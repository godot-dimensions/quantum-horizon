extends Node
## TEMPORARY - numerical verification of hip_suspension_solver.gd on
## creature_gallery.tscn's Steed1:
## 1. Flat/level standing: base height converges near
##    limb_prototype_body.gd's own existing static formula value (continuity
##    with the already-verified baseline), pitch/roll settle near zero.
## 2. Synthetic asymmetric case: force only the two front legs PLANTED
##    (direct state manipulation, not waiting for a real gait phase to land
##    on it) and confirm the body pitches to lower the front (sign check).
## 3. Zero planted legs: force ALL legs to LIFTING and confirm no NaN/crash,
##    pose held.
## Not part of the shipped scene - wired in as a temporary autoload with
## creature_gallery.tscn set as the main scene.

const SETTLE_FRAMES := 180


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var flat_plane: Node4D = scene.get_node("FlatPlane")
	var creature: Node = flat_plane.get_node("Steed1")
	var body: Node4D = creature.get_node("Body")
	body.halted = true # Freeze wander so the test isn't fighting live gait/turn motion.

	for i in range(SETTLE_FRAMES):
		await get_tree().physics_frame

	print("=== flat/level standing check ===")
	var static_formula_y: float = 0.5 * 1.0 + 0.5333 * 7.5 # BASE_ANCHOR_DROP*scale + ratio*total_reach, scale=1 (steed).
	print("  body.position.y=%.4f (static formula predicts ~%.4f)" % [body.position.y, static_formula_y])
	var up: Vector4 = body.global_basis.y
	print("  body.global_basis.y=%s (near (0,1,0,0) = level)" % up)

	print("=== synthetic sloped-ground check (all 4 legs planted, front legs' OWN ground height lowered) ===")
	# NOT an asymmetric planted-SET test - on genuinely flat ground, every
	# leg's own independently-computed target height is IDENTICAL regardless
	# of which subset happens to be planted, so there is no pitch signal to
	# find there at all (confirmed directly: an earlier version of this test
	# forced only the front legs planted on flat ground and correctly found
	# zero pitch, because there was never any real height difference to
	# detect - a flaw in the test's own premise, not the solver). Real pitch
	# has to come from an actual ground-height difference under the
	# planted feet, which is what this test drives directly instead.
	var ft_fl = creature.get_node("FootTargetFL")
	var ft_fr = creature.get_node("FootTargetFR")
	var ft_bl = creature.get_node("FootTargetBL")
	var ft_br = creature.get_node("FootTargetBR")
	var front_drop := Vector4(0, -1.0, 0, 0)
	for i in range(120):
		ft_fl.locked_position += front_drop if i == 0 else Vector4.ZERO
		ft_fr.locked_position += front_drop if i == 0 else Vector4.ZERO
		await get_tree().physics_frame
	var up_after: Vector4 = body.global_basis.y
	print("  body.global_basis.y after front-lowered=%s" % up_after)
	# Front legs are at LOCAL +x (BASE_ANCHOR_FORWARD); lowering the front
	# means the body should pitch so that +x reads as pointing DOWNWARD -
	# i.e. global_basis.x should now have a negative y component.
	var forward_dir: Vector4 = body.global_basis.x
	print("  body.global_basis.x=%s (expect negative y - front end dips)" % forward_dir)
	var any_nan_1: bool = is_nan(up_after.x) or is_nan(up_after.y) or is_nan(up_after.z) or is_nan(up_after.w)
	print("  any_nan=%s" % any_nan_1)

	print("=== zero-planted-legs check ===")
	var y_before: float = body.position.y
	for i in range(60):
		ft_fl.state = ft_fl.FootState.LIFTING
		ft_fr.state = ft_fr.FootState.LIFTING
		ft_bl.state = ft_bl.FootState.LIFTING
		ft_br.state = ft_br.FootState.LIFTING
		await get_tree().physics_frame
	var y_after: float = body.position.y
	print("  body.position.y before=%.4f after=%.4f (expect ~unchanged - held, not solved against no data)" % [y_before, y_after])
	var any_nan_2: bool = is_nan(y_after)
	print("  any_nan=%s" % any_nan_2)

	print("DONE")
	get_tree().quit()
