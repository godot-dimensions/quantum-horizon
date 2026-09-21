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

## Starts facing AWAY from the camera, which is PI, not zero.
##
## _turn_avatar sets this to atan2(wish.x, wish.z), so walking forward - which is -Z, the
## way the camera looks - gives PI. Starting at 0 therefore started the character facing
## the exact opposite of the way the first press of W would take it: it stood looking down
## the camera until you moved.
## Cleared while a conversation is open. Gravity and the floor keep working - only the
## player's own intent is switched off - so standing still mid-sentence cannot leave the
## body hovering or half through the ground.
var input_enabled: bool = true

var _facing: float = PI

## How much slower the ana/kata axis is than ordinary movement.
@export_range(0.05, 1.0, 0.05) var w_speed_scale: float = 0.3

@onready var _rig: Node4D = $CameraRig
@onready var _avatar: Node4D = $Avatar
@onready var _label: Label = get_node_or_null("StateLabel")


## Seconds left on the floor. Nothing else in the scene knocks the player down yet; the
## cat is the first thing that fights back.
var _down: float = 0.0


## Put on the ground for a moment. Movement stops, the avatar tips over, and it gets back
## up on its own - there is no state to clear and nothing to forget to undo.
func knock_down(seconds: float) -> void:
	_down = maxf(_down, seconds)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		linear_velocity += get_gravity() * delta
	if _down > 0.0:
		_down -= delta
		linear_velocity.x = move_toward(linear_velocity.x, 0.0, 20.0 * delta)
		linear_velocity.z = move_toward(linear_velocity.z, 0.0, 20.0 * delta)
		linear_velocity.w = move_toward(linear_velocity.w, 0.0, 20.0 * delta)
		move_and_slide()
		# Tipped over, and levelling out again over the last half second rather than
		# snapping upright.
		var tip: float = clampf(_down / 0.5, 0.0, 1.0) * PI * 0.42
		_avatar.basis = Basis4D.from_zx(_facing) * Basis4D.from_yz(tip)
		return
	if input_enabled and Input.is_action_just_pressed(&"move_jump") and is_on_floor():
		linear_velocity.y = jump_velocity
	var wish: Vector4 = _wish_direction()
	var top: float = run_speed
	if input_enabled and Input.is_key_pressed(KEY_SHIFT):
		top = sprint_speed
	elif input_enabled and Input.is_key_pressed(KEY_ALT):
		top = walk_speed
	var rate: float = acceleration * top * delta
	var target: Vector4 = wish * top
	linear_velocity.x = move_toward(linear_velocity.x, target.x, rate)
	linear_velocity.z = move_toward(linear_velocity.z, target.z, rate)
	# The fourth axis moves DELIBERATELY, at a fraction of walking pace.
	#
	# At full speed a short press of the ana key crossed w 0 to 5.9, and the twelve
	# chickens live between w -2.5 and 2.5 - so every one of them was behind a control
	# that shot past all of them at once, and landing on one was luck. It is also truer to
	# what the action is: stepping out of the world you can see is not a stride.
	var w_top: float = top * w_speed_scale
	linear_velocity.w = move_toward(linear_velocity.w, wish.w * w_top,
		acceleration * w_top * delta)
	move_and_slide()
	_turn_avatar(wish, delta)
	if _label != null:
		_label.text = "%s   %.1f units/s   w %.2f" % [
			_gait_name(),
			_horizontal_speed(), position.w]


func _wish_direction() -> Vector4:
	if not input_enabled:
		return Vector4.ZERO
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
