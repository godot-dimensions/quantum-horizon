extends SceneTree

## The dev look's greybox cave (Ramon, 6 Oct: "keep the original cave in the greybox version. just
## lower res"): the cave hill's own recipe (terrain/pen_cave_hill_4d.gd) baked again at about half its
## resolution, saved beside the pen's bakes. The look shows it in DEV in place of the hill's mesh
## (pen_look_4d.gd rules, "low_mesh"). Rebake after changing the hill's recipe.
##
##   lab_run.sh headless low_cave res://ramon/chickenpen/look/_bake_low_cave_runner.gd [dome_cell] [grid]

const CaveHill := preload("res://ramon/chickenpen/terrain/pen_cave_hill_4d.gd")
const TerrainBake := preload("res://ramon/chickenpen/terrain/terrain_bake_4d.gd")
const OUT := "res://ramon/chickenpen/terrain/baked/cave_hill_low.res"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var dome_cell: float = float(args[0]) if args.size() > 0 else 2.7
	var grid: int = int(args[1]) if args.size() > 1 else 9
	var t0: int = Time.get_ticks_msec()
	var low: TerrainBake.Builder = CaveHill.new().bake(dome_cell, grid)
	var mesh: ArrayTetraMesh4D = TerrainBake.mesh_of(low, false)
	var err: int = ResourceSaver.save(mesh, OUT, ResourceSaver.FLAG_COMPRESS)
	var full := load("res://ramon/chickenpen/terrain/baked/cave_hill_even.res") as TetraMesh4D
	var full_count: int = full.get_simplex_cell_vertex_indices().size() / 4 if full != null else -1
	print("LOW CAVE: dome %.2f m, block grid %d: %d tetrahedra (the pen's: %d), %.1f s -> %s (%s)" % [dome_cell, grid, low.tet_count(),
		full_count, (Time.get_ticks_msec() - t0) / 1000.0, OUT, error_string(err)])
	quit(0)
