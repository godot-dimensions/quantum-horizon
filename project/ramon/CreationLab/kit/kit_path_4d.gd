@tool
extends Node4D

## Kit: a path on the floor that guides you, curved or straight, open or a loop (Ramon, 4 Oct: "a
## dynamic arrow system: dotted zebra lines, arrows, a ball for rotation point, and a bigger rotating
## circle for highlight point ... arrows that can curve or go in a circle ... ideally it is subject to
## slicing ... ideally without faking it").
##
## IT IS 4D, NOT FAKED. A path is a curve through the floor's own space, x, z and W (a floor in 4D is
## a three-dimensional volume). It is built as a thin strip of tetrahedra a hair above the floor
## following that curve, as wide as `width` across and `w_thickness` deep through W either side.
## The renderer slices it like every other mesh: where the curve is at your W you see its marks;
## where it bends away through W they thin out and are gone. A path whose control points all sit at
## W 0 is simply a path on the floor.
##
## THE MARKS are drawn by the grid shader's path mode (lab_grid.gdshader): your chevron pair, zebra
## stripes, square blocks, a line with balls running along it, or solid, moving on along the curve.
## Arrows, blocks and balls are rigid: each turns to the curve at its middle rather than bending
## with it (the shader is handed the curve). An open path ends in a fixed line at each end. The strip carries the floor's own
## grid, so it is invisible and only the marks show; the strip is built once, the movement is the
## shader's, so a path costs nothing a frame.
##
## THE CURVE: through the positions of this node's Node4D children in order (drag them in the
## editor; the path follows, live), or `points` if there are none, or a circle of `radius` round the
## node (`shape` "circle"). Smoothed through its points (a Catmull-Rom curve) unless `smooth` is off.
## Built in the node's own space; turn it only about Y, or the grid on its strip will not meet the
## floor's.
##
## NO class_name (engine_gotchas.md).

const LabGrid := preload("res://ramon/LabKit/lab_grid.gd")
const Style := preload("res://ramon/CreationLab/kit/kit_style.gd")
## The strip is this much wider than `width`, so rigid marks turning on a bend are not cut off.
const MARGIN := 1.4

@export_tool_button("Rebuild") var _rebuild_action: Callable = rebuild
@export_enum("arrows", "zebra", "blocks", "line", "solid") var style: String = "arrows":
	set(v):
		style = v
		_params()
@export_enum("points", "circle") var shape: String = "points":
	set(v):
		shape = v
		_later()
## The curve's points (x, y ignored, z, w), used when the node has no Node4D children.
@export var points: PackedVector4Array = PackedVector4Array():
	set(v):
		points = v
		_later()
## A circle's radius, m.
@export_range(0.2, 20.0, 0.05) var radius: float = 1.5:
	set(v):
		radius = v
		_later()
@export var closed: bool = false:
	set(v):
		closed = v
		_later()
@export var smooth: bool = true:
	set(v):
		smooth = v
		_later()
## Across, m; how far it reaches through W either side of its curve, m.
@export_range(0.05, 4.0, 0.01) var width: float = 1.15:
	set(v):
		width = v
		_later()
@export_range(0.02, 4.0, 0.01) var w_thickness: float = 0.6:
	set(v):
		w_thickness = v
		_later()
## The pattern's period along the curve, m, and how fast it moves on, m/s (negative runs it back).
@export_range(0.1, 10.0, 0.05) var spacing: float = 3.0:
	set(v):
		spacing = v
		_params()
@export_range(-6.0, 6.0, 0.05) var speed: float = 0.7:
	set(v):
		speed = v
		_params()
## The wall's blue by default (Ramon, 5 Oct: "it should be the wall blue").
@export var color: Color = Color(0.13, 0.40, 0.86):
	set(v):
		color = v
		_params()
## None by default: paint, not light (Ramon: "not emit light").
@export_range(0.0, 2.0, 0.01) var glow: float = 0.0:
	set(v):
		glow = v
		_params()
## The fixed line across each end of an open path, m thick: the marks run into it and are gone.
@export_range(0.0, 0.5, 0.01) var cap: float = 0.08:
	set(v):
		cap = v
		_params()
## How high above the floor the strip lies, m.
@export_range(0.002, 0.2, 0.001) var height: float = 0.012:
	set(v):
		height = v
		_later()
## The sampling step along the curve, m.
@export_range(0.03, 1.0, 0.01) var step: float = 0.14:
	set(v):
		step = v
		_later()

