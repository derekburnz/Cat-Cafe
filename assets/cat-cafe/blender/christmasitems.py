"""The Gift Stall's eight items (the Christmas Event, Dec 1 2026 to Jan 3 2027; snowglobe-village-spec.md section 5),
bought with Snowflakes at fixed prices, nothing random. Christmas only.

Three cat hats, built about the cats' existing Outfit_Hat spot (head top, front -Y) like harvestoutfits.py's, so no
cat model changes (ACCESSORY_SLOTS names the spot for Looks):
  CatCafe_Accessory_SantaHat         a red Santa hat with a white fur band, its tip flopped to one side with a pompom
  CatCafe_Accessory_ReindeerAntlers  a brown headband with two branched antlers and a small sprig of holly
  CatCafe_Accessory_KnitBeanie       a green and cream knit beanie with a folded cuff, a snowflake band and a pompom

Five decor pieces, each on a decor spot like harvestdecor.py's (about 4 wide and 2.5 deep, base centre at the pivot,
front -Z). Lights are `_Glow` (Neon):
  CatCafe_Decor_PresentPile        a heap of wrapped presents with ribbons and bows, a gift tag on the top one
  CatCafe_Decor_Snowman            a snowman with a scarf, a top hat, a carrot nose and stick arms, a snow drift
  CatCafe_Decor_GingerbreadHouse   a gingerbread house with icing on the roof, gumdrops, a candy cane door frame and
                                   lit windows (`_Glow`) on a cake board
  CatCafe_Decor_StockingWall       a mantel shelf on two brackets with five stockings, a garland of lights (`_Glow`)
                                   and a little pine at one end, on two posts and a back board (it stands
                                   against a wall: its back is at z 0.4)
  CatCafe_Decor_LittleLitTree      a small pine in a red pot with bulbs (`_Glow`), a star on top and two presents
"""

import math

from mathutils import Matrix, Vector

from common import RB, Builder
from crate_decor import _little_pine, _snowflake
from plot import rot_x, rot_y, rot_z

N = "CatCafe_"
RED, WHITE, GOLD, GREEN, PINE = "shirt_red", "offwhite", "rarity_legend", "leaf_green", "leaf_dark"
SNOW = "milk"
BULBS = ("lamp_warm", RED, GOLD, "pastel_sky", GREEN)
ACCESSORY_SLOTS = {"SantaHat": "Hat", "ReindeerAntlers": "Hat", "KnitBeanie": "Hat"}


def _rot(deg, axis):
    return Matrix.Rotation(math.radians(deg), 3, axis)


# ------------------------------------------------------------------------------------------------------ hats --
def build_santa_hat(mat):
    b = Builder()
    b.cyl((0, 0, 0.07), 0.42, 0.14, WHITE, segments=12, bevel=False)                       # the fur band
    b.cyl((0, 0.02, 0.24), 0.36, 0.22, RED, segments=12, bevel=False, radius2=0.27)       # the cone, in steps
    b.cyl((0.04, 0.04, 0.43), 0.27, 0.18, RED, segments=10, bevel=False, radius2=0.17)
    tip = _rot(-55, "Y")                                                                   # flopped over to +X
    b.cyl((0.17, 0.05, 0.55), 0.17, 0.26, RED, segments=8, bevel=False, radius2=0.07, rot=tip)
    b.ico((0.36, 0.05, 0.58), 0.1, WHITE)                                                  # the pompom
    return [b.finalize(N + "Accessory_SantaHat", mat)]


