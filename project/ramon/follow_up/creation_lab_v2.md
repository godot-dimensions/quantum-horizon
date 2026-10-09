# Creature Lab v2: handover (9 Oct 2026)

Ramon's Creation Lab walkthrough (Part 1, items 1-9; Part 2, items 10-22), built as a fork:
`res://ramon/CreationLab/creature_lab.tscn` and the new hall `res://ramon/CreationLab/hall/creature_hall.tscn`.
The original `creation_lab.tscn` is untouched; copy over only when Ramon says. The plan, its decisions and its
open questions: `CreationLab/PLAN_V2.md`. Same day, mid-build: renamed **Creator Lab to Creature Lab** (titles,
door sign, lesson wall, info panel; textual only).

Ramon's order: "block everything in first, and than worry about optimization after". This is the block-in.
Every animal is the full live one; what each costs is the next batch.

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
