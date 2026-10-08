# CARRIED OVER from res://ramon/chickenpen/scripts/loft_builder_4d.gd on 4 Oct 2026, so the lab owns this copy: the original can change without breaking the lab, and the other way round (LabKit/carried/README.md).
extends RefCounted
# COPIED INTO chickenpen SO THE SCENE OWNS EVERYTHING IT NEEDS. The original lives at
# res://ramon/Water/carried/LabKit/carried/Model/scripts/loft_builder_4d.gd and is what animation_test still uses. The two are
# now separate files: a change to the pig in one scene does NOT reach the other.

# No `class_name` - see the note at the top of cloud_field_4d.gd. Load this with
# preload() and call its static functions on the resulting script.

## Shared geometry for lofting a 4D mesh from a stack of 3D cross-sections.
##
## A "section" is a Dictionary: {"center": Vector4, "radius": float, "v_scale": float,
## "w_scale": float}. `v_scale` and `w_scale` squash or stretch it across its second
## visible axis and across W, so a section can be an ellipse rather than a circle.
## Its `center` places the cross-section in all four axes at once, so pushing a
## section along W is just a matter of where it sits - no separate offset knob.
##
## Sections are lofted bottom to top along Y. Only two tetrahedralizations are
## ever performed, both long-solved: a triangular prism between adjacent layers
## into 3 tetrahedra, and a cone from a layer to a single apex into 1 tetrahedron
## per triangle. General 4-polytope tetrahedralization is never attempted.


## Inserts interpolated sections between the authored ones, following a curve
## through them instead of a straight line.
##
## WHY: without this every span is a straight cone, so a smooth shape has to be
## brute-forced with ball count - a neck needs six balls and still creases at each
## one. A curve through the same balls gives the same shape from three.
##
## Catmull-Rom is the right curve here because it PASSES THROUGH its control points:
## a ball stays exactly where you put it, which a Bezier or B-spline would not
## guarantee. The ends duplicate their neighbour so the first and last spans curve
## sensibly rather than flying off.
##
## Radius, ellipse and W-scale are interpolated along the same curve, not linearly -
## otherwise a smoothly curving centreline would still have a visibly kinked
## silhouette where the thickness changed.
static func smooth_sections(sections: Array, segments: int) -> Array:
	if segments <= 1 or sections.size() < 2:
		return sections
	var last: int = sections.size() - 1
	var out: Array = []
	for span in range(last):
		var before: Dictionary = sections[maxi(span - 1, 0)]
		var start: Dictionary = sections[span]
		var end: Dictionary = sections[span + 1]
		var after: Dictionary = sections[mini(span + 2, last)]
		for step in range(segments):
			out.append(_interpolate_section(before, start, end, after, float(step) / float(segments)))
	out.append(sections[last])
	return out


static func _interpolate_section(before: Dictionary, start: Dictionary, end: Dictionary, after: Dictionary, t: float) -> Dictionary:
	return {
		"center": Vector4(
			_catmull_rom((before["center"] as Vector4).x, (start["center"] as Vector4).x, (end["center"] as Vector4).x, (after["center"] as Vector4).x, t),
			_catmull_rom((before["center"] as Vector4).y, (start["center"] as Vector4).y, (end["center"] as Vector4).y, (after["center"] as Vector4).y, t),
			_catmull_rom((before["center"] as Vector4).z, (start["center"] as Vector4).z, (end["center"] as Vector4).z, (after["center"] as Vector4).z, t),
			_catmull_rom((before["center"] as Vector4).w, (start["center"] as Vector4).w, (end["center"] as Vector4).w, (after["center"] as Vector4).w, t)),
		# Sizes must not go negative on an overshoot, which Catmull-Rom can do where
		# a thick section sits between two thin ones.
		"radius": maxf(_catmull_rom(before["radius"], start["radius"], end["radius"], after["radius"], t), 0.001),
		"v_scale": maxf(_catmull_rom(before.get("v_scale", 1.0), start.get("v_scale", 1.0), end.get("v_scale", 1.0), after.get("v_scale", 1.0), t), 0.001),
		"w_scale": maxf(_catmull_rom(before["w_scale"], start["w_scale"], end["w_scale"], after["w_scale"], t), 0.001),
		"roll": _catmull_rom(before.get("roll", 0.0), start.get("roll", 0.0), end.get("roll", 0.0), after.get("roll", 0.0), t),
		"squareness": _catmull_rom(before.get("squareness", 0.0), start.get("squareness", 0.0), end.get("squareness", 0.0), after.get("squareness", 0.0), t),
		# Colour blends linearly, not along the curve: a Catmull-Rom overshoot would
		# push channels outside 0..1 and read as a bright or black band.
		"color": (start.get("color", Color.WHITE) as Color).lerp(end.get("color", Color.WHITE), t),
		"basis": _lerp_basis(start.get("basis", Projection.IDENTITY), end.get("basis", Projection.IDENTITY), t),
	}


