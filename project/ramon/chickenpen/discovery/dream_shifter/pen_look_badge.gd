extends Control

## THE MODE BADGE (UI/LookBadge; 10 Oct 2026, Ramon's walkthrough item 12: "a more prominent, player-facing indicator
## showing whether Art Mode or Dev Mode is currently active ... near the bottom-left corner, preferably just above the
## inventory ... a larger, more readable toggle treatment. Include an eye icon ... Display the existing I keyboard
## shortcut ... Match the more polished in-game interface style rather than the developer HUD ... Update it
## immediately when pressing I. Make the transition visually clear but not distracting.").
##
## A SWITCH IN THE MIDDLE AT THE BOTTOM since 10 Oct, later (Ramon: "the art mode i to switch toggle should be in the
## center bottom. and it should be just DEV / ART. and one of of the botton sides look like its activated or not. and
## under the botton 'I to switch' just as text."): one pill split in two, DEV and ART, the active half filled in its
## colour (the dev look's blue, the art's warm gold) with dark letters, the other half dark glass with dim ones; the
## fill slides across when the look changes. "I to switch" above it (11 Oct; it was under), on a small dark pill. A click on either half picks it,
## while the cursor is free. It follows the belt: hidden when the belt is (conversations, films).
##
## It reads the Look (look/pen_look_4d.gd) and only calls its set_dev. NO class_name (engine_gotchas.md).

const Look := preload("res://ramon/chickenpen/look/pen_look_4d.gd")
const LabPrint := preload("res://ramon/CreationLab/LabKit/lab_print.gd")
const Style := preload("res://ramon/CreationLab/kit/kit_style.gd")
const Guide := preload("res://ramon/chickenpen/discovery/dream_shifter/pen_look_guide_4d.gd")

@export var inventory_path: NodePath = ^"../Inventory"
@export var dev_colour: Color = Color(0.40, 0.70, 1.0)
@export var art_colour: Color = Color(1.0, 0.76, 0.38)

var _look: Node
var _dev: bool = true
var _was_dev: bool = true
## 0..1 through a change (1: settled).
var _change: float = 1.0
var _pill := Rect2()
var _label := Rect2()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _find_look() -> void:
	if _look != null and is_instance_valid(_look):
		return
	var look: Node = Look.current
	if look == null or not is_instance_valid(look):
		return
	_look = look
	_dev = bool(_look.get("dev"))
	_was_dev = _dev
	_look.connect("look_changed", _on_look)


func _on_look(dev: bool) -> void:
	if dev == _dev:
		return
	_was_dev = _dev
	_dev = dev
	_change = 0.0


## The pill on screen (for panels that keep clear of it, and the layout editor).
func drawn_rect() -> Rect2:
	# The pill and the little "I to switch" pill above it.
	return _pill.merge(_label) if visible else Rect2()


func _process(delta: float) -> void:
	size = get_viewport_rect().size
	_find_look()
	var inv := get_node_or_null(inventory_path) as Control
	# Only once the Dream Shifter has explained it (Ramon, 10 Oct, item 31: "Keep the toggle hidden initially. Reveal
	# it only after the player completes the Dream Shifter introduction."); I works all along.
	var show: bool = _look != null and inv != null and inv.is_visible_in_tree() and Guide.seen
	if show != visible:
		visible = show
	if _change < 1.0:
		_change = minf(_change + delta / 0.45, 1.0)
	if visible:
		queue_redraw()


func _input(event: InputEvent) -> void:
	# A click on the pill switches, while the cursor is free (in play the mouse is captured and I is the way).
	if not visible or _look == null or not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT or Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		return
	var at: Vector2 = (make_input_local(event) as InputEventMouse).position
	if _pill.has_point(at):
		_look.call("set_dev", at.x < _pill.get_center().x)
		get_viewport().set_input_as_handled()


static func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _draw() -> void:
	if _look == null or size.y < 100.0:
		return
	var u: float = size.y / 1080.0
	var fb: Font = LabPrint.font("black")
	var fs: Font = LabPrint.font("bold")
	var w: float = 232.0 * u
	var h: float = 40.0 * u
	# On the belt's centre line, with the menu's pill beside the belt (Ramon, 11 Oct; pen_inventory_4d.gd pill_line());
	# 70 above the bottom as before when there is no belt to follow.
	var inv := get_node_or_null(inventory_path) as Control
	var line_y: float = float(inv.call("pill_line")) if inv != null and inv.has_method("pill_line") else size.y - 70.0 * u - h * 0.5
	_pill = Rect2(Vector2((size.x - w) * 0.5, line_y - h * 0.5), Vector2(w, h))
	var glass := Style.glass_box(h * 0.5, 1.0, 0.82)
	glass.border_color = Color(1, 1, 1, 0.22)
	glass.set_border_width_all(int(maxf(1.0, 1.5 * u)))
	draw_style_box(glass, _pill)
	# The lit half: where the active mode is, sliding there through a change.
	var e: float = _ease(_change)
	var from_x: float = 0.0 if _was_dev else 1.0
	var to_x: float = 0.0 if _dev else 1.0
	var at: float = lerpf(from_x, to_x, e)
	var half := Vector2(w * 0.5, h)
	var lit := Rect2(_pill.position + Vector2(at * half.x, 0.0), half).grow(-3.0 * u)
	var colour: Color = (dev_colour if _was_dev else art_colour).lerp(dev_colour if _dev else art_colour, e)
	var fill := StyleBoxFlat.new()
	fill.bg_color = colour
	fill.set_corner_radius_all(int(lit.size.y * 0.5))
	fill.anti_aliasing = true
	draw_style_box(fill, lit)
	# The words: on the lit half dark, on the other dim.
	var px: int = int(17 * u)
	for i in 2:
		var word: String = "DEV" if i == 0 else "ART"
		var on: float = clampf(1.0 - absf(at - float(i)), 0.0, 1.0)
		var ink: Color = Color(0.08, 0.09, 0.12).lerp(Color(1, 1, 1, 0.55), 1.0 - on)
		var r := Rect2(_pill.position + Vector2(float(i) * half.x, 0.0), half)
		draw_string(fb, Vector2(r.position.x, r.get_center().y + fb.get_ascent(px) * 0.36), word, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, px, ink)
	# "I to switch" ABOVE it, on a small dark glass pill of its own, a little less white (Ramon, 11 Oct).
	var key: String = OS.get_keycode_string(int(_look.get("key")))
	var tpx: int = int(15 * u)
	var text: String = "%s to switch" % key
	var tw: float = fs.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, tpx).x
	var th: float = 26.0 * u
	_label = Rect2(Vector2(_pill.get_center().x - (tw + 26.0 * u) * 0.5, _pill.position.y - 8.0 * u - th), Vector2(tw + 26.0 * u, th))
	var tag := StyleBoxFlat.new()
	tag.bg_color = Color(0.02, 0.03, 0.05, 0.5)
	tag.set_corner_radius_all(int(th * 0.5))
	tag.anti_aliasing = true
	draw_style_box(tag, _label)
	draw_string(fs, Vector2(_label.position.x, _label.get_center().y + fs.get_ascent(tpx) * 0.36), text, HORIZONTAL_ALIGNMENT_CENTER, _label.size.x, tpx, Color(1, 1, 1, 0.72))
