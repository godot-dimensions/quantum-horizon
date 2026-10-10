extends SceneTree

## End-to-end check of the way home (Menu/scripts/menu_way_home.gd, 10 Oct): starts at the menu as
## the game does, and for every visible entry launches it, presses Esc (the question must come up),
## answers No (it must go, the scene unchanged), presses Esc and Enter (back on the menu, nothing
## left over). The same in the labs' second rooms (opened the way their doors open them), with a
## panel open first (Esc must close the panel, not ask), and in the world: Esc + yes holds it (blue
## button), Return puts it back, a lab in between frees it, Return reloads and restores it, and a
## laptop opens the menu too. Prints PASS / FAIL per check, memory at each stage, and saves frames
## to res://smoke_test_output/way_home/.
##
## Keys are synthesised inside this window only (Input.parse_input_event); the window is
## unfocusable and the mouse is kept free every frame, so nothing reaches the desktop.
##
## Arguments after `--`: only=<title|title> to run some entries, world=0 to skip the world, labs=0
## to skip the entries.

const MENU := "res://ramon/menu_final.tscn"
const WORLD := "res://ramon/chickenpen/playable_world.tscn"
const OUT := "res://smoke_test_output/way_home/"
const SECOND_ROOMS := {
	"Voxel Lab": "res://ramon/VoxelLab/field/voxel_field.tscn",
	"Creature Lab": "res://ramon/CreationLab/hall/creature_hall.tscn",
	"Botany Lab": "res://ramon/Arboretum/botany_lab/compare/botany_compare.tscn",
	"Aquatic Lab": "res://ramon/WaterLab/seascape/seascape.tscn",
}
## Generous but bounded: a heavy lab builds for several seconds.
const LAUNCH_FRAMES := 2400
const SETTLE := 150

var _pass := 0
var _fail := 0
var _only: PackedStringArray = []
var _do_world := true
var _do_labs := true
var _frames := 0


func _initialize() -> void:
	root.unfocusable = true
	for argument in OS.get_cmdline_user_args():
		var pair: PackedStringArray = String(argument).split("=", true, 1)
		if pair.size() != 2:
			continue
		match pair[0]:
			"only":
				_only = pair[1].split("|")
			"world":
				_do_world = pair[1] != "0"
			"labs":
				_do_labs = pair[1] != "0"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	process_frame.connect(_keep_mouse_free)
	var menu: Node = (load(MENU) as PackedScene).instantiate()
	root.add_child(menu)
	current_scene = menu
	_run.call_deferred()


func _keep_mouse_free() -> void:
	_frames += 1
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# A hard stop whatever happens (memory: runaway loops crashed this PC).
	if _frames > 60000:
		print("WAY HOME: TIMED OUT")
		quit(2)


func _check(ok: bool, what: String) -> void:
	if ok:
		_pass += 1
		print("  PASS ", what)
	else:
		_fail += 1
		print("  FAIL ", what)


func _frames_wait(n: int) -> void:
	for i in n:
		await process_frame


## Waits until `cond` is true, at most `limit` frames. True if it came true.
func _until(cond: Callable, limit: int) -> bool:
	for i in limit:
		if bool(cond.call()):
			return true
		await process_frame
	return bool(cond.call())


func _key(code: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = code
	down.physical_keycode = code
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	var up := down.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)
	await _frames_wait(3)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")


func _mb(monitor: int) -> float:
	return float(Performance.get_monitor(monitor)) / 1048576.0


func _memory(stage: String) -> void:
	print("  MEMORY %-34s static %7.1f MB   video %7.1f MB" % [stage, _mb(Performance.MEMORY_STATIC), _mb(Performance.RENDER_VIDEO_MEM_USED)])


## A scene's own loading board still up (the Voxel Lab's rooms build behind one).
func _board_up() -> bool:
	for board in root.find_children("LoadBoard", "CanvasLayer", true, false):
		if (board as CanvasLayer).visible:
			return true
	return false


## An opening shot still playing (Crosswise's camera: any key skips it, Esc included, as a
## cutscene should).
func _intro_up() -> bool:
	if current_scene == null:
		return false
	for node in current_scene.find_children("*", "Camera4D", true, false):
		if node.has_method("in_intro") and bool(node.call("in_intro")):
			return true
	return false