def build_reindeer_antlers(mat):
    b = Builder()
    for k in range(9):                                                                     # the headband, an arc
        a = math.radians(180 * k / 8)
        b.box((0.34 * math.cos(a), 0.0, 0.05 + 0.1 * math.sin(a)), (0.1, 0.07, 0.06), "fur_brown", bevel=False,
              rot=_rot(-math.degrees(a) + 90, "Y"))
    for sx in (-1, 1):                                                                     # two branched antlers
        base = Vector((sx * 0.24, 0.0, 0.12))
        R = _rot(sx * -18, "Y")
        b.box(tuple(base + R @ Vector((0, 0, 0.17))), (0.06, 0.06, 0.34), "fur_toffee", bevel=False, rot=R)
        for j, (h, ang, L) in enumerate(((0.14, 50, 0.16), (0.25, -45, 0.14), (0.33, 40, 0.12))):
            Rj = R @ _rot(sx * ang, "Y")
            p = base + R @ Vector((0, 0, h))
            b.box(tuple(p + Rj @ Vector((0, 0, L / 2))), (0.05, 0.05, L), "fur_toffee", bevel=False, rot=Rj)
    for k, (dx, dz) in enumerate(((-0.06, 0.18), (0.06, 0.18))):                           # a holly sprig
        b.box((dx, -0.05, dz), (0.12, 0.03, 0.06), GREEN, bevel=False, rot=_rot(25 * (-1) ** k, "Y"))
    b.ico((0, -0.07, 0.2), 0.04, RED)
    b.ico((0.03, -0.07, 0.24), 0.035, RED)
    return [b.finalize(N + "Accessory_ReindeerAntlers", mat)]


def build_knit_beanie(mat):
    b = Builder()
    b.cyl((0, 0, 0.07), 0.42, 0.14, "cream", segments=12, bevel=False)                     # the folded cuff
    for k in range(12):                                                                    # its rib lines
        a = 2 * math.pi * k / 12
        b.box((0.425 * math.cos(a), 0.425 * math.sin(a), 0.07), (0.02, 0.05, 0.13), "fur_vanilla", bevel=False,
              rot=_rot(math.degrees(a), "Z"))
    b.cyl((0, 0, 0.2), 0.39, 0.12, GREEN, segments=12, bevel=False)                        # the body
    for k in range(6):                                                                     # a band of little flakes
        a = 2 * math.pi * (k + 0.5) / 6
        b.box((0.395 * math.cos(a), 0.395 * math.sin(a), 0.2), (0.02, 0.1, 0.03), WHITE, bevel=False,
              rot=_rot(math.degrees(a), "Z"))
        b.box((0.395 * math.cos(a), 0.395 * math.sin(a), 0.2), (0.02, 0.03, 0.1), WHITE, bevel=False,
              rot=_rot(math.degrees(a), "Z"))
    b.cyl((0, 0, 0.32), 0.37, 0.12, GREEN, segments=12, bevel=False, radius2=0.2)          # the crown
    b.ico((0, 0, 0.45), 0.13, "cream")                                                     # the pompom
    return [b.finalize(N + "Accessory_KnitBeanie", mat)]


# ----------------------------------------------------------------------------------------------------- decor --
def _present(b, x, y, z, w, d, h, sw, rib=GOLD, rot=None, bow=True):
    """A wrapped present standing on y: ribbons both ways and a bow on top."""
    b.box((x, y + h / 2, z), (w, h, d), sw, rot=rot)
    b.box((x, y + h / 2, z), (w * 0.2 if w < d else w + 0.02, h + 0.02, d + 0.02 if w < d else d * 0.2), rib,
          rot=rot)
    b.box((x, y + h / 2, z), (w + 0.02 if w < d else w * 0.2, h + 0.02, d * 0.2 if w < d else d + 0.02), rib,
          rot=rot)
    if bow:
        for sx in (-1, 1):
            b.box((x + sx * 0.1 * w, y + h + 0.06, z), (0.22 * w, 0.12, 0.12), rib, rot=rot_z(sx * 25))


