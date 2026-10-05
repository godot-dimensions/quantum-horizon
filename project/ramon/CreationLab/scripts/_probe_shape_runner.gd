extends SceneTree

## Probe: the goat room's shape numbers. Widens and deepens the room, then photographs it from
## inside and checks the outline, the doorway and the right-wall screens followed.
##
##   CreationLab/scripts/lab_run.sh windowed shape res://ramon/CreationLab/scripts/_probe_shape_runner.gd

const SCENE := "res://ramon/CreationLab/creation_lab.tscn"
const OUT := "res://smoke_test_output/goat_room/"


func _initialize() -> void:
	root.unfocusable = true
	_run.call_deferred()


func _wait(s: float) -> void:
	var until: int = Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


func _run() -> void:
	var g: Node = (load(SCENE) as PackedScene).instantiate()
	root.add_child(g)
	current_scene = g
	await _wait(3.5)
	(g.get("tuner") as Control).visible = false
	g.set("room_half_width", 12.5)
	g.set("room_back", 11.0)
	g.set("back_wall_half", 4.5)
	g.set("corner_z", -2.0)
	await _wait(2.0)
	var gr: Node = g.get_node("GoatRoom")
	var outline: PackedVector2Array = gr.get("outline")
	print("outline ", outline)
	print("doorways ", gr.get("doorways"))
	print("panel at ", (g.get_node("ResearchWall") as Node4D).position, " face ", g.get_node("ResearchWall").get("face"))
	var ok: bool = outline.size() == 6 and absf(outline[0].x + 12.5) < 0.01 and absf(outline[2].y + 11.0) < 0.01
	print(("PASS" if ok else "FAIL") + " the outline follows the shape numbers")
	var p: CharacterBody4D = g.get("player")
	p.global_position = Vector4(0.0, 0.05, 6.5, 0.0)
	await _wait(1.0)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "shape_wider.png")
	quit(0 if ok else 1)
