# Gizmo fix for Aaron

**Status: Aaron said he'd fix it upstream (24 Sep 2026). Carried locally until he does.**

The patch below is live in `engine/modules/4d` right now as an uncommitted local
change, re-applied across two submodule bumps. When Aaron's fix lands it will stop
applying — that is the signal to drop it, not a problem to solve.

## What the module does today

In `editor/viewport/editor_transform_gizmo_4d.cpp`,
`_update_gizmo_mesh_transform()`:

```cpp
ortho:       scale_dist_number = p_camera->get_orthographic_size() * 0.4f;
perspective: scale_dist_number = gizmo_transform.origin.distance_to(
                                     camera_transform.origin) * 0.4f;
```

`0.4` hard-coded in both branches. No focal-length term, and nothing anywhere in
the module reads `editors/3d/manipulator_gizmo_size`.

## The two bugs

### 1. Focal length is ignored

A perspective camera projects a point as `(x, y) * focal / z`. The gizmo's radius
is `distance * factor`, so the distance cancels and its on-screen size is just
`factor * focal`. Scaling with distance is deliberate and correct — it holds the
gizmo steady while flying around. But a camera at any focal length other than the
default is then mis-sized in direct proportion, with nothing compensating.

The 4D editor's own camera settings write `focal_length_4d`. At **3.14**, an
ordinary choice for a narrower view, the factor of `0.4` becomes **1.26** — the
gizmo's radius exceeds half the viewport, at every zoom level. Zooming does not
help, because the model and the gizmo scale together.

**Repro:** set a `Camera4D`'s `focal_length_4d` to 3.14, select any node.

This is what made creature modelling awkward: the gizmo covered the thing being
edited.

### 2. The editor's gizmo-size slider does nothing in 4D

Godot has **Manipulator Gizmo Size** at `editors/3d/manipulator_gizmo_size`
(`editor_settings.cpp:949`, default **80**, range 16–160). This module already
reuses `editors/3d/*` for navigation feel and freelook, but the 4D gizmo never
reads it, so the slider sits there doing nothing for 4D users.

## Why it is a bug fix, not a behaviour change

Both corrections normalise against the existing defaults:

- `80 / 200 == 0.4` exactly — the literal being replaced.
- At `Camera4D`'s default focal length the ratio is exactly 1.

On a default setup the computed factor is `0.4`, bit for bit what it was. Only
users already getting a wrong answer see any difference.

## The patch

Verified to apply cleanly to `82832ec`. Most of the 45 lines are comments, because
the focal-length cancellation is not obvious from the surrounding code.

