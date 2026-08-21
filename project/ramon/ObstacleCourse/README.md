# The 4D Ascent

A vertical obstacle course built to the `4D_Ascent_Prototype_Level_Brief` — one
compact tower, three tiers, one 4D verb.

**Status: Phase 1 (greybox shell) complete and verified, in two separate scenes.**
Both are walkable end to end using ordinary 3D movement. No obstacle beat is
implemented yet; the stairs are deliberate scaffolding.

| Scene | Layout | Built from |
| --- | --- | --- |
| `ascent_wall.tscn` | **the brief's own elevation** — bounded tower, tier-coloured back wall, route zigzagging left/right across a central spine | the brief's page 5 drawing |
| `ascent.tscn` | a helix — decks spiralling around a spine in open void | the brief's TEXT, before the diagrams had been read |

They share nothing but the palette and the material helper — two independent
builders, resource types and bay/station catalogues. They are genuinely different
bets on how a vertical 4D course stays legible and only a playtest settles it.

**`ascent_wall.tscn` is the faithful one.** The helix was built before the PDF's
diagrams had ever been rendered, from extracted text alone; page 5 turned out to
draw something quite different, and the wall course is that drawing. The helix is
kept because a spiral around a spine is a real alternative, not because it was
right.

## Phase 0: what the engine audit changed

`_audit_probe.gd` measured the engine before anything was designed, because
several of the brief's preferred implementations turn out to be unavailable. Run
it with the editor closed:

```bash
engine/godot/bin/godot.windows.editor.double.x86_64.console.exe --headless --path project --script res://ramon/ObstacleCourse/_audit_probe.gd
```

| Capability | Status | Measured evidence |
| --- | --- | --- |
| 4D box collider | SUPPORTED | `BoxShape4D` + `StaticBody4D` |
| Rotated boxes | **ABSENT** | AABB inflates ×1.225 at 15°, ×1.414 at 45° zw |
| Kinematic W motion | SUPPORTED | bounds track a w-translation exactly; rects rebuilt every physics frame |
| Player carry | **ABSENT** | obstacle velocity is subtracted only for `CharacterBody4D`/`RigidBody4D` |
| Slice-transition safety | **NON-ISSUE** | player capsule AABB drift under zw rotation is **0.000000** at every angle |
| Compound boxes | SUPPORTED | per-body shape arrays iterated pairwise |
| Slopes / ramps | **ABSENT** | AABB normals are axis-aligned only; no step-up logic anywhere |
| Triggers | SUPPORTED | `Area4D.body_entered_self` |
| Curved primitives | VISUAL-ONLY | cylinder/sphere/capsule `to_tetra_mesh` → null; cubinder has **0 UVW** entries |

**Branch B** (axis-aligned boxes only). Four consequences shape everything here:

1. **Nothing is ever rotated.** A rotated collider no longer matches what is
   drawn, so the course is built entirely from axis-aligned boxes.
2. **There are no ramps, and cannot be.** Height is gained by steps only.
3. **Steps are capped at 0.8 m** against a measured jump apex of **1.033 m**.
   There is no step-up logic at all, so every rise is cleared by jumping.
4. **Moving platforms cannot carry the player**, and there is no depenetration
   either — the engine comments *"For now, just stop moving"*, so a platform that
   materialises inside the player **sticks** it. Beats 04 and 08 must use the
   brief's static-state fallbacks, which are the only implementation, not a
   safety net.

## Where this deviates from the brief, and why

**Slice pads are gone.** The brief gates rotation behind marked pads with a
0.35–0.55 s freeze, a validation volume and a VALID/BLOCKED check. All of it
exists to keep collision valid mid-rotation — a problem this engine does not
have. Physics here is genuinely 4D at all times and completely independent of
the camera slice, and the player capsule was *measured* to be rotation-invariant.
Rotating can never shove the player into geometry. Rotation is therefore free,
anywhere, as it already is everywhere else in this project.

The corollary matters more: **rotating alone never traverses anything.** The verb
is *rotate to see where w leads, then translate along w* (`move_ana`/`move_kata`,
or walking forward once your basis maps forward onto w).

