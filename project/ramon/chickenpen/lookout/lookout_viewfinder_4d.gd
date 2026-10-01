extends Control

## What you see through the camera at the Lookout: frame lines, the focus point, the lens
## and the film, and the W-METER - the subgame's locator.
##
## THE W-METER is the focus ring drawn as a scale along the bottom: kata to the left, ana to
## the right, the needle where the ring is. Every creature in front of you - inside the
## frame, wherever it is in W - puts a tick on the scale at its W, so you can see there is
## something out there before you can see it, and pull focus to it. A bright tick is a
## photo the journal still wants; a dim one is something you have already got. When the
## needle sits on a tick, that creature is in your slice. Kept on the scale rather than over
## the creatures, so it says WHERE in W without saying where in the picture: finding it in
## the frame is still yours to do.
##
## THE FOCUS POINT in the middle lights up in the HUD's colour when what is under it is
## sharp - a camera's focus-confirm.
##
## THE SHUTTER, on the photo: the frame goes black for the mirror (blackout()), then a toast
## comes in at the top with the thumbnail, what it was, its stars and points, and NEW PAGE
## when it is.

const STYLE := preload("res://ramon/Menu/style/menu_final_style.tres")
const HINT := "Click  shoot   ·   Wheel  zoom   ·   E / Q  focus in W   ·   T  autofocus   ·   Right-drag  turn slice   ·   R  straighten   ·   J  journal   ·   Esc  climb down"
const RIDE_HINT := "Click  shoot   ·   Wheel  zoom   ·   E / Q  focus in W   ·   T  autofocus   ·   X  whistle   ·   J  journal"

var station: Node

var _black: float = 0.0
var _black_len: float = 0.1
var _toasts: Array = []
var _note: String = ""
var _note_t: float = 0.0
var _hint_t: float = 0.0
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = get_theme_default_font()


func blackout(seconds: float) -> void:
	_black_len = maxf(seconds, 0.01)
	_black = _black_len


func flash_note(text: String) -> void:
	_note = text
	_note_t = 1.6


## A toast: [param result] from the journal's record().
func toast(result: Dictionary) -> void:
	_toasts.append({"r": result, "t": 0.0})
	while _toasts.size() > 3:
		_toasts.pop_front()


func _process(delta: float) -> void:
	_hint_t += delta
	if _black > 0.0:
		_black = maxf(_black - delta, 0.0)
	if _note_t > 0.0:
		_note_t -= delta
	# A cutscene's bars would cut them in half: they wait for it, then carry on.
	var held: bool = station != null and bool(station.get("lookout").call("story_busy"))
	for t in _toasts:
		if not held:
			t["t"] = float(t["t"]) + delta
	while not _toasts.is_empty() and float(_toasts[0]["t"]) > 4.2:
		_toasts.pop_front()
	queue_redraw()


