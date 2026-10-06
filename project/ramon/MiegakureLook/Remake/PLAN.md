# Crosswise: the Miegakure remake (plan, 5 Oct 2026)

Ramon's brief, item 6 of his list: remake the Miegakure-inspired prototype. The current one
(`MiegakureLook/levels/`, menu entry "Slice Vision") has the right mechanic and feels dry: an
orange ball on a grey slab in a purple void, moving forward, back and through W.

**What this becomes:** a little walking character on bright floating islands, in a compact
sequence of four 4D puzzles. You see where you are going from the start, and every action
(walking, turning the slice, carrying, striking) exists because a puzzle needs it. One new scene,
`MiegakureLook/Remake/crosswise.tscn`. The old levels stay as they are.

How it was researched: `RESEARCH.md` (Miegakure's own words, screenshots, player accounts, and
what each one changed here). What was learned while building: the "Status" and "Pivots"
sections at the bottom of this page, kept current as the work goes.

## The idea in one paragraph

You play a small figure (the pen's little walker, copied over) on a chain of floating islands
islands, bright like the Creation Lab and mint-skied like Miegakure. WASD walks in the world you
can see. The right mouse button turns your view a quarter turn into W: the world deforms round
you, the sky cools, and now forward and back walk through W while left and right stay what they
were. Four islands, one idea each: **the Wall** (a gate that only exists in some worlds),
**the Cage** (a crate locked in a cage that is closed in 3D and open in 4D, carried back to a
plate), **the Seam** (a fence that stands across W, with a two-strike rock in its door), and
**the Shrine** (all of it at once, to climb to the tower you could see from the first step).

## Decisions, and why

1. **Movement stays inside the slice.** WASD only ever moves you in the 3D world on screen; you
   move through W by turning the view (the swap), never by a separate key. That is Miegakure's
   rule, and it is what makes the puzzles: you cannot see where W takes you until you turn to
   face it. A/D are always world X, "the axis that never changes", so left and right mean the
   same thing in both views. W/S walk Z in the first view and W in the second.
2. **Keys map to the world's axes, not the screen.** Measured in v2: camera-relative keys at a
   45 degree diorama yaw walked the ball off the platform. The camera yaw is then a pure framing
   choice. The character turns to face where it walks, so the eye follows him rather than a
   compass.
3. **The little guy looks the same in both views.** His body is turned with the slice, so the
   world deforms round him while he stays himself (Miegakure: the player is "3D with a tiny
   amount of 4D width"). His collider is the same depth in Z and W, so the swap never changes
   what he bumps into.
4. **The floor carries W.** The ground is the one surface in every slice (Marc ten Bosch, and
   measured in this folder on 19 Aug). Floors are banded in W lanes by the shader: the home lane
   white, kata lanes cooler, ana lanes warmer (the same code PathCreator's builder uses), with
   special lanes marked. In the first view you see your lane's colour; turned, you see all of them.
5. **Faces that end something in W get their own colour.** The surface shader knows each cell's
   4D normal, so the faces with a W normal (a crate's W ends, an island's W edges, a fence across
   W) are tinted. They only face you after a swap, so the tint says "this is where it stops in
   W". Miegakure colours its cut faces the same way (its island sides go deep blue when sliced).
6. **The sky says which way you are looking.** Pale mint with the normal view, cool blue when
   turned into W (Miegakure's own screenshots do this). No HUD needed to know the mode.
7. **Built from boxes where you collide.** Physics is axis-aligned boxes only (engine_capabilities),
   so everything you walk on or bump into is a box, and round or faceted shapes are decoration
   away from the routes.
8. **Aaron's FenceGenerator4D for structure, not only fences.** Walls, the cage, gate frames, a
   crate, railings, the shrine and the tower. A one-face "sheet" seed makes a wall; a sheet whose
   normal is W makes a fence that stands across W; a four-sided tube makes a cage open in W.
   It makes no collision, so each piece gets its own boxes.
9. **Native voxels for the rock.** One small `VoxelWorld4D` per plug (the engine's own,
   dual-contoured, cut by the slice like any mesh), a grey crust over a gold core: the first strike
   carves a dent that shows the gold, the second shatters it.
10. **No presentation rooms** (Ramon). You start in the islands. Guidance is painted on the ground:
    key icons at the start, W-cue dots, footprint frames, hazard bands, a hint layer on request.
11. **Forgiving.** A fall puts you back at the island's arrival ring with a short fade, the crate
    returns to its stand if it fell, R restarts the island, and no mistake costs more than a few
    seconds.
12. **Kept apart from the pen.** The walker, gait and pickaxe ideas are copied into this folder;
    nothing in `chickenpen/` is touched. PathCreator's scripts are used as they are (preloaded,
    never edited).

## The four islands

Islands lie along -Z, each 12 m across in X and 8 m deep in W (lanes of 1.6 m: -2, -1, 0, +1,
+2). You start in lane 0. The shrine's tower stands on the last island and spans every lane, so
it is in view from the first step in the normal view.

| # | Island | What you see | What you do | What it teaches |
|---|---|---|---|---|
| 1 | **The Wall** | the bridge onward behind a gate wall; the tower beyond; a small onlooker by the wall | turn, walk ana two lanes to the lane with the gate frame, turn back, walk through (the onlooker loses you, then finds you on the far side); then, in plain 3D, a ledge too high to step onto and a crate beside it: lift, place, climb | the swap; worlds side by side; the floor lanes; then carrying on its own |
| 2 | **The Cage** | a crate in a cage, a yellow plate at a chasm, no bridge | walk to a lane where the cage is not, stand on its painted footprint, turn: the cage is open along W; walk in, lift the crate, carry it out through W, put it on the plate; the bridge slides out | an object can be inside something in 3D and outside it in 4D; carrying through W |
| 3 | **The Seam** | first a small rock across the path (plain 3D: strike twice); then an open island, no way on, and a striped band across the floor | stand on the band and turn: a fence crosses W with a rock in its door; strike twice; walk through into lane -2 where the bridge is | the strike on its own; then walls can stand across W and only show when you turn |
| 4 | **The Shrine** | the tower on a terrace too high to climb | carry the crate from lane +2 round a gap in lane +1, place it at the marked spot in lane 0, climb crate then terrace, walk to the shrine door | all of it together |

Each new action is met once on its own, in plain 3D, before it is asked of you through W
(Miegakure's own ordering: 3D-only levels teach pushing and jumping before W does; RESEARCH.md).

## The 80 steps

### A. Ground truth and probes (1-10)
1. Folder `MiegakureLook/Remake/` with this plan, `RESEARCH.md`, and `run.sh` (one Godot at a
   time: the lock and the process check gate the launch in the same command; logs to
   `smoke_test_output/crosswise/logs/`, errors grepped).
2. `RESEARCH.md`: Miegakure's mechanic and readability devices in its maker's words, the
   screenshots, player accounts (where they get confused, what delights them), and the ten
   lessons, each tied to a step here.
3. A before-picture of the current prototype: frames of levels 1-3 in both views, a contact sheet.
4. Probe: FenceGenerator4D bent into other things (a wall sheet, a sheet across W, a tube open in
   W, a crate, a gate frame, a tower, a pyramid roof): build times, TETRA output, this folder's
   shader on its materials, frames in both views.
5. Probe: one native `VoxelWorld4D` plug: palette, bounds, load trigger, a sphere carve, its
   remesh cost, both views.
6. Probe: the copied walker on a flat slab with slice movement and the avatar turned with the
   slice: does the gait plant its feet in both views and through a swap?
7. Probe: the surface shader fork: W lanes, the W-face tint, a near-the-W-edge tint, in both views.
8. Probe: the Combined renderer with `allow_projection` on only a few meshes (faint ghosts of the
   crate and the goal when they are out of your slice), switched live. Kept only if it holds and reads.
9. Probe: camera framing, a contact sheet of pitch, yaw, distance and lens with the little guy at
   three sizes; pick by eye.
10. Keys: confirm what is free (E, left and right mouse, Space, R, Tab, H for the menu); fix the map.

### B. The look (11-18)
11. Moods: the lab's bright light under a mint sky (normal view) and a cool blue sky (turned),
    with the sun, ambient and sky eased together during a swap.
12. Island slabs: floating, thick, dev tiles on top, darker strata on the sides, a trim edge.
13. The lane code in the shader: white home lane, cooler kata, warmer ana, seams between lanes,
    and marked lanes (the gate lane, a hazard band).
14. The W-face tint on every box and fence piece.
15. A FenceGenerator vocabulary for set dressing: railings, gate frames, walls, posts, materials.
16. Landmarks that survive the swap (pieces spanning Z and W: corner posts, railings) and faceted
    crystal props (orthoplex, 24-cell) off the walking routes, Miegakure's crystals in our renderer.
17. The destination: a fence-built tower and shrine (walls plus a pyramid roof) on the last
    island, in view from the start.
18. Look runner: an island in both views and mid-swap, set beside the Miegakure screenshots.

### C. The little walker (19-30)
19. Copy the chibi avatar and its gait into `Remake/character/` (forks); colours that read on the
    bright ground.
20. The walker: slice movement (A/D world X, W/S the view's depth axis), run by default, Alt to walk.
21. His body turned with the slice; facing inside the slice.
22. Collider the same depth in Z and W; a 0.3 m step-up; a jump that clears a crate.
23. The swap key, movement held while the view turns, one swap queued if pressed during a turn.
24. Fall bound: a short fade, back to the island's arrival ring.
25. A key rose painted round his feet: four short arrows, the forward one blue for Z or warm for W,
    so the keys stay readable after a turn; it fades while he stands still.
26. The carry pose: stoop, arms up, the load's sink; the crate rides overhead and turns with the slice.
27. The strike: a small hammer appears for a 0.45 s swing; the hit lands at a set frame.
28. Small life: a bump when blocked, a head shake when an action is not possible.
29. A soft contact shadow under him (a dark disc on the floor in both views).
30. Walker runner: each key in both views, measured for axis purity, frames.

### D. The camera (31-36)
31. Diorama camera (a fork of v3): angles from probe 9; follows him smoothly within the view,
    while the slice stays exactly on him.
32. The swap: a 0.65 s eased quarter turn about him, the moods and a sound in step.
33. Island framing: the camera leans toward each island's centre so the island fills the frame.
34. A little look-ahead in the direction he walks.
35. The finale: a slow pull-out round the tower.
36. Camera runner: framing per island, both views.

### E. Interaction (37-48)
37. The crate: a fence-built 4D crate with a yellow core (yellow is "use this"), a body with
    gravity, its collision switched off while carried.
38. Pick up (E): the nearest crate in reach in your slice; the stoop; the lift.
39. Put down (E): a spot ahead on a 0.25 m grid with a ghost outline on the floor; refused (with a
    shake and a sound) if it would overlap anything.
40. Crates as steps: stand on one, jump from it to a ledge.
41. Crates and the swap: a placed crate is a 4D cube, the same in both views.
42. The plate: a yellow pad with a crate icon; it notices a crate resting on it (polled, not an
    Area4D); it sinks, turns green, chimes.
43. The bridge: slabs slide out one by one when the plate is down, and back if the crate is lifted.
44. The rock: a native voxel plug, crust over core, a box collider, a hazard frame, two pips beside it.
45. Strike one: a dent that shows the gold, chips, a sound, one pip goes out. Strike two: it shatters.
46. Prompts: fixed size, screen space, beside the thing (E lift, E put down, click strike).
47. Arrival rings as checkpoints; R restarts the island (crates and rocks put back).
48. Systems runner: lift, carry, place, plate, bridge, strike, with frames at each beat.

### F. Orientation and guidance (49-56)
49. The HUD, black glass and small: the view badge (X Y Z or X Y W), a W ruler with lanes, you,
    the crates and the goal, and only the keys that apply now.
50. Key icons painted on the ground at the start (WASD, the right mouse), not on panels.
51. W cues where a way goes on in another lane (PathCreator's dots: warm ana, cool kata).
52. Footprint frames round things that exist in another lane (the cage's footprint in every lane).
53. Hazard bands across all lanes where a rock waits along W.
54. The hint layer (a key, or by itself after 45 s without progress): the island's route lights
    up, including a network turned into W for the turned view.
55. Ghost hints, if probe 8 holds: the crate and the goal faintly visible when outside your slice.
56. Guidance runner: every cue in both views.

### G. The sequence (57-68)
57. The sequence builder: four islands along -Z, bridges, the tower, arrival rings, the reset registry.
58. Island 1, the Wall.
59. Island 2, the Cage.
60. Island 3, the Seam.
61. Island 4, the Shrine.
62. The finale: the shrine door, the tower lit, a card (time, turns, falls), replay or menu.
63. Pacing: walking distances, lane widths, island sizes; trim dead time.
64. Forgiveness: every mistake checked (a fall, the wrong lane, a crate into a gap, a crate in a
    bad place, a strike at nothing) and what it costs.
65. A solver bot that plays each island through the real input path.
66. The bot's run captured at every beat in both views, contact sheets.
67. A film of the whole run (Godot's movie writer) for Ramon.
68. A bad-path bot: wrong lanes, falls, resets; the game recovers every time.

### H. Sound (69-71)
69. Sounds copied into `Remake/audio/`: turn, lift, place, plate, bridge, strike, shatter, fall,
    goal, an ambient bed.
70. Wired, with level and pitch variation.
71. A sound check in a run.

### I. Proof and performance (72-76)
72. Frame time per island (vsync off, windowed, timed between frames), the swap, a strike, the
    fence builds at load.
73. Readability: his size on screen, prompt sizes at 1080p, lane contrast in both views.
74. Every script parse-checked and every runner green.
75. Look review: a sheet beside the Miegakure screenshots and the lab's look.
76. Fixes from 72-75.

### J. Handover (77-80)
77. `follow_up/crosswise.md`, with Questions for Ramon at the top.
78. engine_capabilities.md and engine_gotchas.md: what FenceGenerator4D and the native voxels
    can and can't do, dated.
79. Memory.
80. Commit by paths (this folder and the handover), not pushed.

## Not in this plan (questions for Ramon, not blockers)
- The menu: the catalogue is a shared file, so the new scene is not wired into the menu. It
  could replace the "Slice Vision" launch or sit beside it.
- PathCreator is used as it is; nothing in `CreationLab/` is changed.

## Status
(kept current while building)

**Steps 1-7, done (5-6 Oct, night).**
- `run.sh`: the lock and the process check gate every launch; `batch` runs a list under one hold
  of the lock (three windows were queuing for Godot all night); `wait` queues. Never edit it while
  a run uses it: runs go through a copy.
- Before-picture: `smoke_test_output/crosswise/before_sheet.png` (the orange ball on a grey
  slab in a purple void, both views, all three levels).
- Probe 4, FenceGenerator4D: all eight non-fence designs build, in 3 to 13 ms (the cage with bars
  every 0.4 m, 51 ms). A sheet whose face spans X and Z at one W is a fence that stands across W:
  absent in the normal view, a fence line across your path once turned. A four-faced tube is a cage
  open along W. A torii is a sheet with one beam at the top. Frames: `probe_fence/`.
- Probe 5, native voxels: a 1.6 x 2 x 1.6 x 1.2 m plug, crust over gold, carved by one sphere edit
  in 0.19 ms with no frame hitch; the dent shows the gold. Frames: `probe_voxel/`.
- Probe 6, the walker: every key pure along its axis in both views (W walks -Z, then exactly +W
  once turned), the slice exactly on him (offset 0.0000). Frames: `probe_walker/`.
- Probe 7, the shader: lanes, seams, the W-face tint, all seen in the turned frames.

**Steps 8-62, built (6 Oct, early hours).** The scene `crosswise.tscn` (one node; everything is
built by `crosswise_4d.gd` and `world/mk_islands_4d.gd`), the four islands, the walker with hands
(lift, carry, place with a ghost outline, the hammer) and feet (shadow, key rose), the camera (turn,
follow, island framing, the opening shot, the finale pull-out), the plate, the bridge, the voxel
rocks, the floor signs, the onlooker, the HUD, the dev panel, the sound, 4D sight (V), the auto-hint.
- The solver bot (`scripts/_solve_runner.gd`) plays all four islands through the game's own code;
  the bad-path bot (`scripts/_badpath_runner.gd`) makes every mistake on purpose: 11 of 11 pass
  (a fall recovers in under 3 s, the crate goes home, R restores a broken rock, two quick turns settle).
- Step 8 (the Combined ghosts) became 4D sight, a V toggle, off by default.
- Step 9 (framing) was chosen by eye from the island frames: 54 degrees down, 32 round, 10.5 m, a
  32 degree lens, a 0.22 lean toward the island's middle; all on F1 for Ramon.

**Steps 63-80, done (6 Oct).**
- Proof: the solver 18 of 18, the bad paths 11 of 11, the tools 4 of 4; about 1 ms a frame on every
  island; the film `smoke_test_output/video/crosswise.mp4` (82 s, sound peaking at -8.8 dB).
- The fixes the proof found: the strike hitch (rocks pre-dented and parked, 111 ms to 12 ms), the
  finale's framing and card, the cage's black bars, a railing at the terrace's foot, the silent film,
  the HUD's size at 1080p.
- Not built, on purpose: the hint layer as PathCreator routes (step 54's second half). The painted
  signs, W-cue dots and text hints (F, and by themselves after 45 s) carried it, and Ramon called the
  path system "just an idea". Noted for him in the handover.
- Handover: `follow_up/crosswise.md`; engine facts in `engine_capabilities.md`; memory.

## Pivots
(when a step hits a wall, or Ramon steers: what happened, and what replaced it)

1. **The look is the Creation Lab's** (Ramon, 6 Oct, mid-build: "take the general look and lighting
   from creatorlabs. maybe also add the 1 spotlight with adjustment dev panel"). The islands' light
   is now the lab's as it plays (the kit's bright room light under his saved creation_lab_tuning.cfg:
   sky fill x1.52, sun x0.66 at 64/25, exposure 1.05) with the lab's centre spot hung over the walker
   (2.69 x 3.26, 35.7 degree cone, 0.42 edge, 10.4 m reach, 0.3 falloff, 8.4 m up), and the floors
   are the lab's procedural grid (mid-grey 1 m tiles of five) instead of the dev textures. An artist
   dev panel on F1 (hud/mk_tuner.gd, after the lab's) tunes light, sun, spot, sky and camera live and
   saves to `crosswise_tuning.cfg`. Decision 6 (the sky says which view) is kept: the lab's sky,
   shifted toward violet when turned, with a slider for how far, and one to lift the sky toward
   Miegakure's pale mint if he wants it.
2. **Node4D has no `top_level`.** Nodes that should not follow the walker (the floor marks, the
   ghost outline) set their global position every frame instead; his body never turns, so their
   basis is theirs.
3. **The pattern on a surface follows the view.** A floor mapped by X and Z showed a smear along W
   once turned; the shader now lays grid and texture along X and the view's own depth axis.
4. **Links set after a node is in the tree are not seen by its _ready.** The game builds its nodes
   into a running tree, so the camera's target and the walker's camera were still empty when their
   _ready looked for them: the camera stood still and its turned slice sat at z 0, through the gate
   wall, with him nowhere in it. Both now find their links when first needed. Caught by looking at
   the frames (three "different" turned frames were the same picture).
5. **The destination is out of frame from a diorama camera.** At the follow framing the tower, 60 m
   on, is far above the top of the frame. So the scene opens on a wide shot down the whole chain of
   islands to the tower, held, then eased down onto the walker (any key cuts it short).
6. **The first platform is lab blue, the railings are walls between pylons** (Ramon, 6 Oct: "make it
   a blue platform with the white icons and explainer. then behind the wall the grey floor can stay.
   check out the blue walls at creatorlab"; "change fence parameters so the outside platform fences
   become more like walls between pilons. every once in a while a basic fence is fine"). The start
   platform's floor is the lab's code-blue grid (the teaching wall's swatch, laid flat) with its lanes
   in gentler tints and white seams, and the explainer painted on it in white like the lab's walls:
   "01 / CROSSWISE", the title, one line, and the controls row with key caps and the mouse. The
   railings are FenceGenerator4D with chunky 1.1 m pylons every 2.4 m and one solid beam between them;
   every fourth railing is the plain rail fence.
