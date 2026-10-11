extends CanvasLayer

## Escape never leaves at once (round 3, Ramon, 10 Oct: "pressing Escape immediately returns the player
## to the main menu. This is frustrating, particularly when adjusting settings"). Esc, in this order:
##   the confirm box open   closes it (No)
##   the Tab panel open     closes it
##   the map open           closes it
##   otherwise              opens "Return to the main menu?" with YES and NO
## While the box is up the game is paused and the cursor is free; NO (or Esc, or N) puts the mouse back
## as it was, YES (or Y) leaves.
##
## WHY A NODE ON THE ROOT. Launched from the menu, the maze is the root's FIRST child and the menu its
## last (Menu/scripts/prototype_launcher.gd, "the Esc fix"): Godot hands _input to the last child
## first, so the menu hears Esc before anything in the maze and closes it. This guard is added to the
## root after the menu, so it hears Esc first of all. The menu's own file is untouched.
##
## LEAVING. From the menu, the guard hands the menu an Esc of its own (through the menu's _input), so
## the menu leaves the way it always has (it frees the maze and puts itself back). Run on its own (F6) there is no menu to hand it to,
## so it goes to the menu scene, as H does.
##
## The game owns this node (maze_root) and frees it when the maze goes.
##
## NO class_name (engine_gotchas.md).

const Kit := preload("res://ramon/PhaseMazeRemake/carried/kit/kit_style.gd")
const MENU_SCENE := "res://ramon/menu_final.tscn"

## The maze's root: its dev panel, its map and its pause are what Esc deals with.
var maze_root: Node

var _box: PanelContainer
var _yes: Button
var _no: Button
var _scrim: ColorRect
var _mouse_before: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _paused_before: bool = false


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_show_box(false)


func is_open() -> bool:
	return _box != null and _box.visible


func _input(event: InputEvent) -> void:
	if maze_root == null or not is_instance_valid(maze_root) or not maze_root.is_inside_tree():
		return
	var k := event as InputEventKey
	if k == null:
		return
	if is_open():
		# Nothing reaches the game or the menu while the box is up, H included. The box's own keys are
		# answered here, Enter too (the GUI never sees a key this node has taken).
		get_viewport().set_input_as_handled()
		if not k.pressed or k.echo:
			return
		match k.keycode:
			KEY_ESCAPE, KEY_N:
				close_box()
			KEY_Y:
				leave()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if _yes.has_focus():
					leave()
				else:
					close_box()
			KEY_LEFT, KEY_RIGHT, KEY_TAB, KEY_UP, KEY_DOWN:
				if _yes.has_focus():
					_no.grab_focus()
				else:
					_yes.grab_focus()
		return
	# Launched from the menu (a WayHome at the root, 10-11 Oct) this guard keeps only its steps (the
	# Tab panel, the map): Esc stops things and with nothing open frees the cursor; the way to the menu
	# is M and the menu's shared question (Menu/scripts/menu_way_home.gd). Run on its own, as before.
	var way_home: Node = get_tree().root.get_node_or_null(^"WayHome")
	if way_home != null and bool(way_home.call("is_asking")):
		return
	var panel: Node = maze_root.get("dev_panel")
	# H (back to the menu) is ignored while the Tab panel is open: tuning never leaves by accident.
	if k.keycode == KEY_H and panel != null and (panel as Control).visible:
		get_viewport().set_input_as_handled()
		return
	if not k.pressed or k.echo or k.keycode != KEY_ESCAPE:
		return
	get_viewport().set_input_as_handled()
	if panel != null and (panel as Control).visible:
		panel.call("toggle")
		return
	var map: Control = maze_root.get("map")
	if map != null and map.visible:
		map.visible = false
		return
	if way_home != null:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	open_box()


func open_box() -> void:
	if is_open():
		return
	_mouse_before = Input.mouse_mode
	_paused_before = get_tree().paused
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_box(true)
	_no.grab_focus()


