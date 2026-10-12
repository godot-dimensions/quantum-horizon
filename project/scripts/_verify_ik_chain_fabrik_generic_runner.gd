extends Node
## TEMPORARY - verifies FABRIK's arbitrary-chain-length support using the
## SAME ik_chain_controller.gd code path for a 2-joint and a 5-joint chain,
## no special-casing either way (per the replacement's own design goal).
## Also isolates whether the core solve+apply logic converges correctly
## against a STATIC target at all, decoupled from the limb rig's extra
## complexity (moving anchor, moving target, gait-cycle timing) - if this
## fails too, the bug is in the core algorithm, not something specific to
## the gait scenario.
##
## Wired in as a temporary autoload with ik_chain_generic_test.tscn set as
## the main scene (NOT limb_prototype_treadmill.tscn - swap project.godot's
## run/main_scene back after this runs).

const SETTLE_FRAMES := 10 # solve_fabrik() fully converges every single frame now - no easing to wait out.
const CONVERGENCE_TOLERANCE := 0.05


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var scene: Node4D = get_tree().current_scene
	var chain2: Node4D = scene.get_node("Chain2/IKChain")
	var target2: Node4D = scene.get_node("Chain2/Target2")
	var chain5: Node4D = scene.get_node("Chain5/IKChain")
	var target5: Node4D = scene.get_node("Chain5/Target5")

	for i in range(SETTLE_FRAMES):
		await get_tree().physics_frame

	var residual2: float = (chain2._end_effector_position() - target2.global_position).length()
	var residual5: float = (chain5._end_effector_position() - target5.global_position).length()
	print("=== 2-joint chain (static target) ===")
	print("  residual=%.5f (threshold=%.2f, %s)" % [residual2, CONVERGENCE_TOLERANCE, "OK" if residual2 <= CONVERGENCE_TOLERANCE else "EXCEEDED"])
	print("=== 5-joint chain (static target) ===")
	print("  residual=%.5f (threshold=%.2f, %s)" % [residual5, CONVERGENCE_TOLERANCE, "OK" if residual5 <= CONVERGENCE_TOLERANCE else "EXCEEDED"])

	# Repeat-call sanity check, isolated from any per-frame drift entirely -
	# confirms the SOLVE itself is stable/idempotent at its own fixed point.
	chain2.solve_fabrik()
	chain5.solve_fabrik()
	var repeat_residual2: float = (chain2._end_effector_position() - target2.global_position).length()
	var repeat_residual5: float = (chain5._end_effector_position() - target5.global_position).length()
	print("=== repeat-call sanity check ===")
	print("  2-joint residual=%.5f  5-joint residual=%.5f (both should be near fabrik_tolerance=0.01)" % [repeat_residual2, repeat_residual5])

	print("DONE")
	get_tree().quit()
