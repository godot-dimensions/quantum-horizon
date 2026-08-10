@tool
extends MeshInstance4D
## Generates a semi-fractal 4D island via dual contouring on a heightmap SDF:
## y = height(x, z, w), where height is fractal (fBm) noise shaped by a
## radial falloff mask so it fades to sea level away from the center - the
## standard "noise + island mask" technique, generalized one axis up. Height
## only ever depends on the terrain's 3 horizontal axes (x, z, w), so
## FastNoiseLite's ordinary 3D sampling is sufficient - nothing 4D-specific
## is needed for the noise itself, only for how the resulting surface gets
## dual-contoured and rendered. This is the same generalization of ordinary
## 3D heightmap terrain that HeightMapShape4D already uses elsewhere in this
## engine, just fed through a smooth dual-contoured surface instead of a flat
## quad grid.
##
## Runs as @tool so the generated mesh is visible directly in the editor's 4D
## viewport, in whatever slice the editor camera is currently on, without
## needing to press Play - every exported parameter below regenerates the
## mesh immediately on change.
##
## Dual contouring generalizes cleanly to 4D. In 3D, each bipolar EDGE (a grid
## edge whose two endpoints have different SDF sign) is shared by the 4 cells
## around it, and those 4 cells' per-cell dual vertices become one quad. One
## dimension up, each bipolar edge is shared by the 8 cells around it (2
## choices - "below" or "above" the edge - along each of the other 3 axes),
## and those 8 cells' dual vertices become one hexahedron - the same topology
## as a BoxPolyMesh4D box cell, just with distorted (non-cube) corners.
##
## That hexahedron is never submitted as one rigid cell, though - its 8
## QEF-solved corners are independent solves with no guarantee they form a
## well-behaved shape together, and forcing them into one cell means one bad
## corner invalidates the whole thing. Instead each hexahedron is split into
## 6 tetrahedra (the standard "shared main diagonal" cube decomposition -
## see _CUBE_TETRAHEDRA), and each tetrahedron is checked and kept/dropped on
## its own via the exact same Basis4D.determinant() check ArrayPolyMesh4D
## itself uses to reject degenerate cells (array_poly_mesh_4d.cpp). A
## hexahedron that's only thin along one internal diagonal still gets most
## of its area covered by the other 5 tetrahedra, so a visible gap now needs
## the specific sliver of area to be bad, not the whole cell.

## Baseline/default values, tuned to feel like a natural real-world rocky
## island rather than a smooth toy blob: Voronoi-ish (Cellular) ridgelines
## via a handful of fractal octaves, an island sized and shaped so the
## coastline is comfortably inside the grid, and the grey ground texture
## active by default rather than the heat map. Grid values keep the same
## 112m footprint as before (10 * 11.2 = 16 * 7), just resolved at
## horizontal_resolution=10 instead of 16 - cell_size scales up to
## compensate, and vertical_resolution drops to match (only needs to span
## height_scale at the new, coarser cell_size). That's a real efficiency
## win, not just a different tradeoff: 10^3 * 5 = 5,000 cells vs the
## previous 16^3 * 6 = 24,576, roughly 5x cheaper, while still covering the
## same island area. Used both as the @export defaults below and by
## _reset_to_baseline(), so the two can never drift out of sync with each
## other.
const BASELINE_NOISE_TYPE := FastNoiseLite.TYPE_CELLULAR
const BASELINE_NOISE_FREQUENCY := 0.03
const BASELINE_FRACTAL_OCTAVES := 3
const BASELINE_FRACTAL_GAIN := 0.5
const BASELINE_TERRAIN_SEED := 1
const BASELINE_HEIGHT_SCALE := 25.0
const BASELINE_ISLAND_RADIUS := 40.0
const BASELINE_ISLAND_FALLOFF_POWER := 1.8
const BASELINE_HORIZONTAL_RESOLUTION := 10
const BASELINE_VERTICAL_RESOLUTION := 5
const BASELINE_CELL_SIZE := 11.2
const BASELINE_ALBEDO_TEXTURE_3D := preload("res://textures/dev_finals/ramdev_grey.png")
const BASELINE_TEXTURE_REPEATS_PER_METER := 1.0
const BASELINE_HEATMAP_STRENGTH := 0.0

## Set while _reset_to_baseline() is reassigning every exported var in turn,
## so each individual setter's _regenerate() call is skipped in favor of one
## single regenerate at the end - otherwise resetting ~13 exported vars back
## to baseline would rebuild the entire mesh ~13 times in a row.
var _suppress_regenerate := false

@export_tool_button("Randomize") var _randomize_button_action: Callable = _randomize_terrain
@export_tool_button("Reset All to Baseline") var _reset_button_action: Callable = _reset_to_baseline

## The 3 density presets below all target this same fixed resolution ladder
## (10/16/20) regardless of the island's current footprint or height_scale -
## keeping resolution fixed per tier, rather than scaling it with whatever
## footprint happens to be set, is what keeps every preset provably safe:
## see _apply_density_preset's vertical_resolution clamp for the actual
## worst-case math.
const _PRESET_LOW_RESOLUTION := 10
const _PRESET_MEDIUM_RESOLUTION := 16
const _PRESET_HIGH_RESOLUTION := 20
## Hard bound on the vertical_resolution a preset will ever pick, regardless
## of height_scale/footprint at the time it's pressed. With this cap, even
## _PRESET_HIGH_RESOLUTION (20) can never exceed 20^3 * 7 = 56,000 cells -
## safely under MAX_TOTAL_CELLS (60,000) no matter what. Without this cap, a
## small footprint combined with a tall height_scale could otherwise compute
## a vertical_resolution well past that.
const _PRESET_MAX_VERTICAL_RESOLUTION := 7

