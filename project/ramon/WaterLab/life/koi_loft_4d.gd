extends Node4D

## WATER LAB: one koi, LOFTED IN 4D (Ramon, 9 Oct: "For the animals also the aquatic, they need to be
## true 4D lofts"). Built the hammerhead's way (life/shark_4d.gd): lofted once by our loft builder
## (carried chickenpen/scripts/loft_builder_4d.gd), cut into rigid pieces, baked under life/baked/, and
## after that only the pieces' transforms move. Turn the slice and the engine cuts the real 4D body.
## (Until 9 Oct the koi were a 3D mesh that a shader only shrank off the slice, life/koi.gdshader: the
## pen starlings' trick, which looked wrong the moment the tank was turned through W.)
##
## THE SHAPE is the old koi's profile (life/koi_mesh.gd PROFILE: a blunt round head, the back highest
## a third of the way along, a deep body tapering to a narrow peduncle, the back fuller than the
## belly). Each section is a ball shaped by its own basis (shark_4d.gd _scale): its half width in x,
## its half height in y and, through W, as deep as it is wide (W_ROUND). A 4D koi is round across its
## two sideways directions, x and W. The fins are thin in x and in W, as the hammerhead's are: a turn
## of the slice through W thins them away first, then the body.
##
## THE PIECES: the mouth (it opens on a gulp), the head, four of body, the tail fin. Neighbours overlap
## so a bend never opens a gap. The pectorals hang from their own holders at their roots, so they
## swing out to brake and scull while it hovers. A butterfly (long-finned) koi has its own fin meshes.
##
## THE SWIM is the old shader's, put on the pieces (life/koi.gdshader spine()): the spine's offset at
## s is A(s) sin(2 pi s - phase) + C (s - 0.3)^2, A = amp / 0.1 (0.02 - 0.08 s + 0.16 s^2) (koi,
## measured: 0.02 of its length at the head, least just behind it, 0.10 at the tail); C bends it into
## the C of a turn. Each piece sits at its own s on that spine, turned with the spine's slope there.
##
## THE COLOURS are painted per pixel from where the point is on the 4D body (life/koi_skin_4d.gdshader,
## life/koi_pattern.gdshaderinc): the varieties' patterns lie over a 4D back, so the cut of a turned
## slice runs across different patches of the same koi.
##
## Meshes are built at one body length and the body node is scaled by the koi's length. In the frame
## of whoever owns it (the tank's life/, the showcase). NO class_name (engine_gotchas.md).

const Loft := preload("res://ramon/WaterLab/carried/chickenpen/scripts/loft_builder_4d.gd")
const Kit := preload("res://ramon/WaterLab/life/loft_kit.gd")
const KoiMesh := preload("res://ramon/WaterLab/life/koi_mesh.gd")
const SKIN := preload("res://ramon/WaterLab/life/koi_skin_4d.gdshader")
const BAKED := "res://ramon/WaterLab/life/baked/"
const BAKE_VERSION := "v1"
## The snout's place ahead of the koi's origin (body lengths), as the old koi had it.
const SNOUT_Z := 0.45
## How deep through W for how wide: 1, round across x and W.
const W_ROUND := 1.0
## The rigid pieces: [name, s from, s to] (s: 0 the snout, 0.8 the tail's root).
const PIECES := [["Mouth", 0.0, 0.05], ["Head", 0.035, 0.2], ["Front", 0.16, 0.38], ["Middle", 0.34, 0.56], ["Rear", 0.52, 0.71], ["Peduncle", 0.67, 0.805]]
## Where the tail fin hangs from.
const TAIL_ROOT := 0.788
## Half the thickness of a fin, body lengths (and 1.4 times that through W, the hammerhead's ratio).
const FIN_HALF := 0.0042

@export var variety: int = 0
@export var long_fins: bool = false
@export var pattern_seed: float = 0.37
## 1 the tank's koi; 2 the showcase's, five times life size, finer and with the fine marks on.
@export_range(1, 2) var detail: int = 1

var body: Node4D
var material: TetraMaterial4D
var tets: int = 0
## How many 4D meshes it draws (each is an instance for the renderer).
var meshes: int = 0
var _pieces: Array = []
var _tail: Node4D
var _pectorals: Array = []


