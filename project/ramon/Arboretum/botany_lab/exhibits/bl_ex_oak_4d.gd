extends "res://ramon/Arboretum/botany_lab/exhibits/bl_tree_exhibit_4d.gd"

## BOTANY LAB (fork, 9 Oct; plan steps 61-65; Ramon: "Instead of showing a separate yellow branch
## structure, consider demonstrating the branches growing directly out of the existing trunk ... Treat
## this as a refinement"): no gold bones. The story opens on GROWING: the trunk alone, then each order
## of branches out of the wood (the bake's oak_order_0..3), the whole oak; then its leaves, the slice,
## the wind, as before. The oak itself is unchanged.
##
## Pedestal 04, OK-04: the oak, on the largest pedestal. Its own skeleton (botany/tree_species.gd
## "oak": a crown wider than tall that starts low, grown by the paper's own space colonization,
## botany/colonize_4d.gd, where 01 to 03 keep the Shrubbery Lab's), lofted wood that is thicker where it carries
## more, tens of thousands of leaves the graphics card places in your slice every frame
## (botany/leaf_field_4d.gd, the grass's route), and the room's wind on all of it. Its story: the
## form, the wood growing limb by limb, the leaves arriving, the slice, the wind. Its key: the seasons.
##
## NO class_name (engine_gotchas.md).

const LoftTree := preload("res://ramon/Arboretum/botany/loft_tree_builder.gd")
const Species := preload("res://ramon/Arboretum/botany/tree_species.gd")
const Leaves := preload("res://ramon/Arboretum/botany/leaf_field_4d.gd")

const SEASONS := ["summer", "autumn", "bare"]

var leaves: Node4D
var _season: float = 0.0
var _season_to: float = 0.0
var _season_i: int = 0


func _init() -> void:
	method = "oak"
	tree_height = 7.4
	turn_speed = 2.5


func _load() -> void:
	sk = Bake.load_res("oak_skeleton")
	if sk == null:
		sk = Species.grow("oak")
	_setup_tree(true)
	record = Bake.record("oak")
	var wood: Resource = Bake.load_res("oak_wood")
	if wood == null:
		var w: Dictionary = LoftTree.build(sk, Species.loft_opts(Species.OAK_LOFT))
		wood = w["mesh"]
		record = {"tets": w["tets"], "sections": w["sections"], "build_ms": w["ms"]}
		live_note = "built live"
	layer("wood", wood)
	var orders: Array = []
	for o in 4:
		var m: Resource = Bake.load_res("oak_order_%d" % o)
		if m != null:
			orders.append(m)
	set_stages("orders", orders)
	leaves = Node4D.new()
	leaves.name = "Leaves"
	leaves.set_script(Leaves)
	Species.oak_leaves(leaves)
	tree.add_child(leaves)
	leaves.call("grow_leaves", sk, 5)
	record = record.duplicate()
	record["leaves"] = int(leaves.get("count"))
	record["leaf_ms"] = float(leaves.get("build_ms"))


func end_cinematic() -> void:
	_gusted = false
	show_only(["wood"])
	if leaves != null:
		leaves.set("enabled", true)
		leaves.call("set_grow", 1.0)


func chapters() -> Array:
	return [
		{"key": "wood", "title": "GROWING", "length": 10.0,
			"line": "The trunk first; then each order of branches grows out of the wood it springs from.",
			"callouts": [[1.6, "A crown wider than it is tall that starts low: each point in it pulls only its nearest bud."],
				[4.8, "Each limb is as thick as the twigs it carries: {nodes} points in {branches} branches."],
				[7.6, "{tets} tetrahedra of wood, lofted limb by limb."]],
			"eye": Vector4(-6.8, 3.0, 11.5, 0.0), "look": Vector4(0.0, 3.4, 0.0, 0.0), "fov": 0.95},
		{"key": "leaves", "title": "THE LEAVES", "length": 9.0,
			"line": "{leaves} leaves, and not one of them is a tetrahedron.",
			"callouts": [[1.8, "The graphics card places every leaf in your slice, every frame."],
				[5.0, "A leaf in 4D is a thin flat 3D blade. Your slice cuts it into a leaf shape."]],
			"eye": Vector4(-5.0, 4.6, 12.0, 0.0), "look": Vector4(0.0, 4.4, 0.0, 0.0), "fov": 0.9},
		{"key": "slice", "title": "THE SLICE", "length": 8.0,
			"line": "Slide through W and the crown changes leaf by leaf.",
			"callouts": [[1.6, "Each leaf is full size on its own slice and shrinks as you leave it."],
				[4.4, "The crown is {w_depth} deep in W."]],
			"eye": Vector4(-2.6, 4.0, 13.0, 0.0), "look": Vector4(0.0, 4.0, 0.0, 0.0), "fov": 0.95},
		{"key": "wind", "title": "THE WIND", "length": 9.0,
			"line": "One wind for wood and leaves: they ride their branches, and each leaf flutters on its own.",
			"callouts": [[1.6, "The leaves run the bark's own wind before they are placed."],
				[4.6, "The wind has a W part, so branches swing out of your slice and back."]],
			"eye": Vector4(-7.2, 3.2, 11.6, 0.0), "look": Vector4(0.0, 4.2, 0.0, 0.0), "fov": 0.95},
	]


