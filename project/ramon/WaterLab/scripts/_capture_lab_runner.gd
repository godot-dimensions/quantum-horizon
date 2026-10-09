extends "res://ramon/WaterLab/scripts/_wl_shots.gd"

## WATER LAB: the tank room through the player's own camera. The opening shot from the corridor, up
## the left to the first turn (the showcase ahead in the corner), the showcase close with its panel
## paged, the turning spot level and turned, feeding at the console, the two walls, the far door, and
## through it to the sea. Frames in smoke_test_output/water_lab/room/. Args: "perf" times the room
## at three places; "hud4k" a 4K frame of the HUD and the walls; "quick" only the first frames;
## "detail" the eel and the crab close through the glass (a camera of the runner's own), every card
## of the fish wall, and the round trip: through the far door to the sea, back in through pier 1's
## door, arriving at the tank room's far door.

const SCENE := "res://ramon/WaterLab/water_lab.tscn"

var _room: Node4D


func setup() -> void:
	out = "res://smoke_test_output/water_lab/room/"
	tag = "ROOM"
	deadline_ms = 240000
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var t0: int = Time.get_ticks_usec()
	_room = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_room)
	# The room as the current scene, so its far door's change_scene replaces it (not the sea on top).
	current_scene = _room
	print("ROOM opened in %.0f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	if "perf" in args:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		for spot in [["opening", -11.0, 17.4, 0.0], ["at_tank", -4.23, -8.2, 0.0], ["showcase", 10.0, 7.0, 180.0]]:
			step(40, _go(float(spot[1]), float(spot[2]), float(spot[3])))
			step(1, perf_start.bind(String(spot[0])))
			step(180, nop)
			step(1, perf_end)
		return
	if "square" in args:
		step(90, _go(-11.0, -4.0, -45.0), "q01_square_from_the_bend")
		step(20, _go(-5.23, -3.2, 0.0), "q02_square_from_behind")
		step(20, _go(-5.23, -7.7, 0.0), "q03_on_the_square")
		step(1, _go(-0.5, -7.7, 90.0))
		step(20, nop, "q04_square_from_the_east")
		return
	if "feed" in args:
		# The feeding booth, then walking away from it (Ramon, 9 Oct: feeding froze his walking).
		step(90, _go(-8.7, -7.5, 0.0), "f01_at_booth")
		step(1, _press.bind(KEY_E))
		step(60, nop, "f02_fed")
		step(1, _walk_start)
		step(60, nop)
		step(1, _walk_stop, "f03_walked_away")
		step(120, nop, "f04_pellets_down")
		return
	if "round2" in args:
		# Ramon's walkthrough (9 Oct): the shorter, wider hall, the tank to the ceiling, the square.
		step(90, _go(-11.0, 12.2, 0.0), "r01_opening")
		step(20, _go(-11.0, 2.0, 0.0), "r02_walking_in")
		step(20, _go(-11.0, -4.0, -45.0), "r03_tank_from_the_bend")
		step(1, _go(-5.2, 2.5, 0.0))
		step(20, _pitch(8.0), "r04_tank_whole")
		step(1, _pitch(-11.0))
		step(40, _go(-5.23, -7.7, 0.0), "r05_on_the_square")
		step(1, _turn_both.bind(20.0, 30.0, 0.8))
		step(30, nop, "r05b_square_turned_both_ways")
		step(1, _press.bind(KEY_V))
		step(120, nop, "r05c_square_following_shark")
		step(1, _press.bind(KEY_R))
		step(1, _go(-9.0, -5.0, 90.0))
		step(20, _pitch(-6.0), "r06_west_wall")
		step(1, _go(4.0, -5.0, -90.0))
		step(20, nop, "r07_east_wall_showcase")
		step(1, _go(-1.5, -3.0, 180.0))
		step(20, nop, "r08_fish_wall")
		step(1, _go(10.0, -7.0, 0.0))
		step(20, nop, "r09_exit")
		step(1, _go(10.0, -10.5, 0.0))
		step(60, nop, "r09b_exit_open")
		step(1, _go(-8.7, -7.5, 0.0))
		step(30, nop, "r10_feeder")
		step(1, _press.bind(KEY_E))
		step(90, nop, "r10b_fed_3s")
		step(120, nop, "r10c_fed_7s")
		return
	if "eel" in args:
		# The eel along its patrol, followed.
		step(60, _go(-8.2, -8.2, 0.0))
		step(1, _close_on.bind("eel", Vector4(0.0, 0.2, 0.0, 0.0)))
		step(1, _eel_out)
		for k in 5:
			step(240, nop, "e%02d_eel_patrol_%ds" % [k + 1, (k + 1) * 4])
		return
	if "detail" in args:
		_detail()
		return
	if "hud4k" in args:
		DisplayServer.window_set_size(Vector2i(3840, 2160))
		step(60, _go(-11.0, -3.0, 0.0), "4k_01_column")
		step(20, _go(9.0, 0.0, -90.0), "4k_02_research")
		return
	step(90, _go(-11.0, 17.4, 0.0), "01_opening")
	if "quick" in args:
		step(30, _go(-11.0, 6.0, 0.0), "02_walking_in")
		step(1, _go(-4.23, -8.2, 0.0))
		step(60, nop, "09_turning_spot_level")
		step(1, _go(-11.0, -8.2, 0.0))
		step(5, _pitch(-6.0))
		step(30, nop, "16_tank_left")
		step(1, _go(-0.4, 6.0, 180.0))
		step(40, _pitch(-6.0), "19_fish_wall")
		step(1, _go(3.4, 10.5, 180.0))
		step(20, _pitch(-4.0), "20_fish_wall_close")
		step(1, _go(-4.2, 0.0, 0.0))
		step(30, _pitch(4.0), "21_title_wall")
		return
	step(30, _go(-11.0, 6.0, 0.0), "02_walking_in")
	step(30, _go(-11.0, -6.6, 0.0), "03_first_turn")
	step(30, _go(10.0, 7.0, 180.0), "04_showcase_close")
	step(10, _press_e, "")
	step(30, nop, "05_showcase_panel_page1")
	step(10, _press_e, "")
	step(30, nop, "06_showcase_panel_page2")
	step(1, _go(-9.2, -8.1, 0.0))
	step(10, _press_e, "")
	step(30, nop, "07_feeding_just_fed")
	step(300, nop, "08_feeding_after_10s")
	step(1, _go(-4.23, -8.2, 0.0))
	step(40, nop, "09_turning_spot_level")
	step(1, _turn_tank(25.0))
	step(30, nop, "10_tank_turned_25")
	step(1, _turn_tank(-40.0))
	step(30, nop, "10b_tank_turned_minus40")
	step(1, _turn_tank(0.0))
	step(1, _go(4.0, -8.2, 0.0))
	step(30, _pitch(-4.0), "11_along_the_tank")
	step(1, _go(9.0, 0.0, -90.0))
	step(40, _pitch(-8.0), "12_research_board")
	step(1, _go(-9.0, 0.0, 90.0))
	step(40, nop, "13_intro_wall")
	step(1, _go(-11.0, -8.2, 0.0))
	step(5, _pitch(-6.0))
	step(30, nop, "16_tank_left")
	step(1, _go(1.0, -8.2, 0.0))
	step(30, nop, "17_tank_right")
	step(1, _go(-4.23, -7.2, 0.0))
	step(120, nop, "18_tank_middle_4s")
	step(1, _go(10.0, -8.5, 0.0))
	step(40, _pitch(-11.0), "14_exit_door_opening")
	step(1, _go(10.0, -13.6, 0.0))
	step(120, nop, "15_through_to_the_sea")


var _close: Camera4D
var _track: Node4D = null
var _track_off := Vector4.ZERO


func _detail() -> void:
	step(60, _go(-8.2, -8.2, 0.0))
	step(1, _close_on.bind("eel", Vector4(0.0, 0.25, 0.0, 0.0)))
	step(20, nop, "d01_eel_at_its_cave")
	step(1, _eel_out)
	step(150, nop, "d02_eel_out")
	step(90, nop, "d03_eel_out_later")
	step(1, _close_on.bind("crab", Vector4(0.0, 0.35, 0.0, 0.0)))
	step(20, nop, "d04_crab")
	step(60, nop, "d05_crab_walking")
	step(1, _close_off)
	step(1, _go(-0.4, 6.0, 180.0))
	for k in 4:
		step(1, _wall_card.bind(k))
		step(40, _pitch(-6.0), "d%02d_fish_wall_cards_%d" % [6 + k, k])
	# The round trip.
	step(1, _go(10.0, -8.5, 0.0))
	step(30, _go(10.0, -13.6, 0.0))
	step(150, nop, "d10_arrived_at_sea")
	step(1, _sea_walk.bind(6.0))
	step(20, nop)
	step(1, _sea_walk.bind(0.3))
	step(200, nop, "d11_back_in_the_lab")
	step(1, _where)


## A camera of the runner's own in front of the glass, following `nm` (the tank's eel or crab).
func _close_on(nm: String, off: Vector4) -> void:
	var tank: Node = _room.get("tank")
	_track = tank.get(nm)
	_track_off = off
	if nm == "crab":
		# On the slice now (it walks through W, on and off it).
		var p: Vector4 = _track.get("_p")
		_track.set("_p", Vector4(p.x, p.y, p.z, 0.0))
	if _close == null:
		_close = Camera4D.new()
		_close.set("rendering_engine_name", "Cross-section")
		root.add_child(_close)
	_close.make_current()


func _close_off() -> void:
	_track = null
	var p: Node = _room.get("player")
	if p != null:
		for c in p.find_children("*", "Camera4D", true, false):
			(c as Camera4D).make_current()
			break


func _eel_out() -> void:
	# Its rest over now: it plans its patrol and swims out on its own.
	var eel: Node = _room.get("tank").get("eel")
	eel.set("_state_t", 0.0)


func _track_point() -> Vector4:
	var p: Vector4 = _track.get("_p")
	return _track.global_position + _track.global_basis * p


func _wall_card(k: int) -> void:
	var wall: Node = _room.get_node_or_null("FishWall")
	if wall != null:
		wall.set("_t", float(k) * float(wall.get("seconds")) + 0.5)


## In the sea (the current scene now): walked to `x` along pier 1.
func _sea_walk(x: float) -> void:
	var sea: Node = current_scene
	print("ROOM in the sea scene: ", sea.name if sea != null else "none")
	if sea != null and sea.has_method("go_to"):
		sea.call("go_to", Vector4(x, float(sea.get("deck_height")) + 0.05, 0.0, 0.0), deg_to_rad(90.0))
		var p: Node = sea.get("player")
		if p != null:
			p.set("input_enabled", false)


func _where() -> void:
	var s: Node = current_scene
	var p: Node4D = s.get("player") if s != null else null
	print("ROOM back in: %s, player at %s" % [s.name if s != null else "none", str(p.global_position) if p != null else "-"])


func _process(d: float) -> bool:
	if _track != null and is_instance_valid(_track) and _close != null:
		var at: Vector4 = _track_point() + _track_off
		# From in front of the glass (the tank's front at +z), a little to the side.
		var tank: Node4D = _room.get("tank")
		var front: float = tank.global_position.z + float((tank.get("water_size") as Vector4).z) * 0.5 + 1.1
		aim(_close, Vector4(at.x - 0.5, at.y + 0.15, front, 0.0), at)
	return super(d)


var _walk_from := Vector4.ZERO


## Walking forward with the real input (the move action), after the room has been used.
func _walk_start() -> void:
	var p: Node4D = _room.get("player")
	p.set("input_enabled", true)
	_walk_from = p.global_position
	Input.action_press(&"move_back")


func _walk_stop() -> void:
	Input.action_release(&"move_back")
	var p: Node4D = _room.get("player")
	print("ROOM walked from %s to %s (%.2f m)" % [str(_walk_from), str(p.global_position), (p.global_position - _walk_from).length()])
	p.set("input_enabled", false)


func _turn_both(turn_deg: float, turn2_deg: float, slide: float) -> void:
	var tank: Node = _room.get("tank")
	tank.call("set_contents", deg_to_rad(turn_deg), slide)
	tank.call("set_turn2", deg_to_rad(turn2_deg))


func _press(key: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = key
		e.physical_keycode = key
		e.pressed = down
		Input.parse_input_event(e)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _rig() -> Node:
	var p: Node = _room.get("player") if is_instance_valid(_room) else null
	return p.get_node_or_null("CameraRig") if p != null else null


func _go(x: float, z: float, yaw_deg: float) -> Callable:
	return func() -> void:
		if not is_instance_valid(_room):
			return
		var p: Node = _room.get("player")
		_room.call("go_to", Vector4(x, 0.05, z, 0.0), deg_to_rad(yaw_deg))
		if p != null:
			p.set("input_enabled", false)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _turn(xw_deg: float, zw_deg: float) -> Callable:
	return func() -> void:
		var r: Node4D = _rig() as Node4D
		if r != null:
			var yaw: float = float(r.get("yaw"))
			r.set("_homing", 0.0)
			r.basis = Basis4D.from_xw(deg_to_rad(xw_deg)) * Basis4D.from_zw(deg_to_rad(zw_deg)) * Basis4D.from_zx(yaw)
			r.call("_apply")


## The tank's contents turned through W (the room's gizmo does this with a right drag in the circle).
func _turn_tank(deg: float) -> Callable:
	return func() -> void:
		var tank: Node = _room.get("tank") if is_instance_valid(_room) else null
		if tank != null:
			tank.call("set_contents", deg_to_rad(deg), 0.0)


func _pitch(deg: float) -> Callable:
	return func() -> void:
		var r: Node = _rig()
		if r != null:
			r.set("pitch", deg_to_rad(deg))
			r.call("_apply")


func _press_e() -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = KEY_E
		e.physical_keycode = KEY_E
		e.pressed = down
		Input.parse_input_event(e)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
