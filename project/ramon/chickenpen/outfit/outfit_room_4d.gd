extends Node4D

## TRYM'S FITTING ROOM: Ramon's version of the outfit changer (outfit/PLAN_FITTING_ROOM.md), beside the
## in-world circle rather than instead of it. Reached from the circle with Enter (outfit_room_trip_4d.gd
## parks the farm and brings it back); runs on its own too.
##
## THE ROOM IS THE LAB'S. Its light, walls, blue teaching wall and pedestals are the Creation Lab kit's
## (read only), so it reads as one of the family. Ramon's brief, as it is laid out:
##   on the left   you, full size, on the lab's pedestal, turning on Q and E or a drag
##   on the right  the one piece you are changing, twice life size, turning on its own pedestal, its
##                 name under it ("on the right is a rotating pants in a certain color")
##   the panel     black glass down the right of the screen, with room for everything: the six parts as
##                 numbered buttons, the styles by name, the colours as big swatches, and the three
##                 things you do (surprise, undo, done), each with its key on it
## The panel never covers either pedestal (Ramon, 4 Oct: nothing in front of the exhibit), every word
## is fixed size, and it is the exhibit that turns, never the room.
##
## THE SAME OUTFIT AS THE CIRCLE. The store (outfit_4d.gd), the wearer that paints it (outfit_wearer_4d.gd)
## and the hats (outfit_pieces_4d.gd) are the circle's, unchanged: what you see here is exactly what the
## farm will show, and Done only has to save and go home, where the keeper dresses the pen's player.
##
## THE PIECE ON THE RIGHT is a second figure, dressed the same way, with every part but the chosen row's
## meshes set aside (kept on the node, not hidden): a rebuild of the figure cannot bring back the rest by
## surprise, and a hat, a boot and a shirt all centre on the same spot by their own bounds.

const Outfit := preload("res://ramon/chickenpen/outfit/outfit_4d.gd")
const Wearer := preload("res://ramon/chickenpen/outfit/outfit_wearer_4d.gd")
const Pieces := preload("res://ramon/chickenpen/outfit/outfit_pieces_4d.gd")
const Trip := preload("res://ramon/chickenpen/outfit/outfit_room_trip_4d.gd")
const Pedestal := preload("res://ramon/CreationLab/kit/kit_pedestal.gd")
const KitStyle := preload("res://ramon/CreationLab/kit/kit_style.gd")
const AVATAR := preload("res://ramon/chickenpen/scripts/block_avatar_4d.gd")
const FONT_DIR := "res://ramon/Demo/fonts/Montserrat/static/"
const STASH := &"outfit_room_stash"

## The figure's own settings when there is no farm behind the room to read them from: the pen's
## Player/Avatar in playable_world.tscn.
const FIGURE_DEFAULTS := {"build": 2, "shorts_length": 0.16, "eyes": true, "eye_spacing": 0.07,
	"eye_height": 0.038, "eye_width": 0.044, "eye_tall": 0.054, "skin": Color(0.42, 0.62, 0.36),
	"accent": Color(0.93, 0.8, 0.62)}
## Settings copied from the farm's player when there is one, so the figure here is the same figure.
const FIGURE_KEYS := ["build", "shorts_length", "eyes", "eye_spacing", "eye_height", "eye_width", "eye_tall",
	"ponytail", "skin", "accent", "hair", "w_thickness"]

