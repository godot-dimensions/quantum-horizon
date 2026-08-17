# Engine and workflow gotchas

Traps in the 4D module, the editor, and this repo's setup that each cost real
time to find. Written 2026-08-14. None of them are documented anywhere else,
and most look like your own bug until you dig.

## Rendering

**`Camera4D.rendering_engine` defaults to `""`, and that does NOT mean
cross-section.** `RenderingServer4D::_get_rendering_engine()` resolves an
unknown name by falling through to `_rendering_engines.begin()->value` —
whichever registered first, which is the *wireframe* engine. A scene can look
correct in the editor's 4D tab (which picks its own engine from its toolbar)
and render as white wireframe in Play. Every `Camera4D` in a scene you intend
to play needs `rendering_engine = "Cross-section"` set explicitly. Only
`player.tscn` currently does.

**The editor's 4D tab renders through its own private `World3D`.**
`CrossSectionRenderingEngine4D::setup_for_viewport()` instantiates one and
calls `viewport->set_world_3d()` with it, so nothing on the edited scene's
environment reaches it. That is why a `WorldEnvironment` sky only ever appears
in Play. 4D *meshes* are built straight into that private world, so anything
made of geometry previews fine — which is why `SkyBoxClouds` is a mesh dome
rather than a `Sky` resource.

**There is no "preview from this Camera4D".** The 4D editor plugin has no
equivalent of the 3D viewport's Preview checkbox — grep the whole of
`editor/viewport/` and nothing comes back. If a script culls against a scene
camera, you cannot see what it sees without pressing Play.

**Shading is flat-faceted and cannot be smoothed from the project side.** The
cross-section shader computes flat per-triangle normals in its vertex stage
and explicitly discards the mesh's baked smooth normals — see the comment in
`TetraMesh4D::update_cross_section_mesh()`. Rounder geometry gives you *more*
facets, never softer ones.

**Only two colour paths reach that shader.**
`TetraMaterial4D::update_cross_section_material()` sets exactly `albedo` and
`albedo_texture`. `albedo_color_array` is never consulted, so PER_CELL and
PER_VERT both render pure white. A `Texture3D` sampled by cell UVW is the only
way to vary colour across a tetrahedral surface.

**You can swap the shader per material from GDScript.** `get_cross_section_material()`
is script-exposed and `Material4D` only assigns its built-in shader when the
slot is empty, so a replacement survives. `_cross_section_material` is
per-instance (only `_cross_section_shader` is static), so this cannot leak into
other scenes. `SkyBoxClouds/shaders/skybox_sky.gdshader` uses this.

