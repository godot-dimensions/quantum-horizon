# Slice Garden: the Miegakure remake (handover)

`project/ramon/MiegakureLook/Remake/slice_garden.tscn`. Ramon's brief item 6, built 5-6 Oct 2026.
The plan, with its status and the pivots taken on the way, is `MiegakureLook/Remake/PLAN.md`; the
research is `MiegakureLook/Remake/RESEARCH.md`. The old prototype (`MiegakureLook/levels/`, the menu's
"Slice Vision") is untouched.

## Questions for Ramon

None of these blocked the plan.

1. **The menu.** The catalogue (`Menu/entries/catalogue.tres`) is a shared file another window is
   editing, so Slice Garden is not in the menu yet. Should it replace the "Slice Vision" launch, or sit
   beside it?
2. **The sky.** The garden uses the Creation Lab's light, as you asked, and with it the lab's dark
   navy sky, which outdoors reads close to black. F1, SKY, "Sky lift" lifts it toward Miegakure's pale
   mint. Which do you want? (Save in the panel and it becomes the default.)
3. **Camera.** 10.5 m back, 54 degrees down, 32 round, a 32 degree lens: the little guy is about 45 px
   tall at 720p (68 at 1080p), about Miegakure's proportion, and each island fills the frame. Closer
   shows him better and the island less. F1, CAMERA, to try it; SAVE keeps it.
4. **4D sight (V)** is off by default (Miegakure shows one slice only). On, it draws the crates, the
   cage, the rocks and the shrine faintly where they are in the worlds beside yours. Keep it as a key,
   or switch it on for the first island as a teaching aid?
