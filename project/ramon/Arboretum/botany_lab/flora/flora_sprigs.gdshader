shader_type spatial;
render_mode skip_vertex_transform, cull_disabled, diffuse_lambert_wrap, specular_disabled;

// BOTANY LAB, round 3 (follow_up/arboretum.md section 9, steps 19-22): the flower room's small foliage
// (ivy leaves, the grass along the wall foot, wisteria florets, little wildflowers) as the pen's trick
// (Ramon: "some tricks with grassy 3d plants that behave well in 4d is fine too. just look at pen
// tech"): one 3D MultiMesh in the Cross-section engine's World3D, moved into the camera's frame by hand
// each render (flora_sprigs_4d.gd), as the pen's grass and leaves are.
//
// EACH PIECE has a place on the wall or the floor (its instance transform, in the node's x, y, z) and
// a home in W (INSTANCE_CUSTOM.a, metres): it is drawn on your slice where the slice crosses its spot,
// full size when the slice is at its home and shrinking to nothing `w_radius` either side, as a blade of
// grass is in the pen. So stepping through W, some leaves grow in as others shrink away: the ivy is a
// different ivy in every slice, which a 3D plant could never be.
//
//   INSTANCE_CUSTOM   r: kind (0 leaf, 1 blade, 2 floret, 3 petal, 4 stem), g: colour pick 0..1,
//                     b: how much it flutters, a: its home in W
// The mesh is the pen's diamond (UV x across -1..1, y along 0..1); the kind shapes it.

uniform vec4 frame[7];
uniform float wind_now = 1.0;
uniform float gust = 0.0;
uniform float w_radius = 0.7;
uniform vec3 leaf_a : source_color = vec3(0.10, 0.24, 0.08);
uniform vec3 leaf_b : source_color = vec3(0.20, 0.36, 0.12);
uniform vec3 blade_a : source_color = vec3(0.24, 0.42, 0.14);
uniform vec3 blade_b : source_color = vec3(0.42, 0.56, 0.22);
uniform vec3 floret_a : source_color = vec3(0.62, 0.52, 0.88);
uniform vec3 floret_b : source_color = vec3(0.92, 0.88, 0.98);
uniform vec3 petal_a : source_color = vec3(0.98, 0.98, 0.96);
uniform vec3 petal_b : source_color = vec3(1.0, 0.86, 0.3);
uniform vec3 stem_a : source_color = vec3(0.28, 0.22, 0.16);
uniform vec3 stem_b : source_color = vec3(0.36, 0.3, 0.2);
uniform float floret_glow = 0.14;

varying vec3 v_colour;
varying float v_glow;

float hash(float id, float k) {
	vec3 p3 = fract(vec3(id * 0.1031, k * 0.1030, (id + k) * 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	mat4 vb = mat4(frame[0], frame[1], frame[2], frame[3]);
	vec4 view_origin = frame[4];
	vec4 camera_world = frame[5];
	vec4 slice_normal = frame[6];
	float id = float(INSTANCE_ID);
	float kind = floor(INSTANCE_CUSTOM.r + 0.5);
	float pick = INSTANCE_CUSTOM.g;
	float flutter = INSTANCE_CUSTOM.b;
	float home_w = INSTANCE_CUSTOM.a;
	// The piece's shape in its own plane: x across, y along (its stalk at y 0).
	float across = kind < 0.5 ? 0.62 : (kind < 1.5 ? 0.09 : (kind < 2.5 ? 0.5 : (kind < 3.5 ? 0.42 : 0.12)));
	vec3 local = vec3(UV.x * across, UV.y, 0.0);
	// A leaf's heart: wider near its stalk.
	if (kind < 0.5) {
		local.x *= 1.0 + 0.5 * (1.0 - UV.y);
	}
	// Flutter: a turn about the stalk, and a nod, with the wind.
	float t = TIME * mix(1.6, 3.2, hash(id, 3.0)) + hash(id, 4.0) * 6.2831853;
	float amp = flutter * (0.12 + 0.05 * wind_now + 0.5 * gust);
	float roll = sin(t) * amp;
	float nod = sin(t * 0.73 + 1.3) * amp * 0.6;
	mat3 r_roll = mat3(vec3(cos(roll), 0.0, -sin(roll)), vec3(0.0, 1.0, 0.0), vec3(sin(roll), 0.0, cos(roll)));
	mat3 r_nod = mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, cos(nod), sin(nod)), vec3(0.0, -sin(nod), cos(nod)));
	local = r_nod * (r_roll * local);
	vec3 base = MODEL_MATRIX[3].xyz;
	vec3 p3 = (MODEL_MATRIX * vec4(local, 1.0)).xyz;
	vec3 n3 = normalize((MODEL_MATRIX * vec4(r_nod * (r_roll * vec3(0.0, 0.0, 1.0)), 0.0)).xyz);
	// Its w: where the slice crosses its spot; its size: how near that is to its home.
	vec3 dp = base - camera_world.xyz;
	float nw = slice_normal.w;
	float w_slice = abs(nw) > 0.25 ? camera_world.w - dot(slice_normal.xyz, dp) / nw : camera_world.w;
	float dw = (w_slice - home_w) / max(w_radius, 0.01);
	float s2 = 1.0 - dw * dw;
	float section = s2 > 0.0 ? sqrt(s2) : 0.0;
	vec4 b4 = vb * vec4(base, w_slice) + view_origin;
	if (section <= 0.02 || b4.z > 1.0) {
		VERTEX = vec3(0.0, 0.0, 1.0);
		NORMAL = vec3(0.0, 1.0, 0.0);
		v_colour = vec3(0.0);
		v_glow = 0.0;
	} else {
		vec3 shrunk = base + (p3 - base) * section;
		vec4 v = vb * vec4(shrunk, w_slice) + view_origin;
		VERTEX = v.xyz;
		NORMAL = normalize((vb * vec4(n3, 0.0)).xyz);
		vec3 c;
		float g = 0.0;
		if (kind < 0.5) {
			c = mix(leaf_a, leaf_b, pick);
			// A paler vein down the middle.
			c = mix(c, c * 1.5, (1.0 - smoothstep(0.0, 0.18, abs(UV.x))) * 0.5);
		} else if (kind < 1.5) {
			c = mix(blade_a, blade_b, pick * 0.6 + UV.y * 0.4);
		} else if (kind < 2.5) {
			c = mix(floret_a, floret_b, pick);
			g = floret_glow;
		} else if (kind < 3.5) {
			c = pick < 0.5 ? mix(petal_a, petal_a * 0.92, pick * 2.0) : mix(petal_b, petal_b * 0.9, pick * 2.0 - 1.0);
			g = floret_glow;
		} else {
			c = mix(stem_a, stem_b, pick);
		}
		v_colour = c;
		v_glow = g;
	}
}

void fragment() {
	ALBEDO = v_colour;
	EMISSION = v_colour * v_glow;
	ROUGHNESS = 0.7;
	BACKLIGHT = v_colour * 0.5;
}
