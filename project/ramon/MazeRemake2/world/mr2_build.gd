extends RefCounted
## THE ANNEX'S BUILDER: turns morph boxes (mr2_morph.gd) into a level's meshes, colliders, doors,
## signs and lights. One builder per level; the level script describes its rooms with it and calls
## finish() once.
##
## EVERY PIECE IS A MORPH BOX IN WORLD SPACE, collected per material and merged into one mesh per
## material at the end (a level is a handful of meshes, not hundreds: every 4D instance costs shader
## instance slots, engine_capabilities.md). Their colliders all go on one StaticBody4D. The grid
## materials are made with grid_offset zero, so the lab's metre grid runs on in world space across
## every piece.
##
## DOORS (door()) are the heart of it: two leaves that slide apart into the wall as you move through
## W, inside a frame that glows in the colour of the W where the door opens. Each door is also
## returned as a record the game reads (where it is, which way it faces, how open it is at a W, the W
## that V aligns you to).
##
## NO class_name (engine_gotchas.md): preload it.

const Morph := preload("res://ramon/MazeRemake2/world/mr2_morph.gd")
const LabGrid := preload("res://ramon/MazeRemake2/carried/lab_grid.gd")
const KitStyle := preload("res://ramon/MazeRemake2/carried/kit_style.gd")
const GlowShader := preload("res://ramon/MazeRemake2/carried/shaders/lab_glow.gdshader")

## The band colours, shared by the floors, the door frames, the gizmo and the signs.
const KATA := Color(0.96, 0.60, 0.18)
const HOME := Color(0.30, 0.55, 1.00)
const ANA := Color(0.10, 0.82, 0.70)
const DEEP := Color(0.66, 0.42, 1.00)

## A passage's plug: how far past its closed range it stays up, and over how much W it sinks.
const SEAM := 0.15
const RISE := 0.4

## Material slots: [swatch, how strongly the W tint shows on it].
const SLOTS := {
	"floor": ["kit_floor", 0.42],
	"wall": ["kit_wall", 0.10],
	"ceiling": ["kit_ceiling", 0.0],
	"blue": ["kit_code_blue", 0.0],
	"leaf": ["kit_screen2", 0.0],
	"metal": ["kit_metal", 0.0],
	"desk": ["kit_desk", 0.0],
	"glass": ["kit_glass", 0.0],
	"cap": ["kit_wall", 0.10],
	"slate": ["slate", 0.12],
	"slate_cap": ["slate", 0.12],
}

var root: Node4D
## The level's W bands as tint stops: {"stops": PackedFloat32Array, "colors": PackedColorArray}.
var tint: Dictionary = {}
var _keys: Dictionary = {}          # slot -> Array of key lists
var _glows: Dictionary = {}         # Color html -> [Color, Array of key lists]
var _colliders: Array = []          # [centre, size]
var doors: Array = []               # door records
var lights: Array[Node4D] = []
var meshes: Dictionary = {}         # slot -> MeshInstance4D
var materials: Dictionary = {}      # slot -> TetraMaterial4D
var body: StaticBody4D


func _init(level_root: Node4D) -> void:
	root = level_root


## A morph box in material `slot`. `collide` false for trims and anything you may walk through.
func add(keys: Array, slot: String = "wall", collide: bool = true) -> void:
	if keys.size() < 2:
		return
	if not _keys.has(slot):
		_keys[slot] = []
	(_keys[slot] as Array).append(keys)
	if collide:
		_colliders.append_array(Morph.collider_boxes(keys))


## A glowing (unshaded) morph box; never collides.
func glow(keys: Array, color: Color) -> void:
	var k: String = color.to_html()
	if not _glows.has(k):
		_glows[k] = [color, []]
	(_glows[k][1] as Array).append(keys)


## A plain box from `lo` to `hi`, standing from W `w0` to `w1` (sinking into the floor over `taper`
## at each end when given).
func box(lo: Vector3, hi: Vector3, w0: float, w1: float, slot: String = "wall", collide: bool = true, taper: float = 0.0) -> void:
	add(Morph.standing(lo, hi, w0, w1, taper), slot, collide)


