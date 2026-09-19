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
	# Framed for the new scale: the birds are a quarter the size they were.
	var eye := Vector4(1.2, 1.1, 8.4, 0.0)
	p.global_position = eye
	p.global_basis = Basis4D.looking_at(Vector4(-8.0, 1.2, -4.0, 0.0) - eye)
	p.linear_velocity = Vector4.ZERO

	if _f < 60 + _shot * 60: return false
	root.get_texture().get_image().save_png("res://smoke_test_output/fog_%d.png" % _shot)
	print("SAVED fog_%d" % _shot)
	_shot += 1
	return _shot > 0
