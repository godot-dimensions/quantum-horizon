extends SceneTree

## Does the plesiosaur actually loft, and is it the shape it claims to be?
##
##   godot --path project --rendering-method forward_plus --headless \
##       --script res://sandbox/water4d/_probe_plesiosaur_runner.gd
##
## WHY THIS RUNS BEFORE THE EDITOR DOES. A hand-written .tscn full of balls either lofts or
## throws, and opening the editor to find out wastes a minute per attempt. More to the point,
## the thing most likely to be wrong is invisible in a screenshot anyway: whether `v_scale`
## and `w_scale` landed on the axes I think they did. `build_frames` seeds its cross-section
## frame with X, Z, W and orthonormalises against the spine, so a body running along Z should
## put radius on X, v_scale on Y and w_scale on W - and a flipper running along X should put
## radius on Z instead. That is a claim about the bounding box, so measure the bounding box.
##
## A flipper authored thin in v and broad in w is the whole point of the model: it makes the
## paddle a blade spanning Z AND W rather than Z alone. If the axes came out transposed the
## animal would swim with its flippers on edge, and it would look merely odd rather than
## wrong, which is exactly the kind of thing that survives a visual check.

const SCENE := "res://sandbox/water4d/plesiosaur.tscn"

## The rig coalesces rebuilds into its own _process, so the mesh is not there on the frame
## the scene is added - calling build() directly from _initialize returned early on
## is_inside_tree() and left me reading a null. Wait a few frames and read what the rig
## itself produced, which is also what the editor will show.
const SETTLE_FRAMES := 6

var _rig: Node = null
var _frames: int = 0


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		var packed: PackedScene = load(SCENE) as PackedScene
		if packed == null:
			print("  FAIL - the scene did not load at all")
			quit(1)
			return true
		var model: Node = packed.instantiate()
		# THE SWIMMER GOES FIRST. Once it has run it owns the hide: it cuts the mesh into
		# pieces and sets the rig's own mesh to null, so this probe - which is about the
		# shape the model was authored as - would read that null and report that the rig
		# built nothing. Removing it before the scene enters the tree keeps this probe
		# measuring the thing it is named after.
		var swimmer: Node = model.get_node_or_null(^"Swimmer")
		if swimmer != null:
			model.remove_child(swimmer)
			swimmer.queue_free()
		root.add_child(model)
		current_scene = model
		_rig = model.get_node_or_null(^"Hide")
		if _rig == null:
			print("  FAIL - no Hide rig under the root")
			quit(1)
			return true
		return false
	if _frames < SETTLE_FRAMES:
		return false
	return _report()


