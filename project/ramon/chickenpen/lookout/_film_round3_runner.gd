extends SceneTree

## A short film of round three, for Ramon to judge (2 Oct): the real game, driven by a script
## and recorded by the movie writer at a fixed 30 fps, the game's own sound.
##
##   the owl's tree   the dead tree it sits in now, out at w +1.5
##   projection       P: the cut, then the cut and a ghost of everything along W
##   lenses           L through the primes, 18 to 200 mm, and their angles
##   the first photo  Wren framed for you, the shot, and how it was judged
##   F4               the developer overlay over the owl, the ring sliding to it
##   the hawk         U: the flock's own hawk, into the murmuration; ana out of their W
##   the heron        stalking on planted feet, the strike, the take-off, legs trailing
##   the kata wood    kata of the marsh: a chipmunk going round its tree through W
##
## Captions say what each part is. Its own journal, deleted at the end.
##
##   godot... --path project --resolution 1920x1080 --write-movie <out>.avi --fixed-fps 30
##       --script res://ramon/chickenpen/lookout/_film_round3_runner.gd

const TEST_BOOK := "user://lookout_journal_film3.cfg"
const STYLE := preload("res://ramon/Menu/style/menu_final_style.tres")
const HIDE := ["InfoCard", "Quests", "FlockStats", "Fps", "Objective", "Progress", "Locator", "CatchPrompt", "Hint",
	"Debug", "Again", "Controls", "ControlsHint", "LockOn", "Keeper", "CameraPicker", "Inventory", "Searcher", "SlicePlane", "Cinematics"]
const BEATS := [
	[1.0, "black"], [6.5, "tree"], [7.5, "projection"], [7.5, "lenses"], [6.5, "first_photo"], [7.5, "overlay"],
	[11.0, "hawk"], [5.0, "hawk_ana"], [10.5, "heron"], [9.0, "wood"], [5.0, "end"],
]

var _room: Node
var _lookout: Node
var _station: Node
var _player: Node4D
var _t: float = 0.0
var _beat: int = -1
var _beat_t: float = 0.0
var _layer: CanvasLayer
var _overlay: Control
var _caption: String = ""
var _caption_t: float = 0.0
var _black: float = 1.0
var _black_goal: float = 1.0
var _end_card: bool = false
var _did: Dictionary = {}
var _cam: Camera4D
var _orbit: float = 0.0


func _initialize() -> void:
	root.unfocusable = true
	_clean()
	_room = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	for node in _room.find_children("*", "", true, false):
		if "debug_key_enabled" in node:
			node.set("debug_key_enabled", false)
	_lookout = _room.get_node("Systems/Lookout")
	_lookout.set("journal_path", TEST_BOOK)
	root.add_child(_room)
	current_scene = _room
	_layer = CanvasLayer.new()
	_layer.layer = 20
	root.add_child(_layer)
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	_layer.add_child(_overlay)


func _key(code: Key, down: bool = true, up: bool = true) -> void:
	for state in ([true] if down else []) + ([false] if up else []):
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = state
		Input.parse_input_event(e)


func _hide_hud() -> void:
	for n in HIDE:
		var item := _room.get_node_or_null("UI/" + String(n)) as CanvasItem
		if item != null:
			item.visible = false
	var label := _room.get_node_or_null("Player/StateLabel") as CanvasItem
	if label != null:
		label.visible = false


func _say(text: String) -> void:
	_caption = text
	_caption_t = 0.0


func _film_cam() -> Camera4D:
	if _cam == null or not is_instance_valid(_cam):
		_cam = Camera4D.new()
		_cam.name = "FilmCam"
		_cam.set("rendering_engine_name", "Cross-section")
		_cam.set("field_of_view_4d", 1.0)
		_room.add_child(_cam)
	_cam.make_current()
	return _cam


func _look(eye: Vector4, at: Vector4) -> void:
	var cam: Camera4D = _film_cam()
	cam.global_position = eye
	var d: Vector4 = at - eye
	cam.global_basis = Basis4D.from_zx(atan2(-d.x, -d.z)) * Basis4D.from_yz(atan2(d.y, Vector2(d.x, d.z).length()))


func _farm_camera() -> void:
	(_room.get_node("Player/CameraRig/Pitch/Camera4D") as Camera4D).make_current()
	if _cam != null and is_instance_valid(_cam):
		_cam.queue_free()
	_cam = null


func _aim(p: Vector4) -> void:
	_station.call("look_along", p - (_station.call("home_eye") as Vector4))


func _process(d: float) -> bool:
	_t += d
	_beat_t += d
	_caption_t += d
	_black = move_toward(_black, _black_goal, d / 0.45)
	_overlay.queue_redraw()
	if _beat < 0 or _beat_t >= float(BEATS[_beat][0]):
		_beat += 1
		_beat_t = 0.0
		if _beat >= BEATS.size():
			_clean()
			print("FILM DONE at %.1f s" % _t)
			return true
		_start(String(BEATS[_beat][1]))
	_during(String(BEATS[_beat][1]), d)
	return false


