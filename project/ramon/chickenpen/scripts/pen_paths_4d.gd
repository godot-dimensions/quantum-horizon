extends Node

## The pen's paths, the player's side of them (6 Oct 2026, PenLayout/PLAN_A.md phase 5): switches on
## the network (CreationLab/PathCreator/graph/path_network_4d.gd), on the controls card (H) and in the
## Paths row of the left-hand panel (grass/pen_grass_panel_4d.gd).
##   9        the type, round and round as Tab goes round the cameras (Ramon, 6 Oct): as drawn (each
##            stretch its own W mode), then every stretch static, here, follow, reveal
##   Shift+9  found as you go (a stretch shows once you have been near it), or every path shown
## The look, sand or the icons, is the world's: sand in the art, the icons in the dev look (I). It had
## its own key, F5, and F5 and F6 are the editor's Run and Run Current, which the game window passed
## on (F8, its Stop, ended the game). Remembered between runs in user://pen_settings.cfg, next to the
## interface size. A full restart (Ctrl+R) forgets what reveal has found.
##
## ONE KEY, TWO LOOKS, NEVER MIXED (Ramon, 6 Oct: "the toggle will be at some point between just
## sand, or icons on white"; and later, "when toggling f5 i see a watermark of the icons moving, but
## no clear switch from sand to dev look white with the blue icons on top"). Icons and sand were two
## keys, and icons over sand were drawn in the sand's colours: a watermark. Now there are only the
## two looks, and F5 swaps them.
##
## THE SAND'S EDGE FADES INTO THE GROUND as the pen paints it (its glow, from the Grass node), so
## the ground's colours are handed to the network here, and again whenever the ground changes.

const Look := preload("res://ramon/chickenpen/look/pen_look_4d.gd")
const PANEL := preload("res://ramon/chickenpen/scripts/pen_paths_panel_4d.gd")
@export var network_path: NodePath = NodePath("../../World/Paths")
@export var grass_path: NodePath = NodePath("../../World/Grass")
## Round the types (TYPES); with Shift, found as you go or all shown.
@export var key_type: Key = KEY_9
@export var key_found: int = KEY_9 | KEY_MASK_SHIFT
@export_range(0.5, 6.0, 0.1) var message_seconds: float = 2.2
@export_range(10, 40, 1) var text_size: int = 18
## The dev look's path, and the colour its icons' soft edges blend toward (the path under them).
@export var dev_white: Color = Color(0.93, 0.935, 0.94)

## The types round 9, and what each is called: "" each stretch as drawn, the rest every stretch so.
const TYPES := ["", "static", "here", "follow", "reveal"]
const TYPE_NAMES := {"": "as drawn", "static": "static", "here": "here", "follow": "follow", "reveal": "reveal"}
const TYPE_SAYS := {
	"": "each stretch as drawn",
	"static": "every stretch static, seen from any W",
	"here": "every stretch at its start's W",
	"follow": "every stretch slanting from its start's W to its end's",
	"reveal": "every stretch only at its end's W",
}

signal changed

const SETTINGS := "user://pen_settings.cfg"
## A new section for the two-look switch: the earlier ones held icons and sand separately.
const SECTION := "path_looks_2"

var _network: Node
var _grass: Node
var _label: Label
var _left: float = 0.0
var _dev: bool = false


func _ready() -> void:
	_network = get_node_or_null(network_path)
	if _network == null:
		push_warning("PenPaths: no path network at %s, so 9 does nothing." % network_path)
		return
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	# The look is the world's now: the art's sand, until the dev look says otherwise.
	_dev = false
	_network.set("reveal", bool(cfg.get_value(SECTION, "reveal", false)))
	var kept: String = String(cfg.get_value(SECTION, "type", ""))
	_network.set("w_mode_override", kept if kept in TYPES and kept != "" else "drawn")
	_apply_look()
	_grass = get_node_or_null(grass_path)
	if _grass != null:
		for sig in ["ground_changed", "glow_changed"]:
			if _grass.has_signal(sig):
				_grass.connect(sig, func(_on: bool) -> void: _ground_to_paths())
	_ground_to_paths.call_deferred()
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", text_size)
	_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.92))
	_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
	_label.add_theme_constant_override("outline_size", 5)
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_label.position.y = 64.0
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.visible = false
	layer.add_child(_label)
	_add_panel.call_deferred()


## The paths' own window (pen_paths_panel_4d.gd; Ramon, 7 Oct: "the path settings should get there own
## window"), in the pen's UI beside the grass panel.
func _add_panel() -> void:
	var room: Node = owner if owner != null else get_tree().current_scene
	var ui: Node = room.get_node_or_null("UI") if room != null else null
	if ui == null:
		return
	var panel := PANEL.new()
	panel.paths = self
	panel.says = TYPE_SAYS
	panel.beside = ui.get_node_or_null("GrassPanel") as Control
	ui.add_child(panel)


