extends SceneTree

## The wall panel kit in a second prototype (tests/panel_test_room.tscn): each of the box room's
## three panels and the freestanding one, straight on, and their warnings. To
## res://smoke_test_output/wall_panels/test_room/.
##
##   CreationLab/scripts/lab_run.sh windowed panel_test res://ramon/CreationLab/scripts/_capture_panel_test_room_runner.gd

const SCENE := "res://ramon/CreationLab/tests/panel_test_room.tscn"
const OUT := "res://smoke_test_output/wall_panels/test_room/"
const Mark := preload("res://ramon/CreationLab/LabKit/lab_mark_4d.gd")

var _g: Node
var _fails: Array = []


func _initialize() -> void:
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run.call_deferred()


func _process(_dt: float) -> bool:
	return false


func _wait(s: float) -> void:
	var until: int = Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_fails.append(what)


func _run() -> void:
	_g = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_g)
	current_scene = _g
	await _wait(4.0)
	(_g.get("player") as Node4D).visible = false
	var cam := Camera4D.new()
	cam.set("rendering_engine_name", "Cross-section")
	_g.add_child(cam)
	cam.current = true
	for nm in ["Intro", "Compare", "Steps", "Freestanding"]:
		var p: Node = _g.get_node(nm)
		var w: PackedStringArray = p.call("_get_configuration_warnings")
		_check(p.get("page") != null, "%s built" % nm)
		_check(w.is_empty(), "%s has no warnings %s" % [nm, str(w)])
		var fr: Array = p.call("panel_frame")
		var c: Vector4 = fr[0]
		var n: Vector4 = fr[1]
		cam.global_position = c + n * 10.5
		cam.global_basis = Mark.basis_looking(cam.global_position, c)
		await _wait(0.8)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT + nm.to_lower() + ".png")
		print("shot ", nm)
	# From above and behind, the freestanding one on its slab, turned.
	var fs: Node4D = _g.get_node("Freestanding")
	cam.global_position = fs.global_position + Vector4(-14, 9, 4, 0)
	cam.global_basis = Mark.basis_looking(cam.global_position, fs.global_position + Vector4(0, 3, 0, 0))
	await _wait(0.8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "freestanding_oblique.png")
	# The pair: kit size, then fitted to its walls, always the same size and level with each other.
	var pair: Node = _g.get_node("WallPanels")
	var a: Node = _g.get_node("Intro")
	var b: Node = _g.get_node("Compare")
	_check(is_equal_approx(float(a.get("scale_factor")), 1.0) and is_equal_approx(float(b.get("scale_factor")), 1.0), "the pair starts at the kit size")
	pair.set("max_scale", 1.5)
	pair.set("size_mode", "fit walls")
	await _wait(1.5)
	var sa: float = float(a.get("scale_factor"))
	var sb: float = float(b.get("scale_factor"))
	var ya: float = ((a.call("panel_frame") as Array)[0] as Vector4).y
	var yb: float = ((b.call("panel_frame") as Array)[0] as Vector4).y
	print("fitted: intro %.3f, compare %.3f, middles at %.3f and %.3f m" % [sa, sb, ya, yb])
	_check(is_equal_approx(sa, sb) and sa > 1.01, "fitted, both panels take one scale (%.3f)" % sa)
	_check(is_equal_approx(ya, yb), "fitted, both stay level")
	var fp: Node = a
	var fr: Array = fp.call("panel_frame")
	cam.global_position = (fr[0] as Vector4) + (fr[1] as Vector4) * 12.5
	cam.global_basis = Mark.basis_looking(cam.global_position, fr[0])
	await _wait(0.8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "intro_fitted.png")
	pair.set("size_mode", "kit size")
	await _wait(1.0)
	_check(is_equal_approx(float(a.get("scale_factor")), 1.0), "and back to the kit size")
	print("PANEL TEST %s: %d failed" % ["PASS" if _fails.is_empty() else "FAIL", _fails.size()])
	quit(0 if _fails.is_empty() else 1)
