extends Control

## What you see through the camera: a viewfinder, so it is never in doubt that you are
## looking through one (Ramon, 2 Oct: "it's not clear to me I'm in a camera mode").
##
## THE MATTE. Dark bars top and bottom slide in when the camera comes up (raised()), and the
## picture area between them gets a camera's frame corners and focus point. The bars carry
## the camera's state the way a real viewfinder's strip does: the mode and the film above,
## the W-meter and the keys below.
##
## THE ZOOM, ON A W-T BAR (camcorders, DJI's focal-length bar, Fujifilm's display): a scale up
## the right side from W (wide) to T (tele), logarithmic, with stops at 1x 2x 4x 8x and 12x as
## DJI's app marks them, the slider moving the same way as the wheel. Beside it the focal
## length in mm and the field of view. While you zoom, it lights up, the magnification shows
## big at the top of the frame, and the frame you had a moment ago is drawn shrinking away -
## so the zoom is felt as well as read.
##
## THE W-METER, the first locator: the focus ring drawn as a scale, kata to ana, the needle
## where the ring is, a tick for every creature in front of you at its W. Bright ticks are
## photos the journal still wants. A shaded band round the needle is the depth of field - what
## is inside it is in your slice - and creatures near the needle are named.
##
## THE GHOST RINGS, the second locator: where in the PICTURE the creatures off your slice are.
## A dashed ring at each one's place in the frame, with the W to turn the ring to. The meter
## says where in W, the rings say where in the frame; the two together find anything.
##
## TWO OF THE PEN'S OWN CARDS, over the viewfinder (Ramon, 2 Oct: "a metric hud that is
## similar in style to the hud of the original chicken pen ... like an overlay"; "all
## features or modes should also be keymapped in this transparent hud"). Top left, the
## camera's metrics in the murmuration card's style - the slice offset, the lens, what is in
## your slice and how much of it, what the judge goes by - with F3 to hide it; top right,
## every key the camera has in this mode, on the controls card's chips. The Playable World
## is visibly experimental; this is where the camera says so.

const STYLE := preload("res://ramon/Menu/style/menu_final_style.tres")
## [key, what it does] per mode, for the keys card.
const KEYS_HELD := [["Click", "shoot"], ["Wheel", "zoom"], ["L", "next lens (Shift: back)"], ["E  Q", "focus ring, through W"], ["T", "autofocus"],
	["RMB", "hold and drag: turn the slice"], ["R", "straighten the slice"], ["P", "projection on / off"], ["WASD", "walk"], ["J", "field journal"],
	["B", "balloon, when it is up"], ["Z", "lower the camera"], ["F3", "metrics card"], ["F4", "developer overlay"]]
const KEYS_CAB := [["Click", "shoot"], ["Wheel", "zoom"], ["L", "next lens (Shift: back)"], ["E  Q", "focus ring, through W"], ["T", "autofocus"],
	["RMB", "hold and drag: turn the slice"], ["R", "straighten the slice"], ["P", "projection on / off"], ["J", "field journal"], ["Esc", "climb down"],
	["F3", "metrics card"], ["F4", "developer overlay"]]
const KEYS_RIDE := [["Click", "shoot"], ["Wheel", "zoom"], ["L", "next lens (Shift: back)"], ["E  Q", "focus ring, through W"], ["T", "autofocus"],
	["Space", "burner: up (let go to sink)"], ["X", "whistle"], ["P", "projection on / off"], ["J", "field journal"], ["Esc", "ask Wren to land"], ["F3", "metrics card"], ["F4", "developer overlay"]]

## The journal's secret pages, for keeping their names off the meter until they are found.
const JOURNAL_PAGES_SECRET := {"owl": true, "white_starling": true, "heron": true, "chipmunks": true}

var station: Node

var _black: float = 0.0
var _black_len: float = 0.1
var _toasts: Array = []
var _note: String = ""
var _note_t: float = 0.0
var _font: Font
## The matte's slide-in: 0 down, 1 up.
var _up: float = 0.0
var _readout: bool = true
## Zoom activity: seconds since the last change, and the frames drawn shrinking away.
var _zoom_seen: float = 1.0
## Seconds since the viewfinder came up, for anything that pulses.
var _clock: float = 0.0
var _in_view_cache: Array = []
## The metrics and keys cards: their own canvas item, redrawn four times a second rather than
## every frame - they are seventy-odd strings, which drawn every frame cost a millisecond and a
## half, and their numbers do not need to move faster than you can read them.
var _cards: Control
var _cards_t: float = 0.0
## What drawing the viewfinder costs, microseconds a frame (a running mean): for the F4 overlay.
var draw_usec: float = 0.0
## The canvas item the cards' draw calls go to.
var _c: CanvasItem
var _in_view_frame: int = -1
var _behaviour_cache: Dictionary = {}
var _behaviour_frame: int = -1
var _zoom_last: float = 1.0
var _zoom_rings: Array = []
## Where the keys card ends, so the zoom bar starts under it.
var _keys_bottom: float = 0.0
var _card: StyleBoxFlat
var _chip: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = get_theme_default_font()
	# The pen's card and key chip (flock_stats_panel_4d.gd, pen_controls_4d.gd).
	_card = StyleBoxFlat.new()
	_card.bg_color = Color(0.04, 0.05, 0.08, 0.34)
	_card.border_color = Color(1.0, 1.0, 1.0, 0.07)
	_card.set_border_width_all(1)
	_card.set_corner_radius_all(9)
	_chip = StyleBoxFlat.new()
	_chip.bg_color = Color(1.0, 1.0, 1.0, 0.11)
	_chip.border_color = Color(1.0, 1.0, 1.0, 0.20)
	_chip.set_border_width_all(1)
	_chip.set_corner_radius_all(4)
	_cards = Control.new()
	_cards.name = "Cards"
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cards.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_cards)
	_cards.draw.connect(_draw_cards)


