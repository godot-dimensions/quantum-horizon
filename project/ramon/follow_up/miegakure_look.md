# MiegakureLook — where we left off

`project/ramon/MiegakureLook/` (started 2026-08-18). A camera-and-avatar feel
test for a Miegakure-style 4D chamber, built after the earlier "Impossible
Bypass" prototype felt too much like a first-person PhaseMaze corridor.

There are now **two generations side by side**. v1 (`miegakure_look.tscn`) is
the continuous free-slicing look test. v2 (`miegakure_look_2.tscn`, built
2026-08-19, and the project's current `run/main_scene`) is a rework against
the technical paper at `D:\depot\papers_forclaude\miegakure_claude_technical_paper.pdf`,
and adds an actual puzzle. **The whole folder is still untracked in git.**

## v1 — the look test

- `miegakure_look.tscn` — a single bounded floating platform, Aaron's real
  environment/sun setup copied verbatim from `Demo/hub1.tscn` (same
  `GradientSkyMaterial4D` values, same `DirectionalLight4D` + `hub_sun_4d.gd`),
  an orange 600-cell ball, a fixed camera rig.
- `scripts/ball_controller.gd` — the ball NEVER rotates (basis stays identity
  forever). Camera-relative WASD via `_flat_camera_basis()`, because a
  world-relative WASD drifts out of alignment with the screen as the camera
  slices (reported directly as controls "tangling").
- `scripts/miegakure_camera.gd` — all slice-rotation control lives here, not on
  the ball. Mouse motion accumulates a `_slice_rotation` (xw/zw planes)
  composed with a fixed diorama tilt (~61° pitch, 45° yaw "diamond" approach,
  ~30° FOV, 14 m back). `Ball never rotates + camera does all the rotating` is
  deliberate: `Camera4D`'s own `global_basis` is what defines the rendered
  cross-section, so this is what makes the WORLD visibly deform while the
  ball/camera framing stays anchored.
- `scripts/miegakure_look_builder.gd` — one 16×16×1.5 m platform plus two small
  props. Real PBR materials (no `FlatShadingRamon` unshaded trick), since the
  point is checking dev textures under Aaron's actual lighting.

### Three real bugs fixed in v1 — don't reintroduce them

1. **`Camera4D.rendering_engine_name`, not `rendering_engine`.** A brand-new
   `Camera4D` silently defaults to wireframe if this isn't set, and the wrong
   property name is silently dropped by Godot's scene loader instead of
   erroring. `engine_gotchas.md` itself had this wrong until 2026-08-18.
2. **The ball must never disappear as the camera rotates.** Position has to be
   derived from the SAME basis used for orientation —
   `ball.global_position + global_basis * Vector4(0, 0, DISTANCE, 0)` — not a
   constant world-space offset held separately from a rotating orientation.
   Because `_local_look_basis.z` and `.w` are orthogonal by construction, this
   keeps the ball at exactly local-w=0 regardless of composition order.
3. **Composition order of tilt vs. slice rotation matters.**
   `slice_rotation * tilt` (rotate around the WORLD's xw/zw planes first, tilt
   on top) reads as a clean slice change. `tilt * slice_rotation` scrambles it
   into what looks like the whole scene tumbling, because the steep diagonal
   tilt doesn't commute with axis-aligned rotations.

Both fixes 2 and 3 are carried into v2 unchanged and still needed.

## v2 — discrete rotation plus the "Wall Around the Fourth" puzzle

- `miegakure_camera_2.gd` — free 2-DOF mouse slicing replaced by a single
  toggled 90° `zw` rotation on `rotate_4d` (**right mouse button**, per
  `project.godot`), smoothstep-eased over 0.7 s, with `is_transitioning()`
  locking movement input mid-rotation. Mouse capture removed entirely. Lens
  narrowed to a ~120 mm telephoto feel (19° FOV, 21.5 m back, roughly
  preserving `DISTANCE * tan(FOV/2)`).
- `ball_controller_2.gd` — camera-relative movement now keeps the full x/z/w
  mix of the camera basis (only y dropped), so the *same* forward key produces
  w-motion after rotating. Not a separate w-translation control.
- `miegakure_look_builder_2.gd` — a wall solid across the whole platform at
  every w except a 3 m window at `w = -6`, plus a red goal pad past it and a
  black-metal landmark. `STRUCTURE_W_HALF_EXTENT = 8` so the platform's w
  extent matches its x/z extent, fixing a real artifact where a w=24 platform
  visibly *expanded* from 16-wide to 24-wide mid-rotation.
- `w_readout_2.gd` — vertical w-gauge with the gap window drawn in the wall's
  own yellow and the ball in its own orange, plus a `Z-SLICE` / `W-SLICE` /
  `ROTATING…` mode label.
- `goal_banner_2.gd` — "GOAL REACHED" overlay; the goal used to only print to
  the console.

`GATE_GAP_W` is negative because `Basis4D::from_zw`'s generated matrix
(`basis.z.w = sin`, `basis.w.z = -sin`) sends the camera's z-column toward +w
at +90°, and forward is the *negation* of that column — so walking forward
after rotating moves toward −w. Traced in `basis_4d.cpp`, not assumed.

## v2 does not actually work in play. Measured 2026-08-19.

Two probes were written to check this with a real rendering device rather than
headless (`--headless` never creates one, so nothing is drawn and no visual
claim can be checked — same reason `Demo/_screenshot.gd` exists):

- `_visual_probe_2.gd` — plays the whole puzzle through the real input path and
  screenshots each beat.
- `_movement_probe_2.gd` — measures what each key actually does to the 4D
  position at both slice angles, and whether the wall can be seen from the
  rotated view.

Note on driving input from a `SceneTree` script: the rotation is an
**event**-based action (`_input` + `is_action_pressed`) so it needs
`Input.parse_input_event()` with a real `InputEventMouseButton`;
`Input.action_press()` alone never reaches `_input`. Movement is **polled**
(`Input.get_axis` in `_physics_process`) so for that `action_press` is correct.
Getting those backwards looks exactly like broken rotation input. Also,
`parse_input_event` is delivered a frame late, so "not `is_transitioning()`" is
true *before* the transition starts too — gate on the angle actually arriving,
or screenshots get labelled with the wrong slice state.

### 1. Plain "forward" is a 45° world diagonal, and it walks you off the map

Measured displacement directions:

| slice | keys | resulting direction |
|---|---|---|
| θ=0 | W | x −0.71, z −0.71 |
| θ=0 | W+D | z −1.00 (pure) |
| θ=90 | W | x −0.71, w −0.71 |
| θ=90 | W+D | w −1.00 (pure) |
| θ=90 | W+A | x −1.00 (pure) |

This is *correct* camera-relative movement — the camera carries a 45° yaw, so
screen-forward is a world diagonal — but the level is axis-aligned, so the two
disagree. Consequences, both observed:

- At θ=0, holding forward into the wall slides the ball along x until it
  reaches `x = -8.20`, i.e. off the 16 m platform's edge (it stays
  `is_on_floor()` there because physics is AABB-only — see
  `hub_demo_lessons.md`).
