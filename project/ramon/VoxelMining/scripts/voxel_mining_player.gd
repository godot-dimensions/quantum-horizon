extends CharacterBody4D
## The mining scenes' player: the shared controller plus STEP-UP.
##
## A fork of `project/player/player.gd` rather than an edit of it, following the
## same convention as ascent_player_4d.gd and gallery_target_spawner_ramon.gd -
## that controller is shared with every other scene in the project.
##
## WHY IT IS NEEDED AT ALL. `CharacterBody4D` has no step logic: `_snap_distance`
## is 0.1 m and there is nothing else, and `AxisAlignedBoxPhysicsEngine4D` only
## ever produces axis-aligned contact normals, so a sloped collider is impossible
## (rotating a box in YZ tilts the mesh but inflates its collider - measured at
## y x5.11 at 15 degrees, see project/ramon/ObstacleCourse/README.md). Between
## those two facts, ANY raised surface is a wall you bounce off, however low.
## That is why the dais and ramp had no collision at all until now.
##
## HOW THIS DIFFERS FROM ascent_player_4d.gd's STEP-UP, which is the whole point.
## That version lifts the body by a FIXED [constant STEP_UP_HEIGHT] and then
## leaves it there, letting move_and_slide and gravity sort it out. On the
## Ascent's 0.35 m stairs the overshoot is small enough to pass; on a 6 cm ramp
## lip it fires you three quarters of a metre into the air. The fix is the third
## move that version is missing: lift, advance, then DROP BACK DOWN by the same
## amount. The drop stops as soon as it lands on whatever was stepped onto, so
## the body ends up exactly on the surface and a 6 cm step costs 6 cm - never the
## full allowance.

const SPEED := 5.0 # Meters per second.
const SPRINT_MULTIPLIER := 2.5
const JUMP_VELOCITY := 4.5 # Meters per second.
const MOUSE_SENSITIVITY := 0.002

## Tallest rise that can be walked over rather than jumped. The default clears
## the 0.40 m dais from any side, so the ramp is an affordance rather than the
## only way up. Kept well below the ~1.03 m jump apex on purpose: anything a jump
## cannot clear should not be silently climbable either.
@export_range(0.0, 1.0, 0.01, "suffix:m") var step_up_height: float = 0.45

var _head_pitch: float = 0.0 # Radians.

@onready var player_head: Node4D = $PlayerHead


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Identical to the shared controller's, minus its right-click raycast print -
## that is a debug leftover there, and `rotate_4d` is held constantly in these
## scenes, so it would spew a dictionary into the console on every slice.
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
		# Forced back to world up every frame and re-orthonormalized so repeated
		# rotation composition cannot drift. See project/player/CONTROLLER_NOTES.md.
		body_basis.y = Vector4(0, 1, 0, 0)
		basis = Basis4D.orthonormalized(body_basis)


func _physics_process(delta_time: float) -> void:
	if not is_on_floor():
		linear_velocity += get_gravity() * delta_time
	if Input.is_action_just_pressed(&"move_jump") and is_on_floor():
		linear_velocity.y = JUMP_VELOCITY

	var input_dir := Vector4(
		Input.get_axis("move_left", "move_right"),
		0.0,
		Input.get_axis("move_forward", "move_back"),
		Input.get_axis("move_kata", "move_ana"),
	)
	var current_speed: float = SPEED * SPRINT_MULTIPLIER if Input.is_key_pressed(KEY_SHIFT) else SPEED
	var direction: Vector4 = (basis * input_dir).normalized()
	if direction:
		linear_velocity.x = direction.x * current_speed
		linear_velocity.z = direction.z * current_speed
		linear_velocity.w = direction.w * current_speed
	else:
		linear_velocity.x = move_toward(linear_velocity.x, 0, current_speed)
		linear_velocity.z = move_toward(linear_velocity.z, 0, current_speed)
		linear_velocity.w = move_toward(linear_velocity.w, 0, current_speed)

	if _step_up(delta_time):
		# The step already carried the body the full horizontal distance for this
		# frame. Zeroing the horizontal velocity keeps move_and_slide from moving
		# it a second time - it still runs, because gravity and the is_on_floor
		# bookkeeping have to happen either way.
		linear_velocity.x = 0.0
		linear_velocity.z = 0.0
		linear_velocity.w = 0.0
	move_and_slide()
	$PositionLabel.text = "Player position: %s" % position


## Walks the body over a low obstruction. Returns true if it took the step and
## has already applied this frame's horizontal motion itself.
##
## THE TRAP, inherited from the Ascent where it cost an afternoon: every move
## here MUST go through `move_and_collide`, never a direct `position` write.
## `AxisAlignedBoxPhysicsEngine4D` caches each body's AABB in
## `_area_and_body_rects` for the whole physics frame and only refreshes it
## inside `move_and_collide` - so after assigning `position`, every later test
## that frame still sees the body's OLD rect. Measured there: an obviously clear
## step tested as blocked 148 times out of 148.
func _step_up(delta_time: float) -> bool:
	if not is_on_floor() or step_up_height <= 0.0:
		return false
	var horizontal := Vector4(linear_velocity.x, 0.0, linear_velocity.z, linear_velocity.w) * delta_time
	if horizontal.is_zero_approx():
		return false

	var blocked: KinematicCollision4D = move_and_collide(horizontal, true, delta_time)
	if blocked == null or blocked.get_travel_ratio() >= 1.0:
		return false # Nothing in the way, so there is no step to take.

	var lift := Vector4(0.0, step_up_height, 0.0, 0.0)
	var headroom: KinematicCollision4D = move_and_collide(lift, true, delta_time)
	if headroom == null or headroom.get_travel_ratio() < 1.0:
		return false # Something overhead: a low tunnel, not a step.

	move_and_collide(lift, false, delta_time)
	var advanced: KinematicCollision4D = move_and_collide(horizontal, true, delta_time)
	if advanced == null or advanced.get_travel_ratio() < 1.0:
		# Still blocked from up there, so it is a genuine wall rather than a
		# step. Put the body back down or it would climb walls a lift at a time.
		move_and_collide(-lift, false, delta_time)
		return false

	move_and_collide(horizontal, false, delta_time)
	# The move ascent_player_4d.gd does not make, and the reason it launches you:
	# come straight back down. The drop stops on contact with whatever was
	# stepped onto, so the body settles on the surface at its real height instead
	# of hanging at the full allowance waiting for gravity.
	move_and_collide(-lift, false, delta_time)
	return true
