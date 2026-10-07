# W tools: the plan (rewritten at step 36, 7 Oct 2026)

Ramon, 7 Oct: two partial auto-generators with tested presets, so things in the pen stay in view when the
slice turns, made procedurally instead of by hand: **the W Exploder** (trees: each plant stood again in W
slices above and below, its own offsets) and **the W Optimiser** (landmarks: analyse an asset and 4D-ify it,
with a W wrap length to set). Ramon keeps editing an asset in its own scene; the W versions follow. Both get a
node with buttons and a preset .tres; tested in volume view as well as the slice; then put into the pen
(his permission, once it works).

The first draft had 80 steps, 1-36 research and experiments. They are done; what they found is in
`research/` (desk_research.md, online_games.md, online_tooling.md, experiments.md). This is the plan rewritten
from them, with the building steps spelled out: 112 steps.

## What the experiments decided (research/experiments.md)

**Trees.** Layers 4.5 m apart out to +-18 m of W hold a turned slice's wood (crowns well cut: 33 flat, 29-31
from 10 to 30 degrees, 26 at 60; as it was: 11 at 10 degrees, 5 from 30). The trunks are the problem: turned,
a thin trunk leaves the slice long before its crown, so crowns float (24 of 30 at 20 degrees). Making each
trunk one depth in W up to its branches, 0.9 of its crown's W reach (the "trunk slab"), keeps the trunk with
its crown (6 floating at 20 degrees) and leaves no stumps on the ground (a taper did). Copies stay out of the
volume view's projection (they smeared it). A 3D Poisson fill was ten times the copies for nothing the layers
do not give: dropped. Costs: 203 copies for the lab's 40 plants, 0.26 s to make, 0.44 ms a frame to cull.

**Landmarks.** Scaling a part in W is an exact extrude and its collisions follow (the engine probe). Extruding
each part to a minimum W depth helps near (the Watchstone from 10 m keeps 53k pixels at 40 degrees, from 3.7k)
but not far. The **wrap** (copies of the landmark swept round a centre in the plane of the way to it and W)
holds a landmark exactly where it is at any turn and distance (the Watchstone: 13.3k pixels at 0 to 60 degrees
from 20 m), if only the copy nearest the slice is drawn (all of them doubled the scaffold) and the copies are
closer than about hw / R (thin landmarks dipped between 7.5-degree copies). Quarter-turn copies and W repeats
are dropped (little reach; repeats jump and multiply). The range keeps its hand-made W yard.

**The editor.** Regenerating in `_ready` is enough to follow an edited asset: saving the asset's scene and
going back to the pen's tab rebuilds the pen (online_tooling.md, from Godot's source). Generated nodes are
never saved (owner null).

## Done: research and experiments (1-36)

1-14 research (desk, online games, online tooling, the engine probe, the code); 15-24 the exploder lab and its
coverage runner; 25-31 the landmark reach runner; 32 the parts (connected pieces are single boxes and stones:
too fine, so parts are meshes and their spatial clusters); 33 collisions (W scale follows; copies of a wrap
need none: they are out of reach); 34 regeneration (above); 35 research/experiments.md; 36 this rewrite.

## D. The W Exploder (37-60)

37. Rename the test-built `exploder/w_exploder_4d.gd` into its final form: header, settings grouped
    (Distribution, Each copy, Trunks, Exclusions, Volume view, Readout).
38. Remove the Poisson mode (kept in the git history and experiments.md).
39. `exploder/w_exploder_preset.gd`: a Resource with every setting; the node takes a preset and copies it in
    when set (and a "Save as preset" button writes one).
