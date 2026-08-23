extends Node
## Shrubbery-lab key bindings for live parameter tweaking - a dedicated
## controller/scene, deliberately not reusing motion_lab_controller.gd's
## bindings or scene (this is for testing the shrub generation algorithm
## itself, not the creature/gait system). Avoids every key already
## claimed by player.gd's own movement/action bindings (W/A/S/D move,
## Q/E kata/ana, Space jump, mouse fire/rotate_4d, F catch_target,
## R reload/reset_capture, T toggle_stopwatch/draw_area - see
## project.godot's own [input] section) so free-roam movement still
## works normally alongside these.

@export var lab_path: NodePath
@export var hint_label_path: NodePath
@export var info_label_path: NodePath

@onready var lab: Node4D = get_node(lab_path)
@onready var hint_label: Label = get_node(hint_label_path) if not hint_label_path.is_empty() else null
@onready var info_label: Label = get_node(info_label_path) if not info_label_path.is_empty() else null

var _base_info_text: String = ""

const ITERATIONS_STEP := 2
const ATTRACTOR_COUNT_STEP := 20
const LEAF_RADIUS_STEP := 0.02
const VOXEL_SIZE_STEP := 0.01
const MIN_VOXEL_SIZE := 0.02


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
	var species: ShrubSpecies4D = lab.species
	match key_event.keycode:
		KEY_G:
			lab.randomize_seed()
		KEY_P:
			lab.regenerate()
		KEY_U:
			species.iterations = maxi(1, species.iterations - ITERATIONS_STEP)
			lab.regenerate()
		KEY_I:
			species.iterations += ITERATIONS_STEP
			lab.regenerate()
		KEY_J:
			species.attractor_count = maxi(1, species.attractor_count - ATTRACTOR_COUNT_STEP)
			lab.regenerate()
		KEY_K:
			species.attractor_count += ATTRACTOR_COUNT_STEP
			lab.regenerate()
		KEY_N:
			species.leaf_radius = maxf(0.0, species.leaf_radius - LEAF_RADIUS_STEP)
			lab.regenerate()
		KEY_M:
			species.leaf_radius += LEAF_RADIUS_STEP
			lab.regenerate()
		KEY_H:
			species.voxel_size = maxf(MIN_VOXEL_SIZE, species.voxel_size - VOXEL_SIZE_STEP)
			lab.regenerate()
		KEY_Y:
			species.voxel_size += VOXEL_SIZE_STEP
			lab.regenerate()
		KEY_B:
			lab.use_blocky_builder = not lab.use_blocky_builder
			lab.regenerate()
		_:
			return
	_update_label()


func _update_label() -> void:
	if hint_label == null:
		return
	var species: ShrubSpecies4D = lab.species
	var builder_name: String = "blocky" if lab.use_blocky_builder else "smooth(MT, SLOW)"
	hint_label.text = "Seed: %d (G=new seed, P=replay)   Iterations: %d (U/I)   Attractors: %d (J/K)   Leaf radius: %.2f (N/M)   Voxel size: %.2f (H/Y)   Builder: %s (B)\nLast build: voxels=%d tets=%d elapsed=%.3fs" % [
		species.seed, species.iterations, species.attractor_count, species.leaf_radius, species.voxel_size, builder_name,
		lab.last_voxel_count, lab.last_tet_count, lab.last_elapsed_sec,
	]
