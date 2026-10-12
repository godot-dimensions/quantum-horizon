@tool
extends RefCounted

## The Lab Chambers' building blocks, all in grid boxes (LabKit/lab_grid.gd): rooms with door
## openings, printed wall panels, floor pads, chevron strips, a drum. Everything is axis-aligned
## and built under nodes that stand at the world origin, because the grid shader places its lines
## from where a box stands (`grid_offset`); that is what lets a wall, the panel printed on it and
## the floor strip in front of it continue one grid.
##
## NO class_name (engine_gotchas.md): preload it.

const LabGrid := preload("res://ramon/CreationLab/LabKit/lab_grid.gd")
const LabPrint := preload("res://ramon/CreationLab/LabKit/lab_print.gd")
const Mats := preload("res://ramon/CreationLab/LabKit/lab_materials.gd")
const Batch := preload("res://ramon/CreationLab/LabKit/lab_batch.gd")

## Every box's depth through W. The player never turns the slice here (the orbit rig's
## `slice_turning` is off), so this only has to cover the exhibits' own turns through W.
const W_DEPTH := 8.0
## Marks every node these functions make, so a rebuild can clear them.
const GENERATED := "chamber_generated"
## Pixels per metre for prints: a 0.5 m letter is 80 px tall in the texture.
const PRINT_PPM := 160.0


static func _mark(n: Node) -> void:
	n.set_meta(GENERATED, true)


## Removes everything these functions made under `parent`.
static func clear(parent: Node) -> void:
	for child in parent.get_children():
		if child.has_meta(GENERATED):
			parent.remove_child(child)
			child.queue_free()


## A grid box centred at `centre` (x, y, z) of `size` (x, y, z) in `swatch`, solid if `collide`.
static func box(parent: Node4D, nm: String, centre: Vector3, size: Vector3, swatch: String, collide: bool = true) -> MeshInstance4D:
	var s4 := Vector4(size.x, size.y, size.z, W_DEPTH)
	var at := Vector4(centre.x, centre.y, centre.z, 0.0)
	var m := MeshInstance4D.new()
	m.name = nm
	m.mesh = Mats.box_mesh(s4)
	m.position = at
	# The grid continues across boxes from where each stands in the world: the parent's own place
	# counts (a kit piece moved in the editor), its turn does not (kit rooms stay square).
	var origin: Vector4 = at + (parent.global_position if parent.is_inside_tree() else Vector4.ZERO)
	m.material_override = LabGrid.material(swatch, s4, origin)
	_mark(m)
	parent.add_child(m)
	if collide:
		var body := StaticBody4D.new()
		body.name = nm + "Body"
		body.position = at
		var shape := CollisionShape4D.new()
		var b := BoxShape4D.new()
		b.size = s4
		shape.shape = b
		body.add_child(shape)
		_mark(body)
		parent.add_child(body)
		m.set_meta("body", body)
	return m


## A floor and four walls round the INTERIOR x0..x1, z0..z1: walls `t` thick outside it and `h`
## tall. `openings` maps a side ("n" is the -Z wall, "s" +Z, "w" -X, "e" +X) to
## [[from, to, height], ...] along that wall (x for n and s, z for w and e); a side listed in
## `open_sides` gets no wall at all (where a corridor runs into a room). `swatches` may give a
## side its own swatch. Returns the wall boxes by side, each a list.
static func room(parent: Node4D, nm: String, x0: float, z0: float, x1: float, z1: float, h: float,
		openings: Dictionary = {}, open_sides: Array = [], swatches: Dictionary = {}, floor_swatch: String = "floor", t: float = 0.5) -> Dictionary:
	box(parent, nm + "Floor", Vector3((x0 + x1) * 0.5, -0.25, (z0 + z1) * 0.5), Vector3(x1 - x0, 0.5, z1 - z0), floor_swatch)
	var walls: Dictionary = {}
	for side in ["n", "s", "w", "e"]:
		if side in open_sides:
			continue
		var along_x: bool = side == "n" or side == "s"
		var a0: float = (x0 - t) if along_x else z0
		var a1: float = (x1 + t) if along_x else z1
		var fixed: float
		match side:
			"n": fixed = z0 - t * 0.5
			"s": fixed = z1 + t * 0.5
			"w": fixed = x0 - t * 0.5
			_: fixed = x1 + t * 0.5
		var gaps: Array = openings.get(side, [])
		gaps = gaps.duplicate()
		gaps.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) < float(q[0]))
		var list: Array = []
		var at: float = a0
		var i: int = 0
		for g in gaps:
			var g0: float = float(g[0])
			var g1: float = float(g[1])
			var gh: float = float(g[2]) if g.size() > 2 else 4.5
			if g0 > at:
				list.append(_wall(parent, "%s_%s%d" % [nm, side, i], along_x, fixed, at, g0, 0.0, h, t, swatches.get(side, "wall")))
				i += 1
			if gh < h:
				list.append(_wall(parent, "%s_%s%dLintel" % [nm, side, i], along_x, fixed, g0, g1, gh, h, t, swatches.get(side, "wall")))
			at = g1
		if at < a1:
			list.append(_wall(parent, "%s_%s%d" % [nm, side, i], along_x, fixed, at, a1, 0.0, h, t, swatches.get(side, "wall")))
		walls[side] = list
	return walls


