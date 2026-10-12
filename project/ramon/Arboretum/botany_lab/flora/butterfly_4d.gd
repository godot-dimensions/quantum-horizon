extends RefCounted

## BOTANY LAB, round 3 (follow_up/arboretum.md section 9, step 11): eight butterflies, each a true 4D
## loft (feedback: every animal a true 4D loft, never a 3D mesh a shader shrinks). Three meshes a
## butterfly, baked under flora/baked/: the body (head, thorax, abdomen, antennae with their clubs) and
## each side's pair of wings, hinged on the body's long axis so butterflies_4d.gd can open and close
## them.
##
## A WING IN 4D is a thin blade: flat across its face, round across the other two directions (the
## chord in the slice, and W), so it is a thin 3D blade whose outline the slice shows; the pattern is
## painted by where a point lies along the wing (u, root to tip) and across it (v, hind edge to
## leading edge), one texture slice per wing and species, after the real insect:
##   monarch       Danaus plexippus: orange cells, black veins and border, white dots
##   blue morpho   Morpho menelaus: bright blue, black leading edge and tip, white spots
##   swallowtail   Papilio machaon: yellow, black base and bars, a blue-spotted border, a red eye, tails
##   peacock       Aglais io: rust red, an eye on every wing
##   small white   Pieris rapae: white, a grey tip, one or two black spots
##   painted lady  Vanessa cardui: orange, a black tip with white spots, rows of small dots
##   red admiral   Vanessa atalanta: black, a red band across, white spots, a red hind border
##   brimstone     Gonepteryx rhamni: lemon yellow, pointed tips, an orange dot on each wing
## Sizes are the insect's (metres, forewing length); the room scales them.
##
## Local frame: +z the head, y the back, x the right wing; wings open flat in x and z.
## NO class_name (engine_gotchas.md).

const Loft := preload("res://ramon/Arboretum/botany_lab/carried/chickenpen/scripts/loft_builder_4d.gd")
const Kit := preload("res://ramon/Arboretum/botany_lab/flora/flora_kit.gd")
const BAKED := "res://ramon/Arboretum/botany_lab/flora/baked/"
const BAKE_VERSION := "v1"
const KEYS := ["monarch", "morpho", "swallowtail", "peacock", "small_white", "painted_lady", "red_admiral", "brimstone"]
const TEX := 32
## Texture slices: two a species (fore, hind), then the bodies.
const SLICES := 17

static var _material: TetraMaterial4D = null


static func data(key: String) -> Dictionary:
	match key:
		"monarch":
			return {"name": "Monarch", "latin": "Danaus plexippus", "fore": [0.32, 0.05, 0.0145, 0.55, 0.7], "hind": [-0.78, 0.036, 0.016, 0.5, 1.0],
				"beat": 5.5, "body": Color(0.08, 0.06, 0.05), "dots": Color(0.95, 0.95, 0.92)}
		"morpho":
			return {"name": "Blue morpho", "latin": "Morpho menelaus", "fore": [0.26, 0.068, 0.022, 0.55, 0.9], "hind": [-0.82, 0.05, 0.022, 0.5, 1.0],
				"beat": 3.6, "body": Color(0.12, 0.1, 0.08), "dots": Color(0.95, 0.95, 0.95)}
		"swallowtail":
			return {"name": "Swallowtail", "latin": "Papilio machaon", "fore": [0.3, 0.04, 0.012, 0.55, 0.6], "hind": [-0.95, 0.032, 0.013, 0.5, 0.9],
				"tail": [0.013, 0.0018], "beat": 6.0, "body": Color(0.1, 0.08, 0.04), "dots": Color(0.98, 0.86, 0.3)}
		"peacock":
			return {"name": "Peacock", "latin": "Aglais io", "fore": [0.3, 0.03, 0.0102, 0.55, 0.45], "hind": [-0.82, 0.024, 0.011, 0.5, 0.7],
				"beat": 7.5, "body": Color(0.12, 0.08, 0.06), "dots": Color(0.9, 0.9, 0.9)}
		"small_white":
			return {"name": "Small white", "latin": "Pieris rapae", "fore": [0.3, 0.025, 0.0092, 0.55, 0.92], "hind": [-0.8, 0.02, 0.0092, 0.5, 1.0],
				"beat": 10.0, "body": Color(0.22, 0.22, 0.22), "dots": Color(1, 1, 1)}
		"painted_lady":
			return {"name": "Painted lady", "latin": "Vanessa cardui", "fore": [0.33, 0.03, 0.0092, 0.55, 0.7], "hind": [-0.8, 0.023, 0.0102, 0.5, 0.95],
				"beat": 8.0, "body": Color(0.3, 0.22, 0.14), "dots": Color(0.95, 0.95, 0.95)}
		"red_admiral":
			return {"name": "Red admiral", "latin": "Vanessa atalanta", "fore": [0.33, 0.031, 0.0095, 0.55, 0.65], "hind": [-0.86, 0.024, 0.0102, 0.5, 0.95],
				"beat": 7.5, "body": Color(0.06, 0.05, 0.05), "dots": Color(0.95, 0.95, 0.95)}
		"brimstone":
			return {"name": "Brimstone", "latin": "Gonepteryx rhamni", "fore": [0.28, 0.03, 0.0112, 0.6, 0.12], "hind": [-0.74, 0.026, 0.0122, 0.55, 0.2],
				"beat": 6.5, "body": Color(0.5, 0.52, 0.3), "dots": Color(1, 0.6, 0.1)}
	return {}


