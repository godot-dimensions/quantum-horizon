extends SceneTree

## Round 3's controls, used the way a player would (keys and clicks sent as events), with frames:
##   the console stands still in the lobby and blocks the walker; a click with the cursor free picks a
##   tile; a number frees the cursor; ENTER plays
##   Esc: the confirm box, NO, the Tab panel closed by Esc, the map closed by Esc, the game keys dead
##   while the panel is open, H dead while it is open, YES handed on to a menu
##   PROBES (printed, for reading): F then walking at once (does anything keep turning?); R in the air
##   on the lift and on a stair through W (does the walker stick?)
## Prints "ROUND3: PASS" or what did not happen. Frames in smoke_test_output/phase_maze_remake/round3/.
##   run.sh windowed round3 res://ramon/PhaseMazeRemake/scripts/_round3_runner.gd

const SCENE := "res://ramon/PhaseMazeRemake/phase_maze_remake.tscn"
const OUT := "res://smoke_test_output/phase_maze_remake/round3/"
const GB := preload("res://ramon/PhaseMazeRemake/carried/walker/ground_basis_4d.gd")

var _t0: int = 0
var _m: Node4D
var _fails: Array = []
var _menu: Node


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_x: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 170000:
		print("ROUND3: gave up after 170 s")
		return true
	return false


