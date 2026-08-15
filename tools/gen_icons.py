#!/usr/bin/env python3
"""Pure-python launcher icon renderer for ROOZI (no third-party deps).

Produces the legacy square/round mipmap PNGs for API < 26 devices.
The adaptive icon (API 26+) is defined by vector drawables.
"""
import math
import struct
import zlib
import os

OUT = os.path.join(os.path.dirname(__file__), "..", "roozi", "app", "src", "main")

SS = 4  # supersampling factor

GRAD_A = (0xFF, 0x8A, 0x65)
GRAD_B = (0xFF, 0x6B, 0x6B)
GRAD_C = (0x7C, 0x5C, 0xFF)
CORAL = (0xFF, 0x6B, 0x6B)
WHITE = (0xFF, 0xFF, 0xFF)


def lerp(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def grad(t):
    t = max(0.0, min(1.0, t))
    return lerp(GRAD_A, GRAD_B, t / 0.55) if t < 0.55 else lerp(GRAD_B, GRAD_C, (t - 0.55) / 0.45)


def rounded_rect(x, y, w, h, r, px, py):
    """Signed test: is (px,py) inside a rounded rect?"""
    cx = min(max(px, x + r), x + w - r)
    cy = min(max(py, y + r), y + h - r)
    if x <= px <= x + w and y + r <= py <= y + h - r:
        return True
    if x + r <= px <= x + w - r and y <= py <= y + h:
        return True
    return (px - cx) ** 2 + (py - cy) ** 2 <= r * r


def seg_dist(px, py, ax, ay, bx, by):
    vx, vy = bx - ax, by - ay
    wx, wy = px - ax, py - ay
    L = vx * vx + vy * vy
    t = 0.0 if L == 0 else max(0.0, min(1.0, (wx * vx + wy * vy) / L))
    dx, dy = px - (ax + t * vx), py - (ay + t * vy)
    return math.hypot(dx, dy)


def render(size, circular):
    n = size * SS
    buf = [[(0, 0, 0, 0)] * n for _ in range(n)]
    s = n / 108.0  # design grid is 108x108
    for j in range(n):
        for i in range(n):
            x, y = i / s, j / s
            # background shape
            if circular:
                inside_bg = (x - 54) ** 2 + (y - 54) ** 2 <= 52 * 52
            else:
                inside_bg = rounded_rect(6, 6, 96, 96, 22, x, y)
            if not inside_bg:
                continue
            col = grad(((x - 6) + (y - 6)) / 192.0)
            # white card
            if rounded_rect(28, 32, 52, 44, 10, x, y):
                col = WHITE
            # check mark stroke
            d = min(seg_dist(x, y, 40, 55, 49, 64), seg_dist(x, y, 49, 64, 68, 44))
            if d <= 3.5:
                col = CORAL
            buf[j][i] = (int(col[0]), int(col[1]), int(col[2]), 255)

    # downsample
    out = bytearray()
    for j in range(size):
        out.append(0)
        for i in range(size):
            r = g = b = a = 0
            for dj in range(SS):
                for di in range(SS):
                    p = buf[j * SS + dj][i * SS + di]
                    r += p[0] * p[3]
                    g += p[1] * p[3]
                    b += p[2] * p[3]
                    a += p[3]
            cnt = SS * SS
            if a == 0:
                out += bytes((0, 0, 0, 0))
            else:
                out += bytes((r // a, g // a, b // a, a // cnt))
    return bytes(out)


def write_png(path, size, raw):
    def chunk(tag, data):
        c = tag + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)

    hdr = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", hdr) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(png)


DENSITIES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}

if __name__ == "__main__":
    for dens, px in DENSITIES.items():
        for name, circular in (("ic_launcher", False), ("ic_launcher_round", True)):
            raw = render(px, circular)
            write_png(os.path.join(OUT, "res", f"mipmap-{dens}", f"{name}.png"), px, raw)
            print("wrote", dens, name, px)
    # Play-store style 512 icon for listings
    write_png(os.path.join(OUT, "..", "..", "..", "..", "store", "icon-512.png"), 512, render(512, False))
    print("done")
