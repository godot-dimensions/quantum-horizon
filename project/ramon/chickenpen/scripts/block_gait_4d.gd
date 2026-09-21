extends Node4D

## A walk cycle for a block avatar: planted feet, bending knees, swinging arms.
##
## WHY FOOT TARGETS AND NOT LIMB WAVING. Swinging a leg back and forth from the hip looks
## like walking for about a second, and then you notice the feet are skating - because
## nothing is holding them still. A real step has two halves: STANCE, where the foot is
## fixed on the ground and the body travels over it, and SWING, where it arcs forward to
## where it will land next. So the cycle produces a foot TARGET, and two-bone IK works
## out what the hip and knee have to do to put the foot there. The knee angle falls out
## of the geometry; it is never authored.
##
## In stance the target slides BACKWARD through the body's own frame at exactly the speed
## the body is moving forward, which leaves the foot standing still in the world. That is
## the whole trick, and it is why the legs stop skating.
##
## Extends Node4D rather than Node, which is not cosmetic: the gait clock resolves its
## body as `Node4D`, so pointing it at a plain Node leaves that null and every read of
## `halted` fails.
##
## Attach as a child of a CharacterBody4D with an avatar built by block_avatar_4d.gd.
## The character needs no code for it: this reads its velocity and whether it is on the
## floor, and drives the avatar's joints directly.

@export var avatar_path: NodePath = NodePath("../Avatar")

## Length of a stride, in units. A step longer than the leg cannot be taken, so this is
## clamped against the leg's own reach when the avatar is measured.
@export var stride_length: float = 0.55

## How high the foot lifts at the top of its arc.
@export var step_height: float = 0.12

## Arms swing opposite the legs, and less.
@export_range(0.0, 1.2, 0.01) var arm_swing: float = 0.60
@export_range(0.0, 1.5, 0.01) var elbow_bend: float = 0.35

## How far the body rises and falls. Twice gait frequency: a biped's trunk lifts once per
## STEP, not once per cycle.
@export_range(0.0, 0.2, 0.005) var body_bob: float = 0.04

## How far it leans into a run.
@export_range(0.0, 0.6, 0.01) var run_lean: float = 0.14

## Speed at which the legs are considered to be running rather than walking, used only to
## scale the lean and the stride.
@export var run_speed: float = 5.0

# The gait clock reads these two off whatever node it is pointed at, which is this one.
var speed: float = 0.0
var halted: bool = true

const _GaitController = preload("res://scripts/gait_controller.gd")

var _gait: Node
var _avatar: Node4D
var _body: CharacterBody4D
var _thigh: float = 0.25
var _shin: float = 0.25
var _hip_height: float = 0.6
var _torso_rest: Vector4
var _airborne: float = 0.0
# Per-leg foot target, carried between frames so stance can hold its ground.
var _plant := [Vector4.ZERO, Vector4.ZERO]
var _lift := [Vector4.ZERO, Vector4.ZERO]
var _was_stance := [false, false]
var _last_body := Vector4.ZERO
var _travelled: float = 0.0
var _measured: bool = false
var _sole: float = 0.0
var _avatar_rest := Vector4.ZERO


func _ready() -> void:
	_body = get_parent() as CharacterBody4D
	_last_body = _body.global_position if _body != null else Vector4.ZERO
	_avatar = get_node_or_null(avatar_path) as Node4D
	_gait = Node.new()
	_gait.set_script(_GaitController)
	_gait.name = "GaitClock"
	_gait.standalone_input = false
	_gait.body_path = NodePath("..")
	add_child(_gait)
	if _gait.has_method("apply_preset"):
		_gait.apply_preset("walk")
	# NOT deferred-and-hope: see _measure.


