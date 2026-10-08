# Shared shaders

Shader code meant to be dropped into more than one scene. First resident: the procedural
foam.

| | |
|---|---|
| `foam_4d.gdshaderinc` | the module — foam and noise over the 4D horizontal volume |
| `foam_4d_demo.gdshader` | the smallest working example, and the reference for feeding it |
| `_probe_foam_4d_runner.gd` | the test: does the field really vary along W? |

---

# foam_4d

Procedural sea foam defined over **(x, z, w)** — the three horizontal axes — so it survives
the slice being turned.

```glsl
#include "res://shaders/foam_4d.gdshaderinc"

// 0..1 coverage at a point in the 4D world.
float foam = foam_4d(world_xzw, density, cell_size_metres, time_seconds);

// The same, plus a gradient for tilting the normal so foam lights as a crust.
vec3 gradient;
float foam = foam_4d_shaded(world_xzw, density, cell_size_metres, time_seconds, gradient);

// Also exposed, because a surface wants its detail noise to share a hash with its foam:
float n = foam4d_value(p);              // trilinear value noise over (x, z, w)
vec2 cell = foam4d_worley(p, jitter);   // cellular; .x nearest, .y second nearest
```

| argument | |
|---|---|
| `p` | the point, in **(x, z, w)** metres — **not** (x, y, z) |
| `density` | 0 nothing, 1 a solid sheet. Drive it from whatever decides *where* foam belongs |
| `scale` | metres across one cell. ~0.85 for sea foam, smaller for a finer lace |
| `time` | seconds; drifts and slowly reorganises so it is not painted on |

**`density` is the hook.** The module answers *what foam looks like*; it never decides where
foam goes. In the water scene that comes from the Jacobian determinant of the wave
displacement, but a shoreline distance, a splash radius or a hand-painted mask all work the
same way.

## The one rule

**Pass a WORLD position.** These are pure functions of the point you hand them, so the
pattern is welded to whatever you evaluate it on: turn the slice and the foam stays on the
wave it belongs to. Pass anything slice-relative — a camera-space position, a screen UV, a
grid index — and it will swim across the surface as you turn, which reads as the sea sliding
along underneath its own foam. If it ever starts shimmering, that is the first thing to
check.

`foam_4d_demo.gdshader` exists to show exactly this: everything above the `foam_4d` call is
there only to work out what the world point is for the current pixel.

## Why not a texture

A 3D game paints foam with a scrolling 2D texture over its ground plane. That cannot work
here. Turning the slice re-cuts the world along W, so a pattern with no W variation is
constant along one of the two axes you can suddenly see — it smears into stripes exactly
when the camera starts moving through it.

Which is a testable claim, so it is tested.

## The test

```bash
engine/godot/bin/godot.windows.editor.double.x86_64.console.exe --path project --rendering-method forward_plus --resolution 720x720 --script res://shaders/_probe_foam_4d_runner.gd
```

It paints a flat plane with the field at four slice angles and measures how stripy each
frame is — the ratio of pixel transitions counted along rows to those counted along columns.
Round cells give about 1. **At 90 degrees one of the two visible axes IS W**, so a field with
no W variation would be constant along it and the ratio would blow up.

```
    0 deg   coverage  50.9%   transitions  5474 across /  5291 down   ratio 1.03
   30 deg   coverage  39.0%   transitions  5576 across /  5740 down   ratio 1.03
   60 deg   coverage  42.4%   transitions  5562 across /  5763 down   ratio 1.04
   90 deg   coverage  46.4%   transitions  5552 across /  5779 down   ratio 1.04
```

It measures the real shader through the real renderer rather than a GDScript port of the
same arithmetic, which would only ever prove that two copies of my own maths agree. The 0
degree row is the control: if even that comes out stripy, the measurement is picking up
something other than foam and no other row means anything — the probe says so and stops.

## What it is made of

**Foam is the EDGES between cells, not the cells**, and this is the easy thing to get
backwards. Look at a photograph of a breaking sea: the white is a *network* of filaments
with open water inside the holes. Foam collects where surface flow converges, and the
convergence lines are the boundaries between patches being pushed apart - not the middles of
them.

So the field is `second nearest - nearest`, which goes to zero exactly where you are
equidistant from two feature points, i.e. on a cell wall. Using the nearest distance alone
paints a disc around every feature point and gives white blobs with water between them: the
photographic negative of foam. **That is what the first version of this did**, and it took
being shown a reference photo to see it.

Layers, over a warped lookup:

- **domain warp, two octaves** - value noise bending the coordinate before it reaches the
  lattice. A raw Worley has straight walls and sharp three-way vertices; real filaments
  wander, because the surface carrying them is being stirred. The two octaves do different
  jobs: the coarse one drags whole cells off the lattice, the fine one **bows the walls**,
  which is what actually rounds a cell. One octave alone still leaves straight segments
  between vertices - recognisably a polygon - however far it drags them about.
- **network** - the ropes, from the boundary field. Thickness wanders along a rope rather
  than being constant, and the edge is feathered: foam has no border, it thins out. The
  cross-section is then smoothstepped a second time, which swells the middle and tapers the
  shoulders - the difference between a filament and a stripe. Width grows with `density`
  until the holes close over into a sheet, which is what the middle of a breaking crest
  should be.
- **wisps** - a finer boundary field, multiplied *into* the network so it grains the ropes.
  Added to open water instead, it tiles the whole surface and reads as cracked glaze.
- **mottle** - value noise, so a rope has grain rather than being painted on.

The Worley sweeps 27 neighbours, not the 9 a 2D implementation uses: in three dimensions the
3x3 misses the diagonals in W and leaves seams that only appear once the slice turns, which
is a miserable thing to debug.

### What the module does not do

**It has no memory.** `foam_4d` is a pure function of where and when, so foam appears and
vanishes the instant `density` does. If you want foam that lingers after whatever made it
has stopped - the "persisting foam" of most water shaders - that is the caller's job, and
`sandbox/water4d` shows one way to do it without a buffer.

It also returns the filaments alone. On their own they leave the holes as bare water, which reads
as a net thrown over the sea rather than as foam. Whether there is a milky film between the
strands - and how milky - belongs to the surface the foam is on, so the caller does it:

```glsl
float network = foam_4d(world_xzw, density, scale, time);
float cover = density * mix(0.32, 1.0, network);   // what sandbox/water4d does
```

## Cost, and the one thing to watch

Two Worley evaluations per call at 27 cells each, plus eight value-noise samples (six for
the two warp octaves, one for the thickness, one for the mottle). `foam_4d_shaded` adds three more whole
calls for its finite-difference gradient, so budget it where foam actually is:

```glsl
if (density > 0.002) { ... }   // the module early-outs too, but skip the call as well
```

In the water scene, per-pixel foam over an ocean costs about **0.1 ms** at 1280x720 on a
3090 — 380 fps with volumetric clouds, against 406 before the foam was textured.

**Procedural detail has no mip chain.** Past the distance where a cell is sub-pixel it
aliases into sparkle. Fade back to the plain `density` mask with distance; the water scene
does this between 22 m and 65 m, and it is the difference between foam and fireflies.

## Used by

- `sandbox/water4d/` — Jacobian-driven foam on Gerstner waves, and the detail noise band.
