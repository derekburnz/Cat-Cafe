"""The Golden Fish Market's tab pictures (#1628, Derek2 11-05: "add new ui icons for these 3 buttons: crates,
treats..., fresh catch"), rendered by icons.py as CatCafe_Icon_Market_<Tab> (transparent, outlined, 512 px) in place
of the tabs' emoji. Each is built from pictures the Market already shows, so a tab looks like what it sells:

  Crates      the Classic Cafe Crate in front with its golden crate behind
  Treats      the Star Treat leaning on the Golden Espresso cup (a treat and a perk)
  FreshCatch  a wooden fish tray of ice with a fresh blue fish on it, and the Quick Bait Potion standing at the back

Blender axes (x right, -y toward the camera, z up); nothing here is a game model.
"""

import math

import crates
import icon_art
import potion_icons
from common import Builder
from icon_compose import place

X = (math.radians(90), "X")


def crates_tab(mat):
    gold = place(crates.build_crate("Classic", mat, True), at=(0.75, 1.0, 0.55), scale=0.85)
    front = place(crates.build_crate("Classic", mat), at=(-0.35, -0.4, 0.0))
    return gold + front


def treats_tab(mat):
    cup = place(icon_art.golden_espresso(mat), at=(0.75, 0.6, 0.0), scale=1.05)
    star = place(icon_art.star_treat(mat), at=(-0.6, -0.6, 0.0), scale=0.85, yaw=8)
    return cup + star


def _fish(b, x, y, z, length, sw="fish_blue", belly="fish_belly"):
    """A plump fish lying on its side along x, its head toward -x, facing the camera, its tail flicked up."""
    r = length / 2
    b.sphere((x, y, z), r, sw, segments=18, rings=10, scale=(1.0, 0.38, 0.46))
    b.sphere((x - 0.05 * r, y - 0.06 * r, z - 0.14 * r), r * 0.8, belly, segments=16, rings=8,
             scale=(1.0, 0.3, 0.3))
    tx = x + r * 0.85                                                               # a forked tail
    b.prism((tx, y, z), [(0.0, 0.08 * r), (0.0, -0.08 * r), (0.42 * r, 0.42 * r), (0.3 * r, 0.0),
                         (0.42 * r, -0.42 * r)][::1], 0.1, sw, rot=X)
    b.prism((x - 0.05 * r, y - 0.02, z + 0.4 * r), [(-0.3 * r, 0.0), (0.3 * r, 0.0), (0.1 * r, 0.24 * r)], 0.06,
            sw, rot=X)                                                              # back fin
    b.cyl((x - 0.62 * r, y - 0.37 * r, z + 0.08 * r), 0.11 * r, 0.04, "offwhite", segments=10, rot=X)  # eye
    b.cyl((x - 0.63 * r, y - 0.39 * r, z + 0.07 * r), 0.06 * r, 0.04, "fur_black", segments=8, rot=X)
    b.box((x - 0.35 * r, y - 0.37 * r, z), (0.04, 0.03, 0.3 * r), "fish_belly", bevel=False)   # gill line
    b.box((x + 0.1 * r, y - 0.39 * r, z + 0.2 * r), (0.3 * r, 0.03, 0.05), "offwhite", bevel=False,
          rot=(math.radians(-12), "Y"))                                              # a shine


def fresh_catch_tab(mat):
    b = Builder()
    W, D = 2.6, 1.6
    b.box((0, 0, 0.12), (W, D, 0.24), "caramel_wood")                              # the tray's floor
    for sy in (-1, 1):
        b.box((0, sy * (D / 2 - 0.06), 0.3), (W, 0.12, 0.36), "caramel_wood")      # its sides
    for sx in (-1, 1):
        b.box((sx * (W / 2 - 0.06), 0, 0.3), (0.12, D, 0.36), "caramel_wood")
    b.box((0, -D / 2 - 0.005, 0.3), (W * 0.5, 0.02, 0.12), "dark_wood", bevel=False)   # a slat line
    for k in range(14):                                                            # the ice
        x = -1.05 + 0.3 * (k % 8) + 0.1 * (k // 8)
        y = -0.35 + 0.45 * (k // 8)
        b.box((x, y, 0.42 + 0.03 * (k % 3)), (0.26, 0.26, 0.2), ("milk", "pastel_sky")[k % 2],
              rot=(math.radians(15 * (k % 4) - 20), "Z"))
    _fish(b, -0.1, -0.15, 0.78, 2.0)
    tray = [b.finalize("CatCafe_IconArt_Market_FreshCatch", mat)]
    potion = place(potion_icons.flask("QuickBait", mat), at=(-0.85, 0.55, 0.2), scale=0.62)
    return tray + potion


BUILDERS = {"Crates": crates_tab, "Treats": treats_tab, "FreshCatch": fresh_catch_tab}
