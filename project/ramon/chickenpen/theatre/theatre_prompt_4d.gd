extends Control

## "There is a second part. Want it?" — and it waits.
##
## IT IS A QUESTION, NOT A COUNTDOWN. The second part is the stakeholder material, which is
## longer and drier than the three engine findings, and pushing somebody into it because
## they did not walk away fast enough is how you get an audience that has stopped reading.
## So it sits there until an answer arrives, and "no" is a real answer that ends the talk
## politely rather than a timeout.
##
## AND WALKING OUT COUNTS AS NO. The way out is open the whole time and always has been;
## somebody who leaves through it has answered. Nothing here traps them for the sake of a
## keypress.

signal answered(yes: bool)

@export var question: String = "There's a second part - the one the money people see. Want it?"
@export var yes_label: String = "Y — go on"
@export var no_label: String = "N — that's plenty"
@export var yes_key: Key = KEY_Y
@export var no_key: Key = KEY_N
@export_range(0.05, 2.0, 0.05) var fade_seconds: float = 0.4

@export_group("Look")
@export var panel_color: Color = Color(0.04, 0.06, 0.10, 0.90)
@export var edge_color: Color = Color(1.0, 0.82, 0.40, 0.9)
@export var text_color: Color = Color(0.94, 0.96, 1.0)
@export var key_color: Color = Color(1.0, 0.85, 0.42)

var _asking: bool = false
var _fade: float = 0.0
var _done: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false


func ask() -> void:
	if _done:
		return
	_asking = true
	visible = true


## For the case where they answered by leaving.
func withdraw() -> void:
	_asking = false


func is_asking() -> bool:
	return _asking


func _unhandled_key_input(event: InputEvent) -> void:
	if not _asking or _done:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == yes_key:
		_answer(true)
	elif key.keycode == no_key:
		_answer(false)


func _answer(yes: bool) -> void:
	_done = true
	_asking = false
	get_viewport().set_input_as_handled()
	answered.emit(yes)


func _process(delta: float) -> void:
	var want: float = 1.0 if _asking else 0.0
	_fade = move_toward(_fade, want, delta / maxf(fade_seconds, 0.01))
	visible = _fade > 0.01
	if visible:
		queue_redraw()


func _draw() -> void:
	if _fade <= 0.01:
		return
	var screen: Vector2 = get_viewport_rect().size
	var font: Font = ThemeDB.fallback_font
	var size: int = int(screen.y * 0.030)
	var small: int = int(screen.y * 0.024)
	var pad: float = screen.y * 0.030
	var lead: float = screen.y * 0.048

	var wide: float = font.get_string_size(question, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	wide = maxf(wide, font.get_string_size(yes_label + "        " + no_label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, small).x)
	var box := Rect2(Vector2((screen.x - wide) * 0.5 - pad, screen.y * 0.36),
		Vector2(wide + pad * 2.0, lead * 2.6 + pad))
	draw_rect(box, Color(panel_color, panel_color.a * _fade), true)
	draw_rect(box, Color(edge_color, edge_color.a * _fade * 0.8), false, 1.5)

	# draw_string places a BASELINE, so each line sits a lead below the one above it.
	var x: float = box.position.x + pad
	var y: float = box.position.y + pad + size * 0.8
	draw_string(font, Vector2(x, y), question, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
		Color(text_color, _fade))
	y += lead * 1.2
	draw_string(font, Vector2(x, y), yes_label, HORIZONTAL_ALIGNMENT_LEFT, -1, small,
		Color(key_color, _fade))
	var gap: float = font.get_string_size(yes_label, HORIZONTAL_ALIGNMENT_LEFT, -1,
		small).x + pad * 1.6
	draw_string(font, Vector2(x + gap, y), no_label, HORIZONTAL_ALIGNMENT_LEFT, -1, small,
		Color(text_color, _fade * 0.75))
