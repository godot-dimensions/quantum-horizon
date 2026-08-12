@tool
class_name Sun4D
extends Node
## Authoritative 4D sun state - drop this node anywhere alongside a
## DirectionalLight3D and a sky ShaderMaterial to drive both from a single
## 4D sun direction. Designed to preview live in the editor (no Play needed):
## drag any export below and the sky/light update immediately.
##
## The sun is a direction in 4D world space, not a DirectionalLight3D - the
## light and the sky shader are both adapters fed FROM this state, never the
## other way around.
##
## The 4D sun direction is composed from two exports rather than one raw
## Vector4, because its x/y/z part and its w part play genuinely different
## roles (see _compose_sun_direction_4d()): sky_direction is "where in the
## visible sky would the sun sit," sun_w_extent is "how far has it rotated
## out of the visible slice" - a single bounded [-1, 1] value, which is also
## why it's the one that gets an actual Inspector slider (@export_range)
## while sky_direction stays a plain vector: x/y/z don't have a fixed
## individual range the way w's role does.
##
## Each frame we read the observer's global_basis (a Projection whose
## .x/.y/.z/.w members are the basis columns directly - the same convention
## bearing_utility_4d.gd already uses) and dot the composed 4D sun direction
## against each column. For an orthonormal basis this is exactly the
## local-frame representation of the world vector (equivalent to
## inverse(basis) * v), reusing the existing bearing-math convention instead
## of a parallel one.
##
## The xyz part of that local vector is the apparent 3D sun direction fed to
## the sky shader and DirectionalLight3D. The w part is NOT discarded: as it
## grows, the sun is rotating out of the visible 3D slice, and a light
## pointing purely along w has zero directional gradient across a 3D slice -
## a real geometric fact, not an art choice - so w drives a fade of the sun's
## directionality toward flat/ambient rather than an arbitrary disappearance.
##
## isoclinic_angle_1/_2 rotate the sun's own world-space direction through
## two mutually orthogonal planes (xw and yz - together they span all of 4D).
## Equal angles give a true isoclinic rotation; unequal angles give the
## general SO(4) double rotation. Scrub them by hand for a static pose, or
## enable auto_rotate to watch the "unusual sun path" phenomenon (from the
## HyperEarth/double-rotation reference material) play out over time - this
## reproduces it without needing a curved planet surface, since this engine's
## 4D space is flat (Basis4D/Node4D already work this way). Note
## isoclinic_angle_1 (xw plane) only has a visible effect once sun_w_extent
## or sky_direction.x is non-zero - a rotation can't move a component that's
## already sitting at zero.

## Where in the visible sky the sun would sit if sun_w_extent were 0.
@export var sky_direction: Vector3 = Vector3(0.0, 1.0, 0.3)

## How far the sun has rotated out of the visible 3D slice: 0 = fully in the
## visible sky, +-1 = fully out (toward ana/+w or kata/-w). This is the
## single most important knob for the "isoclinic sun path" phenomenon - see
## the w_fade discussion in _process() and _compose_sun_direction_4d().
@export_range(-1.0, 1.0, 0.01) var sun_w_extent: float = 0.0

@export_group("Rotation")
@export_range(-180.0, 180.0, 0.5, "degrees") var isoclinic_angle_1: float = 0.0
@export_range(-180.0, 180.0, 0.5, "degrees") var isoclinic_angle_2: float = 0.0
@export var auto_rotate: bool = false
@export var auto_rotate_rate_1: float = 15.0 ## degrees/sec, xw plane.
@export var auto_rotate_rate_2: float = 15.0 ## degrees/sec, yz plane.

@export_group("Sky appearance")
## Vertical color ramp for the sky. Stop offset 0.0 = straight down, 0.5 =
## horizon, 1.0 = straight up. Add/move/recolor stops directly in the
## Inspector - no shader edits needed. Editing stops in place (not replacing
## the whole Gradient) updates live via GradientTexture1D's own
## regenerate-on-change behavior, no extra wiring required.
@export var sky_gradient: Gradient = _make_default_sky_gradient():
	set(value):
		sky_gradient = value
		_apply_sky_gradient()

@export_group("Render targets")
@export var sky_material: ShaderMaterial
## Mesh materials this Sun4D drives directly (their get_cross_section_material()
## "fake_light_direction" uniform - see tetra_cross_section_shader.glsl).
## Deliberately explicit, not a scene-wide search or a global broadcast: a
## global uniform here previously bled this scene's sun into every other
## scene's TetraMesh4D materials for as long as this node was open in any
## editor tab. Only materials listed here are ever touched.
@export var mesh_materials: Array[Material4D] = []
@export var max_sun_energy: float = 1.2
@export var min_sun_energy: float = 0.05

