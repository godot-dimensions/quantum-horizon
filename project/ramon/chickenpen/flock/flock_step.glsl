#[compute]
#version 450

// The murmuration on the GPU: the same model as pen_flock_4d.gd's GDScript step, for
// thousands of birds. Five passes a frame, chosen by the push constant:
//   0 COUNT    each bird hashes its grid cell and counts itself into that bucket
//   1 SCAN     one workgroup turns the bucket counts into start offsets
//   2 SCATTER  each bird writes its index into its bucket's run
//   3 UPDATE   the rules, the flight, and the twenty floats the bird shader reads, written
//              straight into the multimesh's own buffer - nothing comes back to the CPU
//   4 REDUCE   one workgroup sums the flock's middle and mean heading for the next frame
// Positions and headings are double-buffered (read *_in, write *_out, swapped each frame) so
// no bird reads a neighbour that has already moved this frame. Everything else is a bird's
// own and only it touches it.
//
// The grid is hashed, not bounded: cell = the largest search radius, 27 cells around a
// bird, buckets = a power of two. Two different cells can land in one bucket, so the 27
// bucket numbers are de-duplicated before the walk; a stranger that shares a bucket is
// dropped by the distance test like any bird out of range.

layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;

layout(push_constant, std430) uniform Push {
	uint pass_index;
	uint count;
	uint mask;
	uint frame;
	float dt;
	float time;
	float pad0;
	float pad1;
} pc;

// Settings, in the order pen_flock_4d.gd _gpu_params() packs them.
layout(set = 0, binding = 0, std430) restrict readonly buffer Params { vec4 p[]; } params;
layout(set = 0, binding = 1, std430) restrict readonly buffer PosIn { vec4 v[]; } pos_in;
layout(set = 0, binding = 2, std430) restrict readonly buffer HeadIn { vec4 v[]; } head_in;
layout(set = 0, binding = 3, std430) restrict writeonly buffer PosOut { vec4 v[]; } pos_out;
layout(set = 0, binding = 4, std430) restrict writeonly buffer HeadOut { vec4 v[]; } head_out;
layout(set = 0, binding = 5, std430) restrict buffer Turn { vec4 v[]; } turn_buf;
// speed, bank, search radius, centrality
layout(set = 0, binding = 6, std430) restrict buffer Misc { vec4 v[]; } misc;
layout(set = 0, binding = 7, std430) restrict buffer Wander { vec4 v[]; } wander_buf;
layout(set = 0, binding = 8, std430) restrict readonly buffer Lead { vec4 v[]; } lead_buf;
// lead seconds left, flap phase, tint, neighbours seen
layout(set = 0, binding = 9, std430) restrict buffer Misc2 { vec4 v[]; } misc2;
layout(set = 0, binding = 10, std430) restrict buffer CellOf { uint v[]; } cell_of;
layout(set = 0, binding = 11, std430) restrict buffer Counts { uint v[]; } counts;
layout(set = 0, binding = 12, std430) restrict buffer Starts { uint v[]; } starts;
layout(set = 0, binding = 13, std430) restrict buffer Cursor { uint v[]; } cursor;
layout(set = 0, binding = 14, std430) restrict buffer Sorted { uint v[]; } sorted_ids;
// 0 middle, 1 mean heading
layout(set = 0, binding = 15, std430) restrict buffer Flock { vec4 v[]; } flock;
layout(set = 0, binding = 16, std430) restrict writeonly buffer Draw { float v[]; } draw;

shared uint scan_part[256];
shared vec4 sum_pos[256];
shared vec4 sum_head[256];

const float G = 9.81;
const float TAU = 6.28318530718;

uint cell_hash(ivec3 c) {
	return (uint(c.x) * 73856093u) ^ (uint(c.y) * 19349663u) ^ (uint(c.z) * 83492791u);
}

ivec3 cell_of_pos(vec4 p, float cell) {
	return ivec3(floor(p.xyz / cell));
}

uint pcg(uint v) {
	uint state = v * 747796405u + 2891336453u;
	uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	return (word >> 22u) ^ word;
}

