"""Harvest Hollow outfits (#4251, the limited area, Wed Nov 25 to Sun Dec 6 2026): five cat wearables the Harvest
Stall swaps for pumpkins. Autumn and harvest only. All five sit on the head (never the neck), built about the cats'
existing Outfit_Hat spot (head top, front -Y) like storepacks.py's hats, so no cat model changes.

  CatCafe_Accessory_AcornHat       an acorn cap: a wide low tan cap with two rows of scales, a short stalk and an oak leaf
  CatCafe_Accessory_PumpkinHat     a little pumpkin worn as a hat, with a leaf and a curly vine
  CatCafe_Accessory_FeatherCap     a felt forest cap with a turned-up brim and one long striped feather
  CatCafe_Accessory_SunflowerHat   a big sunflower bloom on a short stem, facing front, two leaves at its foot
  CatCafe_Accessory_WheatWreath    a wreath of golden wheat ears round the head top with red berries (the Season 1
                                   Leaf Crown is the leafy one, so this one is wheat)
"""

import math

from mathutils import Matrix, Vector

from common import Builder

N = "CatCafe_"
ACCESSORY_SLOTS = {"AcornHat": "Hat", "PumpkinHat": "Hat", "FeatherCap": "Hat", "SunflowerHat": "Hat",
                   "WheatWreath": "Hat"}


def _rot(deg, axis):
    return Matrix.Rotation(math.radians(deg), 3, axis)


def build_acorn_hat(mat):
    b = Builder()
    b.cyl((0, 0, 0.07), 0.43, 0.14, "fur_toffee", segments=12, bevel=False, radius2=0.42)    # the cap, wide and low
    b.cyl((0, 0, 0.19), 0.42, 0.1, "fur_toffee", segments=12, bevel=False, radius2=0.26)
    for ring, (rad, z, n) in enumerate(((0.435, 0.07, 10), (0.36, 0.2, 8))):                 # scales, in two rows
        for k in range(n):
            a = 2 * math.pi * (k + 0.5 * ring) / n
            b.box((rad * math.cos(a), rad * math.sin(a), z), (0.05, 0.11, 0.08), "fur_brown", bevel=False,
                  rot=_rot(math.degrees(a), "Z") @ _rot(45, "X"))
    b.box((0, 0, 0.29), (0.09, 0.09, 0.12), "fur_seal", bevel=False)                        # a short straight stalk
    b.box((0.2, -0.05, 0.27), (0.24, 0.15, 0.03), "fur_orange", bevel=False, rot=_rot(25, "Z"))   # an oak leaf
    b.box((0.31, -0.01, 0.275), (0.12, 0.1, 0.028), "fur_orange", bevel=False, rot=_rot(60, "Z"))
    return [b.finalize(N + "Accessory_AcornHat", mat)]


def build_pumpkin_hat(mat):
    b = Builder()
    r = 0.34
    for k in range(6):                                                                       # six fat ribs
        a = math.radians(60 * k)
        b.ico((0.42 * r * math.cos(a), 0.42 * r * math.sin(a), 0.2), r * 0.68, "fur_marmalade", scale=(1, 1, 0.85))
    b.box((0, 0, 0.44), (0.09, 0.09, 0.15), "leaf_dark", bevel=False, rot=_rot(12, "Y"))    # stem
    b.box((0.15, -0.03, 0.43), (0.2, 0.12, 0.035), "leaf_green", bevel=False, rot=_rot(-20, "Y") @ _rot(20, "Z"))
    for k in range(4):                                                                       # the vine, in steps
        b.box((-0.1 - 0.035 * k, 0.03 * (k % 2), 0.45 + 0.04 * k), (0.04, 0.04, 0.05), "leaf_dark", bevel=False)
    return [b.finalize(N + "Accessory_PumpkinHat", mat)]


