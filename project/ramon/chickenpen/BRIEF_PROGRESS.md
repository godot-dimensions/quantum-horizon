# 4D Chicken Pen Prototype — build progress

Working checklist against the brief. Ramon supplied it as markdown at
`project/ramon/follow_up/4D_Chicken_Pen_Prototype_Claude_Implementation_Brief.md`
(90 items, 10 phases) - read THAT for the full wording of any item; this file only
tracks what is done.

Brief's own instruction: treat ordered outcomes and non-destructive starting conditions
as REQUIREMENTS; treat the proposed locator UI, hiding patterns and capture details as
INFORMED SUGGESTIONS. Inspect the existing Quantum Range / Shooting Gallery and use
better repo-specific solutions where they improve clarity — documenting any deviation.

Status: `[ ]` not started · `[~]` in progress · `[x]` done · `[!]` deviated, see notes

## Phase 00 — walk/run polish (Ramon's extra ask, not in the brief)
- [x] Running as the default gait, less frantic (3.0 units/s, 2.3 steps/s; ALT walks, SHIFT sprints)
- [x] Swing-leg fold 106 deg -> 74 (a person is ~65); stance 32
- [x] Ankle joint added to all three builds; foot levelled at 0.85 of the leg's rotation

## Phase 01 — Scene foundation and safe duplication (1–7)
- [x] 1  `chickenpen.tscn` copied from `chickenpen_proceduralwalker.tscn`; source recorded in root metadata `copied_from`
- [x] 2  Baseline verified: player lands on floor, 20 avatar blocks, camera current, gait running
- [ ] 3  Optimise the copy carefully (remove only verified-unused residue)
- [x] 4  Groups added: World (sun, environment, ground, scenery) / Chickens / Pen / UI / Systems; Player kept top-level
- [ ] 5  Playable bounds with enough XYZ and W variation for 12 placements
- [ ] 6  Protect reusable systems — instance/extend rather than fork scripts
- [ ] 7  Baseline checkpoint: launches clean, behaviour and performance noted

## Phase 02 — Existing chicken audit and completion (8–15)
- [x] 8  Found in `project/ramon/Model/rigged_creature_ramon.tscn` (Chicken + Walker, chicken_walker.gd)
- [x] 9  Extracted to `chickenpen/chicken.tscn` (37 nodes, 32 sub-resources); runs standalone, 2 legs, wanders 0.46 units
- [x] 10 Audited: wander is script-driven (chicken_walker.gd) - fBm steering, gait clock, two-bone leg IK, pecking, flock separation. Not animation clips.
- [x] 11 Feet were missing (legs ended in stubs). Added, following the foot ball via follow_node_4d.gd
- [x] 12 Red mark on the right wing (-X, since the chicken faces +Z), parented to the Wing rig so it is not mirrored
- [!] 13 Comb and wattle are already red - see Deviations
- [x] 14 chicken_agent_4d.gd exposes home, wander radius, w drift, speeds, idle/wander ranges, alert/evade distance, evade cap and cooldown, catch distance, seed
- [x] 15 One chicken.tscn instanced twelve times; seed drives idle timing, wander range and nerve. 12 distinct seeds verified

## Phase 03 — Chicken gameplay state model (16–25)
- [x] 16 IDLE, WANDER, ALERT, EVADE, CARRIED, THROWN, PENNED, RECOVERING
- [~] 17 Transitions centralised in _enter(); movement and locator eligibility wired. Collision and prompt follow in Phase 04
- [x] 18 Walker kept for locomotion; agent adds pauses, alert, evade and containment on top via an inert steer hook
- [x] 19 Steered home past wander_radius - a pull, not a wall
- [x] 20 W clamped to home +/- w_drift (0.15), far tighter than XYZ
- [ ] 21 Playful proximity response (hop, wing lift, short scurry)
- [ ] 22 Evade cooldown and distance limit — no chain-escaping
- [ ] 23 Evade targets always valid ground
- [x] 24 PENNED ignores alert and evade, shorter leash
- [ ] 25 Debug state readout, easy to disable

## Phase 04 — Catch, carry, drop and throw (26–35)
- [x] 26 Scored on distance AND facing; best valid candidate wins, through all four axes
- [x] 27 Prompt shown only when a catch would work, cleared while carrying
- [x] 28 Catch locks the chicken and halts its walker on the frame of input
- [x] 29 CarryAnchor at y 1.62, slightly forward so the bird is not behind the head
- [ ] 30 Living carried pose
- [x] 31 Verified: max gap to anchor 0.081 while moving, including through W
- [x] 32 Throw travels 5.8 units on an arc; separate gentle drop on fire
- [ ] 33 Clean landing — no bouncing, tunnelling or permanent airborne
- [x] 34 Second catch blocked while carrying (verified); prompt hidden while occupied
- [ ] 35 Decide reuse of returned chickens (default: penned, non-catchable)

## Phase 05 — Procedural pen fence and return volume (36–44)
- [x] 36 pen_fence_4d.gd, @tool, posts and rails as modular segments
- [x] 37 Per-side extents, height, spacing, rail count, thickness, W depth, gate side/position/width
- [x] 38 Verified: 14x12 gives 36 posts, 28x12 gives 55; post size constant at 0.13
- [x] 39 One wall per run, built in the same pass; 5 walls for a gated pen
- [x] 40 No second box - interior_bounds() derives from the same extents; verified it tracks resizes
- [x] 41 Height 0.95 against a 1.35 player - see over it, throw over it
- [ ] 42 Interior comfortably fits 12 chickens plus coop
- [x] 43 The returned flag lives on the chicken, so re-entry cannot re-count
- [x] 44 A penned chicken that leaves is replaced inside, score untouched

