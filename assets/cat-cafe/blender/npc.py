"""NPCs: blocky Roblox proportions, facing -Y, pivot at feet.
Customers: A adult (5 studs), B kid (4 studs), C elder (5 studs, grey hair, cane), Rich (top hat,
tuxedo, gold cane; the daytime rich customer). Dealer: the night food dealer in a starry hooded
cloak with a lantern (Body + Bulb objects; the Bulb goes Neon at night)."""

import math

from common import Builder, scale_mesh

VARIANTS = {
    "A": dict(skin="skin_light", shirt="shirt_blue", pants="pants_navy", hair="hair_brown", scale=1.0),
    "B": dict(skin="skin_tan", shirt="shirt_red", pants="dark_wood", hair="choco", scale=0.8, cap=True),
    "C": dict(skin="skin_deep", shirt="shirt_green", pants="pants_navy", hair="fur_grey", scale=1.0, cane=True),
    "Rich": dict(skin="skin_light", shirt="fur_black", pants="fur_black", hair="hair_brown", scale=1.0, cane=True,
                 moustache="hair_brown", cane_col="fur_black", knob="rarity_legend", top_hat=True, suit=True),
}


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
    """Mysterious but friendly: a starry deep-blue cloak and hood, a warm smile and rosy cheeks
    under the hood, a lantern held out in the right hand."""
    b = Builder()
    b.cyl_base((0, 0, 0), 1.3, 3.9, "galaxy_blue", segments=8, radius2=0.95)                  # cloak
    b.cyl_base((0, 0, 0), 1.33, 0.25, "aurora_violet", segments=8, radius2=1.31, bevel=False)  # hem
    for (x, z, r) in ((-0.45, 0.9, 0.16), (0.35, 1.6, 0.12), (-0.2, 2.5, 0.1), (0.5, 0.55, 0.1), (0.1, 3.1, 0.09)):
        rad = 1.3 - 0.35 * z / 3.9
        b.star((x, -rad * math.cos(math.radians(22.5)) - 0.02, z), r, r * 0.45, 0.03, "rarity_legend",
               rot=(math.radians(90), "X"))
    b.ring((0, 0, 3.85), 0.7, 0.2, 0.22, "aurora_violet", segments=8, bevel=False)            # scarf
    b.crescent((0.0, -0.72, 3.62), 0.12, 0.08, 0.04, "sparkle")                                 # moon pin
    b.box_base((0, 0, 3.9), (1.2, 1.2, 1.0), "skin_tan")                                        # head
    for x in (-0.25, 0.25):
        b.box((x, -0.62, 4.5), (0.16, 0.06, 0.2), "fur_black", bevel=False)                     # eyes
        b.box((x * 1.5, -0.62, 4.22), (0.18, 0.05, 0.1), "blush", bevel=False)                  # cheeks
    b.box((0, -0.62, 4.2), (0.36, 0.06, 0.07), "fur_black", bevel=False)                        # smile
    for x in (-0.2, 0.2):
        b.box((x * 1.15, -0.62, 4.24), (0.07, 0.06, 0.07), "fur_black", bevel=False)
    b.box((0, 0.05, 5.0), (1.55, 1.45, 0.16), "night_sky")                                      # hood top
    b.box((0, 0.7, 4.4), (1.55, 0.16, 1.4), "night_sky")                                        # hood back
    for x in (-0.72, 0.72):
        b.box((x, 0.0, 4.35), (0.14, 1.45, 1.4), "night_sky")                                   # hood sides
        b.box((x, -0.73, 4.35), (0.16, 0.04, 1.3), "sparkle", bevel=False)                      # gold trim
    b.box((0, -0.73, 5.0), (1.55, 0.04, 0.12), "sparkle", bevel=False)
    b.pyramid((0, 0.55, 5.05), 0.7, 0.6, "night_sky", rot=(math.radians(-35), "X"))            # hood point
    b.box((-1.15, -0.35, 3.0), (0.6, 1.3, 0.6), "galaxy_blue", rot=(math.radians(-20), "X"))   # sleeve forward
    b.box_base((-1.15, -1.0, 2.55), (0.45, 0.45, 0.45), "skin_tan")                              # hand
    b.box((1.1, 0, 2.6), (0.6, 0.6, 1.5), "galaxy_blue", rot=(math.radians(-8), "Y"))          # sleeve down
    b.box_base((1.18, 0, 1.6), (0.45, 0.45, 0.45), "skin_tan")
    lx, ly = -1.15, -1.0                                                                         # lantern under the hand
    b.cyl((lx, ly, 2.4), 0.03, 0.3, "fur_black", segments=4, bevel=False)
    b.pyramid((lx, ly, 2.08), 0.48, 0.18, "rarity_legend")
    b.box((lx, ly, 1.45), (0.46, 0.46, 0.08), "fur_black", bevel=False)
    for dx in (-0.2, 0.2):
        for dy in (-0.2, 0.2):
            b.box((lx + dx, ly + dy, 1.77), (0.05, 0.05, 0.6), "fur_black", bevel=False)
    bulb = Builder()
    bulb.box((lx, ly, 1.77), (0.32, 0.32, 0.55), "lamp_warm", bevel=False)
    return [b.finalize("CatCafe_NPC_Dealer_Body", mat), bulb.finalize("CatCafe_NPC_Dealer_Bulb", mat)]


ASSETS = {f"CatCafe_NPC_Customer_{k}": (lambda mat, k=k: build_customer(k, mat), 1000) for k in VARIANTS}
ASSETS["CatCafe_NPC_Dealer"] = (build_dealer, 1200)
