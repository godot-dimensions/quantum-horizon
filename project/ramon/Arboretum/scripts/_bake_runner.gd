extends SceneTree

## Plan step 43: the bake. Every pedestal tree, its story stages and the grove's lighter trees into
## Arboretum/baked/, and what each took into baked/bake.cfg (botany/bake_store.gd). Headless: the
## engine's voxel world meshes without a window.
##
## Args after --: "all" (default), or any of skeleton, voxel, dc, loft, oak, grove, to bake only those
## (the skeletons are read back from disk when not baked again).

const Species := preload("res://ramon/Arboretum/botany/tree_species.gd")
const Voxel := preload("res://ramon/Arboretum/botany/voxel_tree_builder.gd")
const LoftTree := preload("res://ramon/Arboretum/botany/loft_tree_builder.gd")
const DC := preload("res://ramon/Arboretum/botany/dc_tree_builder_4d.gd")
const Bake := preload("res://ramon/Arboretum/botany/bake_store.gd")

const CELL := 0.125
const STAGES := 6
## The voxel and DC leaves, round every node carrying at most this many twigs.
const LEAF_R := 0.2
const LEAF_TWIGS := 2

var _parts: PackedStringArray
var _main: Resource
var _oak: Resource
var _dc_queue: Array = []
var _dc: Node4D
var _deadline: int = 0
var _date: String = ""


func _initialize() -> void:
	_deadline = Time.get_ticks_msec() + 300000
	_date = Time.get_date_string_from_system()
	_parts = OS.get_cmdline_user_args()
	if _parts.is_empty() or "all" in _parts:
		_parts = PackedStringArray(["skeleton", "voxel", "dc", "loft", "oak", "grove"])
	(func() -> void: _run()).call_deferred()


func _want(p: String) -> bool:
	return p in _parts


func _run() -> void:
	if _want("skeleton"):
		_main = Species.grow("specimen")
		Bake.save_res(_main, "main_skeleton")
		_note_skeleton("skeleton_main", _main)
		_oak = Species.grow("oak")
		Bake.save_res(_oak, "oak_skeleton")
		_note_skeleton("skeleton_oak", _oak)
	else:
		_main = Bake.load_res("main_skeleton")
		_oak = Bake.load_res("oak_skeleton")
	if _main == null or _oak == null:
		print("BAKE no skeletons")
		quit(2)
		return
	var f: Dictionary = Species.form()
	_bones("main", _main, 0.022, float(f["w_floor"]))
	_bones("oak", _oak, 0.035, float(f["w_floor"]))
	if _want("voxel"):
		_bake_voxel()
	if _want("loft"):
		_bake_loft()
	if _want("oak"):
		_bake_oak()
	if _want("grove"):
		_bake_grove_static()
	if _want("dc"):
		_dc_queue.append(["dc_wood", _main, CELL, "dc"])
	if _want("grove"):
		for v in 3:
			_dc_queue.append(["grove_dc_%d" % v, Species.grow("specimen", 101 + v), 0.25, "grove_dc_%d" % v])
	_next_dc()


func _note_skeleton(section: String, sk: Resource) -> void:
	var s: Dictionary = sk.call("summary")
	var st: Dictionary = sk.get("stats")
	var rec: Dictionary = s.duplicate()
	rec.merge(st, true)
	rec["date"] = _date
	Bake.write_record(section, rec)
	print("BAKE %s: %s" % [section, str(rec)])


## The skeleton growing, in STAGES steps (gold tubes), the last the whole skeleton.
func _bones(name: String, sk: Resource, r: float, w_depth: float = 0.0) -> void:
	var n: int = (sk.get("positions") as PackedVector4Array).size()
	var t0: int = Time.get_ticks_usec()
	for k in STAGES:
		var upto: int = int(ceil(float(n) * float(k + 1) / float(STAGES)))
		var b: Dictionary = LoftTree.bones(sk, r, upto, w_depth)
		Bake.save_res(b["mesh"], "bones_%s_%d" % [name, k])
	print("BAKE bones %s: %d stages in %.0f ms" % [name, STAGES, (Time.get_ticks_usec() - t0) / 1000.0])


func _bake_voxel() -> void:
	var r: Dictionary = Voxel.build(_main, CELL, Species.voxel_opts())
	Bake.save_res(r["mesh"], "vx_wood")
	var n: int = (_main.get("positions") as PackedVector4Array).size()
	for k in STAGES:
		var upto: int = int(ceil(float(n) * float(k + 1) / float(STAGES)))
		Bake.save_res(Voxel.stage(r["voxels"], r["births"], CELL, upto, float(r["w_stretch"])), "vx_stage_%d" % k)
	Bake.write_record("voxel", {"cell": CELL, "cells": r["cells"], "wood_cells": r["wood_cells"], "tets": r["tets"],
		"voxelize_ms": r["voxelize_ms"], "mesh_ms": r["mesh_ms"], "build_ms": r["ms"], "date": _date})
	print("BAKE voxel: ", r["cells"], " cells, ", r["tets"], " tets, ", r["ms"], " ms")