## Settles a fresh scene: its loading board and opening shot over (bounded), then `extra` frames.
func _settle(extra: int) -> void:
	await _until(func() -> bool: return not _board_up(), LAUNCH_FRAMES)
	await _until(func() -> bool: return not _intro_up(), LAUNCH_FRAMES)
	await _frames_wait(extra)


func _way_home() -> Node:
	return root.get_node_or_null(^"WayHome")


func _menu() -> Node:
	for child in root.get_children():
		if child.has_method("_close_running") and child.has_method("_world_on_hold"):
			return child
	return null


func _asking() -> bool:
	var wh: Node = _way_home()
	return wh != null and bool(wh.call("is_asking"))


## The first CharacterBody4D under the current scene: what "the player did not move" is read from.
func _body() -> Node4D:
	var here: Node = current_scene
	if here == null:
		return null
	var found: Array = here.find_children("*", "CharacterBody4D", true, false)
	return found[0] as Node4D if not found.is_empty() else null


func _run() -> void:
	await _frames_wait(30)
	_check(_way_home() != null, "the menu made WayHome at the root")
	_memory("menu")
	if _do_labs:
		var menu: Node = _menu()
		var entries: Array = menu.call("_entries")
		for i in entries.size():
			var entry: Resource = entries[i]
			if not bool(entry.get("show_in_menu")) or String(entry.get("scene_path")) == "":
				continue
			var title: String = String(entry.get("title"))
			if not _only.is_empty() and not title in _only:
				continue
			await _entry_flow(i, title)
	if _do_world:
		await _world_flow()
	print("WAY HOME: %d pass, %d fail" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)


## Launch, Esc asks, No changes nothing, Esc + Enter goes home; then the second room, and a panel.
func _entry_flow(index: int, title: String) -> void:
	print("== %s" % title)
	var menu: Node = _menu()
	menu.call("_select", index)
	menu.call("_launch", index)
	var up: bool = await _until(func() -> bool: return menu.get("_running") != null and not bool(menu.get("_launching")), LAUNCH_FRAMES)
	_check(up, "%s launches" % title)
	if not up:
		return
	await _settle(SETTLE)
	_memory(title)
	var slug: String = title.to_lower().replace(" ", "_")
	await _shot(slug + "_1_launched")
	await _ask_no_yes(title, slug)
	# The second room, opened the way its door opens it (a change of scene the menu survives).
	if SECOND_ROOMS.has(title):
		var menu2: Node = _menu()
		menu2.call("_select", index)
		menu2.call("_launch", index)
		var up2: bool = await _until(func() -> bool: return menu2.get("_running") != null and not bool(menu2.get("_launching")), LAUNCH_FRAMES)
		if up2:
			await _frames_wait(60)
			change_scene_to_file(String(SECOND_ROOMS[title]))
			var room: String = String(SECOND_ROOMS[title])
			var arrived: bool = await _until(func() -> bool: return current_scene != null and current_scene.scene_file_path == room and current_scene.is_node_ready(), LAUNCH_FRAMES)
			_check(arrived, "%s: second room opens (%s)" % [title, room.get_file()])
			if arrived:
				# Esc while the room's loading board is up does nothing: the room is built first.
				if _board_up():
					await _key(KEY_ESCAPE)
					_check(not _asking(), "%s second room: Esc during its loading board waits (no question)" % title)
				await _settle(SETTLE)
				await _ask_no_yes(title + " second room", slug + "_room")
	# A panel open first: Esc must close it and not ask (the Maze's Tab panel).
	if title == "The Maze":
		var menu3: Node = _menu()
		menu3.call("_select", index)
		menu3.call("_launch", index)
		if await _until(func() -> bool: return menu3.get("_running") != null and not bool(menu3.get("_launching")), LAUNCH_FRAMES):
			await _settle(SETTLE)
			var panel: Control = current_scene.get("dev_panel") as Control
			if panel != null:
				panel.call("toggle")
				await _frames_wait(5)
				var was_open: bool = panel.visible
				await _key(KEY_ESCAPE)
				_check(was_open and not panel.visible and not _asking(), "The Maze: Esc closes the open Tab panel first, no question")
			await _key(KEY_ESCAPE)
			await _key(KEY_ENTER)
			await _until(func() -> bool: return _menu() != null and current_scene == _menu(), 300)


