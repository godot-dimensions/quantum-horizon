extends "res://ramon/Arboretum/botany_lab/exhibits/bl_tree_exhibit_4d.gd"

## BOTANY LAB (fork, 9 Oct; plan steps 42-47; Ramon: "The fine branch skeleton suggests a more detailed,
## organic representation, while the surrounding geometry is deliberately blocky ... explain the voxel
## system in a visually coherent way"): no gold skeleton. The story is cells from the first frame: THE
## GRID (the trunk and the first branches filling in, cell by cell, in the order they grew), THE CROWN
## (the rest, leaves as cells too), THE COST, THE SLICE, THE WIND. One language: boxes.
##
## Pedestal 01, VX-01: the tree written into 4D cells and drawn one box per cell, the Shrubbery Lab's
## own method (its space colonization, its voxelizing, its box mesher), on the room's shared skeleton
## (botany/voxel_tree_builder.gd). Its story: the skeleton grows, the cells fill in the
## order they grew, the cost, the slice, the wind. Its key: a coarser or finer cell, rebuilt live.
##
## NO class_name (engine_gotchas.md).

const Voxel := preload("res://ramon/Arboretum/botany/voxel_tree_builder.gd")
const Species := preload("res://ramon/Arboretum/botany/tree_species.gd")

## The cell sizes E steps through (metres); the first is the bake's.
const CELLS := [0.125, 0.1875, 0.25]

var _cell_i: int = 0


func _init() -> void:
	method = "voxel"
	tree_height = 4.3


func _load() -> void:
	sk = Bake.load_res("main_skeleton")
	if sk == null:
		sk = Species.grow("specimen")
	_setup_tree()
	record = Bake.record("voxel")
	var wood: Resource = Bake.load_res("vx_wood")
	if wood == null:
		var r: Dictionary = Voxel.build(sk, CELLS[0], Species.voxel_opts())
		wood = r["mesh"]
		record = {"tets": r["tets"], "cells": r["cells"], "build_ms": r["ms"], "cell": CELLS[0]}
		live_note = "built live"
	layer("wood", wood)
	var cells: Array = []
	for k in 6:
		var c: Resource = Bake.load_res("vx_stage_%d" % k)
		if c != null:
			cells.append(c)
	set_stages("cells", cells)


func chapters() -> Array:
	return [
		{"key": "grid", "title": "THE GRID", "length": 7.0,
			"line": "Space is cut into 4D cells of {cell}. A cell is either filled or empty.",
			"callouts": [[1.6, "The trunk first: every cell a branch passes through is filled."],
				[4.2, "{nodes} points of one skeleton, written into the grid in the order they grew."]],
			"eye": Vector4(-3.4, 2.6, 6.2, 0.0), "look": Vector4(0.0, 2.2, 0.0, 0.0), "fov": 0.9},
		{"key": "cells", "title": "THE CROWN", "length": 8.0,
			"line": "The branches and the leaves are cells too, the same size, the same box.",
			"callouts": [[1.8, "{cells} cells, filled in the order the branches grew."],
				[4.6, "Each cell draws only the faces no neighbour hides."]],
			"eye": Vector4(-4.2, 2.8, 5.6, 0.0), "look": Vector4(0.0, 2.2, 0.0, 0.0), "fov": 0.9},
		{"key": "cost", "title": "THE COST", "length": 7.0,
			"line": "In 4D the skin of a tree is a volume, so blocks get expensive fast.",
			"callouts": [[1.6, "{tets} tetrahedra, about {mb} of video memory."],
				[4.2, "Half the cell size would cost about eight times as much."]],
			"eye": Vector4(-2.4, 3.4, 6.8, 0.0), "look": Vector4(0.0, 2.4, 0.0, 0.0), "fov": 0.95},
		{"key": "slice", "title": "THE SLICE", "length": 8.0,
			"line": "It is a 4D tree. You only ever see one 3D slice of it.",
			"callouts": [[1.6, "Slide through W and other branches come and go."],
				[4.4, "This one is {w_depth} deep in W."]],
			"eye": Vector4(-1.2, 3.0, 7.4, 0.0), "look": Vector4(0.0, 2.3, 0.0, 0.0), "fov": 0.95},
		{"key": "wind", "title": "THE WIND", "length": 8.0,
			"line": "One wind moves every tree here, branch by branch.",
			"callouts": [[1.6, "Each branch swings about its base and carries the branches it holds."],
				[4.4, "The wind reads the skeleton, not the surface, so it works on every method."]],
			"eye": Vector4(-3.8, 2.4, 6.0, 0.0), "look": Vector4(0.0, 2.6, 0.0, 0.0), "fov": 0.9},
	]


