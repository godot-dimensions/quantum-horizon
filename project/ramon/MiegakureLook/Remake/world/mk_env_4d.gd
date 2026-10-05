extends Node4D
## Slice Garden: the sky, the sun, a fill light, the one spotlight, and the turn's change of mood.
##
## THE CREATION LAB'S LIGHT (Ramon, 6 Oct: "take the general look and lighting from creatorlabs. maybe
## also add the 1 spotlight with adjustment dev panel"). The numbers are the lab's as it plays: the
## kit's bright room light (CreationLab/kit/kit_style.gd ROOM_LIGHT) under Ramon's own saved settings
## (CreationLab/creation_lab_tuning.cfg, read 6 Oct): sky fill x1.52 (the blue in every shadow), the
## sun x0.66 at 64 degrees up and 25 round, exposure 1.05, and the centre spot: strength 2.69 x 3.26,
## a 35.7 degree cone with a 0.42 edge, 10.4 m reach, falloff 0.3, 8.4 m up, warmth 0.23. The spot
## here hangs over the little walker (or the island's middle) instead of a plinth, so he stands in the
## pool of light the lab's exhibit stands in.
##
## Every number lives in `values`, which the artist dev panel (hud/mk_tuner.gd, F1) reads and writes
## live and saves to slice_garden_tuning.cfg; what is saved there is where the garden starts.
##
## THE TURN. Turned into W, the sky shifts toward violet (`turned_shift`), the way Miegakure's sky
## changes in its turned screenshot: the mode reads from the sky alone. `set_turn(t, rotation)` is
## called by the camera every frame of a turn, t from 0 (normal) to 1 (turned).
##
## THE LIGHTS TURN WITH THE VIEW. A 4D sun with no W in its direction lights the faces you see in the
## normal view; a quarter turn into W would point its Z part out of the slice and the garden would go
## flat. Turning the sun and fill by the view's own rotation keeps the light on what you see the same
## in both views. (The spot points straight down, which the turn never touches.)
##
## NO class_name (engine_gotchas.md).

const SAVE_PATH := "res://ramon/MiegakureLook/Remake/slice_garden_tuning.cfg"

## The lab's room light ("bright"), before Ramon's multipliers.
const LAB := {
	"sky_top": Color(0.06, 0.08, 0.13), "sky_horizon": Color(0.12, 0.15, 0.22), "sky_bottom": Color(0.05, 0.06, 0.08),
	"ambient": Color(0.20, 0.24, 0.33), "white": 4.0,
	"key_color": Color(0.72, 0.82, 1.0), "key_energy": 0.42,
	"fill_color": Color(0.80, 0.87, 1.0), "fill_energy": 0.08, "fill_elevation": 30.0, "fill_azimuth": -150.0,
}
## A paler sky (Miegakure's mint), reached by `sky_lift` 0..1.
const PALE := {"sky_top": Color(0.62, 0.78, 0.76), "sky_horizon": Color(0.88, 0.94, 0.92), "sky_bottom": Color(0.74, 0.84, 0.82)}
## Where the sky goes when the view is turned into W (blended by turned_shift).
const TURNED := {"sky_top": Color(0.16, 0.10, 0.32), "sky_horizon": Color(0.30, 0.22, 0.48), "sky_bottom": Color(0.10, 0.07, 0.18)}
const TURNED_AMBIENT := Color(1.04, 0.94, 1.12)
const SPOT_COOL := Color(0.86, 0.92, 1.0)
const SPOT_WARM := Color(1.0, 0.84, 0.62)

## Live numbers (the dev panel's rows). Defaults are the Creation Lab's, 6 Oct.
var values: Dictionary = {
	"fill": 1.52, "sun": 0.66, "exposure": 1.05, "sun_up": 64.0, "sun_turn": 25.0,
	"spot_strength": 8.77, "spot_cone": 35.71, "spot_softness": 0.42, "spot_reach": 10.37,
	"spot_falloff": 0.30, "spot_height": 8.37, "spot_warmth": 0.23, "spot_follow": 1.0,
	"sky_lift": 0.0, "turned_shift": 1.0,
}

## Set by the game: what the spot hangs over (the walker), and the island's middle (spot_follow 0).
var follow: Node4D
var island_centre: Vector4 = Vector4.ZERO

var turn: float = 0.0
var view_basis: Projection = Projection.IDENTITY
var _env: WorldEnvironment4D
var _sky: GradientSkyMaterial4D
var _key: DirectionalLight4D
var _fill: DirectionalLight4D
var _spot: SpotLight4D
var _spot_at: Vector4 = Vector4.ZERO
var _spot_ready: bool = false


func _ready() -> void:
	load_values()
	_env = WorldEnvironment4D.new()
	_env.name = "Environment"
	_sky = GradientSkyMaterial4D.new()
	_env.sky_material = _sky
	_env.tonemap_mode = 2
	_env.ambient_light_sky_contribution = 0.0
	add_child(_env)
	_env.make_current()
	_key = DirectionalLight4D.new()
	_key.name = "Sun"
	add_child(_key)
	_fill = DirectionalLight4D.new()
	_fill.name = "Fill"
	add_child(_fill)
	_spot = SpotLight4D.new()
	_spot.name = "Spot"
	add_child(_spot)
	apply()


