# Isoclynic Sun — how to reinstate

Self-contained recovery note, written 2026-08-13. The Isoclynic Sun's editor
preview was switched off that day by reverting a 5-file engine change. This
file holds everything needed to bring it back without re-deriving it, including
the full patch. Nothing else needs to be consulted.

## What is and isn't still in the repo

**Still here, untouched, committed** — all the project-side content:

- `project/ramon/IsoclynicSun/isoclynic_sun.tscn` — the scene, including the
  `WorldEnvironment` + `Sky` + sky `ShaderMaterial`.
- `project/ramon/IsoclynicSun/scripts/sun_4d.gd` — the `Sun4D` controller.
- `project/ramon/IsoclynicSun/shaders/isoclynic_sun_sky.gdshader` — the sky
  shader.

**Removed** — only the engine side: commit `2e82a1e` in the
`engine/modules/4d` submodule, "Let the editor's 4D tab see the scene's
WorldEnvironment". 93 insertions across 5 files. The submodule is back on
`godot-dimensions/godot-4d` at `cb39334`.

## Why it was parked

Aaron's upstream `light` branch (`1fb0d44`, "[WIP] Add 4D lights to the
cross-section renderer", 2026-08-12) rewrites **4 of the 5 files** this patch
touches:

| file | Aaron's change |
|---|---|
| `cross_section_rendering_engine_4d.cpp` | +89 / −67 |
| `cross_section_rendering_engine_4d.h` | +11 / −3 |
| `rendering_engine_4d.cpp` | +30 / −49 |
| `rendering_engine_4d.h` | +19 / −12 |
| `tetra_cross_section_shader.glsl` | untouched |

`rendering_engine_4d.cpp` comes out 19 lines *shorter* — it is a refactor of
the exact class `get_world_3d()` was added to, not an extension of it. Carrying
this on a fork meant re-deriving it against an in-flight refactor on every push
by its maintainer, for the benefit of an editor preview.

He is also adding real `DirectionalLight4D` / `OmniLight4D` / `SpotLight4D`
nodes. Those are the genuine version of what `fake_light_direction` fakes, so
**the shader half of this patch is scaffolding his system replaces** — when
reinstating, expect to want only the `WorldEnvironment` bridge half.

## Current symptoms (expected, not bugs)

- The sun and sky are invisible in the editor's "4D" tab. They still work in
  Play, driven by `DirectionalLight3D` and the sky shader.
- `fake_light_direction` exists nowhere in the engine. `sun_4d.gd` (~line 162)
  still sets it via `set_shader_parameter`; that is a silent no-op.
- Tetra cross-section shading uses upstream's hardcoded up-vector.

## How to reinstate

Three routes, cheapest first. **Wait until Aaron's light work lands on
`upstream/main`** — reapplying before then recreates the exact problem this
revert solved.

1. **Cherry-pick.** The commit is preserved in the submodule on the `ramon`
   remote (`ramon/main`) and in the local branch
   `main-backup-2026-08-13-135411`:
   ```
   git -C engine/modules/4d cherry-pick 2e82a1e
   ```
   Expect conflicts in the 4 files above once his refactor has landed.
2. **Reapply only the bridge half** — likely the right call. Take the
   `get_world_3d()` additions and the `_sync_editor_world_environment()` /
   `_find_world_environment()` pair, and drop the
   `tetra_cross_section_shader.glsl` hunk entirely in favour of his real lights.
3. **Offer it upstream as a PR** rather than carrying a fork at all. It is
   editor-only, a no-op when the scene has no `WorldEnvironment`, and the
   shader default preserved prior behaviour — it was written to be
   upstreamable. This is the ending that stops the problem recurring.

Note the patch's shader comment references a stale path
(`project/ramon/Skybox/scripts/sun_4d.gd`); the scene was later renamed to
`IsoclynicSun`. Fix that if reapplying.

## The patch in full

