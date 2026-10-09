extends Node4D

## WATER LAB: the eel's body, LOFTED IN 4D (round 5: every animal a true 4D loft; until 9 Oct a 3D mesh
## that life/eel.gdshader shrank off the slice). Lofted once by our loft builder in twelve short
## overlapping pieces, baked under life/baked/; after that only the pieces move. The tank's eel
## (life/eel_4d.gd), the showcase and the fish wall pose it.
##
## THE SHAPE is the old eel's: a round body, one body length, the snout 0.5 ahead of its origin,
## flattening from side to side toward the tail (half as wide, a quarter taller at the tip), one long
## fin along the back from a third of the way and along the belly from 0.42, meeting round the tail;
## small pectorals behind the head, small eyes. Round across x and W (W_ROUND), as the koi: a turned
## slice cuts it thinner, the fin first.
##
## THE SWIM IS ANGUILLIFORM, the old shader's spine put on the pieces (Tytell 2004): the whole body
## waves, more than one wave on it at once (wavelength 0.72 of its length), almost still at the head
## and growing toward the tail,
##     lat(s) = A (0.08 + 0.92 s^1.6) sin(2 pi s / 0.72 - phase) + C (s - 0.4)^2 + R(s),
## C bending it into a turn, R a resting S (`curl`); backing up, the amplitude evens out along it
## (`back`). Twelve pieces to a body is about nine to a wave, enough for the S to read round.
##
## NO class_name (engine_gotchas.md).

const Loft := preload("res://ramon/WaterLab/carried/chickenpen/scripts/loft_builder_4d.gd")
const Kit := preload("res://ramon/WaterLab/life/loft_kit.gd")
const BAKED := "res://ramon/WaterLab/life/baked/"
const BAKE_VERSION := "v1"
const SNOUT_Z := 0.5
const SEGMENTS := 12
const OVERLAP := 0.025
const W_ROUND := 1.0
const WAVELENGTH := 0.72

## 1 the tank's eel; 2 the showcase's, finer.
@export_range(1, 2) var detail: int = 1

var body: Node4D
var material: TetraMaterial4D
var tets: int = 0
var meshes: int = 0
var _pieces: Array = []


func _ready() -> void:
	if body == null:
		build()


func build() -> void:
	material = skin()
	body = Node4D.new()
	body.name = "Body"
	add_child(body)
	for i in SEGMENTS:
		var s0: float = maxf(float(i) / float(SEGMENTS) - OVERLAP, 0.0)
		var s1: float = minf(float(i + 1) / float(SEGMENTS) + OVERLAP, 1.0)
		var sc: float = (s0 + s1) * 0.5
		var holder := Node4D.new()
		holder.name = "Piece%02d" % i
		holder.set_meta("s", sc)
		body.add_child(holder)
		_pieces.append(holder)
		_add(holder, "Skin", _cached("eel_piece%02d" % i, func() -> ArrayTetraMesh4D: return _piece(s0, s1, sc)), material)
	var head_sc: float = float(_pieces[0].get_meta("s"))
	_add(_pieces[0], "Eyes", _cached("eel_eyes", func() -> ArrayTetraMesh4D: return _eyes(head_sc)), material)
	var fore_sc: float = float(_pieces[1].get_meta("s"))
	_add(_pieces[1], "Pectorals", _cached("eel_pectorals", func() -> ArrayTetraMesh4D: return _pectorals(fore_sc)), material)
	pose(Vector4.ZERO, Projection.IDENTITY, 1.0, 0.0, 0.02, 0.0, 0.0, 0.0)


# -- the swim --------------------------------------------------------------------------------------------------

## Places it: `p` and `frame` (right, up, ahead, ana) in its owner's space, `length` in metres; the
## wave's `phase` and `amp`, the turn's `bend`, backing up (`back`, 0-1) and the resting S (`curl`).
func pose(p: Vector4, frame: Projection, length: float, phase: float, amp: float, bend: float, back: float, curl: float) -> void:
	if body == null:
		return
	body.position = p
	body.basis = Projection(frame.x * length, frame.y * length, frame.z * length, frame.w * length)
	for holder in _pieces:
		var sc: float = float((holder as Node4D).get_meta("s"))
		var sp: Vector2 = spine(sc, phase, amp, bend, back, curl)
		(holder as Node4D).position = Vector4(sp.x, 0.0, SNOUT_Z - sc, 0.0)
		(holder as Node4D).basis = Kit.yaw(sp.y)


