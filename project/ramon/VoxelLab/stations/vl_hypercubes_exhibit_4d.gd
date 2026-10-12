extends "res://ramon/VoxelLab/stations/vl_exhibit_4d.gd"

## The Voxel Lab: overlapping geometry. A few 4D cubes of one material, each turned at random and a little
## off the middle, written into an empty world by the engine's parallelogram edit (no generator makes them).
## Between visits all of them stand there. At its ring the choice sits you at its bench (room/vl_bench_4d.gd,
## which treats an exhibit with add_next() as a stepper): the world is emptied, each press puts the next one
## back, and after the last the bench lets you go. Standing up before then makes it whole again. One
## material, so where they overlap they fuse.
##
## NO class_name (engine_gotchas.md).

const VOXEL := 0.06
## A cube's side, voxels.
const SIDE := 10.0
const COUNT := 5
## How far a cube's middle may be from the specimen's, as a fraction of the side, per axis.
const OFFSET := 0.5
const MATERIAL := 2
const COLOUR := Color(0.32, 0.62, 0.86)
## The words beside the specimen while you sit at it.
const SIDE_TEXT := "Dual contouring is capable of producing both sharp and smooth geometric features in arbitrary arrangements, up to the limit of the resolution of the voxel grid. All this remains editable as expected for voxel-based scenes. We are aware of further improvements to the algorithm which, though we have not yet had time to implement them, we expect to improve the meshing beyond what is shown here."

var _recipe: Dictionary = {}
## Each cube: {basis, position, inverse} (the edit's transform, voxels).
var _cubes: Array = []
## How many cubes the world holds since the bench emptied it; -1 while it is whole (all of them).
var _step: int = -1


func _init() -> void:
	code = "HC-03"
	title = "Overlapping geometry"
	display_scale = 1.0
	spare_on = false


