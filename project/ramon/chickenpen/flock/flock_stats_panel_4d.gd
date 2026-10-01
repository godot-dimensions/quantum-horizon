extends Control

## The murmuration in numbers, live, on the left of the pen's HUD. Ramon, 1 Oct: "a little
## panel on the left ... this is an R&D demo after all"; then "the same translucent style as
## the rest, with maybe one small color cue above the frame", "right under the top bracket,
## and the todo list should align bottom left".
##
## IT IS ONE OF THE HUD'S CARDS: the to-do card's translucent fill, hairline border, corner
## and font, so it sits with the others. The only colour is a short bar above its top edge,
## in the menu's accent (menu_final_style.tres), which is what marks it as the R&D readout.
##
## UNDER THE INFO CARD, the to-do list having moved down onto the inventory row. Where the
## two would meet (1280x720 at 125% UI size) it drops to five rows, and if even that would
## run into the to-do list it moves out beside it, still under the info card.
##
## EVERY NUMBER IS THE FLOCK'S OWN, summed over every bird by whichever side steps it (see
## pen_flock_4d.stats()); the panel walks no birds itself. F3 hides it.

const STYLE := preload("res://ramon/Menu/style/menu_final_style.tres")
## Five rows and no sparkline, for screens with no room for the whole thing.
const COMPACT_ROWS := ["Birds", "Step", "Order", "Spacing", "Hawk"]

@export var flock_path: NodePath = NodePath("../../World/Flock")
@export var above_path: NodePath = NodePath("../InfoCard")
@export var todo_path: NodePath = NodePath("../Quests")
@export var toggle_key: Key = KEY_F3
@export_range(9, 28, 1) var text_size: int = 13
## The to-do card's, so the two read as one family.
@export_range(0.0, 1.0, 0.05) var panel_alpha: float = 0.62
@export_range(200.0, 500.0, 1.0, "suffix:px") var panel_width: float = 320.0
@export_range(0.0, 40.0, 1.0) var gap_below: float = 8.0
@export_range(0.05, 2.0, 0.05, "suffix:s") var refresh_seconds: float = 0.25
## How much history the rolling-birds sparkline holds.
@export_range(5.0, 120.0, 1.0, "suffix:s") var history_seconds: float = 45.0

var _flock: Node
var _stats: Dictionary = {}
var _since: float = 0.0
var _history := PackedFloat32Array()
var _panel: StyleBoxFlat
var _compact: bool = false
var _cue: Color


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flock = get_node_or_null(flock_path)
	_panel = StyleBoxFlat.new()
	_panel.bg_color = Color(0.04, 0.05, 0.08, panel_alpha)
	_panel.border_color = Color(1.0, 1.0, 1.0, 0.07)
	_panel.set_border_width_all(1)
	_panel.set_corner_radius_all(9)
	# The menu's accent, lifted a little: on the dark card the menu's own blue goes muddy.
	_cue = STYLE.accent.lightened(0.3)
	_set_timing(visible)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != toggle_key:
		return
	visible = not visible
	_set_timing(visible)
	get_viewport().set_input_as_handled()


## GPU timestamps only while someone is reading them.
func _set_timing(on: bool) -> void:
	if _flock != null:
		_flock.set("profile_gpu", on)


func _process(delta: float) -> void:
	if not visible or _flock == null:
		return
	_since += delta
	if _since < refresh_seconds:
		return
	_since = 0.0
	_stats = _flock.call("stats")
	var birds: float = maxf(float(_stats.get("birds", 1)), 1.0)
	_history.append(float(_stats.get("rolling", 0)) / birds)
	var keep: int = int(history_seconds / refresh_seconds)
	if _history.size() > keep:
		_history = _history.slice(_history.size() - keep)
	_place()
	queue_redraw()


## A touch tighter than the to-do card's (+9): at 1920x1080 the whole panel then fits
## between the info card and the to-do list, where at +9 it missed by a few pixels.
func _step() -> float:
	return float(text_size) + 7.0


func _rows() -> Array:
	var s: Dictionary = _stats
	var rows: Array = []
	var gpu_ms: float = float(s.get("gpu_ms", -1.0))
	rows.append(["Birds", "%s, stepped on the %s" % [_thousands(int(s.get("birds", 0))), str(s.get("backend", "-"))]])
	if gpu_ms >= 0.0:
		rows.append(["Step", "%.2f ms GPU, %.2f ms CPU" % [gpu_ms, float(s.get("cpu_ms", 0.0))]])
	else:
		rows.append(["Step", "%.2f ms CPU" % float(s.get("cpu_ms", 0.0))])
	if s.has("order"):
		rows.append(["Order", "%.3f   (1 is one heading)" % float(s["order"])])
		rows.append(["Spacing", "%.2f m to the nearest" % float(s["nearest"])])
		rows.append(["Follows", "%.1f neighbours each" % float(s["neighbours"])])
		var shape: Vector2 = s["shape"]
		rows.append(["Shape", "1 : %.1f : %.1f, %.1f m thick" % [shape.x, shape.y, float(s["thickness"])]])
		rows.append(["In W", "%.1f m deep, %d%% in your slice" % [float(s["w_depth"]), int(round(float(s["in_slice"]) * 100.0))]])
		rows.append(["Rolling", "%s birds, copied in %d ms" % [_thousands(int(s["rolling"])), int(s.get("wave_ms", 0.0))]])
	var hawk: String = str(s.get("hawk", "-"))
	var next: float = float(s.get("hawk_next", -1.0))
	rows.append(["Hawk", ("away, back in %d s" % int(ceil(next))) if hawk == "away" and next >= 0.0 else hawk])
	if _compact:
		return rows.filter(func(row: Array) -> bool: return String(row[0]) in COMPACT_ROWS)
	return rows


