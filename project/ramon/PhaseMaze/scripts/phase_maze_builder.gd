extends Node4D
## Procedurally builds a 4x4 grid maze whose only route from start to goal
## requires shifting position.w through several disjoint windows to pass a
## handful of "gate" walls. Most maze walls are permanent (solid at every w),
## but a gate wall is really two wall segments with a gap between them in w,
## so it's solid everywhere except a narrow w window - the same "finite
## w-extent = only solid/visible within that slice" trick holodeck_ramon.gd
## and every floor tile in this project already rely on, just applied to a
## maze doorway instead of a backdrop panel.
##
## The maze is one single snaking path visiting every cell (a boustrophedon
## "S" sweep) rather than a branching maze - guarantees exactly one route and
## makes hand-picking gate placements straightforward, at the cost of no
## dead ends/branches to explore.
##
## Reaching the goal needs no new tracking UI: player.tscn's own
## PositionLabel already prints live position (including w), and Q/E
## (move_kata/move_ana) already move the player's actual w directly through
## player.gd's normal input handling - no slice-rotation is required to
## solve this, just straight strafing in w like any other axis.

const GRID_COLS := 4
const GRID_ROWS := 4
const CELL_SIZE := 4.0
const WALL_THICKNESS := 0.4
const WALL_HEIGHT := 3.0
const FLOOR_THICKNESS := 0.5
const CEILING_THICKNESS := 0.4

## Permanent geometry (floor/ceiling/permanent walls) spans this much of w
## either side of 0 - comfortably covers every gate's own w window below
## with margin, so nothing structural vanishes while working a gate.
const STRUCTURE_W_HALF_EXTENT := 12.0

const GATE_GAP_HALF_WIDTH := 1.5 # Total passable window per gate = 3m of w.

## Single path visiting all 16 cells - a boustrophedon "S" sweep.
const PATH := [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),
	Vector2i(3, 1), Vector2i(2, 1), Vector2i(1, 1), Vector2i(0, 1),
	Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2),
	Vector2i(3, 3), Vector2i(2, 3), Vector2i(1, 3), Vector2i(0, 3),
]

## Transition index i means the edge between PATH[i] and PATH[i+1] becomes a
## gate instead of an open passage. Each gap_w is deliberately far from the
## others (and from the spawn w of 0) so clearing all three means actually
## traveling through w, not parking at one favorite value.
const GATE_AFTER_PATH_INDEX := [4, 9, 13]
const GATE_GAP_W := [-6.0, 2.0, 7.0]

const FloorTexture := preload("res://textures/dev_finals/ramdev_blue.png")
const CeilingTexture := preload("res://textures/dev_finals/ramdev_black.png")
const InnerWallTexture := preload("res://textures/dev_finals/ramdev_grey.png")
const BoundaryWallTexture := preload("res://textures/dev_finals/ramdev_black_metal.png")
const GateWallTexture := preload("res://textures/dev_finals/ramdev_yellow.png")
const GoalTexture := preload("res://textures/dev_finals/ramdev_red.png")
## Needs to be reimported as a 3D Texture (Import dock -> Import As -> 3D
## Texture, 1x1 slices, same as textures/tutorial/testrange2.png) before this
## loads correctly - TetraMaterial4D's texture sources are all Texture3D
## (mapped onto tetrahedral cell UVW), and this file was dragged in as a
## plain 2D texture by default.
const TutorialTexture := preload("res://ramon/textures/phaze_maze_new.png")

## Old flat/unlit fake-lighting the engine's cross-section shader used before
## Aaron's real 4D light system replaced it - see the shader file for why.
const FlatShadedShader := preload("res://ramon/PhaseMaze/shaders/phase_maze_flat_shaded.gdshader")

const GRID_ORIGIN_X := -GRID_COLS * CELL_SIZE * 0.5
const GRID_ORIGIN_Z := -GRID_ROWS * CELL_SIZE * 0.5

@onready var player: CharacterBody4D = $"../Player"
@onready var hud: Control = $"../../MazeHud"

var _goal_area: Area4D


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.0, 0.0, 0.0, 1.0))

	var open_edges: Dictionary = {} # edge key -> "open" String, or a gate's gap_w float.
	for i in range(PATH.size() - 1):
		var key: String = _edge_key(PATH[i], PATH[i + 1])
		var gate_index: int = GATE_AFTER_PATH_INDEX.find(i)
		open_edges[key] = float(GATE_GAP_W[gate_index]) if gate_index != -1 else "open"

	_build_floor_and_ceiling()
	_build_boundary_walls()
	_build_internal_walls_and_gates(open_edges)
	_build_goal()

	# The only exit from the corner start cell - used to spawn the player
	# already facing it (rather than the closest permanent wall, which is
	# what the default unrotated facing pointed at) and to place the
	# tutorial billboard so it's in view without blocking that exit.
	var forward: Vector2 = (_cell_center(PATH[1]) - _cell_center(PATH[0])).normalized()
	_spawn_player_at_start(forward)
	_build_tutorial_billboard()


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(
		GRID_ORIGIN_X + cell.x * CELL_SIZE + CELL_SIZE * 0.5,
		GRID_ORIGIN_Z + cell.y * CELL_SIZE + CELL_SIZE * 0.5,
	)


