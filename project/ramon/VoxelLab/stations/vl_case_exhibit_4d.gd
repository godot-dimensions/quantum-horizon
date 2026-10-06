extends "res://ramon/VoxelLab/stations/vl_exhibit_4d.gd"

## The Voxel Lab's gallery: the engine's own test cases on pedestals (Ramon, 6 Oct: "combine the voxel
## mining with a testcase of [Andrew's] work featuring on different pedestals"). Andrew (4Denthusiast)
## wrote the engine's voxels and their test scenes (project/sandbox/voxel_test.tscn,
## voxel_24cell_test.tscn); these are those scenes as specimens, credited, cut live.
##
##   terrain   his landscape cut out as a 4D box: fractal terrain in bands of stone, dirt and grass,
##             his caves through it, his ocean below sea level. A core sample of his world.
##   caves     his caves alone, in a block of stone: tunnels where three noise fields meet zero.
##   24cell    his fringe test: a 24-cell whose corners sit on grid points (warm: the mesher must choose
##             between several normals at once and frays its edges), beside one laid off the grid (blue).
##   ladder    the same block at 20, 10 and 5 cm voxels: E times one cut in each, so the cost of detail
##             can be read off (twice the detail, sixteen times the voxels).
##
## Which one is set on the showcase's node as metadata "case".
##
## NO class_name (engine_gotchas.md).

const RUNGS := [0.2, 0.1, 0.05]

var case: String = "terrain"
var extras: Array = []
var _recipes: Dictionary = {}
## The ladder's measured cuts: [{voxel, latency_ms, worst_ms, chunks, voxels, tets}, ...].
var ladder_results: Array = []
var _ladder_pending: Dictionary = {}


func _init() -> void:
	display_scale = 1.0
	turn_speed = 4.0


func _ready() -> void:
	var sc: Node = get_parent().get_parent() if get_parent() != null else null
	if sc != null:
		case = String(sc.get_meta("case", "terrain"))
	match case:
		"terrain":
			code = "AN-01"
			title = "The terrain sample"
			# No spare: at over 300 MB a specimen, a reset rebuilds in place (a second or two).
			spare_on = false
		"caves":
			code = "AN-02"
			title = "The caves"
			spare_on = false
		"24cell":
			code = "AN-03"
			title = "The 24-cell"
			spare_on = false
			turn_speed = 6.0
		_:
			code = "LD-04"
			title = "The resolution ladder"
			spare_on = false
			turn_speed = 0.0
	super._ready()
	match case:
		"24cell":
			# The clean one is the specimen; the fringed one beside it.
			specimen.position += Vector4(0.95, 0, 0, 0)
			var frayed: Node4D = _extra("Frayed", Recipe.cell24(0.8, 0.1, true))
			frayed.position = _rest_position(frayed.get("recipe")) + Vector4(-0.95, 0, 0, 0)
		"ladder":
			specimen.position += Vector4(0.0, 0, 0, 0)
			for i in [0, 2]:
				var r: Dictionary = _rung(i)
				var s: Node4D = _extra("Rung%d" % i, r)
				s.position = _rest_position(r) + Vector4(-1.05 if i == 0 else 1.05, 0, 0, 0)


func recipe() -> Dictionary:
	if _recipes.has(case):
		return _recipes[case]
	var r: Dictionary
	match case:
		"terrain":
			r = Recipe.terrain(Vector4(2.4, 1.6, 2.4, 1.6), 0.12, {"shift": Vector4(16, 0, -8, 0)})
		"caves":
			# Finer noise than his landscape's caves (2 octaves on a 4-voxel scale): at his own scale the
			# tunnels are further apart than this block is wide, and it showed none (6 Oct).
			r = Recipe.caves(Vector4(1.8, 1.4, 1.6, 1.4), 0.1, {"octaves": 2, "horizontal_scale": 4.0, "vertical_scale": 4.0, "diameter": 3.6})
			# A quarter cut away, as the shelf's section: the tunnels run inside, and a whole block of
			# stone shows none of them (the first gallery, 6 Oct).
			var c: Vector4 = r["center"]
			var h: Vector4 = r["half"]
			r["pre_cuts"] = [Cut.block(c + Vector4(h.x, 0.0, h.z, 0.0), Vector4(h.x, h.y + 3.0, h.z, h.w + 3.0))]
		"24cell":
			r = Recipe.cell24(0.8, 0.1, false)
		_:
			r = _rung(1)
	if bool(r.get("mirror", true)):
		r["voxel_count"] = Recipe.voxel_count(r)
	_recipes[case] = r
	return r


