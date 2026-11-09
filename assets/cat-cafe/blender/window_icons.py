"""#2836 (Derek2 2026-11-09: "make sure all our buttons/icons are high quality"): pictures for every window badge, row and
button that still drew an emoji (UI-Engineer's audit on #2836), in the HUD tiles' chunky Cozy Cream style. icons.py
renders each as CatCafe_Icon_Hud_<Name> (512 px, transparent, dark outline) like the HUD buttons (hud_icons.py).

  Window corner badges
    MysteryMarket  a crystal ball with a gold question mark glowing inside, on a gold stand and a violet cushion
    Codes          a golden ticket with notched ends and a pink paw
    Collector      a magnifying glass over a little gold star
    CornerShop     a little shop front: cream walls, a red and white striped awning, a window with goods, a door
    LawnStall      a terracotta pot of three tulips
    RankUp         a gold trophy cup with handles on a dark base, a star on the cup
    Bellhop        a gold service bell on a wooden base, its press button on top
    YardSale       an open cardboard box of odds and ends with a price tag on a string
  Mystery Market perks (one picture per perk id)
    BigBackpack    the Backpack perk: the Bag tile's cat-ear backpack stuffed full, a fish and a yarn ball poking out
    LongNet        the Long Net perk: a catching net on an extra long pole, laid diagonally, with a green plus
  Upgrade rows
    Tables         a round cafe table with a pink cloth and a cup on it
    Espresso       a red espresso machine with a cup under the spout and steam
    LuckyCat       a gold lucky cat waving one paw, a red collar with a bell
  Staff roles (Upgrades staff rows, Cat Room, cat card, intro)
    RoleBarista    a latte cup with a heart on the foam
    RoleWaiter     a silver tray carrying a slice of cake
    RoleGreeter    a waving paw
    RoleEntertainer  a microphone on a short stand with a pink spotlight star
  Buttons and chips
    Drop           a chunky orange arrow pointing down onto a soft landing pad
    Replay         a round sky-blue arrow curling back on itself with a play triangle in the middle
    Tag            a rainbow name tag on a string (the Mythical tag prize)
    Plate          a plate with a fish biscuit and a fork (a food without its own picture)
  Settings rows (pass 2; Income reuses CatCafe_Icon_Coins, "Tutorial and tips" CatCafe_Icon_Hud_Tutorial)
    SetMusic       two beamed violet music notes          SetMusicVolume  blue headphones with pink cushions
    SetSound       a gold bell ringing                     SetSoundVolume  a blue speaker with three sound arcs
    SetShake       a phone with a paw on its screen, shake lines either side
    SetGraphics    a little green turtle ("Lighter graphics", for slower devices)
    SetOtherCats   two cat heads, grey and orange          SetMapIcons     a red map pin on a folded map
    SetAlerts      a megaphone with sound arcs             SetRecap        a clipboard with ticked rows
    SetAutoEquip   a big gold sparkle and a green tick badge

Each builder lays its object out in Blender axes (x right, -y toward the camera, z up) and returns its objects.
"""

import math

from mathutils import Matrix, Vector

from common import Builder

X = (math.radians(90), "X")          # stands a prism or cylinder up so its face looks at the camera (-Y)


def _fin(b, name, mat):
    return [b.finalize("CatCafe_IconArt_Hud_" + name, mat)]


def _rot(axis_deg):
    """Matrix from (x, y, z) degrees, applied x then y then z."""
    x, y, z = (math.radians(a) for a in axis_deg)
    return Matrix.Rotation(z, 3, "Z") @ Matrix.Rotation(y, 3, "Y") @ Matrix.Rotation(x, 3, "X")


def _bar(b, a, c, w, t, sw, up=(0, -1, 0)):
    """A flat strip from a to c, w wide, t thick along `up` (toward the camera by default)."""
    a, c = Vector(a), Vector(c)
    d = c - a
    y = d.normalized()
    z = Vector(up)
    z = (z - y * z.dot(y)).normalized()
    x = y.cross(z)
    R = Matrix((x, y, z)).transposed()
    b.box(tuple((a + c) / 2), (w, d.length, t), sw, rot=R)


def _paw(b, c, k, sw, y=None):
    """A paw print facing the camera at c: a pad and four toes."""
    x, yy, z = c
    yy = yy if y is None else y
    b.cyl((x, yy, z), 0.15 * k, 0.03, sw, segments=12, rot=X)
    for dx, dz in ((-0.17, 0.2), (-0.06, 0.28), (0.06, 0.28), (0.17, 0.2)):
        b.cyl((x + dx * k, yy, z + dz * k), 0.055 * k, 0.03, sw, segments=8, rot=X)


def _star_front(b, c, r, sw, depth=0.08):
    b.star(c, r, r * 0.45, depth, sw, rot=X)


# ----------------------------------------------------------------------------------------- window badges --

def mystery_market(mat):
    b = Builder()
    b.cyl((0, 0, 0.2), 0.9, 0.4, "aurora_violet", segments=8)                       # the cushion
    for (x, y) in ((-0.9, 0), (0.9, 0), (0, -0.9), (0, 0.9)):                        # its tassels
        b.ico((x * 0.95, y * 0.95 - 0.02, 0.06), 0.1, "rarity_legend")
    b.cyl((0, 0, 0.5), 0.55, 0.22, "gold_mid", segments=16, radius2=0.42)           # the gold stand
    b.ring((0, 0, 0.62), 0.5, 0.08, 0.1, "gold_light", segments=16)
    b.sphere((0, 0, 1.38), 0.82, "pastel_lilac", segments=18, rings=12)              # the ball
    b.sphere((-0.28, -0.52, 1.72), 0.18, "milk", segments=10, rings=6, scale=(1.0, 0.4, 1.3))   # its shine
    # the question mark glowing inside, a chunky hook over a stem and a dot, in front of the ball's middle
    y = -0.88
    for a in (170, 135, 100, 65, 30, -5, -40):
        r = math.radians(a)
        b.box((0.24 * math.cos(r), y, 1.55 + 0.24 * math.sin(r)), (0.17, 0.1, 0.17), "rarity_legend", rot=(-r, "Y"))
    b.box((0.06, y + 0.02, 1.24), (0.17, 0.1, 0.2), "rarity_legend")
    b.box((0.0, y + 0.04, 0.98), (0.17, 0.1, 0.15), "rarity_legend")
    for (x, z, r) in ((0.62, 2.1, 0.17), (-0.7, 2.02, 0.12), (0.78, 1.0, 0.1)):     # sparkles round it
        _star_front(b, (x, -0.2, z), r, "rarity_legend", 0.06)
    return _fin(b, "MysteryMarket", mat)


