extends SceneTree

## The two blue walls side by side in the gallery beside the room (WallCompare): the review jump from
## the dev panel, the player's view of them, and a straight-on view of both, with the story playing
## and not. To res://smoke_test_output/goat_room/compare/.
##
##   CreationLab/scripts/lab_run.sh windowed compare res://ramon/LabChambers/scripts/_capture_compare_runner.gd

const SCENE := "res://ramon/LabChambers/goat_room.tscn"
const OUT := "res://smoke_test_output/goat_room/compare/"
const Mark := preload("res://ramon/LabKit/lab_mark_4d.gd")

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


func _shot(what: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + what + ".png")
	print("shot ", what)


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_fails.append(what)


func _run() -> void:
	_g = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_g)
	current_scene = _g
	await _wait(4.5)
	var p: CharacterBody4D = _g.get("player")
	var before: Vector4 = p.global_position
	_check(bool(_g.call("toggle_compare")), "the review jump goes to the gallery")
	await _wait(1.2)
	_check(p.global_position.x > 30.0 and absf(p.global_position.y) < 0.5, "standing on the gallery floor (%.1f, %.2f, %.1f)" % [p.global_position.x, p.global_position.y, p.global_position.z])
	await _shot("player_view")
	# Straight on, both walls in frame, no HUD.
	for c in _g.get_children():
		if c is CanvasLayer:
			(c as CanvasLayer).visible = false
	var cr: Node4D = _g.get_node("WallCompare")
	var ol: PackedVector2Array = cr.get("outline")
	var dir: Vector2 = (ol[2] - ol[1]).normalized()
	var inward := Vector2(-dir.y, dir.x)
	var mid: Vector2 = Vector2(cr.global_position.x, cr.global_position.z) + ol[2]
	var cam := Camera4D.new()
	cam.set("rendering_engine_name", "Cross-section")
	_g.add_child(cam)
	cam.current = true
	var eye: Vector2 = mid + inward * 13.5
	cam.global_position = Vector4(eye.x, 4.4, eye.y, 0.0)
	cam.global_basis = Mark.basis_looking(cam.global_position, Vector4(mid.x, 4.4, mid.y, 0.0))
	await _wait(0.8)
	await _shot("straight_on")
	# With the story playing, so the research page shows a part.
	var sc: Node = _g.get_node("Showcase")
	sc.call("replay")
	var until: int = Time.get_ticks_msec() + 15000
	while int(sc.get("seq_index")) < 1 and Time.get_ticks_msec() < until:
		await process_frame
	await _wait(2.5)
	await _shot("straight_on_playing")
	cam.current = false
	for c in _g.get_children():
		if c is CanvasLayer:
			(c as CanvasLayer).visible = true
	_check(not bool(_g.call("toggle_compare")), "the jump again goes back")
	await _wait(0.4)
	_check(p.global_position.distance_to(before) < 0.5, "back where it was")
	print("COMPARE %s: %d failed" % ["PASS" if _fails.is_empty() else "FAIL", _fails.size()])
	quit(0 if _fails.is_empty() else 1)
