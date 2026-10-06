extends SceneTree
## Step 3: a before-picture of the current Miegakure prototype (MiegakureLook/levels/): each of its
## three levels in the normal view and turned into W, saved to
## smoke_test_output/crosswise/before/. Nothing in the levels is changed; the turn is the
## real right-mouse press.
##
## Run: Crosswise/run.sh windowed before res://ramon/Crosswise/probes/_capture_before_runner.gd

const OUT := "res://smoke_test_output/crosswise/before/"
const LEVELS := [
	"res://ramon/MiegakureLook/levels/level_1_wall.tscn",
	"res://ramon/MiegakureLook/levels/level_2_bridge.tscn",
	"res://ramon/MiegakureLook/levels/level_3_detour.tscn",
]

var _index: int = -1
var _scene: Node
var _t: float = 0.0
var _beat: int = 0
var _total: float = 0.0


func _initialize() -> void:
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_next()


func _next() -> void:
	if _scene != null:
		_scene.queue_free()
		_scene = null
	_index += 1
	_beat = 0
	_t = 0.0
	if _index >= LEVELS.size():
		return
	_scene = (load(LEVELS[_index]) as PackedScene).instantiate()
	root.add_child.call_deferred(_scene)


func _process(delta: float) -> bool:
	_total += delta
	if _total > 80.0:
		print("BEFORE FAIL: timed out")
		return true
	if _index >= LEVELS.size():
		print("BEFORE done: %d levels" % LEVELS.size())
		return true
	_t += delta
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	match _beat:
		0:
			if _t > 1.2:
				_save("level%d_normal" % (_index + 1))
				var press := InputEventMouseButton.new()
				press.button_index = MOUSE_BUTTON_RIGHT
				press.pressed = true
				Input.parse_input_event(press)
				var release := InputEventMouseButton.new()
				release.button_index = MOUSE_BUTTON_RIGHT
				release.pressed = false
				Input.parse_input_event(release)
				_beat = 1
				_t = 0.0
		1:
			if _t > 1.4:
				_save("level%d_turned" % (_index + 1))
				_next()
	return false


func _save(name: String) -> void:
	var image: Image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("BEFORE saved %s" % name)
