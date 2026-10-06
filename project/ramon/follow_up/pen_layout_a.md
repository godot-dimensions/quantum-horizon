# The pen, layout A: over the hill (6 Oct 2026)

The plan, its decisions and its progress: `PenLayout/PLAN_A.md`. The earlier work (units, the fence
fix, units made movable): `PenLayout/PLAN.md`.

## What you play now

1. You wake at Trym's shed on the field's south edge, facing the cave hill. The tower and the
   balloon show over its left shoulder; the pen is hidden behind it.
2. The professor stands in front of the hill. Its arch is not there: the hill's door is four
   metres ana. Walk up to the rock and the tutor says so; his own line says so too.
3. The path goes two ways round the hill. West is short, but a ruined wall runs from the cave hill
   to the west hill (the funnel), as deep in W as they are; the path goes through its arch, where a
   fallen pillar lies across the way. The pillar is thin in W: turn the slice (hold the right mouse
   button and drag) and walk on, and you walk round it through W. The tutor names the control and
   you think out loud what to do. East is the long way, by the meadow.
4. Round the shoulder the pen comes into view with the tower behind it. The keeper is at the gate;
   the objective line changes to the chickens' when you reach him.
5. Two hidden bags of azoth (two pieces each, so two troughs): at the researchers' camp in the
   meadow's middle, 2.5 m kata (tents, a bonfire in the middle, a kitchen scaffold, the bag by a
   crate), and by a cairn at the hill's east foot, 7 m ana. Thin paths lead to both; their W dots
   say which way and how far.

## Keys

- **F5** the paths' look: sand, or the dev look (a white path with the blue icons on it)
- **F6** paths found as you go (reveal) or all shown (static)
- **Alt+O** grass on or off (off by default now; its panel folds to that one switch)

