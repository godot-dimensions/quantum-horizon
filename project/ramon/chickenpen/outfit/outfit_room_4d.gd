extends Node4D

## TRYM'S FITTING ROOM: the advanced mode of the outfit changer (outfit/PLAN_FITTING_ROOM.md), Ramon's
## version. The fitting circle's basic mode has colours on the arrow keys; its last stop, ADVANCED, brings
## you here (outfit_room_trip_4d.gd parks the farm and brings it back). It runs on its own too.
##
## THE ROOM IS THE CREATION LAB'S. Its light is the lab's (kit_style.gd ROOM_LIGHT under the numbers
## Ramon saved in CreationLab/creation_lab_tuning.cfg, and the lab's downlight over each pedestal), its
## walls the kit's in the code blue, its pedestals the lab's showcase pedestal in miniature (hologram and
## printed band included), all read only. Tab shows the light's panel (fitting_room_tuner.gd), which
## saves this room's own light to TUNING; the lab's file is never written. Ramon's brief, as laid out:
##   on the left   you, full size, on the lab's pedestal, turning on Q and E or a drag
##   on the right  the one piece you are changing, shown large, turning on its own pedestal, its name
##                 under it ("on the right is a rotating pants in a certain color")
##   the panel     black glass down the right of the screen, with room for everything: the six parts as
##                 numbered buttons, the styles by name, the colours as big swatches, and the three
##                 things you do (surprise, undo, done), each with its key on it
## The panel never covers either pedestal (Ramon, 4 Oct: nothing in front of the exhibit), and it is the
## exhibit that turns, never the room.
##
## THE PANEL IS SIZED, NEVER SCALED (Ramon, 8 Oct: "dynamic ... no rasterized pixels. check how the kit
## does it"). As the kit's overlays do (kit_prompt.gd), every size is worked out from the screen's height
## (u is the height over 720) on the kit's type ladder (kit_style.gd type_px), and set again only when the
## window changes size; type is laid out at the size it shows. The first version scaled the whole panel
## to fit, and a wrapped line fed the fit back into itself every frame, so it jittered.
##
## THE SAME OUTFIT AS THE CIRCLE. The store (outfit_4d.gd), the wearer (outfit_wearer_4d.gd) and the hats
## (outfit_pieces_4d.gd) are the circle's: what you see here is what the farm will show, and Done only has
## to save and go home, where the keeper dresses the pen's player.
##
## THE PIECE ON THE RIGHT is a second figure, dressed the same way, with every part but the chosen row's
## meshes set aside (kept on the node, not hidden): a rebuild cannot bring back the rest by surprise, and
## a hat, a boot and a shirt all centre on the same spot by their own bounds.

const Outfit := preload("res://ramon/chickenpen/outfit/outfit_4d.gd")
const Wearer := preload("res://ramon/chickenpen/outfit/outfit_wearer_4d.gd")
const Pieces := preload("res://ramon/chickenpen/outfit/outfit_pieces_4d.gd")
const Trip := preload("res://ramon/chickenpen/outfit/outfit_room_trip_4d.gd")
const Pedestal := preload("res://ramon/CreationLab/kit/kit_pedestal.gd")
const KitStyle := preload("res://ramon/CreationLab/kit/kit_style.gd")
const LabRoom := preload("res://ramon/CreationLab/LabKit/lab_room_4d.gd")
const KitLight := preload("res://ramon/CreationLab/kit/kit_light_4d.gd")
const Tuner := preload("res://ramon/chickenpen/outfit/fitting_room_tuner.gd")
const LabBuild := preload("res://ramon/CreationLab/scripts/chamber_build.gd")
const LabGrid := preload("res://ramon/CreationLab/LabKit/lab_grid.gd")
const LabPrint := preload("res://ramon/CreationLab/LabKit/lab_print.gd")
const Glyphs := preload("res://ramon/CreationLab/kit/kit_glyphs.gd")
const AVATAR := preload("res://ramon/chickenpen/scripts/block_avatar_4d.gd")
## The Creation Lab's saved light (Ramon's numbers from its tuning panel), read only.
const LAB_TUNING := "res://ramon/CreationLab/creation_lab_tuning.cfg"
## This room's own light, saved from its Tab panel (fitting_room_tuner.gd); read first when it is there.
const TUNING := "res://ramon/chickenpen/outfit/fitting_room_tuning.cfg"
## What the lab's tuning panel starts from when nothing is saved (kit_tuner.gd START).
const LAB_LIGHT := {"spots": 3.26, "washes": 0.0, "fill": 1.52, "sun": 0.66, "exposure": 1.05}
## The lab's downlight over its pedestal (creation_lab.tscn Downlight).
const DOWNLIGHT := {"angle": 35.71, "softness": 0.42, "reach": 10.37, "attenuation": 0.3,
	"energy": {"bright": 2.69, "dark": 3.6},
	"color": {"bright": Color(0.8922, 0.9016, 0.9126), "dark": Color(1, 0.95, 0.88)}}
