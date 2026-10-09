extends RefCounted

## Builds a maze lattice (maze_lattice.gd) into nodes (PLAN.md steps 17 to 27; round 2's R3 to R7): walls,
## raised floors and stairs with their collision, the floor, the breadcrumb tiles, the W door marks, the
## start ring and the exit's pad and beacon.
##
## SIZES (both probes, RESEARCH.md sections 4 and 5): walls 5 m above the higher floor beside them (the
## chase camera never sees over), 0.4 m thick (a slice half way through a turn cuts them cleanly). Cells
## are the level's own sizes along x, z and w (round 2: narrow lanes and wide halls).
##
## ONE MESH PER WALL, NOT ONE PER LAYER. 4D sight (maze_sight_4d.gd) lets exactly the neighbouring layer
## along the hidden axis project its ghosts, and only the walls that stand across what you see.
##
## THE GHOST COLOUR rides on each wall material's albedo. The lab grid shader colours the solid wall from
## its own swatch and never reads albedo; the projected pass (tetra_projected_shader.glsl:270) colours a
## ghost with albedo alone (RESEARCH.md section 5).
##
## STAIRS are 0.3 m steps (the walker climbs 0.32), boxes stacked from the ground, so the box-only physics
## is exact. A stair along W is a staircase only when you have turned into W; level, you see the one step
## at your W (round 2, R7).
##
## NO class_name (engine_gotchas.md): preload it.

const LabGrid := preload("res://ramon/PhaseMazeRemake/carried/LabKit/lab_grid.gd")
const LabBatch := preload("res://ramon/PhaseMazeRemake/carried/LabKit/lab_batch.gd")
const LabMaterials := preload("res://ramon/PhaseMazeRemake/carried/LabKit/lab_materials.gd")
const Style := preload("res://ramon/PhaseMazeRemake/maze/maze_style.gd")
const Lattice := preload("res://ramon/PhaseMazeRemake/maze/maze_lattice.gd")

const HEIGHT := 5.0
const THICK := 0.4
const STEP := 0.3
## Breadcrumb tiles wait here, under the floor, until their cell is visited (moving a mesh is free;
## showing a hidden one for the first time builds its draw buffers in that frame).
const PARKED_Y := -2.0
const TILE_Y := 0.012


## Everything for one level under `parent` (a fresh Node4D the game frees on the next level).
## Returns {"walls": [{mesh, cells: [a, b], axis}], "cell_walls": {cell: [[axis, mesh], ...]},
## "tiles": {cell: MeshInstance4D}, "body": StaticBody4D, "exit_at": Vector4, "beacon": Node4D}.
static func build(parent: Node4D, lv) -> Dictionary:
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
	var caps: MeshInstance4D = batch.instance("caps")
	caps.name = "Caps"
	caps.material_override = LabGrid.material("maze_cap", Vector4.ONE, Vector4.ZERO)
	caps.set("allow_projection", false)
	parent.add_child(caps)
	_floor(parent, lv)
	_raised(parent, body, lv)
	_roofs(parent, body, lv)
	out["tiles"] = _tiles(parent, lv)
	_marks(parent, lv, out)
	return out


## The wall on `cell`'s face (`a`, `s`): on the cell boundary, the cell's size across, from the ground to
## 5 m over the higher floor of the two cells it stands between.
static func _wall(walls_node: Node4D, body: StaticBody4D, batch, lv, cell: Vector3i, a: int, s: int, ghost: Color) -> MeshInstance4D:
	var sz: Vector3 = lv.size_of(cell)
	var lo: Vector4 = lv.cell_min(cell)
	var n: Vector3i = cell + Lattice.STEPS[a] * s
	var top: float = lv.top_height(cell)
	if lv.inside(n):
		top = maxf(top, lv.top_height(n))
	var h: float = top + HEIGHT
	var size := Vector4(sz.x + THICK, h, sz.y + THICK, sz.z + THICK)
	var at := Vector4(lo.x + sz.x * 0.5, h * 0.5, lo.z + sz.y * 0.5, lo.w + sz.z * 0.5)
	match a:
		0:
			size.x = THICK
			at.x = lo.x + (sz.x if s > 0 else 0.0)
		1:
			size.z = THICK
			at.z = lo.z + (sz.y if s > 0 else 0.0)
		2:
			size.w = THICK
			at.w = lo.w + (sz.z if s > 0 else 0.0)
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
	_collide(body, size, at)
	var cap := Vector4(size.x + 0.02, 0.06, size.z + 0.02, size.w + 0.02)
	batch.box("caps", cap, at + Vector4(0.0, h * 0.5 + 0.03, 0.0, 0.0))
	return mi


