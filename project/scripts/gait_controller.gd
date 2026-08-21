extends Node
## Shared per-creature gait clock. Period is LINKED to the body's actual
## movement speed rather than a fixed constant: a preset's duty_factor and
## phase_offsets stay fixed (they define the SHAPE of the gait), but its
## period_sec is only ever a REFERENCE value - the cadence a preset was
## tuned at a REFERENCE speed - matching how real quadruped gait-control
## literature treats duty factor/phase relationships as roughly
## speed-invariant while stride FREQUENCY scales with speed for a given
## gait. reference_speed is what limb_prototype_body.gd's own `speed` was
## when a preset's reference_period_sec was picked; ACTUAL period_sec scales
## inversely with the body's CURRENT speed relative to that reference,
## re-evaluated every frame (not a one-time snapshot), so a future
## speed-changing mechanic (sprint, etc.) would already be tracked.
##
## Phase is accumulated as dt/period_sec every frame (phase_progress), NOT
## re-derived as elapsed_time/period_sec from a separately-kept time counter
## - the latter would make phase jump discontinuously the instant
## period_sec changes.
##
## RELEASE MECHANISM (limb_prototype_foot_target.gd): the phase gate is now
## the PRIMARY, hard trigger - a leg releases exactly when its own
## local_phase crosses duty_factor, unconditionally. Reach is only an
## early-release safety backstop while the gate is still closed, and is
## never consulted once the gate has opened. This replaced an earlier
## design where reach-based release was simply GATED by phase eligibility
## (tried first) - that measured a real, reproducible, worsening-with-speed
## co-occurrence breakdown even at reference speed, because a wide-enough
## eligibility window let the reach condition (correlated across all 4 legs,
## since they share one rigid body's velocity) dominate and resynchronize
## legs regardless of phase. Making the gate authoritative removes that
## failure mode entirely.
##
## VALID SPEED RANGE, under the hard-gate mechanism: the constraint that
## actually matters for inter-leg overlap is NOT duty_factor (an earlier,
## incorrect model of this had it gating a race-eligibility window, and its
## own margin formula - confirmed by real re-testing, not assumed - failed
## to predict the actual measured breakdown point). Under a hard gate, what
## matters is the TIME GAP between two DIFFERENT legs' phase crossings:
## min_phase_spacing (the smallest nonzero gap between distinct phase_offset
## values, ignoring legs that share a phase on purpose, e.g. trot's diagonal
## pairs) times period_sec. If that gap is shorter than the fixed physical
## step duration, a leg is still mid-swing when the next distinct leg's gate
## opens, and they overlap - confirmed directly: walk's original
## reference_period_sec (2.0) gave a gap of exactly 0.25*2.0=0.5s, equal to
## the 0.5s fixed step duration with zero margin, and speed=2.2 (shrinking
## the gap further) immediately showed 100% adjacent-leg overlap.
## reference_period_sec raised to 4.0 to give real margin: gap =
## 0.25*4.0=1.0s vs the required-with-margin 0.65s.
##
## Two presets:
## - WALK: four evenly-spaced phase offset VALUES (0, 0.25, 0.5, 0.75),
##   duty_factor 0.6 (comfortably above 0.5 - always at least one foot
##   down, no suspension phase), reference_period_sec 4.0 (see above for
##   why 2.0 didn't have real margin). WHICH leg gets which of those four
##   values matters too, separately from the values themselves - see
##   PRESETS["walk"]["phase_offsets"]'s own comment: the real
##   chronological firing order depends on both, and the "obvious"
##   ascending assignment (FL,FR,BL,BR = 0,0.25,0.5,0.75) produces a real
##   sequence that doesn't match any actual quadruped gait pattern.
## - TROT: diagonal pairs synchronized (FL+BR at phase 0, FR+BL at 0.5) -
##   min_phase_spacing is the gap BETWEEN the two pairs (0.5), not within a
##   pair (0, intentional - they're SUPPOSED to move together).
## Leg order (index 0-3) is FL, FR, BL, BR, matching
## limb_prototype_test.tscn's own leg node names.