def codes(mat):
    b = Builder()
    R = _rot((0, -12, 0))
    w, h = 2.2, 1.2
    b.box((0, 0, 0.9), (w, 0.16, h), "rarity_legend", rot=R)                        # the ticket
    b.box((0, -0.09, 0.9), (w - 0.32, 0.04, h - 0.3), "pastel_butter", rot=R)       # its panel
    for sx in (-1, 1):                                                               # notches: dark bites at the ends
        c = R @ Vector((sx * w / 2, -0.0, 0.0)) + Vector((0, 0, 0.9))
        b.cyl(tuple(c), 0.2, 0.2, "fur_orange_dark", segments=10, rot=X)
    for k in range(5):                                                               # perforation by the stub
        c = R @ Vector((0.55, -0.12, -0.4 + 0.2 * k)) + Vector((0, 0, 0.9))
        b.box(tuple(c), (0.05, 0.03, 0.08), "fur_orange_dark", rot=R)
    _paw(b, tuple(R @ Vector((-0.25, 0, -0.08)) + Vector((0, 0, 0.9))), 1.05, "nose_pink", y=-0.13)
    _star_front(b, tuple(R @ Vector((0.82, 0, 0.0)) + Vector((0, -0.13, 0.9))), 0.15, "fur_orange_dark", 0.04)
    return _fin(b, "Codes", mat)


def collector(mat):
    b = Builder()
    _star_front(b, (0.15, 0.3, 1.25), 0.55, "rarity_legend", 0.18)                  # the find behind the lens
    c = Vector((0.05, -0.15, 1.3))
    b.ring(tuple(c), 0.72, 0.16, 0.2, "dark_wood", segments=20, rot=X)              # the rim
    b.cyl(tuple(c + Vector((0, 0.02, 0))), 0.6, 0.04, "pastel_sky", segments=20, rot=X)   # the lens
    b.box(tuple(c + Vector((-0.22, -0.06, 0.24))), (0.16, 0.03, 0.3), "milk", rot=(math.radians(-35), "Y"))
    a, e = c + Vector((0.52, 0, -0.52)), c + Vector((1.15, 0, -1.15))
    _bar(b, tuple(a), tuple(e), 0.28, 0.24, "caramel_wood")                          # the handle
    _bar(b, tuple(a - (e - a) * 0.08), tuple(a + (e - a) * 0.12), 0.34, 0.28, "gold_mid")   # its collar
    return _fin(b, "Collector", mat)


def corner_shop(mat):
    b = Builder()
    b.box((0, 0, 0.8), (2.0, 1.2, 1.6), "cream")                                    # walls
    b.box((0, 0, 1.72), (2.16, 1.3, 0.24), "terracotta")                            # roof edge
    b.box((0, 0, 1.92), (1.2, 0.8, 0.2), "terracotta")                              # sign board base
    b.box((0, -0.42, 2.02), (1.0, 0.06, 0.34), "pastel_butter")                     # the sign
    _paw(b, (0, -0.46, 1.96), 0.7, "terracotta")
    n = 6                                                                            # the striped awning
    for i in range(n):
        x = -1.05 + 2.1 * (i + 0.5) / n
        sw = ("shirt_red", "offwhite")[i % 2]
        b.box((x, -0.75, 1.42), (2.1 / n, 0.62, 0.08), sw, rot=(math.radians(-24), "X"))
        b.cyl((x, -1.03, 1.27), 2.1 / n / 2, 0.08, sw, segments=10, rot=X)          # scallops
    b.box((-0.45, -0.61, 0.62), (0.8, 0.04, 0.68), "pastel_sky")                     # window
    b.box((-0.45, -0.62, 0.62), (0.86, 0.02, 0.74), "dark_wood")
    for (x, sw) in ((-0.65, "rarity_legend"), (-0.42, "fur_strawberry"), (-0.2, "mint")):   # goods in it
        b.cyl((x, -0.66, 0.42), 0.08, 0.04, sw, segments=8, rot=X)
    b.box((0.55, -0.61, 0.5), (0.5, 0.04, 1.0), "caramel_wood")                      # door
    b.cyl((0.71, -0.65, 0.5), 0.05, 0.05, "gold_mid", segments=8, rot=X)
    b.box((0, -0.62, 0.04), (2.1, 0.06, 0.08), "dark_wood")                         # step
    return _fin(b, "CornerShop", mat)


def lawn_stall(mat):
    b = Builder()
    b.cyl((0, 0, 0.45), 0.62, 0.9, "terracotta", segments=14, radius2=0.78)        # the pot
    b.cyl((0, 0, 0.9), 0.84, 0.18, "terracotta", segments=14)                      # its rim
    b.cyl((0, 0, 0.98), 0.72, 0.04, "hair_brown", segments=14)                     # soil
    for (x, h, sw, lean) in ((-0.35, 1.0, "fur_strawberry", 12), (0.0, 1.3, "rarity_legend", 0),
                             (0.36, 0.95, "neon_pink", -12)):
        top = Vector((x + math.sin(math.radians(-lean)) * h * 0.3, 0, 1.0 + h))
        _bar(b, (x, 0, 1.0), tuple(top), 0.08, 0.08, "leaf_green")                    # stem
        for k in range(3):                                                           # the tulip: three petals
            a = math.radians(k * 120 + 30)
            b.sphere(tuple(top + Vector((0.09 * math.cos(a), 0.09 * math.sin(a), 0.12))), 0.17, sw,
                     segments=10, rings=6, scale=(0.8, 0.8, 1.25))
        b.cyl(tuple(top + Vector((0, 0, -0.02))), 0.1, 0.1, sw, segments=8)
    for sx in (-1, 1):                                                               # leaves
        _bar(b, (sx * 0.15, -0.1, 1.0), (sx * 0.55, -0.18, 1.6), 0.24, 0.06, "leaf_dark")
    return _fin(b, "LawnStall", mat)


