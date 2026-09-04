class_name CloudsLayer
extends MeshInstance4D
## A single REAL 4D object - a subdivided box mesh (SubdividedBoxTetraMesh4D,
## not the engine's own BoxTetraMesh4D - see that class's own header for
## why), meant to be a child of Terrain - rendered through the engine's own
## Cross-Section pipeline, the SAME pipeline that slices the terrain itself.
## See clouds.gdshader's own header for the full rationale; short version:
## an earlier version used an ordinary flat MeshInstance3D plane outside the
## 4D pipeline entirely, on the theory that "genuinely 4D" meant "one 4D
## object per cloud" and that was too expensive - that was a misreading. The
## actual performance concern was dozens of INDIVIDUAL 4D cloud objects, not
## 4D-ness itself. A single subdivided slab sized to the terrain's footprint
## still costs only a few thousand tetrahedra (a couple of terrain bricks'
## worth, not dozens of objects), and gets the SAME correct-from-any-angle
## cross-section shape terrain itself has "for free," instead of fighting
## an ordinary flat plane's inherent edge-on perspective problems with
## fade hacks (tried and abandoned this session: a world-space radial fade
## and a view-angle fade both treated symptoms of "wrong shape," not the
## cause).
##
## Subdivided rather than a plain BoxTetraMesh4D specifically because a
## coarse box (BoxTetraMesh4D's own fixed ~40-48 cell decomposition, no
## subdivision option at all) showed real, confirmed banding in the noise
## at certain 4D rotations - see SubdividedBoxTetraMesh4D's own header for
## the full root-cause story.
##
## Must be parented directly under the terrain's own Node4D (identity
## basis on this node) rather than given a rig_path override of its own -
## slicing is keyed off THIS node's global_transform relative to the
## camera (see CrossSectionRenderingEngine4D / RenderingEngine4D in the
## engine source), so a child with identity basis under a rotating parent
## picks up that rotation automatically, exactly like Ground/Water/POIs
## already do (see poi_spawner.gd's own header for this same convention).
##
## Footprint (X/Z size) comes from the terrain's own nominal grid_size *
## cell_size - tracks the terrain's edges well and stays large/stable
## throughout brick streaming (an earlier attempt to instead use scanned
## real bounds shrank badly during partial generation - see git history).
## thickness_y gives the slab real volume in Y (avoids the "vanishing
## on-screen area at oblique angles" problem an ordinary flat plane had).
## The 4th-dimension extent is set equal to footprint, NOT independently -
## an earlier version used a separate, arbitrary depth_w export (24, picked
## with no basis), and the box's cross-section shape visibly diverged from
## the terrain's own under rotation as a direct result: the terrain's real
## 4D field has the SAME extent in W as it does in X/Z, and how much of a
## shape's footprint a given rotation exposes depends on how much W-extent
## it has to rotate through - two differently-proportioned 4D shapes sliced
## by the same rotation reveal different amounts/shapes, confirmed directly
## via an annotated screenshot showing the two bounding boxes diverging.
## Matching W to footprint makes clouds a proportionally identical 4D shape
## to the terrain's own conceptual extent, so they slice into matching
## outlines under any rotation.
##
## Height comes from the terrain's ACTUAL generated surface geometry
## (Ground/<brick>.mesh vertices - same source poi_spawner.gd reads, see
## that script's own header on why: no raycast available, no separately-
## callable height function either), floated height_margin world units
## above the highest real point - a flat margin, deliberately NOT scaled by
## cell_size (an earlier version did that and put the deck absurdly high
## above any coarse-celled terrain).

@export var height_margin: float = 3.0
## Real thickness in Y - see this script's own header for why this needs to
## be nonzero. (The 4th-dimension extent is derived from footprint, not
## independently configurable - see this script's own header.)
@export var thickness_y: float = 4.0
## Target sub-cell edge length for SubdividedBoxTetraMesh4D - see that
## class's own header. Smaller = less banding but more tetrahedra; the
## thin Y axis (thickness_y) naturally gets little/no subdivision from this
## same value since it derives subdivision count from actual axis extent.
@export var target_cell_size: float = 8.0
## The VoxelTerrain4D to size/position this layer against. Left unset,
## defaults to this node's own parent - the expected case, since this node
## should be a direct child of Terrain (see this script's own header on
## why identity-basis parenting matters for slicing).
@export var terrain_path: NodePath