func _draw() -> void:
	if station == null:
		return
	# The viewport's own size: a control under a CanvasLayer can lay out to nothing on
	# its first frames.
	var s: Vector2 = get_viewport_rect().size
	var mode: int = int(station.get("mode"))
	if mode != 2 and mode != 4:
		# Climbing: nothing but the toasts.
		_draw_toasts(s)
		return
	var white := Color(1.0, 1.0, 1.0, 0.82)
	var dim := Color(1.0, 1.0, 1.0, 0.38)
	var accent: Color = STYLE.accent.lightened(0.35)
	# Frame lines: corners of the picture area, a little in from the edge.
	var inset := Vector2(s.x * 0.06, s.y * 0.08)
	var arm: float = minf(s.x, s.y) * 0.05
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var p := Vector2(lerpf(inset.x, s.x - inset.x, corner.x), lerpf(inset.y, s.y - inset.y, corner.y))
		var sx: float = 1.0 if corner.x == 0.0 else -1.0
		var sy: float = 1.0 if corner.y == 0.0 else -1.0
		draw_line(p, p + Vector2(arm * sx, 0.0), white, 1.5)
		draw_line(p, p + Vector2(0.0, arm * sy), white, 1.5)
	# The focus point, lit when what is under it is sharp.
	var centre: Vector2 = s * 0.5
	var lit: bool = _sharp_under_centre()
	var ring: Color = accent if lit else white
	draw_arc(centre, 13.0, 0.0, TAU, 40, ring, 1.5 if not lit else 2.2)
	draw_line(centre - Vector2(22, 0), centre - Vector2(15, 0), ring, 1.2)
	draw_line(centre + Vector2(15, 0), centre + Vector2(22, 0), ring, 1.2)
	draw_line(centre - Vector2(0, 22), centre - Vector2(0, 15), ring, 1.2)
	draw_line(centre + Vector2(0, 15), centre + Vector2(0, 22), ring, 1.2)
	_draw_meter(s, white, dim, accent)
	# The lens, bottom left; the film, bottom right.
	var size_text: int = 15
	# The lens and the film sit level with the W-meter's line, either side of it.
	var base_y: float = _meter_y(s) + 5.0
	var lens: String = "%d mm   ×%.1f" % [int(round(float(station.call("lens_mm")))), float(station.get("zoom"))]
	draw_string(_font, Vector2(inset.x, base_y), lens, HORIZONTAL_ALIGNMENT_LEFT, -1, size_text, white)
	var film_text: String
	if float(station.get("reloading")) > 0.0:
		film_text = "Winding on a new roll"
	elif int(station.get("film")) <= 0:
		film_text = "Out of film"
	else:
		film_text = "%d left" % int(station.get("film"))
	var fw: float = _font.get_string_size(film_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_text).x
	draw_string(_font, Vector2(s.x - inset.x - fw, base_y), film_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_text, white)
	# The slice, top left, only when it is turned.
	var xw: float = rad_to_deg(float(station.get("slice_xw")))
	var zw: float = rad_to_deg(float(station.get("slice_zw")))
	if absf(xw) > 0.5 or absf(zw) > 0.5:
		var tilt: String = "Slice turned   xw %+.0f°   zw %+.0f°   (R straightens)" % [xw, zw]
		draw_string(_font, Vector2(inset.x, inset.y - 14.0), tilt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, accent)
	# The keys, for the first while.
	var hint_alpha: float = clampf(1.0 - (_hint_t - 14.0) / 2.0, 0.0, 1.0) * 0.62
	if hint_alpha > 0.01:
		var hint: String = RIDE_HINT if mode == 4 else HINT
		var hw: float = _font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(_font, Vector2((s.x - hw) * 0.5, s.y - 10.0), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, hint_alpha))
	if _note_t > 0.0:
		var nw: float = _font.get_string_size(_note, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string(_font, Vector2((s.x - nw) * 0.5, centre.y + 58.0), _note, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, clampf(_note_t, 0.0, 1.0)))
	_draw_toasts(s)
	if _black > 0.0:
		var k: float = _black / _black_len
		draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, clampf(k * 1.4, 0.0, 1.0)))
	elif _toasts.size() > 0 and float(_toasts[-1]["t"]) < 0.12:
		# The flash edge, a frame after the mirror comes back.
		draw_rect(Rect2(Vector2.ZERO, s), Color(1, 1, 1, 0.5), false, 3.0)


func _sharp_under_centre() -> bool:
	var subjects: Node = station.get("lookout").get("subjects")
	var cam: Camera4D = station.get("camera")
	for v in subjects.call("in_view", cam, station.call("home_eye"), station.call("slice_normal"), float(station.get("focus_range"))):
		if (v["screen"] as Vector2).length() > 0.12:
			continue
		var off: float = float(v["w"]) - float(station.get("focus"))
		if absf(off) < float(v["subject"]["w_radius"]) * 0.7:
			return true
	return false


