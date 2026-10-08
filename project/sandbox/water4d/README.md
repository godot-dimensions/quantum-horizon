# 4D water test

`sandbox/water4d/water4d_test.tscn`. Gerstner-style ocean waves living in four dimensions,
seen through the ordinary Cross-section slice. A look-and-feel experiment: nothing outside
this folder is touched, and nothing here is wired into the game.

## Controls

| | |
|---|---|
| WASD | fly horizontally |
| Space / Ctrl | up and down (world, not camera, so rising never drifts you forward) |
| E / Q | ana and kata, through W |
| Shift | sprint |
| mouse | look |
| right-drag | turn the slice (`rotate_4d`, the project's own binding) |
| R | level the slice again |
| 1 - 8 | presets, blended over half a second |
| F | Jacobian debug view |
| G | Gerstner displacement on / off |
| N | detail noise on / off |
| Esc | release the cursor |

**Preset 4, "Off-slice swell", is the one to look at.** Its swell travels almost entirely
along W, so head-on the sea mostly heaves in place: crests are arriving from a direction
that is not on screen. Right-drag to turn the slice and the same sea becomes an ordinary
travelling swell.

## The presets

| | | |
|---|---|---|
| 1 | Calm | long low swells, almost all in-slice |
| 2 | Moderate swell | one wind direction with real spread over the sphere |
| 3 | Storm | seven waves, short next to their height, crests that pinch and foam |
| 4 | **Off-slice swell** | the 4D showcase - see below |
| 5 | Short chop | brief wavelengths thrown wide |
| 6 | **Wind sea over swell** | two systems at once |
| 7 | **Sharp crests** | the whole steepness budget on three aligned waves |
| 8 | Crossing seas | two equal swells at a wide angle, one of them through W |

**6, Wind sea over swell**, is two trains that differ in direction *and* in frequency, which
is what a real sea almost always is: an old swell that has travelled in from a storm
somewhere else - long, low, smooth, pointing wherever that storm was - with today's wind
piling short steep chop on top from a different quarter. They do not interact, they sum,
which is what linear wave theory says to do and what the eye reads as weather. The 4D twist
is that the swell is almost entirely in-slice while the wind sea carries a real W component,
so turning the slice changes the chop without touching the swell underneath it.

**7, Sharp crests**, is the acute one. How pointed a sea looks is set by `sum(Q k A)` over
all its waves, and that sum is clamped to 1 - past it the horizontal map folds through
itself. So a preset that wants cusped crests has to spend the whole budget on a few aligned
waves instead of spreading it over eight. Three nearly-parallel waves reach the cusped
trochoid limit: pointed crests, flattened troughs, and a Jacobian that dips to **0.016**,
which is five times deeper than the storm and puts foam right on the points.

## The approach

### A 3D grid, not a 4D mesh

The water is one ordinary 3D grid added straight to the Cross-section engine's own `World3D`
through `RenderingServer`, exactly as `ramon/chickenpen/flock/pen_flock_4d.gd` adds the
murmuration. The engine draws in camera space - its 3D camera sits at the origin with no
transform - so a plain 3D mesh in that world lands in the same picture, lit by the same suns.

A `MeshInstance4D` displaced and re-sliced every frame was explicitly not used: per-frame
mesh regeneration was the dominant cost in the pen (`perf/README.md`). This is one instance
and one draw, which also keeps it inside the GLES3 instance-uniform budget if a web build is
ever wanted (`follow_up/web_export_feasibility.md`).

Two details carried over from the flock because they are not obvious:
`instance_set_ignore_culling(true)`, because the shader puts vertices where Godot's bounds
cannot predict; and a generous custom AABB **anyway**, because an instance with no bounds is
never indexed into its scenario at all and then `ignore_culling` never gets a say.

### Horizontal space has three dimensions

Gravity is along y, so the water is a height field over `(x, z, w)` and a wave vector `k` is
a 3-vector in that space. Deep-water dispersion `ω = sqrt(g·|k|)` involves only `|k|`, so it
is the same statement in 4D as in 3D and is used unchanged.

Throughout the shader and `water4d_presets.gd`, a `vec3`/`Vector3` named `dir`, `k` or `h` is
**(x, z, w)**, not (x, y, z).

### The slice solve

This is the part that is actually four-dimensional. Gerstner motion is Lagrangian: a particle
moves horizontally as well as vertically, bunching toward crests. In 3D that shuffle stays in
the ground plane. In 4D it has a component along the off-slice horizontal axis, so a particle
resting inside your slice is displaced **out** of it, and the particle you see at a given
spot started somewhere you cannot see.

Drawing the displaced position of an in-slice rest point would therefore be wrong. Instead,
for each grid vertex the shader solves the inverse problem - which rest point lands *here* -
by fixed-point iteration on `h = target - displacement(h)`. It converges in two passes
because the displacement is small next to the wavelength whenever the steepness constraint
holds. `solve_iterations` exposes this; at **0** the horizontal displacement is switched off
entirely and the surface is a plain sum of sines, which is what **G** toggles so the two can
be compared directly.

### Normals and lighting

The surface normal is a genuine 4D vector: the generalised cross product of the three
tangents `∂/∂x`, `∂/∂z`, `∂/∂w` of the displaced surface, computed analytically in the same
loop that builds the Jacobian.

**The slice-light builtins are available to a plain `spatial` shader, so no approximation was
needed.** `LIGHT_SLICE_COMPONENT` is registered for every spatial shader's `light()` function
in `servers/rendering/shader_types.cpp:217`, not only for the module's own shaders - checked
in the source rather than assumed. `light()` therefore mirrors
`render/3d/shaders/tetra_light_shader.glsl` with the water's 4D normal in place of the
tetrahedron's cell normal, so the sea dims and brightens in step with the 4D geometry around
it as the slice turns.

### Surface detail

The wave sum alone is smooth at every scale the grid can carry, which reads as oil rather
than water - there was no noise in the first version of this at all. There is now a band of
two-octave value noise over `(x, z, w)`, added to the height after the solve with its
gradient folded into the normal. **N** toggles it.

It is deliberately noise over all three horizontal dimensions, not a 2D texture over a
ground plane: a 3D ocean can get away with the latter, but here the field has to vary along
W as well or the detail smears into stripes as the slice turns. It takes no part in the
displacement or the Jacobian - it is texture on the surface, not wave dynamics - but the
gradient is what actually shows, because a tilted normal catches the sun where 8 cm of
height change would not.

### Foam

**Jacobian foam.** The 3x3 Jacobian of the horizontal displacement over `(x, z, w)`; foam
where its determinant drops below a threshold. Stateless, recomputed every frame.

**Intersection foam.** A depth difference in screen space where the water meets the floating
bodies. Also stateless.

Persistent foam is out of scope: it would need a texture over three-dimensional horizontal
space, not the 2D texture a 3D ocean gets away with.

## Where the foam threshold came from

Not guessed. `_probe_jacobian_runner.gd` computes the determinant over a patch of horizontal
space for every preset, with no renderer involved:

```
  preset              min det   mean det   max det   below 0.88   below 0.60
  1 Calm                0.935     0.999     1.043     0.00%       0.00%
  2 Moderate swell      0.588     1.002     1.401    21.08%       0.06%
  3 Storm               0.131     0.998     1.764    30.27%       6.02%
  4 Off-slice swell     0.537     0.752     1.167    84.75%       5.44%
  5 Short chop          0.285     1.000     2.003    32.92%       4.58%
  6 Wind sea over swell 0.316     0.996     1.856    34.56%       5.59%
  7 Sharp crests        0.016     0.996     1.988    40.33%      17.22%
  8 Crossing seas       0.472     0.940     1.365    34.98%       2.38%
```

`foam_threshold = 0.62` puts a few percent of the storm and the chop into foam and none of
the calm, which is about what a sea looks like.

**Two earlier attempts to read this off the screen were both wrong, and the probe exists
because of them.** The first counted near-white pixels in the ordinary render and reported a
healthy 0.77% for the storm - that was specular glare on the crest tops, because white water
and a white highlight are the same pixel. The second counted red pixels in the debug view,
which first came back washed to white by the environment's tonemapper and then, after being
made unlit, did not draw the water at all; the "0.01%" it reported was the orange floating
body. The determinant is arithmetic over the wave set, so it can simply be computed. **The
debug view (F) is for seeing *where* the sea is pinching, not for measuring how much.**

## The sky

The pen's cloudy skybox, brought over: a `GradientSkyMaterial4D` with a
`VolumetricCloudMaterial4D` on the same `WorldEnvironment4D`, exactly as
`ramon/chickenpen/playable_world.tscn` sets it up.

**Thicker than the pen's**, which sits at `coverage = 0.45` and reads sparse. This is 0.56
with more fractal shape and more detail. A first attempt at 0.68 with 1600 m of vertical
thickness was a white-out - total overcast, no blue, and the sea went grey because the
bright sky was bleeding in through `ambient_light_sky_contribution`; that is down too, from
0.45 to 0.25. 0.56 at 950 m gives broken cloud with sky between.

The clouds are **most of the frame cost** - see below.

## Performance

RTX 3090, 1280x720, Forward+, 193x193 grid (74k triangles), eight waves evaluated three
times per vertex, two octaves of detail noise, and volumetric clouds.

Through the project harness (`perf_real_scene`, 600 frames after a 180-frame warm-up):

```
frame    : 2.141 ms mean, 2.498 p95, 2.775 p99
gpu      : 1.504 ms   render cpu 0.201 ms   231 render objects
by layer : godot_core 1.855   godot4d 0.219   qh_custom 0.037
  godot_core/draw_submit        1.790 ms/frame  native
  godot4d/render_frame          0.219 ms/frame  native
  qh_custom/water4d/uniforms    0.030 ms/frame  gdscript
  qh_custom/water4d/phase       0.005 ms/frame  gdscript
  qh_custom/water4d/blend       0.001 ms/frame  gdscript
```

The scene's own per-frame script work is **0.036 ms**, which is the point of putting the
wave maths in the shader: what GDScript does here is eight wavelengths, eight phases, a
clamp and a noise clock.

**The clouds cost about 1.2 ms of the 1.5 ms of GPU time.** Before they were added the same
scene measured 0.764 ms mean frame and 0.257 ms GPU, and the water itself has not changed
since. If this is ever wanted as a backdrop for something else, the clouds are the first
thing to turn down.

Per preset, `_perf_water_runner.gd`, medians over ~1,220 frames each:

| preset | GPU ms |
|---|---|
| 1 Calm | 1.321 |
| 2 Moderate swell | 1.323 |
| 3 Storm | 1.335 |
| 4 Off-slice swell | 1.321 |
| 5 Short chop | 1.320 |
| 6 Wind sea over swell | 1.329 |
| 7 Sharp crests | 1.333 |
| 8 Crossing seas | 1.324 |

Flat to within 1%, as expected: the shader runs its eight-wave loop and its two noise
octaves whatever the amplitudes are, so a calm sea costs a storm.

**The CPU column from that run is not quoted, because it is not a measurement.** Every
preset came back at exactly 2.083 ms, which is 1/480 s to three decimal places - a
present-sync somewhere outside the engine, not the water. Nothing in `project.godot` sets a
cap and the runner disables `Engine.max_fps` itself. The GPU column does vary between
presets, so that is the one that means anything here; the harness figure above is the one to
quote for frame cost.

Reproduce with:Reproduce with:

```bash
engine/godot/bin/godot.windows.editor.double.x86_64.console.exe --path project --rendering-method forward_plus --resolution 1280x720 --script res://perf/qh_perf_harness.gd -- scene=res://perf/scenes/perf_real_scene.tscn target=res://sandbox/water4d/water4d_test.tscn frames=600
```

## Approximations, and things to know

- **The camera must keep world up inside the slice.** The surface is parameterised by
  separating world y from the three horizontal axes, which is valid exactly when the camera
  basis's w column has no y component - that is, while the slice is turned in the xw and zw
  planes only, which is the project's convention and what `player/player.gd` enforces. The
  fly camera composes its slice turn on the **left** for this reason; compose it on the right
  and pitch mixes the w column's z into y, world up tilts out of the slice, and the ocean
  shears. If a future camera ever adds a yw turn, this scene needs rethinking, not patching.
- **The steepness clamp is applied every frame in code**, not trusted to the preset values,
  because a blend passes through intermediate states no preset describes.
- **Foam's edge is broken up by the detail noise** rather than being a clean smoothstep,
  which is what stops it reading as a dithered lattice line where the determinant crosses
  over at grid resolution. `foam_break` controls how hard.
- **A cusped crest still stairsteps** at 0.63 m grid spacing - visible on preset 7, where
  the surface genuinely does come to a point. A finer `GRID_RESOLUTION` is the only fix.
- **Reading `DEPTH_TEXTURE` puts the water in the transparent pass**, which is why it carries
  `depth_draw_always` - without it, waves sort against each other by draw order.
- The **short chop** preset is undersampled by the grid: 2.5 m wavelengths against a 0.63 m
  step is about four samples a wave. It reads as busy rather than crisp. Raise
  `GRID_RESOLUTION` for stills.

## No engine changes were needed

Nothing here required a change to `engine/modules/4d` or the engine fork, so there are no
`TODO(flag-for-andrew):` notes. The one thing that looked like it might - 4D lighting for a
non-module shader - turned out to be supported already.

One unrelated bug noticed in passing, in the perf tooling rather than the engine: the harness
builds its output filename from the `target=` argument, so a `res://` path puts colons and
slashes in it and both the `.json` and `.csv` writes fail with "Can't open file". The run
still prints its results, which is how the numbers above were taken. `perf/qh_perf_harness.gd:489`.

## The reference implementation

Technique taken from [emilje/godot-water-shader](https://github.com/emilje/godot-water-shader)
(Gerstner waves, Jacobian foam, intersection foam). **Its licence is MIT**, so reuse would
have been permitted with attribution - but no source was copied. The maths here differs
enough that it had to be written fresh: horizontal space is three-dimensional, the normal is
a 4D cross product of three tangents, and the inverse-displacement solve has no counterpart
in a 3D implementation.

## Files

| | |
|---|---|
| `water4d_test.tscn` | the scene |
| `water4d.gdshader` | waves, normals, foam, 4D lighting |
| `water4d_surface.gd` | the render instance, blending, uniforms, the steepness clamp |
| `water4d_presets.gd` | the eight wave sets, kept separate so probes can read them without pulling in the autoload |
| `water4d_camera.gd` | fly camera, lifted from `sandbox/voxel_demo` |
| `water4d_test_4d.gd` | the floating bodies and the keys |
| `water4d_hud.gd` | the readout |
| `_probe_jacobian_runner.gd` | determinant range per preset, headless |
| `_perf_water_runner.gd` | frame and GPU time per preset |
| `_capture_water_runner.gd` | screenshots, including the preset-4 flat/turned pair |
