extends Node4D

## The goat, walking on the spot: the lofted goat cut into rigid pieces that turn on joints, so a
## walk costs transforms and never a re-loft (Ramon, 4 Oct: "make sure it's optimised for
## performance, and that it can walk too ... a decent walking animation while staying in one
## place ... simplify the motion so it still looks like a walking goat"; "it should be procedural
## and follow the rigid animation system"). The pen's chicken works the same way: separate pieces,
## moved whole, nothing written to a mesh after they are made.
##
## THE PIECES, lofted once from the goat's own balls (loft_builder_4d.gd, the rig's settings) and
## saved beside the goat's baked stages, so later loads only read them:
##   the body   every chain of the goat, each leg cut back to its top ball, so the haunch and
##              shoulder stay on the body and do not move
##   per leg    an upper piece (top ball to middle ball) and a lower one (middle to hoof); the
##              loft's rounded ends overlap at the middle ball, so the joint turns like a ball
##              joint with no seam; left and right are separate pieces (the rig would loft them
##              as one mirrored pair)
## Each piece keeps the goat's colours: its own copy of the coat with its own colour ramp.
##
## THE WALK is deliberately simple: a four-beat walk (left hind, left fore, right hind, right
## fore, a quarter cycle apart), each hoof sliding back along the ground for 60% of the cycle and
## lifting forward through the rest; each leg is a two-bone solve in its own side plane, bending
## the way it was authored (fore knees forward, hind hocks back); the body bobs twice a cycle and
## rolls a little. No hoof planting, no physics: pose(t) is a pure function of time.
##
## THE X-RAY (Ramon, 4 Oct: "the part with the thin lines and ellipses that show the joints walk,
## remember in the cinema"): every ball's guide ring (the ellipses) in gold, and thin gold lines
## from each ball to the next (the bones), hung on the same joints as the pieces, so they walk with
## them; set_xray(true) hides the skin and shows only those.
##
## NO class_name (engine_gotchas.md).

const Builder := preload("res://ramon/LabKit/carried/Model/scripts/loft_builder_4d.gd")
const BAKED := "res://ramon/LabKit/carried/chickenpen/theatre/baked/"

## One step cycle, seconds; stride and lift in the rig's own units (about 1.3 to the metre here).
@export var period: float = 1.3
@export var stride: float = 0.55
@export var lift: float = 0.2
@export var bob: float = 0.035
@export var roll: float = 0.025
@export_range(0.3, 0.9, 0.01) var duty: float = 0.6

## Where in the cycle each leg is, by name: a four-beat lateral walk.
const PHASE := {"RearLegTop_L": 0.0, "FrontLegTop_L": 0.25, "RearLegTop_R": 0.5, "FrontLegTop_R": 0.75}

var _rig: MeshInstance4D
var _body: Node4D
var _legs: Array = []
var _walking: bool = false
var _pivot: Vector4 = Vector4.ZERO
var _skins: Array = []
var _xray_parts: Array = []
var _xray_on: bool = false


## Sets it up on the theatre goat's rig: loads the pieces (or lofts and saves them) and hangs
## them on joints in the rig's own space. Returns false if there is nothing to walk.
func attach(rig: MeshInstance4D) -> bool:
	_rig = rig
	if rig == null:
		return false
	position = rig.position
	basis = rig.basis
	var pieces: Dictionary = load_pieces()
	if pieces.is_empty():
		pieces = build_pieces(rig)
		save_pieces(pieces)
	if pieces.is_empty():
		return false
	var coat: Material4D = rig.material_override
	_pivot = pieces["pivot"]
	_body = Node4D.new()
	_body.name = "Body"
	_body.position = _pivot
	add_child(_body)
	_body.add_child(_piece("BodyMesh", pieces["body"], -_pivot, coat))
	var leg_nodes: Dictionary = {}
	for leg in pieces["legs"]:
		var l: Dictionary = leg
		var top: Vector4 = l["top"]
		var mid: Vector4 = l["mid"]
		var hoof: Vector4 = l["hoof"]
		var hip := Node4D.new()
		hip.name = String(l["name"])
		hip.position = top - _pivot
		_body.add_child(hip)
		hip.add_child(_piece("Upper", l["upper"], -top, coat))
		leg_nodes[String(l["name"])] = [hip, top, mid, hoof]
		var knee := Node4D.new()
		knee.name = "Knee"
		knee.position = mid - top
		hip.add_child(knee)
		knee.add_child(_piece("Lower", l["lower"], -mid, coat))
		leg_nodes[String(l["name"])].append(knee)
		var u1 := Vector2(mid.z - top.z, top.y - mid.y)
		var u2 := Vector2(hoof.z - mid.z, mid.y - hoof.y)
		var a1: float = atan2(u1.x, u1.y)
		var a2: float = atan2(u2.x, u2.y)
		_legs.append({"hip": hip, "knee": knee, "top": top, "hoof": hoof, "l1": u1.length(), "l2": u2.length(),
			"rest1": a1, "rest_k": a2 - a1, "bend": signf(a2 - a1) if absf(a2 - a1) > 0.001 else (1.0 if String(l["name"]).begins_with("Rear") else -1.0),
			"phase": float(PHASE.get(String(l["name"]), 0.0))})
	_build_xray(rig, leg_nodes)
	set_xray(false)
	visible = false
	return true


