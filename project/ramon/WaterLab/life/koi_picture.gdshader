shader_type spatial;
render_mode cull_disabled;

// WATER LAB: the fish wall's picture of a lofted koi (room/fish_wall_4d.gd): the true cut of its 4D
// body at w = 0 (shared/slice_mesh.gd, which carries the loft's UVWs across), painted with the same
// colours as the koi in the tank (life/koi_pattern.gdshaderinc). The mesh is the koi at rest, one body
// length long, so its own x and y are the rest pose's.

#include "res://ramon/WaterLab/life/koi_pattern.gdshaderinc"

uniform float variety = 0.0;
uniform float long_fins = 0.0;
uniform float pattern_seed = 0.37;
uniform float detail = 1.0;

varying vec3 v_uvw;
varying vec3 v_rest;

void vertex() {
	v_uvw = vec3(UV, UV2.x);
	v_rest = VERTEX;
}

void fragment() {
	float shine;
	vec3 col = koi_colour(variety, long_fins, pattern_seed, detail, v_uvw, vec3(v_rest.x, v_rest.y, 0.0), shine);
	ALBEDO = col;
	// Only a touch of metal: the cut's facets are flat, and a fully metallic koi took the studio's blue
	// for its colour (the Ogon read khaki, round 5).
	METALLIC = 0.15 * shine;
	ROUGHNESS = mix(0.36, 0.28, shine);
	SPECULAR = 0.55;
	CLEARCOAT = 0.5;
	CLEARCOAT_ROUGHNESS = 0.22;
}
