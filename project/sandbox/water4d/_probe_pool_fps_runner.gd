extends SceneTree
## Real framerate of the pool room WITH the creature in it, letting it run normally.
## The capture probe's HUD read 1 fps, but that probe steps the pilot thousands of times in a
## single frame - so the number had to be re-taken without that, rather than believed.
var _f := 0
var _held := 0.0
var _samples: Array[float] = []
func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
func _process(delta: float) -> bool:
	_f += 1
	if _f == 1:
		var m: Node = (load("res://sandbox/water4d/pool_room.tscn") as PackedScene).instantiate()
		root.add_child(m); current_scene = m
		return false
	_held += delta
	if _held < 2.0:
		return false
	_samples.append(Engine.get_frames_per_second())
	if _samples.size() < 5:
		_held = 1.0
		return false
	var total := 0.0
	for s in _samples:
		total += s
	print("  pool room with the plesiosaur: %.0f fps (samples %s)" % [total / _samples.size(), _samples])
	quit(0)
	return true
