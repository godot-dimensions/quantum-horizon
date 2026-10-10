extends CanvasLayer

## The way home, for everything launched from the menu (Ramon, 10 Oct: "Escape must always provide a
## safe, consistent way back to the main menu").
##
## ONE QUESTION, EVERYWHERE. Esc in any prototype, in any room it opens, and in the world asks the
## same thing in the same box: "Return to Main Menu?", yes or no. No closes the box and the scene
## goes on exactly where it was (the tree is paused while the box is up, so nothing moves). The
## prototypes' own back-to-menu prompts and H buttons are switched off and hidden while they run
## from the menu, so this is the only way back anyone has to learn.
##
## WHY IT LIVES AT THE ROOT, NOT IN THE MENU. The menu does not outlive everything: the world
## replaces it (an `opens_as_scene` entry), and a laptop in the world makes a new one. So this is
## made once, by the first menu (ensure()), as a child of the root, where changes of scene never
## reach it. It keeps no reference to any menu; it finds the current one when it needs it.
##
## The box is also asked for other questions (ask()), so every yes / no in the exhibition looks
## the same: starting a new world while one is held uses it too.
##
## NO class_name: menu_final preloads it.

const MENU_PATH := "res://ramon/menu_final.tscn"
## The world, and the laptop trip that holds it while the menu is up (the menu's catalogue hero).
const WORLD_PATH := "res://ramon/chickenpen/playable_world.tscn"
const TRIP_SCRIPT := "res://ramon/chickenpen/scripts/pen_laptop_trip_4d.gd"
const FONT_DIR := "res://ramon/Demo/fonts/Montserrat/static/"
## The menu's code blue (menu_final.DECK_WHITE.launch_fill) and its hover.
const BLUE := Color(0.125, 0.384, 0.863)
const BLUE_HOVER := Color(0.20, 0.46, 0.93)
const PANEL := Color(0.04, 0.05, 0.07)
const WHITE := Color(0.97, 0.98, 1.0)
## The bright box: the menu's white page and its ink (menu_final.DECK_WHITE).
const PAPER := Color(0.985, 0.988, 0.995)
const INK := Color(0.08, 0.10, 0.14)

var _box: Control
var _dim: ColorRect
var _panel_box: StyleBoxFlat
var _title: Label
var _line: Label
var _yes: Button
var _no: Button
var _column: VBoxContainer
var _gap: Control
var _row: HBoxContainer
var _button_font: FontVariation
## Window pixels per design pixel (the design is 1080 high); set when the box opens.
var _k: float = 1.0
var _on_yes: Callable = Callable()
var _on_no: Callable = Callable()
var _mouse_before: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _paused_before: bool = false


## The one at the root, made if there is none yet.
static func ensure(tree: SceneTree) -> CanvasLayer:
	var found: Node = tree.root.get_node_or_null(^"WayHome")
	if found != null:
		return found as CanvasLayer
	var made: CanvasLayer = (load("res://ramon/Menu/scripts/menu_way_home.gd") as GDScript).new()
	tree.root.add_child.call_deferred(made)
	return made


func _init() -> void:
	name = "WayHome"
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_build()
	get_tree().node_added.connect(_on_node_added)
	_keep_first.call_deferred()


## WHERE ESC IS HEARD: LAST. Godot hands unhandled input to the root's children in reverse order,
## so sitting FIRST among them makes this the last to hear an Esc nobody else took. Whatever has
## something open closes it first and keeps the key (a lab's panel, a conversation, a cutscene,
## the journal, the hawk, the Voxel Lab's and the Maze's own steps), and only an Esc that closed
## nothing asks the question. Anything that should keep Esc while busy without taking the key
## (the theatre seat polls it) joins the group "escape_first" with escape_wanted() -> bool.
func _unhandled_input(event: InputEvent) -> void:
	if is_asking():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_ESCAPE:
		return
	if not away_from_menu():
		return
	for node in get_tree().get_nodes_in_group(&"escape_first"):
		if node.has_method("escape_wanted") and bool(node.call("escape_wanted")):
			return
	get_viewport().set_input_as_handled()
	ask_home()


## A loading board is up (a scene's own, a CanvasLayer named "LoadBoard" as the Voxel Lab's rooms
## have, or the menu's "MenuLoadBoard" still fading): Esc waits until the room is built rather than
## tearing it down mid-build.
func _loading() -> bool:
	for board_name in ["LoadBoard", "MenuLoadBoard"]:
		for board in get_tree().root.find_children(board_name, "CanvasLayer", true, false):
			if (board as CanvasLayer).visible:
				return true
	return false


func _keep_first() -> void:
	if is_inside_tree() and not is_asking() and get_index() != 0:
		get_parent().move_child(self, 0)