const STASH := &"outfit_room_stash"
## The Creation Lab's showcase pedestal: radius and height (creation_lab.tscn Showcase), its hologram
## as Ramon tuned it (creation_lab_tuning.cfg [hologram], read when it is there) and its colour
## (kit_showcase_4d.gd), and its printed band (where on the body, in the lab's metres, and how wide).
const LAB_PEDESTAL := Vector2(3.4, 0.9)
const LAB_HOLO := {"holo_height": 0.65, "holo_base": 0.8, "holo_falloff": 1.4, "holo_fine": 0.0}
const HOLO_COLOUR := Color(0.25, 0.60, 1.0)
const LAB_BAND := {"y0": 0.27, "y1": 0.49, "width": 2.4}

## The figure's own settings when there is no farm behind the room to read them from: the pen's
## Player/Avatar in playable_world.tscn.
const FIGURE_DEFAULTS := {"build": 2, "shorts_length": 0.16, "eyes": true, "eye_spacing": 0.07,
	"eye_height": 0.038, "eye_width": 0.044, "eye_tall": 0.054, "skin": Color(0.42, 0.62, 0.36),
	"accent": Color(0.93, 0.8, 0.62)}
## Settings copied from the farm's player when there is one, so the figure here is the same figure.
const FIGURE_KEYS := ["build", "shorts_length", "eyes", "eye_spacing", "eye_height", "eye_width", "eye_tall",
	"ponytail", "skin", "accent", "hair", "w_thickness"]

@export_group("Layout")
## Where your pedestal stands, and its radius. THE CREATION LAB'S PEDESTAL, IN MINIATURE (Ramon, 8 Oct:
## "use the pedestals from the creator lab"): the showcase's own (kit_showcase_4d.gd, 3.4 m across and
## 0.9 high in creation_lab.tscn), every part at its proportions, so the white ring stays a thin rim
## round the blue deck as it is there, with its hologram rising off the deck and its band printed on
## its side. Built with the lab's trims at a smaller size, never scaled, so its materials stay true.
@export var figure_at: Vector4 = Vector4(-1.6, 0.0, 0.0, 0.0)
@export_range(0.4, 2.0, 0.01) var figure_pedestal_radius: float = 0.95
## Where the piece's pedestal stands, its radius, and how high the piece floats over it, in the
## pedestal's hologram drawn up to meet it.
@export var garment_at: Vector4 = Vector4(0.2, 0.0, 0.25, 0.0)
@export_range(0.3, 2.0, 0.01) var garment_pedestal_radius: float = 0.62
@export_range(0.3, 2.0, 0.05) var garment_float: float = 1.0
## How big the piece is shown: scaled until its largest side is [member garment_size] metres, but never
## past [member garment_scale] times life size. A fixed 2.2 made the chicken costume 2.2 m tall, over you.
@export_range(1.0, 4.0, 0.1) var garment_scale: float = 2.2
@export_range(0.4, 2.0, 0.05) var garment_size: float = 1.0
## The camera: where it stands, what it looks at, its lens (focal length, 1.25 is the engine's 77 degrees).
## Close, so you fill half the height of the screen: Ramon's lab rule, cinema scale, not tiny platforms.
@export var camera_at: Vector4 = Vector4(-0.45, 1.3, 3.4, 0.0)
@export var camera_looks_at: Vector4 = Vector4(-0.45, 1.0, 0.0, 0.0)
@export_range(0.8, 4.0, 0.05) var focal_length: float = 2.0
## How high the downlights hang (under the room's ceiling).
@export_range(2.0, 10.0, 0.1) var light_height: float = 4.85

@export_group("Motion")
@export_range(0.0, 180.0, 5.0) var turn_degrees_per_second: float = 32.0
@export_range(0.0, 360.0, 5.0) var figure_turn_degrees_per_second: float = 120.0
@export_range(0.0, 2.0, 0.05) var through_w_speed: float = 0.6

@export_group("Panel")
## How much of the screen's width the panel takes.
@export_range(0.2, 0.5, 0.01) var panel_width: float = 0.31

var _row: int = 3
var _came_in: Dictionary = {}
var _through_w: bool = false
var _spin: float = 0.0
var _figure_turn: float = 0.0
var _dragging: bool = false
var _grow: float = 1.0
var _scale_now: float = 1.0
var _scale_want: float = 1.0
var _said: String = ""
var _said_left: float = 0.0
var _u: float = 1.0

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
var _column: VBoxContainer
var _part_grid: GridContainer
var _part_buttons: Array[Button] = []
var _style_box: HFlowContainer
var _swatch_grid: GridContainer
var _wheel: ColorPicker
## The outfit's revision after the wheel's own last change: the panel leaves the wheel be while it is
## the one changing the colour, so a drag is never pulled back under the cursor.
var _wheel_rev: int = -1
var _wheel_row: int = -1
var _colour_name: Label
var _colour_note: Label
var _through_button: Button
var _garment_label: Label
var _size_label: Label
var _toast: Label
var _seen_rev: int = -1
var _seen_row: int = -1
## The light per mood: {spots, washes, fill, sun, exposure, sun_up, sun_turn} (push_light lays it).
var light_values: Dictionary = {}
## Where the Tab panel saves and the room reads its own light; a test points this at a file of its own.
var tuning_path: String = TUNING
var _figure_light: Node4D
var _garment_light: Node4D
var _tuner: PanelContainer
## Both pedestals' parts (kit_pedestal.gd build), recoloured when the mood changes.
var _pedestals: Array[Dictionary] = []
## Every piece of type and every box with padding, with the size it takes at a 720-high screen, so a
## change of window size can set them all again: [Control, ladder role, extra px] and
## [StyleBoxFlat, pad x, pad y, corner].
var _type: Array = []
var _pads: Array = []


