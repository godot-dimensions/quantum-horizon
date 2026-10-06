@tool
extends Node4D

## A pile of the rock kit's boulders (terrain/pen_boulder_4d.gd, baked to terrain/baked/boulder_<n>.res;
## 6 Oct 2026, PenLayout/PLAN_WATCHSTONE.md): the Watchstone's crag and the range's outcrop are each
## one of these, a list of boulders laid where they go.
##
## Each entry of [member rocks] is [variant, position, size, turn, tilt]: the boulder's variant (0
## to 5), its middle (in this node's frame), how big it is along x, y, z and W (the unit boulder is
## about a metre each way from its middle, so a size of 2 is about four metres across), how far it
## is turned about the up axis (radians), and optionally a tilt, Vector2 (about z, about x), so a
## pile does not stand dead straight. Physics here is boxes that do not turn, so each boulder is
## solid as a box a little inside its outline (set [member solid] false to draw it only).

const TerrainBake := preload("res://ramon/chickenpen/terrain/terrain_bake_4d.gd")
const Boulder := preload("res://ramon/chickenpen/terrain/pen_boulder_4d.gd")
const BAKED := "res://ramon/chickenpen/terrain/baked/boulder_%d.res"

@export var rocks: Array = []: set = _set_rocks
@export var tint: Color = Color.WHITE: set = _set_tint
@export var solid: bool = true
## How much of a boulder's outline its box fills (a boulder is rounder than its box).
@export_range(0.4, 1.0, 0.01) var solid_fill: float = 0.82

const OWN := &"_boulder_pile_part"

var _pending: bool = false


func _set_rocks(v: Array) -> void:
	rocks = v
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


func rebuild() -> void:
	_pending = false
	for c in get_children():
		if c.has_meta(OWN):
			remove_child(c)
			c.queue_free()
	var material: TetraMaterial4D = TerrainBake.material(tint)
	var meshes: Dictionary = {}
	var body: StaticBody4D = null
	if solid and not Engine.is_editor_hint():
		body = StaticBody4D.new()
		body.name = "Solid"
		_own(body)
	var i: int = 0
	for r in rocks:
		var variant: int = clampi(int(r[0]), 0, Boulder.VARIANTS.size() - 1)
		if not meshes.has(variant):
			meshes[variant] = load(BAKED % variant) if ResourceLoader.exists(BAKED % variant) else null
			# Flat-shaded, each chiselled face one cut, whether or not the file kept it.
			if meshes[variant] is ArrayTetraMesh4D:
				(meshes[variant] as ArrayTetraMesh4D).set_flat_shading_normals(true)
		if meshes[variant] == null:
			continue
		var at: Vector4 = r[1]
		var size: Vector4 = r[2]
		var turn: float = float(r[3]) if r.size() > 3 else 0.0
		var tilt: Vector2 = r[4] if r.size() > 4 else Vector2.ZERO
		var mi := MeshInstance4D.new()
		mi.name = "Boulder%d" % i
		mi.mesh = meshes[variant]
		mi.material_override = material
		mi.position = at
		mi.basis = Basis4D.from_xy(tilt.x) * Basis4D.from_yz(tilt.y) * Basis4D.from_zx(turn) * Projection(Vector4(size.x, 0, 0, 0), Vector4(0, size.y, 0, 0), Vector4(0, 0, size.z, 0), Vector4(0, 0, 0, size.w))
		_own(mi)
		if body != null:
			var half: Vector4 = (Boulder.VARIANTS[variant]["half"] as Vector4) * size * solid_fill
			# A turned boulder's box: as wide as it reaches in x and z either way.
			var c: float = absf(cos(turn))
			var s: float = absf(sin(turn))
			var holder := CollisionShape4D.new()
			var shape := BoxShape4D.new()
			shape.size = Vector4(half.x * c + half.z * s, half.y, half.x * s + half.z * c, half.w) * 2.0
			holder.shape = shape
			holder.position = at
			body.add_child(holder)
		i += 1


func _own(node: Node) -> void:
	node.set_meta(OWN, true)
	add_child(node)
