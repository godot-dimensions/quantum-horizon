extends Node

## The Lookout's story: a handful of beats, each a few radio lines or a short camera move,
## and the line on the HUD card that says what to do next.
##
##   the approach   first time you come near the tower: the camera rises up it to the cab,
##                  and comes down on Wren at its foot (anticipation)
##   meeting Wren   she hands you her camera: "the ring focuses in W"
##   first climb    on the radio: E and Q, the scale at the bottom, the shutter
##   first photo    "that's in the book, J"
##   the owl hint   after a few photos, or a minute and a half up there, if you have not
##                  found it yet: "a dead tree north of the tower ... about one and a half, ana"
##   the owl        the first good photo of it: the camera goes to it, it turns its head
##                  through W (the payoff), and Wren is delighted
##   the balloon    once the owl and eight photos are in the book: "come down, I want to
##                  show you something" - the balloon is there, inflated, by the tower
##   the heron      out along W in the balloon: "there's water out here"
##   every page     "I'll have to go and find more things"
##
## THE BEATS ARE FLAGS IN THE JOURNAL, so they keep with the book across sessions and a
## fresh journal (Ctrl+Backspace in the book) starts the story over.

const WrenScript := preload("res://ramon/chickenpen/lookout/wren_script.gd")
const JOURNAL := preload("res://ramon/chickenpen/lookout/field_journal_4d.gd")

## How close, across the ground, before the approach plays.
@export_range(5.0, 40.0, 0.5, "suffix:m") var approach_within: float = 17.0
## Up the tower this long without finding the owl, and Wren says where to look.
@export_range(10.0, 600.0, 5.0, "suffix:s") var owl_hint_after: float = 90.0
@export_range(1, 20) var owl_hint_photos: int = 4
## Photos in the book, besides the owl, before the balloon is offered.
@export_range(1, 40) var balloon_after: int = 8

var lookout: Node
var _cab_time: float = 0.0
var _photos: int = 0


func setup(owner_lookout: Node) -> void:
	lookout = owner_lookout


func _journal() -> Node:
	return lookout.get("journal")


func _flag(key: String) -> bool:
	return bool(_journal().call("flag", key))


func _raise(key: String) -> void:
	_journal().call("set_flag", key, true)


func _radio(lines: Array) -> void:
	lookout.get("radio").call("say", lines)


func busy() -> bool:
	var cut: Node = lookout.get("cutscene")
	return cut != null and bool(cut.call("is_playing"))


func met() -> bool:
	return _flag("met_wren")


func balloon_open() -> bool:
	return _journal().call("found", "owl") and int(_journal().call("star_count")) >= balloon_after + 1


# --- What the card says -----------------------------------------------------------------------

func next_hint() -> String:
	var journal: Node = _journal()
	var pages: int = int(journal.call("pages_found"))
	var total: int = JOURNAL.PAGES.size()
	if not met():
		return "Next: meet Wren at the lookout tower"
	if not _flag("first_climb"):
		return "Next: climb the lookout (F at the ladder), or Z for the camera"
	if int(journal.call("star_count")) == 0:
		return "Next: take a photo, click"
	if not bool(journal.call("found", "owl")):
		return "Next: what sits in the dead tree, north of the tower?" if _flag("owl_hint") else "Next: fill Wren's journal"
	if balloon_open() and not _flag("balloon_ridden"):
		return "Next: Wren has something to show you"
	if _flag("balloon_ridden") and not bool(journal.call("found", "heron")) and not bool(journal.call("found", "chipmunks")):
		return "Next: something lives out along W, ana or kata"
	if _flag("balloon_ridden") and not bool(journal.call("found", "heron")):
		return "Next: something stands in the water, ana"
	if _flag("balloon_ridden") and not bool(journal.call("found", "chipmunks")):
		return "Next: there are trees out along kata"
	if pages >= total and int(journal.call("star_count")) >= total * 4:
		return "Every photo in the book"
	if pages >= total:
		return "Every page found. Now every behaviour"
	return "Next: fill Wren's journal, %d pages to find" % (total - pages)


