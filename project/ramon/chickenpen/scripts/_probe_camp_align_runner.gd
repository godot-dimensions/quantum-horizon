extends SceneTree

## Probe (6 Oct; Ramon: "when i press v to align to slice the whole scene breaks in to black"): from
## several spots round the camp, turn the slice until the camp's button comes up, press V, and log the
## player's position and the frame a second and three seconds later.
##
##   lab_run.sh windowed probe_camp res://ramon/chickenpen/scripts/_probe_camp_align_runner.gd

const SliceAngles := preload("res://ramon/chickenpen/scripts/slice_angles_4d.gd")
const OUT := "res://smoke_test_output/pen_layout/camp_probe/"

var _pen: Node
var _t0: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_x: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 170000:
		print("PROBE: gave up")
		return true
	return false


func _wait(s: float) -> void:
	await create_timer(s).timeout


func _shot(name: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _key(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		Input.parse_input_event(e)
		await process_frame


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_pen = (load("res://ramon/chickenpen/playable_world.tscn") as PackedScene).instantiate()
	for node in _pen.find_children("*", "", true, false):
		if "debug_key_enabled" in node:
			node.set("debug_key_enabled", false)
	root.add_child(_pen)
	current_scene = _pen
	await _wait(2.5)
	var camp := _pen.get_node("World/EggCamp") as Node4D
	var player := _pen.get_node("Player") as CharacterBody4D
	var rig: Node4D = _pen.get_node("Player/CameraRig")
	var c: Vector4 = camp.global_position
	var spots: Array = [["east9", Vector2(9, 1)], ["at_fire", Vector2(1.5, 2.5)], ["west12", Vector2(-12, 0)], ["north15", Vector2(0, -15)],
		["south18", Vector2(0, 18)], ["southwest20", Vector2(-14, 14)]]
	if "proj" in OS.get_cmdline_user_args():
		# With the projection on (P), as Ramon may have had it.
		_pen.get_node("Systems/Lookout").call("set_projection", true)
		spots = [["proj_east9", Vector2(9, 1)], ["proj_at_fire", Vector2(1.5, 2.5)]]
	if "both" in OS.get_cmdline_user_args():
		spots = [["both_east9", Vector2(9, 1)]]
	for spot in spots:
		var name: String = spot[0]
		var off: Vector2 = spot[1]
		player.global_position = Vector4(c.x + off.x, 1.2, c.z + off.y, 0.0)
		player.linear_velocity = Vector4.ZERO
		SliceAngles.tilt(rig, 0.0, 0.0)
		var to_camp := Vector4(-off.x, 0, -off.y, 0)
		if to_camp.length() > 0.1:
			rig.call("face_toward", to_camp)
		await _wait(0.8)
		var yaw: float = SliceAngles.angles(rig.basis).z
		var found: bool = false
		for k in 70:
			var a: float = deg_to_rad(1.0 * float(k + 1))
			for plane in ["xw", "zw"]:
				for sgn in [-1.0, 1.0]:
					if "both" in OS.get_cmdline_user_args():
						SliceAngles.tilt(rig, sgn * a, sgn * a * 0.7, yaw)
					elif plane == "xw":
						SliceAngles.tilt(rig, sgn * a, 0.0, yaw)
					else:
						SliceAngles.tilt(rig, 0.0, sgn * a, yaw)
					await process_frame
					if bool(camp.call("can_align")):
						found = true
						print("PROBE %s: button at %s %+.0f deg" % [name, plane, rad_to_deg(sgn * a)])
						break
				if found:
					break
			if found:
				break
		if not found:
			print("PROBE %s: no button" % name)
			continue
		await _shot("%s_0_before" % name)
		await _key(KEY_V)
		await _wait(1.0)
		print("PROBE %s: 1 s after V  pos %s  aligned %s  input %s" % [name, str(player.global_position), str(rig.call("is_aligned_to", c.w)), str(player.get("input_enabled"))])
		await _shot("%s_1_after1s" % name)
		await _wait(2.0)
		print("PROBE %s: 3 s after V  pos %s  world visible %s  camera %s" % [name, str(player.global_position), str((_pen.get_node("World") as Node4D).is_visible_in_tree()),
			str(get_root().get_viewport().get_camera_4d().get_path() if get_root().get_viewport().has_method("get_camera_4d") and get_root().get_viewport().get_camera_4d() != null else "?")])
		await _shot("%s_2_after3s" % name)
		# Back to the farm's W for the next.
		rig.call("align_to", 0.0)
		await _wait(2.0)
	print("PROBE DONE")
	quit(0)
