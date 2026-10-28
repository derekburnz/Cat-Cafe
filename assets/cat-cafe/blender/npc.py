"""NPCs: blocky Roblox proportions, facing -Y, pivot at feet.
Customers: A adult (5 studs), B kid (4 studs), C elder (5 studs, grey hair, cane), Rich (top hat,
tuxedo, gold cane; the daytime rich customer). Dealer: the night food dealer in a starry robe and
a gold-edged hood, holding a lantern out (Body + Bulb objects; the Bulb goes Neon at night)."""

import math

from mathutils import Matrix

from common import Builder, scale_mesh

VARIANTS = {
    "A": dict(skin="skin_light", shirt="shirt_blue", pants="pants_navy", hair="hair_brown", scale=1.0),
    "B": dict(skin="skin_tan", shirt="shirt_red", pants="dark_wood", hair="choco", scale=0.8, cap=True),
    "C": dict(skin="skin_deep", shirt="shirt_green", pants="pants_navy", hair="fur_grey", scale=1.0, cane=True),
    "Rich": dict(skin="skin_light", shirt="fur_black", pants="fur_black", hair="hair_brown", scale=1.0, cane=True,
                 moustache="hair_brown", cane_col="fur_black", knob="rarity_legend", top_hat=True, suit=True),
}


def _rz(deg):
    return Matrix.Rotation(math.radians(deg), 3, "Z")


def build_customer(variant, mat):
    v = VARIANTS[variant]
    b = Builder()
    for x in (-0.5, 0.5):
        b.box_base((x, 0, 0), (0.98, 0.98, 2.0), v["pants"])
        b.box_base((x, 0, 0), (1.0, 1.02, 0.4), "fur_black")
    b.box_base((0, 0, 2.0), (2.0, 1.0, 2.0), v["shirt"])
    for x in (-1.5, 1.5):
        b.box_base((x, 0, 2.0), (0.98, 0.98, 1.0), v["skin"])
        b.box_base((x, 0, 3.0), (1.0, 1.0, 1.0), v["shirt"])
    b.box_base((0, 0, 4.0), (1.2, 1.2, 1.0), v["skin"])
    if v.get("cap"):
        b.box_base((0, 0, 4.85), (1.3, 1.3, 0.25), "mint")
        b.box((0, -0.85, 4.9), (1.3, 0.5, 0.08), "mint", bevel=False)            # cap peak
    else:
        b.box_base((0, 0, 4.75), (1.28, 1.28, 0.3), v["hair"])
        b.box((0, -0.62, 4.6), (1.28, 0.08, 0.3), v["hair"], bevel=False)
    for x in (-0.25, 0.25):
        b.box((x, -0.62, 4.45), (0.14, 0.06, 0.2), "fur_black", bevel=False)
    if v.get("cane"):
        b.box((0, -0.62, 4.0), (0.6, 0.06, 0.2), v.get("moustache", "fur_grey"), bevel=False)
        b.cyl_base((2.1, -0.3, 0), 0.08, 2.4, v.get("cane_col", "dark_wood"), segments=8)
        b.box((2.1, -0.3, 2.45), (0.5, 0.18, 0.18), v.get("knob", "dark_wood"))
    else:
        b.box((0, -0.62, 4.18), (0.4, 0.06, 0.08), "fur_black", bevel=False)
    if v.get("top_hat"):
        b.box_base((0, 0, 5.02), (1.7, 1.7, 0.1), "fur_black")                          # brim
        b.box_base((0, 0, 5.1), (1.15, 1.15, 1.2), "fur_black")                          # crown
        b.box_base((0, 0, 5.22), (1.18, 1.18, 0.22), "rarity_legend", bevel=False)       # gold band
    if v.get("suit"):
        b.box((0, -0.51, 3.15), (0.6, 0.04, 1.5), "offwhite", bevel=False)               # shirt front
        for x in (-0.15, 0.15):
            b.box((x, -0.55, 3.8), (0.24, 0.04, 0.16), "rarity_legend", bevel=False)      # bow tie
        b.box((0, -0.56, 3.8), (0.09, 0.05, 0.11), "rarity_legend", bevel=False)
        b.box((0.62, -0.52, 3.55), (0.26, 0.04, 0.12), "rarity_legend", bevel=False)      # pocket square
        b.ring((0.25, -0.64, 4.45), 0.15, 0.035, 0.03, "rarity_legend", segments=8, bevel=False,
               rot=(math.radians(90), "X"))                                               # monocle
    ob = b.finalize(f"CatCafe_NPC_Customer_{variant}", mat)
    if v["scale"] != 1.0:
        scale_mesh(ob, v["scale"])
    return [ob]


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


ASSETS = {f"CatCafe_NPC_Customer_{k}": (lambda mat, k=k: build_customer(k, mat), 1000) for k in VARIANTS}
ASSETS["CatCafe_NPC_Dealer"] = (build_dealer, 1200)
