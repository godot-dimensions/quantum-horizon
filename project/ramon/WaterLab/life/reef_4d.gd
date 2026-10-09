extends Node4D

## WATER LAB: the tank's stones and corals, built once when the room opens, in the water's own frame
## (life/, x along the tank, y up, z toward the glass, W). Nothing here moves, so every piece is a
## lofted 4D mesh (the carried loft builder, chickenpen/scripts/loft_builder_4d.gd), drawn by the
## engine like any other: drawing costs next to nothing (lofting_gotchas.md).
##
##   STONES   a glome lofted along y, its sections pushed about by noise, then CUT BY PLANES: every
##            vertex past a plane is put back on it, so the stone has flat facets and edges the way
##            the Voxel Lab's chamfered specimens do (Ramon: "nice stones (look at how the Voxel Lab
##            generated things)"). A grey speckle in a 3D texture. A pile of three makes the eel's
##            cave.
##   ARCHES   (Ramon, 9 Oct: "bigger stone arches fish can swim through"): a rock lofted along an arc,
##            its opening along the tank so the koi swim through it, lumped like the stones. One stands
##            turned 40 degrees into W: the level slice cuts only part of it; turn the tank's contents
##            through W (the room's gizmo) and it comes whole.
##   BOULDERS the stones again at four times the size (Ramon: "one of the stones you got, just try to
##            scale it up, 4X").
##   ON THE DUNES everything stands on the sand's 4D hills (`ground`, dunes_4d.gd height_at).
##   CORALS   staghorn: forking branches that spread through x, z AND W, so a turned slice cuts a
##            different colony; a table coral (a plate on a stalk); boulder corals; a sea fan (its
##            branches in one plane, square to the current); tube sponges; an anemone. Each colony one
##            mesh (its branches merged), coloured base to tip by a ramp.
##
## KEPT LIGHT (9 Oct): the first build was 301,000 tetrahedra and 3.7 s; drawing is cheap but not free
## (about 17 ns a tetrahedron a frame) and the loft's winding pass is slow in GDScript. Few sides,
## little smoothing: the stones' facets come from the cuts anyway.
##
## BAKED (9 Oct): each piece is lofted once and saved under life/baked/ (reef_<version>_<name>.res, Git
## LFS as the Arboretum's bakes are), then loaded: the room opened in 3.6 s building them every time.
## Each piece's shape comes from its own random numbers, seeded by its name, so a piece built fresh and
## one loaded are the same. Change how pieces are made and bump BAKE_VERSION (and delete the old files).
##
## `obstacles` hands the koi and the eel a sphere for each piece; `arches` their openings, for the koi
## to swim through. NO class_name (engine_gotchas.md).

const Loft := preload("res://ramon/WaterLab/carried/chickenpen/scripts/loft_builder_4d.gd")
const BAKED := "res://ramon/WaterLab/life/baked/"
const BAKE_VERSION := "v1"

## The water's half extents (the tank sets it) and the sand's top, in this node's frame.
var half_extents: Vector4 = Vector4(9.2, 2.4, 1.6, 3.5)
var floor_y: float = -2.14
## The dunes (dunes_4d.gd), whose height everything stands on; null: the flat sand.
var ground: Node = null
## The arches' openings: {"centre": Vector4 (the middle of the opening), "axis": Vector4 (through it)}.
var arches: Array = []
## [centre, radius] for the swimmers.
var obstacles: Array = []
## Where the eel's cave opens, and the way out of it (the eel rests there).
var cave_mouth: Vector4 = Vector4.ZERO
var cave_out: Vector4 = Vector4(0, 0, 1, 0)
var tets: int = 0
var build_ms: float = 0.0
var baked_hits: int = 0
var _rng := RandomNumberGenerator.new()
## The random numbers a piece's SHAPE is made from, seeded by its name (_cached).
var _brng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()


func _ready() -> void:
	var t0: int = Time.get_ticks_usec()
	_rng.seed = 90917
	_noise.seed = 4471
	_noise.frequency = 1.6
	floor_y = -half_extents.y + 0.26
	_stones()
	_corals()
	build_ms = float(Time.get_ticks_usec() - t0) / 1000.0


# -- stones ------------------------------------------------------------------------------------------------------

