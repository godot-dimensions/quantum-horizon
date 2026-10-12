# W tools

A node that keeps trees in view when the slice turns, made procedurally from what you placed by hand:

- **The W Exploder** (`exploder/w_exploder_4d.gd`) for trees and bushes: it stands each plant again in W
  slices above and below, each copy its own offset, turn and size.

(There was also a W Optimiser for landmarks, which made a copy of a landmark follow your slice; it was
removed on 9 Oct 2026. `PLAN.md` and `research/` still describe it, as history.)

It saves nothing it makes. You keep editing the trees, and every load makes the W versions afresh from them.

Why it works the way it does, with the numbers: `research/experiments.md`. The plan: `PLAN.md`. Frames:
`smoke_test_output/wtools/`.

## 1. The W Exploder

**Use.** Put the node over a container of hand-placed plants (its children with `pen_oak_4d.gd`: oaks and
bushes) and pick a preset. **Preview copies (on / off)** shows them in the editor and takes them away again
(the wood only; the leaves grow at play). They sit at other W's, so the editor's slice (Cross-section) at W 0
looks the same either way; the volume view (Projected, or Combined) shows them: in the editor's Preview they
are left in the volume view on purpose (`preview_in_volume_view`), while in play they stay out of it. The Preview is on when a scene opens (`show_preview`, on by default);
the button switches it and saving the scene keeps the choice, never the copies. **Save as preset** writes the current numbers as a new
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

## 2. In the pen (playable_world.tscn)

- **World/Trees**: the W Exploder, Turnable forest: 458 copies of the 104 plants, to 18 m of W either side.
  The planting costs the GPU less than it did with 259 copies (1.0-2.4 ms flat at five places, against
  1.2-3.6), and its cull 0.1 ms a frame (0.65 before). `solid_near_path` is the player: a copy's trunk is
  in the physics only while you are within 3 m of its W (all of them solid cost 0.7 ms of physics; this way
  0.2-0.3).
- **Frames**: `smoke_test_output/pen_layout/wtools/` (capture set `wtools`) and `smoke_test_output/wtools/pen/`.

## Tests (in `tests/`, run with `CreationLab/scripts/lab_run.sh`)

| Runner | Checks |
|---|---|
| `_presets_exploder_runner.gd` | each Exploder preset: crowns, trunks and floating crowns from 0 to 60 degrees (xw, zw), frames, GPU |
| `_verify_exploder_stable_runner.gd` | moving one plant changes only its copies |
| `_verify_lab_preset_key_runner.gd` | P in the lab steps through the presets |
| `_verify_preview_toggle_runner.gd` | the Preview button turns off with a second press |
| `_film_side_runner.gd` | side by side films (without copies / with the exploder) in the lab, frame by frame, the pen's character |
| `_editor_shots.tscn` | opened with `-- wt_shots`, drives the editor and takes the screenshots for the explainer page |
| `_verify_pen_wtools_runner.gd` | in the pen: the planting, copies' trunks solid near the player's W, frames |
| `_cost_pen_wtools_runner.gd` | in the pen: process and physics time with the W tools, without the exploder, and with hollow copies |
| `PenLayout/scripts/_capture_pen_runner.gd wtools` | the pen's frames: woods turned across the view, the landmarks turned along it, the volume view |
| `_coverage_trees_runner.gd`, `_probe_engine_runner.gd`, `_probe_units_runner.gd` | the experiments (steps 7-35) |

## Traps

- **Untested in the editor itself.** The Preview and Save buttons call the same methods the runners test, but
  the editor's own handling (the save hook) has not been tried by hand.
- **Grass** right at the camera fills the view when the slice is turned along it: the grass's own, not the
  W tools'. It hides whatever is behind it.
- **No class_name** on any of these scripts (engine_gotchas.md): preload them.
