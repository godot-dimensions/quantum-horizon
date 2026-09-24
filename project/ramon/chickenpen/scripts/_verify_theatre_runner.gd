extends SceneTree

## Does the theatre stand up, and does the show run through all three acts?

var _root: Node
var _f := 0
var _fails: Array = []
var _show: Node
var _seen: Array = []
var _lit_on_approach: float = 0.0
var _exhibits_at: int = 0


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/theatre/theatre.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _check(label: String, ok: bool, detail: String) -> void:
	print("   %s %-38s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fails.append(label)


func _process(_d) -> bool:
	_f += 1
	# Everything is set up on the FIRST frame, not after a settling period. The room
	# builds itself and carves its own rock before anything else happens, and those
	# frames carry enormous deltas - waiting sixty of them out let the opening and the
	# first act run before the watcher had started watching, which made this test pass or
	# fail depending on how busy the machine was.
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
		# NOT YET, AND THAT IS THE POINT. The three acts used to be built inside the Show's
		# _ready, which is paid on the frame you walk through the door - 209 ms of it in a
		# debug build, on top of part two's 3,500, for about four seconds at the threshold.
		# They are made one an act per frame now, so the door costs a fraction of what it
		# did and they are still standing long before act one is wanted.
		_check("they are not built on the frame you arrive",
			table.get_node_or_null("ActThree") == null,
			"a doorway is not the place to pay for a mined rock")
		# AND THE CARVE HAS NOT HAPPENED YET EITHER. It used to fire at a third of a
		# second, from back when every exhibit was built inside _ready. Once the acts were
		# spread out, the rock did not exist at that moment - so the carve took its own
		# `_rock == null` exit, set `_carved` on the way out, and the block went on stage
		# solid. Nothing failed; the tunnel simply was not there.
		_check("and the rock has not been carved before it exists",
			not bool(_show.get("_carved")),
			"a carve that runs early runs on nothing and marks itself done")
		_exhibits_at = _f + 6
		_check("the way out is standing when you get there", bool(_root.get_node("ExitArch").get("armed")),
			"open at the head of the walkway")
		# AND ALREADY LIT, before anybody has walked near it or finished anything. It is
		# behind the audience, at the top of a rake, in the dark; a door that only lights
		# when you are stood in front of it is a door you have to have found first.
		_check("and already glowing when you arrive",
			float(_root.get_node("ExitArch").get("highlight")) > 0.5,
			"resting at %.2f, so it is the blue thing you see when you turn round"
				% float(_root.get_node("ExitArch").get("highlight")))
		# Hurry the show along, or this test is a minute of waiting.
		# Long enough that the carve still happens during the ARRIVAL, which is where the
		# real show takes it.
		_show.set("opening_seconds", 1.0)
		_show.set("act_seconds", 0.5)
		_show.set("closing_seconds", 0.3)
		# He holds his mark until somebody sits down, and nobody sits down in this test -
		# the chair has a runner of its own. Zero is what he waits for a player who never
		# finds it, which is the case this one is standing in for.
		_show.set("waits_for_seat", 0.0)
		print("\n--- the run ---")
		return false

	# AND THEY TURN UP ON THEIR OWN, with nobody calling finish_building(). Six frames is
	# twice the three they take, and still well inside the opening.
	if _exhibits_at > 0 and _f >= _exhibits_at:
		_exhibits_at = 0
		var table: Node4D = _root.get_node("Stage/Turntable")
		_check("all three arrive within a few frames",
			table.get_node_or_null("ActOne") != null
				and table.get_node_or_null("ActTwo") != null
				and table.get_node_or_null("ActThree") != null,
			"built by the pump, before the opening was over")
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

	var act: int = int(_show.get("_act"))
	if _seen.is_empty() or _seen[-1] != act:
		_seen.append(act)

	# Walk up to the way out part way through, to see whether it notices you rather
	# than waiting for the talk to finish.
	if _f == 600:
		var door: Node4D = _root.get_node("ExitArch") as Node4D
		(_root.get_node("Player") as Node4D).global_position = door.global_position
	if _f == 640:
		_lit_on_approach = float(_root.get_node("ExitArch").get("_lit"))
		(_root.get_node("Player") as Node4D).global_position = Vector4(0, 2.0, 0, 0)
	if _f < 900: return false
	print("   acts in order: %s" % [_seen])
	_check("it ran all three and closed", _seen.has(0) and _seen.has(1) and _seen.has(2)
		and _seen.has(3), "%s" % [_seen])
	_check("and it is still there at the end", bool(_root.get_node("ExitArch").get("armed"))
		and _root.get_node("ExitArch").visible, "you can walk out of it")
	_check("it lights up when you walk to it, mid-talk", _lit_on_approach > 0.5,
		"lit %.2f on approach, without waiting for the end" % _lit_on_approach)
	_check("and it has a sound of its own",
		_root.get_node_or_null("ExitArch/Chime") != null,
		"the farm's sfx system is switched off while you are in here")
	_check("and the talk turns it up when it finishes",
		float(_root.get_node("ExitArch").get("highlight")) > 0.9,
		"highlight %.2f - usable all along, announced at the end"
			% float(_root.get_node("ExitArch").get("highlight")))
	var voxels: Node = _root.get_node_or_null("Stage/Turntable/ActThree/Rock/Voxels")
	_check("and somebody had been at the rock with a pick", bool(_show.get("_carved"))
		and voxels != null and voxels.get_child_count() > 0,
		"%d surface colliders round the tunnel" % (voxels.get_child_count()
			if voxels != null else -1))
	print("\n%d FAIL(s)" % _fails.size())
	quit(1 if _fails.size() > 0 else 0)
	return true