40. Presets as .tres: **Near wood** (+-9, the pen's first planting with the slab), **Turnable forest** (+-18,
    the experiments' pick), **Wide turn** (+-36, for steep turns), **Sparse** (+-18 at share 0.4).
41. Reach from intent: an optional target angle and view distance compute the reach (W_max = D tan t - h),
    shown beside the reach setting.
42. The trunk slab per bake, measured from each bake's own crown (done in the test build; keep, cache).
43. Culling in one packed pass: the plants' cull boxes in packed arrays, built once they have settled on the
    ground; per frame one loop of arithmetic, no call per plant; compare against the call-per-plant loop.
44. Per-plant overrides: metadata on a placed plant (w_copies: "none", "more", "fewer"; w_reach) read by the
    node.
45. Exclusion shapes (`w_exclude_4d.gd`): ball and box in x, z, W; drawn in the editor as a wire mesh.
46. Stable dice (done): from the plant's name and the layer; a test that moving one plant changes only its
    copies.
47. The dev look: blockouts for copies (the pen's Look finds them by name: Oak*, Bush*), and the slab trunk in
    the blockout too.
48. Readout properties for runners and the panel: placed, copies, refused, made in, cull time, predicted reach
    per angle.
49. Editor buttons: Preview (makes the copies in the editor, unsaved), Clear, Save as preset.
50. The exploder lab scene finished: the readout in the lab look; a key to step through the presets.
51. Coverage runner per preset: crowns, trunks, floating, at 0-60 degrees, xw and zw.
52. Frames per preset: slice at 0, 15, 30, 45; volume view projected and combined.
53. The determinism test runner.
54. Perf per preset in the lab: build time, cull time, GPU time.
55. Fix what 51-54 show.
56. A decision page for Ramon: the presets side by side (frames and numbers), as an artifact.
57. README for the exploder (in WTools/README.md, section one).
58-60. Reserve: what the presets' tests ask for.

## E. The W Optimiser (61-86)

61. `optimiser/w_optimiser_4d.gd`: a node beside a landmark (a unit instance), pointing at it.
62. `optimiser/w_profile.gd`: the preset Resource (minimum part depth, wrap on/off, wrap arc, wrap centre, step
    from hw/R, the parts' classes and what each gets).
63. Analysis: every drawn mesh of the landmark (merged meshes included) with bounds in its frame, W
    half-depth, height, tetrahedra; its colliders.
64. Classes: ground (low and flat), body (most), thin (W half-depth under the minimum), tall (over a height),
    detail (small); a class per mesh, and per spatial cluster for merged meshes later if needed.
65. Treatment: per-part extrude, each thin part's node scaled in W to the minimum, about its own middle.
66. Its colliders: the landmark's collision shapes scaled in W the same (test that the physics follows a
    W-scaled CollisionShape4D as it follows a body).
67. Treatment: the wrap. Copies of the drawn meshes (sharing them) at angles round the wrap centre in the plane
    of (the way from the centre to the landmark, W), out to the arc, the step from the landmark's W half-depth
    and its distance.
68. The wrap's culling: per frame only the copy nearest the slice drawn (the original among them).
69. The wrap's centre: the valley's middle by default (the pen's bounds), or a node.
70. No collision on wrap copies; never a copy inside the walkable sphere (a warning if one would be).
71. The wrap and the volume view: copies out of the projection (one landmark, not a ring of them), tested.
72. Regenerate on ready, from the landmark as it is; editor Preview, Clear; nothing saved.
73. The report: the landmark's reach before and after (the reach runner's measure, offline from its bounds:
    the formula), tetrahedra drawn, warnings.
74. Presets: **Prop** (minimum depth 2 m), **Landmark** (minimum 6 m), **Skyline** (minimum 4 m and the wrap,
    arc 60 degrees), **World-deep** (minimum 60 m: walls that must block every W).
75. The optimiser lab scene: the Watchstone, the camp and the range on the lab floor, viewpoints 10, 20, 40 m.
76. Reach runner per preset (the measure from the experiments).
77. Frames per preset: 0, 20, 40, 60 degrees; volume view.
78. Collision test: walk into extruded parts at turned slices; walk where a wrap copy shows (nothing to hit).
79. Perf per preset.
80. Editing test: change the range in units/rune_range, reload the lab: the W versions follow.
81. Fix what 76-80 show.
82. A decision page for Ramon: the landmarks before and after.
83. README section two (the optimiser).
84-86. Reserve.

## F. Into the pen (87-104), Ramon's permission once it works

87. The Exploder on World/Trees in place of scripts/pen_trees_4d.gd, with the preset chosen from 56 (Turnable
    forest unless the page says otherwise).
88. The pen's exclusions checked: the paths' graph, the frames, the walls, the hills, the valley.
89. The pen's dev look with the Exploder's copies and slab trunks.
90. The Watchstone through the Optimiser (Skyline).
91. The camp through the Optimiser (Landmark), Trym's house too.
92. The range: its hand-made yard kept; the Optimiser's per-part depth only for its thin parts if the reach
    runner shows a gain.
93. The town walls: already as deep as the world (60 m); nothing.
94. The pen's look test, the journey, the playtest batch.
95. Perf in the pen, flat and turned, against today's numbers.
96. Frames of the pen's route, turned slices, volume view.
97. The film again (the slice tour) with the W tools.
98-104. Reserve: what the pen shows that the labs did not.

## G. Hand over (105-112)

105. WTools/README.md: both tools, their settings, presets, traps.
106. follow_up/w_tools.md: the handover.
107. The research folder tidied, linked from the README.
108. Memory.
109. Commit by path.
110-112. Reserve.

## Status

- 1-36 done (7 Oct night).
- 37-55 done (7 Oct): the Exploder in its final form, presets, per-plant overrides, exclusions, stable dice,
  the packed cull (tightened: plant box and ellipsoid reach, 2.68 -> 2.01 ms flat), preset runner with
  frames at 0/15/30/45, zw 30 and the volume view; numbers in research/experiments.md. 56 (the decision page)
  is folded into one page for both tools, made after the Optimiser (82), so Ramon gets one link. 50 done
  too (P in the lab steps the presets; `_verify_lab_preset_key_runner.gd`).
- 61-81 done (7 Oct): the Optimiser and its profiles, the lab, reach per profile, frames, collisions, cost,
  editing. The tests changed the design twice (research/experiments.md, "The Optimiser"): a landmark built
  in W (the range) is left exactly as it is, and the wrap is one copy turned to follow the slice instead of a
  fan of copies. Also: the W wrap length in metres (`wrap_length`), the near rule (`near_margin`).
- 83 (README) done.
- 87-97 done (7 Oct night): the Exploder on World/Trees (Turnable forest), the Optimiser on the Watchstone
  and the range (Skyline); the camp left out (it stands in the egg hunt's W lane), Trym's shed found built in
  W. The pen showed what the labs did not (98-104 used): the wrap's third form (one copy where the landmark
  is on the flat slice through the camera; the ring slid the Watchstone out of frame), the copies' trunks
  in the physics only near the player's W (0.7 ms of physics otherwise) and as deep as the slab trunk, the
  look and the Optimiser kept in step (w_hidden in the look, the copy remade on a switch). Tests: the pen's
  W tools test, the look test, the journey, both labs. The slice tour filmed again with the west wood and the
  Watchstone held while the slice turns (smoke_test_output/video/slice_tour_wtools.mp4).
- 56 and 82: one page for both tools, published as an artifact (claude.ai/artifact/6FLE6gqUG6umchcdUYx49v).
- 105-108 done: README, follow_up/w_tools.md, research tidied, memory. 109: committed by path.
