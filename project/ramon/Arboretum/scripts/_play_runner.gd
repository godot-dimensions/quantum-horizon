extends SceneTree

## Plan step 98: the Arboretum played through as a visitor, by its keys. Each beat puts you where a
## visitor would stand, sends the key a visitor would press (as a real key event, through the same
## input path), checks what changed and shoots a frame. Prints PLAY PASS / PLAY FAIL per check and a
## total. Windowed, unfocusable, the player's own movement off and the mouse left free, so nothing of
## yours leaks in (memory: test windows steal focus).
##
## Not covered here: the mouse (a click, the wheel, a right drag) is read only while the mouse is
## captured, and a runner must not capture yours. A click runs the same code as the arrow keys and E,
## which are covered; the wheel and the drag are the carried showcase's own, as in the Creation Lab.
##
## Frames in smoke_test_output/arboretum/play/.

const SCENE := "res://ramon/Arboretum/arboretum.tscn"
const OUT := "res://smoke_test_output/arboretum/play/"
const Style := preload("res://ramon/Arboretum/carried/kit/kit_style.gd")

var _room: Node4D
var _failed: int = 0
var _passed: int = 0
var _deadline: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_deadline = Time.get_ticks_msec() + 240000
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	(func() -> void: _play()).call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() > _deadline:
		print("PLAY TIMEOUT")
		quit(2)
		return true
	return false


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
	print("PLAY %s  %s" % ["PASS" if ok else "FAIL", what])


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _free_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var p: Node = _room.get("player")
	if p != null:
		p.set("input_enabled", false)


func _go(x: float, z: float, yaw_deg: float, w: float = 0.0) -> void:
	_room.call("go_to", Vector4(x, 0.05, z, w), deg_to_rad(yaw_deg))
	_free_mouse()


