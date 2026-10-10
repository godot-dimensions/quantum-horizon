extends Control

## THE PEN'S MOUSE CARD (discovery, 9 Oct 2026): the Aquatic Lab's live mouse tutorial
## (WaterLab/shared/mouse_tutorial.gd, Ramon's "real-time little dynamic HUD explainer") brought to the playable world
## for its W hints (discovery/pen_w_guide_4d.gd). A copy, so the lab's stays as it is.
##
## What changed from the lab's:
## - The pen's gestures. Holding the right mouse button and dragging turns the slice here (GroundBasis4D.sliced): side
##   to side turns it sideways (x into W), forward and back turns it forward (z into W). The wheel is the zoom, so it
##   is not a gesture.
## - A third kind, "keys": the two keys that step you through W (move_kata / move_ana, read from the InputMap), each
##   lit in turn, a dot sliding along a short W axis between "kata" and "ana".
## - One caption line under the gesture: what to look for.
## - It is shown for a while (play) rather than held by its owner, and it fades.
## - It takes the first free spot on the HUD when it is shown (scripts/pen_hud_spot_4d.gd), and none while it is hidden.
##
## A gesture is [kind, words]: kind "drag_v", "drag_h" or "keys".
## NO class_name (engine_gotchas.md).

const LabPrint := preload("res://ramon/CreationLab/LabKit/lab_print.gd")
const Style := preload("res://ramon/CreationLab/kit/kit_style.gd")
const SPOT := preload("res://ramon/chickenpen/scripts/pen_hud_spot_4d.gd")

## Seconds each gesture is acted.
var beat: float = 2.2
var gestures: Array = []
var caption: String = ""
var _shown: bool = false
var _left: float = 0.0
var _a: float = 0.0
var _t: float = 0.0
var _card := Rect2()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## Act [param acts] (a list of [kind, words]) for [param seconds], with [param line] under them.
func play(acts: Array, line: String, seconds: float) -> void:
	gestures = acts
	caption = line
	_left = seconds
	_shown = true
	_t = 0.0
	_place()


func stop() -> void:
	_shown = false
	_left = 0.0


func is_playing() -> bool:
	return _shown or _a > 0.0


## What it draws, for the HUD's first-free-spot (nothing while it is hidden).
func drawn_rect() -> Rect2:
	return _card if _a > 0.01 else Rect2()


func _process(delta: float) -> void:
	size = get_viewport_rect().size
	if _shown:
		_left -= delta
		if _left <= 0.0:
			_shown = false
	var before: float = _a
	_a = move_toward(_a, 1.0 if _shown else 0.0, delta * 3.0)
	if _a > 0.0:
		_t += delta
	if _a > 0.0 or before != _a:
		queue_redraw()


## The first free spot: the left of the screen at about two thirds down (the lab's place), then the left middle,
## then the right middle, then the bottom middle.
func _place() -> void:
	var screen: Vector2 = get_viewport_rect().size
	var u: float = screen.y / 1080.0
	var want := Vector2(330.0, 430.0) * u
	var places: Array = [Vector2(screen.x * 0.03, screen.y * 0.62 - want.y * 0.5), Vector2(screen.x * 0.03, screen.y * 0.40 - want.y * 0.5),
		Vector2(screen.x * 0.97 - want.x, screen.y * 0.45 - want.y * 0.5), Vector2((screen.x - want.x) * 0.5, screen.y * 0.97 - want.y)]
	_card = Rect2(SPOT.first(places, want, SPOT.taken(get_parent(), self), screen), want)