func _rung(i: int) -> Dictionary:
	var key: String = "rung%d" % i
	if not _recipes.has(key):
		var r: Dictionary = Recipe.plain(Vector4(0.8, 0.8, 0.8, 0.8), float(RUNGS[i]), {"crust_m": maxf(0.06, float(RUNGS[i]) * 1.2)})
		r["voxel_count"] = Recipe.voxel_count(r, 1 if i == 0 else 2)
		_recipes[key] = r
	return _recipes[key]


## A second (or third) specimen on the same stand, standing beside the first.
func _extra(nm: String, r: Dictionary) -> Node4D:
	var s := Node4D.new()
	s.name = nm
	s.set_script(Specimen)
	stand.add_child(s)
	s.call("build", r)
	extras.append(s)
	return s


func is_ready() -> bool:
	if not super.is_ready():
		return false
	for e in extras:
		if not bool(e.call("is_ready")):
			return false
	return true


func idle(delta: float) -> void:
	if case == "ladder":
		return
	super.idle(delta)


# -- the ladder ------------------------------------------------------------------------------------------

func action_label() -> String:
	return "Time a cut on each" if case == "ladder" else ""


## E at the ladder: one ball cut, the same size in metres, into each rung at once; their records come
## back as each shows.
func action() -> String:
	if case != "ladder" or not is_ready():
		return ""
	ladder_results = []
	_ladder_pending = {}
	var rungs: Array = [extras[0], specimen, extras[1]]
	for s in rungs:
		var r: Dictionary = s.get("recipe")
		var v: float = float(r["voxel"])
		var c: Vector4 = r["center"]
		var h: Vector4 = r["half"]
		var cut: Dictionary = Cut.ball(c + Vector4(0.1 / v, 0.12 / v, h.z, 0.0), 0.22 / v)
		cut["label"] = "Ladder %.0f cm" % (v * 100.0)
		if not s.is_connected("cut_done", _on_ladder_cut):
			s.connect("cut_done", _on_ladder_cut.bind(s))
		_ladder_pending[s] = true
		s.call("apply_cut", cut)
	return "One cut in each: 20, 10 and 5 cm voxels"


func _on_ladder_cut(rec: Dictionary, s: Node) -> void:
	if not _ladder_pending.has(s):
		return
	_ladder_pending.erase(s)
	var r: Dictionary = s.get("recipe")
	ladder_results.append({"voxel": float(r["voxel"]), "latency_ms": float(rec.get("latency_ms", 0.0)), "worst_ms": float(rec.get("worst_ms", 0.0)),
		"chunks": int(rec.get("chunks", 0)), "voxels": int(rec.get("voxels", 0)), "tets": int(rec.get("tets", 0)), "solid": int(r.get("voxel_count", 0))})
	ladder_results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["voxel"]) > float(b["voxel"]))


func reset() -> void:
	super.reset()
	for e in extras:
		e.call("build", e.get("recipe"))
	ladder_results = []


# -- words -----------------------------------------------------------------------------------------------

func numbers() -> Dictionary:
	var n: Dictionary = super.numbers()
	if not bool(recipe().get("mirror", true)):
		n["voxels"] = "noise"
	return n


func band_line() -> String:
	var n: Dictionary = numbers()
	match case:
		"terrain":
			return "FROM ANDREW'S TEST SCENE  ·  TERRAIN, CAVES, OCEAN  ·  %s TETRAHEDRA" % String(n["tets"])
		"caves":
			return "FROM ANDREW'S TEST SCENE  ·  4D CAVES IN STONE  ·  %s TETRAHEDRA" % String(n["tets"])
		"24cell":
			return "ANDREW'S FRINGE TEST  ·  ON THE GRID, WARM  ·  OFF IT, BLUE"
	var parts: PackedStringArray = []
	for res in ladder_results:
		parts.append("%.0f CM %.0f MS" % [float(res["voxel"]) * 100.0, float(res["latency_ms"])])
	return "THE SAME BLOCK AT 20, 10 AND 5 CM  ·  " + ("  ·  ".join(parts) if not parts.is_empty() else "E TIMES A CUT IN EACH")


