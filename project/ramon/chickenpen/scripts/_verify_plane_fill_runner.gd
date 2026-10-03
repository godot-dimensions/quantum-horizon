extends SceneTree

## Sweep the level across the whole range of slices, checking two things that only showed
## up after a while of playing.
##
## IT MUST STAY A PLANE. For a plane over a rectangle, the corners taken in cyclic order
## satisfy h0 - h1 + h2 - h3 == 0 - the x and z terms cancel in pairs, whatever the tilt.
## So that alternating sum is an exact test of "is the picture still a plane", and it
## catches the fault this had: corners clamped one at a time to keep them on the panel,
## which pins one while the others carry on and buckles the quad.
##
## AND IT MUST DRAW WITHOUT COMPLAINT. A strong tilt folds the projected corners into a
## bow-tie, which draw_colored_polygon cannot triangulate. Runs windowed, one slice per
## frame, so the real draw path is exercised rather than a copy of it.

var _root: Node
var _f := 0
var _i := 0
var _worst_bend: float = 0.0
var _worst_at: String = ""
var _drew := 0

const STEPS: int = 13


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _process(_d) -> bool:
	_f += 1
	if _f < 40: return false
	var plane: Control = _root.get_node("UI/SlicePlane")
	var player: Node4D = _root.get_node("Player")
	var rig: Node4D = _root.get_node("Player/CameraRig")

	if _i >= STEPS * STEPS:
		print("\n   swept %d slices, from -69 to +69 degrees on both rotations" % _drew)
		print("   worst departure from a plane: %.6f  %s" % [_worst_bend, _worst_at])
		var ok: bool = _worst_bend < 0.001
		print("\n   %s the picture stays a plane everywhere"
			% ["PASS" if ok else "FAIL"])
		print("   (any 'Invalid polygon data' above is the fill folding)")
		print("\n%d FAIL(s)" % (0 if ok else 1))
		quit(0 if ok else 1)
		return true

	var xw: float = -1.2 + float(_i / STEPS) * 0.2
	var zw: float = -1.2 + float(_i % STEPS) * 0.2
	player.position = Vector4(0.0, 1.3, 0.0, -3.0 + float(_i % 7))
	rig.set("_slice_xw", xw); rig.set("_slice_zw", zw); rig.call("_apply")

	var pen: Rect2 = plane.call("_footprint")
	var h: Array = []
	for c in [Vector2(pen.position.x, pen.position.y), Vector2(pen.end.x, pen.position.y),
			Vector2(pen.end.x, pen.end.y), Vector2(pen.position.x, pen.end.y)]:
		h.append(float(plane.call("_w_above", c.x, c.y)))
	if not is_nan(h[0]):
		var drawn: Array = plane.call("_fitted", h)
		var bend: float = absf(drawn[0] - drawn[1] + drawn[2] - drawn[3])
		# Relative to the size of the thing, or a steep slice fails on rounding alone.
		var scale: float = maxf(absf(drawn[0]), maxf(absf(drawn[1]),
			maxf(absf(drawn[2]), absf(drawn[3]))))
		if scale > 0.001:
			bend /= scale
		if bend > _worst_bend:
			_worst_bend = bend
			_worst_at = "at xw %+.2f zw %+.2f" % [xw, zw]
		_drew += 1
	plane.queue_redraw()
	_i += 1
	return false
