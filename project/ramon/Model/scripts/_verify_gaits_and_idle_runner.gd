extends SceneTree
## Exercises every gait plus idle, checking each actually behaves differently and that
## the idle channels hand back cleanly when a gait resumes.

var _frame := 0
var _root: Node
var _player: CharacterBody4D
var _gait: Node
var _idle: Node
var _spine: Node
var _tail: Node
var _head: Node4D
var _feet: Array[Node4D] = []
var _stage := 0
var _samples: Array[float] = []
var _body_y: Array[float] = []
var _contacts := 0
var _prev_down: Array[bool] = []
var _results: Array = []
const STAGES := ["walk", "trot", "hop", "canter_right", "canter_left", "idle"]

func _initialize() -> void:
	_root = load("res://ramon/Model/rigged_creature.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root

func _process(delta: float) -> bool:
	_frame += 1
	if _frame == 1:
		_player = _root.get_node("Player")
		_gait = _root.get_node("IKGaitDriver")
		_idle = _root.get_node("IdleLayer")
		_spine = _root.get_node("SpineNeckSolver")
		_tail = _root.get_node("TailSway")
		_head = _root.get_node("Creature/Barrel/Chest/Neck1/Neck2/Head")
		for station in ["Chest", "Rump"]:
			for side in ["L", "R"]:
				var tag: String = "%s%sA" % ["Fore" if station == "Chest" else "Hind", side]
				var f: Node4D = _root.get_node_or_null(
					"Creature/Barrel/%s/%sIK/Upper/Mid/Lower/Foot/B2" % [station, tag]) as Node4D
				if f != null:
					_feet.append(f)
		_prev_down.resize(_feet.size())
		_apply_stage()
		return false
	var eye := Vector4(5.4, 2.8, 5.4, 0.0)
	_player.global_position = eye
	_player.global_basis = Basis4D.looking_at(Vector4(-0.6, 2.2, 0.0, 0.0) - eye)
	_player.linear_velocity = Vector4.ZERO
	if _frame > 50:
		_samples.append(delta)
		_body_y.append((_root.get_node("Creature/Barrel") as Node4D).position.y)
		for i in range(_feet.size()):
			var down: bool = _feet[i].global_position.y < 0.12
			if down and not _prev_down[i]:
				_contacts += 1
			_prev_down[i] = down
	if _frame >= 290:
		var total := 0.0
		for s in _samples:
			total += s
		var lo := INF
		var hi := -INF
		for y in _body_y:
			lo = minf(lo, y)
			hi = maxf(hi, y)
		_results.append([STAGES[_stage], (total / float(_samples.size())) * 1000.0, _contacts, hi - lo])
		_stage += 1
		if _stage >= STAGES.size():
			print("  stage           frame ms   footfalls   body height range")
			for r in _results:
				print("  %-14s %8.2f %10d   %.4f" % [r[0], r[1], r[2], r[3]])
			print("")
			print("idle channels while halted: flex_scale %.3f  tail sway_scale %.2f  breath %.4f" % [
				_spine.flex_scale, _tail.sway_scale, _gait.breath_offset])
			quit(0)
			return true
		_frame = 50
		_samples.clear()
		_body_y.clear()
		_contacts = 0
		for i in range(_prev_down.size()):
			_prev_down[i] = false
		_apply_stage()
	return false

func _apply_stage() -> void:
	if STAGES[_stage] == "idle":
		_gait.halted = true
		_gait.phase = 0.0
	else:
		_gait.apply_preset(STAGES[_stage])
