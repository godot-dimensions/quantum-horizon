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
## THE BIG OAK'S TRUNK (Ramon, 6 Oct: "the optimised oak seems a bit thinner ... can you make the base
## beam a bit thicker to compensate?"). A branch is as thick as the twigs it carries together (the pipe
## model), so an oak grown with a fifth of the twigs had a trunk a third thinner. The trunk alone is
## thickened to the hall oak's (as a share of the height: the pen stands them at the same height),
## fully at the ground and easing back to its own over the lower two thirds of the leader, so the
## limbs and the crown stay as grown.
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
	# Layout B's medium oaks (PLAN_B.md step 34): lighter again, planted smaller.
	{"name": "oak_lite4", "seed": 223, "points": 500, "sc": {"segment": 1.0, "kill": 2.3, "influence": 4.2, "max_nodes": 150},
		"loft": {"by_radius": [[0.1, 2, 4, 0], [0.0, 2, 3, 0]], "root_sink": 0.5, "min_r": 0.018, "span_ratio": 24.0}},
	# Layout B's bushes: the same oak grown into a low, wide crown from a short stem; three of them.
	{"name": "bush_1", "seed": 301, "points": 320, "trunk": 0.25, "crown": [Vector4(0.0, 1.0, 0.0, 0.0), Vector4(1.5, 0.85, 1.5, 1.5), 0.25, 0.5],
		"sc": {"segment": 0.28, "kill": 0.45, "influence": 1.1, "max_nodes": 80, "cone": 80.0},
		"loft": {"by_radius": [[0.0, 2, 3, 0]], "root_sink": 0.2, "min_r": 0.012, "span_ratio": 24.0}},
	{"name": "bush_2", "seed": 302, "points": 320, "trunk": 0.2, "crown": [Vector4(0.0, 0.85, 0.0, 0.0), Vector4(1.2, 0.7, 1.6, 1.4), 0.2, 0.5],
		"sc": {"segment": 0.28, "kill": 0.45, "influence": 1.1, "max_nodes": 70, "cone": 80.0},
		"loft": {"by_radius": [[0.0, 2, 3, 0]], "root_sink": 0.2, "min_r": 0.012, "span_ratio": 24.0}},
	{"name": "bush_3", "seed": 303, "points": 360, "trunk": 0.3, "crown": [Vector4(0.0, 1.15, 0.0, 0.0), Vector4(1.7, 0.95, 1.4, 1.5), 0.3, 0.5],
		"sc": {"segment": 0.3, "kill": 0.5, "influence": 1.2, "max_nodes": 90, "cone": 80.0},
		"loft": {"by_radius": [[0.0, 2, 3, 0]], "root_sink": 0.2, "min_r": 0.012, "span_ratio": 24.0}},
]


func _initialize() -> void:
	var hall: Resource = Bake.load_res("oak_skeleton")
	# The trunk as a share of the height: the pen stands every oak at the same height.
	var hs: Dictionary = hall.call("summary") if hall != null else {}
	var want_r: float = float(hs.get("trunk_r", 0.0)) / maxf(float(hs.get("height", 1.0)), 0.5)
	for i in LEVELS.size():
		var lv: Dictionary = LEVELS[i]
		var n: int = i + 1
		var name: String = String(lv.get("name", "oak_lite%d" % n))
		var t0: int = Time.get_ticks_msec()
		var grow: Dictionary = {"sc": lv["sc"], "points": lv["points"]}
		for k in ["trunk", "crown"]:
			if lv.has(k):
				grow[k] = lv[k]
		var sk: Resource = Species.grow("oak", int(lv["seed"]), grow)
		var ss: Dictionary = sk.call("summary")
		var got_r: float = float(ss["trunk_r"]) / maxf(float(ss["height"]), 0.5)
		var k: float = want_r / got_r if want_r > 0.0 and got_r > 0.0 else 1.0
		if k > 1.02 and not name.begins_with("bush"):
			_thicken_trunk(sk, k)
		var loft: Dictionary = lv["loft"]
		print("OAK LITE %s: trunk %.4f of its height against the hall oak's %.4f: the trunk x%.2f at the ground" % [name, got_r, want_r, k])
		Bake.save_res(sk, name + "_skeleton")
		var w: Dictionary = LoftTree.build(sk, Species.loft_opts(loft))
		Bake.save_res(w["mesh"], name + "_wood")
		var stats: Dictionary = sk.get("stats")
		Bake.write_record(name, {"nodes": stats.get("generator_nodes", 0), "tets": w["tets"], "sections": w["sections"],
			"build_ms": w["ms"]})
		print("OAK LITE %s: %d nodes, wood %d tetrahedra (%d sections), %.1f s" % [name, int(stats.get("generator_nodes", 0)), int(w["tets"]),
			int(w["sections"]), (Time.get_ticks_msec() - t0) / 1000.0])
	print("OAK LITE DONE")
	quit(0)


## The trunk (the order-0 branch) [param k] times as thick at the ground, easing back to as grown
## two thirds of the way up it; every other branch as it was.
static func _thicken_trunk(sk: Resource, k: float) -> void:
	var radii: PackedFloat32Array = sk.get("radii")
	var on: PackedInt32Array = sk.get("node_branch")
	var along: PackedFloat32Array = sk.get("node_along")
	var branches: Array = sk.get("branches")
	for i in radii.size():
		if on[i] < 0 or on[i] >= branches.size() or int((branches[on[i]] as Dictionary)["order"]) != 0:
			continue
		radii[i] *= lerpf(k, 1.0, smoothstep(0.0, 0.66, along[i]))
	sk.set("radii", radii)
