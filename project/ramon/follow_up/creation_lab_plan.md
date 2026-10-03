# Creation Lab: the plan (v2, 3 Oct 2026)

Ramon: the Motion Lab becomes a Creation Lab that explains **building** (lofting) and
**animating** our 4D creatures in one scene, as the reference for a shared design kit. Bright
white dev look by default, a dark mood on a key, a bit sci-fi, a bit stylish, always an R&D lab.
He decided: one scene, the wolf as the hero, third person, lecterns with drawn text.

Version 1 of this plan was a ring of stations around a centre stage. **Ramon's concern: you see
everything at once, and nothing hand-holds you.** The Unreal tutorials walk you through one
step at a time. Version 2 is rebuilt around that: the explainer flow comes first, the space
follows.

Sketch: `follow_up/creation_lab_layout.png` (one bay from above, and the stack of bays along W).

## Questions for Ramon

Found while building. None blocks the lab; each is outside its scope, so nothing was changed.

1. **The cats' sit and wash may never show in the pen.** By the code they pose ball nodes after
   the hide has been cut into rigid pieces, and nothing re-lofts (`pen_cat_4d.gd`, `_tuck`,
   `_wash`). Shall I check it in the pen and fix it there?
2. **The wolf's and Nike's lofts have a few folded tetrahedra** (the wolf 7 of 1,656 on one
   chain; Nike up to 3% on two). Small, but the loft tool warns. Fixing means nudging balls in
   `Model/wolf.tscn` and `chickenpen/nike.tscn`, which the pen uses too. Shall I?
3. **Two older shader forks read wrong texture coordinates on today's engine.** Since godot-4d
   `b288c8d` (30 Sept) the engine packs corner UVWs into the bone weights; `Demo/shaders/
   hub_tiled_surface.gdshader` and `PhaseMaze/shaders/phase_maze_flat_shaded.gdshader` still
   read the old slots. Phase Maze is in the menu. Shall I bring them up to date (the kit's
   `lab_surface.gdshader` shows how)?
4. **`ramdev_dark_grey.png` imports as a 2D texture**, the rest of the set as 3D, so any code
   that loads it as a Texture3D gets nothing (the kit reads either). Change its import to 3D?
5. **The strider's `belt_speed` only counts in `_ready`.** Writing it later does nothing, so
   the cat's flee pace and the wolf raid's run speed never take effect in the pen (the lab
   writes `speed` instead). Fix it in `strider_walker.gd`?

## Status

Approved 3 Oct, evening; building from step 1.

### Sections A and B: done (3 Oct, night)

**Ground work.** `CreationLab/scripts/lab_run.sh` launches every Godot run: it checks and takes
the lock in the same process, logs to `smoke_test_output/creation_lab/logs/`, and greps the log
for errors (a deliberately broken script proved it catches parse errors). Runners: smoke,
capture (every mark in both moods), measure, verify-creature, filmstrip, measure-roster.

