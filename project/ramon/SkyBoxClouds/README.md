# SkyBoxClouds — 4D skydome and volumetric-style cloud deck

Milestone 1 of the skydome/clouds plan: a rounded 4D sky shell carrying a
vertical colour ramp, visible **in the editor's "4D" tab**, with no engine
change and no fork. Clouds are milestone 2 and are not here yet.

## Files

- `skybox_clouds.tscn` — test scene: `Node4D` root, the dome, a `Camera4D`.
- `scripts/skydome_4d.gd` — `@tool` generator for the dome.
- `scripts/cloud_field_4d.gd` — `@tool` generator for the clouds.

Neither declares a `class_name`, on purpose. Windows resolves `res://` paths
case-insensitively and Godot does not, so a stale editor tab remembering an
older spelling of this folder made Godot load one file twice under two path
strings — and the second copy's `class_name` collided with the first, failing
the parse with "hides a global script class". Nothing needs a global name here:
the scene references both scripts by path, and `_verify.gd` loads them
explicitly.
- `shaders/skybox_sky.gdshader` — sky copy of the engine's cross-section shader.
- `_verify.gd` — throwaway headless check. Delete once the scene looks right.

## The two decisions worth knowing

**The sky is geometry, not a `WorldEnvironment`.** `CrossSectionRenderingEngine4D::setup_for_viewport()`
instantiates its own `World3D` and calls `viewport->set_world_3d()` with it, so
the edited scene's environment has no path into what the 4D tab draws. That is
why the Isoclynic Sun's sky only ever appeared in Play, and it is what the
parked engine bridge was fixing. 4D meshes are built straight into that private
world, so a geometric sky previews live with nothing extra.

**The shader is a project-side copy, with exactly two deltas.** The vertex
stage does the 16-case cross-section slicing and must stay byte-identical; the
copy changes only:

1. `cull_disabled` — we are inside a closed shell and which winding faces the
   camera is not derivable (same reason `DualContour4D` carries `flip_winding`).
   600 tetrahedra of overdraw is free.
2. no lighting term — the stock fragment multiplies by `dot(normal, up)/2+0.5`,
   computed from the sliced triangle's own winding. On an inward-facing shell
   that drives the zenith to literal black, and no ramp value survives being
   multiplied by zero.

Living in the project means no fork and no conflict with Aaron's in-flight 4D
lights. If his work changes the upstream vertex stage, re-copy it here.

## Why the 600-cell

Measured tetrahedron counts (see `ramon/voxel_port/polytope_budget.gd`):

| mesh | tets |
|---|---|
| 5-cell | 5 |
| 16-cell (built-in) | 16 |
| tesseract (built-in) | 40 |
| 24-cell | 96 |
| **600-cell** | **600** |
| 120-cell | 3240 |

Its 120 vertices already lie on a common 3-sphere, so scaling to `radius` gives
a round dome with no projection step. 600 tets is 2% of the voxel terrain's
28,140 — irrelevant for one dome, which is why roundness wins here. For *clouds*
the arithmetic inverts: cost scales with total 4D mesh size because of
`instance_set_ignore_culling(true)`, so the 24-cell (96) is the workhorse there
and the 600-cell is for a few hero blobs only.

## Colour path

`TetraMaterial4D` pushes exactly two uniforms, `albedo` and `albedo_texture`,
and never reads `albedo_color_array` — per-vertex and per-cell colours render
pure white. So a `Texture3D` sampled by cell UVW is the only way to vary colour
across a tetrahedral surface. The shader carries `uvw` as a `varying` and
interpolates it across the sliced polygon, so the ramp is smooth rather than
per-cell flat.

The gradient bakes to a 1 x N x 1 texture; only the vertical axis carries
information. UVW is `(0.5, 0..1, 0.5)` — 0 at the nadir, 1 at the zenith. The
default gradient matches the Isoclynic Sun's three stops so the two read as one
world.

## Clouds

`scripts/cloud_field_4d.gd` scatters convex polytopes at jittered points and
merges them into a single mesh. Worley/Voronoi noise is distance-to-nearest-
feature-point, so this is the same structure as the noise, evaluated as
geometry — which means the stock shader suffices, it previews in the editor,
and the 4D behaviour is free: each blob's cross-section swells from a point and
shrinks back as w passes through it, so the sky boils as you slice-rotate.

`blob_shape` trades roundness against budget. At 100 blobs: 16-cell 1,600 tets
(6% of a terrain), 24-cell 9,600 (34%), 600-cell 60,000 (213%). The 24-cell is
the default for that reason.

Clouds use the **stock** colour path, unlike the dome — they are seen from
outside, so the engine shader's `dot(normal, up)` term helps them read as solid
instead of hurting. And they are **opaque**: overlapping transparent hulls is
the coincident-surface case suspected behind the voxel port's visible holes.

## Two engine gotchas found the hard way

**`Camera4D.rendering_engine` defaults to `""`**, and `RenderingServer4D`
resolves an unknown name by falling through to `_rendering_engines.begin()`—
whichever registered first, which is the wireframe engine. Any `Camera4D` in a
scene you intend to *play* needs `rendering_engine = "Cross-section"` set
explicitly. The editor's 4D tab picks its own, so a scene can look right in the
editor and render as wireframe in Play.

**`ArrayTetraMesh4D::merge_with` mis-sizes the UVW map.** It resizes to
`end_cell_index_count / 4`, but the map holds one entry per cell-*vertex*
(`TetraMesh4D` asserts `texture_map_count == cell_indices_count`), so the write
offset goes negative and every merge spams `Index p_index = -N is out of
bounds`. The boundary-normals block beside it divides by 4 correctly, because
those really are per-cell. Worth reporting upstream. `CloudField4D` sidesteps it
by clearing the template's texture map first — the block is skipped when both
meshes have an empty one.

## Next

- Tune: blob count, size range, altitude band, and how far clouds spread in w
  (`field_extent`) — w spread is what governs how fast the sky changes as you
  slice-rotate.
- `flip_winding` on the dome should still be inert (culling is disabled); it
  only starts mattering if a lit sky variant is tried.
- If clouds read too angular, step `blob_shape` up to `CELL_600` for a smaller
  count rather than adding more 24-cells.
