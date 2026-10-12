extends Node
## TEMPORARY - verifies sandbox/skew_polyhedron/skew_polyhedron_test.tscn end
## to end. Not part of the shipped scene.

@onready var player: CharacterBody4D = $"../Scene/FlatPlane/Player"
@onready var polyhedron: MeshInstance4D = $"../Scene/FlatPlane/Polyhedron"
@onready var label: Label = $"../Scene/PolyhedronLabel"

func _wait_process_frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame

func _screenshot(image_name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://smoke_test_output/" + image_name)

func _press_key(keycode: Key) -> void:
	var press := InputEventKey.new()
	press.keycode = keycode
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().process_frame
	var release := InputEventKey.new()
	release.keycode = keycode
	release.pressed = false
	Input.parse_input_event(release)
	await get_tree().process_frame

func _ready() -> void:
	await get_tree().process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_run()

func _run() -> void:
	await _wait_process_frames(3)

	# 1. Basic resolution.
	print("1a.nodes_resolve: polyhedron=%s label=%s (expect both true)" % [polyhedron != null, label != null])
	print("1b.default_n: n=%d (expect %d)" % [polyhedron.n, polyhedron.DEFAULT_N])

	# 2. At the default n, vertex/edge counts match n^2 / 2n^2 exactly - no
	# accidental duplicates or missing wraparound edges.
	var mesh: ArrayWireMesh4D = polyhedron.mesh
	var expected_vertices: int = polyhedron.n * polyhedron.n
	var expected_edges: int = 2 * polyhedron.n * polyhedron.n
	print("2a.vertex_count: expected=%d actual=%d (match=%s)" % [
		expected_vertices, mesh.get_vertex_positions().size(), expected_vertices == mesh.get_vertex_positions().size(),
	])
	print("2b.edge_count: expected=%d actual=%d (match=%s)" % [
		expected_edges, mesh.get_edge_indices().size() / 2, expected_edges == mesh.get_edge_indices().size() / 2,
	])

	# 3. Every vertex lies exactly on the hypersphere of radius RADIUS - the
	# whole point of the /sqrt(2) normalization in the construction formula.
	var max_radius_error: float = 0.0
	for vertex in mesh.get_vertex_positions():
		max_radius_error = maxf(max_radius_error, absf(vertex.length() - polyhedron.RADIUS))
	print("3a.all_vertices_on_hypersphere: max_radius_error=%.6f (expect ~0)" % [max_radius_error])

	# 4. Number-key press rebuilds at the pressed digit.
	await _press_key(KEY_3)
	print("4a.number_key_sets_n: n=%d (expect 3)" % [polyhedron.n])
	print("4b.rebuilt_vertex_count: expected=9 actual=%d (match=%s)" % [
		polyhedron.mesh.get_vertex_positions().size(), polyhedron.mesh.get_vertex_positions().size() == 9,
	])
	print("4c.label_updated: text=%s (expect it to mention {4,4|3})" % [label.text])

	# 5. Bracket keys increment/decrement from the current n.
	await _press_key(KEY_BRACKETRIGHT)
	print("5a.bracket_right_increments: n=%d (expect 4)" % [polyhedron.n])
	await _press_key(KEY_BRACKETLEFT)
	await _press_key(KEY_BRACKETLEFT)
	print("5b.bracket_left_decrements: n=%d (expect 2, clamped up to MIN_N=%d)" % [polyhedron.n, polyhedron.MIN_N])

	# 6. Direct rebuild_with_n() clamps out-of-range values at both ends.
	polyhedron.rebuild_with_n(1)
	print("6a.clamped_to_min: n=%d (expect %d)" % [polyhedron.n, polyhedron.MIN_N])
	polyhedron.rebuild_with_n(100)
	print("6b.clamped_to_max: n=%d (expect %d)" % [polyhedron.n, polyhedron.MAX_N])

	# Visual check - a moderate n, standing back far enough to see the whole
	# lattice, looking toward it.
	polyhedron.rebuild_with_n(8)
	player.global_position = Vector4(0, 2, 4, 0)
	player.global_basis = Projection()
	await _wait_process_frames(3)
	await _screenshot("skew_polyhedron_view.png")
	print("7a.visual_screenshot_taken: see skew_polyhedron_view.png - confirm a lattice torus reads clearly, ground below it, no gaps")

	print("DONE")