## How long a span may be, measured in section widths, before it is split.
##
## MEASURED, not chosen. Swept against the whole scene: 4.0 still leaves the
## brachiosaurus with 24 slivers, 3.5 is clean but is the last value that is, and 2.5,
## 3.0 and 3.5 are all clean. 3.5 therefore sits directly on the edge of failure, which
## is no place to leave a default that has to hold for models not yet built - so 3.0,
## a quarter below the first value known to break. The cost of that caution is roughly
## 30% more tetrahedra on the two models here.
##
## Raising it trades safety for tetrahedra and is only worth doing if a model gets
## heavy; check_no_slivers will say plainly if it has been raised too far.
const _MAX_SPAN_RATIO: float = 3.0

## The most pieces one span may be split into, so a ball shrunk to near nothing asks
## for a sane number of sections rather than hundreds of thousands.
const _MAX_SPAN_PIECES: int = 12


## Splits any span that is too long for how wide its sections are.
##
## WHY THIS IS NOT OPTIONAL, and not the `smoothing` knob: a stretched span produces
## SLIVERS - tetrahedra so flat the engine cannot invert their metric - and one sliver
## makes it discard the closest-point cache for the whole mesh, which is what the
## editor uses to click-pick a model. See check_no_slivers for the full chain. The
## model looks perfectly correct while being unselectable, so leaving this to be
## noticed and fixed by hand means it will not be.
##
## `smoothing` is the wrong tool for it: that subdivides EVERY span in a rig, and it
## interpolates along a curve, so it both overpays and restyles the model. Only one
## span on each of the two models in the scene actually produces slivers.
##
## Interpolation is LINEAR, deliberately, where `smooth_sections` is Catmull-Rom. This
## is a tessellation fix, not a shape change: the inserted sections land exactly on the
## line the authored balls already describe, so the silhouette is untouched. Curving
## them here would quietly restyle a model that only needed denser cells.
static func subdivide_long_spans(sections: Array, span_ratio: float = _MAX_SPAN_RATIO) -> Array:
	if sections.size() < 2:
		return sections
	var out: Array = []
	for span in range(sections.size() - 1):
		var start: Dictionary = sections[span]
		var end: Dictionary = sections[span + 1]
		out.append(start)
		# Width is the mean of the two radii: a span from a fat section to a thin one
		# fails on account of the thin end, and averaging keeps a taper from being
		# judged by its widest point alone.
		var width: float = (float(start["radius"]) + float(end["radius"])) * 0.5
		if width <= 0.0:
			continue
		var gap: float = (start["center"] as Vector4).distance_to(end["center"])
		var pieces: int = mini(int(ceil(gap / (span_ratio * width))), _MAX_SPAN_PIECES)
		for step in range(1, pieces):
			out.append(_lerp_section(start, end, float(step) / float(pieces)))
	out.append(sections[sections.size() - 1])
	return out


static func _lerp_section(start: Dictionary, end: Dictionary, t: float) -> Dictionary:
	return {
		"center": (start["center"] as Vector4).lerp(end["center"], t),
		"radius": lerpf(start["radius"], end["radius"], t),
		"v_scale": lerpf(start.get("v_scale", 1.0), end.get("v_scale", 1.0), t),
		"w_scale": lerpf(start["w_scale"], end["w_scale"], t),
		"roll": lerpf(start.get("roll", 0.0), end.get("roll", 0.0), t),
		"squareness": lerpf(start.get("squareness", 0.0), end.get("squareness", 0.0), t),
		"color": (start.get("color", Color.WHITE) as Color).lerp(end.get("color", Color.WHITE), t),
		"basis": _lerp_basis(start.get("basis", Projection.IDENTITY), end.get("basis", Projection.IDENTITY), t),
	}


## Blends two section bases column by column. A basis here is a linear map with no
## translation, so blending the columns blends the map - good enough for the scaling
## and mild tilt a ball's gizmo produces, and it collapses to a no-op when both ends
## are the identity, which is the common case.
static func _lerp_basis(start: Projection, end: Projection, t: float) -> Projection:
	if start == end:
		return start
	return Projection(
		(start.x as Vector4).lerp(end.x, t), (start.y as Vector4).lerp(end.y, t),
		(start.z as Vector4).lerp(end.z, t), (start.w as Vector4).lerp(end.w, t))


static func _catmull_rom(before: float, start: float, end: float, after: float, t: float) -> float:
	var t2: float = t * t
	var t3: float = t2 * t
	return 0.5 * ((2.0 * start)
		+ (-before + end) * t
		+ (2.0 * before - 5.0 * start + 4.0 * end - after) * t2
		+ (-before + 3.0 * start - 3.0 * end + after) * t3)


## Turns the -1..1 artist dial into a superellipsoid exponent: 2 is a sphere, higher
## squares it off, lower pinches it toward a star.
static func _squareness_exponent(squareness: float) -> float:
	return 2.0 * pow(4.0, clampf(squareness, -1.0, 1.0))


## Pushes a unit sphere direction onto the superellipsoid |x|^n + |y|^n + |z|^n = 1.
##
## WHY NOT A SHAPE DROPDOWN: sections can only loft into one another if they share
## topology, so a cube and a sphere could never blend. One exponent keeps the vertex
## layout identical at every value, which means a round belly really can flow into a
## square jaw - the sections in between are simply intermediate exponents.
static func _apply_squareness(direction: Vector3, exponent: float) -> Vector3:
	if is_equal_approx(exponent, 2.0):
		return direction
	var total: float = (pow(absf(direction.x), exponent)
		+ pow(absf(direction.y), exponent)
		+ pow(absf(direction.z), exponent))
	if total < 1e-6:
		return direction
	return direction * pow(total, -1.0 / exponent)


