extends Node4D
## Showcase/diagnostic scene for the hash+brick voxel storage system
## (VoxelWorld4D + VoxelBrick4D + TerrainMeshBackendMT + TerrainChunkPool4D)
## - populates a real terrain-like heightfield across many bricks, paces
## brick creation across frames (so startup doesn't block a single frame),
## drives threaded regeneration every frame, keeps a chunk pool synced to
## the camera's position for distance culling, and reports live
## performance stats - see _update_perf_label().
##
## Controls (reusing the existing single-chunk demo's proven camera/rig
## scripts UNCHANGED): left-drag orbits the camera in ordinary 3D,
## right-drag rotates the terrain rig in the 4th dimension, scroll wheel
## zooms. WASD+QE (terrain4d_pan_controller.gd, a sibling of the camera)
## pans the orbit pivot around the world - use it to watch bricks stream
## in and out of TerrainChunkPool4D's render-distance culling live.

@export var noise_seed: int = 1
@export var noise_frequency: float = 0.06
@export var noise_amplitude: float = 6.0
@export var noise_persistence: float = 0.55
@export var ground_level: float = 0.0
@export var step_size: float = 0.75
## Brick coordinates populate from -radius..+radius on each axis -
## horizontal_brick_radius covers x/z, vertical_brick_radius covers y.
## Total brick count is
## (2*horizontal_brick_radius+1)^2 * (2*vertical_brick_radius+1) * (2*w_brick_radius+1)
## - this grows FAST in 4D; these are the dials to turn for a heavier
## stress test (watch the perf HUD's load/meshing timings and memory
## estimate as you raise them).
##
## Defaults kept small deliberately: brick CREATION/collapse-checking is
## still synchronous-only by design (only meshing was threaded this pass
## - see the plan doc). Density sampling now calls the native
## Math4D.noise_4d() binding (see _density() below), not the GDScript
## Noise4D.fractal_noise this used to call - measured ~53x faster per
## noise evaluation, but collapse-checking/apron-sampling are still
## synchronous, so total load time still scales roughly linearly with
## brick count, just with a much smaller constant now. Threading brick
## creation itself (not just meshing) would be the natural next lever if
## a much larger default population is wanted.
@export var horizontal_brick_radius: int = 3
@export var vertical_brick_radius: int = 1
## Kept separate (and small) from horizontal_brick_radius, and worth
## explaining why: the camera's "Cross-section" rendering only ever shows
## a thin W-slice of the scene at once (rotate the terrain rig with
## right-drag to look at a different slice) - populating a wide W range
## the same as x/z would mean MOST of that population is never visible
## at any single camera orientation, just wasted load time. A shallow W
## population keeps most of what gets loaded actually on screen.
@export var w_brick_radius: int = 1
@export var bricks_per_frame_during_load: int = 8
@export var max_render_distance: float = 40.0

@export var camera_path: NodePath
@export var perf_label_path: NodePath

## --- Click-to-edit (dig/place) ---
## Reuses the SAME two mouse buttons already bound to camera drag-orbit
## (left, terrain4d_orbit_camera.gd) and 4D slice drag-rotate (right,
## terrain4d_orbit_controller.gd) rather than inventing a third mouse
## convention: a CLICK (press+release with negligible movement) edits; a
## DRAG (press+move) still orbits/rotates exactly as before, since a
## plain click never generates the motion events those scripts' handlers
## react to - the two behaviors are naturally disjoint on the same
## buttons, not a new input axis layered on top. Left click = dig (carve
## air), right click = place (fill solid) - one tool, not two, per radius.
## Radius (small = single-voxel edits, large = area edits) is live-
## adjustable via [ and ] - the only unclaimed keys in this scene (scroll
## = zoom, WASD+QE = pan, left/right-drag = view/slice control).
@export var edit_radius: float = 1.0
@export var min_edit_radius: float = 0.2
@export var max_edit_radius: float = 6.0
@export var edit_radius_step: float = 0.2
@export var max_edit_ray_distance: float = 200.0
@export var dig_density: float = 5.0  ## positive = air
@export var place_density: float = -5.0  ## negative = solid

const CLICK_MAX_DRAG_PIXELS := 6.0
var _edit_press_screen_pos: Dictionary = {}  ## mouse button index -> Vector2

