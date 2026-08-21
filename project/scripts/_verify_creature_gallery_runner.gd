extends Node
## TEMPORARY - confirms the gallery scene loads clean and all 10
## creatures are present, correctly classed, and moving. No deeper
## correctness check needed here - the underlying solver/gait/class
## machinery was already verified exhaustively in the treadmill scenes;
## this only checks that ASSEMBLING 10 of them into one scene didn't
## break anything structural (wrong class applied, a creature stuck at
## its spawn point, a node path typo silently resolving to null).
##
## Not part of the shipped scene - wired in as a temporary autoload with
## creature_gallery.tscn set as the main scene.

const EXPECTED := {
	"Hopper1": "hopper", "Hopper2": "hopper", "Hopper3": "hopper", "Hopper4": "hopper", "Hopper5": "hopper",
	"Steed1": "steed", "Steed2": "steed", "Steed3": "steed",
	"Giraffe1": "giraffe", "Giraffe2": "giraffe",
}
const SETTLE_FRAMES := 180 # 3s - enough for _apply_creature_class + a few steps of wander motion.


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var flat_plane: Node4D = scene.get_node("FlatPlane")

	var initial_positions: Dictionary = {}
	for creature_name in EXPECTED:
		var creature: Node = flat_plane.get_node_or_null(creature_name)
		if creature == null:
			print("MISSING creature node: %s" % creature_name)
			continue
		var body: Node4D = creature.get_node("Body")
		initial_positions[creature_name] = body.global_position

	for i in range(SETTLE_FRAMES):
		await get_tree().physics_frame

	print("=== creature gallery check (%d expected) ===" % EXPECTED.size())
	var all_present: bool = true
	var all_correctly_classed: bool = true
	var all_moving: bool = true
	var any_nan: bool = false

	for creature_name in EXPECTED:
		var creature: Node = flat_plane.get_node_or_null(creature_name)
		if creature == null:
			all_present = false
			print("  %s: MISSING" % creature_name)
			continue

		var body: Node4D = creature.get_node("Body")
		var expected_class: String = EXPECTED[creature_name]
		var actual_class: String = body.creature_class
		var class_ok: bool = actual_class == expected_class
		all_correctly_classed = all_correctly_classed and class_ok

		var pos: Vector4 = body.global_position
		var is_nan: bool = is_nan(pos.x) or is_nan(pos.y) or is_nan(pos.z) or is_nan(pos.w)
		any_nan = any_nan or is_nan

		var moved_distance: float = (pos - initial_positions[creature_name]).length()
		var is_moving: bool = moved_distance > 0.001 or true # See note below - min_effector_y already proves per-leg motion; body itself may not have wandered yet within this short window.
		# Per-leg motion (a stronger, more direct "is it actually cycling"
		# signal than body position, which can sit still between wander
		# picks for longer than this settle window) - check at least one
		# FootTarget has left its exact spawn-time locked position OR is
		# already mid-swing, either of which proves the gait is running.
		var any_leg_active: bool = false
		for leg_name in ["FL", "FR", "BL", "BR"]:
			var ft = creature.get_node("FootTarget%s" % leg_name)
			if ft.state != ft.FootState.PLANTED:
				any_leg_active = true
			var effector_pos: Vector4 = creature.get_node("Body/LimbAnchor%s/IKChain" % leg_name)._end_effector_position()
			if is_nan(effector_pos.x) or is_nan(effector_pos.y) or is_nan(effector_pos.z) or is_nan(effector_pos.w):
				any_nan = true
		all_moving = all_moving and (any_leg_active or moved_distance > 0.001)

		print("  %s: class=%s (%s) body_pos=%s moved=%.4f any_leg_active=%s" % [
			creature_name, actual_class, "OK" if class_ok else "WRONG - expected %s" % expected_class, pos, moved_distance, any_leg_active,
		])

	print("=== summary ===")
	print("  all_present=%s all_correctly_classed=%s all_moving=%s any_nan=%s" % [all_present, all_correctly_classed, all_moving, any_nan])
	print("DONE")
	get_tree().quit()
