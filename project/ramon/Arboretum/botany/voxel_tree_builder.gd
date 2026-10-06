extends RefCounted

## The Arboretum: a tree written into 4D cells and drawn one box per cell (the Shrubbery Lab's
## method: carried/shrubbery/shrub_generator.gd voxelize() and shrub_mesh_builder_blocky.gd), here
## from the shared skeleton so it is the same tree as the others, and with every cell carrying its
## branch so the room's wind moves it.
##
##   voxelize(sk, cell, opts)   {Vector4i cell: Vector3 uvw}: every cell whose centre is inside a
##                              branch (a tube from node to node, its radius running from one end's
##                              to the other's, never thinner than half a cell, as the Shrubbery Lab
##                              does, or opts "min_r_cells" cells), then leaves: a 4D ball of leaf
##                              cells round every twig end and round nodes carrying few twigs (opts
##                              "leaf_r", "leaf_twigs"). Wood is written first, trunk first, and a
##                              cell keeps what wrote it first.
##   mesh(voxels, cell)         the boxes: for each cell, each of its eight 3D faces (a 4D box is
##                              bounded by eight cubes) whose neighbour is empty, as five tetrahedra
##                              (SubdividedBox's own decomposition, carried). Faces of filled
##                              neighbours are never drawn: inside, nobody can see them.
##   build(sk, cell, opts)      both, with the counts and times.
##
## In 4D a surface is a volume: a box's skin is eight cubes, and a tree's skin a three-dimensional
## thing, so its cost grows with (size / cell) cubed, not squared. That is the whole story of this
## pedestal's numbers.
##
## NO class_name (engine_gotchas.md): preload it.

const SubdividedBox := preload("res://ramon/Arboretum/carried/shrubbery/subdivided_box_tetra_mesh_4d.gd")
const Pivots := preload("res://ramon/Arboretum/botany/tree_pivots.gd")
const Style := preload("res://ramon/Arboretum/botany/botany_style.gd")
const Skel := preload("res://ramon/Arboretum/botany/tree_skeleton_4d.gd")

## The neighbour each face looks at, in the order the face templates are built.
const OFFSETS: Array[Vector4i] = [
	Vector4i(-1, 0, 0, 0), Vector4i(1, 0, 0, 0),
	Vector4i(0, -1, 0, 0), Vector4i(0, 1, 0, 0),
	Vector4i(0, 0, -1, 0), Vector4i(0, 0, 1, 0),
	Vector4i(0, 0, 0, -1), Vector4i(0, 0, 0, 1),
]


static func _key(p: Vector4, cell: float) -> Vector4i:
	return Vector4i(floori(p.x / cell), floori(p.y / cell), floori(p.z / cell), floori(p.w / cell))


static func _centre(k: Vector4i, cell: float) -> Vector4:
	return (Vector4(k) + Vector4(0.5, 0.5, 0.5, 0.5)) * cell


## `births`, if given, is filled with each cell's moment of growth: the generator's index of the node
## that wrote it (nodes are numbered in the order they grew), for the stories' growth stages.
static func voxelize(sk: Resource, cell: float, opts: Dictionary = {}, births = null) -> Dictionary:
	var voxels: Dictionary = {}
	var positions: PackedVector4Array = sk.get("positions")
	var radii: PackedFloat32Array = sk.get("radii")
	var node_along: PackedFloat32Array = sk.get("node_along")
	var node_branch: PackedInt32Array = sk.get("node_branch")
	var twigs: PackedInt32Array = sk.get("twigs")
	var branches: Array = sk.get("branches")
	var sink: float = float(opts.get("root_sink", 0.2))
	var min_r: float = cell * float(opts.get("min_r_cells", 0.5))
	for bi in branches.size():
		var nodes: PackedInt32Array = branches[bi]["nodes"]
		var child: bool = int(branches[bi]["parent"]) >= 0
		for k in range(1, nodes.size()):
			var a: Vector4 = positions[nodes[k - 1]]
			var b: Vector4 = positions[nodes[k]]
			var ra: float = radii[nodes[k]] if (k == 1 and child) else radii[nodes[k - 1]]
			var rb: float = radii[nodes[k]]
			var ta: float = 0.0 if (k == 1 and child) else node_along[nodes[k - 1]]
			var tb: float = node_along[nodes[k]]
			if bi == 0 and k == 1 and sink > 0.0:
				a -= Vector4(0, sink, 0, 0)
			_tube(voxels, a, b, ra, rb, ta, tb, bi, cell, Style.WOOD, births, nodes[k], min_r)
	var leaf_r: float = float(opts.get("leaf_r", 0.22))
	var leaf_twigs: int = int(opts.get("leaf_twigs", 2))
	if leaf_r > 0.0:
		for i in positions.size():
			if twigs[i] <= leaf_twigs:
				_ball(voxels, positions[i], leaf_r, node_branch[i], node_along[i], cell, Style.LEAVES, births, i)
	return voxels


## `min_r` the thinnest a tube is drawn (m; half a cell when not given). In 4D the cell centres nearest
## a line can be √3/2 of a cell from it (across the three other axes), so a tube thinner than 0.87 of a
## cell can miss every cell: the grove's 25 cm trees lost their whole trunk that way (case study 5).
static func _tube(voxels: Dictionary, a: Vector4, b: Vector4, ra: float, rb: float, ta: float, tb: float, branch: int, cell: float, material: int, births = null, born: int = 0, min_r: float = -1.0) -> void:
	var half: float = cell * 0.5 if min_r < 0.0 else min_r
	ra = maxf(ra, half)
	rb = maxf(rb, half)
	var r: float = maxf(ra, rb)
	var lo: Vector4i = _key(a.min(b) - Vector4(r, r, r, r), cell)
	var hi: Vector4i = _key(a.max(b) + Vector4(r, r, r, r), cell)
	var ab: Vector4 = b - a
	var l2: float = ab.length_squared()
	for x in range(lo.x, hi.x + 1):
		for y in range(lo.y, hi.y + 1):
			for z in range(lo.z, hi.z + 1):
				for w in range(lo.w, hi.w + 1):
					var key := Vector4i(x, y, z, w)
					if voxels.has(key):
						continue
					var p: Vector4 = _centre(key, cell)
					var t: float = clampf((p - a).dot(ab) / l2, 0.0, 1.0) if l2 > 0.0 else 0.0
					if p.distance_to(a + ab * t) <= lerpf(ra, rb, t):
						voxels[key] = Pivots.uvw(material, branch, lerpf(ta, tb, t))
						if births != null:
							births[key] = born


