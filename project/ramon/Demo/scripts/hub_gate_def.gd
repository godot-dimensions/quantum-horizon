@tool
class_name HubGateDef4D
extends Resource

## One row in the hub's catalogue: a destination plus the sign that advertises it.
##
## The hub scene contains no billboards and no hand-placed gates. It holds a
## [HubGateRing4D] with an array of these, and the ring builds everything from
## them. Adding a prototype to the demo is therefore one new `.tres` in
## `res://ramon/Demo/gates/` dragged into that array - no scene editing, no
## manual placement, no re-spacing of the gates that were already there.
##
## Because the array's order drives angular position, reordering it in the
## inspector re-lays-out the whole arc. That makes "which prototype sits in the
## centre slot" a two-second experiment, which matters: the centre gate is the
## first thing a stakeholder looks at.

## Shown large on the billboard. Readable from the spawn point, so keep it short -
## if it needs two lines the prototype needs a better name.
@export var gate_name: String = "Untitled"

## One line, shown small. Say what was technically hard, not what it feels like:
## the audience for this demo is asking why the work is worth funding.
@export_multiline var blurb: String = ""

## Flat silhouette, ideally single-colour. Identity is carried by shape rather
## than colour so that colour stays free to mean state (visited / locked).
@export var icon: Texture2D

## Where this gate leads. Unused for now - the hub does not teleport yet - but
## stored here so wiring it up later touches no layout code.
@export var target_scene: PackedScene

## Marks this entry as the gate that only completes when the player slice-rotates.
## The ring spawns the ghosted variant for it instead of a solid frame. Exactly
## one entry should normally set this: it is the hub's only w-varying structure,
## and that scarcity is what makes it legible as special.
@export var w_hidden: bool = false

## Set once the player has been through. Drives the state indicator only.
@export var visited: bool = false

## Manual placement escape hatch, in degrees, added to the computed angle. Lives
## here rather than as a scene override so that it survives regeneration - the
## ring rebuilds its children from scratch every time anything changes.
@export_range(-30.0, 30.0, 0.5, "or_greater", "or_less", "suffix:°") var angle_nudge: float = 0.0

## Same idea for radial distance, in metres.
@export_range(-6.0, 6.0, 0.1, "or_greater", "or_less", "suffix:m") var radius_nudge: float = 0.0
