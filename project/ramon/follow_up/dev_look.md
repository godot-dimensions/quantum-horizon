# The pen's dev look: handover

6 Oct 2026. The playable world has two looks, DEV and ART, switched in a few milliseconds by **F8**
or the **Look** row at the top of the left-hand panel. The pen opens in DEV the first time in a
session and then keeps the last choice. Plan: `PenLayout/PLAN_DEV_LOOK.md`; why it is built this
way: `PenLayout/DEV_LOOK_STUDY.md`.

## Questions for Ramon

1. **Colours.** Landmarks are blue, what you use is red (the rune stone, laptops, pickups). You said
   "all blue or all red, like the pen": which part of the pen did you mean? Change them in the Look
   node's Palette group.
2. **Block or clay, per landmark.** Blocks: the Watchstone, the cave, Trym's shed, the oak, the rock
   pile. Clay (own shapes, one colour): everything else, the marsh with its water kept. Swap any in
   the Look node's `rules`.
3. **The Watchstone:** a cylinder. Tick `tower_three_blocks` for three stacked blocks.
4. **The switch:** F8, and the Look row at the top of the left panel. Somewhere else too (the main
   menu's PLAY THE WORLD)?
5. **The sky and light in DEV:** a pale blue gradient and neutral light at the pen's own strength
   (the lab's light clipped the white floor). Tune it in the Palette group.
6. **The editor:** `editor_dev` is off, so the editor shows the art. Tick it to lay out in DEV. Not
   tried in the editor itself (tests can't run while it is open): clicking a blockout in the pen
   should select its landmark's unit.
7. **Found on the way, not the look's:** the layout check fails "edge 20 runs through
   Cave/CaveHill" since this afternoon's path rerun (the ring at 7.6 m). A route crosses the cave's
   hill. Shall I fix the route?
8. The celebration test is flaky: it failed in the baseline and passed in both looks after.

## How it works

- `chickenpen/look/pen_look_4d.gd` (`Systems/Look` in `playable_world.tscn`) does all of it.
  `chickenpen/look/pen_blockouts_4d.gd` holds the simple shapes.
- **DEV:**
  - the ground: the lab's grid floor, through the Grass node's `dev_floor`;
  - the mountains and the two round hills: light grey;
  - the sky and light: the Creation Lab's bright mood, tuned for a white floor (the Palette
    group on the Look node);
  - the paths: their dev look (white strips, blue arrows);
  - every landmark by its rule (below);
  - animals and characters untouched;
  - what you use (the rune stone, laptops, pickups) red.
- **ART:** the pen exactly as it was. Switching the Look node's `enabled` off gives back today's pen
  with no switch at all.
- **It never hides a node.** Mechanics read visibility (the rune stone, laptops, photo subjects,
  tutor markers, slice dial outlines). The look takes a mesh off its node and keeps it, or lays a
  flat material over it.
- **Art is held** for films, in the cave's tunnel, and in the rooms behind the two crossings (the
  cave room and the cinema): Ramon, "leave the cave interior and the cinema alone".
- **No freeze on the first switch:** the pen opens with the art drawn for a few frames behind a
  black curtain, so the first switch to the art doesn't build its buffers then.

## The rules, per landmark

On the Look node, `rules`: the landmark's node name, and one of:

| Rule | What it does | Used for |
|---|---|---|
| `"block"` | simple shapes instead | the Watchstone (cylinder; `tower_three_blocks` for three blocks), the cave (a wedge with its door), Trym's shed (a house), the oak, the rock pile |
| `"clay"` | its own shapes in one flat colour (the default) | the camp, the range, the cabin's yard, the stone wall (its colliders stand full height where the ruin is broken, so a blockout from them misled), the kata wood, the owl tree, the scenery, the pen enclosure, the egg cairn, the posts |
| `"art"` | left as it is | nothing yet |
| `{"keep": [...], "drop": [...]}` | parts kept as art, parts taken away, the rest clay; `Name*` matches a start | the marsh: its water kept, reeds, tussocks and lily pads gone |

The pen enclosure also gets the path builder's rectangle frame on the floor, open toward the
keeper's gate.

**To give a landmark a blockout:** set its rule to `"block"`. With no builder of its own it gets one
box over its art; for a shape, add its script's file name to `BUILDERS` in `pen_blockouts_4d.gd`
and write a builder (a few lines: boxes, cylinders, wedges, gables, in the landmark's frame).

## Moving things

A blockout is a child of its landmark, never saved (no owner). In the pen, clicking it selects the
landmark's unit, as clicking its art does; move it and the landmark moves. Saving in the editor
never stores the dev look: the art goes back before the save and the look comes back after.

## Couplings (what the look had to respect)

Found by reading the pen, then by the tests in DEV (`look/_verify_look_runner.gd` and the pen's own
tests run with `PEN_LOOK=dev`). Anything new that sets or reads a landmark's mesh should go through
`Look.assign_mesh` / `Look.own_mesh` (static, in `pen_look_4d.gd`).

| Where | What it does | How it's handled |
|---|---|---|
| Rune stone, laptops, photo subjects, tutor markers, slice dial outlines | stop when their node is hidden | the look never hides a node |
| `grass/pen_grass_4d.gd`, the sand mask | measures landmark meshes, over several frames | reads `Look.own_mesh` |
| `grass/pen_grass_4d.gd`, the main-green terrain swap | sets the cave's and hills' meshes | `Look.assign_mesh` |
| `grass/pen_grass_4d.gd`, the ground | keeps the ground's own mesh and material | the look sets `dev_floor` on it instead of touching the ground |
| The meadow and murmuration films, `lookout_ground_4d.gd` | sample the hills' vertices | read `Look.own_mesh` |
| `pen_scenery_release_4d.gd` | lets the mountains and the cave's hill go in the cave, reads them back | goes through `Look.assign_mesh` / `own_mesh` |
| `pen_paths_4d.gd` | fades the sand's edges into the field's green | asks the look; in DEV they fade into their own white |
| The two crossings | put Systems (and the look) to sleep | the look always processes; the art is put back while you're away |
| The cave's tunnel | its walls are the hill's own mesh | the art is held past the door's first metres |
| Films | | the art is held while one plays; a film launched from the menu opens the pen in ART |
| The pen's fill light | an 8 degree soft light, drawn by the sky as a disc | its disc is shrunk in DEV, and the gradient sky's halo kept to a degree |
| A green rebake, the range's and camp's rebuilds, the Watchstone's stone merge | add meshes later | every mesh added under World or the pen takes the current look |
| The Watchstone's hand-placed stones | hidden, merged into one mesh at run time | hidden nodes are never touched; the merged mesh is |
| The editor's save | would store the look's changes on instanced nodes | art put back before a save, the look after |

Not a coupling, though it looked like one: the paths' found-as-you-go state. The probe's capture had
walked the player everywhere, which is what revealed them.

Two pen tests read what's on screen and were taught the dev look: the marsh's align test reads the
paint switch rather than the ground's mesh, and the scenery release test reads the hills' own meshes.

## Numbers

6 Oct, windowed 1280x720, RTX 5080.

| | Frame | GPU |
|---|---|---|
| ART, before any of this (pen / tower / cave) | 4.08 / 4.43 / 3.61 ms | 3.42 / 3.35 / 2.73 ms |
| DEV (pen / tower / cave) | 3.08 / 3.06 / 4.16 ms | 2.21 / 2.17 / 2.01 ms |

- **Switching:** to DEV 18 to 40 ms of work and one frame of 12 to 17 ms; to ART about 4 ms. The
  first switch to the art after opening in DEV: one 17 ms frame (1.7 s without the warm-up).
- **Reach:** 309 of the pen's 1,529 meshes change in DEV; 208 colliders and every node's visibility
  the same in both looks.
- **Tests:** today's 36 passing pen tests run in DEV and in ART. ART matches the baseline on every
  one. DEV matches on every one once two checks were taught to read the real state (above).
  `look/_verify_look_runner.gd`: 23 checks, all pass.
