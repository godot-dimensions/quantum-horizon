# Technical summary: grazing-angle texture banding in a 4D Cross-Section renderer

**Status: substantially improved, not fully eliminated — the worst-case rotation still shows a
faint, softened directional pattern under close inspection, though far less severe than the
original bug.** This document is the final write-up of an extensive, multi-session
investigation, including a later autonomous follow-up that tried six additional, structurally
different fix strategies beyond the one first shipped. Most did not pan out (documented below,
with the specific, non-obvious reasons why), but the last one — replacing the *trigger signal*
that drives the shipped blur mitigation, not the response itself — produced a real, measured
improvement over every earlier attempt. If you are picking this up to try again, read "What was
tried and ruled out" before starting, then "A genuinely better trigger signal" for where this
currently stands. The honest remaining options for a full fix are a genuinely irregular
(non-grid) mesh topology, or engine-level changes to expose screen-space triangle geometry to
the shader — both bigger undertakings than anything attempted in this pass.

## Context

This is a custom fork of Godot 4 with a genuine 4th spatial dimension added as an engine
module (`engine/modules/4d/`). 4D objects are `Node4D`/`MeshInstance4D` with a `Basis4D`
(4x4 rotation) and are rendered by literally *slicing* their 4D geometry with the camera's
current 3D viewing hyperplane every frame ("Cross-Section" rendering), producing an ordinary
3D triangle mesh handed to the normal rasterizer. This is not raymarched/volumetric — it's
geometric: 4D solids are represented as **tetrahedra** (4-point, 3D simplices embedded in 4D
space), and each tetrahedron is intersected with the 3D hyperplane `w=0` (in the object's
transformed space) to produce 0, 1, or 2 output triangles.

The feature: a "clouds" effect — a single 4D box object with a semi-transparent FBM noise
material, sized to sit above a terrain and look plausible from any 4D rotation angle. At most
rotation angles it works well. At specific, fairly extreme combined rotations (rotating two
orthogonal planes simultaneously toward ~90°, e.g. `xw` and `zw` both near 80°), the noise
showed severe, sharp-edged parallel-stripe banding converging toward a point — like a fan of
chevrons — covering a large fraction of the visible surface.

## The exact rendering math (verbatim from the engine)

Every 4D mesh's vertex shader is effectively this (from
`engine/modules/4d/render/cross_section/tetra_cross_section_shader.glsl`, which every custom
4D material's shader must reproduce since the engine only auto-assigns this shader when the
material's shader slot is null):

```glsl
mat4 modelview_basis = mat4(modelview_basis_x, modelview_basis_y, modelview_basis_z, modelview_basis_w);
vec4 verts[] = { CUSTOM0, CUSTOM1, CUSTOM2, CUSTOM3 };
verts[0] = (modelview_basis * verts[0]) + modelview_origin;
// ...same for verts[1..3]

int vertex_id = int(VERTEX.x);
int face = get_face_lookup_index(verts[0].w, verts[1].w, verts[2].w, verts[3].w, vertex_id);
if (CROSS_SECTION_LOOKUP[face] == -1) {
    POSITION = vec4(0.0, 0.0, CLIP_SPACE_FAR, 1.0); // cull, tet doesn't cross w=0
} else {
    int position_edge = CROSS_SECTION_LOOKUP[face + (vertex_id % 3)];
    int edge_vert1 = TETRAHEDRON_EDGE_TO_VERTEX_MAP[position_edge * 2];
    int edge_vert2 = TETRAHEDRON_EDGE_TO_VERTEX_MAP[(position_edge * 2) + 1];
    vec4 position1 = verts[edge_vert1];
    vec4 position2 = verts[edge_vert2];
    float mix_weight = position1.w / (position1.w - position2.w); // ALWAYS in [0,1]
    vec4 position = mix(position1, position2, mix_weight);
    VERTEX = position.xyz;
    POSITION = PROJECTION_MATRIX * vec4(position.xyz, 1.0);
}
```

`CROSS_SECTION_LOOKUP` is a 16-case x 6-slot table mapping to which of a tetrahedron's 6 edges
get interpolated to form 0, 1, or 2 output triangles. This is engine-fixed, not under our
control. Our own shader (`project/scripts/clouds.gdshader`) additionally interpolates the
tetrahedron's **raw, untransformed local corners** using the *same* `mix_weight`, into
`varying vec4 local_pos`, which is what noise is sampled from.