var length: float = 0.0
var _strip: MeshInstance4D
var _queued: bool = false
var _sig: PackedFloat32Array = PackedFloat32Array()
var _origin: Vector4 = Vector4.INF


func _ready() -> void:
	rebuild()


func _later() -> void:
	if _queued or not is_inside_tree():
		return
	_queued = true
	(func() -> void:
		_queued = false
		rebuild()).call_deferred()


func _process(_delta: float) -> void:
	# Live: dragging a control point (or the path) rebuilds it.
	var sig := PackedFloat32Array()
	for h in _handles():
		var p: Vector4 = h.position
		sig.append_array([p.x, p.z, p.w])
	if sig != _sig:
		_sig = sig
		_later()
	if is_instance_valid(_strip) and global_position != _origin:
		_origin = global_position
		_params()


func _handles() -> Array:
	var out: Array = []
	for c in get_children():
		if c is Node4D and c != _strip and not c.has_meta("kit_path_generated"):
			out.append(c)
	return out


## The control points, in this node's space.
func control_points() -> PackedVector4Array:
	if shape == "circle":
		var out := PackedVector4Array()
		for i in 48:
			var a: float = TAU * float(i) / 48.0
			out.append(Vector4(sin(a) * radius, 0.0, cos(a) * radius, 0.0))
		return out
	var hs: Array = _handles()
	if hs.size() >= 2:
		var out2 := PackedVector4Array()
		for h in hs:
			out2.append((h as Node4D).position)
		return out2
	return points


func _is_closed() -> bool:
	return closed or shape == "circle"


## The curve sampled every `step` metres or so: [points, metres along at each].
func samples() -> Array:
	var cp: PackedVector4Array = control_points()
	var out := PackedVector4Array()
	var at := PackedFloat32Array()
	if cp.size() < 2:
		return [out, at]
	var n: int = cp.size()
	var segs: int = n if _is_closed() else n - 1
	for i in segs:
		var p0: Vector4 = cp[(i - 1 + n) % n] if (_is_closed() or i > 0) else cp[i] * 2.0 - cp[i + 1]
		var p1: Vector4 = cp[i]
		var p2: Vector4 = cp[(i + 1) % n]
		var p3: Vector4 = cp[(i + 2) % n] if (_is_closed() or i + 2 < n) else cp[(i + 1) % n] * 2.0 - cp[i]
		var span: float = Vector3(p2.x - p1.x, p2.z - p1.z, p2.w - p1.w).length()
		var m: int = maxi(1, int(ceil(span / step)))
		for j in m:
			var t: float = float(j) / float(m)
			out.append(_catmull(p0, p1, p2, p3, t) if smooth else p1.lerp(p2, t))
	if not _is_closed():
		out.append(cp[n - 1])
	else:
		out.append(out[0])
	var total: float = 0.0
	at.append(0.0)
	for k in range(1, out.size()):
		var d: Vector4 = out[k] - out[k - 1]
		total += Vector3(d.x, d.z, d.w).length()
		at.append(total)
	return [out, at]


static func _catmull(p0: Vector4, p1: Vector4, p2: Vector4, p3: Vector4, t: float) -> Vector4:
	var t2: float = t * t
	var t3: float = t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