func _ready() -> void:
	if body == null:
		build()


func build() -> void:
	material = make_material(variety, long_fins, pattern_seed, detail)
	body = Node4D.new()
	body.name = "Body"
	add_child(body)
	var long_key: String = "_long" if long_fins else ""
	for pc in PIECES:
		var nm: String = pc[0]
		var s0: float = pc[1]
		var s1: float = pc[2]
		var sc: float = (s0 + s1) * 0.5
		var holder := Node4D.new()
		holder.name = nm
		holder.set_meta("s", sc)
		body.add_child(holder)
		_pieces.append(holder)
		# One mesh a piece: its stretch of body and whatever hangs on it fixed (the fins that do not move
		# on their own, the eyes, the barbels), so a koi is nine 4D meshes, not fifteen.
		var i: int = _pieces.size() - 1
		var key: String = "koi_piece_" + nm.to_lower() + (long_key if i >= 3 else "")
		_add(holder, "Skin", _cached(key, func() -> ArrayTetraMesh4D: return _piece_with_fins(i, s0, s1, sc)))
	for side in [1.0, -1.0]:
		var r: Vector3 = KoiMesh.PECTORAL_ROOT
		var h := Node4D.new()
		h.name = "PectoralR" if side > 0.0 else "PectoralL"
		h.set_meta("side", side)
		h.position = Vector4(side * r.z, r.y + KoiMesh.midline(r.x), _sc(2) - r.x, 0.0)
		_pieces[2].add_child(h)
		_pectorals.append(h)
		_add(h, "Fin", _cached("koi_pectoral_%s%s" % ["r" if side > 0.0 else "l", long_key], func() -> ArrayTetraMesh4D: return _pectoral(side)))
	_tail = Node4D.new()
	_tail.name = "Tail"
	body.add_child(_tail)
	_add(_tail, "Fin", _cached("koi_caudal" + long_key, _caudal))
	pose(Vector4.ZERO, Projection.IDENTITY, 1.0, 0.0, 0.05, 0.0, 0.1, 0.0, 0.0)


## Repaints it as another variety and pattern (its fins' length stays: that is its meshes).
func set_look(v: int, seed: float) -> void:
	variety = v
	pattern_seed = seed
	if material != null:
		var cs: ShaderMaterial = material.get_cross_section_material_3d()
		cs.set_shader_parameter("variety", float(v))
		cs.set_shader_parameter("pattern_seed", seed)


func _sc(i: int) -> float:
	return (float(PIECES[i][1]) + float(PIECES[i][2])) * 0.5


# -- the swim --------------------------------------------------------------------------------------------------

## Places the koi: `p` and `frame` (columns right, up, ahead, ana) in its owner's space, `length` in
## metres; the wave's `phase` and `amp` (body lengths), the turn's `bend`; the pectorals' `spread` (0
## tucked, 1 out square to brake), the mouth's `gulp` (0 shut, 1 open), `t` the clock for the sculling.
func pose(p: Vector4, frame: Projection, length: float, phase: float, amp: float, bend: float, spread: float, gulp: float, t: float) -> void:
	if body == null:
		return
	body.position = p
	body.basis = Projection(frame.x * length, frame.y * length, frame.z * length, frame.w * length)
	for holder in _pieces:
		var sc: float = float((holder as Node4D).get_meta("s"))
		var sp: Vector2 = spine(sc, phase, amp, bend)
		(holder as Node4D).position = Vector4(sp.x, 0.0, SNOUT_Z - sc, 0.0)
		(holder as Node4D).basis = Kit.yaw(sp.y)
	# The mouth: the lips push forward and open on a gulp.
	var m: float = 1.0 + 0.35 * gulp
	var mouth: Node4D = _pieces[0]
	mouth.basis = mouth.basis * Projection(Vector4(m, 0, 0, 0), Vector4(0, m, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, m))
	mouth.position.z += 0.012 * gulp
	# The tail fin hangs from its root, along the spine's chord across it, its rays trailing the wave.
	var a: Vector2 = spine(TAIL_ROOT, phase, amp, bend)
	var b: Vector2 = spine(0.95, phase, amp, bend)
	var fin_len: float = 0.21 * (1.85 if long_fins else 1.0)
	var lag: float = amp * 0.35 * sin(TAU * 0.9 - phase - 1.3) / fin_len
	_tail.position = Vector4(a.x, 0.0, SNOUT_Z - TAIL_ROOT, 0.0)
	_tail.basis = Kit.yaw((b.x - a.x) / (0.95 - TAIL_ROOT) + lag)
	# The pectorals: tucked back along the body when it swims, out square to brake and hover, and
	# sculling up and down about the body's length, the two out of step.
	for h in _pectorals:
		var side: float = float((h as Node4D).get_meta("side"))
		var swing: float = lerpf(0.25, -0.75, spread)
		var scull: float = (0.10 + 0.32 * spread) * sin(t * (4.2 + 2.0 * spread) + side * 1.4) - 0.12 * spread
		(h as Node4D).basis = Kit.rot_y(side * swing) * Kit.rot_z(side * scull)


