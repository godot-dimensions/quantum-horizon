extends SceneTree

## Pen layout (6 Oct 2026): frames of the pen to judge a layout by eye. Two kinds of shot:
##   top  an orthographic camera straight down over a point, [size] metres across, at a slice W:
##        the map view, north (-z) up
##   eye  the player put somewhere, facing a heading, seen through their own camera: what you see
##        walking there
## Any shot can ask for a renderer ("Cross-section", "Combined", "Projected"). The HUD is hidden
## unless the shot says "hud". The player's input is off and the window never takes focus, so
## nothing typed or moved elsewhere gets into the frames (feedback_test_windows_steal_focus).
##
## Frames go to res://smoke_test_output/pen_layout/<set>/<shot>.png.
##
##   CreationLab/scripts/lab_run.sh windowed pl_cap res://ramon/PenLayout/scripts/_capture_pen_runner.gd <set> [scene]

const OUT := "res://smoke_test_output/pen_layout/"
const LabGrid := preload("res://ramon/CreationLab/LabKit/lab_grid.gd")
## PathCreator's lab floor (pathcreator_4d.gd FLOOR), and its grid's two line colours.
const DEV_FLOOR := Color(0.96, 0.965, 0.97)
## A shot: "top" (centre) or "at" (where the player stands) with "yaw" (degrees, 0 looks north),
## and optionally "pitch" (degrees), "distance" (the orbit camera's), "w" (the slice), "size"
## (top: metres across), "engine", "hud"; "paths" (properties set on World/Paths first: reveal,
## show_marks, show_sand), "forget" (reveal forgets what it found first) and "walk" (points the
## player is walked through at a run before the shot, so reveal finds what is near them); "set"
## (node path -> {property: value}, set before the shot: a tower's fence frame on, say);
## "devfloor" (from that shot on, the ground is PathCreator's white lab floor and the paths' floor
## colour matches it: the look of a dev version of the pen, Ramon 6 Oct).
const SETS := {
	"before": [
		{"name": "top", "top": Vector4(0, 0, -2, 0), "size": 108.0},
		{"name": "top_combined", "top": Vector4(0, 0, -2, 0), "size": 108.0, "engine": "Combined"},
		{"name": "start", "at": Vector4(4.6, 1.2, -2.0, 0), "yaw": 27.1, "pitch": -15.0, "distance": 8.0},
		{"name": "start_combined", "at": Vector4(4.6, 1.2, -2.0, 0), "yaw": 27.1, "pitch": -15.0, "distance": 8.0, "engine": "Combined"},
		{"name": "from_south", "at": Vector4(4.0, 1.2, 38.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 6.0},
		{"name": "from_shoulder", "at": Vector4(-11.0, 1.2, 9.0, 0), "yaw": 20.0, "pitch": -8.0, "distance": 6.0},
	],
	"paths": [
		{"name": "top", "top": Vector4(-2, 0, 8, 0), "size": 92.0, "paths": {"reveal": false, "show_marks": false, "show_sand": true, "look": "walk"}},
		{"name": "start", "at": Vector4(4.0, 1.2, 38.0, 0), "yaw": 0.0, "pitch": -14.0, "distance": 7.0},
		{"name": "start_west", "at": Vector4(-3.0, 1.2, 33.0, 0), "yaw": 30.0, "pitch": -16.0, "distance": 7.0},
		{"name": "wall_w0", "at": Vector4(-10.5, 1.2, 21.0, 0), "yaw": 0.0, "pitch": -18.0, "distance": 6.0},
		{"name": "wall_w15", "at": Vector4(-10.5, 1.2, 21.0, 1.5), "yaw": 0.0, "pitch": -18.0, "distance": 6.0},
		{"name": "wall_combined", "at": Vector4(-10.5, 1.2, 21.0, 0), "yaw": 0.0, "pitch": -18.0, "distance": 6.0, "engine": "Combined"},
		{"name": "door_w0", "at": Vector4(6.0, 1.2, 34.0, 0), "yaw": 10.0, "pitch": -14.0, "distance": 6.0},
		{"name": "door_w4", "at": Vector4(6.0, 1.2, 34.0, 4.0), "yaw": 10.0, "pitch": -14.0, "distance": 6.0},
		{"name": "meadow_ring", "at": Vector4(24.0, 1.2, 8.0, 0), "yaw": -20.0, "pitch": -24.0, "distance": 9.0},
		{"name": "egg1_kata", "at": Vector4(20.0, 1.2, 5.5, -2.5), "yaw": 0.0, "pitch": -18.0, "distance": 6.0},
		{"name": "egg2_ana", "at": Vector4(27.0, 1.2, 17.0, 7.0), "yaw": -30.0, "pitch": -16.0, "distance": 6.0},
		{"name": "gate", "at": Vector4(6.0, 1.2, 2.0, 0), "yaw": 10.0, "pitch": -18.0, "distance": 8.0},
		{"name": "icons_only", "at": Vector4(-3.0, 1.2, 33.0, 0), "yaw": 30.0, "pitch": -16.0, "distance": 7.0, "paths": {"show_marks": true, "show_sand": false, "look": "dev"}},
		{"name": "sand_only", "at": Vector4(-3.0, 1.2, 33.0, 0), "yaw": 30.0, "pitch": -16.0, "distance": 7.0, "paths": {"show_marks": false, "show_sand": true, "look": "walk"}},
		{"name": "reveal_start", "at": Vector4(4.0, 1.2, 38.0, 0), "yaw": 0.0, "pitch": -14.0, "distance": 7.0,
			"paths": {"show_marks": false, "show_sand": true, "reveal": true, "look": "walk"}, "forget": true},
		{"name": "reveal_walked", "at": Vector4(-10.0, 1.2, 23.0, 0), "yaw": 180.0, "pitch": -20.0, "distance": 9.0,
			"walk": [Vector4(4.0, 1.2, 37.0, 0), Vector4(-5.0, 1.2, 31.0, 0), Vector4(-10.0, 1.2, 23.0, 0)]},
		{"name": "reveal_top", "top": Vector4(-2, 0, 8, 0), "size": 92.0},
	],
	"devfloor": [
		{"name": "start_icons", "at": Vector4(4.0, 1.2, 38.0, 0), "yaw": 0.0, "pitch": -14.0, "distance": 7.0, "devfloor": true,
			"paths": {"reveal": false, "show_marks": true, "show_sand": false, "look": "dev"}},
		{"name": "west_icons", "at": Vector4(-3.0, 1.2, 33.0, 0), "yaw": 30.0, "pitch": -16.0, "distance": 7.0},
		{"name": "wall_icons", "at": Vector4(-10.5, 1.2, 21.0, 0), "yaw": 0.0, "pitch": -18.0, "distance": 6.0},
		{"name": "gate_icons", "at": Vector4(6.0, 1.2, 2.0, 0), "yaw": 10.0, "pitch": -18.0, "distance": 8.0},
		{"name": "close_icons", "at": Vector4(-6.0, 1.2, 30.5, 0), "yaw": 60.0, "pitch": -40.0, "distance": 4.0},
		{"name": "top_icons", "top": Vector4(-2, 0, 8, 0), "size": 92.0},
		{"name": "west_sand", "at": Vector4(-3.0, 1.2, 33.0, 0), "yaw": 30.0, "pitch": -16.0, "distance": 7.0,
			"paths": {"show_sand": true, "show_marks": false, "look": "walk"}},
	],
	"tower": [
		{"name": "classic_w0", "at": Vector4(-7.0, 1.2, -23.0, 0), "yaw": 34.0, "pitch": 9.0, "distance": 7.0},
		{"name": "classic_w2", "at": Vector4(-7.0, 1.2, -23.0, 2.0), "yaw": 34.0, "pitch": 9.0, "distance": 7.0},
		{"name": "classic_combined", "at": Vector4(-7.0, 1.2, -23.0, 0), "yaw": 34.0, "pitch": 9.0, "distance": 7.0, "engine": "Combined"},
		{"name": "fence_w0", "at": Vector4(-7.0, 1.2, -23.0, 0), "yaw": 34.0, "pitch": 9.0, "distance": 7.0,
			"set": {"World/LookoutSite/Lookout": {"fence_frame": true}}},
		{"name": "fence_w1", "at": Vector4(-7.0, 1.2, -23.0, 1.0), "yaw": 34.0, "pitch": 9.0, "distance": 7.0},
		{"name": "fence_w2", "at": Vector4(-7.0, 1.2, -23.0, 2.0), "yaw": 34.0, "pitch": 9.0, "distance": 7.0},
		{"name": "fence_w3", "at": Vector4(-7.0, 1.2, -23.0, 3.1), "yaw": 34.0, "pitch": 9.0, "distance": 7.0},
		{"name": "fence_combined", "at": Vector4(-7.0, 1.2, -23.0, 0), "yaw": 34.0, "pitch": 9.0, "distance": 7.0, "engine": "Combined"},
		{"name": "fence_projected", "at": Vector4(-7.0, 1.2, -23.0, 0), "yaw": 34.0, "pitch": 9.0, "distance": 7.0, "engine": "Projected"},
	],
	"hut": [
		{"name": "shed_classic_w0", "at": Vector4(-3.0, 1.2, 33.0, 0), "yaw": 124.0, "pitch": -6.0, "distance": 6.0},
		{"name": "shed_classic_w1", "at": Vector4(-3.0, 1.2, 33.0, 1.0), "yaw": 124.0, "pitch": -6.0, "distance": 6.0},
		{"name": "shed_fence_w0", "at": Vector4(-3.0, 1.2, 33.0, 0), "yaw": 124.0, "pitch": -6.0, "distance": 6.0,
			"set": {"World/TrymCabin/Shed": {"fence_frame": true}}},
		{"name": "shed_fence_w1", "at": Vector4(-3.0, 1.2, 33.0, 1.0), "yaw": 124.0, "pitch": -6.0, "distance": 6.0},
		{"name": "shed_fence_combined", "at": Vector4(-3.0, 1.2, 33.0, 0), "yaw": 124.0, "pitch": -6.0, "distance": 6.0, "engine": "Combined"},
		{"name": "booth_classic_w0", "at": Vector4(-12.0, 1.2, -4.0, 0), "yaw": 54.0, "pitch": -6.0, "distance": 6.0},
		{"name": "booth_classic_w1", "at": Vector4(-12.0, 1.2, -4.0, 1.0), "yaw": 54.0, "pitch": -6.0, "distance": 6.0},
		{"name": "booth_fence_w0", "at": Vector4(-12.0, 1.2, -4.0, 0), "yaw": 54.0, "pitch": -6.0, "distance": 6.0,
			"set": {"World/Range/RangeBooth": {"fence_posts": true}}},
		{"name": "booth_fence_w1", "at": Vector4(-12.0, 1.2, -4.0, 1.0), "yaw": 54.0, "pitch": -6.0, "distance": 6.0},
		{"name": "booth_fence_combined", "at": Vector4(-12.0, 1.2, -4.0, 0), "yaw": 54.0, "pitch": -6.0, "distance": 6.0, "engine": "Combined"},
	],
	"a": [
		{"name": "top", "top": Vector4(0, 0, -2, 0), "size": 108.0},
		{"name": "top_w4", "top": Vector4(0, 0, -2, 4.0), "size": 108.0},
		{"name": "top_combined", "top": Vector4(0, 0, -2, 0), "size": 108.0, "engine": "Combined"},
		{"name": "wake", "at": Vector4(4.0, 1.2, 38.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 6.0},
		{"name": "wake_combined", "at": Vector4(4.0, 1.2, 38.0, 0), "yaw": 0.0, "pitch": -6.0, "distance": 6.0, "engine": "Combined"},
		{"name": "arch_w0", "at": Vector4(6.5, 1.2, 33.0, 0), "yaw": 0.0, "pitch": -4.0, "distance": 5.0},
		{"name": "arch_w4", "at": Vector4(6.5, 1.2, 33.0, 4.0), "yaw": 0.0, "pitch": -4.0, "distance": 5.0},
		{"name": "west_path", "at": Vector4(-8.0, 1.2, 28.0, 0), "yaw": 10.0, "pitch": -8.0, "distance": 6.0},
		{"name": "shoulder", "at": Vector4(-11.0, 1.2, 9.0, 0), "yaw": 20.0, "pitch": -8.0, "distance": 6.0},
		{"name": "pen_from_gate", "at": Vector4(4.6, 1.2, -2.0, 0), "yaw": 27.1, "pitch": -15.0, "distance": 8.0},
		{"name": "east_meadow", "at": Vector4(24.0, 1.2, 10.0, 0), "yaw": -40.0, "pitch": -8.0, "distance": 6.0},
	],
}

var _room: Node


func _initialize() -> void:
	root.unfocusable = true
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var set_name: String = args[0] if args.size() > 0 else "before"
	var scene: String = args[1] if args.size() > 1 else "res://ramon/chickenpen/playable_world.tscn"
	var shots: Array = SETS[set_name]
	var dir: String = OUT + set_name + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_room = (load(scene) as PackedScene).instantiate()
	root.add_child(_room)
	current_scene = _room
	await _frames(60)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var player := _room.get_node("Player") as Node4D
	player.set("input_enabled", false)
	var rig: Node4D = player.get_node("CameraRig") as Node4D
	var player_cam: Camera4D = player.get_node("CameraRig/Pitch/Camera4D") as Camera4D
	var lookout: Node = _room.get_node_or_null("Systems/Lookout")
	var top_cam := Camera4D.new()
	top_cam.name = "CaptureTop"
	top_cam.projection_type = Camera4D.PROJECTION4D_ORTHOGRAPHIC
	top_cam.clip_far = 400.0
	_room.add_child(top_cam)
	for shot: Dictionary in shots:
		var engine: String = shot.get("engine", "Cross-section")
		_hud(bool(shot.get("hud", false)))
		# The Lookout puts whichever camera is current on Combined or Cross-section every frame
		# (its P toggle); for Projected it is paused for the shot.
		if lookout != null:
			lookout.process_mode = Node.PROCESS_MODE_DISABLED if engine == "Projected" else Node.PROCESS_MODE_INHERIT
			if engine != "Projected" and lookout.has_method("set_projection"):
				lookout.call("set_projection", engine == "Combined")
		var net: Node = _room.get_node_or_null("World/Paths")
		if bool(shot.get("devfloor", false)):
			var ground := _room.get_node_or_null("World/Ground/GroundMesh") as MeshInstance4D
			if ground != null:
				LabGrid.set_swatch("pen_dev_floor", DEV_FLOOR, Color(0.86, 0.87, 0.89), Color(0.92, 0.925, 0.93), 1.0)
				var size: Vector4 = (ground.mesh as BoxTetraMesh4D).size if ground.mesh is BoxTetraMesh4D else Vector4(120, 2, 120, 120)
				ground.material_override = LabGrid.material("pen_dev_floor", size, ground.global_position)
			if net != null:
				net.set("under_color", DEV_FLOOR)
		if net != null:
			var props: Dictionary = shot.get("paths", {})
			for key in props:
				net.set(key, props[key])
			if bool(shot.get("forget", false)) and net.has_method("reset_reveal"):
				net.call("reset_reveal")
		var sets: Dictionary = shot.get("set", {})
		for path in sets:
			var target: Node = _room.get_node_or_null(NodePath(path))
			if target != null:
				for key in sets[path]:
					target.set(key, sets[path][key])
		for p: Vector4 in shot.get("walk", []):
			await _walk_to(player, p)
		if shot.has("top"):
			var c: Vector4 = shot["top"]
			top_cam.orthographic_size = float(shot.get("size", 100.0))
			top_cam.position = Vector4(c.x, 120.0, c.z, float(shot.get("w", c.w)))
			top_cam.look_at(Vector4(c.x, 0.0, c.z, float(shot.get("w", c.w))), Vector4(0, 0, -1, 0))
			# A camera's renderer only changes while it is not current.
			player_cam.make_current()
			await _frames(2)
			top_cam.rendering_engine_name = engine
			top_cam.make_current()
		else:
			var at: Vector4 = shot["at"]
			player.global_position = at
			if player is CharacterBody4D:
				(player as CharacterBody4D).linear_velocity = Vector4.ZERO
			rig.set("yaw", deg_to_rad(float(shot.get("yaw", 0.0))))
			rig.set("pitch", deg_to_rad(float(shot.get("pitch", -10.0))))
			if shot.has("distance"):
				rig.set("distance", float(shot["distance"]))
			if rig.has_method("_apply"):
				rig.call("_apply")
			top_cam.make_current()
			await _frames(2)
			player_cam.rendering_engine_name = engine
			player_cam.make_current()
		# Long enough for the player to settle on the ground and the rig to catch up.
		await _frames(38)
		var path: String = dir + String(shot["name"]) + ".png"
		root.get_texture().get_image().save_png(path)
		print("FRAME %s" % path)
	print("CAPTURE DONE %s: %d frames" % [set_name, shots.size()])
	quit(0)


## The player run to [param p] at 3 m/s, a frame at a time (reveal finds by nearness each frame).
func _walk_to(player: Node4D, p: Vector4) -> void:
	var from: Vector4 = player.global_position
	var steps: int = maxi(1, int(from.distance_to(p) / 3.0 * 60.0))
	for i in steps:
		player.global_position = from.lerp(p, float(i + 1) / float(steps))
		await process_frame


func _hud(on: bool) -> void:
	var ui: Node = _room.get_node_or_null("UI")
	if ui == null:
		return
	for c in ui.get_children():
		if c is CanvasItem:
			(c as CanvasItem).visible = on
		elif c is CanvasLayer:
			(c as CanvasLayer).visible = on
