# Voxel Lab, round 2 (9 Oct 2026)

Ramon walked the lab on 8 Oct and talked it through. This is what he settled on (his end conclusions,
where he changed his mind along the way), the decisions taken where he left it open, and 80 steps.

## 1. What he asked for

**Light.** Start from nothing: he switched every spot off. No light in the corridor. One soft spot on
each item, nothing else. All spots in a room share one set of sliders, except specimens A, B and C,
which each get their own strength. Better still: an in-game top view of the room showing where the
lights are, sliders per light, and a save button.

**The hall's route.** Straight lines, right angles, the odd 45 degrees, aligned with the room:
- in from the corridor, straight on to a quiet pivot level with specimen A (the shelf moves 1 m
  toward the entrance);
- from that pivot, straight on to the big block: the interactive ring right in front of it;
- from the pivot, a T to specimen A's small marker, then a right angle along the shelf past B and C
  (small balls), on to the right corner wall (45 degrees at the end) and a big ring in front of it;
- from there left along the back of the hall to the left corner wall ("Voxel Lab") and its big ring,
  with a quiet junction in the middle that branches (T) to the gallery door;
- from the Voxel Lab wall back up the left side to the pivot, past the column.

**The block.** No story playing as you walk up, no bench pad, no "THE BENCH, CUT IT YOURSELF" print.
Standing at its ring you get a clear choice, in the style of the control strip but bigger: an eye
icon, "Watch the presentation", and a mining icon, "Cut it yourself". Cutting is the bench as it is
(he loves it). The camera at the bench froze once while he cut.

**The shelf (A, B, C).** Nothing plays. A small marker at each; click for a small pop-up that says
what it shows.

**The walls.** The right corner wall ("The block") must be the kit's teaching blue with bright text,
and its main display must move: a diagram, a rotating block. The left corner wall ("Voxel Lab") blue
too.

**Panels.** No console you press E at, far from its exhibit. A floating panel next to the block, in
the style of the Quantum Range's floating console but narrower, that wobbles when you walk into it.
A small one for the column, or just floating number markers.

**The column (02).** Not cuttable (the block already is), no tree. If it stays, it plays as an
animation that really falls; or something new that makes more sense.

**The gallery.** Routes on the same logic. The terrain: pedestal twice the size and lower, the
landscape sunk into it so it reads as Andrew's generator; no brown poking through the green; a toggle
between green, a Nevada desert and a lava field; cutting stays, offered the same way as at the block.
The 24-cell does not belong there. The resolution ladder, if kept, on three small square pedestals
like the shelf. The "What still fails" wall goes: say what works. The grey test-cases sign on the
wall is cropped and misaligned.

**The field.** Finish it, as its own scene you walk into through a blue shimmer in the far door, with
a sci-fi door there that takes you back. Minimal.

## 2. Decisions (most reversible option, noted in the handover)

1. **Choice keys 1 and 2**, drawn as buttons (clickable when the cursor is free, Esc) in a pill above
   the control strip; they appear only at an interactive ring. F or Esc leaves the bench as before.
2. **Lights:** every spot is the kit's `spot` kind, soft, aimed at its item. A light file
   (`voxel_lab_lights.cfg`) holds the room values and any per-light changes; the dev panel's new
   LIGHTS page is a top view of both rooms where you click a light (or drag it) and set it.
3. **The floating panel** is new (the range console never wobbled): the range console's build (a
   tilted slab, rounded light plate, black glass face, glow strips), 1.3 m wide, on a spring: it bobs,
   and when you walk into it it swings away and settles.
4. **The column stays, as a watched animation:** on "Watch it fall" it is cut through your slice
   (it stands), then kata (it falls), every time, and is whole again after. No bench, no tree.
5. **The gallery:** the terrain becomes Andrew's whole scene on one big pedestal (landscape, sea and
   caves); the separate caves pedestal and the 24-cell go; the ladder becomes three small pedestals
   (20, 10 and 5 cm) with pop-ups, as the shelf.
6. **The field** is a floating survey deck you walk onto, with the door back on it; "Fly over it" from
   the same choice pill switches to the flying survey camera, H lands you back on the deck.

## 3. The steps

### A. Read and measure (1-6)
1. Re-read the room, bench, shelf, column, case and field code against the feedback; list every
   piece that changes.
2. Measure the hall and gallery from the plan (walls, corners, doors) for the routes and lights.
3. Find the bench camera freeze: which camera can be current while you sit.
4. Read the wall panels' timing bug and the research page's chart path.
5. Read the range console's build and face for the floating panel.
6. This plan.

### B. Lights from nothing (7-18)
7. Remove every light from the scene generator; none in the corridor.
8. A spot per item: block, A, B, C, column, terrain, the three ladder pedestals, the field door.
9. One light data file, read at start: room values (strength, cone, softness, height) for the hall
   and the gallery, and a strength for each of A, B and C.
