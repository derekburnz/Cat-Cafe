"""Items: food bowls, lure foods (kibble, tuna, salmon, the four dealer foods), nets, the rich
customer's tip pile. Pivot base center. Dealer foods sit on the kibble in CatCafe_Item_FoodBowl:
put their pivot at the bowl's pivot plus FOOD_IN_BOWL up."""

import math

from mathutils import Matrix

from common import Builder

FOOD_IN_BOWL = 0.18      # kibble top in CatCafe_Item_FoodBowl, studs above its pivot
FOODS = ("Sardines", "Caviar", "MoonMilk", "StarTreat")     # the dealer foods that sit in a bowl


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
    # the bag hangs from the hoop: a short mouth band tucked inside the hoop, then netting narrowing downward
    bag_col = "offwhite" if level < 3 else "fish_belly"
    bag = Builder()
    bag.cyl((0, hy, -0.05), hoop_r - 0.02, 0.14, bag_col, segments=14, bevel=False)                      # mouth
    bag.cyl((0, hy, -0.6), 0.22, 1.0, bag_col, segments=14, radius2=hoop_r - 0.06, bevel=False)          # netting
    name = f"CatCafe_Item_Net_L{level}"
    return [h.finalize(name + "_Handle", mat), bag.finalize(name + "_Bag", mat)]


def _rz(deg):
    return Matrix.Rotation(math.radians(deg), 3, "Z")


def build_sardines(mat):
    """Three sardines fanned on the kibble, silver bellies, heads toward -Y."""
    b = Builder()
    for (x, y, z, a) in ((-0.15, 0.02, 0.06, 14), (0.16, 0.0, 0.06, -12), (0.0, -0.04, 0.15, 2)):
        R = _rz(a)
        b.sphere((x, y, z), 0.27, "fish_blue", segments=8, rings=4, scale=(0.32, 1.0, 0.3), rot=R)
        b.sphere((x, y, z - 0.025), 0.26, "metal", segments=8, rings=4, scale=(0.3, 0.92, 0.22), rot=R)
        tx, ty = -math.sin(math.radians(a)) * 0.3, math.cos(math.radians(a)) * 0.3
        b.cyl((x + tx, y + ty, z), 0.1, 0.03, "fish_blue", segments=3, bevel=False,
              rot=R @ Matrix.Rotation(math.radians(90), 3, "Y"))                                   # tail fin
        ex, ey = math.sin(math.radians(a)) * 0.2, -math.cos(math.radians(a)) * 0.2
        b.box((x + ex + 0.05, y + ey, z + 0.04), (0.04, 0.04, 0.04), "fur_black", bevel=False)  # eye
    return [b.finalize("CatCafe_Item_Sardines", mat)]


def build_caviar(mat):
    """A little round tin of caviar with a gold rim and a pearl spoon."""
    b = Builder()
    b.cyl_base((0, 0, 0), 0.3, 0.12, "galaxy_blue", segments=12)
    b.ring((0, 0, 0.13), 0.31, 0.04, 0.03, "rarity_legend", segments=12, bevel=False)
    b.cyl_base((0, 0, 0.12), 0.27, 0.04, "fur_black", segments=12, bevel=False)
    b.sphere((0, 0, 0.15), 0.22, "fur_black", segments=10, rings=4, scale=(1, 1, 0.35))         # heaped pearls
    for (x, y) in ((0.08, -0.05), (-0.1, 0.06), (0.02, 0.12), (-0.04, -0.12), (0.14, 0.08)):
        b.ico((x, y, 0.21), 0.035, "galaxy_blue", subdivisions=1)
    b.box((0.18, -0.22, 0.2), (0.07, 0.42, 0.03), "offwhite", bevel=False, rot=_rz(-35))       # spoon
    b.sphere((0.05, -0.04, 0.21), 0.07, "offwhite", segments=8, rings=4, scale=(1, 1.3, 0.3))
    b.ring((0, 0, 0.0), 0.32, 0.05, 0.02, "rarity_legend", segments=12, bevel=False)
    return [b.finalize("CatCafe_Item_Caviar", mat)]


