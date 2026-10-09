extends SceneTree
## Slide I's see-through pane, drawn from its four projected corners (theatre_pane_4d's
## homography), against every grid point put through the camera the old way: the largest
## difference, in pixels, while the shot moves. Then a frame of the ball in the sheet.
##
## Windowed. Writes res://smoke_test_output/theatre_perf/pane_ball.png.

var _root: Node
var _show: Node
var _seat: Node
var _pane: Node
var _player: CharacterBody4D
var _f := 0
var _worst := 0.0
var _checked := 0
var _saved := false


func _initialize() -> void:
	root.unfocusable = true
	_root = load("res://ramon/chickenpen/theatre/theatre.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root


func _process(_d) -> bool:
	_f += 1
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _f == 1:
		_show = _root.get_node("Show")
		_seat = _root.get_node("UI/Seat")
		_pane = _root.get_node("UI/Pane")
		_player = _root.get_node("Player") as CharacterBody4D
		_show.set("opening_seconds", 2.0)
		_show.set("after_sit_seconds", 0.3)
		_show.set("hold_on_seat_seconds", 0.3)
		_seat.set("sit_seconds", 0.3)
		return false
	if _f == 3:
		var stage: Node4D = _root.get_node("Stage") as Node4D
		var top: Vector4 = stage.get("aisle_to")
		var foot: Vector4 = stage.get("aisle_from")
		_player.set_physics_process(false)
		_player.global_position = Vector4(0.0, lerpf(top.y, foot.y, 0.5) + 0.18, lerpf(top.z, foot.z, 0.5), 0.0)
		return false
	if _f > 8000:
		print("PANE FAIL: never reached the ball")
		quit(1)
		return true
	if bool(_seat.call("is_offering")) and not bool(_seat.call("is_seated")):
		_seat.call("sit")
	if int(_show.call("current_act")) != 0 or not bool(_pane.call("is_showing")):
		return false
	_compare()
	var tau: float = float(_show.get("_phase")) / float(_show.call("_length", 0))
	if tau > 0.27 and not _saved:
		_saved = true
		var path := "res://smoke_test_output/theatre_perf/pane_ball.png"
		root.get_texture().get_image().save_png(path)
		print("saved %s" % path.get_file())
	if tau > 0.3:
		print("pane: %d frames compared, worst difference %.3f px %s" % [_checked, _worst,
			"PASS" if _worst < 1.0 else "FAIL"])
		quit()
		return true
	return false


func _compare() -> void:
	var eye: Camera4D = _pane.call("_live")
	var piece: Node4D = _pane.get("_piece")
	var rect: Rect2 = _pane.get("_rect")
	var cells: Vector2i = _pane.get("cells")
	if eye == null or piece == null:
		return
	var at := func(u: float, v: float) -> Vector2:
		return eye.world_to_viewport(piece.global_position + piece.global_basis * Vector4(
			rect.position.x + u * rect.size.x, rect.position.y + v * rect.size.y, 0.0, 0.0))
	var quad := PackedVector2Array([at.call(0.0, 0.0), at.call(1.0, 0.0), at.call(1.0, 1.0), at.call(0.0, 1.0)])
	var h: PackedFloat32Array = _pane.call("_square_to_quad", quad)
	for j in cells.y + 1:
		for i in cells.x + 1:
			var u: float = float(i) / float(cells.x)
			var v: float = float(j) / float(cells.y)
			var mapped: Vector2 = _pane.call("_map", h, u, v)
			_worst = maxf(_worst, mapped.distance_to(at.call(u, v)))
	_checked += 1