def rank_up(mat):
    b = Builder()
    b.box((0, 0, 0.18), (1.3, 1.0, 0.36), "dark_wood")                              # base
    b.box((0, -0.51, 0.18), (0.8, 0.04, 0.16), "gold_light")                        # its plate
    b.cyl((0, 0, 0.5), 0.18, 0.3, "gold_mid", segments=12)                         # stem
    b.cyl((0, 0, 0.7), 0.4, 0.12, "gold_mid", segments=14, radius2=0.2)
    b.cyl((0, 0, 1.3), 0.5, 1.1, "gold_mid", segments=18, radius2=0.78)            # the cup
    b.ring((0, 0, 1.86), 0.8, 0.1, 0.1, "gold_light", segments=18)                 # its lip
    for sx in (-1, 1):                                                               # handles
        b.ring((sx * 0.82, 0, 1.4), 0.3, 0.1, 0.12, "gold_mid", segments=12, rot=X)
    _star_front(b, (0, -0.65, 1.35), 0.32, "rarity_legend", 0.08)
    b.box((-0.3, -0.62, 1.55), (0.1, 0.03, 0.4), "gold_light", rot=(math.radians(-20), "Y"))   # shine
    return _fin(b, "RankUp", mat)


def bellhop(mat):
    b = Builder()
    b.cyl((0, 0, 0.12), 1.05, 0.24, "caramel_wood", segments=20)                   # wooden base
    b.cyl((0, 0, 0.28), 0.95, 0.1, "gold_dark", segments=20)                       # the bell's foot
    b.sphere((0, 0, 0.32), 0.85, "gold_mid", segments=20, rings=10, scale=(1.0, 1.0, 0.85))   # the dome
    b.cyl((0, 0, 1.08), 0.08, 0.16, "gold_dark", segments=8)                       # the plunger
    b.cyl((0, 0, 1.2), 0.2, 0.1, "gold_light", segments=12)                        # its button
    b.sphere((-0.3, -0.5, 0.75), 0.16, "milk", segments=8, rings=5, scale=(0.6, 0.4, 1.2))   # shine
    return _fin(b, "Bellhop", mat)


def yard_sale(mat):
    b = Builder()
    b.box((0, 0, 0.5), (1.7, 1.2, 1.0), "cardboard")                               # the box
    for sx in (-1, 1):                                                               # open flaps
        b.box((sx * 1.0, 0, 1.12), (0.5, 1.2, 0.06), "cardboard", rot=(math.radians(sx * 30), "Y"))
    b.box((0, -0.61, 0.62), (1.0, 0.03, 0.08), "kibble")                            # tape
    b.ico((-0.45, 0.0, 1.15), 0.32, "fish_blue")                                     # a yarn ball
    b.ring((-0.45, -0.01, 1.15), 0.33, 0.04, 0.05, "pastel_sky", segments=12, rot=X)
    b.cyl((0.1, 0.1, 1.25), 0.22, 0.5, "pastel_butter", segments=10)               # a mug
    b.ring((0.34, 0.1, 1.28), 0.12, 0.05, 0.06, "pastel_butter", segments=8, rot=X)
    b.box((0.5, 0.15, 1.35), (0.18, 0.5, 0.8), "shirt_blue", rot=_rot((0, -12, 0)))  # a book
    b.cyl((0.55, -0.62, 0.55), 0.03, 0.03, "dark_wood", segments=6, rot=X)          # the tag's pin
    _bar(b, (0.55, -0.62, 0.55), (0.75, -0.66, 0.2), 0.03, 0.02, "dark_wood")       # its string
    b.box((0.85, -0.68, 0.05), (0.42, 0.04, 0.3), "rarity_legend", rot=(math.radians(-15), "Y"))   # price tag
    b.cyl((0.72, -0.71, 0.1), 0.04, 0.02, "dark_wood", segments=8, rot=X)
    return _fin(b, "YardSale", mat)


# ----------------------------------------------------------------------------------- Mystery Market perks --

def big_backpack(mat):
    import hud_icons
    b = Builder()
    hud_icons.draw_backpack(b, full=True)
    return _fin(b, "BigBackpack", mat)


def long_net(mat):
    """The Long Net perk: a chunky catching net with an extra long striped pole across the picture, a gold hoop with
    lilac netting, and a green plus by the hoop. Drawn big, not the thin game net, so it reads at 48 px."""
    b = Builder()
    grip, neck = Vector((-1.5, 0, 0.1)), Vector((0.55, 0, 1.45))
    _bar(b, tuple(grip), tuple(neck), 0.16, 0.16, "dark_wood")                      # the long pole
    d = neck - grip
    for f in (0.15, 0.38, 0.61, 0.84):                                              # gold stripes along it
        _bar(b, tuple(grip + d * (f - 0.02)), tuple(grip + d * (f + 0.02)), 0.2, 0.2, "gold_mid")
    _bar(b, tuple(grip), tuple(grip + d * 0.1), 0.22, 0.22, "shirt_red")            # the grip wrap
    c = neck + d.normalized() * 0.55
    R = _rot((70, 0, -34))
    b.ring(tuple(c), 0.62, 0.1, 0.12, "gold_mid", segments=18, rot=R)              # the hoop
    b.sphere(tuple(c + Vector((0.05, 0.05, -0.4))), 0.52, "pastel_lilac", segments=12, rings=7,
             scale=(1.0, 1.0, 0.95))                                                 # the net bag
    for k in range(5):                                                               # its mesh lines
        b.ring(tuple(c + Vector((0.05, 0.05, -0.15 - 0.13 * k))), 0.5 - 0.06 * k * k * 0.25, 0.025, 0.03,
               "offwhite", segments=12)
    p = c + Vector((0.55, -0.3, 0.75))
    b.box(tuple(p), (0.62, 0.22, 0.2), "shirt_green")                               # a green plus
    b.box(tuple(p), (0.2, 0.26, 0.62), "shirt_green")
    return _fin(b, "LongNet", mat)


