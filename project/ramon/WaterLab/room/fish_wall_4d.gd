extends Node4D

## WATER LAB: the fish wall, on the wall facing the tank (Ramon, 9 Oct: "make on the wall in front of the
## tank, we can show different fish with their specs, and rotating in ui panels if you need 2 ui walls
## next to each other for that to make it bigger thats fine").
##
## TWO PANELS SIDE BY SIDE, blue slabs in the kit's code blue, each a page drawn in its own viewport and
## printed on the slab (the kit's way). Each page shows one of the tank's animals at a time and turns to
## the next every `seconds`, the two panels half a turn apart:
##   on the left, the animal on a TURNTABLE, live: a small 3D studio of its own (its own World3D, a
##   camera, a key light, deep blue), the animal drawn by its own shader (the koi swimming on the spot,
##   the eel waving, the crab stepping), the hammerhead as the true cut of its 4D loft at w = 0
##   (shared/slice_mesh.gd): a Camera4D can only be the one current camera of the whole game, so a 4D
##   body is shown here by its slice;
##   on the right, its name and its Latin, a line, and its specs: size, how it swims, how it is drawn,
##   what it costs.
##
## The animals: four koi varieties, the eel, the crab, the hammerhead. NO class_name.

const Mats := preload("res://ramon/WaterLab/carried/LabKit/lab_materials.gd")
const LabGrid := preload("res://ramon/WaterLab/carried/LabKit/lab_grid.gd")
const LabPrint := preload("res://ramon/WaterLab/carried/LabKit/lab_print.gd")
const Style := preload("res://ramon/WaterLab/carried/kit/kit_style.gd")
const Build := preload("res://ramon/WaterLab/carried/scripts/chamber_build.gd")
const KoiMesh := preload("res://ramon/WaterLab/life/koi_mesh.gd")
const KOI := preload("res://ramon/WaterLab/life/koi.gdshader")
const EEL := preload("res://ramon/WaterLab/life/eel.gdshader")
const CRAB := preload("res://ramon/WaterLab/life/crab.gdshader")
const Eel := preload("res://ramon/WaterLab/life/eel_4d.gd")
const Crab := preload("res://ramon/WaterLab/life/crab_4d.gd")
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
		"rows": [["Length here", "0.6 to 1.0 m"], ["Tail beats", "about 1.4 a second at cruise"], ["The wave", "0.02 of its length at the head, 0.10 at the tail"], ["Drawn as", "a 3D shape stretched through W, cut by your slice"], ["In the tank", "16 koi, 4 of them off your slice"]]},
	{"kind": "koi", "variety": 2, "lift": 0.16, "name": "Showa", "latin": "Cyprinus rubrofuscus  ·  koi", "kicker": "BLACK OVER WHITE AND RED",
		"line": "Black reaching the head, black at the root of each pectoral fin: the pattern grown by noise on its back.",
		"rows": [["Pattern", "warped noise, laid out as a koi is judged, from above"], ["Fins", "black at the root, white rays"], ["Shader", "one draw call for every koi"], ["Bent on", "the graphics card, every frame"]]},
	{"kind": "eel", "name": "European eel", "latin": "Anguilla anguilla", "kicker": "HIDES BY DAY, HUNTS ALONG THE BOTTOM",
		"line": "The whole body waves, more than one wave on it at once; it backs into its cave tail first.",
		"rows": [["Length", "1.4 m"], ["The wave", "0.72 of its length, growing toward the tail"], ["Backing up", "the wave runs the other way"], ["Lives", "in the cave under the rock pile"]]},
	{"kind": "koi", "variety": 4, "name": "Ogon", "latin": "Cyprinus rubrofuscus  ·  koi", "kicker": "ONE METALLIC COLOUR, GOLD",
		"line": "A metallic skin and a clear coat over it: the wet sheen of a koi under the lights.",
		"rows": [["Metallic", "0.5, roughness 0.3"], ["Clear coat", "0.65 on the body"], ["Scales", "rows of arcs, faded where smaller than a pixel"]]},
	{"kind": "crab", "lift": 0.14, "name": "Edible crab", "latin": "Cancer pagurus", "kicker": "WALKS SIDEWAYS, AND THROUGH W",
		"line": "It wanders the tank's whole floor, x, z and W: it comes onto your slice somewhere, picks at the sand, and walks off through W.",
		"rows": [["Width", "0.34 m"], ["Legs", "eight, two sets of four in turn"], ["Claws", "pick at the sand, the pincers open and close"], ["Drawn as", "a 4D body, its legs stepping on the GPU"]]},
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
func _show(panel: Dictionary, card: Dictionary) -> void:
	var studio: SubViewport = panel["studio"]
	if panel["specimen"] != null and is_instance_valid(panel["specimen"]):
		(panel["specimen"] as Node).queue_free()
	var node: Node3D
	match String(card["kind"]):
		"shark":
			node = _shark_cut()
			panel["distance"] = 4.2
		"eel":
			node = _herd_specimen(Eel.build_mesh(), EEL, {&"w_radius": 0.06})
			panel["distance"] = 2.6
			panel["custom"] = Vector4(0.0, 0.07, 1.4, 0.0)
			panel["colour"] = Color(0.0, 0.0, 0.5, 0.0)
		"crab":
			node = _herd_specimen(Crab.build_mesh(), CRAB, {&"w_radius": 0.6})
			# A little further back than at first, so its legs stay in the picture once lifted.
			panel["distance"] = 1.2
			panel["custom"] = Vector4(0.0, 0.8, 0.34, 0.0)
			panel["colour"] = Color(0.0, 0.0, 0.0, 1.0)
		_:
			node = _herd_specimen(KoiMesh.build(2), KOI, {&"w_radius": 0.21, &"detail": 1.0})
			panel["distance"] = 1.9
			panel["custom"] = Vector4(0.0, 0.07, 0.95, 0.0)
			panel["colour"] = Color(float(card.get("variety", 0)) / 16.0, 0.37, 0.25, 0.0)
	studio.add_child(node)
	panel["specimen"] = node
	panel["angle"] = 0.6
	panel["phase"] = 0.0
	panel["kind"] = String(card["kind"])
	panel["lift"] = float(card.get("lift", 0.0))


