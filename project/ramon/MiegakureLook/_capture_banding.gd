extends SceneTree

## Captures the three frames the October-gate deck needs for the "legibility
## responds to design" claim, from LEVEL 1 - the teaching level.
##
##   godot.windows.editor.double.x86_64.console.exe --path project \
##       --resolution 1920x1080 \
##       --script res://ramon/MiegakureLook/_capture_banding.gd
##
## MUST NOT be run with --headless: a headless run creates no rendering device,
## so root.get_texture() returns nothing and every shot is silently blank.
##
## The three frames, and why these three:
##
##   1  banded_before   Banded floor, before rotating. What the player arrives to:
##                      the yellow wall ahead, the yellow lane underfoot.
##   2  banded_after    Banded floor, after the 90 degree zw rotation. The lane
##                      is the way through, and it is visible.
##   3  plain_after     Same rotation, floor made uniform grey. This is what the
##                      level looked like BEFORE the banded floor existed, and it
##                      is the control: a bare diamond with nothing to navigate by.
##
## Frames 2 and 3 are the controlled pair - identical camera, identical rotation,
## one variable changed - so the HUD is hidden on both. Frame 1 keeps the HUD
## because it is there to show what the player actually sees.
##
## The uniform-grey pass is applied by walking the built panels rather than by
## editing the builder: floor panels are the ones `build_floor_band` places below
## y = 0, so `position.y < 0` separates them from walls, rails and the goal pad
## without needing to know their order.

const OUT_DIR := "D:/temp_docs/deck_shots/"
const TexGrey := preload("res://textures/dev_finals/ramdev_grey.png")
const SETTLE_SECONDS := 1.4
const ROTATION_TIMEOUT := 4.0

var _root_node: Node = null
var _camera: Node = null
var _builder: Node = null
var _hud: Array[Node] = []
var _elapsed: float = 0.0
var _step: int = 0
var _step_started: float = 0.0
var _tapped: bool = false
var _shots: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	var packed: PackedScene = load("res://ramon/MiegakureLook/levels/level_1_wall.tscn")
	if packed == null:
		printerr("CAPTURE: could not load level_1_wall.tscn")
		quit(1)
		return

	_root_node = packed.instantiate()
	root.add_child(_root_node)
	set_current_scene(_root_node)

	_camera = _root_node.get_node_or_null("CameraRig")
	_builder = _root_node.get_node_or_null("Builder")
	if _camera == null or _builder == null:
		printerr("CAPTURE: expected CameraRig and Builder nodes")
		quit(1)
		return

	for name in ["GoalBanner", "WReadout", "ReturnButton"]:
		var n: Node = _root_node.get_node_or_null(name)
		if n != null:
			_hud.append(n)

	print("CAPTURE: level loaded, %d HUD nodes, %d builder children" % [
		_hud.size(), _builder.get_child_count()])


func _process(delta: float) -> bool:
	_elapsed += delta
	var in_step: float = _elapsed - _step_started

	match _step:
		0: # Let the build, the lighting and the physics settle.
			if in_step >= SETTLE_SECONDS:
				_shot("01_banded_before.png")
				_advance()
		1: # Hide the HUD, then rotate. Both shots of the pair are HUD-free.
			_set_hud_visible(false)
			if in_step >= 0.2:
				if not _tapped:
					_tap_rotate()
					_tapped = true
				elif _rotation_settled() or in_step >= ROTATION_TIMEOUT:
					_shot("02_banded_after.png")
					_advance()
		2: # Strip the banding and shoot the same view again.
			var repainted: int = _make_floor_uniform()
			print("CAPTURE: repainted %d floor panels uniform grey" % repainted)
			_advance()
		3:
			if in_step >= 0.4:
				_shot("03_plain_after.png")
				_advance()
		4:
			print("CAPTURE: wrote %d shots to %s" % [_shots.size(), OUT_DIR])
			for s in _shots:
				print("  - " + s)
			quit(0)
			return true

	return false


func _advance() -> void:
	_step += 1
	_step_started = _elapsed
	_tapped = false


## rotate_4d is an EVENT action, so Input.action_press() never reaches _input().
## It needs a real InputEventMouseButton through parse_input_event, released on
## the following frame or the camera sees the button held.
func _tap_rotate() -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	Input.parse_input_event(press)

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_RIGHT
	release.pressed = false
	Input.parse_input_event(release)


func _rotation_settled() -> bool:
	if _camera.has_method("is_transitioning") and _camera.is_transitioning():
		return false
	if not _camera.has_method("get_current_angle_degrees"):
		return true
	return absf(_camera.get_current_angle_degrees()) >= 45.0


func _set_hud_visible(value: bool) -> void:
	for n in _hud:
		if "visible" in n:
			n.visible = value


## Repaint every floor panel with one grey material, reproducing the uniform floor
## the level had before banding was introduced - including removing the yellow
## gate lane, which is the whole point of the control frame.
func _make_floor_uniform() -> int:
	var material := TetraMaterial4D.new()
	material.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_TEXTURE3D_CELL_UVW_ONLY
	material.albedo_texture_3d = TexGrey

	var count: int = 0
	for body in _builder.get_children():
		if not (body is StaticBody4D):
			continue
		if body.position.y >= 0.0:
			continue # wall, rail or goal - not floor.
		for child in body.get_children():
			if child is MeshInstance4D:
				child.material_override = material
				count += 1
	return count


func _shot(file_name: String) -> void:
	var texture: ViewportTexture = root.get_texture()
	if texture == null:
		printerr("CAPTURE: no viewport texture - running headless by mistake?")
		return
	var image: Image = texture.get_image()
	if image == null:
		printerr("CAPTURE: viewport image was null for " + file_name)
		return
	image.save_png(OUT_DIR + file_name)
	_shots.append(file_name)
	var angle: float = 0.0
	if _camera.has_method("get_current_angle_degrees"):
		angle = _camera.get_current_angle_degrees()
	print("CAPTURE: %s | %dx%d | cam=%.1fdeg" % [
		file_name, image.get_width(), image.get_height(), angle])
