extends Camera4D
## v3 of the Miegakure-feel camera. Identical to miegakure_camera_2.gd except
## for YAW_DEGREES, and for deliberately NOT declaring a class_name - both
## changes are fixes for problems that were measured in play on 2026-08-19, not
## preferences. See project/ramon/follow_up/miegakure_look.md for the numbers.
##
## THE YAW STORY, because this constant has now been changed twice. v2 kept a 45
## degree yaw for the "diamond" diorama framing taken from the official
## screenshots. Because v2 derived MOVEMENT from the camera basis, that made
## screen-forward a 45 degree WORLD diagonal while the level is axis-aligned.
## Measured consequences: holding forward into the wall slid the ball along x
## until it left the 16 m platform (x = -8.20), and at 90 degrees forward moved
## in -x as much as -w, so the ball walked off the platform and fell forever
## (y = -25 after 2.5 s, still falling at y = -109). The w-gap was only
## reachable by holding forward+right, which nothing in the game teaches.
##
## The first v3 fix set this to 0, which made the y-dropped camera basis
## axis-aligned and solved the movement bug - and threw away the diorama look in
## the process. That was a false either/or. The camera's yaw and the movement
## axes only have to agree if movement is DERIVED from the camera, and it no
## longer is: ball_controller_3.gd now builds its movement basis from the slice
## angle alone (see _slice_movement_basis there). So the yaw is back to 45 and is
## now free to be whatever framing looks best - it has no gameplay consequence
## at all.
##
## What this costs, stated plainly: at 45 degrees the world's two horizontal axes
## project onto the screen as the two diagonals of the diamond, so W does not move
## the ball straight up the screen - it moves it along a platform edge. That is
## the ordinary isometric-game convention and it is coherent (WASD maps to the
## four visible platform edges), but it is a real change from "screen-up means
## forward". Set YAW_DEGREES back to 0 if you'd rather have screen-aligned
## controls; nothing else has to change either way now.
##
## Carried over from v2 unchanged because both are still load-bearing:
## - Position is derived from the SAME rotating basis as the orientation, so the
##   ball can never drift out of the visible cross-section.
## - The rotation is composed as (rotation * tilt), never (tilt * rotation),
##   which would read as the whole scene tumbling.

const PITCH_DEGREES := 61.0
## 45, the screenshot-derived diamond framing, same as v1 and v2. Safe to change
## freely: movement no longer reads this. See the yaw story above.
const YAW_DEGREES := 45.0
const DISTANCE := 21.5
const FIELD_OF_VIEW_DEGREES := 19.0
const TRANSITION_SECONDS := 0.7

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


## Read by ball_controller_3.gd to lock movement input during the rotation - the
## visible cross-section is changing shape underneath the player, so letting
## input through would be steering blind.
func is_transitioning() -> bool:
	return _transition_elapsed < TRANSITION_SECONDS


## Read by w_readout_3.gd to label which world axis "forward" currently means.
func get_current_angle_degrees() -> float:
	return rad_to_deg(_current_angle)


## Read by ball_controller_3.gd to build its movement basis. This - not the
## camera's own basis - is what movement is derived from, which is why the pitch,
## yaw, distance and FOV above are all free to be chosen purely for framing.
func get_slice_angle_radians() -> float:
	return _current_angle


func _update_transform() -> void:
	global_basis = Basis4D.from_zw(_current_angle) * _local_look_basis
	global_position = ball.global_position + global_basis * Vector4(0, 0, DISTANCE, 0)


## Unit vector from a pitch (above horizontal) and yaw (compass heading) - same
## spherical-to-Cartesian convention hub_sun_4d.gd uses for the sun.
func _direction_from_angles(pitch_degrees: float, yaw_degrees: float) -> Vector4:
	var pitch := deg_to_rad(pitch_degrees)
	var yaw := deg_to_rad(yaw_degrees)
	var horizontal := cos(pitch)
	return Vector4(sin(yaw) * horizontal, sin(pitch), cos(yaw) * horizontal, 0.0)


## Builds a fixed orthonormal basis whose local -z looks back along [param
## direction] - same Gram-Schmidt approach hub_sun_4d.gd uses to aim a light.
## At yaw 0 this stays well-conditioned: the direction has no x component, so
## the world-x seed passes through untouched as the x axis.
func _look_basis(direction: Vector4) -> Projection:
	var z_axis := direction.normalized()
	var world_up := Vector4(0.0, 1.0, 0.0, 0.0)
	var y_axis := (world_up - z_axis * z_axis.dot(world_up)).normalized()
	var world_x := Vector4(1.0, 0.0, 0.0, 0.0)
	var x_axis := (world_x - z_axis * z_axis.dot(world_x) - y_axis * y_axis.dot(world_x)).normalized()
	var w_axis := Vector4(0.0, 0.0, 0.0, 1.0)
	return Projection(x_axis, y_axis, z_axis, w_axis)
