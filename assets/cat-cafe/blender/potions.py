"""Potion bottles (F64 and F73: data-model.md 12b, quests.md 4), one per potion in Catalog.potions.

Each is `CatCafe_Prop_Potion_<Name>`, the id without "_potion" in PascalCase (tip_potion is Tip, big_tip_potion
is BigTip), so the code can build the name from the id. The liquid is the potion's own colour (UI
Theme.potionColors and the Effects glow), so the bag tile, the drink pop and the bottle agree. Every bottle has a
glass neck, a cork or cap and a badge on its front that says what it does: a coin for tips, a clover for luck,
wings for speed, a paw for steady paws, a coin pair and a gold cap for the big tip, a star for gold luck and a fish
with a clock for quicker bait. Pivot base centre, front -Z, nothing collides; about 1.2 to 1.6 tall.
"""

import math

from mathutils import Matrix

from common import RB


def _sphere(b, c, r, swatch, scale=(1, 1, 1), seg=12, rings=8):
    """A smooth (UV) sphere at Roblox c; scale is Roblox (x, y, z)."""
    b.b.sphere(RB.p(*c), r, swatch, segments=seg, rings=rings, scale=(scale[0], scale[2], scale[1]))


def _disc(b, x, y, z0, z1, r, swatch, seg=12):
    """A disc facing -Z (a badge on the front) from depth z0 (inside) out to z1 (its face)."""
    b.cyl((x, y, (z0 + z1) / 2), r, abs(z1 - z0), swatch, axis="Z", segments=seg)


def _zrot(deg):
    return Matrix.Rotation(math.radians(deg), 3, "Z")


def _top(b, y, r_neck, h_neck, r_lip, cork="treat_tan", h_cork=0.17, lip="glass", seg=10):
    """A glass neck standing at y, a lip round its top and a cork pushed into it. Returns the cork's top."""
    b.cyl((0, y + h_neck / 2, 0), r_neck, h_neck, "glass", segments=seg)
    yl = y + h_neck
    b.cyl((0, yl, 0), r_lip, 0.05, lip, segments=seg)
    b.cyl((0, yl - 0.02 + h_cork / 2, 0), r_neck * 0.8, h_cork, cork, segments=seg)
    return yl - 0.02 + h_cork


def _bottle(b, r, y0, y1, liquid, label=None, shoulder=0.14, seg=14):
    """A straight bottle: a glass foot, a liquid body from y0 to y1 with an optional label band and a domed
    shoulder (half a squashed sphere, so it stays round as a Roblox Part). Returns the dome's top."""
    b.cyl((0, y0 / 2, 0), r + 0.01, y0, "glass", segments=seg)
    b.cyl((0, (y0 + y1) / 2, 0), r, y1 - y0, liquid, segments=seg)
    _sphere(b, (0, y1, 0), r, liquid, scale=(1, shoulder / r, 1), seg=seg, rings=6)
    if label:
        lo, hi, sw = label
        b.cyl((0, (lo + hi) / 2, 0), r + 0.012, hi - lo, sw, segments=seg)
    return y1 + shoulder


def _glint(b, r, y, h, zc=0.0):
    """A thin white highlight on a round body of radius r (axis at z zc), up and to the viewer's left of centre."""
    x = 0.45 * r
    b.box((x, y, zc - (r * 0.89 + 0.01)), (0.045, h, 0.04), "milk")


def _coin(b, x, y, zf, r, depth=0.03):
    """A gold coin facing -Z with its face at zf and a raised middle."""
    _disc(b, x, y, zf + depth, zf, r, "gold_mid")
    _disc(b, x, y, zf + 0.005, zf - 0.012, r * 0.6, "gold_dark", seg=10)


def tip(b):
    """Tip Potion: a round gold flask with a coin on a cream badge."""
    _sphere(b, (0, 0.46, 0), 0.44, "rarity_legend")
    b.cyl((0, 0.03, 0), 0.24, 0.06, "glass", segments=12)
    _top(b, 0.8, 0.13, 0.27, 0.16)
    _disc(b, 0, 0.44, -0.37, -0.45, 0.2, "cream", seg=14)
    _coin(b, 0, 0.44, -0.475, 0.13)
    b.box((0.22, 0.68, -0.33), (0.05, 0.15, 0.05), "milk", rot=_zrot(-35))      # glint
    b.box((0.29, 0.56, -0.33), (0.05, 0.05, 0.05), "milk")


