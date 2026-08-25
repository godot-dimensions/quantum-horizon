# Quantum Horizon — Procedural Creature Animation System

Draft v2 — supersedes v1. Corrects a stale blocker, resolves two open design questions, trims scope per explicit decision. Read this version, not v1.

## 1. Purpose & Scope

This document lays out the target architecture for a fully procedural, per-frame creature animation system: locomotion, posture, secondary motion, contextual actions, and authoring tools, all driven by shared solvers rather than baked clips. The goal is not photorealism — it's expressive, biomechanically-informed "juiciness" that scales across an arbitrary, procedurally-generated creature population (varying limb counts, proportions, weights) without per-creature hand tuning, and without wrecking frame budget at high creature counts.

This is a forward-looking design reference, not a sprint plan. It exists so that incremental engineering work (current FABRIK limb solver, gait FSM, upcoming hip/spine/neck IK) converges on a coherent architecture instead of accreting ad hoc fixes.

## 2. Core Design Principle

Everything is a target-and-constraint problem solved through a small number of shared IK/solver primitives. Locomotion, idle behaviors, and contextual actions are not separate systems with separate logic — they are all "move this chain toward this target, honoring these constraints," differing only in how the target is chosen and how many chains are involved.

This is what makes the system scale to a procedurally generated creature population: author the solvers once, generically, and let per-creature skeletal variation (limb count, segment count, proportions) fall out of parameters rather than bespoke rigs.

## 3. Processing Stack (per-tick order of operations)

Order matters — steering and gait state must be resolved before limb IK, since they change where the feet are even aiming. Hip suspension is explicitly one-frame-delayed against limb state (see 4.2) — this is what keeps the whole tick acyclic rather than circularly dependent on its own output.

```
1. Gait cycle timer advances
   → produces raw stance/swing phase per limb, raw footfall targets

2. Steering & turn-mode layer
   → determines: smooth arc-turn vs. plant-and-pivot sharp turn
   → biases each swinging limb's Bezier apex laterally (outer/inner stride
     asymmetry) — see 4.6
   → applies neck/shoulder turn-lead offset (phase-advanced yaw)

3. Ground adaptation
   → raycast per foot to find terrain height/normal (available now — see 4.7)
   → adjusts final footfall target height + foot angle

4. Hip suspension solver
   → derives body height/pitch/roll from *last frame's* actual planted-leg
     reach state (never this frame's fresh targets — see 4.2)

5. Spine IK chain
   → solves shoulder↔hip anchor chain
   → applies gait-phase-driven flex (compress/extend oscillation)

6. Neck/head IK chain
   → hangs off spine's front anchor
   → applies lag/damping (head bob) + optional counter-rotation
     (gaze stabilization, "chicken head" effect)

7. Limb FABRIK solve
   → resolves each leg chain against final (turn+ground-adjusted) foot target
   → post-hoc plane-alignment + per-joint bend correction applied here
     (see 4.1 — already scoped, implementation in progress as of this doc)

8. Secondary/idle/action layer (when active)
   → overrides or blends specific chain targets
     (scratch, grab, breathing, outlier behaviors)

```

Spine/neck and limb solving can run in parallel — they only depend on hip/shoulder anchors, not on each other's output.

## 4. Core Subsystems

### 4.1 Limb Solver (FABRIK) — in progress

* Existing system. Chain of N segments resolving toward a foot-placement goal, joint-count-agnostic by construction (already verified against 2/3/5-joint chains).
* Goal position currently derived by projecting body position to ground; needs to shift to consuming the hip suspension solver's output (4.2) rather than driving it.
* Post-hoc anatomical shaping (plane-alignment twist + per-joint alternating/decaying bend) is a separate, exact closed-form correction applied after FABRIK converges each frame — scoped and approved, implementation status tracked separately from this document.

### 4.2 Hip Suspension Solver — not yet implemented, timing now resolved

* Inverts the current assumption (body height fixed → limbs conform) to the anatomically correct one (limb reach constraints → body height/pitch/roll conform).
* Frame-timing, resolved: reads last frame's fully-resolved, actual foot positions and anchor points — never this frame's freshly-computed targets. Reading fresh targets would be circular: body pose would be derived from targets computed relative to the old body pose, then the body moves, invalidating the very targets used to compute it. One-frame-delayed feedback keeps this tick strictly acyclic — the same principle that resolved this project's two earlier `_process`/`_physics_process` ordering bugs, applied here deliberately rather than discovered as a bug later.
* Mechanism: for each currently-planted leg only (a swinging leg isn't load-bearing and shouldn't constrain posture), compute the body height at that leg's anchor that would place the chain at a comfortable resting extension fraction — a distinct parameter from the gait system's reach-release-fraction backstop, which governs edit/timing safety, not resting posture. Average across left/right anchor pairs for roll, front/back for pitch, all planted legs for base height. A creature with few currently-planted legs (e.g. mid-hop) naturally yields a more neutral pose — falls out of the formula, no special case needed.
* This is also the natural hook for load response: a heavier pack/weight parameter can bias target spine height downward or increase sag, and the solver reacts automatically — no separate "heavy creature" animation logic needed.

### 4.3 Spine IK Chain — not yet implemented

* Short IK chain between shoulder and hip anchors.
* Flex amplitude and phase are gait-driven parameters (a galloping cheetah gets large-amplitude compress/extend cycling; a rabbit-type hopper may want near-zero flex, relying on a hop-specific pattern instead).

### 4.4 Neck/Head IK Chain — not yet implemented

* Short chain hanging off the spine's front anchor.
* Head bob = damped lag behind shoulder motion (pendulum-like).
* Optional gaze/counter-rotation term for the horse/pigeon/chicken-style stabilized-head look.
* Also the natural site for a turn-lead offset: head/neck yaws into a turn ahead of the hips, which reads strongly as directional intent to the player (especially pronounced on long-necked creatures).

