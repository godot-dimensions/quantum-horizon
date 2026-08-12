@tool
extends Node4D
## Builds a volumetric 4D world by compositing signed-density layers, dual
## contouring the result, and handing the tetrahedra to two [MeshInstance4D]
## children (opaque ground and transparent water) plus optional collision.
##
## This is the port of the reference WebGL demo's pipeline onto Godot 4D. The
## demo's other half - slicing the 4D mesh down to a 3D cross-section in a
## vertex shader - is not ported because the engine already does exactly that
## in render/cross_section/tetra_cross_section_shader.glsl, by the same
## method. So the whole cost here is generation, paid once, and thereafter
## rotating through 4D is five uniform updates per frame.
##
## [b]Unlike[/b] the height-field generator in project/ramon/VoxelIsland/, this does
## not regenerate on every property change. A size^4 grid at size 14 is ~38k
## points and ~154k candidate edges, which is seconds of GDScript rather than
## milliseconds - auto-regenerating would make the inspector unusable. Set up
## the parameters, then press Generate.

const _SCRIPT_PATH_HINT := "res://ramon/voxel_port/scripts/"

## Hard ceiling on grid size. Cost grows as size^4 in memory and roughly
## size^3 in emitted geometry, so this is the difference between "a few
## seconds" and "the editor is gone". 20 matches the reference demo's default;
## 24 is already ~4x its grid.
const MAX_GRID_SIZE := 24

## Grid points per axis. 12-14 is the sweet spot for a first look: visually
## comparable to the reference demo at roughly a third of the geometry, which
## matters because the cross-section renderer disables frustum culling, so
## every tetrahedron is vertex-shaded every frame whether or not it intersects
## the current slice.
const BASELINE_GRID_SIZE := 12

## Model layer bits. The values matter: layers are composited in ascending bit
## order, so the bit order [b]is[/b] the layer order and no separate sort is
## needed. Water first so terrain can replace it where they overlap, solids
## next, and the carving layers last - a carve listed before a solid would just
## get filled back in.
##
## This is the one thing a checkbox list would otherwise lose compared to the
## reference demo's ordered comma-separated string, and encoding the order into
## the bits means it cannot be got wrong rather than merely being documented.
const MODEL_GLOBE_WATER := 1 << 0
const MODEL_PLANE_WATER := 1 << 1
const MODEL_GLOBE := 1 << 2
const MODEL_PLANE := 1 << 3
const MODEL_HYPERCUBE := 1 << 4
const MODEL_24CELL := 1 << 5
const MODEL_SPHERINDER := 1 << 6
const MODEL_CUTOFF := 1 << 7

## Bit index -> the name [method _add_model_layer] dispatches on. Must stay in
## the same order as the bits above and as the @export_flags hint.
const _MODEL_LAYER_NAMES: Array[String] = [
	"globewater",
	"planewater",
	"globe",
	"plane",
	"hypercube",
	"24cell",
	"spherinder",
	"cutoff",
]

const BASELINE_MODEL_LAYERS := MODEL_GLOBE_WATER | MODEL_GLOBE | MODEL_CUTOFF
const BASELINE_CELL_SIZE := 4.0
const BASELINE_NOISE_FREQUENCY := 0.12
const BASELINE_FRACTAL_OCTAVES := 3
const BASELINE_TERRAIN_SEED := 1

## How far to step when differencing the noise field for its gradient, in grid
## cells. The analytic models below (spheres, planes, hypercubes) supply exact
## gradients; only the noise term needs differencing, so this error is confined
## to the one term that has it rather than contaminating the whole surface
## normal the way differencing the composite density would.
const NOISE_GRADIENT_EPSILON := 0.01

## Normals from the noisy terrain layers are scaled down relative to the
## analytic ones. [QEFSolver4D] weights each crossing by its normal's
## magnitude, so this says "trust the exact sphere/plane boundary more than
## the noisy one when they meet in the same cell" - which stops noise from
## dragging an otherwise crisp shoreline off the analytic surface.
const NOISY_LAYER_CONFIDENCE := 0.5
const ANALYTIC_LAYER_CONFIDENCE := 1.0

## Edge length of the generated (slope, altitude) colour palette. 32 is plenty
## - it is sampled with linear filtering and the underlying gradient is smooth,
## so a larger texture would only store interpolation the GPU does for free.
const PALETTE_RESOLUTION := 32

