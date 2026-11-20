"""The Blossom Stall's six items (Cherry Blossom Grove, the spring event, Sat Mar 27 to Sat Apr 3 2027;
cherry-blossom-grove-spec-v2.md section 4), bought with Petals at fixed prices, nothing random. Kept forever.

Two cat hats, built about the cats' existing Outfit_Hat spot (head top, front -Y) like christmasitems.py's, so no
cat model changes (ACCESSORY_SLOTS names the spot for Looks):
  CatCafe_Accessory_FlowerCrown    (flower_crown) a ring of leaves with six cherry blossoms and two ribbon tails
  CatCafe_Accessory_LanternHat     (paper_lantern_hat) a little red paper lantern worn as a hat, gold caps and tassel,
                                   lit (`_Glow`)

Four decor pieces, each on a decor spot like christmasitems.py's (about 4 wide, base centre at the pivot, front -Z).
Lights are `_Glow` (Neon), water `_Water`:
  CatCafe_Decor_LittleKoiPond      (koi_pond) a round stone-edged pond with two koi and lily pads, a little stone
                                   lantern at the back
  CatCafe_Decor_GroveBlossomTree   (blossom_tree) a small cherry tree on a mossy stone with fallen petals. Not
                                   CatCafe_Decor_BlossomTree, which is an older decor piece
  CatCafe_Decor_TeaSet             (tea_set) a low tea table with a teapot, two cups, a whisk and two cushions
  CatCafe_Decor_LanternString      (paper_lanterns) two posts with a string of five paper lanterns between them, lit
                                   (`_Glow`)
"""

import math

from mathutils import Matrix

from common import RB, Builder
from plot import rot_x, rot_y, rot_z

N = "CatCafe_"
RED, GOLD, WOOD, STONE = "bowl_red", "rarity_legend", "dark_wood", "fur_pewter"
PINK = ("blush", "fur_rose", "apron_pink", "offwhite")
ACCESSORY_SLOTS = {"FlowerCrown": "Hat", "LanternHat": "Hat"}


def _rot(deg, axis):
    return Matrix.Rotation(math.radians(deg), 3, axis)


def _blossom(b, c, r, sw, up="Z"):
    """Five petals round a butter middle, lying flat (up Z for Builder, Y for RB)."""
    x, y, z = c
    for k in range(5):
        a = math.radians(90 + 72 * k)
        dx, dv = 0.55 * r * math.cos(a), 0.55 * r * math.sin(a)
        if up == "Z":
            b.ico((x + dx, y + dv, z), r * 0.5, sw, scale=(1, 1, 0.45))
        else:
            b.ball((x + dx, y, z + dv), r * 0.5, sw, scale=(1, 0.45, 1))
    if up == "Z":
        b.ico((x, y, z + r * 0.12), r * 0.28, "pastel_butter")
    else:
        b.ball((x, y + r * 0.12, z), r * 0.28, "pastel_butter")


# ------------------------------------------------------------------------------------------------------ hats --
def build_flower_crown(mat):
    b = Builder()
    for k in range(14):                                                                    # the leafy ring
        a = 2 * math.pi * k / 14
        b.box((0.36 * math.cos(a), 0.36 * math.sin(a), 0.05), (0.18, 0.07, 0.08), ("leaf_green", "leaf_dark")[k % 2],
              bevel=False, rot=_rot(math.degrees(a) + 90, "Z"))
    for k in range(6):
        a = math.radians(60 * k + 90)
        c = (0.36 * math.cos(a), 0.36 * math.sin(a), 0.11)
        for j in range(5):                                                                 # flat petals, cheap
            pa = math.radians(90 + 72 * j)
            b.box((c[0] + 0.07 * math.cos(pa), c[1] + 0.07 * math.sin(pa), c[2]), (0.09, 0.07, 0.03), PINK[k % 4],
                  bevel=False, rot=_rot(math.degrees(pa), "Z"))
        b.box((c[0], c[1], c[2] + 0.02), (0.05, 0.05, 0.03), "pastel_butter", bevel=False)
    for sx in (-1, 1):                                                                     # ribbon tails at the back
        b.box((sx * 0.07, 0.4, 0.07), (0.06, 0.02, 0.12), "fur_rose", bevel=False, rot=_rot(sx * 12, "Y"))
    return [b.finalize(N + "Accessory_FlowerCrown", mat)]