func _bake_loft() -> void:
	var w: Dictionary = LoftTree.build(_main, Species.loft_opts())
	Bake.save_res(w["mesh"], "lf_wood")
	var c: Dictionary = LoftTree.clumps(_main, {"size": 0.3})
	Bake.save_res(c["mesh"], "lf_clumps")
	var s: Dictionary = LoftTree.stations(_main, Species.loft_opts())
	Bake.save_res(s["mesh"], "lf_stations")
	Bake.write_record("loft", {"tets": w["tets"], "sections": w["sections"], "build_ms": w["ms"], "clump_tets": c["tets"], "clumps": c["count"],
		"clump_ms": c["ms"], "station_tets": s["tets"], "stations": s["count"], "date": _date})
	print("BAKE loft: wood %d tets (%d sections) %.0f ms; clumps %d tets; stations %d" % [w["tets"], w["sections"], w["ms"], c["tets"], s["count"]])


func _bake_oak() -> void:
	var w: Dictionary = LoftTree.build(_oak, Species.loft_opts(Species.OAK_LOFT))
	Bake.save_res(w["mesh"], "oak_wood")
	var stages: int = 0
	for o in 4:
		var s: Dictionary = LoftTree.build(_oak, Species.loft_opts(Species.OAK_LOFT.merged({"max_order": o})))
		Bake.save_res(s["mesh"], "oak_order_%d" % o)
		stages += 1
	Bake.write_record("oak", {"tets": w["tets"], "sections": w["sections"], "build_ms": w["ms"], "date": _date})
	print("BAKE oak: wood %d tets (%d sections) %.0f ms, %d order stages" % [w["tets"], w["sections"], w["ms"], stages])


## The grove's lighter trees, three of each method (seeds 101 to 103): coarser voxels (25 cm), the
## loft at its fewest sides, small oaks. The DC ones go through the engine below.
func _bake_grove_static() -> void:
	for v in 3:
		var sk: Resource = Species.grow("specimen", 101 + v)
		Bake.save_res(sk, "grove_sk_%d_skeleton" % v)
		var vx: Dictionary = Voxel.build(sk, 0.25, Species.voxel_opts({"leaf_r": maxf(0.3, float(Species.form()["leaf_r"])), "leaf_twigs": 1, "min_r_cells": 0.9}))
		Bake.save_res(vx["mesh"], "grove_vx_%d" % v)
		Bake.write_record("grove_vx_%d" % v, {"tets": vx["tets"], "build_ms": vx["ms"], "cell": 0.25})
		var lf: Dictionary = LoftTree.build(sk, Species.loft_opts(Species.GROVE_LOFT))
		var cl: Dictionary = LoftTree.clumps(sk, {"size": 0.34, "every": 2})
		Bake.save_res(lf["mesh"], "grove_lf_%d" % v)
		Bake.save_res(cl["mesh"], "grove_lfc_%d" % v)
		Bake.write_record("grove_lf_%d" % v, {"tets": lf["tets"] + cl["tets"], "build_ms": lf["ms"] + cl["ms"]})
		print("BAKE grove %d: voxel %d tets, loft %d tets" % [v, vx["tets"], lf["tets"] + cl["tets"]])
	for v in 2:
		var oak: Resource = Species.grow("oak", 201 + v, Species.GROVE_OAK)
		Bake.save_res(oak, "grove_oak_%d_skeleton" % v)
		var w: Dictionary = LoftTree.build(oak, Species.loft_opts(Species.GROVE_OAK_LOFT))
		Bake.save_res(w["mesh"], "grove_ok_%d" % v)
		Bake.write_record("grove_ok_%d" % v, {"tets": w["tets"], "build_ms": w["ms"]})
		print("BAKE grove oak %d: %d tets" % [v, w["tets"]])


func _next_dc() -> void:
	if _dc_queue.is_empty():
		print("BAKE done")
		quit()
		return
	var job: Array = _dc_queue.pop_front()
	if _dc != null:
		_dc.queue_free()
	_dc = Node4D.new()
	_dc.set_script(DC)
	_dc.set("cell", float(job[2]))
	_dc.set("w_stretch", float(Species.form()["w_stretch"]))
	root.add_child(_dc)
	_dc.connect("built", func(r: Dictionary) -> void: _dc_done(job, r))
	var lr: float = float(Species.form()["leaf_r"])
	var grove: bool = float(job[2]) >= 0.2
	_dc.call("start", job[1], {"leaf_r": maxf(0.3, lr) if grove else lr, "leaf_twigs": 1 if grove else LEAF_TWIGS, "min_r_cells": 0.9 if grove else 0.62})


func _dc_done(job: Array, r: Dictionary) -> void:
	Bake.save_res(r["mesh"], String(job[0]))
	var rec: Dictionary = {"cell": job[2], "edits": r["edits"], "load_ms": r.get("load_ms", 0.0), "edit_ms": r.get("edit_ms", 0.0),
		"mesh_ms": r.get("mesh_ms", 0.0), "read_ms": r.get("read_ms", 0.0), "label_ms": r.get("label_ms", 0.0), "chunks": r.get("chunks", 0),
		"tets": r["tets"], "vertices": r.get("vertices", 0), "date": _date}
	rec["build_ms"] = float(rec["load_ms"]) + float(rec["edit_ms"]) + float(rec["mesh_ms"]) + float(rec["read_ms"]) + float(rec["label_ms"])
	Bake.write_record(String(job[3]), rec)
	print("BAKE %s: %s" % [job[3], str(rec)])
	(func() -> void: _next_dc()).call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() > _deadline:
		print("BAKE TIMEOUT")
		quit(2)
		return true
	return false
