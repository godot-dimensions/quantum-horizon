# Portal paper: reconnaissance and critical review

Review of `papers_forclaude/portal_4d_dual_contouring_strategy_for_claude.pdf`
("Portal-like 4D dual-contouring voxel game", Chamber 01: The Split Bridge,
18 August 2026), written 2026-08-19 before any Portal code exists.

The paper explicitly asks for an evidence inventory first, and to treat the
repository as the authority. This file is that inventory. Three of its
assumptions were checked directly in engine source; all three are wrong for
*this* codebase, and two of them are load-bearing.

## The idea is good. The architecture is written for a different codebase.

The thesis worth proving: **a paired aperture links not two positions but two
slice states — you see slice B framed inside slice A, and stepping through
moves you.** That is genuinely new here. Nothing in `PhaseMaze`,
`ImpossibleBypass` or `Demo/hub1` shows two slices at once; they show one
slice at a time and let you rotate/translate between them.

Everything else in the paper assumes a Godot **3D** game with 4D content
bolted on: `CharacterBody3D` player, main `Camera3D`, `RigidBody3D` cube,
"static concave collider per derived 3D chunk", `SubViewport` + mapped
`Camera3D` for the portal view. This project is the opposite shape — a 4D
game whose 3D output exists only inside the renderer. `CharacterBody4D`,
`PhysicsServer4D` and `Camera4D` are the real classes; there is no derived-3D
physics world to attach a `CharacterBody3D` to.

Naming, for the record: the mesh class is `ArrayTetraMesh4D`/`TetraMesh4D`,
not `ArrayPolyMesh4D`.

## Refutation 1 — the portal view cannot be rendered today (blocker)

The paper's core rendering plan is a `SubViewport` whose camera shows the
*destination* slice while the main viewport shows the current one. Checked in
`engine/modules/4d/render/`:

- One `RenderingEngine4D` instance exists **per engine name**, shared by every
  viewport (`rendering_server_4d.cpp:328`, `:350`).
- That single instance owns one `_cross_section_world_3d` and one
  `_cross_section_camera` RID, and hands the same `World3D` to every viewport
  it is set up for (`cross_section_rendering_engine_4d.cpp:226-238`).
- The slice itself is pushed as **per-instance shader parameters**
  (`modelview_origin`, `modelview_basis_*`) on shared 3D instances, once per
  frame, overwritten per viewport as `_render_frame()` walks them
  (`cross_section_rendering_engine_4d.cpp:186-191`, loop at
  `rendering_server_4d.cpp:105-150`).
- Aaron's own comment sits on exactly that line:
  `// TODO Need to split out view matrix to support multiple viewports,
  currently the same for all viewports.` (`:185`)

So two `Camera4D`s in two viewports do not give two slices; they give the same
slice twice. **Predicted from source, not yet tested empirically** — a
half-hour Play-mode test would confirm it, and is worth doing before any
decision, because this one fact reorganises the whole project.

Two ways out, and this is the main thing to decide:

1. **Engine change.** Implement the TODO — instance-per-viewport or view
   matrix packed into camera attributes. It is Aaron's own note in the shared
   open-source module, so it is a conversation with him, not a fork
   (`follow_up/lighting_overhaul.md` records why forking that module is a bad
   trade). Highest value, unknown cost, not our module.
2. **Geometry diorama.** Don't render a second slice — *duplicate* the
   destination content as w-invariant geometry sitting behind the aperture, in
   the current slice. Real geometry means correct parallax, occlusion and
   lighting for free, no engine work, no `SubViewport`, no slice cache. Cost:
   the diorama is a copy that must be kept in sync, and a moving object on the
   far side has to be mirrored to appear in it. For one authored chamber that
   is cheap.

The paper's entire section 8 (cache keys, revisions, `CrossSectionCache`)
evaporates in either case: this engine re-slices every mesh every frame on the
GPU. There is nothing to cache. That is a large simplification the paper
misses because it assumes slice extraction is our job.

## Refutation 2 — the field size is wrong, but runtime carving is already solved

**Corrected 2026-08-19 after reading `VoxelMining/scripts/voxel_mining_block.gd`
rather than only the follow-up notes. The first version of this section costed
runtime carving off `voxel_port`'s terrain numbers and concluded it was
infeasible. That was wrong, and it produced a bad recommendation.**

What is actually in the tree:

- A **persistent** `VoxelField4D` survives across hits; carving is one more
  layer on top, not a rebuild from scratch —
  `_field.add_layer(AIR, sphere_sdf, gradient, 1.0, 1 << GROUND)`
  (`voxel_mining_block.gd:196-205`).
- **The paper's "density operation" (§5) therefore already exists.** A portal
  cutter is that same call with `sd_rounded_box_4d` in place of the sphere.
  Sections 5 and 6 are an SDF swap, not new architecture.
- At `grid_size` 8 (4,096 points) a full remesh per hit costs "a few tens of
  ms" and is playable (`voxel_mining_block.gd:32-35`).

