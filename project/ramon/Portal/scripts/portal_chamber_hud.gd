extends Control
## Readout for milestone A. The measurements are the deliverable, not decoration:
## the open question this chamber exists to answer is whether VoxelMining's
## per-hit carve survives room scale, and collider count is the number most
## likely to be the answer.

@onready var _builder: Node4D = $"../ChamberWorld/ChamberBuilder"
@onready var _gun: Node = $"../ChamberWorld/PortalGun"
@onready var _label: Label = $Readout

## Frame time is noisy per-frame; a short rolling average makes a collider-count
## regression legible instead of something you squint at.
var _smoothed_frame_msec: float = 16.0


func _process(delta_time: float) -> void:
	_smoothed_frame_msec = lerpf(_smoothed_frame_msec, delta_time * 1000.0, 0.1)
	_label.text = "\n".join([
		"PORTAL CHAMBER 01  -  milestone A: destructible panels at room scale",
		"",
		"LEFT CLICK carve   WASD move   SPACE jump   RIGHT CLICK + mouse rotate 4D   Q / E move through w",
		"",
		"panels        %d" % _builder.panels.size(),
		"colliders     %d   (BoxShape4D, one per exposed voxel)" % _builder.total_collider_count(),
		"tetrahedra    %d" % _builder.total_tetra_count(),
		"initial build %.0f ms" % _builder.build_msec,
		"last carve    %.0f ms   (%d shots landed)" % [_builder.last_carve_msec(), _gun.carve_count],
		"frame         %.1f ms  (%.0f fps)" % [_smoothed_frame_msec, 1000.0 / maxf(_smoothed_frame_msec, 0.001)],
		"",
		"last shot: %s" % _gun.last_shot_status,
		"",
		"white panels accept carving. Dark walls refuse - that is Portal's own rule,",
		"and here it is also what keeps the voxel cost off the room shell.",
	])
