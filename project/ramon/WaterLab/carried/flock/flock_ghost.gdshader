shader_type spatial;
render_mode skip_vertex_transform, cull_disabled, unshaded, blend_mix, depth_draw_never;

// The flock's GHOST: the starlings that are NOT in your slice, drawn faint and see-through,
// tinted by which side of it they are on. Used with the Lookout's projection toggle (P): the
// Combined renderer ghosts every 4D mesh along W, but the birds are not 4D meshes - they are
// drawn by flock_bird.gdshader into the cut only - so without this they would be the one
// thing the projection leaves out.
//
// The same multimesh as the birds, drawn a second time with this material. The vertex code is
// flock_bird.gdshader's (keep the two in step), except that a bird is drawn whole when it is
// OUT of the slice and not at all when it is in it (the real pass draws those), fading out
// over ghost_range metres of W.

uniform vec4 view_basis_x;
uniform vec4 view_basis_y;
uniform vec4 view_basis_z;
uniform vec4 view_basis_w;
uniform vec4 view_origin;
uniform float w_radius = 0.35;
uniform float flap_rate = 11.0;
// How far along W a ghost is still drawn, and how strongly at its nearest.
uniform float ghost_range = 6.0;
uniform float ghost_strength : hint_range(0.0, 1.0) = 0.45;
// Ana (+W) and kata (-W): the camera's own W-fade colours.
uniform vec4 ana_colour : source_color = vec4(0.25, 0.45, 1.0, 1.0);
uniform vec4 kata_colour : source_color = vec4(1.0, 0.35, 0.25, 1.0);
varying float ghost_alpha;
varying float ghost_side;

void vertex() {
	vec4 p = vec4(MODEL_MATRIX[0][0], MODEL_MATRIX[1][0], MODEL_MATRIX[2][0], MODEL_MATRIX[3][0]);
	vec4 f = vec4(MODEL_MATRIX[0][1], MODEL_MATRIX[1][1], MODEL_MATRIX[2][1], MODEL_MATRIX[3][1]);
	vec4 r = vec4(MODEL_MATRIX[0][2], MODEL_MATRIX[1][2], MODEL_MATRIX[2][2], MODEL_MATRIX[3][2]);
	mat4 view_basis = mat4(view_basis_x, view_basis_y, view_basis_z, view_basis_w);
	vec4 rel = view_basis * p + view_origin;
	vec4 ahead_4d = view_basis * f;
	vec4 right_4d = view_basis * r;

	float size = INSTANCE_CUSTOM.z;
	float depth = max(w_radius * size, 0.0001);
	// Whole when out of the slice, gone when in it; fading with distance along W.
	float out_of_slice = abs(rel.w) >= depth ? 1.0 : 0.0;
	float reach = clamp(1.0 - abs(rel.w) / max(ghost_range, 0.001), 0.0, 1.0);
	ghost_alpha = out_of_slice * reach;
	ghost_side = rel.w >= 0.0 ? 1.0 : 0.0;

	vec3 ahead = ahead_4d.xyz;
	float ahead_length = length(ahead);
	ahead = ahead_length > 0.00001 ? ahead / ahead_length : vec3(0.0, 0.0, -1.0);
	vec3 right = right_4d.xyz - dot(right_4d.xyz, ahead) * ahead;
	float right_length = length(right);
	right = right_length > 0.00001 ? right / right_length : normalize(cross(ahead, vec3(0.0, 1.0, 0.0)) + vec3(0.0001));
	vec3 up = cross(ahead, right);

	vec3 v = VERTEX;
	float wing = UV.x;
	if (wing > 0.0) {
		float phase = INSTANCE_CUSTOM.x;
		float rate = flap_rate * (INSTANCE_CUSTOM.w > 0.0 ? INSTANCE_CUSTOM.w : 1.0);
		float beat = sin(TIME * TAU * rate * (0.92 + 0.16 * fract(phase * 7.31)) + phase * TAU);
		float angle = (0.16 + beat * 0.75 * INSTANCE_CUSTOM.y) * (0.75 + 0.5 * wing);
		float side = v.x >= 0.0 ? 1.0 : -1.0;
		float shoulder = 0.02;
		float out_x = abs(v.x) - shoulder;
		v = vec3(side * (shoulder + out_x * cos(angle)), v.y + out_x * sin(angle), v.z);
	}
	v *= size * (ghost_alpha > 0.0 ? 1.0 : 0.0);
	VERTEX = rel.xyz + right * v.x + up * v.y + ahead * v.z;
}

void fragment() {
	ALBEDO = mix(kata_colour.rgb, ana_colour.rgb, ghost_side);
	ALPHA = ghost_alpha * ghost_strength;
}
