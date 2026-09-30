extends SceneTree

## The menu crash with the menu taken out: scene A as the current scene, freed, then scene B.
## Answers whether the crash needs the menu's launch path at all, or is the engine's own.
##
##   ... --script res://ramon/Menu/_repro_engine_switch_runner.gd -- <scene A> <scene B> [free|keep|swap]
##
## free: A is freed before B is added (what the menu does). keep: B is added while A is still
## in the tree. swap: change_scene_to_file, the plain Godot way.

var _a := ""
var _b := ""
var _mode := "free"
var _scene: Node
var _f := 0


func _initialize() -> void:
	root.unfocusable = true
	var args := OS.get_cmdline_user_args()
	_a = String(args[0])
	_b = String(args[1])
	if args.size() > 2:
		_mode = String(args[2])
	_scene = load(_a).instantiate()
	root.add_child(_scene)
	current_scene = _scene
	print("SWITCH: A = %s, B = %s, mode %s" % [_a, _b, _mode])


func _process(_d: float) -> bool:
	_f += 1
	if _f == 200:
		print("SWITCH: A ran 200 frames")
		match _mode:
			"swap":
				change_scene_to_file(_b)
			"keep":
				var b: Node = load(_b).instantiate()
				root.add_child(b)
				print("SWITCH: B added beside A")
			_:
				_scene.queue_free()
	if _f == 204 and _mode == "free":
		var b: Node = load(_b).instantiate()
		root.add_child(b)
		current_scene = b
		print("SWITCH: B added after A was freed")
	if _f == 500:
		print("SWITCH: SURVIVED")
		quit()
		return true
	return false
