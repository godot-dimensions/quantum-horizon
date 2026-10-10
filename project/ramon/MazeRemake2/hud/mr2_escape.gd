extends CanvasLayer

## MAZE REMAKE 2 (11 Oct 2026): CARRIED from VoxelLab/room/vl_escape.gd, paths only changed. The Annex root
## answers escape_step (closes the Tab panel, skips a film, closes the end card) and the guard asks otherwise.

## ESCAPE NEVER LEAVES AT ONCE (round 7, #79: "Pressing Escape still immediately returns the player to the
## main menu ... including while I was adjusting water settings in the developer HUD"). The Phase Maze's
## guard (PhaseMazeRemake/hud/maze_escape.gd, built for the same report the same day), carried here and
## made general: the scene it guards says what Esc closes, in its own order, through `escape_step(key)`.
##
## THE ORDER, each press:
##   1. this box open                      closes it (No)
##   2. the scene has something open       the scene closes the top one (escape_step returns true):
##                                         the Tab and F1 panels, a pop-up, the presentation, the bench,
##                                         the bird's flight
##   3. otherwise                          opens "Return to the main menu?" with YES and NO
## Only YES leaves. H (the menu's other way out) goes the same way: the scene may use it (the bird lands
## on H), otherwise it asks.
##
## WHY A NODE ON THE ROOT, KEPT LAST. Launched from the menu, the prototype is the root's FIRST child and
## the menu its last (Menu/scripts/menu_final.gd, "THE ESC FIX"): Godot hands _input to the last child
## first, so the menu heard Esc before anything here and closed the lab. That was the bug. This node is
## added to the root after the menu and moves itself back to the end whenever anything is added after it,
## so it hears Esc and H first of all and takes them; nothing behind it (the menu, the carried walker
## rig whose Esc QUIT THE PROGRAM on a second press, the bench, the bird) ever gets a stray one. The
## menu's own file is untouched.
##
## LEAVING. From the menu, the guard hands the menu an Esc of its own, through the menu's _input alone
## (never broadcast), so the menu leaves the way it always has. Run on its own (F6) there is no menu: it
## goes to the menu scene.
##
## The scene that makes it (the lab, the open world) frees it as it goes (each makes its own).
##
## NO class_name (engine_gotchas.md).

const Style := preload("res://ramon/MazeRemake2/carried/kit_style.gd")
const MENU_SCENE := "res://ramon/menu_final.tscn"

## The scene guarded: escape_step(key: Key) -> bool closes the top thing it has open.
var scene: Node

var _box: PanelContainer
var _yes: Button
var _no: Button
var _scrim: ColorRect
var _mouse_before: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _paused_before: bool = false


## Made, on the root, after everything else (deferred: the menu adds the scene and only then moves it).
static func guard(for_scene: Node) -> CanvasLayer:
	var g := CanvasLayer.new()
	g.name = "AnnexEscape"
	g.set_script(load("res://ramon/MazeRemake2/hud/mr2_escape.gd"))
	g.set("scene", for_scene)
	for_scene.get_tree().root.add_child.call_deferred(g)
	return g


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_show_box(false)


func is_open() -> bool:
	return _box != null and _box.visible


func _input(event: InputEvent) -> void:
	if scene == null or not is_instance_valid(scene) or not scene.is_inside_tree():
		return
	var k := event as InputEventKey
	if k == null:
		return
	if is_open():
		# Nothing reaches the scene or the menu while the box is up. Its own keys are answered here.
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
	# Launched from the menu (10 Oct) the asking is the menu's one shared question, the same box in
	# every prototype (Menu/scripts/menu_way_home.gd), and H is no longer a way home (the H buttons
	# went); this guard keeps only its steps (panels, the bench, flying). Run on its own, as before.
	var way_home: Node = get_tree().root.get_node_or_null(^"WayHome")
	if way_home != null and bool(way_home.call("is_asking")):
		return
	if k.keycode != KEY_ESCAPE and (k.keycode != KEY_H or way_home != null):
		return
	# Both keys are ours from here: the release too, so nothing behind sees half a press.
	get_viewport().set_input_as_handled()
	if not k.pressed or k.echo:
		return
	if scene.has_method("escape_step") and bool(scene.call("escape_step", k.keycode)):
		return
	if way_home != null:
		way_home.call("ask_home")
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
		# broadcast (the walker's rig took a stray Esc as "quit the program" in the maze's first test).
		var down := InputEventKey.new()
		down.keycode = KEY_ESCAPE
		down.physical_keycode = KEY_ESCAPE
		down.pressed = true
		menu.call("_input", down)
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file.call_deferred(MENU_SCENE)


## The menu the lab was launched from, if any: the root child that can close a running prototype.
func _menu() -> Node:
	for c in get_tree().root.get_children():
		if c != self and c != scene and c.has_method("_close_running"):
			return c
	return null


func _process(_delta: float) -> void:
	# Kept last on the root: anything added after this node would hear Esc first.
	var root: Node = get_parent()
	if root != null and root.get_child_count() > 0 and root.get_child(root.get_child_count() - 1) != self:
		root.move_child(self, -1)
	if _box != null and _box.visible:
		var vs: Vector2 = get_viewport().get_visible_rect().size
		var u: float = maxf(1.0, vs.y / 720.0)
		_box.scale = Vector2(u, u)
		_box.reset_size()
		_box.position = (vs - _box.size * u) * 0.5


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
	_box.add_theme_stylebox_override("panel", Style.glass_box(14.0, 1.0, 0.94))
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
	title.add_theme_font_override("font", Style.ui_font("heading"))
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Style.UI_INK)
	v.add_child(title)
	var sub := Label.new()
	sub.text = "You will leave the Annex."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_override("font", Style.ui_font("text"))
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", Style.UI_INK_SOFT)
	v.add_child(sub)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	_yes = _button("YES, BACK TO THE MENU   Y", false)
	_yes.pressed.connect(leave)
	row.add_child(_yes)
	_no = _button("NO, STAY HERE   ESC", true)
	_no.pressed.connect(close_box)
	row.add_child(_no)
	var keys := Label.new()
	keys.text = "ENTER PRESSES THE LIT BUTTON"
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keys.add_theme_font_override("font", Style.ui_font("key"))
	keys.add_theme_font_size_override("font_size", 11)
	keys.add_theme_color_override("font_color", Style.UI_INK_DIM)
	v.add_child(keys)


func _button(text: String, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(250, 46)
	b.add_theme_font_override("font", Style.ui_font("heading"))
	b.add_theme_font_size_override("font_size", 14)
	var accent: Color = Style.UI_ACCENT
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
	b.add_theme_color_override("font_color", Style.UI_INK)
	b.add_theme_color_override("font_hover_color", Style.UI_INK)
	b.add_theme_color_override("font_focus_color", Style.UI_INK)
	return b
