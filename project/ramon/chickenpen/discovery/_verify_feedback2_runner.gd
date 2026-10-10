extends SceneTree

## RAMON'S 10 OCT WALKTHROUGH, PART TWO OF THE CHECKS (follow_up/pen_feedback_10oct.md): the HUD (the mode badge and
## I, the controls card's two groups and the sizes' bracket, F1 minimal HUD, F2 layout editing with a drag, Save and
## Reset), the meadow thought, the strange clock and Mithra, the stone altar and Alternative A. Frames in
## smoke_test_output/feedback_10oct_b/.
##
##   lab_run.sh windowed fb_verify2 res://ramon/chickenpen/discovery/_verify_feedback2_runner.gd

const SliceAngles := preload("res://ramon/chickenpen/scripts/slice_angles_4d.gd")
const Guide := preload("res://ramon/chickenpen/discovery/pen_w_guide_4d.gd")

var _room: Node
var _player: CharacterBody4D
var _rig: Node4D
var _out: String = "res://smoke_test_output/feedback_10oct_b/"
var _fails: int = 0
var _t0: int = 0


class RunnerGuard extends Node:
	func _input(event: InputEvent) -> void:
		if event.has_meta(&"runner"):
			return
		if event is InputEventKey or event is InputEventMouse or event is InputEventJoypadButton or event is InputEventJoypadMotion:
			get_viewport().set_input_as_handled()


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 300000:
		print("FEEDBACK2: gave up after 300 s")
		return true
	return false


func _check(ok: bool, what: String) -> void:
	print(("  PASS  " if ok else "  FAIL  ") + what)
	if not ok:
		_fails += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _wait(seconds: float) -> void:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	for i in 100000:
		if Time.get_ticks_msec() >= until:
			break
		await process_frame


func _save(name: String) -> void:
	await _frames(1)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(_out + name + ".png"))
	print("FRAME %s" % name)


func _place(p: Vector4, yaw: float, pitch: float = -8.0, dist: float = 6.0) -> void:
	_player.global_position = p
	_player.linear_velocity = Vector4.ZERO
	SliceAngles.tilt(_rig, 0.0, 0.0, deg_to_rad(yaw))
	_rig.set("pitch", deg_to_rad(pitch))
	_rig.set("distance", dist)
	_rig.set("_zoom_target", dist)
	_rig.call("_apply")


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		e.set_meta(&"runner", true)
		Input.parse_input_event(e)
		await _frames(2)