## Reads the avatar's own build rather than being told it, so the same gait fits the
## chibi, the plush and the human without three sets of numbers.
##
## Called from _physics_process until it succeeds, rather than deferred from _ready. The
## avatar builds its blocks in its OWN _ready, and nothing orders the two: measuring
## first read a torso that did not exist yet, left its rest position at zero, and the
## body-bob then wrote the torso to y=0 every frame - which dropped the head and chest to
## the floor and left the hips and shoulders above them. The legs looked like they came
## out of the head because, relative to the sunken torso, they did.
func _measure() -> void:
	if _avatar == null or _avatar.get("hip_left") == null:
		return
	var hip: Node4D = _avatar.hip_left
	var knee: Node4D = _avatar.knee_left
	_hip_height = hip.position.y
	_thigh = maxf(absf(knee.position.y), 0.01)
	# The shin runs from the knee to the foot; the foot block sits just past it.
	var shin_block: Node4D = null
	for child in knee.get_children():
		if child is MeshInstance4D and String(child.name).begins_with("Shin"):
			shin_block = child as Node4D
	_shin = maxf(absf(shin_block.position.y) * 2.0, 0.01) if shin_block != null else _thigh
	# The IK places the ANKLE. A boot hangs below it, so without this the sole sinks into
	# the ground by its own half-height.
	for child in knee.get_children():
		if child is MeshInstance4D and String(child.name).begins_with("Boot"):
			var box := (child as MeshInstance4D).mesh as BoxTetraMesh4D
			if box != null:
				_sole = maxf(absf((child as Node4D).position.y) + box.size.y * 0.5 - _shin, 0.0)
	# A STRIDE IS LIMITED BY SWEEP, NOT BY LEG LENGTH. A leg of length R whose hip is H
	# off the ground can only put its foot sqrt(R^2 - H^2) forward or back before it goes
	# straight, and a straight leg cannot hold a plant - it gets clamped and dragged.
	# Clamping against R instead let a 0.55 stride be asked of a leg that could sweep
	# 0.25, which is most of why the feet skated.
	var reach_len: float = _thigh + _shin
	var sweep: float = sqrt(maxf(reach_len * reach_len - _hip_height * _hip_height, 0.0))
	stride_length = minf(stride_length, sweep * 2.0 * 0.8)

	# SCALE THE CLOCK TO THIS BODY. The "walk" preset is reference_speed 2.0 with
	# reference_period_sec 4.0 - a four-second cycle, authored for Motion Lab's large
	# quadruped. On a 1.35-unit chibi that is seventeen times too slow, and it is fatal
	# rather than merely wrong: stance then lasts seconds, the body walks metres past a
	# planted foot, and no leg can reach back that far, so the foot gives up and travels
	# along. A stride is two steps, and a step takes stride/speed.
	# The relation is exact, not approximate: a planted foot has to still be under the
	# body when stance ends, so the body must travel exactly ONE STRIDE during stance.
	# stance lasts duty * period, so period = stride / (speed * duty). Using 2*stride/
	# speed instead over-travels by 1/duty - about 20% - and the foot is dragged through
	# the last fifth of every step.
	var pace: float = maxf(run_speed * 0.5, 0.1)
	var duty: float = maxf(float(_gait.duty_factor), 0.1)
	_gait.reference_speed = pace
	_gait.reference_period_sec = maxf(stride_length / (pace * duty), 0.12)
	if _avatar.torso != null:
		_torso_rest = _avatar.torso.position
	_avatar_rest = _avatar.position
	_measured = true