## Every arrival at the root (a launch, a room opened by change of scene) puts this back first.
## And the old "BACK TO MENU   H" prompts (Demo/return_button.gd, in the Maze, the Range and
## Crosswise) are hidden and silenced as they appear: Esc is the one way back (Ramon, 10 Oct:
## "the H blue home buttons ... should be removed"). Except on the world's own trip to the range,
## where that prompt is relabelled as the way back to the world (range_way_home_4d.gd).
func _on_node_added(node: Node) -> void:
	if node == self:
		return
	if node.get_parent() == get_tree().root:
		_keep_first.call_deferred()
	if "hub_scene_path" in node and not get_tree().root.has_meta(&"chickenpen_way_home"):
		_quiet.call_deferred(node)


func _quiet(node: Node) -> void:
	if not is_instance_valid(node):
		return
	node.set_process_input(false)
	node.set_process_unhandled_input(false)
	if node is CanvasLayer:
		(node as CanvasLayer).visible = false
	elif node is CanvasItem:
		(node as CanvasItem).visible = false


func is_asking() -> bool:
	return _box != null and _box.visible


## Puts the box up. `on_yes` runs after the box has closed and the tree is running again;
## `on_no` (optional) after a no. Ignored while a question is already up: one box, never two.
func ask(title: String, line: String, yes_text: String, no_text: String, on_yes: Callable, on_no: Callable = Callable()) -> void:
	if is_asking():
		return
	_title.text = title
	_line.text = line
	_yes.text = yes_text
	_no.text = no_text
	_on_yes = on_yes
	_on_no = on_no
	_fit_to_screen()
	_mouse_before = Input.mouse_mode
	_paused_before = get_tree().paused
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_box.visible = true
	# Last while asking, so its _input is FIRST: nothing that runs while paused (the Voxel Lab's and
	# the Maze's guards do) hears the answer keys before the box does.
	get_parent().move_child(self, -1)


## The standard question: back to the menu from whatever is running. Not while a loading board is
## up (the room is built first), whoever asks: the Voxel Lab's and the Maze's guards call this
## directly.
func ask_home(on_yes: Callable = go_home) -> void:
	if _loading():
		return
	ask("Return to Main Menu?", "Would you like to return to the menu or stay here?", "Yes, Return to Menu", "No, Stay Here", on_yes)


## The menu that is alive under a running prototype (it launched it and stays at the root,
## hidden), or null. Found by what it can do, not by type: no dependency on the menu's script.
func menu_alive() -> Node:
	for child in get_tree().root.get_children():
		if child.has_method("_close_running") and child.has_method("_world_on_hold"):
			return child
	return null


## Whether there is anything to go home FROM: a prototype (or a room it opened) or the world is
## the current scene. On the menu itself Esc asks nothing.
func away_from_menu() -> bool:
	var here: Node = get_tree().current_scene
	if here == null:
		return false
	return not (here.has_method("_close_running") and here.has_method("_world_on_hold"))


## Yes: back to the menu.
##   - Under a live menu (a prototype it launched, in whichever room): the menu closes it, the
##     way Esc always did, so nothing is orphaned.
##   - In the world (which replaced the menu): the world is HELD, as a laptop holds it, and a
##     menu comes up with the blue RETURN TO THE WORLD button; nothing is lost.
##   - Anything else: the menu, as a change of scene.
func go_home() -> void:
	var menu: Node = menu_alive()
	if menu != null:
		menu.call("_close_running")
		return
	var here: Node = get_tree().current_scene
	if here != null and here.scene_file_path == WORLD_PATH and ResourceLoader.exists(TRIP_SCRIPT):
		var trip: CanvasLayer = (load(TRIP_SCRIPT) as GDScript).new()
		get_tree().root.add_child(trip)
		trip.call("go", MENU_PATH, _current_camera(here))
		return
	get_tree().change_scene_to_file.call_deferred(MENU_PATH)


## The Camera4D the world is looking through, so the trip can make it current again on return.
static func _current_camera(scene: Node) -> Camera4D:
	for camera in scene.find_children("*", "Camera4D", true, false):
		if bool(camera.get("current")) and (camera as Node4D).is_visible_in_tree():
			return camera as Camera4D
	return null


func _answer(yes: bool) -> void:
	if not is_asking():
		return
	_box.visible = false
	get_tree().paused = _paused_before
	_keep_first()
	var then: Callable = _on_yes if yes else _on_no
	_on_yes = Callable()
	_on_no = Callable()
	# No: the scene as it was, mouse included. Yes: put back too, so a world that is held records
	# its own mouse mode (the menu frees it anyway).
	Input.mouse_mode = _mouse_before
	if then.is_valid():
		then.call()


## While the box is up it takes every key itself: Enter is yes, Esc is no, nothing reaches the
## scene underneath (which is paused anyway).
func _input(event: InputEvent) -> void:
	if not is_asking():
		return
	var key := event as InputEventKey
	if key == null:
		return
	get_viewport().set_input_as_handled()
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE:
		_answer(false)
	elif key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		_answer(true)


func _font(kind: String) -> Font:
	return load(FONT_DIR + "Montserrat-%s.ttf" % kind) as Font