## The sand's height at (x, z, w).
func _gy(x: float, z: float, w: float) -> float:
	return float(ground.call("height_at", x, z, w)) if ground != null else floor_y


## A point `up` metres above the sand at (x, z, w), sunk a little: a stone sits in the sand.
func _on(x: float, up: float, z: float, w: float) -> Vector4:
	return Vector4(x, _gy(x, z, w) + up - 0.08, z, w)


func _stones() -> void:
	var granite: TetraMaterial4D = _speckle(Color(0.42, 0.43, 0.44), Color(0.24, 0.25, 0.27), Color(0.62, 0.60, 0.56))
	var warm: TetraMaterial4D = _speckle(Color(0.47, 0.43, 0.38), Color(0.30, 0.27, 0.24), Color(0.64, 0.58, 0.50))
	var y: float = floor_y
	# The eel's cave: two stones with a third across them, a gap under it facing the glass.
	_stone("CaveLeft", _on(-4.75, 0.36, -0.95, 0.0), Vector4(0.78, 0.56, 0.6, 0.65), granite, 6)
	_stone("CaveRight", _on(-3.15, 0.32, -1.0, 0.08), Vector4(0.7, 0.5, 0.55, 0.6), warm, 5)
	_stone("CaveTop", _on(-3.95, 0.98, -1.05, -0.04), Vector4(0.95, 0.32, 0.5, 0.55), granite, 6)
	cave_mouth = _on(-3.95, 0.2, -0.55, 0.0)
	cave_out = Vector4(0.0, 0.0, 1.0, 0.0)
	# Boulders under the reef, and one off the slice.
	_stone("ReefRockA", _on(5.4, 0.25, -0.8, 0.15), Vector4(1.05, 0.38, 0.7, 0.75), warm, 7)
	_stone("ReefRockB", _on(7.4, 0.18, 0.2, -0.3), Vector4(0.7, 0.3, 0.6, 0.6), granite, 5)
	_stone("DeepRock", _on(0.6, 0.3, -0.7, 1.4), Vector4(0.8, 0.45, 0.6, 0.6), granite, 6)
	_stone("FarLeftRock", _on(-8.0, 0.4, -0.9, -0.2), Vector4(0.9, 0.6, 0.6, 0.7), warm, 6)
	# ROCKWORK (9 Oct, second pass: the first stones were lost in an 18 m tank): three big formations,
	# stacked, the tallest up to a third of the water.
	_stone("WorkLeftBase", _on(-6.6, 0.55, -0.85, 0.1), Vector4(1.3, 0.8, 0.75, 0.9), granite, 7)
	_stone("WorkLeftTop", _on(-6.9, 1.45, -1.0, -0.05), Vector4(0.8, 0.55, 0.55, 0.6), warm, 6)
	_stone("WorkMidBase", _on(-0.4, 0.45, -1.05, 0.2), Vector4(1.5, 0.62, 0.55, 0.9), warm, 7)
	_stone("WorkMidTop", _on(0.3, 1.15, -1.15, -0.1), Vector4(0.7, 0.42, 0.42, 0.55), granite, 5)
	_stone("WorkRightBase", _on(6.4, 0.6, -0.95, -0.15), Vector4(1.4, 0.85, 0.65, 0.9), granite, 7)
	_stone("WorkRightTop", _on(6.0, 1.55, -1.05, 0.1), Vector4(0.85, 0.6, 0.5, 0.6), warm, 6)
	_stone("WorkRightSide", _on(7.9, 0.9, -0.5, 0.25), Vector4(0.7, 0.9, 0.6, 0.6), granite, 6)
	# Boulders four times the size of the stones: one at the back left, one off the slice through W.
	_stone("GiantBack", _on(5.6, 0.9, -1.05, -0.4), Vector4(2.0, 1.25, 0.6, 1.6), warm, 8)
	_stone("GiantDeep", _on(3.2, 1.0, -0.6, -2.0), Vector4(1.8, 1.3, 0.8, 1.2), granite, 8)
	# The arches: two across the tank's depth, their openings along it; one turned 40 degrees into W.
	_arch("ArchLeft", Vector4(-1.8, 0.0, -0.45, 0.0), 2.3, 2.3, 0.42, Projection.IDENTITY, granite)
	_arch("ArchRight", Vector4(2.6, 0.0, -0.5, 0.15), 2.0, 1.9, 0.38, Projection.IDENTITY, warm)
	# The W arch faces the glass (its span along x) and leans 35 degrees into W: the level slice cuts
	# its top and thin pieces of its legs; turned back through W it stands whole, an arch to look through.
	_arch("ArchW", Vector4(0.9, 0.0, -0.9, 0.0), 2.4, 2.0, 0.40, Basis4D.from_xw(deg_to_rad(35.0)) * Basis4D.from_zx(PI * 0.5), granite, false)
	# River stones over the sand, some of them through W.
	for i in 14:
		var r: float = _rng.randf_range(0.10, 0.26)
		var at := Vector4(_rng.randf_range(-8.6, 8.6), 0.0, _rng.randf_range(-1.2, 1.25), _rng.randf_range(-1.4, 1.4) if i % 3 == 0 else _rng.randf_range(-0.12, 0.12))
		at.y = _gy(at.x, at.z, at.w) + r * 0.4
		_stone("Pebble%d" % i, at, Vector4(r * _rng.randf_range(1.0, 1.5), r * 0.6, r, r), granite if i % 2 == 0 else warm, 3, false)


