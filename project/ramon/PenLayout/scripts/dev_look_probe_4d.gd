extends Node

## PROBE, nothing saved (6 Oct, Ramon: "toggle the entire pen scene, to an R&D scene. meaning.. ground
## is white.. path arrows active.. mountains white.. landmarks all blue or all red ... instantly
## swappable with the press of a button while keep the pen scene working in all its operational
## power"). Two dev looks built live in the running pen, for the case study
## (PenLayout/DEV_LOOK_STUDY.md):
##   clay    every landmark's own meshes recoloured flat (blue; the things you use red), the ground
##           and the mountains white, the paths' dev look (white strips, blue arrows).
##   blocks  as clay, but the landmarks' meshes taken off (kept, to put back) and boxes drawn in their
##           place from their own colliders (their bounds where they have none).
##   boxes   as blocks, but each piece of art's own box (its bounds, turned with it) instead of colliders.
##   simple  (6 Oct, Ramon: "the blockouts should be even a bit simpler"; "rock tower could be big
##           cylinder or just 3 blocks"; "the cave ... a wedge shape with a door") one or two plain
##           shapes per landmark: the Watchstone a cylinder, the cave a wedge with its door, Trym's
##           shed a box with a roof, the camp two tents and its fire, the range its yard, backstop
##           and fences; anything else one box, squared to the landmark itself.
##   simple3 as simple, the Watchstone three stacked blocks.
## Every look but art also swaps the sky and light for the Creation Lab's bright mood ("the sky should
## get replaced too in the end upon toggle").
##   art     everything as it was.
## It NEVER changes `visible`: the rune stone, the laptops, the photo subjects, the tutor's markers
## and the slice dial's outlines all read is_visible_in_tree(), and hiding a node would switch them
## off. A mesh taken off its node, or a material laid over it, changes only the picture.
##
## Spawned by _capture_pen_runner.gd with helper=<this file>; driven by "call" steps.

const BLUE := Color(0.13, 0.40, 0.86)
const RED := Color(0.86, 0.24, 0.20)
const WHITE := Color(0.93, 0.935, 0.94)
const MOUNTAIN_WHITE := Color(0.86, 0.87, 0.89)
const LabGrid := preload("res://ramon/CreationLab/LabKit/lab_grid.gd")
const CutStone := preload("res://ramon/chickenpen/terrain/cut_stone_4d.gd")
const TerrainBake := preload("res://ramon/chickenpen/terrain/terrain_bake_4d.gd")
const CaveHill := preload("res://ramon/chickenpen/terrain/pen_cave_hill_4d.gd")
const DOOR := Color(0.05, 0.08, 0.16)
## The Creation Lab's bright mood (CreationLab/LabKit/lab_room_4d.gd MOODS).
const LAB_SKY := {"top": Color(0.66, 0.74, 0.84), "horizon": Color(0.93, 0.94, 0.95), "bottom": Color(0.84, 0.84, 0.83),
	"ambient": Color(0.50, 0.53, 0.59), "ambient_sky": 0.25, "exposure": 1.0, "white": 6.0,
	"key_color": Color(1.0, 0.965, 0.91), "key_energy": 1.75, "key_elevation": 50.0, "key_azimuth": -35.0,
	"fill_color": Color(0.80, 0.87, 1.0), "fill_energy": 0.32, "fill_elevation": 25.0, "fill_azimuth": 145.0}
## Landmarks with a shape of their own in the simple look, by their script.
const TEMPLATE := {"watchstone_4d.gd": "tower", "pen_cave_hill_4d.gd": "cave", "pen_shed_4d.gd": "shed",
	"pen_research_camp_4d.gd": "camp", "pen_rune_range_4d.gd": "range"}
## Units that hold several landmarks: each child is its own.
const CONTAINERS := ["Scenery", "LookoutSite"]
## Characters and creatures keep their own look: any node up the chain with one of these in its
## script or scene file, or a body that moves.
const CHARACTER := ["avatar", "walker", "loft_", "pen_cat", "pen_crow", "wolf", "nike", "chicken", "flock", "wren", "pen_trym_4d",
	"professor_4d", "range_master", "heron", "chipmunk", "strider", "mithra", "balloon", "starling", "researcher", "hawk"]
## What you use: drawn red.
const USED := ["rune_stone", "laptop", "pickup", "pickaxe", "journal_book", "invitation", "pen_stones"]
## The terrain, drawn white: by node name under World.
const TERRAIN := ["Hills", "WestHill", "TowerHill"]

