@tool
extends MeshInstance4D

# No `class_name` - see the note at the top of cloud_field_4d.gd. A stale editor
# tab remembering a differently-cased path for this folder makes Godot load the
# file twice and the second copy's class_name collides with the first. This
# folder was renamed model -> Model, so that trap is live here specifically.

## Builds a 4D mesh by lofting a stack of 3D cross-sections along the Y axis.
##
## THE TECHNIQUE: this is lofting (CAD) / skinning, the operation that builds a
## boat hull from a handful of station drawings - lifted one dimension. In 3D you
## loft 2D outlines into a 3D surface; here we loft 3D closed surfaces into a 4D
## one. You state a few cross-sections and everything between them is generated.
##
## AXES follow the convention in Trym's 4D_MODEL_PIPELINE_REFERENCE.md so files
## compose predictably: Y is the stack axis (gravity, always asymmetric), and each
## cross-section is a closed 3D surface living in (X, Z, W).
##
## WHY THE PROFILE IS A SPHEROID AND NOT A BOX: X and Z are the two "sideways"
## directions and neither has a privileged heading, so a box would impose four
## arbitrary special directions on a plane that has none. W is different - it is
## committed to being asymmetric via [member w_offset_peak], which is what makes
## the model actually change as the player slice-rotates. A model whose profile is
## symmetric in W is a solid of revolution: unique as a shape, but it presents the
## same 3D slice from every W and reads as an ordinary 3D object.
##
## ONLY TWO TETRAHEDRALIZATIONS ARE EVER PERFORMED, both long-solved, which is why
## this sidesteps general 4-polytope tetrahedralization entirely:
## 1. A triangular prism between two adjacent layers -> 3 tetrahedra.
## 2. A cone from a layer to a single apex point -> 1 tetrahedron per triangle.

@export_tool_button("Rebuild") var _rebuild_action: Callable = generate

## Vertices around each ring of the cross-section. Higher reads rounder in the
## X/Z plane, which is the point - see the class doc on why this isn't a box.
@export_range(4, 32, 1) var profile_sides: int = 12:
	set(value):
		profile_sides = value
		generate()

## Rings from pole to pole of the cross-section surface.
@export_range(3, 16, 1) var profile_rings: int = 6:
	set(value):
		profile_rings = value
		generate()

## How far the cross-section is pushed along W at the model's waist, as a
## fraction of its radius. This is the knob that decides whether the result is
## genuinely 4D or merely 4D-shaped: at 0 every slice through W looks the same,
## so the player rotates into ana/kata and nothing changes. Turn it up and the
## model presents a different silhouette at different W.
@export_range(0.0, 2.0, 0.05) var w_offset_peak: float = 0.8:
	set(value):
		w_offset_peak = value
		generate()

## Scales the cross-section's extent along W independently of X/Z. At 1.0 the
## profile is a round ball; away from 1.0 it is a flattened or stretched one, so
## slicing at different W cuts discs of visibly different size.
@export_range(0.2, 2.5, 0.05) var w_stretch: float = 0.6:
	set(value):
		w_stretch = value
		generate()

## Collapses the top and bottom keyframes to a single point each. Without this
## the hypersurface is left open at both ends - the "72 missing faces, two clean
## symmetric holes" failure in the reference doc's first prototype. A hole breaks
## cross-section tracing across a far larger region than its own size.
@export var taper_ends: bool = true:
	set(value):
		taper_ends = value
		generate()

## Runs the watertightness and winding checks after building and prints a report.
## Both are single-pass and cheap; the reference doc is explicit that every bug
## found so far was invisible without them.
@export var run_checks: bool = true:
	set(value):
		run_checks = value
		generate()


func _ready() -> void:
	generate()