def build_moon_milk(mat):
    """A pool of moon milk on the kibble with a small crescent moon and two stars over it."""
    b = Builder()
    b.cyl_base((0, 0, 0), 0.36, 0.04, "milk", segments=14, bevel=False)
    b.sphere((0, 0, 0.04), 0.3, "milk", segments=10, rings=4, scale=(1, 1, 0.12))
    b.crescent((0, 0.0, 0.42), 0.17, 0.12, 0.06, "sparkle")
    b.cyl((0, 0, 0.2), 0.02, 0.14, "sparkle", segments=4, bevel=False)                        # moon stalk
    b.star((-0.22, -0.05, 0.35), 0.07, 0.03, 0.03, "sparkle", rot=(math.radians(90), "X"))
    b.star((0.24, 0.02, 0.48), 0.06, 0.025, 0.03, "sparkle", rot=(math.radians(90), "X"))
    return [b.finalize("CatCafe_Item_MoonMilk", mat)]


def build_star_treat(mat):
    """A gold star biscuit leaning on a smaller one, flecked with sparkle."""
    b = Builder()
    b.star((0.1, 0.08, 0.04), 0.2, 0.09, 0.06, "treat_tan")
    tilt = Matrix.Rotation(math.radians(55), 3, "X")
    b.star((-0.02, -0.04, 0.2), 0.27, 0.12, 0.08, "rarity_legend", rot=tilt)
    for (x, z) in ((-0.08, 0.27), (0.07, 0.2), (0.0, 0.33)):
        b.box((x, -0.11, z), (0.04, 0.02, 0.04), "sparkle", bevel=False, rot=tilt)
    return [b.finalize("CatCafe_Item_StarTreat", mat)]


def build_tip_pile(mat):
    """The rich customer's tip: a heap of gold coins with a few short stacks. Sits on a table."""
    b = Builder()
    b.cyl_base((0, 0, 0), 0.42, 0.18, "rarity_legend", segments=10, radius2=0.18, bevel=False)    # heap core
    coin = dict(segments=10, bevel=False)
    for (x, y, n) in ((-0.42, 0.15, 4), (0.38, 0.25, 3), (0.15, -0.4, 2)):                     # stacks
        for k in range(n):
            b.cyl_base((x + 0.015 * (k % 2), y, 0.06 * k), 0.16, 0.055, "rarity_legend", **coin)
    for (x, y, z, a, ax) in ((0.0, 0.0, 0.22, 20, "X"), (-0.15, -0.2, 0.12, -30, "Y"), (0.25, -0.05, 0.12, 25, "Y"),
                             (-0.1, 0.25, 0.12, 30, "X"), (0.55, -0.35, 0.03, 0, "X")):
        b.cyl((x, y, z), 0.16, 0.05, "rarity_legend", rot=(math.radians(a), ax), **coin)         # loose coins
    for (x, y, z) in ((0.0, 0.0, 0.26), (-0.42, 0.15, 0.25)):
        b.box((x, y, z), (0.06, 0.06, 0.02), "sparkle", bevel=False)                           # glints
    return [b.finalize("CatCafe_Prop_TipPile", mat)]


ASSETS = {
    "CatCafe_Item_FoodBowl": (build_food_bowl, 300),
    "CatCafe_Item_FoodBowl_Premium": (build_food_bowl_premium, 400),
    "CatCafe_Item_Kibble": (build_kibble, 300),
    "CatCafe_Item_TunaCan": (build_tuna_can, 300),
    "CatCafe_Item_Salmon": (build_salmon, 400),
    "CatCafe_Item_Net_L1": (lambda m: build_net(1, m), 500),
    "CatCafe_Item_Net_L2": (lambda m: build_net(2, m), 600),
    "CatCafe_Item_Net_L3": (lambda m: build_net(3, m), 650),
    "CatCafe_Item_Sardines": (build_sardines, 400),
    "CatCafe_Item_Caviar": (build_caviar, 600),
    "CatCafe_Item_MoonMilk": (build_moon_milk, 300),
    "CatCafe_Item_StarTreat": (build_star_treat, 300),
    "CatCafe_Prop_TipPile": (build_tip_pile, 600),
}
