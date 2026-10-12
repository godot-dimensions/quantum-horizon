extends SceneTree

## Does the diagram actually follow the window, or is it still a fixed box?
##
## The panel is anchored as a fraction of the viewport and its three scales - ground, w,
## and the lettering - are fractions of the panel. So at twice the width everything should
## be about twice the size, and the world extent it covers should be UNCHANGED: a bigger
## window shows the same diagram bigger, not more of it at the same size.

var _root: Node
var _f := 0
var _fails: Array = []


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _check(label: String, ok: bool, detail: String) -> void:
	print("   %s %-36s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fails.append(label)


func _sample(plane: Control) -> Array:
	# The panel's size, and the pen's drawn width in pixels at that size.
	var pen: Rect2 = plane.call("_footprint")
	# The dial's own view centre, which now follows the player rather than sitting at a
	# fixed offset from the pen.
	var origin: Vector2 = plane.size * 0.5
	var radius: float = minf(plane.size.x, plane.size.y) * 0.5 - 12.0 * float(plane.call("_ui"))
	var mid: Vector2 = plane.call("_view_centre", pen.position + pen.size * 0.5,
		origin, radius)
	var a: Vector2 = plane.call("_plan", pen.position.x, pen.position.y, 0.0,
		Vector2.ZERO, mid)
	var b: Vector2 = plane.call("_plan", pen.end.x, pen.end.y, 0.0, Vector2.ZERO, mid)
	return [plane.size, (b - a).length(), float(plane.call("_ground_px")),
		float(plane.call("_w_px"))]


var _step := 0
var _small: Array = []
var _big: Array = []


## STEPPED, NOT AWAITED. `await process_frame` inside a SceneTree's _process never
## returns its bool, so the runner simply hangs - the resize has to be spread over
## frames by hand.
func _process(_d) -> bool:
	_f += 1
	if _f < 60: return false
	var plane: Control = _root.get_node("UI/SlicePlane")

	match _step:
		0:
			root.size = Vector2i(1280, 720)
		1:
			_small = _sample(plane)
			root.size = Vector2i(2560, 1440)
		2:
			pass
		3:
			_big = _sample(plane)
		_:
			print("
--- the same diagram at two window sizes ---")
			print("   1280x720   panel %s  pen drawn %.0f px  ground %.2f px/unit"
				% [_small[0], _small[1], _small[2]])
			print("   2560x1440  panel %s  pen drawn %.0f px  ground %.2f px/unit"
				% [_big[0], _big[1], _big[2]])
			var grew: float = _big[0].x / maxf(_small[0].x, 1.0)
			_check("the panel grows with the window", grew > 1.8 and grew < 2.2,
				"%.2f times wider" % grew)
			var drawn: float = _big[1] / maxf(_small[1], 0.01)
			_check("and so does what is drawn on it", absf(drawn - grew) < 0.1,
				"the pen is drawn %.2f times wider" % drawn)
			# Same world extent either way: the scales are fractions, so a bigger window
			# shows the same picture larger, not a wider view of the field.
			var world_small: float = _small[0].x / maxf(_small[2], 0.01)
			var world_big: float = _big[0].x / maxf(_big[2], 0.01)
			_check("it still covers the same ground", absf(world_small - world_big) < 0.5,
				"%.1f world units across either way" % world_small)
			print("
%d FAIL(s)" % _fails.size())
			quit(1 if _fails.size() > 0 else 0)
			return true
	_step += 1
	_f = 55
	return false
