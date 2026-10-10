extends Node4D
## THE ANNEX'S LIGHT, and the B switch the labs share.
##
## BRIGHT is the lab kit's own bright dev light (LabKit/lab_room_4d.gd MOODS "bright": a pale studio
## sky, a high warm key from the front left, a cool fill from behind, a measured ambient), at the
## exposure Ramon saved for the Creation Lab (creation_lab_tuning.cfg, read only). The newer kit rooms
## light their exhibits with big white spots over a blue night; the Annex has ceilings and corridors and
## no pedestals, so it takes the kit's white room light instead, which gives the same white walls and
## floors with the lab grid (checked against the Creature Lab's frames, 11 Oct).
##
## DARK is the labs' dark palette (kit_style.gd "black": the light surfaces swapped for near-black) under
## the kit's dark light (a whisper of blue ambient), so the glowing strips, door frames and signs carry the
## rooms, and a torch on the camera shows what is ahead: the one liberty the Annex takes, because its
## corridors are deeper than a lab's bay.
##
## B toggles it (as in the labs), remembered in user://maze_remake_2.cfg. Anything that wants to follow
## joins the group "mr2_palette" and has `apply_palette(dark: bool)`.

const KitStyle := preload("res://ramon/MazeRemake2/carried/kit_style.gd")
const LabMath := preload("res://ramon/MazeRemake2/carried/lab_math.gd")
const LAB_TUNING := "res://ramon/CreationLab/creation_lab_tuning.cfg"
const SETTINGS := "user://maze_remake_2.cfg"

## LabKit's two designed moods (lab_room_4d.gd MOODS), as the Annex uses them.
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

## Live gains (the Tab panel tunes them and saves them with the game's tuning).
@export var key_gain: float = 1.0
@export var ambient_gain: float = 1.0
## A level's own lift of the ambient in DARK (its rooms may be bigger than the torch reaches).
var dark_ambient_gain: float = 1.0
@export var exposure_gain: float = 1.0
## The torch on the camera in DARK.
@export var torch_energy: float = 3.6
@export var torch_angle: float = 38.0
@export var torch_reach: float = 24.0

var dark: bool = false
var env: WorldEnvironment4D
var sky: GradientSkyMaterial4D
var key: DirectionalLight4D
var fill: DirectionalLight4D
var torch: SpotLight4D
var lab_exposure: float = 1.05


func _ready() -> void:
	var lab := ConfigFile.new()
	if lab.load(LAB_TUNING) == OK:
		lab_exposure = float(lab.get_value("light_bright", "exposure", lab_exposure))
	env = WorldEnvironment4D.new()
	env.name = "Environment"
	sky = GradientSkyMaterial4D.new()
	env.sky_material = sky
	add_child(env)
	env.make_current()
	key = DirectionalLight4D.new()
	key.name = "Key"
	add_child(key)
	fill = DirectionalLight4D.new()
	fill.name = "Fill"
	add_child(fill)
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		dark = bool(cfg.get_value("view", "dark", false))
	apply()


## Lays the light and the palette as they stand now.
func apply() -> void:
	if env == null:
		return
	KitStyle.palette = "black" if dark else "grey"
	KitStyle.apply("bright")
	var v: Dictionary = MOODS["dark" if dark else "bright"]
	env.make_current()
	sky.top_color = v["sky_top"]
	sky.horizon_color = v["sky_horizon"]
	sky.bottom_color = v["sky_bottom"]
	env.ambient_light_color = (v["ambient"] as Color) * ambient_gain * (dark_ambient_gain if dark else 1.0)
	env.ambient_light_sky_contribution = float(v["ambient_sky"])
	env.tonemap_mode = int(v["tonemap"])
	env.tonemap_exposure = (lab_exposure if not dark else float(v["exposure"])) * exposure_gain
	env.tonemap_white = float(v["white"])
	key.light_color = v["key_color"]
	key.light_energy = float(v["key_energy"]) * key_gain
	key.basis = LabMath.basis_with_z(LabMath.sun_direction(float(v["key_elevation"]), float(v["key_azimuth"])))
	fill.light_color = v["fill_color"]
	fill.light_energy = float(v["fill_energy"])
	fill.visible = float(v["fill_energy"]) > 0.001
	fill.basis = LabMath.basis_with_z(LabMath.sun_direction(float(v["fill_elevation"]), float(v["fill_azimuth"])))
	if torch != null:
		torch.visible = dark
		torch.set("light_energy", torch_energy)
		torch.set("spot_angle_degrees", torch_angle)
		torch.set("spot_range_meters", torch_reach)
	if is_inside_tree():
		for n in get_tree().get_nodes_in_group(&"mr2_palette"):
			if n.has_method("apply_palette"):
				n.call("apply_palette", dark)


## B: the other palette, remembered (a runner passes remember = false).
func toggle(remember: bool = true) -> void:
	set_dark(not dark, remember)


func set_dark(on: bool, remember: bool = false) -> void:
	dark = on
	apply()
	if remember:
		var cfg := ConfigFile.new()
		cfg.load(SETTINGS)
		cfg.set_value("view", "dark", dark)
		cfg.save(SETTINGS)


## The torch hangs on the camera, shining where you look; on only in DARK.
func attach_torch(camera: Node4D) -> void:
	if torch != null:
		torch.queue_free()
	torch = SpotLight4D.new()
	torch.name = "Torch"
	torch.set("light_color", Color(1.0, 0.95, 0.86))
	torch.set("spot_angle_attenuation", 0.9)
	torch.set("spot_range_attenuation", 0.35)
	torch.position = Vector4(0.15, -0.1, 0.0, 0.0)
	camera.add_child(torch)
	apply()