10. Per-light changes on top of the room values (strength, cone, softness, height, position).
11. The dev panel gets pages: SETTINGS (as now) and LIGHTS.
12. LIGHTS: a top view of the hall, corridor and gallery, the items drawn as shapes.
13. Each light a dot with its pool drawn to scale; click to select, drag to move.
14. Sliders: the room's, A/B/C's, and the selected light's own.
15. Live: every slider moves the light at once.
16. SAVE writes the file; the room reads it on start.
17. RESET for the selected light (back to its room's values).
18. Runner: lights load, a change saves and reloads.

### C. The hall's layout and routes (19-28)
19. The shelf 1 m toward the entrance.
20. The block's console, bench pad and print removed; the column's bench and console removed.
21. Route graphs written by the generator (Python, straight into paths/*.tres), no Godot needed.
22. The hall graph: corridor, pivot level with A, the block's ring, the shelf markers, the right wall's
    ring, the back junction to the gallery, the left wall's ring, the left side back to the pivot via
    the column.
23. Targets for every ring (block, right wall, left wall, column, gallery door).
24. Ring states follow the visit (what you have done, what is next).
25. No story starts by walking up to anything.
26. Look at the routes from above (a capture from high up).
27. Walk them with a runner, key presses, ring to ring.
28. Rethink: angles, spacing, nothing crossing a pedestal.

### D. The choice and the bench (29-38)
29. The choice pill: icons (eye, pick, a fall arrow, a globe, a flight arrow), labels, keys 1 and 2.
30. Shown only while you stand at an interactive ring; hidden when you sit or watch.
31. Watch: the presentation with the story camera; it ends by itself, or Esc, or walking away.
32. Cut: sits you at the bench (the bench as it is).
33. The camera freeze: the bench's camera stays the one in use while you sit, whatever else happens.
34. Middle drag orbits the bench camera too (WASD still does), as in Blender.
35. The strip at the bench says so.
36. The shelf: at a marker, click for a small pop-up (black glass, beside the specimen, never over it).
37. Pop-up words for A, B and C (what each shows).
38. Runner: ring, choice, watch, cut, stand, pop-up.

### E. Floating panels (39-44)
39. The panel: the range console's build, 1.3 m wide, black glass face, glow strips under it.
40. Its face: number, title, a line, three live numbers (the block: voxels, last cut, worst frame).
41. The spring: an idle bob; walking into it pushes it away; it swings back and settles.
42. One beside the block, a smaller one beside the column.
43. They never stand between you and the exhibit from its ring.
44. Frames.

### F. The corner walls (45-50)
45. The wall-claim timing fixed: both corner walls blue, text bright.
46. The research page's chart: a rotating tesseract (the block's 4D frame), drawn every frame at 30.
47. After a cut, the cut's numbers; the tesseract stays.
48. The intro wall's words checked against the new visit (choice keys, no bench pad).
49. Frames of both walls, both looks.
50. Cost: the walls' redraw time.

### G. The column (51-55)
51. No bench, no tree, no cutting by you.
52. Watch it fall: cut through your slice (stands), cut kata (falls), lies, whole again; every time.
53. The column's shots for the story camera.
54. Runner: watch it twice, it falls both times.
55. Frames.

### H. The gallery (56-66)
56. The terrain on one big low pedestal (twice the size), Andrew's scene: landscape, sea and caves.
57. Sunk into the pedestal, lower overall, so it reads from where you stand.
58. Brown poking through the green: the grass layer thick enough at this voxel size.
59. Biomes: green, a Nevada desert, a lava field (palette and sea), switched from the choice pill.
60. Cut it from its ring (the same choice as the block).
61. The caves pedestal and the 24-cell removed.
62. The ladder on three small square pedestals (20, 10, 5 cm) with markers and pop-ups.
63. "What still fails" replaced by a wall that says what works, measured.
64. The cropped grey sign removed; the test-cases wall's words updated.
65. The gallery's routes, the same logic as the hall.
66. Runner and frames.

### I. The field (67-74)
67. A blue shimmer in the gallery's far door; walking through it fades to the field.
68. The field scene: a floating survey deck you stand on, the landscape generated round it.
69. A sci-fi door on the deck with the same shimmer; through it, back to the gallery's far door.
70. "Fly over it" from the choice pill: the survey camera, H back to the deck.
71. The biome toggle there too.
72. The deck's light and the sky checked in both looks.
73. Runner: in through the shimmer, fly, land, back through the door.
74. Frames.

### J. Proof and handover (75-80)
75. Every runner, both looks; the walk from the corridor to the field and back.
76. Costs: frame time per station, the lights' cost.
77. Look at everything, fix what reads wrong.
78. Handover: what changed, what to look at, questions.
79. Engine map and memory notes.
80. Commit by path. Not pushed.

## 4. Status

**Built and run (9 Oct).** Every part, A to J, built and played by its runner, frames looked at:
the routes (from above too), the choice at the block, the column and the terrain, the shelf's and the
layers' pop-ups, the bench (its camera kept, middle-drag orbit), the floating panels on their springs,
both corner walls blue with the tesseract turning, the light rig and its LIGHTS page (top view, drag,
per-light sliders, SAVE), the column watched twice (it falls both times), the gallery, and the open
world through the hologram door and back.

**Changed on the way, from Ramon's notes while it was being built (9 Oct):**
- The gallery rethought ("rethink what you show and how"): not a resolution ladder and a "what works"
  wall, but how his world is made: his land, his caves, the two clipped, on three small pedestals, then
  his whole scene with its sea on a big square pedestal ("better served on a square pedestal"); the
  walls say the same ("How a world is made", "Andrew's world").
- The door: the pedestals' hologram (the grid shader's dithered shift), not a glowing sheet.
- "The field" is now THE OPEN WORLD, "his landscape, without edges, generated as you go".
- Found and fixed: the corner walls lost their blue to a start-up order (the panels claimed their
  wall before the hall had walls); the column's second watch did not fall after a fall at its bench
  (no bench now, and every watch starts whole); the story camera's shots had your figure in them
  (hidden while it films).
