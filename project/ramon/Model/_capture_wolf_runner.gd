extends SceneTree

## The wolf (wolf.tscn) from all round, standing and then walking in place, in the pen's own
## light with the grass and the HUD off: for checking its proportions and anything odd (Ramon,
## 3 Oct: "check it several times for proportions and oddities"). A man-sized marker post stands
## beside it for scale (1.7 m, the player's height). Saves res://smoke_test_output/wolf_<n>_<view>.png
## and prints the loft's warnings for the wolf alone.
##
##   godot... --path project --windowed --resolution 1280x720 --position 40,40
##       --script res://ramon/Model/_capture_wolf_runner.gd

const VIEWS := [["side", Vector4(2.4, 0.75, 0.0, 0.0)], ["front", Vector4(0.0, 0.85, 2.4, 0.0)],
	["three_quarter", Vector4(1.7, 1.1, 1.7, 0.0)], ["rear", Vector4(-1.2, 0.9, -2.2, 0.0)],
	["above", Vector4(0.6, 3.0, 0.2, 0.0)], ["head", Vector4(0.45, 0.88, 1.3, 0.0)]]
const WALK_SHOTS := 4

var _room: Node
var _wolf: Node4D
var _cam: Camera4D
var _t: float = 0.0
var _step: int = -1
var _wait: float = 0.0
var _n: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_room = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	var grass: Node = _room.get_node_or_null("World/Grass")
	if grass != null:
		(grass as Node4D).visible = false
	root.add_child(_room)
	current_scene = _room
	for c in _room.get_node("UI").get_children():
		if c is CanvasItem:
			(c as CanvasItem).visible = false
	print("--- building the wolf ---")
	_wolf = load("res://ramon/Model/wolf.tscn").instantiate()
	_wolf.get_node("Walker").set_process(false)
	_wolf.get_node("Walker").set_physics_process(false)
	_room.get_node("World").add_child(_wolf)
	_wolf.global_position = Vector4(14.0, 0.0, 12.0, 0.0)
	# A post the player's height beside it, for scale.
	var post := MeshInstance4D.new()
	var box := BoxTetraMesh4D.new()
	box.size = Vector4(0.06, 1.7, 0.06, 0.06)
	post.mesh = box
	_room.get_node("World").add_child(post)
	post.global_position = _wolf.global_position + Vector4(-0.6, 0.85, 0.3, 0.0)
	print("--- wolf built ---")
	_cam = Camera4D.new()
	_cam.set("rendering_engine_name", "Cross-section")
	_room.add_child(_cam)


func _shoot(view: String, offset: Vector4) -> void:
	var at: Vector4 = _wolf.global_position
	_cam.global_position = at + offset
	_cam.look_at(at + (Vector4(0.0, 0.78, 0.6, 0.0) if view == "head" else Vector4(0.0, 0.5, 0.08, 0.0)))
	_cam.make_current()


func _process(d: float) -> bool:
	_t += d
	if _t > 80.0:
		print("WOLF CAPTURE FAIL: timed out")
		return true
	_wait -= d
	if _wait > 0.0:
		return false
	if _step == -1:
		if _t < 5.0:
			return false
		_step = 0
		_extent()
		_shoot(VIEWS[0][0], VIEWS[0][1])
		_wait = 0.4
		return false
	if _step < VIEWS.size():
		root.get_texture().get_image().save_png("res://smoke_test_output/wolf_%d_%s.png" % [_n, VIEWS[_step][0]])
		_n += 1
		_step += 1
		if _step < VIEWS.size():
			_shoot(VIEWS[_step][0], VIEWS[_step][1])
			_wait = 0.4
		else:
			# Walking in place, the walker's treadmill.
			_wolf.get_node("Walker").set_process(true)
			_wolf.get_node("Walker").set_physics_process(true)
			_shoot("side", VIEWS[0][1])
			_wait = 2.0
		return false
	var k: int = _step - VIEWS.size()
	if k < WALK_SHOTS:
		root.get_texture().get_image().save_png("res://smoke_test_output/wolf_%d_walk.png" % _n)
		_n += 1
		_step += 1
		_wait = 0.17
		if k == WALK_SHOTS - 1:
			_shoot("three_quarter", VIEWS[2][1])
			_wait = 0.5
		return false
	root.get_texture().get_image().save_png("res://smoke_test_output/wolf_%d_walk_three_quarter.png" % _n)
	print("WOLF CAPTURE DONE")
	return true


## How big it actually came out, from the hide's own vertices: the size of an animal is easier
## to trust as numbers than off a picture.
func _extent() -> void:
	var mesh := (_wolf.get_node("Hide") as MeshInstance4D).mesh as ArrayTetraMesh4D
	# Once the walker has cut the hide, the rig draws nothing; its pieces share the whole
	# vertex array.
	var body := _wolf.get_node_or_null("Hide/Body") as MeshInstance4D
	if mesh == null and body != null:
		mesh = body.mesh as ArrayTetraMesh4D
	if mesh == null:
		print("      no hide mesh yet")
		return
	var lo := Vector4(INF, INF, INF, INF)
	var hi := -lo
	var torso_lo: float = INF
	var torso_hi: float = -INF
	for v in mesh.vertex_positions:
		lo = Vector4(minf(lo.x, v.x), minf(lo.y, v.y), minf(lo.z, v.z), minf(lo.w, v.w))
		hi = Vector4(maxf(hi.x, v.x), maxf(hi.y, v.y), maxf(hi.z, v.z), maxf(hi.w, v.w))
		# The torso's width at the chest: vertices within 5 cm of z 0.24 and above the elbows.
		if absf(v.z - 0.24) < 0.05 and v.y > 0.5 and absf(v.w) < 0.03:
			torso_lo = minf(torso_lo, v.x)
			torso_hi = maxf(torso_hi, v.x)
	print("      wolf extent (m): x %.2f..%.2f  y %.2f..%.2f  z %.2f..%.2f  w %.2f..%.2f" % [lo.x, hi.x, lo.y, hi.y, lo.z, hi.z, lo.w, hi.w])
	print("      chest width at w 0: %.2f m;  nose to tail tip %.2f m;  height %.2f m" % [torso_hi - torso_lo, hi.z - lo.z, hi.y - lo.y])