func _ask_no_yes(what: String, slug: String) -> void:
	var body: Node4D = _body()
	var before: Vector4 = body.get("position") if body != null else Vector4.ZERO
	await _key(KEY_ESCAPE)
	_check(_asking(), "%s: Esc asks" % what)
	await _shot(slug + "_2_asking")
	await _key(KEY_ESCAPE)
	await _frames_wait(20)
	var after: Vector4 = body.get("position") if body != null and is_instance_valid(body) else before
	_check(not _asking() and not paused, "%s: Esc again answers No (box gone, not paused)" % what)
	_check((after - before).length() < 0.05, "%s: No leaves the player where they were (moved %.3f)" % [what, (after - before).length()])
	await _key(KEY_ESCAPE)
	_check(_asking(), "%s: Esc asks again" % what)
	await _key(KEY_ENTER)
	var home: bool = await _until(func() -> bool: return _menu() != null and current_scene == _menu() and _menu().get("_running") == null, 300)
	_check(home, "%s: Enter answers Yes and lands on the menu" % what)
	await _frames_wait(30)
	_check(not paused and not _asking(), "%s: nothing left over (not paused, no box)" % what)
	await _shot(slug + "_3_menu")


## The world: hold by Esc, return, release by a lab, return by reload, and a laptop.
func _world_flow() -> void:
	print("== The World")
	var menu: Node = _menu()
	menu.call("_launch", -1)
	var up: bool = await _until(func() -> bool: return current_scene != null and current_scene.scene_file_path == WORLD and current_scene.is_node_ready(), LAUNCH_FRAMES)
	_check(up, "the world launches")
	if not up:
		return
	await _frames_wait(SETTLE * 2)
	_memory("world")
	var world: Node = current_scene
	var player: Node4D = world.get_node_or_null(^"Player") as Node4D
	if player != null:
		player.set("position", Vector4(27.0, 1.2, 21.0, 0.6))
	await _frames_wait(60)
	var spot: Vector4 = player.get("position") if player != null else Vector4.ZERO
	await _shot("world_1_playing")
	# Esc + yes: the world is held, the menu has the blue button.
	await _key(KEY_ESCAPE)
	_check(_asking(), "world: Esc asks")
	await _shot("world_2_asking")
	await _key(KEY_ENTER)
	var held: bool = await _until(func() -> bool: return _menu() != null and current_scene == _menu(), 300)
	_check(held, "world: yes lands on a menu")
	await _frames_wait(30)
	var trip: Node = root.get_node_or_null(^"LaptopTrip")
	_check(trip != null and bool(trip.call("has_world")), "world: held whole while the menu is up")
	_check(_menu() != null and bool(_menu().call("_world_on_hold")), "menu: knows a world is on hold")
	_check(_menu() != null and _menu().find_child("ReturnToWorld", true, false) != null, "menu: the blue RETURN TO THE WORLD button is there")
	_memory("menu, world held")
	await _shot("world_3_menu_held")
	# Return (held): the same world, the player where they were.
	_menu().call("_return_to_world")
	var back: bool = await _until(func() -> bool: return current_scene == world, 300)
	_check(back, "Return puts the held world back (same instance)")
	await _frames_wait(30)
	if back and player != null and is_instance_valid(player):
		var d: float = (Vector4(player.get("position")) - spot).length()
		_check(d < 0.3, "Return: the player where they were (off by %.3f)" % d)
	await _shot("world_4_back")
	# Esc + yes again, then a lab: the world is released.
	await _key(KEY_ESCAPE)
	await _key(KEY_ENTER)
	await _until(func() -> bool: return _menu() != null and current_scene == _menu(), 300)
	await _frames_wait(30)
	var lab: int = _index_of("Voxel Lab")
	trip = root.get_node_or_null(^"LaptopTrip")
	_menu().call("_select", lab)
	_menu().call("_launch", lab)
	var lab_up: bool = await _until(func() -> bool: return _menu() != null and _menu().get("_running") != null and not bool(_menu().get("_launching")), LAUNCH_FRAMES)
	_check(lab_up, "a lab launches from the held-world menu")
	_check(trip != null and is_instance_valid(trip) and not bool(trip.call("has_world")), "launching a lab freed the world (labs run clean)")
	await _settle(SETTLE)
	_memory("Voxel Lab, world freed")
	await _key(KEY_ESCAPE)
	await _key(KEY_ENTER)
	await _until(func() -> bool: return _menu() != null and current_scene == _menu() and _menu().get("_running") == null, 300)
	await _frames_wait(30)
	_check(_menu() != null and _menu().find_child("ReturnToWorld", true, false) != null, "after the lab: the blue button is still there")
	await _shot("world_5_menu_released")
	# Return (released): reloaded, restored.
	_menu().call("_return_to_world")
	var again: bool = await _until(func() -> bool: return current_scene != null and current_scene.scene_file_path == WORLD and current_scene.is_node_ready(), LAUNCH_FRAMES)
	_check(again, "Return after a lab reloads the world")
	if again:
		var restored: bool = await _until(func() -> bool: return root.get_node_or_null(^"LaptopTrip") == null, 600)
		_check(restored, "the trip finished its restore")
		await _frames_wait(60)
		var p2: Node4D = current_scene.get_node_or_null(^"Player") as Node4D
		if p2 != null:
			var d2: float = (Vector4(p2.get("position")) - spot).length()
			_check(d2 < 0.5, "reloaded world: the player where they were (off by %.3f)" % d2)
		_memory("world reloaded")
		await _shot("world_6_restored")
		await _laptop_flow()


