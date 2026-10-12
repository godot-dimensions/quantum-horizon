extends SceneTree
## The brachiosaurus whole, and its head close up.
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
	var head := Vector4(-24.0, 39.1, 4.5, 0.0)
	var body := Vector4(-24.0, 16.0, -12.0, 0.0)
	# Shot 1 is now the FEET, low and close, to settle whether it stands on the ground.
	var feet := Vector4(-24.0, 1.2, -12.0, 0.0)
	var eye: Vector4 = (body + Vector4(34.0, 14.0, 46.0, 0.0)) if _shot == 0 else (feet + Vector4(9.0, 1.2, 13.0, 0.0))
	var look: Vector4 = body if _shot == 0 else feet
	p.global_position = eye
	p.global_basis = Basis4D.looking_at(look - eye)
	p.linear_velocity = Vector4.ZERO
	if _f < 60 + _shot * 60: return false
	root.get_texture().get_image().save_png("res://smoke_test_output/brachio_%d.png" % _shot)
	print("SAVED brachio_%d" % _shot)
	_shot += 1
	return _shot > 1
