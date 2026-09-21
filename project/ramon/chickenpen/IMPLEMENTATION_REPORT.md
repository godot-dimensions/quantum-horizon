# 4D Chicken Pen — implementation report

Item 90. What was built, how it works, what was tested, and what is still wrong.

Scene: `project/ramon/chickenpen/chickenpen.tscn`. Run it directly; nothing else is needed.

---

## Controls

| Key | Does |
|---|---|
| WASD | Move |
| Mouse | Look (orbit camera) |
| **E / Q** | **Ana / kata — move through the fourth axis.** This is the one that reaches off-slice chickens |
| Right mouse + move | Slice-rotate the *view*. Changes what you see, not where you are |
| F | Catch, and throw what you are holding |
| Mouse 1 | Put down what you are holding, where you stand |
| Space | Jump |
| Shift / Alt | Sprint / walk |
| Ctrl+R | Restart |
| 0–7 | Debug tools, `0` switches them off (see below) |

Every key the game names on screen is read from the InputMap, so rebinding updates the
advice instead of invalidating it.

## Debug tools (item 81)

`Systems/Debug`, `enabled` in the Inspector. Number row only, so nothing collides with
play. `1` bring the target chicken to you, `2` teleport to it, `3` mark every W target,
`4`/`5` shrink and grow the pen, `6` scatter them all again, `7` deliver all twelve, `0`
switch the whole thing off — which stops its processing and its input, not just its
display.

---

## Files

**New, in `project/ramon/chickenpen/`**

| File | Role |
|---|---|
| `chickenpen.tscn` | The scene |
| `chicken.tscn` | One chicken, extracted from `rigged_creature_ramon.tscn` |
| `scripts/chicken_manager_4d.gd` | Spawns twelve, owns the placement table and the count |
| `scripts/chicken_agent_4d.gd` | Per-chicken state, containment, recovery |
| `scripts/chicken_catcher_4d.gd` | Catch, carry, throw, put down |
| `scripts/chicken_locator_4d.gd` | Where the next chicken is, and which way through W |
| `scripts/chicken_cues_4d.gd` | Clucking and the near-slice glimpse |
| `scripts/pen_fence_4d.gd` | Procedural fence, collision and interior bounds |
| `scripts/pen_coop_4d.gd` | The coop |
| `scripts/pen_return_4d.gd` | Decides when a chicken counts as returned |
| `scripts/pen_tutor_4d.gd` | Teaches move and the W axis, one hint at a time |
| `scripts/pen_debug_4d.gd` | Development tools |
| `scripts/chickenpen_game_4d.gd` | Wires it together, progress, completion, restart |
| `scripts/follow_node_4d.gd` | Makes the feet follow a loft ball that hides itself at runtime |
| `scripts/pen_orbit_rig_4d.gd`, `block_*.gd` | Third-person rig, avatar and gait, from the earlier controller work |

**Changed outside this folder**

- `project/ramon/Model/scripts/chicken_walker.gd` — separation steering now still applies
  while something else is steering the bird. Without it twelve penned chickens stacked.
- `project/project.godot` — input actions only.

**Untouched, and verified untouched:** `rigged_creature_ramon.tscn`,
`chickenpen_proceduralwalker.tscn`, and everything under `project/sandbox/shooting_gallery/`
(item 83; the Shooting Range was read for item 50 and never written to).

---

## How the locator works

Built on the Shooting Range's `project/scripts/bearing_utility_4d.gd` rather than beside
it (items 50, 65), which means it inherits that file's documented fix: read the **player
body**, never the camera, because pitch lives on the head node and would otherwise fold
vertical look into a horizontal answer.

It reports four things and nothing else: a direction, a distance in words, a five-bar
strength, and which way through W. When the chicken is within `lock_angle` of the player's
slice it changes state to `LOCKED … in your slice - catchable` — a different thing to read,
not a better number (item 63). It never gives coordinates and never marks a chicken at
range, because the search is the mechanic (item 58).

Two supporting cues, both driven by the same alignment number so they cannot disagree:

- **Clucking** that gets faster and louder as you align, carrying no direction at all, so
  it cannot replace the visual explanation (item 54).
- **A glimpse** — a 4D orthoplex above each chicken whose W half-extent is the reveal band.
  A cross-section of an orthoplex at distance *d* from its centre is the same shape scaled
  by `(1 − |d| / h)`, so the marker grows out of nothing as you move into the chicken's
  slice and vanishes to a point on the way out. The engine does the fade; there is no alpha
  in `TetraMaterial4D` to fake one with. It is suppressed for chickens already in your
  slice, so it marks only what you cannot yet see (items 55, 58).

## Chicken placement

`PLACEMENTS` in `chicken_manager_4d.gd` is a teaching order, not a scatter (item 59):

- **1–3** near the start, in plain sight — these teach catching.
- **4–6** ordinary distance at w = 0 — these teach searching.
- **7–10** offset through W, nearest first, starting at w = 0.9 right beside where you
  begin — standing next to a chicken you cannot see is a sharper first lesson than a
  distant one (item 60).
- **11–12** W offset *and* distance, so only one variable is new at a time (item 61).

Each bird wanders inside an authored radius and is held far tighter through W, so a W
lesson never turns into an unrelated chase (item 62).

## Inspector parameters worth knowing

