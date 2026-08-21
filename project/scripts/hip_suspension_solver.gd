extends Node
## Hip suspension solver - inverts the historical "body height fixed, legs
## conform" assumption baked into limb_prototype_body.gd's
## _apply_creature_class() (a ONE-TIME constant computed at spawn) into the
## anatomically correct direction: body height/pitch/roll are derived
## every physics frame from where the currently-planted feet actually are.
## See PROCEDURAL_CREATURE_ANIMATION_SYSTEM.md section 4.2 for the full
## design rationale.
##
## Ordering: process_physics_priority = -2, BEFORE Body's own -1 and
## FootTarget's default 0 - this solver reads whatever locked_position/
## state each FootTarget left at the END of the PREVIOUS physics frame,
## before anything in the CURRENT frame has touched it. That's the entire
## "one-frame-delayed" mechanism the design doc calls for: no explicit
## buffering, just running first in the new tick. Reading THIS frame's
## fresh targets instead would be circular - body pose would depend on
## targets computed relative to the old pose, then the body moves,
## invalidating the very targets used to compute it.
##
## Pitch/roll implementation note: the design doc describes "average
## left/right anchor pairs for roll, front/back for pitch." Implemented
## here as two INDEPENDENT 1D least-squares regressions (target height vs
## local x for pitch, vs local z for roll) rather than a coupled 2D plane
## fit - for this project's own anchor layout (front/back varies x at a
## roughly fixed z per side, left/right varies z at a roughly fixed x per
## row), x and z are close to uncorrelated across a leg set, so the two
## give essentially the same answer as a joint fit, while sidestepping any
## 3x3-matrix-singularity handling entirely - a 2-leg diagonal-pair stance
## (e.g. mid-trot) would leave a joint plane fit under-determined; these
## two independent regressions degrade gracefully instead, each simply
## reporting "no slope info" via its own single-variable guard below.
##
## Per-leg reach fraction, not just ground height: the ORIGINAL formula
## used the SAME resting_extension_fraction constant for every leg, so on
## a flat platform with uniform legs every leg's own target_anchor_y came
## out identical - mathematically zero pitch/roll, confirmed directly
## (measured exactly 0.00 degrees through a live walk cycle) - not
## because the solver was broken, but because ground height was the only
## signal it had, and there was none to find. Completing the originally-
## specified mechanism: each leg's own CURRENT reach fraction (actual
## anchor-to-foot distance / max_reach) now feeds into its own
## target_anchor_y too, via reach_response_weight below - a leg sitting
## above the resting target (more extended than "comfortable," e.g. late
## in a long belt-driven stance) pulls its own local target height DOWN,
## and a fresh/under-extended leg pulls it UP. Lowering the target height
## above an overextended leg is the relief mechanism: less vertical drop
## to that same foot means less total reach required from it, mirroring
## how a real animal's posture eases off a leg nearing its limit rather
## than piling more onto it.
##
## Weighted by load_factor, not a hard PLANTED filter: the ORIGINAL
## regression included every PLANTED leg at equal (1.0) weight and
## excluded LIFTING/SWINGING legs entirely - a leg's influence on body
## pose SNAPPED from "full vote" to "no vote" the instant the gate fired,
## and the newly-landed leg SNAPPED from no vote to a full one. Real
## quadrupeds transfer weight between legs continuously, not on/off -
## each leg is now included EVERY frame, weighted by its own
## limb_prototype_foot_target.gd's own load_factor (0 while genuinely
## airborne, ramping smoothly up after touchdown and back down in
## anticipation of its own next liftoff - see that field's own comment).
## A leg about to lift sheds its influence WHILE the next leg is still
## settling into its own, so the handoff overlaps instead of snapping -
## this is what actually changes visually (see this project's own
## MOTION_LAB_LEAN_INVESTIGATION.md for why the earlier hard-filter
## version couldn't do this even with reach_response_weight already on).

