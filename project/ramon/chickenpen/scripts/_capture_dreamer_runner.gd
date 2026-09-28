extends SceneTree

## Pictures of the dreamer in the far room (cave_dreamer_4d.gd), to look at: calm, warning,
## and with the slice turned through W. The HUD is hidden and the player stood to one side,
## so the creature has the frame. Windowed.
##
## Args (after --): tag=<name>   writes res://smoke_test_output/dreamer_<tag>_<n>.png

var _room: Node
var _cave: Node4D
var _f := 0
var _t := 0.0
var _step := 0
var _tag := "look"


func _initialize() -> void:
	# Never takes the keyboard: typing elsewhere while this window is up must not reach
	# the pen (C opens the theatre, E and Q step through W).
	root.unfocusable = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tag="):
			_tag = a.substr(4)
	_room = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_room)
	current_scene = _room


func _hide_hud(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = false
		_hide_hud(child)


func _stand() -> void:
	var p := _room.get_node("Player") as CharacterBody4D
	p.global_position = _cave.global_position + Vector4(2.0, 0.05, -21.0, 46.0)
	p.linear_velocity = Vector4.ZERO
	var rig := p.get_node("CameraRig") as Node4D
	var d: Vector4 = _cave.global_position + Vector4(0, 10.5, -36, 46) - p.global_position
	rig.set("yaw", atan2(-d.x, -d.z))
	rig.set("pitch", deg_to_rad(14.0))
	rig.set("distance", 3.0)
	rig.call("_apply")


func _dreamer() -> Node:
	var far: Node = _cave.find_child("FarRoom", true, false)
	return far.get_node_or_null("Dreamer") if far != null else null


func _save(n: int) -> void:
	var path: String = "res://smoke_test_output/dreamer_%s_%d.png" % [_tag, n]
	root.get_texture().get_image().save_png(path)
	print("   saved %s" % path.get_file())


func _process(d: float) -> bool:
	_f += 1
	if _f == 10:
		_room.get_node("CaveCrossing").call("go")
	if _f == 14:
		for c in _room.get_children():
			if c.name == "Cave":
				_cave = c
		_hide_hud(_room.get_node("UI"))
		_room.get_node("Player").set("visible", false)
	if _f < 20 or _cave == null:
		return false
	_t += d
	_stand()
	var rig := _room.get_node("Player/CameraRig") as Node4D
	match _step:
		0:
			if _dreamer() != null and _t > 2.5:
				_save(0)
				_dreamer().call("set_mood", "warn")
				_step = 1; _t = 0.0
		1:
			if _t > 1.5:
				_save(1)
				_dreamer().call("set_mood", "calm")
				rig.set("_slice_xw", deg_to_rad(30.0))
				_step = 2; _t = 0.0
		2:
			rig.set("_slice_xw", deg_to_rad(30.0))
			if _t > 1.5:
				_save(2)
				quit()
				return true
	if _f > 4000:
		quit()
		return true
	return false
