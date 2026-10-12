# Phase Maze remake: the research behind the plan (8 Oct 2026)

Four studies fed `PLAN.md`:

1. the old Phase Maze, played and photographed;
2. where Andrew's way of walking and viewing is used today;
3. prior art from other 4D games and wayfinding research;
4. a probe that puts the pen's walker into a few 4D maze cells.

Frames are in `project/smoke_test_output/phase_maze_remake/`:
- `old_maze_sheet.png`: the old maze;
- `probe_sheet.png`: the probe, labelled.

## 1. The old Phase Maze

`PhaseMaze/phase_maze.tscn` and `phase_maze_2.tscn` (read only, nothing changed).

**How it works.** Both levels are flat mazes, a 4×4 hand-made one and a 5×5 generated one, with 4 m
cells. Every wall stands through W from -12 to +12. Three "gates" in each are wall pieces that exist
everywhere in W except a narrow band, at W -6, +2 and +7. You find the gap by holding Q or E and
watching a number. Level 2 adds a bar that shows how close you are, but not which way.

**What the frames show** (`old_maze_sheet.png`):
- A black void, grey and dark walls, and a yellow sign.
- From above, the maze cannot be read at any W.
- The HUD is five lines of capitals about rules.
- The shader has been broken since 30 Sept. It reads the corner UVWs from slots the engine moved;
  `follow_up/engine_capabilities.md` has the details.

**What it really asks of you.** W in this maze is not space. It is a combination lock: the maze is
the same at every W except the three gaps, and you find each gap by scanning a number. Nothing about
turning, seeing or walking in four directions is involved.

**Loose ends found:**
- Escape goes to the old team menu.
- Level 1's change of scene frees the menu when it was launched from the menu.
- The fall respawn returns you to the origin, not to the start.
- No timer and no restart.

## 2. Andrew's walk and view: where it is used

"Andrew's way" is two things he gave the pen (b20b6c6, ported 7 Oct; his toggles removed in e4ff9cb,
8 Oct), plus 214dfe4:

