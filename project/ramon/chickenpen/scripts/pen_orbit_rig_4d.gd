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

## THREE CAMERAS TO CHOOSE BETWEEN, cycled with Tab, because this is being decided by
## playing rather than by argument and the only useful comparison is an immediate one.
##
## SUBJECT SIZE IS HELD ROUGHLY CONSTANT across the three: the distance rises as the lens
## narrows, by 1/tan(fov/2). Narrowing the lens on its own is only a zoom, and of course a
## zoomed picture looks different - what these three actually differ in is PERSPECTIVE.
## Wide throws the world away from you and leaves a large empty foreground; narrow
## compresses it, so the pen reads as a box you can judge distances across.
##
## The height and the downward tilt climb with the narrowing, and they are doing at least
## as much of the work as the lens is. Most of what makes the third one legible is simply
## that it can see the ground.
##
##   1 - 77.3 degrees at 5 m. Where this started: the engine's default focal length.
##   2 - 55 degrees at 8 m. A compromise that keeps a good amount of sky.
##   3 - 45 degrees at 9.7 m, higher and tilted further down. The diorama.
##   4 - the cinema's own framing, copied from theatre_camera_4d: wide, close, and up at
##       1.7 m. It is there to be compared against, not because the farm should use a
##       shot built for one seated figure on a stage.
##
## Each row is: name, field of view in degrees, distance, pivot height, pitch in degrees.
const PRESETS: Array = [
	["Camera 1", 77.3, 5.00, 1.10, -8.6],
	["Camera 2", 55.0, 8.00, 1.50, -15.0],
	["Camera 3", 45.0, 9.70, 1.90, -22.0],
	["Camera 4", 77.3, 4.20, 1.70, -6.0],
]

signal preset_changed(index: int)

## Which one the scene opens on, and whether this rig has presets at all. Negative - the
## default - uses the distance, pivot and pitch exported below, and Tab does nothing: the
## behaviour this had before there were presets, which is what the cinema wants.
@export_range(-1, 3, 1) var start_preset: int = -1
@export var cycle_key: Key = KEY_TAB

## Degrees the camera sits above the character's feet, as the point it orbits.
@export var pivot_height: float = 1.1

## How far back the camera sits. Zoom moves this between the two limits.
@export var distance: float = 5.0
@export var min_distance: float = 1.5
@export var max_distance: float = 14.0
@export var zoom_speed: float = 1.2

@export_range(0.0, 0.02, 0.0001) var mouse_sensitivity: float = 0.005

## Which way the camera looks on the first frame, in degrees. Positive turns the view to
## its left, which is the sign from_zx uses.
##
## EXPORTED RATHER THAN SET ON `yaw` IN THE SCENE. `yaw` is a plain script variable, so a
## .tscn line setting it applies on load but carries no STORAGE flag - the next time the
## editor saves the scene it would be dropped, and the spawn would quietly go back to
## facing straight down -Z with nothing in the diff to explain it.
@export_range(-180.0, 180.0, 0.5) var start_yaw_degrees: float = 0.0

## How far the camera looks down on the first frame, in degrees. Negative looks down.
##
## EXPORTED FOR THE SAME REASON AS THE YAW: `pitch` is a plain script variable, so a value
## set on it in the scene applies on load and is dropped the next time the editor saves.
@export_range(-89.0, 89.0, 0.5) var start_pitch_degrees: float = -8.6

## Pitch limits, in degrees. Asymmetric on purpose: a third-person camera wants to look
## down at the character far more than it wants to look up at its feet.
@export_range(-89.0, 0.0, 0.5) var pitch_min_degrees: float = -75.0
@export_range(0.0, 89.0, 0.5) var pitch_max_degrees: float = 25.0

## Pull the camera in when something is between it and the character - the spring arm's
## whole job. Costs one raycast a frame.
@export var collide_with_world: bool = true

## How much of the pulled-in distance to keep clear of the obstruction.
@export var collision_margin: float = 0.3

@export_group("Conversation")
## While somebody is talking, the camera comes in and the point it orbits drops, so the
## two of you fill the frame instead of standing as small figures under a wide sky.
##
## DISTANCE AND PIVOT ONLY - NOT PITCH. Easing the pitch toward a framing would fight the
## mouse for the same variable, and the player should still be able to look around while
## somebody talks at them. Lowering what the camera orbits around gets the same "we are
## down here at eye level" read without taking the look away.
@export_range(1.0, 8.0, 0.1) var talk_distance: float = 2.9
@export_range(0.0, 2.0, 0.05) var talk_pivot_height: float = 0.8
@export_range(1.0, 20.0, 0.5) var talk_ease: float = 7.0

