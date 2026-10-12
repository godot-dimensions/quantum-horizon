shader_type spatial;
render_mode skip_vertex_transform;

// WATER LAB: small round things in the tank, drawn the starlings' way (shared/slice_draw.gdshaderinc):
// the koi's food pellets and the air stone's bubbles. Each instance is a 4D ball: the slice through it
// is a smaller ball off its middle in W.
//
// INSTANCE DATA: custom x its radius (m), y wobble (bubbles squash as they rise), z shine (0 a matt
// pellet, 1 a bubble's bright rim); the colour its colour.

#include "res://ramon/WaterLab/shared/slice_draw.gdshaderinc"

uniform float w_radius = 1.0;

varying vec4 v_col;
varying float v_shine;

void vertex() {
	SliceFrame o = slice_frame(MODEL_MATRIX);
	float r = INSTANCE_CUSTOM.x;
	float section = slice_section(o.rel.w, r * w_radius);
	vec3 v = VERTEX;
	float wob = INSTANCE_CUSTOM.y;
	v.y *= 1.0 - 0.18 * wob * sin(TIME * 9.0 + float(INSTANCE_ID));
	v.x *= 1.0 + 0.09 * wob * sin(TIME * 7.0 + float(INSTANCE_ID) * 1.7);
	v *= r * section;
	VERTEX = slice_place(o, v);
	NORMAL = slice_turn(o, NORMAL);
	v_col = COLOR;
	v_shine = INSTANCE_CUSTOM.z;
}

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALBEDO = v_col.rgb * (1.0 - 0.6 * v_shine) + vec3(0.8, 0.95, 1.0) * rim * v_shine;
	ROUGHNESS = mix(0.7, 0.05, v_shine);
	SPECULAR = mix(0.3, 0.9, v_shine);
	EMISSION = vec3(0.6, 0.85, 0.95) * rim * v_shine * 0.4;
}
