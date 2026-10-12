# Voxel Lab: plan (6 Oct 2026)

The voxel mining prototype remade as a showcase room: `res://ramon/VoxelLab/voxel_lab.tscn`. The old
`VoxelMining/` scenes stay as they are; nothing here loads or changes them.

**Ramon, 6 Oct:** "whatever we build 4denthusiast can come in with his experience and start
improvements and increasing resolution, things where we still have failed. so we could render the
basic setup, show what it is we want to do. be inspired by the voxel block and what that can do. and
just set that up. whilst exploring potential improvements." Then: "write the 70 steps and execute",
"take your time".

So the room has two jobs:
1. **Show what we want:** a 4D specimen you watch being cut, then cut yourself; tunnels, a clean saw
   channel, a hidden cavity, a column that falls. Bright R&D look and a dark one.
2. **Be the test bench for whoever improves it:** every cost measured on screen, the failure cases
   standing in a row, the resolution a setting.

The handover, with the questions for Ramon at the top, is `follow_up/voxel_lab.md`.

---

## 1. What we have, read first

- **The old block** (`VoxelMining/`, Aug-Sept): our own dual contouring in GDScript, ported from a
  teammate's demo marked all rights reserved. 8 grid points a side at 0.4 m, so a 2.1 m rock is
  about 5 voxels across; every hit takes a 1.2 m bite (smaller round bites leave one-voxel walls
  between diagonal craters, measured); about **180 ms a hit**, 6.4 s at 16 a side. What is worth
  keeping: grey crust over a hot orange core, so a cut shows where it went; the tuner that puts the
  cost on screen; the round versus boxy bite; the gem in a hidden cavity, revealed by occlusion alone.
- **The engine's voxels** (`engine/modules/4d/voxel/`, 4Denthusiast, Sept-Oct; Aaron's tidy-ups 3-4
  Oct): `VoxelWorld4D`, dual contouring in C++. Generators (box, plane, cylinder, cave, landscape,
  layered, clipped) build a world at load on worker threads; edits (sphere, box, parallelogram) write
  air or a material. It meshes in **8-voxel chunks, up to 16 a frame, on the main thread**; a new
  chunk mesh then builds its draw buffers on its first frame on screen. No collision, and from
  GDScript you cannot read a voxel back (only `is_voxel_defined`). Materials are flat colours from a
  palette.
- **Andrew's test scenes** (`sandbox/voxel_test.tscn` and `voxel_24cell_test.tscn`, 4Denthusiast, 4 Oct;
  he pointed us to the first, 6 Oct): an ocean plane under a fractal-noise landscape (height bands:
  stone, dirt, grass, their borders bent by 4D noise) clipped against caves (winding tunnels where
  three noise fields are all near zero). The 24-cell scene builds a 24-cell from 24 planes, his test
  of the fringe a surface makes when it runs through grid points. Their root script
  (`res://scripts/voxel_edit_tester.gd`) never reached git, and without it they load nothing (no load
  trigger): a black frame. With a trigger added in a runner they render: islands in a blue sea, brown
  where the caves break through, a different coastline a quarter turn into W.
- **Crosswise's rock** (`Crosswise/world/mk_plug_4d.gd`): the engine's voxels at 0.2 m, crust over a
  gold core by layered generators. A carve costs 0.5 ms to call and **80 to 140 ms the next frame**.
  Its answer: build the dented rock at load and keep it drawn, parked out of sight, then swap by
  moving it. A hidden mesh first shown costs the same 110 ms, so most of that frame is the draw
  buffers, not the meshing.
- **The Arboretum's smooth tree** (`Arboretum/botany/dc_tree_builder_4d.gd`): edits into a chunk that
  has not loaded yet are lost, so wait until the corners are defined; chunks read back into one mesh.
- **The pen's far room** (`chickenpen/cave/cave_far_stream_4d.gd`): the draw buffers of a mesh
  (`Mesh4D.get_proxy_mesh_3d`) can be built on a worker thread before it is shown: its first frame
  went from 141 ms to 17.

## 2. What the research says

