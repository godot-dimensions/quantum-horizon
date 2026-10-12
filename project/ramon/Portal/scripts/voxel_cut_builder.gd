extends Node4D
## Test room for the swap-in voxel cut: plain box walls that become voxel where
## you shoot them. Deliberately minimal - no portals, no ledge, no goal. The one
## question is whether a dual-contoured ball cut reads as a clean circle and what
## it costs, and anything else in the scene is noise against that.

const WallScript := preload("res://ramon/Portal/scripts/voxel_cut_wall.gd")

const FloorTexture: Texture3D = preload("res://textures/dev_finals/ramdev_grey.png")
const CeilingTexture: Texture3D = preload("res://textures/dev_finals/ramdev_black_metal.png")

const HALF_WIDTH := 7.0
const ROOM_HEIGHT := 5.0
const HALF_DEPTH := 8.0
const THICKNESS := 0.6
const W_HALF_EXTENT := 12.0

@onready var player: CharacterBody4D = $"../Player"

var walls: Array[Node4D] = []


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.03, 0.03, 0.05, 1.0))
	_build_room()
	player.global_position = Vector4(0.0, 1.2, HALF_DEPTH - 3.0, 0.0)
	print("[VoxelCutTest] %d cuttable walls" % walls.size())


func _make_material(texture: Texture3D) -> TetraMaterial4D:
	var material := TetraMaterial4D.new()
	material.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_TEXTURE3D_CELL_UVW_ONLY
	FlatShadingRamon.apply(material)
	material.albedo_texture_3d = texture
	return material


func _add_box(position: Vector4, size: Vector4, material: TetraMaterial4D) -> void:
	var body := StaticBody4D.new()
	body.position = position
	add_child(body)
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
	mesh_instance.material_override = material
	body.add_child(mesh_instance)


func _add_wall(centre: Vector4, normal: Vector4, up: Vector4, right: Vector4, half_a: float, half_b: float) -> void:
	var wall := WallScript.new()
	wall.name = "Wall%d" % (walls.size() + 1)
	wall.position = centre
	wall.basis = Projection(right, up, normal, Vector4(0.0, 0.0, 0.0, 1.0))
	wall.normal = normal
	wall.up = up
	wall.right = right
	wall.half_a = half_a
	wall.half_b = half_b
	wall.thickness = THICKNESS
	wall.w_half_extent = W_HALF_EXTENT
	add_child(wall)
	wall.build()
	walls.append(wall)


func _build_room() -> void:
	var half_height: float = ROOM_HEIGHT * 0.5
	var up := Vector4(0.0, 1.0, 0.0, 0.0)

	_add_box(Vector4(0.0, -THICKNESS * 0.5, 0.0, 0.0),
		Vector4(HALF_WIDTH * 2.0, THICKNESS, HALF_DEPTH * 2.0, W_HALF_EXTENT * 2.0),
		_make_material(FloorTexture))
	_add_box(Vector4(0.0, ROOM_HEIGHT + THICKNESS * 0.5, 0.0, 0.0),
		Vector4(HALF_WIDTH * 2.0, THICKNESS, HALF_DEPTH * 2.0, W_HALF_EXTENT * 2.0),
		_make_material(CeilingTexture))

	_add_wall(Vector4(0.0, half_height, -HALF_DEPTH - THICKNESS * 0.5, 0.0),
		Vector4(0, 0, 1, 0), up, Vector4(-1, 0, 0, 0), HALF_WIDTH, half_height)
	_add_wall(Vector4(0.0, half_height, HALF_DEPTH + THICKNESS * 0.5, 0.0),
		Vector4(0, 0, -1, 0), up, Vector4(1, 0, 0, 0), HALF_WIDTH, half_height)
	_add_wall(Vector4(-HALF_WIDTH - THICKNESS * 0.5, half_height, 0.0, 0.0),
		Vector4(1, 0, 0, 0), up, Vector4(0, 0, 1, 0), HALF_DEPTH, half_height)
	_add_wall(Vector4(HALF_WIDTH + THICKNESS * 0.5, half_height, 0.0, 0.0),
		Vector4(-1, 0, 0, 0), up, Vector4(0, 0, -1, 0), HALF_DEPTH, half_height)
