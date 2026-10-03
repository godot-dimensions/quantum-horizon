extends SceneTree

## Close-ups of the back and front of the player's head and the keeper's, so the block
## that should not be there can be identified rather than guessed at.
##
## ITS OWN CAMERA, because pen_orbit_rig_4d drives the scene's camera every frame and
## quietly puts it back five metres behind the player - the first go at this produced
## four identical wide shots of the whole farm.

var _root: Node
var _f := 0
var _shot := 0
var _cam: Camera4D

func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root); current_scene = _root

func _process(_d) -> bool:
	_f += 1
	if _f < 5: return false
	if _cam == null:
		_root.get_node("Systems/SliceAssist").set_process(false)
		_root.get_node("Player/CameraRig").set_process(false)
		_root.get_node("Player/CameraRig").set_physics_process(false)
		_root.get_node("Systems/Debug").set("enabled", false)
		(_root.get_node("UI") as Node4D).visible = false
		_cam = Camera4D.new()
		_cam.name = "HeadCam"
		# The scene's own settings. A fresh Camera4D defaults to the WIREFRAME renderer,
		# which is why the first attempt at this produced a scene made of coloured lines.
		_cam.rendering_engine_name = "Cross-section"
		_cam.w_fade_distance = 6.0
		_root.add_child(_cam)
		_cam.current = true
		# Nobody walks off during the shoot.
		_root.get_node("Player").set_physics_process(false)
	var p: Node4D = _root.get_node("Player")
	var keeper: Node4D = _root.get_node("World/Keeper")
	var target: Node4D = p if _shot < 2 else keeper
	var behind: bool = (_shot % 2) == 0
	# The chibi head sits about 1.26 up. Close, and slightly above, so the crown shows.
	# Whole figure, not just the head, so the legs are in frame too.
	# ALONG THE FIGURE'S OWN FORWARD, not along world Z. The keeper is turned about forty
	# degrees, so a camera parked on the world axis photographs its ear and calls it a
	# face. +Z is forward for this build: the hair is at -Z and the feet point at +Z.
	var head: Vector4 = target.global_position + Vector4(0.0, 1.22, 0.0, 0.0)
	var fwd: Vector4 = (target.global_basis * Vector4(0.0, 0.0, 1.0, 0.0)).normalized()
	var eye: Vector4 = head + fwd * (-0.85 if behind else 0.85) + Vector4(0.0, 0.10, 0.0, 0.0)
	_cam.global_position = eye
	_cam.global_basis = Basis4D.looking_at(head - eye)
	if _f < 40 + _shot * 30: return false
	var who: String = "player" if _shot < 2 else "keeper"
	root.get_texture().get_image().save_png("res://smoke_test_output/head_%s_%s.png"
		% [who, "back" if behind else "front"])
	print("SAVED head_%s_%s at %v" % [who, "back" if behind else "front", eye])
	_shot += 1
	return _shot > 3
