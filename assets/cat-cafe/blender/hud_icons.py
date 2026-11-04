"""HUD button pictures (#1176): chunky little Cozy Cream objects, one per button, rendered by icons.py as
CatCafe_Icon_Hud_<Name> (transparent, dark outline, 512 px) for UI-Engineer to put on the HUD tiles.

  Store     a treasure chest, gold bands and lock, coins peeking from under the lid
  Cats      a ginger cat face with the W mouth, pink ears and cheeks
  Index     an open book with a ribbon
  Quests    a clipboard with a green tick and two lines
  Upgrades  a green up arrow
  Decor     the pink cat-eared armchair and plant (icons.py's CatCafe_Icon_Decor builder)
  Rewards   a pink gift box with a gold ribbon and bow
  Tutorial  a round sky-blue badge with a cream question mark
  Feedback  a cream speech bubble with three dots
  Menu      a grey gear
  MyCafe    a little cafe house: cream walls, terracotta roof, door with a paw, window, chimney
  Cannon    a dark cannon with gold bands on a wooden carriage, a cannonball beside it
  Areas     a red map pin over a little green map
  Potions   a flask (potions.py's Swift Potion)
  Bait      the food bowl (items.py) with a heap of kibble

Each builder lays its object out in Blender axes (x right, -y toward the camera, z up) and returns its objects; nothing
here is a game model.
"""

import math

from common import Builder

X = (math.radians(90), "X")          # stands a prism up so its outline faces the camera (-Y)


def _fin(b, name, mat):
    return [b.finalize("CatCafe_IconArt_Hud_" + name, mat)]


def chest(mat):
    b = Builder()
    b.box((0, 0, 0.55), (2.0, 1.3, 1.1), "caramel_wood")                          # body
    b.cyl((0, 0, 1.1), 0.65, 2.0, "caramel_wood", segments=14, rot=(math.radians(90), "Y"))   # lid, the half above
    for x in (-0.62, 0.62):                                                        # gold bands over body and lid
        b.box((x, 0, 0.55), (0.2, 1.34, 1.12), "gold_mid")
        b.cyl((x, 0, 1.1), 0.67, 0.2, "gold_mid", segments=14, rot=(math.radians(90), "Y"))
    for x in (-1.02, 1.02):                                                        # gold caps on the lid's ends
        b.cyl((x, 0, 1.1), 0.66, 0.05, "gold_mid", segments=14, rot=(math.radians(90), "Y"))
    b.box((0, -0.66, 0.08), (2.04, 0.04, 0.16), "dark_wood")                      # foot rail
    b.box((0, -0.68, 0.95), (0.42, 0.06, 0.5), "gold_light")                      # lock plate
    b.cyl((0, -0.72, 0.95), 0.08, 0.04, "dark_wood", segments=8, rot=(math.radians(90), "X"))   # keyhole
    for k, (x, z) in enumerate(((-0.35, 1.14), (0.32, 1.16), (0.0, 1.2))):        # coins peeking at the front
        b.cyl((x, -0.6, z), 0.17, 0.05, "rarity_legend", segments=10, rot=(math.radians(70 + 8 * k), "X"))
    return _fin(b, "Store", mat)


def cat_face(mat):
    b = Builder()
    b.box((0, 0, 0.9), (1.8, 1.2, 1.5), "fur_orange")                             # head
    b.box((0, -0.55, 0.62), (0.9, 0.2, 0.55), "fur_cream")                        # muzzle
    for sx in (-1, 1):
        b.pyramid((sx * 0.55, 0, 1.62), 0.62, 0.62, "fur_orange")                 # ears
        b.pyramid((sx * 0.55, -0.12, 1.64), 0.34, 0.42, "nose_pink")
        b.box((sx * 0.42, -0.61, 1.05), (0.34, 0.06, 0.42), "fur_black")          # eyes
        b.box((sx * 0.36, -0.645, 1.15), (0.12, 0.04, 0.12), "offwhite")          # shine
        b.box((sx * 0.7, -0.61, 0.72), (0.26, 0.04, 0.14), "blush")               # cheeks
        b.box((sx * 0.13, -0.67, 0.5), (0.2, 0.04, 0.06), "fur_black", rot=(math.radians(-sx * 30), "Y"))  # W mouth
    b.box((0, -0.67, 0.78), (0.24, 0.06, 0.16), "nose_pink")                      # nose
    b.box((0, -0.67, 0.6), (0.05, 0.04, 0.2), "fur_black")
    for sx in (-1, 1):
        for dz in (0.66, 0.56):                                                    # whiskers
            b.box((sx * 0.62, -0.66, dz), (0.34, 0.03, 0.03), "choco")
    return _fin(b, "Cats", mat)


