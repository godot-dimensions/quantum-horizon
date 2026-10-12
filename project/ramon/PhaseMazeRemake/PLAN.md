# Phase Maze remake: the plan (8 Oct 2026; built tonight)

The research is in `RESEARCH.md`, with sources. The frames are in
`project/smoke_test_output/phase_maze_remake/`:
- `old_maze_sheet.png`: the old maze;
- `probe_sheet.png`: the pen's walker in 4D maze cells.

The old Phase Maze stays as it is. The remake is a new scene,
`PhaseMazeRemake/phase_maze_remake.tscn`.

## Evening research (8 Oct), and what it changed

A second probe (`scripts/_probe_turns_runner.gd`, frames in `smoke_test_output/phase_maze_remake/turns/`)
and a read of the engine settled the risky parts:

- **The settle works.** A drag let go 23° off a quarter turn lands on it exactly, in 0.12 s at 4 rad/s,
  with Andrew's own `GroundBasis4D.rotated_toward`. The nearest quarter is the best of the 24 turns of
  a cube in the floor's (x, z, w). I'll ease it over about 0.25 s so you can see it happen.
- **The F swap works.** The heading snaps to the corridor, then the way you face swings into W, and
  the walker turns with it, facing through W.
- **5 m walls work.** The chase camera no longer sees over them in a turned view.
- **0.4 m walls cut cleanly mid-turn.** 0.2 m ones broke into slivers.
- **The hue-shift fade only exists in the wireframe renderer.** Combined and Projected fade ghosts by
  distance in W but never colour them. Instead, the ghost pass colours a wall with its material's
  plain `albedo`. The lab shader multiplies that same albedo into the solid wall. So my copy of the
  shader leaves albedo out: albedo becomes the ghost colour (cyan), and the solid wall stays white.
- **Ghost only the cells next door.** Walls are merged per cell and per direction (about 80 to 150
  meshes for a level, far under the shader-slot limit), not per layer. 4D sight can then allow just
  the cells beside yours along the hidden axis. Of those, it ghosts only the walls you would see
  after the step, never the ones across your own path through W, which would fill the view as a
  haze box.
- **The copied camera rig has keys of its own:** T locks on to chickens, R walks you home to W 0, and
  Tab cycles cameras. All three are exports, so the maze switches them off and handles R, T and Tab
  itself. The copy stays unedited.
- **The range's spot hangs fixed.** Here it follows the walker: the kit's light re-aims itself
  whenever it is moved.
- **The range's F1 panel saves into the project folder.** The maze's saves to the user's settings
  instead.
- **A second web study** (`RESEARCH.md` section 6) changed six steps:
  - **The view badge (58)** becomes a small axis gizmo, as 4D Toys draws it: lines that point where
    each axis points on screen, the hidden axis as a dot into the screen, and W always cyan.
  - **The W ruler (59)** says whether the cell beside you through W is open, before you step. 4D
    Miner's players asked for exactly that.
  - **The map (57)** is cut along whichever axis is hidden, so its panels always match the flat maze
    you see. Panels cut by W stop matching after a turn.
  - **Breadcrumbs (27)** fade with age, and a dead end you have finished is marked done. Plain tinted
    tiles helped on the first pass in Ruddle's study, then cluttered so much that people walked twice
    as far.
  - **Hints (56)** cost nothing and are not counted on the card. Players avoid hints that feel like
    punishment.
  - **The camera (34)** pitches down as it pulls in, and the walker fades when the camera is right
    behind it. The ideas are Nesky's and Valve's.
- **All six levels exist on paper and solve** (the solver is a Python sketch of steps 12 to 15; the
  grids are at the end of this file). Turning beats stepping by about two to one on every level.

## The idea in one paragraph

The old maze is a flat maze with three gaps hidden at certain W values. You find each gap by watching
a number while holding Q or E, so W works as a combination lock, not as space. The remake is a maze
in four directions: its cells run along x, z **and** w. The trick that makes it playable is that
**every view through a cell is an ordinary flat maze**. Looking level you see the x-z maze. Turn the
way you face into W and you see a different flat maze, x-w, with the corridors that were invisible
before now running straight ahead of you. You walk a 4D maze by choosing, at each crossing, which flat
maze to look at. Stepping through W without turning (Q/E) still works, but it is slow and blind:
Andrew's step, at 0.3 of the run. The contrast between the blind step and the turn that shows you
the way is what the maze teaches.

## Decisions, and why

1. **Third person by default, first person on a key.**
   - Probe frame 1: in 4 m corridors the pen's own camera is pushed into the walker's back.
   - Frame 3: in 6 m cells a high chase camera shows the walker small and low, with the way ahead clear.
   - The walker matters in 4D: Andrew's W-thick body and its facing through W show how your slice is
     turned, and a first-person view has nothing to show it with.
   - The prior art agrees: Miegakure and 4D Golf use an outside view. The first-person 4D Miner drew
     the most complaints about getting lost.
   - First person stays one key away (V), because it reads cleanly (frames 6 and 7) and some people
     will want it. Tab switches the third-person camera between chase and over the shoulder.
