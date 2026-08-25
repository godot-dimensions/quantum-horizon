extends Node
## Absolute-axis WASD (x/z) + QE (w) pan of the orbit camera's pivot
## (look_at_target) - lets you move the "focus point" around a large
## sparse voxel world and watch TerrainChunkPool4D's distance culling
## stream bricks in and out live, a direct interactive test of the plan's
## chunk-level culling design. Not camera-relative (ignores azimuth) and
## has no collision - a diagnostic/showcase tool, not a real player
## controller.

@export var camera_path: NodePath
@export var pan_speed: float = 6.0

@onready var camera: Camera4D = get_node(camera_path)

func _process(delta: float) -> void:
	var move := Vector4.ZERO
	if Input.is_key_pressed(KEY_D):
		move.x += 1.0
	if Input.is_key_pressed(KEY_A):
		move.x -= 1.0
	if Input.is_key_pressed(KEY_S):
		move.z += 1.0
	if Input.is_key_pressed(KEY_W):
		move.z -= 1.0
	if Input.is_key_pressed(KEY_E):
		move.w += 1.0
	if Input.is_key_pressed(KEY_Q):
		move.w -= 1.0
	if move.is_zero_approx():
		return
	camera.look_at_target += move.normalized() * pan_speed * delta
	camera.refresh()
