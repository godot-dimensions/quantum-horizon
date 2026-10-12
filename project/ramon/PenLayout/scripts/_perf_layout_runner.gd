extends SceneTree

## Pen layout A (6 Oct 2026, PenLayout/PLAN_A.md steps 72 and 77): what the new things cost. The pen
## from the same camera (the player at the pen's gate looking north over it, the tower and the
## range in view), vsync off, the frame time averaged over 300 frames after 120 to settle, for:
##   paths off / paths on (icons and sand)
##   the tower, the shed and the booth on their old frames / on the fence frames
## and the tetrahedra in every mesh under each of the three buildings, old and new.
##
##   CreationLab/scripts/lab_run.sh windowed pl_perf res://ramon/PenLayout/scripts/_perf_layout_runner.gd

var _room: Node


func _initialize() -> void:
	root.unfocusable = true
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _cells(node: Node) -> int:
	var n: int = 0
	for mi in node.find_children("*", "MeshInstance4D", true, false):
		var mesh: Resource = (mi as MeshInstance4D).mesh
		if mesh is MultiSurfaceMesh4D:
			for sm in (mesh as MultiSurfaceMesh4D).surface_meshes:
				n += (sm.call("get_simplex_cell_vertex_indices") as PackedInt32Array).size() / 4
		elif mesh != null and mesh.has_method("get_simplex_cell_vertex_indices"):
			n += (mesh.call("get_simplex_cell_vertex_indices") as PackedInt32Array).size() / 4
	return n


func _measure(label: String) -> float:
	await _frames(120)
	var total: float = 0.0
	for i in 300:
		await process_frame
		total += root.get_process_delta_time()
	var ms: float = total / 300.0 * 1000.0
	print("FRAME %-34s %.2f ms" % [label, ms])
	return ms


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_room = (load("res://ramon/chickenpen/playable_world.tscn") as PackedScene).instantiate()
	root.add_child(_room)
	current_scene = _room
	var player := _room.get_node("Player") as CharacterBody4D
	player.set("input_enabled", false)
	player.global_position = Vector4(5.0, 1.2, 4.0, 0.0)
	var rig: Node4D = player.get_node("CameraRig") as Node4D
	rig.set("yaw", deg_to_rad(15.0))
	rig.set("pitch", deg_to_rad(-12.0))
	rig.call("_apply")
	var net: Node = _room.get_node("World/Paths")
	var tower: Node = _room.get_node("World/LookoutSite/Lookout")
	var shed: Node = _room.get_node("World/TrymCabin/Shed")
	var booth: Node = _room.get_node("World/Range/RangeBooth")
	await _frames(30)
	print("CELLS tower %d, shed %d, booth %d (old frames)" % [_cells(tower), _cells(shed), _cells(booth)])
	print("CELLS paths %d" % _cells(net))
	net.set("show_marks", false)
	net.set("show_sand", false)
	await _measure("paths off, old frames")
	net.set("show_marks", true)
	net.set("show_sand", true)
	await _measure("paths on, old frames")
	tower.set("fence_frame", true)
	shed.set("fence_frame", true)
	booth.set("fence_posts", true)
	await _frames(10)
	print("CELLS tower %d, shed %d, booth %d (fence frames)" % [_cells(tower), _cells(shed), _cells(booth)])
	await _measure("paths on, fence frames")
	print("PERF DONE")
	quit(0)
