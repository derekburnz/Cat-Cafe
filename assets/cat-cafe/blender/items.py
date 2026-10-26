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


def build_gloves(mat):
    """Pair of chunky catching gloves lying on the floor."""
    b = Builder()
    for sx in (-1, 1):
        x = sx * 0.55
        b.box_base((x, 0, 0), (0.8, 1.0, 0.3), "mint")
        b.box_base((x, 0.6, 0), (0.7, 0.4, 0.28), "caramel_wood")             # cuff
        b.box((x + sx * 0.5, -0.1, 0.15), (0.3, 0.45, 0.28), "mint", rot=(math.radians(sx * 30), "Z"))  # thumb
        b.box((x, -0.52, 0.15), (0.78, 0.06, 0.26), "blush", bevel=False)      # fingertip pad
    return [b.finalize("CatCafe_Item_Gloves", mat)]


ASSETS = {
    "CatCafe_Item_FoodBowl": (build_food_bowl, 300),
    "CatCafe_Item_FoodBowl_Premium": (build_food_bowl_premium, 400),
    "CatCafe_Item_Kibble": (build_kibble, 300),
    "CatCafe_Item_TunaCan": (build_tuna_can, 300),
    "CatCafe_Item_Salmon": (build_salmon, 400),
    "CatCafe_Item_Gloves": (build_gloves, 400),
}
