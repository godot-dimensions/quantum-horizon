# 4D Chicken Pen Prototype

A detailed implementation checklist for Claude: reuse the finished third-person rig and animated chicken, build a functional Cucco-style collection loop, and make W-space discovery understandable without overdesigning the prototype.

- **Primary scene:** `chickenpen.tscn`
- **Chickens:** 12 total
- **Design priority:** Functional clarity

## How Claude should use this brief

> Treat the ordered outcomes and non-destructive starting conditions as requirements. Treat the proposed locator UI, hiding patterns, and capture details as informed suggestions. Inspect the current project, especially the existing Quantum Range / Shooting Gallery implementation, and use better repo-specific solutions whenever they improve clarity, reliability, or player understanding. Do not follow a suggestion blindly when the actual codebase supports a stronger approach. Briefly document any meaningful deviation and why it is better.

## Build sequence

1. Scene foundation and safe duplication
2. Existing chicken audit and completion
3. Chicken gameplay state model
4. Catch, carry, drop, and throw interaction
5. Procedural pen fence and return volume
6. Functional chicken house design
7. W-locator, hiding, and discovery
8. Objective flow, feedback, and completion
9. Robustness, recovery, and optimisation
10. Verification and delivery report

## Phase 01: Scene foundation and safe duplication

Begin from the finished playable work. The new minigame must be a safe, independently runnable scene rather than a rewrite of the original rig scene.

### 1. Copy the finished rig into chickenpen.tscn

Locate the completed procedural 3D third-person character rig and copy it into a new scene named **chickenpen.tscn**. This copied scene is the foundation of the prototype. Do not overwrite, rename or destructively modify the finished source scene.

- Preserve the original player rig, controller, camera, animation links and required dependencies.
- Make the copied scene independently launchable before adding any chicken gameplay.
- Record which source scene was copied so future changes remain traceable.

### 2. Establish a clean baseline

Run chickenpen.tscn immediately after copying it. Confirm that movement, camera behaviour, ordinary 3D rotation, W controls and character animation behave exactly as they did in the finished source.

### 3. Optimise the copied scene carefully

Remove irrelevant test objects, duplicated debug content and clearly unused prototype residue only after verifying they are not required by the rig. Optimise the copy without prematurely rewriting systems that already work.

### 4. Create a readable scene structure

Organise the minigame under clear functional groups so the prototype remains easy to extend and diagnose.

- Player and camera
- World and bounds
- Chicken manager and chicken instances
- Pen, procedural fence and chicken house
- Locator, objective UI and audio
- Recovery, debug and completion logic

### 5. Define the playable bounds

Create a compact functional search area. It does not need finished art direction, but it must contain enough ordinary spatial variation and W variation to support twelve distinct chicken placements.

### 6. Protect existing reusable systems

Prefer instancing, extension and composition over copying scripts into divergent versions. If a shared system must change, make the change compatible with its existing users or isolate the minigame-specific behaviour.

### 7. Create a baseline checkpoint

Before adding chickens, confirm the new scene launches without errors and note the baseline behaviour and performance. This becomes the comparison point for later optimisation.

## Phase 02: Existing chicken audit and completion

The animated chicken built earlier is the source of truth. Reuse and expand it; do not create a replacement model, rig or unrelated animation setup.

### 8. Locate the existing animated chicken

Search the current project for the previously completed animated chicken scene and identify its model, rig, animation player or animation tree, movement script, collision and materials.

### 9. Run the chicken in isolation

Open or instance the chicken in a small test context. Verify the existing wander, idle and movement animations before changing anything.

### 10. Audit what already works

Document the useful existing behaviour and retain it. Determine whether wandering is driven by animation, navigation, steering, scripted target points or a combination.

### 11. Add feet only if still missing

Check the current model first. If feet are absent, design simple low-poly feet that match the chicken and deform or move convincingly with the existing animation. Do not remodel more than needed.

### 12. Add the right-wing orientation mark

Place one clearly readable red spot on the chicken's **right wing only**. It must remain identifiable when the wing is resting and when it lifts slightly. This is a deliberate orientation cue for reading the chicken through 4D changes.

