extends RefCounted

## BOTANY LAB, round 3 (follow_up/arboretum.md section 9, steps 2-7): one flowering plant lofted in 4D
## from its species (flora_species.gd), baked once under flora/baked/, and the material every plant in
## the flower room shares (flora_plant.gdshader over one 3D texture of every species' colours).
##
## HOW A PLANT IS BUILT. Its foot at the origin, y up, its front toward +z (the room turns it to face
## you). Every part is a loft (carried/chickenpen/scripts/loft_builder_4d.gd) or, for the hundreds of
## tiny florets and filaments, a spindle (two cones on a tetrahedron, 8 cells), and they are merged:
##   stem     a tube round in all three directions across it, curving toward the front, nodding
##            where the species nods
##   petals   thin blades along a curved midrib: flat across their face, round across the other two
##            directions (one in the slice, one through W), so a petal is a thin 3D blade in 4D and
##            the slice shows its outline. Width by a profile (widest at `peak`, rounded or pointed)
##   leaves   the same blades from nodes up the stem, arching, toothed or lobed by the species
##   centres  domes round in all three directions of their face: a 3D disc in every cut
##   florets  spindles out along every direction of the 3-sphere (allium, dandelion)
## and the arrangements are what flora_species.gd's header calls ring + W pair, band, ball and bells.
##
## THE TEXTURE (one for every plant): u along a part (0 at its base), v out from its midrib (0 on it,
## 1 at its edge), the part's kind in the third coordinate; each species has its own band of rows.
## flora_species.gd's colours paint it (paint_colour below).
##
## EVERY LOOP IS BOUNDED (section 8: an unbounded loop took Ramon's PC down twice): counts come from
## the species data and are capped by MAX_PARTS and MAX_COUNT.
##
## NO class_name (engine_gotchas.md).

const Loft := preload("res://ramon/Arboretum/botany_lab/carried/chickenpen/scripts/loft_builder_4d.gd")
const Kit := preload("res://ramon/Arboretum/botany_lab/flora/flora_kit.gd")
const Species := preload("res://ramon/Arboretum/botany_lab/flora/flora_species.gd")
const PlantShader := preload("res://ramon/Arboretum/botany_lab/flora/flora_plant.gdshader")
const BAKED := "res://ramon/Arboretum/botany_lab/flora/baked/"
const BAKE_VERSION := "v1"
## How many shapes of each species are baked (each pocket mixes them, turned and scaled).
const VARIANTS := 2

## The part kinds: the texture's slices, and the shader's (flora_plant.gdshader `kinds`).
enum {STEM, LEAF, PETAL, PETAL2, CENTRE, STAMEN, EXTRA, SPOT}
const KINDS := 8
const U_N := 48
const V_N := 16
const ROWS := 16

const UP := Vector4(0, 1, 0, 0)
const FRONT := Vector4(0, 0, 1, 0)
const SIDE := Vector4(1, 0, 0, 0)
const ANA := Vector4(0, 0, 0, 1)
const GOLDEN := 2.399963229728653
## The most parts one plant may have, and the most of any one repeated thing (rays, florets, bells).
const MAX_PARTS := 1500
const MAX_COUNT := 400

static var _material: TetraMaterial4D = null


## A plant's mesh: baked under flora/baked/ the first time, loaded after. Its meta holds "perches"
## (where a butterfly may land, in the plant's own space), "bloom" (the main flower's middle) and
## "height".
static func mesh(key: String, variant: int) -> ArrayTetraMesh4D:
	var path: String = BAKED + "%s_%d_%s.res" % [key, variant, BAKE_VERSION]
	return Kit.cached(path, func() -> ArrayTetraMesh4D: return build(key, variant))


## A bloom alone, facing +y from the origin (no stem, no leaves): the vines' flowers. Baked as the plants are.
static func bloom_mesh(key: String) -> ArrayTetraMesh4D:
	var path: String = BAKED + "%s_bloom_%s.res" % [key, BAKE_VERSION]
	return Kit.cached(path, func() -> ArrayTetraMesh4D: return build(key, 0, true))


## A plant built now (no bake); `bloom_only` the flower alone.
static func build(key: String, variant: int, bloom_only: bool = false) -> ArrayTetraMesh4D:
	var sp: Dictionary = Species.by_key(key)
	if sp.is_empty():
		push_warning("flower_4d: no species %s" % key)
		return null
	var b := Builder.new()
	b.sp = sp
	b.row = int(sp["row"])
	b.rng.seed = hash(key) + variant * 7919 + 17
	if bloom_only or bool(sp.get("bloom_only", false)):
		b.bloom_alone()
	else:
		b.plant()
	var m: ArrayTetraMesh4D = Kit.merge(b.parts)
	if m == null:
		return null
	m.calculate_boundary_normals(false)
	m.set_meta("perches", b.perches)
	m.set_meta("bloom", b.bloom)
	m.set_meta("height", b.top.y)
	m.set_meta("parts", b.parts.size())
	return m


## The builder's light loft for other parts of the room (vines): Loft.build without its span splitting.
static func light_loft(sections: Array, rings: int, sides: int) -> ArrayTetraMesh4D:
	return Builder.new().loft(sections, rings, sides)


## The one material every plant wears (built once).
static func material() -> TetraMaterial4D:
	if _material != null:
		return _material
	var slices: Array = []
	var all: Array = Species.all()
	for kind in KINDS:
		var img: Image = Image.create(U_N, ROWS * V_N, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.5, 0.5, 0.5))
		for sp in all:
			var r: int = int(sp["row"])
			for vi in V_N:
				var v: float = float(vi) / float(V_N - 1)
				for ui in U_N:
					var u: float = float(ui) / float(U_N - 1)
					img.set_pixel(ui, r * V_N + vi, paint_colour(sp, kind, u, v))
		slices.append(img)
	var imgs: Array[Image] = []
	for s in slices:
		imgs.append(s)
	var tex := ImageTexture3D.new()
	tex.create(Image.FORMAT_RGBA8, U_N, ROWS * V_N, KINDS, false, imgs)
	var m := TetraMaterial4D.new()
	var cs: ShaderMaterial = m.get_cross_section_material_3d()
	# The shader before anything else: Material4D only fills an empty slot with its own.
	cs.shader = PlantShader
	m.albedo_color = Color.WHITE
	m.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_TEXTURE3D_CELL_UVW_ONLY
	m.albedo_texture_3d = tex
	cs.set_shader_parameter("albedo_texture", tex)
	cs.set_shader_parameter("kinds", float(KINDS))
	_material = m
	return m


## The shader material inside the shared material, where the room writes the wind and the camera.
static func shader() -> ShaderMaterial:
	return material().get_cross_section_material_3d()


