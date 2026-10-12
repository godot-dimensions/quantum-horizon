extends SceneTree

## BOTANY LAB, round 3 (section 9, step 8): every flower of the flower room built on its own, headless,
## before any scene loads one: timed, its parts, tetrahedra and size printed, nothing saved. Run after
## any change to flora/ (an unbounded loop took the PC down on 9 Oct; every loop in flower_4d.gd is
## capped, and this is the check that the caps hold).
##
##   -- [bake]   also bake every species' variants under flora/baked/ (flower_4d.gd mesh())

const Flower := preload("res://ramon/Arboretum/botany_lab/flora/flower_4d.gd")
const Species := preload("res://ramon/Arboretum/botany_lab/flora/flora_species.gd")


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var bake: bool = "bake" in args
	var t_all: int = Time.get_ticks_usec()
	var total_tets: int = 0
	for key in Species.KEYS:
		for variant in Flower.VARIANTS:
			var t0: int = Time.get_ticks_usec()
			var m: ArrayTetraMesh4D = Flower.mesh(key, variant) if bake else Flower.build(key, variant)
			var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
			if m == null:
				print("FLORA %s/%d: NOTHING BUILT" % [key, variant])
				continue
			var pos: PackedVector4Array = m.get_vertex_positions()
			var lo := Vector4(INF, INF, INF, INF)
			var hi := -lo
			for p in pos:
				lo = Vector4(minf(lo.x, p.x), minf(lo.y, p.y), minf(lo.z, p.z), minf(lo.w, p.w))
				hi = Vector4(maxf(hi.x, p.x), maxf(hi.y, p.y), maxf(hi.z, p.z), maxf(hi.w, p.w))
			var tets: int = m.get_simplex_cell_vertex_indices().size() / 4
			var tex_ok: bool = m.get_texture_map_values().size() == pos.size()
			total_tets += tets
			print("FLORA %-13s v%d %7.0f ms  parts %4d  tets %6d  verts %6d  perches %d  tex %s  x %.3f..%.3f  y %.3f..%.3f  z %.3f..%.3f  w %.3f..%.3f" % [
				key, variant, ms, int(m.get_meta("parts", 0)), tets, pos.size(), (m.get_meta("perches", PackedVector4Array()) as PackedVector4Array).size(),
				"ok" if tex_ok else "MISSING", lo.x, hi.x, lo.y, hi.y, lo.z, hi.z, lo.w, hi.w])
	var t1: int = Time.get_ticks_usec()
	var mat: TetraMaterial4D = Flower.material()
	print("FLORA material in %.0f ms: %s" % [(Time.get_ticks_usec() - t1) / 1000.0, "ok" if mat != null and mat.albedo_texture_3d != null else "MISSING"])
	print("FLORA all in %.1f s, %d tetrahedra over %d meshes, memory %.1f MB" % [(Time.get_ticks_usec() - t_all) / 1e6, total_tets,
		Species.KEYS.size() * Flower.VARIANTS, OS.get_static_memory_usage() / 1048576.0])
	quit()
