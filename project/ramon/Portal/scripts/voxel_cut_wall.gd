extends Node4D
## An ordinary box wall that can swap a square of itself for a voxel patch.
##
## This is the cheap half of the trade. The wall is one box and costs nothing
## until it is shot; then it becomes four framing boxes around a square window,
## and a VoxelCutPatch fills that window. So the expensive representation exists
## only where somebody actually made a hole.
##
## The window is a plain rectangle cut by four boxes - no strips anywhere. The
## roundness is the patch's job, and dual contouring does it properly.

const PatchScript := preload("res://ramon/Portal/scripts/voxel_cut_patch.gd")
const WallTexture: Texture3D = preload("res://textures/dev_finals/ramdev_white.png")

var half_a: float = 8.0
var half_b: float = 3.0
var thickness: float = 0.6
var w_half_extent: float = 12.0

var normal := Vector4(0.0, 0.0, 1.0, 0.0)
var up := Vector4(0.0, 1.0, 0.0, 0.0)
var right := Vector4(1.0, 0.0, 0.0, 0.0)

## How far neighbouring wall pieces bury themselves in each other, in metres.
const SEAM_OVERLAP := 0.02

var patch: Node4D = null

var _solid: StaticBody4D = null
var _window_centre := Vector2.ZERO
var _has_window: bool = false


func build() -> void:
	_solid = StaticBody4D.new()
	_solid.name = &"Solid"
	add_child(_solid)
	_rebuild_solid()


func local_of(world_point: Vector4) -> Vector2:
	var offset: Vector4 = world_point - global_position
	return Vector2(offset.dot(right), offset.dot(up))


## Opens the window at the aimed point, sliding it so the whole square fits on
## the wall, and drops a voxel patch into it. Returns false if the wall is too
## small to hold one.
func cut_at(world_point: Vector4) -> bool:
	var half: float = PatchScript.face_half_extent()
	if half_a < half or half_b < half:
		return false
	var requested: Vector2 = local_of(world_point)
	_window_centre = Vector2(
		clampf(requested.x, -half_a + half, half_a - half),
		clampf(requested.y, -half_b + half, half_b - half))
	_has_window = true
	_rebuild_solid()
	_spawn_patch()
	return true


func _spawn_patch() -> void:
	if patch != null and is_instance_valid(patch):
		patch.queue_free()
	patch = PatchScript.new()
	patch.name = &"Patch"
	patch.thickness = thickness
	patch.w_half_extent = w_half_extent
	# Local space: the patch shares the wall's frame, so its own axes are already
	# (right, up, normal, ana) and it can work in plain local coordinates.
	patch.position = Vector4(_window_centre.x, _window_centre.y, 0.0, 0.0)
	add_child(patch)
	patch.build()


func has_window() -> bool:
	return _has_window


func _make_material() -> TetraMaterial4D:
	var material := TetraMaterial4D.new()
	material.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_TEXTURE3D_CELL_UVW_ONLY
	FlatShadingRamon.apply(material)
	material.albedo_texture_3d = WallTexture
	return material


func _rebuild_solid() -> void:
	for child in _solid.get_children():
		_solid.remove_child(child)
		child.queue_free()

	if not _has_window:
		_add_piece(-half_a, half_a, -half_b, half_b)
		return

	var half: float = PatchScript.face_half_extent()
	var min_a: float = _window_centre.x - half
	var max_a: float = _window_centre.x + half
	var min_b: float = _window_centre.y - half
	var max_b: float = _window_centre.y + half
	# Overlapped into each other, never merely butted. Two boxes that share a
	# face exactly leave a visible black seam in the cross-section renderer -
	# measured: an uncut room is spotless, and the instant a window is cut a
	# black band appears right across the wall at the window's top edge, while a
	# raycast confirms the wall is solid the whole way through. Overlapping
	# solids cannot produce it. Only edges that do NOT face the window move.
	_add_piece(-half_a, half_a, -half_b, min_b + SEAM_OVERLAP)
	_add_piece(-half_a, half_a, max_b - SEAM_OVERLAP, half_b)
	_add_piece(-half_a, min_a + SEAM_OVERLAP, min_b, max_b)
	_add_piece(max_a - SEAM_OVERLAP, half_a, min_b, max_b)


func _add_piece(min_a: float, max_a: float, min_b: float, max_b: float) -> void:
	var span_a: float = max_a - min_a
	var span_b: float = max_b - min_b
	if span_a <= 0.001 or span_b <= 0.001:
		return
	var body := Node4D.new()
	body.position = Vector4((min_a + max_a) * 0.5, (min_b + max_b) * 0.5, 0.0, 0.0)
	_solid.add_child(body)

	var size := Vector4(span_a, span_b, thickness, w_half_extent * 2.0)
	var collision_shape := CollisionShape4D.new()
	var shape := BoxShape4D.new()
	shape.size = size
	collision_shape.shape = shape
	body.add_child(collision_shape)

	var mesh_instance := MeshInstance4D.new()
	var mesh := BoxTetraMesh4D.new()
	mesh.size = size
	mesh.cell_texture_map = BoxTetraMesh4D.BOX_CELL_TEXTURE_MAP_FILL_EACH_SIDE
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _make_material()
	body.add_child(mesh_instance)
