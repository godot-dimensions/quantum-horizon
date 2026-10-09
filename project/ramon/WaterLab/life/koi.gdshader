shader_type spatial;
render_mode skip_vertex_transform, cull_disabled;

// WATER LAB: one koi of the tank, drawn the starlings' way (shared/slice_draw.gdshaderinc) and bent
// by a travelling wave here, on the GPU, every frame. The shape is life/koi_mesh.gd's, one body
// length long; life/koi_school_4d.gd swims them and writes each one's row.
//
// THE SWIM (Wu et al. 2007, routine turning in koi; Lighthill's carangiform model). The spine's
// sideways offset at s (0 snout, 1 tail tip) is
//     lat(s) = A(s) sin(2 pi s / wavelength - phase) + C (s - 0.3)^2
//     A(s)   = amp / 0.1 * (0.02 - 0.08 s + 0.16 s^2)          (koi, measured: 0.02 L at the head,
//                                                             least just behind it, 0.10 L at the tail)
// The first term is the wave that runs down the body a tail beat at a time (the phase is advanced
// by the school at the beat's own frequency, so a change of pace never jumps); the second bends the
// whole fish into a C about a point a third of the way back, which is how a koi turns. Every vertex
// is then placed by the bent spine's FRAME at its s, turned with it, not shoved sideways: a sheared
// fish looks like a flag, a bent one like a fish.
//
// FINS that hang from a point (the pectorals, the pelvics, the barbels, the eyes) are moved as a whole
// with the body at their root (CUSTOM0.x) and turned there first: the pectorals scull while a koi
// hovers and swing out square to the body to brake. Fins that run along the body (the dorsal, the
// anal, the tail) bend with it and flutter at their edges, more for long-finned (butterfly) koi.
//
// INSTANCE DATA (the school writes it):
//   custom  x  the wave's phase (radians)      y  the tail's amplitude (body lengths)
//           z  the koi's length (m)             w  the turn's bend, C (+ bends right)
//   colour  r  (the variety (0-7) + 8 for long fins) / 16
//           g  a seed (0-1), its own pattern    b  pectoral spread (0 tucked, 1 braking)
//           a  the mouth (0 shut, 1 a gulp)

#include "res://ramon/WaterLab/shared/slice_draw.gdshaderinc"

uniform float w_radius = 0.22;
uniform float snout_z = 0.45;
uniform float wavelength = 1.0;
uniform vec3 pectoral_root = vec3(0.205, -0.062, 0.060);
uniform vec3 pelvic_root = vec3(0.455, -0.082, 0.032);
uniform float fin_flutter = 1.0;
// 1 for the showcase's big koi (room/koi_showcase_4d.gd): the gill cover's edge, the lateral line's
// pores, the nostrils, a wet eye and crisper fin rays, which the tank's koi are too small to show.
uniform float detail = 0.0;

varying vec3 rest;
varying float v_s;
varying float v_part;
varying vec2 v_fin;
varying vec4 v_kind;
varying float v_section;

float koi_mid(float s) {
	return -0.012 * (1.0 - smoothstep(0.0, 0.12, s));
}

float amp_shape(float s) {
	return 0.02 - 0.08 * s + 0.16 * s * s;
}

// The spine's offset and its slope (d lat / d s) at s.
vec2 spine(float s, float phase, float amp, float bend) {
	float k = 6.2831853 / wavelength;
	float th = k * s - phase;
	float a = amp * 10.0 * amp_shape(s);
	float da = amp * 10.0 * (-0.08 + 0.32 * s);
	float lat = a * sin(th) + bend * (s - 0.3) * (s - 0.3);
	float d = da * sin(th) + a * cos(th) * k + 2.0 * bend * (s - 0.3);
	return vec2(lat, d);
}

// Turns v about the axis through `root` along `axis` by `angle`.
vec3 turn_about(vec3 v, vec3 root, vec3 axis, float angle) {
	vec3 p = v - root;
	float c = cos(angle);
	float s = sin(angle);
	return root + p * c + cross(axis, p) * s + axis * dot(axis, p) * (1.0 - c);
}

