extends SceneTree

## ANDREW'S 4D, A/B (7 Oct; Ramon: "can we take andrew's grass coding and make the switch in our hud", and the same
## for his walking). The pen with the grass on:
##   - a picture of the grass as it is and of Andrew's 4D field (pen_grass_4d.gd andrew_4d), the slice level and
##     tilted TILT through W;
##   - the GPU time of each, in blocks of FRAMES alternating on, off, off, on (as _measure_grass_runner.gd), level
##     and tilted, the first SKIP frames of a block dropped (the switch rebuilds the bands);
##   - Andrew's two walking switches (block_walker_character_4d.gd andrew_turning, andrew_stepping), each way: a
##     second on the ana key with the slice tilted, where it took you (along the view's W or the world's) and which
##     way the avatar then faced.
##
##   lab_run.sh windowed andrew_ab res://ramon/chickenpen/grass/_andrew_ab_runner.gd

const OUT := "res://smoke_test_output/grass/andrew/"
const ORDER := [true, false, false, true]
const BLOCKS := 8
const FRAMES := 90
const SKIP := 20
## Radians; "tilt=" after "--" sets it, "only=pictures" stops after the pictures (player camera only).
var TILT: float = 0.7
var _only_pictures: bool = false
## "only=closeup": the blades at your feet, from beside the path (Ramon, 7 Oct, on Andrew's wider blades: "ok, show
## me"): his grass, Ramon's, and Andrew's at Ramon's width, then stop.
var _only_closeup: bool = false
## "only=time4k": the grass's GPU cost at Ramon's 3840 x 2160 in the art look (7 Oct, before the push: "measure and
## test"): no grass, the stacked grass and the 4D field in blocks off, stacked, field, field, stacked, off, level
## and tilted TILT; then stop.
var _only_time4k: bool = false

var _room: Node
var _grass: Node4D
var _player: Node4D
var _rig: Node4D


func _initialize() -> void:
	root.unfocusable = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	_room = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	_room.get_node("Systems/Lookout").set("journal_path", "user://lookout_journal_andrew_test.cfg")
	root.add_child(_room)
	current_scene = _room
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("tilt="):
			TILT = float(arg.substr(5))
		elif arg == "only=pictures":
			_only_pictures = true
		elif arg == "only=closeup":
			_only_closeup = true
		elif arg == "only=time4k":
			_only_time4k = true
			# Ramon's screen (7 Oct: "i play in 4k"), as _capture_feedback_runner.gd hud4k.
			DisplayServer.window_set_position(Vector2i(0, 0))
			DisplayServer.window_set_size(Vector2i(3840, 2160))
	_run.call_deferred()


func _wait(s: float) -> void:
	await create_timer(s).timeout


func _mean(a: Array) -> float:
	var s: float = 0.0
	for v in a:
		s += float(v)
	return s / maxf(float(a.size()), 1.0)


## The slice level (keeping the heading), or tilted TILT sideways through W; held there either way.
func _set_tilt(on: bool) -> void:
	_rig.set("_homing", 0.0)
	_rig.set("basis", GroundBasis4D.flattened(_rig.get("basis")))
	_rig.call("_apply")
	if on:
		_rig.call("drag_slice", Vector2(TILT, 0.0))


## Close up, no HUD, the slice level: a camera half a metre up, two metres to the side of the player (not in the
## avatar, whose cut was the green band across the first low pictures), looking down into the meadow, two ways.
func _closeups() -> void:
	root.canvas_cull_mask = 0
	var cam := Camera4D.new()
	cam.set("rendering_engine_name", "Cross-section")
	cam.set("field_of_view_4d", 1.0)
	_room.add_child(cam)
	cam.make_current()
	_set_tilt(false)
	var base_yaw: float = float(_rig.get("yaw"))
	var own_scale: float = float(_grass.get("blade_width_scale"))
	for v in 2:
		var yaw: float = base_yaw + (PI * 0.5 if v == 0 else PI)
		var side := Vector4(cos(base_yaw), 0.0, -sin(base_yaw), 0.0) * 2.0
		cam.global_position = _player.global_position + side + Vector4(0.0, 0.5, 0.0, 0.0)
		cam.global_basis = Basis4D.from_zx(yaw) * Basis4D.from_yz(-0.42)
		for kind in ["ramon", "andrew", "andrew_ramon_width"]:
			_grass.set("blade_width_scale", 1.0 if kind == "andrew_ramon_width" else own_scale)
			_grass.set("andrew_4d", kind != "ramon")
			_grass.call("_rebuild_bands")
			await _wait(1.5)
			await RenderingServer.frame_post_draw
			var file: String = "close%d_%s.png" % [v, kind]
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + file))
			print("ANDREW AB shot %s" % file)
	_grass.set("blade_width_scale", own_scale)
	_grass.set("andrew_4d", false)
	root.canvas_cull_mask = 0xFFFFFFFF


