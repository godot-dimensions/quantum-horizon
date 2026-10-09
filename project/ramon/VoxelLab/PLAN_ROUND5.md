# Voxel Lab, round 5 (9 Oct): Ramon's walkthrough part 6, items 39 to 49

His order: the builder first, then the sea's square edge, then the water controls, foam and grass, then the
presentation refinements. Plus, mid-round, the lab-naming pass across the four labs.

## 1. The builder (39 to 41)

1. **Bigger, in the corner** (#39). A 4.6 m square box pedestal 0.35 m off both walls of the hall's front-left
   corner (`COLUMN` (-8.7, 8.7), a metre off both walls after "its crammed a bit too much in the corner"; half side 2.3, 0.5 m high); bricks 0.5 m (VOXEL 0.125 x CELL 4) on a
   7 x 5 x 7 grid with 5 W layers, 3.5 m across. NX and NZ odd, so a slice turned square stands in a row's
   middle. Its ring (-4.1, 8.8) on the line from the pivot, the route on to the Voxel Lab wall's ring by a
   bend clear of its panel; the panel beside the ring (-3.0, 6.9). Bench camera 6.6 m, -26 degrees.
2. **The camera** (#40). At a builder a LEFT drag orbits and a click with no drag (under 5 px) places. Both
   directions now turn as if you held the build (the middle drag's up and down had been the other way
   round from its left and right). Pitch from -85 to +8 degrees. The camera comes closer rather than go
   through the corner's walls (`camera_bounds`) or the floor. The middle drag still orbits, the same way.
   Right drag still turns the slice; wheel, Q/E, 1 to 3, Z, Space and R as before. The block's own bench is
   left as it was (the request was the builder's).
3. **A grid, not a block** (#41). No stone plate: the recipe is "empty" and its box is the grid, so the
   grid's floor is the deck, made black (a slab over the blue deck: "i wanted black with sutble grey lines"). Thin subtle grey lines (`LINE_COLOR`, 2.2 cm) along every cell edge in x and z, as
   deep through W as the grid, on the stand so a turned slice cuts them like the bricks. Aiming meets the
   grid's floor plane inside the grid. The sand doorway stays (now across the middle row, spanning z, so it
   faces the bench).

## 2. The sea's square (46)

4. The square was the Water Lab's 120 m grid of 0.63 m squares round the camera, then a far ring of
   squares 10 to 25 times bigger while the waves were still full height (seen from the deck, 20 m up, in
   plain view). `field/vl_sea_4d.gd` extends the Water Lab's water (never edits it: another window works
   there): one graded mesh, the even squares to 60 m and every ring 4.5 % wider than the last out to 900 m;
   the fine ripple fades between 60 and 150 m (the shader patched as it loads, in memory).

## 3. Water controls, foam, grass (47 to 49)

5. **The Aquatic Lab's controls** (#47). Tab: COMPARE (ours as saved, or the Aquatic Lab harbour's saved
   water read live from its seascape_tuning.cfg, with the swell it opens on); SEA STATE, its eight presets
   as buttons; WATER, its panel's own eight, named and ranged as it has them, saved in its file's [WATER]
   form; THIS SEA (height, Gerstner); FOAM; LIGHT; THE LAND; GRASS.
6. **Shore foam** (#48). Patched in: strength (default 0.4, the Aquatic Lab's 0.9), how much of it only the
   crests bring (0.65), how deep it reaches (0.4 m), falling to a third by 160 m. All on Tab.
7. **Grass** (#49). It had not been built (round 4's step was still open). Now: the pen's grass carried
   (`carried/grass/`, Andrew's lattice shader with the pen's mask, clearings and paths taken out and patches
   put in), 6 patches chosen off the height map (grass height, level, clear of the deck and the platform,
   nearest the platform first, 14 m apart), heights baked from the chunk meshes under them on a worker
   thread (grass ground only), blades 2.2 times the pen's width, Tab on/off and width.

## 4. Refinements (42 to 45)

8. **Specimen 01's panel** beside its ring (-2.25, 3.3) (#42).
9. **The landscape turned half round** (#43): face_yaw 180 on the station; R and a new look keep it.
10. **The hologram's gradient over the landscape** (#44): the carried showcase draws its hologram on a box
    pedestal too (a box as wide as the deck), on for the landscape only, 1.5 m tall.
11. **The open world's route** (#45): the last orb 0.75 m short of the platform's edge; the marks in the
    platform's own swatch blue, lit as the floor is (`ink_color`, path_mark.gdshader `ink_lit`), instead of
    glowing their own blue.

## 5. Naming (9 Oct, the four labs: Voxel, Creature, Botany, Aquatic)

12. Voxel Lab's own name was already one spelling everywhere it shows (the hall's sign, both loading boards,
    the dev and lights panels). The Water Lab is the Aquatic Lab on Tab now; its folder and code notes keep
    WaterLab.

## 5b. Asked during the round (9 Oct)

- **Grass controls on Tab** ("a grass size slider ... color coder for the grass color and save function"):
  blade height (m), a colour picker (the pen's sap green moved to it, the look's other colours moved the
  same way so its spread stays; "The pen's" puts it back), with the width and the switch, all saved by SAVE
  AS DEFAULTS.
- **Keep the loading screens** ("some protos need time to load"): the lab's own board is back on the way
  in (`board_on_arrival`, on), covering the specimens being built after the menu's screen has loaded the
  file; the open world's board and the board coming back from it were never taken away.
- **The sea from the air**: a lighter square over the built land's seabed (18 m down, nothing past the
  build) seen through 40 m of clear water. `see_depth` 10 m (Tab, THIS SEA): the deep colour everywhere
  but the coast's shallows.
- **A plain seabed** under the whole sea, 0.4 m below the voxel one, in its stone colour: past the built
  land the water now has the same floor under it, so no square shows through from the air.
- **What the grass costs** (Ramon: "how heavy is the grass currently"; `field/_measure_grass_runner.gd`,
  1280 x 720, vsync off, medians of 150 frames, on/off/on): close to a patch +1.00 ms GPU (3.52 against
  2.52), from the deck over the island +0.72 ms (3.31 against 2.59); its layout on the CPU 0.045 ms a
  frame; its heights baked once in 0.2 s on a worker; about 1.1 to 1.2 million blades handed to the GPU,
  most of them dropped in the shader (outside a patch or the slice). Not measured at 4K.
- **The builder**: its deck black under subtle grey lines, not the pedestal's cyan; a metre off both
  walls ("crammed a bit too much in the corner").

## 6. Checks

13. Runners: room (the builder: click places, left drag orbits and places nothing, through W, take away and
    Z), turn, terrain probe (rewritten: the half turn, the hologram, a 170 degree turn without a stop, R,
    every land), gallery, field (graded sea, the Aquatic Lab's water, foam, grass made, drawn, close and from
    the platform, switched off), audit (builder from above, Specimen 01's panel, the far walkway).

Known, left: switching to the open world prints six engine errors ("scenario is null", the lab's panel
viewports freed with the scene); nothing on screen comes of it.