- **4D Miner** (Mashpoe, [Steam](https://store.steampowered.com/app/1941640)): a 4D voxel mining game.
  The scroll wheel turns your slice; crafted 4D glasses show what is outside it. Our wheel and our
  volume view (V) are the same two ideas; it teaches by doing, which is the bench.
- **Teardown** and the voxel-destruction threads around it
  ([Unity forum](https://discussions.unity.com/t/want-to-recreate-teardown-destructable-voxel-physics/828648),
  [80.lv](https://80.lv/articles/this-real-time-voxel-building-demolition-is-so-satisfying/)): after a
  cut, look for voxels no longer attached to the ground and make them fall; Teardown also prototyped
  structural integrity. Our column needs neither: it is designed as two pieces, and we know every cut
  we made, so "how much of its base is left" is a sum, not a search.
- **Deep Rock Galactic** ([Wikipedia](https://en.wikipedia.org/wiki/Deep_Rock_Galactic)): the
  Driller's tools are verbs (drill, carve a tunnel). The bench's tools are named the same way.
- **Hit-stop**: freezing the action for 0.1 to 0.2 s at an impact measured best in an IEICE study
  ([2023](https://ken.ieice.org/ken/paper/20230315OCSt/eng/)); 50 to 100 ms on a heavy hit
  ([game-feel lesson](https://www.wayline.io/learn/game-feel/1)), longer reads as a hang. The engine's
  80 to 140 ms pause sits right in that window, if it lands on the impact.
- **Zylann's Voxel Tools for Godot** ([performance notes](https://voxel-tools.readthedocs.io/en/latest/performance/)):
  meshing runs on worker threads, the main thread gets a time budget (about 8 ms a frame), and the
  mesh block size trades draw calls against edit cost; its `VoxelTool` has `do_sphere` and
  `raycast`. That is the shape of what to ask our engine for.
- **Mesh on a worker, swap on the main thread** (a common pattern,
  [Voxel-Terrain-Game](https://github.com/Drew-Wagner/Voxel-Terrain-Game)): prepare the new mesh off
  the main thread, keep showing the old one, swap when ready, cap the swaps per frame.
- **Museum cutaways and thin sections** ([USGS Core Research Center](https://www.usgs.gov/index.php/core-research-center/resources-services)):
  a specimen is explained by sections through it. That is the shelf of pre-cut specimens on the way
  in.

## 3. The idea

**One room, one direction, one specimen you watch and then cut.**

You walk in past a shelf of three pre-cut specimens (a half section, a tunnel, an opened cavity), so
the room teaches even if you skip everything. The hero specimen stands on a pedestal in the middle,
enlarged: its story plays once as you come near, the specimen cutting itself (two cuts, a tunnel, the
hidden room), then it is made whole and handed to you. You step onto the bench pad in front of it and
cut it yourself, the costs on a screen beside you. Further on, a column you can cut until it falls,
and at the back the limits bench: what still fails, measured, for the engine's developers.

**The 4D lessons, one per beat:**
1. A ball cut and a box cut look the same in your slice. Slide through W: the ball's hole shrinks
   and closes, the box's keeps its size and then stops dead.
2. A tunnel is a tube with a W extent: step aside in W and it is solid rock.
3. A cavity can sit beside your slice: cut here and you hit rock; step ana and the same cut opens
   into it.
4. A column stands while any W of its base remains: cut your slice through and it still stands. Cut
   through W as well and it falls, maybe out of your slice altogether.
5. 4D detail costs the fourth power: twice the resolution is 16 times the voxels. That is why the
   specimen is small, and it is the number to improve.

**What it serves (startup.md section 3):** the lessons are intuition for players; the bench's tools,
grid and chunk views are approachability for developers; the measured costs and the limits bench
are technical feasibility.

## 4. Decisions I take unless told otherwise

1. **The name:** VOXEL LAB, running line "Cutting 4D matter". One word in its room data file.
2. **The kit is carried, not reused** (the rule for remakes): copied from the Arboretum's carried
   kit into `VoxelLab/carried/`, with a README of every change.
3. **The two looks are the kit's B switch** (grey or black surfaces under the lab light), as in the
   Creation Lab and the Arboretum, with the room fill dimmed in black so the specimens stand out.
4. **The specimen's colours follow the old block:** grey crust, orange core; plus a gold vein and a
   violet lining in the cavity, so every cut says where it went.
5. **No menu change:** the catalogue is shared and edited by other windows. Pointing the Voxel Mining
   entry here is a question in the handover.

## 5. The steps (70, and 6 for the open world)

Each part ends on a rethink. A **pivot** says what changes if a check fails.

### A. Measure before building (1-10)
1. **Folder and launcher.** `VoxelLab/run.sh`: the Godot lock taken in the same command that
   launches, released on exit, logs searched for errors (Crosswise's pattern, its own name).
2. **Probe: the specimen.** A chamfered crust-over-core block, 2.4 m wide, at 0.2, 0.15 and 0.1 m
   voxels: load time, chunk count, tetrahedra, video memory. Frames in the normal slice and turned.
3. **Probe: what a cut costs.** Ball, box and slab cuts, small to large, in a chunk's middle and on a
   chunk corner, vsync off: the worst frame after each and the chunks it touched.
4. **Probe: where the cost goes.** Meshing (the world's own frame) against the draw buffers (first
   frame on screen), separated by hiding the chunks before the cut and timing `get_proxy_mesh_3d`
   on its own.
5. **Probe: the swap.** Show the old chunks as stand-ins, hide the world's chunks before the cut,
   build the new chunks' draw buffers on a worker thread, swap all at once when ready. Worst frame,
   and 200 cuts in a row for stability. *Pivot:* if it crashes or saves little, cuts stay in the
   frame and the pause is staged as an impact (flash, chips, sound on that frame).
6. **Probe: aiming.** Our own copy of the specimen's shape (its recipe and every cut) marched along
   the mouse ray; the hit checked against the rendered pixels. *Pivot:* if it misses by more than a
   voxel, read the hit off the chunk meshes instead.
7. **Probe: chunk alignment.** The specimen laid so its middle is a chunk's middle: how many chunks
   the typical cut touches, against a specimen laid on the corners.
8. **Probe: reset.** A pristine spare kept drawn and parked; swap time; the cost of building the next
   spare in the background.
9. **Probe: the failures.** A cut thinner than a voxel that vanishes; a face lying exactly on the grid
   that frays (4Denthusiast's own 24-cell note); frames of both.
10. **Rethink.** Choose the resolution, the swap, and whether the story cuts live or shows pre-built
    states. The numbers go into the Status section below.

### B. The specimen system (11-20)
11. **The specimen world:** a wrapper round `VoxelWorld4D` built from a recipe: bounds, a load
    trigger, the palette, "ready" when its corners are defined. No `class_name`, the type name never
    written (the sandbox's terrain script still claims it).
12. **Recipes:** the chamfered block (box and planes), crust over core, a gold vein (a slab of planes
    clipped to the block), the hidden cavity a little ana with its violet lining; the column; the tree.
13. **Cuts:** ball, block, drill and saw as data: their engine edit, their shape for our copy, their
    bounds, and the voxels they remove.
14. **The shape copy:** the recipe's shape and every cut, for aiming, for the column's support and for
    counting voxels.
15. **The swap** from step 5, in the wrapper, with a switch so the limits bench can show both ways.
16. **Spares and reset:** a whole specimen always waiting, parked and drawn; R swaps it in at once.
17. **A record per cut:** the call, the frame it cost, meshing and draw-buffer time, chunks, tetrahedra
    now, voxels removed.
18. **Chunk view:** the chunks a cut remeshed flash for a moment, so you see the engine's 8-voxel
    blocks at work.
19. **Grid view (G):** the specimen's material swapped for one that keeps its colours and draws the
    voxel lattice on every face, so the resolution is visible.
20. **Runner and frames:** cuts of every kind, reset, aiming, the record. *Rethink:* does a cut read
    clearly from the bench's distance?

### C. The room (21-32)
21. **Carry the kit** into `VoxelLab/carried/` (README: source commit, every change).
22. **The plan of the room:** an entrance corridor, then the hall; the shelf on the left as you come
    in, the hero pedestal in the middle, its bench pad in front, the column further on, the limits
    bench at the back, the door back out.
23. **The sign and the room data:** VOXEL LAB over the doorway; title, lead, interactions.
24. **Lights:** one downlight per station and the sun, tuned in both looks; the dev panel (F1) to tune
    them live and save.
25. **The two wall panels:** the introduction (blue) and the research panel (live numbers).
26. **The cutaway shelf:** three pre-cut specimens (half section, tunnel, opened cavity), each with a
    small label, built at load.
27. **The floor route** (the carried PathCreator): entrance, shelf, pedestal, bench, column, limits,
    door; each destination marked done as you visit it.
28. **Player and HUD:** the kit's figure and camera, the control strip, B for the look, H to the menu.
29. **Look pass, grey:** frames from the entrance, the shelf, the pedestal, the bench, the column, the
    limits bench.
30. **Look pass, black:** the same frames.
31. **Cost of the room:** frame time and video memory with everything in it.
32. **Rethink** against the lab rules (Ramon, 4 Oct): text never resizes with distance, nothing in
    front of an exhibit, one obvious direction, cinema scale, the exhibit turns and the room stays.

### D. Watch: the story on the pedestal (33-42)
33. **The hero exhibit:** the specimen enlarged on the pedestal, turning slowly between stories,
    slid and turned through W by the wheel and a right drag (the kit's showcase).
34. **Part 1, THE SPECIMEN:** its size, voxels, chunks and tetrahedra as callouts.
35. **Part 2, VOXELS IN 4D:** the grid view on; each voxel a 4D cell, one smooth surface through them.
36. **Part 3, TWO CUTS:** a ball and a block cut side by side; the slice slides through W; one hole
    shrinks, the other holds.
37. **Part 4, THE TUNNEL:** drilled through; slid through W, it closes.
38. **Part 5, THE HIDDEN ROOM:** a cut on top dents it at W 0; slid ana, the same cut opens into the
    violet cavity.
39. **Part 6, YOUR TURN:** made whole again, and the bench pad lit.
40. **Shots and words:** a camera framing per part, the title card and callouts (the kit's presenter);
    no dashes in the lines.
41. **Plays once** as you come near; a click or the arrows step through; walking away finishes it.
42. **Frames of every part in both looks.** *Rethink:* the lengths and the words.

### E. Try: the bench (43-54)
43. **The bench pad:** step on and the camera docks round the specimen, the cursor shows, WASD orbits;
    F or Esc stands you back up.
44. **Aiming:** the cursor's ray finds the surface; the cutter's outline shows where it will cut, in
    the slice.
45. **Tools and sizes:** 1 to 4 (ball, block, drill, saw), Q and E for the size; the centred card shows
    the tool, a small diagram of what it does and its key.
46. **Ball and block.**
47. **Drill:** a tunnel along your view, as deep as its size.
48. **Saw:** press, drag and release to cut a clean channel between the two points.
49. **Feedback:** a flash and chips at the cut, a short crunch (made in code), the chunk view's flash.
50. **Reset (R):** whole again at once.
51. **Through W at the bench:** the wheel slides, a right drag turns, V the volume view, G the grid.
52. **The cost screen** (black glass, beside you): the last cut taken apart, a bar per cut, totals.
53. **A playthrough runner** that presses the real keys and drags the real mouse: every tool, a saw
    channel, a reset, leaving. Frames.
54. **Rethink:** is cutting satisfying? The three biggest problems in the frames, fixed.

### F. The column (55-61)
55. **The column station:** a round column (a sphere drawn out along Y, so round in X, Z and W) on a
    base, enlarged on its own pedestal, with its own bench pad.
56. **Its support:** from our copy of the shape, how much of its base remains, across X, Z and W.
57. **The fall:** the top is its own piece; it tips about the edge that is left, in the plane of up and
    the side it lost (which may lean into W), eases down, bounces once, throws chips and dust, and lies.
58. **The 4D beat:** cut through your slice and it stands ("62% of its base is ana of your slice");
    cut through W and it falls; if it falls ana it leaves your slice, and V shows it lying there.
59. **The tree:** a trunk and a crown on the same mechanism; 1 and 2 at the station choose.
60. **Reset** with spares, as the hero.
61. **Runner:** a cut in the slice only (stands), then through W (falls), then a fall ana. Frames.

### G. The engine's test cases, on pedestals (62-66)
(Ramon, 6 Oct: "combine the voxel mining with a testcase of [Andrew's] work featuring on different
pedestals". The limits bench became this row.)
62. **Three pedestals at the back,** each a specimen from Andrew's own test scenes (`sandbox/voxel_test.tscn`,
    `voxel_24cell_test.tscn`, 4Denthusiast, 4 Oct), credited: **the terrain sample** (his fractal
    landscape, ocean and caves, clipped to a 4D box: a core sample of his world), **his caves** on their
    own (winding 4D tunnels in a block), and **his 24-cell** (the fringe case, beside one laid off the
    grid).
63. **Each cuttable** at its own pad with the bench's tools.
64. **The failure cases, measured live** on black-glass readouts: the cut thinner than a voxel that
    vanishes, the fringe, the pause with and without the swap, the resolution ladder (0.2, 0.15, 0.1 m).
65. **What would fix each:** meshing off the main thread (shown working here, project side), a voxel read
    and raycast for GDScript, collision, and his edit-tester script, which never reached git. A short
    message for Andrew and Aaron in the handover.
66. **Runner and frames.**

### H. The open world (67-72)
(Ramon, 6 Oct: "maybe we can explore seeing an open world option". Six steps added to the 70.)
67. **Probe:** his landscape generated round a moving point: chunks, tetrahedra, memory and frame time
    against the load radius, with W bounded to a few chunks and without, with the swap and without.
    (First look, 6 Oct: a 48-voxel radius reached 2,085 chunk meshes and 5.1 million tetrahedra in 20 s,
    still growing, at 100 to 150 ms a frame.)
68. **The view:** through the back door, a balcony over his landscape generated round you, and a survey
    camera to fly (WASD, mouse, Q and E through W, the wheel turns the slice). No walking: the engine's
    voxels have no collision yet.
69. **Streaming with the swap:** new chunks hidden until drawable, so flying never stutters on them.
70. **The honest numbers on screen:** radius, chunks, tetrahedra, memory; how far we can see today.
71. **A crater from the air:** a big ball cut into the landscape, mining at terrain scale.
72. **Runner and frames,** both looks.

### I. Proof and handover (73-76)
73. **The whole visit,** played by a runner from the door to the balcony in both looks; a contact sheet.
74. **Costs:** frame time per station, the worst cut frames, video memory, against 8 ms.
75. **Docs:** the handover with its questions, `engine_capabilities.md`, memory.
76. **Commit** the folder and my docs by path. Not pushed.

---

## 6. Status

**Part A, first numbers (6 Oct, 0.1 m voxels, `probes/_probe_cut_runner.gd`).** The hero block (2.4 x
1.8 x 1.6 x 1.8 m): 107 chunk meshes, 234,000 tetrahedra (about 290 MB), loaded in 43 ms and meshed in
under a second. A cut the engine's way: the frame after it costs 13 to 135 ms, depending on the chunks
it touches (4 to 36). With the swap: the worst frame 19 ms, the cut on screen 25 to 140 ms after the
click, the draw buffers built on a worker in 10 to 107 ms. **The swap works.** A 6 cm saw kerf (0.6
voxel) vanished: the thin limit, now a limits-bench case; the saw's kerf is at least 1.2 voxels.

**Part A, decided (step 10).** 10 cm voxels for the block, the swap on. At 15 cm a small ball cut removes
nothing at all; at 10 cm the specimen is 290 MB and every cut still lands within 160 ms with no frame
over 22 ms. The story cuts live (the swap keeps it smooth); no pre-built states needed. The 1.5 to
2.5 s freezes in the first stress test were the lab's own chunk outlines (a new mesh per flash); they
now share one mesh.

**Run and seen (6 Oct, night).** Everything below has been run in the room by its runner, with frames
looked at in both looks (`smoke_test_output/voxel_lab/`): room, bench played with real input, column,
gallery, costs, looks, field. All pass.

- Part B: `specimen/` (recipe, cuts, the specimen world with the swap, spares, records, chunk flashes,
  the grid view's shader) and `vl_tet_ray.gd` (aiming through the engine's meshes, for noise).
- Part C: the kit carried (`carried/`, README), the room: hall, shelf, block, column, gallery, the
  field door; wall panels with a live research page; dev panel (F1). Signs read on black (step 30).
- Part D: the block's six-part story, cut live. Rethink (step 42): from the player's camera its cuts
  were a few pixels across, so the room now flies a story camera to each part's shot (step 40) and
  hands it back when you move or look. The block grew to 12 cm voxels, 2.9 m wide, for the same
  reason, keeping its voxel count; the tools work in voxels.
- Part E: the bench. Rethink (step 54): sitting now ends the pedestal's story (it went on cutting
  behind the bench); the pad's floating prompt is gone (it stood over the block).
- Part F: the column and the tree.
- Part G: Andrew's test cases. The caves use finer noise than his scene (his showed no tunnel at this
  size).
- Part H: the field. The trigger loads round the ground ahead of the camera (at the camera it reached
  only air), Andrew's sea shows, the light matches his (it was washed out lime).
- Part I: costs (step 74): room 1.8 to 4.5 ms a frame at every station, about 1.8 GB of video memory
  for all specimens; ten swap cuts worst frame 14 ms median, 32 max (engine's way 96 and 272).
  Docs (step 75): `follow_up/voxel_lab.md`, `engine_capabilities.md` (local), memory.

**Open:** in the handover's Open list. (A 126 ms "first cut" turned out to be the room runner saving a
frame in the same frame as the cut; the runners now keep the two apart.)
