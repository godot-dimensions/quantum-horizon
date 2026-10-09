extends RefCounted

## The creature hall's pedestals (Creation Lab v2, 9 Oct 2026; Ramon: "square pedestals, circular pedestals,
## small, low pedestals, larger platforms for animals requiring more movement space ... avoid making the space
## feel like a rigid grid of identical museum stands"). One look for all of them, the lab's own
## (kit/kit_pedestal.gd: a dark foot, a metal body, a dark band, a white lip, the blue deck set in), in any
## size and height and either shape:
##
##   round   the lab's pedestal itself, its trims sized with it; its collision three boxes that follow
##           the circle (the physics has only boxes along the axes; the lab's one box stood 1.6 m proud of
##           the drum at the diagonals, Ramon: "feels strange and unexpectedly rounded")
##   square  the same layers as boxes; its collision the box it is
##
## build() returns the pedestal's node (placed by the caller) and the height an animal stands at.
##
## NO class_name (engine_gotchas.md).

const Build := preload("res://ramon/CreationLab/scripts/chamber_build.gd")
const Mats := preload("res://ramon/CreationLab/LabKit/lab_materials.gd")
const LabGrid := preload("res://ramon/CreationLab/LabKit/lab_grid.gd")
const Style := preload("res://ramon/CreationLab/kit/kit_style.gd")
const KitPedestal := preload("res://ramon/CreationLab/kit/kit_pedestal.gd")


## A pedestal under `parent` at `at` (x, z, on the floor): `shape` "round" (`size.x` its radius) or "square"
## (`size` its width and depth), `h` tall. Returns {"node", "deck_h", "shape", "size"}.
static func build(parent: Node4D, nm: String, at: Vector2, shape: String, size: Vector2, h: float) -> Dictionary:
	var root := Node4D.new()
	root.name = nm
	root.position = Vector4(at.x, 0.0, at.y, 0.0)
	parent.add_child(root)
	# Trims in proportion with the pedestal: the lab's are for a 3.4 m radius and a 0.9 m height.
	var k: float = clampf(minf(h / 0.9, maxf(size.x, size.y) / 3.4 * 1.6), 0.25, 1.0)
	var deck_h: float
	if shape == "round":
		var parts: Dictionary = KitPedestal.build(root, size.x, h, k)
		deck_h = float(parts["deck_h"])
		_round_solid(root, size.x, h)
		# The lab's drums are cubinders 4 m deep in W (Build._cubinder: half of W_DEPTH), the square
		# pedestals and everything else 8: twice as deep in W, so the copies through W (w_population_4d.gd,
		# up to 3 m ana and kata) stand on the deck and not on air. W only: no slice shows the stretch.
		for c in root.get_children():
			if c is MeshInstance4D and String(c.name).begins_with("Pedestal"):
				var b: Projection = (c as MeshInstance4D).basis
				(c as MeshInstance4D).basis = Projection(b.x, b.y, b.z, b.w * 2.0)
	else:
		deck_h = _square(root, size, h, k)
	return {"node": root, "deck_h": deck_h, "shape": shape, "size": size}


## The lab pedestal's one box swapped for three that follow its circle: a square inside it and two bars.
static func _round_solid(root: Node4D, r: float, h: float) -> void:
	for c in root.get_children():
		if c.name == "PedestalSolid":
			root.remove_child(c)
			c.free()
	var solid := StaticBody4D.new()
	solid.name = "PedestalSolid"
	solid.position = Vector4(0, h * 0.5, 0, 0)
	var rr: float = r + 0.04
	for s in [Vector2(rr * 1.42, rr * 1.42), Vector2(rr * 2.0, rr * 0.83), Vector2(rr * 0.83, rr * 2.0)]:
		var cs := CollisionShape4D.new()
		var b := BoxShape4D.new()
		b.size = Vector4(s.x, h, s.y, Build.W_DEPTH)
		cs.shape = b
		solid.add_child(cs)
	solid.set_meta(Build.GENERATED, true)
	root.add_child(solid)


## The square pedestal, the lab's layers as boxes. Returns the height an animal stands at.
static func _square(root: Node4D, size: Vector2, h: float, k: float) -> float:
	var foot: float = KitPedestal.FOOT * k
	var band: float = KitPedestal.BAND * k
	var lip: float = KitPedestal.LIP * k
	var body_top: float = h - lip - band
	var ph: float = maxf(body_top - foot, 0.02)
	var dark: Color = Style.pick(Style.PLINTH) * 0.7
	dark.a = 1.0
	_slab(root, "PedestalFoot", size - Vector2(0.26, 0.26) * k, foot, foot * 0.5, Mats.flat(dark))
	var body := _slab(root, "PedestalBody", size - Vector2(0.08, 0.08) * k, ph, foot + ph * 0.5, null)
	body.material_override = LabGrid.material("kit_metal", Vector4(size.x - 0.08 * k, ph, size.y - 0.08 * k, Build.W_DEPTH),
		root.global_position if root.is_inside_tree() else Vector4.ZERO)
	_slab(root, "PedestalBand", size - Vector2(0.22, 0.22) * k, band, body_top + band * 0.5, Mats.flat(dark))
	_slab(root, "PedestalLip", size, lip, h - lip * 0.5, Mats.flat(Style.lip()))
	var inset: float = KitPedestal.DECK_IN * k
	_slab(root, "PedestalDeck", size - Vector2(inset, inset) * 2.0, 0.02 * k, h + 0.004 * k, Mats.flat(Style.pick(Style.DECK)))
	var solid := StaticBody4D.new()
	solid.name = "PedestalSolid"
	solid.position = Vector4(0, h * 0.5, 0, 0)
	var cs := CollisionShape4D.new()
	var b := BoxShape4D.new()
	b.size = Vector4(size.x, h, size.y, Build.W_DEPTH)
	cs.shape = b
	solid.add_child(cs)
	solid.set_meta(Build.GENERATED, true)
	root.add_child(solid)
	return h + 0.014 * k


static func _slab(root: Node4D, nm: String, size: Vector2, h: float, y: float, mat: Material4D) -> MeshInstance4D:
	var m := MeshInstance4D.new()
	m.name = nm
	m.mesh = Mats.box_mesh(Vector4(maxf(size.x, 0.02), maxf(h, 0.005), maxf(size.y, 0.02), Build.W_DEPTH))
	m.position = Vector4(0, y, 0, 0)
	if mat != null:
		m.material_override = mat
	m.set_meta(Build.GENERATED, true)
	root.add_child(m)
	return m
