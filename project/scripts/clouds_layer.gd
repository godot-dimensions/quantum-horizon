class_name CloudsLayer
extends MeshInstance3D
## Ordinary Godot 3D plane, deliberately outside the 4D Cross-section
## pipeline - same "doesn't need to be 4D" convention as the HUD. No
## Node4D/tet-mesh cost. Renders through the same viewport/camera as
## everything else via a standard spatial shader (see clouds.gdshader).
##
## Sized and positioned to match the terrain's own PLANAR footprint
## (terrain.grid_size * terrain.cell_size, centered at the terrain's own
## local XZ origin - see voxel_terrain_4d.gd's _build_mesh: `world_position =
## (grid_position - center) * cell_size`, i.e. the terrain mesh itself is
## already centered there) at a fixed height above it - a semi-transparent
## deck seen mostly from above, like a real cloud layer photographed from a
## plane window, not a full sky dome. RADIAL (globe) terrains are not
## specially handled - deliberately out of scope for now, see the
## conversation this was built in; the plane still renders, just without
## trying to fit a sphere's silhouette.
##
## Real 4D volumetric clouds were explicitly ruled out as too expensive, but
## the cloud pattern should still respond to the current 4D slice rotation
## as a genuine tilted cross-section (not just a uniform shift) - see
## clouds.gdshader's own header for the derivation (it reuses the same
## ana_offset-style projection this project already uses for real 4D points
## elsewhere, e.g. bearing_utility_4d.gd).

## How far above the terrain's own nominal 0-height the cloud deck sits, as
## a fraction of the terrain's footprint size - keeps proportions sane
## across very different grid_size/cell_size combinations rather than one
## fixed world-unit height. Kept LOW - the terrain's own vertical relief is
## typically a small fraction of its horizontal footprint (a height field,
## not a tall structure), so the cloud deck needs to sit close to it to
## visually overlap the terrain from a normal orbit distance rather than
## receding into a separate band near the top of frame (confirmed directly:
## 0.35 put the clouds visibly far above/behind the terrain instead of
## hovering just over it, even at a steep near-vertical camera angle).
@export var height_fraction: float = 0.1
## The Node4D whose basis carries the xw/zw rotation - typically the same
## node right-drag rotates (see voxel_hover_camera_4d.gd's rig_path). This is
## the authoritative "how far has the 4D slice rotated" state; there is no
## separate copy of it to keep in sync.
@export var rig_path: NodePath
## The VoxelTerrain4D to size/position this layer against.
@export var terrain_path: NodePath

var _material: ShaderMaterial
var _plane_mesh: PlaneMesh
var _last_fitted_size: float = -1.0


func _ready() -> void:
	if mesh == null:
		mesh = PlaneMesh.new()
	_plane_mesh = mesh as PlaneMesh
	if _plane_mesh != null and _plane_mesh.material is ShaderMaterial:
		_material = _plane_mesh.material


func _get_terrain() -> Node:
	return get_node_or_null(terrain_path)


## Refits size/height to the terrain's CURRENT grid_size/cell_size if they've
## changed since the last check (e.g. a different preset/bake loaded) -
## cheap to check every frame, only actually touches the mesh (which
## triggers a rebuild) when the footprint size has genuinely changed.
func _refit_to_terrain(terrain: Node) -> void:
	if _plane_mesh == null or not ("grid_size" in terrain) or not ("cell_size" in terrain):
		return
	var footprint: float = float(terrain.grid_size) * float(terrain.cell_size)
	if is_equal_approx(footprint, _last_fitted_size):
		return
	_last_fitted_size = footprint
	_plane_mesh.size = Vector2(footprint, footprint)
	position = Vector3(0.0, footprint * height_fraction, 0.0)


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
