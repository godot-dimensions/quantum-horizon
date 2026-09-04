@tool
extends Control
class_name MenuBanner

## The identity strip and mode switch, shared by BOTH menu screens.
##
## One banner, two screens, so the thing that never changes - who this is and
## how to get to the other view - never moves, never restyles and never renames
## itself between them. A switch whose halves look different on each side stops
## reading as a switch.
##
## STYLE IS PASSED IN, NOT READ. The two screens own different style resources
## on purpose ([MenuStyle] is a warm dark list, [FrontierStyle] a cold chart), so
## this takes colours and fonts as arguments rather than reaching for either one.
## That keeps the banner shared without making the two palettes shared.
##
## BOTH SCREENS PLACE IT THE SAME WAY: inside a 1920x1080 reference space fitted
## uniformly into the window by `reference_scale` / `reference_origin`. That is
## what makes it land on identical screen pixels rather than merely looking
## similar, which is what went wrong when each screen laid it out itself.

signal tab_pressed(index: int)
signal action_pressed()

## EVERY DIMENSION LIVES HERE, NOT IN EITHER SCREEN'S STYLE RESOURCE.
##
## The banner has to be the same SIZE and in the same PLACE on both screens, not
## merely similar. When each screen supplied its own font sizes and height they
## drifted immediately - Menu2's modular scale produced a different title size
## and a different bar height from the Frontier Map's fixed reference metrics,
## and the switch visibly jumped when you crossed between them.
##
## So the geometry is constants here and the callers pass only content and
## colour. Both screens then place the banner through `reference_scale` and
## `reference_origin` below, which is what puts it at identical screen
## coordinates whatever the window is.
const REFERENCE: Vector2 = Vector2(1920, 1080)
const HEIGHT: float = 104.0
const PAD: float = 44.0
const EYEBROW_SIZE: int = 13
const TITLE_SIZE: int = 37
const TAB_SIZE: int = 13
const TAB_WIDTH: float = 206.0
const TAB_GAP: float = 22.0
const ACTION_WIDTH: float = 386.0
## Space kept for the title before the tabs begin. Must clear the LONGEST title
## either screen uses ("EXPLORE FREELY" at 37px, about 390 reference pixels), not
## just the one being drawn - the whole point of a fixed reserve is that the tabs
## do not move when you switch screens.
const TITLE_RESERVE: float = 426.0


## Uniform fit of the 1920x1080 reference space into a window, and where that
## fitted space starts. Shared by both screens so the banner - and on the
## Frontier Map the whole layout - lands in exactly the same place.
static func reference_scale(screen: Vector2) -> float:
	if screen.x <= 0.0 or screen.y <= 0.0:
		return 1.0
	return minf(screen.x / REFERENCE.x, screen.y / REFERENCE.y)


static func reference_origin(screen: Vector2) -> Vector2:
	return (screen - REFERENCE * reference_scale(screen)) * 0.5

var _band: ColorRect = null
var _rule: ColorRect = null
var _eyebrow: Label = null
var _title: Label = null
var _tabs: Array[Button] = []
var _action: Button = null



