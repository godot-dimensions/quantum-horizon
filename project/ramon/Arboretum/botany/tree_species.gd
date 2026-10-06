extends RefCounted

## The Arboretum's trees, as settings for the carried space colonization
## (carried/shrubbery/shrub_species.gd and shrub_generator.gd, the Shrubbery Lab's own algorithm)
## and the skeleton's own shaping (tree_skeleton_4d.gd).
##
## Each species grows inside a CROWN ENVELOPE (crown_shape_4d.gd: a 4D ellipsoid cut flat
## underneath, denser at its skin), round in X, Z and W before the form squashes it, so the tree has
## a clear trunk below the crown and grows up into it before it branches (Runions, Lane and
## Prusinkiewicz's envelopes). The Shrubbery Lab grew its tree in a box that reached the ground,
## which bent its trunk over like a question mark (case study 3).
##
##   "specimen"  the tree on pedestals 01 to 03: about 4.5 m, a 1.5 m clear trunk, a rounded crown
##   "oak"       pedestal 04: a crown wider than tall that starts low, a radius of influence of five
##               segments so limbs spread rather than climb, a slight droop
##   "shrubbery" the Shrubbery Lab's tree exactly as it was (its box, its numbers), for reference
##
## grow(name, seed, overrides) returns the skeleton; `overrides` changes any setting (the species
## probe tries variants with it).
##
## NO class_name (engine_gotchas.md): preload it.

const Species := preload("res://ramon/Arboretum/carried/shrubbery/shrub_species.gd")
const Gen := preload("res://ramon/Arboretum/carried/shrubbery/shrub_generator.gd")
const Skeleton := preload("res://ramon/Arboretum/botany/tree_skeleton_4d.gd")
const Crown := preload("res://ramon/Arboretum/botany/crown_shape_4d.gd")
const Branch := preload("res://ramon/Arboretum/carried/shrubbery/shrub_branch.gd")
const Colonize := preload("res://ramon/Arboretum/botany/colonize_4d.gd")

## THE FORM (case study 2, the first pivot): how a 4D tree is shaped so a slice reads as a tree.
## "squashed": flattened through W after growing and the wood deeper in W than across, so one slice
## holds most of the tree (turned a quarter turn through W it shows its narrow side); "isotropic":
## grown free in 4D, the same in X, Z and W, the wood thicker all round (4Denthusiast's direction for
## the pen, 5 Oct; in a slice it shows a trunk, stubs and a leaf cloud). Every builder reads this, so
## the room's four trees, the grove and every live rebuild share it.
const FORM := "squashed"
const FORMS := {
	"squashed": {"w_squash": 0.55, "twig_r": 0.02, "oak_twig_r": 0.022, "w_stretch": 3.0, "w_floor": 0.22, "w_cap": 0.45,
		"leaf_r": 0.22, "leaf_w": 0.26, "per_node": 34, "oak_leaf_w": 0.6, "oak_leaf_size": 0.22, "oak_per_node": 44},
	"isotropic": {"w_squash": 1.0, "twig_r": 0.036, "oak_twig_r": 0.04, "w_stretch": 1.0, "w_floor": 0.0, "w_cap": 99.0,
		"leaf_r": 0.3, "leaf_w": 0.3, "per_node": 40, "oak_leaf_w": 0.6, "oak_leaf_size": 0.26, "oak_per_node": 44},
}

