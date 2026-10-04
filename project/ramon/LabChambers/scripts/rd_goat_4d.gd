@tool
extends Node4D

## Room 01's exhibit in the R&D gallery: the cinema's goat (LabKit/carried/chickenpen/theatre/
## theatre_goat_4d.gd, its stages baked) on the plinth.
##
## THE CINEMATIC is three short shots (Ramon, 4 Oct: "a cinematic plays with perhaps 3 small
## sequences that you can skip"): the balls arriving as gold rings, the skin lofted between them,
## and the slice sliding through W (the room moves the slice; this returns how far).
## AFTERWARDS, E adds a ball: the build steps forward one stage at a time and ends in the coat.
## The room owns slicing and turning through W (rd_room_4d.gd); this node only turns on its stand.
##
## NO class_name (engine_gotchas.md).

const GOAT := preload("res://ramon/LabKit/carried/chickenpen/theatre/theatre_goat_4d.gd")
const WALK := preload("res://ramon/LabChambers/scripts/goat_walk_4d.gd")

## How tall the goat stands on the plinth, in metres.
@export var stand_height: float = 3.6
## The turntable, in degrees a second, outside the cinematic.
@export var turn_speed: float = 5.0

var _stand: Node4D
var _goat: Node4D
var _yaw: float = 0.6
var _step: int = -1          # E's build stage; -1 shows the finished goat
var _walker: Node4D          # the goat in rigid pieces, for THE WALK (goat_walk_4d.gd)


func _ready() -> void:
	_stand = Node4D.new()
	_stand.name = "GoatStand"
	add_child(_stand)
	_goat = Node4D.new()
	_goat.name = "Goat"
	_goat.set_script(GOAT)
	_goat.set("stand_height", stand_height)
	_stand.add_child(_goat)
	_stand.basis = Basis4D.from_zx(_yaw)
	if not Engine.is_editor_hint():
		shape()
		var rig: MeshInstance4D = _goat.get("_rig")
		var model: Node4D = _goat.get("_goat")
		if rig != null and model != null:
			_walker = Node4D.new()
			_walker.name = "Walk"
			_walker.set_script(WALK)
			model.add_child(_walker)
			if not bool(_walker.call("attach", rig)):
				_walker.queue_free()
				_walker = null


func _stages() -> int:
	return int(_goat.call("first_morph_stage")) if _goat != null else 7


## The balls placed so far as gold rings round the body: the loft balls' own guide wireframes,
## which hide themselves outside the editor (the goat's marker boxes sit inside the skin).
func _rings(n: int) -> void:
	if _goat == null:
		return
	var balls: Array = _goat.get("_balls")
	for i in balls.size():
		var b: Node4D = balls[i]
		if not is_instance_valid(b):
			continue
		if not b.has_meta("lab_ring") and b is MeshInstance4D:
			var wm := WireMaterial4D.new()
			wm.albedo_color = Color(1.0, 0.74, 0.12)
			wm.set("line_thickness", 5.0)
			(b as MeshInstance4D).material_override = wm
			b.set_meta("lab_ring", true)
		b.visible = i < n


func _show(step: int) -> void:
	if step < 0 or step >= _stages():
		_goat.call("show_finished")
		_goat.call("set_markers_visible", false)
		_rings(0)
	else:
		_goat.call("show_stage", step)
		_goat.call("set_markers_visible", false)
		_rings(int(_goat.call("balls_shown")))


# -- the cinematic ---------------------------------------------------------------------------------

## The three shots: a title, a line, seconds, and the camera in the exhibit's frame (eye, look, lens).
func sequences() -> Array:
	return [
		{"title": "THE BALLS", "line": "A designer places 24 balls. Each one is a cross-section of the body.", "length": 6.5,
			"eye": Vector4(-3.6, 3.0, 6.4, 0.0), "look": Vector4(0.2, 1.3, 0.0, 0.0), "fov": 0.85},
		{"title": "THE SKIN", "line": "The tool lofts a skin between them. Nothing is modelled by hand.", "length": 5.5,
			"eye": Vector4(-5.4, 2.6, 4.2, 0.0), "look": Vector4(0.0, 1.5, 0.0, 0.0), "fov": 0.85},
		{"title": "THE SLICE", "line": "It is four-dimensional. Move the slice through W and the shape changes.", "length": 7.5,
			"eye": Vector4(-1.0, 3.0, 8.4, 0.0), "look": Vector4(0.6, 1.3, -1.0, 0.0), "fov": 0.95},
		{"title": "THE WALK", "line": "Cut into rigid pieces on joints, it walks without lofting again.", "length": 9.0,
			"eye": Vector4(-4.5, 2.4, 5.5, 0.0), "look": Vector4(0.0, 1.4, 0.0, 0.0), "fov": 0.9},
		{"title": "THE RIG", "line": "Under the skin: the balls are the joints, and they walk.", "length": 6.0,
			"eye": Vector4(-4.5, 2.4, 5.5, 0.0), "look": Vector4(0.0, 1.4, 0.0, 0.0), "fov": 0.9},
	]


