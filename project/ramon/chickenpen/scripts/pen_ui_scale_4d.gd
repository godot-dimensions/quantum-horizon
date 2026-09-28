extends Node

## Everything on screen in the pen, bigger - except the dial in the bottom-right corner
## (Ramon, 28 Sept: "make the UI text and elements bigger, except the dial").
##
## ONE KNOB, NOT FORTY. The pen's interface is some forty controls, each with its own font
## sizes and pixel margins in its own script. Rather than turn each of them up, the window's
## content scale factor turns all of it up together - fonts, panels, margins, the belt, the
## tags - in proportion, and anything anchored to the screen's edges stays anchored to them.
##
## A PLAIN PERCENTAGE, set with the slider at the foot of the controls card
## (pen_controls_4d.gd) and kept between runs in user://pen_settings.cfg. 100 is the
## interface exactly as it was before any of this. The first version followed the window's
## height instead - 1.3 at 1080 lines - which on Ramon's 4K screen came to 2.6 and was far
## too big (28 Sept: "the UI elements are too big now ... add a UI size percentage
## slider"). What looks right depends on the screen and the eyes, so it is his to set.
##
## THE DIAL IS HELD AT EXACTLY ITS OLD SIZE. It is given the rectangle on screen it had
## before, in pixels, and a scale of one over the factor, so the two cancel.
##
## THE PEN ONLY. The factor is the whole window's, so it is put back to 1 whenever
## something else is on screen: while the theatre is open (no theatre work, 28 Sept), while
## the pen is parked for the range's gallery, and when the pen closes.
##
## Tags and head-anchored dialogue boxes place themselves with Camera4D.world_to_viewport,
## which answers in window pixels; world_tag_4d.gd and dialogue_box_4d.gd convert that to
## the canvas's units, which is a no-op wherever nothing is scaled.

## How big the interface is, in percent of how it was. What the slider last left it at is
## used instead, when there is one.
@export_range(50.0, 300.0, 5.0) var percent: float = 150.0
const SETTINGS := "user://pen_settings.cfg"
## Controls kept at their unscaled size and place on screen.
@export var keep_size_paths: Array[NodePath] = [NodePath("../../UI/SlicePlane")]
## Crossings during whose trips the scale is off (anything with is_away()).
@export var off_while_away_paths: Array[NodePath] = [NodePath("../../Crossing")]

var _factor := 1.0
var _kept: Array[Control] = []
## Per kept control: [anchors (l, t, r, b), offsets (l, t, r, b)] as authored.
var _layout: Array = []
var _away: Array[Node] = []


func _ready() -> void:
	# The theatre's crossing puts all of Systems to sleep while it is open, and this is the
	# one thing in there that has to notice it is.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var saved := ConfigFile.new()
	if saved.load(SETTINGS) == OK:
		percent = clampf(float(saved.get_value("ui", "percent", percent)), 50.0, 300.0)
	for path in keep_size_paths:
		var c := get_node_or_null(path) as Control
		if c != null:
			_kept.append(c)
			_layout.append([Vector4(c.anchor_left, c.anchor_top, c.anchor_right, c.anchor_bottom),
				Vector4(c.offset_left, c.offset_top, c.offset_right, c.offset_bottom)])
	for path in off_while_away_paths:
		var n := get_node_or_null(path)
		if n != null and n.has_method("is_away"):
			_away.append(n)


func _enter_tree() -> void:
	# Coming back from the range's gallery: _process picks the factor up again next frame.
	_factor = 1.0


func _exit_tree() -> void:
	_set_factor(1.0)


func _process(_delta: float) -> void:
	var want: float = percent / 100.0
	for n in _away:
		if is_instance_valid(n) and bool(n.call("is_away")):
			want = 1.0
	if not is_equal_approx(want, _factor):
		_set_factor(want)
	_hold_kept()


## Sets the size from the slider, and remembers it for next time.
func set_percent(p: float) -> void:
	percent = clampf(p, 50.0, 300.0)
	var saved := ConfigFile.new()
	saved.load(SETTINGS)
	saved.set_value("ui", "percent", percent)
	saved.save(SETTINGS)


func _set_factor(f: float) -> void:
	_factor = f
	if is_inside_tree():
		get_window().content_scale_factor = f
	elif Engine.get_main_loop() != null:
		(Engine.get_main_loop() as SceneTree).root.content_scale_factor = f
	if is_equal_approx(f, 1.0):
		for i in _kept.size():
			_restore(i)


## Where each kept control would be on screen unscaled, in pixels, held there.
func _hold_kept() -> void:
	if is_equal_approx(_factor, 1.0):
		return
	var screen := Vector2(get_viewport().get_size())
	for i in _kept.size():
		var c: Control = _kept[i]
		if not is_instance_valid(c):
			continue
		var a: Vector4 = _layout[i][0]
		var o: Vector4 = _layout[i][1]
		var top_left := Vector2(a.x * screen.x + o.x, a.y * screen.y + o.y)
		var bottom_right := Vector2(a.z * screen.x + o.z, a.w * screen.y + o.w)
		if c.anchor_right != 0.0 or c.anchor_bottom != 0.0:
			c.set_anchors_preset(Control.PRESET_TOP_LEFT)
		c.scale = Vector2.ONE / _factor
		c.position = top_left / _factor
		c.size = bottom_right - top_left


func _restore(i: int) -> void:
	var c: Control = _kept[i]
	if not is_instance_valid(c):
		return
	var a: Vector4 = _layout[i][0]
	var o: Vector4 = _layout[i][1]
	c.scale = Vector2.ONE
	c.anchor_left = a.x
	c.anchor_top = a.y
	c.anchor_right = a.z
	c.anchor_bottom = a.w
	c.offset_left = o.x
	c.offset_top = o.y
	c.offset_right = o.z
	c.offset_bottom = o.w
