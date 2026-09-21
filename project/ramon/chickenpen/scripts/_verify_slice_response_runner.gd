extends SceneTree

## Does the locator - words and dial alike - respond to slice rotation, the way the
## Gallery's radar does?
##
## Slice-rotating changes which 3-slice you can see, so every reading about "is this on my
## slice" must move with it. It did not: the rig carried the rotation and both readouts
## read the body.

var _root: Node
var _f := 0
var _rig: Node4D
var _loc: Node
var _radar: Control
var _step := 0


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root


func _process(_d) -> bool:
	_f += 1
	if _f < 60:
		return false
	if _rig == null:
		_rig = _root.get_node("Player/CameraRig")
		_loc = _root.get_node("Systems/Locator")
		_radar = _root.get_node("UI/Radar")
		print("rotating the slice through xw, and watching what moves:")
		print("   %-9s %-9s %-10s %s" % ["xw", "ana", "angle", "readout"])
	if _f % 15 != 0:
		return false

	var xw: float = float(_step) * 0.15
	_rig.set("_slice_xw", xw)
	_rig.call("_apply")
	var target: Node = _loc.get("target")
	if target == null:
		return false
	var body: Node4D = target.get_parent() as Node4D
	var bearing: Dictionary = BearingUtility4D.compute_raw(
		(_root.get_node("Player") as Node4D).global_position,
		_loc.call("_slice_basis"), body.global_position)
	print("   %-9.2f %-9.3f %-10.3f %s" % [
		xw, bearing["ana_offset"], bearing["angle_off_slice"],
		(_root.get_node("UI/Locator") as Label).text.substr(9)])
	_step += 1
	return _step > 6