def open_book(mat):
    b = Builder()
    for sx in (-1, 1):
        r = (math.radians(sx * -10), "Y")
        b.box((sx * 0.62, 0.05, 0.2), (1.28, 1.6, 0.14), "sign_teal", rot=r)      # cover
        b.box((sx * 0.6, 0.05, 0.31), (1.18, 1.5, 0.12), "offwhite", rot=r)        # pages
        for k in range(4):                                                         # text lines
            b.box((sx * 0.62, 0.45 - k * 0.3, 0.38 + 0.11 * (0.62 - abs(sx * 0.62)) + sx * 0.0),
                  (0.75, 0.07, 0.02), "pastel_sky", rot=r)
    b.box((0, 0.05, 0.25), (0.12, 1.6, 0.2), "dark_wood")                          # spine
    b.box((0.15, -0.82, 0.05), (0.14, 0.4, 0.04), "shirt_red", rot=(math.radians(-20), "X"))   # ribbon
    return _fin(b, "Index", mat)


def clipboard(mat):
    b = Builder()
    b.box((0, 0, 1.1), (1.5, 0.12, 2.0), "caramel_wood")                           # board
    b.box((0, -0.08, 1.02), (1.25, 0.04, 1.65), "offwhite")                        # paper
    b.box((0, -0.06, 2.02), (0.7, 0.16, 0.3), "metal")                             # clip
    b.cyl((0, -0.06, 2.2), 0.12, 0.16, "metal", segments=10, rot=(math.radians(90), "X"))
    b.box((-0.2, -0.13, 1.18), (0.34, 0.08, 0.16), "shirt_green", rot=(math.radians(45), "Y"))    # the tick
    b.box((0.17, -0.13, 1.32), (0.7, 0.08, 0.16), "shirt_green", rot=(math.radians(-50), "Y"))
    for z in (0.62, 0.42):
        b.box((0, -0.11, z), (0.9, 0.03, 0.08), "pastel_sky")
    return _fin(b, "Quests", mat)


def up_arrow(mat):
    b = Builder()
    b.box((0, 0, 0.75), (0.7, 0.45, 1.5), "shirt_green")                           # shaft
    b.prism((0, 0, 1.45), [(-0.85, 0.0), (0.85, 0.0), (0.0, 0.95)], 0.45, "shirt_green", rot=X)   # head
    b.box((0, -0.24, 0.75), (0.2, 0.04, 1.2), "mint")                              # shine
    return _fin(b, "Upgrades", mat)


def gift(mat):
    b = Builder()
    b.box((0, 0, 0.6), (1.5, 1.5, 1.2), "fur_bubblegum")                           # box
    b.box((0, 0, 1.28), (1.64, 1.64, 0.3), "blush")                                # lid
    b.box((0, 0, 0.75), (0.28, 1.68, 1.5), "rarity_legend")                        # ribbon both ways
    b.box((0, 0, 0.75), (1.68, 0.28, 1.5), "rarity_legend")
    for sx in (-1, 1):                                                             # bow loops
        b.ico((sx * 0.3, 0, 1.65), 0.3, "rarity_legend", scale=(1.2, 0.6, 0.8))
    b.ico((0, 0, 1.62), 0.16, "gold_mid")
    return _fin(b, "Rewards", mat)


def question(mat):
    b = Builder()
    b.cyl((0, 0, 1.1), 1.0, 0.3, "pastel_sky", segments=24, rot=X)                # badge
    b.ring((0, -0.02, 1.1), 1.06, 0.14, 0.34, "shirt_blue", segments=24, rot=X)   # rim
    for a in (165, 130, 95, 60, 25, -10, -45):                                     # the hook, over the top
        r = math.radians(a)
        b.box((0.3 * math.cos(r), -0.18, 1.38 + 0.3 * math.sin(r)), (0.22, 0.1, 0.22), "cream", rot=(-r, "Y"))
    b.box((0.08, -0.18, 1.06), (0.22, 0.1, 0.22), "cream")                          # into the stem
    b.box((0.0, -0.18, 0.9), (0.22, 0.1, 0.22), "cream")
    b.box((0.0, -0.18, 0.62), (0.2, 0.1, 0.2), "cream")                            # the dot
    return _fin(b, "Tutorial", mat)


def speech(mat):
    b = Builder()
    b.box((0, 0, 1.15), (2.0, 0.4, 1.3), "cream")                                  # bubble body
    for sx in (-1, 1):                                                             # rounded ends
        b.cyl((sx * 1.0, 0, 1.15), 0.65, 0.38, "cream", segments=16, rot=X)
    b.prism((-0.45, 0, 0.5), [(-0.3, 0.0), (0.35, 0.0), (-0.45, -0.5)], 0.4, "cream", rot=X)   # tail
    for x in (-0.55, 0.0, 0.55):
        b.cyl((x, -0.22, 1.15), 0.17, 0.06, "sign_teal", segments=12, rot=X)       # dots
    return _fin(b, "Feedback", mat)


