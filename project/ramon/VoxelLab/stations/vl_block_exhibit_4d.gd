extends "res://ramon/VoxelLab/stations/vl_exhibit_4d.gd"

## The Voxel Lab's hero: a block of 4D rock (2.9 x 2.2 x 1.9 x 2.2 m at 12 cm voxels, shown at its
## real size, so every number in its story is what you see; at 10 cm voxels and 2.4 m it read small
## from the bench pad, 6 Oct, so it grew with its voxels and kept their count): grey crust over a hot orange core
## after the old VoxelMining block, a teal vein tilted into W, and a hidden cavity lined with
## amethyst a little ana of the middle.
##
## ITS STORY cuts it for real, live, with the bench's own tools (the swap keeps every frame smooth):
##   THE SPECIMEN    what it is, in voxels, chunks and tetrahedra
##   VOXELS IN 4D    each voxel a tiny tesseract; one smooth surface run through them
##   TWO CUTS        a 4D ball and a 4D box side by side; slid through W, one hole closes, one holds
##   THE TUNNEL      drilled front to back; slid through W, it closes
##   THE HIDDEN ROOM slid ana to where the cavity is, drilled from the top: it opens; slid back, gone
##   YOUR TURN       whole again, and the bench is yours
## When the story ends or is interrupted, a story that cut the specimen hands it back whole.
##
## NO class_name (engine_gotchas.md).

const Cutter := preload("res://ramon/VoxelLab/specimen/vl_cutter.gd")

## The block in metres (x, y, z, w) and its voxel size.
const SIZE := Vector4(2.88, 2.16, 1.92, 2.16)
const VOXEL := 0.12
## Every metric number of the first design (at 10 cm) times this.
const K := 1.2

var _recipe: Dictionary = {}
## Which of the story's cuts have been made this pass.
var _done: Dictionary = {}
var _story_cut: bool = false
## Set by the room: show the voxel grid (the grid view's material), for part 2.
var grid_view_hook: Callable


func _init() -> void:
	code = "VX-01"
	title = "The block"
	display_scale = 1.0
	turn_speed = 5.0


func recipe() -> Dictionary:
	if _recipe.is_empty():
		_recipe = Recipe.block(SIZE, VOXEL, {"crust_m": 0.12 * K, "chamfer_m": 0.12 * K, "vein_m": 0.09 * K, "vein_offset_m": -0.18 * K,
			"cavity_at_m": Vector4(0.25, 0.05, 0.0, 0.35) * K, "cavity_m": 0.32 * K, "lining_m": 0.08 * K})
		_recipe["voxel_count"] = Recipe.voxel_count(_recipe)
	return _recipe


## Seen from the front-right, a little above, at a part of the specimen: [eye, look] relative to the
## top of the plinth, in shown metres. The room's story camera flies to each (voxel_lab_4d.gd
## _run_film); the looks sit a little low so the block stands clear of the callout under it.
func chapters() -> Array:
	var c := Vector4(0, 1.15 * K, 0, 0)
	return [
		{"key": "specimen", "title": "THE SPECIMEN", "length": 7.0,
			"line": "A block of 4D rock, {size}, cut from nothing but numbers.",
			"callouts": [[1.4, "{voxels} voxels of {voxel}, in the engine's own voxel world."],
				[4.2, "{chunks} chunks of 8 voxels a side, {tets} tetrahedra on screen."]],
			"eye": Vector4(3.3, 2.4, 5.6, 0) * K, "look": c, "fov": 0.9},
		{"key": "voxels", "title": "VOXELS IN 4D", "length": 8.0,
			"line": "Each voxel is a tiny tesseract. One smooth surface runs through them.",
			"callouts": [[1.6, "The engine places one point in every voxel the surface crosses: dual contouring, in C++."],
				[4.6, "Grey crust, orange core: wherever you see orange, something cut it."]],
			"eye": Vector4(1.9, 2.0, 4.9, 0) * K, "look": c + K * Vector4(0.2, -0.15, 0.8, 0), "fov": 0.8},
		{"key": "two", "title": "TWO CUTS", "length": 13.0,
			"line": "A 4D ball and a 4D box, cut side by side. Now slide through W.",
			"callouts": [[1.0, "Left: a ball. Right: a box. In this slice they look alike."],
				[5.2, "The ball's hole shrinks as you leave its middle, and closes."],
				[8.8, "The box's hole keeps its size, then stops dead."]],
			"eye": Vector4(0.4, 1.8, 5.3, 0) * K, "look": c + K * Vector4(0, -0.15, 0.9, 0), "fov": 0.85},
		{"key": "tunnel", "title": "THE TUNNEL", "length": 11.0,
			"line": "Drilled straight through. A tunnel in 4D is a tube.",
			"callouts": [[1.4, "You can see right through it."], [5.0, "Slide through W: a step aside and it is solid rock."]],
			"eye": Vector4(-0.6, 1.3, 5.2, 0) * K, "look": c + K * Vector4(0.15, -0.6, 0, 0), "fov": 0.8},
		{"key": "hidden", "title": "THE HIDDEN ROOM", "length": 14.0,
			"line": "Something sits ana of your slice. Cut where it is.",
			"callouts": [[1.2, "First, slide ana: 42 centimetres along W."], [4.6, "Drill down from the top, at that W."],
				[8.4, "Slide back to your own slice: the hole is not here at all."]],
			"eye": Vector4(2.4, 3.6, 3.8, 0) * K, "look": c + K * Vector4(0.3, 0.6, 0, 0), "fov": 0.85},
		{"key": "yours", "title": "YOUR TURN", "length": 5.0,
			"line": "Whole again. Step onto the bench in front of it.",
			"callouts": [[1.2, "Every cut you make is timed. The numbers go on the screen beside you."]],
			"eye": Vector4(0.0, 2.6, 6.8, 0) * K, "look": c + K * Vector4(0, -0.4, 2.0, 0), "fov": 0.95},
	]


