@tool
extends Resource
class_name FrontierEdge

## One connection between two nodes on a sub-map.
##
## The OVERVIEW does not use these: its route is derived from catalogue order,
## because there the line means "next in the tour" and nothing else. Sub-maps do
## use them, because there the line means something much stronger - this work
## plausibly enables that work - and that cannot be inferred from an ordering.
##
## THE HONESTY RULE. `estimated` is the whole reason this resource is separate
## rather than a pair of coordinates. The proposal is explicit that the
## dependency graph is "a planning hypothesis, not an engineering truth", and
## that Aaron and Andrew must validate each technical edge before it is treated
## as authoritative. An estimated edge draws dashed and dimmer, so the map cannot
## silently promote a guess into a claim.

@export var from_id: String = "":
	set(value):
		from_id = value
		emit_changed()

@export var to_id: String = "":
	set(value):
		to_id = value
		emit_changed()

## Which hue the edge takes. Deliberately a ROLE rather than a colour, so the
## palette stays in [FrontierStyle] and one retune moves every map at once.
##
## STRUCTURAL is the neutral grey used for supporting links and decision-pack
## inputs - the proposal wants those "visually separated from engine
## dependencies", and a different weight of line is how that separation reads
## without adding a second legend.
enum Tone { PRIMARY, STRUCTURAL, WORLD, RESEARCH, DEFERRED }

@export var tone: Tone = Tone.PRIMARY:
	set(value):
		tone = value
		emit_changed()

## Dashed and dimmed: a proposed prerequisite that no engineer has confirmed.
@export var estimated: bool = false:
	set(value):
		estimated = value
		emit_changed()

## How far the bezier control points reach, as a fraction of the run between the
## two nodes. Sub-map graphs fan out vertically far more than the overview's
## single string does, and a fan drawn at one curvature either crosses itself or
## goes flat. -1 uses the style's default.
@export_range(-1.0, 1.0, 0.01) var curvature: float = -1.0:
	set(value):
		curvature = value
		emit_changed()