## Phase 06 — Functional chicken house (45–49)
- [x] 45 `pen_coop_4d.gd` — stilted body, split front with a real doorway and lintel, pitched roof, ramp
- [x] 46 Box tetra meshes and flat colours, same vocabulary as the fence
- [x] 47 At `Pen/Coop`, z −4.3 inside a pen that reaches −6, doorway facing in
- [x] 48 `idle_points()`; every third returned bird takes one as its home and walks over
- [x] 49 Size, roof rise, doorway, ramp and stilts exported; nothing else parameterised

## Phase 07 — W-locator, hiding and discovery (50–66)
- [x] 50 Inspected the Range; reuses `scripts/bearing_utility_4d.gd` rather than re-deriving it
- [x] 51 Nearest eligible chicken: direction, distance, W side, strength — nothing more
- [x] 52 Two parts kept separate: where to walk, and which way through W
- [x] 53 Five-bar strength from `angle_off_slice`; drops when you close in XZ without matching W
- [x] 54 Synthesised cluck in `chicken_cues_4d.gd`; rate and level rise with alignment, no direction encoded
- [x] 55 Orthoplex marker — its cross-section shrinks to a point at the band edge, so the engine does the fade (no alpha exists to fade with)
- [x] 56 Nearest eligible, with a 25% hysteresis margin before it switches
- [x] 57 Eligibility asked of the chicken; verified the target moves on the moment one is returned
- [x] 58 No coordinates, no marker at range; the glimpse only exists once you are nearly in the slice
- [x] 59 Placement table authored in that order; verified 6 in the starting slice, 6 offset in W
- [x] 60 First W chicken sits at w = 0.9
- [x] 61 Placements 7–10 vary W alone, 11–12 add distance
- [x] 62 Bounded wander around authored homes, plus a W leash; never becomes a chase
- [x] 63 `LOCKED ... in your slice - catchable` — a state change, not a better number
- [x] 64 Carried chicken holds the player's W (1.18 vs 1.20); on return it eases onto the pen slice over 1.6 s rather than snapping
- [x] 65 Reused the Range's bearing utility; replaced the Range's slice-rotate advice with this scene's real control
- [x] 66 `_verify_comprehension_runner.gd` reads the screen, presses the key it names, locks on in 33 frames

## Phase 08 — Objective flow, feedback, completion (67–74)
- [x] 67 Player starts 9.5 units from the pen beside a keeper placeholder and a sign; objective on screen
- [x] 68 `pen_tutor_4d.gd` for move and the W axis; the catcher prompts catch, throw and put-down. No panel, each hint once
- [x] 69 `Chickens returned: n/12`, one line under the objective
- [x] 70 Rising two-note chirp on the frame the count moves — up, where the clucks fall
- [x] 71 Verified none: no Timer node and no exported limit (the only countdown is each chicken's next peck)
- [x] 72 Locator stops guiding and says so, objective becomes the completion line, eight-cluck chorus, glimpses off
- [x] 73 Ctrl+R: 12 eligible again, none marked returned, homes back at authored spots, locator and hints restored
- [x] 74 Flat colours and box meshes throughout; the only things added were a keeper and a sign, both marking where chickens go

## Phase 09 — Robustness, recovery, optimisation (75–82)
- [x] 75 chicken_id plus a fixed seed; nothing keys off tree order
- [ ] 76 Detect invalid positions and recover
- [~] 77 Catch and release guard on the carried slot; area re-entry guard comes with the pen
- [~] 78 Penned destinations are spread inside the interior with a margin; no chicken-to-chicken collision exists to explode
- [ ] 79 Avoid unnecessary per-frame work; stagger low-priority decisions
- [ ] 80 Optimise AFTER measuring against the baseline
- [ ] 81 Debug controls (teleport, reset, mark W targets, resize pen, force states)
- [ ] 82 Fail visibly during development

## Phase 10 — Verification and delivery (83–90)
- [ ] 83 Source scenes intact
- [ ] 84 New scene launches from a clean project state
- [ ] 85 All twelve chickens verified end to end
- [ ] 86 Locator verified across all placements
- [ ] 87 Fence parameters verified in several directions
- [ ] 88 Orientation cue verified
- [ ] 89 Full loop 0/12 → 12/12, then restart and part of a second run
- [ ] 90 Implementation report

## Deviations from the brief
(recorded as they happen, with the reason)

**Item 13 - competing red marks.** The chicken already had a red comb and red wattle
before this brief; they are anatomically red and removing them would make it stop reading
as a chicken. They sit on the HEAD, which is a facing cue rather than a chirality cue, so
they do not compete with what the wing mark is for: telling left from right, which is the
thing a W-rotation can flip. The wing mark is larger and more saturated than either, on an
otherwise white wing. If it turns out to confuse in play, the comb and wattle can be
shifted to orange in one line each.

## Notes
- Source scene for the rig: `project/ramon/chickenpen/chickenpen_proceduralwalker.tscn`
- Source for the chicken: `project/ramon/Model/rigged_creature_ramon.tscn` (Chicken + Walker)
- CLAUDE.md forbids editing `shooting_gallery.tscn` — Phase 07 inspection is READ ONLY.