enum TerrainShape {
	## Up is +Y everywhere; altitude is height above the mid-plane.
	PLANAR,
	## Up is radially outward from the grid center; altitude is distance from
	## it. This is what makes a hypersphere world shade correctly - "up" is a
	## different direction at every point on it.
	RADIAL,
}

@export_tool_button("Generate") var _generate_action: Callable = generate
@export_tool_button("Randomize Seed and Generate") var _randomize_action: Callable = randomize_and_generate
@export_tool_button("Clear") var _clear_action: Callable = clear

@export_group("Grid")
## Grid points per axis. The field is grid_size^4 points.
@export_range(4, MAX_GRID_SIZE, 1) var grid_size: int = BASELINE_GRID_SIZE
## World size of one grid cell, in meters. Total world footprint is
## grid_size * cell_size across each axis.
@export_range(0.25, 32.0, 0.25, "or_greater", "suffix:m") var cell_size: float = BASELINE_CELL_SIZE

@export_group("Model")
## Which layers to composite, ticked in the inspector. They are applied top to
## bottom in the order listed, which is also the order that makes sense - so
## the ordering trap the reference demo's comma-separated string has (put
## [code]cutoff[/code] first and it gets filled straight back in) cannot happen
## here.
##
## Combinations worth trying:
## [br]- Globe Water + Globe + Cutoff: an ocean planet (the default)
## [br]- Plane Water + Plane + Spherinder + Cutoff: the column from the
##   reference demo's own screenshot - set Terrain Shape to Planar and raise
##   Noise Amplitude Fraction to 0.4 to match it
## [br]- Hypercube + Cutoff, or 24-Cell + Cutoff: sharp-edge preservation on
##   its own, with no noise to hide behind
@export_flags("Globe Water", "Plane Water", "Globe", "Plane", "Hypercube", "24-Cell", "Spherinder", "Cutoff")
var model_layers: int = BASELINE_MODEL_LAYERS:
	set(value):
		model_layers = value
		update_configuration_warnings()
@export var terrain_seed: int = BASELINE_TERRAIN_SEED

@export_group("Noise")
@export_range(0.01, 1.0, 0.001, "or_greater") var noise_frequency: float = BASELINE_NOISE_FREQUENCY
@export_range(1, 8, 1) var fractal_octaves: int = BASELINE_FRACTAL_OCTAVES
@export_range(0.0, 1.0, 0.01) var fractal_gain: float = 0.5
## Noise height as a fraction of grid size. The reference demo uses 0.2 for
## the globe and 0.4 for the plane; this is applied to whichever is active.
##
## [b]Interacts with [code]cutoff[/code].[/b] The globe sits at radius
## 0.35 * grid_size and noise pushes peaks out to (0.35 + this) * grid_size,
## while [code]cutoff[/code] seals the world at an axis-aligned box whose
## nearest face is (grid_size / 2 - 1.1) from the globe's centre. Peaks past
## that get shaved flat against the boundary, which reads as suspiciously
## rectangular patches on the highest ground. Clipping is avoided when:
##
##     noise_amplitude_fraction <= 0.15 - 1.1 / grid_size
##
## which is ~0.058 at grid_size 12, ~0.095 at 20, ~0.104 at 24. The default of
## 0.2 is therefore over that line at every usable grid size - deliberately so,
## since the reference demo's own defaults clip the same way and the flat spots
## only appear where fBm actually approaches its extremes, which is rare. Lower
## it if you want a guaranteed-round planet; raise grid_size if you want tall
## peaks and no clipping, since the bound relaxes as the grid grows.
@export_range(0.0, 1.0, 0.01) var noise_amplitude_fraction: float = 0.2

@export_group("Appearance")
## Which way is "up", for slope shading and altitude banding. Set this to
## match the model - RADIAL for globe worlds, PLANAR for plane worlds.
@export var terrain_shape: TerrainShape = TerrainShape.RADIAL:
	set(value):
		terrain_shape = value
		update_configuration_warnings()
## Optional. When set, colouring switches from per-cell to a 3D texture
## indexed by (slope, altitude, material) - the reference demo's trick, which
## gets cliff/grass/snow banding out of a single lookup. When null, the
## equivalent colours are computed per tetrahedron in GDScript instead.
@export var albedo_texture_3d: Texture3D = null
@export var water_color: Color = Color(0.1, 0.25, 0.6, 0.75)
## Flip if the terrain renders inside-out - see [member DualContour4D.flip_winding].
@export var flip_winding: bool = false

