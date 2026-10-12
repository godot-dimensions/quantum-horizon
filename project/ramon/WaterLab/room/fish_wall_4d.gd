extends Node4D

## WATER LAB: the fish wall, on the wall facing the tank (Ramon, 9 Oct: "make on the wall in front of the
## tank, we can show different fish with their specs, and rotating in ui panels if you need 2 ui walls
## next to each other for that to make it bigger thats fine").
##
## TWO PANELS SIDE BY SIDE, blue slabs in the kit's code blue, each a page drawn in its own viewport and
## printed on the slab (the kit's way). Each page shows one of the tank's animals at a time and turns to
## the next every `seconds`, the two panels half a turn apart:
##   on the left, the animal on a TURNTABLE: a small 3D studio of its own (its own World3D, a camera, a
##   key light, deep blue). Every animal is lofted in 4D (round 5) and shown as the true cut of its 4D
##   body at w = 0 (shared/slice_mesh.gd), painted as in the tank (the koi by
##   life/koi_picture.gdshader, the eel and the crab by life/loft_picture.gdshader): a Camera4D can only
##   be the one current camera of the whole game, so a 4D body is shown here by its slice;
##   on the right, its name and its Latin, a line, and its specs: size, how it swims, how it is drawn,
##   what it costs.
##
## The animals: four koi varieties, the eel, the crab, the hammerhead. NO class_name.

const Mats := preload("res://ramon/WaterLab/carried/LabKit/lab_materials.gd")
const LabGrid := preload("res://ramon/WaterLab/carried/LabKit/lab_grid.gd")
const LabPrint := preload("res://ramon/WaterLab/carried/LabKit/lab_print.gd")
const Style := preload("res://ramon/WaterLab/carried/kit/kit_style.gd")
const Build := preload("res://ramon/WaterLab/carried/scripts/chamber_build.gd")
const KoiLoft := preload("res://ramon/WaterLab/life/koi_loft_4d.gd")
const KOI_PICTURE := preload("res://ramon/WaterLab/life/koi_picture.gdshader")
const EelLoft := preload("res://ramon/WaterLab/life/eel_loft_4d.gd")
const LOFT_PICTURE := preload("res://ramon/WaterLab/life/loft_picture.gdshader")
const CrabLoft := preload("res://ramon/WaterLab/life/crab_loft_4d.gd")
const Shark := preload("res://ramon/WaterLab/life/shark_4d.gd")
const SliceMesh := preload("res://ramon/WaterLab/shared/slice_mesh.gd")

## Each panel's size (m), how far apart their middles are, the slabs' foot off the floor.
@export var panel_size: Vector2 = Vector2(7.2, 4.4)
@export var spacing: float = 7.6
@export var foot: float = 0.9
@export var seconds: float = 10.0
## The blue wall behind both panels, floor to ceiling (Ramon, 9 Oct: "the blue wall that is behind
## the blue panels with the fish diagrams [should] extend all the way up and all the way down ... if
## there is a blue wall, this blue wall should always reach the edge of the ceiling and the bottom of
## the floor. That's the rule"): its height (the room's) and how far it reaches past the panels.
@export var backing_height: float = 11.0
@export var backing_margin: float = 0.4
## ROUND 3 (Ramon, 9 Oct: "I would like that entire wall to be blue ... have the background of these
## panels also be just the plain blue background of the wall and not have these brighter blue bits";
## and the pages sat a little off the blue behind them): the pages are printed straight into the
## wall of the kit room named here (its south wall, the one you came in by), the way the kit's wall
## panels are. Each page claims its stretch of the wall, which makes the whole wall the code blue and
## splits it where the page begins and ends. No slabs, no backing: nothing to line up. Without the
## room, the old slabs.
@export var room_name: String = "Hall"
@export var wall: String = "s"
const PPM := 200.0