static func spine(s: float, phase: float, amp: float, bend: float, back: float, curl: float) -> Vector2:
	var k: float = TAU / WAVELENGTH
	var th: float = k * s - phase
	var env: float = lerpf(0.08 + 0.92 * pow(s, 1.6), 0.55 + 0.45 * s, back)
	var denv: float = lerpf(0.92 * 1.6 * pow(maxf(s, 0.0001), 0.6), 0.45, back)
	var lat: float = amp * env * sin(th) + bend * (s - 0.4) * (s - 0.4) + curl * 0.06 * sin(s * 7.0)
	var d: float = amp * (denv * sin(th) + env * cos(th) * k) + 2.0 * bend * (s - 0.4) + curl * 0.06 * 7.0 * cos(s * 7.0)
	return Vector2(lat, d)


# -- its shape (lofted once, baked) ----------------------------------------------------------------------------

static func radius(s: float) -> float:
	var head: float = sqrt(clampf(s / 0.07, 0.0, 1.0))
	var tail: float = 1.0 - smoothstep(0.5, 1.0, s) * 0.88
	return 0.034 * head * tail


## Half width, half height at s (body lengths).
static func half_axes(s: float) -> Vector2:
	var r: float = maxf(radius(s), 0.0025)
	var flat: float = smoothstep(0.4, 1.0, s)
	return Vector2(r * (1.0 - 0.55 * flat), r * (1.0 + 0.25 * flat))


## The long fin's height at s, above (up 1) or below (-1); 0 where it has not begun.
static func fin_height(s: float, up: float) -> float:
	var s0: float = 0.33 if up > 0.0 else 0.42
	if s < s0:
		return 0.0
	return 0.016 * smoothstep(s0, s0 + 0.12, s) * (1.0 - 0.3 * smoothstep(0.9, 1.0, s))


func _piece(s0: float, s1: float, sc: float) -> ArrayTetraMesh4D:
	var n: int = 6 if detail < 2 else 8
	var r: Vector2i = Vector2i(4, 10) if detail < 2 else Vector2i(5, 16)
	var parts: Array = []
	var sections: Array = []
	for k in n:
		var s: float = lerpf(maxf(s0, 0.004), minf(s1, 0.996), float(k) / float(n - 1))
		var a: Vector2 = half_axes(s)
		sections.append({"center": Vector4(0.0, 0.0, sc - s, 0.0), "radius": a.x, "v_scale": 1.0, "w_scale": 1.0,
			"basis": Kit.scale(1.0, a.y / a.x, 1.0, W_ROUND), "color": Color.WHITE})
	parts.append(Loft.build(sections, r.x, r.y, true, false, true, 1, false))
	# The long fin, above and below, where it runs along this piece: lofted along its base, each
	# section a ball the fin's height across, thin across x and W, its foot sunk in the body.
	for up in [1.0, -1.0]:
		var fs0: float = maxf(s0, 0.33 if up > 0.0 else 0.42)
		if fs0 >= s1 - 0.01:
			continue
		var fin: Array = []
		for k in 4:
			var s: float = lerpf(fs0, minf(s1, 0.998), float(k) / 3.0)
			var a: Vector2 = half_axes(s)
			var h: float = maxf(fin_height(s, up), 0.003)
			var half: float = (h + a.y * 0.25) * 0.5
			fin.append({"center": Vector4(0.0, up * (a.y * 0.75 + half), sc - s, 0.0), "radius": half, "v_scale": 1.0, "w_scale": 1.0,
				"basis": Kit.scale(0.0022 / half, 1.0, 1.0, 1.4 * 0.0022 / half), "color": Color.WHITE})
		parts.append(Loft.build(fin, 3, 8, true, false, true, 1, false))
	var m: ArrayTetraMesh4D = Kit.merge(parts)
	Kit.paint(m, func(q: Vector4) -> Vector3: return _coord(sc - q.z, q.y, false))
	return m


## Its texture coordinates: x how high on the body (0 the belly, 1 the back) or, on the fin, how far
## out; y the part (a body row, a fin row, a pectoral row); z along it (the mottle).
## (Each kept to its texels' centres, so the sampler never blends across the texture's wrap.)
static func _coord(s: float, y: float, pectoral: bool) -> Vector3:
	s = clampf(s, 0.0, 1.0)
	var z: float = (0.5 + s * 15.0) / 16.0
	var a: Vector2 = half_axes(s)
	if pectoral:
		return Vector3(0.5, 0.625, z)
	if absf(y) > a.y * 1.02:
		var out: float = clampf((absf(y) - a.y) / maxf(fin_height(s, signf(y)), 0.003), 0.0, 1.0)
		return Vector3((0.5 + out * 31.0) / 32.0, 0.375, z)
	return Vector3((0.5 + clampf(0.5 + 0.5 * y / a.y, 0.0, 1.0) * 31.0) / 32.0, 0.125, z)


