extends PanelContainer

## Kit: a temporary tuning panel for the light, live while playing (Ramon, 4 Oct: "sliders i can
## use to attenuate light strength and darkness of bg environment fill strength ... then i can give
## you the numbered settings and you can default set it").
##
##   Spots     multiplies every downlight and spot (KitLight)
##   Washes    multiplies every wash (KitLight)
##   Sky fill  multiplies the room's ambient light, the blue in every shadow
##   Sun       multiplies the room's key light
##   Exposure  the room's tone-map exposure
##
## Per mood: B switches mood and the sliders show that mood's values. The numbers are printed on
## the panel to read back. Esc frees the mouse to drag them; F1 hides the panel.
##
## NO class_name (engine_gotchas.md).

const Style := preload("res://ramon/LabChambers/kit/kit_style.gd")
const RoomScript := preload("res://ramon/LabKit/lab_room_4d.gd")
const LabPrint := preload("res://ramon/LabKit/lab_print.gd")

## The LabKit room whose light this tunes.
var room: Node
## Values per mood: spots, washes, fill, sun, exposure.
var values: Dictionary = {}
var _sliders: Dictionary = {}
var _labels: Dictionary = {}
var _readout: Label
var _mood: String = ""
var _quiet: bool = false

const KEYS := ["spots", "washes", "fill", "sun", "exposure"]
const RANGES := {"spots": [0.0, 4.0], "washes": [0.0, 4.0], "fill": [0.0, 3.0], "sun": [0.0, 3.0], "exposure": [0.4, 2.5]}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	position = Vector2(14, 14)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.08, 0.82)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	var title := Label.new()
	title.text = "LIGHT  ·  Esc frees the mouse  ·  F1 hides"
	title.add_theme_font_override("font", LabPrint.font("bold"))
	title.add_theme_font_size_override("font_size", 12)
	box.add_child(title)
	for k in KEYS:
		var row := HBoxContainer.new()
		var name_label := Label.new()
		name_label.custom_minimum_size = Vector2(150, 0)
		name_label.add_theme_font_size_override("font_size", 12)
		row.add_child(name_label)
		var s := HSlider.new()
		s.custom_minimum_size = Vector2(200, 18)
		s.min_value = float(RANGES[k][0])
		s.max_value = float(RANGES[k][1])
		s.step = 0.01
		s.focus_mode = Control.FOCUS_NONE
		s.value_changed.connect(func(v: float) -> void: _on_change(k, v))
		row.add_child(s)
		box.add_child(row)
		_sliders[k] = s
		_labels[k] = name_label
	_readout = Label.new()
	_readout.add_theme_font_size_override("font_size", 11)
	box.add_child(_readout)


func _defaults(m: String) -> Dictionary:
	var exp_v: float = float((Style.ROOM_LIGHT.get(m, {}) as Dictionary).get("exposure", (RoomScript.MOODS[m] as Dictionary)["exposure"]))
	return {"spots": 1.0, "washes": 1.0, "fill": 1.0, "sun": 1.0, "exposure": exp_v}


func _process(_delta: float) -> void:
	if room == null:
		return
	var m: String = String(room.get("mood"))
	if m != _mood:
		_mood = m
		if not values.has(m):
			values[m] = _defaults(m)
		_quiet = true
		for k in KEYS:
			(_sliders[k] as HSlider).value = float(values[m][k])
		_quiet = false
		_show()


func _on_change(k: String, v: float) -> void:
	if _quiet or _mood.is_empty():
		return
	values[_mood][k] = v
	_push()
	_show()


func _push() -> void:
	var v: Dictionary = values[_mood]
	Style.gain["spot"] = float(v["spots"])
	Style.gain["wash"] = float(v["washes"])
	get_tree().call_group("kit_light", "apply_mood", _mood, true)
	# The room's own light: LabKit's numbers for this mood, the kit's changes over them, scaled.
	var base: Dictionary = (RoomScript.MOODS[_mood] as Dictionary).duplicate()
	base.merge(Style.ROOM_LIGHT.get(_mood, {}), true)
	var over: Dictionary = (Style.ROOM_LIGHT.get(_mood, {}) as Dictionary).duplicate()
	over["ambient"] = (base["ambient"] as Color) * float(v["fill"])
	over["key_energy"] = float(base["key_energy"]) * float(v["sun"])
	over["exposure"] = float(v["exposure"])
	var all: Dictionary = (room.get("mood_overrides") as Dictionary).duplicate()
	all[_mood] = over
	room.set("mood_overrides", all)
	room.call("set_mood", _mood, true, false)


func _show() -> void:
	var v: Dictionary = values.get(_mood, {})
	if v.is_empty():
		return
	var names := {"spots": "Spots", "washes": "Washes", "fill": "Sky fill (shadows)", "sun": "Sun", "exposure": "Exposure"}
	for k in KEYS:
		(_labels[k] as Label).text = "%s  %.2f" % [names[k], float(v[k])]
	_readout.text = "%s:  spots %.2f  washes %.2f  fill %.2f  sun %.2f  exposure %.2f" % [_mood.to_upper(), v["spots"], v["washes"], v["fill"], v["sun"], v["exposure"]]


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_F1:
		visible = not visible
