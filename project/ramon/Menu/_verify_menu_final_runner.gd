extends SceneTree

## menu_final from the front door, round trip through the chicken pen.
##
## The laptop runner (chickenpen/scripts/_verify_laptop_runner.gd) starts IN the pen and
## goes to the menu and back. This starts where a stakeholder starts, at the menu, and
## checks the other direction as well:
##
##   1. The menu: the banner selected and reading PLAY THE WORLD, the pen in the pane, the
##      tour above the lab in screen order, the arrow keys walking that order, a finding's
##      evidence tier printed, Slice Vision's three levels as three buttons.
##   2. A prototype on top of the menu (Slice Vision level 2), and Escape unwinding it.
##   3. The toggle to the Frontier Map and EXPLORE FREELY back to a fresh menu.
##   4. The banner: the pen REPLACES the menu, the window's scaling back to the project's.
##   5. From Trym's laptop to the menu again, its banner now BACK TO THE PEN, and that
##      banner taking you home with the window as it was.
##
## Windowed (it saves res://smoke_test_output/menu_final_<n>_<what>.png), small, and never
## focused, so nobody's typing lands in it:
##
##   godot.windows.editor.double.x86_64.console.exe --path project --windowed
##       --resolution 1280x720 --position 40,40 --script res://ramon/Menu/_verify_menu_final_runner.gd

const MENU := "res://ramon/menu_final.tscn"
const PEN := "res://ramon/chickenpen/chickenpen.tscn"
const MAP := "res://ramon/FrontierMap.tscn"
const TOUR := ["Slice Vision", "4D Ascent", "Portal", "Quantum Range", "Voxel Mining", "Lofted Creatures"]
const FILMS := ["Flight of the 4D Starlings", "Mountain Range"]
const LAB := ["Phase Maze", "Shrubbery Lab", "Sky Box Clouds", "Motion Lab"]

var _menu: Node
var _pen: Node
var _f := 0
var _t := 0.0
var _step := 0
var _failed := 0
var _windowed := false
var _n := 0
var _before: Array = []