**Recipe: giving one scene the old flat/unlit look without any `Light4D`.**
Aaron's 4D light system (2026-08-16, `056f661` in `engine/modules/4d`) changed
the shared `tetra_cross_section_shader.glsl` from `render_mode
skip_vertex_transform, unshaded;` with a baked-in
`dot(normal, up) / 2 + 0.5` fake-light term, to plain `skip_vertex_transform`
with real per-light shading (`tetra_cross_section_light_shader.glsl`'s
`light()`, appended in C++ by `TetraMaterial4D::init_shaders()` — only for the
engine's *own* default shader, never for a project-supplied one). Any scene
with no `Light4D`/`WorldEnvironment4D` now renders pure black instead of the
old always-visible flat shading, since without `unshaded`, `ALBEDO` is just a
PBR input that gets multiplied by real light + ambient before display — zero
light in the scene means zero output no matter what `ALBEDO` computes to.
`Phase Maze` (`project/ramon/PhaseMaze/`) hit this and was fixed this way,
2026-08-17:
1. Do NOT add `Light4D`/`WorldEnvironment4D` nodes to the scene — that's
   Aaron's real system, and mixing it in gives inconsistent results (e.g. a
   lit floor next to black walls, whichever surfaces the light doesn't reach).
2. Make a project-local copy of `tetra_cross_section_shader.glsl` (same
   pattern as `SkyBoxClouds/shaders/skybox_sky.gdshader`), with
   `render_mode skip_vertex_transform, unshaded;` and the fragment shader
   restoring the exact old line — still present as a comment in the engine
   shader today: `ALBEDO = albedo.rgb * texture(albedo_texture, uvw).rgb *
   ((dot((vec4(NORMAL, 0.0) * INV_VIEW_MATRIX).xyz, vec3(0.0, 1.0, 0.0)) /
   2.0) + 0.5);`. See `project/ramon/PhaseMaze/shaders/phase_maze_flat_shaded.gdshader`.
3. In whatever GDScript builds that scene's `TetraMaterial4D`s, swap the
   shader in BEFORE setting `albedo_texture_3d` — setting the texture re-runs
   `update_cross_section_material()`, which only assigns the built-in shader
   when the slot is still empty:
   ```gdscript
   var cross_section: ShaderMaterial = material.get_cross_section_material()
   cross_section.shader = load("res://path/to/flat_shaded.gdshader")
   material.albedo_texture_3d = texture
   ```
   See `_make_material()` in `phase_maze_builder.gd` / `phase_maze_2_builder.gd`.

This is entirely project-side (no engine fork) and doesn't touch the shared
default shader, so it can't break any other scene that genuinely wants
Aaron's real lighting.

## Bugs in the shared module

**`ArrayTetraMesh4D::merge_with` mis-sizes the UVW map.** It resizes the
texture map to `end_cell_index_count / 4`, but the map holds one entry per
cell-**vertex** — `TetraMesh4D` itself asserts
`texture_map_count == cell_indices_count`. The write offset goes negative and
every merge spams `Index p_index = -N is out of bounds`. The boundary-normals
block beside it divides by 4 correctly, because those really are per-cell; the
texture-map block copied the pattern where it does not apply. Worth reporting
upstream. Workaround: clear the template's texture map before merging, which
skips the branch entirely.

## Editor traps

**A `MeshInstance4D` serializes whatever mesh it holds.** Saving a scene with
generated geometry embeds it — measured at 24 MB for 90k tetrahedra, one line
of it 17 million characters. Far worse than the size: `mesh` is then non-null
on load, so an `if mesh == null: generate()` guard skips generation, and every
piece of runtime setup inside `generate()` is skipped with it. That is what
made the skydome invisible in Play while looking fine in the editor — its
shader assignment lives in `generate()`. Strip on `NOTIFICATION_EDITOR_PRE_SAVE`
and rebuild on `POST_SAVE`, as `voxel_port.tscn` does.

**`res://` paths are case-sensitive; Windows is not.** Writing files into
`ramon/Skybox01/` when the folder is really `SkyBox01` succeeds silently, but
Godot then loads the same script under two path strings — and if it declares a
`class_name`, the second copy collides with the first and fails to parse with
"hides a global script class". The stale spelling also lodges in
`.godot/editor/script_editor_cache.cfg`, `editor_layout.cfg` and
`uid_cache.bin`, so it survives fixing the source. After any rename: fix the
path strings, delete `.godot/uid_cache.bin`, and rescan.

**@tool scripts that gain exports while a scene is open come back with those
properties `Nil`.** Godot keeps the node's old property table until the scene
is reloaded. A typed parameter turns that into a hard failure; `if not
my_new_bool` silently reads Nil as false and the feature just appears broken.
Reload the scene, and prefer Nil-tolerant reads in tool code.

## Repo workflow

**Open the editor without pulling or rebuilding:**
`run_editor_windows.bat -DoNotUpdate -SkipIdeSetup`. Step 1 of the launcher is
a submodule update — that is what pulls, not the build. A bare run also
checks out the recorded `engine/godot` pointer, which right now differs from
what is built and triggers a full 27-file renderer rebuild.

**A local branch rename does not reach the remote.** `phaze_maze` was renamed
to `RamonPrototypes` locally on 2026-08-10; the branch kept tracking
`origin/phaze_maze`, so months of work published under the old name. Fixed
with `git push -u origin RamonPrototypes`. `origin/phaze_maze` is now a stale
duplicate.

**Submodule URL changes need `git submodule sync`.** Pointing `.gitmodules` at
a fork without syncing leaves the submodule's own `origin` on upstream, so the
next update silently pulls the fork commit away. See
`isoclynic_sun_reinstate.md` for the incident.

## State as of 2026-08-14

- `engine/godot` is deliberately left modified: the branch records `73e1646`
  (Aaron's 4D light slice params) but the built binary is `89fe8053`, Trym's
  older pointer, carried in from the `terrain-review` merge. Syncing means a
  full renderer rebuild. Do it when you want Aaron's lights compiled in.
- `engine/modules/4d` is on `b11c7ce`, an unmerged upstream branch
  (`fix-camera4d-process-frame-reconnect`) that Trym's hover camera needs. It
  does NOT contain `cb39334` "Fix crashes with GDExtension" — harmless here,
  since this project builds the module in rather than as a GDExtension.
- Open threads: the voxel port's visible holes (measured NOT to be a topology
  problem — see `voxel_port.md`, and Trym's independent finding in
  `OVERNIGHT_BAKES_README.md` pointing at brick selection radius), and the
  parked Isoclynic Sun bridge (`isoclynic_sun_reinstate.md`), waiting on
  Aaron's 4D lights reaching upstream main.