func recipe() -> Dictionary:
	if not _recipe.is_empty():
		return _recipe
	var half: Vector4 = Vector4.ONE * (SIDE * (1.0 + OFFSET) + 1.0)
	var c: Vector4 = Recipe.chunk_middle() + Recipe.JITTER
	var rng := RandomNumberGenerator.new()
	rng.seed = 4096
	_cubes = []
	for i in COUNT:
		var b: Projection = _random_rotation(rng)
		b = Projection(b.x * SIDE, b.y * SIDE, b.z * SIDE, b.w * SIDE)
		var mid: Vector4 = c + Vector4(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * SIDE * OFFSET
		var pos: Vector4 = mid - b * (Vector4.ONE * 0.5)
		_cubes.append({"basis": b, "position": pos, "inverse": b.inverse()})
	var r: Dictionary = {"kind": "hypercubes", "voxel": VOXEL, "center": c, "half": half, "crust": 0.0, "planes": [], "vein": {},
		"cavity": {}, "column": {}, "empty": true, "fill_edits": [], "colors": {MATERIAL: COLOUR}, "voxel_count": 0}
	r["pre_cuts"] = [_cut(range(COUNT), MATERIAL, "All of them")]
	_recipe = r
	return r


## A rotation of 4D at random: four Gaussian vectors made orthonormal, the last turned round if they make a
## reflection.
static func _random_rotation(rng: RandomNumberGenerator) -> Projection:
	var cols: Array[Vector4] = []
	for i in 4:
		var v := Vector4(rng.randfn(), rng.randfn(), rng.randfn(), rng.randfn())
		for u in cols:
			v -= u * u.dot(v)
		cols.append(v.normalized())
	var b := Projection(cols[0], cols[1], cols[2], cols[3])
	if b.determinant() < 0.0:
		b.w = -b.w
	return b


## A cut writing cubes `which` (indices) in `fill`, as vl_cut.gd's shape.
func _cut(which: Array, fill: int, label: String) -> Dictionary:
	var edits: Array = []
	var lo := Vector4.INF
	var hi := -Vector4.INF
	var mine: Array = []
	for i in which:
		var cube: Dictionary = _cubes[i]
		mine.append(cube)
		edits.append(["ParallelogramVoxelEdit4D", {"basis": cube["basis"], "position": cube["position"], "fill_material": fill}])
		for k in 16:
			var corner: Vector4 = (cube["position"] as Vector4) + (cube["basis"] as Projection) * Vector4(k & 1, (k >> 1) & 1, (k >> 2) & 1, (k >> 3) & 1)
			lo = lo.min(corner)
			hi = hi.max(corner)
	return {"kind": "block", "fill": fill, "label": label, "edits": edits, "voxels": int(pow(SIDE, 4.0)) * which.size(),
		"has": func(p: Vector4) -> bool:
			for cube in mine:
				var u: Vector4 = (cube["inverse"] as Projection) * (p - (cube["position"] as Vector4))
				if u.x >= 0.0 and u.x <= 1.0 and u.y >= 0.0 and u.y <= 1.0 and u.z >= 0.0 and u.z <= 1.0 and u.w >= 0.0 and u.w <= 1.0:
					return true
			return false,
		"aabb": [lo, hi]}


## Standing on the deck: its lowest corner just over it, not its box's floor.
func _rest_position(r: Dictionary) -> Vector4:
	var low: float = INF
	for cube in _cubes:
		for k in 16:
			low = minf(low, ((cube["position"] as Vector4) + (cube["basis"] as Projection) * Vector4(k & 1, (k >> 1) & 1, (k >> 2) & 1, (k >> 3) & 1)).y)
	return Vector4(0, ((r["center"] as Vector4).y - low) * VOXEL * display_scale + 0.01, 0, 0)


# -- at the bench ---------------------------------------------------------------------------------------------

## Sat down at: the world emptied.
func begin() -> void:
	if specimen == null or not bool(specimen.call("is_ready")):
		return
	specimen.call("apply_cut", _cut(range(COUNT), Recipe.AIR, "Empty"))
	_step = 0


## The bench's button: the next cube. Returns whether one went in.
func add_next() -> bool:
	if _step < 0 or _step >= COUNT or specimen == null or not bool(specimen.call("is_ready")):
		return false
	specimen.call("apply_cut", _cut([_step], MATERIAL, "Hypercube %d" % (_step + 1)))
	_step += 1
	return true


## All of them back in place.
func finished() -> bool:
	return _step >= COUNT


## Stood up from: whole again (the cuts missing if you stood up early).
func end() -> void:
	if _step >= 0 and _step < COUNT and specimen != null and bool(specimen.call("is_ready")):
		specimen.call("apply_cut", _cut(range(_step, COUNT), MATERIAL, "The rest"))
	_step = -1


func shown_count() -> int:
	return COUNT if _step < 0 else _step


## For the bench's cards: the step, its line, how many are in, and the words for the side.
func overlay_info() -> Dictionary:
	var name_: String = "AN EMPTY WORLD" if _step <= 0 else "HYPERCUBE %d OF %d" % [_step, COUNT]
	var line: String = "%d hypercubes to come, each turned its own way in 4D." % COUNT if _step <= 0 else \
		("All of them: one surface, where they overlap." if _step >= COUNT else "Written into the voxels by one edit.")
	return {"name": name_, "line": line, "count": shown_count(), "of": COUNT, "colour": COLOUR, "title": title.to_upper(), "text": SIDE_TEXT}


# -- the words ------------------------------------------------------------------------------------------------

func band_line() -> String:
	var n: Dictionary = numbers()
	return "%s  ·  %d OF %d IN PLACE  ·  %s TETRAHEDRA" % [title.to_upper(), shown_count(), COUNT, String(n["tets"])]


func card() -> Dictionary:
	var n: Dictionary = numbers()
	return {
		"short": "Hypercubes turned every which way in 4D, written into the voxels one edit at a time.",
		"code": code, "title": title, "kicker": "EDITS, NOT A GENERATOR",
		"text": "No generator makes a turned hypercube, so each is an edit: the engine fills the voxels inside a 4D parallelotope. All one material, so where they overlap they fuse into one surface.",
		"rows": [["Hypercubes", "%d of %d" % [shown_count(), COUNT]], ["Voxels of", String(n["voxel"])], ["Tetrahedra", String(n["tets"])]],
		"tier": "MEASURED LIVE", "key": "",
	}


func face() -> Array:
	var n: Dictionary = numbers()
	return [["Hypercubes", "%d of %d" % [shown_count(), COUNT]], ["Voxels of", String(n["voxel"])], ["Tetrahedra", String(n["tets"])]]
