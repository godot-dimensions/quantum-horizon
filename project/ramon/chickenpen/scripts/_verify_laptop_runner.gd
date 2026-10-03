extends SceneTree

## The laptops (pen_laptop_4d.gd, pen_laptop_trip_4d.gd) and the prompt at the Artifact
## (cave_mine_prompt_4d.gd).
##
## THREE TRIPS, ONE FOR EACH LAPTOP - the cave's table, Trym's desk in the pen (Trym's talk
## switched off, standing in for his having left it) and the cinema's stand. Each: the
## laptop offers F; F takes you to the menu (menu_final) with the game parked, its banner
## reading BACK TO THE PEN; the way home is in its top bar; Escape asks, Escape again stays;
## the toggle to the Frontier Map keeps the way home; Escape there asks and Enter brings you
## back. At Trym's desk the way back is the other one instead: EXPLORE FREELY back to the
## menu, and its banner. And coming back, everything is as it was
## (Ramon, 29 Sept: "the cave is browner when you return, and no HUD ... make sure it's
## also fixed at the pen laptop and theatre ... make it remember states like previous
## things collected, mined"): the window, the light (the same view comes out the same
## colour), the environment in charge, your camera, the dial, the belt, the rock as you
## mined it, the pieces dug out of it.
##
## And at the Artifact: "Press N to mine" with the pickaxe on the belt and not in hand, and
## nothing once it is. And at Trym's desk while he sits at it: F is his, not the laptop's.
##
## Windowed, it saves res://smoke_test_output/laptop_<n>_<what>.png.

const Trip := preload("res://ramon/chickenpen/scripts/pen_laptop_trip_4d.gd")
const MENU := "res://ramon/menu_final.tscn"

var _room: Node
var _cave: Node4D
var _theatre: Node
var _f := 0
var _t := 0.0
var _step := 0
var _failed := 0
var _windowed := false
var _n := 0
## The trip in progress: which laptop, and what it looked like and held before.
var _where := ""
var _laptop: Node4D
var _cycle := -1
var _before: Dictionary = {}


