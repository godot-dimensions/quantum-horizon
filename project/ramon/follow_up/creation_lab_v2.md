# Creature Lab v2: handover (9 Oct 2026)

Ramon's Creation Lab walkthrough (Part 1, items 1-9; Part 2, items 10-22), built as a fork:
`res://ramon/CreationLab/creature_lab.tscn` and the new hall `res://ramon/CreationLab/hall/creature_hall.tscn`.
The original `creation_lab.tscn` is untouched; copy over only when Ramon says. The plan, its decisions and its
open questions: `CreationLab/PLAN_V2.md`. Same day, mid-build: renamed **Creator Lab to Creature Lab** (titles,
door sign, lesson wall, info panel; textual only).

Ramon's order: "block everything in first, and than worry about optimization after". This is the block-in.
Every animal is the full live one; what each costs is the next batch.

## Round 3 (10 Oct, Ramon's walkthrough Part 3, items 25-42; `CreationLab/PLAN_ROUND3.md`)

The principle: a living exhibition in a stable building. **"Nightpic" / "Nikepeg" is Nike**, the pen's pig.

| Item | What | Where |
|---|---|---|
| 31 Nike stuck | The leash froze him: past its radius it stops him and checks again on the first frame of every walk, so once out he never walked again. Now his own roam with short walks | hall `_populate` "nike" |
| 40 Tab | The Botany Lab's per-light panel, carried; every hall light (centre, wash, four new wall lights), Save to `hall/creature_hall_lights.cfg` | `hall/carried/hall_light_editor.gd` |
| 38 building still | The view's slice no longer turns in the hall. Right drag turns every creature and tree through W round its own middle; R "Whole again". Walls, floor, pedestals, paths, doors, labels never move | `hall/turn_pivot_4d.gd`, hall `_apply_turn` |
| 42 dark mode | "DARK MODE ON / OFF · B" as the Voxel and Aquatic Labs say it, in both scenes; B works in the hall too. The hall's walls kept their lines (four lights grazing them, and in dark mode their grid lines a step lighter) | `_label_switch`, `_dark_walls` |
| 30, 36 Azathoth | The horse out; the cave's dreamer on a technical pedestal (dark grid base, blue deck, the hologram wider and taller), always turned to you, easing along W after you, red when you come within 3 m | `hall/carried/hall_dreamer_4d.gd` |
| 28 labels | The Botany Lab's framed panel at every creature, at the front edge (on the floor in front for small decks), facing the path: number, name, kicker | `hall/carried/hall_float_panel_4d.gd`, `_label` |
| 32 chipmunk | Twice the size, on a bigger stand; a fuller tail that shows (it was buried in the deck when it sat, and its angles pointed down), sat on its deck, its idle cycle fixed, rounder | `hall/carried/hall_chipmunk_4d.gd` |
| 33 close look | C by a small creature (chipmunk, owl; any station with `closeup`): your camera eases to a three-quarter view of it; C, a click or Esc eases back | `close_look()` |
| 37 holograms | Every creature pedestal has the showcase's hologram (they never had one); tallest round the brachiosaurus | `hall_pedestal.gd` `_hologram` |
| 29 green, grass | Green decks and the pen's grass (by way of the Botany Lab's copy), shorter, the pen's spacing, parting round the animals' feet | `hall/carried/grass/` |
| 34 trees | Their pedestals just wider than the trunk (radius 0.62), green with grass | `STATIONS` |
| 27 one door | No room 2: the hologram stands in room 1's back door itself, inside the wall, the doorway's size, under the CREATURE SHOWCASE sign; the hall's door the same | `_build_hall_door()` |
| 25 flicker | The entrance corridor's ceiling ran 0.5 m on through the entrance wall, its end on the wall's face. A kit room option keeps a ceiling flush on its open sides; on for this entrance only | `kit_room_4d.gd` `flush_open_ceiling` |
| 26 path dots | The side routes' dots had grown from about 2 to 6 cm with the wider guide line. Dot size and colour are now settings of the path network (unchanged by default); here 0.4 of the size, light cyan | `path_network_4d.gd` `dot_size`, `dot_color` |
| 39 birds | The heron now and then flies a loop off its deck and lands on the same spot; the crows fly their short loops and land again | `hall/heron_loop_4d.gd` |
| 41 light | The hall a little dimmer: exposure 0.9 of the lab's, the centre and the wash 15 % down | `EXPOSURE_K`, `creature_hall.tscn` |
| 35 cat (optional) | Built and taken out again: on its deck between the wolf and Nike it did not read at all (a black cat, low in dark grass), and its sit and wash cannot show after the walker cuts its hide. The gap stays open | `PLAN_ROUND3.md` |