@export_tool_button("Low Detail (Fast)", "GuiRadioUnchecked") var _preset_low_action: Callable = _apply_low_detail_preset
@export_tool_button("Medium Detail (Balanced)", "GuiRadioUnchecked") var _preset_medium_action: Callable = _apply_medium_detail_preset
@export_tool_button("High Detail (Slow)", "GuiRadioUnchecked") var _preset_high_action: Callable = _apply_high_detail_preset

@export_group("Noise")
## FastNoiseLite's own noise-type dropdown - TYPE_CELLULAR is real Voronoi
## noise, the others (Simplex/Perlin/Value) are the usual smooth gradient
## noises. Swapping this is the "manual Voronoi option" - no separate toggle
## needed since it's already a native enum dropdown. Cellular is also the
## baseline default - it's what actually gives the ridge-and-basin look most
## real rocky islands have, rather than smooth rolling hills.
@export var noise_type: FastNoiseLite.NoiseType = BASELINE_NOISE_TYPE:
	set(value):
		noise_type = value
		if not _suppress_regenerate:
			_regenerate()
## In cycles per meter. 0.03 (baseline) puts a Voronoi cell roughly every
## 30m, giving a handful of distinct ridges/basins across a ~112m island
## rather than one smooth dome or dozens of tiny repetitive bumps.
@export var noise_frequency: float = BASELINE_NOISE_FREQUENCY:
	set(value):
		noise_frequency = max(0.001, value)
		if not _suppress_regenerate:
			_regenerate()
## Number of fBm noise layers (each half the amplitude, double the
## frequency of the last) - this is what makes the terrain "fractal" rather
## than a single smooth bump field. 1 = plain noise, 4-6 = visibly rougher.
@export var fractal_octaves: int = BASELINE_FRACTAL_OCTAVES:
	set(value):
		fractal_octaves = clamp(value, 1, 8)
		if not _suppress_regenerate:
			_regenerate()
@export_range(0.0, 1.0) var fractal_gain: float = BASELINE_FRACTAL_GAIN:
	set(value):
		fractal_gain = value
		if not _suppress_regenerate:
			_regenerate()
@export var terrain_seed: int = BASELINE_TERRAIN_SEED:
	set(value):
		terrain_seed = value
		if not _suppress_regenerate:
			_regenerate()

@export_group("Island Shape")
## Height of the tallest possible point, in meters above sea level.
@export_range(0.0, 200.0, 0.5, "or_greater", "suffix:m") var height_scale: float = BASELINE_HEIGHT_SCALE:
	set(value):
		height_scale = value
		if not _suppress_regenerate:
			_regenerate()
## Distance from the center, in meters, where the falloff overtakes the
## noise (the coastline sits roughly here - see _terrain_height). This is a
## real-world distance in the same meters as the rest of the scene, via
## _grid_point()'s cell_size conversion - not an arbitrary unit. Needs to be
## comfortably smaller than horizontal_resolution * cell_size / 2 (half the
## grid's own footprint in meters), or the coastline falls outside the grid
## entirely and every visible cell reads as "island" - which is exactly what
## made earlier versions look like a dome with no edges, before the domain
## was sized in real meters at all.
@export_range(0.5, 300.0, 0.5, "or_greater", "suffix:m") var island_radius: float = BASELINE_ISLAND_RADIUS:
	set(value):
		island_radius = max(0.5, value)
		if not _suppress_regenerate:
			_regenerate()
## Higher = the island holds its height out further and drops off more
## abruptly near island_radius; lower = a gentler, more gradual taper. 1.8
## (baseline) leans toward the gentler side, closer to a real eroded
## coastline than a sharp cliff-edge cutoff.
@export var island_falloff_power: float = BASELINE_ISLAND_FALLOFF_POWER:
	set(value):
		island_falloff_power = max(0.1, value)
		if not _suppress_regenerate:
			_regenerate()

@export_group("Grid")
## Cells across each horizontal axis. Total footprint is horizontal_resolution
## * cell_size meters per side - 10 * 11.2 = 112m at baseline. Raising this
## adds detail but costs resolution^3 more cells on top of
## vertical_resolution, so go up deliberately, not by default - the density
## preset buttons above are the easier way to move between resolution tiers
## without doing this math by hand.
@export var horizontal_resolution: int = BASELINE_HORIZONTAL_RESOLUTION:
	set(value):
		horizontal_resolution = max(2, value)
		if not _suppress_regenerate:
			_regenerate()
## Only needs to comfortably span height_scale, not match
## horizontal_resolution - height_scale=25 and cell_size=11.2 only needs ~3
## cells of actual vertical range plus margin.
@export var vertical_resolution: int = BASELINE_VERTICAL_RESOLUTION:
	set(value):
		vertical_resolution = max(2, value)
		if not _suppress_regenerate:
			_regenerate()
## Meters per voxel edge, the same for all 4 axes (including vertical and w).
## This is the actual meters-per-unit conversion for the whole grid - every
## other "meters" value here (height_scale, island_radius) is only really in
## meters because _grid_point() multiplies grid coordinates by this. 11.2m
## keeps the same 112m footprint as the earlier 16-resolution/7m-cell
## baseline, just resolved at a cheaper resolution (10^3 * 5 = 5,000 cells
## vs the previous 24,576) - see the DEGENERATE_VOLUME_FRACTION note for why
## a coarser cell_size also means fewer gaps, not just less detail.
@export_range(0.05, 50.0, 0.05, "or_greater", "suffix:m") var cell_size: float = BASELINE_CELL_SIZE:
	set(value):
		cell_size = max(0.05, value)
		if not _suppress_regenerate:
			_regenerate()

