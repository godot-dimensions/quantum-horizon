extends Node4D
## Chamber 01, milestone A: a Portal-shaped room whose portalable panels are
## destructible 4D voxel geometry, and whose shell is not.
##
## The split is the whole design, and it comes from two directions agreeing:
## Portal itself only allows portals on specific surfaces (white panels versus
## dark walls), and a VoxelField4D is finite in w, so a voxel wall silently
## stops existing once the player moves past its w range. So the shell is
## ordinary w-invariant box geometry with a huge w extent - the PhaseMaze /
## hub convention that has held up in three scenes - and the expensive,
## finite, destructible thing is confined to the panels that need it.
##
## This milestone deliberately proves ONE thing: that VoxelMining's per-hit
## carve-and-remesh survives being multiplied up to room scale. VoxelMining has
## only ever run a single block. Everything is instrumented for that reason -
## see the HUD - because collider count is the number most likely to bite, and
## guessing at it would defeat the point.
##
## Not yet here: portal pairs, apertures, traversal, the look-through. Those
## come after the scaling question has an answer.

const PortalVoxelPanel := preload("res://ramon/Portal/scripts/portal_voxel_panel.gd")

## Walls are grey rather than black_metal, measured from a render rather than
## chosen on paper: the flat shading term is dot(normal, up)/2 + 0.5, so a
## vertical surface only ever gets half its albedo. Black_metal walls came out
## indistinguishable from the empty background and the room read as a void with
## a floor in it. Grey walls at half brightness still sit well below the white
## panels, which is the contrast that has to survive - Portal's readability rule
## is that a portalable surface is obvious at a glance.
const FloorTexture: Texture3D = preload("res://textures/dev_finals/ramdev_grey.png")
const WallTexture: Texture3D = preload("res://textures/dev_finals/ramdev_grey.png")
const CeilingTexture: Texture3D = preload("res://textures/dev_finals/ramdev_black_metal.png")

## Interior of the room, in metres. Smaller than the paper's 14 x 7 x 20 m cage
## on the height axis only - 5 m still reads as a hall to a 1.75 m player and
## there is nothing up there to look at yet (Valve: playtesters rarely look up).
const ROOM_WIDTH := 14.0
const ROOM_HEIGHT := 5.0
const ROOM_DEPTH := 18.0
const WALL_THICKNESS := 0.6

## How far the shell extends either side of w = 0. Matches PhaseMaze's structural
## convention: whatever the player does with w, the room must not disappear.
const SHELL_W_HALF_EXTENT := 12.0

## Carve radius per shot, in metres. Roughly VoxelMining's 0.48 m bite scaled to
## this panel's coarser cells, so a few shots open a person-sized hole rather
## than dozens.
const CARVE_RADIUS := 0.6

## Half the slab's thickness in cells, and the same figure in metres.
##
## 1.4 rather than a round 1.0 for a measured reason: a grid point sits exactly
## on the boundary at 1.0, giving it zero margin, and a point with zero margin is
## not "denser" than the air already there - so a half-thickness of 1.0 built a
## panel ONE voxel thick (measured: 125 colliders per panel, i.e. 5 x 5 x 1 x 5)
## rather than the intended three. 1.4 leaves the +/-1 cells a real margin and
## produces the 3-cell slab the carve radius is sized against. A 1-cell panel
## also punches straight through on the first shot, which is a hole, not the
## shallow recess a portal is supposed to be.
const PANEL_HALF_THICKNESS_CELLS := 1.4
const PANEL_CELL_SIZE := 0.5
const PANEL_HALF_THICKNESS := PANEL_HALF_THICKNESS_CELLS * PANEL_CELL_SIZE

@onready var player: CharacterBody4D = $"../Player"

var panels: Array[Node4D] = []
var build_msec: float = 0.0


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.03, 0.03, 0.05, 1.0))
	var started_usec: int = Time.get_ticks_usec()
	_build_shell()
	_build_panels()
	build_msec = float(Time.get_ticks_usec() - started_usec) / 1000.0
	_spawn_player()
	print("[PortalChamber] built in %.0f ms: %d panels, %d colliders, %d tetrahedra" % [
		build_msec, panels.size(), total_collider_count(), total_tetra_count()])


func _make_material(texture: Texture3D) -> TetraMaterial4D:
	var material := TetraMaterial4D.new()
	material.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_TEXTURE3D_CELL_UVW_ONLY
	FlatShadingRamon.apply(material)
	material.albedo_texture_3d = texture
	return material