## The kit's swatches (its walls, floor, the code blue) are registered by its style, which the Creation
## Lab applies when it starts; without it the blue walls come out white. Before the walls build.
func _enter_tree() -> void:
	KitStyle.apply(KitStyle.mood)


func _ready() -> void:
	_came_in = Outfit.snapshot()
	_read_light()
	KitStyle.gain["spot"] = float(light_for(current_mood())["spots"])
	_build_world()
	_build_ui()
	# The lab's B switches its dark look; the light and the words in the room follow it (lab_room_4d.gd
	# broadcasts to this group).
	add_to_group(&"lab_mood_listener")
	push_light()
	_refresh_ui()
	_layout()
	_ui.resized.connect(_layout)


## THE CREATION LAB'S LIGHT, as this room starts: its room light (kit_style.gd ROOM_LIGHT) under the
## numbers Ramon saved with the lab's tuning panel (spots, sky fill, sun, exposure, and the sun's height
## and turn), read only; then over those, this room's own, when he has saved some from its Tab panel
## (TUNING). Per mood, so B finds its own numbers too.
func _read_light() -> void:
	light_values.clear()
	var lab := ConfigFile.new()
	var own := ConfigFile.new()
	var has_lab: bool = lab.load(LAB_TUNING) == OK
	var has_own: bool = own.load(tuning_path) == OK
	for mood in LabRoom.MOODS:
		var base: Dictionary = _base_light(mood)
		var v: Dictionary = LAB_LIGHT.duplicate() if mood == "bright" else {"spots": 1.0, "washes": 0.0, "fill": 1.0,
			"sun": 1.0, "exposure": float(base["exposure"])}
		v["sun_up"] = float(base.get("key_elevation", 50.0))
		v["sun_turn"] = float(base.get("key_azimuth", 30.0))
		if has_lab:
			if lab.has_section("light_" + mood):
				for k in lab.get_section_keys("light_" + mood):
					v[k] = float(lab.get_value("light_" + mood, k))
			v["sun_up"] = float(lab.get_value("room", "sun_up", v["sun_up"]))
			v["sun_turn"] = float(lab.get_value("room", "sun_turn", v["sun_turn"]))
		if has_own and own.has_section("light_" + mood):
			for k in own.get_section_keys("light_" + mood):
				v[k] = float(own.get_value("light_" + mood, k))
		light_values[mood] = v


## A mood's light as the lab lays it before any tuning: lab_room_4d.gd MOODS under kit_style.gd ROOM_LIGHT.
func _base_light(mood: String) -> Dictionary:
	var base: Dictionary = (LabRoom.MOODS[mood] as Dictionary).duplicate()
	base.merge(KitStyle.ROOM_LIGHT.get(mood, {}), true)
	return base


## The light numbers for [param mood] (the tuner changes them in place, then calls push_light).
func light_for(mood: String) -> Dictionary:
	if not light_values.has(mood):
		light_values[mood] = LAB_LIGHT.duplicate()
	return light_values[mood]


## The mood the room's light is in (lab_room_4d.gd; B switches it).
func current_mood() -> String:
	var room: Node = get_node_or_null("Light")
	return String(room.get("mood")) if room != null else KitStyle.mood


## The light numbers laid on the room, the way the lab's tuning panel lays them (kit_tuner.gd _push_light):
## sky fill, the sun and exposure as the room's mood overrides, the spots as the kit's gain.
func push_light() -> void:
	var room: Node = get_node_or_null("Light")
	if room == null:
		return
	var all: Dictionary = KitStyle.ROOM_LIGHT.duplicate(true)
	for mood in LabRoom.MOODS:
		var v: Dictionary = light_for(mood)
		var base: Dictionary = _base_light(mood)
		var over: Dictionary = (KitStyle.ROOM_LIGHT.get(mood, {}) as Dictionary).duplicate()
		over["ambient"] = (base["ambient"] as Color) * float(v["fill"])
		over["key_energy"] = float(base["key_energy"]) * float(v["sun"])
		over["exposure"] = float(v["exposure"])
		over["key_elevation"] = float(v["sun_up"])
		over["key_azimuth"] = float(v["sun_turn"])
		all[mood] = over
	room.set("mood_overrides", all)
	# The room tells everything listening, this room included (apply_mood), which lays the spots.
	room.call("set_mood", current_mood(), true, false)


## The room's light and both downlights to its Tab file. Never the lab's.
func save_tuning() -> Error:
	var cfg := ConfigFile.new()
	for mood in light_values:
		for k in light_values[mood]:
			cfg.set_value("light_" + mood, k, light_values[mood][k])
	for pair in [["spot_you", _figure_light], ["spot_piece", _garment_light]]:
		var light: Node4D = pair[1]
		if light == null:
			continue
		for key in ["angle", "softness", "reach", "attenuation", "energy", "color"]:
			cfg.set_value(pair[0], key, light.get(key))
		cfg.set_value(pair[0], "height", light.position.y)
	return cfg.save(tuning_path)


