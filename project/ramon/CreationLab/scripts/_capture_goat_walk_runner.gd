extends SceneTree

## The goat's walk, photographed: the goat standing in its coat (for its proportions), then six
## frames across one walk cycle, side on, to res://smoke_test_output/goat_walk/.
##
##   CreationLab/scripts/lab_run.sh windowed goat_walk res://ramon/CreationLab/scripts/_capture_goat_walk_runner.gd

const SCENE := "res://ramon/CreationLab/creation_lab.tscn"
const OUT := "res://smoke_test_output/goat_walk/"
const Mark := preload("res://ramon/LabKit/lab_mark_4d.gd")

var _g: Node
var _n: int = 0


func _initialize() -> void:
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run.call_deferred()


func _wait(s: float) -> void:
	var until: int = Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


func _shot(what: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s%02d_%s.png" % [OUT, _n, what])
	_n += 1


func _run() -> void:
	var t0: int = Time.get_ticks_msec()
	_g = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_g)
	current_scene = _g
	await _wait(4.0)
	(_g.get("tuner") as Control).visible = false
	var sc: Node = _g.get_node("Showcase")
	var p: CharacterBody4D = _g.get("player")
	p.global_position = Vector4(0.0, 0.05, 7.4, 0.0)
	p.set("_facing", PI)
	var rig: Node = p.get_node("CameraRig")
	rig.set("yaw", 0.0)
	rig.set("pitch", deg_to_rad(-6.0))
	rig.set("_zoom_target", 3.0)
	rig.set("distance", 3.0)
	rig.set("pivot_height", 2.4)
	rig.set("_home_pivot", 2.4)
	rig.call("_apply")
	# A camera of its own, close and side on to the pedestal.
	var cam := Camera4D.new()
	cam.set("rendering_engine_name", "Cross-section")
	_g.add_child(cam)
	cam.global_position = Vector4(0.0, 2.5, 3.6, 0.0)
	cam.global_basis = Mark.basis_looking(cam.global_position, Vector4(0.0, 2.1, -1.5, 0.0))
	cam.current = true
	var ex: Node = sc.get("exhibit")
	var walker: Node = ex.get("_walker") if ex != null else null
	print("walker: ", walker != null)
	# Standing in its coat: the skin sequence, turned side on.
	sc.set("_touched_at", -100.0)
	sc.set("_loop_t", 6.5 + 4.5)
	await _wait(0.6)
	await _shot("standing")
	# The walk: its sequence starts at 6.5 + 5.5 + 7.5 = 19.5 s into the loop.
	sc.set("_loop_t", 19.5 + 0.3)
	await _wait(0.4)
	print("walking: ", walker.call("is_walking") if walker != null else false)
	for i in 6:
		await _wait(0.2)
		await _shot("walk_%d" % i)
	# The rig: the x-ray walk, 28.5 s into the loop.
	sc.set("_loop_t", 28.5 + 0.3)
	await _wait(0.4)
	for i in 3:
		await _wait(0.3)
		await _shot("rig_%d" % i)
	print("GOAT WALK done, %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit(0)
