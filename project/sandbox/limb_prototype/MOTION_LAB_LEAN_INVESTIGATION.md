# Motion lab treadmill — persistent "lean" investigation summary

## Context / goal

`sandbox/limb_prototype/limb_prototype_treadmill.tscn` + `scripts/motion_lab_creature.gd`
is a dev-inspection scene: one procedural quadruped standing on a flat platform, cycling a
selected gait in place ("treadmill" behavior) so the player can watch a full gait cycle
without having to chase a moving creature. Requested features this arc: gait-dependent pace
(walk slowest, canter fastest), hop removed as a selectable gait for now, and — running
through everything — a reported "full lean" pose that looks physically wrong (as if the
creature would tip over) and hasn't been resolved despite several rounds of fixes.

## Architecture as it stands today

- **Body stays in place via a loose horizontal spring tether** (`motion_lab_creature.gd`,
  `_physics_process`) — no forcing term, just a damped spring pulling `position.x` back
  toward spawn. Confirmed via direct trace: with nothing pushing it, position.x sits at
  exactly 0.0 the entire time.
- **"Walking forward" is simulated via a belt, not real translation**: while a foot is
  `PLANTED`, `limb_prototype_foot_target.gd` slides its `locked_position` backward every
  frame at `belt_speed` (an export, default 0 = off, only nonzero for this scene's feet).
  This makes `reach = anchor - locked_position` grow over the stance exactly like it would
  if the anchor were the one moving — same release-timing math either way.
- **`belt_speed` is deliberately independent of `body.speed`** (which `gait_controller.gd`
  reads for its own cadence scaling). Discovered directly (not guessed) that sharing one
  field between the two made total reach consumed per stance ≈
  `reference_period_sec * reference_speed - FIXED_STEP_DURATION_SEC * speed` — dominated by
  the first (speed-independent) term, so walk was structurally consuming ~90%+ of a leg's
  reach budget per stance *regardless* of the speed value chosen. Decoupling fixed this:
  `body.speed` now stays fixed at 2.0 (= every `FOUR_LEG_GAITS` preset's own
  `reference_speed`), so cadence always equals each preset's already-tuned reference period;
  `GAIT_BELT_SPEEDS` (walk 1.2, trot 1.8, canter 2.4) drives belt rate only.
- **Swing duration (lift+swing) now scales per gait** instead of a fixed 0.5s
  (`SWING_SAFETY_MARGIN_FRACTION`/`SWING_HEADROOM_FRACTION` in `motion_lab_creature.gd`,
  reusing `gait_controller.gd`'s own `compute_min_phase_spacing` formula so it doesn't
  reintroduce cross-leg overlap — a first attempt that scaled off the duty-factor eligible
  window instead was measured to cause up to 4 legs airborne simultaneously in canter, and
  was reverted in favor of this safer, formula-derived version).
- **Leg-index-to-physical-position mapping bug found and fixed**: `_build_rig()`'s
  `pair_index` loop had front/back backwards relative to `gait_controller.gd`'s own
  documented convention (leg 0 = front-left, etc.). Confirmed via hand-derived phase math
  that this particular swap was phase-structure-preserving for all three currently-used
  gaits (just relabels which diagonal leads) — real bug, fixed, but NOT the cause of the
  lean.
- **hop removed** from `FOUR_LEG_GAITS`/`GENERAL_GAITS`/`GAIT_BELT_SPEEDS`; key 3 unbound;
  `gait_controller.gd`'s own `hop` preset is untouched (other scenes may still use it).
- **Camera repositioned** to a ¾ diagonal view (`limb_prototype_treadmill.tscn`'s `Player`
  node) instead of dead-on-lateral, since the original angle made left/right leg pairs
  render almost on top of each other (differing only in Z, which maps to depth from that
  viewpoint) — confirmed via screenshot this was a real, separate source of visual
  confusion, though it did NOT resolve the lean once corrected.

## What's been directly measured and RULED OUT as the cause of the lean

- **Body tilt from `hip_suspension_solver.gd`**: measured exactly 0.00° for the entire
  duration of a live walk cycle. This is mathematically forced to be zero on this specific
  setup — its pitch/roll come from a per-leg target-height regression, and on a flat
  platform with 4 *uniform* legs, every leg's target height is identical, so there is no
  variation for the regression to find. Not a malfunction; there is nothing for it to
  respond to here.
- **Phase gate / stagger timing**: measured the exact state-transition timeline (not
  aggregate stats) for all 4 legs across 2 full walk cycles. Result: legs swing one at a
  time, each ~0.65s, evenly spaced ~1.0s apart (matching the 0.25 phase-offset gaps
  exactly), with only ~0.35s of true quiet between swings — no bunching, no "long pause
  then all-4 burst" anywhere in the underlying simulation.
- **Reach-release backstop overfiring**: `reach_override_count` = 0 across every gait tested
  in every round of verification this session.
- **Leg-index swap**: real bug (fixed), but shown by direct phase-math derivation to be
  structurally equivalent to the correct mapping for all 3 gaits actually in use — doesn't
  explain the lean.
- **Camera occlusion**: real, separate contributing factor to *confusion* (fixed), but the
  user confirmed the lean is still visible and looks physically wrong from the corrected ¾
  angle too — so it is not merely a viewing-angle artifact.

## Leading (unconfirmed) hypothesis — not yet fixed

Under belt-driven walking, each `PLANTED` leg's `reach` (distance from anchor to foot) grows
continuously for as long as it's been planted (the belt keeps sliding `locked_position`
backward). Because the 4 legs are phase-staggered (offsets 0, 0.25, 0.5, 0.75), at any given
instant they are each at a *different* point in their own stance duration — so they have 4
different reach amounts simultaneously. Measured peak-vs-baseline spread for walk: peak
reach ~73% of `max_reach` vs. a freshly-landed leg at ~50–55% — a real, ~20-percentage-point
difference in extension across the 4 legs at any moment, confirmed via
`_verify_motion_lab_belt_decouple_runner.gd`.