## The lab's mood changed (B): the kit's swatches and every kit piece in the room to it, the spots at
## that mood's strength, and the words in the room light on its blue, a little brighter in the dark.
func apply_mood(mood: String, instant: bool = false) -> void:
	if mood != KitStyle.mood:
		# The lab does this itself (creation_lab_4d.gd apply_mood); here the room is the lab.
		KitStyle.apply(mood)
		for n in get_tree().get_nodes_in_group(&"lab_mood_listener"):
			if n != self and is_ancestor_of(n) and n.has_method("apply_mood"):
				n.call("apply_mood", mood, instant)
	var v: Dictionary = light_for(mood)
	KitStyle.gain["spot"] = float(v["spots"])
	KitStyle.gain["wash"] = float(v["washes"])
	for light in [_figure_light, _garment_light]:
		if light != null:
			light.call("apply_mood", mood, true)
	for parts in _pedestals:
		Pedestal.apply_mood(parts)
	if _tuner != null:
		_tuner.call("refresh")
	if _garment_label == null:
		return
	var dark: bool = mood == "dark"
	_garment_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_garment_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55 if dark else 0.4))
	_size_label.add_theme_color_override("font_color", KitStyle.UI_INK_SOFT)


# --- The world -------------------------------------------------------------------------------------

func _build_world() -> void:
	# Your pedestal and the piece's: the lab's own, in miniature, each under the lab's downlight.
	var holo: Dictionary = _lab_hologram()
	var left_parts: Dictionary = _lab_pedestal("FigurePedestal", figure_at, figure_pedestal_radius, holo, 0.0, "YOU")
	var right_parts: Dictionary = _lab_pedestal("GarmentPedestal", garment_at, garment_pedestal_radius, holo, garment_float * 0.9, "THE PIECE")
	var left: Node4D = get_node("FigurePedestal")
	var right: Node4D = get_node("GarmentPedestal")
	_figure_light = _downlight("FigureLight", figure_at, "spot_you")
	_garment_light = _downlight("GarmentLight", garment_at, "spot_piece")

	# YOU, on a turntable set into the pedestal's deck.
	_figure_turntable = Node4D.new()
	_figure_turntable.name = "Turntable"
	left.add_child(_figure_turntable)
	_figure_turntable.position = Vector4(0.0, float(left_parts["deck_h"]), 0.0, 0.0)
	_figure = _make_figure("You")
	_figure_turntable.add_child(_figure)
	_figure_wearer = _dress(_figure)

	# THE PIECE: scaled on a holder, turning on a spinner, centred by its own bounds.
	_garment_holder = Node4D.new()
	_garment_holder.name = "Garment"
	right.add_child(_garment_holder)
	_garment_holder.position = Vector4(0.0, float(right_parts["deck_h"]) + garment_float, 0.0, 0.0)
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


## The lab's pedestal at [param at], [param radius] across, at the lab's proportions (its trims sized by
## the radius over the lab's), with the lab's hologram on its deck ([param holo_height] when it must
## reach something floating, else the lab's own, in proportion) and its band printed on the side
## that faces the camera, [param words] on it. Returns its parts (kit_pedestal.gd build).
func _lab_pedestal(part_name: String, at: Vector4, radius: float, holo: Dictionary, holo_height: float, words: String) -> Dictionary:
	var k: float = radius / LAB_PEDESTAL.x
	var node := Node4D.new()
	node.name = part_name
	add_child(node)
	node.position = at
	var parts: Dictionary = Pedestal.build(node, radius, LAB_PEDESTAL.y * k, k)
	_pedestals.append(parts)
	# THE HOLOGRAM (kit_showcase_4d.gd _build_holo): a cylinder as wide as the deck, on the grid
	# shader's dithered hologram, fading upward.
	var r: float = float(parts["deck_r"])
	var h: float = holo_height if holo_height > 0.0 else float(holo["holo_height"]) * k
	var glow := MeshInstance4D.new()
	glow.name = "Hologram"
	glow.mesh = LabBuild._cubinder(r, h, 96)
	glow.material_override = LabGrid.material("kit_code_blue", Vector4(r * 2.0, h, r * 2.0, LabBuild.W_DEPTH), node.global_position)
	node.add_child(glow)
	glow.position = Vector4(0.0, float(parts["deck_h"]) + h * 0.5, 0.0, 0.0)
	var cs: ShaderMaterial = (glow.material_override as TetraMaterial4D).get_cross_section_material_3d()
	cs.set_shader_parameter("holo_on", 1.0)
	cs.set_shader_parameter("holo_base", float(holo["holo_base"]))
	# The fade is over the column's own height (lab_grid.gdshader): a tall one, drawn up to a floating
	# piece, fades faster so it stays a glow at the deck that thins to the piece, not a blue pillar.
	cs.set_shader_parameter("holo_falloff", float(holo["holo_falloff"]) * (1.8 if holo_height > 0.0 else 1.0))
	cs.set_shader_parameter("holo_color", HOLO_COLOUR)
	cs.set_shader_parameter("holo_fine", float(holo["holo_fine"]))
	# THE BAND, round the front as the camera sees it, at as many pixels as the lab's has.
	var facing: float = atan2(camera_at.x - at.x, camera_at.z - at.z)
	Pedestal.print_band(get_tree(), parts, float(LAB_BAND["width"]) * k, float(LAB_BAND["y0"]) * k, float(LAB_BAND["y1"]) * k,
		_paint_band.bind(words), 320.0 / k, facing)
	return parts


