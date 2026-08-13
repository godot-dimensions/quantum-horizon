class_name VoxelTerrainPerfHud
extends Label
## Dev metrics overlay - FPS plus VoxelTerrain4D's own generation stats and
## the live chunk-culling counts from its per-frame visibility pass. Exists
## purely to make performance changes (this session's slice+distance
## culling, grid_size increases) visible while testing, not a shipped HUD.

@export var terrain_path: NodePath


func _process(_delta: float) -> void:
	var terrain: Node = get_node_or_null(terrain_path)
	if terrain == null:
		text = "FPS: %d" % [Engine.get_frames_per_second()]
		return
	var stats: Dictionary = terrain._last_stats if "_last_stats" in terrain else {}
	text = (
		"FPS: %d\n" +
		"Grid: %d^4  |  field %.0f ms, total %.0f ms\n" +
		"Tets: %d ground / %d water\n" +
		"Visible: %d/%d chunks  |  ~%d/%d tets"
	) % [
		Engine.get_frames_per_second(),
		terrain.grid_size, stats.get("field_ms", 0.0), stats.get("total_ms", 0.0),
		stats.get("ground_tetrahedra", 0), stats.get("water_tetrahedra", 0),
		terrain._visible_chunk_count, terrain._total_chunk_count,
		terrain._visible_tet_count, terrain._total_tet_count,
	]
