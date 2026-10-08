extends SceneTree
## Is there a sea running through the Arboretum's floor? Shot from the spawn corridor and
## from just outside the new door, which are the two places it has to be right.
const SHOTS := [
	# Looking back at the doorway from the pier: this is where the rail used to run across.
	["entry", Vector4(22.0, 1.6, 10.5, 0.0), Vector4(12.0, 1.2, 10.5, 0.0)],
	# On the ring, for the prompt. The player is moved there in _aim.
	["ring", Vector4(30.0, 2.2, 10.5, 0.0), Vector4(40.0, 0.6, 10.5, 0.0)],
]


var _root: Node = null
var _camera: Camera4D = null
var _frames := 0
var _shot := 0
var _held := 0
func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 1:
		_root = (load("res://ramon/Arboretum/arboretum.tscn") as PackedScene).instantiate()
		root.add_child(_root); current_scene = _root
		return false
	if _frames < 6:
		return false
	if _frames == 6:
		_camera = Camera4D.new()
		_camera.rendering_engine_name = "Cross-section"
		_root.add_child(_camera); _camera.current = true
		_aim()
		return false
	_held += 1
	if _held < 30:
		return false
	_held = 0
	root.get_texture().get_image().save_png("user://arb_%s.png" % SHOTS[_shot][0])
	print("  %s" % SHOTS[_shot][0])
	_shot += 1
	if _shot >= SHOTS.size():
		quit(0)
		return true
	_aim()
	return false
func _aim() -> void:
	# The prompt only appears when the PLAYER is on the ring, so put them there - a free
	# camera flying over it proves nothing about a trigger that reads the player.
	if SHOTS[_shot][0] == "ring":
		var player: Node4D = _root.get(&"player") as Node4D
		if player != null:
			player.global_position = Vector4(36.0, 0.05, 10.5, 0.0)
	var from: Vector4 = SHOTS[_shot][1]
	_camera.position = from
	_camera.basis = Basis4D.looking_at(SHOTS[_shot][2] - from)
