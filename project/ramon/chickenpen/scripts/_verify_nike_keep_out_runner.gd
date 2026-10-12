extends SceneTree

## Does Nike keep off the researchers' camp (Ramon, 6 Oct: "nike is walking over the bonfire area, no
## good")? The pen, Nike's walk legs short and time run fast; his distance from the camp's middle
## logged every frame. PASS if he never comes inside the camp's sand (6.6 m) and still roams.
##
##   lab_run.sh windowed nike_keep_out res://ramon/chickenpen/scripts/_verify_nike_keep_out_runner.gd

const CAMP := Vector2(20.0, -2.0)
const CAMP_SAND := 6.6

var _nike: Node4D
var _antics: Node
var _f: int = 0
var _t0: int = 0
var _closest: float = INF
var _inside: int = 0
var _travel: float = 0.0
var _last: Vector4


func _initialize() -> void:
	root.unfocusable = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var scene: Node = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	for node in scene.find_children("*", "", true, false):
		if "debug_key_enabled" in node:
			node.set("debug_key_enabled", false)
	root.add_child(scene)
	current_scene = scene
	_nike = scene.get_node("World/Nike")
	_antics = scene.get_node("World/Nike/Antics")
	_antics.set("walk_seconds", Vector2(3.0, 6.0))
	_antics.set("root_seconds", Vector2(0.3, 0.6))
	_antics.set("lie_seconds", Vector2(0.3, 0.5))
	_antics.set("down_seconds", 0.15)
	_antics.set("up_seconds", 0.2)
	# Toward the camp at the start, the hardest case.
	_antics.set("_yaw", atan2(CAMP.x - _nike.position.x, CAMP.y - _nike.position.z))
	_antics.set("_heading", _antics.get("_yaw"))
	Engine.time_scale = 4.0
	_t0 = Time.get_ticks_msec()
	_last = _nike.global_position


func _process(_d) -> bool:
	_f += 1
	var p: Vector4 = _nike.global_position
	var d: float = Vector2(p.x, p.z).distance_to(CAMP)
	_closest = minf(_closest, d)
	if d < CAMP_SAND:
		_inside += 1
	_travel += Vector2(p.x - _last.x, p.z - _last.z).length()
	_last = p
	if Time.get_ticks_msec() - _t0 < 60000:
		return false
	Engine.time_scale = 1.0
	print("NIKE: %d frames, walked %.1f m, closest to the camp %.2f m, frames inside its sand %d" % [_f, _travel, _closest, _inside])
	var ok: bool = _inside == 0 and _travel > 3.0
	print("NIKE KEEP OUT: %s" % ("PASS" if ok else "FAIL"))
	return true