## One stone: its half extents (x, y, z, W), `cuts` planes, and whether the swimmers go round it.
func _stone(nm: String, at: Vector4, ext: Vector4, mat: TetraMaterial4D, cuts: int, obstacle: bool = true) -> void:
	var make := func() -> ArrayTetraMesh4D: return _stone_mesh(ext, cuts)
	var mesh: ArrayTetraMesh4D = _cached(nm, make)
	if mesh == null:
		return
	_place(nm, mesh, mat, at)
	if obstacle:
		obstacles.append([at, maxf(ext.x, ext.z) * 0.95])


func _stone_mesh(ext: Vector4, cuts: int) -> ArrayTetraMesh4D:
	var sections: Array = []
	var n: int = 7
	var phase: float = _brng.randf() * 10.0
	for k in n:
		var t: float = lerpf(-0.94, 0.94, float(k) / float(n - 1))
		var s: float = pow(maxf(1.0 - t * t, 0.0), 0.42)
		var wob: float = 1.0 + 0.12 * _noise.get_noise_2d(phase, t * 2.0)
		sections.append({"center": Vector4(0.06 * ext.x * _noise.get_noise_2d(phase + 5.0, t), t * ext.y, 0.05 * ext.z * _noise.get_noise_2d(phase + 9.0, t), 0.0),
			"radius": maxf(ext.x * s * wob, 0.01), "v_scale": ext.z / ext.x * (1.0 + 0.1 * _noise.get_noise_2d(phase, t + 3.0)),
			"w_scale": ext.w / ext.x, "color": Color.WHITE})
	var big: bool = maxf(ext.x, ext.y) > 0.35
	var mesh: ArrayTetraMesh4D = Loft.build(sections, 4 if big else 3, 9 if big else 7, true, false, true, 1 if big else 0, false)
	if mesh == null:
		return null
	var pos: PackedVector4Array = mesh.get_vertex_positions()
	# Lumps, then the planes.
	for i in pos.size():
		var p: Vector4 = pos[i]
		var r: float = p.length()
		if r > 0.0001:
			p += p / r * (0.07 * ext.y * _noise.get_noise_3d(p.x * 2.2 + phase, p.y * 2.2, p.z * 2.2 + p.w * 1.7))
		pos[i] = p
	for c in cuts:
		var nrm := Vector4(_brng.randf_range(-1, 1), _brng.randf_range(-0.3, 1.0), _brng.randf_range(-1, 1), _brng.randf_range(-0.6, 0.6)).normalized()
		var reach: float = absf(nrm.x) * ext.x + absf(nrm.y) * ext.y + absf(nrm.z) * ext.z + absf(nrm.w) * ext.w
		var d: float = reach * _brng.randf_range(0.48, 0.66)
		for i in pos.size():
			var e: float = pos[i].dot(nrm) - d
			if e > 0.0:
				pos[i] = pos[i] - nrm * e
	# Flat underneath: it sits on the sand.
	for i in pos.size():
		if pos[i].y < -ext.y * 0.78:
			pos[i].y = -ext.y * 0.78
	mesh.set_vertex_positions(pos)
	_by_position(mesh, ext)
	mesh.calculate_boundary_normals(false)
	return mesh