## Builds the lofted mesh, or null if the input can't make one.
## [param run_checks] turns off the three DIAGNOSTIC passes - watertightness, folding
## and slivers. They answer "is this model sound", which is worth knowing when a build
## is asked for and worth nothing on the intermediate shapes a ball sweeps through
## while being dragged. Each is a full pass over every cell, and watertightness alone
## does four dictionary inserts per cell, so on a fourteen-thousand-cell model they
## dominate the frame. Winding is NOT among them: it rewrites the cells rather than
## reporting on them, so it always runs.
## ARBORETUM (carried copy): `span_ratio` is how long a span may be against its width before it is
## split (subdivide_long_spans); the default is the original's. A tree's twigs are long and thin, and
## at 3 they would be split into many short spans for slivers nobody picks: the Arboretum lofts at a
## higher ratio (see Arboretum/carried/README.md).
static func build(sections: Array, rings: int, sides: int, taper_ends: bool, verbose: bool, align_to_spine: bool = true, smoothing: int = 1, run_checks: bool = true, span_ratio: float = _MAX_SPAN_RATIO) -> ArrayTetraMesh4D:
	if sections.size() < 2:
		push_warning("Loft: need at least 2 sections, got %d." % sections.size())
		return null
	sections = smooth_sections(sections, smoothing)
	sections = subdivide_long_spans(sections, span_ratio)

	var profile: Dictionary = build_profile_surface(rings, sides)
	var directions: PackedVector3Array = profile["directions"]
	var triangles: PackedInt32Array = profile["triangles"]
	var frames: Array = build_frames(sections, align_to_spine)

	var positions := PackedVector4Array()
	var layer_starts := PackedInt32Array()
	# One block of vertices per section, always in the same profile order, so
	# layer L's copy of profile vertex V is at L * count + V. Everything below
	# relies on that correspondence - it is what CAD lofting calls compatibility
	# and what makes "which point joins to which" unambiguous.
	for index in range(sections.size()):
		layer_starts.append(positions.size())
		var section: Dictionary = sections[index]
		var center: Vector4 = section["center"]
		var radius: float = section["radius"]
		var v_scale: float = section.get("v_scale", 1.0)
		var w_scale: float = section["w_scale"]
		var frame: Array = frames[index]
		var axis_u: Vector4 = frame[0]
		var axis_v: Vector4 = frame[1]
		var axis_n: Vector4 = frame[2]

		# ROLL spins the section within its own plane. Without it a section's twist is
		# entirely decided by where the frame happened to arrive, so an ellipse can
		# only ever lie the one way - no twisting fins, blades or curling horns.
		var roll: float = deg_to_rad(section.get("roll", 0.0))
		if not is_zero_approx(roll):
			var turned_u: Vector4 = axis_u * cos(roll) + axis_v * sin(roll)
			axis_v = axis_v * cos(roll) - axis_u * sin(roll)
			axis_u = turned_u

		var exponent: float = _squareness_exponent(section.get("squareness", 0.0))
		# The ball's own basis is applied to the finished cross-section, which is what
		# makes gizmo scaling work on EVERY axis. Folding it into radius and the two
		# scales instead - as this used to - meant deciding in advance which of the
		# ball's local axes were the section's, and that answer changes with the spine
		# direction. A horizontal body's sections stand in X, W and Y, so a ball scaled
		# vertically was being ignored outright. A linear map of the section needs no
		# such guess and is exact for any orientation.
		var section_basis: Projection = section.get("basis", Projection.IDENTITY)
		for direction in directions:
			var shaped: Vector3 = _apply_squareness(direction, exponent)
			positions.append(center + section_basis * (
				axis_u * (shaped.x * radius)
				+ axis_v * (shaped.y * radius * v_scale)
				+ axis_n * (shaped.z * radius * w_scale)))

	var cells := PackedInt32Array()
	# Which section each vertex came from, so texture coordinates can be assigned
	# below without re-deriving it from the vertex index - the two taper apexes sit
	# after every section in the array but belong to the two ENDS, which index
	# arithmetic alone would get backwards for the bottom one.
	var vertex_section := PackedInt32Array()
	for index in range(sections.size()):
		for slot in range(directions.size()):
			vertex_section.append(index)

	# Each cap collapses to its OWN section's centre, never a shared one. A piece
	# that has drifted off-axis and fans back to a distant apex sweeps across empty
	# space and produces long diagonal "sail" artifacts.
	if taper_ends:
		var bottom_apex: int = positions.size()
		positions.append(_section_apex(sections[0], frames[0][3], -0.55))
		vertex_section.append(0)
		_append_cone(cells, layer_starts[0], bottom_apex, triangles, true)

	for layer in range(sections.size() - 1):
		_append_prisms(cells, layer_starts[layer], layer_starts[layer + 1], triangles)

	if taper_ends:
		var last: int = sections.size() - 1
		var top_apex: int = positions.size()
		positions.append(_section_apex(sections[last], frames[last][3], 0.55))
		vertex_section.append(last)
		_append_cone(cells, layer_starts[layer_starts.size() - 1], top_apex, triangles, false)

	# One colour per tetrahedron, laid down in the SAME ORDER the cells were appended
	# above - bottom cap, then each span, then top cap - so the two arrays line up
	# without the append helpers needing to know anything about colour.
	var colors := PackedColorArray()
	var triangle_count: int = triangles.size() / 3
	if taper_ends:
		_fill_color(colors, triangle_count, sections[0].get("color", Color.WHITE))
	for layer in range(sections.size() - 1):
		var blended: Color = (sections[layer].get("color", Color.WHITE) as Color).lerp(
			sections[layer + 1].get("color", Color.WHITE), 0.5)
		_fill_color(colors, triangle_count * 3, blended)
	if taper_ends:
		_fill_color(colors, triangle_count, sections[sections.size() - 1].get("color", Color.WHITE))

	var watertight: bool = check_watertight(cells, verbose) if run_checks else true
	var flipped: int = make_winding_consistent(cells, positions, verbose)
	if run_checks:
		check_not_folded(cells, positions, sections, verbose)
		check_no_slivers(cells, positions, vertex_section, verbose)
	if verbose:
		print("[Loft] %d sections, %d vertices, %d tetrahedra, %d flipped, watertight=%s" % [
			sections.size(), positions.size(), cells.size() / 4, flipped, watertight
		])

	# TEXTURE COORDINATES - the route by which a model gets more than one colour.
	#
	# Per-cell colours are stored and validated but never reach the GPU: the proxy
	# mesh's vertex channels are entirely spoken for (Custom 0-3 carry the cell's four
	# 4D positions, and UV/UV2/Normal/Colour carry exactly these UVW coordinates), and
	# the material hands the shader one flat albedo plus one sampler3D. A texture
	# lookup is therefore the only multi-colour path the renderer actually has, and
	# these coordinates are what feed it.
	#
	# Section i is placed at texel i's CENTRE of a ramp one texel wide per section, so
	# a ball's own colour lands on it exactly and the sampler's linear filter does the
	# blending across the spans in between - the same blend the per-cell path did, but
	# smooth along the chain rather than one flat colour per span.
	#
	# Built AFTER the winding pass: that pass swaps two vertices inside any cell it
	# flips, and these indices are positional, so building them earlier would hand a
	# fifth of the model its neighbour's colour.
	var texture_map := PackedVector3Array()
	var section_count: int = sections.size()
	for index in range(section_count):
		texture_map.append(Vector3((float(index) + 0.5) / float(section_count), 0.5, 0.5))
	var texture_indices := PackedInt32Array()
	texture_indices.resize(cells.size())
	for slot in range(cells.size()):
		texture_indices[slot] = vertex_section[cells[slot]]

	var built := ArrayTetraMesh4D.new()
	built.set_vertex_positions(positions)
	built.set_simplex_cell_vertex_indices(cells)
	built.set_texture_map_values(texture_map)
	built.set_simplex_cell_texture_map_indices(texture_indices)
	built.calculate_boundary_normals(false)
	# Carried as metadata because a mesh has nowhere to store colour - it lives on the
	# material, which the rig owns and which may be shared across several chains.
	# `loft_colors` is one entry per tetrahedron for the per-cell path; `loft_ramp` is
	# one per section, in the same order as the texture coordinates above, and is what
	# the ramp texture is baked from. It is emitted here rather than recomputed by the
	# rig because SMOOTHING has already run - the sections at this point are the
	# interpolated ones, and there are more of them than there are balls.
	built.set_meta("loft_colors", colors)
	var ramp := PackedColorArray()
	for section in sections:
		ramp.append(section.get("color", Color.WHITE))
	built.set_meta("loft_ramp", ramp)
	return built


