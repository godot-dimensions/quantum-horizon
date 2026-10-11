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
## at its W. It perceives you only in its slice (within NOTICE_W of its W), and slowly: an awareness that
## fills while it sees you, faster the closer, the more central and the more you move (12 Oct, Ramon:
## "improve the behavior on the walkers, subtleties, how they see you at what angle, and when not.. walk
## pace differences, like when they see you they walk a little faster. how the walk looks"). See
## _perceive and the states above _physics_process. Something registered: it stops and looks. Full: its
## eyes go red and it walks to you, faster than it paces, slower than you walk. In its slice and within
## reach, it kills you. Lose its slice or its sight and it goes to where it last saw you, looks about,
## then gives up. So the way out is another slice.
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
## How long it stands searching where it lost you before it gives up.
const SEARCH_S := 5.0
## What it sees, from its eyes (so the cones turn with its head): half-angles in degrees, how far the
## peripheral cone reaches as a share of notice_range, and how near it feels you behind it.
const CENTRAL_DEG := 32.0
const PERIPH_DEG := 72.0
const PERIPH_REACH := 0.6
const BACK_SENSE_M := 1.7
## How far it hears you run.
const HEAR_M := 6.5
## Its paces, metres a second (you walk 3.4): pacing, edging toward something, searching, walking home.
const PACE_SPEED := 0.5
const INVESTIGATE_SPEED := 0.45
const SEARCH_SPEED := 0.8
const RETURN_SPEED := 0.7
## Hunting within 4 m, it walks this much faster again.
const HUNT_CLOSE_K := 1.18

@export var notice_range: float = 9.0
## Its hunting pace, m/s: faster than it paces, slower than you walk.
@export var walk_speed: float = 1.35
@export var turn_rate: float = 1.1
## Where it stands and faces when it is not after you (set by the level).
var post: Vector4 = Vector4.ZERO
var post_yaw: float = 0.0
## A slow pacing beat between the post and this point (Vector4.INF: it stands still).
var pace_to: Vector4 = Vector4.INF
var game: Node = null
var player: Node4D = null
var level_body: Node = null
## "idle", "suspicious", "notice", "hunt", "search", "return", "film"
var state: String = "idle"
## 0 calm .. 1 it has you.
var awareness: float = 0.0
## Where it last saw (or sensed) you.
var last_seen: Vector4 = Vector4.INF
var red: float = 0.0
var yaw: float = 0.0
var head_turn: float = 0.0
var head_target: float = 0.0
var _tilt: float = 0.0
var _tilt_target: float = 0.0
var _t: float = 0.0
var _alert_t: float = 0.0
var _sus_t: float = 0.0
var _unseen_t: float = 0.0
var _search_t: float = 0.0
var _travel_t: float = 0.0
var _at_spot: bool = false
var _player_prev: Vector4 = Vector4.INF
var _player_speed: float = 0.0
var _yaw_rate: float = 0.0
var _look_down: float = 0.0
var _hunt_k: float = 0.0
var _reach_k: float = 0.0
var _hitch: float = 0.0
var _hitch_t: float = 6.0
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
	awareness = 0.0
	last_seen = Vector4.INF
	_alert_t = 0.0
	_sus_t = 0.0
	_unseen_t = 0.0
	_search_t = 0.0
	_speed_now = 0.0
	_hunt_k = 0.0
	_reach_k = 0.0
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


## Straight to the hunt (the kennel's ambush): fully aware at once; its eyes flare as it turns to you.
func hunt_now() -> void:
	awareness = 1.0
	if player != null:
		last_seen = player.global_position
	state = "notice"
	_alert_t = 0.3


## The first-sighting film: it stops, and turns its head to the film's camera.
func start_film(cam: Node4D) -> void:
	state = "film"
	_film_t = 0.0
	_film_cam = cam


func end_film() -> void:
	state = "idle"
	red = 0.0
	awareness = 0.0
	_film_cam = null


## Can it see you right now (in its slice, inside its cones and reach, nothing between)?
func sees_player() -> bool:
	return _perceive().y > 0.5


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


