extends SceneTree

## Nothing of the Lookout carries over into the pen (Ramon, 3 Oct: "no watchtower hud or ui elements
## are allowed to carry over to the main scene when you're down the tower again"). At the tower:
## the card shows, the journal can open, the hawk can fly, P turns the projection on and F4 the
## developer overlay. Then back in the pen: the card gone, the journal shut, the overlay switched
## itself off, F4 and J doing nothing, no balloon tag. The hawk (U) and the projection (P) are the
## pen's own (Ramon, 3 Oct): on its controls card, and working out here.
## Prints PASS or FAIL per check. Gives up after 90 s.
##
##   godot... --path project --windowed --resolution 1280x720 --position 40,40
##       --script res://ramon/chickenpen/lookout/_verify_no_carry_over_runner.gd

var _room: Node
var _lookout: Node
var _player: Node4D
var _t: float = 0.0
var _step: int = -1
var _wait: float = 0.0
var _fails: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_room = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	_room.get_node("Systems/Lookout").set("journal_path", "user://lookout_journal_carry_test.cfg")
	root.add_child(_room)
	current_scene = _room


func _check(what: String, ok: bool) -> void:
	if not ok:
		_fails += 1
	print("   %s %s" % ["PASS" if ok else "FAIL", what])


func _key(code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	var up: InputEventKey = e.duplicate()
	up.pressed = false
	Input.parse_input_event(up)


func _card_shown() -> bool:
	var card := _room.get_node("UI/Journal") as CanvasItem
	return card.visible and card.modulate.a > 0.5


func _process(d: float) -> bool:
	_t += d
	if _t > 90.0:
		print("NO CARRY OVER FAIL: timed out at step %d" % _step)
		return true
	_wait -= d
	if _wait > 0.0:
		return false
	match _step:
		-1:
			var grass: Node = _room.get_node_or_null("World/Grass")
			if (grass != null and not bool(grass.get("mask_ready"))) or _t < 6.0:
				return false
			_lookout = _room.get_node("Systems/Lookout")
			for f in ["approached", "met_wren"]:
				_lookout.get("journal").call("set_flag", f, true)
			_player = _room.get_node("Player") as Node4D
			var tower: Vector4 = (_room.get_node("World/LookoutSite/Lookout") as Node4D).global_position
			_player.global_position = tower + Vector4(4.0, 0.05, 6.0, 0.0)
			_step = 0
			_wait = 2.0
		0:
			_check("at the tower: the Lookout card shows", _card_shown())
			_check("at the tower: the journal could open", bool(_lookout.get("book").call("can_open")))
			_check("at the tower: the hawk could fly", bool(_lookout.get("hawk_flight").call("can_fly")))
			_key(KEY_P)
			_key(KEY_F4)
			_step = 1
			_wait = 0.6
		1:
			_check("at the tower: P turned the projection on", bool(_lookout.get("projection")))
			_check("at the tower: F4 turned the developer overlay on", bool(_lookout.get("dev_overlay").get("on")))
			# Back to the pen's middle, by the coop.
			_player.global_position = Vector4(2.0, 0.05, 2.0, 0.0)
			_step = 2
			_wait = 2.0
		2:
			_check("in the pen: the Lookout card is gone", not _card_shown())
			_check("in the pen: the projection stays on (a pen key)", bool(_lookout.get("projection")))
			_check("in the pen: the developer overlay switched itself off", not bool(_lookout.get("dev_overlay").get("on")))
			_check("in the pen: the journal cannot open", not bool(_lookout.get("book").call("can_open")))
			# The hawk is the pen's own (on its controls card), not the Lookout's: it flies from here.
			_check("in the pen: the hawk still flies (a pen key)", bool(_lookout.get("hawk_flight").call("can_fly")))
			var controls: Node = _room.get_node("UI/Controls")
			var rows: Array = controls.get("_rows")
			var listed: bool = false
			for row in rows:
				if String(row[1]) == "fly as the hawk":
					listed = true
			_check("in the pen: the controls card lists the hawk", listed)
			var lists_p: bool = false
			for row in rows:
				if String(row[1]).begins_with("projection"):
					lists_p = true
			_check("in the pen: the controls card lists the projection", lists_p)
			var tag: Node = _lookout.get("_board_tag")
			_check("in the pen: no balloon tag", tag == null or not (tag as CanvasItem).visible)
			_key(KEY_P)
			_key(KEY_F4)
			_key(KEY_J)
			_step = 3
			_wait = 0.6
		3:
			_check("in the pen: P turns the projection off again", not bool(_lookout.get("projection")))
			_check("in the pen: F4 does nothing", not bool(_lookout.get("dev_overlay").get("on")))
			_check("in the pen: J does nothing", not (_lookout.get("book") as CanvasItem).visible)
			print("NO CARRY OVER %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
			if FileAccess.file_exists("user://lookout_journal_carry_test.cfg"):
				DirAccess.remove_absolute(ProjectSettings.globalize_path("user://lookout_journal_carry_test.cfg"))
			return true
	return false
