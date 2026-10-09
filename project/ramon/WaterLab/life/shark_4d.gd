extends Node4D

## WATER LAB: the hammerhead (Ramon, 9 Oct: "a little hammer shark, this will be the biggest fish in the
## tank ... perfect showcase for the loft system we build"). A young scalloped hammerhead, 2.4 m, LOFTED
## IN 4D by our loft builder (carried chickenpen/scripts/loft_builder_4d.gd) and cut into rigid pieces,
## as the QuantumRange chicken's wings and Trym's plesiosaur are: lofted once (baked under life/baked/),
## then only the pieces' transforms move. A real 4D body: turn the tank through W and its cut changes.
##
## THE SHAPE (Sphyrna lewini; the research in follow_up/water_lab.md): the hammer (cephalofoil) 26% of
## its length across, its front edge arched, an eye at each tip; a tall, swept first dorsal over the
## pectorals; small pectorals; a low second dorsal, pelvics and anal fin; a heterocercal tail, the upper
## lobe about a quarter of its length, the lower 40% of that. Grey-bronze above, white below, the line
## between them sharp.
##
## THE SWIM: six body pieces from the head to the tail fin, each placed at its spine point and turned
## with the spine there; the spine's wave (half amplitudes, body lengths): 0.025 at the head, least at
## the pectorals (the pivot), 0.03 mid-body, 0.06 at three quarters, 0.10 at the tail; a wavelength of
## 0.9 of its length, 0.6 to 1 beat a second; the head swinging a little faster as well (the "double
## oscillation" filmed in hammerheads). Glides between bursts. Turns flat: no roll.
## WHERE IT SWIMS: long passes along the tank at mid-water, its whole length; at each end it turns
## THROUGH W (the tank is 7 m deep in W), fading out of your slice for a moment and back, heading the
## other way: a 4D turn, and the only room a 2.4 m shark has to turn in a 3.2 m deep tank.
##
## In the water's own frame (life/). NO class_name (engine_gotchas.md).

const Loft := preload("res://ramon/WaterLab/carried/chickenpen/scripts/loft_builder_4d.gd")
const BAKED := "res://ramon/WaterLab/life/baked/"
const BAKE_VERSION := "v3"

@export var length: float = 2.4
@export var cruise: float = 0.6
var half_extents: Vector4 = Vector4(9.2, 2.4, 1.6, 3.5)
var floor_y: float = -2.14
var obstacles: Array = []
var ground: Node = null

## Where it is (this node's frame) and its 4D frame: right, up, ahead, ana (columns).
var p := Vector4(-6.0, 0.3, -0.2, 0.0)
var frame := Projection.IDENTITY
var cpu_us: float = 0.0
var tets: int = 0
var _body: Node4D
var _pieces: Array = []
var _phase: float = 0.0
var _amp: float = 0.6
var _v: float = 0.5
var _dir: float = 1.0
var _turning: float = 0.0
var _turn_w: float = 1.0
var _glide: float = 0.0
var _t: float = 0.0
var _rng := RandomNumberGenerator.new()

## The body's half width, half height (above/below the midline) along it, s from the snout: body lengths.
## (9 Oct, second pass: slimmer, about 12% of its length across at its widest, so the hammer reads.)
const PROFILE := [
	[0.02, 0.028, 0.032, 0.024], [0.08, 0.040, 0.050, 0.034], [0.16, 0.052, 0.066, 0.044], [0.26, 0.060, 0.076, 0.050],
	[0.36, 0.060, 0.075, 0.050], [0.46, 0.053, 0.065, 0.044], [0.56, 0.043, 0.052, 0.036], [0.66, 0.032, 0.038, 0.027],
	[0.74, 0.023, 0.028, 0.019], [0.80, 0.017, 0.023, 0.014], [0.84, 0.015, 0.026, 0.012],
]
## The rigid pieces of the body: [name, s from, s to]; neighbours overlap so a bend never opens.
const PIECES := [["Head", 0.0, 0.16], ["Chest", 0.11, 0.34], ["Middle", 0.29, 0.52], ["Hips", 0.47, 0.70], ["Tail", 0.65, 0.84], ["TailFin", 0.80, 1.0]]


