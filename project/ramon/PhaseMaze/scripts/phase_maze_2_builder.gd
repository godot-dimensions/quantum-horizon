extends Node4D
## Level 2 of the phase maze - the escalation over phase_maze_builder.gd's
## level 1: a real branching maze (a randomized spanning tree over the grid,
## generated fresh every time this scene loads) instead of a single
## hand-authored snaking path, so dead-end branches are actually worth
## exploring/backing out of - not just a corridor with a few w-shifting
## doorways in it.
##
## Gates (see phase_maze_builder.gd's own comment for the underlying trick -
## two wall segments with a gap between them in w) are placed only along the
## tree's actual diameter (the longest start-to-goal route, found via a
## double breadth-first search - the standard trick for finding a tree's
## longest path without checking every pair of cells). Every other
## spanning-tree edge (the branches/dead ends off that route) stays a plain
## open passage, so only the "real" solution path demands shifting w -
## wrong turns cost exploration time instead of another w puzzle.

const GRID_COLS := 5
const GRID_ROWS := 5
const CELL_SIZE := 4.0
const WALL_THICKNESS := 0.4
const WALL_HEIGHT := 3.0
const FLOOR_THICKNESS := 0.5
const CEILING_THICKNESS := 0.4

const STRUCTURE_W_HALF_EXTENT := 12.0
const GATE_GAP_HALF_WIDTH := 1.5

## Same disjoint w windows level 1 uses - familiar to a player who just
## cleared it, so the novelty here is the maze's topology, not relearning
## what a gate means.
const GATE_GAP_W := [-6.0, 2.0, 7.0]

## White floor (level 1's only unused dev texture) - a deliberate visual tell
## that you're in a different maze, at a glance, before you've even read the
## HUD.
const FloorTexture := preload("res://textures/dev_finals/ramdev_white.png")
const CeilingTexture := preload("res://textures/dev_finals/ramdev_black.png")
const InnerWallTexture := preload("res://textures/dev_finals/ramdev_grey.png")
const BoundaryWallTexture := preload("res://textures/dev_finals/ramdev_black_metal.png")
const GateWallTexture := preload("res://textures/dev_finals/ramdev_yellow.png")
const GoalTexture := preload("res://textures/dev_finals/ramdev_red.png")

## Old flat/unlit fake-lighting the engine's cross-section shader used before
## Aaron's real 4D light system replaced it - see the shader file for why.
const FlatShadedShader := preload("res://ramon/PhaseMaze/shaders/phase_maze_flat_shaded.gdshader")

const GRID_ORIGIN_X := -GRID_COLS * CELL_SIZE * 0.5
const GRID_ORIGIN_Z := -GRID_ROWS * CELL_SIZE * 0.5

@onready var player: CharacterBody4D = $"../Player"
@onready var hud: Control = $"../../MazeHud"

var _goal_area: Area4D

## Every gate this run built, as {"position": Vector2(x, z), "gap_w": float} -
## read externally by maze_hud_2.gd's w-alignment gizmo, same convention
## phase_maze_builder.gd's own _gates uses for level 1.
var _gates: Array[Dictionary] = []


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.0, 0.0, 0.0, 1.0))

	var tree_edges: Dictionary = _generate_spanning_tree()
	# Double BFS: the farthest cell from an arbitrary corner is guaranteed to
	# be one end of the tree's diameter; the farthest cell from THAT end is
	# the other - together they give the longest possible route through this
	# specific maze, rather than whatever short route happened to generate.
	var first_pass: Dictionary = _bfs(Vector2i(0, 0), tree_edges)
	var start_cell: Vector2i = first_pass.farthest
	var second_pass: Dictionary = _bfs(start_cell, tree_edges)
	var goal_cell: Vector2i = second_pass.farthest
	var path: Array[Vector2i] = _reconstruct_path(start_cell, goal_cell, second_pass.parents)

	var open_edges: Dictionary = {} # edge key -> "open" String, or a gate's gap_w float.
	for key in tree_edges.keys():
		open_edges[key] = "open"
	for gate in _pick_gates(path):
		open_edges[_edge_key(path[gate.index], path[gate.index + 1])] = gate.gap_w

	_build_floor_and_ceiling()
	_build_boundary_walls()
	_build_internal_walls_and_gates(open_edges)
	_build_goal(goal_cell)
	_spawn_player_at_start(path)


