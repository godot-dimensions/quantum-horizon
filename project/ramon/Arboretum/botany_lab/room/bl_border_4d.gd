extends Node4D

## BOTANY LAB, round 3 (follow_up/arboretum.md section 9, step 35; Ramon, 10 Oct: "make some smaller
## pedestals with different flower types"): small planters of true 4D lofted flowers (flora/flower_4d.gd),
## each species' name printed round its planter's side, a handful of butterflies (flora/butterflies_4d.gd)
## visiting them. Round 4 had eight down the hall's right side in two rows of four.
##
## ROUND 5 (section 11; Ramon: "relocate the flowers into the corner near 01, Voxels ... Arrange them in a
## compact 4 x 4 grid ... almost like a collection of small potted plants. Keep enough separation to identify
## and interact with individual specimens"): sixteen small pots, one plant each and every one a different
## species, in a grid `step` metres apart (aisles you can walk), tall plants at the back by the walls and
## short ones at the front where the path comes in.
##
## THE W SLICE IS REAL (31: "They appear to rotate or spin around a cylindrical axis rather than actually
## being sliced through four-dimensional geometry ... Ensure the flowers progressively reveal, change, and
## disappear as their geometry intersects the current W-slice"). Their turn had been the floor-only slice
## turn (x-W and z-W), which never tips a stem: a flower round about its stem in x, z and W then only seems
## to spin, and its cut hardly changes. Now, near the collection:
##   SLIDE  a right drag forward and back (or the wheel) moves every flower through W, `slide_w` metres
##          off your slice. A stem is a few millimetres deep in W and goes first, then the ring's petals,
##          and then only the W pair's petals are cut, as they reach out through W, before it all goes.
##   TIP    a right drag sideways leans every flower over into W about its foot (the y-W plane), so the
##          slice loses the head first and then the stem from the top down.
## The pots never move. R puts the flowers back upright in the slice.
##
## ROUND 6 (section 12; Ramon: "Instead of the previously requested 4x4 cluster in the corner, arrange the flowers in
## two rows of eight ... on the right side of the path ... Start the arrangement at the same longitudinal position
## where the first voxel tree platform begins ... Orient the flowers and their presentation labels toward the opposite
## viewing side ... Keep the two rows reasonably close together"): two rows down the right of the spine, the first pots
## level with the start of 01's platform (z 9.1), the short plants in the row by the path and the tall ones behind,
## all of them and their labels facing the path (-x).
##
## Positions are this node's children's (x, z); it is put at the hall's origin.
## NO class_name (engine_gotchas.md).

const Pedestal := preload("res://ramon/Arboretum/botany_lab/carried/kit/kit_pedestal.gd")
const LabPrint := preload("res://ramon/Arboretum/botany_lab/carried/LabKit/lab_print.gd")
const Flower := preload("res://ramon/Arboretum/botany_lab/flora/flower_4d.gd")
const Species := preload("res://ramon/Arboretum/botany_lab/flora/flora_species.gd")
const Butterflies := preload("res://ramon/Arboretum/botany_lab/flora/butterflies_4d.gd")

## The sixteen: the row by the path first (the short plants), from the entrance end down the hall, then the row
## behind it (the tall ones); the colours mixed.
@export var keys: PackedStringArray = PackedStringArray(["marigold", "snowdrop", "cornflower", "tulip", "dandelion", "bluebell", "daisy", "lavender",
	"poppy", "foxglove", "iris", "sunflower", "rose", "allium", "lily", "passionflower"])
## The first pot's middle (x, z), the step from pot to pot along a row and from row to row, and how many to a row.
## (Round 6: the first row 1.7 m right of the spine, its first pot's edge level with 01's platform's start, z 9.1;
## the second row a metre behind it; 0.94 m from pot to pot.)
@export var at: Vector2 = Vector2(1.7, 8.78)
@export var col_step: Vector2 = Vector2(0.0, -0.935)
@export var row_step: Vector2 = Vector2(1.0, 0.0)
@export var per_row: int = 8
@export var radius: float = 0.32
## The earth's radius in each pot (Ramon, mid round 5: "for the potted plants, make the earth radius a bit
## bigger"): the kit's planter sets its soil 0.12 m in from the body, right for the big pedestals but a thick
## stone band on a small pot; here it is widened to this.
@export var soil_radius: float = 0.27
@export var height: float = 0.5
## How much bigger than its species' own display size a plant is shown in its pot (its stem cut down:
## flower_4d.gd potted_mesh).
@export var display: float = 1.9
## How far the planter's label faces round from +Z toward +X (radians): toward the path (-x).
@export var label_angle: float = -PI * 0.5
@export var butterflies: int = 5
## How near (m) you must be to the collection's footprint for a drag or the wheel to move its flowers.
@export var reach: float = 1.6
## How near a pot you must be for it to be the one you are at (its caption).
@export var pot_reach: float = 0.95
## How far the slide and the tip go.
@export var slide_limit: float = 0.12
@export var tip_limit: float = 0.9

