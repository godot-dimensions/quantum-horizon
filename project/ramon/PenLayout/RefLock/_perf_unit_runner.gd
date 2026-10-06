extends SceneTree

## What a unit costs in the pen (PenLayout/PLAN_REF_LOCK.md steps 20 and 58): the pen loaded, the
## player's camera looking at the unit from where you would first see it, the GPU's own render time
## (RenderingServer's measured viewport time, which vsync does not touch) averaged over blocks of
## frames with the unit shown and hidden in turn, and the difference.
##
##   lab_run.sh windowed perf_<name> res://ramon/PenLayout/RefLock/_perf_unit_runner.gd \
##       node=World/LookoutSite/Lookout at=-18,1.2,-20 yaw=200 [blocks=6] [frames=60]

var _args: Dictionary = {}
var _room: Node


func _initialize() -> void:
	root.unfocusable = true
	for a in OS.get_cmdline_user_args():
		var i: int = a.find("=")
		if i > 0:
			_args[a.substr(0, i)] = a.substr(i + 1)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_run.call_deferred()


func _wait_frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	_room = (load("res://ramon/chickenpen/playable_world.tscn") as PackedScene).instantiate()
	for node in _room.find_children("*", "", true, false):
		if "debug_key_enabled" in node:
			node.set("debug_key_enabled", false)
	root.add_child(_room)
	current_scene = _room
	await _wait_frames(90)
	var unit := _room.get_node_or_null(String(_args.get("node", "World/LookoutSite/Lookout"))) as Node4D
	if unit == null:
		print("PERF: no unit at ", _args.get("node"))
		quit(1)
		return
	var player := _room.get_node("Player") as Node4D
	player.set("input_enabled", false)
	var at: PackedStringArray = String(_args.get("at", "-18,1.2,-20")).split(",")
	player.global_position = Vector4(float(at[0]), float(at[1]), float(at[2]), 0.0)
	var rig: Node = _room.get_node("Player/CameraRig")
	rig.set("yaw", deg_to_rad(float(_args.get("yaw", "200"))))
	rig.set("pitch", deg_to_rad(float(_args.get("pitch", "-8"))))
	if rig.has_method("_apply"):
		rig.call("_apply")
	var vp: RID = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	await _wait_frames(30)
	var blocks: int = int(_args.get("blocks", "6"))
	var frames: int = int(_args.get("frames", "60"))
	var gpu := {"on": [], "off": []}
	var cpu := {"on": [], "off": []}
	for b in blocks:
		var on: bool = b % 2 == 0
		unit.visible = on
		await _wait_frames(10)
		for f in frames:
			await process_frame
			(gpu["on" if on else "off"] as Array).append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
			(cpu["on" if on else "off"] as Array).append(RenderingServer.viewport_get_measured_render_time_cpu(vp))
	unit.visible = true
	var mean := func(a: Array) -> float:
		var s: float = 0.0
		for v in a:
			s += float(v)
		return s / maxf(float(a.size()), 1.0)
	var tets: int = 0
	for mi in unit.find_children("*", "MeshInstance4D", true, false):
		var m: Variant = (mi as MeshInstance4D).mesh
		if m is TetraMesh4D:
			tets += (m as TetraMesh4D).get_simplex_cell_vertex_indices().size() / 4
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://smoke_test_output/reflock/perf_%s.png" % String(_args.get("tag", "unit"))))
	print("PERF %s: %d tetrahedra | GPU %.3f ms shown, %.3f ms hidden, cost %.3f ms | render CPU %.3f / %.3f ms" % [
		String(_args.get("node")), tets, mean.call(gpu["on"]), mean.call(gpu["off"]), mean.call(gpu["on"]) - mean.call(gpu["off"]),
		mean.call(cpu["on"]), mean.call(cpu["off"])])
	quit(0)
