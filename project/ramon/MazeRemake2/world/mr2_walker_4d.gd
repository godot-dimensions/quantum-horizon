extends CharacterBody4D
## THE TALL ONES: the Annex's walkers (Ramon, 11 Oct: "elongated creepy walkers. they are grey, have
## rigid animation and loft techniques in how they are build. there animation is subtle.. they dont
## notice you, but when they do, their tiny eyes grow red and they start walking to you.. not fast though,
## but they walk. and they can kill you. and you have to quickly make it to another slice").
##
## THE BODY (12 Oct, Ramon: "make the walkers more lofted humanoid beings. study the creationlab and how
## animals where build there"): a lofted humanoid, built the Creature Lab's way (see _piece_lofts below).
## About 2.9 m tall and very thin: a narrow waist, a long ribbed cage, a long neck, a small elongated skull
## swept back with a dark band across the eyes, arms hanging below the knees with long four-fingered hands,
## long shins and flat feet. Grey in four tones. Two tiny eyes that are a pale glint until it notices you,
## then grow red. Every piece is thick through W (the limbs a little less than the trunk), so it is there
## in a slice near its own W, thinning as you shift away, limbs first, gone beyond.
##
## RIGID: sixteen stiff pieces turning at their joints (no skinning, no bending between joints). Idle, it
## breathes, sways a degree or two, and now and then turns or tilts its head, slowly; walking, a stiff,
## heavy stride, the feet kept flat.
##
## ITS SLICE IS ITS WORLD. It lives at one W and never moves through W; its body collides only with what is
## at its W. It sees you only when you are in its slice (within NOTICE_W of its W), close, in front and
## with no wall between. Then it stops, its eyes grow red over a moment, and it walks to you, slower than
## you walk. In its slice and within reach, it kills you. Out of its slice for LOSE_S, or far off, it
## loses you; the red fades and it goes back to its post. So the way out is another slice.
##
## The level places it (mr2_level_4d.gd add_walker); the game hears `caught` (and resets it on a respawn).

const LoftBuilder := preload("res://ramon/MazeRemake2/carried/dreamer/loft_builder_4d.gd")
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
var _tilt: float = 0.0
var _tilt_target: float = 0.0
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
## The lofted pieces, shared by every Tall One: name -> [mesh, material].
static var _pieces: Dictionary = {}


func _ready() -> void:
	set("snap_to_floor", true)
	set("snap_distance", 0.15)
	var cs := CollisionShape4D.new()
	var box := BoxShape4D.new()
	box.size = Vector4(0.5, 2.8, 0.5, WTHICK)
	cs.shape = box
	cs.position = Vector4(0, 1.4, 0, 0)
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


## THE BODY, lofted the way the Creature Lab's animals are: chains of shaped cross-sections (the wolf's
## and horse's balls, as data here), each with its own colour baked into a ramp along the piece, and cut
## into rigid pieces as the Aquatic Lab's hammerhead is (lofted once, shared by every Tall One, then only
## the joints turn). Every section is a round ball shaped by its own basis, so a palm can be thin across
## and wide front to back whichever way its spine runs.
##
## Piece-local: the joint at the origin, forward -z, a hanging limb running down -y. Each piece is a list
## of lofts (the hand is five: a palm and four long fingers), each loft its sections from end to end.
## Heights over the feet: ankle 0.09, knee 0.79, hip 1.51, waist 1.69, shoulders 2.15, skull base 2.44,
## crown 2.92; the fingertips hang to 0.64, below the knees.
const HIP_Y := 1.51
## Four greys, dark: the dark look's lights are set for near-black walls, so a mid grey reads white.
const C_SKIN := Color(0.19, 0.195, 0.21)
const C_PALE := Color(0.26, 0.265, 0.28)
const C_DARK := Color(0.10, 0.105, 0.115)
const C_DEEP := Color(0.035, 0.035, 0.04)
## W half-thickness of the trunk and head, and of the limbs: the limbs thin out of your slice first as
## you shift away, the trunk last (WTHICK, about where it can no longer see you).
const W_TRUNK := 0.5
const W_LIMB := 0.42


## A section whose spine runs along y: half width `hx` (its radius), half depth `hz`, half W `hw`, at
## height `y`, its middle at (`x`, `z`).
static func _s(y: float, hx: float, hz: float, hw: float, col: Color, x: float = 0.0, z: float = 0.0, sq: float = 0.0) -> Dictionary:
	return {"center": Vector4(x, y, z, 0.0), "radius": hx, "v_scale": 1.0, "w_scale": 1.0,
		"basis": _sc(1.0, 1.0, hz / hx, hw / hx), "color": col, "squareness": sq}