@export_group("Physics")
## Builds a [ConcaveMeshShape4D] from the ground tetrahedra.
##
## [b]This does not currently give you terrain-shaped collision.[/b] The only
## physics engine the module ships is [code]AxisAlignedBoxPhysicsEngine4D[/code],
## whose own header states: "Non-BoxShape4D shapes will work, but will be
## converted to boxes." Every collision shape is reduced to a single [Rect4]
## bounding box, so all ~20,000 tetrahedra collapse into one box spanning the
## whole world - you can stand on its lid and walk off its edges, and it lines
## up with the terrain nowhere except by accident.
##
## Off by default for that reason: the resulting box is not merely useless but
## actively misleading, an invisible crate around the whole world that stops
## you walking up to the terrain you can plainly see. The ObservationFloor in
## voxel_port.tscn is a real BoxShape4D, which the AABB engine handles exactly,
## and is what you actually stand on.
##
## The code is kept, and kept as a mesh shape rather than a hand-made box,
## because the shape itself is correct and costs under a second to build - so
## it starts working the day the module gains a non-AABB engine, with no
## changes needed here. Turning it on today only makes sense for measuring
## generation cost.
@export var generate_collision: bool = false

## Set while [method _reset_defaults] reassigns exported values, so nothing
## tries to regenerate mid-reset.
var _suppress_regenerate := false

var _noise: FastNoiseLite
var _last_stats := {}
## Whether meshes existed when an editor save began, so the post-save rebuild
## only fires for scenes that actually had generated terrain.
var _had_meshes_before_save := false


## Builds the terrain as soon as the scene loads, in the editor as well as at
## runtime, so opening the scene shows the world rather than an empty node.
func _ready() -> void:
	var ground: MeshInstance4D = _get_ground_instance()
	if ground != null and ground.mesh == null:
		generate()


## Keeps the generated meshes out of the saved [code].tscn[/code].
##
## The meshes are ordinary resources assigned to an exported property, so Godot
## would happily serialize all ~28,000 tetrahedra into the scene file - the
## height-field test scene next door is 1.6 MB for exactly this reason, and
## this one would be far worse. Since everything here is reproducible from the
## exported parameters plus the seed, storing it is pure cost. Dropping the
## meshes immediately before a save and rebuilding right after keeps the scene
## file at a couple of hundred bytes.
func _notification(what: int) -> void:
	if not Engine.is_editor_hint():
		return
	match what:
		NOTIFICATION_EDITOR_PRE_SAVE:
			_had_meshes_before_save = _get_ground_instance() != null and _get_ground_instance().mesh != null
			clear()
		NOTIFICATION_EDITOR_POST_SAVE:
			if _had_meshes_before_save:
				generate()


func _get_ground_instance() -> MeshInstance4D:
	return get_node_or_null("Ground") as MeshInstance4D


func _get_water_instance() -> MeshInstance4D:
	return get_node_or_null("Water") as MeshInstance4D


func _get_collision_shape() -> CollisionShape4D:
	return get_node_or_null("StaticBody4D/CollisionShape4D") as CollisionShape4D


## The ticked layers, in composite order. Ascending bit order is the layer
## order by construction (see the MODEL_* constants), so this needs no sort.
func selected_model_names() -> PackedStringArray:
	var names := PackedStringArray()
	for bit in range(_MODEL_LAYER_NAMES.size()):
		if (model_layers & (1 << bit)) != 0:
			names.append(_MODEL_LAYER_NAMES[bit])
	return names


