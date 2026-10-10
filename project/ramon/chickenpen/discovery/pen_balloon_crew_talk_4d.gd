extends PenNpcTalk4D

## The balloon crew's side of a conversation (discovery/pen_balloon_crew_4d.gd, discovery/balloon_crew_script.gd),
## as the camp guide's (scripts/pen_camp_guide_talk_4d.gd): PenNpcTalk4D owns the reach, the key, the prompt and the
## staging; this gives her script and says it shorter the second time, and differently once the balloon is found.

const CrewScript := preload("res://ramon/chickenpen/discovery/balloon_crew_script.gd")
const Balloon := preload("res://ramon/chickenpen/lookout/balloon_4d.gd")

var _met := false


func _configure() -> void:
	_talk.use_script(CrewScript.NODES, CrewScript.START)


func _entry_node() -> String:
	if Balloon.found:
		return "found"
	if not _met:
		_met = true
		return CrewScript.START
	return "again"


## Ctrl+R: a new visitor.
func reset() -> void:
	_met = false
