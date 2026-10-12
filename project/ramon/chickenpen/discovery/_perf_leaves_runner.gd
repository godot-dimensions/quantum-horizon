extends SceneTree

## Ramon's walkthrough item 17 (10 Oct): "slightly denser foliage ... Performance is the deciding factor. If increasing
## foliage density causes a noticeable performance impact, leave the trees as they are." Measures the GPU time of a
## tree-heavy view with the oaks' leaves as they are, or (more=1) with a quarter more (each oak's leaves_per_node set to
## its bake's count + 25% before the pen loads). Run it both ways and compare.
##
##   lab_run.sh windowed leaves_a res://ramon/chickenpen/discovery/_perf_leaves_runner.gd
##   lab_run.sh windowed leaves_b res://ramon/chickenpen/discovery/_perf_leaves_runner.gd more=1

const Oak := preload("res://ramon/chickenpen/scripts/pen_oak_4d.gd")

var _room: Node
var _t0: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 240000:
		print("LEAVES: gave up after 240 s")
		return true
	return false


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Before the pen enters the tree: every oak's leaves as its bake has them, or a quarter more. (Rebuilding oaks in a
## running pen breaks the W Exploder's copies of them, so each count is its own run.)
func _set_leaves(more: bool) -> void:
	for oak in _room.find_children("*", "Node4D", true, false):
		if oak.get_script() != Oak:
			continue
		var own: Array = Oak.LEAVES.get(String(oak.get("bake")), [16, 0.28])
		oak.set("leaves_per_node", int(round(float(own[0]) * 1.25)) if more else -1)


func _gpu_ms(frames: int) -> float:
	var vp: RID = root.get_viewport_rid()
	var total: float = 0.0
	await _frames(20)
	for i in frames:
		await process_frame
		total += RenderingServer.viewport_get_measured_render_time_gpu(vp)
	return total / float(frames)


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	OS.set_environment("PEN_LOOK", "art")
	_room = (load("res://ramon/chickenpen/playable_world.tscn") as PackedScene).instantiate()
	var more_leaves: bool = "more=1" in OS.get_cmdline_user_args()
	_set_leaves(more_leaves)
	root.add_child(_room)
	current_scene = _room
	await _frames(120)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var player: Node = _room.get_node("Player")
	player.set("input_enabled", false)
	# Over the oak belt by the start, looking across it.
	var cam := _room.get_node("World/TalkCam") as Node4D
	cam.global_position = Vector4(30.0, 6.0, 12.0, 0.0)
	var gap: Vector3 = Vector3(-8.0, -4.0, 22.0).normalized()
	var zc: Vector3 = -gap
	var xc: Vector3 = Vector3(0.0, 1.0, 0.0).cross(zc).normalized()
	var yc: Vector3 = zc.cross(xc)
	cam.global_basis = Projection(Vector4(xc.x, xc.y, xc.z, 0.0), Vector4(yc.x, yc.y, yc.z, 0.0), Vector4(zc.x, zc.y, zc.z, 0.0), Vector4(0, 0, 0, 1))
	cam.set("current", true)
	var runs: Array = []
	for i in 4:
		runs.append(await _gpu_ms(150))
	var avg: float = 0.0
	for r in runs:
		avg += float(r)
	avg /= float(runs.size())
	print("LEAVES: %s gpu %.2f ms %s" % ["a quarter more" if more_leaves else "as they are", avg, str(runs)])
	quit(0)
