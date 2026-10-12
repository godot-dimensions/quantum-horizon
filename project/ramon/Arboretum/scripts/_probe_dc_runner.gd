extends SceneTree

## Plan steps 4 and 5: the engine's own voxel world (VoxelWorld4D, dual contouring in C++) as a
## tree. An all-air world scaled to the cell size, a load trigger over the tree, every branch of the
## Shrubbery Lab's skeleton written in as a chain of sphere edits and its leaves as glomes of a second
## material; then the chunk meshes it makes are read back into one mesh in metres.
##
## Prints: how long the world takes to define the region, whether an edit sent before that is lost,
## the edits' own time, how long the meshing takes and how many chunks and tetrahedra it makes, and
## the read-back. Args after --: cell size in metres (default 0.125), sphere spacing as a fraction of
## the radius (default 0.5).

const Gen := preload("res://ramon/Arboretum/carried/shrubbery/shrub_generator.gd")
const Species := preload("res://ramon/Arboretum/carried/shrubbery/shrub_species.gd")

const AIR := 254
const WOOD := 1
const LEAF := 2

var _world: Node4D
var _trigger: Node4D
var _cell: float = 0.125
var _spacing: float = 0.5
var _f: int = 0
var _phase: String = "load"
var _t0: int = 0
var _edits: Array = []
var _probe_cells: Array = []
var _stable: int = 0
var _last_tets: int = -1
var _deadline: int = 0


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_cell = float(args[0])
	if args.size() > 1:
		_spacing = float(args[1])
	_deadline = Time.get_ticks_msec() + 90000
	var sp: Resource = Species.new()
	var g: RefCounted = Gen.new(int(sp.get("seed")))
	g.call("build_trunk", sp)
	g.call("spawn_attractors_from_tesseract", sp)
	g.call("grow", sp)
	var branches: Array = g.get("branches")
	# Edits in voxel units (the world is scaled by the cell size).
	var lo := Vector4(INF, INF, INF, INF)
	var hi := Vector4(-INF, -INF, -INF, -INF)
	var has_child: Dictionary = {}
	var max_gen: int = 0
	for b in branches:
		if int(b.parent_index) >= 0:
			has_child[int(b.parent_index)] = true
		max_gen = maxi(max_gen, int(b.generation))
	for b in branches:
		lo = lo.min(b.position)
		hi = hi.max(b.position)
		if int(b.parent_index) < 0:
			continue
		var a: Vector4 = branches[int(b.parent_index)].position
		var c: Vector4 = b.position
		var r: float = maxf(float(b.thickness) * 0.5, _cell * 0.5)
		var step: float = maxf(r * _spacing, _cell * 0.25)
		var n: int = maxi(1, int(ceil(a.distance_to(c) / step)))
		for k in n + 1:
			_edits.append([a.lerp(c, float(k) / float(n)) / _cell, r / _cell, WOOD])
	var leafy: int = maxi(0, max_gen - int(sp.get("leafy_generation_depth")))
	for i in branches.size():
		var b = branches[i]
		if not has_child.has(i) or int(b.generation) >= leafy:
			_edits.append([b.position / _cell, float(sp.get("leaf_radius")) / _cell, LEAF])
	print("PROBE cell=%.3f spacing=%.2f branches=%d edits=%d extent=%s" % [_cell, _spacing, branches.size(), _edits.size(), str(hi - lo)])

	var scene := Node4D.new()
	root.add_child(scene)
	_world = ClassDB.instantiate("VoxelWorld4D")
	var gen = ClassDB.instantiate("BoxVoxelGenerator4D")
	gen.set("material_inner", AIR)
	gen.set("material_outer", AIR)
	_world.set("generator", gen)
	var pal = ClassDB.instantiate("VoxelMaterialPalette4D")
	pal.set("colors", PackedColorArray([Color.GRAY, Color(0.45, 0.36, 0.28), Color(0.3, 0.5, 0.2)]))
	_world.set("material_palette", pal)
	_world.set("scale", Vector4(_cell, _cell, _cell, _cell))
	scene.add_child(_world)
	_trigger = ClassDB.instantiate("VoxelLoadTrigger4D")
	scene.add_child(_trigger)
	_trigger.set("voxel_world_path", _trigger.get_path_to(_world))
	var mid: Vector4 = (lo + hi) * 0.5
	_trigger.set("position", mid)
	# A chunk loads when its CENTRE is within the radius, so add a chunk's half diagonal (8 voxels).
	var reach: float = ((hi - lo) * 0.5).length() / _cell + 12.0
	_trigger.set("load_distance", reach)
	# Cells to poll for "defined": the box's corners and middle, in voxels.
	for corner in [lo, hi, mid, Vector4(lo.x, hi.y, lo.z, hi.w), Vector4(hi.x, lo.y, hi.z, lo.w)]:
		_probe_cells.append(Vector4i((corner / _cell).floor()))
	print("PROBE load_distance=%.1f voxels" % reach)
	# One edit sent before anything is defined, to see whether it is kept.
	var early = ClassDB.instantiate("SphereVoxelEdit4D")
	early.set("center", mid / _cell + Vector4(0, 0, 0, 0))
	early.set("radius", 3.0)
	early.set("fill_material", WOOD)
	_world.call("apply_edit", early)
	_t0 = Time.get_ticks_usec()