@export_group("Visualization")
## Optional ground texture (must be a Texture3D, not a plain 2D image - drag
## a 2D source in, then Import dock -> Import As -> 3D Texture, same as
## every other tetra-mapped texture in this project). When set, this
## replaces the heat map entirely - the material can only use one albedo
## source at a time, so texture and heat map aren't shown together. Defaults
## to the grey ground texture - resetting to baseline restores this same
## texture rather than clearing it to none.
@export var albedo_texture_3d: Texture3D = BASELINE_ALBEDO_TEXTURE_3D:
	set(value):
		albedo_texture_3d = value
		if not _suppress_regenerate:
			_regenerate()
## How many times the texture repeats per meter of world space. 1.0 (the
## base/correct value for "one texture unit = one meter") means each repeat
## spans exactly 1m regardless of cell_size - this is deliberately NOT a
## flat multiplier like "4 repeats per cell", because EACH_CELL_FILLS gives
## every cell a 0..1 UV range across its own cell_size-meter face, so
## scaling that UV range by cell_size (not by some fixed number) is what
## makes 1 UV-tile correspond to 1 meter in the first place - see
## _regenerate()'s actual_texture_scale. Raise above 1.0 for a texture that
## should look smaller/denser than 1m per repeat, lower for bigger. Requires
## the Texture3D's own repeat/wrap import setting to actually be Repeat
## rather than Clamp, or this will just smear the edge pixel instead of
## tiling - check that on the texture's import settings if this doesn't
## visibly change anything.
@export_range(0.01, 8.0, 0.01, "or_greater") var texture_repeats_per_meter: float = BASELINE_TEXTURE_REPEATS_PER_METER:
	set(value):
		texture_repeats_per_meter = max(0.001, value)
		if not _suppress_regenerate:
			_regenerate()
## Blends a height-based heat gradient (blue low -> green mid -> red high)
## into the base terrain color, per vertex. 0 = plain green, 1 = full heat
## map. Meant as a diagnostic overlay - off (0.0) at baseline so the default
## look is plain, natural terrain color, not a debug visualization. Ignored
## entirely while albedo_texture_3d is set.
@export_range(0.0, 1.0) var heatmap_strength: float = BASELINE_HEATMAP_STRENGTH:
	set(value):
		heatmap_strength = value
		if not _suppress_regenerate:
			_regenerate()

## Pulls the solved QEF vertex toward the mass point (average crossing
## position) whenever the local edge normals are near-degenerate, which keeps
## the per-cell 4x4 solve always well-conditioned (strictly positive
## definite) without needing a separate singular-matrix fallback path.
const QEF_BIAS_WEIGHT := 0.1
## Step size for the central-difference height gradient.
const GRADIENT_EPSILON := 0.05
const BASE_TERRAIN_COLOR := Color(0.4, 0.55, 0.3)

## Standard "6 tetrahedra sharing the main diagonal" decomposition of a cube,
## using this file's corner numbering (0-7, bit 2/1/0 = above/below along
## local axis a/b/c). All 6 entries share corners 0 and 7 (opposite corners
## of the cube), differing only in which 2 of the remaining 6 corners sit
## between them on the way from 0 to 7 - the classic way to tile a hexahedron
## into 6 non-overlapping tetrahedra with no gaps between the pieces
## themselves (whether the whole thing has gaps at its OWN boundary is a
## separate question, handled by the per-tetrahedron degeneracy check in
## _append_hexahedron).
const _CUBE_TETRAHEDRA := [
	[0, 4, 6, 7], [0, 4, 5, 7],
	[0, 2, 6, 7], [0, 2, 3, 7],
	[0, 1, 5, 7], [0, 1, 3, 7],
]
## A tetrahedron's 4 triangular faces, by local vertex index 0-3. The first
## two share edge (0,1), automatically satisfying PolyMesh4D's "first two
## faces must share a common edge" orientation rule - unlike a hexahedron's
## 6 quad faces, a tetrahedron's 4 triangular faces can never be ordered in
## a way that violates this, so there's no face-ordering puzzle here at all.
const _TET_FACES := [
	[0, 1, 2], [0, 1, 3], [0, 2, 3], [1, 2, 3],
]
## Below this fraction of a "typical" cell's volume (cell_size^3), a
## tetrahedron is treated as too thin/sliver-shaped to keep. Mirrors
## ArrayPolyMesh4D's own "Cell is degenerate" check (array_poly_mesh_4d.cpp),
## just applied per-tetrahedron before submission instead of discovering it
## after the fact from an engine error. Scaled to cell_size^3 rather than a
## fixed number so it stays meaningful across very different cell_size
## values, though this is a hand-picked heuristic threshold, not a
## reproduction of the engine's own (differently-derived) tolerance formula.
const DEGENERATE_VOLUME_FRACTION := 1e-4
## horizontal_resolution^3 * vertical_resolution ceiling - see the guard in
## _regenerate(). 60,000 sits comfortably above the 24,576-cell baseline
## (16^3 * 6) with room to raise resolution a bit deliberately, while
## solidly blocking the ~138,000-cell case that previously took minutes and
## locked up the editor on scene reopen.
const MAX_TOTAL_CELLS := 60000

var _noise: FastNoiseLite
var _resolution: Vector4i
var _origin: Vector4
var _collision_body: StaticBody4D
var _collision_shape_node: CollisionShape4D
## height(x, z, w) sampled once per (horizontal_resolution+1)^3 grid point at
## the start of each regenerate - see _build_height_cache. Every corner/edge
## SDF lookup and the collision heightmap all read from this instead of
## re-evaluating _terrain_height() from scratch, which was previously being
## called dozens of times per grid point (once per neighboring cell/vertical
## layer that happened to touch it) despite height never depending on y or
## on which cell is asking.
var _height_cache: PackedFloat64Array
var _height_cache_grid_points: int


func _ready() -> void:
	_regenerate()


