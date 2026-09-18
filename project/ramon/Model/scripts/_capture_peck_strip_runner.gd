extends SceneTree
## A strip of frames through one peck, to actually LOOK at the motion rather than
## trusting the numbers. The camera rides alongside the bird, which is wandering.
var _root: Node
var _player: CharacterBody4D
var _chick: Node4D
var _walk: Node
var _f := 0
var _shot := 0
const _START := 60
const _EVERY := 11
const _SHOTS := 9
func _initialize() -> void:
	_root = load("res://ramon/Model/rigged_creature_ramon.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f == 1:
		_player = _root.get_node("Player")
		_chick = _root.get_node("Chicken")
		_walk = _root.get_node("Chicken/Walker")
		return false
	# Ride beside the bird, a little in front, at head height.
	var c: Vector4 = _chick.position
	# A true side-on view: the bird turns as it wanders, so the camera is placed off
	# its own right-hand axis rather than at a fixed world offset.
	var right: Vector4 = _chick.basis.x
	var eye := c + right * 2.6 + Vector4(0.0, 1.0, 0.0, 0.0)
	_player.global_position = eye
	_player.global_basis = Basis4D.looking_at(c + Vector4(0.0, 0.62, 0.0, 0.0) - eye)
	_player.linear_velocity = Vector4.ZERO
	if _f == _START:
		_walk._peck_countdown = 0.0   # start a peck now, do not wait for the dice
	if _f >= _START and (_f - _START) % _EVERY == 0 and _shot < _SHOTS:
		var img: Image = root.get_texture().get_image()
		if img != null:
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://smoke_test_output/"))
			img.save_png("res://smoke_test_output/peck_%d.png" % _shot)
			print("SAVED peck_%d at frame %d" % [_shot, _f])
		_shot += 1
	return _shot >= _SHOTS
