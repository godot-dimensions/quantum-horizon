extends Node4D

## BOTANY LAB (fork of botany/dc_tree_builder_4d.gd, 9 Oct; plan steps 48-52): the same builder, two
## options more for edits_for():
##   "leaf_mass"  the leaves as masses (Ramon: "These read as a collection of little balls rather than
##                convincing vegetation ... Larger, more cohesive foliage masses. Irregular, organic
##                silhouettes. Fewer obvious individual spheres. Subtle shape variation within each
##                clump"): instead of one 0.22 m ball at every node near a tip, a clump of three bigger
##                balls (0.30 to 0.48 m) at outer twig ends at least `mass_spacing` apart, each ball
##                pushed off the clump's middle at random (seeded). Balls of one material overlap into
##                one surface in the engine's voxel world, so a clump is one lumpy mass, and close
##                clumps run together into the crown's larger masses.
##   "max_order"  only the branches up to that order and no leaves: the smooth growth stages
##                (bl_dc_order_0..3), so the story never shows the voxel boxes.

## The Arboretum: a tree grown in the engine's own voxel world (VoxelWorld4D, 4Denthusiast's, in
## engine/modules/4d/voxel/), meshed by DUAL CONTOURING in C++. Each edge of the voxel grid that
## crosses the surface keeps where it crosses and the surface's direction there; each cell then
## gets one point, placed where those crossings agree best (a small least-squares solve), and the
## cells' points are joined into the surface. So the 4D cells are the same 12.5 cm as the voxel
## tree's, but the surface runs through them instead of along their faces.
##
## HOW IT IS GROWN HERE (start()):
##   1. A world of air the size of the tree, scaled so one voxel is `cell` metres, and a load trigger
##      over it. The engine generates the chunks on worker threads; an edit into a chunk that is not
##      there yet is lost (measured), so the edits wait until the tree's corners are defined.
##   2. Every branch as a chain of 4D spheres (SphereVoxelEdit4D), half a radius apart, its radius
##      running from one node's to the next; the leaves as 4D balls of a second material round the
##      twig ends. Writing a material over itself is a union in this engine (the farther crossing
##      wins), so overlapping spheres make one smooth limb.
##   3. The engine meshes the changed chunks, 16 a frame. When the count of tetrahedra has held for a
##      few frames, the chunks are read back into ONE mesh in the tree's own metres, and every vertex
##      is given its nearest branch (tree_pivots.gd Index) so the room's wind can move it.
## `live` spreads the edits over frames so you watch the tree arrive chunk by chunk; the chunk
## meshes show in the engine's own palette until the read-back swaps in the room's bark.
##
## signal built(result): {"mesh", "tets", "edits", "load_ms", "edit_ms", "mesh_ms", "read_ms",
## "label_ms", "chunks"}.
##
## NO class_name (engine_gotchas.md).

signal built(result: Dictionary)

const Pivots := preload("res://ramon/Arboretum/botany/tree_pivots.gd")
const Style := preload("res://ramon/Arboretum/botany/botany_style.gd")

const AIR := 254

var cell: float = 0.125
## Spheres per radius along a branch (0.5: half a radius apart).
var spacing: float = 0.5
## Edits sent per frame while `live` (all at once otherwise).
var edits_per_frame: int = 140
var live: bool = false
## Keep the engine's world after the read-back (its chunks hidden), or free it.
var keep_world: bool = false
## Grown squeezed in W by this much and stretched back on read-back: the cells (and every branch)
## that many times deeper in W than across; the engine's world is scaled the same way while it grows.
var w_stretch: float = 1.0

var world: Node4D
var phase: String = "idle"
var _trigger: Node4D
var _sk: Resource
var _edits: Array = []
var _sent: int = 0
var _probe: Array = []
var _stable: int = 0
var _last: int = -1
var _t: int = 0
var _result: Dictionary = {}
var _frames: int = 0