## --- Creature cubes (static placement only - no movement, no
## pathfinding, no boid behavior; that's deliberately the NEXT step, not
## this one) ---
## Same BoxTetraMesh4D + MeshInstance4D + TetraMaterial4D pattern already
## used everywhere else in this codebase for a simple placed object (e.g.
## project/target.tscn) - a bare Node4D with no physics body of its own,
## since these don't need to BE hit, only to raycast DOWN against the
## terrain's real collision. Placement uses the SAME broadphase raycast
## pattern proven for click-to-edit (_perform_edit below): PhysicsServer4D
## + RaycastParameters4D, deriving the hit point from global_distance since
## ConcaveMeshShape4D's own raycast never sets a "point" key.
@export var creature_count: int = 6
@export var creature_size: Vector4 = Vector4(0.6, 0.6, 0.6, 0.6)
@export var creature_color: Color = Color(0.9, 0.2, 0.6, 1.0)
@export var creature_spawn_height: float = 20.0  ## world Y the downward raycast starts from - safely above any terrain
@export var creature_max_ray_distance: float = 40.0

var _creatures_spawned := false
var _creatures: Array = []  ## spawned Node4D creature roots, for external diagnostics/tests

@onready var chunk_pool: TerrainChunkPool4D = $ChunkPool
@onready var camera: Camera4D = get_node(camera_path)
@onready var perf_label: Label = get_node(perf_label_path)
@onready var _rig: Node4D = get_parent()

var world: VoxelWorld4D

var _load_queue: Array = []
var _load_start_msec: int = 0
var _population_done_msec: int = -1
var _settled_msec: int = -1

var _stats_accum := 0.0
var _cached_heavy_stats := ""
const STATS_UPDATE_INTERVAL := 0.5

func _ready() -> void:
	world = VoxelWorld4D.new(Vector4.ZERO, Vector4(step_size, step_size, step_size, step_size), Callable(self, "_density"))
	chunk_pool.world = world
	chunk_pool.max_render_distance = max_render_distance
	_center_camera_on_populated_volume()
	_build_load_queue()
	_load_start_msec = Time.get_ticks_msec()

## VoxelBrick4D.nominal_bounds() for brick coord c spans
## [c*cell_size, (c+1)*cell_size) - so a symmetric coordinate range
## -R..R spans a world region centered at +0.5*cell_size, not exactly 0.
## Runs before OverheadCamera's own _ready() (Godot readies children
## before parents, and TerrainRig's whole subtree - including this node -
## comes before the OverheadCamera sibling in the scene tree), so setting
## look_at_target here is picked up by the camera's first _apply_orbit()
## call, no manual refresh() needed.
func _center_camera_on_populated_volume() -> void:
	var cell_size := (VoxelBrick4D.NOMINAL_POINTS_PER_AXIS - 1) * step_size
	var half_cell := 0.5 * cell_size
	camera.look_at_target = Vector4(half_cell, ground_level + half_cell, half_cell, half_cell)

## Pure heightfield - unlike the single-chunk demo's volumetric noise,
## this never samples at p.y, so no overhangs/caves - deliberately simple
## so collapse behavior (deep underground -> solid, high sky -> air) is
## easy to reason about for this diagnostic tool. No closing box needed
## either, unlike the old demo: there's no finite grid to cap here - each
## brick decides its own collapse state independently, however far out
## you populate.
##
## Uses Math4D.noise_4d() (engine/modules/4d/math/math_4d.cpp), the native
## OpenSimplexNoise prototype - not Noise4D.fractal_noise anymore. This is
## the real integration, not a side benchmark: profiling found the
## GDScript hand-rolled noise was the dominant cost in this whole
## pipeline (~51us/call), and the native binding measured ~53x faster per
## call. Same 3-octave/frequency/persistence-ladder structure as the old
## Noise4D.fractal_noise call it replaces (and the same "zero out p.y
## before scaling" heightfield convention), so this is a like-for-like
## swap of WHICH function computes the value, not a redesign of the
## height field's own shape - the actual terrain shape still changes
## (it's a different underlying noise algorithm), which is expected, not
## a bug.
func _density(p: Vector4) -> float:
	var total := 0.0
	var amplitude := 1.0
	var frequency := noise_frequency
	var max_value := 0.0
	for i in range(3):
		total += Math4D.noise_4d(noise_seed, p.x * frequency, 0.0, p.z * frequency, p.w * frequency) * amplitude
		max_value += amplitude
		amplitude *= noise_persistence
		frequency *= 2.0
	var height := ground_level + noise_amplitude * (total / max_value)
	return p.y - height