## The spine's sideways offset (body lengths) and its slope at s (koi.gdshader spine()).
static func spine(s: float, phase: float, amp: float, bend: float) -> Vector2:
	var k: float = TAU
	var th: float = k * s - phase
	var a: float = amp * 10.0 * (0.02 - 0.08 * s + 0.16 * s * s)
	var da: float = amp * 10.0 * (-0.08 + 0.32 * s)
	var lat: float = a * sin(th) + bend * (s - 0.3) * (s - 0.3)
	var d: float = da * sin(th) + a * cos(th) * k + 2.0 * bend * (s - 0.3)
	return Vector2(lat, d)


# -- its shape (lofted once, baked) ----------------------------------------------------------------------------

## The section of the body at s, for a piece centred at `sc` (its mesh's z is sc - s).
static func section(s: float, sc: float) -> Dictionary:
	var a: Vector3 = KoiMesh.at(s)
	var hw: float = maxf(a.z, 0.002)
	var hh: float = maxf((a.x + a.y) * 0.5, 0.002)
	var cy: float = KoiMesh.midline(s) + (a.x - a.y) * 0.5
	return {"center": Vector4(0.0, cy, sc - s, 0.0), "radius": hw, "v_scale": 1.0, "w_scale": 1.0,
		"basis": Kit.scale(1.0, hh / hw, 1.0, W_ROUND), "color": Color.WHITE}


## The profile for the skin shader, every 0.025 from s = 0 to 0.8: centre height, half height, half
## width, half depth through W.
static func profile() -> Array:
	var out: Array = []
	for i in 33:
		var s: float = float(i) * 0.025
		var a: Vector3 = KoiMesh.at(s)
		var hw: float = maxf(a.z, 0.002)
		out.append(Vector4(KoiMesh.midline(s) + (a.x - a.y) * 0.5, maxf((a.x + a.y) * 0.5, 0.002), hw, hw * W_ROUND))
	return out


func _rings() -> Vector2i:
	return Vector2i(4, 12) if detail < 2 else Vector2i(6, 20)


func _fin_rings() -> Vector2i:
	return Vector2i(3, 8) if detail < 2 else Vector2i(4, 12)


## A piece of the body with its fixed parts merged in: the barbels on the mouth, the eyes on the head,
## the pelvics and the dorsal's front on the middle, the dorsal's back on the rear, the anal fin on the
## peduncle.
func _piece_with_fins(i: int, s0: float, s1: float, sc: float) -> ArrayTetraMesh4D:
	var parts: Array = [_body_piece(s0, s1, sc)]
	match i:
		0:
			parts.append(_barbels(sc))
		1:
			parts.append(_eyes(sc))
		3:
			parts.append_array([_pelvics(sc), _median(sc, 1.0, 0.0, 0.53)])
		4:
			parts.append(_median(sc, 1.0, 0.47, 1.0))
		5:
			parts.append(_median(sc, -1.0, 0.0, 1.0))
	return Kit.merge(parts)


