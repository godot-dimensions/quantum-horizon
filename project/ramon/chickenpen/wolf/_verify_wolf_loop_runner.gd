extends SceneTree

## THE WOLF NEVER CIRCLES FOR EVER, AND A CLICK SKIPS IT (Ramon, 7 Oct: "serious glitch happening when the wolf
## animation kicks in. and its not skippable with left mouse click. he keeps going in circles with the chicken,
## stuck in a loop"). The wolf turned at a fixed rate and only counted as there within one frame's step, so a
## target inside its turning circle was circled for ever (wolf_raid_4d.gd _run_to). Here it is sent for a hen at
## five places in the pen, among them one that a re-run of its steering showed circling for good (pen-local
## (2.2, 0.4)) and the fence's corners; each raid must end, within its few seconds. Then once more, and a left
## click in the middle of it: the raid over at once, your input and the farm's camera back, the hen gone off, out
## of the pen and a little ana, as a whole raid leaves it.
##
##   lab_run.sh fast wolf_loop res://ramon/chickenpen/wolf/_verify_wolf_loop_runner.gd

const PEN := "res://ramon/chickenpen/playable_world.tscn"
## Hen places, metres from the pen's middle (x, z).
const PLACES := [Vector2(1.0, 0.5), Vector2(2.2, 0.4), Vector2(3.6, 3.2), Vector2(-3.6, -3.0), Vector2(3.8, -0.2)]

var _room: Node
var _raid: Node
var _manager: Node
var _player: Node4D
var _fails: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_run.call_deferred()


func _check(what: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_fails += 1
	print("   %s %-58s %s" % ["PASS" if ok else "FAIL", what, detail])


func _seconds(s: float) -> void:
	await create_timer(s).timeout


func _home(at: Vector2) -> Node:
	var agent: Node = (_manager.get("agents") as Array)[0]
	var bird := agent.get_parent() as Node4D
	var pen: Vector4 = (_room.get_node("Pen/Fence") as Node4D).global_position
	bird.global_position = Vector4(pen.x + at.x, 0.0, pen.z + at.y, 0.0)
	agent.call("on_landed", true)
	return agent


func _run() -> void:
	_room = (load(PEN) as PackedScene).instantiate()
	root.add_child(_room)
	current_scene = _room
	await _seconds(6.0)
	_raid = _room.get_node("Systems/WolfRaid")
	_manager = _room.get_node("Chickens")
	_player = _room.get_node("Player") as Node4D
	for at in PLACES:
		_home(at)
		var sent: bool = bool(_raid.call("start_raid"))
		var t: float = 0.0
		var longest_phase: float = 0.0
		while _raid.call("is_running") and t < 30.0:
			await process_frame
			t += 1.0 / 60.0
			longest_phase = maxf(longest_phase, float(_raid.get("_phase_t")))
		_check("a hen at (%.1f, %.1f): the raid ends" % [at.x, at.y], sent and not bool(_raid.call("is_running")),
			"%.1f s, its longest beat %.1f s" % [t, longest_phase])
		await _seconds(0.5)
	# Skipped with a left click, a second and a half in.
	var agent: Node = _home(Vector2(2.2, 0.4))
	_check("sent again", bool(_raid.call("start_raid")))
	await _seconds(1.5)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	await process_frame
	await process_frame
	var up: InputEventMouseButton = click.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	_check("a left click ends it at once", not bool(_raid.call("is_running")))
	_check("your input is back", _player.get("input_enabled") == true)
	_check("the farm's camera is back", (_room.get_node("Player/CameraRig/Pitch/Camera4D") as Camera4D).current)
	var bird := agent.get_parent() as Node4D
	var pen: Vector4 = (_room.get_node("Pen/Fence") as Node4D).global_position
	var off := Vector2(bird.global_position.x - pen.x, bird.global_position.z - pen.z)
	_check("the hen is gone off, out of the pen", not bool(agent.get("returned")) and (absf(off.x) > 4.2 or absf(off.y) > 3.8),
		"at (%.1f, %.1f)" % [off.x, off.y])
	_check("a little ana, as a whole raid leaves it", absf(bird.global_position.w - float(_raid.get("exit_w"))) < 0.05)
	print("WOLF LOOP %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
	quit(1 if _fails > 0 else 0)