- **Stepping along the view's W.** Q and E move you along your slice's own W (the rig's `basis.w`),
  at 0.3 of the run, so stepping always leaves your slice square on.
- **Facing through W.** The avatar's frame turns with the slice (`_target_stance`), so on a turned
  slice the body is still seen whole instead of collapsing into a slab.
- **W-thick body parts** (214dfe4). Every part of the player, the NPCs and Nike has its own thickness
  through W (`W_SIZES`), plus W ears.

The view itself is the pen's orbit rig. Its frame (`GroundBasis4D`) holds heading and slice tilt as
one rotation. Holding the right mouse button and dragging tilts the slice in the view's own axes.

| Where | Walker | Andrew's way? |
|---|---|---|
| The pen (`playable_world.tscn`) | `chickenpen/scripts/block_walker_character_4d.gd` and the orbit rig | **Yes.** It is the only walk since 8 Oct. Checked: `_rig.basis.w` stepping and `_target_stance`. |
| Creation Lab, Arboretum, Voxel Lab | Each carries a copy of the pen walker from before 7 Oct (`*/carried/chickenpen/scripts/`) | **No.** World-W stepping, and the avatar faces on the ground. |
| Crosswise | Its own diorama walker with quarter turns | Its own scheme, close to Miegakure's. |
| Shooting Range | A first-person player at a counter | Not a walker. |
| Old Phase Maze | The team's `player/player.tscn` | No. |

The pen is the default, as it should be. The three labs are other windows' work, so I have not
touched them. That is a question for Ramon in the plan. The remake uses Andrew's way, copied.

## 3. Prior art (web research, 8 Oct)

### How 4D games show W

- **Miegakure** (Marc ten Bosch):
  - It shows a 3D slice. Ten Bosch rejected projection, because it overlaps things you cannot touch.
  - He rejected colouring objects by their W as "unnecessarily difficult to visually parse".
  - One button swaps a horizontal axis with W, animated as a 90° turn, and gravity never swaps.
  - Free W movement was rejected: vision and movement must be coupled, or you bump into things you
    cannot see.
  - Levels are sparse enough to hold in your head.
  - Sources: [Nature as Designer](https://marctenbosch.com/news/?p=905); hands-on
    [Shacknews 2010](https://shacknews.com/article/65988/indiecade-2010-hands-on-miegakure).
  - A PC Gamer previewer finished six levels "with no idea how I was doing it"
    ([PC Gamer](https://www.pcgamer.com/miegakure-preview/)).
- **4D Toys:**
  - Slice turns go in 90° steps, because those are the easiest to read, and free rotation can make
    the whole level vanish.
  - Coloured lines mark the horizontal axes, and a white line shows when W has replaced one.
  - Sources: [v8](https://marctenbosch.com/news/?p=3019), [v1.6](https://marctenbosch.com/news/?p=2606).
- **4D Golf** (CodeParade, 2024, 98% positive):
  - The camera follows the ball, and Q/E move along W.
  - Slice, volume and map views; the map is a top-down overview of the whole course.
  - Ghosts show what is off to the side in W, capped in distance.
  - He skipped tilted views as extra confusing.
  - Sources: [Steam](https://store.steampowered.com/app/2147950/4D_Golf/),
    [review](https://gamefaqs.gamespot.com/pc/381090-4d-golf/reviews/175707),
    [Engine4D](https://github.com/HackerPoet/Engine4D),
    [dev thread](https://steamcommunity.com/app/2147950/discussions/0/591762129865946481/).
- **4D Miner** (first person, the mouse wheel turns into W):
  - Players cannot tell what a W turn did relative to their view, and ask for a readout of the axis
    they face.
  - One was "super lost" until they found the keys that snap back to the familiar axes.
  - Sources: [Steam](https://steamcommunity.com/app/1941640/discussions/0/5829358177502838623),
    [Tildes](https://tildes.net/~games/1h14/4d_miner_4th_dimension_minecraft).
- **4D mazes:**
  - Jeff Weeks' 4D Maze shows W as colour ([Geometry Games](https://www.geometrygames.org/Maze4D/index.html)).
  - Tesseract! rotates the room as you pass a door
    ([App Store](https://apps.apple.com/us/app/tesseract-fourth-dimension/id734299096)).
  - A list of about ten more ([Wikipedia](https://en.wikipedia.org/wiki/List_of_four-dimensional_games)).

### First or third person

- In VR, first person gives more accurate interaction and third person better awareness of the
  surroundings ([Gorisse 2017](https://www.frontiersin.org/articles/10.3389/frobt.2017.00033/text)).
- Third person caused less simulator sickness
  ([UCC](https://research.ucc.ie/en/publications/evaluating-enjoyment-presence-and-emulator-sickness-in-vr-games-b/)).
- **First person can work in 4D** (Jamróz 2019, [The Visual Computer](https://doi.org/10.1007/s00371-019-01653-2)):
  - 97 students escaped a first-person 4D labyrinth in 57% of attempts, in 246 s on average.
  - What made it possible was perspective: things growing and shrinking as you move.
- My reading, not a sourced finding: the two best-received 4D games use an outside view, and the
  first-person one drew the most complaints about orientation.

### Readable mazes

- Split the world into distinct parts, order them, and give frequent direction cues. A global
  landmark helps, local landmarks much less (Darken and Sibert,
  [summary](https://discovery-pp.ucl.ac.uk/1103/1/SIaVE.pdf.pdf)).
- Too many aids overwhelm ([arXiv](https://arxiv.org/pdf/1706.08891)).
- Pair colour with shape ([Studio Matrx](https://www.studiomatrx.org/students/wayfinding-and-environmental-graphics/colour-contrast-and-coding)).
- Breadcrumbs were added after players lost themselves ([Flip the Maze](https://sgtwombatstudios.itch.io/flip-the-maze)).

### Level design

- Portal breaks each mechanic into the parts a player must get first
  ([Game Informer](https://gameinformer.com/b/features/archive/2010/03/17/thinking-with-portals-making-a-test-chamber)).
- Baba Is You adds one new interaction per level and removes unplanned solutions
  ([Red Bull](https://www.redbull.com/ph-en/baba-is-you-interview)).
- Hand-made mazes read as more cohesive than generated ones
  ([Chalmers](https://odr.chalmers.se/items/ec34f17b-a57d-4a9e-a8fa-a4c7ccbe6e7c/full)).
- **Hints:**
  - Vague hints rate worse than none ([Illinois](https://ideals.illinois.edu/items/103606)).
  - The first hint should aim at the current sticking point
    ([Danger Mouse](https://www.dangermouse.net/blog/?p=31)).
  - Forced waits drive players off.

### 4D cognition

- With little practice, people judge 4D lengths and angles, crudely
  ([Ambinder 2009](https://link.springer.com/article/10.3758/PBR.16.5.818)).
- After practice in a 4D maze, people could point back to a hidden start
  ([Aflalo and Graziano 2008](https://grazianolab.princeton.edu/publications/four-dimensional-spatial-reasoning-humans)).

## 4. The probe: the pen's walker in 4D maze cells

`scripts/_probe_walker_maze_runner.gd` loads the pen's procedural-walker scene as it is and adds walls
to it. The cells are laid out in x, z and w:

- The way on from cell B is through W, into layer 1, and on to C.
- White walls stand across x or z.
- Cyan walls stand across W, and show only when the slice turns.

It photographs the walker with the slice level, half turned and turned all the way into W. It does
this from behind, over the shoulder, from high and from the eyes, at 4 m and 6 m cells.
`probe_sheet.png` has the eight frames that matter:

1. **4 m cells, the pen's camera:** the camera is pulled in against the wall behind you, and the
   walker's back fills the frame. The way ahead is hidden.
2. **Half turned:** a 45° slice cuts the thin walls into jagged slivers. A tilted view of a grid
   maze is noise, as 4D Toys and CodeParade found.
3. **6 m cells, a high chase camera** (2.1 m up, 3.6 m back, 24° down): the walker is small and low,
   and the corridor and the pad are clear.
4. **Turned all the way:** the way through W is simply a corridor, with the cyan W wall at its end.
   But at 3 m the walls are lower than this camera, which sees over them. Maze walls must be taller,
   about 5 m.
5. **Over the shoulder:** readable, but the walker takes a quarter of the frame.
6. and 7. **First person** reads cleanly, level and turned, but the body is gone. That body is what
   shows how your slice is turned (Andrew's W-thick parts and facing).
8. **4D sight** (Combined, only layer 1 allowed to project): the next layer's walls show as a pale
   ghost box round the corridor. It is visible, and it needs tuning.

## What this adds up to

- **The maze has to be a real 4D maze.** Cells in x, z and w. Every view through a cell is a flat
  maze. Turning the slice picks which of the three flat mazes you walk in. That replaces the old
  combination lock with space.
- **Third person by default**, a high chase camera in 6 m cells with 5 m walls, plus first person on
  a key. The probe and the prior art agree on this.
- **Turns snap to quarters and are animated.** Andrew's drag still works, but it settles to the
  nearest quarter turn on release, because the half-way views are noise.
- **A step through W is slow and blind; a turn shows you W.** That contrast is the lesson of the
  maze, and it is how Andrew's walk already behaves.

## 5. Evening probe and engine reading (8 Oct)

`scripts/_probe_turns_runner.gd` uses the same three cells, at 6 m, with 5 m walls 0.4 m thick.
Frames are in `smoke_test_output/phase_maze_remake/turns/`.

- **Settle:** a drag stopped at 70° ahead plus 12° sideways is 23.3° from the nearest quarter turn.
  `GroundBasis4D.rotated_toward` at 4 rad/s lands on it in 7 ticks (0.12 s), with 0.000° left.
  The nearest quarter is the best of the 24 rotations of a cube in (x, z, w), by the trace of RᵀB.
- **Swap:** starting 20° off the corridor, the heading snaps and then the way you face rotates into
  W. It ends with forward = (0, 0, 0, -1) and the walker facing through W.
- **Tall walls:** in the turned chase view the 5 m walls hide everything beyond them.
- **Thick walls:** a 45° slice through 0.4 m walls leaves one thin wedge, against the sliver noise of
  0.2 m walls.
- **Hue shift:** `Camera4D.w_fade_mode` hue shift is read only by the Wireframe Canvas renderer
  (`wireframe_canvas_rendering_engine_4d.cpp`). The projected pass, which Combined uses, takes only
  the W slope and fade distance (`projected_rendering_engine_4d.cpp:99-100`). Its shader colours a
  ghost with `albedo * albedo_texture` (`tetra_projected_shader.glsl:270`).
  - Our `lab_surface` fork multiplies `albedo * tint * texture`.
  - A copy that drops albedo frees it to be the ghost colour.
- **Note:** switching to Combined after replacing the root's `World3D` prints `Parameter "scenario"
  is null` once. Both probes did it and ran on, but it should be checked in the build.

## 6. Second web study: HUD, maps, teaching, corridor camera, trails (8 Oct evening)

### Showing which axes you see
- **4D Toys** draws three coloured lines for the horizontal axes and a white one for the fourth. When
  you can see the white line, "you have traded one of your regular dimensions for the 4th".
  Axis-aligned turns are "the easiest to understand"
  ([update 8](https://marctenbosch.com/news/wp-json/wp/v2/posts/3019)).
- **Its W scrollbar** shows how far each shape reaches along W
  ([launch post](https://marctenbosch.com/news/wp-json/wp/v2/posts/2145)).
- **Miegakure** marks W in the world: the ground is textured differently at intervals, to group and
  tell apart the parallel worlds ([ten Bosch](https://marctenbosch.com/news/?p=1338)).
- **4D Miner's players** asked for a readout of the axis they face, and to see the block one step along
  the hidden axis, so that a tunnel turning in W does not look like a dead end. The compass they had
  was not being understood
  ([Steam, weak](https://steamcommunity.com/app/1941640/discussions/0/3717188244453833305)).

### Maps of layered spaces
- **The Dead Space remake** dropped its 3D map for a 2D one, "to improve the clarity and the
  readability" ([MP1st](https://mp1st.com/news/dead-space-remake-map-to-be-in-2d-instead-of-3d-to-improve-clarity-says-motive)).
- **Control** added its map late, after playtesters got lost. Its overlapping floors were the main
  complaint ([Game Developer](https://www.gamedeveloper.com/design/the-last-days-of-control)).
- **Li and Giudice 2013:** 2D and 3D maps both helped in a multi-level building, and the 2D group drew
  the layout more accurately ([VEMI](https://umaine.edu/vemi/?p=1238)).
- **Levine 1982:** a "you are here" marker is not enough. Align the map with the world, and label
  both alike ([summary](https://cindy.informatik.uni-bremen.de/www3/www.sfbtr8.spatial-cognition.de/aigaion/index.php/publications/show/1704.html)).
  Reading a misaligned map takes longer the further it is turned.

### Teaching a perspective mechanic
- **Portal's first chambers:**
  - The first portal is placed so players see themselves through it.
  - A forced pause was added because playtesters ran past what was making the portals.
  - ([commentary, fan transcript](https://theportalwiki.com/wiki/Portal_developer_commentary))
- **Super Paper Mario:** something you cannot pass in 2D is the cue to flip into 3D
  ([RPGamer](https://archive.rpgamer.com/news/Q1-2007/030907b.html)).
- **4D Toys:** the required tutorial teaches the one skill of recovering a lost shape, and the deeper
  explanation is optional.

### Third-person camera in corridors
- **John Nesky, "50 Camera Mistakes"** (GDC 2014, [vault](https://gdcvault.com/play/1020460/50-Camera)):
  - pull the camera in early and gradually, along a ray from the character;
  - couple distance to pitch;
  - no hard cuts or fast snaps;
  - keep input mapping coherent while the camera moves.
- **Valve** fades the player model when an enclosed space forces the camera close
  ([wiki](https://developer.valvesoftware.com/wiki/Fading_The_Player_In_Thirdperson)).
- **Nintendo, Super Mario 3D World:** a camera at a set distance in a set direction gives "less
  chance of getting lost"
  ([Iwata Asks](https://iwataasks.nintendo.com/interviews/wiiu/super-mario-3d-world/0/2)).
  Not taken here, because the mouse steers the view, but worth trying from F1 if people get lost.

### Trails and hints
- **Ruddle 2005**
  ([White Rose](https://eprints.whiterose.ac.uk/id/eprint/4961/)):
  - A trail of everywhere you had been halved the distance on a first search.
  - Its clutter later made people travel more than twice as far as needed.
  - Landmarks complement trails.
  - When a trail was on the map as well as in the world, people used the map (Darken and Peterson).
- **Professor Layton** has three escalating hints and no waiting.
- **Big Fish (2010)** found players avoided hints they "equated to being punished", and renaming them
  helped ([Game Developer](https://gamedeveloper.com/game-platforms/to-casual-gamers-hints-are-punishment-says-big-fish)).
