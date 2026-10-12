extends SceneTree

## From the chicken pen to the final range and back (5 Oct: the pen's range trip now opens
## quantum_range_final.tscn). The range master says yes, the pen is parked and the range opens as the
## current scene with its return prompt saying the pen; H, then on a second trip Escape, bring back THE
## SAME pen with the belt as it was. The same checks as the pen's own chickenpen/scripts/
## _verify_range_runner.gd, which still names the old gallery, run here against the new range.
## Frames in smoke_test_output/quantum_range/pen_trip/.
##
##   range_run.sh windowed pen_trip res://ramon/QuantumRange/scripts/_verify_pen_trip_runner.gd

const PEN := "res://ramon/chickenpen/playable_world.tscn"
const RANGE := "res://ramon/QuantumRange/quantum_range_final.tscn"
const OUT := "res://smoke_test_output/quantum_range/pen_trip/"

var _pen: Node
var _pen_id: int = 0
var _fails: int = 0
var _t0: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_x: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 180000:
		print("TRIP: gave up after 180 s")
		return true
	return false


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("  %s  %s  %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_fails += 1


func _shot(name: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("   saved ", name)


func _wait(s: float) -> void:
	await create_timer(s).timeout


func _key(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		Input.parse_input_event(e)
		await process_frame


func _label_of(scene: Node) -> String:
	var button: Node = scene.get_node_or_null("ReturnButton")
	return String(button.call("get_label_text")) if button != null else "(no button)"


## Stands you by the range master and says yes; returns the scene that opened.
func _go_to_range() -> Node:
	var head: Node4D = _pen.get_node("World/Range/RangeMasterHead")
	var player := _pen.get_node("Player") as CharacterBody4D
	player.global_position = Vector4(head.global_position.x + 1.6, 0.05, head.global_position.z, 0.0)
	player.linear_velocity = Vector4.ZERO
	await _wait(0.3)
	var driver: Node = _pen.get_node("Systems/RangeMasterDriver")
	_check("the range master can be talked to at the booth", bool(driver.call("_can_talk")))
	driver.call("_on_effect", "go_range")
	driver.call("_ended")
	await _wait(2.0)
	return current_scene


func _back_in_pen(how: String) -> void:
	_check("%s brings back the same pen" % how, current_scene == _pen and _pen.is_inside_tree() and _pen.get_instance_id() == _pen_id)
	_check("with the belt as it was", bool(_pen.get_node("UI/Inventory").call("has_item", "found_watch")))
	_check("and the pen's camera in charge", bool(_pen.get_node("Player/CameraRig/Pitch/Camera4D").get("current")))
	_check("and the way home taken down", not root.has_meta("chickenpen_way_home"))
	var gone: bool = true
	for child in root.get_children():
		if child.scene_file_path == RANGE:
			gone = false
	_check("and the range gone", gone)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_pen = (load(PEN) as PackedScene).instantiate()
	root.add_child(_pen)
	current_scene = _pen
	_pen_id = _pen.get_instance_id()
	await _wait(2.0)
	_pen.get_node("UI/Inventory").call("add_item", "found_watch")

	# There, by H.
	var now: Node = await _go_to_range()
	_check("yes opens the final range", now != null and now.scene_file_path == RANGE, now.scene_file_path if now != null else "none")
	_check("the pen is parked, not freed", is_instance_valid(instance_from_id(_pen_id)) and not _pen.is_inside_tree())
	_check("its way back says the pen", _label_of(now).contains("CHICKEN PEN"), "\"%s\"" % _label_of(now))
	var d: Node = now.get("director")
	_check("the range starts in its lobby", d != null and String(d.get("state")) == "lobby")
	(now.get("sfx") as Node).set("muted", true)
	d.set("keep_bests", false)
	(now.get("player") as Node).set("input_enabled", false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _shot("1_range_from_the_pen")
	d.call("start", 0)
	await _wait(3.5)
	_check("a stage runs there", String(d.get("state")) == "stage", String(d.get("state")))
	await _shot("2_stage_from_the_pen")
	await _key(KEY_H)
	await _wait(1.0)
	await _back_in_pen("H")
	await _shot("3_back_in_the_pen")

	# There again, by Escape.
	now = await _go_to_range()
	_check("a second trip opens the range again", now != null and now.scene_file_path == RANGE)
	if now != null and now.get("player") != null:
		(now.get("player") as Node).set("input_enabled", false)
		(now.get("sfx") as Node).set("muted", true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _key(KEY_ESCAPE)
	await _wait(1.0)
	await _back_in_pen("Escape")
	print("TRIP: %d failed" % _fails)
	quit()
