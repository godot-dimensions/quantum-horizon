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

## How tall the goat stands on the plinth, in metres.
@export var stand_height: float = 3.6
## The turntable, in degrees a second, outside the cinematic.
@export var turn_speed: float = 5.0

var _stand: Node4D
var _goat: Node4D
var _yaw: float = 0.6
var _step: int = -1          # E's build stage; -1 shows the finished goat


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
	]


## Drives shot `i` at `t` seconds. Returns {"slice": -1..1} when the shot moves the slice.
func play(i: int, t: float) -> Dictionary:
	if _goat == null or int(_goat.call("stage_count")) == 0:
		return {}
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
	return {}


func end_cinematic() -> void:
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
	}


static func _grouped(n: int) -> String:
	var s: String = str(n)
	var out: String = ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
