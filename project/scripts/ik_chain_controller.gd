extends Node4D
## Multi-joint IK via FABRIK (Forward And Backward Reaching Inverse
## Kinematics - Aristidou & Lasenby). Replaces the earlier CCD and
## closed-form two-bone solvers entirely - both were confirmed, by direct
## measurement, to have real, unfixed failure modes: CCD's one-shot
## anatomical seed didn't survive real per-frame convergence (a hind leg's
## cannon bone drifted into a non-anatomical near-horizontal orientation
## during ordinary gait, not just at spawn), and the two-bone solver's own
## per-frame law-of-cosines recompute showed sustained multi-frame
## tracking-lag residual growth (up to ~2.7 units, over runs of 100+
## consecutive frames) that was confirmed, by instrumenting the solver's
## own intermediate values directly, to be UNCORRELATED with any knee-angle
## branch flip or pole-vector sign flip - a genuine convergence-rate
## problem neither fix addressed, not a one-off bug either could patch.
## FABRIK solves arbitrary chain length generically via alternating
## forward/backward position-reaching passes over the WHOLE chain at once
## - no CCD-style greedy per-joint sweep with no memory of the prior
## configuration, and no closed-form formula special-cased to exactly 2
## free joints.
##
## joints[i] is a Node4D whose global_basis.y is the direction of segment i
## (length link_lengths[i]). joints[i+1] MUST be joints[i]'s own scene-tree
## CHILD, offset by local position (0, link_lengths[i], 0, 0) - unchanged
## from the earlier solvers' own convention (see _end_effector_position):
## that's what makes forward kinematics free once an orientation is
## applied, via ordinary child-transform propagation.
##
## No per-frame easing wraps the solve at all - every physics frame runs a
## full FABRIK solve against target.global_position exactly as it stands
## that frame, and applies the fully-converged result with a full-strength
## rotor snap per joint. Each joint's orientation is derived from its
## segment's two converged endpoints via the same shortest-arc rotor-slerp
## pattern already proven in single_joint_controller.gd/w_targeting.gd
## (Rotor4D.vector_product(a, bisector) - see _rotor_from_to).
##
## An EARLIER version of this file stepped the target itself - solving
## against current_effector.lerp(target_pos, fraction) instead of the true
## target, to produce smooth motion without blending each joint's own
## final orientation (which had its own, separately-confirmed failure
## mode). That was removed once it was recognized as unnecessary, not just
## suboptimal: the SWING-phase target this chain actually tracks
## (limb_prototype_foot_target.gd's own LIFTING/SWINGING states) is
## already a closed-form curve, computed fresh from elapsed swing time
## every frame (captured lift-off position, lerp to the known landing
## position, half-sine vertical arc) - not something that needs to be
## chased smoothly by the IK, since it never jumps or teleports on its
## own. Stepping the target on top of an already-smooth curve added a
## second, redundant lag with its own separate time constant to mistune:
## the target curve moves the full swing distance in swing_duration_sec
## (0.35s by default), while the step-target lag converged on its own,
## independent ~slew_time_constant_sec (also 0.35s) schedule - two
## staggered exponential/curve schedules chasing each other, neither
## necessarily catching up before the next state transition reset it. See
## the re-run gait-cycle trace after this change for whether removing it
## actually closes the previously-measured swing-phase residual (up to
## ~3.4 units) - reported plainly either way, not assumed.

const DEGENERATE_LENGTH_EPSILON := 0.0001
## Dot-product slack below which a joint is considered "already exactly
## there" and skipped this frame - a pure numerical no-op guard (avoiding
## a degenerate/zero-magnitude rotor build for a direction that hasn't
## meaningfully changed), NOT a "good enough" convergence tolerance.
const SNAP_ANGLE_EPSILON := 0.0000001

## How much of a chain's own straight-line-toward-target reference to
## blend into each frame's FABRIK seed - see solve_fabrik's own comment.
const SEED_REGULARIZATION_WEIGHT := 0.15

@export var joint_paths: Array[NodePath] = [] # Ordered base -> tip.
@export var link_lengths: Array[float] = [] # link_lengths[i] is the length of the segment attached to joints[i].
@export var target_path: NodePath