def gear(mat):
    b = Builder()
    b.cyl((0, 0, 1.1), 0.8, 0.4, "concrete", segments=20, rot=X)                   # wheel
    for k in range(8):                                                             # teeth
        a = math.radians(k * 45)
        b.box((0.95 * math.sin(a), 0, 1.1 + 0.95 * math.cos(a)), (0.34, 0.4, 0.34), "concrete", rot=(a, "Y"))
    b.cyl((0, -0.21, 1.1), 0.34, 0.04, "concrete_dark", segments=16, rot=X)        # hub
    b.cyl((0, -0.24, 1.1), 0.16, 0.04, "metal", segments=12, rot=X)
    return _fin(b, "Menu", mat)


def house(mat):
    b = Builder()
    b.box((0, 0, 0.6), (1.8, 1.4, 1.2), "cream")                                   # walls
    for sx in (-1, 1):                                                             # roof slopes
        b.box((sx * 0.43, 0, 1.6), (1.3, 1.6, 0.2), "terracotta", rot=(math.radians(sx * 34.6), "Y"))
    b.prism((0, 0, 1.18), [(-0.9, 0.0), (0.9, 0.0), (0.0, 0.62)], 1.38, "cream", rot=X)   # the gable
    b.box((0.55, 0.2, 1.75), (0.28, 0.28, 0.5), "brick")                           # chimney
    b.box((-0.35, -0.71, 0.42), (0.5, 0.04, 0.8), "dark_wood")                    # door
    b.cyl((-0.35, -0.735, 0.5), 0.11, 0.02, "blush", segments=8, rot=X)            # paw on it
    b.box((0.45, -0.71, 0.7), (0.5, 0.04, 0.42), "pastel_sky")                    # window
    b.box((0.45, -0.72, 0.7), (0.54, 0.02, 0.06), "offwhite")
    b.box((0, -0.72, 0.02), (1.84, 0.04, 0.08), "mint")                           # step trim
    return _fin(b, "MyCafe", mat)


def cannon(mat):
    b = Builder()
    tilt = (math.radians(-55), "Y")                                                 # the barrel aims up and left
    b.cyl((0.1, 0, 0.95), 0.36, 1.9, "fur_charcoal", segments=14, rot=tilt, radius2=0.28)
    ax, az = math.sin(math.radians(-55)), math.cos(math.radians(-55))              # the barrel's axis
    for t, r in ((-0.6, 0.38), (0.0, 0.34), (0.62, 0.3)):                          # gold bands along it
        b.cyl((0.1 + t * ax, 0, 0.95 + t * az), r, 0.12, "gold_mid", segments=14, rot=tilt)
    b.box((-0.05, 0, 0.42), (1.3, 0.8, 0.4), "caramel_wood")                       # carriage
    for sy in (-1, 1):                                                             # wheels
        b.cyl((-0.1, sy * 0.48, 0.32), 0.34, 0.14, "dark_wood", segments=14, rot=(math.radians(90), "X"))
        b.cyl((-0.1, sy * 0.56, 0.32), 0.1, 0.04, "gold_mid", segments=8, rot=(math.radians(90), "X"))
    b.ico((0.95, -0.25, 0.22), 0.22, "fur_black")                                  # a cannonball
    return _fin(b, "Cannon", mat)


def map_pin(mat):
    b = Builder()
    b.box((0, 0.2, 0.05), (1.9, 1.4, 0.1), "leaf_green", rot=(math.radians(6), "Z"))   # a little map
    b.box((-0.35, 0.2, 0.11), (0.18, 1.3, 0.02), "pastel_sky", rot=(math.radians(18), "Z"))   # a river
    b.ico((0, 0, 1.45), 0.6, "shirt_red")                                          # the pin head
    b.cyl((0, 0, 0.8), 0.42, 0.9, "shirt_red", segments=14, radius2=0.02)          # its point
    b.cyl((0, -0.4, 1.5), 0.22, 0.2, "offwhite", segments=12, rot=X)               # the dot
    return _fin(b, "Areas", mat)


def bait(mat):
    """The food bowl (items.py) with a heap of kibble on it."""
    import items
    b = Builder()
    items._bowl(b, "bowl_red", "gold_mid", "kibble", premium=True)
    for k in range(9):                                                             # the heap
        a = k * 2.4
        r = 0.08 + 0.03 * (k % 4)
        b.ico((r * math.cos(a), r * math.sin(a), 0.22 + 0.05 * (k % 3)), 0.09 - 0.004 * k, "kibble")
    b.ico((0.0, 0.0, 0.36), 0.08, "treat_tan")
    return _fin(b, "Bait", mat)


def builders():
    """Picture name -> builder, for icons.py."""
    import icons      # noqa: F401  (icons imports this module; the Decor builder lives there)
    import potions
    return {
        "Store": chest, "Cats": cat_face, "Index": open_book, "Quests": clipboard, "Upgrades": up_arrow,
        "Decor": icons._hud_decor, "Rewards": gift, "Tutorial": question, "Feedback": speech, "Menu": gear,
        "MyCafe": house, "Cannon": cannon, "Areas": map_pin,
        "Potions": lambda m: potions.build_potion("Swift", m),
        "Bait": bait,
    }
