extends SceneTree

## The oval and the slider are off, and stay off.
##
## Worth checking rather than assuming: the talk system un-hides every node in its
## locator_ui_paths when the locator unlocks, so a node hidden in the scene can come
## straight back a second later. The radar was in that list.
##
## They are hidden, not deleted - the nodes and their scripts are still in the scene, so
## ticking Visible in the editor brings either one back, and M still brings the radar
## back at runtime.

var _root: Node
var _f := 0
var _fails: Array = []


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _check(label: String, ok: bool, detail: String) -> void:
	print("   %s %-38s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fails.append(label)


func _process(_d) -> bool:
	_f += 1
	# Long enough for the talk system's own _ready and its first pass to have run.
	if _f < 120: return false
	var radar: Control = _root.get_node("UI/Radar")
	var gizmo: Control = _root.get_node("UI/SliceGizmo")
	var plane: Control = _root.get_node("UI/SlicePlane")

	print("\n--- two seconds in ---")
	_check("the oval is off", not radar.visible, "Radar.visible = %s" % radar.visible)
	_check("the slider is off", not gizmo.visible, "SliceGizmo.visible = %s" % gizmo.visible)
	_check("the level is still on", plane.visible, "SlicePlane.visible = %s" % plane.visible)
	_check("but both are still in the scene",
		radar.get_script() != null and gizmo.get_script() != null,
		"scripts still attached, so ticking Visible brings them back")

	# And the radar's own key still reaches it while it is hidden - a hidden Control still
	# gets _unhandled_input, which is what makes M a working recall rather than a dead key.
	var key := InputEventKey.new()
	key.keycode = KEY_M
	key.pressed = true
	radar.call("_unhandled_input", key)
	_check("M brings the oval back", radar.visible, "Radar.visible = %s" % radar.visible)

	print("\n%d FAIL(s)" % _fails.size())
	quit(1 if _fails.size() > 0 else 0)
	return true