func _ready() -> void:
	_rng.seed = 2611
	_body = Node4D.new()
	_body.name = "Body"
	add_child(_body)
	var skin: TetraMaterial4D = _skin()
	var fin: TetraMaterial4D = _fin_skin()
	for pc in PIECES:
		var holder := Node4D.new()
		holder.name = String(pc[0])
		_body.add_child(holder)
		var sc: float = (float(pc[1]) + float(pc[2])) * 0.5
		holder.set_meta("s", sc)
		_pieces.append(holder)
		var mesh: ArrayTetraMesh4D = _cached("shark_" + String(pc[0]), _piece_builder(float(pc[1]), float(pc[2]), sc))
		_add_mesh(holder, "Skin", mesh, skin if String(pc[0]) != "TailFin" else fin)
	# The fins on their pieces.
	_add_mesh(_pieces[0], "Hammer", _cached("shark_hammer", _hammer), skin)
	_add_mesh(_pieces[0], "Eyes", _cached("shark_eyes", _eyes), _flat(Color(0.03, 0.03, 0.03)))
	_add_mesh(_pieces[1], "Pectorals", _cached("shark_pectorals", _pectorals), fin)
	_add_mesh(_pieces[2], "Dorsal", _cached("shark_dorsal", _dorsal), fin)
	_add_mesh(_pieces[3], "Pelvics", _cached("shark_pelvics", _pelvics), fin)
	_add_mesh(_pieces[4], "SecondDorsal", _cached("shark_dorsal2", _dorsal2), fin)
	frame = _frame_for(Vector4(1.0, 0.0, 0.0, 0.0))
	_pose()


# -- swimming -------------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	var t0: int = Time.get_ticks_usec()
	var dt: float = minf(delta, 0.05)
	_t += dt
	var he: Vector4 = half_extents
	var ahead: Vector4 = frame.z
	# Bursts and glides.
	_glide -= dt
	if _glide < -4.0:
		_glide = _rng.randf_range(1.0, 3.0)
	var beating: bool = _glide <= 0.0
	_amp = lerpf(_amp, 1.0 if beating else 0.35, 1.0 - exp(-2.0 * dt))
	_v = lerpf(_v, cruise if beating else cruise * 0.75, 1.0 - exp(-0.8 * dt))
	_phase = fmod(_phase + TAU * (0.6 + 0.35 * _amp) * dt, TAU * 64.0)
	# At an end: the turn through W. The heading swings from +x through +W (or -W) to -x and back
	# into the slice; a little up or down as it goes keeps it off the sand.
	var end_near: bool = (_dir > 0.0 and p.x > he.x - 2.6) or (_dir < 0.0 and p.x < -he.x + 2.6)
	if end_near and _turning <= 0.0:
		_turning = 1.0
		_turn_w = 1.0 if p.w <= 0.0 else -1.0
	var want: Vector4
	if _turning > 0.0:
		var a: float = (1.0 - _turning) * PI
		want = Vector4(_dir * cos(a), 0.0, 0.0, _turn_w * sin(a))
		_turning -= dt * _v / (PI * 1.6)
		if _turning <= 0.0:
			_dir = -_dir
	else:
		# Along the tank, mid-water, back toward the slice in W, clear of the sand and the stones.
		var mid_y: float = clampf(0.4 + 0.5 * sin(_t * 0.07), -0.4, he.y - 1.0)
		want = Vector4(_dir, (mid_y - p.y) * 0.25, (-0.1 - p.z) * 0.2, -p.w * 0.35)
		var floor_at: float = float(ground.call("height_at", p.x, p.z, p.w)) if ground != null else floor_y
		if p.y < floor_at + 0.9:
			want.y += 0.6
		for ob in obstacles:
			var d: Vector4 = p + ahead * length * 0.5 - (ob[0] as Vector4)
			var r: float = float(ob[1]) + length * 0.25
			if d.length() < r and d.length() > 0.001:
				want += d.normalized() * (r - d.length()) / r * 1.2
	want = want.normalized()
	_steer(want, dt, 1.4 if _turning > 0.0 else 0.5)
	p += frame.z * _v * dt
	for k in 4:
		var lim: float = he[k] - (0.35 if k != 0 else 0.6)
		p[k] = clampf(p[k], -lim, lim)
	_pose()
	cpu_us = lerpf(cpu_us, float(Time.get_ticks_usec() - t0), 0.05)