**Frame time (10 Oct, `hall/_perf_hall_runner.gd`, 1280 x 720 window, vsync off, wall clock): 6.8 ms a frame with
everything, 3.4 ms with no stations.** The heaviest: Azathoth 1.6 ms, the wolf 1.4, the goat 1.0. The "72 ms a frame"
reported on 9 Oct was wrong: it was Godot's script-time monitor read with vsync on, not the frame
(follow_up/lofting_gotchas.md says as much). The runner's own "script time" line is that monitor; trust the perf
runner's frame column.

Checks: `hall/_capture_hall_runner.gd`, 35 of 35 passing on 10 Oct (Nike walks 6.3 m in 30 s; the building does not
move while 37 pivots turn; Tab, dark mode, labels, grass, holograms, the close look, both doors).

## Questions for Ramon

1. **The hall's title.** CREATURE SHOWCASE on the blue back wall, and on the sign over room 2's door. Keep, or
   another (Animal Creation, The Living Collection, Creature Lab)?
2. **"Nightpic"** read as **Nike the pig** (speech to text). Nike is on the left, a round pedestal.
3. **Trym's eight-legged creature and the symmetry creature** as two more stations? Trym's cannot be scaled
   (FABRIK) and does not travel; the symmetry creature is one rig. Not added yet.
4. **The brachiosaurus** is 7.4 m tall and 9.6 m long on a 10 m deck: it walks a slow small round at the deck's
   rear (0.2 m/s, turning 10 degrees a second). Its tail and head sweep past the deck's edge as it turns. A
   bigger deck, a smaller animal, or let it stand?

## Room 1 (`creature_lab.tscn`, `creature_lab_4d.gd`)