## A wall along x (from x0 to x1 at z, thickness t) or along z (axis "z": from z0 to z1 at x).
func wall_x(x0: float, x1: float, z: float, w0: float, w1: float, h: float = 3.6, t: float = 0.4, taper: float = 0.0, slot: String = "wall") -> void:
	box(Vector3(minf(x0, x1), 0.0, z - t * 0.5), Vector3(maxf(x0, x1), h, z + t * 0.5), w0, w1, slot, true, taper)


func wall_z(z0: float, z1: float, x: float, w0: float, w1: float, h: float = 3.6, t: float = 0.4, taper: float = 0.0, slot: String = "wall") -> void:
	box(Vector3(x - t * 0.5, 0.0, minf(z0, z1)), Vector3(x + t * 0.5, h, maxf(z0, z1)), w0, w1, slot, true, taper)


## A floor slab with its top at y 0 over the rectangle, from W `w0` to `w1`.
func floor_rect(x0: float, z0: float, x1: float, z1: float, w0: float, w1: float, thick: float = 0.5) -> void:
	box(Vector3(minf(x0, x1), -thick, minf(z0, z1)), Vector3(maxf(x0, x1), 0.0, maxf(z0, z1)), w0, w1, "floor", true)


## A ceiling slab with its underside at `y`.
func ceiling_rect(x0: float, z0: float, x1: float, z1: float, y: float, w0: float, w1: float, thick: float = 0.3) -> void:
	box(Vector3(minf(x0, x1), y, minf(z0, z1)), Vector3(maxf(x0, x1), y + thick, maxf(z0, z1)), w0, w1, "ceiling", true)


## A W cap: a solid filling the footprint, floor to `h`, from W `w0` to `w1`. Never seen from inside a
## room (you cannot get into it), it stops you shifting out of the room's W range. In a view turned
## into W it shows as the building's end wall.
func cap(x0: float, z0: float, x1: float, z1: float, w0: float, w1: float, h: float = 3.6, slot: String = "cap") -> void:
	box(Vector3(minf(x0, x1), 0.0, minf(z0, z1)), Vector3(maxf(x0, x1), h, maxf(z0, z1)), w0, w1, slot, true)


## A downlight at (x, y, z, w) pointing straight down: the lab's spot (creation_lab_tuning.cfg [spot]).
func downlight(at: Vector4, energy: float = 2.0, angle: float = 52.0, reach: float = 9.0, color: Color = Color(0.92, 0.93, 0.95)) -> SpotLight4D:
	var l := SpotLight4D.new()
	l.position = at
	# Lights shine along their local -Z: +Z up makes it shine down.
	var p := Projection.IDENTITY
	p.x = Vector4(1, 0, 0, 0)
	p.y = Vector4(0, 0, -1, 0)
	p.z = Vector4(0, 1, 0, 0)
	p.w = Vector4(0, 0, 0, 1)
	l.basis = p
	l.set("light_energy", energy)
	l.set("light_color", color)
	l.set("spot_angle_degrees", angle)
	l.set("spot_angle_attenuation", 0.42)
	l.set("spot_range_meters", reach)
	l.set("spot_range_attenuation", 0.3)
	l.set_meta("base_energy", energy)
	root.add_child(l)
	lights.append(l)
	return l


func omni(at: Vector4, energy: float = 1.0, reach: float = 6.0, color: Color = Color(1, 0.9, 0.75)) -> OmniLight4D:
	var l := OmniLight4D.new()
	l.position = at
	l.set("light_energy", energy)
	l.set("light_color", color)
	l.set("omni_range_meters", reach)
	l.set("omni_range_attenuation", 0.6)
	l.set_meta("base_energy", energy)
	root.add_child(l)
	lights.append(l)
	return l


