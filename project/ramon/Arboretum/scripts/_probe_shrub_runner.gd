extends SceneTree

## Plan step 3: the Shrubbery Lab's tree as it stands (the carried generator and blocky mesher), at
## three cell sizes: branches, voxels, tetrahedra by material, and the time of each stage. Headless.

const Gen := preload("res://ramon/Arboretum/carried/shrubbery/shrub_generator.gd")
const Species := preload("res://ramon/Arboretum/carried/shrubbery/shrub_species.gd")
const Blocky := preload("res://ramon/Arboretum/carried/shrubbery/shrub_mesh_builder_blocky.gd")


func _initialize() -> void:
	for size in [0.1, 0.125, 0.15]:
		var sp: Resource = Species.new()
		sp.set("voxel_size", size)
		var t0: int = Time.get_ticks_usec()
		var g: RefCounted = Gen.new(int(sp.get("seed")))
		g.call("build_trunk", sp)
		g.call("spawn_attractors_from_tesseract", sp)
		g.call("grow", sp)
		var t1: int = Time.get_ticks_usec()
		var voxels: Dictionary = g.call("voxelize", sp)
		var t2: int = Time.get_ticks_usec()
		var wood_v: int = 0
		for k in voxels:
			if int(voxels[k]) == Gen.VOXEL_ID_WOOD:
				wood_v += 1
		var meshes: Dictionary = Blocky.build_meshes(voxels, sp)
		var t3: int = Time.get_ticks_usec()
		var wood: ArrayTetraMesh4D = meshes[Gen.VOXEL_ID_WOOD]
		var leaf: ArrayTetraMesh4D = meshes[Gen.VOXEL_ID_LEAF]
		var wt: int = wood.get_simplex_cell_vertex_indices().size() / 4
		var lt: int = leaf.get_simplex_cell_vertex_indices().size() / 4
		var b: Dictionary = g.call("branch_bounds")
		print("PROBE size=%.3f branches=%d extent=%s voxels=%d (wood %d, leaf %d) tets wood=%d leaf=%d total=%d grow=%.0fms voxelize=%.0fms mesh=%.0fms  ~%.0f MB" % [
			size, (g.get("branches") as Array).size(), str(b["extent"]), voxels.size(), wood_v, voxels.size() - wood_v,
			wt, lt, wt + lt, (t1 - t0) / 1000.0, (t2 - t1) / 1000.0, (t3 - t2) / 1000.0, float(wt + lt) * 1.25 / 1024.0])
	quit()
