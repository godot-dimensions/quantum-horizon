# Layout B: the pen remade to Ramon's sketch (40 steps)

6 Oct 2026. Ramon painted the new layout over the high-res top view (session images 27 = the top view,
28 = his layout): "make a 40 step plan because i want this done right. then execute."

**Measured, not eyeballed.** The sketch was registered on the top view it was painted over (rows 285 to
1859 are the map, 16.4 px a metre, x -50 / z -40 at its top-left; mean difference 1 level in 255
where untouched). Every element was found by its paint colour or by template-matching the pieces he
moved, and drawn back over the sketch to check (`scratchpad/sketch_found.png`, `sketch_measure.json`).

| What | Measured (world x, z) | Notes |
|---|---|---|
| The valley ring | centre (-0.2, 5.9), radius about 62 | the walkable sphere is 46 m round the origin now; the hills start at 50 |
| Start | (24.9, 19.1) | "1.start": south 18 m to the main line |
| Main line | z 37.1, x -14.2 to 24.9 | junctions at Trym (24.8), the cave (7.3), the pen's diagonal (-4.0) |
| Trym's house | (25.0, 44.9), turned a quarter | "2": its circle at (24.9, 40.9), larger; sand in front |
| Cave | circle at (7.4, 30.8) | "3": the door is 4 m ana: this stretch slants into W to meet it |
| Pen | centre (-19.2, 37.1), turned a quarter (coop west, gate east) | "4": circle at (-14.2, 37.2); its sand wider than the fence |
| Pen to gate | (-4.0, 37.2), (-11.1, 23.1), gate (-11.4, 12) | two pivots, then the gate |
| Town wall | z 12: x -30.4 to -12.9, gate, -10.4 to -1.7; x 18.2 to the edge | plus two walls at x -42.7 (z -7.9 to 7.8) and x -39.2 (z 22.7 to 30.9) |
| North of the gate | range junction (-12.3, 2.1), camp junction (-12.7, -3.9) | straight on to the tower |
| Range | moved (-5.6, +10.1): origin (-21.4, 2.6), still facing east | circle at (-19.3, 2.2) |
| Camp | sand circle (15.8, -3.8), radius 6.4 | the path ends at (6.4, -4.1), at its edge; no ring of paths |
| Tower | circle (-18.8, -27.8) | unchanged |
| Large oaks | 29 circles, radius about 4 m | light green |
| Medium oaks | 35 circles, radius about 2.4 m | dark green |
| Rock parts | (5.7, -29.2) 9 x 7 m; (15.9, -30.2) 3 x 4; (-36.3, -23.1) 4 x 4 | "half tower size" |
| "marsh?" | (5.9, -17.7) | the Ana marsh moved there, at its own W 8 |

## A. Ground truth and safety (1-6)
1. Back up `playable_world.tscn`, the unit scenes, the path graph and every script this touches to
   `chickenpen/.backup/2026-10-06_before_layout_b/`.
2. This table, and an overlay of the measured layout on the sketch (`refs/analysis/layout_b_measured.png`).
3. The couplings: everything that holds an absolute place (the start, the chickens' spawns, Nike,
   Mithra's roam, the keeper's and professor's posts, the tutor's markers, quests, the crossings'
   returns, the tests that teleport the player) listed and moved with what they belong to.
4. Baseline: the pen's test suite and frames as it stands.
5. The valley: centre (0, 6), the hills' foot at 62 m, the walkable sphere 58 m (it is a sphere in
   x, z and W: the walls below are as deep in W as the sphere reaches).
6. The tree budget: all trees together at most about 2 ms of GPU at the worst view, measured.

