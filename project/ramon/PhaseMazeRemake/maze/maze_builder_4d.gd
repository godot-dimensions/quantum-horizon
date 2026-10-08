extends RefCounted

## Builds a maze lattice (maze_lattice.gd) into nodes (PLAN.md steps 17 to 27): walls, their collision,
## the floor, the breadcrumb tiles, the W door marks, the start ring and the exit's pad and beacon.
##
## SIZES (both probes, RESEARCH.md sections 4 and 5): 6 m cells, walls 5 m tall (the chase camera
## never sees over them) and 0.4 m thick (a slice half way through a turn cuts them cleanly; at 0.2 m
## they fell apart into slivers).
##
## ONE MESH PER WALL, NOT ONE PER LAYER. 4D sight (maze_sight_4d.gd) lets exactly the cells beside yours
## along the hidden axis project their ghosts, and only the walls that stand across what you see; a
## mesh per layer would ghost a whole layer, or your own walls with it. A 3 x 3 x 3 level is about 90
## walls, far under the engine's shader-slot limit (engine_capabilities.md).
##
## THE GHOST COLOUR rides on each wall material's albedo. The lab grid shader colours the solid wall from
## its own swatch and never reads albedo; the projected pass (tetra_projected_shader.glsl:270) colours a
## ghost with albedo alone. So every wall is white or cyan where you stand and a cyan ghost in the world
## next door (RESEARCH.md section 5).
##
## NO class_name (engine_gotchas.md): preload it.

const LabGrid := preload("res://ramon/PhaseMazeRemake/carried/LabKit/lab_grid.gd")
const LabBatch := preload("res://ramon/PhaseMazeRemake/carried/LabKit/lab_batch.gd")
const LabMaterials := preload("res://ramon/PhaseMazeRemake/carried/LabKit/lab_materials.gd")
const Style := preload("res://ramon/PhaseMazeRemake/maze/maze_style.gd")
const Lattice := preload("res://ramon/PhaseMazeRemake/maze/maze_lattice.gd")

const HEIGHT := 5.0
const THICK := 0.4
## Breadcrumb tiles wait here, under the floor, until their cell is visited (moving a mesh is free;
## showing a hidden one for the first time builds its draw buffers in that frame).
const PARKED_Y := -2.0
const TILE_Y := 0.012


## Everything for one level under `parent` (a fresh Node4D the game frees on the next level).
## Returns {"walls": [{mesh, cells: [a, b], axis}], "cell_walls": {cell: [[axis, mesh], ...]},
## "tiles": {cell: MeshInstance4D}, "body": StaticBody4D, "exit_at": Vector4, "beacon": Node4D}.
static func build(parent: Node4D, lv) -> Dictionary:
	var c: float = lv.cell
	var out: Dictionary = {"walls": [], "cell_walls": {}, "tiles": {}}
	var body := StaticBody4D.new()
	body.name = "Walls"
	parent.add_child(body)
	out["body"] = body
	var walls_node := Node4D.new()
	walls_node.name = "WallMeshes"
	parent.add_child(walls_node)
	var batch := LabBatch.new()
	var ghost: Color = Style.role("ghost")
	# Every face once: the + side of every cell, and the - side of the cells on the low edge.
	for k in lv.nw:
		for j in lv.nz:
			for i in lv.nx:
				var cell := Vector3i(i, j, k)
				for a in 3:
					for s in [1, -1]:
						var n: Vector3i = cell + Lattice.STEPS[a] * s
						if s < 0 and lv.inside(n):
							continue
						if lv.is_open(cell, a, s):
							continue
						var mi: MeshInstance4D = _wall(walls_node, body, batch, lv, cell, a, s, ghost)
						var cells: Array = [cell]
						if lv.inside(n):
							cells.append(n)
						out["walls"].append({"mesh": mi, "cells": cells, "axis": a})
						for owner in cells:
							if not out["cell_walls"].has(owner):
								out["cell_walls"][owner] = []
							out["cell_walls"][owner].append([a, mi])
	# The caps: one batched mesh, the kit's dark edge line along every wall top.
	var caps: MeshInstance4D = batch.instance("caps")
	caps.name = "Caps"
	caps.material_override = LabGrid.material("maze_cap", Vector4.ONE, Vector4.ZERO)
	caps.set("allow_projection", false)
	parent.add_child(caps)
	_floor(parent, lv)
	out["tiles"] = _tiles(parent, lv)
	_marks(parent, lv, out)
	return out


static func _wall(walls_node: Node4D, body: StaticBody4D, batch, lv, cell: Vector3i, a: int, s: int, ghost: Color) -> MeshInstance4D:
	var c: float = lv.cell
	var span: float = c + THICK
	var size := Vector4(span, HEIGHT, span, span)
	var off := Vector4.ZERO
	match a:
		0:
			size.x = THICK
			off.x = c * 0.5 * float(s)
		1:
			size.z = THICK
			off.z = c * 0.5 * float(s)
		2:
			size.w = THICK
			off.w = c * 0.5 * float(s)
	var at: Vector4 = lv.cell_centre(cell) + off + Vector4(0.0, HEIGHT * 0.5, 0.0, 0.0)
	var mi := MeshInstance4D.new()
	mi.name = "Wall_%d_%d_%d_%s%s" % [cell.x, cell.y, cell.z, "+" if s > 0 else "-", Lattice.AXES[a]]
	var mesh := BoxTetraMesh4D.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = at
	var m: TetraMaterial4D = LabGrid.material("maze_wall_w" if a == 2 else "maze_wall", size, at)
	m.albedo_color = ghost
	mi.material_override = m
	mi.set("allow_projection", false)
	walls_node.add_child(mi)
	var shape := CollisionShape4D.new()
	var box := BoxShape4D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	body.add_child(shape)
	var cap := Vector4(size.x + 0.02, 0.06, size.z + 0.02, size.w + 0.02)
	batch.box("caps", cap, at + Vector4(0.0, HEIGHT * 0.5 + 0.03, 0.0, 0.0))
	return mi