```diff
diff --git a/render/cross_section/cross_section_rendering_engine_4d.cpp b/render/cross_section/cross_section_rendering_engine_4d.cpp
index 488950d..57e94f1 100644
--- a/render/cross_section/cross_section_rendering_engine_4d.cpp
+++ b/render/cross_section/cross_section_rendering_engine_4d.cpp
@@ -14,10 +14,55 @@
 #endif
 #endif
 
+#if GODOT_MODULE && defined(TOOLS_ENABLED)
+#include "core/config/engine.h"
+#include "editor/editor_interface.h"
+#include "scene/3d/world_environment.h"
+
+WorldEnvironment *CrossSectionRenderingEngine4D::_find_world_environment(Node *p_node) {
+	WorldEnvironment *world_env = Object::cast_to<WorldEnvironment>(p_node);
+	if (world_env != nullptr) {
+		return world_env;
+	}
+	for (int i = 0; i < p_node->get_child_count(); i++) {
+		WorldEnvironment *found = _find_world_environment(p_node->get_child(i));
+		if (found != nullptr) {
+			return found;
+		}
+	}
+	return nullptr;
+}
+
+void CrossSectionRenderingEngine4D::_sync_editor_world_environment() {
+	if (!Engine::get_singleton()->is_editor_hint() || !_cross_section_world_3d.is_valid()) {
+		return;
+	}
+	// Always assign explicitly, including a null Ref<Environment> when the
+	// currently-edited scene has no WorldEnvironment - this previously only
+	// ever set an environment when one was found, so switching to view a
+	// scene with none left whatever a PREVIOUSLY viewed scene's
+	// WorldEnvironment had applied still active. Every frame this should
+	// exactly mirror what's actually in the scene being looked at right now,
+	// nothing carried over from elsewhere.
+	Node *edited_scene_root = EditorInterface::get_singleton()->get_edited_scene_root();
+	Ref<Environment> environment;
+	if (edited_scene_root != nullptr) {
+		WorldEnvironment *world_env = _find_world_environment(edited_scene_root);
+		if (world_env != nullptr) {
+			environment = world_env->get_environment();
+		}
+	}
+	_cross_section_world_3d->set_environment(environment);
+}
+#endif
+
 void CrossSectionRenderingEngine4D::render_frame() {
 	ERR_FAIL_NULL(RenderingServer::get_singleton());
 	ERR_FAIL_NULL(get_camera());
 	ERR_FAIL_NULL(get_viewport());
+#if GODOT_MODULE && defined(TOOLS_ENABLED)
+	_sync_editor_world_environment();
+#endif
 	_current_pass++;
 	update_camera();
 	// Maps global to cameral-local, aka world space to view space.
diff --git a/render/cross_section/cross_section_rendering_engine_4d.h b/render/cross_section/cross_section_rendering_engine_4d.h
index e02afa5..06a237d 100644
--- a/render/cross_section/cross_section_rendering_engine_4d.h
+++ b/render/cross_section/cross_section_rendering_engine_4d.h
@@ -11,6 +11,10 @@
 #include "scene/resources/3d/world_3d.h"
 #endif
 
+#if GODOT_MODULE && defined(TOOLS_ENABLED)
+class WorldEnvironment;
+#endif
+
 class CrossSectionRenderingEngine4D : public RenderingEngine4D {
 	GDCLASS(CrossSectionRenderingEngine4D, RenderingEngine4D);
 
@@ -31,6 +35,18 @@ private:
 	RID create_instance();
 	void _cleanup_render_resources();
 
+#if GODOT_MODULE && defined(TOOLS_ENABLED)
+	// Bridges the editor's live "4D" tab preview (which renders through this
+	// engine's own private, disposable World3D - see setup_for_viewport())
+	// to the edited scene's WorldEnvironment, which otherwise has no path to
+	// that private scenario at all. Play mode doesn't need this: by the time
+	// a running scene's WorldEnvironment applies itself, this engine's
+	// private world already IS that scene's viewport's world. Editor-only,
+	// and a no-op if the edited scene has no WorldEnvironment.
+	static WorldEnvironment *_find_world_environment(Node *p_node);
+	void _sync_editor_world_environment();
+#endif
+
 protected:
 	static void _bind_methods() {}
 
@@ -39,6 +55,7 @@ public:
 	virtual void setup_for_viewport() override;
 	virtual void cleanup_for_viewport() override;
 	virtual void render_frame() override;
+	virtual Ref<World3D> get_world_3d() const override { return _cross_section_world_3d; }
 
 	virtual ~CrossSectionRenderingEngine4D();
 };
diff --git a/render/cross_section/tetra_cross_section_shader.glsl b/render/cross_section/tetra_cross_section_shader.glsl
index c27ccd1..0d00656 100644
--- a/render/cross_section/tetra_cross_section_shader.glsl
+++ b/render/cross_section/tetra_cross_section_shader.glsl
@@ -12,6 +12,16 @@ instance uniform vec4 modelview_basis_w;
 uniform vec4 albedo : source_color;
 uniform sampler3D albedo_texture : hint_default_white, source_color;
 
+// Driven per-material by Sun4D (see project/ramon/Skybox/scripts/sun_4d.gd)
+// via set_shader_parameter() on specific materials it's told to control
+// (Sun4D.mesh_materials) - deliberately NOT a global shader uniform. A
+// global value has no concept of "which scene," so it bled into every other
+// scene's TetraMesh4D materials for as long as a Sun4D was open in any
+// editor tab, active or not. A plain per-material uniform means any scene
+// without its own Sun4D simply keeps this shader's declared default below,
+// untouched by anything happening elsewhere.
+uniform vec3 fake_light_direction = vec3(0.0, 1.0, 0.0);
+
 varying vec3 uvw;
 
 // Maps from an arbitrary edge index to the indices of the vertices in a tetrahedron [a,b,c,d].
@@ -116,5 +126,10 @@ void vertex() {
 
 void fragment() {
 	NORMAL = normalize(NORMAL);
-	ALBEDO = albedo.rgb * texture(albedo_texture, uvw).rgb * ((dot((vec4(NORMAL, 0.0) * INV_VIEW_MATRIX).xyz, vec3(0.0, 1.0, 0.0)) / 2.0) + 0.5);
+	// fake_light_direction's length is intentionally not normalized to 1: it's
+	// scaled by Sun4D's w-fade (0 when the sun has rotated fully out of the
+	// visible 3D slice, 1 when fully in it), so the dot product's own
+	// linearity flattens this toward neutral (0.5) as the fade drops, instead
+	// of needing a second uniform.
+	ALBEDO = albedo.rgb * texture(albedo_texture, uvw).rgb * ((dot((vec4(NORMAL, 0.0) * INV_VIEW_MATRIX).xyz, fake_light_direction) / 2.0) + 0.5);
 }
diff --git a/render/rendering_engine_4d.cpp b/render/rendering_engine_4d.cpp
index 35b07b1..356594a 100644
--- a/render/rendering_engine_4d.cpp
+++ b/render/rendering_engine_4d.cpp
@@ -90,6 +90,10 @@ String RenderingEngine4D::get_friendly_name() const {
 	return friendly_name;
 }
 
+Ref<World3D> RenderingEngine4D::get_world_3d() const {
+	return Ref<World3D>();
+}
+
 void RenderingEngine4D::setup_for_viewport_if_needed(Viewport *p_for_viewport) {
 	_viewport = p_for_viewport;
 	if (_setup_viewports.has(p_for_viewport)) {
@@ -143,6 +147,8 @@ void RenderingEngine4D::_bind_methods() {
 	ClassDB::bind_method(D_METHOD("set_mesh_relative_positions", "mesh_relative_positions"), &RenderingEngine4D::set_mesh_relative_positions);
 	ADD_PROPERTY(PropertyInfo(Variant::ARRAY, "mesh_relative_positions"), "set_mesh_relative_positions", "get_mesh_relative_positions");
 
+	ClassDB::bind_method(D_METHOD("get_world_3d"), &RenderingEngine4D::get_world_3d);
+
 	GDVIRTUAL_BIND(_get_friendly_name);
 	GDVIRTUAL_BIND(_prefers_wireframe_meshes);
 	GDVIRTUAL_BIND(_setup_for_viewport);
diff --git a/render/rendering_engine_4d.h b/render/rendering_engine_4d.h
index 7505ec7..2af0ec2 100644
--- a/render/rendering_engine_4d.h
+++ b/render/rendering_engine_4d.h
@@ -6,11 +6,13 @@
 #if GDEXTENSION
 #include <godot_cpp/classes/ref_counted.hpp>
 #include <godot_cpp/classes/viewport.hpp>
+#include <godot_cpp/classes/world3d.hpp>
 #include <godot_cpp/variant/typed_array.hpp>
 #elif GODOT_MODULE
 #include "core/object/ref_counted.h"
 #include "core/variant/typed_array.h"
 #include "scene/main/viewport.h"
+#include "scene/resources/3d/world_3d.h"
 #endif
 
 class RenderingEngine4D : public RefCounted {
@@ -60,6 +62,13 @@ public:
 	virtual void cleanup_for_viewport();
 	virtual void render_frame();
 
+	// Base default is null (e.g. WireframeCanvasRenderingEngine4D has no 3D
+	// world concept at all). CrossSectionRenderingEngine4D overrides this to
+	// expose its private World3D, so callers (e.g. the editor's "4D" tab)
+	// can apply a WorldEnvironment to it without needing engine-internal
+	// access - see cross_section_rendering_engine_4d.h/.cpp.
+	virtual Ref<World3D> get_world_3d() const;
+
 	GDVIRTUAL0RC(String, _get_friendly_name);
 	GDVIRTUAL0R(bool, _prefers_wireframe_meshes);
 	GDVIRTUAL0(_setup_for_viewport);
```