- At θ=90, holding forward from there moves in −x as much as −w, so the ball
  leaves the platform and free-falls: measured `y = -1.21` after 0.8 s,
  `y = -25.23` after 2.5 s, and still falling at `y = -109` by the end of the
  run. There is no fall bound, death plane or respawn, so the run never
  terminates and never reaches the goal.

**The paper's own acceptance test therefore does not pass today.** Reaching the
gap requires holding W+D, which nothing teaches or hints at.

### 2. At θ=90 there is nothing on screen but floor

The rendered slice at θ=90 is a constant-*z* hyperplane through the ball. The
wall lives at z ∈ [−0.2, +0.2] and collision stops the ball at z = +0.70, so
**the wall is never in the slice you rotate into**. Screenshot
`move_a_theta90_at_wall_face.png` is a bare grey diamond: no wall, no gap, no
goal, no landmark. The player is asked to walk to a specific w with zero
on-screen information.

`move_b_theta90_at_wall_centre.png` (ball teleported to z=0, which collision
forbids) shows what the *readable* version would look like — the wall's x–w
cross-section fills the floor with the gap legible as a grey lane through it.
That view is unreachable in play.

This is worth being careful about: the wall vanishing is **authentic** to
Miegakure, not a bug. miegakure.com's FAQ says of translation "you cannot see
where you are going, so you can hit walls you can't see, which is confusing" —
and this build reproduces that confusion inside the *rotation* mechanic, by
authoring the obstacle thin along the axis that becomes hidden. What's missing
is the compensating affordance Marc actually uses, which is the ground:
"to help players understand the game we texture the ground differently at
intervals, to group parallel worlds together". The floor is the one surface
present in *every* slice, so it is the only reliable place to show w. This
build's floor is uniform grey.

