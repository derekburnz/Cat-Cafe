"""Cafe Event reward decor (#2486, #2488; Catalog.eventDecor, #2534): free pieces given for catching a cat during a
Cafe Event, never sold. They stand on a decor spot like every crate piece (crate_decor.py): about 4 wide and 2.5 deep
round the pivot, base centre, front -Z, nothing collides.

  CatCafe_Decor_PartyBunting   (Rare decoration, "Party Bunting") two candy-striped poles on round feet, each topped
                               with a little party hat, and a sagging string of rainbow pennants between them, each
                               flag its own Model `_FlagNN_Pennant` (VFX-Agent's bunting flutter: `_Pennant` inside a
                               Model named *Bunting*; a placed piece takes its decor id, Decor_PartyBunting, as its
                               name); three balloons tied to the left pole, a wrapped gift at the right foot and
                               confetti on both feet. The Cafe Party's colours, the event picture's rainbow.
"""

import math

from common import RB
from plot import rot_y, rot_z

FLAGS = ("rarity_mythic", "rarity_legend", "leaf_green", "rarity_rare", "rarity_epic", "fur_orange")
POLE_X, POLE_TOP, LINE_Y, SAG = 1.6, 3.3, 3.0, 0.38
NAME = "CatCafe_Decor_PartyBunting"


def _line_y(x):
    return LINE_Y - SAG * (1 - (x / (POLE_X - 0.07)) ** 2)


def _confetti(b, x, y, k):
    """Flat confetti bits lying on a foot top at height y round (x, 0)."""
    for i, (dx, dz, a) in enumerate(((-0.18, -0.12, 20), (0.12, -0.2, -35), (0.2, 0.08, 60), (-0.1, 0.18, -10),
                                     (0.0, -0.26, 80))):
        b.box((x + dx, y + 0.012 + 0.002 * i, dz), (0.1, 0.02, 0.05), FLAGS[(i + k) % len(FLAGS)],
              rot=rot_y(a))


def build_party_bunting(mat):
    b = RB()
    for s in (-1, 1):
        x = s * POLE_X
        b.cyl((x, 0.08, 0.0), 0.34, 0.16, "offwhite", segments=14)                             # round foot
        b.cyl((x, 0.17, 0.0), 0.3, 0.02, "rarity_mythic" if s < 0 else "rarity_rare", segments=14)
        b.span((x - 0.07, 0.18, -0.07), (x + 0.07, POLE_TOP, 0.07), "offwhite")                 # pole
        for y in (0.5, 1.05, 1.6, 2.15, 2.7):                                                   # candy stripes
            b.span((x - 0.085, y, -0.085), (x + 0.085, y + 0.22, 0.085), "rarity_mythic")
        b.cyl((x, POLE_TOP + 0.03, 0.0), 0.2, 0.06, "rarity_legend", segments=12)              # hat brim
        b.cyl((x, POLE_TOP + 0.3, 0.0), 0.17, 0.5, "rarity_rare" if s < 0 else "rarity_epic", r2=0.015,
              segments=12)                                                                     # party hat
        b.span((x - 0.18, POLE_TOP + 0.14, -0.012), (x + 0.18, POLE_TOP + 0.2, 0.012), "rarity_legend")  # hat band
        b.ball((x, POLE_TOP + 0.59, 0.0), 0.075, "rarity_legend")                              # pom on top
        _confetti(b, x, 0.18, 0 if s < 0 else 3)
    half = POLE_X - 0.07
    n = 10
    xs = [-half + 2 * half * k / n for k in range(n + 1)]
    for xa, xb in zip(xs, xs[1:]):                                                             # the cord
        ya, yb = _line_y(xa), _line_y(xb)
        length = math.hypot(xb - xa, yb - ya) + 0.04
        ang = math.degrees(math.atan2(yb - ya, xb - xa))
        b.box(((xa + xb) / 2, (ya + yb) / 2, 0), (length, 0.05, 0.05), "pastel_butter", rot=rot_z(ang))
    # three balloons tied to the left pole just under its hat, floating up and out
    knot = (-POLE_X - 0.05, 2.95, 0.0)
    for bx, by, bz, sw in ((-1.8, 3.75, 0.15, "rarity_mythic"), (-1.45, 4.0, -0.12, "rarity_rare"),
                           (-2.0, 3.45, -0.18, "leaf_green")):
        b.ball((bx, by, bz), 0.24, sw, scale=(1, 1.18, 1))
        b.cyl((bx, by - 0.3, bz), 0.05, 0.08, sw, r2=0.015, segments=8)                    # the tied neck
        dx, dy, dz = bx - knot[0], (by - 0.34) - knot[1], bz - knot[2]
        L = math.sqrt(dx * dx + dy * dy + dz * dz)
        mid = ((bx + knot[0]) / 2, (by - 0.34 + knot[1]) / 2, (bz + knot[2]) / 2)
        tilt = math.degrees(math.atan2(-dx, dy))
        b.box(mid, (0.02, L, 0.02), "offwhite", rot=rot_z(tilt))                               # string
    # a wrapped gift at the right foot, in front of the pole
    gx, gz, g = POLE_X + 0.25, -0.5, 0.42
    b.span((gx - g / 2, 0.0, gz - g / 2), (gx + g / 2, g, gz + g / 2), "rarity_epic")
    b.span((gx - 0.05, 0.0, gz - g / 2 - 0.01), (gx + 0.05, g + 0.01, gz + g / 2 + 0.01), "rarity_legend")
    b.span((gx - g / 2 - 0.01, 0.0, gz - 0.05), (gx + g / 2 + 0.01, g + 0.012, gz + 0.05), "rarity_legend")
    for s in (-1, 1):                                                                          # the bow
        b.ball((gx + s * 0.09, g + 0.06, gz), 0.075, "rarity_legend", scale=(1.3, 0.7, 0.8))
    out = [b.finalize(NAME, mat)]
    count = 7
    for k in range(count):                       # each flag its own Model, pivot on the cord (VFX flutter, #640)
        x = -1.25 + k * 2.5 / (count - 1)
        xl, xr = x - 0.19, x + 0.19
        yl, yr = _line_y(xl) - 0.025, _line_y(xr) - 0.025
        ym = (yl + yr) / 2
        flag = RB()
        flag.fan_z(0.0, (0, -0.5), [(xl - x, yl - ym), (xr - x, yr - ym)], 0.04, FLAGS[k % len(FLAGS)])
        out.append(flag.finalize(f"{NAME}_Flag{k + 1:02d}_Pennant", mat, location=(x, ym, 0)))
    return out


ASSETS = {NAME: (build_party_bunting, 2400)}
