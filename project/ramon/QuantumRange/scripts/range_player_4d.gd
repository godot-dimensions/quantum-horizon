extends CharacterBody4D

## The range's first-person player. Built in code (make()), so the range never instances the project's
## shared player.tscn, whose Escape opens the old team menu and whose position label prints over the HUD
## (follow_up/quantum_range.md, findings 2 and 4).
##
## HOW THE 4D CONTROLS COMPOSE (CLAUDE.md, the player controller's own conventions):
##   - turning (yaw, Basis4D.from_zx) and the slice turn (Basis4D.from_xw / from_zw while the right
##     mouse button is held) go on this body's own basis;
##   - the pitch goes on the head only, set absolutely and clamped, so it never leaks into the slice or
##     into anything that asks which way the player faces (bearing, the radar, the snap);
##   - every frame the body's basis is put back to y = (0, 1, 0, 0) and orthonormalised, so repeated
##     turns never drift.
##
## THROUGH W: Q and E step kata and ana along your own W (the way your slice faces), but never further
## than `w_limit` from the room's middle slice (world w): beyond that you turn your slice to reach things
## (the range's stage C of Locate & Align is built on that). X eases the slice back to the room's own,
## keeping the way you face (4D Golf's lesson: axis-aligned slices are the easy ones to read).
##
## NO class_name (engine_gotchas.md): preload it and call make().

const EYE := 0.72
const RADIUS := 0.25
const HEIGHT := 1.75
const MOUSE := 0.0022
const SLICE_MOUSE := 0.0018
const PITCH_LIMIT := 1.45

@export var walk_speed: float = 4.2
@export var sprint_speed: float = 7.0
## How fast Q and E step through W, metres a second.
@export var w_speed: float = 2.2
## How far either way through W you can step yourself (world w).
@export var w_limit: float = 2.0
## Seconds X takes to bring the slice back.
@export var snap_seconds: float = 0.35
@export var input_enabled: bool = true
## The slice turn is allowed (off in the corridor if a scene wants it).
@export var slice_turning: bool = true
## You never go further downrange than this (world z): you play from the line. A limit in the
## movement, not an invisible wall: a wall over the counter stopped every shot too.
@export var min_z: float = -INF

var head: Node4D
var camera: Camera4D
var pitch: float = 0.0
## Metres travelled through W and degrees the slice was turned, since reset_counters(): the metrics wall
## shows both for every experiment.
var w_travelled: float = 0.0
var slice_turned: float = 0.0
## Something else (a menu, a card) holds the mouse: no look, no slice turn.
var look_locked: bool = false

var _snap_from: Projection
var _snap_to: Projection
var _snap_t: float = -1.0
var _last_w: float = 0.0


static func make() -> CharacterBody4D:
	var p := CharacterBody4D.new()
	p.name = "Player"
	p.set_script(load("res://ramon/QuantumRange/scripts/range_player_4d.gd"))
	var shape := CollisionShape4D.new()
	shape.name = "Capsule"
	var cap := CapsuleShape4D.new()
	cap.radius = RADIUS
	cap.full_height = HEIGHT
	shape.shape = cap
	p.add_child(shape)
	var h := Node4D.new()
	h.name = "Head"
	h.position = Vector4(0.0, EYE, 0.0, 0.0)
	p.add_child(h)
	var cam := Camera4D.new()
	cam.name = "Camera"
	cam.set("rendering_engine_name", "Cross-section")
	cam.set("view_angle_type", 1)
	cam.set("field_of_view_4d", 1.3962634)
	cam.current = true
	h.add_child(cam)
	return p


func _ready() -> void:
	head = get_node("Head") as Node4D
	camera = get_node("Head/Camera") as Camera4D
	_last_w = global_position.w


## Puts the player at `at` (feet on the floor at at.y), facing `yaw` (0 is -Z), the slice the room's own.
func place(at: Vector4, yaw: float = 0.0) -> void:
	global_position = at + Vector4(0.0, HEIGHT * 0.5, 0.0, 0.0)
	basis = Basis4D.from_zx(yaw)
	pitch = 0.0
	if head != null:
		head.basis = Projection.IDENTITY
	linear_velocity = Vector4.ZERO
	_snap_t = -1.0
	_last_w = global_position.w


func reset_counters() -> void:
	w_travelled = 0.0
	slice_turned = 0.0


## Which way you face along the floor (0 is -Z, positive turns towards +X... as Basis4D.from_zx).
func yaw() -> float:
	var f: Vector4 = -basis.z
	return atan2(-f.x, -f.z)


## How far the slice is turned off the room's own, degrees (0: you see the room's x, y and z).
func slice_angle() -> float:
	return rad_to_deg(acos(clampf(absf(basis.w.w), 0.0, 1.0)))