## Drives shot `i` at `t` seconds. Returns {"slice": -1..1} when the shot moves the slice.
func play(i: int, t: float) -> Dictionary:
	if _goat == null or int(_goat.call("stage_count")) == 0:
		return {}
	_walk(i == 3 or i == 4)
	if _walker != null:
		_walker.call("set_xray", i == 4)
	match i:
		0:
			_stand.basis = Basis4D.from_zx(0.55)
			var step: int = clampi(int(floor((t - 0.3) / 0.85)), 0, _stages() - 1)
			if step != int(_goat.call("shown_stage")) or not bool(_goat.call("showing_plain")):
				_show(step)
		1:
			if bool(_goat.call("showing_plain")):
				_show(-1)
			_stand.basis = Basis4D.from_zx(0.55 + t * 0.12)
		2:
			if bool(_goat.call("showing_plain")):
				_show(-1)
			_stand.basis = Basis4D.from_zx(0.2)
			return {"slice": sin(clampf(t / 7.0, 0.0, 1.0) * TAU) * 0.55}
		3, 4:
			if bool(_goat.call("showing_plain")):
				_show(-1)
			# Side on, turning a little, so the legs read; the rig goes on from where the walk was.
			var tw: float = t + (9.0 if i == 4 else 0.0)
			_stand.basis = Basis4D.from_zx(1.25 + tw * 0.03)
			if _walker != null:
				_walker.call("pose", tw)
	return {}


## Walking or standing: the rigid pieces or the lofted goat.
func _walk(on: bool) -> void:
	if _walker != null:
		_walker.call("set_walking", on)


func end_cinematic() -> void:
	_walk(false)
	_step = -1
	_show(-1)
	_stand.basis = Basis4D.from_zx(_yaw)


# -- afterwards ------------------------------------------------------------------------------------

func action_label() -> String:
	return "Add a ball"


## E: the next stage of the build; after the last, the coat; then it starts again.
func action() -> String:
	if _goat == null:
		return ""
	_walk(false)
	var n: int = _stages()
	if _step < 0:
		_step = 0
	elif _step >= n - 1:
		_step = -1
	else:
		_step += 1
	_show(_step)
	if _step < 0:
		return "%d balls. The skin is lofted between them." % int(_goat.call("ball_count"))
	return "%d balls placed" % int(_goat.call("balls_shown"))


func idle(delta: float) -> void:
	if _stand == null:
		return
	_yaw += deg_to_rad(turn_speed) * delta
	_stand.basis = Basis4D.from_zx(_yaw)


## How far through W the goat reaches either side of its centre, in metres, read off its
## finished mesh (and its fitting scale), so the slice range ends where the goat does.
func w_extent() -> float:
	if _goat == null:
		return 1.0
	var m: ArrayTetraMesh4D = _goat.get("_finished")
	if m == null:
		return 1.0
	var lo: float = INF
	var hi: float = -INF
	for v in m.get_vertex_positions():
		lo = minf(lo, v.w)
		hi = maxf(hi, v.w)
	if not is_finite(lo):
		return 1.0
	var rig: Node4D = _goat.get("_rig")
	var s: float = 1.0
	if rig != null:
		s = (rig.global_basis * Vector4(0, 0, 0, 1)).length()
	return maxf(0.2, maxf(absf(lo), absf(hi)) * s)


## What the room's data desk shows: read off the goat itself, never typed in.
func data() -> Dictionary:
	if _goat == null or int(_goat.call("stage_count")) == 0:
		return {}
	var baked: Array = _goat.get("_baked")
	var bars: Array = []
	for m in baked:
		bars.append(int((m as ArrayTetraMesh4D).get_simplex_cell_vertex_indices().size() / 4))
	var finished: ArrayTetraMesh4D = _goat.get("_finished")
	var whole: int = int(finished.get_simplex_cell_vertex_indices().size() / 4) if finished != null else 0
	return {
		"title": "THE GOAT, MEASURED",
		"rows": [["Balls placed by hand", str(int(_goat.call("ball_count")))],
			["Tetrahedra, finished", _grouped(whole)],
			["Build stages, baked", str(int(_goat.call("first_morph_stage")))],
			["Reach through W", "%.2f m" % w_extent()]],
		"bars": bars.slice(0, int(_goat.call("first_morph_stage"))),
		"bar_label": "Tetrahedra at each build stage",
		"stats": {"balls": int(_goat.call("ball_count")), "tetra": whole, "stages": int(_goat.call("first_morph_stage")),
			"reach": w_extent(), "verts": finished.get_vertex_positions().size() if finished != null else 0, "mb": _megabytes(baked, finished)},
	}