func _build() -> void:
	_box = Control.new()
	# Not anchored: sized in WINDOW PIXELS by _fit_to_screen() each time the box opens.
	_box.mouse_filter = Control.MOUSE_FILTER_STOP
	_box.visible = false
	add_child(_box)
	_dim = ColorRect.new()
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box.add_child(_dim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box.add_child(centre)
	var panel := PanelContainer.new()
	_panel_box = StyleBoxFlat.new()
	panel.add_theme_stylebox_override("panel", _panel_box)
	centre.add_child(panel)
	_column = VBoxContainer.new()
	panel.add_child(_column)
	# Centred, title, line and buttons on one axis (Ramon, 10 Oct).
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_override("font", _font("SemiBold"))
	_column.add_child(_title)
	_line = Label.new()
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line.add_theme_font_override("font", _font("Regular"))
	_column.add_child(_line)
	_gap = Control.new()
	_column.add_child(_gap)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_column.add_child(_row)
	_button_font = FontVariation.new()
	_button_font.base_font = _font("SemiBold")
	_yes = _button()
	_yes.pressed.connect(_answer.bind(true))
	_row.add_child(_yes)
	_no = _button()
	_no.pressed.connect(_answer.bind(false))
	_row.add_child(_no)
	refresh_look()


## SHARP AT ANY SCALE (Ramon, 10 Oct: the box "was rasterized and I saw pixels. It needs to be
## dynamic like the menu. Vector"). The box lives on the root and inherits whatever the running
## scene did to the window: the menu draws through canvas-items stretch (text re-rasterised at the
## screen's size), but the world puts the project's own scaling back - no stretch, its UI scale on
## top - where text is drawn at its nominal size and the finished pixels are enlarged. So the box
## undoes the window's scaling on its own layer (one unit = one window pixel) and sizes everything,
## type included, for the real screen: the design's 1920 x 1080 proportions, drawn at full
## resolution, whatever the scene underneath does.
func _fit_to_screen() -> void:
	# The window's stretch (canvas units to window pixels), undone on this layer.
	transform = get_viewport().get_stretch_transform().affine_inverse()
	var pixels: Vector2 = Vector2(get_window().size)
	_box.position = Vector2.ZERO
	_box.size = pixels
	_k = maxf(pixels.y / 1080.0, 0.5)
	_panel_box.set_corner_radius_all(_px(8))
	_panel_box.set_border_width_all(maxi(1, _px(1)))
	_panel_box.content_margin_left = _px(44)
	_panel_box.content_margin_right = _px(44)
	_panel_box.content_margin_top = _px(36)
	_panel_box.content_margin_bottom = _px(36)
	_column.add_theme_constant_override("separation", _px(12))
	_title.add_theme_font_size_override("font_size", _px(30))
	_line.add_theme_font_size_override("font_size", _px(17))
	_gap.custom_minimum_size = Vector2(0, _px(16))
	_row.add_theme_constant_override("separation", _px(12))
	_button_font.set_spacing(TextServer.SPACING_GLYPH, maxi(1, _px(1)))
	for b in [_yes, _no]:
		(b as Button).custom_minimum_size = Vector2(_px(250), _px(52))
		(b as Button).add_theme_font_size_override("font_size", _px(15))
	refresh_look()


## A design pixel (at 1080 high) in window pixels.
func _px(design: float) -> int:
	return int(round(design * _k))


## Bright or black, as the menu's light / dark switch was last left (the root's "menu_light", which
## menu_final keeps for the session; Ramon, 10 Oct: "a bright version"). Read each time the box
## opens, so it always matches what was chosen.
func refresh_look() -> void:
	if _panel_box == null:
		return
	var light: bool = bool(get_tree().root.get_meta(&"menu_light", true)) if is_inside_tree() else true
	var ink: Color = INK if light else WHITE
	_dim.color = Color(0.02, 0.03, 0.05, 0.4 if light else 0.55)
	_panel_box.bg_color = PAPER if light else PANEL
	# A faint rim, or the box melts into dark scenes and the dark menu (and white ones in light).
	_panel_box.border_color = Color(ink, 0.14)
	_title.add_theme_color_override("font_color", ink)
	_line.add_theme_color_override("font_color", Color(ink, 0.7))
	_style_button(_yes, true, light)
	_style_button(_no, false, light)


## The menu's LAUNCH button proportions: both the same size, so neither answer is the small one.
func _button() -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_override("font", _button_font)
	return b


## Yes: code blue with white type, in both. No: a hairline edge, in the page's ink (white type on
## black; blue type on bright, as the menu's foot buttons).
func _style_button(b: Button, primary: bool, light: bool) -> void:
	var ink: Color = INK if light else WHITE
	var type: Color = WHITE if primary else (BLUE if light else WHITE)
	for key in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(key, type)
	var fills := {"normal": 0.0, "hover": 0.10, "pressed": 0.18}
	for state in fills:
		var s := StyleBoxFlat.new()
		s.set_corner_radius_all(_px(8))
		s.anti_aliasing = true
		if primary:
			s.bg_color = BLUE_HOVER if state == "hover" else BLUE
		else:
			s.bg_color = Color(BLUE if light else WHITE, float(fills[state]))
			s.border_color = Color(ink, 0.22 if light else 0.35)
			s.set_border_width_all(maxi(1, _px(1)))
		b.add_theme_stylebox_override(state, s)