func _draw() -> void:
	if _a <= 0.001 or gestures.is_empty() or size.y < 100.0:
		return
	var u: float = size.y / 1080.0
	var k: int = int(floor(_t / beat)) % gestures.size()
	var ph: float = fmod(_t, beat) / beat
	var kind: String = String(gestures[k][0])
	var card: Rect2 = _card
	var glass := Style.glass_box(18.0 * u)
	glass.bg_color.a *= _a * 0.92
	draw_style_box(glass, card)
	var ink := Color(1, 1, 1, _a)
	var dim := Color(1, 1, 1, 0.32 * _a)
	var lit := Color(Style.UI_ACCENT, _a)
	var centre := card.position + Vector2(card.size.x * 0.5, 150.0 * u)
	var swing: float = sin(ph * TAU)
	if kind == "keys":
		_draw_keys(centre, ph, u, ink, dim, lit)
	else:
		_draw_mouse(centre, kind, swing, ph, u, dim, lit)
	# The words: this gesture big, the others small under it, and the caption.
	var fb: Font = LabPrint.font("black")
	var fs: Font = LabPrint.font("bold")
	var how: String = "RIGHT MOUSE, FORWARD AND BACK" if kind == "drag_v" else ("RIGHT MOUSE, SIDE TO SIDE" if kind == "drag_h" else "HOLD A KEY")
	var ty0: float = card.position.y + 300.0 * u
	draw_string(fs, Vector2(card.position.x, ty0), how, HORIZONTAL_ALIGNMENT_CENTER, card.size.x, int(13 * u), Color(Style.UI_INK_DIM, _a))
	# The gesture's name, as big as fits the card ("TURN THE SLICE FORWARD" is wider than the lab's names).
	var title: String = String(gestures[k][1])
	var tpx: int = int(24 * u)
	for i in 12:
		if fb.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, tpx).x <= card.size.x - 28.0 * u or tpx <= 10:
			break
		tpx -= 1
	draw_string(fb, Vector2(card.position.x, ty0 + 30.0 * u), title, HORIZONTAL_ALIGNMENT_CENTER, card.size.x, tpx, ink)
	var others: Array = []
	for i in gestures.size():
		if i != k:
			others.append(String(gestures[i][1]).to_lower())
	if not others.is_empty():
		draw_string(fs, Vector2(card.position.x, ty0 + 58.0 * u), "  ·  ".join(others), HORIZONTAL_ALIGNMENT_CENTER, card.size.x, int(12 * u), dim)
	if caption != "":
		var cy: float = ty0 + (84.0 if not others.is_empty() else 62.0) * u
		draw_multiline_string(fs, Vector2(card.position.x + 18.0 * u, cy), caption, HORIZONTAL_ALIGNMENT_CENTER, card.size.x - 36.0 * u, int(14 * u), 2, Color(1, 1, 1, 0.85 * _a))


## The lab's mouse, its right button lit, pushed along the gesture.
func _draw_mouse(centre: Vector2, kind: String, swing: float, ph: float, u: float, dim: Color, lit: Color) -> void:
	var mw: float = 112.0 * u
	var mh: float = 172.0 * u
	var move := Vector2(0.0, -swing * 22.0 * u) if kind == "drag_v" else Vector2(swing * 30.0 * u, 0.0)
	var m := Rect2(centre - Vector2(mw, mh) * 0.5 + move, Vector2(mw, mh))
	_round(Rect2(m.position + Vector2(5.0, 8.0) * u, m.size), 56.0 * u, Color(0, 0, 0, 0.35 * _a))
	_round(m, 56.0 * u, Color(0.93, 0.95, 0.98, _a))
	var split_y: float = m.position.y + mh * 0.42
	var right_btn := Rect2(Vector2(m.get_center().x + 2.0 * u, m.position.y + 3.0 * u), Vector2(mw * 0.5 - 5.0 * u, mh * 0.42 - 4.0 * u))
	_round_top(right_btn, 52.0 * u, Color(Style.UI_ACCENT, _a))
	draw_line(Vector2(m.position.x + 6.0 * u, split_y), Vector2(m.end.x - 6.0 * u, split_y), Color(0.55, 0.60, 0.68, _a), maxf(1.0, 2.0 * u), true)
	draw_line(Vector2(m.get_center().x, m.position.y + 4.0 * u), Vector2(m.get_center().x, split_y), Color(0.55, 0.60, 0.68, _a), maxf(1.0, 2.0 * u), true)
	var wheel := Rect2(Vector2(m.get_center().x - 9.0 * u, m.position.y + 22.0 * u), Vector2(18.0 * u, 40.0 * u))
	_round(wheel, 9.0 * u, Color(0.40, 0.45, 0.53, _a))
	draw_line(Vector2(m.position.x + 18.0 * u, split_y + 16.0 * u), Vector2(m.position.x + 18.0 * u, m.end.y - 40.0 * u), Color(1, 1, 1, 0.5 * _a), maxf(2.0, 5.0 * u), true)
	var v_on: bool = kind == "drag_v"
	var h_on: bool = kind == "drag_h"
	_arrow(centre + Vector2(0.0, -mh * 0.5 - 70.0 * u), Vector2(0, -1), u, lit if v_on else dim)
	_arrow(centre + Vector2(0.0, mh * 0.5 + 22.0 * u), Vector2(0, 1), u, lit if v_on else dim)
	_arrow(centre + Vector2(-mw * 0.5 - 40.0 * u, 0.0), Vector2(-1, 0), u, lit if h_on else dim)
	_arrow(centre + Vector2(mw * 0.5 + 40.0 * u, 0.0), Vector2(1, 0), u, lit if h_on else dim)
	if v_on:
		_chevron(centre + Vector2(mw * 0.5 + 34.0 * u, -swing * 40.0 * u), Vector2(0, -1 if cos(ph * TAU) > 0.0 else 1), u, lit)
	elif h_on:
		_chevron(centre + Vector2(swing * 70.0 * u, -mh * 0.5 - 30.0 * u), Vector2(1 if cos(ph * TAU) > 0.0 else -1, 0), u, lit)


