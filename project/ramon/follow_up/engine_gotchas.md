# Engine and workflow gotchas

Traps in the 4D module, the editor, and this repo's setup that each cost real
time to find. Written 2026-08-14. None of them are documented anywhere else,
and most look like your own bug until you dig.

## Rendering

**`Camera4D.rendering_engine_name` defaults to `""`, and that does NOT mean
cross-section.** (Property name corrected 2026-08-18 - it is
`rendering_engine_name`, not `rendering_engine`; the wrong name is silently
dropped by Godot's scene loader on save/load rather than erroring, which is
exactly how this note itself had it wrong for days.)
`RenderingServer4D::_get_rendering_engine()` resolves an unknown name by
falling through to `_rendering_engines.begin()->value` — whichever registered
first, which is the *wireframe* engine. A scene can look correct in the
editor's 4D tab (which picks its own engine from its toolbar) and render as
white wireframe in Play. Every `Camera4D` in a scene you intend to play needs
`rendering_engine_name = "Cross-section"` set explicitly. Only `player.tscn`,
`MiegakureLook/miegakure_look.tscn` and `MiegakureLook/miegakure_look_2.tscn`
currently do.

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

## Physics

**An `Area4D` never fires for a body that arrives by teleport.** Added
2026-08-19, found building the portal chamber, where every arrival is a
teleport by definition.

`AxisAlignedBoxPhysicsEngine4D::move_and_collide` emits `body_entered_self`
only on a not-overlapping → overlapping *transition*, and it evaluates the
"before" side against a rect cached at the end of the previous
`move_and_collide` (`get_body_shape_rects`, which only recomputes when the
shape *count* changes). Assign a body's `global_position` and neither half
works: on the arrival frame the cached "before" rect is still at the old
location, so the swept test sees no overlap; on every frame after, the body is
already overlapping, so the entered branch is skipped for good.

Measured: the player stood inside a goal `Area4D` for dozens of frames, at a
position confirmed by trace, with the area reporting nothing. **Any trigger a
teleport can deliver a body into must be polled**, not detected — a four-axis
containment test against the box is three lines. See `goal_reached` in
`project/ramon/Portal/scripts/portal_test_chamber_builder.gd`.

Worth an upstream report: recomputing the moving body's "before" rect when its
transform changed outside the physics step would fix it generally.

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

**A `class_name` added outside the editor is invisible to every other script.**
Global class names are resolved from `.godot/global_script_class_cache.cfg`,
which **only the editor regenerates on a project scan**. Write a new script (or
add a `class_name` to an existing one) with the editor closed, then reference it
from another script, and you get `Parse Error: Identifier "Foo" not declared in
the current scope` — the referencing script fails to load entirely, so its node
silently has no script at all and its whole feature is just absent. Measured
2026-08-19: `MiegakureCamera2` was in the cache and `MiegakureLookBuilder2` was
not, so `w_readout_2.gd`'s static reads of
`MiegakureLookBuilder2.STRUCTURE_W_HALF_EXTENT` took the entire HUD down while
the sibling script that only ever *type-annotated* against `MiegakureCamera2`
was fine. Note the failure is at parse time, so no `if`-guard or
`ClassDB.class_exists` check can rescue it.

Two ways out, both worth knowing: open the editor once to force a rescan, or
don't cross-reference another script's `class_name` for constants — pass the
values in as `@export`s, or read them off the node instance you already have.
The second also survives the file being renamed or the folder being moved,
which is the more common way this bites.

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

**A stale submodule pointer is not the safe default — it is the breaking one.**
On 2026-09-23 the branch recorded `engine/modules/4d` at `38307ab` while the
module checked out and compiled here was `7533287`, ten commits ahead. The
instinct was to leave it: an uncommitted pointer feels safer than a committed
one. It is the reverse. One of those ten commits, `d3fda79`, *exposes*
`Mesh4D.get_rect_bounds`, and seven project files call it — including
`ObstacleCourse/scripts/ascent_builder_4d.gd` and `ascent_wall_builder_4d.gd`,
which is gameplay, not tests. Anyone cloning the branch and building what it
recorded would have got a 4D Ascent that does not run, with nothing in the repo
to say why.

Check before deciding, do not reason from feel:

```
cd engine/modules/4d
git merge-base --is-ancestor <local-pointer> origin/main   # 0 = fetchable by anyone
git log --oneline <recorded>..<local-pointer>              # what the branch is missing
```

