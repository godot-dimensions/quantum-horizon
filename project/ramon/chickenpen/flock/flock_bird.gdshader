shader_type spatial;
render_mode skip_vertex_transform, cull_disabled;

// One starling of the murmuration, drawn by the Cross-section engine's own 3D pass.
//
// The Cross-section engine draws in camera space: its 3D camera sits at the origin with no
// transform, and every 4D mesh is moved into the camera's frame and cut at w = 0 there
// (tetra_cross_section_shader.glsl). So a plain 3D multimesh added to the same World3D
// lands in the same picture, lit by the same suns and hidden by the same depth, as long as
// it does that move itself. Each instance carries its bird in the flock's 4D space - the
// 12 transform floats are three Vector4 rows: position, heading, right wing - and this
// shader takes them into the camera's frame with the view uniforms flock_4d.gd sets on
// every RenderingServer4D.pre_render.
//
// The bird is a 4D body: its 3D shape stretched along W by w_radius as an ellipsoid, so the
// slice through it is the whole bird at w = 0, shrinking to nothing at |w| = w_radius -
// sqrt(1 - (w / w_radius)^2), the section of a 4D ellipsoid. That is exact for a bird whose
// own W axis is the camera's; a bird flying partly along W is drawn with its heading and
// wings projected into the slice, which is close for a flock that keeps mostly level in W.

// The flock's space in the camera's frame: rel = view_basis * p + view_origin.
uniform vec4 view_basis_x;
uniform vec4 view_basis_y;
uniform vec4 view_basis_z;
uniform vec4 view_basis_w;
uniform vec4 view_origin;
// Half the bird's depth along W at size 1, in metres.
uniform float w_radius = 0.35;
uniform float flap_rate = 11.0;
uniform vec4 albedo : source_color = vec4(0.045, 0.043, 0.05, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.42;
uniform float specular_amount : hint_range(0.0, 1.0) = 0.6;
// One bird drawn white, or none (-1): the Lookout's white starling (lookout/, opt in from
// pen_flock_4d.gd's white_bird). Never the hawk, whose custom w is its beat rate.
uniform int white_index = -1;
uniform vec3 white_albedo : source_color = vec3(0.93, 0.91, 0.86);
varying float white;

void vertex() {
	vec4 p = vec4(MODEL_MATRIX[0][0], MODEL_MATRIX[1][0], MODEL_MATRIX[2][0], MODEL_MATRIX[3][0]);
	vec4 f = vec4(MODEL_MATRIX[0][1], MODEL_MATRIX[1][1], MODEL_MATRIX[2][1], MODEL_MATRIX[3][1]);
	vec4 r = vec4(MODEL_MATRIX[0][2], MODEL_MATRIX[1][2], MODEL_MATRIX[2][2], MODEL_MATRIX[3][2]);
	mat4 view_basis = mat4(view_basis_x, view_basis_y, view_basis_z, view_basis_w);
	vec4 rel = view_basis * p + view_origin;
	vec4 ahead_4d = view_basis * f;
	vec4 right_4d = view_basis * r;

	white = (INSTANCE_ID == white_index && INSTANCE_CUSTOM.w <= 0.0) ? 1.0 : 0.0;
	float size = INSTANCE_CUSTOM.z;
	float depth = max(w_radius * size, 0.0001);
	float left = 1.0 - (rel.w * rel.w) / (depth * depth);
	float section = left > 0.0 ? sqrt(left) : 0.0;

	vec3 ahead = ahead_4d.xyz;
	float ahead_length = length(ahead);
	ahead = ahead_length > 0.00001 ? ahead / ahead_length : vec3(0.0, 0.0, -1.0);
	vec3 right = right_4d.xyz - dot(right_4d.xyz, ahead) * ahead;
	float right_length = length(right);
	right = right_length > 0.00001 ? right / right_length : normalize(cross(ahead, vec3(0.0, 1.0, 0.0)) + vec3(0.0001));
	// Modelled with +Z ahead, +X right, +Y up: z x x = y.
	vec3 up = cross(ahead, right);

	// Wings (UV.x > 0) swing about the shoulder, the outer half further than the inner.
	vec3 v = VERTEX;
	vec3 n = NORMAL;
	float wing = UV.x;
	if (wing > 0.0) {
		float phase = INSTANCE_CUSTOM.x;
		// Custom w scales the beat rate - 0 for a starling, about 0.36 for the hawk.
		float rate = flap_rate * (INSTANCE_CUSTOM.w > 0.0 ? INSTANCE_CUSTOM.w : 1.0);
		float beat = sin(TIME * TAU * rate * (0.92 + 0.16 * fract(phase * 7.31)) + phase * TAU);
		// Gliding holds a shallow V; beating swings through it.
		float angle = (0.16 + beat * 0.75 * INSTANCE_CUSTOM.y) * (0.75 + 0.5 * wing);
		float side = v.x >= 0.0 ? 1.0 : -1.0;
		float shoulder = 0.02;
		float out_x = abs(v.x) - shoulder;
		float c = cos(angle);
		float s = sin(angle);
		v = vec3(side * (shoulder + out_x * c), v.y + out_x * s, v.z);
		n = vec3(-side * s * n.y + n.x * c, n.y * c + abs(n.x) * s, n.z);
	}
	v *= size * section;
	VERTEX = rel.xyz + right * v.x + up * v.y + ahead * v.z;
	NORMAL = normalize(right * n.x + up * n.y + ahead * n.z);
}

void fragment() {
	ALBEDO = mix(albedo.rgb * COLOR.rgb, white_albedo, white);
	ROUGHNESS = roughness;
	SPECULAR = specular_amount;
}