## Turns the whole frame toward `want` by at most `rate` rad/s, in the plane of the two headings, so
## right, up and ana are carried round with it (no twist, no roll).
func _steer(want: Vector4, dt: float, rate: float) -> void:
	var h: Vector4 = frame.z
	var c: float = clampf(h.dot(want), -1.0, 1.0)
	var ang: float = acos(c)
	if ang < 0.0001:
		return
	var perp: Vector4 = want - h * c
	if perp.length() < 0.0001:
		return
	perp = perp.normalized()
	var step: float = minf(ang, rate * dt)
	var cs: float = cos(step)
	var sn: float = sin(step)
	var cols: Array = [frame.x, frame.y, frame.z, frame.w]
	for i in 4:
		var v: Vector4 = cols[i]
		var a: float = v.dot(h)
		var b: float = v.dot(perp)
		var rest: Vector4 = v - h * a - perp * b
		cols[i] = rest + h * (a * cs - b * sn) + perp * (a * sn + b * cs)
	frame = Projection(cols[0], cols[1], cols[2], cols[3])
	# Keep it level: up stays world up as near as the heading allows (sharks turn flat).
	var up: Vector4 = Vector4(0, 1, 0, 0) - frame.z * frame.z.y
	if up.length() > 0.1:
		frame = _frame_for(frame.z, up.normalized(), frame.x)


## A frame with `ahead` as z, `up` as y, the right carried from `right_hint`, ana the fourth.
func _frame_for(ahead: Vector4, up: Vector4 = Vector4(0, 1, 0, 0), right_hint: Vector4 = Vector4(0, 0, -1, 0)) -> Projection:
	var z: Vector4 = ahead.normalized()
	var y: Vector4 = (up - z * up.dot(z)).normalized()
	var x: Vector4 = right_hint - z * right_hint.dot(z) - y * right_hint.dot(y)
	if x.length() < 0.01:
		x = Vector4(0, 0, 0, 1) - z * z.w - y * y.w
	x = x.normalized()
	# The fourth: what is left, by Gram-Schmidt from the axes.
	var w: Vector4 = Vector4.ZERO
	for cand in [Vector4(0, 0, 0, 1), Vector4(0, 0, 1, 0), Vector4(1, 0, 0, 0)]:
		w = cand - z * cand.dot(z) - y * cand.dot(y) - x * cand.dot(x)
		if w.length() > 0.1:
			break
	return Projection(x, y, z, w.normalized())


## The pieces placed along the bent spine, the hammer's quicker swing on the head.
func _pose() -> void:
	_body.position = p
	_body.basis = frame
	for holder in _pieces:
		var s: float = float((holder as Node4D).get_meta("s"))
		var sp: Vector2 = _spine(s)
		var yaw: float = atan(sp.y)
		if holder == _pieces[0]:
			yaw += 0.06 * _amp * sin(_phase * 2.0)
		(holder as Node4D).position = Vector4(sp.x * length, 0.0, (0.5 - s) * length, 0.0)
		(holder as Node4D).basis = Basis4D.from_zx(-yaw)


## The spine's sideways offset (body lengths) and slope at s.
func _spine(s: float) -> Vector2:
	var env: float = _envelope(s) * _amp
	var k: float = TAU / 0.9
	var th: float = k * s - _phase
	var de: float = (_envelope(s + 0.01) - _envelope(s - 0.01)) / 0.02 * _amp
	return Vector2(env * sin(th), de * sin(th) + env * cos(th) * k)


## Half amplitude along the body (measured, follow_up/water_lab.md): 0.025 head, 0.01 at the pivot,
## 0.03 mid, 0.06 at three quarters, 0.10 at the tail.
static func _envelope(s: float) -> float:
	var pts: Array = [[0.0, 0.025], [0.22, 0.010], [0.5, 0.030], [0.75, 0.060], [1.0, 0.100]]
	for i in pts.size() - 1:
		if s <= float(pts[i + 1][0]):
			var u: float = (s - float(pts[i][0])) / (float(pts[i + 1][0]) - float(pts[i][0]))
			return lerpf(float(pts[i][1]), float(pts[i + 1][1]), smoothstep(0.0, 1.0, clampf(u, 0.0, 1.0)))
	return 0.1


# -- its shape (lofted once, baked) ----------------------------------------------------------------------------