## lift_duration_sec (0.15) + swing_duration_sec (0.35) from
## limb_prototype_foot_target.gd - see this file's own header for why this
## is a deliberate duplicate, not a shared reference.
const FIXED_STEP_DURATION_SEC := 0.5
## Requested "25-30%, not right at the boundary" - picked the top of that
## range for a bit more headroom given walk's original zero-margin failure.
const SAFETY_MARGIN_FRACTION := 0.30

const PRESETS := {
	"walk": {
		"reference_speed": 2.0,
		"reference_period_sec": 4.0,
		"duty_factor": 0.6,
		# [0.25, 0.75, 0.5, 0.0] for FL,FR,BL,BR - NOT the four values in
		# ascending order. Confirmed directly (_verify_walk_sequence_
		# before_runner.gd) that assigning them in the "obvious" ascending
		# order [0.0,0.25,0.5,0.75] to FL,FR,BL,BR satisfies "evenly
		# spaced" and "no bunching" but produces the WRONG real
		# chronological footfall order: because a leg's own gate fires at
		# phase_progress = duty_factor - offset (mod 1), ascending offsets
		# do NOT mean ascending fire order - the actual sequence that
		# assignment produced was BL->FR->FL->BR, not any real quadruped
		# gait pattern. This permutation (same four offset values, same
		# spacing/duty_factor/overlap-safety math - a pure relabeling of
		# which leg gets which value, not a new mechanism) reproduces the
		# real lateral-sequence walk footfall order (LH->LF->RH->RF, i.e.
		# BL->FL->BR->FR in this project's own FL/FR/BL/BR naming) -
		# confirmed via the same script, re-run after this change.
		"phase_offsets": [0.25, 0.75, 0.5, 0.0],
	},
	"trot": {
		"reference_speed": 2.0,
		"reference_period_sec": 1.2,
		"duty_factor": 0.5,
		"phase_offsets": [0.0, 0.5, 0.5, 0.0],
	},
	## Fully synchronized (all four phase offsets equal, so
	## compute_min_phase_spacing's own all-shared-phase fallback applies -
	## no spacing constraint, matching a real hop where every leg is
	## SUPPOSED to move together, not a timing conflict to guard against),
	## directly from the real robotics-reference duty_factor/offset pair
	## already found for this gait - no guessing needed, unlike canter
	## below.
	"hop": {
		"reference_speed": 2.0,
		"reference_period_sec": 1.0,
		"duty_factor": 0.5,
		"phase_offsets": [0.0, 0.0, 0.0, 0.0],
	},
	## APPROXIMATION, not derived from a robotics reference the way hop
	## was - flagged explicitly per the request that added this preset.
	## Shape: one solo limb (phase 0.0), one synchronized diagonal pair
	## (phase 0.35 each - a real canter's characteristic diagonal-pair
	## footfall, the same "two legs sharing one phase" convention already
	## established for trot), one solo limb (phase 0.65). "right" here
	## means the FR/BL diagonal leads; canter_left mirrors which side's
	## diagonal pair leads (FL/BR instead) - same shape, opposite lead,
	## both real canter variants a real quadruped can take. Needs empirical
	## tuning (duty_factor, the exact 0.35/0.65 split, reference_period_sec)
	## against actual running footage or a robotics reference, same as
	## hop had available and this didn't.
	##
	## reference_period_sec=1.0 was tried first (matching hop's own tempo)
	## and measured, via the same co-occurrence check used for every other
	## preset, to produce messy, near-total overlap between ALL legs, not
	## the intended solo/pair/solo separation - NOT because the phase
	## offsets are wrong, but because min_phase_spacing (0.3, the FR/BL
	## pair to either solo leg) times a 1.0s period gives only 0.3s of
	## real-time separation, less than the FIXED 0.5s lift+swing duration
	## itself (see FIXED_STEP_DURATION_SEC) - there is no period-independent
	## way to keep two legs' airborne WINDOWS from overlapping once their
	## phase gap converts to less real time than a single step physically
	## takes, no matter how the offsets are chosen. Raised to 2.2s using
	## this file's own compute_valid_speed_ceiling formula solved for the
	## minimum period that keeps reference_speed at or below the ceiling
	## (required_gap/min_phase_spacing = 0.65/0.3 ~= 2.17, rounded up) -
	## same reasoning walk's own reference_period_sec (2.0 -> 4.0) used
	## earlier in this file's history, just applied to a preset that never
	## had a working value in the first place rather than a regression.
	"canter_right": {
		"reference_speed": 2.0,
		"reference_period_sec": 2.2,
		"duty_factor": 0.4,
		"phase_offsets": [0.0, 0.35, 0.35, 0.65], # FL, FR, BL, BR - FR+BL diagonal pair leads.
	},
	"canter_left": {
		"reference_speed": 2.0,
		"reference_period_sec": 2.2,
		"duty_factor": 0.4,
		"phase_offsets": [0.35, 0.0, 0.65, 0.35], # FL, FR, BL, BR - FL+BR diagonal pair leads (mirror of canter_right).
	},
}

