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
var _want := 1.0


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
				var slider := _room.get_node_or_null("UI/Controls/UiSize") as HSlider
				_check("the size slider is on the controls card", slider != null)
				if slider != null:
					var saved: float = float(_room.get_node("Systems/UiScale").get("percent"))
					_check("and starts where the scale is", absf(slider.value - saved) < 0.01 or absf(slider.value - 130.0) < 0.01,
						"slider %.0f, scale %.0f" % [slider.value, saved])
					_check("from 50% to 300%", slider.min_value == 50.0 and slider.max_value == 300.0)
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