// Roughly normal, mean 0, spread 1: the sum of three uniforms, recentred.
float noise_n(inout uint seed) {
	float s = 0.0;
	for (int k = 0; k < 3; k++) {
		seed = pcg(seed);
		s += float(seed) / 4294967295.0;
	}
	return (s - 1.5) * 2.0;
}

void count_pass(uint i) {
	float cell = params.p[2].w;
	uint b = cell_hash(cell_of_pos(pos_in.v[i], cell)) & pc.mask;
	cell_of.v[i] = b;
	atomicAdd(counts.v[b], 1u);
}

void scan_pass(uint t) {
	uint buckets = pc.mask + 1u;
	uint per = buckets / 256u;
	uint base = t * per;
	uint local_sum = 0u;
	for (uint k = 0u; k < per; k++) {
		local_sum += counts.v[base + k];
	}
	scan_part[t] = local_sum;
	barrier();
	// Hillis-Steele over the 256 partial sums.
	for (uint offset = 1u; offset < 256u; offset <<= 1u) {
		uint add = t >= offset ? scan_part[t - offset] : 0u;
		barrier();
		scan_part[t] += add;
		barrier();
	}
	uint running = scan_part[t] - local_sum;
	for (uint k = 0u; k < per; k++) {
		starts.v[base + k] = running;
		cursor.v[base + k] = running;
		running += counts.v[base + k];
	}
}

void scatter_pass(uint i) {
	uint k = atomicAdd(cursor.v[cell_of.v[i]], 1u);
	sorted_ids.v[k] = i;
}

