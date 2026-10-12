extends SceneTree

## Does Esc in the Aquatic Lab's sea come back to the menu, or quit the game?
##
##   godot --path project --rendering-method forward_plus --resolution 900x560 \
##       --script res://sandbox/_probe_menu_esc_runner.gd
##
## The lab's door swaps the lab for the seascape through change_scene_to_file, which frees
## the lab - so the menu is left holding a dead `_running`, and the guard that makes it claim
## Esc stopped being true. Esc then fell through to the sea's own camera rig, whose Esc frees
## the cursor once and QUITS on the second press.

const AQUATIC := 3
const SEA := "res://ramon/WaterLab/seascape/seascape.tscn"

var _f := 0
var _held := 0.0
var _menu: Node = null
var _asked := false
var _swapped := false
var _settle := 0.0


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


func _process(d: float) -> bool:
	_f += 1
	if _f == 1:
		_menu = (load("res://ramon/menu_final.tscn") as PackedScene).instantiate()
		root.add_child(_menu)
		current_scene = _menu
		return false
	_held += d
	if _held < 2.0:
		return false

	if not _asked:
		_asked = true
		_menu.call(&"_launch", AQUATIC)
		return false
	if bool(_menu.get(&"_launching")):
		return false

	if not _swapped:
		var running: Node = _menu.get(&"_running")
		if running == null:
			return false
		print("  launched. current scene is the %s"
				% ("LAB" if current_scene == running else "MENU"))
		print("  menu says a prototype is up: %s" % _menu.call(&"_prototype_up"))
		# The door.
		change_scene_to_file(SEA)
		_swapped = true
		return false

	_settle += d
	if _settle < 1.5:
		return false

	if not is_instance_valid(_menu):
		print("  FAIL - the menu itself was freed by the door")
		quit(1)
		return true
	var in_sea: bool = current_scene != null and current_scene != _menu
	print("  after the door: in the sea = %s" % in_sea)
	print("  menu still says a prototype is up: %s" % _menu.call(&"_prototype_up"))
	var ok: bool = bool(_menu.call(&"_prototype_up"))
	print("")
	print("  %s" % ("PASS - Esc will be claimed by the menu, not the sea's rig."
			if ok else "FAIL - the menu would let Esc fall through to the sea, which quits."))
	quit(0 if ok else 1)
	return true
