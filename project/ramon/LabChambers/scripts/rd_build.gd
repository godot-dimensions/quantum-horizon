@tool
extends RefCounted

## Building blocks for the R&D gallery (rd_gallery.tscn), on top of chamber_build.gd:
##
##   walls      a wall split wherever a doorway or a print begins or ends, so text is painted
##              straight onto the wall itself (Ramon, 4 Oct: the proud sign "reads as a glitch",
##              "just place the 02, motion and arrow directly on the wall"). Doorways get a lintel.
##   prints     rendered twice, once per mood, with that mood's ink (dark text on the white rooms,
##              light text on the dark ones), and swapped when the mood changes
##   ceilings   a slab with an optional skylight opening, and cove light strips under its edges
##   plants     planters with blocky voxel palms and shrubs, batched into a few meshes
##   icons      the line icons the walls and the HUD use (mouse, wheel, keys, slice, rotate, play)
##
## Everything stands under nodes at the world origin, because the grid shader places its lines
## from where a box stands (chamber_build.gd explains).
##
## NO class_name (engine_gotchas.md): preload it.

const Build := preload("res://ramon/LabChambers/scripts/chamber_build.gd")
const LabGrid := preload("res://ramon/LabKit/lab_grid.gd")
const LabPrint := preload("res://ramon/LabKit/lab_print.gd")
const Mats := preload("res://ramon/LabKit/lab_materials.gd")
const Batch := preload("res://ramon/LabKit/lab_batch.gd")

## The ink each mood prints with: text, a dimmer line, the accent (the gallery's blue), what sits
## on an accent fill, and fine line work.
const INK := {
	"bright": {"name": "bright", "text": Color(0.08, 0.09, 0.11), "dim": Color(0.34, 0.36, 0.40), "accent": Color(0.10, 0.42, 0.95),
		"on_accent": Color(1, 1, 1), "line": Color(0.62, 0.67, 0.76), "panel": Color(0.11, 0.42, 0.93)},
	"dark": {"name": "dark", "text": Color(0.95, 0.95, 0.92), "dim": Color(0.64, 0.67, 0.72), "accent": Color(0.40, 0.76, 1.0),
		"on_accent": Color(1, 1, 1), "line": Color(0.30, 0.38, 0.50), "panel": Color(0.07, 0.24, 0.58)},
}

const MOODS := ["bright", "dark"]


# -- walls and prints ------------------------------------------------------------------------------

## A wall of a room with the INTERIOR rect x0..x1, z0..z1: `side` "n" (-Z), "s" (+Z), "w" (-X),
## "e" (+X), `t` thick outside the interior, `h` tall. `openings`: [[from, to, height], ...] along
## the wall (x for n/s, z for w/e). `cuts`: more places to split it (where prints begin and end).
## Returns [[box, a0, a1, y0, y1], ...] for printing on.
static func wall(parent: Node4D, nm: String, side: String, x0: float, z0: float, x1: float, z1: float, h: float, t: float,
		openings: Array, cuts: Array, swatch: String) -> Array:
	var along_x: bool = side == "n" or side == "s"
	var a0: float = (x0 - t) if along_x else z0
	var a1: float = (x1 + t) if along_x else z1
	var fixed: float
	match side:
		"n": fixed = z0 - t * 0.5
		"s": fixed = z1 + t * 0.5
		"w": fixed = x0 - t * 0.5
		_: fixed = x1 + t * 0.5
	var points: Array = [a0, a1]
	for o in openings:
		points.append(clampf(float(o[0]), a0, a1))
		points.append(clampf(float(o[1]), a0, a1))
	for c in cuts:
		points.append(clampf(float(c), a0, a1))
	points.sort()
	var out: Array = []
	for i in range(points.size() - 1):
		var p: float = points[i]
		var q: float = points[i + 1]
		if q - p < 0.01:
			continue
		var mid: float = (p + q) * 0.5
		var y0: float = 0.0
		for o in openings:
			if mid > float(o[0]) and mid < float(o[1]):
				y0 = float(o[2]) if o.size() > 2 else 4.5
		if y0 >= h:
			continue
		var b: MeshInstance4D
		var cy: float = (y0 + h) * 0.5
		if along_x:
			b = Build.box(parent, "%s%d" % [nm, i], Vector3(mid, cy, fixed), Vector3(q - p, h - y0, t), swatch)
		else:
			b = Build.box(parent, "%s%d" % [nm, i], Vector3(fixed, cy, mid), Vector3(t, h - y0, q - p), swatch)
		out.append([b, p, q, y0, h])
	return out