static func _collide(body: StaticBody4D, size: Vector4, at: Vector4) -> void:
	var shape := CollisionShape4D.new()
	var box := BoxShape4D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	body.add_child(shape)


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


## Raised floors (a block from the ground up to the cell's height) and stairs (a step every 0.3 m along
## the stair's axis, each a block from the ground), all in the floor's grid and all colliding.
static func _raised(parent: Node4D, body: StaticBody4D, lv) -> void:
	var holder := Node4D.new()
	holder.name = "Floors"
	parent.add_child(holder)
	for k in lv.nw:
		for j in lv.nz:
			for i in lv.nx:
				var c := Vector3i(i, j, k)
				var sz: Vector3 = lv.size_of(c)
				var lo: Vector4 = lv.cell_min(c)
				if lv.stairs.has(c):
					var st: Array = lv.stairs[c]
					var a: int = int(st[0])
					var sgn: int = int(st[1])
					var e: Vector2 = lv.stair_ends(c)
					var n: int = maxi(1, roundi((e.y - e.x) / STEP))
					var span: float = sz[a]
					var low_corner: Array = [lo.x, lo.z, lo.w]
					var comp: int = [0, 2, 3][a]
					for q in n:
						var top: float = e.x + (e.y - e.x) * float(q + 1) / float(n)
						var d0: float = span * float(q) / float(n)
						var d1: float = span * float(q + 1) / float(n)
						if sgn < 0:
							var t0: float = span - d1
							d1 = span - d0
							d0 = t0
						var size := Vector4(sz.x, top, sz.y, sz.z)
						var at := Vector4(lo.x + sz.x * 0.5, top * 0.5, lo.z + sz.y * 0.5, lo.w + sz.z * 0.5)
						size[comp] = d1 - d0
						at[comp] = float(low_corner[a]) + (d0 + d1) * 0.5
						_block(holder, body, "Step_%d_%d_%d_%d" % [i, j, k, q], size, at, "maze_climb")
				else:
					var h: float = float(lv.heights.get(c, 0.0))
					if h > 0.01:
						var size := Vector4(sz.x, h, sz.y, sz.z)
						var at := Vector4(lo.x + sz.x * 0.5, h * 0.5, lo.z + sz.y * 0.5, lo.w + sz.z * 0.5)
						_block(holder, body, "Floor_%d_%d_%d" % [i, j, k], size, at)


## Roofs over the indoor stretches: a ceiling at the walls' top, colliding (so the camera's arm is held
## under it, never popping out above), with a warm light strip down its middle. No shadows in this
## renderer, so the inside reads by the ceiling over you and the strip, not by darkness.
static func _roofs(parent: Node4D, body: StaticBody4D, lv) -> void:
	if lv.roofs.is_empty():
		return
	var holder := Node4D.new()
	holder.name = "Roofs"
	parent.add_child(holder)
	var strips := LabBatch.new()
	for c in lv.roofs:
		var cell: Vector3i = c
		var sz: Vector3 = lv.size_of(cell)
		var lo: Vector4 = lv.cell_min(cell)
		var y: float = lv.top_height(cell) + HEIGHT
		var size := Vector4(sz.x + THICK, 0.3, sz.y + THICK, sz.z + THICK)
		var at := Vector4(lo.x + sz.x * 0.5, y + 0.15, lo.z + sz.y * 0.5, lo.w + sz.z * 0.5)
		_block(holder, body, "Roof_%d_%d_%d" % [cell.x, cell.y, cell.z], size, at, "maze_roof")
		var along_x: bool = sz.x >= sz.y
		strips.box("strip", Vector4(sz.x * 0.7 if along_x else 0.22, 0.04, 0.22 if along_x else sz.y * 0.7, sz.z - 1.0), Vector4(at.x, y - 0.03, at.z, at.w))
	var sm: MeshInstance4D = strips.instance("strip")
	sm.name = "RoofLights"
	sm.material_override = LabMaterials.glow(Style.glow("start"), 1.3)
	sm.set("allow_projection", false)
	holder.add_child(sm)