def build_lantern_hat(mat):
    b, glow = Builder(), Builder()
    b.cyl((0, 0, 0.04), 0.3, 0.08, GOLD, segments=10, bevel=False)                          # the bottom cap
    glow.cyl((0, 0, 0.12), 0.32, 0.1, RED, segments=10, bevel=False, radius2=0.38)          # the paper body, in steps
    glow.cyl((0, 0, 0.25), 0.38, 0.16, RED, segments=10, bevel=False)
    glow.cyl((0, 0, 0.38), 0.38, 0.1, RED, segments=10, bevel=False, radius2=0.3)
    for k in range(8):                                                                       # the ribs
        a = 2 * math.pi * k / 8
        b.box((0.385 * math.cos(a), 0.385 * math.sin(a), 0.25), (0.02, 0.02, 0.17), "choco", bevel=False)
    b.cyl((0, 0, 0.46), 0.26, 0.06, GOLD, segments=10, bevel=False)                          # the top cap and loop
    b.cyl((0, 0, 0.53), 0.05, 0.08, GOLD, segments=6, bevel=False)
    b.box((0.35, -0.12, 0.2), (0.03, 0.03, 0.2), GOLD, bevel=False)                          # a tassel at one side
    b.ico((0.35, -0.12, 0.08), 0.045, GOLD)
    return [b.finalize(N + "Accessory_LanternHat", mat), glow.finalize(N + "Accessory_LanternHat_Glow", mat)]


# ----------------------------------------------------------------------------------------------------- decor --
def build_koi_pond(mat):
    b, water = RB(), RB()
    for k in range(12):                                                                      # the stone edge
        a = 2 * math.pi * k / 12
        b.ball((1.6 * math.cos(a), 0.22, 1.1 * math.sin(a)), 0.3, (STONE, "fur_slate")[k % 2], scale=(1.3, 0.7, 1.0))
    b.cyl((0, 0.06, 0), 1.55, 0.12, "fur_moss", segments=14)
    water.cyl((0, 0.18, 0), 1.4, 0.04, "fish_blue", segments=14)
    for (x, z, yaw, sw) in ((-0.4, 0.2, 30, "fur_orange"), (0.45, -0.25, 200, "offwhite")):  # two koi
        b.ball((x, 0.22, z), 0.18, sw, scale=(2.0, 0.6, 0.8))
        b.box((x - 0.4 * math.cos(math.radians(yaw)), 0.22, z + 0.4 * math.sin(math.radians(yaw))), (0.2, 0.04, 0.16),
              sw, rot=rot_y(yaw))
        b.ball((x + 0.1, 0.27, z), 0.07, ("offwhite", "fur_orange")[sw == "offwhite"], scale=(1.2, 0.4, 1.0))
    for (x, z, r) in ((0.6, 0.5, 0.3), (-0.8, -0.4, 0.25)):                                  # lily pads and a flower
        b.cyl((x, 0.21, z), r, 0.02, "leaf_green", segments=8)
    _blossom(b, (0.6, 0.27, 0.5), 0.16, "blush", up="Y")
    b.span((1.4, 0.0, 0.7), (1.9, 0.3, 1.2), STONE)                                          # a little stone lantern
    b.cyl((1.65, 0.6, 0.95), 0.1, 0.6, STONE, segments=6)
    b.span((1.45, 0.9, 0.75), (1.85, 1.2, 1.15), STONE)
    b.span((1.35, 1.2, 0.65), (1.95, 1.32, 1.25), STONE)
    return [b.finalize(N + "Decor_LittleKoiPond", mat), water.finalize(N + "Decor_LittleKoiPond_Water", mat)]


def build_blossom_tree(mat):
    b = RB()
    b.ball((0, 0.4, 0), 1.0, STONE, scale=(1.2, 0.4, 1.0))                                  # the mossy stone
    b.ball((0, 0.55, 0), 0.85, "fur_moss", scale=(1.1, 0.25, 0.9))
    b.cyl((0, 1.4, 0), 0.22, 2.2, "fur_bramble", r2=0.14, segments=8)
    for sx in (-1, 1):                                                                       # two branches
        b.box((sx * 0.45, 2.45, 0.0), (0.12, 1.0, 0.12), "fur_bramble", rot=rot_z(-sx * 40))
    for (x, y, z, r, sw) in ((0, 3.2, 0, 0.95, "blush"), (-0.9, 2.85, 0.2, 0.7, "fur_rose"), (0.9, 2.9, -0.15, 0.72,
                             "apron_pink"), (0.1, 3.7, -0.2, 0.6, "offwhite"), (0.2, 2.7, 0.6, 0.55, "fur_bubblegum")):
        b.ball((x, y, z), r, sw)
    for k in range(10):                                                                      # petals on the stone
        a = 2.4 * k
        rr = 0.4 + 0.07 * k
        b.box((rr * math.cos(a), 0.66 if rr < 0.9 else 0.06, rr * math.sin(a)), (0.16, 0.03, 0.16), PINK[k % 4],
              rot=rot_y(37 * k))
    return [b.finalize(N + "Decor_GroveBlossomTree", mat)]


