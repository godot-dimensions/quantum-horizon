extends SceneTree
## Does the neck actually hold the head steady while the shoulders bob, and does the
## spine flex without dragging planted feet off their targets?

var _frame := 0
var _root: Node
var _player: CharacterBody4D
var _head: Node4D
var _chest: Node4D
var _solver: Node
var _head_y: Array[float] = []
var _shoulder_y: Array[float] = []
var _residual: Array[float] = []
var _chains: Array[Dictionary] = []

func _initialize() -> void:
	_root = load("res://ramon/Model/rigged_creature.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root

func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 1:
		_player = _root.get_node("Player")
		_head = _root.get_node("Creature/Barrel/Chest/Neck1/Neck2/Head")
		_chest = _root.get_node("Creature/Barrel/Chest")
		_solver = _root.get_node("SpineNeckSolver")
		for station in ["Chest", "Rump"]:
			for side in ["L", "R"]:
				for half in ["A", "K"]:
					var tag: String = "%s%s%s" % ["Fore" if station == "Chest" else "Hind", side, half]
					var tip: Node4D = _root.get_node_or_null(
						"Creature/Barrel/%s/%sIK/Upper/Mid/Lower/B2" % [station, tag]) as Node4D
					var target: Node4D = _root.get_node_or_null("Creature/%sFootTarget" % tag) as Node4D
					if tip != null and target != null:
						_chains.append({"tip": tip, "target": target})
		return false
	var eye := Vector4(5.4, 2.8, 5.4, 0.0)
	_player.global_position = eye
	_player.global_basis = Basis4D.looking_at(Vector4(-0.6, 2.2, 0.0, 0.0) - eye)
	_player.linear_velocity = Vector4.ZERO
	if _frame > 80:
		_head_y.append(_head.global_position.y)
		_shoulder_y.append(_chest.global_position.y)
		for c in _chains:
			_residual.append(((c["tip"] as Node4D).global_position - (c["target"] as Node4D).global_position).length())
	if _frame >= 380:
		print("shoulder height range: %.4f" % _range(_shoulder_y))
		print("head     height range: %.4f" % _range(_head_y))
		var reduction: float = 100.0 * (1.0 - _range(_head_y) / maxf(_range(_shoulder_y), 0.00001))
		print("head movement reduced by %.0f%% relative to the shoulders" % reduction)
		var worst := 0.0
		var total := 0.0
		for r in _residual:
			worst = maxf(worst, r)
			total += r
		print("IK residual with spine flex active: mean %.4f  worst %.4f" % [
			total / float(_residual.size()), worst])
		# Turn stabilisation off and confirm the head then tracks the shoulders.
		_solver.head_stabilisation = 0.0
		_head_y.clear()
		_shoulder_y.clear()
		_frame = 300
		if not _off_done:
			_off_done = true
			return false
		quit(0)
		return true
	return false

var _off_done := false

func _range(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var lo := INF
	var hi := -INF
	for v in values:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	return hi - lo
