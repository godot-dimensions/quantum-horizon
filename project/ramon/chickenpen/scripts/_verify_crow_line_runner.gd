extends SceneTree

## The crows arrive and somebody says something about it.
##
## The timings here are forced down to nothing. The real thing waits between fifty-five and
## a hundred and fifty seconds for a lot of crows and then four more before the line, which
## is right in a field and absurd in a test.

var _root: Node
var _f := 0
var _fails: Array = []
var _crow: Node
var _box: DialogueBox4D
var _talk: Node
var _stage := 0
var _said_frame := -1


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
	if _f < 20:
		return false
	if _crow == null:
		_crow = _root.get_node_or_null("Systems/CrowLine")
		_box = _root.get_node_or_null("UI/ThoughtBox") as DialogueBox4D
		_talk = _root.get_node_or_null("Systems/Talk")
		var sfx: Node = _root.get_node_or_null("Systems/Sfx")
		if _crow == null or _box == null or sfx == null:
			_check("the pieces are in the scene", false, "CrowLine / ThoughtBox / Sfx")
			return _finish()
		print("\n--- the crows ---")
		_check("the crows announce themselves", sfx.has_signal("crows_rising"),
			"signal crows_rising, from the bottom of the swell")
		_check("and the line is listening",
			sfx.is_connected("crows_rising", Callable(_crow, "_on_crows_rising")),
			"Systems/Sfx -> Systems/CrowLine")
		_check("the thought is a band, not a speech bubble", _box.layout == 0,
			"BOTTOM_BAND - it is nobody's head")
		_check("and it says nothing before the crows do", not _box.visible,
			"the box is empty on arrival")
		_crow.set("delay_seconds", 0.2)
		_crow.set("hold_seconds", 0.4)
		return false

	match _stage:
		0:
			# Somebody is mid-sentence. The crows must go unremarked.
			_talk.call("begin")
			_crow.call("_on_crows_rising")
			_stage = 1
			_said_frame = _f + 40
		1:
			if _f >= _said_frame:
				_check("it holds its tongue while somebody is talking",
					not _box.visible and not bool(_crow.get("_said")),
					"the keeper was mid-line, so the crows went unremarked")
				_talk.call("stop")
				_crow.call("_on_crows_rising")
				_stage = 2
				_said_frame = _f + 40
		2:
			if _box.visible:
				_check("and says it when nobody is", true,
					'"%s"' % _crow.get("line"))
				_stage = 3
				_said_frame = _f + 400
			elif _f >= _said_frame:
				_check("and says it when nobody is", false, "nothing came up")
				return _finish()
		3:
			# It has to go away on its own. There is no key to press and no conversation
			# to end, so a line that stayed would stay for the rest of the level.
			if not _box.visible:
				_check("then takes itself away", true, "closed after the hold, unprompted")
				# And once only, or a thought had every ninety seconds becomes a tic.
				_crow.call("_on_crows_rising")
				_stage = 4
				_said_frame = _f + 60
			elif _f >= _said_frame:
				_check("then takes itself away", false, "still up after %d frames" % 400)
				return _finish()
		4:
			if _f >= _said_frame:
				_check("and does not say it twice", not _box.visible,
					"once a run, because the crows come round every minute")
				# THE THEATRE HAS NO WEATHER. Caught mid-wait by the door, the line would
				# otherwise have arrived four seconds later on a wall in a room hanging in
				# nothing - so the crossing cancels it and takes the box with it.
				_crow.set("once", false)
				_crow.set("delay_seconds", 4.0)
				_crow.call("_on_crows_rising")
				_root.get_node("Crossing").call("go_for_testing")
				_stage = 5
				_said_frame = _f + 300
		5:
			if _f >= _said_frame:
				_check("and nothing about crows follows you inside",
					not _box.visible and bool(_root.get_node("Crossing").call("is_away")),
					"the pending line was cancelled on the way through the door")
				return _finish()
	return false


func _finish() -> bool:
	print("\n%d FAIL(s)" % _fails.size())
	quit(1 if _fails.size() > 0 else 0)
	return true
