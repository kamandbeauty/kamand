#!/usr/bin/env python3
"""Install a source artwork as the ROOZI launcher icon.

Usage:
    python3 tools/set_launcher_icon.py <source.png>

Generates every density of ic_launcher / ic_launcher_round plus the adaptive
foreground and background layers, and rewrites the adaptive-icon XML to use
them.

Why the layers are built the way they are: Android crops an adaptive icon to a
shape the launcher chooses (circle, squircle, rounded square) and only the
centre 66/108 of the canvas is guaranteed to survive. Artwork placed edge to
edge therefore loses its border. The foreground is scaled into that safe zone
so nothing important is clipped, and the background is filled with the source's
own dominant edge colour so the crop blends instead of showing a seam.
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

# Adaptive icons are authored on a 108dp canvas.
ADAPTIVE_DP = 108
# Only the centre 66dp is guaranteed visible after the launcher's mask.
SAFE_DP = 66

ADAPTIVE_XML = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
"""


def dominant_edge_colour(img: Image.Image) -> tuple[int, int, int]:
    """Average the outer border, which is the colour the mask will crop into."""
    rgb = img.convert("RGB")
    w, h = rgb.size
    band = max(1, min(w, h) // 24)
    px = rgb.load()
    total = [0, 0, 0]
    count = 0
    for x in range(w):
        for y in list(range(band)) + list(range(h - band, h)):
            r, g, b = px[x, y]
            total[0] += r
            total[1] += g
            total[2] += b
            count += 1
    for y in range(h):
        for x in list(range(band)) + list(range(w - band, w)):
            r, g, b = px[x, y]
            total[0] += r
            total[1] += g
            total[2] += b
            count += 1
    return tuple(c // count for c in total)


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
    edge = dominant_edge_colour(src)
    print(f"source {src.size[0]}x{src.size[1]}, edge colour #{edge[0]:02X}{edge[1]:02X}{edge[2]:02X}")

    # Legacy bitmaps: the full artwork at each density.
    for suffix, size in DENSITIES.items():
        out_dir = RES / f"mipmap-{suffix}"
        out_dir.mkdir(parents=True, exist_ok=True)
        scaled = src.resize((size, size), Image.LANCZOS)
        scaled.save(out_dir / "ic_launcher.png")

        # Round variant: same art masked to a circle.
        mask = Image.new("L", (size * 4, size * 4), 0)
        from PIL import ImageDraw

        ImageDraw.Draw(mask).ellipse([0, 0, size * 4 - 1, size * 4 - 1], fill=255)
        mask = mask.resize((size, size), Image.LANCZOS)
        rounded = scaled.copy()
        rounded.putalpha(mask)
        rounded.save(out_dir / "ic_launcher_round.png")
        print(f"  mipmap-{suffix}: {size}px")

    # Adaptive layers, authored at xxxhdpi (4x) for crisp scaling.
    scale = 4
    canvas = ADAPTIVE_DP * scale
    safe = SAFE_DP * scale

    for suffix, dp_px in DENSITIES.items():
        density_scale = dp_px / 48  # mdpi baseline
        c = int(ADAPTIVE_DP * density_scale)
        s = int(SAFE_DP * density_scale)

        fg = Image.new("RGBA", (c, c), (0, 0, 0, 0))
        art = src.resize((s, s), Image.LANCZOS)
        fg.paste(art, ((c - s) // 2, (c - s) // 2), art)
        (RES / f"mipmap-{suffix}").mkdir(parents=True, exist_ok=True)
        fg.save(RES / f"mipmap-{suffix}" / "ic_launcher_foreground.png")

        bg = Image.new("RGBA", (c, c), edge + (255,))
        bg.save(RES / f"mipmap-{suffix}" / "ic_launcher_background.png")

    print(f"  adaptive layers written (safe zone {SAFE_DP}/{ADAPTIVE_DP}dp)")

    for name in ("ic_launcher.xml", "ic_launcher_round.xml"):
        (RES / "mipmap-anydpi-v26" / name).write_text(ADAPTIVE_XML)
    print("  adaptive-icon XML updated")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