## An arch: a rock lofted along an arc in its own y-z plane (the opening along x), `span` between its
## feet, `height` to the top of its opening, `thick` its rock's half width; turned by `turn` (a turn
## into W stands it partly off the slice). Its feet are sunk in the sand. Lumped like the stones.
func _arch(nm: String, base: Vector4, span: float, height: float, thick: float, turn: Projection, mat: TetraMaterial4D, runnable: bool = true) -> void:
	var gy: float = _gy(base.x, base.z, base.w)
	var sections: Array = []
	var n: int = 13
	var phase: float = float(absi(hash(nm)) % 1000) * 0.01
	for k in n:
		var t: float = float(k) / float(n - 1)
		var a: float = lerpf(-0.12, PI + 0.12, t)
		var along: float = -cos(a) * span * 0.5
		var up: float = sin(a) * (height + thick)
		var foot: float = 1.0 + 0.45 * (1.0 - sin(clampf(a, 0.0, PI)))
		var r: float = thick * foot * (1.0 + 0.15 * _noise.get_noise_2d(phase, t * 6.0))
		var local := Vector4(0.0, up - 0.25, along, 0.0)
		sections.append({"center": turn * local, "radius": r, "v_scale": 1.0 + 0.2 * _noise.get_noise_2d(phase + 3.0, t * 5.0), "w_scale": 1.15, "color": Color.WHITE})
	var make := func() -> ArrayTetraMesh4D:
		var m: ArrayTetraMesh4D = Loft.build(sections, 4, 10, true, false, true, 1, false)
		if m == null:
			return null
		var pos: PackedVector4Array = m.get_vertex_positions()
		for i in pos.size():
			var p: Vector4 = pos[i]
			var nz: float = _noise.get_noise_3d(p.x * 2.6 + phase, p.y * 2.6, p.z * 2.6 + p.w * 1.9)
			# Stepped, so the lumps read as rock faces, not dough.
			nz = round(nz * 4.0) / 4.0
			var c := Vector4(0.0, p.y, 0.0, 0.0)
			var d: Vector4 = p - c
			if d.length() > 0.001:
				p += d.normalized() * thick * 0.28 * nz
			pos[i] = p
		m.set_vertex_positions(pos)
		_by_position(m, Vector4(span * 0.6, height, span * 0.6, span * 0.6))
		m.calculate_boundary_normals(false)
		return m
	var mesh: ArrayTetraMesh4D = _cached(nm, make)
	if mesh == null:
		return
	var at := Vector4(base.x, gy, base.z, base.w)
	_place(nm, mesh, mat, at)
	for s in sections:
		obstacles.append([at + (s["center"] as Vector4), float(s["radius"]) * 1.25])
	var middle: Vector4 = at + turn * Vector4(0.0, height * 0.5, 0.0, 0.0)
	if runnable:
		arches.append({"centre": middle, "axis": (turn * Vector4(1.0, 0.0, 0.0, 0.0)).normalized(), "half": height * 0.4})


# -- corals --------------------------------------------------------------------------------------------------------