## FABRIK's own convergence controls - the "vibe" dial for future tuning,
## exposed now even though every chain currently uses the same value.
## fabrik_max_iterations caps the forward+backward pass count run per
## physics frame; fabrik_tolerance is how close the tip needs to land to
## target_path's own current position, in the same units as link_lengths,
## before iterating stops early.
@export var fabrik_tolerance: float = 0.01
@export var fabrik_max_iterations: int = 10

## Optional per-joint anatomical hinge range - placeholder, tune-by-feel
## values, not precisely derived. Leaving both arrays empty (the default)
## is a true no-op: every direction computed anywhere in the solve passes
## through _apply_hinge_constraint unchanged, so a chain with no
## configured range behaves exactly as if this feature didn't exist.
##
## Angle convention, unchanged from the earlier (CCD-era) hinge attempt:
## 0 degrees = pointing straight down (a segment's natural hang), positive
## = swinging toward _hinge_forward() (see that function), negative =
## swinging backward. For a 3-joint leg, the classic zigzag needs joint
## index 1 (the knee/elbow) to bend in the OPPOSITE rotational sense from
## joints 0 and 2 (hip/shoulder and ankle/wrist) - e.g. front-leg
## placeholders here are [-45,-5] (hip: mostly leaning back),
## [10,50] (knee: opposite sense - forward), [-15,15] (ankle: roughly
## neutral); back-leg placeholders mirror the SIGN on the first two
## (femur leans forward, knee bends backward) as established earlier this
## whole arc for two_bone_pole_sign/seed_bend_angles_deg (front and back
## legs want opposite senses to look like a real quadruped, not a mirror-
## image bug).
##
## STATUS: left empty (disabled) in every shipped scene, despite the
## mechanism below being real and independently verified (a 2-/5-joint
## static-target check with generous ranges converges correctly, and two
## genuine bugs - a naive clampf() on a circular angle, and a
## branch-blind seed - were found and fixed via direct numeric
## reproduction, not just live-rig trial and error). What's NOT yet
## resolved: with per-leg ranges tight enough to look anatomically
## distinctive (a real zigzag, not just "roughly vertical"), a REAL
## four-leg gait cycle still measured meaningfully sunk ground contact
## (~-1.8 to -2.2 units) that the isolated static/2-joint checks didn't
## reproduce - some interaction between the live, per-frame-changing
## anchor/target during real gait and the constrained solve's branch
## selection that the fixes above improved but didn't fully close.
## Re-enabling this needs either looser ranges than intended (giving up
## some anatomical distinctiveness) or further work on the branch-bias
## seed specifically for the live-gait case, not more of the same
## static-target verification this file's own history already covers.
@export var joint_hinge_min_deg: Array[float] = []
@export var joint_hinge_max_deg: Array[float] = []

## LOCAL-space fallback hinge-plane forward direction (transformed by this
## chain's own global_basis), used only when forward_direction_provider
## (below) is unset. Defaults to +X, matching this rig's own anchors
## (identity basis, never rotated - the creature's front-back axis IS
## world X) - see forward_direction_provider's own comment for why a
## FIXED direction isn't correct in general, just for this specific,
## X-only-wander scene.
@export var root_forward_local: Vector4 = Vector4(1, 0, 0, 0)

## Optional NodePath to an object exposing `get_travel_direction() ->
## Vector4` (duck-typed - matches limb_prototype_body.gd's own method).
## When set, this replaces root_forward_local as the hinge plane's forward
## reference, re-read fresh every frame. A FIXED root_forward_local was
## the ONLY option in the earlier (CCD-era) hinge attempt and was
## confirmed, by a brute-force search over the entire allowed hinge-angle
## space, to make the chain physically unable to reach targets requiring
## motion along an axis the fixed plane didn't contain - real for any body
## that wanders in genuinely time-varying directions (limb_prototype_
## test.tscn's own Body wanders in x/z/w, not just x). Left unset, nothing
## changes for a rig with no such concept.
@export var forward_direction_provider: NodePath

