# W tools

Two nodes that keep things in view when the slice turns, made procedurally from what you placed by hand:

- **The W Exploder** (`exploder/w_exploder_4d.gd`) for trees and bushes: it stands each plant again in W
  slices above and below, each copy its own offset, turn and size.
- **The W Optimiser** (`optimiser/w_optimiser_4d.gd`) for landmarks and hero objects: it reads an asset,
  deepens its thin parts in W, and can wrap it round the area's middle so it stays where it is at any turn
  (the mountains' way).

Neither saves anything it makes. You keep editing the trees, or the landmark in its own scene
(`chickenpen/units/...`), and every load makes the W versions afresh from that.

Why each works the way it does, with the numbers: `research/experiments.md`. The plan: `PLAN.md`. Frames:
`smoke_test_output/wtools/`.

## 1. The W Exploder

**Use.** Put the node over a container of hand-placed plants (its children with `pen_oak_4d.gd`: oaks and
bushes) and pick a preset. Press **Preview copies** to see them in the editor (the wood only; the leaves
grow at play), **Clear copies** to take them away. **Save as preset** writes the current numbers as a new
.tres in `exploder/presets/`.

**What it does.**
- **Layers.** Every plant again at W steps of `layer_spacing` out to `w_reach` either side. Each copy stands
  a pace or two to one side, is turned about its trunk and in X and W (another cut of the same 4D tree), and
  is a little bigger or smaller. `w_jitter` breaks the layers up so a turned slice does not show stripes.
- **How many.** `auto_share` keeps a turned slice as full as the flat one (share = spacing / 2 x the crown's
  W reach).
- **Trunks.** Each trunk is made one depth in W up to its branches (`trunk_w_slab`, 0.9 of the crown's
  reach). Turned, a thin trunk left the slice long before its crown and the crowns floated; a taper left
  stumps on the ground.
- **Volume view.** The copies stay out of the projection (they smeared it white).
- **Cull.** One packed pass a frame (about 50 us for 200 copies). A copy the slice does not cut is not drawn,
  so the wide preset costs the GPU no more than the default.
- **Stable.** Each copy's dice come from its plant's name and its layer, so moving one plant changes only that
  plant's copies.

**Per plant.** Metadata on a placed plant: `w_copies` = `none`, `fewer` or `more`; `w_reach` = its own reach.

**Where not.** Paths, landmarks (anything with a `footprint()`), walls, hills, outside the valley, and any
`w_exclude_4d.gd` node (a ball or a box in x, z and W, drawn in the editor).

**Aim.** Set `target_angle` and `view_distance` and `reach_needed` says how far the layers must reach for that
view.

**Presets** (the exploder lab, 40 plants; crowns in view and well cut out of 33, slice turned across the view
at 0/20/40/60 degrees; GPU flat):

| Preset | Reach | Copies | Crowns 0/20/40/60 | GPU | For |
|---|---|---|---|---|---|
| Off | | 0 | 33 / 10 / 5 / 5 | 1.59 ms | |
| Near wood | 9 m | 119 | 33 / 33 / 21 / 18 | 2.13 ms | turns to about 30 degrees |
| Sparse | 18 m, share 0.4 | 132 | 33 / 25 / 22 / 22 | 1.83 ms | open country |
| **Turnable forest** | 18 m | 203 | 33 / 30 / 29 / 26 | 2.01 ms | **the pick** |
| Wide turn | 36 m | 405 | 33 / 30 / 29 / 39 | 2.03 ms | slices turned past 45 degrees |

**The lab.** `tests/exploder_lab.tscn`. Walk with the kit player; hold the right mouse button and drag to
turn the slice; R gives the flat slice again; **P** steps through the presets.

## 2. The W Optimiser

**Use.** Put the node beside a landmark (a unit instance), set `target` to it, and pick a profile. **Analyse**
writes the report into the inspector, **Preview** shows the result in the editor, **Clear** takes it away.
A save takes the preview off first and puts it back after, so nothing of it is saved. **Save as profile**
writes the current numbers to `optimiser/profiles/`.

**The report** lists the parts (every drawn mesh, not an animal's or a character's) by class: body, thin,
ground, detail, or elsewhere (at another W). It says how far the slice can turn before the landmark leaves
it, seen from 10, 20 and 40 m, before and after, and what the wrap does. A landmark built in W says so.

**What it does.**
- **Thin parts deeper.** Each part shallower in W than `min_w_half` either side is scaled in W about its own
  middle. W scale is an exact extrude, and its solid colliders are made as deep (never an Area4D's). This
  holds a landmark when you are near it; far off, no depth is enough.
- **The wrap** (Skyline). The mountains are a ring round the pen, so one of them is always in a slice. A
  landmark gets one copy, drawn where the landmark is on the flat slice through the camera: lifted to the
  camera's W, then turned about the camera as the slice is turned. It stays where you saw it, the same size
  and bearing, at any turn up to `wrap_arc` and from `wrap_length` metres of W either side (the W wrap
  length: how far through W it follows you). Walk and it comes nearer as anything would. The copy has no
  collision, and within `near_margin` of the landmark you always see the landmark itself: what you see there
  is what you touch. It took three tries (experiments.md): a fan of copies at fixed angles dipped between
  them; one copy turned round the area's middle slid anything off to one side across the view (in the pen
  the Watchstone slid out of frame).
- **Built in W: left alone.** A landmark laid out through W by hand (the range: boards from W -4 to +4, walls
  across W that keep you in its yard; Trym's shed: walls across W at +-1.7) is kept exactly as it is. It is
  told by its parts and colliders: any off its middle W, or any wall across W. Its meshes are merged, so scaling them would stretch the whole layout: the
  range's W walls were pushed out among the boards, and became solid blocks 12 m deep across the yard (the
  lab caught it). Only the wrap applies to it. `respect_w_layout` turns this off; a part with metadata
  `w_keep` is always left alone.

**Profiles** (the landmark alone, the slice turned straight ahead 0-60 degrees; full table in
`research/experiments.md`):

| Profile | Does | Holds |
|---|---|---|
| Prop | parts 2 m deep | small things, a little turn |
| Landmark | parts 6 m deep | near: from 10 m the Watchstone keeps 70% of itself at 40 degrees (5% untouched); from 20 m, half at 20 degrees |
| **Skyline** | parts 4 m deep, wrapped to 60 degrees and 40 m of W | **all of it at every turn to 60 degrees, from 20 m and 40 m (the Watchstone: 13.2k pixels at every turn)** |
| World-deep | parts 60 m deep | walls that must block every W. Seen through a turned slice, a deep thing looks further off (d / cos t: twice as far at 60 degrees) |

The range (built in W) with Skyline keeps 96-98% of its flat look at every turn to 60 degrees, from 10, 20
and 40 m (from 20 m: 1,064 of 1,092 pixels at each turn; untouched it had 34 at 10 degrees and none after).

**The lab.** `tests/optimiser_lab.tscn`: the Watchstone (Skyline), the camp and the range (Landmark).

## 3. In the pen (playable_world.tscn)

- **World/Trees**: the W Exploder, Turnable forest: 458 copies of the 104 plants, to 18 m of W either side.
  The planting costs the GPU less than it did with 259 copies (1.0-2.4 ms flat at five places, against
  1.2-3.6), and its cull 0.1 ms a frame (0.65 before). `solid_near_path` is the player: a copy's trunk is
  in the physics only while you are within 3 m of its W (all of them solid cost 0.7 ms of physics; this way
  0.2-0.3).
- **World/WatchstoneW**: Skyline on the Watchstone (LookoutSite/Lookout).
- **World/RangeW**: Skyline on the range; it is built in W, so only the wrap: seen from more than 15 m it
  stays in view when the slice turns, and it follows every edit in `units/rune_range`.
- **Not optimised:** the camp (it stands at W -2.5 on purpose, one of the egg hunt's lanes: deepened, it
  would show in the farm's own slice), Trym's shed (built in W), the town walls (already 60 m deep).
- **The look.** When DEV/ART switches, the Optimiser makes its copy again from what the landmark then draws.
  The look treats a landmark mesh hidden behind its copy (`w_hidden`) as drawn
  (`look/pen_look_4d.gd` `_strip`, `look/pen_blockouts_4d.gd` `art_bounds`).
- **Frames**: `smoke_test_output/pen_layout/wtools/` (capture set `wtools`) and `smoke_test_output/wtools/pen/`.

## Tests (in `tests/`, run with `CreationLab/scripts/lab_run.sh`)

| Runner | Checks |
|---|---|
| `_presets_exploder_runner.gd` | each Exploder preset: crowns, trunks and floating crowns from 0 to 60 degrees (xw, zw), frames, GPU |
| `_verify_exploder_stable_runner.gd` | moving one plant changes only its copies |
| `_verify_lab_preset_key_runner.gd` | P in the lab steps through the presets |
| `_reach_landmarks_runner.gd` | a landmark's pixels on screen as the slice turns, per treatment or profile (`p_skyline` ...) |
| `_optimiser_lab_runner.gd` | reports, frames off and on (and the volume view), collisions (deepened colliders hit, the wrap's copy does not, the range left exactly as built), the wrap following the slice, cost, and an edit to the Watchstone's own scene reaching the copy |
| `_parts_runner.gd` | the Optimiser's parts and colliders, one by one, for checking by eye |
| `_verify_pen_wtools_runner.gd` | in the pen: the planting, copies' trunks solid near the player's W, the Optimisers, the look switched with the copy showing, frames |
| `_cost_pen_wtools_runner.gd` | in the pen: process and physics time with the W tools, without each, and with hollow copies |
| `_probe_pen_wrap_runner.gd` | in the pen: the Watchstone's wrap number by number from a spot, for a frame that lost it |
| `PenLayout/scripts/_capture_pen_runner.gd wtools` | the pen's frames: woods turned across the view, the landmarks turned along it, the volume view |
| `_coverage_trees_runner.gd`, `_probe_engine_runner.gd`, `_probe_units_runner.gd` | the experiments (steps 7-35) |

## Traps

- **Untested in the editor itself.** The Preview, Clear and Save buttons call the same methods the runners
  test, but the editor's own handling (the save hook, the inspector report) has not been tried by hand. The
  wrap's copy does not show in the editor (it needs a camera to follow).
- **Turned in two planes at once** (xw and zw together), the wrap's copy is off by the small turn between the
  two orders (exact for one plane, as the rigs turn).
- **Grass** right at the camera fills the view when the slice is turned along it: the grass's own, not the
  W tools'. It hides whatever is behind it, a wrapped landmark too.
- **No class_name** on any of these scripts (engine_gotchas.md): preload them.
