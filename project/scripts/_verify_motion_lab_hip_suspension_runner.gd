extends Node
## TEMPORARY - confirms hip_suspension_solver.gd behaves correctly wired
## into motion_lab_creature.gd's dynamic rebuild flow: stable/orthonormal
## basis and no NaN through a real (non-halted) walk cycle, survives a
## limb_count/segment_count rebuild (new leg_foot_target_paths re-pointed
## correctly), and stays clean through "hop" (all legs swing in sync,
## genuinely exercising the zero-planted-legs fallback for real, not
## synthetically). Wired in as a temporary autoload with
## limb_prototype_treadmill.tscn set as the main scene.


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _check(body: Node4D, label: String) -> void:
	var b: Projection = body.global_basis
	var any_nan: bool = is_nan(body.position.y) or is_nan(b.x.x) or is_nan(b.y.y) or is_nan(b.z.z)
	var orthonormal: bool = is_equal_approx(b.x.length(), 1.0) and is_equal_approx(b.y.length(), 1.0) and absf(b.x.dot(b.y)) < 0.001
	print("  [%s] y=%.4f any_nan=%s orthonormal=%s" % [label, body.position.y, any_nan, orthonormal])


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var flat_plane: Node4D = scene.get_node("FlatPlane")
	var body: Node4D = flat_plane.get_node("MotionLabCreature/Body")

	for i in range(90):
		await get_tree().physics_frame

	body.select_gait("walk")
	print("=== real walk cycle (default 4x3) ===")
	for i in range(180):
		await get_tree().physics_frame
	_check(body, "walk 4x3")

	print("=== rebuild to 6x2, confirm solver survives re-pointed leg paths ===")
	body.set_limb_count(1) # 4 -> 6
	body.set_segment_count(-1) # 3 -> 2
	body.select_gait("walk")
	for i in range(180):
		await get_tree().physics_frame
	_check(body, "walk 6x2 after rebuild")

	print("=== hop gait (all legs swing in sync - real zero-planted-legs moments) ===")
	body.select_gait("hop")
	for i in range(180):
		await get_tree().physics_frame
	_check(body, "hop 6x2")

	print("DONE")
	get_tree().quit()