| Item | What | Where |
|---|---|---|
| 1 paths | The Voxel/Water Lab grid paths: PathCreator's network, built in code, straight runs and right angles. Entrance to the pedestal's round frame; a crossroad to the desk and the board; round the pedestal's right to the back door | `_build_route()` |
| 2 specimen toggle | The Voxel Lab's floating panel (plate, black glass, glow line, spring wobble) with the picker's slots and logic unchanged | `v2/picker_float_4d.gd` |
| 3 wolf | Forked: rump back, hind legs forward, hind hips apart (they overlapped 3 cm), head up a little, eyes bigger, black and out past the head's skin (they sat inside it). Its own bakes (`wolf2*`) | `v2/wolf2.tscn`, `v2/rd_wolf2_4d.gd` |
| 4 slice reset | R "Whole again" (the Water Lab's label): middle slice, home turn | `whole_again()` |
| 6 collision | The round pedestal's one box (1.6 m proud at the diagonals) is now three boxes following its circle | `_pedestal_boxes()` |
| 7 door | Room title over the door to the next room (CREATURE SHOWCASE); the 0.5 m floor gap under the back door closed | `HallSign` node, `_close_door_floor()` |
| loader | The Voxel Lab's loading board on the way in and on the way back from the hall (Ramon: "voxel labs has cool loaders"): bars for the specimen, the route, the wall panels, the hall door | `_open_board()`, `_feed_board()` |
| 8, 9 room 2 | The Paths showcase and the ceiling lines gone; room 2 is a short entry room whose far wall is the hologram door into the hall | `.tscn`, `_build_hall_door()` |

## The hall (`hall/`)

- **The room**: 30 x 44 m, 14 m ceiling, no ceiling lines, the back wall blue with the title (`creature_hall.tscn`).
- **Arriving**: the Voxel Lab's loading board while the stations build, one a frame (`hall/carried/vl_load_board.gd`).
  Back through the door you came in by: the hologram (`hall/carried/vl_shimmer_4d.gd`), into room 2 by its door.
- **Stations** (`STATIONS` in `creature_hall_4d.gd`: where, shape, size, height, who): the brachiosaurus on the
  centre's 10 m square; the wolf (wolf 2, x2 size) on a wide round deck; the horse on a wide square; Nike; the goat
  (with the strider walk, which it never had); chickens; heron; owl on a dead branch; chipmunk on a tall small
  stand; crows with a rail and a crate to perch on; four oaks on very low decks (`oak_lite2`, 28 leaves a node:
  the pen's trees are mostly `oak_lite3` at 24, so one step up and a little fuller).
- **Pedestals** (`hall/hall_pedestal.gd`): the lab's pedestal in any size, round or square; collision follows the
  shape.
- **Edge steering** (`hall/pedestal_roam_4d.gd`): the walk carries on; near the edge it turns in about 35 degrees
  (more if walking straight out), now and then a small turn of its own; never off the deck. Nike and the chickens
  steer themselves and are only kept on.
- **Paths**: from the door up the middle to the centre; branches near the door (chickens, heron), halfway (wolf
  and Nike left, horse and goat right), and up the left and along the back (owl, chipmunk, crows).
- **Through W** (`hall/w_population_4d.gd`): pedestals are 8 m deep in W like everything the kit builds, so each
  station's copies stand on the same deck at other W's (2.4 m apart, ana then kata): step with E/Q or turn the
  slice (right drag; R levels) and the decks hold other animals. Real copies that walk; never the illusion.
  Which stations and how many: `w_copies` in `STATIONS` (the brachiosaurus and Nike none).
- **Info cards** (`hall/hall_info_card.gd`, words in `hall/creature_hall_info.tres`): within 2.5 m of a pedestal's
  edge, its card at the right of the screen (name, HOW IT MOVES, WHAT IS 4D ABOUT IT); left click closes it until
  you have walked 4.5 m away.

## How to change it

- **Move or resize a station**: its line in `STATIONS`. Its path is in `_build_route()` (right angles only).
- **A card's words**: `hall/creature_hall_info.tres`, by station name.
- **More or fewer copies through W**: `w_copies`; spacing and jitter at the top of `w_population_4d.gd`.
- **How an animal walks its deck**: the settings passed to `_roam(...)` in `_populate()` (margin, look_ahead,
  turn_rate, turn_degrees).

## Found and fixed on the way

- Sign titles cut off on a short wall ("CREATURE SHOWCA"): a sign's title now shrinks to fit its wall
  (`kit/kit_wall_text_4d.gd`; a title that fits keeps its size); the board's title likewise.
- The horse, goat and brachiosaurus walked on the Model copy of the strider, which skins every vertex every frame:
  about 20 ms a station with its W copy. Now the pen's copy (rigid pieces, joints blended), as the wolf.
- The round pedestals were cubinders 4 m deep in W, so the copies through W stood on air: now 8 m like the rest.
- You started 2.5 m inside the hall with the camera 6 m behind you, outside: the start is now 6.8 m in.
- Coming back from the hall you faced the door you came through: now into the lab.

## Open: turning the slice in the hall

The hall, like every kit room, is 8 m deep in W. Turned 30 degrees, the slice leaves the walls behind (they drop
into the dark) and a station only shows where one of its W copies is cut. Options: limit the turn in the hall;
a hall deeper in W with more copies per station (the W Exploder's density sum: more animals, more cost); or turn
the slice only at the stations. Waiting on Ramon.

## Not done yet (in PLAN_V2)

- The heron's short flight loops (step 53: `idle_only` must go off, with its flight path overwritten).
- Trym's and the symmetry creature (question 3).
- The fur experiment on the wolf (part K, last).
- Optimisation (the next batch): every animal is lofted live; the copies through W double most of them.

## Checks

`hall/_capture_hall_runner.gd` (windowed; `-- quick=1` skips room 1): room 1's route, picker, wolf 2 and R;
the door into the hall; the board, every station, the walkers kept on their decks for 8 s, frames of every area,
a step ana and a turned slice, the card and its click, and the way back. Frames in
`smoke_test_output/creation_lab/v2/`.