## The keyframes: one entry per cross-section, bottom to top.
##
## `radius` is the X/Z extent, `w_offset` slides the whole cross-section along W.
## These describe a tapered body that leans into ana as it rises - deliberately
## lopsided rather than a solid of revolution.
func _build_keyframes() -> Array[Dictionary]:
	return [
		{"height": 0.0, "radius": 0.55, "w_offset": 0.0},
		{"height": 1.1, "radius": 1.15, "w_offset": 0.45},
		{"height": 2.3, "radius": 1.35, "w_offset": 1.0},
		{"height": 3.5, "radius": 0.95, "w_offset": 0.7},
		{"height": 4.4, "radius": 0.45, "w_offset": 0.2},
	]


func generate() -> void:
	if not is_inside_tree():
		return
	var keyframes: Array[Dictionary] = _build_keyframes()
	if keyframes.size() < 2:
		push_warning("Loft4D: need at least 2 keyframes.")
		return

	var profile: Dictionary = _build_profile_surface(profile_rings, profile_sides)
	var directions: PackedVector3Array = profile["directions"]
	var triangles: PackedInt32Array = profile["triangles"]
	var profile_vertex_count: int = directions.size()

	var positions := PackedVector4Array()
	# One block of `profile_vertex_count` vertices per keyframe, in profile order,
	# so layer L's copy of profile vertex V is always at L * count + V. The loft
	# below relies on that correspondence, which is the same constraint CAD
	# lofting calls "compatibility" and the reference doc calls keyframe
	# correspondence: matching topology, matching order, at every layer.
	var layer_starts := PackedInt32Array()
	for keyframe in keyframes:
		layer_starts.append(positions.size())
		var radius: float = keyframe["radius"]
		var height: float = keyframe["height"]
		var w_offset: float = keyframe["w_offset"] * w_offset_peak
		for direction in directions:
			positions.append(Vector4(
				direction.x * radius,
				height,
				direction.y * radius,
				direction.z * radius * w_stretch + w_offset
			))

	var cells := PackedInt32Array()

	# Bottom cap: a cone from the first layer down to its own apex. The apex is
	# that layer's own centre, never the model's - an off-axis piece fanned back
	# to a distant shared apex produces long diagonal "sail" artifacts (reference
	# doc, bug 4), and the same reasoning applies to a cap that has drifted in W.
	if taper_ends:
		var bottom_apex: int = positions.size()
		positions.append(_layer_apex(keyframes[0], -0.55))
		_append_cone(cells, layer_starts[0], bottom_apex, triangles, true)

	for layer in range(keyframes.size() - 1):
		_append_prisms(cells, layer_starts[layer], layer_starts[layer + 1], triangles, profile_vertex_count)

	if taper_ends:
		var top_apex: int = positions.size()
		positions.append(_layer_apex(keyframes[keyframes.size() - 1], 0.55))
		_append_cone(cells, layer_starts[layer_starts.size() - 1], top_apex, triangles, false)

	if run_checks:
		_report_watertightness(cells)
	var flipped: int = _make_winding_consistent(cells, positions)
	if run_checks:
		print("[Loft4D] %d vertices, %d tetrahedra, %d flipped to agree on orientation." % [positions.size(), cells.size() / 4, flipped])

	var built := ArrayTetraMesh4D.new()
	built.set_vertex_positions(positions)
	built.set_simplex_cell_vertex_indices(cells)
	built.calculate_boundary_normals(false)
	mesh = built


## The point a cap collapses to: the layer's own centre, pushed past the layer
## along Y by a fraction of its radius so the cap reads as a taper, not a crease.
func _layer_apex(keyframe: Dictionary, direction: float) -> Vector4:
	var radius: float = keyframe["radius"]
	return Vector4(0.0, keyframe["height"] + direction * radius, 0.0, keyframe["w_offset"] * w_offset_peak)


