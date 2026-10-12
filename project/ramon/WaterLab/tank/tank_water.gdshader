shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, blend_mix, fog_disabled;

// WATER LAB: the tank's water, one full-screen pass in the Cross-section engine's own World3D, drawn
// after everything opaque (tank/tank_water_4d.gd adds it and sets these uniforms every frame).
//
// THE RENDERER IS OPAQUE ONLY, so water you can see INTO has to be put back over the picture. Every
// pixel's view ray (the 3D camera sits at the origin of the camera's own frame) is taken into the
// tank's frame, where the water is a 4D box, and met against it slab by slab, in all four axes: that
// is right for any tilt of the slice, whatever 3D shape the cut of the box is. Against the depth
// buffer the ray then gives:
//   - how much water lies between you and what you see: its colour by Beer-Lambert, as in Trym's
//     sea (water4d.gdshader), clearer here, as a tank should be;
//   - where it ends on something in the water (the sand, a stone, a koi): caustics, the light the
//     moving surface focuses, fading with depth;
//   - whether it leaves through the top: the surface from below, a silver mirror past the critical
//     angle, the room seen through it inside it (Snell's window), rippling;
//   - soft shafts of light hanging down from the surface.
// The ripples, the caustics and the shafts are functions of x, z AND W in the tank's frame, so a
// turned slice cuts a different pattern, as it cuts a different tank.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

// The camera's frame in the tank's: p_tank = to_tank * p_camera + cam_in_tank (columns).
uniform vec4 to_tank_x;
uniform vec4 to_tank_y;
uniform vec4 to_tank_z;
uniform vec4 to_tank_w;
uniform vec4 cam_in_tank;
// The water's half extents (x, y, z, W) about the tank's middle; y's top is the surface.
uniform vec4 half_ext = vec4(6.0, 2.1, 1.6, 1.6);
// Per metre, per channel: red goes first.
uniform vec3 absorption = vec3(0.26, 0.065, 0.045);
uniform vec3 scatter_color : source_color = vec3(0.10, 0.36, 0.40);
uniform float scatter_strength = 0.42;
uniform float caustic_strength = 0.85;
uniform float shaft_strength = 0.35;
uniform float ripple_strength = 1.0;
uniform float water_time = 0.0;
// The light's direction (toward it) in the tank's frame, for the glints and the shafts' lean.
uniform vec3 light_dir = vec3(0.25, 1.0, 0.15);
uniform vec3 room_tint : source_color = vec3(0.78, 0.84, 0.88);