## Mouse events in window pixels: the HUD's coordinates are the canvas's, which the UI size scales.
func _mouse(at: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = at * root.content_scale_factor
	e.global_position = at * root.content_scale_factor
	e.set_meta(&"runner", true)
	Input.parse_input_event(e)
	await _frames(2)


func _move(at: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = at * root.content_scale_factor
	e.global_position = at * root.content_scale_factor
	e.set_meta(&"runner", true)
	Input.parse_input_event(e)
	await _frames(2)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	OS.set_environment("PEN_LOOK", "art")
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_room = (load("res://ramon/chickenpen/playable_world.tscn") as PackedScene).instantiate()
	root.add_child(_room)
	current_scene = _room
	var guard := RunnerGuard.new()
	guard.name = "RunnerGuard"
	root.add_child(guard)
	await _frames(90)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_player = _room.get_node("Player") as CharacterBody4D
	_rig = _player.get_node("CameraRig") as Node4D
	await _wait(2.0)
	var tutor: Node = _room.get_node_or_null("Systems/Tutor")
	if tutor != null:
		var shown: Dictionary = tutor.get("_shown")
		for k in ["move", "ana", "moved", "home", "deliver"]:
			shown[k] = true
	var look: Node = _room.get_node("Systems/Look")
	var badge: Node = _room.get_node_or_null("UI/LookBadge")
	var controls: Control = _room.get_node("UI/Controls") as Control

	# --- The HUD: the badge, I, the controls card ----------------------------------------------------------------------
	_place(Vector4(24.9, 1.2, 20.0, 0.0), 180.0, -6.0, 6.0)
	await _wait(1.0)
	_check(badge != null and (badge as Control).visible, "the mode badge is up")
	await _save("01_hud_art")
	await _key(KEY_I)
	await _wait(0.2)
	await _save("02_badge_changing")
	await _wait(0.8)
	_check(bool(look.get("dev")), "I switched to the dev look")
	await _save("03_hud_dev")
	await _key(KEY_I)
	await _wait(0.6)
	var r: Rect2 = controls.get_global_rect()
	_check(r.size.x > r.size.y, "the controls card is wider than tall now (%.0f x %.0f)" % [r.size.x, r.size.y])
	var size_card: Control = controls.get_node_or_null("SizeCard") as Control
	_check(size_card != null and size_card.visible, "the sizes have their own bracket")

	# --- F1 minimal HUD ---------------------------------------------------------------------------------------------
	await _key(KEY_F1)
	await _wait(0.6)
	var quests := _room.get_node("UI/Quests") as Control
	_check(not controls.visible and not quests.visible, "F1: the controls and the to-do list are hidden")
	_check((_room.get_node("UI/Inventory") as Control).visible and (_room.get_node("UI/SlicePlane") as Control).visible and (badge as Control).visible, "F1: the belt, the dial and the badge stay")
	await _save("04_minimal_hud")
	await _key(KEY_F1)
	await _wait(0.6)
	_check(controls.visible and quests.visible, "F1 again: all back")

	# --- F2 layout editing: drag the to-do list, save, reset ----------------------------------------------------------
	var editor: Node = _room.get_node("Systems/UiLayout")
	editor.set("verbose", true)
	await _key(KEY_F2)
	await _wait(0.4)
	_check(bool(editor.get("editing")), "F2: layout editing on")
	await _save("05_layout_edit")
	var qr: Rect2 = quests.get_global_rect()
	# Low on the card: the editor's bar of buttons sits over the top of the screen.
	var grab: Vector2 = qr.position + Vector2(qr.size.x * 0.5, qr.size.y - 24.0)
	var before: Vector2 = quests.global_position
	print("LAYOUT: to-do rect %s, grab %s, card there '%s', canvas %s, factor %s" % [str(qr), str(grab), String(editor.call("_card_at", grab)), str(root.get_visible_rect().size), str(root.content_scale_factor)])
	await _move(grab)
	await _mouse(grab, true)
	print("LAYOUT: drag after press %s" % str(editor.get("_drag")))
	await _move(grab + Vector2(0.0, 220.0))
	print("LAYOUT: layout after move %s" % str(editor.get("_layout")))
	await _mouse(grab + Vector2(0.0, 220.0), false)
	await _wait(0.4)
	_check(quests.global_position.y > before.y + 150.0, "dragged the to-do list down (%.0f to %.0f)" % [before.y, quests.global_position.y])
	await _save("06_layout_dragged")
	editor.call("_save")
	_check(FileAccess.file_exists("user://pen_ui_layout.cfg"), "Save UI Location wrote the layout")
	editor.call("_reset")
	await _wait(0.4)
	_check(absf(quests.global_position.y - before.y) < 4.0, "Reset UI Layout put it back")
	_check(not FileAccess.file_exists("user://pen_ui_layout.cfg"), "and removed the saved layout")
	await _key(KEY_F2)
	await _wait(0.3)

	# --- The meadow thought at the camp ---------------------------------------------------------------------------------
	_place(Vector4(18.0, 1.2, -3.0, -2.5), -85.0, -4.0, 6.0)
	await _wait(2.0)
	var thought: Node = _room.get_node("Systems/MeadowThought")
	_check(bool(thought.get("said")), "looking out east from the camp, the meadow thought came")
	await _save("07_meadow_thought")
	await _wait(4.0)

	# --- The strange clock and Mithra -------------------------------------------------------------------------------
	_place(Vector4(36.0, 1.2, -12.0, 0.0), -90.0, -10.0, 5.0)
	await _wait(6.5)
	_check(Guide.spent.has("meadow_clock"), "lingering by the meadow's edge brought the chip")
	await _save("08_clock_chip")
	var clock: Node4D = _room.get_node("World/Pickups/MeadowClock") as Node4D
	_place(clock.global_position + Vector4(0.0, 0.4, 0.0, 0.0), -90.0, -18.0, 3.5)
	await _wait(0.8)
	var inv: Node = _room.get_node("UI/Inventory")
	_check(bool(inv.call("has_item", "found_clock")), "the clock is in the belt")
	await _save("09_clock_found")
	await _wait(3.4)
	var mithra_driver: Node = _room.get_node("Systems/MithraDriver")
	var anchor: Node4D = mithra_driver.call("_anchor") as Node4D
	var at: Vector4 = anchor.global_position
	_place(Vector4(at.x + 1.4, 1.2, at.z, at.w), 90.0, -8.0, 4.0)
	mithra_driver.set("_met", true)
	await _wait(0.6)
	await _key(KEY_F)
	await _wait(1.6)
	await _save("10_mithra_clock")
	await _key(KEY_SPACE)
	await _wait(1.4)
	await _key(KEY_SPACE)
	await _wait(1.8)
	await _save("11_mithra_hawk")
	for i in 8:
		if not bool((_room.get_node("Systems/MithraTalk")).call("is_running")):
			break
		await _key(KEY_SPACE)
		await _wait(0.9)
	_check(not bool(inv.call("has_item", "found_clock")), "Mithra took the clock")

	# --- The stone altar and Alternative A --------------------------------------------------------------------------
	_place(Vector4(24.9, 1.2, 33.5, 0.0), 160.0, -6.0, 7.0)
	await _wait(1.0)
	await _save("12_altar_and_alt_a")
	_place(Vector4(24.2, 1.2, 29.0, 0.0), 90.0, -4.0, 4.0)
	await _wait(0.8)
	await _save("13_altar_close")
	look.call("set_dev", true)
	await _wait(0.8)
	await _save("14_altar_dev")
	print("FEEDBACK2: %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(0 if _fails == 0 else 1)
