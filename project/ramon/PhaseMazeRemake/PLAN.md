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