## The three meshes of a butterfly: [body, right wings, left wings].
static func meshes(key: String) -> Array:
	var out: Array = []
	for part in ["body", "right", "left"]:
		var path: String = BAKED + "fly_%s_%s_%s.res" % [key, part, BAKE_VERSION]
		out.append(Kit.cached(path, func() -> ArrayTetraMesh4D: return build(key, part)))
	return out


static func build(key: String, part: String) -> ArrayTetraMesh4D:
	var d: Dictionary = data(key)
	if d.is_empty():
		return null
	var i: int = KEYS.find(key)
	if part == "body":
		return _body(d, i)
	var side: float = 1.0 if part == "right" else -1.0
	var parts: Array = [_wing(d, i, true, side), _wing(d, i, false, side)]
	if d.has("tail"):
		parts.append(_tail(d, i, side))
	return Kit.merge(parts)


static func _tex(slice: int, u: float, v: float) -> Vector3:
	return Vector3((0.5 + clampf(u, 0.0, 1.0) * float(TEX - 1)) / float(TEX), (0.5 + clampf(v, 0.0, 1.0) * float(TEX - 1)) / float(TEX), (float(slice) + 0.5) / float(SLICES))


## One wing: a blade from its root on the thorax out along its own angle (+ toward the head), its half
## chord by a profile; painted u along, v from the hind edge (0) to the leading edge (1).
static func _wing(d: Dictionary, i: int, fore: bool, side: float) -> ArrayTetraMesh4D:
	var w: Array = d["fore"] if fore else d["hind"]
	var ang: float = float(w[0])
	var L: float = float(w[1])
	var hw: float = float(w[2])
	var peak: float = float(w[3])
	var roundness: float = float(w[4])
	var dir := Vector4(side * cos(ang), 0.0, sin(ang), 0.0)
	# Across the wing, toward the head (square to dir in the wing's plane, on either side).
	var chord := Vector4(-dir.z * side, 0.0, dir.x * side, 0.0)
	var root := Vector4(side * 0.0016, 0.0, 0.0028 if fore else -0.0012, 0.0)
	var n: int = 6
	var pts := PackedVector4Array()
	var widths := PackedFloat32Array()
	var nrm: Array = []
	for k in n + 1:
		var s: float = float(k) / float(n)
		# The midline sweeps a little back toward the tip (forewings) or out (hindwings): the outline's
		# leading edge straighter than its hind edge.
		var sweep: float = (0.12 if fore else -0.05) * s * s * L
		pts.append(root + dir * (s * L) - chord * sweep)
		var x: float
		if s <= peak:
			x = lerpf(0.35, 1.0, sin(s / peak * PI * 0.5))
		else:
			var t: float = (s - peak) / (1.0 - peak)
			x = lerpf(1.0 - t, pow(maxf(cos(t * PI * 0.5), 0.0), 0.5), roundness)
		widths.append(maxf(x * hw, 0.0006))
		nrm.append(Vector4(0, 1, 0, 0))
	var sections: Array = []
	for k in pts.size():
		var r: float = widths[k]
		sections.append({"center": pts[k], "radius": r, "v_scale": 1.0, "w_scale": 1.0, "basis": Kit.flatten4(nrm[k], clampf(0.0008 / r, 0.03, 1.0))})
	var m: ArrayTetraMesh4D = Loft.build(sections, 2, 4, true, false, true, 0, false)
	if m == null:
		return null
	var slice: int = i * 2 + (0 if fore else 1)
	var pos: PackedVector4Array = m.get_vertex_positions()
	var tx := PackedVector3Array()
	tx.resize(pos.size())
	for vi in pos.size():
		var q: Vector4 = pos[vi]
		var best: float = INF
		var bs: float = 0.0
		var bv: float = 0.5
		for k in pts.size() - 1:
			var ab: Vector4 = pts[k + 1] - pts[k]
			var l2: float = ab.length_squared()
			var t: float = clampf((q - pts[k]).dot(ab) / l2, 0.0, 1.0) if l2 > 1e-12 else 0.0
			var c: Vector4 = pts[k] + ab * t
			var dd: float = q.distance_to(c)
			if dd < best:
				best = dd
				bs = (float(k) + t) / float(n)
				var wdt: float = lerpf(widths[k], widths[k + 1], t)
				# Toward the head is the leading edge, for the forewing; the hindwing's leading edge
				# is the one under the forewing (also toward the head).
				bv = 0.5 + 0.5 * clampf((q - c).dot(chord) / maxf(wdt, 1e-5), -1.0, 1.0)
		tx[vi] = _tex(slice, bs, bv)
	m.set_texture_map_values(tx)
	m.set_simplex_cell_texture_map_indices(m.get_simplex_cell_vertex_indices())
	return m