void update_pass(uint i) {
	vec4 roost = params.p[0];
	float cruise = params.p[1].x;
	float min_speed = params.p[1].y;
	float max_speed = params.p[1].z;
	float neighbours = params.p[1].w;
	float radius_max = params.p[2].x;
	float sep_r = params.p[2].y;
	float blind_cos = params.p[2].z;
	float cell = params.p[2].w;
	float rule_separation = params.p[3].x;
	float rule_alignment = params.p[3].y;
	float rule_cohesion = params.p[3].z;
	float rule_noise = params.p[3].w;
	float rule_gather = params.p[4].x;
	float gather_from = params.p[4].y;
	float turn_inertia = params.p[4].z;
	float max_turn_rate = params.p[4].w;
	float speed_spring = params.p[5].x;
	float bank_rate = params.p[5].y;
	float roost_radius = params.p[5].z;
	float roost_pull = params.p[5].w;
	float as_one = params.p[6].x;
	float height_low = params.p[6].y;
	float height_high = params.p[6].z;
	float height_pull = params.p[6].w;
	float altitude_pull = params.p[7].x;
	float altitude = params.p[7].y;
	float w_half = params.p[7].z;
	float w_pull = params.p[7].w;
	float level = params.p[8].x;
	float w_level = params.p[8].y;
	float bird_scale = params.p[8].z;
	float lead_gain = params.p[8].w;
	float dt = pc.dt;

	vec4 p = pos_in.v[i];
	vec4 h = head_in.v[i];
	vec4 m = misc.v[i];
	vec4 m2 = misc2.v[i];
	float s = m.x;
	float r = m.z;
	float r2 = r * r;
	float sep2 = sep_r * sep_r;

	// The 27 buckets around the bird, each once.
	ivec3 c = cell_of_pos(p, cell);
	uint buckets[27];
	int bucket_count = 0;
	for (int dz = -1; dz <= 1; dz++) {
		for (int dy = -1; dy <= 1; dy++) {
			for (int dx = -1; dx <= 1; dx++) {
				uint b = cell_hash(c + ivec3(dx, dy, dz)) & pc.mask;
				bool seen_before = false;
				for (int k = 0; k < bucket_count; k++) {
					if (buckets[k] == b) {
						seen_before = true;
						break;
					}
				}
				if (!seen_before) {
					buckets[bucket_count] = b;
					bucket_count++;
				}
			}
		}
	}
	vec4 sep = vec4(0.0);
	vec4 align = vec4(0.0);
	vec4 toward = vec4(0.0);
	vec4 lean = vec4(0.0);
	int seen = 0;
	for (int k = 0; k < bucket_count; k++) {
		uint b = buckets[k];
		uint start = starts.v[b];
		uint end = start + counts.v[b];
		for (uint q = start; q < end; q++) {
			uint j = sorted_ids.v[q];
			if (j == i) {
				continue;
			}
			vec4 d = pos_in.v[j] - p;
			float dd = dot(d, d);
			if (dd > r2 || dd < 1e-8) {
				continue;
			}
			float dl = sqrt(dd);
			if (dot(d, h) < blind_cos * dl) {
				continue;
			}
			vec4 u = d / dl;
			seen++;
			lean += u;
			toward += d;
			align += head_in.v[j];
			if (dd < sep2) {
				sep -= u * (1.0 - dl / sep_r);
			}
		}
	}
	r = clamp(r * (1.0 + 0.12 * (neighbours - float(seen)) / neighbours), sep_r, radius_max);
	float centrality = 1.0;
	vec4 acc = sep * rule_separation;
	if (seen > 0) {
		float n = float(seen);
		centrality = length(lean) / n;
		acc += (align / n - h) * (rule_alignment * s);
		vec4 to_middle = toward / n;
		float tl = length(to_middle);
		if (tl > 1e-5) {
			acc += to_middle * (rule_cohesion * centrality / tl);
		}
	}
	uint seed = pcg(i * 9781u + pc.frame * 6271u + 1u);
	vec4 wander = mix(wander_buf.v[i], vec4(noise_n(seed), noise_n(seed) * 0.3, noise_n(seed), noise_n(seed) * 0.3), 0.08 * dt * 20.0);
	wander_buf.v[i] = wander;
	acc += wander * rule_noise;

	float lead_left = m2.x;
	if (lead_left > 0.0) {
		lead_left -= dt;
		acc += (lead_buf.v[i] - h) * (s * lead_gain);
	}

	// Flock-level: the gather, the roost measured mostly from the middle, and the side the
	// whole flock turns to when it is heading straight away from home.
	vec4 middle = flock.v[0];
	vec4 mean_heading = flock.v[1];
	vec4 to_mid = middle - p;
	float md = length(to_mid);
	if (md > gather_from) {
		acc += to_mid * (rule_gather * min((md - gather_from) / gather_from, 1.0) / md);
	}
	float hx = mix(p.x, middle.x, as_one);
	float hz = mix(p.z, middle.z, as_one);
	float dxr = roost.x - hx;
	float dzr = roost.z - hz;
	float dist = sqrt(dxr * dxr + dzr * dzr);
	if (dist > roost_radius * 0.6) {
		float pull = smoothstep(roost_radius * 0.6, roost_radius * 1.4, dist) * roost_pull / dist;
		acc.x += dxr * pull;
		acc.z += dzr * pull;
	}
	vec2 home = vec2(roost.x - middle.x, roost.z - middle.z);
	float home_d = length(home);
	vec2 mean = vec2(mean_heading.x, mean_heading.z);
	if (home_d > roost_radius * 0.6 && length(mean) > 0.05) {
		home /= home_d;
		mean = normalize(mean);
		float away = -dot(home, mean);
		if (away > -0.2) {
			float turn_sign = (mean.x * home.y - mean.y * home.x) >= 0.0 ? 1.0 : -1.0;
			float ramp = smoothstep(roost_radius * 0.6, roost_radius * 1.4, home_d);
			acc += vec4(-mean.y, 0.0, mean.x, 0.0) * (turn_sign * roost_pull * ramp * as_one * clamp(away + 0.2, 0.0, 1.0));
		}
	}
	acc.y += (altitude - p.y) * altitude_pull;
	if (p.y < height_low) {
		acc.y += min((height_low - p.y) * height_pull, 8.0);
	} else if (p.y > height_high) {
		acc.y -= min((p.y - height_high) * height_pull, 8.0);
	}
	acc.y -= h.y * s * level;
	acc.w -= h.w * s * w_level;
	float dw = p.w - roost.w;
	if (dw > w_half) {
		acc.w -= (dw - w_half) * w_pull;
	} else if (dw < -w_half) {
		acc.w -= (dw + w_half) * w_pull;
	}

	float along = dot(acc, h);
	vec4 across = acc - h * along;
	vec4 want = across / max(s, 1.0);
	float follow = turn_inertia <= dt ? 1.0 : dt / turn_inertia;
	vec4 turn = mix(turn_buf.v[i], want, follow);
	float rate = length(turn);
	if (rate > max_turn_rate) {
		turn *= max_turn_rate / rate;
	}
	h = normalize(h + turn * dt);
	turn -= h * dot(turn, h);
	s = clamp(s + ((cruise - s) * speed_spring + along * 0.35) * dt, min_speed, max_speed);
	p += h * (s * dt);

	vec4 right = vec4(h.z, 0.0, -h.x, 0.0);
	float rl = length(right);
	right = rl > 0.05 ? right / rl : vec4(1.0, 0.0, 0.0, 0.0);
	vec4 up = vec4(-h.x * h.y, 1.0 - h.y * h.y, -h.z * h.y, -h.w * h.y);
	float ul = length(up);
	up = ul > 0.05 ? up / ul : vec4(0.0, 0.0, 1.0, 0.0);
	float bank = mix(m.y, -atan(dot(turn, right) * s / G), min(dt * bank_rate, 1.0));
	vec4 wing = right * cos(bank) + up * sin(bank);

	pos_out.v[i] = p;
	head_out.v[i] = h;
	turn_buf.v[i] = turn;
	misc.v[i] = vec4(s, bank, r, centrality);
	misc2.v[i] = vec4(max(lead_left, 0.0), m2.y, m2.z, float(seen));

	float glide = sin(pc.time * 0.9 + m2.y * TAU);
	float beat = clamp(0.55 + h.y * 3.0 + (cruise - s) * 0.15 + (glide > 0.2 ? 0.35 : -0.45), 0.0, 1.0);
	uint o = i * 20u;
	draw.v[o + 0u] = p.x;
	draw.v[o + 1u] = p.y;
	draw.v[o + 2u] = p.z;
	draw.v[o + 3u] = p.w;
	draw.v[o + 4u] = h.x;
	draw.v[o + 5u] = h.y;
	draw.v[o + 6u] = h.z;
	draw.v[o + 7u] = h.w;
	draw.v[o + 8u] = wing.x;
	draw.v[o + 9u] = wing.y;
	draw.v[o + 10u] = wing.z;
	draw.v[o + 11u] = wing.w;
	draw.v[o + 12u] = m2.z;
	draw.v[o + 13u] = m2.z;
	draw.v[o + 14u] = m2.z;
	draw.v[o + 15u] = 1.0;
	draw.v[o + 16u] = m2.y;
	draw.v[o + 17u] = beat;
	draw.v[o + 18u] = bird_scale;
	draw.v[o + 19u] = 0.0;
}