@export_group("Layout")
## Where your pedestal stands, and how big it is (radius, height).
@export var figure_at: Vector4 = Vector4(-1.4, 0.0, 0.0, 0.0)
@export var figure_pedestal: Vector2 = Vector2(0.72, 0.42)
## Where the piece's pedestal stands, and how high the piece floats over it.
@export var garment_at: Vector4 = Vector4(0.3, 0.0, 0.3, 0.0)
@export var garment_pedestal: Vector2 = Vector2(0.48, 0.7)
@export_range(0.3, 2.0, 0.05) var garment_float: float = 0.62
## How big the piece is shown: scaled until its largest side is [member garment_size] metres, but never
## past [member garment_scale] times life size. A fixed 2.2 made the chicken costume 2.2 m tall, over you.
@export_range(1.0, 4.0, 0.1) var garment_scale: float = 2.2
@export_range(0.4, 2.0, 0.05) var garment_size: float = 1.0
## The camera: where it stands, what it looks at, its lens (focal length, 1.25 is the engine's 77 degrees).
## Close, so you fill half the height of the screen: Ramon's lab rule, cinema scale, not tiny platforms.
@export var camera_at: Vector4 = Vector4(0.0, 1.3, 3.3, 0.0)
@export var camera_looks_at: Vector4 = Vector4(0.0, 1.0, 0.0, 0.0)
@export_range(0.8, 4.0, 0.05) var focal_length: float = 2.0

@export_group("Motion")
@export_range(0.0, 180.0, 5.0) var turn_degrees_per_second: float = 32.0
@export_range(0.0, 360.0, 5.0) var figure_turn_degrees_per_second: float = 120.0
@export_range(0.0, 2.0, 0.05) var through_w_speed: float = 0.6

@export_group("Panel")
## How much of the screen's width the panel takes.
@export_range(0.2, 0.5, 0.01) var panel_width: float = 0.32

var _row: int = 3
var _came_in: Dictionary = {}
var _through_w: bool = false
var _t: float = 0.0
var _spin: float = 0.0
var _figure_turn: float = 0.0
var _dragging: bool = false
var _grow: float = 1.0
var _scale_now: float = 1.0
var _scale_want: float = 1.0
var _shown_key: String = ""
var _said: String = ""
var _said_left: float = 0.0

var _camera: Camera4D
var _figure: Node4D
var _figure_turntable: Node4D
var _garment: Node4D
var _garment_spin: Node4D
var _garment_holder: Node4D
var _figure_wearer: Node
var _garment_wearer: Node

var _ui: Control
var _panel: PanelContainer
var _part_buttons: Array[Button] = []
var _style_box: Container
var _style_title: Label
var _swatch_grid: GridContainer
var _colour_name: Label
var _colour_note: Label
var _through_button: Button
var _garment_label: Label
var _size_label: Label
var _toast: Label
var _seen_rev: int = -1
var _seen_row: int = -1


## The kit's swatches (its walls, floor, the code blue) are registered by its style, which the Creation
## Lab applies when it starts; without it the blue wall came out white. Before the walls build.
func _enter_tree() -> void:
	KitStyle.apply(KitStyle.mood)


func _ready() -> void:
	_came_in = Outfit.snapshot()
	_build_world()
	_build_ui()
	_refresh_ui()
	# The lab's B switches its dark look; the words in the room follow it (lab_room_4d.gd broadcasts).
	add_to_group(&"lab_mood_listener")


## The lab's mood changed: dark words on the bright floor, light ones on the dark.
func apply_mood(mood: String, _instant: bool = false) -> void:
	var dark: bool = mood == "dark"
	_garment_label.add_theme_color_override("font_color", Color(0.9, 0.93, 0.98) if dark else Color(0.10, 0.12, 0.16))
	_garment_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6) if dark else Color(1, 1, 1, 0.6))
	_size_label.add_theme_color_override("font_color", Color(0.82, 0.86, 0.94, 0.95) if dark else Color(0.18, 0.2, 0.25, 0.95))


# --- The world -------------------------------------------------------------------------------------

