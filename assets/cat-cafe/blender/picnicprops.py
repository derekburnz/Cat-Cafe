"""Picnic Party props (#5572, Derek 2026-11-20: make the Picnic Basket cool and clean), in Roblox axes (RB: y up,
-Z the front). Each pivot is the middle of its underside on the ground or table, so it sits where it is placed.

  CatCafe_Prop_PicnicBlanket          a red and cream checked blanket, 6 x 6 studs and flat (0.08 tall), a cream hem.
  CatCafe_Prop_PicnicBlanket_Rolled   the same blanket rolled up: a 6 stud roll lying along X with a checked wrap and
                                      a tied strap, for the moment before it is spread (swap it for the flat one).
  CatCafe_Prop_PicnicSandwich         a picnic sandwich on a pick with an olive, about 0.7 wide.
  CatCafe_Prop_PicnicCupcake          a striped blue cupcake with a pink swirl and a cherry, about 0.6 tall.
  CatCafe_Prop_PicnicLemonade         a glass of lemonade with a striped straw and a lemon slice, about 0.8 tall.
The three treats follow the Picnic Treats pick card icons (window_icons.py), with fewer faces for the phone budget.
"""

import math

from common import RB

BLANKET, ROLLED = "CatCafe_Prop_PicnicBlanket", "CatCafe_Prop_PicnicBlanket_Rolled"
SANDWICH, CUPCAKE, LEMONADE = "CatCafe_Prop_PicnicSandwich", "CatCafe_Prop_PicnicCupcake", "CatCafe_Prop_PicnicLemonade"
SIZE, N = 6.0, 6                      # the blanket's side and its checks per side


def build_blanket(mat):
    b = RB()
    h = SIZE / 2
    b.span((-h, 0.0, -h), (h, 0.06, h), "offwhite")
    c = SIZE / N
    for i in range(N):                          # red bands both ways: crossings darker, the classic gingham
        if i % 2 == 0:
            b.span((-h + i * c + c * 0.1, 0.06, -h + 0.1), (-h + i * c + c * 0.9, 0.07, h - 0.1), "blush")
    for j in range(N):
        if j % 2 == 0:
            b.span((-h + 0.1, 0.07, -h + j * c + c * 0.1), (h - 0.1, 0.08, -h + j * c + c * 0.9), "blush")
    for i in range(0, N, 2):
        for j in range(0, N, 2):
            b.span((-h + i * c + c * 0.1, 0.08, -h + j * c + c * 0.1), (-h + i * c + c * 0.9, 0.085, -h + j * c + c * 0.9),
                   "bowl_red")
    return [b.finalize(BLANKET, mat)]


def build_rolled(mat):
    b = RB()
    r, L = 0.32, SIZE
    b.cyl((0, r, 0), r, L, "offwhite", axis="X", segments=10)
    for k in range(6):                          # checked bands round the roll
        x = -L / 2 + (k + 0.5) * L / 6
        b.cyl((x, r, 0), r + 0.015, L / 12, ("bowl_red", "blush")[k % 2], axis="X", segments=10)
    for x in (-L / 4, L / 4):                   # two leather straps
        b.cyl((x, r, 0), r + 0.03, 0.12, "choco", axis="X", segments=10)
    b.cyl((-L / 2 - 0.005, r, 0), r * 0.7, 0.02, "bowl_red", axis="X", segments=10)    # the rolled ends
    b.cyl((L / 2 + 0.005, r, 0), r * 0.7, 0.02, "bowl_red", axis="X", segments=10)
    return [b.finalize(ROLLED, mat)]