var planters: Array = []
var slide_w: float = 0.0
var tip: float = 0.0
var _applied := Vector2(INF, INF)
var _flies: Node4D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 707
	var mat: TetraMaterial4D = Flower.material()
	for i in keys.size():
		var key: String = keys[i]
		var p := Node4D.new()
		p.name = "Pot_%s" % key
		var xz: Vector2 = pot_at(i)
		p.position = Vector4(xz.x, 0.0, xz.y, 0.0)
		add_child(p)
		var parts: Dictionary = Pedestal.build(p, radius, height, "planter")
		# The wider earth: the planter's soil disc (radius - 0.12) scaled out across x and z.
		var soil: Node4D = parts.get("deck") as Node4D
		if soil != null and radius > 0.13:
			var k: float = soil_radius / (radius - 0.12)
			soil.basis = Projection(Vector4(k, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, k, 0), Vector4(0, 0, 0, 1))
		var deck: float = float(parts.get("deck_h", height))
		var plants: Array = []
		var mesh: ArrayTetraMesh4D = Flower.potted_mesh(key, i % Flower.VARIANTS)
		if mesh != null:
			# Its front toward the path (-x), a little differently each.
			var base: Projection = Basis4D.from_zx(-PI * 0.5 + _rng.randf_range(-0.5, 0.5))
			var s: float = float(Species.DISPLAY.get(key, 1.4)) * display * _rng.randf_range(0.95, 1.05)
			var mi := MeshInstance4D.new()
			mi.name = key
			mi.mesh = mesh
			mi.material_override = mat
			mi.position = Vector4(0.0, deck, 0.0, 0.0)
			mi.basis = _scaled(base, s)
			p.add_child(mi)
			plants.append([mi, base, s, mi.position])
		planters.append({"key": key, "node": p, "parts": parts, "plants": plants})
	_print_labels.call_deferred()
	if butterflies > 0:
		var lo: Vector2 = footprint_lo()
		var hi: Vector2 = footprint_hi()
		_flies = Node4D.new()
		_flies.name = "CollectionButterflies"
		_flies.set_script(Butterflies)
		_flies.set("count", butterflies)
		_flies.set("size", 1.5)
		_flies.set("bounds_lo", Vector3(lo.x, 0.6, lo.y))
		_flies.set("bounds_hi", Vector3(hi.x, 2.8, hi.y))
		_flies.set("perch_source", perch_points)
		add_child(_flies)


static func _scaled(b: Projection, s: float) -> Projection:
	return Projection(b.x * s, b.y * s, b.z * s, b.w * s)


## Pot `i`'s middle (x, z).
func pot_at(i: int) -> Vector2:
	var row: int = i / maxi(per_row, 1)
	var col: int = i % maxi(per_row, 1)
	return at + col_step * float(col) + row_step * float(row)


## The collection's footprint (x, z), pots' edges included.
func footprint_lo() -> Vector2:
	var lo := Vector2(INF, INF)
	for i in keys.size():
		var q: Vector2 = pot_at(i)
		lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
	return lo - Vector2.ONE * radius


func footprint_hi() -> Vector2:
	var hi := Vector2(-INF, -INF)
	for i in keys.size():
		var q: Vector2 = pot_at(i)
		hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
	return hi + Vector2.ONE * radius


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
	var now := Vector2(slide_w, tip)
	if now == _applied:
		return
	_applied = now
	var lean: Projection = Basis4D.from_wy(tip)
	for pl in planters:
		for pt in pl["plants"]:
			var mi: MeshInstance4D = pt[0]
			mi.basis = _scaled((pt[1] as Projection) * lean, pt[2])
			mi.position = (pt[3] as Vector4) + Vector4(0.0, 0.0, 0.0, slide_w)
	if _flies != null:
		_flies.call("refresh_perches")


## Whether `p` (world) is by the collection: within `reach` of its footprint.
func near(p: Vector4) -> bool:
	var lo: Vector2 = footprint_lo() - Vector2.ONE * reach
	var hi: Vector2 = footprint_hi() + Vector2.ONE * reach
	return p.x > lo.x and p.x < hi.x and p.z > lo.y and p.z < hi.y


## How far `p` (world) is from the collection's footprint, metres (0 inside it).
func footprint_distance(p: Vector4) -> float:
	var lo: Vector2 = footprint_lo()
	var hi: Vector2 = footprint_hi()
	var dx: float = maxf(maxf(lo.x - p.x, p.x - hi.x), 0.0)
	var dz: float = maxf(maxf(lo.y - p.z, p.z - hi.y), 0.0)
	return Vector2(dx, dz).length()


## The pot nearest `p` (world) within `pot_reach` of its rim, or {}; only while by the collection.
func nearest(p: Vector4) -> Dictionary:
	if not near(p):
		return {}
	var best: Dictionary = {}
	var bd: float = pot_reach + radius
	for pl in planters:
		var q: Vector4 = (pl["node"] as Node4D).global_position
		var d: float = Vector2(p.x - q.x, p.z - q.z).length()
		if d < bd:
			bd = d
			best = pl
	return best


## A right drag: sideways tips them through W, forward and back slides them (the mouse pushed away slides
## them ana, +W).
func turn_by(dx: float, dy: float) -> void:
	tip = clampf(tip + dx * 0.7, -tip_limit, tip_limit)
	slide_w = clampf(slide_w - dy * 0.05, -slide_limit, slide_limit)


## The wheel: a step through W.
func slide_by(d: float) -> void:
	slide_w = clampf(slide_w + d, -slide_limit, slide_limit)


func level() -> void:
	slide_w = 0.0
	tip = 0.0


func moved() -> bool:
	return absf(slide_w) > 0.0005 or absf(tip) > 0.005


func perch_points() -> PackedVector4Array:
	var out := PackedVector4Array()
	for pl in planters:
		var n: Node4D = pl["node"]
		for pt in pl["plants"]:
			var mi: MeshInstance4D = pt[0]
			for q in (mi.mesh as Resource).get_meta("perches", PackedVector4Array()):
				out.append(n.global_position + mi.position + mi.basis * (q as Vector4))
	return out
