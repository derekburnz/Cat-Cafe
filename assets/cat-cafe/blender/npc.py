"""NPCs, facing -Y, pivot at feet (the cafe customers are in customers.py).
Dealer: the night food dealer in a starry robe and a gold-edged hood, holding a lantern out (Body + Bulb objects;
the Bulb goes Neon at night)."""

import math

from mathutils import Matrix

from common import Builder


def _rx(deg):
    return Matrix.Rotation(math.radians(deg), 3, "X")


def _ry(deg):
    return Matrix.Rotation(math.radians(deg), 3, "Y")


def _rz(deg):
    return Matrix.Rotation(math.radians(deg), 3, "Z")


def build_dealer(mat):
    """Mysterious but friendly, kept to a few clean blocks: a deep-blue robe flaring a little to a violet hem with a
    gold line, opening below the violet sash onto a starry under-robe, a violet placket with gold buttons up to a violet
    collar, the cart's pale moon on the chest and its gold stars on the skirt and sleeves; the sash's ends and a coin
    pouch hang at the hips. A dark hood with a gold edge, small stars and a gold tassel on its folded-back tip, round a
    kind old face: bright eyes, bushy silver brows, a nose, a smile and a silver goatee, silver hair under the hood.
    The right arm bent to hold a lantern out in front, the left at the side; mitten hands with thumbs."""
    b = Builder()
    up = (math.radians(90), "X")                                                             # a star up, facing -Y
    # robe
    b.box_base((0, 0, 0.06), (2.0, 1.2, 3.94), "galaxy_blue")                                    # to the shoulders
    for sx in (1, -1):
        b.wedge((sx * 1.075, 0, 1.01), (1.2, 0.15, 1.9), "galaxy_blue", bevel=False,
                rot=_rz(90 * sx))                                                                # the skirt flares out
        b.box_base((sx * 0.45, -0.55, 0), (0.6, 0.5, 0.2), "fur_black", bevel=False)            # shoes under the hem
    b.box_base((0, 0, 0.02), (2.36, 1.26, 0.26), "aurora_violet", bevel=False)                   # hem
    b.box((0, 0, 2.0), (2.06, 1.26, 0.2), "aurora_violet", bevel=False)                          # sash
    b.box((0, -0.64, 2.0), (0.3, 0.04, 0.26), "rarity_legend", bevel=False)                      # its gold clasp
    b.crescent((0.45, -0.615, 3.2), 0.24, 0.15, 0.04, "sparkle")                                 # the moon
    for x, z, r in ((-0.62, 1.2, 0.18), (0.6, 0.75, 0.15)):
        b.star((x, -0.615, z), r, r * 0.45, 0.03, "rarity_legend", rot=up)                      # stars on the skirt
    b.star((0, 0.615, 2.9), 0.3, 0.13, 0.03, "rarity_legend", rot=up)                            # one on the back
    b.box((0, 0, 0.305), (2.42, 1.32, 0.05), "rarity_legend", bevel=False)                       # gold line on the hem
    # the robe opens below the sash onto a starry under-robe, gold at the edges
    b.box((0, -0.615, 1.1), (0.56, 0.03, 1.6), "night_sky", bevel=False)
    for sx in (1, -1):
        b.box((sx * 0.29, -0.6175, 1.1), (0.05, 0.035, 1.6), "rarity_legend", bevel=False)
    b.star((0, -0.64, 1.35), 0.12, 0.055, 0.03, "sparkle", rot=up)
    b.star((0.08, -0.64, 0.75), 0.08, 0.036, 0.03, "sparkle", rot=up)
    # a violet placket with gold buttons from the sash to a violet collar round the neck
    b.box((0, -0.615, 3.0), (0.26, 0.03, 1.8), "aurora_violet", bevel=False)
    for z in (2.45, 2.95, 3.45):
        b.cyl((0, -0.64, z), 0.07, 0.03, "rarity_legend", segments=8, bevel=False, rot=up)
    b.box_base((0, -0.02, 3.88), (1.62, 1.34, 0.18), "aurora_violet", bevel=False)
    # the sash's ends with gold tassels and a coin pouch at the hips
    for x, h, turn in ((0.74, 0.7, 6), (0.94, 0.55, -5)):
        b.box((x, -0.64, 1.9 - h / 2), (0.2, 0.04, h), "aurora_violet", bevel=False, rot=_ry(turn))
        b.box((x + math.sin(math.radians(turn)) * h / 2, -0.64, 1.9 - h - 0.05), (0.14, 0.07, 0.14), "rarity_legend",
              bevel=False)
    b.box((-0.65, -0.7, 1.72), (0.4, 0.2, 0.42), "caramel_wood")                                # pouch
    b.box((-0.65, -0.7, 1.86), (0.44, 0.24, 0.06), "rarity_legend", bevel=False)                # its drawstring
    b.cyl((-0.65, -0.81, 1.68), 0.08, 0.02, "rarity_legend", segments=8, bevel=False, rot=up)   # and a coin badge
    # left arm at the side
    b.box_base((1.5, 0, 2.5), (1.0, 1.0, 1.5), "galaxy_blue")                                    # sleeve
    b.box_base((1.5, 0, 2.5), (1.06, 1.06, 0.26), "aurora_violet", bevel=False)                  # cuff
    b.box_base((1.5, 0, 2.76), (1.08, 1.08, 0.05), "rarity_legend", bevel=False)                 # gold trim
    b.box_base((1.5, 0, 1.95), (0.6, 0.6, 0.55), "skin_tan", bevel=False)                        # hand
    b.box((1.28, -0.34, 2.24), (0.16, 0.14, 0.26), "skin_tan", bevel=False)                       # its thumb
    b.star((2.015, 0, 3.35), 0.2, 0.09, 0.03, "rarity_legend", rot=_rz(90) @ _rx(90))            # a star on the sleeve
    # right arm bent, the forearm out in front
    b.box_base((-1.5, 0, 3.0), (1.0, 1.0, 1.0), "galaxy_blue")                                   # upper sleeve
    b.box((-1.5, -0.3, 2.5), (1.0, 1.6, 1.0), "galaxy_blue")                                    # forearm sleeve
    b.box((-1.5, -1.07, 2.5), (1.06, 0.2, 1.06), "aurora_violet", bevel=False)                   # cuff
    b.box((-1.5, -0.945, 2.5), (1.08, 0.05, 1.08), "rarity_legend", bevel=False)                  # gold trim
    b.box((-1.5, -1.42, 2.5), (0.6, 0.5, 0.6), "skin_tan", bevel=False)                          # hand
    b.box((-1.14, -1.5, 2.62), (0.14, 0.2, 0.24), "skin_tan", bevel=False)                       # its thumb
    b.star((-2.015, 0, 3.5), 0.2, 0.09, 0.03, "rarity_legend", rot=_rz(-90) @ _rx(90))          # a star on the sleeve
    # head and face
    b.box_base((0, 0, 3.98), (1.2, 1.2, 1.0), "skin_tan")
    for x in (-0.25, 0.25):
        b.box((x, -0.62, 4.5), (0.16, 0.06, 0.2), "fur_black", bevel=False)                     # eyes
        b.box((x - 0.03, -0.655, 4.55), (0.05, 0.01, 0.06), "milk", bevel=False)                # their sparkle
        b.box((x * 1.12, -0.625, 4.7), (0.3, 0.05, 0.08), "fur_silver", bevel=False)            # bushy brows
        b.box((x * 1.55, -0.62, 4.27), (0.18, 0.05, 0.1), "blush", bevel=False)                 # cheeks
        b.box((x * 0.9, -0.625, 4.24), (0.07, 0.06, 0.07), "fur_black", bevel=False)            # smile corners
    b.box((0, -0.62, 4.2), (0.36, 0.06, 0.07), "fur_black", bevel=False)                        # smile
    b.box((0, -0.64, 4.37), (0.14, 0.08, 0.14), "skin_tan", bevel=False)                        # nose
    b.box((0, -0.66, 4.06), (0.42, 0.12, 0.16), "fur_silver", bevel=False)                      # goatee, over
    b.box((0, -0.73, 3.9), (0.26, 0.08, 0.16), "fur_silver", bevel=False)                       # the collar
    for x, w, h in ((-0.33, 0.36, 0.14), (0.0, 0.3, 0.1), (0.33, 0.36, 0.14)):
        b.box((x, -0.62, 4.98 - h / 2), (w, 0.04, h), "fur_silver", bevel=False)                # hair under the hood
    # hood
    b.box_base((0, 0, 4.98), (1.5, 1.5, 0.2), "night_sky")                                       # top
    b.box_base((0, 0.675, 3.98), (1.5, 0.15, 1.0), "night_sky", bevel=False)                     # back
    for sx in (1, -1):
        b.box_base((sx * 0.675, -0.075, 3.98), (0.15, 1.35, 1.0), "night_sky", bevel=False)     # sides
        b.box_base((sx * 0.675, -0.765, 3.98), (0.09, 0.03, 1.0), "rarity_legend", bevel=False)  # gold edge
    b.box((0, -0.765, 5.025), (1.44, 0.03, 0.09), "rarity_legend", bevel=False)
    b.wedge((0, 0.43, 5.4), (0.8, 0.8, 0.44), "night_sky", bevel=False, rot=_rz(180))            # tip, folded back
    b.sphere((0, 0.92, 5.17), 0.11, "rarity_legend", segments=8, rings=5)                         # its tassel
    for sx in (1, -1):
        b.star((sx * 0.765, -0.15, 4.62), 0.13, 0.06, 0.03, "rarity_legend",
               rot=_rz(90 * sx) @ _rx(90))                                                       # stars on the hood
    # lantern hung from the right hand on a short bail
    lx, ly = -1.5, -1.42
    b.cyl((lx, ly, 2.06), 0.03, 0.28, "fur_black", segments=4, bevel=False)                      # bail
    b.pyramid((lx, ly, 1.82), 0.5, 0.2, "rarity_legend")                                         # cap
    b.box((lx, ly, 1.1), (0.5, 0.5, 0.08), "fur_black", bevel=False)                             # base
    for dx in (-0.21, 0.21):
        for dy in (-0.21, 0.21):
            b.box((lx + dx, ly + dy, 1.46), (0.06, 0.06, 0.72), "fur_black", bevel=False)       # posts
    bulb = Builder()
    bulb.box((lx, ly, 1.46), (0.36, 0.36, 0.64), "lamp_warm", bevel=False)
    return [b.finalize("CatCafe_NPC_Dealer_Body", mat), bulb.finalize("CatCafe_NPC_Dealer_Bulb", mat)]


ASSETS = {"CatCafe_NPC_Dealer": (build_dealer, 1800)}
