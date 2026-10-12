extends SceneTree
## The flock, from a little above and behind, plus a close-up of one bird's legs.
var _root: Node
var _f := 0
var _shot := 0
func _initialize() -> void:
	_root = load("res://ramon/Model/rigged_creature_ramon.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f < 3: return false
	var p: CharacterBody4D = _root.get_node("Player")
	var c: Vector4 = (_root.get_node("Chicken") as Node4D).position
	if _shot == 0:
		var eye := Vector4(-2.2, 3.4, 11.0, 0.0)
		p.global_position = eye
		p.global_basis = Basis4D.looking_at(Vector4(-2.2, 0.6, 5.4, 0.0) - eye)
	else:
		var eye2 := c + Vector4(1.5, 0.55, 1.1, 0.0)
		p.global_position = eye2
		p.global_basis = Basis4D.looking_at(c + Vector4(0.0, 0.42, 0.0, 0.0) - eye2)
	p.linear_velocity = Vector4.ZERO
	if _f < 120 + _shot * 90: return false
	var img: Image = root.get_texture().get_image()
	img.save_png("res://smoke_test_output/flock_%d.png" % _shot)
	print("SAVED flock_%d" % _shot)
	_shot += 1
	return _shot > 1
