# Voxel Lab: handover (started 6 Oct 2026)

The voxel mining prototype remade as a showcase room, `res://ramon/VoxelLab/voxel_lab.tscn`. The plan,
its research and its status: `VoxelLab/PLAN.md`. The old `VoxelMining/` scenes are untouched.

## Questions for Ramon

(Each was settled with the most reversible option and the run went on.)

1. **The menu.** The catalogue (`Menu/entries/catalogue.tres`) is shared and other windows edit it, so
   the Voxel Mining entry still opens the old `VoxelMining/voxel_mining_final_2.tscn`. Point it here?
2. **Andrew's edit-tester script never reached git.** His two test scenes (`sandbox/voxel_test.tscn`,
   `voxel_24cell_test.tscn`) load `res://scripts/voxel_edit_tester.gd`, which is in no branch and no
   commit. Without it they hold no load trigger, so they load nothing: a black screen on our machines.
   With a trigger added (in a runner only) they render. Worth asking him to push it.
3. ~~The column~~ settled (round 4): replaced by **Build it**, the 4D brick builder (your call, 9 Oct).
4. **The choice uses keys 1 and 2** (clickable too when the cursor is free, Esc). Would you rather
   click with the cursor held, or another key?
5. **The open world's edge.** The island ends where the build does, 40 m round the deck, cut straight
   (you see it from high up). Round the green land the sea hides it; round the desert and the lava
   there is no sea, so past the island is the grey of the sky. Options: the moving sea round those two
   as well (calm and pale as a salt flat, dark orange for the lava), or a coast that slopes into the
   sea before the edge (a change to the generator). Nothing done yet.

## What to look at

**Round 6 (10 Oct)**, parts 8 and 9 of your walkthrough, items 60 to 75: `VoxelLab/PLAN_ROUND6.md`.

- The gallery's title in two lines; **the big landscape keeps its square**: a drag sweeps its slice through
  W, back and forth, the pedestal never turns.
