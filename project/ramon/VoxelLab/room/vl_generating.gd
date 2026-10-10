extends Control

## "GENERATING WORLD" (round 7, #82: "the player may not immediately know whether something is loading or
## whether their input was registered ... A short progress line or animated indicator would be sufficient
## ... Avoid introducing a large loading screen"): a small black-glass pill at the top of the screen while a
## world is built again, its line in the lab's blue sweeping under the words, and which world it is of how
## many. Fades in at once (the press is answered the same frame) and out when the world stands.
##
## Set `shown` and `text` from outside; nothing else.
##
## NO class_name (engine_gotchas.md).

const Style := preload("res://ramon/VoxelLab/carried/kit/kit_style.gd")

var shown: bool = false
var text: String = "GENERATING WORLD"
var _a: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_a = move_toward(_a, 1.0 if shown else 0.0, delta * (8.0 if shown else 2.5))
	_t += delta
	if _a > 0.0 or shown:
		queue_redraw()


func _draw() -> void:
	if _a <= 0.001:
		return
	var size: Vector2 = get_viewport_rect().size
	var u: float = maxf(size.y, 360.0) / 720.0
	var f: Font = Style.ui_font("key")
	var px: int = int(12 * u)
	var words: String = text + "…"
	var tw: float = f.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var r := Rect2(Vector2((size.x - tw) * 0.5 - 22 * u, 74 * u), Vector2(tw + 44 * u, 40 * u))
	draw_style_box(Style.glass_box(12.0 * u, _a), r)
	draw_string(f, Vector2(r.position.x + 22 * u, r.position.y + 21 * u), words, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(Style.UI_INK, _a))
	# The line: a track, and a bright piece of it sweeping back and forth.
	var y: float = r.position.y + 31 * u
	var x0: float = r.position.x + 22 * u
	var w: float = r.size.x - 44 * u
	draw_line(Vector2(x0, y), Vector2(x0 + w, y), Color(Style.UI_ACCENT, 0.22 * _a), 2.0 * u)
	var k: float = 0.5 - 0.5 * cos(_t * 2.4)
	var seg: float = w * 0.28
	var sx: float = x0 + (w - seg) * k
	draw_line(Vector2(sx, y), Vector2(sx + seg, y), Color(Style.UI_ACCENT, _a), 2.0 * u)
