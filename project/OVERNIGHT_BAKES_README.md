# Voxel terrain bakes (branch `terrain-review`)

Generated while fixing several real bugs in `ramon/voxel_port/`, then baking four different
terrain "looks" for later use (procedural asset placement, gameplay-loop prototyping, etc.). A
**Voxel Terrain Demos** menu (`scripts/terrain_demo_menu.tscn`, set as this branch's
`run/main_scene`) is the entry point - press Play and pick one.

**Important - the actual baked `.bin` files are NOT in this repo.** `bake_to_file()` writes to
Godot's `user://` data directory (a per-machine folder outside the project, e.g.
`%APPDATA%\Godot\app_userdata\...` on Windows), not `res://` - and at 140-275MB each they're well
over GitHub's 100MB push limit regardless. Pulling this branch gets you the menu and the scripts
that know how to bake/load, but clicking a demo button on a machine that's never baked will just
print "no bake found" - see "Getting the actual demos running on another machine" below.

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
6. **Brick candidates excluding parts of an otherwise-uniform region.** `_stream_bricks_in_radius`
   selects candidates by Euclidean distance from the streaming origin to each brick's *center*.
   With `BRICK_CORE_CELLS=16`, the diagonal distance to a brick offset on N of the 4 axes is
   `16*sqrt(N)`: 16 (1 axis), ~22.6 (2), ~27.7 (3), 32 (4 - the true corners of the whole 3x3x3x3
   candidate cube). The original radius of 20 excluded everything past N=1; raising it to 25
   (an earlier attempt) covered N=2 but still excluded the 8 bricks at N=3, which was still
   visible as real gaps on every preset - most obviously on `ocean_globe`, where the sphere's own
   radius is close enough to the selection radius that ANY exclusion clips the visible surface
   rather than just an unused corner. **Fixed by raising `max_render_distance` to 35**, which
   clears all of N=4 with margin - every one of the 81 candidate bricks in this
   `grid_size`/`BRICK_CORE_CELLS` combination is now included, so there is no remaining
   radius-shaped gap possible. This is also what root-caused the long-standing
   "hollow, gap-toothed sphere with a disconnected floating fragment" on ocean_globe - confirmed
   NOT a meshing/winding bug via isolation testing (`globe` alone, then `+water`, then the full
   `+water+cutoff` stack, all clean at a wide-enough radius), then reproduced through the real
   bake pipeline.
7. **A misclick during orbit could hang the app and blank the mesh.** `edit_sphere()` discards
   and immediately re-requests every brick within `edit_radius`, unconditionally - it isn't
   gated by `freeze_streaming` the way ordinary camera-driven streaming is. The click-vs-drag
   tolerance on the hover camera is only a few pixels, so an accidental click during a fast orbit
   drag was enough to trigger a full live regeneration pass (noise + layers, real seconds of
   work) and made the app appear to hang. Not fixed at the root yet - mitigated by adding
   `VoxelHoverCamera4D.enable_editing` (default on) and setting it `false` in
   `_interactive_bake_runner.gd`, so the demo-browsing menu never triggers this. Editing needs a
   real fix (at minimum: respect `freeze_streaming`) before it's turned back on for these demos.

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
- **Voxel Terrain Demos menu** (`scripts/terrain_demo_menu.gd`/`.tscn`): the project's
  `run/main_scene` on this branch. Four buttons load `_interactive_bake.tscn` with a different
  `bake_path`, staying in the same running instance; Esc from inside any demo returns to the menu.

## Getting the actual demos running on another machine

1. Pull `terrain-review` and build the engine normally (`run_editor_windows.bat`/`.ps1`).
2. First run on a machine that's never had this branch checked out will hit a
   `Could not find type "VoxelField4D"` (etc.) script parse error - Godot's local `.godot` class
   cache doesn't know about the new scripts yet. One-time fix: run
   `godot.windows.editor.double.x86_64.exe --path <project> --editor --headless --quit` once to
   rebuild the cache, then launch normally.
3. Get the four `voxel_bake_*.bin` files into your own `user://` folder - either:
   - Have someone who's already baked send you the files directly (ask, not yet set up as an
     automatic share), and drop them into your own Godot `user://` data dir for this project, or
   - Bake them yourself: run each `_bake_*.tscn` scene directly (not through the menu) and wait -
     at `max_render_distance=35` (full 81-brick coverage) these took 6.5-8.5 minutes each on this
     machine's RTX 3090, with FPS dips into single digits during generation on the heavier
     presets. On weaker hardware, budget considerably more and expect it to be genuinely
     unpleasant to sit through - this is the open question flagged for team discussion (Git LFS
     vs. a manual file drop vs. something else).

