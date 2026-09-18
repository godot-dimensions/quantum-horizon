extends Node
## The sole owner of the head's orientation, and the arbiter between everything that
## wants it.
##
## Four behaviours compete for one basis, so they are ranked rather than blended
## blindly. Highest wins, and a lower one cannot interrupt a higher one:
##
##   1 GLANCE      - the player has come close to the head. Brief, and it fires in ANY
##                   state, walking or idle, because a creature's attention being pulled
##                   to something moving in front of its face is not an idle behaviour.
##   2 SEEK        - idle only, rare: hunt for the player wherever they are, including
##                   behind, recruiting the neck and bracing a leg to reach the angle.
##   3 SHAKE       - idle only, occasional: a quick flick, the way an animal resettles.
##   4 WANDER      - idle only: the ordinary aimless glance. Moved here from
##                   idle_layer.gd when the head gained three more claimants.
##
## WHY RANKED AND NOT ADDITIVE: two simultaneous aims would average into a direction
## that points at neither, which reads as the creature being confused rather than as two
## things happening. Attention is exclusive in real animals too.
##
## Whatever was happening resumes automatically: nothing here holds state about the
## behaviour it interrupted, because each frame re-picks the winner and the loser simply
## stops being applied.
##
## RUNS AT PRIORITY -3, first of everything, so the channels it sets - the neck's aim and
## a braced foot - are in place before the gait driver, the spine solver or the IK chains
## read them that frame.

@export var creature_path: NodePath = NodePath("../Creature")
@export var gait_driver_path: NodePath = NodePath("../IKGaitDriver")
@export var spine_solver_path: NodePath = NodePath("../SpineNeckSolver")
@export var player_path: NodePath = NodePath("../Player")

@export_group("Glance at a near player")
## Measured head-to-player, not body-to-player: something passing the tail should not
## pull the creature's gaze.
@export var glance_radius: float = 4.0
## Re-arms only once the player has left this larger radius, so loitering at the edge of
## the trigger does not make the creature glance over and over.
@export var glance_release_radius: float = 5.5
@export_range(0.2, 5.0, 0.1, "suffix:s") var glance_duration: float = 1.1
@export_range(0.0, 1.0, 0.05) var glance_strength: float = 0.85

@export_group("Seek the player (idle only)")
@export_range(2.0, 60.0, 0.5, "suffix:s") var seek_interval_min: float = 12.0
@export_range(2.0, 90.0, 0.5, "suffix:s") var seek_interval_max: float = 26.0
@export_range(0.5, 6.0, 0.1, "suffix:s") var seek_duration: float = 2.6
## How long it holds the player in view once it has found them, inside seek_duration.
@export_range(0.1, 3.0, 0.1, "suffix:s") var seek_hold: float = 0.9
## How much of the turn the NECK contributes. The head alone cannot see behind itself;
## recruiting the neck base is what makes the angle reachable.
@export_range(0.0, 1.0, 0.05) var seek_neck_share: float = 0.55
## Past this angle the creature braces a leg out to twist further. Below it, a head and
## neck turn is enough and bracing would look fidgety.
@export_range(30.0, 180.0, 5.0, "suffix:°") var seek_brace_threshold: float = 95.0
@export_range(0.0, 0.6, 0.02) var seek_brace_distance: float = 0.22

@export_group("Head shake (idle only)")
@export_range(2.0, 60.0, 0.5, "suffix:s") var shake_interval_min: float = 7.0
@export_range(2.0, 90.0, 0.5, "suffix:s") var shake_interval_max: float = 18.0
@export_range(0.1, 2.0, 0.05, "suffix:s") var shake_duration: float = 0.55
@export_range(1.0, 6.0, 0.5) var shake_cycles: float = 3.0
@export_range(0.0, 40.0, 1.0, "suffix:°") var shake_degrees: float = 13.0

@export_group("Wander (idle only)")
@export_range(0.0, 60.0, 1.0, "suffix:°") var wander_degrees: float = 26.0
@export_range(0.5, 20.0, 0.5, "suffix:s") var wander_interval_min: float = 3.5
@export_range(0.5, 30.0, 0.5, "suffix:s") var wander_interval_max: float = 9.0
@export_range(0.2, 4.0, 0.1, "suffix:s") var wander_duration: float = 1.6
@export_range(0.0, 3.0, 0.1, "suffix:s") var wander_hold: float = 0.7
## Chance a wander glance goes through W. A look into the unseen axis does not turn the
## head at all from the player's side - it changes the head's cross-section - so it is
## deliberately the minority case, or the creature appears to deform for no reason.
@export_range(0.0, 1.0, 0.05) var wander_w_chance: float = 0.3