## Inspector button ("Randomize"). Deliberately only randomizes terrain_seed
## rather than also jittering height_scale/island_radius/etc - a new seed
## alone already gives a completely different island layout while keeping
## whatever "feel" the other tuned parameters currently have, which is
## safer/more predictable than randomizing everything at once and
## potentially landing on an ugly combination.
func _randomize_terrain() -> void:
	terrain_seed = randi()


## Inspector button ("Reset All to Baseline"). Restores every exported
## parameter to its BASELINE_* constant, including albedo_texture_3d back to
## the grey ground texture (not cleared to none - the grey texture is itself
## part of the baseline look). Suppresses the usual per-setter regenerate so
## this doesn't rebuild the mesh once per parameter (~13 times in a row) -
## just once at the end, after everything's been reassigned.
func _reset_to_baseline() -> void:
	_suppress_regenerate = true
	noise_type = BASELINE_NOISE_TYPE
	noise_frequency = BASELINE_NOISE_FREQUENCY
	fractal_octaves = BASELINE_FRACTAL_OCTAVES
	fractal_gain = BASELINE_FRACTAL_GAIN
	terrain_seed = BASELINE_TERRAIN_SEED
	height_scale = BASELINE_HEIGHT_SCALE
	island_radius = BASELINE_ISLAND_RADIUS
	island_falloff_power = BASELINE_ISLAND_FALLOFF_POWER
	horizontal_resolution = BASELINE_HORIZONTAL_RESOLUTION
	vertical_resolution = BASELINE_VERTICAL_RESOLUTION
	cell_size = BASELINE_CELL_SIZE
	albedo_texture_3d = BASELINE_ALBEDO_TEXTURE_3D
	texture_repeats_per_meter = BASELINE_TEXTURE_REPEATS_PER_METER
	heatmap_strength = BASELINE_HEATMAP_STRENGTH
	_suppress_regenerate = false
	_regenerate()


func _apply_low_detail_preset() -> void:
	_apply_density_preset(_PRESET_LOW_RESOLUTION)


func _apply_medium_detail_preset() -> void:
	_apply_density_preset(_PRESET_MEDIUM_RESOLUTION)


func _apply_high_detail_preset() -> void:
	_apply_density_preset(_PRESET_HIGH_RESOLUTION)


## Shared by all 3 density preset buttons. Keeps the island's current
## footprint (horizontal_resolution * cell_size) fixed and re-solves
## cell_size for the target resolution, so switching density tiers changes
## how finely the SAME island is sampled rather than changing its size.
## vertical_resolution is recomputed to comfortably span height_scale at the
## new cell_size, clamped to _PRESET_MAX_VERTICAL_RESOLUTION - that clamp is
## what makes every preset safe regardless of whatever height_scale/
## footprint was already set: target_resolution^3 * 7 is at most 56,000
## (for the High tier), always under MAX_TOTAL_CELLS.
func _apply_density_preset(target_horizontal_resolution: int) -> void:
	var footprint: float = horizontal_resolution * cell_size
	var new_cell_size: float = footprint / target_horizontal_resolution
	var new_vertical_resolution: int = clampi(ceili(height_scale / new_cell_size) + 2, 2, _PRESET_MAX_VERTICAL_RESOLUTION)

	_suppress_regenerate = true
	horizontal_resolution = target_horizontal_resolution
	cell_size = new_cell_size
	vertical_resolution = new_vertical_resolution
	_suppress_regenerate = false
	_regenerate()