2. **Andrew's walk and view, copied from the pen** (steps 3 and 33 to 43): stepping along the view's
   W, facing through W, W-thick parts, the right-drag tilt. The maze adds two things on top:
   - **F, a quarter turn:** the way you face swaps with W, animated, as Miegakure's one button does.
   - **Turns settle to the nearest quarter when you let go of the drag.** Half-turned views of a grid
     maze are slivers (frame 2), and 4D Toys and 4D Golf both stay on quarter turns for that reason.
     F1 can switch the settle off.
3. **The Creation Lab look:**
   - lab light with one spot;
   - grid floors and white walls, 5 m tall so no camera sees over them (frame 4);
   - the kit's colour code: yellow for start, green for the exit, cyan for anything about W;
   - a blue teaching wall in the lobby;
   - black-glass HUD panels, the range's floating console, and an F1 dev panel.
4. **Colour marks a wall's direction, never its W.** Walls that stand across W carry the kit's cyan.
   The research warns against tinting things by where they are in W, so that colour goes on the ghosts
   only (4D sight, below). Each W layer gets its own painted floor shape, a shape and not a colour.
5. **Render options as tools, not decoration:**
   - Cross-section is the game.
   - **G, 4D sight**, is Combined with only the neighbouring cells allowed to project, tinted by side
     (kata or ana) with the camera's hue-shift fade.
   - **M, a map** of the layers side by side.
   - F1 offers Projected and Wireframe for anyone who wants to see the whole maze those ways.
6. **Six short hand-made levels, one new idea each, and a generated bonus level.**
   - All playable from the start with 1 to 6, as you asked for the range.
   - A finished level gets the green stopwatch.
   - Each card shows par for W moves, from the solver.
7. **Help that never makes you wait:**
   - breadcrumbs on visited floor tiles;
   - an instant restart;
   - a three-step hint on T: first which direction the way hides in, then the next door, then the
     route for five seconds.

## The visitor's flow

1. You arrive in a small lab lobby at the maze's door. The blue wall says, in three short lines, what
   a 4D maze is. Three framed pictures show the same cell seen level, turned left into W and turned
   ahead into W.
2. The console floats in front of you with six tiles. Click or press 1 for **Step**, then START. The
   door opens and the timer starts on your first move.
3. You walk a flat maze until a dead end with a cyan W mark on its floor. The prompt says E. You hold
   it, and over a few slow seconds the walls round you change: you are in the next layer, and the way
   on is open.
4. Level 2's corridor runs three cells through W. Stepping it all takes about 24 s. The floor says F:
   you turn, and the same corridor is right in front of you, about 11 s with the turn.
5. At the green pad the console flies to you with your time, your W moves against par, and NEXT.
6. Later levels add the other turn, the map, 4D sight and a room sealed in 3D whose door is in W,
   then a full 3×3×3 cube. Level 6 is a generated maze for anyone who wants more.

## The levels (6 m cells)

| # | Name | The one new idea | Size, cells (x × z × w) | About |
|---|---|---|---|---|
| 1 | **Step** | A dead end whose way on is ana, then one back kata. The old Phase Maze's idea, as a first lesson. | 3 × 3 × 2 | 1 min |
| 2 | **Turn** | A shaft three cells long through W. Step it slowly or turn (F) and run it. | 3 × 2 × 4 | 1 min |
| 3 | **Both turns** | Up a shaft seen facing ahead, then down another seen facing sideways: the way you face decides which flat maze a turn shows. The map (M) and breadcrumbs appear. | 3 × 3 × 3 | 2 min |
| 4 | **Sealed room** | The exit stands in a room closed on all four sides; its beacon shows over the walls. Its door is in W. 4D sight (G) appears. | 3 × 3 × 3 | 2 min |
| 5 | **The cube** | Everything together, hand-made, with par for W moves. | 3 × 3 × 3 | 3 to 4 min |
| 6 | **Generated** | A new maze each run (the old level 2's spanning tree and longest path, in three directions). The seed is shown. | 4 × 4 × 3 | 4 min |

## The 80 steps

### A. Foundations

1. Folders: `PhaseMazeRemake/` with `maze/`, `character/`, `hud/`, `levels/`, `carried/` and
   `scripts/`, and the scene `phase_maze_remake.tscn`. Everything is built in code from one game node,
   and nothing generated is saved into the scene.
2. Carry the kit (light, room, materials, `lab_surface` shader, glyphs, panels, prompt) from the
   range's carried copy, which already has the `edge_ends` fix. Rewrite the paths, with no
   `class_name` and no `.uid` sidecars. `carried/README.md` says where each file came from.
3. Carry Andrew's walker from the pen as of `2fd1560` (8 Oct): `GroundBasis4D` (as a preload, not a
   class name), the orbit rig, the walker, the avatar with its `W_SIZES`, and the gait. The README
   records the commit, so later pen changes can be compared against it.
