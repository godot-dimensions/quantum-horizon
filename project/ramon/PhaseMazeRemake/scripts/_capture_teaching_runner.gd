extends SceneTree

## The lobby wall's three pictures, filmed from the game (PLAN.md step 29): one cell of level 3, seen
## from a high camera so the flat maze reads like a diagram, three ways:
##   view_level   level: the x-z maze
##   view_ahead   facing ahead (-z), F: what was ahead is W, the x-w maze
##   view_side    facing along x, F: the z-w maze
## Saved to ramon/PhaseMazeRemake/art/ (the wall loads them as images, so no import is needed), plus a
## sheet of all three in smoke_test_output/phase_maze_remake/teaching/.
##   run.sh windowed teaching res://ramon/PhaseMazeRemake/scripts/_capture_teaching_runner.gd

const SCENE := "res://ramon/PhaseMazeRemake/phase_maze_remake.tscn"
const ART := "res://ramon/PhaseMazeRemake/art/"
const OUT := "res://smoke_test_output/phase_maze_remake/teaching/"
const GB := preload("res://ramon/PhaseMazeRemake/carried/walker/ground_basis_4d.gd")

var _t0: int = 0
var _m: Node4D


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_x: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 90000:
		print("TEACH: gave up after 90 s")
		return true
	return false


func _wait(seconds: float) -> void:
	var t: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < int(seconds * 1000.0):
		await process_frame


func _shot(name: String) -> void:
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.resize(640, 360, Image.INTERPOLATE_LANCZOS)
	img.save_png(ProjectSettings.globalize_path(ART + name + ".png"))
	img.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("TEACH: ", name)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ART))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_m = (load(SCENE) as PackedScene).instantiate()
	_m.set("keep_bests", false)
	root.add_child(_m)
	current_scene = _m
	for i in 12:
		await process_frame
	_m.call("_load_level", 2)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_m.set_process_unhandled_input(false)
	var view: Node = _m.get("view")
	view.set("keys_on", false)
	var rig: Node4D = _m.get("rig")
	rig.set_process_unhandled_input(false)
	var player: Node4D = _m.get("player")
	player.set("input_enabled", false)
	(_m.get_node("HUD") as CanvasLayer).visible = false
	var rb: Node = _m.get_node_or_null("ReturnButton")
	if rb is CanvasLayer:
		(rb as CanvasLayer).visible = false
	# The high camera: well up and back, looking down, over the walls.
	rig.set("collide_with_world", false)
	rig.set("_zoom_target", 11.0)
	rig.set("distance", 11.0)
	rig.set("_home_pivot", 5.5)
	rig.set("pivot_height", 5.5)
	var lv = _m.get("lattice")
	_m.call("_place_player", lv.cell_centre(Vector3i(1, 1, 1)) + Vector4(0, 0.1, 0, 0), Vector4(0, 0, -1, 0))
	await _wait(0.4)
	for k in [["view_level", 0.0, false], ["view_ahead", 0.0, true], ["view_side", -PI * 0.5, true]]:
		var b: Projection = Basis4D.from_zx(float(k[1]))
		if bool(k[2]):
			b = Projection(b.x, GB.UP, -b.w, b.z)
		rig.basis = b
		rig.set("pitch", deg_to_rad(-52.0))
		rig.call("_apply")
		await _wait(0.5)
		await _shot(String(k[0]))
	print("TEACH: done")
	quit()
