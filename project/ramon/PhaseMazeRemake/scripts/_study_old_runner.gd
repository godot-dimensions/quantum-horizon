extends SceneTree

## The Phase Maze as it is, photographed for the remake's study (8 Oct): each level from the player's
## eyes at spawn and turned four ways, and from above at the W values where its gates open. Nothing is
## changed. Frames in smoke_test_output/phase_maze_remake/study/.
##
##   run.sh windowed study res://ramon/PhaseMazeRemake/scripts/_study_old_runner.gd

const LEVELS := [["l1", "res://ramon/PhaseMaze/phase_maze.tscn", [-6.0, 2.0, 7.0]], ["l2", "res://ramon/PhaseMaze/phase_maze_2.tscn", [-6.0, 0.0, 6.0]]]
const OUT := "res://smoke_test_output/phase_maze_remake/study/"

var _t0: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_x: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 150000:
		print("STUDY: gave up after 150 s")
		return true
	return false


func _shot(name: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("STUDY: ", name)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for lv in LEVELS:
		var scene: Node = (load(String(lv[1])) as PackedScene).instantiate()
		root.add_child(scene)
		current_scene = scene
		for i in 30:
			await process_frame
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		var player: Node4D = scene.find_child("Player", true, false)
		player.set_process_input(false)
		player.set_process_unhandled_input(false)
		var cams: Array = scene.find_children("*", "Camera4D", true, false)
		var pcam: Camera4D = cams[0] if not cams.is_empty() else null
		print("STUDY: %s player at %s, camera %s (%s, fov %s)" % [lv[0], str(player.global_position), pcam.get_path() if pcam else "none",
			pcam.get("rendering_engine_name") if pcam else "", str(pcam.get("field_of_view_4d")) if pcam else ""])
		var b0: Projection = player.basis
		for k in 4:
			player.basis = b0 * Basis4D.from_zx(PI * 0.5 * float(k))
			await _shot("%s_eye_%d" % [lv[0], k])
		player.basis = b0
		# From above, at the gate W values and at 0.
		var top := Camera4D.new()
		top.set("rendering_engine_name", "Cross-section")
		top.set("view_angle_type", 1)
		top.set("field_of_view_4d", deg_to_rad(70.0))
		(scene.find_child("MazeWorld", true, false) as Node).add_child(top)
		top.make_current()
		for w in [0.0] + Array(lv[2]):
			top.global_position = Vector4(0.0, 24.0, 0.01, float(w))
			top.global_basis = Basis4D.from_yz(-PI * 0.5 + 0.001)
			await _shot("%s_top_w%+.0f" % [lv[0], float(w)])
		scene.queue_free()
		for i in 4:
			await process_frame
	print("STUDY: done")
	quit()
