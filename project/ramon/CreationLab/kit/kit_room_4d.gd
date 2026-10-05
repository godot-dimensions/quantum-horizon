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

const Build := preload("res://ramon/CreationLab/scripts/chamber_build.gd")
const RD := preload("res://ramon/CreationLab/scripts/rd_build.gd")
const LabGrid := preload("res://ramon/CreationLab/LabKit/lab_grid.gd")
const Mats := preload("res://ramon/CreationLab/LabKit/lab_materials.gd")
const Batch := preload("res://ramon/CreationLab/LabKit/lab_batch.gd")
const Style := preload("res://ramon/CreationLab/kit/kit_style.gd")
const LabPrint := preload("res://ramon/CreationLab/LabKit/lab_print.gd")

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

## Colour codes by edge for walls with no wall text on them, {edge: "blue"} (kit_style.gd CODES):
## a panel printed straight onto a wall (kit_research_wall_4d.gd, look "painted") asks for its wall.
@export var edge_codes: Dictionary = {}:
	set(v):
		edge_codes = v
		_later()

var _floor: MeshInstance4D
var _walls: Dictionary = {}       # side -> pieces
var _prints: Array = []
var _cove: MeshInstance4D
var _queued: bool = false
## Walls claimed while running (or previewing) by wall panels (kit_wall_panel_4d.gd): {wall: {claimer
## id: [code, claimer, from, to, field from, field to]}}, a wall being an edge number or a side ("n",
## "s", "w", "e"). Only the claimed field (along the wall) is painted in the code; the wall is split
## there and where the claimer's picture begins and ends (a piece of wall carries one picture), so
## two panels can share a wall and a long wall stays the room's own beyond the field. Unlike
## `edge_codes` a claim is never saved with the scene; it ends when its panel lets go or is freed.
var _claims: Dictionary = {}


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
		if edge_codes.has(side):
			swatch = Style.code_swatch(String(edge_codes[side]), swatch)
		swatch = _claimed_swatch(side, swatch)
		cuts.append_array(_claim_cuts(side))
		_walls[side] = RD.wall(self, "Wall" + side.to_upper(), side, x0, z0, x1, z1, h, t, ops, cuts, swatch)
		_paint_fields(side, _walls[side])
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
		if edge_codes.has(e):
			swatch = Style.code_swatch(String(edge_codes[e]), swatch)
		swatch = _claimed_swatch(e, swatch)
		cuts.append_array(_claim_cuts(e))
		_walls[e] = _edge_wall(e, a, c, h, t, ops, cuts, swatch)
		_paint_fields(e, _walls[e])
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
		var glow2: Dictionary = {"bright": float(tx.get("glow")), "dark": float(tx.get("glow")) + 0.15}
		var rec: Dictionary
		if bool(tx.get("live")):
			rec = _live_print(tx, pieces, Vector4(0, 0, -1 if outside else 1, 0), minf(al2.x, al2.y), maxf(al2.x, al2.y), up.x, up.y, glow2)
		else:
			rec = await RD.print_wall(tree, pieces, Vector4(0, 0, -1 if outside else 1, 0),
				minf(al2.x, al2.y), maxf(al2.x, al2.y), up.x, up.y, _painter(tx), glow2)
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


## Edge `e`'s wall pieces as built: [[box, p, q, y0, y1], ...], p and q along the edge from its
## first corner, each box's +Z looking into the room (empty before the room is built).
func wall_pieces(e: int) -> Array:
	var out: Array = []
	for pc in _walls.get(e, []):
		if is_instance_valid(pc[0]):
			out.append(pc)
	return out


## How long edge `e` is, metres.
func edge_length(e: int) -> float:
	if outline.size() < 2:
		return 0.0
	return outline[e % outline.size()].distance_to(outline[(e + 1) % outline.size()])


# -- walls for wall panels (kit_wall_panel_4d.gd) -------------------------------------------------
# A wall is an edge number in a polygon room, a side ("n", "s", "w", "e") in a rectangular one.
# Along it is measured from the edge's first corner (polygon) or the room's centre (rectangle),
# as wall text measures it.

## True if the room has wall `wall` (a polygon edge needs an outline, a side needs none).
func has_wall(wall: Variant) -> bool:
	if wall is String:
		return outline.size() < 3 and String(wall) in ["n", "s", "w", "e"] and not (String(wall) in open_sides)
	return outline.size() >= 3 and int(wall) >= 0 and int(wall) < outline.size()


