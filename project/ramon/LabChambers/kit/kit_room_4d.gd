@tool
extends Node4D

## Kit: a room. Floor, four walls with doorways, a ceiling and a line of cove light, all on the
## gallery grid (kit_style.gd). Move the node and the room moves; set `size` and it rebuilds.
##
## TEXT ON ITS WALLS: KitWallText children (kit_wall_text_4d.gd) say which wall and where; the
## room splits that wall where the text begins and ends and paints it straight onto the wall
## (Ramon, 4 Oct: a proud sign "reads as a glitch").
##
## A ROUTE on its floor: `route` (world x/z) is painted into the floor's own surface as soft
## arrows, no geometry above it (LabKit/lab_grid.gd set_route).
##
## The room's interior is `size` (x, height, z) centred on the node, x and z only (it is never
## turned). Doorways are [side, from, to, height] with from/to measured along that wall from the
## room's centre; "n" is the -Z wall, "s" +Z, "w" -X, "e" +X.
##
## OR AN OUTLINE: give `outline` (the interior's corners in the node's x/z, going clockwise seen
## from above with -Z up the page, e.g. south-west, north-west, ... ) and the room is that
## polygon: square corners, angled panels, whatever the outline says (Ramon, 4 Oct: an octagon
## with square corners at the entrance and big angled panels at the back). Then edges are walls
## numbered from 0 (corner i to corner i+1); doorways become [edge, from, to, height] and wall
## text uses `edge`, both measured along the edge from its first corner. Angled walls are drawn
## turned, but the physics here is box-only, so behind each one stands a row of small upright
## boxes instead of one big tilted one.
##
## NO class_name (engine_gotchas.md).

const Build := preload("res://ramon/LabChambers/scripts/chamber_build.gd")
const RD := preload("res://ramon/LabChambers/scripts/rd_build.gd")
const LabGrid := preload("res://ramon/LabKit/lab_grid.gd")
const Mats := preload("res://ramon/LabKit/lab_materials.gd")
const Batch := preload("res://ramon/LabKit/lab_batch.gd")
const Style := preload("res://ramon/LabChambers/kit/kit_style.gd")

@export_tool_button("Rebuild") var _rebuild_action: Callable = rebuild
## The interior corners for a polygon room (empty: a rectangle of `size`). `size.y` is the height.
@export var outline: PackedVector2Array = PackedVector2Array():
	set(v):
		outline = v
		_later()
@export var size: Vector3 = Vector3(20, 8, 18):
	set(v):
		size = v
		_later()
@export var doorways: Array = []:
	set(v):
		doorways = v
		_later()
@export var open_sides: Array = []:
	set(v):
		open_sides = v
		_later()
@export var ceiling: bool = true:
	set(v):
		ceiling = v
		_later()
@export var cove: bool = true:
	set(v):
		cove = v
		_later()
## Arrows painted into the floor, in world x/z, from the first point to the last.
@export var route: PackedVector2Array = PackedVector2Array():
	set(v):
		route = v
		_show_route()
## A slowly turning ring painted into the floor: world x, z of its centre and its radius (0: none).
@export var ring: Vector3 = Vector3.ZERO:
	set(v):
		ring = v
		_show_route()
@export var route_lit: bool = true:
	set(v):
		route_lit = v
		_show_route()

var _floor: MeshInstance4D
var _walls: Dictionary = {}       # side -> pieces
var _prints: Array = []
var _cove: MeshInstance4D
var _queued: bool = false


func _enter_tree() -> void:
	add_to_group("lab_mood_listener")
	add_to_group("kit_room")


func _ready() -> void:
	rebuild()


func _later() -> void:
	if not is_inside_tree() or _queued:
		return
	_queued = true
	(func() -> void:
		_queued = false
		rebuild()).call_deferred()


func rebuild() -> void:
	if outline.size() >= 3:
		_rebuild_outline()
		return
	Build.clear(self)
	_prints = []
	_walls = {}
	var x0: float = -size.x * 0.5
	var x1: float = size.x * 0.5
	var z0: float = -size.z * 0.5
	var z1: float = size.z * 0.5
	var h: float = size.y
	var t: float = 0.5
	_floor = Build.box(self, "Floor", Vector3(0, -0.25, 0), Vector3(size.x, 0.5, size.z), "kit_floor")
	var texts: Array = _texts()
	for side in ["n", "s", "w", "e"]:
		if side in open_sides:
			continue
		var ops: Array = []
		for d in doorways:
			if String(d[0]) == side:
				ops.append([float(d[1]), float(d[2]), float(d[3]) if d.size() > 3 else 3.6])
		var cuts: Array = []
		var swatch: String = "kit_wall"
		for tx in texts:
			if String(tx.get("side")) == side:
				var a: Vector2 = tx.get("along")
				cuts.append(a.x)
				cuts.append(a.y)
				swatch = Style.code_swatch(String(tx.get("code")), swatch)
		_walls[side] = RD.wall(self, "Wall" + side.to_upper(), side, x0, z0, x1, z1, h, t, ops, cuts, swatch)
	if ceiling:
		RD.ceiling(self, "Ceiling", x0 - t, z0 - t, x1 + t, z1 + t, h, "kit_ceiling")
	if cove:
		var b := Batch.new()
		RD.strip_rect(b, "cove", x0 + 0.3, z0 + 0.3, x1 - 0.3, z1 - 0.3, h - 0.22, 0.09, 0.05)
		_cove = b.instance("cove")
		_cove.set_meta(Build.GENERATED, true)
		add_child(_cove)
	_apply_mood_now()
	_show_route()
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	for tx in texts:
		var side: String = String(tx.get("side"))
		if not _walls.has(side):
			continue
		var a: Vector2 = tx.get("along")
		var up: Vector2 = tx.get("up")
		var rec: Dictionary = await RD.print_wall(tree, _walls[side], RD.wall_normal(side, not bool(tx.get("outside"))),
			minf(a.x, a.y), maxf(a.x, a.y), up.x, up.y, _painter(tx), {"bright": float(tx.get("glow")), "dark": float(tx.get("glow")) + 0.15})
		_prints.append(rec)
	_apply_mood_now()


