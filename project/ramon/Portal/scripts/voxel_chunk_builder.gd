extends Node4D
## Shooting range for the chunked voxel wall: a dark firing room, one white wall
## you can shoot holes in, and a red room behind it you can walk into through
## them.
##
## The staging follows the hub's colour legend (project/ramon/Demo/README.md):
## grey, white and black carry structure, yellow means interaction, and red is
## the one colour the hub deliberately never spends - which makes it the right
## choice for the space you are trying to reach. The firing room is deliberately
## drab so the white plane is the only thing worth looking at, and the yellow
## frame and floor line say where to stand and what to shoot without a word of
## text.

const PortalShading := preload("res://ramon/Portal/scripts/portal_shading.gd")
const ChunkWallScript := preload("res://ramon/Portal/scripts/voxel_chunk_wall.gd")

const FloorTexture: Texture3D = preload("res://textures/dev_finals/ramdev_grey.png")
## Side walls are grey, not black_metal. The flat shading term halves a vertical
## surface's brightness, which took black_metal down to within a shade of the
## clear colour - the firing room read as a void with a floor in it, and it was
## impossible to tell missing geometry from geometry that was merely dark.
const DarkTexture: Texture3D = preload("res://textures/dev_finals/ramdev_grey.png")
## Black props are fine where the CEILINGS are not: a black box standing on a red
## floor still reads as an object, because its silhouette is unmistakable. It was
## downward-facing dark surfaces - ceilings, undersides - that read as voids.
const PropTexture: Texture3D = preload("res://textures/dev_finals/ramdev_black_metal.png")
## Grey, not black or black_metal.
##
## A ceiling is seen from below, so it gets the shading term's minimum, and the
## ambient floor multiplies the TEXTURE rather than replacing it - 0.42 of a
## near-black texture is still near-black. Looking up through a hole therefore
## showed a black void where the far room's ceiling should be, which is exactly
## the "faces lost on the upper surface" report. A mid-grey ceiling at minimum
## brightness still reads as a surface.
const CeilingTexture: Texture3D = preload("res://textures/dev_finals/ramdev_grey.png")
const AccentTexture: Texture3D = preload("res://textures/dev_finals/ramdev_yellow.png")
const RedTexture: Texture3D = preload("res://textures/dev_finals/ramdev_red.png")

const HALF_WIDTH := 6.0
const ROOM_HEIGHT := 4.0
## The firing room runs from the wall back to here.
const FIRING_DEPTH := 9.0
## And the red room continues this far beyond it.
const BACK_DEPTH := 11.0
const THICKNESS := 0.6
const W_HALF_EXTENT := 12.0
const FACE_CELL := 0.25

## Where the shootable wall's near face sits.
const WALL_Z := -FIRING_DEPTH
## Close enough that the wall fills the view and a hole reads immediately.
const FIRING_LINE_Z := -3.0

@onready var player: CharacterBody4D = $"../Player"

var wall: Node4D = null


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.02, 0.02, 0.03, 1.0))
	_build_firing_room()
	_build_wall()
	_build_frame()
	_build_back_room()
	player.global_position = Vector4(0.0, 1.2, FIRING_LINE_Z, 0.0)
	print("[VoxelChunkTest] wall built in %.0f ms: %d chunks, %d tetrahedra, %d colliders" % [
		wall.build_msec, wall.chunks.size(), wall.total_tetra_count(), wall.total_collider_count()])


func _make_material(texture: Texture3D) -> TetraMaterial4D:
	var material := TetraMaterial4D.new()
	material.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_TEXTURE3D_CELL_UVW_ONLY
	PortalShading.apply(material)
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


## Decoration only - no collider, so it can sit proud of a surface without
## catching the player on it.
func _add_trim(position: Vector4, size: Vector4, material: TetraMaterial4D) -> void:
	var mesh_instance := MeshInstance4D.new()
	mesh_instance.position = position
	var mesh := BoxTetraMesh4D.new()
	mesh.size = size
	mesh.cell_texture_map = BoxTetraMesh4D.BOX_CELL_TEXTURE_MAP_FILL_EACH_SIDE
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	add_child(mesh_instance)


func _build_firing_room() -> void:
	var w_size: float = W_HALF_EXTENT * 2.0
	var depth: float = FIRING_DEPTH
	var centre_z: float = 0.0

	_add_box(Vector4(0.0, -THICKNESS * 0.5, centre_z, 0.0),
		Vector4(HALF_WIDTH * 2.0, THICKNESS, depth * 2.0, w_size), _make_material(FloorTexture))
	_add_box(Vector4(0.0, ROOM_HEIGHT + THICKNESS * 0.5, centre_z, 0.0),
		Vector4(HALF_WIDTH * 2.0, THICKNESS, depth * 2.0, w_size), _make_material(CeilingTexture))
	_add_box(Vector4(0.0, ROOM_HEIGHT * 0.5, depth + THICKNESS * 0.5, 0.0),
		Vector4(HALF_WIDTH * 2.0, ROOM_HEIGHT, THICKNESS, w_size), _make_material(DarkTexture))
	_add_box(Vector4(-HALF_WIDTH - THICKNESS * 0.5, ROOM_HEIGHT * 0.5, centre_z, 0.0),
		Vector4(THICKNESS, ROOM_HEIGHT, depth * 2.0, w_size), _make_material(DarkTexture))
	_add_box(Vector4(HALF_WIDTH + THICKNESS * 0.5, ROOM_HEIGHT * 0.5, centre_z, 0.0),
		Vector4(THICKNESS, ROOM_HEIGHT, depth * 2.0, w_size), _make_material(DarkTexture))

	# The firing line: where to stand, said with a stripe rather than a label.
	_add_trim(Vector4(0.0, 0.012, FIRING_LINE_Z, 0.0),
		Vector4(HALF_WIDTH * 2.0 - 1.0, 0.03, 0.28, w_size), _make_material(AccentTexture))


