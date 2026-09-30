extends SceneTree

## A clip of the murmuration for Ramon: from the spawn point first, then from beside the
## flock as a hawk comes through. Run with Godot's movie writer, which steps at a fixed rate
## and so records smoothly whatever the machine does:
##
##   godot... --path project --resolution 1280x720 --write-movie <out>.avi --fixed-fps 30
##       --script res://ramon/chickenpen/scripts/_record_flock_runner.gd
##
## HUD hidden, debug keys off, the flock at its in-game settings.

const SPAWN_SECONDS := 5.0
const TOTAL_SECONDS := 16.0

var _room: Node
var _flock: Node4D
var _cam: Camera4D
var _t: float = 0.0
var _f: int = 0
var _called: bool = false
var _eye := Vector4.ZERO


func _initialize() -> void:
	root.unfocusable = true
	_room = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	for node in _room.find_children("*", "", true, false):
		if "debug_key_enabled" in node:
			node.set("debug_key_enabled", false)
	root.add_child(_room)
	current_scene = _room
	_flock = _room.get_node("World/Flock") as Node4D
	# Let it settle into its sweep before the clip starts: the hawk is held back, and the
	# first seconds are the spawn camera anyway.
	_flock.set("hawk_enabled", true)


func _hide_hud(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = false
		_hide_hud(child)


func _middle() -> Vector4:
	var pos: PackedVector4Array = _flock.call("positions")
	var sum := Vector4.ZERO
	for p in pos:
		sum += p
	return sum / maxf(float(pos.size()), 1.0)


func _process(d: float) -> bool:
	_f += 1
	if _f == 2:
		_hide_hud(_room.get_node("UI"))
		(_room.get_node("Player/StateLabel") as CanvasItem).visible = false
		_cam = Camera4D.new()
		_cam.set("rendering_engine_name", "Cross-section")
		_cam.set("field_of_view_3d", 0.96)
		_room.add_child(_cam)
	if _f < 3:
		return false
	_t += d
	if _t >= SPAWN_SECONDS - 2.0 and not _called:
		# In from the side while the camera moves over, so it arrives on screen.
		_flock.call("call_hawk")
		_called = true
	if _t >= SPAWN_SECONDS:
		# Beside the flock, eased along with it rather than bolted to it.
		var m: Vector4 = _middle()
		var want := Vector4(m.x + 30.0, m.y - 6.0, m.z + 22.0, m.w)
		_eye = want if _eye == Vector4.ZERO else _eye.lerp(want, minf(d * 1.5, 1.0))
		_cam.global_position = _eye
		_cam.look_at(m)
		_cam.make_current()
	if _t >= TOTAL_SECONDS:
		quit()
		return true
	return false
