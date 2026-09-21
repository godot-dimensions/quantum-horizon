extends Control

## A split-prism rangefinder for the fourth axis.
##
## THE PROBLEM IT SOLVES. The locator says "it is ana of you" and draws a bar, which tells
## you a direction and a rough distance but never where you ARE. Without that, W has no
## landmarks: you press E, something changes, and you have no way to know whether you are
## a little off the slice you want or three slices past it, nor how to get home.
##
## THE INSTRUMENT. An old SLR focus screen is cut across the middle, so an out-of-focus
## subject appears broken along the seam and you turn the ring until the two halves line
## up. That is what this is. The top half of the bar is your slice and never moves; the
## bottom half is whatever the locator is pointing at, and slides by the gap between you.
## Aligned, the bar is whole and gold. A broken shape asks to be mended in a way that a
## signed number does not, and which side the bottom half sits on IS the answer to "E or
## Q" without reading a word.
##
## THE RULER BEHIND IT gives W the landmarks it was missing: a notch at w = 0 for the
## default slice, so getting home is walking the notch back to the middle, and a faint
## tick for every other thing currently off your slice, so you can see that three of them
## are sitting together two slices ana rather than discovering it one press at a time.
##
## IT READS, IT DOES NOT DRIVE. No snap-to-slice button. Item 58 is against an autopilot,
## and the whole value of the fourth axis is that arriving on a slice is something you did.

@export var player_path: NodePath
## For the target being tracked. Optional: without it the prism half simply does not draw
## and the ruler still works as a where-am-I.
@export var locator_path: NodePath
## For the faint ticks. Optional in the same way.
@export var manager_path: NodePath

@export_group("Scale")
## How much of the W axis the ruler spans either side of you. The chickens live between
## about -2.5 and 2.5, so six shows the whole world with room at the edges.
@export_range(1.0, 20.0, 0.5) var span: float = 6.0
## Inside this much W the two halves count as joined. Kept a little generous: this is a
## navigation aid, and the catch itself has its own stricter test.
@export_range(0.05, 1.5, 0.05) var align_within: float = 0.35

@export_group("Look")
@export var track_color: Color = Color(1.0, 1.0, 1.0, 0.22)
@export var home_color: Color = Color(0.62, 0.86, 0.72, 0.85)
@export var mark_color: Color = Color(1.0, 1.0, 1.0, 0.34)
@export var you_color: Color = Color(0.74, 0.86, 1.0, 0.95)
@export var them_color: Color = Color(1.0, 0.72, 0.42, 0.95)
@export var joined_color: Color = Color(1.0, 0.86, 0.35, 1.0)
@export_range(4.0, 40.0, 1.0) var bar_width: float = 11.0
@export_range(10, 40, 1) var text_size: int = 15
@export_file("*.ttf") var font_path: String = "res://ramon/Demo/fonts/Montserrat/static/Montserrat-Medium.ttf"

var _player: Node4D
var _locator: Node
var _manager: Node
var _font: Font
var _joined: float = 0.0


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node4D
	_locator = get_node_or_null(locator_path)
	_manager = get_node_or_null(manager_path)
	if _player == null:
		push_warning("PenSliceGizmo: no player at '%s' - it cannot know where you are." % player_path)
	if font_path != "" and ResourceLoader.exists(font_path):
		_font = load(font_path) as Font
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	# Eased rather than snapped, so the moment of joining reads as a click into place
	# instead of a colour that flickers on the boundary.
	var want: float = 1.0 if _aligned() else 0.0
	_joined = move_toward(_joined, want, delta / 0.12)
	queue_redraw()


func _draw() -> void:
	if _player == null:
		return
	var w: float = size.x
	var h: float = size.y
	var mid_y: float = h * 0.52
	var centre: float = w * 0.5

	draw_line(Vector2(6.0, mid_y), Vector2(w - 6.0, mid_y), track_color, 2.0)

	# Every other thing currently off your slice, so the ruler is a map and not just a
	# readout of one target.
	for other in _marks():
		var x: float = _x_for(other)
		if x >= 0.0:
			draw_line(Vector2(x, mid_y - 5.0), Vector2(x, mid_y + 5.0), mark_color, 2.0)

	# The default slice. The one fixed landmark the fourth axis has.
	var home_x: float = _x_for(0.0)
	if home_x >= 0.0:
		draw_line(Vector2(home_x, mid_y - 14.0), Vector2(home_x, mid_y + 14.0), home_color, 2.0)
		_label("0", Vector2(home_x - 4.0, mid_y + 30.0), home_color)

	var target_w: float = _target_w()
	var have_target: bool = not is_nan(target_w)
	var them_x: float = _x_for(target_w) if have_target else -1.0

	var top := you_color.lerp(joined_color, _joined)
	var bottom := them_color.lerp(joined_color, _joined)

	# Your half never moves. Theirs slides. Together they are the instrument.
	draw_rect(Rect2(centre - bar_width * 0.5, mid_y - 17.0, bar_width, 17.0), top)
	if them_x >= 0.0:
		draw_rect(Rect2(them_x - bar_width * 0.5, mid_y, bar_width, 17.0), bottom)
	elif have_target:
		# Off the end of the ruler: a stub at the edge, so "miles away, that way" still
		# reads rather than the half simply vanishing.
		var edge: float = 6.0 if target_w < _player.global_position.w else w - 6.0
		draw_rect(Rect2(edge - bar_width * 0.5, mid_y + 3.0, bar_width, 11.0), bottom * Color(1, 1, 1, 0.55))

	_label("w %+.2f" % _player.global_position.w, Vector2(6.0, 12.0), you_color)
	if have_target:
		var gap: float = target_w - _player.global_position.w
		var hint: String = "aligned" if _aligned() else ("%s  %+.2f" % [_key_hint(gap), gap])
		_label(hint, Vector2(w - 6.0 - _text_width(hint), 12.0),
			joined_color if _aligned() else them_color)


## Nearest pixel for a W value, or -1 when it is off the end of the ruler.
func _x_for(target: float) -> float:
	var gap: float = target - _player.global_position.w
	if absf(gap) > span:
		return -1.0
	return size.x * 0.5 + gap / span * (size.x * 0.5 - 8.0)


func _target_w() -> float:
	if _locator == null:
		return NAN
	var target: Node = _locator.get("target") as Node
	if target == null or not (target is Node4D):
		return NAN
	return (target as Node4D).global_position.w


func _aligned() -> bool:
	var target_w: float = _target_w()
	if is_nan(target_w) or _player == null:
		return false
	return absf(target_w - _player.global_position.w) <= align_within


## Everything else currently off your slice. Drawn faintly, so a cluster of them reads as
## a place worth stepping to.
func _marks() -> Array:
	var out: Array = []
	if _manager == null:
		return out
	var agents: Array = _manager.get("agents") as Array
	if agents == null:
		return out
	for agent in agents:
		if agent is Node4D and is_instance_valid(agent):
			out.append((agent as Node4D).global_position.w)
	return out


## Which key closes the gap, read from the InputMap like every other prompt here.
func _key_hint(gap: float) -> String:
	var action: StringName = &"move_ana" if gap > 0.0 else &"move_kata"
	if not InputMap.has_action(action):
		return "?"
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			return OS.get_keycode_string(code)
	return "?"


func _label(text: String, at: Vector2, colour: Color) -> void:
	if _font == null:
		return
	draw_string(_font, at + Vector2(0.0, float(text_size)), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, colour)


func _text_width(text: String) -> float:
	if _font == null:
		return 0.0
	return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