## The outward normal of `side`'s wall on the face that looks into the room (`inner`) or out of it.
static func wall_normal(side: String, inner: bool) -> Vector4:
	var n: Vector4
	match side:
		"n": n = Vector4(0, 0, 1, 0)
		"s": n = Vector4(0, 0, -1, 0)
		"w": n = Vector4(1, 0, 0, 0)
		_: n = Vector4(-1, 0, 0, 0)
	return n if inner else -n


## Prints across the wall pieces `pieces` (from wall()), on the face with outward `normal`, over
## [a0, a1] along the wall and [y0, y1] up it. `paint(canvas, ink)` draws it; it is rendered once
## per mood. Returns the print's record for `apply()`.
static func print_wall(tree: SceneTree, pieces: Array, normal: Vector4, a0: float, a1: float, y0: float, y1: float,
		paint: Callable, glow: Dictionary = {"bright": 0.12, "dark": 0.5}) -> Dictionary:
	var rec: Dictionary = {"targets": [], "tex": {}, "glow": glow}
	for piece in pieces:
		var b: MeshInstance4D = piece[0]
		var p: float = piece[1]
		var q: float = piece[2]
		var py0: float = piece[3]
		var py1: float = piece[4]
		if q <= a0 or p >= a1 or py1 <= y0 or py0 >= y1:
			continue
		# Where the print's reader-left edge falls in the face's own u, which runs to the right of
		# a reader facing that face (lab_grid.gdshader, print_uv).
		var u0: float
		if absf(normal.z) > 0.5:
			u0 = (a0 - p) if normal.z > 0.0 else (q - a1)
		else:
			u0 = (q - a1) if normal.x > 0.0 else (a0 - p)
		var rect := Rect2(Vector2(u0, y0 - py0), Vector2(a1 - a0, y1 - y0))
		(rec["targets"] as Array).append([b, normal, rect])
	var size_m := Vector2(a1 - a0, y1 - y0)
	for mood in MOODS:
		var ink: Dictionary = INK[mood]
		var px := Vector2i(maxi(8, int(size_m.x * Build.PRINT_PPM)), maxi(8, int(size_m.y * Build.PRINT_PPM)))
		rec["tex"][mood] = await LabPrint.render(tree, px, func(c: Control) -> void: paint.call(c, ink))
	return rec


## Prints over one whole face of one box (a floating panel or a button), as print_wall.
## `ppm` is the pixels per metre to render at (more for small detail you read up close).
static func print_box(tree: SceneTree, b: MeshInstance4D, normal: Vector4, size_m: Vector2, paint: Callable,
		glow: Dictionary = {"bright": 0.6, "dark": 0.8}, ppm: float = 0.0) -> Dictionary:
	var rec: Dictionary = {"targets": [[b, normal, Rect2(Vector2.ZERO, size_m)]], "tex": {}, "glow": glow}
	var res: float = ppm if ppm > 0.0 else Build.PRINT_PPM
	for mood in MOODS:
		var ink: Dictionary = INK[mood]
		var px := Vector2i(maxi(8, int(size_m.x * res)), maxi(8, int(size_m.y * res)))
		rec["tex"][mood] = await LabPrint.render(tree, px, func(c: Control) -> void: paint.call(c, ink))
	return rec


## Shows a print in `mood` (k fades it, 0 to 1).
static func apply(rec: Dictionary, mood: String, k: float = 1.0) -> void:
	var tex: Texture2D = (rec.get("tex", {}) as Dictionary).get(mood)
	var glow: float = float((rec.get("glow", {}) as Dictionary).get(mood, 0.3))
	for t in rec.get("targets", []):
		var b: MeshInstance4D = t[0]
		if not is_instance_valid(b):
			continue
		LabGrid.set_print(b.material_override as TetraMaterial4D, tex, t[1], t[2], Color.WHITE, glow)
		LabGrid.set_print_strength(b.material_override as TetraMaterial4D, k if tex != null else 0.0)


