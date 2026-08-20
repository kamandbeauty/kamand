#!/usr/bin/env python3
"""تولید افکت‌های صوتی بازی حکم — کاملاً procedural (بدون دارایی خارجی).

تمام صداها با numpy سنتز می‌شوند و خروجی WAV 16bit مونو 22050Hz است.
اجرا:  python3 tool/gen_sfx.py
"""
import numpy as np
import wave
import os

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
os.makedirs(OUT, exist_ok=True)

rng = np.random.default_rng(2024)


def save(name: str, data: np.ndarray) -> None:
    data = np.clip(data, -1.0, 1.0)
    # fade-out 5ms برای جلوگیری از کلیک انتهایی
    fade = int(SR * 0.005)
    if len(data) > fade:
        data[-fade:] *= np.linspace(1.0, 0.0, fade)
    pcm = (data * 32767).astype(np.int16)
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print(f"  {name}: {len(data)/SR*1000:.0f}ms, {os.path.getsize(path)//1024}KB")


def env_exp(n: int, tau_ms: float) -> np.ndarray:
    t = np.arange(n) / SR
    return np.exp(-t / (tau_ms / 1000.0))


def lowpass(x: np.ndarray, alpha: float) -> np.ndarray:
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = acc + alpha * (x[i] - acc)
        y[i] = acc
    return y


def t(dl: float) -> int:
    return int(SR * dl)


def noise(n: int) -> np.ndarray:
    return rng.uniform(-1, 1, n)


def sine(freq: float, n: int, phase: float = 0.0) -> np.ndarray:
    return np.sin(2 * np.pi * freq * np.arange(n) / SR + phase)


# ---------- card_pick: تیک کوتاه کشیدن کارت ----------
def card_pick() -> np.ndarray:
    n = t(0.09)
    x = noise(n)
    # پالس کوتاه با رخداد تیز و افت سریع
    e = env_exp(n, 22)
    sweep = np.linspace(1.0, 0.5, n)
    y = x * e * sweep
    # افزودن کلیک اولیه
    click = sine(1900, n) * env_exp(n, 8) * 0.4
    return (y * 0.55 + click) * 0.8


# ---------- card_place: گذاشتن نرم روی میز ----------
def card_place() -> np.ndarray:
    n = t(0.16)
    body = noise(n) * env_exp(n, 30)
    body = lowpass(body, 0.25) * 2.2
    thump = sine(150, n) * env_exp(n, 40) * 0.55
    return (body + thump) * 0.75


# ---------- deal: سوییپ هوایی ----------
def deal() -> np.ndarray:
    n = t(0.16)
    x = noise(n)
    # سیوپ باندپس ساده با خودهمبستگی متغیر
    sweep = 0.06 + 0.30 * np.sin(np.pi * np.arange(n) / n) ** 2
    y = np.empty(n)
    acc = 0.0
    for i in range(n):
        acc = acc + sweep[i] * (x[i] - acc) * (1 if i % 1 == 0 else 1)
        y[i] = acc
    y = np.convolve(y, np.ones(3) / 3, mode="same")
    e = np.sin(np.pi * np.arange(n) / n) ** 1.5  # ورود و خروج نرم
    return (noise(n) * 0 + y * e * 3.2) * 0.6


# ---------- shuffle: بر زدن — چند ریفل پشت سرهم ----------
def shuffle() -> np.ndarray:
    total = t(0.95)
    out = np.zeros(total)
    pos = t(0.05)
    # دو نیم‌دسته + ریفل وسط
    for burst in range(3):
        seg_n = t(0.22 if burst < 2 else 0.3)
        x = noise(seg_n)
        flut = (np.sin(2 * np.pi * 47 * np.arange(seg_n) / SR) > 0).astype(float)
        flut = np.convolve(flut, np.ones(int(t(0.004))) / t(0.004), mode="same")
        seg = x * flut * env_exp(seg_n, 80)
        seg = lowpass(seg, 0.5)
        end = min(total, pos + seg_n)
        out[pos:end] += seg[: end - pos] * (0.7 if burst < 2 else 1.0)
        pos += t(0.28 if burst == 0 else 0.3)
    return out * 1.15


# ---------- trick_win: چایم دو نتی ----------
def trick_win() -> np.ndarray:
    n = t(0.45)
    f1, f2 = 784.0, 1046.5  # G5, C6
    e = env_exp(n, 150)
    y = 0.6 * sine(f1, n) + 0.4 * sine(f2, n) + 0.12 * sine(f1 * 2, n)
    # کمی درخشش اولیه
    out = y * e
    return out * 0.5


# ---------- button: کلیک نرم UI ----------
def button() -> np.ndarray:
    n = t(0.07)
    y = 0.7 * sine(820, n) + 0.25 * sine(1640, n)
    return y * env_exp(n, 20) * 0.75