def lucky(b):
    """Lucky Potion: a tall green bottle with a four-leaf clover on a cream label."""
    top = _bottle(b, 0.3, 0.04, 0.74, "eye_green", label=(0.2, 0.6, "cream"), shoulder=0.16, seg=16)
    _top(b, top - 0.02, 0.11, 0.24, 0.14)
    zf = -0.335
    for dx, dy in ((0.065, 0.065), (-0.065, 0.065), (0.065, -0.065), (-0.065, -0.065)):
        _disc(b, dx, 0.43 + dy, -0.27, zf, 0.075, "leaf_green", seg=10)
    _disc(b, 0, 0.43, -0.3, zf - 0.008, 0.03, "leaf_dark", seg=8)
    b.box((-0.04, 0.28, -0.315), (0.03, 0.12, 0.03), "leaf_dark", rot=_zrot(-25))  # stem
    _glint(b, 0.3, 0.67, 0.1)


def swift(b):
    """Swift Potion: a slim blue bottle with a little white wing on each side and a yellow bolt on the front."""
    top = _bottle(b, 0.22, 0.04, 0.86, "rarity_rare", shoulder=0.12)
    _top(b, top - 0.02, 0.085, 0.22, 0.11)
    for sign in (1, -1):                                       # wings: three feathers each, sweeping up and out
        for k, (length, y) in enumerate(((0.3, 0.64), (0.24, 0.57), (0.17, 0.5))):
            ang = sign * (24 - 5 * k)
            x = sign * (0.18 + length / 2 * math.cos(math.radians(abs(ang))))
            yy = y + length / 2 * math.sin(math.radians(abs(ang)))
            b.box((x, yy, 0.012 * k), (length, 0.1, 0.05), "milk", rot=_zrot(ang))
    # the bolt, as the viewer sees it (u to the right, so x = -u): a slanted top, a step and a point
    bolt = {"A": (-0.02, 0.6), "B": (0.08, 0.6), "C": (0.03, 0.44), "D": (0.09, 0.44), "E": (-0.05, 0.22),
            "F": (-0.01, 0.38), "G": (-0.07, 0.38)}
    for tri in ("ABC", "ACG", "GFD", "GDC", "FDE"):
        p0, p1, p2 = ((-bolt[k][0], bolt[k][1]) for k in tri)
        b.fan_z(-0.235, p0, [p1, p2], 0.03, "rarity_legend")
    _glint(b, 0.22, 0.74, 0.12)


def steady(b):
    """Steady Paw Potion: a squat mint jar with a wooden lid and a brown paw on a cream badge."""
    top = _bottle(b, 0.36, 0.04, 0.6, "mint", shoulder=0.12, seg=16)
    b.cyl((0, top + 0.01, 0), 0.2, 0.1, "glass", segments=14)
    b.cyl((0, top + 0.1, 0), 0.24, 0.1, "caramel_wood", segments=14)
    b.cyl((0, top + 0.18, 0), 0.07, 0.07, "dark_wood", segments=8)
    _disc(b, 0, 0.33, -0.3, -0.4, 0.19, "cream", seg=14)
    zf, s, cy = -0.42, 0.24, 0.33                               # the paw: a pad and four toes
    b.b.cyl(RB.p(0, cy - 0.06, (-0.39 + zf) / 2), 0.07, 0.03, "choco", segments=12, bevel=False,
            rot=(math.radians(-90), "X"), scale=(1.3, 1, 1))
    for tx, ty in ((-0.42, 0.18), (-0.15, 0.38), (0.15, 0.38), (0.42, 0.18)):
        _disc(b, tx * s, cy + ty * s, -0.39, zf, 0.033, "choco", seg=8)
    _glint(b, 0.36, 0.5, 0.1)


