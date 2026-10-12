## Builds an ArrayTetraMesh4D approximating a 4D box's boundary (the same
## "8 flat cubic cells" shape BoxTetraMesh4D represents - see that engine
## class), but with each of the 8 cells subdivided into a grid of smaller
## cells instead of BoxTetraMesh4D's single fixed ~5-40 cell decomposition.
##
## Why this exists: BoxTetraMesh4D has NO subdivision parameter at all - its
## 16 vertices are always exactly the box's own 16 corners, regardless of
## box size (confirmed directly by reading box_tetra_mesh_4d.cpp/.h this
## session). That's fine for opaque/flat-colored 4D objects, but for a
## texture-mapped surface sampling something detailed (like clouds' FBM
## noise), it causes a real, visible bug: at 4D rotations where the
## Cross-Section slicing plane nearly grazes one of those few large cells,
## the resulting thin sliver's per-vertex local coordinate sweeps through a
## huge fraction of the cell's full range over very little screen area -
## invisible in a coarse coordinate-as-color debug view, but massively
## amplified once that coordinate feeds a noise function, producing visible
## banding. The terrain mesh doesn't show this because it's built from many
## thousands of small tetrahedra (one tiny cell per grid point) instead of a
## handful of large ones - this class applies that same fix to a plain box.
##
## Each of the 8 macro-cells (the box's 8 "cubic faces", e.g. the +W cell is
## the flat 3D region {(x,y,z,+half_extent.w)}) is independently subdivided
## into a grid of smaller cells across its own 3 free axes, each further
## split into 5 tetrahedra via the standard "cube -> 5 simplices" identity
## (1 central tetrahedron spanning the cube's 4 even-parity corners, plus 4
## corner tetrahedra cut off at the odd-parity corners - a well-known,
## gap-free, non-overlapping decomposition). Subdivision count is chosen
## per axis from a target cell size rather than a flat count, so a thin
## axis (like the clouds slab's Y thickness) isn't wastefully subdivided
## while a large axis (the footprint) gets real subdivision.
##
## Seam correctness is automatic, not a special case: all 8 macro-cells and
## every sub-cell within them compute vertex positions from ONE shared,
## continuous box-local coordinate formula (never resetting to a per-cell
## local origin), and ArrayTetraMesh4D.append_tetra_cell_points's default
## position-based deduplication merges any two sub-cells' shared corners
## into the same vertex automatically. Since clouds.gdshader samples noise
## from that same continuous position (not a per-cell 0..1 UV), there is no
## per-tile noise pattern to repeat at a seam in the first place - adjacent
## cells are just neighboring samples of one continuous field, exactly like
## adjacent terrain bricks already are.

## Standard 5-tetrahedra decomposition of a cube, corners indexed by parity
## bit pattern (corner_index = dx + 2*dy + 4*dz, matching the loop below).
## T0 is the central tetrahedron (the 4 even-parity corners); T1-T4 each cut
## off one odd-parity corner using its 3 edge-adjacent (even-parity) cube
## neighbors. The corner *sets* are the standard, well-known construction,
## but the ORDER within each tuple was originally picked without checking
## handedness, which does matter here: the Cross-Section renderer's output
## triangle winding (and therefore backface culling) is derived from each
## tetrahedron's own vertex order, so 5 tets that partition a cube's volume
## correctly can still render with holes if some of them wind the opposite
## way from the others. Confirmed directly this session: computing the
## signed volume (scalar triple product) of each tuple below against unit
## cube corners 0=(0,0,0)..7=(1,1,1) showed T2 and T4's original order
## ([2,0,3,6], [7,3,5,6]) came out positive while T0/T1/T3 came out
## negative - a real, measured inconsistency, not a hypothetical one, and
## exactly what produced the sawtooth holes in the first subdivided-box
## test render. Fixed by swapping each mismatched tet's last two corners
## (swapping any 2 corners of a tetrahedron flips its signed volume) so all
## 5 now share the same (negative) handedness.
const CUBE_TETRA_CORNERS = [
	[0, 3, 5, 6],
	[1, 0, 3, 5],
	[2, 0, 6, 3],
	[4, 0, 5, 6],
	[7, 3, 6, 5],
]


