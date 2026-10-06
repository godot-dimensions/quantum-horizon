# The pen's dev look: the plan (80 steps)

6 Oct 2026, from the case study (`PenLayout/DEV_LOOK_STUDY.md`) and Ramon's go: "execute on the most
reasonable efficient plan ... make the swap a possibility ... make sure nothing breaks. original
playable world stays".

**The decision: one world, two looks.** A look system inside the pen (`Systems/Look`) switches the
whole world between DEV (white grid floor, light grey mountains, the lab's bright sky, path arrows,
simple blue blockouts, red for what you use) and ART (the pen exactly as it is) in a few
milliseconds. No mirror scene: a scene inherited from the pen would get the pen's changes but not
send its own back, so moving a blockout there would not move the landmark. With one world, a
landmark and its blockout are the same node: move either and both move. ART is the original
untouched: the look system does nothing in ART, and switching it off (`enabled`) gives back
today's pen exactly. Never hide a node (mechanics read visibility): only take meshes off and lay
flat materials on.

## Status (6 Oct, end of the run)

Done, and seen working in frames: steps 1 to 70 and 72 to 79. Handover: `follow_up/dev_look.md`.

What changed from the plan as written:
- **Rules per landmark, not one look for all.** Ramon, during the run: the camp and the pen stay as
  they are in one colour, the marsh keeps its water without the grass, animals and NPCs untouched,
  the cave interior and the cinema left alone. So each landmark has a rule (block, clay, art, or
  keep/drop parts), editable on the Look node.
- **The stone wall is clay, not a blockout:** drawn from its colliders it stood full height where
  the ruin is broken down.
- **The lab's light was too strong** for a white floor (everything clipped to one white): the dev
  light is the pen's strength, neutral, the floor and mountains a little under white (step 10, three
  measured variants).
- **Step 61** proves the save guard by calling it at play time; **step 62** (clicking a blockout in
  the editor) follows from the 4D editor's picking code and is for Ramon to try.
- **Step 64** didn't apply: no unit in the pen is instanced with editable children.
- **Step 71** not measured to the megabyte: the blockouts are a few hundred tetrahedra a landmark,
  next to the pen's 300,000.
- Two pen tests read what's on screen and were taught the dev look (the marsh's align, the scenery
  release); the scenery release itself now goes through the look, so neither undoes the other.

## A. Safety and groundwork (1-10)
1. Back up `playable_world.tscn`, the unit scenes and every script this touches to
   `.backup/2026-10-06_before_dev_look/`.
2. Baseline: run today's passing pen tests, keep their results to compare against.
3. Baseline frames: the study's viewpoints in ART, kept as the "ART unchanged" reference.
4. Baseline numbers: frame and GPU time at three viewpoints.
5. The couplings list, complete: what reads visibility, meshes or materials, what writes the sky
   or lights, what loads the pen, the paths' reveal state. Into the handover.
6. A free key for the switch, checked against every key handler in the pen.
7. The button: a "Look" row at the top of the pen's dev panel (the grass panel, left), shown with
   the grass off too; the controls card names the key.
8. The session rule: the pen opens in DEV the first time; the choice is kept for the session;
   `look=dev|art` on the command line wins; films always play in ART.
9. The blockout table: one or two shapes per landmark, in its own frame, measured from its own
   constants and colliders.
10. The dev palette tuned from probe frames (floor, mountains, sky, key and fill): three variants,
    the most legible kept. The probe's lab light washed white into white.

## B. The look core (11-30)
11. `chickenpen/look/pen_look_4d.gd`: the Look node, DEV/ART, `set_look()`, `look_changed`.
12. The art registry: every mesh under World and the pen enclosure, with an explicit role
    (landmark, used, character, terrain, ground, paths). Printed and checked by eye.
13. The swap: mesh taken off and kept, or a flat material laid on; never `visible`.
14. The ground: `pen_grass_4d.gd` gets a dev floor the ground shows instead of its paint, its
    own-material cache untouched.
