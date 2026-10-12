# Layout A: Over the hill (80 steps)

Ramon, 6 Oct 2026: "go with option A ... devise an 80 step plan". With C's door in W for the cave.
His asks, in his words, each answered by a phase below:
- "deactivate the grass by default for now, so we can design clearly" (Phase 0)
- "infuse tutorial type stuff ... make interesting use of the W" (Phases 2 and 3)
- "it's so flat": W placement, and the hero models not built for 4D; "use the fence tech" for the
  watchtower (base and the hut above), the range and Trym's hut (Phase 7)
- the paths placed, plus "a secondary path that touches on the meadow with a circle placement
  there" (Phase 4)
- reveal or static paths, "a toggle for both ... in the hud"; paths that reach landmarks in other
  slices, and "look like it works in volume view" (Phases 5 and 6)
- "subpaths lead to at least 2 small easter eggs, like maybe a bag of azoth" (Phase 3)
- "toggle path icon mode, and sand mode on and off" (Phase 5)

## What the research found (6 Oct)

- **Paths (PathCreator):** a network is a node with a graph (`.tres`) and a `targets` node. Its
  destinations can be anchored to objects and follow them through x, z and W. Routes drape onto the
  ground, and W steps show as dots (warm for ana, cool for kata). Missing for the pen: there is no
  reveal of any kind; the "sand" look is just the chevrons drawn in sand colour, with no surface
  under them; marks and the guide line cannot be switched separately; nothing was done for volume
  view (the projected half is probably drawn in the engine's default white); no circle tool; the
  builder only works in its own dev space.
- **Fence tech (FenceGenerator4D):** box-shaped walls of posts, ribs and beams, with real W depth.
  The ends in W come for free, posts lean in with `top_footprint_ratio`, and `beam_coverage` 1 makes
  solid walls. No roofs, floors, doorways, diagonals or colliders.
- **Why it all looks flat:** the tower's legs, ladder and cab run the full 6.4 m of W, so turned
  into W they read as plates. The shed and the booth are the same: full-depth slabs, thin end walls.
- **The pen:** grass is `World/Grass.enabled`, toggled with Alt+O. Free keys: F1, F2, F5 to F12, and
  I. The controls card takes new rows. The slice dial already shows landmarks in other slices. The
  tutor shows each hint once. Azoth comes from the cave's seam, Mithra and the dream, and buys
  troughs. A pickup kind can be added to `pen_pickup_4d.gd`. With the Cave unit at W +4, the arch
  is closed from the farm's slice and the way in is at W 1.5 to 6.5.

## Decisions made here (Ramon can overrule any)

- Toggles: **F5** paths reveal/static, **F6** path icons on/off, **F7** sand on/off (F6 is the
  looks key in PathCreator too). On the controls card, remembered in `user://pen_settings.cfg`.
- **Reveal** means a stretch of path appears, with a short fade, once you have been within 14 m of
  it, and stays found for the session. Landmarks you have not reached show only as a marker where
  their path begins. **Static** shows everything at all times.
- **Sand** is a new soft-edged strip under the marks, draped on the ground, with the same W band as
  the route. **Icons** are the existing chevrons. All four combinations work, including neither.
- The new hero structures are built **beside** the old ones (a design switch on each), shown in
  frames, and only go live when Ramon says so. The old builds stay one switch away.
- New player-facing lines (the professor, the tutor, the bags) are drafted in the plan's voice
  with no dash clauses, and listed for Ramon to read.

## Progress (6 Oct, night)

Done and checked by frames and the pen's tests:
- Phase 0: grass off by default (its panel folds to its one switch), backup and tag, the capture
  runner (`scripts/_capture_pen_runner.gd`, sets before, a, paths, tower, hut).
- Phase 1: the layout in the pen. The cave is at W +4 (closed from the farm's slice, open 4 m ana),
  the professor stands in front of it, Trym's cabin is by the start, and you wake facing the hill.
  The wolf picks a side with clear ground. All the pen's tests pass except the ones that already
  failed (Trym getting up, the dreamer's prompt); the ride's burner check failed once, then
  passed (the window had lost focus).
- Phase 2: **a dry stone wall instead of the fallen trunk.** A trunk can be walked round, which
  teaches nothing. The wall runs across the whole west passage, from the hill to the field's edge,
  and is thin in W: the west way is the 4D short cut, the east way the long walk by the meadow.
  Place hints (`tutor_spot` markers): the wall, the closed arch ("{dir} of your slice"), and R
  after 8 s off the farm's slice. The opening line sends you to the keeper, then becomes the
  chickens'. The professor's line now says the hole is four metres ana.
- Phase 3: the bag of azoth (pickup kind 2, worth 2), standing stones 2.5 m kata in the meadow,
  and a cairn 7 m ana at the hill's east foot.
- Phase 4: `paths/pen_a.tres` (39 nodes, 40 edges), written by `scripts/_make_pen_paths_runner.gd`;
  an Arrival marker in each unit; destinations anchored to them.
- Phase 5: sand (a new shader mode: strips and node patches), marks and sand switched separately,
  reveal (found stretches fade in, 3 m teasers from found nodes), F5 F6 F7 on the controls card,
  remembered between runs.
- Phase 6: the projected half of volume view draws the path boxes in sand, not white.
- Phase 7, first pass: a fence frame switch on the tower (`fence_frame`), the shed (`fence_frame`)
  and the booth (`fence_posts`), all off by default.

Later the same night (Ramon's notes while it ran):
- Two looks, never mixed: sand alone on the field (the first run's look), blue icons only on a
  white dev floor. Checked on PathCreator's lab floor: icons alone are as clean as the path lab.
- The "edges": the sand's soft edges darkened toward the floor's colour where strips and patches
  overlap (the cross-section is opaque). The sand's edge is now dithered, and the patches at joints
  are a quarter wider than the strips; no seams left.
- Route turns are curves now (the sheet's chords between small balls). The meadow ring sat on the
  hill's foot (the route check caught it): it and the kata stones moved to (20, -2).
- The meadow film turns the grass on for itself, hides the paths, and centres on (28, -8), clear of
  the hill. Its close-up shot may want its height tuned there.
- Cost: the paths add about 1.1 ms a frame (each stretch its own box and material; merging the
  sand per route would cut it). The fence frames multiply the buildings' tetrahedra (tower 6,480
  to 34,664, shed 1,120 to 6,304, booth 7,240 to 12,104) with no measurable change in frame time.
- Still open from the plan: the bags on the dial and a checklist line (31), a tilted-slice check (63).

After the plan (6 Oct, Ramon: Trym, the dreamer, the cave, then the tower):
- Trym getting up and the dreamer's prompt pass again. Both tests were stale, not the pen: Trym
  rises on F by design since 50e8db7, and the rig's `_slice_xw`/`_slice_zw` went in b27ffa1 (the
  slice tilt is the rig's basis now). One real bug on the way: Trym aimed his turn from the unit's
  node, not from himself, so he faced past you.
- The cave hill: the shoulder over the arch slopes into the dome instead of running out of the
  hill's back as a flat table; dome and rock face join smoothly; the bake reaches the shoulder's
  foot. Rebaked. The cave's fade to black ended at nothing along the tunnel: behind the hill, from
  its back to the field's edge and across the pen's gate, the screen went black. Bounded now, and
  checked.
- The tower: the fence frame is live (`units/lookout/lookout.tscn`), its base splayed in W so the
  deck never floats, the rail's posts either side of the ladder, the hut's slats wider, the ladder
  2.4 deep in W. 23,192 tetrahedra (34,664 on the first build).

Learned on the way:
- **The fence generator's ribs are full-height plates along its grid lines.** Where the slice falls
  on a grid layer in W they read as solid walls (the tower's base was a solid pyramid from the
  farm's slice at spacing 3.2); between layers you see an open lattice. So the spacing is chosen
  to keep every layer off W 0: 2.2 for the tower, 1.2 for the shed, 1.1 for the booth.

## Phase 0: ready (1-5)

1. Grass off by default: `enabled = false` on `World/Grass` in the pen; Alt+O still turns it on.
   While it is off, its per-frame work and flying leaves stop too.
2. Back up the pen to `chickenpen/.backup/2026-10-06_before_layout_a/` and tag
   `before-layout-a-2026-10-06` locally.
3. A top-view and walk capture runner for the pen (`PenLayout/scripts/_capture_pen_runner.gd`): top
   view, eye-level shots from named spots, any renderer, any slice W. It is the eye for every phase.
4. Capture the pen before the change (top view, the start, the reveal spot, Combined).
5. Godot runs queue on the lock (three windows share it). Each batch is parse-checked first.

## Phase 1: the layout in the pen (6-15)

6. The Cave unit to (8, 0, 15) at W +4: its mouth faces the start, and from the farm's slice it is
   closed.
7. The professor to the mouth on the farm's slice: (3.6, 0, 31.8, W 0), facing the start.
8. Trym's cabin to (-9, 0, 37), turned 90, so his walk and theatre door come out beside the start.
9. The start: the Player at (4, 1.2, 38), the camera facing north at the hill; Ctrl+R comes back here.
10. Nike's run and posts 6 and 7 moved out of the hill. The chickens' teaching order checked
    against the new arrival side (the first bird should be the first one you meet at the pen).
11. The wolf's run-in skips directions a unit blocks (today the cave, the range and now the hill).
12. The meadow film checked with the hill beside it; re-aimed if the hill gets into the frame.
13. The layout check, then all the pen's tests, on the real pen.
14. Frames: waking at the start, the arch, the reveal at the hill's shoulder, the pen with the
    tower behind.
15. Commit.

## Phase 2: the opening teaches W (16-27)

16. The order you meet things in: wake → the arch with no door, and the professor → the path →
    something in the way → step through W → the pen comes into view → the keeper.
17. The professor's first lines when he meets you at the closed hill: the door is there, just not
    on this side; see the keeper first, come back when you can step through W. Drafted for Ramon.
18. Once you have stepped through W, his lines change: the way in is ana.
19. **The first W step, on the path:** a fallen trunk across the west route at the hill's shoulder,
    thin in W (a metre). At W 0 it blocks the path (box colliders); step 1.5 ana and walk past it.
20. Its tutor hint, shown once when you reach it: what is in the way, and E/Q to step through W.
21. The path at the trunk steps ana and back, with its W dots, so the route itself says how.
22. Once you are past, the tutor hint about R (back to the farm's slice).
23. The keeper's intro unchanged; the chickens then use what you just learned.
24. The objective line at the start points you along the path (to the keeper), then becomes the
    chickens' line once he has talked to you.
25. The dial shows the hill's door as a landmark at its W, so "it is ana" can be seen.
26. Back at the hill with W learned: step ana in front of the mouth and the arch opens.
27. Frames of each beat; a runner that walks the opening and checks each hint fires once and in
    order.

## Phase 3: W places and easter eggs (28-33)

28. A new pickup kind, **a bag of azoth** (`Kind.AZOTH_BAG`): a small sack, worth 2 azoth (two
    troughs), with its own line when found.
29. **Egg 1, kata in the meadow:** a ring of stones in the meadow's middle that is only whole kata,
    and the bag at W -2.5 inside it. The meadow circle path leads to it.
30. **Egg 2, deep ana behind the hill:** a ledge on the hill's east side at W +6, past the door's W,
    with the second bag. A faint subpath climbs to it through W.
31. Both bags appear on the dial only once you are near; finding both is a line in the checklist.
32. A runner that walks to each bag, checks it is reachable (not inside rock, inside the field
    sphere) and that the azoth arrives.
33. Frames of both spots at W 0 (nothing there) and at their W (there they are).

## Phase 4: the paths (34-50)

34. An Arrival marker in each unit's scene (where you come in and from which way): the cave mouth,
    Trym's door, the range counter, the tower's ladder foot, the rock pile, the professor.
35. The network looks targets up by name anywhere under World (today it only looks at one node's
    children), so markers inside units are found.
36. `PenLayout/paths/pen_a.tres` written by a runner (`_make_pen_paths_runner.gd`), so it can be
    rebuilt and diffed.
37. **The main route:** start → round the hill's west shoulder → the trunk (the W step) → the keeper
    at the pen's gate.
38. **The east route:** start → the sunny side → the meadow → the pen.
39. **The meadow circle:** a closed ring round the meadow's middle (about 6 m across), joined to the
    east route at a junction. Its length is a whole number of mark spacings, so the marks don't
    jump where it closes.
40. Spurs from the pen to the range, the tower's ladder, the rock pile and Mithra.
41. The way back south to Trym's door and the hill, so the field is a loop, not a dead end.
42. **The cave's door at W +4:** the spur to the mouth climbs from W 0 to W 4 over its last metres,
    so it leads into the W where the door is. The W dots sit where the climb starts.
43. The two egg subpaths: thinner, sand only, no destination frame. The meadow one steps kata from
    the circle; the hill one climbs ana.
44. Every destination anchored to its Arrival marker, so moving a unit carries its path.
45. Routes draped on the ground; none cross the pen's fence, the hill or a building
    (`hide_blocked`), and none run through the wolf's run-in or the chickens' homes.
46. `under_color` set to the ground's colour (otherwise the guide line reads as a white stripe).
47. Mark size (`p_scale`) chosen from readability frames at the pen's camera distance.
48. The paths' bands set so a route reads from the farm's slice but is gone a few metres off it.
49. The network's own checks (`validate`, `acceptance`) clean; the layout check also checks paths.
50. Frames of every route from the player's camera; commit.

## Phase 5: sand, icons, reveal and the HUD (51-60)

51. **The sand strip:** a soft-edged band about 1.2 m wide, draped like the marks, its edges broken
    with noise, with the route's W band.
52. Marks and sand switched separately (two new exports on the network), so all four combinations
    work.
53. **Reveal:** each stretch is found once you have been within 14 m of it, fades in, and stays
    found for the session. Places you haven't reached show a marker at their path's start.
54. **Static:** everything shown, all the time (as today).
55. F5 reveal/static, F6 icons, F7 sand: three new rows on the controls card showing their state.
56. Remembered in `user://pen_settings.cfg` with the UI size; first run: static, icons on, sand on.
57. A full restart (Ctrl+R) forgets what reveal has found.
58. The keys checked against everything else in the pen (F5 to F7 are free today).
59. A runner that presses each toggle and checks what is drawn (marks, sand, revealed stretches).
60. Frames of the four looks, and of reveal before and after walking a route; commit.

## Phase 6: other slices and volume view (61-64)

61. In volume view (Combined) the projected half gets the paths' own colours, not the engine's
    default white.
62. The W climbs (the cave door, the eggs, the trunk step) checked in Combined and Projected: the
    path should be seen bending into W toward the place.
63. A tilted slice (right mouse) checked: routes stay readable, and the climbs show whole when
    tilted to match them.
64. Frames in Cross-section, Combined and Projected from the same spots.

## Phase 7: hero structures in 4D (65-74)

65. A study scene, `PenLayout/Structures/`: fence settings for buildings, measured. Where the solid
    layers land in W, which posts show from the farm's slice, cost in tetrahedra.
66. **The tower's base:** a fence box as wide as the legs' spread and as deep in W as the cab. The
    posts are the legs, leaning in with `top_footprint_ratio` (cab over spread). Four or five
    rings, no diagonals. A 4D tower stands on eight legs, two of them on the farm's slice.
67. **The hut above:** a second fence box at deck height, walls with a window band between sill and
    lintel. The roof, deck, ladder and colliders stay as they are.
68. A design switch on the tower (classic / fence). Everything the Lookout calls (`on_deck`, ladder
    spots, the dial outline, the camera spots) keeps working on both; the Lookout's tests run on
    both.
69. **Trym's hut:** a 4D timber frame from the fence tech round the existing walls. The walls keep
    their cutaway for his scene. The frame is thin, so it never blocks that view. Crows, the cat's
    den and the door are unchanged.
70. **The range booth:** its posts and waist walls from the fence tech, the field side and the
    counter left open. The counter, roof, lane, boards and colliders stay as they are.
71. Each: frames at W 0, ±1.5, its W ends, tilted, in Combined and in Projected, old beside new.
72. Each: tetrahedra and frame time, old against new.
73. A short verdict: where the fence tech makes a building read as 4D and where it doesn't.
74. Shown to Ramon; each goes live only when he says so (a one-line switch in its unit scene).

## Phase 8: proof and handover (75-80)

75. All the pen's tests, the layout check and the network's checks.
76. A playthrough capture: wake → arch → trunk → pen → chickens → back to the hill → in.
77. Frame times on the pen with paths, sand and the new structures, against today.
78. Handover note `follow_up/pen_layout_a.md`: what moved, the toggles, how to edit paths, the
    switches, what waits on Ramon.
79. The lines for Ramon to read, in one list.
80. Commits by explicit path, memory updated.