- **Fence** — four per-side extents, height, post spacing, rail count, thicknesses,
  `w_depth`, and a gate side/position/width. Everything else derives from these, including
  the collision and the return volume: there is no second box to drift (item 40).
- **Coop** — body size, roof rise, doorway, ramp, stilt height.
- **Catcher** — `catch_distance` 1.6, `catch_angle_degrees` 110, `catch_w_tolerance` 0.25,
  throw speed and rise.
- **Agent** — wander radius, W leash, idle and wander durations, and the recovery limits
  (`lost_below_y`, `lost_distance`, `stuck_seconds`, `stuck_travel`).
- **Cues** — cluck intervals and levels, `reveal_band`, `reveal_distance`, `present_band`.
- **Character** — `w_speed_scale` 0.3: the fourth axis moves at a third of walking pace.

---

## Tests

All headless runners in `scripts/`, plus one that renders.

| Runner | Covers |
|---|---|
| `_verify_comprehension_runner.gd` | Reads the screen, presses the key it names, reaches LOCKED (item 66) |
| `_verify_locator_runner.gd` | Target choice, ana/kata advice, strength, exclusion (51–57) |
| `_verify_return_w_runner.gd` | A delivered chicken eases onto the pen slice, counted once (43, 64) |
| `_verify_flow_runner.gd` | Start state, hint order, first return, completion, restart (67–74) |
| `_verify_recovery_runner.gd` | Four ways to lose a chicken, 20 rapid presses, twelve in the pen (76–78) |
| `_verify_debug_runner.gd` | Every debug key, and that the off switch really is off (81, 82) |
| `_verify_phase10_runner.gd` | All twelve end to end, locator across all placements, fence at four sizes, the wing mark, the full loop and a restart (85–89) |
| `_profile_pen_runner.gd` | Cost of each system against the baseline scene (79, 80) |
| `_playthrough_runner.gd` | Renders a real playthrough to PNGs using the actual controls |

**Performance.** 2.44 ms of script time per frame against a 16.7 ms budget at 60 fps; the
baseline scene this was copied from costs 0.33 ms. The walkers' IK and skinning are about
0.08 ms per chicken; the agents, the locator and the return checks are all near the noise.

Two measurement traps are worth repeating, because both produced confident wrong answers
first: headless frame time here is **paced at exactly 6.900 ms** whatever the scene does,
so wall-clock frame timing reports every system as free; and a single pass through the
configurations measures what the flock happens to be doing, not the code.

---

## Found by playing it

Five bugs only appeared once the prototype was driven through a captured playthrough.
Every one of them passed the headless tests.

1. **W moved at run speed.** A short press of the ana key went from w 0 to w 5.9 — past
   every chicken in the game. Now a third of walking pace.
2. **The catch cone pointed backwards.** `Basis4D.looking_at` documents −Z as forward; the
   catcher used +Z, so walking up to a chicken and pressing the key did nothing.
3. **And it read the wrong node.** The player body never turns — only the avatar does — so
   "in front of you" meant "north of you", whichever way you were facing.
4. **You could catch a chicken you could not see.** Catch range was a plain 4D distance, so
   0.9 through W plus 1.2 across the ground came under the 1.6 reach. That made the phase
   step optional and the locator a liar.
5. **The fence vanished off-slice while still blocking you.** Its meshes were as thin
   through W as they were thick; only the collision used `w_depth`.

Three more came from the headless tests: chicken 7 spawned inside the pen and was counted
on frame one; the rails were one stretched box per side while the posts multiplied
correctly; and `chicken.tscn` lost every `live_rebuild = false` when it was extracted, so
all twelve chickens re-checked their loft every frame.

---

## Known limitations

- **The chicken loft folds slightly.** Roughly 22 of 2300 tetrahedra on the neck face
  inwards, a warning inherited from the source model, not introduced here. It does not
  show at this size.
- **No audio assets.** The cluck, the return chirp and the completion chorus are
  synthesised at load, because there is no chicken audio in `ramon/sounds/`. They are
  functional, not good.
- **The keeper and the sign are placeholders**, and the keeper is the player avatar in
  different colours.
- **A wedged chicken takes 8–16 seconds to recover.** The window already running when it
  got stuck still holds the walking it did beforehand, so only the next clean window trips.
- **Throws are scripted arcs, not physics.** Deliberate (item 33), but a chicken thrown at
  a fence post passes through the rails rather than bouncing off them.
- **The walk still has bent knees.** Carried over from before the brief; flagged as
  not-most-important at the time and not revisited.

## Deviations from the brief

- **Item 13 — competing red marks.** The chicken already had a red comb and wattle. They
  are anatomically red and sit on the *head*, which is a facing cue rather than a chirality
  cue, so they do not compete with the wing mark's job of telling left from right. Kept.
- **Item 55 — the partial reveal is real geometry.** The brief allows a shimmer only if it
  matches the engine's slice presentation. `TetraMaterial4D` has no transparency, so
  instead of faking one the marker is a 4D shape whose own cross-section does the fading.
- **Item 65 — the locator names this scene's control, not the Range's.** The Range moves
  through W by slice-rotating the player body; here the camera rig owns slice rotation and
  the body translates on ana/kata. Following the Range's wording would have told the player
  to use a control that cannot reach an off-slice chicken.
