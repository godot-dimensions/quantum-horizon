extends SceneTree

## Does he actually roam in the pen scene, and does he still fit in it afterwards?
##
## The scale is the thing worth checking. He is instanced at 0.3 and his behaviour rewrites
## the root basis every time he turns, so a turn that wrote a bare rotation would silently
## restore him to the size he is authored at - three times too big for this scene, and only
## after the first time he stopped walking.

var _nike: Node4D
var _antics: Node
var _start: Vector4
var _f: int = 0
var _turned: bool = false
var _min_scale: float = 99.0
var _max_scale: float = 0.0


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var scene: Node = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	_nike = scene.get_node("World/Nike")
	_antics = scene.get_node("World/Nike/Antics")
	# Shortened HARD. The pen is a heavy scene - twelve pecking chickens and a voxel rock -
	# so only a few hundred render frames fit in a sensible run, and render frames are not
	# seconds anyway: his real walk legs last five to eleven of them.: a few thousand of them is a couple
	# of seconds of simulated time and his walk legs alone last five to eleven.
	_antics.set("walk_seconds", Vector2(0.15, 0.3))
	_antics.set("root_seconds", Vector2(0.2, 0.3))
	_antics.set("lie_seconds", Vector2(0.3, 0.5))
	_antics.set("down_seconds", 0.15)
	_antics.set("up_seconds", 0.2)
	_start = _nike.position


func _process(_d) -> bool:
	_f += 1
	var scale: float = _nike.basis.x.length()
	_min_scale = minf(_min_scale, scale)
	_max_scale = maxf(_max_scale, scale)
	if absf(_nike.basis.z.x) > 0.05:
		_turned = true
	if _f < 60:  # enough to prove travel, a turn and the scale; the pen is too heavy for more
		return false
	var moved: Vector4 = _nike.position - _start
	print("MOVED %.2f from home, turned: %s" % [Vector2(moved.x, moved.z).length(), str(_turned)])
	print("SCALE stayed %.3f to %.3f (authored 0.300)" % [_min_scale, _max_scale])
	print("STATE at end: %d" % int(_antics.get("state")))
	return true
