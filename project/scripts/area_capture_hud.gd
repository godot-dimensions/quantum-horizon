extends Label
## Dev-metrics overlay for area_capture_test.tscn: FPS, current draw state,
## the live/last box's size, and its 4D hypervolume (x*y*z*w) - the volume
## figure is tracked now specifically for later scoring use (comparing it
## against the target cluster's own combined bounds), even though nothing
## reads it yet beyond this display.
##
## "The box the player is placing" tracks whichever box is currently
## relevant: the live preview while actively drawing, or the most recently
## locked-in box once idle (frozen at its final value) - never blank just
## because the player let go of T.

@export var controller_path: NodePath

var _controller: Node


func _ready() -> void:
	_controller = get_node_or_null(controller_path)


func _process(_delta: float) -> void:
	# Untyped (not AreaCaptureController) deliberately - see
	# simplex_grid_test_hud.gd's own comment on the class_name headless-hang
	# gotcha this sidesteps.
	var controller: Node = _controller
	var state_text := "idle"
	var size_text := "-"
	var volume_text := "-"
	if controller != null:
		if controller._drawing:
			state_text = "drawing (T to lock in)"
		else:
			state_text = "idle (T to start)"
		var reference_box: MeshInstance4D = null
		if controller._drawing and controller._preview_box != null:
			reference_box = controller._preview_box
		elif controller.captured_boxes.size() > 0:
			reference_box = controller.captured_boxes[-1]
		if reference_box != null:
			var box_size: Vector4 = reference_box.mesh.size
			size_text = str(box_size)
			volume_text = "%.3f" % (box_size.x * box_size.y * box_size.z * box_size.w)
	var captured_count: int = controller.captured_boxes.size() if controller != null else 0

	text = (
		"FPS: %d\n" % [Engine.get_frames_per_second()]
		+ "State: %s\n" % state_text
		+ "Live box size (x,y,z,w): %s\n" % size_text
		+ "Live box volume (4D): %s\n" % volume_text
		+ "Captured boxes: %d" % captured_count
	)