## B. The valley (7-10)
7. Bounds: a centre and the new radius (`pen_bounds_4d.gd`), 58 m round (0, 6).
8. The mountains rebaked with their foot at 62 m, moved to the new centre (both bakes, and the main
   green's even one).
9. The ground 160 m square at the new centre; the painted ground and its glow re-centred.
10. A top view of the empty valley at its new size, against the sketch's ring.

## C. The landmarks moved (11-18)
11. The pen to (-19.2, 37.1), turned a quarter; the keeper's post with it; its sand wider.
12. Trym's house to (25.0, 44.9), facing its circle; sand in front of it.
13. The range to (-21.4, 2.6), still facing east.
14. The camp's ring a sandy circle at (15.8, -3.8) (painted, no path chords), the camp itself with it at
    its own W (2.5 kata).
15. The start at (24.9, 19.1), facing down its path; the professor beside it.
16. Nike by the pen; Mithra behind the wall, north of the gate, off the path.
17. The detailed oak up the Lookout rock (staged earlier); the chickens' spawns re-authored over the
    south field, the first near the start.
18. The balloon a desaturated light brown.

## D. Walls (19-24)
19. The town wall rebuilt with the fence tech: straight, twice the old height (about 4.4 m, posts 5.2),
    solid (beam coverage 1), stone grey, as deep in W as the walkable sphere so it cannot be stepped
    round in W.
20. One continuous line at z 12 from the west edge to the east edge: through the cave hill (hidden in
    its rock), the gate the only opening.
21. The gate at x -11.4, 2.5 m wide: taller posts and a lintel.
22. Ramon's two west walls (x -42.7 and x -39.2) as drawn.
23. The old ruin wall retired (kept in the backup).
24. Walk tests: from the start's side, walking at every 4 m along the wall and round both ends, at W
    -6, 0, 4 and 8: through only at the gate.

## E. Paths (25-31)
25. A new graph `PenLayout/paths/pen_b.tres` from the measured points: pivots only where a route turns
    (more than about 10 degrees), junctions where routes meet, nothing else.
26. An action circle in front of each landmark (tower, camp, range, pen, cave, Trym), each a
    destination turning (the sheet's "available" arc), anchored to its landmark; Trym's larger.
27. The camp: the path ends at its edge.
28. The action circles shown in the art look too (the chevrons stay sand), in the sheet's colours.
29. In the dev look a rectangle or circle round every landmark (the network's frames), the pen's own
    frame folded into them.
30. W: every stretch at W 0, but the cave's last, which slants from W 0 to the door's W 4.
31. Path checks: the sheet's rule 10, the layout check (no route through an object), the eggs and
    paths test updated.

## F. Trees, bushes, hills, rocks (32-37)
32. A planting set (`World/Trees`, a list of kind, place, size and turn): oaks built from shared bakes,
    every one a little different (size within about 12 percent, turned about its trunk, never through
    W, which would show the squashed oak's thin side).
33. The 29 large and 35 medium oaks where they were painted; bushes scattered by rule: along the tree
    belts' edges, the wall's foot, beside path bends, never on a path, a circle or a landmark.
34. Cheap enough for many: large oaks on the light bake, medium on a lighter one, bushes leaves on a
    stub; drawn only when the slice cuts them AND they are in front of the camera; measured.
35. Wind: they sway a little more (the oak wind's speed and gusts).
36. Hills: five or six low mounds (1 to 2.5 m) where they help: framing the camp, beside the start,
    between the pen and the west hill, behind the range, by the tower path.
37. The three rock parts from the Watchstone's crag chunks, about half the tower's height.

## G. Flock, marsh, the dev look (38-39)
38. The starlings over the meadow right of the tower; the Ana marsh at the marked spot (its W 8 kept).
39. The dev look: trees as round blockouts, mounds grey like the terrain, rocks and walls in clay, a
    frame round every landmark.

## H. Proof (40)
40. Top views in both looks over the sketch; a walk of the intended route (start, Trym, cave, pen,
    gate, range, camp, tower) in frames; the test suite against the baseline; the numbers; commit by
    path; handover `follow_up/pen_layout_b.md` with what to look at and the open questions.

Also in this round (staged earlier): the range rebuilt in four dimensions, the path type key (9) and
the Paths row, round oak blockouts, the light oaks' thicker trunks.
