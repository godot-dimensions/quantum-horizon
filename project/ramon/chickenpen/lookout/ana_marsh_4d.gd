@tool
extends Node4D

## A marsh that is only there along W: a pond, reeds, stones and a dead tree, all around
## w +8 and nothing at all at w 0. From the farm's slice this is open field. Drift ana in
## the balloon, or step ana on foot for eight metres, and the water comes up out of nothing.
##
## THE REEDS ARE SCATTERED THROUGH W as well as across the ground: each stands at its own w
## within about a metre and a half of the marsh's middle, and each is thin in W. So as you
## slide your slice through the marsh - on foot, or with the camera's focus ring - reeds
## come and go one by one, the way trees pass when you drive through a wood. It is the
## clearest picture this place gives of what "along W" means.
##
## Everything is boxes, sharing one mesh per size, as the tower is. This node sits at the
## marsh's middle (its own w is the marsh's w).

@export_range(1.0, 6.0, 0.1, "suffix:m") var w_depth: float = 3.0
@export_range(4.0, 30.0, 0.5, "suffix:m") var pond_size_x: float = 11.0
@export_range(4.0, 30.0, 0.5, "suffix:m") var pond_size_z: float = 7.0
@export var reed_count: int = 90
@export var marsh_seed: int = 808

var _meshes: Dictionary = {}
var _materials: Dictionary = {}


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	for child in get_children():
		child.free()
	_meshes.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = marsh_seed
	var px: float = pond_size_x
	var pz: float = pond_size_z
	# Wet ground round the water, then the water, darker where it is deep - each a cluster
	# of overlapping slabs turned to different angles, so the edges are ragged rather than
	# the rectangle one box gives (from the balloon, one box read as a map tile).
	var muds: Array = [Color(0.22, 0.24, 0.15), Color(0.25, 0.27, 0.16), Color(0.20, 0.22, 0.14)]
	for i in 7:
		var a: float = float(i) / 7.0 * TAU
		var at := Vector4(cos(a) * px * 0.28, 0.025 + 0.002 * float(i), sin(a) * pz * 0.3, 0.0)
		_box("Mud%d" % i, at, Vector4(px * rng.randf_range(0.55, 0.8), 0.05, pz * rng.randf_range(0.55, 0.8), w_depth + 1.0),
			muds[i % muds.size()], Basis4D.from_zx(rng.randf_range(-0.6, 0.6)))
	for i in 5:
		var a: float = float(i) / 5.0 * TAU + 0.4
		var at := Vector4(cos(a) * px * 0.16, 0.072 + 0.001 * float(i), sin(a) * pz * 0.16, 0.0)
		_box("Water%d" % i, at, Vector4(px * rng.randf_range(0.5, 0.68), 0.05, pz * rng.randf_range(0.5, 0.68), w_depth),
			Color(0.24, 0.34, 0.36), Basis4D.from_zx(rng.randf_range(-0.7, 0.7)))
	_box("Deep", Vector4(0.6, 0.08, -0.4, 0.0), Vector4(px * 0.38, 0.05, pz * 0.4, w_depth * 0.7), Color(0.16, 0.25, 0.28), Basis4D.from_zx(0.35))
	_box("Deep2", Vector4(-0.8, 0.08, 0.3, 0.0), Vector4(px * 0.3, 0.05, pz * 0.32, w_depth * 0.7), Color(0.16, 0.25, 0.28), Basis4D.from_zx(-0.5))
	# Tussocks of rough grass on the wet ground.
	for i in 18:
		var a: float = rng.randf() * TAU
		var at := Vector4(cos(a) * px * rng.randf_range(0.6, 0.85), 0.12, sin(a) * pz * rng.randf_range(0.6, 0.9), rng.randf_range(-1.0, 1.0))
		var r: float = rng.randf_range(0.3, 0.6)
		_box("Tussock%d" % i, at, Vector4(r, 0.22, r, 0.6), Color(0.40, 0.44, 0.20).lerp(Color(0.5, 0.48, 0.26), rng.randf()), Basis4D.from_zx(rng.randf() * TAU))
	# Lily pads: flat octagons on the water.
	for i in 9:
		var at := Vector4(rng.randf_range(-px * 0.35, px * 0.35), 0.11, rng.randf_range(-pz * 0.35, pz * 0.35), rng.randf_range(-0.8, 0.8))
		var r: float = rng.randf_range(0.25, 0.45)
		_box("Pad%d" % i, at, Vector4(r, 0.02, r, r), Color(0.30, 0.46, 0.22))
		_box("PadTurned%d" % i, at, Vector4(r, 0.02, r, r), Color(0.30, 0.46, 0.22), Basis4D.from_zx(PI * 0.25))
	# Reeds round the edge, in clumps, each at its own w.
	var reed_colours: Array = [Color(0.46, 0.48, 0.22), Color(0.56, 0.52, 0.28), Color(0.38, 0.42, 0.20), Color(0.64, 0.58, 0.36)]
	for i in reed_count:
		var angle: float = rng.randf() * TAU
		var edge := Vector2(cos(angle) * px * 0.5, sin(angle) * pz * 0.5) * rng.randf_range(0.85, 1.25)
		# Fewer on the side the heron stalks, so it has open water.
		if edge.x > px * 0.3 and rng.randf() < 0.6:
			continue
		var h: float = rng.randf_range(0.9, 1.9)
		var lean: float = rng.randf_range(-0.12, 0.12)
		var w: float = rng.randf_range(-w_depth * 0.5, w_depth * 0.5)
		var colour: Color = reed_colours[rng.randi() % reed_colours.size()]
		var at := Vector4(edge.x, h * 0.5, edge.y, w)
		_box("Reed%d" % i, at, Vector4(0.035, h, 0.035, 0.45), colour, Basis4D.from_xy(lean))
		if rng.randf() < 0.45:
			_box("Cattail%d" % i, at + Vector4(-sin(lean) * h * 0.42, h * 0.42, 0.0, 0.0), Vector4(0.07, 0.22, 0.07, 0.45), Color(0.36, 0.22, 0.12), Basis4D.from_xy(lean))
	# Stones at the water's edge, and one to stand on.
	for i in 7:
		var angle: float = rng.randf() * TAU
		var at := Vector4(cos(angle) * px * 0.52, 0.1, sin(angle) * pz * 0.52, rng.randf_range(-0.6, 0.6))
		var s: float = rng.randf_range(0.3, 0.7)
		_box("Stone%d" % i, at, Vector4(s, s * 0.5, s * 0.8, s * 0.8), Color(0.45, 0.45, 0.42), Basis4D.from_zx(rng.randf() * TAU))
	# A dead tree on the far bank: a grey trunk and two branches, where the heron goes
	# when it is disturbed.
	var snag := Vector4(-px * 0.5 - 1.2, 0.0, pz * 0.25, 0.3)
	_box("Snag", snag + Vector4(0, 1.5, 0, 0), Vector4(0.26, 3.0, 0.26, 0.6), Color(0.48, 0.46, 0.42))
	_box("SnagBranch", snag + Vector4(0.45, 2.4, 0, 0), Vector4(0.12, 1.2, 0.12, 0.5), Color(0.48, 0.46, 0.42), Basis4D.from_xy(-0.9))
	_box("SnagBranch2", snag + Vector4(-0.35, 2.9, 0.1, 0), Vector4(0.1, 0.9, 0.1, 0.5), Color(0.48, 0.46, 0.42), Basis4D.from_xy(0.8))


## Where the heron stands to fish, in the marsh's own space.
func fishing_spot() -> Vector4:
	return Vector4(pond_size_x * 0.32, 0.08, -pond_size_z * 0.12, 0.0)


## Where it goes when it is put up: the far bank, by the dead tree.
func refuge_spot() -> Vector4:
	return Vector4(-pond_size_x * 0.38, 0.08, pond_size_z * 0.3, 0.2)


func _box(part: String, at: Vector4, size: Vector4, colour: Color, basis: Projection = Projection.IDENTITY) -> void:
	var key: String = "%.3f,%.3f,%.3f,%.3f" % [size.x, size.y, size.z, size.w]
	if not _meshes.has(key):
		var mesh := BoxTetraMesh4D.new()
		mesh.size = size
		_meshes[key] = mesh
	var ckey: String = colour.to_html()
	if not _materials.has(ckey):
		var m := TetraMaterial4D.new()
		m.albedo_color = colour
		_materials[ckey] = m
	var node := MeshInstance4D.new()
	node.name = part
	node.mesh = _meshes[key]
	node.material_override = _materials[ckey]
	add_child(node, true)
	node.position = at
	if basis != Projection.IDENTITY:
		node.basis = basis
