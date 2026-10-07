extends SceneTree

## THE RANGE'S WRAP, TO SEE (Ramon, 7 Oct: "can you show me the wrapped version of the range? open please"):
## the pen with you standing on the path about 19 m east of the range's yard, facing it, so turning the slice
## (hold the right mouse button and drag) shows the range staying where it is. Past 15 m from it you see its
## wrap copy; nearer, the range itself.
##   probe  three frames (flat, the slice turned 30 and 50 along the view) to smoke_test_output/wtools/range_show/
##          and quit, for checking the spot.
##   play   the pen left to you there (the default).
##
##   lab_run.sh windowed wt_range_probe res://ramon/WTools/tests/_show_range_runner.gd probe
##   godot --path project --script res://ramon/WTools/tests/_show_range_runner.gd        (to play)

const PEN := "res://ramon/chickenpen/playable_world.tscn"
const SliceAngles := preload("res://ramon/chickenpen/scripts/slice_angles_4d.gd")
const OUT := "res://smoke_test_output/wtools/range_show/"
const SPOT := Vector4(-8.0, 1.2, 2.5, 0.0)
## Facing west (-x), down the path to the range.
const YAW := 90.0


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var probe: bool = OS.get_cmdline_user_args().has("probe")
	if probe:
		root.unfocusable = true
	var room: Node = (load(PEN) as PackedScene).instantiate()
	root.add_child(room)
	current_scene = room
	await _frames(240)
	var player := room.get_node("Player") as CharacterBody4D
	var rig := player.get_node("CameraRig") as Node4D
	player.global_position = SPOT
	player.linear_velocity = Vector4.ZERO
	SliceAngles.tilt(rig, 0.0, 0.0, deg_to_rad(YAW))
	# The camera up over the meadow's grass, looking a little down at the range.
	rig.set("pitch", -0.22)
	if "distance" in rig:
		rig.set("distance", 9.0)
		rig.set("_zoom_target", 9.0)
	var look: Node = room.get_node_or_null("Systems/Look")
	if look != null and look.has_method("set_dev"):
		look.call("set_dev", false)
	if not probe:
		print("RANGE SHOW: you are 19 m east of the range, facing it. Hold the right mouse button and drag to turn the slice.")
		return
	player.set("input_enabled", false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var opt: Node = room.get_node("World/RangeW")
	for turn in [0.0, 30.0, 50.0]:
		# Facing -x, along the view is the xw plane.
		SliceAngles.tilt(rig, deg_to_rad(turn), 0.0, deg_to_rad(YAW))
		await _frames(30)
		var ui: Node = room.get_node_or_null("UI")
		if ui != null:
			for c in ui.get_children():
				if String(c.name) in ["GrassPanel", "PathsPanel"]:
					c.process_mode = Node.PROCESS_MODE_DISABLED
				if c is CanvasItem:
					(c as CanvasItem).visible = false
		for layer in room.find_children("*", "CanvasLayer", true, false):
			(layer as CanvasLayer).visible = false
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "turn_%02d.png" % int(turn)))
		print("RANGE SHOW turn %d: %s" % [int(turn), "copy" if int(opt.call("shown")) == 0 else "the range itself"])
	quit(0)
