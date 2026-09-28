extends SceneTree

## Bakes the pen's terrain and saves it, so nothing is generated when the scene opens.
##
## Headless is fine - this only builds arrays and writes files.
## Args (after --): what=hills | cave_hill | cave | cave_far | mountains
## "mountains" bakes with the parameters on the pen's World/Hills node, as its Bake button
## does, and writes mountains.res; "hills" is the first version, kept as the "Classic" style.
## Writes res://ramon/chickenpen/terrain/baked/<what>.res and reads it back to check that
## the colours survived the round trip.

const TerrainBake := preload("res://ramon/chickenpen/terrain/terrain_bake_4d.gd")
const PenHills := preload("res://ramon/chickenpen/terrain/pen_hills_4d.gd")
const PenCaveHill := preload("res://ramon/chickenpen/terrain/pen_cave_hill_4d.gd")
const CaveRock := preload("res://ramon/chickenpen/cave/cave_rock_4d.gd")
const OUT := "res://ramon/chickenpen/terrain/baked/"


func _initialize() -> void:
	var what := "hills"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("what="):
			what = a.substr(5)
		elif a == "rewind=1":
			TerrainBake.rewind = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var started: int = Time.get_ticks_msec()
	var b: TerrainBake.Builder
	match what:
		"hills":
			b = PenHills.new().bake_shell()
		"cave_hill":
			b = PenCaveHill.new().bake()
		"cave":
			b = CaveRock.new().bake()
		"cave_far":
			b = CaveRock.new().bake_far()
		"mountains":
			var room: Node = (load("res://ramon/chickenpen/chickenpen.tscn") as PackedScene).instantiate()
			var hills: Node = room.get_node("World/Hills")
			if not hills.has_method("bake"):
				print("World/Hills is not the mountains node")
				room.free()
				quit(1)
				return
			var said: String = hills.call("bake")
			room.free()
			print("   " + said)
			quit(0 if said.ends_with("(OK)") else 1)
			return
		_:
			print("nothing called %s to bake" % what)
			quit(1)
			return
	var mesh: ArrayTetraMesh4D = TerrainBake.mesh_of(b, false)
	var took: float = (Time.get_ticks_msec() - started) / 1000.0
	var path: String = OUT + what + ".res"
	var err: int = ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS)
	print("   %s: %d vertices, %d tetrahedra, %d degenerate dropped, %d re-wound, %.1f s  ->  %s (%s)"
		% [what, b.positions.size(), b.tet_count(), b.skipped, b.flipped, took, path, error_string(err)])
	var back: ArrayTetraMesh4D = load(path) as ArrayTetraMesh4D
	var ok: bool = back != null and back.get_vertex_positions().size() == b.positions.size() \
		and back.texture_map_values.size() == b.positions.size() \
		and back.get_simplex_cell_vertex_indices().size() == b.cells.size()
	print("   read back: %s   file %.1f MB" % ["OK" if ok else "FAILED",
		FileAccess.get_file_as_bytes(path).size() / 1048576.0])
	var lo := Vector4(INF, INF, INF, INF)
	var hi := -lo
	for p in b.positions:
		lo = Vector4(minf(lo.x, p.x), minf(lo.y, p.y), minf(lo.z, p.z), minf(lo.w, p.w))
		hi = Vector4(maxf(hi.x, p.x), maxf(hi.y, p.y), maxf(hi.z, p.z), maxf(hi.w, p.w))
	print("   bounds %s .. %s" % [lo, hi])
	quit(0 if ok else 1)
