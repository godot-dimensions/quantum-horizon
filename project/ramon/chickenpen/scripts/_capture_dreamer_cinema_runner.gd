extends SceneTree

## Plays the dreamer's conversation as a scene (cave_dreamer_cinema_4d.gd) and saves a frame
## of every line and of every set of replies, named for the node, the line and the shot:
## res://smoke_test_output/cine_<n>_<node>_<line>_<shot>.png. Through "What are you?", down
## to "Could you end all this?" and its threat, back, and "I'll go" - which ends in the
## flash and waking in front of the cave, saved as cine_<n>_wake.png. Windowed.
##
## Also checks what the scene promises: you are moved to the mark, the slice is flat and
## locked, the HUD is away, the scene camera is current, and every shot is one it knows.
## And that it will not be skipped: Escape before the offer does nothing, Escape after it
## breaks in with the refusal and a still stare, the conversation carries on at the very
## line it was on, a second Escape gets the shorter answer and the replies back - and the
## game is still running after all of it (the rig's second Escape quits).

const ROOM := Vector4(0, 0, -36, 46)
## Replies to pick, in order, each time replies are offered.
const PICKS := [0, 2, 2, 2, 3, 3]

var _room: Node
var _cave: Node4D
var _f := 0
var _t := 0.0
var _n := 0
var _step := 0
var _picks := 0
var _last := ""
var _failed := 0
var _shots := {}
var _escaped := 0
var _was_refused := false


func _escape() -> void:
	var press := InputEventAction.new()
	press.action = &"ui_cancel"
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventAction.new()
	release.action = &"ui_cancel"
	release.pressed = false
	Input.parse_input_event(release)


