extends SceneTree

## THE WRAP STYLE DROPDOWN (Ramon, 7 Oct: "the dropdown would be good to have ... a small exclamation mark you
## can click ... ring not recommended because"): the optimiser lab with the Watchstone's Optimiser on Ring.
##   1. Ring builds its copies round the lab's middle and the node carries its warning (the editor's mark).
##   2. Turned along the view, one ring copy is drawn and the Watchstone itself hidden; in the volume view
##      every copy and the Watchstone.
##   3. Back to Stay put: one copy again, no warning, and it follows the slice as before.
##
##   lab_run.sh windowed wt_ringstyle res://ramon/WTools/tests/_verify_ring_style_runner.gd

var _fails: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _check(ok: bool, what: String, detail: String = "") -> void:
	print("  %s  %s  %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_fails += 1


func _engine(lab: Node, cam: Camera4D, name: String) -> void:
	var other := Camera4D.new()
	lab.add_child(other)
	other.make_current()
	cam.rendering_engine_name = name
	cam.make_current()
	other.queue_free()


func _run() -> void:
	var lab: Node = (load("res://ramon/WTools/tests/optimiser_lab.tscn") as PackedScene).instantiate()
	lab.set("readout", false)
	var opt: Node = lab.get_node("WatchstoneW")
	opt.set("wrap_style", 1)
	root.add_child(lab)
	var guard := Node.new()
	guard.set_script(load("res://ramon/PenLayout/scripts/input_guard.gd"))
	root.add_child(guard)
	await _frames(40)
	var player := lab.get("player") as CharacterBody4D
	player.set("input_enabled", false)
	var rig := lab.get("rig") as Node4D
	var cam := player.get_node("CameraRig/Pitch/Camera4D") as Camera4D
	# 1.
	var warnings: PackedStringArray = opt.call("_get_configuration_warnings")
	_check(bool(opt.get("applied")) and int(opt.get("wrap_copies")) > 2 and opt.get_node_or_null("WrapRing") != null,
		"Ring: copies round the lab's middle", "%d copies" % int(opt.get("wrap_copies")))
	_check(warnings.size() == 1 and warnings[0].begins_with("Ring is not recommended for landmarks yet"), "and the node carries the warning")
	print("  report: %s" % String(opt.get("report")).get_slice("\n", String(opt.get("report")).count("\n") - 2))
	# 2.
	rig.set("pitch", 0.06)
	rig.set("_slice_xw", 0.0)
	rig.set("_slice_zw", deg_to_rad(30.0))
	rig.set("yaw", 0.0)
	rig.call("_apply")
	await _frames(20)
	var land: Array = opt.get("_land_meshes")
	var land_hidden: bool = land.all(func(mi: Node) -> bool: return not (mi as Node4D).visible)
	var ring: Array = opt.get("_ring")
	var drawn: int = ring.filter(func(c: Node) -> bool: return (c as Node4D).visible).size()
	_check(int(opt.call("shown")) >= 0 and land_hidden and drawn == 1, "turned 30 along the view: one ring copy, the Watchstone hidden",
		"copy %d, %d drawn" % [int(opt.call("shown")), drawn])
	_engine(lab, cam, "Projected")
	await _frames(20)
	drawn = ring.filter(func(c: Node) -> bool: return (c as Node4D).visible).size()
	var land_shown: bool = land.all(func(mi: Node) -> bool: return (mi as Node4D).visible)
	_check(int(opt.call("shown")) == -2 and drawn == ring.size() and land_shown, "the volume view: every copy and the Watchstone", "%d of %d" % [drawn, ring.size()])
	_engine(lab, cam, "Cross-section")
	await _frames(5)
	# 3.
	opt.set("wrap_style", 0)
	opt.call("apply")
	await _frames(20)
	warnings = opt.call("_get_configuration_warnings")
	_check(int(opt.get("wrap_copies")) == 1 and opt.get_node_or_null("WrapCopy") != null and warnings.is_empty(), "back to Stay put: one copy, no warning")
	_check(int(opt.call("shown")) == 0, "and it follows the turned slice as before")
	print("RING STYLE: %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(1 if _fails > 0 else 0)
