# Voxel port — kickstart notes

Purpose of this file: a self-contained briefing so a future session can pick up
`project/ramon/voxel_port/` without re-deriving anything. Written 2026-08-12,
the day the port was built, updated 2026-08-13. The headline unsolved problem is
**holes in the generated surface** — read "The open problem" before touching the
contouring. As of 2026-08-13 the mesh is measured closed, so the cause is
rendering, not contouring; the current lead is coincident ground/water sheets
and it is untested.

## What this is

A port of the generation half of Andrew's WebGL2 4D mesh demo, which lives at
`D:\depot\4d_mesh_demo-non-free\4d_mesh_demo-non-free\` (generate.js, mesh.js,
svd.js, shaders.js — ~1300 lines). Its `index.html` marks it all rights
reserved; Andrew is on the team, so reuse is a conversation, not a blocker, but
get explicit sign-off before anything ships. The port is written from the
techniques, not copied.

Four scripts under `voxel_port/scripts/`:

- `voxel_field_4d.gd` — the field. A `size^4` grid of (material, density) plus
  the exact surface crossing on every grid edge. Layers composite in order.
- `qef_solver_4d.gd` — 4x4 one-sided Jacobi SVD + singular-value-clamped
  pseudo-inverse. This is what keeps sharp creases sharp.
- `dual_contour_4d.gd` — contouring. Face-connection graph, connected
  components, hexahedron → 6 tetrahedra.
- `voxel_terrain_4d.gd` — `@tool` orchestrator. Model library, mesh building,
  colouring, collision.

Scene: `voxel_port/voxel_port.tscn`. Generates on load in the editor, and
strips the meshes on `NOTIFICATION_EDITOR_PRE_SAVE` so the `.tscn` stays ~1 KB
instead of embedding 28,000 tetrahedra.

Baseline numbers at `grid_size` 12, `globewater,globe,cutoff`: 20,736 grid
points → 4,690 crossings → 7,517 vertices → 28,140 tets (20,184 ground / 7,956
water), ~19.3 MB of cross-section mesh, ~900 ms total.

## Engine facts established by reading source (don't re-derive these)

- **GPU slicing already exists.** `render/cross_section/tetra_cross_section_shader.glsl`
  slices tetrahedra to 3D in the vertex shader by exactly the demo's method — a
  16-case lookup on the sign of each corner's `w`. Per frame the engine sets
  five vec4 uniforms per mesh and nothing else. The demo's cleverest trick did
  not need porting.
- **Only two colour paths reach that shader.** `TetraMaterial4D::update_cross_section_material()`
  sets exactly two uniforms: `albedo` (only when the SINGLE_COLOR flag is set)
  and `albedo_texture` (only when TEXTURE3D_CELL_UVW is set). `albedo_color_array`
  is *never* read for tetrahedral meshes, so PER_CELL and PER_VERT both render
  solid white. This cost an afternoon; don't rediscover it.
- **Physics is AABB-only.** The module ships one engine,
  `AxisAlignedBoxPhysicsEngine4D`, whose header says: "Non-BoxShape4D shapes
  will work, but will be converted to boxes." A `ConcaveMeshShape4D` built from
  20,000 tetrahedra collapses to one box round the whole world. `generate_collision`
  is therefore **off by default** — it produced an invisible crate you couldn't
  walk through. The code is kept because the shape is correct and starts working
  the day a non-AABB engine lands.
- **Degeneracy threshold is derived, not guessed.** `Geometry4D::compute_inverse_metric_3x3`
  normalizes to a correlation matrix and requires `det > CMP_EPSILON` (1e-5).
  That determinant equals (volume / product of edge lengths) squared, so the
  engine's real cutoff is `sqrt(1e-5)` = 0.00316. `MIN_NORMALIZED_VOLUME` is
  0.006, roughly 2x that.
- **`instance_set_ignore_culling(true)`** — every tetrahedron is vertex-shaded
  every frame whether or not it intersects the current slice. Cost scales with
  total 4D mesh size, not with what's visible. This is the argument for
  chunking (see below).

## The open problem: holes in the surface

Visible as gaps you can see through, worst on flat/faceted regions.

**Fixed so far:** winding was being decided per-tetrahedron, against the
field's surface normal. For slivers that test is numerical noise, so tetrahedra
*within one hexahedron* disagreed; a disagreeing one is wound backwards and
culled as backfacing. Measured 10.5% of hexahedra internally inconsistent.
Now the winding is voted on once per hexahedron (summing unnormalized
alignments, so big well-formed tetrahedra decide and slivers contribute ~0) and
all 6 inherit it by reversing the ring. Cross-hexahedron disagreement is now
0.44%.

**RESOLVED 2026-08-13 — the surface is closed. The 11,664 was a measurement
artifact**, not a defect. The holes you can see are real; the missing geometry
they implied never existed.

The original check identified a face by its three vertex *indices*. But the
contour deliberately emits one vertex per material pair at the same solved
position (`_emit_component_vertex`), so two tetrahedra can meet perfectly in
space while naming the same corner with different ids — and the check scored
every one of those as a hole. Re-run keyed on *position* instead
(`voxel_port/manifold_check.gd`, headless, still in the tree):

```
                        by index      by position
