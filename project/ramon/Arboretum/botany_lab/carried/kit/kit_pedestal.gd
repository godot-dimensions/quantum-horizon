extends RefCounted

## Kit: the pedestal an exhibit stands on, after Ramon's concept frame (4 Oct: "make pedestal more
## like ref, and with the blue circle a little bit smaller, a decal text on the side of the
## pedestal would be nice too"). From the floor up:
##
##   a dark foot, set in
##   the body: one dark metal cylinder (Ramon, 4 Oct: "remove the separately placed blocks
##     around the grey part, one cylinder shape please"), its label wrapped round its front
##   a dark band, set in under the lip (the warm light lines that were here are gone: Ramon, 4 Oct)
##   the lip: a white ring, and the blue disc set into it, smaller than the lip
##
## build() makes it and returns its parts; apply_mood() recolours them; print_band() wraps a
## picture round the front of the body (the side text; lab_grid's cylinder print).
## The physics is one box (box-only physics), or for a round one, if asked, boxes that follow its circle
## (`round_solid`, below).
##
## NO class_name (engine_gotchas.md).

const Build := preload("res://ramon/Arboretum/botany_lab/carried/scripts/chamber_build.gd")
const Batch := preload("res://ramon/Arboretum/botany_lab/carried/LabKit/lab_batch.gd")
const Mats := preload("res://ramon/Arboretum/botany_lab/carried/LabKit/lab_materials.gd")
const LabGrid := preload("res://ramon/Arboretum/botany_lab/carried/LabKit/lab_grid.gd")
const LabPrint := preload("res://ramon/Arboretum/botany_lab/carried/LabKit/lab_print.gd")
const Style := preload("res://ramon/Arboretum/botany_lab/carried/kit/kit_style.gd")

const FOOT := 0.09
const BAND := 0.07
const LIP := 0.13
## The specimen pedestals' green (round 4): the lab's grass green, flat.
const GREEN := Color(0.33, 0.52, 0.2)
## How far in from the edge the blue disc starts.
const DECK_IN := 0.42
## BOTANY LAB, round 8 (Ramon, #58: "There is a strange square-shaped collision area around the large Oak
## showcase ... Replace it with a simple cylindrical collision shape that closely follows the pedestal's
## footprint"): the physics is box-only and square to the world, so a round pedestal's one box (its
## diameter and 0.3 m) stood out at its corners, 1.8 m past the rim of the oak's 4 m pedestal. Asked for
## (`round_solid`), it is instead this many boxes, all centred on it, each wide one way and narrow the other
## (a box at angle a is cos a by sin a of a circle), their corners on that circle: the outline is a staircase
## round it. Its steps are deepest at 45 degrees, in from the corners' circle by about half the angle between
## boxes (as a share of the radius: 2.5% with 32), so the circle is sized for the deepest step to stand
## RING_CLEAR outside the rim; the corners then stand about 12 cm out on the oak. (Measured in round 8 by rays:
## with 16 boxes on a circle 5 cm out, the 45-degree steps were 15 cm inside the rim.)
const RING_BOXES := 32
## How far outside the rim the staircase's deepest step is, m.
const RING_CLEAR := 0.02


## Builds the pedestal under `parent` at its origin; returns its parts, with "deck_h" the height
## an exhibit stands at.
## ARBORETUM (carried copy): `form` "box" builds it square (the voxel tree stands on a box: it is
## made of boxes), `r` then half its side; "round" is the original.
## BOTANY LAB, round 3 (Ramon, 10 Oct: "change the layout and the pedestals"): "planter" and "planter_box"
## build a garden planter instead: a pale stone body with a rim, a bed of dark soil set just below the
## rim (the tree stands in it), and a thin warm line of light under the rim; lower than the lab drums.
## Round 4 (Ramon: "Replace the existing blue or grass-covered presentation areas with a solid green
## surface ... Keep the surrounding pedestal geometry white"): "specimen" and "specimen_box" are the
## planter's shape in white, with a flat green surface where the soil was.
## `round_solid` (round 8): a round pedestal's physics follows its circle (RING_BOXES) instead of one square box.
static func build(parent: Node4D, r: float, h: float, form: String = "round", round_solid: bool = false) -> Dictionary:
	if form == "planter" or form == "planter_box":
		return _build_planter(parent, r, h, form == "planter_box", false, round_solid)
	if form == "specimen" or form == "specimen_box":
		return _build_planter(parent, r, h, form == "specimen_box", true, round_solid)
	if form == "box":
		return _build_box(parent, r, h)
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
	parts["lip"] = _drum(parent, "PedestalLip", r, LIP, h - LIP * 0.5)
	parts["deck"] = _drum(parent, "PedestalDeck", r - DECK_IN, 0.02, h + 0.004)
	_solid(parent, r, h, round_solid)
	parts["deck_h"] = h + 0.014
	apply_mood(parts)
	return parts