var look: String = "art"
var _world: Node4D
var _arts: Array = []          # [mesh node, "landmark" | "used", unit (World child)]
var _mats: Dictionary = {}     # node -> its material_override
var _meshes: Dictionary = {}   # node -> its mesh, while taken off
var _blocks: Node4D
var _ground_mat: Material4D
var _blue := TetraMaterial4D.new()
var _red := TetraMaterial4D.new()
var _white := TetraMaterial4D.new()
var _door := TetraMaterial4D.new()
var _sky_saved: Dictionary = {}


func _ready() -> void:
	name = "DevProbe"
	_blue.albedo_color = BLUE
	_red.albedo_color = RED
	_white.albedo_color = MOUNTAIN_WHITE
	_door.albedo_color = DOOR
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	if OS.get_cmdline_user_args().has("cold=blocks"):
		_cold.call_deferred()


## Before the first frame is drawn: straight into blocks, so the art has never been drawn (the case
## where the pen opens in the dev look), for the first switch's cost.
func _cold() -> void:
	await get_tree().process_frame
	look_to("blocks")


func _world_node() -> Node4D:
	if _world == null:
		_world = get_parent().get_node("World") as Node4D
	return _world


## Every mesh under World that is landmark art: not a character's, not the ground, the terrain, the
## paths or this probe's own blocks.
func _classify() -> void:
	_arts.clear()
	var world: Node4D = _world_node()
	for node in world.find_children("*", "MeshInstance4D", true, false):
		var mi := node as MeshInstance4D
		var unit: Node = mi
		while unit.get_parent() != world:
			unit = unit.get_parent()
		if unit.name in ["Ground", "Paths", "Grass", "Flock"] or unit.name in TERRAIN or unit == _blocks:
			continue
		var kind: String = _kind(mi, world)
		if kind != "":
			_arts.append([mi, kind, unit])


func _kind(mi: Node, world: Node) -> String:
	var n: Node = mi
	var used: bool = false
	while n != null and n != world:
		if n is CharacterBody4D or n is RigidBody4D:
			return ""
		var tags: String = ""
		if n.get_script() != null:
			tags += (n.get_script() as Script).resource_path.get_file()
		tags += " " + n.scene_file_path.get_file()
		for c in CHARACTER:
			if tags.contains(c):
				return ""
		for u in USED:
			if tags.contains(u):
				used = true
		n = n.get_parent()
	return "used" if used else "landmark"


## Switches the look; prints how long the switch took and the inventory behind it.
func look_to(mode: String) -> String:
	var started: int = Time.get_ticks_usec()
	_restore()
	_classify()
	var paths: Node = get_parent().get_node_or_null("Systems/Paths")
	var grass: Node = _world_node().get_node_or_null("Grass")
	var ground := _world_node().get_node_or_null("Ground/GroundMesh") as MeshInstance4D
	if mode == "art":
		_sky(false)
		if paths != null:
			paths.call("set_dev", false)
		if grass != null:
			grass.set("ground_paint", true)
	else:
		_sky(true)
		if paths != null:
			paths.call("set_dev", true)
		if grass != null:
			grass.set("ground_paint", false)
		if ground != null:
			_ground_mat = ground.material_override
			LabGrid.set_swatch("pen_dev_floor", WHITE, Color(0.86, 0.87, 0.89), Color(0.92, 0.925, 0.93), 1.0)
			var size: Vector4 = (ground.mesh as BoxTetraMesh4D).size if ground.mesh is BoxTetraMesh4D else Vector4(120, 2, 120, 120)
			ground.material_override = LabGrid.material("pen_dev_floor", size, ground.global_position)
		for t in TERRAIN:
			var hill := _world_node().get_node_or_null(t) as MeshInstance4D
			if hill != null:
				_mats[hill] = hill.material_override
				hill.material_override = _white
		var units: Dictionary = {}
		for a in _arts:
			var mi: MeshInstance4D = a[0]
			_mats[mi] = mi.material_override
			mi.material_override = _red if a[1] == "used" else _blue
			if (mode == "blocks" or mode == "boxes") and a[1] == "landmark":
				units[a[2]] = true
		if mode == "blocks":
			_build_blocks(units)
		elif mode == "boxes":
			_build_boxes()
		elif mode.begins_with("simple"):
			_build_simple(mode == "simple3")
		if mode == "blocks" or mode == "boxes" or mode.begins_with("simple"):
			for a in _arts:
				if a[1] == "landmark":
					var mi: MeshInstance4D = a[0]
					_meshes[mi] = mi.mesh
					mi.mesh = null
	look = mode
	var took: float = (Time.get_ticks_usec() - started) / 1000.0
	var line: String = "LOOK %s: %.1f ms to switch, %d art meshes (%d used), %d units" % [mode, took, _arts.size(),
		_arts.filter(func(a) -> bool: return a[1] == "used").size(), _units().size()]
	print(line)
	return line