func _input(input_event: InputEvent) -> void:
	if input_event is InputEventMouseButton:
		_handle_edit_click(input_event)
	elif input_event is InputEventKey and input_event.pressed:
		if input_event.keycode == KEY_BRACKETRIGHT:
			edit_radius = clampf(edit_radius + edit_radius_step, min_edit_radius, max_edit_radius)
		elif input_event.keycode == KEY_BRACKETLEFT:
			edit_radius = clampf(edit_radius - edit_radius_step, min_edit_radius, max_edit_radius)

## Click-vs-drag disambiguation: records the press position, and on
## release only treats it as an edit if the cursor barely moved -
## otherwise this was a camera drag (orbit or 4D rotate), already fully
## handled by the sibling camera/rig scripts, and no edit should fire.
func _handle_edit_click(input_event: InputEventMouseButton) -> void:
	if input_event.button_index != MOUSE_BUTTON_LEFT and input_event.button_index != MOUSE_BUTTON_RIGHT:
		return
	if input_event.pressed:
		_edit_press_screen_pos[input_event.button_index] = input_event.position
		return
	if not _edit_press_screen_pos.has(input_event.button_index):
		return
	var press_pos: Vector2 = _edit_press_screen_pos[input_event.button_index]
	_edit_press_screen_pos.erase(input_event.button_index)
	if press_pos.distance_to(input_event.position) > CLICK_MAX_DRAG_PIXELS:
		return
	_perform_edit(input_event.position, input_event.button_index == MOUSE_BUTTON_LEFT)

## Broadphase raycast against the whole 4D physics world (PhysicsServer4D,
## the same pattern player.gd's own test raycast uses) rather than one
## known StaticBody4D's shape (terrain4d_voxel_hover.gd's pattern) - this
## scene has many separate pooled brick bodies, not one terrain body, so
## the broadphase query is the only one that doesn't need to already know
## which brick is under the cursor.
func _perform_edit(screen_pos: Vector2, is_dig: bool) -> void:
	var ray_params := RaycastParameters4D.new()
	ray_params.global_ray_origin = camera.viewport_to_world_ray_origin(screen_pos)
	ray_params.global_ray_direction = camera.viewport_to_world_ray_direction(screen_pos).normalized()
	ray_params.max_distance = max_edit_ray_distance
	var result: Dictionary = PhysicsServer4D.raycast_physics_objects(ray_params)
	if not result.get("hit", false):
		return
	# ConcaveMeshShape4D's own raycast_intersects() never sets a "point" key
	# (only hit/distance/normal/cell_index - confirmed in
	# concave_mesh_shape_4d.cpp), so PhysicsServer4D's wrapper never adds
	# global_point either (it's conditional on the shape providing "point").
	# global_distance IS always set on a hit, so derive the point from that
	# instead of assuming global_point exists.
	var world_point: Vector4 = ray_params.global_ray_origin + ray_params.global_ray_direction * float(result.global_distance)
	# Same un-rotated-generation-space conversion _process() already does
	# for viewer_position, for the same underlying reason (the rig applies
	# the 4D right-drag rotation on top of the world's own storage space).
	var inverse_basis: Projection = _rig.global_basis.inverse()
	var local_point: Vector4 = inverse_basis * (world_point - _rig.global_position)
	var new_density := dig_density if is_dig else place_density
	# sync=false: mark dirty and return immediately, same non-blocking
	# path process_regeneration_async() (already driven every frame below)
	# is meant to pick up - an edit should never stall a frame.
	world.edit_sphere(local_point, edit_radius, func(_old_d: float, _dist: float) -> float: return new_density, false)

