# Voxel Lab, round 3 (9 Oct 2026)

Ramon walked the lab and the open world on 9 Oct and wrote it up in three parts (20 items). This is
what was found when each was looked at, the decisions where he left it open, and the steps. Frames
before and after: `smoke_test_output/voxel_lab/audit/` (`scripts/_capture_audit_runner.gd`).

## What was found

- **The clipping is the kit's overhangs.** Floors and ceilings of a kit room run half a metre past
  their walls. The corridor's ceiling overhang ends on the hall's front wall face (the slab you see
  above the entrance); the gallery's ceiling overhang ends on the hall's back wall face (the strip at
  the top of the back wall); the hall's back wall and the gallery's front wall occupy the same half
  metre (z -15 to -15.5), and the hall's two blue corner walls run on through it into the gallery (the
  two blue stripes either side of the gallery's door).
- **The shelf** stands 2.5 m in front of the right wall (x 8.6, wall at 12).
- **The column** works as round 2 left it (a watched fall), but its pedestal still reads "CUT ITS BASE
  UNTIL IT FALLS", and its story is four parts with the cuts kept between watches; to check why it
  showed "a few small holes".
- **The lab's own board** shows on the first spawn.
- **The floor arrows** flow along each edge from its first node to its second: on the left the graph
  runs from the back junction up to the pivot, so those arrows point back at the pivot.
- **The rings' outlines** (the frames round the block, the column, the world) are drawn in the path
  sheet's own colours: there is no way to tint them yet.
- **Creation Lab ambience: there is none** (only a chime on its HUD). Nothing to reuse; none added.
- **The open world's camera** has the rig's defaults (5 m, a wheel that zooms 1.5 to 14 m); the lab
  sets its own (4.6 m, its height and pitch). On the deck you cannot turn the slice anywhere.
- **The Water Lab's harbour** (seascape/seascape.tscn, its tuning file and seascape_4d.gd): a low
  sun (10.5 degrees up, turned 137.5), a gradient sky with volumetric clouds, a strong cool ambient
  (0.565, 0.639, 0.742) at 0.225 sky, exposure 0.99; a grey pier to a round blue platform (a cubinder,
  r 5.2) with a turning ring line; on the platform the slice turns (right drag, R levels it), the
  platform stays level while the sea turns, the wheel is off, and a mouse tutorial card shows the
  drag gestures (shared/mouse_tutorial.gd).

## Decisions

- **A, B, C** go 1.9 m nearer the wall (x 10.5): 2 to 3 m would put them against it.
- **The arrows:** the left loop is turned round, so arrows leave the pivot both ways and meet at the
  back junction, then on to the gallery door. No new path feature needed for that.
- **The ring outlines** get a tint on the path network (a Path Creator feature, carried back to the
  kit), blue for every ring in the lab: only the block's in blue would read as a mistake.
- **"R" in the open world:** as in the Water Lab, the right mouse turns the slice and R levels it.
- **The rotation gizmo:** not built (item 20). The blue circle and the mouse card say it; a gizmo would
  sit over the view.

## Steps

### A. The rooms (items 1, 2, 9)
1. The corridor 0.8 m higher (6.8 m).
2. Kit rooms: no ceiling or floor overhang on an open side; the corridor ends on the hall's wall.
3. The gallery 1 m further back (`gallery_gap`), with a short passage between the two doors: floor,
   walls and ceiling of its own, nothing reaching into either room.
4. The hall's corner walls stop at the back wall.
5. Everything in the gallery moves with it (stations, lights, spots, targets, routes, the far door).
6. No board on the first spawn; the board stays when you come back from the open world.
7. Audit frames after: no slab, no strip, no stripes.

### B. The hall's things (items 2, 3, 5, 6, 7)
8. A, B, C at x 10.5; their spots and lights with them.
9. Short branches to each (right angles) from the shelf's run; the main routes unchanged.
10. A label on the wall above each: a down arrow, a few words, the right wall's blue look.
11. The column in the front-left corner, its ring on the left run, its panel and light with it.
12. The left loop turned round (arrows out of the pivot both ways).
13. Ring outlines blue (`frame_tint` on the path network; Path Creator kit too).

### C. The presentations (items 3, 6, 13)
14. The block's presentation in three parts, each one worth its place.
15. The column: three parts (cut through your slice, cut through W and it falls, where it went),
    always from a whole column; its pedestal band without "CUT"; the band lower.
16. Why the column showed "a few small holes": find and fix.
17. A, B, C rethought: what each shows, a diagram each in the gallery's style, short text.

### D. The HUD (items 3, 4, 8)
18. The choice as wide as the strip under it (both take the wider).
19. "Volume view" is "Projection view" (lab and open world).
20. Black and grey off the strip: a switch top right, "Dark mode on / off".
21. Tab: the lights (the dev panel's LIGHTS page, each light's strength and softness).

### E. The gallery's world (items 10, 11, 12, 14)
22. Its pedestal larger; it faces you with its slope; R resets its slice and turn.
23. Each land its own shape: green rolling hills, desert dunes, lava spikes (the open world too).
24. Cropped to its square while it turns: a material that keeps only what is over the square and
    paints the cut sides; the terrain built larger than the square so it still fills it. Measure.
25. The far door's outline on the opening.

### F. The open world (items 15 to 20)
26. The Water Lab's light and sky (its tuning file's values), clouds if they cost little.
27. Darker green; some variation across the land; what can be done about the blocky look.
28. The deck redone as the Water Lab's: a grey standing area (the helm, the door home) and a round
    blue platform with a big ring; inside the ring the slice turns (right drag, R levels it), the
    platform stays level, and the mouse card shows how.
29. The lab's camera on the deck; the wheel zooms as in the lab.
30. 2 at the helm: find why it seemed to do nothing; keys matched on the physical key as well.
31. The bird: steadier steering, the slice drag quicker and immediate; the circle 5 m wider.
32. The sea's settings kept, saved, read back.

### G. Checks
33. Runners: room, gallery, column, play, turn, field, shortcut, audit; frames looked at.
34. Handover, carried README, Path Creator README; commit by path.