void vertex() {
	SliceFrame o = slice_frame(MODEL_MATRIX);
	float phase = INSTANCE_CUSTOM.x;
	float amp = INSTANCE_CUSTOM.y;
	float size = INSTANCE_CUSTOM.z;
	float bend = INSTANCE_CUSTOM.w;
	// The instance colour (a multimesh's is multiplied into COLOR, the mesh's own being white).
	vec4 kind = COLOR;
	v_kind = kind;
	float long_fins = kind.r >= 0.5 ? 1.0 : 0.0;
	float seed = kind.g;
	float spread = kind.b;
	float gulp = kind.a;

	int part = int(UV.y + 0.5);
	float s = UV.x;
	bool rigid = CUSTOM0.y > 0.5;
	float sa = rigid ? CUSTOM0.x : s;
	vec3 v = VERTEX;
	vec3 n = NORMAL;
	rest = VERTEX;
	v_s = s;
	v_part = UV.y;
	v_fin = UV2;
	float t = TIME + seed * 37.0;
	float side = UV2.y;

	if (part == 0 && s < 0.05) {
		// The mouth: the lips push forward and open on a gulp.
		float m = (1.0 - s / 0.05) * gulp;
		float mid = koi_mid(s);
		v.xy = vec2(v.x, mid) + (v.xy - vec2(0.0, mid)) * (1.0 + 0.35 * m);
		v.z += 0.012 * m;
	}
	if (part == 3) {
		// Pectoral: swung out about its root (square to the body to brake), and sculling up and
		// down about the body's length, the two fins out of step while hovering.
		vec3 root = vec3(side * pectoral_root.z, pectoral_root.y, snout_z - pectoral_root.x);
		float fin_len = 1.0 + 0.6 * long_fins;
		v = root + (v - root) * fin_len;
		float swing = side * (0.15 + 0.85 * spread);
		v = turn_about(v, root, vec3(0.0, 1.0, 0.0), swing);
		n = turn_about(n, vec3(0.0), vec3(0.0, 1.0, 0.0), swing);
		float scull = (0.10 + 0.32 * spread) * sin(t * (4.2 + 2.0 * spread) + side * 1.4) - 0.12 * spread;
		v = turn_about(v, root, vec3(0.0, 0.0, 1.0), side * scull);
		n = turn_about(n, vec3(0.0), vec3(0.0, 0.0, 1.0), side * scull);
		// The fin's web bends: the trailing edge lags.
		v.y += 0.010 * UV2.x * UV2.x * sin(t * 4.6 + side) * (0.4 + spread);
	} else if (part == 4) {
		vec3 root = vec3(side * pelvic_root.z, pelvic_root.y, snout_z - pelvic_root.x);
		float paddle = 0.10 * sin(t * 2.3 + side * 2.0);
		v = turn_about(v, root, vec3(0.0, 0.0, 1.0), side * paddle);
	} else if (part == 7) {
		vec3 root = vec3(side * 0.018, -0.022, snout_z - 0.012);
		v = turn_about(v, root, vec3(1.0, 0.0, 0.0), 0.35 * UV2.x * sin(t * 2.6 + side * 1.7));
	} else if (part == 1) {
		// The tail: its rays trail the body's wave, and long tails stream further.
		float root_s = CUSTOM0.x;
		float fin_len = 1.0 + 0.85 * long_fins;
		float along = (s - root_s) * fin_len;
		s = root_s + along;
		v.z = snout_z - s;
		v.y = koi_mid(root_s) + v.y * (1.0 + 0.35 * long_fins);
		sa = s;
	} else if (part == 2 || part == 5) {
		// Taller on long-finned koi.
		float up = part == 2 ? 1.0 : -1.0;
		float fin_len = 1.0 + 0.7 * long_fins;
		float tall = (v.y - koi_mid(s)) * up;
		v.y = koi_mid(s) + up * mix(tall, tall * fin_len, UV2.x);
	}

	vec2 sp = spine(sa, phase, amp, bend);
	// The edges of the fins that run along the body flutter and lag the wave.
	if (part == 1) {
		float u = UV2.x;
		sp.x += amp * 0.35 * u * sin(6.2831853 * sa / wavelength - phase - 1.3);
		sp.x += 0.004 * fin_flutter * (1.0 + 3.0 * long_fins) * u * u * sin(t * 7.0 + UV2.y * 9.0);
	} else if (part == 2 || part == 5) {
		float u = UV2.x;
		sp.x += 0.005 * fin_flutter * (1.0 + 2.5 * long_fins) * u * u * sin(t * 5.5 + s * 26.0 + seed * 6.0);
	}
	float inv = inversesqrt(1.0 + sp.y * sp.y);
	float cb = inv;
	float sb = sp.y * inv;
	float za = snout_z - sa;
	vec3 off = vec3(v.x, v.y, rigid ? v.z - za : 0.0);
	vec3 bent = vec3(sp.x + off.x * cb - off.z * sb, off.y, za + off.x * sb + off.z * cb);
	vec3 nb = vec3(n.x * cb - n.z * sb, n.y, n.x * sb + n.z * cb);

	float section = slice_section(o.rel.w, w_radius * size);
	v_section = section;
	bent *= size * section;
	VERTEX = slice_place(o, bent);
	NORMAL = slice_turn(o, nb);
}

