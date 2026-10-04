extends Node4D

## Kit: the lab player's legs and arms, a walk that opens into a run (Ramon, 4 Oct: "the guy just
## walks very fast, he should run, and very elegantly. remember even the first prince of persia. a
## run is like a jump almost, make it smooth, dynamic. and when he stops running, give him a dynamic
## stop, like stopping the momentum for a short moment"). It takes the place of the pen's block gait
## on the gallery's player only (kit_player.gd swaps it in); the pen and the other labs keep theirs.
##
## THE CLOCK IS DISTANCE, NOT TIME. The cycle moves on by how far the body has actually travelled,
## one cycle every two steps, so a foot on the ground slides back under the hip at exactly the speed
## the ground passes: it is planted by construction, at any speed, through any acceleration.
##
## WALK INTO RUN, one gait blended by speed (`run_blend`):
##   step length       longer with speed, to what these legs can sweep with the hip dropped
##   duty              how much of a cycle each foot is down: 0.62 at a walk (always a foot down),
##                     0.28 at a run, so each step has a flight in it, both feet off the ground
##   the swing         at a walk the foot clears the floor and swings through; at a run the heel
##                     kicks up behind and the knee drives forward before the foot reaches out
##   the body          at a walk a soft rise and fall; at a run it sinks as a foot takes the weight
##                     and rises through the flight, the bound that reads as almost a jump
##   the lean          from the ankles, with the speed, and with the acceleration: forward as it
##                     sets off, back as it stops; carried by a spring, so a stop rocks back and
##                     settles forward past upright for a moment before it stands
##   the arms          relaxed and swinging a little at a walk; at a run, elbows folded near a right
##                     angle, pumping against the opposite leg, the shoulders turning with them
## THE STOP: the body sheds its speed over a few tenths of a second (kit_player sets the
## acceleration); the clock slows with the distance so the legs plant mid-stride, the hips dip and
## the body rocks back, then the feet come together under the hips.
##
## NO class_name (engine_gotchas.md).

@export var avatar_path: NodePath = NodePath("../Avatar")
## The speed the run is fully a run by, and the speed below which it is fully a walk, m/s.
@export var run_from: float = 2.9
@export var walk_until: float = 1.5
## One step's length (half a cycle), m, at a walk and at a run.
@export var step_walk: float = 0.62
@export var step_run: float = 1.12
## How much of a cycle each foot is down at a walk and at a run.
@export_range(0.2, 0.8, 0.01) var duty_walk: float = 0.62
@export_range(0.15, 0.5, 0.01) var duty_run: float = 0.28
## How high the swinging foot rises, m: a walk's clearance, a run's heel kick.
@export var lift_walk: float = 0.07
@export var lift_run: float = 0.34
## The body's rise and fall, m: a walk's bob; a run's sink on landing and rise through the flight.
@export var bob_walk: float = 0.035
@export var sink_run: float = 0.075
@export var float_run: float = 0.07
## Lean from the ankles, radians: at a walk, at a run, and per m/s² of acceleration.
@export var lean_walk: float = 0.02
@export var lean_run: float = 0.13
@export var lean_accel: float = 0.02
## Arms: swing at a walk and a run (radians at the shoulder), elbow fold at a walk and a run.
@export var arm_walk: float = 0.2
@export var arm_run: float = 0.7
@export var elbow_walk: float = 0.18
@export var elbow_run: float = 1.45
## How far the shoulders turn with the arms at a run, radians.
@export var twist_run: float = 0.12
## The lean's spring: stiffness and damping (lower damping, more rock after a stop).
@export var spring_k: float = 110.0
@export var spring_c: float = 12.0
## Seconds for the feet to come together once it has stopped.
@export var settle_seconds: float = 0.42
## The braking stance: how far ahead the leading foot plants and how far back the other pushes, m.
@export var brace_front: float = 0.34
@export var brace_back: float = 0.2
@export_range(0.9, 0.999, 0.001) var reach_fraction: float = 0.985

## Read by others as the block gait's were.
var speed: float = 0.0
var halted: bool = true
var run_blend: float = 0.0