## A DOOR THROUGH W. `spec`:
##   at: Vector2 (x, z) centre of the opening at floor level
##   along: "x" if the wall it sits in runs along x (the door faces z), "z" if along z
##   width (1.8), height (2.6), wall (wall thickness, 0.4), leaf (leaf thickness, 0.12)
##   closed_w: the W at which it starts to open; open_w: the W at which it is fully open
##     (open_w > closed_w: it opens going ana; open_w < closed_w: going kata)
##   align_w: where V puts you (default a little past open_w)
##   w_lo, w_hi: the W range the door exists in (its frame and leaves)
##   color: the frame's glow (the band where it opens)
##   name: for the HUD and tests
## The wall either side of the opening is NOT built here (the level builds it, with a gap of `width`);
## each side must be at least width / 2 + 0.1 long so a parked leaf is hidden inside it.
func door(spec: Dictionary) -> Dictionary:
	var at: Vector2 = spec.get("at", Vector2.ZERO)
	var along: String = String(spec.get("along", "x"))
	var width: float = float(spec.get("width", 1.8))
	var height: float = float(spec.get("height", 2.6))
	var wall_t: float = float(spec.get("wall", 0.4))
	var leaf_t: float = float(spec.get("leaf", 0.12))
	var closed_w: float = float(spec["closed_w"])
	var open_w: float = float(spec["open_w"])
	var dir: float = signf(open_w - closed_w)
	var align_w: float = float(spec.get("align_w", open_w + dir * 0.3))
	var w_lo: float = float(spec.get("w_lo", minf(closed_w, open_w) - 6.0))
	var w_hi: float = float(spec.get("w_hi", maxf(closed_w, open_w) + 6.0))
	var color: Color = spec.get("color", ANA)
	var wall_h: float = float(spec.get("wall_h", 3.6))
	var half: float = width * 0.5
	# Keys along W for the leaves: closed on the closed side, parked on the open side.
	var ws: Array = [w_lo, closed_w, open_w, w_hi] if dir > 0.0 else [w_lo, open_w, closed_w, w_hi]
	var parked_first: bool = dir < 0.0
	for side in [-1.0, 1.0]:
		var keys: Array = []
		for i in ws.size():
			var parked: bool = (i <= 1) if parked_first else (i >= 2)
			# Closed: the leaf fills its half of the opening. Parked: slid a full leaf width into the wall.
			var c0: float = 0.0 if side < 0.0 else half
			var c1: float = -half if side < 0.0 else 0.0
			var a: float = minf(c0, c1)
			var b: float = maxf(c0, c1)
			if parked:
				a += side * half
				b += side * half
			# A hair of overlap at the middle when closed, so no crack shows between the leaves.
			if not parked:
				if side < 0.0:
					b += 0.01
				else:
					a -= 0.01
			keys.append(Morph.key(float(ws[i]), _door_lo(at, along, a, 0.0, -leaf_t * 0.5), _door_hi(at, along, b, height, leaf_t * 0.5)))
		add(keys, "leaf", true)
		# The leaf's edge light: a slim glowing strip on its inner edge, moving with it.
		var gkeys: Array = []
		for k in keys:
			var lo: Vector3 = k[1]
			var hi: Vector3 = k[2]
			var e: float = (hi.x if along == "x" else hi.z) if side < 0.0 else (lo.x if along == "x" else lo.z)
			var e0: float = e - 0.025
			var e1: float = e + 0.025
			if along == "x":
				gkeys.append(Morph.key(float(k[0]), Vector3(e0, 0.05, lo.z - 0.01), Vector3(e1, height - 0.05, hi.z + 0.01)))
			else:
				gkeys.append(Morph.key(float(k[0]), Vector3(lo.x - 0.01, 0.05, e0), Vector3(hi.x + 0.01, height - 0.05, e1)))
		glow(gkeys, color.lerp(Color.WHITE, 0.35))
	# The lintel over the opening (solid wall above the door).
	if wall_h > height:
		box(_door_lo(at, along, -half - 0.02, height, -wall_t * 0.5), _door_hi(at, along, half + 0.02, wall_h, wall_t * 0.5), w_lo, w_hi, String(spec.get("slot", "wall")), true)
	# The frame: glowing strips round the opening on both faces, in the colour of where it opens.
	for face in [-1.0, 1.0]:
		var z0: float = face * wall_t * 0.5
		var z1: float = z0 + face * 0.03
		var zz0: float = minf(z0, z1)
		var zz1: float = maxf(z0, z1)
		for s in [-1.0, 1.0]:
			var x0: float = s * half
			var x1: float = s * (half + 0.09)
			glow(Morph.standing(_door_lo(at, along, minf(x0, x1), 0.0, zz0), _door_hi(at, along, maxf(x0, x1), height + 0.09, zz1), w_lo, w_hi), color)
		glow(Morph.standing(_door_lo(at, along, -half - 0.09, height, zz0), _door_hi(at, along, half + 0.09, height + 0.09, zz1), w_lo, w_hi), color)
	var record := {
		"kind": "door",
		"name": String(spec.get("name", "door")),
		"at": Vector3(at.x, height * 0.5, at.y),
		"along": along,
		"normal": Vector3(0, 0, 1) if along == "x" else Vector3(1, 0, 0),
		"width": width,
		"height": height,
		"closed_w": closed_w,
		"open_w": open_w,
		"align_w": align_w,
		"w_lo": w_lo,
		"w_hi": w_hi,
		"color": color,
		"dir": dir,
	}
	doors.append(record)
	return record


