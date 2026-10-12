extends SceneTree

## Every key the pen listens to, and any key two things listen to (Ramon, 7 Oct: "at the campsite when
## i say v to align slice, i get dropped in the cave interior. must be bug with keystrokes" - the cave's
## debug trip had been on V since the cave went in, and the camp's align took V on 6 Oct).
##
## Gathers, from the running pen (after the Lookout and the rest have built their parts):
##   - every exported Key property on every node (name ends in "key", or "key_<something>")
##   - every key in the input map's actions
## and prints them sorted by key, marking any key held by more than one owner. Keys checked in code
## with a literal (real_character_4d's KEY_V, the controls card's + and -) are not seen; grep for those.
##
##   lab_run.sh headless keys res://ramon/chickenpen/scripts/_audit_pen_keys_runner.gd

var _t0: int = 0


func _initialize() -> void:
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 90000:
		print("KEYS: gave up")
		return true
	return false


func _run() -> void:
	var room: Node = (load("res://ramon/chickenpen/playable_world.tscn") as PackedScene).instantiate()
	root.add_child(room)
	current_scene = room
	for i in 60:
		await process_frame
	var owners: Dictionary = {}
	for node in room.find_children("*", "", true, false):
		for prop in node.get_property_list():
			var pname: String = prop["name"]
			if int(prop["type"]) != TYPE_INT or (int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
				continue
			if not (pname.ends_with("key") or pname.begins_with("key_") or pname.contains("_key_")):
				continue
			var code: int = int(node.get(pname))
			if code == 0:
				continue
			var enabled: bool = true
			for flag in ["debug_key_enabled", "enabled_key"]:
				if flag in node and not bool(node.get(flag)):
					enabled = false
			var who: String = "%s.%s%s" % [room.get_path_to(node), pname, "" if enabled else " (off)"]
			owners.get_or_add(code, []).append(who)
	for action in InputMap.get_actions():
		if String(action).begins_with("ui_"):
			continue
		for ev in InputMap.action_get_events(action):
			var k := ev as InputEventKey
			if k == null:
				continue
			var code: int = k.keycode if k.keycode != 0 else k.physical_keycode
			code |= k.get_modifiers_mask()
			owners.get_or_add(code, []).append("action " + String(action))
	var codes: Array = owners.keys()
	codes.sort()
	var clashes: int = 0
	for code in codes:
		var list: Array = owners[code]
		var live: Array = list.filter(func(s: String) -> bool: return not s.ends_with("(off)"))
		var mark: String = "  CLASH" if live.size() > 1 else ""
		if live.size() > 1:
			clashes += 1
		print("%-14s %s%s" % [OS.get_keycode_string(int(code)), ", ".join(PackedStringArray(list)), mark])
	print("KEYS: %d keys, %d clashes" % [codes.size(), clashes])
	quit(0)
