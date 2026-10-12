// The Arboretum's leaves: no tetrahedra at all. Ordinary 3D leaf cards drawn straight into the
// cross-section renderer's own World3D (the route the pen's grass takes, chickenpen/grass/), placed
// by this shader every frame from where each leaf is in 4D.
//
// A LEAF IN 4D is a thin flat 3D blade (the way a leaf in 3D is a thin flat 2D blade): a flat volume
// with a 4D normal `n`, a midrib direction `m` square to it, a centre and a size. Our 3D slice cuts
// that flat volume in a plane, so what you see of a leaf is a flat 2D leaf shape, standing in the
// plane square to the part of `n` that lies in your slice, its midrib along the part of `m` that
// does. It is full size when the slice passes through its middle and shrinks to nothing as the slice
// leaves it (`leaf_w` either side), so walking or turning through W the crown changes leaf by leaf.
//
// ONE INSTANCE A LEAF (a MultiMesh of the leaf shape); everything else comes from three float
// textures, a row of 1024 leaves each: centre (x, y, z, w), normal, and (midrib x, y, z, w) with the
// branch, how far along it, a seed and the leaf's birth (for growing in) packed in a fourth.
//
// WIND: each leaf's centre goes through the same branch-by-branch swing as the bark
// (botany_bark.gdshader wind_offset, copied: keep the two the same), so leaves stay on their twigs,
// and then flutters about its midrib on its own.
//
// THE CROWN'S LIGHT: a card's own normal flips as it turns, so a crown of them shades as noise; the
// normals are blended toward the direction from the crown's middle (`crown_centre`), so the crown
// shades as one soft mass and each leaf only a little on its own.

shader_type spatial;
render_mode skip_vertex_transform, cull_disabled, diffuse_lambert_wrap, specular_schlick_ggx;

uniform sampler2D leaf_pos : filter_nearest, repeat_disable;
uniform sampler2D leaf_nrm : filter_nearest, repeat_disable;
uniform sampler2D leaf_mid : filter_nearest, repeat_disable;
uniform sampler2D leaf_info : filter_nearest, repeat_disable;
uniform int leaf_count = 0;

// The tree's frame in the camera's: basis columns and origin (leaf_field_4d.gd, every render).
uniform vec4 frame_x = vec4(1.0, 0.0, 0.0, 0.0);
uniform vec4 frame_y = vec4(0.0, 1.0, 0.0, 0.0);
uniform vec4 frame_z = vec4(0.0, 0.0, 1.0, 0.0);
uniform vec4 frame_w = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 frame_o = vec4(0.0);
// How a leaf scales with the tree's node scale (frames carry it, sizes do not).
uniform float frame_scale = 1.0;

uniform float leaf_size = 1.0;
// How deep in W a leaf is, either side of its middle, metres.
uniform float leaf_w = 0.12;
uniform vec4 crown_centre = vec4(0.0, 4.0, 0.0, 0.0);
uniform float crown_normals = 0.65;
uniform float tree_height = 7.0;
// Growth (0: none yet, 1: every leaf) and the season (0 summer, 1 autumn, 2 bare).
uniform float grow = 1.0;
uniform float season = 0.0;

uniform vec4 leaf_color : source_color = vec4(0.314, 0.490, 0.165, 1.0);
uniform vec4 leaf_alt : source_color = vec4(0.416, 0.561, 0.184, 1.0);
uniform vec4 leaf_dark : source_color = vec4(0.17, 0.30, 0.10, 1.0);
uniform vec4 autumn_a : source_color = vec4(0.78, 0.48, 0.12, 1.0);
uniform vec4 autumn_b : source_color = vec4(0.62, 0.24, 0.08, 1.0);

