"""Lay a ref-stage render over the painted view it copies, and score it (PenLayout/PLAN_REF_LOCK.md
steps 6, 8 and 9).

The render comes from ref_stage_runner.gd with the camera ref_fit.py fitted to that view, at the
panel's pixel size, on a plain sky. Both images go through ref_measure.py's cut-out and material
split, then:

- silhouette overlap (IoU: the shared area over the combined area) and how much of the painting
  the build covers and how much it adds;
- the same per material (rock, grass, timber, ...), where the build has them;
- each material's mean colour and the difference from the painting's (a plain RGB distance, out
  of 441);
- width error per band of height (the outline, row by row).

The sheet shows the painting | the build | a 50% mix | the difference (red: painting only, blue:
build only, white: both), with the numbers and the gate verdicts. Each run is numbered into
refs/progress/ so the history is kept.

    python ref_compare.py <sheet> <view> <render.png> <label> [--bg r,g,b]
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ref_measure as rm  # noqa: E402

PROGRESS = os.path.join(rm.REFS, "progress")
# The gates (PLAN_REF_LOCK.md section 3, point 7).
GATE_IOU = 0.85
GATE_COLOUR = 40.0


def iou(a, b):
	inter = (a & b).sum()
	union = (a | b).sum()
	return float(inter) / max(float(union), 1.0)


def compare(key, view, render_path, label, bg=(52, 55, 61), save=True, ignore=()):
	"""[param ignore]: materials of the painting left out of the score (for a rocks-only study,
	the timber: where the painting has timber, neither image counts)."""
	s = rm.sheets()[key]
	classes = s["classes"]
	ref_img, ref_bg, ref_fg, ref_c = rm.measure_view(key, view)
	ren_img, ren_bg, ren_fg, ren_c = rm.measure_render(render_path, classes, bg)
	if ren_img.shape != ref_img.shape:
		raise SystemExit("render %s is %s, the view is %s" % (render_path, ren_img.shape, ref_img.shape))
	names = rm.names(classes)
	if ignore:
		skip = np.zeros(ref_fg.shape, bool)
		for n in ignore:
			skip |= ref_c == names.index(n)
		skip = rm.dilate(skip, 2)
		ref_fg = ref_fg & ~skip
		ren_fg = ren_fg & ~skip
		ref_c = np.where(skip, 0, ref_c)
		ren_c = np.where(skip, 0, ren_c)
	res = {"sheet": key, "view": view, "label": label, "render": render_path}
	res["iou"] = round(iou(ref_fg, ren_fg), 4)
	res["painting_covered"] = round(float((ref_fg & ren_fg).sum()) / max(float(ref_fg.sum()), 1.0), 4)
	res["build_extra"] = round(float((ren_fg & ~ref_fg).sum()) / max(float(ren_fg.sum()), 1.0), 4)
	per = {}
	for i, n in enumerate(names):
		if n in ("bg", "other"):
			continue
		a = ref_c == i
		b = ren_c == i
		if a.sum() < 50 and b.sum() < 50:
			continue
		ca = ref_img[a].mean(axis=0) if a.sum() else np.zeros(3)
		cb = ren_img[b].mean(axis=0) if b.sum() else np.zeros(3)
		per[n] = {"iou": round(iou(a, b), 4), "ref_share": round(float(a.sum()) / max(float(ref_fg.sum()), 1.0), 4),
			"build_share": round(float(b.sum()) / max(float(ren_fg.sum()), 1.0), 4),
			"ref_colour": [int(c) for c in ca], "build_colour": [int(c) for c in cb],
			"colour_diff": round(float(np.linalg.norm(ca - cb)), 1) if b.sum() else None}
	res["materials"] = per
	# Width per band of 40 px of height.
	pa, pb = rm.profile(ref_fg), rm.profile(ren_fg)
	bands = []
	H = ref_fg.shape[0]
	for y0 in range(0, H, 40):
		ys = range(y0, min(y0 + 40, H))
		wa = [pa[y][1] - pa[y][0] for y in ys if pa[y][0] >= 0]
		wb = [pb[y][1] - pb[y][0] for y in ys if pb[y][0] >= 0]
		if wa or wb:
			bands.append([y0, int(np.mean(wa)) if wa else 0, int(np.mean(wb)) if wb else 0])
	res["width_bands"] = bands
	res["gates"] = {"silhouette": res["iou"] >= GATE_IOU,
		"colour": all((v["colour_diff"] is not None and v["colour_diff"] <= GATE_COLOUR) for v in per.values() if v["ref_share"] > 0.05)}
	if save:
		_sheet(res, ref_img, ren_img, ref_fg, ren_fg, ref_c, ren_c, classes)
	return res


def _next_number():
	os.makedirs(PROGRESS, exist_ok=True)
	nums = [int(f[:3]) for f in os.listdir(PROGRESS) if f[:3].isdigit()]
	return (max(nums) + 1) if nums else 1


def _sheet(res, ref_img, ren_img, ref_fg, ren_fg, ref_c, ren_c, classes):
	H, W, _ = ref_img.shape
	mix = (ref_img * 0.5 + ren_img * 0.5)
	diff = np.zeros((H, W, 3), np.uint8)
	diff[ref_fg & ren_fg] = (235, 235, 235)
	diff[ref_fg & ~ren_fg] = (230, 60, 60)
	diff[~ref_fg & ren_fg] = (60, 120, 240)
	tiles = [np.uint8(np.clip(ref_img, 0, 255)), np.uint8(np.clip(ren_img, 0, 255)), np.uint8(np.clip(mix, 0, 255)), diff,
		rm.class_image(ref_c, classes), rm.class_image(ren_c, classes)]
	titles = ["PAINTING", "BUILD", "50% MIX", "DIFFERENCE (red: missing, blue: extra)", "PAINTING MATERIALS", "BUILD MATERIALS"]
	cols = 3
	out = Image.new("RGB", (W * cols + 20, (H + 34) * 2 + 150), (24, 26, 31))
	d = ImageDraw.Draw(out)
	for i, (t, title) in enumerate(zip(tiles, titles)):
		x, y = (i % cols) * (W + 10), (i // cols) * (H + 34)
		d.text((x + 6, y + 6), title, font=rm._font(20, True), fill=(255, 255, 255))
		out.paste(Image.fromarray(t), (x, y + 34))
	y = (H + 34) * 2 + 8
	g = res["gates"]
	line1 = "%s  %s  |  silhouette IoU %.2f (gate %.2f: %s)  covers %d%% of the painting, %d%% extra" % (
		res["label"], res["view"], res["iou"], GATE_IOU, "PASS" if g["silhouette"] else "FAIL",
		round(res["painting_covered"] * 100), round(res["build_extra"] * 100))
	d.text((10, y), line1, font=rm._font(22, True), fill=(255, 255, 255))
	parts = []
	for n, v in res["materials"].items():
		parts.append("%s: IoU %.2f, %d%% vs %d%%, colour off %s" % (n, v["iou"], round(v["ref_share"] * 100), round(v["build_share"] * 100),
			"-" if v["colour_diff"] is None else "%.0f" % v["colour_diff"]))
	d.text((10, y + 36), "   ".join(parts[:3]), font=rm._font(19), fill=(225, 225, 230))
	d.text((10, y + 66), "   ".join(parts[3:]), font=rm._font(19), fill=(225, 225, 230))
	d.text((10, y + 100), "colour gate (within %d on every material over 5%%): %s" % (GATE_COLOUR, "PASS" if g["colour"] else "FAIL"),
		font=rm._font(19), fill=(225, 225, 230))
	num = _next_number()
	base = os.path.join(PROGRESS, "%03d_%s_%s_%s" % (num, res["sheet"], res["view"], res["label"]))
	out.save(base + ".png")
	with open(base + ".json", "w", encoding="utf-8", newline="\n") as f:
		json.dump(res, f, indent=1)
	res["sheet_path"] = base + ".png"


if __name__ == "__main__":
	a = sys.argv
	bg = (52, 55, 61)
	if "--bg" in a:
		bg = tuple(int(c) for c in a[a.index("--bg") + 1].split(","))
	ignore = tuple(a[a.index("--ignore") + 1].split(",")) if "--ignore" in a else ()
	r = compare(a[1], a[2], a[3], a[4], bg, ignore=ignore)
	print(json.dumps({k: r[k] for k in ("iou", "painting_covered", "build_extra", "gates", "sheet_path")}, indent=1))
	for n, v in r["materials"].items():
		print("  %-8s %s" % (n, v))