@export var preset: String = "walk"
@export var body_path: NodePath

## Optional - number-key preset switching (1=walk, 2=trot), same pattern as
## skew_polyhedron_44n.gd's _input/_set_n/label-update shape (that script's
## own KEY_1..KEY_9-to-integer mapping doesn't apply here since there are
## only 2 named presets, not a numeric range, but the guard-then-dispatch-
## then-update-label structure is copied directly). Left empty, this label
## is simply never touched - existing scenes with no gait HUD are
## unaffected.
@export var info_label_path: NodePath

@onready var body: Node4D = get_node(body_path)
@onready var info_label: Label = get_node(info_label_path) if not info_label_path.is_empty() else null

var reference_speed: float = 2.0
var reference_period_sec: float = 4.0
var duty_factor: float = 0.6
var phase_offsets: Array = [0.0, 0.25, 0.5, 0.75]

var period_sec: float = 4.0 # Current, speed-scaled period - recomputed every frame; read-only from outside.
var phase_progress: float = 0.0
var valid_speed_ceiling: float = 0.0 # Documented property of the active preset - see compute_valid_speed_ceiling().

## Captured once at _ready(), before any gait suffix is appended - lets
## _update_label() re-append a fresh suffix on every preset switch without
## the label's own original description (camera/wander behavior, unrelated
## to gait) getting eaten or duplicated.
var _base_label_text: String = ""


func _ready() -> void:
	# Explicitly runs BEFORE limb_prototype_foot_target.gd's own default
	# (0) priority, same reasoning as ik_chain_controller.gd's own
	# explicit priority - a leg's phase gate must read THIS frame's
	# phase_progress, not scene-tree declaration order's (correct here,
	# but implicit) guess at it.
	process_physics_priority = -1
	if info_label != null:
		_base_label_text = info_label.text
	apply_preset(preset)


## Left true (the default) preserves the original behavior EXACTLY: a
## single creature per scene responding directly to its own key presses,
## same as every scene this arc built before now. Set false when several
## creatures share one scene (e.g. a gallery/viewing room) - _input()
## becomes a no-op here, and an external dispatcher (that scene's own
## script, picking whichever single creature the player is nearest to or
## looking at) calls apply_preset()/toggles body.halted directly instead,
## so a key press doesn't drive every creature in the scene at once.
@export var standalone_input: bool = true


func _input(event: InputEvent) -> void:
	if not standalone_input:
		return
	if not (event is InputEventKey) or not event.pressed:
		return
	var key_event: InputEventKey = event
	if key_event.keycode == KEY_1:
		apply_preset("walk")
	elif key_event.keycode == KEY_2:
		apply_preset("trot")
	elif key_event.keycode == KEY_3:
		apply_preset("hop")
	elif key_event.keycode == KEY_4:
		apply_preset("canter_right")
	elif key_event.keycode == KEY_5:
		apply_preset("canter_left")
	elif key_event.keycode == KEY_0:
		# Halt is NOT a gait preset - see limb_prototype_body.gd's own
		# halted field for why this toggles Body directly instead of
		# going through apply_preset/PRESETS.
		body.halted = not body.halted
		_update_label()


## The ONLY thing that needs to change to switch gaits - no per-leg scene
## edits, no branching code elsewhere.
func apply_preset(preset_name: String) -> void:
	var data: Dictionary = PRESETS[preset_name]
	preset = preset_name
	reference_speed = data["reference_speed"]
	reference_period_sec = data["reference_period_sec"]
	duty_factor = data["duty_factor"]
	phase_offsets = data["phase_offsets"]
	period_sec = reference_period_sec
	phase_progress = 0.0
	valid_speed_ceiling = compute_valid_speed_ceiling(phase_offsets, reference_period_sec, reference_speed)
	_update_label()