## A PASSAGE THROUGH W: a doorway in a wall that is open only in some W ranges. Where it is closed, a
## plug of wall stands in it, rising out of the floor as you shift into the closed range and sinking
## back as you leave it, so the maze rearranges round you. The frame over it glows in the colour of
## every band where it is open, side by side, so a doorway says where it leads before you shift.
## `spec`: at (Vector2 x, z), along ("x" or "z"), width (2.0), height (3.0), wall (0.4), wall_h (4.2),
## open: [[w_lo, w_hi, colour], ...] ascending, w_lo, w_hi (the level's range), name.
## A closed range stands at full height SEAM metres into the open ranges either side and sinks over the
## next RISE, so at a band's edge everything closed on either side is still up: crossing between bands
## you can only pass where both are open (no shortcuts at the seam).
func passage(spec: Dictionary) -> Dictionary:
	var at: Vector2 = spec.get("at", Vector2.ZERO)
	var along: String = String(spec.get("along", "x"))
	var width: float = float(spec.get("width", 2.0))
	var height: float = float(spec.get("height", 3.0))
	var wall_t: float = float(spec.get("wall", 0.4))
	var wall_h: float = float(spec.get("wall_h", 4.2))
	var w_lo: float = float(spec["w_lo"])
	var w_hi: float = float(spec["w_hi"])
	var open: Array = spec.get("open", [])
	var half: float = width * 0.5
	# The closed ranges: the gaps between the open ones.
	var closed: Array = []
	var cur: float = w_lo
	for o in open:
		if float(o[0]) > cur + 0.001:
			closed.append([cur, float(o[0])])
		cur = maxf(cur, float(o[1]))
	if cur < w_hi - 0.001:
		closed.append([cur, w_hi])
	var plugs: Array = []
	var lo3: Vector3 = _door_lo(at, along, -half - 0.02, 0.0, -wall_t * 0.5 + 0.01)
	var hi3: Vector3 = _door_hi(at, along, half + 0.02, height + 0.02, wall_t * 0.5 - 0.01)
	var sunk_lo := Vector3(lo3.x, -0.06, lo3.z)
	var sunk_hi := Vector3(hi3.x, -0.02, hi3.z)
	for c in closed:
		var a: float = float(c[0])
		var b: float = float(c[1])
		var keys: Array = []
		if a > w_lo + 0.001:
			keys.append(Morph.key(a - SEAM - RISE, sunk_lo, sunk_hi))
			keys.append(Morph.key(a - SEAM, lo3, hi3))
		else:
			keys.append(Morph.key(w_lo - 1.0, lo3, hi3))
		if b < w_hi - 0.001:
			keys.append(Morph.key(b + SEAM, lo3, hi3))
			keys.append(Morph.key(b + SEAM + RISE, sunk_lo, sunk_hi))
		else:
			keys.append(Morph.key(w_hi + 1.0, lo3, hi3))
		add(keys, String(spec.get("slot", "wall")), true)
		plugs.append(keys)
	# The lintel.
	if wall_h > height:
		box(_door_lo(at, along, -half - 0.02, height, -wall_t * 0.5), _door_hi(at, along, half + 0.02, wall_h, wall_t * 0.5), w_lo - 1.0, w_hi + 1.0, String(spec.get("slot", "wall")), true)
	# The frame: a stripe over the opening per open band, side by side; the jambs glow in the first.
	var n: int = maxi(1, open.size())
	for face in [-1.0, 1.0]:
		var z0: float = face * wall_t * 0.5
		var z1: float = z0 + face * 0.03
		var zz0: float = minf(z0, z1)
		var zz1: float = maxf(z0, z1)
		for i in open.size():
			var col: Color = open[i][2]
			var x0: float = -half - 0.09 + (width + 0.18) * float(i) / n
			var x1: float = -half - 0.09 + (width + 0.18) * float(i + 1) / n
			glow(Morph.standing(_door_lo(at, along, x0, height, zz0), _door_hi(at, along, x1, height + 0.12, zz1), w_lo - 1.0, w_hi + 1.0), col)
		for s in [-1.0, 1.0]:
			var xa: float = s * half
			var xb: float = s * (half + 0.06)
			var jc: Color = (open[0][2] if s < 0.0 else open[open.size() - 1][2]) if open.size() > 0 else Color(0.5, 0.5, 0.5)
			glow(Morph.standing(_door_lo(at, along, minf(xa, xb), 0.0, zz0), _door_hi(at, along, maxf(xa, xb), height, zz1), w_lo - 1.0, w_hi + 1.0), Color(jc, 1.0).lerp(Color(0.6, 0.62, 0.66), 0.35))
	var record := {
		"kind": "passage",
		"name": String(spec.get("name", "passage")),
		"at": Vector3(at.x, height * 0.5, at.y),
		"along": along,
		"width": width,
		"height": height,
		"open": open,
		"plugs": plugs,
		"w_lo": w_lo - 1.0,
		"w_hi": w_hi + 1.0,
		"color": open[0][2] if open.size() > 0 else HOME,
		"align_w": (float(open[0][0]) + float(open[0][1])) * 0.5 if open.size() > 0 else 0.0,
	}
	doors.append(record)
	return record