## Surfaces the configuration mistakes that are otherwise silent - they produce
## terrain that generates without error and simply looks wrong, which is far
## more expensive to notice than a failed build.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if model_layers == 0:
		warnings.append("No model layers selected - Generate will produce nothing.")
		return warnings

	var uses_plane: bool = (model_layers & (MODEL_PLANE | MODEL_PLANE_WATER)) != 0
	var uses_globe: bool = (model_layers & (MODEL_GLOBE | MODEL_GLOBE_WATER)) != 0
	if uses_plane and not uses_globe and terrain_shape == TerrainShape.RADIAL:
		warnings.append("Plane layers are selected but Terrain Shape is Radial, so \"up\" is treated as pointing away from the world centre. Slope and altitude colouring will be wrong. Set Terrain Shape to Planar.")
	if uses_globe and not uses_plane and terrain_shape == TerrainShape.PLANAR:
		warnings.append("Globe layers are selected but Terrain Shape is Planar, so \"up\" is treated as +Y everywhere instead of radially outward. Slope and altitude colouring will be wrong. Set Terrain Shape to Radial.")

	if (model_layers & MODEL_CUTOFF) == 0:
		warnings.append("Cutoff is not selected. Any surface reaching the edge of the grid ends in a ragged open hole, because cells on the boundary are skipped during contouring. Only safe for models that sit comfortably inside the grid.")

	var has_solid: bool = (model_layers & (MODEL_GLOBE | MODEL_PLANE | MODEL_HYPERCUBE | MODEL_24CELL)) != 0
	if not has_solid and (model_layers & (MODEL_GLOBE_WATER | MODEL_PLANE_WATER)) != 0:
		warnings.append("Water is selected with no solid layer, so there is nothing for it to form a shoreline against.")

	return warnings


func randomize_and_generate() -> void:
	terrain_seed = randi()
	generate()


func clear() -> void:
	var ground: MeshInstance4D = _get_ground_instance()
	if ground != null:
		ground.mesh = null
	var water: MeshInstance4D = _get_water_instance()
	if water != null:
		water.mesh = null
	var collision: CollisionShape4D = _get_collision_shape()
	if collision != null:
		collision.shape = null


func generate() -> void:
	var ground_instance: MeshInstance4D = _get_ground_instance()
	if ground_instance == null:
		push_error("VoxelTerrain4D: expected a MeshInstance4D child named 'Ground'.")
		return

	var clamped_size: int = clampi(grid_size, 4, MAX_GRID_SIZE)
	if clamped_size != grid_size:
		push_warning("VoxelTerrain4D: grid_size clamped to %d." % clamped_size)

	var start_usec: int = Time.get_ticks_usec()
	_setup_noise()

	var field := VoxelField4D.new(clamped_size)
	var requested_models: PackedStringArray = selected_model_names()
	if requested_models.is_empty():
		push_warning("VoxelTerrain4D: no model layers selected, nothing to generate.")
		return
	for model_name in requested_models:
		if not _add_model_layer(field, model_name, clamped_size):
			push_warning("VoxelTerrain4D: unknown model '%s', skipped." % model_name)
	var field_usec: int = Time.get_ticks_usec() - start_usec

	var contour := DualContour4D.new(field)
	contour.flip_winding = flip_winding
	contour.generate()
	var total_usec: int = Time.get_ticks_usec() - start_usec

	var center: float = float(clamped_size - 1) * 0.5
	ground_instance.mesh = _build_mesh(contour, contour.ground_cells, center, false)
	var water_instance: MeshInstance4D = _get_water_instance()
	if water_instance != null:
		water_instance.mesh = _build_mesh(contour, contour.water_cells, center, true)

	_update_collision(contour, center)

	_last_stats = contour.stats.duplicate()
	_last_stats["grid_points"] = field.point_count()
	_last_stats["field_ms"] = field_usec / 1000.0
	_last_stats["total_ms"] = total_usec / 1000.0
	_print_stats()


func _print_stats() -> void:
	var ground_tetrahedra: int = _last_stats.get("ground_tetrahedra", 0)
	var water_tetrahedra: int = _last_stats.get("water_tetrahedra", 0)
	var total_tetrahedra: int = ground_tetrahedra + water_tetrahedra
	# 6 cross-section vertices per tetrahedron, each carrying all four corner
	# positions plus texture data - see TetraMesh4D::update_cross_section_mesh.
	var approximate_megabytes: float = float(total_tetrahedra) * 6.0 * 120.0 / (1024.0 * 1024.0)
	print("[VoxelTerrain4D] %d grid points -> %d crossings -> %d vertices -> %d tets (%d ground / %d water)" % [
		_last_stats.get("grid_points", 0),
		_last_stats.get("crossing_edges", 0),
		_last_stats.get("vertices", 0),
		total_tetrahedra,
		ground_tetrahedra,
		water_tetrahedra,
	])
	print("[VoxelTerrain4D] %d broken tets dropped, %d open boundary edges, ~%.1f MB of cross-section mesh" % [
		_last_stats.get("tetrahedra_degenerate", 0),
		_last_stats.get("hexahedra_incomplete", 0),
		approximate_megabytes,
	])
	if generate_collision:
		print("[VoxelTerrain4D] collision uses %d of %d ground tets (%d too thin to invert) - NOTE: AxisAlignedBoxPhysicsEngine4D reduces this to a single bounding box" % [
			_last_stats.get("collision_tetrahedra", 0),
			ground_tetrahedra,
			_last_stats.get("tetrahedra_too_thin_for_collision", 0),
		])
	print("[VoxelTerrain4D] field %.0f ms, total %.0f ms" % [
		_last_stats.get("field_ms", 0.0),
		_last_stats.get("total_ms", 0.0),
	])