func _piece(nm: String, mesh: ArrayTetraMesh4D, offset: Vector4, coat: Material4D) -> MeshInstance4D:
	var m := MeshInstance4D.new()
	_skins.append(m)
	m.name = nm
	m.mesh = mesh
	m.position = offset
	m.material_override = _material(mesh, coat)
	return m


## Walking or not: the pieces show and the rig's own mesh hides, or the other way round.
func set_walking(on: bool) -> void:
	if on == _walking or _rig == null:
		return
	_walking = on
	visible = on
	_rig.visible = not on
	if not on:
		pose_rest()


func is_walking() -> bool:
	return _walking


## The x-ray: only the rings and the bones, the skin hidden.
func set_xray(on: bool) -> void:
	_xray_on = on
	for s in _skins:
		(s as Node4D).visible = not on
	for x in _xray_parts:
		(x as Node4D).visible = on


# -- the x-ray -------------------------------------------------------------------------------------

func _build_xray(rig: MeshInstance4D, leg_nodes: Dictionary) -> void:
	var gold := WireMaterial4D.new()
	gold.albedo_color = Color(1.0, 0.74, 0.12)
	gold.set("line_thickness", 4.0)
	var bone_mat: Material4D = preload("res://ramon/LabKit/lab_materials.gd").glow(Color(1.0, 0.80, 0.35), 1.2)
	var balls: Array = []
	_collect(rig, balls)
	# Which ball hangs where: the legs' three balls on their joints, both sides; the rest on the body.
	var on_leg: Dictionary = {}
	for nm in leg_nodes:
		var base: String = String(nm).trim_suffix("_L").trim_suffix("_R")
		on_leg[base] = true
		on_leg[base.replace("Top", "Mid")] = true
		on_leg[base.replace("LegTop", "Hoof")] = true
	for b in balls:
		var ball: Node4D = b
		var pos: Vector4 = rig.call("_position_in_rig", ball)
		var basis_r: Projection = _basis_in_rig(rig, ball)
		var parent_ball: Node = ball.get_parent() if ball.get_parent() != rig else null
		if on_leg.has(String(ball.name)):
			continue
		for side in ([1.0, -1.0] if absf(pos.x) > 0.01 else [1.0]):
			var p2: Vector4 = Vector4(pos.x * side, pos.y, pos.z, pos.w)
			_ring(_body, ball, p2 - _pivot, basis_r, gold)
			if parent_ball != null and parent_ball.has_method("get_loft_section"):
				var pp: Vector4 = rig.call("_position_in_rig", parent_ball)
				_bone(_body, Vector4(pp.x * side, pp.y, pp.z, pp.w) - _pivot, p2 - _pivot, bone_mat)
	# The body's own chain (the balls straight on the rig), joined in order.
	var roots: Array = []
	for b in balls:
		if (b as Node).get_parent() == rig:
			roots.append(b)
	for i in range(roots.size() - 1):
		_bone(_body, (rig.call("_position_in_rig", roots[i]) as Vector4) - _pivot, (rig.call("_position_in_rig", roots[i + 1]) as Vector4) - _pivot, bone_mat)
	# The legs: rings on their joints, bones from joint to joint, and the bone from the body ball
	# the leg hangs from to its top.
	for nm in leg_nodes:
		var parts: Array = leg_nodes[nm]
		var hip: Node4D = parts[0]
		var top: Vector4 = parts[1]
		var mid: Vector4 = parts[2]
		var hoof: Vector4 = parts[3]
		var knee: Node4D = parts[4]
		var base: String = String(nm).trim_suffix("_L").trim_suffix("_R")
		var side: float = 1.0 if String(nm).ends_with("_L") else -1.0
		for b in balls:
			var ball: Node4D = b
			var bn: String = String(ball.name)
			var br: Projection = _basis_in_rig(rig, ball)
			if bn == base:
				_ring(hip, ball, Vector4.ZERO, br, gold)
				var anchor: Node = ball.get_parent()
				if anchor != null and anchor.has_method("get_loft_section"):
					var ap: Vector4 = rig.call("_position_in_rig", anchor)
					_bone(_body, Vector4(ap.x * side, ap.y, ap.z, ap.w) - _pivot, top - _pivot, bone_mat)
			elif bn == base.replace("Top", "Mid"):
				_ring(knee, ball, Vector4.ZERO, br, gold)
			elif bn == base.replace("LegTop", "Hoof"):
				_ring(knee, ball, hoof - mid, br, gold)
		_bone(hip, Vector4.ZERO, mid - top, bone_mat)
		_bone(knee, Vector4.ZERO, hoof - mid, bone_mat)


