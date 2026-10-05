# The pen, layout A: over the hill (6 Oct 2026)

The plan, its decisions and its progress: `PenLayout/PLAN_A.md`. The earlier work (units, the fence
fix, units made movable): `PenLayout/PLAN.md`.

## What you play now

1. You wake at Trym's shed on the field's south edge, facing the cave hill. The tower and the
   balloon show over its left shoulder; the pen is hidden behind it.
2. The professor stands in front of the hill. Its arch is not there: the hill's door is four
   metres ana. Walk up to the rock and the tutor says so; his own line says so too.
3. The path goes two ways round the hill. West is short, but a dry stone wall crosses the whole
   west side; it is thin in W, so a metre and a half ana it is not there (the path steps ana with
   it, two warm W dots where it leaves the farm's slice). East is the long way, by the meadow.
4. Round the shoulder the pen comes into view with the tower behind it. The keeper is at the gate;
   the objective line changes to the chickens' when you reach him.
5. Two hidden bags of azoth (two pieces each, so two troughs): in a ring of standing stones in the
   meadow's middle, 2.5 m kata, and by a cairn at the hill's east foot, 7 m ana. Thin paths lead
   to both; their W dots say which way and how far.

## Keys

- **F5** paths found as you go (reveal) or all shown (static)
- **F6** path icons on or off
- **F7** sand paths on or off
- **Alt+O** grass on or off (off by default now; its panel folds to that one switch)

The three path switches are remembered between runs (`user://pen_settings.cfg`). Two looks, never
mixed (Ramon, 6 Oct): the field's is sand alone, so a first run is sand on, icons off, static; the
sheet's blue icons are for a white dev floor, and while sand is showing any icons switched on are
drawn in the sand's colours instead. Checked on PathCreator's white lab floor (capture set
devfloor): icons alone there look as clean as in the path lab, with the network's `under_color`
set to the floor's colour. The sand's edge is dithered grain by grain rather than blended, so where
strips and patches overlap there are no dark seams.

## Where things are

- The pen: `chickenpen/playable_world.tscn`. Backup before layout A:
  `chickenpen/.backup/2026-10-06_before_layout_a/`, git tag `before-layout-a-2026-10-06`.
- The paths: `World/Paths` (PathCreator's network). The routes: `PenLayout/paths/pen_a.tres`,
  written by `PenLayout/scripts/_make_pen_paths_runner.gd`; change the runner and run it again
  rather than editing the file. Destinations follow their unit's `...Arrival` marker, so moving a
  unit carries its path's end (the bends before it stay put).
- The wall: `World/StoneWall` (`scripts/pen_stone_wall_4d.gd`). The egg places: `World/EggStones`,
  `World/EggCairn` (`scripts/pen_stones_4d.gd`). The bags: `World/Pickups/AzothBag1` and `2`.
- The switches: `Systems/Paths` (`scripts/pen_paths_4d.gd`).
- Place hints: any node in the group `tutor_spot` with `tutor_*` metadata (`scripts/pen_tutor_4d.gd`).

## The fence frames (built, not live)

Each hero building has a switch that swaps its frame for one built by Aaron's FenceGenerator4D:
the tower `fence_frame` (base, deck railing, cabin walls), Trym's shed `fence_frame` (a timber
frame round the walls; the walls stay for the cutaway in his scene), the range booth `fence_posts`.
All off. Frames to compare: `smoke_test_output/pen_layout/tower/` and `.../hut/`. They multiply the
buildings' tetrahedra (tower 6,480 to 34,664) with no measurable change in frame time; the paths
cost about 1.1 ms a frame.

The one thing to know about the generator: its ribs are full-height plates on its grid lines, so
where the slice falls on a grid layer in W the frame reads as solid walls, and between layers as an
open lattice. The spacing is chosen to keep every layer off the farm's slice.

## Checks

- `PenLayout/scripts/_check_layout_runner.gd`: where everything stands (two warnings stay: the
  wolf's run-in is blocked south by the hill and west by the range, and the wolf now picks a
  clear side; the hill's corner is near the meadow film).
- `PenLayout/scripts/_verify_opening_runner.gd`: the opening, beat by beat.
- `PenLayout/scripts/_verify_eggs_paths_runner.gd`: both bags, and F5 F6 F7.
- `PenLayout/scripts/_capture_pen_runner.gd <set>`: frames (sets before, a, paths, tower, hut).

## Lines for Ramon to read

New player-facing text, all in `scripts/` unless said:
- Objective at the start (scene, Systems/Game): "Follow the path round the hill to the keeper at
  the pen."
- Tutor at the wall (pen_stone_wall_4d.gd): "This wall is thin in W. Hold E to step ana past it."
- Tutor at the closed arch (units/cave/cave.tscn, DoorSpot): "The arch is ana of your slice. Hold E
  until it opens."
- Tutor after 8 s off the farm's slice (pen_tutor_4d.gd): "R takes you back to the farm's slice."
- The professor (professor_script.gd, how_to_mine, first line): "The hole behind me. Not in this
  slice; four metres ana of it. Step that way until the arch opens, then walk in until it gets
  dark. The miner at the bottom is called Hale; he has newer numbers than mine and fewer opinions."
- A bag found (pen_collector_4d.gd): "Found: a bag of azoth, 2 pieces. Somebody hid this."
- The switches (pen_paths_4d.gd): "Paths: found as you go", "Paths: all shown", "Path icons: on",
  "Path icons: off", "Sand paths: on", "Sand paths: off"; on the controls card: "paths found as you
  go, or all shown", "path icons, on or off", "sand paths, on or off".

## Open

- The meadow film may need re-aiming with the hill beside the meadow.
- The fence frames: which go live, and their spacing and rings.
- Mark size (`p_scale` 1.4) and sand width (1.3 m) are first guesses from frames.
- Older failing tests are listed in `PenLayout/PLAN.md` under "Later".
