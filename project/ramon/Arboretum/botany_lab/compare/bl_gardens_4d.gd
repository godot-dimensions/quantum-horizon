extends Node4D

## BOTANY LAB, THE SECOND ROOM, round 4: THE TWO GARDENS' DRESSING (follow_up/arboretum.md section 10, steps
## 35-46; Ramon: "The smooth side ... should feel like a small, attractive botanical landscape"; "The blocky
## side should provide a clear contrast ... without losing the deliberately cubic aesthetic"; "Think in terms
## of stronger environmental composition, guiding the eye, small scenic details, and a slightly dreamy
## quality"; "Reuse existing flowers, trees, grass, and ivy instead of creating new systems").
##
## THE SMOOTH GARDEN (on its turntable, so it turns through W with the land):
##   the light oaks and bushes (carried/oak/bl_oak_lite_4d.gd over the Arboretum's oak_lite and bush bakes)
##   in groups beside the grove's oaks, a clearing kept in front; the flower collection (flora/) in small
##   clusters, never rows; rock groups (flora/rock_4d.gd) half sunk where the eye should stop; the pen's
##   grass (carried/grass/bl_grass_4d.gd) on the green, its ground baked from the land's own chunks on a
##   worker thread once the land is meshed (the grass is drawn in the world's frame, so it hides while the
##   land is turned); ivy on its blue wall only, framing its page; butterflies over it.
## THE BLOCKY GARDEN: the same cells as the land (botany/voxel_tree_builder.gd mesh()): two blocky
##   conifers and a third, stacked tiers of needles on a bark column; two birches, a white trunk marked
##   dark and a pale crown; low bushes and grey rock groups. No grass and no flowers: its ground already
##   says grass.
## The spots are composed, not scattered: tall things to the back and the outer edge, low things near the
## walkway, an open middle on each side so the land itself shows.
##
## `room` is the compare room (bl_compare_4d.gd). Every loop is capped. NO class_name (engine_gotchas.md).

const Voxel := preload("res://ramon/Arboretum/botany/voxel_tree_builder.gd")
const LabGrid := preload("res://ramon/Arboretum/botany_lab/carried/LabKit/lab_grid.gd")
const Flower := preload("res://ramon/Arboretum/botany_lab/flora/flower_4d.gd")
const FloraSpecies := preload("res://ramon/Arboretum/botany_lab/flora/flora_species.gd")
const Rock := preload("res://ramon/Arboretum/botany_lab/flora/rock_4d.gd")
const Butterflies := preload("res://ramon/Arboretum/botany_lab/flora/butterflies_4d.gd")
const Sprigs := preload("res://ramon/Arboretum/botany_lab/flora/flora_sprigs_4d.gd")
const Air := preload("res://ramon/Arboretum/botany_lab/flora/flora_air_4d.gd")
const OakLite := preload("res://ramon/Arboretum/botany_lab/carried/oak/bl_oak_lite_4d.gd")
const Grass := preload("res://ramon/Arboretum/botany_lab/carried/grass/bl_grass_4d.gd")

## The smooth garden, in the land's own coordinates (from its display's middle; x as the smooth half has it).
const SMOOTH_TREES := [["oak_lite2", Vector2(5.6, 4.6), 6.2], ["oak_lite2", Vector2(-1.2, -7.6), 5.6], ["oak_lite3", Vector2(4.8, -1.4), 4.4]]
const SMOOTH_BUSHES := [["bush_1", Vector2(3.4, 6.0), 1.7], ["bush_2", Vector2(4.6, 7.4), 1.3], ["bush_3", Vector2(-4.4, 2.2), 1.1],
	["bush_1", Vector2(1.2, -9.4), 1.5], ["bush_2", Vector2(5.0, -10.2), 1.2], ["bush_3", Vector2(-2.6, 9.6), 1.0], ["bush_2", Vector2(5.8, 0.4), 1.4]]
