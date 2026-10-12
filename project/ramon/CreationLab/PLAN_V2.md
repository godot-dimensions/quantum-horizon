# Creation Lab v2: plan (9 Oct 2026)

From Ramon's walkthrough feedback, parts 1 and 2 (items 1 to 22), and research into the Voxel Lab, the Water Lab, the
current Creation Lab and the project's animals. **Block everything in first; optimisation is a second step after this
batch** (Ramon: "not that important now").

## Decisions, and why

- **A fork, not an edit in place.** The Creation Lab is finished and wired into the menu, so the update is built beside it
  as `creature_lab.tscn` with forked scripts where they must change. The current lab stays exactly as it is until Ramon
  says to copy the new one over. Nothing is pushed until he has seen it.
- **The animal hall is its own scene** (`CreationLab/hall/creature_hall.tscn`), entered through a hologram doorway at the
  back of room 1, behind the Voxel Lab's loading board. Reasons: many walking animals plus copies through W are the
  heaviest thing in any lab, and a separate scene builds them behind the board (no visible pop-in, which Ramon called
  "weird" in the Voxel Lab) and frees them when you go back. Room 1 stays as light as it is now.
- **Paths are the PathCreator network laid out on right angles**, as in the Voxel Lab and the Water Lab: a graph of
  start, bend, junction and destination points written by a generator, straight runs only, destinations framed round
  their stations. Not the old floor strips (`kit_path_4d`, `kit_pivot_4d`, `PathLab`).
