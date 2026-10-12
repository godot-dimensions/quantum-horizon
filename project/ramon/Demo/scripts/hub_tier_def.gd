@tool
class_name HubTier4D
extends Resource

## One elevation tier above hub2's ground floor: a height, and the w-slice its
## connecting ramp lives in.
##
## Tier 0 (dead ahead, ground level) is not described here at all - it has no
## ramp and no w-dependency, so [HubTierRing4D] hardcodes it. This array is tier
## 1, 2, ... in order; [member HubTierGateDef4D.tier] just indexes into it
## (1-based, since 0 means ground).
##
## THE STRUCTURAL IDEA: a tier's platform is w-invariant, same as hub1's
## structure - it never vanishes underfoot. Only the ramp climbing up to it is
## gated to [member w_offset] +/- half of [member w_extent], the same trick hub1
## spends on its one ghosted door, but spent here on the path instead of the
## door, and on every non-ground tier instead of one special case. See
## HUB2_README.md.

## Height of the platform above the main floor, in metres. Subtle by design - a
## step or a shallow ramp's worth, not a tower. Falling off a platform this
## short is a non-event, which is deliberate: it is the fallback way down when
## the ramp itself is not in your slice.
@export_range(0.1, 3.0, 0.05, "suffix:m") var height: float = 0.6

## Horizontal distance the ramp covers to gain [member height]. Longer runs read
## as gentler slopes - height / ramp_run is the rise, and it needs to stay well
## inside whatever angle CharacterBody4D's floor snapping treats as walkable.
@export_range(1.0, 10.0, 0.1, "suffix:m") var ramp_run: float = 3.0

## Centre of the w-band the ramp exists in. Same idea as the hidden offset on
## hub1's one ghosted gate, generalised from one door to one tier's whole
## staircase.
@export_range(0.0, 40.0, 0.5, "suffix:m") var w_offset: float = 6.0

## Width of that w-band. Wide enough that a normal walking pace up the ramp
## does not clip its far edge, short enough that the ramp reads as genuinely
## absent everywhere else.
@export_range(0.5, 40.0, 0.5, "suffix:m") var w_extent: float = 5.0
