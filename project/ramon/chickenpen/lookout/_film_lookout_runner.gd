extends SceneTree

## A short film of the Lookout for the morning: the real game, driven by a script and
## recorded by the movie writer (fixed 30 fps, so it is smooth whatever the machine does,
## and the slow motion records as slow motion). The sound is the game's own.
##
##   the approach   the tower, and Wren at its foot ("The Lookout")
##   Wren           she hands over her camera
##   the climb      up the ladder to the cab
##   a photo        Nike from the window, judged and in the book
##   the owl        the focus ring slides the slice along W, and there it is; its reveal
##   the balloon    it swells beside the tower
##   the ride       up, over the pen, into the starlings (a whistle, a wave), then ana: the
##                  farm thins and goes, and the marsh comes up out of nothing
##   the heron      the payoff, in slow motion
##   the journal    J, the pages
##
## Captions in the corner say what each part is. Its own journal, deleted at the end.
##
##   godot... --path project --resolution 1920x1080 --write-movie <out>.avi --fixed-fps 30
##       --script res://ramon/chickenpen/lookout/_film_lookout_runner.gd

const TEST_BOOK := "user://lookout_journal_film.cfg"
const STYLE := preload("res://ramon/Menu/style/menu_final_style.tres")
## The pen's HUD that a film does not want (the dialogue box, tags and the Journal card stay).
const HIDE := ["InfoCard", "Quests", "FlockStats", "Fps", "Objective", "Progress", "Locator", "CatchPrompt", "Hint",
	"Debug", "Again", "Controls", "ControlsHint", "LockOn", "Keeper", "CameraPicker", "Inventory", "Searcher", "SlicePlane", "Cinematics"]

var _room: Node
var _lookout: Node
var _station: Node
var _balloon: Node4D
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
var _film_cam: Camera4D

## [seconds, name]: each beat's length.
const BEATS := [
	[1.2, "black"], [6.2, "approach"], [7.5, "wren"], [4.4, "climb"], [6.5, "photo"], [8.5, "owl_focus"],
	[5.2, "owl_reveal"], [5.5, "balloon"], [7.0, "lift_off"], [5.0, "over_pen"], [6.5, "flock"],
	[11.0, "ana"], [7.5, "heron"], [6.5, "journal"], [5.0, "end"],
]


func _initialize() -> void:
	root.unfocusable = true
	_clean()
	_room = load("res://ramon/chickenpen/chickenpen_lookout.tscn").instantiate()
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


