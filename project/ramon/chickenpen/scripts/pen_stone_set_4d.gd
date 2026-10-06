@tool
extends Node4D

## A set of designed-cut stones (terrain/cut_stone_4d.gd), placed and merged into one mesh
## (PenLayout/PLAN_REF_LOCK.md steps 12-14). The Watchstone's crag, the range's outcrop and the
## camp's stones are each one of these.
##
## ONE MESH, NOT ONE NODE A STONE. Each stone is a baked file (terrain/baked/stones/<kind>_<n>.res);
## placing one merges a copy of it, moved, turned and scaled, into a single ArrayTetraMesh4D, so a
## crag of a hundred and fifty stones is one draw (Trym's Experiment B: one merged mesh drew 24
## times cheaper than a thousand instances). Merging keeps each stone's colours and flat normals
## (ArrayTetraMesh4D.merge_with carries the texture map and turns the normals with the inverse
## transpose, so a squashed stone still shades true).
##
## A placement: [kind, variant, position, size, yaw, tilt]. Size scales the unit stone (about a
## metre each way) per axis, x y z w; yaw turns it about the up axis; tilt (Vector2) leans it in
## x-y then y-z.
##
## Built when it loads (and in the editor); nothing generated is saved into the scene.
## NO class_name (engine_gotchas.md).

const TerrainBake := preload("res://ramon/chickenpen/terrain/terrain_bake_4d.gd")
const CutStone := preload("res://ramon/chickenpen/terrain/cut_stone_4d.gd")
const BAKED := "res://ramon/chickenpen/terrain/baked/stones/%s_%d.res"
const OWN := &"_stone_set_part"

@export var stones: Array = []: set = _set_stones
@export var tint: Color = Color.WHITE: set = _set_tint

var _pending: bool = false
static var _cache: Dictionary = {}


func _set_stones(v: Array) -> void:
	stones = v
	_later()


func _set_tint(v: Color) -> void:
	tint = v
	_later()


func _ready() -> void:
	rebuild()


func _later() -> void:
	if not is_node_ready() or _pending:
		return
	_pending = true
	rebuild.call_deferred()


## The baked stone of [param kind] and [param variant], loaded once for every set.
static func stone_mesh(kind: String, variant: int) -> ArrayTetraMesh4D:
	var key: String = "%s_%d" % [kind, variant]
	if not _cache.has(key):
		var path: String = BAKED % [kind, variant]
		_cache[key] = load(path) if ResourceLoader.exists(path) else null
	return _cache[key]


## The basis of a placement: lean, turn, then the stone's own size.
static func placement_basis(size: Vector4, yaw: float, tilt: Vector2) -> Projection:
	return Basis4D.from_xy(tilt.x) * Basis4D.from_yz(tilt.y) * Basis4D.from_zx(yaw) \
		* Projection(Vector4(size.x, 0, 0, 0), Vector4(0, size.y, 0, 0), Vector4(0, 0, size.z, 0), Vector4(0, 0, 0, size.w))


func rebuild() -> void:
	_pending = false
	for c in get_children():
		if c.has_meta(OWN):
			remove_child(c)
			c.queue_free()
	var merged := ArrayTetraMesh4D.new()
	var count: int = 0
	for s in stones:
		var mesh: ArrayTetraMesh4D = stone_mesh(String(s[0]), int(s[1]))
		if mesh == null:
			continue
		var tilt: Vector2 = s[5] if s.size() > 5 else Vector2.ZERO
		merged.merge_with(mesh, s[2], placement_basis(s[3], float(s[4]) if s.size() > 4 else 0.0, tilt))
		count += 1
	if count == 0:
		return
	var node := MeshInstance4D.new()
	node.name = "Stones"
	node.mesh = merged
	node.material_override = TerrainBake.material(tint)
	node.set_meta(OWN, true)
	add_child(node)
