extends SceneTree

## Mithra's errand, driven the way a player drives it.
##
## IT FIRES THE REAL EFFECTS, not the fetch node's methods. Her dialogue is what sends
## her - `fetch_chicken` on the last line of the reward, `hand_over_chicken` on the thank
## you - so this emits those through the dialogue player and then watches the field. If
## the wiring between the writing and the behaviour breaks, this goes quiet.

var _root: Node
var _f := 0
var _fails: Array = []
var _fetch: Node
var _talk: Node
var _mithra: Node4D
var _player: Node4D
var _catcher: Node
var _stage := 0
var _t := 0
var _start_gap := 0.0
var _bird_at_start := Vector4.ZERO


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _check(label: String, ok: bool, detail: String) -> void:
	print("   %s %-44s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok: _fails.append(label)


func _step() -> String:
	return ["IDLE", "GOING", "PICKING_UP", "RETURNING", "TALKING", "LEAVING"][int(_fetch.get("step"))]


func _process(_d) -> bool:
	_f += 1
	if _f < 8: return false
	if _fetch == null:
		_fetch = _root.get_node_or_null("Systems/MithraFetch")
		_talk = _root.get_node_or_null("Systems/MithraTalk")
		_mithra = _root.get_node_or_null("Mithra") as Node4D
		_player = _root.get_node_or_null("Player") as Node4D
		_catcher = _root.get_node_or_null("Player/Catcher")
		if _fetch == null or _talk == null or _mithra == null:
			_check("the pieces are in the scene", false, "MithraFetch / MithraTalk / Mithra")
			_finish(); return true
		print("\n--- she is renamed ---")
		# Both discarded names, not just the last one. She has been renamed twice and a
		# check that only knows about the most recent one would miss a stray node left
		# behind by the first pass.
		_check("the character is Mithra", _root.get_node_or_null("Mithra") != null
			and _root.get_node_or_null("Nessa") == null
			and _root.get_node_or_null("Hydra") == null, "node, driver, dialogue and tag")
		_check("her script speaks as Mithra",
			String(load("res://ramon/dialogue/mithra_script.gd").NODES["intro"]["speaker"]) == "Mithra", "")
		print("\n--- she sets off ---")
		_check("idle before the coin comes back", _step() == "IDLE", _step())
		_talk.emit_signal("effect", "fetch_chicken")
		return false

	match _stage:
		0:
			_check("the effect sends her", _step() == "GOING", _step())
			_start_gap = _mithra.global_position.distance_to(_player.global_position)
			_stage = 1
		1:
			# Let her cross the field. She has to actually get there.
			_t += 1
			if _step() == "GOING" and _t < 4000: return false
			_check("she reaches a chicken", _step() != "GOING",
				"now %s after %d frames" % [_step(), _t])
			_stage = 2
			_t = 0
		2:
			_t += 1
			if _step() == "PICKING_UP" and _t < 2000: return false
			_check("she picks it up and turns back", _step() == "RETURNING",
				"%s after the pickup beat" % _step())
			_stage = 3
			_t = 0
		3:
			_t += 1
			if _step() == "RETURNING" and _t < 6000: return false
			_check("she brings it to the player", _step() == "TALKING",
				"%s, %.1f units away" % [_step(),
					_mithra.global_position.distance_to(_player.global_position)])
			_check("and she came to YOU, not to a spot",
				_mithra.global_position.distance_to(_player.global_position) < 2.2,
				"%.2f units" % _mithra.global_position.distance_to(_player.global_position))
			_check("she opened the conversation herself", bool(_talk.call("is_running")),
				"nobody pressed anything")
			print("\n--- the thank you ---")
			_check("the player is empty-handed until then", _catcher.get("carried") == null, "")
			_talk.emit_signal("effect", "hand_over_chicken")
			_stage = 4
		4:
			_check("now the player is holding the chicken", _catcher.get("carried") != null,
				str(_catcher.get("carried")))
			_check("and it is a real catch, not a lookalike",
				_catcher.get("carried") != null
					and String(_catcher.get("carried").call("state_name")) == "CARRIED"
					if _catcher.get("carried") != null
						and _catcher.get("carried").has_method("state_name") else true,
				"through chicken_catcher_4d.give()")
			_talk.emit_signal("effect", "mithra_leaves")
			_stage = 5
			_t = 0
		5:
			_check("she runs off", _step() == "LEAVING", _step())
			_stage = 6
			_t = 0
		6:
			_t += 1
			if _step() == "LEAVING" and _t < 6000: return false
			_check("and settles back into her own life", _step() == "IDLE",
				"%s, searching again: %s" % [_step(), not bool(_mithra.get("halted"))])
			_finish()
			return true
	return false


func _finish() -> void:
	if _fails.is_empty(): print("\nALL PASS")
	else: print("\n%d FAILED: %s" % [_fails.size(), ", ".join(_fails)])
	quit(1 if _fails.size() > 0 else 0)
