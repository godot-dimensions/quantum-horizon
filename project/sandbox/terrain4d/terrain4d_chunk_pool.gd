class_name TerrainChunkPool4D
extends Node4D
## Pooled render/collision nodes for VoxelWorld4D bricks - one StaticBody4D
## (Mesh + Collision children) per currently-visible, non-collapsed brick,
## re-synced only when that brick's cached mesh/collision actually changed
## since this pool last displayed it, never rebuilt every frame. Chunk-
## level culling falls out of this directly: a brick outside
## `max_render_distance` of `viewer_position` simply never gets a pooled
## node bound to it, and one that leaves range gets its node released back
## to the pool for reuse rather than freed.
##
## Assumes this node's own transform is identity (world_origin/step's
## coordinate space IS the scene's world space) - VoxelWorld4D and
## VoxelBrick4D never apply any local/world conversion of their own, so a
## non-identity transform here would double-offset every brick.
##
## Frustum culling is NOT implemented in this pass (distance alone is the
## primary lever called for in the plan's Rendering section, and is enough
## to prove the pooling mechanism end to end) - a real fast-follow if
## render distance needs to grow much further than distance culling alone
## can comfortably afford.

@export var max_render_distance: float = 30.0

var world: VoxelWorld4D
var viewer_position: Vector4 = Vector4.ZERO

## Slice-intersection culling inputs, set every frame by the caller
## alongside viewer_position (see terrain4d_voxel_showcase.gd's _process) -
## a brick whose local nominal AABB does not straddle the camera's current
## 4D cross-section plane contributes ZERO geometry every frame (a tet only
## emits a cross-section triangle when its corners disagree in sign
## relative to the slice - see CROSS_SECTION_LOOKUP in
## tetra_cross_section_shader.glsl), so it costs nothing to skip binding a
## render/collision node for it at all. Measured directly on the live
## showcase before this was added: 141 of 213 visible bricks (66.2%) never
## straddled the slice, submitting a large majority of tets to the vertex
## shader for zero rendered result every frame.
##
## Reuses the SAME ana_offset formula already established in
## bearing_utility_4d.gd (ana_offset = rel.dot(observer_basis.w), zero
## exactly on the slice) generalized from a point target to a brick's
## whole local AABB via the standard rotated-box support-point trick:
## slice_w_dir_local is the camera's own W-basis-direction expressed in the
## rig's local/generation space (inverse_basis * camera.global_basis.w -
## the same world-to-rig-local conversion viewer_position already uses,
## just applied to a direction instead of a position), and
## slice_base_offset is the constant term
## (rig.global_position - camera.global_position).dot(camera.global_basis.w)
## shared by every brick's projection. Defaults to "always straddles" (zero
## direction vector, i.e. every projection collapses to base_offset=0) so a
## caller that never sets these (e.g. an old test scene) gets unchanged
## behavior rather than silently culling everything.
var slice_w_dir_local: Vector4 = Vector4.ZERO
var slice_base_offset: float = 0.0

## One shared TetraMaterial4D per color band (see TerrainColorBands),
## created once and reused by every pooled node's corresponding mesh
## child - matches the flat-albedo_color pattern used everywhere else in
## this codebase (one material, one color), just one material per BAND
## now instead of one per brick, since all bricks in the same band share
## the exact same fixed color.
var _band_materials: Array = []

func _ready() -> void:
	for band in range(TerrainColorBands.BAND_COUNT):
		var material := TetraMaterial4D.new()
		material.albedo_color = TerrainColorBands.BAND_COLORS[band]
		_band_materials.append(material)

var _bound: Dictionary = {}  # brick key int -> StaticBody4D currently showing that brick
## Parallel to _bound - the brick.mesh_version each bound node was last
## synced to. brick.dirty isn't usable for this: VoxelWorld4D clears it
## the moment regenerate_dirty_bricks() finishes, which happens
## independently of (and may be long before) whenever this pool next
## looks at that brick - see VoxelBrick4D.mesh_version.
var _bound_version: Dictionary = {}
## Parallel to _bound - which VoxelBrick4D each bound node is currently
## showing, purely for external diagnostics (visible_bricks() below) -
## nothing in update()'s own logic needs this, it only exists so callers
## can inspect what's actually on screen without reaching into _bound.
var _bound_brick: Dictionary = {}
var _free_nodes: Array = []

