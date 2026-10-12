extends SceneTree

## Nike leaves a trail through the grass too (Ramon, 3 Oct: "nikepig doesnt leave a grass trail
## when he walks"). Nike is walked in a straight line across the field outside the pen at a
## walking pace; the grass's trails are read (Nike's own, by instance id) and a frame saved from
## above, as Nike goes and four seconds after: res://smoke_test_output/nike_trail_<n>.png.
## Prints PASS or FAIL per check; gives up after 60 s.
##
##   godot... --path project --windowed --resolution 1280x720 --position 40,40
##       --script res://ramon/chickenpen/grass/_nike_trail_runner.gd

const SPEED := 1.2
const WALK := 4.0

var _room: Node
var _grass: Node
var _nike: Node4D
var _cam: Camera4D
var _t: float = 0.0
var _go: float = -1.0
var _fails: int = 0
var _start := Vector4(9.0, 0.0, 3.0, 0.0)
var _dir := Vector4(0.0, 0.0, 1.0, 0.0)
var _most: int = 0
var _saved: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_room = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_room)
	current_scene = _room


func _check(what: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_fails += 1
	print("   %s %-44s %s" % ["PASS" if ok else "FAIL", what, detail])


func _trail() -> Array:
	var trails: Dictionary = _grass.get("_trails")
	return trails.get(_nike.get_instance_id(), [])


func _process(d: float) -> bool:
	_t += d
	if _t > 60.0:
		print("NIKE TRAIL FAIL: timed out")
		return true
	if _go < 0.0:
		_grass = _room.get_node_or_null("World/Grass")
		if _grass == null or not bool(_grass.get("mask_ready")) or _t < 6.0:
			return false
		_nike = _room.get_node("World/Nike") as Node4D
		# Nike's own walking is stopped for this: the line is the runner's.
		for child in _nike.get_children():
			child.set_process(false)
			child.set_physics_process(false)
		_cam = Camera4D.new()
		_cam.set("rendering_engine_name", "Cross-section")
		_room.add_child(_cam)
		for c in _room.get_node("UI").get_children():
			if c is CanvasItem:
				(c as CanvasItem).visible = false
		_check("Nike leaves trails", (_grass.get("trail_paths") as Array).has("World/Nike"))
		_go = 0.0
		return false
	_go += d
	var along: float = minf(_go, WALK) * SPEED
	_nike.global_position = _start + _dir * along
	_nike.global_basis = Basis4D.from_zx(atan2(_dir.x, _dir.z))
	_most = maxi(_most, _trail().size())
	# From the side and above, so the line crosses the frame (a lane running straight away from
	# the camera reads as the wind's lean).
	_cam.global_position = _start + _dir * (WALK * SPEED * 0.5) + Vector4(4.5, 3.2, -1.0, 0.0)
	_cam.look_at(_start + _dir * (WALK * SPEED * 0.45))
	_cam.make_current()
	if _saved == 0 and _go > WALK * 0.8:
		root.get_texture().get_image().save_png("res://smoke_test_output/nike_trail_0_walking.png")
		_saved = 1
	if _saved == 1 and _go > WALK + 4.0:
		root.get_texture().get_image().save_png("res://smoke_test_output/nike_trail_1_after.png")
		_saved = 2
		_check("a trail laid behind Nike", _most >= 6, "%d points at most" % _most)
		var first: Array = _trail()
		_check("Nike's trail is Nike's own, not the player's", not first.is_empty() and \
			absf((first[0][0] as Vector4).x - (_grass.global_basis.inverse() * (_nike.global_position - _grass.global_position)).x) < 0.5)
		print("NIKE TRAIL %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
		return true
	return false
