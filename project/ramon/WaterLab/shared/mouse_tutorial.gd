extends Control

## WATER LAB: a small live tutorial for the mouse (Ramon, 9 Oct: "some kind of real-time little dynamic
## HUD explainer ... the icon of a mouse and then the right mouse button activated, and then it says
## slide through W, and then you see this sort of arrow going, sliding over the right mouse button and
## sliding back ... and also maybe have arrows going to the side, so that it's clear that you can also
## rotate side to side ... about the size of the character ... make the design simple, but not crazy
## simple").
##
## ONE MOUSE, ACTING EACH GESTURE IN TURN: a mouse drawn as a mouse (a rounded body, two buttons, a
## wheel, a soft gloss; no cable), its right button lit. It moves through `gestures` one after
## another, about two seconds each: pushed forward and back (the arrows above and below lit, a chevron
## sliding along them), slid side to side (the arrows at both sides lit), the wheel rolled (the wheel
## lit, ticks rolling over it). The gesture being shown is named under it in large type, the others
## listed small. On a glass card at the left of the screen, its height about a sixth of the window's
## (the character's own size on screen, a little smaller).
##
## Shown while `shown`; it fades. A gesture is [kind, words]: kind "drag_v", "drag_h" or "wheel".
##
## THE INTRO, THEN A REMINDER (round 6, Ramon, the sea's #44: "When the player first enters the relevant
## interaction area: Display the mouse tutorial at a large, clearly visible size. Keep the animated
## instructional graphic active for approximately 10 seconds. After 10 seconds: Scale the tutorial down. Move
## it into the panel positioned above the sea information panel. Stop the animation. Leave the smaller
## graphic visible as a static reminder. The transition should feel intentional and smooth"). With `intro`
## above 0: `big_scale` times the size while it acts its gestures, for `intro` seconds of being shown; then
## over `dock_seconds` the card eases into `dock_rect` (pixels, set by its owner each frame), the mouse
## settling still and shrinking to its left, the big words fading as the reminder's lines come in: each
## gesture's motion and what it does. It stays docked from then on. With `intro` 0 (the tank room) it acts
## its gestures at its own size as before.
##
## NO class_name (engine_gotchas.md).

const LabPrint := preload("res://ramon/WaterLab/carried/LabKit/lab_print.gd")
const Style := preload("res://ramon/WaterLab/carried/kit/kit_style.gd")

var shown: bool = false
var gestures: Array = [["drag_v", "SLIDE THROUGH W"], ["drag_h", "TURN THROUGH W"]]
## Seconds each gesture is acted.
var beat: float = 2.2
## Where the card sits, as a share of the window (its left middle).
var anchor := Vector2(0.03, 0.62)
## The intro (see the header): its seconds (0: none), its size, where it docks, how long docking takes, and
## the mouse's size docked.
var intro: float = 0.0
var big_scale: float = 1.45
var dock_rect := Rect2()
var dock_seconds: float = 0.9
var dock_mouse_scale: float = 0.42
var _a: float = 0.0
var _t: float = 0.0
## Seconds shown so far, and how far docked (0 to 1).
var _seen: float = 0.0
var _dock: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	size = get_viewport_rect().size
	var before: float = _a
	var dock_before: float = _dock
	_a = move_toward(_a, 1.0 if shown else 0.0, delta * 3.0)
	if intro > 0.0 and shown:
		_seen += delta
	if intro > 0.0 and _seen >= intro:
		_dock = move_toward(_dock, 1.0, delta / maxf(dock_seconds, 0.05))
	if _a > 0.0:
		# The acting stops once docked.
		if _dock < 1.0:
			_t += delta
	else:
		_t = 0.0
	if _a > 0.0 or before != _a or dock_before != _dock:
		queue_redraw()


## How far docked, eased (0 the intro or the old card, 1 the reminder).
func _docked() -> float:
	return smoothstep(0.0, 1.0, _dock) if intro > 0.0 and dock_rect.size.x > 0.0 else 0.0


static func _lerp_rect(a: Rect2, b: Rect2, k: float) -> Rect2:
	return Rect2(a.position.lerp(b.position, k), a.size.lerp(b.size, k))


