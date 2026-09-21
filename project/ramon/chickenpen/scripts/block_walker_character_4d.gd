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
## The walk itself lives in block_gait_4d.gd, a sibling node, so all three scenes in this
## folder share one cycle rather than three copies of it. This script only moves the body
## and turns it; the gait node reads the velocity that results and works the legs.

@export_group("Movement")
## RUNNING IS THE DEFAULT. A character this size covering ground at a stroll is dull to
## play, so no modifier means a run; hold ALT to walk and SHIFT to sprint.
##
## The numbers are chosen against the BODY, not picked for feel. Cadence is
## stride / (speed * duty), so at a 0.78 stride these give roughly 1.1 steps a second
## walking, 2.3 running and 3.2 sprinting. The previous 6.0 "run" needed 4.6 steps a
## second on 0.36-unit legs, which is why it looked frantic: it was a sprint being
## called a run.
@export var run_speed: float = 3.0
@export var walk_speed: float = 1.4
@export var sprint_speed: float = 4.2
@export var jump_velocity: float = 4.6
@export_range(0.1, 50.0, 0.1) var acceleration: float = 12.0
@export_range(0.1, 50.0, 0.1) var turn_speed: float = 11.0

var _facing: float = 0.0

@onready var _rig: Node4D = $CameraRig
@onready var _avatar: Node4D = $Avatar
@onready var _label: Label = get_node_or_null("StateLabel")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		linear_velocity += get_gravity() * delta
	if Input.is_action_just_pressed(&"move_jump") and is_on_floor():
		linear_velocity.y = jump_velocity
	var wish: Vector4 = _wish_direction()
	var top: float = run_speed
	if Input.is_key_pressed(KEY_SHIFT):
		top = sprint_speed
	elif Input.is_key_pressed(KEY_ALT):
		top = walk_speed
	var rate: float = acceleration * top * delta
	var target: Vector4 = wish * top
	linear_velocity.x = move_toward(linear_velocity.x, target.x, rate)
	linear_velocity.z = move_toward(linear_velocity.z, target.z, rate)
	linear_velocity.w = move_toward(linear_velocity.w, target.w, rate)
	move_and_slide()
	_turn_avatar(wish, delta)
	if _label != null:
		_label.text = "%s   %.1f units/s   w %.2f" % [
			_gait_name(),
			_horizontal_speed(), position.w]


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


func _horizontal_speed() -> float:
	return Vector3(linear_velocity.x, linear_velocity.z, linear_velocity.w).length()


func _gait_name() -> String:
	if not is_on_floor():
		return "AIRBORNE"
	var moving: float = _horizontal_speed()
	if moving < 0.05:
		return "IDLE"
	if moving > (run_speed + sprint_speed) * 0.5:
		return "SPRINT"
	if moving < (walk_speed + run_speed) * 0.5:
		return "WALK"
	return "RUN"
