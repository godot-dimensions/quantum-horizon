# CARRIED OVER from res://ramon/WaterLab/shared/mouse_tutorial.gd (9 Oct 2026) for the Voxel Lab's open
# world (Ramon: "use the same visual treatment as the mouse tutorial that appears when looking at the
# aquarium in the Water Lab ... adapted to demonstrate slice rotation"); the lab owns this copy. Change:
# `footer`, a line of keys under the gestures (the open world's "R  ·  LEVEL AGAIN"); `hold`, the card
# goes after that many seconds and comes back only when `shown` goes off and on again (round 4: "display
# the tutorial when the player enters the relevant interaction zone. Automatically hide it after
# approximately 10 seconds"); the card's place bottom left by default ("preferably the bottom-left
# corner").
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
## NO class_name (engine_gotchas.md).

const LabPrint := preload("res://ramon/VoxelLab/carried/LabKit/lab_print.gd")
const Style := preload("res://ramon/VoxelLab/carried/kit/kit_style.gd")

var shown: bool = false
var gestures: Array = [["drag_v", "SLIDE THROUGH W"], ["drag_h", "TURN THROUGH W"]]
## Seconds each gesture is acted.
var beat: float = 2.2
## Where the card sits, as a share of the window (its left middle).
var anchor := Vector2(0.02, 0.7)
## A line under the gestures, small (VOXEL LAB copy): another key that belongs with them.
var footer: String = ""
## Seconds it shows each time `shown` turns on (0: as long as it is on).
var hold: float = 10.0
var _a: float = 0.0
var _on_for: float = 0.0
var _was: bool = false
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	size = get_viewport_rect().size
	var before: float = _a
	if shown and not _was:
		_on_for = 0.0
	_was = shown
	if shown:
		_on_for += delta
	var want: bool = shown and (hold <= 0.0 or _on_for < hold)
	_a = move_toward(_a, 1.0 if want else 0.0, delta * 3.0)
	if _a > 0.0:
		_t += delta
	else:
		_t = 0.0
	if _a > 0.0 or before != _a:
		queue_redraw()


