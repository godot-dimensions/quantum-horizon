# Portal

Two scenes, built in that order, from the strategy paper in
`papers_forclaude/portal_4d_dual_contouring_strategy_for_claude.pdf`. Read
`PAPER_REVIEW.md` for what in that paper survived contact with this codebase
and `PORTAL_GAME_RESEARCH.md` for what Portal itself actually does.

The two current scenes are named for how the menu launches them: **Portal Test
1** (`portal_test_1.tscn`) is the wall you shoot openings through, **Portal Test
2** (`portal_test_2.tscn`) is the chamber of linked openings. One catalogue entry
in `ramon/Menu2.tscn` carries both, with a launch button each.

## `portal_test_1.tscn` — the shootable wall

A shooting-range room whose far wall is a grid of dual-contoured voxel chunks.
Shoot it anywhere, any number of times; overlapping cuts merge into one opening
and stay open. `NEXT_VERSION.md` is the design and the measurements; the short
version is 40.5 ms per chunk rebuild, 10,752 tetrahedra, four chunks touched per
shot.

## `portal_test_2.tscn` — the portal simulation

**The current scene.** A sealed room whose four walls take a portal **anywhere
you aim**, plus a white square of floor and ceiling on a shared footprint, and
one ledge you cannot reach without them.

An earlier version of this scene used fixed door-sized pads. That was wrong
about the thing it was trying to be: in Portal the aiming *is* the game, the
aperture is an **oval**, and shooting a colour that is already placed closes the
old one instantly while it animates shut. White surfaces accept portals, dark
ones refuse — Portal's own readability rule.

The rule it implements is Portal's, not an approximation of it: two linked
openings, and a traveller's **position, orientation and velocity** are carried
from the entry pad's local frame into the exit pad's with a half turn applied,
so speed is preserved and only its direction changes. `portal_link.gd` is the
only place that transform lives.

| Control | |
| --- | --- |
| left click | blue portal on the pad you are looking at |
| F | yellow portal |
| WASD / space | move, jump |
| right click + mouse | 4D slice rotation (unchanged from `player.gd`) |
| Q / E | move through w |

Four properties are verified by `_portal_shot.gd`, which renders as it goes:

1. **Walk through.** Enter one opening, arrive at the other still moving away
   from that wall. Getting the half turn wrong spits you back the way you came,
   which "did a teleport happen" would not catch.
2. **The endless fall.** The floor and ceiling pads share a footprint, so
   linking them drops you through a loop that keeps accelerating — measured
   7.7 → 22.2 m/s over five crossings. This is the proof that momentum survives.
3. **The ledge.** 3 m up against a 1.03 m jump, reachable only by arriving
   through the opening above it.
4. **Replacement.** Shooting a colour that is already placed seals its old
   opening at once and animates the oval shut, while the new one grows open.

### Design decisions worth keeping

- **The opening is a circle, 2.8 m across, and empty.** No coloured ring, no
  filled membrane. Portal marks its portals blue and orange and fills an
  unpaired one with solid colour; both were built and both were removed — the
  opening should read as a hole in the wall and nothing else.
- **The hole is cut as a disc**, approximated in 48 horizontal strips, and a
  40-segment collar lines the full depth of the bore. The collar is what makes
  it read as round from an angle rather than only head-on, since a strip
  decomposition always leaves a stepped edge.
- **Dual contouring was considered for that cut and rejected.** DC's strength
  is a smooth surface from a coarse grid for shapes with *no analytic form* —
  mined rock, terrain. A portal bore is a cylinder, which ring segments build
  exactly for nothing, where a DC patch would have cost ~130 ms per shot
  (grid 8 = 4,096 points, VoxelMining's measured figure), needed a fork of
  `VoxelField4D` and `DualContour4D` for anisotropic grids, and still could not
  animate. Collision would have stayed boxy regardless, since the physics
  engine only does axis-aligned boxes.
- **A portal aimed near the base of a wall snaps flush with the floor.** Not
  cosmetic: `CharacterBody4D` has no step-up, so an opening whose bottom edge
  sits 3 cm above the floor is an opening you cannot walk through. Valve solves
  the same class of problem with placement helpers; this is the
  one-dimensional version.
- **Surfaces are axis-aligned, always.** Portal 2's hardest problem was that
  "teleportation is almost never axis-aligned", forcing them to trace the
  player as a box on both sides at once. Our physics is axis-aligned-box-only
  anyway; keeping pads axis-aligned means that problem never arises.
- **An unpaired portal is a solid filled oval.** Valve's behaviour, and
  load-bearing here: the opening is a real hole through the wall, so a lone
  portal with no destination would be a hole into the void behind the room.
- **Openings are genuine holes**, not pictures of holes. Placing one rebuilds
  its surface as four boxes framing the gap; closing restores the single box.
  Never show an aperture over collision that behaves like a wall.
- **Arrivals are clearance-tested.** The exit preserves your offset from the
  entry opening, so a floor or ledge just behind the exit can land you inside
  it — and the axis-aligned engine has no depenetration (its own comment reads
  "just stop moving") with a safe margin of 1e-12, so a body overlapping by a
  centimetre is frozen permanently. Measured exactly that: a player arrived
  1.9 cm inside the ledge and never moved again. The link now probes with a
  test-only move and lifts until clear.

### What is deliberately not here

- **The look-through.** You cannot yet see the destination through an opening.
  That needs either the per-viewport engine change described in
  `PAPER_REVIEW.md` or the geometry-diorama approach; `_slice_viewport_probe.tscn`
  is the test that decides which.
- **Cross-slice endpoints.** Both pads currently live at the same w. The whole
  point of the exercise is a pair whose ends sit in different w bands; the
  frame maths already carries w through, so this is a placement question, not a
  new system.
- **Free placement**, cubes, pressure pads.

## `portal_chamber.tscn` — destructible voxel panels

Kept, not replaced. This was the first pass, and it answered a real question:
`VoxelMining`'s per-hit carve does survive room scale (4 panels, 1392
`BoxShape4D` colliders, ~512 ms build, ~130 ms per carve, ~58 fps). What it got
wrong was the mechanic — Portal never destroys a wall, so carving is the wrong
verb. The voxel work returns when apertures need a rounded, dual-contoured rim
rather than a rectangular hole.

## Tools

| File | What |
| --- | --- |
| `_portal_shot.gd` | drives the three portal behaviours and renders each; the main test |
| `_verify_chamber.gd` | headless structural check and carve timings for the voxel scene |
| `_carve_shot.gd` | renders a carved panel |
| `_slice_viewport_probe.tscn` | the two-slices-at-once test that gates the look-through |

Run with the editor **closed**:

```
engine/godot/bin/godot.windows.editor.double.x86_64.console.exe --path project \
    --script res://ramon/Portal/_portal_shot.gd
```

## Two lessons that cost time here

- **Bound simulation tests by physics frames, not render frames.** Counting
  rendered frames made `_portal_shot.gd` report 6 crossings on one run and 1 on
  the next from identical code, purely because frame pacing changed how many
  physics steps fitted inside the window. `Engine.get_physics_frames()` made it
  deterministic across three consecutive runs.
- **You cannot drive this player by assigning `linear_velocity`.** On the
  ground the controller sets horizontal velocity from input every frame, so an
  injected 6 m/s decays to zero in two frames. Tests press the real action with
  `Input.action_press` instead. This is also why `portal_player_4d.gd` exists:
  a scene-local fork that keeps horizontal momentum while airborne, without
  which a fling is erased on the frame after it starts.

Related: [[project_engine_gotchas]], [[project_hub_demo_lessons]]
