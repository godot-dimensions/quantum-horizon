extends Node4D

## BOTANY LAB, round 3 (follow_up/arboretum.md section 9, step 35; Ramon, 10 Oct: "make some smaller
## pedestals with different flower types"): the flower border down the hall's right side, eight small
## planters at knee height along the path to the flower room's door, each with three flowers of one
## species, true 4D lofts (flora/flower_4d.gd), its name printed round the planter's side. A handful
## of butterflies (flora/butterflies_4d.gd) visit them.
##
## Walk along it and a right drag turns every flower in the border through W about its own stem, as in
## the flower room (the pedestals' turn: the floor only); the planters never move. R levels them.
##
## Positions are this node's children's (x, z); it is put at the hall's origin.
## NO class_name (engine_gotchas.md).

const Pedestal := preload("res://ramon/Arboretum/botany_lab/carried/kit/kit_pedestal.gd")
const LabPrint := preload("res://ramon/Arboretum/botany_lab/carried/LabKit/lab_print.gd")
const Ground := preload("res://ramon/Arboretum/botany_lab/carried/LabKit/carried/chickenpen/scripts/ground_basis_4d.gd")
const Flower := preload("res://ramon/Arboretum/botany_lab/flora/flower_4d.gd")
const Species := preload("res://ramon/Arboretum/botany_lab/flora/flora_species.gd")
const Butterflies := preload("res://ramon/Arboretum/botany_lab/flora/butterflies_4d.gd")

## The species, in walking order from the entrance.
@export var keys: PackedStringArray = PackedStringArray(["tulip", "poppy", "iris", "daisy", "lily", "allium", "rose", "foxglove"])
## Where the planters stand (x, z), and how big they are.
@export var at: Vector2 = Vector2(6.9, 12.4)
@export var step: Vector2 = Vector2(0.0, -2.0)
@export var radius: float = 0.5
@export var height: float = 0.42
## How far the planter's label faces round from +Z toward +X (radians): toward the path.
@export var label_angle: float = -PI * 0.5
@export var butterflies: int = 6
## How near (m) you must be for a right drag to turn the border.
@export var reach: float = 2.4

var planters: Array = []
var turn_basis: Projection = Projection.IDENTITY
var _applied: Projection = Projection.IDENTITY
var _flies: Node4D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 707
	var mat: TetraMaterial4D = Flower.material()
	for i in keys.size():
		var key: String = keys[i]
		var p := Node4D.new()
		p.name = "Border_%s" % key
		p.position = Vector4(at.x + step.x * float(i), 0.0, at.y + step.y * float(i), 0.0)
		add_child(p)
		var parts: Dictionary = Pedestal.build(p, radius, height, "planter")
		var deck: float = float(parts.get("deck_h", height))
		var plants: Array = []
		var disp: float = float(Species.DISPLAY.get(key, 1.4)) * 1.15
		for k in 4:
			var mesh: ArrayTetraMesh4D = Flower.mesh(key, k % Flower.VARIANTS)
			if mesh == null:
				continue
			var ang: float = TAU * float(k) / 4.0 + _rng.randf_range(-0.3, 0.3)
			var off := Vector4(cos(ang) * radius * 0.45, deck, sin(ang) * radius * 0.45, 0.0)
			# Each faces the path a little differently.
			var base: Projection = Basis4D.from_zx(-PI * 0.5 + _rng.randf_range(-0.6, 0.6))
			var s: float = disp * _rng.randf_range(0.92, 1.06)
			var mi := MeshInstance4D.new()
			mi.name = "%s_%d" % [key, k]
			mi.mesh = mesh
			mi.material_override = mat
			mi.position = off
			mi.basis = _scaled(base, s)
			p.add_child(mi)
			plants.append([mi, base, s])
		planters.append({"key": key, "node": p, "parts": parts, "plants": plants})
	_print_labels.call_deferred()
	if butterflies > 0:
		_flies = Node4D.new()
		_flies.name = "BorderButterflies"
		_flies.set_script(Butterflies)
		_flies.set("count", butterflies)
		_flies.set("size", 1.5)
		var lo := Vector2(minf(at.x, at.x + step.x * float(keys.size() - 1)), minf(at.y, at.y + step.y * float(keys.size() - 1)))
		var hi := Vector2(maxf(at.x, at.x + step.x * float(keys.size() - 1)), maxf(at.y, at.y + step.y * float(keys.size() - 1)))
		_flies.set("bounds_lo", Vector3(lo.x - 2.0, 0.5, lo.y - 1.0))
		_flies.set("bounds_hi", Vector3(hi.x + 1.5, 3.2, hi.y + 1.0))
		_flies.set("perch_source", perch_points)
		add_child(_flies)


static func _scaled(b: Projection, s: float) -> Projection:
	return Projection(b.x * s, b.y * s, b.z * s, b.w * s)


func _print_labels() -> void:
	await get_tree().process_frame
	for pl in planters:
		var sp: Dictionary = Species.by_key(pl["key"])
		var parts: Dictionary = pl["parts"]
		var y0: float = float(parts.get("body_y", 0.2)) - 0.1
		Pedestal.print_band(get_tree(), parts, 1.1, y0, y0 + 0.2, func(c: Control) -> void: _label(c, sp), 360.0, label_angle)


func _label(c: Control, sp: Dictionary) -> void:
	var sz: Vector2 = c.size
	var u: float = sz.y / 72.0
	c.draw_string(LabPrint.font("bold"), Vector2(0.0, 34.0 * u), String(sp.get("name", "")).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, sz.x, int(26 * u), Color(0.16, 0.18, 0.2, 0.95))
	c.draw_string(LabPrint.font("body"), Vector2(0.0, 62.0 * u), String(sp.get("latin", "")), HORIZONTAL_ALIGNMENT_CENTER, sz.x, int(19 * u), Color(0.2, 0.22, 0.25, 0.8))


func _process(_delta: float) -> void:
	if turn_basis != _applied:
		_applied = turn_basis
		for pl in planters:
			for pt in pl["plants"]:
				(pt[0] as MeshInstance4D).basis = _scaled((pt[1] as Projection) * turn_basis, pt[2])
		if _flies != null:
			_flies.call("refresh_perches")


## The planter nearest `p` (world) within `reach`, or {}.
func nearest(p: Vector4) -> Dictionary:
	var best: Dictionary = {}
	var bd: float = reach
	for pl in planters:
		var q: Vector4 = (pl["node"] as Node4D).global_position
		var d: float = Vector2(p.x - q.x, p.z - q.z).length()
		if d < bd:
			bd = d
			best = pl
	return best


func turn_by(dx: float, dy: float) -> void:
	turn_basis = Ground.cleaned(Ground.sliced(turn_basis, Vector2(dx, dy)))


func level() -> void:
	turn_basis = Projection.IDENTITY


func perch_points() -> PackedVector4Array:
	var out := PackedVector4Array()
	for pl in planters:
		var n: Node4D = pl["node"]
		for pt in pl["plants"]:
			var mi: MeshInstance4D = pt[0]
			for q in (mi.mesh as Resource).get_meta("perches", PackedVector4Array()):
				out.append(n.global_position + mi.position + mi.basis * (q as Vector4))
	return out
