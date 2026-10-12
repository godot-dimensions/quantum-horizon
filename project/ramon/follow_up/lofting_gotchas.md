# Lofting and rigged-creature gotchas

Traps found while building `project/ramon/Model/` — the loft tool, the chicken, and the
attempt to animate a merged body+neck. Sibling to `engine_gotchas.md`, which covers the
4D module and editor itself. Everything here was measured, not assumed; where a number
is not trustworthy it says so.

Measurements: Windows, RTX 5080, windowed 900x600, `rigged_creature_ramon.tscn` /
`rigged_creature_merged.tscn`, 18 Sep 2026.

---

## Measuring anything

**Vsync makes every frame timing meaningless.** The frame is quantised to the 60 Hz
beat, so a real extra cost shows up either as nothing at all or as a whole missed frame.
Differences drawn from vsync-on runs are noise: one comparison here produced a *negative*
cost, and a 7 ms difference was invisible until vsync was off. Every timing runner must
open with:

```gdscript
DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
Engine.max_fps = 0
```

**Headless numbers for anything that renders are fiction.** `--headless` uses the dummy
renderer, which never builds the proxy mesh that most of the cost lives in. Render and
deformation costs must be measured windowed. Headless is still fine for geometry, pose
and state measurements.

**Interleave A and B frame by frame, do not run them as two blocks.** Run-to-run drift
is 1–2 ms, which swamps the signal. Alternate — deform on even frames, leave it alone on
odd — and attribute each sample to the frame *before* it, since the frame time read at
the top of `_process` covers the previous frame's draw, which is where the proxy rebuild
happens.

---

## The cost hierarchy: drawing, deforming, re-lofting

Three ways geometry can cost you, and they are about an order of magnitude apart.
Measured 18–19 Sep 2026 on the chicken:

| | per tetrahedron per frame | example |
|---|---|---|
| **drawing** it | ~0.15 us | five chickens, ~50,000 tets: **0.86 ms** |
| **deforming** it (skinning) | ~2.5 us | 6,200-cell body: **18.5 ms**; 720-cell leg: **1.8 ms** |
| **re-lofting** it | ~11 us | 720-cell leg: **7.8 ms** |

**Drawing lofted geometry is nearly free.** This was the biggest surprise. Five whole
chickens cost 0.86 ms to draw; hiding them saved almost nothing. Tetrahedron count is
not the thing to optimise.

**Moving one ball re-lofts the entire rig, and that is the expensive path.** The walker
posed the chicken's legs by writing knee and foot ball positions; the rig noticed and
rebuilt the whole leg. Five birds spent **77 ms of a 79 ms frame** doing this, while
drawing all five cost 0.86 ms. Replacing it with skinning — bind each vertex to the two
bones once, then `set_vertex_positions` each frame — took the flock from **79.31 ms to
19.76 ms**.

So the order of preference for anything that moves: move whole NODES if you can (free),
skin if the surface must bend, and never let a rig re-loft per frame.

**RETRACTED: "one big mesh costs more than two".** An earlier version of this file
claimed merging the neck into the body cost 3.7 ms for identical geometry (15.37 ms as
two meshes against 19.03 as one). That was wrong. Both numbers were dominated by the
legs re-lofting in the background. Re-measured with a quiet baseline: **0.91 ms for
6,100 tets in two meshes, 0.73 ms for 6,200 in one.** There is no meaningful draw
penalty for merging.

The lesson is about method, not meshes: hiding everything else is not enough to isolate
what you are measuring, because hidden things still ANIMATE. Turn the animation off too.

**What merging does still cost** is flexibility: a part of a merged mesh cannot be moved
by transforming a node, because the mesh belongs to the rig, not the part. It has to be
deformed, at ~2.5 us per cell per frame. That is affordable for a leg and not for a
whole body.

## The "fog" over the floor is the PROJECTION pass

**CORRECTION.** An earlier note here blamed the haze on the ground slab ending 40 units
away with the sky's horizon band showing above it. Enlarging the ground did help, but it
was not the main cause. A/B'd at runtime, 19 Sep 2026:

| | mean pixel difference from the authored view |
|---|---|
| projection pass off (`rendering_engine_name = "Cross-section"`) | **17.3**, and only below the horizon |
| ground thinned through W (300 -> 6), projection left on | **4.3** |

The player's camera in `rigged_creature_ramon` is set to `Combined`, which draws a faint
PROJECTION of the whole 4D scene over the cross-section (`projection_opacity_base = 0.02`).
A ground box 300 units thick through W projects an enormous faint slab across the lower
half of the screen. That is the haze. The sky is untouched, which is why sampling a
column of sky showed no difference at all and sent the first investigation the wrong way.

**There is no way to exclude one mesh from the projection pass.** `Cross-section` and
`Projected` both call the same `_update_3d_mesh_instances()` over the same mesh list, so
it is all or nothing per camera. Options without an engine change:

- Thin the VISIBLE ground through W while leaving the collision box wide: the mesh
  (`BoxTetraMesh4D`) and the shape (`BoxShape4D`) are separate resources. Removes about
  three quarters of the haze; costs a floor that vanishes visually past |w| > half its
  W size.
- Lower `projection_opacity_base`, which dims the projection for everything.
- Add a per-mesh "skip projection" flag to the 4D module - the real fix, and an engine
  change.

## Making a joint look continuous without merging

Sink the joining ball INSIDE its neighbour rather than butting the two surfaces together.
The chicken's neck base sat 0.234 from the chest ball's centre, just outside its 0.2
radius, and read as a join; moved to 0.139 it is swallowed by the chest and the seam is
inside the body where nothing can see it. Visually as good as merging, and free.

