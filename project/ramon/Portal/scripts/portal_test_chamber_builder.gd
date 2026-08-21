extends Node4D
## Portal test chamber: a sealed room whose walls take a portal anywhere you aim,
## plus a white section of floor and ceiling, and one ledge you cannot jump to.
##
## The earlier version of this scene used fixed door-sized pads, and that was
## wrong about the thing it was trying to be. Portal lets you put a portal
## wherever you like on any surface that is white, flat and big enough; the
## aiming IS the game. So the walls here are single large portalable surfaces,
## and the aperture is cut into them at the point you hit.
##
## White means portalable and dark means it will refuse, which is Portal's own
## readability rule and free to obey here.
##
## The floor and ceiling white sections share a footprint on purpose: link them
## and you fall through a loop that keeps accelerating, which is the clearest
## demonstration that a portal preserves motion rather than just moving you.

const SurfaceScript := preload("res://ramon/Portal/scripts/portal_surface.gd")

const FloorTexture: Texture3D = preload("res://textures/dev_finals/ramdev_grey.png")
const CeilingTexture: Texture3D = preload("res://textures/dev_finals/ramdev_black_metal.png")
const LedgeTexture: Texture3D = preload("res://textures/dev_finals/ramdev_black_metal.png")

const HALF_WIDTH := 8.0 # x
const ROOM_HEIGHT := 6.0 # y
const HALF_DEPTH := 10.0 # z
const THICKNESS := 0.6
const W_HALF_EXTENT := 12.0

## The white sections of floor and ceiling, centred on the same footprint.
const PANEL_HALF := 3.5
const PANEL_CENTRE_X := 3.0
const PANEL_CENTRE_Z := 3.0

const LEDGE_TOP := 3.0
const LEDGE_HALF_WIDTH := 2.5
const LEDGE_DEPTH := 3.0

@onready var player: CharacterBody4D = $"../Player"

var surfaces: Array[Node4D] = []
var goal_reached: bool = false

var _goal_centre := Vector4.ZERO
var _goal_half_extents := Vector4.ZERO


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.03, 0.03, 0.05, 1.0))
	_build_room()
	_build_ledge()
	_spawn_player()
	print("[PortalTestChamber] %d portalable surfaces built" % surfaces.size())


func _make_material(texture: Texture3D) -> TetraMaterial4D:
	var material := TetraMaterial4D.new()
	material.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_TEXTURE3D_CELL_UVW_ONLY
	FlatShadingRamon.apply(material)
	material.albedo_texture_3d = texture
	return material


func _add_box(position: Vector4, size: Vector4, material: TetraMaterial4D) -> void:
	if size.x <= 0.001 or size.y <= 0.001 or size.z <= 0.001:
		return
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


## A dark plane with a rectangular gap in it, built as four framing boxes. The
## gap is where a white portalable surface goes.
func _add_framed_plane(
		normal_axis: int, centre_coord: float,
		axis_a: int, min_a: float, max_a: float,
		axis_b: int, min_b: float, max_b: float,
		hole_a: float, hole_half_a: float,
		hole_b: float, hole_half_b: float,
		material: TetraMaterial4D) -> void:
	_add_plane_piece(normal_axis, centre_coord, axis_a, min_a, max_a, axis_b, min_b, hole_b - hole_half_b, material)
	_add_plane_piece(normal_axis, centre_coord, axis_a, min_a, max_a, axis_b, hole_b + hole_half_b, max_b, material)
	_add_plane_piece(normal_axis, centre_coord, axis_a, min_a, hole_a - hole_half_a, axis_b, hole_b - hole_half_b, hole_b + hole_half_b, material)
	_add_plane_piece(normal_axis, centre_coord, axis_a, hole_a + hole_half_a, max_a, axis_b, hole_b - hole_half_b, hole_b + hole_half_b, material)


func _add_plane_piece(
		normal_axis: int, centre_coord: float,
		axis_a: int, min_a: float, max_a: float,
		axis_b: int, min_b: float, max_b: float,
		material: TetraMaterial4D) -> void:
	var span_a: float = max_a - min_a
	var span_b: float = max_b - min_b
	if span_a <= 0.001 or span_b <= 0.001:
		return
	var position := Vector4.ZERO
	position[normal_axis] = centre_coord
	position[axis_a] = (min_a + max_a) * 0.5
	position[axis_b] = (min_b + max_b) * 0.5
	var size := Vector4.ZERO
	size[normal_axis] = THICKNESS
	size[axis_a] = span_a
	size[axis_b] = span_b
	size.w = W_HALF_EXTENT * 2.0
	_add_box(position, size, material)


## One portalable surface. Its basis columns are (right, up, normal, ana), so the
## surface can work entirely in its own local (a, b) and the node does the
## orienting - which is also exactly the frame a portal placed on it inherits.
func _add_surface(centre: Vector4, normal: Vector4, up: Vector4, right: Vector4, half_a: float, half_b: float) -> void:
	var surface := SurfaceScript.new()
	surface.name = "Surface%d" % (surfaces.size() + 1)
	surface.position = centre
	surface.basis = Projection(right, up, normal, Vector4(0.0, 0.0, 0.0, 1.0))
	surface.normal = normal
	surface.up = up
	surface.right = right
	surface.half_a = half_a
	surface.half_b = half_b
	surface.thickness = THICKNESS
	surface.w_half_extent = W_HALF_EXTENT
	add_child(surface)
	surface.build()
	surfaces.append(surface)