func close_box() -> void:
	if not is_open():
		return
	_show_box(false)
	get_tree().paused = _paused_before
	Input.mouse_mode = _mouse_before


## YES: back to the menu. Through the menu if there is one; otherwise to the menu scene.
func leave() -> void:
	_show_box(false)
	get_tree().paused = _paused_before
	var menu: Node = _menu()
	if menu != null:
		# Handed to the menu alone, through its own _input, as if it had heard the key first: never
		# broadcast, because the walker's rig takes a stray Esc as "quit the program" (it did, in the
		# first test of this).
		var down := InputEventKey.new()
		down.keycode = KEY_ESCAPE
		down.physical_keycode = KEY_ESCAPE
		down.pressed = true
		menu.call("_input", down)
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file.call_deferred(MENU_SCENE)


## The menu the maze was launched from, if any: the root child that can close a running prototype.
func _menu() -> Node:
	for c in get_tree().root.get_children():
		if c != self and c != maze_root and c.has_method("_close_running"):
			return c
	return null


func _show_box(on: bool) -> void:
	if _box == null:
		return
	_box.visible = on
	_scrim.visible = on


func _build() -> void:
	_scrim = ColorRect.new()
	_scrim.name = "Scrim"
	_scrim.color = Color(0.02, 0.025, 0.035, 0.45)
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_scrim)
	_box = PanelContainer.new()
	_box.name = "ConfirmBox"
	_box.add_theme_stylebox_override("panel", Kit.glass_box(14.0, 1.0, 0.94))
	add_child(_box)
	var m := MarginContainer.new()
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 34)
	for side in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 26)
	_box.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	m.add_child(v)
	var title := Label.new()
	title.text = "Return to the main menu?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", Kit.ui_font("heading"))
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Kit.UI_INK)
	v.add_child(title)
	var sub := Label.new()
	sub.text = "The level you are in will not be kept."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_override("font", Kit.ui_font("text"))
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", Kit.UI_INK_SOFT)
	v.add_child(sub)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	_yes = _button("YES, BACK TO THE MENU   Y", false)
	_yes.pressed.connect(leave)
	row.add_child(_yes)
	_no = _button("NO, KEEP PLAYING   ESC", true)
	_no.pressed.connect(close_box)
	row.add_child(_no)
	var keys := Label.new()
	keys.text = "ENTER PRESSES THE LIT BUTTON"
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keys.add_theme_font_override("font", Kit.ui_font("key"))
	keys.add_theme_font_size_override("font_size", 11)
	keys.add_theme_color_override("font_color", Kit.UI_INK_DIM)
	v.add_child(keys)


func _button(text: String, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(250, 46)
	b.add_theme_font_override("font", Kit.ui_font("heading"))
	b.add_theme_font_size_override("font_size", 14)
	var accent: Color = Kit.UI_ACCENT
	for state in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(10)
		sb.anti_aliasing = true
		sb.content_margin_left = 18
		sb.content_margin_right = 18
		var lit: bool = state != "normal"
		if primary:
			sb.bg_color = Color(accent, 0.30 if lit else 0.18)
			sb.border_color = Color(accent, 1.0 if lit else 0.7)
		else:
			sb.bg_color = Color(1, 1, 1, 0.12 if lit else 0.05)
			sb.border_color = Color(1, 1, 1, 0.7 if lit else 0.3)
		sb.set_border_width_all(3 if state == "focus" else 2)
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_color_override("font_color", Kit.UI_INK)
	b.add_theme_color_override("font_hover_color", Kit.UI_INK)
	b.add_theme_color_override("font_focus_color", Kit.UI_INK)
	return b


func _process(_delta: float) -> void:
	if _box != null and _box.visible:
		var vs: Vector2 = get_viewport().get_visible_rect().size
		var u: float = maxf(1.0, vs.y / 720.0)
		_box.scale = Vector2(u, u)
		_box.reset_size()
		_box.position = (vs - _box.size * u) * 0.5