func _build_world() -> void:
	# Your pedestal and the piece's: the lab's own (kit_pedestal.gd).
	var left := Node4D.new()
	left.name = "FigurePedestal"
	add_child(left)
	left.position = figure_at
	var left_parts: Dictionary = Pedestal.build(left, figure_pedestal.x, figure_pedestal.y)
	var right := Node4D.new()
	right.name = "GarmentPedestal"
	add_child(right)
	right.position = garment_at
	var right_parts: Dictionary = Pedestal.build(right, garment_pedestal.x, garment_pedestal.y)

	# YOU, on a turntable set into the pedestal's deck.
	_figure_turntable = Node4D.new()
	_figure_turntable.name = "Turntable"
	left.add_child(_figure_turntable)
	_figure_turntable.position = Vector4(0.0, float(left_parts.get("deck_h", figure_pedestal.y)), 0.0, 0.0)
	_figure = _make_figure("You")
	_figure_turntable.add_child(_figure)
	_figure_wearer = _dress(_figure)

	# THE PIECE: scaled up on a holder, turning on a spinner, centred by its own bounds.
	_garment_holder = Node4D.new()
	_garment_holder.name = "Garment"
	right.add_child(_garment_holder)
	_garment_holder.position = Vector4(0.0, float(right_parts.get("deck_h", garment_pedestal.y)) + garment_float, 0.0, 0.0)
	_scale_now = garment_scale
	_garment_spin = Node4D.new()
	_garment_spin.name = "Spin"
	_garment_holder.add_child(_garment_spin)
	_garment = _make_figure("Piece")
	_garment_spin.add_child(_garment)
	_garment_wearer = _dress(_garment)

	_camera = Camera4D.new()
	_camera.name = "Camera"
	_camera.rendering_engine_name = "Cross-section"
	_camera.focal_length_3d = focal_length
	add_child(_camera)
	_camera.position = camera_at
	_camera.look_at(camera_looks_at, Vector4(0.0, 1.0, 0.0, 0.0))
	_camera.current = true


## A block figure with the player's settings: read from the farm's player when the farm is parked
## behind this room, else the pen's own numbers.
func _make_figure(part_name: String) -> Node4D:
	var figure := Node4D.new()
	figure.name = part_name
	figure.set_script(AVATAR)
	var from: Node = _farm_figure()
	for key in FIGURE_KEYS:
		if from != null and key in from:
			figure.set(key, from.get(key))
		elif FIGURE_DEFAULTS.has(key):
			figure.set(key, FIGURE_DEFAULTS[key])
	return figure


func _farm_figure() -> Node:
	var trip: Node = get_tree().root.get_node_or_null(NodePath(String(Trip.NAME))) if is_inside_tree() else null
	var pen: Node = trip.get("_pen") if trip != null else null
	return pen.get_node_or_null("Player/Avatar") if pen != null and is_instance_valid(pen) else null


## A wearer for [param figure], run before this room's own frame so the piece is filtered after any
## rebuild in the same frame (no frame of the whole figure on the right).
func _dress(figure: Node4D) -> Node:
	var wearer: Node = Wearer.new()
	wearer.name = "Wearer" + String(figure.name)
	wearer.set("avatar", figure)
	wearer.process_priority = -10
	add_child(wearer)
	return wearer


# --- Every frame -----------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	# You: Q and E (or a drag) turn the turntable.
	var turn: float = 0.0
	if Input.is_physical_key_pressed(KEY_Q):
		turn -= 1.0
	if Input.is_physical_key_pressed(KEY_E):
		turn += 1.0
	_figure_turn += turn * deg_to_rad(figure_turn_degrees_per_second) * delta
	_figure_turntable.basis = Basis4D.from_zx(_figure_turn)
	# The piece: round on the floor, and through W too when asked.
	_spin += delta
	var b: Projection = Basis4D.from_zx(_spin * deg_to_rad(turn_degrees_per_second))
	if _through_w:
		b = b * Basis4D.from_xw(sin(_spin * through_w_speed) * 1.2)
	_grow = move_toward(_grow, 1.0, delta / 0.2)
	var pop: float = lerpf(0.9, 1.0, ease(_grow, 0.4))
	_garment_spin.basis = b * Basis4D.from_scale(Vector4(pop, pop, pop, pop))
	_filter_garment()
	_scale_now = lerpf(_scale_now, _scale_want, clampf(delta * 10.0, 0.0, 1.0))
	_garment_holder.basis = Basis4D.from_scale(Vector4(_scale_now, _scale_now, _scale_now, _scale_now))
	if _seen_rev != Outfit.changes() or _seen_row != _row:
		_refresh_ui()
	_place_world_labels(delta)
	_fit_panel()


