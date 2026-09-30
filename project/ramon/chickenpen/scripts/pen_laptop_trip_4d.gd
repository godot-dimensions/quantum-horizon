extends CanvasLayer

## From a laptop to the prototypes menu and back, with the game exactly as you left it
## (pen_laptop_4d.gd starts it).
##
## THE RANGE TRIP'S TRICK (pen_range_trip_4d.gd): the current scene - the pen, with the cave
## or the cinema inside it if that is where the laptop was - is taken out of the tree and
## held, not freed, and the menu (menu_final) becomes the current scene. Its toggle to the Frontier Map
## and back is an ordinary change of scene; it frees only the current scene, which is the
## menu, so the parked game is untouched however often you switch.
##
## ESCAPE ASKS, THEN TAKES YOU HOME (Ramon, 29 Sept: "the menus now should revert back to
## the pen by pressing esc, to which you get a notification, back to pen?"). This lives on the
## root, outside both menus, and hears Escape only when neither menu wanted it - so Escape
## still closes a running prototype, a notice, a drawer or a sub-map first, as it always has,
## and only at the top of the menu does it ask. While the question is up it takes every key
## itself - Enter is yes, Escape is no - because Enter in both menus launches a prototype.
## Nothing in the menus was changed for this.
##
## AND IT PUTS BACK WHAT THE MENUS CHANGE AROUND THE GAME (Ramon, 29 Sept: "after I return
## from the laptop ... the cave is browner, and no HUD"). Two things outlive a menu:
##   - The window. The menu sets its own content scale (canvas items, 1920x1080, expand) and
##     goes borderless fullscreen, and nothing set them back - the HUD, laid out for the
##     game's own window, came back scaled off the screen, the dial with it.
##   - The environment. The pen and the cave (and the cinema) each carry a
##     WorldEnvironment4D marked current, and which one owns the sky and the light depends
##     on the order they enter the tree (pen_crossing_4d.gd says so at length). Putting the
##     whole pen back re-enters them in the pen's order, and the field's warm evening won
##     inside the cave. So the one that was really in use - marked current and not under a
##     branch the crossing has hidden - is noted on the way out and made current again on
##     the way back.

const FONT := "res://ramon/Demo/fonts/Montserrat/static/Montserrat-Medium.ttf"
const FONT_BOLD := "res://ramon/Demo/fonts/Montserrat/static/Montserrat-SemiBold.ttf"

var _pen: Node
var _camera: Camera4D
var _mouse := Input.MOUSE_MODE_VISIBLE
var _ask: Control
var _window: Dictionary = {}
var _environment: Node
var _home: Button


func _ready() -> void:
	name = "LaptopTrip"
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _process(_delta: float) -> void:
	_home.visible = _pen != null and not _prototype_running()
	if not _home.visible:
		return
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var k: float = MenuBanner.reference_scale(screen)
	var origin: Vector2 = MenuBanner.reference_origin(screen)
	var tall: float = MenuBanner.HEIGHT * 0.46
	var width: float = 300.0
	var right: float = MenuBanner.REFERENCE.x - MenuBanner.PAD - MenuBanner.ACTION_WIDTH - MenuBanner.TAB_GAP
	_home.add_theme_font_size_override("font_size", maxi(int(round(float(MenuBanner.TAB_SIZE) * k)), 9))
	_home.position = origin + Vector2(right - width, (MenuBanner.HEIGHT - tall) * 0.5) * k
	_home.size = Vector2(width, tall) * k


## A prototype launched from the menu runs on top of it, the menu still current underneath:
## The menu holds it in `_running`, the Frontier Map in its launcher. The button is not offered
## over one - Escape there closes the prototype, as the menus have always done.
func _prototype_running() -> bool:
	var here: Node = get_tree().current_scene
	if here == null:
		return false
	if here.get("_running") != null:
		return true
	var launcher: Object = here.get("_launcher")
	return launcher != null and launcher.has_method("is_running") and bool(launcher.call("is_running"))


func is_asking() -> bool:
	return _ask != null and _ask.visible


## Off to the menu. Deferred: this is reached from input handling inside the scene that is
## about to leave the tree.
func go(menu_path: String, camera: Camera4D) -> void:
	_camera = camera
	_swap.call_deferred(menu_path)


func _swap(menu_path: String) -> void:
	var tree := get_tree()
	var packed: PackedScene = load(menu_path) as PackedScene
	if packed == null:
		push_warning("LaptopTrip: no menu at %s" % menu_path)
		queue_free()
		return
	_mouse = Input.mouse_mode
	_pen = tree.current_scene
	_window = _window_state()
	_environment = _environment_in_use(_pen)
	# Tells the menu not to take over the window's mode and size - only its scaling, which this
	# puts back.
	tree.root.set_meta(&"laptop_trip", true)
	tree.root.remove_child(_pen)
	var menu: Node = packed.instantiate()
	tree.root.add_child(menu)
	tree.current_scene = menu
	tree.root.move_child(self, -1)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Home: the menu (or the map) freed, the game put back, its camera and mouse as they were.
func come_back() -> void:
	_return.call_deferred()


func _return() -> void:
	var tree := get_tree()
	var here: Node = tree.current_scene
	if here != null and here != _pen and is_instance_valid(here):
		tree.root.remove_child(here)
		here.queue_free()
	if tree.root.has_meta(&"laptop_trip"):
		tree.root.remove_meta(&"laptop_trip")
	_restore_window()
	if _pen != null and is_instance_valid(_pen):
		tree.root.add_child(_pen)
		tree.current_scene = _pen
	if _environment != null and is_instance_valid(_environment):
		_environment.call("make_current")
	if _camera != null and is_instance_valid(_camera):
		_camera.current = true
	Input.mouse_mode = _mouse
	queue_free()