func _units() -> Dictionary:
	var out: Dictionary = {}
	for a in _arts:
		out[a[2]] = true
	return out


func _restore() -> void:
	for mi in _meshes:
		if is_instance_valid(mi):
			(mi as MeshInstance4D).mesh = _meshes[mi]
	_meshes.clear()
	for mi in _mats:
		if is_instance_valid(mi):
			(mi as MeshInstance4D).material_override = _mats[mi]
	_mats.clear()
	var ground := _world_node().get_node_or_null("Ground/GroundMesh") as MeshInstance4D
	if ground != null and _ground_mat != null:
		ground.material_override = _ground_mat
		_ground_mat = null
	if _blocks != null:
		_blocks.queue_free()
		_blocks = null


## Each landmark's blockout: its own colliders as solid boxes (the space you walk on and bump into),
## merged into one mesh per landmark. Triggers (Area4D) are left out. A landmark with no collider at
## all gets its bounds as one box.
func _build_blocks(units: Dictionary) -> void:
	_blocks = Node4D.new()
	_blocks.name = "DevBlocks"
	_world_node().add_child(_blocks)
	var report: Array = []
	for unit in units:
		var merged := ArrayTetraMesh4D.new()
		var shapes: int = 0
		var skipped: int = 0
		for node in (unit as Node).find_children("*", "CollisionShape4D", true, false):
			var cs := node as CollisionShape4D
			if cs.shape == null or cs.get_parent() is Area4D or _kind(cs, _world_node()) == "":
				continue
			var piece: TetraMesh4D = cs.shape.to_tetra_mesh()
			if piece == null:
				skipped += 1
				continue
			merged.merge_with(piece.to_array_tetra_mesh() if not (piece is ArrayTetraMesh4D) else piece, cs.global_position, cs.global_basis)
			shapes += 1
		if shapes == 0:
			var lo := Vector4(INF, INF, INF, INF)
			var hi := -lo
			for a in _arts:
				if a[2] == unit and a[1] == "landmark" and (a[0] as MeshInstance4D).mesh != null:
					var r: PackedVector4Array = (a[0] as MeshInstance4D).get_rect_bounds_global()
					lo = Vector4(minf(lo.x, r[0].x), minf(lo.y, r[0].y), minf(lo.z, r[0].z), minf(lo.w, r[0].w))
					hi = Vector4(maxf(hi.x, r[0].x + r[1].x), maxf(hi.y, r[0].y + r[1].y), maxf(hi.z, r[0].z + r[1].z), maxf(hi.w, r[0].w + r[1].w))
			if lo.x < INF:
				var box := BoxTetraMesh4D.new()
				box.size = hi - lo
				merged.merge_with(box.to_array_tetra_mesh(), (lo + hi) * 0.5, Projection.IDENTITY)
		var mi := MeshInstance4D.new()
		mi.name = "Block_" + String((unit as Node).name)
		mi.mesh = merged
		mi.material_override = _blue
		_blocks.add_child(mi)
		report.append("%s %d boxes%s%s" % [(unit as Node).name, shapes, " (bounds)" if shapes == 0 else "", (", %d shapes with no mesh" % skipped) if skipped > 0 else ""])
	print("BLOCKS: " + ", ".join(report))


