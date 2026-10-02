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
##
## ONE MESH PER COLOUR, NOT ONE NODE PER BOX. Every MeshInstance4D costs something each
## frame whether or not it is on screen, and this is a few hundred boxes that never move.
## So with [member merge_parts] on (the default) the boxes of each colour are merged into a
## single ArrayTetraMesh4D (TetraMesh4D.to_array_tetra_mesh, ArrayTetraMesh4D.merge_with)
## and drawn by one node. Off, every box is its own named node, for picking parts apart.

@export_range(1.0, 6.0, 0.1, "suffix:m") var w_depth: float = 3.0
@export_range(4.0, 30.0, 0.5, "suffix:m") var pond_size_x: float = 11.0
@export_range(4.0, 30.0, 0.5, "suffix:m") var pond_size_z: float = 7.0
@export var reed_count: int = 90
@export var marsh_seed: int = 808
@export var merge_parts: bool = true

var _meshes: Dictionary = {}
var _batches: Dictionary = {}
var _arrays: Dictionary = {}
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
	# Wet ground round the water, then the water, darker where it is deep: round, as a pond
	# is - discs of boxes turned about the vertical (six squares make a 24-sided round),
	# stretched a little to an oval. (Ramon, 2 Oct: "instead of a boxed pond why not try a
	# cylinder shape".)
	var oval: float = pz / px
	_disc("Mud", Vector4(0.0, 0.03, 0.0, 0.0), px * 0.5 + 3.2, 0.05, w_depth + 1.0, Color(0.23, 0.25, 0.15), oval)
	_disc("Shore", Vector4(0.0, 0.05, 0.0, 0.0), px * 0.5 + 1.0, 0.05, w_depth + 0.6, Color(0.30, 0.29, 0.20), oval)
	_disc("Water", Vector4(0.0, 0.075, 0.0, 0.0), px * 0.5, 0.05, w_depth, Color(0.24, 0.34, 0.36), oval)
	_disc("Deep", Vector4(0.5, 0.082, -0.3, 0.0), px * 0.27, 0.05, w_depth * 0.7, Color(0.16, 0.25, 0.28), oval)
	# Lily pads: small discs on the water.
	for i in 9:
		var at := Vector4(rng.randf_range(-px * 0.33, px * 0.33), 0.11, rng.randf_range(-pz * 0.33, pz * 0.33), rng.randf_range(-0.8, 0.8))
		_disc("Pad%d" % i, at, rng.randf_range(0.2, 0.36), 0.02, 0.5, Color(0.30, 0.46, 0.22), 1.0, 2)
	# Tussocks of rough grass on the wet ground.
	for i in 18:
		var a: float = rng.randf() * TAU
		var at := Vector4(cos(a) * px * rng.randf_range(0.6, 0.85), 0.12, sin(a) * pz * rng.randf_range(0.6, 0.9), rng.randf_range(-1.0, 1.0))
		var r: float = rng.randf_range(0.3, 0.6)
		_box("Tussock%d" % i, at, Vector4(r, 0.22, r, 0.6), [Color(0.40, 0.44, 0.20), Color(0.45, 0.46, 0.23), Color(0.5, 0.48, 0.26)][rng.randi() % 3], Basis4D.from_zx(rng.randf() * TAU))
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
	_flush()


## Where the heron stands to fish, in the marsh's own space.
func fishing_spot() -> Vector4:
	return Vector4(pond_size_x * 0.32, 0.08, -pond_size_z * 0.12, 0.0)


## Where it goes when it is put up: the far bank, by the dead tree.
func refuge_spot() -> Vector4:
	return Vector4(-pond_size_x * 0.38, 0.08, pond_size_z * 0.3, 0.2)


## A flat round of radius [param r], [param thick] high and [param deep] in W: [param n] boxes
## turned about the vertical, overlapping into a 4n-sided round, stretched along z by
## [param oval].
func _disc(part: String, at: Vector4, r: float, thick: float, deep: float, colour: Color, oval: float = 1.0, n: int = 6) -> void:
	for k in n:
		var turn: Projection = Basis4D.from_scale(Vector4(1.0, 1.0, oval, 1.0)) * Basis4D.from_zx(float(k) * PI * 0.5 / float(n))
		_box(part + str(k), at, Vector4(r * 2.0, thick, r * 2.0, deep), colour, turn)


func _box(part: String, at: Vector4, size: Vector4, colour: Color, basis: Projection = Projection.IDENTITY) -> void:
	if merge_parts:
		_batch(part, at, size, colour, basis)
		return
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

## Into this colour's merged mesh, or a node of its own when merging is off.
func _batch(_part: String, at: Vector4, size: Vector4, colour: Color, basis: Projection) -> MeshInstance4D:
	var key: String = colour.to_html()
	if not _batches.has(key):
		_batches[key] = [ArrayTetraMesh4D.new(), colour]
	var skey: String = "%.3f,%.3f,%.3f,%.3f" % [size.x, size.y, size.z, size.w]
	if not _arrays.has(skey):
		var box := BoxTetraMesh4D.new()
		box.size = size
		_arrays[skey] = box.to_array_tetra_mesh()
	(_batches[key][0] as ArrayTetraMesh4D).merge_with(_arrays[skey], at, basis)
	return null


## The merged meshes, one node each.
func _flush() -> void:
	for key in _batches:
		var node := MeshInstance4D.new()
		node.name = "Parts_" + String(key)
		node.mesh = _batches[key][0]
		var m := TetraMaterial4D.new()
		m.albedo_color = _batches[key][1]
		node.material_override = m
		add_child(node, true)
	_batches.clear()
