# Overnight terrain bakes

Generated in this worktree (`quantum-horizon-ramon-review`) while fixing several real bugs found
during interactive sessions, then baking four different terrain "looks" for later use (procedural
asset placement, gameplay-loop prototyping, etc.).

## Bugs fixed

1. **Brick-aligned wall artifacts.** Root cause: `_noise_value`/`_noise_gradient` read one
   `FastNoiseLite` instance shared across every concurrent WorkerThreadPool brick task. This
   project never independently verified that's safe to call concurrently from multiple threads,
   and the reported artifact (regular structures lining up with brick boundaries) is exactly the
   shape a cross-thread read hazard would produce - the seam between two threads' work IS a brick
   boundary. Fixed by giving every brick its own fresh noise instance
   (`_build_thread_local_noise_set()`), built once per brick on whichever thread it lands on.
2. **Unbounded memory growth during long play sessions.** Once a brick was generated, nothing
   ever freed it - wandering far enough in a live-streamed world accumulated every brick ever
   built forever, and a long session hit the engine's own out-of-memory error. Fixed with brick
   eviction: `_update_chunk_visibility()` now frees (not just hides) any brick more than
   `max_render_distance * 3` from the viewer.
3. **Chunk counter drifting negative.** `_finish_brick` added a brick to `_generated_bricks`
   unconditionally, but early-returned (skipping the `_total_chunk_count` resync) when that brick
   turned out to be pure air. A later eviction/discard of that same key still decremented
   `_total_chunk_count`, even though it was never incremented for it - visible in the HUD as
   "chunks: 0/-3" after enough roaming. Fixed by resyncing on the early-return path too.
4. **Arch tube rendering as disconnected, wrongly-shaded fragments.** The arch's `gradient_fn`
   (in `_add_model_layer`'s `"arch"` case) computed `p - closest_point` (pointing OUTWARD, away
   from the curve) and returned that directly. Every other analytic layer in the file
   (`globe`/`globewater`) uses the opposite convention - `center - p`, pointing TOWARD the
   feature - which is what the true gradient of a `radius - distance` density actually is. The
   sign flip fed a backwards normal into the winding vote across the whole tube surface, which is
   why it rendered as inside-out shading and disconnected pieces rather than one continuous tube.
   Fixed by flipping the subtraction order to match the rest of the file.
5. **Streaming continuing after a bake load, defeating the point of baking.** Loading a bake was
   fast (tens of ms), but the terrain kept live-streaming new bricks every frame as the camera
   moved beyond the baked region - each new brick paying the full noise+layer generation cost
   (seconds), not the point of loading a pre-baked file at all. Added `freeze_streaming: bool` -
   set after `load_from_file()` in `_interactive_bake_runner.gd` - which gates
   `_stream_bricks_near_camera()` off entirely so a loaded demo shows exactly what was baked, no
   more, no less.
6. **Brick candidates excluding corners of an otherwise-uniform region.** `_stream_bricks_in_radius`
   selects candidates by Euclidean distance from the streaming origin to each brick's *center* -
   correct and necessary for live streaming around a freely-orbiting camera (a box would look
   lopsided depending on facing), but for a one-shot bake at `BRICK_CORE_CELLS=16` and the shared
   `max_render_distance=20`, a single-axis-offset brick sits exactly 16 units out (inside the
   radius) while a diagonal two-axis-offset brick sits `sqrt(16^2+16^2)~=22.6` units out (just
   outside it). For a flat terrain (arch/rolling_hills/cracked_archipelago) this only clipped the
   four outer corners of the demo area - a "plus" shape instead of a filled square, cosmetic since
   it's away from the interesting content. For `ocean_globe` specifically, the sphere's own radius
   (~16.8 grid units, plus noise) sits close enough to that same 20-unit radius that the identical
   filtering clipped pieces of the VISIBLE SPHERE SURFACE - a brick whose center landed just past
   the radius got skipped even though its core still overlapped the sphere, leaving a gap with no
   neighbour to connect smoothly to. This, not a meshing bug, was the actual cause of the
   long-unresolved "hollow, gap-toothed sphere with a disconnected floating fragment" - confirmed
   by isolating `globe` alone, then `globe+water`, then the full `globe+water+cutoff` stack (all
   with real noise settings) at a wider radius of 25 and getting a clean, solid result every time,
   then reproducing that same clean result through the actual bake pipeline. Fixed by raising
   `max_render_distance` to 25 for all four presets specifically (in `_bake_preset_runner.gd`),
   which pulls in the diagonal-neighbour bricks without ballooning all the way to the full 81-brick
   candidate cube.

## New features added

- **Noise combination** (`detail_noise_*`, `cellular_noise_*`, `noise_smoothing_power` exports on
  VoxelTerrain4D): a second fractal layer at a different frequency, an optional cellular/Voronoi
  layer, and a post-hoc power-curve reshape - the last one is what actually fixes "too spiky to
  read as small voxels": raising it above 1 flattens gentle variation into wide smooth
  basins/domes while leaving sharp extremes alone.
- **Seafloor depth limit** (new `MODEL_SEAFLOOR` layer, `max_depth_below_water` export): carves
  away everything more than a fixed depth below the water/ground reference level, so a world
  doesn't carry a huge "empty deep ocean" volume below the waterline that costs real generation
  time and mesh memory for something rarely worth looking at.
- **4D arch** (new `MODEL_ARCH` layer, `arch_*` exports): a tube following a curve that rises
  from the ground, sweeps through BOTH y and w on the way up, and comes back down to the ground
  elsewhere - a shape that cannot be flattened into an ordinary 3D arch without self-intersecting.
  Sliced at w=0 (the default view), it appears to emerge from and sink back into the ground as it
  moves through the fourth axis, rather than sitting there like an ordinary bridge would.
