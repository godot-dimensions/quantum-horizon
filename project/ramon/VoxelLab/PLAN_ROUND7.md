# Voxel Lab, round 7 (10 Oct): Ramon's walkthrough parts 10 and 11, items 76 to 94

His order. Part 10: Escape first (critical), then the Build it marker, panel and reach, then the shorter
entrance and the new title, then the world-change feedback and count, then the lighthouse and the ocean, then
Shift to run. Part 11: take the platform lift out, then the desert's banding, then the biome refinements
(trees, cacti, desert colour), then the volcanoes and their smoke. His saved water and desert settings are
kept as he saved them (`field/voxel_field_sea.cfg` was not touched; a copy is in `.backup/voxel_lab_2026-10-10/`).

## Escape (79), the critical one

**The cause.** Five handlers wanted Escape, and the wrong one always heard it first:

1. The main menu (`Menu/scripts/menu_final.gd`, `_input`): launched from the menu, a prototype is the root's
   first child and the menu its last, and Godot hands `_input` to the last child first. The menu took every
   Escape (and H) and closed the lab at once. Nothing in the lab ever heard it: not the Tab settings, not
   the bench, not the bird.
2. The walker's camera, carried from the pen (`carried/LabKit/carried/chickenpen/scripts/pen_orbit_rig_4d.gd`):
   the first Escape freed the cursor, the second quit the whole program.
3. The bench: Escape stood you up.
4. The presentation: Escape stopped it.
5. The bird: Escape and H landed you. H is also the menu's own way out, so H in flight could drop you in the
   menu.

**The fix.** The Phase Maze's guard (`PhaseMazeRemake/hud/maze_escape.gd`, built for the same report the same
day) carried as `room/vl_escape.gd` and made general. It is a node on the root, added after the menu and kept
last, so it hears Escape and H before anything else and takes them. Then it asks the scene, in order:

1. The confirm box open: Escape closes it (No). Y or the lit button leaves.
2. Something open in the scene: the scene closes the top one (`escape_step`). In the lab: the F1 panel, the
   Tab lights panel, a pop-up, the presentation, the bench. In the open world: the Tab settings, then a
   flight (Escape or H land you).
3. Nothing open: "Return to the main menu?" with YES and NO. Only YES leaves (through the menu's own way of
   closing a prototype; run on its own, to the menu scene).

The carried walker rig no longer quits, whatever reaches it. The menu's file is untouched.

## Part 10 (76 to 86)

- **Build it's marker (76).** The ring is a metre nearer, 1.3 m off the pedestal, on the pivot's own row, so the
  branch leaves the spine at a right angle. The ring is also on the left run's line, so that run goes straight
  down to the Voxel Lab wall: the diagonal bend is gone. (Specimen A moved 0.3 m to share the row.)
- **Build it's panel (77)** floats along the pedestal's left side as you come from the spine, between it and
  the front wall, off the grid, turned toward you.
- **Build it's reach (78).** Its choice comes up anywhere within 1.6 m of the pedestal's sides, not only on
  the ring. Standing on a ring still wins. The builder itself is unchanged.
- **The way in (80).** The corridor is 8.5 m long, not 14, and you start 5 m from the hall's door, not 8.5,
  on the same line. Its look and the door are as they were.
- **The title (81)** is WORLD / CREATION, in the same type, its lines smaller (the sign 1.9 m tall, not 2.6).
- **Generating (82).** Changing the land on the world's pedestal puts a small black pill at the top of the
  screen at once: "GENERATING WORLD 2 OF 3, DESERT…" with a blue line sweeping under it, until the land stands.
  In the open world, green to desert or lava keeps its loading board (it builds for 6.4 s); desert to lava is
  instant.
- **How many worlds (83).** The pedestal's choice reads "Change the land (now 1 of 3, Green)" and its panel
  "Look: 1 of 3, Green". The open world's station reads "Back to the green island (1 of 3)", "Go to the lava
  field (3 of 3)", and its panel "Now: 2 of 3, Red desert".
