extends SceneTree

## Plan step 36, time-boxed: what the engine's own voxel world (VoxelWorld4D, new on the
## 4D module's main) does today, and whether the pen's voxel work could move onto it.
##
## Measures: how long the world takes to stream in around a load trigger, how many chunk
## meshes and tetrahedra that makes, and what one SphereVoxelEdit (a carve, like a pickaxe
## blow) costs to apply and re-mesh - against the 172 ms a blow the GDScript slab in the
## cave takes. Headless: the meshing is CPU work.
##
## WHAT IT CANNOT DO YET, read from the source rather than guessed: the generator is
## hard-coded (VoxelData's constructor: "Temporary: hard-coded test data" - a TigerTestGenerator
## torus, major radius 10, minor 4.5, in voxels) and set_generator is not bound to scripts,
## so nothing of our own - a slab, a cave - can be generated in it from GDScript yet.

var _world: Node4D
var _trigger: Node4D
var _f := 0
var _last := 0
var _stream_ms := 0.0
var _edit_at := -1


func _initialize() -> void:
	var scene := Node4D.new()
	root.add_child(scene)
	_world = ClassDB.instantiate("VoxelWorld4D")
	scene.add_child(_world)
	_trigger = ClassDB.instantiate("VoxelLoadTrigger4D")
	scene.add_child(_trigger)
	_trigger.set("voxel_world_path", _trigger.get_path_to(_world))
	_trigger.set("load_distance", 24.0)
	_last = Time.get_ticks_usec()


func _meshes() -> Array:
	var out := []
	for child in _world.get_children():
		if child is MeshInstance4D and (child as MeshInstance4D).mesh != null:
			out.append(child)
	return out


func _tets() -> int:
	var n := 0
	for m in _meshes():
		var mesh = (m as MeshInstance4D).mesh
		if mesh is TetraMesh4D:
			n += (mesh as TetraMesh4D).get_simplex_cell_vertex_indices().size() / 4
	return n


func _process(_d: float) -> bool:
	_f += 1
	var now: int = Time.get_ticks_usec()
	var frame_ms: float = float(now - _last) / 1000.0
	_last = now
	if _f <= 40:
		_stream_ms += frame_ms
	if _f == 40:
		print("   streamed in over 40 frames: %.0f ms total, %d chunk meshes, %d tetrahedra" % [_stream_ms, _meshes().size(), _tets()])
		var edit = ClassDB.instantiate("SphereVoxelEdit")
		# On the tiger's surface: xy on its core circle, zw one minor radius out.
		edit.set("center", Vector4(10.0, 0.0, 14.5, 0.0))
		edit.set("radius", 2.0)
		edit.set("fill_material", 1)
		var t0: int = Time.get_ticks_usec()
		_world.call("apply_edit", edit)
		print("   apply_edit: %.2f ms" % (float(Time.get_ticks_usec() - t0) / 1000.0))
		_edit_at = _f
	elif _edit_at > 0 and _f <= _edit_at + 3:
		print("   frame %d after the edit: %.2f ms  (%d meshes, %d tetrahedra)" % [_f - _edit_at, frame_ms, _meshes().size(), _tets()])
	if _edit_at > 0 and _f > _edit_at + 3:
		quit()
		return true
	return false
