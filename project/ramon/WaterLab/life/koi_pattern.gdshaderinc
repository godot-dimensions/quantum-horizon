// WATER LAB: the koi's colours, worked out from where a point is on its 4D body. Shared by the lofted
// koi's skin (life/koi_skin_4d.gdshader, cut by the 4D renderer) and the fish wall's picture of one
// (room/fish_wall_4d.gd, its cut at w = 0 drawn in a 3D studio), so both paint the same fish.
//
// WHERE A POINT IS: `s` along the fish (0 the snout, 0.8 where the tail fin starts), and `dir`, which
// way the skin faces from the spine there, as a unit vector (x: across, y: up, z: through W). The
// body's sections are ellipsoids, round in x and W (life/koi_loft_4d.gd), so `dir` is the point's
// offset from the section's centre divided by the section's half axes, normalised.
//
// THE PATTERNS are the old 3D shader's (life/koi.gdshader), laid out as a koi is judged, from above,
// but over a 4D back: "across the back" is now a disc (x and W), not a line, and the blotches are 3D
// noise over it. Turn the slice and the cut runs across different patches of the same koi.

// The profile, sampled every 0.025 of the length from s = 0 to 0.8: the section's centre height, its
// half height, its half width, its half depth through W (body lengths). Set from koi_loft_4d.gd.
uniform vec4 koi_profile[33];

vec4 koi_section(float s) {
	float f = clamp(s, 0.0, 0.8) / 0.025;
	int i = int(min(floor(f), 31.0));
	return mix(koi_profile[i], koi_profile[i + 1], f - float(i));
}

// Which way the skin faces at a point of the rest pose (x across, y up, w through W; unit length).
vec3 koi_dir(float s, vec3 xyw) {
	vec4 sec = koi_section(s);
	vec3 rel = vec3(xyw.x / max(sec.z, 0.001), (xyw.y - sec.x) / max(sec.y, 0.001), xyw.z / max(sec.w, 0.001));
	float l = length(rel);
	return l > 0.0001 ? rel / l : vec3(0.0, 1.0, 0.0);
}

float kp_hash(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float kp_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(kp_hash(i), kp_hash(i + vec3(1.0, 0.0, 0.0)), f.x);
	float b = mix(kp_hash(i + vec3(0.0, 1.0, 0.0)), kp_hash(i + vec3(1.0, 1.0, 0.0)), f.x);
	float c = mix(kp_hash(i + vec3(0.0, 0.0, 1.0)), kp_hash(i + vec3(1.0, 0.0, 1.0)), f.x);
	float d = mix(kp_hash(i + vec3(0.0, 1.0, 1.0)), kp_hash(i + vec3(1.0, 1.0, 1.0)), f.x);
	return mix(mix(a, b, f.y), mix(c, d, f.y), f.z);
}

float kp_fbm(vec3 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		s += a * kp_noise(p);
		p = p * 2.03 + vec3(17.1, 9.7, 4.3);
		a *= 0.5;
	}
	return s;
}

// Blotches: value noise with its domain warped, so the shapes are organic, not grid squares.
float kp_blotch(vec3 p) {
	vec3 q = vec3(kp_fbm(p * 0.8 + vec3(3.1, 7.7, 1.3)), kp_fbm(p * 0.8 + vec3(11.3, 1.9, 5.2)), kp_fbm(p * 0.8 + vec3(2.7, 13.1, 8.8)));
	return kp_fbm(p + (q - 0.5) * 1.6);
}

// Scales: rows of round scales whose rear edges are arcs, in a lattice along the body, round it in
// x-y and across W. 56 cells round the x-y circle, a whole number, so the rows meet where the angle
// wraps on the far flank. Faded out where a scale is smaller than a pixel or two (moire otherwise).
float kp_scale_edge(float s, vec3 dir) {
	float a = atan(dir.y, dir.x);
	vec3 g = vec3(s * 58.0, a * 8.9127, dir.z * 9.0);
	g.y += 0.5 * mod(floor(g.x), 2.0);
	vec3 f = fract(g);
	float d = length(vec3(f.x, (f.y - 0.5) * 0.9, (f.z - 0.5) * 0.9));
	float edge = smoothstep(0.80, 0.95, d) * (1.0 - smoothstep(0.95, 1.05, d));
	float px = length(fwidth(g));
	return edge * (1.0 - smoothstep(0.25, 0.6, px));
}

