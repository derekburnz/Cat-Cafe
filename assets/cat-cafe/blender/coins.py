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


# ---------------------------------------------------------------------------------------------- Fish Fountain --
# #4889 (Derek 2026-11-16: "make the admin fountain event spawn a gold fish fountain but no ontop of the cannon and
# make it actual gold fish models that pop out now just gold bars"): the fountain that stands in the Town Square
# while the Fish Fountain admin event runs, and the golden fish it throws out (AdminDropService).
#   CatCafe_Square_FishFountain   about 9.6 across and 10 tall: an eight sided gold basin on a step, navy tiles on
#                                 its wall with a gold paw on the four main sides, water in it (_Water), a pedestal,
#                                 a gold bowl with its own water, and a big golden fish leaping from it, head up, a
#                                 glowing jet from its mouth and glowing drops (_Glow). Pivot base centre.
#   CatCafe_Prop_GoldenFish       the pickup: a chunky golden fish about 2 long, tipped up a little on a small
#                                 glowing puddle of sparkle (_Glow), its side toward -Z. Pivot base centre.
FOUNTAIN = "CatCafe_Square_FishFountain"
GOLDEN_FISH = "CatCafe_Prop_GoldenFish"


def _gold_fish(b, cx, cy, cz, s, rot=None, eye=True):
    """A chunky fish s long, nose toward +X, centred at (cx, cy, cz), turned by `rot` about its centre."""
    def put(dx, dy, dz, size, swatch, extra=None):
        v = (dx * s, dy * s, dz * s)
        if rot is not None:
            from mathutils import Vector
            w = rot @ Vector(v)
            v = (w.x, w.y, w.z)
        r = rot if extra is None else (rot @ extra if rot is not None else extra)
        b.box((cx + v[0], cy + v[1], cz + v[2]), tuple(k * s for k in size), swatch, rot=r)
    put(0.0, 0.0, 0.0, (0.56, 0.36, 0.26), "gold_mid")               # body
    put(0.0, 0.0, 0.0, (0.4, 0.44, 0.22), "gold_mid")                # its deeper middle
    put(0.3, 0.0, 0.0, (0.18, 0.3, 0.24), "gold_light")              # head
    put(0.42, -0.02, 0.0, (0.1, 0.18, 0.18), "gold_light")           # nose
    put(0.475, -0.05, 0.0, (0.03, 0.07, 0.12), "gold_dark")          # mouth
    put(-0.33, 0.0, 0.0, (0.16, 0.2, 0.16), "gold_mid")              # tail stem
    put(-0.5, 0.15, 0.0, (0.32, 0.15, 0.08), "gold_dark", rot_z(-40))  # forked tail
    put(-0.5, -0.15, 0.0, (0.32, 0.15, 0.08), "gold_dark", rot_z(40))
    put(-0.04, 0.26, 0.0, (0.3, 0.1, 0.06), "gold_dark")             # back fin
    put(0.02, -0.25, 0.0, (0.14, 0.08, 0.06), "gold_dark")           # belly fin
    for sz in (-1, 1):
        put(0.08, -0.06, sz * 0.15, (0.16, 0.1, 0.04), "gold_dark", rot_z(-25))   # side fins
        if eye:
            put(0.31, 0.06, sz * 0.125, (0.08, 0.08, 0.02), "fur_black")


def build_fish_fountain(mat):
    b, water, glow = RB(), RB(), RB()
    b.cyl((0, 0.15, 0), 4.8, 0.3, "gold_dark", segments=8)                       # the step
    b.cyl((0, 0.85, 0), 4.2, 1.1, "gold_mid", segments=8)                        # the basin, solid under the water
    b.cyl((0, 1.5, 0), 4.45, 0.24, "gold_light", segments=8)                     # coping
    for k in range(8):                                                           # a navy tile on each side
        a = math.radians(45 * k)
        r = 4.2 * math.cos(math.pi / 8) + 0.02
        from plot import rot_y
        b.box((r * math.cos(a), 0.85, r * math.sin(a)), (0.06, 0.7, 2.5), "pants_navy", rot=rot_y(-math.degrees(a)))
        if k % 2 == 0:                                                           # a glowing paw on the four main sides
            glow.box((r * math.cos(a) * 1.01, 0.85, r * math.sin(a) * 1.01), (0.06, 0.34, 0.5), "rarity_legend",
                     rot=rot_y(-math.degrees(a)))
    water.cyl((0, 1.66, 0), 3.9, 0.12, "fish_blue", segments=8)                  # pool, on the coping inside its rim
    b.cyl((0, 2.3, 0), 0.8, 1.6, "gold_mid", segments=8)                         # pedestal
    b.cyl((0, 1.75, 0), 0.95, 0.3, "gold_dark", segments=8)
    b.cyl((0, 3.4, 0), 0.8, 0.7, "gold_light", r2=2.2, segments=8)               # bowl
    b.cyl((0, 3.85, 0), 2.35, 0.22, "gold_dark", segments=8)                     # its lip
    water.cyl((0, 3.9, 0), 2.0, 0.2, "fish_blue", segments=8)
    for k in range(4):                                                           # four streams off the bowl
        a = math.radians(45 + 90 * k)
        water.box((2.3 * math.cos(a), 2.75, 2.3 * math.sin(a)), (0.3, 2.3, 0.3), "fish_blue")
    _gold_fish(b, 0.0, 6.0, 0.0, 4.2, rot=rot_z(70))                             # the leaping fish, head up
    b.span((-0.35, 3.9, -0.35), (0.35, 4.5, 0.35), "gold_dark")                  # the splash it stands on
    for (x, y, z, r) in ((0.75, 8.6, 0.0, 0.34), (1.0, 9.3, 0.15, 0.26), (0.8, 9.9, -0.15, 0.2)):   # the jet
        glow.box((x, y, z), (r, r, r), "lamp_warm", rot=rot_z(45))
    for k in range(6):                                                           # coins of light on the water
        a = math.radians(20 + 60 * k)
        glow.box((3.0 * math.cos(a), 1.75, 3.0 * math.sin(a)), (0.3, 0.06, 0.3), "rarity_legend")
    return [b.finalize(FOUNTAIN, mat), water.finalize(FOUNTAIN + "_Water", mat), glow.finalize(FOUNTAIN + "_Glow", mat)]


def build_golden_fish(mat):
    b, glow = RB(), RB()
    _gold_fish(b, 0.0, 0.85, 0.0, 2.0, rot=rot_z(18))
    glow.cyl((0, 0.04, 0), 0.9, 0.08, "rarity_legend", segments=8)
    return [b.finalize(GOLDEN_FISH, mat), glow.finalize(GOLDEN_FISH + "_Glow", mat)]


ASSETS = {"CatCafe_Prop_FishCoin": (build_fish_coin, 1200), FOUNTAIN: (build_fish_fountain, 2500),
          GOLDEN_FISH: (build_golden_fish, 400)}
