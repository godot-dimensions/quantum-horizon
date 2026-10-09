extends Node4D

## WATER LAB: the tank's weed beds, the pen's grass taken under water (life/weed.gdshader says what was
## kept and what changed). Kelp at the back corners reaching for the surface, seagrass meadows along
## the back and round the rocks, short tufts at the front: about six hundred blades, rooted on the
## dunes (`ground`), spread through W so a turned slice finds other beds. One slice herd, written once:
## the CPU spends nothing a frame on it. In the water's own frame (life/).
##
## NO class_name (engine_gotchas.md).

const Herd := preload("res://ramon/WaterLab/shared/slice_herd_4d.gd")
const SHADER := preload("res://ramon/WaterLab/life/weed.gdshader")

var half_extents: Vector4 = Vector4(9.2, 2.4, 1.6, 3.5)
var floor_y: float = -2.14
## The dunes (dunes_4d.gd height_at); null: the flat floor.
var ground: Node = null
var herd: Node4D
## The carpets of small weed (Ramon, 9 Oct: "next to the big seaweed, i also want smaller seeweed and in
## much higher quantity"): short blades in their thousands, in clumps over the dunes.
var turf: Node4D
@export var turf_count: int = 3500
var blades: int = 0
var _rng := RandomNumberGenerator.new()
var _clump := FastNoiseLite.new()


func _ready() -> void:
	_rng.seed = 3301
	_clump.seed = 77
	_clump.frequency = 0.45
	var rows: Array = []
	var kelp := Color(0.40, 0.33, 0.10)
	var grass := Color(0.16, 0.40, 0.12)
	var light := Color(0.36, 0.58, 0.18)
	var top: float = half_extents.y * 2.0 - 0.4
	var he: Vector4 = half_extents
	# Kelp forests in the two back corners, reaching the surface.
	for corner in [-1.0, 1.0]:
		for i in 46:
			# Clear of the end glass: the right one (it swayed through the glass, round 3) well in from it.
			var x: float = corner * (he.x - _rng.randf_range(0.9, 3.0)) if corner < 0.0 else he.x - _rng.randf_range(2.6, 4.8)
			_add(rows, x, _rng.randf_range(-1.5, -0.4), _rng.randf_range(-1.6, 1.6), _rng.randf_range(2.4, top), _rng.randf_range(0.18, 0.32), kelp.lerp(grass, _rng.randf() * 0.3), 1.0)
	# Seagrass meadows along the back.
	for i in 300:
		_add(rows, _rng.randf_range(-he.x + 0.6, he.x - 0.6), _rng.randf_range(-1.55, -0.6), _rng.randf_range(-1.8, 1.8), _rng.randf_range(0.8, 2.4), _rng.randf_range(0.04, 0.08), grass.lerp(light, _rng.randf()), 0.45)
	# Patches in the open sand, between the rocks.
	for patch in [Vector3(-6.0, 0.4, 0.2), Vector3(-0.6, 0.6, -0.3), Vector3(4.2, 0.3, 0.4), Vector3(7.6, 0.2, -0.5)]:
		for i in 34:
			_add(rows, patch.x + _rng.randf_range(-0.9, 0.9), patch.y + _rng.randf_range(-0.4, 0.4), patch.z + _rng.randf_range(-1.2, 1.2), _rng.randf_range(0.5, 1.5), _rng.randf_range(0.03, 0.06), light.lerp(grass, _rng.randf()), 0.35)
	# Short tufts at the front corners.
	for corner in [-1.0, 1.0]:
		for i in 22:
			_add(rows, corner * (he.x - _rng.randf_range(0.3, 1.6)), _rng.randf_range(0.6, 1.35), _rng.randf_range(-1.0, 1.0), _rng.randf_range(0.3, 0.8), _rng.randf_range(0.03, 0.05), light, 0.25)
	# Round 4 (Ramon: "a few additional, denser clumps of seaweed. Vary the density"): tight clumps of
	# the long weed, each a different size and thickness, scattered unevenly, some off the slice. Their
	# own random numbers, after the rest, so the weed that was there stays where it was.
	var crng := RandomNumberGenerator.new()
	crng.seed = 4402
	# (_add draws a colour jitter from _rng: its state is put back after, so the turf is as it was.)
	var kept: int = _rng.state
	for clump in [[Vector4(-8.9, 0.0, -0.9, 0.3), 26, 0.45], [Vector4(-3.3, 0.0, -1.1, -0.8), 18, 0.3], [Vector4(1.8, 0.0, 0.9, 0.2), 12, 0.25],
			[Vector4(5.4, 0.0, -1.2, 1.1), 22, 0.4], [Vector4(8.1, 0.0, 0.7, -0.4), 9, 0.2]]:
		var at: Vector4 = clump[0]
		for i in int(clump[1]):
			var rr: float = float(clump[2]) * sqrt(crng.randf())
			var ang: float = crng.randf() * TAU
			_add(rows, at.x + cos(ang) * rr, at.z + sin(ang) * rr * 0.7, at.w + crng.randf_range(-0.25, 0.25), crng.randf_range(1.6, 3.4),
				crng.randf_range(0.10, 0.22), grass.lerp(kelp, crng.randf() * 0.6), 0.6)
	_rng.state = kept
	blades = rows.size()
	herd = Node4D.new()
	herd.name = "WeedHerd"
	herd.set_script(Herd)
	herd.set("mesh", _blade())
	herd.set("shader", SHADER)
	herd.set("w_radius", 0.45)
	herd.set("count", blades)
	add_child(herd)
	for i in blades:
		var r: Array = rows[i]
		herd.call("write", i, r[0], Vector4(0, 0, 1, 0), Vector4(1, 0, 0, 0), r[2], r[1])
	herd.call("upload")
	_build_turf()


