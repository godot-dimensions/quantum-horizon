extends RefCounted

## THE DEV LOOK'S BLOCKOUTS (PenLayout/PLAN_DEV_LOOK.md part C): one or two plain shapes per landmark,
## in the landmark's own frame, so they stand, turn and move with it. Ramon, 6 Oct: "the blockouts
## should be even a bit simpler"; "rock tower could be big cylinder or just 3 blocks"; "the cave ...
## a wedge shape with a door".
##
## Keyed by the landmark's script (BUILDERS). A landmark with no entry is drawn in clay instead: its
## own shapes, flat blue (pen_look_4d.gd). Shapes are convex polytopes cut by planes and baked by the
## cut-stone builder (terrain/cut_stone_4d.gd), or boxes.
##
## To give a landmark a blockout: add its script's file name to BUILDERS and write a builder that
## returns {"blue": [...shapes], "red": [...], "door": [...]}, each shape {"planes": [...]} or
## {"box": size, "at": centre}, in the landmark's frame.
##
## NO class_name (engine_gotchas.md).

const CutStone := preload("res://ramon/chickenpen/terrain/cut_stone_4d.gd")
const TerrainBake := preload("res://ramon/chickenpen/terrain/terrain_bake_4d.gd")
const CaveHill := preload("res://ramon/chickenpen/terrain/pen_cave_hill_4d.gd")

## Landmark script file -> builder.
const BUILDERS := {
	"watchstone_4d.gd": "_tower",
	"pen_cave_hill_4d.gd": "_cave",
	"pen_shed_4d.gd": "_shed",
	"pen_research_camp_4d.gd": "_camp",
	"pen_rune_range_4d.gd": "_range",
	"pen_oak_4d.gd": "_oak",
	"pen_ruin_wall_4d.gd": "_from_colliders",
	"pen_rock_pile_4d.gd": "one_box",
}

## Animals and characters (pen_look_4d.gd never touches them, and no blockout measures them): a node
## up the chain with one of these in its script's or scene's file name, or a body that moves.
const CHARACTER := ["block_avatar", "block_walker", "loft_rig", "loft_ball", "strider", "chicken", "pen_cat", "pen_crow", "wolf",
	"nike", "flock", "heron", "chipmunk", "owl_4d", "balloon", "lookout_wren", "pen_trym_4d", "pen_professor_4d", "range_master",
	"lofted_girl", "researcher", "hawk", "mithra"]

## The Watchstone: its height and plateau (watchstone_4d.gd TOP), the crag's W depth (its spec).
const TOWER_TOP := 13.65
const TOWER_R := 4.8
const TOWER_W := 6.0
## Three blocks instead: [width, from y, to y, depth], stepping in like its courses.
const TOWER_BLOCKS := [[11.0, 0.0, 5.0, 10.0], [9.0, 5.0, 10.0, 8.4], [7.6, 10.0, TOWER_TOP, 7.6]]
## The cave: the wedge's height at its front (the arch and a lintel over it), how far it runs back
## and how far either side of the door, in W either side of the mouth.
const CAVE_FRONT := 6.5
const CAVE_DEPTH := 14.0
const CAVE_SIDE := 2.5
const CAVE_W := 3.0
## The camp's two tents (pen_research_camp_4d.gd TENT_L, TENT_R: front pole, back pole).
const TENTS := [[Vector2(-4.15, -3.03), Vector2(-1.97, -4.58)], [Vector2(4.31, -3.09), Vector2(2.12, -4.68)]]


## The shapes for [param root], or {} when it has no builder. [param three_blocks]: the Watchstone as
## three blocks rather than a cylinder.
static func shapes_for(root: Node4D, three_blocks: bool) -> Dictionary:
	var script: Script = root.get_script() as Script
	if script == null:
		return {}
	var builder: String = BUILDERS.get(script.resource_path.get_file(), "")
	if builder == "":
		return {}
	match builder:
		"_tower":
			return _tower(three_blocks)
		"_cave":
			return _cave()
		"_shed":
			return _shed(root)
		"_camp":
			return _camp()
		"_range":
			return _range()
		"_oak":
			return _oak(root)
		"_from_colliders":
			return _from_colliders(root)
		"one_box":
			return one_box(root)
	return {}