func live() -> Array:
	var out: Array = []
	for res in ladder_results:
		out.append(["%.0f cm voxels" % (float(res["voxel"]) * 100.0), "%s voxels, cut shown after %.0f ms, worst frame %.0f ms, %d chunks" % [
			thousands(int(res["solid"])), float(res["latency_ms"]), float(res["worst_ms"]), int(res["chunks"])]])
	return out


func card() -> Dictionary:
	var n: Dictionary = numbers()
	var rows: Array = [["Tetrahedra", "%s, %s" % [String(n["tets"]), String(n["mb"])]], ["Chunk meshes", String(n["chunks"])]]
	match case:
		"terrain":
			return {"short": "Andrew's landscape, cut out as a 4D box: terrain in bands, caves, an ocean.", "code": code, "title": title,
				"kicker": "FROM THE ENGINE'S TEST SCENES",
				"method": "His own composition from project/sandbox/voxel_test.tscn: an ocean plane under a fractal-noise landscape (bands of stone, dirt and grass, their borders bent by 4D noise), clipped against his caves; here inside a box, at 10 cm voxels, his heights scaled to fit.",
				"shows": "Strata and caves that change as you slide through W: the noise is four-dimensional, so every slice is a different coastline.",
				"limits": "Built from noise in C++ that GDScript cannot read back, so the bench aims through the engine's own meshes, and its cuts count no voxels.",
				"rows": rows, "tier": "FROM 4DENTHUSIAST'S TEST SCENE", "key": ""}
		"caves":
			return {"short": "Andrew's caves on their own: winding 4D tunnels in a block of stone.", "code": code, "title": title,
				"kicker": "FROM THE ENGINE'S TEST SCENES",
				"method": "His cave generator: tunnels where three independent noise fields are all near zero at once. A function from 4D to three values is zero on a set of dimension one, so the caves are connected, winding tubes.",
				"shows": "Tunnels that open and close as you slide through W, the way a tube in 4D does.",
				"limits": "Noise in C++: aimed through the meshes, no voxel counts.", "rows": rows, "tier": "FROM 4DENTHUSIAST'S TEST SCENE", "key": ""}
		"24cell":
			return {"short": "Andrew's fringe test: a surface through grid points frays.", "code": code, "title": title,
				"kicker": "A KNOWN LIMIT, FROM THE ENGINE'S TEST SCENES",
				"method": "A 24-cell (the 4D solid bounded by 24 octahedra) from 24 planes. Warm: its middle on a whole voxel and its corners on grid points. Blue: the same, laid a third of a voxel off the grid.",
				"shows": "Where edges run through grid points the mesher has to pick one of several normals, and picks badly: spurious fringes. Off the grid, the same shape meshes clean.",
				"limits": "His scene note: 'a case where the current voxel meshing algorithm is known to behave poorly'. This room lays every specimen off the grid for that reason.",
				"rows": rows, "tier": "A KNOWN LIMIT", "key": ""}
	var lr: Array = []
	for res in ladder_results:
		lr.append(["%.0f cm" % (float(res["voxel"]) * 100.0), "%s voxels: shown after %.0f ms, worst frame %.0f ms" % [thousands(int(res["solid"])), float(res["latency_ms"]), float(res["worst_ms"])]])
	return {"short": "Twice the detail is sixteen times the voxels.", "code": code, "title": title, "kicker": "THE COST OF DETAIL",
		"method": "The same crust-over-core block at 20, 10 and 5 cm voxels. E cuts the same 4D ball, 22 cm round, into each at once and times it.",
		"shows": "Detail in 4D costs the fourth power of the resolution: halve the voxel and a block holds sixteen times as many.",
		"limits": "Measured on this machine, this run.", "rows": lr if not lr.is_empty() else [["E", "time a cut on each"]], "tier": "MEASURED LIVE", "key": action_label()}
