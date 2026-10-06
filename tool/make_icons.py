#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Generates launcher + notification icons for طالع من.

Draws a premium "midnight sky" mark: deep navy radial background, a golden
crescent moon, scattered stars and a subtle zodiac-wheel ring. Output sizes
cover all Android densities, including adaptive-icon foregrounds.
Run: python3 tool/make_icons.py
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")

NAVY = (11, 16, 38)
NAVY_EDGE = (23, 30, 74)
GOLD = (232, 199, 123)
GOLD_LIGHT = (255, 227, 167)
VIOLET = (139, 124, 246)
STAR_WHITE = (237, 240, 255)


def radial_bg(size):
    """Deep navy radial gradient background."""
    img = Image.new("RGB", (size, size), NAVY)
    px = img.load()
    cx = cy = size / 2
    maxd = math.hypot(cx, cy)
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - cx * 0.62, y - cy * 0.34) / maxd
            t = min(1.0, d)
            r = int(NAVY[0] + (NAVY_EDGE[0] - NAVY[0]) * t)
            g = int(NAVY[1] + (NAVY_EDGE[1] - NAVY[1]) * t)
            b = int(NAVY[2] + (NAVY_EDGE[2] - NAVY[2]) * t)
            px[x, y] = (r, g, b)
    return img


def draw_mark(size, fg_scale=1.0, with_bg=True, padding=0.0):
    """Draws the moon + stars mark. Returns RGBA image."""
    scale = size / 1024.0 * fg_scale
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    if with_bg:
        img = radial_bg(size).convert("RGBA")
    d = ImageDraw.Draw(img)

    cx, cy = size / 2, size / 2
    R = 300 * scale

    # Subtle zodiac wheel ring (two arcs)
    ring_r = R * 1.28
    for arc_alpha, width, rot in [(70, max(2, int(10 * scale)), 15), (46, max(1, int(5 * scale)), 115)]:
        d.arc(
            [cx - ring_r, cy - ring_r, cx + ring_r, cy + ring_r],
            start=rot, end=rot + 240,
            fill=VIOLET + (arc_alpha,),
            width=width,
        )

    # Crescent moon: big gold circle minus offset navy circle
    moon = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    md = ImageDraw.Draw(moon)
    md.ellipse(
        [cx - R, cy - R, cx + R, cy + R],
        fill=GOLD + (255,),
    )
    cut_r = R * 0.86
    off = R * 0.52
    md.ellipse(
        [cx - cut_r + off, cy - cut_r - off * 0.18, cx + cut_r + off, cy + cut_r - off * 0.18],
        fill=(0, 0, 0, 0),
    )
    # glow behind moon
    glow = moon.filter(ImageFilter.GaussianBlur(26 * scale))
    big_img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    big_img.alpha_composite(glow)
    big_img.alpha_composite(moon)
    img.alpha_composite(big_img)

    d = ImageDraw.Draw(img)

    # Stars (deterministic layout)
    rng = random.Random(77)
    star_spots = [
        (0.20, 0.24, 0.9), (0.82, 0.20, 0.7), (0.14, 0.68, 0.6),
        (0.78, 0.78, 0.8), (0.30, 0.86, 0.5), (0.88, 0.52, 0.6),
        (0.55, 0.12, 0.55), (0.08, 0.44, 0.5), (0.64, 0.90, 0.45),
    ]
    for fx, fy, fs in star_spots:
        sx, sy = fx * size, fy * size
        sr = 16 * fs * scale
        # 4-point sparkle
        pts = []
        for i in range(8):
            ang = math.pi / 4 * i - math.pi / 2
            rad = sr if i % 2 == 0 else sr * 0.34
            pts.append((sx + rad * math.cos(ang), sy + rad * math.sin(ang)))
        color = STAR_WHITE if rng.random() > 0.35 else GOLD_LIGHT
        d.polygon(pts, fill=color + (235,))

    return img


def rounded_fg(size, radius_ratio=0.0):
    """Foreground for adaptive icons (transparent outside safe zone)."""
    return draw_mark(size, fg_scale=0.62, with_bg=False)


def main():
    densities = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, size in densities.items():
        out = os.path.join(RES, folder)
        os.makedirs(out, exist_ok=True)
        draw_mark(size).save(os.path.join(out, "ic_launcher.png"))
        # round icon
        img = draw_mark(size)
        mask = Image.new("L", (size, size), 0)
        ImageDraw.Draw(mask).ellipse([0, 0, size, size], fill=255)
        img.putalpha(mask)
        img.save(os.path.join(out, "ic_launcher_round.png"))
        # adaptive foreground (content in center 60%)
        fg = rounded_fg(size * 9 // 5)  # 108dp grid
        fg.save(os.path.join(out, "ic_launcher_foreground.png"))
        print(f"wrote {folder}")

    # adaptive icon XMLs
    anydpi = os.path.join(RES, "mipmap-anydpi-v26")
    os.makedirs(anydpi, exist_ok=True)
    xml = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/launch_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
"""
    open(os.path.join(anydpi, "ic_launcher.xml"), "w").write(xml)
    open(os.path.join(anydpi, "ic_launcher_round.xml"), "w").write(xml)

    # notification small icon (white-only glyph per Material guidance)
    drawable = os.path.join(RES, "drawable")
    os.makedirs(drawable, exist_ok=True)
    nsize = 96
    nimg = Image.new("RGBA", (nsize, nsize), (0, 0, 0, 0))
    nd = ImageDraw.Draw(nimg)
    R = 34
    cx = cy = nsize / 2
    moon = Image.new("RGBA", (nsize, nsize), (0, 0, 0, 0))
    md = ImageDraw.Draw(moon)
    md.ellipse([cx - R, cy - R, cx + R, cy + R], fill=(255, 255, 255, 255))
    cut = R * 0.86
    off = R * 0.5
    md.ellipse(
        [cx - cut + off, cy - cut, cx + cut + off, cy + cut],
        fill=(0, 0, 0, 0),
    )
    nimg.alpha_composite(moon)
    # a tiny sparkle
    nd = ImageDraw.Draw(nimg)
    sx, sy, sr = cx + 26, cy - 26, 7
    pts = []
    for i in range(8):
        ang = math.pi / 4 * i - math.pi / 2
        rad = sr if i % 2 == 0 else sr * 0.34
        pts.append((sx + rad * math.cos(ang), sy + rad * math.sin(ang)))
    nd.polygon(pts, fill=(255, 255, 255, 255))
    nimg.save(os.path.join(drawable, "ic_notification.png"))
    print("wrote adaptive + notification icons")


if __name__ == "__main__":
    main()