## A texel's colour: `kind` the part, u along it, v out from its midrib.
static func paint_colour(sp: Dictionary, kind: int, u: float, v: float) -> Color:
	var c: Dictionary = sp.get("c", {})
	match kind:
		STEM:
			var s: Array = c.get("stem", [Color(0.25, 0.38, 0.18), Color(0.34, 0.48, 0.22)])
			return (s[0] as Color).lerp(s[1], u)
		LEAF:
			var l: Array = c.get("leaf", [Color(0.2, 0.34, 0.14), Color(0.3, 0.46, 0.2), Color(0.36, 0.5, 0.24)])
			var col: Color = (l[0] as Color).lerp(l[1], smoothstep(0.0, 0.85, u))
			# The midrib a lighter line, the edge a touch darker.
			col = col.lerp(l[2], (1.0 - smoothstep(0.06, 0.2, v)) * 0.7)
			return col.darkened(0.12 * smoothstep(0.75, 1.0, v))
		PETAL, PETAL2:
			var p: Array = c.get("petal2" if kind == PETAL2 and c.has("petal2") else "petal", [Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
			var col: Color = (p[0] as Color).lerp(p[1], smoothstep(0.0, 0.32, u)).lerp(p[2], smoothstep(0.32, 1.0, u))
			col = col.lerp(p[3], smoothstep(0.62, 1.0, v) * 0.75)
			if c.has("blotch"):
				var b: Array = c["blotch"]
				var bu: float = float(b[1])
				var bv: float = float(b[2])
				var m: float = (1.0 - smoothstep(bu * 0.6, bu, u)) * (1.0 - smoothstep(bv * 0.65, bv, v))
				col = col.lerp(b[0], m)
				# A thin yellow rim round a tulip's blotch, where the species has one (its base colour).
				col = col.lerp(p[0], (smoothstep(bu * 0.6, bu, u) * (1.0 - smoothstep(bu, bu * 1.35, u))) * (1.0 - smoothstep(bv, bv * 1.2, v)) * 0.8)
			if c.has("spots") and kind == PETAL:
				col = col.lerp((c["spots"] as Array)[0], _spot(c["spots"], u, v))
			if c.has("spots") and kind == PETAL2 and sp.get("key", "") == "lily":
				col = col.lerp((c["spots"] as Array)[0], _spot(c["spots"], u, v))
			# The sunflower's and the daisy's rays: faint lengthwise veins.
			if sp.get("form", "") == "band":
				col = col.darkened(0.06 * (0.5 + 0.5 * cos(v * 18.0)))
			return col
		CENTRE:
			var ce: Array = c.get("centre", [Color(0.95, 0.7, 0.1), Color(0.95, 0.78, 0.2)])
			var col: Color = (ce[0] as Color).lerp(ce[1], smoothstep(0.15, 1.0, u))
			# Rings of florets, opening outward.
			return col * (0.9 + 0.1 * cos(u * 46.0))
		STAMEN:
			var st: Array = c.get("stamen", [Color(0.85, 0.85, 0.6), Color(0.95, 0.8, 0.2)])
			return (st[0] as Color).lerp(st[1], smoothstep(0.62, 0.8, u))
		EXTRA:
			var e: Array = c.get("extra", [Color(0.9, 0.8, 0.3), Color(1.0, 0.9, 0.4)])
			return (e[0] as Color).lerp(e[1], smoothstep(0.2, 0.9, u))
		SPOT:
			if c.has("corona"):
				var co: Array = c["corona"]
				# Purple at the base, a white band, a thin purple one, blue tips (Passiflora caerulea).
				if u < 0.32:
					return co[0]
				if u < 0.55:
					return (co[0] as Color).lerp(co[1], smoothstep(0.32, 0.4, u))
				if u < 0.62:
					return (co[1] as Color).lerp(co[0], smoothstep(0.55, 0.58, u))
				return (co[0] as Color).lerp(co[2], smoothstep(0.62, 0.7, u))
			return c.get("spots", [Color(0.3, 0.05, 0.2)])[0]
	return Color.MAGENTA


## Spots: soft dots in a grid of `density` along, between from-u and to-u.
static func _spot(s: Array, u: float, v: float) -> float:
	var u0: float = float(s[1])
	var u1: float = float(s[2])
	if u < u0 or u > u1:
		return 0.0
	var dens: float = float(s[3])
	var gu: float = u * dens
	var gv: float = v * dens * 0.35
	var cell := Vector2(floor(gu), floor(gv))
	var jitter := Vector2(fmod(sin(cell.x * 12.9 + cell.y * 78.2) * 437.5, 1.0), fmod(sin(cell.x * 39.3 + cell.y * 11.1) * 912.7, 1.0))
	var d: float = Vector2(gu - cell.x - 0.5 - jitter.x * 0.3, gv - cell.y - 0.5 - jitter.y * 0.3).length()
	var edge: float = smoothstep(u0, u0 + 0.06, u) * (1.0 - smoothstep(u1 - 0.08, u1, u))
	return (1.0 - smoothstep(0.18, 0.3, d)) * edge * (0.6 + 0.4 * v)


# -- the builder -------------------------------------------------------------------------------------

class Builder:
	var sp: Dictionary
	var row: int = 0
	var parts: Array = []
	var rng := RandomNumberGenerator.new()
	var perches := PackedVector4Array()
	var bloom: Vector4 = Vector4.ZERO
	var top: Vector4 = Vector4.ZERO
	var _stem_pts := PackedVector4Array()

	func add(m: ArrayTetraMesh4D) -> void:
		if m != null and parts.size() < MAX_PARTS:
			parts.append(m)

	func tex(kind: int, u: float, v: float) -> Vector3:
		return Vector3((0.5 + clampf(u, 0.0, 1.0) * float(U_N - 1)) / float(U_N),
			(float(row * V_N) + 0.5 + clampf(v, 0.0, 1.0) * float(V_N - 1)) / float(ROWS * V_N),
			(float(kind) + 0.5) / float(KINDS))

	func jit(a: float) -> float:
		return 1.0 + rng.randf_range(-a, a)

	# -- the plant -----------------------------------------------------------------------------------

	func plant() -> void:
		var h: float = float(sp.get("height", 0.4)) * jit(0.08)
		var form: String = String(sp.get("form", "ring"))
		var face: float = float(sp.get("face", 0.0))
		var arch: float = float(sp.get("arch", 0.0))
		# The stem: up, leaning a little toward the front, bending more where the species faces you
		# or arches over.
		var lean0: float = rng.randf_range(0.0, 0.06)
		var bend: float = face * 0.45 + arch + rng.randf_range(-0.04, 0.08)
		var lean_dir: Vector4 = (FRONT * cos(rng.randf_range(-0.5, 0.5)) + SIDE * sin(rng.randf_range(-0.5, 0.5))).normalized()
		if String(sp.get("arch_dir", "")) == "side":
			lean_dir = (SIDE * (1.0 if rng.randf() < 0.5 else -1.0) + FRONT * rng.randf_range(0.1, 0.4)).normalized()
		# Four spans: the loft splits each to its width anyway (subdivide_long_spans), so more authored
		# sections only add cells (6 of them cost a 0.5 m stem 1,700; 4 cost 840).
		var n_stem: int = 4
		var a: Array = arc(Vector4.ZERO, UP, lean_dir, h, lean0, bend, n_stem)
		_stem_pts = a[0]
		top = _stem_pts[_stem_pts.size() - 1]
		var radii := PackedFloat32Array()
		var r: float = float(sp.get("stem_r", 0.003))
		for i in _stem_pts.size():
			var s: float = float(i) / float(_stem_pts.size() - 1)
			radii.append(r * lerpf(1.15, 0.8, s))
		tube(_stem_pts, radii, STEM, 4)
		# The bloom's axis: the stem's last direction, turned on toward the front by what is left of
		# the face.
		var th_end: float = lean0 + bend
		var axis: Vector4 = (UP * cos(th_end) + lean_dir * sin(th_end)).normalized()
		if face > 0.0:
			var th_face: float = maxf(face, th_end)
			axis = (UP * cos(th_face) + lean_dir * sin(th_face)).normalized()
		bloom = top
		match form:
			"ring":
				_ring_flower(top, axis)
			"band":
				_band_flower(top, axis)
			"ball":
				_ball_flower(top)
			"spike", "raceme":
				_bells(form == "raceme")
			"rose":
				_rose(top, axis)
			"passion":
				_passion(top, axis)
		for lf in sp.get("leaves", []):
			_leaf(lf)
		for lf in sp.get("compound", []):
			_compound(lf)
		for i in mini(int(sp.get("tendrils", 0)), 4):
			_tendril(0.4 + 0.3 * float(i))

	## The flower alone at the origin, facing up (a vine's bloom): ring and passion forms.
	func bloom_alone() -> void:
		_stem_pts = PackedVector4Array([Vector4.ZERO, UP * 0.01])
		top = Vector4.ZERO
		bloom = Vector4.ZERO
		match String(sp.get("form", "ring")):
			"passion":
				_passion(Vector4.ZERO, UP)
			"band":
				_band_flower(Vector4.ZERO, UP)
			"rose":
				_rose(Vector4.ZERO, UP)
			_:
				_ring_flower(Vector4.ZERO, UP)

	# -- shapes ------------------------------------------------------------------------------------

	## A curved midrib from `base` along `d` (unit), tipped `elev` toward `a` (unit, square to d) and
	## turning `curl` more by its end: [points, normals] (n + 1 of each), the normal the face's.
	func arc(base: Vector4, d: Vector4, a: Vector4, length: float, elev: float, curl: float, n: int) -> Array:
		var pts := PackedVector4Array()
		var nrm: Array = []
		var p: Vector4 = base
		var step: float = length / float(n)
		for i in n + 1:
			var s: float = float(i) / float(n)
			var th: float = elev + curl * s
			pts.append(p)
			nrm.append((a * cos(th) - d * sin(th)).normalized())
			var thm: float = elev + curl * (s + 0.5 / float(n))
			p += (d * cos(thm) + a * sin(thm)) * step
		return [pts, nrm]

	## Half widths at n + 1 points: rising from `base_w` of `hw` to all of it at `peak`, then to the tip
	## (`roundness` 1 a round end, 0 a point), with `teeth` lobes `depth` deep.
	func widths(n: int, hw: float, peak: float, roundness: float, base_w: float = 0.2, teeth: int = 0, depth: float = 0.0) -> PackedFloat32Array:
		var out := PackedFloat32Array()
		var pk: float = clampf(peak, 0.05, 0.95)
		for i in n + 1:
			var s: float = float(i) / float(n)
			var x: float
			if s <= pk:
				x = lerpf(base_w, 1.0, sin(s / pk * PI * 0.5))
			else:
				var t: float = (s - pk) / (1.0 - pk)
				x = lerpf(1.0 - t, pow(maxf(cos(t * PI * 0.5), 0.0), 0.5), roundness)
			if teeth > 0:
				x *= 1.0 - depth * 0.5 * (1.0 - cos(s * float(teeth) * TAU)) * (1.0 - 0.4 * s)
			out.append(maxf(x * hw, 0.0))
		return out

	## A thin blade along `pts`: half width `hw` at each, flat across `nrm` at each to `thick`, round
	## across the rest; stretched `wr` along `m_dir` (square to the blade) if given. Painted u along,
	## v out from the midrib.
	func blade(pts: PackedVector4Array, hw: PackedFloat32Array, nrm: Array, thick: float, kind: int, m_dir: Vector4 = Vector4.ZERO, wr: float = 1.0) -> void:
		if parts.size() >= MAX_PARTS or pts.size() < 2:
			return
		var sections: Array = []
		var floor_r: float = thick * 1.3
		var stretch: bool = absf(wr - 1.0) > 0.01 and m_dir.length() > 0.5
		for i in pts.size():
			var rr: float = maxf(hw[i], floor_r)
			var bs: Projection = Kit.flatten4(nrm[i], clampf(thick / rr, 0.03, 1.0))
			if stretch:
				bs = Kit.flatten4(m_dir, wr) * bs
			sections.append({"center": pts[i], "radius": rr, "v_scale": 1.0, "w_scale": 1.0, "basis": bs})
		var m: ArrayTetraMesh4D = loft(sections, 2, 4)
		if m == null:
			return
		paint_along(m, pts, hw, kind)
		add(m)

	## The loft builder's build() without its span splitting (subdivide_long_spans): that splits a span
	## longer than three of its widths into up to 12, against slivers, which only break the editor's
	## click-picking (loft_builder_4d.gd's note); for a flower's thin stems and petal bases it was most of
	## the cells (a 0.5 m stem: 840 of them, 72 here). The same profile, frames, prisms, caps and winding.
	func loft(sections: Array, rings: int, sides: int) -> ArrayTetraMesh4D:
		if sections.size() < 2:
			return null
		var profile: Dictionary = Loft.build_profile_surface(rings, sides)
		var directions: PackedVector3Array = profile["directions"]
		var triangles: PackedInt32Array = profile["triangles"]
		var frames: Array = Loft.build_frames(sections, true)
		var positions := PackedVector4Array()
		var starts := PackedInt32Array()
		for i in sections.size():
			starts.append(positions.size())
			var s: Dictionary = sections[i]
			var c: Vector4 = s["center"]
			var r: float = s["radius"]
			var fr: Array = frames[i]
			var b: Projection = s.get("basis", Projection.IDENTITY)
			for dir in directions:
				positions.append(c + b * ((fr[0] as Vector4) * (dir.x * r) + (fr[1] as Vector4) * (dir.y * r) + (fr[2] as Vector4) * (dir.z * r)))
		var cells := PackedInt32Array()
		var bottom: int = positions.size()
		positions.append((sections[0]["center"] as Vector4) + (frames[0][3] as Vector4) * (-0.55 * float(sections[0]["radius"])))
		Loft._append_cone(cells, starts[0], bottom, triangles, true)
		for i in sections.size() - 1:
			Loft._append_prisms(cells, starts[i], starts[i + 1], triangles)
		var last: int = sections.size() - 1
		var top_i: int = positions.size()
		positions.append((sections[last]["center"] as Vector4) + (frames[last][3] as Vector4) * (0.55 * float(sections[last]["radius"])))
		Loft._append_cone(cells, starts[last], top_i, triangles, false)
		Loft.make_winding_consistent(cells, positions, false)
		var m := ArrayTetraMesh4D.new()
		m.set_vertex_positions(positions)
		m.set_simplex_cell_vertex_indices(cells)
		return m

	## A round tube along `pts`, `radii` at each.
	func tube(pts: PackedVector4Array, radii: PackedFloat32Array, kind: int, sides: int = 4) -> void:
		if parts.size() >= MAX_PARTS or pts.size() < 2:
			return
		var sections: Array = []
		for i in pts.size():
			sections.append({"center": pts[i], "radius": maxf(radii[i], 0.0003), "v_scale": 1.0, "w_scale": 1.0})
		var m: ArrayTetraMesh4D = loft(sections, 2, sides)
		if m == null:
			return
		paint_along(m, pts, radii, kind)
		add(m)

	## A spindle from `a` to `b`: two cones on a tetrahedron `r` across at `at` of the way (8 cells),
	## shaped by `shape` (a basis on the tetrahedron, e.g. flattened). For the hundreds of florets,
	## filaments and seeds, where a loft's tessellation would be thousands of cells.
	func spindle(a: Vector4, b: Vector4, r: float, at: float, kind: int, shape: Projection = Projection.IDENTITY, v: float = 0.5, u0: float = 0.0, u1: float = 1.0) -> void:
		if parts.size() >= MAX_PARTS:
			return
		var ax: Vector4 = b - a
		if ax.length() < 1e-6:
			return
		var e: Array = square_to(ax.normalized())
		var mid: Vector4 = a.lerp(b, at)
		var k: float = r / sqrt(3.0)
		var corners: Array = [Vector3(1, 1, 1), Vector3(1, -1, -1), Vector3(-1, 1, -1), Vector3(-1, -1, 1)]
		var pos := PackedVector4Array([a, b])
		for c3 in corners:
			var c: Vector3 = c3
			pos.append(mid + shape * ((e[0] as Vector4) * c.x * k + (e[1] as Vector4) * c.y * k + (e[2] as Vector4) * c.z * k))
		# The tetrahedron's four faces, each coned to both ends.
		var faces: Array = [[2, 3, 4], [2, 5, 3], [2, 4, 5], [3, 5, 4]]
		var cells := PackedInt32Array()
		for f in faces:
			cells.append_array([0, f[0], f[1], f[2]])
			cells.append_array([1, f[0], f[2], f[1]])
		Loft.make_winding_consistent(cells, pos, false)
		var m := ArrayTetraMesh4D.new()
		m.set_vertex_positions(pos)
		m.set_simplex_cell_vertex_indices(cells)
		var t := PackedVector3Array([tex(kind, u0, v), tex(kind, u1, v)])
		for i in 4:
			t.append(tex(kind, lerpf(u0, u1, at), v))
		m.set_texture_map_values(t)
		m.set_simplex_cell_texture_map_indices(cells)
		add(m)

	## A dome on `c` facing `a`: `r` across, `h` high, round across all three directions of its face (a
	## 3D dome in every cut), `under` of h below. Painted u from its middle out, v up it.
	func dome(c: Vector4, a: Vector4, r: float, h: float, kind: int, under: float = 0.35) -> void:
		if parts.size() >= MAX_PARTS:
			return
		var sections: Array = []
		# A small dome (a daisy's disc, a receptacle) coarser than the sunflower's.
		var big: bool = r > 0.02
		var k: int = 6 if big else 4
		for i in k + 1:
			var t: float = float(i) / float(k)
			var y: float = lerpf(-h * under, h, t)
			var rad: float
			if t < 0.3:
				rad = r * lerpf(0.62, 1.0, sin(t / 0.3 * PI * 0.5))
			else:
				var q: float = (t - 0.3) / 0.7
				rad = r * sqrt(maxf(1.0 - q * q, 0.0))
			sections.append({"center": c + a * y, "radius": maxf(rad, r * 0.08), "v_scale": 1.0, "w_scale": 1.0})
		var m: ArrayTetraMesh4D = loft(sections, 4 if big else 2, 10 if big else 5)
		if m == null:
			return
		var pos: PackedVector4Array = m.get_vertex_positions()
		var tx := PackedVector3Array()
		tx.resize(pos.size())
		for i in pos.size():
			var d: Vector4 = pos[i] - c
			var along: float = d.dot(a)
			tx[i] = tex(kind, (d - a * along).length() / r, clampf((along + h * under) / (h * (1.0 + under)), 0.0, 1.0))
		m.set_texture_map_values(tx)
		m.set_simplex_cell_texture_map_indices(m.get_simplex_cell_vertex_indices())
		add(m)

	## A solid 4D ball on `c`, `r` across: round in all four directions, so a 3D ball in every cut. Painted
	## `u` along the kind's ramp, v out from its middle.
	func ball(c: Vector4, r: float, kind: int, u: float) -> void:
		if parts.size() >= MAX_PARTS:
			return
		var sections: Array = []
		for i in 9:
			var y: float = lerpf(-0.96, 0.96, float(i) / 8.0)
			sections.append({"center": c + UP * (y * r), "radius": r * sqrt(maxf(1.0 - y * y, 0.02)), "v_scale": 1.0, "w_scale": 1.0})
		var m: ArrayTetraMesh4D = loft(sections, 4, 12)
		if m == null:
			return
		var pos: PackedVector4Array = m.get_vertex_positions()
		var tx := PackedVector3Array()
		tx.resize(pos.size())
		for i in pos.size():
			tx[i] = tex(kind, u, clampf((pos[i] - c).length() / r, 0.0, 1.0))
		m.set_texture_map_values(tx)
		m.set_simplex_cell_texture_map_indices(m.get_simplex_cell_vertex_indices())
		add(m)

	## Paints u along the polyline `pts` (by length) and v out from it over the half width there.
	func paint_along(m: ArrayTetraMesh4D, pts: PackedVector4Array, hw: PackedFloat32Array, kind: int) -> void:
		var cum := PackedFloat32Array([0.0])
		for i in range(1, pts.size()):
			cum.append(cum[i - 1] + pts[i].distance_to(pts[i - 1]))
		var total: float = maxf(cum[cum.size() - 1], 1e-6)
		var pos: PackedVector4Array = m.get_vertex_positions()
		var tx := PackedVector3Array()
		tx.resize(pos.size())
		for vi in pos.size():
			var q: Vector4 = pos[vi]
			var best_d: float = INF
			var best_s: float = 0.0
			var best_w: float = hw[0]
			for i in pts.size() - 1:
				var p0: Vector4 = pts[i]
				var ab: Vector4 = pts[i + 1] - p0
				var l2: float = ab.length_squared()
				var t: float = clampf((q - p0).dot(ab) / l2, 0.0, 1.0) if l2 > 1e-12 else 0.0
				var dd: float = q.distance_to(p0 + ab * t)
				if dd < best_d:
					best_d = dd
					best_s = (cum[i] + t * sqrt(l2)) / total
					best_w = lerpf(hw[i], hw[i + 1], t)
			tx[vi] = tex(kind, best_s, best_d / maxf(best_w, 1e-5))
		m.set_texture_map_values(tx)
		m.set_simplex_cell_texture_map_indices(m.get_simplex_cell_vertex_indices())

	## Three unit directions square to `a` and to each other (from x, z, W, y in that order, so the
	## first two lie in the slice when they can and the third is the one through W).
	func square_to(a: Vector4) -> Array:
		var out: Array = []
		for cand in [SIDE, FRONT, ANA, UP]:
			var v: Vector4 = cand - a * cand.dot(a)
			for e in out:
				v -= (e as Vector4) * v.dot(e)
			if v.length() > 0.2:
				out.append(v.normalized())
			if out.size() == 3:
				break
		return out

	## A petal from `c`, out along the radial direction `d` of a bloom facing `a`, by the species' petal
	## data `p`; `m_dir` the direction its W stretch runs (square to d and a), `kind` its colour.
	func petal(c: Vector4, d: Vector4, a: Vector4, p: Dictionary, kind: int, m_dir: Vector4 = Vector4.ZERO, scale: float = 1.0) -> void:
		# Sections along it: 4 (a ray of a band, small and many, 3).
		var n: int = clampi(int(p.get("n_sec", 4)), 2, 8)
		var L: float = float(p.get("L", 0.04)) * scale * jit(0.08)
		var elev: float = float(p.get("elev", 0.3)) + rng.randf_range(-0.08, 0.08)
		var curl: float = float(p.get("curl", 0.0)) + rng.randf_range(-0.1, 0.1)
		var base: Vector4 = c + d * float(p.get("r0", 0.003)) + a * float(p.get("lift", 0.0))
		var ar: Array = arc(base, d, a, L, elev, curl, n)
		var pts: PackedVector4Array = ar[0]
		var nrm: Array = ar[1]
		var crumple: float = float(p.get("crumple", 0.0))
		if crumple > 0.0:
			# A poppy's crumpled silk: the midrib waves a little across its face.
			for i in range(1, pts.size()):
				pts[i] += (nrm[i] as Vector4) * (sin(float(i) * 2.3 + rng.randf() * 3.0) * crumple * L * 0.12)
		var hw: PackedFloat32Array = widths(n, float(p.get("hw", 0.01)) * scale * jit(0.06), float(p.get("peak", 0.5)), float(p.get("round", 0.8)))
		blade(pts, hw, nrm, float(p.get("thick", 0.0014)), kind, m_dir, float(p.get("wr", 1.0)))

	## A ring of n petals round `a`, starting at `phase`, in the slice's two directions of the bloom.
	func ring_dirs(a: Vector4, n: int, phase: float) -> Array:
		var e: Array = square_to(a)
		var out: Array = []
		for k in mini(n, MAX_COUNT):
			var ph: float = phase + TAU * float(k) / float(n)
			out.append((e[0] as Vector4) * cos(ph) + (e[1] as Vector4) * sin(ph))
		return out

	## n directions over a band either side of the slice (half angle `band` radians), round `a`:
	## Fibonacci on the sphere of directions square to a, the golden angle between neighbours.
	## Returns [direction, its W-stretch direction] pairs.
	## `mixed`: the W heights in a second low-discrepancy order instead of top to bottom, so a spiral
	## built from first to last (the rose, inner to outer) is spread evenly through W at every stage.
	func band_dirs(a: Vector4, n: int, band: float, phase: float = 0.0, mixed: bool = false) -> Array:
		var e: Array = square_to(a)
		var out: Array = []
		var zmax: float = sin(clampf(band, 0.0, PI * 0.5))
		var cnt: int = mini(n, MAX_COUNT)
		for k in cnt:
			var z: float = zmax * (1.0 - 2.0 * (float(k) + 0.5) / float(cnt))
			if mixed:
				z = zmax * (2.0 * fmod(float(k) * 0.7548776662 + 0.5, 1.0) - 1.0)
			var ph: float = phase + float(k) * GOLDEN
			var rr: float = sqrt(maxf(1.0 - z * z, 0.0))
			var d: Vector4 = (e[0] as Vector4) * (rr * cos(ph)) + (e[1] as Vector4) * (rr * sin(ph)) + (e[2] as Vector4) * z
			var m: Vector4 = (e[0] as Vector4) * (-z * cos(ph)) + (e[1] as Vector4) * (-z * sin(ph)) + (e[2] as Vector4) * rr
			out.append([d, m])
		return out

	## n directions over the whole 3-sphere: the super-Fibonacci spiral (Alexa, CVPR 2022).
	func ball_dirs(n: int) -> Array:
		var out: Array = []
		var phi: float = sqrt(2.0)
		var psi: float = 1.533751168755204288118041
		var cnt: int = mini(n, MAX_COUNT)
		for i in cnt:
			var s: float = float(i) + 0.5
			var r: float = sqrt(s / float(cnt))
			var R: float = sqrt(1.0 - s / float(cnt))
			var al: float = TAU * s / phi
			var be: float = TAU * s / psi
			out.append(Vector4(r * sin(al), r * cos(al), R * sin(be), R * cos(be)))
		return out

	## A point on the stem `f` of the way up (by its points).
	func stem_at(f: float) -> Vector4:
		var n: int = _stem_pts.size() - 1
		var x: float = clampf(f, 0.0, 1.0) * float(n)
		var i: int = mini(int(floor(x)), n - 1)
		return _stem_pts[i].lerp(_stem_pts[i + 1], x - float(i))

	## The stem's direction `f` of the way up.
	func stem_dir(f: float) -> Vector4:
		var n: int = _stem_pts.size() - 1
		var i: int = mini(int(floor(clampf(f, 0.0, 1.0) * float(n))), n - 1)
		return (_stem_pts[i + 1] - _stem_pts[i]).normalized()

	# -- forms -------------------------------------------------------------------------------------

	## The ring + W pair: tepals or petals in one or two rings, one more each way through W; then
	## stamens, a pistil or a capsule.
	func _ring_flower(c: Vector4, a: Vector4) -> void:
		var e: Array = square_to(a)
		var w_pair: bool = bool(sp.get("w_pair", false))
		for key in ["petal", "petal2"]:
			if not sp.has(key):
				continue
			var p: Dictionary = sp[key]
			var kind: int = PETAL if key == "petal" else PETAL2
			for d in ring_dirs(a, int(p.get("n", 3)), float(p.get("phase", 0.0))):
				petal(c, d, a, p, kind)
			if w_pair:
				# Ana and kata: the outer ring's pair straight through W, the inner one's a little smaller.
				for sgn in [1.0, -1.0]:
					petal(c, (e[2] as Vector4) * sgn, a, p, kind, Vector4.ZERO, 1.0 if key == "petal" else 0.94)
		if sp.has("capsule"):
			var cap: Dictionary = sp["capsule"]
			var cr: float = float(cap.get("r", 0.007))
			var ch: float = float(cap.get("h", 0.012))
			dome(c + a * (ch * 0.35), a, cr, ch * 0.7, CENTRE, 0.6)
			# The stigma disc: a flat star of rays on top (the capsule's crown), dark.
			for d in ring_dirs(a, int(cap.get("star", 8)), 0.0):
				var p0: Vector4 = c + a * (ch * 1.02)
				spindle(p0, p0 + (d as Vector4) * cr * 1.05 + a * (ch * 0.05), cr * 0.35, 0.3, EXTRA, Kit.flatten4(a, 0.3))
			for sgn in [1.0, -1.0]:
				var p0: Vector4 = c + a * (ch * 1.02)
				spindle(p0, p0 + (e[2] as Vector4) * (sgn * cr * 1.05), cr * 0.35, 0.3, EXTRA, Kit.flatten4(a, 0.3))
		if sp.has("stamens"):
			_stamens(c, a, sp["stamens"])
		if sp.has("pistil"):
			var pi: Dictionary = sp["pistil"]
			var L: float = float(pi.get("L", 0.015))
			var pts := PackedVector4Array([c, c + a * (L * 0.5), c + a * L])
			var rr: float = float(pi.get("r", 0.002))
			tube(pts, PackedFloat32Array([rr * 1.3, rr, rr * 0.9]), EXTRA, 4)
			var knob: float = float(pi.get("knob", 0.0))
			if knob > 0.0:
				spindle(c + a * (L * 0.96), c + a * (L + knob * 1.2), knob, 0.4, EXTRA)
		if sp.has("beard"):
			# The beard: a fuzzy strip along each fall's base, in the slice and through W.
			var bd: Dictionary = sp["beard"]
			var p: Dictionary = sp["petal"]
			var dirs: Array = ring_dirs(a, int(p.get("n", 3)), float(p.get("phase", 0.0)))
			if w_pair:
				dirs.append(e[2])
				dirs.append(-(e[2] as Vector4))
			for d in dirs:
				var ar: Array = arc(c + (d as Vector4) * float(p.get("r0", 0.004)), d, a, float(p.get("L", 0.07)), float(p.get("elev", 0.3)), float(p.get("curl", 0.0)), 5)
				var pts: PackedVector4Array = ar[0]
				var f0: float = float(bd.get("from", 0.1))
				var f1: float = float(bd.get("to", 0.45))
				var lift: Vector4 = ar[1][1] * 0.0018
				var bpts := PackedVector4Array([pts[0].lerp(pts[5], f0) + lift, pts[0].lerp(pts[5], (f0 + f1) * 0.5) + lift, pts[0].lerp(pts[5], f1) + lift])
				var br: float = float(bd.get("r", 0.002))
				tube(bpts, PackedFloat32Array([br * 0.8, br, br * 0.6]), EXTRA, 4)
		perches.append(c + a * 0.01)

	## Stamens round `a`: a ring at their elevation (or a band of many, the poppy's), and a W pair.
	func _stamens(c: Vector4, a: Vector4, st: Dictionary) -> void:
		var n: int = int(st.get("n", 6))
		var L: float = float(st.get("L", 0.015))
		var elev: float = float(st.get("elev", 1.0))
		var anther: float = float(st.get("anther", 0.002))
		var flat: bool = bool(st.get("flat", false))
		var base: Vector4 = c + (a * float(sp.get("column", {}).get("h", 0.0)) if bool(st.get("at_top", false)) else Vector4.ZERO)
		var dirs: Array = []
		if st.has("band"):
			for pair in band_dirs(a, n, float(st["band"]), 0.3):
				dirs.append(pair[0])
		else:
			dirs = ring_dirs(a, n, PI / float(maxi(n, 1)))
			var e: Array = square_to(a)
			dirs.append(e[2])
			dirs.append(-(e[2] as Vector4))
		for d in dirs:
			var dd: Vector4 = d
			var tip_dir: Vector4 = (dd * cos(elev) + a * sin(elev)).normalized()
			var tip: Vector4 = base + dd * 0.002 + tip_dir * L
			spindle(base + dd * 0.001, tip, maxf(anther * 0.22, 0.00045), 0.5, STAMEN, Projection.IDENTITY, 0.2)
			# The anther: a little spindle across the tip (flat ones lie across it, the lily's).
			var across: Vector4 = (a - tip_dir * a.dot(tip_dir)).normalized() if flat else tip_dir
			spindle(tip - across * anther * 0.6, tip + across * anther * 0.6, anther * 0.55, 0.5, STAMEN, Projection.IDENTITY, 0.9)

	## The band: rays over a band of directions round a domed disc (daisy, sunflower); the sunflower's
	## green bracts behind.
	func _band_flower(c: Vector4, a: Vector4) -> void:
		var disc: Dictionary = sp.get("disc", {})
		var dr: float = float(disc.get("r", 0.008))
		var dh: float = float(disc.get("h", 0.004))
		for key in ["rays", "rays2"]:
			if not sp.has(key):
				continue
			var p: Dictionary = sp[key]
			var kind: int = PETAL if String(p.get("kind", "petal")) == "petal" else LEAF
			for pair in band_dirs(a, int(p.get("n", 30)), float(p.get("band", 0.5)), rng.randf() * TAU):
				var d: Vector4 = pair[0]
				# Rays leave the disc's rim, a touch below its top; bracts sit under the rays.
				var pp: Dictionary = p.duplicate()
				pp["n_sec"] = int(p.get("n_sec", 3))
				pp["r0"] = float(p.get("r0", dr)) * 0.92
				pp["lift"] = -dh * (0.6 if kind == PETAL else 1.2)
				petal(c, d, a, pp, kind, pair[1])
		dome(c, a, dr, dh, CENTRE, 0.8)
		perches.append(c + a * dh)

	## The ball: florets or seeds on stalks along every direction of the 3-sphere.
	func _ball_flower(c: Vector4) -> void:
		var b: Dictionary = sp.get("ball", {})
		var R: float = float(b.get("R", 0.05))
		var f: float = float(b.get("floret", 0.005))
		var ped: float = float(b.get("pedicel", 0.0006))
		var kind: int = PETAL if String(b.get("kind", "petal")) == "petal" else EXTRA
		var pappus: bool = bool(b.get("pappus", false))
		var centre: Vector4 = c + UP * (R * 0.92)
		bloom = centre
		for q in ball_dirs(int(b.get("n", 200))):
			var d: Vector4 = q
			var rr: float = R * jit(0.05)
			if pappus:
				# A seed: a beak out to the pappus, a flat white parasol facing out.
				spindle(centre + d * (R * 0.18), centre + d * (rr - f * 0.3), maxf(ped * 2.5, 0.0009), 0.12, EXTRA, Projection.IDENTITY, 0.2)
				spindle(centre + d * (rr - f * 0.45), centre + d * (rr + f * 0.15), f, 0.7, EXTRA, Projection.IDENTITY, 1.0)
			else:
				spindle(centre + d * (R * 0.12), centre + d * (rr - f), maxf(ped * 2.5, 0.0012), 0.15, STEM, Projection.IDENTITY, 0.5)
				# A starry floret: a spindle with a sharp outer point.
				spindle(centre + d * (rr - f * 1.2), centre + d * (rr + f * 0.5), f, 0.45, kind, Projection.IDENTITY, 0.5)
		# The receptacle the stalks leave from.
		dome(centre - UP * (R * 0.06), UP, R * 0.16, R * 0.12, STEM, 0.8)
		# THE CORE: the florets point every way in four directions, so any one slice cuts only those near
		# it (the gallery, 10 Oct: a sparse cloud of dots, not a ball). A solid 4D ball under them, the
		# florets' own colour a shade darker (the dandelion's the white of its pappus), is a ball in every
		# cut, as the real head is in ours; the florets stand proud of it.
		ball(centre, R * (0.86 if pappus else 0.8), kind, 0.9 if pappus else 0.18)
		perches.append(centre + UP * R)

	## Bells on one side of the stem's upper part (foxglove), or nodding from an arching stem (bluebell).
	func _bells(nodding: bool) -> void:
		var b: Dictionary = sp.get("bells", {})
		var n: int = mini(int(b.get("n", 10)), 60)
		var f0: float = float(b.get("from", 0.5))
		var f1: float = float(b.get("to", 0.95))
		var L: float = float(b.get("L", 0.03))
		var R: float = float(b.get("R", 0.008))
		var droop: float = float(b.get("droop", 0.9))
		var spread: float = float(b.get("spread", 0.5))
		var w_side: float = float(b.get("w_side", 0.3))
		var buds: int = int(b.get("bud", 2))
		var flare: bool = bool(b.get("flare", false))
		for k in n:
			var f: float = lerpf(f0, f1, float(k) / float(maxi(n - 1, 1)))
			var p0: Vector4 = stem_at(f)
			var sd: Vector4 = stem_dir(f)
			# One side: toward the front, fanning a little across and through W.
			var yaw: float = rng.randf_range(-spread, spread)
			var wt: float = rng.randf_range(-w_side, w_side)
			var toward: Vector4 = FRONT
			if String(sp.get("arch_dir", "")) == "side":
				toward = Vector4(_stem_pts[_stem_pts.size() - 1].x, 0.0, _stem_pts[_stem_pts.size() - 1].z, 0.0).normalized()
			var across: Vector4 = Vector4(toward.z, 0.0, -toward.x, 0.0)
			var side: Vector4 = (toward * cos(yaw) + across * sin(yaw)) * cos(wt) + ANA * sin(wt)
			side = (side - sd * side.dot(sd)).normalized()
			var size: float = 1.0
			var bud: bool = k >= n - buds
			if bud:
				size = lerpf(0.75, 0.4, float(k - (n - buds)) / float(maxi(buds, 1)))
			var ped_len: float = (0.012 if not nodding else 0.008) * jit(0.2)
			var attach: Vector4 = p0 + side * ped_len + sd * (ped_len * 0.4)
			tube(PackedVector4Array([p0, p0.lerp(attach, 0.5) + sd * 0.002, attach]), PackedFloat32Array([0.0009, 0.0008, 0.0008]), STEM, 4)
			var dr: float = droop * (0.7 if bud else 1.0) + rng.randf_range(-0.1, 0.1)
			var axis: Vector4 = (side * cos(dr) - UP * sin(dr)).normalized()
			var pts := PackedVector4Array()
			var radii := PackedFloat32Array()
			var prof: Array = [[0.0, 0.3], [0.18, 0.5], [0.5, 0.74], [0.82, 0.92], [1.0, 1.15 if flare else 1.0]]
			if bud:
				prof = [[0.0, 0.35], [0.3, 0.7], [0.7, 0.75], [1.0, 0.35]]
			for pr in prof:
				pts.append(attach + axis * (float(pr[0]) * L * size))
				radii.append(float(pr[1]) * R * size)
			if parts.size() >= MAX_PARTS:
				return
			var sections: Array = []
			for i in pts.size():
				sections.append({"center": pts[i], "radius": radii[i], "v_scale": 1.0, "w_scale": 1.0})
			var m: ArrayTetraMesh4D = loft(sections, 2, 4)
			if m != null:
				# (A tube's every point is at its edge: v from three times its radius, so the bell takes its
				# petal colour, not the pale edge's.)
				var wide := PackedFloat32Array()
				for rr in radii:
					wide.append(rr * 3.0)
				paint_along(m, pts, wide, PETAL)
				if bud:
					# Buds stay greener: their colour from low on the petal ramp.
					var tx: PackedVector3Array = m.get_texture_map_values()
					for i in tx.size():
						var v3: Vector3 = tx[i]
						v3.x = (0.5 + 0.05 * float(U_N - 1)) / float(U_N)
						tx[i] = v3
					m.set_texture_map_values(tx)
				add(m)
			if not bud and k % 3 == 0:
				perches.append(attach + axis * (L * 0.5) + side * R)
		bloom = stem_at((f0 + f1) * 0.5)

	## The rose: petals spiralling by the golden angle over a band of directions, the inner ones
	## upright and cupped, the outer ones open and turning back; green sepals under.
	func _rose(c: Vector4, a: Vector4) -> void:
		var r: Dictionary = sp.get("rose", {})
		var n: int = mini(int(r.get("n", 30)), 80)
		var dirs: Array = band_dirs(a, n, float(r.get("band", 0.6)), rng.randf() * TAU, true)
		# The band's directions in the golden-angle order the spiral grows: inner (first) to outer.
		for k in n:
			var t: float = float(k) / float(maxi(n - 1, 1))
			var p := {
				"L": lerpf(float(r.get("L0", 0.02)), float(r.get("L1", 0.04)), t),
				"hw": lerpf(float(r.get("hw0", 0.012)), float(r.get("hw1", 0.024)), t),
				"peak": 0.68, "round": 1.0,
				"elev": lerpf(float(r.get("elev0", 1.4)), float(r.get("elev1", 0.3)), sqrt(t)),
				"curl": lerpf(float(r.get("curl0", 0.6)), float(r.get("curl1", -0.5)), t),
				"r0": float(r.get("r0", 0.003)) + t * 0.004, "thick": float(r.get("thick", 0.0016)), "wr": float(r.get("wr", 1.0)), "n_sec": 3,
				"lift": (1.0 - t) * 0.006,
			}
			petal(c, dirs[k][0], a, p, PETAL, dirs[k][1])
		var se: Dictionary = sp.get("sepals", {})
		for d in ring_dirs(a, int(se.get("n", 5)), 0.3):
			var p := {"L": float(se.get("L", 0.02)), "hw": float(se.get("hw", 0.004)), "peak": 0.3, "round": 0.0, "elev": float(se.get("elev", -0.4)), "curl": float(se.get("curl", -0.5)), "r0": 0.004, "thick": 0.0012, "lift": -0.004}
			petal(c, d, a, p, LEAF)
		dome(c - a * 0.004, a, 0.006, 0.007, STEM, 0.6)
		perches.append(c + a * 0.03)

	## The passionflower: ten tepals and a W pair of each ring, the banded corona over a band, a
	## column carrying five stamens hanging out and three stigmas up.
	func _passion(c: Vector4, a: Vector4) -> void:
		_ring_flower_petals_only(c, a)
		var co: Dictionary = sp.get("corona", {})
		for pair in band_dirs(a, int(co.get("n", 60)), float(co.get("band", 0.5)), 0.1):
			var d: Vector4 = pair[0]
			var L: float = float(co.get("L", 0.025)) * jit(0.08)
			var elev: float = float(co.get("elev", 0.2))
			var curl: float = float(co.get("curl", -0.3))
			var ar: Array = arc(c + d * float(co.get("r0", 0.005)) + a * 0.001, d, a, L, elev, curl, 3)
			var pts: PackedVector4Array = ar[0]
			# A filament: two spindles end to end along its curve (thin, wide through W).
			var shape: Projection = Kit.flatten4(pair[1], float(co.get("wr", 2.0)))
			var hw: float = float(co.get("hw", 0.001))
			# Its bands run on from one half to the next (u 0 to 0.66, then 0.66 to 1).
			spindle(pts[0], pts[2], hw, 0.5, SPOT, shape, 0.5, 0.0, 0.66)
			spindle(pts[2], pts[3], hw * 0.8, 0.3, SPOT, shape, 0.5, 0.66, 1.0)
		var col: Dictionary = sp.get("column", {})
		var ch: float = float(col.get("h", 0.014))
		var cr: float = float(col.get("r", 0.002))
		tube(PackedVector4Array([c, c + a * (ch * 0.5), c + a * ch]), PackedFloat32Array([cr * 1.2, cr, cr * 1.1]), CENTRE, 4)
		dome(c + a * ch, a, cr * 1.6, cr * 1.2, CENTRE, 0.4)
		_stamens(c, a, sp.get("stamens", {}))
		var sg: Dictionary = sp.get("stigmas", {})
		var top_c: Vector4 = c + a * (ch + cr)
		var dirs: Array = ring_dirs(a, int(sg.get("n", 3)), PI / 6.0)
		var e: Array = square_to(a)
		dirs.append(e[2])
		for d in dirs:
			var el: float = float(sg.get("elev", 0.7))
			var tip: Vector4 = top_c + ((d as Vector4) * cos(el) + a * sin(el)) * float(sg.get("L", 0.011))
			spindle(top_c, tip, 0.0012, 0.5, EXTRA, Projection.IDENTITY, 0.3)
			spindle(tip - a * 0.001, tip + a * float(sg.get("knob", 0.0025)), float(sg.get("knob", 0.0025)), 0.5, EXTRA, Projection.IDENTITY, 0.9)
		perches.append(c + a * 0.02)

	func _ring_flower_petals_only(c: Vector4, a: Vector4) -> void:
		var e: Array = square_to(a)
		for key in ["petal", "petal2"]:
			if not sp.has(key):
				continue
			var p: Dictionary = sp[key]
			var kind: int = PETAL if key == "petal" else PETAL2
			for d in ring_dirs(a, int(p.get("n", 5)), float(p.get("phase", 0.0))):
				petal(c, d, a, p, kind)
			if bool(sp.get("w_pair", false)):
				for sgn in [1.0, -1.0]:
					petal(c, (e[2] as Vector4) * sgn, a, p, kind)

	# -- leaves ------------------------------------------------------------------------------------

	## A leaf from the stem `at` of the way up, out along the slice angle `dir` (tipped `w` into W),
	## rising `elev` and curling `curl`; toothed, lobed (palmate) or on a stalk where the data says.
	func _leaf(lf: Dictionary) -> void:
		var at: float = float(lf.get("at", 0.0))
		var base: Vector4 = stem_at(at)
		var ph: float = float(lf.get("dir", 0.0)) + rng.randf_range(-0.15, 0.15)
		var wt: float = float(lf.get("w", 0.0))
		var d: Vector4 = (SIDE * cos(ph) + FRONT * sin(ph)) * cos(wt) + ANA * sin(wt)
		var L: float = float(lf.get("L", 0.1)) * jit(0.1)
		var hw: float = float(lf.get("hw", 0.01)) * jit(0.08)
		var elev: float = float(lf.get("elev", 0.6)) + rng.randf_range(-0.08, 0.08)
		var curl: float = float(lf.get("curl", -0.6)) + rng.randf_range(-0.12, 0.12)
		var stalk: float = float(lf.get("stalk", 0.0))
		if stalk > 0.0:
			var sa: Array = arc(base, d, UP, stalk, elev, curl * 0.3, 3)
			var spts: PackedVector4Array = sa[0]
			tube(spts, PackedFloat32Array([0.0016, 0.0014, 0.0013, 0.0012]), STEM, 4)
			base = spts[spts.size() - 1]
			elev = elev + curl * 0.3
		var lobes: int = int(lf.get("palmate", 0))
		var teeth: int = int(lf.get("teeth", 0))
		var n: int = maxi(6, teeth * 3) if teeth > 0 else 6
		# Swords stand edge-on (the iris's fan): flat across the slice's sideways direction.
		var edge_on: bool = bool(lf.get("pointed", false)) and elev > 1.1
		var m_dir: Vector4 = Vector4.ZERO
		if lobes > 1:
			# Palmate: lobes fanned in the leaf's own plane, the middle one longest.
			var e: Array = square_to(UP)
			var side: Vector4 = (d - UP * d.y)
			side = Vector4(side.z, 0.0, -side.x, side.w).normalized() if Vector2(side.x, side.z).length() > 0.1 else e[0]
			for k in mini(lobes, 7):
				var off: float = (float(k) - float(lobes - 1) * 0.5) * 0.42
				var dd: Vector4 = (d * cos(off) + side * sin(off)).normalized()
				var ll: float = L * (1.0 - absf(off) * 0.35)
				var ar: Array = arc(base, dd, UP, ll, elev, curl, 5)
				blade(ar[0], widths(5, hw, 0.45, 0.3), ar[1], 0.0011, LEAF)
			return
		var ar: Array = arc(base, d, UP, L, elev, curl, n)
		var nrm: Array = ar[1]
		if edge_on:
			var t: Vector4 = Vector4(d.z, 0.0, -d.x, 0.0)
			t = t.normalized() if t.length() > 0.1 else FRONT
			nrm = []
			for i in (ar[0] as PackedVector4Array).size():
				nrm.append(t)
		var round_end: float = 0.0 if bool(lf.get("pointed", false)) else 0.55
		blade(ar[0], widths(n, hw, float(lf.get("peak", 0.4)), round_end, 0.15, teeth, float(lf.get("depth", 0.0))), nrm, 0.0012, LEAF, m_dir)

	## A rose's compound leaf: a stalk with two pairs of leaflets and one at the end.
	func _compound(lf: Dictionary) -> void:
		var base: Vector4 = stem_at(float(lf.get("at", 0.4)))
		var ph: float = float(lf.get("dir", 0.0))
		var wt: float = float(lf.get("w", 0.0))
		var d: Vector4 = (SIDE * cos(ph) + FRONT * sin(ph)) * cos(wt) + ANA * sin(wt)
		var L: float = float(lf.get("L", 0.08))
		var sa: Array = arc(base, d, UP, L, 0.5, -0.5, 4)
		var spts: PackedVector4Array = sa[0]
		tube(spts, PackedFloat32Array([0.0013, 0.0012, 0.0011, 0.001, 0.0009]), STEM, 4)
		var side: Vector4 = Vector4(d.z, 0.0, -d.x, d.w * 0.0)
		side = side.normalized() if side.length() > 0.1 else FRONT
		for k in [1, 2, 3]:
			var p0: Vector4 = spts[k]
			var tdir: Vector4 = (spts[mini(k + 1, 4)] - spts[k - 1]).normalized()
			for sgn in [1.0, -1.0]:
				var ld: Vector4 = (side * sgn * 0.9 + tdir * 0.4).normalized()
				ld = (ld - UP * ld.dot(UP) * 0.6).normalized()
				var ar: Array = arc(p0, ld, UP, 0.026, 0.25, -0.3, 4)
				blade(ar[0], widths(4, 0.0085, 0.45, 0.6, 0.25, 6, 0.08), ar[1], 0.001, LEAF)
		var tip_d: Vector4 = (spts[4] - spts[3]).normalized()
		var ar2: Array = arc(spts[4], tip_d, (UP - tip_d * tip_d.dot(UP)).normalized(), 0.03, 0.0, -0.2, 4)
		blade(ar2[0], widths(4, 0.0095, 0.45, 0.6, 0.25, 6, 0.08), ar2[1], 0.001, LEAF)

	## A passionflower's tendril: a thin coil from the stem.
	func _tendril(at: float) -> void:
		var base: Vector4 = stem_at(at)
		var pts := PackedVector4Array([base])
		var radii := PackedFloat32Array([0.0007])
		var ph: float = rng.randf() * TAU
		var out: Vector4 = SIDE * cos(ph) + FRONT * sin(ph)
		var across: Vector4 = Vector4(out.z, 0.0, -out.x, 0.0)
		for k in 9:
			var t: float = float(k + 1) / 9.0
			var ang: float = t * TAU * 1.6
			var rr: float = 0.012 * (1.0 - t * 0.6)
			pts.append(base + out * (0.025 * t + rr * (1.0 - cos(ang))) + UP * (0.03 * t + rr * sin(ang) * 0.5) + across * (rr * sin(ang) * 0.6))
			radii.append(0.0007 * (1.0 - t * 0.5))
		tube(pts, radii, STEM, 3)
