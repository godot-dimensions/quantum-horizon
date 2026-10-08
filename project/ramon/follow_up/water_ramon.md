# Water (Ramon's version): plan and handover (8 Oct 2026)

Ramon's fork of Trym's 4D water test (`sandbox/water4d/water4d_test.tscn`, from his `water-annex`
branch), as `res://ramon/Water/water4d_test_ramon.tscn`. A scene of its own that you come into from
the Arboretum: a kit door in a sea wall, two piers over Trym's 4D sea, his plesiosaur and his depth
pole, the lab's blue panels, the newest path system, and a HUD you can read, with a light and
environment mode.

## Questions for Ramon

(Each settled the most reversible way; the run went on.)

1. **The way in from the Arboretum.** The scene stands on its own: you arrive at the sea wall's
   door as if you had just come out of the Arboretum, but no door in the Arboretum leads here yet.
   Which Arboretum (yours, or Trym's water copy), and which wall? Should walking back in through the
   sea wall take you to the Arboretum?
2. **A menu entry?** None added (the catalogue is shared).
3. **Trym's plesiosaur: its seams are frozen here.** His swimmer re-bends the seam patches between
   its 13 pieces every physics tick, about 6 ms each time (it made 1 frame in 20 take 8 ms; Trym's
   own annex has the same hitch). With `blend_joints` off the slow frames are gone; deep under the
   water the seams do not show. Worth telling Trym.
4. **Waves against the decks.** Wave scale 0.8 and decks 2.2 m over the still water: a storm (3) or
   sharp crests (7) can lap over a deck. Both numbers are settings on the root node, and the wave
   scale is in the light mode (WATER).
5. **The pages on the floor** read best looking down (the camera's pitch). Should standing on the
   platform tilt the camera down for you?

## The brief (8 Oct, his words condensed)

- A copy of Trym's water test named with `_ramon` behind it; the HUD on a dark see-through backing,
  bigger type; a HUD mode for every light and environment property.
- Trym's plesiosaur, his pier and his "weird pole" (the depth pillar), the pier floating just above
  the sea; a door opening in the kit's style, which is where you arrive from the Arboretum.
- The lab's dynamic blue wall panels; the newest path system (the playable world's).
- Pier 1: from the door straight out, a left turn for a few metres, then a much bigger round
  platform with the blue panels. On it you turn the slice of the sea, but the platform itself does
  not turn: it stays set.
- Pier 2 (P teleports there, also from a door): wider; its last 30% (about 5 x 10 m) holds an
  information panel saying that on the circle you turn the slice of the water, and here the pier
  turns with it. A flat panel may not survive the turn: hide it, or stand in a box with its
  picture on it.

## Strategy in brief

- **Carry, don't reach.** Trym's water, plesiosaur and foam are not on our branch (only on his
  `water-annex`), and the pen's scripts are not to be touched: everything the scene needs is copied
  into `Water/carried/` with a README, so the scene stands on its own and can be committed.
- **Pier 1's "set" platform** is drawn in a frame that turns WITH the slice (the rig's own xw and zw
  angles, about the platform's centre), so it reads as fixed while the sea is re-cut; its collision
  stays square to the world, deep in W; a round invisible rail in code (the physics is box-only).
- **Pier 2 turns with the slice** like any world geometry. Its panel stands on the kit's own blue
  slab, 8 m deep in W, made deeper by its holder, so the printed page survives a turn; past the angle
  where it cannot, it hides.

## The 40 steps

### A. Ground (1-8)
1. Read Trym's water test, pool room, annex ring and plesiosaur; note what each depends on.
2. Find the newest path system (done: `CreationLab/PathCreator`, which the pen loads directly).
3. Check the kit has not moved since the Arboretum carried it (done: unchanged).
4. List the light and environment properties the engine exposes (done: `_props_runner.gd`).
5. Carry Trym's water (surface, presets, shader, foam include, plesiosaur scene and scripts) and the
   pen's loft rig scripts the plesiosaur needs into `Water/carried/`, paths rewritten, no `.uid`s.
6. Carry the kit, LabKit and build scripts (from the Arboretum's copy, with its fixes) and the
   newest PathCreator (from the Creation Lab) into `Water/carried/`.
7. `Water/carried/README.md`: every source, commit and change.
8. Parse-check everything carried before the first Godot run.

### B. The scene (9-16)
9. `water4d_test_ramon.tscn`: Trym's sky, clouds, sun and water as he set them, and the root.
10. The sea wall: a kit room on the shore with two doorways, one per pier.
11. The player: the kit's walker at door 1, facing the sea; slice turning off by default.
12. Pier 1's straight run and its left turn, decks on the kit's grid, Trym's fence railing.
13. Pier 1's round platform, lofted as a 4D disc (round in x, z and W), its rail and its gap.
14. Pier 2: wider, longer, its circle in the last 10 m and its railing.
15. The pole: Trym's banded pillar, floor to above the water, beside pier 1's turn.
16. The sea floor at 35 m (so the depth fade has something to read), and the plesiosaur under pier 1.

### C. Slicing (17-22)
17. Where you stand: on the platform, on pier 2's circle, or neither (polled, not an Area4D).
18. The rig's slice turning lent while on either, taken back with its trip home when you leave.
19. The set frame: the platform's holder turned by the rig's angles about its centre every frame.
20. The platform's round rail in code, and the trip home before you reach its edge.
21. Pier 2's panel holder deep in W, hidden past the angle its slab can carry.
22. P: between door 1 and door 2, the slice levelled on the way.

### D. Panels and paths (23-28)
23. A panel source with live numbers from the sea (preset, waves, wavelength, height, off-W, slice).
24. Pier 1's pair: introduction and research ("steps": the waves, the slice solve, the foam), on the
    platform, facing the way in.
25. Pier 2's single introduction: the circle, what turns, the keys.
26. The path graphs (door to platform, door to circle), written by a runner.
27. The path networks on the decks, targets at the platform and the circle.
28. Their states: arrival, focused, completed as you go.

### E. The HUD (29-33)
29. The readout forked: dark see-through backing, larger type, the walking controls.
30. Tab: readout, light and environment, hidden.
31. The editor: SUN (colour, energy, size, height, turn, through W), ENVIRONMENT, SKY, CLOUDS (every
    property the engine lists), WATER (its look), built from the engine's own property lists.
32. SAVE and load (`Water/water_ramon_tuning.cfg`), and RESET to the scene's own values.
33. The mouse freed in the editor, given back after.

### F. Proof (34-40)
34. Parse-check, then open the scene headless: it builds, nothing errors.
35. Frames: the door, the pier, the turn, the platform, the panels, pier 2, its circle, the pole.
36. Frames with the slice turned on the platform (it stays set) and on pier 2's circle (it turns,
    its panel survives or hides).
37. A play-through by keys: P, Tab, the editor's controls, 1-8, F, G, N.
38. Frame cost at the door, on the platform, on pier 2.
39. This handover: what is where, what to look at, questions.
40. Commit by explicit paths, `Water/` and this file; nothing pushed.

## Status

**Done, 8 Oct 2026, and seen working in frames.** All 40 steps ran. What to look at:

1. **Play it:** open `res://ramon/Water/water4d_test_ramon.tscn` and press F6. You stand in the sea
   wall's door 1. Walk out along pier 1, round its left turn, onto the blue platform: the two pages
   lie on its floor. Right-drag on the platform: the sea is cut a new way, the platform stays set.
   R levels the slice. P takes you to door 2 and pier 2: walk to its circle, right-drag, and the
   pier turns with the slice. Tab: the light and environment mode, Tab again hides the HUD.
2. **Frames:** `project/smoke_test_output/water_ramon/` (`05` and `07`: the platform level and
   turned 60 degrees; `13` to `16`: pier 2's circle level to 70 degrees; `4k_*`: the HUD at
   3840 x 2160).

**Measured** (`scripts/_capture_runner.gd perf`, vsync off): the door, the platform and pier 2's
circle all 1.5 to 1.6 ms a frame at the median, 1.7 to 2.0 ms at the 95th percentile, 1.2 to 1.5 ms
of GPU. The scene opens in 1.7 s.

**Not checked by a runner:** the right drag itself (the runner turns the slice by setting the rig's
angles, as the drag does); the sliders of the light mode one by one (built from the engine's own
lists, opened and shown, SAVE and RESET not pressed).

**Changed on the way:**
- The platform's panels first stood upright at its back, like walls; Ramon: on the floor, and the
  platform blue. The kit's panels still draw the pages (out of sight under the water); the pages
  are printed onto blue plates on the deck. Pier 2's end is the same: a blue floor with the circle
  and its page.
- Pier 2's railing read as solid walls: the fence's subdivision put a rib exactly at W 0 (a rib
  along a pier is a wall the pier's length). Every railing now splits W in thirds, so no rib lands
  at 0, with three thin beam lines (Ramon); the platform's round rail is the same fence on a
  32-sided ring.
- Trym's plesiosaur's joint blending is off (question 3).

### What is where

| Path (under `project/ramon/Water/`) | What it is |
|---|---|
| `water4d_test_ramon.tscn` | The scene: Trym's sky, clouds, sun and water, the root, the path networks and targets |
| `water4d_test_ramon_4d.gd` | The root: the sea wall, both piers, the set platform, the pole, the floor, the plesiosaur, the player, the slicing, P and the water keys |
| `water4d_hud_ramon.gd` | The HUD: the readout on a dark backing, the light and environment mode, SAVE (`water_ramon_tuning.cfg`) and RESET |
| `water_panel_source.gd`, `water_info.tres`, `pier2_info.tres` | The pages' live numbers and words |
| `water_target_4d.gd`, `paths/` | The routes' targets and graphs (`scripts/_make_paths_runner.gd` writes the graphs) |
| `carried/` | Trym's water and plesiosaur, the pen's loft rig, the kit, the newest PathCreator; `carried/README.md` |
| `scripts/` | `_capture_runner.gd` (frames; `hud4k`; `perf`), `_make_paths_runner.gd`, `_props_runner.gd` |