func _body_piece(s0: float, s1: float, sc: float) -> ArrayTetraMesh4D:
	var n: int = 6 if detail < 2 else 9
	var sections: Array = []
	for k in n:
		var s: float = lerpf(maxf(s0, 0.004), minf(s1, KoiMesh.BODY_END), float(k) / float(n - 1))
		sections.append(section(s, sc))
	var r: Vector2i = _rings()
	var m: ArrayTetraMesh4D = Loft.build(sections, r.x, r.y, true, false, true, 1, false)
	Kit.paint(m, func(q: Vector4) -> Vector3: return Vector3(clampf(sc - q.z, 0.0, KoiMesh.BODY_END), 0.0, 0.0))
	return m


## The dorsal (up 1) or the anal fin (up -1), from `t0` to `t1` of its length (the dorsal is cut in two,
## one on each of two pieces, so a bend never pulls it off the back): long and low, its first rays the
## tallest, raked back. Lofted along its base: each section a ball as tall as the fin there, thin
## across x and W, sheared so its top lies back along the rays.
func _median(sc: float, up: float, t0: float, t1: float) -> ArrayTetraMesh4D:
	var s0: float = 0.365 if up > 0.0 else 0.655
	var s1: float = 0.705 if up > 0.0 else 0.745
	var tall: float = (0.088 if up > 0.0 else 0.058) * (1.7 if long_fins else 1.0)
	var rake: float = 0.03 if up > 0.0 else 0.022
	var sections: Array = []
	var n: int = 5 if detail < 2 else 7
	for k in n:
		var t: float = lerpf(t0, t1, float(k) / float(n - 1))
		var s: float = lerpf(s0, s1, t)
		var a: Vector3 = KoiMesh.at(s)
		var base: float = KoiMesh.midline(s) + (a.x - 0.006 if up > 0.0 else -(a.y - 0.006))
		var h: float = maxf(_fin_height(tall, t), 0.004)
		var r: float = h * 0.5
		var rk: float = rake * (1.0 - 0.4 * t) * (1.7 if long_fins else 1.0)
		var shear := Projection(Vector4(FIN_HALF / r, 0, 0, 0), Vector4(0, 1, -up * rk / (2.0 * r), 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1.4 * FIN_HALF / r))
		sections.append({"center": Vector4(0.0, base + up * r, sc - s - rk * 0.5, 0.0), "radius": r, "v_scale": 1.0, "w_scale": 1.0, "basis": shear, "color": Color.WHITE})
	var fr: Vector2i = _fin_rings()
	var m: ArrayTetraMesh4D = Loft.build(sections, fr.x, fr.y, true, false, true, 1, false)
	Kit.paint(m, func(q: Vector4) -> Vector3:
		var s: float = clampf(sc - q.z, s0, s1)
		var t: float = clampf((s - s0) / (s1 - s0), 0.0, 1.0)
		var pr: Vector3 = KoiMesh.at(s)
		var base: float = KoiMesh.midline(s) + (pr.x - 0.006 if up > 0.0 else -(pr.y - 0.006))
		var reach: float = clampf((q.y - base) * up / maxf(_fin_height(tall, t), 0.004), 0.0, 1.0)
		return Vector3(s, reach, 1.0 + 0.5 * t))
	return m


static func _fin_height(tall: float, t: float) -> float:
	return tall * (1.0 - 0.62 * t) * sqrt(clampf(t * 6.0 + 0.25, 0.0, 1.0))