## A section whose spine runs along z (the foot): half width `hx`, half height `hy`, half W `hw`.
static func _f(z: float, hx: float, hy: float, hw: float, col: Color, y: float) -> Dictionary:
	return {"center": Vector4(0.0, y, z, 0.0), "radius": hx, "v_scale": 1.0, "w_scale": 1.0,
		"basis": _sc(1.0, hy / hx, 1.0, hw / hx), "color": col}


static func _sc(x: float, y: float, z: float, w: float) -> Projection:
	return Projection(Vector4(x, 0, 0, 0), Vector4(0, y, 0, 0), Vector4(0, 0, z, 0), Vector4(0, 0, 0, w))


## [lofts, rings, sides] per piece.
static func _piece_lofts() -> Dictionary:
	var T: float = W_TRUNK
	var L: float = W_LIMB
	var fingers: Array = []
	for f in [[-0.03, 0.32], [-0.01, 0.37], [0.01, 0.36], [0.03, 0.31]]:
		var fz: float = f[0]
		var tip: float = -0.11 - float(f[1]) * 0.7
		fingers.append([_s(-0.11, 0.009, 0.009, L * 0.9, C_DARK, 0.0, fz), _s(lerpf(-0.11, tip, 0.4), 0.008, 0.008, L * 0.9, C_SKIN, 0.0, fz * 1.12 - 0.004),
			_s(lerpf(-0.11, tip, 0.75), 0.006, 0.006, L * 0.85, C_SKIN, 0.0, fz * 1.22 - 0.012), _s(tip, 0.0035, 0.0035, L * 0.8, C_DEEP, 0.0, fz * 1.3 - 0.024)])
	return {
		# The pelvis: from the crotch up to the waist, the hips' joints at its sides.
		"pelvis": [[[_s(-0.13, 0.05, 0.045, T * 0.6, C_DARK), _s(-0.1, 0.09, 0.075, T * 0.8, C_DARK), _s(-0.04, 0.145, 0.1, T, C_SKIN),
			_s(0.04, 0.15, 0.105, T, C_SKIN), _s(0.12, 0.105, 0.088, T, C_SKIN), _s(0.2, 0.08, 0.072, T * 0.9, C_DARK)]], 4, 10],
		# The trunk, from the waist: a narrow waist, a long ribbed cage (alternate sections a little in), the
		# upper back bowed out (+z) and the wide yoke of the shoulders rolled forward over it: a hunch.
		"trunk": [[[_s(-0.03, 0.075, 0.07, T * 0.9, C_DARK), _s(0.03, 0.085, 0.074, T, C_DARK, 0.0, 0.004), _s(0.12, 0.11, 0.088, T, C_SKIN, 0.0, 0.012),
			_s(0.2, 0.135, 0.1, T, C_SKIN, 0.0, 0.02), _s(0.26, 0.15, 0.112, T, C_PALE, 0.0, 0.026, 0.15), _s(0.31, 0.141, 0.106, T, C_SKIN, 0.0, 0.03, 0.15),
			_s(0.36, 0.155, 0.114, T, C_PALE, 0.0, 0.03, 0.15), _s(0.41, 0.15, 0.106, T, C_SKIN, 0.0, 0.026, 0.15), _s(0.46, 0.19, 0.09, T, C_SKIN, 0.0, 0.012, 0.25),
			_s(0.5, 0.17, 0.07, T * 0.9, C_DARK, 0.0, 0.0, 0.25), _s(0.535, 0.06, 0.05, T * 0.7, C_DARK, 0.0, -0.005)]], 4, 10],
		"neck": [[[_s(-0.01, 0.045, 0.042, T * 0.7, C_DARK), _s(0.04, 0.036, 0.036, T * 0.75, C_SKIN), _s(0.12, 0.03, 0.032, T * 0.75, C_SKIN),
			_s(0.19, 0.034, 0.034, T * 0.75, C_SKIN), _s(0.23, 0.045, 0.04, T * 0.8, C_DARK)]], 3, 8],
		# The skull: a long oval face, a dark band across it where the eyes sit, the cranium long and swept back.
		"head": [[[_s(-0.01, 0.035, 0.035, T * 0.8, C_DARK), _s(0.03, 0.056, 0.062, T * 0.85, C_SKIN, 0.0, -0.012), _s(0.09, 0.066, 0.078, T * 0.9, C_PALE, 0.0, -0.016),
			_s(0.145, 0.072, 0.086, T, C_PALE, 0.0, -0.012), _s(0.16, 0.074, 0.088, T, C_DEEP, 0.0, -0.011), _s(0.2, 0.077, 0.091, T, C_DEEP, 0.0, -0.008),
			_s(0.215, 0.078, 0.093, T, C_PALE, 0.0, -0.006), _s(0.29, 0.082, 0.106, T, C_SKIN, 0.0, 0.014), _s(0.38, 0.072, 0.108, T * 0.95, C_SKIN, 0.0, 0.036),
			_s(0.45, 0.048, 0.084, T * 0.85, C_DARK, 0.0, 0.05), _s(0.48, 0.02, 0.035, T * 0.6, C_DARK, 0.0, 0.055)]], 4, 10],
		"upper_arm": [[[_s(0.035, 0.03, 0.03, L * 0.8, C_DARK), _s(0.0, 0.05, 0.05, L, C_SKIN), _s(-0.08, 0.046, 0.044, L, C_SKIN), _s(-0.3, 0.036, 0.034, L, C_SKIN),
			_s(-0.52, 0.03, 0.03, L, C_SKIN), _s(-0.58, 0.034, 0.032, L, C_DARK), _s(-0.61, 0.02, 0.02, L * 0.8, C_DARK)]], 3, 8],
		"forearm": [[[_s(0.02, 0.024, 0.024, L * 0.8, C_DARK), _s(-0.02, 0.032, 0.032, L, C_DARK), _s(-0.1, 0.034, 0.03, L, C_SKIN), _s(-0.35, 0.026, 0.022, L, C_SKIN),
			_s(-0.52, 0.02, 0.016, L, C_SKIN), _s(-0.56, 0.022, 0.018, L, C_DARK), _s(-0.585, 0.012, 0.012, L * 0.8, C_DARK)]], 3, 8],
		# The hand: a palm thin across and wide front to back, and four long fingers curling a little forward.
		"hand": [[[_s(0.01, 0.014, 0.016, L * 0.8, C_DARK), _s(-0.03, 0.016, 0.036, L, C_SKIN), _s(-0.09, 0.014, 0.042, L, C_SKIN), _s(-0.125, 0.012, 0.036, L, C_DARK)]]
			+ fingers, 2, 6],
		"thigh": [[[_s(0.04, 0.04, 0.04, L * 0.8, C_SKIN), _s(0.0, 0.066, 0.07, L, C_SKIN), _s(-0.1, 0.064, 0.066, L, C_SKIN), _s(-0.4, 0.05, 0.05, L, C_SKIN),
			_s(-0.66, 0.04, 0.042, L, C_SKIN), _s(-0.72, 0.044, 0.046, L, C_DARK), _s(-0.755, 0.025, 0.025, L * 0.8, C_DARK)]], 3, 8],
		"shin": [[[_s(0.03, 0.03, 0.03, L * 0.8, C_DARK), _s(-0.01, 0.042, 0.044, L, C_DARK), _s(-0.12, 0.044, 0.05, L, C_SKIN, 0.0, 0.008), _s(-0.4, 0.032, 0.034, L, C_SKIN),
			_s(-0.64, 0.024, 0.026, L, C_SKIN), _s(-0.7, 0.028, 0.028, L, C_DARK), _s(-0.73, 0.015, 0.015, L * 0.8, C_DARK)]], 3, 8],
		# The foot, below the ankle's joint: heel to toe along -z, flat underneath.
		"foot": [[[_f(0.06, 0.02, 0.02, L * 0.8, C_DARK, -0.05), _f(0.03, 0.035, 0.035, L, C_DARK, -0.055), _f(-0.04, 0.04, 0.03, L, C_SKIN, -0.065),
			_f(-0.16, 0.042, 0.02, L, C_SKIN, -0.075), _f(-0.25, 0.034, 0.012, L, C_SKIN, -0.08), _f(-0.29, 0.016, 0.008, L * 0.8, C_DEEP, -0.082)]], 3, 8],
	}


