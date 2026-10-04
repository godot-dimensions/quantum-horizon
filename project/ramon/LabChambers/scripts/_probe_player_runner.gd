extends SceneTree

## Probe: the gallery player's legs at rest and walking, numbers to the log and a side-on frame,
## to res://smoke_test_output/goat_room/probe_*.png.
##
##   CreationLab/scripts/lab_run.sh windowed probe res://ramon/LabChambers/scripts/_probe_player_runner.gd

const SCENE := "res://ramon/LabChambers/goat_room.tscn"
const OUT := "res://smoke_test_output/goat_room/"

var _g: Node


func _initialize() -> void:
	root.unfocusable = true
	_run.call_deferred()


func _wait(s: float) -> void:
	var until: int = Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


func _report(what: String) -> void:
	var p: CharacterBody4D = _g.get("player")
	var av: Node4D = p.get_node("Avatar")
	var hip: Node4D = av.get("hip_left")
	var knee: Node4D = av.get("knee_left")
	var ankle: Node4D = av.get("ankle_left")
	var bend: float = rad_to_deg(acos(clampf((knee.basis * Vector4(0, 1, 0, 0)).normalized().y, -1.0, 1.0)))
	print("%s: body y %.3f  avatar y %.3f  hip y %.3f  ankle y %.3f  knee bend %.1f  on floor %s" % [what, p.global_position.y,
		av.position.y, hip.global_position.y, ankle.global_position.y, bend, str(p.is_on_floor())])


func _run() -> void:
	_g = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_g)
	current_scene = _g
	await _wait(3.0)
	(_g.get("tuner") as Control).visible = false
	var p: CharacterBody4D = _g.get("player")
	p.global_position = Vector4(3.0, 0.05, 4.0, 0.0)
	p.set("_facing", PI * 0.75 + PI * 0.5)
	var rig: Node = p.get_node("CameraRig")
	rig.set("yaw", PI * 0.75)
	rig.set("pitch", deg_to_rad(-4.0))
	rig.set("_zoom_target", 3.4)
	rig.set("pivot_height", 1.15)
	rig.set("_home_pivot", 1.15)
	rig.call("_apply")
	await _wait(1.5)
	_report("rest")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "probe_rest.png")
	quit(0)
