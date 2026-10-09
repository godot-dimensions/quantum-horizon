# Phase Maze, remade (handover)

`project/ramon/PhaseMazeRemake/phase_maze_remake.tscn`, built 8 and 9 Oct 2026 from Ramon's brief: "phaze
maze remake ... rethink the gameplay, and rethink what's possible with the tech we have now ... build in a
new tscn". The old Phase Maze (`ramon/PhaseMaze/`) is untouched.

Beside the scene:

- `PLAN.md` holds the 80 steps, the evening research, the levels on paper, and round 2 (the journey)
  with its status.
- `RESEARCH.md` holds the study of the old maze, where Andrew's walker is used, prior art with
  sources, and the probes.
- `carried/README.md` lists what was copied from where.

## Questions for Ramon

None of these blocked the build; each has a default in place.

1. **Going live.** Should it replace the old Phase Maze in the menu, or sit beside it?
   - The catalogue is shared, so it is untouched.
   - A 10 s clip is ready: `PhaseMazeRemake/art/phase_maze_remake.ogv` (level 2's stair through W
     into the chicken hall).
2. **The other walkers.** Andrew's way of walking and seeing is the pen's only walk. The Creation
   Lab, the Arboretum and the Voxel Lab still carry the pen walker from before 7 Oct: world-W
   stepping, the body facing on the ground. Should they be brought up to date? They are other
   windows' work, so I have not touched them.
3. **The name.** It is still "Phase Maze". Keep it?
4. **The spot that follows the walker.** You were unsure about it. Tab now has it on and off, its
   strength in bright and in dark, its cone and its height. SAVE makes your numbers the defaults.
5. **Step speed.** Andrew's 0.3 makes a 6 m cell about 7 s of holding E. That slowness is what makes
   turning worth it. It is "Q/E step speed" on Tab.
6. **The settle.** After round 2 a drag stays skewed where you let go, as the old maze did. "Settle
   to quarter turns" on Tab snaps it back on release, if you would rather.
7. **The Dreamer's hall costs 4.35 ms a frame**, because the creature re-poses about 680 pieces every
   frame. The mazes cost 1 to 2.3 ms. Fine at 60 fps; a smaller scale would cost less.

Ideas not built (round 2 went to the journey):

- More "less tic-tac-toe": round rooms (only visually round: the physics is box-only), arches over
  doorways, light shafts in the indoor stretches.
- A hall reward made from the voxel lab's rocks, or the flock's starlings.
- Sound: the old maze had none, and neither does this.

## What to look at

- **Play it:** open `PhaseMazeRemake/phase_maze_remake.tscn` and press F6. You start in the lobby:
  1 to 6 picks a level, then ENTER.
- **The film:** `project/smoke_test_output/video/phase_maze_journey.mp4` (110 s).
  - The bot plays levels 2, 3 and 5 through the real controls.
  - The overlook, the lift, the stairs through W, and each reward hall with its beat.
  - An earlier film of round 1 is `phase_maze_remake.mp4`.
- **Dark against bright:** `smoke_test_output/phase_maze_remake/moods_sheet.png`.
- **Frames:** `smoke_test_output/phase_maze_remake/`. `journey/` covers the overlooks, the stairs and
  the halls; `probe_sheet.png` and `old_maze_sheet.png` are the research.

## Keys

