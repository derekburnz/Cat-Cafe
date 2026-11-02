"""The golden fish coin (golden-fish.md section 1, F52), the rare currency: a cute round gold coin with a cat face
and a tiny fish in its mouth on the front, and a fish on the back, so it has heads and tails.

  CatCafe_Prop_FishCoin   stands on its rim, the cat face toward -Z; pivot at the base centre, so it spins about
                          its own upright axis. The same model is the world pickup and the HUD picture (icons.py).
"""

import math

from common import RB
from plot import rot_z

R, T = 1.0, 0.24                 # the coin's radius and thickness
CY = R                           # its centre height
LIP = 0.13                       # the light rim showing around each face
FACE, RIM, LINE = "gold_mid", "gold_light", "gold_dark"
FISH = "gold_light"
INK = "fur_black"


def _arc(b, cx, cy, z, r, a0, a1, n, w, d, swatch):
    """A smooth curved stroke w wide around radius r, from angle a0 to a1 (degrees) in n steps, lying on a face at
    depth z: two triangles a step, so the line has no box corners sticking out."""
    def pt(t, rr):
        return (cx + rr * math.cos(math.radians(t)), cy + rr * math.sin(math.radians(t)))
    ts = [a0 + (a1 - a0) * k / n for k in range(n + 1)]
    for t0, t1 in zip(ts, ts[1:]):
        b.fan_z(z, pt(t0, r + w / 2), [pt(t0, r - w / 2), pt(t1, r - w / 2), pt(t1, r + w / 2)], d, swatch)


def _ears(b):
    """Two ears behind the rim, pink inside on the cat's side."""
    def at(a, r):
        return (r * math.cos(math.radians(a)), CY + r * math.sin(math.radians(a)))
    for sx in (-1, 1):
        def m(p):
            return (sx * p[0], p[1])
        b.fan_z(0.0, m(at(54, 1.44)), [m(at(28, R - 0.12)), m(at(80, R - 0.12))], T - 0.08, RIM)
        b.fan_z(-(T - 0.08) / 2 - 0.01, m(at(54, 1.3)), [m(at(38, R - 0.05)), m(at(70, R - 0.05))], 0.03, "blush")


def _heads(b, z):
    """The cat face on the front face (its surface at depth z, toward -Z), a tiny fish held in the mouth."""
    for sx in (-1, 1):
        b.cyl((sx * 0.34, CY + 0.13, z - 0.02), 0.14, 0.06, INK, axis="Z", segments=12)              # eyes
        b.cyl((sx * 0.34 + 0.05, CY + 0.19, z - 0.055), 0.045, 0.02, "offwhite", axis="Z", segments=8)
        for dy, a in ((0.02, 8), (-0.09, -8)):                                                         # whiskers
            b.box((sx * 0.67, CY - 0.04 + dy, z - 0.01), (0.25, 0.028, 0.03), LINE, rot=rot_z(sx * a))
    b.fan_z(z - 0.015, (0, CY - 0.05), [(0.08, CY + 0.03), (-0.08, CY + 0.03)], 0.05, "nose_pink")    # nose
    for sx in (-1, 1):                                                                                 # the w mouth
        _arc(b, sx * 0.075, CY - 0.07, z - 0.01, 0.075, 180, 360, 6, 0.045, 0.04, INK)
    fy = CY - 0.27                                                                                     # the fish
    b.ball((0.0, fy, z - 0.02), 0.28, FISH, scale=(1.0, 0.42, 0.3))
    b.fan_z(z - 0.02, (0.24, fy), [(0.46, fy + 0.15), (0.39, fy), (0.46, fy - 0.15)], 0.05, FISH)
    b.cyl((-0.16, fy + 0.02, z - 0.09), 0.036, 0.02, INK, axis="Z", segments=8)


def _tails(b, z):
    """A bigger fish on the back face (its surface at depth z, toward +Z), with three bubbles."""
    fx, fy = -0.08, CY - 0.05
    b.ball((fx, fy, z + 0.02), 0.46, FISH, scale=(1.0, 0.5, 0.16))
    b.fan_z(z + 0.02, (fx - 0.38, fy), [(fx - 0.7, fy - 0.24), (fx - 0.6, fy), (fx - 0.7, fy + 0.24)], 0.05, FISH)
    b.fan_z(z + 0.015, (fx - 0.05, fy + 0.2), [(fx + 0.18, fy + 0.2), (fx - 0.12, fy + 0.36)], 0.04, FISH)   # fin
    b.cyl((fx + 0.27, fy + 0.04, z + 0.075), 0.05, 0.02, INK, axis="Z", segments=8)                   # eye
    _arc(b, fx + 0.02, fy, z + 0.095, 0.14, -50, 50, 4, 0.03, 0.03, LINE)                             # gill
    for (x, y, r) in ((0.5, CY + 0.28, 0.07), (0.6, CY + 0.47, 0.05), (0.5, CY + 0.62, 0.035)):
        b.cyl((x, y, z + 0.01), r, 0.03, RIM, axis="Z", segments=8)


def build_fish_coin(mat, name="CatCafe_Prop_FishCoin"):
    """The coin, or a copy under another object name (the Fish Market's sign)."""
    b = RB()
    b.cyl((0, CY, 0), R, T, RIM, axis="Z", segments=24)                                                # rim and edge
    for s in (-1, 1):                                                                                  # the two faces
        b.cyl((0, CY, s * (T / 2 + 0.005)), R - LIP, 0.03, FACE, axis="Z", segments=24)
    _ears(b)
    zf = T / 2 + 0.02
    _heads(b, -zf)
    _tails(b, zf)
    return [b.finalize(name, mat)]


ASSETS = {"CatCafe_Prop_FishCoin": (build_fish_coin, 1200)}