func _draw() -> void:
	if _a <= 0.001 or gestures.is_empty() or size.y < 100.0:
		return
	var su: float = size.y / 1080.0
	var e: float = _docked()
	# The intro's size (and the card's at the start of docking).
	var big: float = big_scale if intro > 0.0 else 1.0
	var full := Rect2(Vector2(size.x * anchor.x, size.y * anchor.y - 200.0 * su * big), Vector2(330.0, 400.0) * su * big)
	var card: Rect2 = _lerp_rect(full, dock_rect, e) if e > 0.0 else full
	var glass := Style.glass_box(18.0 * su * lerpf(big, 1.0, e))
	glass.bg_color.a *= _a * 0.92
	draw_style_box(glass, card)
	# The mouse and its arrows at the intro's size, shrinking as it docks to the reminder's left.
	var u: float = su * lerpf(big, dock_mouse_scale, e)
	var k: int = int(floor(_t / beat)) % gestures.size()
	var ph: float = fmod(_t, beat) / beat
	var kind: String = String(gestures[k][0])
	# Docked it acts nothing: every gesture's arrows lit, still.
	var still: bool = e >= 1.0
	var dim := Color(1, 1, 1, 0.32 * _a)
	var lit := Color(Style.UI_ACCENT, _a)
	# The mouse: 120 x 180 (u), its middle a little above the card's.
	var mw: float = 112.0 * u
	var mh: float = 172.0 * u
	var centre: Vector2 = full.position + Vector2(full.size.x * 0.5, 150.0 * su * big)
	if e > 0.0:
		centre = centre.lerp(dock_rect.position + Vector2(dock_rect.size.y * 0.62, dock_rect.size.y * 0.5 + 4.0 * su), e)
	# Acting the gesture: the mouse pushed along it, eased there and back; settling as it docks.
	var swing: float = sin(ph * TAU) * (1.0 - e)
	var move := Vector2.ZERO
	if kind == "drag_v":
		move = Vector2(0.0, -swing * 22.0 * u)
	elif kind == "drag_h":
		move = Vector2(swing * 30.0 * u, 0.0)
	var m := Rect2(centre - Vector2(mw, mh) * 0.5 + move, Vector2(mw, mh))
	# Its shadow and the body (no cable: round 3).
	_round(Rect2(m.position + Vector2(5.0, 8.0) * u, m.size), 56.0 * u, Color(0, 0, 0, 0.35 * _a))
	_round(m, 56.0 * u, Color(0.93, 0.95, 0.98, _a))
	# The buttons: the split, the right one lit (brighter while a drag is being acted).
	var split_y: float = m.position.y + mh * 0.42
	var right_btn := Rect2(Vector2(m.get_center().x + 2.0 * u, m.position.y + 3.0 * u), Vector2(mw * 0.5 - 5.0 * u, mh * 0.42 - 4.0 * u))
	var pressed: float = 1.0 if (kind != "wheel" or still) else 0.35
	_round_top(right_btn, 52.0 * u, Color(Style.UI_ACCENT.lerp(Color.WHITE, 0.15 * (1.0 - pressed)), _a * (0.55 + 0.45 * pressed)))
	draw_line(Vector2(m.position.x + 6.0 * u, split_y), Vector2(m.end.x - 6.0 * u, split_y), Color(0.55, 0.60, 0.68, _a), maxf(1.0, 2.0 * u), true)
	draw_line(Vector2(m.get_center().x, m.position.y + 4.0 * u), Vector2(m.get_center().x, split_y), Color(0.55, 0.60, 0.68, _a), maxf(1.0, 2.0 * u), true)
	# The wheel, and its ticks rolling when it is the gesture.
	var wheel := Rect2(Vector2(m.get_center().x - 9.0 * u, m.position.y + 22.0 * u), Vector2(18.0 * u, 40.0 * u))
	var wheel_lit: bool = kind == "wheel" and not still
	_round(wheel, 9.0 * u, Color(Style.UI_ACCENT, _a) if wheel_lit else Color(0.40, 0.45, 0.53, _a))
	if wheel_lit:
		for i in 3:
			var ty: float = wheel.position.y + fmod(float(i) * 13.0 * u + _t * 40.0 * u, wheel.size.y)
			draw_line(Vector2(wheel.position.x + 4.0 * u, ty), Vector2(wheel.end.x - 4.0 * u, ty), Color(1, 1, 1, 0.8 * _a), maxf(1.0, 2.0 * u))
	# A soft gloss down its left.
	draw_line(Vector2(m.position.x + 18.0 * u, split_y + 16.0 * u), Vector2(m.position.x + 18.0 * u, m.end.y - 40.0 * u), Color(1, 1, 1, 0.5 * _a), maxf(2.0, 5.0 * u), true)
	# The arrows (fixed, round where the mouse rests): above and below, and at both sides.
	var rest := centre
	var v_on: bool = kind == "drag_v" or (still and _has("drag_v"))
	var h_on: bool = kind == "drag_h" or (still and _has("drag_h"))
	_arrow(rest + Vector2(0.0, -mh * 0.5 - 70.0 * u), Vector2(0, -1), u, lit if v_on else dim)
	_arrow(rest + Vector2(0.0, mh * 0.5 + 22.0 * u), Vector2(0, 1), u, lit if v_on else dim)
	_arrow(rest + Vector2(-mw * 0.5 - 40.0 * u, 0.0), Vector2(-1, 0), u, lit if h_on else dim)
	_arrow(rest + Vector2(mw * 0.5 + 40.0 * u, 0.0), Vector2(1, 0), u, lit if h_on else dim)
	# A chevron sliding along the lit arrows, there and back (not once docked).
	if still:
		pass
	elif v_on:
		_chevron(rest + Vector2(mw * 0.5 + 34.0 * u, -swing * 40.0 * u), Vector2(0, -1 if cos(ph * TAU) > 0.0 else 1), u, lit)
	elif h_on:
		_chevron(rest + Vector2(swing * 70.0 * u, -mh * 0.5 - 30.0 * u), Vector2(1 if cos(ph * TAU) > 0.0 else -1, 0), u, lit)
	# The words: this gesture big, the others small under it (gone in the first fifth of docking: the card
	# narrows under them, and the title was cut at its edge).
	var fb: Font = LabPrint.font("black")
	var fs: Font = LabPrint.font("bold")
	var wa: float = _a * (1.0 - smoothstep(0.0, 0.2, e))
	if wa > 0.002:
		var bu: float = su * big
		var how: String = _how(kind)
		var ty0: float = full.position.y + 300.0 * bu + (card.position.y - full.position.y)
		draw_string(fs, Vector2(card.position.x, ty0), how, HORIZONTAL_ALIGNMENT_CENTER, card.size.x, int(13 * bu), Color(Style.UI_INK_DIM, wa))
		draw_string(fb, Vector2(card.position.x, ty0 + 30.0 * bu), String(gestures[k][1]), HORIZONTAL_ALIGNMENT_CENTER, card.size.x, int(24 * bu), Color(1, 1, 1, wa))
		var others: Array = []
		for i in gestures.size():
			if i != k:
				others.append(String(gestures[i][1]).to_lower())
		if not others.is_empty():
			draw_string(fs, Vector2(card.position.x, ty0 + 58.0 * bu), "  ·  ".join(others), HORIZONTAL_ALIGNMENT_CENTER, card.size.x, int(12 * bu), Color(1, 1, 1, 0.32 * wa))
	# The reminder's lines, coming in as it docks: each gesture's motion over what it does.
	var ra: float = _a * smoothstep(0.55, 1.0, e)
	if ra > 0.002:
		var x0: float = dock_rect.position.x + dock_rect.size.y * 1.24
		var tw: float = dock_rect.end.x - x0 - 16.0 * su
		var row_h: float = dock_rect.size.y / float(gestures.size() + 1)
		for i in gestures.size():
			var y: float = dock_rect.position.y + row_h * (float(i) + 1.0)
			draw_string(fs, Vector2(x0, y - 6.0 * su), _how(String(gestures[i][0])), HORIZONTAL_ALIGNMENT_LEFT, tw, int(11 * su), Color(Style.UI_INK_DIM, ra))
			draw_string(fb, Vector2(x0, y + 15.0 * su), String(gestures[i][1]), HORIZONTAL_ALIGNMENT_LEFT, tw, int(17 * su), Color(1, 1, 1, ra))