def build_present_pile(mat):
    b = RB()
    _present(b, -0.9, 0, 0.1, 1.4, 1.2, 1.1, RED)
    _present(b, 0.75, 0, 0.2, 1.2, 1.1, 0.9, GREEN, "cream")
    _present(b, 1.55, 0, -0.55, 0.7, 0.7, 0.6, "pastel_lilac", "cream", rot=rot_y(20))
    _present(b, -1.75, 0, -0.6, 0.6, 0.6, 0.55, "pastel_sky", RED, rot=rot_y(-15))
    _present(b, -0.6, 1.1, 0.0, 0.9, 0.8, 0.7, "pastel_butter", RED, rot=rot_y(12))
    _present(b, 0.75, 0.9, 0.15, 0.7, 0.7, 0.5, "blush", GOLD, rot=rot_y(-20))
    _present(b, -0.45, 1.8, 0.05, 0.5, 0.5, 0.45, WHITE, RED, rot=rot_y(30))
    b.box((-0.1, 2.0, -0.25), (0.28, 0.18, 0.02), "cream", rot=rot_z(-20))                   # a gift tag
    b.box((-0.1, 2.0, -0.26), (0.08, 0.05, 0.01), RED, rot=rot_z(-20))
    return [b.finalize(N + "Decor_PresentPile", mat)]


def build_snowman(mat):
    b = RB()
    b.ball((0, 0.29, 0), 1.6, SNOW, scale=(1.0, 0.18, 0.8))                                  # a drift
    b.ball((0, 0.95, 0), 0.9, SNOW)
    b.ball((0, 2.25, 0), 0.65, SNOW)
    b.ball((0, 3.25, 0), 0.48, SNOW)
    for y, z in ((1.25, -0.86), (1.65, -0.72), (2.3, -0.64)):                                # coal buttons
        b.box((0, y, z), (0.1, 0.1, 0.06), "fur_black")
    for sx in (-1, 1):
        b.box((sx * 0.16, 3.35, -0.44), (0.08, 0.08, 0.04), "fur_black")                    # eyes
    b.cyl((0, 3.2, -0.6), 0.08, 0.36, "fur_marmalade", axis="Z", r2=0.015, segments=6)      # carrot nose
    for k in range(5):                                                                       # a smile
        b.box((-0.16 + 0.08 * k, 3.05 - 0.03 * (2 - abs(k - 2)), -0.45), (0.05, 0.05, 0.03), "fur_black")
    b.cyl((0, 2.82, 0), 0.6, 0.2, RED, segments=12)                                         # scarf
    b.span((0.25, 2.1, -0.62), (0.45, 2.75, -0.52), RED)
    b.span((0.24, 2.15, -0.635), (0.46, 2.2, -0.51), "cream")
    b.cyl((0, 3.68, 0), 0.55, 0.06, "fur_black", segments=12)                                # top hat
    b.cyl((0, 3.98, 0), 0.36, 0.6, "fur_black", segments=12)
    b.cyl((0, 3.78, 0), 0.37, 0.1, RED, segments=12)
    b.box((0.2, 3.82, -0.3), (0.16, 0.16, 0.04), GREEN, rot=rot_z(30))                      # a holly leaf
    for sx in (-1, 1):                                                                       # stick arms
        b.box((sx * 1.05, 2.5, 0), (0.9, 0.08, 0.08), "fur_bramble", rot=rot_z(sx * 25))
        b.box((sx * 1.42, 2.85, 0), (0.3, 0.06, 0.06), "fur_bramble", rot=rot_z(sx * 65))
    return [b.finalize(N + "Decor_Snowman", mat)]


