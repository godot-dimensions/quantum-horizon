extends "res://ramon/VoxelLab/stations/vl_exhibit_4d.gd"

## The Voxel Lab's gallery: the engine's own test cases (Ramon, 6 Oct: "combine the voxel mining with a
## testcase of [Andrew's] work featuring on different pedestals"). Andrew (4Denthusiast) wrote the
## engine's voxels and their test scenes (project/sandbox/voxel_test.tscn); these are his scene as a
## specimen, credited, cut live, and the cost of detail on three small pedestals.
##
##   terrain   his whole scene in a 4D box on a big low pedestal: fractal terrain in bands of stone,
##             dirt and grass, his caves through it, his sea below sea level. Three looks (Ramon, 8 Oct:
##             "a toggle between a lava field, maybe a sandy field like Nevada desert, and this green
##             one"): next_biome() swaps the palette, no remeshing.
##   layer     one of his layers alone, on a small square pedestal like the hall's shelf (metadata
##             "layer"): "land" (fractal noise in bands), "caves" (tunnels where three noise fields
##             meet zero, in stone), "clipped" (the land with the caves carved out of it). In that order
##             they are how the big one is made (Ramon, 9 Oct: "rethink what you show and how"; the
##             resolution ladder that stood here said nothing about this room).
##
## Which one is set on the showcase's node as metadata "case". The 24-cell left the gallery on 9 Oct
## ("why would it be next to something this complex?"). The terrain stands square on a square pedestal
## and does not turn (Ramon: "the big cake cutout might be better served on a square pedestal").
##
## NO class_name (engine_gotchas.md).

const SeaPanel := preload("res://ramon/VoxelLab/field/vl_sea_panel.gd")

const LAYERS := ["land", "caves", "clipped"]
const LAYER_NAMES := ["The land", "The caves", "Land and caves"]
## The three looks, by material: grass (0), dirt (1), stone (2), the sea (3).
const BIOMES := [
	# The green land's water: this teal until the sea panel has a colour saved; _apply_biome and the
	# recipe paint it in SeaPanel.voxel_tint(), the open world's sea colour (Ramon, 9 Oct: "the blue of
	# the water of the voxel surface will have to match ... the big ocean").
	#
	# Each its own ground too (round 3, Ramon: "the lava landscape could have sharper, more jagged, spiky
	# terrain ... other landscape types should have their own recognizable geometric characteristics"):
	# "shape" is the land generator's noise (Recipe.terrain options), in the gallery's voxels. Green is
	# our generator as it stands, rolling hills; the desert broad and smooth, low dunes (few octaves,
	# little roughness, wide); the lava rough and fine, high and spiky (many octaves, persistence near 1).
	{"name": "Green", "colors": {0: Color(0.40, 0.74, 0.22), 1: Color(0.56, 0.32, 0.12), 2: Color(0.34, 0.34, 0.34), 3: Color(0.07, 0.27, 0.34)},
		"shape": {}},
	# Round 6 (#72: "more red overall, closer to a reddish-brown Nevada desert ... remove the white elements ...
	# use darker red tones for rock"): red sand, red-brown dirt, dark red rock, and a red clay pan for its sea.
	{"name": "Desert", "colors": {0: Color(0.70, 0.38, 0.22), 1: Color(0.55, 0.25, 0.14), 2: Color(0.36, 0.14, 0.09), 3: Color(0.62, 0.33, 0.20)},
		"shape": {"octaves": 3, "persistence": 0.4, "horizontal_scale": 6.0, "k": 0.5}},
	# Round 6 (#73: "better lava rock coloration"): black basalt, rusty scoria, darker stone; the lava as before.
	{"name": "Lava", "colors": {0: Color(0.13, 0.115, 0.11), 1: Color(0.27, 0.12, 0.08), 2: Color(0.075, 0.068, 0.068), 3: Color(1.0, 0.40, 0.06)},
		"shape": {"octaves": 6, "persistence": 0.74, "horizontal_scale": 2.0, "vertical_scale": 4.0, "k": 0.5}},
]
## How deep the terrain sits in its pedestal (m): its sea about level with the deck, so you see the
## land, not the side of a box (a box's worth of strata showed from the ring, 9 Oct). Taller than it
## shows, so its hills can rise: half its 2 m less the sea's 12 cm.
##
## ROUND 3'S SQUARE CROP IS GONE (round 4, Ramon: "if maintaining a fixed square footprint creates
## unavoidable problems, revert to the original landscape implementation"). It kept the land to its
## square by throwing away what lay outside and painting the inside faces seen through the cut as its
## wall: wherever the cut met a cave or the edge of what was built that left gaps, and it needed a limit
## on the turn (the hard stop he felt). The renderer has no way to cap a cut solid properly. This is
## round 2's land again, on round 3's larger square pedestal, each look its own ground, R to reset.
const SINK := 0.86