func _corals() -> void:
	var y: float = floor_y
	# Twice the size of the first pass, and more of them.
	_staghorn("Staghorn", _on(4.6, 0.1, -0.7, 0.15), Color(0.72, 0.58, 0.40), Color(0.86, 0.80, 0.95), 2.0, 11)
	_staghorn("StaghornLeft", _on(-6.7, 2.0, -0.95, -0.1), Color(0.62, 0.50, 0.66), Color(0.95, 0.85, 0.98), 1.5, 23)
	_staghorn("StaghornDeep", _on(1.6, 0.0, -0.5, 1.4), Color(0.40, 0.62, 0.55), Color(0.85, 1.0, 0.9), 1.8, 37)
	_staghorn("StaghornMid", _on(0.4, 1.5, -1.1, 0.0), Color(0.80, 0.52, 0.32), Color(1.0, 0.86, 0.70), 1.2, 51)
	_table("TableCoral", _on(6.2, 2.1, -0.85, 0.1), Color(0.50, 0.58, 0.40), Color(0.78, 0.84, 0.56), 1.7)
	_table("TableCoralLow", _on(-3.0, 0.1, 0.4, -0.3), Color(0.58, 0.52, 0.62), Color(0.84, 0.80, 0.92), 1.1)
	_boulder("BoulderCoral", _on(2.9, 0.0, 0.55, 0.25), Color(0.58, 0.64, 0.32), Color(0.80, 0.82, 0.50), 0.85)
	_boulder("BoulderCoral2", _on(8.3, 0.0, 0.6, 0.4), Color(0.62, 0.40, 0.30), Color(0.86, 0.62, 0.48), 0.7)
	_boulder("BoulderCoral3", _on(-5.0, 0.0, 0.6, -0.2), Color(0.55, 0.60, 0.45), Color(0.82, 0.86, 0.66), 0.75)
	_fan("SeaFan", _on(3.6, 0.0, -1.35, -0.15), Color(0.42, 0.14, 0.48), Color(0.78, 0.38, 0.85), 2.1)
	_fan("SeaFanLeft", _on(-2.0, 0.0, -1.4, 0.3), Color(0.70, 0.30, 0.12), Color(0.95, 0.62, 0.30), 1.8)
	_fan("SeaFanRight", _on(8.4, 1.6, -1.3, 0.0), Color(0.80, 0.70, 0.18), Color(1.0, 0.92, 0.50), 1.3)
	_sponges("Sponges", _on(2.0, 0.0, -1.0, -0.3), Color(0.92, 0.50, 0.12), Color(0.35, 0.16, 0.05), 1.8)
	_sponges("SpongesLeft", _on(-8.4, 0.0, 0.2, 0.2), Color(0.90, 0.80, 0.20), Color(0.30, 0.20, 0.04), 1.5)
	_anemone("Anemone", _on(-4.2, 0.0, 0.55, 0.0), Color(0.86, 0.36, 0.52), Color(0.98, 0.78, 0.86), 2.2)
	_anemone("AnemoneGreen", _on(5.0, 0.0, 0.85, 0.1), Color(0.30, 0.62, 0.40), Color(0.80, 1.0, 0.70), 1.8)


## Staghorn: branches that fork two ways at each tip, three generations, spreading through W too.
func _staghorn(nm: String, at: Vector4, base: Color, tip: Color, size: float, _seed: int) -> void:
	var make := func() -> Array:
		var parts: Array = []
		for k in 5:
			var a: float = TAU * float(k) / 5.0 + _brng.randf_range(-0.3, 0.3)
			var dir := Vector4(cos(a) * 0.45, 1.0, sin(a) * 0.45, _brng.randf_range(-0.5, 0.5)).normalized()
			_branch(parts, Vector4(0.0, 0.0, 0.0, 0.0), dir, 0.42 * size, 0.055 * size, 0)
		return parts
	_colony(nm, make, base, tip, at, 0.75 * size)


func _branch(parts: Array, start: Vector4, dir: Vector4, length: float, radius: float, depth: int) -> void:
	var sections: Array = []
	var p: Vector4 = start
	var d: Vector4 = dir
	var n: int = 4
	for k in n:
		var t: float = float(k) / float(n - 1)
		sections.append({"center": p, "radius": radius * (1.0 - 0.35 * t), "v_scale": 1.0, "w_scale": 1.0, "color": Color.WHITE})
		d = (d + Vector4(_brng.randf_range(-0.25, 0.25), 0.12, _brng.randf_range(-0.25, 0.25), _brng.randf_range(-0.2, 0.2))).normalized()
		p += d * (length / float(n - 1))
	var m: ArrayTetraMesh4D = Loft.build(sections, 3, 6, true, false, true, 0, false)
	if m != null:
		parts.append(m)
	if depth < 2:
		var end: Vector4 = sections[n - 1]["center"]
		for s in [-1.0, 1.0]:
			var sideways := Vector4(_brng.randf_range(-1, 1), 0.0, _brng.randf_range(-1, 1), _brng.randf_range(-1, 1)).normalized()
			var nd: Vector4 = (d + sideways * 0.75 * s).normalized()
			nd.y = maxf(nd.y, 0.25)
			_branch(parts, end - d * radius * 0.5, nd.normalized(), length * 0.78, radius * 0.72, depth + 1)