func _regenerate() -> void:
	if not is_inside_tree():
		return # Exported setters can fire while the scene is still loading.

	# Safety cap: this whole generator is a single synchronous pass on the
	# main thread, with no chunking/streaming - a resolution bumped too high
	# (by a slider drag, or by this scene reopening with a leftover high
	# value from earlier testing) blocks the entire editor UI for as long as
	# it takes to finish, which can be minutes. Bailing out early here (and
	# just leaving whatever mesh/collision already existed in place) means
	# that can never happen - worst case, a parameter change silently does
	# nothing until the cell count is brought back under the cap.
	var total_cells: int = horizontal_resolution * horizontal_resolution * horizontal_resolution * vertical_resolution
	if total_cells > MAX_TOTAL_CELLS:
		print("4D terrain: skipped regenerate - %d cells (%d horizontal^3 * %d vertical) exceeds the %d safety cap. Lower horizontal_resolution, vertical_resolution, or raise cell_size to shrink this." % [total_cells, horizontal_resolution, vertical_resolution, MAX_TOTAL_CELLS])
		return

	_resolution = Vector4i(horizontal_resolution, vertical_resolution, horizontal_resolution, horizontal_resolution)
	var horizontal_half: float = horizontal_resolution * 0.5 * cell_size
	_origin = Vector4(-horizontal_half, -cell_size, -horizontal_half, -horizontal_half)
	_setup_noise()
	_build_height_cache()

	var poly_mesh := ArrayPolyMesh4D.new()
	var dual_vertices: Dictionary = {} # Vector4i cell coord -> vertex index in `poly_mesh`.
	var vertex_heights := PackedFloat64Array() # Indexed the same as poly_mesh's vertices, for the heat map.
	var vertex_positions := PackedVector4Array() # Indexed the same as poly_mesh's vertices, for the degeneracy check.

	for x in range(_resolution.x):
		for y in range(_resolution.y):
			for z in range(_resolution.z):
				for w in range(_resolution.w):
					_try_add_cell_dual_vertex(poly_mesh, dual_vertices, vertex_heights, vertex_positions, Vector4i(x, y, z, w))

	var cell_heights := PackedFloat64Array() # Indexed the same as poly_mesh's 3D cells, for the heat map.
	var hexahedra_attempted := 0
	var hexahedra_built := 0
	var tets_kept := 0
	var tets_skipped_degenerate := 0
	for axis in range(4):
		var axis_result: Vector4i = _build_hexahedra_along_axis(poly_mesh, dual_vertices, vertex_heights, vertex_positions, cell_heights, axis)
		hexahedra_attempted += axis_result.x
		hexahedra_built += axis_result.y
		tets_kept += axis_result.z
		tets_skipped_degenerate += axis_result.w

	# Flat (not smooth) shading: a single degenerate/near-coincident cell
	# (e.g. two neighboring QEF solves clamped into the same corner) can only
	# corrupt that one cell's own normal, not the neighbors it happens to
	# share vertices with. Smooth shading averages normals across shared
	# vertices, which would let one bad cell spread a NaN normal across a
	# much larger, otherwise-fine area of the surface.
	poly_mesh.calculate_boundary_normals(ArrayPolyMesh4D.COMPUTE_NORMALS_MODE_FORCE_OUTWARD_FIX_CELL_ORIENTATION)
	poly_mesh.set_flat_shading_normals(ArrayPolyMesh4D.COMPUTE_NORMALS_MODE_FORCE_OUTWARD_FIX_CELL_ORIENTATION, false)
	# Needed for albedo_texture_3d to mean anything - without this every
	# cell's UVW texture coordinates are just zero, so a texture sample would
	# be reading the same single texel everywhere rather than actually
	# mapping across the surface. Skipped entirely when no texture is set
	# (heat-map-only mode) - unwrapping still costs a full pass over every
	# cell, and that data would never be read by anything in that mode, so
	# there's no reason to pay for it.
	if albedo_texture_3d != null:
		# EACH_CELL_FILLS (not TILE_CELLS) is the mode that actually tiles: it
		# gives every cell its own full (0,0,0)-(1,1,1) UVW range, so the same
		# texture repeats once per cell. TILE_CELLS does the opposite - it
		# slices the texture into one small piece per cell so it never
		# repeats at all.
		poly_mesh.unwrap_texture_map(ArrayPolyMesh4D.UNWRAP_MODE_EACH_CELL_FILLS)
		# cell_size itself, not texture_repeats_per_meter alone, is the base
		# scale factor - that's what actually converts "1 UV-tile" into "1
		# meter" for whatever cell_size currently is. texture_repeats_per_meter
		# only adjusts away from that 1:1 baseline.
		var actual_texture_scale: float = cell_size * texture_repeats_per_meter
		poly_mesh.transform_texture_map(Transform3D.IDENTITY.scaled(Vector3.ONE * actual_texture_scale))

	mesh = poly_mesh
	_apply_material(cell_heights)
	_rebuild_collision()

	var footprint_meters: float = horizontal_resolution * cell_size
	print("4D terrain: %.0fm x %.0fm footprint, %d active cells, %d/%d hexahedra with geometry, %d tetrahedra kept, %d skipped (degenerate)" % [footprint_meters, footprint_meters, dual_vertices.size(), hexahedra_built, hexahedra_attempted, tets_kept, tets_skipped_degenerate])


func _setup_noise() -> void:
	_noise = FastNoiseLite.new()
	_noise.seed = terrain_seed
	_noise.noise_type = noise_type
	_noise.frequency = noise_frequency
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = fractal_octaves
	_noise.fractal_gain = fractal_gain


## Samples _terrain_height() exactly once per (horizontal_resolution+1)^3
## grid point, since height never depends on y or on which cell asks for it.
## Every corner/edge lookup during mesh building, plus the collision
## heightmap, reads from this instead of re-evaluating the noise function
## from scratch - the single biggest performance lever in this whole
## generator, since without it a single grid point's height could get
## recomputed dozens of times (once per neighboring cell and vertical
## layer that happens to touch it).
##
## Indexed as ix + iz*n + iw*n*n (n = grid points per axis) - deliberately
## the same formula HeightMapShape4D's own get_height_index uses when
## grid_size is a cube (all 3 axes equal), so _rebuild_collision can hand
## this array to the collision shape directly with no translation.
func _build_height_cache() -> void:
	_height_cache_grid_points = horizontal_resolution + 1
	var n := _height_cache_grid_points
	_height_cache = PackedFloat64Array()
	_height_cache.resize(n * n * n)
	for ix in range(n):
		for iz in range(n):
			for iw in range(n):
				var world_x: float = _origin.x + ix * cell_size
				var world_z: float = _origin.z + iz * cell_size
				var world_w: float = _origin.w + iw * cell_size
				_height_cache[ix + iz * n + iw * n * n] = _terrain_height(world_x, world_z, world_w)


func _cached_height(ix: int, iz: int, iw: int) -> float:
	var n := _height_cache_grid_points
	return _height_cache[ix + iz * n + iw * n * n]


## The signed distance (world y minus terrain height) at a grid-aligned
## point, read from the cached height instead of re-evaluating
## _terrain_height() - use this wherever the caller already has a
## grid-aligned Vector4i index (which is every corner/edge lookup during
## mesh building). _sdf_gradient's finite-difference
## samples are off-grid (epsilon-shifted), so those still need the real
## _terrain_height() call - this cache only covers grid-aligned lookups.
func _sdf_at_grid_index(grid_index: Vector4i) -> float:
	var world_y: float = _origin.y + grid_index.y * cell_size
	return world_y - _cached_height(grid_index.x, grid_index.z, grid_index.w)


