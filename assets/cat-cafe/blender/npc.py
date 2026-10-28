"""NPCs, facing -Y, pivot at feet (the cafe customers are in customers.py).
Dealer: the night food dealer in a starry robe and a gold-edged hood, holding a lantern out (Body + Bulb objects;
the Bulb goes Neon at night)."""

import math

from mathutils import Matrix

from common import Builder


def _rz(deg):
    return Matrix.Rotation(math.radians(deg), 3, "Z")


def build_dealer(mat):
    """Mysterious but friendly, kept to a few clean blocks: a deep-blue robe flaring a little to a violet hem, a violet
    sash, the cart's pale moon on the chest and its gold stars on the skirt; a dark hood with a gold edge round a
    smiling face, its tip folded back; the right arm bent to hold a lantern out in front, the left at the side."""
    b = Builder()
    up = (math.radians(90), "X")                                                                 # stand a star up, facing -Y
    # robe
    b.box_base((0, 0, 0.06), (2.0, 1.2, 3.94), "galaxy_blue")                                    # body, to the shoulders
    for sx in (1, -1):
        b.wedge((sx * 1.075, 0, 1.01), (1.2, 0.15, 1.9), "galaxy_blue", bevel=False,
                rot=_rz(90 * sx))                                                                # the skirt flares out
        b.box_base((sx * 0.45, -0.55, 0), (0.6, 0.5, 0.2), "fur_black", bevel=False)            # shoes under the hem
    b.box_base((0, 0, 0.02), (2.36, 1.26, 0.26), "aurora_violet", bevel=False)                   # hem
    b.box((0, 0, 2.0), (2.06, 1.26, 0.2), "aurora_violet", bevel=False)                          # sash
    b.box((0, -0.64, 2.0), (0.3, 0.04, 0.26), "rarity_legend", bevel=False)                      # its gold clasp
    b.crescent((0.45, -0.615, 3.2), 0.24, 0.15, 0.04, "sparkle")                                 # the moon
    for x, z, r in ((-0.5, 1.15, 0.2), (0.45, 0.7, 0.15), (0.0, 1.55, 0.12)):
        b.star((x, -0.615, z), r, r * 0.45, 0.03, "rarity_legend", rot=up)                      # stars on the skirt
    b.star((0, 0.615, 2.9), 0.3, 0.13, 0.03, "rarity_legend", rot=up)                            # one on the back
    # left arm at the side
    b.box_base((1.5, 0, 2.5), (1.0, 1.0, 1.5), "galaxy_blue")                                    # sleeve
    b.box_base((1.5, 0, 2.5), (1.06, 1.06, 0.26), "aurora_violet", bevel=False)                  # cuff
    b.box_base((1.5, 0, 1.95), (0.6, 0.6, 0.55), "skin_tan", bevel=False)                        # hand
    # right arm bent, the forearm out in front
    b.box_base((-1.5, 0, 3.0), (1.0, 1.0, 1.0), "galaxy_blue")                                   # upper sleeve
    b.box((-1.5, -0.3, 2.5), (1.0, 1.6, 1.0), "galaxy_blue")                                    # forearm sleeve
    b.box((-1.5, -1.07, 2.5), (1.06, 0.2, 1.06), "aurora_violet", bevel=False)                   # cuff
    b.box((-1.5, -1.42, 2.5), (0.6, 0.5, 0.6), "skin_tan", bevel=False)                          # hand
    # head and face
    b.box_base((0, 0, 3.98), (1.2, 1.2, 1.0), "skin_tan")
    for x in (-0.25, 0.25):
        b.box((x, -0.62, 4.5), (0.16, 0.06, 0.2), "fur_black", bevel=False)                     # eyes
        b.box((x * 1.55, -0.62, 4.27), (0.18, 0.05, 0.1), "blush", bevel=False)                 # cheeks
        b.box((x * 0.9, -0.625, 4.24), (0.07, 0.06, 0.07), "fur_black", bevel=False)            # smile corners
    b.box((0, -0.62, 4.2), (0.36, 0.06, 0.07), "fur_black", bevel=False)                        # smile
    # hood
    b.box_base((0, 0, 4.98), (1.5, 1.5, 0.2), "night_sky")                                       # top
    b.box_base((0, 0.675, 3.98), (1.5, 0.15, 1.0), "night_sky", bevel=False)                     # back
    for sx in (1, -1):
        b.box_base((sx * 0.675, -0.075, 3.98), (0.15, 1.35, 1.0), "night_sky", bevel=False)     # sides
        b.box_base((sx * 0.675, -0.765, 3.98), (0.09, 0.03, 1.0), "rarity_legend", bevel=False)  # gold edge
    b.box((0, -0.765, 5.025), (1.44, 0.03, 0.09), "rarity_legend", bevel=False)
    b.wedge((0, 0.43, 5.4), (0.8, 0.8, 0.44), "night_sky", bevel=False, rot=_rz(180))            # tip, folded back
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


ASSETS = {"CatCafe_NPC_Dealer": (build_dealer, 1200)}