## The edits for skeleton `sk`: [centre (voxels), radius (voxels), material].
static func edits_for(sk: Resource, cell: float, spacing: float, opts: Dictionary = {}) -> Array:
	var out: Array = []
	var positions: PackedVector4Array = sk.get("positions")
	var radii: PackedFloat32Array = sk.get("radii")
	var twigs: PackedInt32Array = sk.get("twigs")
	var branches: Array = sk.get("branches")
	var sink: float = float(opts.get("root_sink", 0.2))
	# The thinnest sphere (m): 0.62 of a cell unless opts "min_r_cells" says otherwise (0.87 always
	# reaches a sample point, case study 5).
	var min_r: float = cell * float(opts.get("min_r_cells", 0.62))
	var max_order: int = int(opts.get("max_order", -1))
	for bi in branches.size():
		if max_order >= 0 and int(branches[bi].get("order", 0)) > max_order:
			continue
		var nodes: PackedInt32Array = branches[bi]["nodes"]
		var child: bool = int(branches[bi]["parent"]) >= 0
		for k in range(1, nodes.size()):
			var a: Vector4 = positions[nodes[k - 1]]
			var b: Vector4 = positions[nodes[k]]
			if bi == 0 and k == 1 and sink > 0.0:
				a -= Vector4(0, sink, 0, 0)
			var ra: float = maxf(radii[nodes[k]] if (k == 1 and child) else radii[nodes[k - 1]], min_r)
			var rb: float = maxf(radii[nodes[k]], min_r)
			var step: float = maxf(minf(ra, rb) * spacing, cell * 0.25)
			var n: int = maxi(1, int(ceil(a.distance_to(b) / step)))
			for s in n + 1:
				if s == 0 and k > 1:
					continue
				var f: float = float(s) / float(n)
				out.append([a.lerp(b, f) / cell, lerpf(ra, rb, f) / cell, Style.WOOD])
	var leaf_r: float = float(opts.get("leaf_r", 0.22))
	var leaf_twigs: int = int(opts.get("leaf_twigs", 2))
	if max_order >= 0:
		return out
	if bool(opts.get("leaf_mass", false)):
		out.append_array(_masses(sk, cell, opts))
	elif leaf_r > 0.0:
		for i in positions.size():
			if twigs[i] <= leaf_twigs:
				out.append([positions[i] / cell, leaf_r / cell, Style.LEAVES])
	return out


## The leaves as masses (see the header): clump middles at the outer twig ends, `mass_spacing` apart
## at least; three balls each, the first near the middle, the others pushed off it, all of their own
## size. W offsets are small: the skeleton is squeezed in W here (w_stretch) and stretched after.
static func _masses(sk: Resource, cell: float, opts: Dictionary) -> Array:
	var out: Array = []
	var positions: PackedVector4Array = sk.get("positions")
	var twigs: PackedInt32Array = sk.get("twigs")
	var rng := RandomNumberGenerator.new()
	rng.seed = int(opts.get("mass_seed", 7))
	var spacing: float = float(opts.get("mass_spacing", 0.55))
	var r_lo: float = float(opts.get("mass_r_min", 0.30))
	var r_hi: float = float(opts.get("mass_r_max", 0.48))
	var jitter: float = float(opts.get("mass_jitter", 0.26))
	var w_jitter: float = float(opts.get("mass_w_jitter", 0.06))
	var centres: Array = []
	for i in positions.size():
		if twigs[i] > 1:
			continue
		var p: Vector4 = positions[i]
		var crowded: bool = false
		for c in centres:
			if (c as Vector4).distance_to(p) < spacing:
				crowded = true
				break
		if not crowded:
			centres.append(p)
	for c in centres:
		for k in 3:
			var off := Vector4(rng.randf_range(-jitter, jitter), rng.randf_range(-jitter * 0.6, jitter), rng.randf_range(-jitter, jitter), rng.randf_range(-w_jitter, w_jitter))
			if k == 0:
				off *= 0.3
			out.append([((c as Vector4) + off) / cell, rng.randf_range(r_lo, r_hi) / cell, Style.LEAVES])
	return out


