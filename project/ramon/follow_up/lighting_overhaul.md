# Lighting overhaul — kickstart notes

Purpose of this file: a self-contained briefing so a future session (mine or
anyone else's) can pick up "make 4D geometry shade properly, with shadows and
AO" without re-deriving everything from scratch. Written 2026-08-12, right
after building the first Skybox/Sun4D prototype, since renamed to
`project/ramon/IsoclynicSun/isoclynic_sun.tscn`. Read this before touching any
of the files below.

## Where things stand today

Built a `Sun4D` controller (`project/ramon/IsoclynicSun/scripts/sun_4d.gd`) that
treats the sun as an authoritative 4D direction (`sun_direction_4d: Vector4`),
not a `DirectionalLight3D`. It's `@tool`-annotated so it live-previews in the
editor's "4D" tab, no Play needed. Each frame it dots that direction against
the observer's `global_basis` columns (same convention as
`bearing_utility_4d.gd`) to get a local 3D direction + a `w_fade` (0 = sun
fully rotated out of the visible 3D slice, 1 = fully in it). That feeds three
places:
- A `DirectionalLight3D`'s transform + energy (works correctly, but only in
  Play — see gap below).
- The skybox's custom `shader_type sky` shader (works correctly, only in
  Play).
- A **global shader uniform** `fake_light_direction` (declared in
  `engine/modules/4d/render/cross_section/tetra_cross_section_shader.glsl`,
  registered in `engine/modules/4d/model/mesh/tetra/tetra_material_4d.cpp`'s
  `init_shaders()`, and mirrored in `project/project.godot`'s
  `[shader_globals]`) — this is what actually shades the floor/600-cell mesh
  today, and it's the *only* piece that works live in the editor, because
  it's a RenderingServer-level call with no Viewport dependency at all.

`isoclinic_angle_1`/`isoclinic_angle_2` on `Sun4D` apply an SO(4) double
rotation (`Rotor4D.from_xw(...).rotate_rotor(Rotor4D.from_yz(...))`) to the
sun's own world-space direction — this is deliberately NOT modeling a curved
4D planet surface (the lore reference material, Trym's "Elsewhere/HyperEarth"
digest in Notion, assumes a curved S³ planet with Hopf-coordinate observer
math); our engine's 4D space is flat, so we get the same "unusual sun path"
phenomenon by rotating the sun directly instead.

## Why it's currently fake (the actual root cause, verified in source)

Every `TetraMesh4D`/`TetraMaterial4D` — which is ALL solid 4D mesh rendering
in this engine, not just our scene — goes through
`engine/modules/4d/render/cross_section/tetra_cross_section_shader.glsl`,
which is declared:

```glsl
shader_type spatial;
render_mode skip_vertex_transform, unshaded;
```

`unshaded` means Godot's light-processing step (DirectionalLight3D, shadows,
ambient, SSAO's normal/depth needs) never runs for this material, full stop.
What currently looks like shading is `fake_light_direction` fed into a
hardcoded-style `dot(normal, fake_light_direction)` hack in `fragment()` —
not real lighting. There's a comment in `TetraMesh4D::update_cross_section_mesh()`
(`engine/modules/4d/model/mesh/tetra/tetra_mesh_4d.cpp` ~line 525-588)
admitting the mesh's baked smooth per-vertex normals
(`set_smooth_shading_normals()`, used when building
`600_cell_smooth.g4b` in `workhorse/`) are discarded — flat per-triangle
normals are computed fresh in the vertex shader instead, because
"interpolating the 4D normals gives weird results, needs more experimentation."
That's a real, currently-unsolved problem from whoever built this, not
unfinished polish.

Also worth knowing: the editor's "4D" tab (`EditorMainViewport4D`) and Play
mode both render through the same `CrossSectionRenderingEngine4D`, but it
builds a **separate private `World3D`/scenario per viewport it's currently
servicing** (`cross_section_rendering_engine_4d.cpp` `setup_for_viewport()`).
In Play mode this ends up connected to our scene's `WorldEnvironment`; in the
editor tab it's wired to the plugin's own internal `SubViewport` instead,
which nothing ever calls `set_environment()`/`scenario_set_environment()` on.
That's why the sky/WorldEnvironment only shows up in Play, never in the "4D"
tab — a real, currently-unbridged gap in the editor plugin, not something we
did wrong. We deliberately left this alone (decided not worth the editor-
plugin surgery for this pass) — worth knowing this is still true if picked
back up later, in case a future engine update happens to fix it.

