"""The Decor menu's chip pictures (#5366, Derek 2026-11-18: "redo the decor images to be more obvious/less plain
looking"), rendered by icons.py as CatCafe_Icon_DecorTab_<Chip> (transparent, outlined, 512 px) in place of the chips'
emoji. They sit about 26 px tall on a white chip, so each is one bold object with a bright second colour (Design):

  All     the little cafe house (hud_icons.house, with a ridge cap): cream walls, terracotta roof, a door with a paw
  Style   the barista cap: a mint crown on a cream band, a short brim and a coffee bean badge
  Lawn    a round green tree on a grass mound with two little flowers
  Plants  a terracotta pot with three big leaves standing up out of it
  Floor   a checker floor tile, cream and cocoa squares in a wooden edge, seen from above
  Walls   a framed cat picture on a strip of striped wallpaper over a skirting board

Blender axes (x right, -y toward the camera, z up); nothing here is a game model.
"""

import math

from common import Builder

X = (math.radians(90), "X")


def _fin(b, name, mat):
    return [b.finalize("CatCafe_IconArt_DecorTab_" + name, mat)]


def all_tab(mat):
    """hud_icons.house with a ridge cap, so no gap shows where its two roof slopes meet."""
    b = Builder()
    b.box((0, 0, 0.6), (1.8, 1.4, 1.2), "cream")                                   # walls
    for sx in (-1, 1):                                                             # roof slopes
        b.box((sx * 0.43, 0, 1.6), (1.3, 1.6, 0.2), "terracotta", rot=(math.radians(sx * 34.6), "Y"))
    b.box((0, 0, 1.93), (0.34, 1.64, 0.2), "terracotta")                         # ridge cap
    b.prism((0, 0, 1.18), [(-0.9, 0.0), (0.9, 0.0), (0.0, 0.62)], 1.38, "cream", rot=X)   # the gable
    b.box((0.55, 0.2, 1.75), (0.28, 0.28, 0.5), "brick")                           # chimney
    b.box((-0.35, -0.71, 0.42), (0.5, 0.04, 0.8), "dark_wood")                    # door
    b.cyl((-0.35, -0.735, 0.5), 0.11, 0.02, "blush", segments=8, rot=X)            # paw on it
    b.box((0.45, -0.71, 0.7), (0.5, 0.04, 0.42), "pastel_sky")                    # window
    b.box((0.45, -0.72, 0.7), (0.54, 0.02, 0.06), "offwhite")
    b.box((0, -0.72, 0.02), (1.84, 0.04, 0.08), "mint")                           # step trim
    return _fin(b, "All", mat)


def style(mat):
    b = Builder()
    b.cyl_base((0, 0, 0), 0.95, 0.3, "cream", segments=20)                                   # band
    b.cyl_base((0, 0, 0.3), 0.95, 0.72, "mint", segments=20, radius2=0.78)                   # crown
    b.sphere((0, 0, 1.0), 0.78, "mint", segments=20, rings=8, scale=(1, 1, 0.42))           # soft top
    b.cyl((0, 0, 1.36), 0.14, 0.12, "sign_teal", segments=10)                                # the button on top
    b.box((0, -1.15, 0.12), (1.5, 0.75, 0.12), "sign_teal", rot=(math.radians(14), "X"))     # brim, tipped down
    b.cyl((0, -0.93, 0.62), 0.3, 0.1, "cream", segments=14, rot=X)                           # badge
    b.sphere((0, -0.99, 0.62), 0.19, "dark_wood", segments=10, rings=6, scale=(0.75, 0.4, 1.0))   # coffee bean
    b.box((0, -1.06, 0.62), (0.04, 0.02, 0.26), "cream", bevel=False)                       # its crease
    return _fin(b, "Style", mat)


def lawn(mat):
    b = Builder()
    b.cyl_base((0, 0, 0), 1.3, 0.4, "leaf_green", segments=22, radius2=1.15)                 # grass mound
    b.cyl_base((0, 0, -0.12), 1.32, 0.14, "dark_wood", segments=22)                          # soil edge
    b.box_base((0, 0.1, 0.4), (0.34, 0.34, 0.9), "caramel_wood")                             # trunk
    for (x, y, z, r, sw) in ((0, 0.05, 1.75, 0.78, "leaf_green"), (-0.52, 0.1, 1.38, 0.55, "leaf_dark"),
                             (0.55, 0.1, 1.42, 0.55, "leaf_dark"), (0.05, -0.2, 2.25, 0.5, "leaf_green")):
        b.sphere((x, y, z), r, sw, segments=12, rings=8)
    for x, petal in ((-0.85, "blush"), (0.85, "pastel_butter")):                             # two flowers
        b.cyl_base((x, -0.75, 0.4), 0.04, 0.22, "leaf_dark", segments=6)
        b.sphere((x, -0.75, 0.66), 0.14, petal, segments=8, rings=6)
        b.sphere((x, -0.86, 0.66), 0.06, "pastel_butter" if petal == "blush" else "blush", segments=6, rings=4)
    b.sphere((0.45, -0.95, 1.95), 0.12, "rarity_mythic", segments=8, rings=6)               # an apple
    return _fin(b, "Lawn", mat)