## How open a door or passage record is at W `w`, 0 to 1 (0 outside its W range).
static func openness(d: Dictionary, w: float) -> float:
	if w < float(d["w_lo"]) or w > float(d["w_hi"]):
		return 0.0
	if String(d.get("kind", "door")) == "passage":
		var up: float = 0.0
		var full: float = float(d["height"])
		for keys in d["plugs"]:
			var b: Array = Morph.box_at(keys, w)
			if not b.is_empty():
				up = maxf(up, clampf((b[1] as Vector3).y / maxf(full, 0.01), 0.0, 1.0))
		return 1.0 - up
	var a: float = float(d["closed_w"])
	var bb: float = float(d["open_w"])
	return clampf((w - a) / (bb - a), 0.0, 1.0)


## Where V takes you for this record from W `w`: a door's own align W; for a passage, the middle of
## the open range nearest you.
static func align_for(d: Dictionary, w: float) -> float:
	if String(d.get("kind", "door")) != "passage":
		return float(d["align_w"])
	var best: float = float(d["align_w"])
	var bd: float = INF
	for o in d["open"]:
		var c: float = (float(o[0]) + float(o[1])) * 0.5
		if absf(c - w) < bd:
			bd = absf(c - w)
			best = c
	return best


## The colour of the open range nearest W `w` (a passage's frame stripe you are heading for).
static func color_for(d: Dictionary, w: float) -> Color:
	if String(d.get("kind", "door")) != "passage":
		return d["color"]
	var best: Color = d["color"]
	var bd: float = INF
	for o in d["open"]:
		var dist: float = 0.0 if (w >= float(o[0]) and w <= float(o[1])) else minf(absf(w - float(o[0])), absf(w - float(o[1])))
		if dist < bd:
			bd = dist
			best = o[2]
	return best