## A closed, triangulated 3D surface - the shape of one cross-section, as unit
## directions in (X, Z, W). Poles are single vertices fanned to by the end rings,
## rather than degenerate quads, so the surface is genuinely closed.
func _build_profile_surface(rings: int, sides: int) -> Dictionary:
	var directions := PackedVector3Array()
	directions.append(Vector3(0.0, 0.0, 1.0)) # North pole, at +W.
	for ring in range(1, rings):
		var theta: float = PI * float(ring) / float(rings)
		for slot in range(sides):
			var phi: float = TAU * float(slot) / float(sides)
			directions.append(Vector3(
				sin(theta) * cos(phi),
				sin(theta) * sin(phi),
				cos(theta)
			))
	var south_pole: int = directions.size()
	directions.append(Vector3(0.0, 0.0, -1.0))

	var triangles := PackedInt32Array()
	for slot in range(sides):
		var next_slot: int = (slot + 1) % sides
		triangles.append_array([0, 1 + slot, 1 + next_slot])
	for ring in range(1, rings - 1):
		var this_base: int = 1 + (ring - 1) * sides
		var next_base: int = 1 + ring * sides
		for slot in range(sides):
			var next_slot: int = (slot + 1) % sides
			triangles.append_array([this_base + slot, next_base + slot, next_base + next_slot])
			triangles.append_array([this_base + slot, next_base + next_slot, this_base + next_slot])
	var last_base: int = 1 + (rings - 2) * sides
	for slot in range(sides):
		var next_slot: int = (slot + 1) % sides
		triangles.append_array([south_pole, last_base + next_slot, last_base + slot])

	return {"directions": directions, "triangles": triangles}


## Bridges two adjacent layers, splitting each triangular prism into 3 tetrahedra.
##
## THE DIAGONAL RULE, which is the whole reason this produces a crack-free mesh:
## a prism has 3 quadrilateral side faces, each splittable two ways, so there are
## 8 combinations - 6 of which decompose into exactly 3 tetrahedra, while the
## other 2 are impossible without adding a Steiner point and cost 8 tetrahedra.
## Two prisms sharing a quad must pick the SAME diagonal or a crack opens between
## them. Sorting each triangle's vertices by their profile index and always
## running the diagonal from the lower index's bottom copy to the higher index's
## top copy guarantees both neighbours agree, because both see the same two
## profile indices on the quad they share. This is the Freudenthal/Kuhn
## triangulation trick, and it is what keeps us inside the 6 good cases.
func _append_prisms(cells: PackedInt32Array, bottom_start: int, top_start: int, triangles: PackedInt32Array, profile_vertex_count: int) -> void:
	var triangle_count: int = triangles.size() / 3
	for triangle in range(triangle_count):
		var sorted_profile: Array[int] = [
			triangles[triangle * 3],
			triangles[triangle * 3 + 1],
			triangles[triangle * 3 + 2],
		]
		sorted_profile.sort()
		var a0: int = bottom_start + sorted_profile[0]
		var b0: int = bottom_start + sorted_profile[1]
		var c0: int = bottom_start + sorted_profile[2]
		var a1: int = top_start + sorted_profile[0]
		var b1: int = top_start + sorted_profile[1]
		var c1: int = top_start + sorted_profile[2]
		cells.append_array([a0, b0, c0, c1])
		cells.append_array([a0, b0, c1, b1])
		cells.append_array([a0, b1, c1, a1])


## Fans every triangle of one layer to a single apex - 1 tetrahedron each. This
## is what closes a free end: a layer left as an ordinary cross-section leaves the
## hypersurface open there.
func _append_cone(cells: PackedInt32Array, layer_start: int, apex: int, triangles: PackedInt32Array, reverse: bool) -> void:
	var triangle_count: int = triangles.size() / 3
	for triangle in range(triangle_count):
		var first: int = layer_start + triangles[triangle * 3]
		var second: int = layer_start + triangles[triangle * 3 + 1]
		var third: int = layer_start + triangles[triangle * 3 + 2]
		if reverse:
			cells.append_array([first, third, second, apex])
		else:
			cells.append_array([first, second, third, apex])


