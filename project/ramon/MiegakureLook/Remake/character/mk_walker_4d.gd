extends CharacterBody4D
## Slice Garden's little walker: moves only in the world you can see, and through W by turning.
##
## Movement is the pen walker's (chickenpen/scripts/block_walker_character_4d.gd: run by default,
## Alt to walk, a jump, the probe-ahead step-up), copied and changed in one deep way: THE KEYS ARE
## THE SLICE'S AXES, not the screen's and not fixed world ones (PLAN.md decisions 1-3).
##
##   A / D   always world X: the axis the turn never touches, so left and right mean the same in
##           both views.
##   W / S   the view's depth axis: world Z in the normal view, world W once turned. With the
##           camera's turn_sign of -1, W walks ana (+W) after a turn.
##
## There is no W key. You move through W only by facing it (Miegakure: seeing and moving stay
## coupled, or you walk into what you cannot see).
##
## HE IS TURNED WITH THE VIEW. His body (the avatar) is built in the normal view's axes; its basis is
## the view's own quarter turn times his facing inside the slice, so in the turned view his front,
## his feet and his arms lie in X, Y and W exactly as they lay in X, Y and Z, and he looks the same
## while the garden deforms round him. His collider is as deep in Z as in W, so the turn never
## changes what he bumps into.
##
## Movement is held while the view turns (the cross-section is changing under him).
##
## NO class_name (engine_gotchas.md).

signal fell
signal landed

@export_group("Movement")
@export var run_speed: float = 3.0
@export var walk_speed: float = 1.4
@export var jump_velocity: float = 4.8
@export_range(0.1, 50.0, 0.1) var acceleration: float = 12.0
@export_range(0.1, 50.0, 0.1) var turn_speed: float = 11.0
## Below this height he has fallen off: the game puts him back (fell is emitted once).
@export var fall_limit_y: float = -9.0

@export_group("Stepping up")
## The tallest thing that counts as a step rather than an obstacle (the pen walker's).
@export_range(0.0, 1.0, 0.01) var step_height: float = 0.32
@export_range(0.1, 1.5, 0.05) var step_reach: float = 0.45

@export_group("Links")
@export var camera_path: NodePath

## Cleared while something else owns him (a reset, the finale). Gravity keeps working.
var input_enabled: bool = true
## A runner's keys, used instead of the keyboard when `scripted` is set: Vector2(side, fore).
var scripted: bool = false
var scripted_move: Vector2 = Vector2.ZERO
var scripted_walk: bool = false

var _camera: Node
var _avatar: Node4D
var _facing: float = PI
var _fell: bool = false
var _was_on_floor: bool = true
var _jump_queued: bool = false


func _ready() -> void:
	_camera = get_node_or_null(camera_path)
	_avatar = get_node_or_null("Avatar") as Node4D


## The view's quarter turn (identity when there is no camera). The camera is found when first
## needed: the game sets camera_path after this node is already in the tree.
func view_rotation() -> Projection:
	if _camera == null and not camera_path.is_empty():
		_camera = get_node_or_null(camera_path)
	if _camera != null and _camera.has_method("slice_rotation"):
		return _camera.call("slice_rotation")
	return Projection.IDENTITY


## Where he faces, in the world (his front: +Z of his body, turned by the view).
func facing_direction() -> Vector4:
	return view_rotation() * Basis4D.from_zx(_facing) * Vector4(0.0, 0.0, 1.0, 0.0)


## His facing angle inside the slice (0 faces the view's +depth, PI faces away from the camera).
func facing_angle() -> float:
	return _facing


func set_facing_angle(angle: float) -> void:
	_facing = angle
	_pose_avatar()


func jump() -> void:
	_jump_queued = true


func _turning() -> bool:
	view_rotation()
	return _camera != null and _camera.has_method("is_turning") and bool(_camera.call("is_turning"))


func _physics_process(delta: float) -> void:
	if global_position.y < fall_limit_y:
		if not _fell:
			_fell = true
			fell.emit()
		return
	_fell = false
	if not is_on_floor():
		linear_velocity += get_gravity() * delta
	var wants_jump: bool = _jump_queued or (input_enabled and not scripted and Input.is_action_just_pressed(&"move_jump"))
	_jump_queued = false
	if wants_jump and input_enabled and is_on_floor() and not _turning():
		linear_velocity.y = jump_velocity
	var local: Vector2 = _wish()
	var top: float = run_speed
	if (scripted and scripted_walk) or (not scripted and Input.is_key_pressed(KEY_ALT)):
		top = walk_speed
	var rotation_now: Projection = view_rotation()
	var wish: Vector4 = Vector4.ZERO
	if local.length_squared() > 0.0001:
		wish = rotation_now * Vector4(local.x, 0.0, local.y, 0.0).normalized()
	var rate: float = acceleration * top * delta
	linear_velocity.x = move_toward(linear_velocity.x, wish.x * top, rate)
	linear_velocity.z = move_toward(linear_velocity.z, wish.z * top, rate)
	linear_velocity.w = move_toward(linear_velocity.w, wish.w * top, rate)
	move_and_slide()
	_step_up(wish)
	if local.length_squared() > 0.0001:
		_facing = rotate_toward(_facing, atan2(local.x, local.y), turn_speed * delta)
	_pose_avatar()
	var on_floor: bool = is_on_floor()
	if on_floor and not _was_on_floor:
		landed.emit()
	_was_on_floor = on_floor


## The keys, as (side, depth) in the slice: +x is right, +y is toward the camera (back).
func _wish() -> Vector2:
	if not input_enabled or _turning():
		return Vector2.ZERO
	if scripted:
		return scripted_move.limit_length(1.0)
	return Vector2(Input.get_axis(&"move_left", &"move_right"), Input.get_axis(&"move_forward", &"move_back")).limit_length(1.0)


## His body: the view's turn times his facing inside the slice (see the header).
func _pose_avatar() -> void:
	if _avatar != null:
		_avatar.basis = view_rotation() * Basis4D.from_zx(_facing)


## The pen walker's step-up, unchanged: a ray down a pace ahead, and a lift only onto floor that is
## within one step (a wall has no floor a pace in front of it at knee height, so it stays a wall).
func _step_up(wish: Vector4) -> void:
	if step_height <= 0.0 or not is_on_wall() or not is_on_floor():
		return
	var flat := Vector4(wish.x, 0.0, wish.z, wish.w)
	if flat.length() < 0.2:
		return
	flat = flat.normalized()
	var params := RaycastParameters4D.new()
	var probe: Vector4 = global_position + flat * step_reach
	params.global_ray_origin = probe + Vector4(0.0, step_height + 0.25, 0.0, 0.0)
	params.global_ray_direction = Vector4(0.0, -1.0, 0.0, 0.0)
	params.max_distance = step_height + 0.30
	params.set_exclude_nodes([self])
	var hit: Dictionary = PhysicsServer4D.raycast_physics_objects(params)
	if hit.is_empty() or not hit.has("global_point"):
		return
	var top: float = (hit["global_point"] as Vector4).y
	var climb: float = top - global_position.y
	if climb <= 0.02 or climb > step_height:
		return
	global_position = Vector4(global_position.x, top + 0.02, global_position.z, global_position.w)


## Put him somewhere (a respawn, a runner): velocity cleared, facing kept or given.
func place_at(where: Vector4, facing: float = NAN) -> void:
	global_position = where
	linear_velocity = Vector4.ZERO
	_fell = false
	if not is_nan(facing):
		_facing = facing
	_pose_avatar()


func horizontal_speed() -> float:
	return Vector3(linear_velocity.x, linear_velocity.z, linear_velocity.w).length()
