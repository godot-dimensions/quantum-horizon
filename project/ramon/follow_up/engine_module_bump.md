# The 4D module bump — done, and what it cost

**Status: merged 24 September 2026. `origin/main` in, submodule now at `d9e2227`.**

Kept as a record because the *next* bump will look exactly like this one.

## What moved

`engine/modules/4d` went from **`7533287`** to **`d9e2227`** — 19 commits, merged in
along with `origin/main` as `5704d3d`.

The worry was `74639a4 Major feature: Implement MultiSurfaceMesh4D`, a change to the mesh
class hierarchy. The same area previously split `Mesh4D` into `SingleSurfaceMesh4D` and
broke callers (see `engine_gotchas.md`), and the pen leans on that hierarchy everywhere:
`BoxTetraMesh4D` for the fence, coop, troughs and confetti; `ArrayTetraMesh4D` for every
lofted creature and for the eleven baked goat meshes in `theatre/baked/`, which were the
case most likely to go stale if the class changed shape.

**It did not break any of it.** `MultiSurfaceMesh4D` was added alongside the existing
classes rather than replacing them.

## How it was verified

Twenty-eight runners against the rebuilt engine:

- 23 reported `0 FAIL(s)`
- `_verify_celebration_runner` and `_verify_talkmotion_runner` reported `ALL PASS`
- `_verify_mithra_runner` hit only the known headless limit — `save_png` on a null
  image, because the dummy renderer has no texture. Not a bump failure.
- `_verify_blob_colours_runner` reported 1 FAIL, traced to a **pre-existing** dead
  `NodePath("../../World/LoftedGirl")` in `people_paths` on `UI/SlicePlane`, last touched
  in `62568de`. Removed; the runner now expects four figures, not five.
- Five diagnostic runners print measurements rather than a FAIL count. `_verify_catch_runner`
  and `_verify_planted_feet_runner` print a "verdict" below their own threshold, and did so
  before the bump as well — the catch gap is headless `_process`/`_physics_process` skew,
  and the foot-plant error was already 0.037 against a 0.02 threshold when
  `chickenpen_walk_polish.md` was written on 21 Sep.

## The two local edits inside the submodule

`editor/viewport/editor_transform_gizmo_4d.cpp` and `nodes/camera_4d.h` add a
focal-length macro for the editor gizmo. They re-applied cleanly across the bump — 45
lines, no conflict markers — and are still uncommitted inside the submodule on purpose.
No GDScript depends on them.

## The lesson for next time

Doing this took one rebuild and one runner sweep. Staying 19 commits behind was the
expensive state, not the catching up. Bump early in a session with room to react rather
than in the week of a gate.