func play_part(key: String, t: float, length: float) -> Dictionary:
	var u: float = clampf(t / maxf(length, 0.1), 0.0, 1.0)
	match key:
		"grid":
			# The first half of the stages: the trunk and the first branches, cell by cell.
			show_only([])
			var half: int = maxi(stage_count("cells") / 2 - 1, 0)
			show_stage("cells", int(floor(clampf(u / 0.75, 0.0, 1.0) * float(half) + 0.0001)))
		"cells":
			show_only([])
			var from: int = stage_count("cells") / 2
			if u > 0.85:
				show_only(["wood"])
			else:
				show_stage("cells", from + int(floor(clampf(u / 0.7, 0.0, 1.0) * float(stage_count("cells") - 1 - from) + 0.0001)))
		"cost":
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
	out["cell"] = "%.1f cm" % (float(record.get("cell", CELLS[0])) * 100.0)
	out["cells"] = Bake.thousands(int(record.get("cells", 0)))
	return out


func action_label() -> String:
	return "Cell size: %s cm" % ("%.1f" % (CELLS[(_cell_i + 1) % CELLS.size()] * 100.0)).trim_suffix(".0")


## E: the next cell size, the tree voxelized and meshed again here, now, and timed.
func action() -> String:
	_cell_i = (_cell_i + 1) % CELLS.size()
	var c: float = CELLS[_cell_i]
	var r: Dictionary = Voxel.build(sk, c, Species.voxel_opts({"leaf_r": maxf(float(Species.form()["leaf_r"]), c * 1.6)}))
	layer("wood", r["mesh"])
	record = record.duplicate()
	record["tets"] = r["tets"]
	record["cells"] = r["cells"]
	record["cell"] = c
	record["build_ms"] = r["ms"]
	live_note = "rebuilt live at %.1f cm" % (c * 100.0)
	show_only(["wood"])
	return "Cells of %.1f cm: %s cells, %s tetrahedra, built live in %s" % [c * 100.0, Bake.thousands(r["cells"]), Bake.thousands(r["tets"]), Bake.ms(r["ms"])]


func card() -> Dictionary:
	var c: float = float(record.get("cell", CELLS[0]))
	return {
		"short": "The skeleton written into a 4D grid of cells, every filled cell drawn as a box.",
		"code": "VX-01", "title": "Voxels", "kicker": "THE SHRUBBERY LAB'S METHOD",
		"method": "The skeleton is written into a 4D grid of %.1f cm cells: every cell a branch passes through is filled, and leaf cells in a 4D ball round each twig end. Each cell is drawn as a box, only the faces with an empty neighbour." % (c * 100.0),
		"shows": "The simplest way to make a 4D shape, and how it scales. A box in 4D is bounded by eight cubes, so a tree's skin is a volume of its own.",
		"limits": "Blocky at any size you can afford. Its cost grows with the cube of size over cell, so halving the cell costs about eight times as much.",
		"rows": [["Cells", "%s of %.1f cm" % [Bake.thousands(int(record.get("cells", 0))), c * 100.0]],
			["Tetrahedra", Bake.thousands(int(record.get("tets", 0)))],
			["Video memory", "about %.0f MB" % Bake.mb(int(record.get("tets", 0)))],
			["Built in", Bake.ms(float(record.get("build_ms", 0.0))) + " in GDScript"]],
		"tier": ("PRE-BAKED " + String(record.get("date", ""))) if live_note.is_empty() else "GROWN LIVE, " + live_note,
		"key": action_label(),
	}