## The actual plan, in order, with confidence estimates

1. **Real diffuse shading (~85-90% confidence, do this first).** Drop
   `unshaded` from `tetra_cross_section_shader.glsl`'s `render_mode`. The
   shader already computes and writes `NORMAL` (flat per-triangle, in
   `vertex()`) — that alone should be enough for Godot's built-in
   light-processing to respond to `DirectionalLight3D` correctly. Will need
   sane default `ROUGHNESS`/`METALLIC`/`SPECULAR` values set in `fragment()`
   so it doesn't render broken/black. Expect a faceted look (flat normals),
   not smooth — that's a separate, harder problem (see below).

2. **Shadows (~60-70% confidence, genuine unknown to test).** The
   encouraging part: the shader already cleanly separates "which 4D
   hyperplane to slice at" (baked into per-instance uniforms
   `modelview_basis`/`modelview_origin`, tied to the *viewing* camera,
   computed once regardless of render pass) from "project this already-
   sliced 3D position to clip space" (`POSITION = PROJECTION_MATRIX *
   vec4(position.xyz, 1.0)`) — that second step is exactly what Godot swaps
   per-pass for shadow map rendering, so in principle the same frame's
   already-resolved 3D slice gets correctly re-projected from the light's
   point of view, with no 4D-specific confusion about "what would the light
   see." The real unknown: whether `render_mode skip_vertex_transform`
   (needed for the custom slicing math to not get clobbered by Godot's
   default vertex transform) is honored correctly by Godot's shadow-pass
   vertex shader generation, or whether it causes broken/degenerate shadow
   geometry. **This needs an actual test-and-debug pass, not just a diff.**
   Check `engine/godot/servers/rendering/renderer_rd/forward_mobile/scene_shader_forward_mobile.cpp`
   for how shadow-pass shader variants get generated relative to
   `render_mode` flags, as a starting point.

3. **SSAO (~70-75% confidence, mostly downstream of #1).** Godot's SSAO is
   screen-space, needs depth + normal buffers, both of which should exist
   once the material isn't unshaded. Main risk is aesthetic, not technical —
   flat per-triangle normals might make AO look distractingly faceted rather
   than nicely detailed, until/unless smooth normals get solved too.

4. **Smooth normals (separate, harder, optional for basic correctness).**
   The genuinely unsolved problem flagged by the original code comment.
   Needed for a *polished* look, not for shading/shadows/AO to be
   technically correct. Treat as its own follow-up, not a blocker for 1-3.

**Overall: getting each piece technically working is more likely than not;
getting it to look good together (no shadow acne at slice boundaries, no
distracting faceting) needs real iteration — budget this as its own multi-day
pass, not a quick follow-up.**

## Scope/ownership caution (don't skip this)

`engine/modules/4d` is described in the repo's own `CLAUDE.md` as
"open-source and shared beyond this project" (tracks the external
`godot-dimensions/godot-4d` repo) — this is NOT scoped to just Quantum
Horizon. Everything done today (the `fake_light_direction` hack) was
deliberately kept tiny and backward-compatible (default value reproduces the
old hardcoded look exactly) specifically because of this. A full lighting
overhaul is a much bigger, structural change to that same shared code — worth
raising with whoever maintains/reviews that module *before* committing to it,
not after. As of this writing, none of today's changes are committed to git —
they're local working-tree diffs only.

## Also worth remembering when picking this up

- The engine shader is compiled INTO the binary via a generated header
  (`tetra_cross_section_shader.glsl.gen.h`) — editing the `.glsl` source does
  nothing until an engine rebuild (`run_editor_windows.bat -DoNotUpdate
  -SkipIdeSetup` for a fast incremental build). The running editor holds a
  file lock on the binary — close it before rebuilding.
- Global shader uniforms declared in `project.godot`'s `[shader_globals]`
  can have a load-ordering race with engine startup; the robust fix was to
  ALSO register the default via C++ (`RenderingServer::global_shader_parameter_add()`
  in `TetraMaterial4D::init_shaders()`) so it's guaranteed to exist before the
  shader ever compiles, regardless of ProjectSettings load timing. Keep this
  pattern if adding more global uniforms.
- Hand-writing `NodePath(...)` values for `@export var x: SomeNodeType`
  properties in a `.tscn` does NOT auto-resolve to a real node reference —
  use `@onready var _x = $"../Path"` instead (confirmed via direct headless
  diagnostic testing, not guessing).
