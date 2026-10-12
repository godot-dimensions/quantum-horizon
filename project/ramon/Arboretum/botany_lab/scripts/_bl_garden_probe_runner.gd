extends SceneTree

## BOTANY LAB, round 4 (section 10, step 47): the second room's new generators on their own, headless,
## before the room loads them: the lofted rocks (flora/rock_4d.gd) and the blocky garden's conifer, birch,
## bush and rock (compare/bl_gardens_4d.gd), each built once, timed, its cells and tetrahedra printed.

const Rock := preload("res://ramon/Arboretum/botany_lab/flora/rock_4d.gd")
const Gardens := preload("res://ramon/Arboretum/botany_lab/compare/bl_gardens_4d.gd")
const Voxel := preload("res://ramon/Arboretum/botany/voxel_tree_builder.gd")


func _initialize() -> void:
	for s in 4:
		var t0: int = Time.get_ticks_usec()
		var m: ArrayTetraMesh4D = Rock.build(7 + s)
		print("GARDEN rock %d: %d tets in %.1f ms" % [s, m.get_simplex_cell_vertex_indices().size() / 4 if m != null else -1, (Time.get_ticks_usec() - t0) / 1000.0])
	var g: Node4D = Gardens.new()
	var props: Array = [["conifer", g.call("_conifer", 16, 4)], ["conifer big", g.call("_conifer", 19, 5)], ["birch", g.call("_birch", 14, 4)],
		["bush", g.call("_blob", 2, 0.7, "blocky_bush", 0)], ["rock", g.call("_blob", 2, 0.55, "blocky_rock", -1)]]
	for pr in props:
		var parts: Dictionary = pr[1]
		var all: Dictionary = {}
		for sw in parts:
			all.merge(parts[sw])
		var t0: int = Time.get_ticks_usec()
		var tets: int = 0
		for sw in parts:
			tets += Voxel.mesh(all, 0.25, parts[sw]).get_simplex_cell_vertex_indices().size() / 4
		print("GARDEN %-12s %5d cells  %6d tets  %.1f ms" % [pr[0], all.size(), tets, (Time.get_ticks_usec() - t0) / 1000.0])
	g.free()
	quit()
