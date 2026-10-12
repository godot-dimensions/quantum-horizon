extends SceneTree

## A SHORT FILM OF RAMON'S VERSION (outfit/PLAN_FITTING_ROOM.md step 51): into the fitting circle, the
## scan, Enter, the cyan flash into Trym's fitting room, a run of changes at a person's pace (the shirt,
## long trousers, the hats, the chicken, the piece turned through W), Done, the flash home, and the farm
## with you dressed and the circle saying so.
##
## TIMED IN FRAMES, as the circle's film is: the movie writer runs at a fixed 30 fps.
##
##   lab_run.sh movie_hd outfit_room_film res://ramon/chickenpen/outfit/_film_room_runner.gd look=art

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


func _press(code: Key, then: float = 0.6) -> void:
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
	_player = _room.get_node("Player") as CharacterBody4D
	_rig = _player.get_node("CameraRig") as Node4D
	_circle = _room.get_node("World/OutfitCircle") as Node4D
	# A few steps from the circle, walking in.
	_player.global_position = Vector4(_circle.global_position.x + 4.5, _player.global_position.y, _circle.global_position.z - 2.0, 0.0)
	_player.linear_velocity = Vector4.ZERO
	var look: Vector4 = _circle.global_position - _player.global_position
	SliceAngles.tilt(_rig, 0.0, 0.0, atan2(look.x, look.z) + PI)
	_rig.set("pitch", deg_to_rad(-11.0))
	_rig.set("distance", 4.0)
	_rig.set("_zoom_target", 4.0)
	_rig.call("_apply")
	_player.set("input_enabled", true)
	await _hold(1.2)
	Input.action_press(&"move_forward")
	var steps: int = 0
	while Vector2(_circle.global_position.x - _player.global_position.x, _circle.global_position.z - _player.global_position.z).length() > 0.9 and steps < FPS * 10:
		var to: Vector4 = _circle.global_position - _player.global_position
		_rig.call("face_toward", Vector4(to.x, 0.0, to.z, 0.0).normalized(), 0.08)
		await process_frame
		steps += 1
	Input.action_release(&"move_forward")
	await _hold(0.8)
	await _press(KEY_F, 0.1)
	print("FILM in the circle")
	await _hold(3.0)
	await _press(KEY_DOWN, 0.4)
	await _press(KEY_DOWN, 0.4)
	await _press(KEY_DOWN, 1.0)
	await _press(KEY_ENTER, 1.6)
	print("FILM in the room: %s" % (current_scene.name if current_scene != null else "none"))
	await _press(KEY_RIGHT)
	await _press(KEY_RIGHT)
	await _press(KEY_RIGHT, 1.2)
	await _press(KEY_5, 0.8)
	await _press(KEY_DOWN)
	await _press(KEY_RIGHT)
	await _press(KEY_RIGHT, 1.2)
	await _press(KEY_6, 0.8)
	await _press(KEY_RIGHT, 1.2)
	await _press(KEY_1, 0.8)
	await _press(KEY_DOWN)
	await _press(KEY_DOWN)
	await _press(KEY_DOWN, 0.6)
	await _press(KEY_RIGHT)
	await _press(KEY_RIGHT, 1.4)
	await _press(KEY_DOWN, 2.0)
	await _press(KEY_DOWN, 1.0)
	await _press(KEY_T, 3.6)
	await _press(KEY_T, 0.4)
	await _press(KEY_UP, 2.2)
	print("FILM done")
	await _press(KEY_ENTER, 1.4)
	_hud_off()
	await _hold(2.6)
	_player.set("input_enabled", true)
	Input.action_press(&"move_back")
	await _hold(1.6)
	Input.action_release(&"move_back")
	await _hold(1.4)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://outfit_test_journal.cfg"))
	print("FILM DONE")
	quit(0)


func _hud_off() -> void:
	var ui: Node = _room.get_node_or_null("UI")
	if ui == null:
		return
	for c in ui.get_children():
		if String(c.name) in ["GrassPanel", "PathsPanel"]:
			c.process_mode = Node.PROCESS_MODE_DISABLED
		if c.name == &"OutfitCircleUI":
			continue
		if c is CanvasItem:
			(c as CanvasItem).visible = false
