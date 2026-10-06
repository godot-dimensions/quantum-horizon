"""Measure a reference sheet, or a render of the build, the same way (PenLayout/PLAN_REF_LOCK.md step 2).

Ramon's sheets sit on a flat dark-grey background that darkens a little toward the bottom. Each
view is cut out of it (a vertical gradient fitted to the panel's border pixels, then everything
more than a threshold away from it), split into materials by colour (sheets.json, HSV ranges tried
in order), and summed up: the outline's width at every height, each material's share and mean
colour. Renders from the ref stage (PenLayout/RefLock/ref_stage_runner.gd) sit on a plain sky in
the same grey and go through the same functions, so the two compare like for like.

    python ref_measure.py watchstone          writes refs/measure/watchstone_*.png and .json

No scipy on this machine: the little morphology needed is done with numpy shifts.
"""
import colorsys
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
REFS = os.path.normpath(os.path.join(HERE, "..", "refs"))
SPECS = os.path.normpath(os.path.join(HERE, "..", "RefLock", "specs"))
OUT = os.path.join(REFS, "measure")

# The colour each material is drawn in on a class map.
SHOW = {"bg": (0, 0, 0), "other": (70, 70, 74), "rock": (205, 205, 210), "stone": (205, 205, 210),
	"grass": (110, 190, 40), "timber": (205, 120, 50), "glow": (255, 230, 60), "maroon": (150, 30, 50),
	"canvas": (240, 230, 200), "plaster": (230, 200, 150), "sand": (230, 170, 90)}


def sheets():
	with open(os.path.join(SPECS, "sheets.json"), encoding="utf-8") as f:
		return json.load(f)


def load_view(key, view):
	"""The view's panel as an RGB array (float 0-255), and its x offset in the sheet."""
	s = sheets()[key]
	img = np.asarray(Image.open(os.path.join(REFS, s["file"])).convert("RGB")).astype(float)
	x0, x1 = s["views"][view]
	return img[:, x0:x1].copy(), x0


def background(img, label_bottom=0):
	"""The background colour on every row: a straight-line fit in y to the panel's border pixels
	(left and right six columns, and the label band's empty rows), refitted without outliers."""
	H, W, _ = img.shape
	ys, cols = [], []
	for x in list(range(0, 6)) + list(range(W - 6, W)):
		ys.append(np.arange(H))
		cols.append(img[:, x])
	if label_bottom > 0:
		for y in range(0, label_bottom, 3):
			ys.append(np.full(W, y))
			cols.append(img[y])
	y = np.concatenate(ys).astype(float)
	c = np.concatenate(cols)
	keep = np.ones(len(y), bool)
	for _ in range(4):
		A = np.stack([y[keep], np.ones(keep.sum())], axis=1)
		coef, *_ = np.linalg.lstsq(A, c[keep], rcond=None)
		pred = np.stack([y, np.ones(len(y))], axis=1) @ coef
		err = np.abs(c - pred).sum(axis=1)
		keep = err < max(12.0, np.percentile(err[keep], 60) * 2.5)
	rows = np.stack([np.arange(H, dtype=float), np.ones(H)], axis=1) @ coef
	return rows  # H x 3


def _shift(m, dy, dx):
	out = np.zeros_like(m)
	H, W = m.shape
	ys = slice(max(dy, 0), H + min(dy, 0))
	yd = slice(max(-dy, 0), H + min(-dy, 0))
	xs = slice(max(dx, 0), W + min(dx, 0))
	xd = slice(max(-dx, 0), W + min(-dx, 0))
	out[ys, xs] = m[yd, xd]
	return out


def erode(m, r=1):
	out = m.copy()
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			out &= _shift(m, dy, dx)
	return out


def dilate(m, r=1):
	out = m.copy()
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			out |= _shift(m, dy, dx)
	return out


def foreground(img, bg_rows, label_bottom=0, threshold=40.0):
	d = np.abs(img - bg_rows[:, None, :]).sum(axis=2)
	m = d > threshold
	m[:label_bottom] = False
	# Open (drop specks and the antialiased fringe), then close small holes.
	m = dilate(erode(m, 1), 1)
	m = erode(dilate(m, 2), 2)
	return m


def hsv(img):
	a = np.asarray(Image.fromarray(np.uint8(np.clip(img, 0, 255))).convert("HSV")).astype(float)
	return a[..., 0] * 360.0 / 255.0, a[..., 1] / 255.0, a[..., 2] / 255.0