## The panel down the right of the screen, full height, scaled so its contents fill that height: the same
## share of the screen at 720p, 1080p or 4K, with the pen's UI size or without it (run on its own at 4K
## it was small type over a tall empty panel). The panel's sections keep fixed sizes, so this never
## changes while you use it.
func _fit_panel() -> void:
	var screen: Vector2 = _ui.get_viewport_rect().size
	var least: Vector2 = _panel.get_combined_minimum_size()
	var height: float = screen.y - 48.0
	var fit: float = clampf(height / maxf(least.y, 1.0), 0.5, 2.5)
	var width: float = maxf(least.x, (screen.x * panel_width - 24.0) / fit)
	_panel.scale = Vector2(fit, fit)
	_panel.size = Vector2(width, height / fit)
	_panel.position = Vector2(screen.x - 24.0 - width * fit, 24.0)
	# The words in the room follow the same measure, against a 1080-line screen.
	var words: float = clampf(screen.y / 1080.0, 0.6, 2.5)
	for label in [_garment_label, _size_label, _toast]:
		label.scale = Vector2(words, words)


## Only the chosen row's parts keep their meshes; the rest are set aside on the node, and given back
## the moment their row is chosen. Then the piece is centred on the spinner by what is left.
func _filter_garment() -> void:
	var low := Vector4(INF, INF, INF, INF)
	var high := Vector4(-INF, -INF, -INF, -INF)
	var inverse: Projection = _garment.global_basis.inverse()
	for node in _garment.find_children("*", "MeshInstance4D", true, false):
		var part := node as MeshInstance4D
		var show: bool = _in_row(part)
		if show and part.has_meta(STASH):
			part.mesh = part.get_meta(STASH)
			part.remove_meta(STASH)
		elif not show and part.mesh != null:
			part.set_meta(STASH, part.mesh)
			part.mesh = null
		if show and part.mesh is BoxTetraMesh4D:
			var half: Vector4 = (part.mesh as BoxTetraMesh4D).size * 0.5
			var centre: Vector4 = inverse * (part.global_position - _garment.global_position)
			low = Vector4(minf(low.x, centre.x - half.x), minf(low.y, centre.y - half.y), minf(low.z, centre.z - half.z), 0.0)
			high = Vector4(maxf(high.x, centre.x + half.x), maxf(high.y, centre.y + half.y), maxf(high.z, centre.z + half.z), 0.0)
	if high.x > low.x:
		var middle: Vector4 = (low + high) * 0.5
		_garment.position = -Vector4(middle.x, middle.y, middle.z, 0.0)
		var extent: Vector4 = high - low
		var largest: float = maxf(extent.x, maxf(extent.y, extent.z))
		_scale_want = clampf(garment_size / maxf(largest, 0.01), 1.0, garment_scale)


## Whether [param part] of the piece belongs to the chosen row.
func _in_row(part: MeshInstance4D) -> bool:
	var name_: String = String(part.name)
	if part.has_meta(Pieces.PIECE):
		return _row == Wearer.ROW_HAT
	match _row:
		Wearer.ROW_HAT:
			return name_ == "Cap"
		Wearer.ROW_SKIN:
			return name_ == "Head" or name_.begins_with("Ear") or name_.begins_with("Eye")
	return Wearer.row_of(name_) == _row and not (_row == Wearer.ROW_TROUSERS and not Outfit.long_legs() and (name_.begins_with("Thigh") or name_.begins_with("Shin")))


# --- Doing things ----------------------------------------------------------------------------------

func choose_row(row: int) -> void:
	_row = clampi(row, 0, Outfit.ROWS.size() - 1)
	_grow = 0.0


func change_colour(step: int) -> void:
	Outfit.step(Outfit.ROWS[_row][1], step)
	_changed()


func set_colour(index: int) -> void:
	Outfit.set_value(Outfit.ROWS[_row][1], index)
	_changed()


func change_style(step: int) -> void:
	var key: String = Outfit.ROWS[_row][2]
	if key == "":
		return
	Outfit.step(key, step)
	_changed()


