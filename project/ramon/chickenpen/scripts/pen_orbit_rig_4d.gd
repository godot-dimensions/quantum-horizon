extends Node4D

## A third-person orbit camera for 4D, shared by every controller in this folder.
##
## WHY THIS EXISTS AT ALL. Both 3D controllers being ported here hang their camera on a
## SpringArm3D: a node that casts a ray backwards from the character and pulls the camera
## in when it hits something. There is no SpringArm4D, and there is no Camera4D equivalent
## of it either, so the arm is rebuilt here - the orbit, the clamp, the zoom and the
## pull-in are all done by hand against PhysicsServer4D.
##
## WHAT IS DIFFERENT IN 4D. A 3D orbit needs two angles, yaw and pitch. This needs four:
## the same two, plus the two W-planes that decide which 3D CROSS-SECTION of the 4D world
## you are looking at. Holding `rotate_4d` and moving the mouse turns those instead of
## yaw and pitch, exactly as the project's first-person player does - so the same muscle
## memory works, and the character can walk "sideways" out of the slice it is standing in.
##
## The rig is a CHILD of the character body and carries all the orientation; the body
## itself stays upright and unrotated. That is how both source controllers are built, and
## it is what lets the avatar turn to face where it is going while the camera looks
## wherever the player points it.

## Degrees the camera sits above the character's feet, as the point it orbits.
@export var pivot_height: float = 1.1

## How far back the camera sits. Zoom moves this between the two limits.
@export var distance: float = 5.0
@export var min_distance: float = 1.5
@export var max_distance: float = 14.0
@export var zoom_speed: float = 1.2

@export_range(0.0, 0.02, 0.0001) var mouse_sensitivity: float = 0.005

## Pitch limits, in degrees. Asymmetric on purpose: a third-person camera wants to look
## down at the character far more than it wants to look up at its feet.
@export_range(-89.0, 0.0, 0.5) var pitch_min_degrees: float = -75.0
@export_range(0.0, 89.0, 0.5) var pitch_max_degrees: float = 25.0

## Pull the camera in when something is between it and the character - the spring arm's
## whole job. Costs one raycast a frame.
@export var collide_with_world: bool = true

## How much of the pulled-in distance to keep clear of the obstruction.
@export var collision_margin: float = 0.3

@export_group("The way back")
## R puts you back on the default slice: both rotations to zero and your w to zero.
##
## THE BRIEF DOES NOT FORBID THIS, though it is easy to think it does. Item 58 - "do not
## make the locator an autopilot" - asks to "leave enough interpretation to make W-search
## meaningful" and to "avoid a giant exact world marker that removes all discovery unless
## testing shows it is needed for comprehension". That is about the instrument that points
## you at a CHICKEN. This points at nothing; it undoes your own rotations and puts you back
## where you began, which is the opposite of being led to a target.
##
## What it protects is the willingness to rotate at all. Getting lost in W is not a skill
## the brief is testing, it is the thing that stops the testing happening - and a way back
## is what makes turning the slice far enough to be useful feel safe to try.
##
## It does not touch where you stand or which way you look. Only the fourth axis.
@export var home_key: Key = KEY_R
## Taken over a moment rather than snapped, so the level diagram shows the quad coming
## flat and you can see what the key did.
@export_range(0.05, 3.0, 0.05) var home_seconds: float = 0.45

var yaw: float = 0.0
var pitch: float = -0.15

var _slice_xw: float = 0.0
var _slice_zw: float = 0.0
var _zoom_target: float = 0.0
## Seconds left on the way back to the default slice. Zero means nothing is happening.
var _homing: float = 0.0

@onready var _pitch_node: Node4D = $Pitch
@onready var _camera: Camera4D = $Pitch/Camera4D