func _report() -> bool:
	var mesh: Mesh4D = _rig.mesh as Mesh4D
	if mesh == null:
		print("  FAIL - the rig built nothing")
		quit(1)
		return true

	var points: PackedVector4Array = mesh.get_vertex_positions()
	if points.is_empty():
		print("  FAIL - the built mesh has no vertices")
		quit(1)
		return true

	var low: Vector4 = points[0]
	var high: Vector4 = points[0]
	for p in points:
		low = Vector4(minf(low.x, p.x), minf(low.y, p.y), minf(low.z, p.z), minf(low.w, p.w))
		high = Vector4(maxf(high.x, p.x), maxf(high.y, p.y), maxf(high.z, p.z), maxf(high.w, p.w))
	var span: Vector4 = high - low

	print("")
	print("  vertices        %d" % points.size())
	print("  length (Z)      %.2f m   from %.2f to %.2f" % [span.z, low.z, high.z])
	print("  width  (X)      %.2f m   spanning %.2f to %.2f" % [span.x, low.x, high.x])
	print("  height (Y)      %.2f m" % span.y)
	print("  depth  (W)      %.2f m" % span.w)
	print("")

	var ok := true
	if span.z < span.x or span.z < span.y:
		print("  FAIL - this is not longer than it is wide or tall; the spine is not along Z")
		ok = false
	if absf(low.x + high.x) > 0.05:
		print("  FAIL - X is lopsided (%.2f to %.2f); mirror_x did not fire" % [low.x, high.x])
		ok = false
	# THE WHOLE-MODEL W SPAN SAYS NOTHING ABOUT THE FLIPPERS and I nearly accepted it when it
	# did. It came out at 2.00 m, which is the barrel's own girth through W - radius 0.76 at
	# w_scale 1.3, doubled - and the paddles sit well inside that. A threshold on it passes
	# whatever the flippers are doing.
	#
	# So measure the blade on its own. Everything outboard of x = 1.2 is flipper: the widest
	# body ball is radius 0.76. A paddle authored thin in v and broad in w must come out much
	# deeper through W than it is tall; if the two scales landed on each other's axes it comes
	# out tall and narrow instead, and the ratio catches that where the bounding box cannot.
	var blade_low := Vector4(INF, INF, INF, INF)
	var blade_high := Vector4(-INF, -INF, -INF, -INF)
	var blade_points: int = 0
	for p in points:
		if absf(p.x) < 1.2:
			continue
		blade_points += 1
		blade_low = Vector4(minf(blade_low.x, p.x), minf(blade_low.y, p.y),
				minf(blade_low.z, p.z), minf(blade_low.w, p.w))
		blade_high = Vector4(maxf(blade_high.x, p.x), maxf(blade_high.y, p.y),
				maxf(blade_high.z, p.z), maxf(blade_high.w, p.w))
	# A THIN SLAB, not the whole limb. The region's Z span is dominated by the flipper's
	# backward sweep, so it reports ~2.9 m of "chord" whatever the cross-section is actually
	# doing, and its Y span picks up the limb's droop the same way. Both readings moved when I
	# changed parameters and neither was telling me about the section. One slab 10 cm wide in
	# X is narrow enough that sweep and droop contribute almost nothing, so what is left is
	# the section itself - which is the thing the radius / v_scale / w_scale triple controls.
	var slab_low := Vector4(INF, INF, INF, INF)
	var slab_high := Vector4(-INF, -INF, -INF, -INF)
	var slab_points: int = 0
	for p in points:
		# z > -0.5 keeps the FORE flipper only. Without it the slab also catches the hind
		# flipper, 2.3 m further back, and reports the gap between the two as the blade's
		# chord - which is how a 0.58 m section came back as 2.66 m across.
		if p.x < 1.30 or p.x > 1.40 or p.z < -0.5:
			continue
		slab_points += 1
		slab_low = Vector4(minf(slab_low.x, p.x), minf(slab_low.y, p.y),
				minf(slab_low.z, p.z), minf(slab_low.w, p.w))
		slab_high = Vector4(maxf(slab_high.x, p.x), maxf(slab_high.y, p.y),
				maxf(slab_high.z, p.z), maxf(slab_high.w, p.w))
	if slab_points < 8:
		print("  FAIL - only %d vertices in the blade slab; cannot read the section" % slab_points)
		ok = false
	else:
		var chord: float = slab_high.z - slab_low.z
		var thick: float = slab_high.y - slab_low.y
		var deep: float = slab_high.w - slab_low.w
		print("  blade section  %.2f m chord (Z)   %.2f m thick (Y)   %.2f m through W"
				% [chord, thick, deep])
		# A paddle is broad both ways and thin one way. Measured on the section rather than on
		# the limb's bounding box, because the box reports the backward sweep as chord and the
		# downward droop as thickness, and both of those move when the shape does not.
		if chord < thick * 2.0 or deep < thick * 2.0:
			print("  FAIL - that is a fin or a strut, not a paddle. For a limb running out")
			print("         along X the section's frame puts RADIUS on Y and V_SCALE on Z, not")
			print("         the other way round, so a blade needs roll = 90 to lie flat.")
			ok = false

	if blade_points < 20:
		print("  FAIL - only %d vertices outboard of the body; there are no flippers" % blade_points)
		ok = false
	else:
		var tall: float = blade_high.y - blade_low.y
		var deep: float = blade_high.w - blade_low.w
		var chord: float = blade_high.z - blade_low.z
		print("  flipper blade   %.2f m chord (Z)   %.2f m thick (Y)   %.2f m through W"
				% [chord, tall, deep])
		# No pass/fail on these: the box's Y is mostly droop and its Z is mostly sweep. They
		# are printed because they say how far the limb reaches, which is worth seeing.
		print("  limb reach     %.2f m fore-aft   %.2f m of droop   %.2f m through W"
				% [chord, tall, deep])
	if ok:
		print("  PASS - lofts, mirrors, and the paddles have genuine W span.")
	quit(0 if ok else 1)
	return true