## The lab's hologram numbers: Ramon's from its tuning file when it is there, else the lab's own.
func _lab_hologram() -> Dictionary:
	var holo: Dictionary = LAB_HOLO.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(LAB_TUNING) == OK and cfg.has_section("hologram"):
		for key in cfg.get_section_keys("hologram"):
			holo[key] = float(cfg.get_value("hologram", key))
	return holo


## The pedestal's printed band, the lab's (kit_showcase_4d.gd _paint_band): hazard stripes at both
## ends, the live mark, its name in the heavy face, a rule, a line, the serial, corner brackets.
func _paint_band(c: Control, words: String) -> void:
	var h: float = c.size.y
	var w: float = c.size.x
	var ink := Color(0.88, 0.90, 0.94, 0.9)
	var dim := Color(0.88, 0.90, 0.94, 0.55)
	var heavy: Font = LabPrint.font("black")
	var bold: Font = LabPrint.font("bold")
	var light: Font = LabPrint.font("body")
	for side in [0.0, 1.0]:
		var x0: float = h * 0.15 if side == 0.0 else w - h * 1.15
		for i in 4:
			var sx: float = x0 + float(i) * h * 0.26
			c.draw_colored_polygon(PackedVector2Array([Vector2(sx, h * 0.85), Vector2(sx + h * 0.13, h * 0.85),
				Vector2(sx + h * 0.33, h * 0.15), Vector2(sx + h * 0.2, h * 0.15)]), dim)
	var x: float = h * 1.35
	Glyphs.icon(c, "live", Rect2(Vector2(x, h * 0.25), Vector2(h * 0.5, h * 0.5)), ink)
	x += h * 0.7
	c.draw_string(heavy, Vector2(x, h * 0.66), words, HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.42), ink)
	x += heavy.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.42)).x + h * 0.4
	c.draw_line(Vector2(x, h * 0.2), Vector2(x, h * 0.8), dim, maxf(1.0, h * 0.03))
	x += h * 0.4
	c.draw_string(bold, Vector2(x, h * 0.64), "TRYM'S FITTING ROOM  ·  WHAT YOU WEAR GOES WITH YOU", HORIZONTAL_ALIGNMENT_LEFT,
		w - x - h * 1.6, int(h * 0.3), ink)
	var serial: String = "QH-LAB FR-0%d" % (1 if words == "YOU" else 2)
	c.draw_string(light, Vector2(w - h * 1.3 - light.get_string_size(serial, HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.2)).x, h * 0.98),
		serial, HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.2), dim)
	var t: float = maxf(1.0, h * 0.04)
	var arm: float = h * 0.3
	for cx in [h * 1.2, w - h * 1.3]:
		var dir: float = 1.0 if cx < w * 0.5 else -1.0
		c.draw_line(Vector2(cx, h * 0.08), Vector2(cx + arm * dir, h * 0.08), ink, t)
		c.draw_line(Vector2(cx, h * 0.08), Vector2(cx, h * 0.08 + arm), ink, t)
		c.draw_line(Vector2(cx, h * 0.92), Vector2(cx + arm * dir, h * 0.92), ink, t)
		c.draw_line(Vector2(cx, h * 0.92), Vector2(cx, h * 0.92 - arm), ink, t)


## The lab's downlight (kit_light_4d.gd, its numbers from creation_lab.tscn), straight down onto [param at],
## with what was saved for it from the Tab panel ([param section] of TUNING) over those.
func _downlight(part_name: String, at: Vector4, section: String) -> Node4D:
	var light := Node4D.new()
	light.name = part_name
	light.set_script(KitLight)
	light.set("kind", "downlight")
	light.set("aim", Vector3(at.x, 0.0, at.z))
	for key in ["angle", "softness", "reach", "attenuation", "energy", "color"]:
		var value: Variant = DOWNLIGHT[key]
		# A copy: a constant's dictionary is read-only, and the light may keep and change its own.
		light.set(key, (value as Dictionary).duplicate() if value is Dictionary else value)
	var height: float = light_height
	var cfg := ConfigFile.new()
	if cfg.load(tuning_path) == OK and cfg.has_section(section):
		for key in ["angle", "softness", "reach", "attenuation", "energy", "color"]:
			if cfg.has_section_key(section, key):
				light.set(key, cfg.get_value(section, key))
		height = float(cfg.get_value(section, "height", height))
	add_child(light)
	light.position = Vector4(at.x, height, at.z, 0.0)
	return light


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


## A colour of your own for the chosen part, from the wheel. No flash while you drag: the part itself
## changing is the answer, and a pulse on every move would wash the colour you are judging.
func set_own_colour(c: Color) -> void:
	Outfit.set_custom(Outfit.ROWS[_row][1], c)


func _on_wheel(c: Color) -> void:
	set_own_colour(c)
	_wheel_rev = Outfit.changes()


func _unfocus(control: Control) -> void:
	control.focus_mode = Control.FOCUS_NONE
	for child in control.find_children("*", "Control", true, false):
		(child as Control).focus_mode = Control.FOCUS_NONE


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


