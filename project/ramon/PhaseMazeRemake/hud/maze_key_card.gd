extends Control

## The blue plate's key card (round 3, Ramon, 10 Oct: "the intended solution essentially requires the
## player to rotate using F, and only while standing on a blue square ... introduce a contextual hint
## explaining the relationship between blue squares and F rotation ... consider adapting the animated
## mouse/key tutorial system from Aquatic Lab"). The Aquatic Lab's card (WaterLab/shared/
## mouse_tutorial.gd: a glass card at the left, one gesture acted after another, about two seconds
## each, the one being acted named big) with keys instead of a mouse:
##   "f_turn"   the F key pressed, and beside it a cell seen from above: your arrow AHEAD swings a
##              quarter turn and comes out labelled W, the way the view swings into W
##   "qe_step"  Q and E pressed in turn, a dot sliding along a short KATA to ANA line
## Shown while `shown`; it fades. `title` and `line` are the words over and under the gestures.
##
## NO class_name (engine_gotchas.md).

const LabPrint := preload("res://ramon/PhaseMazeRemake/carried/LabKit/lab_print.gd")
const Kit := preload("res://ramon/PhaseMazeRemake/carried/kit/kit_style.gd")
const Style := preload("res://ramon/PhaseMazeRemake/maze/maze_style.gd")

var shown: bool = false
var title: String = "BLUE PLATE: A WAY THROUGH W"
var line: String = "F turns it ahead of you. Then walk."
var gestures: Array = [["f_turn", "PRESS F"], ["qe_step", "OR HOLD E / Q"]]
var beat: float = 2.4
## The card's left middle, as a share of the window.
var anchor := Vector2(0.03, 0.37)
var _a: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	size = get_viewport_rect().size
	var before: float = _a
	_a = move_toward(_a, 1.0 if shown else 0.0, delta * 3.0)
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
	var card := Rect2(Vector2(size.x * anchor.x, size.y * anchor.y - 170.0 * u), Vector2(360.0 * u, 340.0 * u))
	var glass: StyleBoxFlat = Kit.glass_box(18.0 * u)
	glass.bg_color.a *= _a * 0.92
	glass.border_color = Color(Style.role("w"), 0.8 * _a)
	glass.set_border_width_all(int(maxf(1.0, 2.0 * u)))
	draw_style_box(glass, card)
	var fb: Font = LabPrint.font("black")
	var fs: Font = LabPrint.font("bold")
	var ink := Color(1, 1, 1, _a)
	var soft := Color(Kit.UI_INK_SOFT, Kit.UI_INK_SOFT.a * _a)
	var blue := Color(Style.role("w").lightened(0.15), _a)
	draw_string(fs, card.position + Vector2(22.0, 38.0) * u, title, HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 44.0 * u, int(17.0 * u), blue)
	var stage := Rect2(card.position + Vector2(20.0, 58.0) * u, Vector2(card.size.x - 40.0 * u, 180.0 * u))
	if kind == "f_turn":
		_f_turn(stage, ph, u)
	else:
		_qe_step(stage, ph, u)
	# The gesture being acted, big; the others small under it.
	draw_string(fb, Vector2(card.position.x, card.position.y + 268.0 * u), String(gestures[k][1]), HORIZONTAL_ALIGNMENT_CENTER, card.size.x, int(26.0 * u), ink)
	draw_string(fs, Vector2(card.position.x + 22.0 * u, card.position.y + 312.0 * u), line, HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 44.0 * u, int(15.0 * u), soft)


