extends Node
## TEMPORARY - pathological-case check: does the reach backstop still
## actually work, or did demoting it to "early-release-only" quietly
## disable it? Constructs a deliberately extreme gait config - a VERY long
## closed-gate window (duty_factor=0.9, reference_period_sec=20.0 at the
## body's own default speed, so the gate wouldn't nominally open for 18
## real seconds) - and confirms reach still forces every leg to release
## FAR earlier than that, rather than letting the leg over-extend for 18
## seconds waiting on a gate that was never going to open in time. This is
## exactly the scenario that justified building reach-checking in the first
## place; the point of this run is confirming demoting it to a backstop
## didn't quietly remove its actual function.
##
## Pure numeric check, headless-safe. Not part of the shipped scene - wired
## in as a temporary autoload with limb_prototype_test.tscn set as the main
## scene.

const RUN_SECONDS := 10.0
const NOMINAL_GATE_OPEN_SEC := 18.0 # duty_factor(0.9) * reference_period_sec(20.0) at reference speed - what the gate-open time WOULD be with no backstop.
const LEG_NAMES := ["FL", "FR", "BL", "BR"]


func _reset_chain(ik_chain: Node) -> void:
	for joint in ik_chain.joints:
		joint.global_basis = Projection()


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var flat_plane: Node4D = scene.get_node("FlatPlane")
	var body: Node4D = flat_plane.get_node("Body")
	var gait: Node = flat_plane.get_node("GaitController")
	var foot_targets: Array = [
		flat_plane.get_node("FootTargetFL"),
		flat_plane.get_node("FootTargetFR"),
		flat_plane.get_node("FootTargetBL"),
		flat_plane.get_node("FootTargetBR"),
	]
	var ik_chains: Array = [
		flat_plane.get_node("Body/LimbAnchorFL/IKChain"),
		flat_plane.get_node("Body/LimbAnchorFR/IKChain"),
		flat_plane.get_node("Body/LimbAnchorBL/IKChain"),
		flat_plane.get_node("Body/LimbAnchorBR/IKChain"),
	]

	print("1.nodes_resolve: foot_targets=%s ik_chains=%s gait=%s body_speed=%.3f" % [
		foot_targets.all(func(n): return n != null), ik_chains.all(func(n): return n != null), gait != null, body.speed,
	])

	# Deliberately pathological gait config, set directly (not via
	# apply_preset(), which only knows the two shipped presets) - a gate
	# that would nominally stay closed for 18 real seconds at the body's
	# own default speed.
	gait.reference_speed = body.speed
	gait.reference_period_sec = 20.0
	gait.duty_factor = 0.9
	gait.phase_offsets = [0.0, 0.25, 0.5, 0.75]
	gait.period_sec = gait.reference_period_sec
	gait.phase_progress = 0.0
	print("2.pathological_config: reference_period_sec=%.1f duty_factor=%.2f -> nominal_gate_open_sec=%.1f" % [
		gait.reference_period_sec, gait.duty_factor, gait.reference_period_sec * gait.duty_factor,
	])

	for ik_chain in ik_chains:
		_reset_chain(ik_chain)

	var last_states: Array = []
	var first_release_time: Array = [-1.0, -1.0, -1.0, -1.0]
	var first_release_was_override: Array = [false, false, false, false]
	var override_counts_before: Array = []
	for i in range(4):
		last_states.append(foot_targets[i].state)
		override_counts_before.append(foot_targets[i].reach_override_count)

	var total_frames: int = int(RUN_SECONDS * 60.0)
	for frame in range(total_frames):
		await get_tree().physics_frame
		var t: float = frame / 60.0

		for i in range(4):
			var ft = foot_targets[i]
			if last_states[i] == ft.FootState.PLANTED and ft.state == ft.FootState.LIFTING and first_release_time[i] < 0.0:
				first_release_time[i] = t
				first_release_was_override[i] = ft.reach_override_count > override_counts_before[i]
			last_states[i] = ft.state

	print("3.first_release_time[FL,FR,BL,BR]=%s (expect << %.1fs)" % [first_release_time, NOMINAL_GATE_OPEN_SEC])
	print("4.first_release_was_override[FL,FR,BL,BR]=%s (expect all true - the gate genuinely could not have fired yet)" % [first_release_was_override])

	var all_fired: bool = true
	var all_early: bool = true
	var all_via_override: bool = true
	for i in range(4):
		if first_release_time[i] < 0.0:
			all_fired = false
		elif first_release_time[i] >= NOMINAL_GATE_OPEN_SEC:
			all_early = false
		if not first_release_was_override[i]:
			all_via_override = false

	print("5.all_legs_released_within_%.0fs=%s all_releases_earlier_than_nominal_gate=%s all_releases_via_reach_override=%s" % [
		RUN_SECONDS, all_fired, all_early, all_via_override,
	])
	print("DONE")
	get_tree().quit()