static func _fill_color(colors: PackedColorArray, count: int, color: Color) -> void:
	for index in range(count):
		colors.append(color)


static func _section_apex(section: Dictionary, tangent: Vector4, distance: float) -> Vector4:
	var center: Vector4 = section["center"]
	var radius: float = section["radius"]
	return center + tangent * (distance * radius)


## One orientation frame per section, as [axis_u, axis_v, axis_n, tangent].
##
## WHY THIS EXISTS: without it every cross-section is a flat horizontal slice, so
## the moment the stack leans the model is SHEARED - the outline stays level while
## the body runs diagonally, which reads as a squashed, skewed tube rather than a
## round one following its own centreline. Orienting each section perpendicular to
## the local spine direction is what CAD lofting does and what makes a leaning or
## curving model come out round.
##
## TWIST: picking a perpendicular frame from scratch at each section would make the
## profile spin arbitrarily from one to the next, and the surface between them
## would corkscrew. Instead each frame is carried forward from its predecessor and
## re-squared against the new tangent - the discrete form of a rotation-minimizing
## frame, i.e. parallel transport in the curve's normal bundle. Note that in 4D the
## space perpendicular to a curve is three-dimensional, so this frame has a full
## SO(3) of freedom rather than 3D's single angle.
##
## When [param align_to_spine] is false every frame is the global (X, Z, W), which
## reproduces flat horizontal slices exactly.
static func build_frames(sections: Array, align_to_spine: bool) -> Array:
	var count: int = sections.size()
	var frames: Array = []
	var up := Vector4(0.0, 1.0, 0.0, 0.0)

	if not align_to_spine:
		for index in range(count):
			frames.append([
				Vector4(1.0, 0.0, 0.0, 0.0),
				Vector4(0.0, 0.0, 1.0, 0.0),
				Vector4(0.0, 0.0, 0.0, 1.0),
				up,
			])
		return frames

	# Central differences, so a section's frame answers to both of its neighbours
	# and the surface passes through a bend smoothly instead of kinking at it.
	var tangents: Array = []
	for index in range(count):
		var lower: Vector4 = sections[maxi(index - 1, 0)]["center"]
		var upper: Vector4 = sections[mini(index + 1, count - 1)]["center"]
		var tangent: Vector4 = upper - lower
		if tangent.length() < 0.0001:
			tangent = up
		tangents.append(tangent.normalized())

	# Seeding with the global axes means a perfectly vertical stack reproduces the
	# unaligned frame exactly, so turning alignment on changes nothing until the
	# model actually leans.
	var seeds: Array = [
		Vector4(1.0, 0.0, 0.0, 0.0),
		Vector4(0.0, 0.0, 1.0, 0.0),
		Vector4(0.0, 0.0, 0.0, 1.0),
	]
	for index in range(count):
		var frame: Array = _orthonormal_frame(tangents[index], seeds)
		frame.append(tangents[index])
		frames.append(frame)
		seeds = [frame[0], frame[1], frame[2]]
	return frames