const CLOUD_SHADER: Shader = preload("res://scripts/clouds.gdshader")
const NOISE_ATLAS: Texture2D = preload("res://textures/clouds_noise_volume_atlas.png")

var _material: ShaderMaterial
## The expensive part (scanning every generated brick's full vertex array
## for its highest point) only re-runs when this changes - checking the
## child count itself is a cheap O(1) property read, safe to do every
## frame. Bricks stream in/out rather than mutating in place, so a
## chunk-count change is exactly the terrain's own signal that the highest
## point may have changed.
var _last_ground_chunk_count: int = -1
var _last_fitted_footprint: float = -1.0


func _ready() -> void:
	if not (material_override is TetraMaterial4D):
		material_override = TetraMaterial4D.new()
	var tetra_mat: TetraMaterial4D = material_override

	# get_cross_section_material_3d() only auto-assigns the engine's default
	# shader if this slot is still null (see TetraMaterial4D::
	# update_cross_section_material() in the engine source) - assigning
	# ours here makes it stick permanently, confirmed directly this
	# session with an isolated test object before building this for real.
	_material = tetra_mat.get_cross_section_material_3d()
	_material.shader = CLOUD_SHADER
	_material.set_shader_parameter("noise_volume_atlas", NOISE_ATLAS)


func _get_terrain() -> Node:
	if not terrain_path.is_empty():
		return get_node_or_null(terrain_path)
	return get_parent()


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
		var verts: PackedVector4Array = (chunk.mesh as ArrayTetraMesh4D).get_vertex_positions()
		for v in verts:
			max_y = maxf(max_y, v.y)

	return max_y


func _refit_to_terrain(terrain: Node) -> void:
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
			position = Vector4(0.0, max_y + height_margin, 0.0, 0.0)

	# Footprint: the nominal grid_size * cell_size formula - see this
	# script's own header for why the scanned bounds are deliberately not
	# used here. Unlike the old BoxTetraMesh4D.size setter (an O(1) property
	# update), SubdividedBoxTetraMesh4D.build() rebuilds the whole mesh from
	# scratch - fine here since footprint only actually changes on the rare
	# frame grid_size/cell_size changes, guarded by the equality check below,
	# not every frame.
	var footprint: float = float(terrain.grid_size) * cell_size
	if not is_equal_approx(footprint, _last_fitted_footprint):
		_last_fitted_footprint = footprint
		var half_extents := Vector4(footprint, thickness_y, footprint, footprint) * 0.5
		mesh = SubdividedBoxTetraMesh4D.build(half_extents, target_cell_size)


func _process(_delta: float) -> void:
	var terrain: Node = _get_terrain()
	if terrain != null:
		_refit_to_terrain(terrain)

	# Pushed to the shader for the noise sampling coordinate only - the
	# mesh's own SHAPE already responds to rig rotation for free via real
	# 4D slicing (see this script's own header), but the noise pattern
	# additionally needs this same rig-basis projection applied to it to
	# visibly warp/tilt with rotation instead of just revealing a different
	# fixed patch of a static texture - see clouds.gdshader's own header.
	# The parent (Terrain) IS the rig here - this node is meant to be a
	# direct, identity-basis child of it, so its basis is exactly the
	# current 4D slice rotation.
	var basis_x := Vector4(1.0, 0.0, 0.0, 0.0)
	var basis_z := Vector4(0.0, 0.0, 1.0, 0.0)
	var rig: Node4D = get_parent() as Node4D
	if rig != null:
		var rig_basis: Projection = rig.basis
		basis_x = rig_basis.x
		basis_z = rig_basis.z

	if _material != null:
		_material.set_shader_parameter("basis_x", basis_x)
		_material.set_shader_parameter("basis_z", basis_z)
