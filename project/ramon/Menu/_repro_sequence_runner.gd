extends SceneTree

## Launches catalogue entries from menu_final one after another, the way a person does -
## launch, play a few seconds, Escape, next - to reproduce the crash that has hit the menus
## "about a minute in" since 29 Sept (hard crash, exit 139, no symbols in a release build).
##
## Arguments after `--`: entry indices in order, each optionally `index:target` for an
## extra launch button, and optionally `hold=<seconds>` for how long each one runs.
##
##   godot.windows.editor.double.x86_64.console.exe --path project --windowed
##       --resolution 1280x720 --position 40,40 --script res://ramon/Menu/_repro_sequence_runner.gd
##       -- 3 5 hold=6
##
## Prints a line per step, so the last line before a crash names the step that caused it.

const MENU := "res://ramon/menu_final.tscn"
const MAP := "res://ramon/FrontierMap.tscn"

var _menu: Node
var _plan: Array = []
var _hold: float = 6.0
## `guard`: when back at the menu, give the root a World3D if it has none - the stopgap
## being tested for the engine's cleanup leaving the root Window without one.
var _guard := false
## `map`: launch from the Frontier Map (through PrototypeLauncher) instead of menu_final.
var _map := false
var _step := 0
var _phase := 0
var _t := 0.0
var _f := 0


func _initialize() -> void:
	root.unfocusable = true
	for arg in OS.get_cmdline_user_args():
		var a := String(arg)
		if a.begins_with("hold="):
			_hold = float(a.substr(5))
		elif a == "guard":
			_guard = true
		elif a == "map":
			_map = true
		else:
			var parts := a.split(":")
			_plan.append([int(parts[0]), int(parts[1]) if parts.size() > 1 else 0])
	_menu = load(MAP if _map else MENU).instantiate()
	root.add_child(_menu)
	current_scene = _menu
	print("REPRO: plan %s, hold %.1f s, from %s" % [_plan, _hold, "the Frontier Map" if _map else "menu_final"])


func _running() -> Node:
	if _map:
		var launcher: Object = _menu.get("_launcher")
		return launcher.call("running_node") if launcher != null else null
	return _menu.get("_running")


func _process(d: float) -> bool:
	_f += 1
	_t += d
	if _f < 30:
		return false
	if _step >= _plan.size():
		if _t > 10.0:
			print("REPRO: SURVIVED all %d launches" % _plan.size())
			quit()
			return true
		return false
	var entry: Array = _plan[_step]
	match _phase:
		0:
			var title: String = String(_menu.get("catalogue").entries[entry[0]].title)
			print("REPRO: step %d launching %s (target %d) at frame %d" % [_step, title, entry[1], _f])
			if _map:
				_menu.call("_select", title)
				_menu.call("_on_launch_pressed")
			else:
				_menu.call("_select", entry[0])
				_menu.call("_on_launch_pressed", entry[1])
			_phase = 1; _t = 0.0
		1:
			if _running() != null:
				print("REPRO: step %d running %s" % [_step, _running().scene_file_path])
				_phase = 2; _t = 0.0
			elif _t > 30.0:
				print("REPRO: step %d never started" % _step)
				_phase = 3; _t = 0.0
		2:
			if _t > _hold:
				print("REPRO: step %d closing" % _step)
				if _map:
					_menu.get("_launcher").call("close")
				else:
					_menu.call("_close_running")
				_phase = 3; _t = 0.0
		3:
			if _t > 1.5:
				print("REPRO: step %d back at the menu, root world %s" % [_step, root.world_3d])
				if _guard and root.world_3d == null:
					root.world_3d = World3D.new()
					print("REPRO: guard gave the root a fresh World3D")
				_step += 1
				_phase = 0; _t = 0.0
	return false
