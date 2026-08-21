extends Node
## TEMPORARY - visual + numeric confirmation of the tether+belt treadmill
## design (replaces the earlier wraparound-teleport draft, which measured
## clean numerically but produced a visible sideways snap on this scene's
## side-on camera - see motion_lab_creature.gd's own header for the full
## history): (1) player spawn faces the creature without any turning, (2)
## body.position.x stays small/bounded throughout a real gait window - no
## wraparound needed because the body never travels far from spawn, (3) no
## visible jump anywhere in a screenshot taken well into the walk, (4)
## halt's breathing bob is visible in a screenshot. Wired in as a
## temporary autoload with limb_prototype_treadmill.tscn set as the main
## scene.

const OUTPUT_DIR := "res://smoke_test_output/"
const WALK_FRAMES := 900 # 15s.


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var scene: Control = get_tree().current_scene
	var root: Node = scene.get_node("FlatPlane/MotionLabCreature")
	var body: Node = root.get_node("Body")
	var player: Node4D = scene.get_node("FlatPlane/Player")

	print("=== spawn transform check ===")
	print("  player.global_position=%s" % [player.global_position])
	print("  creature body.global_position=%s" % [body.global_position])
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_screenshot("treadmill_tether_00_spawn_facing")

	body.select_gait("walk")
	var max_abs_offset: float = 0.0
	for i in range(WALK_FRAMES):
		await get_tree().physics_frame
		max_abs_offset = maxf(max_abs_offset, absf(body.position.x - body._spawn_x))
		if i % 120 == 0:
			print("  frame %d: position.x=%.4f (offset from spawn=%.4f)" % [i, body.position.x, body.position.x - body._spawn_x])
	print("max |position.x - spawn_x| over %ds walk = %.4f (tether should keep this small, well under wrap_half_range's old 10.0)" % [WALK_FRAMES / 60, max_abs_offset])
	await RenderingServer.frame_post_draw
	_screenshot("treadmill_tether_01_mid_walk")

	body.halted = true
	for i in range(120): # 2s.
		await get_tree().physics_frame
	print("halted breathing: body_mesh.position.y=%.4f (should be nonzero, |.| <= %.2f)" % [body._body_mesh.position.y, body.BREATHING_AMPLITUDE])
	await RenderingServer.frame_post_draw
	_screenshot("treadmill_tether_02_halt_breathing")

	print("DONE")
	get_tree().quit()


func _screenshot(name: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = OUTPUT_DIR + name + ".png"
	img.save_png(path)
	print("saved %s" % ProjectSettings.globalize_path(path))