## The species. "gen": the carried generator's settings; "crown": [centre, radii (x, y, z, w), the
## height below which nothing grows, how much denser at the skin] or empty for the generator's own
## box; "pipe": [n, twig radius key in FORMS, smoothing passes, root flare]; "trunk": metres of
## straight trunk grown before the crown is let in (case study 3: without it the first tip already
## sees crown points off to one side and the trunk bends over toward them). "sc": grown by the
## paper's own space colonization (colonize_4d.gd: each point pulls its nearest node, any node can
## sprout) with these settings, instead of the carried generator (case study 4: the oak).
const PRESETS := {
	"specimen": {"seed": 4, "trunk": 1.2, "gen": {"segment_length": 0.34, "iterations": 60, "attractor_count": 1100, "attract_distance": 1.25,
		"kill_distance": 0.34, "min_attractors_to_fork": 3, "fork_angle_threshold_deg": 45.0, "fork_probability": 0.4,
		"max_branches": 700, "gravity_lean_strength": 0.02},
		"crown": [Vector4(0.0, 3.2, 0.0, 0.0), Vector4(1.9, 1.55, 1.9, 1.9), 1.55, 0.7], "pipe": [2.5, "twig_r", 3, 1.3]},
	"oak": {"seed": 11, "trunk": 2.0, "points": 2600,
		"sc": {"segment": 0.35, "influence": 2.4, "kill": 0.7, "cone": 60.0, "tropism": Vector4(0.0, -0.1, 0.0, 0.0), "max_nodes": 2400, "steps": 140},
		"gen": {"segment_length": 0.42, "iterations": 70, "attractor_count": 1100, "attract_distance": 2.1,
		"kill_distance": 0.45, "min_attractors_to_fork": 3, "fork_angle_threshold_deg": 45.0, "fork_probability": 0.42,
		"max_branches": 950, "gravity_lean_strength": 0.03},
		"crown": [Vector4(0.0, 4.6, 0.0, 0.0), Vector4(4.6, 2.9, 4.6, 4.6), 2.2, 0.45], "pipe": [2.6, "oak_twig_r", 4, 1.4]},
	"shrubbery": {"seed": 0, "gen": {}, "crown": [], "pipe": [2.5, "twig_r", 3, 1.25]},
}


## The oak's wood (case study 4): sides and smoothing by a branch's own thickness, not its order. The
## paper's colonization puts most of its nodes on thin limbs of low order, and lofting those by
## order cost 395,000 tetrahedra; by thickness, 132,000.
const OAK_LOFT := {"by_radius": [[0.18, 5, 10, 2], [0.09, 4, 7, 1], [0.045, 3, 5, 0], [0.0, 2, 3, 0]], "root_sink": 0.5, "min_r": 0.014}
## The grove's oaks: coarser steps (about 1,500 nodes) and fewer sides; the grove's lofted trees the same.
const GROVE_OAK := {"sc": {"segment": 0.5, "kill": 1.0, "influence": 3.0, "max_nodes": 1500}}
const GROVE_OAK_LOFT := {"by_radius": [[0.15, 4, 8, 1], [0.07, 3, 5, 0], [0.0, 2, 3, 0]], "root_sink": 0.5, "min_r": 0.014}
const GROVE_LOFT := {"by_radius": [[0.12, 3, 6, 1], [0.05, 2, 4, 0], [0.0, 2, 3, 0]]}


## The oak's leaves for the form, onto a leaf_field_4d.gd node (the grove's oaks a third as many).
static func oak_leaves(leaf: Node, grove: bool = false) -> void:
	var f: Dictionary = form()
	leaf.set("leaf_w", float(f["oak_leaf_w"]))
	leaf.set("leaf_size", float(f["oak_leaf_size"]))
	leaf.set("per_node", int(f["oak_per_node"]) / (3 if grove else 1))


## The room's form settings (FORM).
static func form() -> Dictionary:
	return FORMS[FORM]


## The voxel builders' options for the form: leaves and the W stretch.
static func voxel_opts(extra: Dictionary = {}) -> Dictionary:
	var f: Dictionary = form()
	var o: Dictionary = {"leaf_r": f["leaf_r"], "leaf_twigs": 2, "w_stretch": f["w_stretch"]}
	o.merge(extra, true)
	return o


## The loft's options for the form.
static func loft_opts(extra: Dictionary = {}) -> Dictionary:
	var f: Dictionary = form()
	var o: Dictionary = {"w_stretch": f["w_stretch"], "w_floor": f["w_floor"], "w_cap": f["w_cap"]}
	o.merge(extra, true)
	return o


static func species(name: String, seed: int = -1, overrides: Dictionary = {}) -> Resource:
	var p: Dictionary = PRESETS.get(name, PRESETS["specimen"])
	var sp: Resource = Species.new()
	sp.set("seed", int(p["seed"]) if seed < 0 else seed)
	var gen: Dictionary = (p["gen"] as Dictionary).duplicate()
	gen.merge(overrides.get("gen", {}), true)
	for k in gen:
		sp.set(k, gen[k])
	return sp


