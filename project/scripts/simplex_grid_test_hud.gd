extends Label
## Dev-metrics overlay for simplex_grid_test.tscn: FPS/frame time plus the
## grid's own known tetrahedra budget (grid_size^2 * 5, since each 4-simplex
## is exactly 5 tets - see simplex_grid_layer.gd) so the grid's own cost can
## be reasoned about separately from Ramon's cloud field, which at its
## authored preset (max_tetrahedra=95000) dwarfs the grid by ~300x and will
## dominate frame time in this scene - toggle it off (C key) to isolate the
## grid's own contribution.

@export var grid_path: NodePath
@export var clouds_path: NodePath

var _clouds: Node


func _ready() -> void:
	_clouds = get_node_or_null(clouds_path)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_C:
		if _clouds != null:
			_clouds.visible = not _clouds.visible


func _process(_delta: float) -> void:
	# Untyped (not SimplexGridLayer) deliberately: a brand-new class_name
	# script's global name isn't registered until the editor scans the
	# project once, and referencing it before that hangs headless runs -
	# see this project's own git history. Duck-typed property access sidesteps it.
	var grid: Node = get_node_or_null(grid_path)
	var instance_count: int = grid.instance_count if grid != null else 0
	var clouds_on: bool = _clouds != null and _clouds.visible

	text = (
		"FPS: %d (%.1f ms)\n" % [Engine.get_frames_per_second(), 1000.0 / maxf(Engine.get_frames_per_second(), 0.001)]
		+ "Grid: %d simplices x 5 tets = %d tets\n" % [instance_count, instance_count * 5]
		+ "Clouds: %s (C to toggle)" % ("on, ~95000 tets budget" if clouds_on else "off")
	)