### 13. Preserve the visual hierarchy

Keep the red spot unambiguous and avoid adding competing red marks elsewhere. The rest of the chicken can remain visually simple and consistent with the existing low-poly style.

### 14. Prepare reusable chicken configuration

Expose only the values that will genuinely help tune twelve instances: wander radius, speeds, idle duration range, alert distance, evade distance, evade cooldown and optional small variation seeds.

### 15. Confirm twelve instances remain distinct

All chickens may share the same source scene, but their timing and wander choices should not synchronise. Use light seeded variation rather than twelve manually edited copies.

## Phase 03: Chicken gameplay state model

Keep the state model explicit. A chicken should never be half-wandering, half-carried or counted twice because several unrelated booleans disagree.

### 16. Define the core states

Implement a small readable state model for each chicken.

- Loose idle or wandering
- Alert or short evade
- Caught and carried
- Dropped or thrown
- Returned and penned
- Recovery after becoming invalid or stuck

### 17. Centralise state transitions

Make each transition responsible for enabling and disabling the correct movement, collision, animation, interaction prompt and locator eligibility.

### 18. Expand the existing wander rather than replacing it

Analyse the prior wandering system and add only what the minigame needs: natural pauses, direction changes, local containment and variation between chickens.

### 19. Keep loose chickens within authored regions

Each chicken should have a local wander region or home position. Loose chickens must not drift so far that carefully designed placements lose their purpose.

### 20. Keep W behaviour predictable

For the first prototype, a loose chicken may wander in ordinary XYZ space but should remain within its assigned W region unless the existing Shooting Range logic supports a clearly readable better behaviour.

### 21. Add a playful proximity response

When the player approaches, the chicken may sometimes make a small hop, lift its wings slightly and scurry a short distance away. Use the existing animation system wherever possible.

### 22. Prevent frustrating chain-escaping

Add an evade cooldown and limit the distance. A chicken should resist just enough to feel alive, then offer a fair catching opportunity.

### 23. Avoid impossible destinations

Evade targets must remain on valid ground, within the chicken's allowed region and away from unrecoverable edges, geometry traps or inaccessible W positions.

### 24. Separate loose and penned behaviour

Penned chickens should wander calmly within the pen and stop using the escape response. They may cluck, idle or approach the coop but must not attempt to leave.

### 25. Expose debug state information

Provide a temporary debug option that shows each chicken's identity, state, W assignment and whether it has been counted. Make it easy to disable for the presentation build.

## Phase 04: Catch, carry, drop and throw interaction

The interaction should evoke Ocarina of Time: close the distance, catch the Cucco-like chicken, carry it visibly above the character, and bring or throw it into the pen.

### 26. Define a forgiving catch candidate

Select a loose chicken within a short distance and reasonable forward angle. Prefer the best valid candidate rather than requiring pixel-perfect aiming.

### 27. Show a clear catch prompt

Display a small contextual prompt only when a chicken is genuinely catchable. Hide it immediately when the chicken escapes, leaves range or changes state.

### 28. Make the catch response immediate

On input, lock the selected chicken, stop its wandering and transition cleanly into the carried state with a short sound and readable wing response.

### 29. Attach the chicken above the player's head

Use a dedicated carry anchor on the third-person rig. Align the chicken clearly above the head, preserving the intended right-wing orientation cue and avoiding clipping into the character.

### 30. Give the carried chicken a living pose

Use a suitable existing animation or a light carried motion so the wings or feet move subtly. Avoid a rigid frozen prop if the current rig supports better.

### 31. Define movement while carrying

Keep walking, turning and W navigation available unless the existing controller requires a safer limitation. The carried chicken must follow reliably through ordinary movement and slice changes.

### 32. Support drop and gentle throw

Provide a predictable drop or short throw. The trajectory should be strong enough to clear the low pen fence without becoming a physics weapon or sending chickens beyond the playable area.

### 33. Handle landing cleanly