## Tab: the light's panel in the outfit panel's place, and back (fitting_room_tuner.gd).
func toggle_tuner() -> void:
	_tuner.visible = not _tuner.visible
	_panel.visible = not _tuner.visible
	if _tuner.visible:
		_tuner.call("refresh")


## Done, on Enter or Esc: saved, and home to the farm if there is one behind this room. ESC SAVES TOO
## (Ramon, 8 Oct: "when i pressed esc in advanced, nothing was saved. that was a bummer"): every change
## here is on you as you make it, so leaving keeps it, however you leave. Z is the way back.
func done() -> void:
	var err: Error = Outfit.save()
	var trip: Node = get_tree().root.get_node_or_null(NodePath(String(Trip.NAME)))
	if trip != null and bool(trip.call("has_pen")):
		# The circle says "Saved" when you changed something, "Nothing changed" when you did not.
		trip.call("come_back", Outfit.snapshot() != _came_in)
		return
	_toast_say("Saved. It goes with you to the farm." if err == OK else "Could not save.")


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
		_dragging = mouse.pressed and mouse.position.x < _panel.position.x
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
	elif code == KEY_TAB and not key.echo:
		toggle_tuner()
	elif (code == KEY_ENTER or code == KEY_KP_ENTER or code == KEY_ESCAPE) and not key.echo:
		done()
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


# --- The panel ------------------------------------------------------------------------------------

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
	var glass: StyleBoxFlat = KitStyle.glass_box(10.0)
	glass.border_color = Color(1, 1, 1, 0.16)
	_panel.add_theme_stylebox_override("panel", glass)
	_pads.append([glass, 18.0, 16.0, 8.0])
	_ui.add_child(_panel)

	_column = VBoxContainer.new()
	_panel.add_child(_column)
	_column.add_child(_text("TRYM'S", "caption", KitStyle.UI_INK_DIM, "heading"))
	_column.add_child(_text("Fitting room", "title", KitStyle.UI_INK, "title"))
	_column.add_child(_text("Everything you change is on you at once. Done takes it to the farm.", "body", KitStyle.UI_INK_SOFT, "text", true))

	_column.add_child(_text("PART   1 to 6", "caption", KitStyle.UI_ACCENT, "heading"))
	_part_grid = GridContainer.new()
	_part_grid.columns = 2
	_column.add_child(_part_grid)
	for i in Outfit.ROWS.size():
		var b: Button = _button("%d   %s" % [i + 1, String(Outfit.ROWS[i][0]).capitalize()], "lead")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(choose_row.bind(i))
		_part_grid.add_child(b)
		_part_buttons.append(b)

	_column.add_child(_text("STYLE   ↑ ↓", "caption", KitStyle.UI_ACCENT, "heading"))
	_style_box = HFlowContainer.new()
	_column.add_child(_style_box)

	_column.add_child(_text("COLOUR   ← →   or your own on the wheel", "caption", KitStyle.UI_ACCENT, "heading"))
	var colours := HBoxContainer.new()
	colours.name = "Colours"
	_column.add_child(colours)
	_swatch_grid = GridContainer.new()
	_swatch_grid.columns = 5
	_swatch_grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	colours.add_child(_swatch_grid)
	# THE WHEEL (Ramon, 8 Oct: "make a colorpicker wheel next to the colors"): Godot's own picker as
	# its hue ring and square alone, drawn by a shader, so it is sharp at any size; sized in _layout.
	# A colour from it is the part's own (outfit_4d.gd CUSTOM), saved with the rest.
	_wheel = ColorPicker.new()
	_wheel.name = "Wheel"
	_wheel.picker_shape = ColorPicker.SHAPE_HSV_WHEEL
	_wheel.edit_alpha = false
	_wheel.set("edit_intensity", false)
	_wheel.sampler_visible = false
	_wheel.color_modes_visible = false
	_wheel.sliders_visible = false
	_wheel.hex_visible = false
	_wheel.presets_visible = false
	_wheel.can_add_swatches = false
	_wheel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_wheel.color_changed.connect(_on_wheel)
	colours.add_child(_wheel)
	# Never the keyboard's: a focused wheel would take the arrow keys this room steps colours with.
	_unfocus(_wheel)
	_unfocus.call_deferred(_wheel)
	_colour_name = _text("", "lead", KitStyle.UI_INK, "heading")
	_column.add_child(_colour_name)
	_colour_note = _text("", "caption", KitStyle.UI_INK_DIM, "text", true)
	_column.add_child(_colour_note)

	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_column.add_child(gap)
	_through_button = _button("Turn the piece through W   T", "body")
	_through_button.toggle_mode = true
	_through_button.toggled.connect(func(_on: bool) -> void: toggle_through_w())
	_column.add_child(_through_button)
	var row := HBoxContainer.new()
	row.name = "Actions"
	_column.add_child(row)
	var surprise_b: Button = _button("Surprise me   X", "body")
	surprise_b.pressed.connect(surprise)
	var undo_b: Button = _button("Undo   Z", "body")
	undo_b.pressed.connect(undo)
	for b in [surprise_b, undo_b]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	var done_b: Button = _button("Done   Enter", "subhead", true)
	done_b.pressed.connect(done)
	_column.add_child(done_b)
	_column.add_child(_text("Q E  turn you      Esc  done too, saved      Tab  light", "micro", KitStyle.UI_INK_DIM, "text"))

	# Under the piece and under you, drawn flat where those spots project (the world tags' way).
	_garment_label = _text("", "subhead", Color.WHITE, "heading")
	_ui.add_child(_garment_label)
	_size_label = _text("", "caption", KitStyle.UI_INK_SOFT, "text")
	_ui.add_child(_size_label)
	_toast = _text("", "lead", KitStyle.UI_INK, "heading")
	var toast_box: StyleBoxFlat = KitStyle.glass_box(6.0, 1.0, 0.9)
	_pads.append([toast_box, 14.0, 7.0, 6.0])
	_toast.add_theme_stylebox_override("normal", toast_box)
	_toast.visible = false
	_ui.add_child(_toast)

	# The light's panel, hidden until Tab (fitting_room_tuner.gd).
	_tuner = Tuner.new()
	_tuner.name = "LightPanel"
	_tuner.set("room", self)
	_tuner.visible = false
	_ui.add_child(_tuner)