## The square pedestal: the same parts from the floor up (a dark foot set in, the dark metal body
## carrying the label on its faces, a dark band, the white lip, the blue deck set into it), boxes.
static func _build_box(parent: Node4D, r: float, h: float) -> Dictionary:
	var origin: Vector4 = parent.global_position if parent.is_inside_tree() else Vector4.ZERO
	var body_top: float = h - LIP - BAND
	var ph: float = body_top - FOOT
	var parts: Dictionary = {"dark": [], "glow": [], "panels": [], "shape": "box"}
	parts["dark"].append(_slab(parent, "PedestalFoot", r - 0.13, FOOT, FOOT * 0.5))
	parts["dark"].append(_slab(parent, "PedestalBand", r - 0.11, BAND, body_top + BAND * 0.5))
	var body := _slab(parent, "PedestalBody", r - 0.04, ph, FOOT + ph * 0.5)
	body.material_override = LabGrid.material("kit_metal", Vector4((r - 0.04) * 2.0, ph, (r - 0.04) * 2.0, Build.W_DEPTH), origin)
	parts["body"] = body
	parts["body_r"] = r - 0.04
	parts["body_y"] = FOOT + ph * 0.5
	parts["lip"] = _slab(parent, "PedestalLip", r, LIP, h - LIP * 0.5)
	parts["deck"] = _slab(parent, "PedestalDeck", r - DECK_IN, 0.02, h + 0.004)
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


## The planter: from the floor up, a dark foot set in (its shadow line), the stone body (the label is
## printed on it), a warm line of light, the stone rim a little proud of the body, and the soil.
static func _build_planter(parent: Node4D, r: float, h: float, square: bool, white: bool = false, round_solid: bool = false) -> Dictionary:
	if not LabGrid._values.has("planter_stone"):
		LabGrid.set_swatch("planter_stone", Color(0.84, 0.81, 0.75), Color(0.76, 0.73, 0.67), Color(0.81, 0.78, 0.72), 0.22)
	if not LabGrid._values.has("specimen_white"):
		LabGrid.set_swatch("specimen_white", Color(0.93, 0.93, 0.92), Color(0.86, 0.86, 0.85), Color(0.9, 0.9, 0.89), 0.15)
	var origin: Vector4 = parent.global_position if parent.is_inside_tree() else Vector4.ZERO
	var rim_h: float = 0.09
	var body_h: float = h - rim_h - FOOT
	var parts: Dictionary = {"dark": [], "glow": [], "panels": [], "planter": true, "specimen": white}
	if square:
		parts["shape"] = "box"
	var piece := func(nm: String, rr: float, hh: float, y: float) -> MeshInstance4D:
		return _slab(parent, nm, rr, hh, y) if square else _drum(parent, nm, rr, hh, y)
	parts["dark"].append(piece.call("PedestalFoot", r - 0.1, FOOT, FOOT * 0.5))
	var body: MeshInstance4D = piece.call("PedestalBody", r - 0.03, body_h, FOOT + body_h * 0.5)
	body.material_override = LabGrid.material("specimen_white" if white else "planter_stone", Vector4((r - 0.03) * 2.0, body_h, (r - 0.03) * 2.0, Build.W_DEPTH), origin)
	parts["body"] = body
	parts["body_r"] = r - 0.03
	parts["body_y"] = FOOT + body_h * 0.5
	parts["glow"].append(piece.call("PedestalGlow", r - 0.025, 0.022, FOOT + body_h - 0.02))
	parts["lip"] = piece.call("PedestalLip", r + 0.03, rim_h, h - rim_h * 0.5)
	# (Round 4: the rim is a solid drum, so a surface below its top never showed: the soil, or the green, sits
	# on it, inset to leave a band of rim round it.)
	parts["deck"] = piece.call("PedestalSoil", r - 0.12, 0.02, h + 0.01)
	_solid(parent, r, h, round_solid and not square, 0.03)
	parts["deck_h"] = h + 0.02
	apply_mood(parts)
	return parts