### 3. The stable-reference landmark disappears exactly when it's needed

`LANDMARK_FOOTPRINT` is 1.0 in x **and z**, with w extent 16. At θ=90 the slice
is at the ball's z, so a landmark 1 m deep in z is absent from it — confirmed,
no landmark in `move_a`. The paper's own rule is that a landmark must lie on
the plane the rotation doesn't touch; for a zw rotation that is x–y, so a
landmark has to span the full range of **both** z and w to survive. The same
"match the extents" fix that cured the platform's expansion artifact was never
applied here.

### 4. The goal pad balloons during rotation

The pad is 3 m in z but 16 m in w, so an oblique slice sweeps between two very
differently sized cross-sections and it visibly grows — plainly seen in
`probe_2_mid_rotation.png`. Same class of artifact the platform's
`STRUCTURE_W_HALF_EXTENT` fix solved; the pad and the landmark were missed.

### 5. `w_readout_2.gd` has never rendered

It fails to parse: `Identifier "MiegakureLookBuilder2" not declared in the
current scope`, three times, so the node gets no script and the whole gauge is
absent. Cause is the global class cache, not the code — see the new entry in
`engine_gotchas.md`. So the one affordance that *would* have made the w-gap
navigable has been dead the whole time, which is very likely why the puzzle
felt unreadable.

### 6. Framing wastes most of the frame

At 19° FOV and 21.5 m the platform occupies roughly the upper-middle third and
the rest is flat void. Marc's art-direction post argues the opposite way for
dioramas — he explicitly does *not* want "very large flat section of colors",
and notes that if a diorama doesn't "fill a large area" there isn't "enough
interesting stuff to look at". The current frame is a large flat grey slab in a
large flat purple void. The purple is `GradientSkyMaterial4D`'s
`bottom_color`, which is all a steeply-downward camera ever sees.

## Reading the technical paper sceptically

Verified against the first-party sources it cites. Its own DOCUMENTED /
INFERRED / PROPOSED labels are honest and mostly accurate.