const CARDS := [
	{"kind": "koi", "variety": 0, "name": "Kohaku", "latin": "Cyprinus rubrofuscus  ·  koi", "kicker": "WHITE WITH RED, THE FIRST OF THE KOI",
		"line": "Swims with a wave down its body, glides between beats, bends into a C to turn.",
		"rows": [["Length here", "0.6 to 1.0 m"], ["Tail beats", "about 1.4 a second at cruise"], ["The wave", "0.02 of its length at the head, 0.10 at the tail"], ["Drawn as", "lofted in 4D, seven rigid pieces"], ["In the tank", "16 koi, 4 of them off your slice"]]},
	{"kind": "koi", "variety": 2, "lift": 0.16, "name": "Showa", "latin": "Cyprinus rubrofuscus  ·  koi", "kicker": "BLACK OVER WHITE AND RED",
		"line": "Black reaching the head, black at the root of each pectoral fin: the pattern grown by noise on its back.",
		"rows": [["Pattern", "warped noise over its 4D back, as a koi is judged, from above"], ["Fins", "black at the root, white rays"], ["Painted", "per pixel, from its place on the 4D body"], ["Bends", "its pieces follow the swim wave"]]},
	{"kind": "eel", "name": "European eel", "latin": "Anguilla anguilla", "kicker": "HIDES BY DAY, HUNTS ALONG THE BOTTOM",
		"line": "The whole body waves, more than one wave on it at once; it backs into its cave tail first.",
		"rows": [["Length", "1.4 m"], ["The wave", "0.72 of its length, growing toward the tail"], ["Backing up", "the wave runs the other way"], ["Drawn as", "lofted in 4D, twelve rigid pieces"], ["Lives", "in the cave under the rock pile"]]},
	{"kind": "koi", "variety": 4, "name": "Ogon", "latin": "Cyprinus rubrofuscus  ·  koi", "kicker": "ONE METALLIC COLOUR, GOLD",
		"line": "One metallic colour and a wet highlight: the sheen of a koi under the lights.",
		"rows": [["Highlight", "three times a plain koi's"], ["Scales", "rows of arcs, faded where smaller than a pixel"]]},
	{"kind": "crab", "lift": 0.06, "name": "Brown crab", "latin": "Cancer pagurus", "kicker": "WALKS SIDEWAYS, AND THROUGH W",
		"line": "It wanders the tank's whole floor, x, z and W: it comes onto your slice somewhere, picks at the sand, and walks off through W.",
		"rows": [["Width", "0.34 m"], ["Legs", "eight, two sets of four in turn"], ["Claws", "pick at the sand, the pincers open and close"], ["Drawn as", "lofted in 4D, jointed legs and claws"]]},
	{"kind": "koi", "variety": 6, "name": "Asagi", "latin": "Cyprinus rubrofuscus  ·  koi", "kicker": "A BLUE NET, RED BELOW",
		"line": "The oldest of the varieties: each scale outlined pale on a blue-grey back, orange-red on the flanks.",
		"rows": [["Net", "every scale's edge drawn from its place on the body"], ["Below", "orange-red, cheeks and fin roots"]]},
	{"kind": "shark", "name": "Scalloped hammerhead", "latin": "Sphyrna lewini", "kicker": "THE LOFT TOOL'S SHOWCASE",
		"line": "Lofted in 4D by the tool that builds our animals, cut into rigid pieces; at the tank's ends it turns through W.",
		"rows": [["Length", "2.4 m, its hammer 30% of it"], ["Pieces", "six of body, the hammer, the fins"], ["Tail beats", "0.6 to 1 a second, glides between"], ["Shown here", "its true cut at w = 0"]]},
]

var _panels: Array = []
var _t: float = 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_room = get_parent().get_node_or_null(room_name)
	if _room == null:
		_build_backing()
	for i in 2:
		_panels.append(_build_panel(i))


var _room: Node = null


## Where a page runs along the room's wall (the room's own x), and up it.
func _span(i: int) -> Vector2:
	var local_x: float = (float(i) - 0.5) * spacing
	var world_x: float = (global_position + global_basis * Vector4(local_x, 0, 0, 0)).x
	var mid: float = world_x - (_room as Node4D).global_position.x
	return Vector2(mid - panel_size.x * 0.5, mid + panel_size.x * 0.5)


