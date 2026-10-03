extends SceneTree

## The Lookout's story, played through by keys: walking near the tower plays the approach;
## the ladder will not climb until you have met Wren; talking to her (the real dialogue,
## Space and number keys) hands you the camera; the first climb gets Wren on the radio;
## a few photos bring the owl hint; a good photo of the owl plays its reveal; enough photos
## bring the balloon; climbing down and talking to Wren offers it; the ride goes, Escape
## twice brings it down, and Wren asks about it after.
##
## Windowed, small, unfocused; saves res://smoke_test_output/story_<n>_<what>.png. Its own
## journal, deleted at the end.
##
##   godot... --path project --windowed --resolution 1280x720 --position 40,40
##       --script res://ramon/chickenpen/lookout/_verify_story_runner.gd

const TEST_BOOK := "user://lookout_journal_story_test.cfg"

var _room: Node
var _lookout: Node
var _station: Node
var _story: Node
var _journal: Node
var _player: Node4D
var _t: float = 0.0
var _step: int = 0
var _failed: int = 0
var _n: int = 0
var _wait: float = 0.0
var _choices: Array = []
var _talk: Node
var _box: Node
var _acted: float = 0.0
var _photos: int = 0
var _downs: int = -1
var _aimed: bool = false


func _initialize() -> void:
	root.unfocusable = true
	_clean()
	_room = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	for node in _room.find_children("*", "", true, false):
		if "debug_key_enabled" in node:
			node.set("debug_key_enabled", false)
	_lookout = _room.get_node("Systems/Lookout")
	_lookout.set("journal_path", TEST_BOOK)
	root.add_child(_room)
	current_scene = _room


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("   %s %-62s %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _save(what: String) -> void:
	root.get_texture().get_image().save_png("res://smoke_test_output/story_%d_%s.png" % [_n, what])
	_n += 1


func _key(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		root.push_input(e)


func _next(after: float = 0.0) -> void:
	_step += 1
	_wait = after
	_t = 0.0


func _put_player(at: Vector4) -> void:
	_player.global_position = at
	_player.set("linear_velocity", Vector4.ZERO)


## Talking: Space through the lines, the scripted reply when replies are up. True when the
## conversation is over.
func _talk_through(delta: float) -> bool:
	_acted -= delta
	if not bool(_talk.call("is_running")):
		return true
	if _acted > 0.0:
		return false
	_acted = 0.35
	if OS.get_cmdline_user_args().has("debug"):
		print("      talk: typing %s choices %s key %s" % [_box.call("is_typing"), _box.call("has_choices"), _talk.get("_key")])
	if bool(_box.call("has_choices")):
		# The arrows and Space, as a player picks: the pen's inventory belt takes the
		# number keys in _input before the dialogue ever sees them.
		if _downs < 0:
			_downs = (int(_choices.pop_front()) if not _choices.is_empty() else 1) - 1
		if _downs > 0:
			_key(KEY_DOWN)
			_downs -= 1
		else:
			_key(KEY_SPACE)
			_downs = -1
	else:
		_key(KEY_SPACE)
	return false


func _process(d: float) -> bool:
	_t += d
	if _t < _wait:
		return false
	match _step:
		0:
			if _t < 3.0:
				return false
			_station = _lookout.get("station")
			_story = _lookout.get("story")
			_journal = _lookout.get("journal")
			_player = _room.get_node("Player") as Node4D
			_talk = _room.get_node("Systems/WrenTalk")
			_box = _room.get_node("UI/WrenBox")
			_check("a fresh journal: no story yet", not bool(_journal.call("flag", "approached")))
			_check("the card says to meet Wren", String(_lookout.call("next_hint")).contains("Wren"), String(_lookout.call("next_hint")))
			var tower: Node4D = _lookout.get("tower")
			_put_player(tower.global_position + Vector4(6.0, 0.05, 13.0, 0.0))
			_next(0.6)
		1:
			_check("walking near the tower plays the approach", bool(_lookout.call("story_busy")))
			_next(1.4)
		2:
			_save("approach_a")
			_next(2.0)
		3:
			_save("approach_b")
			_next(3.2)
		4:
			_check("the approach is over and the player has control", not bool(_lookout.call("story_busy")) and _player.get("input_enabled") == true)
			# The ladder is Wren's until you have met her.
			_put_player((_lookout.get("tower") as Node4D).call("ladder_foot") + Vector4(0, 0.05, 0.3, 0))
			_next(0.6)
		5:
			_check("no climbing before meeting Wren", not bool(_lookout.call("can_climb")))
			_save("ladder_before_wren")
			var head: Node4D = _lookout.get("wren_head")
			_put_player(Vector4(head.global_position.x - 0.4, 0.05, head.global_position.z + 1.6, 0.0))
			_next(0.8)
		6:
			_save("wren_prompt")
			_key(KEY_F)
			_choices = [2, 1]
			_next(0.5)
		7:
			_check("F starts the conversation with Wren", bool(_talk.call("is_running")))
			_save("wren_talking")
			_next()
		8:
			if _talk_through(d):
				_check("met Wren: the camera is yours", bool(_journal.call("flag", "met_wren")))
				_check("she no longer carries it", _lookout.get("wren").get("has_camera") == false)
				_check("the card says to climb", String(_lookout.call("next_hint")).contains("climb"), String(_lookout.call("next_hint")))
				_put_player((_lookout.get("tower") as Node4D).call("ladder_foot") + Vector4(0, 0.05, 0.3, 0))
				_next(0.8)
		9:
			_check("now the ladder climbs", bool(_lookout.call("can_climb")))
			_key(KEY_F)
			_next(float(_station.get("climb_seconds")) + 0.8)
		10:
			_check("up on the deck, the camera raised", bool(_station.call("up_tower")))
			_check("Wren on the radio for the first climb", bool(_lookout.get("radio").call("busy")))
			_save("first_climb_radio")
			_photos = 0
			_next()
		11:
			# A few photos of the field, wherever the lens points.
			if _t > 0.6:
				var a: float = float(_photos) * 0.9 + 2.2
				_station.call("look_along", Vector4(-sin(a), -0.35, -cos(a), 0.0))
				_station.call("take_photo")
				_photos += 1
				_t = 0.0
				if _photos >= 4:
					_next(1.0)
		12:
			_check("four photos in, the owl hint", bool(_journal.call("flag", "owl_hint")))
			# Round to the north side of the deck, where the owl's post is.
			var tower: Node4D = _lookout.get("tower")
			_player.global_position = tower.global_position + Vector4(0.6, float(tower.get("deck_height")) + 0.05, -2.9, 0.0)
			_player.set("linear_velocity", Vector4.ZERO)
			var owl: Node4D = _lookout.get("owl")
			_station.call("look_along", (owl.call("head_point") as Vector4) - (_station.call("home_eye") as Vector4))
			_station.set("zoom_goal", 3.0)
			_station.set("focus_goal", 1.5)
			_next(1.5)
		13:
			# Aimed again now the eye has leaned over to the north window: aimed from the
			# window it was at, the lean swings the view 25 degrees off.
			if not _aimed:
				_aimed = true
				var owl: Node4D = _lookout.get("owl")
				_station.call("look_along", (owl.call("head_point") as Vector4) - (_station.call("home_eye") as Vector4))
				_wait = 0.6
				_t = 0.0
				return false
			_station.call("take_photo")
			_next(0.6)
		14:
			_check("a good photo of the owl finds it", bool(_journal.call("found", "owl")), str(_journal.get("recent").back()))
			_check("and plays its reveal", bool(_lookout.call("story_busy")))
			_save("owl_reveal_a")
			_next(1.8)
		15:
			_save("owl_reveal_b")
			_next(3.0)
		16:
			_check("the reveal hands the camera back", not bool(_lookout.call("story_busy")) and (_station.get("camera") as Camera4D).is_current())
			# Fill the book to the balloon: eight more photos' worth, then one more photo.
			var slots: Dictionary = _journal.get("slots")
			var k: int = 0
			for page in ["crows", "chickens", "nike", "cats", "folk", "starlings", "hawk", "crows"]:
				var row: Array = slots[page]
				var at: int = 1 if page == "crows" and k > 0 else 0
				row[at] = {"points": 100, "doing": "test", "file": "", "time": 0.0, "from": "tower"}
				k += 1
			_journal.call("save_book")
			_check("enough for the balloon", bool(_story.call("balloon_open")), "%d photos" % int(_journal.call("star_count")))
			_station.set("focus_goal", 0.0)
			_station.call("take_photo")
			_next(1.0)
		17:
			_check("Wren calls you down for the balloon", bool(_journal.call("flag", "balloon_said")))
			_check("the balloon is going up by the tower", (_lookout.get("balloon") as Node4D).visible)
			_check("and the HUD card says B", bool(_lookout.call("can_board")))
			_station.call("climb_down")
			_next(float(_station.get("down_seconds")) + 1.0)
		18:
			_check("back on the ground", int(_station.get("mode")) == 0)
			var head: Node4D = _lookout.get("wren_head")
			_put_player(Vector4(head.global_position.x - 0.4, 0.05, head.global_position.z + 1.6, 0.0))
			_next(0.8)
		19:
			_key(KEY_F)
			_choices = [1]
			_next(0.4)
		20:
			if _talk_through(d):
				_next(0.6)
		21:
			_check("Wren's offer boards the balloon", int(_station.get("mode")) == 4 and bool(_lookout.get("balloon").get("riding")))
			_save("ride_start")
			_next(4.0)
		22:
			_save("ride_up")
			# Escape twice: straight down.
			_key(KEY_ESCAPE)
			_next(0.6)
		23:
			_key(KEY_ESCAPE)
			_next(0.5)
		24:
			if bool(_lookout.get("balloon").get("riding")) and _t < 40.0:
				return false
			_check("Escape twice brought it down", not bool(_lookout.get("balloon").get("riding")), "%.1f s" % _t)
			_check("the ride is in the story", bool(_journal.call("flag", "balloon_ridden")))
			_next(1.0)
		25:
			var head: Node4D = _lookout.get("wren_head")
			_put_player(Vector4(head.global_position.x - 0.4, 0.05, head.global_position.z + 1.6, 0.0))
			_next(0.8)
		26:
			_key(KEY_F)
			_choices = [4]
			_next(0.5)
		27:
			_check("Wren asks about the ride", bool(_talk.call("is_running")))
			_save("after_ride")
			_next()
		28:
			if _talk_through(d):
				_check("she has said her after-ride piece", bool(_journal.call("flag", "after_ride_said")))
				_next(0.3)
		29:
			_clean()
			print("STORY RUNNER: %s (%d failed)" % ["PASS" if _failed == 0 else "FAIL", _failed])
			return true
	return false


## The test journal and its photos gone - at the start too, in case a run was killed.
func _clean() -> void:
	var book: String = ProjectSettings.globalize_path(TEST_BOOK)
	if FileAccess.file_exists(TEST_BOOK):
		DirAccess.remove_absolute(book)
	var photos: String = ProjectSettings.globalize_path("user://lookout_journal_story_test_photos")
	if DirAccess.dir_exists_absolute(photos):
		for f in DirAccess.get_files_at(photos):
			DirAccess.remove_absolute(photos + "/" + f)
		DirAccess.remove_absolute(photos)