func raised() -> void:
	_up = 0.0


func blackout(seconds: float) -> void:
	_black_len = maxf(seconds, 0.01)
	_black = _black_len


func flash_note(text: String) -> void:
	_note = text
	_note_t = 1.6


func toast(result: Dictionary) -> void:
	_toasts.append({"r": result, "t": 0.0})
	while _toasts.size() > 3:
		_toasts.pop_front()


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F3:
		_readout = not _readout
		_cards_t = 0.0
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_clock += delta
	_up = move_toward(_up, 1.0, delta / 0.35)
	if _black > 0.0:
		_black = maxf(_black - delta, 0.0)
	if _note_t > 0.0:
		_note_t -= delta
	var held: bool = station != null and bool(station.get("lookout").call("story_busy"))
	for t in _toasts:
		if not held:
			t["t"] = float(t["t"]) + delta
	while not _toasts.is_empty() and float(_toasts[0]["t"]) > 4.2:
		_toasts.pop_front()
	# Zoom activity, and a ring of the old framing each time it moves on far enough.
	if station != null:
		var z: float = float(station.get("zoom"))
		if absf(log(z) - log(_zoom_last)) > 0.004:
			_zoom_seen = 0.0
			if absf(log(z) - log(_zoom_last)) > 0.18:
				_zoom_rings.append({"from": _zoom_last, "t": 0.0})
				_zoom_last = z
				while _zoom_rings.size() > 3:
					_zoom_rings.pop_front()
		else:
			_zoom_seen += delta
	for r in _zoom_rings:
		r["t"] = float(r["t"]) + delta
	while not _zoom_rings.is_empty() and float(_zoom_rings[0]["t"]) > 0.5:
		_zoom_rings.pop_front()
	queue_redraw()
	# The cards: every frame while the matte slides in, four times a second after.
	_cards_t -= delta
	if _cards != null and (_cards_t <= 0.0 or _up < 1.0):
		_cards_t = 0.25
		_cards.queue_redraw()


## Sizes in canvas units, as the pen's cards are: the window's UI scale (pen_ui_scale_4d.gd)
## does the rest.
func _px(base: float) -> int:
	return int(round(base))


func _draw() -> void:
	if station == null:
		return
	var started: int = Time.get_ticks_usec()
	_draw_frame()
	var took: float = float(Time.get_ticks_usec() - started)
	draw_usec = took if draw_usec <= 0.0 else lerpf(draw_usec, took, 0.05)