## Grows `sk` in a world of its own under this node.
func start(sk: Resource, opts: Dictionary = {}) -> void:
	_clear()
	_sk = sk.call("squeezed", w_stretch) if w_stretch != 1.0 else sk
	sk = _sk
	_edits = edits_for(sk, cell, spacing, opts)
	_sent = 0
	world = ClassDB.instantiate("VoxelWorld4D")
	world.name = "VoxelWorld"
	var gen = ClassDB.instantiate("BoxVoxelGenerator4D")
	gen.set("material_inner", AIR)
	gen.set("material_outer", AIR)
	world.set("generator", gen)
	var pal = ClassDB.instantiate("VoxelMaterialPalette4D")
	# The engine's own colours while it grows: index = material.
	pal.set("colors", PackedColorArray([Color(0.6, 0.6, 0.6), Style.BARK, Style.LEAF]))
	world.set("material_palette", pal)
	world.set("scale", Vector4(cell, cell, cell, cell * w_stretch))
	add_child(world)
	var bb: Dictionary = sk.call("bounds")
	var lo: Vector4 = bb["min"] - Vector4(0.6, 0.6, 0.6, 0.6)
	var hi: Vector4 = bb["max"] + Vector4(0.6, 0.6, 0.6, 0.6)
	var mid: Vector4 = (lo + hi) * 0.5
	_trigger = ClassDB.instantiate("VoxelLoadTrigger4D")
	_trigger.name = "LoadTrigger"
	add_child(_trigger)
	_trigger.set("voxel_world_path", _trigger.get_path_to(world))
	_trigger.set("position", Vector4(mid.x, mid.y, mid.z, mid.w * w_stretch))
	# A chunk loads when its centre is in range: add a chunk's half diagonal (8 voxels).
	_trigger.set("load_distance", ((hi - lo) * 0.5).length() / cell + 12.0)
	_probe = []
	for corner in [lo, hi, mid, Vector4(lo.x, hi.y, lo.z, hi.w), Vector4(hi.x, lo.y, hi.z, lo.w), Vector4(lo.x, lo.y, hi.z, hi.w)]:
		_probe.append(Vector4i((corner / cell).floor()))
	_result = {"edits": _edits.size()}
	phase = "load"
	_t = Time.get_ticks_usec()
	_frames = 0


func _clear() -> void:
	if world != null and is_instance_valid(world):
		world.queue_free()
	if _trigger != null and is_instance_valid(_trigger):
		_trigger.queue_free()
	world = null
	_trigger = null
	phase = "idle"


func _defined() -> bool:
	var data = world.call("get_voxel_data")
	for c in _probe:
		if not bool(data.call("is_voxel_defined", c)):
			return false
	return true


func _chunks() -> Array:
	var out: Array = []
	if world == null:
		return out
	for child in world.get_children():
		if child is MeshInstance4D and (child as MeshInstance4D).mesh != null:
			out.append(child)
	return out


## Tetrahedra the engine has made so far.
func tets_now() -> int:
	var n: int = 0
	for m in _chunks():
		n += ((m as MeshInstance4D).mesh as TetraMesh4D).get_simplex_cell_vertex_indices().size() / 4
	return n


## How far along it is, 0 to 1 (for a progress bar).
func progress() -> float:
	match phase:
		"load":
			return 0.05
		"edit":
			return 0.05 + 0.6 * float(_sent) / maxf(float(_edits.size()), 1.0)
		"mesh":
			return 0.7
		"read":
			return 0.9
		"done":
			return 1.0
	return 0.0


