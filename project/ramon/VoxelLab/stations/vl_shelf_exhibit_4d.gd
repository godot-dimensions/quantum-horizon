extends "res://ramon/VoxelLab/stations/vl_exhibit_4d.gd"

## The Voxel Lab's shelf: three small specimens on the right as you come in, each one idea, so the room
## teaches even if you skip everything else. Round 3 (Ramon, 9 Oct: "reconsider what each specimen
## demonstrates so the three showcases feel more interesting and distinct"; "communicate more through
## visuals and less through lengthy explanations", after the gallery's how-a-world-is-made pedestals):
##
##   voxels  A: what the world is made of. Voxels of 14 cm, nearly twice the shelf's, a quarter cut away, their grid
##           drawn: one surface runs through the cubes it crosses
##   inside  B: cut into ground and the inside shows. A piece of our landscape (grass, earth, stone, as
##           in the gallery), a 4D ball cut out of its top: the layers go on round the bite
##   hidden  C: what is not in your slice. A block that looks whole; slide ana along W and a room lined
##           with amethyst opens to the front
##
## A label on the wall above each says it in a few words and a diagram (kit_wall_text_4d.gd "label").
## Which one is set on the showcase's node as metadata "shelf_kind". It sways gently round the side
## that faces the walkway, set as "face_yaw" (degrees), so its cut side faces you.
##
## NO class_name (engine_gotchas.md).

const GridView := preload("res://ramon/VoxelLab/room/vl_grid_view.gd")

const SIZE := Vector4(1.0, 0.8, 0.72, 0.8)
const VOXEL := 0.08

var kind: String = "voxels"
var face_yaw: float = 0.0
var _recipe: Dictionary = {}
var _t: float = 0.0


func _init() -> void:
	spare_on = false
	display_scale = 1.0
	turn_speed = 0.0


func _ready() -> void:
	var sc: Node = get_parent().get_parent() if get_parent() != null else null
	if sc != null:
		kind = String(sc.get_meta("shelf_kind", "voxels"))
		face_yaw = deg_to_rad(float(sc.get_meta("face_yaw", 0.0)))
	match kind:
		"voxels":
			code = "SH-A"
			title = "Voxels"
		"inside":
			code = "SH-B"
			title = "Inside"
		_:
			code = "SH-C"
			title = "Hidden in W"
	super._ready()
	stand.basis = Basis4D.from_zx(face_yaw)


func recipe() -> Dictionary:
	if not _recipe.is_empty():
		return _recipe
	var r: Dictionary
	var cuts: Array = []
	match kind:
		"voxels":
			# Twice the block's voxel, so each one shows; a quarter cut away, top to bottom and through
			# all of W, so the crust and the core read.
			var v: float = 0.14
			r = Recipe.block(SIZE, v, {"crust_m": v, "chamfer_m": v, "vein": false, "cavity": false})
			var c: Vector4 = r["center"]
			var h: Vector4 = r["half"]
			cuts.append(Cut.block(c + Vector4(h.x, 0.0, h.z, 0.0), Vector4(h.x, h.y + 3.0, h.z, h.w + 3.0)))
		"inside":
			# A piece of our landscape, its ground near the top, a 4D ball cut out of its top front.
			r = Recipe.terrain(SIZE, VOXEL * 0.75, {"parts": ["land"], "ground_m": 0.16, "k": 0.5, "grass_voxels": 2.0})
			var c2: Vector4 = r["center"]
			var h2: Vector4 = r["half"]
			cuts.append(Cut.ball(c2 + Vector4(0.0, h2.y * 0.7, h2.z * 0.55, 0.0), 0.34 / (VOXEL * 0.75)))
		_:
			# The cavity 20 cm ana of your slice (18 cm round, so none of it reaches W 0), a window cut to it from the front at its own W only.
			var opts: Dictionary = {"crust_m": 0.08, "chamfer_m": 0.08, "vein": false, "cavity": true,
				"cavity_at_m": Vector4(0.0, 0.02, 0.0, 0.2), "cavity_m": 0.18, "lining_m": 0.06}
			r = Recipe.block(SIZE, VOXEL, opts)
			var c3: Vector4 = r["center"]
			var h3: Vector4 = r["half"]
			var cav: Vector4 = (r["cavity"] as Dictionary)["center"]
			cuts.append(Cut.block(Vector4(cav.x, cav.y, c3.z + h3.z, cav.w), Vector4(0.15, 0.13, 0.3, 0.08) / VOXEL))
	r["pre_cuts"] = cuts
	r["voxel_count"] = Recipe.voxel_count(r)
	_recipe = r
	return r


## A: its grid drawn once it is built (the grid view, vl_grid_view.gd).
func _after_make(s: Node4D) -> void:
	if kind == "voxels":
		s.connect("built", func(_st: Dictionary) -> void: GridView.apply(s, true), CONNECT_ONE_SHOT)


## A slow sway round the side that faces the walkway, never a full turn: the cut side stays toward you.
func idle(delta: float) -> void:
	_t += delta
	stand.basis = Basis4D.from_zx(face_yaw + sin(_t * 0.35) * deg_to_rad(22.0))


func band_line() -> String:
	var n: Dictionary = numbers()
	return "%s  ·  %s  ·  %s VOXELS OF %s" % [title.to_upper(), String({"voxels": "WHAT IT IS MADE OF", "inside": "CUT INTO GROUND",
		"hidden": "NOT IN YOUR SLICE"}.get(kind, "")), String(n["voxels"]), String(n["voxel"]).to_upper()]


## Short, after the label over it (round 3: "shorten the accompanying text descriptions").
func card() -> Dictionary:
	var n: Dictionary = numbers()
	var shows := {"voxels": "Every voxel a tiny 4D cube. One smooth surface runs through the ones it crosses.",
		"inside": "A piece of our landscape, a 4D ball cut out of it. The layers go on round the cut, in W too.",
		"hidden": "Whole, in your slice. Slide ana along W: a room lined with amethyst opens to the front."}
	return {
		"short": shows.get(kind, ""), "code": code, "title": title, "kicker": {"voxels": "WHAT IT IS MADE OF", "inside": "CUT INTO GROUND",
			"hidden": "NOT IN YOUR SLICE"}.get(kind, ""),
		"method": "The engine's own voxels, cut while it loads, meshed by dual contouring in C++.",
		"shows": shows.get(kind, ""),
		"limits": "Cut at load, not in front of you: the bench in front of the block is where you cut.",
		"rows": [["Voxels", "%s of %s" % [String(n["voxels"]), String(n["voxel"])]], ["Tetrahedra", String(n["tets"])]],
		"tier": "CUT AT LOAD", "key": "",
	}