## Where wall `wall` runs, along it: Vector2(from, to), metres.
func wall_span(wall: Variant) -> Vector2:
	if wall is String:
		var half: float = (size.x if String(wall) in ["n", "s"] else size.z) * 0.5
		return Vector2(-half, half)
	return Vector2(0.0, edge_length(int(wall)))


func wall_height() -> float:
	return size.y


## The wall's inner face: its middle and the way it looks into the room, in the room's x/z.
func wall_frame(wall: Variant) -> Array:
	if wall is String:
		match String(wall):
			"n": return [Vector2(0, -size.z * 0.5), Vector2(0, 1)]
			"s": return [Vector2(0, size.z * 0.5), Vector2(0, -1)]
			"w": return [Vector2(-size.x * 0.5, 0), Vector2(1, 0)]
			_: return [Vector2(size.x * 0.5, 0), Vector2(-1, 0)]
	var n: int = outline.size()
	var a: Vector2 = outline[int(wall) % n]
	var c: Vector2 = outline[(int(wall) + 1) % n]
	var d: Vector2 = (c - a).normalized()
	return [(a + c) * 0.5, Vector2(-d.y, d.x)]


## A wall panel claims wall `wall` in colour code `code` ("blue"); the room repaints it.
## `from`..`to` is the claimer's picture, `field` the stretch of wall painted in `code` round it
## (both along the wall; no field: the whole wall).
func claim_wall(wall: Variant, code: String, who: Object, from: float = NAN, to: float = NAN, field: Vector2 = Vector2(NAN, NAN)) -> void:
	var on: Dictionary = _claims.get(wall, {})
	var rec: Array = [code, who, from, to, field.x, field.y]
	if on.has(who.get_instance_id()) and str(on[who.get_instance_id()]) == str(rec):
		return
	on[who.get_instance_id()] = rec
	_claims[wall] = on
	_later()


## The panel `who` lets go of its wall.
func release_wall(wall: Variant, who: Object) -> void:
	var on: Dictionary = _claims.get(wall, {})
	if not on.has(who.get_instance_id()):
		return
	on.erase(who.get_instance_id())
	if on.is_empty():
		_claims.erase(wall)
	_later()


## Where the claimers' pictures and fields begin and end along `wall`, for splitting it.
func _claim_cuts(wall: Variant) -> Array:
	var out: Array = []
	for cl in (_claims.get(wall, {}) as Dictionary).values():
		if not is_instance_valid(cl[1]):
			continue
		for i in [2, 3, 4, 5]:
			if not is_nan(float(cl[i])):
				out.append(float(cl[i]))
	out.sort()
	return out


## A claim with no field paints the whole wall: the wall's swatch.
func _claimed_swatch(wall: Variant, fallback: String) -> String:
	for cl in (_claims.get(wall, {}) as Dictionary).values():
		if is_instance_valid(cl[1]) and is_nan(float(cl[4])):
			return Style.code_swatch(String(cl[0]), fallback)
	return fallback


## Paints the pieces of `wall` that stand in a claimed field in that claim's code.
func _paint_fields(wall: Variant, pieces: Array) -> void:
	for cl in (_claims.get(wall, {}) as Dictionary).values():
		if not is_instance_valid(cl[1]) or is_nan(float(cl[4])):
			continue
		for pc in pieces:
			var m: float = (float(pc[1]) + float(pc[2])) * 0.5
			if m > float(cl[4]) and m < float(cl[5]):
				var mat: TetraMaterial4D = (pc[0] as MeshInstance4D).material_override as TetraMaterial4D
				if mat != null:
					LabGrid.reswatch(mat, Style.code_swatch(String(cl[0])))