def big_tip(b):
    """Big Tip Potion: the Tip flask grown bigger, amber, with a gold stopper and two coins on its badge."""
    _sphere(b, (0, 0.57, 0), 0.55, "eye_amber", seg=12, rings=8)
    b.cyl((0, 0.03, 0), 0.3, 0.06, "gold_mid", segments=12)
    b.cyl((0, 1.15, 0), 0.16, 0.3, "glass", segments=12)
    b.cyl((0, 1.3, 0), 0.2, 0.07, "gold_mid", segments=12)
    b.cyl((0, 1.39, 0), 0.13, 0.12, "gold_mid", segments=12)
    _sphere(b, (0, 1.5, 0), 0.1, "gold_light", seg=10, rings=6)
    _disc(b, 0, 0.55, -0.46, -0.57, 0.26, "cream", seg=16)
    _coin(b, 0.07, 0.61, -0.595, 0.13)
    _coin(b, -0.09, 0.47, -0.61, 0.11, depth=0.045)
    b.box((0.28, 0.85, -0.4), (0.06, 0.18, 0.06), "milk", rot=_zrot(-38))                  # glint
    b.box((0.37, 0.7, -0.4), (0.06, 0.06, 0.06), "milk")


def gold_rush(b):
    """Gold Rush Potion: a tall egg of pale gold on a gold foot, gold flecks inside, a star for a stopper."""
    _sphere(b, (0, 0.5, 0), 0.38, "pastel_butter", scale=(1, 1.22, 1), seg=14, rings=9)
    b.cyl((0, 0.04, 0), 0.22, 0.08, "gold_mid", segments=12)
    b.cyl((0, 0.98, 0), 0.11, 0.16, "glass", segments=10)
    b.cyl((0, 1.07, 0), 0.15, 0.06, "gold_mid", segments=10)
    b.cyl((0, 1.175, 0), 0.06, 0.17, "gold_mid", segments=8)
    b.b.star(RB.p(0, 1.32, 0), 0.2, 0.09, 0.07, "gold_light", rot=(math.radians(90), "X"))
    for x, y, s in ((0.12, 0.62, 0.07), (-0.14, 0.42, 0.06), (0.06, 0.3, 0.05), (-0.05, 0.72, 0.05)):
        zf = -math.sqrt(max(0.0, 0.38 ** 2 - x ** 2 - ((y - 0.5) / 1.22) ** 2))      # on the egg's front
        b.box((x, y, zf - 0.005), (s, s, 0.04), "gold_light", rot=_zrot(45))
    b.box((0.22, 0.78, -0.22), (0.05, 0.14, 0.05), "milk", rot=_zrot(-25))                  # glint


def quick_bait(b):
    """Quick Bait Potion: a pink bottle whose cream label has a clock over a blue fish."""
    top = _bottle(b, 0.3, 0.04, 0.7, "fur_strawberry", label=(0.16, 0.62, "cream"), shoulder=0.14, seg=16)
    _top(b, top - 0.02, 0.1, 0.22, 0.13)
    zf = -0.335
    _disc(b, 0, 0.5, -0.29, zf, 0.095, "choco", seg=14)                                 # clock
    _disc(b, 0, 0.5, zf + 0.01, zf - 0.008, 0.075, "milk", seg=14)
    b.box((0, 0.525, zf - 0.012), (0.018, 0.055, 0.008), "choco")
    b.box((-0.022, 0.5, zf - 0.012), (0.05, 0.018, 0.008), "choco")
    b.b.cyl(RB.p(-0.02, 0.29, -0.3), 0.075, 0.07, "fish_blue", segments=10, bevel=False,
            rot=(math.radians(-90), "X"), scale=(1.5, 1, 1))                              # fish body, nose to -X
    b.fan_z(-0.3, (0.05, 0.29), [(0.15, 0.36), (0.15, 0.22)], 0.07, "fish_blue")          # tail
    _disc(b, -0.09, 0.31, -0.3, zf - 0.006, 0.014, "choco", seg=6)                       # eye
    _glint(b, 0.3, 0.66, 0.06)


POTIONS = {"Tip": tip, "Lucky": lucky, "Swift": swift, "Steady": steady, "BigTip": big_tip, "GoldRush": gold_rush,
           "QuickBait": quick_bait}


def build_potion(kind, mat):
    b = RB()
    POTIONS[kind](b)
    return [b.finalize(f"CatCafe_Prop_Potion_{kind}", mat)]


ASSETS = {f"CatCafe_Prop_Potion_{k}": ((lambda m, k=k: build_potion(k, m)), 750 if k == "BigTip" else 700)
          for k in POTIONS}