func _physics_process(delta: float) -> void:
	if _avatar == null or _body == null or _avatar.get("hip_left") == null:
		return
	if not _measured:
		_measure()
		if not _measured:
			return
	# MEASURED displacement, not velocity. The character damps its velocity every frame,
	# so linear_velocity is what it is TRYING to do, not what it DID - retreating the
	# foot by that number over-retreats it and the foot skates the other way. The only
	# number that cancels the body's motion is the body's motion.
	var moved: Vector4 = _body.global_position - _last_body
	_last_body = _body.global_position
	_travelled = Vector2(moved.x, moved.z).length()
	speed = Vector3(_body.linear_velocity.x, _body.linear_velocity.z, _body.linear_velocity.w).length()
	halted = speed < 0.05 or not _body.is_on_floor()
	_airborne = lerpf(_airborne, 0.0 if _body.is_on_floor() else 1.0, clampf(delta * 9.0, 0.0, 1.0))

	var phase: float = float(_gait.phase_progress)
	var duty: float = float(_gait.duty_factor)
	var effort: float = clampf(speed / maxf(run_speed, 0.001), 0.0, 1.0)
	# Below a walk the stride shortens rather than the cycle slowing to a crawl.
	var stride: float = stride_length * clampf(speed / maxf(run_speed * 0.6, 0.001), 0.25, 1.0)

	_step(0, _avatar.hip_left, _avatar.knee_left, fposmod(phase, 1.0), duty, stride, delta)
	_step(1, _avatar.hip_right, _avatar.knee_right, fposmod(phase + 0.5, 1.0), duty, stride, delta)

	# Arms take the opposite leg, which is what stops a walk looking like a march.
	#
	# Scaled against a WALK, not a run. Using speed/run_speed meant walking at 2.4 with a
	# run speed of 6 gave 40% of the swing - about ten degrees of shoulder - which reads
	# as arms that do not move at all. A walk should already swing most of the way, with
	# a run adding the rest.
	var arm_effort: float = clampf(speed / maxf(run_speed * 0.45, 0.001), 0.0, 1.15)
	var swing: float = sin(phase * TAU) * arm_swing * arm_effort * (1.0 - _airborne)
	_arm(_avatar.shoulder_left, _avatar.elbow_left, -swing)
	_arm(_avatar.shoulder_right, _avatar.elbow_right, swing)

	# THE PELVIS RISES AT MID-STANCE. This is not decoration: with the hip pinned at one
	# height the standing leg can never extend, and the character walks in a permanent
	# 42-degree crouch. Lifting the whole avatar at twice gait frequency - once per step -
	# straightens the supporting leg exactly when it should be straightest.
	var bob: float = sin(phase * TAU * 2.0) * body_bob * effort * (1.0 - _airborne)
	_avatar.position = _avatar_rest + Vector4(0.0, maxf(bob, 0.0), 0.0, 0.0)
	if _avatar.torso != null:
		_avatar.torso.position = _torso_rest
		_avatar.torso.basis = Basis4D.from_yz(-run_lean * effort)


