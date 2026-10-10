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
## ROUND 3 (10 Oct, Ramon's items 29, 36, 37):
##   style "natural"    the deck green, for grass (the animals "walking on small patches of natural ground
##                      rather than blue technological platforms")
##   style "technical"  Azathoth's: a near-black base on the grid lines, the deck blue, the hologram wider
##   style "plain"      the lab's blue deck, as before
##   holo               a hologram standing on the deck (room 1's showcase's: the grid shader's hologram mode),
##                      {"height", "base", "falloff", "grow"}; empty for none. As deep in W as the pedestal, so
##                      the copies through W stand in it too
##
## NO class_name (engine_gotchas.md).

const Build := preload("res://ramon/CreationLab/scripts/chamber_build.gd")
const Mats := preload("res://ramon/CreationLab/LabKit/lab_materials.gd")
const LabGrid := preload("res://ramon/CreationLab/LabKit/lab_grid.gd")
const Style := preload("res://ramon/CreationLab/kit/kit_style.gd")
const KitPedestal := preload("res://ramon/CreationLab/kit/kit_pedestal.gd")

## The natural decks' green, a dark earth green the grass's roots sit on (the pen grass's ground colour).
const GREEN := Color(0.15, 0.24, 0.10)
## The hologram's blue (room 1's showcase).
const HOLO_COLOR := Color(0.25, 0.60, 1.0)


## A pedestal under `parent` at `at` (x, z, on the floor): `shape` "round" (`size.x` its radius) or "square"
## (`size` its width and depth), `h` tall, in `style`, with a hologram if `holo` says how. Returns {"node",
## "deck_h", "shape", "size", "deck" (the deck's top: radius, or half width and depth), "k", "holo"}.
static func build(parent: Node4D, nm: String, at: Vector2, shape: String, size: Vector2, h: float, style: String = "plain",
		holo: Dictionary = {}) -> Dictionary:
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
		deck_h = _square(root, size, h, k, style)
	var inset: float = KitPedestal.DECK_IN * k
	var deck: Vector2 = Vector2(size.x - inset, size.x - inset) if shape == "round" else size * 0.5 - Vector2(inset, inset)
	_style(root, style)
	var hm: MeshInstance4D = null
	if not holo.is_empty():
		hm = _hologram(root, shape, deck, deck_h, holo)
	return {"node": root, "deck_h": deck_h, "shape": shape, "size": size, "deck": deck, "k": k, "holo": hm}


## The deck green (natural) or the base dark on the grid lines (technical); plain leaves the lab's look.
static func _style(root: Node4D, style: String) -> void:
	if style == "natural":
		var d: MeshInstance4D = root.get_node_or_null("PedestalDeck") as MeshInstance4D
		if d != null:
			d.material_override = Mats.flat(GREEN)
	elif style == "technical":
		# Its own swatch, near black with blue-grey lines, the same in both modes: a research specimen's stand.
		LabGrid.set_swatch("hall_tech", Color(0.03, 0.034, 0.042), Color(0.17, 0.25, 0.38), Color(0.08, 0.11, 0.16), 1.0)
		for nm in ["PedestalFoot", "PedestalBand", "PedestalBody"]:
			var m: MeshInstance4D = root.get_node_or_null(nm) as MeshInstance4D
			if m == null:
				continue
			var sz := Vector4(4.0, 1.0, 4.0, Build.W_DEPTH)
			m.material_override = LabGrid.material("hall_tech", sz, root.global_position if root.is_inside_tree() else Vector4.ZERO)


## The hologram on the deck: as wide as the deck (or `grow` metres wider all round), `height` tall, thickest at
## its foot (`base`) and thinning upward (`falloff`). Round as a cubinder stretched to the pedestal's W depth.
static func _hologram(root: Node4D, shape: String, deck: Vector2, deck_h: float, holo: Dictionary) -> MeshInstance4D:
	var hh: float = float(holo.get("height", 0.65))
	var grow: float = float(holo.get("grow", 0.0))
	var m := MeshInstance4D.new()
	m.name = "Hologram"
	var sz: Vector4
	if shape == "round":
		var r: float = deck.x + grow
		m.mesh = Build._cubinder(r, hh, 96)
		m.basis = Projection(Vector4(1, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 2))
		sz = Vector4(r * 2.0, hh, r * 2.0, Build.W_DEPTH)
	else:
		var hx: float = deck.x + grow
		var hz: float = deck.y + grow
		sz = Vector4(hx * 2.0, hh, hz * 2.0, Build.W_DEPTH)
		m.mesh = Mats.box_mesh(sz)
	m.position = Vector4(0.0, deck_h + hh * 0.5, 0.0, 0.0)
	m.material_override = LabGrid.material("kit_code_blue", sz, root.global_position if root.is_inside_tree() else Vector4.ZERO)
	var cs: ShaderMaterial = (m.material_override as TetraMaterial4D).get_cross_section_material_3d()
	cs.set_shader_parameter("holo_on", 1.0)
	cs.set_shader_parameter("holo_base", float(holo.get("base", 0.55)))
	cs.set_shader_parameter("holo_falloff", float(holo.get("falloff", 1.6)))
	cs.set_shader_parameter("holo_color", HOLO_COLOR)
	cs.set_shader_parameter("holo_glow", float(holo.get("glow", 0.6)))
	cs.set_shader_parameter("holo_fine", 1.0)
	m.set_meta(Build.GENERATED, true)
	root.add_child(m)
	return m


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
static func _square(root: Node4D, size: Vector2, h: float, k: float, _style_name: String = "plain") -> float:
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