## Counts how many tetrahedra own each triangular face.
##
## In a closed model every face must be shared by EXACTLY 2 tetrahedra - the 4D
## analog of every edge in a closed 3D mesh belonging to exactly 2 triangles. A
## face owned by 1 is a hole. This is not a tolerance to be relaxed: in a
## slicing renderer one gap breaks cross-section tracing across a far larger
## region than the hole itself, so 4% missing data fragments the whole model.
func _report_watertightness(cells: PackedInt32Array) -> void:
	var face_counts := {}
	var cell_count: int = cells.size() / 4
	for cell in range(cell_count):
		for face in _cell_faces(cells, cell):
			var key: String = _face_key(face)
			face_counts[key] = face_counts.get(key, 0) + 1
	var open_faces: int = 0
	var overshared: int = 0
	for count in face_counts.values():
		if count == 1:
			open_faces += 1
		elif count > 2:
			overshared += 1
	if open_faces == 0 and overshared == 0:
		print("[Loft4D] Watertight: all %d faces shared by exactly 2 tetrahedra." % face_counts.size())
	else:
		push_warning("[Loft4D] NOT watertight: %d open faces, %d over-shared, of %d total." % [open_faces, overshared, face_counts.size()])


## Makes every tetrahedron agree with its neighbours on which way is outward.
##
## Two tetrahedra sharing a face must induce OPPOSITE rotational order on it,
## exactly as two triangles sharing an edge in a consistently-wound 3D mesh do.
## Three things matter here, each of which was a real bug in the reference doc:
##
## 1. Adjacency is keyed by VERTEX SET, never by local face index. Flipping a
##    tetrahedron permutes which local index maps to which geometric face, so a
##    cached local index silently goes stale and produces what looks like random
##    bad winding but is a systematic indexing error.
## 2. Propagation is per connected component, and the remaining global sign is
##    resolved ONCE per component by a divergence-theorem sum - never per
##    tetrahedron, which breaks on any shape that isn't star-convex.
## 3. The result is re-verified rather than trusted.
func _make_winding_consistent(cells: PackedInt32Array, positions: PackedVector4Array) -> int:
	var cell_count: int = cells.size() / 4
	var face_owners := {}
	for cell in range(cell_count):
		for face in _cell_faces(cells, cell):
			var key: String = _face_key(face)
			if not face_owners.has(key):
				face_owners[key] = []
			face_owners[key].append(cell)

	var visited := PackedInt32Array()
	visited.resize(cell_count)
	visited.fill(0)
	var flipped_total: int = 0

	for seed in range(cell_count):
		if visited[seed] == 1:
			continue
		var component := PackedInt32Array()
		visited[seed] = 1
		var queue: Array[int] = [seed]
		while not queue.is_empty():
			var current: int = queue.pop_back()
			component.append(current)
			for face in _cell_faces(cells, current):
				var owners: Array = face_owners[_face_key(face)]
				for other in owners:
					if other == current or visited[other] == 1:
						continue
					# Neighbours agree when the shared face appears in opposite
					# cyclic order in each. If they agree already, leave it be;
					# otherwise flip the neighbour by swapping its first two
					# indices, which reverses its orientation.
					if _shares_cycle(face, _matching_face(cells, other, face)):
						_flip_cell(cells, other)
						flipped_total += 1
					visited[other] = 1
					queue.append(other)
		flipped_total += _resolve_component_sign(cells, positions, component)

	if run_checks:
		var inconsistent: int = _count_inconsistent_faces(cells, face_owners)
		if inconsistent == 0:
			print("[Loft4D] Winding consistent: 0 disagreeing faces after the fix.")
		else:
			push_warning("[Loft4D] Winding STILL inconsistent: %d disagreeing faces." % inconsistent)
	return flipped_total


