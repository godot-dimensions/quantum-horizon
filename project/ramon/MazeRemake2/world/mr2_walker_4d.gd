extends CharacterBody4D
## THE TALL ONES: the Annex's walkers (Ramon, 11 Oct: "elongated creepy walkers. they are grey, have
## rigid animation and loft techniques in how they are build. there animation is subtle.. they dont
## notice you, but when they do, their tiny eyes grow red and they start walking to you.. not fast though,
## but they walk. and they can kill you. and you have to quickly make it to another slice").
##
## THE BODY is lofted (the Dreamer's loft builder, carried): one short tapered tube, lofted once and
## stretched into every limb, plus a tapered skull. About 2.9 m tall and very thin, the arms hanging past
## the knees. Grey, unlit by anything of its own; two tiny eyes that are a pale glint until it notices you,
## then grow red. Every piece is thick through W only to WTHICK either side, so it is there in a slice
## within that of its own W, thinning as you shift away, gone beyond.
##
## RIGID: each limb is one stiff segment turning at its joint (no skinning, no bending between joints).
## Idle, it sways a degree or two and turns its head slowly; walking, its legs swing stiffly, a slow,
## heavy stride.
##
## ITS SLICE IS ITS WORLD. It lives at one W and never moves through W; its body collides only with what is
## at its W. It sees you only when you are in its slice (within NOTICE_W of its W), close, in front and
## with no wall between. Then it stops, its eyes grow red over a moment, and it walks to you, slower than
## you walk. In its slice and within reach, it kills you. Out of its slice for LOSE_S, or far off, it
## loses you; the red fades and it goes back to its post. So the way out is another slice.
##
## The level places it (mr2_level_4d.gd add_walker); the game hears `caught` (and resets it on a respawn).

const LoftBuilder := preload("res://ramon/MazeRemake2/carried/dreamer/loft_builder_4d.gd")
const LabGrid := preload("res://ramon/MazeRemake2/carried/lab_grid.gd")
const Build := preload("res://ramon/MazeRemake2/world/mr2_build.gd")

signal noticed(walker: Node)
signal caught(walker: Node)
signal lost(walker: Node)

## Its W half-thickness: what of it shows in a slice this far from its own W.
const WTHICK := 0.55
## How near your W must be to its own for it to see you (and for it to reach you).
const NOTICE_W := 0.5
const LOSE_S := 3.0

@export var notice_range: float = 9.0
@export var walk_speed: float = 1.15
@export var turn_rate: float = 1.1
## Where it stands and faces when it is not after you (set by the level).
var post: Vector4 = Vector4.ZERO
var post_yaw: float = 0.0
## A slow pacing beat between the post and this point (Vector4.INF: it stands still).
var pace_to: Vector4 = Vector4.INF
var game: Node = null
var player: Node4D = null
var level_body: Node = null
## "idle", "notice", "hunt", "return", "film"
var state: String = "idle"
var red: float = 0.0
var yaw: float = 0.0
var head_turn: float = 0.0
var head_target: float = 0.0
var _t: float = 0.0
var _notice_t: float = 0.0
var _lost_t: float = 0.0
var _stride: float = 0.0
var _speed_now: float = 0.0
var _pace_leg: int = 0
var _pace_wait: float = 0.0
var _joints: Dictionary = {}
var _eyes: Array[MeshInstance4D] = []
var _eye_mats: Array[TetraMaterial4D] = []
var _body: Node4D
var _step_side: int = 0
var _film_t: float = 0.0
var _film_cam: Node4D = null
static var _segment: ArrayTetraMesh4D = null
static var _skull: ArrayTetraMesh4D = null
static var _mat: TetraMaterial4D = null


func _ready() -> void:
	set("snap_to_floor", true)
	set("snap_distance", 0.15)
	var cs := CollisionShape4D.new()
	var box := BoxShape4D.new()
	box.size = Vector4(0.5, 2.7, 0.5, WTHICK)
	cs.shape = box
	cs.position = Vector4(0, 1.35, 0, 0)
	add_child(cs)
	_make_meshes()
	_build_body()
	reset()


