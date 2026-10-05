extends SceneTree

## Pen layout A (6 Oct 2026, PenLayout/PLAN_A.md steps 16-27): the opening, walked. You wake at
## Trym's shed facing the hill; the objective sends you to the keeper; the hill's arch is closed on
## the farm's slice and the tutor says which way it is; the dry stone wall stops you on the farm's
## slice, the tutor says it is thin in W, a metre and a half ana it is not there; the objective
## gives way to the chickens' line at the keeper; and the arch is open four metres ana.
##
##   CreationLab/scripts/lab_run.sh windowed pl_opening res://ramon/PenLayout/scripts/_verify_opening_runner.gd

const CaveHill := preload("res://ramon/chickenpen/terrain/pen_cave_hill_4d.gd")

var _room: Node
var _player: CharacterBody4D
var _hint: Label
var _objective: Label
var _fails: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_run.call_deferred()


func _check(ok: bool, what: String, detail: String = "") -> void:
	print("  %s  %s  %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_fails += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


## Puts the player at [param p] and keeps them there for [param n] frames.
func _stand(p: Vector4, n: int = 20) -> void:
	for i in n:
		_player.global_position = p
		_player.linear_velocity = Vector4.ZERO
		await physics_frame


## Walks the player toward [param p] for [param n] frames at 3 m/s, letting physics stop them.
func _walk(p: Vector4, n: int) -> void:
	for i in n:
		var d: Vector4 = p - _player.global_position
		d.y = 0.0
		_player.linear_velocity = d.normalized() * 3.0 if d.length() > 0.1 else Vector4.ZERO
		await physics_frame


func _run() -> void:
	_room = (load("res://ramon/chickenpen/playable_world.tscn") as PackedScene).instantiate()
	root.add_child(_room)
	current_scene = _room
	_player = _room.get_node("Player") as CharacterBody4D
	_player.set("input_enabled", false)
	_hint = _room.get_node("UI/Hint") as Label
	_objective = _room.get_node("UI/Objective") as Label
	await _frames(30)
	print("THE OPENING")
	var at: Vector4 = _player.global_position
	_check(Vector2(at.x - 4.0, at.z - 38.0).length() < 1.0, "you wake by Trym's shed, south of the hill", str(at))
	var yaw: float = float(_room.get_node("Player/CameraRig").get("yaw"))
	_check(absf(angle_difference(yaw, 0.0)) < 0.2, "facing north, at the hill", "yaw %.2f" % yaw)
	_check(_objective.text.contains("keeper"), "the objective sends you to the keeper", "\"%s\"" % _objective.text)
	_check(_hint.text.begins_with("Move"), "the first hint is how to move", "\"%s\"" % _hint.text)
	# Let the move hint run out.
	await _frames(int(7.5 * 60))
	# The arch on the farm's slice: closed, and the tutor says which way.
	var hill: Node4D = CaveHill.node_in(_room)
	var mouth: Vector4 = CaveHill.to_world(hill, CaveHill.MOUTH)
	_check(absf(mouth.w - 4.0) < 0.01, "the cave's arch is four metres ana", "W %.2f" % mouth.w)
	await _stand(Vector4(mouth.x, 1.2, mouth.z + 2.5, 0.0), 30)
	_check(_hint.text.contains("arch") and _hint.text.contains("ana"), "at the closed arch, the tutor says it is ana", "\"%s\"" % _hint.text)
	var crossing: Node = _room.get_node("CaveCrossing")
	_check(not bool(crossing.call("is_away")), "and on the farm's slice it does not take you in")
	await _frames(int(7.5 * 60))
	# The wall, on the farm's slice: it stops you.
	await _stand(Vector4(-11.0, 1.2, 19.5, 0.0), 30)
	_check(_hint.text.contains("wall") and _hint.text.contains("W"), "at the wall, the tutor says it is thin in W", "\"%s\"" % _hint.text)
	await _walk(Vector4(-11.0, 1.2, 12.0, 0.0), 150)
	var z0: float = _player.global_position.z
	_check(z0 > 16.2, "on the farm's slice the wall stops you", "z %.2f" % z0)
	# A metre and a half ana: through.
	await _stand(Vector4(-11.0, 1.2, 19.0, 1.5), 20)
	await _walk(Vector4(-11.0, 1.2, 12.0, 1.5), 150)
	var z1: float = _player.global_position.z
	_check(z1 < 15.5, "a metre and a half ana it is not there", "z %.2f" % z1)
	await _frames(int(7.5 * 60))
	# The keeper: the objective becomes the chickens'.
	var keeper: Node4D = _room.get_node("World/KeeperPost/Keeper") as Node4D
	await _stand(keeper.global_position + Vector4(3.0, 1.2, 3.0, 0.0), 30)
	_check(_objective.text.contains("chickens"), "at the keeper, the objective is the chickens'", "\"%s\"" % _objective.text)
	# Back at the hill four metres ana: in.
	var way: Vector4 = CaveHill.to_world(hill, (CaveHill.new().way_in() as Array)[0])
	for i in 40:
		_player.global_position = way - Vector4(0.0, 1.2, 0.0, 0.0)
		_player.linear_velocity = Vector4.ZERO
		await physics_frame
		if bool(crossing.call("is_away")):
			break
	_check(bool(crossing.call("is_away")), "four metres ana, the arch takes you in", "way in at W %.2f" % way.w)
	print("OPENING: %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(0 if _fails == 0 else 1)