## Flower clusters: [centre, radius, species...].
const SMOOTH_FLOWERS := [[Vector2(-4.6, 9.2), 0.9, "iris", "iris", "poppy", "daisy"], [Vector2(-1.4, 5.0), 0.8, "poppy", "poppy", "daisy", "tulip"],
	[Vector2(-4.8, -1.0), 0.7, "foxglove", "foxglove", "bluebell"], [Vector2(2.2, 1.8), 0.9, "allium", "allium", "daisy", "dandelion"],
	[Vector2(-3.8, -6.0), 0.8, "lily", "tulip", "tulip", "bluebell"], [Vector2(1.0, -4.4), 0.7, "rose", "dandelion", "daisy"],
	[Vector2(-5.2, 4.2), 0.6, "iris", "bluebell", "dandelion"]]
## Rock groups: [centre, count, size].
const SMOOTH_ROCKS := [[Vector2(-3.0, 7.2), 3, 0.9], [Vector2(4.2, -4.8), 4, 1.1], [Vector2(-5.6, -3.4), 2, 0.6]]
## The blocky garden, in its land's coordinates.
const BLOCKY_CONIFERS := [Vector2(-5.0, -0.4), Vector2(-4.2, -3.0), Vector2(-5.4, 2.2)]
const BLOCKY_BIRCHES := [Vector2(1.6, 9.4), Vector2(-0.6, 10.6)]
const BLOCKY_BUSHES := [Vector2(4.6, 6.6), Vector2(4.2, -1.4), Vector2(-2.2, 5.6), Vector2(3.6, -9.6)]
const BLOCKY_ROCKS := [[Vector2(4.4, 3.0), 3], [Vector2(-4.4, 8.4), 2], [Vector2(-1.0, -6.2), 2]]
## The blocky props' cells (smaller than the land's, as the voxel trees' are).
const CELL := 0.25

var room: Node4D
var flies: Node4D
var grass: Node4D
var ivy: Node4D
var stats: Dictionary = {}
var _flowers: Array = []
var _rng := RandomNumberGenerator.new()
var _grass_task: int = -1
var _grass_out := PackedFloat32Array()
var _grass_plan: Dictionary = {}


func build() -> void:
	_rng.seed = 2024
	var t0: int = Time.get_ticks_usec()
	var air := Node.new()
	air.name = "Air"
	air.set_script(Air)
	add_child(air)
	_smooth()
	var t1: int = Time.get_ticks_usec()
	_blocky()
	stats["ms"] = {"smooth": (t1 - t0) / 1000.0, "blocky": (Time.get_ticks_usec() - t1) / 1000.0}


# -- the smooth garden -----------------------------------------------------------------------------------

## The smooth land's surface at (x, z) of its own (the grass skin's top over the soil).
func _smooth_y(p: Vector2) -> float:
	return float(room.call("height_at", -p.x, p.y, 0.0)) + 0.12


