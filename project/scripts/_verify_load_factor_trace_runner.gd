extends Node
## TEMPORARY - confirms load_factor actually ramps smoothly (0 while
## airborne, easing up after touchdown, easing down before its own next
## predicted liftoff) rather than just trusting the formula on paper.
## Traces one leg (FootTarget0) through a couple of full cycles.

const OBSERVE_FRAMES := 300 # 5s.


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var root: Node = scene.get_node("FlatPlane/MotionLabCreature")
	var body: Node = root.get_node("Body")
	var ft0: Node = root.get_node("FootTarget0")

	body.select_gait("walk")
	for i in range(150): # 2.5s past the gait-switch transient.
		await get_tree().physics_frame

	var last_state: int = -1
	for i in range(OBSERVE_FRAMES):
		await get_tree().physics_frame
		if int(ft0.state) != last_state or i % 15 == 0:
			var state_name: String = ["PLANTED", "LIFTING", "SWINGING"][ft0.state]
			print("frame %d: state=%s load_factor=%.4f" % [i, state_name, ft0.load_factor])
			last_state = int(ft0.state)

	print("DONE")
	get_tree().quit()