## HOW IT PERCEIVES YOU, this frame: x is awareness gained per second (0 for nothing), y is 1 when that
## is sight (it knows where you are), 0 when it only senses or hears you.
##   sight      from its eyes, so the cones turn with its head: a sharp central cone (CENTRAL_DEG either
##              side) out to notice_range, fastest close up; a wide peripheral one (to PERIPH_DEG) that
##              reaches PERIPH_REACH as far and registers you about a third as fast; nothing behind;
##              never through a wall
##   your W     only within NOTICE_W of its own; in the last 0.2 m of that you are half there to it
##   your pace  standing still you are about half as easy to see; running (Shift) much easier
##   its back   right behind it (BACK_SENSE_M) it feels you, slowly, without knowing quite where
##   hearing    running within HEAR_M of it, in its slice, carries round corners and to its back
func _perceive() -> Vector2:
	if player == null or not player.is_inside_tree():
		return Vector2.ZERO
	var p: Vector4 = player.global_position
	var dw: float = absf(p.w - global_position.w)
	if dw > NOTICE_W:
		return Vector2.ZERO
	var w_k: float = 1.0 - smoothstep(NOTICE_W - 0.2, NOTICE_W, dw)
	var d := Vector2(p.x - global_position.x, p.z - global_position.z)
	var dist: float = d.length()
	if dist < 0.05:
		return Vector2(3.0, 1.0)
	var running: bool = _player_speed > 4.4
	var move_k: float = 0.5 if _player_speed < 0.3 else (1.8 if running else 1.0)
	var look: float = yaw + head_turn
	var fwd := Vector2(-sin(look), -cos(look))
	var ang: float = rad_to_deg(acos(clampf(fwd.dot(d / dist), -1.0, 1.0)))
	var rate: float = 0.0
	var seen: bool = false
	if ang <= PERIPH_DEG:
		var central: bool = ang <= CENTRAL_DEG
		var reach: float = notice_range * (1.0 if central else PERIPH_REACH)
		if dist <= reach and clear_line_to(p + Vector4(0, 0.6, 0, 0)):
			var near_k: float = lerpf(1.0, 0.3, clampf((dist - 1.5) / maxf(reach - 1.5, 0.1), 0.0, 1.0))
			rate = (1.8 if central else 0.6) * near_k * move_k * w_k
			seen = true
	if not seen and dist < BACK_SENSE_M:
		rate = maxf(rate, 0.7 * w_k)
	if running and dist < HEAR_M:
		rate = maxf(rate, 0.65 * w_k)
	return Vector2(rate, 1.0 if seen else 0.0)


## Your ground speed, from how far you moved since the last physics frame (for how easily you are seen).
func _track_player(delta: float) -> void:
	if player == null:
		return
	var p: Vector4 = player.global_position
	if _player_prev != Vector4.INF and delta > 0.0:
		var v: float = Vector2(p.x - _player_prev.x, p.z - _player_prev.z).length() / delta
		_player_speed = lerpf(_player_speed, minf(v, 12.0), clampf(delta * 8.0, 0.0, 1.0))
	_player_prev = p


## It has you: the eyes flare, the head snaps to you, the sting.
func _alert() -> void:
	state = "notice"
	_alert_t = 0.0
	awareness = 1.0
	noticed.emit(self)