## What to print a picture `a0`..`a1` along wall `wall`, `y0`..`y1` up it, on: [[box, normal,
## rect], ...] for LabGrid.set_print, the rect in each piece's own face (the reader-left edge of
## the picture where that piece's u is, as RD.print_wall works it out). Empty before the room is
## built or when the picture misses the wall.
func print_targets(wall: Variant, a0: float, a1: float, y0: float, y1: float) -> Array:
	var out: Array = []
	var polygon: bool = not (wall is String)
	var normal: Vector4 = Vector4(0, 0, 1, 0) if polygon else RD.wall_normal(String(wall), true)
	for piece in _walls.get(wall if not polygon else int(wall), []):
		var b: MeshInstance4D = piece[0]
		if not is_instance_valid(b):
			continue
		var p: float = piece[1]
		var q: float = piece[2]
		var py0: float = piece[3]
		var py1: float = piece[4]
		if q <= a0 or p >= a1 or py1 <= y0 or py0 >= y1:
			continue
		var u0: float
		if absf(normal.z) > 0.5:
			u0 = (a0 - p) if normal.z > 0.0 else (q - a1)
		else:
			u0 = (q - a1) if normal.x > 0.0 else (a0 - p)
		out.append([b, normal, Rect2(Vector2(u0, y0 - py0), Vector2(a1 - a0, y1 - y0))])
	return out


func _texts() -> Array:
	var out: Array = []
	for c in get_children():
		if c.has_method("paint") and c.get("side") != null and c.get("enabled") != false:
			out.append(c)
	return out


## A live wall text (its `live` on): the same targets as RD.print_wall works out, but the picture is
## a viewport of its own, drawn by the text's painter and re-rendered only when asked (UPDATE_ONCE):
## on a change of mood, or when the text says what it says has changed (refresh_text).
func _live_print(tx: Node, pieces: Array, normal: Vector4, a0: float, a1: float, y0: float, y1: float, glow: Dictionary) -> Dictionary:
	var rec: Dictionary = {"targets": [], "tex": {}, "glow": glow, "live_text": tx}
	for piece in pieces:
		var p: float = piece[1]
		var q: float = piece[2]
		var py0: float = piece[3]
		var py1: float = piece[4]
		if q <= a0 or p >= a1 or py1 <= y0 or py0 >= y1:
			continue
		var u0: float = (a0 - p) if normal.z > 0.0 else (q - a1)
		(rec["targets"] as Array).append([piece[0], normal, Rect2(Vector2(u0, y0 - py0), Vector2(a1 - a0, y1 - y0))])
	var ppm: float = float(tx.get("live_ppm")) if tx.get("live_ppm") != null else 200.0
	var vp := SubViewport.new()
	vp.name = "LiveText"
	vp.size = Vector2i(maxi(8, int((a1 - a0) * ppm)), maxi(8, int((y1 - y0) * ppm)))
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.msaa_2d = Viewport.MSAA_4X
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.set_meta(Build.GENERATED, true)
	var painter: Callable = _painter(tx)
	var c := LabPrint.Canvas.new()
	c.size = Vector2(vp.size)
	c.paint = func(cc: Control) -> void: painter.call(cc, RD.INK[Style.mood])
	vp.add_child(c)
	add_child(vp)
	rec["tex"] = {"bright": vp.get_texture(), "dark": vp.get_texture()}
	rec["vp"] = vp
	rec["canvas"] = c
	return rec


func _redraw_live(rec: Dictionary) -> void:
	var c: Control = rec.get("canvas")
	var vp: SubViewport = rec.get("vp")
	if is_instance_valid(c) and is_instance_valid(vp):
		c.queue_redraw()
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE


## The live print's texture has no mipmaps: the shader samples it four times when it is small.
func _aa(rec: Dictionary) -> void:
	for t in rec.get("targets", []):
		if is_instance_valid(t[0]):
			((t[0] as MeshInstance4D).material_override as TetraMaterial4D).get_cross_section_material_3d().set_shader_parameter("print_aa", 1.0)


## A live wall text says what it shows has changed: its print is drawn again.
func refresh_text(tx: Node) -> void:
	for rec in _prints:
		if rec.get("live_text") == tx:
			_redraw_live(rec)


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
		if rec.has("canvas"):
			_redraw_live(rec)
		RD.apply(rec, Style.mood)
		if rec.has("canvas"):
			_aa(rec)
	if is_instance_valid(_cove):
		_cove.material_override = Mats.glow(Style.pick(Style.COVE), 1.0)
	_show_route()


func _show_route() -> void:
	if not is_instance_valid(_floor):
		return
	LabGrid.set_route(_floor.material_override as TetraMaterial4D, route, 1.0 if route_lit else 0.0, Style.pick(Style.CODE_BLUE))
	LabGrid.set_ring(_floor.material_override as TetraMaterial4D, Vector2(ring.x, ring.y), ring.z, 1.0, Style.pick(Style.CODE_BLUE))
