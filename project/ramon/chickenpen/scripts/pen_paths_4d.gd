extends Node

## The pen's paths, the player's side of them (6 Oct 2026, PenLayout/PLAN_A.md phase 5): two switches
## on the network (CreationLab/PathCreator/graph/path_network_4d.gd), each on its own key and listed
## on the controls card (H).
##   F5  the look: SAND (the field's look: the paths are sand, no icons) or DEV (the dev look: a
##       white path with the sheet's blue icons on it)
##   F6  reveal or static: paths found as you go (a stretch shows once you have been near it), or
##       every path shown all the time
## Remembered between runs in user://pen_settings.cfg, next to the interface size. A full restart
## (Ctrl+R) forgets what reveal has found.
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
@export var network_path: NodePath = NodePath("../../World/Paths")
@export var grass_path: NodePath = NodePath("../../World/Grass")
@export var key_look: Key = KEY_F5
@export var key_reveal: Key = KEY_F6
@export_range(0.5, 6.0, 0.1) var message_seconds: float = 2.2
@export_range(10, 40, 1) var text_size: int = 18
## The dev look's path, and the colour its icons' soft edges blend toward (the path under them).
@export var dev_white: Color = Color(0.93, 0.935, 0.94)

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
		push_warning("PenPaths: no path network at %s, so F5 and F6 do nothing." % network_path)
		return
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	_dev = String(cfg.get_value(SECTION, "look", "sand")) == "dev"
	_network.set("reveal", bool(cfg.get_value(SECTION, "reveal", false)))
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


func _process(delta: float) -> void:
	if _left > 0.0:
		_left -= delta
		if _left <= 0.0 and _label != null:
			_label.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _network == null or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: Key = (event as InputEventKey).keycode
	if key == key_look:
		_dev = not _dev
		_apply_look()
		_say("Paths: dev look, icons on white" if _dev else "Paths: sand")
	elif key == key_reveal:
		_network.set("reveal", not bool(_network.get("reveal")))
		_say("Paths: found as you go" if bool(_network.get("reveal")) else "Paths: all shown")
	else:
		return
	get_viewport().set_input_as_handled()
	_save()


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
	_network.call("set_ground", {
		"glow_area": Vector4(centre.x, centre.y, reach.x, reach.y),
		"glow_colour": Vector3(glow.r, glow.g, glow.b),
		"edge_colour": Vector3(edge.r, edge.g, edge.b),
		"glow_on": 1.0 if glow_on else 0.0,
		"glow_w": reach.z,
	})


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
	cfg.set_value(SECTION, "look", "dev" if _dev else "sand")
	cfg.set_value(SECTION, "reveal", bool(_network.get("reveal")))
	cfg.save(SETTINGS)


## Part of the full restart (chickenpen_game_4d.gd calls every sibling's reset).
func reset() -> void:
	if _network != null and _network.has_method("reset_reveal"):
		_network.call("reset_reveal")