## The page's picture onto the wall pieces it runs over (they change when the room rebuilds the wall).
func _print_on_wall(panel: Dictionary) -> void:
	if _room == null:
		return
	var sp: Vector2 = _span(int(panel["index"]))
	var targets: Array = _room.call("print_targets", wall, sp.x, sp.y, foot, foot + panel_size.y)
	var key: String = ""
	for tg in targets:
		key += ":%d" % (tg[0] as Object).get_instance_id()
	if key == String(panel.get("key", "")):
		return
	panel["key"] = key
	var vp: SubViewport = panel["vp"]
	for tg in targets:
		var m: TetraMaterial4D = (tg[0] as MeshInstance4D).material_override as TetraMaterial4D
		if m == null:
			continue
		LabGrid.set_print(m, vp.get_texture(), tg[1], tg[2], Color.WHITE, 0.15)
		LabGrid.set_print_strength(m, 1.0)
		m.get_cross_section_material_3d().set_shader_parameter("print_aa", 1.0)


## The blue backing: one code-blue sheet on the wall behind both panels, floor to ceiling.
func _build_backing() -> void:
	var wide: float = spacing + panel_size.x + 0.4 + backing_margin * 2.0
	var size := Vector4(wide, backing_height, 0.02, Build.W_DEPTH)
	var b := MeshInstance4D.new()
	b.name = "Backing"
	b.mesh = Mats.box_mesh(size)
	# Just in front of the wall (the slabs' backs reach into it), behind the slabs' faces.
	b.position = Vector4(0.0, backing_height * 0.5, -0.16, 0.0)
	b.material_override = LabGrid.material(Style.code_swatch("blue"), size, global_position + b.position)
	add_child(b)


func _build_panel(i: int) -> Dictionary:
	var x: float = (float(i) - 0.5) * spacing
	var holder := Node4D.new()
	holder.name = "Panel%d" % i
	holder.position = Vector4(x, foot, 0.0, 0.0)
	add_child(holder)
	var size := Vector4(panel_size.x + 0.4, panel_size.y + 0.4, 0.3, Build.W_DEPTH)
	var slab: MeshInstance4D = null
	var m: TetraMaterial4D = null
	if _room == null:
		slab = MeshInstance4D.new()
		slab.name = "Slab"
		slab.mesh = Mats.box_mesh(size)
		slab.position = Vector4(0.0, size.y * 0.5, -0.15, 0.0)
		m = LabGrid.material(Style.code_swatch("blue"), size, global_position + holder.position + slab.position)
		slab.material_override = m
		holder.add_child(slab)
	else:
		# Its stretch of the wall, claimed: the whole wall goes blue, split where the page runs.
		var sp: Vector2 = _span(i)
		_room.call("claim_wall", wall, "blue", holder, sp.x, sp.y)
	# The page: clear behind its words, so the wall's own blue shows (premultiplied, as the kit's prints).
	var vp := SubViewport.new()
	vp.size = Vector2i(int(panel_size.x * PPM), int(panel_size.y * PPM))
	vp.transparent_bg = _room != null
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	holder.add_child(vp)
	var page := Control.new()
	page.size = Vector2(vp.size)
	vp.add_child(page)
	# The studio, its picture on the page.
	var studio := SubViewport.new()
	studio.size = Vector2i(int(vp.size.x * 0.46), int(vp.size.y * 0.78))
	studio.own_world_3d = true
	# Clear: the page draws the dark blue and its blueprint lines under the picture (round 2).
	studio.transparent_bg = true
	studio.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	holder.add_child(studio)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.45, 0.55, 0.65)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	studio.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-40.0), deg_to_rad(-30.0), 0.0)
	key.light_energy = 1.3
	studio.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(deg_to_rad(-20.0), deg_to_rad(150.0), 0.0)
	rim.light_energy = 0.6
	rim.light_color = Color(0.6, 0.8, 1.0)
	studio.add_child(rim)
	var cam := Camera3D.new()
	cam.fov = 32.0
	cam.current = true
	studio.add_child(cam)
	var pic := TextureRect.new()
	pic.texture = studio.get_texture()
	pic.position = Vector2(vp.size.x * 0.03, vp.size.y * 0.15)
	pic.size = Vector2(studio.size)
	page.add_child(pic)
	var panel: Dictionary = {"holder": holder, "slab": slab, "vp": vp, "page": page, "studio": studio, "specimen": null, "card": -1,
		"offset": i * CARDS.size() / 2, "index": i}
	page.draw.connect(_paint.bind(panel))
	# The page on the slab's face toward the room (+Z of the holder, turned to face the tank).
	if m != null:
		_print_later(m, vp, size)
	return panel


