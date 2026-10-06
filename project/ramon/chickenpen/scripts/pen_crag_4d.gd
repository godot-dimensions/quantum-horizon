@tool
extends Node4D

## A crag built by the rock hierarchy (PenLayout/PLAN_REF_LOCK.md step 14; Ramon, 6 Oct: "the
## rocks in the towerthing should be a bit hyrachical. one large rock as base. medium rock forming
## on side. smaller rocks that follow natural regression and debree. think logically").
##
## FOUR LEVELS, EACH RESTING ON THE ONE BEFORE (PenLayout/refs/analysis/rock_system.png):
##   L1 the core: the crag's mass, course by course, a dark drum that shows only in the joints
##      between the stones; it sets the outline and carries the colliders.
##   L2 the face blocks: medium designed-cut stones (terrain/cut_stone_4d.gd) round each course,
##      upright, either one tall block filling the course or two stacked; their outer faces at the
##      course's radius, a hand's breadth in or out.
##   L3 ledge stones: small and flat, on each ledge where a course steps in, where grass gathers.
##   L4 debris: fallen from the face, big near the foot and smaller and fewer further out, in
##      clusters, half sunk.
## The green is on the stones themselves (Ramon, 6 Oct: "remove the green clumps ... it should be a
## combination of a texture shader that goes from rock to green on top of a rock, in combinations
## with rocks that are just a grey rock"): the spec's "moss" share of the stones are the mossy-top
## variants (terrain/cut_stone_4d.gd moss_colour, grey sides turning green over the top), the rest
## plain grey. Grass clumps and ledge turf only where the spec asks for them ("tufts", "ledge_turf").
##
## THE SPEC (a JSON file, [member spec_path]) holds the measured shape: each course's heights and its
## radius at eight bearings (E, SE, S, SW, W, NW, N, NE; angles from +x toward +z, so S is +z), the
## top, the debris ring, the counts. It is written from the reference by measurement
## (PenLayout/RefLock), so the shape comes from the painting and not from a guess.
##
## One mesh for every stone and tuft (merged, pen_stone_set_4d.gd), one for the core and turf.
## Built when it loads (and in the editor). NO class_name (engine_gotchas.md).

const TerrainBake := preload("res://ramon/chickenpen/terrain/terrain_bake_4d.gd")
const CutStone := preload("res://ramon/chickenpen/terrain/cut_stone_4d.gd")
const StoneSet := preload("res://ramon/chickenpen/scripts/pen_stone_set_4d.gd")
const MainGreen := preload("res://ramon/chickenpen/terrain/main_green_4d.gd")
const OWN := &"_crag_part"
const TUFTS := 6

@export_tool_button("Rebuild") var _rebuild_action: Callable = rebuild
@export_file("*.json") var spec_path: String = "": set = _set_spec
@export var solid: bool = true
## Leave out the grass disc round the foot (in the pen, the pen's own ground is there).
@export var ground_disc: bool = true: set = _set_disc
## Off once the stones are nodes in the scene (the Watchstone's "Bake every stone into the scene",
## Ramon, 6 Oct: "i want to be able to move all the stones"): the crag then builds its colliders,
## turf and ground, and the stones are the scene's.
@export var procedural_stones: bool = true: set = _set_procedural
## Walkways in front of the rock: [points (Vector4, deck height in y), half width] each. Wherever
## one runs in front of a course, from just below its deck to [member headroom] above, the course
## steps back behind it (a terrace cut for the timber), and the stones go with it.
@export var clear_paths: Array = []: set = _set_clear
@export_range(0.0, 4.0, 0.1, "suffix:m") var headroom: float = 2.0
@export_range(0.0, 2.0, 0.05, "suffix:m") var clearance: float = 0.35

## Per course, the face radius every half degree with the walkways' terraces cut in.
var _faces_table: Array = []
## Stones let stand proud of the plateau so far, this build.
var _proud: int = 0
const TABLE := 720

var spec: Dictionary = {}
var _pending: bool = false
var _rng := RandomNumberGenerator.new()
var _stones: Array = []
var _tufts: Array = []
var _boxes: Dictionary = {}
## The box colours that are turf (the spec's turf_colour, the top's, the ground disc's): drawn in the
## main green while the pen shows it (terrain/main_green_4d.gd).
var _turf_keys: Dictionary = {}
var _body: StaticBody4D


func _set_spec(v: String) -> void:
	spec_path = v
	_later()


func _set_disc(v: bool) -> void:
	ground_disc = v
	_later()


func _set_procedural(v: bool) -> void:
	procedural_stones = v
	_later()


## The stones as laid out by the last build: [kind, variant, centre, scale, yaw, tilt, basis or null,
## group], the group the part of the crag it belongs to (Course 0, Inner, Ledges, Rim, Debris...).
func stone_layout() -> Array:
	return _stones


var _stone_group: String = "Stones"


func _set_clear(v: Array) -> void:
	clear_paths = v
	_later()


func _ready() -> void:
	add_to_group(MainGreen.GROUP)
	rebuild()