## The swallowtail's tail: a thin blade off the hindwing's outer edge, back.
static func _tail(d: Dictionary, i: int, side: float) -> ArrayTetraMesh4D:
	var h: Array = d["hind"]
	var ang: float = float(h[0])
	var L: float = float(h[1])
	var dir := Vector4(side * cos(ang), 0.0, sin(ang), 0.0)
	var start := Vector4(side * 0.0016, 0.0, -0.0012, 0.0) + dir * (L * 0.82)
	var tl: Array = d["tail"]
	var back := Vector4(side * 0.25, 0.0, -1.0, 0.0).normalized()
	var sections: Array = []
	var pts := PackedVector4Array()
	for k in 4:
		var s: float = float(k) / 3.0
		var p: Vector4 = start + back * (s * float(tl[0]))
		pts.append(p)
		var r: float = float(tl[1]) * lerpf(1.2, 0.9, s)
		sections.append({"center": p, "radius": r, "v_scale": 1.0, "w_scale": 1.0, "basis": Kit.flatten4(Vector4(0, 1, 0, 0), clampf(0.0008 / r, 0.03, 1.0))})
	var m: ArrayTetraMesh4D = Loft.build(sections, 2, 4, true, false, true, 0, false)
	if m == null:
		return null
	Kit.paint(m, func(_q: Vector4) -> Vector3: return _tex(i * 2 + 1, 0.98, 0.1))
	return m


## The body: head, thorax and a tapering abdomen along z, round in all three directions across it;
## two antennae with clubs.
static func _body(d: Dictionary, i: int) -> ArrayTetraMesh4D:
	var size: float = float((d["fore"] as Array)[1]) / 0.03
	var prof: Array = [[0.0075, 0.0011], [0.0062, 0.0017], [0.0046, 0.0014], [0.0028, 0.0024], [0.0005, 0.0025], [-0.0015, 0.0018],
		[-0.006, 0.0019], [-0.011, 0.0015], [-0.0155, 0.0008]]
	var sections: Array = []
	for pr in prof:
		sections.append({"center": Vector4(0.0, 0.0, float(pr[0]) * size, 0.0), "radius": float(pr[1]) * size, "v_scale": 1.0, "w_scale": 1.0})
	var parts: Array = [Loft.build(sections, 2, 5, true, false, true, 0, false)]
	for sgn in [1.0, -1.0]:
		var pts := PackedVector4Array()
		var radii := PackedFloat32Array()
		for k in 5:
			var s: float = float(k) / 4.0
			pts.append(Vector4(sgn * (0.0008 + s * 0.0035), 0.0008 + s * 0.004, 0.0068 + s * 0.011, 0.0) * size)
			radii.append(0.00028 * size if k < 4 else 0.0006 * size)
		var sec: Array = []
		for k in pts.size():
			sec.append({"center": pts[k], "radius": radii[k], "v_scale": 1.0, "w_scale": 1.0})
		parts.append(Loft.build(sec, 2, 3, true, false, true, 0, false))
	var m: ArrayTetraMesh4D = Kit.merge(parts)
	Kit.paint(m, func(q: Vector4) -> Vector3: return Vector3((float(i) + 0.5) / 8.0, clampf(0.5 + q.y / (0.005 * size), 0.0, 1.0) * 0.9 + 0.05, (16.5) / float(SLICES)))
	return m


