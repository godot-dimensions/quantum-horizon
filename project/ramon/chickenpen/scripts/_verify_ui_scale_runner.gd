extends SceneTree

## The pen's interface scale (pen_ui_scale_4d.gd): on in the pen, the dial held at its
## unscaled rectangle on screen, off while the theatre is open and while the pen is parked
## for the range's gallery, and on again after each. Headless is fine - it reads the
## window's content scale and the dial's rectangle, not the frame. The size is set straight
## on the node, not through the slider, so the player's saved setting is not touched.

var _room: Node
var _f := 0
var _step := 0
var _wait := 0
var _failed := 0
var _dial_was := 100.0
var _corner_was := Vector2.ZERO
var _want := 1.0
## What the scale loaded - the player's saved size - before the test sets its own.
var _loaded := 0.0


func _initialize() -> void:
	_room = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_room)
	current_scene = _room


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("  %s  %s  %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


## Where the dial is drawn on screen, in window pixels.
func _dial_on_screen() -> Rect2:
	var dial := _room.get_node("UI/SlicePlane") as Control
	var f: float = root.content_scale_factor
	return Rect2(dial.position * f, dial.size * dial.scale * f)


## Where the dial's anchors put it on screen with nothing scaled.
func _dial_as_authored() -> Rect2:
	var screen := Vector2(root.get_size())
	var tl := Vector2(0.6771 * screen.x, 0.426 * screen.y)
	var br := Vector2(screen.x - 10.0, screen.y - 10.0)
	return Rect2(tl, br - tl)


func _near(a: Rect2, b: Rect2) -> bool:
	return a.position.distance_to(b.position) < 1.5 and a.size.distance_to(b.size) < 1.5


func _process(_d: float) -> bool:
	_f += 1
	if _f == 4:
		_loaded = float(_room.get_node("Systems/UiScale").get("percent"))
	if _f == 5:
		_room.get_node("Systems/UiScale").set("percent", 130.0)
	if _f < 30:
		return false
	_wait += 1
	match _step:
		0:
			if _wait == 5:
				_want = 1.3
				print("   window %s, expecting %.2f" % [root.size, _want])
				_check("scaled in the pen", is_equal_approx(root.content_scale_factor, _want), "%.3f" % root.content_scale_factor)
				_check("the dial is where it always was", _near(_dial_on_screen(), _dial_as_authored()),
					"%s vs %s" % [_dial_on_screen(), _dial_as_authored()])
				# A small vertical spinner now, not a slider: a plus over a minus, 10% a press.
				var card: Node = _room.get_node("UI/Controls")
				_check("the size control is on the controls card", _room.get_node_or_null("UI/Controls/UiSize") != null)
				var ui: Node = _room.get_node("Systems/UiScale")
				_check("and shows the size in force", absf(float(card.call("size_percent")) - float(ui.get("percent"))) < 0.01,
					"%.0f" % float(card.call("size_percent")))
				var plus: Button = card.get("_plus")
				var minus: Button = card.get("_minus")
				_check("plus above minus", plus != null and minus != null and plus.position.y < minus.position.y
					and absf(plus.position.x - minus.position.x) < 0.5)
				_check("no slider to drag", card.find_children("*", "HSlider", true, false).is_empty())
				var was: float = float(card.call("size_percent"))
				plus.pressed.emit()
				_check("plus is 10% up", absf(float(card.call("size_percent")) - (was + 10.0)) < 0.01)
				minus.pressed.emit()
				minus.pressed.emit()
				_check("minus is 10% down", absf(float(card.call("size_percent")) - (was - 10.0)) < 0.01)
				plus.pressed.emit()
				for i in 40:
					card.call("step_size", -10.0)
				_check("never under 50%", absf(float(card.call("size_percent")) - 50.0) < 0.01)
				for i in 40:
					card.call("step_size", 10.0)
				_check("never over 300%", absf(float(card.call("size_percent")) - 300.0) < 0.01)
				# The buttons save what they choose; put back the size this machine had saved,
				# and the one this test runs at.
				ui.call("set_percent", _loaded)
				ui.set("percent", was)
				# The dial's own size: hidden until Shift, a hint in its place; a press scales
				# the dial about its bottom-right corner.
				_check("the dial's size is tucked away until Shift", not (card.get("_dial_plus") as Button).visible
					and (card.get("_dial_hint") as Label).visible)
				_dial_was = float(ui.get("dial_percent"))
				var dial := _room.get_node("UI/SlicePlane") as Control
				_corner_was = dial.get_global_rect().end
				card.call("step_dial", 20.0)
				_step = 10
				_wait = 0
				return false
				_room.get_node("Crossing").call("go_for_testing")
				_step = 1
				_wait = 0
		10:
			if _wait == 3:
				var ui: Node = _room.get_node("Systems/UiScale")
				var dial := _room.get_node("UI/SlicePlane") as Control
				var shown: float = dial.get_global_rect().size.x * dial.scale.x
				_check("the dial grows with its own size", absf(float(ui.get("dial_percent")) - (_dial_was + 20.0)) < 0.01,
					"%.0f%%" % float(ui.get("dial_percent")))
				var drawn: Vector2 = dial.get_global_transform().origin + dial.size * dial.get_global_transform().get_scale()
				_check("and stays in its corner", drawn.distance_to(_corner_was) < 2.0, "%s against %s" % [drawn, _corner_was])
				ui.call("set_dial_percent", _dial_was)
				_room.get_node("Crossing").call("go_for_testing")
				_step = 1
				_wait = 0
		1:
			if _wait == 20:
				_check("the theatre is open", bool(_room.get_node("Crossing").call("is_away")))
				_check("and nothing is scaled while it is", is_equal_approx(root.content_scale_factor, 1.0), "%.3f" % root.content_scale_factor)
				_room.get_node("Crossing").call("come_back")
				_step = 2
				_wait = 0
		2:
			if _wait == 20:
				_check("scaled again after the theatre", is_equal_approx(root.content_scale_factor, _want), "%.3f" % root.content_scale_factor)
				_room.get_node("Systems/RangeTrip").call("go")
				_step = 3
				_wait = 0
		3:
			if _wait == 20:
				_check("the gallery is up", current_scene != _room, str(current_scene.name))
				_check("and nothing is scaled while it is", is_equal_approx(root.content_scale_factor, 1.0), "%.3f" % root.content_scale_factor)
				_room.get_node("Systems/RangeTrip").call("come_back")
				_step = 4
				_wait = 0
		4:
			if _wait == 20:
				_check("home from the range", current_scene == _room)
				_check("scaled again after the range", is_equal_approx(root.content_scale_factor, _want), "%.3f" % root.content_scale_factor)
				_check("and the dial still where it was", _near(_dial_on_screen(), _dial_as_authored()))
				print("UI SCALE: %s" % ("ALL PASS" if _failed == 0 else "%d FAILED" % _failed))
				quit()
				return true
	if _f > 5000:
		print("UI SCALE: TIMED OUT at step %d" % _step)
		quit()
		return true
	return false