## Post-hoc anatomical bend shaping, run once per frame AFTER FABRIK has
## already fully converged - a DIFFERENT mechanism from the iteration-time
## joint_hinge_min_deg/max_deg above (which stays disabled), not a
## replacement tuned the same way. See _apply_plane_alignment_twist's own
## header for the full construction and why it structurally can't
## reproduce that system's ground-sinking regression: it never touches the
## anchor or the target, only re-derives each free intermediate point via
## an exact closed-form 2-point solve. Defaults OFF until verified
## (numerically, then visually) per this file's own established rollout
## pattern - see STATUS notes throughout this file for precedent.
@export var enable_plane_alignment_twist: bool = false
## Blend weight (0-1) toward the exact "flipped" position at the joint
## closest to the anchor - tunable, not derived from anything. Weight at
## joint i decays by twist_bend_decay each step further from the anchor
## (see _apply_plane_alignment_twist).
@export var twist_bend_base_weight: float = 0.6
@export var twist_bend_decay: float = 0.5

@onready var joints: Array[Node4D] = _resolve_joints()
@onready var target: Node4D = get_node(target_path)
@onready var _forward_direction_provider: Node = get_node(forward_direction_provider) if not forward_direction_provider.is_empty() else null

## DIAGNOSTIC - the exact target_pos read at the top of the most recent
## solve_fabrik() call, exposed for external verify scripts to compare
## directly against target_path's own live global_position at the same
## moment, without guessing from node-tree order alone whether the two are
## actually in sync a given frame.
var last_solved_target_pos: Vector4 = Vector4.ZERO

## Fallback bend-plane reference for _apply_plane_alignment_twist, reused
## whenever this frame's own hinge-forward/hip-to-foot references go
## near-parallel (an ill-defined plane) - see that function's own header.
## Default is an arbitrary but stable direction, so even the very first
## frame (before any "last frame" exists) has something well-defined.
var _last_plane_v: Vector4 = Vector4(0, 0, 1, 0)

## DIAGNOSTIC - how many times _apply_plane_alignment_twist's own triangle-
## inequality clamp (maxf(0, ...) on h) actually engaged, i.e. l1/l2/d
## stopped satisfying the triangle inequality for some upstream-blended
## anchor. Expected near-zero in ordinary operation - exposed for external
## verify scripts the same way limb_prototype_foot_target.gd's own
## reach_override_count is.
var twist_clamp_engaged_count: int = 0
## DIAGNOSTIC - the resolved plane-v used by the most recent
## _apply_plane_alignment_twist call, exposed for external verify scripts.
var last_plane_v_diagnostic: Vector4 = Vector4.ZERO


## Explicitly run AFTER whatever node owns target_path's own physics update
## (e.g. limb_prototype_foot_target.gd's FootTarget, which moves its own
## global_position every physics frame during LIFTING/SWINGING). Without
## this, Godot falls back to scene-tree declaration order for same-
## priority (default 0) nodes - which, for this rig, put the IK chain's
## own node EARLIER in the tree than its target, and it solved a whole
## physics step behind: every frame's solve read the TARGET's position
## from before that same frame's own update, a full-frame-late reference
## that only mattered visibly once the target started moving fast (mid-
## swing) - confirmed directly, freezing a mid-swing target and calling
## solve_fabrik() one extra time closed a ~0.25-unit residual to ~0.0085
## instantly, ruling out an iteration-budget or reach-limit explanation.
## A relative priority (any value greater than target_path's own node,
## whatever that happens to be - 0 if unset) is what actually matters, not
## a specific number; 1 is enough as long as nothing referenced via
## target_path sets its own priority higher than that.
func _ready() -> void:
	process_physics_priority = 1


func _resolve_joints() -> Array[Node4D]:
	var result: Array[Node4D] = []
	for joint_path in joint_paths:
		result.append(get_node(joint_path))
	return result


func _physics_process(_delta: float) -> void:
	solve_fabrik()