@export var body_path: NodePath
@export var leg_foot_target_paths: Array[NodePath] = []
## The old static baseline (limb_prototype_body.gd's own
## standing_utilization_ratio, ~0.5333) left FABRIK with too much slack -
## confirmed directly via an A/B screenshot on the same creature/pose: at
## 0.5333 the legs fold into a sharp, tight zigzag (lots of unused reach
## for the unconstrained solve to fold into); at 0.8 they read as a
## genuinely straighter, more natural stance. 0.8 still leaves real slack
## for gait (lift_height/stride swing) well below the reach-release
## backstop's own 0.97 threshold.
##
## Restored to 0.8 here after an unrelated A/B test (hopper's own
## reach-release overfiring investigation) had temporarily walked this
## CLASS DEFAULT back down to 0.5333 and it was never restored - caught
## by noticing this solver's own printed resting_extension_fraction
## didn't match the 0.8 every caller (limb_prototype_body.gd's steed/
## giraffe classes, motion_lab_creature.gd's own seed height) actually
## intends. hopper gets 0.5333 via its own explicit per-class override in
## limb_prototype_body.gd, unaffected by this default either way.
@export var resting_extension_fraction: float = 0.8
## Damped response time constant - a literal instant snap every frame
## would read as jittery, not "suspension." Same eased-approach shape
## already used for turning in limb_prototype_body.gd.
@export var suspension_time_constant_sec: float = 0.2
## How strongly a leg's OWN reach deficit (actual_reach_fraction -
## resting_extension_fraction) shifts its own local target height - see
## this file's own header for the relief-direction rationale.
##
## Defaults to 0.0 (off, exactly the old ground-height-only behavior) -
## this script is SHARED with the gallery's real-wandering steed/hopper/
## giraffe (via creature_template.tscn), and confirmed directly this is
## NOT safe to default on there: their reach dynamics come from actual
## anchor translation during wander (which can swing much harder than
## the motion lab's tethered, belt-driven case, and interacts with the
## body's own turning) - measured max tilt of 28-64 degrees with this at
## 0.4 for steed/hopper/giraffe, an obvious instability, not a subtle
## overcorrection. motion_lab_creature.gd sets this explicitly to 0.4 on
## its own HipSuspensionSolver instance after building it, where it WAS
## confirmed safe (max ~2.3 degrees over a 15s walk cycle, see
## _verify_hip_suspension_reach_response_runner.gd) - every other
## existing caller keeps today's exact, already-verified behavior
## unchanged.
@export var reach_response_weight: float = 0.0

const DEGENERATE_VARIANCE_EPSILON := 0.0001
const SNAP_ANGLE_EPSILON := 0.0000001

@onready var body: Node4D = get_node(body_path)
@onready var _foot_targets: Array[Node] = _resolve_foot_targets()


func _ready() -> void:
	process_physics_priority = -2


func _resolve_foot_targets() -> Array[Node]:
	var result: Array[Node] = []
	for p in leg_foot_target_paths:
		result.append(get_node(p))
	return result


