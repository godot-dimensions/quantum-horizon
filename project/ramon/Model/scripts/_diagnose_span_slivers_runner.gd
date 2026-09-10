extends SceneTree

## Asks whether slivers are spread across a model or concentrated on a few spans.
##
## This decides which fix is honest. Raising `smoothing` subdivides EVERY span in a
## rig, so if only two spans are bad it is paying everywhere for a fault in two
## places. Adding a ball on the offending span costs almost nothing by comparison.
##
## Prints, for every span of every rig, the gap between the two balls, how wide they
## are, the ratio between those, and how many slivers the span produced - so the
## relationship between the ratio and the failure is visible rather than asserted.

const _Builder = preload("res://ramon/Model/scripts/loft_builder_4d.gd")

var _instance: Node
var _done: bool = false


func _initialize() -> void:
	_instance = (load("res://ramon/Model/model.tscn") as PackedScene).instantiate()
	root.add_child(_instance)


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	for group in _instance.get_node("Models").get_children():
		for rig in group.get_children():
			if rig is MeshInstance4D and rig.has_method("build"):
				_report("%s/%s" % [group.name, rig.name], rig)
	return true


func _report(label: String, rig: Node) -> void:
	# Rebuild each chain on its own so a span can be tied to the cells it made.
	var chains: Array = rig._collect_chains()
	var total_slivers: int = 0
	var bad_spans: int = 0
	var lines: Array = []
	for chain_index in range(chains.size()):
		var chain: Array = chains[chain_index]
		if chain.size() < 2:
			continue
		var sections: Array = []
		for ball in chain:
			var section: Dictionary = ball.get_loft_section()
			section["center"] = rig._position_in_rig(ball)
			sections.append(section)
		for span in range(sections.size() - 1):
			var pair: Array = [sections[span], sections[span + 1]]
			var mesh: ArrayTetraMesh4D = _Builder.build(
				pair, rig.profile_rings, rig.profile_sides, false, false, rig.align_to_spine, 1)
			if mesh == null:
				continue
			var slivers: int = _slivers(mesh)
			total_slivers += slivers
			var gap: float = (pair[0]["center"] as Vector4).distance_to(pair[1]["center"])
			var width: float = (pair[0]["radius"] + pair[1]["radius"]) * 0.5
			if slivers > 0:
				bad_spans += 1
				lines.append("   chain %d span %s->%s: gap %.2f, width %.2f, ratio %.1f, %d slivers" % [
					chain_index, chain[span].name, chain[span + 1].name,
					gap, width, gap / maxf(width, 0.0001), slivers])
				# How many balls would have to go ON THIS SPAN to clear it. Subdividing
				# the span is exactly what inserting balls along it does, so this reads
				# straight off as "add N balls here".
				for extra in [1, 2, 3]:
					var split: ArrayTetraMesh4D = _Builder.build(
						pair, rig.profile_rings, rig.profile_sides, false, false,
						rig.align_to_spine, extra + 1)
					if split == null:
						continue
					var left: int = _slivers(split)
					lines.append("      + %d ball(s) on this span -> ratio %.1f, %d slivers, %d tets  %s" % [
						extra, gap / float(extra + 1) / maxf(width, 0.0001), left,
						split.get_simplex_cell_vertex_indices().size() / 4,
						"CLEAR" if left == 0 else "still broken"])
	if total_slivers == 0:
		return
	print("%s: %d slivers, on %d of its spans" % [label, total_slivers, bad_spans])
	for line in lines:
		print(line)


func _slivers(mesh: ArrayTetraMesh4D) -> int:
	var cells: PackedInt32Array = mesh.get_simplex_cell_vertex_indices()
	var positions: PackedVector4Array = mesh.get_vertex_positions()
	var count: int = 0
	for cell in range(cells.size() / 4):
		if _Builder._cell_shape(
				positions[cells[cell * 4]], positions[cells[cell * 4 + 1]],
				positions[cells[cell * 4 + 2]], positions[cells[cell * 4 + 3]]) <= 0.00001:
			count += 1
	return count
