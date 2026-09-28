extends Node

## Loads the far room (cave_far.tscn) only when it could be seen, and lets it go again.
##
## FOR MEMORY, NOT FRAME TIME. Drawing the cave costs about 1.3 ms a frame with the far
## room in it; what it costs is memory - 61,000 tetrahedra, about 76 MB of video memory,
## and sixteen lamps - held all the time for a room you only reach through W (Ramon,
## 28 Sept: "i see pretty high numbers with working memory ... im just worried for
## performance"). So the room is a scene of its own and is only in the tree while you
## might be looking at it.
##
## WHEN IT CAN BE SEEN. All of it lies past w = 12, and nothing past w = 6 is on the slice
## you arrive in. It can only come into view once you turn the slice through W, or step off
## w = 0 - so either starts the load, on a thread, while you are still turning; the room is
## at the far end of a twenty-metre tunnel, well past where the turn first shows anything.
## And it is let go once you have been back on the flat slice, at w = 0, for [member linger]
## seconds, so turning back and forth does not load it over and over.
##
## LET GO MEANS FREED. Nothing but the instance holds the loaded scene or its mesh, so when
## the instance goes, so does the mesh and the video memory under it.
##
## BUILT OFF THE MAIN THREAD. Loading was never the slow part; the first frame the room was
## drawn in was - 141 ms, measured - because that is when the renderer turns its 61,000
## tetrahedra into the 730,000-vertex mesh it actually draws. That build is cached on the
## mesh (Mesh4D.get_proxy_mesh_3d), so it is done here, on a worker thread, before the room
## is put in the tree, and its first frame has nothing left to do.

@export_file("*.tscn") var scene_path: String = "res://ramon/chickenpen/cave/cave_far.tscn"
## The scene's baked mesh, whose drawable form is built in the background.
@export_file("*.res") var mesh_path: String = "res://ramon/chickenpen/terrain/baked/cave_far.res"
@export var player_path: NodePath = NodePath("../../Player")
@export var rig_path: NodePath = NodePath("../../Player/CameraRig")
## How far the slice has to be turned through W, or how far off w = 0 you have to be,
## before the room is loaded.
@export_range(1.0, 60.0, 1.0) var turn_degrees: float = 12.0
@export_range(0.1, 6.0, 0.1) var step_w: float = 1.0
## How long back on the flat slice before it is let go.
@export_range(0.5, 30.0, 0.5) var linger: float = 3.0

var _player: Node4D
var _rig: Node
var _far: Node4D
var _task := -1
## Set by the worker when it is done; taken and dropped on the main thread.
var _packed: PackedScene
var _idle := 0.0


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node4D
	_rig = get_node_or_null(rig_path)


## On a worker thread: the scene, and its mesh made drawable. The mesh is the same object the
## scene refers to - a second load of a loaded resource is the cached one.
func _load_in_background() -> void:
	var packed := ResourceLoader.load(scene_path) as PackedScene
	var mesh: Resource = ResourceLoader.load(mesh_path)
	if mesh != null and mesh.has_method("get_proxy_mesh_3d"):
		mesh.call("get_proxy_mesh_3d")
	_packed = packed


## Leaving the cave: the pen keeps the cave for next time, and a far room left in it would
## be kept too, for as long as you are anywhere else.
func _exit_tree() -> void:
	if is_loaded():
		_far.queue_free()
	_far = null
	_idle = 0.0


## Whether the room is in the tree - for the tests.
func is_loaded() -> bool:
	return _far != null and is_instance_valid(_far)


func _process(delta: float) -> void:
	if _player == null:
		return
	var cave := get_parent() as Node4D
	var local: Vector4 = cave.global_basis.inverse() * (_player.global_position - cave.global_position)
	var turned := 0.0
	if _rig != null:
		turned = maxf(absf(float(_rig.get("_slice_xw"))), absf(float(_rig.get("_slice_zw"))))
	var wanted: bool = turned > deg_to_rad(turn_degrees) or absf(local.w) > step_w
	_idle = 0.0 if wanted else _idle + delta
	if wanted and not is_loaded() and _task < 0:
		_task = WorkerThreadPool.add_task(_load_in_background, false, "far room")
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		if _packed == null:
			push_warning("FarStream: could not load %s" % scene_path)
		elif not is_loaded():
			_far = _packed.instantiate() as Node4D
			cave.add_child(_far)
		# Only the instance holds it from here, so letting it go frees it.
		_packed = null
	if is_loaded() and _idle > linger:
		_far.queue_free()
		_far = null