4. Carry the range's floating console and its kit glyphs.
5. The game node `maze_game_4d.gd`: lobby, playing and finished states, and the level load.
6. The lab light, its one spot following the walker (moved each frame; the kit's light re-aims itself),
   and the sky, from the kit's light. All the values go into a table the dev panel can change.
7. Runner rules in every test script: an unfocusable small window, player input off, the mouse
   freed, the scene's keys off, and a fail-fast timer at 90 s. A parse check before every batch.
8. Settings in `user://phase_maze_remake_settings.cfg` and bests in `..._bests.cfg`. Runners never
   write bests.
9. First frame: the lab hall, the grid floor and the walker standing in it. Captured and looked at
   before anything else is built.
10. A perf baseline of that empty frame, for comparing every later step against.

### B. The maze model

11. `maze_lattice.gd`: cells (i, j, k) along x, z and w, six faces each, open or closed. Start, exit,
    and the cells' painted marks.
12. A level file you can read and edit: each W layer as a small text grid, with W doors marked
    between them. The hand-made levels are written in it.
13. A solver: breadth-first over cells, giving the shortest route, its W steps and turns, and its dead
    ends. The hints, the par, the bot and the regression check all use it.
14. A validator: every level solvable, every cell reachable, and the intended route the shortest
    one. It fails loudly when an edit opens a shortcut (Baba Is You's "remove unplanned solutions").
15. The generator: the old level 2's depth-first spanning tree and double breadth-first longest path,
    extended to three directions and seeded.
16. Mapping between a cell and a position (6 m), which cell a position is in, and which axis a view
    hides.
17. Geometry: walls as boxes 0.4 m thick and 5 m tall. Neighbouring faces in a line merge into one
    long wall, giving fewer pieces and fewer colliders.
18. Meshes merged per cell, per wall direction and per material (the kit's batch): about 80 to 150
    instances a level. Every 4D instance uses shader slots, and thousands overflow. Per cell, so 4D
    sight can ghost exactly the cells beside you (step 61).
19. Colliders: one static body, a box per wall run, and a floor slab through all of W. All of them
    are axis-aligned, so the box-only physics is exact.
20. Probe: build level 3, photograph each layer from above and the walker inside it, and log the
    piece counts and the build time (target under 100 ms).

### C. The look

21. Walls and floors on my copy of the `lab_surface` shader (current vertex stage), the grid laid by
    world metres. The copy leaves the material's `albedo` out of the solid surface, so albedo is free
    to be the ghost colour.
22. Walls across W: compare all-cyan (as in the probe) against white with a cyan band and edges, in
    frames, and pick. Both stay as an F1 choice.
23. Wall tops: a thin white cap with the kit's dark edge line, so wall ends and corners read.
24. Layer identity: in each cell, the layer's shape painted on the floor (circle, triangle, square,
    and so on). Shapes, not colours.
25. Start: the yellow "stand here" ring. Exit: a green pad and a tall green-rimmed beacon that stands
    through all of W, so it shows over the walls from every layer.
26. W doors: where a cell opens through W, a cyan W mark on the floor, in both cells. Seen in the
    level view, it says "the way on is in W".
27. Breadcrumbs: a visited cell's floor tile turns pale yellow, strongest where you were last and
    fading with age. A dead end you have fully walked turns grey with a small done mark. The tile is
    just that cell's own slab, so each layer keeps its own trail, and the trail shows on the map too.
28. The lobby: a kit antechamber at the maze's door, with the blue teaching wall, the console and the
    spawn.
29. The wall's words, short and with no dashes: "A maze in four directions." / "Every view is a flat
    maze." / "Turn to choose the one you walk in." Three framed pictures of one cell, from the game
    itself.
30. Glow strips (the kit's unshaded glow) on the exit beacon and the console.
31. Light pass: the spot over the walker, and the fill strength. Both in F1.
32. Look sheet: every level from the walker and from above. Judge it before the gameplay steps.

### D. The walker and the cameras

33. Put the carried walker in the start cell, facing the open way. It keeps the chibi build and the
    W-thick parts.
34. **Chase** camera (default): high and back (about 2.1 m up, 3.6 m back, 24° down), tuned in frames
    in 6 m cells with 5 m walls. As a wall pulls it in, it tilts further down instead of hitting the
    walker's back, and the walker fades when the camera is closer than about a metre.
35. **Shoulder** camera: the orbit rig's own over-the-shoulder framing.
36. **First person:** the arm wound in to eye height and the walker hidden, as the pen's human test
    scene does it.
37. V switches first and third person (eased). Tab switches chase and shoulder.
38. The spring arm against maze walls, checked at corners and in turned views. The camera must never
    end up inside a wall or on the far side of one.
39. **F, the quarter turn:** first the heading snaps to the nearest corridor direction, then the way
    you face swings into ana, in the view's own frame, over 0.35 s. F again swings it back. Walking
    keeps the directions it had when the turn began until the turn ends, so the keys never change
    meaning half way. F always
    swaps what is ahead with what is hidden, so facing along x then F shows z and W instead. To go
    kata after a turn, walk back or turn round.
40. **The drag:** right mouse plus mouse tilts the slice freely (Andrew's). On release it settles to
    the nearest of the cube's 24 quarter turns over about 0.25 s (Andrew's `rotated_toward`, measured
    in the second probe). F1 switches the settle off.
41. **R levels the slice** and keeps your W. This is not the pen's R, which also walks you to W 0:
    in a maze that would walk you through walls. The rig's own R, T (chicken lock) and Tab are
    switched off through its exports.
42. **Q/E** step along the view's W at 0.3 of the run, exactly as in the pen. The speed is a dev
    panel value.
43. Facing through W: check the walker's body and feet in all three views and mid-turn. Frames.
44. Escape: the first press frees the mouse, the second goes back. H goes back to the menu (the
    shared return button), as in the other prototypes.
45. Key audit: a runner lists every key the scene listens to and fails on a clash.
46. Probe: every camera in every view, a contact sheet, and judgement before going on.

### E. The game

47. Level load and unload behind a short fade, with the build under 100 ms.
48. The stopwatch starts on your first move and stops on the exit pad.
49. Counts: W steps (cells crossed along the hidden axis), turns and cells visited.
50. Backspace restarts the level at once: same level, same seed.
51. A guard: below the floor or outside the maze puts you back in your last cell.
52. The console (from the range): tiles 1 to 6 and START. The number keys pick, all levels are open,
    a selected tile is highlighted, and a finished one gets the green stopwatch and its best.
53. Finish: the console flies to you with the card (time, best, W moves against par) and NEXT.
54. Par is the solver's fewest W moves. The card shows it beside yours, with no locks attached.
55. Bests are saved and shown on the tiles. Runners never save.
56. **Hints on T,** three steps and no waiting:
    1. which direction the way on hides in ("The way on is through W. Turn with F, or step with E.");
    2. the next door lights on the floor and on the map;
    3. the route is drawn for 5 s.
    They cost nothing and are not counted on the card. Asked for, never offered unasked.
57. **The map on M:** a black-glass panel of flat panels side by side, never overlapping. They are cut
    along whichever axis your view hides, so each panel is a flat maze like the one you see, turned so
    your forward is up. The panel you are in is outlined. It shows your visited cells, you as an
    arrow, the exit, and the doors to the panels beside it as matching arrows, the way a building map
    marks stairs.
58. **The view badge** (always on): a small axis gizmo. The two axes you see are lines pointing where
    they point on screen, and the hidden one is a dot with Q and E beside it ("step"). Every axis
    carries its letter and its own colour, W always cyan, so nothing rests on brightness alone. It
    swings with the turn. It answers 4D Miner's players' most common question: which way am I looking?
59. **The W ruler:** your cell along the hidden axis, as ticks, with the cell before and after you
    marked open or closed. You know whether a Q or E step goes anywhere before you take it.
60. Prompts in the kit's prompt style, shown the first time something is useful in a level and not
    again.

### F. Render options

61. **4D sight (G):** the camera goes to Combined, and only the cells next to yours along the hidden
    axis may project, and of them only the walls that stand across what you see. That set is updated
    as you cross a cell and when a turn ends.
62. Ghost colour: each wall material's `albedo` (cyan), which only the ghost pass uses (step 21). The
    camera's hue shift is wireframe-only, measured. Checked in frames that the slice stays white.
63. Ghost strength (`projection_opacity_base`), tuned in frames. The Arboretum uses 0.12 and
    Crosswise 0.06.
64. The root `World3D` is set before every switch to Combined, as the 30 Sept crash requires.
65. F1 renderer choice: Cross-section, Combined, Projected, Wireframe. For R&D viewing.
66. Probe: one spot in all four renderers. Contact sheet.

### G. The levels

67. Level 1, **Step**.
68. Level 2, **Turn**.
69. Level 3, **Both turns**.
70. Level 4, **Sealed room**.
71. Level 5, **The cube**.
72. Level 6, **Generated**.

Each one: written in the level format, checked by the validator, played by the bot, and photographed.
Each ships only when it teaches its one idea.

### H. Proof and handover

73. The F1 dev panel (kit style): cameras, turn speed and settle, W step speed, wall marking, ghost
    strength and colours, renderer, light and spot. SAVE makes your choices the defaults, in
    `user://` (the range's panel writes into the project folder; this one does not).
74. The bot (`_solve_runner.gd`) plays every level through the real controls (walk, F, Q/E) along the
    solver's route. It fails if it is stuck for 8 s, and it films each beat.
75. The regression runner: the validator, route and par per level, piece counts and build times.
76. The perf runner: frame and GPU times per level, in each view and with 4D sight. Target under
    2 ms a frame (the range is about 1.4 ms).
77. The HUD at 4K (3840 × 2160 at 145%), with the feedback runner's mode.
78. A short film of the bot's best beats for you, and a menu clip (`.ogv`) ready for the catalogue.
    The catalogue itself is shared, so I leave it alone and ask.
79. Handover `follow_up/phase_maze_remake.md`, Questions for Ramon at the top, and memory.
80. Commit `PhaseMazeRemake/` and the handover by explicit paths, nothing else. No push until you
    say so.

## Questions for Ramon (my defaults hold until you say otherwise)

1. **The other walkers.** Andrew's way is the pen's only walk now. The Creation Lab, Arboretum and
   Voxel Lab still carry the pen walker from before 7 Oct (world-W stepping, the body facing on the
   ground). They are other windows' work, so I have not touched them. Should they be brought up to
   date? It is a copy of three scripts in each, or pointing them at the pen's own.
2. **The name.** "Phase Maze" still fits, so the scene is `phase_maze_remake.tscn`. Keep the name,
   or something more literal?
3. **Going live.** When it is ready: replace the old Phase Maze in the menu, or sit beside it? The
   old one is left untouched either way.
4. **The step speed.** Andrew's 0.3 makes a 6 m cell about 7 s of holding E. That slowness is what
   makes turning worth it, but tell me if it feels like waiting. It is one number in F1.

## Levels on paper (8 Oct evening)

Each layer is a grid: `#` wall, a space open, `S` start, `E` exit, `^` a door ana, `v` a door kata,
`x` both. Lines run from -z (ahead at the start) down to +z, characters along +x. Layer 0 is
kata-most. Route = the shortest way, as moves along each axis; times are the solver's estimate at
the pen walker's speeds (run 3 m/s, W step 0.9 m/s, a turn 0.35 s plus a moment to read it).

### 1 Step

`3x3x2, reachable 18/18, route 10 moves [z2 w1 z1 x2 z1 w1 z2], W moves 2, shortest routes 1, dead ends 5`
`all W stepped: 29 s   turning instead: 23 s with 3 turns`

```
layer 0
#######
#^ .#E#
# ### #
#. .#.#
# ### #
#S .#.#
#######
layer 1
#######
#v . .#
# #####
#. . .#
##### #
#. . v#
#######
```

### 2 Turn

`3x2x4, reachable 11/24, route 5 moves [x1 w3 x1], W moves 3, shortest routes 1, dead ends 2`
`all W stepped: 24 s   turning instead: 11 s with 1 turns`

```
layer 0
#######
#. . .#
# ### #
#S ^#.#
#######
layer 1
#######
#.#.#.#
# ### #
#.#x#.#
#######
layer 2
#######
#.#.#.#
# ### #
#.#x#.#
#######
layer 3
#######
#. .#.#
##### #
#.#v E#
#######
```

### 3 Both turns

`3x3x3, reachable 24/27, route 7 moves [z1 w2 x1 z1 w2], W moves 4, shortest routes 1, dead ends 7`
`all W stepped: 33 s   turning instead: 16 s with 2 turns`

```
layer 0
#######
#^ .#E#
# #####
#.#^ .#
# # ###
#. S .#
#######
layer 1
#######
#v .#x#
# #####
#. x .#
#######
#. . .#
#######
layer 2
#######
#. .#v#
### # #
#. v .#
# #####
#. . .#
#######
```

### 4 Sealed room

`3x3x3, reachable 26/27, route 12 moves [x1 z2 w1 x2 z2 w1 z1 x1 w1], W moves 3, shortest routes 2, dead ends 0`
`all W stepped: 38 s   turning instead: 27 s with 3 turns`

```
layer 0
#######
#^ . .#
# ### #
#.#.#.#
# ### #
#. S .#
#######
layer 1
#######
#v . .#
# ### #
#.#E#.#
# ### #
#. . ^#
#######
layer 2
#######
#. . .#
# ### #
#.#v .#
# ### #
#. . v#
#######
```

### 5 The cube

`3x3x3, reachable 27/27, route 10 moves [x1 w2 x1 z2 x2 w2], W moves 4, shortest routes 1, dead ends 5`
`all W stepped: 39 s   turning instead: 23 s with 3 turns`

```
layer 0
#######
#^ .#E#
# # ###
#. .#.#
# ### #
#S ^ .#
#######
layer 1
#######
#v .#x#
### ###
#. .#.#
# # # #
#.#x .#
#######
layer 2
#######
#. . v#
# #####
#. .#.#
# ### #
#. v .#
#######
```

Level 6 is generated each run (4 × 4 × 3). Three seeds gave routes of 30 to 39 moves, 9 to 16 of
them through W, about 70 to 90 s if you turn and 100 to 150 s if you only step.

## Round 2: the journey (9 Oct, Ramon's notes while the bot played)

His notes, in order:

1. "a lot of 90 degree turns in single lanes, it looks a bit boring ... would be cool if its more
   impressive somehow ... the irregular skewing of the original maze was also cool";
2. "sometimes you end up in a big room, where for example the dreamer is from the pen ... the level
   ends with that reward ... you much smaller in the big room, and like stage completed ... making
   you curious about the next reward";
3. "something with verticality. making you way up";
4. "look down from a highpoint at a giant maze ... as a journey ingredient";
5. "look again at creationlabs ... to be sure the vibes are accurate".

What the study showed (`study2/` frames):

- **The Creation Lab is moodier than round 1.** It has blue-grey tile walls, a darker sky, and a
  bright pool of light round the walker. Round 1 took the range's pale open look.
- **The old maze's "skewing" is the drag itself.** The walls lean and slide while the slice tilts, and
  round 1's settle snapped that away the moment you let go.
- **The walker climbs 0.32 m steps** (`step_height`), but only along x and z.
- **The Dreamer** (`chickenpen/cave/cave_dreamer_4d.gd`) is about 680 pieces, fills a room of about
  50 x 50 m, and needs only the pen's loft builder.

The steps:

| # | Step |
|---|---|
| R1 | **The lab's own light:** the Creation Lab's bright mood instead of the range's pale sky; the walls on the kit's blue-grey tile; a stronger pool of light on the walker. |
| R2 | **The skew stays:** a drag leaves the slice where you let go, as the old maze and the pen do. F and R give the clean views back; F1 can switch the settle back on. |
| R3 | **Irregular cells:** each level can give its own sizes along x, z and w (for example 4, 9, 5 m), so narrow corridors open into wide halls and the grid stops reading as a grid. |
| R4 | **Halls:** big rooms made of open cells, a 2 x 2 hall of 9 m cells being 18 m across, with something to see in them. |
| R5 | **Floors at heights:** each cell has a floor height, written as a second grid per layer. Walls rise 5 m above the higher floor beside them. |
| R6 | **Stairs:** a stair cell rises from its low neighbour to its high one in 0.3 m steps, along x, z or w. |
| R7 | **Stairs through W:** the walker's step-up (in our copy) also looks along W. A stair rising through W is a single ledge in the level view and a staircase once you turn: verticality that only 4D shows you. |
| R8 | **The overlook:** a stage starts high, on a platform over the maze, looking down at all of it. F there shows the maze below rearranging into another flat maze. A stair takes you down into it. |
| R9 | **A giant maze:** the last hand-made level grows into a big one with halls and stairs, made to be seen from the overlook. |
| R10 | **The reward hall:** the exit leads into a big hall. In it stands the stage's reward, huge, with you small. "STAGE COMPLETE": the camera pulls up and back, then the card. |
| R11 | **The rewards:** stage by stage, a giant chicken, the wolf, and last the Dreamer (copied from the pen, never touched). The hall shows the next stage's reward as a dark silhouette, to make you curious. |
| R12 | **Levels re-made** with R3 to R9, checked on paper and by the level runner, played by the bot. |
| R13 | **Proof again:** the level check, the bot, the features run, perf (the Dreamer measured), frames, a new film. |
| R14 | **Handover and commit** (`PhaseMazeRemake/` only). |

### Round 2, as built (9 Oct)

All fourteen steps are done. Five more of Ramon's notes came in while it was being built, and are in
too:

- **The pen's dev colours instead of cyan, green and yellow.**
  - Blue for anything about W.
  - The pen's landmark orange for where you are going and what you climb: the exit, the beacon,
    the stairs and the overlook.
  - A warm cream where the kit had yellow: the start, the lift ring and the breadcrumbs.
- **B toggles dark and bright,** as in the Creation Lab. The spot carries the dark.
- **The stage-complete orbit:** after the beat, the camera keeps circling slowly while the stats sit
  on a see-through card, until you move.
- **Tab is the tuning panel,** with SAVE, as in Ramon's other scenes. The spot is tunable there: on
  or off, its strength in each mood, its cone and its height. The camera framing moved to C.
- **Indoor stretches:** roofs over chosen cells, each with a warm light strip and colliding.
  - Level 1: the start's half.
  - Level 3: the ground floor, so the stairs take you out onto an open mezzanine.
  - Level 4: the rings round the sealed room, an indoor maze round an open sky.
  - Level 5: a wing.
- **The view badge** became a small cube of x, z and w with your slice as a plane in it, tilting with
  any drag, and the tilt in degrees when you are between quarter turns. (Ramon: "less tick tack toe".)
- **The path tool stays out.** Ramon, 9 Oct: "probably not as it would defeat the purpose of a maze
  completely". The hints and the map's route are the asked-for help.

Changes that the build itself led to:

- **Stairs chain:** every stair rises one RISE from the floor at its low side, so a flight of them
  climbs on.
- **The overlook camera** stands high and back while you are up there.
- **The halls' beat** pulls back from nearer the middle, so the camera stays inside the hall.
- **The bot** confirms every F turned the view, and stops walking once it is out of the maze.

Proof:

- **Levels:** the level check passes, with every route as drawn on paper.
- **The bot** plays all six levels at par through the real controls, the lift and the stairs included.
- **Features:** the features run passes.
- **Perf:**
  - The mazes run at 1.0 to 2.3 ms a frame.
  - The chicken and wolf halls run at about 1.3 ms.
  - The Dreamer's hall runs at 4.35 ms: it re-poses about 680 pieces a frame.
- **Films:**
  - `smoke_test_output/video/phase_maze_journey.mp4` (110 s, levels 2, 3 and 5 with their halls);
  - the menu clip `art/phase_maze_remake.ogv` (10 s).
- **Dark against bright:** `smoke_test_output/phase_maze_remake/moods_sheet.png`.

## Round 3: the walkthrough feedback (10 Oct, Ramon's three playtest notes)

Priorities as he set them: first Escape and the Tab panel, then the level console, then the light and
the colours, then the navigation (the gizmo, the blue plates, the door, level 6). Preserve every level,
mechanic and working interaction unless a change is asked for. The Dreamer ("Azathoth") stays.

**1. Escape and the Tab panel**
1. Esc never leaves at once. From the menu, the menu hears Esc first (prototype_launcher's tree-order
   fix) and closes the prototype: a guard node on the root, added after the menu, hears it before
   the menu does. The menu's own file is another window's and stays untouched.
2. Esc, in order: closes the confirm box (No), closes the Tab panel, closes the map, else opens
   "Return to the main menu? Yes / No". The game pauses behind the box and the cursor is free.
3. Yes: from the menu, the guard steps aside and hands Esc on, so the menu leaves the way it always
   has; run alone (F6), it goes to the menu scene as H does. No, Esc or N: back to play, mouse as it was.
4. Tab (and F1) opens and closes the panel every time. While it is open: the cursor is free, a
   click beside the panel does not grab the mouse, and no game key (1-6, Enter, Backspace, F, R, G,
   M, T, L, V, C, walking) can start, leave or change anything.
5. Every row on the Numbers page gets a plain name and a one-line note of what it does; SAVE kept.

**2. The level console**
6. It stands still: in the lobby, in the back left corner between the Phase Maze wall and the back
   wall, turned to face you as you come in; in the hall, at one place facing where you arrive. It no
   longer turns to you or flies to you.
7. A stand that collides, so you walk round it, not through it; clear of the walking line.
8. The mouse: pressing a level's number, or clicking a tile, frees the cursor, so START can be
   clicked with the pointer (a 4D ray from the cursor: Camera4D.viewport_to_world_ray_*); the
   crosshair keeps working when the mouse is captured. Clicking away from the console takes the
   mouse back for looking.
9. A clear prompt on screen once a level is chosen: "02 TURN. CLICK START OR PRESS ENTER".

**3. Light and colour**
10. The spot gets its edge softness (SpotLight4D.spot_angle_attenuation) and its fall-off with
    distance (spot_range_attenuation) and its reach on Tab; cone, height and strength kept.
11. "Spot, dark" did nothing because it is the dark mood's strength (B): rename both strengths after
    their mood, and mark the one in force.
12. Colour presets on the Colours page: the round-2 look, and stronger, graphic ones (dark blue with
    white grid lines; deep red with white grid lines), the floor marks recoloured to suit.
13. Grid line colours editable on their own for the maze's surfaces (white lines on dark blue cannot
    be had by scaling the surface colour).

**4. Navigation**
14. Survey the repo's 4D navigation aids (the old Phase Maze's gizmo first), then adapt the best one
    rather than invent: where am I in W, what a turn or a step changes, where I might go.
15. The blue plates: standing on one says so (the plate lights; the F key on the HUD lights; the
    first time, an animated F key and a line: F turns the way through W ahead of you).
16. Holding Q/E shows progress through W at once, so a slow step never looks like nothing.
17. The exit beacon: solid only in the exit's own layer; elsewhere a hollow outline that says which
    way along W the exit lies, so standing under it in the wrong layer never looks like the way out.
18. The forced turn after F: find it and remove it; you can walk the moment you press F.
19. The mid-air stick after R on the lift: reproduce it, fix it.
20. Level 6 (generated): every W layer its own floor tint and a layer sign on its walls, so moving
    through W is visible and progress can be read; landmarks in a few cells.
21. The door through W in level 1: check it works, and that its feedback is clear.

**5. Proof and handover**
22. Bot at par on all six, level check, features; new runners for Esc, the console, the softlock and
    the turn; frames of every change looked at; perf unchanged.
23. Handover and memory; commit by explicit paths; no push.

### The gizmo survey (step 14), and what it chose

Asked first, built second (Ramon: "investigate the existing systems first, then recommend a solution
... adapting a proven gizmo rather than inventing an entirely new visual language").

**Why the old maze felt more informative.** Its aids reacted *continuously*: a raw W number every frame
(player.gd's position label, which its legend told you to watch), and in level 2 a "W ALIGNMENT" bar
that filled as you neared the hidden gap's W (PhaseMaze/scripts/maze_hud_2.gd). The remake's ruler
changed only when you crossed into the next 6 m cell, so holding Q or E looked like nothing happening,
and it showed nothing of the other layers: not the exit, not where you stood in them.

**What exists, by the three questions** (where am I in W; what a turn or a step changes; where I might go):
- Crosswise's W ruler and lane-tinted floors (Crosswise/hud/mk_hud.gd, shaders/mk_surface.gdshader):
  a column of the lanes in their floor colours, you as a bar placed continuously, the goal at its W.
  Built for the same quarter turn of z into W. Answers the first and third; the floor and the HUD agree.
- The Lookout's W meter and ghost rings (chickenpen/lookout/lookout_viewfinder_4d.gd): a kata to ana
  scale with targets ticked at their W, and "W +n" written on screen where an off-slice thing stands.
  The best for "where might I go".
- The Aquatic Lab's tank dial (WaterLab/room/tank_dial.gd): a side section with YOUR SLICE as a line.
  The best for "what a turn changes", but it needs the lattice drawn as a section; not taken now.
- The pen's spirit level (pen_slice_plane_4d.gd): stems and rings for things in other W. Its maths
  cannot draw a quarter turn into W (edge-on), so it is not portable here; its vocabulary is.
- The Aquatic Lab's animated mouse card (WaterLab/shared/mouse_tutorial.gd) and the pen's copy with
  keys: the teaching card.

**The smallest set that answers all three, adapted, not invented:**
1. The ruler becomes Crosswise's: each cell along the hidden axis as long as it is, in its floor's
   layer colour; your needle placed continuously (it moves while you hold Q or E); the exit's cell
   marked with an orange diamond; "W LAYER 2 OF 4" over it and where the exit is on the right; the Q
   and E caps lit when open and pressed while held. The cube badge stays above it, for the turn.
2. Every W layer's floor takes its own colour (Miegakure's banded ground, Crosswise's lanes), the same
   colours as the ruler, so the ground says which layer you are in, in every level.
3. The beacon over the exit is solid only in the exit's layer and a hollow frame elsewhere, and a
   label where it stands on screen says which layer the exit is in and which key's way (the Lookout's
   ghost labels).
4. The blue plates teach themselves: the plate pulses under you, F's row on the keys strip lights and
   says the way is here (elsewhere: "no door"), and the first few times a key card acts out F and Q/E
   (the Aquatic Lab's card, with keys).
5. A move through W is said: the layer's name, in its colour, and the ruler flashes.

### Round 3, as built (10 Oct)

All 23 steps done; the handover's "10 Oct: round 3" says what each looks like and where.
- 1 to 5: Esc asks first (`hud/maze_escape.gd`, a guard on the root, YES through the menu's own
  `_input`); the Tab panel holds the game while open; every row named and explained.
- 6 to 9: the console stands still in the lobby's corner and in the hall, with a colliding plinth,
  cursor clicks and the prompt.
- 10 to 13: the spot's softness, fade and reach; IN USE on the mood's strength; line colours; the
  ROUND 2, BLUEPRINT and SIGNAL RED looks; the cream marks now a cool white.
- 14 to 21: the survey above, then the ruler, the layer floors, the beacon, the plates and their card,
  the layer toast, level 6's landmarks; the turn's rate fixed (keys back at 0.35 s, nothing turning
  after); the lift's R did not stick in any test; the stairs through W settle W on the step under you.
- 22: round 3 runner PASS, levels PASS, the bot at par on all six, features PASS, perf as before.

Changes the build itself led to:
- **YES once quit the program.** The first YES handed Esc on by broadcasting it, and the walker's rig
  took it as its second Esc: quit. It now goes to the menu alone.
- **The console's reach** for a click went from 12 m to 20 m: from where you arrive it is 13.5 m away.
- **The layer tint** is matched to the floor's brightness before it blends, or a dark floor turned
  another colour (SIGNAL RED's floor went purple).