## A key pressed and let go, as a real event.
func _key(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		Input.parse_input_event(e)
	_free_mouse()


func _shoot(name: String) -> void:
	root.get_texture().get_image().save_png(OUT + name + ".png")


func _station(i: int) -> Node:
	return _room.get_node_or_null("Station%02d" % i)


func _ex(i: int) -> Node:
	var s: Node = _station(i)
	return s.get("exhibit") if s != null else null


func _play() -> void:
	_room = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_room)
	await _frames(40)
	_free_mouse()

	# 1. The door: the hall ahead, nothing active.
	_go(0.0, 14.0, 0.0)
	await _frames(30)
	_check(_room.get("active") == null, "at the door no pedestal is active")
	_shoot("01_door")

	# 2. The showcase pad: E starts the tour, Esc hands the camera back.
	_go(5.2, 12.6, 0.0)
	await _frames(20)
	_key(KEY_E)
	await _frames(90)
	_check(not (_room.get("_cine") as Dictionary).is_empty(), "E on the pad starts the guided tour")
	_shoot("02_tour")
	_key(KEY_ESCAPE)
	await _frames(150)
	_check((_room.get("_cine") as Dictionary).is_empty(), "Esc ends the tour and hands the camera back")
	_free_mouse()
	_shoot("03_after_tour")

	# 3. Pedestal 01: its story plays on arrival, the right arrow moves it on, E rebuilds the cells.
	_go(-2.0, 10.6, 50.0)
	await _frames(90)
	var s1: Node = _station(1)
	_check(_room.get("active") == s1, "pedestal 01 is active when you stand at it")
	var part: int = int(s1.get("seq_index"))
	_check(part >= 0, "its story plays on arrival (part %d)" % (part + 1))
	_key(KEY_RIGHT)
	await _frames(5)
	_check(int(s1.get("seq_index")) == part + 1, "the right arrow moves it to the next part (%d to %d)" % [part + 1, int(s1.get("seq_index")) + 1])
	_shoot("04_pedestal_01_next_part")
	var tets0: int = int((_ex(1).get("record") as Dictionary).get("tets", 0))
	_key(KEY_E)
	await _frames(20)
	var tets1: int = int((_ex(1).get("record") as Dictionary).get("tets", 0))
	_check(tets1 != tets0 and tets1 > 0, "E rebuilds the voxel tree at the next cell size (%d to %d tetrahedra)" % [tets0, tets1])
	_shoot("05_pedestal_01_cells")

	# 4. Its console: E opens the card and closes it.
	_go(-9.8, 13.0, 20.0)
	await _frames(20)
	_check(_room.get("_at_console") != null, "the console beside 01 is in reach")
	_key(KEY_E)
	await _frames(20)
	_check(bool(_room.get("_card_open")), "E at the console opens the card")
	_shoot("06_card_01")
	_key(KEY_E)
	await _frames(10)
	_check(not bool(_room.get("_card_open")), "E again closes it")

	# 5. Pedestal 02: E grows a new tree live in the engine's voxel world.
	_go(2.4, 3.6, -50.0)
	await _frames(40)
	_check(_room.get("active") == _station(2), "pedestal 02 is active")
	_key(KEY_E)
	await _frames(10)
	_check(_ex(2).get("_builder") != null, "E starts a live dual-contoured growth")
	_shoot("07_pedestal_02_growing")
	var waited: int = 0
	while _ex(2).get("_builder") != null and waited < 600:
		await process_frame
		waited += 1
	_check(_ex(2).get("_builder") == null, "the live growth finishes (%d frames)" % waited)
	await _frames(20)
	_shoot("08_pedestal_02_grown")

	# 6. Pedestal 03: E lofts it again at another resolution.
	_go(-2.0, -3.6, 50.0)
	await _frames(40)
	var l0: int = int((_ex(3).get("record") as Dictionary).get("tets", 0))
	_key(KEY_E)
	await _frames(20)
	var l1: int = int((_ex(3).get("record") as Dictionary).get("tets", 0))
	_check(l1 != l0 and l1 > 0, "E lofts pedestal 03 at another resolution (%d to %d tetrahedra)" % [l0, l1])
	_shoot("09_pedestal_03_coarse")

	# 7. The oak: E turns the season; then the room's keys.
	_go(0.0, -5.2, 0.0)
	await _frames(40)
	_check(_room.get("active") == _station(4), "the oak is active")
	_key(KEY_E)
	await _frames(150)
	_check(int(_ex(4).get("_season_i")) == 1, "E turns the oak to autumn")
	_shoot("10_oak_autumn")
	_key(KEY_E)
	_key(KEY_E)
	await _frames(10)
	_check(int(_ex(4).get("_season_i")) == 0, "two more presses bring summer back")
	var wind: Node = _room.call("wind")
	if wind != null:
		wind.set("gust_every", 0.0)
	_key(KEY_G)
	await _frames(30)
	_check(wind != null and bool(wind.get("_gust_on")), "G sends a gust (its front at %.1f m)" % (float(wind.get("gust_front")) if wind != null else 0.0))
	_shoot("11_gust")
	_key(KEY_V)
	await _frames(30)
	_check(bool(_room.get("volume_view")), "V shows the volume view")
	_shoot("12_volume_view")
	_key(KEY_V)
	await _frames(20)
	_check(not bool(_room.get("volume_view")), "V again goes back to the slice")
	var pal: String = Style.palette
	_key(KEY_B)
	await _frames(20)
	_check(Style.palette != pal, "B switches the palette (%s to %s)" % [pal, Style.palette])
	_shoot("13_palette")
	_key(KEY_B)
	await _frames(10)

	# 8. The tools: F1 the dev panel, F4 the path builder.
	var panel: Control = null
	for n in _room.find_children("*", "Control", true, false):
		if (n as Node).get_script() != null and String((n as Node).get_script().resource_path).ends_with("arb_dev_panel.gd"):
			panel = n
	_key(KEY_F1)
	await _frames(10)
	_free_mouse()
	_check(panel != null and panel.visible, "F1 opens the dev panel")
	_shoot("14_dev_panel")
	_key(KEY_F1)
	await _frames(5)
	_free_mouse()
	_check(panel != null and not panel.visible, "F1 again hides it")
	_key(KEY_F4)
	await _frames(30)
	_free_mouse()
	_check(bool(_room.get("building")), "F4 opens the path builder")
	_shoot("15_path_builder")
	_key(KEY_F4)
	await _frames(10)
	_free_mouse()
	_check(not bool(_room.get("building")), "F4 again closes it")

	# 9. The grove: loaded and drawn near its door, the hall hidden deep inside, and back.
	var grove: Node4D = _room.get_node_or_null("Grove")
	_go(0.0, -18.0, 0.0)
	await _frames(60)
	_check(grove != null and String(grove.get("state")) == "ready" and grove.visible, "the grove is loaded and drawn near its door")
	_go(0.0, -38.0, 0.0)
	await _frames(30)
	_check(bool(_room.get("_hall_hidden")) and not (_station(4) as Node4D).visible, "deep in the grove the hall's trees are not drawn")
	_shoot("16_grove")
	_go(0.0, 2.0, 0.0)
	await _frames(30)
	_check(not bool(_room.get("_hall_hidden")) and (_station(4) as Node4D).visible, "back in the hall they are")
	_check(grove != null and not grove.visible, "and the grove is not drawn from the hall")
	_shoot("17_back_in_hall")

	print("PLAY %s: %d passed, %d failed" % ["PASS" if _failed == 0 else "FAIL", _passed, _failed])
	quit(0 if _failed == 0 else 1)