## Roughly what the goat's meshes hold in memory: each vertex is four doubles, each tetrahedron
## four indices, for the finished coat and every baked stage.
static func _megabytes(baked: Array, finished: ArrayTetraMesh4D) -> float:
	var bytes: float = 0.0
	var all: Array = baked.duplicate()
	if finished != null:
		all.append(finished)
	for m in all:
		var tm: ArrayTetraMesh4D = m
		bytes += float(tm.get_vertex_positions().size()) * 32.0 + float(tm.get_simplex_cell_vertex_indices().size()) * 4.0
	return bytes / 1048576.0


var _profile: Dictionary = {}


## How much of the goat each W cuts: the finished coat's tetrahedra counted into `count` bins
## from -reach to +reach (a tetrahedron counts in every bin its own W span crosses), scaled so
## the fullest is 1. A slice at that W shows that many tetrahedra cut, so it is the size of
## what you see there: big through the middle, nothing past the ends. Worked out once.
func w_profile(count: int = 48) -> Dictionary:
	if not _profile.is_empty() or _goat == null:
		return _profile
	var m: ArrayTetraMesh4D = _goat.get("_finished")
	if m == null:
		return {}
	var verts: PackedVector4Array = m.get_vertex_positions()
	var cells: PackedInt32Array = m.get_simplex_cell_vertex_indices()
	var lo: float = INF
	var hi: float = -INF
	for v in verts:
		lo = minf(lo, v.w)
		hi = maxf(hi, v.w)
	var reach: float = maxf(absf(lo), absf(hi))
	if not is_finite(reach) or reach <= 0.0:
		return {}
	var bins := PackedFloat32Array()
	bins.resize(count)
	bins.fill(0.0)
	for t in range(0, cells.size() - 3, 4):
		var a: float = INF
		var b: float = -INF
		for k in 4:
			var w: float = verts[cells[t + k]].w
			a = minf(a, w)
			b = maxf(b, w)
		var i0: int = clampi(int(floor((a / reach * 0.5 + 0.5) * float(count - 1))), 0, count - 1)
		var i1: int = clampi(int(ceil((b / reach * 0.5 + 0.5) * float(count - 1))), 0, count - 1)
		for i in range(i0, i1 + 1):
			bins[i] += 1.0
	var most: float = 0.0
	for x in bins:
		most = maxf(most, x)
	if most > 0.0:
		for i in count:
			bins[i] /= most
	_profile = {"bins": bins, "reach": w_extent()}
	return _profile


static func _grouped(n: int) -> String:
	var s: String = str(n)
	var out: String = ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


## What the goat is showing right now, for the data panel.
func live() -> Array:
	if _goat == null or int(_goat.call("stage_count")) == 0:
		return []
	var plain: bool = bool(_goat.call("showing_plain"))
	return [
		["Showing", "build stage %d of %d" % [int(_goat.call("shown_stage")) + 1, _stages()] if plain else "the finished coat"],
		["Balls in view", str(int(_goat.call("balls_shown")) if plain else int(_goat.call("ball_count")))],
	]


var _shape: Dictionary = {}