var case: String = "terrain"
var layer: String = "land"
var face_yaw: float = 0.0
var biome: int = 0
var _recipes: Dictionary = {}
var _t: float = 0.0
## How far the exhibit may be turned through W, degrees (the kit's showcase reads it). 0: no limit.
var max_tilt: float = 0.0
## The world is never turned: a drag sweeps its slice through W, its square base still (round 6, #61; the
## kit's showcase reads it). The three layers keep their turn (#62).
var sweep_w: bool = false
## A change of look asked for while the last one was still building: built again when it is done.
var _rebuild_again: bool = false


func _init() -> void:
	display_scale = 1.0
	turn_speed = 0.0


func _ready() -> void:
	var sc: Node = get_parent().get_parent() if get_parent() != null else null
	if sc != null:
		case = String(sc.get_meta("case", "terrain"))
		layer = String(sc.get_meta("layer", "land"))
		face_yaw = deg_to_rad(float(sc.get_meta("face_yaw", 0.0)))
	match case:
		"terrain":
			code = "AN-04"
			title = "The world"
			sweep_w = true
			# No spare: a reset rebuilds in place (a second or two).
			spare_on = false
		_:
			var i: int = maxi(0, LAYERS.find(layer))
			code = "AN-%02d" % (i + 1)
			title = String(LAYER_NAMES[i])
			spare_on = false
	super._ready()
	stand.basis = Basis4D.from_zx(face_yaw)


func recipe() -> Dictionary:
	var key: String = "terrain:%d" % biome if case == "terrain" else "layer_" + layer
	if _recipes.has(key):
		return _recipes[key]
	var r: Dictionary
	if case == "terrain":
		# Wide, at 18 cm, its hills given room: the land, not the box, is what you see. His heights scaled (k),
		# his grass at least two and a half voxels deep (thinner, the dirt under it poked through the green
		# wherever a slope crossed a voxel, 8 Oct). Round 2's land (round 4: round 3's crop undone); each
		# look its own ground (BIOMES "shape", round 3).
		var opts: Dictionary = {"shift": Vector4(16, 0, -8, 0), "k": 0.62, "grass_voxels": 2.6, "sea_m": -0.12}
		opts.merge(BIOMES[biome].get("shape", {}), true)
		# 4 m deep in W (1.6 before), so the sweep has land to go through (round 6, #61).
		r = Recipe.terrain(Vector4(5.6, 2.0, 5.6, 4.0), 0.18, opts)
	elif layer == "caves":
		# His caves at a scale this block can show (at his own the tunnels are further apart than it is
		# wide), a quarter cut away so the tunnels inside show.
		r = Recipe.caves(Vector4(1.5, 1.1, 1.5, 1.1), 0.1, {"octaves": 2, "horizontal_scale": 4.0, "vertical_scale": 4.0, "diameter": 3.6})
		var c: Vector4 = r["center"]
		var h: Vector4 = r["half"]
		r["pre_cuts"] = [Cut.block(c + Vector4(h.x, 0.0, h.z, 0.0), Vector4(h.x, h.y + 3.0, h.z, h.w + 3.0))]
	else:
		var parts: Array = ["land"] if layer == "land" else ["land", "caves"]
		r = Recipe.terrain(Vector4(1.5, 1.1, 1.5, 1.1), 0.1, {"shift": Vector4(16, 0, -8, 0), "k": 0.36, "grass_voxels": 2.2, "parts": parts,
			"cave_octaves": 2, "cave_horizontal_scale": 4.0, "cave_vertical_scale": 4.0, "cave_diameter": 3.6})
	_recipes[key] = r
	return r


func _rest_position(r: Dictionary) -> Vector4:
	var p: Vector4 = super._rest_position(r)
	return p - Vector4(0, SINK, 0, 0) if case == "terrain" else p


