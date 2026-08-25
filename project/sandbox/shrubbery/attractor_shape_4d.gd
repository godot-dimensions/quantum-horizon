class_name AttractorShape4D
extends RefCounted
## Base "attractor sampling volume" shape - the space-colonization step
## (ShrubGenerator4D.spawn_attractors_from_shape) samples uniformly from
## whatever shape it's handed via rejection sampling against get_bounds(),
## rather than being hardcoded to one specific volume. Subclasses define
## an actual region: BoxAttractorShape4D (the plain default, matching
## shrubbery's own AttractorShape::Cube generalized to 4D), and
## VoronoiAttractorShape4D (intersects a base shape with an eroded
## nearest-root region, for the forest scene's crown-shyness effect).
##
## Coordinates are always LOCAL to whichever tree is being generated
## (that tree's own trunk root at Vector4.ZERO) - a tree's own growth
## math never needs to know its world placement (see
## shrubbery_forest.gd's own header for why: only the attractor SHAPE
## needs world-space awareness, for the Voronoi test against other
## trees' world root positions, via VoronoiAttractorShape4D's own
## own_site/other_sites).

## Returns {"min": Vector4, "max": Vector4} - an axis-aligned bounding
## box enclosing the whole shape, used as the rejection-sampling envelope.
func get_bounds() -> Dictionary:
	push_error("AttractorShape4D.get_bounds() must be overridden")
	return {"min": Vector4.ZERO, "max": Vector4.ZERO}


func contains(point: Vector4) -> bool:
	push_error("AttractorShape4D.contains() must be overridden")
	return false
