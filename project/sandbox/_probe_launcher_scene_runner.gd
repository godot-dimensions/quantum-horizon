extends SceneTree

## Does a prototype with a door of its own survive being launched from the menu?
##
##   godot --path project --rendering-method forward_plus --resolution 640x400 \
##       --script res://sandbox/_probe_launcher_scene_runner.gd
##
## THE SOFT-LOCK. prototype_launcher.gd parents the prototype to the root and, until now,
## left `current_scene` pointing at the MENU. A prototype that opens a second room of its own
## calls change_scene_to_file, which frees the current scene - so the menu went, the lab kept
## running underneath, its door trigger fired again, and the Aquatic Lab bounced between the
## pier and a black loading screen.
##
## Checked on the launcher itself rather than by walking a player into a door: the launcher is
## the unit that changed, and a door is just one caller of change_scene_to_file. The Voxel
## Lab's open world and the Creature Lab's hall go the same way.

const Launcher := preload("res://ramon/Menu/scripts/prototype_launcher.gd")
const LAB := "res://ramon/WaterLab/water_lab.tscn"
const SEA := "res://ramon/WaterLab/seascape/seascape.tscn"

var _frames: int = 0
var _stage: int = 0
var _menu: Node = null
var _launcher: RefCounted = null
var _lab: Node = null
var _held: int = 0


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		# A stand-in for the menu: what matters is that it is the current scene when the
		# launcher runs, which is the state the real menu is in.
		_menu = Node.new()
		_menu.name = "PretendMenu"
		root.add_child(_menu)
		current_scene = _menu
		_launcher = Launcher.new(_menu)
		_launcher.call(&"launch", LAB)
		return false

	if _stage == 0:
		if _launcher.call(&"is_busy"):
			return false
		_lab = _launcher.call(&"running_node")
		if _lab == null:
			print("  FAIL - the lab did not launch")
			quit(1)
			return true
		var is_current: bool = current_scene == _lab
		print("  launched: current scene is the %s" % ("LAB" if is_current else "MENU"))
		if not is_current:
			print("  FAIL - the menu is still the current scene, so the lab's own door would")
			print("         free the menu instead of the lab")
			quit(1)
			return true
		# The door: exactly what water_lab_4d.gd:611 does.
		change_scene_to_file(SEA)
		_stage = 1
		return false

	_held += 1
	if _held < 60:
		return false

	var ok := true
	var lab_gone: bool = not is_instance_valid(_lab)
	var menu_alive: bool = is_instance_valid(_menu)
	print("  after the door: lab freed = %s, menu still alive = %s" % [lab_gone, menu_alive])
	print("  current scene is now: %s" % (current_scene.scene_file_path if current_scene != null else "<none>"))
	if not lab_gone:
		print("  FAIL - the lab is still running under the sea; its door will fire again")
		ok = false
	if not menu_alive:
		print("  FAIL - the menu was freed, so there is nothing to come back to")
		ok = false
	if current_scene == null or not String(current_scene.scene_file_path).ends_with("seascape.tscn"):
		print("  FAIL - the sea did not become the current scene")
		ok = false
	print("")
	print("  %s" % ("PASS - the door swaps the lab for the sea and leaves the menu alone." if ok else "see above."))
	quit(0 if ok else 1)
	return true
