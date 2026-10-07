extends SceneTree

## Bakes the pen's terrain and saves it, so nothing is generated when the scene opens.
##
## Headless is fine - this only builds arrays and writes files.
## Args (after --): what=hills | cave_hill | cave | cave_far | mountains | hill_west | hill_tower | mound_a to mound_e | boulder_<n> | greens
## "greens" bakes every main-green piece in the saved main green (terrain/main_green_4d.gd), as the
## grass panel's Rebake greens does.
## "mountains" bakes with the parameters on the pen's World/Hills node, as its Bake button
## does, and writes mountains.res; "hills" is the first version, kept as the "Classic" style.
## Writes res://ramon/chickenpen/terrain/baked/<what>.res and reads it back to check that
## the colours survived the round trip. even=1 (cave_hill, hill_west, hill_tower): the turf in the
## main green (terrain/main_green_4d.gd), to <what>_even.res; the pen shows those with its
## Grass node's even_green on. ("mountains" writes both itself.)

const TerrainBake := preload("res://ramon/chickenpen/terrain/terrain_bake_4d.gd")
const PenHills := preload("res://ramon/chickenpen/terrain/pen_hills_4d.gd")
const PenCaveHill := preload("res://ramon/chickenpen/terrain/pen_cave_hill_4d.gd")
const CaveRock := preload("res://ramon/chickenpen/cave/cave_rock_4d.gd")
const CutStone := preload("res://ramon/chickenpen/terrain/cut_stone_4d.gd")
const OUT := "res://ramon/chickenpen/terrain/baked/"
const MainGreen := preload("res://ramon/chickenpen/terrain/main_green_4d.gd")


func _initialize() -> void:
	var what := "hills"
	var even := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("what="):
			what = a.substr(5)
		elif a == "even=1":
			even = true
		elif a == "rewind=1":
			TerrainBake.rewind = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var started: int = Time.get_ticks_msec()
	if even:
		PenCaveHill.grass = MainGreen.colour()
		PenCaveHill.grass_high = MainGreen.colour()
	if what == "greens":
		var room: Node = (load("res://ramon/chickenpen/playable_world.tscn") as PackedScene).instantiate()
		for line in MainGreen.bake_all(MainGreen.colour(), room.get_node_or_null("World/Hills")):
			print("   " + String(line))
		room.free()
		quit(0)
		return
	if what == "stones":
		_bake_stones()
		return
	var b: TerrainBake.Builder
	if what.begins_with("boulder_"):
		# The rock kit's boulders (terrain/pen_boulder_4d.gd), one variant a run.
		b = preload("res://ramon/chickenpen/terrain/pen_boulder_4d.gd").new(int(what.substr(8))).bake()
	else:
		b = null
	match what if b == null else "":
		"":
			pass
		"hills":
			b = PenHills.new().bake_shell()
		"cave_hill":
			b = PenCaveHill.new().bake()
		"hill_west", "hill_tower", "mound_a", "mound_b", "mound_c", "mound_d", "mound_e":
			b = preload("res://ramon/chickenpen/terrain/pen_round_hill_4d.gd").new(what).bake()
		"cave":
			b = CaveRock.new().bake()
		"cave_far":
			b = CaveRock.new().bake_far()
		"mountains":
			var room: Node = (load("res://ramon/chickenpen/playable_world.tscn") as PackedScene).instantiate()
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
	if what.begins_with("boulder_"):
		# Flat-shaded: each chiselled face reads as one cut (pen_boulder_4d.gd).
		mesh.calculate_boundary_normals(false)
		mesh.set_flat_shading_normals(true)
	var took: float = (Time.get_ticks_msec() - started) / 1000.0
	var path: String = OUT + what + ("_even" if even else "") + ".res"
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


## The designed-cut stone library (terrain/cut_stone_4d.gd, PenLayout/PLAN_REF_LOCK.md step 12):
## every kind, VARIANTS of each, one file each (baked/stones/<kind>_<n>.res), flat-shaded.
## Colours: the stone grey with each face a shade lighter or darker, lighter on top, a moss
## stain on what faces straight up. Args: stones_only=<kind> to bake one kind.
func _bake_stones() -> void:
	var dir: String = OUT + "stones/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var only: String = ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("stones_only="):
			only = a.substr(12)
	var total: int = 0
	for kind in CutStone.KINDS:
		if only != "" and kind != only:
			continue
		for n in CutStone.VARIANTS:
			var started: int = Time.get_ticks_msec()
			var mesh: ArrayTetraMesh4D = CutStone.bake_stone(kind, n, false)
			var path: String = "%s%s_%d.res" % [dir, kind, n]
			var err: int = ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS)
			var tets: int = mesh.get_simplex_cell_vertex_indices().size() / 4
			total += tets
			# The same stone with a mossy top (CutStone.moss_colour): <kind>_moss_<n>.res.
			ResourceSaver.save(CutStone.bake_stone(kind, n, true), "%s%s_moss_%d.res" % [dir, kind, n], ResourceSaver.FLAG_COMPRESS)
			print("   stone %s_%d: %d tetrahedra, %.1f s -> %s" % [kind, n, tets, (Time.get_ticks_msec() - started) / 1000.0, error_string(err)])
	if only == "" or only == "tuft":
		for n in 6:
			var tb := TerrainBake.Builder.new()
			CutStone.bake_tuft(tb, 4049 + n * 131)
			var tm: ArrayTetraMesh4D = TerrainBake.mesh_of(tb, false)
			tm.calculate_boundary_normals(false)
			tm.set_flat_shading_normals(true)
			var tp: String = "%stuft_%d.res" % [dir, n]
			print("   tuft_%d: %d tetrahedra -> %s" % [n, tb.tet_count(), error_string(ResourceSaver.save(tm, tp, ResourceSaver.FLAG_COMPRESS))])
			total += tb.tet_count()
	print("   STONES DONE: %d tetrahedra in all" % total)
	quit(0)