func _build_room() -> void:
	var half_height: float = ROOM_HEIGHT * 0.5
	var up := Vector4(0.0, 1.0, 0.0, 0.0)

	# Four walls, each one portalable surface spanning the whole wall.
	_add_surface(Vector4(-HALF_WIDTH - THICKNESS * 0.5, half_height, 0.0, 0.0),
		Vector4(1, 0, 0, 0), up, Vector4(0, 0, 1, 0), HALF_DEPTH, half_height)
	_add_surface(Vector4(HALF_WIDTH + THICKNESS * 0.5, half_height, 0.0, 0.0),
		Vector4(-1, 0, 0, 0), up, Vector4(0, 0, -1, 0), HALF_DEPTH, half_height)
	_add_surface(Vector4(0.0, half_height, -HALF_DEPTH - THICKNESS * 0.5, 0.0),
		Vector4(0, 0, 1, 0), up, Vector4(-1, 0, 0, 0), HALF_WIDTH, half_height)
	_add_surface(Vector4(0.0, half_height, HALF_DEPTH + THICKNESS * 0.5, 0.0),
		Vector4(0, 0, -1, 0), up, Vector4(1, 0, 0, 0), HALF_WIDTH, half_height)

	# Floor and ceiling: dark, with one white section each on a shared footprint.
	var floor_material: TetraMaterial4D = _make_material(FloorTexture)
	var ceiling_material: TetraMaterial4D = _make_material(CeilingTexture)
	_add_framed_plane(1, -THICKNESS * 0.5, 0, -HALF_WIDTH, HALF_WIDTH, 2, -HALF_DEPTH, HALF_DEPTH,
		PANEL_CENTRE_X, PANEL_HALF, PANEL_CENTRE_Z, PANEL_HALF, floor_material)
	_add_surface(Vector4(PANEL_CENTRE_X, -THICKNESS * 0.5, PANEL_CENTRE_Z, 0.0),
		Vector4(0, 1, 0, 0), Vector4(0, 0, -1, 0), Vector4(1, 0, 0, 0), PANEL_HALF, PANEL_HALF)

	_add_framed_plane(1, ROOM_HEIGHT + THICKNESS * 0.5, 0, -HALF_WIDTH, HALF_WIDTH, 2, -HALF_DEPTH, HALF_DEPTH,
		PANEL_CENTRE_X, PANEL_HALF, PANEL_CENTRE_Z, PANEL_HALF, ceiling_material)
	_add_surface(Vector4(PANEL_CENTRE_X, ROOM_HEIGHT + THICKNESS * 0.5, PANEL_CENTRE_Z, 0.0),
		Vector4(0, -1, 0, 0), Vector4(0, 0, -1, 0), Vector4(1, 0, 0, 0), PANEL_HALF, PANEL_HALF)


## Deliberately out of reach: JUMP_VELOCITY 4.5 against gravity 9.8 is a 1.03 m
## hop, and there are no steps or ramps because the axis-aligned physics engine
## cannot represent either. It is dark, so it refuses portals - the way up is to
## put one on the wall above it.
func _build_ledge() -> void:
	var centre_z: float = -HALF_DEPTH + LEDGE_DEPTH * 0.5
	_add_box(
		Vector4(0.0, LEDGE_TOP - 0.25, centre_z, 0.0),
		Vector4(LEDGE_HALF_WIDTH * 2.0, 0.5, LEDGE_DEPTH, W_HALF_EXTENT * 2.0),
		_make_material(LedgeTexture))
	_goal_centre = Vector4(0.0, LEDGE_TOP + 1.0, centre_z, 0.0)
	_goal_half_extents = Vector4(LEDGE_HALF_WIDTH, 1.0, LEDGE_DEPTH * 0.5, W_HALF_EXTENT)


## Polled rather than detected by an Area4D, and this is not a style preference.
##
## The axis-aligned physics engine emits body_entered_self only on a
## not-overlapping -> overlapping TRANSITION, tested against a rect it cached at
## the end of the previous move_and_collide. A body that arrives by having its
## global_position assigned - which is exactly what a portal crossing is - never
## produces that transition: on the arrival frame the cached "before" rect is
## still back at the entry portal, and on every frame after it is already
## overlapping. Measured: the player stood on the ledge for dozens of frames
## while the Area4D reported nothing. See follow_up/engine_gotchas.md.
func _physics_process(_delta_time: float) -> void:
	_recover_if_lost()
	if goal_reached:
		return
	var offset: Vector4 = player.global_position - _goal_centre
	for axis in range(4):
		if absf(offset[axis]) > _goal_half_extents[axis]:
			return
	goal_reached = true


## An unpaired portal is now an open hole rather than a filled oval, so a single
## portal on the floor is a pit straight out of the room. That is the look that
## was asked for, and it needs a way back: falling out drops you at the spawn
## instead of into an endless void with no recourse.
func _recover_if_lost() -> void:
	var position: Vector4 = player.global_position
	if position.y > -12.0 and absf(position.x) < 40.0 and absf(position.z) < 40.0:
		return
	_spawn_player()
	player.linear_velocity = Vector4.ZERO


func _spawn_player() -> void:
	player.global_position = Vector4(0.0, 1.2, HALF_DEPTH - 2.5, 0.0)
