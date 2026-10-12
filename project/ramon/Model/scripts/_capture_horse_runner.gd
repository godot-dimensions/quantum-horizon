extends SceneTree
## Two frames of the horse, half a stride apart, to see whether skinning deforms it well.
var _root: Node
var _f := 0
var _shot := 0
func _initialize() -> void:
	_root = load("res://ramon/Model/animation_test.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f == 1 and OS.get_cmdline_user_args().has("rest"):
		# Rest pose: what the model looks like with nothing animating it.
		var stack: Array = [_root]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			if n.get_script() != null and n.name.findn("walk") >= 0: n.set_physics_process(false)
			for c in n.get_children(): stack.append(c)
	if _f < 3: return false
	var p := _root.get_node_or_null("Player") as CharacterBody4D
	if p:
		var eye := Vector4(9.0, 5.0, 11.0, 0.0)
		p.global_position = eye
		p.global_basis = Basis4D.looking_at(Vector4(0.0, 3.0, 0.0, 0.0) - eye)
		p.linear_velocity = Vector4.ZERO
	if _f < 90 + _shot * 45: return false
	root.get_texture().get_image().save_png("res://smoke_test_output/horse_%s%d.png" % ["rest_" if OS.get_cmdline_user_args().has("rest") else "", _shot])
	print("SAVED horse_%d" % ["rest_" if OS.get_cmdline_user_args().has("rest") else "", _shot])
	_shot += 1
	return _shot > 1
