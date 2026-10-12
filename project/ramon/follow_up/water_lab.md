# Water Lab: plan and handover

Ramon, 9 Oct 2026: a showcase of water systems in its own folder, `ramon/WaterLab/`, no longer part of
the Arboretum. Two scenes:

- **`water_lab.tscn`, the tank room** (the main scene). A square kit room. Across its back stands a big
  aquarium on a lab pedestal, with koi, an eel, corals, stones and swaying weed. A second pedestal holds
  one big koi that you can turn in 4D. Two blue walls explain how the water works, with diagrams that
  move. You come in at the bottom left, walk along the tank and leave by a sci-fi door at the right.
- **`seascape/seascape.tscn`, the sea** (it was `ramon/Water/water4d_test_ramon.tscn`, carried over
  with Ramon's saved tuning). Its additions:
  - a fish murmuration;
  - gulls landing on the rails and posts;
  - the plesiosaur, nearer the surface and seen more often;
  - a sea that reaches the horizon;
  - the doors behind the piers lead back to the tank room.

The seagull is also its own scene, `gull/gull.tscn`, with a test bed, `gull/gull_test.tscn`.

## Engineering decisions (made 9 Oct, before building)

1. **The tank's fish, eel, weed and the sea's school are drawn the way the pen's starlings are**
   (`chickenpen/flock/flock_bird.gdshader`). This is a 3D multimesh in the cross-section's own world,
   placed by each animal's 4D position and heading. Each animal is a 4D body: its 3D shape is stretched
   through W as an ellipsoid, so the slice shrinks it to nothing at the edge of its W depth.
   - **Why:** a vertex shader can bend a body with a real travelling wave. Carangiform for the koi,
     anguilliform for the eel, and swaying for the weed, all at almost no cost.
   - **The cost of the alternative:** rigid 4D pieces bend only at joints, and re-posing a 4D mesh
     costs about 2.5 µs a cell a frame (`lofting_gotchas.md`). Ramon asked for "really really really
     good" koi.
2. **The gull and the pedestal koi are lofted 4D meshes, cut into rigid pieces** (the QuantumRange
   chicken's way, `target_chicken.gd`). Each is lofted once, and only the pieces' transforms move each
   frame, which is nearly free (drawing is about 0.15 µs a tetrahedron).
   - This is what Ramon asked for on the gull: "a lofting system ... break it apart ... so that we
     don't render per frame".
   - The pedestal koi has to be a real 4D shape so that turning it through W shows something true.
3. **The tank's water is one full-screen shader**, drawn in the cross-section's 3D world after the
   opaque pass. It casts each pixel's view ray against the tank as a 4D box, for any tilt of the slice.
   Against the depth buffer it adds:
   - the water's colour by path length (Beer-Lambert, as in Trym's sea);
   - caustics on whatever stands in the water;
   - the silver underside of the surface where the ray leaves through the top.

   The renderer is opaque only, so this is the one way to see INTO water.
4. **The room is deep in W** (the carried kit's `W_DEPTH` raised from 8 to 40 m). The pen's rig can
   tilt the slice there (Andrew's walk and turn), and the tank's 4D contents change with the tilt, so
   the walls must survive the tilt.
5. **Corals and stones are static lofted 4D meshes, branching through W** as well as x and z, so a
   tilted slice cuts a different reef. Stones are lumpy lofted glomes, clipped by planes into facets,
   the way the Voxel Lab's specimens are chamfered. This is a fraction of a VoxelWorld4D's memory and
   first-show cost.
6. **Sound is synthesised** (gull calls, water lapping), baked by a Python script, as the Lookout's
   heron and owl were. The project has no gull or sea audio. Any CC0 recording found online is listed
   at the end and is not downloaded without Ramon's go-ahead.

## The 100 steps

### A. Folder and carry (1-8)
1. Create `ramon/WaterLab/`.
2. Carry `ramon/Water/` into `WaterLab/seascape/`, every `res://` path rewritten and Ramon's tuning cfg
   carried as `seascape_tuning.cfg`.
3. Repoint the seascape HUD's SAVE_PATH, and the capture and path runners, to the new paths.
4. Raise the carried kit's `W_DEPTH` to 40 m. Check that the seascape's doors and panels don't depend
   on 8.
5. Carry the pen's flock (`chickenpen/flock/`) into `WaterLab/carried/flock/` as the base of the
   school.
6. Write `WaterLab/README.md`: what is where, and the keys.
7. Parse-check every script with a headless run.
8. Leave `ramon/Water/` untouched for now. Retiring it is Ramon's call.

### B. Slice-drawn animals (9-16)
9. `shared/slice_draw.gdshaderinc`: the view uniforms, the 4D-to-camera move and the ellipsoid cut,
   in one place.
10. `shared/slice_herd_4d.gd`: one RenderingServer multimesh per species.
    - It has a pre_render hook: the scenario check, the view uniforms and the Combined renderer's inner
      viewport.
    - It has a CPU buffer writer: position, heading and side as three Vector4 rows, then colour and
      custom data.
11. A test scene with one fish, rotated through W: check that the cut shrinks it correctly and that a
    tilted slice cuts it correctly.
12. Fish lighting: the sun and kit lights reach the multimesh (the flock is lit by suns, so check the
    kit's spot lights).
13. Depth: the fish hide behind the tank frame and corals, and corals hide behind fish.
14. Shadows: off, as on the flock.
15. Measure the cost of 50 koi-sized instances (target under 0.2 ms).
16. Write down the rules in the shader's header.

### C. The tank room shell and flow (17-30)
17. Build `water_lab_4d.gd` and `water_lab.tscn` from the Arboretum's pattern: the Room (lab mood),
    the Hall (kit room), the lights, the sun, the panel source, the panels, the stations, the paths and
    the targets.
18. The room is square, 18 x 18 m and 10 m high. The tank fills the back wall.
19. The entrance is a sci-fi door at the bottom left (the south wall's west end). You spawn just inside
    it, facing north.
20. The exit is a sci-fi door at the right end of the tank (the east wall's north end).
21. The player is the pen's rig and walk (the seascape's carried copies), with the Creation Lab's
    camera: distance 5, pivot 2.45, pitch -11, wheel zoom.
22. Andrew's directions: a right drag tilts the slice anywhere in the room (the pen's way) and R levels
    it. At the koi pedestal, a right drag turns the koi instead.
23. The kit HUD (`rd_hud.gd`, glass) with its key strip by context.
24. The entrance sign over the door from the outside, and the room's title on the back wall over the
    tank: WATER LAB.
25. PathCreator routes, rectilinear only:
    - entrance north, then turn 90 degrees east along the tank, then the exit door;
    - branches at right angles to the koi pedestal and to each blue wall.
26. Route states: the destinations complete as you reach them (the Arboretum's `_route_states`).
27. Walking into the exit door fades to black and loads the seascape at pier 1's door. The arrival is
    passed through the tree's meta.
28. Arriving back from the sea puts you at the exit door, facing into the room.
29. Downlights over the tank, the pedestal and each wall, with the kit's lights and mood.
30. The B palette switch and F4 path builder, as in the Arboretum.

### D. The tank (31-42)
31. The pedestal: a square lab pedestal, 13 m wide, 1.2 m high and 3.6 m deep, the kit's grey with a lit
    rim.
32. The tank: 12 m wide, 4.6 m tall (water 4.2 m), 3.2 m deep in z and 3.2 m deep in W, a 4D box.
33. The frame: gunmetal corner posts, a top rim and a base rim, at the box's 4D edges that a level slice
    shows (the W faces' edges stay out of sight).
34. The back: a dark blue-slate backdrop with the kit's faint grid.
35. The substrate: sand and fine gravel, a low box with a sand colour and its own grain (tetra
    material).
36. The water shader, `tank/tank_water.gdshader`, full screen:
    - ray against the 4D box;
    - path length against scene depth;
    - Beer-Lambert absorption, clearer than the sea;
    - scatter colour.
37. Caustics inside: the opaque point is rebuilt from depth into tank space, with an animated caustic
    pattern in x, z and W that fades with depth.
38. The surface: where the ray leaves through the top, a silver total-internal-reflection band with
    ripple normals that move a little (sines in x, z and W). Seen from above, a tinted surface with a
    glint.
39. The surface's edge: a bright meniscus line where the water meets the glass.
40. Light shafts: three or four soft additive beams from the surface down, drifting slowly.
41. Bubbles: an air stone at the back left, a column of small bubbles (slice-drawn spheres) rising and
    wobbling.
42. A tuning section in the HUD (Tab) for the tank: clarity, caustics strength, shafts, and the surface
    ripple.

### E. Tank life (43-74)
**Koi (43-55)**
43. Research note in this file: koi swimming (subcarangiform, tail beat, glide), and the varieties.
44. The koi mesh, built in code (`life/koi_mesh.gd`): body loft with a koi profile (round back, flat
    belly), head and mouth, eyes, barbels, and the fins (pectoral, pelvic, dorsal, anal, forked
    caudal).
    - UV.x is the place along the body (0 snout, 1 tail tip); UV.y is the fin id.
45. The koi shader (`life/koi.gdshader`):
    - the spine bends as a travelling wave (amplitude grows toward the tail; the head yaws a little);
    - each vertex is placed by the bent spine's frame, not sheared.
46. Fin motion: pectorals scull and brake, the dorsal and caudal trail the wave with lag, and long fins
    flutter (butterfly koi).
47. Mouth and gill motion: a slow gulp, with gill flaps in time.
48. Pattern in the fragment shader. Varieties by a per-fish code:
    - Kohaku (white with red patches) and Taisho Sanke (white, red and black patches);
    - Showa (black with red and white), Tancho (white with a red head spot);
    - Ogon (metallic gold), Platinum Ogon;
    - Asagi (blue-grey net with red flanks), Chagoi (bronze).
49. Scales: a subtle scale relief from the body coordinates, and a pearl sheen on the metallic koi.
50. Behaviour (`life/koi_school_4d.gd`):
    - wander in loose company: follow a neighbour, keep apart, turn early from walls;
    - glide between strokes;
    - rise to the surface and gulp;
    - hover near the bottom;
    - a W spring that keeps most of them near the slice, with a few drifting out and back.
51. Turning by bending: a turn bends the body into a C (a curvature term on top of the wave), and the
    tail beat speeds up to accelerate.
52. Twelve koi, 0.55 to 0.85 m, mixed varieties.
53. A frame film of a koi passing close and of the whole tank. Check the bend for shear and the fins for
    pops.
54. A koi passing in front of the glass slows and looks (a curiosity beat), which reads from the walk.
55. Tuning: count, speed and wave in the tank's HUD section.

**Eel (56-60)**
56. The eel mesh: long, round in front, flattened toward the tail, one continuous fin along the back
    and belly, small pectorals, a pointed head.
57. Anguilliform shader: the whole body waves at about 0.6 of its length, with near-constant amplitude.
58. Behaviour: rests in a rock cave, slides out along the bottom, a slow loop round the tank, and back.
    Sometimes rises halfway.
59. One eel, 1.4 m.
60. A frame film.

**Weed (61-64)**
61. A blade mesh: a ribbon with floats for kelp, and a thin strap for eelgrass.
62. A sway shader: the current's travelling wave plus a per-blade phase, more at the tip, with
    backlight so it glows when lit from behind. Cut by its W ribbon depth.
63. Beds at the tank's back corners and along the back, about 60 blades, some 3.5 m tall reaching the
    surface.
64. Check that they never poke through the glass and always stay inside the tank.

**Corals (65-70)**
65. `life/reef_builder.gd`: branching lofts (staghorn) whose branches spread in x, z and W, merged into
    one mesh per colony.
66. A plate (table) coral on a stalk, and a boulder (brain) coral with lobes.
67. Tube sponges: a cluster of tubes with dark rims.
68. Colours along each loft: pale tips on the staghorn, purples, oranges, yellow-green.
69. The reef layout: on rocks at the tank's right and middle, kept clear of the koi's swimming band.
70. A frame check from the walk and through a tilted slice.

**Stones (71-74)**
71. `life/stone_builder.gd`: a lofted glome, its vertices pushed by 4D noise, then clipped by random
    planes into facets (chamfered, as the Voxel Lab's are). Two-tone: crust and inner, by depth.
72. River stones on the substrate, a rock pile with a cave for the eel, and boulders under the reef.
73. Colliders are not needed (nothing walks in the tank). The fish avoid the rocks by spheres.
74. A frame check.

### F. The koi pedestal (75-79)
75. `room/ex_koi_4d.gd`, a kit exhibit: one big koi (2.4 m) lofted in 4D from the same profile as the
    tank's koi, cut into rigid pieces (head, three body pieces, tail, fins), with a Kohaku pattern
    painted in a 3D texture.
76. Its idle: a slow swim in place, the pieces turning by a travelling wave.
77. Its story: three chapters (THE BODY, THE SWIM, THROUGH W) with the kit's camera shots.
78. A round kit pedestal with the blue holographic column (`hologram`) as its water.
79. Its pedestal band text and data (length, cells, pieces, variety).

### G. Blue walls with moving diagrams (80-86)
80. Two walls, both kit wall panels:
    - the INTRO (left wall): what the lab shows and how the water is drawn;
    - the RESEARCH board (right wall): how the waves are made.
81. A new chart kind, "wave", in the carried kit (`kit_panel_charts.gd`), animated. Its page stays busy
    while it is shown, so it redraws every frame.
82. Wave diagrams:
    - Gerstner: water particles turning in circles under a trochoid surface;
    - superposition: eight waves summing;
    - dispersion: long waves outrun short ones;
    - 4D: a wave travelling partly through W, seen in the slice longer and slower;
    - foam: the Jacobian folding at a crest;
    - absorption: red, green and blue fading with depth.
83. `room/wl_panel_source.gd` fills the pages: the steps (the field, the slice solve, the normals, the
    foam, the colour) with the numbers from the live presets.
84. A page about the fish: how the tank's fish are drawn (the starlings' way, the ellipsoid cut).
85. Readability at 4K (the hud4k mode).
86. A frame check of each page.

### H. The seascape (87-92)
87. The plesiosaur nearer the surface: depth 2.5 to 9 m. It passes near the player more often (the
    pilot's wander biased to the piers, a pass every 40 to 70 s).
88. The bigger sea: an outer ring of the same water shader out to 900 m, its step growing with
    distance, plus a bigger floor and a horizon fade.
89. The doors: walking into pier 1's or pier 2's door fades and loads the tank room.
90. The tuning HUD gets a HARBOUR section: gulls (0 to 30), fish (school size), and the plesiosaur's
    visits.
91. Saved settings stay where Ramon left them.
92. A perf pass on the seascape with everything on (target: median under 3 ms).

### I. The gull (93-97, with sub-steps)
93. Research (in this file): the herring gull's shape and colours, flight (wingbeat about 3 Hz, long
    glides, soaring), landing (flare, feet down, wings raised), take-off (hop and deep beats), perched
    behaviour (looking round, the long call, preening).
94. `gull/gull_4d.gd`, built once and posed by pieces:
    - pieces: body, neck and head (with bill), tail, the arm and the hand on each side, and the legs;
    - lofted with the carried loft builder;
    - right side mirrored by `from_xw(PI)`;
    - joints sunk into their neighbours.
    - Colours: a 3D texture painted per piece (grey mantle, black tips with white mirrors, yellow bill
      with a red spot, pink legs).
95. The wing poses: spread, glide (an M with the wrists forward), flap (downstroke 0.45 of the beat,
    wrist folded on the upstroke), flare, and folded on the back (tips crossed over the tail).
96. The behaviour state machine: fly, circle, glide, approach, flare, land, perch (look round, call,
    shuffle, stretch), take off.
    - Perches come from the scene (the rail posts, the rail tops, the pole's top, the door lintels).
    - Landing faces into the wind.
97. `gull/gull_test.tscn`: a deck, posts and rails, four gulls, slow motion (T), and a pose picker.
    Frames of each pose.

### J. Fish murmuration and sound (98-100, with sub-steps)
98. The school: the carried flock with fish settings.
    - Species: Atlantic herring (or sardine, from the research), 1,500 to 3,000 fish, 2 to 10 m down
      by the piers.
    - Silver flanks with a turning flash, a tail-beat shader in place of the wing flap.
    - The plesiosaur as the predator (the flock's hawk), which splits the school and makes it flash.
    - Gulls gather over the school when it rises.
99. Sound:
    - gull calls (the long call, the laugh, the alarm "kek") and harbour water (lapping on piles, a
      distant swell), synthesised by `audio/bake_water_lab_sound.py`;
    - calls placed by gull position (volume and pan);
    - a soft bubbling hum in the tank room.
100. Test by playing:
    - frames of each beat;
    - a perf pass of both scenes;
    - the handover in this file;
    - the memory;
    - commit by explicit paths.

## Added mid-build (Ramon, 9 Oct)

> "maybe on the wall in the first room, not only show info about the ocean, but also the fish, how
> they work in 4d, benchmarks, etc. and maybe you can interact with the fishtank but no idea how. and
> if you could add a walking crab that would be cool, one that appears in different areas of W"

- **The walls:** the research board gets the fish as well as the sea. It covers how the koi are drawn
  (the starlings' way, the ellipsoid cut), the swim wave, the school's rules, and benchmarks measured
  live (the koi's draw cost, the water pass, the tank's frame time).
- **Interacting with the tank: FEEDING.** A feeding spot by the glass: E drops a pinch of pellets on
  the surface. They float and drift, and the koi rise to them and gulp them down, as pond koi do.
  There is also the turning spot in front of the glass, where a right drag turns the slice and shows
  the koi that live off it.
- **A crab:** walking sideways over the sand on eight legs, wandering through W, so it comes and goes
  out of your slice in different places. Drawn the koi's way, its legs stepping in the shader.

## Status (9 Oct, end of the build)

All 100 steps and everything added mid-build are built, checked by frames, and committed in
`bb7f374` .. `8f0e5ba` on `RamonPrototypes` (not pushed).

### How to see it

- **Tank room:** open `ramon/WaterLab/water_lab.tscn` and play.
  - You start in the corridor, bottom left. The path runs up the left and along the tank, past the
    turning circle at the tank's middle.
  - A short branch leads to the koi showcase in the south-east corner.
  - The far door, top right, leads to the sea.
- **Sea:** `ramon/WaterLab/seascape/seascape.tscn` (or walk through that far door). Its doors at the
  piers' backs lead back to the tank room.
- **Gull test bed:** `ramon/WaterLab/gull/gull_test.tscn`.

### Keys

| Where | Key | What it does |
|---|---|---|
| Tank room | E | At the console: feeds the koi. At the showcase: opens or pages its floating panel. |
| Tank room | Right drag (in the circle) | Turns what is IN the tank through W. The room stays put. |
| Tank room | Wheel (in the circle) | Slides the contents through W. |
| Tank room | R | In the circle: puts the contents back. At the showcase: makes the koi whole. |
| Tank room | B | Black or grey palette. |
| Tank room | F4 | The kit builder. |
| Sea | Tab | The HUD's modes. LIGHT has the HARBOUR section: gulls 0 to 30, sardines 0 to 6000, the plesiosaur's visit interval. SAVE keeps them. |
| Sea | P | The other pier. It also disarms the doors until you walk away from them. |
| Gull bed | 1 to 5 | The plinth gull's pose: glide, flap, flare, folded, stretch. |
| Gull bed | F / Esc | Follow a gull (again for the next one) / stop following. |
| Gull bed | T | Slow motion. |
| Gull bed | - / + | Fewer or more gulls. |
| Gull bed | Right drag, wheel | Orbit, zoom. |

### What is where

| Piece | File | Notes |
|---|---|---|
| The tank | `tank/tank_4d.gd` | Water 18.4 x 4.8 x 3.2 m and 7 m deep in W. One full-screen water pass. Contents turn through W. |
| Koi (16) | `life/koi_*` | Slice-drawn. Four live off the slice in W. |
| Eel | `life/eel_4d.gd` | Rests in its cave, patrols low over the sand, backs in tail first. |
| Crab | `life/crab_4d.gd` | Walks through W, so it comes and goes in different places. |
| Hammerhead | `life/shark_4d.gd` | Lofted pieces, baked. |
| Reef, arches, giant stones, dunes | `life/reef_4d.gd`, `life/dunes_4d.gd` | Lofted and baked under `life/baked/`. Load 0.7 s. |
| Weed | `life/weed_4d.gd` | About 600 long blades plus 3500 short turf blades: the pen's grass tech. |
| Bubbles, snow | `life/bubbles_4d.gd`, `life/snow_4d.gd` | Snow is 1500 drifting specks. |
| Gizmo | `room/tank_dial.gd` | The tank's W dial, shown in the circle. |
| Koi showcase | `room/koi_showcase_4d.gd` | 2.8 m koi in a holo field, Voxel Lab floating panel. |
| Fish wall | `room/fish_wall_4d.gd` | Seven turning cards over two panels. Names shrink to fit. |
| Research board | `room/wl_panel_source.gd` | Moving diagrams: waves, the tank, the koi, the weed, the cut. Live benchmarks. |
| Title wall | `water_lab.tscn` (Hall/Title) | "WATER LAB". |
| Sea | `seascape/` | Carried from `ramon/Water` with your tuning. Far sea to 900 m. The plesiosaur visits every 40 to 70 s at 2.5 to 4 m down. |
| Sardine school (3000) | `seascape/fish_school_4d.gd` | The pen's flock at a fifth scale. The plesiosaur is its hawk. |
| Gulls | `gull/` | See below. |
| Sound | `audio/bake_water_lab_sound.py` | Synthesized: four gull calls, the harbour bed, the tank hum. Nothing downloaded. |

### THE GULL (Ramon's emphasis: "the wings needs to work")

**The pieces.** Six lofted pieces: body, head with bill, tail, arm, hand, leg.
- They are baked once to `gull/baked/`. Only the joints move each frame, so nothing re-lofts.
- The right side is the left turned by `from_xw(PI)`.

**The poses.** Each pose is a set of joint angles, and a gull is always a blend of two.
- Glide: an M.
- Flap: 2.5 beats a second. The hand sweeps back on the upstroke.
- Flare: wings high and cupped, tail fanned down, legs reaching forward.
- Folded: the black tips crossed over the tail.
- Stretch: both wings straight up.
- Rigid pieces cannot Z-fold, so folding also shortens the arm, the hand and the chord.

**The behaviour.**
- Soars round the harbour with bursts of beats, banking into its turns.
- Comes in to land into the wind (from +x, off the sea), from a staging point downwind.
- On a perch:
  - looks round;
  - gives the long call (head down, then thrown back) or the laugh;
  - stretches and shuffles;
  - leaves with the alarm "kek".
- Lifts off when you walk within about 3 m, and settles at least 6 m from you.
- Gathers low over the sardines when the school rises.

**Perches (93 of them).**
- Both piers' rail tops and pier 2's end.
- The platform's ring.
- The pole's top.
- Both doors' lintels.
- They are rebuilt when the PIERS sliders change.

**Cost.** About 25 µs a gull a frame in script.

### Numbers

**Tank room.** Measured by the room runner's perf mode.

| Measure | Value |
|---|---|
| Frame median | 1.4 to 1.7 ms |
| Frame 95th percentile | 2.2 to 2.7 ms |
| Opens in | 0.75 s |

**Sea.** Vsync off, at the pier 1 door.

| Gulls | Frame median | Gull scripts |
|---|---|---|
| 12 | 2.1 ms | 0.28 ms |
| 20 | 2.3 ms | 0.5 ms |

The target was a median under 3 ms.

### Checked by frames (`smoke_test_output/water_lab/`)

**Tank room:**
- the room, the tank and all its life (koi close, eel on patrol, crab);
- turning the contents, feeding, the showcase and its panel;
- every fish wall card, the title wall, the research board's moving diagrams;
- both HUDs at 4K;
- the round trip from the lab to the sea and back, arriving at the far door.

**Sea:**
- the far sea, the plesiosaur near the surface;
- the school, at 800 and at 3000;
- gulls on the rails, the ring, the pole and the lintel;
- a gull flushed when walked up to, and the HARBOUR panel.

**Gull test bed:** every pose from five sides, and a full landing cycle.

### Not checked

- **The sound.** Nothing here can listen. The calls were checked by spectrogram: the pitch contours
  and harmonics are as designed. The levels are a guess: gulls -8 dB at 3 m, the harbour bed
  -16 dB, the hum -14 dB at the glass.
- **The editor view.** Nothing was opened in your editor. The new .tscn files (`gull/gull.tscn`,
  `gull/gull_test.tscn`) were written by hand. Godot adds their scene uid on first save.

## Questions for Ramon

1. **The sound.** Listen to the gulls and the two beds, and say if you want real recordings.
   Freesound has CC0 herring gull recordings. I can list some for you to pick (downloading needs
   your go-ahead).
2. **Retire `ramon/Water`?** The sea now lives in `WaterLab/seascape/`. The old folder is untouched;
   retiring it is your call.
3. **A menu entry?** `menu_final`'s catalogue has no water scene at all. Should the Water Lab (the
   tank room) get a card?
4. **Gull size.** The gulls are real size: 0.6 m long, 1.4 m across. From the sea's locked camera
   (10 m back) they read small. Scale them up for legibility, or keep them true?
5. **Sound levels**, once heard. All three are quick to change: `harbour_sound_db` on the sea's
   root, `volume_db` on the Harbour, and the hum's curve in `water_lab_4d.gd`.

## Round 2: Ramon's walkthrough (9 Oct)

### What he said (scale: one white floor square is 1 m)

**Tank room**
1. The entrance corridor is just the white opening. Remove the sci-fi door you enter through.
2. The path starts a little further back.
3. The left (blue, intro) wall moves 2 m to the left.
4. Cut at least 10 m out of the empty middle (the room's depth), so the aquarium comes sooner.
   Re-centre the intro panel on its wall, and the tank diagram (research board) on the opposite one.
5. Remove the "WATER LAB" title above the aquarium.
6. The aquarium goes up to the ceiling, with a grey roof block 1 m high at the top.
7. The spotlights over the aquarium move away from it.
8. The white ceiling panel above: keep it (the depth looks good).
9. Tab opens a dev HUD for the room's lights. It needs a layout, and every light separately, with its
   strength and softness. He will tune them himself.
10. The feed-the-koi booth becomes the Voxel Lab's small white floating panel that turns to you. E
    feeds.
11. BUG: using the feeding booth froze walking, and he could not get out.
12. The turning spot becomes a blue square (a circle intersects the tank).
    - The path moves back a little.
    - "TURN THE TANK THROUGH W" is printed on the square, in the lab's type and outline.
    - The gizmo stays.
13. Discoverability: he tried right drag forward and back to find the shark, and nothing happened.
    - Right drag forward and back slides through W; side to side turns.
    - A minimal live tutorial: a mouse icon with the right button lit, an arrow sliding forward and
      back ("slide through W"), and arrows to both sides (turn).
    - About the size of the character on screen, a little smaller. Simple, not crude.
14. A second gizmo under the first, showing the slice turning the other way (the tank's rectangle
    narrowing from one side).
15. V near the shark aligns the tank so the shark is in your slice.
16. Fish wall: subtle white blueprint lines on the dark blue behind each fish.
17. RULE: a blue wall always runs from the floor to the ceiling. This includes the fish wall's backing.
18. The showcase's panel:
    - You can walk through it; you shouldn't.
    - It should follow and tilt toward you like the Voxel Lab's.
    - It should face away from the pedestal, into the room.
19. The showcase is twice the size: pedestal and koi.
20. The showcase becomes a swap display.
    - Icons for the koi, the hammerhead, the crab and the eel, as on the new shooting range's panel.
    - The chosen one grows from small to large, with a details card.
    - Each swims in place in detail. The eel joins.
21. The ring diagram round the pedestal is blue, not light blue.
22. The exit door:
    - Only plain grey sliding doors inside the white opening.
    - A lighter grey seam instead of the cyan line.
    - No block above. A sign: "4D OCEAN SIMULATOR".
    - When it opens, the Voxel Lab's holographic blue doorway shows.

**Sea**
23. Real gull recordings in place of the synthesized calls.
24. No clanking in the harbour bed: it is not a real harbour, so waves only.
25. The sardines look huge. They should be smaller fish, more scattered; look at the pen's
    murmuration.
26. The door you arrive by is a white dev-texture enclosure with the same simple sliding door.
27. The height pole:
    - closer to the round platform;
    - the walkway's grey;
    - a darker grey cap.
28. Keep pier 1 and the round platform. Remove pier 2.
29. The platform:
    - It is a bit smaller.
    - Pier 2's "TURN THE SLICE" diagram goes in its middle, scaled up, as the only thing on it.
    - The green squares round the edge go.
    - A slowly moving animated line circle runs near the edge, a lighter blue.
30. Turning the slice on the circle: the circle does not turn, only the ocean.
31. The blue circle sits higher, or at least stops clipping. The line around it goes.
32. The white dashes on the path between the arrows are the same blue.
33. The gulls look really good, but they float a little above the rails when they land. They should
    stand on them.
34. A chunky fishing boat:
    - white tones, a little rusty;
    - metal poles and booms for handling fish;
    - bobbing on the waves with each wave setting;
    - cut by the 4D slice when you turn it.
35. Near the edge, a prompt once: "Oh wow, I should really look down and see what creatures I can
    spot."
36. No HUD at the start. Tab opens the dev HUD, the same as now, moved to the right.
37. The overlay everyone sees:
    - the navigation keys (no sprint);
    - sea presets 1 to 4, the current sea as one of them;
    - a key for the Gerstner;
    - detail noise always on, no key;
    - a metrics panel (swell, amplitude, wavelength, steepness, off W, slice tilt, FPS, iterations);
    - the mouse icon for turning.
38. The Gerstner looks wrong: dark patches on top clip with the sea under them, with no smooth
    transition. Make a Gerstner 2 and 3 to choose from (opacity ramping, or something better).
39. The two info pages ("waves through W / your slice / turn it" and "4D Water") stand on two walls,
    left and right, just past the door.
    - Big, as usual.
    - Then 1 m of white wall, with a ceiling: a short tunnel onto the pier.
40. The plesiosaur stays as it is (he loves it).

### The plan (60 steps)

**A. Research (1-5)**
1. The Voxel Lab's floating panel (how it follows and tilts) and its hologram doorway.
2. The Quantum Range console's icon selector.
3. The sea shader's Gerstner path (why it patches), and the pen murmuration's spacing.
4. Fishing boat references: an inshore trawler's hull, wheelhouse, gantry, outriggers, rust.
5. CC0 herring gull recordings: candidates with source and size. Downloading waits for Ramon's yes.

**B. Tank room shell (6-14)**
6. The west wall moves 2 m out. 10 m is cut from the middle (28 to 18 m deep), and everything south
   of the cut moves north.
7. The entrance's sci-fi door goes, leaving the white opening. The path starts further back.
8. The intro wall and research board are re-centred on their shorter walls.
9. Every blue wall runs floor to ceiling, the fish wall's backing included. The rule goes into the
   lab-look notes.
10. The title wall goes.
11. The tank goes to the ceiling: water from the stand up to a 1 m grey roof. It still meets the west
    wall.
12. The life is refitted to the taller water: koi, shark, eel heights, bubbles, snow, light shafts.
13. The spotlights move out over the room, aimed at the glass.
14. The paths are re-routed: the shorter room, the square, the showcase branch, the exit.

**C. Room dev HUD (15-17)**
15. Tab opens a light editor on the right.
    - A top-down layout of the room with every light numbered.
    - A row per light: energy, range, spot angle, softness.
16. SAVE and RESET use `water_lab_lights.cfg`, read back when the room opens.
17. Frames at 4K.

**D. Feeding (18-20)**
18. Find and fix the freeze at the feeding booth.
19. The console becomes the floating panel ("Feed the koi", E).
20. Frames: feed, then walk away.

**E. The turning square (21-27)**
21. A blue square replaces the circle, the path moves back, and the square carries the print "TURN THE
    TANK THROUGH W".
22. Right drag forward and back slides through W; side to side turns. The wheel turns the other way
    (zw).
23. A second gizmo under the first: the zw turn, the tank's rectangle narrowing from one side.
24. The live mouse tutorial: the right button lit, an arrow sliding forward and back, side arrows.
    Character sized; shown while on the square.
25. V aligns to the shark: the contents ease until it is in your slice. Shown when it is near.
26. R puts everything back.
27. Frames of each control.

**F. Fish wall (28-29)**
28. Blueprint lines on the dark blue behind each specimen.
29. Its blue backing runs floor to ceiling.

**G. Showcase (30-37)**
30. Twice the size (pedestal radius 3.7 m), in the new south-east corner.
31. The ring diagram in the lab blue.
32. The panel is solid, follows and tilts toward you, and faces into the room.
33. The selector: icons for the koi, the hammerhead, the crab and the eel, in the range console's style.
34. Each specimen swims or walks in place, big, in the holo.
35. Swapping: the old one shrinks away, the new one grows in.
36. A details card for each.
37. Frames.

**H. Exit door (38-41)**
38. Two plain grey leaves sliding inside the white opening, with a light grey seam. No frame block.
39. A "4D OCEAN SIMULATOR" sign above.
40. The Voxel Lab hologram doorway as it opens.
41. Frames.

**I. Sea layout (42-49)**
42. Pier 2 is removed: deck, rails, circle, page, door, perches, the P key and its sliders.
43. The arrival door becomes a white enclosure with the same sliding door.
44. The info tunnel: two thin walls past the door carrying the two pages, 1 m of white after, and a
    ceiling.
45. The platform:
    - smaller;
    - "TURN THE SLICE" printed big in its middle as the only thing on it;
    - the tiles and the line around it removed;
    - an animated line ring near the edge.
46. The platform is raised so it stops clipping. It stays set while only the ocean turns.
47. The pole moves nearer the platform, in walkway grey with a darker cap.
48. The path's dashes turn blue.
49. The edge prompt, once.

**J. Sea life (50-53)**
50. The gulls stand on the rails: the real rail tops are measured and the foot height is checked by
    frames.
51. The sardines are smaller and more scattered, with the pen murmuration's spacing.
52. The harbour bed is rebaked as waves only.
53. The fishing boat: a lofted 4D hull, wheelhouse, gantry and outriggers, white with rust. It bobs
    on the sea's own waves and is cut by the slice.

**K. Sea HUD and waves (54-58)**
54. No HUD at the start. Tab cycles the dev HUD, now on the right.
55. The overlay for everyone:
    - keys: walk, look, turn the slice, presets 1 to 4, G for the Gerstner;
    - detail noise always on;
    - a metrics panel;
    - the mouse icon.
56. Gerstner 2: the crest layer fades in by opacity instead of clipping.
57. Gerstner 3: another variant, chosen once the cause is known.
58. G cycles through off, 1, 2 and 3.

**L. Close (59-60)**
59. Test by playing both scenes: frames of every change, perf of both, the HUDs at 4K.
60. The handover, the memory, and commits by explicit paths. Then the real gull recordings, after
    Ramon's yes.

## Round 3: Ramon's second walkthrough (9 Oct)

Trym's note via Ramon: the sea's water tech was pulled from https://github.com/emilje/godot-water-shader
(read before finishing Gerstner 3).

### The plan (40 steps)

**A. Tank room fixes (1-14)**
1. Spawn facing into the room, not the wall: check the avatar's own facing against the rig's yaw.
2. Remove the cyan line on the tank (the stand's glow line).
3. The square's words pure white (the floor print boosts white, not the blue).
4. The square gets an inset outline: corner brackets with breaks between them.
5. Feeding:
   - no bottom strip at the booth;
   - the E prompt sits higher, in the middle of the screen;
   - "A pinch of food" stays.
6. The west wall's intro panel 1 m to the left (as you face it: south).
7. The fish wall's pages line up with the blue wall behind them (the offset).
8. The blueprint behind the fish:
   - a clean grid, no centre cross, circle or bottom ticks;
   - fainter lines.
9. The whole south wall blue (the one with the entrance).
10. The two fish pages centred on that wall between the doorway and the east end.
11. The fish pages printed on the wall itself: plain wall blue behind them, no brighter slabs.
12. The exit's hologram: the airlock behind it dark (black grid), so no room shows through.
13. The mouse tutorial loses its cord.
14. The route's frames and completed ticks in the arrow blue; the showcase's frame tighter round its
    pedestal.

**B. The showcase as a swap display (15-24)**
15. The pedestal bigger (round 2: twice: radius 3.7), the holo and the creature scaled with it.
16. Placed halfway between the tank's front and the south wall, closer to the east wall.
17. Its ring diagram in the lab blue.
18. The floating panel:
    - always turned to face you, wherever you are in the room;
    - solid;
    - its cyan lines removed.
19. The panel becomes a selector:
    - tiles for the koi, the hammerhead, the crab and the eel (glyphs drawn for each);
    - the arrow keys move between them, the chosen one lit;
    - the Quantum Range console's look.
20. Choosing one: the creature on the pedestal shrinks away, the new one grows in from life size.
21. Each creature swims or walks in place in the holo field: the big koi, the hammerhead (lofted, as
    in the tank), the crab, the eel.
22. A details card for the chosen one on the panel (its specs), E for more pages.
23. The wheel and right drag still turn and slide the creature through W.
24. Frames of each creature and the swap.

**C. In the tank (25-31)**
25. The two stone arches: one turned 35 degrees, the left one moved further left.
26. The big seaweed on the right (waving through the glass) moved to the left side.
27. A swarm of very small fish (the murmuration technique), slow, parting for the shark.
28. The light shafts and caustics: no cut sliding down the back wall (larger, or tiled).
29. The sand box under the dunes a hair smaller, so the two never clip.
30. Frames of the tank: the arches, the weed, the swarm with the shark through it, the back wall.
31. Perf of the tank with the swarm.

**D. The room's lights (32-33)**
32. Tab opens a light editor:
    - a top-down layout with each light numbered;
    - each light's energy, spread and softness;
    - SAVE and RESET.
33. Frames of it at 4K.

**E. The sea, round 2 continued (34-38)**
34. Finish the layout already written: pier 2 gone, the tunnel with its pages, the smaller platform
    with TURN THE SLICE, the pole, blue dashes, gulls on the rails, the edge thought.
35. The overlay (keys, the four seas, the Gerstner, the numbers, the mouse) and the dev HUD on Tab.
36. Gerstner 2 and 3 (3 after reading Trym's source); the sardines; the waves-only sound.
37. The fishing boat, riding the waves, cut by the slice.
38. Frames of every change in the sea, and its perf.

**F. Close (39-40)**
39. Every frame checked against both rounds' lists. The handover and memory brought up to date.
40. Commit by explicit paths. List the CC0 gull recordings (download only with Ramon's yes).

## Round 4: Ramon's walkthrough parts 2 to 4 (9 Oct)

Also: "make sure we're using Andrew's walker and W rotation settings from the playable world". The
walker, rig and ground-basis scripts were already the pen's own (e4ff9cb). The lab player overrode
the pen's settings, though: Q/E stepping through W was off, and the walk was slower with a soft
acceleration. Both scenes now use the pen's values.

### The plan

**A. The player (1)**
1. The pen's walk in both scenes:
   - walk 1.4, run 3.0, sprint 4.2, acceleration 12, turn 11;
   - Q/E steps through W at 0.3 speed.
   - In the tank room, stepping pauses only where E is taken (the feeding panel, the showcase panel).

**B. The tank and its gizmos (2-9)**
2. The gizmo panels: the z-W one goes on top, renamed "FRONT TO BACK"; the x-W one stays
   "SIDE TO SIDE" below it. Both boxes are drawn the same size, as matching views of one tank.
3. The left arch is 1.25x and turned about 35 degrees (the right arch keeps its round-3 turn).
4. The schooling fish are a little bigger and faster.
5. The shark prompt:
   - "V: Align with the shark" shows while the shark is about 70% in your slice and not yet aligned;
   - V slides the contents until it is whole;
   - it works anywhere in front of the tank.
6. More coral: red corals (sea fans, branching) spread through the tank. The purple ones stay.
7. More weed: denser clumps of the short and the long weed, unevenly spread. The current weed stays.
8. The fish wall: the Showa and the crab sit 0.5 m higher in their pictures. Kohaku and Ogon stay.
9. Frames of the tank: the gizmos, the arches, the fish, the corals, the prompt, then V.

**C. The showcase (10-14)**
10. The wheel on the pedestal slides through W again (it waited for a captured mouse).
11. The hammerhead's broken look when it first appears:
    - capture the swap frame by frame;
    - find the cause;
    - fix it, or label the modes if they turn out to be deliberate.
12. The crab higher on the pedestal.
13. Placed 1 m off the south wall (the crab/Showa wall) and 1 m off the east wall ("The tank"
    board). The path from the junction is extended to it.
14. Frames of the four creatures, the swap, the slide.

**D. The tank room's UI (15-17)**
15. The top-right toggle says "DARK MODE ON" / "DARK MODE OFF".
16. No white outline round the path arrows in dark mode: port the PathCreator kit's floor-swatch fix.
17. A small EXIT sign over the door out of the room.

**E. The sea (18-29)**
18. The tunnel: floor, ceiling and walls end on one line at the mouth, flush with the blue walls. No
    protruding floor.
19. The platform:
    - TURN THE SLICE redrawn square and centred;
    - no "it stays set" status in the top right.
20. The pole 5 m on and 3 m to the left (as you walk out).
21. Platform stability: the platform drawn with only the slice's own turn (the rig's tilt from its
    heading), so it does not swing left and right as you drag.
22. The boats, using the W Tools Exploder's real W distribution (not its static illusion):
    - two main boats, with more spread through W;
    - the one in your slice white with the lab grid, the others orange (the pen's orange).
23. The Gerstner's double lines: find the cause (the near/far seam? the foam band's two edges?) and
    remove them.
24. The storm:
    - longer, fewer crests with the same power;
    - less water over the platform.
25. Spray where a wave hits the platform, on the side it comes from, and wet patches that dry.
26. Labels:
    - "G: Toggle Gerstner";
    - "Press 1-4 ..." on the sea controls;
    - no developer controls shown (Tab).
27. More life below:
    - a group of three hammerheads cruising, now and then near the surface;
    - eels by the pole.
28. A second, deeper Loch Ness creature, subtle.
29. Frames of every change, and perf.

**F. Close (30-31)**
30. The handover and memory.
31. Commit by explicit paths.

### Status (9 Oct, end of round 4)

Done and checked by frames (`smoke_test_output/water_lab/room/u*`, `s*`; `seascape/v*`):
- **Player:** the pen's walk and W stepping in both scenes (`shared/pen_walk.gd`).
- **Gizmos:** FRONT TO BACK on top, SIDE TO SIDE below, equal boxes (u01).
- **Tank:** the left arch bigger and turned 35 degrees; six red corals; denser weed clumps; the
  swarm bigger and faster (u02-u04). The reef is now 325k tets (212k before).
- **Shark prompt:** shows at 70-98% visibility in front of the tank; V aligns (u05, u06; the
  log reads "shark visible 0.80").
- **Fish wall:** the Showa and the crab are lifted 0.16 and 0.14 of the picture's height (about
  0.5 m on the wall); the crab's studio camera is a little further back so its legs stay in
  frame. Kohaku and Ogon are unchanged (u07, u08).
- **Showcase:**
  - The wheel works without a captured mouse.
  - Each creature has its own W depth (koi 0.21, hammerhead 0.05, crab 0.6, eel 0.06 of its
    size), and a wheel step is a sixth of it. Before, one step was a fifth of the koi's depth for
    all four, which threw the thin hammerhead out of the slice in a single tick (s15, s16).
- **The hammerhead's first appearance:** frame by frame (s02-s14), the koi shrank away, then the
  shark jumped in at two-thirds size, because its life size is two-thirds of its display size.
  - It now grows in from nothing over a quarter second.
  - All four creatures' shaders warm up for four frames after the build, so none compiles on its
    first pick.
  - There were no hidden modes, so nothing was labelled.
- **Dark mode:** the label reads DARK MODE ON/OFF; the path arrows lose their white edge in dark
  mode (u09).
- **EXIT:** a separate EXIT text had split the "4D OCEAN SIMULATOR" lettering. EXIT is now the
  sign's small subtitle, "EXIT · TO THE SEA" (u10).
- **Tunnel:** the mouth is flush, with no protruding floor (v01, v02).
- **Platform square:** the page's type is fitted to the square; the title had run off its edge
  (v03).
- **Pole:** moved 5 m on and 3 m left (v04).
- **Platform stability:** the platform moved 0.005 m in view while the slice turned 31 degrees
  (v05).
- **Boats:**
  - Two white principals, plus their copies through W by the Exploder's layers, all white (Ramon,
    mid-round: "his copies in W should not be orange, just other boats, and those need to be further
    away"; then "those orange boats should not be visible in the default slice, but scattered a bit").
    Six other boats, orange, are scattered at random 35-85 m out and 3.5-9 m off the slice in W, so
    none shows level and a few degrees of turn bring them in (v16-v18).
  - They are not further out. At 100 m, a degree of turn moves the slice nearly 2 m through W, so a
    boat 3.8 m deep in W shows for only a degree or two. A first try at 80-140 m was never caught by
    the frames.
  - They are built simple (no tyres, rust, crates or stays), about 36 fewer pieces each.
  - The grid lines had read thick from a distance, because the boat swatch had about four times
    the kit's line contrast and a line is never drawn thinner than a pixel. The swatch now uses
    the kit's own contrast.
- **Gerstner:** style 2 (the default) uses the true normal everywhere, which removes the double
  lines; style 1 (the original) is kept on G for comparison (v08).
- **Storm:** 52 m wavelength with fewer crests (v09-v11).
- **Spray:** the first trigger asked for water within 1 m of the 2.8 m deck, which no sea here
  reaches, so the storm frames showed no spray.
  - Measured at the rim: the water tops out near 1.5 m in the moderate swell and 1.8 m in the storm.
  - It now fires on the top tenth of each sea's own recent crests at the rim (at least 0.8 m),
    judged afresh when you change the sea. A hit throws 50-120 drops, spread along two metres of
    the rim and fanned in over the deck; the hardest wet the deck (v19-v21). The last run measured
    18 bursts in about forty seconds of swell and 19 in ten seconds of storm.
- **Life below:**
  - The hammerheads now swim between 0.8 and 4.5 m deep, on a loop 9-19 m from the platform's middle,
    so they pass close without going under it. Before, their 22 x 15 m loop never came within 11 m.
  - The eels sit just under the surface, 0.5-1.4 m deep; deeper, the dark water hid them.
  - The second plesiosaur stays deep and subtle.
- **Perf, on the platform:** frame median 3.29 ms (95% 4.01 ms), GPU 1.82 ms. The far boats had
  pushed it to 4.85 ms; the simple build and the twice-a-second riding off the slice brought it back.

### Round 4 sound: Ramon's gull recordings (9 Oct)

He saved four of Beison's seagull recordings into `ramon/audio/sfx/` (AAC, which Godot cannot import;
the originals stay there). His notes: "dont make it too crazy, make a good mix", and the ambient one
should "loop and fade in and out at places".

Converted with ffmpeg into `WaterLab/audio/`: 44.1 kHz, 16-bit WAV, each peak matched to the
synthesized calls' (-3 dBFS).
- `gull_call_real.wav`: "Gull Tweeting", mono, 0.55 s.
- `gull_takeoff.wav`: "Bird Taking Off", mono, 2.2 s.
- `gull_flock_off.wav`: "Birds Flying Away Wings Flapping", mono, 1.7 s.
- `harbour_gulls.wav`: "Harbor Ambience Rain Distant Gulls Squawking", stereo, made to loop.
  - The AAC's header says 20.9 s, but it decodes to 23.8 s.
  - Its last 2 s are crossfaded (equal power) into its first 2 s, leaving a 21.8 s loop with no seam.

The mix:
- **Calls:** each call is the recorded call or the synthesized long call, chosen at random. Calls
  keep 0.45 s apart; a call that comes sooner is dropped. The laugh and the landing rustle stay
  synthesized.
- **Take-offs:** the recorded take-off replaces the old synthesized alarm "kek". Three or more gulls
  lifting within 0.6 s play one recorded flock take-off, and the next 1.5 s of take-offs stay quiet.
- **The ambience:** plays under the sea bed (`harbour_gulls_db` -10, about 8 dB under the lap bed).
  - Every 12-30 s it picks a new level: full (45%), half (35%) or nearly gone (20%).
  - It eases there over about six seconds and is never cut.
  - The recording has rain in it, which sits in with the wash at this level.

## Round 5: every animal a true 4D loft (9 Oct)

Ramon found the koi "behave strangely" when the tank turns through W. Only the hammerhead and the gulls
were true 4D. The koi, eel, crab, the tank's swarm and the sea's sardines were 3D meshes, and their
shader only shrank each animal whole as it left the slice (`shared/slice_draw.gdshaderinc`, the
pen starlings' trick). His verdict: "that is a big problem. For the animals also the aquatic, they
need to be true 4D lofts." I chose the shader route for frame time when I built the lab, and never
told him in plain words. It is the opposite of what the lab is for.

His answers: **fewer, all true 4D** (the swarm and the sardines become schools of 60-150 lofted fish,
measured), and **koi first, start now**.

### The plan

**Koi** (`life/koi_loft_4d.gd`, its skin `life/koi_skin_4d.gdshader`, its colours
`life/koi_pattern.gdshaderinc`):
1. Lofted the hammerhead's way, from the old koi's profile. Seven rigid pieces: mouth, head, four of
   body, tail fin. The fins are thin in x and W, as the hammerhead's are. Baked under `life/baked/`
   at one body length; the body node is scaled by each koi's length.
2. Round across x and W (a 4D koi has two sideways directions); a turned slice cuts it shorter and
   thinner, the fins first.
3. The swim from the old shader, put on the pieces: the travelling wave, the C bend of a turn, the
   tail fin trailing; the pectorals on their own holders (tucked, out to brake, sculling); the mouth
   piece opening on a gulp.
4. The eight varieties painted per pixel by a fork of the engine's cross-section shader (the engine's
   own reads one 3D texture and ignores per-vertex colour). The patterns lie over a 4D back, so a
   turned slice crosses different patches of the same koi.
5. The tank's school (`koi_school_4d.gd`) poses one lofted koi per fish instead of writing herd rows.
   The fish in the slice settle exactly onto it in W (a lofted koi is visible only within its own
   half width of the slice; the old one showed across 0.21 of its length).
6. The showcase's koi and the fish wall's koi pictures (the wall: the CPU cut of the loft at w = 0,
   as its hammerhead).
7. Checked against the hammerhead, the slice turned 0/20/40/60/75 degrees in x-W and z-W
   (`scripts/_koi_loft_test_runner.gd`), then in the room. Frame cost measured.

**Eel and crab** next: the eel a lofted chain (many short pieces, its anguilliform wave); the crab a
lofted carapace with jointed legs and claws, each segment a rigid piece.

**Schools** last: the tank swarm and the sea's sardines as 60-150 lofted fish each, one or two
pieces a fish, the frame cost measured against the old 1,600 and 3,000.

Also on the old trick and not animals: the weed, the bubbles, the food pellets. A pellet or a bubble
is a 4D ball, whose cut really is a shrinking sphere, so the trick is exact for those. The weed is not;
it is a question for Ramon whether plants go the same way.

### Status (9 Oct, end of round 5)

Every animal in the Aquatic Lab is now a true 4D loft: rigid pieces lofted once by our loft builder,
baked under `life/baked/`, posed every frame. Shared helpers in `life/loft_kit.gd`.

| Animal | Script | Pieces | Tetrahedra |
|---|---|---|---|
| Koi (16 in the tank, 1 on the showcase) | `life/koi_loft_4d.gd` | 9 meshes: 6 of body with their fixed fins, eyes and barbels merged in, 2 pectorals, the tail | 16,192 |
| Eel (tank, showcase, 2 at sea) | `life/eel_loft_4d.gd` | 12 of body (with the long fin), eyes, pectorals | 27,828 |
| Crab | `life/crab_loft_4d.gd` | shell, eyes, 8 legs of 2, 2 claws of 2 | 16,320 |
| School fish (tank swarm 120, sea sardines 150) | `life/school_loft_4d.gd` | 2 a fish, posed straight from the flock's rows | about 600 |

- **The koi's colours:** a fork of the engine's cross-section shader (`life/koi_skin_4d.gdshader`) paints
  the eight varieties per pixel from the point's place on the 4D body (`life/koi_pattern.gdshaderinc`).
  The engine's own shader reads one 3D texture and ignores per-vertex colour. The eel, crab and
  school fish use 3D textures (`Kit.tex_material`).
- **Checked against the hammerhead, slice turned** (`smoke_test_output/water_lab/koi_loft/`, sheet
  `sheet_turns_close.png`): both cut the same way. Turned through x-W, a fish swimming along x
  shortens to a stub. Turned through z-W, the fins go first and the body stays.
- **In the room** (`room/r5_*`): the koi in the tank level and turned (x-W 20/40/60, z-W 35), a koi
  close, the showcase's koi and eel level and turned through W, the fish wall's koi, eel and crab
  cards (the true w = 0 cut of each loft: `life/koi_picture.gdshader`, `life/loft_picture.gdshader`).
- **The schools:** the flock (carried) steps on the CPU and draws nothing (`drawn` false, `rows()`); a
  lofted fish is only a few millimetres deep through W, so each school's spread through W is squashed
  in the flock node's basis. The HARBOUR slider now runs 0-300 (150 by default).
- **The research board's "IN 4D" page** said the fish were ellipsoids drawn like the starlings; it now
  describes the lofts, and its chart cuts the fins first.
- **Removed:** the stand-in shaders (`life/koi.gdshader`, `eel.gdshader`, `crab.gdshader`,
  `seascape/school_fish.gdshader`), the 3D mesh builders, and `scripts/_studio_test_runner.gd` (its
  experiment was concluded on 9 Oct). All in git history.

**Frame time, same machine, same pass** (`_capture_lab_runner.gd perf`; old = commit 2e63c9b in a
throwaway worktree):

| Where | Stand-ins | Lofted |
|---|---|---|
| Opening | 2.14 ms | 3.24 ms |
| At the tank | 2.63 ms | 4.19 ms |
| Showcase | 1.69 ms | 3.07 ms |

At the tank, the split (round5 r5perf): the koi about 1.3 ms (0.5 ms of it their swimming script), the
swarm about 1.2 ms (0.5 ms its CPU flock, 0.2 ms posing). Most of it is the per-frame work of moving
the pieces, not drawing them. Fewer swarm fish is the easiest lever.

**Gull sounds** (Ramon, mid-round: "i still hear the synth birds and not the real bird files i
provided"): the round 4 mix had kept the synthesized long call for half the calls and the laugh and
landing rustle synthesized. Now every call is his recorded call (pitch varied), landings his wing
claps quieter, take-offs and the flock take-off as before; the synthesized ones only if a file is
missing.

**Still on the slice-draw trick, not animals:** the bubbles, the food pellets and the marine snow
(4D balls, for which the trick is exact), and the weed (a question for Ramon: loft the plants too?).

**Known, not mine:** the koi glyph on the research board logs "Invalid polygon data, triangulation
failed" (since round 4); the `detail` capture's fish-wall position is stale (round 5 uses round 4's).

## Round 6: Ramon's walkthrough part 5, items 31 to 46 (10 Oct)

His priorities, in order: the broken interactions (31, 32), the rendering (41, 42), the sea's
architecture (46), the presentation (39, 45, 33, 34, 36, 43, 38, 37), the onboarding (44). Keep the
aquarium's interactions, the large pedestal (35), the water presets, the life and the storm (40).

### The plan, and what each item turned out to be

**Interactions**
- 31 Feeding. E fed, and E is also the pen walk's step through W, so the feeder switched stepping off.
  The feeding itself was invisible:
  - pellets 1.3 cm across, brown, scattered 10 cm through W, while each is a 4D ball only its own
    radius deep in W, so most were never in the slice;
  - they were dropped on the real surface near the ceiling, so the koi rose out of view.
  - Plan: F feeds, at the panel and on the turning square. The pellets are 6 cm and amber, dropped in
    your slice at the top of what you see, and sink straight down so they stay in a turned slice.
- 32 The shark's V.
  - The visibility looked only at how far the shark's middle sat off the slice, so a shark cut across
    (the tank turned, or the shark turning through W) read as 90%.
  - V only slid the contents, never turned them.
  - V off the square was undone the next frame.
  - Plan: measure the cover along the whole body. V turns and slides the contents so the shark's own W
    axis lies on the world's W (exact, in about half a second), then follows it.

**Rendering**
- 41 The square of water.
  - A fine 120 m grid inside a coarse ring, while the waves are still at full height at the seam.
  - The Voxel Lab fixed the same thing in its own subclass of the same carried script
    (VoxelLab/field/vl_sea_4d.gd).
  - Plan: that graded grid and the ripple fade, as an opt-in in the shared script (`graded_reach`,
    the shader's `detail_fade_far`), so the Voxel Lab could drop its own copy. Its files are not touched.
  - Also the sea floor out to 1800 m (a second, fainter square).
- 42 The hammerheads' see-through look and their loft circles.
  - Their frames were rebuilt each frame from the heading with a fixed "right", which mirrors the frame
    whenever the heading crosses the z axis (twice a lap). A mirrored loft is inside out.
  - The pedestal's hammerhead had the same flaw, facing the -x half.
  - Plan: frames carried on from the last (loft_kit.gd frame_for), on both.

**Architecture**
- 46 Only the platform was held in the set frame.
  - Plan: the pier, its rails, the tunnel with its walls and pages, the door and the route's marks held
    the same way.
  - The pole stays in the sea.
- 37 The tunnel open to the sky. The gulls sit on its walls' tops.

**Presentation**
- 38 One boat in the default slice: the right one.
- 45 The boats spread wide:
  - every two at least 34 m apart;
  - 70 m apart if their W is within 5 m;
  - W kept within a 14 degree turn of the platform, so each can be found.
- 39 The near-black parts in the grid: mid grey on white boats, a darker orange on orange ones.
- 33 The crab is the brown crab (Cancer pagurus, the species the loft was built as; "edible crab" is its
  other common name). Its card tilts toward the camera after the turn, not before.
- 34 The fish wall's turning animals swim (or walk). Each rigid piece of the loft is cut once, then
  posed every frame. This is exact: no pose turns through W.
- 36 The koi glyph's tail outline crossed itself, so it never triangulated and was never drawn. It is
  redrawn as a proper fork.
- 43 The platform's ring lines at 55% width (a new `ring_width` uniform, 1 elsewhere), 25 cm further out.

**Onboarding**
- 44 The shared mouse tutorial gains an opt-in intro:
  - large and acting for 10 s;
  - then over 0.9 s it eases into a still card docked above THE SEA, listing each gesture.
  - The tank room's tutorial is unchanged.

Checks: `_capture_lab_runner.gd round6` (frames `room/x*`) and `_capture_seascape_runner.gd round6`
(frames `seascape/w*`), with the numbers they print.

### Status (10 Oct, end of round 6)

All of 31-46 done. Checked by frames (`room/x*`, `seascape/w*`) and the runners' numbers (logs
`r6b_room`, `r6b_sea`).

**Feeding (31).**
- F feeds, at the panel and on the square. Q/E stepping stays on at the panel.
- 30 pellets fall at once. 4 s later, 29 were in your slice and 14 koi were feeding. With the tank turned
  25 degrees, the new pinch still fell wholly in your slice.
- The pellets are 9 cm across and strong orange. At 6 cm and amber they read as the marine snow.

**The shark (32).**
- The cover (`shark_cover`) counts the body as 60% and its hammer and fins as 40%. Those are 2 to 8 cm deep
  in W and go first: 5 degrees off the shark, the slice shows a finless lens, which the body alone had
  called 80%.
- The prompt comes up at 0.70 and goes below 0.60, only while the shark is on screen. That is about 2
  degrees of turn or 3 cm of slide off it.
- From 0.78, V made the shark whole (1.000) within 0.7 s on the square, and 0.998 off it.
- The maths check: of 300 random turns and headings, 253 can be reached, and all came out whole. The others
  ask more than 75 degrees, or more slide than the tank has. The follow lets go there.

**The sea (41, 42, 46).**
- No square seam in any frame: out to sea, both diagonals, the storm. GPU time is unchanged at 1.82 ms.
- The hammerheads' frames never mirrored over 30 s (least determinant 1.0).
- The structure moved at most 7 mm in view over 31 degree drags both ways. The first try moved 30 cm at
  the door: the heading's ease ran under 20 degrees, and a drag back across the middle passed under that.
  It now runs under 7 degrees.

**Presentation.**
- Boats: 9 in all, 1 in the level slice. The closest two are 36 m apart, and 86 m in neighbouring slices.
  A sweep of turns up to 16 degrees finds all 9, at most 4 at once.
- The boats' darker parts are mid grey on white boats and a deeper orange on orange ones.
- The fish wall's cards swim. The crab card is seen from above, its lift down to 0.06.
- The koi glyph has its tail, on the research board and the pedestal's tile.
- The ring is thinner and further out. The tunnel is open to the sky.
- The tutorial is big for 10 s, then docks in 0.9 s. Its big words fade in the first fifth, as the card
  narrows under them.

**For the Voxel Lab's window** (not touched here): `water4d_surface.gd` now has `graded_reach` and the
shader `detail_fade_far`, the same lattice and ripple fade that `vl_sea_4d.gd` builds for itself.
`vl_sea_4d.gd` could set those and drop its own `_build_grid` and its detail patch. Its other patches
(the shore foam) still fit: their lines are unchanged.

**Questions for Ramon.**
1. The shark prompt now waits until the shark is nearly whole, about 2 degrees off it. Earlier, the
   finless lens already showed it. Is that the right moment?
2. The crab's tile in the pedestal's selector still says "Crab"; its card says "Brown crab". Name the
   tile in full?
3. The pole by the platform still turns with the sea (it stands in the water). Hold it with the
   structure?
