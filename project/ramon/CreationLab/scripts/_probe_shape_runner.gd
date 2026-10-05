extends SceneTree

## The room's plan (kit/kit_room_plan.gd): the shape Ramon saved before the plan comes back as it
## was; lengthening the Creation Lab wall moves only that wall (the room's width and depth stay, its
## side wall and back wall shorten), the wall stays blue end to end and the introduction stays in
## its middle; both corner walls at 0 m make a rectangle. Plan views of each, from straight above,
## to res://smoke_test_output/creation_lab/plan/.
##
##   CreationLab/scripts/lab_run.sh windowed shape res://ramon/CreationLab/scripts/_probe_shape_runner.gd

const SCENE := "res://ramon/CreationLab/creation_lab.tscn"
const OUT := "res://smoke_test_output/creation_lab/plan/"

var _g: Node
var _gr: Node
var _cam: Camera4D
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


func _extent() -> Vector2:
	var ol: PackedVector2Array = _gr.get("outline")
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in ol:
		lo = lo.min(p)
		hi = hi.max(p)
	return hi - lo


func _lengths() -> Dictionary:
	return _g.call("wall_lengths")


## Every piece of the Creation Lab wall in the code blue.
func _all_blue(wall: String) -> bool:
	var e: int = int(_gr.call("wall_key", wall))
	var pieces: Array = _gr.call("wall_pieces", e)
	if pieces.is_empty():
		return false
	for pc in pieces:
		var m: TetraMaterial4D = (pc[0] as MeshInstance4D).material_override as TetraMaterial4D
		if String(m.get_meta("lab_swatch", "")) != "kit_code_blue":
			return false
	return true


## The panel's middle on its wall's middle.
func _centred(panel: Node, wall: String) -> bool:
	var c: Vector4 = (panel.call("panel_frame") as Array)[0]
	var fr: Array = _gr.call("wall_frame", wall)
	var m: Vector2 = (fr[0] as Vector2) + Vector2((_gr as Node4D).global_position.x, (_gr as Node4D).global_position.z)
	return Vector2(c.x, c.z).distance_to(m) < 0.01


func _plan_view(what: String) -> void:
	# The room rebuilds its ceiling with its walls: off again, with the lights' fixtures.
	for n in _g.find_children("*", "Node4D", true, false):
		if String(n.name).begins_with("Ceiling") or String(n.name).begins_with("Fixture"):
			(n as Node4D).visible = false
		if n.get("fixture") != null and n.get("aim") != null and bool(n.get("fixture")):
			n.set("fixture", false)
	_cam.global_position = Vector4(0.0, 30.0, 0.5, 0.0)
	_cam.global_basis = Projection(Vector4(0, 0, -1, 0), Vector4(-1, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 0, 1))
	await _wait(1.0)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + what + ".png")
	print("shot ", what)


func _report(what: String) -> void:
	var L: Dictionary = _lengths()
	print("%s: width %.2f, depth %.2f; creation wall %.2f m at %.1f deg; walls: left %.2f, creation %.2f, back %.2f, right corner %.2f, right %.2f" % [
		what, _extent().x, _extent().y, float(_g.get("creation_wall_length")), float(_g.get("creation_wall_angle")),
		float(L.get("left", 0)), float(L.get("left_corner", 0)), float(L.get("back", 0)), float(L.get("right_corner", 0)), float(L.get("right", 0))])


func _run() -> void:
	_g = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_g)
	current_scene = _g
	await _wait(4.5)
	_gr = _g.get_node("GoatRoom")
	var intro: Node = _g.get_node("IntroPanel")
	var board: Node = _g.get_node("ResearchBoard")
	for c in _g.get_children():
		if c is CanvasLayer:
			(c as CanvasLayer).visible = false
	(_g.get("player") as Node4D).visible = false
	_cam = Camera4D.new()
	_cam.set("rendering_engine_name", "Cross-section")
	_cam.set("projection_type", 0)
	_cam.set("orthographic_size", 30.0)
	_g.add_child(_cam)
	_cam.current = true
	# The shape as saved: the corners Ramon saved before the plan, if his settings were saved then.
	_report("saved")
	var ol: PackedVector2Array = _gr.get("outline")
	print("outline ", ol)
	var cfg := ConfigFile.new()
	if cfg.load("res://ramon/CreationLab/creation_lab_tuning.cfg") == OK and cfg.has_section_key("shape", "corner_z"):
		var w: float = float(cfg.get_value("shape", "room_half_width"))
		var b: float = float(cfg.get_value("shape", "back_wall_half"))
		var cz: float = float(cfg.get_value("shape", "corner_z"))
		var d: float = float(cfg.get_value("shape", "room_back"))
		_check(ol[1].distance_to(Vector2(-w, cz)) < 0.05 and ol[2].distance_to(Vector2(-b, -d)) < 0.05, "the saved shape comes back as it was (%s, %s)" % [ol[1], ol[2]])
	_check(_all_blue("left_corner"), "the Creation Lab wall is blue end to end")
	_check(_centred(intro, "left_corner") and _centred(board, "right"), "both panels in the middle of their walls")
	await _plan_view("plan_saved")
	# Two metres longer: only that wall moves.
	var ext0: Vector2 = _extent()
	var L0: Dictionary = _lengths().duplicate()
	_g.set("creation_wall_length", float(_g.get("creation_wall_length")) + 2.0)
	await _wait(1.5)
	_report("longer")
	var L1: Dictionary = _lengths()
	_check(_extent().distance_to(ext0) < 0.01, "the room keeps its width and depth (%.2f x %.2f)" % [_extent().x, _extent().y])
	_check(float(L1["left_corner"]) > float(L0["left_corner"]) + 1.0, "the Creation Lab wall is longer (%.2f to %.2f m)" % [float(L0["left_corner"]), float(L1["left_corner"])])
	_check(float(L1["left"]) < float(L0["left"]) and float(L1["back"]) < float(L0["back"]), "the left wall and the back wall it meets got shorter")
	_check(is_equal_approx(float(L1["right"]), float(L0["right"])) and is_equal_approx(float(L1["right_corner"]), float(L0["right_corner"])), "the right side is untouched")
	_check(_all_blue("left_corner"), "still blue end to end")
	_check(_centred(intro, "left_corner"), "the introduction stays in its middle")
	await _plan_view("plan_creation_wall_longer")
	# Both corner walls at 0 m: a rectangle.
	_g.set("creation_wall_length", 0.0)
	_g.set("right_corner_length", 0.0)
	await _wait(1.5)
	_report("rectangle")
	var ol2: PackedVector2Array = _gr.get("outline")
	_check(ol2[1].distance_to(ol2[2]) < 0.05 and ol2[3].distance_to(ol2[4]) < 0.05 and _extent().distance_to(ext0) < 0.01, "both at 0 m: a rectangle of the same box")
	_check(not bool(_gr.call("has_wall", "left_corner")), "the corner wall is gone (its panel says so)")
	await _plan_view("plan_rectangle")
	print("SHAPE %s: %d failed" % ["PASS" if _fails.is_empty() else "FAIL", _fails.size()])
	quit(0 if _fails.is_empty() else 1)