# -- ceilings, light, plants -----------------------------------------------------------------------

## A ceiling slab over x0..x1, z0..z1 at height `y` with an optional skylight `hole` (x, z rect).
static func ceiling(parent: Node4D, nm: String, x0: float, z0: float, x1: float, z1: float, y: float, swatch: String, hole: Rect2 = Rect2()) -> void:
	var t: float = 0.4
	var cy: float = y + t * 0.5
	if hole.size == Vector2.ZERO:
		Build.box(parent, nm, Vector3((x0 + x1) * 0.5, cy, (z0 + z1) * 0.5), Vector3(x1 - x0, t, z1 - z0), swatch, false)
		return
	var hx0: float = hole.position.x
	var hz0: float = hole.position.y
	var hx1: float = hole.end.x
	var hz1: float = hole.end.y
	Build.box(parent, nm + "N", Vector3((x0 + x1) * 0.5, cy, (z0 + hz0) * 0.5), Vector3(x1 - x0, t, hz0 - z0), swatch, false)
	Build.box(parent, nm + "S", Vector3((x0 + x1) * 0.5, cy, (hz1 + z1) * 0.5), Vector3(x1 - x0, t, z1 - hz1), swatch, false)
	Build.box(parent, nm + "W", Vector3((x0 + hx0) * 0.5, cy, (hz0 + hz1) * 0.5), Vector3(hx0 - x0, t, hz1 - hz0), swatch, false)
	Build.box(parent, nm + "E", Vector3((hx1 + x1) * 0.5, cy, (hz0 + hz1) * 0.5), Vector3(x1 - hx1, t, hz1 - hz0), swatch, false)


## A rectangle of light strip `width` wide round x0..x1, z0..z1 at height `y`, into `b` as kind.
static func strip_rect(b: Batch, kind: String, x0: float, z0: float, x1: float, z1: float, y: float, width: float = 0.08, tall: float = 0.05) -> void:
	var w: float = Build.W_DEPTH * 0.5
	b.box(kind, Vector4(x1 - x0, tall, width, w), Vector4((x0 + x1) * 0.5, y, z0, 0.0))
	b.box(kind, Vector4(x1 - x0, tall, width, w), Vector4((x0 + x1) * 0.5, y, z1, 0.0))
	b.box(kind, Vector4(width, tall, z1 - z0, w), Vector4(x0, y, (z0 + z1) * 0.5, 0.0))
	b.box(kind, Vector4(width, tall, z1 - z0, w), Vector4(x1, y, (z0 + z1) * 0.5, 0.0))


## A planter at (x, z) with a voxel palm or a shrub, into `b`: kinds "planter", "leaf", "leaf2",
## "trunk". `seed` varies it.
static func planter(b: Batch, x: float, z: float, palm: bool, seed: int) -> void:
	var w: float = 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	b.box("planter", Vector4(1.3, 0.8, 1.3, w), Vector4(x, 0.4, z, 0.0))
	b.box("trunk", Vector4(1.15, 0.06, 1.15, w), Vector4(x, 0.81, z, 0.0))
	if palm:
		var h: float = rng.randf_range(2.6, 3.6)
		var lean := Vector2(rng.randf_range(-0.25, 0.25), rng.randf_range(-0.25, 0.25))
		var segs: int = 6
		for i in segs:
			var k: float = float(i) / float(segs)
			b.box("trunk", Vector4(0.2, h / segs + 0.04, 0.2, w), Vector4(x + lean.x * k * k * h, 0.85 + h * (k + 0.5 / segs), z + lean.y * k * k * h, 0.0))
		var top := Vector4(x + lean.x * h, 0.85 + h, z + lean.y * h, 0.0)
		var fronds: int = 7
		for f in fronds:
			var a: float = TAU * float(f) / float(fronds) + rng.randf() * 0.4
			var reach: float = rng.randf_range(1.3, 1.8)
			for s in 4:
				var r: float = reach * (float(s) + 0.5) / 4.0
				var droop: float = -0.35 * r * r / reach
				b.box("leaf" if (f + s) % 2 == 0 else "leaf2", Vector4(0.42 - 0.07 * s, 0.07, 0.3 - 0.04 * s, w),
					top + Vector4(cos(a) * r, droop + 0.05, sin(a) * r, 0.0), Basis4D.from_zx(-a))
	else:
		var n: int = 9
		for i in n:
			var s: float = rng.randf_range(0.35, 0.6)
			b.box("leaf" if i % 3 else "leaf2", Vector4(s, s, s, w),
				Vector4(x + rng.randf_range(-0.4, 0.4), 0.9 + rng.randf_range(0.1, 1.1), z + rng.randf_range(-0.4, 0.4), 0.0))


