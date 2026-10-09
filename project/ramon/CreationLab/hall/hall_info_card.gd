extends Control

## The creature hall's info card (PLAN_V2 part J; Ramon's walkthrough item 21: "a proximity info HUD ...
## dismissed with left click"). Come near a station and its card slides in at the right of the screen:
## the animal's name, a line over it, HOW IT MOVES and WHAT IS 4D ABOUT IT. One fixed size: never over the
## animal, never growing or shrinking with distance (the lab's rule from 4 Oct). The lab's overlay look:
## dark glass, white type, the blue accent (kit_style.gd).
##
## The hall decides which card shows (show_card / hide_card); a left click closes it, and the hall keeps
## it closed until you have walked away from that station and come back.
##
## NO class_name (engine_gotchas.md).

const Style := preload("res://ramon/CreationLab/kit/kit_style.gd")
const LabPrint := preload("res://ramon/CreationLab/LabKit/lab_print.gd")

var close_hint: String = "LEFT CLICK  ·  CLOSE"
var _card: Dictionary = {}
var _shown: bool = false
var _a: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func showing() -> bool:
	return _shown


func show_card(card: Dictionary) -> void:
	_card = card
	_shown = true


func hide_card() -> void:
	_shown = false


func _process(delta: float) -> void:
	size = get_viewport_rect().size
	var to: float = 1.0 if _shown else 0.0
	var was: float = _a
	_a = move_toward(_a, to, delta / 0.22)
	if _a != was or _a > 0.0:
		queue_redraw()


func _draw() -> void:
	if _a <= 0.001 or _card.is_empty() or size.y < 8.0:
		return
	var u: float = size.y / 720.0
	var e: float = ease(_a, 0.4)
	var fb: Font = LabPrint.font("black")
	var fs: Font = LabPrint.font("bold")
	var fl: Font = LabPrint.font("body")
	var cw: float = 330.0 * u
	var pad: float = 20.0 * u
	var tw: float = cw - pad * 2.0
	var body_px: int = Style.type_px("body", u)
	var line_h: float = float(body_px) * 1.35
	var moves: String = String(_card.get("moves", ""))
	var four_d: String = String(_card.get("four_d", ""))
	var moves_lines: int = _line_count(fl, moves, tw, body_px)
	var four_lines: int = _line_count(fl, four_d, tw, body_px)
	var ch: float = pad + 18.0 * u + 34.0 * u + 18.0 * u + (16.0 * u + line_h * float(moves_lines)) + 14.0 * u \
		+ (16.0 * u + line_h * float(four_lines)) + 30.0 * u + pad
	# At the right, a third of the way down, sliding in from the edge as it fades up.
	var x: float = size.x - cw - 28.0 * u + (1.0 - e) * 40.0 * u
	var y: float = size.y * 0.3
	var a: float = e
	var box := Style.glass_box(14.0 * u, a)
	draw_style_box(box, Rect2(Vector2(x, y), Vector2(cw, ch)))
	# The blue edge down its left.
	draw_rect(Rect2(Vector2(x, y + 14.0 * u), Vector2(3.0 * u, ch - 28.0 * u)), Color(Style.UI_ACCENT, a))
	var cy: float = y + pad + 12.0 * u
	draw_string(fs, Vector2(x + pad, cy), String(_card.get("kicker", "")), HORIZONTAL_ALIGNMENT_LEFT, tw, Style.type_px("micro", u), Color(Style.UI_ACCENT, a))
	cy += 34.0 * u
	draw_string(fb, Vector2(x + pad, cy), String(_card.get("title", "")), HORIZONTAL_ALIGNMENT_LEFT, tw, Style.type_px("title", u), Color(1, 1, 1, a))
	cy += 18.0 * u
	cy = _section(fs, fl, "HOW IT MOVES", moves, x + pad, cy, tw, u, line_h, body_px, a)
	cy += 14.0 * u
	cy = _section(fs, fl, "WHAT IS 4D ABOUT IT", four_d, x + pad, cy, tw, u, line_h, body_px, a)
	draw_string(fs, Vector2(x + pad, y + ch - pad), close_hint, HORIZONTAL_ALIGNMENT_LEFT, tw, Style.type_px("micro", u), Color(Style.UI_INK_DIM, a * Style.UI_INK_DIM.a))


func _section(fs: Font, fl: Font, head: String, text: String, x: float, y: float, w: float, u: float, line_h: float, px: int, a: float) -> float:
	y += 16.0 * u
	draw_string(fs, Vector2(x, y), head, HORIZONTAL_ALIGNMENT_LEFT, w, Style.type_px("micro", u), Color(Style.UI_INK_DIM, a * Style.UI_INK_DIM.a))
	for line in _wrap(fl, text, w, px):
		y += line_h
		draw_string(fl, Vector2(x, y), line, HORIZONTAL_ALIGNMENT_LEFT, w, px, Color(1, 1, 1, a * 0.92))
	return y


func _line_count(f: Font, text: String, w: float, px: int) -> int:
	return maxi(1, _wrap(f, text, w, px).size())


## Words to lines no wider than `w`.
static func _wrap(f: Font, text: String, w: float, px: int) -> PackedStringArray:
	var out := PackedStringArray()
	var line: String = ""
	for word in text.split(" ", false):
		var t: String = word if line.is_empty() else line + " " + word
		if f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > w and not line.is_empty():
			out.append(line)
			line = word
		else:
			line = t
	if not line.is_empty():
		out.append(line)
	return out
