extends SceneTree

## SIDE BY SIDE FILMS OF THE W TOOLS (Ramon, 7 Oct: "these could be amazing videos to show the team"): one
## take per way with the same moves, frame for frame, joined side by side with ffmpeg afterwards.
##   exploder   the exploder lab: no copies | the W Exploder (Turnable forest)
## Each part swings the slice out and back (across the view: xw; along it: zw) or steps the player through W
## and back with the slice flat (w). Every frame is saved as a picture from a normal window (Godot's movie
## writer drew a turned slice wrong), and nobody's mouse or keys reach it (input_guard.gd).
##
## The pen's own smaller player (w_lab_4d.gd pen_player). It is placed once a part and then only moved along
## W: placing it at a height every frame dropped it each frame, and the character and camera bounced.
## With "test" after the way: each part cut to 50 frames, and the player's and camera's height printed.
##
##   lab_run.sh windowed side_<film>_<a|b> res://ramon/WTools/tests/_film_side_runner.gd <film> <a|b> [test]
## Frames: res://smoke_test_output/wtools/films/<film>_<a|b>/f0000.png ...

const SETTLE := 150
const FILMS := {
	"exploder": {
		"scene": "res://ramon/WTools/tests/exploder_lab.tscn",
		"a": "WITHOUT COPIES", "b": "W EXPLODER  (Turnable forest)",
		# [caption, player at, xw / zw / w, frames, engine, camera distance, pitch, how far (degrees or metres)]
		"parts": [
			["The slice turned across the view", Vector4(0.0, 1.0, 14.0, 0), "xw", 180, "Cross-section", 6.0, 0.02, 50.0],
			["The slice turned along the view", Vector4(0.0, 1.0, 14.0, 0), "zw", 180, "Cross-section", 6.0, 0.02, 50.0],
			["Stepping 9 m through W, the slice flat", Vector4(0.0, 1.0, 14.0, 0), "w", 160, "Cross-section", 6.0, 0.02, 9.0],
		],
	},
}

var _cfg: Dictionary
var _way: String
var _lab: Node
var _player: CharacterBody4D
var _rig: Node4D
var _cam: Camera4D
var _caption: Label
var _turn_label: Label
var _out: String
var _frame: int = 0
var _part: int = -1
var _going: bool = false
var _busy: bool = false
var _placed: int = -2
var _test: bool = false


func _initialize() -> void:
	root.unfocusable = true
	_start.call_deferred()


func _start() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var film: String = args[0] if args.size() > 0 else "exploder"
	_way = args[1] if args.size() > 1 else "a"
	_test = args.has("test")
	_cfg = FILMS[film]
	_out = "res://smoke_test_output/wtools/films/%s_%s/" % [film, _way]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_lab = (load(_cfg["scene"]) as PackedScene).instantiate()
	_lab.set("readout", false)
	_lab.set("pen_player", true)
	# The way, set before the scene starts.
	if film == "exploder":
		var trees: Node = _lab.get_node("Trees")
		if _way == "a":
			trees.set("enabled", false)
			trees.set("trunk_w_slab", 0.0)
		else:
			trees.set("preset", load("res://ramon/WTools/exploder/presets/turnable_forest.tres"))
	root.add_child(_lab)
	current_scene = _lab
	var guard := Node.new()
	guard.set_script(load("res://ramon/PenLayout/scripts/input_guard.gd"))
	root.add_child(guard)
	for i in 30:
		await process_frame
	_player = _lab.get("player") as CharacterBody4D
	_player.set("input_enabled", false)
	_rig = _lab.get("rig") as Node4D
	_cam = _player.get_node("CameraRig/Pitch/Camera4D") as Camera4D
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var title := Label.new()
	title.text = String(_cfg[_way])
	title.position = Vector2(28, 20)
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.08, 0.12, 0.2))
	layer.add_child(title)
	_turn_label = Label.new()
	_turn_label.position = Vector2(28, 66)
	_turn_label.add_theme_font_size_override("font_size", 24)
	_turn_label.add_theme_color_override("font_color", Color(0.18, 0.4, 0.8))
	layer.add_child(_turn_label)
	_caption = Label.new()
	_caption.position = Vector2(28, 640)
	_caption.add_theme_font_size_override("font_size", 26)
	_caption.add_theme_color_override("font_color", Color(0.08, 0.12, 0.2))
	layer.add_child(_caption)
	_place(_cfg["parts"][0], 0.0)
	_going = true


func _process(_d: float) -> bool:
	if not _going or _busy:
		return false
	_frame += 1
	if _frame < SETTLE:
		return false
	var t: int = _frame - SETTLE
	var parts: Array = _cfg["parts"]
	var start: int = 0
	var part: int = -1
	for i in parts.size():
		var length: int = 50 if _test else int(parts[i][3])
		if t < start + length:
			part = i
			break
		start += length
	if part == -1:
		print("SIDE FILM DONE: %d frames" % t)
		return true
	var p: Array = parts[part]
	# Out and back, easing, with a beat at each end.
	var k: float = clampf(float(t - start) / float(50 if _test else int(p[3])), 0.0, 1.0)
	var amount: float = float(p[7]) * sin(clampf((k - 0.1) / 0.8, 0.0, 1.0) * PI)
	if part != _part:
		_part = part
		_caption.text = String(p[0])
	_place(p, amount)
	_turn_label.text = ("W %.1f m" % amount) if String(p[2]) == "w" else ("slice turned %d°" % roundi(amount))
	if _test and t % 5 == 0:
		print("HEIGHT t %3d part %d: player y %.3f, camera y %.3f" % [t, part, _player.global_position.y, _cam.global_position.y])
	_save(t)
	return false


## The player and camera for part [param p], turned (or stepped through W) by [param amount].
func _place(p: Array, amount: float) -> void:
	var at: Vector4 = p[1]
	var plane: String = p[2]
	var here: Vector4 = _player.global_position
	if _placed != _part:
		# Once a part (the first time at its own height, to settle on the floor; after that the height the
		# floor holds it at, so it never drops).
		_player.global_position = Vector4(at.x, at.y if _placed == -2 else here.y, at.z, at.w)
		_player.linear_velocity = Vector4.ZERO
		_placed = _part
	elif plane == "w":
		# Only along W.
		_player.global_position = Vector4(here.x, here.y, here.z, amount)
	_rig.set("pitch", float(p[6]))
	_rig.set("distance", float(p[5]))
	_rig.set("_zoom_target", float(p[5]))
	_rig.set("yaw", 0.0)
	_rig.set("_slice_xw", deg_to_rad(amount) if plane == "xw" else 0.0)
	_rig.set("_slice_zw", deg_to_rad(amount) if plane == "zw" else 0.0)
	_rig.call("_apply")
	if _cam.rendering_engine_name != String(p[4]):
		var other := Camera4D.new()
		_lab.add_child(other)
		other.make_current()
		_cam.rendering_engine_name = String(p[4])
		_cam.make_current()
		other.queue_free()


## This frame, once drawn, as a picture; the sequence waits for it.
func _save(t: int) -> void:
	_busy = true
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(_out + "f%04d.png" % t))
	_busy = false
