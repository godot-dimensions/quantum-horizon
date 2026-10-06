extends "res://ramon/Arboretum/exhibits/tree_exhibit_4d.gd"

## Pedestal 03, LF-03: the same tree lofted with the loft tool that builds our animals
## (botany/loft_tree_builder.gd): a cross-section at every point of every branch, skinned between
## them, the leaves as lofted clumps. Its story: the skeleton, the cross-sections as gold rings, the
## skin, the slice, the wind. Its key: fewer or more sides to every cross-section, lofted again live.
##
## NO class_name (engine_gotchas.md).

const LoftTree := preload("res://ramon/Arboretum/botany/loft_tree_builder.gd")
const Species := preload("res://ramon/Arboretum/botany/tree_species.gd")

## What E steps through: the bake's resolution, then coarser, then finer ([rings, sides] by order).
const RESOLUTIONS := [
	{"name": "as baked", "sides": [[4, 8], [3, 6], [3, 5], [2, 4]]},
	{"name": "coarse", "sides": [[3, 6], [2, 4], [2, 4], [2, 3]]},
	{"name": "fine", "sides": [[5, 12], [4, 8], [3, 6], [3, 5]]},
]

var _res_i: int = 0


func _init() -> void:
	method = "loft"
	tree_height = 4.3


func _load() -> void:
	sk = Bake.load_res("main_skeleton")
	if sk == null:
		sk = Species.grow("specimen")
	_setup_tree()
	record = Bake.record("loft")
	var wood: Resource = Bake.load_res("lf_wood")
	var clumps: Resource = Bake.load_res("lf_clumps")
	var stations: Resource = Bake.load_res("lf_stations")
	if wood == null:
		var w: Dictionary = LoftTree.build(sk, Species.loft_opts())
		wood = w["mesh"]
		record = {"tets": w["tets"], "sections": w["sections"], "build_ms": w["ms"]}
		live_note = "built live"
	if clumps == null:
		clumps = LoftTree.clumps(sk, {"size": 0.3})["mesh"]
	if stations == null:
		stations = LoftTree.stations(sk, Species.loft_opts())["mesh"]
	layer("wood", wood)
	layer("clumps", clumps)
	layer("stations", stations)
	var bones: Array = []
	for k in 6:
		var b: Resource = Bake.load_res("bones_main_%d" % k)
		if b != null:
			bones.append(b)
	set_stages("bones", bones)


func end_cinematic() -> void:
	_gusted = false
	show_only(["wood", "clumps"])


func chapters() -> Array:
	return [
		{"key": "skeleton", "title": "THE SAME SKELETON", "length": 5.5,
			"line": "The same tree again. This time our loft tool builds it.",
			"callouts": [[1.6, "The tool that lofts our animals, pointed at a tree."]],
			"eye": Vector4(-3.4, 2.6, 6.2, 0.0), "look": Vector4(0.0, 2.2, 0.0, 0.0), "fov": 0.9},
		{"key": "balls", "title": "THE CROSS-SECTIONS", "length": 8.0,
			"line": "A cross-section at every point of every branch. In 4D each one is a 3D ball.",
			"callouts": [[1.6, "{sections} cross-sections, each as wide as the twigs its branch carries."],
				[4.6, "Every limb is as thick as the twigs above it, the pipe model of trees."]],
			"eye": Vector4(-4.0, 2.8, 5.6, 0.0), "look": Vector4(0.0, 2.4, 0.0, 0.0), "fov": 0.9},
		{"key": "skin", "title": "THE SKIN", "length": 8.0,
			"line": "The loft skins between the cross-sections: three tetrahedra between two rings.",
			"callouts": [[2.0, "{tets} tetrahedra, lofted in {build_ms}."],
				[4.8, "About {ratio} times fewer than the voxels, because it follows the branches."]],
			"eye": Vector4(-2.8, 3.0, 6.0, 0.0), "look": Vector4(0.0, 2.4, 0.0, 0.0), "fov": 0.9},
		{"key": "slice", "title": "THE SLICE", "length": 8.0,
			"line": "Every branch is a tube through 4D, round in every slice.",
			"callouts": [[1.6, "Slide through W and whole limbs come into view and go."],
				[4.4, "This one is {w_depth} deep in W."]],
			"eye": Vector4(-1.2, 3.0, 7.4, 0.0), "look": Vector4(0.0, 2.3, 0.0, 0.0), "fov": 0.95},
		{"key": "wind", "title": "THE WIND", "length": 8.0,
			"line": "The loft knows its branches as it builds them, so the wind is free.",
			"callouts": [[1.6, "Each ring is labelled with its branch as it is lofted."],
				[4.4, "The leaf clumps ride on their twigs."]],
			"eye": Vector4(-3.8, 2.4, 6.0, 0.0), "look": Vector4(0.0, 2.6, 0.0, 0.0), "fov": 0.9},
	]