## The pedestal's physics, `h` high: one box `r` + 0.15 m out each way (as it always was), or with
## `follow_circle` the RING_BOXES boxes whose staircase stays RING_CLEAR or more outside the rim (`rim_out` past
## `r`: the planter's rim stands 3 cm proud of its body).
static func _solid(parent: Node4D, r: float, h: float, follow_circle: bool, rim_out: float = 0.0) -> void:
	var solid := StaticBody4D.new()
	solid.name = "PedestalSolid"
	solid.position = Vector4(0, h * 0.5, 0, 0)
	var halves: Array = [Vector2(r + 0.15, r + 0.15)]
	if follow_circle:
		halves = []
		# The deepest step (between the boxes either side of 45 degrees) is in from the corners by sqrt(1 - sin d).
		var step: float = PI * 0.5 / float(RING_BOXES)
		var rc: float = (r + rim_out + RING_CLEAR) / sqrt(1.0 - sin(step))
		for k in RING_BOXES:
			var a: float = (float(k) + 0.5) * PI * 0.5 / float(RING_BOXES)
			halves.append(Vector2(rc * cos(a), rc * sin(a)))
	for hv in halves:
		var shape := CollisionShape4D.new()
		var bs := BoxShape4D.new()
		bs.size = Vector4((hv as Vector2).x * 2.0, h, (hv as Vector2).y * 2.0, Build.W_DEPTH)
		shape.shape = bs
		solid.add_child(shape)
	solid.set_meta(Build.GENERATED, true)
	parent.add_child(solid)


static func _slab(parent: Node4D, nm: String, half: float, h: float, y: float) -> MeshInstance4D:
	var m := MeshInstance4D.new()
	m.name = nm
	m.mesh = Mats.box_mesh(Vector4(half * 2.0, h, half * 2.0, Build.W_DEPTH))
	m.position = Vector4(0, y, 0, 0)
	m.set_meta(Build.GENERATED, true)
	parent.add_child(m)
	return m


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
	if bool(parts.get("planter", false)):
		# The planter: a pale stone rim, dark soil; the specimen's: a white rim, a flat green surface.
		var specimen: bool = bool(parts.get("specimen", false))
		if is_instance_valid(parts.get("lip")):
			(parts["lip"] as MeshInstance4D).material_override = Mats.flat(Style.lip() if specimen else Color(0.9, 0.87, 0.81))
		if is_instance_valid(parts.get("deck")):
			(parts["deck"] as MeshInstance4D).material_override = Mats.flat(GREEN if specimen else Color(0.2, 0.14, 0.1))
		return
	if is_instance_valid(parts.get("lip")):
		(parts["lip"] as MeshInstance4D).material_override = Mats.flat(Style.lip())
	if is_instance_valid(parts.get("deck")):
		(parts["deck"] as MeshInstance4D).material_override = Mats.flat(Style.pick(Style.DECK))


## Wraps `paint` round the body, `width` metres of its circumference centred at `centre` (radians from
## the front, +Z, towards +X), at heights `y0`..`y1` from the floor.
static func print_band(tree: SceneTree, parts: Dictionary, width: float, y0: float, y1: float, paint: Callable, ppm: float = 320.0, centre: float = 0.0) -> void:
	var body: MeshInstance4D = parts.get("body")
	if not is_instance_valid(body):
		return
	var tex: Texture2D = await LabPrint.render(tree, Vector2i(int(width * ppm), int((y1 - y0) * ppm)), paint)
	if tex == null or not is_instance_valid(body):
		return
	if String(parts.get("shape", "round")) == "box":
		# On a box, the face the label's angle points at (snapped to a quarter turn), centred on it.
		var q: int = posmod(int(round(centre / (PI * 0.5))), 4)
		var normals := [Vector4(0, 0, 1, 0), Vector4(1, 0, 0, 0), Vector4(0, 0, -1, 0), Vector4(-1, 0, 0, 0)]
		var side: float = float(parts["body_r"]) * 2.0
		var by0: float = float(parts["body_y"])
		var face_h: float = by0 * 2.0 - FOOT * 2.0
		var lw: float = minf(width, side - 0.1)
		LabGrid.set_print(body.material_override as TetraMaterial4D, tex, normals[q], Rect2(Vector2((side - lw) * 0.5, y0 - FOOT), Vector2(lw, y1 - y0)), Color.WHITE, 0.25)
		return
	var half: float = width * 0.5 / float(parts["body_r"])
	var by: float = float(parts["body_y"])
	LabGrid.set_print_cylinder(body.material_override as TetraMaterial4D, tex, centre - half, centre + half, y0 - by, y1 - by, Color.WHITE, 0.25)
