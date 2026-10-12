extends PanelContainer

## The Voxel Lab's lights on Tab (Ramon, 9 Oct: "when pressing Tab, I want access to controls for the
## individual lights in the scene ... each light ... intensity/strength and softness ... a clear,
## practical layout so I can easily identify and manipulate each light").
##
## Every light by what it lights, room by room (the hall, then the gallery), each with its own
## strength and softness, applied as you drag. SAVE writes them with the rest of the light rig
## (vl_lights.gd, voxel_lab_lights.cfg), which the room reads back when it starts. The F1 dev panel's
## LIGHTS page keeps the top view, the rooms' shared values, the cones and the heights.
##
## Black glass, the dev panel's look (vl_dev_panel.gd). Tab opens and closes it; the cursor comes free
## while it is open.
##
## NO class_name (engine_gotchas.md).

const Style := preload("res://ramon/VoxelLab/carried/kit/kit_style.gd")
const LabPrint := preload("res://ramon/VoxelLab/carried/LabKit/lab_print.gd")

const FONT := 14
const HEAD := Color(0.42, 0.72, 1.0)

## The room (voxel_lab_4d.gd): its `lights` rig and its HUD for the toast.
var room: Node
var _rig: Node
var _box: VBoxContainer
## light name -> {"strength": [slider, label], "softness": [slider, label]}
var _rows: Dictionary = {}


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", Style.glass_box(10.0, 1.0, 0.92))
	position = Vector2(16, 16)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(440, 620)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_box)
	_label("VOXEL LAB  ·  LIGHTS", LabPrint.font("black"), FONT + 2, Color.WHITE)
	_label("Each light on its own. Tab closes; SAVE keeps them. Cones, heights and the top view: F1.", null, FONT - 2, Style.UI_INK_DIM, true)
	_rig = room.get("lights") if room != null else null
	if _rig == null:
		_label("No light rig in this room", null, FONT, HEAD)
		return
	for r in [["hall", "THE HALL"], ["gallery", "THE GALLERY"]]:
		_label(String(r[1]), LabPrint.font("bold"), FONT, HEAD)
		for l in _rig.get("lights"):
			if String(l.get_meta("room", "")) == String(r[0]):
				_light_rows(l)
	var save := Button.new()
	save.text = "SAVE"
	save.add_theme_font_size_override("font_size", FONT)
	save.pressed.connect(save_now)
	_box.add_child(save)
	_rig.connect("changed", _refresh)
	_refresh()


func _label(text: String, font: Font, px: int, col: Color, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	if font != null:
		l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
	_box.add_child(l)
	return l


## A light's name (what it lights) and its two sliders.
func _light_rows(l: Node) -> void:
	var n: String = String(l.name)
	var item: String = String(l.get_meta("item", n))
	_label(item.substr(0, 1).to_upper() + item.substr(1), LabPrint.font("bold"), FONT - 1, Color.WHITE)
	_rows[n] = {}
	for k in [["strength", "Strength", 0.0, 8.0, 0.01], ["softness", "Softness", 0.1, 8.0, 0.05]]:
		var line := HBoxContainer.new()
		var lab := Label.new()
		lab.text = "    " + String(k[1])
		lab.custom_minimum_size = Vector2(150, 0)
		lab.add_theme_font_size_override("font_size", FONT - 1)
		lab.add_theme_color_override("font_color", Style.UI_INK_DIM)
		line.add_child(lab)
		var s := HSlider.new()
		s.min_value = float(k[2])
		s.max_value = float(k[3])
		s.step = float(k[4])
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.custom_minimum_size = Vector2(170, 0)
		line.add_child(s)
		var v := Label.new()
		v.custom_minimum_size = Vector2(48, 0)
		v.add_theme_font_size_override("font_size", FONT - 1)
		line.add_child(v)
		_box.add_child(line)
		(_rows[n] as Dictionary)[String(k[0])] = [s, v]
		var key: String = String(k[0])
		s.value_changed.connect(func(x: float) -> void: _set_light(n, key, x))


## Strength is set as the light's own factor over its room's (or A, B or C's) strength, so the
## shared sliders on F1 still move it; softness is its own.
func _set_light(n: String, key: String, x: float) -> void:
	var l: Node = _rig.call("light", n)
	if l == null:
		return
	if key == "strength":
		var e: Dictionary = _rig.call("effective", l)
		var mine: Dictionary = (_rig.get("own") as Dictionary).get(n, {})
		var k_now: float = float(mine.get("strength_k", l.get_meta("strength_k", 1.0)))
		var base: float = float(e["strength"]) / maxf(k_now, 0.0001)
		_rig.call("set_own", n, "strength_k", x / maxf(base, 0.0001))
	else:
		_rig.call("set_own", n, "softness", x)


## The sliders as the lights are now (after F1 changes them, or a load).
func _refresh() -> void:
	for n in _rows:
		var l: Node = _rig.call("light", n)
		if l == null:
			continue
		var e: Dictionary = _rig.call("effective", l)
		for key in ["strength", "softness"]:
			var pair: Array = (_rows[n] as Dictionary)[key]
			(pair[0] as HSlider).set_value_no_signal(float(e[key]))
			(pair[1] as Label).text = "%.2f" % float(e[key])


func save_now() -> void:
	var err: int = int(_rig.call("save"))
	if room != null and room.get("hud") != null:
		room.get("hud").call("toast", "Lights saved to voxel_lab_lights.cfg" if err == OK else "Could not save the lights (error %d)" % err)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or k.keycode != KEY_TAB:
		return
	visible = not visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if visible else Input.MOUSE_MODE_CAPTURED
	get_viewport().set_input_as_handled()