## Joints that bend, on a walking creature (3 Oct, the cat)

`strider_walker.gd` cuts the hide into rigid pieces (body, a thigh and a shank per leg) and
moves them by transform. The band of skin either side of each joint goes to BOTH pieces, so a
bend never opens a notch. On a small animal that band reaches into the body: long thin
tetrahedra from the hip out to the haunch's skin, which the thigh's copy swings out of the body
as **needles**, and the thigh's copy past the knee stands out behind it as a **step** (Ramon:
"something still looks a bit off with the legs and stretch artifacts").

Trimming those slivers out of the leg pieces (the first attempt) only traded needles for holes.
What works is **`blend_joints`**: the band tetrahedra, plus any whose corners' weights differ by
more than 0.6 (`STRADDLE`), go to a small mesh per hip and per knee, posed vertex by vertex every
frame: body still, thigh about its hip, shank about its knee, blended by the binding's weights.
Its border vertices are pinned to whichever rigid piece shares them, so there is no seam. On for
the cats; off by default, so Nike, the horse and the sauropod look as they did.

**What re-posing costs is per cell, and worse per cell in a bigger mesh** (writing
`vertex_positions` every frame, the renderer rebuilding the proxy;
`_measure_mesh_upload_runner.gd`, vsync off):

| re-posed each frame | added per frame |
|---|---|
| 200 cells, one mesh | +0.25 ms |
| 800 cells, one mesh | +2.7 ms |
| 800 cells as four meshes of 200 | +1.9 ms |
| 1,600 cells | +5 to +6.6 ms |

So bend only what has to bend, in small meshes: the cat's whole thigh posed cost 4 ms; the band
alone, split hip and knee (about 230 and 28 cells a leg), costs about 1.2 to 1.8 ms while it
walks (`_measure_cat_joints_runner.gd`), nothing while it sits (the walker stops), and nothing
beyond `joint_detail_distance` (20 m) of the player, where the joints hold their last pose.

---

## Authoring traps

**A rig that bakes ball colours writes into the material it is handed.** It sets both the
ramp texture and `albedo_source`, so any *other* mesh sharing that `TetraMaterial4D`
sub-resource starts sampling the wrong ramp with its own texture coordinates. Symptom:
the chicken's wing tips turned comb-red the moment `use_ball_colors` went on for the
body, because both used `chk_TetraMaterial4D_feather`. Give a colour-baking rig its own
material.

**One rig means one profile for everything in it.** Merging the neck (10 sides) into the
body (12 sides) silently promoted the neck to 12 and added 1,340 tetrahedra — 9,960 to
11,300 for the whole chicken — before anything was animated.

**Branches are expressed by nesting; the top-level chain is flat siblings.** A chain is
the rig's direct ball children in order. A branch starts at a ball with
`starts_branch = true` and continues by nesting each successive ball inside the previous
one (see the beak). Reparenting a chain into a branch therefore means nesting it *and*
re-expressing every position, since `.tscn` positions are parent-relative.

**Very short spans fold.** Branching the neck onto the chest ball put its first section
0.23 units from a ball of radius 0.2 and produced "folded through itself" on 22 of 1400
tetrahedra at the junction. Slivers come from spans too *long* for the section width,
folding from spans too *short* — the two checks bracket one ratio.

---

## Rig-reading traps

**"Walk to the last child" does not find the foot.** The balls of a leg rig are
*siblings*, authored bottom-up, so the last child is the **hip**. This made a beak-height
measurement meaningless — it reported the beak stopping 0.8 units above "the foot line"
when that line was actually the hip, 0.67 units too high. Sort the balls by height and
take the lowest.

**Global transforms are not settled in `_ready`.** Solving anything from
`global_position` there reads the feet as sitting at the origin. The chicken's peck angle
was solved against a floor well below the one it stands on, and drove the beak through
the ground. Defer geometric solving to the first simulated frame.

**A rigid swing about a joint cannot reach past its own radius.** Swinging the neck about
its base puts the head on a circle of radius R about the hinge, so any target lower than
`hinge.y - R` is unreachable and the solve clamps. Aim the part that should touch: aiming
the *last ball of the neck chain* (further from the hinge, so it reaches) swung the head
147°, turning it upside down so the comb scraped the floor and the beak pointed back at
the bird's own feet.

**Parent an attachment rather than carrying it in code.** A rig nested under a BALL is
skipped by the parent rig's branch detection, which only descends through balls — so it
keeps its own mesh, material and colour while inheriting the transform. The chicken's
wattle was first carried by the walker at runtime instead, on the mistaken assumption
that nesting would fuse it into the neck; that worked when playing but left the wattle
behind in the EDITOR, where no walker is running.

**Attachments authored as siblings do not follow.** The wattle is its own rig beside the
neck, not under it, so the beak went to the floor and the wattle stayed in the air. Carry
such parts explicitly: place each as though it were a child of the part it belongs to —
its rest offset put through that part's current rotation — which covers every motion at
once rather than chasing each one.

---

## Runner traps

**`SceneTree` does not dispatch `_physics_process`.** A main-loop script only gets
`_process`. A runner written around `_physics_process` silently does nothing and spins
until the timeout.

**Guard the frames before your lookup.** `if _node == null: return true` placed above the
frame that assigns `_node` quits the runner on frame 1, with no output and no error.

**Frame counts are not seconds.** Dividing a `_process` frame count by 60 assumes a rate
the runner does not have; physics also advances at its own pace relative to wall clock in
these runs. Use `Time.get_ticks_msec()` when the answer is a duration. Comparing a
wall-clock figure against a frames/60 figure across two runs produced an apparent
contradiction (8.6 s of head-down against 3.9 s of peck) that did not exist.