**Sprint is to be disabled in this level.** Measured reach: walk-jump **4.59 m**,
sprint-jump **11.48 m**. The brief's 8 m "extending bridge" gap is trivially
cleared at a sprint with no 4D thinking at all, which would defeat the
comprehension acceptance test. Not yet implemented — Phase 2.

**Recovery floors are local, and white-tier only.** The first build gave every
station a full-span slab 3 m below it. A top-down render showed the result
immediately: ten opaque 30 m ceilings stacked up the tower, burying the brief's
own "vertical spectacle comes from seeing the tower above", and overlapping the
decks below since consecutive stations are only 2–5 m apart.

Page 7 is more specific than the text alone suggested — *"Every gap has a visible
recovery floor no more than one jump-height below"*, listed under **white tier
restrictions**. So the wall course puts a slab spanning each white-tier gap one
jump-height (1.03 m) under it, climbable straight back out of, and leaves yellow
and red to carry real risk. Falls that miss everything are caught by an invisible
`Area4D` reset plane per tier, which catches without becoming a ceiling.

## The white-artifact bug, and the check that now catches it

A "full white wall clipping objects" was reported in `ascent_wall.tscn`. It was
**three separate faults** wearing one symptom, and none of them were material
bugs:

1. **Coincident solids.** `_build_ground` placed the tower floor spanning
   y −0.5…0. Bay 00 is authored at height 0, so its deck spanned y −0.5…0 too —
   perfectly co-volumetric. The flat cross-section shader has no depth bias, so
   an overlap that would be a mild z-fight in an ordinary 3D engine renders as
   solid white patches punching through everything. The ground is now a plinth
   one slab *below* the bays.
2. **A sign error.** Gap-recovery slabs used `low - JUMP_APEX + slab_thickness`,
   riding each slab 0.22 m up *into* the deck it sits under. Now
   `low - JUMP_APEX - slab_thickness * 0.5`, so its top lands exactly one
   jump-height below the walking surface.
3. **Exposure blowout.** Ambient 0.62 plus a 0.9 sun on white 0.88-albedo
   horizontal faces exceeded 1.0, clipping **4.3% of the frame to exactly
   (255,255,255)** and washing the grid off every white top. Retuned to sun 0.45
   / exposure 0.90 / ambient 0.62 — measured at 0.02% clipped, with mid-tones
   slightly *brighter* than before.

Two more latent overlaps surfaced while fixing these: every stair flight's final
step landed at exactly the destination deck's height and duplicated its slab
(both courses had this), and recovery slabs intersected the stairs of the beat
below. The recovery floor is now built only once a beat's scaffolding is retired
— which is also the honest rule, since a gap you cannot fall into needs no floor.

`_verify_ascent.gd` now has an **interpenetration check** that catches all of
this from the tree. It is the cheapest possible guard against the most expensive
class of artifact here, and it should have existed before the first render.

## Step-up: the course is WALKED, not jumped

`CharacterBody4D` has no step-up logic — `_snap_distance` is 0.1 m and there is
nothing else — so a 1 cm lip stops you dead and **every** rise has to be jumped
onto a landing. That single fact made the first two greyboxes hostile, and no
amount of tread tuning fixes it: a switchback at this scale always puts step N+2
directly above step N, and getting 1.75 m of headroom there needs rises above
1.1 m, taller than the 1.033 m jump apex. The constraints have no solution.

**Step-up is implementable project-side**, which dissolves the whole problem.
`ascent_player.tscn` / `ascent_player_4d.gd` fork the shared controller and add
it. Measured: 0.30 m and 0.60 m ledges are walked straight over, a 0.90 m ledge
is correctly refused against the 0.70 m allowance, and with step-up off the same
ledges block. Stairs are now straight flights of **0.35 m rises with 0.8 m
treads** that you simply walk up.

**The trap that cost the most time here, worth knowing for any future physics
code:** the lift must go through `move_and_collide`, never a direct `position`
write. `AxisAlignedBoxPhysicsEngine4D` caches every body's AABB in
`_area_and_body_rects` for the whole physics frame and only recomputes it when a
body's shape *count* changes — so after assigning `position`, every later test
that frame still sees the body's **old** rect. An obviously clear step-up tested
as blocked **148 times out of 148**. A real `move_and_collide` writes the updated
rect back and the next test sees it.