## The look and the slice turn, by mouse movement in pixels (the runners call these too).
func look(rel: Vector2) -> void:
	var b: Projection = basis
	b *= Basis4D.from_zx(-rel.x * MOUSE)
	basis = _upright(b)
	pitch = clampf(pitch - rel.y * MOUSE, -PITCH_LIMIT, PITCH_LIMIT)
	head.basis = Basis4D.from_yz(pitch)


func turn_slice(rel: Vector2) -> void:
	if not slice_turning:
		return
	var before: float = slice_angle()
	var b: Projection = basis
	b *= Basis4D.from_xw(-rel.x * SLICE_MOUSE) * Basis4D.from_zw(rel.y * SLICE_MOUSE)
	basis = _upright(b)
	slice_turned += absf(slice_angle() - before)
	_snap_t = -1.0


## Turns to look straight at world point `p`, within your slice (the runners use it; a point off your
## slice is looked at where its shadow on your slice lies).
func aim_at(p: Vector4) -> void:
	var eye: Vector4 = camera.global_position if camera != null else global_position
	var d: Vector4 = basis.inverse() * (p - eye)
	var turn: float = atan2(-d.x, -d.z)
	basis = _upright(basis * Basis4D.from_zx(turn))
	var flat: float = Vector2(d.x, d.z).length()
	pitch = clampf(atan2(d.y, maxf(flat, 0.0001)), -PITCH_LIMIT, PITCH_LIMIT)
	head.basis = Basis4D.from_yz(pitch)


## Eases the slice back to the room's own, keeping the way you face.
func snap_slice() -> void:
	_snap_from = basis
	_snap_to = level_basis()
	_snap_t = 0.0


## The basis you would have with the slice turned back: the way you face, flattened onto the room's x and z.
func level_basis() -> Projection:
	var f: Vector4 = -basis.z
	var flat := Vector2(f.x, f.z)
	var y: float = atan2(-flat.x, -flat.y) if flat.length() > 0.001 else yaw()
	return Basis4D.from_zx(y)


func _upright(b: Projection) -> Projection:
	b.y = Vector4(0, 1, 0, 0)
	return Basis4D.orthonormalized(b)


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	var mm := event as InputEventMouseMotion
	if mm != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not look_locked:
		if (mm.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
			turn_slice(mm.relative)
		else:
			look(mm.relative)
		get_viewport().set_input_as_handled()
		return
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_X:
		snap_slice()
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if _snap_t >= 0.0:
		_snap_t = minf(1.0, _snap_t + delta / maxf(snap_seconds, 0.01))
		var k: float = _snap_t * _snap_t * (3.0 - 2.0 * _snap_t)
		var before: float = slice_angle()
		var b := Projection(_snap_from.x.lerp(_snap_to.x, k), _snap_from.y.lerp(_snap_to.y, k), _snap_from.z.lerp(_snap_to.z, k), _snap_from.w.lerp(_snap_to.w, k))
		basis = _upright(b)
		slice_turned += absf(slice_angle() - before)
		if _snap_t >= 1.0:
			basis = _snap_to
			_snap_t = -1.0
	else:
		basis = _upright(basis)
	if not is_on_floor():
		linear_velocity += get_gravity() * delta
	var dir := Vector4.ZERO
	var dw: float = 0.0
	if input_enabled:
		dir = Vector4(Input.get_axis(&"move_left", &"move_right"), 0.0, Input.get_axis(&"move_forward", &"move_back"), 0.0)
		dw = Input.get_axis(&"move_kata", &"move_ana")
		if Input.is_action_just_pressed(&"move_jump") and is_on_floor():
			linear_velocity.y = 4.2
	var speed: float = sprint_speed if Input.is_key_pressed(KEY_SHIFT) else walk_speed
	var move: Vector4 = basis * dir
	move = Vector4(move.x, 0.0, move.z, move.w)
	if move.length() > 0.001:
		move = move.normalized() * speed
	# Q and E along your own W, at their own pace.
	move += basis.w * (dw * w_speed)
	linear_velocity.x = move.x
	linear_velocity.z = move.z
	linear_velocity.w = move.w
	move_and_slide()
	# Never further through W than the bay allows: you turn your slice to reach past it.
	var p: Vector4 = global_position
	if p.z < min_z:
		p.z = min_z
		global_position = p
		linear_velocity.z = maxf(linear_velocity.z, 0.0)
	if absf(p.w) > w_limit:
		p.w = clampf(p.w, -w_limit, w_limit)
		global_position = p
		linear_velocity.w = 0.0
	w_travelled += absf(global_position.w - _last_w)
	_last_w = global_position.w
