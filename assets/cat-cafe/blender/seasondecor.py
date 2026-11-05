"""Cafe Pass season 1 decor (#1637, cafe-pass.md section 3): six autumn pieces for the paid track. They are looks
only (no cafeMultiplier, not in the Decor Index) and stand on a decor spot like the crate pieces (crate_decor.py):
about 4 studs wide and 2.5 deep at most, pivot base centre, the front toward -Z, no collision. `_Glow` parts are Neon
all day.

  CatCafe_Decor_PumpkinLantern     (level 7)  a round ribbed pumpkin with a friendly cat face glowing warm, a curly stem
                                              and a leaf, two little pumpkins at its side
  CatCafe_Decor_FallenLeafRug      (level 12) an oval rust rug with a cream border, a big maple leaf in the middle,
                                              small leaves round it and a fringe at both ends
  CatCafe_Decor_CosyKnitCushion    (level 15) a round cream knitted pouf with pumpkin cable bands, a knit ring and a
                                              wooden button on top
  CatCafe_Decor_HayBaleSeat        (level 18) a hay bale with twine bands and a red check blanket over it, a pumpkin
                                              at its foot
  CatCafe_Decor_AppleCrateShelf    (level 24) two wooden apple crates stacked on their sides as shelves, red apples,
                                              a jar of jam and a gourd on them
  CatCafe_Decor_MapleTreePlanter   (level 28) a terracotta planter with a little maple tree in red and orange, fallen
                                              leaves on the soil

Built with RB in Roblox axes (x across, y up, -Z the front).
"""

import math

from mathutils import Matrix

from common import RB

PUMPKIN, PUMPKIN_DK = "fur_orange", "fur_rust_red"
MAPLE = ("fur_rust_red", "fur_orange", "pastel_butter")


def _pumpkin(b, x, z, r, h=None, sw=PUMPKIN, stem="leaf_dark", ribs=6, y=0.0):
    """A ribbed pumpkin standing at (x, y, z): `ribs` lobes round a core (one lobe faces the front), a short stem."""
    h = h or r * 1.5
    for k in range(ribs):
        a = -math.pi / 2 + 2 * math.pi * k / ribs
        b.ball((x + r * 0.45 * math.cos(a), y + h / 2, z + r * 0.45 * math.sin(a)), r * 0.62, sw,
               scale=(1.0, h / (r * 1.24), 1.0))
    b.ball((x, y + h / 2, z), r * 0.8, sw, scale=(1.0, h / (r * 1.6), 1.0))
    b.cyl((x, y + h + 0.1 * r, z), 0.09 * r, 0.32 * r, stem, segments=6)
    return h


def _leaf(b, x, y, z, s, sw):
    """A maple leaf lying flat: a five-pointed star with deep notches."""
    b.b.star(RB.p(x, y + 0.015, z), 0.5 * s, 0.24 * s, 0.03, sw)


def build_pumpkin_lantern(mat):
    name = "CatCafe_Decor_PumpkinLantern"
    b, glow = RB(), RB()
    h = _pumpkin(b, 0, 0, 1.0, h=1.45)
    b.cyl((0.12, h + 0.3, 0), 0.06, 0.24, "leaf_dark", axis="X", segments=6)          # the stem's curl
    _leaf(b, -0.3, h - 0.06, 0.15, 0.6, "leaf_green")
    zf, d = -0.97, 0.14                                                               # the face, on the front lobe
    for sx in (-1, 1):                                                                # eyes: little cat triangles
        glow.fan_z(zf, (sx * 0.28, 1.0), [(sx * 0.44, 0.74), (sx * 0.12, 0.74)], d, "lamp_warm")
    glow.fan_z(zf, (0, 0.56), [(-0.08, 0.66), (0.08, 0.66)], d, "lamp_warm")              # nose
    glow.fan_z(zf, (0, 0.3), [(-0.3, 0.5), (-0.15, 0.4), (0.0, 0.47), (0.15, 0.4), (0.3, 0.5)], d,
               "lamp_warm")                                                           # a cat smile
    _pumpkin(b, 1.3, -0.25, 0.4, sw="pastel_butter")
    _pumpkin(b, -1.3, -0.4, 0.34, sw=PUMPKIN_DK)
    return [b.finalize(name, mat), glow.finalize(name + "_Glow", mat)]


