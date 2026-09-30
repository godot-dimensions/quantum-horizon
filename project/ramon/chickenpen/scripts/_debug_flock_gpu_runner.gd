extends SceneTree

## Is the GPU flock stepping, and is it writing what the bird shader draws? A bare 4D scene
## (one camera, the flock, nothing else), a few seconds of frames, then the GPU buffers and
## the multimesh's own buffer read back and printed.
##
##   godot... --path project --windowed --resolution 640x360 --position 40,40
##       --script res://ramon/chickenpen/scripts/_debug_flock_gpu_runner.gd

const FLOCK := preload("res://ramon/chickenpen/flock/pen_flock_4d.gd")

var _flock: Node4D
var _f: int = 0


func _initialize() -> void:
	root.unfocusable = true
	if "pen=1" in OS.get_cmdline_user_args():
		var room: Node = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
		_flock = room.get_node("World/Flock") as Node4D
		_flock.set("count", 2000)
		_flock.set("profile_gpu", true)
		root.add_child(room)
		current_scene = room
		return
	var world := Node4D.new()
	root.add_child(world)
	var cam := Camera4D.new()
	cam.set("rendering_engine_name", "Cross-section")
	world.add_child(cam)
	cam.position = Vector4(0, 20, 0, 0)
	_flock = FLOCK.new()
	_flock.set("count", 256)
	_flock.set("profile_gpu", true)
	world.add_child(_flock)
	cam.look_at(Vector4(0, 23, -70, 0))
	print("DEBUG on GPU: %s" % str(_flock.call("on_gpu")))


func _process(_d: float) -> bool:
	_f += 1
	if _f == 5 or _f == 120:
		var pos: PackedVector4Array = _flock.call("positions")
		var mm: RID = _flock.get("_multimesh")
		var drawn: PackedFloat32Array = RenderingServer.multimesh_get_buffer(mm)
		print("frame %d  on GPU %s  step %.0f us  gpu %.0f us  frame %d  manual %s  processing %s" % [_f, str(_flock.call("on_gpu")), float(_flock.get("last_step_usec")), float(_flock.get("gpu_usec")), int(_flock.get("_frame")), str(_flock.get("manual")), str(_flock.is_processing())])
		print("   positions %d: %s  %s" % [pos.size(), str(pos[0]) if pos.size() > 0 else "-", str(pos[1]) if pos.size() > 1 else "-"])
		print("   drawn floats %d: %s" % [drawn.size(), str(drawn.slice(0, 20))])
		var flock_state: PackedVector4Array = _flock.call("_gpu_read_vec4", "flock")
		print("   flock middle/heading: %s" % str(flock_state))
		print("   misc: %s" % str((_flock.call("_gpu_read_vec4", "misc") as PackedVector4Array).slice(0, 2)))
	if _f == 119:
		root.get_texture().get_image().save_png("res://smoke_test_output/flock_debug_%s.png" % ("pen" if "pen=1" in OS.get_cmdline_user_args() else "bare"))
	if _f >= 120:
		quit()
		return true
	return false