## Builds/updates a HeightMapShape4D collider directly from _height_cache -
## not a ConcaveMeshShape4D built from poly_mesh itself. A heightmap has no
## vertices or seams for a CharacterBody4D to catch on the way a raw trimesh
## collider from our slightly-irregular dual-contoured hexahedra could, and
## since this generator can only ever describe "y above/below height(x,z,w)"
## - never an overhang - a heightmap loses nothing bad here; it's an exact
## match to what this generator can produce, not an approximation of it.
##
## HeightMapShape4D centers its own grid the same way _origin does here
## ((grid_size-1) * -0.5 * grid_spacing, see the engine's
## _get_start_physical_offset), so using the same grid_size/grid_spacing as
## the render grid lines the two up automatically with no extra offset math.
func _rebuild_collision() -> void:
	if _collision_body == null:
		_collision_body = StaticBody4D.new()
		add_child(_collision_body)
		_collision_shape_node = CollisionShape4D.new()
		_collision_body.add_child(_collision_shape_node)

	var grid_points: int = _height_cache_grid_points
	var shape := HeightMapShape4D.new()
	shape.grid_size = Vector3i(grid_points, grid_points, grid_points)
	shape.grid_spacing = Vector3(cell_size, cell_size, cell_size)
	# _height_cache's indexing (ix + iz*n + iw*n*n) matches
	# get_height_index's own formula exactly when grid_size is a cube, so
	# this hands the collision shape the literal same samples the render
	# mesh was built from - no second sampling pass, no room for the two to
	# disagree with each other.
	shape.height_data = _height_cache

	_collision_shape_node.shape = shape


## If albedo_texture_3d is assigned, uses it (via the UVW unwrap done in
## _regenerate). Otherwise falls back to the heat map, colored per 3D cell
## (hexahedron) rather than per vertex - matching the same per-cell data
## pathway calculate_boundary_normals/set_flat_shading_normals already use,
## which is known to work (that's what the visible lit shading is coming
## from). An earlier per-vertex attempt rendered solid white, almost
## certainly because PER_VERT_ONLY indexes its color array against something
## other than the plain append_vertex order assumed here.
func _apply_material(cell_heights: PackedFloat64Array) -> void:
	if not (material_override is TetraMaterial4D):
		material_override = TetraMaterial4D.new()
	var material: TetraMaterial4D = material_override

	if albedo_texture_3d != null:
		material.albedo_texture_3d = albedo_texture_3d
		material.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_TEXTURE3D_CELL_UVW_ONLY
		return

	var colors := PackedColorArray()
	colors.resize(cell_heights.size())
	var safe_height_scale: float = max(height_scale, 0.001)
	for i in range(cell_heights.size()):
		var t: float = clamp(cell_heights[i] / safe_height_scale, 0.0, 1.0)
		colors[i] = BASE_TERRAIN_COLOR.lerp(_heat_color(t), heatmap_strength)

	material.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_PER_CELL_ONLY
	material.albedo_color_array = colors


## Blue (low) -> green (mid) -> red (high), for the heat map overlay.
func _heat_color(t: float) -> Color:
	if t < 0.5:
		return Color(0.15, 0.25, 0.85).lerp(Color(0.2, 0.85, 0.3), t / 0.5)
	return Color(0.2, 0.85, 0.3).lerp(Color(0.9, 0.2, 0.15), (t - 0.5) / 0.5)


## height(x, z, w) = max(0, noise - falloff(distance)) * height_scale.
## Subtracting the radial falloff from the noise (rather than multiplying the
## noise by a mask) is what actually gives the coastline its shape: since
## noise varies with position, the point where "noise > falloff" flips
## happens at a different distance in every direction, producing an
## irregular, natural-looking edge. Multiplying by a mask instead would force
## height to hit exactly 0 at exactly distance == island_radius everywhere,
## which is a perfect circle no matter what the noise looks like.
##
## noise01 is explicitly clamped to [0, 1] - raw FastNoiseLite output is
## nominally [-1, 1], but fractal layering (multiple octaves summed) isn't
## strictly guaranteed to stay within that range for every noise type/gain
## combination, and Cellular in particular can drift past it. Without this
## clamp, noise01 slightly above 1.0 lets "noise01 - falloff" stay positive
## just past island_radius (where falloff is only just above 1), producing
## small false patches of solid ground - and solid *collision* - out in
## what's supposed to be open ocean with nothing rendered there at all.
func _terrain_height(x: float, z: float, w: float) -> float:
	var noise01: float = clampf((_noise.get_noise_3d(x, z, w) + 1.0) * 0.5, 0.0, 1.0)
	var distance_from_center: float = Vector3(x, z, w).length()
	var falloff: float = pow(distance_from_center / island_radius, island_falloff_power)
	var elevation: float = noise01 - falloff
	return height_scale * max(0.0, elevation)


func _sdf_gradient(p: Vector4) -> Vector4:
	var dhdx: float = (_terrain_height(p.x + GRADIENT_EPSILON, p.z, p.w) - _terrain_height(p.x - GRADIENT_EPSILON, p.z, p.w)) / (2.0 * GRADIENT_EPSILON)
	var dhdz: float = (_terrain_height(p.x, p.z + GRADIENT_EPSILON, p.w) - _terrain_height(p.x, p.z - GRADIENT_EPSILON, p.w)) / (2.0 * GRADIENT_EPSILON)
	var dhdw: float = (_terrain_height(p.x, p.z, p.w + GRADIENT_EPSILON) - _terrain_height(p.x, p.z, p.w - GRADIENT_EPSILON)) / (2.0 * GRADIENT_EPSILON)
	return Vector4(-dhdx, 1.0, -dhdz, -dhdw).normalized()


func _grid_point(cell_coord: Vector4i) -> Vector4:
	return Vector4(
		_origin.x + cell_coord.x * cell_size,
		_origin.y + cell_coord.y * cell_size,
		_origin.z + cell_coord.z * cell_size,
		_origin.w + cell_coord.w * cell_size,
	)


func _corner_offset(corner_index: int) -> Vector4i:
	return Vector4i(
		corner_index & 1,
		(corner_index >> 1) & 1,
		(corner_index >> 2) & 1,
		(corner_index >> 3) & 1,
	)