- **The open world:** narrower foam on the crests with smaller bubbles; a ninth preset, **Moderate swell,
  gentle**; the whole walkway holds still while you slice; the platform **lifts** (Space up, Shift down);
  the bird's **Shift dive** works; Tab's new **PROPS ON EACH LAND** window (trees, mesas, cacti, volcanoes:
  clumps, how many, spread, size); a **lighthouse** on the green island; the **red desert** (strata, mesas,
  saguaros, a red clay pan, no white) and the **lava field** (moving, glowing lava with a crust, embers,
  bubbles, little volcanoes); **the way back** named at the station (key 1 on the desert or the lava) and on
  screen; the world-switch performance written up (#74, no rewrite).

**Rounds 3 to 5 (9 Oct)**, each from a walkthrough of yours: `VoxelLab/PLAN_ROUND3.md`, `PLAN_ROUND4.md`,
`PLAN_ROUND5.md` (what you asked, what was done, the numbers). Round 5:

- **Build it**, the front-left corner: a 4.6 m square pedestal, a black construction grid, 0.5 m bricks on
  a 7 x 5 x 7 grid with 5 W layers. Click places, LEFT drag looks round it, right drag turns the slice,
  wheel the next W layer, 1 to 3 brick / through W / take away, Q/E colour, Z undo, Space levels the
  slice, R starts again from the sand doorway.
- **The open world's sea** is one graded mesh (no square edge), the Aquatic Lab's water used from its
  folder (`field/vl_sea_4d.gd` extends it); **Tab** has the Aquatic Lab's controls (its presets as
  buttons, its eight water settings, OURS / THE AQUATIC LAB'S to compare), the shore foam, and the grass.
- **Grass patches** on the island: the pen's grass carried (`carried/grass/`), six patches near the
  platform, blades 2.2 times the pen's width; Tab switches them.
- The landscape turned to face you, with the hologram's gradient; Specimen 01's panel by its ring; the
  open world's route ends short of the platform, in the platform's own blue.

Round 2 (9 Oct), from Ramon's walkthrough of 8 Oct: the plan and what he asked for are in
`VoxelLab/PLAN_ROUND2.md`. Open `res://ramon/VoxelLab/voxel_lab.tscn` and press F6.

1. **The way in.** No light in the corridor. The route runs straight to a quiet junction level with
   specimen A; nothing plays as you walk up to anything.
2. **The block.** Straight on, the big ring in front of it. Standing there you choose: **1 Watch the
   presentation** (it cuts itself live, a camera framing each part; Esc stops it, a click or the arrows
   skip) or **2 Cut it yourself** (the bench, as before: 1 to 4 tools, Q/E size, the wheel through W,
   right drag turns, middle drag or WASD orbits, R whole again, F or Esc stands you up). Its floating
   panel stands beside it: walk into it and it swings away and settles.
3. **The shelf (A, B, C).** From the junction, right to A's small marker, then along the shelf past B
   and C. A click at a marker opens a small pop-up about that specimen.
4. **The right wall** ("The block", now blue): its ring at the end of the shelf run, after a 45 degree
   turn. The research page shows the block's frame in 4D turning through W, and your cuts' times.
5. **The back.** Left from the right wall: a junction (the gallery door is through it) and on to the
   **left wall** ("Voxel Lab", now blue). Then up the left side past **the column**: its ring offers
   **1 Watch it fall** (cut through your slice it stands; cut kata it falls; then it is whole again).
6. **The gallery: how his world is made.** On the right, three small pedestals, one of his generators
   each, in the order they combine: the land (fractal noise in bands), the caves (tunnels where three
   noise fields meet zero), the land with the caves carved out; a pop-up at each. Then the whole world
   on a big square pedestal, sea included, sunk so you see the land: **1 Cut it yourself, 2 Change the
   land** (green, a Nevada desert, a lava field). The two blue walls say the same: how a world is made,
   and the whole world. All of it in our voice (Ramon, 9 Oct: "we're a team"); Andrew's credit is small,
   on the world's floating panel and the open world's loading board.
7. **The open world.** The far door is a hologram, the pedestals' own shift effect. Through it, a
   full-screen loading board in the lab's blue (what is coming, and the chunks being built on a map with
   their numbers) while an island of our landscape is built round a survey deck; then white, then the
   deck (the lab's blue, railings from the engine's fence generator) in Trym's moving sea. The lab has
   the same board while its specimens build. You look first: nothing on screen. At the deck's front
   left floats the helm, a ring in front of it; stand in the ring: **1 Fly over it as a bird**, **2
   Change the land** (green, desert, lava; green to and from the others builds again behind the board).
   The bird flies from its eyes, the Lookout hawk's feel: mouse to steer, W flap, S brake, Space climb,
   Shift dive, **right drag turns the slice** (up to 30 degrees), R brings it home, Q/E through W, click
   a crater, 1 back on the deck. It stays in a circle (a hologram wall shows the edge and you are turned
   back), above the land and the sea. **Tab: the sea's settings**, SAVE keeps them
   (`field/voxel_field_sea.cfg`); the gallery's pedestals paint their water in the same colour. The
   shimmer behind you on the deck takes you back.

**The lights:** one soft light on each item, nothing else. F1 opens the dev panel; its **LIGHTS** page
is a top view of the corridor, hall and gallery with every light and its pool: click one to pick it,
drag it to move it. Sliders for the hall and the gallery (every light in them), specimens A, B and C's
own strength, and the picked light's own. **SAVE** writes `voxel_lab_lights.cfg` (and the settings).

## How it is built

- **`specimen/`**: the engine's voxels, wrapped.
  - `vl_recipe.gd`: a specimen written twice from one recipe, as the engine's generator stack
    (layered boxes, planes, cylinders and Andrew's landscape and caves) and as our own copy in
    GDScript (the engine keeps its voxels to itself; GDScript can only ask whether one is loaded).
  - `vl_cut.gd`: ball, block, drill and saw, each as the engine's edits and as a shape for our copy.
  - `vl_specimen_4d.gd`: one VoxelWorld4D with **the swap** (below), spares, a record per cut, chunk
    outlines, and the grid view's material.
  - `vl_cutter.gd`: the bench's tools from where the mouse's ray meets the surface.
  - `vl_tet_ray.gd`: a ray against the engine's own chunk meshes, for noise our copy cannot follow.
- **`stations/`**: what stands on each pedestal (the kit's showcase holds it): the block and its story,
  the shelf's pre-cut sections, the column and the tree, Andrew's test cases.
- **`room/`**: the bench and its screen, chips and sounds, the grid view, the wall panels' live data,
  the dev panel (F1), consoles, cards, floor marks and route targets.
- **`field/`**: the open world: the island built once round the deck (`vl_stream_4d.gd`, its trigger
  fixed at the middle), the deck and the helm, the bird (`vl_bird_4d.gd`), the height map it flies over
  (read off the built meshes on a worker while the board is up), the sea and its panel
  (`vl_sea_panel.gd`). Trym's sea is carried in `carried/water4d/`, with a graded grid (fine near you,
  a kilometre out) and the waves calmed toward the far edge.
- **`carried/`**: the lab kit, carried from the Arboretum's carried copy (its README lists changes).
  The walk and the camera are the pen's as of 8 Oct (Andrew's stepping and facing, the floor-frame
  camera), carried again; the room never turns (slice turning off), and a right drag turns only the
  exhibit, floor-only like the pen's slice drag: across tilts its width into W, up and down its depth,
  so nothing leans.