func _setup_noise() -> void:
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.seed = terrain_seed
	_noise.frequency = noise_frequency
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = fractal_octaves
	_noise.fractal_gain = fractal_gain


## FastNoiseLite only samples up to 3D, so the fourth axis is folded in by
## offsetting the other three by it. That is a real approximation - the result
## is not isotropic in 4D the way genuine 4D noise would be - but it is
## continuous and seedless-of-artifacts at these frequencies, and it keeps the
## noise term to one cheap call. Swapping in a true 4D noise with an analytic
## gradient is the natural upgrade here, and would let _noise_gradient stop
## differencing entirely.
func _noise_value(p: Vector4) -> float:
	return _noise.get_noise_3d(p.x + p.w * 1.7, p.y - p.w * 1.3, p.z + p.w * 2.1)


func _noise_gradient(p: Vector4) -> Vector4:
	var e: float = NOISE_GRADIENT_EPSILON
	var gradient := Vector4.ZERO
	for axis in range(4):
		var ahead: Vector4 = p
		var behind: Vector4 = p
		ahead[axis] += e
		behind[axis] -= e
		gradient[axis] = (_noise_value(ahead) - _noise_value(behind)) / (2.0 * e)
	return gradient


func _add_model_layer(field: VoxelField4D, model_name: String, size: int) -> bool:
	var center := Vector4(1, 1, 1, 1) * (float(size) * 0.5)
	var noise_amplitude: float = noise_amplitude_fraction * float(size)

	match model_name:
		"globe":
			var radius: float = float(size) * 0.35
			field.add_layer(
				VoxelField4D.VoxelMaterial.GROUND,
				func(p: Vector4) -> float:
					return noise_amplitude * _noise_value(p) + radius - (p - center).length(),
				func(p: Vector4) -> Vector4:
					var offset: Vector4 = center - p
					var length: float = offset.length()
					var radial: Vector4 = Vector4.ZERO if is_zero_approx(length) else offset / length
					return _noise_gradient(p) * noise_amplitude + radial,
				NOISY_LAYER_CONFIDENCE)
			return true

		"globewater":
			var water_radius: float = float(size) * 0.37
			field.add_layer(
				VoxelField4D.VoxelMaterial.WATER,
				func(p: Vector4) -> float:
					return water_radius - (p - center).length(),
				func(p: Vector4) -> Vector4:
					var offset: Vector4 = center - p
					var length: float = offset.length()
					return Vector4.ZERO if is_zero_approx(length) else offset / length,
				ANALYTIC_LAYER_CONFIDENCE)
			return true

		"plane":
			var plane_height: float = float(size) * 0.5
			field.add_layer(
				VoxelField4D.VoxelMaterial.GROUND,
				func(p: Vector4) -> float:
					return noise_amplitude * _noise_value(p) + plane_height - p.y,
				func(p: Vector4) -> Vector4:
					return _noise_gradient(p) * noise_amplitude + Vector4(0, -1, 0, 0),
				NOISY_LAYER_CONFIDENCE)
			return true

		"planewater":
			var water_level: float = float(size) * 0.5
			field.add_layer(
				VoxelField4D.VoxelMaterial.WATER,
				func(p: Vector4) -> float:
					return water_level - p.y,
				func(_p: Vector4) -> Vector4:
					return Vector4(0, -1, 0, 0),
				ANALYTIC_LAYER_CONFIDENCE)
			return true

		"spherinder":
			# Carves away everything outside a sphere in x/z/w, leaving the
			# vertical axis untouched - a cylinder one dimension up.
			var column_radius: float = float(size) * 0.5 - 1.0
			field.add_layer(
				VoxelField4D.VoxelMaterial.AIR,
				func(p: Vector4) -> float:
					var radial := Vector3(p.x - center.x, p.z - center.z, p.w - center.w)
					return radial.length() - column_radius,
				func(p: Vector4) -> Vector4:
					var radial := Vector3(p.x - center.x, p.z - center.z, p.w - center.w)
					if is_zero_approx(radial.length()):
						return Vector4(1, 0, 0, 0)
					radial = radial.normalized()
					return Vector4(radial.x, 0.0, radial.y, radial.z),
				ANALYTIC_LAYER_CONFIDENCE)
			return true

		"cutoff":
			# Seals the outermost shell of the grid. Dual contouring skips
			# cells that would need out-of-bounds neighbors, so without this
			# any surface reaching the boundary ends in a ragged open edge.
			var high_limit: float = float(size) - 1.1
			var low_limit := 0.1
			field.add_layer(
				VoxelField4D.VoxelMaterial.AIR,
				func(p: Vector4) -> float:
					var highest: float = maxf(maxf(p.x, p.y), maxf(p.z, p.w)) - high_limit
					var lowest: float = low_limit - minf(minf(p.x, p.y), minf(p.z, p.w))
					return maxf(highest, lowest),
				func(p: Vector4) -> Vector4:
					var best_axis := 0
					var best_value: float = -INF
					var best_sign := 1.0
					for axis in range(4):
						var above: float = p[axis] - high_limit
						if above > best_value:
							best_value = above
							best_axis = axis
							best_sign = 1.0
						var below: float = low_limit - p[axis]
						if below > best_value:
							best_value = below
							best_axis = axis
							best_sign = -1.0
					var gradient := Vector4.ZERO
					gradient[best_axis] = best_sign
					return gradient,
				ANALYTIC_LAYER_CONFIDENCE)
			return true

		"hypercube":
			var rotation: Projection = _random_rotation()
			# The rotation is orthonormal, so its inverse is its transpose -
			# which is what maps a face normal in the hypercube's own frame back
			# into world space. Projection exposes inverse() but not
			# transposed(), so take that route.
			var inverse_rotation: Projection = rotation.inverse()
			var half_extent: float = float(size) * 0.25
			field.add_layer(
				VoxelField4D.VoxelMaterial.GROUND,
				func(p: Vector4) -> float:
					var local: Vector4 = rotation * (p - center)
					var largest: float = maxf(maxf(absf(local.x), absf(local.y)), maxf(absf(local.z), absf(local.w)))
					return half_extent - largest,
				func(p: Vector4) -> Vector4:
					var local: Vector4 = rotation * (p - center)
					var best_axis := 0
					var best_value: float = -1.0
					for axis in range(4):
						if absf(local[axis]) > best_value:
							best_value = absf(local[axis])
							best_axis = axis
					var face_normal := Vector4.ZERO
					face_normal[best_axis] = signf(local[best_axis])
					return inverse_rotation * face_normal,
				ANALYTIC_LAYER_CONFIDENCE)
			return true

		"24cell":
			# The 24-cell is the intersection of a hypercube and a
			# hyper-octahedron, so its density is the tighter of the two
			# constraints and its gradient is whichever one is currently
			# binding. It has no 3D analogue, which makes it a good check that
			# sharp features survive the QEF solve.
			var cell_radius: float = float(size) * 0.5 - 2.5
			field.add_layer(
				VoxelField4D.VoxelMaterial.GROUND,
				func(p: Vector4) -> float:
					var d: Vector4 = p - center
					var absolute := Vector4(absf(d.x), absf(d.y), absf(d.z), absf(d.w))
					var octahedral: float = (absolute.x + absolute.y + absolute.z + absolute.w) * 0.5
					var cubic: float = maxf(maxf(absolute.x, absolute.y), maxf(absolute.z, absolute.w))
					return cell_radius - maxf(cubic, octahedral),
				func(p: Vector4) -> Vector4:
					var d: Vector4 = p - center
					var absolute := Vector4(absf(d.x), absf(d.y), absf(d.z), absf(d.w))
					var binding: float = (absolute.x + absolute.y + absolute.z + absolute.w) * 0.5
					var gradient := Vector4(-signf(d.x), -signf(d.y), -signf(d.z), -signf(d.w)) * 0.5
					for axis in range(4):
						if absolute[axis] > binding:
							binding = absolute[axis]
							gradient = Vector4.ZERO
							gradient[axis] = -signf(d[axis])
					return gradient,
				ANALYTIC_LAYER_CONFIDENCE)
			return true

	return false


