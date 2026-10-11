extends SceneTree

## Debug views: put the player at given places in a level and photograph (smoke_test_output/maze_remake_2/dbg/).
## Args after --: level number, then shots "x,z,w,yaw_deg,pitch_deg[,tilt_deg]" separated by spaces.
##   run.sh windowed dbg res://ramon/MazeRemake2/scripts/_debug_views_runner.gd 3 "-12.4,2,-1.7,90,0" ...

const SCENE := "res://ramon/MazeRemake2/maze_remake_2.tscn"
const OUT := "res://smoke_test_output/maze_remake_2/dbg/"

var _t0: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run.call_deferred()


func _process(_x: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 90000:
		print("DBG FAIL: timeout")
		quit(1)
		return true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return false


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var lvl: int = int(args[0]) if args.size() > 0 else 1
	var game: Node = (load(SCENE) as PackedScene).instantiate()
	game.set("capture_mouse", false)
	game.set("popups", false)
	game.set("start_level", lvl)
	root.add_child(game)
	for i in 600:
		if String(game.get("mode")) == "play":
			break
		await physics_frame
	var player: CharacterBody4D = game.get("player")
	player.set("input_enabled", false)
	if not "hud" in OS.get_cmdline_user_args():
		(game.get("hud") as CanvasLayer).visible = false
	game.set("sighted", true)
	# "lenstaken": level 2's Lens counts as taken (its film never starts; the kennel stays shut).
	if "lenstaken" in args:
		(game.get("level") as Node).set("lens_taken", true)
	for k in range(1, args.size()):
		if not "," in args[k]:
			continue
		var v: PackedStringArray = args[k].split(",")
		var pos := Vector4(float(v[0]), 0.0, float(v[1]), float(v[2]))
		player.call("place", pos, deg_to_rad(float(v[3])))
		var g: Projection = Basis4D.from_zx(deg_to_rad(float(v[3])))
		if v.size() > 5:
			g = g * Basis4D.from_zw(deg_to_rad(float(v[5])))
		player.set("ground", g)
		player.basis = g
		(player.get("head") as Node4D).basis = Basis4D.from_yz(deg_to_rad(float(v[4])))
		for f in 6:
			await physics_frame
		await RenderingServer.frame_post_draw
		var name: String = "L%d_%02d" % [lvl, k]
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
		print("DBG frame %s at %s  feet %s" % [name, args[k], player.call("feet")])
	quit(0)