After a throw, return the chicken to loose behaviour on valid ground or to penned behaviour if it enters the return area. Prevent repeated bouncing, tunnelling or permanent airborne states.

### 34. Carry only one chicken

Block additional catches while the player is already carrying one. Make the occupied state obvious in both input handling and UI.

### 35. Decide how returned chickens can be reused

The original Ocarina quest allows Link to take a returned Cucco back out and use it for gliding. For this prototype, default to non-catchable penned chickens to protect the collection loop. If the existing controller makes Cucco-style gliding valuable and low-risk, implement it as a clearly isolated optional feature or toggle rather than a hidden dependency.

## Phase 05: Procedural pen fence and return volume

The fence is part of the original interaction, not decoration. It is the physical and visual collection goal, and it must be easy to resize numerically from the Inspector.

### 36. Create a reusable procedural fence

Build the pen fence as a reusable scene or tool-driven component. It should generate repeated posts and rails instead of stretching one mesh.

### 37. Expose numeric dimensions in the Inspector

Allow the pen to be resized simply by entering values. Support overall width and depth, or preferably per-side extension when that makes directional editing clearer.

- Positive and negative X extension
- Positive and negative Z extension
- Fence height
- Post spacing and rail count or spacing
- Optional gate side, position and width

### 38. Rebuild without visual stretching

When dimensions change, add, remove or reposition modular segments. Keep post proportions, rail thickness and spacing credible at every supported size.

### 39. Update collision with geometry

Fence collision must regenerate with the visual fence so the player and chickens cannot pass through outdated boundaries.

### 40. Generate the return area from the same parameters

The chicken-return detection volume must automatically match the pen interior when the fence dimensions change. Do not maintain a second manually sized box that can drift out of sync.

### 41. Keep the fence low and readable

The player must see the collected chickens and easily throw a chicken over the fence. The fence should contain chickens without visually hiding the progress state.

### 42. Provide enough usable interior area

Default dimensions should comfortably support twelve independently wandering chickens, the coop and clear landing space without constant crowding or collision jitter.

### 43. Register a return only once

When an eligible chicken enters the pen, mark its unique returned state, increment progress exactly once and remove it from locator targeting. Re-entry must never duplicate the count.

### 44. Keep returned chickens contained

Penned behaviour should select destinations within the generated interior bounds. If a chicken somehow leaves, return it safely without changing the score.

## Phase 06: Functional chicken house design

Design a recognisable low-poly coop for this prototype. It should strengthen the pen as a destination and support chicken behaviour without becoming an art-production detour.

### 45. Design the coop rather than using a generic cube

Create a simple chicken house with a readable enclosed body, roof, chicken-sized opening and a short ramp or steps.

### 46. Keep it compatible with the existing style

Use clean low-poly forms and simple materials. Prioritise silhouette, scale and functional readability over texture detail or decorative polish.

### 47. Place it at the back of the pen

Do not block the player's view of the collected chickens or the main throw area. Leave open interior space in front of it.

### 48. Add optional chicken interest points

If inexpensive, place a few valid idle targets near the ramp or entrance so penned chickens occasionally relate to the house. Do not require full interior navigation for the first prototype.

### 49. Make practical dimensions editable

Expose useful scale or size parameters if the design benefits from them, but do not proceduralise every decorative piece. The fence requires full numeric resizing; the coop only needs enough flexibility to fit the pen reliably.

## Phase 07: W-locator, hiding and discovery

This section describes the intended player understanding, not a rigid UI implementation. Claude has more direct insight into how the existing Shooting Range was built and should use that knowledge.

> **LOCATOR DESIGN AUTHORITY**
>
> First inspect and play the current Quantum Range / Shooting Gallery prototype. Reuse its working target-location logic, UI language, bearing behaviour and any proven feedback patterns where appropriate. The suggestions below are a starting hypothesis. Claude may invent a clearer locator, a better target-selection model, or a better capture interaction after seeing the real implementation. Preserve the outcome: players must understand that a chicken exists outside their current visible slice, know how to move or rotate toward it, and recognise when it becomes catchable.

### 50. Inspect the existing Shooting Range before designing

