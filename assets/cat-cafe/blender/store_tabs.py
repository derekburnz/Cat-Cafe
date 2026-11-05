"""The Store's sidebar tab pictures (#1674, Derek2 11-05: "update these sidebar symbols in shop as they are too simple
and bad"), rendered by icons.py as CatCafe_Icon_StoreTab_<Tab> (transparent, outlined, 512 px) in place of the tabs'
emoji. They sit about 28 px tall on a white tab, so each is one chunky shape with a bright second colour:

  Featured  a fat gold star with a raised bright gold face, berry ribbon tails and two twinkles
  Passes    a golden ticket with notched ends, a cream panel with a berry paw and a dotted tear line
  Cats      a ginger tabby sitting up and facing you, a little pink heart by its ear
  Potions   the Big Money Potion with a Lucky Potion leaning behind it, and a twinkle
  Codes     a gold key with a round bow and teeth, a cream gift tag tied to its bow

Blender axes (x right, -y toward the camera, z up); nothing here is a game model.
"""

import math

import potion_icons
import store_icons
from common import Builder
from icon_compose import place

X = (math.radians(90), "X")


def _fin(b, name, mat):
    return [b.finalize("CatCafe_IconArt_StoreTab_" + name, mat)]


def _star_pts(outer, inner, n=5):
    pts = []
    for k in range(2 * n + 1):
        a = math.pi / 2 + math.pi * k / n
        r = outer if k % 2 == 0 else inner
        pts.append((r * math.cos(a), r * math.sin(a)))
    return pts


def featured(mat):
    b = Builder()
    for sx in (-1, 1):                                                                # ribbon tails behind it
        b.box((sx * 0.3, 0.25, -0.7), (0.42, 0.08, 1.1), "royal_berry", rot=(math.radians(sx * -16), "Y"))
    b.fan((0, 0.0, 0.1), (0, 0), _star_pts(1.45, 0.66), 0.5, "gold_mid", rot=X)      # the fat star
    b.fan((0, -0.3, 0.1), (0, 0), _star_pts(1.05, 0.48), 0.14, "rarity_legend", rot=X)  # its raised face
    b.box((-0.32, -0.4, 0.55), (0.34, 0.06, 0.1), "offwhite", bevel=False, rot=(math.radians(30), "Y"))  # shine
    store_icons._twinkle(b, 1.35, -0.4, 1.25, 0.6)
    store_icons._twinkle(b, -1.35, -0.4, 0.75, 0.38)
    return _fin(b, "Featured", mat)


def passes(mat):
    b = Builder()
    W, H, R = 2.9, 1.6, 0.26
    out = []                                                                          # outline with notched ends
    for x, y in ((W / 2, -H / 2), (W / 2, -R)):
        out.append((x, y))
    for k in range(1, 8):
        a = math.radians(-90 - 180 * k / 8)
        out.append((W / 2 + R * math.cos(a), R * math.sin(a)))
    out += [(W / 2, R), (W / 2, H / 2), (-W / 2, H / 2), (-W / 2, R)]
    for k in range(1, 8):
        a = math.radians(90 - 180 * k / 8)
        out.append((-W / 2 + R * math.cos(a), R * math.sin(a)))
    out += [(-W / 2, -R), (-W / 2, -H / 2), (W / 2, -H / 2)]
    tilt = (math.radians(90), "X")
    b.fan((0, 0, 0), (0, 0), out, 0.3, "gold_mid", rot=tilt)                         # the ticket
    b.box((-0.25, -0.17, 0), (1.75, 0.06, 1.15), "cream", bevel=False)                # its panel
    store_icons._paw(b, -0.25, -0.22, -0.05, 1.3, "royal_berry")
    for k in range(6):                                                                # the tear line
        b.box((0.95, -0.17, -0.6 + 0.24 * k), (0.07, 0.05, 0.12), "gold_dark", bevel=False)
    store_icons._star(b, 1.17, -0.18, 0.0, 0.2, "royal_berry")
    return [o for o in place(_fin(b, "Passes", mat), at=(0, 0, 0), roll=14)]


def cats_tab(mat):
    cat = place(store_icons._cat("Tabby", mat), at=(0.0, 0.0, 0.0))
    b = Builder()
    heart = []                                                                        # a little heart
    for k in range(25):
        t = 2 * math.pi * k / 24
        heart.append((0.024 * 16 * math.sin(t) ** 3,
                       0.024 * (13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))))
    b.fan((0.8, -0.5, 2.05), (0.0, -0.05), heart, 0.12, "fur_bubblegum", rot=X)
    return cat + _fin(b, "Cats", mat)


def potions(mat):
    back = place(potion_icons.flask("Lucky", mat), at=(0.7, 0.5, 0.1), scale=0.82, roll=-12)
    front = place(potion_icons.flask("BigTip", mat), at=(-0.45, -0.3, 0.0), scale=0.88, roll=6)
    b = Builder()
    store_icons._twinkle(b, -1.1, -0.6, 1.9, 0.5)
    return back + front + _fin(b, "Potions", mat)


def codes(mat):
    b = Builder()
    b.ring((-0.85, 0.0, 0.45), 0.6, 0.3, 0.3, "gold_mid", segments=20, rot=X)         # the key's bow
    b.cyl((-0.85, 0.0, 0.45), 0.2, 0.18, "gold_light", segments=12, rot=X)            # a jewel in it
    b.box((0.6, 0.0, 0.45), (1.9, 0.3, 0.34), "gold_mid")                             # shaft, from inside the bow
    for x, h in ((1.05, 0.42), (1.3, 0.3)):                                           # teeth
        b.box((x, 0.0, 0.45 - 0.13 - h / 2), (0.18, 0.24, h), "gold_mid")
    b.box((1.43, 0.0, 0.45), (0.1, 0.26, 0.4), "gold_dark")                           # the tip
    b.box((0.6, -0.16, 0.52), (0.9, 0.04, 0.07), "gold_light", bevel=False)           # a shine
    # a gift tag tied to the bow
    b.box((-1.18, -0.05, -0.15), (0.05, 0.05, 0.75), "royal_berry", bevel=False, rot=(math.radians(-22), "Y"))
    b.prism((-1.42, -0.1, -0.95), [(-0.38, -0.42), (0.38, -0.42), (0.38, 0.3), (0.0, 0.58), (-0.38, 0.3)], 0.1,
            "cream", rot=X)
    b.cyl((-1.42, -0.17, -0.55), 0.07, 0.06, "royal_berry", segments=8, rot=X)       # its eyelet
    store_icons._star(b, -1.42, -0.17, -1.05, 0.22, "royal_berry")
    return _fin(b, "Codes", mat)


BUILDERS = {"Featured": featured, "Passes": passes, "Cats": cats_tab, "Potions": potions, "Codes": codes}
# name -> (yaw, pitch) for icons.py
VIEWS = {"Featured": (-14.0, 10.0), "Passes": (-16.0, 12.0), "Cats": (-14.0, 8.0), "Potions": (-12.0, 8.0),
         "Codes": (-14.0, 14.0)}