// The wind (wind_4d.gd hands every tree the same; see botany_bark.gdshader).
uniform sampler2D pivot_tex : filter_nearest, repeat_disable;
uniform int pivot_count = 0;
uniform vec4 wind = vec4(0.0);
uniform float wind_time = 0.0;
uniform float bend = 0.05;
uniform float sway = 0.35;
uniform float gust_front = -1000.0;
uniform float gust_width = 3.0;
uniform float gust_strength = 0.0;
uniform float wind_on = 1.0;
// The flutter: radians, and how fast.
uniform float flutter = 0.35;
uniform float flutter_rate = 2.3;

varying vec3 v_colour;
varying vec2 v_leaf_uv;
varying float v_vein;

float smooth_wave(float x) {
	float t = abs(fract(x + 0.5) * 2.0 - 1.0);
	return t * t * (3.0 - 2.0 * t) * 2.0 - 1.0;
}

vec4 swing(vec4 p, vec4 c, vec4 u, vec4 v, float angle) {
	vec4 d = p - c;
	float du = dot(d, u);
	float dv = dot(d, v);
	float ca = cos(angle);
	float sa = sin(angle);
	return p + u * (du * ca - dv * sa - du) + v * (du * sa + dv * ca - dv);
}

// KEEP IN STEP with botany_bark.gdshader wind_offset.
vec4 wind_offset(vec4 p, int branch, float along) {
	if (wind_on <= 0.0 || pivot_count <= 0 || branch < 0 || branch >= pivot_count) {
		return p;
	}
	float speed = length(wind);
	vec4 wdir = speed > 0.0001 ? wind / speed : vec4(1.0, 0.0, 0.0, 0.0);
	int r = branch;
	float t = along;
	for (int k = 0; k < 10; k++) {
		if (r < 0 || r >= pivot_count) {
			break;
		}
		vec4 piv = texelFetch(pivot_tex, ivec2(0, r), 0);
		vec4 dir = texelFetch(pivot_tex, ivec2(1, r), 0);
		vec4 info = texelFetch(pivot_tex, ivec2(2, r), 0);
		vec4 more = texelFetch(pivot_tex, ivec2(3, r), 0);
		vec4 wv = wdir - dir * dot(wdir, dir);
		float wl = length(wv);
		if (wl > 0.0001) {
			vec4 v = wv / wl;
			float pressure = tanh(speed * speed * 0.02) * wl;
			float g = gust_strength * exp(-pow((dot(piv, wdir) - gust_front) / max(gust_width, 0.01), 2.0));
			float osc = 0.6 * smooth_wave(wind_time * info.w + info.z) + 0.4 * smooth_wave(wind_time * info.w * 2.31 + info.z * 1.7);
			float a = info.y * bend * (pressure * (1.0 + sway * osc) + g);
			a *= 0.25 + 0.75 * clamp(t, 0.0, 1.0);
			p = swing(p, piv, dir, v, a);
		}
		t = more.y;
		r = int(info.x + 0.5) - 1;
	}
	return p;
}

ivec2 texel(int i) {
	return ivec2(i % 1024, i / 1024);
}

