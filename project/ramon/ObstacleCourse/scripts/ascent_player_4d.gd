extends CharacterBody4D

## THE 4D ASCENT's player: the shared controller plus STEP-UP, minus sprint.
##
## A fork of `project/player/player.gd` rather than an edit of it, following the
## same convention as `gallery_target_spawner_ramon.gd` - that controller is
## shared with every other scene in the project and neither change below should
## leak into them.
##
## TWO DIFFERENCES, both forced by measurement:
##
## 1. STEP-UP. `CharacterBody4D` has none: `_snap_distance` is 0.1 m and there is
##    no step logic anywhere, so a 1 cm lip stops you dead and EVERY rise in a
##    level has to be jumped. That makes staircases hostile and ramps impossible,
##    and it is why the first greybox was unclimbable. Measured with step-up on:
##    0.30 m and 0.60 m ledges are walked straight over, a 0.90 m ledge is
##    correctly refused against a 0.70 m allowance.
##
## 2. NO SPRINT. Measured reach is 4.59 m walking against 11.48 m sprinting, and
##    the brief's widest intended gap is 8 m - so sprint lets a tester clear
##    every 4D puzzle without ever using the fourth dimension, which fails the
##    brief's own comprehension test. Shift does nothing here.

const SPEED := 5.0 # Meters per second.
const JUMP_VELOCITY := 4.5 # Meters per second.
const MOUSE_SENSITIVITY := 0.002

## Tallest rise that can be walked over rather than jumped. Below the 1.033 m
## measured jump apex on purpose: anything a jump cannot clear should not be
## silently climbable either, or the level's own difficulty stops meaning
## anything.
const STEP_UP_HEIGHT := 0.7

## Lifted a hair past the obstruction's top so the feet land just above the
## surface rather than exactly level with it, where a float comparison could put
## them back inside it.
const STEP_UP_MARGIN := 0.02

## How fast the eye catches up after the body steps up, in metres per second.
##
## Step-up necessarily moves the BODY in one discrete jump - it is a collider, it
## either clears the obstruction or it does not. Smoothing the collider is not an
## option, and making the treads fine enough to hide the jump costs hundreds of
## colliders and drops the frame rate to single digits. So the body steps and the
## VIEW eases: the camera holds back by exactly the lift and slides up over about
## a tenth of a second, which is the difference between climbing stairs and
## walking up a slope. Standard first-person practice, and cheap.
const VIEW_CATCHUP_SPEED := 3.2

## Never lag the eye further than this behind the body, so a fast series of steps
## cannot sink the camera into the floor.
const VIEW_LAG_MAX := 0.35

## Fall below this and you are put back where you started.
##
## The room now has a stretch of w with no floor in it, so falling is a real
## outcome - and falling forever is the worst possible response to a mistake.
## One press-free reset costs seconds, which is what the brief asks of a fall.
const FALL_LIMIT := -25.0

var _head_pitch: float = 0.0 # Radians.

## Half the capsule's height, read off the real shape at startup rather than
## written down twice - the step-up maths needs the distance from the body origin
## to the feet, and a stale constant here would silently mis-measure every step.
var _half_height: float = 0.875

## How far the eye currently sits BELOW where the body has got to. Always <= 0.
var _view_lag: float = 0.0

## The head's authored height, captured once so the smoothing has a baseline to
## return to rather than accumulating drift.
var _head_base_y: float = 0.75

## Where to put the player back after a fall.
## Read by the course goal for its completion screen. Public on purpose.
var falls: int = 0

var _spawn_position: Vector4 = Vector4()
var _spawn_basis: Projection = Projection()

@onready var player_head: Node4D = $PlayerHead


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for child in get_children():
		var collider := child as CollisionShape4D
		if collider == null:
			continue
		var capsule := collider.shape as CapsuleShape4D
		if capsule != null:
			_half_height = capsule.full_height * 0.5
	_head_base_y = player_head.position.y
	_spawn_position = position
	_spawn_basis = basis


func _input(input_event: InputEvent) -> void:
	if input_event.is_action_pressed(&"ui_cancel"):
		get_tree().quit()
	elif input_event is InputEventMouseMotion:
		var body_basis: Projection = basis
		var rel: Vector2 = input_event.relative * MOUSE_SENSITIVITY
		if Input.is_action_pressed(&"rotate_4d"):
			body_basis *= Basis4D.from_xw(-rel.x) * Basis4D.from_zw(rel.y)
		else:
			body_basis *= Basis4D.from_zx(-rel.x)
			_head_pitch = clampf(_head_pitch - rel.y, -1.57, 1.57)
			player_head.basis = Basis4D.from_yz(_head_pitch)
		# Forced back to world up every frame, then re-orthonormalized, so that
		# repeated rotation composition cannot drift. Same guard as the shared
		# controller - see project/player/CONTROLLER_NOTES.md.
		body_basis.y = Vector4(0, 1, 0, 0)
		basis = Basis4D.orthonormalized(body_basis)


