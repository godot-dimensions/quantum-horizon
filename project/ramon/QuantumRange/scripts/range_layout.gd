@tool
extends RefCounted

## Where everything in the Quantum Range stands, in one place (world metres; you face -Z downrange).
##
##   entrance corridor   z 10.5 .. 17.5, 6 m wide, you start at its far end
##   firing bay          z 0 .. 10, the hall's full 28 m, behind the counter on the firing line (z = 0)
##   downrange hall      z -36 .. 0, 28 m wide, no roof
##
## One rectangle, not a narrower bay opening onto the hall: the bay's own walls hid the outer half of
## each wing from the firing line (frame room/03_explainer, 5 Oct).
##   the two wings       blue walls standing just past the line, left and right, each turned to
##                       face the firing position: the explainer on the left, the metrics on the
##                       right (follow_up/quantum_range_final.md section 3)
##
## Every box in the room is 24 m deep through W (carried/scripts/chamber_build.gd W_DEPTH), so the
## room is still there when you turn your slice to reach a core 7 m off in W. You can step only
## W_LIMIT either way yourself.
##
## NO class_name (engine_gotchas.md): preload it.

const LINE_Z := 0.0
const BAY_BACK := 10.0
const HALL_HALF := 14.0
const HALL_FAR := -36.0
const WALL_H := 8.5
## The entrance door, along x, and its height.
const DOOR := Vector2(-1.6, 1.6)
const DOOR_H := 3.6
const CORRIDOR_HALF := 3.0
const CORRIDOR_END := 17.5
const CORRIDOR_H := 5.0
## Where you start, and where you stand to shoot.
const SPAWN := Vector4(0.0, 0.05, 16.0, 0.0)
const STAND := Vector4(0.0, 0.05, 1.5, 0.0)
## How far you can step through W yourself, either way.
const W_LIMIT := 2.0
## The counter on the firing line.
const COUNTER := Vector3(28.0, 1.05, 0.6)
## The wings: the middle of the left one's foot (x, z); the right one mirrors it. Each turns to face
## the firing position.
const WING := Vector2(-9.0, -5.2)
## The console stands on its own to your left in the bay, facing you across it (+X): not on the counter
## in front, where it covered the radar (frame play/00_lobby, 5 Oct).
const CONSOLE_AT := Vector4(-2.3, 0.0, 1.5, 0.0)
const WING_FACES := Vector2(0.0, 1.5)


## The hall's floor plan for KitRoom (carried/kit/kit_room_4d.gd): clockwise seen from above with -Z
## up the page, starting at the bay's back left corner.
static func outline() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-HALL_HALF, BAY_BACK), Vector2(-HALL_HALF, HALL_FAR), Vector2(HALL_HALF, HALL_FAR), Vector2(HALL_HALF, BAY_BACK),
	])


## The hall's walls, one name an edge of outline().
static func wall_names() -> PackedStringArray:
	return PackedStringArray(["left", "far", "right", "entrance"])


## How far along the entrance wall (edge 3 runs from x = +14 to x = -14) world x is.
static func entrance_along(x: float) -> float:
	return HALL_HALF - x


## The entrance door as a KitRoom doorway on the entrance wall.
static func doorway() -> Array:
	return ["entrance", entrance_along(DOOR.y), entrance_along(DOOR.x), DOOR_H]


## The turn that makes a wing at `at` face the firing position (its +Z towards it).
static func wing_yaw(at: Vector2) -> float:
	var n: Vector2 = (WING_FACES - at).normalized()
	return atan2(n.x, n.y)
