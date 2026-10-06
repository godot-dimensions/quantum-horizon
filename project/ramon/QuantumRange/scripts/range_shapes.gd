extends RefCounted

## Every mesh the range's targets are made of, built once and shared (drawing is nearly free, building
## is not: follow_up/lofting_gotchas.md). Lofted pieces come from the carried loft builder
## (carried/chicken/loft_builder_4d.gd, the pen's tool): a stack of 3D cross-sections along Y, each
## section a ball through X, Z and W, lofted into a 4D solid. A round core is a stack of sections whose
## radii rise and fall like a sphere's; a petal is the same squashed flat; a tendril joint is a short
## tapered tube. The rest are the project's primitives (res://models/primitives/).
##
## NO class_name (engine_gotchas.md): preload it.

const Loft := preload("res://ramon/QuantumRange/carried/chicken/loft_builder_4d.gd")
const Batch := preload("res://ramon/QuantumRange/carried/LabKit/lab_batch.gd")
const CHICKEN := "res://ramon/QuantumRange/carried/chicken/chicken.tscn"
## The chicken's size here against the pen's (the pen's is a quarter of its rig; this one is two thirds,
## a big comic bird that reads at fifteen metres: at half it was a white speck, play/skeet_1_play, 5 Oct).
const CHICKEN_SCALE := 0.66

const TORISPHERE := "res://models/primitives/torisphere/mesh/torisphere1_smooth_ma2_mi0pt5_step10.g4b"
const SPHERITORUS := "res://models/primitives/spheritorus/mesh/spheritorus_smooth_ma2_mi0pt25_step32.g4b"
const CELL24 := "res://models/primitives/platonic/24_cell/24_cell.g4b"
const CELL600 := "res://models/primitives/platonic/600_cell/600_cell.g4b"

static var _cache: Dictionary = {}
## Milliseconds spent building meshes so far (the metrics wall shows it).
static var build_ms: float = 0.0


static func _cached(key: String, maker: Callable) -> Mesh4D:
	if _cache.has(key):
		return _cache[key]
	var t: int = Time.get_ticks_usec()
	var m: Mesh4D = maker.call()
	build_ms += (Time.get_ticks_usec() - t) / 1000.0
	_cache[key] = m
	return m


## A section dictionary for the loft builder.
static func _sec(y: float, r: float, v: float = 1.0, w: float = 1.0, x: float = 0.0, z: float = 0.0, ww: float = 0.0, square: float = 0.0) -> Dictionary:
	return {"center": Vector4(x, y, z, ww), "radius": maxf(r, 0.0005), "v_scale": v, "w_scale": w, "squareness": square}


## A 4D ball of radius 1 (a glome-like loft): the core, the thing to hit.
static func ball(square: float = 0.0) -> Mesh4D:
	return _cached("ball%.2f" % square, func() -> Mesh4D:
		var secs: Array = []
		var n: int = 10
		for i in range(1, n):
			var th: float = PI * float(i) / float(n)
			secs.append(_sec(-cos(th), sin(th), 1.0, 1.0, 0.0, 0.0, 0.0, square))
		return Loft.build(secs, 7, 14, true, false, true, 1, false))


## A petal 1 m long along +Y from its hinge, a broad leaf thin in its v axis (Z), full in W.
static func petal() -> Mesh4D:
	return _cached("petal", func() -> Mesh4D:
		var secs: Array = []
		for i in range(0, 6):
			var t: float = float(i) / 5.0
			var r: float = 0.08 + 0.34 * sin(PI * (0.15 + t * 0.85))
			secs.append(_sec(t, r, 0.22, 0.85, 0.0, -0.06 * sin(PI * t)))
		return Loft.build(secs, 4, 10, true, false, true, 1, false))


