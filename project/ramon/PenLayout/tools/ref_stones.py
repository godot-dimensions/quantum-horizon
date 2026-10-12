"""Count and size the painted stones in a view (PenLayout/PLAN_REF_LOCK.md step 11).

The rock pixels (ref_measure.py's split) are pulled apart along their dark joints (an erosion),
labelled into connected pieces, and each piece's box is turned into metres with the fitted
camera at the crag's face. Pieces that are too small are chips of a stone cut by grass, and are
dropped. What remains is a count and a size spread per band of height: the case study's numbers.
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ref_measure as rm  # noqa: E402
import reflock_cam as rc  # noqa: E402


def label(mask):
	H, W = mask.shape
	lab = np.zeros((H, W), np.int32)
	n = 0
	sizes = []
	for y0 in range(H):
		row = mask[y0]
		for x0 in np.nonzero(row & (lab[y0] == 0))[0]:
			if lab[y0, x0]:
				continue
			n += 1
			stack = [(y0, x0)]
			lab[y0, x0] = n
			cnt = 0
			while stack:
				y, x = stack.pop()
				cnt += 1
				for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
					yy, xx = y + dy, x + dx
					if 0 <= yy < H and 0 <= xx < W and mask[yy, xx] and not lab[yy, xx]:
						lab[yy, xx] = n
						stack.append((yy, xx))
			sizes.append(cnt)
	return lab, sizes


def stones(key, view, cams_key, rock_class="rock", erode=2, min_px=250):
	s = rm.sheets()[key]
	img, bg, fg, cmap = rm.measure_view(key, view)
	names = rm.names(s["classes"])
	rock = cmap == names.index(rock_class)
	# Light rock only: the joints between stones are darker grey, which the split calls "other".
	m = rm.erode(rock, erode)
	lab, sizes = label(m)
	with open(os.path.join(rm.SPECS, cams_key + "_cameras.json"), encoding="utf-8") as f:
		cams = json.load(f)
	c = cams["views"][view]
	F = c["focal"] * c["height"] / 2
	cx, cy, cz = rc.axes(c["yaw"], c["pitch"], c["roll"])
	pos = np.array(c["position"])
	out = []
	for i, cnt in enumerate(sizes):
		if cnt < min_px:
			continue
		ys, xs = np.nonzero(lab == i + 1)
		u0, u1, v0, v1 = xs.min() - erode, xs.max() + erode, ys.min() - erode, ys.max() + erode
		# Metres per pixel at the stone: its depth along the view, taken on the plane through the
		# crag's middle facing the camera.
		um, vm = (u0 + u1) / 2, (v0 + v1) / 2
		d = (um - c["width"] / 2) / F * cx + (c["height"] / 2 - vm) / F * cy - cz
		t = -np.dot(pos, -cz) / np.dot(d, -cz)
		P = pos + t * d
		depth = np.dot(P - pos, -cz)
		mpp = depth / F
		out.append({"box": [int(u0), int(v0), int(u1), int(v1)], "w": round((u1 - u0) * mpp, 2), "h": round((v1 - v0) * mpp, 2),
			"y": round(float(P[1]), 2), "x": round(float(P[0]), 2), "px": int(cnt)})
	return img, out


if __name__ == "__main__":
	key, view = sys.argv[1], sys.argv[2]
	img, out = stones(key, view, key)
	out.sort(key=lambda o: o["y"])
	im = Image.fromarray(np.uint8(np.clip(img, 0, 255)))
	d = ImageDraw.Draw(im)
	for o in out:
		d.rectangle(o["box"], outline=(255, 0, 255), width=2)
		d.text((o["box"][0] + 3, o["box"][1] + 2), "%.1fx%.1f" % (o["w"], o["h"]), fill=(255, 255, 0))
	path = os.path.join(rm.OUT, "%s_%s_stones.png" % (key, view))
	im.save(path)
	with open(os.path.join(rm.OUT, "%s_%s_stones.json" % (key, view)), "w", encoding="utf-8", newline="\n") as f:
		json.dump(out, f, indent=1)
	print(len(out), "stones ->", path)
	for o in out:
		print("  y %5.1f  x %5.1f   %.2f wide x %.2f tall  (%d px)" % (o["y"], o["x"], o["w"], o["h"], o["px"]))