def plants(mat):
    b = Builder()
    b.cyl_base((0, 0, 0), 0.62, 1.0, "terracotta", segments=18, radius2=0.82)                # pot
    b.cyl_base((0, 0, 0.92), 0.9, 0.22, "terracotta", segments=18)                           # rim
    b.cyl((0, 0, 1.1), 0.78, 0.06, "choco", segments=18)                                     # soil
    b.box((0, -0.86, 1.03), (1.2, 0.04, 0.08), "cream", bevel=False)                       # a stripe on the rim
    for ang, h, sw in ((-34, 1.5, "leaf_green"), (0, 1.9, "leaf_dark"), (34, 1.5, "leaf_green")):
        a = math.radians(ang)
        cx, cz = math.sin(a) * h * 0.5, 1.1 + math.cos(a) * h * 0.5
        b.sphere((cx, -0.05, cz), 0.42, sw, segments=12, rings=8, scale=(0.8, 0.45, h / 0.84),
                 rot=(-a, "Y"))
        b.box((cx * 0.9, -0.24, cz), (0.05, 0.03, h * 0.7), "leaf_dark" if sw == "leaf_green" else "leaf_green",
              bevel=False, rot=(-a, "Y"))                                                   # the leaf's vein
    return _fin(b, "Plants", mat)


def floor(mat):
    b = Builder()
    n, s = 3, 0.62
    b.box((0, 0, -0.16), (n * s + 0.36, n * s + 0.36, 0.28), "caramel_wood")               # wooden edge
    for i in range(n):
        for j in range(n):
            sw = "cream" if (i + j) % 2 == 0 else "choco"
            b.box(((i - 1) * s, (j - 1) * s, 0.02), (s - 0.03, s - 0.03, 0.12), sw, bevel=False)
    b.cyl((0, 0, 0.11), 0.16, 0.03, "blush", segments=10)                                    # a pink paw in the middle
    for dx, dy in ((-0.16, 0.17), (-0.05, 0.24), (0.06, 0.24), (0.17, 0.17)):
        b.cyl((dx, dy, 0.11), 0.06, 0.03, "blush", segments=8)
    return _fin(b, "Floor", mat)


def walls(mat):
    b = Builder()
    W, H = 2.3, 2.0
    b.box((0, 0.1, H / 2), (W, 0.2, H), "pastel_sky")                                        # wallpaper
    for k in range(5):                                                                     # its stripes
        b.box((-W / 2 + 0.23 + k * 0.46, -0.005, H / 2 + 0.08), (0.13, 0.03, H - 0.3), "offwhite", bevel=False)
    b.box((0, -0.04, 0.14), (W + 0.06, 0.2, 0.28), "dark_wood")                              # skirting
    b.box((0, -0.12, 1.12), (1.3, 0.14, 1.05), "gold_mid")                                   # frame
    b.box((0, -0.2, 1.12), (1.02, 0.04, 0.78), "cream", bevel=False)                       # the picture
    # a ginger cat face in the picture
    b.box((0, -0.235, 1.05), (0.5, 0.04, 0.4), "fur_orange", bevel=False)
    for sx in (-1, 1):
        b.prism((sx * 0.17, -0.235, 1.3), [(-0.09, 0.0), (0.09, 0.0), (0.0, 0.14)], 0.04, "fur_orange", rot=X)
        b.box((sx * 0.1, -0.26, 1.1), (0.07, 0.02, 0.09), "fur_black", bevel=False)
    b.box((0, -0.26, 0.98), (0.07, 0.02, 0.05), "blush", bevel=False)
    b.box((0, -0.2, 1.72), (0.06, 0.04, 0.12), "gold_dark", bevel=False)                    # the hook
    return _fin(b, "Walls", mat)


BUILDERS = {"All": all_tab, "Style": style, "Lawn": lawn, "Plants": plants, "Floor": floor, "Walls": walls}
# name -> (yaw, pitch) for icons.py
VIEWS = {"All": (-20.0, 12.0), "Style": (-18.0, 18.0), "Lawn": (-14.0, 10.0), "Plants": (-14.0, 10.0),
         "Floor": (-24.0, 48.0), "Walls": (-16.0, 6.0)}