## A paddle fin from its root along `d` (its plane's normal `n`): narrow at the root, broad and round
## at its end; lofted along `d`, each section a ball the fin's width across, thin across `n` and W.
## `root` is where it hangs from in the mesh's own frame (the pectorals' holders put it at 0).
func _paddle(root: Vector3, d: Vector3, n: Vector3, length: float, width: float, s_root: float, part: float) -> ArrayTetraMesh4D:
	d = d.normalized()
	n = (n - d * n.dot(d)).normalized()
	var e: Vector3 = n.cross(d).normalized()
	var sections: Array = []
	var k_n: int = 5 if detail < 2 else 7
	for k in k_n:
		var u: float = lerpf(0.04, 0.86, float(k) / float(k_n - 1))
		var w: float = width * (0.35 + 0.65 * sin(PI * (0.18 + 0.62 * u)))
		var r: float = w * 0.5
		var c: Vector3 = root + d * (length * u)
		sections.append({"center": Vector4(c.x, c.y, c.z, 0.0), "radius": r, "v_scale": 1.0, "w_scale": 1.0,
			"basis": Kit.flatten(n, FIN_HALF * (1.0 - 0.4 * u) / r, 1.4), "color": Color.WHITE})
	var fr: Vector2i = _fin_rings()
	var m: ArrayTetraMesh4D = Loft.build(sections, fr.x, fr.y, true, false, true, 1, false)
	Kit.paint(m, func(q: Vector4) -> Vector3:
		var v := Vector3(q.x, q.y, q.z) - root
		return Vector3(s_root, clampf(v.dot(d) / length, 0.0, 1.0), part + 0.5 * clampf(0.5 + v.dot(e) / width, 0.0, 1.0)))
	return m


## A pectoral, in its holder's frame (the root at the origin): swept back, out and down.
func _pectoral(side: float) -> ArrayTetraMesh4D:
	var d := Vector3(side * 0.62, -0.30, -0.72)
	var n := Vector3(side * 0.15, 1.0, 0.25)
	var grow: float = 1.6 if long_fins else 1.0
	return _paddle(Vector3.ZERO, d, n, 0.135 * grow, 0.078 * (1.0 + 0.2 * (grow - 1.0)), KoiMesh.PECTORAL_ROOT.x, 4.0)


func _pelvics(sc: float) -> ArrayTetraMesh4D:
	var parts: Array = []
	var r: Vector3 = KoiMesh.PELVIC_ROOT
	for side in [1.0, -1.0]:
		var root := Vector3(side * r.z, r.y, sc - r.x)
		parts.append(_paddle(root, Vector3(side * 0.45, -0.42, -0.79), Vector3(side * 0.2, 1.0, 0.3), 0.082, 0.045, r.x, 1.0))
	return Kit.merge(parts)


## The tail fin, in its holder's frame (the root at the origin, the fin along -z): a forked fan, two
## lobes from the root to the fork's tips and a web between them to the notch. Lofted in three, each
## thin across x and W. A butterfly koi's reaches 1.85 times as far, its lobes a third taller.
func _caudal() -> ArrayTetraMesh4D:
	var along: float = 1.85 if long_fins else 1.0
	var tall: float = 1.35 if long_fins else 1.0
	var fr: Vector2i = _fin_rings()
	var parts: Array = []
	# [start (s, y), end (s, y), half chord at the start, at the end]
	var lobes: Array = [
		[Vector2(0.0, 0.012), Vector2(0.202, 0.118), 0.032, 0.010],
		[Vector2(0.0, -0.008), Vector2(0.202, -0.110), 0.030, 0.010],
		[Vector2(0.0, 0.002), Vector2(0.105, 0.003), 0.036, 0.012],
	]
	for lobe in lobes:
		var a: Vector2 = lobe[0]
		var b: Vector2 = lobe[1]
		var sections: Array = []
		var n: int = 5 if detail < 2 else 7
		for k in n:
			var u: float = float(k) / float(n - 1) * 0.92
			var p: Vector2 = a.lerp(b, u)
			var r: float = lerpf(float(lobe[2]), float(lobe[3]), u) * tall
			sections.append({"center": Vector4(0.0, p.y * tall, -p.x * along, 0.0), "radius": r, "v_scale": 1.0, "w_scale": 1.0,
				"basis": Kit.scale(FIN_HALF * (1.0 - 0.5 * u) / r, 1.0, 1.0, 1.4 * FIN_HALF * (1.0 - 0.5 * u) / r), "color": Color.WHITE})
		parts.append(Loft.build(sections, fr.x, fr.y, true, false, true, 1, false))
	var m: ArrayTetraMesh4D = Kit.merge(parts)
	Kit.paint(m, func(q: Vector4) -> Vector3:
		var ds: float = -q.z / along
		var ray: float = clampf((atan2(q.y / tall, maxf(ds, 0.001)) + 0.75) / 1.5, 0.0, 1.0)
		return Vector3(TAIL_ROOT + ds, clampf(ds / 0.21, 0.0, 1.0), 1.0 + 0.5 * ray))
	return m