func _print_later(m: TetraMaterial4D, vp: SubViewport, size: Vector4) -> void:
	await get_tree().process_frame
	LabGrid.set_print(m, vp.get_texture(), Vector4(0, 0, 1, 0), Rect2(Vector2(0.2, 0.2), panel_size), Color.WHITE, 0.25)
	LabGrid.set_print_strength(m, 1.0)
	m.get_cross_section_material_3d().set_shader_parameter("print_aa", 1.0)


func _process(delta: float) -> void:
	_t += delta
	for panel in _panels:
		var idx: int = (int(floor(_t / seconds)) + int(panel["offset"])) % CARDS.size()
		if idx != int(panel["card"]):
			panel["card"] = idx
			_show(panel, CARDS[idx])
		_turn(panel, delta)
		(panel["page"] as Control).queue_redraw()
		_print_on_wall(panel)


## A new animal on the turntable.
##
## ROUND 6 (Ramon, #34: "The rotating hammerhead shark and fish displays currently appear static apart from
## their display rotation. I'd like their existing creature animations to remain active ... Let both
## animations work together without interfering with each other"): each card's animal was one cut of its
## loft at rest, made once. Now it is the loft's rigid pieces, each cut at w = 0 once in its own frame
## (shared/slice_mesh.gd), and placed every frame where the loft's own pose puts it: the koi and the eel
## swim, the crab walks on the spot and works its claws, the hammerhead swims, while the turntable turns
## the whole. This is exact, not a likeness: every turn the poses make is about x, y or z (loft_kit.gd
## yaw, rot_x, rot_y, rot_z), never through W, so a piece's cut is the same wherever the pose puts it.
## The lofts themselves are built once and never enter the tree (only their transforms are read).
func _show(panel: Dictionary, card: Dictionary) -> void:
	var studio: SubViewport = panel["studio"]
	if panel["specimen"] != null and is_instance_valid(panel["specimen"]):
		(panel["specimen"] as Node).queue_free()
	var kind: String = String(card["kind"])
	var node: Node3D = _card_animal(kind, card)
	match kind:
		"shark":
			panel["distance"] = 4.2
		"eel":
			panel["distance"] = 2.6
		"crab":
			# A little further back than at first, so its legs stay in the picture once lifted.
			panel["distance"] = 1.2
		_:
			panel["distance"] = 1.9
	studio.add_child(node)
	panel["specimen"] = node
	panel["angle"] = 0.6
	panel["kind"] = kind
	panel["lift"] = float(card.get("lift", 0.0))
	panel["swim"] = randf() * TAU
	_animate(panel, 0.0)


## The lofts, built once: kind -> {"loft": the loft node, "body": its body, "pieces": [[MeshInstance4D,
## its cut ArrayMesh]], "skin": its 3D texture or null}.
var _lofts: Dictionary = {}


