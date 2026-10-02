shader_type spatial;
render_mode skip_vertex_transform, cull_disabled, diffuse_lambert_wrap, specular_schlick_ggx;

// Grass for the pen: blades built and moved entirely here, from noise, every frame
// (pen_grass_4d.gd sets the uniforms; follow_up/grass_study.md is the why).
//
// HOW IT GETS INTO A 4D PICTURE. As the flock's starlings do (flock_bird.gdshader): this is a
// plain 3D MultiMesh in the Cross-section engine's own World3D, which draws in camera space,
// and the shader moves every vertex into the camera's frame itself with the view uniforms. The
// blades live in 4D - each has a w - and each is thin along W, so the slice cuts it: full size on
// its own slice, shrinking to nothing as it leaves (the section of a 4D body, sqrt(1-(w/r)^2)).
// Walk ana and the grass round you shrinks away while the next grass grows in.
//
// WHERE THE BLADES ARE. No positions are stored. Instance n is cell (i, j) of a square grid
// round the camera, snapped to the world so a blade never swims, and layer k along W: the
// layers sit round the w where the camera's slice crosses that spot of ground, so a turned
// slice still finds grass wherever it passes. A hash of the cell gives the jitter, the height,
// the facing and the w within the layer.
//
// WHAT A BLADE IS (Ghost of Tsushima's, GDC 2021): a cubic Bezier from the root to the tip,
// rebuilt every frame from four points - so bending it is moving the points. Widest at the
// root, a point at the tip, more vertices towards the tip where it bends. Its normals are
// turned out at the edges so a flat strip shades like a rounded blade, and seen edge-on it is
// thickened in view space so it never vanishes into a line.
//
// CLUMPS. A Voronoi of clump points over the ground (and along W, in bands): every blade knows
// its nearest clump, which sets its height, its colour - lush, ordinary or dry - and leans it
// towards the clump's middle. That is what makes a field look grown, not scattered.
//
// WIND, as wind in a field behaves (Ramon, 2 Oct: "a realistic wind algorithm ... more subtle"):
//   - a mean wind leans everything a little downwind;
//   - GUSTS travel downwind at about the wind's speed, in bands lying ACROSS the wind - the
//     waves that roll over a field of wheat (honami: the shear at the top of the canopy makes
//     coherent gusts that sweep the field). Anisotropic noise, stretched across the wind,
//     advected at 0.8 of the wind speed, with a slow swell in the gustiness;
//   - the bend follows the wind's PRESSURE, which goes as speed squared, and saturates at the
//     blade's stiffness (tanh): a little wind barely moves it, a gust lays it over, never flat;
//   - taller blades answer later: each samples the gusts a moment in the past, the lag growing
//     with its height, so a gust passes through the field rather than snapping it;
//   - each blade rocks about its bent pose at its own natural frequency (shorter ones faster),
//     harder in a gust, with a little turbulent flutter across the wind.
// People and animals walking through push the blades aside.
//
// THE RING. Two of these, a near ring of fine blades and a far ring of fewer, wider ones; each
// fades by shrinking and by turning the ground's colour at its edges, so there is no line.
// Not inside things: a mask texture gives, for each half metre of ground, up to two stretches
// of W where something stands on it (a floor, a pond, a hill), and no blade grows there.

uniform vec4 view_basis_x;
uniform vec4 view_basis_y;
uniform vec4 view_basis_z;
uniform vec4 view_basis_w;
uniform vec4 view_origin;
uniform vec4 camera_world;
uniform vec4 slice_normal = vec4(0.0, 0.0, 0.0, 1.0);

uniform float spacing = 0.11;
uniform int cells = 180;
uniform int layers = 3;
uniform float layer_spacing = 0.22;
uniform float w_radius = 0.3;
uniform float radius_in = 0.0;
uniform float radius_in_band = 2.0;
uniform float radius_out = 10.0;
uniform float radius_out_band = 2.5;
uniform float blade_height = 0.42;
uniform float blade_width = 0.032;
uniform float ground_extent = 59.0;
uniform float clump_size = 1.3;
// One blade in this many is a flower stem: a little coloured head on a thin stalk.
uniform float flower_share = 0.012;
uniform vec3 flower_a : source_color = vec3(0.92, 0.90, 0.80);
uniform vec3 flower_b : source_color = vec3(0.95, 0.78, 0.22);
uniform vec3 flower_c : source_color = vec3(0.62, 0.45, 0.78);

