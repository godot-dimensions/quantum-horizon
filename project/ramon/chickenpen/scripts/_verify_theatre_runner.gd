extends SceneTree

## Does the theatre stand up, and does the show run through all three acts?

var _root: Node
var _f := 0
var _fails: Array = []
var _show: Node
var _seen: Array = []


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/theatre/theatre.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _check(label: String, ok: bool, detail: String) -> void:
	print("   %s %-38s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fails.append(label)


func _process(_d) -> bool:
	_f += 1
	if _f < 60: return false
	if _show == null:
		_show = _root.get_node_or_null("Show")
		if _show == null:
			print("   FAIL there is no show")
			quit(1); return true
		var stage: Node4D = _root.get_node("Stage")
		print("\n--- the room ---")
		_check("the floor is there", stage.get_node_or_null("Floor") != null,
			"%d pieces" % stage.get_node_or_null("Floor").get_child_count())
		_check("and a backdrop behind the stage",
			stage.get_node_or_null("Backdrop") != null,
			"%d panels" % stage.get_node_or_null("Backdrop").get_child_count())
		_check("a house to play to", stage.get_node_or_null("House") != null,
			"%d seats and backs" % stage.get_node_or_null("House").get_child_count())
		_check("beams", stage.get_node_or_null("Beams") != null, "over the stage")
		_check("and a sky", stage.get_node_or_null("Motes") != null,
			"%d motes" % stage.get_node_or_null("Motes").get_child_count())
		print("\n--- the exhibits ---")
		var table: Node4D = stage.get_node("Turntable")
		_check("three of them, on the turntable",
			table.get_node_or_null("ActOne") != null
				and table.get_node_or_null("ActTwo") != null
				and table.get_node_or_null("ActThree") != null, "built")
		_check("act one really does carry a 3D node",
			table.get_node_or_null("ActOne/ThreeD") is MeshInstance3D,
			"a MeshInstance3D, which the renderer will never draw")
		_check("act two has a hull and a swarm",
			table.get_node_or_null("ActTwo/Hull") != null
				and table.get_node_or_null("ActTwo/Swarm") != null, "both")
		_check("act three is a real mined block",
			table.get_node_or_null("ActThree/Rock") != null
				and table.get_node_or_null("ActThree/Rock/Voxels") != null,
			"a VoxelMiningBlock with its own colliders")
		_check("the way out is standing when you get there", bool(_root.get_node("ExitArch").get("armed")),
			"open at the head of the walkway")
		# Hurry the show along, or this test is a minute of waiting.
		_show.set("opening_seconds", 0.2)
		_show.set("act_seconds", 0.5)
		_show.set("closing_seconds", 0.3)
		print("\n--- the run ---")
		return false

	var act: int = int(_show.get("_act"))
	if _seen.is_empty() or _seen[-1] != act:
		_seen.append(act)

	if _f < 900: return false
	print("   acts in order: %s" % [_seen])
	_check("it ran all three and closed", _seen.has(0) and _seen.has(1) and _seen.has(2)
		and _seen.has(3), "%s" % [_seen])
	_check("and it is still there at the end", bool(_root.get_node("ExitArch").get("armed"))
		and _root.get_node("ExitArch").visible, "you can walk out of it")
	var voxels: Node = _root.get_node_or_null("Stage/Turntable/ActThree/Rock/Voxels")
	_check("and somebody had been at the rock with a pick", bool(_show.get("_carved"))
		and voxels != null and voxels.get_child_count() > 0,
		"%d surface colliders round the tunnel" % (voxels.get_child_count()
			if voxels != null else -1))
	print("\n%d FAIL(s)" % _fails.size())
	quit(1 if _fails.size() > 0 else 0)
	return true
