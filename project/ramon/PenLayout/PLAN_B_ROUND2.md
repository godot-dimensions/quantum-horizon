# Layout B, round 2: Ramon's playtest notes (7 Oct 2026)

From his play of layout B (session images 29-38) and "a good thorough playtest in the end ... front to
back. dont worry about the menu linkages yet." Fifty steps, done in this order.

## A. Start
1. Save his play logs, take the Godot lock, back up everything this round touches to `chickenpen/.backup/2026-10-07_round2/`.
2. The professor as a ritual tech wizard, moved beside the cave road (staged on 6 Oct).
3. Baseline frames of today's state (top view and the route shots, both looks), to compare against at the end.

## B. Bugs that block play
4. Mithra: why she stands crying at the wall. Her roam circle (6.5 m round (-7.5, 7)) reaches the town wall at z 12. Move her roam to open ground behind the wall, and make her turn away from anything she bumps into.
5. Mithra test: watch her for three minutes; fail if she stands still too long or presses into a wall. Frames of her walking.
6. V at the camp drops you into the cave: reproduce it in a runner, find the handler, fix it.
7. Every key in the pen checked for double use (V for the camp, the lookout and the character; 9; I; Tab), so one press does one thing.
8. The art look starts with the grass on again.
9. The centre glow gone: its mesh, its layers and its panel button.
10. Range rings and boards: fix the normals on the spun discs, frames to confirm.

## C. Sand
11. The pen's sand reaches past the fence; the grass starts beyond it.
12. The range yard's floor is sand, no grass inside.
13. Camp: the path's end bleeds into the camp's sand circle.
14. A sand patch under the cave entrance.
15. Tower: a sand layer painted over the path's end, so the sand flows over it and the green edge goes.

## D. Grass
16. The hills' grass the same green as the meadow's.
17. The clearings round every landmark get the soft random edge with shorter blades, not boxes.
18. The grass reaches a little over the path edges, so no green strip shows.
19. The greenery panel: do its settings and rebakes survive a restart? If not, a Save button.
20. The grass following the path in follow mode: try it; build it if it is cheap, otherwise say why not.
21. Frames of every clearing edge, both looks.

## E. Paths window
22. The path settings in their own window (keys stay 9 and Shift+9).
23. Check it in both looks, and that the choice is remembered after a restart.

## F. Landmarks and the DEV look
24. The town gate wider, the wall a little lower.
25. The no-shortcuts walk test again with the new gate: only the gate leads north.
26. The pen house remade with the fence set where it fits, looking like the original; the old one kept to switch back to.
27. The pen house tested: side-by-side frames, chickens in and out, the door, collisions.
28. The oak on the tower red in the art look.
29. Wren's balloon blue in DEV.
30. DEV tree blocks taller, measured against the art crowns.
31. DEV and ART frames of every landmark.

## G. Trees in W
32. Measure what a tree costs drawn and culled, to set a safe count.
33. Design the W forest: trees spread through W, not on one slice, each W layer shifted and turned a little, so trees come and go one by one as the slice turns. Lanes, landmarks and the meadow view stay clear in every W.
34. Crowns rounder in W, so a tree shrinks out as the slice leaves it instead of vanishing at once.
35. Plant it from a seeded script (repeatable; the DEV look gets blocks for every tree).
36. Slice-turn frames at three places, both looks.
37. Perf at the five route views with the new planting.

## H. Front-to-back playtest (menu linkages left out)
38. Update the test runners still on old positions that the playtest needs.
39. Opening: spawn, the opening text, follow the path to Trym, his talk and the quest.
40. Chickens: catch, carry, pen, eggs; Nike by the pen and her grab.
41. Mithra: find her, talk, her quest steps.
42. Range: walk in, the counter, the targets, every game including Wolf Run.
43. Camp: V align, the azoth bag.
44. Gate and town: through the gate; the wall shortcuts are closed.
45. Lookout tower: climb, photography, marsh align, the balloon ride.
46. Cave: in through the door, the dark, inside, out again; twice, in both looks; the professor's talk at its road.
47. Sequences and animations: cinematics (K), the wolf raid, the flock, the celebration, slice home (R), full restart; logs clean of script errors.

## I. Video and handover
48. The walking video: a scripted run from the player's eye through four or five scenes, switching DEV and ART on the walk and turning the slice at the trees, the camp and the cave; 1080p.
49. Watch it frame by frame, fix what is ugly, render the final; send it.
50. Handover note, PLAN_B status, memory, commit by explicit path.

