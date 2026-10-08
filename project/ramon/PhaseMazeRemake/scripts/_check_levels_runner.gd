extends SceneTree

## The levels' regression check (PLAN.md steps 14, 20 and 75): every level file parsed and validated
## (solvable, every cell reachable or reported, the route PLAN.md drew on paper unchanged), its par and
## dead ends printed, then built into a node to count the pieces and time the build. Five generated seeds
## the same way. Headless; prints "LEVELS: PASS" or the problems.
##   run.sh headless levels res://ramon/PhaseMazeRemake/scripts/_check_levels_runner.gd

const Lattice := preload("res://ramon/PhaseMazeRemake/maze/maze_lattice.gd")
const Builder := preload("res://ramon/PhaseMazeRemake/maze/maze_builder_4d.gd")
const Style := preload("res://ramon/PhaseMazeRemake/maze/maze_style.gd")

var _t0: int = 0


func _initialize() -> void:
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_x: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 90000:
		print("LEVELS: gave up after 90 s")
		return true
	return false


func _run() -> void:
	Style.apply()
	var problems: Array = []
	var levels: Array = []
	for i in range(1, 6):
		levels.append(["level %d" % i, Lattice.load_file("res://ramon/PhaseMazeRemake/levels/level_%d.txt" % i)])
	for s in [1, 2, 3, 4, 5]:
		levels.append(["generated seed %d" % s, Lattice.generate(4, 4, 3, s)])
	for pair in levels:
		var name: String = pair[0]
		var lv = pair[1]
		lv.cell = 6.0
		lv.origin = Vector4(-float(lv.nx - 1) * 3.0, 0.0, -float(lv.nz - 1) * 6.0 - 3.0, 0.0)
		var v: Array = lv.validate()
		var reach: int = lv.bfs(lv.start).size()
		print("LEVELS: %s '%s' %dx%dx%d, reachable %d/%d, route [%s], par W %d, shortest routes %d, dead ends %d%s" % [
			name, lv.meta.get("name", ""), lv.nx, lv.nz, lv.nw, reach, lv.nx * lv.nz * lv.nw, lv.route_text(), lv.par_w(),
			lv.shortest_routes(), lv.dead_ends().size(), "" if v.is_empty() else "  PROBLEMS " + str(v)])
		for p in v:
			problems.append("%s: %s" % [name, p])
		var holder := Node4D.new()
		root.add_child(holder)
		var t: int = Time.get_ticks_usec()
		var built: Dictionary = Builder.build(holder, lv)
		var ms: float = float(Time.get_ticks_usec() - t) / 1000.0
		var meshes: int = holder.find_children("*", "MeshInstance4D", true, false).size()
		print("LEVELS:    built in %.1f ms: %d walls, %d meshes, %d tiles" % [ms, built["walls"].size(), meshes, built["tiles"].size()])
		if ms > 100.0:
			problems.append("%s: build took %.0f ms" % [name, ms])
		# Round trip: a cell's centre maps back to the cell.
		for c in [lv.start, lv.exit]:
			if lv.cell_at(lv.cell_centre(c)) != c:
				problems.append("%s: cell_at(cell_centre(%s)) is wrong" % [name, str(c)])
		holder.free()
	print("LEVELS: %s" % ("PASS" if problems.is_empty() else "FAIL " + str(problems)))
	quit()
