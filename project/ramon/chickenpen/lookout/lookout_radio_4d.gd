extends Control

## Wren on the radio: her lines as subtitles while you are up the tower or in the balloon,
## and on the ground when she calls.
##
## SUBTITLES THAT TAKE NO INPUT. The pen's dialogue box wants a click or a key to move on,
## and up here the click is the shutter. So the radio advances by itself - each line held
## for as long as it takes to read (a second and a bit, plus a twentieth of a second a
## letter) - and nothing you press is taken from you. A squelch at the start of a call and
## at its end, as a walkie-talkie does.
##
## Drawn low in the middle, above the viewfinder's W-meter, on its own canvas layer so it is
## there in the cab, the basket and on foot alike.

const STYLE := preload("res://ramon/Menu/style/menu_final_style.tres")

signal finished

var lookout: Node

var _queue: Array = []
var _line: Dictionary = {}
## The last line said, kept for the fade out after the call ends.
var _last: Dictionary = {}
var _left: float = 0.0
var _fade: float = 0.0
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = get_theme_default_font()


func busy() -> bool:
	return not _line.is_empty() or not _queue.is_empty()


## Queues [param lines], spoken by [param speaker].
func say(lines: Array, speaker: String = "Wren") -> void:
	var opening: bool = not busy()
	for line in lines:
		_queue.append({"speaker": speaker, "text": String(line)})
	if opening:
		lookout.call("sound", &"radio_on")
		_next()


## Stops the call at once (a cutscene starting, the scene going away).
func hush() -> void:
	_queue.clear()
	_line = {}
	_left = 0.0


func _next() -> void:
	if _queue.is_empty():
		_line = {}
		lookout.call("sound", &"radio_off")
		finished.emit()
		return
	_line = _queue.pop_front()
	_last = _line
	_left = 1.3 + 0.055 * float(String(_line["text"]).length())


func _process(delta: float) -> void:
	# The journal open over it: the call waits, out of sight, until the book is shut.
	var book: Node = lookout.get("book") if lookout != null else null
	if book != null and bool(book.call("is_open")):
		_fade = move_toward(_fade, 0.0, delta / 0.15)
		queue_redraw()
		return
	if not _line.is_empty():
		_left -= delta
		if _left <= 0.0:
			_next()
	_fade = move_toward(_fade, 1.0 if not _line.is_empty() else 0.0, delta / 0.2)
	queue_redraw()


func _draw() -> void:
	if _fade <= 0.001 or _last.is_empty():
		return
	var s: Vector2 = get_viewport_rect().size
	var shown: Dictionary = _line if not _line.is_empty() else _last
	var text: String = String(shown.get("text", ""))
	var speaker: String = String(shown.get("speaker", "Wren"))
	var size_text: int = 17
	var max_w: float = minf(s.x * 0.5, 680.0)
	var lines: PackedStringArray = _wrap(text, max_w, size_text)
	var h: float = 30.0 + float(lines.size()) * (float(size_text) + 7.0)
	var w: float = 0.0
	for l in lines:
		w = maxf(w, _font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, size_text).x)
	w = maxf(w, 160.0) + 40.0
	# Just above the W-meter's readout, low enough to keep the middle of the frame clear;
	# in a cutscene, down in the bottom bar, as a film's subtitles are.
	var at := Vector2((s.x - w) * 0.5, s.y - 100.0 - h)
	if lookout != null and bool(lookout.call("story_busy")):
		at.y = s.y - s.y * 0.055 - h * 0.5
	var a: float = _fade
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.04, 0.05, 0.08, 0.66 * a)
	box.border_color = Color(1, 1, 1, 0.08 * a)
	box.set_border_width_all(1)
	box.set_corner_radius_all(9)
	draw_style_box(box, Rect2(at, Vector2(w, h)))
	var accent: Color = STYLE.accent.lightened(0.4)
	draw_string(_font, at + Vector2(20.0, 19.0), "%s  ·  radio" % speaker.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, accent * Color(1, 1, 1, a))
	var y: float = at.y + 26.0 + float(size_text)
	for l in lines:
		draw_string(_font, Vector2(at.x + 20.0, y), l, HORIZONTAL_ALIGNMENT_LEFT, -1, size_text, Color(1, 1, 1, 0.92 * a))
		y += float(size_text) + 7.0


func _wrap(text: String, width: float, font_size: int) -> PackedStringArray:
	var out := PackedStringArray()
	var line: String = ""
	for word in text.split(" "):
		var trial: String = word if line == "" else line + " " + word
		if _font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width and line != "":
			out.append(line)
			line = word
		else:
			line = trial
	if line != "":
		out.append(line)
	return out
