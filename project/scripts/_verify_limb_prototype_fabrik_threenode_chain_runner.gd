extends Node
## TEMPORARY - logs FL's gait phase, foot-target position, and the
## position the IK chain actually solved against, all frame-tagged, for a
## short mid-swing window - checking whether the whole three-node chain
## (GaitController -> FootTarget -> IKChain) is reading consistent,
## same-frame values, or whether a skew exists somewhere in it, before
## assuming which specific link is broken.
##
## Not part of the shipped scene - wired in as a temporary autoload with
## limb_prototype_treadmill.tscn set as the main scene.

const LOG_FRAMES := 30
const MAX_WAIT_FRAMES := 3600


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var flat_plane: Node4D = scene.get_node("FlatPlane")
	var ft = flat_plane.get_node("FootTargetFL")
	var chain = flat_plane.get_node("Body/LimbAnchorFL/IKChain")
	var gait = flat_plane.get_node("GaitController")

	var reached: bool = false
	for frame in range(MAX_WAIT_FRAMES):
		await get_tree().physics_frame
		if ft.state == ft.FootState.SWINGING:
			reached = true
			break

	if not reached:
		print("Never reached SWINGING within %d frames - aborting." % MAX_WAIT_FRAMES)
		print("DONE")
		get_tree().quit()
		return

	print("=== three-node chain trace (FL, %d frames from SWINGING start) ===" % LOG_FRAMES)
	print("columns: frame | gait.phase_progress | FL.local_phase | ft.global_position (live) | chain.last_solved_target_pos (what IK actually used) | delta(ft vs solved) | residual")
	for i in range(LOG_FRAMES):
		var local_phase: float = fmod(gait.phase_progress + gait.phase_offsets[ft.leg_index], 1.0)
		var effector: Vector4 = chain._end_effector_position()
		var residual: float = (ft.global_position - effector).length()
		var target_delta: float = (ft.global_position - chain.last_solved_target_pos).length()
		print("frame=%d state=%d phase_progress=%.6f local_phase=%.6f ft_pos=%s solved_pos=%s target_delta=%.6f residual=%.5f" % [
			i, ft.state, gait.phase_progress, local_phase, ft.global_position, chain.last_solved_target_pos, target_delta, residual,
		])
		await get_tree().physics_frame

	print("DONE")
	get_tree().quit()
