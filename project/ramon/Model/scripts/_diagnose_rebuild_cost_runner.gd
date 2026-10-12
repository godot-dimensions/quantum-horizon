extends SceneTree

## Times a rebuild of each rig, split into the work that HAS to happen and the work
## that only answers "is this model sound".
##
## Dragging a ball rebuilds its whole rig every frame, so the question is not how long
## a build takes but how much of that time buys anything while a ball is in motion.
## The three diagnostic passes report on the finished model; the intermediate shapes a
## ball sweeps through are not a model anyone is keeping, so their answers are thrown
## away. Winding is not a diagnostic - it rewrites the cells - so it always runs.

const _Builder = preload("res://ramon/Model/scripts/loft_builder_4d.gd")
const _RUNS: int = 5

var _instance: Node
var _done: bool = false


func _initialize() -> void:
	_instance = (load("res://ramon/Model/model.tscn") as PackedScene).instantiate()
	root.add_child(_instance)


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	print("%-24s %10s %10s %8s" % ["rig", "drag (ms)", "build (ms)", "cells"])
	for group in _instance.get_node("Models").get_children():
		for rig in group.get_children():
			if rig is MeshInstance4D and rig.has_method("build"):
				_time("%s/%s" % [group.name, rig.name], rig)
	return true


func _time(label: String, rig: Node) -> void:
	rig.verbose = false
	var cells: int = 0
	var drag_us: int = 0
	var build_us: int = 0
	for run in range(_RUNS):
		var start: int = Time.get_ticks_usec()
		rig.build(false) # Live rebuild: diagnostics skipped.
		drag_us += Time.get_ticks_usec() - start
		start = Time.get_ticks_usec()
		rig.build(true) # Explicit build: everything checked.
		build_us += Time.get_ticks_usec() - start
		if rig.mesh != null:
			cells = rig.mesh.get_simplex_cell_vertex_indices().size() / 4
	print("%-24s %10.1f %10.1f %8d" % [
		label,
		float(drag_us) / float(_RUNS) / 1000.0,
		float(build_us) / float(_RUNS) / 1000.0,
		cells])
