extends SceneTree

## Layout B, step 34 (PenLayout/PLAN_B.md; Ramon: "make sure trees are optimized to handle the placement of
## many"): frame and GPU time at five places along the route, with the planting (World/Trees, 104 plants)
## shown and hidden, and the share the planting costs. Vsync off, medians of 150 frames.
##
##   PEN_LOOK=art lab_run.sh windowed b_perf res://ramon/PenLayout/scripts/_perf_layout_b_runner.gd

const SliceAngles := preload("res://ramon/chickenpen/scripts/slice_angles_4d.gd")
const VIEWS := [
	["start", Vector4(24.9, 1.2, 19.5, 0), 180.0],
	["pen", Vector4(-8.0, 1.2, 37.1, 0), 90.0],
	["gate north", Vector4(-12.0, 1.2, 4.0, 0), 180.0],
	["tower road", Vector4(-14.0, 1.2, -10.0, 0), 15.0],
	["middle, looking west", Vector4(0.0, 1.2, 20.0, 0), 90.0],
]

var _room: Node
var _t0: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 600000:
		print("PERF: gave up")
		return true
	return false


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	_room = (load("res://ramon/chickenpen/playable_world.tscn") as PackedScene).instantiate()
	for node in _room.find_children("*", "", true, false):
		if "debug_key_enabled" in node:
			node.set("debug_key_enabled", false)
	root.add_child(_room)
	current_scene = _room
	await _frames(90)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var player := _room.get_node("Player") as CharacterBody4D
	player.set("input_enabled", false)
	var rig := player.get_node("CameraRig") as Node4D
	var trees := _room.get_node("World/Trees") as Node4D
	print("PERF: %d plants under World/Trees (%s stood again in W, %s spots refused)" % [trees.get_child_count(), str(trees.get("echo_count")), str(trees.get("echo_refused"))])
	# Flat, and the slice turned 20 degrees into W (7 Oct: the planting through W, pen_trees_4d.gd).
	for turn in [0.0, 20.0]:
		for v in VIEWS:
			await _view(v, turn, player, rig, trees)
	print("PERF DONE")
	quit(0)


func _view(v: Array, turn: float, player: CharacterBody4D, rig: Node4D, trees: Node4D) -> void:
	player.global_position = v[1]
	player.set("linear_velocity", Vector4.ZERO)
	SliceAngles.tilt(rig, deg_to_rad(turn), 0.0, deg_to_rad(float(v[2])))
	rig.set("pitch", deg_to_rad(-6.0))
	trees.visible = true
	var drawn: int = 0
	await _frames(30)
	for t in trees.get_children():
		var tree := (t as Node).get_node_or_null("Tree") as Node4D
		if tree != null and tree.visible:
			drawn += 1
	var with: Array = await _measure()
	trees.visible = false
	var without: Array = await _measure()
	print("PERF %s, slice turned %.0f: frame %.2f ms, GPU %.2f ms with the planting (%d of %d drawn, cull loop %d us); without it %.2f / %.2f: the planting costs %.2f ms GPU, %.2f ms frame" % [
		v[0], turn, with[0], with[1], drawn, trees.get_child_count(), int(trees.get("cull_usec")), without[0], without[1], with[1] - without[1], with[0] - without[0]])


## [frame ms, GPU ms], medians of 150 frames.
func _measure() -> Array:
	await _frames(20)
	var rid: RID = root.get_viewport_rid()
	var cpu: Array = []
	var gpu: Array = []
	var last: int = Time.get_ticks_usec()
	for k in 150:
		await process_frame
		var now: int = Time.get_ticks_usec()
		cpu.append((now - last) / 1000.0)
		last = now
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
	cpu.sort()
	gpu.sort()
	return [cpu[75], gpu[75]]
