shader_type spatial;
render_mode skip_vertex_transform, unshaded, cull_back;

// WATER LAB: the specks that hang in the tank's water (marine snow), drawn the starlings' way
// (shared/slice_draw.gdshaderinc). Written ONCE by life/snow_4d.gd: each speck drifts and sinks here,
// on the GPU, its height wrapped back to the top of the water when it reaches the sand, so a
// thousand of them cost the CPU nothing a frame. Each is a tiny 4D ball, cut by the slice; it glows a
// little, as specks do where they cross a beam of light.
//
// INSTANCE DATA: the position is the speck's home in the water's frame; custom x its radius, y how
// fast it sinks (m/s), z a phase, w how bright; the colour its tint.

#include "res://ramon/WaterLab/shared/slice_draw.gdshaderinc"

uniform vec4 half_ext = vec4(9.2, 2.4, 1.6, 3.5);
uniform float w_depth = 24.0;

varying float v_bright;
varying vec4 v_col;

void vertex() {
	vec4 home = vec4(MODEL_MATRIX[0][0], MODEL_MATRIX[1][0], MODEL_MATRIX[2][0], MODEL_MATRIX[3][0]);
	float r = INSTANCE_CUSTOM.x;
	float ph = INSTANCE_CUSTOM.z;
	float t = TIME;
	vec4 p = home;
	p.x += 0.25 * sin(t * 0.07 + ph) + 0.06 * sin(t * 0.31 + ph * 2.7);
	p.z += 0.12 * sin(t * 0.05 + ph * 1.9);
	p.w += 0.10 * sin(t * 0.04 + ph * 3.1);
	// Sinking, wrapped from the sand back to the surface.
	float span = half_ext.y * 2.0;
	p.y = mod(p.y + half_ext.y - t * INSTANCE_CUSTOM.y, span) - half_ext.y;
	mat4 vb = mat4(view_basis_x, view_basis_y, view_basis_z, view_basis_w);
	vec4 rel = vb * p + view_origin;
	float section = slice_section(rel.w, r * w_depth);
	// A camera-facing speck: the quad's corners spread in the view's own plane.
	vec3 v = VERTEX * r * section;
	VERTEX = rel.xyz + v;
	v_bright = INSTANCE_CUSTOM.w * (0.5 + 0.5 * sin(t * 1.3 + ph * 5.0));
	v_col = COLOR;
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	if (d > 1.0) {
		discard;
	}
	ALBEDO = v_col.rgb * (0.6 + 0.6 * v_bright) * (1.0 - d * 0.5);
}
