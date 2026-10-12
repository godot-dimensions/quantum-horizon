extends Node
## TEMPORARY - times SingleVertexDualContour4D.generate() (via terrain_generator.gd's
## regenerate()) at several grid resolutions, isolated from the drag-
## simulation/screenshot overhead the main verify runner has. Not part of
## the shipped scene.

@onready var terrain: StaticBody4D = $"../Terrain"

# [resolution_horizontal, resolution_vertical]
const CONFIGS := [
	[20, 16],
	[21, 16],
	[21, 17],
]

func _ready() -> void:
	await get_tree().process_frame
	_run()

func _run() -> void:
	print("config, tet_count, active_cell_count, elapsed_ms")
	for config in CONFIGS:
		terrain.resolution_horizontal = config[0]
		terrain.resolution_vertical = config[1]
		var start_ms := Time.get_ticks_msec()
		terrain.regenerate()
		var elapsed_ms := Time.get_ticks_msec() - start_ms
		var result: Dictionary = terrain.get_last_result()
		print("%dx%dx%dx%d, %d, %d, %d" % [
			config[0], config[1], config[0], config[0],
			result.tet_count, result.active_cell_count, elapsed_ms,
		])
		await get_tree().process_frame

	print("DONE")
	get_tree().quit()
