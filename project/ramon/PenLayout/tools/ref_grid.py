"""A zoomed crop of a sheet with a labelled pixel grid, for reading landmark positions off a view
(PenLayout/PLAN_REF_LOCK.md step 4). Coordinates on the grid are the sheet's own.

    python ref_grid.py <sheet.png> x0 y0 x1 y1 [zoom] [out.png] [step]
"""
import sys
from PIL import Image, ImageDraw, ImageFont


def grid(path, x0, y0, x1, y1, zoom=3, out="grid.png", step=10, points=None):
	img = Image.open(path).convert("RGB").crop((x0, y0, x1, y1))
	img = img.resize(((x1 - x0) * zoom, (y1 - y0) * zoom), Image.LANCZOS)
	d = ImageDraw.Draw(img)
	f = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", 13)
	for x in range((x0 // step + 1) * step, x1, step):
		major = x % (step * 5) == 0
		X = (x - x0) * zoom
		d.line((X, 0, X, img.height), fill=(255, 255, 255) if major else (120, 120, 120), width=1)
		if major:
			d.rectangle((X + 1, 0, X + 34, 14), fill=(0, 0, 0))
			d.text((X + 2, 0), str(x), font=f, fill=(255, 255, 0))
	for y in range((y0 // step + 1) * step, y1, step):
		major = y % (step * 5) == 0
		Y = (y - y0) * zoom
		d.line((0, Y, img.width, Y), fill=(255, 255, 255) if major else (120, 120, 120), width=1)
		if major:
			d.rectangle((0, Y + 1, 34, Y + 15), fill=(0, 0, 0))
			d.text((2, Y + 1), str(y), font=f, fill=(0, 255, 255))
	for name, (px, py) in (points or {}).items():
		X, Y = (px - x0) * zoom, (py - y0) * zoom
		d.ellipse((X - 5, Y - 5, X + 5, Y + 5), outline=(255, 0, 255), width=2)
		d.text((X + 7, Y - 7), name, font=f, fill=(255, 0, 255))
	img.save(out)
	return img.size


if __name__ == "__main__":
	a = sys.argv
	print(grid(a[1], int(a[2]), int(a[3]), int(a[4]), int(a[5]), int(a[6]) if len(a) > 6 else 3,
		a[7] if len(a) > 7 else "grid.png", int(a[8]) if len(a) > 8 else 10))