func _ready() -> void:
	_zoom_target = distance
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	# ESCAPE HAS TO GET YOU OUT. These scenes capture the mouse on the first frame and
	# nothing gave it back, so a running scene could not be closed without killing the
	# window. First press frees the cursor, second quits.
	if event.is_action_pressed(&"ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			get_tree().quit()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).keycode == home_key \
			and not Input.is_key_pressed(KEY_CTRL):
		# Ctrl+R restarts the whole scene and is somebody else's key. Plain R is the slice.
		_homing = home_seconds
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed:
		# Clicking back into the window recaptures it.
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and event.button_index == MOUSE_BUTTON_LEFT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
		# Wheel zoom. Read from the raw event rather than an action, because the project's
		# input map has no wheel bindings and adding them would change every other scene.
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_target = clampf(_zoom_target - zoom_speed, min_distance, max_distance)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_target = clampf(_zoom_target + zoom_speed, min_distance, max_distance)
	elif event is InputEventMouseMotion:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			return
		var motion: Vector2 = event.relative * mouse_sensitivity
		if Input.is_action_pressed(&"rotate_4d"):
			# Taking hold of the slice cancels the trip home. Fighting the player for
			# control of the same two angles is worse than either behaviour alone.
			_homing = 0.0
			# Turning the view through W: this changes which slice of the 4D world is
			# visible, not which way the character faces within it.
			_slice_xw -= motion.x
			_slice_zw += motion.y
		else:
			# MINUS, and this was tried both ways with a controller in hand. Plus is what
			# the geometry suggests - the camera sits at +Z of a from_zx(yaw) frame and
			# looks BACK at the player, so plus swings the arm towards +X and the view
			# turns right - and it played worse. Minus is what is here because it is the
			# one that felt right, not because of an argument about signs. Do not "fix"
			# it by reading the maths; flip it, play it, and see.
			yaw -= motion.x
			pitch = clampf(pitch - motion.y,
				deg_to_rad(pitch_min_degrees), deg_to_rad(pitch_max_degrees))
		_apply()


func _physics_process(delta: float) -> void:
	if _homing > 0.0:
		_go_home(delta)
	distance = lerpf(distance, _zoom_target, clampf(delta * 10.0, 0.0, 1.0))
	position = Vector4(0.0, pivot_height, 0.0, 0.0)
	_place_camera()


## Yaw and the two W-planes live on the rig; pitch lives on a child.
##
## Splitting them is not tidiness. Pitch has to be applied AFTER yaw and must not feed
## back into it, and keeping it on its own node means the rig's own basis stays a clean
## horizontal frame that movement can be measured against - the same reason the project's
## first-person player keeps pitch on its head node.
##
## THE SLICE ROTATIONS GO OUTSIDE THE YAW, and the order is the whole point.
##
## Built the other way round - from_zx(yaw) first, then the W-planes - yaw is the
## outermost rotation, so it turns the slice normal along with everything else and simply
## LOOKING AROUND re-cuts the world. Measured before the swap: with xw at 20 degrees, a
## full look-around swung the slice normal 40 degrees and moved the slice's height over
## the pen's far corner from -5.66 to +5.66. You could line up on a chicken, turn to walk
## at it, and lose the alignment by turning.
##
## With the slice rotations outermost, yaw's own w column is (0, 0, 0, 1) - from_zx only
## touches x and z - so the product's w column is the slice rotations' alone and cannot
## depend on yaw at all. Measured after: 0.0 degrees of swing at every slice rotation
## tried, and the view still yaws by exactly the angle asked for.
func _apply() -> void:
	var frame: Projection = Projection.IDENTITY
	if not is_zero_approx(_slice_xw):
		frame *= Basis4D.from_xw(_slice_xw)
	if not is_zero_approx(_slice_zw):
		frame *= Basis4D.from_zw(_slice_zw)
	frame *= Basis4D.from_zx(yaw)
	basis = Basis4D.orthonormalized(frame)
	if _pitch_node != null:
		_pitch_node.basis = Basis4D.from_yz(pitch)


## The trip back to the default slice: both rotations and your w, eased to zero together.
##
## The step is delta over the time REMAINING, not a fixed fraction, so the three of them
## arrive at zero at the same moment and exactly on time - a plain lerp toward zero is
## asymptotic and would leave a slice that is nearly default for ever, which is the one
## outcome this is meant to rule out.
##
## Your w velocity is held at zero on the way, or the walker's own accelerating carries
## you back off the slice as fast as this puts you on it.
func _go_home(delta: float) -> void:
	_homing = maxf(_homing - delta, 0.0)
	var step: float = clampf(delta / maxf(_homing + delta, 0.0001), 0.0, 1.0)
	_slice_xw = lerpf(_slice_xw, 0.0, step)
	_slice_zw = lerpf(_slice_zw, 0.0, step)
	var body: Node4D = get_parent() as Node4D
	if body != null:
		body.position.w = lerpf(body.position.w, 0.0, step)
		if body.get("linear_velocity") != null:
			var speed: Vector4 = body.get("linear_velocity")
			speed.w = 0.0
			body.set("linear_velocity", speed)
	if _homing <= 0.0:
		# Landed exactly, rather than within a rounding error of it.
		_slice_xw = 0.0
		_slice_zw = 0.0
		if body != null:
			body.position.w = 0.0
	_apply()


## Positions the camera along the arm, pulled in if the world is in the way.
func _place_camera() -> void:
	if _camera == null:
		return
	var wanted: float = distance
	if collide_with_world:
		wanted = minf(wanted, _clear_distance(distance))
	_camera.position = Vector4(0.0, 0.0, wanted, 0.0)


## How far back the camera can sit before something blocks it.
##
## The 4D stand-in for SpringArm3D's sweep. A ray rather than a swept shape, which is
## cheaper and slightly less forgiving at grazing angles - it can let a corner clip the
## near plane where a real sweep would not.
func _clear_distance(wanted: float) -> float:
	var origin: Vector4 = global_position
	var back: Vector4 = (_pitch_node.global_basis * Vector4(0.0, 0.0, 1.0, 0.0)).normalized()
	var params := RaycastParameters4D.new()
	params.global_ray_origin = origin
	params.global_ray_direction = back
	params.max_distance = wanted
	var hit: Dictionary = PhysicsServer4D.raycast_physics_objects(params)
	if hit.is_empty() or not hit.has("position"):
		return wanted
	var travelled: float = origin.distance_to(hit["position"])
	return clampf(travelled - collision_margin, min_distance * 0.5, wanted)


## The horizontal frame movement is measured against: the rig's own basis with any pitch
## left out, so walking forward never means walking into the ground.
func movement_basis() -> Projection:
	return basis