func _time4k() -> void:
	var look: Node = _room.get_node_or_null("Systems/Look")
	if look != null and look.has_method("set_dev"):
		look.call("set_dev", false)
	await _wait(2.0)
	var order: Array = ["off", "stacked", "field", "field", "stacked", "off"]
	for tilted in [false, true]:
		_set_tilt(tilted)
		var gpu: Dictionary = {"off": [], "stacked": [], "field": []}
		for round in 2:
			for state in order:
				_grass.set("enabled", state != "off")
				if state != "off":
					_grass.set("andrew_4d", state == "field")
				for f in FRAMES:
					await process_frame
					if f >= SKIP:
						(gpu[state] as Array).append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		print("ANDREW AB 4K %-7s window %s  GPU a frame: no grass %.2f ms, stacked grass %.2f ms (+%.2f), 4D field %.2f ms (+%.2f)" % [
			"tilted" if tilted else "level", str(root.size), _mean(gpu["off"]), _mean(gpu["stacked"]), _mean(gpu["stacked"]) - _mean(gpu["off"]),
			_mean(gpu["field"]), _mean(gpu["field"]) - _mean(gpu["off"])])
	_grass.set("andrew_4d", true)


func _run() -> void:
	_grass = _room.get_node("World/Grass")
	_player = _room.get_node("Player")
	_rig = _player.get_node("CameraRig")
	var started: int = Time.get_ticks_msec()
	while not bool(_grass.get("mask_ready")) or Time.get_ticks_msec() - started < 25000:
		if Time.get_ticks_msec() - started > 90000:
			print("ANDREW AB FAILED: no grass mask after 90 s")
			quit(1)
			return
		await _wait(0.5)
	_player.set("input_enabled", false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_grass.set("enabled", true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	if _only_time4k:
		await _time4k()
		print("ANDREW AB DONE")
		quit(0)
		return
	if _only_closeup:
		await _closeups()
		print("ANDREW AB DONE")
		quit(0)
		return

	# The pictures, the HUD hidden: the player's own camera, then a low one in the meadow beside the path.
	# (The HUD is 2D, the 4D picture 3D: no 2D drawn for the pictures.)
	root.canvas_cull_mask = 0
	for view in (["player"] if _only_pictures else ["player", "low"]):
		var cam: Camera4D = null
		if view == "low":
			cam = Camera4D.new()
			cam.set("rendering_engine_name", "Cross-section")
			cam.set("field_of_view_4d", 1.0)
			_room.add_child(cam)
			cam.make_current()
		for tilted in [false, true]:
			_set_tilt(tilted)
			if cam != null:
				var yaw: float = float(_rig.get("yaw")) + PI * 0.5
				cam.global_position = _player.global_position + Vector4(0.0, 1.1, 0.0, 0.0)
				cam.global_basis = Basis4D.from_zx(yaw) * Basis4D.from_xw(TILT if tilted else 0.0) * Basis4D.from_yz(-0.28)
			for andrew in [false, true]:
				_grass.set("andrew_4d", andrew)
				await _wait(1.5)
				await RenderingServer.frame_post_draw
				var file: String = "%s_%s_%s.png" % [view, "andrew" if andrew else "ramon", ("tilted%d" % roundi(rad_to_deg(TILT))) if tilted else "level"]
				root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + file))
				print("ANDREW AB shot %-26s blades %7d  per column %d" % [file, int(_grass.call("blade_count")), int(_grass.call("_layers_now"))])
		if cam != null:
			cam.queue_free()
			(_rig.get_node("Pitch/Camera4D") as Camera4D).make_current()
	root.canvas_cull_mask = 0xFFFFFFFF
	if _only_pictures:
		print("ANDREW AB DONE")
		quit(0)
		return

	# The timing.
	for tilted in [false, true]:
		_set_tilt(tilted)
		var on: Array = [[], [], []]
		var off: Array = [[], [], []]
		for block in BLOCKS:
			var andrew: bool = ORDER[block % 4]
			_grass.set("andrew_4d", andrew)
			for f in FRAMES:
				await process_frame
				if f < SKIP:
					continue
				var vp: RID = root.get_viewport_rid()
				var into: Array = on if andrew else off
				into[0].append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
				into[1].append(RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu())
				into[2].append(int(_grass.get("prerender_usec")))
		print("ANDREW AB time %-7s GPU Ramon's grass %.3f ms, Andrew's %.3f ms (%+.3f)   CPU %+.3f ms   grass script %d / %d us" % [
			"tilted" if tilted else "level", _mean(off[0]), _mean(on[0]), _mean(on[0]) - _mean(off[0]),
			_mean(on[1]) - _mean(off[1]), roundi(_mean(off[2])), roundi(_mean(on[2]))])
	_grass.set("andrew_4d", false)

	# The walking.
	_player.set("input_enabled", true)
	var avatar := _player.get_node("Avatar") as Node4D
	for mode in [[false, false], [true, false], [false, true], [true, true]]:
		_player.set("andrew_turning", mode[0])
		_player.set("andrew_stepping", mode[1])
		_set_tilt(true)
		await _wait(0.6)
		var from: Vector4 = _player.global_position
		var view_w: Vector4 = (_player.global_basis * (_rig.get("basis") as Projection).w).normalized()
		Input.action_press(&"move_ana")
		await _wait(1.0)
		Input.action_release(&"move_ana")
		await _wait(0.8)
		var moved: Vector4 = _player.global_position - from
		var flat := Vector4(moved.x, 0.0, moved.z, moved.w)
		var along_view: float = flat.normalized().dot(view_w) if flat.length() > 0.01 else 0.0
		var along_world: float = flat.normalized().w if flat.length() > 0.01 else 0.0
		var faces: Vector4 = avatar.global_basis.z
		print("ANDREW AB walk turning %-5s stepping %-5s moved %.2f m  along view W %.2f  along world W %.2f  avatar faces (x %.2f z %.2f w %.2f)" % [
			str(mode[0]), str(mode[1]), flat.length(), along_view, along_world, faces.x, faces.z, faces.w])
		_player.global_position = from
		_player.set("linear_velocity", Vector4.ZERO)
	_player.set("andrew_turning", false)
	_player.set("andrew_stepping", false)

	# THE HUD: the walking card under the grass panel, the panel open with its width slider, the grass on.
	var panel: Node = _room.get_node_or_null("UI/GrassPanel")
	if panel != null and bool(panel.get("_folded")):
		panel.call("_toggle_fold")
	await _wait(1.0)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "hud_card.png"))
	print("ANDREW AB shot hud_card.png")
	if panel != null:
		panel.call("_toggle_fold")

	# THE DEFAULTS AGAIN, after everything has been switched (7 Oct evening: the 4D field is the grass now; the walking
	# card's two choices start on the defaults): the stacked grass still comes back whole when asked for, the field is
	# the grass again after, the walk is the default walk with its heading kept, the width slider reaches the blades,
	# the card switches the player, and nothing of the switches is saved.
	_set_tilt(false)
	_player.set("andrew_turning", true)
	_player.set("andrew_stepping", true)
	_player.set("_facing", 1.0)
	_grass.set("andrew_4d", false)
	await _wait(1.0)
	var stacked: bool = _shader_is("res://ramon/chickenpen/grass/pen_grass.gdshader") and int(_grass.call("_layers_now")) == int(_grass.get("layers"))
	_grass.set("andrew_4d", true)
	_player.set("andrew_turning", false)
	_player.set("andrew_stepping", false)
	await _wait(1.0)
	var field: bool = _shader_is("res://ramon/chickenpen/grass/pen_grass_lattice.gdshader") and int(_grass.call("_layers_now")) == int(_grass.get("_lattice_layers"))
	var walk: bool = absf(float(_player.get("_facing")) - 1.0) < 0.01 and (avatar.basis.z - Basis4D.from_zx(1.0).z).length() < 0.01
	var keep: float = float(_grass.get("blade_width_scale"))
	_grass.set("blade_width_scale", 2.0)
	var band0: Object = (_grass.get("_bands") as Array)[0]
	var width: bool = absf(float((band0.get("material") as ShaderMaterial).get_shader_parameter("blade_width")) - float(_grass.get("blade_width")) * 2.0) < 1e-6
	_grass.set("blade_width_scale", keep)
	var card: Node = _room.get_node_or_null("UI/SteppingCard")
	var switched: bool = false
	if card != null:
		card.call("_pick", 0, true)
		card.call("_pick", 1, true)
		switched = bool(_player.get("andrew_stepping")) and bool(_player.get("andrew_turning"))
		card.call("_pick", 0, false)
		card.call("_pick", 1, false)
		switched = switched and not bool(_player.get("andrew_stepping")) and not bool(_player.get("andrew_turning"))
	var saved: Array = (_grass.get_script() as GDScript).get_script_constant_map()["SAVED_KEYS"]
	var unsaved: bool = not ("andrew_4d" in saved) and not ("andrew_turning" in saved) and not ("andrew_stepping" in saved)
	var back: bool = stacked and field and walk and width and switched and unsaved
	print("ANDREW AB defaults: %s (stacked grass whole %s, field the grass again %s, walk and heading back %s, width slider reaches the blades %s, card switches the player %s, switches never saved %s)" % [
		"YES" if back else "NO", str(stacked), str(field), str(walk), str(width), str(switched), str(unsaved)])
	print("ANDREW AB DONE")
	quit(0 if back else 1)


## Whether every band of the grass draws with [param path].
func _shader_is(path: String) -> bool:
	var bands: Array = _grass.get("_bands")
	var all: bool = not bands.is_empty()
	for band in bands:
		all = all and (band.get("material") as ShaderMaterial).shader == load(path)
	return all