## Reads saved values (if any) over the defaults.
func load_values() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK or not cfg.has_section("light"):
		return
	for k in cfg.get_section_keys("light"):
		if values.has(k):
			values[k] = float(cfg.get_value("light", k))


func save_values() -> int:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	for k in values:
		cfg.set_value("light", k, values[k])
	return cfg.save(SAVE_PATH)


func set_value(key: String, v: float) -> void:
	values[key] = v
	apply()


## Everything from `values` and the turn.
func apply() -> void:
	set_turn(turn, view_basis)


## Blend the turned mood by `t` (0 normal view, 1 turned), and turn the sun and fill by `rotation`.
func set_turn(t: float, rotation: Projection) -> void:
	turn = clampf(t, 0.0, 1.0)
	view_basis = rotation
	if _sky == null:
		return
	var lift: float = float(values["sky_lift"])
	var shift: float = turn * float(values["turned_shift"])
	for k in ["sky_top", "sky_horizon", "sky_bottom"]:
		var c: Color = (LAB[k] as Color).lerp(PALE[k], lift).lerp(TURNED[k], shift * (1.0 - lift * 0.4))
		match k:
			"sky_top": _sky.top_color = c
			"sky_horizon": _sky.horizon_color = c
			"sky_bottom": _sky.bottom_color = c
	var amb: Color = (LAB["ambient"] as Color) * float(values["fill"])
	var tint: Color = Color(1, 1, 1).lerp(TURNED_AMBIENT, shift)
	_env.ambient_light_color = Color(amb.r * tint.r, amb.g * tint.g, amb.b * tint.b)
	_env.tonemap_exposure = float(values["exposure"])
	_env.tonemap_white = float(LAB["white"])
	_key.light_color = LAB["key_color"]
	_key.light_energy = float(LAB["key_energy"]) * float(values["sun"])
	_key.basis = rotation * _basis_with_z(_sun_direction(float(values["sun_up"]), float(values["sun_turn"])))
	_fill.light_color = LAB["fill_color"]
	_fill.light_energy = float(LAB["fill_energy"])
	_fill.basis = rotation * _basis_with_z(_sun_direction(float(LAB["fill_elevation"]), float(LAB["fill_azimuth"])))
	_spot.light_color = SPOT_COOL.lerp(SPOT_WARM, float(values["spot_warmth"]))
	_spot.light_energy = float(values["spot_strength"])
	_spot.set("spot_angle_degrees", float(values["spot_cone"]))
	_spot.set("spot_angle_attenuation", float(values["spot_softness"]))
	_spot.set("spot_range_meters", float(values["spot_reach"]))
	_spot.set("spot_range_attenuation", float(values["spot_falloff"]))
	# Straight down: its -Z points at the floor.
	_spot.global_basis = _basis_with_z(Vector4(0, 1, 0, 0))


func _process(delta: float) -> void:
	if _spot == null:
		return
	var target: Vector4 = island_centre
	if float(values["spot_follow"]) >= 0.5 and follow != null:
		target = follow.global_position
	var want: Vector4 = target + Vector4(0, float(values["spot_height"]), 0, 0)
	if not _spot_ready:
		_spot_at = want
		_spot_ready = true
	else:
		# Eased in the slice, but always exactly at him along the slice's normal, at any angle of
		# the turn (the camera keeps the slice on him; the pool must stay in it).
		_spot_at = _spot_at.lerp(want, clampf(delta * 3.0, 0.0, 1.0))
		var n: Vector4 = view_basis.w
		_spot_at += n * n.dot(want - _spot_at)
		_spot_at.y = want.y
	_spot.global_position = _spot_at


func environment() -> WorldEnvironment4D:
	return _env


## A unit direction from a height and a compass turn (the lab's convention, LabKit/lab_math.gd).
static func _sun_direction(elevation: float, azimuth: float) -> Vector4:
	var e: float = deg_to_rad(elevation)
	var az: float = deg_to_rad(azimuth)
	var flat: float = cos(e)
	return Vector4(sin(az) * flat, sin(e), cos(az) * flat, 0.0)


## An orthonormal basis whose Z is `z_axis` (LabKit/lab_math.gd basis_with_z, copied).
static func _basis_with_z(z_axis: Vector4) -> Projection:
	var forward: Vector4 = z_axis.normalized()
	var candidates: Array[Vector4] = [Vector4(1, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1)]
	candidates.sort_custom(func(p: Vector4, q: Vector4) -> bool: return absf(p.dot(forward)) < absf(q.dot(forward)))
	var axes: Array[Vector4] = []
	for c in candidates:
		var v: Vector4 = c - forward * c.dot(forward)
		for e in axes:
			v -= e * v.dot(e)
		if v.length() > 0.001:
			axes.append(v.normalized())
		if axes.size() == 3:
			break
	var p := Projection.IDENTITY
	p.x = axes[0]
	p.y = axes[1]
	p.z = forward
	p.w = axes[2]
	# Keep it right-handed (determinant +1), so nothing mirrors.
	if p.determinant() < 0.0:
		p.x = -p.x
	return p