# ------------------------------------------------------------------------------------------- upgrade rows --

def tables(mat):
    b = Builder()
    b.cyl((0, 0, 0.06), 0.55, 0.12, "dark_wood", segments=14)                       # foot
    b.cyl((0, 0, 0.6), 0.1, 1.0, "dark_wood", segments=10)                          # leg
    b.cyl((0, 0, 1.12), 1.1, 0.1, "caramel_wood", segments=20)                      # top
    b.cyl((0, 0, 1.08), 1.18, 0.24, "fur_strawberry", segments=20, radius2=1.24)    # cloth
    b.cyl((0, 0, 1.2), 1.12, 0.04, "offwhite", segments=20)                         # its top
    b.cyl((0.2, 0.0, 1.245), 0.42, 0.05, "pastel_sky", segments=14)                # saucer
    b.cyl((0.2, 0.0, 1.45), 0.26, 0.36, "shirt_blue", segments=14, radius2=0.22)    # cup
    b.cyl((0.2, 0.0, 1.62), 0.22, 0.03, "choco", segments=14)
    b.ring((0.5, 0.0, 1.45), 0.12, 0.05, 0.06, "shirt_blue", segments=8, rot=X)
    b.ico((-0.45, -0.25, 1.32), 0.16, "fur_strawberry")                              # a cupcake on it
    b.cyl((-0.45, -0.25, 1.24), 0.15, 0.12, "treat_tan", segments=10, radius2=0.12)
    return _fin(b, "Tables", mat)


def espresso(mat):
    b = Builder()
    b.box((0, 0, 0.12), (1.7, 1.2, 0.24), "metal")                                 # drip tray
    b.box((0, 0.25, 1.05), (1.6, 0.7, 1.7), "shirt_red")                            # body
    b.box((0, 0.25, 1.95), (1.7, 0.8, 0.12), "metal")                               # top
    b.box((0, -0.11, 1.45), (1.2, 0.04, 0.32), "metal")                             # front panel
    for x in (-0.3, 0.3):
        b.cyl((x, -0.15, 1.45), 0.09, 0.06, "rarity_legend", segments=8, rot=X)    # dials
    b.box((0, -0.25, 1.08), (0.5, 0.36, 0.14), "metal")                             # group head
    b.cyl((0, -0.25, 0.96), 0.14, 0.12, "fur_black", segments=10)                  # spout
    b.cyl((0, -0.3, 0.42), 0.28, 0.36, "milk", segments=14, radius2=0.24)          # cup under it
    b.ring((0.3, -0.3, 0.44), 0.11, 0.05, 0.06, "milk", segments=8, rot=X)
    b.cyl((0, -0.3, 0.6), 0.25, 0.02, "choco", segments=14)
    for k, x in enumerate((-0.12, 0.12)):                                           # steam
        for j in range(3):
            b.ico((x + 0.06 * (j % 2 * 2 - 1), -0.3, 2.25 + 0.2 * j + 0.05 * k), 0.09 - 0.015 * j, "milk")
    return _fin(b, "Espresso", mat)


def lucky_cat(mat):
    b = Builder()
    b.box((0, 0, 0.55), (1.3, 1.0, 1.1), "gold_mid")                                # body
    b.box((0, 0, 1.55), (1.5, 1.1, 1.0), "gold_mid")                                # head
    for sx in (-1, 1):
        b.pyramid((sx * 0.48, 0, 2.05), 0.45, 0.4, "gold_mid")                      # ears
        b.pyramid((sx * 0.48, -0.1, 2.06), 0.24, 0.26, "nose_pink")
        b.box((sx * 0.33, -0.56, 1.65), (0.26, 0.04, 0.08), "fur_black")           # happy closed eyes
        b.box((sx * 0.55, -0.56, 1.42), (0.2, 0.03, 0.1), "blush")                  # cheeks
        b.box((sx * 0.1, -0.57, 1.33), (0.15, 0.03, 0.05), "fur_black", rot=(math.radians(-sx * 30), "Y"))
    b.box((0, -0.57, 1.47), (0.16, 0.04, 0.1), "nose_pink")
    b.box((0, -0.51, 0.98), (1.3, 0.04, 0.14), "shirt_red")                         # collar
    b.ico((0, -0.58, 0.88), 0.14, "rarity_legend")                                   # bell
    b.box((0.85, -0.1, 1.75), (0.36, 0.4, 0.8), "gold_mid", rot=_rot((0, -15, 0)))   # the waving paw
    b.box((-0.45, -0.52, 0.5), (0.38, 0.1, 0.5), "gold_light")                      # front paw
    b.cyl((0.0, -0.53, 0.5), 0.26, 0.06, "rarity_legend", segments=12, rot=X)       # a coin it holds
    return _fin(b, "LuckyCat", mat)


# -------------------------------------------------------------------------------------------- staff roles --

def role_barista(mat):
    b = Builder()
    b.cyl((0, 0, 0.06), 0.95, 0.12, "milk", segments=18)                           # saucer
    b.cyl((0, 0, 0.6), 0.62, 0.96, "milk", segments=18, radius2=0.78)              # cup
    b.cyl((0, 0, 1.1), 0.72, 0.04, "caramel_wood", segments=18)                    # the latte, on top of the cup
    b.ring((0.86, 0, 0.62), 0.24, 0.1, 0.12, "milk", segments=10, rot=X)           # handle
    for sx in (-1, 1):                                                               # a foam heart, from above
        b.cyl((sx * 0.13, -0.04, 1.13), 0.16, 0.03, "offwhite", segments=12)
    b.box((0, -0.17, 1.135), (0.27, 0.27, 0.03), "offwhite", rot=(math.radians(45), "Z"))
    return _fin(b, "RoleBarista", mat)


