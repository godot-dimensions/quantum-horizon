extends Node
## TEMPORARY - prints each creature class's actual per-leg link_lengths as
## built by limb_prototype_body.gd's _apply_creature_class(), to confirm
## directly (not by re-reading the formula) that the unequal femur:tibia:
## cannon ratios per class are genuinely active, not flattened to equal
## segments anywhere downstream. Wired in as a temporary autoload with
## creature_gallery.tscn set as the main scene.


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var flat_plane: Node4D = scene.get_node("FlatPlane")
	print("=== per-class segment length check ===")
	for creature_name in ["Steed1", "Hopper1", "Giraffe1"]:
		var creature: Node = flat_plane.get_node(creature_name)
		var body: Node4D = creature.get_node("Body")
		print("--- %s (class=%s, scale=%.2f) ---" % [creature_name, body.creature_class, body.CREATURE_CLASSES[body.creature_class]["scale"]])
		for leg_name in ["FL", "BL"]:
			var ik_chain = creature.get_node("Body/LimbAnchor%s/IKChain" % leg_name)
			var lengths: Array = ik_chain.link_lengths
			var ratios_normalized: Array = []
			var total: float = 0.0
			for l in lengths:
				total += l
			for l in lengths:
				ratios_normalized.append(l / total)
			var all_equal: bool = true
			for l in lengths:
				if not is_equal_approx(l, lengths[0]):
					all_equal = false
			print("  %s: lengths=%s ratios=%s all_equal=%s" % [leg_name, lengths, ratios_normalized, all_equal])
	print("DONE")
	get_tree().quit()
