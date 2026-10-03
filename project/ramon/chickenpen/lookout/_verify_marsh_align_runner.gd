extends SceneTree

## V at the marsh aligns you to its slice: the player stood by the marsh a little off its w with
## the slice turned (the marsh cut to a sliver), the prompt offered, V pressed, then the slice
## flat and the player at the marsh's w, the prompt gone. Frames before and after; also the
## ground's lighter test colour and the pen's own. Saves res://smoke_test_output/marsh_align_<n>.png.
##
##   godot... --path project --windowed --resolution 1280x720 --position 40,40
##       --script res://ramon/chickenpen/lookout/_verify_marsh_align_runner.gd

var _room: Node
var _grass: Node
var _lookout: Node
var _rig: Node
var _player: Node4D
var _t: float = 0.0
var _step: int = -1
var _fails: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_room = load("res://ramon/chickenpen/chickenpen_lookout.tscn").instantiate()
	_room.get_node("Systems/Lookout").set("journal_path", "user://lookout_journal_marsh_align_test.cfg")
	_grass = _room.get_node("World/Grass")
	root.add_child(_room)
	current_scene = _room


func _check(what: String, ok: bool) -> void:
	if not ok:
		_fails += 1
	print("      %-44s %s" % [what, "ok" if ok else "FAIL"])


func _process(d: float) -> bool:
	_t += d
	match _step:
		-1:
			if not bool(_grass.get("mask_ready")) or _t < 5.0:
				return false
			_lookout = _room.get_node("Systems/Lookout")
			for f in ["approached", "met_wren"]:
				_lookout.get("journal").call("set_flag", f, true)
			_player = _room.get_node("Player") as Node4D
			_rig = _room.get_node("Player/CameraRig")
			var marsh: Node4D = _lookout.get("marsh")
			# Beside the pond, 0.9 off its w, the slice turned a little through W.
			_player.global_position = marsh.global_position + Vector4(9.0, 0.05, 6.0, -0.9)
			_rig.set("yaw", atan2(9.0, 6.0))
			_rig.set("_slice_xw", 0.35)
			_step = 0
			_t = 0.0
		0:
			if _t < 1.5:
				return false
			_check("prompt offered by the marsh", bool(_lookout.call("can_align")))
			_check("card shown at the marsh", bool(_room.get_node("UI/Journal").call("at_lookout")))
			root.get_texture().get_image().save_png("res://smoke_test_output/marsh_align_0_before.png")
			var e := InputEventKey.new()
			e.keycode = KEY_V
			e.physical_keycode = KEY_V
			e.pressed = true
			Input.parse_input_event(e)
			var up: InputEventKey = e.duplicate()
			up.pressed = false
			Input.parse_input_event(up)
			_step = 1
			_t = 0.0
		1:
			if _t < 1.5:
				return false
			var marsh_w: float = (_lookout.get("marsh") as Node4D).global_position.w
			_check("player at the marsh's w (%.3f, want %.1f)" % [_player.global_position.w, marsh_w], absf(_player.global_position.w - marsh_w) < 0.05)
			_check("slice flat", bool(_rig.call("is_aligned_to", marsh_w)))
			_check("prompt gone once aligned", not bool(_lookout.call("can_align")))
			root.get_texture().get_image().save_png("res://smoke_test_output/marsh_align_1_after.png")
			# The ground: back at the pen, the lighter test colour, then the pen's own.
			_player.global_position = Vector4(4.0, 0.05, 6.0, 0.0)
			_rig.call("go_home")
			_step = 2
			_t = 0.0
		2:
			if _t < 1.5:
				return false
			var mat: Resource = (_room.get_node("World/Ground/GroundMesh") as MeshInstance4D).material_override
			_check("ground lighter while the test is on", (mat.get("albedo_color") as Color).is_equal_approx(_grass.get("lighter_ground_colour")))
			root.get_texture().get_image().save_png("res://smoke_test_output/marsh_align_2_ground_lighter.png")
			_grass.set("lighter_ground", false)
			_step = 3
			_t = 0.0
		3:
			if _t < 0.8:
				return false
			var mat: Resource = (_room.get_node("World/Ground/GroundMesh") as MeshInstance4D).material_override
			_check("ground back to the pen's own", (mat.get("albedo_color") as Color).is_equal_approx(Color(0.16, 0.22, 0.11, 1.0)))
			root.get_texture().get_image().save_png("res://smoke_test_output/marsh_align_3_ground_own.png")
			print("MARSH ALIGN %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
			if FileAccess.file_exists("user://lookout_journal_marsh_align_test.cfg"):
				DirAccess.remove_absolute(ProjectSettings.globalize_path("user://lookout_journal_marsh_align_test.cfg"))
			return true
	return false
