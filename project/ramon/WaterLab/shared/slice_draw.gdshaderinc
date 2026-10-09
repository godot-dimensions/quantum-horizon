// WATER LAB: the 4D part shared by everything drawn the starlings' way (the pen's
// chickenpen/flock/flock_bird.gdshader): the tank's koi, its eel, its weed and bubbles, and the
// sea's sardines.
//
// The Cross-section engine draws in camera space: its 3D camera sits at the origin with no
// transform, and every 4D mesh is moved into the camera's frame and cut at w = 0 there. A plain 3D
// multimesh added to the same World3D lands in the same picture, lit by the same lights and hidden
// by the same depth, as long as it does that move itself (render_mode skip_vertex_transform).
//
// EACH INSTANCE IS AN ANIMAL IN ITS HERD'S 4D SPACE. The 12 transform floats are three Vector4 rows,
// read here as columns of MODEL_MATRIX: position, heading (ahead), and side (right). The herd node
// (shared/slice_herd_4d.gd) sets the view uniforms on every RenderingServer4D.pre_render:
// rel = view_basis * p + view_origin is the point in the camera's frame, rel.w how far off the slice.
//
// THE CUT: an animal is a 4D body, its 3D shape stretched through W as an ellipsoid, so the slice
// through it is the whole shape on the slice, shrinking to nothing at |w| = its W radius:
// sqrt(1 - (w / r)^2), the section of a 4D ellipsoid. Exact for an animal whose own W axis is the
// camera's; one heading partly along W is drawn with its heading and side projected into the slice,
// which is close while they keep mostly level in W (the herds' W springs see to that).

uniform vec4 view_basis_x;
uniform vec4 view_basis_y;
uniform vec4 view_basis_z;
uniform vec4 view_basis_w;
uniform vec4 view_origin;

struct SliceFrame {
	vec4 rel;      // the animal's origin in the camera's frame (w: off the slice)
	vec3 ahead;    // its heading in the slice, unit
	vec3 right;    // its side in the slice, unit, square to ahead
	vec3 up;       // ahead x right... z x x = y: modelled +Z ahead, +X right, +Y up
};

SliceFrame slice_frame(mat4 model) {
	vec4 p = vec4(model[0][0], model[1][0], model[2][0], model[3][0]);
	vec4 f = vec4(model[0][1], model[1][1], model[2][1], model[3][1]);
	vec4 r = vec4(model[0][2], model[1][2], model[2][2], model[3][2]);
	mat4 vb = mat4(view_basis_x, view_basis_y, view_basis_z, view_basis_w);
	SliceFrame o;
	o.rel = vb * p + view_origin;
	vec3 ahead = (vb * f).xyz;
	float al = length(ahead);
	ahead = al > 0.00001 ? ahead / al : vec3(0.0, 0.0, -1.0);
	vec3 right = (vb * r).xyz;
	right -= dot(right, ahead) * ahead;
	float rl = length(right);
	right = rl > 0.00001 ? right / rl : normalize(cross(ahead, vec3(0.0, 1.0, 0.0)) + vec3(0.0001));
	o.ahead = ahead;
	o.right = right;
	o.up = cross(ahead, right);
	return o;
}

// How much of an animal `radius` deep in W (half depth) the slice shows at `w` off it: 1 on it,
// 0 at or past its edge.
float slice_section(float w, float radius) {
	float d = max(radius, 0.00001);
	float left = 1.0 - (w * w) / (d * d);
	return left > 0.0 ? sqrt(left) : 0.0;
}

// A point of the model (+Z ahead, +X right, +Y up, metres) into the camera's frame.
vec3 slice_place(SliceFrame o, vec3 v) {
	return o.rel.xyz + o.right * v.x + o.up * v.y + o.ahead * v.z;
}

vec3 slice_turn(SliceFrame o, vec3 n) {
	return normalize(o.right * n.x + o.up * n.y + o.ahead * n.z);
}

// Cheap hashes and value noise, for patterns and wobble.
float sd_hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float sd_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = sd_hash(i);
	float b = sd_hash(i + vec2(1.0, 0.0));
	float c = sd_hash(i + vec2(0.0, 1.0));
	float d = sd_hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float sd_fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		s += a * sd_noise(p);
		p = p * 2.03 + vec2(17.1, 9.7);
		a *= 0.5;
	}
	return s;
}