func _window_state() -> Dictionary:
	var w: Window = get_window()
	return {"scale_mode": w.content_scale_mode, "aspect": w.content_scale_aspect,
		"scale_size": w.content_scale_size, "factor": w.content_scale_factor,
		"mode": w.mode, "borderless": w.borderless, "size": w.size, "position": w.position}


func _restore_window() -> void:
	if _window.is_empty():
		return
	var w: Window = get_window()
	w.content_scale_mode = _window["scale_mode"]
	w.content_scale_aspect = _window["aspect"]
	w.content_scale_size = _window["scale_size"]
	w.content_scale_factor = _window["factor"]
	w.borderless = _window["borderless"]
	w.mode = _window["mode"]
	if int(_window["mode"]) == Window.MODE_WINDOWED:
		w.size = _window["size"]
		w.position = _window["position"]
		# And again once the change of mode has settled: straight out of fullscreen the
		# system trims the size it is given by the frame it is about to draw, and a frame
		# later is still too soon.
		var size_: Vector2i = _window["size"]
		var at: Vector2i = _window["position"]
		get_tree().create_timer(0.25).timeout.connect(func() -> void:
			if is_instance_valid(w) and w.mode == Window.MODE_WINDOWED:
				w.size = size_
				w.position = at)


## The WorldEnvironment4D that is actually lighting the game: marked current, and not inside
## a branch that is hidden (the crossing hides the field while you are in the cave or the
## cinema). The last such in the tree, the way the most recent arrival wins.
static func _environment_in_use(scene: Node) -> Node:
	var found: Node = null
	for env in scene.find_children("*", "WorldEnvironment4D", true, false):
		if bool(env.get("current")) and (env as Node4D).is_visible_in_tree():
			found = env
	return found


# ------------------------------------------------------------------ the question

func _unhandled_input(event: InputEvent) -> void:
	if is_asking() or _pen == null:
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_show_ask(true)


func _input(event: InputEvent) -> void:
	if not is_asking():
		return
	var key := event as InputEventKey
	if key == null:
		return
	get_viewport().set_input_as_handled()
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		_show_ask(false)
		come_back()
	elif key.keycode == KEY_ESCAPE:
		_show_ask(false)


func _show_ask(on: bool) -> void:
	_ask.visible = on
	# Last among the root's children, so its _input runs before whichever menu is current -
	# the map is added after this when you switch to it.
	if on:
		get_parent().move_child(self, -1)


func _build() -> void:
	var regular: Font = load(FONT) as Font
	var bold: Font = load(FONT_BOLD) as Font
	# THE WAY HOME AS A BUTTON TOO, in the top bar (Ramon, 29 Sept: "create a button
	# somewhere that says return to pen, but tuck it neatly, dont break the design ...
	# probably in the top tiny bar"). The bar is the menus' shared banner (menu_banner.gd),
	# laid out in a 1920x1080 reference space fitted into the window; this sits in the
	# clear stretch between the tabs and the action button on its right, in the tabs' own
	# small caps and the dim text colour, brightening under the pointer - so it reads as
	# part of the bar on both screens. Placed every frame from the banner's own numbers.
	_home = Button.new()
	_home.text = "ESC    RETURN TO THE PEN"
	_home.flat = true
	_home.focus_mode = Control.FOCUS_NONE
	_home.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var caps := FontVariation.new()
	caps.base_font = bold
	caps.spacing_glyph = 1
	_home.add_theme_font_override("font", caps)
	_home.add_theme_color_override("font_color", Color(0.58, 0.62, 0.70, 0.9))
	_home.add_theme_color_override("font_hover_color", Color(0.90, 0.92, 0.95))
	_home.add_theme_color_override("font_pressed_color", Color(0.90, 0.92, 0.95))
	_home.pressed.connect(func() -> void: _show_ask(true))
	_home.visible = false
	add_child(_home)

	_ask = Control.new()
	_ask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ask.mouse_filter = Control.MOUSE_FILTER_STOP
	_ask.visible = false
	add_child(_ask)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ask.add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ask.add_child(centre)
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.09, 0.11, 0.15, 0.96)
	box.border_color = Color(0.55, 0.75, 0.95, 0.5)
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	box.content_margin_left = 34
	box.content_margin_right = 34
	box.content_margin_top = 24
	box.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", box)
	centre.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	var question := Label.new()
	question.text = "Back to the chicken pen?"
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question.add_theme_font_override("font", bold)
	question.add_theme_font_size_override("font_size", 24)
	question.add_theme_color_override("font_color", Color(0.94, 0.95, 0.97))
	column.add_child(question)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	column.add_child(row)
	var yes := _button("Yes", regular, true)
	yes.pressed.connect(func() -> void:
		_show_ask(false)
		come_back())
	row.add_child(yes)
	var no := _button("No", regular, false)
	no.pressed.connect(func() -> void: _show_ask(false))
	row.add_child(no)


func _button(text: String, font: Font, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 17)
	for state in ["normal", "hover", "pressed"]:
		var s := StyleBoxFlat.new()
		var base: Color = Color(0.26, 0.46, 0.72) if primary else Color(0.18, 0.21, 0.27)
		s.bg_color = base.lightened(0.12) if state == "hover" else (base.darkened(0.15) if state == "pressed" else base)
		s.set_corner_radius_all(4)
		s.content_margin_left = 18
		s.content_margin_right = 18
		s.content_margin_top = 9
		s.content_margin_bottom = 9
		b.add_theme_stylebox_override(state, s)
	b.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	return b
