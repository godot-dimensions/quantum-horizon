"""Fit a camera to each view of a reference sheet and place its landmarks in metres, all at once
(PenLayout/PLAN_REF_LOCK.md step 4).

The sheets are paintings, not photographs: each view is drawn on its own and they do not agree
exactly (the Watchstone's ladder sits at a different bearing in each). So this is a least-squares
fit with a soft loss (Huber), each view weighted (the front view is the hero, the side view the
least trusted), and every disagreement left over is printed per point and per view, so it can be
read as "the painting disagrees with itself here" rather than hidden.

Unknowns: per view a pinhole camera (reflock_cam.py: position, yaw, pitch, roll, focal; the
front view's yaw is fixed at 0, which defines north); every landmark's position in metres; each
circle's middle, height and radius, and where on it each rim pick sits. Fixed: the player's feet
at the origin and the top of the cap 1.54 m above them (the chibi avatar, block_avatar_4d.gd),
which sets the scale and the ground.

    python ref_fit.py watchstone      reads RefLock/specs/watchstone_picks.json,
                                      writes watchstone_cameras.json and watchstone_fit.json
"""
import json
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import reflock_cam as rc  # noqa: E402
from ref_measure import SPECS, sheets  # noqa: E402

HUBER = 5.0


class Problem:
	def __init__(self, key):
		with open(os.path.join(SPECS, key + "_picks.json"), encoding="utf-8") as f:
			self.picks = json.load(f)
		self.key = key
		sh = sheets()[self.picks["sheet"]]
		self.sheet = sh
		from PIL import Image
		self.H = Image.open(os.path.join(os.path.dirname(SPECS), "..", "refs", sh["file"])).size[1]
		self.views = list(sh["views"].keys())
		self.panel = {v: sh["views"][v] for v in self.views}
		self.fixed = {k: np.array(p, float) for k, p in self.picks["fixed"].items()}
		self.free = [k for k in self.picks["points"] if k not in self.fixed]
		self.circles = self.picks.get("circles", {})
		self.weights = self.picks.get("weights", {})
		self.lock_yaw = {self.views[0]: 0.0}
		self.layout()

	def layout(self):
		i = 0
		self.idx = {}
		for v in self.views:
			self.idx["cam_" + v] = slice(i, i + 7)
			i += 7
		for k in self.free:
			self.idx["pt_" + k] = slice(i, i + 3)
			i += 3
		for c, spec in self.circles.items():
			self.idx["circle_" + c] = slice(i, i + 4)
			i += 4
			for v in self.views:
				n = len(spec.get(v, []))
				self.idx["ang_%s_%s" % (c, v)] = slice(i, i + n)
				i += n
		self.n = i

	def obs(self, v, xy):
		return np.array([xy[0] - self.panel[v][0], xy[1]], float)

	def size(self, v):
		return self.panel[v][1] - self.panel[v][0], self.H

	def cam(self, p, v):
		c = p[self.idx["cam_" + v]]
		yaw = self.lock_yaw.get(v, c[3])
		return c[0:3], yaw, c[4], c[5], math.exp(c[6])

	def point(self, p, k):
		if k in self.fixed:
			return self.fixed[k]
		return p[self.idx["pt_" + k]]

	def residuals(self, p, robust=True):
		res = []
		self.labels = []
		for k, per in self.picks["points"].items():
			P = self.point(p, k)
			for v, xy in per.items():
				pos, yaw, pitch, roll, f = self.cam(p, v)
				W, H = self.size(v)
				uv, depth = rc.project(P[None, :], pos, yaw, pitch, roll, f, W, H)
				d = (uv[0] - self.obs(v, xy)) * self.weights.get(v, 1.0)
				res.extend(d)
				self.labels += [(k, v, "u"), (k, v, "v")]
		for c, spec in self.circles.items():
			cx, cy, cz, lr = p[self.idx["circle_" + c]]
			r = math.exp(lr)
			for v in self.views:
				pts = spec.get(v, [])
				if not pts:
					continue
				ang = p[self.idx["ang_%s_%s" % (c, v)]]
				lift = spec.get("top_view_lift", 0.0) if v == "top" else 0.0
				P = np.stack([cx + r * np.cos(ang), np.full(len(ang), cy + lift), cz + r * np.sin(ang)], axis=1)
				pos, yaw, pitch, roll, f = self.cam(p, v)
				W, H = self.size(v)
				uv, depth = rc.project(P, pos, yaw, pitch, roll, f, W, H)
				squash = spec.get("v_weight", 1.0) if v != "top" else 1.0
				for j, xy in enumerate(pts):
					d = (uv[j] - self.obs(v, xy)) * self.weights.get(v, 1.0)
					d[1] *= squash
					res.extend(d)
					self.labels += [(c + "%d" % j, v, "u"), (c + "%d" % j, v, "v")]
		# Priors: no roll to speak of.
		for v in self.views:
			res.append(p[self.idx["cam_" + v]][5] * 573.0)
			self.labels.append(("roll", v, "prior"))
		r = np.array(res)
		if robust:
			a = np.abs(r)
			w = np.where(a <= HUBER, 1.0, np.sqrt(HUBER / np.maximum(a, 1e-9)))
			r = r * w
		return r

	def solve(self, p, iters=200):
		lam = 1e-2
		r = self.residuals(p)
		cost = float(r @ r)
		for it in range(iters):
			J = np.zeros((len(r), self.n))
			for j in range(self.n):
				h = 1e-5 * max(1.0, abs(p[j]))
				q = p.copy()
				q[j] += h
				J[:, j] = (self.residuals(q) - r) / h
			A = J.T @ J
			g = J.T @ r
			improved = False
			for _ in range(10):
				step = np.linalg.solve(A + lam * np.diag(np.diag(A) + 1e-9), -g)
				q = p + step
				rq = self.residuals(q)
				cq = float(rq @ rq)
				if cq < cost:
					p, r, cost = q, rq, cq
					lam = max(lam / 3.0, 1e-9)
					improved = True
					break
				lam *= 4.0
			if not improved or np.abs(step).max() < 1e-7:
				break
		return p, cost


