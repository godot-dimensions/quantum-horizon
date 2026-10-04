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
## THE CENTRE SPOT (Ramon, 4 Oct: "I want only one spotlight in the room, the middle one. For this
## spotlight I also want more controls"): its strength (per mood), cone, edge softness, reach,
## falloff, height and warmth, set straight on the KitLight `spot` (kit_light_4d.gd).
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
## The centre spotlight (a KitLight) the spot sliders drive.
var spot: Node
## The sun handle (kit_sun_4d.gd), the showcase (its pedestal's radius) and the goat room (its
## ceiling), for the ROOM sliders.
var sun: Node
var showcase: Node
var goat_room: Node
var _room_sliders: Dictionary = {}
var _room_labels: Dictionary = {}
var _room_pending: Dictionary = {}
var _room_wait: float = 0.0
## The goat room's root (goat_room_4d.gd), whose five shape numbers the ROOM SHAPE sliders set.
var shape_root: Node
var _shape_sliders: Dictionary = {}
var _shape_labels: Dictionary = {}
var _shape_pending: Dictionary = {}
var _shape_wait: float = 0.0
const SHAPE_KEYS := ["room_half_width", "room_back", "room_front", "back_wall_half", "corner_z"]
const SHAPE_RANGES := {"room_half_width": [5.0, 20.0], "room_back": [4.0, 20.0], "room_front": [4.0, 20.0], "back_wall_half": [1.0, 10.0], "corner_z": [-15.0, 15.0]}
const SHAPE_NAMES := {"room_half_width": "Half width, m", "room_back": "Back wall, m from middle", "room_front": "Entrance wall, m from middle",
	"back_wall_half": "Back wall half width, m", "corner_z": "Angled walls start at z"}
var _spot_sliders: Dictionary = {}
var _spot_labels: Dictionary = {}
var _spot_read: Label
## Values per mood: spots, washes, fill, sun, exposure.
var values: Dictionary = {}
var _sliders: Dictionary = {}
var _labels: Dictionary = {}
var _readout: Label
var _mood: String = ""
var _quiet: bool = false

const KEYS := ["spots", "washes", "fill", "sun", "exposure"]
## Where the sliders start, per mood: Ramon's numbers for bright (4 Oct, "keep the sliders for
## now"); a mood not listed starts at 1, washes off, and its own exposure.
const START := {"bright": {"spots": 3.26, "washes": 0.0, "fill": 1.52, "sun": 0.66, "exposure": 1.05}}
const SPOT_KEYS := ["strength", "cone", "softness", "reach", "falloff", "height", "warmth"]
const ROOM_KEYS := ["ceiling", "pedestal", "sun_up", "sun_turn"]
const ROOM_RANGES := {"ceiling": [6.0, 14.0], "pedestal": [2.0, 5.0], "sun_up": [5.0, 90.0], "sun_turn": [-180.0, 180.0]}
const ROOM_NAMES := {"ceiling": "Ceiling, m", "pedestal": "Pedestal radius, m", "sun_up": "Sun height, degrees", "sun_turn": "Sun turn, degrees"}
const SPOT_RANGES := {"strength": [0.0, 15.0], "cone": [10.0, 120.0], "softness": [0.1, 10.0], "reach": [2.0, 30.0],
	"falloff": [0.01, 2.0], "height": [3.0, 8.4], "warmth": [0.0, 1.0]}
const SPOT_NAMES := {"strength": "Strength", "cone": "Cone, degrees", "softness": "Edge softness", "reach": "Reach, m",
	"falloff": "Falloff", "height": "Height, m", "warmth": "Warmth"}