## The pen's sky and light swapped for the Creation Lab's bright mood, or put back.
func _sky(dev: bool) -> void:
	var world: Node4D = _world_node()
	var env := world.get_node_or_null("Environment") as WorldEnvironment4D
	var sun := world.get_node_or_null("Sun") as DirectionalLight4D
	var fill := world.get_node_or_null("SkyFill") as DirectionalLight4D
	if env == null or sun == null or fill == null:
		return
	if not dev:
		if _sky_saved.is_empty():
			return
		for key in _sky_saved:
			var parts: PackedStringArray = String(key).split(":")
			world.get_node(parts[0]).set(parts[1], _sky_saved[key])
		_sky_saved.clear()
		return
	if _sky_saved.is_empty():
		for prop in ["sky_material", "cloud_material", "ambient_light_color", "ambient_light_sky_contribution", "tonemap_exposure", "tonemap_white"]:
			_sky_saved["Environment:" + prop] = env.get(prop)
		for light in ["Sun", "SkyFill"]:
			for prop in ["light_color", "light_energy", "elevation_degrees", "azimuth_degrees"]:
				_sky_saved[light + ":" + prop] = world.get_node(light).get(prop)
	var sky := GradientSkyMaterial4D.new()
	sky.top_color = LAB_SKY["top"]
	sky.horizon_color = LAB_SKY["horizon"]
	sky.bottom_color = LAB_SKY["bottom"]
	env.sky_material = sky
	env.cloud_material = null
	env.ambient_light_color = LAB_SKY["ambient"]
	env.ambient_light_sky_contribution = LAB_SKY["ambient_sky"]
	env.tonemap_exposure = LAB_SKY["exposure"]
	env.tonemap_white = LAB_SKY["white"]
	sun.light_color = LAB_SKY["key_color"]
	sun.light_energy = LAB_SKY["key_energy"]
	sun.set("elevation_degrees", LAB_SKY["key_elevation"])
	sun.set("azimuth_degrees", LAB_SKY["key_azimuth"])
	fill.light_color = LAB_SKY["fill_color"]
	fill.light_energy = LAB_SKY["fill_energy"]
	fill.set("elevation_degrees", LAB_SKY["fill_elevation"])
	fill.set("azimuth_degrees", LAB_SKY["fill_azimuth"])