- **`voxel_lab_4d.gd`**: the room: which pedestal you are at, the pads, consoles, route, views, and the
  story camera (`_run_film`).
- **`room/`, round 2:** `vl_choice.gd` (the choice pill), `vl_popup.gd` (the small pop-up),
  `vl_float_panel_4d.gd` (the floating panel on its spring), `vl_lights.gd` (the light rig and its
  file), `vl_light_map.gd` (the LIGHTS page's top view), `vl_shimmer_4d.gd` (the blue doorway).
- **`tools/make_scene.py`** writes `voxel_lab.tscn` and both floor routes (`paths/*.tres`) from one
  layout: the spots you act at (Spots/*, with their options in metadata), the lights, the panels, the
  rings. Move anything there and run it, rather than editing the scene. `run.sh` is the only way these
  scripts start Godot (it takes the lock).

## The swap (the improvement this room explores)

The engine meshes an edited chunk on the main thread, and a new chunk mesh builds its draw buffers
(the 3D proxy the renderer draws) on the first frame it is on screen, also on the main thread. That
first frame is most of the pause after a cut. The swap: before a cut, the chunks it will touch are
hidden behind stand-ins showing their old meshes; the engine meshes them while hidden (a hidden mesh
never builds its draw buffers); the new meshes' draw buffers are built on a worker thread
(`Mesh4D.get_proxy_mesh_3d`, as the pen's far room loads); then all are shown in one frame and the
stand-ins go. Measured on the block (12 cm voxels, ten cuts each way, `_perf_room_runner.gd`): the worst
frame after a cut 96 ms (median) and up to 272 ms the engine's way, 14 ms (median) and at most 32 ms
with the swap; the cut shows about 110 ms after the click either way (slowest 235 ms).

Spares and rebuilds are built hidden too, and they share the main thread with the engine's meshing:
their load radius grows in over three seconds, and they stand still while any cut in the room is on
its way to the screen (a spare meshing in a cut's frames made it cost 126 ms).

The open world used the same idea to stream (every new chunk hidden until a worker had made it
drawable) until 9 Oct; now it builds once, behind the board, and nothing builds while you fly.

## For Andrew and Aaron (draft message)

> The Voxel Lab (RamonPrototypes, `project/ramon/VoxelLab/`) shows the engine's voxels cut live, with
> four things measured that you may want:
> 1. **Meshing and draw buffers off the main thread.** A cut's frame is mostly the new chunk meshes'
>    proxies being built when they first draw. Project side we hide the touched chunks behind their old
>    meshes, build the new proxies on a WorkerThreadPool (`get_proxy_mesh_3d`), and show them together:
>    over ten cuts on a 116,000-voxel block, the worst frame after a cut went from 96 ms (median; up
>    to 272 ms) to 14 ms (up to 32 ms). Doing this in VoxelMeshHandler4D (keep the
>    old mesh until the new one is drawable; mesh on workers as chunk generation already is) would give
>    every voxel world it.
> 2. **A voxel read and raycast for GDScript.** We keep a copy of every specimen's recipe and cuts just
>    to aim the mouse and count voxels; for noise generators we ray-test the chunk meshes' tetrahedra.
>    Something like Zylann's `VoxelTool.raycast` and a `get_voxel_material(voxel)` would remove both.
> 3. **Andrew's `scripts/voxel_edit_tester.gd`** is not in the repo, so `sandbox/voxel_test.tscn` and
>    `voxel_24cell_test.tscn` load nothing here (no load trigger). Could you push it?
> 4. **Your 24-cell fringe case** stands in the lab's gallery beside the same shape laid off the grid,
>    and every lab specimen is laid off the grid for that reason.
> 5. **Streaming your landscape** (the field, through the gallery's far door): meshing new chunks on the
>    main thread is what limits it. With the swap (new chunks hidden until a worker has built their
>    draw buffers) the median frame flying at 6 m/s over a 48 m radius is 1.9 ms against 149 ms
>    without, but one frame in four to six still runs 60 to 250 ms while new chunks arrive (16 a frame, up to
>    about 8 ms each). A time budget per frame in
>    `VoxelMeshHandler4D::update_dirty_meshes`, or meshing on the worker threads that already generate,
>    would fix it. Also handy: `set_process(false)` on a VoxelWorld4D pauses its loading and meshing,
>    which the lab uses to keep a spare's meshing out of a cut's frames. (Since 9 Oct the lab's open
>    world builds an island once instead of streaming, so it no longer shows this; the numbers are from
>    the streaming version.)

## Open

1. **The open world no longer streams; it is an island, built once** (Ramon, 9 Oct: "how it builds as
   you're moving, is that correct? rather just fly as a bird ... limited in a circle"). Streaming
   stuttered whatever we did: the engine meshes new chunks on the main thread (item 5 of the note).
   Built once instead, 40 m round the deck and 16 m either side of W 0 (so a turned slice still has
   land in it): 656 chunks, 2.0 million tetrahedra, about 2.4 GB of video memory, 8 s behind the board,
   the ground mapped in 0.2 s. Flying over it, turning the slice: median frame 2.2 ms, worst 5.6 ms, no
   frame over 16.7 ms in 5,100 (the streaming field: one frame in three over 33 ms). The price is the
   memory and that the island ends: past 40 m there is no land, only the sea (and for the desert and
   the lava, the grey of the sky; question 5). `BUILT_RADIUS` and `W_CHUNKS` in `voxel_field_4d.gd`
   trade one for the other. Earlier streaming numbers: radius 16 m, 66 chunks, about 210 MB; 24 m,
   170, 490 MB; 32 m, 252, 860 MB; 48 m, 600, about 2 GB (one band of W).
2. **Runners: never save a frame in the frame of a cut.** Reading the screen back stalls that frame
   (about 110 ms here), and the cut's record is charged for it: a "126 ms first cut" chased for an hour
   was the room runner's own screenshot. Both bench runners now wait a moment after a save.
3. **The lights' first values are mine** (soft downlights; the small pedestals' cones narrower, the
   terrain's wider and softer). Set them on the dev panel's LIGHTS page and SAVE.
4. **A cut is on screen 100 to 250 ms after the click** (a big saw, 500 ms): the engine's meshing and
   the worker's draw buffers. No frame waits for it, but you can feel the delay. Engine side, as 1.
5. **The column is gone** (round 4): Build it stands in the front-left corner instead (round 5: bigger,
   on a grid). Its exhibit and runners are deleted.
6. **Gone from the gallery** (round 2): the 24-cell and the resolution ladder. The gallery now shows how
   his world is made, layer by layer, and then the world.
7. **The field is a deck, not ground to walk on**: the engine's voxels have no collision yet, so you
   walk on the floating deck and fly over the land; the bird keeps off the ground by a height map read
   off the built meshes, not by physics.
8. **The sea.** Trym's, as the Water Lab (on screen: the Aquatic Lab) has it, used from its folder since
   round 4 (`carried/water4d/` deleted); round 5 builds it as one graded mesh and patches its shore foam
   from our side (`field/vl_sea_4d.gd`), without touching the Water Lab's files. The land's own sea is air
   under it, so there is no voxel water, only seabed. Its numbers are on Tab and in `field/voxel_field_sea.cfg`
   once saved; my first values: 1.1 m over the land's sea level, the Calm preset at 0.4, a kilometre
   out, the waves calm from 120 m to flat by 320 m. Its cost did not show in the frame time (2.2 ms
   median flying with it).
9. **Switching to the open world prints six engine errors** ("scenario is null", from
   `get_tree().change_scene_to_file` in `to_field`): the lab's off-screen panel viewports freed with the
   scene. Nothing on screen comes of it; not chased yet.
10. **The grass costs** +0.7 to +1.0 ms of GPU at 1280 x 720 (from the deck, close to a patch) and 0.045 ms
   of CPU a frame (`field/_measure_grass_runner.gd`); not measured at 4K, where it will be more.
11. **The grass's ground** is baked from the island's chunk meshes under each patch (grass material only)
   on a worker thread after the island is built; the patches are picked off the bird's height map. If the
   island changes (BUILT_RADIUS, the generator), the patches move with it.
12. **Green to desert or lava builds the island again (6.4 s measured, behind the board)**; desert to lava is a
   repaint. The land is the same in all three, only the generator's sea differs (empty under our water, or
   filled as the clay pan or the lava). Making every switch instant means drawing those two as a plane like
   our water: about half a day, written up in `PLAN_ROUND6.md`. Keeping two islands built doubles the 2.4 GB.