func _build_wall() -> void:
	wall = ChunkWallScript.new()
	wall.name = &"ChunkWall"
	wall.position = Vector4(0.0, ROOM_HEIGHT * 0.5, WALL_Z - THICKNESS * 0.5, 0.0)
	wall.basis = Projection(Vector4(-1, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1))
	wall.normal = Vector4(0, 0, 1, 0)
	wall.up = Vector4(0, 1, 0, 0)
	wall.right = Vector4(-1, 0, 0, 0)
	wall.face_cell = FACE_CELL
	# One cell larger than the opening it fills: the wall's solid extent is inset
	# a cell inside its chunk coverage so the outer edge can be capped, and
	# without this compensation that inset shows as a gap to floor and ceiling.
	wall.half_a = HALF_WIDTH + FACE_CELL
	wall.half_b = ROOM_HEIGHT * 0.5 + FACE_CELL
	wall.thickness = THICKNESS
	wall.w_half_extent = W_HALF_EXTENT
	add_child(wall)
	wall.build()


## A yellow band wrapping the room at the plane where the shootable wall begins -
## floor, both side walls and ceiling - rather than a frame stuck around the wall
## itself. A frame decorates the wall; a threshold says "the range starts here"
## and belongs to the room, which is what the space needs to communicate.
func _build_frame() -> void:
	var material: TetraMaterial4D = _make_material(AccentTexture)
	var w_size: float = W_HALF_EXTENT * 2.0
	var band_z: float = WALL_Z + 0.35
	var band := 0.3
	var skim := 0.02

	_add_trim(Vector4(0.0, skim, band_z, 0.0),
		Vector4(HALF_WIDTH * 2.0, 0.03, band, w_size), material)
	_add_trim(Vector4(0.0, ROOM_HEIGHT - skim, band_z, 0.0),
		Vector4(HALF_WIDTH * 2.0, 0.03, band, w_size), material)
	_add_trim(Vector4(-HALF_WIDTH + skim, ROOM_HEIGHT * 0.5, band_z, 0.0),
		Vector4(0.03, ROOM_HEIGHT, band, w_size), material)
	_add_trim(Vector4(HALF_WIDTH - skim, ROOM_HEIGHT * 0.5, band_z, 0.0),
		Vector4(0.03, ROOM_HEIGHT, band, w_size), material)


## The room you are shooting your way into. Red throughout, because it has to be
## unmistakably somewhere else the moment the first hole opens.
func _build_back_room() -> void:
	var w_size: float = W_HALF_EXTENT * 2.0
	var red: TetraMaterial4D = _make_material(RedTexture)
	var near_z: float = WALL_Z - THICKNESS
	var far_z: float = near_z - BACK_DEPTH
	var centre_z: float = (near_z + far_z) * 0.5

	_add_box(Vector4(0.0, -THICKNESS * 0.5, centre_z, 0.0),
		Vector4(HALF_WIDTH * 2.0, THICKNESS, BACK_DEPTH, w_size), red)
	_add_box(Vector4(0.0, ROOM_HEIGHT + THICKNESS * 0.5, centre_z, 0.0),
		Vector4(HALF_WIDTH * 2.0, THICKNESS, BACK_DEPTH, w_size), _make_material(CeilingTexture))
	_add_box(Vector4(0.0, ROOM_HEIGHT * 0.5, far_z - THICKNESS * 0.5, 0.0),
		Vector4(HALF_WIDTH * 2.0, ROOM_HEIGHT, THICKNESS, w_size), red)
	_add_box(Vector4(-HALF_WIDTH - THICKNESS * 0.5, ROOM_HEIGHT * 0.5, centre_z, 0.0),
		Vector4(THICKNESS, ROOM_HEIGHT, BACK_DEPTH, w_size), red)
	_add_box(Vector4(HALF_WIDTH + THICKNESS * 0.5, ROOM_HEIGHT * 0.5, centre_z, 0.0),
		Vector4(THICKNESS, ROOM_HEIGHT, BACK_DEPTH, w_size), red)

	# A couple of blocks so the red room reads as a place with depth rather than
	# a flat backdrop once you see it through a hole.
	_add_box(Vector4(-2.6, 0.6, centre_z + 1.5, 0.0), Vector4(1.2, 1.2, 1.2, w_size),
		_make_material(PropTexture))
	_add_box(Vector4(3.0, 0.4, centre_z - 2.0, 0.0), Vector4(1.6, 0.8, 1.6, w_size),
		_make_material(PropTexture))
