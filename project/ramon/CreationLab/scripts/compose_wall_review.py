"""The two blue walls side by side, flat and unlit, for painting over (Ramon, 5 Oct: "I need a flat
look so I can easily make adjustments without gradients, in Photoshop or with AI").

Run _capture_compare_runner.gd first; it saves each panel's own picture as drawn, premultiplied, at
260 px a metre (flat_lesson_print.png, flat_research_page.png). This lays them on the wall blue at
their places on the gallery's 28 by 10 m wall, at the same 260 px a metre, with NO resampling (a
filtered resize of premultiplied pixels is what put speckled halos round every letter the first
time), and writes front_flat.png and front_flat_grid.png (the wall's 1 m and 20 cm grid lines) to
project/smoke_test_output/wall_review/.

    python project/ramon/CreationLab/scripts/compose_wall_review.py
"""
import os
import shutil

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.normpath(os.path.join(HERE, "../../../smoke_test_output/goat_room/compare"))
OUT = os.path.normpath(os.path.join(HERE, "../../../smoke_test_output/wall_review"))
PPM = 260
WALL_W, WALL_H = 28.0, 10.0
BLUE = np.array([0.13, 0.40, 0.86], np.float32)          # kit_code_blue, bright
LINE = np.array([0.20, 0.48, 0.93], np.float32)
SUB = np.array([0.16, 0.44, 0.90], np.float32)
# Where each panel sits: left edge along the wall and top, metres (WallCompare in goat_room.tscn).
PANELS = [("flat_lesson_print.png", 2.7, WALL_H - 7.6), ("flat_research_page.png", 15.3, WALL_H - 8.2)]


def place(canvas: np.ndarray, path: str, x0: float, y_top: float) -> None:
    a = np.asarray(Image.open(path).convert("RGBA")).astype(np.float32) / 255.0
    x, y = int(round(x0 * PPM)), int(round(y_top * PPM))
    reg = canvas[y:y + a.shape[0], x:x + a.shape[1]]
    reg[:] = np.clip(reg * (1.0 - a[..., 3:4]) + a[..., :3], 0.0, 1.0)


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    for grid in (False, True):
        c = np.ones((int(WALL_H * PPM), int(WALL_W * PPM), 3), np.float32) * BLUE
        if grid:
            ys, xs = np.mgrid[0:c.shape[0], 0:c.shape[1]] / PPM
            near = lambda v, step, half: np.abs(((v + step / 2) % step) - step / 2) <= half
            minor = near(xs, 0.2, 0.003) | near(ys, 0.2, 0.003)
            major = near(xs, 1.0, 0.011) | near(ys, 1.0, 0.011)
            c[minor] = c[minor] * 0.5 + SUB * 0.5
            c[major] = c[major] * 0.5 + LINE * 0.5
        for name, x0, y_top in PANELS:
            place(c, os.path.join(SRC, name), x0, y_top)
        Image.fromarray((c * 255 + 0.5).astype(np.uint8)).save(os.path.join(OUT, "front_flat_grid.png" if grid else "front_flat.png"))
    for name, _, _ in PANELS:
        shutil.copy(os.path.join(SRC, name), os.path.join(OUT, name))
    print("written to", OUT)


if __name__ == "__main__":
    main()