## The simple look: one or two plain shapes per landmark (see the header), in each landmark's own
## frame, so they turn and move with it. [param three_blocks]: the Watchstone as three blocks.
func _build_simple(three_blocks: bool) -> void:
	_blocks = Node4D.new()
	_blocks.name = "DevBlocks"
	_world_node().add_child(_blocks)
	var world: Node4D = _world_node()
	var roots: Dictionary = {}
	for a in _arts:
		if a[1] == "landmark":
			roots[_landmark_root(a[0], world)] = true
	var blue := ArrayTetraMesh4D.new()
	var red := ArrayTetraMesh4D.new()
	var dark := ArrayTetraMesh4D.new()
	var report: Array = []
	for root in roots:
		var r := root as Node4D
		var kind: String = _template(r)
		var at: Vector4 = r.global_position
		var b: Projection = r.global_basis
		match kind:
			"tower":
				if three_blocks:
					for k in [[11.0, 0.0, 5.0, 10.0], [9.0, 5.0, 10.0, 8.4], [7.6, 10.0, 13.65, 7.6]]:
						_box_into(blue, Vector4(k[0], k[2] - k[1], k[3], 6.0), Vector4(0, (k[1] + k[2]) * 0.5, 0, 0), at, b)
				else:
					_poly_into(blue, _cylinder(4.8, 13.65, 3.0), at, b)
			"cave":
				var lo_hi: Array = _bounds_in(r)
				var lo: Vector4 = lo_hi[0]
				var hi: Vector4 = lo_hi[1]
				var zf: float = CaveHill.MOUTH.z
				var hx: float = (hi.x - lo.x) * 0.5
				var cx: float = (hi.x + lo.x) * 0.5
				_poly_into(blue, _wedge(Vector4(cx, 0, 0, (hi.w + lo.w) * 0.5), hx, (hi.w - lo.w) * 0.5, lo.z, zf, hi.y), at, b)
				_box_into(dark, Vector4(CaveHill.ARCH_HALF_WIDTH * 2.0, CaveHill.ARCH_HEIGHT, 0.6, CaveHill.ARCH_HALF_WIDTH * 2.0),
					CaveHill.MOUTH + Vector4(0, CaveHill.ARCH_HEIGHT * 0.5, 0.15, 0), at, b)
			"shed":
				var lo_hi: Array = _bounds_in(r)
				var lo: Vector4 = lo_hi[0]
				var hi: Vector4 = lo_hi[1]
				var wall: float = hi.y * 0.62
				_box_into(blue, Vector4(hi.x - lo.x, wall, hi.z - lo.z, hi.w - lo.w), Vector4((hi.x + lo.x) * 0.5, wall * 0.5, (hi.z + lo.z) * 0.5, (hi.w + lo.w) * 0.5), at, b)
				_poly_into(blue, _gable(Vector4((hi.x + lo.x) * 0.5, wall, (hi.z + lo.z) * 0.5, (hi.w + lo.w) * 0.5), (hi.x - lo.x) * 0.5 + 0.2,
					(hi.z - lo.z) * 0.5 + 0.2, hi.y - wall, (hi.w - lo.w) * 0.5), at, b)
			"camp":
				var tents: Array = [[Vector2(-4.15, -3.03), Vector2(-1.97, -4.58)], [Vector2(4.31, -3.09), Vector2(2.12, -4.68)]]
				for t in tents:
					var u: Vector2 = (t[1] - t[0]).normalized()
					var mid: Vector2 = (t[0] + t[1]) * 0.5
					var length: float = (t[1] - t[0]).length() + 0.6
					var turn := Projection(Vector4(u.y, 0, -u.x, 0), Vector4(0, 1, 0, 0), Vector4(u.x, 0, u.y, 0), Vector4(0, 0, 0, 1))
					_poly_into(blue, _gable(Vector4.ZERO, 1.35, length * 0.5, 2.1, 0.9), at + b * Vector4(mid.x, 0, mid.y, 0), b * turn)
				_box_into(red, Vector4(1.0, 0.5, 1.0, 1.0), Vector4(0, 0.25, 0, 0), at, b)
			"range":
				_box_into(blue, Vector4(4.4, 0.12, 10.7, 2.4), Vector4(0.2, 0.06, -4.95, 0), at, b)
				_box_into(blue, Vector4(5.9, 2.2, 0.5, 2.4), Vector4(0.25, 1.1, -10.75, 0), at, b)
				for x in [-2.6, 3.08]:
					_box_into(blue, Vector4(0.15, 1.0, 7.4, 1.4), Vector4(x, 0.5, -6.3, 0), at, b)
			_:
				var lo_hi: Array = _bounds_in(r)
				if lo_hi.is_empty():
					continue
				var lo: Vector4 = lo_hi[0]
				var hi: Vector4 = lo_hi[1]
				_box_into(blue, hi - lo, (hi + lo) * 0.5, at, b)
		report.append("%s%s" % [r.name, (" (" + kind + ")") if kind != "" else ""])
	for pair in [[blue, _blue, "Blue"], [red, _red, "Red"], [dark, _door, "Door"]]:
		if (pair[0] as ArrayTetraMesh4D).get_simplex_cell_vertex_indices().is_empty():
			continue
		var mi := MeshInstance4D.new()
		mi.name = pair[2]
		mi.mesh = pair[0]
		mi.material_override = pair[1]
		_blocks.add_child(mi)
	print("SIMPLE: %d landmarks: %s" % [report.size(), ", ".join(report)])


## The node a piece of art belongs to as a landmark: the one with a shape of its own, else the unit
## (or, in a unit that holds several, the unit's child).
func _landmark_root(mi: Node, world: Node) -> Node:
	var n: Node = mi
	var chain: Array = []
	while n != world:
		chain.append(n)
		n = n.get_parent()
	for node in chain:
		if _template(node) != "":
			return node
	var unit: Node = chain[-1]
	if String(unit.name) in CONTAINERS and chain.size() >= 2:
		return chain[-2]
	return unit


func _template(node: Node) -> String:
	if node.get_script() == null:
		return ""
	return TEMPLATE.get((node.get_script() as Script).resource_path.get_file(), "")


