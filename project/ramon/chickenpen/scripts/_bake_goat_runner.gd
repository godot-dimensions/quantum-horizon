extends SceneTree

## Bake the goat's twelve lofts to disk, once, so the theatre never lofts them again.
##
## WHY THIS EXISTS. Building the goat was 3,106 ms - four fifths of the cost of walking
## through the sci-fi door - and it is twelve full lofts: seven stages of assembly, four of
## reshaping, one dressed. Spreading them over twelve frames was the obvious move and it is
## the wrong one: it turns a single stall into twelve dropped frames, which is worse to
## look at and exactly the trap the lofting notes already warn about.
##
## The stages are a PURE FUNCTION of the authored animal. Same handles, same reshape table,
## same result every run. So they are baked here and saved as ArrayTetraMesh4D resources,
## and the theatre loads them. Re-run this whenever the goat in the Model scene changes;
## the theatre falls back to lofting at runtime if the files are missing, so a stale or
## absent bake is slow rather than broken.

const OUT := "res://ramon/chickenpen/theatre/baked/"

var _f := 0


func _process(_d) -> bool:
	_f += 1
	if _f < 3:
		return false
	var holder := Node4D.new()
	root.add_child(holder)
	var goat := Node4D.new()
	goat.set_script(load("res://ramon/chickenpen/theatre/theatre_goat_4d.gd"))
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
	var total := 0
	for i in stages.size():
		var path: String = "%sgoat_stage_%02d.res" % [OUT, i]
		var err: int = ResourceSaver.save(stages[i] as Resource, path)
		if err != OK:
			print("could not write %s (%d)" % [path, err])
			quit(1)
			return true
		total += _size_of(path)
	var err2: int = ResourceSaver.save(finished, OUT + "goat_finished.res")
	if err2 != OK:
		print("could not write the dressed goat (%d)" % err2)
		quit(1)
		return true
	total += _size_of(OUT + "goat_finished.res")
	# The handle counts go with them: show_stage needs to know how much animal each stage
	# is, and that is not recoverable from a mesh.
	var counts := ConfigFile.new()
	counts.set_value("goat", "balls_at_stage", goat.get("_balls_at_stage"))
	counts.set_value("goat", "tetra_whole", goat.get("_tetra_whole"))
	counts.set_value("goat", "stages", stages.size())
	# What it was baked from: the cinema lofts the goat live instead of reading this bake
	# when the goat in the Model scene, or its loft scripts, no longer match (theatre_bake_4d).
	var source: Node = (load("res://ramon/Model/model.tscn") as PackedScene).instantiate()
	counts.set_value("goat", "fingerprint",
		load("res://ramon/chickenpen/theatre/theatre_goat_4d.gd").call("fingerprint", source.get_node("Models/Goat")))
	source.free()
	counts.save(OUT + "goat.cfg")

	print("\nbaked %d stages plus the dressed one in %.0f ms" % [stages.size(), ms])
	print("on disk: %.2f MB" % (float(total) / 1048576.0))
	quit(0)
	return true


func _size_of(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 0
	var n: int = f.get_length()
	f.close()
	return n
