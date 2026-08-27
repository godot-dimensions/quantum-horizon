shader_type canvas_item;

// Rounds the corners of whatever it is applied to - the preview video or the
// still fallback - with a separately adjustable radius per corner.
//
// A shader rather than a mask texture or a NinePatch because the thing being
// rounded is a VIDEO. Control.clip_contents clips to a rectangle only, and a
// mask texture would have to be regenerated every time the pane resized or a
// radius changed. An SDF costs one fragment's arithmetic and is resolution
// independent, so the same material works at 1080p and on a 4K panel.
//
// `rect_size` has to be pushed from GDScript because a canvas_item shader has no
// intrinsic knowledge of its Control's size; UV alone would give an ellipse on a
// non-square pane rather than equal corners.

// The visible FRAME, in pixels. Corners are rounded against this, not against
// the node the shader happens to be on.
uniform vec2 rect_size = vec2(576.0, 324.0);

// The node's own size, and where its top-left sits relative to the frame's.
//
// These exist because the video is deliberately LARGER than the frame: it is
// scaled to cover, then slid vertically to a chosen crop, and the frame clips
// the overflow. Rounding against the node's own rect would put the corners
// somewhere off-screen. Working in frame space keeps them on the visible edge.
// For nodes that exactly fill the frame, pass node_size = rect_size and
// node_offset = 0 and this reduces to the simple case.
uniform vec2 node_size = vec2(576.0, 324.0);
uniform vec2 node_offset = vec2(0.0, 0.0);

// Per corner, in pixels: x = top-left, y = top-right, z = bottom-right,
// w = bottom-left. Ordered clockwise from the top-left, matching how CSS and
// Godot's own StyleBoxFlat name their corners.
uniform vec4 corner_radius = vec4(14.0, 14.0, 14.0, 14.0);

// Edge softness in pixels. 0 gives a hard, aliased edge; ~1 is a clean
// antialiased one. Exposed because a very large radius benefits from slightly
// more feathering.
uniform float edge_softness : hint_range(0.0, 4.0) = 1.0;

// Signed distance to a rounded rectangle, negative inside.
//
// The radius is picked per quadrant, which is what allows four different
// corners. In UV space y increases downward, so y < 0 after centring is the TOP
// half - hence top-left/top-right map to the negative-y cases.
float rounded_box(vec2 point, vec2 half_size, vec4 radii) {
	float radius;
	if (point.x > 0.0) {
		radius = (point.y < 0.0) ? radii.y : radii.z;
	} else {
		radius = (point.y < 0.0) ? radii.x : radii.w;
	}
	// Never let a radius exceed half the shorter side, or opposite corners
	// overlap and the shape inverts into artefacts.
	radius = min(radius, min(half_size.x, half_size.y));
	vec2 q = abs(point) - half_size + radius;
	return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - radius;
}

void fragment() {
	vec2 half_size = rect_size * 0.5;
	// This fragment's position in FRAME space, then centred.
	vec2 point = UV * node_size + node_offset - half_size;
	float distance = rounded_box(point, half_size, corner_radius);
	float softness = max(edge_softness, 0.0001);
	COLOR.a *= 1.0 - smoothstep(-softness, softness, distance);
}
