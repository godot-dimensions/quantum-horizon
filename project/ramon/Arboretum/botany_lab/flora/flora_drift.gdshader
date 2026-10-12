shader_type spatial;
render_mode skip_vertex_transform, cull_disabled, diffuse_lambert_wrap, specular_disabled;

// BOTANY LAB, round 3 (follow_up/arboretum.md section 9, step 14): petals, pollen and leaves on the air
// (Ramon, 10 Oct: "maybe the wind creates some leaves in the wind"). CARRIED from the pen's
// chickenpen/grass/pen_wind_bits.gdshader (the pen itself untouched): a plain 3D MultiMesh in the
// Cross-section engine's own World3D, moved into the camera's frame by hand; flora_drift_4d.gd sets the
// frame, the wind and how many are up.
//
// TWO WAYS TO FLY (`stream`):
//   0  a box of air (the flower room): each piece has a start in the box and goes downwind by `travel`
//      (the distance the air has moved), wrapped in the box, swirling, faded at its walls
//   1  a stream from a source (the hall's oak): each piece leaves the crown, goes downwind `reach`
//      metres while falling to the floor, tumbling, and starts again; faded in at the crown and out
//      at the end
//
// THE 4D PART, as in the pen: each piece has a w, round where the slice crosses its spot and drifting
// slowly through W: thin in W, so the cut shows it full on its own slice and shrinking as it leaves.

uniform vec4 frame[7];
uniform sampler2D wind_noise : filter_linear, repeat_enable;
uniform vec2 wind_dir = vec2(0.82, 0.57);
uniform float wind_now = 1.5;
uniform float travel = 0.0;
uniform int stream = 0;
// The box: its middle and size (x, z), its floor and top (y), in the node's space.
uniform vec2 box_centre = vec2(0.0);
uniform vec2 box_size = vec2(18.0, 18.0);
uniform float floor_y = 0.2;
uniform float top_y = 7.0;
// The stream: its source (x, y, z) and radius, how far it carries, how far it falls.
uniform vec3 source = vec3(0.0, 4.0, 0.0);
uniform float source_radius = 2.5;
uniform float reach = 14.0;
uniform float w_span = 1.2;
uniform float w_radius = 0.4;
// Shares: petals (or leaves) and specks; sizes.
uniform float leaf_share = 0.55;
uniform float leaf_size = 0.05;
uniform float bit_size = 0.014;
uniform vec3 leaf_a : source_color = vec3(0.96, 0.72, 0.82);
uniform vec3 leaf_b : source_color = vec3(0.98, 0.96, 0.94);
uniform vec3 leaf_c : source_color = vec3(0.78, 0.66, 0.92);
uniform vec3 bit_colour : source_color = vec3(1.0, 0.86, 0.42);
uniform float bit_glow = 0.9;
uniform float leaf_glow = 0.18;

varying vec3 v_colour;
varying float v_glow;