## half_extents: the box's own half-size per axis (same meaning as
## BoxTetraMesh4D.half_extents). target_cell_size: desired sub-cell edge
## length in world units - actual subdivision count per axis is derived
## from this (at least 1), so a short axis naturally gets little or no
## subdivision instead of wasting cells on an axis that was never the
## problem.
##
## exclude_axis (-1 = include everything) skips BOTH macro-cells for that
## axis. Confirmed directly this session as the real fix lever for the
## grazing-angle noise banding: at identity rotation a hypercube's w=0
## cross-section is formed entirely by the +-X/+-Y/+-Z cells, since the
## +-W cells' corners all share one w value and never cross - but at
## extreme combined rotations (e.g. xw+zw both near 90 degrees), the +-W
## cells start crossing too, contributing a cell that's "just barely
## becoming visible": inherently thin, near-degenerate geometry, sensitive
## in a way NO amount of subdivision fixed (tested up to ~500x - see git
## history), but excluding the marginal axis's cells removed the vast
## majority of the artifact in that same test. NOT currently used by
## clouds_layer.gd - which axis is marginal depends on the LIVE rotation,
## so a real fix needs to pick it dynamically, not hardcode one axis.
## Hard per-axis cap, independent of target_cell_size. A too-small
## target_cell_size isn't just slow, it's a real, demonstrated hang: this
## session, a target_cell_size of 1.0 on a 48-unit footprint (48
## subdivisions/axis, ~1.4M tetrahedra) froze the engine outright building
## a single mesh - the GDScript build loop plus ArrayTetraMesh4D's
## position-based vertex dedup never even finished. 32/axis is already far
## more than any legitimate use needs (8 macro-cells x 32^3 x 5 = ~1.3M
## tets at the cap's own worst case is still a lot - this is a safety
## ceiling, not a recommended operating point).
const MAX_SUBDIVISIONS_PER_AXIS: int = 32

## jitter_fraction: displaces INTERIOR sub-cell grid lines (never the
## macro-cell's own outer boundary, or a shared macro-cell-to-macro-cell
## seam would open up) by up to this fraction of one grid step, tapered
## smoothly to exactly zero at both ends of each free axis via a sine
## taper. Exists for the grazing-angle banding investigation (see the
## clouds shader's own git history for the fuller account): a near-
## degenerate w=0 crossing makes an individual tetrahedron's sampled
## position wildly unstable, but on a perfectly REGULAR grid, which
## specific tetrahedra are near-degenerate at a given rotation is itself
## spatially correlated with the grid - producing a coherent, repeating
## stripe/moire pattern rather than incoherent noise. Jittering the grid
## breaks that correlation: the same per-tetrahedron instability should
## still occur, but scattered at irregular intervals instead of aligned
## into visible parallel lines - a structural lever, independent of any
## degeneracy THRESHOLD, unlike every shader-side mitigation tried before
## this (alpha suppression, blur, cell-center fallback - see
## CLOUDS_BANDING_TECHNICAL_SUMMARY.md), all three of which shared the same
## weakness: no single threshold value was both "fixes the worst case" and
## "invisible at moderate rotations," because the trigger signal itself
## doesn't predict on-screen severity. This targets the MECHANISM instead
## of gating a response to it.
##
## The jitter is a deterministic hash of (axis, grid index s) alone, NOT
## of which macro-cell is calling it - two different macro-cells that both
## use the same axis as a free axis (with the same subdivision count,
## since subdivisions[] is shared) compute IDENTICAL jittered coordinate
## values for the same s, so ArrayTetraMesh4D's position-based vertex
## dedup still merges shared vertices correctly within a macro-cell.
## Cross-macro-cell seams stay exact because the taper is exactly zero at
## s=0 and s=steps, where a free axis coordinate hits its own +-half_extent
## - the true box-boundary vertices are never displaced.
##
## RESULT (tested at 0.3, the largest value comfortably clear of self-
## intersection risk): confirmed via pixel-diff to genuinely change ~40%
## of rendered pixels (not a no-op), yet the banding's gross STRIPE
## pattern survived essentially unchanged, at both the 80deg problem
## rotation alone and combined with the shipped blur mitigation. Why: the
## stripes are contiguous BANDS of topologically-ADJACENT near-degenerate
## cells (a real, continuous region of near-critical geometry) - jittering
## a cell's exact POSITION doesn't change which cells are adjacent to
## which, so a jittered band of cells is still a contiguous band, still
## reads as a stripe. Defaults to 0 (disabled): since it doesn't help,
## there's no reason to pay its cost (a small amount of extra hashing per
## build, and gratuitously different rendered output) by default. Kept in,
## not deleted, as tested infrastructure - see this constant's own header
## for what a jitter-based fix would actually require (breaking topological
## adjacency, not just position).
const DEFAULT_JITTER_FRACTION: float = 0.0