void reduce_pass(uint t) {
	vec4 sp = vec4(0.0);
	vec4 sh = vec4(0.0);
	// Reads what UPDATE just wrote: after the swap those are this frame's *_out, bound
	// here as *_in by the next frame's set - so REDUCE runs with the other set bound.
	for (uint i = t; i < pc.count; i += 256u) {
		sp += pos_in.v[i];
		sh += head_in.v[i];
	}
	sum_pos[t] = sp;
	sum_head[t] = sh;
	barrier();
	for (uint half_size = 128u; half_size > 0u; half_size >>= 1u) {
		if (t < half_size) {
			sum_pos[t] += sum_pos[t + half_size];
			sum_head[t] += sum_head[t + half_size];
		}
		barrier();
	}
	if (t == 0u) {
		float n = max(float(pc.count), 1.0);
		flock.v[0] = sum_pos[0] / n;
		flock.v[1] = sum_head[0] / n;
	}
}

void main() {
	uint i = gl_GlobalInvocationID.x;
	if (pc.pass_index == 1u) {
		scan_pass(gl_LocalInvocationID.x);
		return;
	}
	if (pc.pass_index == 4u) {
		reduce_pass(gl_LocalInvocationID.x);
		return;
	}
	if (i >= pc.count) {
		return;
	}
	if (pc.pass_index == 0u) {
		count_pass(i);
	} else if (pc.pass_index == 2u) {
		scatter_pass(i);
	} else {
		update_pass(i);
	}
}
