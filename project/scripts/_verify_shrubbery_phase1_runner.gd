extends Node
## TEMPORARY - Phase 1 verification of the shrubbery port (see the
## approved plan): pure-GDScript algorithm, no rendering. Checks:
## 1. Voxel count is a plausible order of magnitude (not near-zero, not
##    absurdly large).
## 2. Bounding-box W extent as a FRACTION of X/Y/Z extent, not just
##    checked nonzero - a technically-nonzero-but-negligible sliver must
##    be caught here per the plan's own sharpened done-criterion.
## 3. Re-running the same seed reproduces an identical voxel set
##    (determinism).
## 4. w_lean_strength=0 with tesseract-sampled attractors ALONE is
##    measured for how much w-branching it already produces on its own,
##    before assuming the parameter's authored range needs to be large -
##    the two mechanisms (attractor pull, now genuinely 4D, and explicit
##    w-lean) could otherwise compose in an unstated way.

func _ready() -> void:
	_run()
	print("DONE")
	get_tree().quit()


func _run() -> void:
	var species := ShrubSpecies4D.new()
	species.seed = 12345

	print("=== Run A (w_lean_strength=0.0) ===")
	var voxels_a := _generate(species)
	_report(voxels_a, species)

	print("=== Determinism check: re-run same seed ===")
	var voxels_a2 := _generate(species)
	var identical := voxels_a.size() == voxels_a2.size()
	if identical:
		for key in voxels_a:
			if not voxels_a2.has(key) or voxels_a2[key] != voxels_a[key]:
				identical = false
				break
	print("identical_voxel_set=%s (a=%d cells, a2=%d cells)" % [identical, voxels_a.size(), voxels_a2.size()])

	print("=== Run B (w_lean_strength=0.6, for comparison) ===")
	species.w_lean_strength = 0.6
	var voxels_b := _generate(species)
	_report(voxels_b, species)


func _generate(species: ShrubSpecies4D) -> Dictionary:
	var generator := ShrubGenerator4D.new(species.seed)
	generator.build_trunk(species)
	generator.spawn_attractors_from_tesseract(species)
	generator.grow(species)
	var bounds: Dictionary = generator.branch_bounds()
	var extent: Vector4 = bounds.extent
	var voxels: Dictionary = generator.voxelize(species)
	print("branch_count=%d voxel_count=%d bounds_extent=%s" % [generator.branches.size(), voxels.size(), extent])
	var xyz_extent: float = maxf(extent.x, maxf(extent.y, extent.z))
	var w_fraction: float = extent.w / xyz_extent if xyz_extent > 0.0001 else 0.0
	print("w_extent=%.4f xyz_extent(max)=%.4f w_fraction_of_xyz=%.4f" % [extent.w, xyz_extent, w_fraction])
	return voxels


func _report(voxels: Dictionary, species: ShrubSpecies4D) -> void:
	if voxels.size() < 20:
		print("WARNING: voxel_count looks implausibly low")
	if voxels.size() > 2_000_000:
		print("WARNING: voxel_count looks implausibly high")