- **The "wobbly toggle" is the floating panel on a spring** (`vl_float_panel_4d` / the Water Lab's `float_panel_4d`):
  the specimen picker keeps its logic (`pick(i)`, `Showcase.set_exhibit`) and gets that panel as its face.
- **Slice reset is R**, labelled as at the Water Lab's showcase ("R  Whole again"): it returns the exhibit to the
  middle slice and its home turn.
- **"Nightpic" is read as Nike the pig.** No creature of that name exists in the repo (code, scenes, docs or history).
- **Walking animals stay on their pedestals by steering, not by new animation.** The four-legged walker cannot turn
  mid-stride, so near the edge an animal eases to a stop, turns inward about 35 degrees (more if it is facing out), and
  walks on: its own walk cycle untouched (the way Nike and the cats roam in the pen).
- **Copies through W** use a new sibling of the W Exploder (which only knows trees): real copies of chosen stations at
  other W's, so stepping or turning through W reveals a different population. Never the illusion mode.
- **Pedestal collision**: physics is axis-aligned boxes only, so the round plinth gets three boxes (a square and two
  bars) that follow its circle, instead of one box that stood 1.6 m proud at the diagonals.
- **The hall's title**: CREATURE SHOWCASE, subtitle "Lofted, rigged and animated in four dimensions". Technical, not a zoo;
  easy to change in one line.

## Steps

### A. The fork (1 to 6)
1. Copy `creation_lab.tscn` to `creature_lab.tscn` with its own scene uid; copy `creation_lab_tuning.cfg` to
   `creature_lab_tuning.cfg` so tuning one never moves the other.
2. Fork the root script as `creature_lab_4d.gd`; point the fork's root at it.
3. List every script the fork changes; fork only those (suffix `2`), reference the rest unchanged.
4. Give the fork its own way in (opened directly; no menu change until Ramon says).
5. A smoke runner for the fork (`scripts/_v2_smoke_runner.gd`): loads, walks the route, prints errors.
6. Save point: commit locally, never push.

### B. Room 1: paths (item 1)
7. Remove `Guides` (the old strips and pads), `PathLab`, `BigRoom/PathLabSign` and the floor ring the root kept in step.
8. Carry the Water Lab's PathCreator copy (it has guide and edge colours and the floor swatch) into `CreationLab/v2/`.
9. A path generator for the lab (`v2/tools/make_paths.py`, the Voxel Lab's `Graph` helper): start at the entrance door.
10. Route: entrance, straight to the pedestal's ring, branch left to the research desk, branch right to the wall
    panel, straight on to the back door. Right angles only.
11. Targets under `Paths/Targets` with footprints: the showcase, the desk, the wall panel, the back door.
12. Frames: round round the pedestal, rect at the desk and the door; margin as the Water Lab (0.12).
13. Visit states: destinations turn completed as you visit them (the Voxel Lab's `_route_states`).
14. Look in both moods; check marks stop cleanly at junctions.

### C. Room 1: the specimen panel (item 2)
15. Carry the floating panel into `v2/`; give it the specimen tiles as its pages (one tile per animal).
16. Keys 1 to 6 and Left/Right still pick; the lit tile follows the showcase.
17. The panel springs toward you as you approach the pedestal; the old desk picker is removed from the fork.
18. Check the swap (old animal out, new one in) is unchanged.

### D. Room 1: slice reset and more specimens (items 4, 5)
19. R at the showcase: middle slice, home turn; strip label "R  Whole again".
20. A brachiosaurus exhibit (from `rigged_creature_ramon.tscn`'s Brachio), fitted to the pedestal's stand height.
21. A heron exhibit (`lookout/heron_4d.gd`, standing and stalking in place).
22. A horse exhibit (`Model/animation_test.tscn`, the strider walk) as the third.
23. Each new exhibit answers the showcase's interface (walk, slice, wire); story parts they cannot play are skipped.
24. Panel tiles for the six specimens (goat, chicken, wolf, brachiosaurus, heron, horse); the cat left out.

### E. Room 1: pedestal and the way out (items 6, 7)
25. Replace the pedestal's single box with three boxes following the circle; probe the player round it.
26. A black title over the back door naming the hall (the Voxel Lab's sign: `kit_wall_text_4d`, kind "sign").
27. Close the 0.5 m floor gap under the back door; check walls and ceiling meet with no clipping.
28. The back door becomes the hologram doorway into the hall (`vl_shimmer_4d`, flash out, change scene).
29. Room 2 in the fork: its Paths sign, cases and blue wall removed; its shell kept as the short entry hall.

### F. The wolf (item 3)
30. Fork the wolf model as `v2/wolf2.tscn` with its own bake names, so the current lab's wolf is untouched.
31. Rump back (the Rump and Loin balls), hind legs a little forward; check the hip balls no longer cut each other.
32. Head raised slightly (Skull, Muzzle, Nose).
33. Eyes larger and entirely black, set proud of the skull so they read.
34. Re-bake the wolf's stages and walk pieces; compare before and after side by side.

### G. The creature hall (items 10 to 13, 22)
35. `hall/creature_hall.tscn` + `hall/creature_hall_4d.gd`: a kit room about 30 m wide, 44 m deep, ceiling 14 m.
36. No ceiling cove lines in the hall (the bright strip near the ceiling).
37. Arrival: you appear just inside the entrance, facing in; going back through the door returns you to room 1's back door.
38. The loading board (`vl_load_board`) while the animals are built: one bar per station.
39. Bright lab look (white grid floor and walls), the blue back wall with the title.
40. The central square pedestal, 9 m, on the entrance's axis, a third of the room's width.
41. The brachiosaurus at the back of the central pedestal, scaled to impress (about 7 m tall).
42. The main path straight from the entrance to the central pedestal's frame.
43. Lighting: one soft light per station, the kit's lights; room light for the bright mood.
44. The slice turns freely here (right drag), R levels it; the room is fully sliceable.

### H. Stations and animals (items 14, 15, 17 to 20)
45. Station kit: square, round, low and wide pedestals from `kit_pedestal`, sized to each animal.
46. Wolf: a wide pedestal, walking with the edge steering.
47. Edge steering (`hall/pedestal_roam_4d.gd`): walk straight; near the edge ease off, turn inward ~35 degrees (more if
    facing out), walk on; works for any strider animal.
48. Horse and goat on wide pedestals, roaming.
49. Nike on a round pedestal, roaming (her own walk).
50. Chickens (two) on a low round pedestal, pecking in place (the exhibit walker).
51. Chipmunk on a very small pedestal, idle.
52. Owl perched on a branch on a pedestal (a branch prop with a box under its perch).
53. Heron on a round pedestal, standing; now and then a short flight loop round its station and back.
54. Crows (two or three) with a home station: fly loops in a local area, land on their branch, a pedestal edge or the
    floor nearby, return (the pen's crow, perches given as boxes).
55. Trym's eight-legged creature and the symmetry creature as two more stations, if they hold up (unscaled).
56. Trees: the pen's oak one step up (`oak_lite2`), a little more leaf, on very low pedestals barely wider than the trunk;
    four to six of them breaking up the hall.
57. Branch paths from the main route to each station, right angles, asymmetric but on one grid.
58. Station layout: a clear structure (main axis, two side aisles) with varied sizes and heights.

### I. Copies through W (item 16)
59. `hall/w_population_4d.gd`: copies chosen stations to other W's (spacing, side offset, a turn, a little size change),
    the W Exploder's idea for any node.
60. Choose who is copied: small and medium animals two or three times, the brachiosaurus never.
61. Copies are real (walk, roam, fly), not the illusion.
62. Check stepping (E/Q) and turning the slice show different populations.

### J. Animal information (item 21)
63. A fixed-size info card (never over the animal, never resizing with distance), shown when you come near a station.
64. Content per animal: name, how it moves, what is 4D about it, one small diagram where it helps.
65. Left click dismisses it; it does not come back until you leave and return; right drag still turns the slice.
66. Words in one resource (`hall/creature_hall_info.tres`), so they are easy to edit.

### K. The fur experiment (item 3, last)
67. A strand scatter over the wolf's surface, short and dense, after the Arboretum's leaf field, following each walk piece.
68. Judge it by frames; keep it only if it reads as fur and costs little; otherwise the wolf keeps its surface.

### L. Checks and handover (69 to 72)
69. Runners: room 1 route and specimen swap; hall arrival, stations, W copies; frames in both moods at 4K.
70. Measure frame time in the hall (for the optimisation step that follows this batch).
71. `follow_up/creation_lab_v2.md`: what was built, how to change it, open questions.
72. Show Ramon; copy over the original only when he says.

## Open questions for Ramon
- The hall's title (CREATURE SHOWCASE) and the room 1 door sign: keep, or another name?
- Nightpic: is it Nike the pig?
- Trym's creature and the symmetry creature in the hall: wanted?