## A uniformly-ish random 4D rotation, by Gram-Schmidt on gaussian columns.
## Gaussian rather than uniform because a gaussian vector's direction is
## isotropic, so orthonormalizing four of them gives no preferred axis.
func _random_rotation() -> Projection:
	var generator := RandomNumberGenerator.new()
	generator.seed = terrain_seed
	var columns: Array[Vector4] = []
	while columns.size() < 4:
		var candidate := Vector4(
			generator.randfn(), generator.randfn(), generator.randfn(), generator.randfn())
		for existing in columns:
			candidate -= existing * candidate.dot(existing)
		var length: float = candidate.length()
		if length < 1e-4:
			continue # Landed nearly inside the span already covered; redraw.
		columns.append(candidate / length)
	return Projection(columns[0], columns[1], columns[2], columns[3])


## Builds one [ArrayTetraMesh4D] from a subset of the contoured tetrahedra.
##
## Note this appends tetrahedra directly rather than going through the
## polytope hierarchy (edges -> faces -> cells) that the height-field
## generator uses. These are already simplices, so the polytope form buys
## nothing and costs ~11 deduplicating appends per tetrahedron instead of one -
## and PolyMesh4D would only decompose them straight back into simplices to
## render anyway.
func _build_mesh(contour: DualContour4D, cells: PackedInt32Array, center: float, is_water: bool) -> ArrayTetraMesh4D:
	if cells.is_empty():
		return null

	var mesh := ArrayTetraMesh4D.new()
	var remap := {}
	var texture_map := PackedVector3Array()

	for i in range(0, cells.size(), 4):
		var indices := PackedInt32Array()
		indices.resize(4)
		for corner in range(4):
			var source_index: int = cells[i + corner]
			var mapped_index: int
			if remap.has(source_index):
				mapped_index = remap[source_index]
			else:
				var grid_position: Vector4 = contour.vertices[source_index]
				var world_position: Vector4 = (grid_position - Vector4(center, center, center, center)) * cell_size
				mapped_index = mesh.append_vertex(world_position, false)
				remap[source_index] = mapped_index
			indices[corner] = mapped_index

		mesh.append_tetra_cell_indices(indices[0], indices[1], indices[2], indices[3])

		# One UVW per tetrahedron corner, in the same order the corners were
		# appended - TetraMesh4D requires the texture map to be exactly as long
		# as the cell position list, which is 4 entries per cell.
		for corner in range(4):
			var source_index: int = cells[i + corner]
			var grid_position: Vector4 = contour.vertices[source_index]
			texture_map.append(Vector3(
				_slope_at(grid_position, contour.vertex_normals[source_index], center),
				_altitude_at(grid_position, center),
				0.5))

	# Only two colour sources actually reach the cross-section shader:
	# TetraMaterial4D::update_cross_section_material sets exactly two uniforms,
	# `albedo` (from albedo_color, and only when the SINGLE_COLOR flag is set)
	# and `albedo_texture` (only when the TEXTURE3D_CELL_UVW flag is set).
	# albedo_color_array is never consulted for tetrahedral meshes at all, so
	# PER_CELL and PER_VERT both silently render pure white - the shader simply
	# has no per-cell colour attribute to read.
	var material := TetraMaterial4D.new()
	if is_water:
		material.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_SINGLE_COLOR
		material.albedo_color = water_color
	else:
		mesh.simplex_cell_texture_map = texture_map
		material.albedo_texture_3d = albedo_texture_3d if albedo_texture_3d != null else _build_palette_texture()
		material.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_TEXTURE3D_CELL_UVW_ONLY
	mesh.material = material
	return mesh


