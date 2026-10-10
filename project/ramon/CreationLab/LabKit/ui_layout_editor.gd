extends CanvasLayer

## THE UI LAYOUT EDITOR (10 Oct 2026, Ramon's walkthrough item 10, first used in the playable world: Systems/UiLayout).
## "a way to reposition and resize the UI cards directly inside the running scene ... Click and drag individual UI
## cards to reposition them. Resize their dimensions interactively ... Save UI Location ... Restore the saved layout
## automatically when the scene is loaded again ... Reset UI Layout ... restricted to the developer interface ... the
## simplest reusable implementation, since this could eventually be useful across other prototypes."
##
## REUSABLE: drop a Node with this script into any scene and point [member ui_root_path] at the node whose children are
## the HUD cards (Controls, at any depth of nesting under non-Control parents). Nothing in the cards has to change.
##
## HOW IT WORKS WITH CARDS THAT PLACE THEMSELVES. Most of the HUD here sizes and places itself (anchors, "first free
## spot" logic, cards that draw at a rect of their own inside a full-screen Control). So the editor does not ask a card
## to move: it remembers where you put each one as an OFFSET from where the card puts itself, and adds that offset back
## after the card has placed itself, every frame (it processes last, and re-applies when a card moves itself). Resizing
## is SCALE, from the card's top-left corner: the cards draw their own content at their own sizes, so scaling is the one
## resize that works for every card without rebuilding it. Shift while dragging a corner scales width and height apart.
##
## F2 (by default) turns editing on and off. While on: the mouse is free, every card has an outline and its name, drag
## one to move it, drag the square in its bottom-right corner to resize, and the bar at the top has Save UI Location,
## Reset UI Layout and Done. Saved to user:// (one file per scene, [member save_name]); loaded and applied on start.
## Cards that report a rect of their own (drawn_rect(), belt_rect()) are outlined and grabbed by that rect.
##
## NO class_name (engine_gotchas.md): preload it, or set it on a node in the scene.

@export var ui_root_path: NodePath = ^"../../UI"
@export var key: Key = KEY_F2
## The saved layout's file name under user://.
@export var save_name: String = "ui_layout.cfg"
## Cards never touched (by node name).
@export var exclude: PackedStringArray = PackedStringArray()
## Ignore Controls this big (share of the screen in both directions) unless they report a drawn rect.
@export_range(0.5, 1.0, 0.01) var full_screen: float = 0.9
@export var verbose: bool = false

const ACCENT := Color(0.40, 0.76, 1.0)

var editing: bool = false
## Per card (NodePath string): {"offset": Vector2, "scale": Vector2}.
var _layout: Dictionary = {}
## Where each card had put itself, before our offset, this frame.
var _base: Dictionary = {}
var _applied: Dictionary = {}
var _overlay: Control
var _bar: HBoxContainer
var _note: Label
var _drag: Dictionary = {}
var _mouse_was: int = Input.MOUSE_MODE_VISIBLE
var _hover: String = ""


func _ready() -> void:
	layer = 110
	process_priority = 1000
	_overlay = Control.new()
	_overlay.name = "LayoutOverlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = false
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	_build_bar()
	_load()