static func _wall(parent: Node4D, nm: String, along_x: bool, fixed: float, a0: float, a1: float, y0: float, y1: float, t: float, swatch: String) -> MeshInstance4D:
	var mid: float = (a0 + a1) * 0.5
	var len: float = a1 - a0
	if along_x:
		return box(parent, nm, Vector3(mid, (y0 + y1) * 0.5, fixed), Vector3(len, y1 - y0, t), swatch)
	return box(parent, nm, Vector3(fixed, (y0 + y1) * 0.5, mid), Vector3(t, y1 - y0, len), swatch)


## A thin panel standing 3 cm proud of a wall, for a print: `face` is the side of the wall the
## reader stands on ("+z", "-z", "+x", "-x"), `wall_at` the wall's inner face along that axis,
## `rect` the panel in metres (along the wall's axis, and up). Same swatch as the wall, so it reads
## as paint on it.
static func panel(parent: Node4D, nm: String, face: String, wall_at: float, rect: Rect2, swatch: String) -> MeshInstance4D:
	var d: float = 0.06
	var cy: float = rect.position.y + rect.size.y * 0.5
	var ca: float = rect.position.x + rect.size.x * 0.5
	var m: MeshInstance4D
	match face:
		"+z": m = box(parent, nm, Vector3(ca, cy, wall_at + d * 0.5), Vector3(rect.size.x, rect.size.y, d), swatch, false)
		"-z": m = box(parent, nm, Vector3(ca, cy, wall_at - d * 0.5), Vector3(rect.size.x, rect.size.y, d), swatch, false)
		"+x": m = box(parent, nm, Vector3(wall_at + d * 0.5, cy, ca), Vector3(d, rect.size.y, rect.size.x), swatch, false)
		_: m = box(parent, nm, Vector3(wall_at - d * 0.5, cy, ca), Vector3(d, rect.size.y, rect.size.x), swatch, false)
	m.set_meta("print_face", face)
	return m


## The outward normal of a panel's printed face, in its own space.
static func face_normal(face: String) -> Vector4:
	match face:
		"+z": return Vector4(0, 0, 1, 0)
		"-z": return Vector4(0, 0, -1, 0)
		"+x": return Vector4(1, 0, 0, 0)
		_: return Vector4(-1, 0, 0, 0)


## Prints `paint` over the whole printed face of `panel` (or of a floor tile, `face` "+y").
static func print_on(tree: SceneTree, m: MeshInstance4D, face: String, size_m: Vector2, paint: Callable, glow: float = 0.35) -> void:
	if not is_instance_valid(m):
		return
	var px := Vector2i(maxi(8, int(size_m.x * PRINT_PPM)), maxi(8, int(size_m.y * PRINT_PPM)))
	var tex: Texture2D = await LabPrint.render(tree, px, paint)
	if tex == null or not is_instance_valid(m):
		return
	var normal: Vector4 = Vector4(0, 1, 0, 0) if face == "+y" else face_normal(face)
	LabGrid.set_print(m.material_override as TetraMaterial4D, tex, normal, Rect2(Vector2.ZERO, size_m), Color.WHITE, glow)


## A strip of floor `proud` metres high (6 cm: at 2 cm the floor showed through it at a distance,
## Ramon 4 Oct) from `a` to `b` (x, z; axis-aligned), `width` wide, carrying
## chevrons that run from a to b. `phase` is how far along the route the strip starts, so strips
## laid end to end continue one stream. Returns the strip; LabGrid.set_chevrons turns it on.
static func strip(parent: Node4D, nm: String, a: Vector2, b: Vector2, width: float, phase: float, swatch: String = "floor", proud: float = 0.06) -> MeshInstance4D:
	var d: Vector2 = b - a
	var along_x: bool = absf(d.x) >= absf(d.y)
	var c := Vector3((a.x + b.x) * 0.5, proud * 0.5, (a.y + b.y) * 0.5)
	var size: Vector3
	var dir: Vector2
	if along_x:
		size = Vector3(absf(d.x), proud, width)
		dir = Vector2(signf(d.x), 0.0)
	else:
		size = Vector3(width, proud, absf(d.y))
		dir = Vector2(0.0, signf(d.y))
	var m: MeshInstance4D = box(parent, nm, c, size, swatch, false)
	m.set_meta("chevron_dir", dir)
	m.set_meta("chevron_phase", -phase)
	LabGrid.set_chevrons(m.material_override as TetraMaterial4D, 0.0, LabGrid.ACID, 1.2, 1.1, -phase, dir)
	return m


## Strips along a route of axis-aligned points; returns them, all off.
static func route(parent: Node4D, nm: String, points: PackedVector2Array, width: float = 0.9, swatch: String = "floor") -> Array:
	var out: Array = []
	var run: float = 0.0
	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		if a.distance_to(b) < 0.05:
			continue
		out.append(strip(parent, "%s%d" % [nm, i], a, b, width, run, swatch))
		run += a.distance_to(b)
	return out


