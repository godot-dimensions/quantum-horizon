@tool
extends Node4D

## A wood that is only there along KATA: four trees, a fallen log, leaf litter, a burrow, and
## the chipmunks that live in it. At w -8, over the same patch of field as the marsh is at
## w +8 - the same place, two different worlds either side of the farm's slice, which is the
## clearest thing this subgame says about W: a direction has two ways, and there is something
## each way. The balloon's fork picks one (balloon_4d.gd); on foot it is eight metres of Q.
##
## THE CHIPMUNK TREE is the one in the middle, rounder in W than the others (its trunk is as
## deep in W as it is across), so a chipmunk that runs round it can go round through W: the
## behaviour the journal's fourth slot asks for (chipmunk_4d.gd).
##
## Trees from lookout_tree_4d.gd (lofted once, merged, a node or two each); the ground cover is
## cubinders and boxes merged per colour into one mesh each, as the marsh is.

const TREE := preload("res://ramon/chickenpen/lookout/lookout_tree_4d.gd")
const RIG := preload("res://ramon/chickenpen/scripts/loft_rig_4d.gd")
const BALL := preload("res://ramon/chickenpen/scripts/loft_ball_4d.gd")

@export var wood_seed: int = 4242
@export_range(2.0, 10.0, 0.5, "suffix:m") var spread: float = 5.0

## The chipmunks' tree, built.
var tree: Node4D
var _batches: Dictionary = {}
var _arrays: Dictionary = {}


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	for child in get_children():
		child.free()
	_batches.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = wood_seed
	# The chipmunk tree, and three more round it - one of them dead.
	tree = _tree("ChipmunkTree", Vector4.ZERO, 8.5, 0.36, 0.85, 52, TREE.Style.LEAFY)
	_tree("Tree2", Vector4(spread * 1.1, 0.0, -spread * 0.6, 0.6), 7.0, 0.28, 0.6, 9, TREE.Style.LEAFY)
	_tree("Tree3", Vector4(-spread * 0.9, 0.0, spread * 0.7, -0.5), 6.5, 0.26, 0.6, 21, TREE.Style.LEAFY)
	_tree("Snag", Vector4(spread * 0.5, 0.0, spread * 1.2, 0.3), 5.5, 0.22, 0.6, 7, TREE.Style.DEAD)
	# The fallen log, mossy on top.
	var log_rig := MeshInstance4D.new()
	log_rig.name = "Log"
	log_rig.set_script(RIG)
	add_child(log_rig)
	log_rig.set("live_rebuild", false)
	log_rig.set("mirror_x", false)
	log_rig.set("verbose", false)
	log_rig.set("profile_sides", 6)
	log_rig.set("profile_rings", 3)
	var m := TetraMaterial4D.new()
	m.albedo_color = Color(0.40, 0.31, 0.22)
	log_rig.material_override = m
	for k in 3:
		var b := MeshInstance4D.new()
		b.set_script(BALL)
		log_rig.add_child(b)
		b.position = Vector4(-1.6 + 1.6 * float(k), 0.26 + 0.01 * float(k), 0.0, 0.0)
		b.set("radius", 0.26 - 0.03 * absf(float(k) - 1.0))
		b.set("w_scale", 0.8)
	log_rig.call("build", false)
	log_rig.position = Vector4(-2.6, 0.0, -2.4, 0.2)
	log_rig.basis = Basis4D.from_zx(0.7)
	_disc(Vector4(-2.6, 0.5, -2.4, 0.2), 0.5, 0.04, 0.4, Color(0.34, 0.48, 0.22), 1.0, 10)
	# Leaf litter: low discs of brown and orange, thickest round the trees.
	var litter: Array = [Color(0.45, 0.30, 0.15), Color(0.55, 0.36, 0.14), Color(0.38, 0.28, 0.16), Color(0.62, 0.44, 0.18)]
	for i in 26:
		var a: float = rng.randf() * TAU
		var r: float = sqrt(rng.randf()) * spread * 1.4
		var at := Vector4(cos(a) * r, 0.015, sin(a) * r, rng.randf_range(-1.2, 1.2))
		_disc(at, rng.randf_range(0.4, 1.1), 0.02, 0.8, litter[rng.randi() % litter.size()], rng.randf_range(0.6, 1.0), 10)
	# The burrow at the chipmunk tree's foot: a dark hole with a lip of earth.
	_disc(burrow() + Vector4(0.0, 0.01, 0.0, 0.0), 0.22, 0.03, 0.3, Color(0.32, 0.24, 0.16), 1.0, 12)
	_disc(burrow() + Vector4(0.0, 0.025, 0.0, 0.0), 0.12, 0.02, 0.22, Color(0.06, 0.05, 0.04), 1.0, 10)
	# Mushrooms by the log, and ferns.
	for i in 5:
		var at := Vector4(-2.6 + rng.randf_range(-1.2, 1.2), 0.0, -2.4 + rng.randf_range(0.3, 0.8), rng.randf_range(-0.2, 0.2))
		var h: float = rng.randf_range(0.06, 0.12)
		_disc(at + Vector4(0.0, h * 0.5, 0.0, 0.0), 0.015, h, 0.03, Color(0.86, 0.82, 0.72), 1.0, 6)
		_disc(at + Vector4(0.0, h, 0.0, 0.0), rng.randf_range(0.04, 0.07), 0.025, 0.06, Color(0.72, 0.30, 0.16), 1.0, 8)
	for i in 9:
		var a: float = rng.randf() * TAU
		var at := Vector4(cos(a) * rng.randf_range(1.5, spread * 1.3), 0.0, sin(a) * rng.randf_range(1.5, spread * 1.3), rng.randf_range(-0.8, 0.8))
		for f in 5:
			var turn: float = float(f) / 5.0 * TAU + rng.randf() * 0.4
			_box(at + Vector4(cos(turn) * 0.22, 0.14, sin(turn) * 0.22, 0.0), Vector4(0.06, 0.02, 0.45, 0.3), Color(0.30, 0.46, 0.20),
				Basis4D.from_zx(turn + PI * 0.5) * Basis4D.from_yz(-0.5))
	_flush()


