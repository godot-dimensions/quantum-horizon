extends CharacterBody4D
## THE ANNEX'S PLAYER: first person, free walk and free look, and W at walking pace.
##
## The body is the team's first-person player in shape (a capsule 0.25 by 1.75, the head 0.75 above
## its centre, project/player/player.tscn) with its own code, because player.gd sends Esc to the old
## team menu (the Esc guard and the menu's WayHome own Esc here).
##
## THE FRAME. The body's basis is a "ground basis" (carried/ground_basis_4d.gd, the pen's): y always
## straight up, and every turn a right-multiply by a rotation of the (x, z, w) space. Looking left and
## right turns within the slice you see; the turn into W (level 3, once you hold the Lens) tilts what is
## ahead into W. Pitch lives on the head only, as an absolute clamped angle, so it never leaks into
## walking or into W (CLAUDE.md: bearing maths reads the body, never the head).
##
## W. Q and E (and the wheel, in nudges) move you along the body's own W axis, the normal of the slice
## you see, through move_and_slide with the walk: the engine sweeps that motion against the walls in
## all four axes, so you cannot shift into a wall any more than you can walk into one. When you push and
## nothing moves, `w_blocked` says so (the gizmo shows the stop, the sound knocks).
##
## V AND R are eased moves the game asks for (align_w, align_frame, level): they run in the physics
## step, through the same collision, and land exactly when nothing is in the way.

const Ground := preload("res://ramon/MazeRemake2/carried/ground_basis_4d.gd")

signal w_knock(direction: float)

@export var walk_speed: float = 3.4
@export var sprint_speed: float = 5.6
@export var accel: float = 30.0
@export var w_speed: float = 1.6
@export var w_accel: float = 10.0
@export var wheel_step: float = 0.35
@export var mouse_sensitivity: float = 0.0022
@export var turn_sensitivity: float = 0.0045
@export var gravity: float = 18.0
@export var fov_degrees: float = 78.0
## The turn into W (right mouse held, drag up and down). Off until the Lens.
@export var turn_enabled: bool = false

var input_enabled: bool = true
var look_enabled: bool = true
var w_enabled: bool = true
var ground: Projection = Projection.IDENTITY
var pitch: float = 0.0
var head: Node4D
var camera: Camera4D
## -1, 0 or 1: the W keys held (the gizmo lights them).
var w_input: float = 0.0
## True while you push along W and the world stops you.
var w_blocked: bool = false
## The speed along your W axis this step, m/s (the sound follows it).
var w_rate: float = 0.0
var _wheel_left: float = 0.0
var _plane := Vector4.ZERO
var _normal: float = 0.0
var _vy: float = 0.0
var _align: Dictionary = {}
var _turn_held: bool = false
var _blocked_for: float = 0.0
var _knocked: bool = false


func _ready() -> void:
	set("snap_to_floor", true)
	set("snap_distance", 0.12)
	if get_node_or_null("Shape") == null:
		var cs := CollisionShape4D.new()
		cs.name = "Shape"
		var cap := CapsuleShape4D.new()
		cap.radius = 0.25
		cap.full_height = 1.75
		cs.shape = cap
		add_child(cs)
	head = get_node_or_null("Head")
	if head == null:
		head = Node4D.new()
		head.name = "Head"
		head.position = Vector4(0, 0.75, 0, 0)
		add_child(head)
	camera = head.get_node_or_null("Camera") as Camera4D
	if camera == null:
		camera = Camera4D.new()
		camera.name = "Camera"
		head.add_child(camera)
	camera.set("rendering_engine_name", "Cross-section")
	camera.set("view_angle_type", 1)
	camera.set("field_of_view_4d", deg_to_rad(fov_degrees))
	camera.set("clip_near", 0.05)
	camera.current = true
	ground = Ground.cleaned(basis)
	basis = ground


