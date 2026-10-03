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

(None open. During the build, new questions and out-of-plan ideas go here.)

## Status

Approved 3 Oct, evening; building from step 1.

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