# -- the wings' patterns ------------------------------------------------------------------------------

static func material() -> TetraMaterial4D:
	if _material != null:
		return _material
	var slices: Array = []
	for i in KEYS.size():
		for fore in [true, false]:
			var img: Image = Image.create(TEX, TEX, false, Image.FORMAT_RGBA8)
			for vi in TEX:
				for ui in TEX:
					img.set_pixel(ui, vi, wing_colour(KEYS[i], fore, float(ui) / float(TEX - 1), float(vi) / float(TEX - 1)))
			slices.append(img)
	# The bodies: one column band a species (x), dark below to its own colour on the back (y).
	var body: Image = Image.create(TEX, TEX, false, Image.FORMAT_RGBA8)
	for ui in TEX:
		var k: int = mini(int(float(ui) / float(TEX) * 8.0), 7)
		var c: Color = data(KEYS[k])["body"]
		for vi in TEX:
			var y: float = float(vi) / float(TEX - 1)
			body.set_pixel(ui, vi, c.darkened(0.35 * (1.0 - y)).lerp(Color(0.85, 0.82, 0.75), 0.15 if (k == 0 and int(vi) % 5 == 0) else 0.0))
	slices.append(body)
	_material = Kit.tex_material(slices)
	return _material


static func _h(a: float, b: float) -> float:
	return fmod(absf(sin(a * 127.1 + b * 311.7) * 43758.5453), 1.0)