def build_tea_set(mat):
    b = RB()
    b.span((-1.1, 0.0, -0.7), (1.1, 0.12, 0.7), "fur_oat")                                  # a tatami mat
    for sx in (-1, 1):                                                                       # the low table's legs
        for sz in (-1, 1):
            b.span((sx * 0.7 - 0.06, 0.12, sz * 0.4 - 0.06), (sx * 0.7 + 0.06, 0.55, sz * 0.4 + 0.06), WOOD)
    b.span((-0.85, 0.55, -0.5), (0.85, 0.65, 0.5), WOOD)
    b.cyl((-0.2, 0.83, 0.05), 0.2, 0.3, "fur_sand", r2=0.14, segments=10)                    # the teapot
    b.ball((-0.2, 1.0, 0.05), 0.09, "fur_sand")
    b.box((0.02, 0.86, 0.05), (0.22, 0.06, 0.06), "fur_sand", rot=rot_z(30))                 # its spout
    b.box((-0.2, 1.08, 0.05), (0.32, 0.03, 0.03), "caramel_wood")                            # the cane handle
    for x in (0.35, 0.62):                                                                   # two cups of matcha
        b.cyl((x, 0.72, -0.15), 0.08, 0.13, "milk", r2=0.1, segments=8)
        b.cyl((x, 0.79, -0.15), 0.09, 0.01, "leaf_green", segments=8)
    b.box((0.5, 0.68, 0.25), (0.06, 0.06, 0.28), "caramel_wood", rot=rot_x(90))              # the whisk
    b.cyl((0.5, 0.7, 0.42), 0.07, 0.1, "fur_custard", segments=6)
    for sz in (-1, 1):                                                                       # two cushions
        b.span((-0.4, 0.12, sz * 1.0 - 0.3), (0.4, 0.27, sz * 1.0 + 0.3), ("fur_rose", "blush")[sz > 0])
    return [b.finalize(N + "Decor_TeaSet", mat)]


def build_lantern_string(mat):
    b, glow = RB(), RB()
    for sx in (-1, 1):
        x = sx * 1.9
        b.span((x - 0.25, 0.0, -0.25), (x + 0.25, 0.2, 0.25), STONE)
        b.cyl((x, 1.5, 0), 0.08, 2.8, WOOD, segments=6)
        b.span((x - 0.15, 2.85, -0.1), (x + 0.15, 3.0, 0.1), RED)
    for k in range(5):                                                                       # the string, sagging
        t = (k + 1) / 6
        x = -1.9 + 3.8 * t
        y = 2.8 - 0.55 * math.sin(math.pi * t)
        b.box((x, y + 0.26, 0), (0.02, 0.2, 0.02), "choco")
        glow.ball((x, y - 0.05, 0), 0.24, (RED, "fur_strawberry", GOLD)[k % 3], scale=(1.0, 1.2, 1.0))
        b.cyl((x, y + 0.22, 0), 0.12, 0.06, GOLD, segments=6)
        b.cyl((x, y - 0.32, 0), 0.12, 0.06, GOLD, segments=6)
    for k in range(6):
        t0, t1 = k / 6, (k + 1) / 6
        x0, x1 = -1.9 + 3.8 * t0, -1.9 + 3.8 * t1
        y0, y1 = 2.8 - 0.55 * math.sin(math.pi * t0) + 0.36, 2.8 - 0.55 * math.sin(math.pi * t1) + 0.36
        L = math.hypot(x1 - x0, y1 - y0)
        b.box(((x0 + x1) / 2, (y0 + y1) / 2, 0), (L, 0.03, 0.03), "choco",
              rot=rot_z(math.degrees(math.atan2(y1 - y0, x1 - x0))))
    return [b.finalize(N + "Decor_LanternString", mat), glow.finalize(N + "Decor_LanternString_Glow", mat)]


ASSETS = {
    N + "Accessory_FlowerCrown": (build_flower_crown, 700),
    N + "Accessory_LanternHat": (build_lantern_hat, 600),
    N + "Decor_LittleKoiPond": (build_koi_pond, 3000),
    N + "Decor_GroveBlossomTree": (build_blossom_tree, 3000),
    N + "Decor_TeaSet": (build_tea_set, 3000),
    N + "Decor_LanternString": (build_lantern_string, 3000),
}