## Puts the body at `pos` (its feet at pos.y) facing `yaw` (from_zx's sign: 0 faces -z), level.
func place(pos: Vector4, yaw: float) -> void:
	_align.clear()
	ground = Basis4D.from_zx(yaw)
	basis = ground
	global_position = Vector4(pos.x, pos.y + 0.875, pos.z, pos.w)
	_plane = Vector4.ZERO
	_normal = 0.0
	_vy = 0.0
	_wheel_left = 0.0
	pitch = 0.0
	if head != null:
		head.basis = Basis4D.from_yz(0.0)
	set("linear_velocity", Vector4.ZERO)


func feet() -> Vector4:
	return global_position - Vector4(0, 0.875, 0, 0)


func forward() -> Vector4:
	return -ground.z


## How far the slice is turned into W, radians (0 level, PI/2 when ahead is W).
func tilt() -> float:
	return Ground.tilt(ground)


func eye() -> Vector4:
	return camera.global_position if camera != null else global_position


func is_aligning() -> bool:
	return not _align.is_empty()


## Eases your W to `target` over `seconds`, then lands on it exactly (V).
func align_w(target: float, seconds: float = 0.4) -> void:
	_align = {"t": 0.0, "dur": maxf(seconds, 0.05), "w0": global_position.w, "w1": target, "b0": ground, "b1": null}


## Eases the frame to `frame` (and W to `target_w` when given) over `seconds` (V on a turn, R).
func align_frame(frame: Projection, seconds: float = 0.5, target_w: float = NAN) -> void:
	_align = {"t": 0.0, "dur": maxf(seconds, 0.05), "w0": global_position.w,
		"w1": target_w if not is_nan(target_w) else NAN, "b0": ground, "b1": frame}


## R: the slice laid level again (your W kept), eased.
func level(seconds: float = 0.45) -> void:
	align_frame(Ground.flattened(ground), seconds)


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	var mb := event as InputEventMouseButton
	if mb != null:
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_turn_held = mb.pressed
		if mb.pressed and w_enabled and _align.is_empty():
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_wheel_left = clampf(_wheel_left + wheel_step, -2.0, 2.0)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_wheel_left = clampf(_wheel_left - wheel_step, -2.0, 2.0)
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var mm := event as InputEventMouseMotion
	if mm != null and look_enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look(mm.relative)


## A mouse move: turn and pitch; with the right button held and the turn unlocked, up and down tilt
## what is ahead into W instead of pitching.
func look(rel: Vector2) -> void:
	if not _align.is_empty():
		return
	ground = Ground.looked(ground, Vector2(rel.x * mouse_sensitivity, 0.0))
	if _turn_held and turn_enabled:
		# Up turns what is ahead into ana (+W), down back towards level and on into kata (measured by
		# scripts/_probe_turn_dir_runner.gd: sliced's positive y swings ahead towards -W).
		ground = Ground.sliced(ground, Vector2(0.0, rel.y * turn_sensitivity))
		# Never past ahead-is-W: the turn is a quarter at most each way.
		var t: float = Ground.tilt(ground)
		if t > PI * 0.5:
			ground = Ground.sliced(ground, Vector2(0.0, -rel.y * turn_sensitivity))
	else:
		pitch = clampf(pitch - rel.y * mouse_sensitivity, -1.45, 1.45)
		if head != null:
			head.basis = Basis4D.from_yz(pitch)
	ground = Ground.cleaned(ground)
	basis = ground


