extends Node4D
## Single-room "Impossible Bypass" chamber: one partition wall blocks the
## straight line from start to goal, and the only way through it is to shift
## position.w until you're standing at the wall's one w-gap. Same finite-w
## "solid/visible only within a slice window" trick as PhaseMaze's gates
## (see phase_maze_builder.gd), isolated to a single wall in a single room so
## the fourth axis mattering is the whole and only point of the chamber -
## no maze, no branching, one idea.

const ROOM_WIDTH := 8.0
const ROOM_DEPTH := 16.0
const WALL_THICKNESS := 0.4
const WALL_HEIGHT := 3.0
const FLOOR_THICKNESS := 0.5
const CEILING_THICKNESS := 0.4

## Permanent geometry (floor/ceiling/boundary walls) spans this much of w
## either side of 0 - comfortably covers the bypass wall's own gap window
## below with margin, so nothing structural vanishes while working the gap.
const STRUCTURE_W_HALF_EXTENT := 12.0

const GATE_GAP_HALF_WIDTH := 1.5 # Total passable window = 3m of w.
const GATE_GAP_W := 6.0 # Far enough from spawn w (0) that finding it needs a deliberate shift.

const FloorTexture := preload("res://textures/dev_finals/ramdev_blue.png")
const CeilingTexture := preload("res://textures/dev_finals/ramdev_black.png")
const BoundaryWallTexture := preload("res://textures/dev_finals/ramdev_black_metal.png")
const BypassWallTexture := preload("res://textures/dev_finals/ramdev_yellow.png")
const GoalTexture := preload("res://textures/dev_finals/ramdev_red.png")

@onready var player: CharacterBody4D = $"../Player"
@onready var hud: Control = $"../../BypassHud"

var _goal_area: Area4D


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.0, 0.0, 0.0, 1.0))
	_build_floor_and_ceiling()
	_build_boundary_walls()
	_build_bypass_wall()
	_build_goal()
	_spawn_player()


## No Light4D/WorldEnvironment4D in this scene, so cross-sections need the
## flat-shaded swap - see FlatShadingRamon for why, and PhaseMaze/the
## shooting gallery for the other two places that rely on it the same way.
func _make_material(texture: Texture3D) -> TetraMaterial4D:
	var material := TetraMaterial4D.new()
	material.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_TEXTURE3D_CELL_UVW_ONLY
	FlatShadingRamon.apply(material)
	material.albedo_texture_3d = texture
	return material


func _add_panel(position: Vector4, size: Vector4, material: TetraMaterial4D) -> void:
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


func _build_floor_and_ceiling() -> void:
	var w_size: float = STRUCTURE_W_HALF_EXTENT * 2.0
	_add_panel(Vector4(0, -FLOOR_THICKNESS * 0.5, 0, 0), Vector4(ROOM_WIDTH, FLOOR_THICKNESS, ROOM_DEPTH, w_size), _make_material(FloorTexture))
	_add_panel(Vector4(0, WALL_HEIGHT + CEILING_THICKNESS * 0.5, 0, 0), Vector4(ROOM_WIDTH, CEILING_THICKNESS, ROOM_DEPTH, w_size), _make_material(CeilingTexture))


func _build_boundary_walls() -> void:
	var material := _make_material(BoundaryWallTexture)
	var w_size: float = STRUCTURE_W_HALF_EXTENT * 2.0
	var half_width: float = ROOM_WIDTH * 0.5
	var half_depth: float = ROOM_DEPTH * 0.5

	# Long side walls run the FULL depth (permanent, every w) so the only way
	# past the bypass wall is through its w-gap - never around it in x.
	_add_panel(Vector4(-half_width, WALL_HEIGHT * 0.5, 0, 0), Vector4(WALL_THICKNESS, WALL_HEIGHT, ROOM_DEPTH, w_size), material)
	_add_panel(Vector4(half_width, WALL_HEIGHT * 0.5, 0, 0), Vector4(WALL_THICKNESS, WALL_HEIGHT, ROOM_DEPTH, w_size), material)
	# Start-side and goal-side end walls.
	_add_panel(Vector4(0, WALL_HEIGHT * 0.5, -half_depth, 0), Vector4(ROOM_WIDTH, WALL_HEIGHT, WALL_THICKNESS, w_size), material)
	_add_panel(Vector4(0, WALL_HEIGHT * 0.5, half_depth, 0), Vector4(ROOM_WIDTH, WALL_HEIGHT, WALL_THICKNESS, w_size), material)


