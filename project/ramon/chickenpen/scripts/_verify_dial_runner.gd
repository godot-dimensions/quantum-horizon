extends SceneTree

## Does the dial hold still near the pen, follow you past the dead zone, and never let
## you off the edge of it?
##
## The third is the one worth testing hard. The projection is not isotropic - a step along
## x moves you across the dial about twice as far as a step along z moves you down it - so
## a dead zone measured in world units would hold in one direction and leak in the other,
## and the failure would only show up walking one particular way. This sweeps every
## bearing.

var _root: Node
var _f := 0
var _fails: Array = []


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _check(label: String, ok: bool, detail: String) -> void:
	print("   %s %-38s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fails.append(label)


## Where the player is drawn on the dial, in pixels from its middle, with the view doing
## whatever it would do at that position.
func _offset(plane: Control, player: Node4D, x: float, z: float) -> float:
	player.position = Vector4(x, 1.3, z, player.position.w)
	var pen: Rect2 = plane.call("_footprint")
	var anchor: Vector2 = pen.position + pen.size * 0.5
	var origin: Vector2 = plane.size * 0.5
	var radius: float = minf(plane.size.x, plane.size.y) * 0.5 - 12.0 * float(plane.call("_ui"))
	var mid: Vector2 = plane.call("_view_centre", anchor, origin, radius)
	var spot: Vector2 = plane.call("_plan", x, z, 0.0, origin, mid)
	return (spot - origin).length() / radius


func _still(plane: Control, player: Node4D, x: float, z: float) -> bool:
	player.position = Vector4(x, 1.3, z, player.position.w)
	var pen: Rect2 = plane.call("_footprint")
	var anchor: Vector2 = pen.position + pen.size * 0.5
	var origin: Vector2 = plane.size * 0.5
	var radius: float = minf(plane.size.x, plane.size.y) * 0.5 - 12.0 * float(plane.call("_ui"))
	return (plane.call("_view_centre", anchor, origin, radius) as Vector2)\
		.is_equal_approx(anchor)


func _process(_d) -> bool:
	_f += 1
	if _f < 60: return false
	var plane: Control = _root.get_node("UI/SlicePlane")
	var player: Node4D = _root.get_node("Player")
	var pen: Rect2 = plane.call("_footprint")
	var anchor: Vector2 = pen.position + pen.size * 0.5
	var zone: float = float(plane.get("dead_zone"))

	print("\n--- standing at the pen ---")
	_check("the view is on the pen", _still(plane, player, anchor.x, anchor.y),
		"and stays there")
	_check("and you are in the middle", _offset(plane, player, anchor.x, anchor.y) < 0.02,
		"you sit %.3f of the way out" % _offset(plane, player, anchor.x, anchor.y))

	print("\n--- walking out in every direction ---")
	var worst: float = 0.0
	var worst_at: String = ""
	var held: int = 0
	var followed: int = 0
	for bearing in 24:
		var a: float = TAU * float(bearing) / 24.0
		for step in 30:
			var d: float = float(step) * 2.0
			var x: float = anchor.x + sin(a) * d
			var z: float = anchor.y + cos(a) * d
			var off: float = _offset(plane, player, x, z)
			if off > worst:
				worst = off
				worst_at = "%.0f units out on bearing %.0f" % [d, rad_to_deg(a)]
			if _still(plane, player, x, z):
				held += 1
			else:
				followed += 1
	print("   swept 24 bearings out to 58 units: %d positions held the view, %d moved it"
		% [held, followed])
	# The clamp allows a hair over the ring for rounding; anything real would be far more.
	_check("you never leave the dial", worst <= zone + 0.01,
		"furthest you were ever drawn: %.3f of the radius (%s)" % [worst, worst_at])
	_check("the view does hold near the pen", held > 0, "%d positions inside the zone" % held)
	_check("and does follow further out", followed > 0, "%d positions outside it" % followed)

	# Inside the zone it must not creep: the pen has to sit still while you work near it.
	var crept: bool = false
	for step in 6:
		if not _still(plane, player, anchor.x + float(step) * 0.8, anchor.y):
			crept = true
			break
	_check("no creep inside the zone", not crept, "the pen does not drift as you move")

	print("\n%d FAIL(s)" % _fails.size())
	quit(1 if _fails.size() > 0 else 0)
	return true
