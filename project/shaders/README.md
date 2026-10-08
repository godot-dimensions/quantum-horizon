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
| `scale` | metres across one clump. ~0.4 for sea foam, larger for a lazier raft |
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
    0 deg   coverage  49.9%   transitions  8861 across /  8753 down   ratio 1.01
   30 deg   coverage  55.2%   transitions 10041 across / 10047 down   ratio 1.00
   60 deg   coverage  54.9%   transitions  9376 across /  9364 down   ratio 1.00
   90 deg   coverage  51.8%   transitions  8916 across /  9141 down   ratio 1.03
```

It measures the real shader through the real renderer rather than a GDScript port of the
same arithmetic, which would only ever prove that two copies of my own maths agree. The 0
degree row is the control: if even that comes out stripy, the measurement is picking up
something other than foam and no other row means anything — the probe says so and stops.

## What it is made of

Three layers, which is what stops it reading as a flat white smear:

- **clumps** — where there is foam at all, from the nearest-feature distance of a Worley
  lattice. The clump radius grows with `density`; past about 0.8 the cells touch and it
  becomes a sheet, which is what a breaking crest should look like.
- **bubbles** — the *cell walls* of a much finer lattice (the gap between nearest and second
  nearest goes to zero on a boundary), brightening the clump interior.
- **lacing** — value noise punching holes, so the sheet is torn rather than solid.

The Worley sweeps 27 neighbours, not the 9 a 2D implementation uses: in three dimensions the
3x3 misses the diagonals in W and leaves seams that only appear once the slice turns, which
is a miserable thing to debug.

## Cost, and the one thing to watch

Two Worley evaluations per call, 27 cells each. `foam_4d_shaded` adds three more calls for
its finite-difference gradient, so budget it where foam actually is:

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
