extends SceneTree

## Round 2 study (9 Oct; Ramon: "look again at creationlabs, for studying, just to be sure the vibes are
## accurate"): the Creation Lab as it is, read only, photographed from its own camera four ways round,
## then the old Phase Maze with the slice tilted part way (Ramon: "the irregular skewing of the original
## maze was also cool"). Nothing in either is changed. Frames in
## smoke_test_output/phase_maze_remake/study2/.
##   run.sh windowed study2 res://ramon/PhaseMazeRemake/scripts/_study_lab_runner.gd

const LAB := "res://ramon/CreationLab/creation_lab.tscn"
const OLD := "res://ramon/PhaseMaze/phase_maze.tscn"
const OUT := "res://smoke_test_output/phase_maze_remake/study2/"

var _t0: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_x: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 120000:
		print("STUDY2: gave up after 120 s")
		return true
	return false


func _wait(seconds: float) -> void:
	var t: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < int(seconds * 1000.0):
		await process_frame


func _shot(name: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("STUDY2: ", name)


func _quiet(scene: Node) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for n in scene.find_children("*", "", true, false):
		n.set_process_unhandled_input(false)
		n.set_process_input(false)
		if "input_enabled" in n:
			n.set("input_enabled", false)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var lab: Node = (load(LAB) as PackedScene).instantiate()
	root.add_child(lab)
	current_scene = lab
	await _wait(3.0)
	_quiet(lab)
	var rigs: Array = lab.find_children("CameraRig", "", true, false)
	var rig: Node4D = rigs[0] if not rigs.is_empty() else null
	print("STUDY2: lab rig %s" % (rig.get_path() if rig else "none"))
	await _shot("lab_0_spawn")
	if rig != null:
		for k in [1, 2, 3]:
			rig.basis = rig.basis * Basis4D.from_zx(PI * 0.5)
			if rig.has_method("_apply"):
				rig.call("_apply")
			await _wait(0.6)
			await _shot("lab_%d_turned_%d" % [k, k * 90])
	lab.queue_free()
	await _wait(0.5)
	# The old maze, its slice tilted part way and all the way, both planes.
	var old: Node = (load(OLD) as PackedScene).instantiate()
	root.add_child(old)
	current_scene = old
	await _wait(1.5)
	_quiet(old)
	var player: Node4D = old.find_child("Player", true, false)
	var b0: Projection = player.basis
	for t in [["old_level", 0.0, 0.0], ["old_xw_20", 20.0, 0.0], ["old_xw_45", 45.0, 0.0], ["old_zw_30", 0.0, 30.0], ["old_both_35", 35.0, 25.0]]:
		player.basis = b0 * Basis4D.from_xw(deg_to_rad(float(t[1]))) * Basis4D.from_zw(deg_to_rad(float(t[2])))
		await _wait(0.4)
		await _shot(String(t[0]))
	print("STUDY2: done")
	quit()