## A table coral: a short stalk and a wide flat plate, thin at its rim.
func _table(nm: String, at: Vector4, base: Color, tip: Color, size: float = 1.0) -> void:
	var rows: Array = [[0.0, 0.11], [0.22, 0.08], [0.34, 0.16], [0.40, 0.62], [0.44, 0.92], [0.48, 0.98], [0.52, 0.7]]
	var sections: Array = []
	for r in rows:
		sections.append({"center": Vector4(0.0, float(r[0]) * size, 0.0, 0.0), "radius": float(r[1]) * size, "v_scale": 0.85, "w_scale": 0.55, "color": Color.WHITE})
	var make := func() -> Array: return [Loft.build(sections, 3, 14, true, false, true, 1, false)]
	_colony(nm, make, base, tip, at, 0.95 * size)


## A boulder coral: a few lumpy domes huddled together.
func _boulder(nm: String, at: Vector4, base: Color, tip: Color, size: float) -> void:
	var make := func() -> Array:
		var parts: Array = []
		for k in 4:
			var off := Vector4(_brng.randf_range(-0.4, 0.4), 0.0, _brng.randf_range(-0.3, 0.3), _brng.randf_range(-0.3, 0.3)) * size
			var r: float = size * _brng.randf_range(0.55, 0.9)
			var sections: Array = []
			for j in 6:
				var t: float = float(j) / 5.0
				sections.append({"center": off + Vector4(0.0, t * r * 0.95, 0.0, 0.0), "radius": maxf(r * sqrt(maxf(1.0 - t * t, 0.0)) * (1.0 + 0.08 * sin(t * 9.0 + float(k))), 0.02),
					"v_scale": 0.9, "w_scale": 0.85, "color": Color.WHITE})
			var m: ArrayTetraMesh4D = Loft.build(sections, 3, 10, true, false, true, 1, false)
			if m != null:
				parts.append(m)
		return parts
	_colony(nm, make, base, tip, at, size)


## A sea fan: branching in one plane (x and y), thin; its plane faces the glass, square to the current.
func _fan(nm: String, at: Vector4, base: Color, tip: Color, size: float = 1.0) -> void:
	var make := func() -> Array:
		var parts: Array = []
		for k in 3:
			var a: float = lerpf(-0.5, 0.5, float(k) / 2.0)
			_fan_branch(parts, Vector4(0.0, 0.0, 0.0, 0.0), Vector4(sin(a), cos(a), 0.0, 0.0), 0.38 * size, 0.022 * size, 0)
		return parts
	_colony(nm, make, base, tip, at, 0.7 * size)


func _fan_branch(parts: Array, start: Vector4, dir: Vector4, length: float, radius: float, depth: int) -> void:
	var end: Vector4 = start + dir * length
	var sections: Array = [{"center": start, "radius": radius, "v_scale": 1.0, "w_scale": 2.2, "color": Color.WHITE},
		{"center": (start + end) * 0.5, "radius": radius * 0.85, "v_scale": 1.0, "w_scale": 2.2, "color": Color.WHITE},
		{"center": end, "radius": radius * 0.7, "v_scale": 1.0, "w_scale": 2.2, "color": Color.WHITE}]
	var m: ArrayTetraMesh4D = Loft.build(sections, 3, 6, true, false, true, 0, false)
	if m != null:
		parts.append(m)
	if depth < 3:
		for s in [-1.0, 1.0]:
			var a: float = 0.42 * s + _brng.randf_range(-0.12, 0.12)
			var nd := Vector4(dir.x * cos(a) - dir.y * sin(a), dir.x * sin(a) + dir.y * cos(a), 0.0, 0.0)
			_fan_branch(parts, end, nd.normalized(), length * 0.74, radius * 0.75, depth + 1)


