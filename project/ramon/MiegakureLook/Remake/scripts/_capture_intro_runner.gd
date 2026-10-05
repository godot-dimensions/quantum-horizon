extends SceneTree
## Slice Garden: the opening shot and a turn, as frames. The scene starts as a player starts it (the
## opening shot plays); frames at 0.2, 1.2, 2.4, 3.6 and 5 s, then a turn into W shot at 0.15,
## 0.3, 0.45 and 0.8 s into it (the world deforming round him), to
## smoke_test_output/miegakure_remake/intro/.
##
## Run: Remake/run.sh windowed intro res://ramon/MiegakureLook/Remake/scripts/_capture_intro_runner.gd

const SCENE := "res://ramon/MiegakureLook/Remake/slice_garden.tscn"
const OUT := "res://smoke_test_output/miegakure_remake/intro/"
const SHOTS := [0.2, 1.2, 2.4, 3.6, 5.0]
const TURN_SHOTS := [0.15, 0.3, 0.45, 0.8]

var _game: Node
var _t: float = 0.0
var _total: float = 0.0
var _shot: int = 0
var _turn_t: float = -1.0
var _turn_shot: int = 0


func _initialize() -> void:
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_game = (load(SCENE) as PackedScene).instantiate()
	root.add_child.call_deferred(_game)


func _process(delta: float) -> bool:
	_total += delta
	if _total > 60.0:
		print("INTRO FAIL: timed out")
		return true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _game == null or not _game.is_inside_tree():
		return false
	_t += delta
	if _shot < SHOTS.size():
		if _t >= SHOTS[_shot]:
			_save("intro_%d_%.1fs" % [_shot, SHOTS[_shot]])
			_shot += 1
		return false
	if _turn_t < 0.0:
		if _t > 5.6:
			(_game.get("camera") as Node).call("request_turn")
			_turn_t = 0.0
		return false
	_turn_t += delta
	if _turn_shot < TURN_SHOTS.size() and _turn_t >= TURN_SHOTS[_turn_shot]:
		_save("turn_%d_%.2fs" % [_turn_shot, TURN_SHOTS[_turn_shot]])
		_turn_shot += 1
	if _turn_shot >= TURN_SHOTS.size():
		print("INTRO done")
		return true
	return false


func _save(name: String) -> void:
	var image: Image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("INTRO saved %s" % name)
