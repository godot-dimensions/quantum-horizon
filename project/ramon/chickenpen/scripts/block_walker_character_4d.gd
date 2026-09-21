extends CharacterBody4D

## A third-person character whose walk is PROCEDURAL, not ported and not recorded.
##
## The other two scenes in this folder port a 3D controller and give it a static body.
## This one is the opposite experiment: the rig is built here out of 4D blocks, and the
## walk comes from the same machinery the creatures in project/ramon/Model use - Motion
## Lab's gait clock driving limbs that are moved RIGIDLY, as whole nodes.
##
## RIGID IS THE WHOLE POINT. Measured on those creatures, the three ways to move
## geometry are about an order of magnitude apart per tetrahedron per frame: drawing it
## ~0.15 us, deforming it ~2.5 us, re-lofting it ~11 us. Moving a whole NODE costs
## nothing measurable - Trym's rigged creature runs six solvers and does not register
## above the noise floor. A character built as separate limb nodes can therefore be
## animated for free, which is why this is the version worth trying on a player
## character rather than the skinned one.
##
## The gait clock is fed the character's ACTUAL ground speed, so the legs keep up with
## the player instead of running at a preset cadence. That is what the clock was built
## for: it scales its period with speed rather than holding a fixed one.

@export_group("Movement")
@export var walk_speed: float = 2.4
@export var run_speed: float = 6.0
@export var jump_velocity: float = 4.6
@export_range(0.1, 50.0, 0.1) var acceleration: float = 12.0
@export_range(0.1, 50.0, 0.1) var turn_speed: float = 11.0

@export_group("Gait")
## How far a leg swings fore and aft, in radians.
@export_range(0.0, 1.2, 0.01) var leg_swing: float = 0.55
## Arms swing opposite the legs, and less.
@export_range(0.0, 1.2, 0.01) var arm_swing: float = 0.38
## How far the body rises and falls over a stride. Twice gait frequency: a biped's trunk
## lifts once per STEP, not once per cycle.
@export_range(0.0, 0.3, 0.005) var body_bob: float = 0.05
## How far it leans into a run.
@export_range(0.0, 0.6, 0.01) var run_lean: float = 0.18

# The gait clock reads these two off whatever node it is pointed at. This character is
# that node, which is why they are plain vars rather than exports.
var speed: float = 0.0
var halted: bool = true

var _facing: float = 0.0
var _airborne_blend: float = 0.0

const _GaitController = preload("res://scripts/gait_controller.gd")

@onready var _rig: Node4D = $CameraRig
@onready var _avatar: Node4D = $Avatar
@onready var _label: Label = get_node_or_null("StateLabel")

var _gait: Node
var _torso_rest: Vector4


func _ready() -> void:
	_gait = Node.new()
	_gait.set_script(_GaitController)
	_gait.name = "GaitController"
	_gait.standalone_input = false
	_gait.body_path = NodePath("..")
	add_child(_gait)
	if _gait.has_method("apply_preset"):
		_gait.apply_preset("walk")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		linear_velocity += get_gravity() * delta
	if Input.is_action_just_pressed(&"move_jump") and is_on_floor():
		linear_velocity.y = jump_velocity
	var wish: Vector4 = _wish_direction()
	var top: float = run_speed if Input.is_key_pressed(KEY_SHIFT) else walk_speed
	var rate: float = acceleration * top * delta
	var target: Vector4 = wish * top
	linear_velocity.x = move_toward(linear_velocity.x, target.x, rate)
	linear_velocity.z = move_toward(linear_velocity.z, target.z, rate)
	linear_velocity.w = move_toward(linear_velocity.w, target.w, rate)
	move_and_slide()

	# Hand the clock the speed the character is ACTUALLY making, so the legs match the
	# ground rather than running at whatever cadence the preset was authored at.
	speed = _horizontal_speed()
	halted = speed < 0.05 or not is_on_floor()

	_turn_avatar(wish, delta)
	_pose(delta, top)
	if _label != null:
		_label.text = "%s   %.1f units/s   w %.2f" % [
			"AIRBORNE" if not is_on_floor() else ("WALK" if speed > 0.05 else "IDLE"),
			speed, position.w]


func _wish_direction() -> Vector4:
	var local := Vector4(
		Input.get_axis(&"move_left", &"move_right"),
		0.0,
		Input.get_axis(&"move_forward", &"move_back"),
		Input.get_axis(&"move_kata", &"move_ana"))
	if local.length_squared() < 0.0001:
		return Vector4.ZERO
	return (_rig.movement_basis() * local).normalized()


func _turn_avatar(wish: Vector4, delta: float) -> void:
	if absf(wish.x) > 0.001 or absf(wish.z) > 0.001:
		_facing = rotate_toward(_facing, atan2(wish.x, wish.z), turn_speed * delta)
	_avatar.basis = Basis4D.from_zx(_facing)


## The walk cycle. Four limbs, a bob and a lean, all of it rigid node rotation.
##
## Legs swing half a cycle apart and each arm swings with the OPPOSITE leg, which is what
## makes a walk read as a walk rather than as a shuffle. In the air the whole cycle fades
## out and the legs tuck, so a jump does not look like walking through the sky.
func _pose(delta: float, top: float) -> void:
	if _avatar == null or _avatar.get("hip_left") == null:
		return
	var phase: float = float(_gait.phase_progress)
	var airborne: float = 0.0 if is_on_floor() else 1.0
	_airborne_blend = lerpf(_airborne_blend, airborne, clampf(delta * 8.0, 0.0, 1.0))

	# Amplitude follows speed, so a slow walk does not flail.
	var effort: float = clampf(speed / maxf(top, 0.001), 0.0, 1.0) * (1.0 - _airborne_blend)
	var swing: float = sin(phase * TAU)

	var hip_l: Node4D = _avatar.hip_left
	var hip_r: Node4D = _avatar.hip_right
	var arm_l: Node4D = _avatar.shoulder_left
	var arm_r: Node4D = _avatar.shoulder_right
	# A tuck when airborne: both legs forward, which reads as pulling the knees up.
	var tuck: float = 0.7 * _airborne_blend
	hip_l.basis = Basis4D.from_yz(swing * leg_swing * effort + tuck)
	hip_r.basis = Basis4D.from_yz(-swing * leg_swing * effort + tuck)
	arm_l.basis = Basis4D.from_yz(-swing * arm_swing * effort - tuck * 0.5)
	arm_r.basis = Basis4D.from_yz(swing * arm_swing * effort - tuck * 0.5)

	var torso: Node4D = _avatar.torso
	if torso != null:
		if _torso_rest == Vector4.ZERO:
			_torso_rest = torso.position
		# Twice gait frequency: the trunk lifts once per step, not once per cycle.
		var bob: float = sin(phase * TAU * 2.0) * body_bob * effort
		torso.position = _torso_rest + Vector4(0.0, bob, 0.0, 0.0)
		torso.basis = Basis4D.from_yz(-run_lean * effort)


func _horizontal_speed() -> float:
	return Vector3(linear_velocity.x, linear_velocity.z, linear_velocity.w).length()
