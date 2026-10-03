extends SceneTree

## The black cat walking, seen side-on with the HUD hidden - Ramon, 30 Sept: "the cat looks
## weird when it walks in the pen. like it has 8 legs, or something is very off."
##
## Saves res://smoke_test_output/catwalk_<n>.png: one standing still, then a burst through
## a stride. And prints what strider_walker.gd did with the hide when it cut it into rigid
## pieces - how many tetrahedra each piece got, and for every leg how many of the vertices
## it claimed lie on the OTHER side of the body or up in the body - so a leg stealing its
## neighbour's skin, or the body keeping a still copy of a leg, shows up as a number.
##
##   godot... --path project --windowed --resolution 1280x720 --position 40,40
##       --script res://ramon/chickenpen/scripts/_capture_cat_walk_runner.gd

var _root: Node
var _cat: Node4D
var _camera: Camera4D
var _f := 0
var _t := 0.0
var _step := 0
var _n := 0
var _pending := ""


func _initialize() -> void:
	root.unfocusable = true
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root


func _frame(view: String = "side") -> void:
	# Its own camera, following the cat: the player's third-person rig put the avatar
	# between the lens and a small black animal on dark grass.
	if _camera == null:
		_camera = Camera4D.new()
		_camera.name = "CatCamera"
		_camera.rendering_engine_name = "Cross-section"
		_root.add_child(_camera)
	var at: Vector4 = _cat.global_position
	var side: Vector4 = (_cat.global_basis * Vector4(1, 0, 0, 0)).normalized()
	var ahead: Vector4 = (_cat.global_basis * Vector4(0, 0, 1, 0)).normalized()
	match view:
		"face":
			# Close on the head, from in front and a little to one side.
			var head: Vector4 = at + ahead * 0.47 + Vector4(0, 0.44, 0, 0)
			_camera.global_position = head + ahead * 0.55 + side * 0.28 + Vector4(0, 0.06, 0, 0)
			_camera.look_at(head)
		"three_quarter":
			_camera.global_position = at + ahead * 1.0 + side * 0.75 + Vector4(0, 0.45, 0, 0)
			_camera.look_at(at + Vector4(0, 0.3, 0, 0))
		_:
			_camera.global_position = at + side * 1.1 + Vector4(0, 0.32, 0, 0)
			_camera.look_at(at + Vector4(0, 0.2, 0, 0))
	_camera.make_current()


## Every animal the strider walker drives, not only the cat - the fix changes how all of
## them bind, so Nike and the red cat are reported too.
func _report_all() -> void:
	for walker in _root.get_node("World").find_children("Walker", "", true, false):
		if walker.get("_pieces") == null or (walker.get("_pieces") as Array).is_empty():
			print(" %s: not bound yet (asleep or never walked)" % walker.get_parent().name)
			continue
		print(" %s:" % walker.get_parent().name)
		_report(walker)


func _report(walker: Node) -> void:
	var hide: Node = walker.get_parent().get_node("Hide")
	var pieces: Array = walker.get("_pieces")
	for piece in pieces:
		var mesh: ArrayTetraMesh4D = (piece as MeshInstance4D).mesh as ArrayTetraMesh4D
		print("  piece %-12s %5d tetrahedra" % [piece.name, mesh.simplex_cell_vertex_indices.size() / 4 if mesh != null else 0])
	var legs: Array = walker.get("_legs")
	var rest: PackedVector4Array = walker.get("_rest_verts")
	var index: PackedInt32Array = walker.get("_skin_index")
	var owner_leg: Array = walker.get("_skin_leg")
	for l in legs.size():
		var leg: Dictionary = legs[l]
		var hip: Vector4 = leg["hip_world"]
		var total := 0
		var wrong_side := 0
		var above_hip := 0
		var midline := 0
		for k in index.size():
			if int(owner_leg[k]) != l:
				continue
			var v: Vector4 = rest[index[k]]
			total += 1
			if absf(v.x) > 0.01 and signf(v.x) != signf(hip.x):
				wrong_side += 1
			if v.y > hip.y:
				above_hip += 1
			# No leg's skin reaches the body's centre line: anything claimed there is belly.
			if absf(v.x) < 0.012:
				midline += 1
		print("  leg %d  %-10s hip (%.3f, %.3f, %.3f)  claims %4d vertices, %4d on the other side, %4d above the hip, %4d on the midline" % [
			l, String(leg["hip"].name), hip.x, hip.y, hip.z, total, wrong_side, above_hip, midline])
	print("  hide children: %s" % [hide.get_children().map(func(c): return String(c.name))])


func _process(d: float) -> bool:
	_f += 1
	if _pending != "":
		root.get_texture().get_image().save_png("res://smoke_test_output/catwalk_%d_%s.png" % [_n, _pending])
		print("   saved catwalk_%d_%s.png" % [_n, _pending])
		_n += 1
		_pending = ""
		return false
	if _f < 60:
		return false
	_t += d
	match _step:
		0:
			_cat = _root.get_node("World/Cat") as Node4D
			# UI is a Node4D, and 2D children do not inherit a Node4D's visibility.
			for child in _root.get_node("UI").get_children():
				if child is CanvasItem or child is CanvasLayer:
					child.set("visible", false)
			_step = 1; _t = 0.0
		1:
			# Where the game starts it: sat on its crate.
			_frame("three_quarter")
			if _t > 1.0:
				_pending = "crate"
				_step = 2; _t = 0.0
		2:
			# Off the crate and onto open ground, walking, and staying that way.
			_cat.position = Vector4(-4.0, 0.0, 4.0, 0.0)
			_cat.set("_mood", 0)
			_cat.set("_mood_left", 999.0)
			_cat.set("roam_radius", 50.0)
			_cat.set("_home", _cat.position)
			_step = 3; _t = 0.0
		3:
			_frame()
			if _t > 2.5:
				_report_all()
				_step = 4; _t = 0.0
		4:
			_frame()
			# A burst through about one stride.
			if _t > 0.12:
				_pending = "walk"
				_t = 0.0
				if _n >= 6:
					_step = 5
		5:
			_frame("three_quarter")
			if _t > 0.4:
				_pending = "walk_front"
				_step = 6; _t = 0.0
		6:
			_frame("face")
			if _t > 0.4:
				_pending = "face"
				_step = 7; _t = 0.0
		7:
			if _t > 0.3:
				print("CAT WALK: done")
				quit()
				return true
	return false
