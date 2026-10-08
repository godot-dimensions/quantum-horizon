extends SceneTree

## What does one re-loft of the plesiosaur cost, at each resolution?
##
##   godot --path project --rendering-method forward_plus --resolution 640x400 \
##       --script res://sandbox/water4d/_probe_loft_cost_runner.gd
##
## WHY THIS COMES FIRST. Animating a lofted creature by moving its balls means rebuilding the
## whole surface every frame, and whether that is sane depends entirely on a number neither I
## nor the docstrings know for THIS model. loft_rig_4d.gd quotes "roughly 13 ms at 12 x 6";
## strider_walker.gd quotes "about 106 ms at 10 sides x 5 rings" for the sauropod. Those
## disagree by 8x because cost scales with section count as well as profile size, and the
## plesiosaur has its own section count - 49 after smoothing.
##
## If a rebuild at playable resolution costs a couple of milliseconds, driving the balls
## directly is the honest approach and the animation can be written plainly. If it costs 30,
## it is not, and the creature needs the skinning treatment strider_walker.gd gives the
## sauropod - which is a much bigger job and worth knowing about before starting, not after.
##
## Each row re-lofts repeatedly and reports the mean, because a single build includes one-off
## costs and the frame it lands in may be doing other things.

const SCENE := "res://sandbox/water4d/plesiosaur.tscn"
const REBUILDS := 12

## smoothing, profile_sides, profile_rings.
const SETTINGS := [
	[3, 12, 5],
	[2, 10, 4],
	[2, 8, 3],
	[1, 8, 3],
	[1, 6, 3],
]

var _rig: Node = null
var _frames: int = 0


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		var model: Node = (load(SCENE) as PackedScene).instantiate()
		root.add_child(model)
		current_scene = model
		_rig = model.get_node_or_null(^"Hide")
		if _rig == null:
			print("  FAIL - no Hide rig")
			quit(1)
			return true
		return false
	if _frames < 4:
		return false

	print("")
	print("  smoothing  sides  rings    sections   vertices   ms per rebuild   frames at 60 Hz")
	for setting in SETTINGS:
		_rig.smoothing = setting[0]
		_rig.profile_sides = setting[1]
		_rig.profile_rings = setting[2]
		_rig.verbose = false
		# One build outside the timing, so whatever it caches is already warm.
		_rig.build(false)
		var started: int = Time.get_ticks_usec()
		for _i in range(REBUILDS):
			_rig.build(false)
		var each: float = float(Time.get_ticks_usec() - started) / float(REBUILDS) / 1000.0
		var mesh: Mesh4D = _rig.mesh as Mesh4D
		var verts: int = mesh.get_vertex_positions().size() if mesh != null else 0
		print("  %9d  %5d  %5d    %8s   %8d   %14.2f   %.2f" % [
				setting[0], setting[1], setting[2], "-", verts, each, each / 16.67])
	print("")
	print("  A rebuild has to fit in a 16.67 ms frame alongside everything else the pool room")
	print("  is already doing, so anything over about 4 ms is not a per-frame budget.")

	# THE OTHER WAY: build the surface ONCE and move its vertices. This is what
	# strider_walker.gd does for the sauropod, and it is the only reason that animal moves at
	# all. The cost is a GDScript pass over the vertex array plus whatever the engine does
	# when the array is handed back - strider measured 18.97 ms for the handback alone on a
	# much heavier mesh, so it has to be measured here rather than assumed cheap.
	_rig.smoothing = 3
	_rig.profile_sides = 12
	_rig.profile_rings = 5
	_rig.build(false)
	var mesh := _rig.mesh as ArrayTetraMesh4D
	var rest: PackedVector4Array = mesh.get_vertex_positions()
	var moved := PackedVector4Array()
	moved.resize(rest.size())

	# A travelling wave down Z, which is roughly the per-vertex work a swimming pose needs.
	var pass_started: int = Time.get_ticks_usec()
	for _i in range(REBUILDS):
		for v in range(rest.size()):
			var point: Vector4 = rest[v]
			var phase: float = point.z * 0.6
			moved[v] = Vector4(point.x + sin(phase) * 0.2, point.y, point.z,
					point.w + cos(phase) * 0.15)
	var maths: float = float(Time.get_ticks_usec() - pass_started) / float(REBUILDS) / 1000.0

	var handback_started: int = Time.get_ticks_usec()
	for _i in range(REBUILDS):
		mesh.set_vertex_positions(moved)
	var handback: float = float(Time.get_ticks_usec() - handback_started) / float(REBUILDS) / 1000.0

	print("")
	print("  SKINNING INSTEAD, on the full-resolution mesh (%d vertices):" % rest.size())
	print("    posing the vertices in GDScript   %6.2f ms" % maths)
	print("    handing the array back            %6.2f ms" % handback)
	print("    total per frame                   %6.2f ms" % (maths + handback))
	quit(0)
	return true
