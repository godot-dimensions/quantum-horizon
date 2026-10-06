extends SceneTree

## The flying chicken up close, for judging its flight (6 Oct: "improve the chicken animations to feel
## more natural"): one bird flown on a climbing line in the range, filmed at a fixed 30 fps from its side,
## its front and above, a frame every beat-tenth, then shot and filmed as it falls. Frames in
## smoke_test_output/quantum_range/chicken/, one strip per view.
##
##   range_run.sh clip chicken res://ramon/QuantumRange/scripts/_chicken_lab_runner.gd

const SCENE := "res://ramon/QuantumRange/quantum_range_final.tscn"
const CHICKEN := "res://ramon/QuantumRange/scripts/targets/target_chicken.gd"
const OUT := "res://smoke_test_output/quantum_range/chicken/"

var _r: Node
var _d: Node
var _cam: Camera4D
var _bird: Node4D
var _t0: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_x: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 240000:
		print("CHICKEN: gave up after 240 s")
		return true
	return false


func _frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw


func _save(name: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _look(from: Vector4, at: Vector4) -> void:
	var d: Vector4 = at - from
	_cam.global_position = from
	_cam.global_basis = Basis4D.from_zx(atan2(-d.x, -d.z)) * Basis4D.from_yz(atan2(d.y, Vector2(d.x, d.z).length()))


## Flies a fresh bird along +X and up from `start`, filming `frames` frames from `offset` (from the bird).
func _film(view: String, offset: Vector4, frames: int) -> void:
	var start := Vector4(-3.0, 2.5, -6.0, 0.0)
	_bird = _d.call("spawn", CHICKEN, start)
	_bird.set("path", func(_tt: Node4D, a: float) -> Vector4: return start + Vector4(2.2 * a, 1.1 * a - 0.15 * a * a, 0.0, 0.0))
	for i in 12:
		await _frame()
	for i in frames:
		_look(_bird.global_position + offset, _bird.global_position)
		await _frame()
		_save("%s_%02d" % [view, i])
	print("CHICKEN: filmed ", view)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for f in DirAccess.get_files_at(ProjectSettings.globalize_path(OUT)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(OUT).path_join(f))
	_r = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_r)
	current_scene = _r
	for i in 30:
		await _frame()
	_d = _r.get("director")
	_d.set("keep_bests", false)
	_d.set_process_unhandled_key_input(false)
	_r.set_process_unhandled_input(false)
	(_r.get("player") as Node).set("input_enabled", false)
	(_r.get("sfx") as Node).set("muted", true)
	(_r.get("hud") as Node).set("clean", true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_cam = Camera4D.new()
	_cam.set("rendering_engine_name", "Cross-section")
	_cam.set("view_angle_type", 1)
	_cam.set("field_of_view_4d", deg_to_rad(40.0))
	_r.add_child(_cam)
	_cam.make_current()
	# It flies along +X, so a camera at +Z sees its right side, one at +X its front, one above its back.
	await _film("side", Vector4(0.0, 0.2, 3.2, 0.0), 45)
	_bird.call("leave")
	await _film("front", Vector4(3.2, 0.3, 0.0, 0.0), 36)
	_bird.call("leave")
	await _film("top", Vector4(-0.4, 3.4, 0.01, 0.0), 24)
	# Shot: the fall.
	_bird.call("hit", "Bird", false, _bird.global_position)
	for i in 24:
		_look(_bird.global_position + Vector4(0.0, 0.6, 4.0, 0.0) if is_instance_valid(_bird) else _cam.global_position, _bird.global_position if is_instance_valid(_bird) else Vector4.ZERO)
		await _frame()
		_save("shot_%02d" % i)
	print("CHICKEN: done")
	quit()
