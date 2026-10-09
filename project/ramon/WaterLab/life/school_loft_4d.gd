extends Node4D

## WATER LAB: a school of small fish, each one LOFTED IN 4D (round 5: every animal a true 4D loft; Ramon
## chose "fewer, all true 4D" over thousands of 3D shapes that a shader shrank off the slice). The tank's
## swarm (life/tank_swarm_4d.gd) and the sea's sardines (seascape/fish_school_4d.gd) keep their carried
## flock (carried/flock/school_flock_4d.gd) for the swimming; it steps on the CPU and draws nothing
## (`drawn` false), and this node poses a lofted fish at each of its rows every frame.
##
## THE FISH is the sardine the sea drew before (fish_school_4d.gd _fish_mesh): a slim body, a forked
## tail, a little dorsal fin; one body length long, its middle at the origin, the snout half a length
## ahead. Round across x and W like the koi, so it shows only within its own half width of your slice
## (a few millimetres for the tank's 9 cm fish): the school is kept that close to the slice by its
## owner (the flock's W squashed in the node's own basis), and a turn of the slice cuts it away.
##
## TWO RIGID PIECES, jointed at the middle: the front swings a little one way, the back (with the tail)
## the other way more, the tail beat (the old shader's swing, its rate and how hard it beats from the
## flock). Each piece is one MeshInstance4D under this node, posed here directly: no node in between,
## so a school of 150 is 300 transforms a frame. Its colours: blue-green back, a row of dark spots,
## silver flanks, a white belly, all in one 3D texture shared by the school.
##
## In the flock's parent's frame (this node sits beside the flock). NO class_name (engine_gotchas.md).

const Loft := preload("res://ramon/WaterLab/carried/chickenpen/scripts/loft_builder_4d.gd")
const Kit := preload("res://ramon/WaterLab/life/loft_kit.gd")
const BAKED := "res://ramon/WaterLab/life/baked/"
const BAKE_VERSION := "v2"
const FLOATS := 20
const W_ROUND := 1.0
## Its half width for its half height (a slim fish).
const SLIM := 0.62

## The flock whose rows it draws (a sibling, set by the owner before it enters the tree).
var flock: Node4D = null
## Each fish's length, metres.
@export var fish_length: float = 0.2
## How fast the tail beats at rest (beats a second), and how hard.
@export var beat_rate: float = 4.5

var material: TetraMaterial4D
var tets_each: int = 0
var cpu_us: float = 0.0
var _front_mesh: ArrayTetraMesh4D
var _back_mesh: ArrayTetraMesh4D
var _pieces: Array = []
var _frames: Array = []
var _t: float = 0.0


func _ready() -> void:
	material = skin()
	_front_mesh = Kit.cached(BAKED + "school_fish_front_%s.res" % BAKE_VERSION, _front)
	_back_mesh = Kit.cached(BAKED + "school_fish_back_%s.res" % BAKE_VERSION, _back)
	tets_each = (_front_mesh.get_simplex_cell_vertex_indices().size() + _back_mesh.get_simplex_cell_vertex_indices().size()) / 4