## A label on the kit's type ladder ([param role]) in one of its type families ("title", "heading" or
## "text", kit_style.gd ui_font); its size is set in _layout.
## [param keep] adds it to the sizes _layout sets again; what _refresh_ui rebuilds is made at today's size
## instead, so the list does not grow with every change.
func _text(words: String, role: String, colour: Color, family: String, wrap: bool = false, keep: bool = true) -> Label:
	var label := Label.new()
	label.text = words
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", KitStyle.ui_font(family))
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.0))
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if keep:
		_type.append([label, role])
	label.add_theme_font_size_override("font_size", KitStyle.type_px(role, _u))
	return label


## A button in the kit's black glass: a faint fill, a thin edge, white type; the chosen one in the lab's
## code blue. Never takes the keyboard focus, so Enter and Space stay this room's keys.
func _button(words: String, role: String, primary: bool = false, keep: bool = true) -> Button:
	var b := Button.new()
	b.text = words
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", KitStyle.ui_font("heading"))
	for colour_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(colour_name, KitStyle.UI_INK)
	var blue: Color = KitStyle.CODE_BLUE["bright"]
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		box.anti_aliasing = true
		box.border_color = Color(1, 1, 1, 0.22)
		box.set_border_width_all(1)
		if primary:
			box.bg_color = blue.lightened(0.12) if state == "hover" else blue
		else:
			box.bg_color = Color(1, 1, 1, 0.16 if state.begins_with("hover") else (0.22 if state == "pressed" else 0.08))
		b.add_theme_stylebox_override(state, box)
		if keep:
			_pads.append([box, 10.0, 6.0 if not primary else 9.0, 5.0])
	if keep:
		_type.append([b, role])
	b.add_theme_font_size_override("font_size", KitStyle.type_px(role, _u))
	return b


## A swatch: a square of the colour itself, ringed in white when chosen, a hair of edge when not.
func _swatch(colour: Color, chosen: bool, muted: bool, index: int) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(38.0, 38.0) * _u
	b.tooltip_text = Outfit.name_of(Outfit.ROWS[_row][1], index)
	var shown: Color = colour.lerp(Color(0.45, 0.47, 0.5), 0.7) if muted else colour
	for state in ["normal", "hover", "pressed"]:
		var box := StyleBoxFlat.new()
		box.anti_aliasing = true
		box.bg_color = shown.lightened(0.08) if state == "hover" else shown
		box.set_corner_radius_all(int(5.0 * _u))
		box.border_color = Color.WHITE if chosen else Color(1, 1, 1, 0.25)
		box.set_border_width_all(maxi(2, int(3.0 * _u)) if chosen else 1)
		b.add_theme_stylebox_override(state, box)
	b.pressed.connect(set_colour.bind(index))
	return b