var _avatar: Node4D
var _body: CharacterBody4D
var _thigh: float = 0.39
var _shin: float = 0.346
var _sole: float = 0.11
var _measured: bool = false
var _phase: float = 0.0
var _last_body: Vector4 = Vector4.ZERO
var _avatar_rest: Vector4 = Vector4.ZERO
var _torso_rest: Projection = Projection.IDENTITY
var _shoulder_rest: Array = [Vector4.ZERO, Vector4.ZERO]
var _settle: float = 1.0
var _accel: float = 0.0
var _prev_speed: float = 0.0
var _lean: float = 0.0
var _lean_v: float = 0.0
var _dip: float = 0.0
var _dip_v: float = 0.0
var _airborne: float = 0.0
var _foot_z: Array = [0.0, 0.0]
var _brake: float = 0.0
var _brake_v: float = 0.0
var _lead: int = 0
var _braking: bool = false


func _ready() -> void:
	_body = get_parent() as CharacterBody4D
	_avatar = get_node_or_null(avatar_path) as Node4D
	_last_body = _body.global_position if _body != null else Vector4.ZERO


func _measure() -> void:
	if _avatar == null or _avatar.get("hip_left") == null or _avatar.hip_left == null:
		return
	_thigh = maxf(absf((_avatar.knee_left as Node4D).position.y), 0.05)
	_shin = maxf(absf((_avatar.ankle_left as Node4D).position.y), 0.05) if _avatar.ankle_left != null else _thigh
	for child in (_avatar.ankle_left as Node).get_children():
		if child is MeshInstance4D and String(child.name).begins_with("Boot"):
			var box := (child as MeshInstance4D).mesh as BoxTetraMesh4D
			if box != null:
				_sole = absf((child as Node4D).position.y) + box.size.y * 0.5
	_avatar_rest = _avatar.position
	if _avatar.torso != null:
		_torso_rest = (_avatar.torso as Node4D).basis
	_shoulder_rest = [(_avatar.shoulder_left as Node4D).position, (_avatar.shoulder_right as Node4D).position]
	_measured = true