// The body's colour. `variety` 0-7 in VARIETIES' order (koi_school_4d.gd); `shine` comes back 0 for
// a plain skin, up to 1 for the metallic ones (the skin shader's highlight).
vec3 koi_body(float variety, float seed, float detail, float s, vec3 dir, out float shine) {
	float dorsal = dir.y;
	vec2 across = dir.xz;
	vec3 white = vec3(0.93, 0.92, 0.88);
	vec3 cream = vec3(0.95, 0.90, 0.80);
	vec3 hi = vec3(0.78, 0.11, 0.04);
	vec3 sumi = vec3(0.035, 0.035, 0.04);
	vec3 col = white;
	shine = 0.0;
	vec3 P = vec3(s * 4.2 + seed * 31.0, across.x * 1.1 + seed * 17.0, across.y * 1.1 + seed * 5.0);
	float n1 = kp_blotch(P) + 0.12 * (1.0 - smoothstep(0.10, 0.24, s));
	float back = smoothstep(-0.35, 0.15, dorsal);
	float red = smoothstep(0.46, 0.49, n1) * back * smoothstep(0.012, 0.03, s) * (1.0 - smoothstep(0.74, 0.79, s) * 0.7);
	float scale_edge = kp_scale_edge(s, dir);
	float scaled = (s > 0.19 && s < 0.79) ? 1.0 : 0.0;
	if (variety < 0.5) {
		// KOHAKU: white with red.
		col = mix(white, hi, red);
	} else if (variety < 1.5) {
		// TAISHO SANKE: Kohaku with small black patches on the back, none on the head.
		col = mix(white, hi, red);
		float black = smoothstep(0.60, 0.62, kp_blotch(P * 2.2 + 40.0)) * smoothstep(0.0, 0.35, dorsal) * step(0.22, s);
		col = mix(col, sumi, black);
	} else if (variety < 2.5) {
		// SHOWA: black over white and red, black reaching the head.
		float wmask = smoothstep(0.56, 0.59, kp_blotch(P * 0.9 + 70.0)) + smoothstep(-0.2, -0.7, dorsal);
		col = mix(sumi, white, clamp(wmask, 0.0, 1.0));
		col = mix(col, hi, smoothstep(0.53, 0.56, n1) * back);
	} else if (variety < 3.5) {
		// TANCHO: white, one red disc on the head (a ball's cut, on a 4D head).
		float d = length(vec3((s - 0.085) * 15.0, across * 1.3));
		col = mix(white, hi, smoothstep(0.62, 0.56, d) * step(0.0, dorsal));
	} else if (variety < 4.5) {
		// OGON: metallic gold all over.
		col = vec3(1.0, 0.76, 0.28) * (0.92 + 0.08 * dorsal);
		shine = 1.0;
	} else if (variety < 5.5) {
		// PLATINUM OGON.
		col = vec3(0.92, 0.93, 0.95);
		shine = 1.0;
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
		shine = 0.5;
		scaled = 0.0;
	}
	// The scales: a fine darker line at each scale's edge.
	col *= 1.0 - 0.06 * scale_edge * scaled;
	// The belly is paler on every koi but the metallic ones.
	if (variety < 3.5 || variety > 5.5) {
		col = mix(col, cream, smoothstep(-0.55, -0.9, dorsal) * 0.6);
	}
	if (detail > 0.5) {
		// The gill cover's rear edge, a soft curve behind the eye.
		float gill = abs(s - (0.205 - 0.03 * dorsal * dorsal));
		col *= 1.0 - 0.22 * (1.0 - smoothstep(0.0015, 0.0045, gill)) * step(abs(dorsal), 0.75);
		// The lateral line: a row of pores along the flank (a band round the 4D flank), a little
		// below the middle.
		float pore = step(fract(s * 140.0), 0.38) * (1.0 - smoothstep(0.02, 0.045, abs(dorsal + 0.08))) * step(0.21, s) * step(s, 0.77);
		col = mix(col, col * (variety > 3.5 && variety < 5.5 ? 1.18 : 0.78), pore * 0.6);
		// The nostrils.
		vec2 nose = vec2((s - 0.032) * 18.0, (length(across) - 0.55) * 3.0);
		col *= 1.0 - 0.7 * (1.0 - smoothstep(0.3, 0.55, length(nose))) * step(0.2, dorsal);
	}
	if (s < 0.014) {
		// The lips.
		col = mix(col, vec3(0.85, 0.66, 0.60), 0.5);
	}
	return col;
}

