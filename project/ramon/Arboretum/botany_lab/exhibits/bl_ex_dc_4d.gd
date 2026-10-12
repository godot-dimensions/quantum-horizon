extends "res://ramon/Arboretum/botany_lab/exhibits/bl_tree_exhibit_4d.gd"

## BOTANY LAB (fork, 9 Oct; plan steps 48-54; Ramon: "Make this showcase consistently smooth and rounded
## ... Avoid visibly cubic forms ... Preserve the branch structure if it helps ... Larger, more cohesive
## foliage masses"): the voxel boxes are gone from its story; the skeleton stays (it suits the organic
## result); the wood grows smooth, order by order (bl_dc_order_0..3); the leaves are masses
## (bl_dc_wood, the forked builder's "leaf_mass"). E grows a new seed with the same masses.
##
## Pedestal 02, DC-02: the same tree grown in the engine's own voxel world and meshed by dual
## contouring in C++ (botany/dc_tree_builder_4d.gd). The same 12.5 cm cells as pedestal 01, so the
## story shows those cells first and then the smooth surface the engine runs through them. Its key
## grows a new tree (a new seed) live, in front of you: the engine's chunks arrive a few at a time,
## and the read-back swaps in the room's bark.
##
## NO class_name (engine_gotchas.md).

const DC := preload("res://ramon/Arboretum/botany_lab/botany/bl_dc_tree_builder_4d.gd")
const Species := preload("res://ramon/Arboretum/botany/tree_species.gd")

var _builder: Node4D
var _seed: int = 300


func _init() -> void:
	method = "dc"
	tree_height = 4.3


func _load() -> void:
	sk = Bake.load_res("main_skeleton")
	if sk == null:
		sk = Species.grow("specimen")
	_setup_tree()
	record = bl_record("bl_dc")
	var wood: Resource = bl_load("bl_dc_wood")
	if wood != null:
		layer("wood", wood)
	else:
		_grow_live(sk)
	var orders: Array = []
	var bones: Array = []
	for k in 4:
		var o: Resource = bl_load("bl_dc_order_%d" % k)
		if o != null:
			orders.append(o)
	for k in 6:
		var b: Resource = Bake.load_res("bones_main_%d" % k)
		if b != null:
			bones.append(b)
	set_stages("orders", orders)
	set_stages("bones", bones)


func chapters() -> Array:
	return [
		{"key": "skeleton", "title": "THE SAME SKELETON", "length": 5.5,
			"line": "The same tree as pedestal 01, point for point.",
			"callouts": [[1.6, "{nodes} points in {branches} branches."]],
			"eye": Vector4(-3.4, 2.6, 6.2, 0.0), "look": Vector4(0.0, 2.2, 0.0, 0.0), "fov": 0.9},
		{"key": "contour", "title": "THE SMOOTH WOOD", "length": 8.0,
			"line": "Each branch becomes a chain of 4D spheres; the engine runs one smooth surface through them all.",
			"callouts": [[1.6, "The trunk first, then each order of branches, merging where they meet."],
				[4.6, "Dual contouring: each cell gets one point, placed where the surface really crosses it."]],
			"eye": Vector4(3.6, 2.8, 5.8, 0.0), "look": Vector4(0.0, 2.2, 0.0, 0.0), "fov": 0.9},
		{"key": "leaves", "title": "THE LEAF MASSES", "length": 8.0,
			"line": "The leaves are larger balls of a second material, three to a clump; touching, they merge.",
			"callouts": [[2.0, "One surface for the whole crown: {tets} tetrahedra, meshed in C++ in {mesh_ms}."],
				[5.0, "{edits} sphere edits in all, applied in {edit_ms}."]],
			"eye": Vector4(2.8, 3.2, 5.4, 0.0), "look": Vector4(0.0, 2.8, 0.0, 0.0), "fov": 0.9},
		{"key": "slice", "title": "THE SLICE", "length": 8.0,
			"line": "A smooth 4D surface stays smooth in every slice.",
			"callouts": [[1.6, "Slide through W: the branches thin and swell instead of stepping."],
				[4.4, "This one is {w_depth} deep in W."]],
			"eye": Vector4(1.4, 3.0, 7.2, 0.0), "look": Vector4(0.0, 2.3, 0.0, 0.0), "fov": 0.95},
		{"key": "wind", "title": "THE WIND", "length": 8.0,
			"line": "The engine's surface knows nothing of branches, so every point is given its nearest one.",
			"callouts": [[1.6, "{vertices} points labelled with their branch in {label_ms}."],
				[4.4, "Then the same wind moves it as it moves the others."]],
			"eye": Vector4(3.8, 2.4, 6.0, 0.0), "look": Vector4(0.0, 2.6, 0.0, 0.0), "fov": 0.9},
	]


