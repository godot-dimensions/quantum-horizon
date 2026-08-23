class_name ShrubBranch4D
extends RefCounted
## One node of a shrub's branch graph - a direct port of shrubbery's own
## `Branch` struct (github.com/TanTanDev/shrubbery), generalized from
## Vec3 to Vector4 per the port plan. A parent-pointer arena entry, not a
## scene-graph node: `branches[parent_index]` is the branch this one grew
## from, -1 for the trunk root. See shrub_generator.gd for how the arena
## is built and walked.

var parent_index: int
var position: Vector4
var direction: Vector4
var thickness: float
var generation: int
var id: int

func _init(p_position: Vector4, p_direction: Vector4, p_thickness: float, p_parent_index: int, p_generation: int, p_id: int) -> void:
	position = p_position
	direction = p_direction.normalized() if p_direction.length() > 0.0001 else Vector4(0, 1, 0, 0)
	thickness = p_thickness
	parent_index = p_parent_index
	generation = p_generation
	id = p_id
