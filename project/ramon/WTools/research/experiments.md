# W tools: what the engine and the experiments said (7 Oct 2026)

Plan steps 7-35. Runners in `WTools/tests/`; frames in `smoke_test_output/wtools/`. Numbers are this
machine's (RTX 5080), windowed, vsync off where timed.

## The engine (`_probe_engine_runner.gd`)

| Question | Answer |
|---|---|
| A Godot 3D mesh into 4D (convert, cells from sheets, extrude through W) | Box 48 tetrahedra, cylinder 3,692: works. A sphere gives no cells (a normals binding error): closed round meshes need another way in. |
| Spin a half profile in X and W | Works, cheap (an L profile at 24 steps: 216 tetrahedra, 0.3 ms). Full turn only. |
| Solidify faces (the fence's slab) | Works. |
| Shape4D tetra meshes | Cubinder yes (8/16/32 segments: 120/264/552). Spherinder (CylinderShape4D) and duocylinder give none. |
| A node scaled in W against a mesh built that deep | The same picture at 0, 30 and 60 degrees of turn (frames wscale_*.png): **W scale is an exact, free extrude.** |
| A collider under a W-scaled body | Follows the scale (a ray at W 1.2 hits a 1-deep box scaled 3x). |
| Volume view settings | Camera4D w_fade (mode 1, 5 m), projection opacity 1.0, plane sharpness 0.3; MeshInstance4D.allow_projection on by default. |
| The cross-section's cost | **GPU about 1.8 ms per million tetrahedra drawn**, linear (590k: 1.06 ms); a drawn node costs about 6.6 us of frame on its own. |

## Trees (`_coverage_trees_runner.gd`, the exploder lab: 40 hand-placed light oaks and bushes)

Trees within 45 m and in view whose crown the slice cuts through its middle 70%, the mean of three headings,
as the slice turns (degrees). "Trunked": the trunk is in the slice too. "Floating": a crown with no trunk.

| Setup | 0 | 10 | 20 | 30 | 40 | 60 | copies | made | cull |
|---|---|---|---|---|---|---|---|---|---|
| As it was (flat in W) | 33 | 11 | 6 | 5 | 5 | 5 | 0 | | 0.10 ms |
| Round in W (w_stretch 1.8) | 33 | 21 | 10 | 7 | 5 | 5 | 0 | | 0.11 ms |
| The pen's planting (+-4.5, +-9) | 33 | 32 | 33 | 30 | 20 | 19 | 119 | 0.15 s | 0.31 ms |
| Layers to +-18, share 0.62 | 33 | 29 | 30 | 31 | 28 | 26 | 203 | 0.26 s | 0.44 ms |
| Layers to +-36 | 33 | 28 | 30 | 30 | 29 | 39 | 405 | 0.89 s | 0.87 ms |
| Layers to +-54 | 33 | 28 | 30 | 30 | 29 | 40 | 604 | 1.28 s | 1.03 ms |
| Poisson in (x, z, W), r 7 | (box count) 51-61 throughout | | | | | | 2,727 | 4.2 s | 4.9 ms |

Trunks at 10/20/30/60 degrees, layers to +-18:

| Trunks | 10 | 20 | 30 | 60 | floating at 20 |
|---|---|---|---|---|---|
| As they are | 5 | 6 | 7 | 4 | 24 |
| W-taper x4 (deeper toward the ground) | 25 | 22 | 22 | 18 | 9 |
| W-taper x8 | 28 | 28 | 28 | 25 | 3 |
| Slab 0.7 (one depth to the branches, 70% of the crown's) | 24 | 22 | 22 | 16 | 9 |
| **Slab 0.9** | 27 | 25 | 25 | 20 | 6 |

Frames (`coverage/`): the taper leaves **spikes on the ground** (stumps of trees whose crowns are out of the
slice: an off-centre cut catches only the deep base); the slab does not (trunk and crown are cut together).
Volume view (`coverage/volume_*`): copies in the projection smear the wood into a white haze; without them
it reads clean.

## Landmarks (`_reach_landmarks_runner.gd`: each unit alone, the camera 10, 20, 40 m off, the slice turned in zw)

The landmark's pixels on screen as the slice turns (0 / 10 / 20 / 30 / 40 / 60 degrees). The Watchstone:

| Treatment | 10 m | 20 m | 40 m |
|---|---|---|---|
| None | 74739 67913 51939 21884 3689 0 | 13269 4747 0 0 0 0 | 2729 0 0 0 0 0 |
| Extrude the whole unit to 9 m | 74691 73798 68144 54209 41719 3771 | 13269 11058 8297 571 0 0 | 2729 1984 0 0 0 0 |
| Extrude each part to 6 m | 74697 73788 70697 64795 53004 9439 | 13269 12432 6265 0 0 0 | 2729 324 0 0 0 0 |
| Quarter-turn copy | 75308 69190 55559 30409 19827 1356 | 13361 6729 1902 0 0 0 | 2739 192 0 0 0 0 |
| Repeat every 4.5 m to +-18 | 74713 67887 54173 52007 51887 29225 | 13269 10671 10450 9796 7686 5 | 2729 2346 2388 929 0 0 |
| Wrap (copies every 7.5 deg round the viewer) | 75431 75586 75737 75496 75858 75506 | 13408 13369 13370 13421 13401 13335 | 2729 2432 2415 2731 2435 2728 |
| **Wrap, the nearest copy only** | 74713 74695 74612 74776 74737 74788 | 13269 13267 13257 13282 13278 13279 | 2729 2432 2415 2731 2435 2728 |

The range (thin in W, 4 m) and the camp behave alike, with one more lesson: with copies 7.5 deg apart the wrap
dips between copies for a thin landmark (the range at 20 m: 1105, 418, 451, 1105, 414, 1105; at 40 m: nothing
between copies). The copies must be closer than the landmark's own W reach allows: about angle step <=
hw / R (hw its W half-depth, R its distance from the wrap's centre).

Frames (`reach/watchstone_*_20m_*`): untreated gone by 20 deg; the whole-unit extrude keeps the rock and loses
the timber (thin parts stay thin); the repeats jump (a smaller copy off to one side); the wrap stays put but,
with every copy drawn, the scaffold doubles where two copies are both partly cut; drawing only the nearest
copy fixes it.

## What it decides (the plan's step 36)

- Trees: layers, 4.5 m apart, to +-18 (the "turnable forest"), share 0.62, W jitter 0.8, the trunk as a slab at
  0.9 of the crown, copies out of the projection; Poisson is dropped (ten times the copies for no gain the
  layers do not give). Wider presets for steep turns (+-36 helps only past 45 deg).
- Landmarks: per part, an extrude to a minimum W depth (cheap, exact, collisions follow); for landmarks seen
  from afar (the Watchstone), the wrap with only the nearest copy drawn and its step set by hw / R; repeats and
  quarter turns are dropped as treatments (the range keeps its hand-made W yard as it is).

## The Exploder's presets (`_presets_exploder_runner.gd`, plan steps 51-54, after the cull was tightened)

The exploder lab, each preset in turn: crowns well cut within 45 m and in view (the mean of three headings)
as the slice turns 0 / 10 / 20 / 30 / 40 / 50 / 60 degrees, then the GPU's time (median of 90 frames, vsync
off) flat and turned 30. Frames: `presets/<preset>_00, _15, _30, _45` (xw), `_zw30`, `_volume_projected`,
`_volume_combined`.

| Preset | reach | copies | made | crowns, xw | crowns, zw | floating at 20 xw | cull | GPU flat / 30 |
|---|---|---|---|---|---|---|---|---|
| Off (the plants alone) | | 0 | | 33 21 10 7 5 5 5 | 33 5 0 0 0 0 0 | 6 | 16 us | 1.59 / 0.57 ms |
| Near wood | +-9, share 0.75 | 119 | 0.28 s | 33 31 33 30 21 18 18 | 33 26 24 9 2 0 0 | 7 | 43 us | 2.13 / 1.96 ms |
| Sparse | +-18, share 0.4 | 132 | 0.32 s | 33 24 25 26 22 22 22 | 33 16 18 13 9 6 3 | 5 | 60 us | 1.83 / 1.71 ms |
| **Turnable forest** | +-18, auto (0.62) | 203 | 0.46 s | 33 28 30 30 29 26 26 | 33 23 28 20 13 7 3 | 6 | 52 us | 2.01 / 2.21 ms |
| Wide turn | +-36, auto | 405 | 0.88 s | 33 28 30 30 29 35 39 | 33 23 28 23 21 27 15 | 6 | 92 us | 2.03 / 2.20 ms |

- xw is a turn across the view; zw is a turn along it (straight ahead), the harder one: what is ahead at
  distance d leaves a slice turned t unless it is W-deep d tan t. Out to 20 degrees every preset but sparse
  keeps most of the wood both ways; past 30, only the wide turn holds straight ahead.
- The cull pays for itself: the wide turn, twice the copies, costs the same GPU as the turnable forest
  (copies out of the slice are not drawn); before the cull was tightened (plant box and ellipsoid reach) the
  turnable forest cost 2.68 ms flat.
- Frames: no stumps, no floating crowns to speak of at 15 or 45; at zw 30 the turnable forest and the wide
  turn still read as a wood, near wood as a few trees, off as nothing. The volume view is clean in every preset
  (the copies stay out of the projection).
- The pick stays the turnable forest: as much wood as the wide turn up to 40 degrees for half the copies and
  half the time to make; the wide turn is for places where the slice is turned steeply on purpose.

## The Optimiser (plan steps 61-81: `_reach_landmarks_runner.gd` p_<profile>, `_optimiser_lab_runner.gd`)

Each landmark alone, the camera 10 / 20 / 40 m off, the slice turned straight ahead (zw) 0 / 10 / 20 / 30 /
40 / 60 degrees; the landmark's pixels on screen (as in the treatments above). The wrap centred on the viewer.

| Watchstone | 10 m | 20 m | 40 m |
|---|---|---|---|
| None | 74721 67901 51939 21884 3689 0 | 13269 4747 0 0 0 0 | 2729 0 0 0 0 0 |
| Prop (2 m) | 74713 73632 67719 34325 13404 0 | 13269 4747 0 0 0 0 | 2729 0 0 0 0 0 |
| Landmark (6 m) | 74694 73789 70688 64762 52639 9439 | 13265 12409 6241 0 0 0 | 2728 319 0 0 0 0 |
| **Skyline (4 m, wrap)** | 74736 73753 70066 59296 26956 5385 (near: itself) | **13269 13272 13226 13276 13282 13271** | **2729 2728 2711 2725 2724 2719** |
| World-deep (60 m) | 74681 73804 71018 65736 57118 33344 | 13256 12838 11785 10147 8055 3432 | 2727 2662 2415 2066 1577 125 |

| Camp, range (Skyline) | 10 m | 20 m | 40 m |
|---|---|---|---|
| Camp, none | 27709 18825 15921 2748 0 0 | 1786 0 0 0 0 0 | 410 0 0 0 0 0 |
| Camp, Skyline | 27702 24267 21091 11925 615 0 (near) | 1779 2055 1813 1818 2024 1991 | 408 419 418 409 419 421 |
| Range (hand-made W yard), none | 4625 1278 0 105 0 0 | 1092 34 0 0 0 0 | 273 0 0 0 0 0 |
| Range, Skyline, copies 8.5 deg apart | 4625 1754 3151 3165 1857 1949 | 1092 1001 702 450 482 782 | 273 275 269 209 165 111 |
| **Range, Skyline, one copy following** | 4625 3993 3486 3105 2472 1820 | 1092 1019 947 954 857 774 | 273 288 284 260 252 252 |

What it found, in the order it was found:
- **Built in W.** The range's meshes are merged, and its layout runs through W (boards from W -4 to +4, walls
  across W at +-2.8 that keep you in the yard). Deepening its parts stretched that layout, and the walls
  across W became solid blocks 12 m deep across the yard (a ray along W from +10 hit at +9.9). The Optimiser
  now tells such a landmark by its colliders (any off its middle W, or any wall across W) and leaves it
  exactly as it is; only the wrap applies (`_optimiser_lab_runner`: 71 of 71 nodes unchanged).
- **One copy following the slice** replaced the fan of copies at fixed steps. The fan dipped between copies
  for a thin landmark (the range: down to 41% at 30 degrees from 20 m), needed a step setting, and made
  dozens of hidden copies. One copy, turned each frame to the angle at which the slice passes through its
  middle, holds the Watchstone exactly (13.2k pixels at every turn from 20 m; its middle 0.000 m from the
  slice at 10-60 degrees in the lab) for 14 us a frame.
- **Near is the landmark itself.** Within `near_margin` (8 m) of its bounds the real landmark is drawn (the
  copy has no collision): the 10 m rows above fall off at steep turns for that reason, as the landmark
  itself would.
- **Deep things recede.** An extruded landmark seen through a turned slice is drawn at d / cos t (twice as
  far at 60 degrees) and stretched along the view: World-deep keeps the Watchstone in the slice but small.
  The wrap keeps it at its own distance.
- **The bearing of an off-axis landmark** in a wrap round the area's middle narrows by cos t as the slice
  turns (the mountains do the same): the range, off to one side, drifts toward the middle of the view.
- **Collisions.** A deepened box is hit exactly where its new depth says (a ray along W: faces at +-0.70
  before, +-6.00 after); a body walked into the camp at W 4 is stopped with the Optimiser and passes through
  without; a ray down through the wrap's copy hits the floor, not the stone.
- **Editing.** A chunk and a stone moved 3 m in a copy of the Watchstone's own scene: the merged stones moved
  by exactly 3 m x 648 vertices, and the wrap's copy draws them.
- **Cost.** Made in 1-4 ms per landmark; the wrap's per-frame work 14 us at most; GPU in the lab unchanged
  (0.70 ms off and on, flat and turned 30).

### The wrap, third form: where it is on the flat slice (7 Oct, in the pen)

The one copy turned round the area's middle held a landmark straight ahead exactly, but in the pen the
Watchstone slid out of frame when the slice turned across the line to it: a ring round a centre narrows the
bearing of anything off to one side (the probe, `_probe_pen_wrap_runner.gd`: from the meadow looking west,
the slice turned 50 in the world's zw, the copy was drawn but out of the view). The wrap now draws the one copy
where the landmark is on the flat slice through the camera: lifted to the camera's W, then turned about the
camera by the least turn taking W to the slice's normal. For a turn in one plane (as the rigs turn) that is the
very turn of the slice, so the camera sees what it saw flat: in the lab 0.000 m off the slice and within 0.26
degrees of the flat view to 60 degrees (the rest is the camera, behind the player, coming nearer); from the
pen's meadow, where the ring lost it, within 1.2 degrees to 60. Its settings became the turn it follows to
(`wrap_arc`) and the W wrap length in metres (`wrap_length`: how far through W either side it follows you).
Also tried: turning by the camera's own frame against the flat frame nearest it; with the camera pitched it
drifted 3.7 degrees by 60.

## Into the pen (plan steps 87-96)

| | Before (`pen_trees_4d.gd`) | With the W tools |
|---|---|---|
| Plants / copies through W | 104 / 259 (+-4.5, +-9) | 104 / 458 (Turnable forest, to +-18) |
| Planting's GPU, flat (5 views) | 2.34 2.91 3.64 1.15 2.87 ms | 1.44 2.20 2.37 1.01 2.25 ms |
| Planting's GPU, turned 20 | 2.06 2.24 2.58 0.69 1.49 ms | 1.55 1.66 2.05 0.45 1.31 ms |
| Cull loop | 600-680 us | 105-150 us |
| Physics (all copies solid / near the player's W only) | | 1.66-1.84 / 1.14-1.29 ms (no copies: 0.92-0.96) |

- **Trunks you bump into.** Every body costs every move a check (the engine's physics looks at them all):
  458 solid copies cost 0.7 ms of physics. A copy's trunk is now in the physics only while the player is
  within 3 m of its W (89 of 458 at W 0); walk to a copy at W 12.9 and its trunk stops you, walk back and it is
  out again (`_verify_pen_wtools_runner.gd`). The trunk collider is as deep in W as the slab trunk you see.
- **The Watchstone** (Skyline): 198 parts in DEV (its blockout and the clay), 20 in ART, deepened to 4 m and
  wrapped. **The range** (Skyline): built in W, left exactly as it is, wrapped. **The camp is left out**: it
  stands at W -2.5 on purpose (the egg hunt's lanes), and deepening it would put it in the farm's own slice.
  **Trym's shed** is built in W (walls across W at +-1.7): the Optimiser would leave it as it is anyway.
- **The look.** Switched DEV to ART and back with the slice turned (the copy showing, the landmark hidden):
  the same meshes drawn and copied as when switched flat. The look's own tests (`look/_verify_look_runner.gd`,
  nine groups, fifty switches, the cinema, the cave, a save) and the journey (22 of 22, the cave in and out in
  both looks) pass.

The reach runner with the third form (the viewer as the camera; turns 0 / 10 / 20 / 30 / 40 / 60 along the view):

| Skyline, third form | 10 m | 20 m | 40 m |
|---|---|---|---|
| Watchstone | 74709 73730 70069 59296 26956 5385 (near: itself) | 13269 13268 13218 13274 13274 13271 | 2729 2728 2713 2730 2730 2727 |
| Camp | 27703 24267 21091 11925 615 0 (near: itself) | 1782 2065 1836 1894 2034 1939 | 410 419 418 409 418 421 |
| Range (built in W) | 4625 4438 4437 4437 4437 4437 | 1092 1064 1064 1064 1061 1064 | 273 269 269 270 268 266 |

The range now holds 96-98% at every turn (the copy is cut at the range's middle W, +0.08, the flat slice at 0).
