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

## What to look at

Open `res://ramon/VoxelLab/voxel_lab.tscn` and press Play (F6). Every station is on the floor route.

1. **The way in.** The hall: the introduction (blue, left corner), the live research board (right
   corner, its numbers measured as the room loads), the shelf on the right, the block in the middle.
2. **The block's story** plays by itself as you come near (click or the arrows step through it): what
   it is, the voxel grid (each voxel a tiny tesseract), a ball and a box cut side by side and slid
   through W (one hole closes, one holds), a tunnel that is a tube, and a hidden room ana of your slice.
   All cut live. It hands the block back whole.
3. **The bench.** Step on the pad in front of the block, E. 1 to 4 ball, block, drill, saw (press, drag,
   let go); Q / E size; the wheel slides through W; right drag turns in 4D; G the voxel grid; V the
   volume view; R whole again at once; T switches to the engine's own way, so you feel the difference
   (the screen beside you times every cut); C outlines the chunks a cut made the engine mesh again.
4. **The shelf:** three specimens cut before you came (a half section, tunnels, the cavity opened).
5. **The column** (left, further on): cut its base in your slice and it stands, because the rest of
   its base is ana or kata of you. Cut through W too and it falls. E at its pad swaps it for a tree.
6. **The gallery** (the door at the back): Andrew's own test cases on pedestals. His landscape (a cube
   of it), his caves (finer noise than his scene's, so they show at this size), his 24-cell beside the
   same shape laid off the grid, and the resolution ladder (E times one cut at 20, 10 and 5 cm). The two
   blue walls say what they are and what still fails.
7. **The field** (THE FIELD, the gallery's far door): his landscape generated round you as you fly.
   WASD, Space / C, Q / E through W, [ and ] the load radius, click a crater, H back. The numbers on
   screen are the honest ones: flying is slow on purpose (see Open, 1).

B switches grey and black everywhere; F1 is the dev panel (the lights, the swap, the flashes).

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
- **`tools/make_scene.py`** writes `voxel_lab.tscn`: move a station or a light there and run it, rather
  than editing the scene. `run.sh` is the only way these scripts start Godot (it takes the lock).

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
3. **The lab light on the block's top** reads white rather than grey crust (the downlight straight
   onto a 0.63 grey). Left for your eye: F1, the hero's light.
4. **A cut is on screen 100 to 250 ms after the click** (a big saw, 500 ms): the engine's meshing and
   the worker's draw buffers. No frame waits for it, but you can feel the delay. Engine side, as 1.
5. **The caves case** uses finer noise than Andrew's scene (2 octaves on a 4-voxel scale): at his own
   scale a block this size held no tunnel at all.
6. **The story camera** (new): while a story plays and you stand still, the camera flies to each
   part's shot; move or look and it hands back. `story_camera` on the room turns it off.