`hip_suspension_solver.gd` only reacts to *ground height* differences between planted legs
(via `locked_position.y`), never to *reach/extension* differences — so on this flat platform
there is no mechanism compensating for a near-fully-extended leg the way a real animal would
shift its weight/posture to accommodate it. The visible "lean" — front legs tucked steeply
under the body while back legs stretch out nearly flat, or vice versa — is consistent with
this: it may be an accurate rendering of the current model's real leg-extension asymmetry,
just with no postural compensation layered on top, which is what makes it read as
physically wrong ("would tip over") rather than as an ordinary mid-stride reach.

This has NOT been fixed yet. It's a design gap, not a located bug: the current hip
suspension model doesn't have the right kind of input signal to address it. Candidate
directions, none implemented or verified:

1. Extend `hip_suspension_solver.gd`'s regression to also weigh per-leg *reach fraction*
   (not just ground height) when computing pitch/roll/height — i.e. give it a reason to
   respond to leg-extension asymmetry the same way it already responds to ground-slope
   asymmetry. This is a real model extension, not a tuning knob.
2. Reduce the reach spread at the source — lower `belt_speed` further and/or shorten
   effective stance duration, so the peak-vs-baseline gap shrinks and the asymmetry is less
   visually extreme, independent of whether hip suspension ever compensates for it.
3. Reconsider whether a strict one-leg-at-a-time release model (current design) is the right
   fit for this treadmill's belt-driven stance mechanic at all, versus a model with smoother
   overlapping weight transfer between legs.

## Files touched this session (for reference)

- `scripts/motion_lab_creature.gd` — tether, belt speeds, swing-duration scaling, leg-index
  fix, hop removal, gait application.
- `scripts/limb_prototype_foot_target.gd` — `belt_speed` field/PLANTED-branch slide.
- `scripts/motion_lab_controller.gd` — hop keybind removed, hint text updated.
- `sandbox/limb_prototype/limb_prototype_treadmill.tscn` — player spawn position/facing.
- `scripts/hip_suspension_solver.gd`, `scripts/gait_controller.gd` — read/referenced, not
  modified this round.