def build_feather_cap(mat):
    b = Builder()
    b.box((0, 0, 0.04), (0.84, 0.74, 0.08), "leaf_dark", bevel=False)                       # brim
    b.box((0, 0.02, 0.15), (0.64, 0.6, 0.16), "dumpster_green", bevel=False)                # crown
    b.box((0, 0.04, 0.27), (0.42, 0.44, 0.1), "dumpster_green", bevel=False)
    b.box((0, -0.37, 0.1), (0.84, 0.05, 0.14), "leaf_dark", bevel=False, rot=_rot(-12, "X"))  # turned-up front
    b.box((0, 0.02, 0.095), (0.66, 0.62, 0.05), "eye_amber", bevel=False)                   # the band
    a, c = Vector((0.3, 0.0, 0.1)), Vector((0.52, 0.5, 0.92))
    d = c - a
    R = d.to_track_quat("Z", "X").to_matrix()
    b.box(tuple((a + c) / 2), (0.035, 0.035, d.length), "fur_cream", bevel=False, rot=R)    # the quill
    for k in range(7):                                                                       # the vane, in bands
        f = 0.28 + 0.1 * k
        b.box(tuple(a + d * f), (0.24 - 0.04 * abs(k - 3), 0.03 + 0.002 * k, d.length * 0.1),
              ("fur_rust_red", "fur_custard", "fur_toffee")[k % 3], bevel=False, rot=R)
    return [b.finalize(N + "Accessory_FeatherCap", mat)]


def build_sunflower_hat(mat):
    b = Builder()
    tilt = _rot(-58, "X")                                                                   # the bloom faces front and up
    c = Vector((0, 0.06, 0.34))
    b.box((0, 0.1, 0.1), (0.07, 0.07, 0.2), "leaf_dark", bevel=False)                       # a short stem
    for sx, ang in ((-1, 25), (1, -25)):                                                    # two leaves at its foot
        b.box((sx * 0.24, 0.1, 0.04), (0.34, 0.2, 0.05), "leaf_green", bevel=False, rot=_rot(ang, "Z"))
    for k in range(12):                                                                      # two rings of petals
        a = math.radians(30 * k)
        out = 0.33 if k % 2 == 0 else 0.3
        b.box(tuple(c + tilt @ Vector((out * math.cos(a), out * math.sin(a), 0.012 * (k % 2)))),
              (0.24, 0.14, 0.04 + 0.004 * (k % 3)), ("eye_amber", "fur_golden")[k % 2], bevel=False,
              rot=tilt @ _rot(30 * k, "Z"))
    b.cyl(tuple(c + tilt @ Vector((0, 0, 0.04))), 0.22, 0.1, "fur_brown", segments=12, bevel=False, rot=tilt)
    b.cyl(tuple(c + tilt @ Vector((0, 0, 0.1))), 0.15, 0.04, "choco", segments=10, bevel=False, rot=tilt)
    return [b.finalize(N + "Accessory_SunflowerHat", mat)]


def build_wheat_wreath(mat):
    b = Builder()
    rx, ry, cy = 0.38, 0.32, 0.03
    n = 10
    for k in range(n):                                                                       # the straw band
        ta, tb = (2 * math.pi * t / n for t in (k, k + 1))
        pa = Vector((rx * math.cos(ta), cy + ry * math.sin(ta)))
        pb = Vector((rx * math.cos(tb), cy + ry * math.sin(tb)))
        m, d = (pa + pb) / 2, pb - pa
        b.box((m.x, m.y, 0.03), (d.length + 0.03, 0.05, 0.06), "fur_sand", bevel=False,
              rot=(math.atan2(d.y, d.x), "Z"))
    for k in range(8):                                                                       # wheat ears, leaning out
        a = math.radians(45 * k + 22.5)
        x, y = rx * math.cos(a), cy + ry * math.sin(a)
        R = _rot(math.degrees(a) - 90, "Z") @ _rot(-22, "X")
        base = Vector((x, y, 0.05))
        b.box(tuple(base + R @ Vector((0, 0, 0.08))), (0.03, 0.03, 0.16), "fur_sand", bevel=False, rot=R)
        for j in range(3):                                                                   # the grains
            b.box(tuple(base + R @ Vector((0, 0, 0.18 + 0.085 * j))), (0.12 - 0.02 * j, 0.07, 0.12 - 0.02 * j),
                  ("fur_golden", "eye_amber")[(k + j) % 2], bevel=False, rot=R @ _rot(45, "Y"))
    for x in (-0.08, 0.0, 0.08):                                                            # red berries at the front
        b.ico((x, cy - ry - 0.03, 0.06 + (0.03 if x == 0 else 0)), 0.045, "bowl_red")
    return [b.finalize(N + "Accessory_WheatWreath", mat)]


ASSETS = {
    N + "Accessory_AcornHat": (build_acorn_hat, 500),
    N + "Accessory_PumpkinHat": (build_pumpkin_hat, 600),
    N + "Accessory_FeatherCap": (build_feather_cap, 500),
    N + "Accessory_SunflowerHat": (build_sunflower_hat, 500),
    N + "Accessory_WheatWreath": (build_wheat_wreath, 700),
}