## Whether [param root] has a blockout.
static func has_blockout(root: Node) -> bool:
	var script: Script = root.get_script() as Script
	return script != null and BUILDERS.has(script.resource_path.get_file())


## [param shapes] baked into one mesh per colour: {"blue": ArrayTetraMesh4D, ...}, in the root's frame.
static func bake(shapes: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for colour in shapes:
		var mesh := ArrayTetraMesh4D.new()
		for s in shapes[colour]:
			if (s as Dictionary).has("unit"):
				# A shape built once and stretched where it stands (a hundred oaks: Ramon's layout B).
				mesh.merge_with(_unit_mesh(String(s["unit"])), s.get("at", Vector4.ZERO), s.get("basis", Projection.IDENTITY))
			elif (s as Dictionary).has("planes"):
				var b := TerrainBake.Builder.new()
				CutStone.bake_into(b, s["planes"], func(_n: Vector4, _c: Vector4) -> Color: return Color(0.5, 0.5, 0.5))
				mesh.merge_with(TerrainBake.mesh_of(b, false), s.get("at", Vector4.ZERO), s.get("basis", Projection.IDENTITY))
			else:
				var box := BoxTetraMesh4D.new()
				box.size = s["box"]
				mesh.merge_with(box.to_array_tetra_mesh(), s["at"], s.get("basis", Projection.IDENTITY))
		if not mesh.get_simplex_cell_vertex_indices().is_empty():
			out[colour] = mesh
	return out


## The unit shapes "unit" names, built the first time they are asked for.
static var _units: Dictionary = {}


static func _unit_mesh(key: String) -> ArrayTetraMesh4D:
	if not _units.has(key):
		var planes: Array = cell24_up() if key == "cell24_up" else cell24(Vector4.ONE)
		var b := TerrainBake.Builder.new()
		CutStone.bake_into(b, planes, func(_n: Vector4, _c: Vector4) -> Color: return Color(0.5, 0.5, 0.5))
		_units[key] = TerrainBake.mesh_of(b, false)
	return _units[key]


# --- The landmarks -------------------------------------------------------------------------------

static func _tower(three_blocks: bool) -> Dictionary:
	if three_blocks:
		var blocks: Array = []
		for k in TOWER_BLOCKS:
			blocks.append({"box": Vector4(k[0], k[2] - k[1], k[3], TOWER_W), "at": Vector4(0, (k[1] + k[2]) * 0.5, 0, 0)})
		return {"blue": blocks}
	return {"blue": [{"planes": cylinder(TOWER_R, TOWER_TOP, TOWER_W * 0.5)}]}


## A wedge with its door: full height at the front, where the arch opens (the hill's MOUTH, facing +z
## in its own frame), down to the ground behind.
static func _cave() -> Dictionary:
	var m: Vector4 = CaveHill.MOUTH
	var hx: float = CaveHill.ARCH_HALF_WIDTH + CAVE_SIDE
	var hw: float = CaveHill.ARCH_HALF_WIDTH + CAVE_W
	return {
		"blue": [{"planes": wedge(Vector4(m.x, 0, 0, m.w), hx, hw, m.z - CAVE_DEPTH, m.z, CAVE_FRONT)}],
		"door": [{"box": Vector4(CaveHill.ARCH_HALF_WIDTH * 2.0, CaveHill.ARCH_HEIGHT, 0.5, CaveHill.ARCH_HALF_WIDTH * 2.0),
			"at": m + Vector4(0, CaveHill.ARCH_HEIGHT * 0.5, 0.1, 0)}],
	}


## Trym's shed: a box and a gable roof over the bounds of its own art.
static func _shed(root: Node4D) -> Dictionary:
	var b: Array = art_bounds(root)
	if b.is_empty():
		return {}
	var lo: Vector4 = b[0]
	var hi: Vector4 = b[1]
	var c := (lo + hi) * 0.5
	var wall: float = hi.y * 0.6
	return {"blue": [
		{"box": Vector4(hi.x - lo.x, wall, hi.z - lo.z, hi.w - lo.w), "at": Vector4(c.x, wall * 0.5, c.z, c.w)},
		{"planes": gable(Vector4(c.x, wall, c.z, c.w), (hi.x - lo.x) * 0.5 + 0.25, (hi.z - lo.z) * 0.5 + 0.25, hi.y - wall, (hi.w - lo.w) * 0.5)},
	]}


## The researchers' camp: its two tents, and the fire in red.
static func _camp() -> Dictionary:
	var tents: Array = []
	for t in TENTS:
		var u: Vector2 = (t[1] - t[0]).normalized()
		var mid: Vector2 = (t[0] + t[1]) * 0.5
		var length: float = (t[1] - t[0]).length() + 0.6
		var turn := Projection(Vector4(u.y, 0, -u.x, 0), Vector4(0, 1, 0, 0), Vector4(u.x, 0, u.y, 0), Vector4(0, 0, 0, 1))
		tents.append({"planes": gable(Vector4.ZERO, 1.35, length * 0.5, 2.1, 0.9), "at": Vector4(mid.x, 0, mid.y, 0), "basis": turn})
	return {"blue": tents, "red": [{"box": Vector4(1.0, 0.5, 1.0, 1.0), "at": Vector4(0, 0.25, 0, 0)}]}


## The rune range: its yard, the backstop the targets hang on, and the two fences
## (pen_rune_range_4d.gd SAND_X/Z, BOARDS, FENCE_L/R).
static func _range() -> Dictionary:
	return {"blue": [
		{"box": Vector4(4.4, 0.12, 10.7, 2.4), "at": Vector4(0.2, 0.06, -4.95, 0)},
		{"box": Vector4(5.9, 2.2, 0.5, 2.4), "at": Vector4(0.25, 1.1, -10.75, 0)},
		{"box": Vector4(0.15, 1.0, 7.4, 1.4), "at": Vector4(-2.6, 0.5, -6.3, 0)},
		{"box": Vector4(0.15, 1.0, 7.4, 1.4), "at": Vector4(3.08, 0.5, -6.3, 0)},
	]}


## The oak: a trunk and a crown over the bounds of its wood (its leaves are switched off in the dev
## look by pen_look_4d.gd).
static func _oak(root: Node4D) -> Dictionary:
	var b: Array = art_bounds(root)
	if b.is_empty():
		return {}
	var lo: Vector4 = b[0]
	var hi: Vector4 = b[1]
	var c := (lo + hi) * 0.5
	var height: float = hi.y - lo.y
	var stretch := func(r: Vector4) -> Projection:
		return Projection(Vector4(r.x, 0, 0, 0), Vector4(0, r.y, 0, 0), Vector4(0, 0, r.z, 0), Vector4(0, 0, 0, r.w))
	# Round, not boxes (Ramon, 6 Oct: "in the dev look they should be round. 24 cells or something"): a
	# crown as wide as the tree's own, a 24-cell stretched to it, a corner up ("arguably a 24 cell looks
	# better rotated ... upward"); the trunk a thin square box ("why ... are the tree trunks so thick. just
	# make then thinner square boxes"). A bush is its crown on the ground.
	#
	# TALLER, AS TALL AS THE LEAVES (Ramon, 7 Oct: "SCALE BLUE TREEBLOCKS a bit larger upward so they match
	# the artlook more"): sized from the wood alone (the leaves are off by the time the dev look measures),
	# the crowns stopped at the wood's top, under the art's. The oak hands over its leaves' box (pen_oak_4d.gd
	# crown_box); its top is the crown's top. Its width is not used: the light oaks are sparse, and a crown
	# filling the leaves' whole reach was twice the art's mass (frames treecmp, 7 Oct), so as wide as before,
	# from the wood, and from 40% of the way up, the trunk showing under it.
	var leafy: Array = root.call("crown_box") if root.has_method("crown_box") else []
	if leafy.size() == 2:
		var top: float = (leafy[1] as Vector4).y
		if String(root.get("bake")).begins_with("bush"):
			var low := Vector4((hi.x - lo.x) * 0.45, (top - lo.y) * 0.5, (hi.z - lo.z) * 0.45, (hi.w - lo.w) * 0.45)
			return {"blue": [{"unit": "cell24_up", "basis": stretch.call(low), "at": Vector4(c.x, lo.y + low.y, c.z, c.w)}]}
		var bottom: float = lo.y + height * 0.4
		var tall := Vector4((hi.x - lo.x) * 0.42, (top - bottom) * 0.5, (hi.z - lo.z) * 0.42, (hi.w - lo.w) * 0.42)
		var tw_leafy: float = maxf(0.18, height * 0.05)
		var trunk_to: float = bottom + tall.y * 0.4
		# As deep in W as the art's trunk (WTools' W Exploder makes trunks one depth to the branches, the
		# "trunk slab", so a turned slice keeps them under their crowns; the block does the same).
		var trunk_w: float = maxf(tw_leafy, float(root.get_meta(&"trunk_w_half", 0.0)) * 2.0)
		return {"blue": [
			{"box": Vector4(tw_leafy, trunk_to - lo.y, tw_leafy, trunk_w), "at": Vector4(c.x, (lo.y + trunk_to) * 0.5, c.z, c.w)},
			{"unit": "cell24_up", "basis": stretch.call(tall), "at": Vector4(c.x, (bottom + top) * 0.5, c.z, c.w)},
		]}
	if String(root.get("bake")).begins_with("bush"):
		var bush := Vector4((hi.x - lo.x) * 0.45, height * 0.5, (hi.z - lo.z) * 0.45, (hi.w - lo.w) * 0.45)
		return {"blue": [{"unit": "cell24_up", "basis": stretch.call(bush), "at": Vector4(c.x, lo.y + height * 0.5, c.z, c.w)}]}
	var trunk_top: float = lo.y + height * 0.45
	var crown := Vector4((hi.x - lo.x) * 0.42, (hi.y - trunk_top) * 0.5, (hi.z - lo.z) * 0.42, (hi.w - lo.w) * 0.42)
	var tw: float = maxf(0.18, height * 0.05)
	return {"blue": [
		{"box": Vector4(tw, trunk_top + 0.4, tw, tw), "at": Vector4(c.x, (trunk_top + 0.4) * 0.5, c.z, c.w)},
		{"unit": "cell24_up", "basis": stretch.call(crown), "at": Vector4(c.x, (trunk_top + hi.y) * 0.5, c.z, c.w)},
	]}


## The landmark's own box colliders, as they stand (the dry stone wall: its stretches and the arch).
static func _from_colliders(root: Node4D) -> Dictionary:
	var inv: Projection = root.global_basis.inverse()
	var boxes: Array = []
	for node in root.find_children("*", "CollisionShape4D", true, false):
		var cs := node as CollisionShape4D
		if not (cs.shape is BoxShape4D) or cs.get_parent() is Area4D:
			continue
		boxes.append({"box": (cs.shape as BoxShape4D).size, "at": inv * (cs.global_position - root.global_position), "basis": inv * cs.global_basis})
	return {"blue": boxes} if not boxes.is_empty() else one_box(root)


## One box over the landmark's own art.
static func one_box(root: Node4D) -> Dictionary:
	var b: Array = art_bounds(root)
	if b.is_empty():
		return {}
	return {"blue": [{"box": (b[1] as Vector4) - (b[0] as Vector4), "at": ((b[0] as Vector4) + (b[1] as Vector4)) * 0.5}]}


# --- Bounds and shapes ---------------------------------------------------------------------------

## The bounds of [param root]'s own drawn meshes (visible, not a character's), in its frame: [lo, hi],
## or [] when there are none.
static func art_bounds(root: Node4D) -> Array:
	var inv: Projection = root.global_basis.inverse()
	var lo := Vector4(INF, INF, INF, INF)
	var hi := -lo
	var nodes: Array = [root] if root is MeshInstance4D else []
	nodes.append_array(root.find_children("*", "MeshInstance4D", true, false))
	var found: bool = false
	for node in nodes:
		var mi := node as MeshInstance4D
		# Hidden by a W Optimiser while its copy shows (w_hidden): drawn art all the same.
		if mi.mesh == null or (not mi.visible and not mi.has_meta(&"w_hidden")) or mi.has_meta(&"_look_own") or is_character(mi, root):
			continue
		var r: PackedVector4Array = mi.get_rect_bounds_local()
		if r[1].length() < 0.01:
			continue
		for i in 16:
			var corner := Vector4(r[1].x * (i & 1), r[1].y * ((i >> 1) & 1), r[1].z * ((i >> 2) & 1), r[1].w * ((i >> 3) & 1))
			var p: Vector4 = inv * (mi.global_position + mi.global_basis * (r[0] + corner) - root.global_position)
			lo = Vector4(minf(lo.x, p.x), minf(lo.y, p.y), minf(lo.z, p.z), minf(lo.w, p.w))
			hi = Vector4(maxf(hi.x, p.x), maxf(hi.y, p.y), maxf(hi.z, p.z), maxf(hi.w, p.w))
			found = true
	return [lo, hi] if found else []


## Whether [param node] belongs to an animal or a character, looking up as far as [param stop].
static func is_character(node: Node, stop: Node) -> bool:
	var n: Node = node
	while n != null:
		if n is CharacterBody4D or n is RigidBody4D:
			return true
		var tags: String = n.scene_file_path.get_file()
		if n.get_script() != null:
			tags += " " + (n.get_script() as Script).resource_path.get_file()
		for c in CHARACTER:
			if tags.contains(c):
				return true
		if n == stop:
			return false
		n = n.get_parent()
	return false


## An upright cylinder of radius [param r], [param h] tall from the ground, [param hw] either side in W
## (twenty sides). Planes are [normal, d], inside where normal . p <= d.
static func cylinder(r: float, h: float, hw: float) -> Array:
	var planes: Array = [[Vector4(0, 1, 0, 0), h], [Vector4(0, -1, 0, 0), 0.0], [Vector4(0, 0, 0, 1), hw], [Vector4(0, 0, 0, -1), hw]]
	for k in 20:
		var a: float = TAU * float(k) / 20.0
		planes.append([Vector4(cos(a), 0, sin(a), 0), r])
	return planes


## THE 24-CELL: the regular 4D polytope with 24 octahedral cells, the roundest of the simple ones; its
## cells face the four axes both ways (8) and the sixteen diagonals (+-1, +-1, +-1, +-1). Stretched to
## [param radii] (half its size along x, y, z and W), its middle at the origin.
static func cell24(radii: Vector4) -> Array:
	var normals: Array = []
	for axis in 4:
		for s in [-1.0, 1.0]:
			var n := Vector4.ZERO
			n[axis] = s
			normals.append(n)
	for k in 16:
		normals.append(Vector4(1.0 if (k & 1) != 0 else -1.0, 1.0 if (k & 2) != 0 else -1.0, 1.0 if (k & 4) != 0 else -1.0,
			1.0 if (k & 8) != 0 else -1.0) * 0.5)
	return _stretched(normals, radii)


## The 24-cell a corner up: turned an eighth of a turn from x into y, then pressed back into the unit box
## (its corners reached the square root of two), so a stretch by a crown's half sizes fits that crown.
static func cell24_up() -> Array:
	var normals: Array = []
	for n: Vector4 in _cell24_normals():
		var c: float = cos(PI * 0.25)
		var s: float = sin(PI * 0.25)
		normals.append(Vector4(n.x * c - n.y * s, n.x * s + n.y * c, n.z, n.w))
	return _stretched(normals, Vector4(1.0 / sqrt(2.0), 1.0 / sqrt(2.0), 1.0, 1.0))


static func _cell24_normals() -> Array:
	var normals: Array = []
	for axis in 4:
		for s in [-1.0, 1.0]:
			var n := Vector4.ZERO
			n[axis] = s
			normals.append(n)
	for k in 16:
		normals.append(Vector4(1.0 if (k & 1) != 0 else -1.0, 1.0 if (k & 2) != 0 else -1.0, 1.0 if (k & 4) != 0 else -1.0,
			1.0 if (k & 8) != 0 else -1.0) * 0.5)
	return normals


## A post round in x, z AND W ([param r] across, [param h] tall from the ground): eighteen sides, the
## three axes of the ground and the twelve diagonals between them, so it reads round from a turned slice.
static func round_post(r: float, h: float) -> Array:
	var ground: Array = [Vector4(1, 0, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1)]
	var normals: Array = []
	for i in 3:
		normals.append(ground[i])
		normals.append(-ground[i])
		for j in range(i + 1, 3):
			for s in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
				normals.append((ground[i] * s.x + ground[j] * s.y).normalized())
	var planes: Array = _stretched(normals, Vector4(r, 1.0, r, r))
	planes.append([Vector4(0, 1, 0, 0), h])
	planes.append([Vector4(0, -1, 0, 0), 0.0])
	return planes


## [param normals] as planes, each at the distance of its own length from the middle (unit normals: 1),
## the shape then stretched by [param radii] along x, y, z and W, exactly (each normal re-normalised).
static func _stretched(normals: Array, radii: Vector4) -> Array:
	var planes: Array = []
	for n: Vector4 in normals:
		var u: Vector4 = n / n.length_squared()
		var m := Vector4(u.x / radii.x, u.y / radii.y, u.z / radii.z, u.w / radii.w)
		var l: float = m.length()
		planes.append([m / l, 1.0 / l])
	return planes


## A wedge: [param h] tall at its front (z = [param zf]), down to the ground at its back (z =
## [param zb]); [param hx] either side of [param c].x, [param hw] either side of [param c].w.
static func wedge(c: Vector4, hx: float, hw: float, zb: float, zf: float, h: float) -> Array:
	var k: float = h / (zf - zb)
	var n := Vector4(0, 1, -k, 0)
	var nl: float = n.length()
	return [[Vector4(1, 0, 0, 0), c.x + hx], [Vector4(-1, 0, 0, 0), -(c.x - hx)], [Vector4(0, 0, 0, 1), c.w + hw], [Vector4(0, 0, 0, -1), -(c.w - hw)],
		[Vector4(0, -1, 0, 0), 0.0], [Vector4(0, 0, 1, 0), zf], [n / nl, -k * zb / nl]]


## A gable (a roof, or a tent): its ridge along z, [param h] over [param c].y; [param hx] either side
## in x, [param hz] in z, [param hw] in W.
static func gable(c: Vector4, hx: float, hz: float, h: float, hw: float) -> Array:
	var s: float = h / hx
	var n1 := Vector4(s, 1, 0, 0)
	var n2 := Vector4(-s, 1, 0, 0)
	return [[Vector4(0, -1, 0, 0), -c.y], [Vector4(0, 0, 1, 0), c.z + hz], [Vector4(0, 0, -1, 0), -(c.z - hz)],
		[Vector4(0, 0, 0, 1), c.w + hw], [Vector4(0, 0, 0, -1), -(c.w - hw)],
		[n1 / n1.length(), (c.y + h + s * c.x) / n1.length()], [n2 / n2.length(), (c.y + h - s * c.x) / n2.length()]]
