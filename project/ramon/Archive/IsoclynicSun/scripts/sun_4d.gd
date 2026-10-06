@tool
class_name Sun4D
extends Node
## Authoritative 4D sun state - drop this node alongside a DirectionalLight4D
## to point it in the correct 4D direction every frame. Designed to preview
## live in the editor (no Play needed): drag any export below and the light
## updates immediately.
##
## The sun is a direction in 4D world space, not a DirectionalLight4D - the
## light is an adapter fed FROM this state, never the other way around.
## A GradientSkyMaterial4D on the scene's WorldEnvironment4D reads that same
## DirectionalLight4D directly (up to 4 suns, evaluated in 4D), and the
## cross-section renderer's own light() shader shades TetraMesh4D materials
## from it too - both already fade out correctly as the sun rotates out of
## the visible 3D slice on their own, so this script no longer has to fake
## either effect itself (see project/ramon/follow_up/isoclynic_sun_reinstate.md
## for the old fake_light_direction approach this replaced).
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

@onready var _player: Node4D = $"../Player"
@onready var _directional_light: DirectionalLight4D = $"../Sun"
@onready var _debug_label: Label = get_node_or_null("../DebugUI/SunDebugLabel")


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

	if _directional_light:
		# DirectionalLight4D emits along its local -Z, so aiming -Z at
		# -sun_world points the light the way real sunlight travels (down
		# from the sun), which leaves it shining FROM the sun_world
		# direction, matching how sky/mesh shading interpret it elsewhere.
		# Swap the up hint on the rare frame sun_world is near-parallel to
		# the default one, same edge case the old 3D Basis.looking_at path
		# used to guard against.
		var up_hint: Vector4 = Vector4(0, 0, 1, 0) if absf(sun_world.y) > 0.999 else Vector4(0, 1, 0, 0)
		_directional_light.look_at(-sun_world, up_hint)

	if _debug_label == null or _player == null:
		return

	var basis: Projection = _player.global_basis
	var local_sun := Vector4(basis.x.dot(sun_world), basis.y.dot(sun_world), basis.z.dot(sun_world), basis.w.dot(sun_world))
	var visible_part := Vector3(local_sun.x, local_sun.y, local_sun.z)
	var w_fade: float = clamp(visible_part.length(), 0.0, 1.0)
	_debug_label.text = "sun 4D (world): %s\nsun 3D (local, visible): %s\nlocal w: %.3f    w-fade: %.3f" % [
		_format_vec4(sun_world), _format_vec3(visible_part), local_sun.w, w_fade
	]


func _format_vec4(v: Vector4) -> String:
	return "(%.2f, %.2f, %.2f, %.2f)" % [v.x, v.y, v.z, v.w]


func _format_vec3(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]