Identify how that prototype represents targets that leave the visible slice, how it computes target bearing, how the UI updates and which parts can be reused safely.

### 51. Define the locator's minimum information

The player needs enough feedback to understand ordinary direction, W direction and whether alignment is improving. Avoid showing unrelated technical data.

### 52. Use a two-part cue if it fits the existing system

One plausible design is an ordinary spatial direction arrow plus a W indicator showing whether the target lies toward Ana or Kata. A centred or locked state signals slice alignment. Use a different design if the Range already solves this more elegantly.

### 53. Communicate signal strength

Let the device become clearer as the player approaches the correct W relationship. Possible cues include pulse rate, colour, bar centring, distance simplification or increasing audio clarity.

### 54. Use chicken audio as supporting guidance

Faint clucking can help the player search. It should become clearer or more present as alignment improves, without replacing the visual explanation entirely.

### 55. Consider partial visual reveal

Near the correct slice, a brief silhouette, shimmer or intermittent glimpse may help players connect the locator reading to the chicken's arrival. Only use this if it matches the engine's slice presentation and remains visually stable.

### 56. Choose stable target selection

The simplest default is to track the nearest eligible loose chicken. Prevent rapid switching when two chickens are similarly close. If the Range already supports deliberate cycling or locking more clearly, reuse that instead.

### 57. Exclude invalid targets

Never select a carried, penned, unrecoverable or already completed chicken. The locator should immediately move to a useful remaining target after a successful return.

### 58. Do not make the locator an autopilot

Guide the player toward the spatial problem but leave enough interpretation to make W-search meaningful. Avoid a giant exact world marker that removes all discovery unless testing shows it is needed for comprehension.

### 59. Author a readable twelve-chicken progression

Use placement to teach the mechanic rather than hiding chickens arbitrarily.

- Three introductory chickens visible in or near the starting slice
- Three chickens found through ordinary XYZ exploration
- Four chickens meaningfully offset in W and found with the locator
- Two later chickens combining W search with a simple obstacle, height change or route decision

### 60. Keep early W discoveries close

The first off-slice chicken should require only a small, unmistakable adjustment so the player quickly learns what the locator means.

### 61. Increase complexity one variable at a time

Teach W offset before combining it with ordinary distance, occlusion, elevation or a moving chicken. Do not make the player's first W search solve several uncertainties at once.

### 62. Preserve designed hiding relationships

Chickens should not randomly wander so far that a W lesson becomes an unrelated chase. Use bounded movement around authored positions.

### 63. Make slice alignment legible

When the chicken becomes fully present and catchable, give a decisive locator response such as a lock tone, centred indicator or state change. The player should not wonder whether the device has succeeded.

### 64. Resolve carried-chicken W behaviour

A caught chicken must remain visibly attached through the player's W movement. When returned, it should occupy the pen's valid W relationship rather than snapping away or disappearing.

### 65. Allow superior repo-specific solutions

If inspection reveals that the Shooting Range uses a different conceptual model, Claude may replace these UI suggestions with a clearer implementation. Likewise, Claude may improve the catch method if the existing player controller supports something more natural. Explain the choice and keep the interaction simple.

### 66. Test comprehension, not only correctness

Run the locator from a cold start and verify that a player can infer which action changes the W relationship. A technically accurate indicator that no one understands is not sufficient.

## Phase 08: Objective flow, feedback and completion

The prototype needs a complete beginning, middle and end even if the presentation and world art remain minimal.

### 67. Create a clear start state

Begin near the pen with a short objective message, sign or lightweight chicken-keeper placeholder. State that twelve chickens are loose and must be returned.

### 68. Teach only the essential controls

Introduce locate, W adjustment, catch, carry and throw/drop at the moment each first becomes relevant. Avoid a large technical tutorial panel.

### 69. Show persistent progress

Display a restrained counter such as **Chickens returned: 5/12**. Keep it readable without dominating the locator.

### 70. Confirm each return

On a valid deposit, play a short sound, update the counter and briefly acknowledge the successful chicken. The feedback should happen immediately.