func play_part(key: String, t: float, length: float) -> Dictionary:
	var u: float = clampf(t / maxf(length, 0.1), 0.0, 1.0)
	match key:
		"skeleton":
			show_only([])
			show_stage("bones", int(floor(clampf(u / 0.7, 0.0, 1.0) * float(stage_count("bones") - 1) + 0.0001)))
		"contour":
			show_only([])
			if stage_count("orders") > 0:
				var k: int = int(floor(clampf(u / 0.8, 0.0, 1.0) * float(stage_count("orders") - 1) + 0.0001))
				show_stage("orders", k)
				return {"done": k >= stage_count("orders") - 1}
			show_only(["wood"])
			return {"done": true}
		"leaves":
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
	out["cell"] = "%.1f cm" % (float(record.get("cell", 0.125)) * 100.0)
	out["edits"] = Bake.thousands(int(record.get("edits", 0)))
	out["edit_ms"] = Bake.ms(float(record.get("edit_ms", 0.0)))
	out["mesh_ms"] = Bake.ms(float(record.get("mesh_ms", 0.0)))
	out["label_ms"] = Bake.ms(float(record.get("label_ms", 0.0)))
	out["vertices"] = Bake.thousands(int(record.get("vertices", 0)))
	return out


func action_label() -> String:
	return "Grow a new one" if _builder == null else "Growing..."


## E: a new seed, a new skeleton, grown in the engine's voxel world in front of you.
func action() -> String:
	if _builder != null:
		return ""
	_seed += 1
	var fresh: Resource = Species.grow("specimen", _seed)
	_grow_live(fresh)
	return "Growing seed %d in the engine's voxel world" % _seed


func _grow_live(fresh: Resource) -> void:
	_builder = Node4D.new()
	_builder.name = "LiveBuilder"
	_builder.set_script(DC)
	_builder.set("cell", 0.125)
	_builder.set("live", true)
	_builder.set("w_stretch", float(Species.form()["w_stretch"]))
	tree.add_child(_builder)
	_builder.connect("built", func(r: Dictionary) -> void: _grown(fresh, r))
	show_only([])
	_builder.call("start", fresh, {"leaf_mass": true, "mass_seed": _seed})


func _grown(fresh: Resource, r: Dictionary) -> void:
	sk = fresh
	_setup_tree()
	layer("wood", r["mesh"])
	for k in layers:
		(layers[k] as MeshInstance4D).material_override = material
	record = {"cell": 0.125, "edits": r["edits"], "edit_ms": r.get("edit_ms", 0.0), "mesh_ms": r.get("mesh_ms", 0.0),
		"label_ms": r.get("label_ms", 0.0), "read_ms": r.get("read_ms", 0.0), "load_ms": r.get("load_ms", 0.0),
		"tets": r["tets"], "vertices": r.get("vertices", 0), "chunks": r.get("chunks", 0)}
	record["build_ms"] = float(record["load_ms"]) + float(record["edit_ms"]) + float(record["mesh_ms"]) + float(record["read_ms"]) + float(record["label_ms"])
	live_note = "seed %d, grown live" % _seed
	_builder.queue_free()
	_builder = null
	show_only(["wood"])


func live() -> Array:
	if _builder != null:
		return [["Growing", "%.0f%%  ·  %s tetrahedra so far" % [float(_builder.call("progress")) * 100.0, Bake.thousands(int(_builder.call("tets_now")))]]]
	return []


func card() -> Dictionary:
	return {
		"short": "The same cells in the engine's own voxel world, meshed smooth by dual contouring in C++.",
		"code": "DC-02", "title": "Smooth voxels", "kicker": "THE ENGINE'S OWN VOXEL WORLD",
		"method": "The skeleton is written into the engine's voxel world (VoxelWorld4D) as chains of 4D spheres, and the leaves as masses: clumps of three larger balls of a second material that run together where they touch. The engine meshes it by dual contouring in C++: every grid edge that crosses the surface keeps where it crosses and which way the surface faces, and each cell gets one point where those agree best.",
		"shows": "Native engine voxels with smooth surfaces, built fast enough to watch: the same cells as the blocks, without the stair steps. The voxel world can also be edited live, which a baked mesh cannot.",
		"limits": "Costs about what the blocks cost at the same cell size, since it is still one face for every edge the surface crosses. Twigs thinner than a cell vanish or thicken. The surface knows nothing of branches until every point is labelled.",
		"rows": [["Sphere edits", "%s in %s" % [Bake.thousands(int(record.get("edits", 0))), Bake.ms(float(record.get("edit_ms", 0.0)))]],
			["Meshed in C++", "%s, %d chunks" % [Bake.ms(float(record.get("mesh_ms", 0.0))), int(record.get("chunks", 0))]],
			["Tetrahedra", Bake.thousands(int(record.get("tets", 0)))],
			["Labelled for the wind", Bake.ms(float(record.get("label_ms", 0.0))) + " in GDScript"]],
		"tier": ("PRE-BAKED " + String(record.get("date", ""))) if live_note.is_empty() else "GROWN LIVE, " + live_note,
		"key": action_label(),
	}