## The F key pressed once a beat, and a cell from above whose AHEAD arrow swings into W.
func _f_turn(stage: Rect2, ph: float, u: float) -> void:
	var down: bool = ph > 0.12 and ph < 0.30
	_key(Rect2(stage.position + Vector2(10.0 * u, stage.size.y * 0.5 - 38.0 * u), Vector2(76, 76) * u), "F", down, u)
	# The cell: a square, you in the middle.
	var c := stage.position + Vector2(stage.size.x * 0.68, stage.size.y * 0.52)
	var half: float = 64.0 * u
	var frame := Rect2(c - Vector2(half, half), Vector2(half, half) * 2.0)
	draw_rect(frame, Color(1, 1, 1, 0.06 * _a), true)
	draw_rect(frame, Color(1, 1, 1, 0.35 * _a), false, 2.0 * u)
	# The blue plate under you.
	draw_rect(Rect2(c - Vector2(26, 26) * u, Vector2(52, 52) * u), Color(Style.role("w"), 0.55 * _a), true)
	# The swing: still, then a quarter turn eased over the middle of the beat, then held.
	var s: float = smoothstep(0.30, 0.62, ph)
	var ang: float = -PI * 0.5 + s * PI * 0.5
	var tip: Vector2 = c + Vector2(cos(ang), sin(ang)) * half * 0.92
	var col: Color = Color(1, 1, 1, _a).lerp(Color(Style.role("w").lightened(0.3), _a), s)
	draw_line(c, tip, col, 5.0 * u, true)
	var d: Vector2 = (tip - c).normalized()
	var side := Vector2(-d.y, d.x)
	draw_colored_polygon(PackedVector2Array([tip + d * 10.0 * u, tip + side * 8.0 * u, tip - side * 8.0 * u]), col)
	var fs: Font = LabPrint.font("black")
	var label: String = "AHEAD" if s < 0.5 else "W"
	draw_string(fs, tip + d * 22.0 * u + Vector2(-30.0 * u, 6.0 * u), label, HORIZONTAL_ALIGNMENT_CENTER, 60.0 * u, int(15.0 * u), col)
	draw_circle(c, 6.0 * u, Color(1, 1, 1, _a))


## Q and E pressed in turn, a dot sliding along KATA to ANA.
func _qe_step(stage: Rect2, ph: float, u: float) -> void:
	var ana: bool = ph < 0.5
	var key_y: float = stage.position.y + stage.size.y * 0.62 - 34.0 * u
	_key(Rect2(Vector2(stage.position.x + 30.0 * u, key_y), Vector2(68, 68) * u), "Q", not ana and fmod(ph, 0.5) < 0.38, u)
	_key(Rect2(Vector2(stage.end.x - 98.0 * u, key_y), Vector2(68, 68) * u), "E", ana and fmod(ph, 0.5) < 0.38, u)
	var y: float = stage.position.y + 34.0 * u
	var x0: float = stage.position.x + 50.0 * u
	var x1: float = stage.end.x - 50.0 * u
	draw_line(Vector2(x0, y), Vector2(x1, y), Color(Style.role("w"), 0.6 * _a), 3.0 * u, true)
	var fs: Font = LabPrint.font("bold")
	draw_string(fs, Vector2(x0 - 40.0 * u, y + 26.0 * u), "KATA", HORIZONTAL_ALIGNMENT_CENTER, 80.0 * u, int(12.0 * u), Color(1, 1, 1, 0.7 * _a))
	draw_string(fs, Vector2(x1 - 40.0 * u, y + 26.0 * u), "ANA", HORIZONTAL_ALIGNMENT_CENTER, 80.0 * u, int(12.0 * u), Color(1, 1, 1, 0.7 * _a))
	var f: float = smoothstep(0.0, 0.45, ph) if ana else 1.0 - smoothstep(0.5, 0.95, ph)
	draw_circle(Vector2(lerpf(x0, x1, f), y), 9.0 * u, Color(1, 1, 1, _a))


func _key(r: Rect2, text: String, down: bool, u: float) -> void:
	var shift := Vector2(0.0, 5.0 * u) if down else Vector2.ZERO
	var under := StyleBoxFlat.new()
	under.set_corner_radius_all(int(12.0 * u))
	under.bg_color = Color(0, 0, 0, 0.45 * _a)
	draw_style_box(under, Rect2(r.position + Vector2(0.0, 6.0 * u), r.size))
	var top := StyleBoxFlat.new()
	top.set_corner_radius_all(int(12.0 * u))
	top.anti_aliasing = true
	top.bg_color = Color(Style.role("w"), _a) if down else Color(0.93, 0.95, 0.98, _a)
	draw_style_box(top, Rect2(r.position + shift, r.size))
	var fb: Font = LabPrint.font("black")
	draw_string(fb, Vector2(r.position.x, r.position.y + shift.y + r.size.y * 0.68), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(r.size.y * 0.5),
		Color(1, 1, 1, _a) if down else Color(0.06, 0.07, 0.09, _a))
