# Portal cutting, version 3: chunked voxel walls

> **BUILT 2026-08-19 — `voxel_chunk_test.tscn`.** Shoot the far wall anywhere,
> any number of times; overlapping cuts merge into one opening; every opening
> heals shut and the wall returns to exactly its original tetrahedron count.
> Measured: 21 chunks build in 1,093 ms, a carve rebuilds 4 chunks in ~285 ms,
> ~21,500 tetrahedra, 6,144 colliders, 7 rebuild events per shot across the
> open/hold/close cycle. The remaining problem is that cost, not the look — see
> "What to watch" below.

Written 2026-08-19 after `voxel_cut_test.tscn` proved the cut quality but not the
architecture. This is the drawing-board pass Ramon asked for: what is actually
wrong, what the literature says about it, and what the next version should be.

## What we have, and what it cannot do

`voxel_cut_test.tscn` produces a genuinely clean boolean hole — a smooth round
bore, ~33 rim facets, 186 ms, 3,600 tetrahedra, 280 colliders. Dual contouring
does exactly what it promises.

But the architecture around it is wrong in three ways:

1. **One patch per wall.** Shooting again *moves* the patch; you cannot make
   holes all over a wall the way you can in `portal_test_chamber.tscn`.
2. **Cuts are not cumulative.** Each patch is built from a fresh field with a
   single ball in it. In VoxelMining, every chip is another AIR layer on a
   persistent field, so a new chip interacts with all the previous ones — the
   thing that makes mining feel good. Here, a second cut on the same wall throws
   the first away.
3. **Boxes and voxels are mixed**, and everything they touch produces artifacts.

## The artifact, as measured rather than guessed

The black band across the wall after a cut:

- **Render-only.** A raycast through the band reports solid wall at every height
  (2.6 m through 3.6 m, all hit at z = -8.00). Collision is continuous; the
  renderer is not drawing a strip.
- **Caused by the cut**, not the room. An uncut room renders spotless; the band
  appears the instant a window is opened, at the window's top edge, and runs the
  full width of the wall.
- **Not a butt-joint seam.** Overlapping the framing pieces by 2 cm — which did
  fix the earlier stripes in the box scene — changes nothing here.
- **It is a downward-facing surface.** The flat shading term is
  `dot(normal, up) / 2 + 0.5`, which maps a normal of straight-down to exactly
  zero, i.e. pure black. The band is something whose normal points down being
  visible where it should be hidden — consistent with the underside of the piece
  above the window showing through.

Still open, and worth one focused session rather than more guessing. But note
that **every artifact in this whole effort has come from the same place**:
box geometry meeting cut geometry and relying on faces lining up exactly.
Stripes at strip seams, shards where the collar interpenetrated the wall, the
square-hole-under-a-round-collar mismatch, and now this band. The fix that
removes the entire class is to stop mixing the two.

## What the literature says

- **Chunk seams in dual contouring are a solved problem.** Chunks meshed in
  isolation disagree at their shared boundary, and the standard answer is either
  explicit seam geometry built from the neighbours' boundary nodes
  ([Nick's Voxel Blog](http://ngildea.blogspot.com/2014/09/dual-contouring-chunked-terrain.html)),
  or **ghost cells** — each chunk samples one cell beyond its own bounds so both
  sides see identical data
  ([the ghost cell pattern](https://medium.com/@willdavis84/the-ghost-cell-pattern-0e9e6ae67b5e)).
- **Ghost cells are free for us.** The hard part of ghost cells is keeping the
  halo in sync, and the same source notes it disappears when the field is a pure
  function of position, as with procedural noise. Ours is exactly that: a slab
  SDF minus a list of carve balls. Two chunks sampling the same world point get
  the same number by construction, so there is nothing to exchange.
- **DC needs no special seam handling at uniform resolution** — the seam problem
  in the literature is overwhelmingly about differing LOD between neighbours,
  which we do not have.
- **4D specifically**: Miegakure builds its world from tetrahedral 4D meshes
  sliced to 3D triangles, the same pipeline as ours, and its own writeups note
  that a static 4D asset costs about what a 3D one does *after projection*,
  while anything that changes has to have its projection recomputed
  ([Marc ten Bosch / Miegakure](https://marctenbosch.com/news/)). That matches
  what this engine does: `instance_set_ignore_culling(true)` means every
  tetrahedron is vertex-shaded every frame whether or not it intersects the
  slice, so **total tetrahedra in the scene is the GPU budget**, not visible
  geometry. Keeping the cut geometry local is therefore a rendering concern as
  well as a CPU one.
- Manifold/2-manifold DC variants exist for topology guarantees
  (Schaefer, Ju & Warren 2007; tetrahedral-decomposition DC) and are worth
  reaching for only if the cuts start producing non-manifold cells.

## Version 3: the wall IS the voxel field

Stop patching boxes. A portalable wall becomes a **grid of voxel chunks**, and
nothing else.

```
wall = chunk grid (say 4 x 3 chunks across its face, 1 deep)
each chunk = anisotropic field, ~8 x 8 x 5 x 5 = 1,600 points
             + 1 ghost cell of overlap on every face axis
field(p)   = slab_sdf(p) minus every carve ball recorded so far
```

- **Shoot anywhere, any number of times.** A shot appends a ball to the wall's
  carve list.
- **Cumulative by construction.** Every chunk samples the whole list, so a new
  cut interacts with old ones exactly as chipping does in VoxelMining — overlap
  two shots and you get one merged opening, with the QEF resolving the join.
- **Cost is proportional to the edit.** Mark dirty only the chunks whose bounds
  intersect the new ball expanded by one cell; re-contour those. One shot
  touches one or two chunks, so ~40–80 ms rather than a whole-wall rebuild.
- **No butt joints anywhere.** The wall has no box pieces to line up with, so
  the entire artifact class above cannot occur. Chunk boundaries are handled by
  ghost cells, which the pure-function field makes automatic.
- **Collision** stays per-exposed-voxel `BoxShape4D`, rebuilt per dirty chunk
  only — the physics engine reduces everything else to a single box anyway.

### What to watch

- **Total tetrahedra**, because of `ignore_culling`. An uncut wall of 12 chunks
  should contour to almost nothing (two flat faces), so the budget is spent only
  where cuts are.
- **Initial build** of 12 chunks at load. Cache it, build it off the main
  thread, or accept it once per scene load.
- **w extent.** Contouring skips boundary cells, so the slab must be closed
  inside the field along w or the wall will have open ends. Currently it spans
  the whole field and the ends are open — invisible today because they are 12 m
  away, but wrong.

### What this does NOT need

The anisotropic fork already exists (`patch_field_4d.gd`, `patch_contour_4d.gd`)
and is what makes chunk-sized fields cheap. No further engine work, no C++, and
no change to anything shared.

Related: [[project_portal]], [[project_voxel_mining]], [[project_engine_gotchas]]
