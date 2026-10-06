extends SceneTree

## The blue walls' type as you see it, in the Creation Lab and in the range (Ramon, 6 Oct: "the blue
## walls should also have the same font sizes as the creation lab"). Both rooms hang the same kit panels
## (identical code: the same letters in metres), so what differs is how far you stand from them. Each
## wall is photographed from where you stand in each room, through the same 80 degree lens, and the
## panel's width on screen is measured from the frame. The Creation Lab is only opened and looked at.
## Frames in smoke_test_output/quantum_range/walls/.
##
##   range_run.sh windowed walls res://ramon/QuantumRange/scripts/_compare_walls_runner.gd

const LAB := "res://ramon/CreationLab/creation_lab.tscn"
const RANGE := "res://ramon/QuantumRange/quantum_range_final.tscn"
const OUT := "res://smoke_test_output/quantum_range/walls/"

var _t0: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_x: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 120000:
		print("WALLS: gave up after 120 s")
		return true
	return false


func _look(cam: Camera4D, from: Vector4, at: Vector4) -> void:
	var d: Vector4 = at - from
	var yaw: float = atan2(-d.x, -d.z)
	var pitch: float = atan2(d.y, Vector2(d.x, d.z).length())
	cam.global_position = from
	cam.global_basis = Basis4D.from_zx(yaw) * Basis4D.from_yz(pitch)


func _shot(name: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("WALLS: saved ", name)


func _open(path: String) -> Array:
	var scene: Node = (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 40:
		await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var cam := Camera4D.new()
	cam.set("rendering_engine_name", "Cross-section")
	cam.set("view_angle_type", 1)
	cam.set("field_of_view_4d", 1.3962634)
	scene.add_child(cam)
	cam.make_current()
	# Hide the HUDs so the walls are all there is.
	for n in scene.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	return [scene, cam]


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	# The Creation Lab: you stand at the ring's edge in front of the exhibit.
	var lab: Array = await _open(LAB)
	var eye := Vector4(0.0, 1.7, 2.3, 0.0)
	_look(lab[1], eye, Vector4(-6.5, 4.25, -7.0, 0.0))
	await _shot("lab_intro")
	_look(lab[1], eye, Vector4(10.0, 4.25, 3.0, 0.0))
	await _shot("lab_research")
	(lab[0] as Node).queue_free()
	for i in 4:
		await process_frame
	# The range: at the console in the middle of the bay, and at the counter.
	var rng: Array = await _open(RANGE)
	for at in [["console", Vector4(0.0, 1.7, 8.0, 0.0)], ["line", Vector4(0.0, 1.7, 1.5, 0.0)]]:
		_look(rng[1], at[1], Vector4(-9.0, 4.25, 6.5, 0.0))
		await _shot("range_explainer_from_" + String(at[0]))
		_look(rng[1], at[1], Vector4(9.0, 4.25, 6.5, 0.0))
		await _shot("range_metrics_from_" + String(at[0]))
	print("WALLS: done")
	quit()