@export var show_label: bool = true

## Legs braced during a seek. Hind only: bracing at the rear lets the front twist, which
## is the way round an animal actually does it.
const BRACE_LEGS: PackedStringArray = ["HindLA", "HindLK", "HindRA", "HindRK"]

var _head: Node4D = null
var _gait: Node = null
var _spine: Node = null
var _player: Node4D = null
var _head_rest: Projection = Projection.IDENTITY
## The head's own bone direction at rest, in its local space. Read from the rig rather
## than assumed: this creature's head is not built on the +Y bone convention the legs
## use, so hard-coding an axis here would aim it sideways.
var _bone_local: Vector4 = Vector4(0, 1, 0, 0)

var _glance_elapsed: float = -1.0
var _glance_armed: bool = true
var _seek_timer: float = 0.0
var _seek_elapsed: float = -1.0
var _shake_timer: float = 0.0
var _shake_elapsed: float = -1.0
var _wander_timer: float = 0.0
var _wander_elapsed: float = -1.0
var _wander_plane: String = "XZ"
var _wander_sign: float = 1.0
var _state: String = "rest"
var _label: Label = null


func _ready() -> void:
	# First of all the animation nodes: see the note above.
	process_physics_priority = -3
	var creature: Node4D = get_node_or_null(creature_path) as Node4D
	_gait = get_node_or_null(gait_driver_path)
	_spine = get_node_or_null(spine_solver_path)
	_player = get_node_or_null(player_path) as Node4D
	if creature != null:
		_head = creature.get_node_or_null("Barrel/Chest/Neck1/Neck2/Head") as Node4D
	if _head == null or _gait == null:
		push_warning("HeadAttention: need both a Head rig and the gait driver.")
		set_physics_process(false)
		return
	_head_rest = _head.basis
	var tip: Node4D = _head.get_node_or_null("B2") as Node4D
	if tip != null and tip.position.length() > 0.0001:
		_bone_local = tip.position.normalized()
	_seek_timer = randf_range(seek_interval_min, seek_interval_max)
	_shake_timer = randf_range(shake_interval_min, shake_interval_max)
	_wander_timer = randf_range(wander_interval_min, wander_interval_max)
	if show_label:
		var layer := CanvasLayer.new()
		add_child(layer)
		_label = Label.new()
		_label.position = Vector2(14, 110)
		_label.add_theme_font_size_override("font_size", 17)
		_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
		_label.add_theme_constant_override("shadow_offset_x", 1)
		_label.add_theme_constant_override("shadow_offset_y", 1)
		layer.add_child(_label)


func _physics_process(delta: float) -> void:
	var idle: bool = bool(_gait.halted)
	# Channels are released every frame and re-claimed only by the winner, so a
	# behaviour that loses cannot leave the neck or a leg stuck where it left them.
	_release_channels(delta)

	_tick_glance(delta, idle)
	if idle:
		_tick_seek(delta)
		_tick_shake(delta)
		_tick_wander(delta)
	else:
		_seek_elapsed = -1.0
		_shake_elapsed = -1.0
		_wander_elapsed = -1.0

	# Ranked, highest first. The first one active wins the head outright.
	if _glance_elapsed >= 0.0:
		_state = "glance"
		_apply_glance()
	elif _seek_elapsed >= 0.0:
		_state = "seek"
		_apply_seek()
	elif _shake_elapsed >= 0.0:
		_state = "shake"
		_apply_shake()
	elif _wander_elapsed >= 0.0:
		_state = "wander"
		_apply_wander()
	else:
		_state = "idle" if idle else _gait.preset
		_head.basis = _head_rest

	if _label != null:
		_label.text = "attention: %s%s" % [
			_state, "" if _player == null else "   player %.1f away" % _player_distance()]


