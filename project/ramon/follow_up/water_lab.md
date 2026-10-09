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

## Status

(Filled in as the steps land.)

## Questions for Ramon

(Collected here, not asked mid-build.)
