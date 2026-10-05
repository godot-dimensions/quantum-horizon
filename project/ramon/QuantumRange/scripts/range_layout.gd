@tool
extends RefCounted

## Where everything in the Quantum Range stands, in one place (world metres; you face -Z downrange).
##
##   entrance corridor   z 10.5 .. 17.5, 6 m wide, you start at its far end
##   firing bay          z 0 .. 10, the hall's full 23 m, behind the counter on the firing line (z = 0)
##   downrange hall      z -36 .. 0, 23 m wide, no roof
##   the two walls       the hall's side walls are split just past the line: from z 0 to -11 the left
##                       one is the explainer and the right one the metrics wall, each a whole wall in
##                       code blue with its panel in the middle (the kit's rule for two panels on long
##                       walls: split them into walls in line). From the firing position each faces you
##                       about 27 degrees off square, readable, and neither stands in the view downrange.
##
## Two tries before this, both measured from the firing line: a narrower bay opening onto the hall hid
## half of each panel behind the bay's walls (room/03_explainer); two blue wings standing past the line,
## turned to face you, took 80 degrees of the view between them at the kit's fixed 9.6 m (moments/, 5 Oct).
##
## Every box in the room is 24 m deep through W (carried/scripts/chamber_build.gd W_DEPTH), so the
## room is still there when you turn your slice to reach a core 7 m off in W. You can step only
## W_LIMIT either way yourself.
##
## NO class_name (engine_gotchas.md): preload it.

const LINE_Z := 0.0
const BAY_BACK := 10.0
const HALL_HALF := 11.5
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
const COUNTER := Vector3(23.0, 1.05, 0.6)
## Where the panel walls run along the side walls (z), from the line out.
const PANEL_WALL := Vector2(0.0, -11.0)
## How far downrange you can walk while no experiment runs: up to the two walls, to read them close
## (their tables do not read from the line at 13 m, frame room/04_metrics, 5 Oct). While one runs the
## counter holds you (line_hold()).
const WALK_OUT := -10.4
## The console stands on its own to your left in the bay, facing you across it (+X): not on the counter
## in front, where it covered the radar (frame play/00_lobby, 5 Oct).
const CONSOLE_AT := Vector4(-2.3, 0.0, 1.5, 0.0)


## Where the counter stops you while an experiment runs (your z can go no lower).
static func line_hold() -> float:
	return LINE_Z + COUNTER.z * 0.5 + 0.3


## The hall's floor plan for KitRoom (carried/kit/kit_room_4d.gd): clockwise seen from above with -Z
## up the page, starting at the bay's back left corner.
static func outline() -> PackedVector2Array:
	var h: float = HALL_HALF
	return PackedVector2Array([
		Vector2(-h, BAY_BACK), Vector2(-h, PANEL_WALL.x), Vector2(-h, PANEL_WALL.y), Vector2(-h, HALL_FAR),
		Vector2(h, HALL_FAR), Vector2(h, PANEL_WALL.y), Vector2(h, PANEL_WALL.x), Vector2(h, BAY_BACK),
	])


## The hall's walls, one name an edge of outline().
static func wall_names() -> PackedStringArray:
	return PackedStringArray(["bay_left", "explainer", "left", "far", "right", "metrics", "bay_right", "entrance"])


## The entrance wall's edge number.
const ENTRANCE_EDGE := 7


## How far along the entrance wall (it runs from x = +HALL_HALF to -HALL_HALF) world x is.
static func entrance_along(x: float) -> float:
	return HALL_HALF - x


## The entrance door as a KitRoom doorway on the entrance wall.
static func doorway() -> Array:
	return ["entrance", entrance_along(DOOR.y), entrance_along(DOOR.x), DOOR_H]

