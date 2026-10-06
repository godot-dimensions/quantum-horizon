extends SceneTree

## The range's room from the places that matter (plan steps 6 to 8): the corridor and its sign, the
## firing line looking downrange, each wing from the line, the line seen from downrange, and the plan
## from above. Frames in smoke_test_output/quantum_range/room/.
##
##   range_run.sh windowed room res://ramon/QuantumRange/scripts/_capture_room_runner.gd

const SCENE := "res://ramon/QuantumRange/quantum_range_final.tscn"
const OUT := "res://smoke_test_output/quantum_range/room/"

var _cam: Camera4D
var _t0: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 90000:
		print("ROOM: gave up after 90 s")
		return true
	return false


func _look(eye: Vector4, at: Vector4) -> void:
	var d: Vector4 = at - eye
	var yaw: float = atan2(-d.x, -d.z)
	var pitch: float = atan2(d.y, maxf(Vector2(d.x, d.z).length(), 0.0001))
	_cam.global_position = eye
	_cam.global_basis = Basis4D.from_zx(yaw) * Basis4D.from_yz(pitch)


func _shot(name: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("ROOM: saved ", name)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var t: int = Time.get_ticks_usec()
	var scene: Node = (load(SCENE) as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	print("ROOM: instanced in %.1f ms" % ((Time.get_ticks_usec() - t) / 1000.0))
	_cam = Camera4D.new()
	_cam.set("rendering_engine_name", "Cross-section")
	_cam.set("view_angle_type", 1)
	_cam.set("field_of_view_4d", 1.3962634)
	scene.add_child(_cam)
	_cam.make_current()
	# The walls print themselves over a few frames.
	for i in 30:
		await process_frame
	var n: int = 0
	for c in scene.find_children("*", "MeshInstance4D", true, false):
		n += 1
	print("ROOM: %d mesh instances" % n)
	_look(Vector4(0, 1.7, 19.8, 0), Vector4(0, 2.6, 0, 0))
	await _shot("01_corridor")
	_look(Vector4(0, 1.7, 1.5, 0), Vector4(0, 2.4, -30, 0))
	await _shot("02_line_downrange")
	_look(Vector4(0, 1.7, 1.5, 0), Vector4(-9.0, 4.25, 6.5, 0))
	await _shot("03_explainer")
	_look(Vector4(0, 1.7, 1.5, 0), Vector4(9.0, 4.25, 6.5, 0))
	await _shot("04_metrics")
	_look(Vector4(0, 2.0, -30, 0), Vector4(0, 2.0, 4, 0))
	await _shot("05_from_downrange")
	_look(Vector4(0, 3.0, 11.5, 0), Vector4(0, 2.4, -20, 0))
	await _shot("06_bay")
	# Each wall from the middle of the bay, where you arrive.
	_look(Vector4(-1.0, 1.7, 8.5, 0), Vector4(-9.0, 4.0, 6.5, 0))
	await _shot("08_explainer_close")
	_look(Vector4(1.0, 1.7, 8.5, 0), Vector4(9.0, 4.0, 6.5, 0))
	await _shot("09_metrics_close")
	# Where each blue wall ends at the line: framed by the white wall where the bay meets the hall, from
	# the bay and from downrange.
	_look(Vector4(-5.5, 1.7, 3.0, 0), Vector4(-9.0, 3.0, 0.0, 0))
	await _shot("10_wall_end_from_bay")
	_look(Vector4(-5.0, 1.7, -4.0, 0), Vector4(-9.5, 3.0, 0.0, 0))
	await _shot("11_wall_end_from_downrange")
	_look(Vector4(5.5, 1.7, 3.0, 0), Vector4(9.0, 3.0, 0.0, 0))
	await _shot("12_wall_end_right")
	_cam.global_position = Vector4(0, 70, -12, 0)
	_cam.global_basis = Basis4D.from_yz(-PI * 0.5 + 0.0001)
	await _shot("07_top")
	print("ROOM: done")
	quit()
