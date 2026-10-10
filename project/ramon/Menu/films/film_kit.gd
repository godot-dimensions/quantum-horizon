extends RefCounted

## The menu films' shared kit: what every prototype's film runner (Menu/films/<clip>_film_runner.gd)
## needs to record the clip that plays in menu_final's details pane (Menu/thumbs/<clip>.ogv).
##
## How a film is made (Ramon, 9 Oct: "about 5 shots for each prototype ... as hires as possible ...
## cinematic, immersive, cool, and also gameplay shots"):
##   - film_run.sh starts Godot at 1920 x 1080 with --fixed-fps 30, so every frame advances the world
##     exactly 1/30 s however long it takes to draw and save: the film is smooth even where the scene
##     is heavy, and a frame's save stalls nothing on screen.
##   - the runner loads the prototype's own scene (never the menu, never through a launch), waits out
##     its loading, hides its HUD, and plays its shots, saving only the frames it means to keep.
##   - film_run.sh then encodes the frames: an mp4 to review and the .ogv for the menu.
##
## The pane crops: the list view shows the frame at 16:9, the route view at about 2:1 (the middle
## 88 % of its height), so keep what matters in the middle band, nothing important at the top or the
## bottom edge.
##
## Rules for a runner: never edit the prototype's files (the films live in Menu/films/); never save
## anything into the scene; switch the player's input off and free the mouse (his real mouse and keys
## must not leak into the shot); quit when done.
##
## NO class_name: runners preload it.

var tree: SceneTree
var out_dir: String = ""
var recording: bool = false
var count: int = 0
var _hidden: Array = []


func _init(scene_tree: SceneTree, out: String) -> void:
	tree = scene_tree
	out_dir = out
	DirAccess.make_dir_recursive_absolute(out_dir)


## One frame: the world advances 1/30 s and is drawn; while recording it is saved.
func frame() -> void:
	await tree.process_frame
	await RenderingServer.frame_post_draw
	if recording:
		tree.root.get_texture().get_image().save_jpg(out_dir.path_join("%05d.jpg" % count), 0.95)
		count += 1


## `n` frames, recorded or not as `recording` says.
func hold(n: int) -> void:
	for i in n:
		await frame()


## Frames not recorded (let a scene settle, a board fade, a camera land).
func skip(n: int) -> void:
	var was: bool = recording
	recording = false
	for i in n:
		await frame()
	recording = was


## Eases 0..1 in and out (smoothstep), for camera glides.
static func ease_io(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Plays `frames` frames, calling `step(t)` with t eased 0..1 before each: a glide.
func glide(frames: int, step: Callable) -> void:
	for i in frames:
		step.call(ease_io(float(i) / float(maxi(1, frames - 1))))
		await frame()


## Hides every CanvasLayer under `node` (HUDs, panels, key strips) except those named in `keep`;
## show_layers() puts them back.
func hide_layers(node: Node, keep: PackedStringArray = []) -> void:
	for layer in node.find_children("*", "CanvasLayer", true, false):
		if String(layer.name) in keep or not (layer as CanvasLayer).visible:
			continue
		(layer as CanvasLayer).visible = false
		_hidden.append(layer)


func show_layers() -> void:
	for layer in _hidden:
		if is_instance_valid(layer):
			(layer as CanvasLayer).visible = true
	_hidden.clear()


## Frees the mouse and keeps the test window from taking his typing (memory: test windows steal focus).
func calm_window() -> void:
	tree.root.unfocusable = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