## Back at its post, calm (a respawn, a level start).
func reset() -> void:
	state = "idle"
	red = 0.0
	_notice_t = 0.0
	_lost_t = 0.0
	_speed_now = 0.0
	global_position = Vector4(post.x, post.y + 0.0, post.z, post.w)
	yaw = post_yaw
	head_turn = 0.0
	head_target = 0.0
	_apply_eyes()


static func _make_meshes() -> void:
	if _segment != null:
		return
	# A segment of tube along y from 0 to 1, a little narrower at the far end, with rounded caps.
	_segment = LoftBuilder.build([
		{"center": Vector4(0, -0.06, 0, 0), "radius": 0.6, "w_scale": 1.0},
		{"center": Vector4(0, 0.0, 0, 0), "radius": 1.0, "w_scale": 1.0},
		{"center": Vector4(0, 1.0, 0, 0), "radius": 0.72, "w_scale": 1.0},
		{"center": Vector4(0, 1.06, 0, 0), "radius": 0.45, "w_scale": 1.0},
	], 3, 8, true, false, true, 1, false)
	# The skull: long and narrow, widest a third of the way up, tapering to the crown.
	_skull = LoftBuilder.build([
		{"center": Vector4(0, -0.05, 0, 0), "radius": 0.45, "w_scale": 1.0},
		{"center": Vector4(0, 0.0, 0, 0), "radius": 0.8, "w_scale": 1.0},
		{"center": Vector4(0, 0.35, 0, 0), "radius": 1.0, "w_scale": 1.0},
		{"center": Vector4(0, 0.8, 0, 0), "radius": 0.75, "w_scale": 1.0},
		{"center": Vector4(0, 1.0, 0, 0), "radius": 0.3, "w_scale": 1.0},
	], 4, 8, true, false, true, 1, false)
	LabGrid.set_swatch("mr2_walker", Color(0.27, 0.28, 0.30), Color(0.23, 0.24, 0.26), Color(0.25, 0.26, 0.28), 0.12)
	_mat = LabGrid.material("mr2_walker", Vector4.ONE, Vector4.ZERO)


## A joint (a Node4D) under `parent` at `at`, and a stiff piece hanging from it along `dir` (down is -y),
## `length` long and `radius` thick.
func _limb(parent: Node4D, name: String, at: Vector4, length: float, radius: float, down: bool = true, mesh: Mesh4D = null) -> Node4D:
	var j := Node4D.new()
	j.name = name
	j.position = at
	parent.add_child(j)
	var piece := MeshInstance4D.new()
	piece.mesh = mesh if mesh != null else _segment
	piece.material_override = _mat
	# The segment runs +y from 0 to 1; a hanging limb points down.
	piece.basis = _rs(Basis4D.from_xy(PI) if down else Projection.IDENTITY, Vector4(radius, length, radius, WTHICK))
	j.add_child(piece)
	_joints[name] = j
	return j