## Called once, right when population+meshing first settles. Picks
## creature_count random (x,z,w) points within the populated footprint (in
## the SAME un-rotated generation/local space bricks live in), raycasts
## straight down against the terrain's REAL ConcaveMeshShape4D collision
## (same PhysicsServer4D broadphase pattern as _perform_edit above) to find
## actual ground height, and places a small BoxTetraMesh4D there. The
## downward ray is built in WORLD space (physics is always global) via the
## rig's current transform, then the hit point is converted back to local
## space before being assigned as the creature's own position - the exact
## same round-trip _perform_edit already does, and for the same reason:
## right-drag 4D rotation (Basis4D.from_xw/from_zw) only ever mixes the
## X/W and Z/W axes, never Y, so "straight down" in world space is always
## correct regardless of the rig's current orientation.
func _spawn_creatures() -> void:
	var cell_size := (VoxelBrick4D.NOMINAL_POINTS_PER_AXIS - 1) * step_size
	var horizontal_span := (2 * horizontal_brick_radius + 1) * cell_size
	var w_span := (2 * w_brick_radius + 1) * cell_size
	var horizontal_min := -horizontal_brick_radius * cell_size
	var w_min := -w_brick_radius * cell_size
	var wander_min := Vector4(horizontal_min, 0.0, horizontal_min, w_min)
	var wander_max := Vector4(horizontal_min + horizontal_span, 0.0, horizontal_min + horizontal_span, w_min + w_span)
	var spawned := 0
	for i in range(creature_count):
		var local_x: float = horizontal_min + randf() * horizontal_span
		var local_z: float = horizontal_min + randf() * horizontal_span
		var local_w: float = w_min + randf() * w_span
		var ground_local: Variant = _raycast_ground_local(local_x, local_z, local_w)
		if ground_local == null:
			continue
		_add_creature_at(ground_local, wander_min, wander_max)
		spawned += 1
	print("Spawned %d/%d creature cube(s) on the terrain." % [spawned, creature_count])

## Returns the LOCAL (rig-space) ground position at (local_x, *, local_z,
## local_w), or null if the downward ray found no terrain there.
func _raycast_ground_local(local_x: float, local_z: float, local_w: float) -> Variant:
	var rig_basis: Projection = _rig.global_basis
	var local_origin := Vector4(local_x, creature_spawn_height, local_z, local_w)
	var ray_params := RaycastParameters4D.new()
	ray_params.global_ray_origin = _rig.global_position + rig_basis * local_origin
	ray_params.global_ray_direction = Vector4(0.0, -1.0, 0.0, 0.0)
	ray_params.max_distance = creature_max_ray_distance
	var result: Dictionary = PhysicsServer4D.raycast_physics_objects(ray_params)
	if not result.get("hit", false):
		return null
	var world_point: Vector4 = ray_params.global_ray_origin + ray_params.global_ray_direction * float(result.global_distance)
	var inverse_basis: Projection = rig_basis.inverse()
	return inverse_basis * (world_point - _rig.global_position)

const _CREATURE_SCRIPT := preload("res://sandbox/terrain4d/terrain4d_creature_4d.gd")

## Same BoxTetraMesh4D + MeshInstance4D + TetraMaterial4D pattern already
## used everywhere else in this codebase (e.g. project/target.tscn) - a
## bare Node4D, no physics body of its own. Positioned so the box SITS ON
## the ground point (its bottom face touching it), not centered through it -
## a BoxTetraMesh4D is centered on its own origin, so the creature's own
## position needs to be the ground point raised by half the box's own
## height. TerrainCreature4D (basic wander + continuous ground-tracking,
## no pathfinding/boids yet) is attached here and given the exact wander
## bounds computed from the populated footprint, so it never wanders into
## ungenerated space.
func _add_creature_at(ground_local: Vector4, wander_min: Vector4, wander_max: Vector4) -> void:
	var creature := Node4D.new()
	creature.set_script(_CREATURE_SCRIPT)
	creature.position = ground_local + Vector4(0.0, creature_size.y * 0.5, 0.0, 0.0)
	creature.half_height = creature_size.y * 0.5
	creature.wander_min = wander_min
	creature.wander_max = wander_max
	var mesh_instance := MeshInstance4D.new()
	var box_mesh := BoxTetraMesh4D.new()
	box_mesh.size = creature_size
	mesh_instance.mesh = box_mesh
	var material := TetraMaterial4D.new()
	material.albedo_color = creature_color
	mesh_instance.material_override = material
	creature.add_child(mesh_instance)
	add_child(creature)
	_creatures.append(creature)

func _build_load_queue() -> void:
	_load_queue.clear()
	for bx in range(-horizontal_brick_radius, horizontal_brick_radius + 1):
		for by in range(-vertical_brick_radius, vertical_brick_radius + 1):
			for bz in range(-horizontal_brick_radius, horizontal_brick_radius + 1):
				for bw in range(-w_brick_radius, w_brick_radius + 1):
					_load_queue.append(Vector4i(bx, by, bz, bw))

