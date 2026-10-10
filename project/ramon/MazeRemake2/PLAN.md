# Maze Remake 2: THE ANNEX (plan, 11 Oct 2026)

Ramon's brief: "FACE MAZE, REMAKE 2", a 100-step autonomous brief (design, build, test, deliver).
"Face Maze" is the Phase Maze. The original (`ramon/PhaseMaze/`) and the first remake
(`ramon/PhaseMazeRemake/`, on the menu as "The Maze") stay untouched.

Scene: `res://ramon/MazeRemake2/maze_remake_2.tscn`. Everything else for it lives in this folder.

## 1. What the research found (steps 1 to 15)

Read for this plan: the original's builders and HUDs, the first remake's handover, PLAN.md round 3
(its gizmo survey) and RESEARCH.md (prior art with sources), the pen's slice dial, locator, V
prompts and mouse cards, the four labs' looks, dials, cards, cinematics, Esc guard and sound,
the team's first-person player, and the engine's physics and cross-section code.

**Why the original felt immediate.** You were a person in a corridor. Mouse and WASD did what
they do in every game, Q and E moved you along W at walking speed, and the world answered at
once: a wall you had been staring at was simply gone at the right W. Nothing stood between you
and the experiment. Its weaknesses: a black void, broken shading, five lines of rules in
capitals, and the gaps were a combination lock (the maze was the same at every W except three
narrow bands, found by watching a number).

**Why the first remake felt clunky.** It made W real space (a maze in x, z and w), which was
right, but it paid for it with control: a third-person chase camera in 6 m cells, quarter turns
on F that took the keys away while they eased, a slow blind step on Q/E (7 s a cell), a cube
badge, a ruler that only moved per cell, a map, hints, 4D sight. Every aid was a fix for a
control that did not explain itself. The player ended up working the controls instead of
exploring.

**What the newer work gives us.**
- The pen: the V prompt that finishes a reveal you have started (offered between about 35 and
  99 per cent visible; it eases you there in 0.45 to 0.6 s, exactly), the animated mouse and key
  cards that appear where a skill is needed and retire once you have used it, and the rule that
  "off your slice" is measured along the camera's W axis (`w_sense_4d.gd`).
- The labs: the Creation Lab look (kit palette, grid floors, code-blue teaching walls with white
  type, the lab light under Ramon's saved numbers), B for the dark palette, printed signs, the
  Esc guard (`vl_escape.gd`), sound made in code, film cameras that hand control back cleanly.
- The engine: physics is axis-aligned boxes in four axes, so a wall that spans only part of W
  blocks you only where it exists, and moving along W is swept against walls like any other
  move (you cannot step through W into a wall). The cross-section is binary (no fade), so a
  doorway can only appear gradually if its *geometry* changes gradually with W.

**The assessment (step 15).** Take the original's body (first person, free walk and look, Q/E
along W at walking pace) and the remake's idea that W is space, and drop everything that
turns exploring into operating: no grid, no forced turns, no slow blind step, no map, no hint
ladder. The one thing that must be invented is what the original lacked: a way for W changes
to be *seen continuously*, so that pressing E feels like moving somewhere rather than scanning
a combination.

## 2. The idea

**Shift through W, and the building rearranges itself around you: doors slide open, walls sink
into the floor, rooms rise out of it. Find the way, walk in.**

The core is one new building block, the **morph box**: a 4D solid whose cross-section is a box
that changes smoothly along W (a door leaf that slides sideways as you move ana, a wall whose
height falls to nothing at the edge of its W range). It is real 4D geometry (two 3D boxes at two
W values joined across W), so what you see is the true slice, not an effect, and its collider
is the same shape in steps of W. Everything in the levels is built from it, so the whole world
answers W the same way, continuously, and physics always agrees with the picture.

**Decisions, and why.**
- **First person, free movement and look** (brief, and the original). Jamróz 2019 found people
  escape first-person 4D labyrinths; what made it possible was perspective. The remake's case
  for third person was the body showing a tilted slice; here the slice is level in levels 1 and
  2, and the turn in level 3 is shown by the gizmo and the floor's colour bands.