distinct faces            62,066          53,929
used twice (good)         50,392          49,638
used ONCE  (hole)         11,640               0
used 3+    (non-manifold)     34           4,291
degenerate (excluded)          0               0
```

**Zero boundary faces.** Supporting stats from the same run, all of which had
to be zero for that to mean anything, and all of which are:
`tetrahedra_degenerate 0` (the `MIN_NORMALIZED_VOLUME` sliver rejection never
fires, so no geometry is discarded), `hexahedra_incomplete 0` (every one of the
4,690 crossing edges got its full ring of 8 cells), and no face collapsed to a
repeated corner. Nothing is missing from the mesh.

So **the visible holes are not missing triangles**, and three suspects die at
once: vertex sharing, surface topology, and sliver rejection.

**Andrew's answer (2026-08-12), which pointed the right way:** the original
shows no visible gaps at `?size=12&model=globeWater,globe,cutoff`. On vertex
sharing he noted that `edge.vertices[cellCoord]` being per-primal-edge is not a
divergence risk, because `addMeshVertex` fans the same vertex out to every
relevant primal edge at once — the guarantee lives in the write, not the
lookup. The port does structurally the same thing. He did caveat that he had
not verified the tets' faces match perfectly, which is exactly the gap the
by-position measurement closed.

**Current lead — UNTESTED:** the 4,291 faces used 3+ times. In a clean surface
that is zero. It is non-zero because ground and water are geometrically
coincident over much of the globe: 3,553 of 7,517 vertices sit on a position
another vertex already occupies. One triangle therefore bounds both the ground
volume and the water volume, and both are rendered — opaque ground and
transparent water at identical positions. Z-fighting between two near-parallel
coincident sheets would look exactly like "gaps you can see through, worst on
flat/faceted regions."

**Next step, ~30 seconds:** regenerate with `model_layers` = `globe,cutoff`
(water off). Holes vanish → coincident sheets and transparency sorting, and the
fix is in how the two meshes are separated, nowhere near the QEF or component
detection. Holes persist → winding, and `flip_winding` plus the 491 contested
hexahedra are where to look.

Three theories tested and **ruled out** — don't repeat these:

1. *Mismatched fan diagonals.* Worked through the demo's `getFaceIndices` ring
   construction: the main diagonal is defined globally ("cell before the edge
   in all three directions" → "cell at the edge in all three"), and every quad
   face splits along the diagonal joining both-free-bits-0 to both-free-bits-1,
   symmetric across all three face orientations. Neighbours therefore derive
   the same diagonal. A centroid decomposition would have doubled the geometry
   and fixed nothing.
2. *The vertex-splitting key.* Was keying on the originating layer as well as
   the material pair; removing it changed the vertex count from 7,525 to 7,517.
   Eight vertices. Not it. (Change was kept anyway — it matches the demo, which
   keys on material pair plus the layer's altitude *function*.)

3. *Vertex sharing.* Was the leading suspect overnight, on the grounds that
   `_edge_cell_vertex` is keyed per *edge*, so two adjacent hexahedra on the
   same sheet look up their own edge's vertex in the four cells they share with
   nothing obviously forcing agreement. Killed twice over: by Andrew's
   explanation of `addMeshVertex` above, and by the by-position measurement
   showing zero boundary faces. The ~1.94 dual vertices per cell (3,869 cells →
   7,517 vertices) is legitimate — `globewater` at 0.37·size and `globe` at
   0.35·size are only ~0.24 grid units apart, so most surface cells genuinely
   contain two sheets.

## Deferred, roughly in value order

- **Altitude is normalised against the wrong reference.** The demo's altitude is
  relative to sea level (`dist / (SIZE*0.35) - 1`, zero at the base radius), so
  the shoreline lands mid-palette. `_altitude_at` divides by the grid half-span
  instead, putting sea level at 0.76 at `grid_size` 12 — which is why the planet
  reads as rock and snow with almost no sand. Two lines to fix, visibly better.
- **Slope loses the up/down distinction.** Demo uses `dot(normal, up)` across
  [-1, 1] so ceilings and floors sit at opposite ends of the texture. Ours is
  `1 - abs(dot(...))`, folding them together — cave roofs shade like floors.
- **Per-layer altitude functions.** The demo attaches one per layer. The
  plumbing exists here (`_edge_layer` in the field, `vertex_layers` in the
  contour) but was never wired up; `_altitude_at` applies one global rule with
  the `terrain_shape` enum as a stand-in. Doing this properly is what the two
  items above really want.
- **The `house` model.** The demo's only demonstration of placing authored
  geometry into the field — 13 half-spaces intersected via `min(...)`, "a small
  hypercuboid with a pyramid on top". Skipped during the port as low-value;
  that was arguably wrong, and it'd give something to walk up to.
- **Chunking with 4D slice-culling.** The thing the demo doesn't have and a game
  needs. Split the field into chunks, one `MeshInstance4D` each, hide any whose
  w-extent doesn't straddle the camera. Only ~1 in 18 tetrahedra contributes
  geometry at any instant, so ~94% of the per-frame vertex shading currently
  produces nothing.
- **Voxel-shaped collision that works today.** Given the AABB engine, the way to
  get real terrain collision is many small `BoxShape4D` nodes (~1,500–3,000 at
  grid 12) rather than one mesh shape. Chunky at voxel resolution, which
  arguably suits the aesthetic.

## Also worth remembering

- `cutoff` must be selected for anything reaching the grid edge, or the surface
  ends in ragged holes — contouring skips boundary cells outright. It's the
  last bit in `model_layers` for that reason, and the bit order *is* the
  composite order, so a bad layer ordering is unrepresentable.
- `noise_amplitude_fraction` interacts with `cutoff`: clipping is avoided when
  it's `<= 0.15 - 1.1 / grid_size` (~0.058 at 12). The default 0.2 is over that
  line deliberately, matching the demo. Flat spots on high peaks are this.
- For flat terrain use Plane Water + Plane + Spherinder + Cutoff, set
  `terrain_shape` to PLANAR, and raise `noise_amplitude_fraction` to 0.4 — the
  demo's plane value, which happens to fit the grid exactly with no clipping.
- `flip_winding` exists as a one-click escape hatch if the surface ever renders
  inside-out. It shouldn't be needed now.
- Diagnostics were run as throwaway `SceneTree` scripts under `voxel_port/` and
  deleted. Headless is the fast loop:
  `godot.windows.editor.double.x86_64.console.exe --headless --path project --script res://...`
  and `--check-only --script <file>` for a parse check.