## The bounds of a landmark in its own frame: of its colliders where it has them (not a character's,
## not a trigger), else of its art. [lo, hi], or [] if it has neither.
func _bounds_in(root: Node4D) -> Array:
	var inv: Projection = root.global_basis.inverse()
	var lo := Vector4(INF, INF, INF, INF)
	var hi := -lo
	var found: bool = false
	for node in root.find_children("*", "CollisionShape4D", true, false):
		var cs := node as CollisionShape4D
		if not (cs.shape is BoxShape4D) or cs.get_parent() is Area4D or _kind(cs, _world_node()) == "":
			continue
		var half: Vector4 = (cs.shape as BoxShape4D).size * 0.5
		for corner in _corners(half):
			var p: Vector4 = inv * (cs.global_position + cs.global_basis * corner - root.global_position)
			lo = Vector4(minf(lo.x, p.x), minf(lo.y, p.y), minf(lo.z, p.z), minf(lo.w, p.w))
			hi = Vector4(maxf(hi.x, p.x), maxf(hi.y, p.y), maxf(hi.z, p.z), maxf(hi.w, p.w))
			found = true
	if not found:
		var nodes: Array = [root] if root is MeshInstance4D else []
		nodes.append_array(root.find_children("*", "MeshInstance4D", true, false))
		for node in nodes:
			var mi := node as MeshInstance4D
			if mi.mesh == null or not mi.is_visible_in_tree() or _kind(mi, _world_node()) != "landmark":
				continue
			var r: PackedVector4Array = mi.get_rect_bounds_local()
			if r[1].length() < 0.01:
				continue
			for corner in _corners(r[1] * 0.5):
				var p: Vector4 = inv * (mi.global_position + mi.global_basis * (r[0] + r[1] * 0.5 + corner) - root.global_position)
				lo = Vector4(minf(lo.x, p.x), minf(lo.y, p.y), minf(lo.z, p.z), minf(lo.w, p.w))
				hi = Vector4(maxf(hi.x, p.x), maxf(hi.y, p.y), maxf(hi.z, p.z), maxf(hi.w, p.w))
				found = true
	return [lo, hi] if found else []


static func _corners(half: Vector4) -> Array:
	var out: Array = []
	for i in 16:
		out.append(Vector4(half.x * (1 if i & 1 else -1), half.y * (1 if i & 2 else -1), half.z * (1 if i & 4 else -1), half.w * (1 if i & 8 else -1)))
	return out


func _box_into(into: ArrayTetraMesh4D, size: Vector4, centre: Vector4, at: Vector4, b: Projection) -> void:
	var box := BoxTetraMesh4D.new()
	box.size = size
	into.merge_with(box.to_array_tetra_mesh(), at + b * centre, b)


## A convex shape from planes ([normal, d]: inside where normal . p <= d), baked by the cut-stone
## builder and merged in at [param at], turned by [param b].
func _poly_into(into: ArrayTetraMesh4D, planes: Array, at: Vector4, b: Projection) -> void:
	var builder := TerrainBake.Builder.new()
	CutStone.bake_into(builder, planes, func(_n: Vector4, _c: Vector4) -> Color: return Color(0.5, 0.5, 0.5))
	into.merge_with(TerrainBake.mesh_of(builder, false), at, b)


## An upright cylinder of [param r], [param h] tall from the ground, [param hw] deep either side in W
## (twenty sides).
static func _cylinder(r: float, h: float, hw: float) -> Array:
	var planes: Array = [[Vector4(0, 1, 0, 0), h], [Vector4(0, -1, 0, 0), 0.0], [Vector4(0, 0, 0, 1), hw], [Vector4(0, 0, 0, -1), hw]]
	for k in 20:
		var a: float = TAU * float(k) / 20.0
		planes.append([Vector4(cos(a), 0, sin(a), 0), r])
	return planes


## A wedge: full height [param h] at its front (z = [param zf]) sloping to the ground at its back
## (z = [param zb]), [param hx] either side of [param c].x, [param hw] either side in W.
static func _wedge(c: Vector4, hx: float, hw: float, zb: float, zf: float, h: float) -> Array:
	var k: float = h / (zf - zb)
	var n: Vector4 = Vector4(0, 1, -k, 0)
	var nl: float = n.length()
	return [[Vector4(1, 0, 0, 0), c.x + hx], [Vector4(-1, 0, 0, 0), -(c.x - hx)], [Vector4(0, 0, 0, 1), c.w + hw], [Vector4(0, 0, 0, -1), -(c.w - hw)],
		[Vector4(0, -1, 0, 0), 0.0], [Vector4(0, 0, 1, 0), zf], [n / nl, -k * zb / nl]]


## A gable roof (or a tent): its ridge along z at [param c] + [param h], eaves at [param c].y, [param hx]
## either side in x, [param hz] in z, [param hw] in W.
static func _gable(c: Vector4, hx: float, hz: float, h: float, hw: float) -> Array:
	var s: float = h / hx
	var n1 := Vector4(s, 1, 0, 0)
	var n2 := Vector4(-s, 1, 0, 0)
	return [[Vector4(0, -1, 0, 0), -c.y], [Vector4(0, 0, 1, 0), c.z + hz], [Vector4(0, 0, -1, 0), -(c.z - hz)],
		[Vector4(0, 0, 0, 1), c.w + hw], [Vector4(0, 0, 0, -1), -(c.w - hw)],
		[n1 / n1.length(), (c.y + h + s * c.x) / n1.length()], [n2 / n2.length(), (c.y + h - s * c.x) / n2.length()]]