### 71. Avoid a timer in the default mode

This prototype is primarily about spatial comprehension and a playful collection loop. Do not add time pressure unless it becomes an optional later benchmark.

### 72. Create a clear completion event

At 12/12, stop active locator guidance, show a concise completion message and trigger a small sound or collective chicken response. No elaborate reward system is required.

### 73. Provide restart and replay

Allow the minigame to reset cleanly: restore all chickens to their authored starting states, clear progress and reactivate the locator without requiring an editor restart.

### 74. Keep the presentation prototype-focused

Use clear materials, readable contrast and functional shapes. Do not spend implementation time on environmental decoration that does not improve locating, catching, carrying or returning chickens.

## Phase 09: Robustness, recovery and optimisation

Twelve autonomous actors, 4D visibility and throw physics create edge cases. Handle the failures that would undermine a live demonstration.

### 75. Give every chicken a stable identity

Use unique IDs or an equivalent reliable mechanism so progress, locator exclusion and recovery never depend on scene-tree order or display names alone.

### 76. Detect invalid positions

Recover chickens that fall below the world, leave authorised bounds, become stuck for too long or enter an impossible state. Return them to a valid home or recent safe position.

### 77. Protect against duplicate input

Catch, drop, throw and return events should be idempotent enough to survive rapid button presses, repeated area signals and low-frame-rate timing.

### 78. Prevent pen overcrowding failures

Ensure twelve penned chickens can wander without explosive collision forces, permanent stacking or blocking the deposit area. Simplify chicken-to-chicken collision if needed.

### 79. Avoid unnecessary per-frame work

Reuse the existing efficient patterns. Do not make every chicken perform expensive searches each frame. Stagger low-priority decisions or reduce update frequency at distance when appropriate.

### 80. Optimise after measuring

Compare the complete prototype against the baseline checkpoint. Address demonstrated costs in AI, collision, locator queries or procedural regeneration rather than rewriting speculatively.

### 81. Keep debug controls available

Provide temporary tools to teleport or reset a chicken, mark all W targets, resize the pen and force states. Make them easy to disable for the final demo.

### 82. Fail visibly during development

Use clear warnings for missing chicken assets, invalid pen dimensions, absent carry anchors and unassigned locator targets. Silent failure will make later iteration much slower.

## Phase 10: Verification and delivery report

Do not consider the task complete because the scene runs once. Verify the whole loop and report what was built, changed and deliberately deferred.

### 83. Verify the source scenes remain intact

Confirm that the finished third-person rig scene and the original animated chicken source have not been accidentally overwritten or broken.

### 84. Verify the new scene launches directly

Open chickenpen.tscn from a clean project state and confirm there are no missing dependencies, script errors or required manual editor steps.

### 85. Verify all twelve chickens

Each chicken must spawn, wander, react, become catchable, carry correctly, survive W navigation, enter the pen and count exactly once.

### 86. Verify the locator across all placements

Every loose off-slice chicken must be discoverable. The locator must not target returned chickens, oscillate uncontrollably or point to an unrecoverable state.

### 87. Verify procedural fence parameters

Change the dimensions numerically in several directions. Confirm geometry, post distribution, rails, collision, return area and chicken containment all update together.

### 88. Verify the orientation cue

Check the red spot remains on the right wing, is readable in relevant poses and helps rather than confuses orientation.

### 89. Verify the full objective loop

Complete a normal playthrough from 0/12 to 12/12, then restart and complete enough of a second run to prove reset reliability.

### 90. Report implementation decisions

At handoff, provide a concise summary of files created or changed, controls, Inspector parameters, locator approach, chicken placement logic, tests performed, known limitations and any deviations from this brief.

## Definition of done

A player can enter chickenpen.tscn, understand the objective, use a readable W-location method, catch and carry each of twelve chickens, throw or drop them into a resizable fenced pen, watch the pen fill, reach a reliable 12/12 completion state, and restart. The original rig and chicken work remain safe, the coop and environment are functionally designed, and the build is stable enough for a live prototype demonstration.