## Three orthonormal vectors spanning the space perpendicular to [param tangent],
## taken from [param seeds] where possible so the frame stays as close as it can to
## the one it inherited. Gram-Schmidt, with the standard axes as a fallback for
## seeds that collapse.
static func _orthonormal_frame(tangent: Vector4, seeds: Array) -> Array:
	var frame: Array = []
	var candidates: Array = seeds.duplicate()
	candidates.append_array([
		Vector4(1.0, 0.0, 0.0, 0.0),
		Vector4(0.0, 1.0, 0.0, 0.0),
		Vector4(0.0, 0.0, 1.0, 0.0),
		Vector4(0.0, 0.0, 0.0, 1.0),
	])
	for candidate in candidates:
		var vector: Vector4 = candidate - tangent * candidate.dot(tangent)
		for existing in frame:
			vector -= existing * vector.dot(existing)
		if vector.length() > 0.001:
			frame.append(vector.normalized())
		if frame.size() == 3:
			break
	return frame


## A closed, triangulated 3D surface - the shape of one cross-section, as unit
## directions in (X, Z, W). The poles are single vertices fanned to by the end
## rings rather than degenerate quads, so the surface is genuinely closed.
static func build_profile_surface(rings: int, sides: int) -> Dictionary:
	var directions := PackedVector3Array()
	directions.append(Vector3(0.0, 0.0, 1.0)) # North pole, at +W.
	for ring in range(1, rings):
		var theta: float = PI * float(ring) / float(rings)
		for slot in range(sides):
			var phi: float = TAU * float(slot) / float(sides)
			directions.append(Vector3(sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta)))
	var south_pole: int = directions.size()
	directions.append(Vector3(0.0, 0.0, -1.0))

	var triangles := PackedInt32Array()
	for slot in range(sides):
		triangles.append_array([0, 1 + slot, 1 + (slot + 1) % sides])
	for ring in range(1, rings - 1):
		var this_base: int = 1 + (ring - 1) * sides
		var next_base: int = 1 + ring * sides
		for slot in range(sides):
			var next_slot: int = (slot + 1) % sides
			triangles.append_array([this_base + slot, next_base + slot, next_base + next_slot])
			triangles.append_array([this_base + slot, next_base + next_slot, this_base + next_slot])
	var last_base: int = 1 + (rings - 2) * sides
	for slot in range(sides):
		triangles.append_array([south_pole, last_base + (slot + 1) % sides, last_base + slot])

	return {"directions": directions, "triangles": triangles}


## Bridges two adjacent layers, splitting each triangular prism into 3 tetrahedra.
##
## THE DIAGONAL RULE: a prism has 3 quadrilateral side faces, each splittable two
## ways - 8 combinations, of which 6 decompose into exactly 3 tetrahedra and 2 are
## impossible without adding a vertex. Two prisms sharing a quad must pick the SAME
## diagonal or a crack opens. Sorting each triangle's vertices by profile index and
## always running the diagonal from the lower index's bottom copy to the higher
## index's top copy makes both neighbours reach the same answer independently,
## because both see the same two profile indices on the quad they share.
static func _append_prisms(cells: PackedInt32Array, bottom_start: int, top_start: int, triangles: PackedInt32Array) -> void:
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


