extends Node
## TEMPORARY - confirms hop's removal from the motion lab didn't break
## anything: walk/trot/canter still select correctly with their own
## GAIT_SPEEDS value, hop is now a no-op (current_gait stays whatever it
## was, doesn't silently crash or half-apply), and the generalized
## (limb_count != 4) path still works with only "walk" in GENERAL_GAITS.

func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var root: Node = scene.get_node("FlatPlane/MotionLabCreature")
	var body: Node = root.get_node("Body")

	for gait_name in ["walk", "trot", "canter_right", "canter_left"]:
		body.select_gait(gait_name)
		await get_tree().physics_frame
		print("select_gait(%s) -> current_gait=%s speed=%.3f halted=%s" % [gait_name, body.current_gait, body.speed, body.halted])

	print("--- attempting hop (should no-op, current_gait/speed unchanged) ---")
	var before_gait: String = body.current_gait
	var before_speed: float = body.speed
	body.select_gait("hop")
	await get_tree().physics_frame
	print("after select_gait(hop): current_gait=%s (was %s) speed=%.3f (was %.3f)" % [body.current_gait, before_gait, body.speed, before_speed])

	print("--- generalized path (limb_count=6) ---")
	body.set_limb_count(1) # 4 -> 6
	await get_tree().physics_frame
	print("limb_count=%d current_gait=%s" % [body.limb_count, body.current_gait])
	body.select_gait("walk")
	await get_tree().physics_frame
	for i in range(120):
		await get_tree().physics_frame
	print("6-limb walk ran 2s with no errors; speed=%.3f" % body.speed)

	print("DONE")
	get_tree().quit()
