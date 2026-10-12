extends SceneTree

## Plan step 14: the player walks in from the corridor to the firing line, steps through W to the bay's
## limit both ways, turns the slice and snaps it back. Checks print as PASS / FAIL; frames from the
## player's own camera go to smoke_test_output/quantum_range/player/.
##
##   range_run.sh windowed player res://ramon/QuantumRange/scripts/_verify_player_runner.gd

const SCENE := "res://ramon/QuantumRange/quantum_range_final.tscn"
const OUT := "res://smoke_test_output/quantum_range/player/"

var _range: Node
var _p: CharacterBody4D
var _t0: int = 0
var _fails: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 90000:
		print("PLAYER: gave up after 90 s")
		return true
	return false


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_fails += 1


func _shot(name: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _hold(action: StringName, seconds: float) -> void:
	Input.action_press(action)
	await create_timer(seconds).timeout
	Input.action_release(action)
	await physics_frame


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_range = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_range)
	current_scene = _range
	for i in 30:
		await process_frame
	_p = _range.get("player")
	_check(_p != null, "the range made a player")
	if _p == null:
		quit(1)
		return
	_check(_p.global_position.z > 15.0, "it starts in the corridor (z %.2f)" % _p.global_position.z)
	await _shot("01_spawn")
	await _hold(&"move_forward", 3.6)
	await create_timer(0.3).timeout
	var p: Vector4 = _p.global_position
	_check(p.z < 2.0 and p.z > 0.2, "walked through the door to the line, and the counter stops it (z %.2f)" % p.z)
	_check(absf(p.x) < 0.5, "straight down the middle (x %.2f)" % p.x)
	await _shot("02_at_line")
	await _hold(&"move_ana", 1.6)
	_check(absf(_p.global_position.w - 2.0) < 0.05, "E steps ana to the bay's limit, +2 m (w %.2f)" % _p.global_position.w)
	await _shot("03_w_plus2")
	await _hold(&"move_kata", 2.6)
	_check(absf(_p.global_position.w + 2.0) < 0.05, "Q steps kata to -2 m (w %.2f)" % _p.global_position.w)
	_check(float(_p.get("w_travelled")) > 5.9, "W travelled is counted (%.2f m)" % float(_p.get("w_travelled")))
	await _hold(&"move_ana", 0.9)
	_p.call("turn_slice", Vector2(-160.0, 0.0))
	var a: float = float(_p.call("slice_angle"))
	_check(a > 14.0 and a < 19.0, "a right drag turns the slice (%.1f degrees)" % a)
	await _shot("04_slice_turned")
	_p.call("look", Vector2(220.0, 0.0))
	_check(absf(float(_p.call("slice_angle")) - a) < 0.5, "turning to look keeps the slice turn (%.1f)" % float(_p.call("slice_angle")))
	_p.call("snap_slice")
	await create_timer(0.6).timeout
	_check(float(_p.call("slice_angle")) < 0.5, "X brings the slice back (%.2f degrees)" % float(_p.call("slice_angle")))
	var y: Vector4 = (_p.basis as Projection).y
	_check(y.is_equal_approx(Vector4(0, 1, 0, 0)), "the body stays upright")
	await _shot("05_snapped")
	_p.call("look", Vector2(-220.0, -90.0))
	await _shot("06_look_up")
	print("PLAYER: %d failed" % _fails)
	quit(1 if _fails > 0 else 0)
