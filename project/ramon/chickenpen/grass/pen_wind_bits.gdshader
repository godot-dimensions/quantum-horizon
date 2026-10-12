shader_type spatial;
render_mode skip_vertex_transform, cull_disabled, diffuse_lambert_wrap, specular_disabled;

// Leaves and bits on the wind over the pen (Ramon, 3 Oct: "i want some flying leaves in the
// sky, but in a way that is natural. more wind would mean more leaves and bits"). Built and
// moved here, every frame, from the instance number, as the grass is (pen_grass.gdshader): a
// plain 3D MultiMesh in the Cross-section engine's own World3D, moved into the camera's frame
// by hand. pen_grass_4d.gd sets the frame, the wind and how many there are.
//
// WHAT FLIES. Most are bits - seed fluff, pollen, specks - small and pale, catching the low sun;
// a third are leaves, bigger, in dry greens and browns, tumbling. Leaves keep lower, the fluff
// goes higher, and higher the harder it blows.
//
// HOW. Each has a start in a box round you (box wide, top high), wrapped so the box follows you
// and they stay put in the world. They go downwind by `travel` - the distance the air has
// moved, added up by the script, so changing the wind speeds them up rather than throwing them
// across the sky - each at its own share of it, with a slow swirl across and up and down from
// the noise, and turning end over end.
//
// THE 4D PART. Each has a w, and drifts slowly through W round the slice: thin in W, as a blade
// of grass is, so the cut shows it full on its own slice and shrinking as it leaves. Now and
// then one blows in from ana or kata.

uniform vec4 frame[8];
uniform sampler2D wind_noise : filter_linear, repeat_enable;
uniform vec2 wind_dir = vec2(0.82, 0.57);
// The wind now (m/s, smoothed by the script) and how far the air has gone, m.
uniform float wind_now = 3.0;
uniform float travel = 0.0;
uniform float box = 44.0;
uniform float top = 14.0;
uniform float w_span = 2.0;
uniform float w_radius = 0.5;
uniform float leaf_share = 0.3;
uniform float leaf_size = 0.07;
uniform float bit_size = 0.022;
uniform vec3 leaf_a : source_color = vec3(0.36, 0.42, 0.14);
uniform vec3 leaf_b : source_color = vec3(0.56, 0.47, 0.20);
uniform vec3 leaf_c : source_color = vec3(0.42, 0.29, 0.15);
uniform vec3 bit_colour : source_color = vec3(0.93, 0.90, 0.80);

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
	// About y by a, then about x by b.
	mat3 ry = mat3(vec3(ca, 0.0, -sa), vec3(0.0, 1.0, 0.0), vec3(sa, 0.0, ca));
	mat3 rx = mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, cb, sb), vec3(0.0, -sb, cb));
	return rx * ry;
}