func _process(delta: float) -> void:
	if _left > 0.0:
		_left -= delta
		if _left <= 0.0 and _label != null:
			_label.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _network == null or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var ev := event as InputEventKey
	if ev.get_keycode_with_modifiers() == key_found:
		set_found(not is_found())
	elif ev.keycode == key_type and not ev.shift_pressed and not ev.ctrl_pressed and not ev.alt_pressed:
		set_type(TYPES[(TYPES.find(type()) + 1) % TYPES.size()])
	else:
		return
	get_viewport().set_input_as_handled()


## The type now: "" as drawn, or what every stretch is (TYPES).
func type() -> String:
	var t: String = String(_network.get("w_mode_override")) if _network != null else ""
	return t if t in TYPES else ""


func set_type(t: String) -> void:
	if _network == null or not (t in TYPES):
		return
	_network.set("w_mode_override", t if t != "" else "drawn")
	_say("Paths: %s" % TYPE_SAYS[t])
	_save()
	changed.emit()


## Found as you go (true), or every path shown.
func is_found() -> bool:
	return _network != null and bool(_network.get("reveal"))


func set_found(on: bool) -> void:
	if _network == null:
		return
	_network.set("reveal", on)
	_say("Paths: found as you go" if on else "Paths: all shown")
	_save()
	changed.emit()


## Whether the dev look is on (for runners and the controls card).
func is_dev() -> bool:
	return _dev


## Sets the look: true the dev look (white path, blue icons), false the field's sand.
func set_dev(on: bool) -> void:
	_dev = on
	if _network != null:
		_apply_look()


## The two looks. Sand: the strips in the yard's sand, no icons. Dev: the strips white and the
## sheet's blue icons on them, their soft edges blending into the white.
func _apply_look() -> void:
	_network.set("show_sand", true)
	_network.set("show_marks", _dev)
	_network.set("look", "dev" if _dev else "walk")
	if _dev:
		_network.set("under_color", dev_white)


## The ground's colours, as the Grass node paints them (pen_grass_4d.gd _glow_to does the same for
## the grass's far edge), for the sand's edge to fade into.
func _ground_to_paths() -> void:
	if _network == null or not _network.has_method("set_ground"):
		return
	# The pen's dev look (look/pen_look_4d.gd): no field green under the strips, their soft edges fade
	# into their own white.
	var look: Variant = Look.current
	if look != null and is_instance_valid(look) and bool(look.get("_applied")):
		_network.call("set_ground", {})
		return
	if _grass == null or not is_instance_valid(_grass) or _grass.get("ground_colour") == null:
		_network.call("set_ground", {})
		return
	var paint: bool = bool(_grass.get("ground_paint"))
	var glow_on: bool = paint and bool(_grass.get("ground_glow"))
	# In linear light: the shader's ground colours are plain vec3s (path_sand.gdshader says why).
	var glow: Color = (_grass.call("field_glow") as Color).srgb_to_linear()
	var edge: Color = (_grass.call("field_edge") as Color).srgb_to_linear()
	var centre: Vector2 = _grass.get("glow_centre")
	var reach: Vector3 = _grass.call("glow_reach") if _grass.has_method("glow_reach") else Vector3(_grass.get("glow_in"), _grass.get("glow_out"), _grass.get("glow_w"))
	var ground: Dictionary = {
		"glow_area": Vector4(centre.x, centre.y, reach.x, reach.y),
		"glow_colour": Vector3(glow.r, glow.g, glow.b),
		"edge_colour": Vector3(edge.r, edge.g, edge.b),
		"glow_on": 1.0 if glow_on else 0.0,
		"glow_w": reach.z,
	}
	# THE GROUND'S OWN PAINT, when it is painted (7 Oct: the soft edge fades to the sand where the path
	# crosses sand, not to a green rim; path_sand.gdshader).
	var info: Dictionary = _grass.call("ground_paint_info") if _grass.has_method("ground_paint_info") else {}
	if not info.is_empty():
		var breaks: PackedFloat32Array = info["breaks"]
		var padded := PackedFloat32Array(breaks)
		padded.resize(48)
		ground["ground_mode"] = 2.0
		ground["ground_tex"] = info["tex"]
		ground["ground_breaks"] = padded
		ground["ground_breaks_n"] = mini(breaks.size(), 48)
		ground["ground_size"] = info["size"]
	_network.call("set_ground", ground)


func _say(text: String) -> void:
	if _label == null:
		return
	_label.text = text
	_label.visible = true
	_label.reset_size()
	_label.position.x = (_label.get_viewport_rect().size.x - _label.size.x) * 0.5
	_left = message_seconds


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value(SECTION, "reveal", bool(_network.get("reveal")))
	cfg.set_value(SECTION, "type", type())
	cfg.save(SETTINGS)


## Part of the full restart (chickenpen_game_4d.gd calls every sibling's reset).
func reset() -> void:
	if _network != null and _network.has_method("reset_reveal"):
		_network.call("reset_reveal")
