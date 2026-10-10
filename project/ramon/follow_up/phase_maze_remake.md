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

**Round 3 (10 Oct), new:**

A. **H still leaves at once.** Esc now asks first; H is the labelled "BACK TO MENU" key, so I left it
   immediate (it does nothing while the Tab panel is open). Should H ask too?
B. **The default look.** Kept round 2's colours, with the cream floor marks (breadcrumbs, start and
   lift rings, roof lights) now a cool white. The stronger looks you described are one click away on
   Tab, Colours, START FROM A LOOK: BLUEPRINT (dark blue, white grid lines) and SIGNAL RED (deep red,
   white grid lines). Should one of them be the default?
   - If you pressed SAVE in round 2, your saved colours load instead of the new defaults (the cream
     comes back): pick a look or RESET THIS PAGE on the Colours page.
   - On BLUEPRINT the walker's dark blue sits close to the floor. Tab, Colours, THE WALKER recolours him
     (in Miegakure the character is the one warm, saturated thing on screen).
C. **The R softlock on the lift did not happen in my tests.** R in mid-air on the descending lift, in
   the level view and turned, always ended the ride on the ground. What I did find and fix is a float on
   the stairs through W (below). If it happens again, which level and what you did just before would
   find it.
D. **What F changes is still told by the cube badge only.** The survey's best aid for it is the Aquatic
   Lab's tank dial (a side section with YOUR SLICE as a line). Not built yet; the next step if the new
   ruler and plates are not enough.