## Resolves one connected component's single remaining global sign.
##
## Sums an unnormalized outward measure over the component: for each tetrahedron,
## the 4D perpendicular of its three edge vectors (Vector4D.perpendicular is the
## engine's generalized cross product, 3 vectors -> 1 perpendicular) dotted
## against the vector from the component's reference point to its centroid. A
## negative sum means the whole component is inside-out.
func _resolve_component_sign(cells: PackedInt32Array, positions: PackedVector4Array, component: PackedInt32Array) -> int:
	if component.is_empty():
		return 0
	var reference := Vector4()
	for cell in component:
		reference += _cell_centroid(cells, positions, cell)
	reference /= float(component.size())

	var total: float = 0.0
	for cell in component:
		var a: Vector4 = positions[cells[cell * 4]]
		var b: Vector4 = positions[cells[cell * 4 + 1]]
		var c: Vector4 = positions[cells[cell * 4 + 2]]
		var d: Vector4 = positions[cells[cell * 4 + 3]]
		var normal: Vector4 = Vector4D.perpendicular(b - a, c - a, d - a)
		total += normal.dot(_cell_centroid(cells, positions, cell) - reference)

	if total >= 0.0:
		return 0
	for cell in component:
		_flip_cell(cells, cell)
	return component.size()


func _count_inconsistent_faces(cells: PackedInt32Array, face_owners: Dictionary) -> int:
	var inconsistent: int = 0
	for key in face_owners:
		var owners: Array = face_owners[key]
		if owners.size() != 2:
			continue
		var first: Array[int] = _matching_face_by_key(cells, owners[0], key)
		var second: Array[int] = _matching_face_by_key(cells, owners[1], key)
		if _shares_cycle(first, second):
			inconsistent += 1
	return inconsistent


## The four boundary faces of a tetrahedron, each oriented by the standard
## boundary operator so that a consistently-oriented pair of neighbours induces
## opposite cycles on the face they share.
func _cell_faces(cells: PackedInt32Array, cell: int) -> Array:
	var v0: int = cells[cell * 4]
	var v1: int = cells[cell * 4 + 1]
	var v2: int = cells[cell * 4 + 2]
	var v3: int = cells[cell * 4 + 3]
	return [
		[v1, v2, v3] as Array[int],
		[v0, v3, v2] as Array[int],
		[v0, v1, v3] as Array[int],
		[v0, v2, v1] as Array[int],
	]


func _matching_face(cells: PackedInt32Array, cell: int, face: Array) -> Array[int]:
	return _matching_face_by_key(cells, cell, _face_key(face))


func _matching_face_by_key(cells: PackedInt32Array, cell: int, key: String) -> Array[int]:
	for face in _cell_faces(cells, cell):
		if _face_key(face) == key:
			return face
	return [] as Array[int]


## Identifies a face by its vertex SET, so the key survives a flip - see point 1
## in _make_winding_consistent's doc comment.
func _face_key(face: Array) -> String:
	var sorted_face: Array[int] = [face[0], face[1], face[2]]
	sorted_face.sort()
	return "%d_%d_%d" % sorted_face


## Whether two orientations of the same triangle run the same way round. Two
## correctly-oriented neighbours must NOT share a cycle.
func _shares_cycle(first: Array, second: Array) -> bool:
	if first.is_empty() or second.is_empty():
		return false
	for rotation in range(3):
		if second[rotation] == first[0]:
			return second[(rotation + 1) % 3] == first[1]
	return false


func _flip_cell(cells: PackedInt32Array, cell: int) -> void:
	var swap: int = cells[cell * 4]
	cells[cell * 4] = cells[cell * 4 + 1]
	cells[cell * 4 + 1] = swap


func _cell_centroid(cells: PackedInt32Array, positions: PackedVector4Array, cell: int) -> Vector4:
	return (positions[cells[cell * 4]]
		+ positions[cells[cell * 4 + 1]]
		+ positions[cells[cell * 4 + 2]]
		+ positions[cells[cell * 4 + 3]]) / 4.0
