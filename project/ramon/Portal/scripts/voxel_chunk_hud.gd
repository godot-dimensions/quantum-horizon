extends Control
## Range readout: what to do, and what the voxel wall is costing to do it.
##
## The numbers are here because they are the point of this scene. Every one of
## them moved during the optimisation pass, and having them on screen while
## shooting is how you tell a stall from a slow frame.

@onready var _builder: Node4D = $"../ChunkWorld/ChunkBuilder"
@onready var _gun: Node = $"../ChunkWorld/ChunkGun"
@onready var _label: Label = $Readout

## Frame time is noisy per frame; a short rolling average makes a rebuild spike
## legible instead of something you squint at.
var _smoothed_frame_msec: float = 16.0


func _process(delta_time: float) -> void:
	_smoothed_frame_msec = lerpf(_smoothed_frame_msec, delta_time * 1000.0, 0.1)
	var wall: Node4D = _builder.wall
	_label.text = "\n".join([
		"SHOOT THE WALL",
		"",
		"LEFT CLICK carves a hole   -   walk through into the red room",
		"WASD move   SPACE jump   RIGHT CLICK + mouse rotate 4D   Q / E move through w",
		"",
		"holes         %d" % wall.carves.size(),
		"chunks        %d   (%d rebuilt on the last carve)" % [wall.chunks.size(), wall.last_dirty_count],
		"tetrahedra    %d" % wall.total_tetra_count(),
		"colliders     %d   (BoxShape4D, one per exposed voxel)" % wall.total_collider_count(),
		"last rebuild  %.0f ms" % wall.last_rebuild_msec,
		"frame         %.1f ms  (%.0f fps)" % [
			_smoothed_frame_msec, 1000.0 / maxf(_smoothed_frame_msec, 0.001)],
		"",
		"last shot: %s" % _gun.last_shot_status,
	])
