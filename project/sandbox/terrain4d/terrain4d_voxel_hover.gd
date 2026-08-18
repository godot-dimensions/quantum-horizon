extends Node
## Highlights the "voxel" (the dual-contouring cell the cursor is currently
## over) with a wireframe outline - first step toward voxel editing
## (placing/removing shapes). For now this only needs to prove hovering
## registers correctly against the real geometry; the outline mesh IS the
## proof, since it can only be built from a real raycast hit.
##
## The outline mesh is a sibling of Mesh/Collision under Terrain (a child
## of TerrainRig), so it automatically rotates along with the terrain -
## its vertices are written in the terrain's own LOCAL space, exactly like
## the terrain mesh itself, with no extra transform bookkeeping needed for
## display. Only the RAYCAST (which starts from the camera in world space)
## needs an explicit inverse-transform into that local space.

@export var camera_path: NodePath
@export var terrain_path: NodePath
@export var outline_path: NodePath
@export var outline_color: Color = Color(0.2, 1.0, 0.9, 1.0)
@export var outline_line_thickness: float = 3.0
@export var max_ray_distance: float = 100.0

@onready var camera: Camera4D = get_node(camera_path)
@onready var terrain: StaticBody4D = get_node(terrain_path)
@onready var outline: MeshInstance4D = get_node(outline_path)

var _last_dual_cube_id := -1

func _ready() -> void:
	var material := WireMaterial4D.new()
	material.albedo_color = outline_color
	material.line_thickness = outline_line_thickness
	outline.material_override = material
	outline.visible = false

func _process(_delta: float) -> void:
	update_hover_at(get_viewport().get_mouse_position())

## Takes the screen position explicitly rather than reading
## get_viewport().get_mouse_position() itself, so tests can drive this
## directly with a known-good target instead of depending on
## Input.warp_mouse() actually relocating the OS cursor - which isn't
## reliable in an automated/headless-adjacent window (confirmed: the
## viewport still reports the pre-warp position afterward).
func update_hover_at(screen_pos: Vector2) -> void:
	var shape: ConcaveMeshShape4D = terrain.collision_shape.shape
	if shape == null:
		return
	var world_origin: Vector4 = camera.viewport_to_world_ray_origin(screen_pos)
	var world_direction: Vector4 = camera.viewport_to_world_ray_direction(screen_pos)

	# The raycast against the collision shape needs LOCAL (terrain-space)
	# coordinates, but the ray itself starts in world space from the fixed
	# camera - so undo the terrain's current (possibly rig-rotated) global
	# transform here. Display doesn't need this: the outline mesh lives
	# under the same rotating parent as the terrain mesh, so its own local
	# vertices display correctly with no further transforming.
	var inverse_basis: Projection = terrain.global_basis.inverse()
	var local_origin: Vector4 = inverse_basis * (world_origin - terrain.global_position)
	var local_direction: Vector4 = (inverse_basis * world_direction).normalized()

	var hit: Dictionary = shape.raycast_intersects(local_origin, local_direction, max_ray_distance, false)
	if not hit.get("hit", false):
		outline.visible = false
		_last_dual_cube_id = -1
		return

	var result: Dictionary = terrain.get_last_result()
	var source_ids: PackedInt32Array = result.get("tet_source_ids", PackedInt32Array())
	var tet_index: int = hit.get("cell_index", -1)
	if tet_index < 0 or tet_index >= source_ids.size():
		outline.visible = false
		_last_dual_cube_id = -1
		return

	var dual_cube_id: int = source_ids[tet_index]
	if dual_cube_id == _last_dual_cube_id and outline.visible:
		return
	_last_dual_cube_id = dual_cube_id
	_rebuild_outline(dual_cube_id, source_ids)

## Draws the wireframe of every tet sharing the hovered dual-cube id - this
## traces the full local surface patch (the "voxel"), not just one thin
## tetrahedron slice of it.
func _rebuild_outline(dual_cube_id: int, source_ids: PackedInt32Array) -> void:
	var mesh: ArrayTetraMesh4D = terrain.mesh_instance.mesh
	var vertices: PackedVector4Array = mesh.get_vertices()
	var cell_indices: PackedInt32Array = mesh.get_simplex_cell_indices()

	var wire := ArrayWireMesh4D.new()
	for tet_index in range(source_ids.size()):
		if source_ids[tet_index] != dual_cube_id:
			continue
		var base := tet_index * 4
		var local_indices := PackedInt32Array()
		for c in range(4):
			local_indices.append(wire.append_vertex(vertices[cell_indices[base + c]], true))
		wire.append_edge_indices(local_indices[0], local_indices[1], true)
		wire.append_edge_indices(local_indices[0], local_indices[2], true)
		wire.append_edge_indices(local_indices[0], local_indices[3], true)
		wire.append_edge_indices(local_indices[1], local_indices[2], true)
		wire.append_edge_indices(local_indices[1], local_indices[3], true)
		wire.append_edge_indices(local_indices[2], local_indices[3], true)

	outline.mesh = wire
	outline.visible = true