## EVERY SECTION IS A ROUND BALL SHAPED BY ITS OWN BASIS (the loft builder applies a section's `basis`
## to the finished cross-section). Which of the builder's section axes ends up along x, y or W depends
## on which way the spine runs (its frames are seeded from the world axes), so for a swept fin or the
## hammer an ellipse given by radius and scales comes out turned some odd way; a unit ball squashed by
## an explicit scale cannot.
static func _scale(sx: float, sy: float, sz: float, sw: float) -> Projection:
	return Projection(Vector4(sx, 0, 0, 0), Vector4(0, sy, 0, 0), Vector4(0, 0, sz, 0), Vector4(0, 0, 0, sw))


## A section of the body (its spine along -z): half width, half height, half W, the middle `up` above
## the spine; at piece-local z `local_from - s` lengths.
func _body_section(s: float, hw: float, hh: float, hW: float, up: float, local_from: float) -> Dictionary:
	var L: float = length
	# The width as the radius (the builder puts its end caps' tips by the radius, before the basis),
	# the height and W as scales of it.
	return {"center": Vector4(0.0, up * L, (local_from - s) * L, 0.0), "radius": hw * L, "v_scale": 1.0, "w_scale": 1.0,
		"basis": _scale(1.0, hh / hw, 1.0, hW / hw), "color": Color.WHITE}


## The profile at s: [half width, half height, half W].
static func _at(s: float) -> Vector3:
	for i in PROFILE.size() - 1:
		if s <= float(PROFILE[i + 1][0]):
			var u: float = clampf((s - float(PROFILE[i][0])) / (float(PROFILE[i + 1][0]) - float(PROFILE[i][0])), 0.0, 1.0)
			return Vector3(lerpf(PROFILE[i][1], PROFILE[i + 1][1], u), lerpf(PROFILE[i][2], PROFILE[i + 1][2], u), lerpf(PROFILE[i][3], PROFILE[i + 1][3], u))
	var last: Array = PROFILE[PROFILE.size() - 1]
	return Vector3(last[1], last[2], last[3])


func _piece_builder(s0: float, s1: float, sc: float) -> Callable:
	return func() -> ArrayTetraMesh4D:
		if s0 >= 0.8:
			return _tail_fin(sc)
		var sections: Array = []
		var n: int = 6
		for k in n:
			var s: float = lerpf(maxf(s0, 0.01), minf(s1, 0.84), float(k) / float(n - 1))
			var a: Vector3 = _at(s)
			sections.append(_body_section(s, a.x, a.y, a.z, 0.0, 0.5 - sc + sc))
		# Piece-local: its centre at the origin.
		for sec in sections:
			var c: Vector4 = sec["center"]
			c.z -= (0.5 - sc) * length
			sec["center"] = c
		return Loft.build(sections, 4, 12, true, false, true, 1, false)


## The heterocercal tail: an upper lobe up and back, a lower lobe a third its length down and back.
func _tail_fin(sc: float) -> ArrayTetraMesh4D:
	var L: float = length
	var parts: Array = []
	for lobe in [[0.27, 0.62, 0.05], [0.11, -0.62, 0.04]]:
		var span: float = float(lobe[0]) * L
		var ang: float = float(lobe[1])
		var dir := Vector4(0.0, sin(ang), -cos(ang), 0.0)
		var root := Vector4(0.0, 0.0, (0.5 - 0.81 - (0.5 - sc)) * L, 0.0)
		var sections: Array = []
		for k in 5:
			var u: float = float(k) / 4.0
			var chord: float = float(lobe[2]) * L * (1.0 - 0.75 * u)
			var thick: float = 0.012 * L * (1.0 - 0.6 * u)
			# A ball the chord across, flattened to the fin's thickness in x and a little W.
			sections.append({"center": root + dir * (u * span) + Vector4(0.0, 0.0, -chord * 0.4, 0.0), "radius": chord * 0.5,
				"v_scale": 1.0, "w_scale": 1.0, "basis": _scale(thick / (chord * 0.5), 1.0, 1.0, 1.6 * thick / (chord * 0.5)), "color": Color.WHITE})
		parts.append(Loft.build(sections, 3, 8, true, false, true, 1, false))
	return _merge(parts)


