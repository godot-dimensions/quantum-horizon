# Overnight session: cloud bug fixes + POI system

Two commits on `terrain-review`, both local only (not pushed - see "What's not
done" at the end):

- `Add mock 4D-responsive clouds via a real Sky shader`
- `Add POI system: real 4D markers, surface spawner, and a bearing radar`

## Clouds: what was actually wrong, and what fixed it

Your screenshots caught two real, separate bugs, not one:

**1. Wrong rendering approach entirely.** The clouds were a flat 3D `PlaneMesh`
sampling its own world position. That has two structural problems a plane can
never avoid: it shows a hard edge where the mesh ends (the "floating ceiling"
look), and worse, near the plane's own horizon the visible world-space
distance per screen pixel grows without bound - classic edge-on-plane
perspective blowup. That's what produced the severe stretching, and it got
*worse* not better as I first tried "fade out near the horizon" - the blowup
starts well before any reasonable fade threshold. Fixed by switching to a real
`Environment`/`Sky` shader (this project already has one, unused, at
`ramon/IsoclynicSun/shaders/isoclynic_sun_sky.gdshader` - copied that wiring
pattern). A sky shader has no geometry and no edges; it's the background
wherever nothing else is drawn, sampled purely from `EYEDIR` (a per-pixel view
direction, always a smooth unit vector, no blowup possible).

**2. The atlas tiles were never actually seamless.** This was the one
producing the dramatic radiating rays in your screenshots. I'd flagged this as
a known shortcut when I first baked the noise volume (real 3-axis-correlated
noise, but not seamless in x/y - true 2D seamless tiling needs 4 independent
noise axes and `FastNoiseLite` only goes to 3D) and assumed it wouldn't be
visible. It wasn't, on a flat texture - but once sampled through `EYEDIR`
(a *radial*, not linear, coordinate), every ordinary hard tile-seam turned into
a dramatic curved ray. Confirmed directly by adding a `debug_mode` uniform to
the shader that outputs raw intermediate values as color - `fract(local_uv)`
alone, before any texture sampling, already showed the exact ray pattern.
Fixed by baking one genuinely seamless tile (Godot's own `NoiseTexture2D`
`seamless=true`, the same technique that already worked fine in this
feature's very first, throwaway bake attempt) and building all 48 "depth
slices" as wrapped translations of that same tile - translating a seamless
tile keeps it exactly seamless, sidestepping the 4-axis problem entirely.

You also caught a real math bug I'd introduced myself along the way: an
intermediate version applied the rig's rotation to the *depth* coordinate
only and left the spatial UV as raw untransformed coordinates. That's wrong -
a plane rotated by angle θ both picks up depth (`local.w = z·sinθ`) *and*
foreshortens along the rotating axis (`local.z = z·cosθ`, not `z`) at the same
time. Fixed by computing the full `local = EYEDIR.x·basis_x + EYEDIR.z·basis_z`
transform together, verified numerically against known rotation angles before
moving on.

**Current state:** dramatically improved - soft, plausible, windswept-looking
cloud coverage at every camera angle and rotation I tested, including the
exact extreme case from your screenshots. There's a faint residual
dotted/dashed artifact under some rotations, much subtler than the original
bug (barely visible, not dominating the image) - most likely from the
depth-slice blend boundary, or minor imperfection in `NoiseTexture2D`'s own
blend-skirt seamless technique. I judged it not worth further time tonight
given the POI work was also asked for, but it's the first thing to revisit if
you want the clouds pixel-perfect. `clouds.gdshader` has a `debug_mode`
uniform (0 = normal) left in for exactly this kind of future debugging - set
it to 1-4 to see raw `EYEDIR`, the post-rotation `local`, the wrapped tile UV,
or a raw single-layer noise sample, at each stage of the pipeline.

Tunables if you want to adjust the look: `direction_scale` (cloud blob size),
`coverage`/`softness` (how much sky is covered), `leak_scale` (how dramatic
the rotation-driven tilt looks) - all on the `WorldEnvironment`'s Sky material
in `voxel_port.tscn`.

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
