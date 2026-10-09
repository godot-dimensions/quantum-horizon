shader_type spatial;
render_mode skip_vertex_transform, cull_disabled;

// WATER LAB: one sardine of the sea's school (seascape/fish_school_4d.gd), drawn by the carried flock
// (carried/flock/school_flock_4d.gd) in place of a starling: the same instance data, the same 4D cut
// (shared/slice_draw.gdshaderinc does what flock_bird.gdshader does inline), a fish instead of a bird.
//
// The flock's rows: position, heading, the side the fish is rolled to; custom x its phase, y how hard
// it beats (the flock's flap: 1 when the school is startled), z its size; the colour its tint. Where a
// bird flapped its wings, the fish beats its tail: the back half of the body swings side to side, more
// toward the tail, a wave running down it. SILVER FLANKS: as a fish rolls (the school's turns, the
// agitation waves when the plesiosaur comes through) its flank turns to the light and flashes, as a
// real school does.

#include "res://ramon/WaterLab/shared/slice_draw.gdshaderinc"

uniform float w_radius = 0.35;
uniform float flap_rate = 4.5;
uniform int white_index = -1;

varying float v_up;
varying float v_tail;
varying vec4 v_col;

void vertex() {
	SliceFrame o = slice_frame(MODEL_MATRIX);
	float size = INSTANCE_CUSTOM.z;
	float section = slice_section(o.rel.w, w_radius * size);
	vec3 v = VERTEX;
	float tail = UV.x;
	float ph = INSTANCE_CUSTOM.x;
	float beat = clamp(0.35 + INSTANCE_CUSTOM.y * 0.65, 0.0, 1.0);
	float rate = flap_rate * (0.9 + 0.2 * fract(ph * 7.31));
	float swing = beat * 0.22 * tail * tail * sin(TIME * 6.2831 * rate + ph * 6.2831 - tail * 2.5);
	v.x += swing * 0.25;
	v *= size * section;
	VERTEX = slice_place(o, v);
	NORMAL = slice_turn(o, NORMAL);
	v_up = UV.y;
	v_tail = tail;
	v_col = COLOR;
}

void fragment() {
	// A sardine: blue-green back, a row of dark spots on the upper flank, silver flanks, a white belly.
	vec3 back = vec3(0.04, 0.14, 0.18);
	vec3 silver = vec3(0.78, 0.82, 0.86);
	vec3 belly = vec3(0.94, 0.95, 0.96);
	float up = v_up;
	vec3 col = mix(silver, back, smoothstep(0.25, 0.55, up));
	col = mix(belly, col, smoothstep(-0.55, -0.15, up));
	float spots = step(0.5, fract(v_tail * 9.0)) * (1.0 - smoothstep(0.02, 0.08, abs(up - 0.22))) * step(v_tail, 0.6);
	col = mix(col, back * 0.6, spots * 0.7);
	ALBEDO = col * clamp(v_col.r, 0.7, 1.2);
	METALLIC = mix(0.85, 0.2, smoothstep(0.3, 0.6, up));
	ROUGHNESS = 0.22;
	SPECULAR = 0.8;
}