- **The lighthouse (84).** No red: a white tower, its foot, gallery and cap in greys. A low rail (0.6 m, two
  bars, the platform's own fence made small) stands on the foot's top just in from its edge, round the dark
  ring of stone it stood in. Its discs are smoother (48 sides).
- **The ocean (85).** See below.
- **Shift (86).** The walker already had a sprint: holding Shift takes you from the 2.8 m/s run to 4.2 m/s
  (the same in the open world, where Shift no longer moves the platform). It was never shown anywhere: it is
  on the lab's key strip now ("Shift  Run"). Measured in the test below.

## Part 11 (87 to 94)

- **Your saved water and desert (87, 91).** Not touched: Moderate swell, gentle (preset 9), your wave size,
  foam and colours, and your props (1 mesa a clump, 10 cactus clumps 3.5 m wide).
- **The trees' greens (88)** are made from the island's own green (Tab, THE LAND): a touch darker, about the
  same, and darker and greyer, each a hair off in hue. Round 6's were half its brightness.
- **The desert's banding (89).** Two causes, both gone: the wind ripple in the land shader drew parallel
  stripes a metre apart over the ground (they read as bands in perspective), and the mesas had 16 flat sides,
  each 2 m wide and lit its own way. The ripple is out; the mesas have 48 sides.
- **Cacti (90).** Clumps at least 20 m apart (12 before), each half as wide again as its slider and even across
  it rather than crowded to the middle. Your saved numbers stay as they are.
- **Desert colour (91).** Broad patches of ochre and pale sand, tens of metres across, mostly on the flats, each
  matched to the ground's brightness so the desert stays one piece.
- **The lift is gone (92):** its keys, the moving floor, the gate and its hints on the page and the key strip.
  The platform stands where it was built and still turns the slice. The bird's Space and Shift are untouched.
- **Volcanoes (93).** Each is a 16-cell, whose cut is an octahedron, so its half above the ground is a
  four-sided pyramid with a point, turned at random. Two to four smaller ones lean round its foot as spires.
  Lava runs down two of its faces in glowing veins from just under the peak, instead of one bright spot.
- **Smoke (94).** From two or three peaks, seven grey 24-cell puffs each, rising slowly, drifting, swelling and
  thinning away. It shares Tab's switch with the embers and bubbles.

## The ocean (85)

`field/_probe_sea_runner.gd` renders the sea as saved, then with one thing changed at a time (shore foam off,
crest foam off, highlights off, the fine ripple off, Calm, round 5's bubble size, the Aquatic Lab's own water),
from the platform and from 40 m and 95 m straight down. What it found:

- **Your saved sea is clean.** Moderate swell, gentle never breaks into foam (its crests are far too shallow),
  and from the deck and from the air it shows no blotches and no grain. The controls all work (the probe moves
  each one and the sea follows).
- **The strange look was the foam, and part of it was mine.** Round 6 made "Bubble size" set the shader's
  foam cell size, which every foam on the sea uses. So the crest foam out at sea (from any preset that breaks,
  as Moderate swell does) went to 6 cm cells: a dark grain all over the water from the deck. And the Aquatic
  Lab draws crest foam flat white past 65 m (it was made for a harbour seen from a pier), so from the air those
  breaking crests were large white blotches.
- **Fixed, without touching any of your numbers:** "Bubble size" is the shore foam's alone again; the crests'
  foam keeps the Aquatic Lab's own cells, and fades out between 70 and 160 m instead of turning to flat white
  sheets. With the Aquatic Lab's swell the grain is gone from the deck, and from 95 m the breaking crests are
  soft and pale, not white.
- **Still yours to judge:** with "Wave size" at 0.25 the swell is a field of small waves (it shortens the waves
  as well as lowering them, by the Aquatic Lab's design), which reads as fine regular ripples toward the
  horizon. That is the setting, not a fault; a larger wave size gives longer waves.