## Collision plus visual as one static box, the same pairing
## phase_maze_builder.gd's _add_panel() uses - a BoxShape4D is the one shape the
## axis-aligned physics engine does not have to approximate.
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


func _build_shell() -> void:
	var w_size: float = SHELL_W_HALF_EXTENT * 2.0
	var half_width: float = ROOM_WIDTH * 0.5
	var half_depth: float = ROOM_DEPTH * 0.5
	var outer_width: float = ROOM_WIDTH + WALL_THICKNESS * 2.0

	_add_box(
		Vector4(0.0, -WALL_THICKNESS * 0.5, 0.0, 0.0),
		Vector4(outer_width, WALL_THICKNESS, ROOM_DEPTH + WALL_THICKNESS * 2.0, w_size),
		_make_material(FloorTexture))
	_add_box(
		Vector4(0.0, ROOM_HEIGHT + WALL_THICKNESS * 0.5, 0.0, 0.0),
		Vector4(outer_width, WALL_THICKNESS, ROOM_DEPTH + WALL_THICKNESS * 2.0, w_size),
		_make_material(CeilingTexture))

	var wall_material: TetraMaterial4D = _make_material(WallTexture)
	var wall_centre_y: float = ROOM_HEIGHT * 0.5
	# End walls span the full outer width so the corners close properly.
	_add_box(
		Vector4(0.0, wall_centre_y, -half_depth - WALL_THICKNESS * 0.5, 0.0),
		Vector4(outer_width, ROOM_HEIGHT, WALL_THICKNESS, w_size), wall_material)
	_add_box(
		Vector4(0.0, wall_centre_y, half_depth + WALL_THICKNESS * 0.5, 0.0),
		Vector4(outer_width, ROOM_HEIGHT, WALL_THICKNESS, w_size), wall_material)
	_add_box(
		Vector4(-half_width - WALL_THICKNESS * 0.5, wall_centre_y, 0.0, 0.0),
		Vector4(WALL_THICKNESS, ROOM_HEIGHT, ROOM_DEPTH, w_size), wall_material)
	_add_box(
		Vector4(half_width + WALL_THICKNESS * 0.5, wall_centre_y, 0.0, 0.0),
		Vector4(WALL_THICKNESS, ROOM_HEIGHT, ROOM_DEPTH, w_size), wall_material)


## Four panels: a facing pair on the far wall (so one is visible from the other,
## which is how Valve introduces the mechanic - the player sees themselves
## through the pair before being asked to do anything), and one on each side
## wall. Panels sit proud of their host wall rather than recessed into it; the
## shell is only WALL_THICKNESS deep and a portal is meant to be flush with its
## surface, never a tunnel.
func _build_panels() -> void:
	var half_width: float = ROOM_WIDTH * 0.5
	var half_depth: float = ROOM_DEPTH * 0.5
	var panel_centre_y: float = 1.6

	# Offset by the slab's own half-thickness so its back face is flush with the
	# wall's inner surface and it reads as part of the wall, not furniture.
	_add_panel(Vector4(-3.5, panel_centre_y, -half_depth + PANEL_HALF_THICKNESS, 0.0), 2)
	_add_panel(Vector4(3.5, panel_centre_y, -half_depth + PANEL_HALF_THICKNESS, 0.0), 2)
	_add_panel(Vector4(-half_width + PANEL_HALF_THICKNESS, panel_centre_y, -3.0, 0.0), 0)
	_add_panel(Vector4(half_width - PANEL_HALF_THICKNESS, panel_centre_y, 3.0, 0.0), 0)


func _add_panel(position: Vector4, normal_axis: int) -> void:
	var panel := PortalVoxelPanel.new()
	panel.name = "Panel%d" % (panels.size() + 1)
	panel.position = position
	panel.normal_axis = normal_axis
	panel.cell_size = PANEL_CELL_SIZE
	panel.thickness_half_cells = PANEL_HALF_THICKNESS_CELLS
	add_child(panel)
	panel.build()
	panels.append(panel)


## Facing the far wall's panel pair from across the room, which is the first
## thing the chamber has to say for itself.
func _spawn_player() -> void:
	player.global_position = Vector4(0.0, 1.2, ROOM_DEPTH * 0.5 - 2.0, 0.0)


func total_collider_count() -> int:
	var total := 0
	for panel in panels:
		total += panel.collider_count
	return total


func total_tetra_count() -> int:
	var total := 0
	for panel in panels:
		total += panel.tetra_count
	return total


func last_carve_msec() -> float:
	var latest := 0.0
	for panel in panels:
		latest = maxf(latest, panel.last_carve_msec)
	return latest