def role_waiter(mat):
    b = Builder()
    b.cyl((0.3, 0.1, 0.6), 0.12, 0.7, "metal", segments=10, radius2=0.05)           # the tray's stand
    b.cyl((0.3, 0.1, 0.95), 1.1, 0.08, "metal", segments=20)                       # the tray
    b.ring((0.3, 0.1, 1.0), 1.1, 0.08, 0.08, "concrete", segments=20)
    c = Vector((0.3, 0.1, 1.04))                                                    # a slice of cake: a wedge
    pts = [(0.0, 0.0), (0.9, -0.3), (0.9, 0.3)]
    b.prism(tuple(c + Vector((-0.4, 0, 0.0))), pts, 0.3, "fur_custard")
    b.prism(tuple(c + Vector((-0.4, 0, 0.3))), pts, 0.1, "fur_strawberry")
    b.prism(tuple(c + Vector((-0.4, 0, 0.13))), pts, 0.06, "fur_strawberry")
    b.ico(tuple(c + Vector((0.3, 0.0, 0.48))), 0.13, "bowl_red")                     # a cherry
    return _fin(b, "RoleWaiter", mat)


def role_greeter(mat):
    b = Builder()
    R = _rot((0, -15, 0))
    o = Vector((0, 0, 1.0))
    b.sphere(tuple(o), 0.62, "fur_ginger", segments=16, rings=10, scale=(1.0, 0.6, 0.9), rot=R)   # the paw, held up
    b.cyl(tuple(o + R @ Vector((0, 0, -0.75))), 0.38, 0.8, "fur_ginger", segments=12, rot=R)      # the arm
    for k, dx in enumerate((-0.42, -0.15, 0.15, 0.42)):                             # four toes on top
        b.sphere(tuple(o + R @ Vector((dx, 0, 0.5 + 0.06 * (k in (1, 2))))), 0.2, "fur_ginger", segments=10,
                 rings=6, scale=(1.0, 0.75, 1.0), rot=R)
        b.sphere(tuple(o + R @ Vector((dx, -0.15, 0.5 + 0.06 * (k in (1, 2))))), 0.1, "nose_pink", segments=8,
                 rings=5, scale=(1.0, 0.4, 1.0), rot=R)                              # toe beans
    b.sphere(tuple(o + R @ Vector((0, -0.36, -0.05))), 0.28, "nose_pink", segments=12, rings=6,
             scale=(1.15, 0.35, 0.9), rot=R)                                         # big pad
    for k, (x, z) in enumerate(((-0.95, 1.4), (-1.1, 0.95), (0.95, 1.45))):         # wave lines
        _bar(b, (x, 0, z), (x + (0.2 if x > 0 else -0.2), 0, z + 0.25), 0.1, 0.1, "rarity_legend")
    return _fin(b, "RoleGreeter", mat)


def role_entertainer(mat):
    b = Builder()
    b.cyl((0, 0, 0.06), 0.55, 0.12, "fur_black", segments=14)                      # stand foot
    b.cyl((0, 0, 0.6), 0.06, 1.0, "metal", segments=8)                             # stand pole
    R = _rot((0, -25, 0))
    top = Vector((0.15, 0, 1.2))
    _bar(b, (0, 0, 1.08), tuple(top), 0.12, 0.12, "metal")
    h = top + R @ Vector((0, 0, 0.35))
    b.cyl(tuple(h), 0.13, 0.55, "fur_black", segments=10, rot=R, radius2=0.18)     # handle
    b.sphere(tuple(top + R @ Vector((0, 0, 0.8))), 0.32, "concrete", segments=12, rings=8)   # the grille
    b.ring(tuple(top + R @ Vector((0, 0, 0.66))), 0.25, 0.06, 0.08, "neon_pink", segments=12, rot=R)
    _star_front(b, (-0.75, -0.1, 1.9), 0.3, "neon_pink", 0.08)
    _star_front(b, (0.95, -0.1, 0.8), 0.18, "rarity_legend", 0.06)
    return _fin(b, "RoleEntertainer", mat)


# -------------------------------------------------------------------------------------- buttons and chips --

def drop(mat):
    b = Builder()
    b.cyl((0, 0, 0.08), 0.95, 0.16, "pastel_sky", segments=20)                      # landing pad
    b.ring((0, 0, 0.1), 0.95, 0.12, 0.18, "shirt_blue", segments=20)
    b.box((0, 0, 1.75), (0.7, 0.45, 1.2), "fur_orange")                             # shaft
    b.prism((0, 0, 1.15), [(-0.85, 0.0), (0.85, 0.0), (0.0, -0.9)], 0.45, "fur_orange", rot=X)   # head, down
    b.box((0, -0.24, 1.8), (0.2, 0.04, 0.9), "pastel_butter")                       # shine
    return _fin(b, "Drop", mat)


def replay(mat):
    b = Builder()
    c = (0, 0, 1.1)
    for k in range(13):                                                              # the curling arrow
        a = math.radians(60 + k * 22)
        b.box((0.8 * math.cos(a), 0, 1.1 + 0.8 * math.sin(a)), (0.3, 0.3, 0.26), "pastel_sky",
              rot=(-a, "Y"))
    a = math.radians(60)
    tip = Vector((0.8 * math.cos(a), 0, 1.1 + 0.8 * math.sin(a)))
    b.prism(tuple(tip + Vector((0.05, 0, 0.0))), [(-0.35, 0.0), (0.35, 0.0), (0.0, 0.42)], 0.3, "shirt_blue",
            rot=_rot((90, -150, 0)))
    b.prism(c, [(-0.2, -0.3), (-0.2, 0.3), (0.32, 0.0)], 0.2, "shirt_blue", rot=X)     # play triangle
    return _fin(b, "Replay", mat)


