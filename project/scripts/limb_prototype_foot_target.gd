extends Node4D
## Step 3 of the limb prototype: Planted/Lifting/Swinging foot-placement FSM
## on top of step 2's raycast ground-tracking, now with a REACH-based
## release trigger (see reach_release_fraction) instead of a fixed timer.
##
## Note on precedent: an earlier brief for this step called for "the
## hazard-creature base-state-plus-owning-node pattern already established
## in this project." A real search turned up no such thing - there is no
## hazard/creature FSM, no base State class, and no enter/exit-style state
## contract anywhere in this codebase (confirmed by grepping for "hazard",
## "class_name.*State", "enter_state"/"exit_state", etc. - all empty). The
## closest REAL, already-established pattern is the contest movement-
## archetype scripts (pop_hold_retract.gd, vertical_toss.gd,
## constant_velocity_crossing.gd): each `extends Node`, grabs its owner via
## get_parent() in _ready(), does its own per-frame work in _process(), and
## signals completion via its own `signal expired`. That fits a one-shot
## animation dispatched by an external orchestrator; a continuously-cycling
## 3-state gait with no external spawner is a poor fit for reproducing it
## verbatim, so this stays a single self-contained enum-driven match,
## keeping the same SPIRIT (each state's own simple per-frame logic) without
## inventing overhead this codebase doesn't otherwise use for this shape.
##
## History: this FSM's first release trigger was a fixed minimum dwell
## time (stance_duration_sec), sized from the measured 5-joint static-IK
## convergence time. Measured result over 30 real cycles: 0/30 reached the
## static-root 0.05 convergence bar (avg residual 0.658, max 1.355) -
## because that reference measured a STATIC root, and this limb's anchor
## keeps walking the entire time a foot is Planted, so the required reach
## keeps growing throughout the whole dwell regardless of how long it is -
## more dwell time doesn't help and can even hurt. Replaced with a
## reach-based trigger instead: release once the anchor has ACTUALLY walked
## far enough that the plant is nearing the chain's physical limit, which is
## the mechanism real gaits use and doesn't have that "waiting makes it
## worse" problem.
##
## Live raycast (see _compute_live_target, identical mechanism to step 2) is
## computed every frame regardless of state, but only DRIVES this node's
## position while PLANTED is deciding whether to leave - it's a decision
## input, not a continuous position feed, unlike step 2.

const GROUND_PROBE_HEIGHT := 20.0
const GROUND_MAX_RAY_DISTANCE := 40.0

enum FootState { PLANTED, LIFTING, SWINGING }

@export var body_path: NodePath
@export var anchor_path: NodePath
@export var ik_chain_path: NodePath
@export var forward_lead_distance: float = 1.5
@export var lift_duration_sec: float = 0.15 # Brief upward arc, not a slow raise.
@export var swing_duration_sec: float = 0.35 # Same order of magnitude as the IK's own slew_time_constant_sec.
@export var lift_height: float = 0.6