## The one wall that matters: solid across the full room width at every w
## except a GATE_GAP_HALF_WIDTH*2 window centred on GATE_GAP_W. Two segments
## flanking that gap - same trick as PhaseMaze's gate walls
## (phase_maze_builder.gd's _build_edge), just isolated to a single wall.
func _build_bypass_wall() -> void:
	var material := _make_material(BypassWallTexture)
	var near_half: float = (GATE_GAP_W + STRUCTURE_W_HALF_EXTENT - GATE_GAP_HALF_WIDTH) * 0.5
	var far_half: float = (STRUCTURE_W_HALF_EXTENT - GATE_GAP_W - GATE_GAP_HALF_WIDTH) * 0.5
	if near_half > 0.01:
		var near_center_w: float = -STRUCTURE_W_HALF_EXTENT + near_half
		_add_panel(Vector4(0, WALL_HEIGHT * 0.5, 0, near_center_w), Vector4(ROOM_WIDTH, WALL_HEIGHT, WALL_THICKNESS, near_half * 2.0), material)
	if far_half > 0.01:
		var far_center_w: float = GATE_GAP_W + GATE_GAP_HALF_WIDTH + far_half
		_add_panel(Vector4(0, WALL_HEIGHT * 0.5, 0, far_center_w), Vector4(ROOM_WIDTH, WALL_HEIGHT, WALL_THICKNESS, far_half * 2.0), material)


func _build_goal() -> void:
	var half_depth: float = ROOM_DEPTH * 0.5
	var full_w_size: float = STRUCTURE_W_HALF_EXTENT * 2.0
	var footprint := Vector2(ROOM_WIDTH - WALL_THICKNESS * 2.0, 3.0)
	var goal_center_z: float = -half_depth + WALL_THICKNESS + footprint.y * 0.5

	var pad_mesh := MeshInstance4D.new()
	var pad_box := BoxTetraMesh4D.new()
	pad_box.size = Vector4(footprint.x, 0.1, footprint.y, full_w_size)
	pad_box.cell_texture_map = BoxTetraMesh4D.BOX_CELL_TEXTURE_MAP_FILL_EACH_SIDE
	pad_mesh.mesh = pad_box
	pad_mesh.material_override = _make_material(GoalTexture)
	pad_mesh.position = Vector4(0, 0.05, goal_center_z, 0)
	add_child(pad_mesh)

	# Spans the full structural w range, not just the gap window - once
	# you've threaded the bypass, any further w drift while standing here
	# still counts as the finish.
	_goal_area = Area4D.new()
	_goal_area.position = Vector4(0, WALL_HEIGHT * 0.5, goal_center_z, 0)
	add_child(_goal_area)
	var collision_shape := CollisionShape4D.new()
	var shape := BoxShape4D.new()
	shape.size = Vector4(footprint.x, WALL_HEIGHT, footprint.y, full_w_size)
	collision_shape.shape = shape
	_goal_area.add_child(collision_shape)
	_goal_area.body_entered_self.connect(_on_goal_entered)


func _on_goal_entered(body: PhysicsBody4D) -> void:
	if body != player:
		return
	hud.show_goal_reached()


## Spawns facing -z (Basis4D identity's own forward), which already points
## at the goal since the goal sits at -half_depth - unlike PhaseMaze's
## arbitrary path directions, a single straight room needs no yaw math.
func _spawn_player() -> void:
	var half_depth: float = ROOM_DEPTH * 0.5
	player.global_position = Vector4(0, 1.0, half_depth - 1.5, 0.0)
