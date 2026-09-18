extends SceneTree
## The number that decides how this creature can be animated.
##
## Windowed on purpose: the dominant cost of changing vertices is the engine
## rebuilding its 3D proxy mesh, and that only happens when something actually
## renders. A headless measurement would miss it and flatter the wrong option.
##
## Four phases, each measured as a mean over frames after a settle period:
##   idle      - nothing touched, the cost of just drawing the creature
##   transform - the rig NODE's basis rotated each frame, mesh untouched
##   skin      - vertex positions rewritten each frame, topology untouched
##   reloft    - the whole rig rebuilt from its balls each frame

var _frame := 0
var _root: Node
var _rig: MeshInstance4D
var _player: CharacterBody4D
var _base: PackedVector4Array
var _phase := 0
var _samples: Array[float] = []
var _results: Array = []
const PHASES := ["idle", "transform", "skin", "reloft"]
const SETTLE := 20
const MEASURE := 90


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
		var m := _rig.mesh as ArrayTetraMesh4D
		_base = m.get_vertex_positions().duplicate()
		print("creature: %d verts, %d tets" % [
			_base.size(), m.get_simplex_cell_vertex_indices().size() / 4])
		return false

	var eye := Vector4(5.6, 2.6, 5.6, 0.0)
	_player.global_position = eye
	_player.global_basis = Basis4D.looking_at(Vector4(0.3, 1.6, 0.0, 0.0) - eye)
	_player.linear_velocity = Vector4.ZERO

	var t: float = float(_frame) * 0.05
	match PHASES[_phase]:
		"transform":
			_rig.basis = Basis4D.from_zx(sin(t) * 0.15)
		"skin":
			# A cheap per-vertex displacement: the point is the cost of handing new
			# positions over, not the sophistication of the deformation.
			var moved := PackedVector4Array()
			moved.resize(_base.size())
			var s: float = sin(t) * 0.05
			for i in range(_base.size()):
				var v: Vector4 = _base[i]
				moved[i] = Vector4(v.x, v.y + s * v.y, v.z, v.w)
			(_rig.mesh as ArrayTetraMesh4D).set_vertex_positions(moved)
		"reloft":
			_rig.build(false)

	var phase_frame: int = _samples.size()
	if _frame > SETTLE:
		_samples.append(delta)
	if _samples.size() >= MEASURE:
		var total := 0.0
		var worst := 0.0
		for s in _samples:
			total += s
			worst = maxf(worst, s)
		var mean: float = total / float(_samples.size())
		_results.append([PHASES[_phase], mean * 1000.0, worst * 1000.0])
		_samples.clear()
		_phase += 1
		_frame = SETTLE  # re-settle before the next phase
		if _phase >= PHASES.size():
			print("")
			print("  phase       mean frame   worst frame   fps")
			for r in _results:
				print("  %-10s %8.2f ms %9.2f ms %6.1f" % [r[0], r[1], r[2], 1000.0 / r[1]])
			# Restore, so nothing is left deformed.
			(_rig.mesh as ArrayTetraMesh4D).set_vertex_positions(_base)
			quit(0)
			return true
	return false
