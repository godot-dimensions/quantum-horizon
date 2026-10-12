extends SceneTree

## What handing a tetrahedral mesh's vertices back to the engine costs each frame, by how many
## cells and in how many meshes (3 Oct, for the cat's bent joints): a box cut finer and finer, in
## view of a camera, its vertex_positions written every frame for a block and left alone for the
## next, ABBA. Prints the frame's script time and wall time per case.
##
##   godot... --path project --windowed --resolution 960x540 --position 40,40
##       --script res://ramon/chickenpen/scripts/_measure_mesh_upload_runner.gd

## [meshes, cells each]
const CASES := [[1, 200], [1, 800], [1, 1600], [4, 200], [4, 400]]
const BLOCK := 1.5
const ORDER := [true, false, false, true]

var _cam: Camera4D
var _meshes: Array = []
var _rest: Array = []
var _case: int = -1
var _block: int = 0
var _t: float = 0.0
var _frames: Dictionary = {}
var _proc: Dictionary = {}


func _initialize() -> void:
	root.unfocusable = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var world := Node4D.new()
	root.add_child(world)
	_cam = Camera4D.new()
	_cam.set("rendering_engine_name", "Cross-section")
	world.add_child(_cam)
	_cam.global_position = Vector4(0.0, 1.0, 6.0, 0.0)
	_cam.look_at(Vector4.ZERO)
	_cam.make_current()


## A mesh of about [param cells] tetrahedra: boxes merged until there are enough.
func _make(cells: int, at: Vector4) -> MeshInstance4D:
	var box := BoxTetraMesh4D.new()
	box.size = Vector4(0.4, 0.4, 0.4, 0.4)
	var one: ArrayTetraMesh4D = box.to_array_tetra_mesh()
	var mesh: ArrayTetraMesh4D = one.duplicate()
	var per: int = one.simplex_cell_vertex_indices.size() / 4
	var i: int = 1
	while mesh.simplex_cell_vertex_indices.size() / 4 < cells:
		mesh.merge_with(one, Vector4(fmod(float(i), 6.0) * 0.45, floorf(float(i) / 6.0) * 0.45, 0.0, 0.0), Projection.IDENTITY)
		i += 1
	var node := MeshInstance4D.new()
	node.mesh = mesh
	root.get_child(root.get_child_count() - 1).add_child(node)
	node.global_position = at
	return node


func _next_case() -> bool:
	for m in _meshes:
		(m as Node).queue_free()
	_meshes.clear()
	_rest.clear()
	_case += 1
	if _case >= CASES.size():
		return false
	var c: Array = CASES[_case]
	for k in int(c[0]):
		var node: MeshInstance4D = _make(int(c[1]), Vector4(-2.0 + float(k) * 1.2, 0.0, 0.0, 0.0))
		_meshes.append(node)
		_rest.append((node.mesh as ArrayTetraMesh4D).vertex_positions)
	_frames[_case] = {true: 0, false: 0}
	_proc[_case] = {true: 0.0, false: 0.0}
	_block = 0
	_t = 0.0
	return true


func _process(d: float) -> bool:
	if _case < 0:
		_next_case()
		return false
	_t += d
	var on: bool = ORDER[_block % ORDER.size()]
	if on:
		var wobble: float = sin(float(Time.get_ticks_msec()) * 0.01) * 0.01
		for k in _meshes.size():
			var rest: PackedVector4Array = _rest[k]
			var moved := PackedVector4Array(rest)
			for i in moved.size():
				moved[i] = rest[i] + Vector4(wobble, 0.0, 0.0, 0.0)
			((_meshes[k] as MeshInstance4D).mesh as ArrayTetraMesh4D).vertex_positions = moved
	if _t > 0.3:
		_frames[_case][on] += 1
		_proc[_case][on] += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	if _t >= BLOCK:
		_t = 0.0
		_block += 1
		if _block >= ORDER.size() * 2:
			var c: Array = CASES[_case]
			var f_on: int = _frames[_case][true]
			var f_off: int = _frames[_case][false]
			print("      %d mesh(es) x %4d cells: scripts %.3f ms written, %.3f left; frames %d vs %d in the same time" % [
				int(c[0]), int(c[1]), _proc[_case][true] / maxf(f_on, 1), _proc[_case][false] / maxf(f_off, 1), f_on, f_off])
			if not _next_case():
				print("UPLOAD DONE")
				return true
	return false
