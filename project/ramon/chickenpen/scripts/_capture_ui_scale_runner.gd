extends SceneTree

## The pen's interface at a given size (pen_ui_scale_4d.gd), to look at: from the spawn
## point with the belt, checklist and dial up; beside the professor with his tag; in
## conversation with him; and at the range's counter. Windowed.
##
## Args (after --): tag=<name>   writes res://smoke_test_output/ui_<tag>_<n>.png
##                  scale=<f>    UiScale's ui_scale; 1 is the interface as it was. Run it
##                               at the size you want to judge - the scale follows the
##                               window's height and is never below 1.

var _room: Node
var _f := 0
var _tag := "now"
var _scale := 1.3
var _n := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tag="):
			_tag = a.substr(4)
		elif a.begins_with("scale="):
			_scale = float(a.substr(6))
	_room = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_room)
	current_scene = _room


func _player() -> CharacterBody4D:
	return _room.get_node("Player") as CharacterBody4D


func _hold(at: Vector4) -> void:
	_player().global_position = at
	_player().linear_velocity = Vector4.ZERO


func _face(at: Vector4) -> void:
	var rig := _player().get_node("CameraRig") as Node4D
	var d: Vector4 = at - _player().global_position
	rig.set("yaw", atan2(-d.x, -d.z))
	rig.call("_apply")


func _save() -> void:
	var path: String = "res://smoke_test_output/ui_%s_%d.png" % [_tag, _n]
	root.get_texture().get_image().save_png(path)
	print("   saved %s   (content scale %.2f)" % [path.get_file(), root.content_scale_factor])
	_n += 1


func _process(_d: float) -> bool:
	_f += 1
	if _f == 5:
		_room.get_node("Systems/UiScale").set("ui_scale", _scale)
	var prof: Node4D = _room.get_node("World/Professor") as Node4D
	var booth: Node4D = _room.get_node("World/RangeBooth") as Node4D
	if _f < 60:
		return false
	if _f < 120:
		if _f == 110:
			_save()
		return false
	if _f < 200:
		_hold(prof.global_position + Vector4(0.0, 0.0, 2.2, 0.0))
		_face(prof.global_position)
		if _f == 190:
			_save()
		return false
	if _f == 200:
		var press := InputEventAction.new()
		press.action = &"catch_target"
		press.pressed = true
		Input.parse_input_event(press)
	if _f < 330:
		if _f == 320:
			_save()
		return false
	if _f == 330:
		# Out of the conversation, over to the range.
		var esc := InputEventKey.new()
		esc.keycode = KEY_ESCAPE
		esc.physical_keycode = KEY_ESCAPE
		esc.pressed = true
		Input.parse_input_event(esc)
	if _f < 460:
		_hold(booth.global_position + booth.global_basis * Vector4(-1.0, 0.0, 0.0, 0.0))
		_face(booth.global_position + booth.global_basis * Vector4(-12.0, 1.5, 0.0, 0.0))
		if _f == 450:
			_save()
		return false
	quit()
	return true