## Randomized depth-first "recursive backtracker" - the standard perfect-
## maze algorithm: every cell visited exactly once, every visited cell
## connected by exactly one path (no loops, no isolated pockets), which is
## what makes every generated layout solvable by construction.
func _generate_spanning_tree() -> Dictionary:
	var visited: Dictionary = {Vector2i(0, 0): true}
	var tree_edges: Dictionary = {}
	var stack: Array[Vector2i] = [Vector2i(0, 0)]
	while not stack.is_empty():
		var current: Vector2i = stack[stack.size() - 1]
		var unvisited: Array[Vector2i] = []
		for neighbor in _grid_neighbors(current):
			if not visited.has(neighbor):
				unvisited.append(neighbor)
		if unvisited.is_empty():
			stack.pop_back()
			continue
		var next: Vector2i = unvisited[randi() % unvisited.size()]
		tree_edges[_edge_key(current, next)] = true
		visited[next] = true
		stack.append(next)
	return tree_edges


func _grid_neighbors(cell: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	if cell.x > 0:
		neighbors.append(Vector2i(cell.x - 1, cell.y))
	if cell.x < GRID_COLS - 1:
		neighbors.append(Vector2i(cell.x + 1, cell.y))
	if cell.y > 0:
		neighbors.append(Vector2i(cell.x, cell.y - 1))
	if cell.y < GRID_ROWS - 1:
		neighbors.append(Vector2i(cell.x, cell.y + 1))
	return neighbors


func _tree_neighbors(cell: Vector2i, tree_edges: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for neighbor in _grid_neighbors(cell):
		if tree_edges.has(_edge_key(cell, neighbor)):
			result.append(neighbor)
	return result


## Breadth-first search from start over the spanning tree only. Returns the
## farthest cell reached (the last one dequeued - guaranteed by BFS's
## level-by-level order) plus a parent pointer for every reached cell, used
## to walk the unique path back to start afterward.
func _bfs(start: Vector2i, tree_edges: Dictionary) -> Dictionary:
	var parents: Dictionary = {start: start}
	var queue: Array[Vector2i] = [start]
	var farthest: Vector2i = start
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		farthest = current
		for neighbor in _tree_neighbors(current, tree_edges):
			if not parents.has(neighbor):
				parents[neighbor] = current
				queue.append(neighbor)
	return {"parents": parents, "farthest": farthest}


func _reconstruct_path(start: Vector2i, goal: Vector2i, parents: Dictionary) -> Array[Vector2i]:
	var path: Array[Vector2i] = [goal]
	var current: Vector2i = goal
	while current != start:
		current = parents[current]
		path.append(current)
	path.reverse()
	return path


## Up to GATE_GAP_W.size() gates, evenly spaced along the solution path -
## the same 25/50/75%-style spacing phase_maze_builder.gd hand-picked for its
## fixed snake, just computed from whatever length this run's random path
## turns out to be.
func _pick_gates(path: Array[Vector2i]) -> Array[Dictionary]:
	var edge_count: int = path.size() - 1
	var count: int = mini(GATE_GAP_W.size(), edge_count)
	var gates: Array[Dictionary] = []
	var used_indices: Dictionary = {}
	for i in range(count):
		var idx: int = clampi(int(float(i + 1) / float(count + 1) * edge_count), 0, edge_count - 1)
		if used_indices.has(idx):
			continue
		used_indices[idx] = true
		gates.append({"index": idx, "gap_w": GATE_GAP_W[i]})
	return gates


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
	var cross_section: ShaderMaterial = material.get_cross_section_material_3d()
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
		return # Part of the maze (trunk or a dead-end branch) - no wall at all.

	var mid: Vector2 = (_cell_center(a) + _cell_center(b)) * 0.5
	var vertical_edge: bool = a.x != b.x # True: a fixed-x plane spanning z. False: a fixed-z plane spanning x.
	var horizontal_size: Vector4 = Vector4(WALL_THICKNESS, WALL_HEIGHT, CELL_SIZE, 0) if vertical_edge else Vector4(CELL_SIZE, WALL_HEIGHT, WALL_THICKNESS, 0)

	if state == null:
		# Not part of the spanning tree at all - a permanent, all-w wall.
		var size := Vector4(horizontal_size.x, horizontal_size.y, horizontal_size.z, full_w_size)
		_add_panel(Vector4(mid.x, WALL_HEIGHT * 0.5, mid.y, 0), size, inner_material)
		return

	# Gate: two segments flanking a gap in w, rather than one solid panel -
	# solid everywhere except a GATE_GAP_HALF_WIDTH*2 window centered on gap_w.
	var gap_w: float = state
	_gates.append({"position": mid, "gap_w": gap_w})
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


func _build_goal(goal_cell: Vector2i) -> void:
	var center: Vector2 = _cell_center(goal_cell)
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


func _spawn_player_at_start(path: Array[Vector2i]) -> void:
	var center: Vector2 = _cell_center(path[0])
	player.global_position = Vector4(center.x, 1.0, center.y, 0.0)
	var forward: Vector2 = (_cell_center(path[1]) - center).normalized()
	player.global_basis = Basis4D.from_zx(_yaw_facing(forward))
