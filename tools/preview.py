#!/usr/bin/env python3
"""Approximate previews of the nova43 zoom from a 1280x960 device screenshot (no game needed).

A uniform zoom of the 16:9 band about a pivot is exactly an affine crop of the screenshot, so this
shows the layout the Lua patch produces (text will be sharper in game, since it renders at the new size).

  python3 tools/preview.py boon  shot.png out.png --px 440 [--s 1.3333]
  python3 tools/preview.py dialogue shot.png out.png --px 640
Pivot is in screen pixels (1280x960); y pivot is the screen centre (480).
"""
import argparse
from PIL import Image

def zoom(img, s, px, py):
    a = 1 / s
    return img.transform(img.size, Image.AFFINE, (a, 0, px * (1 - a), 0, a, py * (1 - a)), Image.BICUBIC)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("kind", choices=["boon", "dialogue"])
    ap.add_argument("src"); ap.add_argument("dst")
    ap.add_argument("--px", type=float, default=640)
    ap.add_argument("--s", type=float, default=960 / 720)
    a = ap.parse_args()
    src = Image.open(a.src).convert("RGB")
    out = zoom(src, a.s, a.px, 480)
    if a.kind == "boon":
        k = 960 / 720
        # action bar: same size, same x, spread to the bottom band
        for box in ((16, 788, 172, 824), (1138, 788, 1262, 824)):
            crop = src.crop(box)
            cy = (box[1] + box[3]) / 2
            ny = 480 + k * (cy - 480)
            out.paste(crop, (box[0], int(ny - crop.height / 2)))
        # title/flavor anchored to the screen centre: undo the horizontal pivot shift
        shift = int(round((a.px - 640) * (a.s - 1)))
        top = int(480 + a.s * (155 - 480)); bot = int(480 + a.s * (215 - 480))
        band = out.crop((0, top, 1280, bot))
        x0, x1 = 360 + int(a.s * 0), 920
        zx0 = int(a.px + a.s * (x0 - a.px)); zx1 = int(a.px + a.s * (x1 - a.px))
        title = out.crop((zx0, top, zx1, bot))
        out.paste(title, (zx0 + shift, top))
    out.save(a.dst)

main()
