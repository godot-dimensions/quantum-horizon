extends SceneTree
## Does FABRIK actually reach the foot targets? The controller's own header records a
## measured ~2.7-unit residual for the two-bone solver it replaced, so residual is the
## number that decides whether this integration is real or nominal.

var _frame := 0
var _root: Node
var _player: CharacterBody4D
var _chains: Array[Dictionary] = []
var _worst := 0.0
var _total := 0.0
var _count := 0

func _initialize() -> void:
	_root = load("res://ramon/Model/rigged_creature.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root

func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 1:
		_player = _root.get_node("Player")
		for station in ["Chest", "Rump"]:
			for side in ["L", "R"]:
				for half in ["A", "K"]:
					var tag: String = "%s%s%s" % ["Fore" if station == "Chest" else "Hind", side, half]
					var ik: Node = _root.get_node_or_null("Creature/Barrel/%s/%sIK" % [station, tag])
					var target: Node4D = _root.get_node_or_null("Creature/%sFootTarget" % tag) as Node4D
					var tip: Node4D = _root.get_node_or_null(
						"Creature/Barrel/%s/%sIK/Upper/Mid/Lower/B2" % [station, tag]) as Node4D
					if ik != null and target != null and tip != null:
						_chains.append({"ik": ik, "target": target, "tip": tip, "tag": tag})
		print("chains: %d" % _chains.size())
		return false
	var eye := Vector4(5.4, 2.8, 5.4, 0.0)
	_player.global_position = eye
	_player.global_basis = Basis4D.looking_at(Vector4(-0.6, 2.2, 0.0, 0.0) - eye)
	_player.linear_velocity = Vector4.ZERO
	if _frame > 60:
		for c in _chains:
			var d: float = ((c["tip"] as Node4D).global_position - (c["target"] as Node4D).global_position).length()
			_worst = maxf(_worst, d)
			_total += d
			_count += 1
	if _frame >= 260:
		print("tracking residual over %d samples: mean %.4f  worst %.4f units" % [
			_count, _total / float(_count), _worst])
		print("(the two-bone solver this replaced measured a sustained ~2.7-unit residual)")
		quit(0)
		return true
	return false