## Tube sponges: a cluster of tubes, flared at the top, dark at the mouth.
func _sponges(nm: String, at: Vector4, base: Color, mouth: Color, size: float = 1.0) -> void:
	var make := func() -> Array:
		var parts: Array = []
		for k in 5:
			var off := Vector4(_brng.randf_range(-0.25, 0.25), 0.0, _brng.randf_range(-0.2, 0.2), _brng.randf_range(-0.25, 0.25)) * size
			var h: float = _brng.randf_range(0.45, 0.95) * size
			var r: float = _brng.randf_range(0.07, 0.1) * size
			var lean := Vector4(_brng.randf_range(-0.15, 0.15), 1.0, _brng.randf_range(-0.15, 0.15), _brng.randf_range(-0.1, 0.1)).normalized()
			var sections: Array = []
			for j in 5:
				var t: float = float(j) / 4.0
				sections.append({"center": off + lean * (t * h), "radius": r * (1.0 + 0.35 * t * t), "v_scale": 1.0, "w_scale": 1.0, "color": Color.WHITE})
			var m: ArrayTetraMesh4D = Loft.build(sections, 3, 10, true, false, true, 1, false)
			if m != null:
				parts.append(m)
		return parts
	_colony(nm, make, base, mouth, at, 0.6 * size)


## An anemone: a short column and a ring of tentacles reaching up and out.
func _anemone(nm: String, at: Vector4, base: Color, tip: Color, size: float = 1.0) -> void:
	var make := func() -> Array: return _anemone_parts(size)
	_colony(nm, make, base, tip, at, 0.35 * size)


func _anemone_parts(size: float) -> Array:
	var parts: Array = []
	var col: Array = []
	for j in 4:
		var t: float = float(j) / 3.0
		col.append({"center": Vector4(0.0, t * 0.22 * size, 0.0, 0.0), "radius": (0.12 + 0.04 * t) * size, "v_scale": 1.0, "w_scale": 1.0, "color": Color.WHITE})
	parts.append(Loft.build(col, 3, 12, true, false, true, 1, false))
	for k in 22:
		var a: float = TAU * float(k) / 22.0
		var out := Vector4(cos(a), 0.0, sin(a), 0.35 * sin(a * 3.0))
		var p0 := Vector4(0.0, 0.22, 0.0, 0.0) * size + out * 0.11 * size
		var sections: Array = []
		for j in 4:
			var t: float = float(j) / 3.0
			sections.append({"center": p0 + (out * (t * 0.16) + Vector4(0.0, t * 0.2 - t * t * 0.06, 0.0, 0.0)) * size, "radius": 0.022 * (1.0 - 0.5 * t) * size, "v_scale": 1.0, "w_scale": 1.0, "color": Color.WHITE})
		var m: ArrayTetraMesh4D = Loft.build(sections, 3, 6, true, false, true, 0, false)
		if m != null:
			parts.append(m)
	return parts


# -- meshes and materials ------------------------------------------------------------------------------------------

## A colony: its parts (`make_parts`, run only when it is not baked yet) merged into one mesh, coloured
## from `base` at its foot to `tip` at its top.
func _colony(nm: String, make_parts: Callable, base: Color, tip: Color, at: Vector4, reach: float) -> void:
	var build := func() -> ArrayTetraMesh4D:
		var mm: ArrayTetraMesh4D = _merge(make_parts.call())
		if mm == null:
			return null
		var pos: PackedVector4Array = mm.get_vertex_positions()
		var lo: float = INF
		var hi: float = -INF
		for p in pos:
			lo = minf(lo, p.y)
			hi = maxf(hi, p.y)
		var tex := PackedVector3Array()
		tex.resize(pos.size())
		for i in pos.size():
			tex[i] = Vector3(0.5, clampf((pos[i].y - lo) / maxf(hi - lo, 0.001), 0.02, 0.98), 0.5)
		mm.set_texture_map_values(tex)
		mm.set_simplex_cell_texture_map_indices(mm.get_simplex_cell_vertex_indices())
		mm.calculate_boundary_normals(false)
		mm.set_meta("reef_height", hi - lo)
		return mm
	var m: ArrayTetraMesh4D = _cached(nm, build)
	if m == null:
		return
	_place(nm, m, _ramp(base, tip), at)
	obstacles.append([at + Vector4(0.0, float(m.get_meta("reef_height", 1.0)) * 0.5, 0.0, 0.0), reach])


