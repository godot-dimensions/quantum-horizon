extends SceneTree
## Exercises the chunked wall: shots land anywhere, overlapping cuts merge, and
## every opening heals shut again. Renders at three moments in that cycle.

const SCENE_PATH := "res://ramon/Portal/portal_test_1.tscn"
const SHOTS := [
	Vector4(-2.4, 1.9, -8.0, 0.0),
	Vector4(-1.5, 1.5, -8.0, 0.0),   # overlaps the first: must merge, not stack
	Vector4(1.8, 2.2, -8.0, 0.0),
]

var _scene: Node = null
var _wall: Node4D = null
var _stage := -1
var _start_physics := 0
var _shot_frames := 0


func _initialize() -> void:
	root.set_size(Vector2i(1600, 900))
	_scene = (load(SCENE_PATH) as PackedScene).instantiate()
	root.add_child(_scene)
	set_current_scene(_scene)


func _elapsed() -> float:
	return float(Engine.get_physics_frames() - _start_physics) / 60.0


func _process(_d: float) -> bool:
	if _stage < 0:
		var builder: Node = _scene.get_node("ChunkWorld/ChunkBuilder")
		_wall = builder.wall
		print("wall: %d chunks, %.0f ms, %d tetrahedra, %d colliders" % [
			_wall.chunks.size(), _wall.build_msec, _wall.total_tetra_count(), _wall.total_collider_count()])
		for shot in SHOTS:
			var dirty: int = _wall.carve_at(shot, 0.9)
			print("  shot -> %d chunks in %.0f ms" % [dirty, _wall.last_rebuild_msec])
		for chunk in _wall.chunks:
			if not chunk.last_phase_msec.is_empty() and chunk.tetra_count > 0:
				var phases: Dictionary = chunk.last_phase_msec
				print("  chunk phases: slab %.1f  carves %.1f  contour %.1f  mesh %.1f  colliders %.1f (total %.1f ms, %d colliders)" % [
					phases.slab, phases.carves, phases.contour, phases.mesh, phases.colliders,
					chunk.rebuild_msec, chunk.collider_count])
				var inner: Dictionary = chunk.contour_phase_msec
				print("    contour: edge_ids %.1f  cell_vertices %.1f  hexahedra %.1f  normals %.1f" % [
					inner.edge_ids, inner.cell_vertices, inner.hexahedra, inner.normals])
				print("    cells with geometry: %d" % chunk.last_cells_with_geometry)
				break
		_place_camera()
		_stage = 0
		_start_physics = Engine.get_physics_frames()
		return false

	_shot_frames += 1
	# Three captures: fully open, mid-close, and healed.
	if _stage == 0 and _elapsed() > 1.0:
		_capture("chunk_open.png")
		_stage = 1
	elif _stage == 1 and _elapsed() > 2.5:
		_capture("chunk_closing.png")
		_stage = 2
	elif _stage == 2 and _elapsed() > 4.2:
		_capture("chunk_healed.png")
		print("carves remaining: %d, rebuild events: %d, tetrahedra: %d" % [
			_wall.carves.size(), _wall.rebuild_events, _wall.total_tetra_count()])
		quit(0)
		return true
	return false


func _capture(name: String) -> void:
	var image: Image = root.get_texture().get_image()
	if image != null:
		image.save_png(ProjectSettings.globalize_path("res://ramon/Portal/" + name))
		print("wrote %s at t=%.1fs (carves %d, tetrahedra %d)" % [
			name, _elapsed(), _wall.carves.size(), _wall.total_tetra_count()])


func _place_camera() -> void:
	var camera: Node4D = _find(_scene)
	camera.get_parent().remove_child(camera)
	_scene.add_child(camera)
	camera.position = Vector4(0.0, 1.9, -3.4, 0.0)
	camera.basis = Projection.IDENTITY


func _find(n: Node) -> Node4D:
	if n is Camera4D:
		return n
	for c in n.get_children():
		var f := _find(c)
		if f != null:
			return f
	return null
