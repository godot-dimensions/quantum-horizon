extends SceneTree

## Watch the gauntlet be handed over: turning overhead, then on the arm and in the slot.

var _root: Node
var _f := 0
var _t0 := 0
var _award: Node
var _shots := 0
var _pending := ""


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _process(_d) -> bool:
	_f += 1
	if _f < 70: return false
	if _pending != "":
		root.get_texture().get_image().save_png("res://smoke_test_output/gaunt_%s.png" % _pending)
		print("SAVED gaunt_%s  (stage %s)" % [_pending, _award.get("stage")])
		_pending = ""
		return false
	if _award == null:
		_award = _root.get_node("Systems/GauntletAward")
		# Put the camera somewhere the reveal is visible, then fire the effect the
		# conversation would have fired.
		var rig: Node4D = _root.get_node("Player/CameraRig")
		rig.set("pitch", deg_to_rad(-18.0))
		rig.set("distance", 6.0)
		rig.set("_zoom_target", 6.0)
		rig.call("_apply")
		(_root.get_node("Systems/Talk") as Node).emit_signal("effect", "give_gauntlet")
		_t0 = Time.get_ticks_msec()
		return false

	var elapsed: float = float(Time.get_ticks_msec() - _t0) / 1000.0
	var at := [0.6, 1.8, 3.6, 4.6]
	if _shots < at.size() and elapsed >= at[_shots]:
		_pending = "%02d_%s" % [_shots, ["spin_a", "spin_b", "flying", "worn"][_shots]]
		_shots += 1
	return _shots >= at.size() and _pending == "" and elapsed > 5.0