## The mesh being sliced

The box is built by our own `SubdividedBoxTetraMesh4D`
(`project/scripts/subdivided_box_tetra_mesh_4d.gd`, custom GDScript, not engine-native). A 4D
hypercube's boundary consists of 8 "cells" (3D cubic facets) — e.g. the `+W` cell is the flat
3D region `{(x,y,z,+half_extent.w) : x,y,z in [-he,+he]}`. We subdivide each of the 8 cells into
a grid of smaller cubes (size from a target world-space cell size, e.g. ~8 units), each split
into 5 tetrahedra via the standard "cube → 5 simplices" decomposition. All coordinates come
from one shared, continuous box-local frame; `ArrayTetraMesh4D`'s own position-based vertex
deduplication merges shared corners automatically. `SubdividedBoxTetraMesh4D.build()` has a hard
`MAX_SUBDIVISIONS_PER_AXIS = 32` safety ceiling (see "Performance" below).

## Root cause (confirmed by direct causal test, not correlation)

At *identity* 4D rotation, a hypercube's `w=0` cross-section is formed *entirely* by its
`±X`/`±Y`/`±Z` cells — the `±W` cells' 4 corners all share the exact same `w` value and
mathematically cannot cross `w=0` at all. Only once the rig's rotation matrix mixes enough of
X and Z into W (the test case: `xw` and `zw` both near 80°) do the `±W` cells' *transformed*
w-values start to differ from each other, and those cells begin contributing to the visible
cross-section for the first time. Excluding the `±W` cells entirely (still fully subdivided on
the other 6) at the exact problem rotation made the banding almost entirely disappear. Clean,
reproducible, causal.