## The hammer: lofted across the head (along x), flat, its front edge arched, thinning to the tips.
func _hammer() -> ArrayTetraMesh4D:
	var L: float = length
	var half: float = 0.15 * L
	var sections: Array = []
	var n: int = 9
	for k in n:
		var u: float = lerpf(-1.0, 1.0, float(k) / float(n - 1))
		var chord: float = (0.075 - 0.035 * u * u) * L
		# The front edge arched and the tips swept back: the cephalofoil is a wing, not a bar.
		var front: float = 0.012 * L * (1.0 - u * u) - 0.045 * L * pow(absf(u), 1.6)
		# A ball the chord across, flattened to the hammer's thickness in y and its depth in W.
		sections.append({"center": Vector4(u * half, 0.004 * L, (0.5 - 0.035 - (0.5 - 0.08)) * L + front, 0.0), "radius": chord * 0.5,
			"v_scale": 1.0, "w_scale": 1.0, "basis": _scale(1.0, 0.022 * L / (chord * 0.5), 1.0, 0.035 * L / (chord * 0.5)), "color": Color.WHITE})
	return Loft.build(sections, 4, 10, true, false, true, 1, false)


func _eyes() -> ArrayTetraMesh4D:
	var L: float = length
	var parts: Array = []
	for side in [-1.0, 1.0]:
		var c := Vector4(side * 0.148 * L, 0.006 * L, (0.42 - 0.42) * L + 0.04 * L, 0.0)
		var sections: Array = []
		for k in 3:
			var u: float = float(k) / 2.0 - 0.5
			sections.append({"center": c + Vector4(side * u * 0.012 * L, 0.0, 0.0, 0.0), "radius": 0.009 * L * sqrt(maxf(1.0 - 4.0 * u * u, 0.05)), "v_scale": 1.0, "w_scale": 1.0, "color": Color.WHITE})
		parts.append(Loft.build(sections, 3, 6, true, false, true, 0, false))
	return _merge(parts)


## A thin fin from a root on the body out along `dir`: chord and thickness tapering to the tip, flat
## across `thin_axis` (0 x: an upright fin; 1 y: a flat one).
func _fin(root: Vector4, dir: Vector4, span: float, chord: float, sweep: float, thin_axis: int = 0) -> ArrayTetraMesh4D:
	var L: float = length
	var sections: Array = []
	for k in 5:
		var u: float = float(k) / 4.0
		var ch: float = chord * L * (1.0 - 0.8 * u) * 0.5
		var thin: float = 0.007 * L * (1.0 - 0.5 * u) / ch
		var b: Projection = _scale(thin, 1.0, 1.0, 1.4 * thin) if thin_axis == 0 else _scale(1.0, thin, 1.0, 1.4 * thin)
		sections.append({"center": root + dir * (u * span * L) + Vector4(0.0, 0.0, -sweep * u * u * L, 0.0), "radius": ch,
			"v_scale": 1.0, "w_scale": 1.0, "basis": b, "color": Color.WHITE})
	return Loft.build(sections, 3, 8, true, false, true, 1, false)


func _dorsal() -> ArrayTetraMesh4D:
	return _fin(Vector4(0.0, 0.07 * length, 0.02 * length, 0.0), Vector4(0.0, 1.0, -0.35, 0.0).normalized(), 0.13, 0.07, 0.05)


func _dorsal2() -> ArrayTetraMesh4D:
	return _fin(Vector4(0.0, 0.02 * length, 0.03 * length, 0.0), Vector4(0.0, 1.0, -0.6, 0.0).normalized(), 0.035, 0.03, 0.02)


func _pectorals() -> ArrayTetraMesh4D:
	var parts: Array = []
	for side in [-1.0, 1.0]:
		parts.append(_fin(Vector4(side * 0.06 * length, -0.05 * length, 0.04 * length, 0.0), Vector4(side * 0.85, -0.35, -0.4, 0.0).normalized(), 0.14, 0.055, 0.03, 1))
	return _merge(parts)


func _pelvics() -> ArrayTetraMesh4D:
	var parts: Array = []
	for side in [-1.0, 1.0]:
		parts.append(_fin(Vector4(side * 0.03 * length, -0.06 * length, -0.06 * length, 0.0), Vector4(side * 0.5, -0.6, -0.6, 0.0).normalized(), 0.05, 0.03, 0.01, 1))
	# The anal fin, under the hips' back end.
	parts.append(_fin(Vector4(0.0, -0.045 * length, -0.09 * length, 0.0), Vector4(0.0, -1.0, -0.6, 0.0).normalized(), 0.035, 0.03, 0.01))
	return _merge(parts)


# -- meshes and materials -------------------------------------------------------------------------------------