## The motion a gesture is made with, in words.
static func _how(kind: String) -> String:
	return "RIGHT MOUSE, FORWARD AND BACK" if kind == "drag_v" else ("RIGHT MOUSE, SIDE TO SIDE" if kind == "drag_h" else "THE WHEEL")


func _has(kind: String) -> bool:
	for g in gestures:
		if String(g[0]) == kind:
			return true
	return false


func _round(r: Rect2, radius: float, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(minf(radius, minf(r.size.x, r.size.y) * 0.5)))
	sb.anti_aliasing = true
	draw_style_box(sb, r)


func _round_top(r: Rect2, radius: float, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.corner_radius_top_right = int(minf(radius, r.size.x))
	sb.corner_radius_top_left = int(6.0)
	sb.anti_aliasing = true
	draw_style_box(sb, r)


## An arrow: a short shaft and a head, pointing `dir`.
func _arrow(at: Vector2, dir: Vector2, u: float, col: Color) -> void:
	var n := Vector2(-dir.y, dir.x)
	var tip: Vector2 = at + dir * 22.0 * u
	draw_line(at - dir * 18.0 * u, tip - dir * 6.0 * u, col, maxf(2.0, 5.0 * u), true)
	draw_colored_polygon(PackedVector2Array([tip + dir * 6.0 * u, tip - dir * 12.0 * u + n * 13.0 * u, tip - dir * 12.0 * u - n * 13.0 * u]), col)


func _chevron(at: Vector2, dir: Vector2, u: float, col: Color) -> void:
	var n := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array([at - dir * 8.0 * u + n * 11.0 * u, at + dir * 4.0 * u, at - dir * 8.0 * u - n * 11.0 * u])
	draw_polyline(pts, col, maxf(2.0, 4.0 * u), true)