func _collect(node: Node, out: Array) -> void:
	for c in node.get_children():
		if c.has_method("get_loft_section"):
			out.append(c)
			_collect(c, out)


static func _basis_in_rig(rig: Node, ball: Node4D) -> Projection:
	var b: Projection = ball.basis
	var n: Node = ball.get_parent()
	while n != null and n != rig and n.has_method("get_loft_section"):
		b = (n as Node4D).basis * b
		n = n.get_parent()
	return b


## A ball's guide ring (its own wire mesh) in gold, at `at` under `parent`.
func _ring(parent: Node4D, ball: Node4D, at: Vector4, b: Projection, mat: Material4D) -> void:
	if not (ball is MeshInstance4D) or (ball as MeshInstance4D).mesh == null:
		return
	var m := MeshInstance4D.new()
	m.name = "Ring"
	m.mesh = (ball as MeshInstance4D).mesh
	m.position = at
	m.basis = b
	m.material_override = mat
	parent.add_child(m)
	_xray_parts.append(m)


## A thin bone from `a` to `b` under `parent`.
func _bone(parent: Node4D, a: Vector4, b: Vector4, mat: Material4D) -> void:
	var d: Vector4 = b - a
	var len: float = d.length()
	if len < 0.01:
		return
	var y3 := Vector3(d.x, d.y, d.z).normalized()
	var ref := Vector3(0, 0, 1) if absf(y3.z) < 0.9 else Vector3(1, 0, 0)
	var x3: Vector3 = y3.cross(ref).normalized()
	var z3: Vector3 = x3.cross(y3)
	var m := MeshInstance4D.new()
	m.name = "Bone"
	m.mesh = preload("res://ramon/LabKit/lab_materials.gd").box_mesh(Vector4(0.035, len, 0.035, 0.3))
	m.position = (a + b) * 0.5
	m.basis = Projection(Vector4(x3.x, x3.y, x3.z, 0.0), Vector4(y3.x, y3.y, y3.z, 0.0), Vector4(z3.x, z3.y, z3.z, 0.0), Vector4(0, 0, 0, 1))
	m.material_override = mat
	parent.add_child(m)
	_xray_parts.append(m)


func pose_rest() -> void:
	if _body != null:
		_body.position = _pivot
		_body.basis = Projection.IDENTITY
	for leg in _legs:
		(leg["hip"] as Node4D).basis = Projection.IDENTITY
		(leg["knee"] as Node4D).basis = Projection.IDENTITY