### 4.5 Gait State Machine

* Already in place. Discrete named gaits (walk/trot/canter/hop, etc.), each parameterized by stride length, duty factor, phase offsets between limbs, vertical bounce.
* Reference target: real biomechanical gait-analysis data (stance/swing phase timing, etc.) used as tuning targets rather than literal playback data — keeps the system in "convincing" territory without needing motion capture.
* Sharp-turn handling: treat plant-and-pivot rotation as its own discrete gait-machine state (triggered when turn-rate/forward-speed ratio crosses a threshold), not a continuous deformation of the normal gait — qualitatively different motion, not a scaled one.

### 4.6 Steering & Turning Layer — footfall-path collision with existing swing curve, now resolved

* Resolution: this generalizes the already-shipped swing curve rather than replacing it. Current behavior: `position(t) = lerp(lift_off, landing, ease(t)) + up·vertical_arc(t)`. Add one term — a lateral apex offset, zero by default: `position(t) = quadratic_bezier(lift_off, apex, landing, ease(t))`, where `apex = midpoint(lift_off, landing) + up·vertical_arc_peak + lateral_dir·apex_lateral_offset(turn_rate, is_outer_leg)`. Zero turn rate recovers today's exact straight-line behavior as a special case, not an approximation of it.
* This is the same Bezier-apex swing-trajectory technique already grounded in real quadruped-robotics literature (found and cited during the swing-curve work) — extended from a height-only apex bias to a height-and-lateral one, not a new technique.
* Outer/inner leg distinction (which side gets the wider arc) falls out of each leg's already-known lateral anchor offset relative to current turn direction — no new per-leg classification needed.
* Sharp/pivot turn: separate state (see 4.5), not a continuous deformation of this curve.

### 4.7 Ground Adaptation

* Status corrected: surface normals are available now. `PhysicsServer4D.raycast_physics_objects()` returns `global_normal` whenever the hit shape populates it (confirmed directly against engine source), and the shipped foot-segment system already consumes this (`locked_ground_normal`/`swing_target_ground_normal`). The earlier "blocked" note was a mix-up with a separate, unrelated prototype system — nothing to resolve here.
* Feeds foot angle and final placement height; should also factor into slope-driven stride length/body pitch adjustments (uphill/downhill gait changes) — not yet implemented, but no longer blocked.
* Anticipatory foot behavior (extending toward ground pre-contact, small "wind-up"/overshoot on lift) lives here or as a style parameter on the limb solver — already specified and in progress as part of the foot-segment work.

### 4.8 Secondary/Idle/Outlier Behavior Library

* A reusable library of parametric behavior templates, not baked poses: "scratch," "yawn," "shake off," "roll in dirt," etc., each defined generically (e.g. "lower a limb toward a body-relative target near head region, hold, repeat N times") and solved through the same IK chains as locomotion.
* Each entry tagged with skeletal requirements (needs ≥1 limb that can reach head region, needs a tail, etc.); the FSM filters the library to whatever's compatible with a given creature's rig at spawn/generation time.
* Authored once, expanded incrementally over time — not re-tailored per creature.
* Breathing/idle sits here too, always-on and cheap.

### 4.9 Contextual Action Layer

* Grab/attack/interact-type actions reuse the same chain-target machinery as locomotion and idle behaviors — differ only in trigger (contextual, not randomized/timed) and target selection logic (e.g. Spore-style hand-preferred-else-mouth resolution for interaction point).

## 5. Authoring Layer (Editor Tooling — future)

Target artist-facing surface, layered so no raw joint math is ever touched directly:

1. Body rig layer: limb count, segments per limb, spine anchor points, mass distribution.
2. Gait library layer: which named gaits are available at all for this body plan (heavy armored creature might only unlock idle/walk/slow-trot; a hopper might skip walk/trot in favor of a synchronized-hop gait entirely).
3. Style layer: overshoot, anticipation/windup, swing speed curves, spine flex amplitude/phase, head lag/stabilization strength — tunable per-creature on top of whichever gait is active, without touching the underlying solver.

## 6. Why Procedural (Not Mocap) Is the Right Call Here

* Mocap's real advantage is capturing subtle, authentic human performance nuance — it doesn't meaningfully apply to fictional/non-human creature rigs, which are hand-animated or procedural industry-wide regardless of budget.
* The strongest precedent for purely procedural creature animation (Rain World, Spore) is specifically praised for feeling more alive than baked animation, because physics-driven reactivity gives believable weight and response to arbitrary body plans and situations — exactly the property this design leans on (weight response, slope adaptation, steering). (Spore's own design history — CCD tried and explicitly rejected as "not tunable," replaced with a position-based approach — is independently confirmed via primary source; the Rain World comparison is a widely-repeated claim, not independently source-checked to the same standard.)
* Given the actual goal (a varied, procedurally generated creature population), procedural is the load-bearing architecture, not a fallback — the "juiciness" gap vs. AAA mocap work is closed by investment in the specific layers above (spine flex, head lag, anticipation, turn-lead), not by needing performance capture.

## 7. Open Dependencies / Blockers

* Hip suspension, spine IK, neck/head IK — designed above (timing resolved for hip suspension specifically), not yet implemented.
* Steering/turn-warp layer — designed above (footfall-curve collision resolved), not yet implemented.

## 8. Explicitly Out of Scope (for now)

* Full realism / AAA-mocap-parity fidelity (not the goal — target is "juicy," not photoreal).
* Cloth/fur secondary dynamics.
* LOD/fidelity scaling — deferred, depends on a central LOD authority design not yet settled elsewhere in the project.
* Mounting/rideable-transition handshakes — deferred, out of scope for this pass.
