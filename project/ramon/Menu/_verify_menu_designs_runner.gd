extends SceneTree

## Every design of the 8 Oct design review launches and comes back: in each, 4D Ascent is
## selected, launched on top of the menu, and Escape unwinds it; the menu must be showing again
## and have moved on to the next prototype. Run in both groupings (the map's systems, then the
## RFP's questions). Saves one frame inside the prototype for the first design. "A" runs a
## second time in its route view, reached by pressing the ROUTE switch at its foot.
##
## Arguments after `--` narrow it: only=<n> (one design), from=<n> (that design on), group=<0|1>
## (one grouping); the whole run takes about twelve minutes.
##
##   godot.windows.editor.double.x86_64.console.exe --path project --windowed
##       --resolution 1280x720 --position 40,40 --script res://ramon/Menu/_verify_menu_designs_runner.gd

## Since 9 Oct the designs live only in the frozen reference menu (menu_final is A alone).
const MENU := "res://ramon/menu_variations.tscn"
const TARGET := "4D Ascent"

var _menu: Node
var _t := 0.0
var _f := 0
var _jobs: Array = []
var _job := 0
var _phase := 0
var _failed := 0


func _initialize() -> void:
	root.unfocusable = true
	_menu = load(MENU).instantiate()
	root.add_child(_menu)
	current_scene = _menu
	var only := -1
	var from := 0
	var groupings: Array = [0, 1]
	for argument in OS.get_cmdline_user_args():
		var pair: PackedStringArray = String(argument).split("=", true, 1)
		if pair.size() != 2:
			continue
		match pair[0]:
			"only":
				only = int(pair[1])
			"from":
				from = int(pair[1])
			"group":
				groupings = [int(pair[1])]
	var count: int = (_menu.get("DESIGN_NAMES") as PackedStringArray).size()
	var design_a: int = int(_menu.get("DESIGN_A"))
	for grouping in groupings:
		for d in range(from, count):
			if (only < 0 or d == only) and bool(_menu.call("_design_available", d)):
				_jobs.append([d, grouping, false])
		if only < 0 or only == design_a:
			_jobs.append([design_a, grouping, true])


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("  %s  %s  %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _index_of(title: String) -> int:
	var entries: Array = _menu.call("_entries")
	for i in entries.size():
		if String((entries[i] as Resource).get("title")) == title:
			return i
	return -1


func _title_selected() -> String:
	var entry: Resource = _menu.call("_selected_entry")
	return String(entry.get("title")) if entry != null else ""


## The first Button under `node` showing `text`.
func _button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node
	for child in node.get_children():
		var found := _button(child, text)
		if found != null:
			return found
	return null


func _escape() -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = KEY_ESCAPE
		e.physical_keycode = KEY_ESCAPE
		e.pressed = down
		Input.parse_input_event(e)


func _process(d: float) -> bool:
	_f += 1
	_t += d
	if _job >= _jobs.size():
		print("MENU DESIGNS VERIFY: %s" % ("ALL PASS" if _failed == 0 else "%d FAILED" % _failed))
		quit()
		return true
	var job: Array = _jobs[_job]
	var route: bool = bool(job[2])
	var name := "design %d%s (%s)" % [int(job[0]), " route" if route else "", "questions" if int(job[1]) == 1 else "systems"]
	match _phase:
		0:
			if _t > 0.6:
				_menu.set("_taxonomy", int(job[1]))
				_menu.set("design", int(job[0]))
				_menu.set("_played", [])
				_menu.set("_a_route", false)
				_menu.call("rebuild")
				if route:
					var toggle := _button(_menu, "ROUTE")
					_check("%s: the ROUTE switch is there" % name, toggle != null)
					if toggle != null:
						toggle.pressed.emit()
				_phase = 1
				_t = 0.0
		1:
			if _t > 0.4:
				if route:
					_check("%s: the switch shows the route" % name, bool(_menu.get("_a_route")) and not (_menu.get("_tracks") as Dictionary).is_empty())
				var i: int = _index_of(TARGET)
				_menu.call("_select", i)
				_check("%s: %s selected" % [name, TARGET], _title_selected() == TARGET, _title_selected())
				_menu.call("_on_launch_pressed", 0)
				_phase = 2
				_t = 0.0
		2:
			var running = _menu.get("_running")
			if running != null and _t > 1.5:
				_check("%s: it runs on top of the menu" % name, (running as Node).scene_file_path.ends_with("w_gap.tscn"))
				if _job == 0:
					root.get_texture().get_image().save_png("res://smoke_test_output/menu_review/designs/roundtrip_inside.png")
				_escape()
				_phase = 3
				_t = 0.0
			elif _t > 20.0:
				_check("%s: it runs on top of the menu" % name, false, "never started")
				_phase = 3
				_t = 0.0
		3:
			if _t > 0.8:
				_check("%s: Escape brings the menu back" % name, _menu.get("_running") == null and (_menu.get("_shell") as Control).visible)
				_check("%s: and it moved on" % name, _title_selected() != TARGET, _title_selected())
				if route:
					_menu.call("_toggle_a_route", false)
					root.remove_meta(&"menu_a_route")
				_job += 1
				_phase = 0
				_t = 0.0
	if _f > 60000:
		print("MENU DESIGNS VERIFY: TIMED OUT at job %d" % _job)
		quit()
		return true
	return false