## A slice-drawn animal for the studio: one instance of its mesh and shader, the view uniforms set so
## it stands `distance` in front of the studio's camera (whose frame is the view's own).
func _herd_specimen(mesh: Mesh, shader: Shader, params: Dictionary) -> Node3D:
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = 1
	mmi.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = shader
	for k in params:
		mat.set_shader_parameter(k, params[k])
	mat.set_shader_parameter(&"view_basis_x", Vector4(1, 0, 0, 0))
	mat.set_shader_parameter(&"view_basis_y", Vector4(0, 1, 0, 0))
	mat.set_shader_parameter(&"view_basis_z", Vector4(0, 0, 1, 0))
	mat.set_shader_parameter(&"view_basis_w", Vector4(0, 0, 0, 1))
	mmi.material_override = mat
	mmi.extra_cull_margin = 16384.0
	return mmi


## The hammerhead's cut at w = 0: its baked pieces placed at rest, sliced (shared/slice_mesh.gd).
func _shark_cut() -> Node3D:
	var L: float = 2.4
	var parts: Array = []
	var grey := Color(0.36, 0.36, 0.32)
	for pc in Shark.PIECES:
		var sc: float = (float(pc[1]) + float(pc[2])) * 0.5
		var origin := Vector4(0.0, 0.0, (0.5 - sc) * L, 0.0)
		var m: Resource = load(Shark.BAKED + "shark_%s_%s.res" % [String(pc[0]), Shark.BAKE_VERSION])
		if m is ArrayTetraMesh4D:
			parts.append([m, Projection.IDENTITY, origin, grey])
		var extra: Dictionary = {"Head": ["hammer", "eyes"], "Chest": ["pectorals"], "Middle": ["dorsal"], "Hips": ["pelvics"], "Tail": ["dorsal2"]}
		for e in extra.get(String(pc[0]), []):
			var em: Resource = load(Shark.BAKED + "shark_%s_%s.res" % [String(e), Shark.BAKE_VERSION])
			if em is ArrayTetraMesh4D:
				parts.append([em, Projection.IDENTITY, origin, Color(0.05, 0.05, 0.05) if e == "eyes" else grey])
	var mi := MeshInstance3D.new()
	mi.mesh = SliceMesh.cut(parts, 0.0)
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	# Countershaded by height, the eyes dark (their vertex colour).
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
	mi.material_override = mat
	return mi


## The turntable: round and round, the animal swimming (or stepping) on the spot.
func _turn(panel: Dictionary, delta: float) -> void:
	var node: Node3D = panel["specimen"]
	if node == null or not is_instance_valid(node):
		return
	panel["angle"] = float(panel["angle"]) + delta * 0.35
	panel["phase"] = float(panel["phase"]) + delta * TAU * 0.9
	var a: float = panel["angle"]
	var d: float = panel["distance"]
	if String(panel["kind"]) == "shark":
		node.position = Vector3(0.0, -0.05, -d)
		node.rotation = Vector3(0.25, a, 0.0)
		return
	var mmi := node as MultiMeshInstance3D
	var mat: ShaderMaterial = mmi.material_override
	# A card's lift: its animal raised that share of the picture's height (round 4: "raise the Showa and
	# the Edible crab displays"; the picture is 2 d tan(16 deg) high at the animal, the studio's fov 32).
	var up: float = float(panel.get("lift", 0.0)) * 2.0 * d * tan(deg_to_rad(16.0))
	mat.set_shader_parameter(&"view_origin", Vector4(0.0, -0.02 + up, -d, 0.0))
	var h := Vector3(sin(a), -0.15, cos(a)).normalized()
	var r := Vector3(cos(a), 0.0, -sin(a))
	var custom: Vector4 = panel["custom"]
	custom.x = panel["phase"]
	var buf := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, h.x, h.y, h.z, 0.0, r.x, r.y, r.z, 0.0])
	var c: Color = panel["colour"]
	buf.append_array([c.r, c.g, c.b, c.a, custom.x, custom.y, custom.z, custom.w])
	RenderingServer.multimesh_set_buffer(mmi.multimesh.get_rid(), buf)


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