**Mechanism**: a cell that has *just* started crossing `w=0` — corners' transformed w-values
all very close to zero, some barely positive and some barely negative — contributes geometry
that is the 4D-rotation equivalent of "a flat surface viewed almost perfectly edge-on." This is
an inherently thin-sliver case no matter how finely it's subdivided. The `mix_weight =
w1/(w1-w2)` computation is always bounded in `[0,1]`, but its *sensitivity* to small
perturbations, `d(mix_weight)/dw1 = -w2/(w1-w2)^2`, diverges as `(w1-w2)→0` — exactly this
near-degenerate case. Since neighboring tetrahedra compute their crossing edges independently
from their own corner data, small real numerical differences between adjacent tets get
amplified into large `local_pos` jumps between neighboring triangles near this condition.

**Important, hard-won correction**: this divergent sensitivity was initially suspected to be
*compounded* by GPU floating-point imprecision (see below) — it is not. A dedicated test proved
the sensitivity is a property of the *exact* mathematical formula, present even with perfect
arithmetic. The mesh's own regular sub-cube grid is what turns this per-tetrahedron instability
into a *coherent, repeating* stripe pattern rather than isolated speckle: as rotation increases
toward the critical threshold, the specific sub-cells that are "barely crossing" at any given
moment are spatially correlated with the regular grid, producing a moiré-like pattern tied to
the mesh's own tessellation.

## What was ruled out, in the order established (original investigation)

1. **Not the noise atlas's depth-slice resolution.** Confirmed via a direct depth-axis-
   coordinate visualization: completely smooth, no speckling, unlike the fine banding itself.
2. **Not the "rotation warp" step.** Removing the rig-rotation-reactive coordinate warp and
   sampling directly from raw `local_pos.xz` produced identical banding.
3. **Not fixable by mesh subdivision, at any practical density.** ~40 tets → ~21,600 tets
   (~500x): banding visually unchanged. ~1.4 million tets hung the engine outright (this is why
   `MAX_SUBDIVISIONS_PER_AXIS = 32` exists as a hard ceiling).
4. **The coordinate is smooth and low-derivative by every direct measurement, yet the
   texture-sampled result isn't.** `local_pos` false-color visualizations looked perfectly
   smooth at the exact banded pixels. `dFdx`/`dFdy` of the final UV coordinate read as
   sub-1-texel-per-pixel everywhere visible — flatly contradicted by the visible banding. This
   remains an open, unexplained detail: hardware screen-space derivatives are computed within
   one triangle/quad and likely cannot see a discontinuity that exists *between* independently-
   parametrized triangles from different tetrahedra — but this was never confirmed directly.
5. **Not GPU mip-level corruption.** The noise atlas's mip chain is separately known-corrupted
   (blends unrelated tiles across boundaries above LOD 0), and LOD is forced to 0 in the shader
   as an independent fix for that — but disabling it entirely did not change the banding.
6. **Anisotropic/derivative-aware multi-tap supersampling did not help** — consistent with (4).

## What was tried and failed: color/position regularization toward a fixed local weight

Blend `mix_weight` toward the edge's fixed parametric midpoint (0.5) as `|w1-w2|` shrinks,
applied only to the noise-sampling coordinate. Result: at low thresholds, no change; at higher
thresholds, the smooth stripe pattern **transformed into a different, jagged/faceted zigzag
pattern tracking the mesh's own tetrahedra grid** — traded one artifact for a different one.
**Why**: 0.5 in one tetrahedron's own local parametrization is a different physical point than
0.5 in a neighbor's, unless the two happen to be symmetric — fading toward it doesn't restore
genuine spatial continuity between independently-parametrized neighboring cells. Fully
reverted; nothing from this attempt remains in the shipped shader.

## Later investigation: was this actually a numerical-precision bug? (No.)

A later pass reconsidered the whole problem from scratch, hypothesizing that GPU **float32
catastrophic cancellation** — not an inherent geometric property — might be the true cause: the
engine composes `modelview_basis` in double precision on the CPU (this is a `real_t=double`
custom Godot build), but instance shader uniforms and vertex attributes are always plain
float32 on the GPU, and computing `w1`/`w2` via a 4-term dot product of half-extent-scale
values (tens of units) that sums to near-zero is a textbook cancellation setup.

**Investigated two ways:**
- A subagent research pass confirmed Forward Mobile (the RD/Vulkan rendering method in use
  here) does **not** force `mediump` precision anywhere relevant — vertex-stage math and
  instance uniforms are full 32-bit float on both Forward Mobile and Forward+; the only
  `mediump`-equivalent path (`EXPLICIT_FP16`) is fragment-stage-only internal BRDF math, unused
  by custom shaders. This ruled out a "far worse than float32" precision cliff.
- Implemented a **numerically-stable reformulation** of the crossing-edge denominator:
  instead of `position1.w - position2.w` (subtracting two independently-transformed,
  half-extent-magnitude values — the classic cancellation pattern), compute
  `(modelview_basis * (local_vert1 - local_vert2)).w` — transforming the *small*,
  well-conditioned local-space corner difference directly. Mathematically identical in exact
  arithmetic, but avoids ever representing-then-cancelling the larger intermediate values.
  Kept in the shader behind a `debug_use_naive_mix_weight` A/B toggle (default `false` = the
  stable path).

**Result: no visible difference whatsoever**, confirmed via careful crop-level before/after
renders at the exact problem rotation (after first catching and fixing a harness bug — see
"A methodology note" below). This is a genuine, useful **negative result**: it rules out
float32 cancellation as the cause and confirms the sensitivity is a property of the *exact*
mathematical `mix_weight` formula, not an artifact of how precisely it's computed. Anyone
revisiting this should not re-try precision-based fixes without a new hypothesis for why they'd
behave differently.

## Later investigation: three de-aliasing mechanisms, compared head-to-head

With the precision question closed, the remaining honest options are all *mitigations* that
respond to a per-edge degeneracy signal, `w_degeneracy = 1 - smoothstep(0, degeneracy_threshold,
|w1-w2|)`. Three fundamentally different responses to this signal were implemented and
calibrated via rigorous crop-level (not full-frame-glance) before/after renders at both the
80° problem rotation and a 45° previously-clean rotation:

**1. Alpha suppression** (the original, first-shipped fix): fade the fragment's own alpha
toward 0 as degeneracy rises. Produces a smooth fade with no new pattern *shape* — but a whole
banded region tends to share a similarly small `w`-gap, so a uniform per-edge fade dims the
*entire* region together rather than removing its internal structure. At the calibrated
threshold (15), the worst case is fainter but the same stripes are still visible; moderate
rotations show a mild version of the mesh's own facet grid as alpha variation.

**2. Blur-based de-aliasing** (`sample_slice_blurred()` in `clouds.gdshader`): as degeneracy
rises, average several manual ring-taps of the noise texture within the *same* atlas tile
(can't rely on hardware mip/LOD — the atlas's own mip chain is separately corrupted across tile
boundaries, and `textureLod` is forced to 0 elsewhere for that reason). This is a genuine
anti-aliasing response — softening contrast/sharpness — rather than a transparency response.
Confirmed via crops: real, visible softening of the worst-case banding at a *mild* radius
(0.12, in pre-wrap tile-UV units); pushing the radius much larger (tested up to 1.2) does
eventually wash the stripes toward flat, but only after passing through an *intermediate*
zone where the ring-tap offsets wrap around the tile (via `fract()`) and alias into a **new**
grid-aligned interference pattern — so "more blur" is not simply "more washed out."

**3. Cell-center fallback**: blend the sampling coordinate toward the tetrahedron's own
sub-cube *center* (a genuinely shared, continuous reference — unlike the earlier failed 0.5
weight, every tetrahedron in one sub-cube agrees on the exact same point) instead of its own
unstable interpolated corner. Implemented by extending `SubdividedBoxTetraMesh4D.build()` to
populate `ArrayTetraMesh4D.simplex_cell_texture_map` (one of the only genuinely free per-corner
data channels `TetraMesh4D` exposes — `NORMAL` gets renormalized and `COLOR` gets `[0,1]`-clamped
by the engine's own mesh-building code, but `UV` is passed through uncompressed) with each
cell's box-local X/Z center (the only two components `clouds.gdshader`'s sampling coordinate
actually reads). This was the most *structurally* effective at removing the stripe shape itself
at high blend — pushed hard, a badly-behaved region converges to a coherent, if blocky, mosaic
rather than jittering. **But it has the worst calibration curve of the three**: its
moderate-rotation cost (a sharp, prominent diamond/facet grid, much more visually dominant than
alpha's mild version) ramps up to full severity at roughly the *same* threshold where it only
barely starts helping the worst case — there is no usable middle ground. Shipped **disabled**
by default (`enable_cell_center_fallback = false`), but the code and the
`simplex_cell_texture_map` mesh-data plumbing are kept in as real, tested infrastructure, in
case a future, better-targeted trigger signal (see "What a real fix would need" below) can use
a shared reference point more surgically.

**Also tried and found to make things *worse*, not better**: combining alpha suppression and
blur at their individually-calibrated thresholds. Both mechanisms respond to the same
underlying signal by revealing the mesh's own sub-cube grid at moderate rotations once their
threshold is high enough to help the worst case — stacking them compounds that cost rather than
each covering the other's gap. Confirmed via direct crop comparison; a real, useful negative
result, not an oversight.

## Later investigation: jittering the mesh's own grid (a structural, not per-fragment, lever)

All three mitigations above share a weakness: they respond to a *threshold* on a degeneracy
signal, and no threshold value was both "fixes the worst case" and "invisible at moderate
rotations." A structurally different idea, which doesn't depend on any threshold at all: the
banding reads as *coherent, repeating stripes* (not incoherent noise) specifically because the
mesh's sub-cell grid is perfectly regular, so on a given rotation, the specific tetrahedra that
are "barely crossing" at that moment are spatially correlated with the regular grid. If the
grid were irregular, that correlation should break, scattering the same per-tetrahedron
instability into unstructured graininess instead of aligned lines.

**Implemented**: `SubdividedBoxTetraMesh4D.build()` gained a `jitter_fraction` parameter.
Interior sub-cell grid lines (never the macro-cell's own outer boundary, so cross-macro-cell
seams stay exact) are displaced by a deterministic hash of `(axis, grid index)`, tapered to
zero at both ends of each free axis via a sine taper, up to a fraction of one grid step (tested
at 0.3, comfortably clear of the ~0.5 self-intersection limit that would invert a cube's
winding). The hash depends only on `(axis, s)`, not which macro-cell is calling it, so two
macro-cells sharing an axis as a free axis compute identical jittered values for the same
index — vertex deduplication at shared faces still works correctly.

**Result: no meaningful improvement**, confirmed both in isolation and stacked on top of the
shipped blur mitigation. A pixel-diff against the unjittered baseline at the same rotation
showed jitter is genuinely engaging (~40% of sampled pixels differ, not a no-op), but the
banding's gross stripe pattern survived essentially unchanged in both cases. **Why**: the
stripes are contiguous *bands of topologically-adjacent* near-degenerate cells — a real,
continuous spatial region where the local w-gradient puts many neighboring cells simultaneously
near the critical threshold — not an artifact of exact grid *positions* correlating by
coincidence. Perturbing a cell's position by a fraction of a grid step doesn't change which
cells are topologically adjacent to which, so a jittered band of adjacent near-degenerate cells
is still a contiguous band, and still reads as a stripe. A genuine fix along these lines would
need to break *adjacency*, not just position — i.e. an actually irregular (non-grid) mesh
topology, such as an unstructured Delaunay-like tessellation — which is a substantially larger
engineering effort with real risk of introducing new mesh-validity bugs (gaps, cracks, winding
errors) and was not attempted here. Shipped **disabled** (`DEFAULT_JITTER_FRACTION = 0.0`):
since it doesn't help, there's no reason to pay its cost (gratuitously different rendered
output, a small amount of extra per-vertex hashing) by default. Kept in as tested
infrastructure, with this finding recorded so a future attempt doesn't have to re-derive it.

## Later investigation: a genuinely better trigger signal (real, measured improvement)

After jitter's negative result, the remaining honest options looked like a big step up in scope
(irregular mesh topology, or engine-level geometry-shader-style changes). Before committing to
either, one more idea was worth testing: not a new *response* to degeneracy, but a better
*signal* for when to respond. All three response mechanisms above (alpha, blur, cell-center)
shared the same trigger — the raw crossing-edge gap `|w1-w2|` — which a headless sweep had
already shown does not predict visible severity (more small-gap edges at clean 45° than at
banded 80°).

**Why the raw gap fails**: it only asks "is the denominator small," but `local_pos =
mix(local_vert1, local_vert2, mix_weight)`, so how far `local_pos` actually *swings* per unit of
`mix_weight` change is the edge's own vector, `local_vert2 - local_vert1`. A short edge with a
tiny gap barely moves `local_pos` at all; a long edge with the same tiny gap swings it by a lot.
The raw gap conflates these two very different cases.

**New signal**: `sensitivity = edge_length / max(|w1-w2|, epsilon)`, directly estimating how much
`local_pos` could swing per unit of `w`-perturbation (chain rule: `d(mix_weight)/dw ~
1/(w1-w2)`, `d(local_pos)/d(mix_weight) = local_vert2 - local_vert1`). A headless sweep across
0-88° found this separates the known-clean and known-banded cases cleanly for the first time:
max sensitivity across the whole mesh stayed at **1.4-6.8** at identity/45° (both confirmed
clean throughout this entire investigation), versus **37-821** at 80-88° (both confirmed
banded) — a real, monotonic-at-the-verified-points gap the old metric never had, not just at the
extremes but in the *prevalence* data too (fraction of edges exceeding a given sensitivity
threshold): zero edges exceeded 10 at 45°, versus a real, nonzero fraction at 80-88°.

**Implemented**: replaced the `w_degeneracy` trigger in `clouds.gdshader`'s `vertex()` with this
sensitivity metric (computed from `local_verts[edge_vert1] - local_verts[edge_vert2]` and the
already-computed `diff_w`), feeding the *same*, already-shipped blur response unchanged.
Calibrated the threshold by direct render (not just the numeric proxy): 45° stays completely
clean up to a threshold of ~10-11; a mild version of the old mesh-grid cost starts appearing by
8; thresholds from 12-18 all gave a real, visible improvement at the 88° worst case — noticeably
softer, fainter banding than the old gap-based metric ever achieved at any threshold, including
values that had previously introduced new artifacts at moderate rotations. **Shipped
`degeneracy_threshold = 12.0`** (in the new sensitivity units — this replaces, not adds to, the
old gap-based default) for comfortable margin below the clean-case cost onset. Confirmed via
direct crop renders at 88°, 80°, 45°, 20°, and identity: 88° improved substantially (a much
fainter, washed-out result compared to every earlier attempt at this severity), 80° improved
moderately (similar to the old metric's best result, since 80°'s own max sensitivity, ~37, is
much closer to the clean-case ceiling than 88°'s ~821 is), and 45°/20°/0° all stayed clean.

**Honest limit**: this is real, measured progress — not a full fix. The 88° case is much
improved but still shows a visible (fainter) directional pattern under close inspection, and 80°
specifically is only modestly better than before. The remaining gap is the same one described in
the jitter section below: some of the surviving pattern comes from contiguous *bands* of
near-degenerate cells whose average severity, not just their peak, drives what's visible — a
threshold on any single-edge metric (including this better one) still responds edge-by-edge, not
band-by-band.

## Later investigation: this is a geometric instability, not a clouds-texture issue — and MSAA/supersampling don't fix it either

Prompted by a direct challenge to the whole "fade it out" line of mitigation (correctly pointed
out: reducing opacity in the degenerate region is not a fix that generalizes — pushed further it
would produce literal holes in coverage, and it would be unacceptable for any opaque object, not
just clouds), this investigation went back to first principles instead of tuning another
threshold.

**Confirmed: the TRUE rendered geometry carries the same instability, not just the noise
sampling.** There is an exact algebraic identity in the vertex shader:
`position = modelview_basis * local_pos + modelview_origin` (mixing commutes with any affine
transform, so this holds regardless of `mix_weight`'s value — not an approximation). This means
`local_pos` and the true output `position`/`VERTEX` are rigidly, linearly tied together — if one
is unstable near a grazing crossing, so is the other. A direct test confirmed this: `debug_mode
6` visualizes a fine checkerboard built purely from `local_pos`, with **no noise texture
involved at all**, and at 88° it shows the exact same coherent parallel-band structure as the
noise banding. **This means the artifact is not specific to clouds, or to any texture** — it is
a property of the Cross-Section slicing algorithm itself when a cell is nearly edge-on to the
slicing hyperplane, and it would show up on any material (including a flat-shaded, untextured
surface, or a character model) applied to a 4D object at the same kind of grazing rotation — it
would just be far less *visible* on a low-frequency material than on high-frequency noise, not
absent.

**Confirmed (again, more precisely this time): GPU derivatives are structurally blind to this,
because the discontinuity is *between* primitives, not *within* one.** `dFdx`/`dFdy`/`fwidth`
measure the rate of change of an interpolated varying *within a single triangle's own linear
interpolation* — they have no visibility into a neighboring, independently-rasterized triangle
from a different tetrahedron. `debug_mode 7` (visualizing `fwidth(local_uv)` directly, log-scaled
for visibility) confirmed this reads as flat, uniform, low brightness across the *entire*
88°-rotation surface, including the region the checkerboard test had just shown to be severely
compressed. This is not a measurement bug — it is the derivative correctly reporting that *each
individual triangle's own* interior gradient is low, which is true; it simply cannot see that
the *neighboring* triangle (from a different, independently-computed tetrahedron) starts from a
substantially different baseline value.

**Tested and ruled out: MSAA and true supersampling, both directly, at the exact problem
rotation, with every shader-side mitigation disabled to isolate the effect.** Given derivatives
can't detect this, the natural next guess was that it's sub-pixel geometric aliasing (many tiny,
differently-shaded triangles landing inside one pixel) — the textbook case for MSAA or
supersampling. Both were tested directly as pure engine/viewport settings, no shader changes:
`Viewport.msaa_3d = MSAA_8X` and `Viewport.scaling_3d_scale = 2.0` (2x linear resolution, i.e.
4x the pixel density, with `SCALING_3D_MODE_BILINEAR`, then downsampled) — **neither changed the
banding at all.** This is a clean, decisive negative result, and it reframes the mechanism
further: the visible stripes are not small-scale, sub-pixel aliasing (which finer sampling would
resolve) — they are **large, coherent, many-pixels-wide bands with sharp transitions between
them**. Increasing sample density doesn't help because the "jump" isn't happening at a
sub-pixel scale; whole contiguous runs of adjacent tetrahedra are producing a consistent (but
wrong, relative to a true smooth parametrization) sampled value across a wide screen-space
region, then jumping to a different consistent-but-wrong value in the next region over. This is
consistent with `mix_weight` becoming pinned near an extreme (0 or 1) across many adjacent,
similarly-oriented near-degenerate tetrahedra at once, rather than each tetrahedron
independently producing unrelated noise.

**What this means for a real fix**: every mitigation tried in this document (alpha suppression,
blur, cell-center fallback, the sensitivity-based trigger, mesh jitter, MSAA, supersampling)
operates either per-fragment or per-sample — all of them are structurally unable to fix a
between-primitive discontinuity at this scale, because none of them has access to what a
*neighboring, independently-computed* tetrahedron decided. A genuine fix needs one of:
1. **Engine-level changes to the Cross-Section slicing algorithm itself** — detecting near-
   degenerate cells during slicing and handling their geometry with a method that guarantees
   agreement between adjacent tetrahedra (e.g., snapping a whole near-degenerate region to a
   single, exactly-shared reference derived from the cell's known relationship to the crossing
   plane, computed once, not independently re-derived per tetrahedron). This is a real
   engineering undertaking in C++ (`engine/modules/4d/`), requiring an engine rebuild, and
   carries real risk since the Cross-Section pipeline is shared by everything that uses it
   (including the terrain).
2. A fundamentally different (non-tetrahedral, or non-grid) meshing scheme for near-degenerate
   regions specifically, which faces the same engineering scope and risk.

Given how many independently-designed, shader-only approaches have now been tried and each hit
this exact same wall, that is a structural conclusion about the problem, not a gap in effort.

## Final shipped decision

**Blur alone**, at `max_blur_radius = 0.12`, `enable_blur = true`, `enable_alpha_suppression =
false`, `enable_cell_center_fallback = false` — same response mechanism as originally shipped,
but now driven by the sensitivity-based trigger (`degeneracy_threshold = 12.0`, in the new
`edge_length / |w1-w2|` units — see "A genuinely better trigger signal" above) instead of the
original raw-gap trigger. Confirmed via crop-level renders at 88°, 80°, 45°, 20°, and identity
(0°, which remains completely unaffected at any threshold, since the `±W` cells provably cannot
cross there regardless of mitigation): 88° is substantially softer/fainter than any earlier
attempt achieved at that severity; 80° is moderately improved (similar to the old metric's best
result, since 80° itself is closer to the clean-case ceiling in this new metric than 88° is);
45°/20° both stay completely clean, with real margin (cost onset was found at threshold ~8,
shipped at 12). This is **still not a complete fix** — the worst-case rotation shows a real,
substantial improvement but still a faint, softened directional pattern under close inspection,
not clean cloud texture — and that honest limit should not be re-litigated without either a new
idea for the trigger signal, or a structurally different mesh/rendering approach (see "What a
real fix would need" below).

## A methodology note: a harness bug produced a false "it's fixed!" reading

Midway through this investigation, a new crop-comparison test harness appeared to show the
precision fix completely eliminating the banding — captures at three different configs
(different `debug_mode`, different rotation, different shader flag combos) all looked like
whatever the *first* config in the sequence should have shown. The actual cause: the harness set
shader parameters and captured the screenshot **in the same frame**, with no settle delay.
Node4D transform changes (`rig.basis`) take effect the same frame they're set, but
`ShaderMaterial.set_shader_parameter()` changes go through the RenderingServer's command queue
and lag by at least one frame before a render reflects them — so every capture was showing the
*previous* config's already-rendered state, including, for the first config, the scene's
untouched initial defaults. Diagnosed by adding a parameter readback print (confirmed the
*value* was set correctly) and comparing full-frame silhouette shape against known-correct
rotations (a symmetric identity-like trapezoid appeared where an extreme 80° rotation was
expected). Fixed by explicitly separating "apply this config" and "capture" into different
ticks with several settle frames in between. Worth remembering for any future shader-parameter
A/B test harness in this engine.

## What a real fix would need (not yet built)

All three per-fragment mitigations share one root limitation: they trigger off a **world-space**
geometric signal (`|w1-w2|`), which does not reliably predict a triangle's actual **screen-space**
prominence — a headless numeric sweep confirmed more small-gap edges exist at the visually
*clean* 45° rotation than at the visibly *banded* 80° one. A genuinely better trigger would need
to be screen-space-aware (e.g. the emitted triangle's actual projected area/aspect ratio), which
would require visibility into a primitive's sibling vertices simultaneously — not available in
Godot's shading language for `shader_type spatial` (no exposed geometry-shader stage). Pursuing
that would mean either a deeper engine-level change or accepting the current, calibrated
trade-off. Given three independently-designed mitigations all hit this same wall, treat that as
a structural property of the problem, not a gap in effort.

## Performance sanity check

The `SubdividedBoxTetraMesh4D` architecture exists to keep the clouds effect as **one mesh
resource with a modest tetrahedron count**, avoiding the older, rejected approach of many
individual 4D objects. Measured headless, at the shipped production config
(`target_cell_size = 8.0`, 96x96 footprint, 4-unit-thick Y), including the cell-center data
added during this investigation:

| Metric | Value |
|---|---|
| Tetrahedra | 21,600 |
| Vertices | 4,394 |
| `simplex_cell_texture_map` entries | 86,400 (4 per tetrahedron) |
| Build time (`SubdividedBoxTetraMesh4D.build()`) | ~298 ms (was ~289 ms before this session's mesh-data addition — no meaningful regression) |
| vs. engine's native `BoxTetraMesh4D` (48-cell, unsubdivided) | 450x more tetrahedra |
| vs. one typical terrain brick (~1,485 tets) | 14.55x one brick's tet count |

The build is a one-time cost, not per-frame: `clouds_layer.gd`'s `_refit_to_terrain()` only
calls `build()` when the footprint actually changes, guarded by an equality check — in practice
once at scene load. 21,600 tetrahedra as a single static mesh resource is well within what the
existing terrain pipeline already handles routinely across its many bricks; this does not
reintroduce the original performance concern the architecture was built to avoid.

## Standalone test scene

`project/clouds_test.tscn` + `project/scripts/clouds_test_rig.gd`: a minimal scene for fast
iteration on the clouds shader/mesh without a full terrain scene's generation cost.
`CloudsTestRig` (`Node4D`) exposes only `grid_size` (96) and `cell_size` (1.0) — the only two
properties `clouds_layer.gd`'s `_refit_to_terrain()` reads — so `CloudsLayer` runs completely
unmodified with no `VoxelTerrain4D`, no ground generation, no POIs, no HUD. Reuses
`voxel_hover_camera_4d.gd` unmodified for interactive orbit/4D-rotate/zoom. Confirmed to load
and render in ~1.8 seconds, versus 15-30+ seconds for the terrain-based test scenes this
replaced for this purpose.

## Reference: full context of the box mesh construction (GDScript)

The 5-tetrahedra-per-cube decomposition used (standard construction, corners indexed by parity
bit pattern `corner_index = dx + 2*dy + 4*dz`):

```
T0 (central, 4 even-parity corners): [0, 3, 5, 6]
T1 (corner at 1): [1, 0, 3, 5]
T2 (corner at 2): [2, 0, 6, 3]
T3 (corner at 4): [4, 0, 5, 6]
T4 (corner at 7): [7, 3, 6, 5]
```
(Corner order within each tuple was adjusted from the "obvious" grouping to give all 5 tets
consistent handedness/winding — verified via signed-volume/scalar-triple-product computation —
since inconsistent winding causes backface-culled holes in the Cross-Section-rendered output, a
real bug hit and fixed during the original investigation, separate from the banding issue.)

Each of the box's 8 macro-cells (one per `(axis, sign)` pair, `axis` in `{X,Y,Z,W}`) is
subdivided independently across its own 3 "free" axes, with per-axis subdivision count derived
from a target world-space cell size — capped at `MAX_SUBDIVISIONS_PER_AXIS = 32` as a hard
safety ceiling after an earlier 1.4-million-tetrahedron config hung the engine outright during
mesh construction. Each sub-cube's own box-local X/Z center is also computed here and threaded
through to `simplex_cell_texture_map`, for the (currently disabled) cell-center fallback — see
"Later investigation" above.