15. The mountains and the two round hills: light grey.
16. The sky and light: the dev environment saved and restored as one.
17. The paths: their dev look, with the found-as-you-go state kept (the probe's round trip lost it).
18. Blockouts built from the table as unsaved children of each landmark's root, so the editor
    selects the landmark when one is clicked.
19. Clay (flat blue) for art the table doesn't cover; red for used things.
20. Meshes added later (rebuilds, merges, green rebakes) get the current look as they arrive.
21. The Watchstone's runtime stone merge picks up the look.
22. Freed meshes dropped from the registry (the range and camp rebuild on a green rebake).
23. The warm-up: the art drawn for a few frames under a black curtain before the first DEV, so the
    first switch to ART is instant (the probe: 1.7 s without).
24. Films switch to ART for their length and back.
25. The key and the button; a short "Dev look" / "Art look" note on screen when it switches.
26. Session memory and `look=` from the command line.
27. The kill switch: `enabled` off means the pen as it was.
28. The Look node added to `playable_world.tscn` by text, and the scene checked by loading it.
29. Parse checks, first run, fixes.
30. Frames of both looks from the study's viewpoints.

## C. Blockouts (31-42)
31. The Watchstone: a cylinder; three stacked blocks as a switchable variant.
32. The cave: a wedge with its door, sized to the hill, at its W.
33. Trym's shed: a box with a roof; its yard props in clay.
34. The camp: two tents and the fire, at its W; the ring's stones in clay.
35. The range: yard, backstop, fences; the rune stone red.
36. The rock pile: one box.
37. The stone wall: its arch kept as plain boxes.
38. The oak: trunk and crown.
39. The owl tree, the kata wood and the marsh: posts and plates.
40. The keeper's and professor's posts, the egg cairn: small boxes or clay.
41. The chicken pen enclosure: clay, so the fence keeps its shape.
42. Every landmark checked against its art from its viewpoint (ART and DEV frames side by side),
    sizes fixed.

## D. Mechanics carry over (43-58)
43. The passing tests run in DEV (runners take `look=dev`), compared with the baseline.
44. The same in ART: identical to the baseline.
45. The rune stone and its trip to the Quantum Range, in DEV, and back.
46. The laptops.
47. The Lookout: the walk-up, a photo, the journal.
48. The camp's align to slice (V).
49. The tutor's markers and the slice dial's outlines.
50. The cave: in, the fade, the crossing, back.
51. Catching chickens; Nike.
52. The wolf raid.
53. A main-green rebake while in DEV: blockouts and clay survive it.
54. The murmuration launched from the menu plays in ART.
55. Fifty switches in a row: nothing lost, mesh and tetrahedron counts unchanged.
56. ART after ten switches matches the baseline frames.
57. Numbers: frame and GPU time in both looks, and the first switch after the warm-up.
58. A playthrough film in DEV: start, cave, pen, tower, range, camp.

## E. The editor (59-66)
59. The Look shows in the editor too (@tool), its own editor setting.
60. Saving never stores a look: art put back before the save, the look re-applied after.
61. Proven without the editor: apply DEV, run the pre-save step, pack the scene, compare with the
    file, re-apply.
62. The selection link: a blockout's target is its landmark's root (the 4D editor's picking rule),
    noted for Ramon to try.
63. A unit scene opened on its own (the Watchstone's stones) has no Look: unchanged.
64. Instanced units with editable children: the link still holds or is noted.
65. The Look's editor setting saved in the scene, nothing else.
66. The trap written into engine_gotchas.md.

## F. Optimise (67-72)
67. DEV leaves every system running (gameplay is the point); measure what the hidden art costs.
68. The meadow film: it hides the teal fill and turns the grass on for its shots, then restores
    them; cheap, kept, and now played in ART.
69. Blockouts merged into one mesh per colour (instance count).
70. The registry built once and kept up as nodes come and go.
71. Memory: art and blockouts both resident; the tetrahedra the blockouts add.
72. The probe stays a test tool; nothing at runtime uses it.

## G. Proof and handover (73-80)
73. The frames sheet: ART and DEV at every viewpoint, and the tower's two variants.
74. The numbers table.
75. The tests table: DEV and ART against the baseline.
76. `follow_up/dev_look.md`: how it works, how to give a landmark its blockout, the couplings,
    questions for Ramon.
77. `engine_capabilities.md`: no render layers, the first-draw cost, the editor's pick targets.
78. Memory notes.
79. Commits by explicit path.
80. The report: what to look at first, then the questions.
