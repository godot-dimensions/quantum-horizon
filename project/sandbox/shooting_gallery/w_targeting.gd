extends Node
## W-targeting: cycle between currently active targetable objects (the red
## gallery target and every active duck), continuously realigning the
## player's horizontal slice orientation so the selected target - and, in
## dual mode, one of its neighbors in the cycle order - stay on the visible
## slice, with the selection (and pairing) highlighted on the radar.
##
## Deliberately re-solved every physics frame, not just once at the moment of
## selection: targets like ducks keep moving after being selected, so a one-
## shot realign would let them (or whichever neighbor was paired with them)
## quietly drift back out of the slice as soon as they moved. Continuously
## re-solving and re-easing toward the live result keeps the guarantee true
## for as long as a target stays selected, not just at the instant of
## selecting it.
##
## Two modes, toggled with a middle-click (toggle_target_mode) - cycling
## itself is mouse wheel up/down (cycle_target_next/cycle_target_prev),
## deliberately not rotate_4d, which is already double-booked in player.gd
## for slice-rotation-drag and a one-off raycast test:
## - Dual (default): tries to keep the selected target AND a list-neighbor on
##   the slice together (see _solve_ana_direction()).
## - Single: only tracks the selected target, ignoring neighbors entirely -
##   useful when a neighbor's own movement would otherwise make dual mode's
##   continuous readjustment feel too restless to aim through.
##
## The math (see _solve_ana_direction()) works entirely in the horizontal
## x/z/w subspace - y is dropped throughout, since y is vertical look, not
## part of the slice. Treating the surviving x/z/w triple as an ordinary
## 3-vector and using the standard 3D cross product is deliberate and exact
## here (not an approximation of some "real" 4D cross product, which doesn't
## exist as a vector operation - only as a bivector/wedge): the result is
## guaranteed orthogonal to both inputs *within* that 3D subspace, which is
## exactly "a horizontal direction that puts both targets on the slice."
##
## Reaches directly into GalleryTargetSpawner._current_target and
## DuckRowSpawner._ducks, matching the existing convention slice_radar.gd
## already uses (both are otherwise-private fields with no public
## accessor) - not new coupling, just the same pattern.

const BearingUtility4D = preload("res://scripts/bearing_utility_4d.gd")

const REALIGN_TIME_CONSTANT_SEC := 0.13 # ~95% converged by ~0.4s (3 time constants) - tune by feel.
const SNAP_ANGLE_EPSILON := 0.001 # Radians - close enough to skip re-easing this frame.
const DEGENERATE_SIN_THRESHOLD := 0.02 # sin(angle between a and b) below this counts as collinear.

@onready var player: CharacterBody4D = $"../FlatPlane/Player"
@onready var spawner: Node4D = $"../FlatPlane/GalleryTargetSpawner"
@onready var duck_spawner: Node4D = $"../FlatPlane/DuckRowSpawner"
@onready var contest_player: Node4D = $"../FlatPlane/ContestSequencePlayer"
@onready var slice_radar: Control = $"../RadarOrbHud/SliceRadar"

var _selected_target: Node4D = null
## The list-neighbor actually used to solve _target_ana_direction, if any -
## null when the fallback path (single target, single mode, or both
## neighbors degenerate) was used instead. Exposed so the radar can show a
## distinct second indicator for it, alongside the primary selection.
var _secondary_target: Node4D = null
var _target_ana_direction: Vector4 = Vector4.ZERO
## Dual: track the selected target and a neighbor together. Single: track
## only the selected target. Toggled by toggle_target_mode (middle-click).
var _dual_mode: bool = true


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"cycle_target_next"):
		_cycle(1)
	elif event.is_action_pressed(&"cycle_target_prev"):
		_cycle(-1)
	elif event.is_action_pressed(&"toggle_target_mode"):
		_dual_mode = not _dual_mode


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_selected_target):
		return
	var targets: Array = _get_active_targets()
	var selected_index: int = targets.find(_selected_target)
	if selected_index == -1:
		# No longer active (caught, or otherwise despawned) since the last
		# frame - nothing left to track until the next cycle.
		_selected_target = null
		_secondary_target = null
		slice_radar.highlighted_object = null
		slice_radar.secondary_highlighted_object = null
		return

	_target_ana_direction = _solve_ana_direction(targets, selected_index)
	slice_radar.secondary_highlighted_object = _secondary_target

	var current_n: Vector4 = player.global_basis.w
	var cos_angle: float = clampf(current_n.dot(_target_ana_direction), -1.0, 1.0)
	if acos(cos_angle) <= SNAP_ANGLE_EPSILON:
		# Already there this frame - nothing to rotate, so skip building a
		# rotor for it entirely rather than feeding vector_product() two
		# identical/near-identical vectors (a zero-angle geometric product it
		# doesn't normalize cleanly).
		return
	var fraction: float = 1.0 - exp(-delta / REALIGN_TIME_CONSTANT_SEC)
	_apply_rotor_step(current_n, fraction)


func _apply_rotor_step(current_n: Vector4, fraction: float) -> void:
	var rotor: Rotor4D = _rotor_from_to(current_n, _target_ana_direction)
	if rotor == null:
		return # Antipodal - no well-defined shortest path this frame; try again next frame.
	# Deliberately NOT rotate_rotor_local(), which composes in the player's
	# own current local frame (basis = basis * rotor.to_basis()) - the
	# rotation this system needs is defined in world terms (current_n and
	# _target_ana_direction are both global directions), so it has to rotate
	# the current *global* basis directly instead: rotate_basis() applies the
	# rotor to each basis column the same way rotate_vector() applies it to a
	# single vector, which is what actually moves global_basis.w from
	# current_n toward _target_ana_direction. Composing locally instead
	# converged to the wrong (roughly antipodal) direction in practice.
	player.global_basis = rotor.slerp_fraction(fraction).rotate_basis(player.global_basis)