**From round 2:**

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
| F | Turn into W: what is ahead swings into ana. F again: back to level. Facing along x, F shows z and W. On a blue plate it opens the way through W (the plate pulses and the F row lights). |
| Q / E | Step through the hidden axis: slow and blind. The ruler says if the cell beyond is open, and its needle moves while you hold them. |
| Right mouse + drag | Tilt the slice freely (Andrew's). It stays where you let go. |
| R | Level the slice, keeping your W. |
| G | 4D sight: the next layer's walls as blue ghosts. |
| M | The map, cut along whichever axis your view hides, your forward up. |
| T | A hint, three steps: which way it hides; the next cell lit; the route for 5 s. |
| V | First or third person. |
| C | Chase or over-the-shoulder camera. |
| B | Dark or bright, as in the Creation Lab. Remembered. |
| Tab (or F1) | The tuning panel (Tab or Esc closes it; the game takes no keys while it is open). **Numbers:** cameras, turns, step speed, ghosts, renderer, light, spot. **Colours:** every colour in the scene (the maze's surfaces and posts, the colour code, the lobby and halls, the console, the sky and light in each mood, the walker), live. SAVE keeps both; RESET THIS PAGE goes back. |
| Backspace | Restart the level. |
| 1 to 6, Enter | Levels, at any time. In the lobby a number chooses and frees the cursor; Enter or a click on START plays. |
| L | Back to the lobby. |
| H | Back to the menu. |
| Esc | Closes the Tab panel or the map if one is open; otherwise asks "Return to the main menu?" (Y or N, Esc is no). |

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
| `_check_walker_settings_runner.gd` | Every walker, rig, camera, gait, avatar and capsule setting against the playable world's (headless) |
| `_capture_colours_runner.gd` | The Colours page: live, saved, reopened, reset (your settings file set aside and restored) |
| `_capture_journey_runner.gd`, `_capture_moods_runner.gd`, `_capture_lobby_runner.gd`, `_hud4k_runner.gd`, `_smoke_runner.gd` | Frames: the journey, bright against dark, the lobby, the HUD at 4K, a smoke pass |
| `_capture_teaching_runner.gd` | Films the back wall's three pictures (`art/`) |
| `_round3_runner.gd` | Esc and its box (YES handed to a stand-in menu), the Tab panel's hold, the still console and its clicks; probes for F's turn, R on the lift and on a stair through W |
| `_capture_round3_runner.gd` | Frames of round 3: the lobby, the Tab pages, the three looks, the spot's softness, a blue plate, the beacon, level 6, the Esc box |
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

## 10 Oct: round 3, the walkthrough feedback

Ramon's three notes from playing it (Escape and the Tab panel, the level console, light and colour,
then navigation; the gizmo review; the blue squares, the softlock, the forced turn and level 6). The
plan and the gizmo survey are PLAN.md "Round 3". Every level, mechanic and route is as it was; the
Dreamer ("Azathoth") is untouched.

**Escape and the Tab panel**
- Esc closes the Tab panel, then the map, and otherwise asks "Return to the main menu?" (YES or Y, NO or
  N or Esc; Enter presses the lit button, which starts on NO). The game pauses behind it.
- It is `hud/maze_escape.gd`, a guard on the scene tree's root. From the menu, the menu used to hear Esc
  before anything in the maze (prototype_launcher's tree-order fix) and close it at once; the guard is
  added after the menu, so it hears Esc first. YES hands the menu an Esc through the menu's own `_input`,
  so it leaves the way it always did. It is never broadcast: the walker's rig quits the whole program
  on a stray Esc (the first test did exactly that). Run alone (F6), YES loads the menu scene, as H does.
  No menu file was touched.
- Tab (and F1) open and close the panel every time; Esc closes it too. While it is open the cursor is
  free, a click beside it does not grab the mouse, the walker stands still, and no game key (1 to 6,
  Enter, Backspace, F, R, G, M, T, L, V, C) or H does anything. Closing it puts the mouse back as it was.
- Every number has a plain name and a line under it saying what it does, in groups (camera; turning and
  stepping; 4D sight; sky light; spot; finding your way). "Sun" is "Sunlight strength", "Ambient" is
  "Shadow brightness".

**The spot**
- New on Tab: edge softness (the engine's own `spot_angle_attenuation`: 0.3 a crisp rim, 1.2 an even
  fade, 3.5 a soft glow; `round3_frames/05_*`), fade with distance, and reach.
- "Spot, dark" did nothing because it is the dark mood's strength: it only applies after B. Both
  strengths are named after their mood now, and the one in force says IN USE.

**The level console**
- It stands still: in the lobby's back left corner between the Phase Maze wall and the back wall,
  facing where you arrive; in the hall ahead and to the right of where you arrive. A plinth under it
  collides, so you stop in front of it.
- A number frees the cursor, so START can be clicked with it (a 4D ray from the cursor,
  `Camera4D.viewport_to_world_ray_*`); the crosshair still works with the mouse captured; a click
  beside the console goes back to looking. A prompt under it says the level chosen and ENTER, CLICK
  START, 1-6.

**Colour**
- Grid line colours of their own for the walls, the walls across W, the floor, the stairs and the roofs.
- Looks: ROUND 2, BLUEPRINT, SIGNAL RED (`round3_frames/04_*`).

**Finding your way** (the gizmo survey chose Crosswise's ruler and floors, the Lookout's labels and the
Aquatic Lab's card; PLAN.md says why)
- Every W layer's floor is tinted its own colour (blue, teal, violet, coral), and the W ruler under the
  view badge uses the same colours: "W LAYER 2 OF 4", where the exit is, each cell as long as it is,
  your needle moving continuously (it moves while you hold Q or E), Q and E pressed while held.
  "Floor tint by W layer" on Tab.
- The exit's beacon is solid only in the exit's own layer; in the others it is a hollow frame, with a
  label where it stands on screen: "EXIT: W LAYER 1 · 1 LAYER KATA (Q)".
- A move through W says so: "W LAYER 3 OF 3" in the layer's colour, and the ruler flashes.
- The blue plates: the one you stand on pulses; F's row on the keys strip lights ("turn: the way is
  HERE"; elsewhere "turn into W (no door)"); the first three times, a card acts out F and E or Q
  (`hud/maze_key_card.gd`, after the Aquatic Lab's mouse card).
- Level 6 (generated): a landmark floating high over one cell in each layer (a crystal, an obelisk, a
  frame, a stack), in its layer's colour and only in that layer.

**The forced turn after F, and the float on the stairs**
- F used to ease at a quarter turn's rate while the heading's snap to the corridor rode on the same
  ease, so a turn begun 30 degrees off took a third longer than the swing that holds the walking keys:
  you walked while the view kept turning. Now the whole turn takes "F turn duration", the keys come back
  as it lands (0.35 s, measured), and moving the mouse during a turn turns its goal too.
- On a stair through W the walker's body, deep in W, could rest on the next step while the level slice
  showed the one below: he hung in the air over a step you could not see. When the view comes back
  level on such a stair, his W is put on the step he stands on.

**Proof** (10 Oct): `scripts/_round3_runner.gd` (the controls, YES through a stand-in menu, and the
probes for the turn, the lift and the stair) PASS; the level check PASS; the bot all six at par; the
features run PASS; the mazes 1.2 to 2.5 ms a frame, the Dreamer's hall 4.37 ms as before. Frames in
`smoke_test_output/phase_maze_remake/round3_frames/` (`scripts/_capture_round3_runner.gd`, which sets
your settings file aside and puts it back).

## Andrew's walker and W rotation, checked against the playable world (9 Oct)

Ramon: "make sure we're using andrews walker and w rotation settings from the playable world".

- **The scripts are the pen's.** The walker, its camera rig, `GroundBasis4D`, the avatar and the gait
  are byte for byte the pen's at the copy point (11971e1), and still the pen's at HEAD (1131bb2
  changed only the pen's scenery). The copies differ only in what `carried/README.md` lists:
  - the preload name;
  - the colour exports;
  - the step-up also looking along W (for stairs through W);
  - a debug print removed.
- **The settings.** The pen's Player sets nothing on the walker or its slice turning, so both run on
  the scripts' defaults, in the pen and here alike:
  - W steps at 0.3 of the run;
  - the right-drag tilts the slice at 0.005 a pixel through `GroundBasis4D.sliced`;
  - the body faces through W.
- **What matches the playable world's scene:** the avatar, the gait, the capsule, the camera's
  renderer, W fade and lens (77.3°), and the pitch and zoom limits. R now levels the slice over the
  pen's 0.45 s.
- **`scripts/_check_walker_settings_runner.gd`** prints the comparison: 30 settings SAME, and these
  KEPT on purpose:
  - the chase framing (made for 6 m corridors, not the pen's open-field preset);
  - the arm coming all the way in;
  - the dark blue;
  - R keeping your W: the pen's R walks you to W 0, which in a maze goes through walls.

  The stride is the gait's own measurement at runtime, the same in both.

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