## A tip from Wren about something not in the book yet, nearest the start of the book first.
func tip() -> String:
	var journal: Node = _journal()
	if not bool(journal.call("found", "owl")):
		return "North of the tower there's a dead tree I can only hear. Try the ring at about one and a half, ana."
	for page in JOURNAL.PAGES:
		if bool(page["secret"]) and not bool(journal.call("found", page["id"])):
			match String(page["id"]):
				"white_starling":
					return "One of the starlings is white. One in five thousand. You'll want the long lens, and patience."
				"heron":
					return "There's water out along W. You can only reach it in the balloon, or on foot if you walk a long way ana."
				"chipmunks":
					return "The marsh is ana of the field. Kata of it, the same field has trees. Take the balloon kata, or walk it, Q."
		for k in 4:
			if not bool(journal.call("filled", page["id"], k + 1)):
				if bool(page["secret"]) and not bool(journal.call("found", page["id"])):
					continue
				return "%s. %s" % [String(page["title"]), String(page["hints"][k])]
	return "You've got everything I know about. Go and find something I don't."


func wren_opening() -> String:
	if not met():
		return WrenScript.START_MEET
	var total: int = JOURNAL.PAGES.size()
	if int(_journal().call("pages_found")) >= total and not _flag("done_said"):
		_raise("done_said")
		return WrenScript.START_DONE
	if balloon_open() and not _flag("balloon_ridden"):
		return WrenScript.START_BALLOON
	if _flag("balloon_ridden") and not _flag("after_ride_said"):
		_raise("after_ride_said")
		return WrenScript.START_AFTER_RIDE
	return WrenScript.START_AGAIN


# --- Beats -----------------------------------------------------------------------------------

func on_camera_given() -> void:
	_raise("met_wren")
	var wren: Node = lookout.get("wren")
	if wren != null:
		wren.set("has_camera", false)
	lookout.call("sound", &"page")


func on_wren_spoken() -> void:
	pass


## The camera explained the first time it comes up, wherever that is: on the ground with Z or
## on the deck after the climb.
func on_camera_raised() -> void:
	if _flag("first_raise"):
		return
	_raise("first_raise")
	_radio([
		"Can you hear me? Good, that's the radio. The ring on the lens is the clever part: E and Q.",
		"It doesn't focus near and far. It focuses in W.",
		"See the scale at the bottom? Every mark on it is something out there. Put the needle on one, and there it is.",
		"Click to take a picture. T finds the focus for you. Z puts the camera down.",
		"Try me first. I'm the easy one.",
	])


## The owl's tick has come up on the scale for the first time, not found yet.
func on_owl_tick() -> void:
	if _flag("owl_tick") or _flag("owl_found") or busy():
		return
	_raise("owl_tick")
	_radio([
		"See that mark on the scale, pulsing? Something's out there, ana of you, about one and a half.",
		"Turn the ring to it. E.",
	])


func on_cab_entered() -> void:
	_cab_time = 0.0
	if not _flag("first_climb"):
		_raise("first_climb")
		_radio(["Walk round, the deck goes all the way. The best of it is north, over the field."])
	elif balloon_open() and not _flag("balloon_ridden") and not _flag("balloon_said"):
		_balloon_call()


func on_photo(result: Dictionary) -> void:
	_photos += 1
	var look: Dictionary = result.get("look", {})
	var good: bool = String(result.get("verdict", "")) == "good"
	# The owl first: if it is the first good photo of all, its reveal is the bigger moment.
	if good and String(look.get("page", "")) == "owl" and not _flag("owl_found"):
		_raise("owl_found")
		_raise("first_photo")
		_owl_reveal()
		return
	if good and not _flag("first_photo"):
		_raise("first_photo")
		_radio(["That's in the book. J to have a look, whenever you like."])
		return
	if good and bool(result.get("new_page", false)) and String(look.get("page", "")) == "heron":
		lookout.call("on_heron_found")
	if good and balloon_open() and not _flag("balloon_said") and bool(lookout.get("station").call("up_tower")):
		_balloon_call()
		return
	if not bool(_journal().call("found", "owl")) and not _flag("owl_hint") and _photos >= owl_hint_photos:
		_owl_hint()


