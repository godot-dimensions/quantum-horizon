extends Camera4D
## Fixed-relative-position third-person camera for the Miegakure-feel test.
## Per project chat: the camera's framing should stay put relative to the
## ball (which moves freely and never rotates - see ball_controller.gd),
## while mouse motion rotates the SLICE itself, i.e. this camera's own
## global_basis - since Camera4D's own basis is what defines the rendered
## cross-section, this is what makes the world visibly deform/appear/
## disappear as you drag, without ever touching the platform's own
## transform (it stays large-w/permanent, so nothing physically moves
## underneath the ball).
##
## THE BALL MUST NEVER DISAPPEAR. Position is deliberately computed as
## `ball.global_position + global_basis * Vector4(0, 0, DISTANCE, 0)` -
## i.e. DISTANCE along the camera's OWN current z-axis, not a constant
## world-space offset. That guarantees the ball sits at exactly local-w=0
## relative to the camera at all times, no matter how far it's rotated.
## An earlier version used a fixed world-space offset with position never
## rotating while orientation did - since that offset has nonzero x/z and
## the rotated basis.w picks up x/z components from slicing, their dot
## product drifted as you rotated, making the ball wander out of the
## visible cross-section even though it never moved. Keep position and
## orientation derived from the SAME basis or this bug comes back.
##
## The fixed local look angle is a diagonal (corner) approach, not straight
## behind - so the square platform reads as a rotated diamond, matching the
## official Miegakure screenshots analysed in chat (Windmill/Temple/
## Pillars), rather than head-on. Steep ~60 degree pitch and narrow FOV for
## the same "pulled-back diorama" reason.

const PITCH_DEGREES := 61.0 # Above horizontal.
const YAW_DEGREES := 45.0 # Compass heading of the approach - the "diamond" angle.
const DISTANCE := 14.0 # Meters from the ball - pulled back further to stop platform edges/props clipping out of frame.
const FIELD_OF_VIEW_DEGREES := 30.0
const MOUSE_SENSITIVITY := 0.002

@onready var ball: CharacterBody4D = $"../Ball"

var _local_look_basis: Projection
var _slice_rotation: Projection = Projection.IDENTITY


func _ready() -> void:
	current = true
	rendering_engine_name = "Cross-section"
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	set_field_of_view_3d(deg_to_rad(FIELD_OF_VIEW_DEGREES))
	_local_look_basis = _look_basis(_direction_from_angles(PITCH_DEGREES, YAW_DEGREES))
	_update_transform()


func _input(input_event: InputEvent) -> void:
	if input_event.is_action_pressed(&"ui_cancel"):
		get_tree().quit()
	elif input_event is InputEventMouseMotion:
		var rel: Vector2 = input_event.relative * MOUSE_SENSITIVITY
		# Composed on the LEFT (world-space xw/zw planes), not the right -
		# see the note above the class on why the opposite order made the
		# whole tilted view scramble into what looked like a spin instead of
		# a clean slice change. Rotating around the WORLD's own xw/zw planes
		# first, with the fixed diorama tilt applied on top afterward, keeps
		# the rotation aligned with the platform's own axes.
		var rotated: Projection = Basis4D.from_xw(-rel.x) * Basis4D.from_zw(rel.y) * _slice_rotation
		rotated.y = Vector4(0, 1, 0, 0)
		_slice_rotation = Basis4D.orthonormalized(rotated)


func _process(_delta: float) -> void:
	_update_transform()


func _update_transform() -> void:
	global_basis = _slice_rotation * _local_look_basis
	global_position = ball.global_position + global_basis * Vector4(0, 0, DISTANCE, 0)


## Unit vector from a pitch (above horizontal) and yaw (compass heading) -
## same spherical-to-Cartesian convention hub_sun_4d.gd uses for the sun.
func _direction_from_angles(pitch_degrees: float, yaw_degrees: float) -> Vector4:
	var pitch := deg_to_rad(pitch_degrees)
	var yaw := deg_to_rad(yaw_degrees)
	var horizontal := cos(pitch)
	return Vector4(sin(yaw) * horizontal, sin(pitch), cos(yaw) * horizontal, 0.0)


## Builds a fixed orthonormal basis whose local -z looks back along [param
## direction] toward whatever it will be added to - same Gram-Schmidt
## approach hub_sun_4d.gd uses to aim a light, applied here to aim a camera.
func _look_basis(direction: Vector4) -> Projection:
	var z_axis := direction.normalized()
	var world_up := Vector4(0.0, 1.0, 0.0, 0.0)
	var y_axis := (world_up - z_axis * z_axis.dot(world_up)).normalized()
	var world_x := Vector4(1.0, 0.0, 0.0, 0.0)
	var x_axis := (world_x - z_axis * z_axis.dot(world_x) - y_axis * y_axis.dot(world_x)).normalized()
	var w_axis := Vector4(0.0, 0.0, 0.0, 1.0)
	return Projection(x_axis, y_axis, z_axis, w_axis)