func _release_channels(delta: float) -> void:
	if _spine != null:
		_spine.aim_weight = lerpf(float(_spine.aim_weight), 0.0, clampf(delta * 8.0, 0.0, 1.0))
	if _gait != null and not _gait.target_offsets.is_empty():
		var fade: float = clampf(delta * 5.0, 0.0, 1.0)
		for tag in _gait.target_offsets.keys():
			var value: Vector4 = _gait.target_offsets[tag]
			_gait.target_offsets[tag] = value.lerp(Vector4.ZERO, fade)


func _player_distance() -> float:
	if _player == null or _head == null:
		return INF
	return (_player.global_position - _head.global_position).length()


func _to_player() -> Vector4:
	return (_player.global_position - _head.global_position).normalized()


# --- 1. glance: any state, edge-triggered on the player coming close -----------------

func _tick_glance(delta: float, _idle: bool) -> void:
	if _player == null:
		return
	var distance: float = _player_distance()
	if _glance_elapsed >= 0.0:
		_glance_elapsed += delta
		if _glance_elapsed >= glance_duration:
			_glance_elapsed = -1.0
		return
	# Hysteresis: arm only once they have properly left, so hovering at the boundary
	# does not retrigger every frame.
	if distance > glance_release_radius:
		_glance_armed = true
	elif _glance_armed and distance < glance_radius:
		_glance_armed = false
		_glance_elapsed = 0.0


func _apply_glance() -> void:
	# Eased in and out over the glance, so it is a look rather than a snap.
	var t: float = clampf(_glance_elapsed / maxf(glance_duration, 0.0001), 0.0, 1.0)
	var weight: float = sin(t * PI) * glance_strength
	_aim_head(_to_player(), weight)


# --- 2. seek: idle only, rare, recruits neck and a braced leg ------------------------

func _tick_seek(delta: float) -> void:
	if _player == null:
		return
	if _seek_elapsed >= 0.0:
		_seek_elapsed += delta
		if _seek_elapsed >= seek_duration:
			_seek_elapsed = -1.0
		return
	_seek_timer -= delta
	if _seek_timer <= 0.0:
		_seek_timer = randf_range(seek_interval_min, seek_interval_max)
		_seek_elapsed = 0.0


func _apply_seek() -> void:
	var out_time: float = (seek_duration - seek_hold) * 0.5
	var weight: float = 0.0
	if _seek_elapsed < out_time:
		weight = _ease(_seek_elapsed / maxf(out_time, 0.0001))
	elif _seek_elapsed < out_time + seek_hold:
		weight = 1.0
	else:
		weight = 1.0 - _ease((_seek_elapsed - out_time - seek_hold) / maxf(out_time, 0.0001))

	var direction: Vector4 = _to_player()
	# The neck takes its share first, which is what makes a rearward angle reachable at
	# all - the head's own travel is nowhere near 180 degrees.
	if _spine != null:
		_spine.aim_direction = direction
		_spine.aim_weight = weight * seek_neck_share
	_aim_head(direction, weight)

	# Past a threshold, brace the hind feet away from the turn so the body can twist
	# after the head instead of the neck running out of angle.
	var rest_forward := Vector4(-1.0, 0.0, 0.0, 0.0)
	var angle: float = rad_to_deg(acos(clampf(rest_forward.dot(direction), -1.0, 1.0)))
	if _gait == null or angle < seek_brace_threshold:
		return
	var brace: Vector4 = Vector4(-direction.x, 0.0, -direction.z, -direction.w).normalized() * (
		seek_brace_distance * weight)
	for tag in BRACE_LEGS:
		_gait.target_offsets[tag] = brace


# --- 3. shake: idle only, occasional ------------------------------------------------

func _tick_shake(delta: float) -> void:
	if _shake_elapsed >= 0.0:
		_shake_elapsed += delta
		if _shake_elapsed >= shake_duration:
			_shake_elapsed = -1.0
		return
	_shake_timer -= delta
	if _shake_timer <= 0.0:
		_shake_timer = randf_range(shake_interval_min, shake_interval_max)
		_shake_elapsed = 0.0


func _apply_shake() -> void:
	var t: float = clampf(_shake_elapsed / maxf(shake_duration, 0.0001), 0.0, 1.0)
	# Envelope so it starts and ends at rest rather than cutting off mid-flick.
	var envelope: float = sin(t * PI)
	var angle: float = deg_to_rad(shake_degrees) * envelope * sin(t * TAU * shake_cycles)
	_head.basis = _head_rest * Basis4D.from_zx(angle)


