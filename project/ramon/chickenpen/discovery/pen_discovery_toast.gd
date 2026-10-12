extends Control

## THE DISCOVERY TOAST (10 Oct 2026, Ramon's walkthrough feedback, follow_up/pen_feedback_10oct.md): a short, playful
## card high in the middle of the screen when you find something, "Whoa! You discovered a balloon!" (item 18), the
## pen's eggs (item 14), the clock (item 27). A title, an optional line under it, a coloured edge, a little burst of
## sparks; in for 0.3 s, up for a few seconds, out. One at a time: a second one waits for the first.
##
## Use: Toast.say(any_node_in_the_pen, "Whoa! You discovered a balloon!", "", Color(...)). The first call makes the
## card (on its own canvas layer under the scene's root) and keeps it for the next.
##
## Sizes in 1080p units (u), so it follows the HUD's UI size. NO class_name (engine_gotchas.md).

const LabPrint := preload("res://ramon/CreationLab/LabKit/lab_print.gd")
const Style := preload("res://ramon/CreationLab/kit/kit_style.gd")

const NAME := "DiscoveryToast"
const SECONDS := 3.4

var _queue: Array = []
var _title: String = ""
var _line: String = ""
var _colour: Color = Color(1.0, 0.80, 0.35)
var _t: float = -1.0
var _drew: bool = false


## Shows [param title] (and [param line] under it) on the pen's toast, after any already showing.
static func say(from: Node, title: String, line: String = "", colour: Color = Color(1.0, 0.80, 0.35)) -> void:
	if from == null or not from.is_inside_tree():
		return
	var root: Node = from.get_tree().current_scene if from.get_tree().current_scene != null else from.get_tree().root
	var toast: Node = root.get_node_or_null(NAME + "Layer/" + NAME)
	if toast == null:
		var layer := CanvasLayer.new()
		layer.name = NAME + "Layer"
		layer.layer = 64
		root.add_child(layer)
		toast = (load("res://ramon/chickenpen/discovery/pen_discovery_toast.gd") as GDScript).new()
		toast.name = NAME
		layer.add_child(toast)
	toast.call("push", title, line, colour)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func push(title: String, line: String, colour: Color) -> void:
	_queue.append([title, line, colour])
	if _t < 0.0:
		_next()


func _next() -> void:
	if _queue.is_empty():
		_t = -1.0
		return
	var item: Array = _queue.pop_front()
	_title = String(item[0])
	_line = String(item[1])
	_colour = item[2]
	_t = 0.0


func _process(delta: float) -> void:
	size = get_viewport_rect().size
	if _t >= 0.0:
		_t += delta
		if _t >= SECONDS:
			_next()
	var on: bool = _t >= 0.0
	if on or _drew:
		queue_redraw()
	_drew = on


static func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _draw() -> void:
	if _t < 0.0 or size.y < 100.0:
		return
	var u: float = size.y / 1080.0
	var a: float = _ease(_t / 0.3) * _ease((SECONDS - _t) / 0.45)
	if a <= 0.001:
		return
	var fb: Font = LabPrint.font("black")
	var fs: Font = LabPrint.font("body")
	var tpx: int = int(30 * u)
	var lpx: int = int(16 * u)
	var tw: float = fb.get_string_size(_title, HORIZONTAL_ALIGNMENT_LEFT, -1, tpx).x
	var lw: float = fs.get_string_size(_line, HORIZONTAL_ALIGNMENT_LEFT, -1, lpx).x if _line != "" else 0.0
	var w: float = maxf(tw, lw) + 64.0 * u
	var h: float = (92.0 if _line != "" else 64.0) * u
	var pop: float = 1.0 + 0.08 * (1.0 - _ease(_t / 0.25))
	var centre := Vector2(size.x * 0.5, size.y * 0.30)
	var card := Rect2(centre - Vector2(w, h) * 0.5 * pop, Vector2(w, h) * pop)
	var glass := Style.glass_box(16.0 * u, a, 0.9)
	glass.border_color = Color(_colour, 0.8 * a)
	glass.set_border_width_all(int(maxf(2.0, 2.5 * u)))
	draw_style_box(glass, card)
	# Sparks flying out from the card's edge over the first second.
	var burst: float = clampf(_t / 1.0, 0.0, 1.0)
	if burst < 1.0:
		for i in 14:
			var ang: float = TAU * float(i) / 14.0 + 0.3
			var p: Vector2 = centre + Vector2(cos(ang) * (w * 0.5 + 10.0 * u + 70.0 * u * burst), sin(ang) * (h * 0.5 + 10.0 * u + 46.0 * u * burst))
			var r: float = (5.0 - 3.5 * burst) * u
			var spark := PackedVector2Array([p + Vector2(0, -r), p + Vector2(r * 0.6, 0), p + Vector2(0, r), p + Vector2(-r * 0.6, 0)])
			draw_colored_polygon(spark, Color(_colour, a * (1.0 - burst)))
	var ty: float = card.position.y + (40.0 if _line != "" else 42.0) * u * pop
	draw_string(fb, Vector2(card.position.x, ty), _title, HORIZONTAL_ALIGNMENT_CENTER, card.size.x, tpx, Color(1, 1, 1, a))
	if _line != "":
		draw_string(fs, Vector2(card.position.x, ty + 30.0 * u), _line, HORIZONTAL_ALIGNMENT_CENTER, card.size.x, lpx, Color(1, 1, 1, 0.82 * a))
