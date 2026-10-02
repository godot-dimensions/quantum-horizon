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
## The water and the ground round it are CUBINDERS (CubinderShape4D.to_tetra_mesh): a true
## circle in XZ, extruded up a few centimetres and through W, so every slice of it is a
## round pond, stretched to an oval. The rest is boxes, sharing one mesh per size, as the
## tower is. This node sits at the marsh's middle (its own w is the marsh's w).
##
## ONE MESH PER COLOUR, NOT ONE NODE PER BOX. Every MeshInstance4D costs something each
## frame whether or not it is on screen, and this is a few hundred boxes that never move.
## So with [member merge_parts] on (the default) the boxes of each colour are merged into a
## single ArrayTetraMesh4D (TetraMesh4D.to_array_tetra_mesh, ArrayTetraMesh4D.merge_with)
## and drawn by one node. Off, every box is its own named node, for picking parts apart.

const TREE := preload("res://ramon/chickenpen/lookout/lookout_tree_4d.gd")

@export_range(1.0, 6.0, 0.1, "suffix:m") var w_depth: float = 3.0
@export_range(4.0, 30.0, 0.5, "suffix:m") var pond_size_x: float = 11.0
@export_range(4.0, 30.0, 0.5, "suffix:m") var pond_size_z: float = 7.0
@export var reed_count: int = 90
@export var marsh_seed: int = 808
@export var merge_parts: bool = true
## The heron, for the rings where it steps and strikes (set by lookout_4d.gd).
@export var heron_path: NodePath
@export var lookout_path: NodePath

## WATER THAT READS AS WATER. The 4D material has a colour and nothing else - no gloss, no
## transparency - so water has to be told by how it moves: rings spreading from where
## something touched it (a ring is a pale disc with a water-coloured one on top, the inner
## growing a little behind the outer), and a few glints that come and go. The reeds stand in
## clumps that sway, each clump one merged mesh on a pivot at its foot, so a sway is a node
## turning - nothing re-lofts or re-merges. All of it only while a camera can see the marsh.
const WATER := Color(0.24, 0.34, 0.36)
const RING := Color(0.55, 0.66, 0.68)
const SECTORS := 8