func _update_label() -> void:
	if info_label != null:
		var halt_suffix: String = " [HALTED]" if body.halted else ""
		info_label.text = "%s | Gait: %s%s (1=walk 2=trot 3=hop 4=canter_r 5=canter_l 0=halt)" % [_base_label_text, preset, halt_suffix]


## The smallest nonzero gap between distinct phase_offset values (wrapping
## around 1.0), ignoring legs that intentionally share a phase (gap 0 -
## e.g. trot's diagonal pairs, which are SUPPOSED to move together, not a
## timing conflict to guard against).
static func compute_min_phase_spacing(phase_offsets_value: Array) -> float:
	var sorted_phases: Array = phase_offsets_value.duplicate()
	sorted_phases.sort()
	var min_spacing: float = INF
	for i in range(sorted_phases.size()):
		var next_i: int = (i + 1) % sorted_phases.size()
		var gap: float = sorted_phases[next_i] - sorted_phases[i]
		if gap < 0.0:
			gap += 1.0 # Wrap-around gap (last phase back to the first).
		if gap > 0.0001:
			min_spacing = minf(min_spacing, gap)
	return min_spacing if min_spacing < INF else 1.0 # All legs share one phase - no spacing constraint applies.


## The maximum body speed at which the TIME GAP between two distinct legs'
## phase crossings (min_phase_spacing * period_sec) still exceeds
## FIXED_STEP_DURATION_SEC by at least SAFETY_MARGIN_FRACTION - see this
## file's own header for the corrected derivation (this used to be based on
## (1-duty_factor)*period_sec, which real re-testing showed doesn't actually
## predict the overlap this class is trying to prevent under the hard-gate
## release mechanism).
static func compute_valid_speed_ceiling(phase_offsets_value: Array, reference_period_sec_value: float, reference_speed_value: float) -> float:
	var min_spacing: float = compute_min_phase_spacing(phase_offsets_value)
	var required_gap: float = FIXED_STEP_DURATION_SEC * (1.0 + SAFETY_MARGIN_FRACTION)
	return min_spacing * reference_period_sec_value * reference_speed_value / required_gap


## _physics_process, NOT _process - every downstream consumer of
## phase_progress (limb_prototype_foot_target.gd's phase gate,
## ik_chain_controller.gd's own solve) runs on the fixed physics tick, not
## the idle/render tick. Accumulating phase_progress from _process's own
## variable, real-wall-clock delta was tried first and measured to
## introduce genuine run-to-run non-determinism into the gait simulation
## itself: identical code, freshly re-launched with no changes, produced
## swing-phase residuals ranging from 0.09 to 0.30 across repeated runs
## (not just noise - two separate runs landed on the exact same 0.26742,
## suggesting real timing-driven quantization, not random jitter) - the
## idle loop's actual call rate/delta in a headless run isn't tied to the
## physics tick rate at all, so phase_progress could advance a
## meaningfully different amount relative to how many physics frames (and
## therefore how much real leg motion) had actually elapsed, shifting
## exactly when the phase gate crossed duty_factor relative to the
## chain's own fixed-step state. Physics-tick accumulation removes that
## skew at the source, matching the fix already applied to
## ik_chain_controller.gd's own physics-process ordering for the same
## underlying reason (every node in this dependency chain needs to share
## one consistent clock).
func _physics_process(delta: float) -> void:
	if body.halted:
		# Halt is a BODY-level state (see limb_prototype_body.gd's own
		# halted field), not a gait preset - freezing phase_progress here
		# on top of Body's own frozen position is what actually stops NEW
		# swings from being triggered while halted: local_phase (in
		# limb_prototype_foot_target.gd) is derived from phase_progress,
		# so a frozen value can never cross duty_factor again. Any leg
		# already mid-LIFTING/SWINGING keeps evolving on its own
		# elapsed-time clock regardless (untouched here) and finishes
		# landing normally, exactly as requested - only the GATE that
		# would start a NEW swing is what halt actually suppresses.
		return
	var current_speed: float = body.speed
	period_sec = reference_period_sec * (reference_speed / maxf(current_speed, 0.0001))
	phase_progress += delta / period_sec