## Runs one whole-chain FABRIK solve against target.global_position exactly
## as it stands this frame, and applies the fully-converged result with a
## full-strength rotor snap per joint. Arbitrary chain length - nothing
## here special-cases a particular joint count.
##
## Callable directly (not just from _physics_process) for one-shot
## spawn-pose seeding - see limb_prototype_foot_target.gd's own
## _seed_spawn_pose - though that's no longer functionally different from
## an ordinary frame's own solve, since every frame already fully snaps.
func solve_fabrik() -> void:
	var n: int = joints.size()
	if n == 0:
		return

	var target_pos: Vector4 = target.global_position
	last_solved_target_pos = target_pos
	var anchor_pos: Vector4 = joints[0].global_position
	var current_effector: Vector4 = _end_effector_position()

	# Seed FABRIK's iteration from a BLEND of the chain's actual live
	# positions (the vast majority of the weight) and a canonical
	# straight-line-toward-target reference (a small, constant pull).
	#
	# Seeding purely from a canonical reference that already, by
	# construction, lands within fabrik_tolerance of the target (e.g. a
	# straight line pre-scaled to exactly the target's own distance) was
	# tried first and measured to fail badly: the convergence check passes
	# on iteration zero, so the forward/backward passes below never run
	# even once - no bend can ever be found, only whatever shape the seed
	# itself already has (confirmed directly: a 2-joint chain stuck at a
	# mathematically-avoidable 1.2-unit residual, unchanged over hundreds
	# of frames, because its straight-line seed already "solved" the
	# problem in a way that left its own last segment with zero real
	# distance left to close).
	#
	# Seeding purely from live positions (no canonical pull at all) was
	# tried before that and ALSO measured to fail, differently: once a
	# frame's motion left the chain in some contorted shape (confirmed
	# directly - a joint pointing sideways, a segment doubling back on
	# itself), every subsequent frame's solve just re-confirmed a
	# similarly-shaped nearby solution, since "nearest the current,
	# already-bad shape" perpetuates the badness rather than correcting
	# it - the chain could never escape once it fell in.
	#
	# A small constant blend gets both properties at once: mostly-live
	# seeding still requires FABRIK to genuinely iterate to reach the
	# target (so real bends keep getting found, not short-circuited),
	# while the canonical reference's small constant pull keeps nudging
	# any already-bad configuration back toward sanity every single
	# frame, preventing permanent lock-in.
	# For a joint with a configured hinge range, the canonical reference is
	# that joint's own MID-RANGE angle, not a blanket "aim at the target"
	# direction shared by every joint - a 3-joint chain reaching a
	# position (not orientation) target is redundant, with several
	# genuinely different valid bend "branches" (e.g. knee-forward vs
	# knee-backward), each with its OWN minimum achievable extension. A
	# toward-target seed doesn't prefer any branch, and was measured to
	# sometimes land in one whose minimum extension is BELOW the actual
	# target - not a shortfall but an OVERSHOOT past it, since the
	# constrained chain then does its best from the wrong branch. The
	# mid-range angle already satisfies the joint's own limits by
	# construction, biasing the seed toward the intended anatomical branch
	# before the target-reaching iteration even starts. Joints with no
	# configured range keep the original toward-target reference.
	var toward_target_dir: Vector4 = _safe_normalized(target_pos - anchor_pos, Vector4(0, -1, 0, 0))
	var canonical_point: Vector4 = anchor_pos
	var points: Array[Vector4] = [anchor_pos]
	for i in range(n):
		var canonical_dir: Vector4 = toward_target_dir
		if i < joint_hinge_min_deg.size() and i < joint_hinge_max_deg.size():
			var mid_angle: float = deg_to_rad((joint_hinge_min_deg[i] + joint_hinge_max_deg[i]) * 0.5)
			canonical_dir = (Vector4(0, -1, 0, 0) * cos(mid_angle) + _hinge_forward() * sin(mid_angle)).normalized()
		canonical_point += canonical_dir * link_lengths[i]
		var live_point: Vector4 = joints[i + 1].global_position if i + 1 < n else current_effector
		points.append(live_point.lerp(canonical_point, SEED_REGULARIZATION_WEIGHT))

	for _iteration in range(fabrik_max_iterations):
		if (points[n] - target_pos).length() <= fabrik_tolerance:
			break

		# Forward reaching pass: snap the tip to the target, then work
		# backward toward the anchor, preserving every segment's own length.
		# dir here is TIP-TO-BASE (points[i+1] -> points[i]) - the OPPOSITE
		# of the hinge constraint's own convention (matching
		# joints[i].global_basis.y and the backward pass below: BASE-TO-
		# TIP) - negate before and after constraining, and use the
		# NEGATED current direction as the degenerate-length fallback too.
		#
		# Leaving this pass entirely unconstrained was tried and measured
		# to still allow the same stuck-fixed-point pathology this whole
		# hinge feature already hit once (see _apply_hinge_constraint's own
		# header): the ACTUAL bug behind that pathology turned out to be
		# a naive clampf() on a circular angle (mapping a direction that
		# wants to point "up", genuinely reachable at 180 degrees away
		# from a limit's far side, onto the WRONG nearby limit rather than
		# the true shortest-arc one) plus a seed with no preference for
		# which of several valid bend branches to converge toward - not
		# "constraining both passes is inherently unsafe". With those two
		# bugs fixed (_apply_hinge_constraint's shortest-arc clamp, and
		# the per-joint mid-range-angle seed above), constraining this
		# pass too keeps the FORWARD estimate itself anatomically
		# plausible from the very first iteration, rather than only
		# reconciling it against the limits one pass later.
		points[n] = target_pos
		for i in range(n - 1, -1, -1):
			var dir: Vector4 = _safe_normalized(points[i] - points[i + 1], -joints[i].global_basis.y)
			dir = -_apply_hinge_constraint(i, -dir)
			points[i] = points[i + 1] + dir * link_lengths[i]

		# Backward reaching pass: re-pin the root to the TRUE current
		# anchor (a walking body's own attachment point can itself move
		# frame to frame - it's not a free FABRIK point like the rest of
		# the chain), then work forward toward the tip. When the target is
		# unreachable from here, this pass alone - no special casing
		# needed - is what produces FABRIK's well-known graceful
		# degradation: the chain simply straightens toward the target
		# instead of breaking or clamping. This is also what actually
		# determines each joint's applied orientation (see the final
		# application loop below, which mirrors this same base-to-tip
		# direction) - constraining it is what enforces the anatomical
		# limits on the real output; constraining the forward pass above
		# too keeps its own intermediate estimate plausible along the way.
		points[0] = anchor_pos
		for i in range(n):
			var dir: Vector4 = _safe_normalized(points[i + 1] - points[i], joints[i].global_basis.y)
			dir = _apply_hinge_constraint(i, dir)
			points[i + 1] = points[i] + dir * link_lengths[i]

	if enable_plane_alignment_twist:
		_apply_plane_alignment_twist(points, anchor_pos, target_pos, toward_target_dir)

	for i in range(n):
		var desired_dir: Vector4 = _safe_normalized(points[i + 1] - points[i], joints[i].global_basis.y)
		desired_dir = _apply_hinge_constraint(i, desired_dir)
		_snap_joint_toward(i, desired_dir)