## Solves for this tesseract cell's dual vertex and records it into
## `dual_vertices` (and its height into `vertex_heights`, at the same index),
## unless none of its 32 edges cross the surface (all 16 corners share the
## same sign), in which case the cell is left out entirely.
func _try_add_cell_dual_vertex(poly_mesh: ArrayPolyMesh4D, dual_vertices: Dictionary, vertex_heights: PackedFloat64Array, vertex_positions: PackedVector4Array, cell_coord: Vector4i) -> void:
	var corner_values := PackedFloat64Array()
	corner_values.resize(16)
	for i in range(16):
		corner_values[i] = _sdf_at_grid_index(cell_coord + _corner_offset(i))

	var crossing_points: Array[Vector4] = []
	var crossing_normals: Array[Vector4] = []
	for axis in range(4):
		var axis_bit: int = 1 << axis
		for corner_index_lo in range(16):
			if corner_index_lo & axis_bit != 0:
				continue # Only visit each of the 32 edges once, from its "low" end.
			var corner_index_hi: int = corner_index_lo | axis_bit
			var v_lo: float = corner_values[corner_index_lo]
			var v_hi: float = corner_values[corner_index_hi]
			if (v_lo < 0.0) == (v_hi < 0.0):
				continue # Not bipolar - the surface doesn't cross this edge.
			var t: float = v_lo / (v_lo - v_hi)
			var p_lo: Vector4 = _grid_point(cell_coord + _corner_offset(corner_index_lo))
			var p_hi: Vector4 = _grid_point(cell_coord + _corner_offset(corner_index_hi))
			var crossing: Vector4 = p_lo.lerp(p_hi, t)
			crossing_points.append(crossing)
			crossing_normals.append(_sdf_gradient(crossing))

	if crossing_points.is_empty():
		return

	var mass_point := Vector4.ZERO
	for p in crossing_points:
		mass_point += p
	mass_point /= crossing_points.size()

	# Least-squares fit (QEF) for the single point that best lies on every
	# crossing's local tangent hyperplane at once: minimize sum_i (n_i . (x -
	# p_i))^2, i.e. solve (sum_i n_i n_i^T) x = sum_i n_i (n_i . p_i), with a
	# small multiple of the identity added to both sides (pulling toward the
	# mass point) so the 4x4 matrix is always invertible.
	var col_x := Vector4.ZERO
	var col_y := Vector4.ZERO
	var col_z := Vector4.ZERO
	var col_w := Vector4.ZERO
	var rhs := Vector4.ZERO
	for i in range(crossing_points.size()):
		var n: Vector4 = crossing_normals[i]
		var p: Vector4 = crossing_points[i]
		col_x += n * n.x
		col_y += n * n.y
		col_z += n * n.z
		col_w += n * n.w
		rhs += n * n.dot(p)
	col_x.x += QEF_BIAS_WEIGHT
	col_y.y += QEF_BIAS_WEIGHT
	col_z.z += QEF_BIAS_WEIGHT
	col_w.w += QEF_BIAS_WEIGHT
	rhs += QEF_BIAS_WEIGHT * mass_point

	var qef_matrix := Projection(col_x, col_y, col_z, col_w)
	var vertex_pos: Vector4 = qef_matrix.inverse() * rhs

	# Clamp into the cell's own bounds - a standard dual contouring robustness
	# fix, since an ill-fit QEF can otherwise place the vertex well outside
	# the cell that's supposed to own it.
	var cell_min: Vector4 = _grid_point(cell_coord)
	var cell_max: Vector4 = _grid_point(cell_coord + Vector4i(1, 1, 1, 1))
	vertex_pos.x = clamp(vertex_pos.x, cell_min.x, cell_max.x)
	vertex_pos.y = clamp(vertex_pos.y, cell_min.y, cell_max.y)
	vertex_pos.z = clamp(vertex_pos.z, cell_min.z, cell_max.z)
	vertex_pos.w = clamp(vertex_pos.w, cell_min.w, cell_max.w)

	# NaN/Inf guard: clamp() doesn't reliably filter non-finite values (NaN
	# comparisons are always false in IEEE floats, so clamp's internal
	# min/max can pass NaN straight through), and a QEF solve can go
	# genuinely non-finite on a pathological input - e.g. an extreme
	# finite-difference gradient right at a Cellular noise cell boundary,
	# where the height field has a real discontinuity. Falling back to the
	# mass point (guaranteed finite - it's a plain average of finite
	# crossing points) keeps this cell's vertex usable instead of poisoning
	# every tetrahedron that touches it.
	if not (is_finite(vertex_pos.x) and is_finite(vertex_pos.y) and is_finite(vertex_pos.z) and is_finite(vertex_pos.w)):
		vertex_pos = mass_point

	var vertex_index: int = poly_mesh.append_vertex(vertex_pos)
	if vertex_index >= vertex_heights.size():
		vertex_heights.resize(vertex_index + 1)
	if vertex_index >= vertex_positions.size():
		vertex_positions.resize(vertex_index + 1)
	vertex_heights[vertex_index] = vertex_pos.y
	vertex_positions[vertex_index] = vertex_pos
	dual_vertices[cell_coord] = vertex_index


## The 3 axes other than [param axis], in ascending order. A tesseract edge
## running along [param axis] is shared by the 8 cells that each pick "below"
## or "above" that edge along these 3 other axes.
func _other_axes(axis: int) -> PackedInt32Array:
	var others := PackedInt32Array()
	for a in range(4):
		if a != axis:
			others.append(a)
	return others


