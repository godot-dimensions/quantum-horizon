extends Node
## TEMPORARY - the new 0.8 standing_utilization_ratio (up from ~0.53)
## deliberately eats more of each leg's reach budget just standing still.
## This project has ALREADY measured, once before, that too little
## remaining slack causes the reach-release backstop
## (limb_prototype_foot_target.gd's own reach_release_fraction=0.97 safety
## net) to fire far more often than the phase gate alone intends (hopper's
## front legs at ~89% standing utilization, back when body height was
## sized off the wrong leg). Confirms directly that 0.8 does NOT reproduce
## that failure mode on any of the 3 creature classes across a real gait
## cycle, rather than assuming the earlier "sized off the front leg's own
## reach" fix generalizes safely on its own. Wired in as a temporary
## autoload with creature_gallery.tscn set as the main scene.

const GAIT_FRAMES := 600 # 10s.


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var flat_plane: Node4D = scene.get_node("FlatPlane")

	for i in range(GAIT_FRAMES):
		await get_tree().physics_frame

	print("=== reach_override_count after a real %ds gait window, all classes ===" % (GAIT_FRAMES / 60))
	for creature_name in ["Steed1", "Hopper1", "Giraffe1"]:
		var creature: Node = flat_plane.get_node(creature_name)
		for leg_name in ["FL", "FR", "BL", "BR"]:
			var ft = creature.get_node("FootTarget%s" % leg_name)
			print("  %s/%s: reach_override_count=%d, max_reach=%.3f" % [creature_name, leg_name, ft.reach_override_count, ft.max_reach])

	print("DONE")
	get_tree().quit()
