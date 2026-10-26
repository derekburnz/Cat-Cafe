"""Items: food bowls, lure foods (kibble, tuna, salmon), gloves. Pivot base center."""

import math

from common import Builder


def _bowl(b, outer, rim, food, premium=False):
    b.cyl_base((0, 0, 0), 0.45, 0.06, outer, segments=12, bevel=False)
    b.ring((0, 0, 0.18), 0.46, 0.08, 0.26, outer, segments=12, bevel=False)
    if premium:
        b.ring((0, 0, 0.32), 0.48, 0.06, 0.06, rim, segments=12, bevel=False)
    if food:
        b.cyl_base((0, 0, 0.06), 0.38, 0.12, food, segments=12, bevel=False)


def build_food_bowl(mat):
    b = Builder()
    _bowl(b, "bowl_red", None, "kibble")
    return [b.finalize("CatCafe_Item_FoodBowl", mat)]


def build_food_bowl_premium(mat):
    b = Builder()
    _bowl(b, "blush", "rarity_legend", "fish_belly", premium=True)
    b.sphere((0, 0.05, 0.3), 0.22, "fish_blue", segments=8, rings=4, scale=(0.7, 1.3, 0.6))
    b.pyramid((0, 0.42, 0.22), 0.22, 0.22, "fish_blue", rot=(math.radians(90), "X"))
    return [b.finalize("CatCafe_Item_FoodBowl_Premium", mat)]


def build_kibble(mat):
    """Small kibble bag."""
    b = Builder()
    b.box_base((0, 0, 0), (0.7, 0.4, 0.9), "treat_tan")
    b.box((0, -0.21, 0.5), (0.5, 0.02, 0.4), "bowl_red", bevel=False)
    b.box((0, -0.22, 0.5), (0.3, 0.02, 0.2), "fur_black", bevel=False)
    b.box_base((0, 0, 0.9), (0.72, 0.42, 0.1), "treat_tan")
    return [b.finalize("CatCafe_Item_Kibble", mat)]


def build_tuna_can(mat):
    b = Builder()
    b.cyl_base((0, 0, 0), 0.35, 0.3, "metal", segments=12)
    b.cyl_base((0, 0, 0.07), 0.36, 0.16, "fish_blue", segments=12, bevel=False)
    b.ring((0, 0, 0.28), 0.36, 0.05, 0.04, "metal", segments=12, bevel=False)
    b.box((0, -0.365, 0.15), (0.3, 0.01, 0.1), "offwhite", bevel=False)
    return [b.finalize("CatCafe_Item_TunaCan", mat)]


def build_salmon(mat):
    """A whole fish, head toward -Y."""
    b = Builder()
    b.sphere((0, 0, 0.22), 0.35, "fish_blue", segments=10, rings=6, scale=(0.55, 1.0, 0.62))
    b.sphere((0, 0.02, 0.17), 0.3, "fish_belly", segments=10, rings=6, scale=(0.5, 0.9, 0.5))
    b.cyl((0, 0.45, 0.24), 0.24, 0.05, "fish_blue", segments=3, bevel=False, rot=(math.radians(90), "Y"))
    b.cyl((0, 0.0, 0.45), 0.12, 0.04, "fish_blue", segments=3, bevel=False, rot=(math.radians(90), "Y"))
    for x in (-0.12, 0.12):
        b.box((x, -0.2, 0.3), (0.07, 0.07, 0.07), "fur_black", bevel=False)
    return [b.finalize("CatCafe_Item_Salmon", mat)]


def build_net(level, mat):
    """Catching net, a held Tool. Pivot at the grip end; the pole runs forward (-Y in
    Blender, -Z in Roblox) with the hoop at the far end. Handle + Bag objects: set the
    Bag MeshPart to Transparency 0.35 in Studio so it reads as netting."""
    handle_col = ("caramel_wood", "mint", "dark_wood")[level - 1]
    ring_col = ("dark_wood", "metal", "rarity_legend")[level - 1]
    pole = 3.0 + 0.3 * (level - 1)
    hoop_r = 0.9 + 0.15 * (level - 1)
    h = Builder()
    h.cyl((0, -pole / 2, 0), 0.1, pole, handle_col, segments=8, rot=(math.radians(90), "X"))
    h.cyl((0, -0.35, 0), 0.13, 0.7, "fur_black", segments=8, rot=(math.radians(90), "X"))      # grip wrap
    if level >= 2:
        for y in (-1.2, -2.0):
            h.cyl((0, y, 0), 0.12, 0.12, ring_col, segments=8, rot=(math.radians(90), "X"))   # bands
    hy = -pole - hoop_r
    h.ring((0, hy, 0), hoop_r, 0.1, 0.12, ring_col, segments=14, bevel=False)                # hoop, flat
    h.box((0, -pole - 0.05, 0), (0.22, 0.3, 0.22), ring_col)                                   # ferrule
    if level == 3:
        for a in (0, 90, 180, 270):
            r = math.radians(a)
            h.box((math.cos(r) * hoop_r, hy + math.sin(r) * hoop_r, 0.1), (0.1, 0.1, 0.1), "sparkle", bevel=False)
    bag = Builder()
    bag.cyl((0, hy, -0.55), hoop_r - 0.05, 1.0, "offwhite" if level < 3 else "fish_belly", segments=14, radius2=0.25,
            bevel=False)
    name = f"CatCafe_Item_Net_L{level}"
    return [h.finalize(name + "_Handle", mat), bag.finalize(name + "_Bag", mat)]


ASSETS = {
    "CatCafe_Item_FoodBowl": (build_food_bowl, 300),
    "CatCafe_Item_FoodBowl_Premium": (build_food_bowl_premium, 400),
    "CatCafe_Item_Kibble": (build_kibble, 300),
    "CatCafe_Item_TunaCan": (build_tuna_can, 300),
    "CatCafe_Item_Salmon": (build_salmon, 400),
    "CatCafe_Item_Net_L1": (lambda m: build_net(1, m), 500),
    "CatCafe_Item_Net_L2": (lambda m: build_net(2, m), 600),
    "CatCafe_Item_Net_L3": (lambda m: build_net(3, m), 650),
}