func _draw_frame() -> void:
	var s: Vector2 = get_viewport_rect().size
	var mode: int = int(station.get("mode"))
	if mode != 2 and mode != 4 and mode != 5:
		_draw_toasts(s, 0.0)
		return
	var accent: Color = STYLE.accent.lightened(0.35)
	var white := Color(1.0, 1.0, 1.0, 0.85)
	var dim := Color(1.0, 1.0, 1.0, 0.42)
	var k: float = smoothstep(0.0, 1.0, _up)
	var top_h: float = s.y * 0.075 * k
	var bot_h: float = s.y * 0.115 * k
	# The matte, and a soft darkening at its inner edges.
	var matte := Color(0.02, 0.025, 0.03, 0.82)
	draw_rect(Rect2(0, 0, s.x, top_h), matte)
	draw_rect(Rect2(0, s.y - bot_h, s.x, bot_h), matte)
	for i in 6:
		var a: float = 0.05 * (1.0 - float(i) / 6.0) * k
		draw_rect(Rect2(0, top_h + float(i) * 3.0, s.x, 3.0), Color(0, 0, 0, a))
		draw_rect(Rect2(0, s.y - bot_h - float(i + 1) * 3.0, s.x, 3.0), Color(0, 0, 0, a))
	# Frame corners and the focus point.
	var inset := Vector2(s.x * 0.04, top_h + s.y * 0.04)
	var arm: float = minf(s.x, s.y) * 0.045
	var bottom: float = s.y - bot_h - s.y * 0.04
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var p := Vector2(lerpf(inset.x, s.x - inset.x, corner.x), lerpf(inset.y, bottom, corner.y))
		var sx: float = 1.0 if corner.x == 0.0 else -1.0
		var sy: float = 1.0 if corner.y == 0.0 else -1.0
		draw_line(p, p + Vector2(arm * sx, 0.0), white, 2.0)
		draw_line(p, p + Vector2(0.0, arm * sy), white, 2.0)
	var centre: Vector2 = s * 0.5
	var lit: bool = _sharp_under_centre()
	var ring: Color = accent if lit else white
	draw_arc(centre, _px(13), 0.0, TAU, 40, ring, 2.2 if lit else 1.5)
	for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		draw_line(centre + d * _px(15), centre + d * _px(22), ring, 1.3)
	# The top strip: the camera's mode and its film.
	var fs: int = _px(14)
	var title: String = ["", "", "LOOKOUT CAMERA  ·  in the cab", "", "LOOKOUT CAMERA  ·  in the balloon", "LOOKOUT CAMERA"][mode]
	if mode == 5 and bool(station.call("up_tower")):
		title = "LOOKOUT CAMERA  ·  on the deck"
	draw_circle(Vector2(inset.x + 6.0, top_h * 0.5 + 1.0), 4.5, Color(0.95, 0.3, 0.25, 0.9 * k))
	draw_string(_font, Vector2(inset.x + 18.0, top_h * 0.5 + fs * 0.36), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, white * Color(1, 1, 1, k))
	var film_text: String
	if float(station.get("reloading")) > 0.0:
		film_text = "Winding on a new roll"
	elif int(station.get("film")) <= 0:
		film_text = "Out of film"
	else:
		film_text = "%d shots left" % int(station.get("film"))
	var fw: float = _font.get_string_size(film_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(_font, Vector2(s.x - inset.x - fw, top_h * 0.5 + fs * 0.36), film_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, white * Color(1, 1, 1, k))
	var xw: float = rad_to_deg(float(station.get("slice_xw")))
	var zw: float = rad_to_deg(float(station.get("slice_zw")))
	if absf(xw) > 0.5 or absf(zw) > 0.5:
		var tilt: String = "SLICE TURNED   xw %+.0f°   zw %+.0f°   R straightens" % [xw, zw]
		var tw: float = _font.get_string_size(tilt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(_font, Vector2((s.x - tw) * 0.5, top_h * 0.5 + fs * 0.36), tilt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, accent * Color(1, 1, 1, k))
	_draw_ghosts(s, accent, bottom, inset.y)
	_draw_guide(s, accent, bottom, inset.y)
	_draw_zoom(s, white, dim, accent, inset, bottom)
	_draw_meter(s, bot_h, white, dim, accent)
	# The two cards are drawn by their own canvas item, four times a second (_draw_cards).
	if _note_t > 0.0:
		var nw: float = _font.get_string_size(_note, HORIZONTAL_ALIGNMENT_LEFT, -1, _px(18)).x
		draw_string(_font, Vector2((s.x - nw) * 0.5, centre.y + _px(58)), _note, HORIZONTAL_ALIGNMENT_LEFT, -1, _px(18), Color(1, 1, 1, clampf(_note_t, 0.0, 1.0)))
	_draw_toasts(s, top_h)
	if _black > 0.0:
		draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, clampf(_black / _black_len * 1.4, 0.0, 1.0)))
	elif _toasts.size() > 0 and float(_toasts[-1]["t"]) < 0.12:
		draw_rect(Rect2(Vector2(0, top_h), Vector2(s.x, s.y - top_h - bot_h)), Color(1, 1, 1, 0.5), false, 3.0)


## A subject's behaviour, once a frame (the hawk's asks the flock for its stats).
func _behaviour(subject: Dictionary) -> Array:
	var frame: int = Engine.get_process_frames()
	if frame != _behaviour_frame:
		_behaviour_frame = frame
		_behaviour_cache.clear()
	var id: String = String(subject["id"])
	if not _behaviour_cache.has(id):
		_behaviour_cache[id] = station.get("lookout").get("subjects").call("behaviour", subject)
	return _behaviour_cache[id]


## What is in front of the camera, worked out once a frame: the meter, the ghost rings, the
## guide and the metrics card all ask, and asking five times cost a millisecond a frame.
func _in_view() -> Array:
	var frame: int = Engine.get_process_frames()
	if frame == _in_view_frame:
		return _in_view_cache
	_in_view_frame = frame
	var subjects: Node = station.get("lookout").get("subjects")
	_in_view_cache = subjects.call("in_view", station.get("camera"), station.call("home_eye"), station.call("slice_normal"), float(station.get("focus_range")))
	return _in_view_cache


