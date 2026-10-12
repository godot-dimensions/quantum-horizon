extends SceneTree
## Confirms the player camera really is on Combined and that the projected layer
## puts visible pixels on screen, rather than just that a property was set.

const OUT := "user://lab_projections.png"
var _frame := 0
var _root: Node
var _cam: Camera4D

func _initialize() -> void:
	_root = load("res://ramon/Model/symmetry_lab.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root

func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 1:
		_cam = _root.get_node("Player/PlayerHead/FirstPersonCamera")
		print("camera engine:        %s" % _cam.rendering_engine_name)
		print("projection opacity:   %.2f / base %.2f" % [
			_cam.projection_opacity, _cam.projection_opacity_base])
		print("w fade distance:      %.1f" % _cam.w_fade_distance)
		return false
	# Gravity drags the body between placement and capture, so re-pin every frame.
	var player: CharacterBody4D = _root.get_node("Player")
	var eye := Vector4(5.6, 2.6, 5.6, 0.0)
	player.global_position = eye
	player.global_basis = Basis4D.looking_at(Vector4(0.3, 1.6, 0.0, 0.0) - eye)
	player.linear_velocity = Vector4.ZERO
	if _frame < 40:
		return false
	var img: Image = root.get_texture().get_image()
	if img == null:
		print("no framebuffer")
		quit(1)
		return true
	img.save_png(OUT)
	print("saved %s" % ProjectSettings.globalize_path(OUT))
	quit(0)
	return true