## Every size from the screen's height (u = height / 720, the kit's measure): type on the ladder,
## padding, gaps and swatches, and the panel down the right at its share of the width. Run when the
## window changes size, never every frame, so nothing moves while you look at it.
func _layout() -> void:
	var screen: Vector2 = _ui.get_viewport_rect().size
	_u = maxf(screen.y / 720.0, 0.5)
	for entry in _type:
		if is_instance_valid(entry[0]):
			(entry[0] as Control).add_theme_font_size_override("font_size", KitStyle.type_px(String(entry[1]), _u))
	for entry in _pads:
		var box := entry[0] as StyleBoxFlat
		box.content_margin_left = float(entry[1]) * _u
		box.content_margin_right = float(entry[1]) * _u
		box.content_margin_top = float(entry[2]) * _u
		box.content_margin_bottom = float(entry[2]) * _u
		box.set_corner_radius_all(int(float(entry[3]) * _u))
	_column.add_theme_constant_override("separation", int(8.0 * _u))
	for grid in [_part_grid, _swatch_grid]:
		grid.add_theme_constant_override("h_separation", int(6.0 * _u))
		grid.add_theme_constant_override("v_separation", int(6.0 * _u))
	_style_box.add_theme_constant_override("h_separation", int(5.0 * _u))
	_style_box.add_theme_constant_override("v_separation", int(5.0 * _u))
	(_column.get_node("Actions") as HBoxContainer).add_theme_constant_override("separation", int(6.0 * _u))
	# Fixed room per section (Ramon, 4 Oct: no cards that resize): two rows of styles, three of
	# swatches, two lines of note, whichever part is chosen.
	_style_box.custom_minimum_size.y = 2.0 * (KitStyle.type_px("body", _u) + 14.0 * _u) + 5.0 * _u
	_swatch_grid.custom_minimum_size.y = 3.0 * 38.0 * _u + 2.0 * 6.0 * _u
	_colour_note.custom_minimum_size.y = 2.2 * KitStyle.type_px("caption", _u)
	var margin: float = 16.0 * _u
	_panel.size = Vector2(maxf(screen.x * panel_width, 240.0 * _u), screen.y - margin * 2.0)
	_panel.position = Vector2(screen.x - margin - _panel.size.x, margin)
	# The wheel as tall as the swatches beside it, narrower if the panel has no more room.
	var colours := _column.get_node("Colours") as HBoxContainer
	colours.add_theme_constant_override("separation", int(10.0 * _u))
	var grid_w: float = 5.0 * 38.0 * _u + 4.0 * 6.0 * _u
	var room_for: float = _panel.size.x - 2.0 * 18.0 * _u - grid_w - 10.0 * _u
	var wheel: int = int(clampf(room_for, 60.0 * _u, 3.0 * 38.0 * _u + 2.0 * 6.0 * _u))
	_wheel.add_theme_constant_override("sv_width", wheel)
	_wheel.add_theme_constant_override("sv_height", wheel)
	_wheel.add_theme_constant_override("margin", 0)
	_tuner.call("layout", _u, _panel.position, _panel.size)
	_refresh_ui()


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
		_style_box.remove_child(child)
		child.queue_free()
	if style_key == "":
		_style_box.add_child(_text("%s comes in one style." % String(row[0]).capitalize(), "body", KitStyle.UI_INK_DIM, "text", false, false))
	else:
		var styles: Array = Outfit.options(style_key)
		for i in styles.size():
			var b: Button = _button(String(styles[i]), "body", false, false)
			_fit_pads(b)
			if i == Outfit.get_value(style_key):
				var box := (b.get_theme_stylebox("normal") as StyleBoxFlat)
				box.bg_color = blue
				box.border_color = Color(1, 1, 1, 0.55)
			b.pressed.connect(set_style.bind(i))
			_style_box.add_child(b)
	for child in _swatch_grid.get_children():
		_swatch_grid.remove_child(child)
		child.queue_free()
	var colour_key: String = row[1]
	var muted: bool = _row == Wearer.ROW_HAT and not Outfit.hat_takes_colour()
	var list: Array = Outfit.options(colour_key)
	for i in list.size():
		_swatch_grid.add_child(_swatch(list[i], i == Outfit.get_value(colour_key), muted, i))
	# The wheel shows the part's colour, unless the wheel is what just changed it.
	if _wheel_rev != Outfit.changes() or _wheel_row != _row:
		_wheel.color = Outfit.colour(colour_key)
		_wheel_rev = Outfit.changes()
		_wheel_row = _row
	_wheel.modulate.a = 0.5 if muted else 1.0
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


## A button made after the last layout takes its padding at today's size straight away.
func _fit_pads(b: Button) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var box := b.get_theme_stylebox(state) as StyleBoxFlat
		if box != null:
			box.content_margin_left = 10.0 * _u
			box.content_margin_right = 10.0 * _u
			box.content_margin_top = 6.0 * _u
			box.content_margin_bottom = 6.0 * _u
			box.set_corner_radius_all(int(5.0 * _u))


func _toast_say(words: String) -> void:
	_said = words
	_said_left = 2.5


## The piece's name under its pedestal, your four sizes under yours, and any word to say, each where
## the camera sees that spot, at the size the layout gave them.
func _place_world_labels(delta: float) -> void:
	var screen: Vector2 = _ui.get_viewport_rect().size
	var to_canvas: Vector2 = screen / Vector2(_ui.get_viewport().get_size())
	_garment_label.size = _garment_label.get_combined_minimum_size()
	# Under the pedestal's front edge, which is the lowest of it on screen.
	var under: Vector4 = global_position + garment_at + Vector4(0.0, 0.0, garment_pedestal_radius, 0.0)
	var p: Vector2 = _camera.world_to_viewport(under) * to_canvas
	_garment_label.position = Vector2(p.x - _garment_label.size.x * 0.5, p.y + 10.0 * _u)
	var size4: Vector4 = _measure(_figure)
	_size_label.text = "%.2f m tall   %.2f wide   %.2f deep   %.2f thick in W" % [size4.y, size4.x, size4.z, size4.w]
	_size_label.size = _size_label.get_combined_minimum_size()
	var foot: Vector4 = global_position + figure_at + Vector4(0.0, 0.0, figure_pedestal_radius, 0.0)
	var q: Vector2 = _camera.world_to_viewport(foot) * to_canvas
	_size_label.position = Vector2(q.x - _size_label.size.x * 0.5, q.y + 10.0 * _u)
	_said_left = maxf(_said_left - delta, 0.0)
	_toast.visible = _said_left > 0.0
	if _toast.visible:
		_toast.text = _said
		_toast.size = _toast.get_combined_minimum_size()
		_toast.position = Vector2((_panel.position.x - _toast.size.x) * 0.5, 24.0 * _u)
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