func _draw() -> void:
	if _a <= 0.001 or gestures.is_empty() or size.y < 100.0:
		return
	var u: float = size.y / 1080.0
	var k: int = int(floor(_t / beat)) % gestures.size()
	var ph: float = fmod(_t, beat) / beat
	var kind: String = String(gestures[k][0])
	var card := Rect2(Vector2(size.x * anchor.x, size.y * anchor.y - 200.0 * u), Vector2(330.0 * u, 400.0 * u))
	var glass := Style.glass_box(18.0 * u)
	glass.bg_color.a *= _a * 0.92
	draw_style_box(glass, card)
	var ink := Color(1, 1, 1, _a)
	var dim := Color(1, 1, 1, 0.32 * _a)
	var lit := Color(Style.UI_ACCENT, _a)
	# The mouse: 120 x 180 (u), its middle a little above the card's.
	var mw: float = 112.0 * u
	var mh: float = 172.0 * u
	var centre := card.position + Vector2(card.size.x * 0.5, 150.0 * u)
	# Acting the gesture: the mouse pushed along it, eased there and back.
	var swing: float = sin(ph * TAU)
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
	var pressed: float = 1.0 if kind != "wheel" else 0.35
	_round_top(right_btn, 52.0 * u, Color(Style.UI_ACCENT.lerp(Color.WHITE, 0.15 * (1.0 - pressed)), _a * (0.55 + 0.45 * pressed)))
	draw_line(Vector2(m.position.x + 6.0 * u, split_y), Vector2(m.end.x - 6.0 * u, split_y), Color(0.55, 0.60, 0.68, _a), maxf(1.0, 2.0 * u), true)
	draw_line(Vector2(m.get_center().x, m.position.y + 4.0 * u), Vector2(m.get_center().x, split_y), Color(0.55, 0.60, 0.68, _a), maxf(1.0, 2.0 * u), true)
	# The wheel, and its ticks rolling when it is the gesture.
	var wheel := Rect2(Vector2(m.get_center().x - 9.0 * u, m.position.y + 22.0 * u), Vector2(18.0 * u, 40.0 * u))
	var wheel_lit: bool = kind == "wheel"
	_round(wheel, 9.0 * u, Color(Style.UI_ACCENT, _a) if wheel_lit else Color(0.40, 0.45, 0.53, _a))
	if wheel_lit:
		for i in 3:
			var ty: float = wheel.position.y + fmod(float(i) * 13.0 * u + _t * 40.0 * u, wheel.size.y)
			draw_line(Vector2(wheel.position.x + 4.0 * u, ty), Vector2(wheel.end.x - 4.0 * u, ty), Color(1, 1, 1, 0.8 * _a), maxf(1.0, 2.0 * u))
	# A soft gloss down its left.
	draw_line(Vector2(m.position.x + 18.0 * u, split_y + 16.0 * u), Vector2(m.position.x + 18.0 * u, m.end.y - 40.0 * u), Color(1, 1, 1, 0.5 * _a), maxf(2.0, 5.0 * u), true)
	# The arrows (fixed, round where the mouse rests): above and below, and at both sides.
	var rest := centre
	var v_on: bool = kind == "drag_v"
	var h_on: bool = kind == "drag_h"
	_arrow(rest + Vector2(0.0, -mh * 0.5 - 70.0 * u), Vector2(0, -1), u, lit if v_on else dim)
	_arrow(rest + Vector2(0.0, mh * 0.5 + 22.0 * u), Vector2(0, 1), u, lit if v_on else dim)
	_arrow(rest + Vector2(-mw * 0.5 - 40.0 * u, 0.0), Vector2(-1, 0), u, lit if h_on else dim)
	_arrow(rest + Vector2(mw * 0.5 + 40.0 * u, 0.0), Vector2(1, 0), u, lit if h_on else dim)
	# A chevron sliding along the lit arrows, there and back.
	if v_on:
		_chevron(rest + Vector2(mw * 0.5 + 34.0 * u, -swing * 40.0 * u), Vector2(0, -1 if cos(ph * TAU) > 0.0 else 1), u, lit)
	elif h_on:
		_chevron(rest + Vector2(swing * 70.0 * u, -mh * 0.5 - 30.0 * u), Vector2(1 if cos(ph * TAU) > 0.0 else -1, 0), u, lit)
	# The words: this gesture big, the others small under it.
	var fb: Font = LabPrint.font("black")
	var fs: Font = LabPrint.font("bold")
	var how: String = "RIGHT MOUSE, FORWARD AND BACK" if kind == "drag_v" else ("RIGHT MOUSE, SIDE TO SIDE" if kind == "drag_h" else "THE WHEEL")
	var ty0: float = card.position.y + 300.0 * u
	draw_string(fs, Vector2(card.position.x, ty0), how, HORIZONTAL_ALIGNMENT_CENTER, card.size.x, int(13 * u), Color(Style.UI_INK_DIM, _a))
	draw_string(fb, Vector2(card.position.x, ty0 + 30.0 * u), String(gestures[k][1]), HORIZONTAL_ALIGNMENT_CENTER, card.size.x, int(24 * u), ink)
	var others: Array = []
	for i in gestures.size():
		if i != k:
			others.append(String(gestures[i][1]).to_lower())
	if not others.is_empty():
		draw_string(fs, Vector2(card.position.x, ty0 + 58.0 * u), "  ·  ".join(others), HORIZONTAL_ALIGNMENT_CENTER, card.size.x, int(12 * u), dim)
	if not footer.is_empty():
		draw_string(fs, Vector2(card.position.x, ty0 + 80.0 * u), footer, HORIZONTAL_ALIGNMENT_CENTER, card.size.x, int(13 * u), Color(Style.UI_INK, _a))


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
