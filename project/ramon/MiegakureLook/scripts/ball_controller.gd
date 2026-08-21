extends CharacterBody4D
## Minimal placeholder avatar for the Miegakure-feel camera test: a sphere
## that never rotates at all - its own basis stays identity forever. Slice
## rotation lives entirely on miegakure_camera.gd instead: per project chat,
## the ball should be able to "move freely" while the camera's own framing
## stays put relative to it, and the WORLD/environment is what visibly
## deforms as the slice rotates - not the character. Since Camera4D's own
## global_basis is what defines the rendered cross-section, putting the
## rotation control there is what actually makes that true, without the
## platform's own collision ever having to rotate underneath the ball (it
## stays large-w/permanent, same convention as hub_gate_4d.gd's w-invariant
## gates).
##
## WASD IS CAMERA-RELATIVE, not world-relative. Since slicing rotates the
## camera's own basis (xw/zw mixing changes how much of world x/z shows up
## in its x/z columns), a world-relative "forward" would visibly drift out
## of alignment with the screen as you rotate - reported directly in chat as
## controls "tangling" while slicing. Flattening the camera's current x/z
## columns onto the ground plane each frame keeps "forward" meaning "away
## from the camera" regardless of how much has been sliced.
##
## Deliberately NOT a momentum/balance physics toy (no RigidBody4D torque) -
## this is a placeholder for "not a walking character", not a physics puzzle
## of its own.

const SPEED := 4.0 # Meters per second.

@onready var camera: Camera4D = $"../CameraRig"


func _physics_process(delta_time: float) -> void:
	if not is_on_floor():
		linear_velocity += get_gravity() * delta_time
	var input_dir := Vector4(
		Input.get_axis("move_left", "move_right"),
		0.0,
		Input.get_axis("move_forward", "move_back"),
		0.0, # No w-translation - see the note above on why slicing is rotation-only for now.
	)
	var direction: Vector4 = (_flat_camera_basis() * input_dir).normalized()
	if direction:
		linear_velocity.x = direction.x * SPEED
		linear_velocity.z = direction.z * SPEED
	else:
		linear_velocity.x = move_toward(linear_velocity.x, 0, SPEED)
		linear_velocity.z = move_toward(linear_velocity.z, 0, SPEED)
	move_and_slide()


## The camera's current x (right) and z (back) columns, flattened onto the
## ground plane (y and w dropped) and renormalized, so WASD always means
## "relative to what's on screen right now" - not the camera's full basis,
## since input_dir only ever has x/z components (y=0, w=0 always here).
func _flat_camera_basis() -> Projection:
	var cam_basis: Projection = camera.global_basis
	var right := Vector4(cam_basis.x.x, 0.0, cam_basis.x.z, 0.0)
	var back := Vector4(cam_basis.z.x, 0.0, cam_basis.z.z, 0.0)
	if right.length() < 0.001 or back.length() < 0.001:
		return Projection.IDENTITY # Camera looking near straight up/down - fall back rather than divide by ~0.
	return Projection(right.normalized(), Vector4(0, 1, 0, 0), back.normalized(), Vector4(0, 0, 0, 1))