func set_style(index: int) -> void:
	var key: String = Outfit.ROWS[_row][2]
	if key != "":
		Outfit.set_value(key, index)
		_changed()


func surprise() -> void:
	Outfit.randomise(RandomNumberGenerator.new())
	_changed(true)


func undo() -> void:
	Outfit.restore(_came_in)
	_changed(true)


func toggle_through_w() -> void:
	_through_w = not _through_w
	_refresh_ui()


## Done: saved, and home to the farm if there is one behind this room.
func done() -> void:
	var err: Error = Outfit.save()
	var trip: Node = get_tree().root.get_node_or_null(NodePath(String(Trip.NAME)))
	if trip != null and bool(trip.call("has_pen")):
		trip.call("come_back", true)
		return
	_toast_say("Saved. It goes with you to the farm." if err == OK else "Could not save.")


## Esc: back to what you came in wearing, and home without saving anything new.
func cancel() -> void:
	Outfit.restore(_came_in)
	var trip: Node = get_tree().root.get_node_or_null(NodePath(String(Trip.NAME)))
	if trip != null and bool(trip.call("has_pen")):
		trip.call("come_back", false)
		return
	_changed(true)
	_toast_say("Back to what you came in wearing.")


func _changed(everything: bool = false) -> void:
	_grow = 0.0
	for wearer in [_figure_wearer, _garment_wearer]:
		if everything:
			for i in Outfit.ROWS.size():
				wearer.call("flash", i, 0.6)
		else:
			wearer.call("flash", _row, 0.8)


func _unhandled_input(event: InputEvent) -> void:
	var trip: Node = get_tree().root.get_node_or_null(NodePath(String(Trip.NAME)))
	if trip != null and bool(trip.call("is_busy")):
		return
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.button_index == MOUSE_BUTTON_LEFT:
		# A drag anywhere left of the panel turns you round.
		_dragging = mouse.pressed and mouse.position.x < _ui.get_viewport_rect().size.x * (1.0 - panel_width)
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _dragging:
		_figure_turn += motion.relative.x * 0.01
		return
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	var code: Key = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	var handled: bool = true
	if code >= KEY_1 and code <= KEY_6 and not key.echo:
		choose_row(code - KEY_1)
	elif code >= KEY_KP_1 and code <= KEY_KP_6 and not key.echo:
		choose_row(code - KEY_KP_1)
	elif code == KEY_LEFT or code == KEY_A:
		change_colour(-1)
	elif code == KEY_RIGHT or code == KEY_D:
		change_colour(1)
	elif code == KEY_UP or code == KEY_W:
		change_style(-1)
	elif code == KEY_DOWN or code == KEY_S:
		change_style(1)
	elif code == KEY_X and not key.echo:
		surprise()
	elif (code == KEY_Z or code == KEY_BACKSPACE) and not key.echo:
		undo()
	elif code == KEY_T and not key.echo:
		toggle_through_w()
	elif (code == KEY_ENTER or code == KEY_KP_ENTER) and not key.echo:
		done()
	elif code == KEY_ESCAPE and not key.echo:
		cancel()
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


# --- The panel ------------------------------------------------------------------------------------