# -- icons -----------------------------------------------------------------------------------------

## Draws a line icon of `kind` in `rect`: mouse, wheel, rdrag, key:<label>, slice, rotate, play,
## engine, player, developer, arrow_left, arrow_right.
static func icon(c: Control, kind: String, rect: Rect2, col: Color) -> void:
	var s: float = minf(rect.size.x, rect.size.y)
	var o: Vector2 = rect.get_center()
	var lw: float = maxf(2.0, s * 0.06)
	if kind.begins_with("key:"):
		var label: String = kind.substr(4)
		var kr := Rect2(o - Vector2(s, s) * 0.42, Vector2(s, s) * 0.84)
		if label.length() > 1:
			kr = Rect2(o - Vector2(s * 0.85, s * 0.42), Vector2(s * 1.7, s * 0.84))
		var box := StyleBoxFlat.new()
		box.draw_center = false
		box.border_color = col
		box.set_border_width_all(int(lw))
		box.set_corner_radius_all(int(s * 0.14))
		box.anti_aliasing = true
		c.draw_style_box(box, kr)
		var f: Font = LabPrint.font("bold")
		var px: int = int(s * (0.42 if label.length() <= 1 else 0.24))
		c.draw_string(f, Vector2(kr.position.x, o.y + f.get_ascent(px) * 0.36), label, HORIZONTAL_ALIGNMENT_CENTER, kr.size.x, px, col)
		return
	match kind:
		"mouse", "wheel", "rdrag":
			var mr := Rect2(o - Vector2(s * 0.27, s * 0.42), Vector2(s * 0.54, s * 0.84))
			var box2 := StyleBoxFlat.new()
			box2.draw_center = false
			box2.border_color = col
			box2.set_border_width_all(int(lw))
			box2.set_corner_radius_all(int(s * 0.26))
			box2.anti_aliasing = true
			c.draw_style_box(box2, mr)
			c.draw_line(Vector2(o.x, mr.position.y), Vector2(o.x, mr.position.y + s * 0.3), col, lw, true)
			c.draw_line(Vector2(mr.position.x, mr.position.y + s * 0.3), Vector2(mr.end.x, mr.position.y + s * 0.3), col, lw, true)
			if kind == "wheel":
				c.draw_line(Vector2(o.x, mr.position.y + s * 0.07), Vector2(o.x, mr.position.y + s * 0.22), col, lw * 2.2, true)
			elif kind == "rdrag":
				c.draw_rect(Rect2(Vector2(o.x, mr.position.y + lw), Vector2(mr.size.x * 0.5 - lw, s * 0.3 - lw)), col)
		"slice":
			for i in 3:
				var dy: float = (float(i) - 1.0) * s * 0.2
				var pts := PackedVector2Array([o + Vector2(-s * 0.4, dy + s * 0.08), o + Vector2(-s * 0.1, dy - s * 0.12),
					o + Vector2(s * 0.4, dy - s * 0.12), o + Vector2(s * 0.1, dy + s * 0.08), o + Vector2(-s * 0.4, dy + s * 0.08)])
				c.draw_polyline(pts, col, lw, true)
		"rotate":
			c.draw_arc(o, s * 0.34, -PI * 0.2, PI * 1.45, 48, col, lw, true)
			var tip: Vector2 = o + Vector2(cos(-PI * 0.2), sin(-PI * 0.2)) * s * 0.34
			c.draw_colored_polygon(PackedVector2Array([tip + Vector2(-s * 0.14, -s * 0.02), tip + Vector2(s * 0.08, -s * 0.12), tip + Vector2(s * 0.06, s * 0.12)]), col)
		"play":
			c.draw_arc(o, s * 0.42, 0.0, TAU, 64, col, lw, true)
			c.draw_colored_polygon(PackedVector2Array([o + Vector2(-s * 0.12, -s * 0.2), o + Vector2(s * 0.22, 0.0), o + Vector2(-s * 0.12, s * 0.2)]), col)
		"engine":
			var r := Rect2(o - Vector2(s * 0.28, s * 0.28), Vector2(s * 0.56, s * 0.56))
			c.draw_rect(r, col, false, lw)
			c.draw_rect(Rect2(o - Vector2(s * 0.1, s * 0.1), Vector2(s * 0.2, s * 0.2)), col, false, lw)
			for i in 3:
				var k: float = -0.16 + 0.16 * float(i)
				c.draw_line(Vector2(o.x + s * k, r.position.y), Vector2(o.x + s * k, r.position.y - s * 0.12), col, lw)
				c.draw_line(Vector2(o.x + s * k, r.end.y), Vector2(o.x + s * k, r.end.y + s * 0.12), col, lw)
				c.draw_line(Vector2(r.position.x, o.y + s * k), Vector2(r.position.x - s * 0.12, o.y + s * k), col, lw)
				c.draw_line(Vector2(r.end.x, o.y + s * k), Vector2(r.end.x + s * 0.12, o.y + s * k), col, lw)
		"player":
			c.draw_arc(o + Vector2(0, -s * 0.18), s * 0.16, 0.0, TAU, 40, col, lw, true)
			c.draw_arc(o + Vector2(0, s * 0.38), s * 0.32, PI * 1.08, PI * 1.92, 40, col, lw, true)
		"developer":
			var pts2 := PackedVector2Array([o + Vector2(0, -s * 0.4), o + Vector2(s * 0.35, -s * 0.2), o + Vector2(s * 0.35, s * 0.2),
				o + Vector2(0, s * 0.4), o + Vector2(-s * 0.35, s * 0.2), o + Vector2(-s * 0.35, -s * 0.2), o + Vector2(0, -s * 0.4)])
			c.draw_polyline(pts2, col, lw, true)
			c.draw_polyline(PackedVector2Array([o + Vector2(-s * 0.35, -s * 0.2), o, o + Vector2(s * 0.35, -s * 0.2)]), col, lw, true)
			c.draw_line(o, o + Vector2(0, s * 0.4), col, lw, true)
		"arrow_left", "arrow_right":
			var d: float = -1.0 if kind == "arrow_left" else 1.0
			c.draw_polyline(PackedVector2Array([o + Vector2(-d * s * 0.12, -s * 0.24), o + Vector2(d * s * 0.12, 0.0), o + Vector2(-d * s * 0.12, s * 0.24)]), col, lw * 1.3, true)


## A row of [icon kind, label] pairs, each icon `size` px with its label under it, from `origin`.
static func icon_row(c: Control, origin: Vector2, size: float, gap: float, items: Array, col: Color, label_px: int) -> void:
	var x: float = origin.x
	var f: Font = LabPrint.font("bold")
	for it in items:
		var kind: String = String(it[0])
		var w: float = size * (1.7 if kind.begins_with("key:") and kind.length() > 5 else 1.0)
		icon(c, kind, Rect2(Vector2(x, origin.y), Vector2(w, size)), col)
		var lw: float = maxf(w, f.get_string_size(String(it[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, label_px).x)
		c.draw_string(f, Vector2(x + w * 0.5 - lw * 0.5, origin.y + size + label_px * 1.35), String(it[1]), HORIZONTAL_ALIGNMENT_CENTER, lw, label_px, col)
		x += maxf(w, lw) + gap
