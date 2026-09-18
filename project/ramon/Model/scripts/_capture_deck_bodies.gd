extends SceneTree

## Photographs the three lofted bodies individually, in profile, for the October-gate
## deck's "content can be made without a 4D specialist" slide.
##
##   godot.windows.editor.double.x86_64.console.exe --path project \
##       --resolution 1920x1080 \
##       --script res://ramon/Model/scripts/_capture_deck_bodies.gd
##
## MUST run WINDOWED - there is no framebuffer headless.
##
## Why individually rather than the existing row shot: `_capture_row_runner.gd` frames
## all three at true relative scale, which is honest and useless as a slide - at
## 0.51 m, 1.15 m and 10.2 m the chicken and goat are specks beside the
## brachiosaurus. The claim the deck makes is "three different bodies out of one rig",
## so all three have to be legible; relative scale belongs in the caption instead.
##
## Camera distance is derived from each body's own height rather than hand-tuned per
## animal, so adding a fourth body needs one table row and no new numbers. The
## multipliers come from the known-good goat framing in `_capture_goat_runner.gd`
## (-7.0 x, +2.4 y against a 4.6-unit body).
##
## The player faces -Z, so a profile needs the BASIS yawed -90 degrees to point the
## gaze along +X - moving the camera alone gives a front view from further away.

const OUT_DIR := "D:/temp_docs/deck_shots/"
const SETTLE_FRAMES := 50

## name in Models/, output file, approximate body height in scene units.
const BODIES := [
	["Chicken", "10_loft_chicken.png", 2.05],
	["Goat", "11_loft_goat.png", 4.6],
	["Brachio", "12_loft_brachio.png", 40.7],
]

const X_PER_HEIGHT := -1.55
const Y_PER_HEIGHT := 0.44

var _instance: Node = null
var _player: Node4D = null
var _index: int = 0
var _frames: int = 0
var _shots: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	_instance = (load("res://ramon/Model/model.tscn") as PackedScene).instantiate()
	root.add_child(_instance)
	_player = _instance.get_node_or_null("Player")
	if _player == null:
		printerr("CAPTURE: no Player node in model.tscn")
		quit(1)
		return

	# Profile view: gaze along +X.
	_player.basis = Projection(
		Vector4(0, 0, 1, 0), Vector4(0, 1, 0, 0), Vector4(-1, 0, 0, 0), Vector4(0, 0, 0, 1))

	# These are studio plates of a modelling tool, not slice comparisons, so the
	# position readout is noise here rather than evidence.
	var label: Node = _player.get_node_or_null("PositionLabel")
	if label != null and "visible" in label:
		label.visible = false

	_aim()


func _aim() -> void:
	var entry: Array = BODIES[_index]
	var body: Node4D = _instance.get_node_or_null("Models/" + entry[0])
	if body == null:
		printerr("CAPTURE: missing Models/" + entry[0])
		return
	var h: float = float(entry[2])
	_player.position = body.position + Vector4(X_PER_HEIGHT * h, Y_PER_HEIGHT * h, 0.4, 0.0)
	print("CAPTURE: aiming at %s (h=%.2f) from (%.1f, %.1f)" % [
		entry[0], h, _player.position.x, _player.position.y])


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < SETTLE_FRAMES:
		return false
	_frames = 0

	var entry: Array = BODIES[_index]
	var image: Image = root.get_texture().get_image()
	if image == null:
		printerr("CAPTURE: no framebuffer - running headless by mistake?")
		quit(1)
		return true
	image.save_png(OUT_DIR + entry[1])
	_shots.append(entry[1])
	print("CAPTURE: %s | %dx%d" % [entry[1], image.get_width(), image.get_height()])

	_index += 1
	if _index >= BODIES.size():
		print("CAPTURE: wrote %d body plates to %s" % [_shots.size(), OUT_DIR])
		quit(0)
		return true

	_aim()
	return false
