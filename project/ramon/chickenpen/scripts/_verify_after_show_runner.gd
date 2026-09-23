extends SceneTree

## The two ends of the journey say the right things, and the arrows do not deadlock.
##
## TWO BUGS LIVE HERE, both reported from a playtest, both mine.
##
## ONE: "let's get back to the pen house" was wired into the HOMECOMING conversation, so
## it played once you were already standing in the pen house - and it displaced "so, what
## did you think", which is what belongs there. Same lines, wrong end of the trip.
##
## TWO: stepping back off part two's first slide into part one worked, and stepping
## forward again did nothing at all - part one returns early on `_done`, which part one
## sets when it finishes. Both halves then waited on each other for ever. The show sat
## frozen on a slide with the player still free to walk about.

const TrymScript = preload("res://ramon/dialogue/trym_script.gd")

var _root: Node
var _f := 0
var _fails: Array = []
var _show: Node
var _two: Node
var _stage := 0
var _mark := 0


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/theatre/theatre.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root


func _check(label: String, ok: bool, detail: String) -> void:
	print("   %s %-46s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fails.append(label)


func _text(key: String) -> String:
	var out := ""
	for line in ((TrymScript.NODES.get(key, {}) as Dictionary).get("lines", []) as Array):
		out += String(line) + " "
	return out.to_lower()


func _process(_d) -> bool:
	_f += 1
	if _f < 20:
		return false
	if _show == null:
		_show = _root.get_node_or_null("Show")
		_two = _root.get_node_or_null("PartTwo")
		if _show == null or _two == null:
			_check("the pieces are in the scene", false, "Show / PartTwo")
			return _finish()

		print("\n--- which line goes where ---")
		_check("the homecoming asks what you thought",
			_text("what_did_you_think").contains("you've seen it now"),
			"what_did_you_think, the node the driver enters on return")
		_check("and does not send you back to the pen house",
			not _text("what_did_you_think").contains("pen house")
				and not _text(String(TrymScript.NODES["what_did_you_think"].get("goto", "")))
					.contains("pen house"),
			"you are standing in it - the line belongs in the cinema")
		# AND THE STAKEHOLDER QUESTIONS ARE STILL THERE. This check used to assert the
		# opposite - that the homecoming ended without a menu - because "no more multiple
		# choice" was read as "delete the reply list", and nine nodes of Ramon's writing
		# went with it. They are back verbatim out of 8c808dd. The instruction was about
		# not being FORCED through a menu, not about losing the answers behind one.
		var homecoming: Dictionary = TrymScript.NODES[String(
			TrymScript.NODES["what_did_you_think"]["goto"])]
		var replies: Array = homecoming.get("choices", []) as Array
		_check("and the stakeholder questions survived", replies.size() >= 8,
			"%d ways to answer him, from platform to tech demo" % replies.size())
		var leaves := false
		for reply in replies:
			if bool((reply as Dictionary).get("leave", false)):
				leaves = true
		_check("with a way out of the list", leaves,
			"you are never held in it - that was the actual complaint")
		# And having taken the ticket you can still come back and ask.
		_check("and the ticket does not end the conversation",
			String((TrymScript.NODES["greet_after"] as Dictionary).get("goto", "")) == "post_show",
			"greet_after reopens the questions rather than signing off")
		_check("and the pen house line is the cinema's",
			_text("after_show_walk").contains("pen house")
				and _text("after_show_walk").contains("dimensional door"),
			"after_show_walk - the short way out of either reply list")

		print("
--- and the cinema conversation ---")
		# YOU open it, so the node has no lines of his and the reply list is first.
		var first: Dictionary = TrymScript.NODES.get("greet_cinema", {})
		# TWO WORDS OF HIS, AND THEN YOU. Not none: dialogue_player_4d keeps the previous
		# line on screen when a node has no lines of its own, which is right for a hub in
		# the middle of a conversation and wrong for the node a conversation OPENS on -
		# there is no previous beat, so it left the last thing he said last time sitting
		# above the new reply list, and read as him repeating himself.
		_check("he acknowledges you and then it is your turn",
			(first.get("lines", []) as Array).size() == 1
				and (first.get("choices", []) as Array).size() == 2,
			"one word of his, so nothing stale can be left on the panel")
		var opener := ""
		for reply in (first.get("choices", []) as Array):
			opener += String((reply as Dictionary).get("text", ""))
		_check("with the questions and a way out", opener.to_lower().contains("questions")
			and opener.to_lower().contains("going"),
			"ask him, or leave - and the leave goes straight to the walk")
		# ONE RUN, NO SEAM. It used to stop and then start again.
		var answers: Dictionary = TrymScript.NODES.get("cinema_answers", {})
		var said := ""
		for line in (answers.get("lines", []) as Array):
			said += String(line)
		_check("and he answers all of it in one go, then closes it",
			(answers.get("lines", []) as Array).size() >= 5
				and (answers.get("choices", []) as Array).is_empty()
				and String(answers.get("goto", "")) == ""
				and said.to_lower().contains("now let's go"),
			"%d lines, straight into the figures, and he ends it himself"
				% (answers.get("lines", []) as Array).size())
		_check("the second time is the creepy one",
			_text("greet_cinema_again").contains("hyperspace")
				and _text("greet_cinema_again").contains("can't stay"),
			"he gets most of the way to saying it and stops")
		# The third conversation, and the last one there is.
		var insist: Dictionary = TrymScript.NODES.get("greet_cinema_insist", {})
		var push := ""
		for reply in (insist.get("choices", []) as Array):
			push += String((reply as Dictionary).get("text", ""))
		_check("and the third time you refuse to be shooed out",
			push.to_lower().contains("insist"),
			"he has been trying to leave for two conversations")
		_check("and he tells you where you actually are",
			_text("cinema_truth").contains("transcendental object at the end of time")
				and _text("cinema_truth").contains("fourth dimension"),
			"one sentence, flat, and then he changes the subject")
		var after_show: Node = _root.get_node_or_null("AfterShow")
		_check("and then he has nothing more to say",
			after_show != null and int(after_show.get("done_after")) == 3,
			"the prompt stops offering him - silence is him finishing the sentence")
		_check("and the insist node has a line of its own too",
			((TrymScript.NODES["greet_cinema_insist"] as Dictionary)
				.get("lines", []) as Array).size() == 1,
			"same reason as the opener - nothing stale left on the panel")

		print("
--- and it is a real conversation, not a caption ---")
		var talker: Node = _root.get_node_or_null("AfterShow")
		_check("there is an after-show at all", talker != null, "Theatre/AfterShow")
		if talker == null:
			return _finish()
		# THE FARM'S OWN MACHINERY. This was three lines typed into the presentation's
		# caption band; Ramon's note was that a character answering you should look like
		# every other character answering you, and he is right - the caption is the SHOW
		# talking. It is PenNpcTalk4D now, the same base the keeper and Mithra use.
		_check("it uses the same driver as everybody else", talker is PenNpcTalk4D,
			"PenNpcTalk4D - same box, same prompt over his head, same freeze")
		_check("with a box of its own", _root.get_node_or_null("UI/TrymBox") != null
			and _root.get_node_or_null("TrymTalk") != null,
			"a DialogueBox4D and a DialoguePlayer4D, straight out of ramon/dialogue")
		_check("and an F over his head", _root.get_node_or_null("UI/TrymTag") != null,
			"a WorldTag4D anchored on the presenter, as the farm does it")
		# AND THE PRESENTATION STOPS TALKING WHILE HE DOES. Two text systems on one screen
		# is the conflict: the caption band is the SHOW's voice and the box is his, and
		# both drawing at once reads as the room arguing with itself. PenNpcTalk4D already
		# carries the answer - the farm hides its dials and readouts the same way.
		_check("and the presentation gets out of the way while he talks",
			(talker.get("hide_while_talking") as Array).size() >= 4,
			"%d of the room's own readouts put away for the conversation"
				% (talker.get("hide_while_talking") as Array).size())
		_check("and it says nothing during the presentation",
			not bool(talker.call("_is_over")), "F is free until the talk has finished")
		_check("the show announces its own ending", _show.has_signal("finished"),
			"signal finished, emitted from let_them_go by every route")
		# OVER HIS HEAD, LIKE EVERY OTHER CONVERSATION. It was a band stretched along the
		# bottom of the screen, which is the layout the PRESENTATION uses - so talking to
		# him looked like another slide rather than a person answering.
		var box: DialogueBox4D = _root.get_node("UI/TrymBox") as DialogueBox4D
		# RESOLVED FROM THE BOX, not from the scene root. head_anchor_path is written
		# relative to the node that owns it, like every NodePath export in this project -
		# looking it up anywhere else finds nothing and says the wiring is broken.
		_check("and the box sits over his head, not across the screen",
			box.layout == DialogueBox4D.Layout.OVER_HEAD
				and box.get_node_or_null(box.head_anchor_path) != null,
			"OVER_HEAD, anchored on a head that survives - see below")
		# AND THE ANCHOR IS NOT A CHILD OF HIM. block_avatar_4d frees every child it has
		# when it rebuilds its body, so a Head parented to the presenter is a freed object
		# by the time the box asks where to draw - and a box with no anchor falls back to
		# the bottom of the screen, which is what it was doing.
		var head: Node4D = box.get_node_or_null(box.head_anchor_path) as Node4D
		_check("and the head it hangs off is not one of his children",
			head != null and head.get_parent() != _root.get_node("Presenter"),
			"a sibling that follows him, as World/TrymHead is on the farm")
		# AND THE CLOSING CAPTION LETS GO. It used to stay up for the rest of the visit.
		# What is asserted is that the end of the talk SCHEDULES the clear - the clearing
		# itself is a countdown in _process, and driving the show far enough to watch it
		# land would mean playing the whole presentation through twice.
		_show.call("let_them_go")
		_check("and the end of the talk takes the caption down with it",
			float(_show.get("_clear_in")) > 0.0
				and float(_show.get("caption_hold")) > 0.0,
			"the closing line holds for %.0f s and then the band goes"
				% float(_show.get("caption_hold")))
		print("\n--- the arrows, across the seam ---")
		_show.set("opening_seconds", 0.4)
		_show.set("act_seconds", 0.25)
		_show.set("closing_seconds", 0.2)
		_show.set("waits_for_seat", 0.0)
		_two.set("moment_seconds", 0.4)
		_mark = _f + 900
		_stage = 1
		return false

	match _stage:
		1:
			# Let part one finish and start part two, then put part two on its first slide.
			if _two.has_method("is_running") and bool(_two.call("is_running")):
				_two.call("_enter", 0)
				_check("part two is up and on its first slide",
					int(_two.call("current_moment")) == 0, "moment 0")
				_stage = 2
			elif _f >= _mark:
				# Nobody answered the prompt, so answer it.
				if _two.has_method("begin"):
					_two.call("begin")
					_mark = _f + 600
				else:
					_check("part two is up and on its first slide", false, "it never started")
					return _finish()
		2:
			# BACK off the front, which hands the floor to part one.
			_press(KEY_LEFT)
			_stage = 3
			_mark = _f + 10
		3:
			if _f >= _mark:
				_check("back off the first slide lands in part one",
					bool(_two.call("is_lent_back")) and bool(_show.get("_lent")),
					"part two has stopped, part one has the floor")
				_press(KEY_RIGHT)
				_stage = 4
				_mark = _f + 20
		4:
			if _f >= _mark:
				_check("and forward gets you back to part two",
					not bool(_two.call("is_lent_back")) and not bool(_show.get("_lent"))
						and bool(_two.call("is_running")),
					"this is the deadlock - `_done` used to eat the key")
				# AND PART ONE'S STAGE IS EMPTY WHEN IT GOES. Lending the floor back puts
				# the mined rock up; taking it back used to leave it there, and every part
				# two slide after that was played inside a voxel block.
				var standing := 0
				for piece in (_show.get("_exhibits") as Array):
					if piece != null and (piece as Node4D).visible:
						standing += 1
				_check("and part one's rock does not come with it", standing == 0,
					"%d of part one's exhibits still on the drum" % standing)
				return _finish()
	return false


func _press(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	# Straight to both handlers, in the order the viewport would deliver them, because the
	# dummy driver does not reliably run a parsed event out to _unhandled_input.
	_two.call("_unhandled_input", ev)
	_show.call("_unhandled_input", ev)


func _finish() -> bool:
	print("\n%d FAIL(s)" % _fails.size())
	quit(1 if _fails.size() > 0 else 0)
	return true