func _add_mesh(holder: Node, nm: String, mesh: ArrayTetraMesh4D, mat: TetraMaterial4D) -> void:
	if mesh == null:
		return
	var mi := MeshInstance4D.new()
	mi.name = nm
	mi.mesh = mesh
	mi.material_override = mat
	holder.add_child(mi)
	tets += mesh.get_simplex_cell_vertex_indices().size() / 4


func _cached(key: String, build: Callable) -> ArrayTetraMesh4D:
	var path: String = BAKED + "%s_%s.res" % [key, BAKE_VERSION]
	if ResourceLoader.exists(path):
		var r: Resource = load(path)
		if r is ArrayTetraMesh4D:
			return r
	var m: ArrayTetraMesh4D = build.call()
	if m != null:
		_paint_coords(m)
		m.calculate_boundary_normals(false)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BAKED))
		ResourceSaver.save(m, path)
	return m


func _merge(parts: Array) -> ArrayTetraMesh4D:
	var pos := PackedVector4Array()
	var cells := PackedInt32Array()
	for m in parts:
		if m == null:
			continue
		var off: int = pos.size()
		pos.append_array((m as ArrayTetraMesh4D).get_vertex_positions())
		for c in (m as ArrayTetraMesh4D).get_simplex_cell_vertex_indices():
			cells.append(c + off)
	var out := ArrayTetraMesh4D.new()
	out.set_vertex_positions(pos)
	out.set_simplex_cell_vertex_indices(cells)
	return out


## Texture coordinates from height: the countershading (grey-bronze above, white below) is a lookup by
## how high a point is on the body, and the fins' dark tips by how far out they reach.
func _paint_coords(m: ArrayTetraMesh4D) -> void:
	var pos: PackedVector4Array = m.get_vertex_positions()
	var tex := PackedVector3Array()
	tex.resize(pos.size())
	var L: float = length
	for i in pos.size():
		var q: Vector4 = pos[i]
		tex[i] = Vector3(clampf(0.5 + q.y / (0.2 * L), 0.0, 1.0), clampf(Vector2(q.x, q.y).length() / (0.2 * L), 0.0, 1.0), 0.5)
	m.set_texture_map_values(tex)
	m.set_simplex_cell_texture_map_indices(m.get_simplex_cell_vertex_indices())


## Grey-bronze above, white below, a soft line between (x of the texture: height).
func _skin() -> TetraMaterial4D:
	var img: Image = Image.create(32, 2, false, Image.FORMAT_RGBA8)
	for i in 32:
		var y: float = float(i) / 31.0
		var c: Color = Color(0.90, 0.89, 0.85).lerp(Color(0.30, 0.30, 0.26), smoothstep(0.45, 0.53, y))
		c = c.lerp(Color(0.24, 0.24, 0.21), smoothstep(0.7, 1.0, y))
		for j in 2:
			img.set_pixel(i, j, c)
	return _tex_material([img, img])


## The fins: the body's colours, darker toward the tips (y of the texture: reach).
func _fin_skin() -> TetraMaterial4D:
	var slices: Array = []
	for k in 2:
		var img: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		for i in 16:
			for j in 16:
				var y: float = float(i) / 15.0
				var reach: float = float(j) / 15.0
				var c: Color = Color(0.84, 0.83, 0.79).lerp(Color(0.30, 0.30, 0.26), smoothstep(0.40, 0.55, y))
				c = c.lerp(Color(0.16, 0.16, 0.15), smoothstep(0.55, 0.95, reach) * 0.7)
				img.set_pixel(i, j, c)
		slices.append(img)
	return _tex_material(slices)


static func _tex_material(slices: Array) -> TetraMaterial4D:
	var imgs: Array[Image] = []
	for s in slices:
		imgs.append(s)
	var tex := ImageTexture3D.new()
	tex.create(Image.FORMAT_RGBA8, imgs[0].get_width(), imgs[0].get_height(), imgs.size(), false, imgs)
	var m := TetraMaterial4D.new()
	m.set("albedo_source", 3)
	m.set("albedo_texture_3d", tex)
	return m


static func _flat(c: Color) -> TetraMaterial4D:
	var m := TetraMaterial4D.new()
	m.albedo_color = c
	return m


func bench_row() -> Array:
	return ["Hammerhead", "1", "%.3f ms" % (cpu_us / 1000.0), str(_pieces.size() + 6), "lofted in 4D, rigid pieces"]