## THE STATES
##   idle        standing at its post or pacing slowly to its second point and back; awareness drains
##   suspicious  something registered (awareness past 0.3): it stops, its head goes to it, then its body if
##               the head cannot reach, and after a moment it takes slow steps toward it. Its eyes warm.
##               Full awareness: notice. Nothing more for a while: back to idle.
##   notice      0.7 s: the eyes go full red, the head snaps to you, it turns
##   hunt        it walks to you at walk_speed, a little faster within 4 m, its arms coming up as it
##               closes; locked on, it tracks you at any angle while it can see you. In its slice and
##               within reach, it catches you. You leave its slice, or a wall hides you: it goes to
##               where it last saw you.
##   search      it walks to that spot and stands there, its head turning, for SEARCH_S; still primed, so
##               it knows you again quickly. Then it gives up (lost) and walks back.
##   return      back to its post; it can notice you again on the way
##   film        the first sighting's film
func _physics_process(delta: float) -> void:
	_t += delta
	_track_player(delta)
	var want_speed: float = 0.0
	var target_yaw: float = yaw
	var look_at: Vector4 = Vector4.INF
	var per: Vector2 = Vector2.ZERO if state == "film" else _perceive()
	var p: Vector4 = player.global_position if player != null else Vector4.ZERO
	if per.x > 0.0:
		last_seen = p
	match state:
		"idle":
			# It drains only while nothing registers (a faint glimpse still adds up).
			awareness = clampf(awareness + (per.x if per.x > 0.0 else -0.2) * delta, 0.0, 1.0)
			_idle_pace(delta)
			want_speed = _speed_pace_target()
			if want_speed > 0.0:
				target_yaw = _yaw_to(pace_to if _pace_leg == 1 else post)
			else:
				target_yaw = post_yaw if pace_to == Vector4.INF else yaw
			if awareness >= 0.3:
				state = "suspicious"
				_sus_t = 0.0
		"suspicious":
			_sus_t += delta
			awareness = clampf(awareness + (per.x if per.x > 0.0 else -0.12) * delta, 0.0, 1.0)
			look_at = last_seen
			var rel: float = wrapf(_yaw_to(last_seen) - yaw, -PI, PI)
			if absf(rel) > 0.85 or _sus_t > 1.6:
				target_yaw = _yaw_to(last_seen)
			if _sus_t > 1.6 and Vector2(last_seen.x - global_position.x, last_seen.z - global_position.z).length() > 2.2:
				want_speed = INVESTIGATE_SPEED
			if awareness >= 1.0:
				_alert()
			elif awareness < 0.1:
				state = "idle"
		"notice":
			_alert_t += delta
			look_at = p
			target_yaw = _yaw_to(p)
			if _alert_t > 0.7:
				state = "hunt"
				_unseen_t = 0.0
		"hunt":
			var in_slice: bool = absf(p.w - global_position.w) <= NOTICE_W
			var seen: bool = in_slice and clear_line_to(p + Vector4(0, 0.6, 0, 0))
			if seen:
				last_seen = p
				_unseen_t = 0.0
			else:
				_unseen_t += delta
			look_at = last_seen
			target_yaw = _yaw_to(last_seen)
			var dist: float = Vector2(p.x - global_position.x, p.z - global_position.z).length()
			want_speed = walk_speed * (HUNT_CLOSE_K if dist < 4.0 else 1.0)
			if in_slice and dist < 0.95 and absf(p.y - global_position.y) < 1.8:
				caught.emit(self)
				state = "return"
				awareness = 0.0
			elif (not in_slice and _unseen_t > 0.5) or _unseen_t > 1.5:
				state = "search"
				_search_t = 0.0
				_travel_t = 0.0
				_at_spot = false
		"search":
			awareness = maxf(0.55, awareness - delta * 0.06)
			if per.y > 0.5 or per.x > 0.0:
				awareness += per.x * delta * 1.6
				if awareness >= 1.0:
					_alert()
			# It stops about a metre short of the spot, not on it: standing where you were, its body would
			# fill the place you shift back into, and hold you at the edge of its slice.
			var to_spot := Vector2(last_seen.x - global_position.x, last_seen.z - global_position.z)
			if not _at_spot and to_spot.length() > 1.1:
				target_yaw = _yaw_to(last_seen)
				want_speed = SEARCH_SPEED
				look_at = last_seen
				_travel_t += delta
				if _travel_t > 12.0:
					_at_spot = true
			else:
				_at_spot = true
				_search_t += delta
				# Standing where you vanished: the head sweeps slowly, the body follows now and then.
				head_target = sin(_search_t * 0.9) * 1.0
				if absf(head_target) > 0.9:
					target_yaw = yaw + head_target * 0.5
			if state == "search" and _search_t > SEARCH_S:
				state = "return"
				lost.emit(self)
		"return":
			awareness = clampf(awareness + (per.x if per.x > 0.0 else -0.15) * delta, 0.0, 1.0)
			var to_post := Vector2(post.x - global_position.x, post.z - global_position.z)
			if to_post.length() < 0.3:
				state = "idle"
			else:
				target_yaw = _yaw_to(post)
				want_speed = RETURN_SPEED
			if awareness >= 0.45:
				state = "suspicious"
				_sus_t = 0.0
		"film":
			# Its film: the head turns, slowly, to the camera; the eyes flicker red once and go pale.
			_film_t += delta
			if is_instance_valid(_film_cam):
				var d := Vector2(_film_cam.global_position.x - global_position.x, _film_cam.global_position.z - global_position.z)
				head_target = clampf(wrapf(atan2(-d.x, -d.y) - yaw, -PI, PI), -1.3, 1.3)
			var ft: float = _film_t - 3.2
			red = clampf(sin(ft * 3.0), 0.0, 1.0) * 0.85 if (ft > 0.0 and ft < 1.05) else 0.0
	# The eyes: warming with awareness, full red once it has you, cooling slowly when it has lost you.
	if state != "film":
		var want_red: float = 1.0 if state in ["notice", "hunt"] else clampf((awareness - 0.15) / 0.85, 0.0, 1.0) * 0.6
		red = move_toward(red, want_red, delta * (2.2 if want_red > red else 0.35))
	# The head: to what holds its attention, fast when it has just noticed you; idle, it looks about.
	if look_at != Vector4.INF:
		head_target = clampf(wrapf(_yaw_to(look_at) - yaw, -PI, PI), -1.15, 1.15)
		var dd: float = Vector2(look_at.x - global_position.x, look_at.z - global_position.z).length()
		_look_down = move_toward(_look_down, clampf(atan2(1.0, maxf(dd, 0.5)) * 0.7, 0.0, 0.5), delta * 0.8)
	else:
		_look_down = move_toward(_look_down, 0.0, delta * 0.5)
		if state == "idle" and fmod(_t, 7.0) < delta:
			head_target = (fmod(_t * 3.17, 2.0) - 1.0) * 0.9
		if state in ["return"]:
			head_target = 0.0
	var head_speed: float = {"notice": 3.2, "hunt": 1.6, "suspicious": 1.3, "search": 0.9, "film": 0.6}.get(state, 0.45)
	head_turn = move_toward(head_turn, head_target, delta * head_speed)
	# A stiff turn toward where it is going, then a step only when it more or less faces it.
	var dy: float = wrapf(target_yaw - yaw, -PI, PI)
	var rate: float = turn_rate * (1.6 if state in ["notice", "hunt"] else 1.0)
	var turn: float = clampf(dy, -rate * delta, rate * delta)
	yaw += turn
	_yaw_rate = lerpf(_yaw_rate, turn / maxf(delta, 0.0001), clampf(delta * 6.0, 0.0, 1.0))
	if absf(dy) > 0.6:
		want_speed = 0.0
	_speed_now = move_toward(_speed_now, want_speed, delta * (1.8 if want_speed > _speed_now else 1.2))
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