## Bricks per coarse cell, per axis - groups neighboring bricks into one
## spatial-index cell so update() only has to look at cells near the viewer,
## not every dense brick in the world (that per-frame full scan over
## world.get_dense_bricks() was a real steady-state cost - it ran every
## frame regardless of whether anything was actively generating/editing,
## since it's driven by resident brick count, not activity). Doesn't need
## to be fancy: a brick, once dense, stays dense forever - VoxelWorld4D
## never re-collapses one (see its own comment on _uncollapse_brick) - so
## this index only ever grows and never has to handle removal.
const COARSE_CELL_BRICKS := 4

var _coarse_index: Dictionary = {}  # coarse-cell key int -> Dictionary<brick key int, VoxelBrick4D>
## world.dense_brick_count() as of the last _refresh_coarse_index() call -
## an O(1) check that lets a steady-state (nothing new going dense) frame
## skip the index refresh entirely, rather than re-scanning every dense
## brick just to confirm nothing changed.
var _indexed_dense_count: int = -1

static func _coarse_key(brick_coord: Vector4i) -> int:
	var cx := floori(float(brick_coord.x) / float(COARSE_CELL_BRICKS))
	var cy := floori(float(brick_coord.y) / float(COARSE_CELL_BRICKS))
	var cz := floori(float(brick_coord.z) / float(COARSE_CELL_BRICKS))
	var cw := floori(float(brick_coord.w) / float(COARSE_CELL_BRICKS))
	return ((cx & 0xFFFF) << 48) | ((cy & 0xFFFF) << 32) | ((cz & 0xFFFF) << 16) | (cw & 0xFFFF)

## No-op (a single Dictionary.size() comparison) on every frame where the
## resident dense-brick count hasn't changed - i.e. the actual steady-state
## case this fix targets. Only re-scans world.get_dense_bricks() (still
## O(current dense count), same as the old update() paid EVERY frame) on a
## frame where that count grew, which during active population/editing is
## expected work, not a regression - it just no longer also happens on every
## idle frame afterward.
func _refresh_coarse_index() -> void:
	var current_count := world.dense_brick_count()
	if current_count == _indexed_dense_count:
		return
	for brick in world.get_dense_bricks():
		var key := VoxelWorld4D.brick_key(brick.brick_coord)
		var ckey := _coarse_key(brick.brick_coord)
		if not _coarse_index.has(ckey):
			_coarse_index[ckey] = {}
		var cell: Dictionary = _coarse_index[ckey]
		if not cell.has(key):
			cell[key] = brick
	_indexed_dense_count = current_count

## One MeshInstance4D child per color band ("Mesh_0".."Mesh_N-1"), each
## with its material_override set ONCE here to that band's shared
## TerrainColorBands material - never touched again per-sync, only the
## mesh itself changes (see _sync_node).
func _make_node() -> StaticBody4D:
	var body := StaticBody4D.new()
	body.position = Vector4.ZERO
	for band in range(TerrainColorBands.BAND_COUNT):
		var mesh_instance := MeshInstance4D.new()
		mesh_instance.name = "Mesh_%d" % [band]
		mesh_instance.material_override = _band_materials[band]
		body.add_child(mesh_instance)
	var collision_shape := CollisionShape4D.new()
	collision_shape.name = "Collision"
	body.add_child(collision_shape)
	add_child(body)
	return body

func _acquire_node() -> StaticBody4D:
	if _free_nodes.is_empty():
		return _make_node()
	return _free_nodes.pop_back()

func _release_node(body: StaticBody4D) -> void:
	body.visible = false
	for band in range(TerrainColorBands.BAND_COUNT):
		(body.get_node("Mesh_%d" % [band]) as MeshInstance4D).mesh = null
	(body.get_node("Collision") as CollisionShape4D).shape = null
	_free_nodes.append(body)

func _sync_node(body: StaticBody4D, brick: VoxelBrick4D) -> void:
	for band in range(TerrainColorBands.BAND_COUNT):
		var mesh_instance := body.get_node("Mesh_%d" % [band]) as MeshInstance4D
		mesh_instance.mesh = brick.cached_band_meshes[band] if band < brick.cached_band_meshes.size() else null
	var collision_shape := body.get_node("Collision") as CollisionShape4D
	collision_shape.shape = brick.cached_collision_shape