## REACH-based release. History: for a standalone limb with no gait
## controller (no clock, no phase gate at all), this is the ONLY release
## mechanism - release once the anchor has walked far enough from
## locked_position that the plant is approaching the chain's own physical
## limit, a fraction of max_reach, not a timer.
##
## With a gait_controller assigned, this is now an EARLY-RELEASE SAFETY
## OVERRIDE ONLY, not a race against the phase gate - see _physics_process's
## PLANTED branch and gait_controller_path's own comment below for why: an
## in-between design (reach-based trigger simply GATED by phase eligibility,
## tried first) measured a real, reproducible, worsening-with-speed
## co-occurrence breakdown even at reference speed, because a wide-enough
## eligibility window stops being the actual binding constraint and the
## reach condition (correlated across all 4 legs, since they share one
## rigid body's velocity) dominates instead, resynchronizing legs regardless
## of their assigned phase offsets. Restructured so the phase gate is
## authoritative (fires exactly when local_phase crosses duty_factor,
## unconditionally) and reach can ONLY act as a backstop BEFORE that crossing
## - once the gate has opened, reach is never consulted again for this
## plant. reach_override_count (below) tracks how often the backstop
## actually fires, for verification - it should be rare/zero in ordinary
## operation now that the gate decides.
##
## Default recomputed, not left at the old value: with this scene's anchor
## height (4.5 above ground) and forward_lead_distance (1.5), the anchor-to
## -foot distance right after ANY fresh landing is already 4.5-4.74 (a
## geometric floor from the fixed vertical drop alone, independent of how
## far the body has actually walked) - 60-63% of max_reach (7.5). The old
## default (0.5, threshold 3.75) sat BELOW that floor, so the override was
## satisfied on essentially every landing, not the rare backstop it was
## meant to be (confirmed directly: it fired on ~29/38 releases in one
## run - not "rare").
##
## 0.8 (threshold 6.0) sat above the geometric floor but re-verifying after
## the hard-gate restructure still measured 33-38% override rates at tested
## speeds (2.0/2.6/3.4). Root cause, confirmed empirically (see
## _verify_limb_prototype_reach_tuning_runner.gd), not just derived: the
## body's wander target changes direction periodically, so the anchor
## doesn't always drift steadily away from a planted foot - but when a
## given stance phase DOES happen to line up with a fairly straight
## stretch of wander, the geometric drift budget at 0.8 is exhausted well
## before the phase gate's own natural opening (time from landing to next
## gate-open is period_sec minus the fixed 0.5s swing, independent of
## duty_factor - confirmed by testing duty_factor=0.75, which changed
## nothing reliably: 13.6/29.7/24.4% vs 0.6's 25.9/25.7/24.4%, noise, not
## improvement, exactly as that formula predicts).
##
## reach_release_fraction is the lever that actually measured a real,
## repeatable effect: 0.8->33-38%, 0.9->~25%, 0.97->9-17% across the same
## three speeds. Landed on 0.97 (threshold 7.275, ~1.7 units more drift
## budget than 0.9) - not 0.99, which nudged some speeds better and others
## worse (this project's RNG is deterministic - see _verify script's own
## comment - so that's a real reproducible artifact of the specific wander
## path, not noise) while sitting uncomfortably close to max_reach itself.
## This is NOT single-digit at every tested speed (2.6 still ran ~13%) -
## the residual rate appears structurally tied to how often the deterministic
## wander happens to hold a consistent direction for a whole stance phase,
## which fraction tuning alone reduces but can't eliminate without changing
## gait cadence (reference_period_sec) or wander behavior - out of scope
## here. Reported as a real, substantial improvement (33-38% -> 8-17%), not
## a full elimination.
@export var reach_release_fraction: float = 0.97

## Vertical offset from the true ground-contact point to the target this
## chain's own FABRIK solve actually aims for (see ik_chain_path's own
## `target_path`). The gap between the two is bridged by a separate, non-
## FABRIK "foot" segment (limb_prototype_foot_segment.gd) parented to the
## chain's last joint - its OWN orientation, not this node's position,
## is what visually absorbs ground slope. Set per-class from
## limb_prototype_body.gd's own BASE_FOOT_HEIGHT.
@export var foot_height: float = 0.5

## Optional multi-limb gait hook (no-op for a standalone limb: gait_controller
## stays null, and release is reach-only, unchanged from before). With one
## assigned, local_phase = fmod(gait_controller.phase_progress +
## phase_offsets[leg_index], 1.0) is the PRIMARY, hard release trigger -
## Planted->Lifting fires exactly when local_phase crosses duty_factor,
## regardless of reach. duty_factor/phase_offsets are the gait PRESET's
## declared data (which leg is due to swing when), not a per-frame
## computation of anything else.
@export var gait_controller_path: NodePath
@export var leg_index: int = 0

## Treadmill belt speed - 0.0 (off) by default so every existing scene
## (the gallery's real-wandering creatures) keeps its exact current,
## already-verified behavior: locked_position stays perfectly fixed while
## PLANTED, and reach grows only because the ANCHOR walks away from it.
## When nonzero (only motion_lab_creature.gd's own treadmill sets this),
## THIS field - deliberately NOT body.speed - is spent sliding the
## PLANTED foot's own locked_position backward every frame, producing the
## exact same growing-reach/release timing as real anchor motion would
## (this system only ever cared about the ANCHOR-TO-LOCKED-POSITION
## distance, never which side of that pair was the one actually moving).
##
## Kept independent of body.speed on purpose - an earlier version reused
## body.speed for both this AND gait_controller.gd's own cadence-scaling
## (period_sec = reference_period_sec*reference_speed/body.speed), and
## measured directly (a real 15s walk trace) that doing so is actively
## counterproductive: total reach consumed per stance is APPROXIMATELY
## reference_period_sec*reference_speed - fixed_step_duration*body.speed,
## which is DOMINATED by the (speed-independent) first term - meaning
## walk's own stance was consuming ~90%+ of max_reach regardless of which
## body.speed value got picked, because slowing body.speed down to make
## the belt gentler just proportionally LENGTHENS the stance window via
## that same formula, canceling the intended effect. Separating the two
## fields lets gait_controller.gd's cadence stay at each preset's own
## already-tuned reference (motion_lab_creature.gd now leaves body.speed
## fixed at 2.0, matching every FOUR_LEG_GAITS preset's own
## reference_speed) while this field is tuned purely for a comfortable,
## well-under-reach_release_fraction stride length.
@export var belt_speed: float = 0.0