## Post-hoc, non-iterative anatomical bend shaping - NOT another iteration-
## time constraint like joint_hinge_min_deg/max_deg above (that system
## stays disabled; this is a deliberately different mechanism, not a
## replacement tuned the same way). Runs exactly once, after FABRIK has
## already fully converged, and can never desync a segment length or miss
## the true target: every free intermediate point (points[1..n-1] -
## points[0]=anchor and points[n]=target are never touched) is re-derived
## via the exact, closed-form 2-point ("law of cosines") construction
## already proven for the earlier two-bone solver, generalized to solve
## WITHIN one fixed plane rather than assuming a fixed 3D frame, and
## chained sequentially from the anchor outward so each step's own two
## segment lengths are satisfied exactly regardless of what the previous
## step did to its own upstream anchor - the same reason the LAST joint's
## own solve, anchored to the untouched true target, hits that target
## exactly too. See this file's own plan-mode writeup (the DOF-counting
## argument) for why a single whole-chain rotation can't do this alone.
##
## The bend PLANE is fixed once per call from the hip-to-foot direction
## and the current travel direction - NOT a literal 4D cross product
## (undefined in 4D the way it is in 3D); the actual quantity a real leg's
## knee should track is the travel direction's own component perpendicular
## to the leg's own extension, which is exactly what v_raw computes below.
## Falls back to the PREVIOUS frame's plane (_last_plane_v) when the two
## references go near-parallel, per the original request.
func _apply_plane_alignment_twist(points: Array[Vector4], anchor_pos: Vector4, target_pos: Vector4, toward_target_dir: Vector4) -> void:
	var n: int = points.size() - 1
	if n < 2:
		return # No free intermediate point to adjust (a 1-segment chain has none).

	var hinge_forward_dir: Vector4 = _hinge_forward()
	var v_raw: Vector4 = hinge_forward_dir - toward_target_dir * hinge_forward_dir.dot(toward_target_dir)
	var v: Vector4
	if v_raw.length() > DEGENERATE_LENGTH_EPSILON:
		v = v_raw.normalized()
		_last_plane_v = v
	else:
		v = _last_plane_v
	last_plane_v_diagnostic = v

	for i in range(1, n):
		var a_point: Vector4 = points[i - 1]
		var b_point: Vector4 = points[i + 1]
		var l1: float = link_lengths[i - 1]
		var l2: float = link_lengths[i]
		var d: float = (b_point - a_point).length()
		if d < DEGENERATE_LENGTH_EPSILON:
			continue # Degenerate (coincident anchors) - leave this joint as FABRIK left it.
		var axis_i: Vector4 = (b_point - a_point) / d

		var perp_i: Vector4 = v - axis_i * v.dot(axis_i)
		if perp_i.length() < DEGENERATE_LENGTH_EPSILON:
			var arbitrary_axis := Vector4(1, 0, 0, 0)
			if absf(axis_i.dot(arbitrary_axis)) > 0.9:
				arbitrary_axis = Vector4(0, 0, 1, 0)
			perp_i = arbitrary_axis - axis_i * axis_i.dot(arbitrary_axis)
		perp_i = perp_i.normalized()

		# Exact closed-form 2-point solve (law of cosines): a and h are
		# derived so |flip_point-a_point|==l1 and |flip_point-b_point|==l2
		# EXACTLY whenever the triangle inequality holds for l1/l2/d, which
		# it provably does here since d comes from FABRIK's own
		# already-valid solve (a and b_point were themselves a valid
		# solution a moment ago).
		var a: float = (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
		var h_squared: float = l1 * l1 - a * a
		if h_squared < 0.0:
			twist_clamp_engaged_count += 1
		var h: float = sqrt(maxf(0.0, h_squared))
		var sign_i: float = 1.0 if i % 2 == 1 else -1.0
		var flip_dir: Vector4 = perp_i * sign_i

		if h < DEGENERATE_LENGTH_EPSILON:
			points[i] = a_point + axis_i * a # No perpendicular offset possible at all (a straight sub-segment) - nothing to point in any direction.
			continue

		# The point BEFORE any adjustment (points[i], still FABRIK's own
		# value at this point in the loop) already satisfies the exact same
		# two distance constraints (|.-a_point|==l1, |.-b_point|==l2) as
		# flip_point does, by the SAME law-of-cosines derivation - meaning
		# its own along-axis coordinate and perpendicular RADIUS are
		# already exactly a and h too (up to FABRIK's own float/convergence
		# noise), and only its perpendicular DIRECTION differs. Blending
		# the raw POSITIONS (a straight lerp) does NOT preserve this - the
		# midpoint of a chord is strictly inside the circle both points
		# sit on, not on it (confirmed directly: an earlier version of this
		# function did exactly that and measured segment lengths coming out
		# 2-3% short on a genuinely bent test chain, silently breaking the
		# "can never break convergence" guarantee this whole design exists
		# for). Blending the DIRECTION instead (a fractional rotor rotation
		# of unit vectors, then re-scaled by the EXACT h derived above)
		# stays exactly on the circle at every intermediate weight.
		var orig_perp: Vector4 = points[i] - a_point - axis_i * a
		var orig_dir: Vector4 = _safe_normalized(orig_perp, flip_dir)

		var weight: float = clampf(twist_bend_base_weight * pow(twist_bend_decay, i - 1), 0.0, 1.0)
		var new_dir: Vector4 = flip_dir
		# Same "already exactly there" guard _snap_joint_toward already
		# uses before building a rotor - vector_product(dir, dir) is a
		# degenerate (pure-scalar) bivector the engine's own Rotor4D can't
		# normalize (confirmed directly: "invalid split square magnitude"
		# engine error), not just a wasted no-op call.
		if weight < 1.0 - DEGENERATE_LENGTH_EPSILON and orig_dir.dot(flip_dir) < 1.0 - SNAP_ANGLE_EPSILON:
			var rotor: Rotor4D = _rotor_from_to(orig_dir, flip_dir)
			new_dir = rotor.slerp_fraction(weight).rotate_vector(orig_dir) if rotor != null else orig_dir

		points[i] = a_point + axis_i * a + new_dir * h


func _safe_normalized(v: Vector4, fallback: Vector4) -> Vector4:
	return v.normalized() if v.length() > DEGENERATE_LENGTH_EPSILON else fallback


## Position-based projection, applied INSIDE every forward/backward pass
## (and once more to the final applied direction) - not a post-hoc angle
## clamp applied only after the whole position solve already finished.
## That distinction is the entire point: the earlier (CCD-era) hinge
## attempt applied its clamp AFTER computing each joint's raw desired
## direction but BEFORE the REST of that same sweep had any chance to
## react to the clamped result, which - confirmed via a brute-force search
## over the entire allowed angle space - left CCD permanently stuck at a
## fixed, wrong residual once a joint saturated its limit: relaxing the
## limit further just produced a new, still-wrong stuck point, ruling out
## "the limit itself is too tight" as the explanation. Projecting the
## constraint directly into each pass's OWN direction computation instead
## means every subsequent point in the SAME pass is computed from the
## already-constrained position, not the raw unconstrained one - the
## solve's own forward/backward iteration naturally reconciles the
## constraint with reachability every single pass, the same way it already
## reconciles segment lengths, rather than fighting a clamp bolted on
## afterward.
##
## Two real bugs, both confirmed via a standalone numeric reproduction
## independent of the whole gait rig, were found and fixed here:
##
## 1. clampf() on a CIRCULAR angle. atan2 returns a value that WRAPS
## (+-180 degrees are the same direction), but clampf treats its input as
## a plain, non-wrapping number line - a raw_dir pointing nearly straight
## UP (angle near +-180 degrees, which legitimately happens mid-solve
## whenever the chain has swung past straight-down toward the far side)
## used to get clamped to whichever configured limit is numerically
## closest to +-180 on that line, which - since every placeholder range
## here sits within +-90 degrees of straight down - is ALWAYS the
## limit that points MORE downward, never the one that's actually the
## shortest real-world turn away. That silently pushed the tip further
## past the target instead of folding it back, and did so at a genuine,
## stable fixed point (confirmed: 9 additional iterations changed
## nothing), not a transient - matching the ~2.5-unit ground-overshoot
## measured on the real leg rig. Fixed by finding the closest limit via
## the actual shortest SIGNED arc (wrapf), not raw numeric distance.
##
## 2. Discarding an in-range direction's exact value. The previous version
## always rebuilt raw_dir from scratch as e_down*cos(angle)+e_fwd*sin(angle)
## - even when raw_dir was already legal, this silently zeroed out
## whatever component raw_dir had OUTSIDE the {e_down, e_fwd} plane (e.g.
## true 4D motion toward a w-offset target), since the rebuilt vector only
## ever spans that one 2D plane. Fixed by returning raw_dir completely
## unchanged whenever it's already within range, and by preserving its
## real out-of-plane component (scaled down to keep the whole result a
## unit vector) even in the case that DOES need clamping.
func _apply_hinge_constraint(i: int, raw_dir: Vector4) -> Vector4:
	if i >= joint_hinge_min_deg.size() or i >= joint_hinge_max_deg.size():
		return raw_dir
	var e_down := Vector4(0, -1, 0, 0)
	var e_fwd: Vector4 = _hinge_forward()
	var a: float = raw_dir.dot(e_down)
	var b: float = raw_dir.dot(e_fwd)
	if sqrt(a * a + b * b) < DEGENERATE_LENGTH_EPSILON:
		return raw_dir # Perpendicular to the hinge plane entirely - no well-defined angle to clamp.
	var angle: float = atan2(b, a)
	var min_rad: float = deg_to_rad(joint_hinge_min_deg[i])
	var max_rad: float = deg_to_rad(joint_hinge_max_deg[i])
	if angle >= min_rad and angle <= max_rad:
		return raw_dir
	var clamped_angle: float = min_rad if absf(wrapf(angle - min_rad, -PI, PI)) < absf(wrapf(angle - max_rad, -PI, PI)) else max_rad
	var out_of_plane: Vector4 = raw_dir - e_down * a - e_fwd * b
	var in_plane_scale: float = sqrt(maxf(0.0, 1.0 - out_of_plane.length_squared()))
	var new_in_plane: Vector4 = (e_down * cos(clamped_angle) + e_fwd * sin(clamped_angle)) * in_plane_scale
	return (new_in_plane + out_of_plane).normalized()


## The horizontal (no-w) hinge-plane forward direction - see
## forward_direction_provider's own comment for why this is re-read fresh
## every call (a live travel direction) rather than a one-time fixed axis.
func _hinge_forward() -> Vector4:
	var raw_forward: Vector4 = (
		_forward_direction_provider.get_travel_direction()
		if _forward_direction_provider != null
		else global_basis * root_forward_local
	)
	var horizontal := Vector4(raw_forward.x, 0.0, raw_forward.z, 0.0)
	return horizontal.normalized() if horizontal.length() > DEGENERATE_LENGTH_EPSILON else Vector4(1, 0, 0, 0)


func _snap_joint_toward(i: int, desired_dir: Vector4) -> void:
	var current_dir: Vector4 = joints[i].global_basis.y
	if current_dir.dot(desired_dir) >= 1.0 - SNAP_ANGLE_EPSILON:
		return
	var rotor: Rotor4D = _rotor_from_to(current_dir, desired_dir)
	if rotor != null:
		joints[i].global_basis = rotor.rotate_basis(joints[i].global_basis)


## The tip of the last segment - not itself a joint, so it has no node of its
## own to read a position from; derived fresh from the last joint's current
## position/orientation/length every time it's needed.
func _end_effector_position() -> Vector4:
	var last_joint: Node4D = joints[joints.size() - 1]
	var last_length: float = link_lengths[link_lengths.size() - 1]
	return last_joint.global_position + last_joint.global_basis.y * last_length


## Builds a Rotor4D that takes `from_dir` exactly to `to_dir` (shortest path).
## Same bisector construction as w_targeting.gd's own _rotor_from_to - see
## that file for the full derivation (vector_product(a, b) alone
## double-rotates by the angle between a and b, per its own doc comment) -
## confirmed correct, including for near-180-degree and exactly-180-degree
## from/to pairs, via a standalone Rotor4D probe
## (_verify_rotor4d_antipodal_probe_runner.gd), independent of this whole
## chain's own gait-cycle behavior.
##
## The antipodal case (from_dir == -to_dir, bisector undefined) does NOT
## return null here, unlike w_targeting.gd's own version - a null return
## there just means "try again next frame" (whichever caller reads it
## KEEPS calling with slightly different vectors), which never resolves if
## from_dir and to_dir land EXACTLY opposite and nothing else perturbs
## them - confirmed to happen for real, at spawn (every joint starts at
## the scene-authored default orientation, world up; a chain reaching
## straight down is exactly antipodal to that). A 180-degree rotation is
## still well-defined here (just not unique - any perpendicular axis
## works), so pick one: vector_product(a, b) alone (without the bisector's
## angle-halving) performs a rotation of DOUBLE the angle between a and b
## (see this function's own header) - at exactly 90 degrees apart, that's
## exactly the 180 degrees needed.
func _rotor_from_to(from_dir: Vector4, to_dir: Vector4) -> Rotor4D:
	var bisector: Vector4 = from_dir + to_dir
	if bisector.length() < 0.0001:
		var arbitrary_axis := Vector4(1, 0, 0, 0)
		if absf(from_dir.dot(arbitrary_axis)) > 0.9:
			arbitrary_axis = Vector4(0, 0, 1, 0)
		var perp: Vector4 = (arbitrary_axis - from_dir * from_dir.dot(arbitrary_axis)).normalized()
		return Rotor4D.vector_product(from_dir, perp).normalized()
	return Rotor4D.vector_product(from_dir, bisector.normalized()).normalized()
