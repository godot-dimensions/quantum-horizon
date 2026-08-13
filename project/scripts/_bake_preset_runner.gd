extends Node
## Bakes ONE named preset to disk (plus a documentation screenshot), then
## quits - see _apply_preset() for what each name configures. Run via
## _bake_preset.tscn with `preset_name` exported to pick which one. Not
## part of the shipped scene - an overnight batch-baking tool.
##
## Every preset shares the SAME generation budget (BRICK_CORE_CELLS=16,
## radius_grid=20, grid_size=48) - the combination already measured to
## complete reliably in ~2 minutes without the memory blowup a much bigger
## BRICK_CORE_CELLS hit earlier. Pushing any one preset further tonight
## would trade a guaranteed set of finished bakes for a chance at a bigger
## one that might crash partway and leave nothing - not the right trade for
## an unattended overnight run.

@onready var terrain: Node4D = $VoxelPort/Terrain
@onready var camera: Camera4D = $VoxelPort/HoverCamera

@export var preset_name: String = "rolling_hills"
@export var bake_path: String = "" # auto-derived from preset_name if empty

const PROGRESS_INTERVAL_SECONDS := 15.0


func _apply_preset(preset: String) -> void:
	terrain.BRICK_CORE_CELLS = 16
	terrain.cell_size = 1.0
	terrain.grid_size = 48
	terrain.max_render_distance = 20.0
	terrain.terrain_seed = 1
	terrain.flip_winding = false

	match preset:
		"rolling_hills":
			# Gentle: low frequency, low amplitude, a smoothing power well
			# above 1 to flatten mid-range variation into wide basins/domes
			# instead of the original default's spiky look, plus a shallow
			# seafloor so there is no deep "empty ocean" volume below the
			# waterline.
			# Same corner-gap issue as arch (see that case's comment): at the
			# shared default radius of 20, diagonal-neighbour bricks
			# (~22.6 units from center) get silently excluded, notching the
			# corners out of what should be one continuous flat sheet.
			terrain.max_render_distance = 25.0
			terrain.model_layers = terrain.MODEL_PLANE | terrain.MODEL_PLANE_WATER | terrain.MODEL_SEAFLOOR | terrain.MODEL_CUTOFF
			terrain.terrain_shape = terrain.TerrainShape.PLANAR
			terrain.noise_frequency = 0.05
			terrain.fractal_octaves = 3
			terrain.fractal_gain = 0.4
			terrain.noise_amplitude_fraction = 0.08
			terrain.noise_smoothing_power = 1.8
			terrain.detail_noise_enabled = true
			terrain.detail_noise_frequency_multiplier = 5.0
			terrain.detail_noise_amplitude_fraction = 0.15
			terrain.cellular_noise_enabled = false
			terrain.max_depth_below_water = 4.0

		"cracked_archipelago":
			# Cellular/Voronoi noise on its own (no smoothing, no detail
			# layer) - its sharp cell boundaries read as a cracked,
			# geometric island pattern once water floods the low cells,
			# nothing like the continuous rolling-hills look.
			# Same corner-gap issue as arch/rolling_hills - see that case's
			# comment.
			terrain.max_render_distance = 25.0
			terrain.model_layers = terrain.MODEL_PLANE | terrain.MODEL_PLANE_WATER | terrain.MODEL_SEAFLOOR | terrain.MODEL_CUTOFF
			terrain.terrain_shape = terrain.TerrainShape.PLANAR
			terrain.noise_frequency = 0.06
			terrain.fractal_octaves = 2
			terrain.fractal_gain = 0.4
			terrain.noise_amplitude_fraction = 0.1
			terrain.noise_smoothing_power = 1.0
			terrain.detail_noise_enabled = false
			terrain.cellular_noise_enabled = true
			terrain.cellular_noise_frequency = 0.15
			terrain.cellular_noise_amplitude_fraction = 0.35
			terrain.max_depth_below_water = 5.0

		"arch":
			# Rolling-hills-style base terrain (so it is not just bare
			# flat ground) plus the 4D arch: rises through y, sweeps
			# through w and back on the way up, lands again elsewhere.
			# Candidate bricks are chosen by EUCLIDEAN distance from the
			# streaming origin to each brick's center - at radius 20 (the
			# shared default above), a single-axis-offset brick sits exactly
			# 16 units out (inside 20) but a diagonal two-axis-offset corner
			# brick sits sqrt(16^2+16^2)=~22.6 units out (outside 20), so the
			# corners of what should be one continuous flat sheet get silently
			# skipped - a "plus" shape instead of a filled square. 25 clears
			# the two-axis diagonal with margin.
			terrain.max_render_distance = 25.0
			terrain.model_layers = terrain.MODEL_PLANE | terrain.MODEL_PLANE_WATER | terrain.MODEL_SEAFLOOR | terrain.MODEL_ARCH | terrain.MODEL_CUTOFF
			terrain.terrain_shape = terrain.TerrainShape.PLANAR
			terrain.noise_frequency = 0.05
			terrain.fractal_octaves = 3
			terrain.fractal_gain = 0.4
			terrain.noise_amplitude_fraction = 0.06
			terrain.noise_smoothing_power = 1.8
			terrain.detail_noise_enabled = true
			terrain.detail_noise_frequency_multiplier = 5.0
			terrain.detail_noise_amplitude_fraction = 0.12
			terrain.cellular_noise_enabled = false
			terrain.max_depth_below_water = 4.0
			terrain.arch_start_fraction = 0.2
			terrain.arch_end_fraction = 0.8
			terrain.arch_height = 14.0
			terrain.arch_w_amplitude = 10.0
			terrain.arch_radius = 2.0

		"ocean_globe":
			# The project's own original default model (a spherical ocean
			# planet), carried forward with the SAME noise-smoothing and
			# colour fixes as the other presets, to show those fixes
			# clearly apply to the radial/globe case too, not just planar
			# ones.
			# Candidate bricks are chosen by distance from the streaming
			# origin to each brick's CENTER, not by whether the brick's own
			# CORE extent reaches the surface - harmless for a flat terrain
			# (only clips unused corners far from the interesting content),
			# but this sphere's own radius (~16.8 grid units, plus noise) is
			# close enough to the shared default radius (20) that the same
			# filtering clips pieces of the VISIBLE SURFACE itself: a brick
			# whose CENTER lands just past the radius gets skipped even when
			# its CORE still overlaps the sphere, leaving a gap with no
			# neighbour to connect smoothly to - this is what "hollow,
			# gap-toothed sphere with a disconnected floating fragment" was.
			# Confirmed by isolation testing at radius 25 (clean, no gaps).
			terrain.max_render_distance = 25.0
			terrain.model_layers = terrain.MODEL_GLOBE_WATER | terrain.MODEL_GLOBE | terrain.MODEL_CUTOFF
			terrain.terrain_shape = terrain.TerrainShape.RADIAL
			terrain.noise_frequency = 0.1
			terrain.fractal_octaves = 3
			terrain.fractal_gain = 0.45
			terrain.noise_amplitude_fraction = 0.1
			terrain.noise_smoothing_power = 1.6
			terrain.detail_noise_enabled = true
			terrain.detail_noise_frequency_multiplier = 4.0
			terrain.detail_noise_amplitude_fraction = 0.2
			terrain.cellular_noise_enabled = false

		_:
			push_error("VoxelTerrain4D bake preset: unknown preset '%s'" % preset)


