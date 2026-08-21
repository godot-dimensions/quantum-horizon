@tool
class_name HubTierGateDef4D
extends Resource

## One row in hub2's catalogue: a destination plus its address.
##
## hub2 drops hub1's billboard entirely. A door's identity is its address -
## bearing, from this array's order (same as hub1's arc); tier, authored here -
## not a sign naming it. [member gate_name] survives only for tooling: node
## names, warnings, the verifier's printout. It is never drawn in the running
## game.
##
## Adding a prototype is still one `.tres` dropped into
## [member HubTierRing4D.gates] - bearing stays computed, never hand-placed.
## Tier is the one deliberate choice a resource makes, the same way
## [member HubGateDef4D.w_hidden] was hub1's.

## Tooling-only label - node names and the verifier's printout, never rendered
## in-game. Keep it anyway: "Gate3" in a warning is useless three weeks later.
@export var gate_name: String = "Untitled"

## Where this gate leads. Unused for now, same as hub1's field of the same
## name - stored so wiring up the actual transition later touches no layout
## code.
@export var target_scene: PackedScene

## 0 = ground, dead ahead, always reachable, no ramp built at all. 1..N indexes
## [member HubTierRing4D.tiers] (1-based). This is the "authored placement on
## top of a derived arc" the brief asked for: bearing stays computed from array
## order, tier is the one thing a resource decides.
@export_range(0, 4, 1) var tier: int = 0

## Set once the player has been through. Drives the state indicator only - the
## one piece of hub1's colour legend this scene keeps, since it is not text.
@export var visited: bool = false

## Manual placement escape hatches, same as hub1's - survive regeneration
## because the ring rebuilds its children from scratch every time anything
## changes.
@export_range(-30.0, 30.0, 0.5, "or_greater", "or_less", "suffix:°") var angle_nudge: float = 0.0
@export_range(-6.0, 6.0, 0.1, "or_greater", "or_less", "suffix:m") var radius_nudge: float = 0.0
