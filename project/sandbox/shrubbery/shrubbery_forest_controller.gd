extends Node
## Forest-lab key bindings - the same per-species controls as
## shrubbery_lab_controller.gd (this is deliberately the SAME control
## scheme, not a divergent one, so switching between the single-tree lab
## and the forest scene doesn't require relearning bindings), plus two
## additional controls for tree_count and crown_shyness_voxels. Avoids
## every key already claimed by player.gd's own movement/action bindings
## (see shrubbery_lab_controller.gd's own header for the exact list).

@export var forest_path: NodePath
@export var hint_label_path: NodePath
@export var info_label_path: NodePath

@onready var forest: Node4D = get_node(forest_path)
@onready var hint_label: Label = get_node(hint_label_path) if not hint_label_path.is_empty() else null
@onready var info_label: Label = get_node(info_label_path) if not info_label_path.is_empty() else null

var _base_info_text: String = ""

const ITERATIONS_STEP := 2
const ATTRACTOR_COUNT_STEP := 20
const LEAF_RADIUS_STEP := 0.02
const VOXEL_SIZE_STEP := 0.01
const MIN_VOXEL_SIZE := 0.02
const TREE_COUNT_STEP := 5
const MIN_TREE_COUNT := 1


func _ready() -> void:
	if info_label != null:
		_base_info_text = info_label.text
	_update_label()


func _process(_delta: float) -> void:
	if info_label != null:
		info_label.text = "%s | FPS: %d" % [_base_info_text, Engine.get_frames_per_second()]


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	var key_event: InputEventKey = event
	var species: ShrubSpecies4D = forest.species_template
	match key_event.keycode:
		KEY_G:
			forest.randomize_seed()
		KEY_P:
			forest.regenerate()
		KEY_U:
			species.iterations = maxi(1, species.iterations - ITERATIONS_STEP)
			forest.regenerate()
		KEY_I:
			species.iterations += ITERATIONS_STEP
			forest.regenerate()
		KEY_J:
			species.attractor_count = maxi(1, species.attractor_count - ATTRACTOR_COUNT_STEP)
			forest.regenerate()
		KEY_K:
			species.attractor_count += ATTRACTOR_COUNT_STEP
			forest.regenerate()
		KEY_N:
			species.leaf_radius = maxf(0.0, species.leaf_radius - LEAF_RADIUS_STEP)
			forest.regenerate()
		KEY_M:
			species.leaf_radius += LEAF_RADIUS_STEP
			forest.regenerate()
		KEY_H:
			species.voxel_size = maxf(MIN_VOXEL_SIZE, species.voxel_size - VOXEL_SIZE_STEP)
			forest.regenerate()
		KEY_Y:
			species.voxel_size += VOXEL_SIZE_STEP
			forest.regenerate()
		KEY_B:
			forest.use_blocky_builder = not forest.use_blocky_builder
			forest.regenerate()
		KEY_C:
			forest.tree_count = maxi(MIN_TREE_COUNT, forest.tree_count - TREE_COUNT_STEP)
			forest.regenerate()
		KEY_V:
			forest.tree_count += TREE_COUNT_STEP
			forest.regenerate()
		KEY_X:
			forest.crown_shyness_voxels = maxi(0, forest.crown_shyness_voxels - 1)
			forest.regenerate()
		KEY_Z:
			forest.crown_shyness_voxels += 1
			forest.regenerate()
		_:
			return
	_update_label()


func _update_label() -> void:
	if hint_label == null:
		return
	var species: ShrubSpecies4D = forest.species_template
	var builder_name: String = "blocky" if forest.use_blocky_builder else "smooth(MT, SLOW)"
	hint_label.text = "Forest seed: %d (G=new, P=replay)   Trees: %d (C/V)   Crown shyness (voxels): %d (X/Z)   Builder: %s (B)\nIterations: %d (U/I)   Attractors: %d (J/K)   Leaf radius: %.2f (N/M)   Voxel size: %.2f (H/Y)\nLast build: total_voxels=%d total_tets=%d elapsed=%.2fs" % [
		forest.forest_seed, forest.tree_count, forest.crown_shyness_voxels, builder_name,
		species.iterations, species.attractor_count, species.leaf_radius, species.voxel_size,
		forest.last_voxel_count, forest.last_tet_count, forest.last_elapsed_sec,
	]