## Fans every triangle of one layer to a single apex - 1 tetrahedron each. This is
## what closes a free end; a layer left as an ordinary cross-section leaves the
## hypersurface open there, and a hole breaks cross-section tracing across a far
## larger region than its own size.
static func _append_cone(cells: PackedInt32Array, layer_start: int, apex: int, triangles: PackedInt32Array, reverse: bool) -> void:
	var triangle_count: int = triangles.size() / 3
	for triangle in range(triangle_count):
		var first: int = layer_start + triangles[triangle * 3]
		var second: int = layer_start + triangles[triangle * 3 + 1]
		var third: int = layer_start + triangles[triangle * 3 + 2]
		if reverse:
			cells.append_array([first, third, second, apex])
		else:
			cells.append_array([first, second, third, apex])


## Every face of a closed model must be shared by EXACTLY 2 tetrahedra - the 4D
## analog of every edge in a closed 3D mesh belonging to exactly 2 triangles.
static func check_watertight(cells: PackedInt32Array, verbose: bool) -> bool:
	var face_counts := {}
	var cell_count: int = cells.size() / 4
	for cell in range(cell_count):
		for slot in range(4):
			var key: int = _face_key_of(cells, cell, slot)
			face_counts[key] = face_counts.get(key, 0) + 1
	var open_faces: int = 0
	var overshared: int = 0
	for count in face_counts.values():
		if count == 1:
			open_faces += 1
		elif count > 2:
			overshared += 1
	if open_faces == 0 and overshared == 0:
		if verbose:
			print("[Loft] Watertight: all %d faces shared by exactly 2 tetrahedra." % face_counts.size())
		return true
	push_warning("[Loft] NOT watertight: %d open faces, %d over-shared, of %d total." % [open_faces, overshared, face_counts.size()])
	return false


## Warns when the surface has folded through itself on a bend.
##
## WHY THE OTHER TWO CHECKS CANNOT SEE THIS: both are topological. A loft that
## doubles back through its own surface still has every face shared by exactly two
## tetrahedra, and still has every neighbour agreeing on orientation. It is a
## perfectly valid closed surface that happens to occupy the same space twice, so
## watertightness and winding both pass while the model visibly tears.
##
## The test is geometric instead: on a tube, every outward normal must point away
## from the spine. One that points back at it can only mean the surface has folded
## over. Verified to read exactly zero on straight and gently bent chains.
##
## WHEN IT HAPPENS: when a bend is sharp relative to how thick the sections are
## compared to their spacing. Sections at 0.4x their spacing survive any angle
## tested; at 1.0x they start folding around 150 degrees; at 1.5x - sections wider
## than they are apart - they fold by 127 degrees. Either space the balls further
## apart, make them thinner, or bend less. This is inherent to lofting, and is
## exactly why Spore summed metaball fields instead: overlapping blobs merge, so
## there is no such thing as folding through yourself.
static func check_not_folded(cells: PackedInt32Array, positions: PackedVector4Array, sections: Array, verbose: bool) -> bool:
	var centers := PackedVector4Array()
	for section in sections:
		centers.append(section["center"])
	var folded: int = 0
	var cell_count: int = cells.size() / 4
	for cell in range(cell_count):
		var a: Vector4 = positions[cells[cell * 4]]
		var b: Vector4 = positions[cells[cell * 4 + 1]]
		var c: Vector4 = positions[cells[cell * 4 + 2]]
		var d: Vector4 = positions[cells[cell * 4 + 3]]
		var centroid: Vector4 = (a + b + c + d) * 0.25
		var outward: Vector4 = centroid - _nearest_on_spine(centers, centroid)
		if outward.length() < 0.0001:
			continue
		if Vector4D.perpendicular(b - a, c - a, d - a).dot(outward) < 0.0:
			folded += 1
	if folded == 0:
		if verbose:
			print("[Loft] Not folded: every face points away from the spine.")
		return true
	push_warning("[Loft] FOLDED THROUGH ITSELF: %d of %d tetrahedra (%.0f%%) face inwards - the bend is too sharp for sections this thick. Space the balls further apart, shrink them, or bend less." % [
		folded, cell_count, 100.0 * float(folded) / float(cell_count)])
	return false


