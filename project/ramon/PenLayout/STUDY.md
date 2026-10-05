# Pen layout: the study (6 Oct 2026)

Before the pen's layout changes: what the pen scene is now, and what Aaron's new fence
(`FenceGenerator4D`, 4 Oct) does, in 4D, in volume view and across its parameters. Nothing in
`chickenpen/` was changed. The pen was only loaded by the runners in `scripts/`, with the grass off
for these runs (Ramon: "we dont need to take it in consideration yet").

## 1. The pen scene now

`chickenpen/playable_world.tscn` is one 1.5 MB file:
- 672 nodes, 762 inline sub-resources (mostly baked meshes and materials) and 89 external files.
- Two pieces are already their own scenes: Nike and the wolf.
- Everything else sits in one file:
  - **World:** 36 children, including the buildings, the people, the crows and the lookout.
  - **Pen:** the fence, the coop, the upgrades and the return logic.
  - **UI:** 37 controls.
  - **Systems:** 41 nodes.

The places (`img/01_layout_map.png`, from above, about 80 m across):
- They spread over roughly x -20..13, z -36..4, all at W 0, around the pen at (0, -11).
- The W-side things are the chickens (they wander between W -4 and +4), the lookout's animals (W
  -8 and +1.5) and the pickups.

## 2. The new fence: FenceGenerator4D

Aaron Franke, 4 Oct: C++ in our own engine module (`engine/modules/quantum_horizon/model/fence/`),
with unit tests. A 3D fence follows a line on the ground. This one follows a surface in the 3D
ground of a 4D world (x, z and W), the "seed":
- each face of the seed becomes a stack of beams (the rails)
- each edge becomes a rib (a vertical bar)
- each corner becomes a post
- large faces get filler ribs and posts about every `desired_spacing_meters`

It is a true 4D volume, so every slice of it is a proper cross-section, as Ramon put it.

**Where the shape comes from** (`input_shape_type`):
- a box
- star-shaped corner points (`fence_corners`)
- movable guide-post nodes (`FenceGuidePost4D`, dragged in the editor)
- a 3D mesh (modelled in Blender, Y up becomes W)
- a ready-made 4D poly mesh

Corners may sit at different heights: the beams shear to follow uneven ground.

**Output:** a tetra mesh, in three surfaces (posts, ribs, beams), each with its own material. It
builds on a worker thread when `update_automatically` is on, or on demand. `is_global_point_inside()`
says whether a point is inside the footprint, at any height.

**What it does not do:** collision. The pen's fence has six hand-placed box walls under it
(`Pen/Fence/Collision`: four in x and z, two in W at -4 and +4). Physics is boxes only, so a fence
that is not a box (octagon, diamond) cannot get exact walls. Gameplay containment should use
`is_global_point_inside()`, with box walls only where a box fits.

**The pen's fence as set:**
- a box 8.4 x 7.6 m, 8 m deep in W (-4 to +4)
- posts 1.1 m tall and 0.15 m thick
- filler every 1.5 m
- three rails
- saved with `update_automatically` off, so the baked mesh is stored in the scene

It is 11,760 tetrahedra (posts 8,256, ribs 3,072, beams 432) and costs 0.03 ms a frame.

## 3. Findings: what broke when the fence was swapped