var _clumps: Array = []
var _rings: Array = []
var _glints: Array = []
var _t: float = 0.0
var _next_ring: float = 1.0
var _seen: bool = true
var _seen_check: float = 0.0
var _rng := RandomNumberGenerator.new()
var _heron_last := Vector4.ZERO
var _reed_batches: Dictionary = {}

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
	# is - real discs, stretched a little to an oval. (Ramon, 2 Oct: "instead of a boxed pond
	# why not try a cylinder shape".)
	var oval: float = pz / px
	_disc("Mud", Vector4(0.0, 0.03, 0.0, 0.0), px * 0.5 + 3.2, 0.05, w_depth + 1.0, Color(0.23, 0.25, 0.15), oval)
	_disc("Shore", Vector4(0.0, 0.05, 0.0, 0.0), px * 0.5 + 1.0, 0.05, w_depth + 0.6, Color(0.30, 0.29, 0.20), oval)
	_disc("Water", Vector4(0.0, 0.075, 0.0, 0.0), px * 0.5, 0.05, w_depth, WATER, oval)
	# The shallows: a paler band just inside the edge, so the water has an edge to read by.
	_disc("Shallows", Vector4(0.0, 0.078, 0.0, 0.0), px * 0.5 - 0.15, 0.05, w_depth * 0.95, WATER.lerp(Color(0.40, 0.46, 0.40), 0.45), oval)
	_disc("Open", Vector4(0.0, 0.08, 0.0, 0.0), px * 0.5 - 0.75, 0.05, w_depth * 0.92, WATER, oval)
	_disc("Deep", Vector4(0.5, 0.082, -0.3, 0.0), px * 0.27, 0.05, w_depth * 0.7, Color(0.16, 0.25, 0.28), oval)
	# Lily pads: small discs on the water.
	for i in 9:
		var at := Vector4(rng.randf_range(-px * 0.33, px * 0.33), 0.11, rng.randf_range(-pz * 0.33, pz * 0.33), rng.randf_range(-0.8, 0.8))
		_disc("Pad%d" % i, at, rng.randf_range(0.2, 0.36), 0.02, 0.5, Color(0.30, 0.46, 0.22), 1.0, 10)
	# Tussocks of rough grass on the wet ground.
	for i in 18:
		var a: float = rng.randf() * TAU
		var at := Vector4(cos(a) * px * rng.randf_range(0.6, 0.85), 0.12, sin(a) * pz * rng.randf_range(0.6, 0.9), rng.randf_range(-1.0, 1.0))
		var r: float = rng.randf_range(0.3, 0.6)
		# Round tufts, two tiers, the top one narrower.
		var tuft: Color = [Color(0.40, 0.44, 0.20), Color(0.45, 0.46, 0.23), Color(0.5, 0.48, 0.26)][rng.randi() % 3]
		_disc("Tussock%d" % i, at, r * 0.5, 0.16, 0.6, tuft, 1.0, 8)
		_disc("TussockTop%d" % i, at + Vector4(0.0, 0.1, 0.0, 0.0), r * 0.33, 0.12, 0.5, tuft.lightened(0.06), 1.0, 6)
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
		# Into the clump for its side of the pond, to sway with it.
		var sector: int = int(floor(fposmod(atan2(edge.y, edge.x), TAU) / TAU * float(SECTORS))) % SECTORS
		_reed(sector, at, Vector4(0.035, h, 0.035, 0.45), colour, Basis4D.from_xy(lean))
		if rng.randf() < 0.45:
			_reed(sector, at + Vector4(-sin(lean) * h * 0.42, h * 0.42, 0.0, 0.0), Vector4(0.07, 0.22, 0.07, 0.45), Color(0.36, 0.22, 0.12), Basis4D.from_xy(lean))
	# Stones at the water's edge, and one to stand on.
	for i in 7:
		var angle: float = rng.randf() * TAU
		var at := Vector4(cos(angle) * px * 0.52, 0.1, sin(angle) * pz * 0.52, rng.randf_range(-0.6, 0.6))
		var s: float = rng.randf_range(0.3, 0.7)
		# Rounded, and a little rounder on top: a wide low disc under a smaller one.
		_disc("Stone%d" % i, at, s * 0.5, s * 0.3, s * 0.8, Color(0.45, 0.45, 0.42), rng.randf_range(0.7, 1.0), 8)
		_disc("StoneTop%d" % i, at + Vector4(0.0, s * 0.2, 0.0, 0.0), s * 0.36, s * 0.16, s * 0.7, Color(0.49, 0.49, 0.46), 1.0, 7)
	# A dead tree on the far bank, where the heron goes when it is disturbed: lofted, like the
	# owl's (lookout_tree_4d.gd).
	var snag := Node4D.new()
	snag.name = "Snag"
	snag.set_script(TREE)
	snag.set("height", 4.8)
	snag.set("trunk_radius", 0.22)
	snag.set("limb_count", 3)
	snag.set("tree_seed", 17)
	add_child(snag)
	snag.position = Vector4(-px * 0.5 - 1.2, 0.0, pz * 0.25, 0.3)
	_flush()
	_flush_reeds()
	_build_rings_and_glints(rng)


## A reed into its side's clump: placed relative to the clump's foot, which is where it turns.
func _reed(sector: int, at: Vector4, size: Vector4, colour: Color, basis: Projection) -> void:
	var a: float = (float(sector) + 0.5) / float(SECTORS) * TAU
	var foot := Vector4(cos(a) * pond_size_x * 0.55, 0.0, sin(a) * pond_size_z * 0.55, 0.0)
	var key: String = "%d_%s" % [sector, colour.to_html()]
	if not _reed_batches.has(key):
		_reed_batches[key] = [ArrayTetraMesh4D.new(), colour, foot, sector]
	var skey: String = "%.3f,%.3f,%.3f,%.3f" % [size.x, size.y, size.z, size.w]
	if not _arrays.has(skey):
		var box := BoxTetraMesh4D.new()
		box.size = size
		_arrays[skey] = box.to_array_tetra_mesh()
	(_reed_batches[key][0] as ArrayTetraMesh4D).merge_with(_arrays[skey], at - foot, basis)


func _flush_reeds() -> void:
	_clumps.clear()
	for key in _reed_batches:
		var b: Array = _reed_batches[key]
		var node := MeshInstance4D.new()
		node.name = "Reeds_" + String(key)
		node.mesh = b[0]
		node.material_override = _material(b[1])
		add_child(node)
		node.position = b[2]
		_clumps.append({"node": node, "phase": float(b[3]) * 0.9, "rate": 0.55 + 0.05 * float(int(b[3]) % 3)})
	_reed_batches.clear()