The fork also **removes sprint** (measured 11.48 m sprint-jump reach against the
brief's 8 m gaps would let a tester finish without ever using W).

## On ramps, and rotating through W

Both ideas were measured rather than argued about, in `_ramp_probe.gd`:

- **Rotating a box in ZW cannot make a ramp.** Its y extent is *unchanged at
  every angle* — the rotation only trades z-extent against w-extent, and the
  visible cross-section stays an axis-aligned box. It is a fine mechanic for
  slice-dependent geometry (it is essentially beat 05's extending bridge), but it
  can never tilt or raise a surface.
- **Rotating in a spatial plane (YZ) does tilt the mesh**, but the collider
  inflates: y grows **×5.11 at 15°** and **×12.02 at 45°**. Walking into a
  "ramp" is walking into a tall box.

So a visible ramp has to be a tilted mesh with real, axis-aligned collision
underneath it — and with step-up in place, that collision can be a fine
staircase the player never notices. That is the route to actual ramps whenever
the greybox stairs are worth replacing.

## Stairs: an earlier dead end (switchbacks)

A playtest reported "controls are buggy, sometimes stops" and "hard to get on the
first jumpable part". One geometry defect caused both. Measured across the nine
flights, **seven advanced less than one step footprint per step** — the worst at
**0.17 m of advance against a 2.0 m tread**. Consecutive treads therefore
overlapped in plan, putting the next step's underside **0.3 m above your feet,
directly where you had to stand**. Not hard: impossible, and it reads in play as
the controller sticking rather than as a level bug.

The constraint behind it: `CharacterBody4D` has **no step-up logic**, so every
rise is a jump onto a landing, and a straight flight cannot give both a low rise
and a wide tread in the 5–8 m between bays. Real staircases answer this with
switchbacks, so the flights now alternate sides in z — buying distance between
treads out of the tower's depth rather than its width.

Final numbers, tuned against simulation rather than by eye: **0.6 m rise, 1.3 m
tread, 0.7 m zigzag throw**, giving ~1.7 m between consecutive treads. Bays were
also re-spaced so every flight has the run to hold a staircase at all.
`_verify_ascent.gd` now fails if any flight advances less than one footprint per
step.

## Climb probe — partial, do not trust yet

`_climb_probe.gd` drives the real `CharacterBody4D` with the real constants
through the real `move_and_slide()`, walking every tread in order. The intent is
to answer "can this actually be climbed" without a human.

**It does not yet give a clean verdict.** It reports treads unreachable that a
human very likely clears, and its failures track its own approach-and-jump
heuristic more than the geometry. What it *has* established, by direct
measurement, is that the physics is sound: the player bounces 0.96 → 1.94 m, a
clean 0.94 m jump against the 1.033 m theoretical apex, so nothing is wrong with
jumping itself. Treat the probe as a work in progress and the editor as the
arbiter until it can complete a course it should be able to complete.

## The one idea in the wall course

**The back wall is the HUD.** Three tier-coloured bands, visible from anywhere in
the tower, answer "which tier am I in" with no screen-space UI at all. That is
why the tower is bounded rather than floating in a void, and why the wall earns
its geometry. The spine is thin in X and broad in Z — the route crosses left and
right past it, so width in X would block the very traverse it exists to
reference, while depth in Z keeps it present from every bay.

## The one idea in both

**The course is a list, not a layout.** `ascent.tscn` contains no decks and no
stairs. It contains a `Course` node holding an array of `AscentStationDef4D`
resources from `stations/`, and everything visible is generated from that array.

- In the wall course, **plan positions are authored** — page 5 is a drawing, not
  a curve, and which side of the spine a beat sits on is the substance of that
  beat. In the helix, **heights are authored and bearings derived**, so inserting
  a beat re-spaces every other one.
- **Generated nodes are not owned by the scene**, so nothing is serialised into
  `ascent.tscn`. `_verify_ascent.gd` asserts it.
- **`suppress_phase1_stair` retires the scaffolding one beat at a time**, so the
  course stays finishable at every commit — which is the whole point of the
  brief's gated build order.

## Colour

Sampled from `res://textures/dev_finals/ramdev_*.png` by `hub_palette.gd`, shared
with the Demo hub. `ramdev_cyan.png` and `ramdev_violet.png` were generated to
match the existing grid style — edit them to retint the course.

| Colour | Means |
| --- | --- |
| white / yellow / red | tier 1 / 2 / 3 — **tier only, never anything spatial** |
| grey | the invariant spine, and Phase 1 scaffolding |
| cyan | correctly here: checkpoints now, the goal when its alignment is valid |
| violet | w-language — marks geometry with w-extent worth rotating into |
| black | hazard and void trim |

Tier colour deliberately encodes nothing spatial. The brief's own kill criteria
fire if testers start reading tier colour as a W cue, so W meaning is carried
entirely by cyan/violet, by patterns and by labels.

## Files

| Path | What |
| --- | --- |
| `ascent_wall.tscn` | **the brief-faithful course** |
| `bays/bay00..09.tres` | its ten bays, plan positions read off page 5 |
| `scripts/ascent_wall_builder_4d.gd` | tower shell, tier bands, spine, bays, W markers, gap recovery |
| `scripts/ascent_bay_def.gd` | the `AscentBayDef4D` resource type |
| `ascent.tscn` | the helix course |
| `stations/station00..09.tres` | its ten stations |
| `scripts/ascent_builder_4d.gd` | spine, decks, stairs, checkpoints, reset planes |
| `scripts/ascent_station_def.gd` | the `AscentStationDef4D` resource type |
| `scripts/ascent_checkpoints_4d.gd` | respawn, falls, telemetry |
| `_audit_probe.gd` | the Phase 0 capability measurements |
| `_verify_ascent.gd` | headless structural check |
| `_shot.gd` | renders the tower from an arbitrary eye/target |

## Verifying

Editor **closed** — two Godot processes on one `.godot` cache silently breaks
`@tool` buttons in the running editor.

```bash
engine/godot/bin/godot.windows.editor.double.x86_64.console.exe --headless --path project --script res://ramon/ObstacleCourse/_verify_ascent.gd -- ascent_wall.tscn
```

Pass `ascent.tscn` instead for the helix course; both pass.

Checks the scene loads, the spine and all decks generate, nothing generated is
owned by the scene, **every step rise is below the measured jump apex**, three
checkpoints exist and are w-broad enough to catch a slice-shifted player, no
collider anywhere is rotated, and **no two solids interpenetrate** — coincident
boxes are the white-artifact bug above.

For a look rather than a check (needs a rendering device, so no `--headless`):

```bash
engine/godot/bin/godot.windows.editor.double.x86_64.console.exe --path project --script res://ramon/ObstacleCourse/_shot.gd -- ascent_wall.tscn wall_elevation.png 0 17 -48 0 0 17 0
```

Args: scene, output, eye x y z w, target x y z. Setting the eye's **w** re-shoots
the same framing from a different slice, which is how you check what appears and
disappears.

## Open questions

Headless proves structure only. These need a playtest:

1. **Does the 0.8 m step read as climbable**, or as a wall you happen to be able
   to jump? Every rise in the tower is at that height.
2. **Is a 3-turn helix over 34 m legible**, or does it disorient once slice
   rotation removes the usual navigation cues?
3. **Does the spine actually work as an invariant reference** from every deck, or
   does the tower need a second anchor higher up?
4. Sun angle, ambient level and sky colours are first guesses. Ambient is
   deliberately high (`ambient_light_sky_contribution = 0`) because the near-black
   sky left every deck underside unreadable from below, which killed the
   aspiration view.

## Reading the brief

The PDF is a *designed* document — page 5 draws the route, page 7 draws the S0/S1
gap, page 10 carries the palette swatches. Text extraction loses all of it, and
the helix course is what that loses looks like. Render the pages before trusting
any prose summary:

```bash
pdftoppm -png -r 110 "D:/depot/papers_forclaude/4D_Ascent_Prototype_Level_Brief_for_Claude.pdf" page
```

## Next (Phase 2)

Decide wall vs. helix, disable sprint in-level, then build the white tier's four
beats (00–03) against the affordance language rather than a HUD — violet marks
w-extent worth rotating into, cyan marks where you are correctly standing.
