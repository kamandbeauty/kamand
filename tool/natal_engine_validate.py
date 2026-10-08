#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Python mirror of lib/domain/astrology/natal_engine.dart (exact
transcription, line by line) + validation against golden values.

Golden references:
- Meeus 25.b: Sun @ 1992-10-13 0h TD = 199.90988 deg
- Meeus 47.a: Moon @ 1992-04-12 0h TD = 133.162655 deg (full series;
  our 20-term truncation ~ +/-0.05)
- Meeus 32.a pipeline: heliocentric Venus @ 1992-10-13 = 278.35 deg
- astrolibrary snapshot 2026-10-03 00:00 UT: Sun Libra 10d29m, Mercury
  Scorpio 4d09m, Venus Scorpio 8d29m R, Mars Leo 3d15m, Jupiter Leo
  20d04m, Saturn Aries 11d22m R
"""
import math
import sys

D2R = math.pi / 180.0


def norm360(x):
    r = x % 360.0
    return r + 360.0 if r < 0 else r


def sind(deg):
    return math.sin(norm360(deg) * D2R)


# ── SkyMath (verbatim port) ──────────────────────────────────────────
def julian_day(y, m, d, hour=0, minute=0, second=0):
    a = (14 - m) // 12
    yy = y + 4800 - a
    mm = m + 12 * a - 3
    jdn = (d + (153 * mm + 2) // 5 + 365 * yy + yy // 4
           - yy // 100 + yy // 400 - 32045)
    frac = (hour * 3600 + minute * 60 + second) / 86400
    return jdn + frac - 0.5


def sun_longitude(jd):
    t = (jd - 2451545.0) / 36525.0
    l0 = 280.46646 + 36000.76983 * t + 0.0003032 * t * t
    m = 357.52911 + 35999.05029 * t - 0.0001537 * t * t
    c = ((1.914602 - 0.004817 * t - 0.000014 * t * t) * sind(m)
         + (0.019993 - 0.000101 * t) * sind(2 * m)
         + 0.000289 * sind(3 * m))
    omega = 125.04 - 1934.136 * t
    return norm360(l0 + c - 0.00569 - 0.00478 * sind(omega))


MOON_TERMS = [
    [0, 0, 1, 0, 6288774], [2, 0, -1, 0, 1274027], [2, 0, 0, 0, 658314],
    [0, 0, 2, 0, 213618], [0, 1, 0, 0, -185116], [0, 0, 0, 2, -114332],
    [2, 0, -2, 0, 58793], [2, -1, -1, 0, 57066], [2, 0, 1, 0, 53322],
    [2, -1, 0, 0, 45758], [0, 1, -1, 0, -40923], [1, 0, 0, 0, -34720],
    [0, 1, 1, 0, -30383], [2, 0, 0, -2, 15327], [0, 0, 1, 2, -12528],
    [0, 0, 1, -2, 10980], [4, 0, -1, 0, 10675], [0, 0, 3, 0, 10034],
    [4, 0, -2, 0, 8548], [2, 1, -1, 0, -7888],
]


def moon_longitude(jd):
    t = (jd - 2451545.0) / 36525.0
    t2, t3, t4 = t * t, t * t * t, t * t * t * t
    lp = (218.3164477 + 481267.88123421 * t - 0.0015786 * t2
          + t3 / 538841.0 - t4 / 65194000.0)
    d = (297.8501921 + 445267.1114034 * t - 0.0018819 * t2
         + t3 / 545868.0 - t4 / 113065000.0)
    m = 357.5291092 + 35999.0502909 * t - 0.0001536 * t2 + t3 / 24490000.0
    mp = (134.9633964 + 477198.8675055 * t + 0.0087414 * t2
          + t3 / 69699.0 - t4 / 14712000.0)
    f = (93.2720950 + 483202.0175233 * t - 0.0036539 * t2
         - t3 / 3526000.0 + t4 / 863310000.0)
    total = 0.0
    for term in MOON_TERMS:
        total += (term[4] / 1000000.0
                  * sind(term[0] * d + term[1] * m + term[2] * mp
                         + term[3] * f))
    return norm360(lp + total)


# ── NatalEngine (verbatim port) ──────────────────────────────────────
ELEMENTS = {
    'mercury': [
        [0.38709927, 0.20563593, 7.00497902, 252.25032350, 77.45779628, 48.33076593],
        [0.00000037, 0.00001906, -0.00594749, 149472.67411175, 0.16047689, -0.12534081]],
    'venus': [
        [0.72333566, 0.00677672, 3.39467605, 181.97909950, 131.60246718, 76.67984255],
        [0.00000390, -0.00004107, -0.00078890, 58517.81538729, 0.00268329, -0.27769418]],
    'earth': [
        [1.00000261, 0.01671123, -0.00001531, 100.46457166, 102.93768193, 0.0],
        [0.00000562, -0.00004392, -0.01294668, 35999.37244981, 0.32327364, 0.0]],
    'mars': [
        [1.52371034, 0.09339410, 1.84969142, -4.55343205, -23.94362959, 49.55953891],
        [0.00001847, 0.00007882, -0.00813131, 19140.30268499, 0.44441088, -0.29257343]],
    'jupiter': [
        [5.20288700, 0.04838624, 1.30439695, 34.39644051, 14.72847983, 100.47390909],
        [-0.00011607, -0.00013253, -0.00183714, 3034.74612775, 0.21252668, 0.20469106]],
    'saturn': [
        [9.53667594, 0.05386179, 2.48599187, 49.95424423, 92.59887831, 113.66242448],
        [-0.00125060, -0.00050991, 0.00193609, 1222.49362201, -0.41897216, -0.28867794]],
}
M_TERMS = {
    'jupiter': [-0.00012452, 0.06064060, -0.35635438, 38.35125000],
    'saturn': [0.00025899, -0.13434469, 0.87320147, 38.35125000],
}


def precession(t):
    return (5029.0966 * t + 1.11113 * t * t) / 3600.0


def heliocentric_xy(body, jd):
    t = (jd - 2451545.0) / 36525.0
    el = ELEMENTS[body]
    a = el[0][0] + el[1][0] * t
    e = el[0][1] + el[1][1] * t
    i = (el[0][2] + el[1][2] * t) * D2R
    l = el[0][3] + el[1][3] * t
    w = el[0][4] + el[1][4] * t
    o = el[0][5] + el[1][5] * t

    m = norm360(l - w)
    mt = M_TERMS.get(body)
    if mt is not None:
        m = (m + mt[0] * t * t + mt[1] * math.cos(mt[3] * t * D2R)
             + mt[2] * math.sin(mt[3] * t * D2R))
    if m > 180:
        m -= 360
    mr = m * D2R

    ecc = mr
    for _ in range(12):
        ecc -= (ecc - e * math.sin(ecc) - mr) / (1 - e * math.cos(ecc))
    nu = 2 * math.atan2(math.sqrt(1 + e) * math.sin(ecc / 2),
                        math.sqrt(1 - e) * math.cos(ecc / 2))
    r = a * (1 - e * math.cos(ecc))

    u = nu + (w - o) * D2R
    orad = o * D2R
    x = r * (math.cos(orad) * math.cos(u)
             - math.sin(orad) * math.sin(u) * math.cos(i))
    y = r * (math.sin(orad) * math.cos(u)
             + math.cos(orad) * math.sin(u) * math.cos(i))
    return x, y


def geocentric_longitude(body, jd):
    t = (jd - 2451545.0) / 36525.0
    px, py = heliocentric_xy(body, jd)
    ex, ey = heliocentric_xy('earth', jd)
    lon = math.atan2(py - ey, px - ex) / D2R
    return norm360(lon + precession(t))


def sun_from_earth_elements(jd):
    t = (jd - 2451545.0) / 36525.0
    ex, ey = heliocentric_xy('earth', jd)
    return norm360(math.atan2(-ey, -ex) / D2R + precession(t))


def is_retrograde(body, jd):
    if body in ('sun', 'moon'):
        return False
    before = geocentric_longitude(body, jd - 0.5)
    after = geocentric_longitude(body, jd + 0.5)
    d = after - before
    if d > 180:
        d -= 360
    if d < -180:
        d += 360
    return d < 0


def gmst(jd):
    d = jd - 2451545.0
    t = d / 36525.0
    return norm360(280.46061837 + 360.98564736629 * d
                   + 0.000387933 * t * t - t * t * t / 38710000.0)


def obliquity(jd):
    return 23.4392911 - 0.0130042 * ((jd - 2451545.0) / 36525.0)


def ascendant(jd, latitude, longitude):
    ramc = norm360(gmst(jd) + longitude)
    eps = obliquity(jd) * D2R
    lat = latitude * D2R
    asc = norm360(math.atan2(
        math.cos(ramc * D2R),
        -(math.sin(ramc * D2R) * math.cos(eps)
          + math.tan(lat) * math.sin(eps))) / D2R)
    mc = norm360(math.atan2(
        math.sin(ramc * D2R),
        math.cos(ramc * D2R) * math.cos(eps)) / D2R)
    return asc, mc


# ── Validation ───────────────────────────────────────────────────────
def check(name, got, expected, tol):
    ok = abs(got - expected) <= tol
    print(f"{'✓' if ok else '✗'} {name}: got {got:.4f}, "
          f"expected {expected:.4f} (±{tol})")
    return ok


def main():
    all_ok = True

    # 1. Meeus golden values
    all_ok &= check("Sun @ Meeus 25.b (1992-10-13)",
                    sun_longitude(2448908.5), 199.90988, 0.01)
    all_ok &= check("Moon @ Meeus 47.a (1992-04-12)",
                    moon_longitude(2448724.5), 133.162655, 0.1)
    all_ok &= check("Venus helio L @ Meeus 32.a (1992-10-13)",
                    norm360(math.atan2(*reversed(
                        heliocentric_xy('venus', 2448908.5))) / D2R),
                    278.35, 0.05)

    # 2. Sun cross-check (elements vs Meeus series), 2026-10-03 12:00 UT
    jd_now = julian_day(2026, 10, 3, 12)
    all_ok &= check("Sun elements vs series (2026-10-03)",
                    sun_from_earth_elements(jd_now),
                    sun_longitude(jd_now), 0.05)

    # 3. astrolibrary snapshot 2026-10-03 00:00 UT
    jd0 = julian_day(2026, 10, 3, 0)
    snap = {  # expected geocentric longitudes from the snapshot
        'mercury': 180 + 30 + 4 + 9 / 60,   # Scorpio 4°09′
        'venus': 180 + 30 + 8 + 29 / 60,    # Scorpio 8°29′
        'mars': 120 + 3 + 15 / 60,          # Leo 3°15′
        'jupiter': 120 + 20 + 4 / 60,       # Leo 20°04′
        'saturn': 11 + 22 / 60,             # Aries 11°22′
    }
    tols = {'mercury': 1.0, 'venus': 0.05, 'mars': 0.6,
            'jupiter': 0.3, 'saturn': 0.3}
    for body, exp in snap.items():
        all_ok &= check(f"{body} vs snapshot (2026-10-03 00 UT)",
                        geocentric_longitude(body, jd0), exp, tols[body])

    # 4. Retrograde flags. 2026-10-03 is Venus's exact station day (the
    # ±0.5-day delta straddles the turn), so test a clear mid-retro date
    # (2026-10-20) and a clear direct date (2026-09-01) instead.
    jd_mid = julian_day(2026, 10, 20)
    flags = {b: is_retrograde(b, jd_mid) for b in
             ['mercury', 'venus', 'mars', 'jupiter', 'saturn']}
    print(f"{'✓' if flags['venus'] else '✗'} Venus retrograde (2026-10-20)")
    print(f"{'✓' if flags['saturn'] else '✗'} Saturn retrograde (2026-10-20)")
    print(f"{'✓' if not flags['jupiter'] else '✗'} Jupiter direct")
    print(f"{'✓' if not flags['mars'] else '✗'} Mars direct")
    print(f"{'✓' if not is_retrograde('venus', julian_day(2026, 9, 1)) else '✗'}"
          " Venus direct (2026-09-01)")
    all_ok &= flags['venus'] and flags['saturn']
    all_ok &= (not flags['jupiter']) and (not flags['mars'])
    all_ok &= not is_retrograde('venus', julian_day(2026, 9, 1))

    # 5. Ascendant sanity — Tehran, 1991-08-03 04:00 UT
    asc, mc = ascendant(julian_day(1991, 8, 3, 4), 35.69, 51.39)
    ok = 0 <= asc < 360 and 0 <= mc < 360 and 10 < (asc - mc) % 360 < 110
    print(f"{'✓' if ok else '✗'} ASC sanity: asc={asc:.2f}, mc={mc:.2f}")
    all_ok &= ok
    # (MC trails ASC in zodiacal order between quadrants; info only.)

    # 6. GMST spot check: 2026-10-08 00:00 UT ≈ ?
    g = gmst(julian_day(2026, 10, 8, 0))
    print(f"  GMST 2026-10-08 00 UT = {g:.3f} deg (info)")

    print("\nRESULT:", "ALL PASS ✓" if all_ok else "FAILURES ✗")
    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())