// A fin's colour: `reach` 0 at its root to 1 at its edge, `ray` across it (0-1, the rays run root to
// edge), `body` the body colour there (the metallic koi's fins are their body's). Each variety's fins
// in its own colours, never the body's patches across them.
vec3 koi_fin(float variety, float long_fins, float reach, float ray_at, bool pectoral, vec3 body) {
	vec3 white = vec3(0.93, 0.92, 0.88);
	vec3 sumi = vec3(0.035, 0.035, 0.04);
	float ray = 0.5 + 0.5 * sin(ray_at * 70.0);
	vec3 fin = white;
	if (variety > 1.5 && variety < 2.5) {
		// Showa: black at the pectorals' root, black rays elsewhere.
		fin = pectoral ? mix(sumi, white, smoothstep(0.25, 0.45, reach)) : mix(white, sumi, step(0.8, ray) * 0.5);
	} else if (variety > 0.5 && variety < 1.5) {
		fin = mix(white, sumi, step(0.86, ray) * 0.6 * step(0.3, reach));
	} else if (variety > 3.5 && variety < 5.5) {
		fin = body;
	} else if (variety > 5.5 && variety < 6.5) {
		fin = mix(vec3(0.86, 0.40, 0.16), white, smoothstep(0.2, 0.8, reach));
	} else if (variety > 6.5) {
		fin = vec3(0.62, 0.46, 0.28);
	}
	fin *= 0.93 + 0.07 * ray;
	return mix(fin, white * 0.97, 0.25 * long_fins * reach);
}

// The eye: a black pupil in a gold ring; `k` how far the point faces out along the eye's look (-1-1).
vec3 koi_eye(float k) {
	vec3 col = mix(vec3(0.05, 0.05, 0.05), vec3(0.75, 0.55, 0.18), smoothstep(0.35, 0.5, k));
	return mix(col, vec3(0.005), smoothstep(0.70, 0.78, k));
}

// Every part of the koi: `uvw` as koi_loft_4d.gd bakes it (x: s; y: a fin's reach or the eye's k;
// z: the part, 0 body, 1-2 a fin (1 + its ray coordinate / 2), 2 the eye, 3 a barbel, 4 a pectoral
// fin (4 + ray / 2)), `xyw` the point's place at rest (unit length) for the body's own facing.
vec3 koi_colour(float variety, float long_fins, float seed, float detail, vec3 uvw, vec3 xyw, out float shine) {
	float part = uvw.z;
	float s = uvw.x;
	vec3 body = koi_body(variety, seed, detail, s, koi_dir(s, xyw), shine);
	if (part < 0.75) {
		return body;
	}
	if (part >= 3.75) {
		shine *= 0.5;
		return koi_fin(variety, long_fins, uvw.y, max(part - 4.0, 0.0) * 2.0, true, body);
	}
	if (part < 1.75) {
		shine *= 0.5;
		return koi_fin(variety, long_fins, uvw.y, (part - 1.0) * 2.0, false, body);
	}
	if (part < 2.75) {
		shine = 1.0;
		return koi_eye(uvw.y);
	}
	shine = 0.0;
	return mix(body, vec3(0.88, 0.70, 0.62), 0.5);
}
