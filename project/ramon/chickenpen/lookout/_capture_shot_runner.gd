extends SceneTree

## One still of the Lookout scene from wherever you say, relative to the tower, with the HUD
## hidden: for checking a piece of the build by eye.
##
##   godot... --path project --windowed --resolution 1280x720 --position 40,40
##       --script res://ramon/chickenpen/lookout/_capture_shot_runner.gd -- eye=8,4,10,0 at=0,9,0,0 name=under_deck

var _room: Node
var _t: float = 0.0
var _eye := Vector4(8.0, 4.0, 10.0, 0.0)
var _at := Vector4(0.0, 9.0, 0.0, 0.0)
var _name: String = "shot"


func _vec(text: String) -> Vector4:
	var p: PackedStringArray = text.split(",")
	return Vector4(float(p[0]), float(p[1]), float(p[2]), float(p[3]) if p.size() > 3 else 0.0)


func _initialize() -> void:
	root.unfocusable = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("eye="):
			_eye = _vec(arg.substr(4))
		elif arg.begins_with("at="):
			_at = _vec(arg.substr(3))
		elif arg.begins_with("name="):
			_name = arg.substr(5)
	_room = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	_room.get_node("Systems/Lookout").set("journal_path", "user://lookout_journal_shot_test.cfg")
	root.add_child(_room)
	current_scene = _room


var _frames: int = -1


func _process(d: float) -> bool:
	_t += d
	if _t < 3.0:
		return false
	if _frames < 0:
		for child in _room.get_node("UI").get_children():
			if child is CanvasItem:
				(child as CanvasItem).visible = false
		var tower: Node4D = _room.get_node("World/LookoutSite/Lookout")
		var cam := Camera4D.new()
		cam.set("rendering_engine_name", "Cross-section")
		cam.set("field_of_view_4d", 1.0)
		_room.add_child(cam)
		cam.make_current()
		var eye: Vector4 = tower.global_position + _eye
		var dv: Vector4 = tower.global_position + _at - eye
		cam.global_position = eye
		cam.global_basis = Basis4D.from_zx(atan2(-dv.x, -dv.z)) * Basis4D.from_yz(atan2(dv.y, Vector2(dv.x, dv.z).length()))
		_frames = 0
		return false
	_frames += 1
	if _frames < 4:
		return false
	root.get_texture().get_image().save_png("res://smoke_test_output/shot_%s.png" % _name)
	print("SHOT %s" % _name)
	return true
