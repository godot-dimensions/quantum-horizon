extends CharacterBody4D
## Rework of ball_controller.gd for the discrete-rotation MiegakureCamera2.
## Camera-relative movement now uses the FULL x/z/w mix of the camera's
## current basis (only dropping the vertical y component), not a flattened
## pure-x/z projection like v1 - after a 90-degree rotation, "forward" on
## screen should produce motion along w instead of z, which is what
## actually lets the player walk past a wall that's only solid at a
## different w (see miegakure_look_builder_2.gd's wall-with-a-w-gap). This
## is still not a separate "w-translation" control - it is the SAME
## forward/back input, just producing different world-space motion because
## the basis rotated. That distinction matters: Miegakure's own developer
## describes straight w-translation as confusing on its own, but walking
## normally after rotating is the documented, intended way to cross w.
##
## Movement is locked while the camera is mid-rotation
## (MiegakureCamera2.is_transitioning()) - the paper's own recommended
## transition-safety rule.

const SPEED := 4.0

@onready var camera: MiegakureCamera2 = $"../CameraRig"


func _physics_process(delta_time: float) -> void:
	if not is_on_floor():
		linear_velocity += get_gravity() * delta_time
	var direction: Vector4 = Vector4.ZERO
	if not camera.is_transitioning():
		var input_dir := Vector4(
			Input.get_axis("move_left", "move_right"),
			0.0,
			Input.get_axis("move_forward", "move_back"),
			0.0,
		)
		direction = (_flat_camera_basis() * input_dir).normalized()
	if direction:
		linear_velocity.x = direction.x * SPEED
		linear_velocity.z = direction.z * SPEED
		linear_velocity.w = direction.w * SPEED
	else:
		linear_velocity.x = move_toward(linear_velocity.x, 0, SPEED)
		linear_velocity.z = move_toward(linear_velocity.z, 0, SPEED)
		linear_velocity.w = move_toward(linear_velocity.w, 0, SPEED)
	move_and_slide()


## The camera's current x (right) and z (back) columns with only their
## vertical y component dropped - NOT flattened to zero-w like v1, since a
## post-rotation "forward" is supposed to carry a w component now.
func _flat_camera_basis() -> Projection:
	var cam_basis: Projection = camera.global_basis
	var right: Vector4 = cam_basis.x
	right.y = 0.0
	var back: Vector4 = cam_basis.z
	back.y = 0.0
	if right.length() < 0.001 or back.length() < 0.001:
		return Projection.IDENTITY # Camera looking near straight up/down - fall back rather than divide by ~0.
	return Projection(right.normalized(), Vector4(0, 1, 0, 0), back.normalized(), Vector4(0, 0, 0, 1))
