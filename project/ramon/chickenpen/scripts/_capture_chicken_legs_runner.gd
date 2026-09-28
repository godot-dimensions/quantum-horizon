extends SceneTree

## Four frames of one animal walking, side-on and close, from the real pen.
##
## Defaults to a chicken. After `--`, `who=World/Nike dist=3.2 tag=nike` points it at
## anything else that walks.
##
## The leg runners in this folder measure the block people's gait and the carry, not the
## chicken's legs, so none of them would notice a thigh on backwards. This one exists to be
## LOOKED AT - after the legs stopped being skinned and became two rigid halves each, the
## only honest check is a picture of a bird mid-stride.
##
## Windowed (the headless renderer draws nothing). Writes res://smoke_test_output/legs_N.png

const SCENE := "res://ramon/chickenpen/chickenpen.tscn"
const SHOTS := [150, 162, 174, 186]

var _who: String = "Chickens/Chicken01"
var _dist: float = 1.25
var _tag: String = "legs"

var _room: Node
var _cam: Camera4D
var _f: int = 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv: PackedStringArray = arg.split("=")
		if kv.size() != 2:
			continue
		match kv[0]:
			"who": _who = kv[1]
			"dist": _dist = float(kv[1])
			"tag": _tag = kv[1]
	_room = load(SCENE).instantiate()
	root.add_child(_room)
	current_scene = _room
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://smoke_test_output"))


func _process(_d: float) -> bool:
	_f += 1
	var bird := _room.get_node_or_null(_who) as Node4D
	if bird == null:
		print("nothing at %s" % _who)
		quit()
		return true
	if _cam == null:
		_cam = Camera4D.new()
		_cam.rendering_engine_name = "Cross-section"
		_room.add_child(_cam)
		_cam.current = true
	# Follow it: side-on at the bird's own height, a little above, in its own slice.
	var at: Vector4 = bird.global_position
	var side: Vector4 = bird.global_basis.x.normalized()
	_cam.global_position = at + side * _dist + Vector4(0.0, absf(_dist) * 0.36, 0.0, 0.0)
	_cam.look_at(at + Vector4(0.0, 0.25, 0.0, 0.0))
	if _f in SHOTS:
		var n: int = SHOTS.find(_f)
		root.get_texture().get_image().save_png("res://smoke_test_output/%s_%d.png" % [_tag, n])
		print("   saved %s_%d.png" % [_tag, n])
	if _f > SHOTS[-1]:
		quit()
		return true
	return false
