extends Node
## Loads a pre-baked world (see _bake_high_res_runner.gd/bake_to_file) and
## hands full interactive control to the player - orbit/pan/zoom/4D-rotate on
## the hover camera, click-to-edit sphere add/remove, all exactly as they
## work in the normal voxel_port.tscn scene. The only thing this script does
## beyond that scene's own defaults is load the cache instead of generating
## from scratch, and rescale the camera to actually fit the (likely much
## smaller/higher-resolution) baked world instead of the default ~50m-scale
## orbit distance. Not part of the shipped scene - a benchmarking/preview
## tool for a specific baked file.

@onready var terrain: Node4D = $VoxelPort/Terrain
@onready var camera: Camera4D = $VoxelPort/HoverCamera

@export var bake_path: String = "user://voxel_bake_10cm_safe.bin"

## Set by terrain_demo_menu.gd before adding this scene to the tree, so Esc
## can return there instead of just quitting - a no-op (Esc does nothing)
## when this scene is run standalone, e.g. via _bake_*.tscn's own preview.
var return_to_menu_scene: String = "res://scripts/terrain_demo_menu.tscn"


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if not return_to_menu_scene.is_empty() and ResourceLoader.exists(return_to_menu_scene):
			get_tree().change_scene_to_file(return_to_menu_scene)


func _apply_baked_generation_params(data: Dictionary) -> void:
	terrain.BRICK_CORE_CELLS = int(data["brick_core_cells"])
	terrain.cell_size = float(data["cell_size"])
	terrain.grid_size = int(data["nominal_size"])
	terrain.model_layers = int(data["model_layers"])
	terrain.terrain_seed = int(data["terrain_seed"])
	terrain.noise_frequency = float(data["noise_frequency"])
	terrain.fractal_octaves = int(data["fractal_octaves"])
	terrain.fractal_gain = float(data["fractal_gain"])
	terrain.noise_amplitude_fraction = float(data["noise_amplitude_fraction"])
	terrain.flip_winding = bool(data["flip_winding"])
	terrain.terrain_shape = int(data["terrain_shape"])


func _ready() -> void:
	await get_tree().process_frame
	if not FileAccess.file_exists(bake_path):
		print("=== interactive: no bake found at %s ===" % bake_path)
		return

	var file := FileAccess.open(bake_path, FileAccess.READ)
	var data: Dictionary = file.get_var()
	file.close()
	_apply_baked_generation_params(data)

	var baked_radius: float = 0.0
	for entry in data["bricks"].values():
		if entry.has("max"):
			baked_radius = maxf(baked_radius, (entry["max"] as Vector4).length())

	var load_start_usec: int = Time.get_ticks_usec()
	var ok: bool = terrain.load_from_file(bake_path)
	var load_ms: float = (Time.get_ticks_usec() - load_start_usec) / 1000.0
	if not ok:
		print("=== interactive: load_from_file failed ===")
		return

	# This scene's whole point is instant interaction with EXACTLY what got
	# baked - without this, a camera radius wider than the bake's own
	# max_render_distance (see below) silently triggers full live generation
	# for everything beyond it, paying the noise+layer cost per brick (up to
	# several seconds each) instead of the ~40ms this load just took.
	terrain.freeze_streaming = true
	# edit_sphere() discards+re-requests bricks unconditionally, ignoring
	# freeze_streaming - a misclick during a fast orbit drag was enough to
	# trigger a live regeneration pass and hang the app. Off here until
	# editing gets its own real fix; re-enable per-scene once it does.
	camera.enable_editing = false
	camera.look_at_target = Vector4.ZERO
	camera.radius = baked_radius * 1.8
	camera.min_radius = baked_radius * 0.05
	camera.max_radius = baked_radius * 20.0
	camera.edit_radius = baked_radius * 0.15
	camera._apply_orbit()

	print("=== interactive session ready: loaded %d bricks / %d tets in %.1f ms ===" % [
		terrain._generated_bricks.size(), terrain._total_tet_count, load_ms,
	])
	print("=== cell_size=%.3f (%.0fcm/voxel), baked radius ~%.2fm, camera radius %.2fm, edit_radius %.2fm ===" % [
		terrain.cell_size, terrain.cell_size * 100.0, baked_radius, camera.radius, camera.edit_radius,
	])
	print("=== controls: left-drag orbit, right-drag 4D rotate, scroll zoom, WASD+QE pan, Esc back to menu (editing disabled for now) ===")