## Where the burrow is, in the wood's own space.
func burrow() -> Vector4:
	return Vector4(0.62, 0.0, 0.45, 0.0)


func _tree(part: String, at: Vector4, h: float, r: float, ws: float, seed_value: int, style: int) -> Node4D:
	var t := Node4D.new()
	t.name = part
	t.set_script(TREE)
	t.set("style", style)
	t.set("height", h)
	t.set("trunk_radius", r)
	t.set("w_scale", ws)
	t.set("limb_count", (5 if part == "ChipmunkTree" else 4) if style == TREE.Style.LEAFY else 3)
	t.set("tree_seed", seed_value)
	t.set("bark", Color(0.42, 0.33, 0.25) if style == TREE.Style.LEAFY else Color(0.50, 0.49, 0.46))
	t.position = at
	add_child(t)
	return t


func _disc(at: Vector4, r: float, thick: float, deep: float, colour: Color, oval: float = 1.0, segments: int = 12) -> void:
	var key: String = "disc%.3f,%.3f,%.3f,%d" % [r, thick, deep, segments]
	if not _arrays.has(key):
		var shape := CubinderShape4D.new()
		shape.radius = r
		shape.height = thick
		shape.thickness = deep
		_arrays[key] = shape.to_tetra_mesh({"segments": segments}).to_array_tetra_mesh()
	_merge(colour, _arrays[key], at, Basis4D.from_scale(Vector4(1.0, 1.0, oval, 1.0)))


func _box(at: Vector4, size: Vector4, colour: Color, basis: Projection = Projection.IDENTITY) -> void:
	var key: String = "box%.3f,%.3f,%.3f,%.3f" % [size.x, size.y, size.z, size.w]
	if not _arrays.has(key):
		var box := BoxTetraMesh4D.new()
		box.size = size
		_arrays[key] = box.to_array_tetra_mesh()
	_merge(colour, _arrays[key], at, basis)


func _merge(colour: Color, mesh: ArrayTetraMesh4D, at: Vector4, basis: Projection) -> void:
	var key: String = colour.to_html()
	if not _batches.has(key):
		_batches[key] = [ArrayTetraMesh4D.new(), colour]
	(_batches[key][0] as ArrayTetraMesh4D).merge_with(mesh, at, basis)


func _flush() -> void:
	for key in _batches:
		var node := MeshInstance4D.new()
		node.name = "Ground_" + String(key)
		node.mesh = _batches[key][0]
		var m := TetraMaterial4D.new()
		m.albedo_color = _batches[key][1]
		node.material_override = m
		add_child(node)
	_batches.clear()