| Key | What |
|---|---|
| WASD | Walk (in the slice you see). Shift sprints, Alt walks. |
| F | Turn into W: what is ahead swings into ana. F again: back to level. Facing along x, F shows z and W. |
| Q / E | Step through the hidden axis: slow and blind. The ruler says if the cell beyond is open. |
| Right mouse + drag | Tilt the slice freely (Andrew's). It stays where you let go. |
| R | Level the slice, keeping your W. |
| G | 4D sight: the next layer's walls as blue ghosts. |
| M | The map, cut along whichever axis your view hides, your forward up. |
| T | A hint, three steps: which way it hides; the next cell lit; the route for 5 s. |
| V | First or third person. |
| C | Chase or over-the-shoulder camera. |
| B | Dark or bright, as in the Creation Lab. Remembered. |
| Tab (or F1) | The tuning panel. **Numbers:** cameras, turns, step speed, ghosts, renderer, light, spot. **Colours:** every colour in the scene (the maze's surfaces and posts, the colour code, the lobby and halls, the console, the sky and light in each mood, the walker), live. SAVE keeps both; RESET THIS PAGE goes back. |
| Backspace | Restart the level. |
| 1 to 6, Enter | Levels, at any time. |
| L | Back to the lobby. |
| H | Back to the menu. |
| Esc, Esc | Let go of the mouse, then quit. |

## How it plays

- **The idea.** The maze's cells run along x, z and w. Every view through a cell is a flat maze. Level,
  you see the x-z maze. Press F and what was ahead is W: another flat maze, with the corridors that were
  hidden now in front of you. Stepping through W without turning (Q, E) works, but slowly and blind.
  That difference is the lesson.
- **The journey.**
  1. A level starts on the overlook, 14 m up over its start cell, railed. From there you look down
     over the whole maze. F there rearranges it into another flat maze below you.
  2. Stand in the cream ring and the lift lowers you in.
  3. At the exit you come out in a hall 48 m across. The stage's reward is there, huge: a flock of
     giant chickens, then a wolf pack, then the Dreamer.
  4. "STAGE COMPLETE": the camera pulls back and slowly circles, and the stats sit on a see-through
     card until you move.
  5. A blue panel shows the next stage's reward as a silhouette.
- **The levels:**

| # | Name | The new idea | Cells |
|---|---|---|---|
| 1 | Step | A dead end whose way on is through W (the old maze's idea). Indoor start, outdoor beyond. | 3 x 3 x 2 |
| 2 | Turn | A stair through W, three cells. You cannot step up it: turn, and it stands before you. | 3 x 2 x 4 |
| 3 | Both turns | Up a stair through W onto a mezzanine, and down another. Indoor ground floor. | 3 x 3 x 3 |
| 4 | Sealed room | The exit's room is closed in its layer; its door is next door in W. 4D sight. Indoor rings. | 3 x 3 x 3 |
| 5 | The cube | The giant one: a hall, two stairs through W, an indoor wing. 36 x 36 m. | 5 x 5 x 3 |
| 6 | Generated | A new maze every run (seed shown), irregular cell sizes. | 4 x 4 x 3 |

## How it is built

Everything is built in code from the root (`phase_maze_remake_4d.gd`); nothing generated is saved into
the scene. The scene holds the lab light, the lobby (a kit room), its two live wall panels and the spot.

| File | What |
|---|---|
| `phase_maze_remake_4d.gd` | The game: lobby, levels, overlook ride, clock and counts, breadcrumbs, hints, finish, hall and beat, keys, tuning, moods |
| `maze/maze_lattice.gd` | The maze model: the level format (sizes, heights, stairs, roofs), the solver, the validator, the generator, cells in the world |
| `maze/maze_builder_4d.gd` | Walls (one mesh each), floors, stairs, roofs, breadcrumb tiles, door marks, start and exit, the beacon |
| `maze/maze_journey_4d.gd` | The overlook and its lift, the reward hall, the rewards, the next-stage teaser |
| `maze/maze_view_4d.gd` | The cameras, F's quarter turn, the settle, R |
| `maze/maze_sight_4d.gd` | 4D sight: Combined, the next layer's walls allowed to project, the R&D renderers |
| `maze/maze_walker_build.gd` | Andrew's walker, built from the carried copies, in dark blue |
| `maze/maze_console_4d.gd`, `hud/*` | The console, the HUD (card, badge, ruler, keys, title, mood chip), the map, the Tab panel, the glyphs |
| `maze/maze_panel_source.gd`, `phase_maze_info.tres` | The lobby's two live kit walls (intro and research) |
| `maze/maze_style.gd` | The look: the Creation Lab's light and tiles, the pen's blue and orange, the dark mood |
| `levels/level_1..5.txt` | The hand-made levels (the format is at the top of `maze_lattice.gd`) |
| `carried/` | The kit, Andrew's walker, the rewards: copies, see `carried/README.md` |

## Proof (runners in `scripts/`, launched with `scripts/run.sh`)

| Runner | Proves |
|---|---|
| `_check_levels_runner.gd` | Every level parses, validates (route as drawn on paper), builds under 20 ms; five generated seeds too |
| `_solve_runner.gd` | The bot plays every level through the real keys (walk, F, Q/E, the lift, the stairs) at par. With `film`, in movie mode, it is the film |
| `_features_runner.gd` | Every key and option: the console, hints, map, door prompt, restart, Tab, renderers, F, V, C, G, L |
| `_perf_runner.gd` | Frame, script, physics and GPU time per level, view, 4D sight, first person and hall |
| `_capture_journey_runner.gd`, `_capture_moods_runner.gd`, `_capture_lobby_runner.gd`, `_hud4k_runner.gd`, `_smoke_runner.gd` | Frames: the journey, bright against dark, the lobby, the HUD at 4K, a smoke pass |
| `_capture_teaching_runner.gd` | Films the back wall's three pictures (`art/`) |
| `_probe_*`, `_study_*` | The research probes |

Last results (9 Oct):

- level check PASS;
- bot PASS, all six at par;
- features PASS;
- worst median frame 4.35 ms (the Dreamer's hall), the mazes 1.0 to 2.3 ms.

## 9 Oct afternoon: the colours page and the corners

- **Tab, Colours** (Ramon: "allow me to change all the colors used in the scene? and save"). One picker
  per colour, applied as you drag, saved with the numbers in `user://phase_maze_remake_tuning.cfg`.
  - **Surfaces** are edited by their main colour; their grid lines and their dark-mood twin follow in
    proportion (`maze_style.gd` `swatch_values`).
  - **Glows** are made through `Style.glow_material()` and registered, so a new colour reaches what
    is already built.
  - **The walker** is painted in place, part by part, because rebuilding him would leave the gait
    holding his old limbs.
  - Checked by `scripts/_capture_colours_runner.gd`, which sets your settings file aside and puts it
    back.
- **The corners** (Ramon: "the corners of the wall still clip in to each other"). A wall used to reach
  half its thickness past each edge, so where two met their faces lay in one plane and flickered,
  worst where a blue wall met a white one.
  - Every wall now stops short of its edges.
  - A slim post fills each edge where walls meet: along x, z or w, as tall as the tallest wall it
    holds, capped and colliding.
  - Walls touch nothing now. The posts are all one material and overlap only each other, so nothing
    shows.
  - Their colour is "Corner posts" on the Colours page.

## Traps met

- **Combined:** set the root's `World3D` only if it is null; replacing one prints "scenario is null".
- **Hue shift is wireframe-only.** Ghost colour rides on each wall material's `albedo`, which the lab
  grid shader never reads but the projected pass does.
- **`CapsuleShape4D`'s height is `full_height`.**
- **A texture made inside a `LabPrint.render` paint call** is freed before the canvas draws it.
  Load first, hold, then paint.
- **A const is not a property:** `get("LEVELS")` from outside is null. The root has `levels()`.
- **The pen walker's step-up looked only along x and z.** The copy looks along W too, so stairs
  through W climb.
- **A spot offset along z lights the walker from the hidden side in a turned view.** Hang it
  straight above.
- **Runners:**
  - A key sent with `Input.parse_input_event` lands a frame or two later. Wait for the turn to start.
  - In a fixed-rate film, make sure F took.
- **Reaching the exit takes you to the hall.** A bot walking to the exit must stop once the level is
  finished.
