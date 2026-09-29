extends SceneTree

## The laptops (pen_laptop_4d.gd, pen_laptop_trip_4d.gd) and the prompt at the Artifact
## (cave_mine_prompt_4d.gd). In the cave: the laptop offers F; F takes you to Menu2 with the
## game parked; its top bar has the way home; Escape asks, Escape again stays; the toggle to
## the Frontier Map keeps the way home; Escape there asks and Enter brings you back to the
## very spot, in the cave, with your camera. At the Artifact: "Press N to mine" with the
## pickaxe on the belt and not in hand, and nothing once it is. In the pen: Trym's laptop
## gives way to Trym while he sits at it.
##
## Windowed, it saves res://smoke_test_output/laptop_<n>.png of the prompt, the menu, the
## question, the map, and the mine prompt.

var _room: Node
var _cave: Node4D
var _f := 0
var _t := 0.0
var _step := 0
var _failed := 0
var _windowed := false
var _n := 0


func _initialize() -> void:
	root.unfocusable = true
	_windowed = DisplayServer.get_name() != "headless"
	_room = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
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
	return _room.get_node("Player") as CharacterBody4D


func _stand(at: Vector4, look_at: Vector4) -> void:
	_player().global_position = at
	_player().linear_velocity = Vector4.ZERO
	var rig := _player().get_node("CameraRig") as Node4D
	var d: Vector4 = look_at - at
	rig.set("yaw", atan2(-d.x, -d.z))
	rig.set("pitch", deg_to_rad(-6.0))
	rig.call("_apply")


func _trip() -> Node:
	return root.get_node_or_null("LaptopTrip")


func _process(d: float) -> bool:
	_f += 1
	if _f == 10:
		_room.get_node("CaveCrossing").call("go")
	if _f == 14:
		for c in _room.get_children():
			if c.name == "Cave":
				_cave = c
		_room.set_meta(&"cave_first_look_said", true)
	if _f < 20 or (_cave == null and _step < 20):
		return false
	_t += d
	match _step:
		0:
			var laptop: Node4D = _cave.get_node("LaptopUse")
			_stand(laptop.global_position + Vector4(0.0, -1.0 + 0.05, 1.0, 0.0), laptop.global_position)
			if _t > 1.2:
				_check("the cave laptop offers F", bool(laptop.call("usable")))
				_save("cave_prompt")
				_press_f()
				_step = 1; _t = 0.0
		1:
			if _t > 1.2:
				var here: Node = current_scene
				_check("F opens Menu2", here != null and here.scene_file_path == "res://ramon/Menu2.tscn", here.scene_file_path if here != null else "none")
				_check("with the game parked, not freed", is_instance_valid(_room) and not _room.is_inside_tree())
				var home: Button = _trip().get("_home") if _trip() != null else null
				_check("and the way home in the top bar", home != null and home.visible and home.position.y < 90.0, "%s" % (home.position if home != null else Vector2.ZERO))
				_save("menu2")
				_key(KEY_ESCAPE)
				_step = 2; _t = 0.0
		2:
			if _t > 0.4:
				_check("Escape asks", bool(_trip().call("is_asking")))
				_save("ask")
				_key(KEY_ESCAPE)
				_step = 3; _t = 0.0
		3:
			if _t > 0.4:
				_check("Escape again stays", not bool(_trip().call("is_asking")) and current_scene.scene_file_path == "res://ramon/Menu2.tscn")
				current_scene.call("_on_frontier_map")
				_step = 4; _t = 0.0
		4:
			if _t > 1.5:
				_check("the toggle goes to the Frontier Map", current_scene.scene_file_path == "res://ramon/FrontierMap.tscn", current_scene.scene_file_path)
				var home: Button = _trip().get("_home")
				_check("and the way home is there too", home.visible)
				_save("frontier")
				_key(KEY_ESCAPE)
				_step = 5; _t = 0.0
		5:
			if _t > 0.4:
				_check("Escape asks on the map as well", bool(_trip().call("is_asking")))
				_key(KEY_ENTER)
				_step = 6; _t = 0.0
		6:
			if _t > 1.0:
				_check("Enter brings you home", current_scene == _room and _room.is_inside_tree())
				_check("to the same place, in the cave", _cave.is_inside_tree() and (_player().global_position - _cave.get_node("LaptopUse").global_position).length() < 1.6)
				var cam := _player().get_node("CameraRig/Pitch/Camera4D") as Camera4D
				_check("looking through your own camera", cam.current)
				_check("and the trip is gone", _trip() == null)
				_step = 7; _t = 0.0
		7:
			# The Artifact, with the pickaxe on the belt but not in hand.
			var belt: Node = _room.get_node("UI/Inventory")
			if not bool(belt.call("has_item", "found_pickaxe")):
				belt.call("add_item", "found_pickaxe")
			belt.set("selected", -1)
			var rock: Node4D = _cave.get_node("Monolith")
			_stand(rock.global_position * Vector4(1, 0, 1, 1) + Vector4(0.0, 0.05, 3.0, 0.0), rock.global_position)
			if _t > 1.2:
				var slot: int = (belt.get("items") as Array).find("found_pickaxe") + 1
				var said: String = String(_cave.get_node("MinePrompt").call("prompt"))
				_check("at the Artifact without the pickaxe in hand: press to mine", said == "Press %d to mine" % slot, said)
				_save("mine_prompt")
				belt.set("selected", slot - 1)
				_step = 8; _t = 0.0
		8:
			if _t > 0.3:
				_check("and nothing once it is in hand", String(_cave.get_node("MinePrompt").call("prompt")) == "")
				_room.get_node("CaveCrossing").call("come_back")
				_step = 9; _t = 0.0
		9:
			# Trym at his desk: the laptop is his.
			var desk: Node4D = _room.get_node("World/TrymLaptopUse")
			_stand(desk.global_position + Vector4(0.0, -0.67, 0.0, 0.0), desk.global_position + Vector4(-1.0, 0.0, 0.0, 0.0))
			if _t > 1.2:
				var trym: Node = _room.get_node("Systems/TrymDriver")
				_check("at Trym's desk, F is Trym's", bool(trym.call("_can_talk")) and not bool(desk.call("usable")))
				print("LAPTOP: %s" % ("ALL PASS" if _failed == 0 else "%d FAILED" % _failed))
				quit()
				return true
	if _f > 4000:
		print("LAPTOP: TIMED OUT at step %d" % _step)
		quit()
		return true
	return false
