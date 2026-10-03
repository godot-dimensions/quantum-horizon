extends SceneTree

## Does the grass lie the way you walk, stay down behind you and come up again? The player walks
## a straight line across the field at a walking pace, watched from above and behind; frames
## while walking, then after stopping (the trail should fade over the next seconds). Saves
## res://smoke_test_output/trail_<n>_<what>.png.
##
##   godot... --path project --windowed --resolution 1280x720 --position 40,40
##       --script res://ramon/chickenpen/grass/_trail_grass_runner.gd

const SPEED := 2.5
const WALK := 3.2
const SHOTS := [[1.6, "walking"], [3.2, "walked_8m"], [4.2, "stopped_1s"], [7.2, "stopped_4s"], [11.2, "stopped_8s"]]

var _room: Node
var _grass: Node
var _cam: Camera4D
var _player: Node4D
var _t: float = 0.0
var _go: bool = false
var _shot: int = 0
var _start := Vector4(6.0, 0.05, 6.0, 0.0)
var _dir := Vector4(-0.8, 0.0, -0.6, 0.0)


func _initialize() -> void:
	root.unfocusable = true
	_room = load("res://ramon/chickenpen/chickenpen_lookout.tscn").instantiate()
	_room.get_node("Systems/Lookout").set("journal_path", "user://lookout_journal_trail_test.cfg")
	_grass = _room.get_node("World/Grass")
	root.add_child(_room)
	current_scene = _room


func _process(d: float) -> bool:
	_t += d
	if not _go:
		if _t > 60.0:
			print("TRAIL FAILED: no grass after 60 s")
			return true
		if not bool(_grass.get("mask_ready")) or _t < 4.0:
			return false
		for child in _room.get_node("UI").get_children():
			if child is CanvasItem:
				(child as CanvasItem).visible = false
		_player = _room.get_node("Player") as Node4D
		_player.set_physics_process(false)
		_cam = Camera4D.new()
		_cam.set("rendering_engine_name", "Cross-section")
		_cam.set("field_of_view_4d", 1.0)
		_player.add_child(_cam)
		_cam.make_current()
		_go = true
		_t = 0.0
	var walked: float = minf(_t, WALK) * SPEED
	_player.global_position = _start + _dir * walked
	# Above and to the side of where the walk ends, looking back along it.
	var end: Vector4 = _start + _dir * (WALK * SPEED)
	var eye: Vector4 = end + Vector4(-2.5, 3.2, 3.4, 0.0)
	_cam.global_position = eye
	var at: Vector4 = _start + _dir * (WALK * SPEED * 0.55)
	var dd: Vector4 = at - eye
	_cam.global_basis = Basis4D.from_zx(atan2(-dd.x, -dd.z)) * Basis4D.from_yz(atan2(dd.y, Vector2(dd.x, dd.z).length()))
	if _shot < SHOTS.size() and _t >= float(SHOTS[_shot][0]):
		root.get_texture().get_image().save_png("res://smoke_test_output/trail_%d_%s.png" % [_shot, SHOTS[_shot][1]])
		_shot += 1
		if _shot >= SHOTS.size():
			print("TRAIL DONE")
			if FileAccess.file_exists("user://lookout_journal_trail_test.cfg"):
				DirAccess.remove_absolute(ProjectSettings.globalize_path("user://lookout_journal_trail_test.cfg"))
			return true
	return false