# --- 4. wander: idle only, the ordinary aimless glance -------------------------------

func _tick_wander(delta: float) -> void:
	if _wander_elapsed >= 0.0:
		_wander_elapsed += delta
		if _wander_elapsed >= wander_duration + wander_hold:
			_wander_elapsed = -1.0
		return
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = randf_range(wander_interval_min, wander_interval_max)
		_wander_elapsed = 0.0
		_wander_sign = 1.0 if randf() < 0.5 else -1.0
		if randf() < wander_w_chance:
			_wander_plane = "XW"
		else:
			_wander_plane = "XZ" if randf() < 0.7 else "XY"


func _apply_wander() -> void:
	var out_time: float = wander_duration * 0.5
	var amount: float = 0.0
	if _wander_elapsed < out_time:
		amount = _ease(_wander_elapsed / out_time)
	elif _wander_elapsed < out_time + wander_hold:
		amount = 1.0
	else:
		amount = 1.0 - _ease((_wander_elapsed - out_time - wander_hold) / maxf(out_time, 0.0001))
	_head.basis = _head_rest * _plane_basis(
		_wander_plane, deg_to_rad(wander_degrees) * amount * _wander_sign)


# --- shared -------------------------------------------------------------------------

## Points the head's own bone [param weight] of the way toward a world direction.
##
## Partial by design: aiming fully would swing the head to its limit on every glance.
## Blending the DIRECTION rather than the finished rotation keeps the result a genuine
## rotation at every weight, which lerping two bases would not.
func _aim_head(world_direction: Vector4, weight: float) -> void:
	if weight <= 0.001:
		_head.basis = _head_rest
		return
	var parent: Node4D = _head.get_parent() as Node4D
	var rest_world: Vector4 = (parent.global_basis * (_head_rest * _bone_local)).normalized()
	var wanted: Vector4 = rest_world.lerp(world_direction, clampf(weight, 0.0, 1.0))
	if wanted.length() < 0.0001:
		return
	var local_wanted: Vector4 = parent.global_basis.inverse() * wanted.normalized()
	_head.basis = _rotation_between(_bone_local, local_wanted)


func _ease(t: float) -> float:
	var c: float = clampf(t, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)


func _plane_basis(plane: String, angle: float) -> Projection:
	match plane:
		"XY":
			return Basis4D.from_xy(angle)
		"XW":
			return Basis4D.from_xw(angle)
	return Basis4D.from_zx(angle)


## The rotation taking direction [param from] onto direction [param to]. In 4D a
## rotation lives in a PLANE rather than about an axis, so this builds it in the plane
## the two directions span and leaves everything perpendicular untouched.
func _rotation_between(from: Vector4, to: Vector4) -> Projection:
	if from.length() < 0.000001 or to.length() < 0.000001:
		return Projection.IDENTITY
	var a: Vector4 = from.normalized()
	var target: Vector4 = to.normalized()
	var cos_t: float = clampf(a.dot(target), -1.0, 1.0)
	if cos_t > 0.999999:
		return Projection.IDENTITY
	var b: Vector4 = target - a * cos_t
	if b.length() < 0.000001:
		b = _any_perpendicular(a)
	b = b.normalized()
	var sin_t: float = sqrt(maxf(1.0 - cos_t * cos_t, 0.0))
	return Projection(
		_rotate_vector(Vector4(1, 0, 0, 0), a, b, cos_t, sin_t),
		_rotate_vector(Vector4(0, 1, 0, 0), a, b, cos_t, sin_t),
		_rotate_vector(Vector4(0, 0, 1, 0), a, b, cos_t, sin_t),
		_rotate_vector(Vector4(0, 0, 0, 1), a, b, cos_t, sin_t))


func _rotate_vector(x: Vector4, a: Vector4, b: Vector4, cos_t: float, sin_t: float) -> Vector4:
	var ax: float = a.dot(x)
	var bx: float = b.dot(x)
	return x + a * ((cos_t - 1.0) * ax - sin_t * bx) + b * ((cos_t - 1.0) * bx + sin_t * ax)


func _any_perpendicular(a: Vector4) -> Vector4:
	for candidate in [Vector4(0, 1, 0, 0), Vector4(1, 0, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1)]:
		var p: Vector4 = candidate - a * a.dot(candidate)
		if p.length() > 0.001:
			return p
	return Vector4(0, 1, 0, 0)
