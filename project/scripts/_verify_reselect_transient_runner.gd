extends Node
## TEMPORARY - checks whether RE-selecting an already-active gait (e.g.
## pressing "1" for walk a second time while already walking, which a
## real play session naturally does while comparing/testing) produces a
## worse transient with today's load_factor-weighted hip suspension than
## the already-known, already-accepted "one leg fires early" gate
## transient alone did. Traces tilt and all 4 legs' load_factor right
## around the re-selection instant.

func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var root: Node = scene.get_node("FlatPlane/MotionLabCreature")
	var body: Node = root.get_node("Body")

	body.select_gait("walk")
	for i in range(200): # ~3.3s into a normal walk cycle - well past the initial transient.
		await get_tree().physics_frame

	print("=== RE-SELECTING walk while already mid-cycle (frame 200) ===")
	body.select_gait("walk") # Same call a real key-press would make.

	for i in range(120): # 2s after re-selection.
		await get_tree().physics_frame
		var up: Vector4 = body.global_basis.y
		var tilt_deg: float = rad_to_deg(acos(clampf(up.y, -1.0, 1.0)))
		var loads: Array = []
		for j in range(4):
			var ft: Node = root.get_node("FootTarget%d" % j)
			loads.append("%.2f" % ft.load_factor)
		if i < 20 or i % 10 == 0:
			print("  frame %d: tilt=%.3fdeg loads=%s body.position.y=%.3f" % [i, tilt_deg, loads, body.position.y])

	print("DONE")
	get_tree().quit()
