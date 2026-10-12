"""Fit a sheet whose top view is a painted map rather than a camera view (PenLayout/PLAN_REF_LOCK.md
step 42; the camp sheet).

The camp's top view is drawn like a map: the ground round, the tents and props leaning up the
page by their height, and its foreshortening not the front view's (a camera fitted to both put the
camp's back 20 m away). So here the front view is a pinhole camera (reflock_cam.py) and the top
view an affine map of the ground with a lean for height:

    u = a x + r z + c          v = b z + q x + d - e y

with its own a, b, r, q, c, d, e. Every landmark's position is solved in metres from both: the
front view decides heights and the camera, the top view the plan. The player is in a different
place in each view (the painter moved him), so he is used in the front view only, for the scale
(1.54 m, the chibi avatar); the origin is the fire ring's middle on the ground.

    python ref_fit_plan.py camp     reads RefLock/specs/camp_picks.json, writes camp_cameras.json
                                    (the front camera, and the top map for the ref stage's top
                                    render: a straight-down orthographic camera over the plan)
"""
import json
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import reflock_cam as rc  # noqa: E402
from ref_measure import SPECS, sheets  # noqa: E402

HUBER = 4.0


def solve(key):
	with open(os.path.join(SPECS, key + "_picks.json"), encoding="utf-8") as f:
		picks = json.load(f)
	sh = sheets()[picks["sheet"]]
	from PIL import Image
	H = Image.open(os.path.join(os.path.dirname(SPECS), "..", "refs", sh["file"])).size[1]
	fx0, fx1 = sh["views"]["front"]
	tx0, tx1 = sh["views"]["top"]
	W_front = fx1 - fx0
	pts = picks["points"]
	names = [k for k in pts if k not in ("PH", "PF")]
	origin = picks.get("origin", "fire")
	free = [k for k in names if k != origin]
	known_y = picks.get("known_y", {})
	# Unknowns: front camera (pos 3, pitch, roll, log f; yaw fixed 0), top map (a, b, r, q, c, d, e),
	# the player's ground (x, z), each free point (x, y, z), the origin's y.
	n = 6 + 7 + 2 + 3 * len(free) + 1
	idx = {}
	i = 0
	for nm, size in [("cam", 6), ("map", 7), ("player", 2)]:
		idx[nm] = slice(i, i + size)
		i += size
	for k in free:
		idx[k] = slice(i, i + 3)
		i += 3
	idx["origin_y"] = slice(i, i + 1)

	def point(p, k):
		if k == origin:
			return np.array([0.0, p[idx["origin_y"]][0], 0.0])
		return p[idx[k]]

	def front(p, P):
		c = p[idx["cam"]]
		uv, _ = rc.project(np.asarray(P)[None, :], c[0:3], 0.0, c[3], c[4], math.exp(c[5]), W_front, H)
		return uv[0]

	def top(p, P):
		a, b, r, q, cc, d, e = p[idx["map"]]
		return np.array([a * P[0] + r * P[2] + cc, b * P[2] + q * P[0] + d - e * P[1]])

	def residuals(p, robust=True):
		res = []
		for k in names:
			P = point(p, k)
			if "front" in pts[k]:
				res.extend(front(p, P) - np.array([pts[k]["front"][0] - fx0, pts[k]["front"][1]]))
			if "top" in pts[k]:
				res.extend((top(p, P) - np.array([pts[k]["top"][0] - tx0, pts[k]["top"][1]])) * 0.8)
		px, pz = p[idx["player"]]
		res.extend(front(p, [px, 0.0, pz]) - np.array([pts["PF"]["front"][0] - fx0, pts["PF"]["front"][1]]))
		res.extend(front(p, [px, 1.54, pz]) - np.array([pts["PH"]["front"][0] - fx0, pts["PH"]["front"][1]]))
		for k, y in known_y.items():
			res.append((point(p, k)[1] - float(y)) * 100.0)
		for group in picks.get("equal_y", []):
			ys = [point(p, k)[1] for k in group]
			m = sum(ys) / len(ys)
			res.extend([(y - m) * 100.0 for y in ys])
		c = p[idx["cam"]]
		res.append(c[4] * 573.0)
		mp = p[idx["map"]]
		# The map's x and z scales alike within reason, and little shear.
		res.append((mp[0] - mp[1]) * 0.5)
		res.append(mp[2] * 2.0)
		res.append(mp[3] * 2.0)
		r = np.array(res)
		if robust:
			a_ = np.abs(r)
			r = r * np.where(a_ <= HUBER, 1.0, np.sqrt(HUBER / np.maximum(a_, 1e-9)))
		return r

	p = np.zeros(n)
	# Starts: the camera 14 m south and 5 m up, looking down 15 degrees; the map 40 px a metre with
	# the fire where it is drawn.
	fire_top = pts[origin]["top"]
	best = None
	for dist, f in [(14.0, 3.0), (20.0, 4.5), (30.0, 6.5)]:
		p = np.zeros(n)
		pos = rc.look_from([0, 1.0, 0], 0.0, math.radians(14.0), dist)
		p[idx["cam"]] = [pos[0], pos[1], pos[2], math.radians(14.0), 0.0, math.log(f)]
		p[idx["map"]] = [40.0, 40.0, 0.0, 0.0, fire_top[0] - tx0, fire_top[1], 25.0]
		p[idx["player"]] = [0.0, 3.0]
		for k in free:
			t = pts[k].get("top")
			if t:
				p[idx[k]] = [(t[0] - fire_top[0]) / 40.0, 1.0, (t[1] - fire_top[1]) / 40.0]
		lam = 1e-2
		r = residuals(p)
		cost = float(r @ r)
		for it in range(300):
			J = np.zeros((len(r), n))
			for j in range(n):
				h = 1e-5 * max(1.0, abs(p[j]))
				q = p.copy()
				q[j] += h
				J[:, j] = (residuals(q) - r) / h
			A = J.T @ J
			g = J.T @ r
			ok = False
			for _ in range(10):
				step = np.linalg.solve(A + lam * np.diag(np.diag(A) + 1e-9), -g)
				q = p + step
				rq = residuals(q)
				cq = float(rq @ rq)
				if cq < cost:
					p, r, cost = q, rq, cq
					lam = max(lam / 3.0, 1e-9)
					ok = True
					break
				lam *= 4.0
			if not ok or np.abs(step).max() < 1e-7:
				break
		if best is None or cost < best[1]:
			best = (p.copy(), cost)
	p = best[0]
	# Report.
	out = {"points": {}, "player": [round(float(v), 3) for v in p[idx["player"]]]}
	err_f, err_t = [], []
	for k in names:
		P = point(p, k)
		out["points"][k] = [round(float(v), 3) for v in P]
		if "front" in pts[k]:
			err_f.append(np.linalg.norm(front(p, P) - np.array([pts[k]["front"][0] - fx0, pts[k]["front"][1]])))
		if "top" in pts[k]:
			err_t.append(np.linalg.norm(top(p, P) - np.array([pts[k]["top"][0] - tx0, pts[k]["top"][1]])))
	c = p[idx["cam"]]
	out["front_camera"] = {"position": [round(float(v), 3) for v in c[0:3]], "pitch_deg": round(math.degrees(c[3]), 2),
		"roll_deg": round(math.degrees(c[4]), 2), "focal": round(math.exp(c[5]), 3)}
	out["top_map"] = [round(float(v), 4) for v in p[idx["map"]]]
	out["rms_px"] = {"front": round(float(np.sqrt(np.mean(np.square(err_f)))), 2), "top": round(float(np.sqrt(np.mean(np.square(err_t)))), 2)}
	with open(os.path.join(SPECS, key + "_fit.json"), "w", encoding="utf-8", newline="\n") as f:
		json.dump(out, f, indent=1)
	# Presets: the front camera as fitted; the top as a camera looking straight down the map's
	# lean (so a render lines up with the drawing as well as one camera can).
	views = {"front": rc.preset_view(c[0:3], 0.0, c[3], c[4], math.exp(c[5]), W_front, H)}
	a, b, r_, q, cc, d, e = p[idx["map"]]
	# An orthographic look along (0, -b', e') approximated by a far pinhole: pitch from the lean.
	pitch = math.atan2(abs(b), abs(e)) if abs(e) > 1e-6 else math.pi / 2
	scale = (abs(a) + abs(b) / max(math.sin(pitch), 1e-3)) * 0.5
	dist = 200.0
	f_top = scale * dist / (H / 2.0)
	# The centre of the drawing's ground, from the map: where the panel's middle falls.
	u_mid = (tx1 - tx0) / 2.0
	v_mid = H / 2.0
	x_mid = (u_mid - cc) / a
	z_mid = (v_mid - d) / (b * 1.0) if abs(b) > 1e-6 else 0.0
	target = [x_mid, 0.0, z_mid]
	pos = rc.look_from(target, 0.0, pitch, dist)
	views["top"] = rc.preset_view(pos, 0.0, pitch, 0.0, f_top, tx1 - tx0, H)
	player = [float(v) for v in [p[idx["player"]][0], 0.0, p[idx["player"]][1], 0.0]]
	rc.write_presets(os.path.join(SPECS, key + "_cameras.json"), views, [44, 47, 56], player=player, markers=out["points"])
	print(json.dumps({k: out[k] for k in ("rms_px", "front_camera", "top_map", "player")}, indent=1))
	for k, v in out["points"].items():
		print("  %-14s %s" % (k, v))


if __name__ == "__main__":
	solve(sys.argv[1] if len(sys.argv) > 1 else "camp")
