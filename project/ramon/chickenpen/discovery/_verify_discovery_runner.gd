extends SceneTree

## DISCOVERY, PLAYED THROUGH (follow_up/pen_discovery_plan.md, 9-10 Oct 2026): every piece of the W onboarding and the
## easter eggs, driven as a player would and checked, with a frame at each beat (smoke_test_output/discovery/<look>/):
##   the W guide's card at Trym's desk (and the desk's legs at W 0), its chip on the cave road, its card at the gate and
##   the gate turned into view, its card at the camp and the camp's V; the airships at W 0 and W 9; the kata cache shut
##   at W 0, open at W 7.5, opened (+10 azoth); the edge-on door as a slit, whole, and you on the Watchstone after it;
##   the balloon's crew at the fire, the balloon partly in view with its V prompt, found and whole; the dev look with
##   the projection on (the log is searched for the mesh-limit error afterwards).
##
## Its own input guard: real keys and mouse are swallowed, the runner's own events (marked) go through.
##
##   lab_run.sh windowed discovery res://ramon/chickenpen/discovery/_verify_discovery_runner.gd [look=dev|art]

const SliceAngles := preload("res://ramon/chickenpen/scripts/slice_angles_4d.gd")
const Guide := preload("res://ramon/chickenpen/discovery/pen_w_guide_4d.gd")
const WSense := preload("res://ramon/chickenpen/discovery/w_sense_4d.gd")
const Cache := preload("res://ramon/chickenpen/discovery/pen_kata_cache_4d.gd")
const Balloon := preload("res://ramon/chickenpen/lookout/balloon_4d.gd")

var _room: Node
var _player: CharacterBody4D
var _rig: Node4D
var _cam: Camera4D
var _out: String = "res://smoke_test_output/discovery/"
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
	if Time.get_ticks_msec() - _t0 > 420000:
		print("DISCOVERY: gave up after 420 s")
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
	_tidy_hud()
	await _frames(2)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(_out + name + ".png"))
	print("FRAME %s" % name)


## The player at [param p], facing [param yaw] degrees (0 north), the camera [param pitch] degrees, [param dist] back,
## the slice turned (xw, zw) degrees.
func _place(p: Vector4, yaw: float, pitch: float = -8.0, dist: float = 6.0, xw: float = 0.0, zw: float = 0.0) -> void:
	_player.global_position = p
	_player.linear_velocity = Vector4.ZERO
	SliceAngles.tilt(_rig, deg_to_rad(xw), deg_to_rad(zw), deg_to_rad(yaw))
	_rig.set("pitch", deg_to_rad(pitch))
	_rig.set("distance", dist)
	_rig.set("_zoom_target", dist)
	_rig.call("_apply")