func _door_lo(at: Vector2, along: String, a: float, y: float, d: float) -> Vector3:
	return Vector3(at.x + a, y, at.y + d) if along == "x" else Vector3(at.x + d, y, at.y + a)


func _door_hi(at: Vector2, along: String, b: float, y: float, d: float) -> Vector3:
	return Vector3(at.x + b, y, at.y + d) if along == "x" else Vector3(at.x + d, y, at.y + b)


## A sign: a thin box with text printed on its `normal` face. The texture comes later (LabPrint is
## asynchronous); set it with LabGrid.set_print on the returned material.
func sign(lo: Vector3, hi: Vector3, w0: float, w1: float, slot: String = "blue") -> MeshInstance4D:
	var size := Vector4(hi.x - lo.x, hi.y - lo.y, hi.z - lo.z, w1 - w0)
	var centre := Vector4((lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5, (lo.z + hi.z) * 0.5, (w0 + w1) * 0.5)
	var mi := MeshInstance4D.new()
	var bm := BoxTetraMesh4D.new()
	bm.size = size
	mi.mesh = bm
	mi.position = centre
	mi.material_override = LabGrid.material(String(SLOTS.get(slot, SLOTS["blue"])[0]), size, centre)
	root.add_child(mi)
	return mi


## Builds every mesh and the one body. Call once, after the level has added everything.
func finish() -> void:
	for slot in _keys:
		var merged: ArrayTetraMesh4D = null
		for keys in _keys[slot]:
			var m: ArrayTetraMesh4D = Morph.mesh(keys)
			if m == null:
				continue
			if merged == null:
				merged = m
			else:
				merged.merge_with(m)
		if merged == null:
			continue
		var mi := MeshInstance4D.new()
		mi.name = "Mesh_" + String(slot)
		mi.mesh = merged
		var sw: Array = SLOTS.get(slot, SLOTS["wall"])
		var mat: TetraMaterial4D = LabGrid.material(String(sw[0]), Vector4(1, 1, 1, 1), Vector4.ZERO)
		if float(sw[1]) > 0.0 and tint.has("stops"):
			LabGrid.set_wtint(mat, tint["stops"], tint["colors"], float(sw[1]))
		mi.material_override = mat
		materials[slot] = mat
		meshes[slot] = mi
		root.add_child(mi)
	var gi: int = 0
	for k in _glows:
		var color: Color = _glows[k][0]
		var merged: ArrayTetraMesh4D = null
		for keys in _glows[k][1]:
			var m: ArrayTetraMesh4D = Morph.mesh(keys)
			if m == null:
				continue
			if merged == null:
				merged = m
			else:
				merged.merge_with(m)
		if merged == null:
			continue
		var mi := MeshInstance4D.new()
		mi.name = "Glow_%d" % gi
		gi += 1
		mi.mesh = merged
		mi.material_override = glow_material(color)
		root.add_child(mi)
	body = StaticBody4D.new()
	body.name = "Solids"
	root.add_child(body)
	for c in _colliders:
		var cs := CollisionShape4D.new()
		var shape := BoxShape4D.new()
		shape.size = c[1]
		cs.shape = shape
		cs.position = c[0]
		body.add_child(cs)


## An unshaded material in `color` (lab_glow.gdshader): the only way to look lit in this renderer.
static func glow_material(color: Color, energy: float = 1.0) -> TetraMaterial4D:
	var m := TetraMaterial4D.new()
	var cs: ShaderMaterial = m.get_cross_section_material_3d()
	cs.shader = GlowShader
	m.albedo_color = Color.WHITE
	cs.set_shader_parameter("glow_color", color)
	cs.set_shader_parameter("glow_energy", energy)
	return m


## How many collider boxes the level has (the tests read it).
func collider_count() -> int:
	return _colliders.size()
