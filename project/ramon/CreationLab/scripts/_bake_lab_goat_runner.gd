extends SceneTree

## Bakes the lab's goat: its build stages and dressed coat (as chickenpen/scripts/_bake_goat_runner.gd
## does for the pen's), and its walking pieces (goat_walk_4d.gd), into the lab's own folder,
## LabKit/carried/chickenpen/theatre/baked/. Re-run it whenever the lab's goat (in
## LabKit/carried/Model/model.tscn) changes: the theatre loads whatever is on disk, so a stale bake
## shows the old goat.
##
##   CreationLab/scripts/lab_run.sh headless bake res://ramon/CreationLab/scripts/_bake_lab_goat_runner.gd

const OUT := "res://ramon/LabKit/carried/chickenpen/theatre/baked/"
const GOAT := "res://ramon/LabKit/carried/chickenpen/theatre/theatre_goat_4d.gd"
const WALK := preload("res://ramon/CreationLab/scripts/goat_walk_4d.gd")

var _f := 0


func _process(_d) -> bool:
	_f += 1
	if _f < 3:
		return false
	var holder := Node4D.new()
	root.add_child(holder)
	var goat := Node4D.new()
	goat.set_script(load(GOAT))
	goat.set("bake_to_disk", false)
	holder.add_child(goat)
	var t0: int = Time.get_ticks_usec()
	goat.call("finish_baking")
	var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	var stages: Array = goat.get("_baked")
	var finished: Resource = goat.get("_finished")
	if stages.is_empty() or finished == null:
		print("NOTHING BAKED - the goat did not build")
		quit(1)
		return true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	# Old stage files beyond the new count would be read as stages; clear them first.
	for f in DirAccess.get_files_at(OUT):
		if f.begins_with("goat_stage_") or f.begins_with("walk_"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(OUT + f))
	for i in stages.size():
		if ResourceSaver.save(stages[i] as Resource, "%sgoat_stage_%02d.res" % [OUT, i]) != OK:
			print("could not write stage %d" % i)
			quit(1)
			return true
	if ResourceSaver.save(finished, OUT + "goat_finished.res") != OK:
		print("could not write the dressed goat")
		quit(1)
		return true
	var counts := ConfigFile.new()
	counts.set_value("goat", "balls_at_stage", goat.get("_balls_at_stage"))
	counts.set_value("goat", "tetra_whole", goat.get("_tetra_whole"))
	counts.set_value("goat", "stages", stages.size())
	counts.save(OUT + "goat.cfg")
	print("baked %d stages plus the dressed one in %.0f ms" % [stages.size(), ms])
	# The walking pieces, from the same balls.
	var rig: MeshInstance4D = goat.get("_rig")
	var t1: int = Time.get_ticks_usec()
	var pieces: Dictionary = WALK.build_pieces(rig)
	if pieces.is_empty():
		print("NO WALK PIECES")
		quit(1)
		return true
	WALK.save_pieces(pieces)
	var tetra: int = int((pieces["body"] as ArrayTetraMesh4D).get_simplex_cell_vertex_indices().size() / 4)
	for leg in pieces["legs"]:
		tetra += int((leg["upper"] as ArrayTetraMesh4D).get_simplex_cell_vertex_indices().size() / 4)
		tetra += int((leg["lower"] as ArrayTetraMesh4D).get_simplex_cell_vertex_indices().size() / 4)
	print("walk pieces: body + %d legs, %d tetrahedra, %.0f ms" % [(pieces["legs"] as Array).size(), tetra, float(Time.get_ticks_usec() - t1) / 1000.0])
	for leg in pieces["legs"]:
		print("  %s top %s mid %s hoof %s" % [leg["name"], leg["top"], leg["mid"], leg["hoof"]])
	quit(0)
	return true