func _thousands(n: int) -> String:
	var digits: String = str(n)
	var out: String = ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return digits + out


func _layout_height() -> float:
	var spark: float = 0.0 if _compact else 40.0
	return 12.0 + _step() * float(_rows().size() + 1) + spark + _step() + 8.0


func _place() -> void:
	var above := get_node_or_null(above_path) as Control
	if above == null:
		_compact = false
		size = Vector2(panel_width, _layout_height())
		position = Vector2(16.0, 300.0)
		return
	var r: Rect2 = above.call("drawn_rect") if above.has_method("drawn_rect") else Rect2(above.position, above.size)
	var under := Vector2(r.position.x, r.position.y + r.size.y + gap_below * 2.0)
	var todo := get_node_or_null(todo_path) as Control
	var todo_rect := Rect2(todo.position, todo.size) if todo != null and todo.visible else Rect2()
	for compact in [false, true]:
		_compact = compact
		# Compact is narrower too: beside the to-do list at 720p it would reach the camera picker.
		size = Vector2(minf(panel_width, 290.0) if compact else panel_width, _layout_height())
		if todo_rect.size == Vector2.ZERO or under.y + size.y + gap_below <= todo_rect.position.y:
			position = under
			return
	# Still in the way: out beside the to-do list, under the info card all the same.
	position = Vector2(todo_rect.end.x + gap_below * 1.5, under.y)


func _draw() -> void:
	if _stats.is_empty():
		return
	var font: Font = get_theme_default_font()
	var w: float = size.x
	draw_style_box(_panel, Rect2(Vector2.ZERO, size))
	# The one colour: a short bar just above the frame.
	draw_rect(Rect2(Vector2(14.0, -6.0), Vector2(34.0, 3.0)), _cue)
	var x: float = 14.0
	var y: float = 12.0
	# The algorithm, named in the heading - Ramon: "as a one off word or tiny sentence".
	draw_string(font, Vector2(x, y + font.get_ascent(text_size)), "Murmuration  ·  Reynolds boids, live",
		HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, Color(1.0, 1.0, 1.0, 0.55))
	y += _step()
	var value_x: float = x + 72.0
	for row in _rows():
		var base: float = y + font.get_ascent(text_size)
		draw_string(font, Vector2(x, base), String(row[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, Color(1.0, 1.0, 1.0, 0.45))
		draw_string(font, Vector2(value_x, base), String(row[1]), HORIZONTAL_ALIGNMENT_LEFT, w - value_x - 10.0, text_size, Color(1.0, 1.0, 1.0, 0.90))
		y += _step()
	if not _compact:
		# Birds rolling, over the last history_seconds: a hawk is a spike, the wave its width.
		var spark := Rect2(Vector2(x, y + 4.0), Vector2(w - x * 2.0, 32.0))
		draw_rect(spark, Color(1.0, 1.0, 1.0, 0.05))
		if _history.size() > 1:
			var peak: float = 0.05
			for v in _history:
				peak = maxf(peak, v)
			var points := PackedVector2Array()
			var keep: float = maxf(history_seconds / refresh_seconds - 1.0, 1.0)
			for k in _history.size():
				var t: float = float(k + int(keep) + 1 - _history.size()) / keep
				points.append(Vector2(spark.position.x + t * spark.size.x, spark.end.y - 2.0 - (_history[k] / peak) * (spark.size.y - 4.0)))
			draw_polyline(points, Color(1.0, 1.0, 1.0, 0.75), 1.5, true)
		draw_string(font, Vector2(spark.position.x + 6.0, spark.position.y + 4.0 + font.get_ascent(text_size - 2)),
			"rolling, last %d s" % int(history_seconds), HORIZONTAL_ALIGNMENT_LEFT, -1, text_size - 2, Color(1.0, 1.0, 1.0, 0.40))
		y += 40.0
	draw_string(font, Vector2(x, y + font.get_ascent(text_size - 2)), "F3 hide", HORIZONTAL_ALIGNMENT_LEFT, -1, text_size - 2, Color(1.0, 1.0, 1.0, 0.40))
