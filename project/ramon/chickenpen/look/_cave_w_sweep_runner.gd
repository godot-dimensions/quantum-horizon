extends SceneTree

## THE CAVE'S OPENING, W BY W (Ramon, 7 Oct: "this is still not the most aestetically pleasing opening. you can look
## at the backup pen file and see how the cave looks at default there. and use that W measure for this one"). The
## pen's cave hill seen from the end of its road, straight on, with each of its meshes: the one the pen had before the
## units (terrain/baked/cave_hill.res, the backup pens' "default"), the one it has now (cave_hill_even.res), and the
## dev look's coarse one (cave_hill_low.res), the slice at the door's W and either side of it. One frame each, to
## res://smoke_test_output/cave_w/<mesh>_<w>.png, for a contact sheet.
##
##   lab_run.sh windowed cave_w res://ramon/chickenpen/look/_cave_w_sweep_runner.gd look=art

const OUT := "res://smoke_test_output/cave_w/"
const MESHES := {"old": "res://ramon/chickenpen/terrain/baked/cave_hill.res", "even": "res://ramon/chickenpen/terrain/baked/cave_hill_even.res",
	"low": "res://ramon/chickenpen/terrain/baked/cave_hill_low.res"}
const OFFSETS := [-2.0, -1.5, -1.0, -0.5, 0.0, 0.5, 1.0, 1.5, 2.0]

var _room: Node
var _t0: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_room = (load("res://ramon/chickenpen/playable_world.tscn") as PackedScene).instantiate()
	_room.get_node("Systems/Lookout").set("journal_path", "user://cave_w_journal.cfg")
	root.add_child(_room)
	current_scene = _room
	_run.call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 170000:
		print("CAVE W: gave up after 170 s")
		return true
	return false


func _wait(s: float) -> void:
	await create_timer(s).timeout


func _run() -> void:
	await _wait(6.0)
	(_room.get_node("Player") as Node).set("input_enabled", false)
	for c in _room.get_node("UI").get_children():
		if c is CanvasItem:
			(c as CanvasItem).visible = false
	var hill := _room.get_node("World/Cave/CaveHill") as MeshInstance4D
	var cave := _room.get_node("World/Cave") as Node4D
	var mouth_w: float = cave.global_position.w
	var cam := Camera4D.new()
	cam.name = "SweepCam"
	_room.add_child(cam)
	cam.set("rendering_engine_name", "Cross-section")
	cam.make_current()
	var art_mesh: Mesh4D = hill.mesh
	# "variants": the dev look's coarse cave baked at other resolutions (_bake_low_cave_runner.gd), copied to
	# res://smoke_test_output/cave_low/low_<dome>_<grid>.res, at the door's W and a metre either side.
	var meshes: Dictionary = MESHES
	var offsets: Array = OFFSETS
	if "variants" in OS.get_cmdline_user_args():
		meshes = {}
		for f in DirAccess.get_files_at("res://smoke_test_output/cave_low/"):
			if f.ends_with(".res"):
				meshes[f.get_basename()] = "res://smoke_test_output/cave_low/" + f
		offsets = [-2.5, -2.0, -1.5, -1.0, -0.5, 0.0]
	for key in meshes:
		var mesh := load(String(meshes[key])) as Mesh4D
		if mesh == null:
			print("CAVE W: no mesh %s" % key)
			continue
		hill.mesh = mesh
		for off in offsets:
			var w: float = mouth_w + float(off)
			cam.global_position = Vector4(7.4, 1.7, 36.5, w)
			cam.look_at(Vector4(7.5, 2.0, 26.4, w), Vector4(0, 1, 0, 0))
			for i in 4:
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "%s_%+.1f.png" % [key, off]))
		print("CAVE W: %s done" % key)
	hill.mesh = art_mesh
	print("CAVE W: mouth at w %.2f; done" % mouth_w)
	quit(0)