func _process(delta: float) -> void:
	if flock == null or not is_instance_valid(flock):
		return
	var t0: int = Time.get_ticks_usec()
	_t += delta
	var rows: PackedFloat32Array = flock.call("rows")
	var n: int = rows.size() / FLOATS
	_ensure(n)
	var fb: Projection = flock.basis
	var fo: Vector4 = flock.position
	var L: float = fish_length
	for i in n:
		var o: int = i * FLOATS
		var p: Vector4 = fo + fb * Vector4(rows[o], rows[o + 1], rows[o + 2], rows[o + 3])
		var h: Vector4 = (fb * Vector4(rows[o + 4], rows[o + 5], rows[o + 6], rows[o + 7])).normalized()
		var side: Vector4 = fb * Vector4(rows[o + 8], rows[o + 9], rows[o + 10], rows[o + 11])
		var f: Projection = frame_from(h, side, _frames[i])
		_frames[i] = f
		var ph: float = rows[o + 16]
		var beat: float = clampf(0.35 + rows[o + 17] * 0.65, 0.0, 1.0)
		var rate: float = beat_rate * (0.9 + 0.2 * fmod(ph * 7.31, 1.0))
		var swing: float = beat * 0.42 * sin(_t * TAU * rate + ph * TAU)
		var b := Projection(f.x * L, f.y * L, f.z * L, f.w * L)
		var front: MeshInstance4D = _pieces[i * 2]
		var back: MeshInstance4D = _pieces[i * 2 + 1]
		front.position = p
		front.basis = b * Kit.yaw(-0.25 * swing)
		back.position = p
		back.basis = b * Kit.yaw(swing)
	cpu_us = lerpf(cpu_us, float(Time.get_ticks_usec() - t0), 0.05)


## Two pieces a fish, made or freed to match the flock's count.
func _ensure(n: int) -> void:
	while _pieces.size() < n * 2:
		var front := MeshInstance4D.new()
		front.mesh = _front_mesh
		front.material_override = material
		add_child(front)
		var back := MeshInstance4D.new()
		back.mesh = _back_mesh
		back.material_override = material
		add_child(back)
		_pieces.append_array([front, back])
		_frames.append(Projection.IDENTITY)
	while _pieces.size() > n * 2:
		(_pieces.pop_back() as Node).queue_free()
		(_pieces.pop_back() as Node).queue_free()
		_frames.pop_back()


## A frame (right, up, ahead, ana) for `ahead`, its right along `side` (the flock's roll in it), up and
## ana what is left, carried on from `prev` so ana never flips.
static func frame_from(ahead: Vector4, side: Vector4, prev: Projection) -> Projection:
	var z: Vector4 = ahead
	var x: Vector4 = side - z * side.dot(z)
	if x.length() < 0.05:
		return Kit.frame_for(ahead, prev)
	x = x.normalized()
	var y: Vector4 = Vector4(0, 1, 0, 0) - z * z.y - x * x.y
	if y.length() < 0.05:
		y = prev.y - z * prev.y.dot(z) - x * prev.y.dot(x)
	y = y.normalized()
	var w: Vector4 = prev.w - z * prev.w.dot(z) - y * prev.w.dot(y) - x * prev.w.dot(x)
	if w.length() < 0.05:
		for cand in [Vector4(0, 0, 0, 1), Vector4(0, 0, 1, 0), Vector4(1, 0, 0, 0)]:
			w = cand - z * cand.dot(z) - y * cand.dot(y) - x * cand.dot(x)
			if w.length() > 0.1:
				break
	var f := Projection(x, y, z, w.normalized())
	if f.determinant() < 0.0:
		f.w = -f.w
	return f


# -- the fish (lofted once, baked) -----------------------------------------------------------------------------

## The old sardine's radius at s (0 the snout, 1 the tail's root), body lengths.
static func radius(s: float) -> float:
	return 0.11 * pow(sin(PI * clampf(s * 0.92 + 0.04, 0.0, 1.0)), 0.7)


static func _section(s: float) -> Dictionary:
	var r: float = maxf(radius(s), 0.004)
	return {"center": Vector4(0.0, 0.0, 0.5 - s, 0.0), "radius": r * SLIM, "v_scale": 1.0, "w_scale": 1.0,
		"basis": Kit.scale(1.0, 1.0 / SLIM, 1.0, W_ROUND), "color": Color.WHITE}


## The front half, to a little past the middle, with the dorsal fin.
func _front() -> ArrayTetraMesh4D:
	var sections: Array = []
	for k in 4:
		sections.append(_section(lerpf(0.03, 0.56, float(k) / 3.0)))
	var parts: Array = [Loft.build(sections, 3, 6, true, false, true, 0, false)]
	parts.append(_fin(Vector2(0.45, 0.07), Vector2(0.60, 0.07), 0.04, 0.012, Vector2(0.0, 1.0)))
	var m: ArrayTetraMesh4D = Kit.merge(parts)
	Kit.paint(m, _coord)
	return m