## Lofts every piece once (the first Tall One pays, about a tenth of a second; the rest share them): each
## piece's lofts merged into one mesh, its sections' colours baked into a ramp texture (the loft rig's
## per-ball colour, LabKit/carried/chickenpen/scripts/loft_rig_4d.gd `_apply_ball_colors`).
static func _make_meshes() -> void:
	if not _pieces.is_empty():
		return
	var defs: Dictionary = _piece_lofts()
	for key in defs:
		var def: Array = defs[key]
		var pos := PackedVector4Array()
		var cells := PackedInt32Array()
		var tex_idx := PackedInt32Array()
		var ramp := PackedColorArray()
		for sections in def[0]:
			var m: ArrayTetraMesh4D = LoftBuilder.build(sections, int(def[1]), int(def[2]), true, false, true, 1, false)
			if m == null:
				continue
			var off: int = pos.size()
			var toff: int = ramp.size()
			pos.append_array(m.get_vertex_positions())
			for c in m.get_simplex_cell_vertex_indices():
				cells.append(c + off)
			for t in m.get_simplex_cell_texture_map_indices():
				tex_idx.append(t + toff)
			ramp.append_array(m.get_meta("loft_ramp", PackedColorArray()))
		var mesh := ArrayTetraMesh4D.new()
		mesh.set_vertex_positions(pos)
		mesh.set_simplex_cell_vertex_indices(cells)
		var spread := PackedVector3Array()
		spread.resize(ramp.size())
		for i in ramp.size():
			spread[i] = Vector3((float(i) + 0.5) / float(ramp.size()), 0.5, 0.5)
		mesh.set_texture_map_values(spread)
		mesh.set_simplex_cell_texture_map_indices(tex_idx)
		mesh.calculate_boundary_normals(false)
		var img: Image = Image.create(ramp.size(), 1, false, Image.FORMAT_RGBA8)
		for i in ramp.size():
			img.set_pixel(i, 0, ramp[i])
		var tex := ImageTexture3D.new()
		tex.create(Image.FORMAT_RGBA8, ramp.size(), 1, 1, false, [img])
		var mat := TetraMaterial4D.new()
		mat.set("albedo_source", 3)
		mat.set("albedo_texture_3d", tex)
		_pieces[key] = [mesh, mat]


