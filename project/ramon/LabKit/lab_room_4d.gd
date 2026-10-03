@tool
extends Node4D

## The lab's sky, sun, fill light and mood: bright dev by default, dark dev on a key.
##
## BOTH MOODS ARE DESIGNED (Ramon, 3 Oct: "you have to optimize for both"), each with its own
## numbers in MOODS below rather than one derived from the other.
## - Bright: a clean-studio feel. A pale sky, a high warm key from the front left (the bays are
##   viewed looking towards -Z, so faces turned right fall into shade and white boxes read as
##   forms against a white floor), a cool fill from behind right so no face goes dead, and a
##   measured ambient. Filmic tonemapping keeps the white dev floor white without blowing out.
## - Dark: a dim blue-black room. The key drops low, the fill goes, ambient is a whisper. The
##   rigs' own light pools and the glow strips (other kit pieces, listening for the mood) carry
##   the room, as stage lighting would.
##
## OTHER PIECES FOLLOW THE MOOD by joining the group "lab_mood_listener" and having
## `apply_mood(mood: String, instant: bool)`. This node is in the group "lab_mood", which the
## capture and measure runners use to shoot every view in both moods.
##
## The key (B by default) toggles it; the choice is remembered per viewer in
## user://lab_settings.cfg. Runners call set_mood() without `remember`, so a test never changes
## what the viewer chose.

const Style := preload("res://ramon/LabKit/lab_style.gd")
const LabMath := preload("res://ramon/LabKit/lab_math.gd")
const Mats := preload("res://ramon/LabKit/lab_materials.gd")
const SETTINGS := "user://lab_settings.cfg"
const GENERATED := "lab_generated"

signal mood_changed(mood: String)

const MOODS := {
	"bright": {
		"sky_top": Color(0.66, 0.74, 0.84), "sky_horizon": Color(0.93, 0.94, 0.95), "sky_bottom": Color(0.84, 0.84, 0.83),
		"ambient": Color(0.50, 0.53, 0.59), "ambient_sky": 0.25,
		"tonemap": 2, "exposure": 1.0, "white": 6.0,
		"key_color": Color(1.0, 0.965, 0.91), "key_energy": 1.75, "key_elevation": 50.0, "key_azimuth": -35.0,
		"fill_color": Color(0.80, 0.87, 1.0), "fill_energy": 0.32, "fill_elevation": 25.0, "fill_azimuth": 145.0,
	},
	"dark": {
		"sky_top": Color(0.012, 0.016, 0.026), "sky_horizon": Color(0.035, 0.045, 0.062), "sky_bottom": Color(0.015, 0.016, 0.02),
		"ambient": Color(0.10, 0.12, 0.17), "ambient_sky": 0.0,
		"tonemap": 2, "exposure": 1.15, "white": 4.0,
		"key_color": Color(0.70, 0.80, 1.0), "key_energy": 0.22, "key_elevation": 64.0, "key_azimuth": 25.0,
		"fill_color": Color(0.80, 0.87, 1.0), "fill_energy": 0.0, "fill_elevation": 30.0, "fill_azimuth": -150.0,
	},
}

## The mood the room starts in when nothing is remembered.
@export_enum("bright", "dark") var start_mood: String = "bright"
## The key that toggles the mood.
@export var mood_key: Key = KEY_B
## Seconds an eased mood change takes.
@export_range(0.0, 3.0, 0.05) var ease_seconds: float = 0.7
## A ground slab under the room, in metres (x, y thickness, z, w); zero size builds none. Bays
## build their own floors; this is for open rooms like the Hall and for tests.
@export var ground_size: Vector4 = Vector4.ZERO
## Metres one floor texture covers.
@export_range(0.25, 8.0, 0.25) var ground_texture_metres: float = 2.0

var mood: String = "bright"
var _env: WorldEnvironment4D
var _sky: GradientSkyMaterial4D
var _key: DirectionalLight4D
var _fill: DirectionalLight4D
var _ground: MeshInstance4D
var _from: Dictionary = {}
var _to: Dictionary = {}
var _t: float = 1.0


func _enter_tree() -> void:
	add_to_group("lab_mood")


func _ready() -> void:
	_build()
	var start: String = start_mood
	if not Engine.is_editor_hint():
		var cfg := ConfigFile.new()
		if cfg.load(SETTINGS) == OK:
			start = String(cfg.get_value("lab", "mood", start_mood))
	set_mood(start, true)