## Builds a Rotor4D that takes `from_dir` exactly to `to_dir` (shortest path,
## in the plane they span). Rotor4D.vector_product(a, b) alone double-rotates
## by the angle between a and b (per its own doc comment: the inputs should
## be half the desired rotation apart), so the standard bisector trick is
## used to get a single exact rotation instead - the same construction as
## the classic "shortest-arc quaternion."
func _rotor_from_to(from_dir: Vector4, to_dir: Vector4) -> Rotor4D:
	var a: Vector4 = from_dir.normalized()
	var b: Vector4 = to_dir.normalized()
	var bisector: Vector4 = a + b
	if bisector.length() < 0.0001:
		return null # a and b point in opposite directions - bisector undefined.
	return Rotor4D.vector_product(a, bisector.normalized()).normalized()


func _get_active_targets() -> Array:
	var targets: Array = []
	if spawner._current_target != null and is_instance_valid(spawner._current_target):
		targets.append(spawner._current_target)
	for duck in duck_spawner._ducks:
		if is_instance_valid(duck):
			targets.append(duck)
	for contest_target in contest_player.get_active_targets():
		if is_instance_valid(contest_target):
			targets.append(contest_target)
	return targets


func _cycle(direction: int) -> void:
	var targets: Array = _get_active_targets()
	if targets.is_empty():
		return

	var current_index: int = -1
	if is_instance_valid(_selected_target):
		current_index = targets.find(_selected_target)

	var new_index: int = 0 if current_index == -1 else wrapi(current_index + direction, 0, targets.size())

	_selected_target = targets[new_index]

	# Same moment the slice starts easing - not before, not after.
	# _target_ana_direction/_secondary_target/the secondary highlight are
	# solved and kept in sync continuously from here on (see
	# _physics_process), not just once here - so a moving target, or
	# whichever neighbor is currently paired with it, never silently drifts
	# back out of the slice after the initial realign.
	slice_radar.highlighted_object = _selected_target


## Restricted to x/z/w - y (vertical look) is never part of the slice.
func _horizontal(v: Vector4) -> Vector4:
	return Vector4(v.x, 0.0, v.z, v.w)


## Ordinary 3D cross product on the x/z/w triple, packed into a Vector3 in
## that order and unpacked the same way - see the file-level doc comment for
## why this is exact here, not an approximation.
func _cross_xzw(a: Vector4, b: Vector4) -> Vector4:
	var a3 := Vector3(a.x, a.z, a.w)
	var b3 := Vector3(b.x, b.z, b.w)
	var c3: Vector3 = a3.cross(b3)
	return Vector4(c3.x, 0.0, c3.y, c3.z)


## Solves the new horizontal ana-direction for `targets[selected_index]`,
## trying (in dual mode) to also put one of its list-neighbors on the slice
## at the same time. Falls back to the smallest possible reorientation (just
## the selected target on the slice) in single mode, or when dual mode has no
## usable neighbor. Also sets _secondary_target as a side effect (the
## neighbor actually used, or null when the fallback path was taken).
func _solve_ana_direction(targets: Array, selected_index: int) -> Vector4:
	_secondary_target = null
	var player_pos: Vector4 = player.global_position
	var selected_pos: Vector4 = targets[selected_index].global_position
	var a: Vector4 = _horizontal(BearingUtility4D.compute(player, selected_pos).rel)
	var current_n: Vector4 = player.global_basis.w

	var target_count: int = targets.size()
	if _dual_mode and target_count >= 2:
		var next_index: int = (selected_index + 1) % target_count
		var prev_index: int = (selected_index - 1 + target_count) % target_count
		var neighbor_indices: Array = [next_index]
		if prev_index != next_index:
			neighbor_indices.append(prev_index)

		for neighbor_index in neighbor_indices:
			var b: Vector4 = _horizontal(BearingUtility4D.compute(player, targets[neighbor_index].global_position).rel)
			var cross: Vector4 = _cross_xzw(a, b)
			var sin_angle: float = cross.length() / (a.length() * b.length())
			if sin_angle >= DEGENERATE_SIN_THRESHOLD:
				var n: Vector4 = cross.normalized()
				# a x b's sign is an arbitrary artifact of which operand came
				# first - both +n and -n are equally valid slice normals (each
				# is orthogonal to both a and b), but only one of them keeps
				# the realign a short, stable rotation from where the player
				# is already facing. Blindly using whichever sign the cross
				# product happened to produce can demand a near-180-degree
				# "shortest path" - both a jarring flip and, right at the
				# antipodal point, numerically unstable (the bisector in
				# _rotor_from_to degenerates as the two vectors approach
				# opposite, which showed up as a real playtest bug: a
				# violently jittering camera stuck oscillating between two
				# orientations). Flipping to the near side keeps the angle
				# to at most 90 degrees, nowhere near that instability.
				if n.dot(current_n) < 0.0:
					n = -n
				_secondary_target = targets[neighbor_index]
				return n

	# Single target, or both neighbors were collinear with the player and the
	# selected target: fall back to the closest valid horizontal ana-
	# direction to the player's current one - project the current
	# ana-direction's component along the target out, keep the rest.
	var a_hat: Vector4 = a.normalized()
	var projected: Vector4 = current_n - current_n.dot(a_hat) * a_hat
	if projected.length() < 0.0001:
		# The target sits exactly along the current ana-direction - no
		# horizontal direction is meaningfully closer than the one we have.
		return current_n
	return projected.normalized()