static func _block(holder: Node4D, body: StaticBody4D, nm: String, size: Vector4, at: Vector4, swatch: String = "maze_floor") -> void:
	var mi := MeshInstance4D.new()
	mi.name = nm
	var mesh := BoxTetraMesh4D.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = at
	mi.material_override = LabGrid.material(swatch, size, at)
	mi.set("allow_projection", false)
	holder.add_child(mi)
	_collide(body, size, at)


## A tile per cell, parked under the floor until the cell is visited (the game raises and colours it).
## Its own material, so each fades on its own. Stairs have none.
static func _tiles(parent: Node4D, lv) -> Dictionary:
	var holder := Node4D.new()
	holder.name = "Trail"
	parent.add_child(holder)
	var out: Dictionary = {}
	for k in lv.nw:
		for j in lv.nz:
			for i in lv.nx:
				var cell := Vector3i(i, j, k)
				if lv.stairs.has(cell):
					continue
				var sz: Vector3 = lv.size_of(cell)
				var size := Vector4(maxf(1.0, sz.x - 2.6), 0.02, maxf(1.0, sz.y - 2.6), maxf(1.0, sz.z - 1.0))
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
	var batch := LabBatch.new()
	for key in lv.open:
		var e: Vector4i = key
		if e.w != 2:
			continue
		for cell in [Vector3i(e.x, e.y, e.z), Vector3i(e.x, e.y, e.z + 1)]:
			if lv.stairs.has(cell):
				continue
			var at: Vector4 = lv.cell_centre(cell)
			var sw: float = lv.size_of(cell).z - 1.0
			batch.box("doors", Vector4(2.2, 0.03, 2.2, sw), at + Vector4(0.0, 0.03, 0.0, 0.0))
			batch.box("doors_in", Vector4(1.5, 0.035, 1.5, sw), at + Vector4(0.0, 0.032, 0.0, 0.0))
	var s_at: Vector4 = lv.cell_centre(lv.start)
	batch.ring("start", s_at + Vector4(0.0, 0.03, 0.0, 0.0), 1.5, 0.14, 0.035, lv.size_of(lv.start).z - 1.0, 48)
	var e_at: Vector4 = lv.cell_centre(lv.exit)
	var ew: float = lv.size_of(lv.exit).z - 1.0
	batch.box("exit", Vector4(3.0, 0.04, 3.0, ew), e_at + Vector4(0.0, 0.03, 0.0, 0.0))
	batch.ring("exit_ring", e_at + Vector4(0.0, 0.035, 0.0, 0.0), 2.1, 0.12, 0.04, ew, 48)
	var b: Array = lv.bounds()
	var all_w: float = (b[1] as Vector4).w - (b[0] as Vector4).w + 2.0
	var mid_w: float = ((b[0] as Vector4).w + (b[1] as Vector4).w) * 0.5
	var tallest: float = 0.0
	for c in lv.heights:
		tallest = maxf(tallest, float(lv.heights[c]))
	batch.box("beacon", Vector4(0.6, 14.0, 0.6, all_w), Vector4(e_at.x, tallest + HEIGHT + 0.8 + 7.0, e_at.z, mid_w))
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