func _initialize() -> void:
	# Never takes the keyboard: typing elsewhere while this window is up must not reach
	# the pen (C opens the theatre, E and Q step through W).
	root.unfocusable = true
	_room = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_room)
	current_scene = _room


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("  %s  %s  %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _far(path: String) -> Node:
	var far: Node = _cave.find_child("FarRoom", true, false) if _cave != null else null
	return far.get_node_or_null(path) if far != null else null


func _save(what: String) -> void:
	var path: String = "res://smoke_test_output/cine_%02d_%s.png" % [_n, what]
	root.get_texture().get_image().save_png(path)
	print("   saved %s" % path.get_file())
	_n += 1


func _process(d: float) -> bool:
	_f += 1
	if _f == 10:
		_room.get_node("CaveCrossing").call("go")
	if _f == 14:
		for c in _room.get_children():
			if c.name == "Cave":
				_cave = c
		_room.set_meta(&"cave_first_look_said", true)
	if _f < 20 or _cave == null:
		return false
	_t += d
	var player := _room.get_node("Player") as CharacterBody4D
	match _step:
		0:
			# Off to one side of it and a little off its w, as you might walk up.
			player.global_position = _cave.global_position + ROOM + Vector4(2.5, 0.05, 6.5, -1.5)
			player.linear_velocity = Vector4.ZERO
			var rig := player.get_node("CameraRig")
			rig.set("_slice_zw", deg_to_rad(20.0))
			if _far("Systems/DreamerTalk") != null and _t > 2.0:
				var press := InputEventAction.new()
				press.action = &"catch_target"
				press.pressed = true
				Input.parse_input_event(press)
				_step = 1; _t = 0.0
		1:
			if _t > 0.4:
				var talk: Node = _far("Systems/DreamerTalk")
				_check("F opens the scene", talk != null and bool(talk.call("is_running")))
				var cine: Node = _far("Systems/DreamerCinema")
				_check("the scene is playing", cine != null and bool(cine.call("is_playing")))
				var cam := _far("CinemaCamera") as Camera4D
				_check("through its own camera", cam != null and cam.current)
				var mark: Vector4 = _cave.global_position + ROOM + Vector4(0, 0, 10, 0)
				var at: Vector4 = player.global_position
				_check("with you on the mark", Vector2(at.x - mark.x, at.z - mark.z).length() < 0.05 and absf(at.w - mark.w) < 0.05, "at %s" % (at - _cave.global_position))
				var rig := player.get_node("CameraRig")
				_check("on the flat slice", is_zero_approx(float(rig.get("_slice_xw"))) and is_zero_approx(float(rig.get("_slice_zw"))))
				_check("and it cannot be turned", bool(rig.get("_look_locked")))
				_check("the dial is away", not (_room.get_node("UI/SlicePlane") as CanvasItem).visible)
				_check("and the frame counter", not (_room.get_node("UI/Fps") as CanvasItem).visible)
				# Too early: the skip is not on offer yet, and Escape must not end it either.
				_escape()
				_step = 20; _t = 0.0
		20:
			if _t > 0.3:
				var talk: Node = _far("Systems/DreamerTalk")
				_check("Escape before the offer does nothing", bool(talk.call("is_running")) and not bool(talk.call("is_interrupted")),
					String(talk.get("_key")))
				_step = 2; _t = 0.0
		2:
			var talk: Node = _far("Systems/DreamerTalk")
			var box: Node = _far("UI/DreamerBox")
			var cine: Node = _far("Systems/DreamerCinema")
			if talk == null or not bool(talk.call("is_running")):
				_step = 3; _t = 0.0
				return false
			var shot: String = String(cine.call("shot"))
			_shots[shot] = true
			var key: String = String(talk.get("_key"))
			var line: int = int(talk.get("_at"))
			var choosing: bool = bool(box.call("has_choices"))
			var beat: String = "%s_%d%s" % [key, line, "_choices" if choosing else ""]
			if beat != _last:
				# Back from the refusal: exactly where it was.
				if _was_refused and not bool(talk.call("is_interrupted")):
					_was_refused = false
					_check("and it carries on at the line it was on", beat.begins_with("topic_what_1" if _escaped == 1 else "menu_two_0"), beat)
				_last = beat
				_t = 0.0
			if bool(box.call("is_typing")):
				return false
			# The skip, twice: once mid-line, once while choosing.
			var skip_at: String = "topic_what_1" if _escaped == 0 else ("menu_two_0_choices" if _escaped == 1 else "")
			if beat == skip_at and _t > 1.0:
				_escape()
				_escaped += 1
				_was_refused = true
				_step = 21; _t = 0.0
				return false
			# Long enough into the shot to see where it is going.
			if _t > 2.2:
				_save("%s_%s" % [beat, shot])
				if choosing:
					talk.call("_on_chose", PICKS[mini(_picks, PICKS.size() - 1)])
					_picks += 1
				else:
					talk.call("_advance")
		21:
			if _t > 0.3:
				var talk: Node = _far("Systems/DreamerTalk")
				var want: String = "skip_refused" if _escaped == 1 else "skip_again_1"
				_check("Escape %d breaks in with %s" % [_escaped, want], bool(talk.call("is_running")) and String(talk.get("_key")) == want, String(talk.get("_key")))
				_check("in the still stare", String(_far("Systems/DreamerCinema").call("shot")) == "stare")
				_check("and the offer is struck through", bool(_far("Systems/DreamerCinema").call("has_refused")))
				_step = 2; _t = 0.0
		3:
			if _t > 1.2 and _t - d <= 1.2:
				_save("wake")
			if _t > 4.0:
				_check("every shot is one it knows", not _shots.has(""), str(_shots.keys()))
				_check("and the game is still running after two Escapes", _escaped == 2, "%d" % _escaped)
				print("CINEMA: %s, %d shots used" % ["ALL PASS" if _failed == 0 else "%d FAILED" % _failed, _shots.size()])
				quit()
				return true
	if _f > 20000:
		print("CINEMA: TIMED OUT at step %d, %s" % [_step, _last])
		quit()
		return true
	return false