func _loft(kind: String) -> Dictionary:
	if _lofts.has(kind):
		return _lofts[kind]
	var t0: int = Time.get_ticks_usec()
	var k := Node4D.new()
	var body: Node4D
	var skin: Texture3D = null
	match kind:
		"shark":
			k.set_script(Shark)
			# Its _ready builds its pieces from the bakes; called by hand, as it never enters the tree.
			k.call("_ready")
			body = k.get("_body")
		_:
			k.set_script({"koi": KoiLoft, "eel": EelLoft, "crab": CrabLoft}[kind])
			k.set("detail", 2)
			k.call("build")
			body = k.get("body")
			var mat: TetraMaterial4D = k.get("material") as TetraMaterial4D
			if mat != null and kind != "koi":
				skin = mat.albedo_texture_3d
	var pieces: Array = []
	var stack: Array = [body]
	for guard in 4096:
		if stack.is_empty():
			break
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is MeshInstance4D:
			var col: Color = Color(0.05, 0.05, 0.05) if (kind == "shark" and String(n.name) == "Eyes") else (Color(0.36, 0.36, 0.32) if kind == "shark" else Color.WHITE)
			pieces.append([n, SliceMesh.cut([[(n as MeshInstance4D).mesh, Projection.IDENTITY, Vector4.ZERO, col]], 0.0)])
	var rec: Dictionary = {"loft": k, "body": body, "pieces": pieces, "skin": skin}
	_lofts[kind] = rec
	print("FISH WALL %s: %d pieces cut in %.0f ms" % [kind, pieces.size(), (Time.get_ticks_usec() - t0) / 1000.0])
	return rec


## A card's animal: one MeshInstance3D a piece, in the card's paint, under one node the turntable turns.
func _card_animal(kind: String, card: Dictionary) -> Node3D:
	var rec: Dictionary = _loft(kind)
	var root := Node3D.new()
	var mat: Material
	match kind:
		"shark":
			mat = _shark_material()
		"koi":
			var km := ShaderMaterial.new()
			km.shader = KOI_PICTURE
			km.set_shader_parameter(&"variety", float(card.get("variety", 0)))
			km.set_shader_parameter(&"pattern_seed", 0.37)
			km.set_shader_parameter(&"detail", 1.0)
			km.set_shader_parameter(&"koi_profile", KoiLoft.profile())
			mat = km
		_:
			var lm := ShaderMaterial.new()
			lm.shader = LOFT_PICTURE
			lm.set_shader_parameter(&"skin", rec["skin"])
			if kind == "crab":
				lm.set_shader_parameter(&"clearcoat", 0.4)
			mat = lm
	for pc in rec["pieces"]:
		var mi := MeshInstance3D.new()
		mi.mesh = pc[1]
		mi.material_override = mat
		root.add_child(mi)
	# The size shown: the koi one body length to 0.95 m, the eel to 1.4 m, the crab 0.34 m across (the
	# hammerhead's bakes are life size).
	root.scale = Vector3.ONE * float({"koi": 0.95, "eel": 1.4, "crab": 0.34}.get(kind, 1.0))
	root.set_meta("kind", kind)
	return root


