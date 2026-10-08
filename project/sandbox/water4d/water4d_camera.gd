extends Camera4D
## Free-flying camera with 3D look and 4D slice turning.
##
## Lifted from `sandbox/voxel_demo/voxel_demo_4d.gd`, which is the sandbox scenes' fly
## camera, and made a standalone Camera4D script so this scene does not have to carry a
## whole demo along with it. The bindings are that scene's, which are in turn the project's:
## WASD and Space/Shift to move, E and Q through W, mouse to look, right-drag to turn the
## slice (`rotate_4d`, the same action `player/player.gd` uses).
##
## THE SLICE ROTATION IS COMPOSED ON THE LEFT, and that is load-bearing rather than taste.
## water4d_surface.gd needs world up to stay inside the slice, which holds exactly when the
## basis's w column has no y component. Yaw and pitch never touch w, so with the slice turn
## applied last - in WORLD xw and zw - the w column is the slice rotation's own, and those
## two planes leave y alone. Compose the slice turn on the right instead and pitch mixes the
## w column's z into y, world up tilts out of the slice, and the ocean shears.
## `MiegakureLook/scripts/miegakure_camera.gd` found the same thing from the other end.

const MOVE_SPEED := 14.0
const SPRINT_MULTIPLIER := 3.0
const LOOK_SENSITIVITY := 0.004
const SLICE_SENSITIVITY := 0.004
const PITCH_LIMIT := 1.5

var _yaw: float = 0.0
var _pitch: float = -0.25
var _slice_x: float = 0.0
var _slice_z: float = 0.0


func _ready() -> void:
	current = true
	rendering_engine_name = "Cross-section"
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		if Input.is_action_pressed(&"rotate_4d"):
			_slice_x -= motion.relative.x * SLICE_SENSITIVITY
			_slice_z += motion.relative.y * SLICE_SENSITIVITY
		else:
			_yaw -= motion.relative.x * LOOK_SENSITIVITY
			_pitch = clampf(_pitch - motion.relative.y * LOOK_SENSITIVITY, -PITCH_LIMIT, PITCH_LIMIT)
		_apply()
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		match key.keycode:
			KEY_ESCAPE:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if Input.mouse_mode
						== Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED)
			KEY_R:
				_slice_x = 0.0
				_slice_z = 0.0
				_apply()


func _process(delta: float) -> void:
	var move := Vector4.ZERO
	if Input.is_key_pressed(KEY_W):
		move.z -= 1.0
	if Input.is_key_pressed(KEY_S):
		move.z += 1.0
	if Input.is_key_pressed(KEY_A):
		move.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		move.x += 1.0
	if Input.is_key_pressed(KEY_SPACE):
		move.y += 1.0
	if Input.is_key_pressed(KEY_CTRL):
		move.y -= 1.0
	# E and Q step through the fourth axis, as everywhere else in the project.
	if Input.is_key_pressed(KEY_E):
		move.w += 1.0
	if Input.is_key_pressed(KEY_Q):
		move.w -= 1.0
	if move == Vector4.ZERO:
		return
	var speed: float = MOVE_SPEED
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= SPRINT_MULTIPLIER
	# Space and Ctrl are WORLD up and down rather than camera up and down, so rising while
	# looking at the horizon does not also drift you forwards.
	var lift: float = move.y
	move.y = 0.0
	var step: Vector4 = basis * move
	step.y += lift
	if step.length() > 0.0001:
		position += step.normalized() * (speed * delta)


func _apply() -> void:
	var slice: Projection = Basis4D.from_xw(_slice_x) * Basis4D.from_zw(_slice_z)
	basis = Basis4D.orthonormalized(slice * Basis4D.from_zx(_yaw) * Basis4D.from_yz(_pitch))


## How far the slice has been turned, in degrees, for the HUD.
func slice_turn_degrees() -> Vector2:
	return Vector2(rad_to_deg(_slice_x), rad_to_deg(_slice_z))
