class_name QEFSolver4D
extends RefCounted
## Solves the 4x4 Quadratic Error Function that places a dual-contouring
## vertex, using a singular-value-clamped pseudo-inverse rather than a
## regularized direct inverse.
##
## The problem: given N surface crossings, each with a position p_i and a
## surface normal n_i, find the point x minimizing sum_i (n_i . (x - p_i))^2 -
## i.e. the point closest to lying on every crossing's tangent hyperplane at
## once. Setting the derivative to zero gives (sum_i n_i n_i^T) x = sum_i n_i
## (n_i . p_i), a 4x4 symmetric positive-semidefinite system.
##
## That system is frequently singular or near-singular, and *how* you handle
## that is what separates crisp terrain from mush. On a flat region every
## normal points the same way, so the matrix has rank 1: the solve pins x
## along the surface normal and says nothing about where x sits *within* the
## surface. Something has to choose the other 3 degrees of freedom.
##
## The naive fix - adding epsilon*I to the matrix before inverting (Tikhonov
## regularization) - pulls the answer toward the centroid in *every*
## direction, including the directions the solve had determined perfectly
## well. That rounds off exactly the sharp creases dual contouring exists to
## preserve. Instead, this decomposes the matrix (one-sided Jacobi SVD) and
## damps only the small singular values, so the centroid bias applies
## strictly to the underdetermined directions and well-conditioned
## directions keep their exact answer. Sharp edges survive; flat regions
## still get a stable, centered vertex.

## Iteration bound for the Jacobi sweep. Convergence on a 4x4 is typically
## 3-6 sweeps; this is a safety net against a pathological input spinning
## forever inside a @tool script and locking the editor, not a tuning knob.
const MAX_JACOBI_SWEEPS := 32

## The Jacobi sweep stops once the total off-diagonal movement in a full
## sweep drops below this. Matches the demo's tolerance - tighter buys no
## visible geometry change because the result is immediately clamped into a
## cell anyway.
const CONVERGENCE_THRESHOLD := 1e-4

## Column pairs are treated as already orthogonal (and skipped) below this
## dot product, which both saves work and avoids computing a rotation from
## what is numerically noise.
const ORTHOGONAL_EPSILON := 1e-12


## Returns the QEF-minimizing point for the given crossings.
##
## [param singular_cutoff] is the singular value below which a direction is
## treated as undetermined and handed back to the centroid. It is scaled by
## the crossing count by the caller, since the matrix is a *sum* over
## crossings and therefore grows with how many there are - a fixed cutoff
## would mean something different for a 3-crossing cell than a 20-crossing
## one.
##
## Everything is computed relative to the centroid of the crossing points, so
## that "zero" in the solved coordinate system already means "the centroid".
## That is what makes a fully-singular solve degrade gracefully to the
## centroid rather than to the origin, which could be arbitrarily far away.
static func solve(crossing_positions: Array[Vector4], crossing_normals: Array[Vector4], singular_cutoff: float) -> Vector4:
	var count: int = crossing_positions.size()
	if count == 0:
		return Vector4.ZERO

	var centroid := Vector4.ZERO
	for position in crossing_positions:
		centroid += position
	centroid /= float(count)

	# Accumulate A = sum_i n_i n_i^T (as 4 columns) and b = sum_i n_i (n_i . d_i),
	# where d_i is the crossing position relative to the centroid.
	var col_x := Vector4.ZERO
	var col_y := Vector4.ZERO
	var col_z := Vector4.ZERO
	var col_w := Vector4.ZERO
	var rhs := Vector4.ZERO
	for i in range(count):
		var n: Vector4 = crossing_normals[i]
		var d: Vector4 = crossing_positions[i] - centroid
		col_x += n * n.x
		col_y += n * n.y
		col_z += n * n.z
		col_w += n * n.w
		rhs += n * n.dot(d)

	var columns: Array[Vector4] = [col_x, col_y, col_z, col_w]
	var decomposition: Dictionary = _jacobi_svd(columns)
	var basis: Array[Vector4] = decomposition["basis"]
	var singular_values: PackedFloat64Array = decomposition["singular_values"]

	# A is symmetric positive-semidefinite, so its left and right singular
	# vectors coincide and the pseudo-inverse collapses to
	# A+ = sum_i inv_i * (u_i u_i^T). Applying that to `rhs` directly avoids
	# ever materializing a matrix product.
	var offset := Vector4.ZERO
	for i in range(4):
		var singular_value: float = singular_values[i]
		var inverse_value: float
		if absf(singular_value) > singular_cutoff:
			inverse_value = 1.0 / singular_value
		else:
			# Below the cutoff, fade the contribution out smoothly instead of
			# hard-zeroing it. A hard zero makes the vertex position jump
			# discontinuously as a cell crosses the threshold, which shows up
			# as visible popping along the boundary between flat and creased
			# terrain; this ramp keeps it continuous.
			inverse_value = singular_value / (singular_cutoff * singular_cutoff)
		offset += basis[i] * (inverse_value * basis[i].dot(rhs))

	var result: Vector4 = centroid + offset
	# A QEF solve can go genuinely non-finite on degenerate input (a zero-length
	# normal from a flat spot in the density field, for instance). The centroid
	# is a plain average of finite positions, so it is always a usable answer.
	if not (is_finite(result.x) and is_finite(result.y) and is_finite(result.z) and is_finite(result.w)):
		return centroid
	return result


