extends Camera4D
class_name MiegakureCamera2
## Rework of miegakure_camera.gd per the technical paper Ramon shared in
## chat, CRITICALLY adapted rather than copied verbatim - see chat history
## for the full reasoning, summarized here:
##
## - ADOPTED: a single DISCRETE 90-degree rotation instead of free
##   continuous 2-plane mouse dragging. Independently corroborated by Marc
##   ten Bosch's own public writing (found in this session's FIRST research
##   pass, before this paper existed): axis-aligned 90-degree rotation is
##   easier to reason about than arbitrary rotation. Also plausibly explains
##   v1's tumbling/tangling bugs by construction - no continuous 2-DOF drag
##   state left to get disoriented by.
## - CORRECTED FOR OUR AXIS CONVENTION: the paper calls this a "Y-W" plane
##   rotation using Marc's own axis labels, where his Y is HORIZONTAL and Z
##   is vertical/gravity. This project's own convention (CLAUDE.md) is the
##   opposite - Y is vertical, X/Z are horizontal, slicing happens via
##   xw/zw. Rotating our vertical y into w would tip gravity into the
##   fourth dimension - a different and much stranger effect than intended.
##   This rotates zw, not yw.
## - REJECTED: the paper's suggested pitch (40-45 deg) and yaw (~45) are
##   explicitly labelled by the paper itself as "visual approximations, not
##   official values." We have better evidence: direct pixel analysis of
##   official screenshots earlier this session (Windmill/Temple/Pillars)
##   measured a much steeper ~55-65 degree pitch. Kept v1's screenshot-
##   derived numbers.
## - REJECTED: trying orthographic first. miegakure.com's own text (fetched
##   directly earlier this session) says the real camera is an ordinary
##   third-person PERSPECTIVE camera, not orthographic.
##
## Position is still derived from the SAME rotating basis used for
## orientation (v1's anti-disappear fix), and rotation is still composed as
## (rotation * tilt), not (tilt * rotation) (v1's anti-tumble fix). Both
## hold regardless of continuous vs. discrete rotation, so both are kept.

const PITCH_DEGREES := 61.0
const YAW_DEGREES := 45.0
## Narrowed toward a "120mm" telephoto feel per Ramon's feedback - a real
## 120mm-on-35mm-equivalent lens is roughly an 18-20 degree FOV. Distance is
## increased to compensate (a narrower FOV needs to be further back to keep
## the same framing) - roughly preserving apparent subject size via
## DISTANCE * tan(FOV/2) staying close to its old value (14 * tan(15deg)).
## Flatter perspective compression reads closer to isometric without
## actually switching to orthographic (still unverified-in-practice in this
## engine - see engine_gotchas.md).
const DISTANCE := 21.5
const FIELD_OF_VIEW_DEGREES := 19.0
const TRANSITION_SECONDS := 0.7 # Paper's own recommended 0.5-1.0s range.

@onready var ball: CharacterBody4D = $"../Ball"

var _local_look_basis: Projection
var _start_angle: float = 0.0
var _target_angle: float = 0.0
var _current_angle: float = 0.0
var _transition_elapsed: float = TRANSITION_SECONDS # Starts at rest, not mid-transition.


func _ready() -> void:
	current = true
	rendering_engine_name = "Cross-section"
	set_field_of_view_3d(deg_to_rad(FIELD_OF_VIEW_DEGREES))
	_local_look_basis = _look_basis(_direction_from_angles(PITCH_DEGREES, YAW_DEGREES))
	_update_transform()


func _input(input_event: InputEvent) -> void:
	if input_event.is_action_pressed(&"ui_cancel"):
		get_tree().quit()
	elif input_event.is_action_pressed(&"rotate_4d") and not is_transitioning():
		_start_angle = _current_angle
		_target_angle = PI * 0.5 if is_equal_approx(_target_angle, 0.0) else 0.0
		_transition_elapsed = 0.0


func _process(delta: float) -> void:
	if _transition_elapsed < TRANSITION_SECONDS:
		_transition_elapsed = minf(_transition_elapsed + delta, TRANSITION_SECONDS)
		var eased := smoothstep(0.0, 1.0, _transition_elapsed / TRANSITION_SECONDS)
		_current_angle = lerp(_start_angle, _target_angle, eased)
	_update_transform()


## Read by ball_controller_2.gd to lock movement input during the rotation -
## the paper's own "transition safety" recommendation: the visible cross-
## section is changing shape underneath the player during this interval, so
## letting input through would be steering blind.
func is_transitioning() -> bool:
	return _transition_elapsed < TRANSITION_SECONDS


## Read by w_readout_2.gd to label which world axis "forward" currently
## means - the mode isn't otherwise obvious from the world deformation
## alone, especially to someone seeing this for the first time.
func get_current_angle_degrees() -> float:
	return rad_to_deg(_current_angle)


func _update_transform() -> void:
	global_basis = Basis4D.from_zw(_current_angle) * _local_look_basis
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