func _physics_process(delta: float) -> void:
	if _avatar == null or _body == null:
		return
	if not _measured:
		_measure()
		if not _measured:
			return
	var moved: Vector4 = _body.global_position - _last_body
	_last_body = _body.global_position
	var travelled: float = Vector3(moved.x, moved.z, moved.w).length()
	if travelled > 1.0:
		travelled = 0.0   # a teleport, not a step
	var v: Vector4 = _body.linear_velocity
	speed = Vector3(v.x, v.z, v.w).length()
	var on_floor: bool = _body.is_on_floor()
	halted = speed < 0.05 or not on_floor
	_airborne = move_toward(_airborne, 0.0 if on_floor else 1.0, delta * 8.0)
	# The acceleration along the way it moves, smoothed: what the lean and the dip answer to.
	var a_now: float = (speed - _prev_speed) / maxf(delta, 0.0001)
	_prev_speed = speed
	_accel = lerpf(_accel, a_now, clampf(delta * 10.0, 0.0, 1.0))
	run_blend = smoothstep(walk_until, run_from, speed)
	var r: float = run_blend
	var step: float = lerpf(step_walk, step_run, r) * clampf(0.55 + 0.45 * speed / maxf(run_from, 0.1), 0.55, 1.0)
	var duty: float = lerpf(duty_walk, duty_run, r)
	var cycle: float = step * 2.0
	_phase = fposmod(_phase + travelled / maxf(cycle, 0.05), 1.0)
	_settle = move_toward(_settle, 1.0 if speed < 0.25 and on_floor and _brake < 0.35 else 0.0, delta / maxf(settle_seconds, 0.01))
	# Braking from a run: the foot that is ahead becomes the one that plants, and the body braces
	# over it until the speed is gone (sprung, so it eases in and lets go).
	var hard: bool = _accel < -2.5 and speed > 0.15 and on_floor
	if hard and not _braking and speed > walk_until:
		_braking = true
		_lead = 0 if float(_foot_z[0]) >= float(_foot_z[1]) else 1
	if _braking and (speed < 0.08 or _accel > -0.5):
		_braking = false
	var want_brake: float = 1.0 if _braking else 0.0
	_brake_v += ((want_brake - _brake) * spring_k * 1.6 - _brake_v * spring_c * 1.3) * delta
	_brake = clampf(_brake + _brake_v * delta, 0.0, 1.0)

	# The body: up and down, and the spring-carried lean and dip.
	var q: float = fposmod(_phase * 2.0, 1.0)          # where in the current step
	var stance_part: float = minf(duty * 2.0, 1.0)     # the share of a step with a foot down
	var walk_y: float = bob_walk * sin(q * TAU - PI * 0.5) * clampf(speed / walk_until, 0.0, 1.0)
	var run_y: float
	if q < stance_part:
		run_y = -sink_run * sin(PI * q / maxf(stance_part, 0.001))
	else:
		run_y = float_run * sin(PI * (q - stance_part) / maxf(1.0 - stance_part, 0.001))
	var y_off: float = lerpf(walk_y, run_y, r) * (1.0 - _settle)
	var want_lean: float = (lerpf(lean_walk, lean_run, r) * clampf(speed / maxf(run_from, 0.1), 0.0, 1.2)
		+ clampf(_accel * lean_accel, -0.22, 0.12)) * (1.0 - _airborne * 0.5)
	_lean_v += ((want_lean - _lean) * spring_k - _lean_v * spring_c) * delta
	_lean += _lean_v * delta
	# A dip as it brakes hard: the knees take the momentum.
	var want_dip: float = clampf(-_accel / 8.0, 0.0, 1.0) * 0.08 * maxf(r, 0.4) + 0.03 * _brake
	_dip_v += ((want_dip - _dip) * spring_k - _dip_v * spring_c) * delta
	_dip += _dip_v * delta
	_avatar.position = _avatar_rest + Vector4(0.0, y_off - _dip, 0.0, 0.0)
	# Leaned from the ankles, on top of the facing the body has just given it. A positive turn in
	# YZ tips the top forward (the leg solver's measured convention: negative swings a hanging foot
	# forward, so positive swings the head forward).
	_avatar.basis = _avatar.basis * Basis4D.from_yz(_lean)

	# The legs.
	var sweep: float = duty * cycle
	var lift: float = lerpf(lift_walk, lift_run, r)
	_leg(0, _avatar.hip_left, _avatar.knee_left, _avatar.ankle_left, _phase, duty, sweep, lift, r)
	_leg(1, _avatar.hip_right, _avatar.knee_right, _avatar.ankle_right, fposmod(_phase + 0.5, 1.0), duty, sweep, lift, r)

	# The arms, each against the other side's leg, and the shoulders turning with them.
	var moving: float = clampf(speed / 0.6, 0.0, 1.0) * (1.0 - _settle)
	var amp: float = lerpf(arm_walk, arm_run, r) * moving
	var half: float = maxf(sweep * 0.5, 0.05)
	var left_swing: float = clampf(_foot_z[1] / half, -1.2, 1.2) * amp
	var right_swing: float = clampf(_foot_z[0] / half, -1.2, 1.2) * amp
	var fold: float = lerpf(elbow_walk, elbow_run, r * moving)
	_arm(_avatar.shoulder_left, _avatar.elbow_left, left_swing, fold)
	_arm(_avatar.shoulder_right, _avatar.elbow_right, right_swing, fold)
	var twist: float = clampf(_foot_z[0] / half, -1.0, 1.0) * twist_run * r * moving
	if _avatar.torso != null:
		(_avatar.torso as Node4D).basis = _torso_rest * Basis4D.from_zx(twist)
	(_avatar.shoulder_left as Node4D).position = Basis4D.from_zx(twist) * (_shoulder_rest[0] as Vector4)
	(_avatar.shoulder_right as Node4D).position = Basis4D.from_zx(twist) * (_shoulder_rest[1] as Vector4)