func _build_body() -> void:
	_body = Node4D.new()
	_body.name = "Body"
	add_child(_body)
	var hip_y: float = 1.42
	var pelvis := Node4D.new()
	pelvis.name = "Pelvis"
	pelvis.position = Vector4(0, hip_y, 0, 0)
	_body.add_child(pelvis)
	_joints["pelvis"] = pelvis
	# The trunk: up from the pelvis, thin, a little forward-leaning.
	var spine: Node4D = _limb(pelvis, "spine", Vector4.ZERO, 0.78, 0.085, false)
	var neck: Node4D = _limb(spine, "neck", Vector4(0, 0.8, 0, 0), 0.26, 0.035, false)
	var head: Node4D = _limb(neck, "head", Vector4(0, 0.27, 0, 0), 0.30, 0.085, false, _skull)
	# Two tiny eyes on the front of the skull (forward is -z).
	for side in [-1.0, 1.0]:
		var eye := MeshInstance4D.new()
		var m := OrthoplexTetraMesh4D.new()
		m.size = Vector4(0.028, 0.02, 0.028, WTHICK * 1.2)
		eye.mesh = m
		eye.position = Vector4(side * 0.032, 0.13, -0.075, 0)
		var em: TetraMaterial4D = Build.glow_material(Color(0.75, 0.78, 0.8), 1.0)
		eye.material_override = em
		head.add_child(eye)
		_eyes.append(eye)
		_eye_mats.append(em)
	# Shoulders: a thin bar across the top of the trunk, the arms hanging from its ends.
	var yoke := MeshInstance4D.new()
	yoke.mesh = _segment
	yoke.material_override = _mat
	yoke.position = Vector4(-0.24, 0.74, 0, 0)
	yoke.basis = _rs(Basis4D.from_xy(-PI * 0.5), Vector4(0.04, 0.48, 0.04, WTHICK))
	spine.add_child(yoke)
	for side in [-1.0, 1.0]:
		var s: String = "l" if side < 0.0 else "r"
		var upper: Node4D = _limb(spine, s + "_arm", Vector4(side * 0.24, 0.74, 0, 0), 0.72, 0.034)
		var fore: Node4D = _limb(upper, s + "_fore", Vector4(0, -0.72, 0, 0), 0.78, 0.028)
		_limb(fore, s + "_hand", Vector4(0, -0.78, 0, 0), 0.22, 0.02)
		var thigh: Node4D = _limb(pelvis, s + "_thigh", Vector4(side * 0.11, 0, 0, 0), 0.72, 0.05)
		var shin: Node4D = _limb(thigh, s + "_shin", Vector4(0, -0.72, 0, 0), 0.7, 0.038)
		var foot := MeshInstance4D.new()
		foot.mesh = _segment
		foot.material_override = _mat
		foot.position = Vector4(0, -0.7, 0.02, 0)
		foot.basis = _rs(Basis4D.from_yz(-PI * 0.5), Vector4(0.035, 0.2, 0.025, WTHICK))
		shin.add_child(foot)


## A rotation with each axis stretched (the basis carries the scale; Node4D's own scale is read back out
## of it, so setting both invites drift).
static func _rs(rot: Projection, s: Vector4) -> Projection:
	var p: Projection = rot
	p.x = rot.x * s.x
	p.y = rot.y * s.y
	p.z = rot.z * s.z
	p.w = rot.w * s.w
	return p


func _apply_eyes() -> void:
	var c: Color = Color(0.72, 0.74, 0.76).lerp(Color(1.0, 0.08, 0.05), red)
	for m in _eye_mats:
		m.get_cross_section_material_3d().set_shader_parameter("glow_color", c)
		m.get_cross_section_material_3d().set_shader_parameter("glow_energy", 1.0 + red * 1.5)
	for e in _eyes:
		var k: float = 1.0 + red * 0.9
		e.basis = _rs(Projection.IDENTITY, Vector4(k, k, k, 1.0))


## Straight to the hunt (the kennel's ambush): the eyes go red as it walks.
func hunt_now() -> void:
	state = "hunt"
	_lost_t = 0.0
	red = maxf(red, 0.3)


## The first-sighting film: it stops, and turns its head to the film's camera.
func start_film(cam: Node4D) -> void:
	state = "film"
	_film_t = 0.0
	_film_cam = cam


func end_film() -> void:
	state = "idle"
	red = 0.0
	_film_cam = null


## Is the player in my slice, close, in front of me, with nothing between?
func sees_player() -> bool:
	if player == null or not player.is_inside_tree():
		return false
	var p: Vector4 = player.global_position
	if absf(p.w - global_position.w) > NOTICE_W:
		return false
	var d := Vector2(p.x - global_position.x, p.z - global_position.z)
	var dist: float = d.length()
	if dist > notice_range:
		return false
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	if dist > 1.5 and fwd.dot(d / dist) < cos(deg_to_rad(80.0)):
		return false
	return clear_line_to(p + Vector4(0, 0.6, 0, 0))


