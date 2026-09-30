extends SceneTree

## Does the theatre stand up, and does the show run slides I to V and hand on to part two?
##
## One presentation since 30 Sept: part one is the walk-in and slides I to V (the chicken's
## sheet, the visitors along W, the rock turned through W, the shape parade and the one you
## turn yourself), then part two takes the floor with no closing line and no question. The
## primer's own exhibits have a runner of their own (_verify_primer_runner); this one checks
## the room and the running order.

var _root: Node
var _f := 0
var _fails: Array = []
var _show: Node
var _seen: Array = []
var _lit_on_approach: float = 0.0
var _rock_at_slide: bool = false
var _carved_at_slide: bool = false
var _handed_on: bool = false
var _pieces_at_start: Array = []
## Slide III, the rock: its index in the show's table of acts.
const ROCK_ACT := 2


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
		# NOT YET, AND THAT IS THE POINT. The exhibits used to be built inside the Show's
		# _ready, which is paid on the frame you walk through the door. The rock is made on
		# a still beat now - in the chair, or once the opening has run - so the door costs a
		# fraction of what it did and the rock is still standing before slide I is wanted.
		_check("they are not built on the frame you arrive",
			table.get_node_or_null("SliceRock") == null,
			"a doorway is not the place to pay for a mined rock")
		# AND THE CARVE HAS NOT HAPPENED YET EITHER. It used to fire at a third of a
		# second, from back when every exhibit was built inside _ready. Once the acts were
		# spread out, the rock did not exist at that moment - so the carve took its own
		# `_rock == null` exit, set `_carved` on the way out, and the block went on stage
		# solid. Nothing failed; the tunnel simply was not there.
		_check("and the rock has not been carved before it exists",
			not bool(_show.get("_carved")),
			"a carve that runs early runs on nothing and marks itself done")
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
		# And part two, which carries the talk on; long enough that the walk to the way out
		# below still happens mid-talk.
		var two: Node = _root.get_node("PartTwo")
		two.set("moment_seconds", 1.5)
		two.set("closing_seconds", 0.3)
		# He holds his mark until somebody sits down, and nobody sits down in this test -
		# the chair has a runner of its own. Zero is what he waits for a player who never
		# finds it, which is the case this one is standing in for.
		_show.set("waits_for_seat", 0.0)
		print("\n--- the run ---")
		return false

	var act: int = int(_show.get("_act"))
	if _seen.is_empty() or _seen[-1] != act:
		_seen.append(act)
		# THE ROCK IS THERE, AND CUT, BY THE TIME SLIDE I STARTS. Nobody sits in this test,
		# so it is the opening-has-run path that builds it, not the chair.
		var table: Node4D = _root.get_node("Stage/Turntable")
		if act == 0:
			for piece in ["FlatWorld", "Visitors", "SliceRock", "Zoo", "Toy"]:
				if table.get_node_or_null(piece) != null:
					_pieces_at_start.append(piece)
		if act == ROCK_ACT:
			_rock_at_slide = table.get_node_or_null("SliceRock/Rock/Voxels") != null
			_carved_at_slide = bool(_show.get("_carved"))
	if act == 5 and bool(_root.get_node("PartTwo").call("is_running")):
		_handed_on = true

	# Walk up to the way out part way through, to see whether it notices you rather
	# than waiting for the talk to finish.
	if _f == 600:
		var door: Node4D = _root.get_node("ExitArch") as Node4D
		(_root.get_node("Player") as Node4D).global_position = door.global_position
	if _f == 640:
		_lit_on_approach = float(_root.get_node("ExitArch").get("_lit"))
		(_root.get_node("Player") as Node4D).global_position = Vector4(0, 2.0, 0, 0)
	if _f < 900 or not bool(_show.call("is_over")):
		if _f > 30000:
			print("   FAIL the talk never ended (acts %s)" % [_seen])
			quit(1); return true
		return false
	print("   acts in order: %s" % [_seen])
	print("\n--- slides I to V ---")
	_check("all five exhibits stand before slide I starts", _pieces_at_start.size() == 5,
		"%s" % [_pieces_at_start])
	_check("the rock is a real mined block", _rock_at_slide,
		"a VoxelMiningBlock with its own colliders, on the drum as the slide opens")
	_check("and already cut", _carved_at_slide,
		"the carve was taken before the slide, not on its first frame")
	_check("it ran all five in order and handed on", _seen.slice(-6) == [0, 1, 2, 3, 4, 5] and _handed_on,
		"%s, then part two had the floor" % [_seen])
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
	var voxels: Node = _root.get_node_or_null("Stage/Turntable/SliceRock/Rock/Voxels")
	_check("and somebody had been at the rock with a pick", bool(_show.get("_carved"))
		and voxels != null and voxels.get_child_count() > 0,
		"%d surface colliders round the tunnel" % (voxels.get_child_count()
			if voxels != null else -1))
	print("\n%d FAIL(s)" % _fails.size())
	quit(1 if _fails.size() > 0 else 0)
	return true
