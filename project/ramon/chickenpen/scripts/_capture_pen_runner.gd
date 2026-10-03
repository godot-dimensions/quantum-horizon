extends SceneTree
var _root: Node
var _f := 0
var _shot := 0
func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f < 5: return false
	var p: CharacterBody4D = _root.get_node("Player")
	var eye := Vector4(0, 14, 10, 0) if _shot == 0 else Vector4(0, 2.2, 2.5, 0)
	var look := Vector4(0, 0, -8, 0) if _shot == 0 else Vector4(0, 0.6, -6, 0)
	p.global_position = eye
	p.global_basis = Basis4D.looking_at(look - eye)
	p.linear_velocity = Vector4.ZERO
	if _f < 70 + _shot * 45: return false
	root.get_texture().get_image().save_png("res://smoke_test_output/pen_%d.png" % _shot)
	print("SAVED pen_%d" % _shot)
	_shot += 1
	return _shot > 1