func _eyes(sc: float) -> ArrayTetraMesh4D:
	var parts: Array = []
	for side in [1.0, -1.0]:
		var c := Vector4(side * 0.016, 0.012, sc - 0.035, 0.0)
		var sections: Array = []
		for k in 4:
			var t: float = lerpf(-0.8, 0.8, float(k) / 3.0)
			sections.append({"center": c + Vector4(t * 0.006, 0.0, 0.0, 0.0), "radius": 0.006 * sqrt(1.0 - t * t), "v_scale": 1.0, "w_scale": 1.0, "color": Color.WHITE})
		parts.append(Loft.build(sections, 3, 8, true, false, true, 0, false))
	var m: ArrayTetraMesh4D = Kit.merge(parts)
	Kit.paint(m, func(_q: Vector4) -> Vector3: return Vector3(0.5, 0.875, 0.5))
	return m


## Small rounded paddles behind the gill, flat across y and thin in W.
func _pectorals(sc: float) -> ArrayTetraMesh4D:
	var parts: Array = []
	for side in [1.0, -1.0]:
		var root := Vector3(side * 0.022, -0.008, sc - 0.12)
		var d := Vector3(side * 0.9, -0.25, -0.35).normalized()
		var sections: Array = []
		for k in 4:
			var u: float = lerpf(0.05, 0.85, float(k) / 3.0)
			var r: float = 0.009 * (0.5 + 0.5 * sin(PI * (0.2 + 0.6 * u)))
			var c: Vector3 = root + d * (0.03 * u)
			sections.append({"center": Vector4(c.x, c.y, c.z, 0.0), "radius": r, "v_scale": 1.0, "w_scale": 1.0,
				"basis": Kit.scale(1.0, 0.0018 / r, 1.0, 1.4 * 0.0018 / r), "color": Color.WHITE})
		parts.append(Loft.build(sections, 3, 8, true, false, true, 1, false))
	var m: ArrayTetraMesh4D = Kit.merge(parts)
	Kit.paint(m, func(q: Vector4) -> Vector3: return _coord(sc - q.z, q.y, true))
	return m


## A European eel in its yellow phase: dark olive on the back, yellow-grey flanks, a pale belly, a
## faint mottle along it; the fin darker at its root; the pectorals olive; the eyes black. (eel.gdshader's
## colours.) Rows: body, fin, pectoral, eye.
static func skin() -> TetraMaterial4D:
	var back := Color(0.10, 0.10, 0.05)
	var flank := Color(0.42, 0.38, 0.18)
	var belly := Color(0.78, 0.70, 0.42)
	var noise := FastNoiseLite.new()
	noise.seed = 1414
	noise.frequency = 0.35
	var slices: Array = []
	for z in 16:
		var img: Image = Image.create(32, 4, false, Image.FORMAT_RGBA8)
		for i in 32:
			var x: float = float(i) / 31.0
			var dorsal: float = x * 2.0 - 1.0
			var c: Color = flank.lerp(back, smoothstep(-0.1, 0.6, dorsal))
			c = c.lerp(belly, smoothstep(-0.35, -0.8, dorsal))
			var mottle: float = 0.9 + 0.12 * (0.5 + 0.5 * noise.get_noise_2d(float(z) * 3.0, float(i)))
			img.set_pixel(i, 0, c * mottle)
			img.set_pixel(i, 1, Color(0.26, 0.22, 0.10).lerp(Color(0.45, 0.40, 0.22), x))
			img.set_pixel(i, 2, Color(0.36, 0.32, 0.16))
			img.set_pixel(i, 3, Color(0.03, 0.03, 0.02))
		slices.append(img)
	return Kit.tex_material(slices)


# -- meshes ----------------------------------------------------------------------------------------------------

func _add(holder: Node, nm: String, mesh: ArrayTetraMesh4D, mat: TetraMaterial4D) -> void:
	if mesh == null:
		return
	tets += Kit.add_mesh(holder, nm, mesh, mat)
	meshes += 1


func _cached(key: String, build_fn: Callable) -> ArrayTetraMesh4D:
	return Kit.cached(BAKED + "%s_d%d_%s.res" % [key, detail, BAKE_VERSION], build_fn)
