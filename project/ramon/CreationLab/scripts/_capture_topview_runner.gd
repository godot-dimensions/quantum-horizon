extends SceneTree

## Plan views of the walk markers (Ramon, 5 Oct: "make a topview so I can clearly see all the walk
## markers from above that we designed"): an orthographic camera straight down over the Creation Lab
## and over Room 2's path test bed, the ceilings, the light fixtures, the player and the HUD hidden,
## the window as large as the screen allows. Prints the scale (pixels a metre) and the world point at
## the image's centre, for labelling. To res://smoke_test_output/creation_lab/topview/.
##
##   CreationLab/scripts/lab_run.sh windowed topview res://ramon/CreationLab/scripts/_capture_topview_runner.gd

const SCENE := "res://ramon/CreationLab/creation_lab.tscn"
const OUT := "res://smoke_test_output/creation_lab/topview/"

var _g: Node
var _cam: Camera4D


func _initialize() -> void:
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run.call_deferred()


func _process(_dt: float) -> bool:
	return false


func _wait(s: float) -> void:
	var until: int = Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


func _hide_named(n: Node, prefixes: Array) -> void:
	for c in n.get_children():
		for p in prefixes:
			if String(c.name).begins_with(p) and c is Node4D:
				(c as Node4D).visible = false
		_hide_named(c, prefixes)


## Straight down over (cx, cz), `height_m` metres from the image's bottom edge to its top (the
## orthographic size is the whole height, as Camera3D's is); the room's length (-z) runs to the
## right, its left side (-x) up.
func _plan(what: String, cx: float, cz: float, height_m: float) -> void:
	_cam.set("orthographic_size", height_m)
	_cam.global_position = Vector4(cx, 30.0, cz, 0.0)
	_cam.global_basis = Projection(Vector4(0, 0, -1, 0), Vector4(-1, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 0, 1))
	await _wait(0.8)
	await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png(OUT + what + ".png")
	print("%s: %dx%d px, %.2f px/m, centre (%.2f, %.2f), right is -z, up is -x" % [what, img.get_width(), img.get_height(), float(img.get_height()) / height_m, cx, cz])


func _run() -> void:
	var screen: Vector2i = DisplayServer.screen_get_size()
	var want := Vector2i(mini(screen.x - 80, 3200), mini(screen.y - 120, 1800))
	DisplayServer.window_set_size(want)
	_g = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_g)
	current_scene = _g
	await _wait(4.5)
	for c in _g.get_children():
		if c is CanvasLayer:
			(c as CanvasLayer).visible = false
	(_g.get("player") as Node4D).visible = false
	_hide_named(_g, ["Ceiling", "Fixture"])
	for light in _g.find_children("*", "Node4D", true, false):
		if light.get("fixture") != null and light.get("aim") != null:
			light.set("fixture", false)
	_cam = Camera4D.new()
	_cam.set("rendering_engine_name", "Cross-section")
	_cam.set("projection_type", 0)
	_g.add_child(_cam)
	_cam.current = true
	await _wait(0.5)
	print("window ", DisplayServer.window_get_size())
	# The Creation Lab: entrance corridor (z up to about 17) to the back door (z -11).
	await _plan("creation_lab_plan", 0.0, 2.6, 22.0)
	# Room 2 (centre z -27, 30 by 30).
	await _plan("room2_plan", 0.0, -27.0, 31.5)
	# The same on the near-black palette (B), where the markers read most clearly.
	_g.call("toggle_palette")
	await _wait(0.5)
	await _plan("creation_lab_plan_black", 0.0, 2.6, 22.0)
	await _plan("room2_plan_black", 0.0, -27.0, 31.5)
	_g.call("toggle_palette")
	quit(0)