float hash11(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void vertex() {
	int i = INSTANCE_ID;
	vec4 c = texelFetch(leaf_pos, texel(i), 0);
	vec4 n = texelFetch(leaf_nrm, texel(i), 0);
	vec4 m = texelFetch(leaf_mid, texel(i), 0);
	vec4 info = texelFetch(leaf_info, texel(i), 0); // branch, along, seed, birth
	float seed = info.z;
	// Growing in, and falling in the bare season.
	float shown = clamp((grow - info.w) * 8.0, 0.0, 1.0);
	shown *= 1.0 - clamp((season - 1.0 - seed * 0.8) * 5.0, 0.0, 1.0);
	// The wind: the centre goes with its branch; the leaf turns about its midrib, a flutter of its own.
	vec4 moved = wind_offset(c, int(info.x + 0.5), info.y);
	float speed = length(wind) * wind_on;
	float fl = flutter * clamp(speed / 8.0, 0.0, 1.5) * smooth_wave(wind_time * flutter_rate * (0.8 + seed * 0.6) + seed * 31.0);
	vec4 side4 = vec4(0.0);
	// A direction square to both n and m: rotate n toward it by the flutter.
	vec4 k = vec4(m.y * n.z - m.z * n.y, m.z * n.x - m.x * n.z, m.x * n.y - m.y * n.x, 0.0);
	if (length(k) > 0.001) {
		side4 = normalize(k);
		n = normalize(n * cos(fl) + side4 * sin(fl));
	}
	// Into the camera's frame.
	vec4 cc = frame_x * moved.x + frame_y * moved.y + frame_z * moved.z + frame_w * moved.w + frame_o;
	vec4 nc = frame_x * n.x + frame_y * n.y + frame_z * n.z + frame_w * n.w;
	vec4 mc = frame_x * m.x + frame_y * m.y + frame_z * m.z + frame_w * m.w;
	// The slice is the camera's w = 0: how far this leaf's middle is from it.
	float w_half = leaf_w * frame_scale;
	float dw = abs(cc.w) / max(w_half, 0.0001);
	float cut = dw < 1.0 ? sqrt(1.0 - dw * dw) : 0.0;
	vec3 n3 = nc.xyz;
	float nl = length(n3);
	float size = cut * shown * leaf_size * (0.75 + 0.5 * hash11(seed * 7.0)) * frame_scale;
	// (No `return` in vertex(): Godot rejects it. A leaf not shown is folded to a point outside the
	// view instead.)
	vec2 shape = VERTEX.xy;
	v_vein = UV.x;
	if (size <= 0.0001 || nl < 0.05) {
		VERTEX = vec3(0.0, 0.0, 1.0e6);
		POSITION = vec4(0.0, 0.0, 2.0, 1.0);
		v_colour = vec3(0.0);
		v_leaf_uv = vec2(0.0);
	} else {
	n3 /= nl;
	vec3 mid = mc.xyz - n3 * dot(mc.xyz, n3);
	mid = length(mid) > 0.0001 ? normalize(mid) : normalize(cross(n3, vec3(0.0, 0.0, 1.0)) + vec3(0.0001));
	vec3 across = cross(n3, mid);
	vec3 p = cc.xyz + (across * shape.x + mid * shape.y) * size;
	VERTEX = p;
	POSITION = PROJECTION_MATRIX * vec4(p, 1.0);
	// The crown's light.
	vec4 crown = (frame_x * (c.x - crown_centre.x) + frame_y * (c.y - crown_centre.y) + frame_z * (c.z - crown_centre.z) + frame_w * (c.w - crown_centre.w));
	vec3 out_dir = length(crown.xyz) > 0.0001 ? normalize(crown.xyz) : n3;
	NORMAL = normalize(mix(n3, out_dir, crown_normals));
	// Colour: sap green with its two neighbours by leaf, darker inside the crown and low, lighter
	// at the top and the outside; the season turns it.
	float h = hash11(seed * 3.1);
	vec3 col = mix(leaf_color.rgb, leaf_alt.rgb, step(0.62, h));
	col *= 0.86 + 0.28 * hash11(seed * 9.7);
	float outside = clamp(length((c - crown_centre).xyz) / max(tree_height * 0.45, 0.1), 0.0, 1.0);
	float up = clamp(c.y / max(tree_height, 0.1), 0.0, 1.0);
	col = mix(leaf_dark.rgb, col, 0.45 + 0.55 * clamp(outside * 0.7 + up * 0.5, 0.0, 1.0));
	float autumn = clamp(season - seed * 0.35, 0.0, 1.0);
	col = mix(col, mix(autumn_a.rgb, autumn_b.rgb, hash11(seed * 5.3)), autumn);
	v_colour = col;
	v_leaf_uv = shape;
	}
}

void fragment() {
	// A lighter midrib, and the leaf's own two sides.
	float vein = 1.0 - smoothstep(0.0, 0.07, abs(v_vein));
	ALBEDO = mix(v_colour, v_colour * 1.35 + vec3(0.03), vein * 0.35);
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	BACKLIGHT = v_colour * 0.45;
	ROUGHNESS = 0.7;
	SPECULAR = 0.25;
}