def build_sandwich(mat):
    b = RB()
    w, d = 0.7, 0.55
    b.span((-w / 2, 0.0, -d / 2), (w / 2, 0.13, d / 2), "treat_tan")                    # bottom slice
    b.span((-w / 2 - 0.04, 0.13, -d / 2 - 0.04), (w / 2 + 0.04, 0.17, d / 2 + 0.04), "leaf_green")   # lettuce
    b.span((-w / 2 + 0.02, 0.17, -d / 2 + 0.02), (w / 2 + 0.02, 0.21, d / 2 + 0.02), "rarity_legend")  # cheese
    for x in (-0.16, 0.16):                                                                # tomato
        b.cyl((x, 0.235, -0.04), 0.15, 0.05, "shirt_red", segments=8)
    b.span((-w / 2, 0.26, -d / 2), (w / 2, 0.39, d / 2), "treat_tan")                    # top slice
    b.span((-w / 2 - 0.01, 0.37, -d / 2 - 0.01), (w / 2 + 0.01, 0.4, d / 2 + 0.01), "fur_caramel")   # crust
    b.cyl((0, 0.55, 0), 0.02, 0.36, "caramel_wood", segments=6)                         # the pick
    b.ball((0, 0.75, 0), 0.08, "shirt_green")                                           # the olive
    return [b.finalize(SANDWICH, mat)]


def build_cupcake(mat):
    b = RB()
    b.cyl((0, 0.15, 0), 0.2, 0.3, "pastel_sky", r2=0.27, segments=10)                   # wrapper (wider at the top)
    for k in range(5):                                                                     # its pleats
        t = 2 * math.pi * k / 5
        b.span((0.235 * math.cos(t) - 0.02, 0.02, 0.235 * math.sin(t) - 0.02),
               (0.235 * math.cos(t) + 0.02, 0.29, 0.235 * math.sin(t) + 0.02), "fish_blue")
    b.cyl((0, 0.33, 0), 0.29, 0.07, "treat_tan", segments=10)                           # cake top
    for r, y, hh in ((0.27, 0.42, 0.12), (0.2, 0.52, 0.1), (0.12, 0.61, 0.08)):           # frosting swirl
        b.cyl((0, y, 0), r, hh, "fur_strawberry", r2=r * 0.8, segments=10)
    b.ball((0, 0.7, 0), 0.07, "shirt_red")                                              # cherry
    for k, sw in enumerate(("sparkle", "fish_blue", "leaf_green")):                       # sprinkles
        t = 2 * math.pi * k / 3 + 0.4
        b.span((0.2 * math.cos(t) - 0.03, 0.47, 0.2 * math.sin(t) - 0.01), (0.2 * math.cos(t) + 0.03, 0.49, 0.2 * math.sin(t) + 0.01), sw)
    return [b.finalize(CUPCAKE, mat)]


def build_lemonade(mat):
    b = RB()
    b.cyl((0, 0.03, 0), 0.2, 0.06, "fish_belly", segments=10)                           # thick base
    b.cyl((0, 0.32, 0), 0.21, 0.52, "rarity_legend", r2=0.245, segments=10)             # the lemonade seen through the glass
    b.cyl((0, 0.595, 0), 0.25, 0.03, "glass", segments=10)                              # clear glass rim
    b.cyl((0, 0.615, 0), 0.225, 0.02, "sparkle", segments=10)                           # the drink top, fizzy
    b.span((-0.08, 0.56, -0.06), (0.02, 0.64, 0.04), "fish_belly")                      # an ice cube
    b.cyl((0.08, 0.72, 0.03), 0.025, 0.5, "milk", segments=6)                           # straw
    for y in (0.82, 0.92):
        b.cyl((0.08, y, 0.03), 0.03, 0.04, "nose_pink", segments=6)
    b.cyl((-0.23, 0.62, 0), 0.12, 0.03, "rarity_legend", axis="Z", segments=10)         # lemon slice on the rim
    b.cyl((-0.23, 0.62, -0.017), 0.09, 0.01, "sparkle", axis="Z", segments=10)
    return [b.finalize(LEMONADE, mat)]


ASSETS = {
    BLANKET: (build_blanket, 600),
    ROLLED: (build_rolled, 600),
    SANDWICH: (build_sandwich, 300),
    CUPCAKE: (build_cupcake, 300),
    LEMONADE: (build_lemonade, 300),
}
