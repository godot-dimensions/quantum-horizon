extends SceneTree
## Photographs the symmetry lab from the side and from above, so a Dihedral ring of
## limbs can actually be counted. Must run WINDOWED.
var _root: Node
var _player: CharacterBody4D
var _frame := 0
# The body runs along X, so a profile needs the camera out on Z - the first attempt
# sat on -X and was looking straight down the creature's length.
var _shots := [[60, Vector4(-1.5, 3.2, -8.5, 0.0), "ramon_side"],
			   [120, Vector4(-1.5, 11.0, 0.35, 0.0), "ramon_top"],
			   [180, Vector4(-1.5, 3.2, -6.0, 3.0), "ramon_w3"]]
var _next := 0
func _initialize() -> void:
	_root = load("res://ramon/Model/symmetry_lab_ramon.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root
func _process(_d) -> bool:
	_frame += 1
	if _frame == 1:
		_player = _root.get_node_or_null("Player")
		return false
	if _player == null:
		print("FAILED: no Player"); return true
	if _next < _shots.size():
		var eye: Vector4 = _shots[_next][1]
		_player.global_position = eye
		_player.global_basis = Basis4D.looking_at(Vector4(-1.5, 2.3, 0.0, 0.0) - eye)
		_player.linear_velocity = Vector4.ZERO
	if _next < _shots.size() and _frame == int(_shots[_next][0]):
		var img: Image = root.get_texture().get_image()
		if img != null:
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://smoke_test_output/"))
			img.save_png("res://smoke_test_output/%s.png" % _shots[_next][2])
			print("SAVED %s" % _shots[_next][2])
		_next += 1
	return _next >= _shots.size()