## One leg, one point in its cycle.
##
## THE FOOT TARGET LIVES IN WORLD SPACE. This is the standard way procedural locomotion
## is built, and two failed attempts here are why: holding the target in the body's frame
## and hand-correcting it for the body's motion needs the correction to be exactly right
## every frame, and it never is. Retreating by velocity over-retreats, because a character
## damps its velocity and does not travel as far as it meant to. Retreating by measured
## displacement is closer but still accumulates. Pinning the target to a POINT ON THE
## GROUND and re-deriving the joint angles from wherever the body now is cannot drift:
## the foot is planted by construction, not by arithmetic that has to come out even.
##
## STANCE: the target is the spot where the foot landed, and stays there while the body
## walks over it. SWING: it travels from where it lifted to where it will next land,
## rising to step_height on the way.
func _step(index: int, hip: Node4D, knee: Node4D, local_phase: float, duty: float,
		stride: float, _delta: float) -> void:
	var reach: float = (_thigh + _shin) * 0.97
	var hip_world: Vector4 = hip.global_position
	# THE ANKLE'S HEIGHT IS SET BY THE FLOOR, NOT BY THE LEG. It sits one sole above the
	# ground, so the drop from hip to ankle is whatever that distance happens to be -
	# clamped only if the leg genuinely cannot reach that far. Subtracting the sole from
	# a drop that had already been clamped to the leg's reach did the opposite: raising
	# the hip lifted the TARGET instead of straightening the leg, which is why standing
	# taller changed nothing and then made the feet hover.
	var forward: Vector4 = _avatar.global_basis * Vector4(0.0, 0.0, 1.0, 0.0)
	var drop: float = clampf(hip_world.y - _body.global_position.y - _sole, 0.05, reach)
	var ground: Vector4 = hip_world - Vector4(0.0, drop, 0.0, 0.0)
	var in_stance: bool = local_phase < duty and _airborne < 0.5
	var target: Vector4

	if _airborne >= 0.5:
		# Tucked, and moving with the body rather than pinned to anything.
		target = ground + forward * 0.15 + Vector4(0.0, drop * 0.35, 0.0, 0.0)
		_was_stance[index] = false
	elif in_stance:
		if not _was_stance[index]:
			# Touchdown. From here the foot belongs to the ground, not to the body.
			_plant[index] = ground + forward * (stride * 0.5)
		target = _plant[index]
		_was_stance[index] = true
	else:
		var t: float = (local_phase - duty) / maxf(1.0 - duty, 0.0001)
		var eased: float = t * t * (3.0 - 2.0 * t)
		if _was_stance[index]:
			_lift[index] = _plant[index]
			_was_stance[index] = false
		# Where it will land: ahead of where the body is NOW, recomputed every frame so
		# the step leads a body that is still moving.
		var landing: Vector4 = ground + forward * (stride * 0.5)
		target = _lift[index].lerp(landing, eased) + Vector4(0.0, sin(t * PI) * step_height, 0.0, 0.0)

	# Into the hip's own frame, which is what the solver works in.
	var local: Vector4 = _avatar.global_basis.inverse() * (target - hip_world)
	_solve_leg(hip, knee, local.z, local.y)


## Closed-form two-bone IK in the sagittal plane.
##
## The leg is a triangle: thigh, shin, and the line from hip to foot. Knowing all three
## lengths gives every angle by the cosine rule, so nothing here is iterative and nothing
## can fail to converge. The knee is placed so it bends FORWARD, like a human's - the
## other root of the same triangle bends it backwards, like a bird's.
func _solve_leg(hip: Node4D, knee: Node4D, target_z: float, target_y: float) -> void:
	var d: float = clampf(sqrt(target_z * target_z + target_y * target_y),
		absf(_thigh - _shin) + 0.01, _thigh + _shin - 0.01)
	# Angle of the hip-to-foot line, measured from straight down.
	var line: float = atan2(target_z, -target_y)
	# Angle between that line and the thigh.
	var at_hip: float = acos(clampf((_thigh * _thigh + d * d - _shin * _shin) / (2.0 * _thigh * d), -1.0, 1.0))
	# Interior angle at the knee; PI minus it is how far the shin folds back.
	var at_knee: float = acos(clampf((_thigh * _thigh + _shin * _shin - d * d) / (2.0 * _thigh * _shin), -1.0, 1.0))
	# NEGATED, and measured rather than reasoned: asking this solver for a foot 0.25
	# FORWARD put it 0.18 BACKWARD, because Basis4D.from_yz turns the opposite way to
	# what the maths above assumes. With the sign wrong the swing added to the body's
	# motion instead of cancelling it, which is exactly what a skating leg looks like.
	hip.basis = Basis4D.from_yz(-(line + at_hip))
	knee.basis = Basis4D.from_yz(PI - at_knee)


## Arms swing from the shoulder with the elbow trailing, which is enough to read as an
## arm rather than a plank.
func _arm(shoulder: Node4D, elbow: Node4D, swing: float) -> void:
	if shoulder == null:
		return
	shoulder.basis = Basis4D.from_yz(swing)
	if elbow != null:
		elbow.basis = Basis4D.from_yz(-absf(swing) * elbow_bend - elbow_bend * 0.4)