What does *not* survive is the paper's **single 589,824-cell field** — 144× a
mining block, in single-threaded GDScript, with no chunking anywhere in the
project. The architecture that works here is the one `VoxelMining` already
uses: **many small independent block fields**, which is chunking by another
name. Its known limitation is real and unsolved — cuts do not blend across
block boundaries, because each block owns its own field with no shared
boundary samples (the "skirts" question in `voxel_port.md` and
`feedback_voxel_mining_lessons`).

The scaling step that is genuinely untested: `VoxelMining` has only ever run
**one** block at a time. A room shell is tens of blocks, and collider count is
per surface grid point in 4D (order ~500 per block) — so a room could reach
five figures of `CollisionShape4D` nodes. Measure this early; it is the most
likely thing to bite.

## Refutation 3 — collision exists for voxel geometry (my error, corrected)

**Corrected 2026-08-19.** The first version of this section said dual-contoured
geometry has no usable collision. That is true only of *mesh* colliders.
`voxel_mining_block.gd:350-379` solves it: one `BoxShape4D` per **surface**
grid point, which is exempt from the AABB collapse because it genuinely is a
box, with buried interior points skipped. A raycast hands back the exact
`CollisionShape4D` hit, so hit → voxel is a dictionary lookup rather than
coordinate math (`:20-30`), and `mining_axe.gd` already does raycast → carve on
the `fire` action.

So: shooting holes in dual-contoured 4D geometry and walking on the result is
**working technology in this repo**, not a dependency to build.

What remains true about AABB-only physics:

| Paper asks for | Reality |
| --- | --- |
| "static concave collider per derived 3D chunk" | No derived-3D physics world exists, and a `ConcaveMeshShape4D` collapses to one box (`voxel_port.md`). Per-voxel `BoxShape4D` is the working answer |
| Angled exit shelf, momentum fling into it | A ramp collides as its own bounding box; no step-up, `snap_distance` 0.1. Angled surfaces are still not representable |
| `RigidBody3D` cube | `RigidBody4D` exists but is **used nowhere in this project** — unproven, flag as risk |

## What survives, and is worth keeping

- **The Portal design discipline** (section 2) — every visual claim needs a
  matching physics claim; never show an open aperture over a solid wall.
- **Teach-by-constraint level shape**: observe → cross → cross into a
  different slice. The paper's own fallback ("stop after step 5") is the right
  scope.
- **Crossing as a swept signed-distance test plus an explicit state machine**
  with a safe-close rule (sections 9, appendix A). Cheap and correct here.
- **Endpoint = origin + orthonormal 4D frame + captured slice state**, with
  `M = F_out · C · inv(F_in)`. Sound; `C` must be derived from `Basis4D`
  conventions and unit-tested, as the paper says.
- **Discrete authored slice states** rather than continuous rotation. In this
  codebase the honest simplification is stronger than the paper's: a slice
  state is a **w offset**, one float — exactly what `PhaseMaze`'s gates and
  `hub2`'s ramps already key off. No basis rotation, no quantised matrix
  hashing.

## Occam's razor: what Chamber 01 should actually be

Strip everything whose absence does not weaken the thesis:

**Revised 2026-08-19.** The first version of this table proposed replacing the
voxel geometry with authored boxes and deferring dual contouring entirely. That
followed from the two errors corrected above and is withdrawn: the destructible
voxel core is the *point*, it works today, and the paper is right to build on
it.

| Paper | Proposed |
| --- | --- |
| Runtime rounded-hyperbox SDF subtraction | **Keep** — `VoxelField4D.add_layer` with `sd_rounded_box_4d`, exactly how `mine_at_shape` already carves spheres |
| One 589,824-cell field with chunked dirty rebuilds and ghost borders | Many small `VoxelMiningBlock`-style fields, as `VoxelMining` already does. Seams between blocks are the known unsolved cost |
| Cross-section cache, revisions, slice keys | None. The GPU re-slices every frame; there is nothing to cache |
| `CharacterBody3D` + 4D anchor | Aaron's `CharacterBody4D` player, unmodified |
| Concave chunk colliders | Per-surface-voxel `BoxShape4D`, already working |
| Cube as `RigidBody3D` | Deferred until look-through and traversal land |
| Angled exit shelf, momentum fling | Deferred; flat shelf only, AABB physics cannot do the angle |

That leaves the genuinely unproven things — **look-through**,
**cross-slice traversal**, and **voxel geometry at room scale** — as the
first artifact, which is what the paper's own kill criteria say to protect.

## Open question for the human

Continuous `rotate_4d` and authored portals fight each other. If the player
can freely slice-rotate, an aperture's captured "w = +6" stops being a
hyperplane offset in the rotated frame. The paper's answer is to remove free
rotation and give the chamber a dial. `MiegakureLook` bet the opposite way.
Deciding this before building is cheaper than after.

Related: [[project_engine_gotchas]], [[project_hub_demo_lessons]],
[[project_phase_maze]], [[project_miegakure_look]]
