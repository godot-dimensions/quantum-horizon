extends SceneTree

## A LOOK AT A TALL ONE (smoke_test_output/maze_remake_2/walker_look/): level 1's Tall One, calm (it never
## notices), photographed in the dark look from the front, three-quarter, side, back, its head close, low
## down; from slices a little off its W (it thins, limbs first); walking; its eyes red; and in the bright
## look. The camera is the player's own, placed and aimed at it.
##   run.sh windowed look res://ramon/MazeRemake2/scripts/_walker_look_runner.gd

const SCENE := "res://ramon/MazeRemake2/maze_remake_2.tscn"
const OUT := "res://smoke_test_output/maze_remake_2/walker_look/"

var _t0: int = 0
var _game: Node
var _player: CharacterBody4D
var _w: Node4D


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run.call_deferred()


func _process(_x: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 90000:
		print("LOOK FAIL: timeout")
		quit(1)
		return true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return false


## The camera `dist` from the Tall One at `angle` round it (0: where it looks), feet `dw` off its W,
## looking at a point `aim_y` up it.
func _view(name: String, dist: float, angle: float, dw: float, aim_y: float) -> void:
	var q: Vector4 = _w.global_position
	var face: float = float(_w.get("yaw")) + angle
	var e := Vector2(q.x - sin(face) * dist, q.z - cos(face) * dist)
	var yaw: float = atan2(e.x - q.x, e.y - q.z)
	_player.call("place", Vector4(e.x, 0.0, e.y, q.w + dw), yaw)
	var g: Projection = Basis4D.from_zx(yaw)
	_player.set("ground", g)
	_player.basis = g
	var pitch: float = atan2(aim_y - 1.625, dist)
	(_player.get("head") as Node4D).basis = Basis4D.from_yz(pitch)
	for f in 8:
		await physics_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("LOOK frame ", name)


func _run() -> void:
	_game = (load(SCENE) as PackedScene).instantiate()
	_game.set("capture_mouse", false)
	root.add_child(_game)
	for i in 600:
		if String(_game.get("mode")) == "play":
			break
		await physics_frame
	_game.set("sighted", true)
	(_game.get("light") as Node).call("set_dark", true, false)
	(_game.get("hud") as CanvasLayer).visible = false
	_player = _game.get("player")
	_player.set("input_enabled", false)
	_w = ((_game.get("level") as Node).get("walkers") as Array)[0]
	_w.set("notice_range", 0.0)
	# Angle 0 stands where it looks; positive angles go round to its left (+x here, clear of the wall).
	await _view("01_front", 3.2, 0.0, 0.0, 1.6)
	await _view("02_three_quarter", 3.0, 0.7, 0.0, 1.6)
	await _view("03_side", 3.0, PI * 0.5, 0.0, 1.6)
	await _view("04_back", 3.0, PI, 0.0, 1.6)
	await _view("05_head", 1.3, 0.3, 0.0, 2.6)
	await _view("06_hands", 1.5, 0.9, 0.0, 0.95)
	await _view("07_low", 2.2, 0.4, 0.0, 2.4)
	await _view("08_w_plus_025", 3.2, 0.0, 0.25, 1.6)
	await _view("09_w_plus_040", 3.2, 0.0, 0.4, 1.6)
	# Walking: pacing toward the hall's mouth and back.
	var q: Vector4 = _w.global_position
	_w.set("pace_to", Vector4(q.x, 0.0, q.z + 4.0, q.w))
	_w.set("_pace_wait", 0.0)
	for f in 90:
		await physics_frame
	await _view("10_walking_a", 3.4, 1.3, 0.0, 1.5)
	for f in 20:
		await physics_frame
	await _view("11_walking_b", 3.4, 1.3, 0.0, 1.5)
	await _view("12_walking_front", 3.6, 0.0, 0.0, 1.5)
	# Its eyes red.
	_w.set("red", 1.0)
	_w.set("state", "notice")
	await _view("13_red_eyes", 1.6, 0.2, 0.0, 2.6)
	_w.set("state", "idle")
	_w.set("red", 0.0)
	(_game.get("light") as Node).call("set_dark", false, false)
	await _view("14_bright", 3.0, 0.6, 0.0, 1.6)
	(_game.get("light") as Node).call("set_dark", true, false)
	print("LOOK DONE")
	quit(0)