func _font(weight: String) -> Font:
	return load(FONT_DIR + "Montserrat-%s.ttf" % weight) as Font


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "UI"
	add_child(layer)
	_ui = Control.new()
	_ui.name = "FittingRoomUI"
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_ui)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var glass: StyleBoxFlat = StyleBoxFlat.new()
	glass.bg_color = Color(KitStyle.UI_GLASS.r, KitStyle.UI_GLASS.g, KitStyle.UI_GLASS.b, KitStyle.UI_GLASS_ALPHA)
	glass.border_color = Color(1, 1, 1, 0.16)
	glass.set_border_width_all(1)
	glass.set_corner_radius_all(10)
	glass.content_margin_left = 28.0
	glass.content_margin_right = 28.0
	glass.content_margin_top = 26.0
	glass.content_margin_bottom = 24.0
	_panel.add_theme_stylebox_override("panel", glass)
	_ui.add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	_panel.add_child(column)
	column.add_child(_text("TRYM'S", 13, KitStyle.UI_INK_DIM, "SemiBold"))
	column.add_child(_text("Fitting room", 34, KitStyle.UI_INK, "SemiBold"))
	column.add_child(_text("Everything you change is on you at once. Done takes it to the farm.", 15, KitStyle.UI_INK_SOFT, "Medium", true))

	column.add_child(_section("PART"))
	var parts := GridContainer.new()
	parts.columns = 2
	parts.add_theme_constant_override("h_separation", 10)
	parts.add_theme_constant_override("v_separation", 10)
	column.add_child(parts)
	for i in Outfit.ROWS.size():
		var b: Button = _button("%d   %s" % [i + 1, String(Outfit.ROWS[i][0]).capitalize()], 19)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(choose_row.bind(i))
		parts.add_child(b)
		_part_buttons.append(b)

	_style_title = _section("STYLE   ↑ ↓")
	column.add_child(_style_title)
	_style_box = HFlowContainer.new()
	_style_box.add_theme_constant_override("h_separation", 8)
	_style_box.add_theme_constant_override("v_separation", 8)
	# THE PANEL NEVER CHANGES SIZE (Ramon, 4 Oct: no cards that resize): every section keeps the room
	# its tallest case needs, whichever part is chosen. Styles take two rows at most (the hats).
	_style_box.custom_minimum_size.y = 84.0
	column.add_child(_style_box)

	column.add_child(_section("COLOUR   ← →"))
	_swatch_grid = GridContainer.new()
	_swatch_grid.columns = 5
	_swatch_grid.add_theme_constant_override("h_separation", 10)
	_swatch_grid.add_theme_constant_override("v_separation", 10)
	# Three rows of swatches, the clothing palettes' thirteen; skin and hair have eight.
	_swatch_grid.custom_minimum_size.y = 58.0 * 3.0 + 10.0 * 2.0
	column.add_child(_swatch_grid)
	_colour_name = _text("", 20, KitStyle.UI_INK, "SemiBold")
	column.add_child(_colour_name)
	_colour_note = _text("", 14, KitStyle.UI_INK_DIM, "Medium", true)
	_colour_note.custom_minimum_size.y = 40.0
	column.add_child(_colour_note)

	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(gap)
	_through_button = _button("Turn the piece through W   T", 16)
	_through_button.toggle_mode = true
	_through_button.toggled.connect(func(_on: bool) -> void: toggle_through_w())
	column.add_child(_through_button)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)
	var surprise_b: Button = _button("Surprise me   X", 17)
	surprise_b.pressed.connect(surprise)
	var undo_b: Button = _button("Undo   Z", 17)
	undo_b.pressed.connect(undo)
	for b in [surprise_b, undo_b]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	var done_b: Button = _button("Done   Enter", 21, true)
	done_b.custom_minimum_size.y = 56.0
	done_b.pressed.connect(done)
	column.add_child(done_b)
	column.add_child(_text("1 to 6  part      Q E  turn you      Esc  back without changing", 13, KitStyle.UI_INK_DIM, "Medium"))

	# Under the piece and under you, in the room's own space but drawn flat (the world tags' way).
	_garment_label = _text("", 26, Color(0.10, 0.12, 0.16), "SemiBold")
	_garment_label.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.6))
	_ui.add_child(_garment_label)
	_size_label = _text("", 15, Color(0.18, 0.2, 0.25, 0.95), "SemiBold")
	_ui.add_child(_size_label)
	_toast = _text("", 20, KitStyle.UI_INK, "SemiBold")
	var toast_box := StyleBoxFlat.new()
	toast_box.bg_color = Color(KitStyle.UI_GLASS.r, KitStyle.UI_GLASS.g, KitStyle.UI_GLASS.b, 0.9)
	toast_box.set_corner_radius_all(6)
	toast_box.content_margin_left = 16.0
	toast_box.content_margin_right = 16.0
	toast_box.content_margin_top = 8.0
	toast_box.content_margin_bottom = 8.0
	_toast.add_theme_stylebox_override("normal", toast_box)
	_toast.visible = false
	_ui.add_child(_toast)