def build_gingerbread_house(mat):
    b, glow = RB(), RB()
    ging, icing = "fur_toffee", "milk"
    b.cyl((0, 0.05, 0), 1.6, 0.1, "cream", segments=16)                                     # the cake board
    b.span((-1.1, 0.1, -0.8), (1.1, 1.5, 0.8), ging)                                         # walls
    for sd in (-1, 1):                                                                       # the roof, ridge along x
        b.box((0, 1.95, sd * 0.47), (2.5, 0.12, 1.15), ging, rot=rot_x(sd * 40))
        b.box((0, 2.03, sd * 0.49), (2.4, 0.06, 1.05), icing, rot=rot_x(sd * 40))
        for k in range(5):                                                                   # gumdrops on it
            b.ball((-0.9 + 0.45 * k, 2.12 + 0.1 * (1 - abs(sd)), sd * (0.3 + 0.18 * (k % 2))), 0.09,
                   ("bowl_red", GREEN, "pastel_lilac", GOLD, "pastel_sky")[k])
    for sx in (-1, 1):                                                                       # gable ends
        b.wedge((sx * 1.07, 1.88, -0.45), (0.06, 0.76, 0.9), ging)
        b.wedge((sx * 1.07, 1.88, 0.45), (0.06, 0.76, 0.9), ging, rot=rot_y(180))
    b.span((-0.3, 0.1, -0.84), (0.3, 0.95, -0.8), "fur_brown")                               # the door
    for sx in (-1, 1):                                                                       # candy cane door frame
        for k in range(4):
            b.span((sx * 0.38 - 0.05, 0.1 + 0.22 * k, -0.9), (sx * 0.38 + 0.05, 0.32 + 0.22 * k, -0.82),
                   (RED, WHITE)[k % 2])
    b.span((-0.43, 0.98, -0.9), (0.43, 1.06, -0.82), RED)
    for x in (-0.75, 0.75):                                                                  # lit windows
        glow.span((x - 0.2, 0.6, -0.83), (x + 0.2, 1.0, -0.8), "lamp_warm")
        b.span((x - 0.24, 0.56, -0.85), (x + 0.24, 0.6, -0.8), icing)
        b.span((x - 0.02, 0.6, -0.86), (x + 0.02, 1.0, -0.83), icing)
    for k in range(9):                                                                       # icing drips on the eave
        b.span((-1.2 + 0.3 * k, 1.42, -0.98), (-1.1 + 0.3 * k, 1.56 - 0.06 * (k % 2), -0.9), icing)
    for x in (-1.35, 1.35):                                                                  # candy canes in the yard
        b.cyl((x, 0.45, -0.95), 0.05, 0.7, (RED, WHITE)[x > 0], segments=6)
        b.box((x + 0.08 * (1 if x < 0 else -1), 0.84, -0.95), (0.2, 0.08, 0.08), (RED, WHITE)[x > 0])
    b.box((0.55, 1.75, 0.5), (0.25, 0.5, 0.25), ging)                                       # the chimney
    b.box((0.55, 2.02, 0.5), (0.3, 0.06, 0.3), icing)
    return [b.finalize(N + "Decor_GingerbreadHouse", mat), glow.finalize(N + "Decor_GingerbreadHouse_Glow", mat)]