def initial(pb):
	p = np.zeros(pb.n)
	pts = pb.picks["points"]
	s_front, s_top, el = 42.0, 37.0, math.radians(15)
	# Pixels a metre, from the player (1.54 m) in the front view, and the top view's from the spread
	# of the points both views share.
	if "PH" in pts and "PF" in pts:
		s_front = (pts["PF"]["front"][1] - pts["PH"]["front"][1]) / 1.54 * math.cos(el)
		shared = [k for k in pts if "front" in pts[k] and "top" in pts[k]]
		if len(shared) >= 3:
			fu = [pts[k]["front"][0] for k in shared]
			tu = [pts[k]["top"][0] for k in shared]
			s_top = s_front * (max(tu) - min(tu)) / max(max(fu) - min(fu), 1.0)
	f_feet = pb.obs("front", pts["PF"]["front"])
	t_feet = pb.obs("top", pts["PF"]["top"]) if "top" in pts["PF"] else None
	guess = {}
	for k in pb.free:
		fu, fv = pb.obs("front", pts[k]["front"])
		x = (fu - f_feet[0]) / s_front
		up = (f_feet[1] - fv) / s_front
		y = up / math.cos(el)
		z = 0.0
		if "top" in pts[k] and t_feet is not None:
			tu, tv = pb.obs("top", pts[k]["top"])
			z = (tv - t_feet[1]) / s_top + y * 0.45
			y = (up + z * math.sin(el)) / math.cos(el)
		guess[k] = np.array([x, max(y, 0.0), z])
		p[pb.idx["pt_" + k]] = guess[k]
	centre = np.mean(list(guess.values()), axis=0) if guess else np.array([0.0, 5.0, -5.0])
	for c, spec in pb.circles.items():
		fr = np.array([pb.obs("front", q) for q in spec["front"]])
		cx = (fr[:, 0].mean() - f_feet[0]) / s_front
		r = (fr[:, 0].max() - fr[:, 0].min()) / 2.0 / s_front
		cy = (f_feet[1] - fr[:, 1].mean()) / s_front / math.cos(el)
		cz = -8.0
		if "top" in spec:
			tp = np.array([pb.obs("top", q) for q in spec["top"]])
			cz = (tp[:, 1].mean() - t_feet[1]) / s_top + cy * 0.45
		p[pb.idx["circle_" + c]] = [cx, cy, cz, math.log(r)]
		for v in pb.views:
			obs = spec.get(v, [])
			if not obs:
				continue
			o = np.array([pb.obs(v, q) for q in obs])
			mid = o.mean(axis=0)
			ang = []
			for q in o:
				dx, dy = q - mid
				if v == "front":
					a = math.atan2(dy * 4.0, dx)
				elif v == "right":
					a = math.atan2(-dx, -dy * 4.0)
				else:
					a = math.atan2(dy, dx)
				ang.append(a)
			p[pb.idx["ang_%s_%s" % (c, v)]] = ang
	# Far away on long lenses: the player (in front) is only about 13% bigger, metre for metre, than
	# the plateau (behind), which puts the camera some 80 m off.
	for v, (yaw, pitch, f, D) in {"front": (0.0, 15.0, 8.0, 80.0), "right": (90.0, 15.0, 8.0, 80.0), "top": (0.0, 62.0, 6.0, 70.0)}.items():
		if v not in pb.views:
			continue
		target = centre + np.array([0.0, 0.0, 0.0])
		pos = rc.look_from(target, math.radians(yaw), math.radians(pitch), D)
		p[pb.idx["cam_" + v]] = [pos[0], pos[1], pos[2], math.radians(yaw), math.radians(pitch), 0.0, math.log(f)]
	return p