## How long, in real seconds, this leg takes to ease INTO full weight-
## bearing right after touchdown, and to ease OUT of it in anticipation
## of its own next scheduled liftoff (see load_factor's own comment) -
## a continuous, overlapping alternative to the hard PLANTED/not-PLANTED
## split hip_suspension_solver.gd used to filter on. Same order of
## magnitude as lift_duration_sec - a settle/shed that takes noticeably
## longer than the lift arc itself would read as sluggish, not weight
## transfer.
@export var load_transition_duration_sec: float = 0.2

## Continuous 0..1 weight-bearing estimate for this leg - 0 while
## LIFTING/SWINGING (genuinely airborne, contributes nothing), ramping
## smoothly up to 1 over load_transition_duration_sec right after
## touchdown, and back down to 0 over the same duration in ANTICIPATION
## of this leg's own next scheduled liftoff (predicted from local_phase/
## duty_factor/period_sec, when a gait_controller is assigned - legs
## without one only get the post-touchdown ease-in, no anticipatory
## shed, since there's no phase clock to predict a liftoff time from).
## Read by hip_suspension_solver.gd as a per-leg REGRESSION WEIGHT
## instead of the old hard PLANTED-or-excluded filter - see that file's
## own comment for why this is what makes weight transfer between legs
## overlap smoothly (a leg about to lift sheds weight WHILE the next leg
## is still settling in) rather than snapping instantly from one
## exclusive weight-bearing leg to the next. Public so it can be read
## externally without every consumer needing to duplicate this math.
var load_factor: float = 1.0

@onready var body: Node4D = get_node(body_path)
@onready var anchor: Node4D = get_node(anchor_path)
@onready var ik_chain: Node = get_node(ik_chain_path)
@onready var gait_controller: Node = get_node(gait_controller_path) if not gait_controller_path.is_empty() else null

var state: FootState = FootState.PLANTED
var locked_position: Vector4 = Vector4.ZERO
var swing_start_position: Vector4 = Vector4.ZERO
var swing_target_position: Vector4 = Vector4.ZERO
var state_elapsed_sec: float = 0.0
var last_hit: bool = false
var max_reach: float = 0.0
var reach_override_count: int = 0 # How many times the reach backstop actually fired (gait_controller present, gate still closed) - exposed for verification.

## Raw ground-contact facts (NOT offset by foot_height, unlike
## locked_position/swing_target_position above) - what limb_prototype_
## foot_segment.gd actually reads to orient the separate foot segment
## against real ground slope, and to reach toward the known landing spot
## during late swing ("ground prediction"). locked_* is captured whenever a
## plant lands (both the initial _ready() plant and the SWINGING->PLANTED
## transition); swing_target_* is captured in _start_swing, from the exact
## same raycast that produced this swing's own target.
var locked_ground_point: Vector4 = Vector4.ZERO
var locked_ground_normal: Vector4 = Vector4(0, 1, 0, 0)
var swing_target_ground_point: Vector4 = Vector4.ZERO
var swing_target_ground_normal: Vector4 = Vector4(0, 1, 0, 0)

## Scratch fields, refreshed every _compute_live_target() call - copied into
## the locked_*/swing_target_* fields above by whichever caller decides to
## actually USE that frame's computed target, so the raw ground facts stay
## in sync with whichever ankle-height target they informed.
var _last_ground_point: Vector4 = Vector4.ZERO
var _last_ground_normal: Vector4 = Vector4(0, 1, 0, 0)

## Arm/consume latch for the hard gate trigger. Needed because the gate
## stays OPEN for a whole span of local_phase (1 - duty_factor of the
## period), not a single instant - a completed swing (lift+swing, ~0.5s)
## can land back in PLANTED while local_phase is STILL inside that same
## open span (confirmed directly: without this latch, a leg would
## immediately re-fire on landing since "local_phase >= duty_factor" was
## still true, causing rapid repeated swinging - and worse, since the
## open span (0.8s at reference) is wider than the stagger spacing between
## legs (0.5s), multiple legs would be doing this simultaneously, producing
## near-100% co-occurrence and a cycle-count blowup, confirmed in an actual
## run before this fix). Re-armed only once local_phase drops back BELOW
## duty_factor (the next cycle's closed/stance portion), so the gate fires
## exactly once per crossing, not once per frame it happens to read open.
var _gate_armed: bool = true


