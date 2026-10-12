class_name VoronoiAttractorShape4D
extends AttractorShape4D
## Intersection of a base shape (a tree's own default box) with its own
## Voronoi cell among a set of sites (tree root positions) - eroded by
## crown_shyness_margin for a visible gap between neighboring trees'
## canopies, matching real "crown shyness."
##
## No explicit Voronoi polytope is ever constructed - a point's Voronoi
## cell membership is just "is my own site the closest site to this
## point," a direct O(other_sites) distance comparison that generalizes
## to 4D for free (Voronoi cells are a metric concept, not inherently
## 2D/3D - explicit boundary construction would be the part that's hard
## to generalize, and this never needs one).
##
## own_site/other_sites are WORLD-space root positions, but `contains()`
## receives a LOCAL point (relative to the tree's own root, matching
## every other shape/growth computation in this project - see
## attractor_shape_4d.gd's own header) - converted to world space
## internally via `local_point + own_site` before the distance
## comparisons, so growth math itself never needs to become world-space
## aware.
##
## crown_shyness_margin is a margin on (distance to other site - distance
## to own site), not a direct Euclidean clearance from the cell boundary -
## for two sites, the exact perpendicular-bisector clearance in that
## metric is margin/2 (moving distance x off the bisector toward one site
## changes each distance by ~x in opposite directions, so the difference
## changes by ~2x) - callers (see shrubbery_forest.gd) account for this
## by doubling the requested voxel clearance when constructing the margin.
var base_shape: AttractorShape4D
var own_site: Vector4
var other_sites: Array[Vector4]
var crown_shyness_margin: float


func _init(p_base_shape: AttractorShape4D, p_own_site: Vector4, p_other_sites: Array[Vector4], p_crown_shyness_margin: float) -> void:
	base_shape = p_base_shape
	own_site = p_own_site
	other_sites = p_other_sites
	crown_shyness_margin = p_crown_shyness_margin


## Voronoi/crown-shyness intersection only ever SHRINKS the base shape,
## never extends it - the base shape's own bounds remain a valid (if
## looser than necessary) rejection-sampling envelope.
func get_bounds() -> Dictionary:
	return base_shape.get_bounds()


func contains(local_point: Vector4) -> bool:
	if not base_shape.contains(local_point):
		return false
	var world_point: Vector4 = local_point + own_site
	var dist_to_own: float = world_point.distance_to(own_site)
	for other_site in other_sites:
		var dist_to_other: float = world_point.distance_to(other_site)
		if dist_to_other - dist_to_own <= crown_shyness_margin:
			return false
	return true