func _physics_process(delta: float) -> void:
	var up := Vector4(0, 1, 0, 0)
	var before: Vector4 = global_position
	if not _align.is_empty():
		_step_align(delta)
	var ix: float = 0.0
	var iz: float = 0.0
	w_input = 0.0
	var running: bool = false
	if input_enabled and _align.is_empty():
		ix = Input.get_axis(&"move_left", &"move_right")
		iz = Input.get_axis(&"move_forward", &"move_back")
		if w_enabled:
			w_input = Input.get_axis(&"move_kata", &"move_ana")
		running = Input.is_key_pressed(KEY_SHIFT)
	var dir: Vector4 = ground.x * ix + ground.z * iz
	if dir.length_squared() > 1.0:
		dir = dir.normalized()
	var top: float = sprint_speed if running else walk_speed
	_plane = _toward(_plane, dir * top, accel * delta)
	var want_w: float = w_input * w_speed
	if absf(w_input) < 0.01 and absf(_wheel_left) > 0.005:
		want_w = signf(_wheel_left) * w_speed
	if not _align.is_empty():
		want_w = 0.0
		_normal = 0.0
	_normal = move_toward(_normal, want_w, w_accel * delta)
	if is_on_floor() and _vy < 0.0:
		_vy = -0.5
	else:
		_vy -= gravity * delta
	var v: Vector4 = _plane + ground.w * _normal + up * _vy
	if not _align.is_empty():
		v = up * _vy
	set("linear_velocity", v)
	move_and_slide(delta)
	var moved: Vector4 = global_position - before
	var along_w: float = moved.dot(ground.w)
	w_rate = along_w / maxf(delta, 0.0001)
	if absf(_wheel_left) > 0.005 and absf(w_input) < 0.01 and _align.is_empty():
		var used: float = along_w if signf(along_w) == signf(_wheel_left) else 0.0
		_wheel_left = move_toward(_wheel_left, 0.0, maxf(absf(used), 0.0))
		# Nudging against a stop ends the nudge.
		if absf(along_w) < 0.0005:
			_wheel_left = 0.0
	var pushing: float = w_input
	if absf(pushing) < 0.01 and absf(_wheel_left) > 0.005:
		pushing = signf(_wheel_left)
	if absf(pushing) > 0.01 and absf(along_w) < 0.15 * w_speed * delta and absf(_normal) > 0.5 * w_speed:
		_blocked_for += delta
	else:
		_blocked_for = 0.0
		_knocked = false
	w_blocked = _blocked_for > 0.06
	if w_blocked:
		_normal = 0.0
		if not _knocked:
			_knocked = true
			w_knock.emit(signf(pushing))
	# The velocity the engine left us (a wall stops the plane part, a W stop the normal part).
	var lv: Vector4 = get("linear_velocity")
	_vy = lv.y
	ground = Ground.cleaned(ground)
	basis = ground


## Vector4 has no move_toward: `a` moved toward `b` by at most `d`.
static func _toward(a: Vector4, b: Vector4, d: float) -> Vector4:
	var gap: Vector4 = b - a
	var n: float = gap.length()
	if n <= d or n < 0.000001:
		return b
	return a + gap / n * d


func _step_align(delta: float) -> void:
	_align["t"] = float(_align["t"]) + delta / float(_align["dur"])
	var t: float = clampf(float(_align["t"]), 0.0, 1.0)
	var e: float = t * t * (3.0 - 2.0 * t)
	var b1 = _align["b1"]
	if b1 != null:
		var b0: Projection = _align["b0"]
		var rel: Quaternion = Ground._to_3d(Basis4D.transposed(b0) * (b1 as Projection)).get_rotation_quaternion()
		if rel.w < 0.0:
			rel = -rel
		ground = Ground.cleaned(b0 * Ground._from_3d(Basis(Quaternion.IDENTITY.slerp(rel, e))))
		basis = ground
	if not is_nan(float(_align["w1"])):
		var want: float = lerpf(float(_align["w0"]), float(_align["w1"]), e)
		var dw: float = want - global_position.w
		if absf(dw) > 0.00001:
			# Through the collision like any move: a V never puts you inside a wall.
			move_and_collide(Vector4(0, 0, 0, dw), false)
	if t >= 1.0:
		_align.clear()
		_plane = Vector4.ZERO
		_normal = 0.0
		_wheel_left = 0.0