## Six rings, ready to spread, and ten glints.
func _build_rings_and_glints(rng: RandomNumberGenerator) -> void:
	_rings.clear()
	_glints.clear()
	var shape := CubinderShape4D.new()
	shape.radius = 1.0
	shape.height = 0.004
	shape.thickness = 0.5
	var unit: ArrayTetraMesh4D = shape.to_tetra_mesh({"segments": 20}).to_array_tetra_mesh()
	for i in 6:
		var outer := MeshInstance4D.new()
		outer.name = "Ring%d" % i
		outer.mesh = unit
		var mo := TetraMaterial4D.new()
		mo.albedo_color = RING
		outer.material_override = mo
		add_child(outer)
		var inner := MeshInstance4D.new()
		inner.name = "Inner"
		inner.mesh = unit
		var mi := TetraMaterial4D.new()
		mi.albedo_color = WATER
		inner.material_override = mi
		outer.add_child(inner)
		inner.position = Vector4(0.0, 0.003, 0.0, 0.0)
		outer.visible = false
		_rings.append({"node": outer, "inner": inner, "outer_m": mo, "t": 99.0, "size": 1.0})
	var glint := BoxTetraMesh4D.new()
	glint.size = Vector4(0.7, 0.003, 0.05, 0.4)
	var gm := TetraMaterial4D.new()
	gm.albedo_color = Color(0.78, 0.84, 0.82)
	for i in 10:
		var g := MeshInstance4D.new()
		g.name = "Glint%d" % i
		g.mesh = glint
		g.material_override = gm
		add_child(g)
		g.position = Vector4(rng.randf_range(-pond_size_x * 0.32, pond_size_x * 0.32), 0.087, rng.randf_range(-pond_size_z * 0.3, pond_size_z * 0.3), rng.randf_range(-0.6, 0.6))
		g.basis = Basis4D.from_zx(rng.randf_range(-0.3, 0.3))
		_glints.append({"node": g, "phase": rng.randf() * TAU, "rate": rng.randf_range(0.7, 1.6)})


## A ring spreading from [param at] (in the marsh's own space) out to [param size] metres.
func ripple(at: Vector4, size: float = 0.9) -> void:
	for r in _rings:
		if float(r["t"]) > 2.2:
			r["t"] = 0.0
			r["size"] = size
			(r["node"] as Node4D).position = Vector4(at.x, 0.084, at.z, at.w)
			(r["node"] as Node4D).visible = true
			return


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	_seen_check -= delta
	if _seen_check <= 0.0:
		_seen_check = 0.5
		_seen = _visible_to_camera()
	if not _seen:
		return
	# Reeds: each clump on its own slow sway, a gust passing round the pond.
	for c in _clumps:
		var k: float = _t * float(c["rate"]) + float(c["phase"])
		(c["node"] as Node4D).basis = Basis4D.from_xy(sin(k) * 0.035 + sin(k * 2.3) * 0.012) * Basis4D.from_yz(cos(k * 0.8) * 0.025)
	# Glints that come and go.
	for g in _glints:
		(g["node"] as Node4D).visible = sin(_t * float(g["rate"]) + float(g["phase"])) > 0.55
	# Rings: now and then from nothing (a fish, a fly), and where the heron's feet go in.
	_next_ring -= delta
	if _next_ring <= 0.0:
		_next_ring = _rng.randf_range(1.2, 3.0)
		ripple(Vector4(_rng.randf_range(-pond_size_x * 0.3, pond_size_x * 0.3), 0.0, _rng.randf_range(-pond_size_z * 0.3, pond_size_z * 0.3), _rng.randf_range(-0.5, 0.5)), _rng.randf_range(0.5, 0.9))
	var heron := get_node_or_null(heron_path) as Node4D
	if heron != null and heron.is_visible_in_tree():
		var here: Vector4 = global_basis.inverse() * (heron.global_position - global_position)
		var st: int = int(heron.get("state"))
		# A step (it moved) or the stab (state 4) puts a ring on the water.
		if here.distance_to(_heron_last) > 0.12 and st == 3:
			ripple(here, 0.6)
			_heron_last = here
		elif st == 4 and float(heron.get("_state_t")) > 0.5 and float(heron.get("_state_t")) < 0.55:
			ripple(here + heron.basis * Vector4(0.0, 0.0, 0.3 * float(heron.get("size")), 0.0), 1.2)
	for r in _rings:
		var t: float = float(r["t"])
		if t > 2.2:
			continue
		t += delta
		r["t"] = t
		var k: float = t / 2.2
		var size: float = lerpf(0.08, float(r["size"]), sqrt(k))
		var node: Node4D = r["node"]
		node.basis = Basis4D.from_scale(Vector4(size, 1.0, size, 1.0))
		(r["inner"] as Node4D).basis = Basis4D.from_scale(Vector4(clampf(1.0 - 0.18 / maxf(size, 0.1), 0.0, 1.0), 1.0, clampf(1.0 - 0.18 / maxf(size, 0.1), 0.0, 1.0), 1.0))
		(r["outer_m"] as TetraMaterial4D).albedo_color = RING.lerp(WATER, k)
		if t > 2.2:
			node.visible = false


