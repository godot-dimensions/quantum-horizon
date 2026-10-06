extends "res://ramon/Arboretum/carried/shrubbery/attractor_shape_4d.gd"
## Plain tesseract (4D box) sampling volume - the default/maximum shape
## every species defines via attractor_center_offset/attractor_half_extents
## (see ShrubSpecies.build_default_attractor_shape()). Matches
## shrubbery's own AttractorShape::Cube, generalized to 4D per the
## approved port plan.

## CARRIED (Arboretum, 5 Oct 2026): a copy of res://sandbox/shrubbery/box_attractor_shape_4d.gd, its class_name taken out
## and its references preloaded (Arboretum/carried/README.md).


var center: Vector4
var half_extents: Vector4


func _init(p_center: Vector4, p_half_extents: Vector4) -> void:
	center = p_center
	half_extents = p_half_extents


func get_bounds() -> Dictionary:
	return {"min": center - half_extents, "max": center + half_extents}


func contains(point: Vector4) -> bool:
	var local: Vector4 = point - center
	return (
		absf(local.x) <= half_extents.x
		and absf(local.y) <= half_extents.y
		and absf(local.z) <= half_extents.z
		and absf(local.w) <= half_extents.w
	)
