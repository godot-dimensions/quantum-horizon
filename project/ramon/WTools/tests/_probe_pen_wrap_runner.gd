extends SceneTree

## THE WRAP IN THE PEN, NUMBER BY NUMBER: from a spot, the slice turned 0-60 degrees straight ahead as the
## capture runner turns it (SliceAngles.tilt), what the Watchstone's Optimiser sees and picks: the camera's
## W, the slice's normal, which is drawn, how far its middle is off the slice, and where the camera sees it
## against the flat view. For finding why a frame lost the Watchstone.
##
##   lab_run.sh windowed wt_probe_wrap res://ramon/WTools/tests/_probe_pen_wrap_runner.gd [x z yaw pitch distance]

const PEN := "res://ramon/chickenpen/playable_world.tscn"
const SliceAngles := preload("res://ramon/chickenpen/scripts/slice_angles_4d.gd")


func _initialize() -> void:
	root.unfocusable = true
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var at := Vector4(float(a[0]) if a.size() > 0 else 5.0, 1.2, float(a[1]) if a.size() > 1 else 10.0, 0.0)
	var yaw: float = float(a[2]) if a.size() > 2 else 74.0
	var pitch: float = float(a[3]) if a.size() > 3 else 4.0
	var dist: float = float(a[4]) if a.size() > 4 else 6.0
	var room: Node = (load(PEN) as PackedScene).instantiate()
	root.add_child(room)
	current_scene = room
	await _frames(240)
	var player := room.get_node("Player") as CharacterBody4D
	player.set("input_enabled", false)
	var rig := player.get_node("CameraRig") as Node4D
	var cam := player.get_node("CameraRig/Pitch/Camera4D") as Camera4D
	var opt: Node = room.get_node("World/WatchstoneW")
	var mid: Vector4 = opt.get("_land_mid")
	print("PROBE at %s yaw %.0f; Watchstone middle %s, arc %.0f, length %.0f, parts %.2f deep, near margin %.0f" % [str(at), yaw, str(mid),
		float(opt.get("wrap_arc")), float(opt.get("wrap_length")), float(opt.get("parts_w_half")), float(opt.get("near_margin"))])
	var flat_seen := Vector3.ZERO
	for turn in [0.0, 10.0, 20.0, 30.0, 40.0, 50.0, 60.0]:
		player.global_position = at
		player.linear_velocity = Vector4.ZERO
		rig.set("pitch", deg_to_rad(pitch))
		if "distance" in rig:
			rig.set("distance", dist)
		SliceAngles.tilt(rig, 0.0, deg_to_rad(turn), deg_to_rad(yaw))
		await _frames(6)
		var e: Vector4 = cam.global_position
		var b: Projection = cam.global_basis
		var shown: int = int(opt.call("shown"))
		var m: Vector4 = opt.call("copy_middle_now") if shown == 0 else mid
		var rel: Vector4 = m - e
		var seen := Vector3(rel.dot(Vector4(b.x).normalized()), rel.dot(Vector4(b.y).normalized()), rel.dot(Vector4(b.z).normalized()))
		if turn == 0.0:
			flat_seen = seen
		print("PROBE turn %2d: cam W %.2f, normal %s; %s, %.3f m off the slice, seen at %s (%.2f deg from the flat view)" % [int(turn), e.w,
			str(Vector4(b.w).normalized().snapped(Vector4.ONE * 0.01)), "copy" if shown == 0 else "itself", absf(rel.dot(Vector4(b.w).normalized())),
			str(seen.snapped(Vector3.ONE * 0.1)), rad_to_deg(seen.angle_to(flat_seen))])
	quit(0)