## Countershaded by height, the eyes dark (their vertex colour).
func _shark_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode cull_disabled;
varying float h;
varying vec3 vc;
void vertex() { h = VERTEX.y; vc = COLOR.rgb; }
void fragment() {
	vec3 top = vec3(0.30, 0.30, 0.26);
	vec3 belly = vec3(0.90, 0.89, 0.85);
	vec3 c = mix(belly, top, smoothstep(-0.02, 0.03, h));
	ALBEDO = vc.r < 0.1 ? vc : c;
	ROUGHNESS = 0.5;
}"""
	mat.shader = sh
	return mat


## The card's animal posed for now: its loft posed at the origin, level (its swim's own numbers, gentler
## than in the tank so it stays in the picture), then each piece's place up to the body read off it.
func _animate(panel: Dictionary, delta: float) -> void:
	var node: Node3D = panel["specimen"]
	if node == null or not is_instance_valid(node):
		return
	var kind: String = String(panel.get("kind", ""))
	if not _lofts.has(kind):
		return
	var rec: Dictionary = _lofts[kind]
	var k: Node4D = rec["loft"]
	var swim: float = float(panel.get("swim", 0.0)) + delta
	panel["swim"] = swim
	match kind:
		"shark":
			k.set("p", Vector4.ZERO)
			k.set("frame", Projection.IDENTITY)
			k.set("_phase", fmod(TAU * 0.65 * swim, TAU * 64.0))
			k.set("_amp", 0.7)
			k.call("_pose")
		"koi":
			k.call("pose", Vector4.ZERO, Projection.IDENTITY, 1.0, fmod(TAU * 0.9 * swim, TAU * 64.0), 0.07, 0.0, 0.3, 0.0, swim)
		"eel":
			k.call("pose", Vector4.ZERO, Projection.IDENTITY, 1.0, fmod(TAU * 0.6 * swim, TAU * 64.0), 0.07, 0.0, 0.0, 0.0)
		"crab":
			k.call("pose", Vector4.ZERO, Projection.IDENTITY, 1.0, fmod(TAU * 0.8 * swim, TAU * 64.0), 0.6, 0.3 + 0.25 * sin(swim * 0.9),
				0.5 + 0.5 * sin(swim * 1.7), swim)
	var body: Node4D = rec["body"]
	var pieces: Array = rec["pieces"]
	for i in mini(pieces.size(), node.get_child_count()):
		var n: Node4D = pieces[i][0]
		var b: Projection = n.basis
		var o: Vector4 = n.position
		var up: Node = n.get_parent()
		for guard in 16:
			if up == null or up == body:
				break
			var h := up as Node4D
			o = h.basis * o + h.position
			b = h.basis * b
			up = up.get_parent()
		(node.get_child(i) as Node3D).transform = Transform3D(Basis(Vector3(b.x.x, b.x.y, b.x.z), Vector3(b.y.x, b.y.y, b.y.z), Vector3(b.z.x, b.z.y, b.z.z)), Vector3(o.x, o.y, o.z))


func _exit_tree() -> void:
	for kind in _lofts:
		var k: Node = (_lofts[kind] as Dictionary)["loft"]
		if is_instance_valid(k) and not k.is_inside_tree():
			k.free()
	_lofts.clear()


## The crab seen a little from above (round 6, Ramon, #33: "The small rotating crab diagram currently
## exposes too much of its underside ... Present the crab from a slightly elevated, top-down perspective"):
## its tilt was about its own x, before the turntable's turn, so as it turned the tilt went round with it
## and every half turn showed it from below. The crab's tilt is now toward the camera, after the turn. (Its
## lift came down from 0.14 to 0.06 with it: seen from above, it had risen to the top of its picture.)
const CRAB_TILT := 0.42


## The turntable: round and round, the animal turning on the spot as it swims.
func _turn(panel: Dictionary, delta: float) -> void:
	var node: Node3D = panel["specimen"]
	if node == null or not is_instance_valid(node):
		return
	panel["angle"] = float(panel["angle"]) + delta * 0.35
	var a: float = panel["angle"]
	var d: float = panel["distance"]
	# A card's lift: its animal raised that share of the picture's height (round 4: "raise the Showa and
	# the Edible crab displays"; the picture is 2 d tan(16 deg) high at the animal, the studio's fov 32).
	var up: float = float(panel.get("lift", 0.0)) * 2.0 * d * tan(deg_to_rad(16.0))
	node.position = Vector3(0.0, -0.05 + up, -d)
	if String(panel.get("kind", "")) == "crab":
		var s: Vector3 = node.scale
		node.basis = Basis(Vector3.RIGHT, CRAB_TILT) * Basis(Vector3.UP, a)
		node.scale = s
	else:
		node.rotation = Vector3(0.25, a, 0.0)
	_animate(panel, delta)


## The picture's ground: dark blue and a clean grid of faint white lines, a little stronger every
## fourth, laid from the rectangle's middle so it is the same on both sides (round 3: the cross, the
## circle and the ticks went, the lines fainter).
func _blueprint(page: Control, r: Rect2, u: float) -> void:
	page.draw_rect(r, Color(0.03, 0.10, 0.20))
	var step: float = 26.0 * u
	var c: Vector2 = r.get_center()
	var nx: int = int(r.size.x * 0.5 / step)
	var ny: int = int(r.size.y * 0.5 / step)
	for i in range(-nx, nx + 1):
		var x: float = c.x + float(i) * step
		var strong: bool = i % 4 == 0
		page.draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(1, 1, 1, 0.07 if strong else 0.03), maxf(1.0, u))
	for j in range(-ny, ny + 1):
		var y: float = c.y + float(j) * step
		var strong2: bool = j % 4 == 0
		page.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(1, 1, 1, 0.07 if strong2 else 0.03), maxf(1.0, u))


func _paint(panel: Dictionary) -> void:
	var page: Control = panel["page"]
	var card: Dictionary = CARDS[maxi(int(panel["card"]), 0)]
	var sz: Vector2 = page.size
	var u: float = sz.y / 880.0
	if _room == null:
		page.draw_rect(Rect2(Vector2.ZERO, sz), Style.pick(Style.CODE_BLUE))
	var fb: Font = LabPrint.font("black")
	var fs: Font = LabPrint.font("bold")
	var fl: Font = LabPrint.font("body")
	var white := Color(1, 1, 1, 0.96)
	var dim := Color(1, 1, 1, 0.66)
	var pad: float = 44.0 * u
	page.draw_string(fs, Vector2(pad, pad + 20.0 * u), "THE TANK'S FISH", HORIZONTAL_ALIGNMENT_LEFT, -1, int(22 * u), dim)
	var count: String = "%02d / %02d" % [int(panel["card"]) + 1, CARDS.size()]
	page.draw_string(fs, Vector2(pad, pad + 20.0 * u), count, HORIZONTAL_ALIGNMENT_RIGHT, sz.x - pad * 2.0, int(22 * u), dim)
	page.draw_line(Vector2(pad, pad + 40.0 * u), Vector2(sz.x - pad, pad + 40.0 * u), Color(1, 1, 1, 0.3), maxf(1.0, 2.0 * u))
	# The picture's frame, on the dark blue of a blueprint (Ramon, 9 Oct: "behind the fishes ... on
	# this dark blue subtle, subtle white lines, also like this diagram style, blueprint style").
	var pic: Rect2 = Rect2(Vector2(sz.x * 0.03, sz.y * 0.15), Vector2((panel["studio"] as SubViewport).size))
	_blueprint(page, pic, u)
	page.draw_rect(pic.grow(4.0 * u), Color(1, 1, 1, 0.5), false, maxf(1.0, 3.0 * u))
	var x0: float = sz.x * 0.53
	var w: float = sz.x - x0 - pad
	page.draw_string(fs, Vector2(x0, sz.y * 0.19), String(card["kicker"]), HORIZONTAL_ALIGNMENT_LEFT, w, int(20 * u), Color(0.75, 0.9, 1.0, 0.9))
	# The name as large as fits ("Scalloped hammerhead" ran off the card at the full size).
	var title_px: int = int(66 * u)
	while title_px > int(34 * u) and fb.get_string_size(String(card["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, title_px).x > w:
		title_px -= 2
	page.draw_string(fb, Vector2(x0, sz.y * 0.19 + 74.0 * u), String(card["name"]), HORIZONTAL_ALIGNMENT_LEFT, w, title_px, white)
	page.draw_string(fl, Vector2(x0, sz.y * 0.19 + 112.0 * u), String(card["latin"]), HORIZONTAL_ALIGNMENT_LEFT, w, int(24 * u), dim)
	page.draw_multiline_string(fl, Vector2(x0, sz.y * 0.19 + 162.0 * u), String(card["line"]), HORIZONTAL_ALIGNMENT_LEFT, w, int(25 * u), 3, white)
	var y: float = sz.y * 0.19 + 270.0 * u
	for row in card["rows"]:
		page.draw_line(Vector2(x0, y - 30.0 * u), Vector2(x0 + w, y - 30.0 * u), Color(1, 1, 1, 0.22), maxf(1.0, u))
		page.draw_string(fs, Vector2(x0, y), String(row[0]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, w * 0.34, int(18 * u), dim)
		page.draw_string(fl, Vector2(x0 + w * 0.36, y), String(row[1]), HORIZONTAL_ALIGNMENT_LEFT, w * 0.64, int(22 * u), white)
		y += 56.0 * u
	# How far along to the next card.
	var k: float = fmod(_t, seconds) / seconds
	page.draw_rect(Rect2(Vector2(pad, sz.y - pad * 0.6), Vector2((sz.x - pad * 2.0) * k, 4.0 * u)), Color(1, 1, 1, 0.6))