uniform sampler2D mask : filter_nearest, repeat_disable;
// x, z of the mask's corner, its cell size, its cells per side.
uniform vec4 mask_rect = vec4(-60.0, -60.0, 0.5, 240.0);

uniform sampler2D wind_noise : filter_linear, repeat_enable;
uniform vec2 wind_dir = vec2(0.82, 0.57);
// The mean wind, m/s, and how gusty it is (0 steady, 1 squally).
uniform float wind_speed = 3.0;
uniform float gustiness = 0.55;
// A gust band's length down the wind and across it, m.
uniform float gust_length = 7.0;
uniform float gust_width = 18.0;
// How far over the strongest gust can lay a blade (the tip's lean, 0..1 of its height).
uniform float bend_max = 0.5;
// The wind pressure, (m/s)^2, that lays a blade half way over.
uniform float stiffness = 30.0;
// The middle of the rings, in x and z: you. The player when the camera is following them, the
// camera itself when it is your eye (the hawk, the Lookout's camera). The slice and the frustum
// are still the camera's.
uniform vec2 ring_centre = vec2(0.0);
// tan of half the camera's horizontal view, with a margin: blades off the sides are dropped.
uniform float frustum_x = 1.6;

uniform vec4 pushers[16];
uniform int pusher_count = 0;

uniform vec3 colour_root : source_color = vec3(0.07, 0.10, 0.05);
uniform vec3 colour_base : source_color = vec3(0.20, 0.31, 0.12);
uniform vec3 colour_lush : source_color = vec3(0.14, 0.30, 0.13);
uniform vec3 colour_dry : source_color = vec3(0.47, 0.44, 0.22);
uniform vec3 colour_tip : source_color = vec3(0.46, 0.55, 0.24);
uniform vec3 ground_colour : source_color = vec3(0.16, 0.22, 0.11);
uniform float sheen = 0.32;

varying vec3 v_colour;
varying float v_t;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float hash13(vec3 p3) {
	p3 = fract(p3 * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}

// The nearest clump point: its offset from p (x, z) and its id.
vec3 clump(vec2 p, float band) {
	vec2 g = floor(p / clump_size);
	vec2 f = p / clump_size - g;
	float best = 1e9;
	vec3 out_value = vec3(0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 o = vec2(float(i), float(j));
			vec2 key = g + o + vec2(band * 17.31, band * 3.7);
			vec2 d = o + hash22(key) - f;
			float dd = dot(d, d);
			if (dd < best) {
				best = dd;
				out_value = vec3(d * clump_size, hash12(key + 5.3));
			}
		}
	}
	return out_value;
}