func _yaw_to(q: Vector4) -> float:
	var d := Vector2(q.x - global_position.x, q.z - global_position.z)
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
	return PACE_SPEED


## THE WALK, rigid pieces at their joints, matched to how fast it is really moving:
##   the stride   steps lengthen with speed (0.5 m pacing, about 0.8 m hunting) and the cadence is the
##                speed over the stride, so the feet do not skate; a leg's knee bends only while it swings
##                forward, and the planted foot stays level
##   the hips     drop at each footfall and rise over the planted leg, shift a little over it, and twist
##                with the stride; the trunk twists back against them
##   the arms     swing against the legs, more the faster it goes; hunting and close, they come up toward
##                you, the fingers first
##   the posture  a slight hunch standing, more walking, most hunting, the knees softer and the head low
##   turning      standing, it shuffles its feet round as it turns
##   idle         it breathes, shifts its weight, now and then turns or tilts its head, and once in a
##                while its head jerks, a stiff twitch, and settles
func _pose(delta: float) -> void:
	_body.basis = Basis4D.from_zx(yaw)
	var speed: float = _speed_now
	var sk: float = clampf(speed / 1.6, 0.0, 1.0)
	var gait: float = clampf(speed / 0.35, 0.0, 1.0)
	var shuffle: float = clampf(absf(_yaw_rate) / 0.7, 0.0, 1.0) * (1.0 - gait)
	var step_len: float = 0.5 + 0.3 * sk
	var cadence: float = speed / (2.0 * step_len)
	_stride += delta * TAU * (cadence + shuffle * 0.45)
	var s: float = sin(_stride)
	var c: float = cos(_stride)
	var amp: float = gait * (0.17 + 0.13 * sk) + shuffle * 0.07
	var hunting: float = 1.0 if state in ["notice", "hunt"] else 0.0
	_hunt_k = move_toward(_hunt_k, hunting, delta * 1.5)
	var close_k: float = 0.0
	if state == "hunt" and player != null:
		var dp: Vector4 = player.global_position - global_position
		close_k = clampf((3.6 - Vector2(dp.x, dp.z).length()) / 2.2, 0.0, 1.0)
	_reach_k = move_toward(_reach_k, close_k, delta * 0.9)
	# Idle: the head turns now and then (set by the state machine); it tilts; it twitches.
	if state == "idle" and fmod(_t + 3.0, 11.0) < delta:
		_tilt_target = (fmod(_t * 1.91, 2.0) - 1.0) * 0.3
	if state != "idle":
		_tilt_target = 0.0
	_tilt = move_toward(_tilt, _tilt_target, delta * 0.18)
	_hitch_t -= delta
	if state in ["idle", "search"] and _hitch_t <= 0.0:
		_hitch_t = 9.0 + fmod(_t * 5.17, 8.0)
		_hitch = 0.22 if fmod(_t, 2.0) < 1.0 else -0.22
	_hitch = move_toward(_hitch, 0.0, delta * (1.6 if absf(_hitch) > 0.15 else 0.5))
	var breathe: float = sin(_t * 0.8) * 0.012
	var weight: float = sin(_t * 0.31) * 0.014 * (1.0 - gait)
	# The hips.
	var bob: float = (0.03 + 0.02 * sk) * absf(s) * gait
	var crouch: float = 0.02 + 0.05 * _hunt_k
	(_joints["pelvis"] as Node4D).position = Vector4(0.022 * c * gait + weight, HIP_Y - crouch - bob, 0, 0)
	(_joints["pelvis"] as Node4D).basis = Basis4D.from_zx(0.07 * s * gait) * Basis4D.from_xy(-0.03 * c * gait)
	# The trunk, neck and head.
	var lean: float = -0.12 - 0.05 * gait - 0.12 * _hunt_k
	(_joints["spine"] as Node4D).basis = Basis4D.from_zx(-0.09 * s * gait) * Basis4D.from_yz(lean + breathe) * Basis4D.from_xy(sin(_t * 0.7) * 0.015 * (1.0 - gait))
	(_joints["neck"] as Node4D).basis = Basis4D.from_yz(-0.42 - breathe - 0.08 * _hunt_k)
	(_joints["head"] as Node4D).basis = Basis4D.from_zx(head_turn) * Basis4D.from_yz(0.48 + 0.07 * gait + 0.18 * _hunt_k - _look_down) * Basis4D.from_xy(_tilt + _hitch)
	# The legs: a leg bends while it swings forward (its angle rising); the planted foot kept level.
	var knee_soft: float = 0.09 + 0.08 * _hunt_k
	var thigh_l: float = 0.05 + 0.04 * _hunt_k + amp * s
	var thigh_r: float = 0.05 + 0.04 * _hunt_k - amp * s
	var lift_l: float = maxf(0.0, c) * (0.25 + 0.3 * sk) * gait + maxf(0.0, c) * shuffle * 0.25
	var lift_r: float = maxf(0.0, -c) * (0.25 + 0.3 * sk) * gait + maxf(0.0, -c) * shuffle * 0.25
	var shin_l: float = -knee_soft - lift_l
	var shin_r: float = -knee_soft - lift_r
	(_joints["l_thigh"] as Node4D).basis = Basis4D.from_yz(thigh_l)
	(_joints["r_thigh"] as Node4D).basis = Basis4D.from_yz(thigh_r)
	(_joints["l_shin"] as Node4D).basis = Basis4D.from_yz(shin_l)
	(_joints["r_shin"] as Node4D).basis = Basis4D.from_yz(shin_r)
	(_joints["l_foot"] as Node4D).basis = Basis4D.from_yz(-(thigh_l + shin_l) + lift_l * 0.35)
	(_joints["r_foot"] as Node4D).basis = Basis4D.from_yz(-(thigh_r + shin_r) + lift_r * 0.35)
	# The arms: against the legs, more with speed; reaching for you as it closes.
	var swing: float = amp * (0.7 + 0.4 * sk)
	var reach: float = _reach_k
	var arm_l: float = 0.1 + 0.06 * _hunt_k - swing * s + 0.6 * reach + sin(_t * 0.6) * 0.012
	var arm_r: float = 0.1 + 0.06 * _hunt_k + swing * s + 0.55 * reach + sin(_t * 0.53 + 1.0) * 0.012
	(_joints["l_arm"] as Node4D).basis = Basis4D.from_yz(arm_l) * Basis4D.from_xy(-0.05 - 0.04 * reach)
	(_joints["r_arm"] as Node4D).basis = Basis4D.from_yz(arm_r) * Basis4D.from_xy(0.05 + 0.04 * reach)
	(_joints["l_fore"] as Node4D).basis = Basis4D.from_yz(0.14 + maxf(0.0, -s) * swing * 0.6 + 0.3 * reach)
	(_joints["r_fore"] as Node4D).basis = Basis4D.from_yz(0.14 + maxf(0.0, s) * swing * 0.6 + 0.3 * reach)
	(_joints["l_hand"] as Node4D).basis = Basis4D.from_yz(0.06 + sin(_t * 0.43) * 0.05 + 0.25 * reach) * Basis4D.from_zx(0.15)
	(_joints["r_hand"] as Node4D).basis = Basis4D.from_yz(0.06 + sin(_t * 0.37 + 1.3) * 0.05 + 0.25 * reach) * Basis4D.from_zx(-0.15)
	# A footfall as each leg lands (its forward swing ending): the game's sound hears it.
	var side: int = 1 if c > 0.0 else -1
	if (gait > 0.3 or shuffle > 0.5) and side != _step_side:
		_step_side = side
		if game != null:
			game.call("walker_step", self)
