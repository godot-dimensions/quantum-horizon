extends SceneTree

## Bakes what the cinema reads from disk instead of building while you watch: the goat's
## twelve lofts (part two, VII and VIII), the walking creature's 42 segments (IX) and the
## carved rock (III). Writes res://ramon/chickenpen/theatre/baked/.
##
## RE-RUN IT whenever the goat (Model/model.tscn) or the creature
## (Model/rigged_creature_ramon.tscn) are edited, or their loft scripts, or the rock's recipe
## in theatre_show_4d. Each bake carries a fingerprint of what it was made from
## (theatre_bake_4d), and until it is re-run the cinema builds that exhibit live: correct,
## but with the stalls this bake exists to remove.
##
## Each one is made exactly the way the cinema makes it, by the cinema's own scripts with
## their bake switched off, so a baked exhibit and a live one are the same mesh.
##
## Headless is fine: nothing here is drawn. Args after --: only=goat|creature|rock.

const BAKED := "res://ramon/chickenpen/theatre/baked/"
const GOAT := preload("res://ramon/chickenpen/theatre/theatre_goat_4d.gd")
const CREATURE := preload("res://ramon/chickenpen/theatre/theatre_creature_4d.gd")
const SHOW := preload("res://ramon/chickenpen/theatre/theatre_show_4d.gd")

var _f := 0
var _only := ""
var _creature: Node4D
var _theatre: Node
var _failed := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			_only = a.substr(5)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BAKED))


func _process(_d) -> bool:
	_f += 1
	if _f == 2:
		if _wants("goat"):
			_bake_goat()
		if _wants("creature"):
			# The segments loft in their own _ready, as they are added; counted next frame.
			_creature = Node4D.new()
			_creature.set_script(CREATURE)
			_creature.set("use_bake", false)
			root.add_child(_creature)
		if _wants("rock"):
			_theatre = load("res://ramon/chickenpen/theatre/theatre.tscn").instantiate()
			_theatre.get_node("Show").set("use_baked_rock", false)
			root.add_child(_theatre)
		return false
	if _f == 4:
		if _creature != null:
			_bake_creature()
		if _theatre != null:
			_bake_rock()
		print("\nBAKE %s" % ("FAILED" if _failed else "DONE"))
		quit(1 if _failed else 0)
		return true
	return false


func _wants(what: String) -> bool:
	return _only == "" or _only == what


func _save(resource: Resource, file: String) -> int:
	var err: int = ResourceSaver.save(resource, BAKED + file)
	if err != OK:
		print("could not write %s (%d)" % [file, err])
		_failed = true
		return 0
	var f := FileAccess.open(BAKED + file, FileAccess.READ)
	var n: int = f.get_length() if f != null else 0
	return n


## As _bake_goat_runner always did: the goat's own state machine run to the end, its seven
## stages of assembly, four of reshaping and the dressed animal saved, with the handle
## counts show_stage needs.
func _bake_goat() -> void:
	var holder := Node4D.new()
	root.add_child(holder)
	var goat := Node4D.new()
	goat.set_script(GOAT)
	goat.set("bake_to_disk", false)
	holder.add_child(goat)
	var t0: int = Time.get_ticks_usec()
	goat.call("finish_baking")
	var stages: Array = goat.get("_baked")
	var finished: Resource = goat.get("_finished")
	if stages.is_empty() or finished == null:
		print("goat: NOTHING BAKED - the goat did not build")
		_failed = true
		return
	var total := 0
	for i in stages.size():
		total += _save(stages[i], "goat_stage_%02d.res" % i)
	total += _save(finished, "goat_finished.res")
	var config := ConfigFile.new()
	config.set_value("goat", "balls_at_stage", goat.get("_balls_at_stage"))
	config.set_value("goat", "tetra_whole", goat.get("_tetra_whole"))
	config.set_value("goat", "stages", stages.size())
	var source: Node = (load(GOAT.SOURCE) as PackedScene).instantiate()
	config.set_value("goat", "fingerprint", GOAT.fingerprint(source.get_node(GOAT.GOAT_PATH)))
	source.free()
	config.save(BAKED + "goat.cfg")
	print("goat: %d stages and the dressed one, lofted in %.0f ms, %.2f MB" % [stages.size(),
		(Time.get_ticks_usec() - t0) / 1000.0, total / 1048576.0])
	holder.queue_free()


func _bake_creature() -> void:
	var adopted: Node = _creature.get("_creature")
	if adopted == null:
		print("creature: NOTHING BAKED - no creature was adopted")
		_failed = true
		return
	var segments: Array[MeshInstance4D] = CREATURE.segments_of(adopted)
	var total := 0
	var tetra := 0
	for i in segments.size():
		var mesh := segments[i].mesh as ArrayTetraMesh4D
		if mesh == null:
			print("creature: segment %s has no mesh" % segments[i].name)
			_failed = true
			return
		tetra += mesh.get_simplex_cell_vertex_indices().size() / 4
		total += _save(mesh, "creature_seg_%02d.res" % i)
	var config := ConfigFile.new()
	config.set_value("creature", "segments", segments.size())
	var source: Node = (load(CREATURE.SOURCE) as PackedScene).instantiate()
	config.set_value("creature", "fingerprint", CREATURE.fingerprint(source.get_node("Creature")))
	source.free()
	config.save(BAKED + "creature.cfg")
	print("creature: %d segments, %d tetrahedra, %.2f MB" % [segments.size(), tetra, total / 1048576.0])


## The rock as the show makes it - its recipe and its three blows - and its mesh saved
## without the material, which the show gives it again from the block's own palette.
func _bake_rock() -> void:
	var show: Node = _theatre.get_node("Show")
	var t0: int = Time.get_ticks_usec()
	show.call("_the_rock")
	show.call("_carve_once")
	var rock: Node = show.get("_rock")
	var mesh := (rock.get_node("Ground") as MeshInstance4D).mesh as ArrayTetraMesh4D if rock != null else null
	if mesh == null:
		print("rock: NOTHING BAKED - the block made no mesh")
		_failed = true
		return
	var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	var saved := mesh.duplicate() as ArrayTetraMesh4D
	saved.material = null
	var bytes: int = _save(saved, "rock.res")
	var config := ConfigFile.new()
	config.set_value("rock", "fingerprint", SHOW.rock_fingerprint())
	config.save(BAKED + "rock.cfg")
	print("rock: %d tetrahedra, carved in %.0f ms, %.2f MB" % [mesh.get_simplex_cell_vertex_indices().size() / 4,
		ms, bytes / 1048576.0])
