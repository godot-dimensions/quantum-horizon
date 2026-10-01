extends SceneTree

## The pen with its HUD as a player sees it, for placing and checking the murmuration's stats
## panel: a frame from the spawn point, one after a hawk has come, and one with F3 pressed.
## Saves res://smoke_test_output/flockstats_<n>_<what>.png.
##
##   godot... --path project --windowed --resolution 1280x720 --position 40,40
##       --script res://ramon/chickenpen/scripts/_capture_flock_stats_runner.gd

var _room: Node
var _flock: Node4D
var _f: int = 0
var _shots: Array = [[150, "spawn"], [520, "hawk"], [560, "hidden"]]


func _initialize() -> void:
	root.unfocusable = true
	_room = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	for node in _room.find_children("*", "", true, false):
		if "debug_key_enabled" in node:
			node.set("debug_key_enabled", false)
	root.add_child(_room)
	current_scene = _room
	_flock = _room.get_node("World/Flock") as Node4D


func _process(_d: float) -> bool:
	_f += 1
	if _f == 200:
		_flock.call("call_hawk")
	if _f == 540:
		# F3 as if pressed.
		var key := InputEventKey.new()
		key.keycode = KEY_F3
		key.physical_keycode = KEY_F3
		key.pressed = true
		root.push_input(key)
	for shot in _shots:
		if _f == shot[0]:
			root.get_texture().get_image().save_png("res://smoke_test_output/flockstats_%d_%s.png" % [_f, shot[1]])
			print("   saved flockstats_%d_%s.png" % [_f, shot[1]])
	if _f >= 570:
		quit()
		return true
	return false
