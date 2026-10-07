@tool
extends Node4D

## A tree, lofted: a trunk and its limbs as chains of balls (loft_rig_4d.gd), built once and
## merged into one mesh per colour, so a whole tree is one or two nodes that never change.
## (Ramon, 2 Oct: "make the owl a tree, could be a bare dead tree of lofted shapes, so it can
## sit on a twig. Keep the loft optimised.")
##
## OPTIMISED HOW. Drawing lofted geometry is nearly free (follow_up/lofting_gotchas.md:
## ~0.15 us a tetrahedron a frame); what costs is re-lofting, and nodes. So: it is lofted
## once, at build; every limb is its own short chain at 6 or 7 sides and the fewest rings
## (3), so a tree is a few thousand tetrahedra; and the chains are merged into one
## ArrayTetraMesh4D and the rigs thrown away, so a tree costs one node, not forty.
##
## DEAD: bare, silver-grey, snapped off at the top, a few limbs reaching up and out and a twig
## or two off each. LEAFY: brown, with clumps of leaves at the ends of the limbs, for the
## chipmunks to run up.
##
## THIN IN W, like the post it replaces: the balls are squashed along W ([member w_scale]), so
## a tree out at w +1.5 is not there at all from the farm's slice. The limbs sit at slightly
## different w, so pulling focus through it brings them in one by one.
##
## A PERCH. With [member use_perch] on, one limb is grown to end in a level twig at [member
## perch] (in the tree's own space), for the owl to sit on: the trunk is not moved, the limb
## is aimed at the point.

enum Style { DEAD, LEAFY }

const RIG := preload("res://ramon/chickenpen/scripts/loft_rig_4d.gd")
const BALL := preload("res://ramon/chickenpen/scripts/loft_ball_4d.gd")

@export var style: Style = Style.DEAD:
	set(v):
		style = v
		_changed()
@export_range(3.0, 25.0, 0.1, "suffix:m") var height: float = 12.0:
	set(v):
		height = v
		_changed()
@export_range(0.1, 1.5, 0.01, "suffix:m") var trunk_radius: float = 0.4:
	set(v):
		trunk_radius = v
		_changed()
## How thick the tree is along W, against its thickness across: 1 is round all ways.
@export_range(0.2, 1.5, 0.05) var w_scale: float = 0.6:
	set(v):
		w_scale = v
		_changed()
@export_range(2, 10, 1) var limb_count: int = 5:
	set(v):
		limb_count = v
		_changed()
@export var tree_seed: int = 31:
	set(v):
		tree_seed = v
		_changed()
@export var use_perch: bool = false:
	set(v):
		use_perch = v
		_changed()
## Where the perch twig's top is, in the tree's own space.
@export var perch: Vector4 = Vector4(1.6, 10.0, 0.4, 0.0):
	set(v):
		perch = v
		_changed()
@export var bark: Color = Color(0.50, 0.49, 0.46):
	set(v):
		bark = v
		_changed()
## The leafy style's clumps of leaves, two squashed balls at each high limb's tip: off since Ramon, 7 Oct ("dont
## change the trees. just remove the leave balls"), so a leafy tree stands bare-limbed, its seats where they were.
@export var leaf_balls: bool = false:
	set(v):
		leaf_balls = v
		_changed()
@export var leaves: Color = Color(0.30, 0.42, 0.20):
	set(v):
		leaves = v
		_changed()

## Every limb as built, in the tree's own space: [{points: [Vector4], radii: [float]}],
## the trunk first. For anything that climbs it.
var limbs: Array = []
## Level places on top of the limbs, in the tree's own space: for sitting on.
var seats: Array[Vector4] = []
## Tetrahedra in the built tree.
var cells: int = 0