## A piece's mesh: the baked one under life/baked/ if there is one, else built by `build` (its random
## numbers seeded by its name) and baked for next time.
func _cached(nm: String, build: Callable) -> ArrayTetraMesh4D:
	var path: String = BAKED + "reef_%s_%s.res" % [BAKE_VERSION, nm]
	if ResourceLoader.exists(path):
		var r: Resource = load(path)
		if r is ArrayTetraMesh4D:
			baked_hits += 1
			return r
	_brng.seed = hash(nm)
	var m: ArrayTetraMesh4D = build.call()
	if m != null:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BAKED))
		ResourceSaver.save(m, path)
	return m


func _merge(parts: Array) -> ArrayTetraMesh4D:
	var pos := PackedVector4Array()
	var cells := PackedInt32Array()
	for m in parts:
		if m == null:
			continue
		var mp: PackedVector4Array = (m as ArrayTetraMesh4D).get_vertex_positions()
		var mc: PackedInt32Array = (m as ArrayTetraMesh4D).get_simplex_cell_vertex_indices()
		var off: int = pos.size()
		pos.append_array(mp)
		for c in mc:
			cells.append(c + off)
	if pos.is_empty():
		return null
	var out := ArrayTetraMesh4D.new()
	out.set_vertex_positions(pos)
	out.set_simplex_cell_vertex_indices(cells)
	return out


## Texture coordinates from where each vertex is in the stone's box, for the speckle.
func _by_position(m: ArrayTetraMesh4D, ext: Vector4) -> void:
	var pos: PackedVector4Array = m.get_vertex_positions()
	var tex := PackedVector3Array()
	tex.resize(pos.size())
	for i in pos.size():
		var p: Vector4 = pos[i]
		tex[i] = Vector3(clampf(p.x / ext.x * 0.5 + 0.5 + p.w * 0.2, 0.0, 1.0), clampf(p.y / ext.y * 0.5 + 0.5, 0.0, 1.0), clampf(p.z / ext.z * 0.5 + 0.5, 0.0, 1.0))
	m.set_texture_map_values(tex)
	m.set_simplex_cell_texture_map_indices(m.get_simplex_cell_vertex_indices())


func _place(nm: String, mesh: ArrayTetraMesh4D, mat: TetraMaterial4D, at: Vector4) -> void:
	var mi := MeshInstance4D.new()
	mi.name = nm
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	add_child(mi)
	tets += mesh.get_simplex_cell_vertex_indices().size() / 4


static func _tex3d(w: int, h: int, d: int, colour: Callable) -> ImageTexture3D:
	var slices: Array[Image] = []
	for k in d:
		var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
		for j in h:
			for i in w:
				img.set_pixel(i, j, colour.call(i, j, k))
		slices.append(img)
	var tex := ImageTexture3D.new()
	tex.create(Image.FORMAT_RGBA8, w, h, d, false, slices)
	return tex


func _ramp(base: Color, tip: Color) -> TetraMaterial4D:
	var m := TetraMaterial4D.new()
	m.set("albedo_source", 3)
	m.set("albedo_texture_3d", _tex3d(2, 32, 1, func(_i: int, j: int, _k: int) -> Color:
		var t: float = float(j) / 31.0
		return base.lerp(tip, smoothstep(0.35, 1.0, t))))
	return m


## Granite: a base grey with dark and light flecks, through all three texture axes.
func _speckle(base: Color, dark: Color, light: Color) -> TetraMaterial4D:
	var n := FastNoiseLite.new()
	n.seed = _rng.randi()
	n.frequency = 0.35
	var m := TetraMaterial4D.new()
	m.set("albedo_source", 3)
	m.set("albedo_texture_3d", _tex3d(24, 24, 24, func(i: int, j: int, k: int) -> Color:
		var v: float = n.get_noise_3d(float(i), float(j), float(k))
		var fleck: float = n.get_noise_3d(float(i) * 3.1 + 40.0, float(j) * 3.1, float(k) * 3.1)
		var c: Color = base.lerp(dark, clampf(-v * 1.4, 0.0, 0.6)).lerp(light, clampf(v * 1.2, 0.0, 0.5))
		if fleck > 0.55:
			c = dark
		elif fleck < -0.6:
			c = light
		return c))
	return m