**One control surface over six drivers.** `LabKit/lab_clock_4d.gd` takes over an animal's whole
subtree and steps it in Godot's own order with a scaled delta: exact pause, slow motion and
frame steps for every animal without touching a single creature script. (Pulled forward from
step 50: every rig needs it.) `CreationLab/scripts/lab_creature_4d.gd` is the root of every
animal: card text, tether, and adapters for the strider, the chicken walker, Trym's solvers,
the birds, the dreamer, the people's walk and the first armature. Each animal passes a
headless control test (12 checks for walkers: the clock adopts it, phase rate, half speed,
exact pause, one-frame step, gait change keeping the phase, legs, belt, pieces; a pose test
for the rest, with flyers made to take off and kept over the rig's centre).

**The roster** (`CreationLab/creature_roster.tscn`, 17 animals, frames from three sides in both
moods): measured windowed, vsync off, 3 Oct. "Unique" counts a mesh shared by many instances
once, which is what video memory follows. Script ms is the animal's own stepping per frame at
60 Hz, timed by the lab clock.

| Animal | Drawn tetrahedra | Unique | Script ms |
|---|---|---|---|
| Wolf | 7,440 | 7,400 | 0.16 |
| Nike | 7,893 | 7,893 | 0.05 |
| Chicken | 9,948 | 9,908 | 0.02 |
| Black cat / red cat | 5,360 | 5,360 | 0.22 |
| Crow | 3,272 | 3,272 | 0.01 |
| Owl | 4,668 | 4,668 | 0.01 |
| Heron | 6,880 | 6,880 | 0.02 |
| Chipmunk | 2,040 | 2,040 | 0.01 |
| Horse | 4,429 | 4,429 | 0.03 |
| Goat | 4,434 | 4,434 | 0.03 |
| Trym's creature | 20,340 | 20,340 | 0.24 |
| Symmetry creature | 34,480 | 34,480 | 0.05 |
| The people's walk | 760 | 760 | 0.03 |
| The first armature | 296 | 296 | 0.17 |
| The dreamer | 213,504 | 540 | 1.37 |
| Brachiosaurus | 3,043 | 3,043 | 0.03 |
| **All 17** | **334,147** | **121,103** | **2.7** |

The whole roster frame: median 1.6 ms, 95th percentile 2.8 ms (before bending joints were turned
on for four more animals, below).

**The review pass (step 18), from filmstrips of each gait cycle:**
- Horse, goat, brachiosaurus and Nike walked on rigid pieces with no bending joints, so needles
  stuck out at the hips and hocks (the cat's old artifact). `blend_joints` on for all four; the
  horse's frames beside its original walker show the same pose and clean joints.
- The horse's cadence was a slow default (`belt_speed` 1.6): now 3.6.
- The heron's column flight peaked at 1.65 m (a Bezier never reaches its control points):
  `column_rise` 2.9 gives about 2.2 m.
- The first armature at its own scale is a 4 m giant: `body_scale` 0.45.
- The dreamer at a quarter scale read as a small urchin: now half the far room's size.
- Trym's creature faces -X, so `front_axis` tells cameras where its front is (it cannot be
  turned: its foot solver works along world -X). The symmetry creature, static, is turned to
  face +Z (`display_yaw`).
- The symmetry creature in a plain slice shows only its body: its repeated legs lie off the
  slice through W, by design. Bay 4 shows them with P.

### Section C: done (3 Oct, night)

`LabKit/lab_rig_4d.gd`, the test rig, on a bench of its own (`CreationLab/_rig_test.tscn`):
- **The drum** is a cubinder (a disc swept through height and W), stepped: a body and a deck a
  step smaller, a glowing rim in the part's colour, a dark contact disc under the animal.
- **The belt** runs back along the animal's walking direction at the speed its planted feet
  slide, and stops when it pauses.
- **The boom** stands on one post behind the animal and reaches over its back, so the side,
  front and three-quarter views stay clear; the tether drops straight from its tip. Flyers fly
  between two cyan halo rings; perchers sit on a stand.
- **The light pool** from the boom tip carries the dark mood.
- **The view switch** (`LabKit/lab_views_4d.gd`): Skin; Blocks (every rigid piece its own
  colour); Lines (Marey: bones and joint dots, filled feet when planted and hollow when
  swinging, each foot's path as a loop; drawn by `LabKit/lab_overlay_4d.gd` through the live
  camera); Balls (the loft rig's own cross-sections, carried along with the walking pieces).
  Each animal offers only the views it has.
- **The W spin** turns the animal through the fourth axis, eased: at 45 and 90 degrees the
  wolf's legs leave the slice and Trym's creature becomes one leg and a head.
- **Sleep:** a far animal, or one behind the camera, holds its pose; bending joints run only
  near.
- `_verify_rig_runner.gd`, 10 checks, passing on the wolf, Trym's creature and the chicken: the
  belt's direction and stop, the spin, sleep and wake, and every view switch restoring exactly.

### Section D: done (3 Oct, night)

- **The bay shell** (`LabKit/lab_bay_4d.gd`, bench `CreationLab/_bay_test.tscn`): a 14 m test cell,
  open at the front where you arrive; walls on three sides with chamfered corners; Ramon's grid
  at 2 m a tile; a skirting light and a cap light along the walls; a light ring and four thin
  crossbars overhead; the step's number as large segmented digits on the back wall, built from
  bars; the W-lift's pad. Every piece has its own W thickness for the dissolve.
- **Spacing found by eye:** the first bay (18 m, rig nine metres from the pad) showed a small wolf
  far off. Now pad, learning zone, lectern and rig sit on one line about six metres long, and a
  rig can show a small animal enlarged (`animal_scale`, as exhibitions show models; the wolf at
  1.4x in its teaching bays, said on its card). Trym's creature is never scaled.
- **Moods tuned for both:** bright is a clean white studio (front-left key, so faces turned right
  fall into shade and white boxes read against white floor); dark is a blue-black room carried by
  the rigs' light pools and the glow strips. Checked with the extremes side by side: the white
  goat and chicken on grey decks, the black cat against white; under the dark pools the cat gets
  a rim of light and the white animals glow without blowing out.
- An outer floor a step below the bays, so their open front looks onto floor, not sky.

**Animals that needed lab versions** (subclasses, so fixes to the originals reach the lab):
the chicken's walker and the cat walk in place (`creatures/lab_chicken_walker.gd`,
`lab_cat.gd`); the heron flies straight up and down its column (`lab_heron.gd`); the people's
walk runs on a treadmill (`lab_person.gd`: a real body that tells the gait it walks, snaps back,
and slides the planted feet back like a belt).

## What the research said

| Source | What we take |
|---|---|
| Unreal's **Content Examples** project: rooms per topic, numbered stands, one feature each, text you can cross-reference | One idea per stand, numbered, with a written explanation beside it |
| Unreal's interactive **Introduction** tutorial: steps, one action at a time, "Next" | A guide panel with step x of n, one task, a tick, then on |
| **The Science Behind Pixar** (8 sections in pipeline order: modelling, rigging, surfaces, ... rendering; 50+ hands-on stations, a life-size character at each) | Follow the pipeline's own order; each section has a hands-on task and the real character |
| Valve on **Portal**: test chambers each teach one part of a mechanic ("checklisting"), then layer them | Break the pipeline into the few things a visitor must grasp; each bay teaches one; the last room combines them |
| Bret Victor, **Explorable Explanations / Ladder of Abstraction**: a simulation with guidance, moving between concrete and abstract | Every bay pairs the real creature (concrete) with a diagram view of it (abstract), switchable |
| **Muybridge** (sequential plates) and **Marey** (geometric chronophotography: a black suit with white stripes on the limbs and dots on the joints, giving lines and dots) | The mechanism view drawn as Marey did: white lines and joint dots, with motion trails. A Muybridge strip of frozen poses for the walk |
| **Hildebrand's gait diagram**: one bar per foot for its ground contact, across one stride | A live footfall chart on the wall, synced to the creature, which reshapes when the gait changes |
| Robotics labs test legged robots on **treadmills under an overhead gantry and safety tether** | Our pedestal is a test rig: a treadmill drum under a gantry. The creature walks in place, tethered, and flyers rise and fall in the tether's column. That makes the tether honest R&D, not a museum plinth |
| David Rosen (GDC 2014, *An Indie Approach to Procedural Animation*): a whole game's movement from 13 key poses plus maths | The card line for the animation bays: "nothing here is keyframed" |

## The idea: a lab you ride through W

Every step of the explanation is a **bay**: a small test cell with one rig, one card and one
task. The bays are all **stacked along W**, at the same place in the room. You only ever see
the bay you are in, because the others are in other slices. When a step is done, you ride the
**W-lift**, a pad in the floor of every bay, to the next one. The bay you leave thins away
through W and the next one grows in around you.

- **No overwhelm, by construction:** one idea on screen at a time.
- **The structure teaches 4D:** by the end you have moved through W eleven times without being
  told to. The last room says so, and P shows every bay you passed, superimposed in the same
  place.
- **You can't get lost:** every bay is the same shell at the same spot, so a step change works
  like turning a page.
- **Filmable for free:** the camera marks belong to the bay shell, so every bay is shot the same
  way. The W-slide is a ready-made transition.
- **A safety valve:** the stack's axis is one setting. If playtests show the W-lift confuses
  people, the same bays sit side by side along X and the lift becomes a door, with no other
  changes.

### The beat of every bay: arrive, show, try, unlock, next

1. **Arrive.** The slide ends. The bay's code and title light up ("CL-03 · Many balls make a
   body"), and the step numeral glows on the wall.
2. **Show.** The guide panel (top left, Unreal-style: "Step 3 of 9 · Build") says the one idea
   in a sentence. The rig is already doing its thing.
3. **Try.** One task with its key in a chip ("Press ] to add the next ball"). The rig reacts,
   and a "what just happened" line follows.
4. **Unlock.** The task ticks. The lectern card opens its detail (METHOD / LIMITS / MEASURED
   with the evidence tier), the lift pad lights cyan, and a soft chime plays.
5. **Next.** Stand on the pad and press N to ride on. Shift+N goes back, M opens the lift's
   floor list to jump anywhere. A dim "for the curious" row lists the extra controls.

### The route

| W | Bay | The one idea | The task | What is on the rig |
|---|---|---|---|---|
| 0 | **Atrium** | "How a 4D creature is made, in ten steps. Nothing is keyframed." | Walk to the lift | The finished wolf walking under the gantry: the destination first |
| | **I. BUILD** | | | |
| 12 | 1 · **A ball is a slice** | A ball sets the body's shape at one point | Widen it, then stretch it through W and watch it shrink in your slice | One ball and its section ring |
| 24 | 2 · **Two balls make a limb** | The skin is lofted between sections, live | Move the middle ball; the rebuild ms appears | The wolf's foreleg, three balls |
| 36 | 3 · **Many balls make a body** | Built ball by ball; checks keep it watertight | Build it to the end (←/→ scrubs) | The wolf, stage by stage, with markers and a spine line |
| 48 | 4 · **Mirror, branch, through W** | Mirrored legs; limbs repeated around W | Turn the slice to find the legs hidden in W; P shows them all | The wolf's mirror ghost, then the symmetry creature |
| | **II. MOTION** | | | |
| 60 | 5 · **Cut into pieces** | The hide is cut into rigid pieces; only joint bands bend | Explode and reassemble (E) | The wolf, exploded into coloured blocks and put back |
| 72 | 6 · **The feet find the ground** | Feet planned from a clock; legs solved by two-bone IK | Slow motion (T), watch one foot plant and lift | The wolf in Marey lines: bones, joint dots, stepping circles, contacts |
| 84 | 7 · **A clock drives the gait** | Gaits are timing; the footfall chart shows it | Switch gaits (G); then the W offset, a gait with no 3D equivalent | Trym's 8-leg creature and a live Hildebrand chart on the wall |
| 96 | 8 · **Three views, one walk** | Skin, blocks and lines are the same walk | Pause and step frame by frame | Three wolves in sync, and a Muybridge strip of frozen poses |
| 108 | 9 · **What it costs** | Moving pieces is free; reshaping is not | Switch each leg on and watch its ms | Four wolf legs: drawn, moved, skinned, re-lofted every frame |
| 120 | 10 · **Layers on top of the walk** | A walk alone looks robotic; small layers make it alive | Switch the layers on one by one (1 to 6) | Trym's creature with its six solvers (gait, ground, spine and neck, head attention, tail sway, idle), the wolf with its new tail and head layers, and the chicken's steady head and pecks |
| 132 | **The Hall** | "You moved through W eleven times to get here." | Press P: every bay, in the same place | The roster: every creature on its own rig, with the view switch from the steps |

### The animals

Rather too many than too few (Ramon). Every animal gets a review pass for oddities (sliding
feet, knees folding the wrong way, popping) before it goes on a rig.

| Animal | Where | Its animation today | What I improve |
|---|---|---|---|
| **Wolf** (the hero) | Atrium, bays 2 to 6 and 8 to 10, Hall | walk in place, rigid pieces with bending joints | trot and lope gaits; tail and head layers, so the hero shows layering too |
| **Trym's 8-leg creature** | bays 7 and 10, Hall | walk, trot, canter, hop, idle; six solvers; legs in two W halves | its 42 segments coloured for the Blocks view; each solver switchable on its own |
| **Symmetry creature** (Trym, legs around W) | bay 4, Hall | static | stays static: its legs are generated copies that no walker can drive |
| **Chicken** | bay 10, Hall | two-legged walk, pecking, steady head | freed from the pen's flock code; pecks on a loop |
| **Black cat, red cat** | Hall | walk with bending joints; ten moods | a short loop of moods on the rig (walk, sit, wash) |
| **Nike** | Hall | walk, rooting, lying down and getting up | the antics on a loop |
| **Horse** (the first walking loft creature) | Hall | walk, but skins every vertex (slow) | moved to rigid pieces with bending joints |
| **Brachiosaurus** | Hall, the big rig | walk, skinned (slow) | moved to rigid pieces; walks in place on the big rig |
| **Goat** | Hall | none | given a walk (the strider on its legs) |
| **Crow** | Hall, a flyer | perch, look about, fly | take-off, flight and landing in a loop inside its column |
| **Owl** | Hall | sit, look, stretch a wing, turn its head through W | on a perch rig |
| **Heron** | Hall, a flyer | wade, strike, take-off, flight, landing | the whole loop inside its column |
| **Chipmunk** | Hall | forage and the rest | as it is |
| **The first armature** (the old Motion Lab, Aug) | Hall, archive rig | walks on its own belt; legs and segments on keys | as it is: where the work started |
| **The block avatar** (the people's walk) | Hall | planted feet, pelvis drop, arm swing | as it is, on a rig |
| **The dreamer** (Azathoth), scaled down | Hall, last exhibit | tentacles moving through all four dimensions, a core that shimmers | on its own rig, scaled to fit (Ramon: include it, 3 Oct) |

Not in the lab: the starlings and the hawk (a GPU flock, with its own showcase in the brief).

The Hall is the walkable payoff: an open floor, every creature on its own rig and card, and
every view you learned (Skin, Blocks, Lines, Balls, W spin) working on all of them. It is the
museum of interactive properties, after the lessons rather than instead of them.

### Three ways in (the menu's buttons)

- **Guided:** start at the Atrium, steps unlock in order.
- **Watch:** the autopilot plays the whole route as a guided film, about 4 minutes.
- **Explore:** start in the Hall, every floor open on the lift.

## The look

- **Your textures, your grid:** `res://textures/dev_finals/ramdev_*.png`, each a 1024 px tile
  split 2×2 with a thin border and darker chamfered corners. Tiled at true metres by
  `ramon/Demo/scripts/hub_tiled_floor_4d.gd` and `ramon/Demo/shaders/hub_tiled_surface.gdshader`.
  Colours are read from the PNGs by `ramon/Demo/scripts/hub_palette.gd`.
- **Bright (default):** a white grid floor, pale walls, a high sun with strong ambient.
- **Dark:** dark grey and black, low ambient, light pools on the rigs, cyan rim light. Same bays,
  same content.
- **Sci-fi, stylish, R&D.** Designed, not decorated:
  - The bay is a **test cell**: chamfered walls, a light-strip ring overhead, and a large
    segmented numeral on the back wall built from bars (no texture needed).
  - The rig is a **treadmill drum under a gantry**, with the tether line (thickened along the
    slice so it doesn't vanish in 4D).
  - Few materials, measured spacing, Montserrat with thin rules, nothing that doesn't explain
    something.
- **Colour code:**

| Colour | Means |
|---|---|
| greys | structure |
| yellow | stand here, press this |
| cyan | W: the lift, rulers, slice markers |
| violet | build |
| blue | animate |
| red | a limit or a failed check |

- **Engine limits we design around:**
  - No shadows: contact discs ground the creatures.
  - Flat shading: it suits the blockout honesty.
  - Opaque only: the diagram views are overlays drawn through the live camera.
  - Boxes don't fade through W, they end: each bay's pieces are given staggered W
    thicknesses, so a bay dissolves outside-in during the slide and the next builds inside-out.

## The kit (what the other prototypes reuse)

`res://ramon/LabKit/` is separate from the lab, and the Creation Lab is its first user. The kit
is not only a look; it is the **explainer grammar**: bays along an axis, the lift, the beat,
the guide panel, cards, autopilot and film. The Shrubbery Lab's three trees, Voxel Mining's
demonstrations and the range's experiments can each become a sequence of bays.

| Piece | Built from |
|---|---|
| `lab_style.gd`: tokens, colour code, the two moods | `ramon/Menu/scripts/menu_style.gd`, `hub_palette.gd` |
| bay shell and room moods | `hub_tiled_floor_4d.gd` and its shader; `ramon/lightTest/light_test_museum.tscn` lighting |
| test rig: drum, belt, gantry, tether, view switch, W spin, sleep | `chickenpen/theatre/theatre_stage_4d.gd` drum |
| `LabStep` resource, step runner, W-lift | new |
| guide panel, lectern card, controls card, metrics card | the pen's card grammar (`pen_controls_4d.gd`, `flock/flock_stats_panel_4d.gd`); the finding layout in `ramon/Menu/scripts/menu_final.gd` |
| world tags, panel spots, UI size | `ramon/dialogue/world_tag_4d.gd`, `pen_hud_spot_4d.gd`, `pen_ui_scale_4d.gd` (as they are) |
| autopilot and shot player | the keyframe player in `lookout/lookout_cutscene_4d.gd`, the cinematics' caption card |

## Engineering calls and risks

- **Only the bay you are in runs.** The others are hidden and paused, so the cost is one bay at
  a time. The Hall puts its far rigs to sleep.
- **Rigid pieces everywhere.** The chickenpen copy of `strider_walker.gd` is used throughout;
  the Model copy skins every vertex and is far too slow. Bending joints run only on the rig you
  are at.
- **Live re-lofting only where it is cheap** (bays 1 and 2). Bay 3 plays baked stages, the way
  the cinema's goat was baked.
- **The W-slide:** the player's physics pauses, and the player and camera glide 12 m along W in
  about 1.2 s. Adjacent bay floors overlap in W, so there is always floor underfoot. Zones are
  polled, because an Area4D never fires for a body that teleports.
- **P and the reveal:** the projection superimposes every bay, which is the point. Floors that
  span W add haze to it. Upstream `6875f37` (leave one mesh out of the projection) would remove
  that, but it needs an engine pull, so it is your call. The reveal works without it.
- **Scale:** the lab is in metres. Lineup models (0.25 m units) are scaled on their root. Trym's
  creature stays at its authored size, since FABRIK breaks under a parent scale.
- **Menu:** a new "Creation Lab" entry with the three buttons. The Motion Lab and Lofted
  Creatures entries stay until you retire them.
- **Performance target:** under 8 ms a frame at 1280×720 (RTX 5080), in every bay and in the
  Hall.

## The 70 steps

Every step that makes something visible ends with captured frames looked at by eye, **in both
moods**: bright dev is the default and dark dev the toggle, and both are tuned, not one tuned and
the other derived (Ramon, 3 Oct: "you have to optimize for both"). Timings are taken windowed with
vsync off. One Godot at a time, with the lock taken in the same command
that launches. Commits by explicit paths at the end of each section.

### A. Foundations
1. Folders: `ramon/CreationLab/` (the scene, `bays/`, `creatures/`, `scripts/`, `baked/`) and
   `ramon/LabKit/`.
2. Read every creature script in full and write down, per creature, what it needs from the pen
   (managers, groups, node paths, player references): the chickenpen strider and chicken walker,
   the cat, the crow, the owl, the heron, the chipmunk, Nike's antics, the block gait, the first
   armature, and Trym's six solvers.
3. `_verify_lab_smoke_runner.gd`: loads a scene headless and fails on any script error, missing
   resource, or a Camera4D not set to Cross-section.
4. `_capture_lab_runner.gd`: a windowed 1280x720 run, unfocusable, vsync off, with frames from
   named camera marks saved to `smoke_test_output/creation_lab/`.
5. `_measure_lab_runner.gd`: frame, GPU and script time and video memory, with A and B
   interleaved.
6. Parse-check every new script with `--check-only` before any batch run.

### B. The animals (every creature in one new scene, each reviewed and improved)
7. `lab_creature_4d.gd`, the root of every creature sub-scene. It holds the name, how it was
   built, how it's animated, its tether (ground, column or perch), footprint and height. It also
   offers one control surface (pause, speed, phase, gait, view, layers) over whichever walker the
   creature has.
8. Wolf and Nike, from their own scenes (the rigid-piece copies), walking on the spot.
9. The wolf improved: trot and lope gaits, plus tail and head layers. Frames compared with its
   old walk.
10. Chicken: a fork of `chickenpen/chicken.tscn` without the pen's flock agent; walk, steady head
    and pecks on a loop.
11. The cats, black and red: wrappers that build the hide with `pen_cat_4d.gd`'s own builder, with
    a short loop of moods (walk, sit, wash).
12. Crow, owl, heron and chipmunk: wrappers over their own scripts. The crow and the heron loop
    take-off, flight and landing inside their column; the owl sits on a perch rig.
13. Horse: a fork of `animation_test.tscn` moved to rigid pieces with bending joints. Frames
    before and after prove the pose did not change.
14. Brachiosaurus: extracted from `rigged_creature_ramon.tscn`, moved to rigid pieces, and scaled
    to metres.
15. Goat: extracted from `model.tscn` and given a walk (the strider on its legs).
16. Trym's 8-leg creature (segments coloured for Blocks, each solver switchable), the symmetry
    creature, the first armature, the block avatar, and the dreamer scaled down, each in its own
    sub-scene.
17. `creature_roster.tscn`: all of them in a grid with name tags. Frames of each from three
    sides, and each one's measured tetrahedra, ms and video memory written into this doc.
18. The review pass: every animal watched walking, slowed down, for sliding feet, knees folding
    the wrong way and popping. Each fixed, with before-and-after frames.

### C. The test rig
19. `LabKit/lab_rig_4d.gd`: a chamfered treadmill drum with real W thickness, sized from the
    creature's footprint, with a rim light in the part's colour and a contact disc.
20. The belt: marks on the drum's top that run at the creature's own walking speed and stop
    when it pauses.
21. The gantry: a chamfered overhead frame and a tether line to the creature's back, thickened
    along the slice so it stays visible.
22. The tether: x, z and w locked to the rig's centre. Flyers are free in height within a band,
    marked by two cyan halo rings; perchers sit on a stand.
23. The view switch: Skin, Blocks (each rigid piece its own colour), Lines (Marey: white bones
    and joint dots) and Balls (the rig's own ball wireframes).
24. The W spin: the creature turns through W (an xw rotation), eased, with a cyan W readout.
25. Sleep: a rig out of view or far away holds its pose; bending joints run only on the rig you
    are at. Frames of the wolf on the rig in all four views, walking and paused.

### D. The look
26. `LabKit/lab_style.gd`: tokens on top of `MenuStyle`, the colour code, and the bright and
    dark palettes.
27. Lab materials from your `dev_finals` textures through the tiled shader: the white floor at
    2 m a tile, grey, dark grey, black metal, and the accents.
28. `LabKit/lab_bay_4d.gd`, the test-cell shell: floor, chamfered walls, the light-strip ring,
    the lift pad, the lectern spot, the rig spot, and a segmented numeral built from bars on the
    back wall. Its pieces have staggered W thicknesses for the dissolve.
29. `set_mood(BRIGHT or DARK)`: palette, sky, sun, ambient and the light strips, eased. Light
    pools on the rig in dark mode, with OmniLight4D reach checked in cross-section.
30. Frames of one bay in both moods from the entry, from above, and from the rig.
31. Tune exposure and floor value so the white chicken and the black cat both read, in both
    moods.

### E. The step framework
32. `LabKit/lab_step.gd`, a resource: code, title, the one idea, the task and its check, card
    rows with evidence tier, captions, camera marks, and the autopilot demo.
33. `LabKit/lab_sequence_4d.gd`: places bays along an axis (W by default, X as the fallback),
    owns the current step, and wakes only the bay you are in.
34. The W-lift: the pad, its floor indicator (W and step), and the slide. Physics paused, player
    and camera glide 12 m in W, the bays dissolve and build in turn.
35. The guide panel: step x of n, part, title, the idea, the task with its key chip and tick, and
    what's next.
36. `LabKit/lab_lectern_4d.gd` and its card, drawn over the lectern's face through the live
    camera. It shows a summary first and the full detail once the step is done, and fades if the
    lectern leaves your slice.
37. The controls card (the pen's key-chip grammar), with the dim "for the curious" rows.
38. Task checks: each step's condition polled, the tick, the chime, the lift lighting up.
39. Back (Shift+N), the lift's floor list (M), and the three entry modes: Guided, Watch, Explore.
40. The player (the pen's block walker, third person, arriving on the lift pad facing the rig)
    and the global keys (bright/dark, P projection, F3 HUD, Esc back), each checked to be free.
41. A runner that rides the lift through empty bays both ways. Frames mid-slide, to check the
    dissolve reads as intended.

### F. The Atrium and the Build bays
42. Atrium: the finished wolf on its rig, the welcome card, the axis gizmo (X, Y, Z, and W in
    cyan), the lift.
43. Bay 1, A ball is a slice: one ball and its section ring; radius and W stretch on keys; the
    stretch shrinks it in your slice.
44. Bay 2, Two balls make a limb: the wolf's foreleg (three balls) re-lofts live as the middle
    ball moves. The measured rebuild ms on the card.
45. A rebuild that also covers roll, squareness and colour, which the rig's change check misses.
46. Bake the wolf's build stages ball by ball, plus its reshape and colour stages
    (`_bake_wolf_stages_runner.gd`, the goat's method).
47. Bay 3, Many balls make a body: scrub the stages with ball markers and a spine line, and the
    checks tick green at the end.
48. Bay 4, Mirror, branch, through W: the wolf's mirror ghost, then the symmetry creature. The
    task is turning the slice to find the legs hidden in W, then P to see them all.
49. A guided run through the Build bays as a player would do it. Frames at every beat.

### G. The Motion bays
50. One lab clock: every creature's phase reads from it, so pause, slow motion and frame
    stepping apply exactly.
51. Bay 5, Cut into pieces: the wolf's rigid pieces drift apart in their colours and come back
    together (E).
52. The Lines view drawn properly: bones, joint dots, motion trails, stepping circles, and
    contacts filled while planted.
53. Bay 6, The feet find the ground: the wolf in Lines, with slow motion and live stride.
54. The footfall chart (Hildebrand): one bar per foot across the stride, drawn live on the back
    wall and synced to the creature.
55. Bay 7, A clock drives the gait: Trym's creature through walk, trot, canter, hop and idle, the
    chart reshaping each time, then the W-pair offset. The wolf's new trot and lope beside it.
56. Bay 8, Three views, one walk: three wolves in sync (skin, blocks, lines) and a Muybridge
    strip of frozen poses on the grid behind them.
57. Bay 9, What it costs: four wolf legs, each switchable, with live measured ms bars and the
    per-tetrahedron numbers.
58. Layer switches: each of Trym's six solvers, and the wolf's tail and head layers, turned on
    and off cleanly without a jump in the pose.
59. Bay 10, Layers on top of the walk: keys 1 to 6 add the layers one at a time, from a bare
    robotic walk to a creature that looks alive. The chicken's steady head and pecks are the last
    example.
60. Each Motion bay's card text, captions and camera marks.
61. A guided run through the Motion bays. Frames at every beat.

### H. The Hall
62. The Hall at the end of the stack: an open floor, every animal on its own rig with a card,
    the brachiosaurus on the big rig at the back.
63. Every view and layer from the steps working on every animal there.
64. The reveal: "You moved through W eleven times to get here", then P superimposes every bay in
    the same place.
65. Performance pass: under 8 ms a frame in every bay and in the Hall, measured and written
    down.

### I. Autopilot and film
66. Camera marks on the bay shell (wide, medium, close, top), shared by every bay, with
    per-bay overrides.
67. Autopilot and "Watch" mode: each step's demo performs its own task on cue, with the shots and
    captions, then the lift to the next. The whole route in about 4 minutes; Esc hands control
    back wherever you are.
68. `_film_creation_lab_runner.gd`: the same route rendered with `--write-movie` at fixed fps,
    with the HUD and your avatar hidden, to `smoke_test_output/video/`.

### J. Finish
69. The menu entry, "Creation Lab", with Guided, Watch and Explore. The Motion Lab and Lofted
    Creatures entries stay until you say.
70. `follow_up/lab_kit.md` (how the other prototypes use the kit: the look, the rig and the
    step framework), this handover, `engine_capabilities.md` and memory brought up to date.
    Then the film and the frames for you to look at.

Pivot rule: if a step fails or a better way shows up, take it and write down why here.
Questions and ideas outside the plan go to the top. The plan does not grow.

Sources: [Unreal Content Examples](https://dev.epicgames.com/documentation/en-us/unreal-engine/content-examples-sample-project-for-unreal-engine),
[The Science Behind Pixar](https://ctsciencecenter.org/?p=54560),
[Portal developer commentary](https://theportalwiki.com/wiki/Portal_developer_commentary),
[Explorable explanation](https://en.wikipedia.org/wiki/Explorable_explanation),
[Chronophotography](https://en.wikipedia.org/wiki/Chronophotography),
[Hildebrand 1980](https://www.originalwisdom.com/wp-content/uploads/bsk-pdf-manager/2019/03/Hildebrand_1980_The-Adaptive-Significance-of-Tetrapod-Gait-Selection.pdf),
[robot test gantries](https://research.gatech.edu/robotics/human-augmentation-core),
[David Rosen, GDC 2014](https://gamedeveloper.com/design/video-an-indie-approach-to-procedural-animation).
