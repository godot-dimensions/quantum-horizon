extends Label
## Dev-metrics overlay for simplex_pillar_test.tscn. Surfaces the monument's
## own current spin angle (not just FPS) specifically so two screenshots
## taken seconds apart can be checked against each other to confirm the
## configuration is actually rotating, not just present - see
## simplex_pillar_layer.gd's _process().

@export var monument_path: NodePath
@export var clouds_path: NodePath

var _clouds: Node


func _ready() -> void:
	_clouds = get_node_or_null(clouds_path)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_C:
		if _clouds != null:
			_clouds.visible = not _clouds.visible


func _process(_delta: float) -> void:
	# Untyped (not SimplexPillarLayer) deliberately - see simplex_grid_test_hud.gd's
	# own comment on the class_name headless-hang gotcha this sidesteps.
	var monument: Node = get_node_or_null(monument_path)
	var ring_count: int = monument.ring_count if monument != null else 0
	var spin_degrees: float = rad_to_deg(monument._spin_angle) if monument != null else 0.0
	var clouds_on: bool = _clouds != null and _clouds.visible

	text = (
		"FPS: %d (%.1f ms)\n" % [Engine.get_frames_per_second(), 1000.0 / maxf(Engine.get_frames_per_second(), 0.001)]
		+ "Monument: %d simplices x 5 tets + pillar\n" % ring_count
		+ "Spin: %.1f deg\n" % fmod(spin_degrees, 360.0)
		+ "Clouds: %s (C to toggle)" % ("on, ~95000 tets budget" if clouds_on else "off")
	)