## Canonical (order-independent) key for the shared edge between two
## grid-adjacent cells, used to look an edge up regardless of which cell it
## was reached from.
func _edge_key(a: Vector2i, b: Vector2i) -> String:
	var lo: Vector2i = a if (a.x < b.x or (a.x == b.x and a.y < b.y)) else b
	var hi: Vector2i = b if lo == a else a
	return "%d,%d-%d,%d" % [lo.x, lo.y, hi.x, hi.y]


func _make_material(texture: Texture3D) -> TetraMaterial4D:
	var material := TetraMaterial4D.new()
	material.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_TEXTURE3D_CELL_UVW_ONLY
	# Swap the engine's cross-section shader for the flat-shaded copy BEFORE
	# pushing the texture - Material4D only assigns its built-in shader when
	# the slot is empty, so once this is set it survives; setting the texture
	# afterwards re-runs update_cross_section_material() and pushes
	# albedo_texture at the replacement rather than leaving it unbound.
	var cross_section: ShaderMaterial = material.get_cross_section_material()
	cross_section.shader = FlatShadedShader
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
	var width: float = GRID_COLS * CELL_SIZE
	var depth: float = GRID_ROWS * CELL_SIZE
	var w_size: float = STRUCTURE_W_HALF_EXTENT * 2.0
	_add_panel(Vector4(0, -FLOOR_THICKNESS * 0.5, 0, 0), Vector4(width, FLOOR_THICKNESS, depth, w_size), _make_material(FloorTexture))
	_add_panel(Vector4(0, WALL_HEIGHT + CEILING_THICKNESS * 0.5, 0, 0), Vector4(width, CEILING_THICKNESS, depth, w_size), _make_material(CeilingTexture))


func _build_boundary_walls() -> void:
	var material := _make_material(BoundaryWallTexture)
	var w_size: float = STRUCTURE_W_HALF_EXTENT * 2.0
	var min_x: float = GRID_ORIGIN_X
	var max_x: float = GRID_ORIGIN_X + GRID_COLS * CELL_SIZE
	var min_z: float = GRID_ORIGIN_Z
	var max_z: float = GRID_ORIGIN_Z + GRID_ROWS * CELL_SIZE

	for cz in range(GRID_ROWS):
		var z: float = GRID_ORIGIN_Z + cz * CELL_SIZE + CELL_SIZE * 0.5
		_add_panel(Vector4(min_x, WALL_HEIGHT * 0.5, z, 0), Vector4(WALL_THICKNESS, WALL_HEIGHT, CELL_SIZE, w_size), material)
		_add_panel(Vector4(max_x, WALL_HEIGHT * 0.5, z, 0), Vector4(WALL_THICKNESS, WALL_HEIGHT, CELL_SIZE, w_size), material)
	for cx in range(GRID_COLS):
		var x: float = GRID_ORIGIN_X + cx * CELL_SIZE + CELL_SIZE * 0.5
		_add_panel(Vector4(x, WALL_HEIGHT * 0.5, min_z, 0), Vector4(CELL_SIZE, WALL_HEIGHT, WALL_THICKNESS, w_size), material)
		_add_panel(Vector4(x, WALL_HEIGHT * 0.5, max_z, 0), Vector4(CELL_SIZE, WALL_HEIGHT, WALL_THICKNESS, w_size), material)


func _build_internal_walls_and_gates(open_edges: Dictionary) -> void:
	var inner_material := _make_material(InnerWallTexture)
	var gate_material := _make_material(GateWallTexture)
	var full_w_size: float = STRUCTURE_W_HALF_EXTENT * 2.0

	# Each internal edge is only visited once (via its lower-index cell's +x/+z
	# neighbor), matching _edge_key's canonical ordering.
	for cx in range(GRID_COLS):
		for cz in range(GRID_ROWS):
			var cell := Vector2i(cx, cz)
			if cx + 1 < GRID_COLS:
				_build_edge(cell, Vector2i(cx + 1, cz), open_edges, inner_material, gate_material, full_w_size)
			if cz + 1 < GRID_ROWS:
				_build_edge(cell, Vector2i(cx, cz + 1), open_edges, inner_material, gate_material, full_w_size)


