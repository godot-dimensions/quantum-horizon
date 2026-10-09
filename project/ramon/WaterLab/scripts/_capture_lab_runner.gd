extends "res://ramon/WaterLab/scripts/_wl_shots.gd"

## WATER LAB: the tank room through the player's own camera. The opening shot from the corridor, up
## the left to the first turn (the showcase ahead in the corner), the showcase close with its panel
## paged, the turning spot level and turned, feeding at the console, the two walls, the far door, and
## through it to the sea. Frames in smoke_test_output/water_lab/room/. Args: "perf" times the room
## at three places; "hud4k" a 4K frame of the HUD and the walls; "quick" only the first frames.

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