func _smooth() -> void:
	var table: Node4D = room.get("_turn_smooth")
	var holder := Node4D.new()
	holder.name = "SmoothGarden"
	table.add_child(holder)
	var tets: int = 0
	for tr in SMOOTH_TREES + SMOOTH_BUSHES:
		var at: Vector2 = tr[1]
		var o := Node4D.new()
		o.name = "%s_%d" % [tr[0], holder.get_child_count()]
		o.set_script(OakLite)
		o.set("bake", String(tr[0]))
		o.set("height", float(tr[2]))
		o.set("snap_to_ground", false)
		o.set("leaf_seed", 5 + holder.get_child_count())
		o.position = Vector4(at.x, _smooth_y(at) - 0.08, at.y, 0.0)
		o.basis = Basis4D.from_zx(_rng.randf() * TAU)
		holder.add_child(o)
	var mat: TetraMaterial4D = Flower.material()
	for cl in SMOOTH_FLOWERS:
		var c: Vector2 = cl[0]
		var r: float = cl[1]
		var keys: Array = cl.slice(2)
		for k in mini(keys.size() * 2, 12):
			var key: String = keys[k % keys.size()]
			var a: float = _rng.randf() * TAU
			var p: Vector2 = c + Vector2(cos(a), sin(a)) * r * sqrt(_rng.randf())
			var mesh: ArrayTetraMesh4D = Flower.mesh(key, k % Flower.VARIANTS)
			if mesh == null:
				continue
			var mi := MeshInstance4D.new()
			mi.name = "%s_%d" % [key, _flowers.size()]
			mi.mesh = mesh
			mi.material_override = mat
			var s: float = float(FloraSpecies.DISPLAY.get(key, 1.4)) * _rng.randf_range(1.0, 1.25)
			var b: Projection = Basis4D.from_zx(_rng.randf() * TAU)
			mi.basis = Projection(b.x * s, b.y * s, b.z * s, b.w * s)
			mi.position = Vector4(p.x, _smooth_y(p) - 0.04, p.y, 0.0)
			holder.add_child(mi)
			_flowers.append(mi)
			tets += mesh.get_simplex_cell_vertex_indices().size() / 4
	for rg in SMOOTH_ROCKS:
		var c: Vector2 = rg[0]
		for k in mini(int(rg[1]), 6):
			var a: float = _rng.randf() * TAU
			var p: Vector2 = c + Vector2(cos(a), sin(a)) * float(rg[2]) * (0.4 + 0.6 * _rng.randf())
			var sz: float = float(rg[2]) * (1.0 if k == 0 else _rng.randf_range(0.35, 0.7))
			var m: ArrayTetraMesh4D = Rock.mesh(7 + k + int(c.x * 10.0))
			var mi := MeshInstance4D.new()
			mi.name = "Rock_%d" % holder.get_child_count()
			mi.mesh = m
			mi.material_override = Rock.material(k + int(c.y))
			var b: Projection = Basis4D.from_zx(_rng.randf() * TAU)
			mi.basis = Projection(b.x * sz, b.y * sz, b.z * sz, b.w * sz)
			# Half sunk, as a field stone sits.
			mi.position = Vector4(p.x, _smooth_y(p) - sz * 0.22, p.y, 0.0)
			holder.add_child(mi)
			tets += m.get_simplex_cell_vertex_indices().size() / 4 if m != null else 0
	stats["smooth"] = {"trees": SMOOTH_TREES.size(), "bushes": SMOOTH_BUSHES.size(), "flowers": _flowers.size(), "tets": tets}
	_ivy()
	_butterflies()


## The flowers' landing points (world), as they stand now (the land turns them with it).
func perch_points() -> PackedVector4Array:
	var out := PackedVector4Array()
	for mi in _flowers:
		var m: MeshInstance4D = mi
		if not is_instance_valid(m) or not m.is_inside_tree():
			continue
		for q in (m.mesh as Resource).get_meta("perches", PackedVector4Array()):
			out.append(m.global_position + m.global_basis * (q as Vector4))
	return out


func _butterflies() -> void:
	var at: Vector2 = room.get("right_at")
	var size: Vector2 = room.get("display_size")
	flies = Node4D.new()
	flies.name = "Butterflies"
	flies.set_script(Butterflies)
	flies.set("count", 14)
	flies.set("size", 1.7)
	flies.set("bounds_lo", Vector3(at.x - size.x * 0.5, 1.2, at.y - size.y * 0.5 + 3.0))
	flies.set("bounds_hi", Vector3(at.x + size.x * 0.5 - 0.3, 6.0, at.y + size.y * 0.5))
	flies.set("air_margin", 0.8)
	flies.set("perch_source", perch_points)
	flies.set("wind", room.get_node_or_null("Wind"))
	add_child(flies)


