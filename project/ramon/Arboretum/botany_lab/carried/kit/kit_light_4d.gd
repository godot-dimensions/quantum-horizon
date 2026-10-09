@tool
extends Node4D

## Kit: a light, in one of three kinds, with its own strength and colour per mood. Move the node
## to move the light; `aim` is the world point a spot or downlight looks at.
##
##   downlight  a narrow spot straight down onto a subject, with a glowing disc in the ceiling
##              where it hangs: the pool of light the concept frames put under every exhibit
##   spot       a broad soft spot (the light bench's frame 4: 90 degrees, soft edge), a wash
##   wash       an omni light with a long, gentle falloff, for walls and text
##
## 4D lights fall off steeply by default, so a spot barely lit a metre (the light bench,
## _light_test_runner.gd, 4 Oct); `attenuation` here is low (0.2) to give real pools and washes.
##
## NO class_name (engine_gotchas.md).

const Build := preload("res://ramon/Arboretum/botany_lab/carried/scripts/chamber_build.gd")
const Mats := preload("res://ramon/Arboretum/botany_lab/carried/LabKit/lab_materials.gd")
const Mark := preload("res://ramon/Arboretum/botany_lab/carried/LabKit/lab_mark_4d.gd")
const Style := preload("res://ramon/Arboretum/botany_lab/carried/kit/kit_style.gd")

@export_tool_button("Rebuild") var _rebuild_action: Callable = rebuild
@export_enum("downlight", "spot", "wash") var kind: String = "downlight":
	set(v):
		kind = v
		_later()
## The world point it looks at (spot and downlight).
@export var aim: Vector3 = Vector3(0, 0, -10):
	set(v):
		aim = v
		_aim()
@export_range(5.0, 120.0, 1.0) var angle: float = 50.0:
	set(v):
		angle = v
		_set_params()
## How soft the cone's edge is (1 is a crisp pool, 6 a broad wash).
@export_range(0.1, 10.0, 0.1) var softness: float = 1.5:
	set(v):
		softness = v
		_set_params()
@export_range(1.0, 60.0, 0.5) var reach: float = 16.0:
	set(v):
		reach = v
		_set_params()
@export_range(0.01, 2.0, 0.01) var attenuation: float = 0.2:
	set(v):
		attenuation = v
		_set_params()
@export var energy: Dictionary = {"bright": 4.0, "dark": 5.0}:
	set(v):
		energy = v
		_set_params()
@export var color: Dictionary = {"bright": Color(1.0, 0.97, 0.92), "dark": Color(1.0, 0.95, 0.88)}:
	set(v):
		color = v
		_set_params()
## Draw the fixture: a glowing disc where a downlight hangs.
## Where the fixture disc hangs, world height in metres (below 0: just above the light). The goat
## room keeps it at the ceiling, wherever the light is.
@export var fixture_at: float = -1.0:
	set(v):
		fixture_at = v
		_place_fixture()
@export var fixture: bool = true:
	set(v):
		fixture = v
		_later()

var _light: Light4D
var _disc: MeshInstance4D
var _queued: bool = false


func _enter_tree() -> void:
	add_to_group("lab_mood_listener")
	add_to_group("kit_light")


var _last_at: Vector4 = Vector4.INF


## Node4D has no transform notification: re-aim when the light has been moved (in the editor).
func _process(_delta: float) -> void:
	if not is_inside_tree():
		return
	var at: Vector4 = global_position
	if at != _last_at:
		_last_at = at
		_aim()
		_place_fixture()


func _ready() -> void:
	rebuild()


func _later() -> void:
	if not is_inside_tree() or _queued:
		return
	_queued = true
	(func() -> void:
		_queued = false
		rebuild()).call_deferred()


func rebuild() -> void:
	Build.clear(self)
	_disc = null
	if kind == "wash":
		_light = OmniLight4D.new()
	else:
		_light = SpotLight4D.new()
	_light.name = "Light"
	_light.set_meta(Build.GENERATED, true)
	add_child(_light)
	if kind == "downlight" and fixture:
		_disc = MeshInstance4D.new()
		_disc.name = "Fixture"
		var c := CubinderShape4D.new()
		c.radius = 0.42
		c.height = 0.04
		c.thickness = 0.4
		_disc.mesh = c.to_tetra_mesh({"segments": 40})
		_disc.set_meta(Build.GENERATED, true)
		add_child(_disc)
		_place_fixture()
	_set_params()
	_aim()


func _aim() -> void:
	if _light == null or not is_inside_tree() or kind == "wash":
		return
	var from: Vector4 = global_position
	var to := Vector4(aim.x, aim.y, aim.z, 0.0)
	if (to - from).length() < 0.01:
		return
	_light.global_basis = Mark.basis_looking(from, to)


func _set_params() -> void:
	if _light == null:
		return
	_light.set("light_energy", float(energy.get(Style.mood, 1.0)) * float(Style.gain.get("wash" if kind == "wash" else "spot", 1.0)))
	_light.set("light_color", color.get(Style.mood, Color.WHITE))
	if _light is SpotLight4D:
		_light.set("spot_angle_degrees", angle)
		_light.set("spot_angle_attenuation", softness)
		_light.set("spot_range_meters", reach)
		_light.set("spot_range_attenuation", attenuation)
	else:
		_light.set("omni_range_meters", reach)
		_light.set("omni_range_attenuation", attenuation)
	if is_instance_valid(_disc):
		_disc.material_override = Mats.glow(Style.pick(Style.FIXTURE), 1.0)


func apply_mood(_m: String, _instant: bool = false) -> void:
	_set_params()


func _place_fixture() -> void:
	if not is_instance_valid(_disc):
		return
	var y: float = 0.15
	if fixture_at >= 0.0 and is_inside_tree():
		y = fixture_at - global_position.y
	_disc.position = Vector4(0, y, 0, 0)
