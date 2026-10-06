extends Control

## The Voxel Lab field's screen: the numbers of the open world, live, on black glass top left (the
## lab's rule for screens), the keys along the bottom, a toast, and a cross in the middle where a
## crater would land. Sizes follow the window's height.
##
## NO class_name (engine_gotchas.md).

const Style := preload("res://ramon/VoxelLab/carried/kit/kit_style.gd")

var field: Node
var _toast: String = ""
var _toast_t: float = 0.0
var _t: float = 0.0
var _stats: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func toast(text: String) -> void:
	_toast = text
	_toast_t = 2.4


func _process(delta: float) -> void:
	_toast_t -= delta
	_t -= delta
	if _t <= 0.0 and field != null:
		_t = 0.25
		_stats = field.get("stream").call("stats")
	queue_redraw()


func _draw() -> void:
	if field == null:
		return
	var size: Vector2 = get_viewport_rect().size
	var u: float = maxf(size.y, 360.0) / 720.0
	var fb: Font = Style.ui_font("title")
	var fk: Font = Style.ui_font("key")
	var ft: Font = Style.ui_font("text")
	var stream: Node = field.get("stream")
	var v: float = float(stream.get("voxel"))
	var fr: Dictionary = field.call("frame_numbers")
	var r := Rect2(Vector2(22, 22) * u, Vector2(330, 286) * u)
	draw_style_box(Style.glass_box(14.0 * u), r)
	var x: float = r.position.x + 16 * u
	var right: float = r.end.x - 16 * u
	var y: float = r.position.y + 28 * u
	draw_string(fb, Vector2(x, y), "THE FIELD", HORIZONTAL_ALIGNMENT_LEFT, -1, int(17 * u), Style.UI_INK)
	draw_string(fk, Vector2(x, y + 18 * u), "ANDREW'S LANDSCAPE, GENERATED ROUND YOU", HORIZONTAL_ALIGNMENT_LEFT, -1, int(9 * u), Style.UI_ACCENT)
	y += 44 * u
	var swap: bool = bool(stream.get("swap"))
	var rows: Array = [
		["Load radius", "%.0f m  ([ and ])" % (float(stream.get("radius")) * v)],
		["W band", "%.0f m either side" % (float(stream.get("w_chunks")) * 8.0 * v)],
		["Chunks loaded", "%d  (%d drawn)" % [int(_stats.get("chunks", 0)), int(_stats.get("shown", 0))]],
		["Waiting to be drawable", str(int(_stats.get("waiting", 0)))],
		["Tetrahedra", _thousands(int(_stats.get("tets", 0)))],
		["Video memory", "%.0f MB" % float(_stats.get("mb", 0.0))],
		["Frame, median", "%.1f ms" % float(fr.get("median", 0.0))],
		["Frame, worst of 4 s", "%.1f ms" % float(fr.get("worst", 0.0))],
		["New chunks", "worker thread" if swap else "in the frame (engine)"],
		["You", "W %+.1f m,  slice turned %.0f°" % [float((field.get("cam") as Node4D).global_position.w), rad_to_deg(float(field.get("slice_turn")))]],
	]
	for row in rows:
		draw_string(ft, Vector2(x, y), String(row[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * u), Style.UI_INK_DIM)
		var col: Color = Style.UI_INK
		if String(row[0]) == "New chunks":
			col = Style.UI_LIVE if swap else Style.UI_WARM
		draw_string(fk, Vector2(x, y), String(row[1]), HORIZONTAL_ALIGNMENT_RIGHT, right - x, int(11 * u), col)
		y += 20 * u
	# The cross where a crater lands.
	var c: Vector2 = size * 0.5
	draw_line(c - Vector2(9, 0) * u, c + Vector2(9, 0) * u, Color(1, 1, 1, 0.8), 1.5 * u)
	draw_line(c - Vector2(0, 9) * u, c + Vector2(0, 9) * u, Color(1, 1, 1, 0.8), 1.5 * u)
	# The keys.
	var keys: Array = [["WASD", "Fly"], ["Space / C", "Up, down"], ["Q / E", "Through W"], ["Wheel", "Turn the slice"], ["Click", "Crater"],
		["[ / ]", "Radius"], ["T", "Worker / engine"], ["V", "Volume view"], ["H", "Back to the lab"]]
	var kx: float = 22 * u
	var ky: float = size.y - 22 * u
	var strip := Rect2(Vector2(kx - 10 * u, ky - 22 * u), Vector2(size.x - 2.0 * (kx - 10 * u), 32 * u))
	draw_style_box(Style.glass_box(12.0 * u), strip)
	for kv in keys:
		draw_string(fk, Vector2(kx, ky), String(kv[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * u), Style.UI_INK)
		kx += fk.get_string_size(String(kv[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * u)).x + 6 * u
		draw_string(ft, Vector2(kx, ky), String(kv[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * u), Style.UI_INK_DIM)
		kx += ft.get_string_size(String(kv[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * u)).x + 18 * u
	if _toast_t > 0.0:
		var tw: float = fk.get_string_size(_toast, HORIZONTAL_ALIGNMENT_LEFT, -1, int(13 * u)).x
		var tr := Rect2(Vector2((size.x - tw) * 0.5 - 14 * u, 24 * u), Vector2(tw + 28 * u, 32 * u))
		draw_style_box(Style.glass_box(12.0 * u), tr)
		draw_string(fk, Vector2(tr.position.x + 14 * u, tr.position.y + 21 * u), _toast, HORIZONTAL_ALIGNMENT_LEFT, -1, int(13 * u), Style.UI_INK)


static func _thousands(n: int) -> String:
	var s: String = str(absi(n))
	var out: String = ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out