## The eyes: 4D balls, half sunk in the head, looking out sideways (lofted across x).
func _eyes(sc: float) -> ArrayTetraMesh4D:
	var parts: Array = []
	var s: float = KoiMesh.EYE_S
	var r: float = KoiMesh.EYE_R
	var a: Vector3 = KoiMesh.at(s)
	for side in [1.0, -1.0]:
		var c := Vector4(side * a.z * 0.80, KoiMesh.midline(s) + KoiMesh.EYE_UP, sc - s, 0.0)
		var sections: Array = []
		for k in 5:
			var t: float = lerpf(-0.85, 0.85, float(k) / 4.0)
			sections.append({"center": c + Vector4(t * r, 0.0, 0.0, 0.0), "radius": r * sqrt(1.0 - t * t), "v_scale": 1.0, "w_scale": 1.0, "color": Color.WHITE})
		parts.append(Loft.build(sections, 4, 10, true, false, true, 0, false))
	var m: ArrayTetraMesh4D = Kit.merge(parts)
	var cx: float = a.z * 0.80
	Kit.paint(m, func(q: Vector4) -> Vector3: return Vector3(s, clampf((absf(q.x) - cx) / r, -1.0, 1.0), 2.0))
	return m


## Two pairs of barbels at the corners of the mouth, the upper pair longer: thin and tapering.
func _barbels(sc: float) -> ArrayTetraMesh4D:
	var parts: Array = []
	for side in [1.0, -1.0]:
		for k in 2:
			var root := Vector3(side * (0.016 + 0.006 * float(k)), KoiMesh.midline(0.012) - 0.010 - 0.004 * float(k), sc - (0.012 + 0.008 * float(k)))
			var d := Vector3(side * 0.35, -0.55, 0.45 - 0.25 * float(k)).normalized()
			var length: float = 0.036 if k == 0 else 0.022
			var sections: Array = []
			for i in 4:
				var u: float = float(i) / 3.0
				var c: Vector3 = root + d * (length * u)
				sections.append({"center": Vector4(c.x, c.y, c.z, 0.0), "radius": 0.0024 * (1.0 - 0.7 * u), "v_scale": 1.0, "w_scale": 1.0, "color": Color.WHITE})
			parts.append(Loft.build(sections, 3, 6, true, false, true, 0, false))
	var m: ArrayTetraMesh4D = Kit.merge(parts)
	Kit.paint(m, func(_q: Vector4) -> Vector3: return Vector3(0.012, 0.5, 3.0))
	return m


# -- meshes and materials -------------------------------------------------------------------------------------

func _add(holder: Node, nm: String, mesh: ArrayTetraMesh4D) -> void:
	if mesh == null:
		return
	tets += Kit.add_mesh(holder, nm, mesh, material)
	meshes += 1


func _cached(key: String, build_fn: Callable) -> ArrayTetraMesh4D:
	return Kit.cached(BAKED + "%s_d%d_%s.res" % [key, detail, BAKE_VERSION], build_fn)


## One koi's skin: the forked cross-section shader with its variety, pattern and fins set.
static func make_material(v: int, long: bool, seed: float, det: int) -> TetraMaterial4D:
	var m := TetraMaterial4D.new()
	m.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_TEXTURE3D_CELL_UVW_ONLY
	# The shader goes in BEFORE the texture: Material4D only assigns its built-in shader while the slot
	# is empty, and setting the texture re-runs the update that binds it (LabKit/lab_materials.gd).
	var cs: ShaderMaterial = m.get_cross_section_material_3d()
	cs.shader = SKIN
	m.albedo_texture_3d = Kit.white_texture()
	cs.set_shader_parameter("variety", float(v))
	cs.set_shader_parameter("long_fins", 1.0 if long else 0.0)
	cs.set_shader_parameter("pattern_seed", seed)
	cs.set_shader_parameter("detail", 1.0 if det >= 2 else 0.0)
	cs.set_shader_parameter("koi_profile", profile())
	return m