The `-dirty` suffix in `git diff --submodule=short` means files modified inside
the submodule's own working tree. Those are local-only and do **not** travel
with a pointer bump, so they are not a reason to withhold one.

One straggler from that bump, still unfixed:
`Model/scripts/_diagnose_skinning_budget_runner.gd:66` calls
`update_proxy_mesh_3d()`, which those ten commits replaced with
`append_proxy_mesh_surfaces_3d`.

## Two ways a careful change still breaks

Both of these cost real time on 2026-09-23, with three Claude sessions sharing
one working tree. Neither is Godot's fault and both will be rediscovered.

**Staging a file hunk by hunk can split it below the level the language cares
about.** Three sessions editing one tree meant committing by explicit path and,
for shared files, by explicit hunk — which is what kept anyone from sweeping
anyone. It is also what broke `HEAD`. A filter kept every hunk mentioning
`_rig ` or `_rig =` and dropped `var _rig: Node`, which matches neither. The
commit landed three *uses* of a variable and none of its *declaration*: an
undeclared identifier, which GDScript rejects at parse time, so
`pen_slice_plane_4d.gd` would not have loaded from a clean checkout.

A filter clever enough to split a file by authorship is clever enough to split
it below what the parser needs. Where a file is genuinely mixed, commit it
whole and say whose work it carries in the message.

**A test that waits N frames on a system that polls every N frames is a coin
flip.** `_verify_celebration_runner` filled the pen, waited exactly three
frames, then asserted the game had noticed. `pen_return_4d` tests every
`check_every` frames — 3 by default — so three frames of waiting buys between
zero and one check depending on where its tick counter happens to sit. One run
in three got zero, which reads as a flaky test and sends you looking at
whatever changed most recently. It is not flakiness, it is a race with a
divisor.

Wait on the condition with a frame cap, never on a frame count. And when
widening a wait, check whether the counter you are extending is read by
anything further down — the first fix for this reused `_settle`, which the
sampling loop below it also counts on, and would have started that loop
part-way through its own count. Same shape as the `_rig` bug: a partial change
that leaves one name meaning two things.

**Capture runners cannot run headless.** `_verify_mithra_runner`,
`_verify_ticket_runner` and `_verify_flock_ring_runner` all die on `save_png`
or `texture_2d_get` under `--headless` — the dummy renderer has no texture to
hand them. Their assertions still execute and print, so read the output rather
than the exit code, and run them windowed when you want the images.

## A FABRIK-driven rig cannot be scaled by a parent

`scripts/ik_chain_controller.gd` solves entirely in GLOBAL space - it reads
`target.global_position`, walks `joints[i].global_position`, and writes
`joints[i].global_basis` back - while its `link_lengths` stay in the chain's own
LOCAL units. A uniform scale anywhere up the ancestor chain therefore leaves
every leg reaching for a target it can no longer arrive at, and the global-basis
writes fight the scale rather than composing with it.

This bites the moment you try to reuse a rigged creature at a different size:
the obvious move is the one the lofted goat allows (set the root's basis to a
uniform `Projection` and it fits anywhere), and it is exactly wrong here. Place
a rigged creature instead - translate it onto the floor and build the scene
around its authored size. `ramon/chickenpen/theatre/theatre_creature_4d.gd`
does this and says so at the top.

Corollary: a rigid ROTATION of an ancestor is fine, because the targets rotate
with the joints and the lengths are unchanged.

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

## `Basis4D.from_yz` — the sign is about which END is uphill

`theatre_stage_4d.gd` carries a note saying a NEGATIVE `from_yz` angle is the
one that lifts the far end of a ramp, and that note got copied into
`pen_coop_4d.gd`, where it was wrong. The rule is not about the function; it is
about which end of the slab you meant to raise.

A slab's length runs along its own local `+Z`. `from_yz(-a)` lifts the `+Z` end,
`from_yz(+a)` lifts the `-Z` end. The theatre's aisle climbs towards `+Z`, so it
wants the negative. The coop's ramp reaches OUT from the doorway, so its `+Z`
end is the one lying in the grass, and the negative angle put the high end in
the field and the low end at the door — a plank sloping away from the building
and not touching it. Correct there, wrong here, same line of code.

It survived a long time because it is barely visible on paper: the rise is
0.35 over 1.5, about 13°, so nothing looks obviously broken in the numbers, and
the scene file's cached basis was the OLD sign while the script rebuilt the new
one on `_ready` — so reading the `.tscn` and reading the script disagreed. Only
a rendered frame showed it. Capture the thing.