- **Colour scheme**: added mud (flat, low-lying shoreline - distinct from sand, which is what the
  same low band looks like on a steeper bank) and a cooler, distinct stone grey for steep slopes
  specifically (previously steep slopes just blended toward the same brownish colour used for the
  mid-altitude band, so a cliff read as "more of whatever altitude it was at" instead of bare rock).

## How to load one of these later

The easiest way is `_interactive_bake.tscn` (`scripts/_interactive_bake_runner.gd`) - set its
`bake_path` export to whichever `.bin` you want, run it, and you get a live, orbitable,
click-to-edit scene loaded from the cache in well under a second. `freeze_streaming` is set true
automatically after load, so it shows exactly what was baked and never falls back to slow live
generation as you move the camera.

To load manually from your own script:

```gdscript
terrain.BRICK_CORE_CELLS = 16
terrain.cell_size = 1.0
terrain.grid_size = 48
terrain.model_layers = ...  # must match what the bake used - see load_from_file()'s own
terrain.terrain_seed = 1    # validation; it refuses to load a mismatched cache rather than
# ...                       # risk silently loading geometry that disagrees with these settings.
terrain.load_from_file("user://voxel_bake_<name>.bin")
terrain.freeze_streaming = true  # optional - keep set unless you want it to keep streaming live
```

Every preset below shares `BRICK_CORE_CELLS=16`, `grid_size=48`, `cell_size=1.0`, `terrain_seed=1`,
and `max_render_distance=25.0` (raised from the original 20.0 - see bug #6 above).
`_bake_preset_runner.gd` (and its four `_bake_*.tscn` wrapper scenes) records the *exact*
per-preset settings if you want to regenerate one from scratch instead of loading the cache.

## The four scenes

### 1. Rolling hills (`user://voxel_bake_rolling_hills.bin`)
**Done** - 33 bricks, 1,285,293 tets, 144.6 MB, 0 broken tets.

Gentle, low-frequency terrain with a second fine-detail noise layer and a smoothing power of 1.8
(flattens the mid-range bumps that made the very first attempt read as "spiky" rather than
rolling). Shallow seafloor (4 grid units below the waterline) instead of a deep ocean basin.

### 2. Cracked archipelago (`user://voxel_bake_cracked_archipelago.bin`)
**Done** - 33 bricks, 1,873,049 tets, 193.0 MB, 0 broken tets.

Pure cellular/Voronoi noise, no smoothing - reads as a genuine archipelago of separate rounded
islands surrounded by water, clearly distinct from rolling_hills' continuous terrain.

### 3. 4D arch (`user://voxel_bake_arch.bin`)
**Done** - 33 bricks, 1,253,010 tets, 141.5 MB, 0 broken tets.

Rolling-hills-style base terrain plus the arch tube described above, now rendering as one
continuous, correctly-shaded tube (see bug #4). In the baseline w=0 view you should see one clear
"chimney" where the arch's peak pokes through (y-high, w-back-at-zero) and the tube mostly
invisible elsewhere along its length (it's off in w during most of the climb/descent) - rotate the
4D slice (right-drag on the hover camera) to watch the rest of it sweep into view.

Known rough edge: the tube's flat end caps, where they meet the ground plane, currently show as
small depressions rather than blending in perfectly smoothly - cosmetic, not a generation bug
(the whole point of an SDF end cap is a well-defined shape; it just isn't shaped to feather into a
flat plane at a shallow angle yet). Worth revisiting if these get used for anything where that
seam would actually show.

### 4. Ocean globe (`user://voxel_bake_ocean_globe.bin`)
**Done** - 33 bricks, 2,053,101 tets, 161.6 MB, 0 broken tets.

The project's own original default model (spherical ocean planet), now rendering as one solid,
continuous sphere with proper islands showing through the water - see bug #6 above for the actual
root cause (brick-candidate distance filtering clipping the visible surface, nothing to do with
meshing/winding). This was the long-unresolved item from the first overnight session; it's closed
now, confirmed both by isolated layer-by-layer testing and by the real bake pipeline producing the
identical clean tet count and screenshot.

## For later: procedural asset placement

Once you're ready to scatter houses/trees/etc. on one of these, the pieces already in place that
should help:
- `_slope_at()`/`_altitude_at()` (existing) give you exactly the two values the colour system
  itself uses to decide sand/mud/grass/rock/snow/stone - the same signals are a reasonable first
  cut at "where should a tree/house go" (e.g. avoid steep slope, avoid underwater altitude).
- `edit_sphere()` (existing) means placed objects could carve a flat pad into the terrain under
  themselves rather than just floating on an uneven surface, if that turns out to matter.
- Nothing exists yet for actually sampling "is this world position solid ground" from outside the
  terrain generation pipeline (a raycast-free point query) - that would be the natural next piece
  to build for asset placement specifically, since `generate_collision` is documented as not
  useful for this (AxisAlignedBoxPhysicsEngine4D collapses every shape to one bounding box).

## Possible follow-up (not done)

`_stream_bricks_in_radius`'s Euclidean-distance candidate selection is the right tool for live
streaming around a freely-orbiting camera, but the wrong tool for "bake a clean rectangular/cubic
region" - raising `max_render_distance` (as done above) works but is a "generous sphere with
margin," not an exact guarantee of a filled region. A dedicated `_stream_bricks_in_box(min, max)`
variant, used only by the bake scripts, would give bakes an exact, predictable footprint instead of
relying on radius tuning per preset.