Both switches are remembered between runs (`user://pen_settings.cfg`, section `path_looks_2`); a
first run is the sand look, static. The sand (`CreationLab/PathCreator/render/path_sand.gdshader`)
is the pen yard's own colour and mottle, its edge soft and irregular and fading into the ground's
real colour (the Grass node's glow, handed over by `scripts/pen_paths_4d.gd`). Where strips and
patches overlap, the pixel with the most sand wins (each writes its depth a hair further back the
less sand it has), so a soft edge never paints a seam over another strip.

## Where things are

- The pen: `chickenpen/playable_world.tscn`. Backup before layout A:
  `chickenpen/.backup/2026-10-06_before_layout_a/`, git tag `before-layout-a-2026-10-06`.
- The paths: `World/Paths` (PathCreator's network). The routes: `PenLayout/paths/pen_a.tres`,
  written by `PenLayout/scripts/_make_pen_paths_runner.gd`; change the runner and run it again
  rather than editing the file. Destinations follow their unit's `...Arrival` marker, so moving a
  unit carries its path's end (the bends before it stay put).
- The wall: `World/StoneWall` (`scripts/pen_ruin_wall_4d.gd`: FenceGenerator4D modules, the arch,
  the fallen pillar, the self-talk). The hills: `World/WestHill`, `World/TowerHill`
  (`scripts/pen_round_hill_4d.gd`, shapes in `terrain/pen_round_hill_4d.gd`, baked by
  `_bake_terrain_runner.gd what=hill_west` / `hill_tower`). The camp: `World/EggCamp`
  (`scripts/pen_camp_4d.gd`); the cairn: `World/EggCairn` (`scripts/pen_stones_4d.gd`). The bags:
  `World/Pickups/AzothBag1` and `2`. The oak: `World/Oak` (`scripts/pen_oak_4d.gd`, the Arboretum's
  own baked oak and GPU leaves).
- The switches: `Systems/Paths` (`scripts/pen_paths_4d.gd`).
- Place hints: any node in the group `tutor_spot` with `tutor_*` metadata (`scripts/pen_tutor_4d.gd`).

## The fence frames

Each hero building has a switch that swaps its frame for one built by Aaron's FenceGenerator4D:
the tower `fence_frame` (base, deck railing, cabin walls), Trym's shed `fence_frame` (a timber
frame round the walls; the walls stay for the cutaway in his scene), the range booth `fence_posts`.
Frames to compare: `smoke_test_output/pen_layout/tower/` and `.../hut/`. The paths cost about
1.1 ms a frame; the frames made no measurable change.

**The tower's is live** (6 Oct, the tower pass; `units/lookout/lookout.tscn`), with three changes
from the first build:
- the base splays in W as much as it leans in x and z, so its top holds the deck's whole W depth
  (before, a slice near the deck's W end showed the deck floating with no legs under it);
- the deck rail's posts are 2.4 apart, either side of the ladder (a 1.2 grid put a post in the
  middle of the ladder's opening);
- the hut's slats are 0.8 apart (0.6 before), and the ladder is 2.4 deep in W, the depth you can
  climb it from, not the cab's 6.4 (which read as two plates in a turned slice).
Tetrahedra: 6,480 on the old frame, 34,664 on the first fence build, 23,192 now
(`PenLayout/scripts/_study_tower_cells_runner.gd` counts them part by part). The shed and booth
frames are still off.

The one thing to know about the generator: its ribs are full-height plates on its grid lines, so
where the slice falls on a grid layer in W the frame reads as solid walls, and between layers as an
open lattice. The spacing is chosen to keep every layer off the farm's slice.

## Checks

- `PenLayout/scripts/_check_layout_runner.gd`: where everything stands (two warnings stay: the
  wolf's run-in is blocked south by the hill and west by the range, and the wolf now picks a
  clear side; the hill's corner is near the meadow film).
- `PenLayout/scripts/_verify_opening_runner.gd`: the opening, beat by beat.
- `PenLayout/scripts/_verify_eggs_paths_runner.gd`: both bags, and F5 F6.
- `PenLayout/scripts/_capture_pen_runner.gd <set>`: frames (sets before, a, paths, tower, hut,
  feedback, hero, cavetilt, cavesweep, cavediag).

## Lines for Ramon to read

New player-facing text, all in `scripts/` unless said:
- Objective at the start (scene, Systems/Game): "Follow the path round the hill to the keeper at
  the pen."
- Tutor at the arch (pen_ruin_wall_4d.gd): "The fallen pillar is thin in W. Hold the right mouse
  button and drag to turn your slice, then walk on."
- Thought at the arch (pen_ruin_wall_4d.gd): "Blocked. But that pillar looks thin in W. If I turn my
  slice a little, I could walk round it."
- Tutor at the closed arch (units/cave/cave.tscn, DoorSpot): "The arch is ana of your slice. Hold E
  until it opens."
- Tutor after 8 s off the farm's slice (pen_tutor_4d.gd): "R takes you back to the farm's slice."
- The professor (professor_script.gd, how_to_mine, first line): "The hole behind me. Not in this
  slice; four metres ana of it. Step that way until the arch opens, then walk in until it gets
  dark. The miner at the bottom is called Hale; he has newer numbers than mine and fewer opinions."
- A bag found (pen_collector_4d.gd): "Found: a bag of azoth, 2 pieces. Somebody hid this."
- The switches (pen_paths_4d.gd): "Paths: sand", "Paths: dev look, icons on white", "Paths: found
  as you go", "Paths: all shown"; on the controls card: "paths: sand, or icons on white", "paths
  found as you go, or all shown".

## The cave hill (6 Oct)

- The turf shoulder over the arch used to run on at full height through the hill and out past the
  dome, where the bake's box cut it off: flat tables with sheer sides at both ends of the hill. It
  now slopes into the dome behind the arch (`shoulder_height`), the dome reaches further toward the
  arch (`HALF` 11.5 along z), the dome and the rock face meet in a smooth maximum rather than a
  crease (`block_density`), and the bake's box reaches 7 m in front of the mouth so the shoulder's
  slopes come down to the field instead of ending in walls. Rebaked: `terrain/baked/cave_hill.res`.
- The cave's fade to black (`scripts/pen_cave_fade_4d.gd`) was bounded across the tunnel but not
  along it, so the field north of the mouth, as wide as the arch, counted as deep inside. With the
  pen now behind the hill and the cave 4 m ana, that strip reached the farm's slice by 0.1 m: a black
  screen from the hill's back to the field's north edge, x 3.4 to 11.6: across the pen's gate,
  where both paths meet, and the east path into it. It now ends at the tunnel's blind end and the arch's top;
  `_verify_cave_fade_runner.gd` checks behind the hill on both slices and on the hilltop.

## The second round (6 Oct, Ramon's notes after playing)

- The road at the rock pile's fork: the diagonal to the gate is gone; the road from the south runs
  into the cross-road where the tower and range roads branch, and on to the gate.
- The tower: the fence generator's ribs are 0.8 of its posts' height by default, and on the farm's
  slice the ribs are what you see, so the legs stopped 2 m under the deck and the hut's slats under
  its roof. Ribs now full height; the base has no filler (four corner legs and girts, the old
  silhouette); the hut is plain white with window frames and corner pillars, no fence tech; sand
  under the tower (the Grass node's `sand_round`).
- The balloon: six reds; moored 4 m further west of the tower.
- The crows: a landing was a fixed 1.1 s glide from wherever the crow was, fine round the pen but
  48 m to Trym's roof since layout A (40 m/s). A far perch is now flown to first, then landed on.
- The paths drape over solid things; the fallen pillar's body is marked `drape_through` so the path
  lies on the ground under it.

## Open

- The cave's green spot (the slice turned steeply lengthways, 35 to 55 degrees; capture sets
  cavesweep, cavediag) is fixed the cheap way, as Ramon asked: two low dark boxes over the tunnel's
  floor where it tapers to its W edge (`scripts/pen_cave_hill_4d.gd` `_tunnel_patch`). It was the
  hill's own mesh: a few dual-contoured vertices there coloured as mossy rock.
- The meadow film may need re-aiming with the hill beside the meadow.
- The shed and booth fence frames: whether they go live, and their spacing and rings.
- Mark size (`p_scale` 1.4) and sand width (1.3 m) are first guesses from frames.
- Older failing tests are listed in `PenLayout/PLAN.md` under "Later".