func _process(_d: float) -> void:
	if phase == "idle" or phase == "done" or world == null:
		return
	_frames += 1
	if phase == "load":
		if _defined():
			_result["load_ms"] = (Time.get_ticks_usec() - _t) / 1000.0
			_t = Time.get_ticks_usec()
			_result["edit_ms"] = 0.0
			phase = "edit"
		return
	if phase == "edit":
		var t: int = Time.get_ticks_usec()
		var upto: int = _edits.size() if not live else mini(_edits.size(), _sent + edits_per_frame)
		for i in range(_sent, upto):
			var e: Array = _edits[i]
			var ed = ClassDB.instantiate("SphereVoxelEdit4D")
			ed.set("center", e[0])
			ed.set("radius", e[1])
			ed.set("fill_material", e[2])
			world.call("apply_edit", ed)
		_sent = upto
		_result["edit_ms"] = float(_result["edit_ms"]) + (Time.get_ticks_usec() - t) / 1000.0
		if _sent >= _edits.size():
			phase = "mesh"
			_t = Time.get_ticks_usec()
			_stable = 0
			_last = -1
		return
	if phase == "mesh":
		var n: int = tets_now()
		_stable = _stable + 1 if (n == _last and n > 0) else 0
		_last = n
		if _stable >= 4:
			_result["mesh_ms"] = (Time.get_ticks_usec() - _t) / 1000.0
			_result["chunks"] = _chunks().size()
			phase = "read"
			_read_back()


## The chunks into one mesh in metres, each vertex labelled with its branch.
func _read_back() -> void:
	var t0: int = Time.get_ticks_usec()
	var pos := PackedVector4Array()
	var cells := PackedInt32Array()
	var normals := PackedVector4Array()
	var mats := PackedInt32Array()
	for m in _chunks():
		var mi := m as MeshInstance4D
		var am: ArrayTetraMesh4D = (mi.mesh as TetraMesh4D).to_array_tetra_mesh()
		var base: int = pos.size()
		var off: Vector4 = mi.position
		var vp: PackedVector4Array = am.get_vertex_positions()
		var start_mats: int = mats.size()
		for p in vp:
			pos.append((p + off) * cell)
			mats.append(Style.WOOD)
		var vi: PackedInt32Array = am.get_simplex_cell_vertex_indices()
		var tv: PackedVector3Array = am.get_texture_map_values()
		var ti: PackedInt32Array = am.get_simplex_cell_texture_map_indices()
		for s in vi.size():
			cells.append(vi[s] + base)
			if s < ti.size() and ti[s] < tv.size():
				mats[start_mats + vi[s]] = int(round(tv[ti[s]].x * 255.0))
		normals.append_array(am.get_simplex_cell_boundary_normals())
	var t1: int = Time.get_ticks_usec()
	var index := Pivots.Index.new(_sk, 0.35)
	var tex := PackedVector3Array()
	tex.resize(pos.size())
	for i in pos.size():
		var nb: Array = index.nearest(pos[i])
		tex[i] = Pivots.uvw(mats[i], int(nb[0]), float(nb[1]))
	if w_stretch != 1.0:
		for i in pos.size():
			var p: Vector4 = pos[i]
			p.w *= w_stretch
			pos[i] = p
	var out := ArrayTetraMesh4D.new()
	out.set_vertex_positions(pos)
	out.set_simplex_cell_vertex_indices(cells)
	out.set_texture_map_values(tex)
	# One texture value per vertex: each corner of a cell reads its own vertex's.
	out.set_simplex_cell_texture_map_indices(cells)
	out.set_simplex_cell_boundary_normals(normals)
	_result["read_ms"] = (t1 - t0) / 1000.0
	_result["label_ms"] = (Time.get_ticks_usec() - t1) / 1000.0
	_result["mesh"] = out
	_result["tets"] = cells.size() / 4
	_result["vertices"] = pos.size()
	if keep_world:
		world.visible = false
	else:
		_clear()
	phase = "done"
	built.emit(_result)