func _initialize() -> void:
	root.unfocusable = true
	_windowed = DisplayServer.get_name() != "headless"
	_menu = load(MENU).instantiate()
	root.add_child(_menu)
	current_scene = _menu


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("  %s  %s  %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _save(what: String) -> void:
	if _windowed:
		root.get_texture().get_image().save_png("res://smoke_test_output/menu_final_%d_%s.png" % [_n, what])
		print("   saved menu_final_%d_%s.png" % [_n, what])
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


func _click_banner() -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	current_scene.call("_on_hero_input", click)


func _banner_text(menu: Node) -> String:
	var panel: Node = menu.get("_hero_panel") if menu != null else null
	if panel == null:
		return ""
	var labels: Array[Node] = panel.find_children("*", "Label", true, false)
	return (labels[0] as Label).text if not labels.is_empty() else ""


func _selected_title(menu: Node) -> String:
	var entry: Resource = menu.call("_selected_entry")
	return String(entry.get("title")) if entry != null else ""


func _has_label(node: Node, text: String) -> bool:
	for label in node.find_children("*", "Label", true, false):
		if (label as Label).text == text and (label as Label).is_visible_in_tree():
			return true
	return false


func _has_label_containing(node: Node, text: String) -> bool:
	for label in node.find_children("*", "Label", true, false):
		if (label as Label).text.contains(text) and (label as Label).is_visible_in_tree():
			return true
	return false


func _scaling() -> Array:
	return [root.content_scale_mode, root.content_scale_aspect, root.content_scale_size]


func _window_state() -> Array:
	return [root.content_scale_mode, root.content_scale_aspect, root.content_scale_size,
		snappedf(root.content_scale_factor, 0.001), root.mode, root.borderless]


## In front of Trym's laptop, on the floor, looking at it (as the laptop runner does it).
func _stand_at_trym_laptop() -> void:
	var laptop := _pen.get_node("World/TrymLaptopUse") as Node4D
	var at: Vector4 = laptop.global_position + Vector4(1, 0, 0, 0)
	at.y = laptop.global_position.y - 0.72 + 0.05
	var p := _pen.get_node("Player") as CharacterBody4D
	p.global_position = at
	p.set("linear_velocity", Vector4.ZERO)
	var rig := p.get_node("CameraRig") as Node4D
	var d: Vector4 = laptop.global_position - at
	rig.set("yaw", atan2(-d.x, -d.z))
	rig.set("pitch", deg_to_rad(-6.0))
	rig.call("_apply")


func _process(d: float) -> bool:
	_f += 1
	_t += d
	match _step:
		0:
			if _t > 1.0:
				var catalogue: Resource = _menu.get("catalogue")
				_check("the menu scales its own window", root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
					and root.content_scale_size == Vector2i(1920, 1080), "%s" % [_scaling()])
				_check("it opens on the banner", int(_menu.get("_selected")) == -1)
				_check("the banner reads PLAY THE WORLD", _banner_text(_menu) == "PLAY THE WORLD", _banner_text(_menu))
				_check("and the pane shows the pen", (_menu.get("_detail_title") as Label).text == "CHICKEN PEN", (_menu.get("_detail_title") as Label).text)
				var buttons: Array = (_menu.get("_launch_row") as Node).get_children()
				_check("with one button, PLAY THE WORLD", buttons.size() == 1 and (buttons[0] as Button).text == "PLAY THE WORLD")
				var titles: Array[String] = []
				for i in (_menu.get("_order") as Array):
					titles.append(String((_menu.call("_entry", i) as Resource).get("title")))
				var expected: Array[String] = []
				expected.assign(TOUR + FILMS + LAB)
				_check("the tour, the cinematics, then the lab, in screen order", titles == expected, "%s" % [titles])
				_check("the lab has its heading", _has_label(_menu, String(catalogue.get("lab_heading"))))
				_save("start")
				_menu.call("_step_selection", 1)
				_check("down from the banner is the first of the tour", _selected_title(_menu) == "Slice Vision", _selected_title(_menu))
				_check("Slice Vision offers its three levels", (_menu.get("_launch_row") as Node).get_child_count() == 3)
				_check("its finding carries its tier", _has_label(_menu, "OBSERVED WHILE BUILDING · n = 1"))
				for i in 5:
					_menu.call("_step_selection", 1)
				_check("five more down is the last of the tour", _selected_title(_menu) == "Lofted Creatures", _selected_title(_menu))
				_menu.call("_step_selection", 1)
				_check("one more is the first cinematic", _selected_title(_menu) == "Flight of the 4D Starlings", _selected_title(_menu))
				_menu.call("_step_selection", 2)
				_check("and past the cinematics, the first of the lab", _selected_title(_menu) == "Phase Maze", _selected_title(_menu))
				_check("the lab's finding tier too, where it has a finding", _has_label_containing(_menu, "n = 1"))
				for i in 9:
					_menu.call("_step_selection", -1)
				_check("and all the way up is the banner again", int(_menu.get("_selected")) == -1)
				# Slice Vision's second level, on top of the menu as prototypes are.
				_menu.call("_select", 0)
				_menu.call("_on_launch_pressed", 1)
				_step = 1; _t = 0.0
		1:
			var running: Node = _menu.get("_running")
			if running != null and _t > 1.5:
				_check("level 2 runs on top of the menu", running.scene_file_path == "res://ramon/MiegakureLook/levels/level_2_bridge.tscn"
					and current_scene == _menu, running.scene_file_path)
				_save("level_2")
				_key(KEY_ESCAPE)
				_step = 2; _t = 0.0
			elif _t > 20.0:
				_check("level 2 runs on top of the menu", false, "never started")
				_step = 2; _t = 0.0
		2:
			if _t > 0.6:
				_check("Escape brings the menu back", _menu.get("_running") == null and (_menu.get("_shell") as Control).visible)
				_check("moved on to the next of the tour", _selected_title(_menu) == "4D Ascent", _selected_title(_menu))
				_menu.call("_on_frontier_map")
				_step = 3; _t = 0.0
		3:
			if _t > 1.5:
				_check("the toggle opens the Frontier Map", current_scene != null and current_scene.scene_file_path == MAP)
				current_scene.call("_on_explore_freely")
				_step = 4; _t = 0.0
		4:
			if _t > 1.5:
				_menu = current_scene
				_check("EXPLORE FREELY comes back to menu_final", _menu != null and _menu.scene_file_path == MENU,
					_menu.scene_file_path if _menu != null else "none")
				_check("still on the banner", int(_menu.get("_selected")) == -1 and _banner_text(_menu) == "PLAY THE WORLD")
				_click_banner()
				_step = 5; _t = 0.0
		5:
			# The first click on a selected banner goes.
			if current_scene != null and current_scene.scene_file_path == PEN and _t > 4.0:
				_pen = current_scene
				_check("the banner opens the pen IN PLACE of the menu", not is_instance_valid(_menu) and _pen.is_inside_tree())
				_check("with the project's own scaling back", root.content_scale_mode == Window.CONTENT_SCALE_MODE_DISABLED
					and root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP, "%s" % [_scaling()])
				_check("and its HUD there", (_pen.get_node("UI/SlicePlane") as CanvasItem).is_visible_in_tree()
					and (_pen.get_node("UI/Inventory") as CanvasItem).is_visible_in_tree())
				_save("pen")
				_pen.get_node("Systems/TrymDriver").process_mode = Node.PROCESS_MODE_DISABLED
				_step = 6; _t = 0.0
			elif _t > 40.0:
				_check("the banner opens the pen", false, current_scene.scene_file_path if current_scene != null else "none")
				_step = 9
		6:
			_stand_at_trym_laptop()
			if _t > 1.2:
				var laptop: Node = _pen.get_node("World/TrymLaptopUse")
				_check("Trym's laptop offers F", bool(laptop.call("usable")))
				_before = _window_state()
				_press_f()
				_step = 7; _t = 0.0
		7:
			if _t > 1.5:
				var here: Node = current_scene
				_check("F opens menu_final with the pen parked", here != null and here.scene_file_path == MENU
					and is_instance_valid(_pen) and not _pen.is_inside_tree())
				_check("its banner reads BACK TO THE PEN", _banner_text(here) == "BACK TO THE PEN", _banner_text(here))
				_check("and the pane starts on the tour, not on the pen", _selected_title(here) == "Slice Vision", _selected_title(here))
				_save("menu_from_laptop")
				_click_banner()
				_step = 8; _t = 0.0
		8:
			if _t > 1.5:
				_check("the banner takes you home", current_scene == _pen and _pen.is_inside_tree()
					and root.get_node_or_null("LaptopTrip") == null)
				_check("the window as it was", _window_state() == _before, "%s against %s" % [_window_state(), _before])
				var cam := _pen.get_node("Player/CameraRig/Pitch/Camera4D") as Camera4D
				_check("through your own camera", cam.current)
				_save("pen_again")
				_pen.get_node("Systems/TrymDriver").process_mode = Node.PROCESS_MODE_INHERIT
				_step = 9
		9:
			print("MENU FINAL: %s" % ("ALL PASS" if _failed == 0 else "%d FAILED" % _failed))
			quit()
			return true
	if _f > 12000:
		print("MENU FINAL: TIMED OUT at step %d" % _step)
		quit()
		return true
	return false