## A joint (a Node4D) under `parent` at `at`, holding the rigid piece `piece`.
func _joint(parent: Node4D, name: String, at: Vector4, piece: String) -> Node4D:
	var j := Node4D.new()
	j.name = name
	j.position = at
	parent.add_child(j)
	var mi := MeshInstance4D.new()
	mi.name = piece.capitalize().replace(" ", "")
	mi.mesh = _pieces[piece][0]
	mi.material_override = _pieces[piece][1]
	j.add_child(mi)
	_joints[name] = j
	return j


func _build_body() -> void:
	_body = Node4D.new()
	_body.name = "Body"
	add_child(_body)
	var pelvis: Node4D = _joint(_body, "pelvis", Vector4(0, HIP_Y, 0, 0), "pelvis")
	var trunk: Node4D = _joint(pelvis, "spine", Vector4(0, 0.18, 0, 0), "trunk")
	var neck: Node4D = _joint(trunk, "neck", Vector4(0, 0.525, -0.005, 0), "neck")
	var head: Node4D = _joint(neck, "head", Vector4(0, 0.225, 0, 0), "head")
	# Two tiny eyes in the dark band across the face (forward is -z).
	for side in [-1.0, 1.0]:
		var eye := MeshInstance4D.new()
		var m := OrthoplexTetraMesh4D.new()
		m.size = Vector4(0.024, 0.014, 0.02, W_TRUNK * 1.8)
		eye.mesh = m
		eye.position = Vector4(side * 0.03, 0.18, -0.097, 0)
		var em: TetraMaterial4D = Build.glow_material(Color(0.75, 0.78, 0.8), 1.0)
		eye.material_override = em
		head.add_child(eye)
		_eyes.append(eye)
		_eye_mats.append(em)
	for side in [-1.0, 1.0]:
		var s: String = "l" if side < 0.0 else "r"
		var upper: Node4D = _joint(trunk, s + "_arm", Vector4(side * 0.21, 0.455, 0.0, 0), "upper_arm")
		var fore: Node4D = _joint(upper, s + "_fore", Vector4(0, -0.58, 0, 0), "forearm")
		_joint(fore, s + "_hand", Vector4(0, -0.56, 0, 0), "hand")
		var thigh: Node4D = _joint(pelvis, s + "_thigh", Vector4(side * 0.095, 0, 0, 0), "thigh")
		var shin: Node4D = _joint(thigh, s + "_shin", Vector4(0, -0.72, 0, 0), "shin")
		_joint(shin, s + "_foot", Vector4(0, -0.7, 0, 0), "foot")


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