static func _jitter_hash(axis: int, s: int) -> float:
	var x: float = sin(float(axis * 92821 + s * 12007)) * 43758.5453
	return (x - floor(x)) - 0.5


static func build(half_extents: Vector4, target_cell_size: float, exclude_axis: int = -1, jitter_fraction: float = DEFAULT_JITTER_FRACTION) -> ArrayTetraMesh4D:
	var mesh := ArrayTetraMesh4D.new()
	var subdivisions := PackedInt32Array()
	subdivisions.resize(4)
	for axis in range(4):
		var full_extent: float = half_extents[axis] * 2.0
		subdivisions[axis] = clampi(ceili(full_extent / target_cell_size), 1, MAX_SUBDIVISIONS_PER_AXIS)

	# Ours: per-CELL (sub-cube) center, box-local X/Z only (the two axes
	# clouds.gdshader's sampling coordinate actually reads - see
	# CELL_CENTER_XZ's own comment there), stashed via
	# texture_map_values / simplex_cell_texture_map_indices - one of the only genuinely free per-corner
	# data channels TetraMesh4D exposes (see that class's own
	# update_cross_section_mesh(), which packs this straight through
	# UV/UV2/NORMAL/COLOR with no compression on the UV slot specifically,
	# unlike NORMAL, which gets renormalized, or COLOR, which gets
	# [0,1]-clamped). Exists to let the shader fall back to a value that's
	# the SAME for every tetrahedron sharing a sub-cube - and therefore
	# genuinely continuous across a near-degenerate region - instead of
	# each tetrahedron's own unstable mix_weight-interpolated corner. See
	# this shader's git history for why an EARLIER attempt at this same
	# idea (blending toward a fixed LOCAL parametric weight of 0.5) failed:
	# 0.5 in one tet's own parametrization isn't the same physical point as
	# 0.5 in a neighbor's. A cell center has no such ambiguity - it's one
	# well-defined point, independent of which tetrahedron or edge asks for
	# it.
	var cell_center_xz := PackedVector3Array()

	for fixed_axis in range(4):
		if fixed_axis == exclude_axis:
			continue
		# _build_cell RETURNS its own portion rather than appending into a
		# passed-in array - GDScript's PackedArray params are copy-on-write,
		# so mutating one in place inside a callee is not guaranteed to be
		# visible to the caller once more than one reference to it exists.
		cell_center_xz.append_array(_build_cell(mesh, half_extents, subdivisions, fixed_axis, -1.0, jitter_fraction))
		cell_center_xz.append_array(_build_cell(mesh, half_extents, subdivisions, fixed_axis, 1.0, jitter_fraction))

	mesh.texture_map_values = cell_center_xz
	mesh.simplex_cell_texture_map_indices = PackedInt32Array(range(cell_center_xz.size()))
	return mesh