func _changed() -> void:
	if is_node_ready():
		rebuild()


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	for child in get_children():
		child.free()
	limbs.clear()
	seats.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = tree_seed
	var r: float = trunk_radius
	var h: float = height
	# The trunk: flared at the foot (buried a little, so it stands in the ground rather than
	# on it), leaning a touch, and narrowing to the top - a snapped spike on a dead one.
	var lean := Vector2(rng.randf_range(-0.05, 0.05), rng.randf_range(-0.05, 0.05)) * h
	var trunk_top: float = h * (0.92 if style == Style.DEAD else 0.8)
	# The loft collapses a chain's first and last sections to a point (taper_ends), so the
	# first ball is buried well under the ground: the trunk is its full width where it comes
	# out of the earth, not pinched to half of it (which left climbing chipmunks floating).
	var trunk: Array = [Vector4(0.0, -1.6, 0.0, 0.0)]
	var radii: Array = [r * 1.5]
	for k in 7:
		var f: float = float(k) / 6.0
		var y: float = lerpf(-0.4, trunk_top, f)
		var bend: float = f * f
		trunk.append(Vector4(lean.x * bend, y, lean.y * bend, 0.0))
		radii.append(r * lerpf(1.35, 0.25 if style == Style.DEAD else 0.45, pow(f, 0.8)) * (1.15 if k == 0 else 1.0))
	limbs.append({"points": trunk, "radii": radii, "sides": 6})
	# The limbs: up and out, round the trunk at the golden angle so no two line up.
	var spin: float = rng.randf() * TAU
	for i in limb_count:
		var f: float = lerpf(0.42, 0.86, float(i) / maxf(float(limb_count - 1), 1.0)) + rng.randf_range(-0.04, 0.04)
		var from: Vector4 = _on_trunk(trunk, f * trunk_top)
		spin += 2.39996
		var rise: float = rng.randf_range(0.55, 1.0) if style == Style.DEAD else rng.randf_range(0.35, 0.75)
		var length: float = h * lerpf(0.38, 0.22, f) * rng.randf_range(0.85, 1.15)
		var w: float = rng.randf_range(-0.25, 0.25) * r
		_grow(from, Vector2(cos(spin), sin(spin)), rise, length, _radius_on_trunk(radii, f) * 0.72, w, rng)
	# The perch: a limb aimed at the point, ending in a level twig there.
	if use_perch:
		var goal: Vector4 = perch - Vector4(0.0, 0.05, 0.0, 0.0)
		var from: Vector4 = _on_trunk(trunk, clampf(perch.y - 1.1, 0.5, trunk_top - 0.5))
		var out := Vector2(goal.x - from.x, goal.z - from.z)
		var bow: Vector4 = from.lerp(goal, 0.55) + Vector4(0.0, 0.45, 0.0, 0.0)
		var twig_end: Vector4 = goal + Vector4(out.normalized().x * 0.45, 0.06, out.normalized().y * 0.45, 0.0)
		limbs.append({"points": [from, bow, goal, twig_end], "radii": [r * 0.42, r * 0.28, 0.07, 0.035], "sides": 6})
		seats.append(perch)
	if style == Style.LEAFY and leaf_balls:
		_canopy(rng)
	else:
		set_meta("clumps", [])
	_build()


func _on_trunk(trunk: Array, y: float) -> Vector4:
	for k in range(1, trunk.size()):
		var a: Vector4 = trunk[k - 1]
		var b: Vector4 = trunk[k]
		if y <= b.y:
			return a.lerp(b, (y - a.y) / maxf(b.y - a.y, 0.001))
	return trunk.back()


func _radius_on_trunk(radii: Array, f: float) -> float:
	var x: float = clampf(f, 0.0, 1.0) * float(radii.size() - 1)
	var k: int = mini(int(x), radii.size() - 2)
	return lerpf(float(radii[k]), float(radii[k + 1]), x - float(k))


## A limb from [param from], heading out along [param out] and rising by [param rise] (0 level,
## 1 straight up at the end), curling upward as it goes, with a twig or two off it.
func _grow(from: Vector4, out: Vector2, rise: float, length: float, radius: float, w: float, rng: RandomNumberGenerator) -> void:
	var pts: Array = [from]
	var rad: Array = [radius]
	var dir := Vector3(out.x, rise * 0.6, out.y).normalized()
	var at: Vector4 = from
	for k in 3:
		dir = (dir + Vector3(rng.randf_range(-0.2, 0.2), 0.18 * rise + 0.08, rng.randf_range(-0.2, 0.2))).normalized()
		at += Vector4(dir.x, maxf(dir.y, 0.05), dir.z, 0.0) * (length / 3.0) + Vector4(0.0, 0.0, 0.0, w / 3.0)
		pts.append(at)
		rad.append(radius * lerpf(0.75, 0.2, float(k) / 2.0))
	limbs.append({"points": pts, "radii": rad, "sides": 5})
	# A seat on top of the limb's first third, where something could sit.
	var seat: Vector4 = (pts[0] as Vector4).lerp(pts[1], 0.7)
	seats.append(seat + Vector4(0.0, float(rad[1]) * 0.9, 0.0, 0.0))
	# Twigs off the limb, shorter and thinner, pointing up and further out.
	var twigs: int = 1
	for t in twigs:
		var base: Vector4 = (pts[1 + t] as Vector4)
		var side := Vector2(out.x, out.y).rotated(rng.randf_range(-1.0, 1.0))
		var tip: Vector4 = base + Vector4(side.x * length * 0.3, length * rng.randf_range(0.2, 0.4), side.y * length * 0.3, rng.randf_range(-0.2, 0.2) * radius)
		limbs.append({"points": [base, base.lerp(tip, 0.5) + Vector4(0.0, 0.08, 0.0, 0.0), tip],
			"radii": [float(rad[1 + t]) * 0.6, float(rad[1 + t]) * 0.35, 0.02], "sides": 4})


