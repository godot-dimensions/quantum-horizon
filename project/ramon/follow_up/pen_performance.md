# Chicken pen performance — what it was, and what fixed it

**28 September 2026.** Follows Trym's measurement run of 27 September
(`RESULTS-2026-09-27.md`, §17, and `CHICKENPEN_REMESHING_FIX_BRIEF.md`).

## Result

| | before | after |
|---|---:|---:|
| mean frame | 76.26 ms | **2.46 ms** |
| fps | 13.1 | **406** |
| p99 | 91.42 ms | 3.17 ms |
| worst | 92.67 ms | 4.05 ms |
| physics ticks per frame | 4.57 | 0.15 |
| tetrahedra rebuilt per physics tick | 17,574 | **0** |

This machine (RTX 5080), editor build, 1280×720, vsync off, spawn point, nobody moving.
Trym's machine measured the same scene at 146 ms, about 1.9× this one, so his should land
around 5 ms. The ratios travel; the milliseconds do not.

## What it actually was

Trym's diagnosis was right in kind: the procedural animation was rebuilding meshes. His
harness reported **492 meshes rebuilding at 196 µs each**, which read as a scene-wide
problem. It was not.

`Mesh4D` emits `proxy_mesh_3d_marked_dirty` on every invalidation, under any renderer, so
connecting to it on every mesh counts exactly what the renderer rebuilds. Of 862 meshes,
**20 ever rebuilt**:

| mesh | tetrahedra | rebuilt |
|---|---:|---|
| 18 chicken legs | 720 each | every physics tick |
| Nike's hide | 7,008 | every second tick |
| the red cat's hide | 2,928 | whenever it walks |

~20,000 tetrahedra a frame, which is Trym's 97.8 ms. His harness saw ~499 proxy fetches,
but ~480 of them were free cache hits; the 196 µs average was those 20 rebuilds (~5 ms
each on his machine) divided across all 499.

**Why the physics number was the same problem.** His 8.0 physics ticks per frame is
exactly Godot's default `max_physics_steps_per_frame`. All three animals skinned in
`_physics_process`, so a slow frame owing several ticks re-skinned every leg several times
before it drew once. Fixing the rebuilds collapsed physics with it, as he predicted.

**The voxel rock was not a factor.** It never invalidates its mesh. Stripping its colliders
moved the frame by less than run-to-run noise.

## The fix

Skinning was only ever rigid motions blended — a thigh swinging about the hip, a shank
about the knee — written into the mesh's vertices every tick. Every write dirtied the
proxy. So each skinned mesh is now **cut once, on the first frame, into rigid pieces**, and
each piece rides a node whose **transform** carries the motion that used to be written
into its vertices. A transform change costs the renderer a matrix; a mesh change costs it
the mesh.

- `chickenpen/scripts/chicken_walker.gd` — each leg becomes a thigh and a shank.
- `chickenpen/scripts/strider_walker.gd` — each hide becomes a body plus a thigh and shank
  per leg (Nike and both cats).

The band either side of each joint belongs to **both** neighbouring pieces. A rigid hinge
opens a notch on the outside of a bend; the overlap fills it. At rest the two copies
coincide in the same colour and cannot be seen. Pieces share the source mesh's vertex,
normal and texture arrays whole and divide only the tetrahedra, so every index still
points where it did.

## Two traps worth knowing

- **`BoxTetraMesh4D.set_size` has no early-out.** Writing the same size back every frame
  still clears the cache and forces a full rebuild.
- **`PackedInt32Array` is a value type in GDScript.** The first version of the hide split
  kept its growing lists as packed arrays inside an `Array`; `(arr[0] as
  PackedInt32Array).append(x)` appends to a copy that is thrown away. Every bucket stayed
  empty, Nike and both cats vanished, and the rebuild test passed perfectly — nothing
  left, nothing to rebuild. The test now also checks each animal still draws at least
  the tetrahedra it had.

## Tools

- `scripts/_verify_no_rebuilds_runner.gd` — headless. Counts invalidations per physics
  tick against a budget of 300 tetrahedra, and checks nothing vanished. The regression
  test for all of this.
- `scripts/_measure_pen_frame_runner.gd` — windowed; the headless renderer builds no
  proxies and would report the cost as zero. `norock=1` strips the voxel rock's colliders.
  It reports wall-clock frame time only: `Performance.TIME_PROCESS` holds its value
  between updates, and averaging it produced "35 ms of process time" in a 2.5 ms frame.
- `scripts/_capture_chicken_legs_runner.gd` — frames of any animal mid-stride, to look
  at. `who=World/Nike dist=3.4 tag=nike`.

## For Trym

His question 6 for Aaron — *"is there a way for content to know it is causing a proxy
rebuild?"* — is already answered: `Mesh4D.proxy_mesh_3d_marked_dirty`. The rebuild runner
above uses it, and it works under the headless renderer, so it can gate a test.