float hash(float id, float k) {
	vec3 p3 = fract(vec3(id * 0.1031, k * 0.1030, (id + k) * 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

mat3 tumble(float a, float b) {
	float ca = cos(a);
	float sa = sin(a);
	float cb = cos(b);
	float sb = sin(b);
	mat3 ry = mat3(vec3(ca, 0.0, -sa), vec3(0.0, 1.0, 0.0), vec3(sa, 0.0, ca));
	mat3 rx = mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, cb, sb), vec3(0.0, -sb, cb));
	return rx * ry;
}

void vertex() {
	mat4 vb = mat4(frame[0], frame[1], frame[2], frame[3]);
	vec4 view_origin = frame[4];
	vec4 camera_world = frame[5];
	vec4 slice_normal = frame[6];
	float id = float(INSTANCE_ID);
	float r1 = hash(id, 1.0);
	float r2 = hash(id, 2.0);
	float r3 = hash(id, 3.0);
	float r4 = hash(id, 4.0);
	float r5 = hash(id, 5.0);
	float r6 = hash(id, 6.0);
	bool leaf = hash(id, 7.0) < leaf_share;
	float speed_k = leaf ? mix(0.5, 0.8, r3) : mix(0.75, 1.0, r3);
	vec2 n_uv = vec2(r1, r2) * 3.0 + vec2(TIME * 0.021, TIME * 0.017);
	vec2 swirl = vec2(texture(wind_noise, n_uv).r, texture(wind_noise, n_uv + vec2(0.37, 0.61)).r) - 0.5;
	float bob = texture(wind_noise, n_uv * 1.7 + vec2(0.13, 0.29)).r - 0.5;
	vec2 p_xz;
	float y;
	float fade;
	vec2 wd = normalize(wind_dir);
	if (stream == 1) {
		// Its age along the stream: the air's travel, its own share, its own start.
		float age = fract(travel * speed_k / max(reach, 0.1) + r1);
		vec2 start = source.xz + (vec2(r2, r4) - 0.5) * 2.0 * source_radius;
		vec2 across = vec2(-wd.y, wd.x);
		p_xz = start + wd * age * reach + across * swirl.x * mix(1.0, 3.0, age) + wd * swirl.y;
		float fall = leaf ? 1.0 : 0.55;
		float y0 = source.y + (r5 - 0.5) * source_radius * 0.8;
		y = mix(y0, floor_y, pow(age, mix(0.8, 1.4, r6)) * fall) + bob * 0.8;
		y = max(y, floor_y);
		fade = smoothstep(0.0, 0.08, age) * (1.0 - smoothstep(0.85, 1.0, age));
	} else {
		float h01 = r4;
		y = mix(floor_y, top_y, leaf ? h01 * 0.8 : h01) + bob * 1.2;
		y = clamp(y, floor_y, top_y);
		vec2 xz = (vec2(r1, r2) - 0.5) * box_size + wd * travel * speed_k + swirl * mix(1.5, 4.0, r4);
		vec2 rel = mod(xz + box_size * 0.5, box_size) - box_size * 0.5;
		p_xz = box_centre + rel;
		vec2 edge = abs(rel) / (box_size * 0.5);
		fade = 1.0 - smoothstep(0.82, 1.0, max(edge.x, edge.y));
	}
	vec3 dp = vec3(p_xz.x - camera_world.x, y - camera_world.y, p_xz.y - camera_world.z);
	float nw = slice_normal.w;
	float w_slice = abs(nw) > 0.25 ? camera_world.w - dot(slice_normal.xyz, dp) / nw : camera_world.w;
	float w_drift = texture(wind_noise, n_uv * 0.5 + vec2(0.71, 0.19)).r * 2.0 + r5;
	vec4 p = vec4(p_xz.x, y, p_xz.y, w_slice + (fract(w_drift) - 0.5) * w_span);
	vec4 rel4 = vb * p + view_origin;
	float s2 = 1.0 - (rel4.w / w_radius) * (rel4.w / w_radius);
	float section = s2 > 0.0 ? sqrt(s2) : 0.0;
	float size = (leaf ? leaf_size * mix(0.7, 1.3, r6) : bit_size * mix(0.6, 1.4, r6)) * section * fade;
	if (size <= 0.0003 || rel4.z > 0.5) {
		VERTEX = vec3(0.0, 0.0, 1.0);
		NORMAL = vec3(0.0, 1.0, 0.0);
		v_colour = vec3(0.0);
		v_glow = 0.0;
	} else {
		float spin = (0.4 + wind_now * 0.15) * (leaf ? 0.7 : 1.0);
		float a = TIME * mix(1.5, 5.0, r5) * spin * (r6 < 0.5 ? -1.0 : 1.0) + r6 * 6.2831853;
		float b = TIME * mix(1.0, 3.5, r6) * spin + r5 * 6.2831853;
		mat3 turn = tumble(a, b);
		// A petal is rounder than the pen's leaves, a speck round.
		vec3 local = vec3(UV.x * (leaf ? 0.55 : 0.5), UV.y - 0.5, 0.0) * size;
		vec3 offs = turn * local;
		vec4 v = vb * (p + vec4(offs, 0.0)) + view_origin;
		VERTEX = v.xyz;
		NORMAL = normalize((vb * vec4(turn * vec3(0.0, 0.0, 1.0), 0.0)).xyz);
		float pick = hash(id, 8.0);
		vec3 lc = pick < 0.45 ? leaf_a : (pick < 0.8 ? leaf_b : leaf_c);
		v_colour = leaf ? lc * mix(0.85, 1.1, r3) : bit_colour * mix(0.85, 1.05, r3);
		v_glow = leaf ? leaf_glow : bit_glow;
	}
}

void fragment() {
	ALBEDO = v_colour;
	EMISSION = v_colour * v_glow;
	ROUGHNESS = 0.8;
	BACKLIGHT = v_colour * 0.6;
}