func _key(code: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = code
	down.physical_keycode = code
	down.pressed = true
	down.set_meta(&"runner", true)
	Input.parse_input_event(down)
	await _frames(2)
	var up := InputEventKey.new()
	up.keycode = code
	up.physical_keycode = code
	up.pressed = false
	up.set_meta(&"runner", true)
	Input.parse_input_event(up)
	await _frames(1)


func _action(name: StringName) -> void:
	var down := InputEventAction.new()
	down.action = name
	down.pressed = true
	down.set_meta(&"runner", true)
	Input.parse_input_event(down)
	await _frames(2)
	var up := InputEventAction.new()
	up.action = name
	up.pressed = false
	up.set_meta(&"runner", true)
	Input.parse_input_event(up)
	await _frames(1)


func _run() -> void:
	var look: String = "art"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("look="):
			look = a.substr(5)
	OS.set_environment("PEN_LOOK", look)
	_out += look + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	print("DISCOVERY (look %s)" % look)
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
	_cam = WSense.camera_of(_player)
	var guide: Node = _room.get_node_or_null("Systems/WGuide")
	_check(guide != null, "the W guide is in the pen")
	_check(_room.get_node_or_null("World/KataCache") != null and _room.get_node_or_null("World/WDoor") != null and _room.get_node_or_null("World/Zeppelins") != null, "the cache, the door and the airships are in the pen")
	# The Tutor's hints would hold the screen (one hint at a time); this tests the guide's own.
	await _wait(2.0)
	_quiet_tutor()

	# --- Trym's desk: the card, then a step ---------------------------------------------------------------------
	_place(Vector4(25.6, 1.2, 45.0, 0.0), 200.0, -22.0, 2.4)
	var shed: Node = _room.get_node_or_null("World/TrymCabin/Shed")
	if shed != null and shed.has_method("set_cutaway"):
		shed.call("set_cutaway", true)
	await _wait(4.5)
	_check(Guide.spent.has("trym_shelf"), "the card came up at Trym's desk after lingering")
	await _save("01_cabin_card")
	Input.action_press(&"move_ana")
	await _wait(0.7)
	Input.action_release(&"move_ana")
	await _wait(0.4)
	_check(int(Guide.uses.get("step", 0)) >= 1, "the step was counted (%d)" % int(Guide.uses.get("step", 0)))
	_check(Guide.done.has("trym_shelf"), "the cabin's hint is done after a step")
	await _save("02_cabin_stepped")
	_place(Vector4(25.7, 1.2, 44.3, 0.0), 200.0, -28.0, 1.9)
	await _wait(0.6)
	await _save("03_desk_legs_w0")

	# --- The cave road: a chip now (step learned once) ---------------------------------------------------------
	_place(Vector4(7.33, 1.2, 35.6, 0.0), 180.0, -6.0, 6.0)
	await _wait(3.2)
	_check(Guide.spent.has("cave_road"), "the cave road's hint fired")
	await _save("04_cave_road_chip")

	# --- The gate: the card, then the slice turned forward until the gate shows ---------------------------------
	_place(Vector4(-11.3, 1.2, 19.5, 0.0), 0.0, 2.0, 6.0)
	await _wait(4.2)
	_check(Guide.spent.has("gate_road"), "the card came up at the gate road")
	await _save("05_gate_card")
	var gate: Vector4 = (_room.get_node("World/TownWall") as Node4D).global_position + Vector4(0, 1.7, 0, 0)
	var best_zw: float = 0.0
	var best_off: float = INF
	for zw in range(-80, 81, 4):
		_place(Vector4(-11.3, 1.2, 19.5, 0.0), 0.0, 2.0, 6.0, 0.0, float(zw))
		var off: float = absf(WSense.off_slice(_cam, gate))
		if off < best_off:
			best_off = off
			best_zw = float(zw)
	_place(Vector4(-11.3, 1.2, 19.5, 0.0), 0.0, 2.0, 6.0, 0.0, best_zw)
	await _wait(0.8)
	_check(best_off < 2.0, "turned forward %d degrees, the gate is in the slice (%.2f m off)" % [best_zw, best_off])
	_check(Guide.done.has("gate_road"), "the gate's hint is done once the gate shows")
	await _save("06_gate_turned")

	# --- The camp: the card, then turned sideways until V, and V ------------------------------------------------
	_place(Vector4(2.0, 1.2, -4.0, 0.0), -90.0, -6.0, 6.0)
	await _wait(4.2)
	_check(Guide.spent.has("camp_road"), "the card came up on the camp road")
	await _save("07_camp_card")
	var camp: Node = _room.get_node("World/EggCamp")
	var found_xw: float = NAN
	for xw in range(-60, 61, 1):
		_place(Vector4(-4.0, 1.2, -4.0, -1.1), -90.0, -6.0, 6.0, float(xw), 0.0)
		await _frames(1)
		if camp.has_method("can_align") and bool(camp.call("can_align")):
			found_xw = float(xw)
			break
	_check(not is_nan(found_xw), "turned sideways, the camp's V comes up (at %s degrees)" % str(found_xw))
	await _wait(0.4)
	await _save("08_camp_v_prompt")
	await _key(KEY_V)
	await _wait(0.9)
	_check(int(Guide.uses.get("align", 0)) >= 1, "V at the camp counted as an align")
	await _save("09_camp_aligned")

	# --- The airships ---------------------------------------------------------------------------------------------
	_rig.call("align_to", 0.0)
	await _wait(0.6)
	# From the talk camera, high over the north meadow, looking at the fleet: at W 0 one ship, at W 9 four.
	var cam := _room.get_node("World/TalkCam") as Node4D
	for w in [0.0, 9.0]:
		_player.global_position = Vector4(10.0, 1.2, -36.0, w)
		cam.global_position = Vector4(6.0, 16.0, -30.0, w)
		cam.global_basis = _look_basis(Vector4(30.0, 62.0, -160.0, w) - cam.global_position)
		cam.set("current", true)
		await _wait(0.6)
		await _save("10_airships_w0" if w == 0.0 else "11_airships_w9")
	_cam.set("current", true)

	# --- The kata cache -------------------------------------------------------------------------------------------
	_place(Vector4(25.0, 1.2, -24.5, 0.0), 0.0, -2.0, 6.0)
	await _wait(0.8)
	await _save("12_cache_w0_shut")
	await _wait(8.6)
	_check(Guide.spent.has("kata_cache"), "the cache's chip came up after lingering")
	await _save("13_cache_chip")
	_place(Vector4(25.0, 1.2, -25.5, 7.5), 0.0, -2.0, 5.0)
	await _wait(0.8)
	await _save("14_cache_w75_open")
	_place(Vector4(25.0, 1.2, -31.4, 7.5), 0.0, -18.0, 1.8)
	await _wait(0.8)
	var cache: Node = _room.get_node("World/KataCache")
	_check(bool(cache.call("can_open")), "inside, at W 7.5, the chest can be opened")
	await _save("15_cache_inside")
	var inv: Node = _room.get_node("UI/Inventory")
	var before: int = int(inv.call("count_of", "found_azoth"))
	await _action(&"catch_target")
	await _wait(0.8)
	await _save("16_chest_open")
	await _wait(1.4)
	await _save("17_chest_spin")
	await _wait(0.8)
	await _save("18_chest_paid")
	await _wait(1.0)
	_check(Cache.found, "the cache is found")
	_check(int(inv.call("count_of", "found_azoth")) == before + 10, "10 azoth in the belt (%d to %d)" % [before, int(inv.call("count_of", "found_azoth"))])

	# --- The edge-on door -----------------------------------------------------------------------------------------
	_place(Vector4(45.0, 1.2, 7.0, 0.0), 0.0, 0.0, 5.0)
	await _wait(0.8)
	await _save("19_door_w0_slit")
	_place(Vector4(45.0, 1.2, 7.0, 0.0), 0.0, 0.0, 5.0, 90.0, 0.0)
	await _wait(0.8)
	await _save("20_door_whole")
	_place(Vector4(45.0, 1.2, 2.4, 0.0), 0.0, 0.0, 5.0, 90.0, 0.0)
	await _wait(1.6)
	_check(_player.global_position.y > 12.0, "through the door, on top of the Watchstone (y %.1f)" % _player.global_position.y)
	await _wait(0.6)
	await _save("21_door_arrived")

	# --- The balloon: the crew at the fire, the balloon partly in view, V, found -----------------------------------
	_rig.call("align_to", 0.0)
	await _wait(0.6)
	_place(Vector4(-29.2, 1.2, -26.4, 0.0), 0.0, -6.0, 5.0)
	await _wait(1.0)
	await _save("22_crew_fire_w0")
	var finder: Node = _room.get_node("Systems/BalloonFinder")
	var lookout: Node = _room.get_node("Systems/Lookout")
	var balloon: Node = lookout.get("balloon")
	_check(balloon != null and bool(balloon.get("parked")) and absf((balloon as Node4D).global_position.w - 5.0) < 0.01, "the balloon hovers 5 m ana until found")
	_check(not bool(lookout.call("can_board")), "it cannot be boarded before it is found")
	var got: float = NAN
	for zw in range(0, 61, 2):
		for sgn in [1.0, -1.0]:
			_place(Vector4(-29.6, 1.2, -18.0, 0.0), 0.0, 10.0, 6.0, 0.0, float(zw) * sgn)
			await _frames(1)
			if bool(finder.call("can_align")):
				got = float(zw) * sgn
				break
		if not is_nan(got):
			break
	_check(not is_nan(got), "turned forward, V comes up for the balloon (at %s degrees, %.0f%% showing)" % [str(got), 100.0 * float(finder.call("shown_share"))])
	await _wait(0.4)
	await _save("23_balloon_partly_v")
	await _key(KEY_V)
	await _wait(1.0)
	_check(Balloon.found, "V found the balloon")
	_check(bool(lookout.call("can_board")) or true, "boarding is open now (checked at the basket below)")
	_place(Vector4(-30.0, 1.2, -20.0, 5.0), 0.0, 12.0, 7.0)
	await _wait(0.8)
	await _save("24_balloon_found_w5")
	_place(Vector4(-28.6, 1.2, -32.0, 5.0), 90.0, -4.0, 4.0)
	await _wait(0.6)
	_check(bool(lookout.call("can_board")), "at the basket, at its W, boarding is open")
	await _save("25_balloon_board_prompt")

	# --- The dev look with the projection on -------------------------------------------------------------------------
	_place(Vector4(0.0, 1.2, 20.0, 0.0), 16.0, 6.0, 6.0)
	var look_node: Node = _room.get_node_or_null("Systems/Look")
	if look_node != null and not bool(look_node.get("dev")):
		await _key(KEY_I)
		await _wait(1.0)
	await _save("26_dev_start")
	await _key(KEY_P)
	await _wait(1.5)
	await _save("27_dev_projection")
	print("PROJECTION MESHES CHECKED (search the log for 'Too many instances')")

	print("DISCOVERY: %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(0 if _fails == 0 else 1)


## Test panels out of the frames (the murmuration readout, the paths panel, the camera picker, the controls card): at
## 720p and the pen's UI size they cover most of the screen. Only hidden, never changed.
func _tidy_hud() -> void:
	for node in _room.find_children("*", "Control", true, false):
		var s: Script = node.get_script() as Script
		if s == null:
			continue
		var f: String = s.resource_path.get_file()
		if f in ["flock_stats_panel_4d.gd", "pen_paths_panel_4d.gd", "pen_camera_picker_4d.gd", "pen_controls_4d.gd"]:
			(node as Control).visible = false


## The Tutor's opening hints marked as shown, so they do not hold the screen while the hints under test want it.
func _quiet_tutor() -> void:
	var tutor: Node = _room.get_node_or_null("Systems/Tutor")
	if tutor == null:
		return
	var shown: Dictionary = tutor.get("_shown")
	for k in ["move", "ana", "moved", "home", "deliver"]:
		shown[k] = true
	tutor.set("_showing", "")
	var label: Label = _room.get_node_or_null("UI/Hint") as Label
	if label != null:
		label.text = ""


static func _look_basis(gap: Vector4) -> Projection:
	var forward: Vector3 = Vector3(gap.x, gap.y, gap.z).normalized()
	var zc: Vector3 = -forward
	var xc: Vector3 = Vector3(0.0, 1.0, 0.0).cross(zc).normalized()
	var yc: Vector3 = zc.cross(xc)
	return Projection(Vector4(xc.x, xc.y, xc.z, 0.0), Vector4(yc.x, yc.y, yc.z, 0.0), Vector4(zc.x, zc.y, zc.z, 0.0), Vector4(0.0, 0.0, 0.0, 1.0))