func _build_edge(a: Vector2i, b: Vector2i, open_edges: Dictionary, inner_material: TetraMaterial4D, gate_material: TetraMaterial4D, full_w_size: float) -> void:
	var key: String = _edge_key(a, b)
	var state: Variant = open_edges.get(key, null)
	if typeof(state) == TYPE_STRING and state == "open":
		return # Part of the solve path - no wall at all.

	var mid: Vector2 = (_cell_center(a) + _cell_center(b)) * 0.5
	var vertical_edge: bool = a.x != b.x # True: a fixed-x plane spanning z. False: a fixed-z plane spanning x.
	var horizontal_size: Vector4 = Vector4(WALL_THICKNESS, WALL_HEIGHT, CELL_SIZE, 0) if vertical_edge else Vector4(CELL_SIZE, WALL_HEIGHT, WALL_THICKNESS, 0)

	if state == null:
		# Not on the solve path and not a gate - a permanent, all-w wall
		# that blocks this shortcut no matter what w the player is on.
		var size := Vector4(horizontal_size.x, horizontal_size.y, horizontal_size.z, full_w_size)
		_add_panel(Vector4(mid.x, WALL_HEIGHT * 0.5, mid.y, 0), size, inner_material)
		return

	# Gate: two segments flanking a gap in w, rather than one solid panel -
	# solid everywhere except a GATE_GAP_HALF_WIDTH*2 window centered on gap_w.
	var gap_w: float = state
	var near_half: float = (gap_w + STRUCTURE_W_HALF_EXTENT - GATE_GAP_HALF_WIDTH) * 0.5
	var far_half: float = (STRUCTURE_W_HALF_EXTENT - gap_w - GATE_GAP_HALF_WIDTH) * 0.5
	if near_half > 0.01:
		var near_center_w: float = -STRUCTURE_W_HALF_EXTENT + near_half
		var near_size := Vector4(horizontal_size.x, horizontal_size.y, horizontal_size.z, near_half * 2.0)
		_add_panel(Vector4(mid.x, WALL_HEIGHT * 0.5, mid.y, near_center_w), near_size, gate_material)
	if far_half > 0.01:
		var far_center_w: float = gap_w + GATE_GAP_HALF_WIDTH + far_half
		var far_size := Vector4(horizontal_size.x, horizontal_size.y, horizontal_size.z, far_half * 2.0)
		_add_panel(Vector4(mid.x, WALL_HEIGHT * 0.5, mid.y, far_center_w), far_size, gate_material)


func _build_goal() -> void:
	var center: Vector2 = _cell_center(PATH[PATH.size() - 1])
	var full_w_size: float = STRUCTURE_W_HALF_EXTENT * 2.0
	var footprint := Vector2(CELL_SIZE - WALL_THICKNESS, CELL_SIZE - WALL_THICKNESS)

	var pad_mesh := MeshInstance4D.new()
	var pad_box := BoxTetraMesh4D.new()
	pad_box.size = Vector4(footprint.x, 0.1, footprint.y, full_w_size)
	pad_box.cell_texture_map = BoxTetraMesh4D.BOX_CELL_TEXTURE_MAP_FILL_EACH_SIDE
	pad_mesh.mesh = pad_box
	pad_mesh.material_override = _make_material(GoalTexture)
	pad_mesh.position = Vector4(center.x, 0.05, center.y, 0)
	add_child(pad_mesh)

	# Spans the full structural w range (not just the last gate's window) -
	# once you've threaded every gate to physically reach this cell, any
	# further w drift while standing in it still counts as the finish.
	_goal_area = Area4D.new()
	_goal_area.position = Vector4(center.x, WALL_HEIGHT * 0.5, center.y, 0)
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


## Basis4D.from_zx(angle)'s z column is (sin(angle), 0, cos(angle), 0) and
## forward is -z (see Basis4D::from_zx in the 4d module source) - solving
## -sin(angle) = forward.x and -cos(angle) = forward.y for angle gives this,
## the absolute yaw that makes -z (and so -basis.z, "forward") point along
## forward exactly, with y and w left untouched (a pure horizontal turn).
func _yaw_facing(forward: Vector2) -> float:
	return atan2(-forward.x, -forward.y)


func _spawn_player_at_start(forward: Vector2) -> void:
	var center: Vector2 = _cell_center(PATH[0])
	player.global_position = Vector4(center.x, 1.0, center.y, 0.0)
	player.global_basis = Basis4D.from_zx(_yaw_facing(forward))


## A plaque flush-mounted on the start cell's own north wall (the (0,0)-(0,1)
## boundary - always a permanent wall, since that pair is never adjacent in
## PATH), rather than a freestanding panel floating at a diagonal - reads as
## an actual mounted sign, and needs no rotation at all since it shares the
## wall's own axis-aligned orientation (thin in z, spanning x), same as every
## other wall panel _add_panel builds.
func _build_tutorial_billboard() -> void:
	var center: Vector2 = _cell_center(PATH[0])
	var wall_z: float = center.y + CELL_SIZE * 0.5

	var mesh_instance := MeshInstance4D.new()
	var box := BoxTetraMesh4D.new()
	box.size = Vector4(3.0, 2.0, 0.12, 3.0) # Matches the 1536x1024 (3:2) source image's aspect exactly, sized to fill most of the wall's own 4m width with margin.
	box.cell_texture_map = BoxTetraMesh4D.BOX_CELL_TEXTURE_MAP_FILL_EACH_SIDE
	mesh_instance.mesh = box
	mesh_instance.material_override = _make_material(TutorialTexture)
	# Just in front of the wall's near (player-facing) face, not centered on
	# the wall itself, so it doesn't z-fight with the wall panel behind it.
	mesh_instance.position = Vector4(center.x, 1.6, wall_z - WALL_THICKNESS * 0.5 - 0.05, 0)
	add_child(mesh_instance)
