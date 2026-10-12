extends SceneTree
## Splits the skinning cost into the part GDScript pays and the part the ENGINE pays.
## Ramon's note records 0.06 ms for "moving all of a creature's vertices" and calls
## skinning the next piece of work. That figure is the set_vertex_positions call
## alone; it does not include the engine rebuilding its 3D proxy mesh, which only
## happens when something renders. This measures both.

var _frame := 0
var _root: Node
var _rig: MeshInstance4D
var _player: CharacterBody4D
var _base: PackedVector4Array
var _set_us: Array[float] = []
var _frame_ms: Array[float] = []

func _initialize() -> void:
	_root = load("res://ramon/Model/symmetry_lab.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root

func _process(delta: float) -> bool:
	_frame += 1
	if _frame == 1:
		_rig = _root.get_node("Creature")
		_player = _root.get_node("Player")
		_rig.live_rebuild = false
		_rig.verbose = false
		_rig.build(false)
		_base = (_rig.mesh as ArrayTetraMesh4D).get_vertex_positions().duplicate()
		return false
	var eye := Vector4(5.6, 2.6, 5.6, 0.0)
	_player.global_position = eye
	_player.global_basis = Basis4D.looking_at(Vector4(0.3, 1.6, 0.0, 0.0) - eye)
	_player.linear_velocity = Vector4.ZERO

	var moved := PackedVector4Array()
	moved.resize(_base.size())
	var s: float = sin(float(_frame) * 0.05) * 0.05
	for i in range(_base.size()):
		var v: Vector4 = _base[i]
		moved[i] = Vector4(v.x, v.y + s * v.y, v.z, v.w)
	var t0 := Time.get_ticks_usec()
	(_rig.mesh as ArrayTetraMesh4D).set_vertex_positions(moved)
	var t1 := Time.get_ticks_usec()

	if _frame > 25:
		_set_us.append(float(t1 - t0))
		_frame_ms.append(delta * 1000.0)
	if _set_us.size() >= 60:
		var set_total := 0.0
		var frame_total := 0.0
		for v in _set_us:
			set_total += v
		for v in _frame_ms:
			frame_total += v
		var set_ms: float = set_total / float(_set_us.size()) / 1000.0
		var frame: float = frame_total / float(_frame_ms.size())
		print("vertices:                    %d" % _base.size())
		print("set_vertex_positions call:   %8.3f ms   <- what GDScript pays" % set_ms)
		print("whole frame:                 %8.2f ms" % frame)
		print("engine-side remainder:       %8.2f ms   <- proxy mesh rebuild" % (frame - set_ms - 16.9))
		print("")
		print("(16.9 ms subtracted as the measured idle cost of drawing this scene)")
		(_rig.mesh as ArrayTetraMesh4D).set_vertex_positions(_base)
		quit(0)
		return true
	return false
