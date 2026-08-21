extends CharacterBody4D
## v3 of the ball controller. The SAME forward key still produces z-motion before
## the slice rotates and w-motion after it - that part is the whole point and is
## unchanged from v2. What changed is where the movement axes come from.
##
## v2 derived them from the camera basis, which coupled the controls to the
## camera's framing: the 45 degree diorama yaw made screen-forward a 45 degree
## world diagonal while the level is axis-aligned, so holding forward slid the
## ball off the 16 m platform (measured x = -8.20, then an endless fall to
## y = -109). v3 derives them from the SLICE ANGLE alone, so the camera's pitch,
## yaw, distance and FOV are pure framing choices with no gameplay consequence -
## which is what let the screenshot-derived 45 degree diamond come back after an
## interim version had to flatten it to 0 to be playable.
##
## The trade is that screen-up no longer means forward: at 45 degrees the world's
## horizontal axes project onto the two diamond diagonals, so W runs along a
## platform edge. Ordinary isometric-game convention, and WASD lands on the four
## visible platform edges, but it is a deliberate choice rather than a free win.
##
## NEW IN v3: a fall bound. v2 had nothing catching the ball, so a mis-step off
## the 16 m platform was an unrecoverable infinite fall - measured y = -109 and
## still accelerating at the end of a probe run, with the platform long gone
## from the visible cross-section. Falling is now a recoverable mistake.
##
## The respawn goes back to the ORIGINAL spawn, not to the last grounded
## position. Last-grounded sounds friendlier but the position you were last
## grounded at is, by definition, right next to the edge you just fell off, so
## it tends to drop you straight back off again.
##
## The camera is typed as the engine's Camera4D rather than a project class_name
## on purpose - see w_readout_3.gd for the measured failure that motivates it.
## Calling is_transitioning() through that type is an unsafe call and GDScript
## warns about it; that is the same pattern miegakure_look_builder_2.gd already
## uses for its `goal_banner: Control`.

const SPEED := 4.0
## Well below the platform's underside (y = -1.5) but shallow enough that the
## recovery is quick rather than a long silent drop.
const FALL_LIMIT_Y := -12.0

@onready var camera: Camera4D = $"../CameraRig"

var _spawn_position: Vector4 = Vector4.ZERO
var _fall_count: int = 0


func _ready() -> void:
	_spawn_position = global_position


func _physics_process(delta_time: float) -> void:
	if global_position.y < FALL_LIMIT_Y:
		_respawn()
		return
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
		direction = (_slice_movement_basis() * input_dir).normalized()
	if direction:
		linear_velocity.x = direction.x * SPEED
		linear_velocity.z = direction.z * SPEED
		linear_velocity.w = direction.w * SPEED
	else:
		linear_velocity.x = move_toward(linear_velocity.x, 0, SPEED)
		linear_velocity.z = move_toward(linear_velocity.z, 0, SPEED)
		linear_velocity.w = move_toward(linear_velocity.w, 0, SPEED)
	move_and_slide()


## Back to spawn with all four velocity components cleared. The slice rotation
## is deliberately left alone: yanking the camera back to 0 as well would mean a
## fall silently undoes the rotation the player just made, which reads as the
## rotate button having failed rather than as a fall.
func _respawn() -> void:
	_fall_count += 1
	global_position = _spawn_position
	linear_velocity = Vector4.ZERO
	print("BALL: fell off, respawned at spawn (fall %d)" % _fall_count)


## The movement axes for the current slice, built from the slice angle rather than
## from the camera. Strafe is always world x - the axis the zw rotation never
## touches, which is exactly the paper's "X remains X". Forward/back is the axis
## the rotation DOES swap: world -z at theta 0, world -w at theta 90, because
## Basis4D.from_zw carries the z column round to w.
##
## Only the x and z columns are ever consumed (input_dir has zero y and w), but
## the whole basis is built orthonormal anyway so it stays a well-formed transform
## rather than something that happens to work given the current caller.
func _slice_movement_basis() -> Projection:
	var theta: float = camera.get_slice_angle_radians()
	var back := Vector4(0.0, 0.0, cos(theta), sin(theta))
	var ana := Vector4(0.0, 0.0, -sin(theta), cos(theta))
	return Projection(Vector4(1, 0, 0, 0), Vector4(0, 1, 0, 0), back, ana)
