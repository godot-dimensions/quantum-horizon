extends SceneTree

## THE SLICE TOUR, a film to share (Ramon, 7 Oct: "can you make a walking video that oscilates between dev
## look and art look, and also shows slice behavior from player perspective? i could share that as a
## video. just make a few scenes that show it well"). Six scenes on the player's own camera (the orbit
## rig), each with a line of caption, cut through black:
##   1  the farm as it plays: down the path to Trym's house, art, then dev, then art
##   2  turning the slice into W among the trees: 35 degrees and back, in the art and then in the dev look
##   3  the camp, 2.5 m kata: out of the slice, the slice turned until it shows, V brings you to it
##   4  through W to the cave: the path climbs 4 m ana to its door (E), and in, and out again
##   5  the town gate, the only way north: walked through in dev, then art
##   6  the Watchstone, its red oak and Wren's balloon, the slice rocking a little
## The movie writer at a fixed 30 fps (lab_run.sh movie_hd: 1920 x 1080), then ffmpeg to mp4. With
## "stills" after "--": a frame at every scene's middle instead (res://smoke_test_output/tour/), for
## checking it before the long render.
##
##   lab_run.sh movie_hd slice_tour res://ramon/PenLayout/scripts/_film_slice_tour_runner.gd

const SliceAngles := preload("res://ramon/chickenpen/scripts/slice_angles_4d.gd")
const Look := preload("res://ramon/chickenpen/look/pen_look_4d.gd")
const FADE := 0.6
const STILLS := "res://smoke_test_output/tour/"

var _room: Node
var _player: CharacterBody4D
var _rig: Node4D
var _black: ColorRect
var _caption: Label
var _t: float = 0.0
var _started: bool = false
var _scene: int = -1
var _st: float = 0.0
var _stills: bool = false
var _still_taken: bool = false
var _scenes: Array = []
var _state: Dictionary = {}


func _initialize() -> void:
	root.unfocusable = true
	_room = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	_room.get_node("Systems/Lookout").set("journal_path", "user://lookout_journal_tour_film.cfg")
	for node in _room.find_children("*", "", true, false):
		if "debug_key_enabled" in node:
			node.set("debug_key_enabled", false)
	root.add_child(_room)
	current_scene = _room
	_stills = OS.get_cmdline_user_args().has("stills")
	var layer := CanvasLayer.new()
	layer.layer = 90
	root.add_child(layer)
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_black)
	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", 30)
	_caption.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	_caption.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	_caption.add_theme_constant_override("outline_size", 8)
	_caption.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_caption.position = Vector2(48, -90)
	_caption.grow_vertical = Control.GROW_DIRECTION_BEGIN
	layer.add_child(_caption)
	_scenes = [
		{"len": 12.0, "say": "The farm as it plays: art look, dev look (I), art again.", "set": _farm_set, "run": _farm_run},
		{"len": 15.0, "say": "Turning the slice into W. The trees stand through W, so the wood stays.", "set": _trees_set, "run": _trees_run},
		{"len": 11.0, "say": "The camp is 2.5 m kata. Turn the slice until it shows, then V.", "set": _camp_set, "run": _camp_run},
		{"len": 17.0, "say": "The cave's door is 4 m ana. The path climbs through W to it.", "set": _cave_set, "run": _cave_run},
		{"len": 9.0, "say": "The town wall runs through all of W. The gate is the only way north.", "set": _gate_set, "run": _gate_run},
		{"len": 9.0, "say": "The Watchstone and its red oak.", "set": _tower_set, "run": _tower_run},
	]


func _process(d: float) -> bool:
	_t += d
	if not _started:
		if _t > 120.0:
			print("TOUR FILM FAIL: no grass after 120 s")
			return true
		var grass: Node = _room.get_node_or_null("World/Grass")
		if (grass != null and not bool(grass.get("mask_ready"))) or _t < 8.0:
			return false
		_set_up()
		_started = true
		_next_scene()
		print("FILM FROM %.3f s" % _t)
		return false
	_st += d
	_hide_layers()
	var length: float = float(_scenes[_scene]["len"])
	var a: float = minf(clampf(_st / FADE, 0.0, 1.0), clampf((length - _st) / FADE, 0.0, 1.0))
	_black.modulate.a = 1.0 - a
	_caption.modulate.a = clampf((_st - 0.4) / 0.6, 0.0, 1.0) * clampf((length - 0.5 - _st) / 0.5, 0.0, 1.0)
	(_scenes[_scene]["run"] as Callable).call(d, _st)
	if _stills and not _still_taken and _st >= length * 0.55:
		_still_taken = true
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(STILLS))
		root.get_texture().get_image().save_png(STILLS + "scene_%d.png" % (_scene + 1))
	if _st >= length:
		if _scene + 1 >= _scenes.size():
			_release()
			print("TOUR FILM DONE at %.3f s" % _t)
			return true
		_next_scene()
	return false


func _next_scene() -> void:
	_release()
	_scene += 1
	_st = 0.0
	_still_taken = false
	_state = {}
	_caption.text = String(_scenes[_scene]["say"])
	(_scenes[_scene]["set"] as Callable).call()
	print("SCENE %d at %.3f s" % [_scene + 1, _t])