## Ivy on the smooth half's blue wall only (Ramon: "Add ivy only on the smooth side ... Preserve the blue
## wall as a recognizable part of the room's visual language"): the flower room's ivy (the pen's sprig trick),
## climbing in a few places from the bank's top, thicker at the wall's ends, kept off its page.
func _ivy() -> void:
	ivy = Node4D.new()
	ivy.name = "Ivy"
	ivy.set_script(Sprigs)
	ivy.set("w_radius", 0.75)
	ivy.set("wind", room.get_node_or_null("Wind"))
	add_child(ivy)
	var hall: Node4D = room.get_node_or_null("Hall") as Node4D
	var hs: Vector3 = hall.get("size") if hall != null else Vector3(30.2, 12, 26.4)
	var hz: float = hall.position.z if hall != null else 0.0
	var wall_x: float = hs.x * 0.5 - 0.02
	var bank: float = float(room.get("slab_height"))
	# Climbing points along the wall (z), how high each may reach; none under the page (z -9 to 5, above 5 m).
	var starts: Array = []
	for k in 10:
		starts.append([lerpf(hz + hs.z * 0.5 - 0.6, hz + hs.z * 0.5 - 3.6, _rng.randf()), 6.5])
	for k in 9:
		starts.append([lerpf(hz - hs.z * 0.5 + 0.4, hz - hs.z * 0.5 + 3.2, _rng.randf()), 7.5])
	for k in 8:
		starts.append([lerpf(-8.5, 4.5, _rng.randf()), 3.4])
	var n_leaves: int = 0
	for st in starts:
		var z: float = st[0]
		var top: float = st[1]
		var y: float = bank + 0.05
		var dir := Vector2(_rng.randf_range(-0.4, 0.4), 1.0).normalized()
		var home: float = _rng.randf_range(-1.2, 1.2)
		for k in 90:
			dir = (dir + Vector2(_rng.randf_range(-0.35, 0.35), 0.05)).normalized()
			z += dir.x * 0.07
			y += dir.y * 0.07
			if y > top:
				break
			var at := Vector3(wall_x, y, z)
			ivy.call("add", Sprigs.STEM, at, Vector3(0.0, dir.y, dir.x), Vector3.LEFT, 0.075, _rng.randf(), 0.0, home + _rng.randf_range(-0.1, 0.1))
			if k % 2 == 0:
				var sideways: float = 1.0 if (k / 2) % 2 == 0 else -1.0
				var along: Vector3 = Vector3(0.0, _rng.randf_range(-0.6, 0.2), sideways * 0.8).normalized()
				var face: Vector3 = (Vector3.LEFT + Vector3.UP * 0.3 + Vector3(0, 0, _rng.randf_range(-0.3, 0.3))).normalized()
				ivy.call("add", Sprigs.LEAF, at + Vector3.LEFT * 0.01, along, face, _rng.randf_range(0.06, 0.1), _rng.randf(), 0.6, home + _rng.randf_range(-0.15, 0.15))
				n_leaves += 1
	ivy.call("commit")
	stats["ivy_leaves"] = n_leaves


# -- the grass on the smooth land (once it is meshed) ------------------------------------------------------

## The land meshed (the room's "ready"): its chunks' tetrahedra baked into the grass's height grid on a
## worker thread, then the grass made.
func start_grass() -> void:
	var world: Node4D = room.get("_world")
	if world == null or _grass_task >= 0 or grass != null:
		return
	var at: Vector2 = room.get("right_at")
	var size: Vector2 = room.get("display_size")
	var w_reach: float = 1.2
	var side: float = size.y + 0.5
	var cells: int = int(ceil(side / Grass.CELL))
	var rect := Vector4(at.x - size.x * 0.5 - 0.25, at.y - size.y * 0.5 - 0.25, Grass.CELL, float(cells))
	var wl := Vector3(-w_reach - 1.0, Grass.DW, (w_reach + 1.0) * 2.0 / Grass.DW + 1.0)
	var boxes: Array = [[Vector3(rect.x, rect.y, -w_reach - 1.0), Vector3(rect.x + size.x + 0.5, rect.y + side, w_reach + 1.0)]]
	var jobs: Array = []
	for m in world.find_children("*", "MeshInstance4D", true, false):
		var mi := m as MeshInstance4D
		var tm := mi.mesh as TetraMesh4D
		if tm == null:
			continue
		var am = tm if tm is ArrayTetraMesh4D else tm.call("to_array_tetra_mesh")
		jobs.append([mi.global_position, mi.global_basis, tm.get_vertex_positions(), tm.get_simplex_cell_vertex_indices(),
			am.call("get_texture_map_values"), am.call("get_simplex_cell_texture_map_indices")])
	if jobs.is_empty():
		return
	var bank: float = float(room.get("slab_height")) + 0.2
	_grass_plan = {"rect": rect, "wl": wl, "w_reach": w_reach, "ground_y": bank + 1.4, "t0": Time.get_ticks_usec()}
	_grass_task = WorkerThreadPool.add_task(func() -> void: _grass_out = Grass.bake_heights(jobs, rect, wl, boxes, bank, true), false, "smooth garden grass")