func _sharp_under_centre() -> bool:
	for v in _in_view():
		if (v["screen"] as Vector2).length() > 0.12:
			continue
		var off: float = float(v["w"]) - float(station.get("focus"))
		if absf(off) < float(v["subject"]["w_radius"]) * 0.7:
			return true
	return false


## The zoom on a W-T bar up the right side, with its stops, the slider, the lens in mm and the
## field of view; while zooming, the magnification big and the old framing shrinking away.
func _draw_zoom(s: Vector2, white: Color, dim: Color, accent: Color, inset: Vector2, bottom: float) -> void:
	var zoom: float = float(station.get("zoom"))
	var zmax: float = float(station.get("zoom_max"))
	var active: float = clampf(1.0 - (_zoom_seen - 0.6) / 0.6, 0.0, 1.0)
	var x: float = s.x - inset.x - _px(10)
	var y0: float = bottom - 26.0
	var y1: float = maxf(_keys_bottom + 46.0, inset.y + 60.0)
	var at := func(z: float) -> float: return lerpf(y0, y1, log(z) / log(zmax))
	var bar_c: Color = white.lerp(accent, active)
	draw_line(Vector2(x, y0), Vector2(x, y1), Color(1, 1, 1, 0.3 + 0.4 * active), 2.0)
	draw_rect(Rect2(x - 2.0, at.call(zoom), 4.0, y0 - at.call(zoom)), bar_c * Color(1, 1, 1, 0.8))
	var fs: int = _px(11)
	# The primes L steps through, marked in mm where they sit on the bar.
	var base: float = float(station.call("base_mm"))
	var chosen: int = int(station.get("lens_chosen"))
	for mm in station.get("lenses"):
		var z: float = float(mm) / maxf(base, 1.0)
		if z > zmax + 0.01 or z < 0.99:
			continue
		var y: float = at.call(z)
		var lit: bool = int(mm) == chosen and absf(zoom - z) < 0.05
		draw_line(Vector2(x - 7.0, y), Vector2(x + 7.0, y), accent if lit else dim, 1.0)
		var label: String = "%d" % int(mm)
		var lw: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(_font, Vector2(x - 12.0 - lw, y + fs * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, accent if lit else dim)
	draw_string(_font, Vector2(x - _font.get_string_size("T", HORIZONTAL_ALIGNMENT_LEFT, -1, _px(13)).x * 0.5, y1 - 10.0), "T", HORIZONTAL_ALIGNMENT_LEFT, -1, _px(13), white)
	draw_string(_font, Vector2(x - _font.get_string_size("W", HORIZONTAL_ALIGNMENT_LEFT, -1, _px(13)).x * 0.5, y0 + _px(20)), "W", HORIZONTAL_ALIGNMENT_LEFT, -1, _px(13), white)
	# The slider, and what it says.
	var ty: float = at.call(zoom)
	draw_colored_polygon(PackedVector2Array([Vector2(x - 9.0, ty - 6.0), Vector2(x - 1.0, ty), Vector2(x - 9.0, ty + 6.0)]), bar_c)
	var fov: float = rad_to_deg(float(station.get("camera").get("field_of_view_4d"))) if station.get("camera") != null else 0.0
	var lines: Array = ["×%.1f" % zoom, "%d mm" % int(round(float(station.call("lens_mm")))), "FOV %d°" % int(round(fov))]
	var ly: float = ty - _px(14)
	for i in lines.size():
		var size_i: int = _px(16) if i == 0 else _px(11)
		var w: float = _font.get_string_size(String(lines[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, size_i).x
		draw_string(_font, Vector2(x - 40.0 - w, ly), String(lines[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, size_i, (bar_c if i == 0 else white) * Color(1, 1, 1, 0.9))
		ly += float(size_i) + 3.0
	# Zooming: the lens big - in mm and in degrees, which is what a lens is to most people -
	# the magnification under it, and the frame you had shrinking away into the middle.
	if active > 0.01:
		var mm: float = float(station.call("lens_mm"))
		var big: String = "%d mm  ·  %d°" % [int(round(mm)), int(round(fov))]
		var bs: int = _px(34)
		var bw: float = _font.get_string_size(big, HORIZONTAL_ALIGNMENT_LEFT, -1, bs).x
		draw_string(_font, Vector2((s.x - bw) * 0.5, inset.y + _px(40)), big, HORIZONTAL_ALIGNMENT_LEFT, -1, bs, Color(1, 1, 1, 0.85 * active))
		var under: String = "×%.1f" % zoom
		if float(station.get("lens_chosen_t")) < 1.5:
			under = "lens %d of %d  ·  ×%.1f  ·  L for the next" % [(station.get("lenses") as PackedInt32Array).find(int(station.get("lens_chosen"))) + 1, (station.get("lenses") as PackedInt32Array).size(), zoom]
		var us: int = _px(13)
		var uw: float = _font.get_string_size(under, HORIZONTAL_ALIGNMENT_LEFT, -1, us).x
		draw_string(_font, Vector2((s.x - uw) * 0.5, inset.y + _px(40) + float(us) + 8.0), under, HORIZONTAL_ALIGNMENT_LEFT, -1, us, Color(1, 1, 1, 0.7 * active))
	for r in _zoom_rings:
		var age: float = float(r["t"]) / 0.5
		var ratio: float = float(r["from"]) / maxf(zoom, 0.01)
		if absf(ratio - 1.0) < 0.01:
			continue
		# The framing you had, as four corners, shrinking away into the middle.
		var half := Vector2(s.x, bottom - inset.y) * 0.5 * clampf(ratio, 0.05, 3.0)
		var c: Vector2 = Vector2(s.x * 0.5, (inset.y + bottom) * 0.5)
		var col := Color(1, 1, 1, 0.45 * (1.0 - age))
		var arm: float = minf(half.x, half.y) * 0.25
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			var p: Vector2 = c + half * corner
			draw_line(p, p - Vector2(corner.x * arm, 0.0), col, 1.5)
			draw_line(p, p - Vector2(0.0, corner.y * arm), col, 1.5)


## The W-meter in the bottom strip: kata to ana, the needle and its depth of field, a tick for
## every creature in front of you, the near ones named.
func _draw_meter(s: Vector2, bot_h: float, white: Color, dim: Color, accent: Color) -> void:
	var reach: float = float(station.get("focus_range"))
	var width: float = minf(s.x * 0.6, 980.0)
	var left: float = (s.x - width) * 0.5
	var y: float = s.y - bot_h + bot_h * 0.48
	var at := func(w: float) -> float: return left + (w + reach) / (2.0 * reach) * width
	var focus: float = float(station.get("focus"))
	# The depth of field round the needle: what is inside it is in your slice.
	var band: float = 0.2
	var b0: float = at.call(clampf(focus - band, -reach, reach))
	var b1: float = at.call(clampf(focus + band, -reach, reach))
	draw_rect(Rect2(Vector2(b0, y - _px(16)), Vector2(b1 - b0, _px(22))), accent * Color(1, 1, 1, 0.16))
	draw_line(Vector2(left, y), Vector2(left + width, y), Color(1, 1, 1, 0.5), 1.5)
	var w: float = -reach
	var fs: int = _px(11)
	while w <= reach + 0.001:
		var major: bool = is_equal_approx(fmod(absf(w), 1.0), 0.0)
		var x: float = at.call(w)
		draw_line(Vector2(x, y), Vector2(x, y + (_px(8) if major else _px(4))), white if is_zero_approx(w) else dim, 1.0)
		if major:
			var label: String = "0" if is_zero_approx(w) else "%+d" % int(round(w))
			var lw: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(_font, Vector2(x - lw * 0.5, y + _px(21)), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, dim)
		w += 0.5
	var ends: int = _px(13)
	draw_string(_font, Vector2(left - _font.get_string_size("kata", HORIZONTAL_ALIGNMENT_LEFT, -1, ends).x - 14.0, y + ends * 0.36), "kata", HORIZONTAL_ALIGNMENT_LEFT, -1, ends, white)
	draw_string(_font, Vector2(left + width + 14.0, y + ends * 0.36), "ana", HORIZONTAL_ALIGNMENT_LEFT, -1, ends, white)
	draw_string(_font, Vector2(left, y - _px(22)), "FOCUS RING  ·  W", HORIZONTAL_ALIGNMENT_LEFT, -1, _px(11), dim)
	var lookout: Node = station.get("lookout")
	var journal: Node = lookout.get("journal")
	var named: Array = []
	for v in _in_view():
		var subject: Dictionary = v["subject"]
		var sw: float = float(v["w"])
		var x: float = at.call(clampf(sw, -reach, reach))
		var b: Array = _behaviour(subject)
		var fresh: bool = not bool(journal.call("filled", subject["page"], int(b[0])))
		var off: float = absf(sw - focus)
		var on: bool = off < float(subject["w_radius"]) * 0.7
		var c: Color = accent if fresh else Color(1, 1, 1, 0.5)
		if on:
			c = c.lightened(0.35)
		# Taller the nearer the needle: how close it is to coming into your slice.
		var tall: float = lerpf(float(_px(7)), float(_px(16)), clampf(1.0 - off / 1.5, 0.0, 1.0))
		var r: float = float(_px(4)) + (1.5 if on else 0.0)
		draw_colored_polygon(PackedVector2Array([Vector2(x, y - 3.0 - tall), Vector2(x + r, y - 3.0 - tall + r), Vector2(x, y - 3.0), Vector2(x - r, y - 3.0 - tall + r)]), c)
		var label_name: String = String(subject["name"]).trim_prefix("The ").trim_prefix("A ")
		# A secret not found yet is a question, not a name.
		var unknown: bool = bool(JOURNAL_PAGES_SECRET.has(String(subject["page"]))) and not bool(journal.call("found", subject["page"]))
		if unknown:
			label_name = "?"
			# The owl's tick pulses until it is found: the guide to the first secret.
			if String(subject["id"]) == "owl":
				var pulse: float = fmod(_clock * 0.9, 1.0)
				draw_arc(Vector2(x, y - 3.0 - tall * 0.5), float(_px(6)) + pulse * float(_px(16)), 0.0, TAU, 24, accent * Color(1, 1, 1, 1.0 - pulse), 2.0)
				lookout.get("story").call("on_owl_tick")
		var nw: float = _font.get_string_size(label_name, HORIZONTAL_ALIGNMENT_LEFT, -1, _px(11)).x
		var clear: bool = true
		for span in named:
			if x + nw * 0.5 + 6.0 > float(span.x) and x - nw * 0.5 - 6.0 < float(span.y):
				clear = false
		if (off < 0.8 or unknown) and clear and named.size() < 3:
			named.append(Vector2(x - nw * 0.5, x + nw * 0.5))
			draw_string(_font, Vector2(x - nw * 0.5, y - tall - _px(8)), label_name, HORIZONTAL_ALIGNMENT_LEFT, -1, _px(11), c)
	# The needle and its reading.
	var nx: float = at.call(focus)
	draw_colored_polygon(PackedVector2Array([Vector2(nx, y + 2.0), Vector2(nx - _px(7), y + _px(13)), Vector2(nx + _px(7), y + _px(13))]), white)
	var readout: String = "W %+.2f m" % focus
	var rw: float = _font.get_string_size(readout, HORIZONTAL_ALIGNMENT_LEFT, -1, _px(13)).x
	draw_string(_font, Vector2(left + width - rw, y - _px(22)), readout, HORIZONTAL_ALIGNMENT_LEFT, -1, _px(13), white)


## The second locator: a dashed ring in the frame where each creature off your slice is, and
## the W to turn the ring to. Five at most, the nearest the middle first.
func _draw_ghosts(s: Vector2, accent: Color, bottom: float, top: float) -> void:
	var focus: float = float(station.get("focus"))
	var lookout: Node = station.get("lookout")
	var journal: Node = lookout.get("journal")
	var list: Array = []
	for v in _in_view():
		var off: float = float(v["w"]) - focus
		if absf(off) < float(v["subject"]["w_radius"]) * 0.9:
			continue
		list.append(v)
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a["screen"] as Vector2).length() < (b["screen"] as Vector2).length())
	for i in mini(list.size(), 4):
		var v: Dictionary = list[i]
		var sc: Vector2 = v["screen"]
		var p := Vector2((sc.x + 1.0) * 0.5 * s.x, (1.0 - sc.y) * 0.5 * s.y)
		if p.y < top or p.y > bottom:
			continue
		var subject: Dictionary = v["subject"]
		var b: Array = _behaviour(subject)
		var fresh: bool = not bool(journal.call("filled", subject["page"], int(b[0])))
		var nearness: float = clampf(1.0 - absf(float(v["w"]) - focus) / 3.5, 0.25, 1.0)
		var c: Color = (accent if fresh else Color(1, 1, 1, 1)) * Color(1, 1, 1, 0.75 * nearness)
		var r: float = float(_px(16))
		var steps: int = 16
		for k in steps:
			if k % 2 == 1:
				continue
			draw_arc(p, r, float(k) / float(steps) * TAU, float(k + 1) / float(steps) * TAU, 4, c, 1.5)
		draw_string(_font, p + Vector2(r + 4.0, _px(4)), "W %+.1f" % float(v["w"]), HORIZONTAL_ALIGNMENT_LEFT, -1, _px(11), c)


## The first photo, guided: until there is one in the book, Wren - the easy one, near and in
## your slice - gets a pulsing frame and a line under it, so the first click has a target
## rather than a radio lecture. Out of view, a line at the top says where she is.
func _draw_guide(s: Vector2, accent: Color, bottom: float, top: float) -> void:
	var lookout: Node = station.get("lookout")
	var journal: Node = lookout.get("journal")
	if bool(journal.call("flag", "first_photo")) or int(station.get("mode")) != 5 and int(station.get("mode")) != 2:
		return
	var pulse: float = 0.5 + 0.5 * sin(_clock * 4.0)
	var col: Color = accent.lightened(0.3) * Color(1, 1, 1, 0.6 + 0.4 * pulse)
	for v in _in_view():
		if String(v["subject"]["id"]) != "wren":
			continue
		var sc: Vector2 = v["screen"]
		var p := Vector2((sc.x + 1.0) * 0.5 * s.x, (1.0 - sc.y) * 0.5 * s.y)
		if p.y < top or p.y > bottom:
			break
		var half := Vector2(float(_px(34)), float(_px(52))) * (1.0 + 0.08 * pulse)
		var arm: float = float(_px(12))
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			var c: Vector2 = p + half * corner
			draw_line(c, c - Vector2(corner.x * arm, 0.0), col, 2.0)
			draw_line(c, c - Vector2(0.0, corner.y * arm), col, 2.0)
		var line: String = "Your first photo: Wren. Frame her and click."
		var lw: float = _font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, _px(13)).x
		draw_string(_font, Vector2(p.x - lw * 0.5, p.y + half.y + float(_px(20))), line, HORIZONTAL_ALIGNMENT_LEFT, -1, _px(13), col)
		return
	var hint: String = "Your first photo: Wren, by the tower. Turn until she is in the frame."
	var hw: float = _font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, _px(13)).x
	draw_string(_font, Vector2((s.x - hw) * 0.5, top + float(_px(64))), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, _px(13), col)


## The cards, on their own canvas item: the metrics card and the keys card, or neither.
func _draw_cards() -> void:
	if station == null:
		return
	var mode: int = int(station.get("mode"))
	var s: Vector2 = get_viewport_rect().size
	var k: float = smoothstep(0.0, 1.0, _up)
	var inset := Vector2(s.x * 0.04, s.y * 0.075 * k + s.y * 0.04)
	if (mode != 2 and mode != 4 and mode != 5) or not _readout:
		_keys_bottom = inset.y
		return
	_c = _cards
	_draw_readout(s, inset, STYLE.accent.lightened(0.35))
	_draw_keys(s, inset, mode)
	_c = self


## The metrics card (F3), in the murmuration card's style: a cue bar above, a heading that
## names the method, label and value rows.
func _draw_readout(_s: Vector2, inset: Vector2, accent: Color) -> void:
	var focus: float = float(station.get("focus"))
	var sharpest: String = "nothing"
	var best: float = 0.0
	var in_view: int = 0
	var in_slice: int = 0
	for v in _in_view():
		in_view += 1
		var wr: float = float(v["subject"]["w_radius"])
		var off: float = float(v["w"]) - focus
		var ratio: float = 1.0 - (off / wr) * (off / wr)
		if ratio > 0.25:
			in_slice += 1
		if ratio > best:
			best = ratio
			sharpest = "%s, %d%% of it" % [String(v["subject"]["name"]).to_lower().trim_prefix("the ").trim_prefix("a "), int(round(sqrt(ratio) * 100.0))]
	var cam: Camera4D = station.get("camera")
	var fov_deg: int = int(round(rad_to_deg(float(cam.get("field_of_view_4d"))))) if cam != null else 0
	var rows: Array = [
		["slice", "%+.2f m along its own W" % focus],
		["lens", "%d mm  ·  ×%.1f  ·  %d° view" % [int(round(float(station.call("lens_mm")))), float(station.get("zoom")), fov_deg]],
		["in view", "%d %s, %d in your slice" % [in_view, "creature" if in_view == 1 else "creatures", in_slice]],
		["sharpest", sharpest],
		["render", "the cut, and a projection of all W (P)" if bool(station.get("lookout").get("projection")) else "the plain cut (P adds the projection)"],
		["judged", "from the game's state, not pixels"],
	]
	var ts: int = 12
	var step: float = float(ts) + 7.0
	var w: float = 286.0
	var at := Vector2(inset.x - 8.0, inset.y + 4.0)
	var h: float = 12.0 + step * float(rows.size() + 2)
	_c.draw_style_box(_card, Rect2(at, Vector2(w, h)))
	_c.draw_rect(Rect2(at + Vector2(14.0, -6.0), Vector2(34.0, 3.0)), STYLE.accent.lightened(0.3))
	var x: float = at.x + 14.0
	var y: float = at.y + 12.0
	var asc: float = _font.get_ascent(ts)
	_c.draw_string(_font, Vector2(x, y + asc), "Camera  ·  a slice of 4D, live", HORIZONTAL_ALIGNMENT_LEFT, -1, ts, Color(1, 1, 1, 0.55))
	y += step
	for row in rows:
		_c.draw_string(_font, Vector2(x, y + asc), String(row[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, ts, Color(1, 1, 1, 0.45))
		_c.draw_string(_font, Vector2(x + 66.0, y + asc), String(row[1]), HORIZONTAL_ALIGNMENT_LEFT, w - 84.0, ts, Color(1, 1, 1, 0.9))
		y += step
	_c.draw_string(_font, Vector2(x, y + _font.get_ascent(ts - 2)), "F3 hides both cards", HORIZONTAL_ALIGNMENT_LEFT, -1, ts - 2, Color(1, 1, 1, 0.4))


## The keys card: every key the camera has in this mode, on the controls card's chips.
func _draw_keys(s: Vector2, inset: Vector2, mode: int) -> void:
	var keys: Array = (KEYS_RIDE if mode == 4 else (KEYS_CAB if mode == 2 else KEYS_HELD)).duplicate()
	# What F does here and now, at the top, lit.
	var context: int = 0
	if mode == 5:
		if bool(station.get("lookout").call("can_climb_down")):
			keys.push_front(["F", "climb down"])
			context = 1
		elif bool(station.call("_someone_to_talk_to")):
			keys.push_front(["F", "talk (lowers the camera)"])
			context = 1
	var ts: int = 12
	var step: float = float(ts) + 7.0
	var chip_w: float = 0.0
	var label_w: float = 0.0
	for k in keys:
		chip_w = maxf(chip_w, _font.get_string_size(String(k[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, ts - 1).x + 14.0)
		label_w = maxf(label_w, _font.get_string_size(String(k[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x)
	var w: float = 14.0 + chip_w + 10.0 + label_w + 16.0
	var h: float = 12.0 + step * float(keys.size() + 1)
	var at := Vector2(s.x - inset.x + 8.0 - w, inset.y + 4.0)
	_c.draw_style_box(_card, Rect2(at, Vector2(w, h)))
	var asc: float = _font.get_ascent(ts)
	var y: float = at.y + 12.0
	_c.draw_string(_font, Vector2(at.x + 14.0, y + asc), "Camera keys", HORIZONTAL_ALIGNMENT_LEFT, -1, ts, Color(1, 1, 1, 0.55))
	y += step
	var lit: Color = STYLE.accent.lightened(0.45)
	for i in keys.size():
		var k: Array = keys[i]
		var chip := Rect2(Vector2(at.x + 14.0, y - 1.0), Vector2(chip_w, float(ts) + 5.0))
		_c.draw_style_box(_chip, chip)
		var kw: float = _font.get_string_size(String(k[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, ts - 1).x
		_c.draw_string(_font, Vector2(chip.position.x + (chip.size.x - kw) * 0.5, y + asc), String(k[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, ts - 1, Color(1, 1, 1, 0.9))
		_c.draw_string(_font, Vector2(chip.end.x + 10.0, y + asc), String(k[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, ts, lit if i < context else Color(1, 1, 1, 0.82))
		y += step
	_keys_bottom = at.y + h


func _draw_toasts(s: Vector2, top: float) -> void:
	if station != null and bool(station.get("lookout").call("story_busy")):
		return
	var y: float = top + 14.0
	for t in _toasts:
		var r: Dictionary = t["r"]
		var age: float = float(t["t"])
		var a: float = clampf(age / 0.2, 0.0, 1.0) * clampf((4.2 - age) / 0.5, 0.0, 1.0)
		if a <= 0.0:
			continue
		var look: Dictionary = r.get("look", {})
		var w: float = 430.0
		var h: float = 128.0
		var x: float = (s.x - w) * 0.5
		var panel := Rect2(x, y, w, h)
		draw_rect(panel, Color(0.04, 0.05, 0.08, 0.78 * a))
		draw_rect(panel, Color(1, 1, 1, 0.12 * a), false, 1.0)
		var tex: Texture2D = r.get("thumb") as Texture2D
		var thumb := Rect2(x + 8.0, y + 8.0, 142.0, 112.0)
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
			# How it was judged: the four things the points are made of, as bars.
			bars(self, _font, Vector2(tx, y + 98.0), w - (tx - x) - 12.0, look, a, accent)
		y += h + 8.0


## The four things a photo is judged on, as bars in a row, each with its name over it: how big
## the subject is in the frame, how sharp (how near your slice is to the middle of it in W),
## how centred, and how rare the behaviour is. They are the judge's own numbers
## (photo_judge_4d.gd points()), read from the game's state, not from the pixels.
static func bars(on: CanvasItem, font: Font, at: Vector2, width: float, look: Dictionary, a: float, accent: Color) -> void:
	var values: Array = [
		["size", clampf(float(look.get("size", 0.0)) / 0.33, 0.0, 1.0)],
		["in focus", clampf(float(look.get("sharp", 0.0)), 0.0, 1.0)],
		["centred", clampf(float(look.get("centred", 0.0)), 0.0, 1.0)],
		["behaviour", clampf(float(look.get("stars", 0)) / 4.0, 0.0, 1.0)],
	]
	var gap: float = 8.0
	var bw: float = (width - gap * 3.0) / 4.0
	for i in values.size():
		var bx: float = at.x + float(i) * (bw + gap)
		on.draw_string(font, Vector2(bx, at.y), String(values[i][0]), HORIZONTAL_ALIGNMENT_LEFT, bw, 11, Color(1, 1, 1, 0.55 * a))
		var bar := Rect2(bx, at.y + 6.0, bw, 5.0)
		on.draw_rect(bar, Color(1, 1, 1, 0.14 * a))
		on.draw_rect(Rect2(bar.position, Vector2(bw * float(values[i][1]), 5.0)), accent * Color(1, 1, 1, a))


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
