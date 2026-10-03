extends SceneTree

## Nike mid-stride, side-on and close, HUD off: the frames to look at when her legs look
## wrong. She is sent to eat at a point along +x and filmed from the side by a camera that
## keeps pace with her. Windowed (the headless renderer draws nothing).
##
## Args (after --): tag=<name>  writes res://smoke_test_output/nike_<tag>_<n>.png
##                  dist=<m>    how far off to the side (default 5)
##                  still=1     leave her standing, to tell a walking fault from a modelling one

var _room: Node
var _nike: Node4D
var _cam: Camera4D
var _f := 0
var _n := 0
var _tag := "now"
var _dist := 5.0
var _still := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tag="):
			_tag = a.substr(4)
		elif a.begins_with("dist="):
			_dist = float(a.substr(5))
		elif a == "still=1":
			_still = true
	_room = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_room)
	current_scene = _room


func _process(_d: float) -> bool:
	_f += 1
	if _f == 15:
		_hide_hud(_room.get_node("UI"))
		_nike = _room.get_node("World/Nike")
		_cam = Camera4D.new()
		_cam.set("rendering_engine_name", "Cross-section")
		_room.add_child(_cam)
		_cam.current = true
		# Somewhere clear to walk to, and the pen's own feeding logic takes her there.
		if _still:
			_nike.get_node("Antics").set("suspended", true)
		else:
			_nike.get_node("Antics").call("go_and_eat", _nike.global_position + Vector4(8.0, 0.0, 0.0, 0.0))
	if _f < 15:
		return false
	# Side-on: to her -z, level with her knees, looking straight across.
	var at: Vector4 = _nike.global_position
	_cam.global_position = at + Vector4(0.0, 0.6, _dist, 0.0)
	_cam.global_basis = Basis4D.from_yz(-0.08)
	if _f > 90 and (_f - 90) % 9 == 0:
		var path: String = "res://smoke_test_output/nike_%s_%d.png" % [_tag, _n]
		root.get_texture().get_image().save_png(path)
		print("   saved %s   at %s" % [path.get_file(), at])
		_n += 1
		if _n >= 8:
			quit()
			return true
	return false


func _hide_hud(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = false
		_hide_hud(child)