func _ready() -> void:
	for length in ik_chain.link_lengths:
		max_reach += length

	# Establish an initial planted position from the very first raycast, so
	# the foot doesn't start out at the world origin waiting for a release
	# event that may never trip if the first live target is already close.
	var initial_target: Variant = _compute_live_target()
	if initial_target != null:
		locked_position = initial_target
		global_position = locked_position
		locked_ground_point = _last_ground_point
		locked_ground_normal = _last_ground_normal

	# Seed the chain's joint rotations toward this resting position
	# immediately, instead of leaving them at their scene-authored identity
	# basis (visually: every segment pointing straight up) for the first
	# slew_time_constant_sec or so while ik_chain's own per-frame partial
	# CCD sweep gradually catches up. Deferred so it runs after every node's
	# _ready() - including ik_chain's own @onready joints/target - has
	# definitely run, regardless of which subtree happens to ready first.
	call_deferred("_seed_spawn_pose")


## Runs one FABRIK solve at spawn only, purely so the chain doesn't render
## one frame of its raw scene-authored default pose (every joint pointing
## straight up) before its own first _physics_process tick - see _ready()'s
## own comment for why this needs to be deferred. ik_chain_controller.gd's
## solve_fabrik() always fully converges every frame now (no per-frame
## easing left to warm up), so this is otherwise no different from an
## ordinary frame's own solve.
func _seed_spawn_pose() -> void:
	ik_chain.solve_fabrik()


func _physics_process(delta: float) -> void:
	var live_target: Variant = _compute_live_target()

	match state:
		FootState.PLANTED:
			# Time since THIS plant's own touchdown - state_elapsed_sec is
			# already reset to 0.0 exactly on landing (see the SWINGING
			# branch's own transition below, and _ready()'s initial plant),
			# so accumulating it here for the first time gives load_factor's
			# post-touchdown ease-in a real elapsed-time source without
			# needing a second field.
			state_elapsed_sec += delta

			if belt_speed > 0.0:
				# The belt scrolling backward under a roughly-stationary
				# body - see belt_speed's own comment. Ground-fact fields
				# (locked_ground_point/normal) deliberately NOT shifted
				# here: they're only ever read by limb_prototype_foot_
				# segment.gd for slope/ground-prediction visuals, and
				# staying anchored to the real raycast hit avoids slowly
				# drifting them away from the actual mesh they described.
				locked_position -= body.get_travel_direction() * belt_speed * delta
			global_position = locked_position # Exactly fixed (belt_speed 0) - the live raycast is consulted, never applied, while planted.

			if gait_controller != null:
				var offset: float = gait_controller.phase_offsets[leg_index]
				var local_phase: float = fmod(gait_controller.phase_progress + offset, 1.0)
				if local_phase < gait_controller.duty_factor:
					_gate_armed = true # Closed portion - prime for the next opening.
				elif _gate_armed:
					# PRIMARY, hard trigger - release exactly on the gate
					# crossing (once per crossing, see _gate_armed's own
					# comment), unconditionally. Reach is NOT checked here:
					# once the gate is open, it never matters again for this
					# plant.
					_gate_armed = false
					if live_target != null:
						_start_swing(live_target)

			if state == FootState.PLANTED:
				# Still planted: either no gait_controller at all (reach is
				# the only mechanism there, unchanged from before), or a
				# gait_controller exists but its gate hasn't opened yet -
				# reach is purely an EARLY-RELEASE SAFETY OVERRIDE here, never
				# reached once the gate above has already fired this frame.
				var reach: float = (anchor.global_position - locked_position).length()
				if reach > reach_release_fraction * max_reach and live_target != null:
					if gait_controller != null:
						reach_override_count += 1
					_start_swing(live_target)

			if state == FootState.PLANTED:
				# Only reached if this leg DIDN'T just fire this same frame
				# (_start_swing, called from either check above, already set
				# load_factor to 0.0 and changed state away from PLANTED) -
				# so this always reflects a leg genuinely still grounded.
				load_factor = _compute_planted_load_factor()

		FootState.LIFTING:
			state_elapsed_sec += delta
			var t: float = clampf(state_elapsed_sec / lift_duration_sec, 0.0, 1.0)
			global_position = swing_start_position + Vector4(0.0, lift_height * sin(t * PI * 0.5), 0.0, 0.0)
			if state_elapsed_sec >= lift_duration_sec:
				state = FootState.SWINGING
				state_elapsed_sec = 0.0

		FootState.SWINGING:
			state_elapsed_sec += delta
			var t: float = clampf(state_elapsed_sec / swing_duration_sec, 0.0, 1.0)
			var horizontal: Vector4 = swing_start_position.lerp(swing_target_position, t)
			var lift_y: float = lift_height * sin((1.0 - t) * PI * 0.5) # Peaks at swing start, eases to 0 by arrival - the second half of the step arc.
			global_position = Vector4(horizontal.x, swing_target_position.y + lift_y, horizontal.z, horizontal.w)
			if state_elapsed_sec >= swing_duration_sec:
				locked_position = swing_target_position
				locked_ground_point = swing_target_ground_point
				locked_ground_normal = swing_target_ground_normal
				global_position = locked_position
				state = FootState.PLANTED
				state_elapsed_sec = 0.0