func _physics_process(delta_time: float) -> void:
	if not is_on_floor():
		linear_velocity += get_gravity() * delta_time
	if Input.is_action_just_pressed("move_jump") and is_on_floor():
		linear_velocity.y = JUMP_VELOCITY

	var input_dir := Vector4(
		Input.get_axis("move_left", "move_right"),
		0.0,
		Input.get_axis("move_forward", "move_back"),
		Input.get_axis("move_kata", "move_ana"),
	)
	var direction: Vector4 = (basis * input_dir).normalized()
	if direction:
		linear_velocity.x = direction.x * SPEED
		linear_velocity.z = direction.z * SPEED
		linear_velocity.w = direction.w * SPEED
	else:
		linear_velocity.x = move_toward(linear_velocity.x, 0, SPEED)
		linear_velocity.z = move_toward(linear_velocity.z, 0, SPEED)
		linear_velocity.w = move_toward(linear_velocity.w, 0, SPEED)

	_try_step_up(delta_time)
	move_and_slide()
	_settle_view(delta_time)
	if position.y < FALL_LIMIT:
		_respawn()
	$PositionLabel.text = "Player position: %s" % position


## Lift the body over a small obstruction so it can be walked rather than jumped.
##
## Runs BEFORE move_and_slide: if this frame's horizontal motion is blocked while
## grounded, rise by EXACTLY the height of the thing in the way and let
## move_and_slide carry the body forward and settle it.
##
## "Exactly" is the difference between a ramp and a staircase. The first version
## always lifted the full [constant STEP_UP_HEIGHT], so a 7 cm tread bumped the
## body 70 cm into the air and dropped it back - which is precisely why walking up
## a smooth-looking ramp felt like climbing stairs. The obstruction's real height
## is available for nothing: `KinematicCollision4D` hands back the shape node that
## blocked us, so one lookup gives its top and the lift becomes a few centimetres.
##
## THE TRAP, and it cost an afternoon: the lift MUST go through
## `move_and_collide`, never a direct `position` write.
## `AxisAlignedBoxPhysicsEngine4D` caches every body's AABB in
## `_area_and_body_rects` for the whole physics frame and only recomputes it when
## a body's shape COUNT changes - so after assigning `position`, every later test
## that frame still sees the body's OLD rect. Measured: an obviously clear
## step-up tested as blocked 148 times out of 148. A real `move_and_collide`
## writes the updated rect back into the cache, and the next test sees it.
func _try_step_up(delta_time: float) -> void:
	if not is_on_floor():
		return
	var horizontal := Vector4(linear_velocity.x, 0.0, linear_velocity.z, linear_velocity.w) * delta_time
	if horizontal.is_zero_approx():
		return

	var blocked: KinematicCollision4D = move_and_collide(horizontal, true, delta_time)
	if blocked == null or blocked.get_travel_ratio() >= 1.0:
		return # Nothing in the way.

	var needed: float = _step_height_of(blocked)
	if needed <= 0.0 or needed > STEP_UP_HEIGHT:
		return # Flat ground, or a wall too tall to step onto.

	var lift := Vector4(0.0, needed, 0.0, 0.0)
	var headroom: KinematicCollision4D = move_and_collide(lift, true, delta_time)
	if headroom == null or headroom.get_travel_ratio() < 1.0:
		return # Something overhead: this is a low tunnel, not a step.

	move_and_collide(lift, false, delta_time)
	var after: KinematicCollision4D = move_and_collide(horizontal, true, delta_time)
	if after == null or after.get_travel_ratio() < 1.0:
		# Still blocked from up there, so it is a genuine wall. Put the body back
		# down, or it would climb walls a step at a time.
		move_and_collide(-lift, false, delta_time)
	else:
		# The step was taken. Hold the eye back by exactly that much and let
		# _settle_view slide it up, so the view rises smoothly across a step the
		# body crossed instantly.
		_view_lag = maxf(_view_lag - needed, -VIEW_LAG_MAX)


## Back to the start, including the slice you began in - respawning at the right
## place in the wrong w band would drop you straight back into the void.
func _respawn() -> void:
	falls += 1
	position = _spawn_position
	basis = _spawn_basis
	linear_velocity = Vector4()
	_view_lag = 0.0


## Eases the eye back up to the body after a step-up.
func _settle_view(delta_time: float) -> void:
	if not is_zero_approx(_view_lag):
		_view_lag = move_toward(_view_lag, 0.0, VIEW_CATCHUP_SPEED * delta_time)
	player_head.position.y = _head_base_y + _view_lag


## How far the body must rise to clear whatever it just hit, or 0 if that cannot
## be worked out. Returns the step height plus a hair, so the lift lands the feet
## just above the surface rather than exactly level with it.
func _step_height_of(collision: KinematicCollision4D) -> float:
	var shape_node: CollisionShape4D = collision.get_obstacle_shape_node()
	if shape_node == null:
		return 0.0
	var box: BoxShape4D = shape_node.shape as BoxShape4D
	if box == null:
		# Only boxes are measurable this cheaply, and per the engine audit boxes
		# are the only thing with honest collision anyway.
		return 0.0
	var obstacle_top: float = shape_node.global_position.y + box.size.y * 0.5
	var feet: float = global_position.y - _half_height
	return obstacle_top - feet + STEP_UP_MARGIN