## J. Afterwards (Ramon, 7 Oct, during the round)
51. The range in W: a test of how quickly the range slices out as the slice turns or W changes (the shooter's targets, boards, frames, table), and a design so it holds in view longer, as the fence enclosure does; built and tested. Ramon: "ideally i'd still like to update the range in the range scene (not talking about the linked range), and that the W versions update accordingly": the W versions are made from what is authored in units/rune_range, never by hand, so editing the range there updates them.

## K. After everything above: the W tools (Ramon, 7 Oct, "I might have a brilliant idea")
1. A W exploder for trees: a tool that stands a tree again in more W slices above and below by settings,
   each tree with its own offset parameters so it works in 4D; procedural. In a new folder with a test scene
   of trees; once it works (and mimics what scripts/pen_trees_4d.gd does now), it replaces that in the pen.
2. A W optimiser for landmarks and hero objects: analyse an asset (the range, the tower) and 4D-ify it, with
   a W wrap length to set (as the mountains wrap all round in W, so they are in every slice), smart offsets
   from the analysis, a UI or a .tres with a button, and template presets that are tested.
Process: an 80-step plan, a significant share of it research (online too) and testing; only then extend the
plan and execute it as a whole. Permission to update the playable world once it works. Step 51 (the range in
W) folds into the landmark optimiser.

## Status (7 Oct, night)
- 1-3 done: logs saved, backup in chickenpen/.backup/2026-10-07_round2/, the wizard professor by the cave road; frames
  round2 (tag a = before, b = after) in smoke_test_output/pen_layout/.
- 4-5 Mithra: she had no way to notice a blocked spot (her old walk stood 84 s against the town wall at (-8.8, 11.4)).
  Now a clear-line check before each spot and a give-up after 0.9 s without getting closer
  (scripts/pen_searcher_4d.gd); chickenpen/scripts/_verify_mithra_walk_runner.gd: 151 m in 3 min, never stuck > 0.7 s.
- 6-7 Keys: the cave's debug trip sat on V with the camp's align since the cave went in: now Shift+C (the crossing
  compares keys with modifiers), on the controls card. T: the slice assist and the rig both listened and only one
  heard; the assist owns T and drives the rig's lock (set_locked). Audit: chickenpen/scripts/_audit_pen_keys_runner.gd.
- 8 grass on in the art look; 9 the centre glow, its button and Ctrl+O gone.
- 10 the range's spun parts: 5,073 of 18,243 faces were facing in (28%); turned out and shaded flat (_face_out).
- 11-15 sand: every ground_sand shape now also clears the grass (a soft ragged edge, its own W lane; four lanes now:
  farm, camp, cave, marsh). PenSand over the pen's run (+2.2 m), CaveSand at the mouth. The paths' soft edges fade into
  the ground's own paint (path_sand.gdshader ground_mode 2), so no green rim over sand (tower, camp).
- 16 grass on the hills: baked heights (grass/grass_heights_4d.gd, _bake_grass_heights_runner.gd, 0.5 s; remade at
  start if a hill moved); no blades above 9 m or steeper than 0.9.
- 17-18 more landmarks with the soft edge; the paths out of the hard mask, a path field instead (blades 0.2 m inside
  the sand's edge, trodden fringe), remade when the path type changes, so 20 (grass follows follow mode) is done too.
- 19 Save settings in the grass panel (grass/grass_saved.cfg); 22 the paths' own window (scripts/pen_paths_panel_4d.gd).
- 24 gate 3.4 m wide, wall 4 m (4.4); 26-27 the coop's walls by the fence tech (pen_coop_4d.gd fence_walls; a darker
  frame shows on purpose: flush rails flickered), the old walls one switch away; frames coop (tag old/new).
- 28 the tower's oak red (pen_oak_4d.gd red); 29 Wren's balloon blue in DEV; 30 DEV tree crowns as tall as the leaves.
- 32-37 trees in W: oaks round in W (w_stretch 1.8), the planting stands again at 4.5 and 9 ana and kata
  (scripts/pen_trees_4d.gd, 259 more, never saved), one culling loop. Trees cut by the slice within 40 m at
  0/10/20/30 degrees, east spot: as it was 27/9/5/3, now 40/51/44/31. Perf: 1-3.6 ms GPU for the planting.
- 38-47 the playtest: 55 runners and the journey (PenLayout/scripts/_verify_journey_b_runner.gd, 22/22: the route
  walked on the move key, the Watchstone's scene waited out, the cave in and out in both looks). Fixed: the grass
  during a trip in the first second, the balloon ride's marsh leg (41 m off), the camera inside the cave hill on
  the way out, the balloon in the held dev look. Stale tests updated or noted: follow_up/pen_layout_b.md.
- 48-49 the film: smoke_test_output/video/slice_tour.mp4 (73 s, 1080p, 86 MB; runner
  PenLayout/scripts/_film_slice_tour_runner.gd, lab_run.sh movie_hd, then ffmpeg).
- 50 handover follow_up/pen_layout_b.md; memory; committed by path.
- 51 folded into the W tools (section K).
