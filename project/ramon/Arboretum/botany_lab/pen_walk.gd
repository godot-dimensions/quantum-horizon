extends RefCounted

## WATER LAB: the playable world's walk, on the Water Lab's player (Ramon, 9 Oct: "make sure we're using
## Andrew's walker and W rotation settings from the playable world"). The scripts are the pen's own,
## carried at e4ff9cb (Andrew's stepping and facing through W are the only walk there since then:
## carried/LabKit/carried/chickenpen/scripts/block_walker_character_4d.gd, pen_orbit_rig_4d.gd,
## ground_basis_4d.gd), but the lab's player builder (carried/kit/kit_player.gd over LabKit/
## lab_player.gd) set its own: no stepping through W on Q/E, a slower walk, a soft start. The pen's
## Player sets none of them, so these are the walker's own defaults, as in playable_world.tscn.
##
## NO class_name (engine_gotchas.md).

const WALK := {"walk_speed": 1.4, "run_speed": 3.0, "sprint_speed": 4.2, "acceleration": 12.0, "turn_speed": 11.0, "w_speed_scale": 0.3}


static func apply(body: Node) -> void:
	for k in WALK:
		body.set(k, WALK[k])
