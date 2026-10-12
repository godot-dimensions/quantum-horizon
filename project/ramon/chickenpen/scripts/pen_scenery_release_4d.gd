extends Node

const Look := preload("res://ramon/chickenpen/look/pen_look_4d.gd")

## While you are deep in the cave, the pen's two biggest meshes are let go, and they are
## brought back in the background as you walk out.
##
## WHY THESE TWO. The pen holds about 308,000 tetrahedra - some 376 MB of video memory,
## every one of them resident whether or not it is drawn (a hidden mesh keeps its memory).
## The mountains (92,160) and the hill with the cave in it (81,749) are 56% of that, and
## both are baked files, so they can be dropped and read back. Everything else is 900-odd
## small meshes made when the pen starts - the chickens, the crows, Nike - which would have
## to be built again, and together they are less than either of these two.
##
## WHEN. Let go once you are past the corridor's second ring of lamps, going in, where no
## part of the pen could be on screen; read back once you are within the corridor's first
## stretch coming out, fifteen metres short of the daylight - well before the crossing, and
## on a worker thread, their drawable form built there too (Mesh4D.get_proxy_mesh_3d), so
## putting them back costs nothing on screen. The cave's own tunnel is between, so turning
## round on the way in or out does not flip them to and fro.
##
## A way home that skips the corridor (the V debug key) still finds them: whatever is not
## back by the time the pen is, is read back there and then.
##
## Ramon, 28 Sept: "i see pretty high numbers with working memory ... im just worried for
## performance" - measured in _verify_scenery_release_runner.gd.

const CaveRock := preload("res://ramon/chickenpen/cave/cave_rock_4d.gd")

@export var crossing_path: NodePath = NodePath("../../CaveCrossing")
@export var player_path: NodePath = NodePath("../../Player")
## The meshes to let go, by the nodes that show them.
@export var release_paths: Array[NodePath] = [NodePath("../../World/Hills"), NodePath("../../World/CaveHill")]
## How far into the cave, along its z, before they are let go, and how far back out before
## they are read back. The cave's arrival is at -0.5 and its daylight at 5.8.
@export var release_below_z: float = -14.0
@export var reload_above_z: float = -10.0

var _crossing: Node
var _player: Node4D
var _nodes: Array[MeshInstance4D] = []
var _paths: PackedStringArray = []
var _released := false
var _task := -1
## Filled by the worker, index-matched to _nodes; taken on the main thread.
var _loaded: Array = []


func _ready() -> void:
	# The cave's crossing puts parts of the pen to sleep; this has to keep watching.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_crossing = get_node_or_null(crossing_path)
	_player = get_node_or_null(player_path) as Node4D
	for path in release_paths:
		var node := get_node_or_null(path) as MeshInstance4D
		# The mesh each really has: the dev look may have taken one off (look/pen_look_4d.gd), and
		# letting go and taking back go through it too, so neither undoes the other.
		var own: Mesh4D = Look.own_mesh(node) if node != null else null
		if own != null and own.resource_path != "":
			_nodes.append(node)
			_paths.append(own.resource_path)


## Whether the meshes are let go right now - for the tests.
func is_released() -> bool:
	return _released


func _process(_delta: float) -> void:
	if _crossing == null or _player == null:
		return
	var away: bool = bool(_crossing.call("is_away"))
	if not away:
		if _released:
			_take_back(true)
		return
	var cave: Node4D = _crossing.get("_theatre") as Node4D
	if cave == null or not is_instance_valid(cave):
		return
	var local: Vector4 = cave.global_basis.inverse() * (_player.global_position - cave.global_position)
	var z: float = local.z
	if not _released and _task < 0 and z < release_below_z:
		for node in _nodes:
			Look.assign_mesh(node, null)
		_released = true
	# Only on the way out: the far room, out along W, reaches back to z -7, which is no
	# nearer the daylight than its middle is.
	elif _released and _task < 0 and z > reload_above_z and local.w < CaveRock.FLOOR_SPLIT_W:
		_task = WorkerThreadPool.add_task(_load_in_background, false, "pen scenery")
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		_take_back(false)


## On a worker thread: each mesh read back and made drawable.
func _load_in_background() -> void:
	var out: Array = []
	for path in _paths:
		var mesh: Resource = ResourceLoader.load(path)
		if mesh != null and mesh.has_method("get_proxy_mesh_3d"):
			mesh.call("get_proxy_mesh_3d")
		out.append(mesh)
	_loaded = out


## Puts them back: from the worker if it is done, or - [param now] - read here and then.
func _take_back(now: bool) -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	elif now:
		_load_in_background()
	for i in _nodes.size():
		if i < _loaded.size() and _loaded[i] != null:
			Look.assign_mesh(_nodes[i], _loaded[i])
	_loaded = []
	_released = false