func play_part(key: String, t: float, length: float) -> Dictionary:
	var u: float = clampf(t / maxf(length, 0.1), 0.0, 1.0)
	match key:
		"skeleton":
			show_only([])
			show_stage("bones", int(floor(clampf(u / 0.7, 0.0, 1.0) * float(stage_count("bones") - 1) + 0.0001)))
		"balls":
			show_only(["stations"])
			show_stage("bones", stage_count("bones") - 1)
		"skin":
			show_only(["stations", "wood"] if u < 0.4 else (["wood"] if u < 0.75 else ["wood", "clumps"]))
		"slice":
			show_only(["wood", "clumps"])
			return {"slice": sweep(t, length)}
		"wind":
			show_only(["wood", "clumps"])
			gust_once(t, 0.8)
	return {}


func numbers() -> Dictionary:
	var out: Dictionary = super.numbers()
	out["sections"] = Bake.thousands(int(record.get("sections", 0)))
	out["build_ms"] = Bake.ms(float(record.get("build_ms", 0.0)))
	var vx: Dictionary = Bake.record("voxel")
	if int(vx.get("tets", 0)) > 0 and int(record.get("tets", 0)) > 0:
		out["ratio"] = str(int(round(float(vx["tets"]) / float(record["tets"]))))
	return out


func action_label() -> String:
	return "Cross-sections: %s" % String(RESOLUTIONS[(_res_i + 1) % RESOLUTIONS.size()]["name"])


## E: the next resolution, every branch lofted again here and now.
func action() -> String:
	_res_i = (_res_i + 1) % RESOLUTIONS.size()
	var res: Dictionary = RESOLUTIONS[_res_i]
	var w: Dictionary = LoftTree.build(sk, Species.loft_opts({"sides": res["sides"]}))
	layer("wood", w["mesh"])
	record = record.duplicate()
	record["tets"] = w["tets"]
	record["sections"] = w["sections"]
	record["build_ms"] = w["ms"]
	live_note = "" if _res_i == 0 else "lofted live, %s" % String(res["name"])
	show_only(["wood", "clumps"])
	return "Cross-sections %s: %s tetrahedra, lofted live in %s" % [String(res["name"]), Bake.thousands(w["tets"]), Bake.ms(w["ms"])]


func card() -> Dictionary:
	return {
		"short": "Our loft tool: a cross-section at every point of every branch, skinned between them.",
		"code": "LF-03", "title": "Lofted", "kicker": "THE LOFT TOOL THAT BUILDS OUR ANIMALS",
		"method": "Each branch of the skeleton is lofted root to tip: a cross-section at every point, as wide as the pipe model says, square to the branch, and a skin of tetrahedra between neighbouring cross-sections. Leaves are lofted clumps at the twig ends.",
		"shows": "A surface that follows the branches instead of a grid, so a tree costs a tenth of its voxels and is smooth at any size. The tool knows each branch as it builds it, which is what the wind needs.",
		"limits": "Branches overlap where they meet instead of merging, and a joint is only as clean as its parent hides it. The leaves are soft balls, not leaves: that is pedestal 04's job.",
		"rows": [["Cross-sections", Bake.thousands(int(record.get("sections", 0)))],
			["Tetrahedra", "%s wood, %s leaf clumps" % [Bake.thousands(int(record.get("tets", 0))), Bake.thousands(int(record.get("clump_tets", 0)))]],
			["Video memory", "about %.0f MB" % Bake.mb(int(record.get("tets", 0)) + int(record.get("clump_tets", 0)))],
			["Lofted in", Bake.ms(float(record.get("build_ms", 0.0))) + " in GDScript"]],
		"tier": ("PRE-BAKED " + String(record.get("date", ""))) if live_note.is_empty() else "GROWN LIVE, " + live_note,
		"key": action_label(),
	}
