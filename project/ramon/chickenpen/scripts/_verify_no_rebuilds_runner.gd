extends SceneTree

## Does anything in the pen rebuild its mesh while the game is simply running?
##
## WHY THIS TEST EXISTS. Trym's profiling on 27 Sept put the pen at 6.8 fps and 67% of every
## frame in `proxy_fetch` - the 4D renderer rebuilding the 3D proxy of a mesh that has been
## marked dirty. His harness can only see the average cost of a fetch, so it reported 492
## meshes rebuilding at 196 us each. Counting them showed 19: the eighteen chicken legs and
## Nike's hide, all of them skinned, every one rebuilt every physics tick. The other ~480
## fetches were free cache hits being averaged in.
##
## HOW IT SEES THEM. Mesh4D emits `proxy_mesh_3d_marked_dirty` whenever its proxy is
## invalidated, under any renderer including the headless one, so a connection on every mesh
## in the scene counts exactly the rebuilds the real renderer would do - no timing, no
## guesswork about which of 862 meshes is responsible.
##
## PER PHYSICS TICK, NOT PER FRAME. The headless loop runs process frames faster than the
## 60 Hz physics clock, and the skinning that caused this lived in _physics_process, so a
## per-frame count would be divided by a ratio that depends on how busy the machine is.
##
## WHAT IT ALLOWS. A mesh that genuinely has to change shape may do so, but the whole pen
## has a budget: at ~2.5 us per tetrahedron rebuilt, BUDGET_TETS per tick is well under a
## millisecond. Anything above that is a regression somebody should look at.

const SCENE := "res://ramon/chickenpen/playable_world.tscn"
const WARMUP_TICKS := 60
const WINDOW_TICKS := 240
const BUDGET_TETS := 300

var _room: Node
var _ticks: int = 0
var _armed: bool = false
var _hits: Dictionary = {}
var _info: Dictionary = {}


func _initialize() -> void:
	_room = load(SCENE).instantiate()
	root.add_child(_room)
	current_scene = _room
	physics_frame.connect(_on_tick)


func _tets(mesh: Mesh4D) -> int:
	if mesh is BoxTetraMesh4D:
		return 40
	if mesh.has_method("get_simplex_cell_vertex_indices"):
		return int((mesh.call("get_simplex_cell_vertex_indices") as PackedInt32Array).size() / 4)
	return 0


func _arm(node: Node) -> void:
	var mi := node as MeshInstance4D
	if mi != null and mi.mesh != null:
		var mesh: Mesh4D = mi.mesh
		var id: int = mesh.get_instance_id()
		if not _info.has(id):
			_info[id] = [str(_room.get_path_to(mi)), _tets(mesh)]
			_hits[id] = 0
			mesh.proxy_mesh_3d_marked_dirty.connect(func() -> void:
				if _armed:
					_hits[id] += 1)
	for c in node.get_children():
		_arm(c)


func _on_tick() -> void:
	_ticks += 1
	if _ticks == WARMUP_TICKS:
		_arm(_room)
		_armed = true
	elif _ticks == WARMUP_TICKS + WINDOW_TICKS:
		_armed = false
		_report()


func _report() -> void:
	var rows: Array = []
	var tets: float = 0.0
	var count: float = 0.0
	for id in _hits:
		if _hits[id] > 0:
			var per: float = float(_hits[id]) / WINDOW_TICKS
			rows.append([per * _info[id][1], per, _info[id][1], _info[id][0]])
			tets += per * _info[id][1]
			count += per
	rows.sort_custom(func(a, b): return a[0] > b[0])
	print("   %d meshes in the pen, %d invalidated at least once" % [_info.size(), rows.size()])
	print("   %.2f invalidations and %.0f tetrahedra rebuilt per physics tick (budget %d)" % [count, tets, BUDGET_TETS])
	for i in mini(12, rows.size()):
		var r: Array = rows[i]
		print("      %6.0f tets/tick   %.2f x %5d   %s" % [r[0], r[1], r[2], r[3]])
	var fails: int = 0
	var ok: bool = tets <= BUDGET_TETS
	if not ok:
		fails += 1
	print("   %s the pen stays inside its rebuild budget" % ("PASS" if ok else "FAIL"))
	# AND NOTHING VANISHED TO GET THERE. The first version of the rigid hides divided the
	# tetrahedra into buckets that silently stayed empty, deleted Nike and both cats, and
	# passed the budget above perfectly - nothing left, nothing to rebuild. So each animal
	# that used to be skinned must still draw at least the tetrahedra it was skinned with.
	for pair in DRAWN:
		var node: Node = _room.get_node_or_null(String(pair[0]))
		var have: int = _drawn_tets(node) if node != null else 0
		var enough: bool = have >= int(pair[1])
		if not enough:
			fails += 1
		print("   %s %s still draws %d tetrahedra (it was skinned with %d)" % [
			"PASS" if enough else "FAIL", pair[0], have, pair[1]])
	print("\n%d FAIL(s)" % fails)
	quit(0 if fails == 0 else 1)


## Every animal whose mesh used to be rewritten each tick, and how many tetrahedra it had.
const DRAWN := [
	["World/Nike", 7008], ["World/Cat", 2928], ["World/RedCat", 2928],
	["Chickens/Chicken01", 1440], ["Chickens/Chicken05", 1440], ["Chickens/Chicken09", 1440],
]


func _drawn_tets(node: Node) -> int:
	var n: int = 0
	var mi := node as MeshInstance4D
	if mi != null and mi.is_visible_in_tree() and mi.mesh is ArrayTetraMesh4D:
		n += (mi.mesh as ArrayTetraMesh4D).get_simplex_cell_vertex_indices().size() / 4
	for c in node.get_children():
		n += _drawn_tets(c)
	return n