## One leg at `p` in its cycle: down for the first `duty` of it, sliding back under the hip by
## `sweep` as the ground passes; up for the rest, swinging forward along a curve that kicks the heel
## up behind and drives the knee through at a run.
func _leg(i: int, hip: Node4D, knee: Node4D, ankle: Node4D, p: float, duty: float, sweep: float, lift: float, r: float) -> void:
	var z: float
	var y: float = 0.0
	var toe: float = 0.0
	if _airborne > 0.5:
		z = 0.12 if i == 0 else -0.05
		y = 0.18
	elif p < duty:
		var u: float = p / maxf(duty, 0.0001)
		z = sweep * 0.5 - sweep * u
		toe = 0.45 * r * smoothstep(0.6, 1.0, u)   # the heel lifting into the push-off (toes down)
	else:
		var u2: float = (p - duty) / maxf(1.0 - duty, 0.0001)
		# A cubic curve from behind to in front: up and back first (the heel kick), then up and
		# forward (the knee drive), then down to the landing.
		var p0 := Vector2(-sweep * 0.5, 0.0)
		var p1 := Vector2(-sweep * 0.5 - 0.22 * r, lift * 1.25)
		var p2 := Vector2(sweep * 0.5 + 0.18 * r, lift * (0.9 + 0.5 * r))
		var p3 := Vector2(sweep * 0.5, 0.0)
		var e: float = u2 * u2 * (3.0 - 2.0 * u2) * 0.6 + u2 * 0.4
		var a1: float = 1.0 - e
		var c: Vector2 = p0 * a1 * a1 * a1 + p1 * 3.0 * a1 * a1 * e + p2 * 3.0 * a1 * e * e + p3 * e * e * e
		z = c.x
		y = c.y
		toe = 0.35 * r * (1.0 - u2) - 0.15 * r * smoothstep(0.75, 1.0, u2)
	# Braking: the leading foot planted ahead, the other pushing from behind on its toes.
	if _brake > 0.001:
		var bz: float = brace_front if i == _lead else -brace_back
		z = lerpf(z, bz, _brake)
		y = lerpf(y, 0.0, _brake)
		toe = lerpf(toe, 0.0 if i == _lead else 0.35, _brake)
	# Standing: the feet come together under the hips.
	z = lerpf(z, 0.0, _settle)
	y = lerpf(y, 0.0, _settle)
	toe = lerpf(toe, 0.0, _settle)
	_foot_z[i] = z
	# Into the hip's frame: the ground is where the body stands, a sole below the ankle.
	var hip_h: float = hip.global_position.y - _body.global_position.y
	var drop: float = hip_h - _sole - y
	# The lean tips the leg's frame forward (its forward axis dips, its up axis leans ahead): the
	# target is measured along those axes, so the foot lands where it should on the level ground.
	var ang: float = _lean
	var tz: float = z * cos(ang) + drop * sin(ang)
	var ty: float = z * sin(ang) - drop * cos(ang)
	_solve(hip, knee, ankle, tz, ty, toe - _lean)


## Two bones in the leg's side plane (the block gait's solver): knee forward.
func _solve(hip: Node4D, knee: Node4D, ankle: Node4D, tz: float, ty: float, foot_pitch: float) -> void:
	var d: float = clampf(sqrt(tz * tz + ty * ty), absf(_thigh - _shin) + 0.01, (_thigh + _shin) * reach_fraction)
	var line: float = atan2(tz, -ty)
	var at_hip: float = acos(clampf((_thigh * _thigh + d * d - _shin * _shin) / (2.0 * _thigh * d), -1.0, 1.0))
	var at_knee: float = acos(clampf((_thigh * _thigh + _shin * _shin - d * d) / (2.0 * _thigh * _shin), -1.0, 1.0))
	var hip_angle: float = -(line + at_hip)
	var knee_angle: float = PI - at_knee
	hip.basis = Basis4D.from_yz(hip_angle)
	knee.basis = Basis4D.from_yz(knee_angle)
	if ankle != null:
		ankle.basis = Basis4D.from_yz(-(hip_angle + knee_angle) + foot_pitch)


## An arm: forward is a negative turn at the shoulder (the hanging hand swings ahead); the forearm
## folds forward and up from the elbow the same way.
func _arm(shoulder: Node4D, elbow: Node4D, swing: float, fold: float) -> void:
	if shoulder == null:
		return
	shoulder.basis = Basis4D.from_yz(-swing)
	if elbow != null:
		elbow.basis = Basis4D.from_yz(-fold - maxf(-swing, 0.0) * 0.25)


## The block gait's carrying call, kept so nothing that calls it breaks; the lab player never carries.
func set_carrying(_carrying: bool, _load: float = 0.0) -> void:
	pass
