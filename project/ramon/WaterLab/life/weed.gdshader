shader_type spatial;
render_mode skip_vertex_transform, cull_disabled, diffuse_lambert_wrap;

// WATER LAB: the tank's weed, the pen's grass taken under water (chickenpen/grass/pen_grass_lattice.gdshader;
// Ramon, 9 Oct: "look at the grass system in the pen, adapt it and make long weed things"). Drawn the
// starlings' way (shared/slice_draw.gdshaderinc); written once by life/weed_4d.gd, moved here.
//
// FROM THE PEN'S GRASS, KEPT:
//   - the cut: each blade a 4D ribbon `w_radius` deep in W, the section shrinking its height AND its
//     width off its middle (the grass does both);
//   - gust BANDS that travel downstream across the bed (noise moving with the current), varying through
//     the blade's own W, so neighbours through W sway differently;
//   - taller blades lagging the band (the pen's up to half a second), a rocking of their own, a flutter
//     across;
//   - the colour: a ramp root, base, tip; clumps lush or dry by noise on the root; a hue jitter a blade;
//     backlight for translucency; lambert wrap.
// CHANGED FOR WATER:
//   - LONG: 20 segments, 1 to 4.3 m, ribbons 3 to 30 cm wide; the single Bezier of the grass hooks
//     long blades, so the bend is a lean that grows up the blade plus a wave that runs up it (the tip a
//     beat behind the root), the length kept by pulling the height in as it leans;
//   - CURRENT, not wind: slow (bands at a third of a metre a second), and BUOYANT: the lean saturates
//     and springs back upright instead of laying the blade flat (no tanh-to-the-ground);
//   - no big gust fronts and no fast rock: water is thick.
//
// INSTANCE DATA: custom x the height (m), y the width (m), z its phase, w how loose it is (0 stiff, 1 a
// kelp ribbon); the colour its base colour, alpha its clump (0 lush, 1 dry).

#include "res://ramon/WaterLab/shared/slice_draw.gdshaderinc"

uniform float w_radius = 0.45;
uniform float current_speed = 0.35;
uniform float current_strength = 1.0;

varying float v_t;
varying vec4 v_col;
varying float v_band;

void vertex() {
	SliceFrame o = slice_frame(MODEL_MATRIX);
	vec4 root = vec4(MODEL_MATRIX[0][0], MODEL_MATRIX[1][0], MODEL_MATRIX[2][0], MODEL_MATRIX[3][0]);
	float height = INSTANCE_CUSTOM.x;
	float width = INSTANCE_CUSTOM.y;
	float ph = INSTANCE_CUSTOM.z;
	float loose = INSTANCE_CUSTOM.w;
	float t = UV.x;
	float across = UV.y;
	float section = slice_section(o.rel.w, w_radius);
	float h = height * section;
	// The current's bands, travelling downstream (+x), through the blade's own W too; the tall lag.
	float lag = 0.6 * height / 4.0;
	float tt = TIME - lag * t;
	float band = sd_noise(vec2(root.x * 0.22 - tt * current_speed, root.w * 0.6 + root.z * 0.4));
	v_band = band;
	float strength = current_strength * (0.35 + 0.65 * band) * (0.5 + 0.5 * loose);
	// The lean grows up the blade and saturates (buoyancy pulls it back up).
	float lean = 0.55 * strength * t * t;
	// A wave running up the blade, a beat behind at the tip, and its own slow rocking.
	float wave = (0.10 + 0.12 * loose) * t * sin(6.2831 * (t * 0.7 * height / 2.0) - tt * 1.6 + ph);
	float rock = 0.05 * t * sin(tt * (0.5 + 0.3 * fract(ph * 3.1)) + ph * 2.0);
	float dx = (lean + wave + rock) * h;
	float dz = (0.06 + 0.06 * loose) * t * h * sin(tt * 0.9 + ph * 1.7 - t * 3.0);
	// Kept its length: what leans is taken from the height.
	float dy = t * h - 0.5 * (dx * dx + dz * dz) / max(t * h, 0.05);
	// The ribbon: narrow at the root, widest two thirds up, a rounded tip, twisting a little.
	float wprof = pow(sin(3.14159 * pow(t, 0.75)), 0.8) * (1.0 - 0.15 * t);
	float twist = ph * 2.0 + t * (1.2 + loose) + 0.3 * sin(tt * 0.7 + ph);
	vec3 wdir = vec3(cos(twist), 0.0, sin(twist));
	vec3 nrm = vec3(-sin(twist), 0.0, cos(twist));
	float ruffle = loose * 0.15 * sin(t * 50.0 + ph * 3.0) * abs(across);
	vec3 p = vec3(dx, dy, dz) + wdir * (across * width * 0.5 * wprof * section) + nrm * ruffle * width;
	VERTEX = slice_place(o, p);
	NORMAL = slice_turn(o, nrm);
	v_t = t;
	v_col = COLOR;
}

void fragment() {
	// The ramp: a dark root, the base colour, a lighter tip; dry clumps paler and browner.
	vec3 base = v_col.rgb;
	vec3 dry = mix(base, vec3(0.55, 0.48, 0.24), 0.55);
	vec3 col = mix(base, dry, v_col.a);
	col = mix(col * 0.45, col, smoothstep(0.0, 0.25, v_t));
	col = mix(col, col * 1.35 + vec3(0.03, 0.05, 0.0), smoothstep(0.6, 1.0, v_t));
	// The band passing: a little sheen, as the grass's gust sheen.
	col += vec3(0.04, 0.06, 0.02) * smoothstep(0.6, 0.9, v_band) * v_t;
	ALBEDO = col;
	ROUGHNESS = 0.55;
	SPECULAR = 0.35;
	BACKLIGHT = col * 0.55 * (0.4 + 0.6 * v_t);
}
