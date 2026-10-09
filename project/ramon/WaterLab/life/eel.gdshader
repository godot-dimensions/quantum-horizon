shader_type spatial;
render_mode skip_vertex_transform, cull_disabled;

// WATER LAB: the tank's eel (life/eel_4d.gd), drawn the starlings' way (shared/slice_draw.gdshaderinc)
// and bent here, on the GPU, every frame. Its mesh is one body length, snout at z = +0.5.
//
// THE SWIM IS ANGUILLIFORM (Tytell 2004, American eels; the research in follow_up/water_lab.md): the
// whole body waves, more than one wave on it at once (a wavelength of 0.65 to 0.87 body lengths),
// almost still at the head and growing toward the tail:
//     lat(s) = A (0.08 + 0.92 s^1.6) sin(2 pi s / wavelength - phase) + C (s - 0.4)^2 + R(s)
// C bends it into a turn; R is a resting curve (an S, its tail tucked in the cave). Swimming
// backward the phase runs the other way and the head swings more (the school sets `back`).
//
// INSTANCE DATA: custom x the phase, y A (body lengths), z the length (m), w C; colour r: 1 when
// swimming backward, g: the rest curve's weight, b: the gill and mouth (breathing), a: spare.

#include "res://ramon/WaterLab/shared/slice_draw.gdshaderinc"

uniform float w_radius = 0.06;
uniform float snout_z = 0.5;
uniform float wavelength = 0.72;

varying vec3 rest;
varying float v_s;
varying float v_part;
varying vec2 v_fin;

vec2 spine(float s, float phase, float amp, float bend, float back, float curl) {
	float k = 6.2831853 / wavelength;
	float th = k * s - phase;
	float env = 0.08 + 0.92 * pow(s, 1.6);
	float denv = 0.92 * 1.6 * pow(max(s, 0.0001), 0.6);
	// Backward, the amplitude is more even along the body and the head swings.
	env = mix(env, 0.55 + 0.45 * s, back);
	denv = mix(denv, 0.45, back);
	float lat = amp * env * sin(th) + bend * (s - 0.4) * (s - 0.4) + curl * 0.06 * sin(s * 7.0);
	float d = amp * (denv * sin(th) + env * cos(th) * k) + 2.0 * bend * (s - 0.4) + curl * 0.06 * 7.0 * cos(s * 7.0);
	return vec2(lat, d);
}

void vertex() {
	SliceFrame o = slice_frame(MODEL_MATRIX);
	vec4 kind = COLOR;
	float phase = INSTANCE_CUSTOM.x;
	float amp = INSTANCE_CUSTOM.y;
	float size = INSTANCE_CUSTOM.z;
	float bend = INSTANCE_CUSTOM.w;
	int part = int(UV.y + 0.5);
	float s = UV.x;
	bool rigid = CUSTOM0.y > 0.5;
	float sa = rigid ? CUSTOM0.x : s;
	vec3 v = VERTEX;
	rest = VERTEX;
	v_s = s;
	v_part = UV.y;
	v_fin = UV2;
	if (part == 0 && s < 0.05) {
		// Breathing: the mouth and the gills open a little.
		float m = (1.0 - s / 0.05) * kind.b;
		v.y -= 0.004 * m * step(v.y, -0.002);
	}
	if (part == 2) {
		// The pectorals flutter.
		v.y += 0.006 * UV2.x * sin(TIME * 9.0 + UV2.y);
	}
	vec2 sp = spine(sa, phase, amp, bend, kind.r, kind.g);
	if (part == 1) {
		// The long fin ripples a little behind the body.
		sp.x += 0.006 * UV2.x * sin(6.2831853 * sa / wavelength - phase - 1.0);
	}
	float inv = inversesqrt(1.0 + sp.y * sp.y);
	float cb = inv;
	float sb = sp.y * inv;
	float za = snout_z - sa;
	vec3 off = vec3(v.x, v.y, rigid ? v.z - za : 0.0);
	vec3 bent = vec3(sp.x + off.x * cb - off.z * sb, off.y, za + off.x * sb + off.z * cb);
	vec3 n = NORMAL;
	vec3 nb = vec3(n.x * cb - n.z * sb, n.y, n.x * sb + n.z * cb);
	float section = slice_section(o.rel.w, w_radius * size);
	bent *= size * section;
	VERTEX = slice_place(o, bent);
	NORMAL = slice_turn(o, nb);
}

void fragment() {
	int part = int(v_part + 0.5);
	float s = v_s;
	float a = atan(rest.y, rest.x);
	float dorsal = sin(a);
	// A European eel in its yellow phase: dark olive on the back, yellow-grey flanks, a pale belly.
	vec3 back = vec3(0.10, 0.10, 0.05);
	vec3 flank = vec3(0.42, 0.38, 0.18);
	vec3 belly = vec3(0.78, 0.70, 0.42);
	vec3 col = mix(flank, back, smoothstep(-0.1, 0.6, dorsal));
	col = mix(col, belly, smoothstep(-0.35, -0.8, dorsal));
	// A faint mottle.
	col *= 0.9 + 0.12 * sd_noise(vec2(s * 60.0, a * 4.0));
	float rough = 0.28;
	if (part == 1) {
		col = mix(vec3(0.26, 0.22, 0.10), vec3(0.45, 0.40, 0.22), v_fin.x);
		col *= 0.9 + 0.1 * sin(v_fin.y * 300.0);
		rough = 0.5;
	} else if (part == 2) {
		col = vec3(0.36, 0.32, 0.16);
	} else if (part == 3) {
		col = mix(vec3(0.02), vec3(0.62, 0.48, 0.14), smoothstep(0.35, 0.5, v_fin.x) * (1.0 - smoothstep(0.72, 0.8, v_fin.x)));
		rough = 0.05;
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.6;
	// Eels are slimy: a strong clear coat.
	CLEARCOAT = 0.9;
	CLEARCOAT_ROUGHNESS = 0.15;
}
