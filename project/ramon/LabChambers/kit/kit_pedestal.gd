extends RefCounted

## Kit: the pedestal an exhibit stands on, after Ramon's concept frame (4 Oct: "make pedestal more
## like ref, and with the blue circle a little bit smaller, a decal text on the side of the
## pedestal would be nice too"). From the floor up:
##
##   a dark foot, set in, with a warm light line round it on the floor
##   the body: one dark metal cylinder (Ramon, 4 Oct: "remove the separately placed blocks
##     around the grey part, one cylinder shape please"), its label wrapped round its front
##   a dark band, set in under the lip, with a warm light line in it
##   the lip: a white ring, and the blue disc set into it, smaller than the lip
##
## build() makes it and returns its parts; apply_mood() recolours them; print_band() wraps a
## picture round the front of the body (the side text; lab_grid's cylinder print).
## The physics is one box (box-only physics).
##
## NO class_name (engine_gotchas.md).

const Build := preload("res://ramon/LabChambers/scripts/chamber_build.gd")
const Batch := preload("res://ramon/LabKit/lab_batch.gd")
const Mats := preload("res://ramon/LabKit/lab_materials.gd")
const LabGrid := preload("res://ramon/LabKit/lab_grid.gd")
const LabPrint := preload("res://ramon/LabKit/lab_print.gd")
const Style := preload("res://ramon/LabChambers/kit/kit_style.gd")

const FOOT := 0.09
const BAND := 0.07
const LIP := 0.13
## How far in from the edge the blue disc starts.
const DECK_IN := 0.42


## Builds the pedestal under `parent` at its origin; returns its parts, with "deck_h" the height
## an exhibit stands at.
static func build(parent: Node4D, r: float, h: float) -> Dictionary:
	var origin: Vector4 = parent.global_position if parent.is_inside_tree() else Vector4.ZERO
	var body_top: float = h - LIP - BAND
	var ph: float = body_top - FOOT
	var parts: Dictionary = {"dark": [], "glow": [], "panels": []}
	parts["dark"].append(_drum(parent, "PedestalFoot", r - 0.13, FOOT, FOOT * 0.5))
	parts["dark"].append(_drum(parent, "PedestalBand", r - 0.11, BAND, body_top + BAND * 0.5))
	# The body: one cylinder, on the grid shader so its label can be printed round it.
	var body := _drum(parent, "PedestalBody", r - 0.04, ph, FOOT + ph * 0.5)
	body.material_override = LabGrid.material("kit_metal", Vector4((r - 0.04) * 2.0, ph, (r - 0.04) * 2.0, Build.W_DEPTH), origin)
	parts["body"] = body
	parts["body_r"] = r - 0.04
	parts["body_y"] = FOOT + ph * 0.5
	# The light lines: one in the band under the lip, one round the foot.
	var b := Batch.new()
	b.ring("glow", Vector4(0, body_top + BAND * 0.5, 0, 0), r - 0.095, 0.02, 0.022, Build.W_DEPTH * 0.5, 96)
	b.ring("glow", Vector4(0, FOOT * 0.45, 0, 0), r - 0.115, 0.02, 0.022, Build.W_DEPTH * 0.5, 96)
	var glow: MeshInstance4D = b.instance("glow")
	glow.name = "PedestalGlow"
	glow.set_meta(Build.GENERATED, true)
	parent.add_child(glow)
	parts["glow"].append(glow)
	parts["lip"] = _drum(parent, "PedestalLip", r, LIP, h - LIP * 0.5)
	parts["deck"] = _drum(parent, "PedestalDeck", r - DECK_IN, 0.02, h + 0.004)
	var solid := StaticBody4D.new()
	solid.name = "PedestalSolid"
	solid.position = Vector4(0, h * 0.5, 0, 0)
	var shape := CollisionShape4D.new()
	var bs := BoxShape4D.new()
	bs.size = Vector4(r * 2.0 + 0.3, h, r * 2.0 + 0.3, Build.W_DEPTH)
	shape.shape = bs
	solid.add_child(shape)
	solid.set_meta(Build.GENERATED, true)
	parent.add_child(solid)
	parts["deck_h"] = h + 0.014
	apply_mood(parts)
	return parts


static func _drum(parent: Node4D, nm: String, r: float, h: float, y: float) -> MeshInstance4D:
	var m := MeshInstance4D.new()
	m.name = nm
	m.mesh = Build._cubinder(r, h, 96)
	m.position = Vector4(0, y, 0, 0)
	m.set_meta(Build.GENERATED, true)
	parent.add_child(m)
	return m


static func apply_mood(parts: Dictionary) -> void:
	var dark: Color = Style.pick(Style.PLINTH) * 0.7
	dark.a = 1.0
	for m in parts.get("dark", []):
		if is_instance_valid(m):
			(m as MeshInstance4D).material_override = Mats.flat(dark)
	for m in parts.get("glow", []):
		if is_instance_valid(m):
			(m as MeshInstance4D).material_override = Mats.glow(Style.pick(Style.GLOW_WARM), 1.6)
	if is_instance_valid(parts.get("lip")):
		(parts["lip"] as MeshInstance4D).material_override = Mats.flat(Style.pick(Style.LIP))
	if is_instance_valid(parts.get("deck")):
		(parts["deck"] as MeshInstance4D).material_override = Mats.flat(Style.pick(Style.DECK))


## Wraps `paint` round the front (+Z) of the body, `width` metres of its circumference, at heights
## `y0`..`y1` from the floor.
static func print_band(tree: SceneTree, parts: Dictionary, width: float, y0: float, y1: float, paint: Callable, ppm: float = 320.0) -> void:
	var body: MeshInstance4D = parts.get("body")
	if not is_instance_valid(body):
		return
	var tex: Texture2D = await LabPrint.render(tree, Vector2i(int(width * ppm), int((y1 - y0) * ppm)), paint)
	if tex == null or not is_instance_valid(body):
		return
	var half: float = width * 0.5 / float(parts["body_r"])
	var by: float = float(parts["body_y"])
	LabGrid.set_print_cylinder(body.material_override as TetraMaterial4D, tex, -half, half, y0 - by, y1 - by, Color.WHITE, 0.25)
