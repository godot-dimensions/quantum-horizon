extends "res://ramon/VoxelLab/stations/vl_exhibit_4d.gd"

## The Voxel Lab's shelf: three small specimens cut before you arrive, on the right as you come in, so
## the room teaches even if you skip everything else. Museums explain a specimen by its sections; these
## are the block's three sections, at 8 cm voxels:
##
##   section   a quarter cut away, top to bottom and right through W: the crust, the core and the
##             tilted vein read like the layers of a cutaway model
##   tunnels   two tunnels drilled through, crossing; you can see through both
##   cavity    the amethyst cavity opened from the front (here it sits in your slice, not ana)
##
## Which one is set on the showcase's node as metadata "shelf_kind" (the showcase builds its exhibit
## from a script and passes nothing else). It sways gently round the side that faces the walkway, set
## as "face_yaw" (degrees), so the cut side always faces you.
##
## NO class_name (engine_gotchas.md).

const SIZE := Vector4(1.0, 0.8, 0.72, 0.8)
const VOXEL := 0.08

var kind: String = "section"
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
		kind = String(sc.get_meta("shelf_kind", "section"))
		face_yaw = deg_to_rad(float(sc.get_meta("face_yaw", 0.0)))
	match kind:
		"section":
			code = "SH-A"
			title = "A half section"
		"tunnels":
			code = "SH-B"
			title = "Two tunnels"
		_:
			code = "SH-C"
			title = "The cavity, opened"
	super._ready()
	stand.basis = Basis4D.from_zx(face_yaw)


func recipe() -> Dictionary:
	if not _recipe.is_empty():
		return _recipe
	var opts: Dictionary = {"crust_m": 0.08, "chamfer_m": 0.08, "vein_m": 0.07, "vein_offset_m": -0.08,
		"cavity": kind == "cavity", "cavity_at_m": Vector4(0.05, 0.0, 0.0, 0.0), "cavity_m": 0.2, "lining_m": 0.06}
	var r: Dictionary = Recipe.block(SIZE, VOXEL, opts)
	var c: Vector4 = r["center"]
	var h: Vector4 = r["half"]
	var cuts: Array = []
	match kind:
		"section":
			# The front-right quarter, top to bottom and through all of W.
			cuts.append(Cut.block(c + Vector4(h.x, 0.0, h.z, 0.0), Vector4(h.x, h.y + 3.0, h.z, h.w + 3.0)))
		"tunnels":
			cuts.append(Cut.drill(c + Vector4(-0.18, 0.08, 0.5, 0.0) / VOXEL, Vector4(0, 0, -1, 0), 0.1 / VOXEL, 1.0 / VOXEL))
			cuts.append(Cut.drill(c + Vector4(0.62, -0.14, 0.04, 0.0) / VOXEL, Vector4(-1, 0, 0, 0), 0.09 / VOXEL, 1.24 / VOXEL))
		_:
			var cav: Vector4 = (r["cavity"] as Dictionary)["center"]
			cuts.append(Cut.block(Vector4(cav.x, cav.y, c.z + h.z, cav.w), Vector4(0.17, 0.15, 0.3, 0.12) / VOXEL))
	r["pre_cuts"] = cuts
	r["voxel_count"] = Recipe.voxel_count(r)
	_recipe = r
	return r


## A slow sway round the side that faces the walkway, never a full turn: the cut side stays toward you.
func idle(delta: float) -> void:
	_t += delta
	stand.basis = Basis4D.from_zx(face_yaw + sin(_t * 0.35) * deg_to_rad(22.0))


func band_line() -> String:
	var n: Dictionary = numbers()
	return "%s  ·  CUT BEFORE YOU CAME  ·  %s VOXELS OF %s" % [title.to_upper(), String(n["voxels"]), String(n["voxel"]).to_upper()]


func card() -> Dictionary:
	var n: Dictionary = numbers()
	var shows := {"section": "Inside the block: the crust, the orange core, and a vein tilted into W, so it sits a little differently in every slice.",
		"tunnels": "Two tunnels crossing. Each is a tube in 4D: slide through W and both close.",
		"cavity": "The cavity, opened: a hollow lined with amethyst. In the block on the pedestal it sits ana of your slice."}
	return {
		"short": shows.get(kind, ""), "code": code, "title": title, "kicker": "A SECTION, CUT AT LOAD",
		"method": "The same recipe as the block, smaller and at 8 cm voxels, with its cuts made while it loads: the engine's edits (boxes and 4D balls of air), meshed by dual contouring in C++.",
		"shows": shows.get(kind, ""),
		"limits": "Made at load: it is not cut in front of you. The bench in front of the block is where you cut.",
		"rows": [["Voxels", "%s of %s" % [String(n["voxels"]), String(n["voxel"])]], ["Tetrahedra", "%s, %s" % [String(n["tets"]), String(n["mb"])]]],
		"tier": "CUT AT LOAD", "key": "",
	}