## Call whenever the viewer moves or bricks may have regenerated (once a
## frame is fine - this only does real work for bricks that entered/left
## range or came back with a new mesh_version, both cheap Dictionary
## lookups per brick).
## A range-loop over coarse-cell coordinates, capped so a caller-chosen
## max_render_distance can never blow this up - the range-loop's cell count
## grows as (render_distance / cell_world_size)^4, and a diagnostic/test
## caller that sets max_render_distance to something enormous specifically
## to disable culling (several of this project's own benchmark/measurement
## scripts do exactly this) would otherwise turn a "doesn't need to be
## fancy" cell-range loop into an effectively infinite one - caught the
## hard way: this exact bug hung two real measurement runs for many
## minutes before being traced back here. Above the cap, this falls back
## to iterating every occupied coarse cell directly (bounded by how much of
## the world has ever gone dense, never by render distance) instead of by
## coordinate range - slower than the render-distance-bounded path for a
## huge world with a small render distance, but correct and bounded for
## any input, which the range-loop path is not.
##
## The cap itself is min(MAX_CANDIDATE_CELLS, _coarse_index.size()), not a
## flat constant - a direct measurement (frame time vs. max_render_distance
## on a scene where the populated footprint is small and fully within
## render distance at every tested value) found frame time kept climbing
## with distance alone even though every step's rendered content was
## byte-identical (same visible bricks/tets), because the flat 50000
## constant let the range-loop's cost keep scaling as distance^4 well past
## the point where iterating the world's actual occupied cells directly
## would already be cheaper. Comparing against the occupied-cell count
## instead means the range-loop is only ever used when it's genuinely the
## cheaper of the two options, and cost stops scaling with render distance
## the moment that distance's footprint exceeds the populated world - the
## MAX_CANDIDATE_CELLS constant is kept as an outer ceiling for a huge
## world where even the occupied-cell count is large, not the sole gate.
const MAX_CANDIDATE_CELLS := 50000

## Exact rotated-AABB support-point test: true if [lo, hi] (a brick's local
## nominal AABB) has at least one point on each side of the camera's 4D
## slice plane (ana_offset <= 0 somewhere AND >= 0 somewhere) - i.e. this
## brick's tets could genuinely produce cross-section geometry. False means
## every corner of this box projects to the SAME side, so calculate_boundary
## work here would be provably wasted - see slice_w_dir_local's own comment
## for the derivation.
func _straddles_slice(lo: Vector4, hi: Vector4) -> bool:
	var min_proj := 0.0
	var max_proj := 0.0
	for axis in range(4):
		var d: float = slice_w_dir_local[axis]
		var lo_a: float = lo[axis]
		var hi_a: float = hi[axis]
		if d >= 0.0:
			min_proj += d * lo_a
			max_proj += d * hi_a
		else:
			min_proj += d * hi_a
			max_proj += d * lo_a
	var min_ana: float = min_proj + slice_base_offset
	var max_ana: float = max_proj + slice_base_offset
	return min_ana <= 0.0 and max_ana >= 0.0

func _process_candidate_cell(ckey: int, dist_sq: float, still_visible: Dictionary) -> void:
	if not _coarse_index.has(ckey):
		return
	var cell: Dictionary = _coarse_index[ckey]
	for key in cell:
		var brick: VoxelBrick4D = cell[key]
		var nominal: Dictionary = VoxelBrick4D.nominal_bounds(brick.brick_coord, world.world_origin, world.step)
		var nominal_min: Vector4 = nominal.min
		var nominal_max: Vector4 = nominal.max
		var center: Vector4 = (nominal_min + nominal_max) * 0.5
		if center.distance_squared_to(viewer_position) > dist_sq:
			continue
		if not _straddles_slice(nominal_min, nominal_max):
			continue
		still_visible[key] = true
		if not _bound.has(key):
			var body := _acquire_node()
			body.visible = true
			_bound[key] = body
			_bound_brick[key] = brick
			_sync_node(body, brick)
			_bound_version[key] = brick.mesh_version
		elif _bound_version.get(key, -1) != brick.mesh_version:
			_sync_node(_bound[key], brick)
			_bound_version[key] = brick.mesh_version