## A laptop: stand where one can be used, press F, the menu comes up holding the world. Trym's
## cabin laptop gives way to Trym (he stands 0.3 m from it, and a talk wins over the laptop, as
## designed), so spots round each laptop are tried, then the cave's (through CaveCrossing.go()).
func _laptop_flow() -> void:
	var world: Node = current_scene
	var laptop: Node = await _usable_laptop(world)
	if laptop == null:
		var crossing: Node = world.get_node_or_null(^"CaveCrossing")
		if crossing != null and crossing.has_method("go"):
			crossing.call("go")
			await _frames_wait(90)
			laptop = await _usable_laptop(world)
	_check(laptop != null, "laptop: one can be used (%s)" % (laptop.get_path() if laptop != null else "none"))
	if laptop == null:
		return
	var press := InputEventAction.new()
	press.action = &"catch_target"
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var release := press.duplicate() as InputEventAction
	release.pressed = false
	Input.parse_input_event(release)
	var opened: bool = await _until(func() -> bool: return _menu() != null and current_scene == _menu(), 300)
	_check(opened, "laptop: F opens the menu")
	await _frames_wait(30)
	_check(_menu() != null and _menu().find_child("ReturnToWorld", true, false) != null, "laptop: the blue button is there")
	await _shot("world_7_laptop_menu")
	if opened:
		_menu().call("_return_to_world")
		var back: bool = await _until(func() -> bool: return current_scene == world, 300)
		_check(back, "laptop: Return puts the world back")
		await _frames_wait(30)
		_check(laptop != null and is_instance_valid(laptop) and bool(laptop.call("usable")), "laptop: still works after coming back")


## The first laptop in the world (cave included once it is in) that is usable from some spot round
## it: the player is put at eight spots 1 m out and the laptop asked.
func _usable_laptop(world: Node) -> Node:
	var player: Node4D = world.get_node_or_null(^"Player") as Node4D
	if player == null:
		return null
	var laptops: Array = world.find_children("*", "Node4D", true, false).filter(func(n: Node) -> bool:
		var s: Script = n.get_script() as Script
		return s != null and s.resource_path.ends_with("pen_laptop_4d.gd") and n.is_inside_tree() and (n as Node4D).is_visible_in_tree())
	for laptop in laptops:
		var at: Vector4 = (laptop as Node4D).global_position
		for k in 8:
			var a: float = TAU * float(k) / 8.0
			player.global_position = Vector4(at.x + cos(a), at.y, at.z + sin(a), at.w)
			await _frames_wait(4)
			if bool(laptop.call("usable")):
				return laptop
	return null


func _index_of(title: String) -> int:
	var entries: Array = _menu().call("_entries")
	for i in entries.size():
		if String((entries[i] as Resource).get("title")) == title:
			return i
	return -1
