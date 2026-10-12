extends SceneTree

## BOTANY LAB: the meshes the reworked pedestals need, baked once (section 7's plan steps 49-50 and 59),
## into botany_lab/baked/ with their own record (botany_lab/baked/bl_bake.cfg), so the Arboretum's
## baked/ and bake.cfg are left as they are.
##   bl_dc_wood         02's tree, dual-contoured, its leaves as masses (bl_dc_tree_builder_4d.gd
##                      "leaf_mass"); record "bl_dc"
##   bl_dc_order_0..3   02's wood up to each branch order, no leaves (the smooth growth stages)
##   bl_lf_order_0..3   03's wood up to each branch order (the skin, grown order by order)
## All from the shared skeleton (Arboretum/baked/main_skeleton.tres). Args after --: "dc", "loft"
## (default both).

const Species := preload("res://ramon/Arboretum/botany/tree_species.gd")
const LoftTree := preload("res://ramon/Arboretum/botany/loft_tree_builder.gd")
const Bake := preload("res://ramon/Arboretum/botany/bake_store.gd")
const DC := preload("res://ramon/Arboretum/botany_lab/botany/bl_dc_tree_builder_4d.gd")

const DIR := "res://ramon/Arboretum/botany_lab/baked/"
const RECORD := "res://ramon/Arboretum/botany_lab/baked/bl_bake.cfg"
const CELL := 0.125

var _main: Resource
var _queue: Array = []
var _dc: Node4D
var _deadline: int = 0
var _date: String = ""


func _initialize() -> void:
	_deadline = Time.get_ticks_msec() + 400000
	_date = Time.get_date_string_from_system()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	(func() -> void: _run()).call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() > _deadline:
		print("BAKE TIMEOUT")
		quit(2)
		return true
	return false


static func save(r: Resource, name: String) -> int:
	return ResourceSaver.save(r, DIR + name + ".res")


static func write_record(section: String, values: Dictionary) -> void:
	var cf := ConfigFile.new()
	cf.load(RECORD)
	for k in values:
		cf.set_value(section, String(k), values[k])
	cf.save(RECORD)


func _run() -> void:
	var parts: PackedStringArray = OS.get_cmdline_user_args()
	if parts.is_empty():
		parts = PackedStringArray(["dc", "loft"])
	_main = Bake.load_res("main_skeleton")
	if _main == null:
		print("BAKE no skeleton")
		quit(2)
		return
	if "loft" in parts:
		for o in 4:
			var w: Dictionary = LoftTree.build(_main, Species.loft_opts({"max_order": o}))
			save(w["mesh"], "bl_lf_order_%d" % o)
			print("BAKE loft order %d: %d tets in %.0f ms" % [o, int(w["tets"]), float(w["ms"])])
	if "dc" in parts:
		_queue.append(["bl_dc_wood", {"leaf_mass": true, "min_r_cells": 0.62}, "bl_dc"])
		for o in 4:
			_queue.append(["bl_dc_order_%d" % o, {"max_order": o, "min_r_cells": 0.62}, ""])
	_next()


func _next() -> void:
	if _queue.is_empty():
		print("BAKE done")
		quit()
		return
	var job: Array = _queue.pop_front()
	if _dc != null:
		_dc.queue_free()
	_dc = Node4D.new()
	_dc.set_script(DC)
	_dc.set("cell", CELL)
	_dc.set("w_stretch", float(Species.form()["w_stretch"]))
	root.add_child(_dc)
	_dc.connect("built", func(r: Dictionary) -> void: _done(job, r))
	_dc.call("start", _main, job[1])


func _done(job: Array, r: Dictionary) -> void:
	save(r["mesh"], String(job[0]))
	var rec: Dictionary = {"cell": CELL, "edits": r["edits"], "load_ms": r.get("load_ms", 0.0), "edit_ms": r.get("edit_ms", 0.0),
		"mesh_ms": r.get("mesh_ms", 0.0), "read_ms": r.get("read_ms", 0.0), "label_ms": r.get("label_ms", 0.0), "chunks": r.get("chunks", 0),
		"tets": r["tets"], "vertices": r.get("vertices", 0), "date": _date}
	rec["build_ms"] = float(rec["load_ms"]) + float(rec["edit_ms"]) + float(rec["mesh_ms"]) + float(rec["read_ms"]) + float(rec["label_ms"])
	if not String(job[2]).is_empty():
		write_record(String(job[2]), rec)
	print("BAKE %s: %d tets, %d edits, %.0f ms" % [job[0], int(r["tets"]), int(r["edits"]), float(rec["build_ms"])])
	(func() -> void: _next()).call_deferred()