## Nothing of the level between my eyes and `target` (a ray at my W through the level's solids).
func clear_line_to(target: Vector4) -> bool:
	var eye: Vector4 = global_position + Vector4(0, 2.6, 0, 0)
	var tgt := Vector4(target.x, target.y, target.z, global_position.w)
	var gap: Vector4 = tgt - eye
	var dist: float = gap.length()
	if dist < 0.01:
		return true
	var rp := RaycastParameters4D.new()
	rp.global_ray_origin = eye
	rp.global_ray_direction = gap / dist
	rp.max_distance = dist
	var ex: Array = [self]
	if player != null:
		ex.append(player)
	rp.set_exclude_nodes(ex)
	var r: Dictionary = PhysicsServer4D.raycast_physics_objects(rp)
	return not bool(r.get("hit", false))


func _physics_process(delta: float) -> void:
	_t += delta
	var want_speed: float = 0.0
	var target_yaw: float = yaw
	match state:
		"idle":
			red = move_toward(red, 0.0, delta * 0.6)
			_idle_pace(delta)
			want_speed = _speed_pace_target()
			if want_speed > 0.0:
				target_yaw = _yaw_to(pace_to if _pace_leg == 1 else post)
			else:
				target_yaw = post_yaw if pace_to == Vector4.INF else yaw
			if sees_player():
				state = "notice"
				_notice_t = 0.0
				noticed.emit(self)
		"notice":
			_notice_t += delta
			red = minf(1.0, red + delta * 1.6)
			target_yaw = _yaw_to(player.global_position)
			head_target = 0.0
			if _notice_t > 0.9:
				state = "hunt"
				_lost_t = 0.0
		"hunt":
			red = minf(1.0, red + delta * 2.0)
			var p: Vector4 = player.global_position
			target_yaw = _yaw_to(p)
			want_speed = walk_speed
			var in_slice: bool = absf(p.w - global_position.w) <= NOTICE_W
			var dist: float = Vector2(p.x - global_position.x, p.z - global_position.z).length()
			if in_slice and dist < 0.95 and absf(p.y - global_position.y) < 1.8:
				caught.emit(self)
				state = "return"
			if not in_slice or dist > 22.0:
				_lost_t += delta
				if _lost_t > LOSE_S:
					state = "return"
					lost.emit(self)
			else:
				_lost_t = 0.0
		"return":
			red = move_toward(red, 0.0, delta * 0.5)
			var to_post := Vector2(post.x - global_position.x, post.z - global_position.z)
			if to_post.length() < 0.3:
				state = "idle"
			else:
				target_yaw = _yaw_to(post)
				want_speed = walk_speed * 0.7
			if sees_player() and red < 0.5:
				state = "notice"
				_notice_t = 0.0
				noticed.emit(self)
		"film":
			# Its film: the head turns, slowly, to the camera; the eyes flicker red once and go pale.
			_film_t += delta
			if is_instance_valid(_film_cam):
				var d := Vector2(_film_cam.global_position.x - global_position.x, _film_cam.global_position.z - global_position.z)
				head_target = clampf(wrapf(atan2(-d.x, -d.y) - yaw, -PI, PI), -1.3, 1.3)
			var ft: float = _film_t - 3.2
			red = clampf(sin(ft * 3.0), 0.0, 1.0) * 0.85 if (ft > 0.0 and ft < 1.05) else 0.0
	# A stiff turn toward where it is going, then a step only when it more or less faces it.
	var dy: float = wrapf(target_yaw - yaw, -PI, PI)
	yaw += clampf(dy, -turn_rate * delta, turn_rate * delta)
	if absf(dy) > 0.6:
		want_speed = 0.0
	_speed_now = move_toward(_speed_now, want_speed, delta * 1.5)
	var fwd := Vector4(-sin(yaw), 0, -cos(yaw), 0)
	var vy: float = (get("linear_velocity") as Vector4).y
	vy = -0.5 if is_on_floor() else vy - 18.0 * delta
	set("linear_velocity", fwd * _speed_now + Vector4(0, vy, 0, 0))
	move_and_slide(delta)
	# Its W never changes.
	if absf(global_position.w - post.w) > 0.0001:
		global_position = Vector4(global_position.x, global_position.y, global_position.z, post.w)
	_pose(delta)
	_apply_eyes()


