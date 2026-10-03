extends SceneTree

## Do the LOD bands show as rings that move with you? The wind is stilled, a camera that is
## the player's own (so the bands centre on the player) is held at one place in the world, and
## the player steps across the field a metre at a time; a frame is saved at each step. Anything
## that changes far from the player between frames is the bands moving, nothing else (pass
## tag=<name> after "--" to name the frames; key=value sets a Grass knob, as in the capture
## runner). Saves res://smoke_test_output/rings_<tag>_<n>.png; compare them with a diff.
##
##   godot... --path project --windowed --resolution 1280x720 --position 40,40
##       --script res://ramon/chickenpen/grass/_rings_grass_runner.gd -- tag=before

const STEPS := 4

var _room: Node
var _grass: Node
var _cam: Camera4D
var _player: Node4D
var _t: float = 0.0
var _step: int = -1
var _tag: String = "test"
var _eye := Vector4(6.0, 1.7, 14.0, 0.0)
var _start := Vector4(4.0, 0.05, 8.0, 0.0)


func _initialize() -> void:
	root.unfocusable = true
	_room = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	_room.get_node("Systems/Lookout").set("journal_path", "user://lookout_journal_rings_test.cfg")
	_grass = _room.get_node("World/Grass")
	# Still air: no gusts, no rock, no flutter, so only the bands can change a far blade.
	_grass.set("wind_speed", 0.0)
	_grass.set("bend_max", 0.0)
	for arg in OS.get_cmdline_user_args():
		var kv: PackedStringArray = arg.split("=", true, 1)
		if kv.size() != 2:
			continue
		if kv[0] == "tag":
			_tag = kv[1]
		else:
			_grass.set(kv[0], float(kv[1]))
	root.add_child(_room)
	current_scene = _room


func _process(d: float) -> bool:
	_t += d
	if _step < 0:
		if not bool(_grass.get("mask_ready")) or _t < 4.0:
			return false
		for child in _room.get_node("UI").get_children():
			if child is CanvasItem:
				(child as CanvasItem).visible = false
		_player = _room.get_node("Player") as Node4D
		_player.set_physics_process(false)
		_player.set_process(false)
		_cam = Camera4D.new()
		_cam.set("rendering_engine_name", "Cross-section")
		_cam.set("field_of_view_4d", 1.0)
		_player.add_child(_cam)
		_cam.make_current()
		_step = 0
		_place()
		_t = 0.0
		return false
	if _t < 0.6:
		return false
	root.get_texture().get_image().save_png("res://smoke_test_output/rings_%s_%d.png" % [_tag, _step])
	_step += 1
	if _step >= STEPS:
		print("RINGS DONE")
		if FileAccess.file_exists("user://lookout_journal_rings_test.cfg"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://lookout_journal_rings_test.cfg"))
		return true
	_place()
	_t = 0.0
	return false


## The player a metre further along for each step; the camera put back where it was, looking
## across the field away from them.
func _place() -> void:
	_player.global_position = _start + Vector4(-1.0, 0.0, -0.6, 0.0) * float(_step)
	_cam.global_position = _eye
	var at := Vector4(-14.0, 0.0, -18.0, 0.0)
	var dd: Vector4 = at - _eye
	_cam.global_basis = Basis4D.from_zx(atan2(-dd.x, -dd.z)) * Basis4D.from_yz(atan2(dd.y, Vector2(dd.x, dd.z).length()))
