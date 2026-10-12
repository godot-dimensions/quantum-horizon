extends Node
## TEMPORARY - confirms the belt/cadence decoupling fix: (1) leg_index 0
## is now FRONT (matching gait_controller.gd's own FL,FR,BL,BR
## convention, after the pair_index lerp direction fix), (2) each gait
## correctly pushes its own GAIT_BELT_SPEEDS value onto every foot
## target's belt_speed (not body.speed, which should stay fixed at 2.0),
## (3) peak reach stays comfortably mid-range (target: well under 85%,
## nowhere near reach_release_fraction's 0.97) across a real gait window
## for walk/trot/canter_right, unlike the pre-fix trace which climbed
## past 90%. reach_override_count checked too, for the same reason as
## every earlier reach-safety check this session.

const GAITS_TO_CHECK := ["walk", "trot", "canter_right"]
const GAIT_FRAMES := 900 # 15s.


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var root: Node = scene.get_node("FlatPlane/MotionLabCreature")
	var body: Node = root.get_node("Body")

	print("=== leg-index-to-position check ===")
	for i in range(4):
		var anchor: Node4D = body.get_node("LegAnchor%d" % i)
		var role: String = "FRONT" if anchor.position.x > 0 else "BACK"
		var side: String = "LEFT" if anchor.position.z > 0 else "RIGHT"
		print("  LegAnchor%d: x=%.2f z=%.2f -> %s %s" % [i, anchor.position.x, anchor.position.z, role, side])

	for gait_name in GAITS_TO_CHECK:
		body.select_gait(gait_name)
		await get_tree().physics_frame
		var belt_speeds: Array = []
		var j: int = 0
		while true:
			var ft: Node = root.get_node_or_null("FootTarget%d" % j)
			if ft == null:
				break
			belt_speeds.append(ft.belt_speed)
			j += 1
		print("=== gait=%s body.speed=%.2f (should stay 2.0) belt_speeds=%s ===" % [gait_name, body.speed, belt_speeds])

		var peak_reach: float = 0.0
		for i in range(GAIT_FRAMES):
			await get_tree().physics_frame
			var k: int = 0
			while true:
				var ft2: Node = root.get_node_or_null("FootTarget%d" % k)
				if ft2 == null:
					break
				if ft2.state == ft2.FootState.PLANTED:
					var reach_frac: float = (ft2.anchor.global_position - ft2.global_position).length() / ft2.max_reach
					peak_reach = maxf(peak_reach, reach_frac)
				k += 1

		print("  peak reach fraction over %ds: %.1f%% (target: comfortably under 85%%)" % [GAIT_FRAMES / 60, peak_reach * 100.0])
		var m: int = 0
		while true:
			var ft3: Node = root.get_node_or_null("FootTarget%d" % m)
			if ft3 == null:
				break
			print("    FootTarget%d reach_override_count=%d" % [m, ft3.reach_override_count])
			m += 1

	print("DONE")
	get_tree().quit()
