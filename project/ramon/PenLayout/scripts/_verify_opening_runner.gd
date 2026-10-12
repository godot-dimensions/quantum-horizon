extends SceneTree

## Pen layout A (6 Oct 2026, PenLayout/PLAN_A.md steps 16-27): the opening, walked. You wake at
## Trym's shed facing the hill; the objective sends you to the keeper; the hill's arch is closed on
## the farm's slice and the tutor says which way it is; at the ruined wall's arch a fallen pillar
## stops you on the farm's slice, the tutor names the slice turn and you think out loud what to do,
## and with the slice turned you walk on round it, through W (6 Oct, the second round: the dry stone
## wall you stepped past ana became the ruins); the objective gives way to the chickens' line at the
## keeper; and the arch is open four metres ana.
##
##   CreationLab/scripts/lab_run.sh windowed pl_opening res://ramon/PenLayout/scripts/_verify_opening_runner.gd

const CaveHill := preload("res://ramon/chickenpen/terrain/pen_cave_hill_4d.gd")
const SliceAngles := preload("res://ramon/chickenpen/scripts/slice_angles_4d.gd")

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
	# The ruined wall's arch, on the farm's slice: the fallen pillar stops you.
	var wall: Node4D = _room.get_node("World/StoneWall") as Node4D
	var arch: Vector4 = wall.global_position + Vector4(float(wall.get("arch_at")), 0.0, 0.0, 0.0)
	await _stand(Vector4(arch.x, 1.2, arch.z + 4.0, 0.0), 40)
	_check(_hint.text.contains("pillar") and _hint.text.contains("slice"), "at the arch, the tutor names the slice turn", "\"%s\"" % _hint.text)
	_check(_room.has_meta(&"ruin_wall_thought_said"), "and you think out loud what to do", "")
	await _walk(Vector4(arch.x, 1.2, arch.z - 4.0, 0.0), 150)
	var z0: float = _player.global_position.z
	_check(z0 > arch.z + 0.5, "on the farm's slice the pillar stops you", "z %.2f" % z0)
	# The slice turned 20 degrees through W and the player walked along it, as the walker walks
	# (along the rig's own forward, which leans into W): round the pillar and through the arch.
	var rig: Node4D = _room.get_node("Player/CameraRig") as Node4D
	await _stand(Vector4(arch.x, 1.2, arch.z + 5.0, 0.0), 20)
	SliceAngles.tilt(rig, 0.0, deg_to_rad(20.0), 0.0)
	for i in 240:
		var ahead: Vector4 = (rig.global_basis * Vector4(0.0, 0.0, -1.0, 0.0))
		ahead.y = 0.0
		_player.linear_velocity = ahead.normalized() * 3.0
		await physics_frame
	var p1: Vector4 = _player.global_position
	# Through means past the wall's far face (its panels and the arch's piers are under a metre deep).
	_check(p1.z < arch.z - 1.0 and absf(p1.w) > 0.5, "with the slice turned you walk round it, through W", "z %.2f, w %.2f" % [p1.z, p1.w])
	SliceAngles.tilt(rig, 0.0, 0.0, 0.0)
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
