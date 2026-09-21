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
- [ ] 14 Expose reusable config (wander radius, speeds, idle range, alert/evade, cooldown)
- [ ] 15 Twelve instances stay distinct via seeded variation

## Phase 03 — Chicken gameplay state model (16–25)
- [ ] 16 Core states: idle/wander, alert/evade, carried, dropped/thrown, penned, recovery
- [ ] 17 Centralised transitions own movement, collision, animation, prompt, locator eligibility
- [ ] 18 Expand the existing wander rather than replacing it
- [ ] 19 Loose chickens stay in authored regions
- [ ] 20 W behaviour predictable (stay in assigned W region)
- [ ] 21 Playful proximity response (hop, wing lift, short scurry)
- [ ] 22 Evade cooldown and distance limit — no chain-escaping
- [ ] 23 Evade targets always valid ground
- [ ] 24 Penned chickens behave calmly, never flee
- [ ] 25 Debug state readout, easy to disable

## Phase 04 — Catch, carry, drop and throw (26–35)
- [ ] 26 Forgiving catch candidate selection
- [ ] 27 Contextual catch prompt, hidden the instant it stops applying
- [ ] 28 Immediate catch response
- [ ] 29 Carry anchor above the player's head, orientation cue preserved
- [ ] 30 Living carried pose
- [ ] 31 Movement, turning and W navigation while carrying
- [ ] 32 Drop and gentle throw that clears the fence
- [ ] 33 Clean landing — no bouncing, tunnelling or permanent airborne
- [ ] 34 One chicken at a time, obvious in input and UI
- [ ] 35 Decide reuse of returned chickens (default: penned, non-catchable)

## Phase 05 — Procedural pen fence and return volume (36–44)
- [ ] 36 Reusable procedural fence (repeated posts and rails, not a stretched mesh)
- [ ] 37 Numeric Inspector dimensions (+/-X, +/-Z, height, spacing, optional gate)
- [ ] 38 Rebuild without visual stretching
- [ ] 39 Collision regenerates with geometry
- [ ] 40 Return volume generated from the SAME parameters
- [ ] 41 Fence low and readable
- [ ] 42 Interior comfortably fits 12 chickens plus coop
- [ ] 43 Register each return exactly once
- [ ] 44 Returned chickens stay contained

## Phase 06 — Functional chicken house (45–49)
- [ ] 45 Designed coop (body, roof, chicken-sized opening, ramp)
- [ ] 46 Low-poly, consistent with existing style
- [ ] 47 Placed at the back of the pen
- [ ] 48 Optional idle interest points
- [ ] 49 Practical dimensions editable (not fully proceduralised)

## Phase 07 — W-locator, hiding and discovery (50–66)
- [ ] 50 INSPECT the Shooting Gallery first — reuse its target-location logic and UI language
- [ ] 51 Locator's minimum information
- [ ] 52 Two-part cue (spatial arrow + ana/kata indicator) if it fits
- [ ] 53 Signal strength communicates approach
- [ ] 54 Chicken audio as supporting guidance
- [ ] 55 Optional partial visual reveal near the correct slice
- [ ] 56 Stable target selection (nearest eligible, no rapid switching)
- [ ] 57 Exclude invalid targets (carried, penned, completed)
- [ ] 58 Not an autopilot
- [ ] 59 Readable 12-chicken progression (3 near slice, 3 XYZ, 4 W, 2 combined)
- [ ] 60 First off-slice chicken needs only a small adjustment
- [ ] 61 One new variable at a time
- [ ] 62 Preserve designed hiding relationships
- [ ] 63 Legible slice alignment (lock tone / centred indicator)
- [ ] 64 Carried chicken survives player W movement; returns to pen's W
- [ ] 65 Superior repo-specific solutions allowed — explain them
- [ ] 66 Test comprehension from a cold start, not only correctness

## Phase 08 — Objective flow, feedback, completion (67–74)
- [ ] 67 Clear start state near the pen with a short objective message
- [ ] 68 Teach controls at the moment each first matters
- [ ] 69 Persistent restrained progress counter
- [ ] 70 Confirm each return immediately
- [ ] 71 No timer in the default mode
- [ ] 72 Clear completion event at 12/12
- [ ] 73 Restart and replay without an editor restart
- [ ] 74 Presentation stays prototype-focused

## Phase 09 — Robustness, recovery, optimisation (75–82)
- [ ] 75 Stable identity per chicken (IDs, not tree order or names)
- [ ] 76 Detect invalid positions and recover
- [ ] 77 Idempotent catch/drop/throw/return against rapid input
- [ ] 78 No pen overcrowding failures
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