## The main green changed, or was switched on or off: the turf takes it, or its own colours back.
func main_green_changed(c: Color, _baked: bool) -> void:
	for node in get_children():
		if node.has_meta(&"turf") and node is MeshInstance4D:
			var m := (node as MeshInstance4D).material_override as TetraMaterial4D
			if m != null:
				m.albedo_color = c if MainGreen.on else Color.html(String(node.get_meta(&"turf")))


func _later() -> void:
	if not is_node_ready() or _pending:
		return
	_pending = true
	rebuild.call_deferred()


func rebuild() -> void:
	_pending = false
	for c in get_children():
		if c.has_meta(OWN):
			remove_child(c)
			c.queue_free()
	if spec_path == "" or not FileAccess.file_exists(spec_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(spec_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Crag: the spec at %s is not readable" % spec_path)
		return
	spec = parsed
	_rng.seed = int(spec.get("seed", 7))
	_stones = []
	_tufts = []
	_boxes = {}
	_body = null
	if solid and not Engine.is_editor_hint():
		_body = StaticBody4D.new()
		_body.name = "Solid"
		_own(_body)
	var courses: Array = spec["courses"]
	_proud = 0
	_cut_terraces(courses)
	_monoliths(courses)
	if bool(spec.get("only_monoliths", false)):
		_flush()
		return
	for i in courses.size():
		_stone_group = "Inner"
		if bool(courses[i].get("core", true)):
			_core(courses[i], i)
		_stone_group = "Course%d" % i
		_faces(courses[i], i)
		var above: Variant = courses[i + 1] if i + 1 < courses.size() else null
		_stone_group = "Ledges"
		_ledge(courses[i], above, i)
	_stone_group = "Rim"
	_top(courses[courses.size() - 1])
	_stone_group = "Debris"
	_debris(courses[0])
	if ground_disc:
		_disc(courses[0])
	_flush()


# --- The shape ---------------------------------------------------------------------------------

## The face radius of course [param index] at bearing [param a], terraces cut in.
func face(index: int, a: float) -> float:
	if index >= _faces_table.size():
		return radius(spec["courses"][index], a)
	var t: float = fposmod(a, TAU) / TAU * float(TABLE)
	var i: int = int(t) % TABLE
	return lerpf(float(_faces_table[index][i]), float(_faces_table[index][(i + 1) % TABLE]), t - floor(t))


## The terraces: each course's radius sampled round, then cut back wherever a walkway runs in front
## of it within its height (from 0.3 below the deck to [member headroom] above).
func _cut_terraces(courses: Array) -> void:
	_faces_table = []
	for course in courses:
		var row := PackedFloat32Array()
		row.resize(TABLE)
		for k in TABLE:
			row[k] = radius(course, TAU * float(k) / float(TABLE))
		var y0: float = course["y0"]
		var y1: float = course["y1"]
		for path in clear_paths:
			var pts: Array = path[0]
			var half: float = float(path[1])
			for i in pts.size() - 1:
				var a: Vector4 = pts[i]
				var b: Vector4 = pts[i + 1]
				var n: int = maxi(2, int((b - a).length() / 0.25))
				for j in n + 1:
					var p: Vector4 = a.lerp(b, float(j) / float(n))
					if y0 > p.y + headroom or y1 < p.y - 0.3:
						continue
					var r: float = Vector2(p.x, p.z).length()
					var bearing: float = atan2(p.z, p.x)
					var limit: float = r - half - clearance
					var spread: float = (half + clearance) / maxf(r, 0.5)
					var k0: int = int(floor((bearing - spread) / TAU * float(TABLE)))
					var k1: int = int(ceil((bearing + spread) / TAU * float(TABLE)))
					for k in range(k0, k1 + 1):
						var kk: int = posmod(k, TABLE)
						row[kk] = minf(row[kk], maxf(limit, 0.8))
		_faces_table.append(row)


## Whether (x, z) is under or beside a walkway (within [param margin] of its middle line's
## half width): no debris there.
func _in_clear(x: float, z: float, margin: float) -> bool:
	for path in clear_paths:
		var pts: Array = path[0]
		for i in pts.size() - 1:
			var a := Vector2((pts[i] as Vector4).x, (pts[i] as Vector4).z)
			var b := Vector2((pts[i + 1] as Vector4).x, (pts[i + 1] as Vector4).z)
			var ab: Vector2 = b - a
			var t: float = clampf((Vector2(x, z) - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
			if (a + ab * t).distance_to(Vector2(x, z)) < float(path[1]) + margin:
				return true
	return false


## A course's face radius at bearing [param a] (radians from +x toward +z), from its eight.
static func radius(course: Dictionary, a: float) -> float:
	var r: Array = course["r"]
	var t: float = fposmod(a, TAU) / (TAU / 8.0)
	var i: int = int(floor(t)) % 8
	var f: float = t - floor(t)
	# Smooth between the bearings (a cosine blend), so the outline has no corners at them.
	f = 0.5 - 0.5 * cos(f * PI)
	return lerpf(float(r[i]), float(r[(i + 1) % 8]), f)


func _dir(a: float) -> Vector4:
	return Vector4(cos(a), 0.0, sin(a), 0.0)


## The way a stone at bearing [param a] faces: out, its local +z toward the outside.
static func _face_yaw(a: float) -> float:
	return atan2(cos(a), sin(a))


# --- The big chunks ----------------------------------------------------------------------------

## The spec's "monoliths": single stones standing a large share of the crag's height in its face,
## [bearing (degrees from +x toward +z), height, width, depth, kind]. Each stands on the ground with
## its outer face at the base course's, and leans in with the crag's taper so its top meets the face
## where the courses have it at that height: one chunk, through the courses, the outline unchanged.
var _monolith_spans: Array = []
## Chunk nodes standing against the crag (pen_crag_chunk_4d.gd, placed by hand in the editor): the
## crag clears its face stones where each stands, as for the spec's monoliths.
var chunks: Array = []


func _monoliths(courses: Array) -> void:
	_monolith_spans = []
	for c in chunks:
		var node := c as Node4D
		if node == null or not is_instance_valid(node) or not node.has_method("footprint"):
			continue
		var fp: Dictionary = node.call("footprint", self)
		var a: float = atan2(float(fp["z"]), float(fp["x"]))
		var r: float = maxf(Vector2(float(fp["x"]), float(fp["z"])).length(), 1.0)
		_monolith_spans.append([a, float(fp["width"]) * 0.5 * 0.7 / r, float(fp["height"]) - 0.6])
	for m in spec.get("monoliths", []):
		var a: float = deg_to_rad(float(m["bearing"]))
		var h: float = float(m["height"])
		# Buried at the foot (Ramon: "the bottom can burry underground, so the shape becomes nice"): the
		# stone runs [bury] metres below the ground, so its rounded underside is out of sight.
		var bury: float = float(m.get("bury", spec.get("bury", 1.6)))
		var wdt: float = float(m["width"])
		var dep: float = float(m["depth"])
		var kind: String = String(m.get("kind", "pillar"))
		# The course at its top.
		var top_index: int = 0
		for i in courses.size():
			if float(courses[i]["y0"]) <= h:
				top_index = i
		# Proud of the face ([proud] metres), so it reads as one mass standing out of the courses, not a
		# stone among them (Ramon, 6 Oct: "i still dont see a rock chunck thats 70%").
		var proud: float = float(m.get("proud", spec.get("monolith_proud", 0.6)))
		var r_foot: float = face(0, a) + proud - dep * 0.5
		var r_top: float = face(top_index, a) + proud * 0.6 - dep * 0.5
		var lean: float = atan2(r_foot - r_top, h)
		var out := Vector4(cos(a), 0, sin(a), 0)
		var up := Vector4(0, 1, 0, 0)
		var tangent := Vector4(-sin(a), 0, cos(a), 0)
		var up_l: Vector4 = up * cos(lean) - out * sin(lean)
		var out_l: Vector4 = out * cos(lean) + up * sin(lean)
		var half: Vector4 = CutStone.KINDS[kind][0]
		var scale := Vector4(wdt / (2.0 * half.x), (h + bury) / (2.0 * half.y), dep / (2.0 * half.z), float(spec.get("w_depth", 6.0)) * 0.6 / (2.0 * half.w))
		var basis := Projection(tangent * scale.x, up_l * scale.y, out_l * scale.z, Vector4(0, 0, 0, scale.w))
		var centre: Vector4 = out * ((r_foot + r_top) * 0.5) + up_l * ((h - bury) * 0.5) + Vector4(0, 0, 0, 0)
		var mossy: bool = bool(m.get("moss", true))
		_stones.append([kind + ("_moss" if mossy else ""), _rng.randi() % CutStone.VARIANTS, centre, scale, 0.0, Vector2.ZERO, basis, "Monoliths"])
		_monolith_spans.append([a, (wdt * 0.5 * 0.7) / maxf(r_foot, 1.0), h - 0.6])
		_solid(Vector4(wdt * 0.8, h, wdt * 0.8, float(spec.get("w_depth", 6.0)) * 0.6), centre)


## Whether a face block at bearing [param a] starting at height [param y] is where a big chunk stands.
func _behind_monolith(a: float, y: float) -> bool:
	for span in _monolith_spans:
		var d: float = absf(wrapf(a - float(span[0]), -PI, PI))
		if d < float(span[1]) and y < float(span[2]):
			return true
	return false


# --- L1 the core --------------------------------------------------------------------------------

## The course's mass. With the spec's "core": "stones" (the Watchstone, since Ramon's "eventually you
## have to remove those blockout insides"), an inner ring of big plain stones behind the face blocks
## and a few more in the middle, so a gap between face blocks shows rock behind rock; otherwise a
## drum of turned boxes a little inside the face. Either way, two crossed colliders.
func _core(course: Dictionary, index: int) -> void:
	var y0: float = course["y0"]
	var y1: float = course["y1"]
	if String(spec.get("core", "boxes")) == "stones":
		_core_stones(course, index)
		_core_colliders(course, index)
		return
	var inset: float = float(spec.get("core_inset", 0.45))
	var wd: float = float(spec.get("w_depth", 6.0))
	var n: int = 12
	for k in n:
		var a: float = TAU * float(k) / float(n)
		var r: float = face(index, a) - inset
		var r2: float = face(index, a + PI) - inset
		var mid: float = (r - r2) * 0.5
		var half: float = (r + r2) * 0.5
		var face: float = 2.0 * half * tan(PI / float(n)) * 1.1
		var at: Vector4 = _dir(a) * mid + Vector4(0, (y0 + y1) * 0.5, 0, 0)
		_box(Color(spec.get("core_colour", "#3d3a36")), Vector4(half * 2.0, y1 - y0, face, wd), at, _turn_y(-a))
	_core_colliders(course, index)


## The inner ring: big plain stones (no moss: they sit in shadow) a stone's depth in from the face,
## each the course's full height, and a ring of them again further in on the wider courses.
func _core_stones(course: Dictionary, index: int) -> void:
	var y0: float = course["y0"]
	var y1: float = course["y1"]
	# Up to the course's top and a little over, never through the plateau's turf.
	var tall: float = minf(y1 - y0 + 0.4, float(spec["top"]["y"]) - 0.08 - (y0 - 0.2))
	if tall < 0.3:
		return
	var wd: float = float(spec.get("w_depth", 6.0))
	for ring in [1.6, 3.4]:
		var a: float = _rng.randf_range(0.0, TAU)
		var start: float = a
		while a < start + TAU - 0.05:
			var r: float = face(index, a) - ring
			if r < 1.2:
				break
			var w: float = _rng.randf_range(2.4, 3.2)
			var step: float = w * 0.85 / r
			var mid: float = a + step * 0.5
			var half: Vector4 = (CutStone.KINDS["block"][0] as Vector4)
			var size := Vector3(w, tall, w * 0.9)
			var scale := Vector4(size.x / (2.0 * half.x), size.y / (2.0 * half.y), size.z / (2.0 * half.z), wd * 0.8 / (2.0 * half.w))
			var at: Vector4 = _dir(mid) * r + Vector4(0, y0 - 0.2 + tall * 0.5, 0, _rng.randf_range(-0.4, 0.4))
			_stones.append([["block", "round"][_rng.randi() % 2], _rng.randi() % CutStone.VARIANTS, at, scale, _face_yaw(mid) + _rng.randf_range(-0.2, 0.2), Vector2.ZERO, null, _stone_group])
			a += step
	# The middle, on the courses wide enough to leave one.
	if face(index, 0.0) > 5.2:
		var half: Vector4 = (CutStone.KINDS["round"][0] as Vector4)
		var size := Vector3(3.6, tall, 3.6)
		var scale := Vector4(size.x / (2.0 * half.x), size.y / (2.0 * half.y), size.z / (2.0 * half.z), wd * 0.8 / (2.0 * half.w))
		_stones.append(["round", _rng.randi() % CutStone.VARIANTS, Vector4(0, y0 - 0.2 + tall * 0.5, 0, 0), scale, _rng.randf_range(0.0, TAU), Vector2.ZERO, null, _stone_group])


func _core_colliders(course: Dictionary, index: int) -> void:
	var y0: float = course["y0"]
	var y1: float = course["y1"]
	var wd: float = float(spec.get("w_depth", 6.0))
	if _body != null:
		var rx: float = (face(index, 0.0) + face(index, PI)) * 0.5
		var rz: float = (face(index, PI * 0.5) + face(index, PI * 1.5)) * 0.5
		var cx: float = (face(index, 0.0) - face(index, PI)) * 0.5
		var cz: float = (face(index, PI * 0.5) - face(index, PI * 1.5)) * 0.5
		var fill: float = float(spec.get("collider_fill", 0.86))
		for long in 2:
			var size := Vector4(rx * 2.0 * (fill if long == 0 else 0.62), y1 - y0, rz * 2.0 * (0.62 if long == 0 else fill), wd)
			_solid(size, Vector4(cx, (y0 + y1) * 0.5, cz, 0))


# --- L2 the face blocks -------------------------------------------------------------------------

## Round the course, block after block: one tall stone filling the course, or two stacked, each
## sized from the painting's spread (refs/measure/watchstone_front_stones.json).
func _faces(course: Dictionary, index: int) -> void:
	var y0: float = course["y0"]
	var y1: float = course["y1"]
	var tall: float = y1 - y0
	var kinds: Array = course.get("kinds", ["block", "round", "slab", "wedge"])
	var stack: float = float(course.get("stack", 0.35))
	var jt: Array = spec.get("joint", [0.08, 0.22])
	var joint: Vector2 = Vector2(float(jt[0]), float(jt[1]))
	var a: float = _rng.randf_range(0.0, TAU)
	var start: float = a
	var wd: float = float(spec.get("w_depth", 6.0))
	var scale_w: float = float(course.get("width_scale", 1.0))
	while a < start + TAU - 0.02:
		var r: float = face(index, a)
		var two: bool = _rng.randf() < stack and tall > 1.6
		# Not masonry: a stone may stand proud of its course or fall short of it, and overlaps the
		# one above (the painting's courses blur into each other).
		var h: float = tall * (_rng.randf_range(0.8, 1.22) if not two else _rng.randf_range(0.9, 1.08)) / (2.0 if two else 1.0)
		# The painting's stones are about as wide as they are tall (refs/measure: height over width
		# 1.1-1.2), pillowy, never columns.
		var w: float = h * (_rng.randf_range(1.0, 1.4) if two else _rng.randf_range(0.78, 1.05)) * scale_w
		w = clampf(w, 0.9, 3.2)
		var step: float = (w + _rng.randf_range(joint.x, joint.y)) / maxf(r, 1.0)
		var mid: float = a + step * 0.5
		var rows: int = 2 if two else 1
		var keep: float = float(course.get("keep", 1.0))
		if keep < 1.0 and _rng.randf() > keep:
			rows = 0
		# Where a big chunk stands, the course gives way to it (below its top).
		if _behind_monolith(mid, y0):
			rows = 0
		for row in rows:
			var hh: float = h * _rng.randf_range(0.94, 1.04)
			# Not through the plateau's turf, but for the spec's "proud" stones (Ramon: "one or two stones can
			# potrude on the terrase, kinda looks good"): the first that would, near the rim, stand up to
			# [proud_height] above it.
			var roof: float = float(spec["top"]["y"]) + 0.05 - (y0 + float(row) * h)
			var near_rim: bool = face(index, mid) - w * 0.4 > float(spec["top"]["turf_r"]) - 1.4
			if hh > roof and near_rim and _proud < int(spec["top"].get("proud", 0)):
				hh = minf(hh, roof + float(spec["top"].get("proud_height", 0.9)))
				_proud += 1
			else:
				hh = minf(hh, maxf(roof, 0.3))
			var ww: float = w * _rng.randf_range(0.9, 1.05)
			var d: float = ww * _rng.randf_range(0.7, 0.95)
			# Proud of the face more at mid-course than at its top and foot: the courses bulge.
			var out: float = _rng.randf_range(-0.1, 0.3) + (0.2 if not two else 0.1)
			var rr: float = face(index, mid) - d * 0.5 + out
			# Never above what it stands on (the rest-on rule): sunk a little into the course below.
			var base: float = y0 + float(row) * h + _rng.randf_range(-0.3, 0.0)
			var kind: String = kinds[_rng.randi() % kinds.size()]
			var at: Vector4 = _dir(mid) * rr + Vector4(0, base, 0, _rng.randf_range(-0.5, 0.5))
			_stone(kind, at, Vector3(ww, hh, d), _rng.randf_range(wd * 0.4, wd * 0.6), _face_yaw(mid) + _rng.randf_range(-0.12, 0.12),
				Vector2(_rng.randf_range(-0.05, 0.05), _rng.randf_range(-0.07, 0.03)))
			# Grass: in some joints, on some tops.
			if _rng.randf() < float(spec.get("tuft_on_top", 0.45)):
				for t in 1:
					_tuft(_dir(mid + _rng.randf_range(-0.08, 0.08)) * (rr + d * _rng.randf_range(-0.1, 0.4)) + Vector4(0, base + hh * 0.9, 0, _rng.randf_range(-0.3, 0.3)),
						_rng.randf_range(0.8, 1.7) * float(spec.get("tuft_scale", 1.0)))
		if _rng.randf() < float(spec.get("tuft_in_joint", 0.4)):
			var ja: float = a + step
			for t in 1:
				_tuft(_dir(ja) * (face(index, ja) + 0.1) + Vector4(0, y0 + tall * _rng.randf_range(0.1, 0.9), 0, 0), _rng.randf_range(0.7, 1.5) * float(spec.get("tuft_scale", 1.0)))
		a += step


# --- L3 the ledges ------------------------------------------------------------------------------

## Where this course steps in under the next: turf on the ledge, grass along it, small flat stones
## lying on it. [param above] is the next course (or null for the top course, which _top does).
func _ledge(course: Dictionary, above: Variant, index: int) -> void:
	if above == null:
		return
	var y: float = course["y1"]
	var n: int = 32
	for k in n:
		var a: float = TAU * float(k) / float(n)
		var outer: float = face(index, a) + 0.1
		var inner: float = face(index + 1, a) - 0.6
		var width: float = outer - inner
		if width < 0.4:
			continue
		var mid: float = (outer + inner) * 0.5
		var arc: float = TAU * mid / float(n) * _rng.randf_range(0.7, 1.25)
		# Turf in patches along the ledge, not a ring: some stretches bare stone, some thick.
		if bool(spec.get("ledge_turf", true)) and _rng.randf() > float(spec.get("turf_gaps", 0.35)):
			_box(_turf(spec.get("turf_colour", "#6f8a22")), Vector4(arc, _rng.randf_range(0.18, 0.4), width * _rng.randf_range(0.6, 1.0), float(spec.get("w_depth", 6.0)) * 0.9),
				_dir(a) * (mid + _rng.randf_range(-0.2, 0.2)) + Vector4(0, y + _rng.randf_range(-0.05, 0.08), 0, 0), _turn_y(-a - PI * 0.5 + _rng.randf_range(-0.15, 0.15)))
		var ledge: float = width - 0.6
		if ledge > 0.5:
			for t in int(ledge * float(spec.get("ledge_tufts", 1.6))) + 1:
				var r: float = _rng.randf_range(inner + 0.6, outer - 0.15)
				var b: float = a + _rng.randf_range(-0.1, 0.1)
				_tuft(_dir(b) * r + Vector4(0, y + 0.15, 0, _rng.randf_range(-0.6, 0.6)), _rng.randf_range(1.3, 2.3) * float(spec.get("tuft_scale", 1.0)))
			if _rng.randf() < float(spec.get("ledge_stones", 0.35)):
				var r2: float = _rng.randf_range(inner + 0.7, outer - 0.3)
				var s: float = _rng.randf_range(0.5, 0.9)
				_stone(["ledge", "chip", "cap"][_rng.randi() % 3], _dir(a) * r2 + Vector4(0, y + 0.05, 0, _rng.randf_range(-0.6, 0.6)),
					Vector3(s * 1.3, s * 0.55, s), s * 2.0, _rng.randf_range(0.0, TAU), Vector2(_rng.randf_range(-0.08, 0.08), _rng.randf_range(-0.08, 0.08)))


# --- The top -------------------------------------------------------------------------------------

## The plateau: a turf disc on the top course, a ring of cap stones round its edge just below, and
## a few tufts on it as the painting has.
func _top(course: Dictionary) -> void:
	var top: Dictionary = spec["top"]
	var y: float = top["y"]
	var r: float = top["turf_r"]
	var wd: float = float(top.get("w_depth", spec.get("w_depth", 6.0)))
	var sides: int = 16
	var face: float = 2.0 * r * tan(PI / float(sides)) * 1.03
	for k in sides / 2:
		var t: float = PI * float(k) / float(sides / 2)
		# The turf: a thin layer ([member spec] top "thickness"), the stones of the top course coming up to
		# meet its edge (a thick slab read as a lid laid on the rock).
		var th: float = float(top.get("thickness", 0.5))
		_box(_turf(top.get("turf_colour", "#7d9a26")), Vector4(r * 2.0, th, face, wd), Vector4(0, y - th * 0.5, 0, 0), _turn_y(t))
		if bool(top.get("edge", true)):
			_box(_turf(spec.get("turf_colour", "#6f8a22")), Vector4(r * 2.0 + 0.25, 0.35, face + 0.12, wd - 0.2), Vector4(0, y - 0.55, 0, 0), _turn_y(t))
	if _body != null:
		_solid(Vector4(r * 2.0, 0.6, r * 2.0, wd), Vector4(0, y - 0.3, 0, 0))
	# The ring of stones under the rim.
	var ring: int = int(top.get("rim_stones", 18))
	for k in ring:
		var a: float = TAU * (float(k) + _rng.randf_range(-0.2, 0.2)) / float(ring)
		var rs: Array = top.get("rim_size", [0.9, 1.25])
		var s: float = _rng.randf_range(float(rs[0]), float(rs[1]))
		var rr: float = r + _rng.randf_range(-0.25, 0.05)
		_stone(["block", "round", "cap"][_rng.randi() % 3], _dir(a) * rr + Vector4(0, y - 1.25 * s, 0, _rng.randf_range(-0.6, 0.6)),
			Vector3(s * 1.3, s * 1.3, s * 1.0), s * 2.5, _face_yaw(a) + _rng.randf_range(-0.2, 0.2), Vector2(_rng.randf_range(-0.06, 0.06), _rng.randf_range(-0.1, 0.0)))
		if _rng.randf() < 0.7:
			_tuft(_dir(a) * (rr + 0.2) + Vector4(0, y - 0.12, 0, _rng.randf_range(-0.4, 0.4)), _rng.randf_range(0.8, 1.15))
	for k in int(top.get("tufts", 7)):
		var a: float = _rng.randf_range(0.0, TAU)
		_tuft(_dir(a) * _rng.randf_range(0.5, r - 0.8) + Vector4(0, y - 0.08, 0, _rng.randf_range(-0.8, 0.8)), _rng.randf_range(0.75, 1.05))


# --- L4 debris ----------------------------------------------------------------------------------

## Fallen stones round the foot: a few clusters, each a big one and smaller ones beside it, the
## further from the face the smaller and the fewer.
func _debris(base: Dictionary) -> void:
	var d: Dictionary = spec.get("debris", {})
	var keep: Array = d.get("keep_clear", [])
	# The skirt: a ring of low boulders round the base course, where the top view shows the rock
	# running almost to the grass's edge (refs/progress, the crag's top view, 6 Oct).
	# Then rings further out, each the stones smaller and fewer: the natural fall-off of a scree
	# (Ramon: "smaller rocks that follow natural regression and debree").
	var rings: Array = d.get("rings", [[int(d.get("skirt", 0)), 0.2, 0.9, 1.1, 1.8]])
	for ring in rings:
		_skirt_ring(base, int(ring[0]), float(ring[1]), float(ring[2]), Vector2(float(ring[3]), float(ring[4])))
	var skirt: int = 0
	for k in skirt:
		var a: float = TAU * (float(k) + _rng.randf_range(-0.3, 0.3)) / float(skirt)
		var s: float = _rng.randf_range(1.1, 1.8)
		var at: Vector4 = _dir(a) * (face(0, a) + _rng.randf_range(0.2, 0.9))
		var blocked: bool = _in_clear(at.x, at.z, s * 0.6)
		for kc in keep:
			if Vector2(at.x - float(kc[0]), at.z - float(kc[1])).length() < float(kc[2]):
				blocked = true
		if blocked:
			continue
		at.y = -0.18 * s
		at.w = _rng.randf_range(-1.0, 1.0)
		_stone(["round", "cap", "block"][_rng.randi() % 3], at, Vector3(s * 1.2, s * _rng.randf_range(0.65, 0.9), s), s * 2.0, _face_yaw(a) + _rng.randf_range(-0.4, 0.4),
			Vector2(_rng.randf_range(-0.1, 0.1), _rng.randf_range(-0.1, 0.1)))
		if _rng.randf() < 0.4:
			_tuft(at + _dir(a) * s * 0.5 + Vector4(0, 0.1, 0, 0), _rng.randf_range(0.9, 1.4))
	var clusters: int = int(d.get("clusters", 7))
	var reach: float = float(d.get("reach", 2.4))
	var keep_clear: Array = d.get("keep_clear", [])
	for c in clusters:
		var a: float = _rng.randf_range(0.0, TAU)
		var rb: float = radius(base, a)
		var t: float = -log(1.0 - _rng.randf() * 0.95) * reach * 0.4
		var centre: Vector4 = _dir(a) * (rb + 0.3 + t)
		var big: float = float(d.get("size", 1.6)) * (1.0 - 0.35 * clampf(t / reach, 0.0, 1.0)) * _rng.randf_range(0.8, 1.1)
		for k in _rng.randi_range(2, 4):
			var s: float = big * (1.0 if k == 0 else _rng.randf_range(0.35, 0.6))
			var off := Vector4(_rng.randf_range(-1.0, 1.0), 0, _rng.randf_range(-1.0, 1.0), 0) * big * (0.0 if k == 0 else 0.9)
			var at: Vector4 = centre + off
			var blocked: bool = _in_clear(at.x, at.z, s * 0.6)
			for kc in keep_clear:
				if Vector2(at.x - float(kc[0]), at.z - float(kc[1])).length() < float(kc[2]):
					blocked = true
			if blocked:
				continue
			at.y = -0.22 * s
			at.w = _rng.randf_range(-1.2, 1.2)
			_stone(["round", "chip", "ledge", "block"][_rng.randi() % 4], at, Vector3(s, s * _rng.randf_range(0.6, 0.85), s * _rng.randf_range(0.8, 1.0)),
				s * 1.6, _rng.randf_range(0.0, TAU), Vector2(_rng.randf_range(-0.15, 0.15), _rng.randf_range(-0.15, 0.15)))
			if _rng.randf() < 0.5:
				_tuft(at + Vector4(s * 0.45, 0.15, 0, 0), _rng.randf_range(0.8, 1.2))


## One ring of the skirt: [param count] stones of [param size] across, from [param r0] to
## [param r1] beyond the base course's face.
func _skirt_ring(base: Dictionary, count: int, r0: float, r1: float, size: Vector2) -> void:
	var keep: Array = spec.get("debris", {}).get("keep_clear", [])
	for k in count:
		var a: float = TAU * (float(k) + _rng.randf_range(-0.35, 0.35)) / float(maxi(count, 1))
		var s: float = _rng.randf_range(size.x, size.y)
		var at: Vector4 = _dir(a) * (face(0, a) + _rng.randf_range(r0, r1))
		var blocked: bool = _in_clear(at.x, at.z, s * 0.6)
		for kc in keep:
			if Vector2(at.x - float(kc[0]), at.z - float(kc[1])).length() < float(kc[2]):
				blocked = true
		if blocked:
			continue
		at.y = -0.2 * s
		at.w = _rng.randf_range(-1.2, 1.2)
		_stone(["round", "cap", "block", "chip"][_rng.randi() % 4], at, Vector3(s * 1.15, s * _rng.randf_range(0.6, 0.88), s), s * 2.0,
			_face_yaw(a) + _rng.randf_range(-0.5, 0.5), Vector2(_rng.randf_range(-0.12, 0.12), _rng.randf_range(-0.12, 0.12)))
		if _rng.randf() < 0.35:
			_tuft(at + _dir(a) * s * 0.5 + Vector4(0, 0.08, 0, 0), _rng.randf_range(0.8, 1.2))


## The grass disc the painting stands the crag on, with tufts scattered round its edge.
func _disc(base: Dictionary) -> void:
	var g: Dictionary = spec.get("ground", {})
	var r: float = float(g.get("r", 9.8))
	var gc: Array = g.get("centre", [0.0, 0.0])
	var centre := Vector4(float(gc[0]), 0, float(gc[1]), 0)
	var sides: int = 20
	var face: float = 2.0 * r * tan(PI / float(sides)) * 1.03
	for k in sides / 2:
		var t: float = PI * float(k) / float(sides / 2)
		_box(_turf(g.get("colour", "#6f8a22")), Vector4(r * 2.0, 0.08, face, float(spec.get("w_depth", 6.0)) + 2.0), centre + Vector4(0, -0.04, 0, 0), _turn_y(t))
	for k in int(g.get("tufts", 40)):
		var a: float = _rng.randf_range(0.0, TAU)
		var edge: float = (centre + _dir(a) * r).length()
		var rr: float = _rng.randf_range(face(0, a) + 0.2, maxf(face(0, a) + 0.3, edge - 0.2))
		_tuft(_dir(a) * rr + Vector4(0, 0.0, 0, _rng.randf_range(-1.5, 1.5)), _rng.randf_range(0.9, 1.4))


# --- Helpers ------------------------------------------------------------------------------------

## A stone of [param kind] at [param at] (its base, on the ground or the course), [param size] its
## width, height and depth in metres, [param wsize] its depth in W.
func _stone(kind: String, at: Vector4, size: Vector3, wsize: float, yaw: float, tilt: Vector2) -> void:
	var half: Vector4 = (CutStone.KINDS[kind][0] as Vector4)
	var scale := Vector4(size.x / (2.0 * half.x), size.y / (2.0 * half.y), size.z / (2.0 * half.z), wsize / (2.0 * half.w))
	# The unit stone sits on its middle; lift it by its half height so [param at] is its base.
	var lifted: Vector4 = at + Vector4(0, size.y * 0.5, 0, 0)
	# Mossy-topped or plain grey, the spec's share of each.
	var mossy: bool = _rng.randf() < float(spec.get("moss", 0.0))
	_stones.append([kind + ("_moss" if mossy else ""), _rng.randi() % CutStone.VARIANTS, lifted, scale, yaw, tilt, null, _stone_group])


func _tuft(at: Vector4, size: float) -> void:
	if not bool(spec.get("tufts", true)):
		return
	_tufts.append([_rng.randi() % TUFTS, at, size, _rng.randf_range(0.0, TAU)])


## A turf colour from the spec, noted as turf so _flush can mark its node and the main green reach it.
func _turf(html: String) -> Color:
	var c := Color(html)
	_turf_keys[c.to_html(false)] = true
	return c


func _box(colour: Color, size: Vector4, at: Vector4, basis: Projection = Projection.IDENTITY) -> void:
	var key: String = colour.to_html(false)
	if not _boxes.has(key):
		_boxes[key] = ArrayTetraMesh4D.new()
	var box := BoxTetraMesh4D.new()
	box.size = size
	(_boxes[key] as ArrayTetraMesh4D).merge_with(box.to_array_tetra_mesh(), at, basis)


func _solid(size: Vector4, at: Vector4) -> void:
	if _body == null:
		return
	var holder := CollisionShape4D.new()
	var shape := BoxShape4D.new()
	shape.size = size
	holder.shape = shape
	holder.position = at
	_body.add_child(holder)


func _flush() -> void:
	var merged := ArrayTetraMesh4D.new()
	var count: int = 0
	for s in (_stones if procedural_stones else []):
		var mesh: ArrayTetraMesh4D = StoneSet.stone_mesh(String(s[0]), int(s[1]))
		if mesh == null:
			continue
		var basis: Projection = s[6] if s.size() > 6 and s[6] != null else StoneSet.placement_basis(s[3], float(s[4]), s[5])
		merged.merge_with(mesh, s[2], basis)
		count += 1
	for t in _tufts:
		var mesh: ArrayTetraMesh4D = StoneSet.stone_mesh("tuft", int(t[0]))
		if mesh == null:
			continue
		var sz: float = t[2]
		merged.merge_with(mesh, t[1], Basis4D.from_zx(float(t[3])) * Projection(Vector4(sz, 0, 0, 0), Vector4(0, sz, 0, 0), Vector4(0, 0, sz, 0), Vector4(0, 0, 0, sz)))
		count += 1
	if count > 0:
		var node := MeshInstance4D.new()
		node.name = "Stones"
		node.mesh = merged
		node.material_override = TerrainBake.material()
		_own(node)
	for key in _boxes:
		var node := MeshInstance4D.new()
		node.name = "Mass_" + String(key)
		node.mesh = _boxes[key]
		var m := TetraMaterial4D.new()
		m.albedo_color = Color.html(key)
		if _turf_keys.has(key):
			node.set_meta(&"turf", key)
			if MainGreen.on:
				m.albedo_color = MainGreen.shown()
		node.material_override = m
		_own(node)
	_boxes.clear()
	_turf_keys.clear()


## Stones and tufts placed, for runners counting them.
func counts() -> Dictionary:
	return {"stones": _stones.size(), "tufts": _tufts.size()}


## A turn about the up axis by [param t]: x toward -z (so _turn_y(-a) points x along bearing a).
static func _turn_y(t: float) -> Projection:
	return Projection(Vector4(cos(t), 0.0, -sin(t), 0.0), Vector4(0.0, 1.0, 0.0, 0.0), Vector4(sin(t), 0.0, cos(t), 0.0), Vector4(0.0, 0.0, 0.0, 1.0))


func _own(node: Node) -> void:
	node.set_meta(OWN, true)
	add_child(node)