def classify(img, fg, classes):
	"""A map of material indices: 0 background, 1..n the classes in order, n+1 'other'."""
	h, s, v = hsv(img)
	out = np.zeros(fg.shape, np.int32)
	free = fg.copy()
	for i, (name, hr, sr, vr) in enumerate(classes):
		lo, hi = hr
		hue = (h >= lo) & (h <= hi)
		if hi > 360:  # a hue range that wraps past red
			hue = hue | (h <= hi - 360)
		m = free & hue & (s >= sr[0]) & (s <= sr[1]) & (v >= vr[0]) & (v <= vr[1])
		out[m] = i + 1
		free &= ~m
	out[free] = len(classes) + 1
	return out


def names(classes):
	return ["bg"] + [c[0] for c in classes] + ["other"]


def profile(fg):
	"""Per row: (x_min, x_max), or (-1, -1) where the row is empty."""
	H, W = fg.shape
	out = np.full((H, 2), -1, int)
	any_ = fg.any(axis=1)
	xs = np.arange(W)
	for y in np.nonzero(any_)[0]:
		row = xs[fg[y]]
		out[y] = (row.min(), row.max())
	return out


def stats(img, cmap, classes):
	n = names(classes)
	fg = cmap > 0
	total = max(int(fg.sum()), 1)
	res = {}
	for i, name in enumerate(n):
		if i == 0:
			continue
		m = cmap == i
		cnt = int(m.sum())
		mean = img[m].mean(axis=0) if cnt else np.zeros(3)
		res[name] = {"share": round(cnt / total, 4), "mean": [int(round(c)) for c in mean]}
	ys, xs = np.nonzero(fg)
	res["_box"] = [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())] if len(xs) else None
	return res


def class_image(cmap, classes):
	n = names(classes)
	out = np.zeros(cmap.shape + (3,), np.uint8)
	for i, name in enumerate(n):
		out[cmap == i] = SHOW.get(name, (255, 0, 255))
	return out


def measure_view(key, view):
	s = sheets()[key]
	img, x0 = load_view(key, view)
	bg = background(img, s["label_bottom"])
	fg = foreground(img, bg, s["label_bottom"])
	cmap = classify(img, fg, s["classes"])
	return img, bg, fg, cmap


def measure_render(path, classes, bg_rgb, threshold=30.0):
	"""The same for a render on a plain background of colour bg_rgb."""
	img = np.asarray(Image.open(path).convert("RGB")).astype(float)
	bg = np.tile(np.asarray(bg_rgb, float), (img.shape[0], 1))
	fg = foreground(img, bg, 0, threshold)
	cmap = classify(img, fg, classes)
	return img, bg, fg, cmap


def _font(size, bold=False):
	try:
		return ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf" if bold else "C:/Windows/Fonts/segoeui.ttf", size)
	except OSError:
		return ImageFont.load_default()


def main(key):
	os.makedirs(OUT, exist_ok=True)
	s = sheets()[key]
	report = {}
	tiles = []
	for view in s["views"]:
		img, bg, fg, cmap = measure_view(key, view)
		st = stats(img, cmap, s["classes"])
		prof = profile(fg)
		st["profile_every_10px"] = [[int(y), int(prof[y][0]), int(prof[y][1])] for y in range(0, len(prof), 10) if prof[y][0] >= 0]
		report[view] = st
		ci = class_image(cmap, s["classes"])
		Image.fromarray(ci).save(os.path.join(OUT, "%s_%s_class.png" % (key, view)))
		tiles.append((view, np.uint8(np.clip(img, 0, 255)), ci, st))
	with open(os.path.join(OUT, "%s_measure.json" % key), "w", encoding="utf-8", newline="\n") as f:
		json.dump(report, f, indent=1)
	# A sheet: each view over its class map, with the shares.
	W = sum(t[1].shape[1] for t in tiles) + 10 * (len(tiles) - 1)
	H = tiles[0][1].shape[0]
	sheet = Image.new("RGB", (W, H * 2 + 70), (24, 26, 31))
	d = ImageDraw.Draw(sheet)
	x = 0
	for view, im, ci, st in tiles:
		sheet.paste(Image.fromarray(im), (x, 0))
		sheet.paste(Image.fromarray(ci), (x, H + 70))
		line = "  ".join("%s %d%%" % (k, round(v["share"] * 100)) for k, v in st.items() if not k.startswith("_") and k not in ("profile_every_10px",) and v["share"] >= 0.01)
		d.text((x + 8, H + 8), view.upper(), font=_font(22, True), fill=(255, 255, 255))
		d.text((x + 8, H + 38), line, font=_font(18), fill=(230, 230, 235))
		x += im.shape[1] + 10
	sheet.save(os.path.join(OUT, "%s_measure.png" % key))
	print(json.dumps({v: {k: r[k] for k in r if k != "profile_every_10px"} for v, r in report.items()}, indent=1))


if __name__ == "__main__":
	for k in (sys.argv[1:] or list(sheets().keys())):
		if not k.startswith("_"):
			print("==", k)
			main(k)