## Bakes [method _ground_color] into a 3D texture indexed by (slope, altitude).
##
## This is the reference demo's trick, and on this renderer it is not merely
## the nicer option but the only one available for varying colour across a
## surface - see the note in [method _build_mesh]. Depth is 1 because both
## inputs fit in the first two axes; the third UVW component is unused and the
## sampler clamps it.
func _build_palette_texture() -> ImageTexture3D:
	var image: Image = Image.create_empty(PALETTE_RESOLUTION, PALETTE_RESOLUTION, false, Image.FORMAT_RGB8)
	for y in range(PALETTE_RESOLUTION):
		var altitude: float = float(y) / float(PALETTE_RESOLUTION - 1)
		for x in range(PALETTE_RESOLUTION):
			var slope: float = float(x) / float(PALETTE_RESOLUTION - 1)
			image.set_pixel(x, y, _ground_color(slope, altitude))
	var texture := ImageTexture3D.new()
	texture.create(Image.FORMAT_RGB8, PALETTE_RESOLUTION, PALETTE_RESOLUTION, 1, false, [image])
	return texture


## Slope as 0 (facing straight up) to 1 (vertical wall or overhang), from the
## angle between the surface normal and local "up".
func _slope_at(grid_position: Vector4, normal: Vector4, center: float) -> float:
	if normal.length_squared() < 1e-8:
		return 0.0
	var up: Vector4 = _up_at(grid_position, center)
	return clampf(1.0 - absf(normal.dot(up)), 0.0, 1.0)


