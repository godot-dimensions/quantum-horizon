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
3. **The column (round 2):** kept as a watched fall that works every time. Keep it, or something new
   in its place (you offered "something completely new")?
4. **The choice uses keys 1 and 2** (clickable too when the cursor is free, Esc). Would you rather
   click with the cursor held, or another key?

## What to look at

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
   their numbers) while the landscape builds behind it; then white, then the survey deck over our
   landscape, the same generators without edges. The lab has the same board while its specimens build. **1 Fly over it** (H lands you), **2 Change the land**; the shimmer behind you takes you
   back.

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
- **`field/`**: Andrew's landscape streamed round a flying camera.
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

The same idea streams the field: every new chunk is hidden until a worker has made it drawable.

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
>    which the lab uses to keep a spare's meshing out of a cut's frames.

## Open

1. **Flying over the field still stutters, and the rest of the fix is in the engine.** The swap takes
   the draw buffers off the main thread: at a 48 m radius, flying, the median frame is 1.9 ms with it
   and 149 ms without (T in the field switches). What is left is the meshing, on the main thread, 16
   chunks a frame at up to about 8 ms each: one frame in four to six still runs 60 to 250 ms while new ground
   comes in. The field flies slowly and grows its radius in over 8 s. Measured: radius 16 m, 66 chunks,
   172,000 tetrahedra, about 210 MB; 24 m, 170 chunks, 400,000, about 490 MB; 32 m, 252 chunks,
   708,000, about 860 MB; 48 m, 600 chunks, 1.6 million, about 2 GB. (Item 5 of the note below.)
2. **Runners: never save a frame in the frame of a cut.** Reading the screen back stalls that frame
   (about 110 ms here), and the cut's record is charged for it: a "126 ms first cut" chased for an hour
   was the room runner's own screenshot. Both bench runners now wait a moment after a save.
3. **The lights' first values are mine** (soft downlights; the small pedestals' cones narrower, the
   terrain's wider and softer). Set them on the dev panel's LIGHTS page and SAVE.
4. **A cut is on screen 100 to 250 ms after the click** (a big saw, 500 ms): the engine's meshing and
   the worker's draw buffers. No frame waits for it, but you can feel the delay. Engine side, as 1.
5. **The column stayed, watched** (round 2): it falls every time now. Something new could replace it;
   that is your call (question 3).
6. **Gone from the gallery** (round 2): the 24-cell and the resolution ladder. The gallery now shows how
   his world is made, layer by layer, and then the world.
7. **The field is a deck, not ground to walk on**: the engine's voxels have no collision yet, so you
   walk on the floating deck and fly over the land.