static func _ball(voxels: Dictionary, c: Vector4, r: float, branch: int, along: float, cell: float, material: int, births = null, born: int = 0) -> void:
	var lo: Vector4i = _key(c - Vector4(r, r, r, r), cell)
	var hi: Vector4i = _key(c + Vector4(r, r, r, r), cell)
	for x in range(lo.x, hi.x + 1):
		for y in range(lo.y, hi.y + 1):
			for z in range(lo.z, hi.z + 1):
				for w in range(lo.w, hi.w + 1):
					var key := Vector4i(x, y, z, w)
					if voxels.has(key):
						continue
					if _centre(key, cell).distance_to(c) <= r:
						voxels[key] = Pivots.uvw(material, branch, along)
						if births != null:
							births[key] = born


## The eight face templates of one cell (a 4D box of side `cell` round the origin), each as its own
## positions, tetrahedra and outward normals.
static func templates(cell: float) -> Array:
	var half := Vector4(cell, cell, cell, cell) * 0.5
	var subs := PackedInt32Array([1, 1, 1, 1])
	var out: Array = []
	for axis in range(4):
		for sign_index in range(2):
			var face := ArrayTetraMesh4D.new()
			SubdividedBox._build_cell(face, half, subs, axis, -1.0 if sign_index == 0 else 1.0, 0.0)
			face.calculate_boundary_normals()
			out.append({"positions": face.get_vertex_positions(), "cells": face.get_simplex_cell_vertex_indices(),
				"normals": face.get_simplex_cell_boundary_normals()})
	return out


## `only` (a set of keys) limits it to those cells while still culling against every cell (the
## growth stages draw a part of the tree as the whole tree would hide it).
static func mesh(voxels: Dictionary, cell: float, only: Dictionary = {}) -> ArrayTetraMesh4D:
	var tpl: Array = templates(cell)
	var pos := PackedVector4Array()
	var cells := PackedInt32Array()
	var normals := PackedVector4Array()
	var tex := PackedVector3Array()
	var tind := PackedInt32Array()
	var limit: bool = not only.is_empty()
	for key in voxels:
		if limit and not only.has(key):
			continue
		var centre: Vector4 = _centre(key, cell)
		var ti: int = tex.size()
		var wrote: bool = false
		for f in 8:
			var nk: Vector4i = key + OFFSETS[f]
			if voxels.has(nk) and (not limit or only.has(nk)):
				continue
			var t: Dictionary = tpl[f]
			var base: int = pos.size()
			for p in (t["positions"] as PackedVector4Array):
				pos.append(p + centre)
			for c in (t["cells"] as PackedInt32Array):
				cells.append(c + base)
				tind.append(ti)
			normals.append_array(t["normals"])
			wrote = true
		if wrote:
			tex.append(voxels[key])
	var out := ArrayTetraMesh4D.new()
	out.set_vertex_positions(pos)
	out.set_simplex_cell_vertex_indices(cells)
	out.set_texture_map_values(tex)
	out.set_simplex_cell_texture_map_indices(tind)
	out.set_simplex_cell_boundary_normals(normals)
	return out


## opts "w_stretch": the tree is voxelized squeezed in W by this much and its mesh stretched back, so
## its cells are that many times deeper in W than across (tree_skeleton_4d.gd squeezed()).
static func build(sk: Resource, cell: float, opts: Dictionary = {}) -> Dictionary:
	var t0: int = Time.get_ticks_usec()
	var births: Dictionary = {}
	var ks: float = float(opts.get("w_stretch", 1.0))
	var src: Resource = sk.call("squeezed", ks) if ks != 1.0 else sk
	var voxels: Dictionary = voxelize(src, cell, opts, births)
	var t1: int = Time.get_ticks_usec()
	var m: ArrayTetraMesh4D = mesh(voxels, cell)
	Skel.stretch_w(m, ks)
	var t2: int = Time.get_ticks_usec()
	var wood: int = 0
	for k in voxels:
		if int(round((voxels[k] as Vector3).x * 255.0)) == Style.WOOD:
			wood += 1
	return {"mesh": m, "voxels": voxels, "births": births, "w_stretch": ks, "cells": voxels.size(), "wood_cells": wood, "tets": m.get_simplex_cell_vertex_indices().size() / 4,
		"voxelize_ms": (t1 - t0) / 1000.0, "mesh_ms": (t2 - t1) / 1000.0, "ms": (t2 - t0) / 1000.0}


## The tree as it stood when the generator had grown its first `upto` nodes: only the cells written
## by those nodes, culled as the whole tree culls them.
static func stage(voxels: Dictionary, births: Dictionary, cell: float, upto: int, w_stretch: float = 1.0) -> ArrayTetraMesh4D:
	var only: Dictionary = {}
	for k in births:
		if int(births[k]) < upto:
			only[k] = true
	var m: ArrayTetraMesh4D = mesh(voxels, cell, only)
	Skel.stretch_w(m, w_stretch)
	return m
