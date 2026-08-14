class_name CloudsLayer
extends MeshInstance3D
## Ordinary Godot 3D plane, deliberately outside the 4D Cross-section
## pipeline - same "doesn't need to be 4D" convention as the HUD. No
## Node4D/tet-mesh cost. Renders through the same viewport/camera as
## everything else via a standard spatial shader (see clouds.gdshader).
##
## Footprint (size) comes from the terrain's own nominal grid_size *
## cell_size - this already tracks the terrain's edges well (see the
## conversation this was built in) and, importantly, stays a large, stable
## value throughout brick streaming. HEIGHT instead comes from the terrain's
## ACTUAL generated surface geometry (Ground/<brick>.mesh vertices - same
## source poi_spawner.gd already reads, see that script's own header on why:
## no raycast available, no separately-callable height function either),
## per an explicit request to float the deck a fixed margin above the
## highest real voxel rather than a fraction of the footprint (which put
## clouds absurdly high/low whenever grid_size changed).
##
## Deliberately NOT using the scanned bounds for the footprint too: only a
## fraction of the terrain's bricks may have streamed in at any given
## moment, so the scanned XZ extent can be far smaller than the terrain's
## eventual real size - and a small footprint combined with this deck's
## typical height (tens of units, once height_margin_voxels * cell_size is
## added on top of a real peak) hits a reproducible Godot rendering cliff
## (confirmed empirically this session: identical shader/material, a ~40-unit
## plane at height ~29 renders nothing from ANY camera angle tested, while
## the same plane at height ~10, or a ~70+-unit plane at height ~29, both
## render fine - some engine-level interaction between small size and large
## height for a thin transparent quad, not chased further).
##
## The nominal grid_size * cell_size formula alone does NOT reliably dodge
## that cliff either, though: this project's own default terrain settings
## (BASELINE_GRID_SIZE 12 * BASELINE_CELL_SIZE 4.0 = 48) land well inside the
## same failing range, confirmed directly - clouds were invisible in exactly
## this way the first time this fix was tried live, in the plain default
## scene, not just a synthetic small-grid test. FOOTPRINT_TO_HEIGHT_MIN_RATIO
## below is a floor on top of the nominal formula, tying the minimum
## footprint to the deck's own height instead of a bare magic number, since
## height (not size alone) is the other half of whatever this cliff actually
## is - both confirmed-safe empirical points (footprint 70 & 96 at height
## ~28.6) sit at ratio >= 2.45; 3.0 keeps real margin past that boundary
## without being tied to one specific grid_size/cell_size combination.
##
## A semi-transparent deck seen mostly from above, like a real cloud layer
## photographed from a plane window, not a full sky dome. RADIAL (globe)
## terrains are not specially handled - deliberately out of scope for now,
## see the conversation this was built in; the plane still renders, just
## without trying to fit a sphere's silhouette.
##
## Real 4D volumetric clouds were explicitly ruled out as too expensive, but
## the cloud pattern should still respond to the current 4D slice rotation
## as a genuine tilted cross-section (not just a uniform shift) - see
## clouds.gdshader's own header for the derivation (it reuses the same
## ana_offset-style projection this project already uses for real 4D points
## elsewhere, e.g. bearing_utility_4d.gd).

## How many WORLD UNITS above the highest currently-generated surface point
## the cloud deck floats - a real margin off real geometry rather than a
## fraction of a nominal footprint. Deliberately a flat world-unit value,
## NOT multiplied by cell_size: an earlier version scaled it by cell_size
## ("N voxel heights"), which put the deck absurdly far above the terrain
## for any coarse-celled bake (e.g. cell_size 4.0 turned a margin of 5 into
## 20 world units - visibly "in the sky" rather than hugging the surface,
## per direct visual feedback/annotated screenshot). A flat margin keeps the
## deck close to the surface regardless of the terrain's own voxel scale.
@export var height_margin: float = 3.0
## The Node4D whose basis carries the xw/zw rotation - typically the same
## node right-drag rotates (see voxel_hover_camera_4d.gd's rig_path). This is
## the authoritative "how far has the 4D slice rotated" state; there is no
## separate copy of it to keep in sync.
@export var rig_path: NodePath
## The VoxelTerrain4D to size/position this layer against.
@export var terrain_path: NodePath

## See this script's own header for where this ratio comes from.
const FOOTPRINT_TO_HEIGHT_MIN_RATIO := 3.0