func _process(_delta: float) -> void:
	if _grass_task >= 0 and WorkerThreadPool.is_task_completed(_grass_task):
		WorkerThreadPool.wait_for_task_completion(_grass_task)
		_grass_task = -1
		grass = Node4D.new()
		grass.name = "Grass"
		grass.set_script(Grass)
		grass.set("coverage", 1.0)
		grass.set("w_reach", float(_grass_plan["w_reach"]))
		grass.set("height_m", 0.42)
		grass.set("width_scale", 1.8)
		grass.set("radius", 30.0)
		grass.set("band_radii", [8.0, 18.0])
		add_child(grass)
		grass.set("player", room.get("player"))
		grass.call("start", _grass_out, _grass_plan["rect"], _grass_plan["wl"], float(_grass_plan["ground_y"]))
		stats["grass_ms"] = float(Time.get_ticks_usec() - int(_grass_plan["t0"])) / 1000.0
		_grass_out = PackedFloat32Array()
	# The grass stands in the world's frame, the land on its turntable: shown only while the land is level.
	if grass != null:
		var level: bool = (room.get("turn_basis") as Projection) == Projection.IDENTITY
		if grass.visible != level:
			grass.visible = level
			grass.set("enabled", level)


func grass_ready() -> bool:
	return grass != null


# -- the blocky garden -----------------------------------------------------------------------------------

## The blocky land's top at (x, z) of its own (the top of its column of 0.5 m cells).
func _blocky_y(p: Vector2) -> float:
	var c: float = float(room.get("block_cell"))
	return maxf(1.0, round(float(room.call("height_at", p.x, p.y, 0.0)) / c)) * c


func _blocky() -> void:
	var table: Node4D = room.get("_turn_blocky")
	var holder := Node4D.new()
	holder.name = "BlockyGarden"
	table.add_child(holder)
	LabGrid.set_swatch("blocky_needles", Color(0.17, 0.33, 0.2), Color(0.13, 0.27, 0.16), Color(0.15, 0.3, 0.18), 0.5)
	LabGrid.set_swatch("blocky_bark", Color(0.36, 0.26, 0.18), Color(0.29, 0.2, 0.13), Color(0.33, 0.23, 0.16), 0.5)
	LabGrid.set_swatch("blocky_birch", Color(0.9, 0.89, 0.85), Color(0.8, 0.79, 0.75), Color(0.86, 0.85, 0.81), 0.4)
	LabGrid.set_swatch("blocky_birch_mark", Color(0.16, 0.15, 0.14), Color(0.12, 0.11, 0.1), Color(0.14, 0.13, 0.12), 0.4)
	LabGrid.set_swatch("blocky_birch_leaf", Color(0.6, 0.7, 0.28), Color(0.5, 0.6, 0.22), Color(0.56, 0.66, 0.26), 0.5)
	LabGrid.set_swatch("blocky_bush", Color(0.3, 0.5, 0.2), Color(0.24, 0.42, 0.16), Color(0.28, 0.46, 0.18), 0.5)
	LabGrid.set_swatch("blocky_rock", Color(0.52, 0.51, 0.49), Color(0.42, 0.41, 0.4), Color(0.48, 0.47, 0.45), 0.5)
	var tets: int = 0
	for i in BLOCKY_CONIFERS.size():
		tets += _prop(holder, "Conifer%d" % i, BLOCKY_CONIFERS[i], _conifer(16 + i * 3, 4 + i % 2))
	for i in BLOCKY_BIRCHES.size():
		tets += _prop(holder, "Birch%d" % i, BLOCKY_BIRCHES[i], _birch(14 + i * 2, 4))
	for i in BLOCKY_BUSHES.size():
		tets += _prop(holder, "Bush%d" % i, BLOCKY_BUSHES[i], _blob(2 + i % 2, 0.7, "blocky_bush", 0))
	for rg in BLOCKY_ROCKS:
		var c: Vector2 = rg[0]
		for k in mini(int(rg[1]), 4):
			var p: Vector2 = c + (Vector2(_rng.randf_range(-0.8, 0.8), _rng.randf_range(-0.8, 0.8)) if k > 0 else Vector2.ZERO)
			tets += _prop(holder, "Rock%d" % holder.get_child_count(), p, _blob(2 if k == 0 else 1, 0.55, "blocky_rock", -1))
	stats["blocky"] = {"conifers": BLOCKY_CONIFERS.size(), "birches": BLOCKY_BIRCHES.size(), "bushes": BLOCKY_BUSHES.size(), "tets": tets}