func _key(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		root.push_input(e)


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
			_balloon = _lookout.get("balloon")
			_player = _room.get_node("Player") as Node4D
			_hide_hud()
		"approach":
			_black_goal = 0.0
			var tower: Node4D = _lookout.get("tower")
			_player.global_position = tower.global_position + Vector4(6.0, 0.05, 13.0, 0.0)
		"wren":
			_hide_hud()
			var head: Node4D = _lookout.get("wren_head")
			_player.global_position = Vector4(head.global_position.x - 0.4, 0.05, head.global_position.z + 1.6, 0.0)
			_say("Wren keeps the lookout, and a journal of everything on the farm")
		"climb":
			var talk: Node = _room.get_node("Systems/WrenTalk")
			if bool(talk.call("is_running")):
				talk.call("stop")
			_lookout.get("story").call("on_camera_given")
			_player.global_position = (_lookout.get("tower") as Node4D).call("ladder_foot") + Vector4(0, 0.05, 0.3, 0)
			_did["climb_at"] = _t + 0.3
			_say("F at the ladder")
		"photo":
			var nike := _room.get_node("World/Nike") as Node4D
			_station.call("look_along", nike.global_position + Vector4(0, 0.5, 0, 0) - (_station.call("home_eye") as Vector4))
			_say("Up in the cab: a hide. Nothing sees you, nothing blocks you")
		"owl_focus":
			_say("The focus ring doesn't focus in depth. It slides your slice along W")
		"owl_reveal":
			_station.call("take_photo")
			_say("The ana owl: on a post that is only there at w +1.5")
		"balloon":
			_balloon.call("set_ready", true)
			_station.set("zoom_goal", 1.6)
			_station.set("focus_goal", 0.0)
			# From the ground, the tower behind it: from the cab the sill hides it.
			_film_cam = Camera4D.new()
			_film_cam.set("rendering_engine_name", "Cross-section")
			_film_cam.set("field_of_view_4d", 1.0)
			_room.add_child(_film_cam)
			var at: Vector4 = _balloon.global_position
			_film_cam.global_position = at + Vector4(-9.0, 2.2, 13.0, 0.0)
			var d: Vector4 = at + Vector4(2.5, 5.0, 0, 0) - _film_cam.global_position
			_film_cam.global_basis = Basis4D.from_zx(atan2(-d.x, -d.z)) * Basis4D.from_yz(atan2(d.y, Vector2(d.x, d.z).length()))
			_film_cam.make_current()
			_station.call("set_view_visible", false)
			_say("Enough photos, and Wren's balloon goes up beside the tower")
		"lift_off":
			_black_goal = 1.0
			if is_instance_valid(_film_cam):
				_film_cam.queue_free()
			_did["board_at"] = _t + 0.45
			_say("")
		"over_pen":
			_jump(31.0, 1)
			_say("Over the farm, on a rail Wren and the wind choose")
		"flock":
			_jump(60.0, 2)
			_did["whistle_at"] = _t + 2.0
			_say("Into the starlings. X whistles, and a wave goes through them")
		"ana":
			_jump(86.0, 3)
			_balloon.set("ride_speed", 2.1)
			_say("Then ana: the farm thins and goes. Nothing moved but you")
		"heron":
			_balloon.set("ride_speed", 1.0)
			_jump(maxf(float(_balloon.get("ride_time")), 114.0), 4)
			_say("And the heron, in a marsh that is only there along W")
		"journal":
			_black_goal = 1.0
			_did["book_at"] = _t + 0.45
			_say("")
		"end":
			_black_goal = 1.0
			_end_card = true
			_say("")


func _during(beat: String, _d: float) -> void:
	match beat:
		"wren":
			if _beat_t > 0.8 and not _did.has("talked"):
				_did["talked"] = true
				_key(KEY_F)
			# Two lines, at reading speed.
			if _beat_t > 3.3 and not _did.has("line2"):
				_did["line2"] = true
				_key(KEY_SPACE)
				_key(KEY_SPACE)
			if _beat_t > 5.6 and not _did.has("line3"):
				_did["line3"] = true
				_key(KEY_SPACE)
				_key(KEY_SPACE)
		"climb":
			if _did.has("climb_at") and _t >= float(_did["climb_at"]) and not _did.has("climbed"):
				_did["climbed"] = true
				_station.call("climb")
		"photo":
			var nike := _room.get_node("World/Nike") as Node4D
			# Aimed every frame: the eye leans to the window it faces, so a single aim drifts.
			_aim_at(nike.global_position + Vector4(0, 0.5, 0, 0), 0.35)
			_station.set("zoom_goal", 1.0 + clampf((_beat_t - 1.0) / 1.6, 0.0, 1.0) * 6.0)
			if _beat_t > 3.6 and not _did.has("nike_shot"):
				_did["nike_shot"] = true
				_station.call("take_photo")
		"owl_focus":
			var owl: Node4D = _lookout.get("owl")
			_aim_at(owl.call("head_point"), 0.06)
			_station.set("zoom_goal", 3.2)
			# The ring, turned slowly, as a hand would: nothing, then the post, then the owl.
			var k: float = clampf((_beat_t - 2.4) / 4.2, 0.0, 1.0)
			_station.set("focus_goal", smoothstep(0.0, 1.0, k) * 1.5)
		"lift_off":
			if _did.has("board_at") and _t >= float(_did["board_at"]) and not _did.has("boarded"):
				_did["boarded"] = true
				if int(_station.get("mode")) == 2:
					_station.call("climb_down")
				_climb_down_now()
				_balloon.call("set_ready", true, true)
				_balloon.call("board")
				_black_goal = 0.0
			if _did.has("boarded"):
				# Back at the tower as it falls away, Wren at its foot.
				_aim_at((_lookout.get("tower") as Node4D).global_position + Vector4(0, 6.0, 0, 0), 0.2)
		"over_pen":
			var pen := _room.get_node("Pen") as Node4D
			_aim_at(pen.global_position, 0.08)
			_station.set("zoom_goal", 1.4)
		"flock":
			# Where the flock's sound comes from: towards the bulk of the birds.
			var heard: Dictionary = (_room.get_node("World/Flock") as Node4D).call("sound")
			var from: Vector4 = heard.get("from", Vector4(0.0, 0.1, -1.0, 0.0))
			if from.length() > 0.05:
				var eye: Vector4 = _station.call("home_eye")
				_aim_at(eye + from.normalized() * 20.0, 0.06)
			_station.set("zoom_goal", 1.0)
			if _did.has("whistle_at") and _t >= float(_did["whistle_at"]) and not _did.has("whistled"):
				_did["whistled"] = true
				_key(KEY_X)
		"ana":
			var marsh: Node4D = _lookout.get("marsh")
			_aim_at(marsh.global_position, 0.04)
			_station.set("zoom_goal", 1.3)
		"heron":
			var heron: Node4D = _lookout.get("heron")
			_aim_at(heron.call("centre"), 0.12)
			_station.set("zoom_goal", 2.6)
			for v in _lookout.get("subjects").call("in_view", _station.get("camera"), _station.call("home_eye"), _station.call("slice_normal"), 3.0):
				if v["subject"]["id"] == "heron":
					_station.set("focus_goal", clampf(float(v["w"]), -3.0, 3.0))
			if _beat_t > 1.6 and not _did.has("heron_shot"):
				_did["heron_shot"] = true
				_station.call("take_photo")
		"journal":
			if _did.has("book_at") and _t >= float(_did["book_at"]) and not _did.has("book"):
				_did["book"] = true
				# The ride is over for the film: down, and the book open on the owl.
				if bool(_balloon.get("riding")):
					_balloon.set("ride_time", 999.0)
				_black_goal = 0.0
				_lookout.get("book").call("open_book", "owl")
			if _did.has("book") and _beat_t > 3.4 and not _did.has("page2"):
				_did["page2"] = true
				_key(KEY_DOWN)
				_key(KEY_DOWN)


## Turns the station's camera towards [param p], easing by [param rate] a frame.
func _aim_at(p: Vector4, rate: float) -> void:
	if _station == null or _station.get("camera") == null:
		return
	var eye: Vector4 = _station.call("home_eye")
	var d: Vector4 = p - eye
	var flat := Vector2(d.x, d.z)
	var yaw_goal: float = atan2(-flat.x, -flat.y)
	var pitch_goal: float = atan2(d.y, maxf(flat.length(), 0.0001))
	_station.set("yaw", lerp_angle(float(_station.get("yaw")), yaw_goal, rate))
	_station.set("pitch", lerpf(float(_station.get("pitch")), pitch_goal, rate))


## For the cut to the balloon: off the tower at once.
func _climb_down_now() -> void:
	if int(_station.get("mode")) != 0:
		_station.set("_t", 999.0)
		_station.call("_run_climb", 0.0, false)


func _draw_overlay() -> void:
	var s: Vector2 = _overlay.get_viewport_rect().size
	var font: Font = _overlay.get_theme_default_font()
	if _caption != "" and _black < 0.5:
		var a: float = clampf(_caption_t / 0.5, 0.0, 1.0) * 0.92
		var size_text: int = int(s.y * 0.022)
		var at := Vector2(s.x * 0.06, s.y * 0.08 + size_text + 34.0)
		var w: float = font.get_string_size(_caption, HORIZONTAL_ALIGNMENT_LEFT, -1, size_text).x
		_overlay.draw_rect(Rect2(at - Vector2(14.0, size_text + 10.0), Vector2(w + 28.0, size_text + 22.0)), Color(0.03, 0.04, 0.06, 0.55 * a / 0.92))
		_overlay.draw_rect(Rect2(at - Vector2(14.0, size_text + 10.0), Vector2(4.0, size_text + 22.0)), STYLE.accent.lightened(0.35) * Color(1, 1, 1, a))
		_overlay.draw_string(font, at, _caption, HORIZONTAL_ALIGNMENT_LEFT, -1, size_text, Color(1, 1, 1, a))
	if _black > 0.001:
		_overlay.draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, _black))
	if _end_card:
		var a: float = clampf(_beat_t / 0.8, 0.0, 1.0) * clampf((5.0 - _beat_t) / 0.6, 0.0, 1.0)
		var title_size: int = int(s.y * 0.06)
		var small: int = int(s.y * 0.022)
		var lines: Array = [["The Lookout", title_size, 1.0], ["Wren, the ana owl, the white starling and the heron", small, 0.7],
			["a photography game out along W  ·  Quantum Horizon R&D  ·  2 October 2026", small, 0.5]]
		var y: float = s.y * 0.42
		for l in lines:
			var w: float = font.get_string_size(String(l[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(l[1])).x
			_overlay.draw_string(font, Vector2((s.x - w) * 0.5, y), String(l[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(l[1]), Color(1, 1, 1, a * float(l[2])))
			y += float(l[1]) * 1.6


func _clean() -> void:
	var book: String = ProjectSettings.globalize_path(TEST_BOOK)
	if FileAccess.file_exists(TEST_BOOK):
		DirAccess.remove_absolute(book)
	var photos: String = ProjectSettings.globalize_path("user://lookout_journal_film_photos")
	if DirAccess.dir_exists_absolute(photos):
		for f in DirAccess.get_files_at(photos):
			DirAccess.remove_absolute(photos + "/" + f)
		DirAccess.remove_absolute(photos)


## A cut in the ride: to [param ride_time], with Wren's line for that stretch next on the
## radio (index [param line] of the balloon's RADIO) rather than every line skipped over.
func _jump(ride_time: float, line: int) -> void:
	_balloon.set("ride_time", ride_time)
	_balloon.set("_said", line)
	_lookout.get("radio").call("hush")
