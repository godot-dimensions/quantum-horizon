extends Node4D
## Rail mode's fixed target lineup: 5 authored positions along the ride's
## path (see rail_controller.gd), a deliberate mix of w=0 and nonzero-w -
## same "test whether 4D navigation is needed, not just aim" principle
## every other mode in this project already uses (W-targeting, Contest
## mode's w=+-3 pairs). Fixed for a single ride, not randomized or
## respawned mid-run like the old single-target bullseye spawner's infinite
## loop - each target exists once per ride; reset_all() is what brings them
## all back for the next one.

const TargetScript := preload("res://sandbox/shooting_gallery/bullseye/bullseye_target.gd")

## Authored positions along the ride, ordered start-to-end - x/y/w vary for
## visual and navigational variety, z tracks the ride's own progress along
## the path (see rail_controller.gd's PATH_START/PATH_END, z=3 to z=-12).
const TARGET_POSITIONS: Array[Vector4] = [
	Vector4(2.0, 1.5, 0.0, 0.0),
	Vector4(-2.0, 1.5, -3.0, 2.5),
	Vector4(2.0, 1.5, -6.0, -2.5),
	Vector4(-2.0, 1.5, -9.0, 0.0),
	Vector4(0.0, 1.5, -11.5, 3.0),
]

var _targets: Array = []


func _ready() -> void:
	reset_all()


## Called by bullseye_weapon.gd with the projectile hit's body and impact
## point. Returns {"hit": bool, "ring_score": int, "slice_score_percent":
## int} - self-contained (the scores are computed here, not left for the
## caller to dig out of a "_current_target" reference) since a rail target
## is consumed once and never individually respawned mid-run, unlike the
## old single-target spawner's try_hit_target()/respawn() pair.
func try_hit_target(hit_body: Object, global_point: Vector4) -> Dictionary:
	for target in _targets:
		if target == hit_body:
			var result := {
				"hit": true,
				"ring_score": target.get_ring_score(global_point),
				"slice_score_percent": roundi(target.get_alignment_t() * 100.0),
			}
			_targets.erase(target)
			target.queue_free()
			return result
	return {"hit": false, "ring_score": 0, "slice_score_percent": 0}


## Called by rail_controller.gd once a completed ride's results have been
## shown - clears any targets left over from the last run (unhit ones) and
## spawns a fresh set at the same authored positions, ready for the next ride.
func reset_all() -> void:
	for target in _targets:
		if is_instance_valid(target):
			target.queue_free()
	_targets.clear()
	for target_position in TARGET_POSITIONS:
		var target := Area4D.new()
		target.set_script(TargetScript)
		add_child(target)
		target.position = target_position
		_targets.append(target)