## A prop's cells ({swatch: {Vector4i: Vector3}}) on the blocky land at `at`: one mesh a swatch, the faces
## between swatches kept (each part is meshed against all the prop's cells).
func _prop(holder: Node4D, nm: String, at: Vector2, parts: Dictionary) -> int:
	var all: Dictionary = {}
	for sw in parts:
		all.merge(parts[sw])
	var node := Node4D.new()
	node.name = nm
	# The cells' feet on the land's top, their middle on the spot.
	node.position = Vector4(at.x - CELL * 0.5, _blocky_y(at), at.y - CELL * 0.5, -CELL * 0.5)
	holder.add_child(node)
	var tets: int = 0
	for sw in parts:
		var mesh: ArrayTetraMesh4D = Voxel.mesh(all, CELL, parts[sw])
		var mi := MeshInstance4D.new()
		mi.name = String(sw)
		mi.mesh = mesh
		mi.material_override = LabGrid.material(String(sw), Vector4(3, 6, 3, 3), node.position)
		node.add_child(mi)
		tets += mesh.get_simplex_cell_vertex_indices().size() / 4
	return tets


## A blocky conifer: a bark column `trunk` cells tall, tiers of needles from a third of the way up, each a
## square ring through x, z and W narrowing to a point.
func _conifer(trunk: int, base_r: int) -> Dictionary:
	var bark: Dictionary = {}
	var needles: Dictionary = {}
	for y in mini(trunk, 40):
		bark[Vector4i(0, y, 0, 0)] = Vector3.ZERO
	var start: int = trunk / 4
	var tiers: int = trunk - start + 2
	for k in mini(tiers, 40):
		var y: int = start + k
		var r: int = int(round(lerpf(float(base_r), 0.0, float(k) / float(maxi(tiers - 1, 1)))))
		# Each tier steps in a little at its top (the conifer's layered skirt).
		if k % 3 == 2:
			r = maxi(r - 1, 0)
		for ix in range(-r, r + 1):
			for iz in range(-r, r + 1):
				for iw in range(-r, r + 1):
					if absi(ix) + absi(iz) + absi(iw) > r + r / 2:
						continue
					var key := Vector4i(ix, y, iz, iw)
					if not bark.has(key):
						needles[key] = Vector3.ZERO
	return {"blocky_bark": bark, "blocky_needles": needles}


## A blocky birch: a white trunk a cell wide, dark marks on it every few cells, a pale round crown.
func _birch(trunk: int, crown_r: int) -> Dictionary:
	var white: Dictionary = {}
	var marks: Dictionary = {}
	var leaf: Dictionary = {}
	for y in mini(trunk, 40):
		if y % 3 == 1 and _rng.randf() < 0.7:
			marks[Vector4i(0, y, 0, 0)] = Vector3.ZERO
		else:
			white[Vector4i(0, y, 0, 0)] = Vector3.ZERO
	var cy: int = trunk
	for ix in range(-crown_r, crown_r + 1):
		for iy in range(-crown_r, crown_r + 2):
			for iz in range(-crown_r, crown_r + 1):
				for iw in range(-crown_r, crown_r + 1):
					var d: float = Vector4(ix, float(iy) * 0.8, iz, iw).length()
					if d <= float(crown_r) + 0.3 and _rng.randf() < 0.92:
						leaf[Vector4i(ix, cy + iy, iz, iw)] = Vector3.ZERO
	return {"blocky_birch": white, "blocky_birch_mark": marks, "blocky_birch_leaf": leaf}


## A rounded blob of cells (a bush, or a rock squashed by `squash`), `r` cells across; `sink` cells below the
## ground (a rock sits half in it).
func _blob(r: int, squash: float, swatch: String, sink: int) -> Dictionary:
	var cells: Dictionary = {}
	var sq: float = clampf(squash, 0.2, 1.0)
	# A ball `r` cells across, squashed to `sq` of its height, its bottom on the ground (then `sink` down).
	var hy: int = int(ceil(float(r) * sq))
	for ix in range(-r, r + 1):
		for iy in range(-hy, hy + 1):
			for iz in range(-r, r + 1):
				for iw in range(-r, r + 1):
					var d: float = Vector4(ix, float(iy) / sq, iz, iw).length()
					if d <= float(r) + 0.35:
						cells[Vector4i(ix, iy + hy + sink, iz, iw)] = Vector3.ZERO
	return {swatch: cells}
