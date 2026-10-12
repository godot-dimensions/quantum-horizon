extends SceneTree

## Splits one chain's build time into phases, so effort goes where the time is.
##
## The brachiosaurus costs about 165 ms per dragged frame even with the diagnostics
## off, and there are three plausible culprits: generating the vertices, splitting the
## prisms into cells, and the winding pass, which builds a dictionary holding four
## face keys per cell and then walks it. Guessing between them would be a good way to
## optimize the wrong one.

const _Builder = preload("res://ramon/Model/scripts/loft_builder_4d.gd")
const _RUNS: int = 5

var _instance: Node
var _done: bool = false


func _initialize() -> void:
	_instance = (load("res://ramon/Model/model.tscn") as PackedScene).instantiate()
	root.add_child(_instance)


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var rig: Node = _instance.get_node("Models/Brachio/Spine")
	rig.verbose = false

	# The rig's longest chain, which is where most of its cells come from.
	var chains: Array = rig._collect_chains()
	var longest: Array = []
	for chain in chains:
		if chain.size() > longest.size():
			longest = chain
	var sections: Array = []
	for ball in longest:
		var section: Dictionary = ball.get_loft_section()
		section["center"] = rig._position_in_rig(ball)
		sections.append(section)
	sections = _Builder.subdivide_long_spans(sections)
	print("longest chain: %d balls -> %d sections after subdivision" % [longest.size(), sections.size()])

	var profile: Dictionary = _time("build_profile_surface", func():
		return _Builder.build_profile_surface(rig.profile_rings, rig.profile_sides))
	_time("build_frames", func():
		return _Builder.build_frames(sections, rig.align_to_spine))

	# A whole build, to get the cells to hand the winding pass.
	var mesh: ArrayTetraMesh4D = _Builder.build(
		sections, rig.profile_rings, rig.profile_sides, true, false, rig.align_to_spine, 1, false)
	var cells: PackedInt32Array = mesh.get_simplex_cell_vertex_indices()
	var positions: PackedVector4Array = mesh.get_vertex_positions()
	print("chain has %d cells, %d vertices" % [cells.size() / 4, positions.size()])

	_time("make_winding_consistent", func():
		var copy: PackedInt32Array = cells.duplicate()
		return _Builder.make_winding_consistent(copy, positions, false))
	_time("check_watertight (diagnostic)", func():
		return _Builder.check_watertight(cells, false))
	_time("whole build, no checks", func():
		return _Builder.build(sections, rig.profile_rings, rig.profile_sides, true, false, rig.align_to_spine, 1, false))
	return true


func _time(label: String, work: Callable) -> Variant:
	var result: Variant = null
	var total: int = 0
	for run in range(_RUNS):
		var start: int = Time.get_ticks_usec()
		result = work.call()
		total += Time.get_ticks_usec() - start
	print("   %-32s %8.1f ms" % [label, float(total) / float(_RUNS) / 1000.0])
	return result