## Warns when the model contains SLIVERS - tetrahedra so flat that the engine cannot
## build its closest-point cache for them.
##
## WHY THIS MATTERS, and why none of the other three checks see it: a sliver is a
## perfectly valid cell. It is watertight, correctly wound, and not folded. But
## `TetraMesh4D::populate_inverse_metric_cache` inverts each cell's metric, and a flat
## cell has no inverse - so on meeting ONE it prints an error and throws the ENTIRE
## cache away (tetra_mesh_4d.cpp:49). `raycast_intersects_fast` then returns false for
## every ray, and the editor's picking pass drops the node from its candidate list
## outright (editor_main_viewport_4d.cpp:268-276), so a single bad cell out of ten
## thousand makes a whole model impossible to select by clicking it.
##
## Note what this does NOT affect: the model draws normally, and shooting is untouched,
## because weapons raycast through PhysicsServer4D against CollisionShape4D rather than
## against the mesh. The cost is mesh raycasting alone.
##
## WHERE THEY COME FROM: splitting a triangular prism into 3 tetrahedra always
## produces two with three corners on one layer and only one on the other. Stretch
## that prism - balls far apart relative to how wide the sections are - and those two
## become long thin spikes. It shows up first at the profile's poles, where the
## triangles are smallest. This is inherent to lofting, not a mistake in the split:
## the cure is more sections along the span, either more balls or more smoothing.
##
## The test is the ENGINE'S OWN, reproduced rather than approximated, so this can
## never disagree with the error in the Output panel. It normalizes the three edges
## before taking the determinant, which makes it a measure of SHAPE and not size - a
## tiny cell is fine, a flat one is not, whatever the model's scale.
static func check_no_slivers(cells: PackedInt32Array, positions: PackedVector4Array, vertex_section: PackedInt32Array, verbose: bool) -> bool:
	var cell_count: int = cells.size() / 4
	var slivers: int = 0
	var worst: float = INF
	var worst_section: int = 0
	for cell in range(cell_count):
		var a: Vector4 = positions[cells[cell * 4]]
		var quality: float = _cell_shape(a,
			positions[cells[cell * 4 + 1]],
			positions[cells[cell * 4 + 2]],
			positions[cells[cell * 4 + 3]])
		if quality < worst:
			worst = quality
			worst_section = vertex_section[cells[cell * 4]]
		# CMP_EPSILON, the cutoff in Geometry4D::compute_inverse_metric_3x3.
		if quality <= 0.00001:
			slivers += 1
	if slivers == 0:
		if verbose:
			print("[Loft] No slivers: every tetrahedron has a shape the engine can invert (worst %.6f)." % worst)
		return true
	push_warning("[Loft] SLIVERS: %d of %d tetrahedra (%.1f%%) are too flat for the engine to build its closest-point cache, worst around section %d. The model still draws normally and physics is unaffected - what breaks is mesh raycasting, so it can no longer be selected by clicking it in the viewport, only from the Scene tree. The balls there are too far apart for how wide the sections are - add a ball on that span, or raise smoothing." % [
		slivers, cell_count, 100.0 * float(slivers) / float(cell_count), worst_section])
	return false


## How far a tetrahedron is from flat, on the engine's own scale: the determinant of
## the Gram matrix of its three edges after normalizing them. 1 is an ideal corner,
## 0 is flat, and it does not change if the whole model is scaled.
static func _cell_shape(a: Vector4, b: Vector4, c: Vector4, d: Vector4) -> float:
	var edge1: Vector4 = b - a
	var edge2: Vector4 = c - a
	var edge3: Vector4 = d - a
	var length1: float = edge1.length()
	var length2: float = edge2.length()
	var length3: float = edge3.length()
	if length1 <= 0.0 or length2 <= 0.0 or length3 <= 0.0:
		return 0.0
	var n01: float = edge1.dot(edge2) / (length1 * length2)
	var n02: float = edge1.dot(edge3) / (length1 * length3)
	var n12: float = edge2.dot(edge3) / (length2 * length3)
	return (1.0 - n12 * n12) + n01 * (n02 * n12 - n01) + n02 * (n01 * n12 - n02)


## Nearest point on the spine polyline. Snapping to the nearest ball instead leaves
## a large component along the chain in "outward", and the test flips at random.
static func _nearest_on_spine(centers: PackedVector4Array, point: Vector4) -> Vector4:
	var best: Vector4 = centers[0]
	var best_distance: float = point.distance_to(best)
	for index in range(centers.size() - 1):
		var start: Vector4 = centers[index]
		var span: Vector4 = centers[index + 1] - start
		var length_squared: float = span.dot(span)
		if length_squared < 1e-9:
			continue
		var candidate: Vector4 = start + span * clampf((point - start).dot(span) / length_squared, 0.0, 1.0)
		var distance: float = point.distance_to(candidate)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best


## Makes every tetrahedron agree with its neighbours on which way is outward.
##
## Three things matter, each of which is a documented real-world bug in this
## technique: adjacency is keyed by VERTEX SET rather than local face index (a
## flip permutes which local index maps to which geometric face, so a cached index
## silently goes stale); the remaining global sign is resolved once per CONNECTED
## COMPONENT rather than per tetrahedron (per-tetrahedron breaks on anything not
## star-convex); and the result is re-verified rather than trusted.
static func make_winding_consistent(cells: PackedInt32Array, positions: PackedVector4Array, verbose: bool) -> int:
	var cell_count: int = cells.size() / 4
	# The SET of four face keys belonging to a tetrahedron is invariant under a
	# flip - flipping only permutes which slot holds which set - so this adjacency
	# map is built once and stays valid throughout. What is NOT invariant is the
	# orientation each slot induces, which is why the comparison below always
	# re-derives the oriented triple from the current cells array.
	var face_owners := {}
	for cell in range(cell_count):
		for slot in range(4):
			var key: int = _face_key_of(cells, cell, slot)
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
			for slot in range(4):
				var key: int = _face_key_of(cells, current, slot)
				for other in face_owners[key]:
					if other == current or visited[other] == 1:
						continue
					# Correctly-oriented neighbours induce OPPOSITE cycles on the
					# face they share, so sharing a cycle means disagreement.
					if _slots_share_cycle(cells, current, slot, other, key):
						_flip_cell(cells, other)
						flipped_total += 1
					visited[other] = 1
					queue.append(other)
		flipped_total += _resolve_component_sign(cells, positions, component)

	var inconsistent: int = _count_inconsistent_faces(cells, face_owners)
	if inconsistent == 0:
		if verbose:
			print("[Loft] Winding consistent: 0 disagreeing faces after the fix.")
	else:
		push_warning("[Loft] Winding STILL inconsistent: %d disagreeing faces." % inconsistent)
	return flipped_total