def tag(mat):
    b = Builder()
    R = _rot((0, -18, 0))
    o = Vector((0, 0, 1.0))
    b.box(tuple(o), (1.6, 0.14, 1.0), "milk", rot=R)                                # the tag
    for k, sw in enumerate(("bowl_red", "fur_orange", "rarity_legend", "shirt_green", "fish_blue", "aurora_violet")):
        b.box(tuple(o + R @ Vector((-0.12 + 0.1 * 0, -0.08, 0.36 - 0.13 * k))), (1.2, 0.03, 0.13), sw, rot=R)
    b.prism(tuple(o + R @ Vector((-0.8, 0, 0))), [(0.0, -0.5), (0.0, 0.5), (-0.4, 0.0)], 0.14, "milk",
            rot=R @ _rot((90, 0, 0)))                                                   # the pointed end
    eye = o + R @ Vector((-0.95, -0.08, 0))
    b.ring(tuple(eye), 0.1, 0.04, 0.06, "gold_mid", segments=10, rot=X)
    _bar(b, tuple(eye), tuple(eye + Vector((-0.4, 0, 0.7))), 0.05, 0.05, "pastel_lilac")   # string
    return _fin(b, "Tag", mat)


def plate(mat):
    b = Builder()
    b.cyl((0, 0, 0.06), 1.1, 0.12, "milk", segments=22, radius2=1.2)               # plate
    b.ring((0, 0, 0.12), 1.0, 0.12, 0.06, "pastel_sky", segments=22)                # its rim band
    b.box((-0.1, 0, 0.3), (0.8, 0.5, 0.26), "treat_tan")                             # a fish biscuit
    b.prism((0.42, 0, 0.17), [(0.0, 0.0), (0.3, 0.25), (0.3, -0.25)], 0.26, "treat_tan")
    b.box((-0.32, -0.26, 0.32), (0.08, 0.03, 0.08), "choco")                         # its eye
    _bar(b, (-0.95, -0.4, 0.2), (0.7, -0.9, 0.2), 0.12, 0.06, "metal", up=(0, 0, 1))   # fork
    return _fin(b, "Plate", mat)


# ------------------------------------------------------------------------------- #2836 pass 2: Settings rows --
# Settings draws its row icons through IconArt (Components/SettingsList.luau). Income reuses CatCafe_Icon_Coins and
# "Tutorial and tips" CatCafe_Icon_Hud_Tutorial; these are the rest.

