# The 4D module bump, and why it is not merged yet

**Status as of 24 September 2026: deliberately deferred. Not forgotten.**

## What the situation is

`engine/modules/4d` is a submodule — a recorded commit id, not files in this
repo. `RamonPrototypes` records **`7533287`**. `origin/main` records
**`d9e2227`**, bumped there by Aaron on 22 September along with an LFS fix.

Merging `main` into this branch moves that pointer, and the next
`update_submodules` run checks the newer module out and rebuilds against it.

## Why it was not done on the day

There are **19 commits** between the two, and they are not all housekeeping:

```
d9e2227  Add import of HoxelDraw .hox and .4do files
74639a4  Major feature: Implement MultiSurfaceMesh4D
a6b25a2  Fix tetra mesh transform incorrectly clearing boundary normals
1df340b  Refuse to build 3D surfaces that would overflow Godot's rendering server
ce2b141  Add Mesh4D.proxy_mesh_3d_marked_dirty signal
1be110a  Keep all data when converting to Array versions of Poly and Wire meshes
...plus a dozen G4MF import/export changes
```

`MultiSurfaceMesh4D` is a change to the **mesh class hierarchy**. That is the
same area that previously split `Mesh4D` into `SingleSurfaceMesh4D` and broke
callers — see `engine_gotchas.md`. The chicken pen leans on that hierarchy
everywhere: `BoxTetraMesh4D` for the fence, the coop, the troughs and the
confetti; `ArrayTetraMesh4D` for every lofted creature; the loft rigs; and the
twelve baked goat meshes now sitting in `theatre/baked/` as saved
`ArrayTetraMesh4D` resources, which are the case most likely to go stale if the
class changes shape.

The two fixes in there are ones we probably WANT — the tetra-normals fix and
the rendering-server overflow guard both touch things this project does.

## The risk, stated plainly

This is the one change that could put the pen in a state where nothing runs. It
is not a merge, it is a job:

1. Stash or commit the two local edits inside the submodule
   (`editor/viewport/editor_transform_gizmo_4d.cpp`, `nodes/camera_4d.h` — they
   add a focal-length macro for the editor gizmo and no GDScript depends on them)
2. Merge `main`, update the submodule
3. **Full engine rebuild** — the slow part
4. Run the whole runner suite and fix what moved

## Why it should not be left much longer

Staying 19 behind only makes the catch-up harder, and a stale pointer is exactly
how the obstacle course ended up broken before: the branch recorded a module
older than the one being built against, so a fresh clone got code that would not
compile. The gate is 16 October. Doing this at the start of a session with room
to react is very different from discovering it the week of the deadline.

## What Aaron should know

The concern is not that the bump is wrong — it is that nobody has run the pen
against it. If the mesh hierarchy change has a migration note, or if he already
knows whether `BoxTetraMesh4D` / `ArrayTetraMesh4D` callers are affected, that
would save a rebuild-and-find-out cycle. Worth asking him before spending the
build time.