def build_stocking_wall(mat):
    b, glow = RB(), RB()
    b.span((-2.0, 2.6, -0.2), (2.0, 2.8, 0.4), "caramel_wood")                               # the shelf
    b.span((-2.0, 0.0, -0.1), (2.0, 0.12, 0.4), "dark_wood")                                 # a low plinth
    for sx in (-1, 1):                                                                       # two posts hold it up
        b.span((sx * 1.85 - 0.15, 0.12, -0.05), (sx * 1.85 + 0.15, 2.6, 0.35), "dark_wood")
        b.span((sx * 1.85 - 0.2, 0.12, -0.1), (sx * 1.85 + 0.2, 0.4, 0.4), "caramel_wood")
    b.span((-1.7, 0.12, 0.3), (1.7, 2.6, 0.4), "fur_cream")                                  # a back board
    for k, (x, sw, cuff) in enumerate(((-1.5, RED, WHITE), (-0.8, GREEN, WHITE), (-0.1, RED, "cream"),
                                       (0.6, "pastel_sky", WHITE), (1.3, GREEN, "cream"))):
        top = 2.6
        b.span((x - 0.17, top - 0.9, -0.24), (x + 0.17, top - 0.05, -0.12), sw)              # the leg
        b.span((x - 0.17, top - 1.15, -0.24), (x + 0.38, top - 0.9, -0.12), sw)              # the foot
        b.span((x - 0.2, top - 0.25, -0.26), (x + 0.2, top, -0.1), cuff)                     # the cuff
        b.span((x - 0.04, top - 0.85, -0.25), (x + 0.04, top - 0.3, -0.245), (WHITE, GOLD)[k % 2])
    for k in range(17):                                                                      # the garland of lights
        x = -1.95 + 0.24 * k
        b.ball((x, 2.82, -0.22), 0.13, (PINE, GREEN)[k % 2])
        if k % 2 == 0:
            glow.ball((x, 2.75, -0.33), 0.06, BULBS[(k // 2) % len(BULBS)])
    _little_pine(b, 1.75, 2.8, 0.1, 0.75)
    b.cyl((-1.6, 3.05, 0.15), 0.08, 0.5, "cream", segments=8)                                # a candle
    glow.cyl((-1.6, 3.39, 0.15), 0.045, 0.16, "lamp_warm", r2=0.01, segments=6)
    return [b.finalize(N + "Decor_StockingWall", mat), glow.finalize(N + "Decor_StockingWall_Glow", mat)]


def build_little_lit_tree(mat):
    b, glow = RB(), RB()
    b.cyl((0, 0.35, 0), 0.5, 0.7, RED, r2=0.6, segments=12)                                 # the pot
    b.cyl((0, 0.72, 0), 0.62, 0.08, GOLD, segments=12)
    b.cyl((0, 0.76, 0), 0.55, 0.02, "fur_bramble", segments=12)
    b.cyl((0, 0.95, 0), 0.1, 0.4, "dark_wood", segments=6)
    for k, (y, r, h) in enumerate(((1.15, 1.05, 0.9), (1.8, 0.82, 0.8), (2.4, 0.58, 0.7), (2.95, 0.34, 0.6))):
        b.cyl((0, y + h / 2, 0), r, h, (PINE, "paw_woods")[k % 2], r2=0.12, segments=10)
        n = 6 + 2 * (3 - k)
        for j in range(n):                                                                   # bulbs round each tier
            a = 2 * math.pi * (j + 0.5 * k) / n
            rr = r * 0.78
            glow.ball((rr * math.cos(a), y + h * 0.3, rr * math.sin(a)), 0.08, BULBS[(j + k) % len(BULBS)])
    for k in range(5):                                                                       # the star on top
        a = math.radians(90 + 72 * k)
        glow.box((0.18 * math.cos(a), 3.75 + 0.18 * math.sin(a), 0), (0.12, 0.3, 0.06), GOLD,
                 rot=rot_z(math.degrees(a) - 90))
    glow.box((0, 3.75, 0), (0.18, 0.18, 0.07), GOLD, rot=rot_z(45))
    _present(b, 0.95, 0, -0.45, 0.55, 0.55, 0.45, GREEN, GOLD, rot=rot_y(15))
    _present(b, -0.95, 0, -0.35, 0.65, 0.5, 0.5, "pastel_lilac", "cream", rot=rot_y(-20))
    return [b.finalize(N + "Decor_LittleLitTree", mat), glow.finalize(N + "Decor_LittleLitTree_Glow", mat)]


ASSETS = {
    N + "Accessory_SantaHat": (build_santa_hat, 600),
    N + "Accessory_ReindeerAntlers": (build_reindeer_antlers, 600),
    N + "Accessory_KnitBeanie": (build_knit_beanie, 700),
    N + "Decor_PresentPile": (build_present_pile, 3000),
    N + "Decor_Snowman": (build_snowman, 3000),
    N + "Decor_GingerbreadHouse": (build_gingerbread_house, 3000),
    N + "Decor_StockingWall": (build_stocking_wall, 3000),
    N + "Decor_LittleLitTree": (build_little_lit_tree, 3000),
}
