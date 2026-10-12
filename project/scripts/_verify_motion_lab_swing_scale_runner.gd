extends Node
## TEMPORARY - confirms the gait-scaled swing-duration fix: (1) each
## gait's lift/swing duration lands at the expected computed value, (2)
## the fraction of time each leg spends airborne is now a much bigger,
## more visible share of the cycle (target: noticeably more than the old
## fixed 0.5s/period ratio), (3) max simultaneous airborne legs still
## matches each gait's own expected shape (walk<=1, trot/canter<=2) -
## lengthening swing duration well past gait_controller.gd's built-in
## FIXED_STEP_DURATION_SEC=0.5 assumption needs this re-checked directly,
## not assumed safe from the old (now-stale) ceiling math.

const GAITS_TO_CHECK := ["walk", "trot", "canter_right"]
const GAIT_FRAMES := 900 # 15s.
const MAX_EXPECTED_AIRBORNE := {"walk": 1, "trot": 2, "canter_right": 2}


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var root: Node = scene.get_node("FlatPlane/MotionLabCreature")
	var body: Node = root.get_node("Body")

	for gait_name in GAITS_TO_CHECK:
		body.select_gait(gait_name)
		await get_tree().physics_frame
		var ft0: Node = root.get_node("FootTarget0")
		print("=== gait=%s lift=%.3fs swing=%.3fs (total=%.3fs) ===" % [gait_name, ft0.lift_duration_sec, ft0.swing_duration_sec, ft0.lift_duration_sec + ft0.swing_duration_sec])

		var airborne_frames: int = 0
		var ft0_airborne_frames: int = 0
		var max_airborne: int = 0
		var max_airborne_frames: Array = []
		var overlap_after_frame_60: bool = false
		for i in range(GAIT_FRAMES):
			await get_tree().physics_frame
			var airborne: int = 0
			var j: int = 0
			while true:
				var ft: Node = root.get_node_or_null("FootTarget%d" % j)
				if ft == null:
					break
				if ft.state != ft.FootState.PLANTED:
					airborne += 1
					if j == 0:
						ft0_airborne_frames += 1
				j += 1
			if airborne > 0:
				airborne_frames += 1
			if airborne > max_airborne:
				max_airborne = airborne
				max_airborne_frames = [i]
			elif airborne == max_airborne and airborne > MAX_EXPECTED_AIRBORNE.get(gait_name, 0):
				max_airborne_frames.append(i)
			if airborne > MAX_EXPECTED_AIRBORNE.get(gait_name, 0) and i > 60:
				overlap_after_frame_60 = true

		var any_leg_airborne_fraction: float = float(airborne_frames) / float(GAIT_FRAMES)
		var ft0_fraction: float = float(ft0_airborne_frames) / float(GAIT_FRAMES)
		print("  fraction of time with >=1 leg airborne: %.1f%% | FootTarget0's own airborne fraction: %.1f%% (old fixed-0.5s system was ~12-40%% depending on gait)" % [any_leg_airborne_fraction * 100.0, ft0_fraction * 100.0])
		print("  max simultaneous airborne: %d (expected <= %d) at frames %s | recurs after frame 60 (i.e. NOT just a gait-switch transient): %s" % [max_airborne, MAX_EXPECTED_AIRBORNE[gait_name], max_airborne_frames, overlap_after_frame_60])
		var m: int = 0
		while true:
			var ft2: Node = root.get_node_or_null("FootTarget%d" % m)
			if ft2 == null:
				break
			print("    FootTarget%d reach_override_count=%d" % [m, ft2.reach_override_count])
			m += 1

	print("DONE")
	get_tree().quit()