func play_part(key: String, t: float, length: float) -> Dictionary:
	var u: float = clampf(t / maxf(length, 0.1), 0.0, 1.0)
	match key:
		"wood":
			# The trunk alone for the first beat, then an order every beat, then the whole oak.
			show_only([])
			leaves.set("enabled", false)
			var k: int = int(floor(clampf((u - 0.1) / 0.7, 0.0, 1.0) * float(stage_count("orders"))))
			if k >= stage_count("orders"):
				show_only(["wood"])
				return {"done": true}
			show_stage("orders", k)
			return {"done": false}
		"leaves":
			show_only(["wood"])
			leaves.set("enabled", true)
			leaves.call("set_grow", clampf(u / 0.75, 0.0, 1.0))
			return {"done": u >= 0.75}
		"slice":
			show_only(["wood"])
			leaves.set("enabled", true)
			leaves.call("set_grow", 1.0)
			return {"slice": sweep(t, length)}
		"wind":
			show_only(["wood"])
			leaves.set("enabled", true)
			leaves.call("set_grow", 1.0)
			gust_once(t, 0.8)
	return {}


func numbers() -> Dictionary:
	var out: Dictionary = super.numbers()
	out["leaves"] = Bake.thousands(int(record.get("leaves", 0)))
	out["orders"] = str(int(sk.call("max_order")) + 1)
	return out


func _process(delta: float) -> void:
	if absf(_season - _season_to) > 0.001:
		_season = move_toward(_season, _season_to, delta * 0.6)
		leaves.call("set_season", _season)


func action_label() -> String:
	return "Season: %s" % SEASONS[(_season_i + 1) % SEASONS.size()]


## E: summer, autumn, bare, and summer again.
func action() -> String:
	_season_i = (_season_i + 1) % SEASONS.size()
	_season_to = float(_season_i)
	if _season_i == 0:
		_season = 0.0
		_season_to = 0.0
		leaves.call("set_season", 0.0)
	return "The oak in %s" % SEASONS[_season_i]


func card() -> Dictionary:
	return {
		"short": "Its own skeleton, lofted wood, and leaves the graphics card places in your slice.",
		"code": "OK-04", "title": "The oak", "kicker": "WHAT THE METHODS ADD UP TO",
		"method": "An oak's own skeleton, grown by space colonization as the paper describes it: each point in a low, wide crown pulls only the bud nearest to it, and any bud can sprout, so limbs share out the space. Lofted with sides set by each limb's thickness. The leaves are not geometry: each is a small card the graphics card places in your slice every frame, from where the leaf is in 4D, the way the pen's grass is drawn.",
		"shows": "A full crown of %s leaves for under a millisecond of the graphics card's time, and a 4D tree that changes leaf by leaf as you slice through it. Wood and leaves share one wind, read from the skeleton." % Bake.thousands(int(record.get("leaves", 0))),
		"limits": "The leaves are drawn, not solid: nothing can stand on them or hit them. Each leaf is lit as part of the crown's mass rather than on its own. The skeleton grows in a quarter of a second, but lofting its wood takes about two, so both are baked.",
		"rows": [["Leaves", "%s, placed in %s" % [Bake.thousands(int(record.get("leaves", 0))), Bake.ms(float(record.get("leaf_ms", 0.0)))]],
			["Wood", "%s tetrahedra" % Bake.thousands(int(record.get("tets", 0)))],
			# A leaf is four float texels (64 bytes) and a multimesh transform (48).
			["Video memory", "wood %.0f MB, leaves %.0f MB" % [Bake.mb(int(record.get("tets", 0))), float(int(record.get("leaves", 0)) * 112) / 1048576.0]],
			["Skeleton", "%s points, grown in %s" % [str(int((sk.call("summary") as Dictionary).get("nodes", 0))), Bake.ms(float((sk.get("stats") as Dictionary).get("grow_ms", 0.0)))]]],
		"tier": ("PRE-BAKED " + String(record.get("date", ""))) if live_note.is_empty() else "GROWN LIVE, " + live_note,
		"key": action_label(),
	}