// --- the patterns ---------------------------------------------------------------------------------

// Scales: rows of overlapping round scales, each one's rear edge an arc (1 on the edge line, 0
// inside), faded out where a scale is smaller than a pixel or two (moire otherwise).
float scale_edge_at(float s, float a) {
	vec2 g = vec2(s * 58.0, a * 9.0);
	g.y += 0.5 * mod(floor(g.x), 2.0);
	vec2 f = fract(g);
	// The scale's centre sits at its cell's front; its edge is the circle through the cell's back.
	float d = length(vec2(f.x, (f.y - 0.5) * 0.9));
	float edge = smoothstep(0.80, 0.95, d) * (1.0 - smoothstep(0.95, 1.05, d));
	float px = length(fwidth(g));
	return edge * (1.0 - smoothstep(0.25, 0.6, px));
}

// Blotches for the patterns: value noise, its domain warped so the shapes are organic, not grid
// squares (the first frames' patches read as decals).
float blotch(vec2 p) {
	vec2 q = vec2(sd_fbm(p * 0.8 + vec2(3.1, 7.7)), sd_fbm(p * 0.8 + vec2(11.3, 1.9)));
	return sd_fbm(p + (q - 0.5) * 1.6);
}

void fragment() {
	// The variety, 0-7, and the long-fin flag (8 more in the stored sixteenths).
	float variety = floor(mod(v_kind.r * 16.0 + 0.01, 8.0));
	float long_fins = v_kind.r >= 0.5 ? 1.0 : 0.0;
	float seed = v_kind.g;
	int part = int(v_part + 0.5);
	float s = v_s;
	float mid = koi_mid(s);
	float a = atan(rest.y - mid, rest.x);
	float dorsal = sin(a);
	float across = cos(a);

	vec3 white = vec3(0.93, 0.92, 0.88);
	vec3 cream = vec3(0.95, 0.90, 0.80);
	vec3 hi = vec3(0.78, 0.11, 0.04);
	vec3 sumi = vec3(0.035, 0.035, 0.04);
	vec3 col = white;
	float metallic = 0.0;
	float rough = 0.34;

	// Patterns are laid out as a koi is judged, from above: across the back (cos a) and along it,
	// fading down the flanks to about the lateral line.
	vec2 P = vec2(s * 4.2 + seed * 31.0, across * 1.1 + seed * 17.0);
	float n1 = blotch(P) + 0.12 * (1.0 - smoothstep(0.10, 0.24, s));
	float back = smoothstep(-0.35, 0.15, dorsal);
	float red = smoothstep(0.46, 0.49, n1) * back * smoothstep(0.012, 0.03, s) * (1.0 - smoothstep(0.74, 0.79, s) * 0.7);
	float scale_edge = scale_edge_at(s, a);
	float scaled = (part == 0 && s > 0.19 && s < 0.79) ? 1.0 : 0.0;

	if (variety < 0.5) {
		// KOHAKU: white with red.
		col = mix(white, hi, red);
	} else if (variety < 1.5) {
		// TAISHO SANKE: Kohaku with small black patches on the back, none on the head.
		col = mix(white, hi, red);
		float n2 = blotch(P * 2.2 + 40.0);
		float black = smoothstep(0.60, 0.62, n2) * smoothstep(0.0, 0.35, dorsal) * step(0.22, s);
		col = mix(col, sumi, black);
	} else if (variety < 2.5) {
		// SHOWA: black over white and red, black reaching the head.
		float wmask = smoothstep(0.56, 0.59, blotch(P * 0.9 + 70.0)) + smoothstep(-0.2, -0.7, dorsal);
		col = mix(sumi, white, clamp(wmask, 0.0, 1.0));
		col = mix(col, hi, smoothstep(0.53, 0.56, n1) * back);
	} else if (variety < 3.5) {
		// TANCHO: white, one red disc on the head.
		float d = length(vec2((s - 0.085) * 15.0, across * 1.3));
		col = mix(white, hi, smoothstep(0.62, 0.56, d) * step(0.0, dorsal));
	} else if (variety < 4.5) {
		// OGON: metallic gold all over.
		col = vec3(1.0, 0.76, 0.28) * (0.92 + 0.08 * dorsal);
		metallic = 0.5;
		rough = 0.3;
	} else if (variety < 5.5) {
		// PLATINUM OGON.
		col = vec3(0.92, 0.93, 0.95);
		metallic = 0.5;
		rough = 0.28;
	} else if (variety < 6.5) {
		// ASAGI: a blue-grey net on the back, orange-red below and on the cheeks.
		vec3 blue = vec3(0.32, 0.43, 0.54);
		col = mix(blue * 0.85, vec3(0.70, 0.80, 0.88), scale_edge * scaled);
		float low = smoothstep(0.05, -0.40, dorsal) + (1.0 - smoothstep(0.12, 0.2, s)) * smoothstep(0.1, -0.3, dorsal);
		col = mix(col, vec3(0.86, 0.36, 0.12), clamp(low, 0.0, 1.0));
		scaled = 0.0;
	} else {
		// CHAGOI: bronze, every scale outlined.
		col = mix(vec3(0.52, 0.36, 0.20), vec3(0.72, 0.55, 0.33), scale_edge * scaled);
		metallic = 0.25;
		scaled = 0.0;
	}
	// The scales: a fine darker line at each scale's edge.
	col *= 1.0 - 0.06 * scale_edge * scaled;
	// The belly is paler on every koi but the metallic ones.
	if (variety < 3.5 || variety > 5.5) {
		col = mix(col, cream, smoothstep(-0.55, -0.9, dorsal) * 0.6);
	}

	if (part >= 1 && part <= 5) {
		// FINS: paler than the body, the rays as faint lines; long fins fade toward their edge.
		// Each variety's fins in its own colour, never the body's patches across them.
		float ray = 0.5 + 0.5 * sin(v_fin.y * (part == 1 ? 90.0 : 60.0));
		vec3 fin = white;
		if (variety > 1.5 && variety < 2.5) {
			// Showa: black at the pectorals' root, black rays elsewhere.
			fin = part == 3 ? mix(sumi, white, smoothstep(0.25, 0.45, v_fin.x)) : mix(white, sumi, step(0.8, ray) * 0.5);
		} else if (variety > 0.5 && variety < 1.5) {
			fin = mix(white, sumi, step(0.86, ray) * 0.6 * step(0.3, v_fin.x));
		} else if (variety > 3.5 && variety < 5.5) {
			fin = col;
		} else if (variety > 5.5 && variety < 6.5) {
			fin = mix(vec3(0.86, 0.40, 0.16), white, smoothstep(0.2, 0.8, v_fin.x));
		} else if (variety > 6.5) {
			fin = vec3(0.62, 0.46, 0.28);
		}
		fin *= 0.93 + 0.07 * ray;
		fin = mix(fin, white * 0.97, 0.25 * long_fins * v_fin.x);
		col = fin;
		rough = 0.45;
	}
	if (part == 6) {
		// The eye: a black pupil in a gold ring.
		float k = v_fin.x;
		col = mix(vec3(0.05, 0.05, 0.05), vec3(0.75, 0.55, 0.18), smoothstep(0.35, 0.5, k));
		col = mix(col, vec3(0.005), smoothstep(0.70, 0.78, k));
		metallic = 0.0;
		rough = 0.08;
	}
	if (part == 7) {
		col = mix(col, vec3(0.88, 0.70, 0.62), 0.5);
	}
	if (detail > 0.5 && part == 0) {
		// The gill cover's rear edge, a soft curve behind the eye.
		float gill = abs(s - (0.205 - 0.03 * dorsal * dorsal));
		col *= 1.0 - 0.22 * (1.0 - smoothstep(0.0015, 0.0045, gill)) * step(abs(dorsal), 0.75);
		// The lateral line: a row of pores along the flank, a little below the middle.
		float lat_d = abs(dorsal + 0.08);
		float pore = step(fract(s * 140.0), 0.38) * (1.0 - smoothstep(0.02, 0.045, lat_d)) * step(0.21, s) * step(s, 0.77);
		col = mix(col, col * (variety > 3.5 && variety < 5.5 ? 1.18 : 0.78), pore * 0.6);
		// The nostrils.
		vec2 nose = vec2((s - 0.032) * 18.0, (abs(across) - 0.55) * 3.0);
		col *= 1.0 - 0.7 * (1.0 - smoothstep(0.3, 0.55, length(nose))) * step(0.2, dorsal);
	}
	if (part == 0 && s < 0.014) {
		// The lips, and the mouth's dark inside on a gulp.
		col = mix(col, vec3(0.85, 0.66, 0.60), 0.5);
		col = mix(col, vec3(0.03, 0.02, 0.02), smoothstep(0.2, 0.8, v_kind.a) * (1.0 - smoothstep(0.0, 0.008, s)));
	}

	if (part == 6 && detail > 0.5) {
		rough = 0.03;
	}
	ALBEDO = col;
	METALLIC = metallic;
	ROUGHNESS = rough;
	SPECULAR = 0.55;
	// Wet skin: a clear coat over the colour.
	CLEARCOAT = part == 0 ? 0.65 : (part == 6 ? 1.0 : 0.3);
	CLEARCOAT_ROUGHNESS = 0.22;
	RIM = 0.25;
	RIM_TINT = 0.6;
}
