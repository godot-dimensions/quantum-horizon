extends Control

## The Voxel Lab's pop-up: a small black-glass frame about the specimen you are standing at, opened
## with a click (Ramon, 8 Oct, at the shelf: "Nothing gets activated. You can only look at it. Maybe if
## you click on it, you get one little pop-up frame that says, okay, this shows blah blah blah"). It
## sits low on the left, above the control strip, so it never covers what it is about.
##
##   data   {"code", "title", "kicker", "text", "rows": [[label, value], ...]}, from the exhibit's
##          card(); empty hides it
##
## NO class_name (engine_gotchas.md).

const Style := preload("res://ramon/VoxelLab/carried/kit/kit_style.gd")
const LabPrint := preload("res://ramon/VoxelLab/carried/LabKit/lab_print.gd")

var data: Dictionary = {}
var shown: bool = false
var _a: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	size = get_viewport_rect().size
	_a = move_toward(_a, 1.0 if shown and not data.is_empty() else 0.0, delta * 7.0)
	queue_redraw()


func _draw() -> void:
	if _a <= 0.01 or data.is_empty():
		return
	var u: float = size.y / 720.0
	var w: float = 330.0 * u
	var pad: float = 16.0 * u
	var fb: Font = LabPrint.font("black")
	var fs: Font = LabPrint.font("bold")
	var fl: Font = LabPrint.font("body")
	var tpx: int = Style.type_px("title", u)
	var kpx: int = Style.type_px("micro", u)
	var bpx: int = Style.type_px("body", u)
	var text: String = String(data.get("text", ""))
	var lines: PackedStringArray = _wrap(fl, text, w - pad * 2.0, bpx)
	var rows: Array = data.get("rows", [])
	var h: float = pad + 14.0 * u + tpx * 1.3 + lines.size() * bpx * 1.35 + 8.0 * u + rows.size() * bpx * 1.45 + pad
	var r := Rect2(Vector2(28.0 * u, size.y - 62.0 * u - 22.0 * u - h - 12.0 * u), Vector2(w, h))
	r.position.y += (1.0 - _a) * 12.0 * u
	draw_style_box(Style.glass_box(12.0 * u, _a), r)
	var ink := Color(Style.UI_INK, _a)
	var dim := Color(Style.UI_INK_DIM, Style.UI_INK_DIM.a * _a)
	var acc := Color(Style.UI_ACCENT, _a)
	var y: float = r.position.y + pad + kpx
	var kicker: String = String(data.get("kicker", ""))
	var code: String = String(data.get("code", ""))
	draw_string(fs, Vector2(r.position.x + pad, y), ("%s  ·  %s" % [code, kicker]) if not code.is_empty() else kicker, HORIZONTAL_ALIGNMENT_LEFT, w - pad * 2.0, kpx, acc)
	y += 6.0 * u + tpx
	draw_string(fb, Vector2(r.position.x + pad, y), String(data.get("title", "")), HORIZONTAL_ALIGNMENT_LEFT, w - pad * 2.0, tpx, ink)
	y += tpx * 0.3
	for ln in lines:
		y += bpx * 1.35
		draw_string(fl, Vector2(r.position.x + pad, y), ln, HORIZONTAL_ALIGNMENT_LEFT, w - pad * 2.0, bpx, ink)
	y += 8.0 * u
	for row in rows:
		y += bpx * 1.45
		draw_string(fl, Vector2(r.position.x + pad, y), String(row[0]), HORIZONTAL_ALIGNMENT_LEFT, w * 0.5, bpx, dim)
		draw_string(fs, Vector2(r.position.x + pad, y), String(row[1]), HORIZONTAL_ALIGNMENT_RIGHT, w - pad * 2.0, bpx, ink)


static func _wrap(f: Font, text: String, width: float, px: int) -> PackedStringArray:
	var out := PackedStringArray()
	var line: String = ""
	for word in text.split(" ", false):
		var trial: String = word if line.is_empty() else line + " " + word
		if f.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > width and not line.is_empty():
			out.append(line)
			line = word
		else:
			line = trial
	if not line.is_empty():
		out.append(line)
	return out