@export_group("Locking on")
## T: keep the nearest loose chicken dead ahead of you. The controls card has promised this
## since the start and nothing listened for the key - Trym: "I couldn't seem to get T to do
## anything in terms of locking onto chickens".
##
## HEADING ONLY. It turns the way you face, never your slice and never your w. Rotating the
## slice onto a chicken would SHOW it without making it reachable - the camera changes what
## you see, only moving through W changes where you are - and the locator's own rule is that
## a guide which does the searching for you deletes the thing it exists to teach. Locked on,
## the bird stays in front of you while you step through W to get to it yourself.
@export var lock_key: Key = KEY_T
## Where to ask which chicken is nearest. The locator already answers that question, with
## hysteresis, from the birds that are loose - carried, penned and returned birds are not
## candidates - so the lock and the HUD can never disagree about which one it means.
@export var locator_path: NodePath
## How quickly the heading swings onto the bird, per second, as a fraction of the gap.
@export_range(1.0, 30.0, 0.5) var lock_turn_rate: float = 8.0

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

## Somewhere with walls the physics cannot see can say how far back the camera may go:
## anything with camera_clearance(origin, direction, wanted) -> float. The cave sets itself
## here while you are in it - its walls are baked rock with no colliders, and the ray above
## would sail through them. Null everywhere else.
var clearance_provider: Object = null
var _slice_xw: float = 0.0
var _slice_zw: float = 0.0
var _zoom_target: float = 0.0
## Seconds left on the way back to the default slice. Zero means nothing is happening.
var _homing: float = 0.0
## Seconds during which an implausibly large mouse jump is treated as the cursor being
## warped rather than as a look. See _unhandled_input.
var _ignore_mouse: float = 1.5
var _talking: bool = false
## Set while a staged shot is on screen. See lock_look.
var _look_locked: bool = false
var _locator: Node
## The chicken locked on to, and its agent - the agent is what the locator hands out, and
## asking whether it is still a candidate is how a caught bird releases the lock.
var _lock_agent: Node = null
var _lock_body: Node4D = null
## The authored framing, so leaving a conversation restores what the scene asked for and
## whatever the player had zoomed to, rather than a hard-coded default.
var _home_pivot: float = 0.0
var _rest_distance: float = 0.0
## Which of PRESETS is on, so the readout can say which.
var preset: int = 0

@onready var _pitch_node: Node4D = $Pitch
@onready var _camera: Camera4D = $Pitch/Camera4D


func _ready() -> void:
	yaw = deg_to_rad(start_yaw_degrees)
	pitch = deg_to_rad(start_pitch_degrees)
	if start_preset >= 0:
		use_preset(start_preset)
	_zoom_target = distance
	_home_pivot = pivot_height
	_rest_distance = distance
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_locator = get_node_or_null(locator_path)
	_apply()


## Locked on to a chicken, for the locator's readout.
func is_locked_on() -> bool:
	return _lock_body != null


## PRESETS reached through a call, not through get(): a const is not a property, so
## asking a rig instance for "PRESETS" comes back null and the readout draws nothing.
func presets() -> Array:
	return PRESETS


## Snaps to one of the three. The zoom target moves with it, so the wheel still works
## from wherever the preset put you, and a conversation afterwards returns to it.
func use_preset(index: int) -> void:
	if PRESETS.is_empty():
		return
	preset = posmod(index, PRESETS.size())
	var p: Array = PRESETS[preset]
	distance = float(p[2])
	_zoom_target = distance
	_rest_distance = distance
	pivot_height = float(p[3])
	_home_pivot = pivot_height
	pitch = deg_to_rad(float(p[4]))
	if _camera != null:
		_camera.set("field_of_view_3d", deg_to_rad(float(p[1])))
	_apply()
	preset_changed.emit(preset)


## Held still while a staged shot is up.
##
## THE SHOT IS NOT YOURS FOR THOSE TWO SECONDS. The staged camera is a different node, so
## dragging the mouse does not move it anyway - but it does turn the orbit camera behind
## the cut, and the view you are handed back is then somewhere you never chose to look.
## Ignoring the mouse for the length of the shot means the cut back returns you exactly
## where the cut away left you.
func lock_look(on: bool) -> void:
	_look_locked = on


## Called when a conversation opens and closes. Remembers whatever the player had zoomed
## to so leaving gives it back.
func set_talking(on: bool) -> void:
	if on == _talking:
		return
	_talking = on
	if on:
		_rest_distance = _zoom_target
		_zoom_target = talk_distance
	else:
		_zoom_target = _rest_distance


## Bring the slice back to flat over `home_seconds`. The R key does it, and so does the
## full restart - one way in, so the two can never drift apart.
func go_home() -> void:
	_homing = home_seconds