void vertex() {
	mat4 vb = mat4(view_basis_x, view_basis_y, view_basis_z, view_basis_w);
	int n = cells;
	int id = INSTANCE_ID;
	int ix = id % n;
	int iz = (id / n) % n;
	int k = id / (n * n);
	vec2 cam_cell = floor(ring_centre / spacing);
	vec2 cell = cam_cell + vec2(float(ix), float(iz)) - float(n / 2);
	vec2 root_xz = (cell + hash22(cell)) * spacing;
	// The w where the camera's slice crosses this spot of ground, and the layers round it.
	vec3 dp = vec3(root_xz.x - camera_world.x, -camera_world.y, root_xz.y - camera_world.z);
	float nw = slice_normal.w;
	float w_slice = abs(nw) > 0.25 ? camera_world.w - dot(slice_normal.xyz, dp) / nw : camera_world.w;
	float layer = floor(w_slice / layer_spacing) + float(k) - float(layers / 2);
	float root_w = (layer + hash13(vec3(cell, layer))) * layer_spacing;
	vec4 root = vec4(root_xz.x, 0.0, root_xz.y, root_w);

	float alive = 1.0;
	if (abs(root.x) > ground_extent || abs(root.z) > ground_extent || abs(root.w) > ground_extent) {
		alive = 0.0;
	}
	vec2 mc = (root_xz - mask_rect.xy) / mask_rect.z;
	if (mc.x >= 0.0 && mc.y >= 0.0 && mc.x < mask_rect.w && mc.y < mask_rect.w) {
		vec4 m = texelFetch(mask, ivec2(mc), 0);
		if ((root_w > m.r - 0.12 && root_w < m.g + 0.12) || (root_w > m.b - 0.12 && root_w < m.a + 0.12)) {
			alive = 0.0;
		}
	}
	// The ring's edges THIN the grass, blade by blade (Ghost of Tsushima drops three in four
	// before it hands over), and shrink and recolour what is left a little, so neither the near
	// ring's edge nor the far ring's is a line.
	float dist = length(root_xz - ring_centre);
	float ring = 1.0 - smoothstep(radius_out - radius_out_band, radius_out, dist);
	if (radius_in > 0.0) {
		ring *= smoothstep(radius_in, radius_in + radius_in_band, dist);
	}
	float keep = hash12(cell + vec2(7.7, 1.3));
	if (keep > ring * 1.15) {
		alive = 0.0;
	}
	ring = mix(0.55, 1.0, ring);
	// The cut: as much of the blade as the slice passes through.
	vec4 rel_root = vb * root + view_origin;
	float s2 = 1.0 - (rel_root.w / w_radius) * (rel_root.w / w_radius);
	float section = s2 > 0.0 ? sqrt(s2) : 0.0;
	float grow = ring * section * alive;
	// DEAD BLADES COST NOTHING MORE: out of the slice, thinned out, under a floor, behind the
	// camera or off the side of the view - all its vertices go to one point behind the camera,
	// before any of the clump, wind and curve work below.
	float ahead = -rel_root.z;
	bool dead = grow <= 0.0 || ahead < -0.8 || abs(rel_root.x) > ahead * frustum_x + 1.0;
	// (Godot does not allow a return in vertex(), so the rest is in an else.)
	if (dead) {
		VERTEX = vec3(0.0, 0.0, 1.0);
		NORMAL = vec3(0.0, 1.0, 0.0);
		v_colour = vec3(0.0);
		v_t = 0.0;
	} else {

		// The blade's own numbers, from its cell and its clump.
		vec3 cl = clump(root_xz, floor(root_w / 1.2));
		float clump_h = mix(0.82, 1.18, hash12(vec2(cl.z, 3.1)));
		float dry = smoothstep(0.62, 0.95, hash12(vec2(cl.z, 8.7)));
		float lush = 1.0 - smoothstep(0.0, 0.5, hash12(vec2(cl.z, 1.9)));
		float rnd = hash13(vec3(cell, layer + 4.2));
		float flower = step(hash13(vec3(cell, layer + 2.6)), flower_share);
		float h = blade_height * clump_h * mix(0.7, 1.25, rnd) * grow * (1.0 + flower * 0.5);
		float facing = hash13(vec3(cell, layer + 9.1)) * 6.2831853;
		vec2 lean = cl.xy * 0.06 + vec2(cos(facing), sin(facing)) * 0.08;

		// Wind (see the top): gust bands advected downwind, a pressure-driven bend, a lag by
		// height, a natural rock and a flutter.
		vec2 across_wind = vec2(-wind_dir.y, wind_dir.x);
		float lag = 0.12 + 0.35 * clamp(h / max(blade_height, 0.01), 0.0, 2.0);
		float tw = TIME - lag;
		float along = dot(root_xz, wind_dir) - wind_speed * 0.8 * tw;
		float side_pos = dot(root_xz, across_wind);
		vec2 guv = vec2(along / gust_length, side_pos / gust_width) * 0.18;
		float g1 = texture(wind_noise, guv).r;
		float g2 = texture(wind_noise, guv * 2.3 + vec2(0.31, 0.77) - vec2(0.05 * tw, 0.0)).r;
		float swell = 0.75 + 0.25 * sin(TIME * 0.21) * sin(TIME * 0.077 + 1.3);
		float gust = smoothstep(0.32, 0.8, g1 * 0.75 + g2 * 0.25) * swell;
		float speed = wind_speed * (1.0 - gustiness * 0.5 + gustiness * 1.6 * gust);
		float bend = bend_max * tanh(speed * speed / stiffness);
		// The rock about the bent pose, at the blade's own frequency: shorter ones faster.
		float freq = mix(2.2, 1.1, clamp(h / max(blade_height * 1.3, 0.01), 0.0, 1.0)) * mix(0.85, 1.15, rnd);
		float rock = sin(TIME * 6.2831853 * freq + rnd * 40.0) * (0.03 + 0.07 * gust) * bend_max;
		float flutter = (texture(wind_noise, root_xz * 0.9 + vec2(TIME * 0.6, TIME * 0.37)).r - 0.5) * 0.08 * (0.3 + gust);
		vec2 push = wind_dir * (bend + rock) + across_wind * flutter;
		// Whoever walks through pushes it aside.
		for (int i = 0; i < pusher_count; i++) {
			vec4 p = pushers[i];
			vec2 d = root_xz - p.xz;
			float dl = length(d);
			float near = (1.0 - smoothstep(0.1, 0.85, dl)) * (1.0 - smoothstep(0.25, 0.6, abs(root_w - p.w)));
			push += (d / max(dl, 0.01)) * near * 1.5;
		}
		vec2 hz = lean + push;
		float hl = length(hz);
		if (hl > 0.9) {
			hz *= 0.9 / hl;
		}

		// The Bezier: root at the origin, the tip where the lean and the wind put it.
		vec3 p3 = vec3(hz.x, sqrt(max(1.0 - dot(hz, hz), 0.1)), hz.y) * h;
		vec3 p1 = vec3(hz.x * 0.05, 0.4, hz.y * 0.05) * h;
		vec3 p2 = vec3(hz.x * 0.5, 0.0, hz.y * 0.5) * h + vec3(0.0, p3.y * 0.9, 0.0);
		float t = UV.y;
		float side = UV.x;
		float u = 1.0 - t;
		vec3 b = 3.0 * u * u * t * p1 + 3.0 * u * t * t * p2 + t * t * t * p3;
		vec3 tangent = 3.0 * u * u * p1 + 6.0 * u * t * (p2 - p1) + 3.0 * t * t * (p3 - p2);
		tangent = normalize(tangent + vec3(0.0, 1e-5, 0.0));
		vec3 across = vec3(-sin(facing), 0.0, cos(facing));
		float width = blade_width * grow * pow(u, 0.75) * mix(0.8, 1.25, rnd);
		if (flower > 0.5) {
			// A thin stalk, and a head: wide for the last fifth of it.
			width = blade_width * grow * (t > 0.86 ? 1.25 * sin((t - 0.86) / 0.14 * 3.14159) + 0.2 : 0.35);
		}
		vec3 pos = b + across * side * width;
		vec3 normal = normalize(cross(across, tangent));
		if (normal.y < 0.0) {
			normal = -normal;
		}
		normal = normalize(normal + across * side * 0.6);

		// Into the camera's frame, thickened when seen edge-on.
		vec4 rel = vb * (root + vec4(pos, 0.0)) + view_origin;
		vec3 n_view = normalize((vb * vec4(normal, 0.0)).xyz);
		vec3 a_view = (vb * vec4(across, 0.0)).xyz;
		float edge = 1.0 - abs(dot(n_view, normalize(-rel.xyz)));
		rel.xyz += a_view * side * width * edge * 1.4;
		VERTEX = rel.xyz;
		NORMAL = n_view;

		// Colour: dark at the root, the clump's green, a pale tip; the passing gust bright on the tips;
		// the ring's edge going over to the ground's colour.
		vec3 base = mix(colour_base, colour_lush, lush);
		base = mix(base, colour_dry, dry * 0.85);
		base *= mix(0.86, 1.12, rnd);
		vec3 tip = mix(colour_tip, colour_dry * 1.2, dry * 0.65);
		vec3 c = mix(colour_root, base, smoothstep(0.0, 0.45, t));
		c = mix(c, tip, smoothstep(0.55, 1.0, t));
		c += sheen * gust * t * t * vec3(0.5, 0.52, 0.3);
		if (flower > 0.5 && t > 0.86) {
			float pick = hash13(vec3(cell, layer + 6.6));
			c = pick < 0.5 ? flower_a : (pick < 0.8 ? flower_b : flower_c);
		}
		v_colour = mix(ground_colour, c, ring);
		v_t = t;
	}
}

void fragment() {
	ALBEDO = v_colour;
	ROUGHNESS = 0.72;
	SPECULAR = 0.22;
	BACKLIGHT = v_colour * 0.5 * v_t;
	AO = mix(0.5, 1.0, v_t);
	AO_LIGHT_AFFECT = 0.5;
}
