extends SceneTree

## BOTANY LAB (fork of scripts/_play_runner.gd, 9 Oct): botany_lab.tscn played the same way, without the
## grove; Tab's dev HUD; Q/E through W; and the Botany Lab's own beats as they are built.
##
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

const SCENE := "res://ramon/Arboretum/botany_lab.tscn"
const OUT := "res://smoke_test_output/botany_lab/play/"
const Style := preload("res://ramon/Arboretum/botany_lab/carried/kit/kit_style.gd")

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
	_go(0.0, 10.5, 0.0)
	await _frames(30)
	_check(_room.get("active") == null, "at the door no pedestal is active")
	_shoot("01_door")

	# 2. The showcase pad (round 3: on the route's left branch; round 6 the left again, -3.0, 10.6): E starts the tour, Esc hands
	# the camera back.
	_go(-3.0, 10.6, 0.0)
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

	# 3. Pedestal 01, from its ring (the route's destination): its finished tree stands still on arrival
	# (round 2: no story plays by itself), a click or the right arrow plays it, the arrow moves it on, E
	# rebuilds the cells.
	_go(-4.2, 7.0, 90.0)
	await _frames(90)
	var s1: Node = _station(1)
	_check(_room.get("active") == s1, "pedestal 01 is active when you stand at it")
	_check(int(s1.get("seq_index")) < 0 and not bool(s1.get("cinematic")), "arriving shows the finished tree, no story plays by itself")
	_key(KEY_RIGHT)
	await _frames(30)
	var part: int = int(s1.get("seq_index"))
	_check(part >= 0, "the right arrow (or a click) plays its story (part %d)" % (part + 1))
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

	# 4. Its floating panel (plan steps 27-35): walking up lights it; E turns its pages; walking away puts
	# it back on its face.
	var pn: Node = _room.get_node_or_null("Panel01")
	pn.set("page_index", -1)
	# (Round 4: the panel stands on the pedestal's front edge; you read it from the planter's edge.)
	_go(-5.0, 7.0, 90.0)
	await _frames(20)
	_check(_room.get("_at_panel") == pn and pn != null, "the panel on 01's pedestal is in reach from its edge")
	_check(bool(pn.get("near")), "it lights as you come up to it")
	_key(KEY_E)
	await _frames(15)
	_check(int(pn.get("page_index")) == 0, "E turns it to its first page (Method)")
	_shoot("06_panel_01_method")
	_key(KEY_E)
	await _frames(15)
	_check(int(pn.get("page_index")) == 1, "E again to the next (What it shows)")
	_go(0.0, 10.5, 0.0)
	await _frames(15)
	_check(int(pn.get("page_index")) == -1 and not bool(pn.get("near")), "walking away puts it back on its face")

	# 5. Pedestal 02: E grows a new tree live in the engine's voxel world.
	_go(-4.0, 0.0, 90.0)
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
	_go(-4.0, -7.0, 90.0)
	await _frames(40)
	var l0: int = int((_ex(3).get("record") as Dictionary).get("tets", 0))
	_key(KEY_E)
	await _frames(20)
	var l1: int = int((_ex(3).get("record") as Dictionary).get("tets", 0))
	_check(l1 != l0 and l1 > 0, "E lofts pedestal 03 at another resolution (%d to %d tetrahedra)" % [l0, l1])
	_shoot("09_pedestal_03_coarse")

	# 7. The oak: E turns the season; then the room's keys.
	_go(0.0, -7.6, 0.0)
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

	# 8. The tools: Tab the dev HUD (the lights' editor and the artist panel), F1 the same, F4 the path
	# builder.
	var panel: Control = _room.get("dev_panel")
	var lights: Control = _room.get("light_editor")
	_key(KEY_TAB)
	await _frames(10)
	_free_mouse()
	_check(panel != null and panel.visible and lights != null and lights.visible, "Tab opens the dev HUD (lights and artist panel)")
	_shoot("14_dev_hud")
	var light0: Node4D = (lights.get("lights") as Array)[0] if lights != null and not (lights.get("lights") as Array).is_empty() else null
	if light0 != null:
		var before: float = float(light0.get("softness"))
		lights.call("_apply_value", light0, "softness", before + 1.0)
		await _frames(5)
		_check(absf(float(light0.get("softness")) - before - 1.0) < 0.001, "the editor sets a light's softness (%s, %.1f to %.1f)" % [light0.name, before, float(light0.get("softness"))])
		lights.call("_apply_value", light0, "softness", before)
	_key(KEY_TAB)
	await _frames(5)
	_free_mouse()
	_check(panel != null and not panel.visible and lights != null and not lights.visible, "Tab again closes it")
	_key(KEY_F1)
	await _frames(10)
	_free_mouse()
	_check(panel != null and panel.visible, "F1 opens it too")
	_key(KEY_F1)
	await _frames(5)
	_free_mouse()
	_key(KEY_F4)
	await _frames(30)
	_free_mouse()
	_check(bool(_room.get("building")), "F4 opens the path builder")
	_shoot("15_path_builder")
	_key(KEY_F4)
	await _frames(10)
	_free_mouse()
	_check(not bool(_room.get("building")), "F4 again closes it")

	# 9. Q/E through W, away from the pedestals (the playable world's walk).
	_go(0.0, 10.5, 0.0)
	await _frames(20)
	var pl: Node4D = _room.get("player")
	pl.set("input_enabled", true)
	var w0: float = pl.global_position.w
	# The walker reads the move_ana action (E): held for 40 frames.
	Input.action_press(&"move_ana")
	await _frames(40)
	Input.action_release(&"move_ana")
	await _frames(5)
	_free_mouse()
	_check(absf(pl.global_position.w - w0) > 0.05, "E away from the pedestals steps through W (%.2f to %.2f)" % [w0, pl.global_position.w])
	_go(0.0, 10.5, 0.0, 0.0)
	await _frames(10)

	# 9b. The flowers (round 4, 11; round 5: sixteen pots in the corner by 01): near a pot only a key prompt
	# shows; E opens its caption, E closes it, walking away closes it; a drag tips them and slides them
	# through W, R puts them back.
	_go(0.8, 7.85, -90.0)
	await _frames(30)
	var border: Node = _room.get_node_or_null("Border")
	_check(border != null and not (_room.get("_at_border") as Dictionary).is_empty(), "at the border a planter is yours")
	_check(String(_room.get("_border_caption")) == "", "walking up opens nothing by itself")
	_check(bool((_room.get("prompt") as Node).get("shown")), "a small key prompt shows instead")
	_key(KEY_E)
	await _frames(5)
	_check(String(_room.get("_border_caption")) != "", "E opens its caption (%s)" % String(_room.get("_border_caption")))
	_shoot("16_border_caption")
	_key(KEY_E)
	await _frames(5)
	_check(String(_room.get("_border_caption")) == "", "E again closes it")
	_room.call("open_flower")
	await _frames(3)
	_go(0.0, 10.5, 0.0)
	await _frames(10)
	_check(String(_room.get("_border_caption")) == "", "walking away closes it")
	_go(0.8, 6.0, -90.0)
	await _frames(20)
	border.call("turn_by", 0.5, 0.0)
	await _frames(5)
	_check(absf(float(border.get("tip"))) > 0.1, "a sideways drag tips the flowers through W (%.2f rad)" % float(border.get("tip")))
	border.call("turn_by", 0.0, -0.5)
	await _frames(5)
	_check(float(border.get("slide_w")) > 0.02, "a drag forward slides them through W (%.2f m)" % float(border.get("slide_w")))
	_key(KEY_R)
	await _frames(5)
	_check(not bool(border.call("moved")), "R puts them back in the slice")
	# The flower room is shelved: no door in the right wall.
	_check(_room.get_node_or_null("FlowerShimmer") == null, "the right wall has no door (the flower room is shelved)")
	var pl3: Node4D = _room.get("player")
	_go(4.0, -3.0, -90.0)
	await _frames(5)
	pl3.global_position = Vector4(5.2, 0.05, -3.0, 0.0)
	await _frames(3)
	_check(not bool(_room.get("_leaving")), "walking up to the right wall leads nowhere")
	pl3.set("input_enabled", false)
	_go(0.0, 10.5, 0.0)
	await _frames(10)

	# 10. The back door (plan step 67): walking into its shimmer starts the way to the second room. The
	# run ends here, before the scene changes.
	_go(-7.3, -20.6, 0.0)
	await _frames(10)
	var pl2: Node4D = _room.get("player")
	pl2.global_position = Vector4(-7.3, 0.05, -21.8, 0.0)
	await _frames(3)
	_check(bool(_room.get("_leaving")), "walking into the back door's shimmer starts the way to the second room")

	print("PLAY %s: %d passed, %d failed" % ["PASS" if _failed == 0 else "FAIL", _passed, _failed])
	quit(0 if _failed == 0 else 1)