## For every grid edge running along [param axis], builds the hexahedron
## (as up to 6 independent tetrahedra - see _append_hexahedron) from the 8
## surrounding cells' dual vertices, if the edge is bipolar and its full
## ring of 8 neighbors exists (i.e. it's not on the outermost boundary
## layer, where the surface is deliberately left open). Returns (hexahedron
## locations attempted, locations with at least 1 surviving tetrahedron,
## total tetrahedra kept, total tetrahedra skipped as degenerate) as a
## Vector4i, since GDScript has no lightweight multi-return - fittingly,
## this project already leans on 4-component vectors for everything else.
func _build_hexahedra_along_axis(poly_mesh: ArrayPolyMesh4D, dual_vertices: Dictionary, vertex_heights: PackedFloat64Array, vertex_positions: PackedVector4Array, cell_heights: PackedFloat64Array, axis: int) -> Vector4i:
	var others: PackedInt32Array = _other_axes(axis)
	var hexahedra_attempted := 0
	var hexahedra_with_geometry := 0
	var tets_kept := 0
	var tets_skipped := 0
	for e in range(_resolution[axis]):
		for p0 in range(1, _resolution[others[0]]):
			for p1 in range(1, _resolution[others[1]]):
				for p2 in range(1, _resolution[others[2]]):
					var lo := Vector4i(0, 0, 0, 0)
					var hi := Vector4i(0, 0, 0, 0)
					lo[axis] = e
					hi[axis] = e + 1
					lo[others[0]] = p0; hi[others[0]] = p0
					lo[others[1]] = p1; hi[others[1]] = p1
					lo[others[2]] = p2; hi[others[2]] = p2
					var v_lo: float = _sdf_at_grid_index(lo)
					var v_hi: float = _sdf_at_grid_index(hi)
					if (v_lo < 0.0) == (v_hi < 0.0):
						continue # Not a bipolar edge - no dual polyhedron here.

					var corner_vertex_indices := PackedInt32Array()
					corner_vertex_indices.resize(8)
					var complete := true
					for choice_index in range(8):
						var cell_coord := Vector4i(0, 0, 0, 0)
						cell_coord[axis] = e
						cell_coord[others[0]] = p0 - 1 + ((choice_index >> 2) & 1)
						cell_coord[others[1]] = p1 - 1 + ((choice_index >> 1) & 1)
						cell_coord[others[2]] = p2 - 1 + (choice_index & 1)
						if not dual_vertices.has(cell_coord):
							complete = false
							break
						corner_vertex_indices[choice_index] = dual_vertices[cell_coord]
					if not complete:
						continue

					hexahedra_attempted += 1
					var kept: int = _append_hexahedron(poly_mesh, corner_vertex_indices, vertex_heights, vertex_positions, cell_heights)
					if kept > 0:
						hexahedra_with_geometry += 1
					tets_kept += kept
					tets_skipped += _CUBE_TETRAHEDRA.size() - kept
	return Vector4i(hexahedra_attempted, hexahedra_with_geometry, tets_kept, tets_skipped)


## Splits one hexahedron (8 already-appended corner vertex indices, in
## standard cube corner order - index bit 2/1/0 = above/below along the
## hexahedron's own local "other axis" 0/1/2) into up to 6 tetrahedra via
## _CUBE_TETRAHEDRA, checking each independently with the same
## Basis4D.determinant() test ArrayPolyMesh4D itself uses, and only
## submitting the ones that pass. Relies on append_edge_indices' automatic
## deduplication so edges shared between tetrahedra (including the shared
## main diagonal every one of them touches) are only ever added once. Also
## records each kept tetrahedron's average corner height into
## `cell_heights`, in the same order cells get appended to `poly_mesh` -
## that ordering is what makes PER_CELL_ONLY coloring line up correctly in
## _apply_material.
##
## Returns how many of the 6 tetrahedra were kept (0 if this hexahedron
## truly has no valid volume anywhere - the one remaining case that still
## leaves a real gap).
func _append_hexahedron(poly_mesh: ArrayPolyMesh4D, corner_vertex_indices: PackedInt32Array, vertex_heights: PackedFloat64Array, vertex_positions: PackedVector4Array, cell_heights: PackedFloat64Array) -> int:
	var min_volume: float = pow(cell_size, 3) * DEGENERATE_VOLUME_FRACTION
	var kept := 0

	for tet in _CUBE_TETRAHEDRA:
		var local_indices := PackedInt32Array()
		for local_corner in tet:
			local_indices.append(corner_vertex_indices[local_corner])

		var p0: Vector4 = vertex_positions[local_indices[0]]
		var edge_x: Vector4 = vertex_positions[local_indices[1]] - p0
		var edge_y: Vector4 = vertex_positions[local_indices[2]] - p0
		var edge_z: Vector4 = vertex_positions[local_indices[3]] - p0
		var span_basis: Projection = Basis4D.from_xyz(edge_x, edge_y, edge_z)
		var determinant: float = Basis4D.determinant(span_basis)
		# is_nan() check is deliberately separate from the magnitude check,
		# not folded into one comparison: NaN compares false against
		# everything in IEEE floats, so "absf(determinant) < min_volume"
		# alone would let a NaN determinant slip through as if it were a
		# perfectly healthy, non-degenerate tetrahedron. This is a second
		# layer of defense on top of the is_finite() guard already applied
		# to vertex_pos in _try_add_cell_dual_vertex - belt and suspenders.
		if is_nan(determinant) or absf(determinant) < min_volume:
			continue # This one sliver is too thin (or broken) - skip it, not the whole hexahedron.

		var face_indices := PackedInt32Array()
		for face in _TET_FACES:
			var face_edges := PackedInt32Array()
			for i in range(3):
				var a: int = local_indices[face[i]]
				var b: int = local_indices[face[(i + 1) % 3]]
				face_edges.append(poly_mesh.append_edge_indices(a, b))
			face_indices.append(poly_mesh.append_poly_cell(2, face_edges))

		var average_height := 0.0
		for idx in local_indices:
			average_height += vertex_heights[idx]
		cell_heights.append(average_height / 4.0)

		poly_mesh.append_poly_cell(3, face_indices)
		kept += 1

	return kept