5. **Not mine, noticed in passing:** a 264 MB `EpicInstaller-20.3.3-unrealEngine.exe` sits in
   `chickenpen/audio/sfx/` (untracked); and `project.godot`'s main scene points at the playable world
   instead of `menu_final` (uncommitted, another window's).

Ideas outside the plan (not built):
- PathCreator routes as the hint layer (plan step 54 asked for it; the painted signs, the W-cue dots and
  the text hints did the job, and you called the path system "just an idea").
- A second onlooker who reacts on the cage island ("thief!", as Miegakure's temple NPC does).
- Sound that tells you a rock or crate is near in W (Miegakure changes its sounds by W distance; the
  plate and bridge already fade with W here).

## What to look at

- **Play it:** open `MiegakureLook/Remake/slice_garden.tscn` and press F6. Keys: WASD walk (in the
  world you see; A/D are always X), Space jump, right mouse or Tab turn into W, E lift or put down, left
  mouse strike, R restart the island, F a hint, V 4D sight, F1 the artist dev panel, H back to the menu.
- **The film:** `project/smoke_test_output/video/slice_garden.mp4` (82 s, with sound): the opening shot
  down the garden, then the solver bot playing all four islands to the finale.
- **Frames:** `project/smoke_test_output/miegakure_remake/` has `look_sheet_1.png` and `look_sheet_2.png`
  (the islands), `solve/` (every beat of the solve), `tools_sheet.png` (the dev panel and 4D sight),
  `before_sheet.png` (the old prototype, for comparison).

## The four islands

| # | Island | The beat |
|---|---|---|
| 1 | **The Wall** | On the lab-blue start platform, the explainer is painted in white. A gate wall stands in every lane but +2 (marked teal, a red torii). Turn into W, walk ana two lanes, turn back, walk through. The onlooker, who sees only lane 0, loses you ("?") and finds you on the far side ("!"). Then, in plain 3D: a terrace too high to jump, a crate at its foot, a dashed mark where it goes. |
| 2 | **The Cage** | A crate in a cage closed in X and Z but open along W; its footprint is painted in every other lane. Stand on it in lane -1, turn: the cage's open sides face you. Walk in, lift, carry it out through W, put it on the yellow plate: the bridge slides out over the chasm. |
| 3 | **The Seam** | First a rock across the landing (plain 3D, two strikes). Then a fence stands across W the length of the island, with the bridge on in lane +2; its one door is plugged by a rock. A striped band marks the door's Z: stand on it, turn, strike twice, walk through. |
| 4 | **The Shrine** | The terrace is railed everywhere but lane 0; the crate waits in lane +2; lane +1 has no floor near the terrace. Carry the crate back to where lane +1 has floor, cross, put it on the mark, climb, walk to the shrine door: the tower's lamps light and the camera pulls out. |

## How it is built

Everything is built in code from one node (`slice_garden_4d.gd`); nothing generated is saved into
the scene.

| File | What it is |
|---|---|
| `slice_garden_4d.gd` | The game: builds it all, tracks the island, checkpoints, falls and R, hints, 4D sight, the finale, the sound wiring, `blocked()` / `blocker()` for putting crates down |
| `world/mk_garden_4d.gd` | The four islands, their railings (walls between pylons, a plain fence every fourth), signs, outlines, crystals, the shrine and tower |
| `world/mk_build.gd` | The vocabulary: boxes with colliders, slabs, FenceGenerator4D bent into walls (X-W, Z-W, across W), cages, crates, towers, roofs |
| `world/mk_env_4d.gd` | The Creation Lab's light, its one spot over the walker, the turned sky, all in `values` for the dev panel |
| `world/mk_crate_4d.gd`, `mk_plate_4d.gd`, `mk_bridge_4d.gd`, `mk_plug_4d.gd` | The crate (fence-built), the plate (polled), the sliding bridge, the two-strike voxel rock |
| `world/mk_sign_4d.gd`, `shaders/mk_decal.gdshader` | Signs painted on the floor: key caps, the mouse, W-cue dots, panel type |
| `world/mk_fx_4d.gd`, `world/mk_sound_4d.gd` | Chips and rings; sounds (quieter by W distance) |
| `shaders/mk_surface.gdshader` | The lab grid (or a dev texture) laid along the axes you see, the W lanes, the W-face tint, the near-W-edge tint, hazard stripes |
| `scripts/mk_camera_4d.gd` | The diorama camera, the quarter turn into W, the opening shot |
| `character/` | The walker (copied from the pen: avatar, gait), his hands (lift, carry, place, hammer), his feet (shadow, key rose), the onlooker |
| `hud/mk_hud.gd`, `hud/mk_tuner.gd` | The HUD (view badge, W ruler, keys, prompts, titles, hints), the F1 dev panel |
| `run.sh` | The lock-gated launcher (`batch`, `wait`); launch from a copy |

## Measured (6 Oct, RTX 5080, 1280 x 720, vsync off)

- About 1 ms a frame on every island (95th percentile 1.1 to 1.4 ms), the same during a turn; the GPU
  0.3 to 0.6 ms. The scene is ready in 1.2 s.
- A strike: 0.15 ms to call, one frame of 12 ms after the first strike (the dented rock swapped in),
  3.7 ms after the shatter. A voxel carve at strike time cost 80 to 140 ms: see the trap below.
- FenceGenerator4D builds: 3 to 13 ms each (51 ms for the cage's bars), all at load.

## Tests

All run through `run.sh` (they take the Godot lock and wait their turn):

| Runner | Proves | Last result |
|---|---|---|
| `scripts/_solve_runner.gd` | all four islands solved through the game's own code, a frame at every beat; `film` records the movie | 18 of 18 |
| `scripts/_badpath_runner.gd` | a fall, a fall carrying the crate, a refused put-down, a strike at nothing, R after a broken rock, two quick turns | 11 of 11 |
| `scripts/_capture_tools_runner.gd` | the F1 panel and 4D sight, by real key presses | 4 of 4 |
| `scripts/_perf_runner.gd` | frame times per island, a turn, strikes | see above |
| `scripts/_capture_islands_runner.gd`, `_capture_intro_runner.gd` | every island in both views; the opening shot and a turn | frames |
| `probes/_probe_*_runner.gd` | the walker, the fence designs, the voxel rock (plan steps 4-7) | all pass |

## Traps found (also in `engine_capabilities.md` where they are engine facts)

1. **A node added to a running tree has run `_ready` before you set its properties.** The camera
   never followed and its turned slice sat at z 0, through the gate wall; the walker did not turn his
   movement into W. Resolve such links when first needed. Seen only by looking at frames: three
   "different" turned frames were the same picture.
2. **Node4D has no `top_level`.**
3. **A voxel edit's remesh is a 80 to 140 ms frame**, and a mesh first shown after being hidden builds
   its draw buffers then, at the same cost. Build variants at load, keep the waiting one drawn and
   parked out of sight, and move it into place.
4. **A FenceGenerator sheet's filler posts fill its whole face**: a wall's face seen head-on (after a
   turn, standing inside its W range) is a grid of posts. Expected, but surprising the first time.
5. **Movie Maker mode** shows as the `movie` feature (`OS.has_feature("movie")`), not as
   `--write-movie` in the script's arguments: the first film came out silent because of it.
6. **Patterns follow the view.** A floor mapped by X and Z smears into stripes once turned into W;
   map by X and the view's own depth axis (the shader works it out from the model-view basis).
7. **A railing at the foot of a terrace** blocks the crate's mark and the climb; the solver bot found it.