```diff
diff --git a/editor/viewport/editor_transform_gizmo_4d.cpp b/editor/viewport/editor_transform_gizmo_4d.cpp
index b57d26e..6ed35ab 100644
--- a/editor/viewport/editor_transform_gizmo_4d.cpp
+++ b/editor/viewport/editor_transform_gizmo_4d.cpp
@@ -337,11 +337,47 @@ void EditorTransformGizmo4D::_update_gizmo_mesh_transform(const Camera4D *p_came
 		_mesh_holder->set_global_transform(gizmo_transform);
 		return;
 	}
+	// The gizmo's geometry is built at radius 1, so this factor is the tangent of its
+	// on-screen half-angle. The former hard-coded 0.4 therefore made the gizmo span
+	// about 44 degrees of the view at every zoom level, which dwarfs small models and
+	// cannot be escaped by zooming, since model and gizmo scale together.
+	//
+	// Derived from Godot's existing 3D gizmo-size preference rather than a new
+	// setting, matching how this module already reuses editors/3d/* for navigation
+	// feel and freelook. The default is unchanged for everyone: the 3D setting
+	// defaults to 80, and 80 / 200 == 0.4 exactly. Anyone who finds the gizmo
+	// overbearing can now turn down the "Manipulator Gizmo Size" slider they already
+	// have, and the 4D gizmo follows it.
+	real_t gizmo_size_factor = real_t(int(EDITOR_GET("editors/3d/manipulator_gizmo_size"))) / 200.0f;
 	real_t scale_dist_number;
 	if (p_camera->get_projection_type() == Camera4D::PROJECTION4D_ORTHOGRAPHIC) {
-		scale_dist_number = p_camera->get_orthographic_size() * 0.4f;
+		scale_dist_number = p_camera->get_orthographic_size() * gizmo_size_factor;
 	} else {
-		scale_dist_number = gizmo_transform.origin.distance_to(camera_transform.origin) * 0.4f;
+		// Correct for the camera's focal length, which this sizing otherwise ignores.
+		//
+		// A perspective camera projects a point to the screen as (x, y) * focal / z, and
+		// the gizmo's radius is set to distance * factor - so the distance cancels and
+		// its on-screen size is simply factor * focal. Scaling with distance therefore
+		// holds the gizmo steady while flying around, but a camera set to anything other
+		// than the default focal length is silently mis-sized, in direct proportion.
+		//
+		// That is not a small effect at the extremes. The 4D editor's own camera
+		// settings write focal_length_4d, and at 3.14 - a fairly ordinary choice for a
+		// narrower view - the factor of 0.4 yields 1.26, meaning the gizmo's radius
+		// exceeds half the viewport and it swallows the screen at every zoom level.
+		//
+		// Normalizing by the default focal length rather than by 1 keeps this a pure
+		// bug fix: at Camera4D's defaults the ratio is exactly 1 and the gizmo is
+		// unchanged for everyone. Both perspective flags are handled because
+		// PROJECTION4D_PERSPECTIVE_DUAL sets both, and each divides the size again.
+		const Camera4D::ProjectionType4D projection_type = p_camera->get_projection_type();
+		if (projection_type & Camera4D::PROJECTION4D_PERSPECTIVE_4D) {
+			gizmo_size_factor *= real_t(CAMERA_4D_DEFAULT_FOCAL_LENGTH) / real_t(p_camera->get_focal_length_4d());
+		}
+		if (projection_type & Camera4D::PROJECTION4D_PERSPECTIVE_3D) {
+			gizmo_size_factor *= real_t(CAMERA_4D_DEFAULT_FOCAL_LENGTH) / real_t(p_camera->get_focal_length_3d());
+		}
+		scale_dist_number = gizmo_transform.origin.distance_to(camera_transform.origin) * gizmo_size_factor;
 	}
 	if (scale_dist_number < 1e-4) {
 		scale_dist_number = 1e-4;
diff --git a/nodes/camera_4d.h b/nodes/camera_4d.h
index 163e1ed..31a7427 100644
--- a/nodes/camera_4d.h
+++ b/nodes/camera_4d.h
@@ -2,6 +2,11 @@
 
 #include "node_4d.h"
 
+// The focal length both projections start at. Named because code elsewhere needs to
+// express "relative to a default camera" - the transform gizmo sizes itself against
+// it so that a camera at a different focal length does not silently mis-scale it.
+#define CAMERA_4D_DEFAULT_FOCAL_LENGTH 1.25
+
 class Camera4D : public Node4D {
 	GDCLASS(Camera4D, Node4D);
 
@@ -47,8 +52,8 @@ private:
 	WFadeMode _w_fade_mode = W_FADE_TRANSPARENCY;
 
 	// These have wrappers with trig functions, so let's use double to avoid precision loss.
-	double _focal_length_4d = 1.25;
-	double _focal_length_3d = 1.25;
+	double _focal_length_4d = CAMERA_4D_DEFAULT_FOCAL_LENGTH;
+	double _focal_length_3d = CAMERA_4D_DEFAULT_FOCAL_LENGTH;
 
 	Color _w_fade_color_negative = Color(0.0f, 0.5f, 1.0f);
 	Color _w_fade_color_positive = Color(1.0f, 0.5f, 0.0f);
```

## Applying it

Saved alongside this note as `gizmo_fix_for_aaron.patch`:

```
cd engine/modules/4d && git apply ../../../project/ramon/follow_up/gizmo_fix_for_aaron.patch
```

Do this **after** an engine rebuild picks up the recorded submodule pointer, not
before — and note that `update_submodules` does a `reset --hard`, which wipes the
working-tree change every time. That is the treadmill this note exists to end.
