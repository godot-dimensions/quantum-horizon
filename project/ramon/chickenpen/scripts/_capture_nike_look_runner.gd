extends SceneTree

## Nike from all round, standing and then walking, HUD off - Ramon, 30 Sept: "nikepig has
## some weird small errors aestetically with some little mesh bits going through surfaces
## here and there." Saves res://smoke_test_output/nikelook_<n>_<view>.png and prints every
## mesh under her - which rig or piece it is, whether it is drawn, and how big - so a stray
## bit in a frame can be traced to the part it came from.
##
##   godot... --path project --windowed --resolution 1280x720 --position 40,40
##       --script res://ramon/chickenpen/scripts/_capture_nike_look_runner.gd

const VIEWS := ["front_left", "side", "rear_right", "head", "hind_legs", "above"]

var _room: Node
var _nike: Node4D
var _cam: Camera4D
var _f := 0
var _t := 0.0
var _step := 0
var _view := 0
var _n := 0
var _pending := ""


func _initialize() -> void:
	root.unfocusable = true
	_room = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_room)
	current_scene = _room


func _hide_hud(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = false
		_hide_hud(child)


func _aim(view: String) -> void:
	var at: Vector4 = _nike.global_position
	var ahead: Vector4 = (_nike.global_basis * Vector4(0, 0, 1, 0)).normalized()
	var side: Vector4 = (_nike.global_basis * Vector4(1, 0, 0, 0)).normalized()
	var up := Vector4(0, 1, 0, 0)
	var middle: Vector4 = at + up * 0.75
	match view:
		"front_left":
			_cam.global_position = middle + ahead * 3.0 + side * 2.2 + up * 0.5
			_cam.look_at(middle)
		"side":
			_cam.global_position = middle + side * 3.4 + up * 0.2
			_cam.look_at(middle)
		"rear_right":
			_cam.global_position = middle - ahead * 3.0 - side * 2.2 + up * 0.6
			_cam.look_at(middle)
		"head":
			var head: Vector4 = at + ahead * 1.45 + up * 0.62
			_cam.global_position = head + ahead * 1.3 + side * 0.7 + up * 0.25
			_cam.look_at(head)
		"hind_legs":
			var hind: Vector4 = at - ahead * 0.5 + up * 0.35
			_cam.global_position = hind + side * 1.6 - ahead * 0.9 + up * 0.1
			_cam.look_at(hind)
		"above":
			_cam.global_position = middle + up * 3.0 + side * 1.2 + ahead * 0.6
			_cam.look_at(middle)
	_cam.make_current()


func _report() -> void:
	print("NIKE meshes:")
	for mesh_node in _nike.find_children("*", "MeshInstance4D", true, false):
		var m: MeshInstance4D = mesh_node
		var tets: int = 0
		if m.mesh is ArrayTetraMesh4D:
			tets = (m.mesh as ArrayTetraMesh4D).simplex_cell_vertex_indices.size() / 4
		elif m.mesh != null:
			tets = -1
		if tets == 0:
			continue
		print("  %-40s drawn %-5s tetrahedra %d" % [_nike.get_path_to(m), m.is_visible_in_tree(), tets])


func _process(d: float) -> bool:
	_f += 1
	if _pending != "":
		root.get_texture().get_image().save_png("res://smoke_test_output/nikelook_%d_%s.png" % [_n, _pending])
		print("   saved nikelook_%d_%s.png" % [_n, _pending])
		_n += 1
		_pending = ""
		return false
	if _f < 20:
		return false
	_t += d
	match _step:
		0:
			_hide_hud(_room.get_node("UI"))
			_nike = _room.get_node("World/Nike")
			_cam = Camera4D.new()
			_cam.name = "NikeCamera"
			_cam.set("rendering_engine_name", "Cross-section")
			_room.add_child(_cam)
			_nike.get_node("Antics").set("suspended", true)
			_step = 1; _t = 0.0
		1:
			# Standing: every view once.
			_aim(VIEWS[_view])
			if _t > 0.5:
				_pending = "still_" + VIEWS[_view]
				_view += 1
				_t = 0.0
				if _view >= VIEWS.size():
					_nike.get_node("Antics").set("suspended", false)
					_nike.get_node("Antics").call("go_and_eat", _nike.global_position + Vector4(12.0, 0.0, 0.0, 0.0))
					_view = 0
					_step = 2
		2:
			_aim("side")
			if _t > 2.0:
				_report()
				_step = 3; _t = 0.0
		3:
			# Walking: the views where legs and body meet.
			var walk_views := ["side", "front_left", "hind_legs", "rear_right"]
			_aim(walk_views[_view])
			if _t > 0.35:
				_pending = "walk_" + walk_views[_view]
				_view += 1
				_t = 0.0
				if _view >= walk_views.size():
					_step = 4
		4:
			if _t > 0.3:
				print("NIKE LOOK: done")
				quit()
				return true
	return false