func _up_at(grid_position: Vector4, center: float) -> Vector4:
	if terrain_shape == TerrainShape.PLANAR:
		return Vector4(0, 1, 0, 0)
	var outward: Vector4 = grid_position - Vector4(center, center, center, center)
	var length: float = outward.length()
	return Vector4(0, 1, 0, 0) if is_zero_approx(length) else outward / length


## Normalized height in [0, 1] across the world, for altitude banding.
func _altitude_at(grid_position: Vector4, center: float) -> float:
	var span: float = maxf(center, 0.001)
	if terrain_shape == TerrainShape.PLANAR:
		return clampf(grid_position.y / (span * 2.0), 0.0, 1.0)
	var radius: float = (grid_position - Vector4(center, center, center, center)).length()
	return clampf(radius / span, 0.0, 1.0)


## Sand at the waterline, grass above it, rock on anything steep, snow at the
## top. The reference demo gets this from a single 2D texture lookup indexed by
## exactly these two values; assigning an [member albedo_texture_3d] switches
## to that path.
func _ground_color(slope: float, altitude: float) -> Color:
	const SAND := Color(0.76, 0.70, 0.50)
	const GRASS := Color(0.28, 0.52, 0.24)
	const ROCK := Color(0.42, 0.40, 0.38)
	const SNOW := Color(0.92, 0.94, 0.96)

	var base: Color
	if altitude < 0.45:
		base = SAND.lerp(GRASS, clampf(altitude / 0.45, 0.0, 1.0))
	elif altitude < 0.8:
		base = GRASS.lerp(ROCK, clampf((altitude - 0.45) / 0.35, 0.0, 1.0))
	else:
		base = ROCK.lerp(SNOW, clampf((altitude - 0.8) / 0.2, 0.0, 1.0))
	return base.lerp(ROCK, clampf((slope - 0.35) / 0.4, 0.0, 1.0))


## Builds collision from the well-conditioned subset of the ground tetrahedra
## rather than from the finished mesh.
##
## [method ConcaveMeshShape4D.create_from_mesh] would take the mesh whole, and
## a single sliver in it fails the entire shape - which on flat-faceted models
## is close to guaranteed. Feeding [method ConcaveMeshShape4D.set_simplex_cells]
## the filtered subset directly keeps the visible mesh complete while giving
## the physics side only what it can actually invert. The excluded tetrahedra
## are too thin to have meaningfully contributed a collision surface anyway.
func _update_collision(contour: DualContour4D, center: float) -> void:
	var collision_shape: CollisionShape4D = _get_collision_shape()
	if collision_shape == null:
		return
	if not generate_collision or contour.ground_collision_cells.is_empty():
		collision_shape.shape = null
		return

	var offset := Vector4(center, center, center, center)
	var simplex_cells := PackedVector4Array()
	simplex_cells.resize(contour.ground_collision_cells.size())
	for i in range(contour.ground_collision_cells.size()):
		var vertex_index: int = contour.ground_collision_cells[i]
		simplex_cells[i] = (contour.vertices[vertex_index] - offset) * cell_size

	var shape := ConcaveMeshShape4D.new()
	shape.set_simplex_cells(simplex_cells)
	collision_shape.shape = shape