## A tendril joint 1 m long along +Y, tapering from radius 1 to `tip` (scale it).
static func segment(tip: float = 0.7) -> Mesh4D:
	return _cached("seg%.2f" % tip, func() -> Mesh4D:
		var secs: Array = [_sec(0.0, 1.0), _sec(0.5, (1.0 + tip) * 0.5), _sec(1.0, tip)]
		return Loft.build(secs, 4, 8, true, false, true, 1, false))


## A drone's fin: a flat blade 1 m long along +Y, thin in Z.
static func fin() -> Mesh4D:
	return _cached("fin", func() -> Mesh4D:
		var secs: Array = [_sec(0.0, 0.28, 0.12, 0.5), _sec(0.5, 0.22, 0.12, 0.45), _sec(1.0, 0.06, 0.12, 0.3)]
		return Loft.build(secs, 4, 8, true, false, true, 1, false))


## A 16-cell (the cross-polytope: one vertex out along each of the eight axis directions), radius 1.
## In any slice through its middle it reads as a diamond: the cluster's satellites.
static func diamond() -> Mesh4D:
	return _cached("diamond", func() -> Mesh4D:
		var m := OrthoplexTetraMesh4D.new()
		return m)


static func box(size: Vector4) -> Mesh4D:
	return _cached("box%s" % size, func() -> Mesh4D:
		var m := BoxTetraMesh4D.new()
		m.size = size
		return m)


static func torisphere() -> Mesh4D:
	return _cached("torisphere", func() -> Mesh4D: return load(TORISPHERE))


static func spheritorus() -> Mesh4D:
	return _cached("spheritorus", func() -> Mesh4D: return load(SPHERITORUS))


static func cell24() -> Mesh4D:
	return _cached("cell24", func() -> Mesh4D: return load(CELL24))


static func cell600() -> Mesh4D:
	return _cached("cell600", func() -> Mesh4D: return load(CELL600))


## A plus of four bars, one along each axis (x, y, z and w), `l` long and `t` thick, merged into one
## mesh: in any slice through its middle it reads as a cross. The friendly's shape.
static func cross(l: float = 0.85, t: float = 0.2) -> Mesh4D:
	return _cached("cross%.2f%.2f" % [l, t], func() -> Mesh4D:
		var b := Batch.new()
		for s4 in [Vector4(l, t, t, t), Vector4(t, l, t, t), Vector4(t, t, l, t), Vector4(t, t, t, l)]:
			b.box("x", s4, Vector4.ZERO)
		return b.instance("x").mesh)


static var _chicken: Array = []


## The pen's chicken (carried/chicken/chicken.tscn, the carried copy) baked once into rigid pieces:
## [[name, mesh, material, position, is_wing], ...], positions in metres from the bird's middle at
## CHICKEN_SCALE. Its loft rigs build themselves when it enters the tree; this keeps their meshes and
## throws the rig away.
static func chicken(tree: SceneTree) -> Array:
	if not _chicken.is_empty():
		return _chicken
	var t0: int = Time.get_ticks_usec()
	var scene: Node4D = (load(CHICKEN) as PackedScene).instantiate()
	tree.root.add_child(scene)
	var mid := Vector4(0.0, 1.05, -0.2, 0.0)
	for nm in ["Body", "NeckHead", "LegL", "LegR", "Wing"]:
		var rig: MeshInstance4D = scene.get_node_or_null(nm) as MeshInstance4D
		if rig == null or rig.mesh == null:
			continue
		var pos: Vector4 = (rig.position - mid) * CHICKEN_SCALE
		_chicken.append([nm, rig.mesh, rig.material_override, pos, nm == "Wing"])
		for c in rig.get_children():
			if c is MeshInstance4D and String(c.name).begins_with("Foot"):
				var f: MeshInstance4D = c
				_chicken.append([String(c.name), f.mesh, f.material_override, (rig.position + f.position - mid) * CHICKEN_SCALE, false])
	tree.root.remove_child(scene)
	scene.queue_free()
	build_ms += (Time.get_ticks_usec() - t0) / 1000.0
	return _chicken