func update() -> void:
	if world == null:
		return
	# SPIKE INSTRUMENTATION (temporary - see Terrain4DProfile): times this
	# whole function as "chunk_pool_update". Remove the two
	# Terrain4DProfile lines (and this comment) once the spike's numbers
	# are captured.
	var _profile_t0 := Time.get_ticks_usec()
	_refresh_coarse_index()
	var dist_sq := max_render_distance * max_render_distance
	var still_visible := {}

	# Only the coarse cells within max_render_distance of the viewer are
	# candidates - bounded by render distance, not by total resident brick
	# count, which is what makes this a real fix for the steady-state cost
	# (nothing generating, but update() still ran every frame): the old
	# version scanned every dense brick in the world unconditionally.
	var cell_world_size := Vector4(
		COARSE_CELL_BRICKS * (VoxelBrick4D.NOMINAL_POINTS_PER_AXIS - 1) * world.step.x,
		COARSE_CELL_BRICKS * (VoxelBrick4D.NOMINAL_POINTS_PER_AXIS - 1) * world.step.y,
		COARSE_CELL_BRICKS * (VoxelBrick4D.NOMINAL_POINTS_PER_AXIS - 1) * world.step.z,
		COARSE_CELL_BRICKS * (VoxelBrick4D.NOMINAL_POINTS_PER_AXIS - 1) * world.step.w,
	)
	var lo_x := floori((viewer_position.x - max_render_distance - world.world_origin.x) / cell_world_size.x)
	var lo_y := floori((viewer_position.y - max_render_distance - world.world_origin.y) / cell_world_size.y)
	var lo_z := floori((viewer_position.z - max_render_distance - world.world_origin.z) / cell_world_size.z)
	var lo_w := floori((viewer_position.w - max_render_distance - world.world_origin.w) / cell_world_size.w)
	var hi_x := floori((viewer_position.x + max_render_distance - world.world_origin.x) / cell_world_size.x)
	var hi_y := floori((viewer_position.y + max_render_distance - world.world_origin.y) / cell_world_size.y)
	var hi_z := floori((viewer_position.z + max_render_distance - world.world_origin.z) / cell_world_size.z)
	var hi_w := floori((viewer_position.w + max_render_distance - world.world_origin.w) / cell_world_size.w)

	var span_x: int = hi_x - lo_x + 1
	var span_y: int = hi_y - lo_y + 1
	var span_z: int = hi_z - lo_z + 1
	var span_w: int = hi_w - lo_w + 1
	var candidate_count: float = float(span_x) * float(span_y) * float(span_z) * float(span_w)

	var range_loop_cap: int = mini(MAX_CANDIDATE_CELLS, _coarse_index.size())
	if candidate_count <= range_loop_cap:
		for cx in range(lo_x, hi_x + 1):
			for cy in range(lo_y, hi_y + 1):
				for cz in range(lo_z, hi_z + 1):
					for cw in range(lo_w, hi_w + 1):
						var ckey := ((cx & 0xFFFF) << 48) | ((cy & 0xFFFF) << 32) | ((cz & 0xFFFF) << 16) | (cw & 0xFFFF)
						_process_candidate_cell(ckey, dist_sq, still_visible)
	else:
		for ckey in _coarse_index.keys():
			_process_candidate_cell(ckey, dist_sq, still_visible)

	for key in _bound.keys():
		if not still_visible.has(key):
			_release_node(_bound[key])
			_bound.erase(key)
			_bound_version.erase(key)
			_bound_brick.erase(key)
	Terrain4DProfile.add("chunk_pool_update", Time.get_ticks_usec() - _profile_t0)

func visible_brick_count() -> int:
	return _bound.size()

func pooled_node_count() -> int:
	return _bound.size() + _free_nodes.size()

## The VoxelBrick4D behind every currently-visible pooled node - for
## external diagnostics (e.g. summing visible tet/vertex counts) without
## exposing this pool's internal keyed Dictionaries directly.
func visible_bricks() -> Array:
	return _bound_brick.values()
