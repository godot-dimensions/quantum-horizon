@tool
extends RefCounted

## Where everything in the Quantum Range stands, in one place (world metres; you face -Z downrange).
##
##   entrance corridor   z 13.5 .. 20.5, 6 m wide, you start at its far end
##   firing bay          z 0 .. 13, 18 m wide, behind the counter on the firing line (z = 0)
##   downrange hall      z -36 .. 0, 23 m wide, no roof
##   the two walls       the bay's own side walls, right next to you: from the entrance wall (z 13) to
##                       the counter (z 0) the left one is the explainer and the right one the metrics
##                       wall, each a whole wall in code blue with its panel in the middle, ending at
##                       the counter (Ramon, 6 Oct: "directly next to you, on the 2 empty walls, and
##                       ending with the range collider bar"). Downrange the side walls are plain.
##                       The bay is narrower than the hall so the walls stand 9 m from its middle, as
##                       far as the Creation Lab's stand from its exhibit (8.5 and 10 m): the same kit
##                       panels, so the same type, read at the same size (Ramon, 6 Oct; measured in
##                       smoke_test_output/quantum_range/walls/, scripts/_compare_walls_runner.gd).
##                       13 m long, so the 9.6 m panel has blue round it as in the Creation Lab (10.6 and
##                       12 m walls there); at 10 m it filled its wall edge to edge and looked squeezed.
##
## Three tries before this: a narrower bay opening onto the hall hid half of each panel behind the bay's
## walls; two blue wings standing past the line took 80 degrees of the view; then the side walls just past
## the line, which read only as headings from the line and needed a walk out to the walls (5 Oct).
##
## Every box in the room is 24 m deep through W (carried/scripts/chamber_build.gd W_DEPTH), so the
## room is still there when you turn your slice to reach a core 7 m off in W. You can step only
## W_LIMIT either way yourself.
##
## NO class_name (engine_gotchas.md): preload it.

const LINE_Z := 0.0
const BAY_BACK := 13.0
const HALL_HALF := 11.5
const BAY_HALF := 9.0
## Where the bay steps out to the wider hall: half a metre past the line, the walls' thickness, so the
## white wall there stands at the end of each blue wall, its end frame, beside the counter (Ramon, 6 Oct:
## "reposition the white bars, not make the blue wall stop").
const STEP_Z := LINE_Z - 0.5
const HALL_FAR := -36.0
const WALL_H := 8.5
## The entrance door, along x, and its height.
const DOOR := Vector2(-1.6, 1.6)
const DOOR_H := 3.6
const CORRIDOR_HALF := 3.0
const CORRIDOR_END := 20.5
const CORRIDOR_H := 5.0
## Where you start, and where you stand to shoot.
const SPAWN := Vector4(0.0, 0.05, 19.0, 0.0)
const STAND := Vector4(0.0, 0.05, 1.5, 0.0)
## How far you can step through W yourself, either way.
const W_LIMIT := 2.0
## The counter on the firing line.
const COUNTER := Vector3(BAY_HALF * 2.0, 1.05, 0.6)
## The console floats in the middle of the bay, in front of you as you come in; once you start something
## it flies to beside you and stays there, facing you (scripts/range_console_4d.gd).
const CONSOLE_LOBBY := Vector4(0.0, 0.0, 6.5, 0.0)


## Where the counter stops you (your z can go no lower). The walls are in the bay now, so nothing calls
## you downrange: it holds you whether or not an experiment runs.
static func line_hold() -> float:
	return LINE_Z + COUNTER.z * 0.5 + 0.3


## The hall's floor plan for KitRoom (carried/kit/kit_room_4d.gd): clockwise seen from above with -Z
## up the page, starting at the bay's back left corner. The side walls are split at the line, so the two
## blue walls end at the counter.
static func outline() -> PackedVector2Array:
	var h: float = HALL_HALF
	return PackedVector2Array([
		Vector2(-BAY_HALF, BAY_BACK), Vector2(-BAY_HALF, STEP_Z), Vector2(-h, STEP_Z), Vector2(-h, HALL_FAR),
		Vector2(h, HALL_FAR), Vector2(h, STEP_Z), Vector2(BAY_HALF, STEP_Z), Vector2(BAY_HALF, BAY_BACK),
	])


## The hall's walls, one name an edge of outline().
static func wall_names() -> PackedStringArray:
	return PackedStringArray(["explainer", "step_left", "left", "far", "right", "step_right", "metrics", "entrance"])


## The entrance wall's edge number.
const ENTRANCE_EDGE := 7


## How far along the entrance wall (it runs from x = +BAY_HALF to -BAY_HALF) world x is.
static func entrance_along(x: float) -> float:
	return BAY_HALF - x


## The entrance door as a KitRoom doorway on the entrance wall.
static func doorway() -> Array:
	return ["entrance", entrance_along(DOOR.y), entrance_along(DOOR.x), DOOR_H]