- Various temporary `scripts/_verify_motion_lab_*_runner.gd` diagnostic scripts (kept per
  this project's existing convention of not deleting verify scripts after use).

## Resolution (this round)

1. **Mapping check, single instant, all 4 legs at once**: confirmed correct.
   `FL=0.000, FR=0.250, BL=0.500, BR=0.750`, exactly matching `gait_controller.gd`'s
   documented `phase_offsets`/leg-order convention. No lingering index bug.
2. **Chronological order revealed real structure**: because `local_phase` crossing happens
   at `phase_progress = duty_factor - offset`, the actual firing order is the
   *descending*-offset order (`BL → FR → FL → BR`), not the ascending assignment order.
   The gaps between successive fires are uneven (0.25 of the cycle three times, 0.75 once)
   — meaning one leg sits planted (and reach-growing) for 3 of every 4 seconds while its
   partner cycles on its own clock. Reviewing dense screenshots across a full cycle from the
   corrected ¾ camera confirmed the lean is exactly this: a **transient**, ~20% of the
   cycle, coinciding with that leg's peak reach deficit — not a persistent, always-wrong
   pose. Matches a plausible reach-asymmetry read, per the user's own framing.
3. **`hip_suspension_solver.gd` completed**: now also weighs each planted leg's own
   `actual_reach_fraction` (not just ground height) into its local target height — a leg
   more extended than `resting_extension_fraction` pulls its own target height down
   (relief: less vertical drop reduces required reach), an under-extended leg pulls it up.
   Verified directly: on the motion lab's flat/uniform platform, where the old formula
   produced exactly 0.000° for the entire session, the completed version now produces a
   real response — up to ~2.3° over a 15s walk cycle, 95.8% of frames nonzero, no NaN.
4. **Two additional bugs found and fixed while verifying this**:
   - `resting_extension_fraction`'s class default had been left at `0.5333` since an
     earlier, unrelated hopper-overfiring investigation (a sed rollback that was never
     restored) — silently mismatched against the `0.8` every actual caller (steed/giraffe,
     the motion lab's own seed height) intends. Restored to `0.8`.
   - The new `reach_response_weight` defaults to **0.0** (opt-in), not applied globally.
     First attempt defaulted it on (0.4) for every user of this shared script, including the
     gallery's real-wandering steed/hopper/giraffe — measured 28–64° max tilt there, a real
     instability (their reach dynamics come from actual anchor translation during wander,
     which swings much harder than the motion lab's tethered/belt-driven case). Made it
     opt-in; `motion_lab_creature.gd` now explicitly sets `reach_response_weight = 0.4` on
     its own solver instance, where it's confirmed safe. Steed and Giraffe measured back to
     exactly 0.000° after the fix.
   - **Hopper's ~71° tilt (flagged above) — now confirmed and fixed**: logged the ground-
     height regression's exact per-leg inputs at a standstill (body halted immediately, 0
     wander motion, `reach_response_weight` confirmed at 0.0). Front legs (`max_reach` 4.5)
     and back legs (`max_reach` 7.2) fed the regression `y_value`s of 3.375 and 4.815
     respectively — a 1.44-unit spread from leg-length asymmetry ALONE, on flat ground,
     nothing moving. That alone implies a ~34° pitch slope; measured actual tilt at that
     instant was 26° (still catching up via the damped response) — confirms this, not
     anything reach-related, was the real cause.

     Root issue: the regression compared each leg's *raw* target height directly, so a
     leg pair with a structurally different natural length got read as "the ground must be
     sloped here," even with zero real slope. Fix: subtract each leg's own
     `resting_extension_fraction * max_reach` baseline before feeding it into the pitch/roll
     regression (a new `normalized_ys` array) — cancels the structural asymmetry while
     leaving genuine ground-slope variation and the reach-response term untouched. The
     height/base computation deliberately keeps using the raw (non-normalized) values, since
     the overall standing height legitimately should blend each leg's own natural
     contribution — only the *tilt* needed to be blind to leg-length differences.

     Verified every consumer of this shared solver, not just Hopper: standstill tilt
     0.000° (was 26°+ and climbing); a full 15s of real wander/gait for Steed, Hopper, and
     Giraffe together all measured exactly 0.000° max tilt, no NaN (Hopper was 71.456°
     before, Steed/Giraffe unchanged at their already-correct 0.000°); the motion lab's own
     reach-response behavior re-verified byte-identical (2.318° max) — expected and
     confirmed, since its uniform legs make the normalization subtract the same constant
     from every leg, a mathematical no-op for the slope specifically there.

## Walk phase-offset assignment fix (this round)

Separate from the lean itself: the chronological-order derivation used to investigate the
lean (`phase_progress = duty_factor - offset`, using actual physical leg identities) was
run against the real intended lateral-sequence walk footfall pattern from earlier gait
research (LH→LF→RH→RF, i.e. `BL→FL→BR→FR` in this project's own FL/FR/BL/BR naming).

**Confirmed mismatch, not just "different but still valid"**: the walk preset's existing
`phase_offsets` — `[0.0, 0.25, 0.5, 0.75]` assigned to `FL,FR,BL,BR` in that ascending order
— satisfies "evenly spaced," "no bunching," and clean co-occurrence data, but produces the
real chronological sequence `BL → FR → FL → BR`, which is not the intended pattern (nor any
standard real quadruped gait sequence). This happens because a leg's own gate fires at
`phase_progress = duty_factor - offset (mod 1)` — ascending offset values do NOT produce
ascending fire order, so assigning offsets to legs "in order" doesn't do what it looks like
it should.

**Fix**: `gait_controller.gd`'s `PRESETS["walk"]["phase_offsets"]` changed from
`[0.0, 0.25, 0.5, 0.75]` to `[0.25, 0.75, 0.5, 0.0]` (still FL,FR,BL,BR order) — the same
four values, permuted to reproduce the intended sequence. This is a phase-offset assignment
fix, not a new mechanism: duty_factor, spacing, and the overlap-safety math are all
untouched, since they only depend on the *set* of offset values and their pairwise gaps,
never on which physical leg holds which one.

**Verified the same way co-occurrence was verified for walk/trot originally, not just
re-confirming "still evenly staggered"**:
- Recomputed the chronological sequence after the fix on the motion lab: `BL → FL → BR →
  FR`, exactly matching intended. `MATCHES INTENDED SEQUENCE: true`.
- Re-checked the gallery's Steed (shares this same preset) — identical result, confirms the
  fix applies correctly to both consumers, not just the motion lab.
- Re-ran the walk/trot/canter co-occurrence check (max simultaneous airborne legs,
  reach_override_count) on the motion lab: numbers came back byte-identical to the pre-fix
  baseline (walk max 1 in steady state, trot max 2, canter's known transient unchanged,
  zero backstop fires throughout) — confirms the permutation didn't disturb overlap safety
  at all, exactly as the underlying math predicts.

Scope note: only walk's assignment was checked/fixed this round, since that's the preset
the intended real-sequence reference (LH→LF→RH→RF) applies to. Trot's phase_offsets
(diagonal pairs) and canter's (solo/pair/solo) are separate dict entries, untouched by this
change, and weren't re-examined against a specific intended real sequence here.

## A process note, unrelated to the gait logic itself

A large amount of this session's time was lost to `project.godot` silently accumulating a
**duplicate `Verify=` autoload key** under `[autoload]` at some point during repeated edits;
Godot's ini parser kept honoring the *last* one, which stayed stuck on an old, already-
deleted script for a long stretch, making several "fresh" verification runs silently replay
stale results. Now fixed and being checked for (`grep -c "^Verify=" project.godot` should
always report exactly 1) before trusting any verify run's output.