## Builds one of the box's 8 macro-cells (fixed_axis at fixed_sign *
## half_extents[fixed_axis]), subdivided into a grid across its 3 free axes.
## Returns this cell's portion of the per-tetrahedron cell-center-XZ array
## (4 identical entries per tetrahedron, same order as the tets this call
## appends to mesh) - see build()'s own comment for why.
static func _build_cell(mesh: ArrayTetraMesh4D, half_extents: Vector4, subdivisions: PackedInt32Array, fixed_axis: int, fixed_sign: float, jitter_fraction: float) -> PackedVector3Array:
	var free_axes := PackedInt32Array()
	for axis in range(4):
		if axis != fixed_axis:
			free_axes.append(axis)

	# Precomputed grid coordinate values along each free axis, from
	# -half_extent to +half_extent in subdivisions[axis] steps. Interior
	# values (0 < s < steps) get displaced by a deterministic hash of
	# (axis, s), tapered to zero at both ends via sin(PI*t) - see build()'s
	# own comment for why this exists and why it's safe for seams.
	var coord_values := []
	for slot in range(3):
		var axis: int = free_axes[slot]
		var he: float = half_extents[axis]
		var steps: int = subdivisions[axis]
		var step_size: float = (2.0 * he) / float(steps)
		var values := PackedFloat64Array()
		for s in range(steps + 1):
			var t: float = float(s) / float(steps)
			var value: float = lerp(-he, he, t)
			if jitter_fraction > 0.0 and s > 0 and s < steps:
				var taper: float = sin(PI * t)
				value += taper * _jitter_hash(axis, s) * jitter_fraction * step_size
			values.append(value)
		coord_values.append(values)

	var fixed_value: float = fixed_sign * half_extents[fixed_axis]
	# Mirroring one axis (the fixed_sign < 0 case, relative to fixed_sign >
	# 0) flips handedness - swap 2 of the 8 corner slots to compensate so
	# both signs of the same axis wind outward consistently.
	#
	# A SECOND, independent handedness flip was found later (via the
	# shrubbery port's own per-voxel standalone-box use case, which
	# exercises all 4 fixed_axis choices symmetrically for one small
	# closed box - a configuration this class's original single-cloud-
	# slab use case, verified only by one windowed screenshot at identity
	# rotation, never stressed the same way): free_axes is always the
	# OTHER 3 axes in ascending numeric order, so which position
	# fixed_axis itself sits at within the full 4-axis ordering (0..3)
	# changes the PARITY of the (free_axis0, free_axis1, free_axis2,
	# fixed_axis) permutation relative to the canonical (0,1,2,3) order -
	# CUBE_TETRA_CORNERS assumes one fixed handedness in local (d0,d1,d2)
	# coordinates, so embedding it back into full 4D space via an ODD
	# permutation (fixed_axis is odd: Y or W) produces the OPPOSITE
	# handedness from an EVEN permutation (fixed_axis is even: X or Z).
	# Confirmed directly, not guessed: a standalone box's boundary
	# normals came back backward (negative dot product against the known-
	# correct outward-from-center direction) for BOTH signs of exactly
	# the Y and W macro-cells, and correct for BOTH signs of X and Z -
	# precisely the even/odd axis-index split this second flip predicts
	# and corrects (_verify_voxel_box_normals_runner.gd).
	var flip_winding: bool = (fixed_sign < 0.0) != (fixed_axis % 2 == 1)
	var cell_center_xz := PackedVector3Array()

	for i in range(subdivisions[free_axes[0]]):
		for j in range(subdivisions[free_axes[1]]):
			for k in range(subdivisions[free_axes[2]]):
				var corners := []
				corners.resize(8)
				for corner_idx in range(8):
					var d0: int = corner_idx & 1
					var d1: int = (corner_idx >> 1) & 1
					var d2: int = (corner_idx >> 2) & 1
					var pos := Vector4()
					pos[fixed_axis] = fixed_value
					pos[free_axes[0]] = coord_values[0][i + d0]
					pos[free_axes[1]] = coord_values[1][j + d1]
					pos[free_axes[2]] = coord_values[2][k + d2]
					corners[corner_idx] = pos

				# This sub-cube's own center, box-local X/Z only - see
				# build()'s own comment for why only these two axes matter.
				var center := Vector4()
				center[fixed_axis] = fixed_value
				center[free_axes[0]] = (coord_values[0][i] + coord_values[0][i + 1]) * 0.5
				center[free_axes[1]] = (coord_values[1][j] + coord_values[1][j + 1]) * 0.5
				center[free_axes[2]] = (coord_values[2][k] + coord_values[2][k + 1]) * 0.5
				var center_xz := Vector3(center.x, center.z, 0.0)

				for tet in CUBE_TETRA_CORNERS:
					var a: Vector4 = corners[tet[0]]
					var b: Vector4 = corners[tet[1]]
					var c: Vector4 = corners[tet[2]]
					var d: Vector4 = corners[tet[3]]
					if flip_winding:
						mesh.append_tetra_cell_points(a, b, d, c)
					else:
						mesh.append_tetra_cell_points(a, b, c, d)
					cell_center_xz.append(center_xz)
					cell_center_xz.append(center_xz)
					cell_center_xz.append(center_xz)
					cell_center_xz.append(center_xz)

	return cell_center_xz


## CARRIED (Arboretum, 5 Oct 2026): a copy of res://scripts/subdivided_box_tetra_mesh_4d.gd, its class_name taken
## out and its references preloaded (Arboretum/carried/README.md).