## The back half from a little before the middle, with the forked tail.
func _back() -> ArrayTetraMesh4D:
	var sections: Array = []
	for k in 4:
		sections.append(_section(lerpf(0.44, 0.97, float(k) / 3.0)))
	var parts: Array = [Loft.build(sections, 3, 6, true, false, true, 0, false)]
	for up in [1.0, -1.0]:
		parts.append(_fin(Vector2(0.96, 0.0), Vector2(1.18, up * 0.15), 0.035, 0.01, Vector2(0.0, up)))
	var m: ArrayTetraMesh4D = Kit.merge(parts)
	Kit.paint(m, _coord)
	return m


## A thin fin from `a` to `b` (s, height), its half chord from `c0` to `c1`, thin across x and W.
func _fin(a: Vector2, b: Vector2, c0: float, c1: float, _dir: Vector2) -> ArrayTetraMesh4D:
	var sections: Array = []
	for k in 3:
		var u: float = float(k) / 2.0 * 0.9
		var q: Vector2 = a.lerp(b, u)
		var r: float = lerpf(c0, c1, u)
		sections.append({"center": Vector4(0.0, q.y, 0.5 - q.x, 0.0), "radius": r, "v_scale": 1.0, "w_scale": 1.0,
			"basis": Kit.scale(0.004 / r, 1.0, 1.0, 1.4 * 0.004 / r), "color": Color.WHITE})
	return Loft.build(sections, 3, 5, true, false, true, 0, false)


## Texture coordinates, on texel centres: x how high on the body (0 the belly, 1 the back), y the row
## (body, fin), z along it (the spots).
static func _coord(q: Vector4) -> Vector3:
	var s: float = clampf(0.5 - q.z, 0.0, 1.0)
	var r: float = maxf(radius(minf(s, 0.98)), 0.004)
	var fin: bool = absf(q.y) > r * 1.05 or s > 0.985
	var up: float = clampf(0.5 + 0.5 * q.y / r, 0.0, 1.0)
	return Vector3((0.5 + up * 31.0) / 32.0, 0.75 if fin else 0.25, (0.5 + s * 15.0) / 16.0)


## A sardine (school_fish.gdshader's colours): blue-green back, a row of dark spots on the upper flank
## (along the front 60%), silver flanks, a white belly; the fins a grey-blue.
static func skin() -> TetraMaterial4D:
	var back := Color(0.04, 0.14, 0.18)
	var silver := Color(0.78, 0.82, 0.86)
	var belly := Color(0.94, 0.95, 0.96)
	var slices: Array = []
	for zi in 16:
		var s: float = float(zi) / 15.0
		var img: Image = Image.create(32, 2, false, Image.FORMAT_RGBA8)
		for i in 32:
			var up: float = float(i) / 31.0 * 2.0 - 1.0
			var c: Color = silver.lerp(back, smoothstep(0.25, 0.55, up))
			c = belly.lerp(c, smoothstep(-0.55, -0.15, up))
			var spots: float = (1.0 if fmod(s * 9.0, 1.0) > 0.5 else 0.0) * (1.0 - smoothstep(0.02, 0.1, absf(up - 0.22))) * (1.0 if s < 0.6 else 0.0)
			c = c.lerp(back * 0.6, spots * 0.7)
			img.set_pixel(i, 0, c)
			img.set_pixel(i, 1, Color(0.52, 0.60, 0.66))
		slices.append(img)
	return Kit.tex_material(slices)


func bench_row(name_: String) -> Array:
	var n: int = _pieces.size() / 2
	return [name_, str(n), "%.3f ms" % (cpu_us / 1000.0), str(_pieces.size()), "4D loft, 2 pieces"]
