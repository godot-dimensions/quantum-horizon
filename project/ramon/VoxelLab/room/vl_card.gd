extends Control

## The Voxel Lab (adapted from the Arboretum's room/tree_card.gd, 6 Oct): a specimen's card, opened at
## the console beside its pedestal (E or a click), closed the
## same way or by walking off. The kit's rule for screens and overlays: black glass, white type, light
## blue for what is active (carried/kit/kit_style.gd). It sits on the right of the screen, so the specimen
## you were looking at stays in view on the left; nothing covers the exhibit.
##
## Reads exhibit.card(): code, title, kicker, method, shows, limits, rows ([label, value]), tier
## ("PRE-BAKED <date>" or "GROWN LIVE, ..."), key (what E does at the pedestal). The tier is the
## technical description's honesty: a pre-cut specimen says so; one cut in front of you
## says that.
##
## NO class_name (engine_gotchas.md).

const Style := preload("res://ramon/VoxelLab/carried/kit/kit_style.gd")
const LabPrint := preload("res://ramon/VoxelLab/carried/LabKit/lab_print.gd")

var data: Dictionary = {}
var shown: bool = false
var _a: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	var want: Vector2 = get_viewport_rect().size
	if size != want or position != Vector2.ZERO:
		position = Vector2.ZERO
		size = want
	var to: float = 1.0 if shown and not data.is_empty() else 0.0
	_a = move_toward(_a, to, delta * 6.0)
	queue_redraw()


func _draw() -> void:
	if _a <= 0.01 or data.is_empty():
		return
	var u: float = size.y / 720.0
	var a: float = 1.0 - pow(1.0 - _a, 3.0)
	var fb: Font = LabPrint.font("black")
	var fs: Font = LabPrint.font("bold")
	var fl: Font = LabPrint.font("body")
	var px_kick: int = Style.type_px("caption", u)
	var px_title: int = Style.type_px("title", u)
	var px_head: int = Style.type_px("micro", u)
	var px_body: int = Style.type_px("body", u)
	var w: float = 430.0 * u
	var pad: float = 24.0 * u
	var tw: float = w - pad * 2.0
	# Height: worked out from the text, so nothing is clipped and nothing reflows while it shows.
	var sections: Array = [["METHOD", String(data.get("method", ""))], ["WHAT IT SHOWS", String(data.get("shows", ""))], ["LIMITS", String(data.get("limits", ""))]]
	var h: float = pad + 18.0 * u + 30.0 * u + 26.0 * u
	for s in sections:
		h += 18.0 * u + _text_h(fl, String(s[1]), tw, px_body) + 10.0 * u
	var rows: Array = data.get("rows", [])
	h += 18.0 * u + 22.0 * u * float(rows.size()) + 10.0 * u + 30.0 * u + pad
	var slide: float = (1.0 - a) * 24.0 * u
	var r := Rect2(Vector2(size.x - w - 28.0 * u + slide, maxf(24.0 * u, (size.y - h) * 0.5)), Vector2(w, h))
	draw_style_box(Style.glass_box(14.0 * u, a), r)
	draw_rect(Rect2(r.position + Vector2(0.0, 18.0 * u), Vector2(maxf(2.0, 4.0 * u), h - 36.0 * u)), Color(Style.UI_ACCENT, a))
	var x: float = r.position.x + pad
	var y: float = r.position.y + pad + 12.0 * u
	draw_string(fs, Vector2(x, y), "%s   ·   %s" % [String(data.get("code", "")), String(data.get("kicker", ""))], HORIZONTAL_ALIGNMENT_LEFT, tw, px_kick, Color(Style.UI_ACCENT, a))
	y += 32.0 * u
	draw_string(fb, Vector2(x, y), String(data.get("title", "")), HORIZONTAL_ALIGNMENT_LEFT, tw, px_title, Color(Style.UI_INK, a))
	# The tier: gold for baked (made beforehand), green for live (made in front of you).
	var tier: String = String(data.get("tier", ""))
	if not tier.is_empty():
		var live: bool = tier.begins_with("GROWN LIVE")
		var col: Color = Style.UI_LIVE if live else Style.UI_GOLD
		var tsz: Vector2 = fs.get_string_size(tier, HORIZONTAL_ALIGNMENT_LEFT, -1, px_head)
		var pill := Rect2(Vector2(x, y + 10.0 * u), Vector2(minf(tsz.x + 20.0 * u, tw), 20.0 * u))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(col, 0.16 * a)
		sb.border_color = Color(col, 0.8 * a)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(int(10.0 * u))
		draw_style_box(sb, pill)
		draw_string(fs, Vector2(pill.position.x + 10.0 * u, pill.position.y + 14.0 * u), tier, HORIZONTAL_ALIGNMENT_LEFT, tw - 20.0 * u, px_head, Color(col, a))
	y += 26.0 * u + 22.0 * u
	for s in sections:
		draw_string(fs, Vector2(x, y), String(s[0]), HORIZONTAL_ALIGNMENT_LEFT, tw, px_head, Color(Style.UI_INK_DIM, Style.UI_INK_DIM.a * a))
		y += 16.0 * u
		draw_multiline_string(fl, Vector2(x, y + px_body * 0.8), String(s[1]), HORIZONTAL_ALIGNMENT_LEFT, tw, px_body, -1, Color(Style.UI_INK_SOFT, Style.UI_INK_SOFT.a * a))
		y += _text_h(fl, String(s[1]), tw, px_body) + 12.0 * u
	draw_string(fs, Vector2(x, y), "MEASURED", HORIZONTAL_ALIGNMENT_LEFT, tw, px_head, Color(Style.UI_INK_DIM, Style.UI_INK_DIM.a * a))
	y += 8.0 * u
	for row in rows:
		y += 22.0 * u
		draw_line(Vector2(x, y - 16.0 * u), Vector2(x + tw, y - 16.0 * u), Color(1, 1, 1, 0.07 * a), 1.0)
		draw_string(fl, Vector2(x, y), String(row[0]), HORIZONTAL_ALIGNMENT_LEFT, tw * 0.45, px_body, Color(Style.UI_INK_DIM, Style.UI_INK_DIM.a * a))
		draw_string(fs, Vector2(x + tw * 0.45, y), String(row[1]), HORIZONTAL_ALIGNMENT_RIGHT, tw * 0.55, px_body, Color(Style.UI_INK, a))
	y += 30.0 * u
	var key: String = String(data.get("key", ""))
	if not key.is_empty():
		_key_cap(Vector2(x, y - 15.0 * u), "E", u, a)
		draw_string(fl, Vector2(x + 30.0 * u, y), "at the pedestal:  " + key, HORIZONTAL_ALIGNMENT_LEFT, tw - 30.0 * u, px_body, Color(Style.UI_INK_SOFT, Style.UI_INK_SOFT.a * a))


func _key_cap(at: Vector2, k: String, u: float, a: float) -> void:
	var r := Rect2(at, Vector2(22.0 * u, 20.0 * u))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.08 * a)
	sb.border_color = Color(1, 1, 1, 0.55 * a)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(int(4.0 * u))
	draw_style_box(sb, r)
	draw_string(LabPrint.font("bold"), Vector2(r.position.x, r.position.y + 14.5 * u), k, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, Style.type_px("micro", u), Color(1, 1, 1, a))


func _text_h(f: Font, text: String, width: float, px: int) -> float:
	return f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, px).y
