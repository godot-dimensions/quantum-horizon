# Overnight + morning-after session: cloud bug fixes + POI system

This doc's original overnight version described a `shader_type sky` /
`EYEDIR`-based implementation. That approach got reviewed the next morning and
turned out to be wrong for this project's actual camera use case (an
RTS-style hover camera looking mostly downward at a bounded terrain patch, not
a first-person view needing a full sky dome) - a sky shader fills the entire
sky as seen from ground level, which read as "clouds fixed to the top of the
screen, not reacting to zoom/rotation" rather than a deck sitting over the
terrain. This section now describes the CURRENT, morning-after-fixes
implementation instead of the overnight one; the underlying noise/rotation
math described below is unchanged from the original overnight work, only
*where it's sampled from* changed.

## Clouds: current implementation

`clouds_layer.gd` + `clouds.gdshader` render an ordinary bounded 3D
`PlaneMesh` (`shader_type spatial`, `unshaded`, `cull_disabled`,
`depth_draw_never`) positioned as a semi-transparent deck over the terrain,
not a sky dome:

- **Footprint** comes from the terrain's nominal `grid_size * cell_size` -
  this tracks the terrain's edges well and, importantly, stays a large,
  stable value throughout brick streaming.
- **Height** comes from the terrain's ACTUAL generated surface geometry
  (scanning `Ground/<brick>.mesh` vertices for the highest point, the same
  vertex-read technique `poi_spawner.gd` uses for surface placement - no
  raycast or separate height function available in this engine), floated
  `height_margin_voxels` (default 5) `cell_size` units above that real peak,
  per an explicit request to derive height from real geometry rather than a
  fraction of the footprint (which put clouds absurdly high/low whenever
  grid_size changed, and was the direct cause of the "fixed to the top of the
  screen, doesn't react to zoom" bug report).
- Footprint deliberately does NOT also come from the scanned bounds (an
  earlier version tried this): only a fraction of the terrain's bricks may
  have streamed in at any moment, so the scanned XZ extent can be far smaller
  than the terrain's eventual real size - and a small footprint combined with
  this deck's height hits a reproducible Godot rendering cliff (confirmed
  empirically: identical shader/material, a ~40-unit plane at height ~29
  renders nothing from ANY camera angle, while the same plane at height ~10,
  or a ~70+-unit plane at height ~29, both render fine). Not fully
  root-caused at the engine level; sidestepped by keeping the footprint on
  the large, stable nominal formula instead.

The noise sampling itself (seamless flipbook-atlas volume, tilted
cross-section via the rig's `xw`/`zw` basis) is unchanged from the original
overnight implementation - see `clouds.gdshader`'s own header for the
derivation. `debug_mode` (0 = normal) is still there for future debugging -
set it to 1-4 to see raw world-space XZ, the post-rotation `local`, the
wrapped tile UV, or a raw single-layer noise sample.

Tunables: `coverage`/`softness` (how much of the deck is covered),
`leak_scale` (how dramatic the rotation-driven tilt looks), `uv_scale` (cloud
blob size) - all on the `Clouds` node's shader material in `voxel_port.tscn`.
`height_margin_voxels` and `rig_path`/`terrain_path` are exports on
`clouds_layer.gd` itself.

## POI system

Three new files, all in `project/scripts/`:

- **`poi.gd` (`POI4D`)** - a plain marker (ore/base/unit categories, distinct
  colors and sizes) meant to be parented directly under the terrain. That's
  the whole trick: because it's a real `Node4D` child of `Terrain`, it
  automatically appears/disappears exactly like the terrain's own geometry as
  you rotate the 4D slice, through the *same* Cross-section rendering
  pipeline - no custom visibility code needed. Confirmed directly: a spawned
  marker was invisible at one rotation and visible (a small red cube) at
  another in my verification screenshots.
- **`poi_spawner.gd` (`POISpawner4D`)** - places POIs on the terrain's actual
  generated surface. No raycast (this project's own collision collapses
  everything to a bounding box) and no re-derived height function (the
  density math lives as anonymous closures private to `_add_model_layer`,
  and isn't solvable for height in closed form for the plane/globe models
  anyway) - instead it reads the Ground mesh's own vertex data directly via
  `ArrayTetraMesh4D.get_vertices()`. Those come out already in the terrain's
  local coordinate space, so a sampled point can be used as a POI's
  `.position` with no transform math at all. Auto-spawns once the terrain
  actually has a generated surface to sample from (polls for real
  surface points, not the `_generated_bricks` dict - that dict goes non-empty
  *before* the actual mesh exists, which I only found by testing directly and
  getting zero POIs the first time).
- **`poi_radar.gd`** - a generalized version of the shooting gallery's
  `slice_radar.gd` (same ellipse + oblique-projection drawing, air-traffic-
  control-style: a point on the ellipse for horizontal position, a vertical
  stem for how far off the current slice something is), adapted to track an
  arbitrary POI list instead of gallery-specific globals. One real adaptation
  needed, not just a copy-paste: the shooting gallery's Player body carries
  slice-rotation directly on its own basis, but `voxel_port`'s hover camera
  never rotates - the *terrain* does (see `voxel_hover_camera_4d.gd`'s own
  header). Using the camera's basis for the bearing math would have silently
  ignored all rotation and shown every POI as if the slice were still at
  zero. Fixed by giving `BearingUtility4D` a `compute_raw()` overload that
  takes the observer's position and basis as separate values - camera
  position, but rig basis.

All three are already wired into `voxel_port.tscn` (so every demo scene gets
them automatically): a `POIs` container under `Terrain`, a `POISpawner4D`
node (6 ore / 2 base / 4 unit by default), and the radar in the bottom-right
HUD corner. Verified end-to-end with real screenshots: correct POI counts,
plausible surface positions, radar dots in the right category colors,
correct behavior through a 4D rotation.

## What's not done / open questions for you

- **Not pushed to GitHub.** Both commits are local-only on `terrain-review`.
  Given the scope of tonight's changes I'd rather you look them over before
  they go anywhere the team can see - say the word and I'll push.
- **Clouds' faint residual artifact** - documented above, didn't chase further
  given time.
- **POI placement is purely random** - no avoidance of water-covered terrain,
  no minimum spacing between markers, no "ore clusters near X" type logic.
  Explicitly out of scope per your framing ("test the supporting systems," not
  a game loop) but flagging in case you want any of that next.
- **The radar's `halfway_meters`/marker sizes are first-guess tuning**, not
  measured against how the terrain actually looks in a real play session -
  worth a look once you're actually driving the camera around live.
- The bake-distribution question (Git LFS vs. manual sharing for the large
  `.bin` files) is still exactly where you left it - untouched tonight.