- **W is a continuous position, moved at walking pace** (1.6 m/s, Q/E or the mouse wheel), not
  a cell step. A level spans about 7 m of W, so any place is a couple of seconds away.
- **The floor's colour is your W.** Each level has W bands (kata amber, home blue, ana teal, and
  a fourth for level 3). The floor shader colours itself by the true W of every point, so the
  whole floor shifts hue as you move, and in a turned view the bands lie across the floor as
  stripes. The gizmo, door frames and signs use the same colours (Miegakure's banded ground,
  Crosswise's lanes, the remake's layer floors; but continuous).
- **Doors say where they open.** Every W door has a glowing frame in the colour of the W where it
  opens. Teal door: go ana. Amber door: go kata.
- **V finishes a reveal exactly.** Offered when a door is between 70 and 99 per cent open (or a
  turn 70 to 99 per cent done) and you are near it and facing it; it eases W (and, in level 3,
  the turn) to the exact open position in 0.4 s.
- **The world is bounded in W by real walls** ("W caps"): solids that fill a room's footprint
  outside its W range. You can never shift into nothing or fall out of the world; the gizmo
  shows the stop, and a soft knock says you hit it.
- **One new control per level.** Level 1: Q/E (and V). Level 2: nothing new, but W becomes a
  maze. Level 3: the turn into W (right mouse and drag, from the Lens found at the end of level
  2), with V and R.
- **The lab look by default**, made eerier: the lab's palette and light in BRIGHT; in DARK the
  near-black kit palette, glowing strips and a torch on the camera. B switches, as in the labs.
- **Short.** About 6 to 10 minutes for all three levels.

## 3. The visitor's flow

1. The menu launches straight into level 1's arrival room (title card for 2 s). No lobby.
2. A blue wall: "THE CORRIDOR ENDS. THE BUILDING DOES NOT." Ahead, a corridor ends in a door with a
   teal frame. Within seconds a key card shows E. Press it: the floor turns teal and the door's
   leaves slide apart. V appears; V snaps you to the open W. Walk through. Under 30 s.
3. A garden hall that only exists ana. A glint in the air that only shows at its own W (a relic).
   A second door further ana leads to the lift.
4. The lift (the same small chamber begins and ends every level): doors close, hum, fade, open.
5. Level 2, the archive: the same doorways lead to different rooms at different W. A landmark
   pillar in the middle never changes. A pit crossed by two bridges, one amber, one teal, that
   overlap in the middle. A room that is an archive at home and a dark computer room kata. At the
   end, the Lens: a short film turns the view into W and shows every band side by side.
6. Level 3, the Heart: a vast dark atrium, a giant 24-cell crystal whose cut changes as you shift.
   Shifting at the centre stops dead: something is ana of you. Turn your view into W: a vault
   stands there, sealed by two lights. Find the two seals (one behind a kata door, one across a
   W-weaving route), turn, walk in along W. The finale, a quiet film, the end card (replay or
   menu).

## 4. The levels on paper

y is up; you start facing -z. Metres. W bands per level: KATA amber, HOME blue, ANA teal
(level 3 adds DEEP violet beyond ana).