func play_part(key: String, t: float, length: float) -> Dictionary:
	var r: Dictionary = recipe()
	var cen: Vector4 = r["center"]
	var h: Vector4 = r["half"]
	var front: Vector4 = cen + Vector4(0, 0, h.z, 0)
	var v: float = VOXEL
	face_front(0.08)
	if grid_view_hook.is_valid():
		grid_view_hook.call(key == "voxels" and t > 0.8 and t < length - 0.6)
	match key:
		"two":
			if t > 1.0:
				_cut_once("two_ball", Cut.ball(front + Vector4(-0.55, 0.12, 0.10, 0) * K / v, 0.30 * K / v))
			if t > 1.8:
				_cut_once("two_box", Cut.block(front + Vector4(0.55, 0.12, -0.12, 0) * K / v, Vector4.ONE * 0.24 * K / v))
			return {"slice": _sweep(t, 4.2, length - 0.6, 0.30 * K)}
		"tunnel":
			if t > 0.8:
				var at: Vector4 = front + Vector4(0.15, -0.45, 0.1, 0) * K / v
				_cut_once("tunnel", Cut.drill(at, Vector4(0, 0, -1, 0), 0.16 * K / v, (SIZE.z + 0.2 * K) / v))
			return {"slice": _sweep(t, 4.4, length - 0.6, 0.24 * K)}
		"hidden":
			var cav: Dictionary = r["cavity"]
			var cw: float = ((cav["center"] as Vector4).w - cen.w) * v
			# 0 to 3.5 s: slide ana to the cavity's W; hold while drilling; from 7.5 s, back to 0.
			var w_now: float = cw * smoothstep(0.6, 3.4, t) * (1.0 - smoothstep(7.6, 10.4, t))
			if t > 4.4:
				var top := Vector4((cav["center"] as Vector4).x, cen.y + h.y + 0.15 * K / v, (cav["center"] as Vector4).z, (cav["center"] as Vector4).w)
				_cut_once("hidden", Cut.drill(top, Vector4(0, -1, 0, 0), 0.15 * K / v, ((top.y - (cav["center"] as Vector4).y)) + 0.05 * K / v))
			return {"slice": _fraction(w_now)}
		"yours":
			if t > 0.3 and _story_cut:
				_story_cut = false
				_done = {}
				reset()
	return {}


## Cuts once per pass of the story.
func _cut_once(key: String, cut: Dictionary) -> void:
	if _done.has(key) or specimen == null or not bool(specimen.call("is_ready")):
		return
	_done[key] = true
	_story_cut = true
	cut["label"] = "Story: " + key
	specimen.call("apply_cut", cut)


## A slide through W, out to `reach` metres either side and back, between `t0` and `t1`, as the
## showcase's slice fraction.
func _sweep(t: float, t0: float, t1: float, reach: float) -> float:
	var u: float = clampf((t - t0) / maxf(t1 - t0, 0.1), 0.0, 1.0)
	return _fraction(sin(u * TAU) * reach)


## The showcase slides the exhibit by fraction x w_extent(); to see the specimen's own W `w` (real
## metres) in your slice, the exhibit moves by -w x display_scale.
func _fraction(w: float) -> float:
	return -(w * display_scale) / maxf(w_extent(), 0.01)


## A story that cut the specimen hands it back whole (stepping in mid-story included).
func end_cinematic() -> void:
	if grid_view_hook.is_valid():
		grid_view_hook.call(false)
	if _story_cut:
		_story_cut = false
		_done = {}
		reset()
	_done = {}


func card() -> Dictionary:
	var n: Dictionary = numbers()
	return {
		"short": "A block of 4D rock in the engine's own voxel world, cut live with every cost measured.",
		"code": code, "title": "The block", "kicker": "THE ENGINE'S VOXELS, CUT LIVE",
		"method": "The block is built by the engine's generators (a crust box, a core box, a vein between two planes, 24 chamfer planes) and two 4D balls for the cavity. A cut is an edit of air: a 4D ball, box or slab. The engine meshes the chunks it touched by dual contouring in C++; the lab builds their draw buffers on a worker thread before showing them, so no frame freezes.",
		"shows": "Matter you can cut, where every cut goes through W too: a ball's hole shrinks through W, a box's holds; a tunnel is a tube; a cavity can hide beside your slice.",
		"limits": "About 290 MB of video memory at %s voxels. A cut shows 25 to 160 ms after the click. Cuts thinner than a voxel vanish." % String(n["voxel"]),
		"rows": [["Voxels", "%s of %s" % [String(n["voxels"]), String(n["voxel"])]], ["Chunk meshes", String(n["chunks"])],
			["Tetrahedra", "%s, %s" % [String(n["tets"]), String(n["mb"])]], ["Meshed in", String(n["mesh_ms"]) + " (engine, C++)"]],
		"tier": "MEASURED LIVE",
		"key": "",
	}