## Resolves one connected component's single remaining global sign by a
## divergence-theorem sum: each tetrahedron's 4D perpendicular (the engine's
## generalized cross product, 3 vectors -> 1 perpendicular) dotted against the
## vector from the component's reference point to its own centroid. Negative means
## the whole component is inside-out.
static func _resolve_component_sign(cells: PackedInt32Array, positions: PackedVector4Array, component: PackedInt32Array) -> int:
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
		total += Vector4D.perpendicular(b - a, c - a, d - a).dot(_cell_centroid(cells, positions, cell) - reference)

	if total >= 0.0:
		return 0
	for cell in component:
		_flip_cell(cells, cell)
	return component.size()


static func _count_inconsistent_faces(cells: PackedInt32Array, face_owners: Dictionary) -> int:
	var inconsistent: int = 0
	for key in face_owners:
		var owners: Array = face_owners[key]
		if owners.size() != 2:
			continue
		var slot: int = _slot_with_key(cells, owners[0], key)
		if slot < 0:
			continue
		if _slots_share_cycle(cells, owners[0], slot, owners[1], key):
			inconsistent += 1
	return inconsistent


## Which of a tetrahedron's four vertices make up each of its four boundary
## faces, oriented by the standard boundary operator so that a consistently-
## oriented pair of neighbours induces OPPOSITE cycles on the face they share.
## Held as a flat table and read by index so no per-face array is ever allocated -
## this runs sixteen times per tetrahedron per rebuild, which at live-drag rates
## is the difference between a responsive rig and a slideshow.
const _FACE_SLOTS: Array = [
	1, 2, 3,
	0, 3, 2,
	0, 1, 3,
	0, 2, 1,
]

## Vertex indices are packed three to an int64, 21 bits each, so a face is
## identified by its vertex SET without building a string. 21 bits caps a model at
## 2,097,151 vertices, orders of magnitude beyond anything this builder produces.
const _KEY_BITS: int = 21


## The key of one face of one tetrahedron. Identifies the face by vertex SET, so
## it is unchanged by a flip - which is exactly the property that makes it safe to
## key adjacency on, where a local face index would silently go stale.
static func _face_key_of(cells: PackedInt32Array, cell: int, slot: int) -> int:
	var base: int = cell * 4
	var offset: int = slot * 3
	var lo: int = cells[base + _FACE_SLOTS[offset]]
	var mid: int = cells[base + _FACE_SLOTS[offset + 1]]
	var hi: int = cells[base + _FACE_SLOTS[offset + 2]]
	var swap: int
	if lo > mid:
		swap = lo
		lo = mid
		mid = swap
	if mid > hi:
		swap = mid
		mid = hi
		hi = swap
	if lo > mid:
		swap = lo
		lo = mid
		mid = swap
	return lo | (mid << _KEY_BITS) | (hi << (_KEY_BITS * 2))


static func _slot_with_key(cells: PackedInt32Array, cell: int, key: int) -> int:
	for slot in range(4):
		if _face_key_of(cells, cell, slot) == key:
			return slot
	return -1


## Whether two tetrahedra run the same way round the face they share. Correctly
## oriented neighbours must NOT - they induce opposite cycles on it - so a true
## result here means the second one needs flipping.
static func _slots_share_cycle(cells: PackedInt32Array, cell_a: int, slot_a: int, cell_b: int, key: int) -> bool:
	var slot_b: int = _slot_with_key(cells, cell_b, key)
	if slot_b < 0:
		return false
	var base_a: int = cell_a * 4
	var base_b: int = cell_b * 4
	var offset_a: int = slot_a * 3
	var offset_b: int = slot_b * 3
	var first: int = cells[base_a + _FACE_SLOTS[offset_a]]
	var second: int = cells[base_a + _FACE_SLOTS[offset_a + 1]]
	for rotation in range(3):
		if cells[base_b + _FACE_SLOTS[offset_b + rotation]] == first:
			return cells[base_b + _FACE_SLOTS[offset_b + (rotation + 1) % 3]] == second
	return false


static func _flip_cell(cells: PackedInt32Array, cell: int) -> void:
	var swap: int = cells[cell * 4]
	cells[cell * 4] = cells[cell * 4 + 1]
	cells[cell * 4 + 1] = swap


static func _cell_centroid(cells: PackedInt32Array, positions: PackedVector4Array, cell: int) -> Vector4:
	return (positions[cells[cell * 4]]
		+ positions[cells[cell * 4 + 1]]
		+ positions[cells[cell * 4 + 2]]
		+ positions[cells[cell * 4 + 3]]) / 4.0
