extends SceneTree

## Throwaway. Measures the real tetrahedron count of each 4D polytope asset and
## the built-in primitives, so cloud-blob budgets are based on numbers rather
## than guesses. Delete once the skydome design is settled.
##
##   engine/godot/bin/godot.windows.editor.double.x86_64.console.exe \
##     --headless --path project --script res://ramon/voxel_port/polytope_budget.gd

const ASSETS := {
	"5-cell": "res://models/primitives/platonic/5_cell/5_cell.g4b",
	"24-cell": "res://models/primitives/platonic/24_cell/24_cell.g4b",
	"120-cell": "res://models/primitives/platonic/120_cell/120_cell.g4b",
	"600-cell": "res://models/primitives/platonic/600_cell/600_cell.g4b",
	"600-cell smooth": "res://models/primitives/platonic/600_cell/600_cell_smooth.g4b",
}

## Terrain at the documented baseline, for scale.
const TERRAIN_TETRAHEDRA := 28140


func _init() -> void:
	print("=".repeat(58))
	print("%-20s %10s %10s" % ["mesh", "tets", "verts"])
	print("=".repeat(58))

	var counts: Dictionary = {}

	var orthoplex := OrthoplexTetraMesh4D.new()
	counts["16-cell (built-in)"] = _measure("16-cell (built-in)", orthoplex)
	var box := BoxTetraMesh4D.new()
	counts["tesseract (built-in)"] = _measure("tesseract (built-in)", box)

	for name in ASSETS:
		var path: String = ASSETS[name]
		if not ResourceLoader.exists(path):
			print("%-20s %10s" % [name, "MISSING"])
			continue
		var mesh: TetraMesh4D = load(path)
		if mesh == null:
			print("%-20s %10s" % [name, "LOAD FAIL"])
			continue
		counts[name] = _measure(name, mesh)

	print("")
	print("BLOB BUDGET  (terrain baseline = %d tets; cost scales with TOTAL 4D" % TERRAIN_TETRAHEDRA)
	print("mesh size, not visible geometry, because of instance_set_ignore_culling)")
	print("")
	print("%-20s %12s %12s %12s" % ["blob type", "50 blobs", "200 blobs", "500 blobs"])
	print("-".repeat(58))
	for name in counts:
		var per: int = counts[name]
		if per <= 0:
			continue
		print("%-20s %12s %12s %12s" % [
			name,
			_budget(per * 50),
			_budget(per * 200),
			_budget(per * 500),
		])
	quit()


func _measure(name: String, mesh: TetraMesh4D) -> int:
	var cells: PackedInt32Array = mesh.get_simplex_cell_indices()
	var tets: int = cells.size() / 4
	var verts: int = mesh.get_simplex_cell_positions().size()
	print("%-20s %10d %10d" % [name, tets, verts])
	return tets


func _budget(total: int) -> String:
	return "%d (%.0f%%)" % [total, 100.0 * float(total) / float(TERRAIN_TETRAHEDRA)]