## The goat drawn flat, for the research panel: its finished mesh's points and its balls
## (centre, radius, name) seen from the side in the loft rig's own frame (whichever of x and z
## it is longer along, across; y up), in metres, and which ball hangs from which. Worked out once,
## while every ball is still on the goat (the build sequence takes some off).
func shape() -> Dictionary:
	if not _shape.is_empty() or _goat == null:
		return _shape
	var rig: Node4D = _goat.get("_rig")
	var m: ArrayTetraMesh4D = _goat.get("_finished")
	if rig == null or m == null or not rig.is_inside_tree():
		return {}
	var balls: Array = _goat.get("_balls")
	for b in balls:
		if not (b as Node).is_inside_tree():
			return {}
	var verts: PackedVector4Array = m.get_vertex_positions()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for v in verts:
		lo = Vector2(minf(lo.x, v.x), minf(lo.y, v.z))
		hi = Vector2(maxf(hi.x, v.x), maxf(hi.y, v.z))
	var across_x: bool = hi.x - lo.x >= hi.y - lo.y
	# The vertices sit only on the loft's rings, round each ball; the middle of every tetrahedron
	# fills in the body between them.
	var pts := PackedVector2Array()
	for v in verts:
		pts.append(Vector2(v.x if across_x else v.z, v.y))
	var cells: PackedInt32Array = m.get_simplex_cell_vertex_indices()
	for t in range(0, cells.size() - 3, 4):
		var cv: Vector4 = (verts[cells[t]] + verts[cells[t + 1]] + verts[cells[t + 2]] + verts[cells[t + 3]]) * 0.25
		pts.append(Vector2(cv.x if across_x else cv.z, cv.y))
	var inv: Projection = rig.global_basis.inverse()
	var unit: float = maxf((rig.global_basis * Vector4(1, 0, 0, 0)).length(), 0.000001)
	var out_balls: Array = []
	var bones: Array = []
	for i in balls.size():
		var b: Node4D = balls[i]
		var l: Vector4 = inv * (b.global_position - rig.global_position)
		var r: float = float(b.get("radius")) * (b.global_basis * Vector4(1, 0, 0, 0)).length() / unit
		out_balls.append([Vector2(l.x if across_x else l.z, l.y), r, String(b.name)])
		var j: int = balls.find(b.get_parent())
		if j >= 0:
			bones.append([j, i])
	_shape = {"points": pts, "balls": out_balls, "bones": bones}
	return _shape


## How many of its balls the goat shows now (all of them once its coat is on), and which build
## stage (-1 for the finished coat): the research panel lights its diagram's balls from these.
func balls_in_view() -> int:
	if _goat == null:
		return 0
	return int(_goat.call("balls_shown")) if bool(_goat.call("showing_plain")) else int(_goat.call("ball_count"))


func stage_in_view() -> int:
	if _goat == null or not bool(_goat.call("showing_plain")):
		return -1
	return int(_goat.call("shown_stage"))


var _cloud: PackedVector4Array = PackedVector4Array()


## The goat as a cloud of its own points in 4D, for the slice view (kit_slice_view.gd): the finished
## coat's vertices and the middles of its tetrahedra, thinned to one per cell of a grid about 26
## cells along the goat, in the rig's space (W included). Worked out once.
func cloud() -> PackedVector4Array:
	if not _cloud.is_empty() or _goat == null:
		return _cloud
	var m: ArrayTetraMesh4D = _goat.get("_finished")
	if m == null:
		return _cloud
	var verts: PackedVector4Array = m.get_vertex_positions()
	var cells: PackedInt32Array = m.get_simplex_cell_vertex_indices()
	var all := PackedVector4Array(verts)
	for t in range(0, cells.size() - 3, 4):
		all.append((verts[cells[t]] + verts[cells[t + 1]] + verts[cells[t + 2]] + verts[cells[t + 3]]) * 0.25)
	var lo := Vector4(INF, INF, INF, INF)
	var hi := Vector4(-INF, -INF, -INF, -INF)
	for p in all:
		lo = Vector4(minf(lo.x, p.x), minf(lo.y, p.y), minf(lo.z, p.z), minf(lo.w, p.w))
		hi = Vector4(maxf(hi.x, p.x), maxf(hi.y, p.y), maxf(hi.z, p.z), maxf(hi.w, p.w))
	var cell: float = maxf(maxf(hi.x - lo.x, hi.z - lo.z), 0.001) / 26.0
	var keep: Dictionary = {}
	for p in all:
		var key := Vector4i(int(floor(p.x / cell)), int(floor(p.y / cell)), int(floor(p.z / cell)), int(floor(p.w / cell)))
		if not keep.has(key):
			keep[key] = p
	for p in keep.values():
		_cloud.append(p)
	return _cloud


## The slice the camera sees, in the goat's own (rig) space: a rig point p sits at world
## W = n.dot(p) + d, so the slice is where that is the viewer's W. n and d come straight from the
## rig's place in the world, so they hold whoever moves the slice: the wheel, a right drag turning
## it through W, or the sequence. Returns [n, d], or [] before the goat is built.
func slice_in_rig() -> Array:
	if _goat == null:
		return []
	var rig: Node4D = _goat.get("_rig")
	if rig == null or not rig.is_inside_tree():
		return []
	var gb: Projection = rig.global_basis
	return [Vector4(gb.x.w, gb.y.w, gb.z.w, gb.w.w), rig.global_position.w]