func _screenshot(image_name: String) -> void:
	for i in range(10):
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://smoke_test_output/" + image_name)


func _ready() -> void:
	await get_tree().process_frame
	_apply_preset(preset_name)
	var path: String = bake_path
	if path.is_empty():
		path = "user://voxel_bake_%s.bin" % preset_name

	print("=== baking preset '%s' to %s ===" % [preset_name, path])
	# The camera sits wherever voxel_port.tscn's own defaults left it
	# (unrelated to the region this bake actually populates) for the WHOLE
	# generate-and-wait phase below, since nothing here moves it until the
	# screenshot step. Without this, bricks near the eviction boundary from
	# THAT camera's perspective cycle generate -> evict -> re-request ->
	# generate forever and never converge - measured directly tonight: a
	# bake that stalled at 4/8 bricks for over 30 minutes before the
	# sustained instance churn crashed the renderer outright. See
	# suppress_eviction's own comment.
	terrain.suppress_eviction = true
	var start_usec: int = Time.get_ticks_usec()
	terrain.generate()

	var elapsed := 0.0
	var min_fps := INF
	var previous_generated_count := -1
	while true:
		await get_tree().create_timer(PROGRESS_INTERVAL_SECONDS).timeout
		elapsed += PROGRESS_INTERVAL_SECONDS
		var fps: float = Engine.get_frames_per_second()
		min_fps = minf(min_fps, fps)
		var in_flight: int = terrain._bricks_in_flight.size() + terrain._pending_brick_tasks.size()
		print("t=%.0fs fps=%.1f bricks_done=%d in_flight=%d tets=%d" % [
			elapsed, fps, terrain._generated_bricks.size(), in_flight, terrain._total_tet_count,
		])
		# See this project's own notes on generate()'s one-shot request pass -
		# re-issuing the same request against world center every interval
		# guarantees every candidate within radius eventually gets tried,
		# regardless of how the WorkerThreadPool queue happened to be
		# occupied at the exact moment generate() itself ran.
		terrain._stream_bricks_in_radius(Vector4.ZERO, terrain.max_render_distance, terrain._nominal_center)
		var generated_count: int = terrain._generated_bricks.size()
		if in_flight == 0 and generated_count == previous_generated_count:
			break
		previous_generated_count = generated_count

	var total_ms: float = (Time.get_ticks_usec() - start_usec) / 1000.0
	print("=== '%s' generation caught up after %.1fs (%.0f ms), min_fps_observed=%.1f, bricks=%d tets=%d ===" % [
		preset_name, elapsed, total_ms, min_fps, terrain._generated_bricks.size(), terrain._total_tet_count,
	])

	# Documentation screenshot - boost max_render_distance far past
	# camera.radius + world half-extent purely for this shot (see this
	# project's own notes on why the distance sum, not camera.radius alone,
	# is what has to clear it) so everything already generated is visible
	# regardless of camera angle. This never affects what gets baked -
	# bake_to_file() below serializes whatever generate() already produced,
	# independent of the visibility settings at screenshot time.
	var is_radial: bool = terrain.terrain_shape == terrain.TerrainShape.RADIAL
	var plane_height_world: float = float(terrain.grid_size) * 0.5 * terrain.cell_size
	camera.look_at_target = Vector4.ZERO if is_radial else Vector4(0, plane_height_world, 0, 0)
	camera.radius = 30.0
	camera._elevation = deg_to_rad(35.0)
	terrain.max_render_distance = 90.0
	terrain._update_chunk_visibility()
	camera._apply_orbit()
	await _screenshot("bake_%s.png" % preset_name)
	terrain.max_render_distance = 20.0 # Restore, in case anything downstream reads it.

	terrain.bake_to_file(path)
	var bytes: int = FileAccess.get_file_as_bytes(path).size()
	print("=== baked '%s' to %s (%.1f MB) ===" % [preset_name, path, bytes / (1024.0 * 1024.0)])

	get_tree().quit()