# -- a polygon room -------------------------------------------------------------------------------

func _rebuild_outline() -> void:
	Build.clear(self)
	_prints = []
	_walls = {}
	var h: float = size.y
	var t: float = 0.5
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in outline:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var mid: Vector2 = (lo + hi) * 0.5
	var ext: Vector2 = hi - lo
	# Floor and ceiling as plain rectangles over the whole footprint: what lies outside the walls
	# is never seen from inside.
	_floor = Build.box(self, "Floor", Vector3(mid.x, -0.25, mid.y), Vector3(ext.x + t * 2.0, 0.5, ext.y + t * 2.0), "kit_floor")
	if ceiling:
		Build.box(self, "Ceiling", Vector3(mid.x, h + 0.2, mid.y), Vector3(ext.x + t * 2.0, 0.4, ext.y + t * 2.0), "kit_ceiling", false)
	var texts: Array = _texts()
	var b := Batch.new()
	var n: int = outline.size()
	for e in n:
		var a: Vector2 = outline[e]
		var c: Vector2 = outline[(e + 1) % n]
		var ops: Array = []
		for d in doorways:
			if int(d[0]) == e:
				ops.append([float(d[1]), float(d[2]), float(d[3]) if d.size() > 3 else 3.6])
		var cuts: Array = []
		var swatch: String = "kit_wall"
		for tx in texts:
			if int(tx.get("edge")) == e:
				var al: Vector2 = tx.get("along")
				cuts.append(al.x)
				cuts.append(al.y)
				swatch = Style.code_swatch(String(tx.get("code")), swatch)
		_walls[e] = _edge_wall(e, a, c, h, t, ops, cuts, swatch)
		if cove:
			var d2: Vector2 = (c - a).normalized()
			var inward := Vector2(-d2.y, d2.x)
			var len: float = a.distance_to(c)
			var m2: Vector2 = (a + c) * 0.5 + inward * 0.3
			b.box("cove", Vector4(len - 0.4, 0.05, 0.09, 1.0), Vector4(m2.x, h - 0.22, m2.y, 0.0), Basis4D.from_zx(atan2(d2.x, d2.y) - PI * 0.5))
	if cove:
		_cove = b.instance("cove")
		_cove.set_meta(Build.GENERATED, true)
		add_child(_cove)
	_apply_mood_now()
	_show_route()
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	for tx in texts:
		var e2: int = int(tx.get("edge"))
		if not _walls.has(e2):
			continue
		var al2: Vector2 = tx.get("along")
		var up: Vector2 = tx.get("up")
		var outside: bool = bool(tx.get("outside"))
		var pieces: Array = []
		for pc in _walls[e2]:
			# [box, p, q, y0, y1] along the edge; print_wall reads u from the face as an axis wall
			# would, so hand it the face's own frame: inner face +Z (u from p), outer -Z (u from q).
			pieces.append(pc)
		var rec: Dictionary = await RD.print_wall(tree, pieces, Vector4(0, 0, -1 if outside else 1, 0),
			minf(al2.x, al2.y), maxf(al2.x, al2.y), up.x, up.y, _painter(tx), {"bright": float(tx.get("glow")), "dark": float(tx.get("glow")) + 0.15})
		_prints.append(rec)
	_apply_mood_now()


