extends SceneTree

## The legs close up while they walk, goat then wolf, to check the joints (the round beads in every
## hip and knee, goat_walk_4d.gd joint_balls). To res://smoke_test_output/goat_room/joints/.
##
##   LabChambers/scripts/lab_run.sh windowed joints res://ramon/LabChambers/scripts/_capture_joints_runner.gd

const SCENE := "res://ramon/LabChambers/creation_lab.tscn"
const OUT := "res://smoke_test_output/goat_room/joints/"
const Mark := preload("res://ramon/LabKit/lab_mark_4d.gd")

var _g: Node


func _initialize() -> void:
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run.call_deferred()


func _process(_dt: float) -> bool:
	return false


func _wait(s: float) -> void:
	var until: int = Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


func _shot(what: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + what + ".png")
	print("shot ", what)


var _cam: Camera4D


func _legs(sc: Node, tag: String) -> void:
	sc.set("autoplay", false)
	sc.set("cinematic", true)
	var walk_i: int = 4
	for view in [[Vector4(4.6, 1.9, -0.4, 0.0), "a"], [Vector4(-1.2, 1.7, 3.4, 0.0), "b"]]:
		_cam.global_position = view[0]
		_cam.global_basis = Mark.basis_looking(_cam.global_position, Vector4(0.0, 1.75, -1.5, 0.0))
		for k in 4:
			var t0: float = 2.0 + float(k) * 0.26
			for i in 6:
				sc.call("play", walk_i, t0 + float(i) * 0.002)
				await process_frame
			await _shot("%s_%s_walk_%d" % [tag, view[1], k])
	sc.call("end_cinematic")
	sc.set("autoplay", true)


func _run() -> void:
	_g = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_g)
	current_scene = _g
	for nm in ["tuner", "tuner_room2"]:
		var t: Control = _g.get(nm)
		if t != null:
			t.visible = false
	_g.get_node("Room").call("set_mood", "dark", true, false)
	await _wait(4.0)
	var sc: Node = _g.get_node("Showcase")
	var p: CharacterBody4D = _g.get("player")
	var rig: Node = p.get_node("CameraRig")
	rig.set("_zoom_target", 2.4)
	rig.set("distance", 2.4)
	rig.set("pivot_height", 1.7)
	rig.set("_home_pivot", 1.7)
	p.global_position = Vector4(1.0, 0.05, 3.3, 0.0)
	p.set("_facing", 0.25 + PI)
	rig.set("yaw", 0.25)
	rig.set("pitch", deg_to_rad(-4.0))
	rig.call("_apply")
	_cam = Camera4D.new()
	_cam.set("rendering_engine_name", "Cross-section")
	_g.add_child(_cam)
	_cam.current = true
	for c in _g.get_children():
		if c is CanvasLayer:
			(c as CanvasLayer).visible = false
	await _wait(0.5)
	await _legs(sc, "goat")
	_g.call("pick", 2)
	await _wait(3.4)
	await _legs(sc, "wolf")
	quit(0)