## One-sided Jacobi SVD of a symmetric 4x4 given as 4 columns.
##
## Repeatedly applies plane rotations that orthogonalize pairs of columns.
## When every pair is mutually orthogonal, the columns are the (unnormalized)
## left singular vectors: their lengths are the singular values and their
## normalized directions are the basis. Chosen over the more common
## Golub-Kahan bidiagonalization because at 4x4 the sweep converges in a
## handful of passes and needs no bidiagonal phase, no shifts, and no
## special-casing - it is about 40 lines instead of several hundred.
##
## Returns {"basis": Array[Vector4], "singular_values": PackedFloat64Array}.
static func _jacobi_svd(columns: Array[Vector4]) -> Dictionary:
	var working: Array[Vector4] = columns.duplicate()

	for sweep in range(MAX_JACOBI_SWEEPS):
		var total_change := 0.0
		for i in range(4):
			for j in range(i + 1, 4):
				var col_i: Vector4 = working[i]
				var col_j: Vector4 = working[j]
				var dot_ij: float = col_i.dot(col_j)
				if absf(dot_ij) < ORTHOGONAL_EPSILON:
					continue # Already orthogonal - nothing to rotate away.
				var norm_difference: float = col_j.dot(col_j) - col_i.dot(col_i)
				var tangent: float
				if is_zero_approx(norm_difference):
					# Equal column norms: the rotation that orthogonalizes them
					# is exactly 45 degrees, which is the limit of the formula
					# below as norm_difference approaches zero (and where that
					# formula would divide by zero).
					tangent = 1.0
				else:
					var ratio: float = 2.0 * dot_ij / norm_difference
					tangent = ratio / (1.0 + sqrt(ratio * ratio + 1.0))
				var cosine: float = 1.0 / sqrt(1.0 + tangent * tangent)
				var sine: float = tangent * cosine
				working[i] = col_i * cosine - col_j * sine
				working[j] = col_j * cosine + col_i * sine
				total_change += absf(sine) * (absf(dot_ij) + absf(norm_difference))
		if total_change <= CONVERGENCE_THRESHOLD:
			break

	var basis: Array[Vector4] = []
	var singular_values := PackedFloat64Array()
	singular_values.resize(4)
	for i in range(4):
		var column: Vector4 = working[i]
		var length: float = column.length()
		singular_values[i] = length
		# A zero-length column means that direction contributed nothing; its
		# pseudo-inverse weight is zero regardless of the direction we pick, so
		# a zero vector is safe and avoids a divide-by-zero normalize.
		basis.append(Vector4.ZERO if is_zero_approx(length) else column / length)

	return {"basis": basis, "singular_values": singular_values}