float h21(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

vec2 h22(vec2 p) {
	float n = h21(p);
	return vec2(n, h21(p + n + 17.17));
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Distance to the nearest Voronoi cell edge (F2 - F1), the cells drifting: caustic lines are where
// the surface focuses light, and they look like a moving cell net.
float cell_edge(vec2 p, float t) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = h22(i + g);
			o = 0.5 + 0.42 * sin(t + 6.2831 * o);
			float d = length(g + o - f);
			if (d < d1) {
				d2 = d1;
				d1 = d;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return d2 - d1;
}

// Caustic light at a point in the water (x, y, z, W in the tank's frame).
float caustic(vec4 p) {
	float t = water_time;
	vec2 q = vec2(p.x, p.z) * 1.15 + vec2(p.w * 0.83, -p.w * 0.57);
	// Lower down, the pattern is wider and softer.
	float depth = half_ext.y - p.y;
	q *= 1.0 / (1.0 + depth * 0.06);
	q += 0.30 * vec2(sin(q.y * 1.3 + t * 0.7), sin(q.x * 1.1 - t * 0.6));
	float a = cell_edge(q, t * 0.9);
	float b = cell_edge(q * 1.7 + vec2(3.1, 1.7), t * 1.3 + 2.0);
	float c = pow(1.0 - smoothstep(0.0, 0.16, a), 3.0) + 0.6 * pow(1.0 - smoothstep(0.0, 0.11, b), 3.0);
	return c;
}

// The surface's ripples: small waves through x, z and W, and its slope in the slice's x and z.
vec2 ripple_slope(vec4 p) {
	float t = water_time;
	vec2 s = vec2(0.0);
	vec4 k[4] = vec4[4](vec4(2.1, 0.0, 1.3, 0.6), vec4(-1.4, 0.0, 2.6, -0.9), vec4(3.7, 0.0, -1.1, 1.4), vec4(-2.9, 0.0, -3.3, -0.5));
	float a[4] = float[4](0.010, 0.008, 0.005, 0.004);
	for (int i = 0; i < 4; i++) {
		vec4 kk = k[i];
		float w = sqrt(9.81 * length(kk)) * 0.35;
		float ph = dot(kk, p) - w * t;
		s += a[i] * cos(ph) * vec2(kk.x, kk.z);
	}
	s += 0.006 * vec2(vnoise(p.xz * 3.0 + vec2(t * 0.3, p.w)) - 0.5, vnoise(p.zx * 3.0 - vec2(t * 0.25, p.w)) - 0.5);
	return s * 6.0 * ripple_strength;
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	view.xyz /= view.w;
	float t_scene = length(view.xyz);
	vec3 dir = view.xyz / max(t_scene, 0.00001);
	mat4 to_tank = mat4(to_tank_x, to_tank_y, to_tank_z, to_tank_w);
	vec4 ro = cam_in_tank;
	vec4 rd = to_tank * vec4(dir, 0.0);

	// The ray against the 4D box, slab by slab.
	float t0 = -1e9;
	float t1 = 1e9;
	int axis_in = -1;
	int axis_out = -1;
	float sign_in = 0.0;
	float sign_out = 0.0;
	bool miss = false;
	for (int i = 0; i < 4; i++) {
		float r = rd[i];
		float o = ro[i];
		float h = half_ext[i];
		if (abs(r) < 1e-6) {
			if (abs(o) > h) {
				miss = true;
			}
			continue;
		}
		float ta = (-h - o) / r;
		float tb = (h - o) / r;
		float tn = min(ta, tb);
		float tf = max(ta, tb);
		if (tn > t0) {
			t0 = tn;
			axis_in = i;
			sign_in = -sign(r);
		}
		if (tf < t1) {
			t1 = tf;
			axis_out = i;
			sign_out = sign(r);
		}
	}
	float t_in = max(t0, 0.0);
	if (miss || t1 <= t_in || t_scene <= t_in) {
		discard;
	}
	vec3 scene = textureLod(screen_tex, SCREEN_UV, 0.0).rgb;
	bool through_top = axis_out == 1 && sign_out > 0.0 && t_scene > t1 + 0.002;
	bool from_top = axis_in == 1 && sign_in > 0.0;
	if (from_top) {
		// Looking down through the surface: the picture under it bent by the ripples, and a glint.
		vec4 ps = ro + rd * t_in;
		vec2 sl = ripple_slope(ps);
		scene = textureLod(screen_tex, SCREEN_UV + sl * 0.03, 0.0).rgb;
	}
	float t_out = min(t1, t_scene);
	float path = max(t_out - t_in, 0.0);
	vec3 col = scene;
	if (through_top) {
		// The surface from below. Past the critical angle (48.6 degrees from straight up) it is a
		// mirror: the water's own silver; inside it, the room above, bright.
		vec4 ps = ro + rd * t1;
		vec2 sl = ripple_slope(ps);
		vec3 n = normalize(vec3(-sl.x, 1.0, -sl.y));
		float up = dot(rd.xyz, n);
		float window = smoothstep(0.62, 0.70, up);
		// The mirror shows the water's own deep colour back, silvered by the ripples where they
		// catch the light; the window shows the hood's light, not whatever is behind the surface
		// from here (that read as dark blots, 9 Oct).
		vec3 lit = vec3(0.55, 0.68, 0.72) * (0.45 + 0.55 * clamp(dot(n, normalize(light_dir)), 0.0, 1.0));
		float glimmer = pow(clamp(1.0 - abs(sl.x + sl.y) * 5.0, 0.0, 1.0), 8.0);
		vec3 mirror = mix(scatter_color * 1.1, lit, 0.40) + vec3(0.20, 0.26, 0.28) * glimmer;
		vec3 above = room_tint * (0.85 + 0.6 * glimmer);
		col = mix(mirror, above, window * 0.8);
		path = t1 - t_in;
	}
	// Caustics where the ray ends on something in the water.
	if (!through_top && t_scene <= t1 + 0.002) {
		vec4 p = ro + rd * t_scene;
		float d = half_ext.y - p.y;
		col += scene * caustic(p) * caustic_strength * exp(-d * 0.22) * (0.6 + 0.4 * clamp(light_dir.y, 0.0, 1.0));
	}
	// The water between: absorbed, and the water's own colour scattered in.
	vec3 trans = exp(-absorption * path);
	col = col * trans + scatter_color * scatter_strength * (vec3(1.0) - exp(-path * vec3(0.30, 0.22, 0.20)));
	// Shafts of light hanging down from the surface, leaning with the light.
	float shafts = 0.0;
	for (int i = 0; i < 6; i++) {
		float tt = mix(t_in, t_out, (float(i) + 0.5) / 6.0);
		vec4 p = ro + rd * tt;
		float d = half_ext.y - p.y;
		vec2 lean = light_dir.xz / max(light_dir.y, 0.3);
		// Long in depth and drifting only sideways (round 3, Ramon: "a cut ... being animated and it's
		// going down the back wall ... make it larger, scale it in height"): the pattern's second axis
		// was the depth with a drift along it, and on the vertical back wall a cell's edge slid down.
		vec2 q = vec2(p.x + d * lean.x + p.w * 0.6, (p.z + d * lean.y) * 0.18);
		float s = vnoise(q * 1.3 + vec2(water_time * 0.04, 0.0));
		s = smoothstep(0.58, 0.92, s) * exp(-d * 0.20);
		shafts += s;
	}
	col += room_tint * vec3(0.55, 0.85, 0.90) * (shafts / 6.0) * shaft_strength * min(path, 4.0) * 0.35;
	// The front glass: a faint sheen at a grazing look, and a bright line where the water meets it.
	if (axis_in == 2 && sign_in > 0.0) {
		float graze = pow(1.0 - abs(rd.z), 4.0);
		col = mix(col, room_tint * 0.55, graze * 0.35);
		vec4 pin = ro + rd * t_in;
		float meniscus = 1.0 - smoothstep(0.0, 0.025, half_ext.y - pin.y);
		col += vec3(0.55, 0.70, 0.72) * meniscus * 0.8;
	}
	ALBEDO = col;
	ALPHA = 1.0;
}