## The walk at `t` seconds.
func pose(t: float) -> void:
	if _body == null:
		return
	var p: float = fposmod(t / maxf(period, 0.05), 1.0)
	var up: float = bob * cos(p * TAU * 2.0)
	_body.position = _pivot + Vector4(0.0, up, 0.0, 0.0)
	_body.basis = Basis4D.from_xy(roll * sin(p * TAU))
	for leg in _legs:
		var q: float = fposmod(p + float(leg["phase"]), 1.0)
		var dz: float
		var dy: float = 0.0
		if q < duty:
			dz = stride * 0.5 - stride * (q / duty)
		else:
			var u: float = (q - duty) / (1.0 - duty)
			dz = -stride * 0.5 + stride * smoothstep(0.0, 1.0, u)
			dy = lift * sin(u * PI)
		var top: Vector4 = leg["top"]
		var hoof: Vector4 = leg["hoof"]
		# The hoof's target, from the hip, keeping it on the ground while the body bobs.
		var d := Vector2(hoof.z + dz - top.z, top.y - (hoof.y + dy) + up)
		_solve(leg, d)


## Two bones in the leg's side plane: `d` is the hoof from the hip as (forward, down).
func _solve(leg: Dictionary, d: Vector2) -> void:
	var l1: float = float(leg["l1"])
	var l2: float = float(leg["l2"])
	var dist: float = clampf(d.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.002)
	var theta: float = atan2(d.x, d.y)
	var alpha: float = acos(clampf((l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist), -1.0, 1.0))
	var beta: float = acos(clampf((l1 * l1 + l2 * l2 - dist * dist) / (2.0 * l1 * l2), -1.0, 1.0))
	var s: float = float(leg["bend"])
	var a1: float = theta - s * alpha
	var k: float = s * (PI - beta)
	# Basis4D.from_yz(a) turns a bone hanging down by -a in this (forward, down) measure.
	(leg["hip"] as Node4D).basis = Basis4D.from_yz(-(a1 - float(leg["rest1"])))
	(leg["knee"] as Node4D).basis = Basis4D.from_yz(-(k - float(leg["rest_k"])))


# -- the pieces ------------------------------------------------------------------------------------

