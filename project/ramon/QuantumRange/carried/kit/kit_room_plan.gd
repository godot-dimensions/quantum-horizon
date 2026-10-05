@tool
extends RefCounted

## Kit: a room's plan, worked out from what it is for rather than from its corners (Ramon, 5 Oct:
## "it would be good to be able to change the length of the creationlab wall without changing the
## overal width of the room ... feel free to redesign the room modelling system").
##
## THE ROOM is a box `width` wide, its entrance wall `front` metres in front of its middle and its
## back wall `back` metres behind it. Each back corner can be cut across by a corner wall of its own
## length, turned its own angle off the side wall it starts from. Lengthening a corner wall leaves
## the box as it is: the wall slides into the corner, its ends running along the side wall and the
## back wall, so the side wall and the back wall get shorter and nothing else moves. Both corner
## walls at 0 m: a rectangle. One builder, then, not one for each shape.
##
## THE WALLS HAVE NAMES, so what hangs on them (wall panels, doorways, signs) says which wall it
## means and keeps meaning it whatever the numbers do:
##
##   0 "left"          the left side wall, from the entrance back to the left corner wall
##   1 "left_corner"   the left corner wall (the Creation Lab's wall, carrying its introduction)
##   2 "back"          the back wall
##   3 "right_corner"  the right corner wall
##   4 "right"         the right side wall (the Creation Lab's research wall)
##   5 "entrance"      the entrance wall
##
## A corner wall at 0 m stays in the list with no length (KitRoom builds nothing for it), so the
## numbers never shift. A corner wall too long for its box is shortened until the side wall keeps
## `min_side` metres and the back wall `min_back`, its angle kept.
##
## NO class_name (engine_gotchas.md).

const NAMES := ["left", "left_corner", "back", "right_corner", "right", "entrance"]


## The plan: {"outline": PackedVector2Array (x, z, clockwise from the entrance's left end as
## kit_room_4d.gd wants), "names": PackedStringArray, "lengths": {name: metres}, "corners": {"left": [length,
## angle], "right": [...]} as they came out after any shortening}.
## `left` and `right` are each Vector2(length m, angle degrees off the side wall).
static func chamfered(width: float, front: float, back: float, left: Vector2, right: Vector2,
		min_side: float = 1.0, min_back: float = 1.0) -> Dictionary:
	var hw: float = width * 0.5
	var l: Array = _corner(hw, front, back, left, min_side, min_back)
	var r: Array = _corner(hw, front, back, right, min_side, min_back)
	var outline := PackedVector2Array([Vector2(-hw, front), Vector2(-hw, l[1]), Vector2(-l[0], -back), Vector2(r[0], -back),
		Vector2(hw, r[1]), Vector2(hw, front)])
	var lengths: Dictionary = {}
	for i in NAMES.size():
		lengths[NAMES[i]] = outline[i].distance_to(outline[(i + 1) % NAMES.size()])
	return {"outline": outline, "names": PackedStringArray(NAMES), "lengths": lengths,
		"corners": {"left": [float(l[2]), left.y], "right": [float(r[2]), right.y]}}


## One corner wall: [where the back wall ends (x, from the middle), where the side wall ends (z),
## its length after any shortening].
static func _corner(hw: float, front: float, back: float, c: Vector2, min_side: float, min_back: float) -> Array:
	var a: float = deg_to_rad(clampf(c.y, 1.0, 89.0))
	var length: float = maxf(0.0, c.x)
	var run_x: float = length * sin(a)
	var run_z: float = length * cos(a)
	var k: float = 1.0
	var room_x: float = maxf(0.0, hw - min_back * 0.5)
	var room_z: float = maxf(0.0, front + back - min_side)
	if run_x > room_x:
		k = minf(k, room_x / run_x)
	if run_z > room_z:
		k = minf(k, room_z / run_z)
	return [hw - run_x * k, -back + run_z * k, length * k]


## A corner wall's [length, angle] from the room's corners as the first five numbers gave them
## (half width `w`, back `d`, back wall half `b`, angled walls starting at z `c`), for settings saved
## before the plan.
static func corner_from_points(w: float, d: float, b: float, c: float) -> Vector2:
	var run_x: float = maxf(0.0, w - b)
	var run_z: float = maxf(0.0, c + d)
	return Vector2(Vector2(run_x, run_z).length(), rad_to_deg(atan2(run_x, run_z)))