## The skeleton of `name`; `seed` -1 for the room's own.
static func grow(name: String, seed: int = -1, overrides: Dictionary = {}) -> Resource:
	var p: Dictionary = PRESETS.get(name, PRESETS["specimen"])
	var sp: Resource = species(name, seed, overrides)
	var f: Dictionary = form()
	var pipe: Array = overrides.get("pipe", p["pipe"])
	var crown_def: Array = overrides.get("crown", p["crown"])
	var squash: float = float(overrides.get("w_squash", f["w_squash"]))
	var twig: float = float(f[String(pipe[1])])
	if crown_def.is_empty():
		return Skeleton.grow(sp, float(pipe[0]), twig, int(pipe[2]), float(pipe[3]), squash)
	var t0: int = Time.get_ticks_usec()
	if (p.has("sc") or overrides.has("sc")) and not bool(overrides.get("carried", false)):
		var sc: Dictionary = (p.get("sc", {}) as Dictionary).duplicate()
		sc.merge(overrides.get("sc", {}), true)
		sc["trunk"] = float(overrides.get("trunk", p.get("trunk", 1.5)))
		var seed_n: int = int(sp.get("seed"))
		var shape: RefCounted = Crown.new(crown_def[0], crown_def[1], float(crown_def[2]), float(crown_def[3]), seed_n)
		var pts: PackedVector4Array = Colonize.sample(shape, int(overrides.get("points", p.get("points", 2000))), seed_n)
		var r: Dictionary = Colonize.grow(pts, sc)
		var t_sc: int = Time.get_ticks_usec()
		var sk_sc: Resource = Skeleton.new()
		sk_sc.call("_build", r["positions"], r["parents"], float(pipe[0]), twig, int(pipe[2]), float(pipe[3]), squash)
		sk_sc.set("stats", {"generator_nodes": (r["positions"] as PackedVector4Array).size(), "grow_ms": (t_sc - t0) / 1000.0,
			"shape_ms": (Time.get_ticks_usec() - t_sc) / 1000.0, "seed": seed_n, "pipe_n": float(pipe[0]), "twig_r": twig, "form": FORM,
			"species": name, "algorithm": "space colonization (nearest node, any node sprouts)", "points": pts.size(),
			"points_left": int(r["left"]), "steps": int(r["steps"])})
		return sk_sc
	var g: RefCounted = Gen.new(int(sp.get("seed")))
	g.call("build_trunk", sp)
	_straight_trunk(g, float(overrides.get("trunk", p.get("trunk", 0.0))), float(sp.get("segment_length")))
	var crown: RefCounted = Crown.new(crown_def[0], crown_def[1], float(crown_def[2]), float(crown_def[3]), int(sp.get("seed")))
	g.call("spawn_attractors_from_shape", crown, int(sp.get("attractor_count")))
	g.call("grow", sp)
	var t1: int = Time.get_ticks_usec()
	var src: Array = g.get("branches")
	var pos := PackedVector4Array()
	var par := PackedInt32Array()
	for b in src:
		pos.append(b.position)
		par.append(int(b.parent_index))
	var sk: Resource = Skeleton.new()
	sk.call("_build", pos, par, float(pipe[0]), twig, int(pipe[2]), float(pipe[3]), squash)
	sk.set("stats", {"generator_nodes": src.size(), "grow_ms": (t1 - t0) / 1000.0, "shape_ms": (Time.get_ticks_usec() - t1) / 1000.0,
		"seed": int(sp.get("seed")), "pipe_n": float(pipe[0]), "twig_r": twig, "form": FORM, "species": name})
	return sk


## A straight trunk of `height` metres, in segments of `step`, grown up from the root before the
## space colonization takes over at its top (its only tip).
static func _straight_trunk(g: RefCounted, height: float, step: float) -> void:
	if height <= 0.0:
		return
	var branches: Array = g.get("branches")
	var n: int = int(ceil(height / maxf(step, 0.05)))
	for k in n:
		var parent: int = branches.size() - 1
		var at: Vector4 = (branches[parent] as Object).get("position") + Vector4(0.0, height / float(n), 0.0, 0.0)
		branches.append(Branch.new(at, Vector4(0, 1, 0, 0), 0.5, parent, k + 1, branches.size()))