## Clumps of leaves round the ends of the limbs: squashed balls, deeper in W than the wood.
func _canopy(rng: RandomNumberGenerator) -> void:
	var clumps: Array = []
	for limb in limbs.slice(1):
		var tip: Vector4 = (limb["points"] as Array).back()
		if tip.y < height * 0.45:
			continue
		clumps.append([tip + Vector4(0.0, 0.3, 0.0, 0.0), rng.randf_range(1.0, 1.6) * height / 9.0])
	var top: Vector4 = (limbs[0]["points"] as Array).back()
	clumps.append([top + Vector4(0.0, 0.6, 0.0, 0.0), 1.9 * height / 9.0])
	set_meta("clumps", clumps)


func _build() -> void:
	var wood := ArrayTetraMesh4D.new()
	cells = 0
	for limb in limbs:
		var rig := _rig(int(limb["sides"]))
		var pts: Array = limb["points"]
		var rad: Array = limb["radii"]
		# The rig chains its balls lowest first; a limb that dips has to be fed its points
		# in that order or it loops back on itself, so dipping points are lifted level.
		var floor_y: float = -INF
		for k in pts.size():
			var p: Vector4 = pts[k]
			p.y = maxf(p.y, floor_y + 0.01)
			floor_y = p.y
			_ball(rig, "B%d" % k, p, float(rad[k]))
		rig.call("build", false)
		var built: ArrayTetraMesh4D = rig.mesh as ArrayTetraMesh4D
		if built != null:
			wood.merge_with(built, Vector4.ZERO, Projection.IDENTITY)
		rig.free()
	_show("Wood", wood, bark)
	if style == Style.LEAFY and has_meta("clumps") and not (get_meta("clumps") as Array).is_empty():
		var green := ArrayTetraMesh4D.new()
		var green2 := ArrayTetraMesh4D.new()
		var i: int = 0
		for clump in get_meta("clumps"):
			var c: Vector4 = clump[0]
			var size: float = clump[1]
			var rig := _rig(6)
			_ball(rig, "Low", c - Vector4(0.0, size * 0.25, 0.0, 0.0), size * 0.9, 1.6)
			_ball(rig, "High", c + Vector4(0.0, size * 0.35, 0.0, 0.0), size * 0.75, 1.6)
			rig.call("build", false)
			if rig.mesh != null:
				(green if i % 2 == 0 else green2).merge_with(rig.mesh as ArrayTetraMesh4D, Vector4.ZERO, Projection.IDENTITY)
			rig.free()
			i += 1
		_show("Leaves", green, leaves)
		_show("Leaves2", green2, leaves.lightened(0.12))


func _show(part: String, mesh: ArrayTetraMesh4D, colour: Color) -> void:
	var node := MeshInstance4D.new()
	node.name = part
	node.mesh = mesh
	var m := TetraMaterial4D.new()
	m.albedo_color = colour
	node.material_override = m
	add_child(node)
	cells += mesh.get_simplex_cell_vertex_indices().size() / 4


func _rig(sides: int) -> MeshInstance4D:
	var rig := MeshInstance4D.new()
	rig.name = "Rig"
	rig.set_script(RIG)
	add_child(rig)
	rig.set("live_rebuild", false)
	rig.set("mirror_x", false)
	rig.set("verbose", false)
	rig.set("profile_sides", sides)
	rig.set("profile_rings", 3)
	return rig


func _ball(rig: Node, part: String, at: Vector4, radius: float, w_mul: float = 1.0) -> void:
	var node := MeshInstance4D.new()
	node.name = part
	node.set_script(BALL)
	rig.add_child(node)
	node.position = at
	node.set("radius", radius)
	node.set("w_scale", w_scale * w_mul)


## A point on the trunk at [param y], in the world: for climbing it.
func trunk_at(y: float) -> Vector4:
	if limbs.is_empty():
		return global_position
	return global_position + global_basis * _on_trunk(limbs[0]["points"], y)


## The trunk's real radius at [param y]: the lofted surface runs straight between its balls,
## and the first and last are collapsed to points by the loft (taper_ends).
func trunk_radius_at(y: float) -> float:
	if limbs.is_empty():
		return trunk_radius
	var pts: Array = limbs[0]["points"]
	var rad: Array = limbs[0]["radii"]
	var last: int = pts.size() - 1
	for k in range(1, pts.size()):
		var a: Vector4 = pts[k - 1]
		var b: Vector4 = pts[k]
		if y <= b.y or k == last:
			var ra: float = 0.0 if k - 1 == 0 else float(rad[k - 1])
			var rb: float = 0.0 if k == last else float(rad[k])
			return lerpf(ra, rb, clampf((y - a.y) / maxf(b.y - a.y, 0.001), 0.0, 1.0))
	return 0.0


## Where the perch twig's top is, in the world.
func perch_point() -> Vector4:
	return global_position + global_basis * perch
