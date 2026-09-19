extends SceneTree
## Same view twice: as the camera is set up, then with the 4D fades turned off. If the
## haze is the camera's W fade and edge falloff, the second shot is clear.
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
	var p: CharacterBody4D = _root.get_node("Player")
	var eye := Vector4(4.0, 3.2, 16.0, 0.0)
	p.global_position = eye
	p.global_basis = Basis4D.looking_at(Vector4(-6.0, 1.0, -6.0, 0.0) - eye)
	p.linear_velocity = Vector4.ZERO
	if _shot == 1 and _cam:
		_cam.w_fade_mode = 0
		_cam.edge_falloff = 1.0
	if _f < 60 + _shot * 60: return false
	root.get_texture().get_image().save_png("res://smoke_test_output/fog_%d.png" % _shot)
	print("SAVED fog_%d" % _shot)
	_shot += 1
	return _shot > 1