func _text(words: String, px: int, colour: Color, weight: String, wrap: bool = false) -> Label:
	var label := Label.new()
	label.text = words
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", _font(weight))
	label.add_theme_font_size_override("font_size", px)
	label.add_theme_color_override("font_color", colour)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _section(words: String) -> Label:
	var label: Label = _text(words, 13, KitStyle.UI_ACCENT, "SemiBold")
	return label


## A button in the kit's black glass: a faint fill, a thin edge, white type; the chosen one in the lab's
## code blue. Never takes the keyboard focus, so Enter and Space stay this room's keys.
func _button(words: String, px: int, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = words
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", _font("SemiBold"))
	b.add_theme_font_size_override("font_size", px)
	b.add_theme_color_override("font_color", KitStyle.UI_INK)
	b.add_theme_color_override("font_hover_color", KitStyle.UI_INK)
	b.add_theme_color_override("font_pressed_color", KitStyle.UI_INK)
	var blue: Color = KitStyle.CODE_BLUE["bright"]
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(6)
		box.content_margin_left = 14.0
		box.content_margin_right = 14.0
		box.content_margin_top = 9.0
		box.content_margin_bottom = 9.0
		box.border_color = Color(1, 1, 1, 0.22)
		box.set_border_width_all(1)
		if primary:
			box.bg_color = blue.lightened(0.12) if state == "hover" else blue
		else:
			box.bg_color = Color(1, 1, 1, 0.16 if state == "hover" else (0.22 if state == "pressed" else 0.08))
		b.add_theme_stylebox_override(state, box)
	return b


## A swatch: a square of the colour itself, ringed in white when chosen, a hair of edge when not.
func _swatch(colour: Color, chosen: bool, muted: bool, index: int) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(58, 58)
	b.tooltip_text = Outfit.name_of(Outfit.ROWS[_row][1], index)
	var shown: Color = colour.lerp(Color(0.45, 0.47, 0.5), 0.7) if muted else colour
	for state in ["normal", "hover", "pressed"]:
		var box := StyleBoxFlat.new()
		box.bg_color = shown.lightened(0.08) if state == "hover" else shown
		box.set_corner_radius_all(6)
		box.border_color = Color.WHITE if chosen else Color(1, 1, 1, 0.25)
		box.set_border_width_all(4 if chosen else 1)
		b.add_theme_stylebox_override(state, box)
	b.pressed.connect(set_colour.bind(index))
	return b


## The panel to the outfit: the chosen part lit, its styles and swatches rebuilt.
func _refresh_ui() -> void:
	_seen_rev = Outfit.changes()
	_seen_row = _row
	var blue: Color = KitStyle.CODE_BLUE["bright"]
	for i in _part_buttons.size():
		var box := (_part_buttons[i].get_theme_stylebox("normal") as StyleBoxFlat)
		box.bg_color = blue if i == _row else Color(1, 1, 1, 0.08)
		box.border_color = Color(1, 1, 1, 0.55) if i == _row else Color(1, 1, 1, 0.22)
	var row: Array = Outfit.ROWS[_row]
	var style_key: String = row[2]
	for child in _style_box.get_children():
		child.queue_free()
	if style_key == "":
		_style_box.add_child(_text("%s comes in one style." % String(row[0]).capitalize(), 15, KitStyle.UI_INK_DIM, "Medium"))
	else:
		var styles: Array = Outfit.options(style_key)
		for i in styles.size():
			var b: Button = _button(String(styles[i]), 16)
			var chosen: bool = i == Outfit.get_value(style_key)
			if chosen:
				var box := (b.get_theme_stylebox("normal") as StyleBoxFlat)
				box.bg_color = blue
				box.border_color = Color(1, 1, 1, 0.55)
			b.pressed.connect(set_style.bind(i))
			_style_box.add_child(b)
	for child in _swatch_grid.get_children():
		child.queue_free()
	var colour_key: String = row[1]
	var muted: bool = _row == Wearer.ROW_HAT and not Outfit.hat_takes_colour()
	var list: Array = Outfit.options(colour_key)
	for i in list.size():
		_swatch_grid.add_child(_swatch(list[i], i == Outfit.get_value(colour_key), muted, i))
	_colour_name.text = Outfit.name_of(colour_key, Outfit.get_value(colour_key))
	_colour_note.text = ("%s takes no colour. Pick one for the next hat." % Outfit.name_of("hat", Outfit.hat())) if muted else ""
	_through_button.set_pressed_no_signal(_through_w)
	var said: String = String(row[0])
	var colour_name: String = Outfit.name_of(colour_key, Outfit.get_value(colour_key))
	if style_key != "":
		var style_name: String = Outfit.name_of(style_key, Outfit.get_value(style_key))
		said += "   %s" % (style_name if muted else "%s, %s" % [style_name, colour_name])
	else:
		said += "   %s" % colour_name
	_garment_label.text = said


func _toast_say(words: String) -> void:
	_said = words
	_said_left = 2.5


## The piece's name under its pedestal, your four sizes under yours, and any word to say, each where
## the camera sees that spot, at a fixed size.
func _place_world_labels(delta: float) -> void:
	var screen: Vector2 = _ui.get_viewport_rect().size
	var to_canvas: Vector2 = screen / Vector2(_ui.get_viewport().get_size())
	_garment_label.size = _garment_label.get_combined_minimum_size()
	var k: float = _garment_label.scale.x
	# Under the pedestal's front edge, which is the lowest of it on screen.
	var under: Vector4 = global_position + garment_at + Vector4(0.0, 0.0, garment_pedestal.x, 0.0)
	var p: Vector2 = _camera.world_to_viewport(under) * to_canvas
	_garment_label.position = Vector2(p.x - _garment_label.size.x * 0.5 * k, p.y + 12.0 * k)
	var size4: Vector4 = _measure(_figure)
	_size_label.text = "%.2f m tall   %.2f wide   %.2f deep   %.2f thick in W" % [size4.y, size4.x, size4.z, size4.w]
	_size_label.size = _size_label.get_combined_minimum_size()
	var j: float = _size_label.scale.x
	var foot: Vector4 = global_position + figure_at + Vector4(0.0, 0.0, figure_pedestal.x, 0.0)
	var q: Vector2 = _camera.world_to_viewport(foot) * to_canvas
	_size_label.position = Vector2(q.x - _size_label.size.x * 0.5 * j, q.y + 12.0 * j)
	_said_left = maxf(_said_left - delta, 0.0)
	_toast.visible = _said_left > 0.0
	if _toast.visible:
		_toast.text = _said
		_toast.size = _toast.get_combined_minimum_size()
		var left_width: float = screen.x * (1.0 - panel_width)
		_toast.position = Vector2((left_width - _toast.size.x * _toast.scale.x) * 0.5, 40.0)
		_toast.modulate.a = clampf(_said_left / 0.4, 0.0, 1.0)


## A figure's extent in its own frame, as the circle's readout measures it.
func _measure(figure: Node4D) -> Vector4:
	var low := Vector4(INF, INF, INF, INF)
	var high := Vector4(-INF, -INF, -INF, -INF)
	var inverse: Projection = figure.global_basis.inverse()
	for node in figure.find_children("*", "MeshInstance4D", true, false):
		var part := node as MeshInstance4D
		if not (part.mesh is BoxTetraMesh4D):
			continue
		var half: Vector4 = (part.mesh as BoxTetraMesh4D).size * 0.5
		var centre: Vector4 = inverse * (part.global_position - figure.global_position)
		low = Vector4(minf(low.x, centre.x - half.x), minf(low.y, centre.y - half.y), minf(low.z, centre.z - half.z), minf(low.w, centre.w - half.w))
		high = Vector4(maxf(high.x, centre.x + half.x), maxf(high.y, centre.y + half.y), maxf(high.z, centre.z + half.z), maxf(high.w, centre.w + half.w))
	return high - low if high.x > low.x else Vector4.ZERO
