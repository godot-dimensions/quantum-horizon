extends SceneTree

## Did the hide get cut correctly, and what does one animated frame cost?
##
##   godot --path project --rendering-method forward_plus --resolution 640x400 \
##       --script res://sandbox/water4d/_probe_swim_runner.gd
##
## Three things are worth checking, and only one of them is visible in a screenshot.
##
## CELLS ARE CONSERVED. Cutting a mesh into buckets is exactly the kind of operation that
## silently drops geometry - strider_walker.gd records losing a whole hide to a GDScript
## value-copy in its bucket loop, and the symptom there was an animal that looked fine until
## you turned it round. Every tetrahedron the rig built must end up in exactly one piece or
## one seam patch; the count either adds up or it does not.
##
## THE PIECES ACTUALLY MOVE. A rig that cuts correctly and then animates nothing looks the
## same as one that works, in a still. So the pose is sampled twice, half a stroke apart, and
## the pieces' transforms are compared.
##
## IT FITS IN A FRAME. The whole point of cutting rather than re-lofting was the 574 ms
## rebuild. If posing costs 20 ms this bought nothing.

const SCENE := "res://sandbox/water4d/plesiosaur.tscn"
const SAMPLES := 240

var _model: Node = null
var _rig: Node = null
var _swimmer: Node = null
var _frames: int = 0


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_model = (load(SCENE) as PackedScene).instantiate()
		root.add_child(_model)
		current_scene = _model
		_rig = _model.get_node_or_null(^"Hide")
		_swimmer = _model.get_node_or_null(^"Swimmer")
		if _rig == null or _swimmer == null:
			print("  FAIL - the scene has no Hide rig or no Swimmer")
			quit(1)
			return true
		return false
	if _frames < 4:
		return false
	return _report()