func _draw_meter(s: Vector2, white: Color, dim: Color, accent: Color) -> void:
	var reach: float = float(station.get("focus_range"))
	var width: float = minf(s.x * 0.42, 640.0)
	var left: float = (s.x - width) * 0.5
	var y: float = _meter_y(s)
	var at := func(w: float) -> float: return left + (w + reach) / (2.0 * reach) * width
	draw_line(Vector2(left, y), Vector2(left + width, y), dim, 1.0)
	var step: float = 0.5
	var w: float = -reach
	while w <= reach + 0.001:
		var major: bool = is_equal_approx(fmod(absf(w), 1.0), 0.0)
		var x: float = at.call(w)
		draw_line(Vector2(x, y), Vector2(x, y + (7.0 if major else 4.0)), dim if not is_zero_approx(w) else white, 1.0)
		if major:
			var label: String = "0" if is_zero_approx(w) else "%+d" % int(round(w))
			var lw: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			draw_string(_font, Vector2(x - lw * 0.5, y + 22.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, dim)
		w += step
	draw_string(_font, Vector2(left - 46.0, y + 4.0), "kata", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, dim)
	draw_string(_font, Vector2(left + width + 10.0, y + 4.0), "ana", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, dim)
	# The ticks: what is out there, at its W.
	var lookout: Node = station.get("lookout")
	var journal: Node = lookout.get("journal")
	var focus: float = float(station.get("focus"))
	var subjects: Array = lookout.get("subjects").call("in_view", station.get("camera"), station.call("home_eye"), station.call("slice_normal"), reach)
	for v in subjects:
		var subject: Dictionary = v["subject"]
		var tw: float = clampf(float(v["w"]), -reach, reach)
		var x: float = at.call(tw)
		var b: Array = lookout.get("subjects").call("behaviour", subject)
		var fresh: bool = not bool(journal.call("filled", subject["page"], int(b[0])))
		var on: bool = absf(float(v["w"]) - focus) < float(subject["w_radius"]) * 0.7
		var c: Color = accent if fresh else Color(1, 1, 1, 0.45)
		if on:
			c = c.lightened(0.3)
		var r: float = 4.5 if on else 3.5
		draw_colored_polygon(PackedVector2Array([Vector2(x, y - 6.0 - r * 2.0), Vector2(x + r, y - 6.0 - r), Vector2(x, y - 6.0), Vector2(x - r, y - 6.0 - r)]), c)
	# The needle.
	var nx: float = at.call(focus)
	draw_colored_polygon(PackedVector2Array([Vector2(nx, y + 2.0), Vector2(nx - 6.0, y + 12.0), Vector2(nx + 6.0, y + 12.0)]), white)
	var readout: String = "W %+.2f m" % focus
	var rw: float = _font.get_string_size(readout, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(_font, Vector2(nx - rw * 0.5, y - 22.0), readout, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, white)


## The W-meter's line: above the key hints, below the frame lines' bottom corners.
func _meter_y(s: Vector2) -> float:
	return s.y - 58.0


func _draw_toasts(s: Vector2) -> void:
	if station != null and bool(station.get("lookout").call("story_busy")):
		return
	var y: float = 26.0
	for t in _toasts:
		var r: Dictionary = t["r"]
		var age: float = float(t["t"])
		var a: float = clampf(age / 0.2, 0.0, 1.0) * clampf((4.2 - age) / 0.5, 0.0, 1.0)
		if a <= 0.0:
			continue
		var look: Dictionary = r.get("look", {})
		var w: float = 470.0
		var h: float = 96.0
		var x: float = (s.x - w) * 0.5
		var panel := Rect2(x, y, w, h)
		draw_rect(panel, Color(0.04, 0.05, 0.08, 0.72 * a))
		draw_rect(panel, Color(1, 1, 1, 0.12 * a), false, 1.0)
		var tex: Texture2D = r.get("thumb") as Texture2D
		var thumb := Rect2(x + 8.0, y + 8.0, 142.0, 80.0)
		if tex != null:
			draw_texture_rect(tex, thumb, false, Color(1, 1, 1, a))
		var tx: float = thumb.end.x + 14.0
		var verdict: String = String(r.get("verdict", ""))
		var title: String = String(look.get("name", "Nothing in it"))
		var line2: String = String(look.get("doing", ""))
		var line3: String = ""
		var accent: Color = STYLE.accent.lightened(0.35)
		match verdict:
			"good":
				line3 = "%s pts" % _thousands(int(look.get("points", 0)))
				if bool(r.get("new_page", false)):
					line3 += "    NEW PAGE"
				elif bool(r.get("new_slot", false)):
					line3 += "    new in the journal"
				elif bool(r.get("better", false)):
					line3 += "    a better one"
			"soft":
				line3 = "Out of focus: it was at W %+.1f" % (float(station.get("focus")) + float(look.get("w_off", 0.0)))
			"small":
				line3 = "Too far away to make out"
			_:
				title = "Nothing in it"
		draw_string(_font, Vector2(tx, y + 26.0), title, HORIZONTAL_ALIGNMENT_LEFT, w - (tx - x) - 10.0, 17, Color(1, 1, 1, 0.92 * a))
		draw_string(_font, Vector2(tx, y + 50.0), line2, HORIZONTAL_ALIGNMENT_LEFT, w - (tx - x) - 96.0, 15, Color(1, 1, 1, 0.7 * a))
		draw_string(_font, Vector2(tx, y + 78.0), line3, HORIZONTAL_ALIGNMENT_LEFT, w - (tx - x) - 10.0, 14,
			(accent if verdict == "good" else Color(1, 1, 1, 0.6)) * Color(1, 1, 1, a))
		if verdict == "good" or verdict == "soft" or verdict == "small":
			var stars: int = int(look.get("stars", 0))
			for i in 4:
				star(self, Vector2(x + w - 84.0 + float(i) * 19.0, y + 45.0), 7.5, i < stars, Color(1, 1, 1, a), accent * Color(1, 1, 1, a))
		y += h + 8.0


## A five-pointed star, drawn - the default font has no star glyph.
static func star(on: CanvasItem, at: Vector2, r: float, full: bool, line: Color, fill: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var angle: float = -PI * 0.5 + float(i) * PI / 5.0
		var rr: float = r if i % 2 == 0 else r * 0.45
		pts.append(at + Vector2(cos(angle), sin(angle)) * rr)
	if full:
		on.draw_colored_polygon(pts, fill)
	else:
		pts.append(pts[0])
		on.draw_polyline(pts, Color(line.r, line.g, line.b, line.a * 0.5), 1.0)


static func _thousands(n: int) -> String:
	var s: String = str(n)
	var out: String = ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