## Turns a route's chevrons on (1) or off (0), in `color`.
static func route_on(strips: Array, on: float, color: Color = LabGrid.ACID) -> void:
	for s in strips:
		if is_instance_valid(s):
			var m: MeshInstance4D = s
			LabGrid.set_chevrons(m.material_override as TetraMaterial4D, on, color, 1.2, 1.1,
				float(m.get_meta("chevron_phase", 0.0)), m.get_meta("chevron_dir", Vector2(0, -1)))


## A floor tile 2 cm proud, `size` metres square, centred at `at` (x, z), ready for a print.
static func tile(parent: Node4D, nm: String, at: Vector2, size: float) -> MeshInstance4D:
	return box(parent, nm, Vector3(at.x, 0.01, at.y), Vector3(size, 0.02, size), "floor", false)


static var _cubinders: Dictionary = {}


static func _cubinder(r: float, h: float, segs: int = 48) -> Mesh4D:
	var key: String = "%.3f|%.3f|%d" % [r, h, segs]
	if _cubinders.has(key):
		return _cubinders[key]
	var c := CubinderShape4D.new()
	c.radius = r
	c.height = h
	c.thickness = W_DEPTH * 0.5
	var m: Mesh4D = c.to_tetra_mesh({"segments": segs})
	_cubinders[key] = m
	return m


## The drum an exhibit stands on: a dark body `height` tall, a deck in the chamber's colour on top
## and a white rim light round its edge. Returns the deck height. Solid as a box (the physics is
## box-shaped), a step bigger than the drum, so the player stops short of it.
static func drum(parent: Node4D, nm: String, at: Vector2, r: float, height: float, deck: Color) -> float:
	var body := MeshInstance4D.new()
	body.name = nm + "Body"
	body.mesh = _cubinder(r, height)
	body.position = Vector4(at.x, height * 0.5, at.y, 0.0)
	body.material_override = Mats.flat(Color(0.15, 0.16, 0.19))
	_mark(body)
	parent.add_child(body)
	var top := MeshInstance4D.new()
	top.name = nm + "Deck"
	top.mesh = _cubinder(r - 0.12, 0.04)
	top.position = Vector4(at.x, height + 0.02, at.y, 0.0)
	top.material_override = Mats.flat(deck)
	_mark(top)
	parent.add_child(top)
	var b := Batch.new()
	b.ring("rim", Vector4(at.x, height - 0.06, at.y, 0.0), r + 0.015, 0.05, 0.06, W_DEPTH * 0.5, 96)
	var rim: MeshInstance4D = b.instance("rim")
	rim.material_override = Mats.glow(Color(0.95, 0.97, 1.0), 1.0)
	_mark(rim)
	parent.add_child(rim)
	var solid := StaticBody4D.new()
	solid.name = nm + "Solid"
	solid.position = Vector4(at.x, height * 0.5, at.y, 0.0)
	var shape := CollisionShape4D.new()
	var bs := BoxShape4D.new()
	bs.size = Vector4(r * 2.0 + 0.3, height, r * 2.0 + 0.3, W_DEPTH)
	shape.shape = bs
	solid.add_child(shape)
	_mark(solid)
	parent.add_child(solid)
	return height + 0.04


## A glowing frame round a door opening (two posts and a lintel) in `color`. `side` and `span`
## as for room openings, `wall_at` the wall's centre line.
static func door_frame(parent: Node4D, nm: String, side: String, wall_at: float, a0: float, a1: float, h: float, t: float, color: Color) -> MeshInstance4D:
	var b := Batch.new()
	var bar: float = 0.16
	var depth: float = t + 0.08
	if side == "n" or side == "s":
		b.box("f", Vector4(bar, h, depth, W_DEPTH * 0.5), Vector4(a0 + bar * 0.5, h * 0.5, wall_at, 0.0))
		b.box("f", Vector4(bar, h, depth, W_DEPTH * 0.5), Vector4(a1 - bar * 0.5, h * 0.5, wall_at, 0.0))
		b.box("f", Vector4(a1 - a0, bar, depth, W_DEPTH * 0.5), Vector4((a0 + a1) * 0.5, h - bar * 0.5, wall_at, 0.0))
	else:
		b.box("f", Vector4(depth, h, bar, W_DEPTH * 0.5), Vector4(wall_at, h * 0.5, a0 + bar * 0.5, 0.0))
		b.box("f", Vector4(depth, h, bar, W_DEPTH * 0.5), Vector4(wall_at, h * 0.5, a1 - bar * 0.5, 0.0))
		b.box("f", Vector4(depth, bar, a1 - a0, W_DEPTH * 0.5), Vector4(wall_at, h - bar * 0.5, (a0 + a1) * 0.5, 0.0))
	var m: MeshInstance4D = b.instance("f")
	m.name = nm
	m.material_override = Mats.glow(color, 1.0)
	_mark(m)
	parent.add_child(m)
	return m
