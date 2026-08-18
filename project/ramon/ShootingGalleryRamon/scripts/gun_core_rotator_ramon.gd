extends MeshInstance4D
## Ramon-only fork of gun_core_rotator.gd - identical rotation/pulse-on-fire
## behavior, with three changes: the idle/hot colors are dark red -> bright
## red instead of purple (this branch's charge-up mechanic wants the core
## reading as "getting hot" rather than the original's stylistic purple), a
## new charge_glow input (set every frame by hitscan_weapon_ramon.gd while
## charging) blends in on top of the existing fire-pulse glow (whichever
## effect is currently stronger wins, rather than fighting each other or
## needing a second color-lerp path), and the mesh is kept as its original
## solid ArrayTetraMesh4D rather than converted to a wire mesh - the
## original script converted it specifically to get genuine wireframe
## rendering (see gun_core_rotator.gd's own comment on why), but this
## branch wants the core to read as solid geometry instead.

@export var base_speed: float = 1.5 # Radians per second, in each of the xw/yz planes.
@export var pulse_speed_multiplier: float = 6.0
@export var pulse_decay_rate: float = 4.0 # Higher = settles back to base_speed faster.

@export var base_color: Color = Color(0.35, 0.03, 0.03, 1.0) # Dark red, idle.
@export var hot_color: Color = Color(1.0, 0.08, 0.05, 1.0) # Bright red, at full charge/pulse.

## Set externally (0-1) by hitscan_weapon_ramon.gd while the charge button is
## held. Not a @export - this is a live input, not an authoring-time tunable.
var charge_glow: float = 0.0

var _speed_multiplier: float = 1.0


func _process(delta: float) -> void:
	_speed_multiplier = 1.0 + (_speed_multiplier - 1.0) * exp(-pulse_decay_rate * delta)
	var angle: float = base_speed * _speed_multiplier * delta
	rotate_rotor_local(Rotor4D.from_xw(angle).rotate_rotor(Rotor4D.from_yz(angle)))

	var pulse_glow_t: float = clampf((_speed_multiplier - 1.0) / (pulse_speed_multiplier - 1.0), 0.0, 1.0)
	var glow_t: float = maxf(pulse_glow_t, charge_glow)
	material_override.albedo_color = base_color.lerp(hot_color, glow_t)


func pulse() -> void:
	_speed_multiplier = pulse_speed_multiplier