## Each piece of landmark art as its own box: its local bounds, placed and turned as it is (hidden
## pieces, like the Watchstone's stones merged into one, left out). One mesh in all.
func _build_boxes() -> void:
	_blocks = Node4D.new()
	_blocks.name = "DevBlocks"
	_world_node().add_child(_blocks)
	var merged := ArrayTetraMesh4D.new()
	var count: int = 0
	for a in _arts:
		var mi: MeshInstance4D = a[0]
		if a[1] != "landmark" or mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var r: PackedVector4Array = mi.get_rect_bounds_local()
		if r[1].length() < 0.01:
			continue
		var box := BoxTetraMesh4D.new()
		box.size = r[1]
		merged.merge_with(box.to_array_tetra_mesh(), mi.global_position + mi.global_basis * (r[0] + r[1] * 0.5), mi.global_basis)
		count += 1
	var node := MeshInstance4D.new()
	node.name = "Boxes"
	node.mesh = merged
	node.material_override = _blue
	_blocks.add_child(node)
	print("BOXES: %d pieces of art as boxes" % count)


## Frame cost in this look, over [param frames] frames: the CPU frame and the GPU's measured time.
func measure(label: String, frames: int = 120) -> String:
	var rid: RID = get_viewport().get_viewport_rid()
	await get_tree().process_frame
	var cpu: float = 0.0
	var gpu: float = 0.0
	var worst: float = 0.0
	var last: int = Time.get_ticks_usec()
	for k in frames:
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		var dt: float = (now - last) / 1000.0
		last = now
		cpu += dt
		worst = maxf(worst, dt)
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
	var line: String = "MEASURE %s: frame %.2f ms (worst %.1f), GPU %.2f ms, over %d frames" % [label, cpu / frames, worst, gpu / frames, frames]
	print(line)
	return line


## The first frames after a switch: how long each took (a mesh drawn for the first time builds its
## buffers then: engine_capabilities.md).
func switch_cost(mode: String) -> String:
	await get_tree().process_frame
	var t0: int = Time.get_ticks_usec()
	look_to(mode)
	var times: Array = []
	var last: int = Time.get_ticks_usec()
	for k in 4:
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		times.append("%.0f" % ((now - last) / 1000.0))
		last = now
	var line: String = "SWITCH to %s: %.1f ms in all to the 4th frame; frames after it %s ms" % [mode, (last - t0) / 1000.0, ", ".join(times)]
	print(line)
	return line


## The pen's own Look (Systems/Look) switched by its player-facing call, the first frames after timed:
## the first switch to the art after the pen opened in DEV is the one the warm-up is for.
func pen_look(dev: bool) -> String:
	var look: Node = get_parent().get_node_or_null("Systems/Look")
	if look == null:
		return "no Look"
	await get_tree().process_frame
	var t0: int = Time.get_ticks_usec()
	look.call("set_dev", dev)
	var times: Array = []
	var last: int = Time.get_ticks_usec()
	for k in 4:
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		times.append("%.0f" % ((now - last) / 1000.0))
		last = now
	var line: String = "PEN LOOK to %s: %.1f ms to the 4th frame; frames %s ms" % ["dev" if dev else "art", (last - t0) / 1000.0, ", ".join(times)]
	print(line)
	return line


## The mechanics this look must not touch, read back: every node with a script still visible where it
## was, the colliders all there.
func check() -> String:
	var world: Node4D = _world_node()
	var hidden: int = 0
	var scripted: int = 0
	for node in world.find_children("*", "Node4D", true, false):
		if node.get_script() != null:
			scripted += 1
			if not (node as Node4D).is_visible_in_tree() and (node as Node4D).visible:
				hidden += 1
	var shapes: int = world.find_children("*", "CollisionShape4D", true, false).size()
	var areas: int = world.find_children("*", "Area4D", true, false).size()
	var line: String = "CHECK %s: %d scripted nodes, %d hidden by a parent, %d collision shapes, %d triggers" % [look, scripted, hidden, shapes, areas]
	print(line)
	return line
