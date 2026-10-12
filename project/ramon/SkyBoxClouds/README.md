# SkyBoxClouds — 4D volumetric-style cloud deck

**Update (2026-09-07): the skydome half of this folder is gone.** The original
milestone-1 dome (`scripts/skydome_4d.gd`, `shaders/skybox_sky.gdshader`, and
the throwaway `_verify.gd` that tested it) predated the 4D module's now-native
`WorldEnvironment4D`/sky-material system and has been deleted — use
`GradientSkyMaterial4D`/`PhysicalSkyMaterial4D`/`PlainSkyMaterial4D` via
`WorldEnvironment4D` instead (see `simplex_grid_test.tscn`/`simplex_pillar_test.tscn`
for a scene already migrated to that). What remains here — the mesh-based
"clouds built from actual 4D geometry" approach below — is a genuinely
different, still-valuable technique and is being kept.

## Files

- `skybox_clouds.tscn` — test scene: `Node4D` root, the clouds, a `Camera4D`.
- `scripts/cloud_field_4d.gd` — `@tool` generator for the clouds.

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
- If clouds read too angular, step `blob_shape` up to `CELL_600` for a smaller
  count rather than adding more 24-cells.
- Consider adding a native `WorldEnvironment4D`/sky material to
  `skybox_clouds.tscn` now that the old geometric dome is gone, matching what
  `simplex_grid_test.tscn`/`simplex_pillar_test.tscn` already do — this scene
  currently has no sky behind the clouds at all.
