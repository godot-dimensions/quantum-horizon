@tool
extends RefCounted

## PathCreator: the path system's one source of numbers, from Ramon's Figma sheet "Path_Indicator"
## (Creation Lab, Aligned Layout file, page 5:20, read 5 Oct 2026). Nothing else in the path system
## types a size, a spacing, a clearance or a colour of its own.
##
## UNITS. The sheet draws every symbol on P = 40 units, P being the player's ground collision
## diameter, 0.6 m in the large field map (B1). So one sheet unit is 0.015 m, and a symbol comes out
## the size the sheet shows: the primary stencil pair (40 x 36 units) is 0.6 m along and 0.54 m
## across the route, the destination (88 x 88) 1.32 m. Repeats are the field map's (B1: "primary
## spacing 1.2 m; secondary 1.3 m"), which were walk-tested for that scale, not the symbol sheets'
## 1.5P / 1.6P.
##
## RULES carried as numbers (the sheet's "Claude implementation contract", rules 01-10):
##   arrows by cumulative arc length along a route, turned to each chord        (01)
##   no arrow within a node's radius + 0.25P                                    (03)
##   bends of straight chords: a ball and ring at a bend, small balls on a curve (B1)
##   a junction is a choice; a crossing without one breaks the weaker guide     (05)
##   arrival still; available: the outer 90 degree arc, one turn in 6 s;
##   focused: cyan and the centre accent, 160 ms colour change; completed: tick (07)
##
## NO class_name (engine_gotchas.md): preload it.

# -- scale ---------------------------------------------------------------------------------------

## The player's ground diameter, metres.
const P_M := 0.6
## Sheet units in one P.
const P_UNITS := 40.0
## Metres a sheet unit.
const UNIT_M := P_M / P_UNITS

## Repeats along a route, metres (B1 field map).
const PRIMARY_REPEAT_M := 1.2
const SECONDARY_REPEAT_M := 1.3
## Clear floor round a node or a destination, beyond its art (rule 03): 0.25P.
const CLEAR_M := 0.25 * P_M
## A segment shorter than this carries only the guide line (B1: "short segments may use only a
## guide when an arrow would crowd the end markers"): room for one mark and both clearances.
const SHORT_SEGMENT_M := 1.2

## The guide line under the marks (Ramon, 5 Oct: "one subtle blue line under the icons to clearly
## see the path yet subtle"), metres wide.
const GUIDE_W_M := 0.035
## How fast marks flow along a route, metres a second (Ramon: "arrows should move at all times").
const FLOW_M_S := 0.55
## A segment box: how far above the floor it floats, and how thick it is.
const PROUD_M := 0.012
const BOX_H_M := 0.01

# -- symbols (sheet units; each library's masters are this size) ---------------------------------

## The ten symbol slots every library draws, and their size in sheet units.
const SLOTS := {
	"A": {"name": "primary route", "size": Vector2(40, 36)},
	"B": {"name": "secondary route", "size": Vector2(28, 30)},
	"C": {"name": "junction", "size": Vector2(16, 16)},
	"D": {"name": "arrival", "size": Vector2(88, 88)},
	"E": {"name": "action available", "size": Vector2(88, 88)},
	"F": {"name": "focused action", "size": Vector2(88, 88)},
	"G": {"name": "completed", "size": Vector2(88, 88)},
	"H": {"name": "rectangular frame", "size": Vector2(180, 132)},
	"I": {"name": "round frame", "size": Vector2(180, 180)},
	"J": {"name": "player scale", "size": Vector2(40, 40)},
}

## The pivots the B1 field map adds (no sheet symbol of their own): a bend is a small solid ball
## in one thin ring, a curve's joint a small solid ball alone. Sheet units, measured off the field
## map's export at its 40 px a metre (5 Oct): the ring 0.39 m across, the ball 0.16 m.
const BEND_BALL_R := 5.3
const BEND_RING_R := 12.0
const BEND_RING_W := 1.7
const CHORD_BALL_R := 5.3
## The field map draws its junctions larger than the library's master ("the larger segmented B1
## node"): 0.39 m across against the master's 0.24 m.
const JUNCTION_SCALE := 1.6

## Where a route's marks end at a node. "hide": they run right up to the node's art and slide
## under it as they flow (Ramon: "use the hide under strip technique"), the art being what they
## hide under. "keep": they stop the sheet's 0.25P short of it (rule 03), cut where they cross.
const CLEAR_STYLE := "hide"
## In "hide", this far short of the art's edge, metres.
const HIDE_GAP_M := 0.02
## The secondary route's guide is dotted, as the field map draws it: a dot this far apart, metres.
const GUIDE_DOT_M := 0.16

# -- motion (rule 07) --------------------------------------------------------------------------------

## The available-action arc: one clockwise turn in this many seconds.
const ARC_TURN_S := 6.0
## The colour change into and out of focus, seconds.
const FOCUS_FADE_S := 0.16

# -- colour (the sheet's variables, "--floor-*") ----------------------------------------------------

const TOKENS := {
	"blue": Color("#1761d7"),
	"cyan": Color("#49d9ff"),
	"muted": Color("#8eaac8"),
	"edge": Color("#668bae"),
	"floor": Color("#d7e3ef"),
	"white": Color("#f1f7ff"),
	"ink": Color("#0a1426"),
	"panel": Color("#10233d"),
}
## The WALK look (Ramon, 5 Oct: "toggle the whole arrow system to a bland beige sandy albedo
## color", for the pen): one sand, lit like paint on the ground, no glow. One colour for now.
const SAND := Color("#cdb48c")

# -- W (PathCreator's own, not on the sheet) ---------------------------------------------------------

## The W range the dev space is built for: the floor and the widest band reach this far ana and
## kata of W 0, metres.
const W_REACH := 15.0
## A band's edge: marks dissolve over this much W rather than stopping dead, metres.
const W_SOFT := 0.35


## A slot's size in metres.
static func slot_m(slot: String) -> Vector2:
	return (SLOTS.get(slot, SLOTS["A"])["size"] as Vector2) * UNIT_M