def report(pb, p):
	r = pb.residuals(p, robust=False)
	labels = pb.labels
	per_view = {}
	per_point = {}
	for (k, v, axis), val in zip(labels, r):
		if axis == "prior":
			continue
		wv = pb.weights.get(v, 1.0)
		px = val / wv
		per_view.setdefault(v, []).append(px * px)
		per_point.setdefault((k, v), []).append(px)
	out = {"rms_px": {v: round(math.sqrt(np.mean(e)), 2) for v, e in per_view.items()}, "points": {}, "cameras": {}, "worst": []}
	for (k, v), e in per_point.items():
		d = math.hypot(*e) if len(e) == 2 else 0.0
		out["worst"].append([round(d, 1), k, v])
	out["worst"].sort(reverse=True)
	out["worst"] = out["worst"][:12]
	for k in pb.picks["points"]:
		out["points"][k] = [round(float(c), 3) for c in pb.point(p, k)]
	for c in pb.circles:
		cx, cy, cz, lr = p[pb.idx["circle_" + c]]
		out["circle_" + c] = {"centre": [round(cx, 3), round(cy, 3), round(cz, 3)], "radius": round(math.exp(lr), 3)}
	for v in pb.views:
		pos, yaw, pitch, roll, f = pb.cam(p, v)
		out["cameras"][v] = {"position": [round(float(c), 2) for c in pos], "yaw_deg": round(math.degrees(yaw), 2),
			"pitch_deg": round(math.degrees(pitch), 2), "roll_deg": round(math.degrees(roll), 2), "focal": round(f, 3),
			"fov_deg": round(math.degrees(2 * math.atan(1 / f)), 2)}
	return out


def main(key):
	pb = Problem(key)
	p = initial(pb)
	p, cost = pb.solve(p)
	rep = report(pb, p)
	# Re-centre on the plateau's middle at the ground (the unit's origin); the player keeps its place
	# relative to everything.
	origin = np.zeros(3)
	if "circle_rim" in rep:
		c = rep["circle_rim"]["centre"]
		origin = np.array([c[0], 0.0, c[2]])
	shifted = {k: [round(float(a - b), 3) for a, b in zip(v, origin)] for k, v in rep["points"].items()}
	rep["origin_in_fit"] = [round(float(c), 3) for c in origin]
	rep["points_from_origin"] = shifted
	if "circle_rim" in rep:
		c = rep["circle_rim"]["centre"]
		rep["circle_rim"]["centre_from_origin"] = [0.0, c[1], 0.0]
	views = {}
	for v in pb.views:
		pos, yaw, pitch, roll, f = pb.cam(p, v)
		W, H = pb.size(v)
		views[v] = rc.preset_view(np.asarray(pos) - origin, yaw, pitch, roll, f, W, H)
	bg = [52, 55, 61]
	player = list(-origin) + [0.0]
	markers = {k: v for k, v in shifted.items()}
	rc.write_presets(os.path.join(SPECS, key + "_cameras.json"), views, bg, player=player, markers=markers)
	with open(os.path.join(SPECS, key + "_fit.json"), "w", encoding="utf-8", newline="\n") as f:
		json.dump(rep, f, indent=1)
	print(json.dumps({k: rep[k] for k in ("rms_px", "cameras", "worst")}, indent=1))
	print("points from origin:")
	for k, v in shifted.items():
		print("  %-12s %s" % (k, v))
	if "circle_rim" in rep:
		print("  rim", rep["circle_rim"])
	print("cost", cost)


if __name__ == "__main__":
	main(sys.argv[1] if len(sys.argv) > 1 else "watchstone")