## Two key caps, kata on the left and ana on the right, each held in turn, and a dot along a W axis over them going
## the way the held key takes you.
func _draw_keys(centre: Vector2, ph: float, u: float, ink: Color, dim: Color, lit: Color) -> void:
	var cap := Vector2(92.0, 92.0) * u
	var gap: float = 26.0 * u
	var ana_held: bool = ph >= 0.5
	var held_frac: float = fmod(ph * 2.0, 1.0)
	var fb: Font = LabPrint.font("black")
	var fs: Font = LabPrint.font("bold")
	var keys: Array = [[_key_for(&"move_kata"), "KATA", not ana_held], [_key_for(&"move_ana"), "ANA", ana_held]]
	for i in 2:
		var held: bool = bool(keys[i][2])
		var press: float = 6.0 * u if held else 0.0
		var r := Rect2(centre + Vector2((float(i) - 1.0) * (cap.x + gap) + gap * 0.5, -cap.y * 0.5 + 40.0 * u + press), cap)
		_round(Rect2(r.position + Vector2(0, 7.0 * u - press), r.size), 16.0 * u, Color(0, 0, 0, 0.35 * _a))
		_round(r, 16.0 * u, Color(Style.UI_ACCENT, _a) if held else Color(0.93, 0.95, 0.98, _a))
		draw_string(fb, Vector2(r.position.x, r.position.y + r.size.y * 0.62), String(keys[i][0]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(40 * u), Color(0.08, 0.10, 0.14, _a))
		draw_string(fs, Vector2(r.position.x, r.end.y + 26.0 * u), String(keys[i][1]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(13 * u), lit if held else dim)
	# The W axis above the keys, the dot carried along it by whichever key is held.
	var y: float = centre.y - 60.0 * u
	var x0: float = centre.x - 110.0 * u
	var x1: float = centre.x + 110.0 * u
	draw_line(Vector2(x0, y), Vector2(x1, y), dim, maxf(2.0, 4.0 * u), true)
	_arrow(Vector2(x1 - 10.0 * u, y), Vector2(1, 0), u * 0.7, dim)
	_arrow(Vector2(x0 + 10.0 * u, y), Vector2(-1, 0), u * 0.7, dim)
	draw_string(fs, Vector2(x1 - 30.0 * u, y - 18.0 * u), "W", HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * u), ink)
	var along: float = lerpf(0.5, 1.0, held_frac) if ana_held else lerpf(0.5, 0.0, held_frac)
	draw_circle(Vector2(lerpf(x0 + 20.0 * u, x1 - 20.0 * u, along), y), 11.0 * u, lit)


## The key bound to [param action], read from the InputMap: advice naming a key nobody has bound is worse than none.
func _key_for(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "?"
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			return OS.get_keycode_string(code)
	return "?"


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
