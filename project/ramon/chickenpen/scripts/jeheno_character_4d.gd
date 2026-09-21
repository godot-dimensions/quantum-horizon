extends CharacterBody4D

## The Jeheno third-person controller, rebuilt for 4D.
##
## Ported from `JehenoThirdPersonController` in D:\depot\__GODOT. What carries over is
## its FEEL and its parameters: split jump gravity, a walk/run split, and the two model
## rotation modes. What does not carry over is its architecture - the original spends a
## node and a script per state (idle, walk, run, jump, in-air, ragdoll), and that is a lot
## of scaffolding to port before knowing whether the thing is navigable in 4D at all. The
## states are an enum here, and `state_name` is exported so the same information is on
## screen. Splitting them back out into nodes is a mechanical change if it earns its keep.
##
## THE JUMP IS THE PART WORTH KEEPING VERBATIM. Rather than a velocity and a gravity, it
## takes a HEIGHT and the time to reach it, then derives both - and uses a heavier gravity
## coming down than going up. That asymmetry is most of why the original feels good, and
## it costs nothing to reproduce.
##
## 4D: the rig can be turned through W (hold `rotate_4d`), and `move_ana` / `move_kata`
## walk along it. Movement is measured against the camera rig's frame, so "forward" is
## always what you are looking at, whichever 3D slice that happens to be.

enum State { IDLE, WALK, RUN, JUMP, IN_AIR }

## FOLLOW turns the avatar to face wherever the camera looks, which suits aiming.
## FREE turns it to face where it is actually walking, which suits roaming.
enum RotationMode { FOLLOW_CAMERA, FREE }

@export_group("Movement")
@export var walk_speed: float = 2.2
@export var run_speed: float = 8.5
@export var acceleration: float = 12.0
@export var air_control: float = 0.35

@export_group("Jump")
## The jump is authored as a height and a time, not a velocity - see the note above.
@export var jump_height: float = 2.6
@export var jump_time_to_peak: float = 0.40
@export var jump_time_to_descent: float = 0.30

@export_group("Model")
@export var rotation_mode: RotationMode = RotationMode.FREE
@export var model_rotation_speed: float = 9.0

@export_group("Readout")
@export var state_name: String = "IDLE"

var state: State = State.IDLE

var _facing: float = 0.0

@onready var _rig: Node4D = $CameraRig
@onready var _avatar: Node4D = $Avatar
@onready var _label: Label = get_node_or_null("StateLabel")

# Derived from the three jump numbers, once.
@onready var _jump_velocity: float = (2.0 * jump_height) / jump_time_to_peak
@onready var _jump_gravity: float = (2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)
@onready var _fall_gravity: float = (2.0 * jump_height) / (jump_time_to_descent * jump_time_to_descent)


func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	var wish: Vector4 = _wish_direction()
	var running: bool = Input.is_key_pressed(KEY_SHIFT)
	var speed: float = run_speed if running else walk_speed
	_drive(wish, speed, delta)
	if Input.is_action_just_pressed(&"move_jump") and is_on_floor():
		linear_velocity.y = _jump_velocity
		state = State.JUMP
	move_and_slide()
	_update_state(wish, running)
	_turn_avatar(wish, delta)
	if _label != null:
		_label.text = "%s   speed %.1f   w %.2f" % [state_name, _horizontal_speed(), position.w]


## Heavier coming down than going up. This is the Jeheno jump.
func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	var g: float = _jump_gravity if linear_velocity.y > 0.0 else _fall_gravity
	linear_velocity.y -= g * delta


## Where the player is asking to go, in world terms.
##
## Measured against the CAMERA RIG's frame rather than the body's, so forward is whatever
## the camera faces - including after the view has been turned through W, which is what
## makes the fourth axis navigable rather than just present.
func _wish_direction() -> Vector4:
	var local := Vector4(
		Input.get_axis(&"move_left", &"move_right"),
		0.0,
		Input.get_axis(&"move_forward", &"move_back"),
		Input.get_axis(&"move_kata", &"move_ana"))
	if local.length_squared() < 0.0001:
		return Vector4.ZERO
	return (_rig.movement_basis() * local).normalized()


func _drive(wish: Vector4, speed: float, delta: float) -> void:
	# In the air the player keeps only a fraction of their steering, which is what stops a
	# jump being a free change of direction.
	var authority: float = 1.0 if is_on_floor() else air_control
	var rate: float = acceleration * authority * delta
	var target: Vector4 = wish * speed
	linear_velocity.x = move_toward(linear_velocity.x, target.x, rate * speed)
	linear_velocity.z = move_toward(linear_velocity.z, target.z, rate * speed)
	linear_velocity.w = move_toward(linear_velocity.w, target.w, rate * speed)


func _update_state(wish: Vector4, running: bool) -> void:
	if not is_on_floor():
		state = State.JUMP if linear_velocity.y > 0.0 else State.IN_AIR
	elif wish.length_squared() < 0.0001:
		state = State.IDLE
	else:
		state = State.RUN if running else State.WALK
	state_name = State.keys()[state]


## Turns the avatar, leaving the BODY upright.
##
## Only the X and Z of the movement decide facing. A character walking purely along W has
## no direction to face in the slice you are watching, so it keeps the heading it had -
## turning it would spin the model on the spot for a movement you cannot see.
func _turn_avatar(wish: Vector4, delta: float) -> void:
	var target: float = _facing
	if rotation_mode == RotationMode.FOLLOW_CAMERA:
		target = _rig.yaw
	elif absf(wish.x) > 0.001 or absf(wish.z) > 0.001:
		target = atan2(wish.x, wish.z)
	_facing = rotate_toward(_facing, target, model_rotation_speed * delta)
	_avatar.basis = Basis4D.from_zx(_facing)


func _horizontal_speed() -> float:
	return Vector3(linear_velocity.x, linear_velocity.z, linear_velocity.w).length()
