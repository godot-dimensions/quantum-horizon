extends SceneTree

## A CLIP OF A TALL ONE WALKING (smoke_test_output/maze_remake_2/walker_clip/, frames at a fixed 30 fps):
## level 1's Tall One seen side-on from across the Long Hall, first pacing (calm), then hunting a decoy
## at the hall's mouth (faster, leaning in), then standing, searching. The camera is the player's, held still
## at 0.7 m off its W so it never notices the camera itself.
##   run.sh clip wclip res://ramon/MazeRemake2/scripts/_walker_clip_runner.gd
## then: ffmpeg -framerate 30 -i walker_clip/%04d.png -c:v libx264 -pix_fmt yuv420p walker_clip.mp4

const SCENE := "res://ramon/MazeRemake2/maze_remake_2.tscn"
const OUT := "res://smoke_test_output/maze_remake_2/walker_clip/"

var _t0: int = 0
var _n: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run.call_deferred()


func _process(_x: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 240000:
		print("CLIP FAIL: timeout")
		quit(1)
		return true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return false


func _frames(n: int, cam: CharacterBody4D, w: Node4D) -> void:
	for i in n:
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "%04d.png" % _n))
		_n += 1


func _run() -> void:
	var game: Node = (load(SCENE) as PackedScene).instantiate()
	game.set("capture_mouse", false)
	game.set("popups", false)
	root.add_child(game)
	for i in 600:
		if String(game.get("mode")) == "play":
			break
		await physics_frame
	game.set("sighted", true)
	(game.get("hud") as CanvasLayer).visible = false
	var cam: CharacterBody4D = game.get("player")
	cam.set("input_enabled", false)
	var w: Node4D = ((game.get("level") as Node).get("walkers") as Array)[0]
	var post: Vector4 = w.get("post")
	# The camera across the hall, side-on to its path, a little off its W (it cannot see the camera).
	cam.call("place", Vector4(2.2, 0.0, post.z + 4.0, post.w + 0.7), PI * 0.5)
	var g: Projection = Basis4D.from_zx(PI * 0.5 - 0.2)
	cam.set("ground", g)
	cam.basis = g
	(cam.get("head") as Node4D).basis = Basis4D.from_yz(0.18)
	# Make the walker visible from the camera's W: the clip is about its walk, so it is shown at the
	# camera's W by moving its post there (it lives at one W; here, that one).
	w.set("post", Vector4(post.x, post.y, post.z, post.w + 0.7))
	w.call("reset")
	w.set("notice_range", 0.0)
	# 1. Pacing toward the hall's mouth (calm, 0.5 m/s).
	w.set("pace_to", Vector4(post.x, 0.0, post.z + 6.0, post.w + 0.7))
	w.set("_pace_wait", 0.0)
	await _frames(150, cam, w)
	# 2. Hunting a decoy at the hall's mouth: it turns to it, leans in, walks faster.
	var decoy := Node4D.new()
	game.add_child(decoy)
	decoy.global_position = Vector4(post.x, 0.875, post.z + 11.0, post.w + 0.7)
	w.set("player", decoy)
	w.call("hunt_now")
	await _frames(150, cam, w)
	# 3. It loses the decoy (gone from its slice): it searches.
	decoy.global_position = decoy.global_position + Vector4(0, 0, 0, 3.0)
	await _frames(120, cam, w)
	print("CLIP DONE %d frames" % _n)
	quit(0)