The old fence was a GDScript node (`scripts/pen_fence_4d.gd`). Its API: `extend_x/z_*`, `height`,
`contains_point()`, `interior_bounds()`, `random_interior_point()`. Aaron's swap (437ab8c) replaced
it with the C++ node, which has none of these. It also removed the `fence_path` links of eight
nodes that called them:
- the three crows (they no longer perch on the fence)
- `Pen/Return`
- `UI/SlicePlane` (the slice diagram's pen outline)
- `Systems/Debug` (the debug resize keys)
- `Systems/Celebration` and `Systems/WolfRaid`, set to empty

Only `nike_antics.gd` was moved to the new API.

Measured in the running pen:
1. **No chicken can be counted as returned.**
   - The pen logs "PenReturn: fence_path resolves to nothing - no chicken can ever be returned
     (item 82)".
   - `Pen/Return` is the only thing that calls a chicken's `on_landed(true)` and the manager's
     `note_returned`.
   - So the pen's core loop has not counted a return since 4 Oct.
2. **The fence does not know its inside.**
   - `is_global_point_inside()` returns false even at the pen's middle.
   - With `update_automatically` off, the footprint is never built when the scene loads.
   - Aaron's docs say exactly this: no footprint until the first update.
   - Nike's fence logic depends on that call, so it never sees the pen.

Putting the links back is not enough: the scripts would call methods that no longer exist. The fix
is one of these two:
- **(a) A small adapter:** the old API answered from the new fence (`box_size` for the extents,
  `is_global_point_inside` for `contains_point`, a random point tested against the footprint for
  `random_interior_point`), plus one update of the footprint at load.
- **(b) Six scripts moved to the new API.**

This is a pen change, so it is Ramon's call. It also belongs with the new layout.

## 4. How it looks in 4D

**Slicing** (`img/02_fence_by_w.png`: the pen's fence, 3/4 view; `img/03_fence_from_above.png`):

| W | What the slice shows |
|---|---|
| 0 | the ordinary rail fence |
| 0.8 | the sides go **solid**: a layer of filler ribs runs along them there; the layers are every 1.6 m of W, at -2.4, -0.8, 0.8 and 2.4 |
| 2 | thin rails again |
| 3.95 to 4.0 | the fence's W face: an **egg-crate grid filling the whole pen floor** |
| 4.1 | nothing: past the fence in W |

A player inside cannot reach W 4: the W walls stop them. But a tilted slice, or a player outside
the pen at W 4, does see the grid. Both are the proper 4D shape, and the layout should decide where
they show:
- choose the W depth and spacing so a solid layer does not land where people stand
- or keep the W faces where nobody slices

Tilting the slice 20 to 45 degrees keeps an ordinary rectangle near the pivot: a box fence runs
straight through W.

**Volume view** (`img/04_pen_renderers.png`; `img/07_slice_vs_volume.png` on a white floor):
- **Combined** (the pen's P) draws the slice and a faint projection of what lies near in W. On a
  clean floor the fence's other W layers show as a haze inside the pen. In the pen the grass and
  the ground hide most of it. With the camera turned 35 degrees into W, the fence trails off as a
  ghost of layered rails: the 4D volume.
- **Projected** draws all of the 4D scene at once (ground and hills hidden here, they fog it). The
  fence becomes nested rails, the W depth stretched across the screen when the camera is turned
  into W (`img/05_fences_projected.png`: the pen's fence, one 1 m thin in W, an octagon, a diamond).

A trap found on the way: the pen's Lookout puts the current camera back on its own renderer every
frame, so a script that switches renderers in the pen has to go through the Lookout's
`set_projection()`.

## 5. The parameters

`img/06_parameters.png`: the pen's fence and eleven variants, built fresh, each at W 0, 2.5 and
3.98. Build times are on the main thread (`update_fence_mesh_now`); in play it builds on a worker
thread.

| Variant | Built in | Tetrahedra | What it does |
|---|---|---|---|
| 01 the pen's fence | 69 ms | 11,760 | rails; the egg-crate grid at the W face |
| 02 engine defaults (10 x 10 x 10, spacing 2) | 60 ms | 10,608 | bigger, thinner |
| 03 no filler (spacing 0) | 6 ms | 1,392 | corner posts only; the W face becomes one **solid slab** |
| 04 dense filler (0.75 m) | 268 ms | 39,408 | more posts; at W 2.5 a solid layer; fine grid at the face |
| 05 beams 0 | 67 ms | 11,328 | posts and ribs only |
| 06 five rails | 69 ms | 12,048 | five rails |
| 07 coverage 1 | 68 ms | 11,760 | solid walls |
| 08 chunky posts (0.3) | 68 ms | 11,760 | thicker; the filler layers catch more W (solid at 2.5) |
| 09 thin in W (1 m) | 38 ms | 6,768 | there only at W 0 ± 0.5 |
| 10 octagon (radial points) | 82 ms | 17,232 | an octagonal pen; octagonal grid at the face |
| 11 diamond through W | 129 ms | 16,715 | **the pen shrinks as you leave W 0** and is a single post near W ±4.5 |
| 12 one corner raised 0.6 m | 183 ms | 23,254 | rails follow the slope; faces split into flat triangles |

What matters most for the layout:
- `desired_spacing_meters` sets where solid layers appear in W, and how heavy the W face is.
- The W depth (`box_size.z`, or the corners' W) decides where the fence exists in W at all.
- Non-box shapes are where the "proper 4D" shows best (the diamond), and where box collision
  fits worst.

## 6. Splitting the pen into scenes (the Discord question)

Yes. Godot's scenes are what Unreal's sublevels and Blueprints are: any branch of the tree can be
saved as its own `.tscn` and placed in the main scene as an instance (in the editor: right-click
a node, **Save Branch as Scene**).

**Good first candidates:**
- the Shed with Trym and his laptop and door
- the range booth with its master
- the professor
- the lookout site
- the pen (fence, coop, upgrades, return)
- the UI (37 controls)
- the Systems (41 nodes)

Each then has its own file, so two people editing different buildings no longer touch the same
1.5 MB file.

**Things to know:**
- Paths between them still work: they are resolved in the assembled tree. But a path set in the
  main scene into an instance's insides needs that instance's children made editable, or the
  wiring moved into the sub-scene.
- Do it in one commit, when nobody has unpushed edits to `playable_world.tscn`, and announce it:
  the split itself is one large change everybody has to take.

Aaron's point (open and save each scene in Godot after Claude edits it) fits this: the split is
best done through the editor's own save, so the files come out the way Godot writes them.

## Runners

- `scripts/_study_pen_fence_runner.gd`: the pen read only. Layout, the fence's settings and mesh,
  slices at six W, from above, tilted, the frame cost.
- `scripts/_study_fence_params_runner.gd`: twelve fences in a bare space, timed, counted and filmed.
- `scripts/_study_fence_projection_runner.gd`: Projected views of four fences, and the pen in
  Cross-section, Combined and Projected.

Frames go to `smoke_test_output/pen_layout/`.