def build_fallen_leaf_rug(mat):
    b = RB()
    b.b.cyl(RB.p(0, 0.03, 0), 1.85, 0.06, "cream", segments=24, bevel=False, scale=(1.0, 0.62, 1.0))   # border
    b.b.cyl(RB.p(0, 0.065, 0), 1.68, 0.03, PUMPKIN_DK, segments=24, bevel=False, scale=(1.0, 0.6, 1.0))
    b.b.cyl(RB.p(0, 0.085, 0), 1.2, 0.02, "fur_orange", segments=24, bevel=False, scale=(1.0, 0.56, 1.0))
    _leaf(b, 0, 0.08, -0.05, 1.3, "pastel_butter")                                   # the big leaf
    b.span((-0.04, 0.08, 0.2), (0.04, 0.115, 0.62), "fur_russet")                     # its stem
    for (x, z, s, sw) in ((-1.15, 0.35, 0.36, "pastel_butter"), (1.2, -0.3, 0.34, "cream"),
                          (-1.05, -0.45, 0.3, "cream"), (1.05, 0.45, 0.3, "pastel_butter")):
        _leaf(b, x, 0.07, z, s, sw)
    for sx in (-1, 1):                                                                # fringe at both ends
        for k in range(5):
            z = -0.4 + 0.2 * k
            b.span((sx * 1.77 - 0.1, 0.0, z - 0.03), (sx * 1.77 + 0.1, 0.03, z + 0.03), "cream")
    return [b.finalize("CatCafe_Decor_FallenLeafRug", mat)]


def build_cosy_knit_cushion(mat):
    """A round knitted pouf: a cream drum with a soft domed top, pumpkin cable bands down its side, a knit ring and
    a wooden button on top."""
    b = RB()
    R, H = 0.85, 0.5
    b.cyl((0, H / 2, 0), R, H, "cream", segments=16)                                  # the drum
    b.ball((0, H, 0), R, "cream", scale=(1.0, 0.24, 1.0))                             # its soft top
    for k in range(8):                                                                # cable bands round the side
        a = 2 * math.pi * (k + 0.5) / 8
        b.box((R * math.cos(a), H / 2, R * math.sin(a)), (0.16, H - 0.04, 0.08), PUMPKIN,
              rot=Matrix.Rotation(-a + math.pi / 2, 3, "Y"))
    for k in range(8):                                                                # a knit ring on top
        a = 2 * math.pi * k / 8
        b.box((0.45 * math.cos(a), H + 0.15, 0.45 * math.sin(a)), (0.16, 0.06, 0.16), PUMPKIN_DK)
    b.cyl((0, H + 0.2, 0), 0.12, 0.06, "caramel_wood", segments=10)                   # the button
    return [b.finalize("CatCafe_Decor_CosyKnitCushion", mat)]


def build_hay_bale_seat(mat):
    b = RB()
    W, H, D = 2.4, 1.1, 1.3
    zc = 0.3
    b.span((-W / 2, 0, zc - D / 2), (W / 2, H, zc + D / 2), "pastel_butter")            # the bale
    zf = zc - D / 2
    for (x, y) in ((-0.8, 0.35), (0.35, 0.3), (0.95, 0.42), (-0.25, 0.22)):          # straw tufts on its face
        b.box((x, y, zf - 0.02), (0.3, 0.05, 0.05), "treat_tan")
    for x in (-0.75, 0.75):                                                           # twine bands
        b.span((x - 0.05, 0.0, zf - 0.03), (x + 0.05, H + 0.03, zc + D / 2 + 0.03), "caramel_wood")
    x0, x1 = -1.05, 0.55                                                              # a red check blanket
    b.span((x0, H + 0.03, zf - 0.06), (x1, H + 0.08, zc + D / 2 + 0.05), "bowl_red")
    b.span((x0, H - 0.55, zf - 0.09), (x1, H + 0.08, zf - 0.04), "bowl_red")           # its front fall
    for k in range(4):
        x = x0 + 0.17 + 0.4 * k
        b.span((x, H + 0.08, zf - 0.06), (x + 0.1, H + 0.1, zc + D / 2 + 0.05), "cream")
        b.span((x, H - 0.55, zf - 0.11), (x + 0.1, H + 0.08, zf - 0.09), "cream")
    _pumpkin(b, 0.95, zf - 0.32, 0.32)
    return [b.finalize("CatCafe_Decor_HayBaleSeat", mat)]