## Warmth 0 is this cool white, 1 this warm one.
const COOL := Color(0.86, 0.92, 1.0)
const WARM := Color(1.0, 0.84, 0.62)
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
	var room_head := Label.new()
	room_head.text = "ROOM"
	room_head.add_theme_font_override("font", LabPrint.font("bold"))
	room_head.add_theme_font_size_override("font_size", 12)
	box.add_child(room_head)
	for k in ROOM_KEYS:
		var row := HBoxContainer.new()
		var name_label := Label.new()
		name_label.custom_minimum_size = Vector2(150, 0)
		name_label.add_theme_font_size_override("font_size", 12)
		row.add_child(name_label)
		var s := HSlider.new()
		s.custom_minimum_size = Vector2(200, 18)
		s.min_value = float(ROOM_RANGES[k][0])
		s.max_value = float(ROOM_RANGES[k][1])
		s.step = 0.05
		s.focus_mode = Control.FOCUS_NONE
		s.value = _room_value(k)
		s.value_changed.connect(func(v: float) -> void: _on_room(k, v))
		row.add_child(s)
		box.add_child(row)
		_room_sliders[k] = s
		_room_labels[k] = name_label
	_show_room()
	if shape_root != null:
		var shape_head := Label.new()
		shape_head.text = "ROOM SHAPE"
		shape_head.add_theme_font_override("font", LabPrint.font("bold"))
		shape_head.add_theme_font_size_override("font_size", 12)
		box.add_child(shape_head)
		for k in SHAPE_KEYS:
			var row := HBoxContainer.new()
			var name_label := Label.new()
			name_label.custom_minimum_size = Vector2(150, 0)
			name_label.add_theme_font_size_override("font_size", 12)
			row.add_child(name_label)
			var s := HSlider.new()
			s.custom_minimum_size = Vector2(200, 18)
			s.min_value = float(SHAPE_RANGES[k][0])
			s.max_value = float(SHAPE_RANGES[k][1])
			s.step = 0.1
			s.focus_mode = Control.FOCUS_NONE
			s.value = float(shape_root.get(k))
			s.value_changed.connect(func(v: float) -> void: _on_shape(k, v))
			row.add_child(s)
			box.add_child(row)
			_shape_sliders[k] = s
			_shape_labels[k] = name_label
		_show_shape()
	if spot == null:
		return
	var head := Label.new()
	head.text = "CENTRE SPOT"
	head.add_theme_font_override("font", LabPrint.font("bold"))
	head.add_theme_font_size_override("font_size", 12)
	box.add_child(head)
	for k in SPOT_KEYS:
		var row := HBoxContainer.new()
		var name_label := Label.new()
		name_label.custom_minimum_size = Vector2(150, 0)
		name_label.add_theme_font_size_override("font_size", 12)
		row.add_child(name_label)
		var s := HSlider.new()
		s.custom_minimum_size = Vector2(200, 18)
		s.min_value = float(SPOT_RANGES[k][0])
		s.max_value = float(SPOT_RANGES[k][1])
		s.step = 0.01
		s.focus_mode = Control.FOCUS_NONE
		s.value = _spot_value(k)
		s.value_changed.connect(func(v: float) -> void: _on_spot(k, v))
		row.add_child(s)
		box.add_child(row)
		_spot_sliders[k] = s
		_spot_labels[k] = name_label
	_spot_read = Label.new()
	_spot_read.add_theme_font_size_override("font_size", 11)
	box.add_child(_spot_read)
	_show_spot()


func _room_value(k: String) -> float:
	match k:
		"ceiling":
			return (goat_room.get("size") as Vector3).y if goat_room != null else 8.5
		"pedestal":
			return float(showcase.get("radius")) if showcase != null else 3.0
		"sun_up":
			return (sun.call("angles") as Vector2).x if sun != null else 64.0
		"sun_turn":
			return (sun.call("angles") as Vector2).y if sun != null else 25.0
	return 0.0


## The sun moves at once; the ceiling and the pedestal rebuild, so they wait for the slider to
## settle a moment.
func _on_room(k: String, v: float) -> void:
	if _quiet:
		return
	if k == "sun_up" or k == "sun_turn":
		if sun != null:
			var a: Vector2 = sun.call("angles")
			sun.call("set_angles", v if k == "sun_up" else a.x, v if k == "sun_turn" else a.y)
	else:
		_room_pending[k] = v
		_room_wait = 0.3
	_show_room()


## The shape rebuilds the room, so it waits for the slider to settle a moment.
func _on_shape(k: String, v: float) -> void:
	if _quiet:
		return
	_shape_pending[k] = v
	_shape_wait = 0.35
	_show_shape()


func _show_shape() -> void:
	for k in _shape_labels:
		var v: float = float(_shape_pending.get(k, shape_root.get(k) if shape_root != null else 0.0))
		(_shape_labels[k] as Label).text = "%s  %.1f" % [SHAPE_NAMES[k], v]


