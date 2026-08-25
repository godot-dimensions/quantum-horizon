class_name AreaCaptureTargetCluster
extends Node4D
## A tight cluster of small target cubes for the player to fully encapsulate
## with a drawn box (see area_capture_controller.gd). Spread across x/z/AND
## w, not just x/z, and not all sharing one w value - specifically so a lazy
## box drawn without ever rotating the 4D slice (rotate_4d) between the two
## corner presses can't trivially contain them all. That's the whole point
## of this prototype, so the layout has to actually test it.
##
## Fixed, authored offsets rather than randomized - a hand-tuned puzzle
## layout that's easy to reason about and re-screenshot for verification,
## matching this project's own convention for small authored encounters
## (e.g. contest_sequence_01.tres) rather than gallery_target_spawner.gd's
## randomized-within-bounds style, which is for a very different (endless,
## disposable-target) mode.
##
## No collision shape - these are pure visual/logical targets for a future
## capture-check to compare bounds against, not obstacles the player can
## bump into or a raycast needs to hit.

@export var cluster_center: Vector4 = Vector4(0.0, 0.0, 2.0, 0.0)
@export var cube_size: float = 0.6
@export var cube_color: Color = Color(0.2, 0.85, 0.9)

## x/y/z/w offsets from cluster_center - y always 0 here since each cube's
## actual height is fixed separately (see _ready) to rest on the ground.
const _OFFSETS: Array[Vector4] = [
	Vector4(0.0, 0.0, 0.0, 0.0),
	Vector4(1.4, 0.0, -0.8, 0.9),
	Vector4(-1.1, 0.0, 0.6, -1.3),
	Vector4(0.7, 0.0, 1.2, 0.4),
	Vector4(-1.5, 0.0, -1.1, -0.6),
]

## Every spawned cube, for a future capture-check to test against - each
## carries its own known .position and .mesh.size, enough to compute full
# world-space bounds without any extra bookkeeping here.
var cubes: Array[MeshInstance4D] = []


func _ready() -> void:
	var shared_material := TetraMaterial4D.new()
	shared_material.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_SINGLE_COLOR
	shared_material.albedo_color = cube_color

	for offset in _OFFSETS:
		var cube := MeshInstance4D.new()
		var mesh := BoxTetraMesh4D.new()
		mesh.size = Vector4(cube_size, cube_size, cube_size, cube_size)
		cube.mesh = mesh
		cube.material_override = shared_material
		var pos: Vector4 = cluster_center + offset
		pos.y = cube_size * 0.5 # Rests on the ground (assumed at local y=0).
		cube.position = pos
		add_child(cube)
		cubes.append(cube)
