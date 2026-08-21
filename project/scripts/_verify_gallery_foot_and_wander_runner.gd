extends Node
## TEMPORARY - confirms Part 1 (foot segment) and Part 2 (waypoint wander +
## turning) on the creature_gallery.tscn scene: no NaN, foot segment
## orientation actually differs across PLANTED/LIFTING/SWINGING and reacts
## to a real ground normal, waypoints are real 4D (w varies), and the body
## visibly turns toward its own travel direction over time. Not part of the
## shipped scene - wired in as a temporary autoload with
## creature_gallery.tscn set as the main scene.

const SETTLE_FRAMES := 300 # 5s


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var flat_plane: Node4D = scene.get_node("FlatPlane")
	var creature: Node = flat_plane.get_node("Steed1")
	var body: Node4D = creature.get_node("Body")

	print("=== waypoint check ===")
	print("  waypoints: %s" % [body._waypoints])
	var w_varies: bool = false
	for wp in body._waypoints:
		if absf(wp.w) > 0.01:
			w_varies = true
	print("  w varies across waypoints: %s" % w_varies)

	var initial_forward: Vector4 = body.global_basis.x
	print("=== settling %d frames, watching foot orientation + turning ===" % SETTLE_FRAMES)

	var any_nan: bool = false
	var foot_dirs_by_state: Dictionary = {}
	for i in range(SETTLE_FRAMES):
		await get_tree().physics_frame
		for leg_name in ["FL", "FR", "BL", "BR"]:
			var ft = creature.get_node("FootTarget%s" % leg_name)
			var ik_chain = creature.get_node("Body/LimbAnchor%s/IKChain" % leg_name)
			var joint3 = ik_chain.get_node("Joint1/Joint2/Joint3")
			var foot: Node4D = joint3.get_node("Foot")
			var foot_pos: Vector4 = foot.global_position
			var foot_dir: Vector4 = foot.global_basis.y
			if is_nan(foot_pos.x) or is_nan(foot_pos.y) or is_nan(foot_pos.z) or is_nan(foot_pos.w) or is_nan(foot_dir.x):
				any_nan = true
			var state_name: String = ["PLANTED", "LIFTING", "SWINGING"][ft.state]
			var key: String = "%s_%s" % [leg_name, state_name]
			if not foot_dirs_by_state.has(key):
				foot_dirs_by_state[key] = foot_dir

	print("=== foot segment directions observed per state (first sample each) ===")
	for key in foot_dirs_by_state:
		print("  %s: %s" % [key, foot_dirs_by_state[key]])

	# A working, non-frozen foot segment should show a MEANINGFULLY
	# different global_basis.y between at least PLANTED and one of
	# LIFTING/SWINGING for the same leg, not an identical frozen value.
	var any_leg_shows_variation: bool = false
	for leg_name in ["FL", "FR", "BL", "BR"]:
		var planted_key: String = "%s_PLANTED" % leg_name
		for other_state in ["LIFTING", "SWINGING"]:
			var other_key: String = "%s_%s" % [leg_name, other_state]
			if foot_dirs_by_state.has(planted_key) and foot_dirs_by_state.has(other_key):
				var dot: float = foot_dirs_by_state[planted_key].dot(foot_dirs_by_state[other_key])
				if dot < 0.999:
					any_leg_shows_variation = true

	var final_forward: Vector4 = body.global_basis.x
	var travel_dir: Vector4 = body.get_travel_direction()
	var turned_toward_travel: float = final_forward.dot(travel_dir)
	var initial_vs_final_forward_change: float = initial_forward.dot(final_forward)

	print("=== summary ===")
	print("  any_nan=%s" % any_nan)
	print("  any_leg_shows_foot_orientation_variation=%s" % any_leg_shows_variation)
	print("  final body forward . current travel direction = %.4f (closer to 1.0 = well-turned)" % turned_toward_travel)
	print("  initial forward . final forward = %.4f (< 1.0 means the body actually turned at some point)" % initial_vs_final_forward_change)
	print("DONE")
	get_tree().quit()
