extends "res://ramon/Arboretum/botany_lab/exhibits/bl_tree_exhibit_4d.gd"

## BOTANY LAB (fork, 9 Oct; plan steps 55-60; Ramon: "Consider making this station primarily a branch and
## lofting showcase ... Preserve the interesting visible twig geometry when it is integrated into the
## lofted form. Remove the little spherical foliage clumps"): no leaf clumps and no separate skeleton.
## The story: THE SECTIONS (the gold cross-sections along every branch, where the loft samples), THE
## SKIN (lofted through them order by order, trunk first: bl_lf_order_0..3), THE JOINTS (close on a
## fork, the twigs growing out of the lofted wood), THE SLICE, THE WIND.
##
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
	var stations: Resource = Bake.load_res("lf_stations")
	if wood == null:
		var w: Dictionary = LoftTree.build(sk, Species.loft_opts())
		wood = w["mesh"]
		record = {"tets": w["tets"], "sections": w["sections"], "build_ms": w["ms"]}
		live_note = "built live"
	if stations == null:
		stations = LoftTree.stations(sk, Species.loft_opts())["mesh"]
	layer("wood", wood)
	layer("stations", stations)
	var orders: Array = []
	for k in 4:
		var o: Resource = bl_load("bl_lf_order_%d" % k)
		if o != null:
			orders.append(o)
	set_stages("orders", orders)


func end_cinematic() -> void:
	_gusted = false
	show_only(["wood"])


func chapters() -> Array:
	return [
		{"key": "balls", "title": "THE SECTIONS", "length": 7.0,
			"line": "The loft samples every branch: a cross-section at every point, square to the branch.",
			"callouts": [[1.6, "{sections} cross-sections. In 4D each one is a 3D ball."],
				[4.2, "Every limb is as thick as the twigs above it, the pipe model of trees."]],
			"eye": Vector4(-4.0, 2.8, 5.6, 0.0), "look": Vector4(0.0, 2.4, 0.0, 0.0), "fov": 0.9},
		{"key": "skin", "title": "THE SKIN", "length": 9.0,
			"line": "The skin runs between the sections, branch by branch, the trunk first.",
			"callouts": [[2.0, "Three tetrahedra between two rings: {tets} in all, lofted in {build_ms}."],
				[5.2, "About {ratio} times fewer than the voxels, because it follows the branches."]],
			"eye": Vector4(-2.8, 3.0, 6.0, 0.0), "look": Vector4(0.0, 2.4, 0.0, 0.0), "fov": 0.9},
		{"key": "joints", "title": "THE JOINTS", "length": 7.0,
			"line": "Where a branch leaves its parent the two lofts meet: the twig grows out of the wood.",
			"callouts": [[1.6, "Each branch is its own loft, from its parent's surface to its tip."],
				[4.2, "No leaves here: this pedestal is about the branches."]],
			"eye": Vector4(-1.6, 3.4, 2.4, 0.0), "look": Vector4(0.0, 3.0, 0.0, 0.0), "fov": 0.8},
		{"key": "slice", "title": "THE SLICE", "length": 8.0,
			"line": "Every branch is a tube through 4D, round in every slice.",
			"callouts": [[1.6, "Slide through W and whole limbs come into view and go."],
				[4.4, "This one is {w_depth} deep in W."]],
			"eye": Vector4(-1.2, 3.0, 7.4, 0.0), "look": Vector4(0.0, 2.3, 0.0, 0.0), "fov": 0.95},
		{"key": "wind", "title": "THE WIND", "length": 8.0,
			"line": "The loft knows its branches as it builds them, so the wind is free.",
			"callouts": [[1.6, "Each ring is labelled with its branch as it is lofted."],
				[4.4, "Each branch swings about its base and carries the ones it holds."]],
			"eye": Vector4(-3.8, 2.4, 6.0, 0.0), "look": Vector4(0.0, 2.6, 0.0, 0.0), "fov": 0.9},
	]


func play_part(key: String, t: float, length: float) -> Dictionary:
	var u: float = clampf(t / maxf(length, 0.1), 0.0, 1.0)
	match key:
		"balls":
			show_only(["stations"])
		"skin":
			if stage_count("orders") > 0 and u < 0.8:
				show_only(["stations"] if u < 0.15 else [])
				show_stage("orders", int(floor(clampf((u - 0.1) / 0.65, 0.0, 1.0) * float(stage_count("orders") - 1) + 0.0001)))
			else:
				show_only(["wood"])
		"joints":
			show_only(["wood"])
		"slice":
			show_only(["wood"])
			return {"slice": sweep(t, length)}
		"wind":
			show_only(["wood"])
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
	show_only(["wood"])
	return "Cross-sections %s: %s tetrahedra, lofted live in %s" % [String(res["name"]), Bake.thousands(w["tets"]), Bake.ms(w["ms"])]


func card() -> Dictionary:
	return {
		"short": "Our loft tool: a cross-section at every point of every branch, skinned between them.",
		"code": "LF-03", "title": "Lofted", "kicker": "THE LOFT TOOL THAT BUILDS OUR ANIMALS",
		"method": "Each branch of the skeleton is lofted root to tip: a cross-section at every point, as wide as the pipe model says, square to the branch, and a skin of tetrahedra between neighbouring cross-sections. Each branch starts from its parent's surface, so the twigs grow out of the wood.",
		"shows": "The branching itself: a surface built along each branch, not a volume filled and then contoured (pedestal 02). It follows the branches instead of a grid, so a tree costs a tenth of its voxels and is smooth at any size; the tool knows each branch as it builds it, which is what the wind needs.",
		"limits": "Branches overlap where they meet instead of merging, and a joint is only as clean as its parent hides it. No leaves here on purpose: pedestal 04 shows what this wood carries.",
		"rows": [["Cross-sections", Bake.thousands(int(record.get("sections", 0)))],
			["Tetrahedra", Bake.thousands(int(record.get("tets", 0)))],
			["Video memory", "about %.0f MB" % Bake.mb(int(record.get("tets", 0)))],
			["Lofted in", Bake.ms(float(record.get("build_ms", 0.0))) + " in GDScript"]],
		"tier": ("PRE-BAKED " + String(record.get("date", ""))) if live_note.is_empty() else "GROWN LIVE, " + live_note,
		"key": action_label(),
	}
