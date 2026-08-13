class_name BearingUtility4D
extends RefCounted
## Milestone 3: the one function W-targeting, the POI arrow, and the compass/
## minimap all need - how far a target sits outside the visible slice, and
## which way to rotate to fix it. Pure math: only reads a global transform
## and a world position, never touches rendering.
##
## Takes the Player body itself, NOT the camera/head chain. Player.gd applies
## yaw (zx) and slice-rotation (xw/zw) directly to the Player body's own
## basis - that's the frame "which way to drag to reduce ana_offset" is
## defined in. Pitch lives only on PlayerHead, layered on top of Player's
## basis purely for where the camera looks; it has no bearing on which way
## to turn or slice-rotate, so reading through the camera would incorrectly
## fold pitch into every result here (confirmed bug: depth_component drifted
## with pitch alone, no yaw/turn involved).

## Node4D.global_basis is a Projection (Godot core type); its .x/.y/.z/.w
## members are the basis columns directly (confirmed throughout this project,
## e.g. gimbal_basis.w/.z usage in player_4d.gd and the test scripts) - no
## get_column() needed.
static func compute(body: Node4D, target_position: Vector4) -> Dictionary:
	return compute_raw(body.global_position, body.global_basis, target_position)


## Same computation as [method compute], but taking the observer's position/
## basis as plain values rather than reading them off a live Node4D. Needed
## wherever the "observer" for bearing purposes ISN'T the thing that visually
## carries the 4D rotation - e.g. voxel_port's hover-camera convention
## rotates the TERRAIN (rig_path), never the camera itself (see
## voxel_hover_camera_4d.gd's own header on why), so the correct observer
## basis for "is this on the currently-visible slice" is the rig's basis,
## while the correct observer position is still the camera's - two different
## nodes, neither of which alone is the right single Node4D to pass to
## [method compute].
static func compute_raw(observer_position: Vector4, observer_basis: Projection, target_position: Vector4) -> Dictionary:
	var rel: Vector4 = target_position - observer_position
	var basis: Projection = observer_basis
	var ana_offset: float = rel.dot(basis.w)
	var rel_length: float = rel.length()
	return {
		"rel": rel,
		# Zero = exactly on the slice boundary (visible). Sign = which side.
		"ana_offset": ana_offset,
		# Governs how much xw (right-ana) rotation is needed.
		"right_component": rel.dot(basis.x),
		# Governs how much zw (forward-ana) rotation is needed. This engine's
		# DIR_FORWARD = (0,0,-1,0), so a target straight ahead has a NEGATIVE
		# depth_component - the name describes what it governs, not "how far
		# ahead" in an intuitive positive-is-forward sense.
		"depth_component": rel.dot(basis.z),
		# How far off the current slice the target is, as a genuine angle
		# rather than a raw distance - a fixed distance threshold behaves
		# inconsistently depending on range (trivial to satisfy for a close
		# target, near-impossible for a far one at the same raw ana_offset);
		# an angle is range-independent. rel_length==0 only when body is
		# exactly at target_position - falls back to 0 rather than dividing
		# by zero.
		"angle_off_slice": asin(clampf(ana_offset / rel_length, -1.0, 1.0)) if rel_length > 0.0001 else 0.0,
	}

## Sign of the xw-plane rotation (feed into Rotor4D.from_xw(sign * step)) that
## reduces |ana_offset| for the given bearing, as a small incremental step -
## not a single-shot exact angle. (The exact angle, atan2(ana_offset,
## right_component), is degenerate right where it matters most: an
## already-near-slice target with negative right_component solves to a
## near-180-degree "correction" that's technically exact but not the minimal
## useful direction. Incremental nudging - the same shape of use as a POI
## arrow or turn-assist - sidesteps that entirely.)
##
## Derivation: for a pure xw rotation by angle theta, ana_offset(theta) =
## -right_component*sin(theta) + ana_offset(0)*cos(theta) (from Basis4D's xw
## rotation convention: basis.x=(cos,0,0,sin), basis.w=(-sin,0,0,cos)). The
## derivative of ana_offset^2 at theta=0 with respect to theta is
## -2*ana_offset*right_component, so ana_offset^2 decreases for a small step
## whose sign matches sign(ana_offset * right_component).
static func xw_correction_sign(bearing: Dictionary) -> float:
	return signf(bearing.ana_offset * bearing.right_component)

## Same derivation, for the zw plane (forward-ana) via depth_component.
static func zw_correction_sign(bearing: Dictionary) -> float:
	return signf(bearing.ana_offset * bearing.depth_component)