func _start(beat: String) -> void:
	match beat:
		"black":
			_station = _lookout.get("station")
			_player = _room.get_node("Player") as Node4D
			for f in ["approached", "met_wren", "first_climb"]:
				_lookout.get("journal").call("set_flag", f, true)
			_hide_hud()
		"tree":
			_black_goal = 0.0
			_say("The owl sits in a dead tree now: lofted, out at w +1.5")
		"projection":
			var tower: Node4D = _lookout.get("tower")
			_look(tower.global_position + Vector4(-14.0, 3.5, 20.0, 0.0), tower.global_position + Vector4(-6.0, 4.0, 0.0, 0.0))
			_say("P: the plain cut of the world, first")
		"lenses":
			_lookout.call("set_projection", false)
			_farm_camera()
			var tower: Node4D = _lookout.get("tower")
			# The camera is the lookout's: on the deck.
			_player.global_position = tower.global_position + Vector4(0.6, float(tower.get("deck_height")) + 0.05, -2.9, 0.0)
			_station.call("raise")
			_say("L: the lenses, 18 to 200 mm, and the angle each one sees")
		"first_photo":
			_station.set("zoom_goal", 1.0)
			# From the deck's south side, down at her at the foot of the tower.
			var tower: Node4D = _lookout.get("tower")
			_player.global_position = tower.global_position + Vector4(0.0, float(tower.get("deck_height")) + 0.05, 2.9, 0.0)
			_say("Your first photo is guided: Wren. Then how it was judged")
		"overlay":
			_station.call("lower")
			var tower: Node4D = _lookout.get("tower")
			_player.global_position = tower.global_position + Vector4(0.6, float(tower.get("deck_height")) + 0.05, -2.9, 0.0)
			_say("F4: the developer overlay. W depth, the slice, the numbers")
		"hawk":
			_lookout.get("dev_overlay").set("on", false)
			_lookout.get("dev_overlay").set("visible", false)
			_station.call("lower")
			_player.global_position = Vector4(0.0, 0.05, -24.0, 0.0)
			_say("U: fly the flock's own hawk. They break around you")
		"hawk_ana":
			_say("E: slide ana, out of their W. They stop caring. P shows their ghost")
		"heron":
			var hawk: Node = _lookout.get("hawk_flight")
			if bool(hawk.get("flying")):
				hawk.call("stop")
			_lookout.call("set_projection", false)
			var heron: Node4D = _lookout.get("heron")
			heron.call("perform", "stalk")
			_say("The heron, re-animated from a study of how herons move")
		"wood":
			_say("Kata of the marsh, a wood. A chipmunk goes round its tree through W")
			var chip: Node4D = (_lookout.get("chipmunks") as Array)[0]
			chip.call("perform", "round_w")
		"end":
			_farm_camera()
			_caption = ""
			_black_goal = 1.0
			_end_card = true