func _owl_hint() -> void:
	_raise("owl_hint")
	_radio([
		"One more thing. North of the tower there's an old dead tree, a little way along W. I hear something in it at night.",
		"I've never seen it. Try the ring at about one and a half, ana.",
	])


func _balloon_call() -> void:
	_raise("balloon_said")
	lookout.call("show_balloon", true)
	_radio([
		"You've an eye for this.",
		"My balloon's up by the tower. B when you're ready, and up you go.",
	])


func _owl_reveal() -> void:
	var owl: Node4D = lookout.get("owl")
	var station: Node = lookout.get("station")
	var cam: Camera4D = station.get("camera")
	if owl == null or cam == null:
		_radio(["That's it! It's been out there the whole time. Just not here."])
		return
	var head: Vector4 = owl.call("head_point")
	var toward: Vector4 = (cam.global_position - head)
	toward.w = 0.0
	toward = toward.normalized()
	var side := Vector4(-toward.z, 0.0, toward.x, 0.0)
	var keys: Array = [
		[0.0, cam.global_position, head],
		[0.45, head + toward * 1.6 + side * 0.35 + Vector4(0, 0.15, 0, 0), head],
		[1.0, head + toward * 1.15 - side * 0.25 + Vector4(0, 0.05, 0, 0), head],
	]
	owl.call("perform", "turn_w", 1.0)
	lookout.get("cutscene").call("play", keys, 4.6, "", true, func() -> void:
		_radio([
			"That's it! It's been out there the whole time. Just not here.",
			"Watch it for a while. Owls do things with their heads you won't believe.",
		]))


func board_balloon() -> void:
	var balloon: Node = lookout.get("balloon")
	if balloon != null:
		balloon.call("board")


func on_ride_started() -> void:
	_raise("balloon_ridden")


# --- The approach ----------------------------------------------------------------------------

func _process(delta: float) -> void:
	var station: Node = lookout.get("station")
	if bool(station.call("up_tower")):
		_cab_time += delta
		if _cab_time > owl_hint_after and not _flag("owl_hint") and not bool(_journal().call("found", "owl")):
			_owl_hint()
	if not _flag("approached") and not busy() and not bool(station.call("busy")):
		var player: Node4D = lookout.get("player")
		var tower: Node4D = lookout.get("tower")
		if player != null and tower != null and player.is_visible_in_tree() and player.get("input_enabled") == true:
			var gap: Vector4 = tower.global_position - player.global_position
			if Vector2(gap.x, gap.z).length() < approach_within and absf(gap.w) < 3.0:
				_raise("approached")
				_approach()


func _approach() -> void:
	var tower: Node4D = lookout.get("tower")
	var cam: Camera4D = lookout.call("current_camera")
	var head: Node4D = lookout.get("wren_head")
	var base: Vector4 = tower.global_position
	var h: float = float(tower.get("deck_height"))
	var start: Vector4 = cam.global_position if cam != null else base + Vector4(0, 2, 18, 0)
	var wren_at: Vector4 = head.global_position if head != null else base + Vector4(3, 1.5, 6, 0)
	var keys: Array = [
		[0.0, start, base + Vector4(0, 4.0, 0, 0)],
		[0.3, base + Vector4(7.0, 3.0, 11.0, 0), base + Vector4(0, h * 0.6, 0, 0)],
		[0.62, base + Vector4(4.5, h + 2.2, 7.5, 0), base + Vector4(0, h + 1.2, 0, 0)],
		[1.0, wren_at + Vector4(1.6, 0.25, 3.2, 0), wren_at],
	]
	lookout.get("cutscene").call("play", keys, 6.0, "The Lookout")