# ---------- hukum: انتخاب حکم — آرپژ کوتاه ----------
def hukum() -> np.ndarray:
    total = t(0.55)
    out = np.zeros(total)
    freqs = [523.25, 659.25, 783.99]  # C5 E5 G5
    for i, f in enumerate(freqs):
        seg_n = t(0.28)
        seg = (0.6 * sine(f, seg_n) + 0.25 * sine(f * 2, seg_n)) * env_exp(seg_n, 120)
        pos = i * t(0.09)
        end = min(total, pos + seg_n)
        out[pos:end] += seg[: end - pos]
    return out * 0.42


# ---------- round_win: فانفار کوتاه ----------
def round_win() -> np.ndarray:
    total = t(0.9)
    out = np.zeros(total)
    freqs = [523.25, 659.25, 783.99, 1046.5]
    durs = [0.10, 0.10, 0.10, 0.28]
    step = [0.10, 0.10, 0.10, 0.0]
    pos = 0
    for i, f in enumerate(freqs):
        seg_n = t(durs[i] + 0.16)
        seg = (0.55 * sine(f, seg_n) + 0.2 * sine(f * 2, seg_n) + 0.1 * sine(f / 2, seg_n)) * env_exp(seg_n, 200)
        end = min(total, pos + seg_n)
        out[pos:end] += seg[: end - pos]
        pos += t(step[i])
    return out * 0.5


# ---------- match_win: جشن نهایی ----------
def match_win() -> np.ndarray:
    total = t(1.4)
    out = np.zeros(total)
    seq = [523.25, 659.25, 783.99, 1046.5, 783.99, 1046.5]
    for i, f in enumerate(seq):
        seg_n = t(0.30)
        seg = (0.5 * sine(f, seg_n) + 0.2 * sine(f * 2, seg_n)) * env_exp(seg_n, 180)
        pos = i * t(0.11)
        end = min(total, pos + seg_n)
        out[pos:end] += seg[: end - pos]
    # درام‌رول خیلی ملایم پایانی
    tail = noise(t(0.3)) * (np.abs(np.sin(2 * np.pi * 30 * np.arange(t(0.3)) / SR))) * env_exp(t(0.3), 250)
    out[t(0.8): t(0.8) + t(0.3)] += lowpass(tail, 0.2) * 0.6
    return out * 0.5


# ---------- match_lose: فرود ملایم ----------
def match_lose() -> np.ndarray:
    total = t(0.7)
    out = np.zeros(total)
    for i, f in enumerate([440.0, 349.23, 293.66]):
        seg_n = t(0.35)
        seg = (0.55 * sine(f, seg_n) + 0.15 * sine(f * 1.5, seg_n)) * env_exp(seg_n, 220)
        pos = i * t(0.16)
        end = min(total, pos + seg_n)
        out[pos:end] += seg[: end - pos]
    return out * 0.4


# ---------- music_ambient: لایهٔ آرام لَونج برای پس‌زمینه ----------
def music_ambient() -> np.ndarray:
    dur = 24.0
    n = t(dur)
    tvec = np.arange(n) / SR
    out = np.zeros(n)
    # پد ملایم: Em9 (E2 B2 D3 E3 F#3 G3)
    chord = [82.41, 123.47, 146.83, 164.81, 185.0, 196.0]
    for i, f in enumerate(chord):
        vib = sine(0.13 + i * 0.017, n) * 0.5  # در نوسان آرام ولوم
        w = sine(f, n) + 0.25 * sine(f * 2.003, n)
        env = 0.55 + 0.45 * sine(0.05 + i * 0.031, n)
        out += w * env * 0.055
    # زنگ‌‌های پراکندهٔ خیلی ملایم (سنتوروار)
    for s in range(6):
        f = [659.25, 587.33, 783.99, 880.0, 659.25, 987.77][s]
        seg_n = t(1.6)
        seg = (0.5 * sine(f, seg_n) + 0.3 * sine(f * 3.01, seg_n) * env_exp(seg_n, 60)) * env_exp(seg_n, 500)
        pos = t(2.0 + s * 3.7)
        end = min(n, pos + seg_n)
        out[pos:end] += seg[: end - pos] * 0.16
    # ریورب ساده: دو اکوی خفیف
    echo1 = np.roll(out, t(0.11)) * 0.22
    echo2 = np.roll(out, t(0.23)) * 0.12
    out = out + echo1 + echo2
    # نوسان کلی + فید ابتدا/انتها برای لوپ بهتر
    out *= 0.6 + 0.40 * (0.5 + 0.5 * np.sin(2 * np.pi * tvec / dur))
    fade_len = t(1.2)
    out[:fade_len] *= np.linspace(0, 1, fade_len)
    out[-fade_len:] *= np.linspace(1, 0, fade_len)
    return out * 0.5


if __name__ == "__main__":
    print("Generating Hokm SFX →", os.path.abspath(OUT))
    save("card_pick.wav", card_pick())
    save("card_place.wav", card_place())
    save("deal.wav", deal())
    save("shuffle.wav", shuffle())
    save("trick_win.wav", trick_win())
    save("button.wav", button())
    save("hukum.wav", hukum())
    save("round_win.wav", round_win())
    save("match_win.wav", match_win())
    save("match_lose.wav", match_lose())
    save("music_ambient.wav", music_ambient())
    print("Done.")
