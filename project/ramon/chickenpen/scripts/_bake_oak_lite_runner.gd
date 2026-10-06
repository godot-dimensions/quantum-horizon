extends SceneTree

## Light oaks for the pen (Ramon, 6 Oct: "put an oak next to it, heavily optimised so i can start
## placing them in the pen without problems ... this level of fidelity was great for the arboretum, but
## not so much for in the pen. generate a few in lower quality and test").
##
## The Arboretum's oak, grown and lofted again with less: fewer nodes from coarser colonization steps
## (the grove's settings are the first level), fewer sides and rings per branch, and in the pen fewer
## leaves a node (pen_oak_4d.gd LEVELS, which also names these bakes). Saved beside the Arboretum's own
## bakes (Arboretum/botany/bake_store.gd) as oak_lite<n>_skeleton / oak_lite<n>_wood; the hall oak and
## the grove are not touched.
##
##   lab_run.sh headless oak_lite res://ramon/chickenpen/scripts/_bake_oak_lite_runner.gd

const Species := preload("res://ramon/Arboretum/botany/tree_species.gd")
const LoftTree := preload("res://ramon/Arboretum/botany/loft_tree_builder.gd")
const Bake := preload("res://ramon/Arboretum/botany/bake_store.gd")

## Per level: the colonization over the oak's own (Species.PRESETS "oak" sc), its crown points, and
## the loft. Level 1 is the grove's oak exactly.
const LEVELS := [
	{"seed": 211, "points": 2600, "sc": {"segment": 0.5, "kill": 1.0, "influence": 3.0, "max_nodes": 1500},
		"loft": {"by_radius": [[0.15, 4, 8, 1], [0.07, 3, 5, 0], [0.0, 2, 3, 0]], "root_sink": 0.5, "min_r": 0.014}},
	{"seed": 211, "points": 1400, "sc": {"segment": 0.65, "kill": 1.4, "influence": 3.4, "max_nodes": 800},
		"loft": {"by_radius": [[0.15, 3, 6, 0], [0.06, 2, 4, 0], [0.0, 2, 3, 0]], "root_sink": 0.5, "min_r": 0.014, "span_ratio": 14.0}},
	{"seed": 211, "points": 800, "sc": {"segment": 0.85, "kill": 1.9, "influence": 3.8, "max_nodes": 400},
		"loft": {"by_radius": [[0.12, 2, 5, 0], [0.0, 2, 3, 0]], "root_sink": 0.5, "min_r": 0.016, "span_ratio": 20.0}},
]


func _initialize() -> void:
	for i in LEVELS.size():
		var lv: Dictionary = LEVELS[i]
		var n: int = i + 1
		var t0: int = Time.get_ticks_msec()
		var sk: Resource = Species.grow("oak", int(lv["seed"]), {"sc": lv["sc"], "points": lv["points"]})
		Bake.save_res(sk, "oak_lite%d_skeleton" % n)
		var w: Dictionary = LoftTree.build(sk, Species.loft_opts(lv["loft"]))
		Bake.save_res(w["mesh"], "oak_lite%d_wood" % n)
		var stats: Dictionary = sk.get("stats")
		Bake.write_record("oak_lite%d" % n, {"nodes": stats.get("generator_nodes", 0), "tets": w["tets"], "sections": w["sections"],
			"build_ms": w["ms"]})
		print("OAK LITE %d: %d nodes, wood %d tetrahedra (%d sections), %.1f s" % [n, int(stats.get("generator_nodes", 0)), int(w["tets"]),
			int(w["sections"]), (Time.get_ticks_msec() - t0) / 1000.0])
	print("OAK LITE DONE")
	quit(0)