func _unhandled_input(event: InputEvent) -> void:
	if start_preset >= 0 and event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == cycle_key:
			use_preset(preset + 1)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo 			and (event as InputEventKey).keycode == lock_key:
		_toggle_lock()
		get_viewport().set_input_as_handled()
		return
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
		go_home()
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
		if _look_locked:
			return
		if _ignore_mouse > 0.0 and event.relative.length() > 120.0:
			# The warp, not a look. Small movements in this window are let through, so
			# somebody who grabs the mouse immediately is not ignored.
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
			# Locked on, the heading belongs to the lock and the mouse keeps only pitch -
			# otherwise every nudge is a tug of war the player cannot win or see.
			if _lock_body == null:
				yaw -= motion.x
			pitch = clampf(pitch - motion.y,
				deg_to_rad(pitch_min_degrees), deg_to_rad(pitch_max_degrees))
		_apply()


func _physics_process(delta: float) -> void:
	if _ignore_mouse > 0.0:
		_ignore_mouse -= delta
	if _homing > 0.0:
		_go_home(delta)
	# The conversation framing eases in and out on the same channel the zoom already uses,
	# so it cannot end up fighting a scroll wheel.
	pivot_height = lerpf(pivot_height,
		talk_pivot_height if _talking else _home_pivot,
		clampf(delta * talk_ease, 0.0, 1.0))
	distance = lerpf(distance, _zoom_target, clampf(delta * 10.0, 0.0, 1.0))
	position = Vector4(0.0, pivot_height, 0.0, 0.0)
	if _lock_body != null:
		_steer_to_lock(delta)
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
		if is_instance_valid(clearance_provider):
			var back: Vector4 = (_pitch_node.global_basis * Vector4(0.0, 0.0, 1.0, 0.0)).normalized()
			wanted = minf(wanted, float(clearance_provider.call("camera_clearance", global_position, back, wanted)))
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
	if hit.is_empty() or not hit.has("global_point"):
		return wanted
	var travelled: float = origin.distance_to(hit["global_point"])
	return clampf(travelled - collision_margin, min_distance * 0.5, wanted)


## The horizontal frame movement is measured against: the rig's own basis with any pitch
## left out, so walking forward never means walking into the ground.
func movement_basis() -> Projection:
	return basis


## T. On if nothing is locked and the locator has a bird; off otherwise.
func _toggle_lock() -> void:
	if _lock_body != null:
		_release_lock()
		return
	if _locator == null:
		return
	var agent: Node = _locator.get("target")
	var body := agent.get_parent() as Node4D if agent != null else null
	if body == null:
		return
	_lock_agent = agent
	_lock_body = body
	# Taking the heading cancels any trip home: the two want the same angle.
	_homing = 0.0


func _release_lock() -> void:
	_lock_agent = null
	_lock_body = null


## Swings the heading onto the locked bird, within the slice you have chosen.
##
## The bird's offset is taken into the rig's parent frame and then out of the slice
## rotation, so what is left is where it stands in the 3D world you are looking at; its W
## is dropped, because W is the part you have to walk. The yaw that points the view along
## that is one of two closed forms depending on from_zx's handedness, so both are tried and
## the one whose forward actually lands on the bird is kept - measured, not argued, the
## same way the slice assist settles its signs.
func _steer_to_lock(delta: float) -> void:
	if not is_instance_valid(_lock_body) or not is_instance_valid(_lock_agent):
		_release_lock()
		return
	# Caught, carried, penned or returned: no longer a candidate, so the lock lets go.
	var manager: Node = _locator.get("_manager") if _locator != null else null
	if manager != null and manager.has_method("locator_candidates") 			and not (manager.call("locator_candidates") as Array).has(_lock_agent):
		_release_lock()
		return
	var parent := get_parent() as Node4D
	var rel: Vector4 = _lock_body.global_position - global_position
	if parent != null:
		rel = parent.global_basis.inverse() * rel
	var slice: Projection = Projection.IDENTITY
	if not is_zero_approx(_slice_xw):
		slice *= Basis4D.from_xw(_slice_xw)
	if not is_zero_approx(_slice_zw):
		slice *= Basis4D.from_zw(_slice_zw)
	var t: Vector4 = slice.inverse() * rel
	var flat := Vector2(t.x, t.z)
	if flat.length() < 0.2:
		return
	flat = flat.normalized()
	var want: float = yaw
	var best: float = -2.0
	for candidate in [atan2(-flat.x, -flat.y), atan2(flat.x, -flat.y)]:
		var f: Vector4 = Basis4D.from_zx(candidate) * Vector4(0.0, 0.0, -1.0, 0.0)
		var score: float = Vector2(f.x, f.z).dot(flat)
		if score > best:
			best = score
			want = candidate
	yaw = lerp_angle(yaw, want, clampf(delta * lock_turn_rate, 0.0, 1.0))
	_apply()
