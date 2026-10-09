shader_type spatial;
render_mode cull_disabled;

// WATER LAB: the fish wall's picture of a lofted animal (room/fish_wall_4d.gd) whose 4D material looks
// its colours up in a 3D texture (the eel, life/eel_loft_4d.gd skin()): the true cut of its 4D body at
// w = 0 (shared/slice_mesh.gd carries the loft's texture coordinates across), the same texture read at
// the same coordinates. A wet, slimy skin, as the old eel shader had it.

uniform sampler3D skin : source_color, filter_linear, repeat_disable;
uniform float clearcoat = 0.9;

varying vec3 v_uvw;

void vertex() {
	v_uvw = vec3(UV, UV2.x);
}

void fragment() {
	ALBEDO = texture(skin, v_uvw).rgb;
	ROUGHNESS = 0.3;
	SPECULAR = 0.6;
	CLEARCOAT = clearcoat;
	CLEARCOAT_ROUGHNESS = 0.15;
}