func rebuild() -> void:
	_cached = []
	if is_instance_valid(_strip):
		_strip.free()
	_strip = null
	var sm: Array = samples()
	var pts: PackedVector4Array = sm[0]
	var at: PackedFloat32Array = sm[1]
	if pts.size() < 2:
		return
	length = at[at.size() - 1]
	# Four corners at every sample: across the curve on the floor, either side of it in W.
	var verts := PackedVector4Array()
	var tex := PackedVector3Array()
	var count: int = pts.size()
	for k in count:
		var prev: Vector4 = pts[maxi(k - 1, 0)] if not (_is_closed() and k == 0) else pts[count - 2]
		var next: Vector4 = pts[mini(k + 1, count - 1)] if not (_is_closed() and k == count - 1) else pts[1]
		var tan2 := Vector2(next.x - prev.x, next.z - prev.z)
		if tan2.length() < 0.0001:
			tan2 = Vector2(0.0, 1.0)
		tan2 = tan2.normalized()
		var across := Vector4(tan2.y, 0.0, -tan2.x, 0.0)
		var c: Vector4 = Vector4(pts[k].x, height, pts[k].z, pts[k].w)
		for ws in [-1.0, 1.0]:
			for side in [-1.0, 1.0]:
				verts.append(c + across * (side * width * 0.5 * MARGIN) + Vector4(0.0, 0.0, 0.0, ws * w_thickness))
				tex.append(Vector3(at[k], side, ws))
	# Between two samples a box in (along, across, W): six tetrahedra (one per order of its three
	# axes, which tiles neighbouring boxes consistently), each laid down both ways round so it shows
	# whichever way the renderer culls.
	var cells := PackedInt32Array()
	for k in count - 1:
		var corner := func(a: int, b: int, w: int) -> int: return 4 * (k + a) + b + 2 * w
		var orders := [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]]
		for o in orders:
			var bits := [0, 0, 0]
			var chain := [corner.call(0, 0, 0)]
			for axis in o:
				bits[axis] = 1
				chain.append(corner.call(bits[0], bits[1], bits[2]))
			cells.append_array([chain[0], chain[1], chain[2], chain[3]])
			cells.append_array([chain[0], chain[2], chain[1], chain[3]])
	var mesh := ArrayTetraMesh4D.new()
	mesh.set_vertex_positions(verts)
	mesh.set_simplex_cell_vertex_indices(cells)
	mesh.set_texture_map_values(tex)
	mesh.set_simplex_cell_texture_map_indices(cells)
	mesh.calculate_boundary_normals(false)
	_strip = MeshInstance4D.new()
	_strip.name = "Strip"
	_strip.set_meta("kit_path_generated", true)
	_strip.mesh = mesh
	_strip.material_override = LabGrid.material("kit_floor", Vector4(1, 1, 1, 1), global_position if is_inside_tree() else Vector4.ZERO)
	add_child(_strip)
	_origin = Vector4.INF
	_params()


## The marks' settings onto the strip's material.
func _params() -> void:
	if not is_instance_valid(_strip):
		return
	var cs: ShaderMaterial = (_strip.material_override as TetraMaterial4D).get_cross_section_material_3d()
	cs.set_shader_parameter("grid_offset", global_position if is_inside_tree() else Vector4.ZERO)
	cs.set_shader_parameter("path_on", 1.0)
	cs.set_shader_parameter("path_style", float(maxi(0, ["arrows", "zebra", "blocks", "line", "solid", "dots"].find(style)) if style != "dots" else 2))
	cs.set_shader_parameter("path_color", color)
	cs.set_shader_parameter("path_glow", glow)
	# A loop's pattern has to meet itself: its period is the nearest that fits a whole number of times.
	var sp: float = spacing
	if _is_closed() and length > 0.01:
		sp = length / maxf(1.0, round(length / spacing))
	cs.set_shader_parameter("path_spacing", sp)
	cs.set_shader_parameter("path_speed", speed)
	cs.set_shader_parameter("path_length", length)
	cs.set_shader_parameter("path_width", width)
	cs.set_shader_parameter("path_margin", MARGIN)
	cs.set_shader_parameter("path_cap", cap)
	# The curve itself, 128 points evenly spaced along it, for the rigid marks.
	var n: int = 128
	var img := Image.create(n, 1, false, Image.FORMAT_RGBAF)
	for i in n:
		var q: Vector4 = point_at(length * float(i) / float(n - 1))
		img.set_pixel(i, 0, Color(q.x, q.z, q.w, 1.0))
	cs.set_shader_parameter("path_curve_tex", ImageTexture.create_from_image(img))
	cs.set_shader_parameter("path_curve_n", n)
	cs.set_shader_parameter("path_closed", 1.0 if _is_closed() else 0.0)
	cs.set_shader_parameter("path_pair", 0.76 * width / 1.15)


var _cached: Array = []


## The point at `s` metres along, in this node's space (for markers riding the path).
func point_at(s: float) -> Vector4:
	if _cached.is_empty():
		_cached = samples()
	var sm: Array = _cached
	var pts: PackedVector4Array = sm[0]
	var at: PackedFloat32Array = sm[1]
	if pts.is_empty():
		return Vector4.ZERO
	for k in range(1, pts.size()):
		if at[k] >= s:
			var f: float = (s - at[k - 1]) / maxf(at[k] - at[k - 1], 0.0001)
			return pts[k - 1].lerp(pts[k], f)
	return pts[pts.size() - 1]