func _start_swing(target: Vector4) -> void:
	swing_start_position = locked_position
	swing_target_position = target
	swing_target_ground_point = _last_ground_point
	swing_target_ground_normal = _last_ground_normal
	state = FootState.LIFTING
	state_elapsed_sec = 0.0
	load_factor = 0.0 # Genuinely airborne the instant it leaves PLANTED - stays 0.0 through both LIFTING and SWINGING.


## Continuous weight-bearing ramp while PLANTED - see load_factor's own
## comment for the overlap-with-neighboring-legs rationale. Two
## independent ramps, combined via min() (whichever is more restrictive
## wins, so a short stance relative to load_transition_duration_sec
## can't have both ramps "agree" to exceed what either alone allows):
## settle (time since THIS touchdown, via state_elapsed_sec) and shed
## (time remaining until this leg's own NEXT predicted liftoff, only
## computable with a gait_controller assigned - legs without one get
## settle only, no anticipatory shed, since there's no phase clock to
## predict a liftoff time from). sin(t*PI*0.5) matches this file's own
## existing lift/swing easing convention rather than a linear ramp.
func _compute_planted_load_factor() -> float:
	var settle_fraction: float = clampf(state_elapsed_sec / load_transition_duration_sec, 0.0, 1.0)
	if gait_controller == null:
		return sin(settle_fraction * PI * 0.5)

	var offset: float = gait_controller.phase_offsets[leg_index]
	var local_phase: float = fmod(gait_controller.phase_progress + offset, 1.0)
	var phase_until_liftoff: float
	if local_phase < gait_controller.duty_factor:
		phase_until_liftoff = gait_controller.duty_factor - local_phase
	else:
		# Already fired and consumed this cycle's own opening (see
		# _gate_armed's own comment) - the next real liftoff is a full
		# cycle's worth of closed-portion away, not this cycle's stale
		# crossing point.
		phase_until_liftoff = 1.0 - local_phase + gait_controller.duty_factor
	var time_until_liftoff: float = phase_until_liftoff * gait_controller.period_sec
	var shed_fraction: float = clampf(time_until_liftoff / load_transition_duration_sec, 0.0, 1.0)

	return sin(minf(settle_fraction, shed_fraction) * PI * 0.5)


## Same raycast mechanism as step 2 (see that step's own header for the full
## derivation) - returns the world hit point, or null if the ray missed.
func _compute_live_target() -> Variant:
	var travel_dir: Vector4 = body.get_travel_direction()
	var anchor_pos: Vector4 = anchor.global_position
	var probe_xzw: Vector4 = anchor_pos + travel_dir * forward_lead_distance

	var ray_params := RaycastParameters4D.new()
	ray_params.global_ray_origin = Vector4(probe_xzw.x, GROUND_PROBE_HEIGHT, probe_xzw.z, probe_xzw.w)
	ray_params.global_ray_direction = Vector4(0.0, -1.0, 0.0, 0.0)
	ray_params.max_distance = GROUND_MAX_RAY_DISTANCE
	var result: Dictionary = PhysicsServer4D.raycast_physics_objects(ray_params)
	last_hit = result.get("hit", false)
	if not last_hit:
		return null
	_last_ground_point = ray_params.global_ray_origin + ray_params.global_ray_direction * float(result.global_distance)
	_last_ground_normal = result.get("global_normal", Vector4(0, 1, 0, 0))
	# The ankle-height target FABRIK actually solves against - offset along
	# world up (not the normal), so a sloped ground tilts the separate foot
	# segment below, not the whole leg's own reach target. See foot_height's
	# own comment.
	return _last_ground_point + Vector4(0.0, foot_height, 0.0, 0.0)
