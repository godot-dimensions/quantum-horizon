extends Node

## A short camera move for the Lookout's story beats: the first sight of the tower, the
## balloon lifting off. A few keyed points, eased; letterbox bars; an optional title; Escape
## skips. Small on purpose - "small cutscenes for payoffs, or to create anticipation, but all
## within reason" (Ramon, 1 Oct) - so each one is a handful of seconds and a single move.
##
## IT BORROWS THE PEN as the cinematic does, more lightly: the HUD put away, the player
## frozen where they stand (still shown - they are in the shot), its own camera, and all
## of it handed back at the end. When the station is already borrowing (the owl's reveal,
## up in the cab), it only takes the camera for a moment and gives the station's back.
##
## A KEY is [time share 0-1, eye, look-at point]; between keys the eye and the look-at both
## ease (smoothstep), so a move starts and stops without a jolt.

signal done

var lookout: Node

var _cam: Camera4D
var _keys: Array = []
var _length: float = 4.0
var _t: float = 0.0
var _playing: bool = false
var _layer: CanvasLayer
var _bars: Control
var _title: String = ""
var _saved: Dictionary = {}
var _light: bool = false
var _back_to: Camera4D
var _on_done: Callable = Callable()


func _ready() -> void:
	set_process(false)
	set_process_input(false)


func is_playing() -> bool:
	return _playing


## Plays [param keys] over [param seconds]. [param light]: the station is already holding
## the pen; just borrow the picture.
func play(keys: Array, seconds: float, title: String = "", light: bool = false, then: Callable = Callable()) -> void:
	if _playing or keys.size() < 2:
		return
	_keys = keys
	_length = maxf(seconds, 0.5)
	_title = title
	_light = light
	_on_done = then
	_t = 0.0
	var room: Node = lookout.get("room")
	# The camera raised on foot comes down FIRST: it is holding the HUD too, and if it gave it
	# back mid-cutscene, this would then give back its own hidden copy and the HUD would stay
	# gone.
	var station: Node = lookout.get("station")
	if not light and station != null and int(station.get("mode")) == 5:
		station.call("lower")
	# The same for the hawk: you land first.
	var hawk: Node = lookout.get("hawk_flight")
	if not light and hawk != null and bool(hawk.get("flying")):
		hawk.call("stop")
	_back_to = lookout.call("current_camera")
	if not light:
		var hud: Dictionary = {}
		for child in room.get_node("UI").get_children():
			if child is CanvasItem:
				hud[child] = (child as CanvasItem).visible
				(child as CanvasItem).visible = false
		var player: Node4D = lookout.get("player")
		_saved = {"hud": hud, "input": player.get("input_enabled"), "mode": player.process_mode}
		player.set("input_enabled", false)
		player.process_mode = Node.PROCESS_MODE_DISABLED
	_cam = Camera4D.new()
	_cam.name = "LookoutCutsceneCamera"
	_cam.set("rendering_engine_name", "Cross-section")
	_cam.set("field_of_view_4d", 1.05)
	room.add_child(_cam)
	_place(0.0)
	_cam.make_current()
	_layer = CanvasLayer.new()
	_layer.layer = 9
	add_child(_layer)
	_bars = Control.new()
	_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bars.draw.connect(_draw_bars)
	_layer.add_child(_bars)
	_playing = true
	set_process(true)
	set_process_input(true)


func skip() -> void:
	if _playing:
		_t = maxf(_t, _length - 0.35)


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		if key.keycode == KEY_ESCAPE:
			skip()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_t += delta
	var k: float = clampf(_t / _length, 0.0, 1.0)
	_place(k)
	_bars.queue_redraw()
	if k >= 1.0:
		_finish()


func _place(k: float) -> void:
	var i: int = 0
	while i < _keys.size() - 2 and k > float(_keys[i + 1][0]):
		i += 1
	var a: Array = _keys[i]
	var b: Array = _keys[i + 1]
	var u: float = smoothstep(0.0, 1.0, clampf((k - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001), 0.0, 1.0))
	var eye: Vector4 = (a[1] as Vector4).lerp(b[1], u)
	var at: Vector4 = (a[2] as Vector4).lerp(b[2], u)
	_cam.global_position = eye
	var d: Vector4 = at - eye
	var flat := Vector2(d.x, d.z)
	_cam.global_basis = Basis4D.from_zx(atan2(-d.x, -d.z)) * Basis4D.from_yz(atan2(d.y, maxf(flat.length(), 0.0001)))


func _draw_bars() -> void:
	var s: Vector2 = _bars.get_viewport_rect().size
	var k: float = clampf(_t / 0.4, 0.0, 1.0) * clampf((_length - _t) / 0.4, 0.0, 1.0)
	var bar: float = s.y * 0.11 * k
	_bars.draw_rect(Rect2(0, 0, s.x, bar), Color.BLACK)
	_bars.draw_rect(Rect2(0, s.y - bar, s.x, bar), Color.BLACK)
	if _title != "":
		var font: Font = _bars.get_theme_default_font()
		var a: float = clampf((_t - 0.5) / 0.6, 0.0, 1.0) * clampf((_length - 0.6 - _t) / 0.6, 0.0, 1.0)
		var size_text: int = 30
		var w: float = font.get_string_size(_title, HORIZONTAL_ALIGNMENT_LEFT, -1, size_text).x
		_bars.draw_string(font, Vector2((s.x - w) * 0.5, s.y - bar - 34.0), _title, HORIZONTAL_ALIGNMENT_LEFT, -1, size_text, Color(1, 1, 1, 0.9 * a))


func _finish() -> void:
	_playing = false
	set_process(false)
	set_process_input(false)
	if not _light:
		var hud: Dictionary = _saved.get("hud", {})
		for item in hud:
			if is_instance_valid(item):
				(item as CanvasItem).visible = hud[item]
		var player: Node4D = lookout.get("player")
		player.process_mode = _saved.get("mode", Node.PROCESS_MODE_INHERIT)
		player.set("input_enabled", _saved.get("input", true))
	if is_instance_valid(_back_to):
		_back_to.make_current()
	elif lookout.get("farm_camera") != null:
		(lookout.get("farm_camera") as Camera4D).make_current()
	if is_instance_valid(_cam):
		_cam.queue_free()
	if is_instance_valid(_layer):
		_layer.queue_free()
	_cam = null
	_layer = null
	if _on_done.is_valid():
		_on_done.call()
	done.emit()
