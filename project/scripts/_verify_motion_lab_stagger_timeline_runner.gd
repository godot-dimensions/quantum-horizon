extends Node
## TEMPORARY - prints the EXACT frame/time of every state transition
## (PLANTED->LIFTING, LIFTING->SWINGING, SWINGING->PLANTED) for all 4 legs
## through 2 full walk cycles, to directly see whether the 4 legs'
## swings are evenly staggered (as walk's phase_offsets [0,0.25,0.5,0.75]
## intend - one swing roughly every period_sec/4 seconds) or bunched
## together with a long gap - a reported "long pause then all 4 move in
## an accelerated burst" symptom, checked directly rather than inferred
## from aggregate statistics (which looked fine in aggregate but could
## still hide a real clustering pattern).

const OBSERVE_FRAMES := 540 # 9s - a bit over 2 full walk cycles (period 4.0s).


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var root: Node = scene.get_node("FlatPlane/MotionLabCreature")
	var body: Node = root.get_node("Body")
	var gc: Node = root.get_node("GaitController")

	body.select_gait("walk")
	print("gait_controller: duty_factor=%.3f period_sec=%.3f phase_offsets=%s" % [gc.duty_factor, gc.period_sec, gc.phase_offsets])

	var last_states: Array = [-1, -1, -1, -1]
	for i in range(OBSERVE_FRAMES):
		await get_tree().physics_frame
		var t: float = float(i) / 60.0
		for leg in range(4):
			var ft: Node = root.get_node("FootTarget%d" % leg)
			if int(ft.state) != last_states[leg]:
				var state_name: String = ["PLANTED", "LIFTING", "SWINGING"][ft.state]
				print("t=%.3fs (frame %d): leg %d -> %s (gait phase_progress=%.4f)" % [t, i, leg, state_name, gc.phase_progress])
				last_states[leg] = int(ft.state)

	print("DONE")
	get_tree().quit()