func _shot(name: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("ROUND3: frame ", name)


func _wait(seconds: float) -> void:
	var t: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < int(seconds * 1000.0):
		await process_frame


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		Input.parse_input_event(e)
		await process_frame
	await process_frame


func _hold(action: StringName, on: bool) -> void:
	if on:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _click(at: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.position = at
		e.global_position = at
		e.pressed = pressed
		Input.parse_input_event(e)
		await process_frame
	await process_frame


func _check(ok: bool, what: String) -> void:
	print("ROUND3: %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails.append(what)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	# A stand-in for the menu, on the root BEFORE the maze, as the real menu is: it counts the Esc it
	# hears and can "close" a prototype, which is how the guard recognises a menu.
	var src := GDScript.new()
	src.source_code = "extends Node\nvar heard: int = 0\nfunc _close_running() -> void:\n\tpass\nfunc _input(e: InputEvent) -> void:\n\tif e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_ESCAPE:\n\t\theard += 1\n"
	src.reload()
	_menu = Node.new()
	_menu.name = "FakeMenu"
	_menu.set_script(src)
	root.add_child(_menu)
	_m = (load(SCENE) as PackedScene).instantiate()
	_m.set("keep_bests", false)
	root.add_child(_m)
	current_scene = _m
	for i in 15:
		await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var player: CharacterBody4D = _m.get("player")
	var console: Node4D = _m.get("console")
	var cam: Camera4D = _m.get("camera")
	var view: Node = _m.get("view")
	var rig: Node4D = _m.get("rig")
	var guard: Node = _m.get("escape")
	_check(guard != null and guard.get_parent() == root and guard.get_index() == root.get_child_count() - 1, "the Esc guard sits last on the root")
	await _wait(0.8)

	# -- the console stands still -------------------------------------------------------------------
	var at0: Vector4 = console.global_position
	var yaw0: Vector4 = console.global_basis.z
	player.set("input_enabled", true)
	Input.action_press(&"move_left")
	await _wait(1.0)
	Input.action_release(&"move_left")
	await _wait(0.3)
	_check(console.global_position.distance_to(at0) < 0.001 and console.global_basis.z.distance_to(yaw0) < 0.001, "the console does not move or turn while you walk")
	await _shot("01_lobby_console_corner")
	# Walk into it: the stand stops you short of its middle.
	_m.call("_place_player", at0 + Vector4(0.0, 0.1, 0.0, 0.0) + console.global_basis.z * 2.2, -console.global_basis.z)
	await _wait(0.2)
	Input.action_press(&"move_forward")
	await _wait(1.6)
	Input.action_release(&"move_forward")
	var d_mid: float = Vector2(player.global_position.x - at0.x, player.global_position.z - at0.z).length()
	_check(d_mid > 0.55, "the console's stand stops the walker (%.2f m from its middle)" % d_mid)
	await _shot("02_walked_into_console")
	player.set("input_enabled", false)
	# Back to the arrival spot, looking at the console.
	_m.call("_place_player", Vector4(0.0, 0.1, 44.6, 0.0), Vector4(0, 0, -1, 0))
	await _wait(0.3)
	rig.basis = GB.faced(rig.basis, (Vector4(at0.x, 0.0, at0.z, 0.0) - Vector4(0.0, 0.0, 44.6, 0.0)).normalized(), 1.0)
	rig.call("_apply")
	await _wait(0.3)

	# -- a number frees the cursor; a click picks; ENTER plays ----------------------------------------
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _key(KEY_3)
	_check(int(_m.get("sel")) == 2, "3 chooses level 3")
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "choosing by number frees the cursor")
	_check(not (_m.get("hud").get("menu") as Dictionary).is_empty(), "the prompt under the console shows")
	await _shot("03_chose_3_prompt")
	# Click tile 5 with the cursor, where the camera draws it.
	var b4: Node4D = console.get_node("Button4")
	var px: Vector2 = cam.world_to_viewport(b4.global_position)
	await _click(px)
	_check(int(_m.get("sel")) == 4, "a click with the free cursor picks tile 5 (sel %d, at %s)" % [int(_m.get("sel")), str(px)])
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# A click that misses goes back to looking and presses nothing.
	await _click(Vector2(40, 40))
	_check(int(_m.get("sel")) == 4 and String(_m.get("state")) == "lobby", "a click beside the console presses nothing")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# -- Tab: the panel, game keys dead while it is open, Esc closes it ------------------------------
	await _key(KEY_TAB)
	var panel: Control = _m.get("dev_panel")
	_check(panel.visible, "TAB opens the tuning panel")
	await _shot("04_tab_panel")
	await _key(KEY_ENTER)
	await _key(KEY_2)
	await _wait(0.6)
	_check(String(_m.get("state")) == "lobby" and int(_m.get("sel")) == 4, "ENTER and 2 do nothing while the panel is open")
	await _key(KEY_H)
	_check(_m.is_inside_tree() and String(_m.get("state")) == "lobby", "H does nothing while the panel is open")
	await _key(KEY_ESCAPE)
	_check(not panel.visible, "ESC closes the panel")
	_check(not bool(guard.call("is_open")), "...without asking to leave")
	_check(int(_menu.get("heard")) == 0, "...and the menu never hears it")

	# -- Esc: the box, NO ------------------------------------------------------------------------
	await _key(KEY_ESCAPE)
	_check(bool(guard.call("is_open")) and paused, "ESC opens the confirm box and pauses")
	await _shot("05_escape_box")
	await _key(KEY_ESCAPE)
	_check(not bool(guard.call("is_open")) and not paused, "ESC again is NO: the box closes, play goes on")
	await _key(KEY_ESCAPE)
	await _key(KEY_N)
	_check(not bool(guard.call("is_open")), "N is NO")
	_check(int(_menu.get("heard")) == 0 and _m.is_inside_tree(), "the menu heard none of it")

	# -- start level 3 with ENTER --------------------------------------------------------------------
	await _key(KEY_3)
	await _key(KEY_ENTER)
	await _wait(1.0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_check(String(_m.get("state")) == "playing" and int(_m.get("level_index")) == 2, "ENTER plays level 3")
	# The map closes on Esc too.
	await _key(KEY_M)
	await _key(KEY_ESCAPE)
	_check(not (_m.get("map") as Control).visible and not bool(guard.call("is_open")), "ESC closes the map first")

	# -- PROBE: R in the air on the lift -----------------------------------------------------------
	await _probe_lift(player, view, false)
	await _load(2)
	await _probe_lift(player, view, true)

	# -- PROBE: F, then walking at once ----------------------------------------------------------------
	await _probe_turn(player, view, rig)

	# -- PROBE: R half way down a stair through W ------------------------------------------------------
	await _probe_stair(player, view, rig)

	# -- YES, handed on to the menu -----------------------------------------------------------------
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _key(KEY_ESCAPE)
	_check(bool(guard.call("is_open")), "ESC opens the box again")
	await _key(KEY_Y)
	await _wait(0.3)
	_check(int(_menu.get("heard")) == 1, "YES hands one Esc on to the menu (heard %d)" % int(_menu.get("heard")))
	_check(not bool(guard.call("is_open")) and not paused, "the box is gone, the game unpaused")
	await _wait(0.8)
	await _key(KEY_ESCAPE)
	_check(bool(guard.call("is_open")) and int(_menu.get("heard")) == 1, "the guard stands again afterwards")
	await _key(KEY_ESCAPE)
	print("ROUND3: %s" % ("PASS" if _fails.is_empty() else "FAIL " + str(_fails)))
	quit()


func _load(i: int) -> void:
	_m.call("_load_level", i)
	await _wait(0.4)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## On the overlook: into the lift's ring, wait for it to go down, jump (or not) and press R mid-air.
## Logs y, floor, the lift and whether the ride ends.
func _probe_lift(player: CharacterBody4D, view: Node, turned: bool) -> void:
	var ov: Dictionary = _m.get("overlook")
	var lift: Node4D = ov["lift"]
	player.set("input_enabled", true)
	if turned:
		await _key(KEY_F)
		await _wait(0.6)
	_m.call("_place_player", lift.global_position + Vector4(0.0, 0.1, 0.0, 0.0), -(_m.get("rig") as Node4D).basis.z)
	var t: float = 0.0
	var pressed_r: bool = false
	var jumped: bool = false
	var stuck_for: float = 0.0
	var last_y: float = player.global_position.y
	while t < 9.0:
		await physics_frame
		t += 1.0 / float(Engine.physics_ticks_per_second)
		if bool(_m.get("_lifting")) and not jumped and lift.position.y < float(ov["top"]) - 3.0:
			jumped = true
			Input.action_press(&"move_jump")
			await physics_frame
			Input.action_release(&"move_jump")
		if jumped and not pressed_r and not player.is_on_floor():
			pressed_r = true
			await _key(KEY_R)
			print("ROUND3: PROBE lift%s R pressed mid-air at y %.2f (lift %.2f)" % [" turned" if turned else "", player.global_position.y, lift.global_position.y])
		var y: float = player.global_position.y
		if pressed_r and absf(y - last_y) < 0.0005 and not player.is_on_floor() and bool(_m.get("on_overlook")):
			stuck_for += 1.0 / float(Engine.physics_ticks_per_second)
		last_y = y
		if int(t * 60.0) % 30 == 0:
			print("ROUND3: PROBE lift t %.1f y %.2f floor %s lift %.2f lifting %s on_overlook %s vel %s" % [t, y, str(player.is_on_floor()), lift.global_position.y,
				str(_m.get("_lifting")), str(_m.get("on_overlook")), str(player.get("linear_velocity"))])
		if not bool(_m.get("on_overlook")) and t > 1.0:
			break
	var ok: bool = not bool(_m.get("on_overlook")) and player.global_position.y < float(ov["bottom"]) + 1.0
	_check(ok, "R in mid-air on the lift%s: the ride ends on the ground (y %.2f, on_overlook %s, stuck %.2f s)" % [" (turned)" if turned else "", player.global_position.y, str(_m.get("on_overlook")), stuck_for])
	await _shot("06_lift_after_r%s" % ("_turned" if turned else ""))
	player.set("input_enabled", false)


## F on a door plate, then forward held at once: logs the rig's heading and the avatar's facing every
## 50 ms, so any turn that goes on after the swing shows.
func _probe_turn(player: CharacterBody4D, view: Node, rig: Node4D) -> void:
	await _load(1)
	_m.set("on_overlook", false)
	(_m.get("overlook")["lift"] as Node4D).position.y = float(_m.get("overlook")["bottom"])
	var lv = _m.get("lattice")
	# Stand on a cell with a door through W, facing 25 degrees off the corridor (as a player would).
	var door: Vector3i = lv.start
	for key in lv.open:
		var e: Vector4i = key
		if e.w == 2 and not lv.stairs.has(Vector3i(e.x, e.y, e.z)):
			door = Vector3i(e.x, e.y, e.z)
			break
	_m.call("_place_player", lv.cell_centre(door) + Vector4(0, 0.1, 0, 0), Vector4(sin(deg_to_rad(25.0)), 0, -cos(deg_to_rad(25.0)), 0))
	await _wait(0.5)
	player.set("input_enabled", true)
	var avatar: Node4D = _m.get("avatar")
	await _key(KEY_F)
	Input.action_press(&"move_forward")
	var t0: int = Time.get_ticks_msec()
	var turning_after: float = 0.0
	var prev: Projection = rig.basis
	var first_move: float = -1.0
	var start: Vector4 = player.global_position
	while Time.get_ticks_msec() - t0 < 1600:
		await process_frame
		var ms: float = float(Time.get_ticks_msec() - t0) / 1000.0
		var b: Projection = rig.basis
		var moved: float = (b.z - prev.z).length()
		prev = b
		if first_move < 0.0 and player.global_position.distance_to(start) > 0.05:
			first_move = ms
		if ms > float(view.get("turn_seconds")) + 0.1 and moved > 0.0005:
			turning_after += moved
		if int(ms * 1000.0) % 100 < 17:
			print("ROUND3: PROBE turn t %.2f rig fwd %s avatar fwd %s turning %s input %s" % [ms, str(-b.z), str((avatar.global_basis.z)), str(view.call("is_turning")), str(player.get("input_enabled"))])
	Input.action_release(&"move_forward")
	print("ROUND3: PROBE turn: first move at %.2f s, rig still turning after the swing: %.4f" % [first_move, turning_after])
	_check(turning_after < 0.01, "nothing keeps turning after F's swing (%.4f)" % turning_after)
	_check(first_move >= 0.0 and first_move < float(view.get("turn_seconds")) + 0.25, "you walk as soon as the turn is done (%.2f s)" % first_move)
	await _shot("07_after_f_walking")
	player.set("input_enabled", false)


## Down a stair through W (turned), R half way, then a second: does the walker stick in the air?
func _probe_stair(player: CharacterBody4D, view: Node, rig: Node4D) -> void:
	await _load(1)
	_m.set("on_overlook", false)
	(_m.get("overlook")["lift"] as Node4D).position.y = float(_m.get("overlook")["bottom"])
	var lv = _m.get("lattice")
	var stair: Vector3i = Vector3i(-1, -1, -1)
	for c in lv.stairs:
		if int(lv.stairs[c][0]) == 2:
			stair = c
			break
	if stair.x < 0:
		print("ROUND3: PROBE stair: level 2 has no stair through W")
		return
	var sgn: int = int(lv.stairs[stair][1])
	# Start at the stair's high end in W, turned to face down it.
	var high: Vector3i = stair + Vector3i(0, 0, sgn)
	_m.call("_place_player", lv.cell_centre(high) + Vector4(0, lv.top_height(high) + 0.1, 0, 0), Vector4(0, 0, -1, 0))
	await _wait(0.4)
	await _key(KEY_F)
	await _wait(0.6)
	player.set("input_enabled", true)
	# Face down the stair: forward is the rig's -z; along W after F, the sign is the level's.
	var fwd: Vector4 = -rig.basis.z
	var down_w: float = -float(sgn)
	var act: StringName = &"move_forward" if fwd.w * down_w > 0.0 else &"move_back"
	Input.action_press(act)
	var mid: float = lv.cell_centre(stair).w
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 4000 and absf(player.global_position.w - mid) > 0.6:
		await process_frame
	Input.action_release(act)
	print("ROUND3: PROBE stair: at w %.2f y %.2f floor %s, pressing R" % [player.global_position.w, player.global_position.y, str(player.is_on_floor())])
	await _key(KEY_R)
	var ys: Array = []
	for i in 24:
		await _wait(0.05)
		ys.append(snappedf(player.global_position.y, 0.01))
	print("ROUND3: PROBE stair after R: y %s floor %s w %.2f hidden %d" % [str(ys), str(player.is_on_floor()), player.global_position.w, int(view.get("hidden_axis"))])
	# Walk on: forward and back, a second each. Does he move?
	var before: Vector4 = player.global_position
	for a in [&"move_forward", &"move_back", &"move_left"]:
		Input.action_press(a)
		await _wait(0.8)
		Input.action_release(a)
	var moved: float = player.global_position.distance_to(before)
	print("ROUND3: PROBE stair: moved %.2f m after R, y %.2f floor %s" % [moved, player.global_position.y, str(player.is_on_floor())])
	await _shot("08_stair_after_r")
	_check(moved > 0.3, "after R on a stair through W the walker can still move (%.2f m)" % moved)
	player.set("input_enabled", false)