## The stiff pose. Standing: it breathes, sways a degree or two, its knees a little bent, the head jutting
## forward on the long neck; now and then the head turns, or tilts, slowly, to look at nothing. Walking:
## a heavy stride, the swinging leg's knee bending (a leg bends only while it swings forward), the feet
## kept flat, the arms swinging a little and late. Every angle is a rigid piece turning at its joint.
func _pose(delta: float) -> void:
	_body.basis = Basis4D.from_zx(yaw)
	var moving: float = clampf(_speed_now / maxf(walk_speed, 0.01), 0.0, 1.0)
	_stride += delta * (0.2 + moving * 1.5) * TAU * 0.5
	var swing: float = sin(_stride) * 0.36 * moving
	var lift_l: float = maxf(0.0, cos(_stride)) * 0.45 * moving
	var lift_r: float = maxf(0.0, -cos(_stride)) * 0.45 * moving
	# The head: in idle it turns now and then, slowly, and now and then tilts.
	if state == "idle" and fmod(_t, 7.0) < delta:
		head_target = (fmod(_t * 3.17, 2.0) - 1.0) * 0.9
	if state == "idle" and fmod(_t + 3.0, 11.0) < delta:
		_tilt_target = (fmod(_t * 1.91, 2.0) - 1.0) * 0.3
	if state != "idle":
		_tilt_target = 0.0
	head_turn = move_toward(head_turn, head_target if (state == "idle" or state == "film") else 0.0, delta * (0.6 if state == "film" else 0.45))
	_tilt = move_toward(_tilt, _tilt_target, delta * 0.18)
	var sway: float = sin(_t * 0.7) * 0.02
	var breathe: float = sin(_t * 0.8) * 0.012
	(_joints["pelvis"] as Node4D).position = Vector4(0, HIP_Y - 0.02 - absf(sin(_stride)) * 0.03 * moving, 0, 0)
	(_joints["spine"] as Node4D).basis = Basis4D.from_yz(-0.12 - 0.07 * moving + breathe) * Basis4D.from_xy(sway)
	(_joints["neck"] as Node4D).basis = Basis4D.from_yz(-0.42 - breathe)
	(_joints["head"] as Node4D).basis = Basis4D.from_zx(head_turn) * Basis4D.from_yz(0.48 + 0.07 * moving) * Basis4D.from_xy(_tilt)
	# The legs: a little knee bend standing; the foot turned back by both so its sole stays level.
	var thigh_l: float = 0.05 + swing
	var thigh_r: float = 0.05 - swing
	var shin_l: float = -0.09 - lift_l
	var shin_r: float = -0.09 - lift_r
	(_joints["l_thigh"] as Node4D).basis = Basis4D.from_yz(thigh_l)
	(_joints["r_thigh"] as Node4D).basis = Basis4D.from_yz(thigh_r)
	(_joints["l_shin"] as Node4D).basis = Basis4D.from_yz(shin_l)
	(_joints["r_shin"] as Node4D).basis = Basis4D.from_yz(shin_r)
	(_joints["l_foot"] as Node4D).basis = Basis4D.from_yz(-(thigh_l + shin_l) * (1.0 - 0.6 * lift_l))
	(_joints["r_foot"] as Node4D).basis = Basis4D.from_yz(-(thigh_r + shin_r) * (1.0 - 0.6 * lift_r))
	# The arms: hanging a little out and forward, elbows soft, the hands now and then turning at the wrist.
	var arm: float = -swing * 0.3 + sin(_t * 0.6) * 0.015
	(_joints["l_arm"] as Node4D).basis = Basis4D.from_yz(0.1 + arm) * Basis4D.from_xy(-0.05)
	(_joints["r_arm"] as Node4D).basis = Basis4D.from_yz(0.1 - arm) * Basis4D.from_xy(0.05)
	(_joints["l_fore"] as Node4D).basis = Basis4D.from_yz(0.14 + maxf(0.0, -arm) * 0.5)
	(_joints["r_fore"] as Node4D).basis = Basis4D.from_yz(0.14 + maxf(0.0, arm) * 0.5)
	(_joints["l_hand"] as Node4D).basis = Basis4D.from_yz(0.06 + sin(_t * 0.43) * 0.05) * Basis4D.from_zx(0.15)
	(_joints["r_hand"] as Node4D).basis = Basis4D.from_yz(0.06 + sin(_t * 0.37 + 1.3) * 0.05) * Basis4D.from_zx(-0.15)
	# A footfall: the game's sound hears it.
	var side: int = 1 if sin(_stride) > 0.0 else -1
	if moving > 0.3 and side != _step_side:
		_step_side = side
		if game != null:
			game.call("walker_step", self)