## The colour at (u along the wing, v from its hind edge to its leading edge).
static func wing_colour(key: String, fore: bool, u: float, v: float) -> Color:
	# How far in from the outline (0 on it): the tip and both edges.
	var edge: float = minf(1.0 - u, minf(v, 1.0 - v) * 2.0)
	var black := Color(0.05, 0.04, 0.04)
	match key:
		"monarch":
			var c := Color(0.96, 0.5, 0.06).lerp(Color(0.85, 0.36, 0.04), u * 0.4)
			# Veins: lines along the wing, fanning toward the tip.
			var vein: float = absf(fmod(v * 4.0 + u * 0.6, 1.0) - 0.5)
			if vein > 0.43 or u < 0.06:
				c = black
			if edge < 0.14 or (fore and u > 0.72 and v > 0.55):
				c = black
				# White dots in the black border, two rows.
				var gu: float = (u + v) * 13.0
				if absf(fmod(gu, 1.0) - 0.5) < 0.22 and edge > 0.03 and edge < 0.11:
					c = Color(0.97, 0.96, 0.92)
				if fore and u > 0.8 and v > 0.62 and _h(floor(u * 10.0), floor(v * 8.0)) > 0.6:
					c = Color(0.98, 0.7, 0.3) if v < 0.8 else Color(0.97, 0.96, 0.92)
			return c
		"morpho":
			var c := Color(0.08, 0.42, 1.0).lerp(Color(0.25, 0.75, 1.0), smoothstep(0.2, 0.7, u) * smoothstep(0.2, 0.6, v) * 0.6)
			if (fore and (v > 0.82 - u * 0.25 or u > 0.78)) or edge < 0.08:
				c = Color(0.04, 0.05, 0.08)
				if fore and u > 0.6 and _h(floor(u * 9.0), floor(v * 7.0)) > 0.72:
					c = Color(0.92, 0.94, 0.98)
			return c
		"swallowtail":
			var c := Color(0.98, 0.86, 0.28)
			if u < 0.16 or edge < 0.16:
				c = black
				if edge > 0.05 and edge < 0.13 and absf(fmod(u * 9.0 + v * 3.0, 1.0) - 0.5) < 0.24:
					c = Color(0.98, 0.86, 0.28) if fore else Color(0.25, 0.4, 0.9)
			if fore and v > 0.72 and (absf(u - 0.3) < 0.05 or absf(u - 0.47) < 0.05 or absf(u - 0.62) < 0.04):
				c = black
			var vein: float = absf(fmod(v * 5.0 + u * 0.5, 1.0) - 0.5)
			if vein > 0.46:
				c = black
			if not fore and Vector2(u - 0.2, v - 0.12).length() < 0.09:
				c = Color(0.9, 0.2, 0.1) if Vector2(u - 0.2, v - 0.12).length() < 0.06 else Color(0.25, 0.4, 0.9)
			return c
		"peacock":
			var c := Color(0.62, 0.12, 0.07).lerp(Color(0.45, 0.08, 0.05), u * 0.4)
			if edge < 0.1:
				c = Color(0.26, 0.15, 0.1)
			var eye := Vector2(0.74, 0.62) if fore else Vector2(0.6, 0.5)
			var r: float = Vector2(u - eye.x, (v - eye.y) * 0.8).length()
			if fore:
				if r < 0.22:
					c = Color(0.95, 0.8, 0.45)
				if r < 0.16:
					c = Color(0.55, 0.15, 0.25)
				if r < 0.11:
					c = Color(0.2, 0.35, 0.75)
				if r < 0.05:
					c = black
			else:
				if r < 0.26:
					c = Color(0.85, 0.85, 0.8)
				if r < 0.22:
					c = black
				if r < 0.15:
					c = Color(0.18, 0.3, 0.62) if _h(floor(u * 20.0), floor(v * 20.0)) > 0.35 else black
			if fore and v > 0.82 and u < 0.6 and absf(fmod(u * 8.0, 1.0) - 0.5) < 0.2:
				c = Color(0.1, 0.06, 0.05)
			return c
		"small_white":
			var c := Color(0.96, 0.96, 0.92).lerp(Color(0.8, 0.8, 0.76), (1.0 - smoothstep(0.0, 0.2, u)))
			if fore and u > 0.82 and v > 0.45:
				c = Color(0.35, 0.35, 0.34)
			if fore and (Vector2(u - 0.58, v - 0.38).length() < 0.07 or Vector2(u - 0.6, v - 0.14).length() < 0.06):
				c = Color(0.15, 0.15, 0.15)
			if not fore and Vector2(u - 0.55, v - 0.86).length() < 0.06:
				c = Color(0.2, 0.2, 0.2)
			return c
		"painted_lady":
			var c := Color(0.92, 0.52, 0.2).lerp(Color(0.7, 0.4, 0.2), (1.0 - smoothstep(0.0, 0.3, u)) * 0.6)
			if fore and u > 0.6 and v > 0.38 - (u - 0.6) * 0.5:
				c = black
				if _h(floor(u * 10.0), floor(v * 9.0)) > 0.62 and u > 0.66:
					c = Color(0.97, 0.95, 0.92)
			if fore and absf(u - 0.45) < 0.06 and v > 0.4:
				c = black
			if not fore:
				if edge < 0.2 and edge > 0.1 and absf(fmod(u * 10.0 + v * 4.0, 1.0) - 0.5) < 0.2:
					c = black
				if edge < 0.06:
					c = Color(0.3, 0.2, 0.12)
			return c
		"red_admiral":
			var c := Color(0.08, 0.06, 0.06)
			if fore and absf(u + 0.55 * (1.0 - v) - 0.88) < 0.09 and v < 0.9:
				c = Color(0.88, 0.22, 0.06)
			if fore and u > 0.76 and v > 0.55 and _h(floor(u * 11.0), floor(v * 9.0)) > 0.55:
				c = Color(0.97, 0.97, 0.95)
			if not fore and edge < 0.2 and edge > 0.04 and u > 0.35:
				c = Color(0.88, 0.22, 0.06)
				if absf(fmod(u * 9.0, 1.0) - 0.5) < 0.12 and edge > 0.1:
					c = black
			return c
		"brimstone":
			var c := Color(0.96, 0.93, 0.36).lerp(Color(0.86, 0.9, 0.4), (1.0 - smoothstep(0.0, 0.3, u)) * 0.5)
			if Vector2(u - 0.52, v - 0.5).length() < 0.05:
				c = Color(0.98, 0.55, 0.08)
			var vein: float = absf(fmod(v * 4.0 + u * 0.4, 1.0) - 0.5)
			if vein > 0.47:
				c = c.darkened(0.12)
			return c
	return Color.MAGENTA
