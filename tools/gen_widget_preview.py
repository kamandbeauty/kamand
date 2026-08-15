#!/usr/bin/env python3
"""Renders the widget preview images shown in Android's widget picker.

Pure-python PNG writer (no third-party deps) so it runs anywhere. The preview
mirrors the real widget layout: gradient header, progress bar, task rows.
"""
import math
import os
import struct
import zlib

OUT_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "roozi", "app", "src", "main", "res", "drawable-nodpi"
)

CORAL = (0xFF, 0x6B, 0x6B)
MID = (0xFF, 0x7E, 0x8F)
PURPLE = (0x7C, 0x5C, 0xFF)
SURFACE = (0xFD, 0xF7, 0xF4)
ROW = (0xF6, 0xF1, 0xFA)
TEXT = (0x24, 0x1F, 0x2E)
TEXT2 = (0x8A, 0x85, 0x95)
MINT = (0x2E, 0xCC, 0x9B)
ORANGE = (0xFF, 0x9F, 0x45)
WHITE = (0xFF, 0xFF, 0xFF)


def lerp(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def header_gradient(t):
    return lerp(CORAL, MID, t / 0.5) if t < 0.5 else lerp(MID, PURPLE, (t - 0.5) / 0.5)


class Canvas:
    def __init__(self, w, h, bg=(0, 0, 0, 0)):
        self.w, self.h = w, h
        self.px = [[bg] * w for _ in range(h)]

    def set(self, x, y, color, alpha=255):
        if 0 <= x < self.w and 0 <= y < self.h:
            if alpha >= 255:
                self.px[y][x] = (int(color[0]), int(color[1]), int(color[2]), 255)
            else:
                old = self.px[y][x]
                a = alpha / 255.0
                self.px[y][x] = (
                    int(color[0] * a + old[0] * (1 - a)),
                    int(color[1] * a + old[1] * (1 - a)),
                    int(color[2] * a + old[2] * (1 - a)),
                    255,
                )

    def rounded_rect(self, x, y, w, h, r, color_fn, top_only=False):
        for j in range(int(y), int(y + h)):
            for i in range(int(x), int(x + w)):
                lx, ly = i - x, j - y
                # corner rounding
                cx = min(max(lx, r), w - r)
                cy_top = min(max(ly, r), h - r) if not top_only else max(ly, r)
                cy = cy_top if not top_only else (r if ly < r else ly)
                inside = True
                if lx < r and ly < r:
                    inside = (lx - r) ** 2 + (ly - r) ** 2 <= r * r
                elif lx > w - r and ly < r:
                    inside = (lx - (w - r)) ** 2 + (ly - r) ** 2 <= r * r
                elif not top_only and lx < r and ly > h - r:
                    inside = (lx - r) ** 2 + (ly - (h - r)) ** 2 <= r * r
                elif not top_only and lx > w - r and ly > h - r:
                    inside = (lx - (w - r)) ** 2 + (ly - (h - r)) ** 2 <= r * r
                if inside:
                    c = color_fn(lx / max(1, w), ly / max(1, h))
                    self.set(i, j, c)

    def bar(self, x, y, w, h, color, radius=None):
        r = radius if radius is not None else h / 2
        self.rounded_rect(x, y, w, h, r, lambda u, v: color)

    def circle(self, cx, cy, r, color, alpha=255):
        for j in range(int(cy - r), int(cy + r) + 1):
            for i in range(int(cx - r), int(cx + r) + 1):
                if (i - cx) ** 2 + (j - cy) ** 2 <= r * r:
                    self.set(i, j, color, alpha)

    def to_png_bytes(self):
        raw = bytearray()
        for row in self.px:
            raw.append(0)
            for p in row:
                raw += bytes((p[0], p[1], p[2], p[3]))
        return bytes(raw)


def write_png(path, canvas):
    def chunk(tag, data):
        c = tag + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)

    hdr = struct.pack(">IIBBBBB", canvas.w, canvas.h, 8, 6, 0, 0, 0)
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", hdr)
        + chunk(b"IDAT", zlib.compress(canvas.to_png_bytes(), 9))
        + chunk(b"IEND", b"")
    )
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(png)


def today_preview():
    W, H = 400, 280
    c = Canvas(W, H)
    # card
    c.rounded_rect(0, 0, W, H, 30, lambda u, v: SURFACE)
    # gradient header
    HH = 104
    c.rounded_rect(0, 0, W, HH, 30, lambda u, v: header_gradient(u * 0.7 + v * 0.3), top_only=True)
    # title bar (block shapes standing in for text)
    c.bar(24, 26, 96, 15, WHITE)
    c.bar(24, 50, 150, 10, (0xF0, 0xE4, 0xF2))
    # progress pill
    c.bar(W - 150, 28, 62, 22, (0xFF, 0xFF, 0xFF), radius=11)
    # plus button
    c.circle(W - 52, 40, 18, WHITE, alpha=80)
    c.bar(W - 61, 38, 18, 4, WHITE, radius=2)
    c.bar(W - 54, 31, 4, 18, WHITE, radius=2)
    # progress track + fill
    c.bar(24, 80, W - 48, 8, (0xFF, 0xFF, 0xFF), radius=4)
    c.bar(24, 80, int((W - 48) * 0.62), 8, WHITE, radius=4)

    # rows
    y = HH + 14
    for accent, done, width in ((MINT, True, 190), (CORAL, False, 220), (ORANGE, False, 160)):
        c.rounded_rect(16, y, W - 32, 44, 14, lambda u, v: ROW)
        c.bar(W - 34, y + 12, 4, 20, accent, radius=2)
        c.circle(W - 58, y + 22, 9, accent if done else (0xD8, 0xD2, 0xE2))
        c.bar(W - 76 - width, y + 17, width, 10, TEXT2 if done else TEXT, radius=5)
        c.bar(28, y + 16, 40, 12, (0xEC, 0xE6, 0xF2), radius=6)
        y += 52
    return c


def quick_add_preview():
    W, H = 320, 110
    c = Canvas(W, H)
    c.rounded_rect(0, 0, W, H, 26, lambda u, v: header_gradient(u))
    c.circle(W - 56, H / 2, 20, WHITE, alpha=80)
    c.bar(W - 66, H / 2 - 2, 20, 5, WHITE, radius=2)
    c.bar(W - 58, H / 2 - 10, 5, 21, WHITE, radius=2)
    c.bar(60, H / 2 - 7, 130, 14, WHITE, radius=7)
    return c


if __name__ == "__main__":
    write_png(os.path.join(OUT_DIR, "widget_today_preview.png"), today_preview())
    write_png(os.path.join(OUT_DIR, "widget_quick_add_preview.png"), quick_add_preview())
    print("wrote widget previews to", os.path.normpath(OUT_DIR))