def overlay(key, out_path):
	"""The sheet with every pick (green) and where the fit puts it (red), and each fitted circle."""
	from PIL import Image, ImageDraw
	pb = Problem(key)
	with open(os.path.join(SPECS, key + "_cameras.json"), encoding="utf-8") as f:
		cams = json.load(f)
	with open(os.path.join(SPECS, key + "_fit.json"), encoding="utf-8") as f:
		fit = json.load(f)
	img = Image.open(os.path.join(os.path.dirname(SPECS), "..", "refs", pb.sheet["file"])).convert("RGB")
	d = ImageDraw.Draw(img)
	pts = fit["points_from_origin"]
	for v in pb.views:
		c = cams["views"][v]
		x0 = pb.panel[v][0]
		proj = lambda P: rc.project(np.asarray(P, float).reshape(-1, 3), c["position"], c["yaw"], c["pitch"], c["roll"], c["focal"], c["width"], c["height"])[0]
		for k, per in pb.picks["points"].items():
			if v not in per:
				continue
			ox, oy = per[v]
			u, w = proj(pts[k])[0]
			d.line((ox, oy, u + x0, w), fill=(255, 60, 60), width=2)
			d.ellipse((ox - 4, oy - 4, ox + 4, oy + 4), outline=(60, 255, 60), width=2)
			d.ellipse((u + x0 - 3, w - 3, u + x0 + 3, w + 3), fill=(255, 60, 60))
			d.text((ox + 6, oy - 12), k, fill=(255, 255, 255))
		for cname, spec in pb.circles.items():
			ci = fit["circle_" + cname]
			cy = ci["centre_from_origin"][1] + (spec.get("top_view_lift", 0.0) if v == "top" else 0.0)
			ring = [[ci["radius"] * math.cos(a), cy, ci["radius"] * math.sin(a)] for a in np.linspace(0, 2 * math.pi, 73)]
			uv = proj(ring)
			d.line([(u + x0, w) for u, w in uv], fill=(255, 60, 60), width=2)
			for q in spec.get(v, []):
				d.ellipse((q[0] - 3, q[1] - 3, q[0] + 3, q[1] + 3), outline=(60, 255, 60), width=2)
	img.save(out_path)


def triangulate(key, picks):
	"""Places extra picks in metres with the fitted cameras held: each a dict view -> sheet pixel.
	Returns {name: ([x, y, z] from the unit origin, rms px)}."""
	with open(os.path.join(SPECS, key + "_cameras.json"), encoding="utf-8") as f:
		cams = json.load(f)
	sh = sheets()[key]
	out = {}
	for name, per in picks.items():
		def res(P):
			r = []
			for v, xy in per.items():
				c = cams["views"][v]
				uv, _ = rc.project(np.asarray(P)[None, :], c["position"], c["yaw"], c["pitch"], c["roll"], c["focal"], c["width"], c["height"])
				r.extend(uv[0] - np.array([xy[0] - sh["views"][v][0], xy[1]]))
			return np.array(r)
		P = np.array([0.0, 5.0, 0.0])
		for _ in range(60):
			r = res(P)
			J = np.zeros((len(r), 3))
			for j in range(3):
				q = P.copy()
				q[j] += 1e-4
				J[:, j] = (res(q) - r) / 1e-4
			step = np.linalg.lstsq(J, -r, rcond=None)[0]
			P = P + step
			if np.abs(step).max() < 1e-6:
				break
		r = res(P)
		out[name] = ([round(float(c), 2) for c in P], round(float(np.sqrt(np.mean(r * r))), 1))
	return out


def plane_point(key, view, sheet_xy, axis, value):
	"""The point where the ray through [param sheet_xy] (sheet pixels) of [param view] meets the plane
	coordinate [param axis] (0 x, 1 y, 2 z) = [param value], in metres from the unit origin."""
	with open(os.path.join(SPECS, key + "_cameras.json"), encoding="utf-8") as f:
		cams = json.load(f)
	sh = sheets()[key]
	c = cams["views"][view]
	F = c["focal"] * c["height"] / 2
	x, y, z = rc.axes(c["yaw"], c["pitch"], c["roll"])
	pos = np.array(c["position"])
	u = sheet_xy[0] - sh["views"][view][0]
	d = (u - c["width"] / 2) / F * x + (c["height"] / 2 - sheet_xy[1]) / F * y - z
	t = (value - pos[axis]) / d[axis]
	return [round(float(v), 2) for v in pos + t * d]