func _process(delta: float) -> void:
	if _population_done_msec < 0:
		var n := mini(bricks_per_frame_during_load, _load_queue.size())
		for i in range(n):
			world.get_or_create_brick(_load_queue.pop_back())
		if _load_queue.is_empty():
			_population_done_msec = Time.get_ticks_msec()

	world.process_regeneration_async()

	if _population_done_msec >= 0 and _settled_msec < 0 and not world.has_pending_regen_tasks():
		_settled_msec = Time.get_ticks_msec()

	if _settled_msec >= 0 and not _creatures_spawned:
		_creatures_spawned = true
		_spawn_creatures()

	# Bricks live in un-rotated GENERATION space; this node's own PARENT
	# (the rig) applies the 4D right-drag rotation for display on top of
	# that - so the camera's world-space position has to be converted into
	# the rig's local space before comparing it against brick bounds,
	# exactly like terrain4d_voxel_hover.gd's raycast conversion does, for
	# the same underlying reason (both need a world-space quantity
	# expressed in the terrain's own un-rotated space).
	var inverse_basis: Projection = _rig.global_basis.inverse()
	chunk_pool.viewer_position = inverse_basis * (camera.global_position - _rig.global_position)
	# Slice-intersection culling inputs (see TerrainChunkPool4D.slice_w_dir_local's
	# own comment for the derivation) - reuses the exact ana_offset formula
	# already established in bearing_utility_4d.gd (rel.dot(observer_basis.w)),
	# generalized from a point target to a brick's whole AABB. Measured
	# directly before this was added: 141 of 213 visible bricks (66.2%)
	# never straddled the slice, submitting the large majority of tets to
	# the vertex shader for zero rendered result every frame.
	chunk_pool.slice_w_dir_local = inverse_basis * camera.global_basis.w
	chunk_pool.slice_base_offset = (_rig.global_position - camera.global_position).dot(camera.global_basis.w)
	chunk_pool.update()

	_update_perf_label(delta)

func _update_perf_label(delta: float) -> void:
	var lines := []
	lines.append("FPS: %d" % [Engine.get_frames_per_second()])
	lines.append("Edit radius: %.2f  (LMB=dig, RMB=place, [ / ] to resize)" % [edit_radius])
	if _population_done_msec < 0:
		lines.append("Loading bricks: %d remaining..." % [_load_queue.size()])
	else:
		lines.append("Population time: %d ms" % [_population_done_msec - _load_start_msec])
		if _settled_msec >= 0:
			lines.append("Meshing catch-up: %d ms" % [_settled_msec - _population_done_msec])
		else:
			lines.append("Meshing catch-up: in progress...")

	_stats_accum += delta
	if _stats_accum >= STATS_UPDATE_INTERVAL or _cached_heavy_stats.is_empty():
		_stats_accum = 0.0
		_cached_heavy_stats = _compute_heavy_stats()
	lines.append(_cached_heavy_stats)

	perf_label.text = "\n".join(lines)

## Throttled to STATS_UPDATE_INTERVAL rather than every frame - this is a
## linear scan over every resident brick (thousands at the default
## settings), cheap in absolute terms but no reason to pay it 60x/sec for
## a number that only needs to look "live", not instantaneous.
func _compute_heavy_stats() -> String:
	var total := 0
	var collapsed := 0
	var density_bytes := 0
	for brick in world.get_all_bricks():
		total += 1
		if brick.is_collapsed:
			collapsed += 1
		else:
			density_bytes += brick.density.size()
	var dense := total - collapsed
	var collapse_rate := (float(collapsed) / float(total) * 100.0) if total > 0 else 0.0

	var visible_tets := 0
	for brick in chunk_pool.visible_bricks():
		if brick.cached_mesh != null:
			visible_tets += brick.cached_mesh.get_simplex_cell_vertex_indices().size() / 4

	return (
		"Resident bricks: %d  (collapsed %d [%.1f%%], dense %d)\n" +
		"Dense brick density memory: %.2f MB\n" +
		"Visible bricks: %d  |  pooled nodes: %d  |  visible tets: %d\n" +
		"Regen jobs in flight/queued: %d  |  CPU cores available: %d"
	) % [
		total, collapsed, collapse_rate, dense,
		density_bytes / (1024.0 * 1024.0),
		chunk_pool.visible_brick_count(), chunk_pool.pooled_node_count(), visible_tets,
		world.pending_regen_task_count(), OS.get_processor_count(),
	]