func _initialize() -> void:
	root.unfocusable = true
	_windowed = DisplayServer.get_name() != "headless"
	_room = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_room)
	current_scene = _room


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("  %s  %s  %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _save(what: String) -> void:
	if _windowed:
		root.get_texture().get_image().save_png("res://smoke_test_output/laptop_%d_%s.png" % [_n, what])
		print("   saved laptop_%d_%s.png" % [_n, what])
	_n += 1


func _key(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		Input.parse_input_event(e)


func _press_f() -> void:
	for down in [true, false]:
		var e := InputEventAction.new()
		e.action = &"catch_target"
		e.pressed = down
		Input.parse_input_event(e)


func _player() -> CharacterBody4D:
	if _where == "theatre" and _theatre != null:
		return _theatre.get_node("Player") as CharacterBody4D
	return _room.get_node("Player") as CharacterBody4D


## In front of the laptop, on the floor, looking at it: a metre out from its screen.
func _stand_at(laptop: Node4D) -> void:
	var out := Vector4(0, 0, 1, 0)
	var floor_y: float = laptop.global_position.y - 1.0
	if _where == "pen":
		out = Vector4(1, 0, 0, 0)
		floor_y = laptop.global_position.y - 0.72
	elif _where == "theatre":
		out = ((laptop.get_parent() as Node4D).global_basis * Vector4(0, 0, 1, 0)).normalized()
	var at: Vector4 = laptop.global_position + out
	at.y = floor_y + 0.05
	var p := _player()
	p.global_position = at
	p.set("linear_velocity", Vector4.ZERO)
	var rig := p.get_node("CameraRig") as Node4D
	var d: Vector4 = laptop.global_position - at
	rig.set("yaw", atan2(-d.x, -d.z))
	rig.set("pitch", deg_to_rad(-6.0))
	rig.call("_apply")


func _trip() -> Node:
	return root.get_node_or_null("LaptopTrip")


func _window_state() -> Array:
	var w: Window = root
	return [w.content_scale_mode, w.content_scale_aspect, w.content_scale_size, snappedf(w.content_scale_factor, 0.001), w.mode, w.borderless]


func _look() -> Color:
	var img: Image = root.get_texture().get_image()
	var sum := Vector3.ZERO
	var n := 0
	for y in range(0, img.get_height(), 12):
		for x in range(0, img.get_width(), 12):
			var c: Color = img.get_pixel(x, y)
			sum += Vector3(c.r, c.g, c.b)
			n += 1
	sum /= float(n)
	return Color(sum.x, sum.y, sum.z)


func _state() -> Dictionary:
	var belt: Node = _room.get_node("UI/Inventory")
	var out := {
		"window": _window_state(),
		"size": root.size,
		"belt": (belt.get("items") as Array).duplicate(),
		"azoth": int(belt.call("count_of", "found_azoth")),
		"environment": Trip._environment_in_use(_room),
	}
	if _cave != null:
		out["rock"] = (_cave.get_node("Monolith").get("_collider_grid_point") as Dictionary).size()
		out["dug"] = int(_cave.get_node("Gold").call("dug_out"))
	return out


## One whole trip from the laptop in hand; true when it is over.
func _run_cycle() -> bool:
	match _cycle:
		0:
			_stand_at(_laptop)
			if _t > 1.2:
				_check("%s: the laptop offers F" % _where, bool(_laptop.call("usable")))
				_before = _state()
				_before["look"] = _look()
				_save("%s_before" % _where)
				_press_f()
				_cycle = 1; _t = 0.0
		1:
			if _t > 1.2:
				var here: Node = current_scene
				_check("%s: F opens the menu" % _where, here != null and here.scene_file_path == MENU, here.scene_file_path if here != null else "none")
				_check("%s: its banner offers the way back, not a second pen" % _where, _banner_text(here) == "BACK TO THE PEN", _banner_text(here))
				_check("%s: the game parked, not freed" % _where, is_instance_valid(_room) and not _room.is_inside_tree())
				var home: Button = _trip().get("_home") if _trip() != null else null
				_check("%s: the way home in the top bar" % _where, home != null and home.visible and home.position.y < 90.0)
				if _where == "cave":
					_save("menu2")
				_key(KEY_ESCAPE)
				_cycle = 2; _t = 0.0
		2:
			if _t > 0.4:
				_check("%s: Escape asks" % _where, bool(_trip().call("is_asking")))
				if _where == "cave":
					_save("ask")
				_key(KEY_ESCAPE)
				_cycle = 3; _t = 0.0
		3:
			if _t > 0.4:
				_check("%s: Escape again stays" % _where, not bool(_trip().call("is_asking")) and current_scene.scene_file_path == MENU)
				current_scene.call("_on_frontier_map")
				_cycle = 4; _t = 0.0
		4:
			if _t > 1.5:
				_check("%s: the toggle to the Frontier Map, the way home still there" % _where,
					current_scene.scene_file_path == "res://ramon/FrontierMap.tscn" and (_trip().get("_home") as Button).visible)
				if _where == "cave":
					_save("frontier")
				if _where == "pen":
					current_scene.call("_on_explore_freely")
					_cycle = 10; _t = 0.0
				else:
					_key(KEY_ESCAPE)
					_cycle = 5; _t = 0.0
		5:
			if _t > 0.4:
				_check("%s: Escape asks on the map as well" % _where, bool(_trip().call("is_asking")))
				_key(KEY_ENTER)
				_cycle = 6; _t = 0.0
		6:
			if _t > 1.2:
				var now: Dictionary = _state()
				_check("%s: home, the trip gone" % _where, current_scene == _room and _room.is_inside_tree() and _trip() == null)
				_check("%s: the window as it was" % _where, now["window"] == _before["window"]
					and absi(now["size"].x - _before["size"].x) <= 2 and absi(now["size"].y - _before["size"].y) <= 2,
					"%s %s against %s %s" % [now["window"], now["size"], _before["window"], _before["size"]])
				_check("%s: the same environment in charge" % _where, now["environment"] == _before["environment"],
					"%s" % (now["environment"].get_path() if now["environment"] != null else "none"))
				var cam := _player().get_node("CameraRig/Pitch/Camera4D") as Camera4D
				_check("%s: through your own camera" % _where, cam.current)
				if _where != "theatre":
					_check("%s: the dial back" % _where, (_room.get_node("UI/SlicePlane") as CanvasItem).is_visible_in_tree())
				_check("%s: the belt as it was" % _where, now["belt"] == _before["belt"] and now["azoth"] == _before["azoth"], "%s x%d" % [now["belt"], now["azoth"]])
				if _before.has("rock"):
					_check("%s: the rock as you mined it" % _where, now["rock"] == _before["rock"], "%d voxels against %d" % [now["rock"], _before["rock"]])
					_check("%s: and what was dug out of it still dug out" % _where, now["dug"] == _before["dug"], "%d" % now["dug"])
				_cycle = 7; _t = 0.0
		7:
			_stand_at(_laptop)
			if _t > 1.0:
				var now: Color = _look()
				var was: Color = _before["look"]
				var gap: float = absf(now.r - was.r) + absf(now.g - was.g) + absf(now.b - was.b)
				_check("%s: and it looks as it did, in its own light" % _where, gap < 0.02, "before %s after %s" % [was, now])
				_save("%s_after" % _where)
				_cycle = -1
				return true
		10:
			if _t > 1.5:
				_check("%s: EXPLORE FREELY comes back to the menu, the way home still there" % _where,
					current_scene.scene_file_path == MENU and (_trip().get("_home") as Button).visible)
				_check("%s: and its banner still offers the way back" % _where, _banner_text(current_scene) == "BACK TO THE PEN", _banner_text(current_scene))
				_save("%s_menu_again" % _where)
				# The banner, clicked: the way home that does not ask, because it is the question.
				var click := InputEventMouseButton.new()
				click.button_index = MOUSE_BUTTON_LEFT
				click.pressed = true
				current_scene.call("_on_hero_input", click)
				_cycle = 6; _t = 0.0
	return false


## The first line of the menu's banner, or "" when there is none.
func _banner_text(menu: Node) -> String:
	var panel: Node = menu.get("_hero_panel") if menu != null else null
	if panel == null:
		return ""
	var labels: Array[Node] = panel.find_children("*", "Label", true, false)
	return (labels[0] as Label).text if not labels.is_empty() else ""


func _process(d: float) -> bool:
	_f += 1
	if _f == 10:
		_room.get_node("CaveCrossing").call("go")
	if _f == 14:
		for c in _room.get_children():
			if c.name == "Cave":
				_cave = c
		_room.set_meta(&"cave_first_look_said", true)
	if _f < 20 or _cave == null:
		return false
	_t += d
	match _step:
		0:
			# Something collected and something mined, so the trip has something to lose.
			var belt: Node = _room.get_node("UI/Inventory")
			belt.call("add_item", "found_pickaxe")
			belt.call("add_item", "found_azoth")
			belt.call("add_item", "found_azoth")
			var rock: Node = _cave.get_node("Monolith")
			rock.call("mine_at_shape", rock.get_node("Voxels").get_child(0))
			_where = "cave"
			_laptop = _cave.get_node("LaptopUse")
			_cycle = 0
			_step = 1; _t = 0.0
		1:
			if _run_cycle():
				_step = 2; _t = 0.0
		2:
			# The Artifact, with the pickaxe on the belt but not in hand.
			var belt: Node = _room.get_node("UI/Inventory")
			belt.set("selected", -1)
			var rock: Node4D = _cave.get_node("Monolith")
			var p := _player()
			p.global_position = rock.global_position * Vector4(1, 0, 1, 1) + Vector4(0.0, 0.05, 3.0, 0.0)
			p.linear_velocity = Vector4.ZERO
			if _t > 1.2:
				var slot: int = (belt.get("items") as Array).find("found_pickaxe") + 1
				var said: String = String(_cave.get_node("MinePrompt").call("prompt"))
				_check("at the Artifact without the pickaxe in hand: press to mine", said == "Press %d to mine" % slot, said)
				_save("mine_prompt")
				belt.set("selected", slot - 1)
				_step = 3; _t = 0.0
		3:
			if _t > 0.3:
				_check("and nothing once it is in hand", String(_cave.get_node("MinePrompt").call("prompt")) == "")
				_room.get_node("UI/Inventory").set("selected", -1)
				_room.get_node("CaveCrossing").call("come_back")
				_step = 4; _t = 0.0
		4:
			# Trym at his desk: the laptop is his.
			_where = "pen"
			_laptop = _room.get_node("World/TrymLaptopUse")
			_stand_at(_laptop)
			if _t > 1.2:
				var trym: Node = _room.get_node("Systems/TrymDriver")
				_check("at Trym's desk while he sits there, F is Trym's", bool(trym.call("_can_talk")) and not bool(_laptop.call("usable")))
				# As if he had gone: his conversation switched off, and the laptop is free.
				trym.process_mode = Node.PROCESS_MODE_DISABLED
				_cycle = 0
				_step = 5; _t = 0.0
		5:
			if _run_cycle():
				_room.get_node("Systems/TrymDriver").process_mode = Node.PROCESS_MODE_INHERIT
				_room.get_node("Crossing").call("go_for_testing")
				_step = 6; _t = 0.0
		6:
			if _t > 2.0:
				_theatre = _room.get_node("Crossing").get("_theatre")
				_where = "theatre"
				_laptop = _theatre.find_child("LaptopUse", true, false) if _theatre != null else null
				if _laptop == null:
					_check("the cinema has its laptop", false)
					_step = 8
				else:
					_cycle = 0
					_step = 7; _t = 0.0
		7:
			if _run_cycle():
				_step = 8
		8:
			print("LAPTOP: %s" % ("ALL PASS" if _failed == 0 else "%d FAILED" % _failed))
			quit()
			return true
	if _f > 8000:
		print("LAPTOP: TIMED OUT at step %d, cycle %d" % [_step, _cycle])
		quit()
		return true
	return false
