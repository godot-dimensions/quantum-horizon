extends SceneTree

## The range's rune stone (PenLayout/PLAN_WATCHSTONE.md step 13): the range is illustration now,
## nothing at it shoots, and the stone by the table is the button to the Quantum Range. Away from
## it there is no prompt; beside it "F  To the range" comes up and the range master, a few metres
## off, does not take the key; F parks the pen and opens the final range; H brings back the same
## pen. Also: no RangeShooting in Systems, no booth in the yard. Frames in
## smoke_test_output/pen_layout/rune_stone/.
##
##   lab_run.sh windowed rune_stone res://ramon/chickenpen/scripts/_verify_rune_stone_runner.gd

const PEN := "res://ramon/chickenpen/playable_world.tscn"
const RANGE := "res://ramon/QuantumRange/quantum_range_final.tscn"
const OUT := "res://smoke_test_output/pen_layout/rune_stone/"

var _pen: Node
var _pen_id: int = 0
var _fails: int = 0
var _t0: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_x: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 90000:
		print("RUNE STONE: gave up after 90 s")
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


func _put(at: Vector4) -> void:
	var player := _pen.get_node("Player") as CharacterBody4D
	player.global_position = at
	player.linear_velocity = Vector4.ZERO


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_pen = (load(PEN) as PackedScene).instantiate()
	for node in _pen.find_children("*", "", true, false):
		if "debug_key_enabled" in node:
			node.set("debug_key_enabled", false)
	root.add_child(_pen)
	current_scene = _pen
	_pen_id = _pen.get_instance_id()
	await _wait(2.5)
	_pen.get_node("UI/Inventory").call("add_item", "found_watch")

	_check("no shooting at the range: no RangeShooting", _pen.get_node_or_null("Systems/RangeShooting") == null)
	_check("and no booth", _pen.get_node_or_null("World/Range/RangeBooth") == null)
	var stone := _pen.get_node_or_null("World/Range/RuneStone") as Node4D
	_check("the rune stone is there", stone != null)
	if stone == null:
		print("RUNE STONE: %d failed" % _fails)
		quit(1)
		return
	var cam := _pen.get_node("Player/CameraRig/Pitch/Camera4D") as Camera4D
	cam.make_current()
	# Away from it, out on the path: nothing.
	_put(stone.global_position + Vector4(5.0, 0.6, 0.0, 0.0))
	await _wait(0.6)
	_check("away from it, F would not send you", not bool(stone.call("can_press")))
	# Beside it, on the path's side.
	_put(stone.global_position + Vector4(1.1, 0.6, 0.0, 0.0))
	var rig: Node = _pen.get_node("Player/CameraRig")
	rig.call("face_toward", Vector4(-1.0, 0.0, 0.3, 0.0))
	await _wait(0.8)
	_check("beside it, F would send you", bool(stone.call("can_press")))
	var master: Node = _pen.get_node("Systems/RangeMasterDriver")
	_check("and the range master does not take the key", not bool(master.call("_can_talk")))
	_check("the prompt is up", String(stone.get("_shown")) == "F  To the range", "\"%s\"" % String(stone.get("_shown")))
	await _shot("1_by_the_stone")
	await _key(KEY_F)
	await _wait(2.0)
	var now: Node = current_scene
	_check("F opens the final range", now != null and now.scene_file_path == RANGE, now.scene_file_path if now != null else "none")
	_check("the pen is parked, not freed", is_instance_valid(instance_from_id(_pen_id)) and not _pen.is_inside_tree())
	if now != null and now.scene_file_path == RANGE:
		if now.get("player") != null:
			(now.get("player") as Node).set("input_enabled", false)
		if now.get("sfx") != null:
			(now.get("sfx") as Node).set("muted", true)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		await _shot("2_at_the_range")
		await _key(KEY_H)
		await _wait(1.0)
	_check("H brings back the same pen", current_scene == _pen and _pen.is_inside_tree())
	_check("with the belt as it was", bool(_pen.get_node("UI/Inventory").call("has_item", "found_watch")))
	await _shot("3_back")
	print("RUNE STONE: %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(1 if _fails > 0 else 0)