var _material: ShaderMaterial
var _plane_mesh: PlaneMesh
## The expensive part (scanning every generated brick's full vertex array
## for its highest point) only re-runs when this changes - checking the
## child count itself is a cheap O(1) property read, safe to do every frame.
## Bricks stream in/out rather than mutating in place, so a chunk-count
## change is exactly the terrain's own signal that the highest point may
## have changed.
var _last_ground_chunk_count: int = -1
var _last_fitted_footprint: float = -1.0
## The deck's current height above world origin - tracked separately from
## the terrain scan itself so the footprint floor (which depends on height)
## can be recomputed every frame alongside the cheap nominal-footprint check,
## without re-scanning terrain geometry every frame too.
var _current_height: float = 0.0


func _ready() -> void:
	if mesh == null:
		mesh = PlaneMesh.new()
	_plane_mesh = mesh as PlaneMesh
	if _plane_mesh != null and _plane_mesh.material is ShaderMaterial:
		_material = _plane_mesh.material


func _get_terrain() -> Node:
	return get_node_or_null(terrain_path)


## The terrain's actual highest currently-generated surface point, scanning
## Ground/<brick>.mesh vertices directly (same source and same "no transform
## needed, already terrain-local" reasoning as poi_spawner.gd's
## _collect_surface_points_local - see that script's own header). Returns
## -INF if there is nothing generated yet.
func _scan_max_height(terrain: Node) -> float:
	var ground: Node = terrain.get_node_or_null("Ground")
	if ground == null or ground.get_child_count() == 0:
		return -INF

	var max_y := -INF
	for chunk in ground.get_children():
		if not (chunk is MeshInstance4D) or not (chunk.mesh is ArrayTetraMesh4D):
			continue
		var verts: PackedVector4Array = (chunk.mesh as ArrayTetraMesh4D).get_vertices()
		for v in verts:
			max_y = maxf(max_y, v.y)

	return max_y


func _refit_to_terrain(terrain: Node) -> void:
	if _plane_mesh == null:
		return
	var cell_size: float = float(terrain.cell_size) if "cell_size" in terrain else 1.0

	# Height: re-scan whenever the Ground's child count changes (bricks
	# streaming in can only raise the highest point, never silently lower
	# it without a chunk-count change of their own).
	var ground: Node = terrain.get_node_or_null("Ground")
	var chunk_count: int = ground.get_child_count() if ground != null else 0
	if chunk_count != 0 and chunk_count != _last_ground_chunk_count:
		_last_ground_chunk_count = chunk_count
		var max_y: float = _scan_max_height(terrain)
		if not is_inf(max_y):
			_current_height = max_y + height_margin
			position = Vector3(0.0, _current_height, 0.0)

	# Footprint: the nominal grid_size * cell_size formula, floored against
	# the deck's own height - see this script's own header for both why the
	# scanned bounds are deliberately NOT used here, and why the floor is
	# necessary even with the nominal formula alone. Cheap, so re-evaluated
	# every frame (not gated on chunk_count) since _current_height can change
	# independently of the nominal formula.
	var nominal_footprint: float = float(terrain.grid_size) * cell_size
	var footprint: float = maxf(nominal_footprint, _current_height * FOOTPRINT_TO_HEIGHT_MIN_RATIO)
	if not is_equal_approx(footprint, _last_fitted_footprint):
		_last_fitted_footprint = footprint
		_plane_mesh.size = Vector2(footprint, footprint)


func _process(_delta: float) -> void:
	var terrain: Node = _get_terrain()
	if terrain != null:
		_refit_to_terrain(terrain)

	# Identity default (basis_x=(1,0,0,0), basis_z=(0,0,1,0)) matches the
	# shader's own defaults - the zero-rotation, untilted case.
	var basis_x := Vector4(1.0, 0.0, 0.0, 0.0)
	var basis_z := Vector4(0.0, 0.0, 1.0, 0.0)
	if not rig_path.is_empty():
		var rig: Node4D = get_node_or_null(rig_path)
		if rig != null:
			# rig.basis is a Projection (4x4) built by
			# Basis4D.from_xw(...) * Basis4D.from_zw(...) - pushed wholesale
			# so the shader can compute the FULL local = world.x*basis_x +
			# world.z*basis_z transform per-fragment (both the in-plane
			# rotation/foreshortening AND the depth-into-volume term - see
			# clouds.gdshader's own header for the derivation).
			var rig_basis: Projection = rig.basis
			basis_x = rig_basis.x
			basis_z = rig_basis.z

	if _material != null:
		_material.set_shader_parameter("basis_x", basis_x)
		_material.set_shader_parameter("basis_z", basis_z)
		# Half the current footprint - see clouds.gdshader's own comment on
		# coverage_radius for why this exists (keeps the visible cloud mass
		# concentrated over the terrain instead of smearing to the horizon).
		_material.set_shader_parameter("coverage_radius", _last_fitted_footprint * 0.5)