## `Node4D.global_position = x` is wrong two levels below an offset node

Found 28 Sept 2026 building the cave. `Node4D::set_global_position`
(`engine/modules/4d/nodes/node_4d.cpp`, at module commit `e449710`) converts
through the parent's **local** transform:

```cpp
set_position(node_4d_parent->get_transform().xform_inv(p_global_position));
```

so it is only right when the parent's own parent sits at the origin. Tested:
parent at x = 1000, child's child told `global_position = (1000, 1, 0, 0)`,
reads back `(2000, 1, 0, 0)`. The getter is right, so the error only shows as
things landing in the wrong place. `set_global_basis`, `set_global_transform`
and `set_global_rotation` all go through the parent's GLOBAL transform and are
fine; it is only this one.

It never bit in the pen because nearly everything there hangs straight off an
un-moved `World`. The cave hangs 1 km along x, and a piece of gold knocked loose
by the pickaxe (`Cave/Gold/Nugget0`) landed a kilometre further on.

**Workaround:** set `position` through the parent instead —
`node.position = parent.global_basis.inverse() * (where - parent.global_position)`
(`_place_global` in `pen_rock_gold_4d.gd`). **The fix for Aaron** is one word:
`get_transform()` → `get_global_transform()` on that line.

(Fixed upstream in the module, `0cd7372`; not yet pulled here as of 28 Sept.)

## The cross-section renderer ignores per-vertex colour

`TetraMaterial4D` has `albedo_color_array` and per-vertex / per-cell sources,
and the wireframe path uses them — but `tetra_cross_section_shader.glsl`, which
is what the pen draws with, only ever reads one albedo times a `Texture3D` looked
up at a UVW carried on each tetrahedron corner. Per-vertex colour set the obvious
way draws as flat albedo. `terrain/terrain_bake_4d.gd` gets real per-vertex
colour anyway by giving each vertex a UVW that IS its colour and a colour cube as
the texture; see its header.

## Two of those twelve texture coordinates are 8-bit

Found 28 Sept 2026 chasing a "pattern" in the cave mouth's dark gradient. The
proxy packs each tetrahedron's four corner UVWs into free vertex slots
(`tetra_mesh_4d.cpp`, `append_proxy_mesh_surfaces_3d`): UV, UV2, the normal's
x/z and y/z, VERTEX.y and .z are floats, but the fourth corner's UVW and the
first corner's w go through `set_color`, which Godot stores as RGBA8. With a
colour cube coded linearly (0.25 + 0.5 x linear colour), one 8-bit step is 0.008
of linear light: invisible on grass, 40% of a dark rock's value. A vertex is a
different corner in each tetrahedron around it, so each tetrahedron came out its
own shade - a mosaic of triangles that only showed on dark colours, and most
under the brightest light. It looked like lighting, occlusion, winding and
z-fighting in turn; it was none of them.

**Workaround** (in `terrain_bake_4d.gd`): code the UVW as the sRGB colour, and
make the cube's texels linear light at evenly spaced sRGB values - then an 8-bit
step is an ordinary 8-bit image's step. Use a half-float texture (no sampler
decodes those, whatever the material's hints), and pad each end with a spare
texel: the sampler repeats, and black on the edge texel's centre, rounded down a
hair, blended in white from the far side.

## `Camera4D.world_to_viewport` answers in window pixels

It scales by `viewport->get_size()`, the window's pixel size. A Control lives in
canvas units, which are the same thing until the window's content is scaled
(`Window.content_scale_factor`, or a stretch mode); then everything placed from
it is off by the scale. Multiply by `get_viewport_rect().size /
Vector2(get_viewport().get_size())` (`world_tag_4d.gd`, `dialogue_box_4d.gd`).

## Every tetrahedron is ~1.25 KB of video memory

`TetraMesh4D` builds its cross-section proxy as TWELVE vertices per tetrahedron
at 104 bytes each (`tetra_mesh_4d.h`, `PROXY_VERTS_PER_TET`,
`PROXY_BYTES_PER_VERT`), whether it is on screen or not. Measured in the pen:
the 92,160-tetrahedron hill ring added 229 MB of video memory while costing
0.04 ms of frame time. Drawing is nearly free; memory is not. Budget
tetrahedra for static scenery by memory, not by frame time.