### Level 1, THE THRESHOLD (teaches: E reveals a door; V finishes it)
- Arrival A: x -3.5..3.5, z 0..7, all W. Blue lesson wall on the east side.
- Corridor: x -1.3..1.3, z -9..0. At z -9 door D1, teal frame, leaves part over W 0.3 to 1.4.
- Garden hall G: x -6..6, z -22..-9.2, exists from W 0.2 to 4 (capped kata of 0.2). Tall, warm,
  a tree or flowers under a skylight. A floating relic at W 3.0 (visible only near its W, grows
  from a point as you approach: the pen's glimpse).
- Kata niche in A's west wall: amber door, opens over W -0.4 to -1.4; a small alcove (W -3..-0.2)
  with relic 1, an old monitor showing the original Phase Maze's sign (an homage).
- Door D2 in G's far wall: teal, opens over W 2.4 to 3.2. Beyond: the lift (W 2.6..4).

### Level 2, THE STACKS (teaches: different W, different routes; two routes that meet)
- A 3 x 3 grid of 8 m bays, the hub in the middle with the PILLAR (glowing, the same at every W).
  Start in the south bay (lift), exit beyond the north-east bay.
- HOME: south to hub, hub to west, west to north-west (a dead end with a sealed door).
- ANA: hub to east, east to south-east; north to north-east.
- KATA: hub to north; north to north-west.
- The north bay holds a pit with two bridges: amber from the south edge to the middle, teal from
  the middle to the north-east door. They overlap on a striped landing. Fall: back to the bay's
  door.
- The west bay is an archive (tall shelves) at home and a dark computer room kata (the shelves
  sink, the walls move): a terminal with a research log, and something alive (relic).
- The north-east bay: the Lens on a plinth (the Dream Shifter's 24-cell crystal). The reveal
  film, then the lift.

### Level 3, THE HEART (teaches: turning into W; combines the doors and routes)
- Atrium 28 x 28 m, 12 m high, dark; the giant crystal floating high in the middle.
- The vault: ana of the atrium's centre (W 2 to 8), closed on every side in x and z at every W.
  Its kata face (at W 2) has a doorway, visible only in a turned view. Shifting at the centre
  stops at W 1.75.
- Seal A: west alcove behind an amber door (kata).
- Seal B: east alcove reached by a route that weaves between home and ana.
- With both seals lit the vault's doorway unseals. Turn (right mouse, drag up), V to finish,
  walk forward (along W) into the Heart. Finale and end card.

## 5. The gizmo (steps 26 to 40)

Three genuinely different designs, built side by side behind one switch, photographed in the same
situations (facing D1 at W 0, half open, aligned; level 2's bridge; level 3's turn), then judged
on how fast a newcomer reads them:

- **A. THE RULER**: a horizontal W scale at the bottom centre, kata on the left, ana on the right,
  coloured by band, your needle moving continuously, the doors in view marked at the W where they
  open, Q and E caps at its ends, the stops shown as walls.
- **B. THE DIAL**: a compact radial gauge in the corner: W as an angle round a ring (a
  combination dial, which is what the original felt like), doors as notches; the turn shown as a
  needle in the middle.
- **C. THE LENS (hybrid)**: a slim ruler plus feedback in the world: the door you are looking at
  gets brackets on screen and a ring that fills as it opens, with the V chip when it is ready;
  the turn appears as a small quarter-circle meter only once you have the Lens.

The choice and why go here once the frames are in (section 9).

## 6. The 100 steps, adapted to this codebase

### Phase I: research and foundation (1 to 15): DONE above
1-15. Original, remake, pen dial/locator/V/cards, the labs, materials, physics, menu, assessment.

### Phase II: define the game (16 to 25)
16. Folder `ramon/MazeRemake2/` (CamelCase like its neighbours), this PLAN.md.
17. The originals untouched; nothing outside this folder edited except the menu's catalogue (98).
18. Main scene `maze_remake_2.tscn`: a root `Node4D` (`maze_remake_2_4d.gd`) that owns the game,
    the player, the HUD and the light, and loads one level at a time as a child scene
    (`levels/level_1.tscn` ... built in code from its script, so collider and mesh never drift).
19. First person (section 2).
20. The sentence: shift through W, and the building rearranges itself; find the way, walk in.
21. Three levels, one insight each (section 4).
22. Level 1's first door within 30 s of arriving.
23. Level 2's routes that only exist at some W, and the two bridges.
24. Level 3's vault reached only along W.
25. The lab look, eerier in dark (section 2).

### Phase III: the gizmo (26 to 40)
26. The original's gizmo: a W number plus a magnitude bar; readable because it moved every frame.
27. The pen's dial: stems and rungs for things at other W; green when in your slice.
28. The labs' tank dial (YOUR SLICE line), mouse card, key strip.
29. Build gizmos A, B and C (`hud/gizmo_ruler.gd`, `hud/gizmo_dial.gd`, `hud/gizmo_lens.gd`).
30. A: the ruler (the pen's and Crosswise's vocabulary, continuous).
31. B: the dial.
32. C: the hybrid.
33. A runner photographs all three in the same five situations; the sheet in `smoke_test_output`.
34. Choose by how fast a newcomer reads it (written up in section 9).
35. W responds at once: speed 1.6 m/s, acceleration 10 m/s², the wheel nudges 0.35 m eased.
36. The needle moves continuously and smoothly.
37. The floor's hue, the door frames and the gizmo share one colour scale.
38. V at 70 to 99 per cent open, near and facing the door.
39. V eases to the exact open W in 0.4 s (and the exact quarter turn in level 3); collision-safe.
40. A small key strip: only the keys that matter here and now (MOVE, LOOK, Q/E, V when offered,
    R when turned, B).

### Phase IV: movement (41 to 50)
41. `player/mr2_player_4d.gd`: a CharacterBody4D (capsule 0.25 x 1.75, as the team's player),
    yaw on the body, pitch on the head, no Esc handling of its own.
42. Mouse look, sensitivity on the Tab panel; pitch clamped.
43. Walk 3.4 m/s, Shift 5.5, acceleration 30, friction; gravity; floor snap.
44. W moves through `move_and_slide` with the walk, along the body's own W axis.
45. Morph boxes everywhere: what you see is what collides, in steps of 0.1 m of W.
46. A wall blocks until its cut is gone; you cannot shift into a wall (the engine sweeps W).
47. A door's leaves are out of the way well before V's target.
48. No softlocks: W caps everywhere, no stairs or ledges, the start of every room reachable.
49. Recovery: R levels a turn and returns to the room's home W if free; Backspace returns to the
    last checkpoint (each room's entry), with a short fade.
50. A greybox probe (`scripts/_probe_morph_runner.gd`) before any level: a sliding door and a
    sinking wall, frames at several W, the bot walking through.

### Phase V: level 1 (51 to 60)
51. The arrival room, compact, lit, with the lesson wall.
52. The key card (E and Q, a dot sliding along a W axis) after 2 s looking down the corridor,
    retiring once you have moved 0.5 m of W.
53. D1 in sight from the spawn.
54. E reveals it; the floor turns teal.
55. Leaves slide into the jambs; a soft slide sound tied to how fast they move.
56. V at 70 per cent.
57. Walk through.
58. The garden hall, warmer, taller, a skylight.
59. The kata niche (relic 1) and the floating relic at W 3 (relic 2).
60. D2 and the lift to level 2.

### Phase VI: level 2 (61 to 70)
61. The 3 x 3 archive, corridors between bays, bay numbers on the walls.
62. Identity: tall shelving, fluorescent strips, a hush.
63. Three bands of walls, each its own plan, rising and sinking as you shift.
64. The hub: its doors lead to different bays at different W.
65. The pillar: the one thing that is the same at every W.
66. The west bay's kata twin: the computer room, the log, something alive.
67. A tone per band; bays a little different in light.
68. The bridges over the pit.
69. Nothing hidden behind a key or a hotspot: every route is walked.
70. The Lens and its film (the bands laid side by side), then the lift.

### Phase VII: level 3 (71 to 80)
71. The atrium, dark, vast.
72. A kata door and a weaving route to the two seals.
73. The vault ana of the centre.
74. The crystal: its cut changes with W and with time.
75. The Dreamer (Azathoth) in the Heart, carried, if he costs little enough; else the crystal's twin.
76. A short skippable film when the vault unseals.
77. The final step is to understand that the blocker is ana of you, and to turn and look.
78. Once turned, the doorway is plain: a lit opening in a wall.
79. The finale: lights, a chord, the crystal's pulse, the end card with time and relics.
80. Replay (Enter or R) or the menu (Esc, through the guard).

### Phase VIII: presentation (81 to 90)
81. The kit's proportions: 3.6 m rooms, 2.6 m corridors, 0.4 m walls, posts at corners.
82. Kit swatches and the lab grid shader, carried, with the W tint added.
83. Each level its own material accent and light.
84. Eerie, never horror: hum, distance, emptiness, a living thing in the dark.
85. BRIGHT: the lab's light and Ramon's saved numbers.
86. DARK: the kit's black palette, glow strips, a torch on the camera.
87. B in every level, remembered.
88. Sound in code: a hum per level, a tone that follows your W speed, door slides, a chime, the lift.
89. Cards and films short and skippable.
90. HUD typography on the kit's type ladder; fades between levels; the end card.

### Phase IX: testing and delivery (91 to 100)
91. Parse checks, first load, every error fixed.
92. The bot plays level 1 from a fresh start through the real keys; frames looked at.
93. Every W interaction: E/Q, wheel, V, door collision, W caps, R, Backspace.
94. The bot plays levels 2 and 3; falls and recoveries.
95. Films: skip, camera back, keys back.
96. BRIGHT and DARK in every level: frames, contrast of the gizmo, frame times.
97. The Esc guard: from the menu and alone, from every level, during a film, with the Tab panel.
98. The menu's catalogue: a new entry after "The Maze", nothing removed; a thumbnail.
99. The whole thing end to end, launched from the menu, played through, replayed, back.
100. The handover (`follow_up/maze_remake_2.md`) with Questions for Ramon at the top, memory, commit
     by explicit paths, no push.

## 7. Risks I am watching
- Morph boxes are new: the probe (50) comes before any level.
- The capsule touches walls 0.25 m before you can see them in W (its W half-width): doors open
  0.4 m before V's target, so you never hit an invisible leaf.
- Turning in first person can disorient: level 3 only, V finishes it, R undoes it, and the
  floor's stripes show which way W runs.

## 8. Status
11 Oct, night run. Built: the morph box and its probe (step 50, all five checks), the builder (doors,
passages, caps, signs, lights), the light and B switch, the first-person player (walk, look, W, the turn,
V, R), the HUD (three gizmos, the key strip, cards, toasts, films, end card), sound made in code, the Esc
guard, and the three levels. Each level is played through by a bot runner on the real keys: level 1, 11
checks; level 2, 16; level 3, 22 (the whole game, start to end card and replay). Remaining: section 10.

## 9. The gizmo trial (steps 29 to 34)
All three were built and photographed at the same moments (smoke_test_output/maze_remake_2/
gizmo_trial_sheet.png: level 1's first door at 79 per cent and after V, level 2's hub at home and the
landing ana). G cycles them in the game, for anyone who wants to compare.

- **A, THE RULER**, read fastest for *where am I in W*: the whole level's scale, the bands in the floor's
  colours, numbers, the doors as glyphs that part as they open, the stops hatched, Q and E at the ends.
  But it says nothing about the door in front of you, and it takes a 560 px panel.
- **B, THE DIAL**, is the most compact, and the combination-lock metaphor is the original's. But W as
  an angle has to be decoded every time (which way round is ana?), its door notches cannot be tied to
  the door you see, and the needle is in the corner, far from the action. Slowest to read; rejected.
- **C, THE LENS**, puts the answer where your eyes already are: brackets on the door you face, a ring
  that fills as it opens with how open it is, and the V chip under it at 70 per cent. Its own slim ruler
  was too faint (tiny labels, no keys) and lost A's clarity.

**The choice: C, with A's ruler in compact form inside it** (hud/gizmo_lens.gd draws
gizmo_ruler.gd's `draw_ruler` at 440 x 46). The ruler answers where you are and where the doors open;
the lens answers how open this one is and when V will finish it. The turn's meter only appears once
you hold the Lens. Brackets and ring sit on dark glass so they read on the white lab walls.

## 10. What is left (in order)
- The Tab panel: mouse, W speed, FOV, light, torch, volume; SAVE.
- The menu's catalogue entry and its thumbnail; one launch from the menu, Esc back.
- Frame times per level; the HUD at 4K; BRIGHT and DARK sheets.
- The handover (follow_up/maze_remake_2.md), memory, commit.
