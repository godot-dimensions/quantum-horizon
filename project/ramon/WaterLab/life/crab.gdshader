shader_type spatial;
render_mode skip_vertex_transform, cull_disabled;

// WATER LAB: the tank's crab (life/crab_4d.gd), drawn the starlings' way (shared/slice_draw.gdshaderinc),
// its legs stepping here on the GPU. Modelled +Z ahead (its face), +X its right, +Y up, one unit its
// carapace's width.
//
// A crab walks SIDEWAYS on eight legs in two alternating sets of four (a tetrapod gait): on each
// side legs 1 and 3 step while 2 and 4 hold, and the other side is half a step behind. A leg lifts at
// its hip, swings, and its knee flexes as it reaches; the body bobs a little with each step. The
// claws hang folded in front of the face, and now and then pick at the sand and bring it to the
// mouth, the pincers opening and closing.
//
// PER VERTEX: UV.y the part (0 carapace, 1 eyes, 2 claw, 3 claw finger, 4 leg upper, 5 leg lower),
// UV.x the leg's slot 0-3 (claws: 0), UV2.x its side (-1 left, 1 right); CUSTOM0.xyz the part's hip
// or shoulder, CUSTOM1.xyz its knee or hinge.
// INSTANCE: custom x the gait's phase, y how hard it walks (0 still), z the size (m), w the claws'
// reach (0 folded, 1 down to the sand); colour r the pincers (0 shut, 1 open).

#include "res://ramon/WaterLab/shared/slice_draw.gdshaderinc"

uniform float w_radius = 0.6;

varying float v_part;
varying vec3 rest;

vec3 turn_about(vec3 v, vec3 root, vec3 axis, float angle) {
	vec3 p = v - root;
	float c = cos(angle);
	float s = sin(angle);
	return root + p * c + cross(axis, p) * s + axis * dot(axis, p) * (1.0 - c);
}

void vertex() {
	SliceFrame o = slice_frame(MODEL_MATRIX);
	float phase = INSTANCE_CUSTOM.x;
	float walk = INSTANCE_CUSTOM.y;
	float size = INSTANCE_CUSTOM.z;
	float reach = INSTANCE_CUSTOM.w;
	float pinch = COLOR.r;
	int part = int(UV.y + 0.5);
	float slot = UV.x;
	float side = UV2.x;
	vec3 v = VERTEX;
	vec3 n = NORMAL;
	rest = VERTEX;
	v_part = UV.y;
	vec3 hip = CUSTOM0.xyz;
	vec3 knee = CUSTOM1.xyz;
	if (part == 4 || part == 5) {
		// Two sets of four: legs 0 and 2 on one side with 1 and 3 on the other.
		float set_ = mod(slot + (side > 0.0 ? 1.0 : 0.0), 2.0);
		float ph = phase + set_ * 3.14159265;
		float lift = max(sin(ph), 0.0) * 0.45 * walk;
		float sweep = cos(ph) * 0.22 * walk;
		float flex = (0.25 + 0.35 * max(sin(ph), 0.0)) * walk;
		if (part == 5) {
			// The knee first, about the axis along the body.
			v = turn_about(v, knee, vec3(0.0, 0.0, 1.0), -side * flex);
			n = turn_about(n, vec3(0.0), vec3(0.0, 0.0, 1.0), -side * flex);
		}
		// Then the hip: up, and swung fore and aft.
		v = turn_about(v, hip, vec3(0.0, 0.0, 1.0), side * lift);
		v = turn_about(v, hip, vec3(0.0, 1.0, 0.0), sweep);
		n = turn_about(n, vec3(0.0), vec3(0.0, 0.0, 1.0), side * lift);
	} else if (part == 2 || part == 3) {
		// The claws: lowered to the sand and raised to the mouth (reach), the finger opening.
		if (part == 3) {
			v = turn_about(v, knee, vec3(0.0, 1.0, 0.0), side * 0.5 * pinch);
		}
		float down = reach * (0.55 + 0.25 * sin(TIME * 3.0 + side));
		v = turn_about(v, hip, vec3(1.0, 0.0, 0.0), down);
		n = turn_about(n, vec3(0.0), vec3(1.0, 0.0, 0.0), down);
	}
	// The body bobs with the steps.
	v.y += 0.02 * walk * sin(phase * 2.0);
	float section = slice_section(o.rel.w, w_radius * size);
	v *= size * section;
	VERTEX = slice_place(o, v);
	NORMAL = slice_turn(o, n);
}

void fragment() {
	int part = int(v_part + 0.5);
	// An edible crab's colours: a brick-red shell, paler legs, black-tipped claws.
	vec3 shell = vec3(0.55, 0.24, 0.12);
	vec3 col = shell;
	if (part == 0) {
		// Darker at the rim, a faint pie-crust edge, paler underneath.
		float r = length(rest.xz / vec2(0.5, 0.38));
		col = mix(shell * 1.15, shell * 0.75, smoothstep(0.6, 1.0, r));
		col = mix(col, vec3(0.86, 0.74, 0.6), smoothstep(0.0, -0.06, rest.y));
		col *= 0.92 + 0.1 * sd_noise(rest.xz * 40.0);
	} else if (part == 1) {
		col = vec3(0.02);
	} else if (part == 2) {
		col = mix(shell * 0.9, vec3(0.05), smoothstep(0.42, 0.55, rest.z));
	} else if (part == 3) {
		col = vec3(0.05);
	} else {
		col = mix(vec3(0.70, 0.40, 0.24), vec3(0.85, 0.62, 0.45), float(part == 5));
	}
	ALBEDO = col;
	ROUGHNESS = part == 1 ? 0.1 : 0.45;
	SPECULAR = 0.5;
	CLEARCOAT = 0.4;
	CLEARCOAT_ROUGHNESS = 0.3;
}