def _arcs(b, c, n, sw, r0=0.35, step=0.28, span=70, t=0.14):
    """n sound arcs to the right of c, facing the camera."""
    for i in range(n):
        r = r0 + step * i
        for a in range(-span // 2, span // 2 + 1, 14):
            ra = math.radians(a)
            b.box((c[0] + r * math.cos(ra), c[1], c[2] + r * math.sin(ra)),
                  (t, 0.12, r * math.radians(14) * 1.2 + 0.02), sw, rot=(-ra, "Y"))   # overlapping: one solid arc


def set_music(mat):
    b = Builder()
    R = _rot((0, -10, 0))
    for x in (-0.55, 0.55):                                                          # two notes, heads low
        h = Vector((x, 0, 0.55 if x < 0 else 0.75))
        b.sphere(tuple(h), 0.36, "aurora_violet", segments=14, rings=8, scale=(1.25, 0.75, 0.95), rot=_rot((0, -25, 0)))
        b.box(tuple(h + Vector((0.34, 0, 0.75))), (0.14, 0.2, 1.5), "aurora_violet")
    b.box((0.0, 0, 2.1), (1.44, 0.22, 0.3), "aurora_violet", rot=_rot((0, -9, 0)))   # the beam
    b.box((0.0, 0, 1.78), (1.44, 0.22, 0.22), "aurora_violet", rot=_rot((0, -9, 0)))
    b.sphere((-0.68, -0.27, 0.66), 0.09, "milk", segments=8, rings=5, scale=(1.0, 0.4, 1.4))   # shines
    b.sphere((0.42, -0.27, 0.86), 0.09, "milk", segments=8, rings=5, scale=(1.0, 0.4, 1.4))
    _star_front(b, (-1.0, -0.1, 1.7), 0.2, "rarity_legend", 0.06)
    del R
    return _fin(b, "SetMusic", mat)


def set_music_volume(mat):
    b = Builder()
    for k in range(9):                                                               # the band over the top
        a = math.radians(180 - k * 22.5)
        b.box((0.82 * math.cos(a), 0, 1.0 + 0.82 * math.sin(a)), (0.3, 0.3, 0.24), "fish_blue", rot=(-a + math.pi / 2, "Y"))
    for sx in (-1, 1):
        b.cyl((sx * 0.92, 0, 0.75), 0.42, 0.34, "fish_blue", segments=16, rot=(math.radians(90), "Y"))   # cups
        b.cyl((sx * 0.7, 0, 0.75), 0.36, 0.14, "nose_pink", segments=14, rot=(math.radians(90), "Y"))    # cushions
        b.cyl((sx * 1.1, 0, 0.75), 0.2, 0.04, "milk", segments=12, rot=(math.radians(90), "Y"))
    _paw(b, (1.12, 0, 0.75), 0.75, "milk", y=-0.0)
    return _fin(b, "SetMusicVolume", mat)


def set_sound(mat):
    b = Builder()
    b.cyl((0, 0, 0.75), 0.82, 0.9, "rarity_legend", segments=18, radius2=0.5)        # the bell, flared
    b.sphere((0, 0, 1.2), 0.5, "rarity_legend", segments=16, rings=8, scale=(1.0, 1.0, 0.8))
    b.ring((0, 0, 0.32), 0.86, 0.12, 0.14, "gold_mid", segments=18)                 # its lip
    b.ico((0, 0, 0.12), 0.2, "gold_mid")                                             # the clapper
    b.ring((0, 0, 1.68), 0.14, 0.06, 0.1, "gold_mid", segments=10, rot=X)           # the loop on top
    b.sphere((-0.3, -0.62, 1.0), 0.1, "milk", segments=8, rings=5, scale=(1.0, 0.4, 1.8))
    for sx in (-1, 1):                                                               # little ring lines
        for k in range(2):
            a = sx * (0.95 + 0.3 * k)
            _bar(b, (a, 0, 1.2 + 0.15 * k), (a + sx * 0.25, 0, 1.45 + 0.2 * k), 0.12, 0.12, "fur_orange")
    return _fin(b, "SetSound", mat)


def set_sound_volume(mat):
    b = Builder()
    b.box((-0.85, 0, 1.0), (0.5, 0.5, 0.75), "shirt_blue")                          # the speaker's back box
    b.cyl((-0.35, 0, 1.0), 0.32, 0.55, "shirt_blue", segments=14, radius2=0.72, rot=(math.radians(90), "Y"))
    b.cyl((-0.06, 0, 1.0), 0.55, 0.06, "pastel_sky", segments=16, rot=(math.radians(90), "Y"))
    _arcs(b, (0.05, 0, 1.0), 3, "rarity_legend", r0=0.45, step=0.32)
    return _fin(b, "SetSoundVolume", mat)


def set_shake(mat):
    b = Builder()
    R = _rot((0, -14, 0))
    o = Vector((0, 0, 1.05))
    b.box(tuple(o), (1.0, 0.22, 1.8), "fur_charcoal", rot=R)                        # the phone
    b.box(tuple(o + R @ Vector((0, -0.12, 0.05))), (0.82, 0.04, 1.45), "pastel_sky", rot=R)   # its screen
    _paw(b, tuple(o + R @ Vector((0, 0, -0.05))), 1.2, "milk", y=-0.16)
    b.box(tuple(o + R @ Vector((0, -0.12, 0.8))), (0.26, 0.04, 0.06), "concrete", rot=R)
    for sx in (-1, 1):                                                               # shake lines both sides
        for k in range(2):
            x = sx * (0.85 + 0.28 * k)
            _bar(b, (x, 0, 0.6 + 0.2 * k), (x, 0, 1.5 - 0.2 * k), 0.13, 0.13, "fur_orange")
    return _fin(b, "SetShake", mat)


def set_graphics(mat):
    b = Builder()
    b.sphere((0, 0, 0.55), 0.95, "leaf_green", segments=16, rings=8, scale=(1.0, 0.9, 0.62))   # the shell
    b.ring((0, 0, 0.32), 0.97, 0.12, 0.14, "fur_moss", segments=18)
    for (x, z) in ((0, 1.08), (-0.45, 0.82), (0.45, 0.82), (-0.65, 0.55), (0.65, 0.55), (0, 0.72)):
        b.cyl((x, -0.5 if z < 1.0 else -0.25, z), 0.17, 0.08, "leaf_dark", segments=6,
              rot=_rot((90 - 40 * (1.08 - z), 0, 0)))
    b.sphere((-1.05, -0.2, 0.55), 0.36, "mint", segments=12, rings=7)         # the head
    for dx in (-0.12, 0.12):
        b.sphere((-1.15 + dx, -0.5, 0.65), 0.07, "fur_ink", segments=8, rings=5)
    for (x, y) in ((-0.6, -0.45), (0.6, -0.45), (-0.55, 0.45), (0.55, 0.45)):          # feet
        b.sphere((x, y, 0.15), 0.2, "mint", segments=10, rings=5, scale=(1.0, 1.0, 0.75))
    return _fin(b, "SetGraphics", mat)


def _cat_head(b, c, k, fur, inner):
    x, y, z = c
    b.box((x, y, z), (1.1 * k, 0.8 * k, 0.95 * k), fur)
    for sx in (-1, 1):
        b.prism((x + sx * 0.32 * k, y, z + 0.47 * k), [(-0.2 * k, 0.0), (0.2 * k, 0.0), (0.0, 0.34 * k)], 0.3 * k,
                fur, rot=X)
        b.prism((x + sx * 0.32 * k, y - 0.16 * k, z + 0.5 * k), [(-0.1 * k, 0.0), (0.1 * k, 0.0), (0.0, 0.18 * k)],
                0.04 * k, inner, rot=X)
        b.box((x + sx * 0.22 * k, y - 0.41 * k, z + 0.05 * k), (0.14 * k, 0.03, 0.2 * k), "fur_ink")
    b.box((x, y - 0.41 * k, z - 0.13 * k), (0.12 * k, 0.03, 0.08 * k), "nose_pink")


def set_other_cats(mat):
    b = Builder()
    _cat_head(b, (0.45, 0.3, 1.25), 1.0, "fur_grey", "nose_pink")
    _cat_head(b, (-0.4, -0.2, 0.85), 1.1, "fur_orange", "nose_pink")
    return _fin(b, "SetOtherCats", mat)


def set_map_icons(mat):
    b = Builder()
    for k, (x, sw) in enumerate(((-0.7, "mint"), (0.0, "pastel_butter"), (0.7, "mint"))):   # folded map
        b.box((x, 0, 0.1), (0.72, 1.5, 0.08), sw, rot=_rot((0, 8 if k % 2 else -8, 0)))
    _bar(b, (-0.9, -0.5, 0.18), (0.8, 0.3, 0.18), 0.08, 0.03, "fur_orange", up=(0, 0, 1))     # a path on it
    b.sphere((0.1, 0, 1.45), 0.55, "bowl_red", segments=16, rings=9)                 # the pin
    b.cyl((0.1, 0, 0.7), 0.3, 0.9, "bowl_red", segments=14, radius2=0.0)
    b.cyl((0.1, -0.42, 1.48), 0.22, 0.12, "milk", segments=14, rot=X)
    b.sphere((-0.15, -0.38, 1.7), 0.08, "milk", segments=8, rings=5, scale=(1.0, 0.5, 1.4))
    return _fin(b, "SetMapIcons", mat)


def set_alerts(mat):
    b = Builder()
    R = _rot((0, 20, 0))
    o = Vector((-0.3, 0, 1.0))
    b.cyl(tuple(o), 0.28, 1.2, "pastel_butter", segments=16, radius2=0.7, rot=R @ _rot((0, 90, 0)))   # the horn
    b.ring(tuple(o + R @ Vector((0.62, 0, 0))), 0.72, 0.1, 0.12, "bowl_red", segments=16, rot=R @ _rot((0, 90, 0)))
    b.box(tuple(o + R @ Vector((-0.7, 0, 0))), (0.3, 0.42, 0.42), "bowl_red", rot=R)          # its back
    _bar(b, tuple(o + Vector((-0.3, 0, -0.2))), tuple(o + Vector((-0.4, 0, -0.85))), 0.18, 0.18, "bowl_red")   # handle
    _arcs(b, tuple(o + R @ Vector((0.7, 0, 0))), 2, "fur_orange", r0=0.5, step=0.32)
    return _fin(b, "SetAlerts", mat)


def set_recap(mat):
    b = Builder()
    R = _rot((0, -8, 0))
    o = Vector((0, 0, 1.0))
    b.box(tuple(o), (1.5, 0.12, 2.0), "caramel_wood", rot=R)                        # the board
    b.box(tuple(o + R @ Vector((0, -0.08, -0.08))), (1.25, 0.04, 1.65), "milk", rot=R)   # the paper
    b.box(tuple(o + R @ Vector((0, -0.09, 0.98))), (0.6, 0.16, 0.24), "gold_mid", rot=R)   # the clip
    for k in range(4):                                                               # ticked rows
        z = 0.5 - 0.36 * k
        b.box(tuple(o + R @ Vector((-0.38, -0.11, z))), (0.18, 0.03, 0.18), ("shirt_green", "shirt_green", "fur_orange",
                                                                             "pastel_sky")[k], rot=R)
        b.box(tuple(o + R @ Vector((0.2, -0.11, z))), (0.7, 0.03, 0.09), "concrete", rot=R)
    return _fin(b, "SetRecap", mat)


def set_auto_equip(mat):
    b = Builder()
    b.star((0, 0, 1.05), 1.0, 0.3, 0.3, "rarity_legend", points=4, rot=X)             # the big sparkle
    b.star((0, -0.12, 1.05), 0.55, 0.17, 0.12, "pastel_butter", points=4, rot=X)
    b.star((0.85, -0.1, 1.85), 0.32, 0.1, 0.12, "rarity_legend", points=4, rot=X)
    b.star((-0.85, -0.1, 0.35), 0.26, 0.08, 0.12, "nose_pink", points=4, rot=X)
    b.cyl((0.75, -0.2, 0.35), 0.36, 0.14, "shirt_green", segments=16, rot=X)          # a green tick badge
    _bar(b, (0.57, -0.3, 0.38), (0.7, -0.3, 0.24), 0.08, 0.05, "milk")
    _bar(b, (0.7, -0.3, 0.24), (0.95, -0.3, 0.52), 0.08, 0.05, "milk")
    return _fin(b, "SetAutoEquip", mat)


ICONS = {
    "MysteryMarket": mystery_market, "Codes": codes, "Collector": collector, "CornerShop": corner_shop,
    "LawnStall": lawn_stall, "RankUp": rank_up, "Bellhop": bellhop, "YardSale": yard_sale,
    "BigBackpack": big_backpack, "LongNet": long_net,
    "Tables": tables, "Espresso": espresso, "LuckyCat": lucky_cat,
    "RoleBarista": role_barista, "RoleWaiter": role_waiter, "RoleGreeter": role_greeter,
    "RoleEntertainer": role_entertainer,
    "Drop": drop, "Replay": replay, "Tag": tag, "Plate": plate,
    "SetMusic": set_music, "SetMusicVolume": set_music_volume, "SetSound": set_sound,
    "SetSoundVolume": set_sound_volume, "SetShake": set_shake, "SetGraphics": set_graphics,
    "SetOtherCats": set_other_cats, "SetMapIcons": set_map_icons, "SetAlerts": set_alerts, "SetRecap": set_recap,
    "SetAutoEquip": set_auto_equip,
}
# name -> (yaw, pitch) for icons.py
VIEWS = {
    "MysteryMarket": (-14.0, 10.0), "Codes": (-18.0, 8.0), "Collector": (-10.0, 6.0), "CornerShop": (-26.0, 14.0),
    "LawnStall": (-18.0, 12.0), "RankUp": (-14.0, 10.0), "Bellhop": (-18.0, 22.0), "YardSale": (-24.0, 24.0),
    "BigBackpack": (-24.0, 14.0), "LongNet": (-10.0, 12.0),
    "Tables": (-20.0, 22.0), "Espresso": (-24.0, 12.0), "LuckyCat": (-18.0, 8.0),
    "RoleBarista": (-14.0, 34.0), "RoleWaiter": (-22.0, 22.0), "RoleGreeter": (-10.0, 6.0),
    "RoleEntertainer": (-14.0, 8.0),
    "Drop": (-18.0, 14.0), "Replay": (-8.0, 4.0), "Tag": (-12.0, 8.0), "Plate": (-18.0, 40.0),
    "SetMusic": (-10.0, 6.0), "SetMusicVolume": (-10.0, 8.0), "SetSound": (-14.0, 12.0),
    "SetSoundVolume": (-16.0, 10.0), "SetShake": (-10.0, 6.0), "SetGraphics": (-24.0, 22.0),
    "SetOtherCats": (-16.0, 8.0), "SetMapIcons": (-14.0, 30.0), "SetAlerts": (-12.0, 8.0), "SetRecap": (-10.0, 6.0),
    "SetAutoEquip": (-10.0, 6.0),
}
