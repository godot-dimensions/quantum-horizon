extends SceneTree

## Pressing C without ever having spoken to Trym, which is how this gets played.
##
## THE SHORTCUT HAS TO LEAVE HIM WHERE THE WALK WOULD HAVE. Its own header says so. It was
## missing two of the flags his talk driver keys off, and both were invisible to a test
## that talked to him first:
##
##   `_met` - you cannot have walked the invitation without meeting him; he offers it
##   halfway through the first conversation. Left false, the SECOND thing he said after
##   the cinema was his own introduction. You came home, gave him your opinion of the
##   presentation, and then he said hello and explained that his legs had developed
##   opinions.
##
##   `_shown_it` - set by the `trym_invite` effect, which the shortcut never runs. Left
##   false, `_entry_node` falls through to `offer` for the rest of the session and the
##   ticket is unreachable.
##
## So this one never talks to him before pressing C. The old runner did, and passed.

var _root: Node
var _f := 0
var _fails: Array = []
var _driver: Node
var _stage := 0
var _mark := 0
var _seen: Array = []


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root


func _check(label: String, ok: bool, detail: String) -> void:
	print("   %s %-44s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fails.append(label)


func _process(_d) -> bool:
	_f += 1
	if _f < 60:
		return false
	if _driver == null:
		_driver = _root.get_node_or_null("Systems/TrymDriver")
		if _driver == null:
			_check("the driver is in the scene", false, "Systems/TrymDriver")
			return _finish()
		# AND HE IS NOT TALKABLE WHILE HE WALKS. Opening a conversation slides the player
		# onto a marker beside his desk, so catching him halfway out of the shed put you
		# in the shed and left him walking away from you. Forced rather than observed -
		# waiting for him to actually set off would mean playing the invitation out.
		var invite: Node = _root.get_node("Invitation")
		var could: bool = bool(_driver.call("_can_talk"))
		# THE WHOLE ERRAND, not the walking. He stops at the end of the walk, while the
		# door rises and while he waits for you to follow - and the moving flag goes false
		# at every one of those, so a guard built on it let the prompt flash back on
		# repeatedly mid-errand.
		for beat in [2, 3, 4, 5, 6]:
			invite.set("_beat", beat)
			if bool(_driver.call("_can_talk")):
				_check("the prompt stays out for the whole errand", false,
					"F came back at beat %d" % beat)
				break
		_check("the prompt stays out for the whole errand",
			not bool(_driver.call("_can_talk")),
			"walking, raising, calling, leaving, open - F on none of them")
		invite.set("_beat", 7)
		_check("and comes back once you are both home",
			bool(_driver.call("_can_talk")) == could,
			"exactly as talkable as before he got up")
		invite.set("_beat", 0)
		print("\n--- C, without ever having spoken to him ---")
		_check("you have not met him", not bool(_driver.get("_met")),
			"nobody has pressed F on him")
		_root.get_node("Crossing").call("go_for_testing")
		_stage = 1
		_mark = _f + 500
		return false

	match _stage:
		1:
			if bool(_root.get_node("Crossing").call("is_away")):
				_check("the shortcut staged the whole trip",
					bool(_driver.get("_met")) and bool(_driver.get("_shown_it")),
					"met AND shown - you cannot have walked it without both")
				_root.get_node("Crossing").call("come_back")
				_stage = 2
				_mark = _f + 20
			elif _f >= _mark:
				_check("the shortcut staged the whole trip", false, "it never got there")
				return _finish()
		2:
			if _f >= _mark:
				for i in 3:
					_seen.append(String(_driver.call("_entry_node")))
				print("   three conversations: %s" % [_seen])
				_check("he asks what you thought first",
					_seen[0] == "what_did_you_think", "the reason you came back")
				_check("then hands over the ticket", _seen[1] == "greet_ticket",
					"which was unreachable while `_shown_it` was false")
				_check("and never replays his introduction",
					not _seen.has("intro"),
					"`intro` is the legs line - second in the list before this fix")
				return _finish()
	return false


func _finish() -> bool:
	print("\n%d FAIL(s)" % _fails.size())
	quit(1 if _fails.size() > 0 else 0)
	return true