def _crate_on_side(b, x0, y0, W, H, D):
    """An open wooden crate on its side, opening toward the front: top, bottom, two sides and a back."""
    t = 0.1
    b.span((x0, y0, -D / 2), (x0 + W, y0 + t, D / 2), "caramel_wood")                 # bottom
    b.span((x0, y0 + H - t, -D / 2), (x0 + W, y0 + H, D / 2), "caramel_wood")         # top
    for xs in (x0, x0 + W - t):                                                       # sides
        b.span((xs, y0 + t, -D / 2), (xs + t, y0 + H - t, D / 2), "caramel_wood")
    b.span((x0 + t, y0 + t, D / 2 - t), (x0 + W - t, y0 + H - t, D / 2), "dark_wood")   # back
    for xs in (x0, x0 + W - t):                                                       # dark corner posts at the front
        b.span((xs - 0.02, y0, -D / 2 - 0.03), (xs + t + 0.02, y0 + H + 0.02, -D / 2 + 0.06), "dark_wood")


def _apple(b, x, y, z):
    b.ball((x, y + 0.17, z), 0.17, "shirt_red")
    b.cyl((x, y + 0.37, z), 0.025, 0.08, "dark_wood", segments=4)


def build_apple_crate_shelf(mat):
    b = RB()
    W, H, D = 2.6, 0.95, 1.1
    _crate_on_side(b, -W / 2, 0, W, H, D)
    W2, H2 = W - 0.5, H * 0.9
    _crate_on_side(b, -W2 / 2, H, W2, H2, D * 0.9)
    for (x, z) in ((-0.85, -0.1), (-0.5, 0.15), (-0.65, 0.3), (-0.2, -0.05), (-0.95, 0.25)):
        _apple(b, x, 0.1, z)                                                          # apples in the bottom crate
    b.cyl((0.6, 0.1 + 0.25, 0), 0.19, 0.5, "glass", segments=10)                      # a jar of jam
    b.cyl((0.6, 0.1 + 0.23, 0), 0.16, 0.42, "bowl_red", segments=10)
    b.cyl((0.6, 0.1 + 0.53, 0), 0.21, 0.07, "caramel_wood", segments=10)
    for (x, z) in ((-0.55, 0.0), (-0.2, 0.1)):                                         # apples in the top crate
        _apple(b, x, H + 0.1, z)
    _pumpkin(b, 0.45, 0.0, 0.28, sw="pastel_butter", y=H + 0.1)                        # a gourd
    _pumpkin(b, 0.0, 0.0, 0.22, sw=PUMPKIN, y=H + H2)                                  # a little pumpkin on top
    return [b.finalize("CatCafe_Decor_AppleCrateShelf", mat)]


def build_maple_tree_planter(mat):
    b = RB()
    b.cyl((0, 0.45, 0), 0.75, 0.9, "terracotta", r2=0.6, segments=12)                 # planter
    b.cyl((0, 0.92, 0), 0.82, 0.14, "terracotta", segments=12)                        # its rim
    b.cyl((0, 1.0, 0), 0.7, 0.04, "choco", segments=12)                              # soil
    b.cyl((0, 1.65, 0), 0.11, 1.4, "fur_russet", segments=6)                          # trunk
    for (x, y, a) in ((0.22, 2.0, -40), (-0.2, 2.1, 45)):                             # branches
        b.box((x, y, 0), (0.08, 0.6, 0.08), "fur_russet", rot=Matrix.Rotation(math.radians(a), 3, "Z"))
    for (x, y, z, r, sw) in ((0, 2.6, 0, 0.62, MAPLE[0]), (-0.55, 2.3, 0.05, 0.45, MAPLE[1]),
                             (0.55, 2.35, -0.05, 0.45, MAPLE[1]), (0.2, 2.95, 0.15, 0.4, MAPLE[2]),
                             (-0.25, 2.8, -0.25, 0.38, MAPLE[0])):                     # the canopy
        b.ball((x, y, z), r, sw)
    for (x, z, sw) in ((-0.4, -0.3, MAPLE[0]), (0.38, 0.2, MAPLE[2]), (0.2, -0.42, MAPLE[1])):
        _leaf(b, x, 1.01, z, 0.24, sw)                                                # fallen leaves on the soil
    return [b.finalize("CatCafe_Decor_MapleTreePlanter", mat)]


ASSETS = {
    "CatCafe_Decor_PumpkinLantern": (build_pumpkin_lantern, 1500),
    "CatCafe_Decor_FallenLeafRug": (build_fallen_leaf_rug, 1000),
    "CatCafe_Decor_CosyKnitCushion": (build_cosy_knit_cushion, 800),
    "CatCafe_Decor_HayBaleSeat": (build_hay_bale_seat, 800),
    "CatCafe_Decor_AppleCrateShelf": (build_apple_crate_shelf, 1500),
    "CatCafe_Decor_MapleTreePlanter": (build_maple_tree_planter, 1200),
}
