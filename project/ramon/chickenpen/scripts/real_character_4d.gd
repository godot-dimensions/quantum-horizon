extends CharacterBody4D

## The `real-controller` third-person controller, rebuilt for 4D.
##
## Ported from `my-own-01/addons/real-controller` in D:\depot\__GODOT. That one is a
## humanoid with a full bone rig - root, hips, spine, chest, neck, head, shoulders, arms
## down to individual fingers, thighs, shins, feet, toes - and a library of baked
## locomotion clips: idle, jump, fall, run_forward, run_backward_left, and so on.
##
## NONE OF THE CLIPS COME ACROSS, and that is the honest difference between this port and
## the original. They animate a Skeleton3D that cannot exist here. What ports is the
## CONTROL: three speeds rather than two, a camera that can drop into first person, a
## tilt limit, and a model that turns smoothly toward where it is going instead of
## snapping. The body is blocks at the same proportions (see block_avatar_4d.gd) and the
## walk cycle in the third scene is procedural rather than recorded.
##
## Against the plush controller next door, this one is deliberately the grounded, human
## one: slower, no bounce, a jump that is a step rather than a leap.

enum CameraMode { THIRD_PERSON, FIRST_PERSON }

@export_group("Movement")
@export_range(0.1, 20.0, 0.1) var speed: float = 5.0
@export_range(0.1, 10.0, 0.1) var walk_speed: float = 2.5
@export_range(0.1, 30.0, 0.1) var sprint_speed: float = 8.0
@export_range(1.0, 20.0, 0.1) var jump_velocity: float = 4.5
@export var can_walk: bool = true
@export_range(0.1, 50.0, 0.1) var acceleration: float = 10.0

@export_group("Camera")
@export var camera_mode: CameraMode = CameraMode.THIRD_PERSON:
	set(value):
		camera_mode = value
		_camera_dirty = true
@export var allow_camera_mode_switch: bool = true
@export_range(0.0, 10.0, 0.1) var third_person_distance: float = 3.5
@export_range(1.0, 20.0, 0.1) var camera_transition_speed: float = 8.0

@export_group("Model")
@export_range(0.1, 50.0, 0.1) var rotation_speed: float = 10.0

@export_group("Readout")
@export var frozen: bool = false

var _facing: float = 0.0
var _camera_dirty: bool = true

@onready var _rig: Node4D = $CameraRig
@onready var _avatar: Node4D = $Avatar
@onready var _label: Label = get_node_or_null("StateLabel")


func _unhandled_input(event: InputEvent) -> void:
	if not allow_camera_mode_switch:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_V:
		camera_mode = CameraMode.FIRST_PERSON if camera_mode == CameraMode.THIRD_PERSON else CameraMode.THIRD_PERSON


func _physics_process(delta: float) -> void:
	_update_camera_mode(delta)
	if frozen:
		return
	if not is_on_floor():
		linear_velocity += get_gravity() * delta
	if Input.is_action_just_pressed(&"move_jump") and is_on_floor():
		linear_velocity.y = jump_velocity
	var wish: Vector4 = _wish_direction()
	_drive(wish, _current_speed(), delta)
	move_and_slide()
	_turn_avatar(wish, delta)
	if _label != null:
		_label.text = "%s   %.1f units/s   w %.2f" % [
			"FIRST" if camera_mode == CameraMode.FIRST_PERSON else "THIRD",
			_horizontal_speed(), position.w]


## Three speeds: walking, ordinary, sprinting. The original binds walk to a held key, so
## holding ALT walks and holding SHIFT sprints.
func _current_speed() -> float:
	if Input.is_key_pressed(KEY_SHIFT):
		return sprint_speed
	if can_walk and Input.is_key_pressed(KEY_ALT):
		return walk_speed
	return speed


func _wish_direction() -> Vector4:
	var local := Vector4(
		Input.get_axis(&"move_left", &"move_right"),
		0.0,
		Input.get_axis(&"move_forward", &"move_back"),
		Input.get_axis(&"move_kata", &"move_ana"))
	if local.length_squared() < 0.0001:
		return Vector4.ZERO
	return (_rig.movement_basis() * local).normalized()


func _drive(wish: Vector4, top: float, delta: float) -> void:
	var rate: float = acceleration * top * delta
	var target: Vector4 = wish * top
	linear_velocity.x = move_toward(linear_velocity.x, target.x, rate)
	linear_velocity.z = move_toward(linear_velocity.z, target.z, rate)
	linear_velocity.w = move_toward(linear_velocity.w, target.w, rate)


## First person is the same rig with the arm wound all the way in, plus hiding the body
## so the player is not looking at the inside of their own head.
func _update_camera_mode(delta: float) -> void:
	if _rig == null:
		return
	var wanted: float = 0.0 if camera_mode == CameraMode.FIRST_PERSON else third_person_distance
	var current: float = float(_rig.get("distance"))
	_rig.set("distance", lerpf(current, wanted, clampf(delta * camera_transition_speed, 0.0, 1.0)))
	_rig.set("collide_with_world", camera_mode == CameraMode.THIRD_PERSON)
	if _avatar != null:
		_avatar.visible = camera_mode == CameraMode.THIRD_PERSON or float(_rig.get("distance")) > 0.6


## Faces where it is walking, turning at a fixed rate rather than snapping. As next door,
## movement along W alone leaves the heading untouched - there is no direction to face in
## a slice you cannot see.
func _turn_avatar(wish: Vector4, delta: float) -> void:
	if absf(wish.x) > 0.001 or absf(wish.z) > 0.001:
		_facing = rotate_toward(_facing, atan2(wish.x, wish.z), rotation_speed * delta)
	_avatar.basis = Basis4D.from_zx(_facing)


func _horizontal_speed() -> float:
	return Vector3(linear_velocity.x, linear_velocity.z, linear_velocity.w).length()