## Lofts the pieces from the rig's balls (all of them must be on the rig). In the rig's space.
static func build_pieces(rig: MeshInstance4D) -> Dictionary:
	var chains: Array = rig.call("_collect_chains")
	var body_chains: Array = []
	var legs: Array = []
	for ch in chains:
		var chain: Array = ch
		if chain.size() >= 4 and String((chain[1] as Node).name).ends_with("LegTop"):
			body_chains.append([chain[0], chain[1]])
			for side in [1.0, -1.0]:
				var tag: String = "_L" if side > 0.0 else "_R"
				var secs: Array = []
				for k in range(1, 4):
					secs.append(_section(rig, chain[k], side))
				legs.append({"name": String((chain[1] as Node).name) + tag,
					"top": secs[0]["center"], "mid": secs[1]["center"], "hoof": secs[2]["center"],
					"upper": _loft(rig, [secs[0], secs[1]]), "lower": _loft(rig, [secs[1], secs[2]])})
		else:
			body_chains.append(chain)
	var body: ArrayTetraMesh4D = null
	var ramp := PackedColorArray()
	for i in body_chains.size():
		var piece: ArrayTetraMesh4D = rig.call("_build_chain", body_chains[i], false, i > 0, false)
		if piece == null:
			continue
		ramp.append_array(piece.get_meta("loft_ramp", PackedColorArray()))
		if body == null:
			body = piece
		else:
			body.merge_with(piece, Vector4(), Projection.IDENTITY)
	if body == null:
		return {}
	_spread(body, ramp)
	# The body turns about the middle of its back.
	var lo := Vector4(INF, INF, INF, 0.0)
	var hi := Vector4(-INF, -INF, -INF, 0.0)
	for v in body.get_vertex_positions():
		lo = Vector4(minf(lo.x, v.x), minf(lo.y, v.y), minf(lo.z, v.z), 0.0)
		hi = Vector4(maxf(hi.x, v.x), maxf(hi.y, v.y), maxf(hi.z, v.z), 0.0)
	var pivot := Vector4((lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.55, (lo.z + hi.z) * 0.5, 0.0)
	return {"body": body, "legs": legs, "pivot": pivot}


## A ball's loft section in the rig's space; side -1 mirrors it across the rig's middle (as the
## rig's own mirrored twin does: the centre reflected, the roll turned round).
static func _section(rig: MeshInstance4D, ball: Node, side: float) -> Dictionary:
	var s: Dictionary = ball.call("get_loft_section")
	var c: Vector4 = rig.call("_position_in_rig", ball)
	if bool(rig.get("flatten_w")):
		c.w = 0.0
	if side < 0.0:
		c.x = -c.x
		s["roll"] = -float(s.get("roll", 0.0))
	s["center"] = c
	return s


static func _loft(rig: MeshInstance4D, sections: Array) -> ArrayTetraMesh4D:
	var typed: Array[Dictionary] = []
	for s in sections:
		typed.append(s)
	var smoothing: int = int(rig.get("smoothing")) if rig.get("smoothing") != null else 1
	var m: ArrayTetraMesh4D = Builder.build(typed, int(rig.get("profile_rings")), int(rig.get("profile_sides")), bool(rig.get("taper_ends")),
		false, bool(rig.get("align_to_spine")), smoothing, false)
	if m != null:
		_spread(m, m.get_meta("loft_ramp", PackedColorArray()))
	return m


## The rig's colour trick, kept on the mesh: each texture coordinate becomes an index into a
## ramp of ball colours (the ramp is kept as the mesh's "loft_ramp"; _material makes the texture).
static func _spread(mesh: ArrayTetraMesh4D, ramp: PackedColorArray) -> void:
	var pool: PackedVector3Array = mesh.get_texture_map_values()
	if ramp.size() != pool.size() or pool.is_empty():
		return
	var spread := PackedVector3Array()
	spread.resize(pool.size())
	for i in pool.size():
		spread[i] = Vector3((float(i) + 0.5) / float(pool.size()), 0.5, 0.5)
	mesh.set_texture_map_values(spread)
	mesh.set_meta("loft_ramp", ramp)


## A copy of the coat reading this piece's own colour ramp.
static func _material(mesh: ArrayTetraMesh4D, coat: Material4D) -> Material4D:
	var ramp: PackedColorArray = mesh.get_meta("loft_ramp", PackedColorArray())
	var mat: TetraMaterial4D = (coat.duplicate() as TetraMaterial4D) if coat is TetraMaterial4D else TetraMaterial4D.new()
	if ramp.is_empty():
		return mat
	var image: Image = Image.create(ramp.size(), 1, false, Image.FORMAT_RGBA8)
	for i in ramp.size():
		image.set_pixel(i, 0, ramp[i])
	var tex := ImageTexture3D.new()
	tex.create(Image.FORMAT_RGBA8, ramp.size(), 1, 1, false, [image])
	mat.set("albedo_source", 3)
	mat.set("albedo_texture_3d", tex)
	return mat


static func save_pieces(pieces: Dictionary) -> void:
	if pieces.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BAKED))
	ResourceSaver.save(pieces["body"], BAKED + "walk_body.res")
	var cfg := ConfigFile.new()
	cfg.set_value("walk", "pivot", pieces["pivot"])
	var names: Array = []
	for leg in pieces["legs"]:
		var nm: String = String(leg["name"])
		names.append(nm)
		ResourceSaver.save(leg["upper"], BAKED + "walk_%s_upper.res" % nm)
		ResourceSaver.save(leg["lower"], BAKED + "walk_%s_lower.res" % nm)
		cfg.set_value(nm, "top", leg["top"])
		cfg.set_value(nm, "mid", leg["mid"])
		cfg.set_value(nm, "hoof", leg["hoof"])
	cfg.set_value("walk", "legs", names)
	cfg.save(BAKED + "walk.cfg")


static func load_pieces() -> Dictionary:
	if not FileAccess.file_exists(BAKED + "walk.cfg"):
		return {}
	var cfg := ConfigFile.new()
	if cfg.load(BAKED + "walk.cfg") != OK:
		return {}
	var body := load(BAKED + "walk_body.res") as ArrayTetraMesh4D
	if body == null:
		return {}
	var legs: Array = []
	for nm in cfg.get_value("walk", "legs", []):
		var upper := load(BAKED + "walk_%s_upper.res" % nm) as ArrayTetraMesh4D
		var lower := load(BAKED + "walk_%s_lower.res" % nm) as ArrayTetraMesh4D
		if upper == null or lower == null:
			return {}
		legs.append({"name": nm, "top": cfg.get_value(nm, "top"), "mid": cfg.get_value(nm, "mid"), "hoof": cfg.get_value(nm, "hoof"), "upper": upper, "lower": lower})
	return {"body": body, "legs": legs, "pivot": cfg.get_value("walk", "pivot", Vector4.ZERO)}
