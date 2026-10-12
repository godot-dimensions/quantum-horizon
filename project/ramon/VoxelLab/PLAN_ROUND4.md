# Voxel Lab, round 4 (9 Oct 2026)

Ramon's walkthrough parts 4 and 5 (items 21 to 38), and "make sure we're using Andrew's walker and W
rotation settings from the playable world". Round 3's plan (PLAN_ROUND3.md) stands except where this
supersedes it.

## Decisions

- **The gallery's world goes back to round 2's** (item 23's fallback): the square crop is removed. Its
  cut was faked in the shader (inside faces shaded as the wall), which leaves gaps wherever the cut meets
  caves or the edge of what is built, and the tilt limit it needed is the hard stop he felt. Kept from
  round 3, none of which depends on the crop: the larger square pedestal, each land's own ground, R to
  reset the slice, the stand turned so its slope faces the ring (checked from the ring).
- **The walker and the W turning are the playable world's.** The walker and camera rig scripts already
  match the pen's line for line (Andrew's 7 Oct walker). The settings follow it in the open world:
  stepping through W (Q / E, the pen's 0.3), the right drag turning the slice (on the blue platform),
  R levelling it, the pen's camera framing (its preset 2: 8 m back, pivot 1.5 m, 15 degrees down, W
  fade 6 m) with the wheel zooming freely (item 38). The lab's hall keeps its own rule (the room never
  turns). No jump on the deck (the rails are 1.05 m).
- **The column's demonstration is replaced** (item 21) by a showcase of something the block does not
  show: chosen after reading what the engine's voxels can do (see the column section below).
- **Water** (item 31): the Water Lab's current sea is used directly, not copied again, so its presets
  are the ones Ramon compares; Tab picks them.

## Steps

### 1. The gallery's world (items 23, 24)
1. Remove the crop (material, shader, tilt limit); the recipe and sink as round 2.
2. Check from the ring which way its slope faces; turn the stand if it faces away.
3. The pedestal's band gone (the terrain's only); the layer pedestals' band without the slanted stripes.
4. The mouse card at its ring (the Water Lab's, carried): the right drag turns it through W, the wheel
   slides it; shown on arrival at the ring for ten seconds.

### 2. The open world's slice turning (items 29, 30, walker)
5. The whole blue platform turns the slice; no smaller hotspot, no automatic levelling near the edge.
6. No hard stop: the limit removed (past about 30 degrees less land is in the slice: it is built 16 m
   either side of W 0; that is what turning shows, not a fault).
7. The pen's walker settings and camera (above); W kept on the deck.

### 3. The open world's approach (items 26, 27, 28, 33)
8. The grey pier extended 4 m, 4 m wide, railed, onto the platform.
9. Two matching stations either side of the walkway: left Take off, right Change the world; the same
   floating panel, ring and path.
10. Routes (the Path Creator): the main path from the door, a branch in the middle to the two stations,
    on to the platform.
11. The platform after the Water Lab's (its page printed into the deck, its ring, its rail).

### 4. Details (items 22, 25, 31, 32)
12. The column's marker a proper blue; its panel to its left.
13. A sign over the gallery door, the open world door's look.
14. No dot before SPECIMEN on any band; the QH-LAB serial clear of its bracket.
15. The far door: a walkway beyond it, so you never drop before the open world opens.
16. The deck's white lip clear of the grey body.
17. The Water Lab's sea and its presets, picked on Tab.
18. The mouse card bottom left, shown on entering, gone after ten seconds.

### 5. The islands (items 34 to 38)
19. The islands larger without more voxels: each voxel 1.6 m (the same counts, the land scaled).
20. Lower hills; a rounded coastline (land only inside a round region, sea outside).
21. The green darker and less saturated; Tab: the land's colour (hue, saturation, brightness), saved.
22. Grass: a few small patches, the pen's grass carried, blades wider; on and off on Tab.
23. A few distant birds, lightweight.

### 6. The column (item 21): now BUILD IT
24. Its new demonstration; its panel; runner. Chosen with Ramon (9 Oct: "grow would be good, make it only
    about [building] because we lack a 'build system' completely ... like putting blocks in place to build
    something and then rotate the slice"; "if the building part needs better a square pedestal go for it"):
    `stations/vl_build_exhibit_4d.gd`. A square plate on a square box pedestal (half side 1.35 m), no
    turntable; 4D bricks of 28 cm (4 voxels of 7 cm) snapped to a 5 x 4 x 5 x 5 grid, W included; the wheel
    steps one W layer (each slice stop a layer's middle, the showcase's wheel kept to those five); tools
    Brick, Through W (one in every layer), Take away; Q/E four colours, each in two shades laid as a checker
    so fused bricks still count; Z undo, Space levels the slice, R starts again from the sand doorway (in
    the middle layer only, so a turned slice thins it to a brick). The bench hands a builder the aiming
    (its own grid march, not the cut list), the outline (the cube a brick would fill) and the edit. The
    column exhibit and its two runners are deleted; the Grow it draft (crystals) never shipped.

### 7. Checks
25. Runners: terrain, room (Build it in place of the column), turn, gallery, field; frames looked at; handover; commit by path.