func _visible_to_camera() -> bool:
	var lookout: Node = get_node_or_null(lookout_path)
	if lookout == null:
		return true
	var cam: Camera4D = lookout.call("current_camera")
	if cam == null:
		return true
	var rel: Vector4 = global_position - cam.global_position
	return absf(rel.dot(cam.global_basis.w)) < w_depth + 2.0 and rel.length() < 90.0


## Where the heron stands to fish, in the marsh's own space.
func fishing_spot() -> Vector4:
	return Vector4(pond_size_x * 0.32, 0.08, -pond_size_z * 0.12, 0.0)


## Where it goes when it is put up: the far bank, by the dead tree.
func refuge_spot() -> Vector4:
	return Vector4(-pond_size_x * 0.38, 0.08, pond_size_z * 0.3, 0.2)


## A flat round of radius [param r], [param thick] high and [param deep] in W, stretched along
## z by [param oval]: a cubinder of [param segments] sides, so it is a circle in every slice.
func _disc(part: String, at: Vector4, r: float, thick: float, deep: float, colour: Color, oval: float = 1.0, segments: int = 32) -> void:
	var key: String = "disc%.3f,%.3f,%.3f,%d" % [r, thick, deep, segments]
	if not _arrays.has(key):
		var shape := CubinderShape4D.new()
		shape.radius = r
		shape.height = thick
		shape.thickness = deep
		_arrays[key] = shape.to_tetra_mesh({"segments": segments}).to_array_tetra_mesh()
	var squash: Projection = Basis4D.from_scale(Vector4(1.0, 1.0, oval, 1.0))
	if merge_parts:
		_merge(colour, _arrays[key], at, squash)
		return
	var node := MeshInstance4D.new()
	node.name = part
	node.mesh = _arrays[key]
	node.material_override = _material(colour)
	add_child(node, true)
	node.position = at
	node.basis = squash


func _box(part: String, at: Vector4, size: Vector4, colour: Color, basis: Projection = Projection.IDENTITY) -> void:
	if merge_parts:
		_batch(part, at, size, colour, basis)
		return
	var key: String = "%.3f,%.3f,%.3f,%.3f" % [size.x, size.y, size.z, size.w]
	if not _meshes.has(key):
		var mesh := BoxTetraMesh4D.new()
		mesh.size = size
		_meshes[key] = mesh
	var node := MeshInstance4D.new()
	node.name = part
	node.mesh = _meshes[key]
	node.material_override = _material(colour)
	add_child(node, true)
	node.position = at
	if basis != Projection.IDENTITY:
		node.basis = basis

func _material(colour: Color) -> TetraMaterial4D:
	var ckey: String = colour.to_html()
	if not _materials.has(ckey):
		var m := TetraMaterial4D.new()
		m.albedo_color = colour
		_materials[ckey] = m
	return _materials[ckey]


## Into this colour's merged mesh, or a node of its own when merging is off.
func _batch(_part: String, at: Vector4, size: Vector4, colour: Color, basis: Projection) -> MeshInstance4D:
	var skey: String = "%.3f,%.3f,%.3f,%.3f" % [size.x, size.y, size.z, size.w]
	if not _arrays.has(skey):
		var box := BoxTetraMesh4D.new()
		box.size = size
		_arrays[skey] = box.to_array_tetra_mesh()
	_merge(colour, _arrays[skey], at, basis)
	return null


func _merge(colour: Color, mesh: ArrayTetraMesh4D, at: Vector4, basis: Projection) -> void:
	var key: String = colour.to_html()
	if not _batches.has(key):
		_batches[key] = [ArrayTetraMesh4D.new(), colour]
	(_batches[key][0] as ArrayTetraMesh4D).merge_with(mesh, at, basis)


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
