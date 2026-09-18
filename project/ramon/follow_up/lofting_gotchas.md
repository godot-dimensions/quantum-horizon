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

## What rendering actually costs

Measured with everything else in the scene hidden, vsync off:

| | tets | frame |
|---|---|---|
| body + neck as **two** meshes | 6,100 | **15.37 ms** |
| the same geometry merged into **one** mesh | 6,200 | **19.03 ms** |

**One big mesh costs more than two smaller ones at equal tetrahedra** — about 3.7 ms
here, roughly a quarter. Not a volume effect. The colour ramp and the per-frame rebuild
were both ruled out by switching them off and re-measuring; neither moved the number.
So: splitting a creature across several rigs is not just an authoring convenience, it is
cheaper to draw.

Whole scene, same two scenes: 16.16 ms working, 23.13 ms merged.

## What deforming a mesh costs

Moving a mesh's vertices per frame ("skinning") on the merged 6,200-cell body:

| | |
|---|---|
| GDScript skinning maths | **0.204 ms** |
| `set_vertex_positions()` | **0.004 ms** |
| the engine rebuilding the proxy mesh | **~18.3 ms** |
| **total** | **18.51 ms/frame** |

The approach is sound and the maths is free. What makes it unaffordable is that moving
any vertex triggers a rebuild of the *whole* proxy mesh. An incremental proxy update is
an engine-side change and would unlock real skinned deformation — this measurement is
the argument for it.

Earlier per-mesh figures (3700 cells 8.05 ms, 2400 cells 4.64 ms, 720 cells 0.19 ms)
were taken with vsync ON and are indicative only; they do suggest the cost falls away
sharply below ~1000 cells.

**Consequence for animation:** a part of a merged mesh cannot be moved by transforming a
node, because the mesh belongs to the rig, not the part. Either keep the piece as its own
rig and move it rigidly (cheap, shows a joint), or merge it and deform (continuous, and
currently too expensive). Trym's rigid-transform creature is the affordable route today.

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