func _yaw_to(p: Vector4) -> float:
	var d := Vector2(p.x - global_position.x, p.z - global_position.z)
	if d.length() < 0.01:
		return yaw
	return atan2(-d.x, -d.y)


## Pacing: to its second point and back, a long pause at each end.
func _idle_pace(delta: float) -> void:
	if pace_to == Vector4.INF:
		return
	if _pace_wait > 0.0:
		_pace_wait -= delta
		return
	var goal: Vector4 = pace_to if _pace_leg == 1 else post
	if Vector2(goal.x - global_position.x, goal.z - global_position.z).length() < 0.25:
		_pace_leg = 1 - _pace_leg
		_pace_wait = 4.0 + fmod(_t * 7.31, 3.0)


func _speed_pace_target() -> float:
	if pace_to == Vector4.INF or _pace_wait > 0.0:
		return 0.0
	return walk_speed * 0.45


## The stiff pose: a slow sway and head turn standing; a heavy, stiff stride walking.
func _pose(delta: float) -> void:
	_body.basis = Basis4D.from_zx(yaw)
	var moving: float = clampf(_speed_now / maxf(walk_speed, 0.01), 0.0, 1.0)
	_stride += delta * (0.2 + moving * 1.5) * TAU * 0.5
	var swing: float = sin(_stride) * 0.36 * moving
	var lift: float = maxf(0.0, -cos(_stride)) * 0.4 * moving
	var lift2: float = maxf(0.0, cos(_stride)) * 0.4 * moving
	# The head: in idle it turns now and then, slowly, to look at nothing.
	if state == "idle" and fmod(_t, 7.0) < delta:
		head_target = (fmod(_t * 3.17, 2.0) - 1.0) * 0.9
	head_turn = move_toward(head_turn, head_target if (state == "idle" or state == "film") else 0.0, delta * (0.6 if state == "film" else 0.45))
	var sway: float = sin(_t * 0.7) * 0.025
	(_joints["pelvis"] as Node4D).position = Vector4(0, 1.42 - absf(sin(_stride)) * 0.03 * moving, 0, 0)
	(_joints["spine"] as Node4D).basis = Basis4D.from_yz(-0.08 - 0.05 * moving) * Basis4D.from_xy(sway)
	(_joints["neck"] as Node4D).basis = Basis4D.from_yz(0.18)
	(_joints["head"] as Node4D).basis = Basis4D.from_zx(head_turn) * Basis4D.from_yz(-0.1)
	(_joints["l_thigh"] as Node4D).basis = Basis4D.from_yz(swing)
	(_joints["r_thigh"] as Node4D).basis = Basis4D.from_yz(-swing)
	(_joints["l_shin"] as Node4D).basis = Basis4D.from_yz(-lift)
	(_joints["r_shin"] as Node4D).basis = Basis4D.from_yz(-lift2)
	var arm: float = -swing * 0.35 + sin(_t * 0.6) * 0.02
	(_joints["l_arm"] as Node4D).basis = Basis4D.from_yz(arm) * Basis4D.from_xy(-0.06)
	(_joints["r_arm"] as Node4D).basis = Basis4D.from_yz(-arm) * Basis4D.from_xy(0.06)
	(_joints["l_fore"] as Node4D).basis = Basis4D.from_yz(-0.12)
	(_joints["r_fore"] as Node4D).basis = Basis4D.from_yz(-0.12)
	# A footfall: the game's sound hears it.
	var side: int = 1 if sin(_stride) > 0.0 else -1
	if moving > 0.3 and side != _step_side:
		_step_side = side
		if game != null:
			game.call("walker_step", self)
