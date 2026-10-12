extends SceneTree
## Trym's creature and the chicken side by side, to check the chicken arrived intact
## and is standing on the ground rather than floating or buried.
var _root: Node
var _player: CharacterBody4D
var _f := 0
func _initialize() -> void:
	_root = load("res://ramon/Model/rigged_creature_ramon.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f == 1:
		_player = _root.get_node("Player"); return false
	var eye := Vector4(-0.9, 1.1, 7.6, 0.0)
	_player.global_position = eye
	_player.global_basis = Basis4D.looking_at(Vector4(-2.2, 0.9, 5.5, 0.0) - eye)
	_player.linear_velocity = Vector4.ZERO
	if _f < 95: return false
	var img: Image = root.get_texture().get_image()
	if img != null:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://smoke_test_output/"))
		img.save_png("res://smoke_test_output/chicken_walk.png")
		print("SAVED chicken_walk")
	return true