func _physics_process(delta: float) -> void:
	var xs: Array[float] = []
	var zs: Array[float] = []
	var ys: Array[float] = []
	var weights: Array[float] = []
	# Baseline-normalized copy of ys, used ONLY for the pitch/roll slope
	# regressions below, never for the height/base average - see this
	# array's own comment at the point it's built for why.
	var normalized_ys: Array[float] = []

	for foot_target in _foot_targets:
		var weight: float = foot_target.load_factor
		if weight <= 0.0:
			continue # Genuinely airborne right now - zero influence either way, skip the (still well-defined but meaningless) math below.
		var anchor: Node4D = foot_target.anchor
		# actual_reach_fraction uses GLOBAL positions (a real 3D distance,
		# not the local x/z used below for the regression's independent
		# variable) - the same anchor-to-foot reach every reach_release_
		# fraction/reach_override_count check elsewhere in this project
		# already uses.
		var actual_reach: float = (anchor.global_position - foot_target.global_position).length()
		var actual_reach_fraction: float = actual_reach / foot_target.max_reach
		var reach_deficit: float = actual_reach_fraction - resting_extension_fraction
		var effective_fraction: float = resting_extension_fraction - reach_response_weight * reach_deficit
		var target_anchor_y: float = foot_target.locked_position.y + effective_fraction * foot_target.max_reach
		var y_value: float = target_anchor_y - anchor.position.y
		xs.append(anchor.position.x)
		zs.append(anchor.position.z)
		ys.append(y_value)
		weights.append(weight)
		# Subtracting resting_extension_fraction*max_reach removes THIS
		# leg's own structural "natural resting height" contribution
		# before it ever reaches the slope regression - confirmed
		# directly (_verify_hopper_tilt_diagnosis_runner.gd) that without
		# this, a creature class with genuinely different front/back leg
		# lengths (hopper: max_reach 4.5 front vs 7.2 back) produces a
		# large y_value spread (1.44 units on FLAT ground, standing still,
		# with reach_response_weight at 0.0) purely from comparing raw
		# target heights across legs with different natural lengths -
		# read by the regression as "the ground must be sloped," inflating
		# the pitch slope to ~34 degrees with nothing actually uneven.
		# base/body-height below intentionally still uses the RAW ys - the
		# overall standing height legitimately IS a blend of each leg's
		# own natural resting contribution; only the TILT should be blind
		# to structural leg-length differences, not the height.
		normalized_ys.append(y_value - resting_extension_fraction * foot_target.max_reach)

	var total_weight: float = 0.0
	for w in weights:
		total_weight += w
	if total_weight <= DEGENERATE_VARIANCE_EPSILON:
		return # Nobody has any real weight right now (e.g. mid-hop apex) - hold current pose rather than solving against no data.

	var base: float = _weighted_mean(ys, weights, total_weight)
	var normalized_base: float = _weighted_mean(normalized_ys, weights, total_weight)

	var pitch_slope: float = _regress_slope(xs, normalized_ys, normalized_base, weights, total_weight)
	var roll_slope: float = _regress_slope(zs, normalized_ys, normalized_base, weights, total_weight)

	var fraction: float = 1.0 - exp(-delta / suspension_time_constant_sec)
	body.position.y = lerp(body.position.y, base, fraction)

	var desired_up: Vector4 = Vector4(-pitch_slope, 1.0, -roll_slope, 0.0).normalized()
	var current_up: Vector4 = body.global_basis.y
	if current_up.dot(desired_up) < 1.0 - SNAP_ANGLE_EPSILON:
		var rotor: Rotor4D = _rotor_from_to(current_up, desired_up)
		if rotor != null:
			body.global_basis = rotor.slerp_fraction(fraction).rotate_basis(body.global_basis)


func _weighted_mean(values: Array[float], weights: Array[float], total_weight: float) -> float:
	var sum: float = 0.0
	for i in range(values.size()):
		sum += weights[i] * values[i]
	return sum / total_weight


## Weighted single-variable least-squares slope of ys against coords,
## already knowing the weighted intercept (y_mean) - the same
## sum(w*(x-xmean)(y-ymean))/sum(w*(x-xmean)^2) formula as an ordinary
## least-squares slope, just with every term carrying its own leg's
## load_factor weight (see this file's own header for why: a leg mid-
## handoff contributes PARTIALLY, not as a full vote or none at all).
## x_mean here is ALSO weighted, for the same reason - an unweighted mean
## would let an airborne-adjacent, low-weight leg's raw coordinate skew
## where "center" is even though it barely counts. Returns 0.0 (no tilt)
## if every leg's own coordinate along this axis is identical (or every
## weight has degenerated to ~0, though the caller already guards that
## case for total_weight as a whole) - there's no slope information to
## extract, not a division-by-zero to paper over.
func _regress_slope(coords: Array[float], ys: Array[float], y_mean: float, weights: Array[float], total_weight: float) -> float:
	var x_mean: float = _weighted_mean(coords, weights, total_weight)

	var numerator: float = 0.0
	var denominator: float = 0.0
	for i in range(coords.size()):
		var dx: float = coords[i] - x_mean
		numerator += weights[i] * dx * (ys[i] - y_mean)
		denominator += weights[i] * dx * dx

	return numerator / denominator if denominator > DEGENERATE_VARIANCE_EPSILON else 0.0


## Same bisector construction duplicated in ik_chain_controller.gd,
## limb_prototype_body.gd, w_targeting.gd, and limb_prototype_foot_segment.gd.
func _rotor_from_to(from_dir: Vector4, to_dir: Vector4) -> Rotor4D:
	var bisector: Vector4 = from_dir + to_dir
	if bisector.length() < 0.0001:
		return null
	return Rotor4D.vector_product(from_dir, bisector.normalized()).normalized()
