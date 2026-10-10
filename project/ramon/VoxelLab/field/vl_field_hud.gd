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


func toast(text: String, seconds: float = 2.4) -> void:
	_toast = text
	_toast_t = seconds


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
	var r := Rect2(Vector2(22, 22) * u, Vector2(330, 232) * u)
	# The sea panel (Tab) stands where the numbers do: they wait while it is open.
	var sea: Control = field.get("sea_panel")
	var numbers: bool = sea == null or not sea.visible
	if numbers:
		draw_style_box(Style.glass_box(14.0 * u), r)
	var x: float = r.position.x + 16 * u
	var right: float = r.end.x - 16 * u
	var y: float = r.position.y + 28 * u
	if numbers:
		draw_string(fb, Vector2(x, y), "THE OPEN WORLD", HORIZONTAL_ALIGNMENT_LEFT, -1, int(17 * u), Style.UI_INK)
		draw_string(fk, Vector2(x, y + 18 * u), "OUR LANDSCAPE, AN ISLAND OF IT, BUILT ONCE", HORIZONTAL_ALIGNMENT_LEFT, -1, int(9 * u), Style.UI_ACCENT)
	y += 44 * u
	var flying: bool = String(field.get("mode")) == "fly"
	var bird: Node = field.get("bird")
	var you: String = "on the deck, the " + String(field.call("land_name"))
	if flying and bird != null:
		var at: Vector4 = bird.get("at")
		you = "%.0f m up,  W %+.1f m,  slice %.0f°" % [at.y, at.w, float(bird.call("slice_degrees"))]
	var rows: Array = [
		["Built round the deck", "%.0f m,  W %.0f m either side" % [float(stream.get("radius")) * v, float(stream.get("w_chunks")) * 8.0 * v]],
		["Chunks", "%d  (%d drawn)" % [int(_stats.get("chunks", 0)), int(_stats.get("shown", 0))]],
		["Tetrahedra", _thousands(int(_stats.get("tets", 0)))],
		["Video memory", "%.0f MB" % float(_stats.get("mb", 0.0))],
		["Built in", "%.1f s,  ground mapped in %.0f ms" % [float(field.get("build_seconds")), float(field.get("height_map_ms"))]],
		["Frame, median", "%.1f ms" % float(fr.get("median", 0.0))],
		["Frame, worst of 4 s", "%.1f ms" % float(fr.get("worst", 0.0))],
		["You", you],
	]
	for row in rows if numbers else []:
		draw_string(ft, Vector2(x, y), String(row[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * u), Style.UI_INK_DIM)
		draw_string(fk, Vector2(x, y), String(row[1]), HORIZONTAL_ALIGNMENT_RIGHT, right - x, int(11 * u), Style.UI_INK)
		y += 20 * u
	# The cross where a crater lands (flying only).
	var c: Vector2 = size * 0.5
	if flying:
		draw_line(c - Vector2(9, 0) * u, c + Vector2(9, 0) * u, Color(1, 1, 1, 0.8), 1.5 * u)
		draw_line(c - Vector2(0, 9) * u, c + Vector2(0, 9) * u, Color(1, 1, 1, 0.8), 1.5 * u)
	# The keys.
	var keys: Array = [["Mouse", "Steer"], ["W / S", "Flap, brake"], ["Space", "Climb"], ["Shift", "Dive"], ["Right drag", "Turn the slice"],
		["R", "Slice back"], ["Q / E", "Through W"], ["Click", "Crater"], ["V", "Projection view"], ["Tab", "Settings"], ["1", "Back to the deck"]]
	if not flying:
		keys = [["WASD", "Walk"], ["The blue platform", "Turn the slice"], ["The two stations", "Take off, change the world"], ["Tab", "Settings"],
			["The blue door behind you", "Back to the lab"]]
		# Away from the green island: the way back first (round 6, #75).
		if int(field.get("biome")) != 0:
			keys = [["Change the world station, 1", "Back to the green island"], ["WASD", "Walk"], ["The blue platform", "Turn the slice"],
				["Tab", "Settings"], ["The blue door", "Back to the lab"]]
		if String(field.get("site")) == "platform":
			keys = [["WASD", "Walk"], ["Right drag", "Turn the slice"], ["R", "Level again"], ["Space / Shift", "Platform up, down"], ["Tab", "Settings"]]
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