func _build() -> void:
	for child in get_children():
		if child.has_meta(GENERATED):
			remove_child(child)
			child.queue_free()
	_env = WorldEnvironment4D.new()
	_env.name = "Environment"
	_sky = GradientSkyMaterial4D.new()
	_env.sky_material = _sky
	_env.set_meta(GENERATED, true)
	add_child(_env)
	_env.make_current()
	_key = DirectionalLight4D.new()
	_key.name = "Key"
	_key.set_meta(GENERATED, true)
	add_child(_key)
	_fill = DirectionalLight4D.new()
	_fill.name = "Fill"
	_fill.set_meta(GENERATED, true)
	add_child(_fill)
	if ground_size.x > 0.0 and ground_size.z > 0.0:
		_ground = MeshInstance4D.new()
		_ground.name = "Ground"
		_ground.mesh = Mats.box_mesh(ground_size)
		_ground.position = Vector4(0.0, -ground_size.y * 0.5, 0.0, 0.0)
		_ground.set_meta(GENERATED, true)
		add_child(_ground)
		var body := StaticBody4D.new()
		body.name = "GroundBody"
		body.set_meta(GENERATED, true)
		var shape := CollisionShape4D.new()
		var box := BoxShape4D.new()
		box.size = ground_size
		shape.shape = box
		body.add_child(shape)
		body.position = _ground.position
		add_child(body)


## Switches to `new_mood` ("bright" or "dark"), eased unless `instant`. `remember` saves it as
## the viewer's choice (only the key does that, never a runner).
func set_mood(new_mood: String, instant: bool = false, remember: bool = false) -> void:
	if not MOODS.has(new_mood):
		return
	mood = new_mood
	_from = _current_values()
	_to = MOODS[new_mood].duplicate()
	_t = 1.0 if instant or ease_seconds <= 0.0 else 0.0
	_apply(_to if _t >= 1.0 else _from, 1.0)
	if _ground != null:
		_ground.material_override = Mats.surface(Style.surface("floor", mood), ground_size, ground_texture_metres)
	for n in get_tree().get_nodes_in_group("lab_mood_listener") if is_inside_tree() else []:
		if n.has_method("apply_mood"):
			n.call("apply_mood", mood, instant)
	if remember and not Engine.is_editor_hint():
		var cfg := ConfigFile.new()
		cfg.load(SETTINGS)
		cfg.set_value("lab", "mood", mood)
		cfg.save(SETTINGS)
	mood_changed.emit(mood)


func toggle_mood() -> void:
	set_mood("dark" if mood == "bright" else "bright", false, true)


func _unhandled_key_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == mood_key and not k.shift_pressed and not k.ctrl_pressed:
		toggle_mood()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _t >= 1.0:
		return
	_t = minf(1.0, _t + delta / maxf(ease_seconds, 0.001))
	_apply_blend(LabMath.ease01(_t))


func _current_values() -> Dictionary:
	if _sky == null:
		return MOODS[mood].duplicate()
	return {
		"sky_top": _sky.top_color, "sky_horizon": _sky.horizon_color, "sky_bottom": _sky.bottom_color,
		"ambient": _env.ambient_light_color, "ambient_sky": _env.ambient_light_sky_contribution,
		"tonemap": _env.tonemap_mode, "exposure": _env.tonemap_exposure, "white": _env.tonemap_white,
		"key_color": _key.light_color, "key_energy": _key.light_energy,
		"key_elevation": _to.get("key_elevation", 50.0), "key_azimuth": _to.get("key_azimuth", 30.0),
		"fill_color": _fill.light_color, "fill_energy": _fill.light_energy,
		"fill_elevation": _to.get("fill_elevation", 30.0), "fill_azimuth": _to.get("fill_azimuth", -150.0),
	}


func _apply_blend(k: float) -> void:
	var mixed: Dictionary = {}
	for key in _to:
		var a = _from.get(key, _to[key])
		var b = _to[key]
		if a is Color:
			mixed[key] = (a as Color).lerp(b, k)
		elif a is float or a is int:
			mixed[key] = lerpf(float(a), float(b), k)
		else:
			mixed[key] = b
	_apply(mixed, k)


func _apply(v: Dictionary, _k: float) -> void:
	if _sky == null:
		return
	_sky.top_color = v["sky_top"]
	_sky.horizon_color = v["sky_horizon"]
	_sky.bottom_color = v["sky_bottom"]
	_env.ambient_light_color = v["ambient"]
	_env.ambient_light_sky_contribution = float(v["ambient_sky"])
	_env.tonemap_mode = int(_to.get("tonemap", 2))
	_env.tonemap_exposure = float(v["exposure"])
	_env.tonemap_white = float(v["white"])
	_key.light_color = v["key_color"]
	_key.light_energy = float(v["key_energy"])
	_key.basis = LabMath.basis_with_z(LabMath.sun_direction(float(v["key_elevation"]), float(v["key_azimuth"])))
	_fill.light_color = v["fill_color"]
	_fill.light_energy = float(v["fill_energy"])
	_fill.basis = LabMath.basis_with_z(LabMath.sun_direction(float(v["fill_elevation"]), float(v["fill_azimuth"])))
	_fill.visible = float(v["fill_energy"]) > 0.001
