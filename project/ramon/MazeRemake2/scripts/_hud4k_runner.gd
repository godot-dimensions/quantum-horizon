extends SceneTree

## The HUD on Ramon's screen (3840 x 2160; memory: HUD at 4K): a 4K window, the lens and its ruler on
## level 1's door half open, the key card, and the Tab panel, saved at full size and at half for reading.
## Short, and the window takes no input.
##   run.sh windowed hud4k res://ramon/MazeRemake2/scripts/_hud4k_runner.gd

const SCENE := "res://ramon/MazeRemake2/maze_remake_2.tscn"
const OUT := "res://smoke_test_output/maze_remake_2/hud4k/"

var _t0: int = 0


func _initialize() -> void:
	root.unfocusable = true
	DisplayServer.window_set_position(Vector2i(0, 0))
	DisplayServer.window_set_size(Vector2i(3840, 2160))
	_t0 = Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run.call_deferred()


func _process(_x: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 60000:
		print("HUD4K FAIL: gave up after 60 s")
		quit(1)
		return true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return false


func _shot(name: String) -> void:
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	print("HUD4K %s at %dx%d" % [name, img.get_width(), img.get_height()])
	img.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_LANCZOS)
	img.save_png(ProjectSettings.globalize_path(OUT + name + "_half.png"))


func _run() -> void:
	var g: Node = (load(SCENE) as PackedScene).instantiate()
	g.set("capture_mouse", false)
	g.set("popups", false)
	root.add_child(g)
	for i in 600:
		if String(g.get("mode")) == "play":
			break
		await process_frame
	var p: CharacterBody4D = g.get("player")
	p.set("input_enabled", false)
	p.call("place", Vector4(0, 0, -4.5, 1.05), 0.0)
	for i in 30:
		await process_frame
	(g.get("hud") as Node).get("card").call("play", "shift", 8.0, "STEP THROUGH W", "Hold E to shift ana. Q shifts back.")
	await _shot("01_door_lens_card")
	(g.get("tuning") as Node).call("open")
	await _shot("02_tab_panel")
	(g.get("tuning") as Node).call("close")
	quit(0)
