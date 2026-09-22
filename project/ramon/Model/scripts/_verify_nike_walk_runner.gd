extends SceneTree

## Does Nike actually walk? Three things have to be true and none of them are visible in
## a still: the walker has to have FOUND four legs, the legs have to hold different
## phases, and the body has to travel. Printed rather than eyeballed, plus a strip of
## frames across one gait cycle so the pose can be looked at.
##
## Vsync off, because a frame timing taken against the 60 Hz beat is meaningless - see
## follow_up/lofting_gotchas.md. The cost matters here: the walker hands the whole mesh
## back to be re-posed, so it scales with the model, not with the legs.

const _DIR: String = "res://smoke_test_output/"
var _walker: Node
var _nike: Node4D
var _camera: Camera4D
var _frames: int = 0
var _start: Vector4
var _shots: int = 0
var _worst: float = 0.0
var _total: float = 0.0
var _samples: int = 0
var _static_total: float = 0.0
var _static_samples: int = 0
var _was_posing: bool = true


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var scene: Node = (load("res://ramon/Model/animation_test.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	_nike = scene.get_node("Nike")
	_nike.position = Vector4(24.0, 0.0, 3.0, 0.0)
	_walker = scene.get_node("Nike/Walker")
	# The horse shares this scene and skins its own 14,000 cells every frame, so a frame
	# time taken with it running is mostly its. Stopped AND hidden: a hidden thing still
	# animates, which is the isolation mistake lofting_gotchas.md records.
	var horse: Node = scene.get_node("Creature/Strider")
	horse.get_node("Walker").set_process_mode(Node.PROCESS_MODE_DISABLED)
	horse.get_node("Hide").visible = false
	_start = _nike.position
	_camera = Camera4D.new()
	_camera.rendering_engine_name = "Cross-section"
	_camera.focal_length_3d = 2.75
	_camera.position = Vector4(30.4, 1.2, 2.6, 0.0)
	# Side on, looking -X, W left as the world's.
	_camera.basis = Projection(
		Vector4(0, 0, -1, 0), Vector4(0, 1, 0, 0), Vector4(1, 0, 0, 0), Vector4(0, 0, 0, 1))
	scene.add_child(_camera)
	_camera.current = true


func _process(delta: float) -> bool:
	_frames += 1
	if _frames == 30:
		var legs: Array = _walker.get("_legs")
		print("LEGS FOUND: %d" % legs.size())
		for leg in legs:
			print("  %s  order %d  upper %.3f  lower %.3f" % [
				leg["hip"].name, leg["order"], leg["upper"], leg["lower"]])
	# A/B INTERLEAVED, not as two blocks: run-to-run drift is 1-2 ms and would swamp the
	# difference. The walker is switched on and off every frame and each sample is
	# attributed to the frame BEFORE it, because the delta read at the top of _process
	# covers the previous frame's draw - which is where the re-posed mesh is rebuilt.
	if _frames > 40:
		if _was_posing:
			_total += delta
			_samples += 1
			_worst = maxf(_worst, delta)
		else:
			_static_total += delta
			_static_samples += 1
		var posing: bool = _frames % 2 == 0
		_walker.set_process_mode(Node.PROCESS_MODE_INHERIT if posing else Node.PROCESS_MODE_DISABLED)
		_was_posing = posing
	# One gait cycle, sampled four times.
	if _frames >= 60 and _shots < 4 and (_frames - 60) % 14 == 0:
		var image: Image = root.get_texture().get_image()
		if image != null:
			image.save_png(_DIR + "nike_walk_%d.png" % _shots)
		_shots += 1
	if _frames < 190:
		return false
	var moved: Vector4 = _nike.position - _start
	print("TRAVELLED: %.3f units (%.3f, %.3f, %.3f, %.3f)" % [
		moved.length(), moved.x, moved.y, moved.z, moved.w])
	var posed: float = _total / maxf(float(_samples), 1.0) * 1000.0
	var still: float = _static_total / maxf(float(_static_samples), 1.0) * 1000.0
	print("FRAME posed: %.2f ms (%d samples), worst %.2f" % [posed, _samples, _worst * 1000.0])
	print("FRAME still: %.2f ms (%d samples)" % [still, _static_samples])
	print("POSING COSTS: %.2f ms - IK for four legs plus handing the whole mesh back" % (posed - still))
	print("CELLS: %d" % (_nike.get_node("Hide").mesh.get_simplex_cell_vertex_indices().size() / 4))
	return true