func _build_bar() -> void:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.06, 0.10, 0.92)
	sb.border_color = Color(ACCENT, 0.6)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.position = Vector2(-260.0, 10.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(panel)
	_bar = HBoxContainer.new()
	_bar.add_theme_constant_override("separation", 10)
	panel.add_child(_bar)
	var title := Label.new()
	title.text = "UI LAYOUT   drag to move, corner to resize"
	title.add_theme_font_size_override("font_size", 13)
	_bar.add_child(title)
	for spec in [["Save UI Location", _save], ["Reset UI Layout", _reset], ["Done  " + OS.get_keycode_string(key), func() -> void: set_editing(false)]]:
		var b := Button.new()
		b.text = String(spec[0])
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(spec[1])
		_bar.add_child(b)
	_note = Label.new()
	_note.add_theme_font_size_override("font_size", 12)
	_note.add_theme_color_override("font_color", Color(ACCENT, 0.9))
	_bar.add_child(_note)


func set_editing(on: bool) -> void:
	editing = on
	_overlay.visible = on
	_drag = {}
	if on:
		_mouse_was = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_note.text = ""
	else:
		Input.mouse_mode = _mouse_was


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == key:
		set_editing(not editing)
		get_viewport().set_input_as_handled()


# --- The cards -----------------------------------------------------------------------------------

## The cards: {path: Control}, every visible Control under the root whose parent is not a Control (a card, not a
## part of one), not excluded, not full-screen unless it reports its own rect.
func _cards() -> Dictionary:
	var out: Dictionary = {}
	var root: Node = get_node_or_null(ui_root_path)
	if root == null:
		return out
	var screen: Vector2 = _overlay.get_viewport_rect().size
	for node in root.find_children("*", "Control", true, false):
		var c := node as Control
		if c.get_parent() is Control or String(c.name) in exclude or not c.is_visible_in_tree():
			continue
		# An empty label shows nothing: not a card.
		if c is Label and (c as Label).text.strip_edges() == "":
			continue
		var r: Rect2 = _rect_of(c)
		if r.size.x <= 2.0 or r.size.y <= 2.0:
			continue
		if not _has_own_rect(c) and r.size.x > screen.x * full_screen and r.size.y > screen.y * full_screen:
			continue
		out[String(root.get_path_to(c))] = c
	return out


static func _has_own_rect(c: Control) -> bool:
	return c.has_method("drawn_rect") or c.has_method("belt_rect")


## The card's rect on screen: its own drawn rect if it reports one, else its global rect (scale included).
func _rect_of(c: Control) -> Rect2:
	if c.has_method("belt_rect"):
		return c.call("belt_rect")
	if c.has_method("drawn_rect"):
		var r: Variant = c.call("drawn_rect")
		if r is Rect2 and (r as Rect2).size != Vector2.ZERO:
			return r
	return Rect2(c.get_global_rect().position, c.size * c.scale)


# --- Applying the layout -------------------------------------------------------------------------

func _process(_delta: float) -> void:
	var root: Node = get_node_or_null(ui_root_path)
	if root == null:
		return
	for path in _layout:
		var c := root.get_node_or_null(NodePath(path)) as Control
		if c == null:
			continue
		_apply_to(path, c)
	if editing:
		_overlay.queue_redraw()


## Where the card put itself (our last offset taken back off, unless it has moved itself since), plus the saved offset;
## and the saved scale.
func _apply_to(path: String, c: Control) -> void:
	var entry: Dictionary = _layout[path]
	var off: Vector2 = entry.get("offset", Vector2.ZERO)
	var sc: Vector2 = entry.get("scale", Vector2.ONE)
	var last: Variant = _applied.get(path)
	var base: Vector2 = c.position
	if last is Vector2 and c.position.is_equal_approx(last):
		base = _base.get(path, c.position)
	_base[path] = base
	var want: Vector2 = base + off
	if not c.position.is_equal_approx(want):
		c.position = want
	if not c.scale.is_equal_approx(sc):
		c.scale = sc
	_applied[path] = want


# --- Editing -------------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not editing:
		return
	if event is InputEventKey:
		return
	var mb := event as InputEventMouseButton
	var mm := event as InputEventMouseMotion
	if mb == null and mm == null:
		return
	# The event's own position in the overlay's (canvas) space: right at any UI scale, and for events sent by a script.
	var at: Vector2 = (_overlay.make_input_local(event) as InputEventMouse).position
	# The bar's buttons get their clicks; the rest of the bar does not block the cards under it.
	if mb != null:
		for b in _bar.get_children():
			if b is Button and (b as Button).get_global_rect().has_point(at):
				return
	if verbose and mb != null:
		print("UILAYOUT: click %s at %s" % [str(mb.pressed), str(at)])
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_start_drag(at)
		else:
			_drag = {}
		get_viewport().set_input_as_handled()
	elif mm != null:
		if not _drag.is_empty():
			_continue_drag(at, mm.shift_pressed)
		else:
			_hover = _card_at(at)
		get_viewport().set_input_as_handled()
	elif mb != null:
		get_viewport().set_input_as_handled()


func _card_at(at: Vector2) -> String:
	var cards: Dictionary = _cards()
	var best: String = ""
	var best_area: float = INF
	for path in cards:
		var r: Rect2 = _rect_of(cards[path])
		if r.grow(10.0).has_point(at) and r.get_area() < best_area:
			best = path
			best_area = r.get_area()
	return best


func _start_drag(at: Vector2) -> void:
	var path: String = _card_at(at)
	if path == "":
		return
	var c: Control = _cards()[path]
	var r: Rect2 = _rect_of(c)
	var entry: Dictionary = _layout.get(path, {"offset": Vector2.ZERO, "scale": Vector2.ONE})
	_layout[path] = entry
	var corner := Rect2(r.end - Vector2(16.0, 16.0), Vector2(20.0, 20.0))
	_drag = {"path": path, "from": at, "offset": entry["offset"], "scale": entry["scale"], "size": r.size / (entry["scale"] as Vector2),
		"resize": corner.has_point(at)}
	_note.text = ""


func _continue_drag(at: Vector2, apart: bool) -> void:
	var path: String = String(_drag["path"])
	var entry: Dictionary = _layout[path]
	var d: Vector2 = at - (_drag["from"] as Vector2)
	if bool(_drag["resize"]):
		var base: Vector2 = _drag["size"]
		var s0: Vector2 = _drag["scale"]
		var want: Vector2 = (base * s0 + d) / base.max(Vector2.ONE)
		if not apart:
			var k: float = maxf(want.x / maxf(s0.x, 0.01), want.y / maxf(s0.y, 0.01))
			want = s0 * k
		entry["scale"] = want.clamp(Vector2(0.4, 0.4), Vector2(3.0, 3.0))
	else:
		entry["offset"] = (_drag["offset"] as Vector2) + d


func _draw_overlay() -> void:
	var font: Font = ThemeDB.fallback_font
	var cards: Dictionary = _cards()
	for path in cards:
		var r: Rect2 = _rect_of(cards[path])
		var lit: bool = path == _hover or (not _drag.is_empty() and String(_drag["path"]) == path)
		_overlay.draw_rect(r, Color(ACCENT, 0.10 if lit else 0.04), true)
		_overlay.draw_rect(r, Color(ACCENT, 0.95 if lit else 0.55), false, 2.0 if lit else 1.0)
		_overlay.draw_rect(Rect2(r.end - Vector2(12.0, 12.0), Vector2(12.0, 12.0)), Color(ACCENT, 0.9), true)
		var name: String = path.get_file()
		_overlay.draw_string(font, r.position + Vector2(4.0, -4.0), name + ("  (moved)" if _layout.has(path) else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(ACCENT, 0.95))


# --- Saving ---------------------------------------------------------------------------------------

func _file() -> String:
	return "user://" + save_name


func _save() -> void:
	var cfg := ConfigFile.new()
	for path in _layout:
		var e: Dictionary = _layout[path]
		cfg.set_value("cards", path, [e.get("offset", Vector2.ZERO), e.get("scale", Vector2.ONE)])
	var err: int = cfg.save(_file())
	_note.text = "Saved" if err == OK else "Could not save (%d)" % err


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_file()) != OK or not cfg.has_section("cards"):
		return
	for path in cfg.get_section_keys("cards"):
		var v: Variant = cfg.get_value("cards", path)
		if v is Array and (v as Array).size() == 2:
			_layout[path] = {"offset": v[0], "scale": v[1]}


func _reset() -> void:
	var root: Node = get_node_or_null(ui_root_path)
	for path in _layout:
		var c := root.get_node_or_null(NodePath(path)) as Control if root != null else null
		if c != null:
			c.position = _base.get(path, c.position)
			c.scale = Vector2.ONE
	_layout.clear()
	_base.clear()
	_applied.clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_file()))
	_note.text = "Reset"
