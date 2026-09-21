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

var yaw: float = 0.0
var pitch: float = -0.15

var _slice_xw: float = 0.0
var _slice_zw: float = 0.0
var _zoom_target: float = 0.0

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
			# Turning the view through W: this changes which slice of the 4D world is
			# visible, not which way the character faces within it.
			_slice_xw -= motion.x
			_slice_zw += motion.y
		else:
			# PLUS, not minus. Subtracting swung the view left when the mouse went right,
			# which is the wrong way round for a camera you are pushing rather than a head
			# you are turning. The W-drag above keeps its own sign: it is a separate,
			# deliberately-held gesture, and pen_slice_assist_4d tells the player which way
			# to drag in words that are derived from that sign.
			yaw += motion.x
			pitch = clampf(pitch - motion.y,
				deg_to_rad(pitch_min_degrees), deg_to_rad(pitch_max_degrees))
		_apply()


func _physics_process(delta: float) -> void:
	distance = lerpf(distance, _zoom_target, clampf(delta * 10.0, 0.0, 1.0))
	position = Vector4(0.0, pivot_height, 0.0, 0.0)
	_place_camera()


## Yaw and the two W-planes live on the rig; pitch lives on a child.
##
## Splitting them is not tidiness. Pitch has to be applied AFTER yaw and must not feed
## back into it, and keeping it on its own node means the rig's own basis stays a clean
## horizontal frame that movement can be measured against - the same reason the project's
## first-person player keeps pitch on its head node.
func _apply() -> void:
	var frame: Projection = Basis4D.from_zx(yaw)
	if not is_zero_approx(_slice_xw):
		frame *= Basis4D.from_xw(_slice_xw)
	if not is_zero_approx(_slice_zw):
		frame *= Basis4D.from_zw(_slice_zw)
	basis = Basis4D.orthonormalized(frame)
	if _pitch_node != null:
		_pitch_node.basis = Basis4D.from_yz(pitch)


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