## `colors` keys: fill, rule, text_bright, text_faint, tab_active_fill,
## tab_active_stroke, tab_idle_fill, tab_idle_stroke, action_fill, action_stroke,
## action_hover, action_text.
func setup(eyebrow: String, title: String, tab_labels: PackedStringArray,
		active_tab: int, action_label: String, fonts: Dictionary,
		colors: Dictionary) -> void:
	for child in get_children():
		child.queue_free()
	_tabs.clear()
	size = Vector2(REFERENCE.x, HEIGHT)
	custom_minimum_size = size
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_band = ColorRect.new()
	_band.color = colors["fill"]
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_band)

	_rule = ColorRect.new()
	_rule.color = colors["rule"]
	_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rule)

	_eyebrow = _label(eyebrow, fonts["caps"], EYEBROW_SIZE, colors["text_faint"])
	add_child(_eyebrow)
	_title = _label(title, fonts["caps"], TITLE_SIZE, colors["text_bright"])
	add_child(_title)

	for i in tab_labels.size():
		var active: bool = i == active_tab
		var button := _tab_button(tab_labels[i], active, fonts, colors)
		if not active:
			button.pressed.connect(tab_pressed.emit.bind(i))
		add_child(button)
		_tabs.append(button)

	if action_label != "":
		_action = Button.new()
		_action.text = action_label
		_action.focus_mode = Control.FOCUS_ALL
		_action.add_theme_font_override("font", fonts["caps_tight"])
		_action.add_theme_font_size_override("font_size", TAB_SIZE)
		_action.add_theme_color_override("font_color", colors["action_text"])
		_action.add_theme_stylebox_override("normal",
			_box(colors["action_fill"], colors["action_stroke"]))
		_action.add_theme_stylebox_override("hover",
			_box(colors["action_hover"], colors["action_stroke"]))
		_action.add_theme_stylebox_override("pressed",
			_box(colors["action_stroke"], colors["action_stroke"]))
		_action.add_theme_stylebox_override("focus",
			_box(colors["action_fill"], colors["text_bright"]))
		_action.pressed.connect(action_pressed.emit)
		add_child(_action)

	if not resized.is_connected(_do_layout):
		resized.connect(_do_layout)
	_do_layout()


## Lays the banner out in reference pixels. Never reads the node's own size, so
## the result cannot depend on which screen mounted it.
func _do_layout() -> void:
	if _band == null:
		return
	var width: float = REFERENCE.x
	_band.position = Vector2.ZERO
	_band.size = Vector2(width, HEIGHT)
	_rule.position = Vector2(0, HEIGHT - 1.0)
	_rule.size = Vector2(width, 1.0)

	_eyebrow.position = Vector2(PAD, HEIGHT * 0.17)
	_title.position = Vector2(PAD, HEIGHT * 0.36)

	var tab_height: float = HEIGHT * 0.46
	# The tabs start after a FIXED reserve rather than after the measured title,
	# so they sit at the same x on both screens even though "FRONTIER MAP" and
	# "EXPLORE FREELY" are different lengths. A switch that moves when you use it
	# is the exact thing this banner exists to prevent.
	var x: float = PAD + TITLE_RESERVE
	for button in _tabs:
		button.position = Vector2(x, (HEIGHT - tab_height) * 0.5)
		button.size = Vector2(TAB_WIDTH, tab_height)
		x += TAB_WIDTH + TAB_GAP

	if _action != null:
		_action.size = Vector2(ACTION_WIDTH, tab_height)
		_action.position = Vector2(width - PAD - ACTION_WIDTH, (HEIGHT - tab_height) * 0.5)


func set_action_text(text: String) -> void:
	if _action != null:
		_action.text = text


func _label(text: String, font: Font, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if font != null:
		label.add_theme_font_override("font", font)
	return label


func _tab_button(text: String, active: bool, fonts: Dictionary,
		colors: Dictionary) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	# The half naming the CURRENT screen is disabled rather than hidden: a switch
	# showing only the other option does not read as a switch at all.
	button.disabled = active
	button.add_theme_font_size_override("font_size", TAB_SIZE)
	if fonts.has("caps_tight") and fonts["caps_tight"] != null:
		button.add_theme_font_override("font", fonts["caps_tight"])
	var ink: Color = colors["tab_active_stroke"] if active else colors["text_faint"]
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_disabled_color", ink)
	var fill: Color = colors["tab_active_fill"] if active else colors["tab_idle_fill"]
	var stroke: Color = colors["tab_active_stroke"] if active else colors["tab_idle_stroke"]
	button.add_theme_stylebox_override("normal", _box(fill, stroke))
	button.add_theme_stylebox_override("disabled", _box(fill, stroke))
	button.add_theme_stylebox_override("hover", _box(colors["tab_active_fill"], stroke))
	button.add_theme_stylebox_override("pressed", _box(fill, stroke))
	button.add_theme_stylebox_override("focus", _box(fill, colors["text_bright"]))
	return button


func _box(fill: Color, stroke: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = stroke
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	return box
