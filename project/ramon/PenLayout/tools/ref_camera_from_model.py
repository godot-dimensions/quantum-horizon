"""Fit only a camera, to picks of points whose places are known (PenLayout/PLAN_REF_LOCK.md step 51).

For a sheet whose views are near-orthographic paintings of one simple building (Trym's cottage),
the building's measured model fixes the points (its corners, its ridge, its door frame) and each
view needs only its camera, so the ref stage can render the model the way the sheet shows it.

    python ref_camera_from_model.py <sheet> <picks.json>
      picks: {"views": {"front": {"yaw_deg": 0, "points": [[[x, y, z], [sheet_u, sheet_v]], ...]}, ...}}
"""
import json
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import reflock_cam as rc  # noqa: E402
from ref_measure import SPECS, sheets  # noqa: E402


def fit(key, picks_path):
	with open(picks_path, encoding="utf-8") as f:
		picks = json.load(f)
	sh = sheets()[key]
	from PIL import Image
	H = Image.open(os.path.join(os.path.dirname(SPECS), "..", "refs", sh["file"])).size[1]
	views = {}
	report = {}
	for name, spec in picks["views"].items():
		x0, x1 = sh["views"][name]
		W = x1 - x0
		P = np.array([p[0] for p in spec["points"]], float)
		uv = np.array([[p[1][0] - x0, p[1][1]] for p in spec["points"]], float)
		yaw = math.radians(float(spec.get("yaw_deg", 0.0)))
		target = P.mean(axis=0)

		def res(q):
			pos = q[0:3]
			uvp, _ = rc.project(P, pos, q[3], q[4], q[5], math.exp(q[6]), W, H)
			r = list((uvp - uv).ravel())
			r.append(q[5] * 300.0)
			return np.array(r)

		best = None
		for dist, f in [(30.0, 6.0), (60.0, 12.0), (120.0, 24.0)]:
			pos = rc.look_from(target, yaw, math.radians(5.0), dist)
			q = np.array([pos[0], pos[1], pos[2], yaw, math.radians(5.0), 0.0, math.log(f)])
			lam = 1e-2
			r = res(q)
			cost = float(r @ r)
			for it in range(400):
				J = np.zeros((len(r), 7))
				for j in range(7):
					h = 1e-5 * max(1.0, abs(q[j]))
					qq = q.copy()
					qq[j] += h
					J[:, j] = (res(qq) - r) / h
				A = J.T @ J
				g = J.T @ r
				ok = False
				for _ in range(10):
					step = np.linalg.solve(A + lam * np.diag(np.diag(A) + 1e-9), -g)
					qq = q + step
					rr = res(qq)
					cc = float(rr @ rr)
					if cc < cost:
						q, r, cost = qq, rr, cc
						lam = max(lam / 3.0, 1e-9)
						ok = True
						break
					lam *= 4.0
				if not ok or np.abs(step).max() < 1e-8:
					break
			if best is None or cost < best[1]:
				best = (q, cost)
		q = best[0]
		uvp, _ = rc.project(P, q[0:3], q[3], q[4], q[5], math.exp(q[6]), W, H)
		err = np.linalg.norm(uvp - uv, axis=1)
		views[name] = rc.preset_view(q[0:3], q[3], q[4], q[5], math.exp(q[6]), W, H)
		report[name] = {"rms_px": round(float(np.sqrt(np.mean(err ** 2))), 2), "worst_px": round(float(err.max()), 1),
			"yaw_deg": round(math.degrees(q[3]), 2), "pitch_deg": round(math.degrees(q[4]), 2), "focal": round(math.exp(q[6]), 2),
			"distance": round(float(np.linalg.norm(q[0:3] - target)), 1)}
	bg = picks.get("background", [45, 47, 58])
	player = picks.get("player")
	rc.write_presets(os.path.join(SPECS, key + "_cameras.json"), views, bg, player=player)
	print(json.dumps(report, indent=1))


if __name__ == "__main__":
	fit(sys.argv[1], sys.argv[2])
