"""Voxel Lab: many captured frames on one sheet, each labelled with its file name, for looking.

    python contact_sheet.py OUT.png FRAME.png [FRAME.png ...] [--cols 3] [--width 640]

Frames keep their aspect; the sheet is dark grey with white labels. Needs Pillow.
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont


def main(argv):
    cols = 3
    width = 640
    paths = []
    out = None
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--cols":
            cols = int(argv[i + 1])
            i += 2
            continue
        if a == "--width":
            width = int(argv[i + 1])
            i += 2
            continue
        if out is None:
            out = a
        else:
            paths.append(a)
        i += 1
    if out is None or not paths:
        print(__doc__)
        return 1
    images = [Image.open(p).convert("RGB") for p in paths]
    thumbs = []
    for im in images:
        h = int(im.height * width / im.width)
        thumbs.append(im.resize((width, h), Image.LANCZOS))
    label_h = 26
    cell_h = max(t.height for t in thumbs) + label_h
    rows = (len(thumbs) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * width + (cols + 1) * 8, rows * cell_h + (rows + 1) * 8), (28, 30, 34))
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("arial.ttf", 16)
    except OSError:
        font = ImageFont.load_default()
    for k, (t, p) in enumerate(zip(thumbs, paths)):
        r, c = divmod(k, cols)
        x = 8 + c * (width + 8)
        y = 8 + r * (cell_h + 8)
        sheet.paste(t, (x, y + label_h))
        draw.text((x + 4, y + 4), Path(p).stem, fill=(235, 238, 245), font=font)
    sheet.save(out)
    print("sheet", out, sheet.size)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
