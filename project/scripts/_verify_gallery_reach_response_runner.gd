extends Node
## TEMPORARY - hip_suspension_solver.gd's new reach_response_weight
## defaults ON (0.4) for every user of the shared script, not just the
## motion lab - the gallery's real-wandering steed/hopper/giraffe also
## use it via creature_template.tscn. Confirms this doesn't introduce
## instability (excessive tilt, NaN) there, where reach dynamics come
## from real anchor translation during wander, not belt-slide.

const OBSERVE_FRAMES := 900 # 15s.


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var flat_plane: Node4D = scene.get_node("FlatPlane")

	var max_tilt: Dictionary = {}
	var any_nan: Dictionary = {}
	for creature_name in ["Steed1", "Hopper1", "Giraffe1"]:
		max_tilt[creature_name] = 0.0
		any_nan[creature_name] = false

	for i in range(OBSERVE_FRAMES):
		await get_tree().physics_frame
		for creature_name in ["Steed1", "Hopper1", "Giraffe1"]:
			var creature: Node = flat_plane.get_node(creature_name)
			var body: Node4D = creature.get_node("Body")
			var up: Vector4 = body.global_basis.y
			if is_nan(up.x) or is_nan(up.y) or is_nan(up.z):
				any_nan[creature_name] = true
				continue
			var tilt_deg: float = rad_to_deg(acos(clampf(up.y, -1.0, 1.0)))
			max_tilt[creature_name] = maxf(max_tilt[creature_name], tilt_deg)

	print("=== RESULT over %ds, gallery creatures with reach_response_weight now active ===" % (OBSERVE_FRAMES / 60))
	for creature_name in ["Steed1", "Hopper1", "Giraffe1"]:
		print("  %s: max tilt=%.3fdeg any_nan=%s" % [creature_name, max_tilt[creature_name], any_nan[creature_name]])

	print("DONE")
	get_tree().quit()