**Holds up (checked against source):**
- 90° swap, smoothly interpolated; gravity kept off the swapped axis; X left
  alone ("It would not be interesting enough to let players swap in the X
  direction"). Small levels, "4x4x7x4 for example". W-distance colour coding
  rejected as "unnecessarily difficult to visually parse". Two dimensions stay
  common so objects on that plane are reference points. Player is 3D with "a
  tiny amount of 4D width". Slicing rather than projection, and why.
- Its axis convention is Marc's, where **Z is vertical**. v2's decision to
  rotate zw rather than yw is the correct adaptation to this project's Y-up
  convention — rotating our vertical y into w would tip gravity into the fourth
  dimension. Getting this wrong would have been the single most expensive
  mistake available.

**Reject for this repo — §7/§8, the architecture.** "Do not make Godot itself
4D. Keep the 4D math authoritative and feed ordinary 3D meshes/collision to the
engine", with `Level4D` / `SliceFrame4D` / `SliceMeshBuilder` / `CharacterBody3D`
+ logical `Vector4` position, and 3D collision rebuilt from the slice each
frame. That describes a Godot **3D** game with a 4D layer bolted on. This repo
is the opposite shape: `engine/modules/4d` already provides `Node4D`,
`Camera4D`, `CharacterBody4D`, `PhysicsServer4D` and `TetraMesh4D` with
cross-section rendering in the shader, and physics is genuinely 4D. Adopting
§7/§8 means deleting the engine module's job and reimplementing tetrahedron
slicing in GDScript. In particular the "rebuild 3D collision from the slice
every frame" step is not merely unnecessary here, it would be wrong — 4D
collision is independent of the camera, which is exactly why the ball can walk
along w without the platform's collider ever changing.

This is the **same** systematic error `Portal/PAPER_REVIEW.md` found in the
Portal paper from the same source ("Everything else in the paper assumes a
Godot 3D game with 4D content bolted on… This project is the opposite shape").
Treat the architecture sections of any future paper from this source as
written for a different codebase until proven otherwise; the design and
maths sections have been reliable.

**Unverifiable claims, flagged:**
- §3's camera numbers (yaw ~45, pitch 40–45, "ortho OR FOV 25–35") are
  self-labelled visual inferences. Fine.
- But `miegakure_camera_2.gd`'s own header asserts "miegakure.com's own text …
  says the real camera is an ordinary third-person PERSPECTIVE camera, not
  orthographic". **That is not on miegakure.com** — the site says nothing about
  camera type or projection. The perspective choice is fine on its merits;
  the citation is not, and should be softened rather than relied on.
- §5/§6's art guidance ("keep high-frequency detail low", "prefer broad
  material masses") is half of what the source says. Marc warns against *tiny*
  detail that strobes through the slice **and** against large flat colour
  regions. Only the first half was taken, and the result is the framing problem
  in finding 6.

**Its §9 checklist item 10** (basis gizmos, current W, theta, hidden normal,
colour-coded cut geometry, toggleable) is the item that would most directly fix
findings 1–3, and in v2 it was also the one item silently broken (finding 5).
Partly met as of v3 — the gauge now draws; the gizmos do not exist yet.

## v3 — the three fixes, verified in play 2026-08-19

`miegakure_look_3.tscn` plus a `_3` script set. The level geometry is the same
design as v2, unchanged numbers and all; only the three fixes below differ. v2
is left intact for comparison. Findings 4 and 6 above (the goal pad's z/w
mismatch, the landmark's 1 m z depth, the framing) are deliberately still
present in v3 — they were not part of the three.

1. **Movement decoupled from the camera.** `ball_controller_3.gd` builds its
   movement basis from the **slice angle** (`_slice_movement_basis`), not from
   the camera basis: strafe is always world x — the axis the zw rotation never
   touches, i.e. the paper's "X remains X" — and forward/back is the axis the
   rotation swaps, world −z at θ=0 and world −w at θ=90. Measured: `x = +0.000`
   after walking forward at *both* angles, with `YAW_DEGREES` at 45.

   Worth recording that this was got wrong first. The initial v3 set
   `YAW_DEGREES = 0`, which does fix the movement bug — a yaw of 0 makes the
   y-dropped camera basis axis-aligned — but it throws away the
   screenshot-derived diamond framing to do it, and Ramon spotted the regression
   immediately. That was a false either/or: the camera's yaw and the movement
   axes only have to agree while movement is *derived from* the camera. Once it
   isn't, `PITCH_DEGREES`, `YAW_DEGREES`, `DISTANCE` and
   `FIELD_OF_VIEW_DEGREES` are pure framing choices with **no gameplay
   consequence** — which is the arrangement that should have been reached
   directly.

   The one real trade left: at 45° the world's horizontal axes project onto the
   two diamond diagonals, so W runs along a platform edge rather than straight
   up the screen. Ordinary isometric convention, and WASD lands on the four
   visible platform edges, but it is a choice. `YAW_DEGREES = 0` gives
   screen-aligned controls back and nothing else needs to change either way.
2. **Fall bound** in `ball_controller_3.gd`: below `y = -12` the ball returns to
   its spawn with all four velocity components cleared. Respawns at the original
   spawn rather than the last grounded position, because the last grounded
   position is by definition next to the edge you just fell off. The slice
   rotation is deliberately *not* reset — a fall silently undoing the player's
   rotation reads as the rotate button having failed.
3. **HUD loads.** `w_readout_3.gd` reads the three level numbers off the builder
   *node* via getter methods instead of naming the builder script's `class_name`
   at parse time, so it cannot break that way again and survives the builder
   being renamed. No `class_name` on any `_3` script; these are scene-local, and
   CLAUDE.md only asks for `class_name` on reusable utilities anyway. Cameras
   and builders are typed as their engine base classes and called through, which
   is the same unsafe-call pattern `miegakure_look_builder_2.gd` already used for
   its `goal_banner: Control`.

`_visual_probe_3.gd` runs the whole puzzle with **one key at a time** and asserts
all of it: 10 checks, 0 failures, no errors or warnings — blocked at the wall at
z=+0.70, into the gap at w=−5.67 without leaving the floor, past the wall after
rotating back, goal banner shown, and a deliberate walk off the edge respawning
correctly.

One layout bug surfaced only because the gauge finally draws: v2's `+W` cap was
on the same line as the mode label, wide enough that "W-SLICE" ran underneath it
and rendered as "W-SWCE". Fixed by pushing the bar 26 px below the label instead
of 6.

## Level 2 — "The Bridge in Another World" (`miegakure_look_4.tscn`)

Built 2026-08-19 as the second level, and chosen over another wall specifically
because it dissolves finding 2 rather than working around it.

A chasm cuts the platform across its full x width. At most w it is genuinely
open and walking in drops you; in one 2 m band of w the floor runs straight
across. Walk to the lip, rotate, walk along w into the bridge band, rotate back,
cross ground that was not there before.

**Why this shape of puzzle is better.** In the wall level the obstacle is thin
along z, so at θ=90 it is never in the slice and the screen is bare floor. Here
the puzzle-relevant geometry *is* floor, and the floor is the one surface present
in every slice at every angle — so after rotating you are looking straight at the
thing you have to navigate. Confirmed visually:
`v4_2_rotated_bands_visible.png` shows eight countable lanes with the cyan bridge
two lanes over, versus `move_a_theta90_at_wall_face.png`'s empty grey diamond.

- **Floor banding** — 8 slabs of 2 m along w, alternating grey/white, bridge band
  cyan. Built as separate slabs rather than one clever texture, because a
  `BoxTetraMesh4D` carries a fixed per-cell UVW unwrap and smears a single image
  across whole cells (`hub_demo_lessons.md`). Light colours throughout on
  purpose: the chasm reads as a hole by showing the dark void through it, and
  dark bands would compete with that.
- **Rails** at x = ±7 spanning the full z *and* full w — the stable reference done
  properly this time (finding 3's landmark was 1 m deep in z and vanished at
  θ=90). They double as the x-axis fall guard, so the chasm is the only way to
  fall, i.e. the only fall is the puzzle.
- **Goal** square in z and w (3×3) inside the bridge band, avoiding finding 4's
  ballooning and making the goal a place in 4D rather than a stripe across it.
- **The gauge is shared, not copied.** `w_readout_3.gd` serves both levels
  unchanged: it asks the builder node for the w extent, the highlighted band and
  now its colour, so the wall level highlights its gap in the wall's yellow and
  this one highlights the bridge in the bridge's cyan. That is the getter pattern
  from v3 fix 3 paying off. `miegakure_look_builder_3.gd` gained a
  `get_gap_color()` to match; nothing else about the wall level changed.
- Camera, ball controller and banner are **reused from the `_3` set**, not copied.
  They are level-agnostic now that framing and movement are decoupled. Worth
  knowing: tuning `miegakure_camera_3.gd` therefore affects both scenes.

`_visual_probe_4.gd` asserts the whole route — 12 checks, 0 failures — including
the negative case, which matters as much as the positive one: rotating back in
the *wrong* band and walking forward must drop the ball into the chasm (measured
y = −2.70) and the fall bound must recover it.

**Known tuning knob:** the bridge band's saturated cyan fills most of the frame
at θ=0 (`v4_4_bridge_exists.png`), which is precisely the "very large flat
section of colors" Marc argues against. It is doing real teaching work at θ=90,
so the fix is a more desaturated tint rather than dropping it — legible as a lane
from the rotated view without dominating the crossing.

## The three levels — `levels/`, built 2026-08-19

`MiegakureLook/levels/` holds the actual game now; the older
`miegakure_look_2/3/4.tscn` are superseded one-offs kept for comparison (they
still run standalone and simply never advance).

| # | Scene | Obstacle | Teaches |
|---|---|---|---|
| 1 | `level_1_wall.tscn` | Wall, gapped in the yellow lane | The move, with a safe failure — the wall just stops you |
| 2 | `level_2_bridge.tscn` | Chasm, bridged in the cyan lane | The same move with a consequence: the floor is a 4D object |
| 3 | `level_3_detour.tscn` | Both, gap at w −5 and bridge at w +5 | A *route* through w — the second leg runs the other way |

All three extend `scripts/miegakure_level_base.gd` rather than copying geometry
code, and all three share the camera, ball controller, banner and gauge from the
`_3` set. Level 3 is the one that stops w being a switch: the lane that solved
the wall is the wrong answer for the chasm, and the return leg is 10 m the other
way, so you have to travel back through lanes you already visited.

**The banding is what makes any of this legible** and it is why every level is
built out of bands. The rendered slice at θ=90 is a constant-z hyperplane, so a
wall thin along z is simply absent from the view you rotate into — the original
wall level's rotated view was a bare grey diamond. The floor is the one surface
in every slice at every angle, so colouring it in lanes is the only reliable
place to show w. Lanes are separate slabs, not one banded texture, because a
`BoxTetraMesh4D` carries a fixed per-cell UVW unwrap and smears a single image
across whole cells.

### Level progression — and the omission that needed fixing

The three levels were first built with **no way to get from one to the next**:
the goal banner drew its text and the game sat there. Reported exactly as "after
completing level 1, level 2 doesn't start", which is what it did.

`scripts/level_flow.gd` now owns the order in one place — a `LEVELS` array plus
static lookups, referenced by `preload` rather than `class_name` so it needs no
editor rescan. Adding a level 4 is one line there and nothing else knows the
order. On goal the base builder shows "LEVEL n OF 3 NEXT…", holds 1.8 s so the
banner is readable, then changes scene.

**The transition must not happen straight from the goal signal.**
`body_entered_self` fires inside the physics step, and changing scene frees the
current scene immediately — including the `Area4D` running the callback and the
body the solver is still iterating. `hub_demo_lessons.md` already records that
crash from the hub gates. A `SceneTreeTimer`'s timeout lands on an idle frame, so
the 1.8 s hold doubles as the deferral.

Two traps worth keeping, both cost time here:

- **`scene_file_path` is only set on a scene's ROOT node**, not on children, so
  the builder reads `get_tree().current_scene.scene_file_path` to find out which
  level it is.
- **In a `SceneTree` probe script, returning `true` from `_process` quits the
  tree.** The probe's end-of-route branch did that unconditionally, so the
  harness exited before the level's own 1.8 s timer could fire — which looked
  precisely like the transition being broken, with no error and exit code 0. If
  a transition ever "silently does nothing" again, check the harness before the
  game.

`_visual_probe_levels.gd -- <n>` plays a level end to end, one key at a time, and
asserts the hand-off actually happened and that the next level built its own
geometry — not merely that the banner appeared. 6 / 6 / 5 checks, 0 failures.

## What to pick up next, in priority order

1. **Backport the floor banding to the wall level**, or retire that level in
   favour of this one. It is currently the only level where the rotated view
   carries no information. Marc's own readability device, and the only one
   that works from inside every slice. This replaces "walk blind toward a
   number on a gauge" with "walk down the visibly different lane".
2. **Desaturate the bridge band** (see the tuning knob above).
3. **Match z and w extents on the wall level's goal pad and landmark**, as its
   platform and level 2's goal already do.
4. Revisit framing (`FIELD_OF_VIEW_DEGREES`, `DISTANCE`, `PITCH_DEGREES` 61,
   `MOUSE_SENSITIVITY` on v1) — level 2 fills the frame far better than the wall
   level did, so this is now a tuning pass rather than a fix.
7. Skybox/cloudy-void backdrop still deferred; `SkyBoxClouds` is the natural
   fit.

Prior art worth mining for the gizmo work, since it is the closest thing to a
solved version of finding 2: **4D Toys v1.8** draws "three colored lines
[that] represent the three horizontal dimensions", with the white one visible
only once you have traded a normal horizontal for w — and supports both 90°
increments and free rotation, noting "axis-aligned rotations are the easiest to
understand". **4D Golf** (CodeParade, 2024) ships toggleable visualization
layers, buttons that jump you to the ball or the hole, and a "volumetric mode"
showing x/z/w with y omitted so the ground reads as a solid volume — which is
almost exactly the view `move_b` accidentally produced.

Related: [[project_engine_gotchas]], [[project_phase_maze]],
[[project_hub_demo_lessons]]