## One slab under the whole maze and a margin round it, through all its layers, top at y 0.
static func _floor(parent: Node4D, lv) -> void:
	var b: Array = lv.bounds()
	var lo: Vector4 = b[0]
	var hi: Vector4 = b[1]
	var margin: float = 3.0
	var size := Vector4(hi.x - lo.x + margin * 2.0, 1.0, hi.z - lo.z + margin * 2.0, hi.w - lo.w + margin * 2.0)
	var at := Vector4((lo.x + hi.x) * 0.5, -0.5, (lo.z + hi.z) * 0.5, (lo.w + hi.w) * 0.5)
	var floor_body := StaticBody4D.new()
	floor_body.name = "Floor"
	floor_body.position = at
	var shape := CollisionShape4D.new()
	var box := BoxShape4D.new()
	box.size = size
	shape.shape = box
	floor_body.add_child(shape)
	var mi := MeshInstance4D.new()
	mi.name = "FloorMesh"
	var mesh := BoxTetraMesh4D.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = LabGrid.material("maze_floor", size, at)
	mi.set("allow_projection", false)
	floor_body.add_child(mi)
	parent.add_child(floor_body)


## A tile per cell, parked under the floor until the cell is visited (the game raises and colours it).
## Its own material, so each fades on its own.
static func _tiles(parent: Node4D, lv) -> Dictionary:
	var c: float = lv.cell
	var holder := Node4D.new()
	holder.name = "Trail"
	parent.add_child(holder)
	var out: Dictionary = {}
	var size := Vector4(c - 2.6, 0.02, c - 2.6, c - 1.0)
	for k in lv.nw:
		for j in lv.nz:
			for i in lv.nx:
				var cell := Vector3i(i, j, k)
				var mi := MeshInstance4D.new()
				mi.name = "Tile_%d_%d_%d" % [i, j, k]
				var mesh := BoxTetraMesh4D.new()
				mesh.size = size
				mi.mesh = mesh
				var m := TetraMaterial4D.new()
				m.albedo_color = Style.role("trail")
				mi.material_override = m
				mi.set("allow_projection", false)
				var at: Vector4 = lv.cell_centre(cell)
				mi.position = Vector4(at.x, PARKED_Y, at.z, at.w)
				holder.add_child(mi)
				out[cell] = mi
	return out


## The W doors' cyan plates (both cells of every open edge along W), the start ring, the exit pad and
## the exit's beacon: a green pillar over the walls, standing through every layer, so you can see which
## way the exit lies from anywhere in the level view (Darken and Sibert's global landmark).
static func _marks(parent: Node4D, lv, out: Dictionary) -> void:
	var c: float = lv.cell
	var batch := LabBatch.new()
	for key in lv.open:
		var e: Vector4i = key
		if e.w != 2:
			continue
		for cell in [Vector3i(e.x, e.y, e.z), Vector3i(e.x, e.y, e.z + 1)]:
			var at: Vector4 = lv.cell_centre(cell)
			batch.box("doors", Vector4(2.2, 0.03, 2.2, c - 1.0), at + Vector4(0.0, 0.03, 0.0, 0.0))
			batch.box("doors_in", Vector4(1.5, 0.035, 1.5, c - 1.0), at + Vector4(0.0, 0.032, 0.0, 0.0))
	var s_at: Vector4 = lv.cell_centre(lv.start)
	batch.ring("start", s_at + Vector4(0.0, 0.03, 0.0, 0.0), 1.5, 0.14, 0.035, c - 1.0, 48)
	var e_at: Vector4 = lv.cell_centre(lv.exit)
	batch.box("exit", Vector4(3.0, 0.04, 3.0, c - 1.0), e_at + Vector4(0.0, 0.03, 0.0, 0.0))
	batch.ring("exit_ring", e_at + Vector4(0.0, 0.035, 0.0, 0.0), 2.1, 0.12, 0.04, c - 1.0, 48)
	var all_w: float = float(lv.nw) * c + 2.0
	var mid_w: float = lv.origin.w + (float(lv.nw) - 1.0) * c * 0.5
	batch.box("beacon", Vector4(0.6, 14.0, 0.6, all_w), Vector4(e_at.x, HEIGHT + 0.8 + 7.0, e_at.z, mid_w))
	var looks := {
		"doors": LabMaterials.glow(Style.glow("w"), 1.0),
		"doors_in": LabMaterials.glow(Style.role("w").darkened(0.35), 1.0),
		"start": LabMaterials.glow(Style.glow("start"), 1.1),
		"exit": LabMaterials.glow(Style.role("exit"), 1.0),
		"exit_ring": LabMaterials.glow(Style.glow("exit"), 1.2),
		"beacon": LabMaterials.glow(Style.glow("exit"), 1.3),
	}
	for kind in batch.kinds():
		var mi: MeshInstance4D = batch.instance(kind)
		mi.material_override = looks.get(kind, LabMaterials.glow(Color.WHITE, 1.0))
		mi.set("allow_projection", kind == "beacon")
		parent.add_child(mi)
		if kind == "beacon":
			out["beacon"] = mi
	out["exit_at"] = e_at