func _during(beat: String, d: float) -> void:
	match beat:
		"tree":
			var owl: Node4D = _lookout.get("owl")
			# From the north, away from the tower, slowly round: the whole tree and the owl on its twig.
			_orbit += d * 0.08
			var o: Vector4 = owl.global_position
			_look(o + Vector4(sin(_orbit - 0.4) * 9.0, -3.0, -cos(_orbit - 0.4) * 9.0 - 2.0, 0.0), o + Vector4(-0.8, -3.5, -1.2, 0.0))
		"projection":
			if _beat_t > 3.0 and not _did.has("proj_on"):
				_did["proj_on"] = true
				_key(KEY_P)
				_say("P, and the projection is on: the cut, plus a ghost of everything along W")
		"lenses":
			var flock: Node4D = _room.get_node("World/Flock")
			_aim(flock.global_position + flock.global_basis * (flock.get("_middle") as Vector4))
			var k: int = int(floor((_beat_t - 0.8) / 0.95))
			if k >= 0 and k < 7 and not _did.has("lens%d" % k):
				_did["lens%d" % k] = true
				_key(KEY_L)
		"first_photo":
			var wren: Node4D = _lookout.get("wren")
			_aim(wren.global_position + Vector4(0.0, 0.9, 0.0, 0.0))
			if _beat_t > 2.8 and not _did.has("shot"):
				_did["shot"] = true
				_station.call("take_photo")
		"overlay":
			if _beat_t > 0.5 and not _did.has("raise2"):
				_did["raise2"] = true
				_station.call("raise")
			if _did.has("raise2"):
				_aim((_lookout.get("owl") as Node4D).call("head_point"))
				_station.set("zoom_goal", 2.6)
			if _beat_t > 1.6 and not _did.has("f4"):
				_did["f4"] = true
				_key(KEY_F4)
			if _beat_t > 2.2:
				_station.set("focus_goal", move_toward(float(_station.get("focus_goal")), 1.5, d * 1.4))
		"hawk":
			var hawk: Node = _lookout.get("hawk_flight")
			if not _did.has("u") and _beat_t > 0.4:
				_did["u"] = true
				_key(KEY_U)
			if bool(hawk.get("flying")):
				var flock: Node4D = _room.get_node("World/Flock")
				var middle: Vector4 = flock.global_position + flock.global_basis * (flock.get("_middle") as Vector4)
				var at: Vector4 = hawk.get("at")
				var dir: Vector4 = middle - at
				hawk.set("yaw", lerp_angle(float(hawk.get("yaw")), atan2(-dir.x, -dir.z), clampf(d * 1.5, 0.0, 1.0)))
				hawk.set("pitch", lerpf(float(hawk.get("pitch")), clampf(atan2(dir.y, Vector2(dir.x, dir.z).length()), -0.6, 0.4), clampf(d * 1.5, 0.0, 1.0)))
		"hawk_ana":
			var hawk: Node = _lookout.get("hawk_flight")
			if bool(hawk.get("flying")):
				var at: Vector4 = hawk.get("at")
				at.w = move_toward(at.w, 2.5, d * 2.5)
				hawk.set("at", at)
				if _beat_t > 2.6 and not _did.has("p2"):
					_did["p2"] = true
					_key(KEY_P)
		"heron":
			var heron: Node4D = _lookout.get("heron")
			var c: Vector4 = heron.call("centre")
			if _beat_t > 4.0 and not _did.has("strike"):
				_did["strike"] = true
				heron.call("perform", "strike")
			if _beat_t > 6.4 and not _did.has("fly"):
				_did["fly"] = true
				heron.call("perform", "take_off")
			var side: Vector4 = heron.global_basis * Vector4(4.2, 0.0, 0.6, 0.0)
			_look(c + side + Vector4(0.0, 0.5, 0.0, 0.0), c)
		"wood":
			var tree: Node4D = (_lookout.get("wood") as Node4D).get("tree")
			var chip: Node4D = (_lookout.get("chipmunks") as Array)[0]
			var base: Vector4 = tree.global_position
			_look(base + Vector4(2.2, 1.3, 3.2, 0.0), Vector4(base.x, chip.global_position.y + 0.1, base.z, base.w))


func _draw_overlay() -> void:
	var s: Vector2 = _overlay.get_viewport_rect().size
	var font: Font = _overlay.get_theme_default_font()
	if _caption != "" and _black < 0.5:
		var a: float = clampf(_caption_t / 0.5, 0.0, 1.0) * 0.92
		var size_text: int = int(s.y * 0.022)
		var w: float = font.get_string_size(_caption, HORIZONTAL_ALIGNMENT_LEFT, -1, size_text).x
		var at := Vector2(s.x * 0.045, s.y * 0.36)
		_overlay.draw_rect(Rect2(at - Vector2(14.0, size_text + 10.0), Vector2(w + 28.0, size_text + 22.0)), Color(0.03, 0.04, 0.06, 0.55 * a / 0.92))
		_overlay.draw_rect(Rect2(at - Vector2(14.0, size_text + 10.0), Vector2(4.0, size_text + 22.0)), STYLE.accent.lightened(0.35) * Color(1, 1, 1, a))
		_overlay.draw_string(font, at, _caption, HORIZONTAL_ALIGNMENT_LEFT, -1, size_text, Color(1, 1, 1, a))
	if _black > 0.001:
		_overlay.draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, _black))
	if _end_card:
		var a: float = clampf(_beat_t / 0.8, 0.0, 1.0) * clampf((5.0 - _beat_t) / 0.6, 0.0, 1.0)
		var title_size: int = int(s.y * 0.06)
		var small: int = int(s.y * 0.022)
		var lines: Array = [["The Lookout, round three", title_size, 1.0],
			["the owl's tree, P projection, L lenses, F4, the hawk, the heron, the kata wood", small, 0.7],
			["Quantum Horizon R&D  ·  2 October 2026", small, 0.5]]
		var y: float = s.y * 0.42
		for l in lines:
			var w: float = font.get_string_size(String(l[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(l[1])).x
			_overlay.draw_string(font, Vector2((s.x - w) * 0.5, y), String(l[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(l[1]), Color(1, 1, 1, a * float(l[2])))
			y += float(l[1]) * 1.6


func _clean() -> void:
	if FileAccess.file_exists(TEST_BOOK):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_BOOK))
	var photos: String = ProjectSettings.globalize_path("user://lookout_journal_film3_photos")
	if DirAccess.dir_exists_absolute(photos):
		for f in DirAccess.get_files_at(photos):
			DirAccess.remove_absolute(photos + "/" + f)
		DirAccess.remove_absolute(photos)
