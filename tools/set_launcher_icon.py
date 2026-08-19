#!/usr/bin/env python3
"""Install a source artwork as the ROOZI launcher icon.

Usage:
    python3 tools/set_launcher_icon.py <source.png>

Writes ic_launcher and ic_launcher_round at every density, reproducing the
source exactly, and clears any adaptive-icon definition so the bitmaps are what
the launcher actually uses.
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

RES = Path(__file__).resolve().parent.parent / "roozi" / "app" / "src" / "main" / "res"

# Legacy square/round launcher bitmaps.
DENSITIES = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}

# This artwork is delivered as a legacy icon, with no adaptive layers.
#
# An adaptive icon is always cropped to a mask the launcher chooses. This source
# is a near-square card with opaque corners, so a circular mask necessarily
# slices them off; sizing it small enough to survive that circle works out at
# 57 of the 108dp canvas — barely half — and renders as a tiny sticker adrift in
# a coloured field. Neither outcome is "exactly this image with nothing cut".
#
# Legacy icons are not mask-cropped. Launchers on API 26+ shrink them onto a
# neutral plate instead, so the artwork arrives whole, which is the requirement
# here.



def square(img: Image.Image) -> Image.Image:
    """Centre-crop to a square so no density stretches the artwork."""
    w, h = img.size
    if w == h:
        return img
    side = min(w, h)
    return img.crop(
        ((w - side) // 2, (h - side) // 2, (w + side) // 2, (h + side) // 2)
    )


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2

    src_path = Path(sys.argv[1])
    if not src_path.exists():
        print(f"source not found: {src_path}")
        return 1

    src = square(Image.open(src_path).convert("RGBA"))
    print(f"source {src.size[0]}x{src.size[1]}")

    # Legacy bitmaps: the full artwork at each density.
    for suffix, size in DENSITIES.items():
        out_dir = RES / f"mipmap-{suffix}"
        out_dir.mkdir(parents=True, exist_ok=True)
        scaled = src.resize((size, size), Image.LANCZOS)
        scaled.save(out_dir / "ic_launcher.png")

        # The round variant is the same untouched artwork. Masking it to a
        # circle here would cut the card's corners off — the very thing this
        # icon is meant to avoid — and launchers that ask for the round icon
        # already apply their own shape.
        scaled.save(out_dir / "ic_launcher_round.png")
        print(f"  mipmap-{suffix}: {size}px")

    # Remove any adaptive definitions and layers from a previous run: leaving
    # ic_launcher.xml in mipmap-anydpi-v26 would keep overriding these bitmaps
    # on every device from API 26 up, which is all of them.
    for name in ("ic_launcher.xml", "ic_launcher_round.xml"):
        stale = RES / "mipmap-anydpi-v26" / name
        if stale.exists():
            stale.unlink()
            print(f"  removed adaptive {name}")

    for suffix in DENSITIES:
        for name in ("ic_launcher_foreground.png", "ic_launcher_background.png"):
            stale = RES / f"mipmap-{suffix}" / name
            if stale.exists():
                stale.unlink()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