func _defined() -> bool:
	var data = _world.call("get_voxel_data")
	for c in _probe_cells:
		if not bool(data.call("is_voxel_defined", c)):
			return false
	return true


func _meshes() -> Array:
	var out: Array = []
	for child in _world.get_children():
		if child is MeshInstance4D and (child as MeshInstance4D).mesh != null:
			out.append(child)
	return out


func _tets() -> int:
	var n: int = 0
	for m in _meshes():
		n += ((m as MeshInstance4D).mesh as TetraMesh4D).get_simplex_cell_vertex_indices().size() / 4
	return n


func _process(_d: float) -> bool:
	_f += 1
	if Time.get_ticks_msec() > _deadline:
		print("PROBE TIMEOUT in phase ", _phase)
		quit(2)
		return true
	if _phase == "load":
		if _f % 60 == 0:
			var data = _world.call("get_voxel_data")
			var ok: int = 0
			for c in _probe_cells:
				if bool(data.call("is_voxel_defined", c)):
					ok += 1
			print("PROBE frame %d: %d of %d probe cells defined, %d meshes" % [_f, ok, _probe_cells.size(), _meshes().size()])
		if _defined():
			print("PROBE defined after %d frames, %.0f ms; meshes from the early edit: %d (%d tets)" % [_f, (Time.get_ticks_usec() - _t0) / 1000.0, _meshes().size(), _tets()])
			var t: int = Time.get_ticks_usec()
			for e in _edits:
				var ed = ClassDB.instantiate("SphereVoxelEdit4D")
				ed.set("center", e[0])
				ed.set("radius", e[1])
				ed.set("fill_material", e[2])
				_world.call("apply_edit", ed)
			print("PROBE %d edits applied in %.0f ms" % [_edits.size(), (Time.get_ticks_usec() - t) / 1000.0])
			_phase = "mesh"
			_t0 = Time.get_ticks_usec()
			_f = 0
		return false
	if _phase == "mesh":
		var n: int = _tets()
		if n == _last_tets and n > 0:
			_stable += 1
		else:
			_stable = 0
		_last_tets = n
		if _stable >= 5:
			print("PROBE meshed: %d frames, %.0f ms, %d chunk meshes, %d tets (~%.0f MB)" % [_f - 5, (Time.get_ticks_usec() - _t0) / 1000.0, _meshes().size(), n, float(n) * 1.25 / 1024.0])
			_harvest()
			quit()
			return true
	return false


func _harvest() -> void:
	var t: int = Time.get_ticks_usec()
	var out := ArrayTetraMesh4D.new()
	var scale := Projection.IDENTITY
	scale.x = Vector4(_cell, 0, 0, 0)
	scale.y = Vector4(0, _cell, 0, 0)
	scale.z = Vector4(0, 0, _cell, 0)
	scale.w = Vector4(0, 0, 0, _cell)
	for m in _meshes():
		var mi := m as MeshInstance4D
		var am: ArrayTetraMesh4D = (mi.mesh as TetraMesh4D).to_array_tetra_mesh()
		out.merge_with(am, mi.position * _cell, scale)
	var cells: int = out.get_simplex_cell_vertex_indices().size() / 4
	var tm: PackedVector3Array = out.get_texture_map_values()
	var mats: Dictionary = {}
	for v in tm:
		var m: int = int(round(v.x * 255.0))
		mats[m] = int(mats.get(m, 0)) + 1
	var lo := Vector4(INF, INF, INF, INF)
	var hi := Vector4(-INF, -INF, -INF, -INF)
	for p in out.get_vertex_positions():
		lo = lo.min(p)
		hi = hi.max(p)
	print("PROBE harvested into one mesh in %.0f ms: %d tets, %d vertices, texture values by material %s, bounds %s .. %s" % [
		(Time.get_ticks_usec() - t) / 1000.0, cells, out.get_vertex_positions().size(), str(mats), str(lo), str(hi)])
	var err: int = ResourceSaver.save(out, "res://smoke_test_output/arboretum/probe_dc_tree.res")
	print("PROBE saved: ", err)
