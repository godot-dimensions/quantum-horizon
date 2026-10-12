extends SceneTree

## The two wall panels flat, side by side on the Figma's own canvas (2048 x 732 units, the panels at
## x 144 and 1104, y 144), in the Figma's tokens and its reference data: the sheet to lay over the
## handoff's frame 01 and measure (step 18 of follow_up/wall_panels_plan.md), and a clean picture
## to paint over. Saves the canvas at 1 and 3 pixels a unit, plus the three research layout families,
## to res://smoke_test_output/wall_panels/.
##
##   CreationLab/scripts/lab_run.sh windowed sheet res://ramon/CreationLab/scripts/_capture_panel_sheet_runner.gd

const Spec := preload("res://ramon/CreationLab/kit/panels/kit_panel_spec.gd")
const Intro := preload("res://ramon/CreationLab/kit/panels/kit_panel_intro.gd")
const Research := preload("res://ramon/CreationLab/kit/panels/kit_panel_research.gd")
const INFO := "res://ramon/CreationLab/creation_lab_info.tres"
const OUT := "res://smoke_test_output/wall_panels/"


func _initialize() -> void:
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run.call_deferred()


func _intro_data(info: Resource) -> Dictionary:
	var fill := func(t: String) -> String: return t.replace("{name}", "goat").replace("{balls}", "24").replace("{action}", "Add a ball")
	var controls: Array = []
	for it in info.get("interactions"):
		controls.append([String(it[0]), fill.call(String(it[1]))])
	return {"header_left": info.call("intro_header"), "header_right": info.get("status"), "title": info.get("title"),
		"lead": info.get("lead"), "body": fill.call(String(info.get("description"))), "heading": info.get("controls_heading"), "controls": controls}


func _sheet(what: String, s: float, layout: String) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(int(Spec.CANVAS.x * s), int(Spec.CANVAS.y * s))
	vp.disable_3d = true
	vp.msaa_2d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Spec.TOKENS["blue"]
	bg.size = Vector2(vp.size)
	vp.add_child(bg)
	var info: Resource = load(INFO)
	var intro: Control = Intro.new()
	intro.name = "Intro"
	vp.add_child(intro)
	intro.call("setup", s)
	intro.position = Vector2(Spec.MARGIN, Spec.MARGIN) * s
	intro.call("refresh", _intro_data(info))
	var res: Control = Research.new()
	res.name = "Research"
	res.call("set_layout", layout)
	vp.add_child(res)
	res.call("setup", s)
	res.position = Vector2(Spec.MARGIN + Spec.PANEL.x + Spec.GAP, Spec.MARGIN) * s
	res.call("refresh", Research.sample(layout))
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	img.save_png(OUT + what + ".png")
	print("%s: %dx%d, overflow: intro %s research %s" % [what, img.get_width(), img.get_height(), str(intro.call("overflowed")), str(res.call("overflowed"))])
	vp.queue_free()
	await process_frame


func _run() -> void:
	Spec.flat = true
	await _sheet("sheet_1x", 1.0, "specimen")
	await _sheet("sheet_3x", 3.0, "specimen")
	await _sheet("sheet_compare_2x", 2.0, "compare")
	await _sheet("sheet_steps_2x", 2.0, "steps")
	Spec.flat = false
	quit(0)
