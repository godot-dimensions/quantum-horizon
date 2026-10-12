extends Node
## TEMPORARY - companion to _verify_resting_fraction_reach_check_runner.gd,
## but for the motion lab's dynamically-built rig (limb_prototype_treadmill.
## tscn / motion_lab_creature.gd) rather than the gallery's static
## creature_template.tscn instances. The motion lab's legs are all uniform
## (no front/back asymmetry the way hopper has), so there's no a priori
## reason to expect the same overfiring - confirming that directly rather
## than assuming symmetry makes it safe on its own.

const GAIT_FRAMES := 600 # 10s.


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var root: Node = scene.get_node("FlatPlane/MotionLabCreature")

	# Motion lab spawns halted=true (idle rest pose) by default - a real
	# user picks a gait immediately, so match that rather than measuring
	# 10s of a creature that never actually walks.
	var body: Node = root.get_node("Body")
	body.select_gait("walk")

	for i in range(GAIT_FRAMES):
		await get_tree().physics_frame

	print("=== motion lab reach_override_count after a real %ds gait window ===" % (GAIT_FRAMES / 60))
	var i: int = 0
	while true:
		var ft: Node = root.get_node_or_null("FootTarget%d" % i)
		if ft == null:
			break
		print("  FootTarget%d: reach_override_count=%d, max_reach=%.3f" % [i, ft.reach_override_count, ft.max_reach])
		i += 1

	print("DONE")
	get_tree().quit()
