extends SceneTree

## The camp's "Align to slice" (PenLayout/PLAN_REF_LOCK.md step 48; Ramon, 6 Oct: "when you rotate it
## so that its 50% visible you can make a button appear that says, align to slice"). In the pen, 9 m
## from the camp at the farm's W: no button with the slice square (the camp is 2.5 kata, out of
## sight); the slice turned until it passes through the camp: the button comes up; V: you are brought
## to the camp's W, the slice square, the button gone. Frames in smoke_test_output/pen_layout/camp/.
##
##   lab_run.sh windowed camp_align res://ramon/chickenpen/scripts/_verify_camp_align_runner.gd

const SliceAngles := preload("res://ramon/chickenpen/scripts/slice_angles_4d.gd")
const PEN := "res://ramon/chickenpen/playable_world.tscn"
const OUT := "res://smoke_test_output/pen_layout/camp/"

var _pen: Node
var _fails: int = 0
var _t0: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_x: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 90000:
		print("CAMP ALIGN: gave up after 90 s")
		return true
	return false


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("  %s  %s  %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_fails += 1


func _wait(s: float) -> void:
	await create_timer(s).timeout


func _shot(name: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_pen = (load(PEN) as PackedScene).instantiate()
	for node in _pen.find_children("*", "", true, false):
		# The cave's trip stays live: its key sat on V with the align's (7 Oct), which is what to catch.
		if "debug_key_enabled" in node and node.name != "CaveCrossing":
			node.set("debug_key_enabled", false)
	root.add_child(_pen)
	current_scene = _pen
	await _wait(2.5)
	var camp := _pen.get_node_or_null("World/EggCamp") as Node4D
	_check("the camp is in the pen", camp != null and camp.has_method("can_align"))
	if camp == null:
		quit(1)
		return
	var player := _pen.get_node("Player") as CharacterBody4D
	var rig: Node4D = _pen.get_node("Player/CameraRig")
	player.set("input_enabled", true)
	player.global_position = Vector4(camp.global_position.x + 9.0, 1.0, camp.global_position.z + 1.0, 0.0)
	player.linear_velocity = Vector4.ZERO
	rig.call("face_toward", Vector4(-1.0, 0.0, -0.1, 0.0))
	await _wait(0.8)
	_check("square to the farm, no button", not bool(camp.call("can_align")), "slice w at the camp %.2f" % float(camp.call("slice_w_here")))
	await _shot("1_square")
	# Turn the slice a step at a time until it passes through the camp.
	var found: bool = false
	var yaw: float = SliceAngles.angles(rig.basis).z
	for k in 60:
		var a: float = deg_to_rad(1.0 * float(k + 1))
		for sgn in [-1.0, 1.0]:
			SliceAngles.tilt(rig, sgn * a, 0.0, yaw)
			await process_frame
			await process_frame
			if bool(camp.call("can_align")):
				found = true
				print("      turned %.0f degrees in xw, slice w at the camp %.2f" % [rad_to_deg(sgn * a), float(camp.call("slice_w_here"))])
				break
		if found:
			break
	_check("turned through the camp, the button comes up", found)
	await _wait(0.3)
	var shown: String = String(camp.get("_shown"))
	_check("it says Align to slice", shown.contains("Align to slice"), "\"%s\"" % shown)
	await _shot("2_button")
	var e := InputEventKey.new()
	e.keycode = KEY_V
	e.physical_keycode = KEY_V
	e.pressed = true
	Input.parse_input_event(e)
	await process_frame
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	await _wait(2.5)
	_check("V brought you to the camp's W", absf(player.global_position.w - camp.global_position.w) < 0.1, "w %.2f" % player.global_position.w)
	_check("the slice square again", bool(rig.call("is_aligned_to", camp.global_position.w)))
	_check("and the button gone", not bool(camp.call("can_align")) and String(camp.get("_shown")) == "")
	# Ramon, 7 Oct: "at the campsite when i say v to align slice, i get dropped in the cave interior"
	# (the cave's debug trip was on V too; it is F6 now).
	var cave: Node = _pen.get_node_or_null("CaveCrossing")
	_check("and you are still in the pen, not taken to the cave", cave == null or not bool(cave.call("is_away")))
	rig.call("face_toward", Vector4(-1.0, 0.0, -0.1, 0.0))
	await _wait(0.5)
	await _shot("3_aligned")
	print("CAMP ALIGN: %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(1 if _fails > 0 else 0)
