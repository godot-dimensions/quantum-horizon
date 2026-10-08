extends SceneTree

## A SHORT FILM OF THE FITTING CIRCLE, for Ramon to watch (outfit/PLAN_OUTFIT.md step 75): walking up to
## Trym's house, the frame rising, stepping in, the scan, a run of changes at a person's pace (shirt,
## trousers, skin, hair, the hats, the chicken, the hypercube), F, and walking away as the frame lifts off.
##
## TIMED IN FRAMES, NOT SECONDS: the movie writer runs at a fixed 30 fps however fast the machine
## renders, so a wait measured on the wall clock would play back at the wrong speed.
##
##   lab_run.sh movie_hd outfit_film res://ramon/chickenpen/outfit/_film_outfit_runner.gd look=art

const Outfit := preload("res://ramon/chickenpen/outfit/outfit_4d.gd")
const SliceAngles := preload("res://ramon/chickenpen/scripts/slice_angles_4d.gd")
const TEST_SAVE := "user://outfit_test_film.cfg"
const OURS := 77
const FPS := 30

var _room: Node
var _player: CharacterBody4D
var _rig: Node4D
var _circle: Node4D
var _f: int = 0


class Guard extends Node:
	func _input(event: InputEvent) -> void:
		if event.device == 77:
			return
		if event is InputEventKey or event is InputEventMouse:
			get_viewport().set_input_as_handled()


func _initialize() -> void:
	root.unfocusable = true
	_run.call_deferred()


func _process(_d: float) -> bool:
	_f += 1
	if _f > FPS * 240:
		print("FILM FAIL: ran past four minutes")
		return true
	return false


func _hold(seconds: float) -> void:
	for i in int(seconds * FPS):
		await process_frame


func _press(code: Key, then: float = 0.55) -> void:
	var down := InputEventKey.new()
	down.device = OURS
	down.physical_keycode = code
	down.keycode = code
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	var up := down.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)
	await _hold(then)


func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	Outfit.use_save_path(TEST_SAVE)
	_room = (load("res://ramon/chickenpen/playable_world.tscn") as PackedScene).instantiate()
	var lookout: Node = _room.get_node_or_null("Systems/Lookout")
	if lookout != null:
		lookout.set("journal_path", "user://outfit_test_journal.cfg")
	root.add_child(_room)
	current_scene = _room
	root.add_child(Guard.new())
	await _hold(0.1)
	_hud_off()
	await _hold(2.9)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_hud_off()
	await _go()


func _hud_off() -> void:
	var ui: Node = _room.get_node_or_null("UI")
	for c in ui.get_children():
		if String(c.name) in ["GrassPanel", "PathsPanel"]:
			c.process_mode = Node.PROCESS_MODE_DISABLED
		if c.name == &"OutfitCircleUI":
			continue
		if c is CanvasItem:
			(c as CanvasItem).visible = false


func _go() -> void:
	_player = _room.get_node("Player") as CharacterBody4D
	_rig = _player.get_node("CameraRig") as Node4D
	_circle = _room.get_node("World/OutfitCircle") as Node4D
	# On the path north of Trym's sand, where you arrive, looking down at his house and the circle.
	_player.global_position = Vector4(24.5, _player.global_position.y, 35.5, 0.0)
	_player.linear_velocity = Vector4.ZERO
	var look: Vector4 = _circle.global_position - _player.global_position
	SliceAngles.tilt(_rig, 0.0, 0.0, atan2(look.x, look.z) + PI)
	_rig.set("pitch", deg_to_rad(-11.0))
	_rig.set("distance", 4.2)
	_rig.set("_zoom_target", 4.2)
	_rig.call("_apply")
	_player.set("input_enabled", true)
	await _hold(1.0)
	print("FILM walk up")
	# Walk west, then steer into the middle of the circle.
	Input.action_press(&"move_forward")
	var guard_frames: int = 0
	while _flat(_player.global_position - _circle.global_position) > 0.3 and guard_frames < FPS * 12:
		var to: Vector4 = _circle.global_position - _player.global_position
		_rig.call("face_toward", Vector4(to.x, 0.0, to.z, 0.0).normalized(), 0.08)
		await process_frame
		guard_frames += 1
		if int(_circle.get("state")) >= 2:
			break
	Input.action_release(&"move_forward")
	print("FILM in, state %d" % int(_circle.get("state")))
	await _hold(3.2)
	# Dressing, at a person's pace.
	await _press(KEY_D)
	await _press(KEY_D)
	await _press(KEY_D, 0.9)
	await _press(KEY_S)
	await _press(KEY_E)
	await _press(KEY_D)
	await _press(KEY_D, 0.9)
	await _press(KEY_S)
	await _press(KEY_D, 0.9)
	await _press(KEY_W)
	await _press(KEY_W)
	await _press(KEY_W)
	await _press(KEY_D)
	await _press(KEY_D)
	await _press(KEY_D, 0.9)
	await _press(KEY_W)
	await _press(KEY_D)
	await _press(KEY_D, 0.9)
	await _press(KEY_W)
	await _press(KEY_E)
	await _press(KEY_E, 0.9)
	await _press(KEY_E)
	await _press(KEY_D)
	await _press(KEY_D, 1.2)
	await _press(KEY_E, 2.4)
	await _press(KEY_E, 3.2)
	await _press(KEY_X, 1.4)
	await _press(KEY_X, 1.4)
	# Back to what you came in wearing, then the chicken again (from the cap, Q goes round to the
	# hypercube and then the chicken): leaving as a chicken is the better ending.
	await _press(KEY_BACKSPACE, 1.2)
	await _press(KEY_Q)
	await _press(KEY_Q, 2.2)
	print("FILM done")
	await _press(KEY_F, 2.2)
	# And away, east along the house, as the frame lifts off behind you.
	_player.set("input_enabled", true)
	Input.action_press(&"move_back")
	await _hold(3.4)
	Input.action_release(&"move_back")
	await _hold(2.4)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://outfit_test_journal.cfg"))
	print("FILM DONE")
	quit(0)


func _flat(v: Vector4) -> float:
	return Vector2(v.x, v.z).length()