func _show_room() -> void:
	for k in _room_labels:
		var v: float = float(_room_pending.get(k, _room_value(k)))
		(_room_labels[k] as Label).text = "%s  %.2f" % [ROOM_NAMES[k], v]


## The spot's current value for a slider.
func _spot_value(k: String) -> float:
	match k:
		"strength":
			return float((spot.get("energy") as Dictionary).get(Style.mood, 1.0))
		"cone":
			return float(spot.get("angle"))
		"softness":
			return float(spot.get("softness"))
		"reach":
			return float(spot.get("reach"))
		"falloff":
			return float(spot.get("attenuation"))
		"height":
			return float((spot as Node4D).position.y)
		"warmth":
			var c: Color = (spot.get("color") as Dictionary).get(Style.mood, COOL)
			return clampf((COOL.b - c.b) / maxf(COOL.b - WARM.b, 0.001), 0.0, 1.0)
	return 0.0


func _on_spot(k: String, v: float) -> void:
	if _quiet or spot == null:
		return
	match k:
		"strength":
			var e: Dictionary = (spot.get("energy") as Dictionary).duplicate()
			e[Style.mood] = v
			spot.set("energy", e)
		"cone":
			spot.set("angle", v)
		"softness":
			spot.set("softness", v)
		"reach":
			spot.set("reach", v)
		"falloff":
			spot.set("attenuation", v)
		"height":
			var n := spot as Node4D
			n.position = Vector4(n.position.x, v, n.position.z, n.position.w)
		"warmth":
			var cd: Dictionary = (spot.get("color") as Dictionary).duplicate()
			cd[Style.mood] = COOL.lerp(WARM, v)
			spot.set("color", cd)
	spot.call("apply_mood", Style.mood, true)
	_show_spot()


func _show_spot() -> void:
	if spot == null or _spot_read == null:
		return
	for k in SPOT_KEYS:
		(_spot_labels[k] as Label).text = "%s  %.2f" % [SPOT_NAMES[k], _spot_value(k)]
	_spot_read.text = "SPOT %s:  strength %.2f  cone %.0f  softness %.2f  reach %.1f  falloff %.2f  height %.2f  warmth %.2f" % [
		Style.mood.to_upper(), _spot_value("strength"), _spot_value("cone"), _spot_value("softness"), _spot_value("reach"),
		_spot_value("falloff"), _spot_value("height"), _spot_value("warmth")]


func _defaults(m: String) -> Dictionary:
	if START.has(m):
		return (START[m] as Dictionary).duplicate()
	var exp_v: float = float((Style.ROOM_LIGHT.get(m, {}) as Dictionary).get("exposure", (RoomScript.MOODS[m] as Dictionary)["exposure"]))
	return {"spots": 1.0, "washes": float(Style.gain.get("wash", 0.0)), "fill": 1.0, "sun": 1.0, "exposure": exp_v}


func _process(delta: float) -> void:
	if not _shape_pending.is_empty():
		_shape_wait -= delta
		if _shape_wait <= 0.0:
			for k in _shape_pending:
				shape_root.set(k, float(_shape_pending[k]))
			_shape_pending.clear()
			_show_shape()
	if not _room_pending.is_empty():
		_room_wait -= delta
		if _room_wait <= 0.0:
			if _room_pending.has("ceiling") and goat_room != null:
				var sz: Vector3 = goat_room.get("size")
				goat_room.set("size", Vector3(sz.x, float(_room_pending["ceiling"]), sz.z))
			if _room_pending.has("pedestal") and showcase != null:
				showcase.set("radius", float(_room_pending["pedestal"]))
			_room_pending.clear()
			_show_room()
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
		for k in _spot_sliders:
			(_spot_sliders[k] as HSlider).value = _spot_value(k)
		_quiet = false
		_push()
		_show()
		_show_spot()


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
	var all_now: Dictionary = room.get("mood_overrides") as Dictionary
	var over: Dictionary = (Style.ROOM_LIGHT.get(_mood, {}) as Dictionary).duplicate()
	# Keep what others set (the sun handle's angles).
	for key in ["key_elevation", "key_azimuth"]:
		if (all_now.get(_mood, {}) as Dictionary).has(key):
			over[key] = all_now[_mood][key]
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
