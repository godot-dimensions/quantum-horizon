# W tools: handover (7 Oct 2026)

Ramon, 7 Oct: two partial auto-generators with tested presets, so things stay in view when the slice turns,
made procedurally: the **W Exploder** for trees and the **W Optimiser** for landmarks. Built in
`project/ramon/WTools/` with test labs, then put into the pen with his permission ("when succesful, i do give
permission to update the player world").

Read first: `WTools/README.md` (use, settings, presets, traps). Why each choice: `WTools/research/experiments.md`.
The plan and its status: `WTools/PLAN.md`.

## Where things are

- `WTools/exploder/`: `w_exploder_4d.gd` (the node), `w_exploder_preset.gd`, `presets/*.tres` (Near wood,
  Sparse, Turnable forest, Wide turn), `w_exclude_4d.gd` (keep-out shapes).
- `WTools/optimiser/`: `w_optimiser_4d.gd` (the node), `w_profile.gd`, `profiles/*.tres` (Prop, Landmark,
  Skyline, World-deep).
- `WTools/tests/`: the labs (`exploder_lab.tscn`, `optimiser_lab.tscn`, made by their `_make_*` runners) and
  the runners (README, Tests).
- In the pen: `World/Trees` is the Exploder (was `scripts/pen_trees_4d.gd`, still on disk, unused),
  `World/WatchstoneW` and `World/RangeW` are Optimisers. Two lines in the look: `look/pen_look_4d.gd` `_strip`
  and the low-mesh branch of `_take`, `look/pen_blockouts_4d.gd` `art_bounds` (a mesh hidden by an Optimiser
  behind its copy, `w_hidden`, is drawn art all the same). The blockout's oak trunk is as deep in W as the
  slab trunk (`_oak`, `trunk_w_half`).

## What the tests changed (the design moved three times)

1. **The range is built in W.** Deepening its merged meshes stretched its W layout, and its walls across W
   became solid blocks 12 m deep across the yard. Now any landmark with parts or colliders off its middle W,
   or walls across W, is left exactly as it is (Trym's shed is one too).
2. **The wrap.** Copies at fixed angles round the middle dipped between them (the range lost half); one copy
   turned round the middle slid off-axis landmarks across the view (the Watchstone left the frame in the
   pen). Now one copy is drawn where the landmark is on the flat slice through the camera. Exact for a turn
   in one plane; a quarter of a degree of camera movement at 60.
3. **Solid copies cost physics.** The engine's physics checks every body on every move: 458 trunks cost 0.7
   ms. A copy's trunk is in the physics only near the player's W (89 of 458 at W 0).

## For Ramon to decide

- **The camp** is left out on purpose (it stands at W -2.5 in the egg hunt's lane). If it should be seen from
  the farm's slice when turned, give it the Optimiser with the Skyline profile and a `min_w_half` under 2.5
  (so it stays out of W 0), or decide the lane matters less.
- **Wide turn vs Turnable forest**: Turnable forest is in. Wide turn keeps more wood past 45 degrees for twice
  the copies and about the same GPU (the cull hides what is not cut); physics is cheap now that far trunks are
  out of it.
- **`wrap_arc` and `wrap_length`** on the Watchstone and the range: 60 degrees and 40 m. Past them the
  landmark is only itself.
- **The editor**: the Preview, Clear and Save buttons have not been tried by hand.

## Numbers to compare against

Pen, art look, five route views (`_perf_layout_b_runner.gd`): planting GPU flat 1.44 2.20 2.37 1.01 2.25 ms
(before 2.34 2.91 3.64 1.15 2.87), cull 105-150 us (before 600-680). Physics (`_cost_pen_wtools_runner.gd`):
1.14-1.29 ms with the W tools, 0.92-0.96 without the Exploder.

## Tests that pass (7 Oct)

`_verify_pen_wtools_runner.gd` (14 checks), `_optimiser_lab_runner.gd` (all), `_verify_lab_preset_key_runner.gd`,
`_verify_exploder_stable_runner.gd`, `look/_verify_look_runner.gd` (nine groups), `PenLayout/scripts/
_verify_journey_b_runner.gd` (22 of 22). The journey's log ends with "27 resources still in use at exit"; it
did before the W tools too.

## Asked by Ramon, to do once his editor is closed (7 Oct, after the build)

- **The wrap in the editor**: DONE in code (with Preview on, the wrap follows the editor's own camera), NOT yet
  tried by hand in the editor: turn the 4D view into W in Cross-section and the Watchstone should stay put.
- **Test the Preview toggles**: DONE (`_verify_preview_toggle_runner.gd` passes: off at a second press, the
  Watchstone put back exactly, on again).
- **Ring or stay put, as pictures**: DONE as a side by side film (`smoke_test_output/wtools/films/ring_side.mp4`,
  on the explainer page). They differ only off to the side with the slice turned across the view (the ring
  slides and skews). Ramon to decide whether a "Ring" checkbox is worth building.
- **Explainer page for the team**: https://claude.ai/artifact/6FLE6gqUG6umchcdUYx49v (diagrams, four videos,
  editor screenshots). Shared with the organisation. Its build files are in the session scratchpad; the
  films and editor shots are reproducible from `_film_side_runner.gd` and `_editor_shots.tscn`.
- Also done on request: Exploder Preview copies show in the editor's volume view by default
  (`preview_in_volume_view`); the films use the pen's smaller character (`w_lab_4d.gd pen_player`).