## One edge of a polygon room: its wall in pieces (split at doorways and where text starts and
## ends), each a box turned to the edge, its +Z looking into the room; then, for an angled edge, a
## row of small upright boxes behind it for the physics. Returns [[box, p, q, y0, y1], ...] with p
## and q measured along the edge.
func _edge_wall(e: int, a: Vector2, c: Vector2, h: float, t: float, openings: Array, cuts: Array, swatch: String = "kit_wall") -> Array:
	var len: float = a.distance_to(c)
	var d: Vector2 = (c - a) / maxf(len, 0.0001)
	var inward := Vector2(-d.y, d.x)
	var turn: Projection = Basis4D.from_zx(atan2(d.x, d.y) - PI * 0.5)
	var axis: bool = absf(d.x) < 0.001 or absf(d.y) < 0.001
	# Walls overlap a little at the corners so no seam opens.
	var a0: float = -t
	var a1: float = len + t
	var points: Array = [a0, a1]
	for o in openings:
		points.append(clampf(float(o[0]), a0, a1))
		points.append(clampf(float(o[1]), a0, a1))
	for k in cuts:
		points.append(clampf(float(k), a0, a1))
	points.sort()
	var out: Array = []
	for i in range(points.size() - 1):
		var p: float = points[i]
		var q: float = points[i + 1]
		if q - p < 0.01:
			continue
		var m: float = (p + q) * 0.5
		var y0: float = 0.0
		for o in openings:
			if m > float(o[0]) and m < float(o[1]):
				y0 = float(o[2]) if o.size() > 2 else 3.6
		if y0 >= h:
			continue
		var centre2: Vector2 = a + d * m - inward * t * 0.5
		var box: MeshInstance4D = Build.box(self, "Edge%d_%d" % [e, i], Vector3(centre2.x, (y0 + h) * 0.5, centre2.y), Vector3(q - p, h - y0, t), swatch, false)
		box.basis = turn
		if axis:
			# A square edge: one box for the physics, in the world's own axes.
			var body := StaticBody4D.new()
			body.name = "Edge%d_%dBody" % [e, i]
			body.position = box.position
			var shape := CollisionShape4D.new()
			var bs := BoxShape4D.new()
			bs.size = Vector4(q - p, h - y0, t, Build.W_DEPTH) if absf(d.x) > absf(d.y) else Vector4(t, h - y0, q - p, Build.W_DEPTH)
			shape.shape = bs
			body.add_child(shape)
			body.set_meta(Build.GENERATED, true)
			add_child(body)
		# The grid in the wall's own frame, so it runs on unbroken along the edge.
		(box.material_override as TetraMaterial4D).get_cross_section_material_3d().set_shader_parameter("grid_offset", Vector4(m, (y0 + h) * 0.5, 0.0, 0.0))
		out.append([box, p, q, y0, h])
	if not axis:
		var step: float = 0.7
		var count: int = int(ceil(len / step))
		for k2 in count:
			var at: float = (float(k2) + 0.5) * len / float(count)
			var blocked: bool = false
			for o in openings:
				if at > float(o[0]) and at < float(o[1]):
					blocked = true
			if blocked:
				continue
			var p2: Vector2 = a + d * at - inward * (step * 0.5 + 0.05)
			var body := StaticBody4D.new()
			body.name = "Edge%dBlock%d" % [e, k2]
			body.position = Vector4(p2.x, h * 0.5, p2.y, 0.0)
			var shape := CollisionShape4D.new()
			var bs := BoxShape4D.new()
			bs.size = Vector4(step, h, step, Build.W_DEPTH)
			shape.shape = bs
			body.add_child(shape)
			body.set_meta(Build.GENERATED, true)
			add_child(body)
	return out


func _texts() -> Array:
	var out: Array = []
	for c in get_children():
		if c.has_method("paint") and c.get("side") != null:
			out.append(c)
	return out


## A wall text's painter: its own paint(), handed its colour code's ink when it has one.
func _painter(tx: Node) -> Callable:
	var code: String = String(tx.get("code"))
	if code.is_empty() or code == "none":
		return Callable(tx, "paint")
	return func(c: Control, ink: Dictionary) -> void: tx.call("paint", c, Style.code_ink(code, ink))


## True if `p` (world) stands inside the room's outline (or its rectangle).
func _inside_outline(l: Vector2) -> bool:
	var inside_it: bool = false
	var n: int = outline.size()
	for i in n:
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % n]
		if (a.y > l.y) != (b.y > l.y) and l.x < (b.x - a.x) * (l.y - a.y) / (b.y - a.y) + a.x:
			inside_it = not inside_it
	return inside_it


## The floor's box, for anything that wants to paint on it.
func floor_box() -> MeshInstance4D:
	return _floor


## True if `p` (world) stands inside the room.
func inside(p: Vector4) -> bool:
	var l: Vector4 = p - global_position
	if outline.size() >= 3:
		return _inside_outline(Vector2(l.x, l.z))
	return absf(l.x) <= size.x * 0.5 + 0.3 and absf(l.z) <= size.z * 0.5 + 0.3


func apply_mood(_m: String, _instant: bool = false) -> void:
	_apply_mood_now()


func _apply_mood_now() -> void:
	for rec in _prints:
		RD.apply(rec, Style.mood)
	if is_instance_valid(_cove):
		_cove.material_override = Mats.glow(Style.pick(Style.COVE), 1.0)
	_show_route()


func _show_route() -> void:
	if not is_instance_valid(_floor):
		return
	LabGrid.set_route(_floor.material_override as TetraMaterial4D, route, 1.0 if route_lit else 0.0, Style.pick(Style.ROUTE))
	LabGrid.set_ring(_floor.material_override as TetraMaterial4D, Vector2(ring.x, ring.y), ring.z, 1.0, Style.pick(Style.ROUTE))