## The carpets: points over the whole floor (x, z AND W) kept where a clump noise says a meadow grows,
## short blades in greens with some red weed among them. Their own herd, a shorter blade.
func _build_turf() -> void:
	var rows: Array = []
	var meadow := FastNoiseLite.new()
	meadow.seed = 913
	meadow.frequency = 0.32
	var greens: Array = [Color(0.20, 0.46, 0.14), Color(0.34, 0.56, 0.16), Color(0.12, 0.34, 0.16), Color(0.46, 0.50, 0.18)]
	var reds: Array = [Color(0.48, 0.12, 0.12), Color(0.62, 0.24, 0.16)]
	var he: Vector4 = half_extents
	var tries: int = 0
	while rows.size() < turf_count and tries < turf_count * 8:
		tries += 1
		var x: float = _rng.randf_range(-he.x + 0.2, he.x - 0.2)
		var z: float = _rng.randf_range(-he.z + 0.15, he.z - 0.35)
		var w: float = _rng.randf_range(-1.6, 1.6)
		if meadow.get_noise_3d(x, z * 1.5, w) < 0.05:
			continue
		var red: bool = _rng.randf() < 0.12
		var c: Color = reds[_rng.randi_range(0, 1)] if red else greens[_rng.randi_range(0, greens.size() - 1)]
		_add(rows, x, z, w, _rng.randf_range(0.14, 0.62), _rng.randf_range(0.015, 0.04) * (1.8 if red else 1.0), c, 0.3)
	turf = Node4D.new()
	turf.name = "TurfHerd"
	turf.set_script(Herd)
	turf.set("mesh", _blade(8))
	turf.set("shader", SHADER)
	turf.set("w_radius", 0.45)
	turf.set("count", rows.size())
	add_child(turf)
	for i in rows.size():
		var r: Array = rows[i]
		turf.call("write", i, r[0], Vector4(0, 0, 1, 0), Vector4(1, 0, 0, 0), r[2], r[1])
	turf.call("upload")
	blades += rows.size()


## One blade rooted on the sand at (x, z, w): its height, width, colour and looseness; its clump
## (lush or dry) from noise on its root, as the grass's clumps are.
func _add(rows: Array, x: float, z: float, w: float, height: float, width: float, colour: Color, loose: float) -> void:
	z = clampf(z, -half_extents.z + 0.1, half_extents.z - 0.1)
	var y: float = float(ground.call("height_at", x, z, w)) if ground != null else floor_y
	var c: Color = Color.from_hsv(fposmod(colour.h + _rng.randf_range(-0.03, 0.03), 1.0), clampf(colour.s * _rng.randf_range(0.85, 1.15), 0.0, 1.0), colour.v * _rng.randf_range(0.85, 1.1))
	c.a = clampf(0.5 + 0.8 * _clump.get_noise_3d(x, z, w), 0.0, 1.0)
	rows.append([Vector4(x, y - 0.02, z, w), Vector4(height, width, _rng.randf() * TAU, loose), c])


## One blade: a strip up y, `n` segments, UV.x up it, UV.y across.
static func _blade(n: int = 20) -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	var idx := PackedInt32Array()
	for i in n + 1:
		var h: float = float(i) / float(n)
		for a in [-1.0, 0.0, 1.0]:
			verts.append(Vector3(a, h, 0.0))
			uvs.append(Vector2(h, a))
			normals.append(Vector3(0, 0, 1))
	for i in n:
		for j in 2:
			var a0: int = i * 3 + j
			idx.append_array([a0, a0 + 1, a0 + 4, a0, a0 + 4, a0 + 3])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var col := PackedColorArray()
	col.resize(verts.size())
	col.fill(Color.WHITE)
	arrays[Mesh.ARRAY_COLOR] = col
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.custom_aabb = AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000))
	return mesh


func bench_row() -> Array:
	return ["Weed", str(blades), "0 ms", "1", "swayed on the GPU"]
