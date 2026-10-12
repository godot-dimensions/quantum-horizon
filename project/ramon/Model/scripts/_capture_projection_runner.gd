extends SceneTree
## Is the haze the camera's PROJECTION pass? Same view three ways, changed at runtime
## only - the scene file is not touched.
##   0: as authored (Combined: cross-section plus a faint projection)
##   1: projection opacity 0
##   2: projection back on, ground thinned through W
var _root: Node
var _f := 0
var _shot := 0
var _cam: Camera4D
func _initialize() -> void:
	_root = load("res://ramon/Model/rigged_creature_ramon.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f < 3: return false
	if _cam == null:
		var stack: Array = [_root]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			if n is Camera4D: _cam = n
			for c in n.get_children(): stack.append(c)
		print("camera engine=%s projection_opacity=%.3f base=%.3f skewness=%.2f" % [
			_cam.rendering_engine_name, _cam.projection_opacity, _cam.projection_opacity_base, _cam.skewness])
	var p: CharacterBody4D = _root.get_node("Player")
	var eye := Vector4(1.2, 1.1, 8.4, 0.0)
	p.global_position = eye
	p.global_basis = Basis4D.looking_at(Vector4(-8.0, 1.2, -4.0, 0.0) - eye)
	p.linear_velocity = Vector4.ZERO
	if _shot == 1:
		# Drop the projection PASS entirely rather than just making it invisible.
		_cam.rendering_engine_name = "Cross-section"
	elif _shot == 2:
		_cam.rendering_engine_name = "Combined"
	if _f < 40 + _shot * 40: return false
	root.get_texture().get_image().save_png("res://smoke_test_output/proj_%d.png" % _shot)
	var im: Image = root.get_texture().get_image()
	var vals := PackedStringArray()
	for y in range(120, 330, 30):
		var c: Color = im.get_pixel(950, y)
		vals.append("%d" % int((c.r + c.g + c.b) / 3.0 * 255.0))
	print("shot %d brightness down the sky at x=950: %s" % [_shot, ", ".join(vals)])
	_shot += 1
	return _shot > 2