## The terrain stands still, square to its square pedestal; a layer sways like the shelf's specimens.
func idle(delta: float) -> void:
	if held or case == "terrain":
		return
	_t += delta
	stand.basis = Basis4D.from_zx(face_yaw + sin(_t * 0.3) * deg_to_rad(20.0))


func face_front(k: float = 1.0) -> void:
	_yaw = lerp_angle(_yaw, 0.0, k)
	stand.basis = Basis4D.from_zx(face_yaw + _yaw)


## The next look of the terrain: green, a Nevada desert, a lava field, each its own ground; built again
## hidden, the old one on show until the new is ready. Returns its name.
func next_biome() -> String:
	if case != "terrain":
		return ""
	biome = (biome + 1) % BIOMES.size()
	if _rebuilding != null:
		_rebuild_again = true
	else:
		reset()
	return String(BIOMES[biome]["name"])


func biome_name() -> String:
	return String(BIOMES[biome]["name"])


func _apply_biome() -> void:
	var colors: Dictionary = BIOMES[biome]["colors"]
	if biome == 0:
		# The green land's water in the open world's sea colour, as the sea panel has it saved.
		colors = colors.duplicate()
		colors[3] = SeaPanel.voxel_tint()
	for s in [specimen, spare, _rebuilding]:
		if s != null and is_instance_valid(s) and s.get("world") != null:
			s.get("world").set("material_palette", Recipe.palette(s.get("recipe"), colors))


func _after_make(s: Node4D) -> void:
	if case == "terrain":
		s.connect("built", func(_st: Dictionary) -> void:
			_apply_biome()
			if _rebuild_again:
				_rebuild_again = false
				reset.call_deferred(), CONNECT_ONE_SHOT)


# -- words -----------------------------------------------------------------------------------------------

func numbers() -> Dictionary:
	var n: Dictionary = super.numbers()
	if not bool(recipe().get("mirror", true)):
		n["voxels"] = "noise"
	return n


func band_line() -> String:
	var n: Dictionary = numbers()
	if case == "terrain":
		return "OUR WORLD GENERATOR  ·  TERRAIN, CAVES, SEA  ·  %s TETRAHEDRA" % String(n["tets"])
	return "%s  ·  ONE LAYER OF OUR GENERATOR  ·  %s TETRAHEDRA" % [title.to_upper(), String(n["tets"])]


## Three numbers for a floating panel.
func face() -> Array:
	var n: Dictionary = numbers()
	return [["Look", biome_name()], ["Chunk meshes", String(n["chunks"])], ["Tetrahedra", String(n["tets"])]]


func card() -> Dictionary:
	var n: Dictionary = numbers()
	if case == "terrain":
		return {"short": "Our world generator in a 4D box: fractal terrain, caves and a sea, built by the engine as you watch.", "code": code, "title": title,
			"kicker": "OUR WORLD GENERATOR",
			"text": "Land, caves and a sea, cut out of an endless 4D world. Slide through W and every slice is a new coastline. Cut it: the engine remeshes it live.",
			"method": "A sea plane under a fractal-noise landscape, clipped against its caves; here in a box at 18 cm voxels. Adapted from the work of Andrew (4Denthusiast).",
			"rows": [["Look", biome_name()], ["Chunk meshes", String(n["chunks"])], ["Tetrahedra", "%s, %s" % [String(n["tets"]), String(n["mb"])]]],
			"tier": "OUR WORLD GENERATOR", "key": ""}
	var words := {
		"land": "Fractal noise, summed over scales, decides how high the ground is; bands below its surface make grass, dirt and stone. One rule, run in 4D.",
		"caves": "Three noise fields, and a tunnel wherever all three are near zero at once. In 4D that leaves winding tubes, cut open here so you can see in.",
		"clipped": "The land, with the caves taken out of it: one generator clipped by another. Add a sea below a plane and it is the world on the big pedestal.",
	}
	var step := {"land": "LAYER 1 OF 3", "caves": "LAYER 2 OF 3", "clipped": "1 AND 2, CLIPPED"}
	return {"short": String(words.get(layer, "")), "code": code, "title": title, "kicker": String(step.get(layer, "")),
		"text": String(words.get(layer, "")),
		"rows": [["Voxels of", String(n["voxel"])], ["Chunk meshes", String(n["chunks"])], ["Tetrahedra", "%s, %s" % [String(n["tets"]), String(n["mb"])]]],
		"tier": "OUR GENERATORS", "key": ""}
