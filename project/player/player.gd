extends CharacterBody4D


const MENU_SCENE_PATH := "res://menu/main_menu.tscn"

const SPEED = 5.0 # Meters per second.
const SPRINT_MULTIPLIER = 2.5
const JUMP_VELOCITY = 4.5 # Meters per second.
const MOUSE_SENSITIVITY = 0.002

var _head_pitch: float = 0.0 # Radians.

## Rail mode: when true, _physics_process skips its own WASD/Q-E movement
## and move_and_slide() entirely - something else (rail_controller.gd) is
## driving position directly instead. Deliberately doesn't touch rotation
## at all - mouse-look and slice-rotation both live in _input() below,
## completely separate from this flag, so they stay fully live either way.
var rail_locked: bool = false

@onready var player_head: Node4D = $PlayerHead


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(input_event: InputEvent) -> void:
	if input_event.is_action_pressed(&"ui_cancel"):
		get_tree().change_scene_to_file(MENU_SCENE_PATH)
	elif input_event is InputEventMouseMotion:
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
	elif input_event.is_action_pressed(&"rotate_4d"):
		# Temporary test of raycast functionality: Do a raycast on left click.
		var ray_params := RaycastParameters4D.new()
		ray_params.global_ray_origin = player_head.global_position
		ray_params.global_ray_direction = -player_head.global_basis.z
		# The default is inside_is_skip = true, which
		# means the ray won't hit the player's capsule.
		#ray_params.inside_is_skip = false
		# However, if in the future we want a raycast from not necessarily
		# inside the capsule (ex: from the player's VR hand, reaching out),
		# then the player should be explicitly excluded.
		# Either the body node or shape node will work here.
		#ray_params.set_exclude_nodes([self])
		var result: Dictionary = PhysicsServer4D.raycast_physics_objects(ray_params)
		print(result)


func _physics_process(delta_time: float) -> void:
	if not rail_locked:
		# Add the gravity.
		if not is_on_floor():
			linear_velocity += get_gravity() * delta_time
		# Handle jump.
		if Input.is_action_just_pressed("move_jump") and is_on_floor():
			linear_velocity.y = JUMP_VELOCITY
		# Get the input direction and handle the movement/deceleration.
		var input_dir := Vector4(
			Input.get_axis("move_left", "move_right"),
			0.0, # Use `Input.get_axis("move_up", "move_down")` if up/down is needed.
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
		move_and_slide()
	$PositionLabel.text = "Player position: %s" % position
