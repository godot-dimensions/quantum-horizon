extends CharacterBody4D
## Scene-local fork of project/player/player.gd for the portal chamber.
##
## Why fork at all: Aaron's controller sets linear_velocity.x/z/w from input
## EVERY frame, on the ground and in the air alike. That is right for walking and
## fatal for portals - a traveller leaving a wall portal at 15 m/s has that speed
## erased on the very next frame, so the single property that makes a portal a
## portal ("speedy thing goes in, speedy thing comes out") cannot be observed at
## all. Portal's own movement works the way this fork does: authoritative on the
## ground, and in the air you keep what you had with only limited steering.
##
## Forked rather than edited, per CLAUDE.md: player.gd is shared. The .tscn
## overrides the script on its own Player instance, so nothing outside this
## folder changes. Everything else here - mouse look, pitch on PlayerHead, slice
## rotation, the y-column reset - is Aaron's, unchanged, and should stay that way.
## The one deletion is his left-click raycast test branch, which would otherwise
## print on every portal shot.

const SPEED = 5.0 # Meters per second.
const SPRINT_MULTIPLIER = 2.5
const JUMP_VELOCITY = 4.5 # Meters per second.
const MOUSE_SENSITIVITY = 0.002

## Metres per second squared of steering available while airborne. Enough to
## adjust a landing, far too little to accelerate up to walking speed from a
## standstill - so a fling stays a fling and cannot be faked by holding W.
const AIR_CONTROL = 12.0

var _head_pitch: float = 0.0 # Radians.

## Capturing the mouse warps the cursor to the centre of the window, and the OS
## reports that warp as one enormous relative motion - which the look code would
## otherwise apply as a real flick, spinning the view the instant the scene
## starts. Measured: a fresh run yawed the player 30 degrees before they had
## touched anything, and it varied run to run. The first motion event after any
## capture is therefore discarded.
var _swallow_next_motion: bool = true

@onready var player_head: Node4D = $PlayerHead


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_swallow_next_motion = true


func _input(input_event: InputEvent) -> void:
	if input_event.is_action_pressed(&"ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif input_event is InputEventMouseButton and input_event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			_swallow_next_motion = true
	elif input_event is InputEventMouseMotion:
		if _swallow_next_motion:
			_swallow_next_motion = false
			return
		var body_basis: Projection = basis
		var rel: Vector2 = input_event.relative * MOUSE_SENSITIVITY
		if Input.is_action_pressed(&"rotate_4d"):
			body_basis *= Basis4D.from_xw(-rel.x) * Basis4D.from_zw(rel.y)
		else:
			body_basis *= Basis4D.from_zx(-rel.x)
			_head_pitch = clampf(_head_pitch - rel.y, -1.57, 1.57)
			player_head.basis = Basis4D.from_yz(_head_pitch)
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
	var current_speed: float = SPEED * SPRINT_MULTIPLIER if Input.is_key_pressed(KEY_SHIFT) else SPEED
	var direction: Vector4 = (basis * input_dir).normalized()

	if is_on_floor():
		# Aaron's original behaviour, untouched.
		if direction:
			linear_velocity.x = direction.x * current_speed
			linear_velocity.z = direction.z * current_speed
			linear_velocity.w = direction.w * current_speed
		else:
			linear_velocity.x = move_toward(linear_velocity.x, 0, current_speed)
			linear_velocity.z = move_toward(linear_velocity.z, 0, current_speed)
			linear_velocity.w = move_toward(linear_velocity.w, 0, current_speed)
	else:
		# Airborne: momentum is kept and steering only nudges it. The speed cap
		# is whatever you ARRIVED with (or walking speed, whichever is greater),
		# so steering can redirect a fling but never build one out of nothing.
		var horizontal := Vector4(linear_velocity.x, 0.0, linear_velocity.z, linear_velocity.w)
		var speed_cap: float = maxf(horizontal.length(), current_speed)
		if direction:
			horizontal += direction * AIR_CONTROL * delta_time
			if horizontal.length() > speed_cap:
				horizontal = horizontal.normalized() * speed_cap
		linear_velocity.x = horizontal.x
		linear_velocity.z = horizontal.z
		linear_velocity.w = horizontal.w

	move_and_slide()
	$PositionLabel.text = "Player position: %s" % position