func _set_up() -> void:
	for c in _room.get_node("UI").get_children():
		if c is CanvasItem:
			(c as CanvasItem).visible = false
		c.process_mode = Node.PROCESS_MODE_DISABLED
	var label := _room.get_node_or_null("Player/StateLabel") as CanvasItem
	if label != null:
		label.visible = false
	_player = _room.get_node("Player") as CharacterBody4D
	_rig = _room.get_node("Player/CameraRig") as Node4D


func _hide_layers() -> void:
	for layer in _room.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false


func _release() -> void:
	for a in [&"move_forward", &"move_back", &"move_left", &"move_right", &"move_ana", &"move_kata"]:
		Input.action_release(a)


func _place(at: Vector4, yaw_deg: float, pitch: float, distance: float = 7.0) -> void:
	_player.set("input_enabled", true)
	_player.global_position = at
	_player.linear_velocity = Vector4.ZERO
	SliceAngles.tilt(_rig, 0.0, 0.0, deg_to_rad(yaw_deg))
	_rig.set("pitch", pitch)
	_rig.set("distance", distance)
	_rig.set("_zoom_target", distance)


func _look(dev: bool) -> void:
	var look: Node = Look.current
	if look != null and is_instance_valid(look) and bool(look.get("dev")) != dev:
		look.call("set_dev", dev)


func _once(key: String) -> bool:
	if _state.has(key):
		return false
	_state[key] = true
	return true


func _key(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		Input.parse_input_event(e)


# --- 1: the farm -----------------------------------------------------------------------------------

func _farm_set() -> void:
	_look(false)
	_place(Vector4(24.9, 1.2, 20.0, 0.0), 180.0, -0.2)


func _farm_run(_d: float, t: float) -> void:
	Input.action_press(&"move_forward")
	if t > 4.0 and _once("dev"):
		_look(true)
	if t > 8.0 and _once("art"):
		_look(false)


# --- 2: the trees ------------------------------------------------------------------------------------

func _trees_set() -> void:
	_look(false)
	_place(Vector4(14.0, 1.2, 2.0, 0.0), -90.0, -0.05, 6.0)


func _trees_run(_d: float, t: float) -> void:
	# Art: out to 35 degrees and back over 7 s; then the dev look, out and back again.
	var k: float = t if t < 7.5 else t - 7.5
	if t > 7.5 and _once("dev"):
		_look(true)
	var turn: float = deg_to_rad(35.0) * sin(clampf(k / 7.0, 0.0, 1.0) * PI)
	SliceAngles.tilt(_rig, turn, 0.0, deg_to_rad(-90.0))


# --- 3: the camp ---------------------------------------------------------------------------------------

func _camp_set() -> void:
	_look(false)
	_place(Vector4(6.5, 1.2, -3.0, 0.0), -90.0, -0.12, 6.0)


func _camp_run(_d: float, t: float) -> void:
	var camp: Node = _room.get_node_or_null("World/EggCamp")
	if t < 4.5:
		# Turned a little at a time, until the camp is half in the slice and its button comes up.
		if camp != null and bool(camp.call("can_align")):
			_state["shows"] = true
		if not _state.has("shows"):
			SliceAngles.tilt(_rig, -deg_to_rad(min(t, 4.0) * 3.0), 0.0, deg_to_rad(-90.0))
	elif _once("v"):
		_key(KEY_V)


# --- 4: the cave ----------------------------------------------------------------------------------------

func _cave_set() -> void:
	_look(false)
	_place(Vector4(7.3, 1.2, 38.5, 0.0), 0.0, -0.12, 6.5)


func _cave_run(_d: float, t: float) -> void:
	var crossing: Node = _room.get_node_or_null("CaveCrossing")
	var away: bool = crossing != null and bool(crossing.call("is_away"))
	if t < 10.0 and not away:
		Input.action_press(&"move_forward")
		# Up through W as the path climbs: 4 m ana by the door.
		if _player.global_position.w < 3.95 and _player.global_position.z < 36.5:
			Input.action_press(&"move_ana")
		else:
			Input.action_release(&"move_ana")
	else:
		_release()
	if away and not _state.has("in_at"):
		_state["in_at"] = t
	if _state.has("in_at") and t > float(_state["in_at"]) + 4.5 and _once("out"):
		crossing.call("come_back")


# --- 5: the gate ----------------------------------------------------------------------------------------

func _gate_set() -> void:
	_look(true)
	_place(Vector4(-11.6, 1.2, 21.0, 0.0), 0.0, -0.08, 6.5)


func _gate_run(_d: float, t: float) -> void:
	Input.action_press(&"move_forward")
	if t > 4.5 and _once("art"):
		_look(false)


# --- 6: the tower ---------------------------------------------------------------------------------------

func _tower_set() -> void:
	_look(false)
	# On the tower's path, the camera above the hay.
	_place(Vector4(-14.6, 1.2, -14.0, 0.0), 3.0, -0.18, 9.0)


func _tower_run(_d: float, t: float) -> void:
	SliceAngles.tilt(_rig, deg_to_rad(8.0) * sin(t * 0.7), 0.0, deg_to_rad(3.0))