## How to load one of these later (from your own script)

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

Every preset shares `BRICK_CORE_CELLS=16`, `grid_size=48`, `cell_size=1.0`, `terrain_seed=1`, and
`max_render_distance=35.0`. `_bake_preset_runner.gd` (and its four `_bake_*.tscn` wrapper scenes)
records the *exact* per-preset settings if you want to regenerate one from scratch.

## The four scenes

### 1. Rolling hills (`user://voxel_bake_rolling_hills.bin`)
**Done** - 81 bricks (full candidate cube), 1,846,630 tets, 207.5 MB, 0 broken tets.

Gentle, low-frequency terrain with a second fine-detail noise layer and a smoothing power of 1.8
(flattens the mid-range bumps that made the very first attempt read as "spiky" rather than
rolling). Shallow seafloor (4 grid units below the waterline) instead of a deep ocean basin.

### 2. Cracked archipelago (`user://voxel_bake_cracked_archipelago.bin`)
**Done** - 81 bricks, 2,674,405 tets, 274.7 MB, 0 broken tets.

Pure cellular/Voronoi noise, no smoothing - reads as a genuine archipelago of separate rounded
islands surrounded by water, clearly distinct from rolling_hills' continuous terrain.

### 3. 4D arch (`user://voxel_bake_arch.bin`)
**Done** - 81 bricks, 1,794,105 tets, 202.4 MB, 0 broken tets.

Rolling-hills-style base terrain plus the arch tube described above, rendering as one continuous,
correctly-shaded tube (see bug #4). In the baseline w=0 view you should see one clear "chimney"
where the arch's peak pokes through (y-high, w-back-at-zero) and the tube mostly invisible
elsewhere along its length (it's off in w during most of the climb/descent) - rotate the 4D slice
(right-drag on the hover camera) to watch the rest of it sweep into view.

Known rough edge: the tube's flat end caps, where they meet the ground plane, currently show as
small depressions rather than blending in perfectly smoothly - cosmetic, not a generation bug
(the whole point of an SDF end cap is a well-defined shape; it just isn't shaped to feather into a
flat plane at a shallow angle yet). Worth revisiting if these get used for anything where that
seam would actually show.

### 4. Ocean globe (`user://voxel_bake_ocean_globe.bin`)
**Done** - 81 bricks, 2,289,882 tets, 178.2 MB, 0 broken tets.

The project's own original default model (spherical ocean planet), rendering as one solid,
continuous sphere with proper islands showing through the water - see bug #6 above for the actual
root cause (brick-candidate distance filtering clipping the visible surface, nothing to do with
meshing/winding). This was the long-standing unresolved item from the first pass at these bakes;
it's closed now.

## For later: procedural asset placement

Once you're ready to scatter houses/trees/etc. on one of these, the pieces already in place that
should help:
- `_slope_at()`/`_altitude_at()` (existing) give you exactly the two values the colour system
  itself uses to decide sand/mud/grass/rock/snow/stone - the same signals are a reasonable first
  cut at "where should a tree/house go" (e.g. avoid steep slope, avoid underwater altitude).
- `edit_sphere()` (existing, currently disabled in the demo menu - see bug #7) means placed
  objects could carve a flat pad into the terrain under themselves rather than just floating on
  an uneven surface, if that turns out to matter.
- Nothing exists yet for actually sampling "is this world position solid ground" from outside the
  terrain generation pipeline (a raycast-free point query) - that would be the natural next piece
  to build for asset placement specifically, since `generate_collision` is documented as not
  useful for this (AxisAlignedBoxPhysicsEngine4D collapses every shape to one bounding box).

## Possible follow-up (not done)

- **Editing needs a real fix, not just a disable** (bug #7) - at minimum, gate `edit_sphere()`'s
  discard+re-request behind `freeze_streaming`, or give it its own opt-in confirmation before it
  does a live regen pass.
- **Bake distribution across the team** - the `.bin` files aren't in git (see above); still open
  whether to hand them out manually, set up Git LFS, or something else.
- `_stream_bricks_in_radius`'s Euclidean-distance candidate selection is the right tool for live
  streaming around a freely-orbiting camera, but generating the full 81-brick cube by brute-force
  radius (35) works only because this grid is small enough to afford it. A dedicated
  `_stream_bricks_in_box(min, max)` variant, used only by the bake scripts, would express "bake
  this exact region" directly instead of relying on a radius large enough to accidentally cover
  it - worth doing if bakes grow beyond this size.