@onready var _player: Node4D = $"../Player"
@onready var _directional_light: DirectionalLight3D = $"../DirectionalLight"
@onready var _debug_label: Label = get_node_or_null("../DebugUI/SunDebugLabel")

var _sky_ramp_texture: GradientTexture1D


static func _make_default_sky_gradient() -> Gradient:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gradient.colors = PackedColorArray([Color(0.13, 0.11, 0.09), Color(0.55, 0.7, 0.95), Color(0.05, 0.12, 0.35)])
	return gradient


func _ready() -> void:
	_sky_ramp_texture = GradientTexture1D.new()
	_apply_sky_gradient()


func _apply_sky_gradient() -> void:
	if _sky_ramp_texture == null:
		return
	_sky_ramp_texture.gradient = sky_gradient
	if sky_material:
		sky_material.set_shader_parameter("sky_ramp", _sky_ramp_texture)


## Combines sky_direction and sun_w_extent into a proper unit Vector4: the
## xyz part is sky_direction scaled down by sqrt(1 - w^2) so the whole thing
## stays unit length automatically (no separate normalize step needed - by
## construction x^2+y^2+z^2+w^2 = (1-w^2) + w^2 = 1).
func _compose_sun_direction_4d() -> Vector4:
	var w: float = clamp(sun_w_extent, -1.0, 1.0)
	var xyz_scale: float = sqrt(max(0.0, 1.0 - w * w))
	var dir3: Vector3 = sky_direction.normalized() if sky_direction.length() > 0.0001 else Vector3.UP
	return Vector4(dir3.x * xyz_scale, dir3.y * xyz_scale, dir3.z * xyz_scale, w)


func _process(delta: float) -> void:
	if auto_rotate:
		isoclinic_angle_1 = wrapf(isoclinic_angle_1 + auto_rotate_rate_1 * delta, -180.0, 180.0)
		isoclinic_angle_2 = wrapf(isoclinic_angle_2 + auto_rotate_rate_2 * delta, -180.0, 180.0)

	var rotor: Rotor4D = Rotor4D.from_xw(deg_to_rad(isoclinic_angle_1)).rotate_rotor(Rotor4D.from_yz(deg_to_rad(isoclinic_angle_2)))
	var sun_world: Vector4 = rotor.rotate_vector(_compose_sun_direction_4d())

	if _player == null:
		return

	var basis: Projection = _player.global_basis
	var local_sun := Vector4(basis.x.dot(sun_world), basis.y.dot(sun_world), basis.z.dot(sun_world), basis.w.dot(sun_world))

	var visible_part := Vector3(local_sun.x, local_sun.y, local_sun.z)
	var visible_length: float = visible_part.length()
	var w_fade: float = clamp(visible_length, 0.0, 1.0)
	var sun_dir_3d: Vector3 = (visible_part / visible_length) if visible_length > 0.0001 else Vector3.UP
	var sun_energy: float = lerp(min_sun_energy, max_sun_energy, w_fade)

	if _directional_light:
		var up_hint: Vector3 = Vector3.FORWARD if absf(sun_dir_3d.y) > 0.999 else Vector3.UP
		_directional_light.global_transform.basis = Basis.looking_at(-sun_dir_3d, up_hint)
		_directional_light.light_energy = sun_energy

	if sky_material:
		sky_material.set_shader_parameter("sun_direction", sun_dir_3d)
		sky_material.set_shader_parameter("sun_energy", sun_energy)

	# Only the materials explicitly listed here - never anything scene-wide or
	# global (see mesh_materials doc comment above for why). Length is
	# w_fade, not 1, so these meshes flatten toward neutral shading as the
	# sun rotates out of the visible slice, same as the light/sky energy fade.
	var fake_light_direction: Vector3 = sun_dir_3d * w_fade
	for material in mesh_materials:
		if material:
			material.get_cross_section_material().set_shader_parameter("fake_light_direction", fake_light_direction)

	if _debug_label:
		_debug_label.text = "sun 4D (world): %s\nsun 3D (local, visible): %s\nlocal w: %.3f    w-fade: %.3f" % [
			_format_vec4(sun_world), _format_vec3(sun_dir_3d), local_sun.w, w_fade
		]


func _format_vec4(v: Vector4) -> String:
	return "(%.2f, %.2f, %.2f, %.2f)" % [v.x, v.y, v.z, v.w]


func _format_vec3(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]