void vertex() {
	mat4 vb = mat4(frame[0], frame[1], frame[2], frame[3]);
	vec4 view_origin = frame[4];
	vec4 camera_world = frame[5];
	vec4 slice_normal = frame[6];
	vec2 centre = frame[7].xy;
	float id = float(INSTANCE_ID);
	float r1 = hash(id, 1.0);
	float r2 = hash(id, 2.0);
	float r3 = hash(id, 3.0);
	float r4 = hash(id, 4.0);
	float r5 = hash(id, 5.0);
	float r6 = hash(id, 6.0);
	bool leaf = hash(id, 7.0) < leaf_share;
	// Its own share of the air's speed: leaves drag, fluff rides it.
	float speed_k = leaf ? mix(0.5, 0.8, r3) : mix(0.75, 1.0, r3);
	float lift = clamp(wind_now / 6.0, 0.15, 1.6);
	float h01 = r4 * r4;
	float y0 = leaf ? 0.3 + h01 * 6.0 * lift : 0.4 + h01 * top * lift;
	// The swirl: slow noise across, along and up, its own place in the noise.
	vec2 n_uv = vec2(r1, r2) * 3.0 + vec2(TIME * 0.021, TIME * 0.017);
	vec2 swirl = vec2(texture(wind_noise, n_uv).r, texture(wind_noise, n_uv + vec2(0.37, 0.61)).r) - 0.5;
	float bob = texture(wind_noise, n_uv * 1.7 + vec2(0.13, 0.29)).r - 0.5;
	vec2 xz = vec2(r1, r2) * box + wind_dir * travel * speed_k + swirl * mix(4.0, 10.0, r4);
	float y = max(0.12, y0 + bob * (leaf ? 2.5 : 4.0) * lift);
	// Wrapped round you; faded out at the box's edge so none pops in or out there.
	vec2 rel = mod(xz - centre + box * 0.5, box) - box * 0.5;
	vec2 p_xz = centre + rel;
	float edge_fade = 1.0 - smoothstep(box * 0.36, box * 0.5, max(abs(rel.x), abs(rel.y)));
	// Its w: round where the slice crosses this spot, drifting slowly through W.
	vec3 dp = vec3(p_xz.x - camera_world.x, y - camera_world.y, p_xz.y - camera_world.z);
	float nw = slice_normal.w;
	float w_slice = abs(nw) > 0.25 ? camera_world.w - dot(slice_normal.xyz, dp) / nw : camera_world.w;
	float w_drift = texture(wind_noise, n_uv * 0.5 + vec2(0.71, 0.19)).r * 2.0 + r5;
	vec4 p = vec4(p_xz.x, y, p_xz.y, w_slice + (fract(w_drift) - 0.5) * w_span);
	vec4 rel4 = vb * p + view_origin;
	float s2 = 1.0 - (rel4.w / w_radius) * (rel4.w / w_radius);
	float section = s2 > 0.0 ? sqrt(s2) : 0.0;
	float size = (leaf ? leaf_size * mix(0.7, 1.3, r6) : bit_size * mix(0.6, 1.4, r6)) * section * edge_fade;
	if (size <= 0.0003 || rel4.z > 0.5) {
		VERTEX = vec3(0.0, 0.0, 1.0);
		NORMAL = vec3(0.0, 1.0, 0.0);
		v_colour = vec3(0.0);
		v_glow = 0.0;
	} else {
		// End over end, faster in a stronger wind; a leaf a little slower than a speck.
		float spin = (0.4 + wind_now * 0.15) * (leaf ? 0.7 : 1.0);
		float a = TIME * mix(1.5, 5.0, r5) * spin * (r6 < 0.5 ? -1.0 : 1.0) + r6 * 6.2831853;
		float b = TIME * mix(1.0, 3.5, r6) * spin + r5 * 6.2831853;
		mat3 turn = tumble(a, b);
		// The shape: a diamond from the mesh's UV (x across -1..1, y along 0..1), a leaf longer
		// than it is wide, a speck round.
		vec3 local = vec3(UV.x * (leaf ? 0.38 : 0.5), UV.y - 0.5, 0.0) * size;
		vec3 offs = turn * local;
		vec4 v = vb * (p + vec4(offs, 0.0)) + view_origin;
		VERTEX = v.xyz;
		NORMAL = normalize((vb * vec4(turn * vec3(0.0, 0.0, 1.0), 0.0)).xyz);
		float pick = hash(id, 8.0);
		vec3 lc = pick < 0.45 ? leaf_a : (pick < 0.8 ? leaf_b : leaf_c);
		v_colour = leaf ? lc * mix(0.8, 1.15, r3) : bit_colour * mix(0.85, 1.05, r3);
		// Fluff catches the low sun whichever way it turns: a little light of its own, or against
		// the bright sky it reads as a dark speck. Leaves a touch.
		v_glow = leaf ? 0.12 : 0.55;
	}
}

void fragment() {
	ALBEDO = v_colour;
	EMISSION = v_colour * v_glow;
	ROUGHNESS = 0.8;
	// Thin things lit through from behind by the low sun.
	BACKLIGHT = v_colour * 0.6;
}