func _report() -> bool:
	var ok := true

	# --- what the rig built, before the cut -----------------------------------------------
	# Rebuilt from the balls on a rig of its own, because the scene's rig has already handed
	# its mesh over to the pieces and set its own to null.
	var reference: Node = (load(SCENE) as PackedScene).instantiate()
	var spare: Node = reference.get_node_or_null(^"Swimmer")
	if spare != null:
		reference.remove_child(spare)
		spare.queue_free()
	root.add_child(reference)
	var whole := (reference.get_node(^"Hide") as MeshInstance4D).mesh as ArrayTetraMesh4D
	if whole == null:
		print("  FAIL - could not rebuild the uncut hide to compare against")
		quit(1)
		return true
	var expected: int = whole.simplex_cell_vertex_indices.size() / 4

	# --- what the pieces hold -------------------------------------------------------------
	var piece_cells: int = 0
	var seam_cells: int = 0
	var pieces: int = 0
	var seams: int = 0
	for node in _walk(_rig):
		if not (node is MeshInstance4D):
			continue
		var mesh := (node as MeshInstance4D).mesh as ArrayTetraMesh4D
		if mesh == null:
			continue
		var count: int = mesh.simplex_cell_vertex_indices.size() / 4
		if String(node.name).ends_with("Seam"):
			seams += 1
			seam_cells += count
		else:
			pieces += 1
			piece_cells += count

	print("")
	print("  the uncut hide        %d tetrahedra" % expected)
	print("  rigid pieces          %d holding %d" % [pieces, piece_cells])
	print("  seam patches          %d holding %d" % [seams, seam_cells])
	print("  accounted for         %d" % (piece_cells + seam_cells))
	if piece_cells + seam_cells != expected:
		print("  FAIL - %d tetrahedra went missing in the cut"
				% (expected - piece_cells - seam_cells))
		ok = false
	if pieces < 10:
		print("  FAIL - only %d rigid pieces; the body was not split into segments" % pieces)
		ok = false

	# --- does it move ---------------------------------------------------------------------
	var before: Array = _transforms()
	# Half a stroke on, which is the furthest the flippers ever get from where they started.
	_swimmer.set("_time", _swimmer.get("_time") + _swimmer.get("stroke_period") * 0.5)
	_swimmer.call("_physics_process", 0.0)
	var after: Array = _transforms()
	var moved: int = 0
	var furthest: float = 0.0
	for i in before.size():
		var shift: float = (before[i][1] as Vector4).distance_to(after[i][1])
		var turn: float = _basis_difference(before[i][0], after[i][0])
		if shift > 0.001 or turn > 0.001:
			moved += 1
		furthest = maxf(furthest, turn)
	print("")
	print("  pieces that move      %d of %d, largest turn %.3f" % [moved, before.size(), furthest])
	if moved < 8:
		print("  FAIL - only %d pieces moved; the neck, tail and flippers should all be" % moved)
		print("         carrying some of the stroke")
		ok = false

	# --- does anything swing out of the slice ---------------------------------------------
	# THE FAILURE THIS EXISTS FOR. The neck's W sway is applied per joint and the joints
	# compose, so a small angle at each becomes a large one at the head. At 3 degrees a joint
	# the head ended up about 1.2 m off the w = 0 slice on a neck 0.25 m thick, and the
	# animal rendered with NO NECK - which looks exactly like a cut that dropped the
	# geometry, and sent me looking in the wrong place for it. A number catches it; a
	# screenshot of a missing neck does not say why it is missing.
	var worst_ratio: float = 0.0
	var worst_piece: String = ""
	for step in range(48):
		_swimmer.set("_time", float(step) / 48.0 * maxf(_swimmer.get("wave_period"), 0.01))
		_swimmer.call("_physics_process", 0.0)
		for node in _walk(_rig):
			if not (node is MeshInstance4D) or String(node.name).ends_with("Seam"):
				continue
			var mesh := (node as MeshInstance4D).mesh as ArrayTetraMesh4D
			if mesh == null or mesh.simplex_cell_vertex_indices.is_empty():
				continue
			var verts: PackedVector4Array = mesh.get_vertex_positions()
			var seen: Dictionary = {}
			var low_w: float = INF
			var high_w: float = -INF
			for index in mesh.simplex_cell_vertex_indices:
				if seen.has(index):
					continue
				seen[index] = true
				var w: float = ((node as Node4D).get_global_basis() * verts[index]
						+ (node as Node4D).get_global_position()).w
				low_w = minf(low_w, w)
				high_w = maxf(high_w, w)
			# In the slice if the piece still straddles w = 0 with room to spare.
			if low_w > 0.0 or high_w < 0.0:
				var miss: float = minf(absf(low_w), absf(high_w))
				var thickness: float = maxf(high_w - low_w, 0.0001)
				if miss / thickness > worst_ratio:
					worst_ratio = miss / thickness
					worst_piece = String(node.name)
	print("")
	if worst_piece.is_empty():
		print("  slice           every piece straddles w = 0 all cycle; nothing vanishes")
	else:
		print("  FAIL - '%s' leaves the w = 0 slice entirely, by %.2f of its own W thickness."
				% [worst_piece, worst_ratio])
		print("         It will simply not be drawn. Share the W sway along the chain or")
		print("         lower it.")
		ok = false

	# --- what it costs --------------------------------------------------------------------
	var started: int = Time.get_ticks_usec()
	for _i in range(SAMPLES):
		_swimmer.set("_time", _swimmer.get("_time") + 0.016)
		_swimmer.call("_physics_process", 0.016)
	var each: float = float(Time.get_ticks_usec() - started) / float(SAMPLES) / 1000.0
	print("  cost per posed frame  %.3f ms  (a rebuild was 574 ms)" % each)
	if each > 4.0:
		print("  FAIL - %.2f ms per frame is too much of a 16.67 ms budget" % each)
		ok = false

	print("")
	print("  %s" % ("PASS - cut cleanly, moves, and fits in a frame." if ok else "see the failures above."))
	quit(0 if ok else 1)
	return true


func _transforms() -> Array:
	var out: Array = []
	for node in _walk(_rig):
		if node is MeshInstance4D and not String(node.name).ends_with("Seam"):
			out.append([(node as Node4D).basis, (node as Node4D).position])
	return out


## How far two bases differ, as the largest distance any unit axis is moved. A Projection has
## no distance operator and comparing sixteen floats one by one says nothing about how big the
## difference looks.
func _basis_difference(a: Projection, b: Projection) -> float:
	var worst: float = 0.0
	for axis in [Vector4(1, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1)]:
		worst = maxf(worst, (a * axis).distance_to(b * axis))
	return worst


func _walk(node: Node) -> Array[Node]:
	var found: Array[Node] = []
	for child in node.get_children():
		found.append(child)
		found.append_array(_walk(child))
	return found
