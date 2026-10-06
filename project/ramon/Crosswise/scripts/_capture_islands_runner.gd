extends SceneTree
## Crosswise: a look at every island. Loads the scene, puts the walker on each island's arrival
## ring (and at a few chosen spots), and saves a frame in the normal view and one turned into W.
## Frames to smoke_test_output/crosswise/islands/. Prints any island registry problems.
##
## Run: Crosswise/run.sh windowed islands res://ramon/Crosswise/scripts/_capture_islands_runner.gd

const SCENE := "res://ramon/Crosswise/crosswise.tscn"
const OUT := "res://smoke_test_output/crosswise/islands/"

## [name, where (x, y, z, w), facing]
var SPOTS := [
	["i1_start", Vector4(0, 0.05, 4.6, 0), PI],
	["i1_wall", Vector4(0, 0.05, 1.2, 0), PI],
	["i1_gate_lane", Vector4(0, 0.05, 1.2, 3.2), PI],
	["i1_terrace", Vector4(0.5, 0.05, -3.0, 0), PI],
	["i2_start", Vector4(0, 1.4, -11.6, 0), PI],
	["i2_cage_lane_m1", Vector4(-2.4, 1.4, -14.6, -1.6), PI],
	["i2_plate", Vector4(1.0, 1.4, -18.6, 0), PI],
	["i3_start", Vector4(0, 1.4, -35.9, 0), PI],
	["i3_band", Vector4(0, 1.4, -44.2, 0.8), PI],
	["i4_start", Vector4(0, 1.4, -55.2, 3.2), PI],
	["i4_mark", Vector4(0, 1.4, -61.0, 0), PI],
]

var _game: Node
var _t: float = 0.0
var _total: float = 0.0
var _i: int = 0
var _phase: int = 0


func _initialize() -> void:
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_game = (load(SCENE) as PackedScene).instantiate()
	_game.set("play_intro", false)
	root.add_child.call_deferred(_game)


func _process(delta: float) -> bool:
	_total += delta
	if _total > 120.0:
		print("ISLANDS FAIL: timed out at %d/%d" % [_i, SPOTS.size()])
		return true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _game == null or not _game.is_inside_tree():
		return false
	_t += delta
	if _i >= SPOTS.size():
		print("ISLANDS done: %d spots" % SPOTS.size())
		return true
	var spot: Array = SPOTS[_i]
	var walker: Node = _game.get("walker")
	var cam: Node = _game.get("camera")
	match _phase:
		0:
			walker.set("input_enabled", false)
			cam.call("set_turned", false)
			walker.call("place_at", spot[1], spot[2])
			cam.call("snap_focus")
			_phase = 1
			_t = 0.0
		1:
			if _t > 1.3:
				_save(String(spot[0]) + "_normal")
				cam.call("request_turn")
				_phase = 2
				_t = 0.0
		2:
			if _t > 1.2:
				_save(String(spot[0]) + "_turned")
				_i += 1
				_phase = 0
	return false


func _save(name: String) -> void:
	var image: Image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	var w: Node4D = _game.get("walker")
	print("ISLANDS saved %s, walker at %s, island %d" % [name, w.global_position, int(_game.get("island"))])
