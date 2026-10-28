"""The Neighbourhood kit (areas-and-stations.md A2; draft sheet approved by Derek 2026-10-27): a pastel cul-de-sac.
Whisker Lane runs from the gate to a round loop road; four houses line the lane and five ring the loop, with the
playground under the tyre swing oak in the middle and two fenced back gardens in the far corners.

  CatCafe_Neighbourhood_Set   the whole area dressed, in area space (areakit): place it at the area's centre on its
                              floor, unturned. 140 x 140 inside WorldBuilder's walls. It brings its own roads, so
                              Layout.neighbourhood.paths goes. SPAWNS and TRAPS below are the matching spots.

The pieces inside it are built here too (HouseFrontA to C, PicketFence, Mailbox, Hedge, FlowerBed, GardenGnome,
KiddiePool, Trampoline, Slide, Swings, Sandbox, TyreSwingOak, Garage, BBQGrill, IceCreamVan, RecyclingBins,
GardenShed, StreetSign, LampPost, Bicycle); house windows are _Pane parts and porch lights and lamps _Bulb parts, so
they light at night.
"""

import math

import common
from areakit import PI, Set, flowers, gable, ring_blocks, rx, ry, rz, tree_round, turned, window
from common import RB, Builder

N = "CatCafe_Neighbourhood_"
NB_WALLS = {"A": ("blush", "pants_navy", "offwhite"), "B": ("mint", "dark_wood", "offwhite"),
            "C": ("pastel_butter", "terracotta", "offwhite")}
HOUSE_D, PORCH_D = 10.0, 4.0


def house(letter, mat):
    wall, roof, trim = NB_WALLS[letter]
    b, panes, lamp = Builder(), Builder(), Builder()
    W, D, H1, H2 = 20.0, HOUSE_D, 8.0, 15.5
    b.box_base((0, 0, 0), (W + 0.4, D + 0.4, 0.8), "concrete")                           # foundation
    b.box_base((0, 0, 0.8), (W, D, H2 - 0.8), wall)
    b.box((0, -D / 2 - 0.05, H1), (W + 0.3, 0.3, 0.4), trim, bevel=False)                # floor line
    for sx in (-1, 1):
        b.box_base((sx * (W / 2 + 0.05), -D / 2 + 0.2, 0.79), (0.4, 0.5, H2 - 0.8), trim, bevel=False)  # off the wall top
    gable(b, 0, 0, H2, W, D, 5.0 if letter != "C" else 4.0, wall, roof)
    fy = -D / 2
    if letter == "A":
        window(b, panes, 4.5, fy, 4.4, 4.5, 3.2)
        for x in (-5, 5):
            window(b, panes, x, fy, 11.5, 3.0, 3.0)
        window(b, panes, 0, fy, 18.0, 1.6, 1.6, sill=False)                               # attic
        door_x = -4.5
        b.box_base((7.5, 2, H2 + 2), (1.6, 1.6, 6.0), "brick")                             # chimney
    elif letter == "B":
        for x in (-5, 5):
            window(b, panes, x, fy, 4.4, 3.2, 3.2)
            window(b, panes, x, fy, 11.5, 3.0, 3.0)
        b.cyl((0, fy - 0.1, 18.0), 1.1, 0.3, trim, segments=12, rot=rx(90))                # round attic window
        panes.cyl((0, fy - 0.27, 18.0), 0.8, 0.06, "glass", segments=12, rot=rx(90))
        door_x = 0.0
    else:
        for x in (-6, 6):
            window(b, panes, x, fy, 4.4, 3.4, 3.2)
        b.box((0, fy - 1.2, 11.5), (8.0, 2.4, 0.4), trim)                                  # balcony
        for i in range(9):
            b.box_base((-3.8 + i * 0.95, fy - 2.3, 11.7), (0.2, 0.2, 1.4), trim, bevel=False)
        b.box((0, fy - 2.3, 13.2), (8.0, 0.3, 0.25), trim, bevel=False)
        window(b, panes, 0, fy, 12.6, 3.4, 2.8, sill=False)
        door_x = 0.0
    b.box_base((door_x, fy - 0.1, 0.8), (3.2, 0.3, 6.2), trim, bevel=False)                # door
    b.box_base((door_x, fy - 0.22, 0.8), (2.6, 0.2, 5.7), "shirt_red" if letter != "B" else "sign_teal", bevel=False)
    b.box((door_x + 0.9, fy - 0.42, 3.6), (0.25, 0.2, 0.25), "rarity_legend", bevel=False)
    px0, px1 = (door_x - 4.5, door_x + 4.5) if letter != "B" else (-W / 2 + 0.5, W / 2 - 0.5)
    pw, pd = px1 - px0, PORCH_D
    pc = (px0 + px1) / 2
    b.box_base((pc, fy - pd / 2, 0), (pw, pd, 1.0), "caramel_wood")                        # porch
    for i in range(2):
        b.box_base((door_x, fy - pd - 0.4 - i * 0.8, 0), (3.6, 0.8, 0.66 - i * 0.33), "caramel_wood")
    for x in (px0 + 0.4, px1 - 0.4):
        b.box_base((x, fy - pd + 0.4, 1.0), (0.5, 0.5, 6.0), trim)
    b.box((pc, fy - pd / 2 + 0.2, 7.3), (pw + 0.6, pd + 1.0, 0.4), roof, rot=rx(8))
    lamp.box((door_x - 2.0, fy - 0.24, 6.4), (0.5, 0.5, 0.7), "lamp_warm", bevel=False)     # porch light
    bx = px1 - 2.5
    b.box_base((bx, fy - 1.2, 1.0), (2.6, 0.9, 0.9), "caramel_wood")                         # porch bench
    b.box((bx, fy - 0.8, 2.35), (2.6, 0.2, 1.0), "caramel_wood")
    b.box((0, fy - 0.35, H2 + 0.1), (W + 0.6, 0.5, 0.35), "metal", bevel=False)            # gutter and downpipe
    b.box_base((W / 2 + 0.1, fy - 0.35, 0.3), (0.4, 0.4, H2), "metal", bevel=False)
    name = f"{N}HouseFront{letter}"
    return [b.finalize(name, mat), panes.finalize(name + "_Pane", mat), lamp.finalize(name + "_Bulb", mat)], door_x


def fence(mat, L=8.0):
    b = Builder()
    n = max(3, int(round((L - 0.5) / 0.75)) + 1)                 # two Parts a picket: the post and a diamond tip
    for i in range(n):
        x = -L / 2 + 0.25 + i * (L - 0.5) / (n - 1)
        b.box_base((x, 0, 0), (0.36, 0.36, 2.4), "offwhite", bevel=False)           # 0.36 deep, so it collides
        b.box((x, 0, 2.4), (0.255, 0.36, 0.255), "offwhite", rot=ry(45), bevel=False)
    for z in (0.7, 1.8):
        b.box((0, 0.12, z), (L, 0.12, 0.25), "offwhite", bevel=False)
    for x in (-L / 2, L / 2):
        b.box_base((x, 0.05, 0), (0.45, 0.45, 2.8), "offwhite")
    return [b.finalize(N + "PicketFence", mat)]


def mailbox(mat):
    b = Builder()
    b.box_base((0, 0, 0), (0.35, 0.35, 3.4), "dark_wood")
    b.box_base((0, 0, 3.4), (0.9, 1.6, 0.7), "shirt_blue")
    b.cyl((0, 0, 4.1), 0.45, 1.6, "shirt_blue", segments=10, rot=rx(90))
    b.box_base((0.55, 0.3, 3.7), (0.1, 0.2, 1.2), "bowl_red", bevel=False)                  # flag up
    b.box((0.55, 0.0, 4.75), (0.1, 0.6, 0.35), "bowl_red", bevel=False)
    b.box((0, -0.82, 3.9), (0.5, 0.06, 0.15), "offwhite", bevel=False)
    return [b.finalize(N + "Mailbox", mat)]


def hedge(mat, L=6.0):
    b = Builder()
    b.box_base((0, 0, 0), (L, 1.6, 2.4), "leaf_dark")
    k = max(2, int(L / 1.6))
    for i in range(k):
        x = -L / 2 + 0.8 + i * (L - 1.6) / (k - 1)
        b.ico((x, -0.2, 2.3), 0.9, "leaf_dark", subdivisions=1, scale=(1, 0.9, 0.6))
    return [b.finalize(N + "Hedge", mat)]


def flowerbed(mat):
    b, deco = Builder(), Builder()                     # flowers as _Decor, so a cat can sit in the bed among them
    b.box_base((0, 0, 0), (5.0, 2.2, 0.6), "brick")
    b.box_base((0, 0, 0.3), (4.6, 1.8, 0.4), "choco", bevel=False)
    for i, x in enumerate((-1.6, -0.2, 1.4)):
        flowers(deco, x, 0, 0.7, n=5, r=0.6, seed=i)
    return [b.finalize(N + "FlowerBed", mat), deco.finalize(N + "FlowerBed_Decor", mat)]


def gnome(mat):
    b = Builder()
    b.cyl_base((0, 0, 0), 0.5, 0.25, "leaf_green", segments=10)
    b.cyl_base((0, 0, 0.25), 0.45, 0.9, "shirt_blue", segments=10, radius2=0.35)
    b.sphere((0, 0, 1.4), 0.38, "skin_light", segments=10, rings=6)
    b.cyl_base((0, -0.15, 0.85), 0.35, 0.55, "offwhite", segments=8, radius2=0.05)          # beard
    b.cyl_base((0, 0, 1.6), 0.42, 1.1, "bowl_red", segments=10, radius2=0.02)
    b.sphere((0, -0.36, 1.38), 0.1, "nose_pink", segments=6, rings=4)
    return [b.finalize(N + "GardenGnome", mat)]


def kiddie_pool(mat):
    b, water = Builder(), Builder()
    for i, sw in enumerate(("shirt_blue", "offwhite", "shirt_blue")):
        b.ring((0, 0, 0.3 + i * 0.6), 3.0, 0.7, 0.6, sw, segments=16)
    water.cyl_base((0, 0, 0.0), 2.45, 1.2, "puddle", segments=16, bevel=False)
    b.ico((0.9, -0.6, 1.45), 0.45, "pastel_butter", subdivisions=1)                         # a rubber duck
    b.box((1.3, -0.6, 1.55), (0.35, 0.2, 0.12), "fur_orange", bevel=False)
    return [b.finalize(N + "KiddiePool", mat), water.finalize(N + "KiddiePool_Water", mat)]


def trampoline(mat):
    b = Builder()
    for k in range(6):
        a = 2 * PI * k / 6
        b.box_base((3.0 * math.cos(a), 3.0 * math.sin(a), 0), (0.25, 0.25, 1.6), "metal", bevel=False)
    b.ring((0, 0, 1.75), 3.4, 0.9, 0.3, "shirt_blue", segments=16)
    b.cyl((0, 0, 1.68), 2.6, 0.1, "fur_black", segments=16, bevel=False)
    return [b.finalize(N + "Trampoline", mat)]


def slide(mat):
    b = Builder()
    for x in (-1.2, 1.2):
        for y in (0.8, 3.2):
            b.box_base((x, y, 0), (0.35, 0.35, 5.6), "pastel_butter")
    b.box_base((0, 2.0, 3.8), (2.8, 2.8, 0.35), "caramel_wood")
    b.box((0, 2.0, 5.7), (3.2, 3.2, 0.3), "shirt_red")                                     # little roof
    b.pyramid((0, 2.0, 5.85), 3.6, 1.4, "shirt_red")
    for i in range(6):                                                                      # ladder at the back
        b.box((0, 3.9, 0.6 + i * 0.6), (1.6, 0.25, 0.18), "caramel_wood", bevel=False)
    for x in (-0.9, 0.9):
        b.box_base((x, 3.9, 0), (0.2, 0.2, 4.0), "caramel_wood", bevel=False)
    a = math.atan2(3.9, 5.0)
    L = math.hypot(5.0, 3.9)
    b.box((0, 0.6 - 2.5, 3.9 / 2 + 0.1), (1.8, L, 0.25), "sign_teal", rot=rx(math.degrees(a)))
    for x in (-0.95, 0.95):
        b.box((x, 0.6 - 2.5, 3.9 / 2 + 0.35), (0.15, L, 0.5), "sign_teal", rot=rx(math.degrees(a)))
    b.box_base((0, -4.9, 0), (1.8, 1.2, 0.25), "sign_teal")
    return [b.finalize(N + "Slide", mat)]


def swings(mat):
    b = Builder()
    for x in (-4.0, 4.0):
        for s in (-1, 1):
            b.box((x, s * 1.1, 3.0), (0.35, 0.35, 6.4), "shirt_red", rot=rx(s * 20))
    b.box((0, 0, 6.0), (8.6, 0.4, 0.4), "shirt_red")
    for x, seat in ((-1.8, "pastel_butter"), (1.8, "sign_teal")):
        for dx in (-0.6, 0.6):
            b.box((x + dx, 0, 3.8), (0.08, 0.08, 4.4), "metal", bevel=False)
        b.box((x, 0, 1.55), (1.6, 0.7, 0.18), seat)
    return [b.finalize(N + "Swings", mat)]


def sandbox(mat):
    b = Builder()
    for s in (-1, 1):
        b.box_base((0, s * 2.9, 0), (6.2, 0.4, 0.8), "caramel_wood")
        b.box_base((s * 2.9, 0, 0), (0.4, 5.4, 0.8), "caramel_wood")
    b.box_base((0, 0, 0), (5.4, 5.4, 0.55), "fur_sand", bevel=False)
    b.ico((0.8, 0.6, 0.55), 0.9, "fur_sand", subdivisions=1, scale=(1, 1, 0.5))            # sand castle heap
    b.cyl_base((0.8, 0.6, 0.85), 0.35, 0.6, "fur_sand", segments=8)
    b.cyl_base((-1.4, -1.0, 0.55), 0.35, 0.55, "shirt_red", segments=8, radius2=0.42)     # bucket
    b.box((-0.4, -1.6, 0.62), (0.25, 1.2, 0.1), "sign_teal", bevel=False, rot=rz(30))     # spade
    return [b.finalize(N + "Sandbox", mat)]


def tyre_swing_oak(mat):
    b = Builder()
    b.cyl_base((0, 0, 0), 1.3, 9.0, "fur_brown", segments=10, radius2=0.9)
    b.box((2.6, 0, 7.6), (5.5, 1.0, 1.0), "fur_brown", rot=ry(-12))                         # swing branch
    for (x, y, z, r, sw) in ((0, 0, 12.0, 5.0, "leaf_green"), (3.8, 0.5, 10.5, 3.2, "leaf_green"),
                             (-3.4, -0.5, 10.8, 3.4, "leaf_dark"), (0.5, 2.6, 11.0, 3.0, "leaf_dark")):
        b.ico((x, y, z), r, sw, subdivisions=1)
    for s in (-1, 1):                                                                       # roots
        b.box_base((s * 1.4, 0.3, 0), (1.4, 0.8, 0.6), "fur_brown", rot=rz(s * 20))
    b.box((4.4, 0, 5.2), (0.12, 0.12, 4.4), "cardboard", bevel=False)                       # rope
    b.ring((4.4, 0, 2.6), 1.0, 0.45, 0.7, "fur_black", segments=12, rot=rx(90))            # tyre
    return [b.finalize(N + "TyreSwingOak", mat)]


def garage(mat):
    b = Builder()
    W, D, H = 12.0, 12.0, 8.0
    b.box_base((0, 0, 0), (W, D, H), "pastel_lilac")
    b.box_base((0, -D / 2 - 0.02, 0), (8.0, 0.4, 6.2), "fur_black", bevel=False)            # dark inside
    for i in range(6):                                                                      # door, half up
        b.box((0, -D / 2 - 0.3, 6.0 - i * 0.55), (8.06, 0.3, 0.5), "offwhite", bevel=False)
    b.box((0, -D / 2 - 0.25, 6.5), (8.8, 0.5, 0.5), "offwhite", bevel=False)
    gable(b, 0, 0, H, W, D, 3.5, "pastel_lilac", "dark_wood")
    return [b.finalize(N + "Garage", mat)]


def bbq(mat):
    b = Builder()
    for k in range(3):
        a = 2 * PI * k / 3 + 0.3
        b.box((0.6 * math.cos(a), 0.6 * math.sin(a), 1.2), (0.15, 0.15, 2.5), "fur_black", rot=(0.25, "X"))
    b.sphere((0, 0, 2.5), 1.1, "fur_black", segments=12, rings=6, scale=(1, 1, 0.75))
    b.box((0, 0, 2.55), (2.3, 2.3, 0.08), "metal", bevel=False)
    b.box((0, -0.9, 3.0), (0.6, 0.15, 0.15), "metal", bevel=False)
    for x in (-0.4, 0.3):
        b.box((x, 0.1, 2.75), (0.6, 0.3, 0.25), "bowl_red", bevel=False)                     # sausages
    return [b.finalize(N + "BBQGrill", mat)]


def ice_cream_van(mat):
    b, glass = Builder(), Builder()
    b.box_base((0, 0.8, 1.0), (6.4, 11.0, 6.8), "fur_rose")
    b.box_base((0, -6.0, 1.0), (6.2, 3.4, 4.2), "fur_rose")                                 # cab
    glass.box((0, -7.75, 3.9), (5.4, 0.1, 1.8), "glass", bevel=False)                        # windscreen
    b.box_base((0, 0.8, 0.9), (6.5, 11.1, 1.0), "offwhite")                                  # stripe
    b.box((3.25, 1.2, 5.0), (0.15, 5.0, 2.8), "night_sky", bevel=False)                     # serving hatch
    b.box((3.7, 1.2, 3.55), (1.0, 5.4, 0.25), "offwhite", bevel=False)
    b.box((3.35, 1.2, 6.9), (0.3, 5.6, 0.5), "mint", bevel=False)                            # awning
    b.cyl((3.3, -2.6, 5.2), 0.9, 0.1, "offwhite", segments=12, rot=ry(90))                  # cone sign
    b.cyl((3.36, -2.6, 5.2), 0.6, 0.1, "blush", segments=12, rot=ry(90))
    for (x, y) in ((-3.1, -5.0), (3.1, -5.0), (-3.1, 4.0), (3.1, 4.0)):
        b.cyl((x, y, 1.0), 1.0, 0.6, "fur_black", segments=12, rot=ry(90))
    b.cyl_base((0, 2.0, 7.8), 0.3, 2.6, "treat_tan", segments=10, radius2=1.2)              # big cone on the roof
    b.cyl_base((0, 2.0, 10.4), 0.9, 0.4, "treat_tan", segments=10)
    b.ico((0, 2.0, 11.1), 1.2, "blush", subdivisions=1)
    b.ico((0, 2.0, 12.3), 0.35, "bowl_red", subdivisions=1)
    for i, sw in enumerate(("mint", "pastel_butter", "blush", "pastel_lilac")):
        b.cyl((3.27, 3.0 + (i - 1.5) * 1.1, 2.6), 0.35, 0.1, sw, segments=8, rot=ry(90))   # scoop dots
    return [b.finalize(N + "IceCreamVan", mat), glass.finalize(N + "IceCreamVan_Glass", mat)]


def recycling_bins(mat):
    b = Builder()
    for x, sw in ((-1.2, "shirt_blue"), (1.2, "shirt_green")):
        b.box_base((x, 0, 0.3), (2.0, 2.2, 3.6), sw)
        b.box((x, -0.1, 4.0), (2.2, 2.5, 0.25), sw)
        b.box((x, 1.2, 3.6), (1.8, 0.25, 0.25), "fur_black", bevel=False)
        for dx in (-0.7, 0.7):
            b.cyl((x + dx, 1.0, 0.35), 0.35, 0.3, "fur_black", segments=8, rot=ry(90))
        b.box((x, -1.12, 2.2), (0.9, 0.05, 0.9), "offwhite", bevel=False)                    # recycle sign
    return [b.finalize(N + "RecyclingBins", mat)]


def garden_shed(mat):
    b, glass = Builder(), Builder()
    b.box_base((0, 0, 0), (6.0, 5.0, 5.5), "caramel_wood")
    for x in (-2.4, -1.2, 0, 1.2, 2.4):
        b.box_base((x, -2.52, 0), (0.08, 0.08, 5.5), "dark_wood", bevel=False)              # board lines
    gable(b, 0, 0, 5.5, 6.0, 5.0, 2.2, "caramel_wood", "leaf_dark")
    b.box_base((0.6, -2.58, 0), (2.4, 0.15, 4.4), "dark_wood", bevel=False)                 # door, jammed
    b.box((0.6, -2.72, 2.4), (3.4, 0.2, 0.4), "cardboard", bevel=False, rot=ry(-20))         # the stuck plank
    glass.box((-1.9, -2.6, 3.4), (1.2, 0.1, 1.0), "glass", bevel=False)
    b.box_base((-2.2, -3.2, 0), (0.9, 0.9, 1.1), "terracotta")                              # flower pot
    flowers(b, -2.2, -3.2, 1.1, n=4, r=0.3, seed=2)
    return [b.finalize(N + "GardenShed", mat), glass.finalize(N + "GardenShed_Glass", mat)]


def street_sign(mat):
    rb = RB()
    rb.box((0, 4.0, 0), (0.35, 8.0, 0.35), "metal")
    w = common.text_width("WHISKER LANE", 0.17)
    rb.box((0, 7.0, -0.05), (w + 1.0, 1.4, 0.2), "shirt_green")
    rb.text("WHISKER LANE", (w / 2, 6.58, -0.15), 0.17, 0.08, "offwhite", right=(-1, 0, 0), up=(0, 1, 0))
    rb.box((0, 8.2, -0.05), (0.5, 0.5, 0.5), "metal")
    return [rb.finalize(N + "StreetSign", mat)]


def lamp_post(mat):
    b, bulb = Builder(), Builder()
    b.cyl_base((0, 0, 0), 0.4, 0.4, "fur_black", segments=8)
    b.cyl_base((0, 0, 0.4), 0.18, 8.25, "fur_black", segments=8)
    bulb.box((0, 0, 9.3), (1.1, 1.1, 1.2), "lamp_warm", bevel=False)
    b.pyramid((0, 0, 9.9), 1.5, 0.7, "fur_black")
    b.box((0, 0, 8.65), (1.3, 1.3, 0.15), "fur_black", bevel=False)
    return [b.finalize(N + "LampPost", mat), bulb.finalize(N + "LampPost_Bulb", mat)]


def bicycle(mat):
    b = Builder()
    for y in (-1.3, 1.3):
        b.ring((0, y, 1.0), 0.95, 0.18, 0.12, "fur_black", segments=14, rot=ry(90))
    b.box((0, -0.2, 1.4), (0.14, 2.2, 0.14), "shirt_red", rot=rx(-8), bevel=False)
    b.box((0, 0.45, 1.25), (0.14, 0.14, 1.4), "shirt_red", rot=rx(20), bevel=False)
    b.box((0, -1.0, 1.3), (0.14, 0.14, 1.2), "shirt_red", rot=rx(-15), bevel=False)
    b.box((0, 0.6, 2.05), (0.4, 0.8, 0.15), "fur_black", bevel=False)                         # seat
    b.box((0, -1.2, 2.0), (1.3, 0.12, 0.12), "metal", bevel=False)                            # handlebar
    b.box((0, -1.55, 1.7), (0.6, 0.5, 0.4), "cardboard", bevel=False)                         # basket
    return [b.finalize(N + "Bicycle", mat)]


# ------------------------------------------------------------------------------------------------- the set --
HALF = 70.0                     # WorldBuilder's walls stand at +-70 (their inner faces at +-69.5)
LOOP_C = 20.0                   # the loop's centre, north of the area's centre (the far house clears the hedge)
HUB_Y = 0.32                    # the hub lawn's top; the playground stands on it
ROAD_OUT, ROAD_W = 26.0, 8.5
PAVE_OUT, KERB_R = 28.5, 17.7
LOOP_HOUSE_R = 42.0
LANE_HW = 6.0
BORDER_D = 2.0                  # the border hedge's depth
GATE_HALF = 23.0                # the gate model is 44.6 wide, centred on the lane
ROAD_Y, PAVE_Y, LANE_PAVE_Y, DRIVE_Y = 0.24, 0.37, 0.34, 0.3     # tops of the slabs in _ground


def _ground():
    """Flat pieces on the floor (Builder, Blender axes: Roblox (x, z) is (-x, y) here). Every top sits at its own
    height so no two overlapping slabs share a face."""
    g = Builder()
    # the loop is a round road disc with the hub's lawn on top: one Cylinder Part each, where a wide ring of
    # blocks would open wedge gaps between them
    g.cyl_base((0, LOOP_C, 0.02), ROAD_OUT, 0.22, "concrete_dark", segments=48, bevel=False)          # top 0.24
    g.cyl_base((0, LOOP_C, 0.03), ROAD_OUT - ROAD_W, 0.29, "leaf_green", segments=40, bevel=False)    # top 0.32
    ring_blocks(g, 0, LOOP_C, 0.01, PAVE_OUT, PAVE_OUT - ROAD_OUT + 0.1, 0.36, "concrete", n=48)       # top 0.37
    ring_blocks(g, 0, LOOP_C, 0.01, KERB_R, 0.8, 0.44, "concrete", n=36)                             # hub kerb
    for k in range(20):                                                                             # loop dashes
        a = 2 * PI * (k + 0.5) / 20
        g.box((21.75 * math.cos(a), LOOP_C + 21.75 * math.sin(a), 0.25), (0.4, 2.4, 0.02), "offwhite", bevel=False,
              rot=(a, "Z"))
    lane_end = LOOP_C - ROAD_OUT + 0.6
    g.box_base((0, (-HALF + lane_end) / 2, 0.015), (2 * LANE_HW, lane_end + HALF, 0.195), "concrete_dark", bevel=False)
    for y in range(-66, int(lane_end) - 2, 6):                                                     # lane dashes
        g.box((0, y, 0.22), (0.4, 2.4, 0.02), "offwhite", bevel=False)
    for sx in (-1, 1):
        g.box_base((sx * (LANE_HW + 1.5), (-HALF + lane_end - 1.5) / 2, 0.01), (3, lane_end - 1.5 + HALF, 0.33),
                   "concrete", bevel=False)                                                         # lane pavements
        for y in (-41.5, -11.5):                                                                    # driveways
            g.box_base((sx * 23, y, 0.01), (26, 6, 0.29), "concrete", bevel=False)
    return g


def build_set(mat):
    s = Set(N + "Set")

    def lot(letter, x, z, r, fence_at=12.5):
        objs, door_x = house(letter, mat)
        s.put(objs, x, z, r)
        s.mark("porch", *turned(x, z, r, 2.8 - door_x, -HOUSE_D / 2 - 2.4), y=1.0)          # on the porch, by the door
        for sd in (-1, 1):                                                                 # fence either side of the path
            s.put(fence(mat), *turned(x, z, r, sd * 6.8, -fence_at), r)
        s.put(mailbox(mat), *turned(x, z, r, -3.2, -fence_at - 0.7), r)
        bed_x = 9.5 if door_x else 6.5                                                     # clear of the steps
        front = -HOUSE_D / 2 - PORCH_D - 1.7                                               # between porch and fence
        s.put(flowerbed(mat), *turned(x, z, r, bed_x, front), r)
        s.mark("flowerbed", *turned(x, z, r, bed_x, front), y=0.7)                         # in the bed
        s.put(hedge(mat), *turned(x, z, r, -7.0, front), r)

    for letter, x, z, r in (("B", 27, -56, 90), ("C", -27, -56, -90), ("A", 27, -26, 90), ("B", -27, -26, -90)):
        lot(letter, x, z, r)
    for letter, deg in (("A", 90), ("C", 40), ("C", 140), ("B", -10), ("A", 190)):
        a = math.radians(deg)
        x, z = -LOOP_HOUSE_R * math.cos(a), LOOP_C + LOOP_HOUSE_R * math.sin(a)
        r = math.degrees(math.atan2(x, z - LOOP_C))                                        # front toward the loop
        lot(letter, x, z, r)
    # the hub playground
    s.put(tyre_swing_oak(mat), -3, LOOP_C + 4, 20, y=HUB_Y)
    s.mark("hub", *turned(-3, LOOP_C + 4, 20, -4.4, -1.5), y=HUB_Y)                         # by the tyre
    s.put(slide(mat), 9, LOOP_C + 5, 160, y=HUB_Y)
    s.mark("hub", *turned(9, LOOP_C + 5, 160, 0, 2.0), y=HUB_Y)                             # under the platform
    s.put(swings(mat), -5, LOOP_C - 10, 0, y=HUB_Y)
    s.put(sandbox(mat), 7, LOOP_C - 8, 10, y=HUB_Y)
    s.mark("hub", *turned(7, LOOP_C - 8, 10, 1.2, 1.2), y=HUB_Y + 0.55)                     # on the sand
    # back gardens in the far corners, fenced off the loop with a gap cats squeeze through
    for sx in (-1, 1):
        s.put(fence(mat, 16.0), sx * 50, 42.2, 90)                                         # the gap at z 50 to 58
        s.put(fence(mat), sx * 50, 62.2, 90)
        s.put(fence(mat, 17.0), sx * 58.9, 34.2, 0)                                       # to the border hedge
    # seen from the gate, as in the approved draft: the trampoline and pool on the right (-X), the shed, BBQ and
    # gnomes on the left (+X)
    s.put(trampoline(mat), -60.5, 58, 0)
    s.mark("garden", -60.5, 58, y=1.73)                                                 # on the mat
    s.put(kiddie_pool(mat), -61, 43, 0)
    s.put(garden_shed(mat), 63.5, 40, 90)
    s.mark("shed", 59.2, 40)
    s.put(bbq(mat), 59, 61, -30)
    for (x, z) in ((55, 48), (63, 52), (56, 64)):
        s.put(gnome(mat), x, z, 160)
    s.mark("garden", 58, 56)
    # the lane: garage, bike, bins, lamps, the sign; the van parked on the loop
    s.put(garage(mat), -45, -41.5, -90)
    s.mark("driveway", -18, -41.5)
    s.put(bicycle(mat), 22, -41.5, 90, y=DRIVE_Y)
    s.mark("driveway", 16, -41.5)
    s.mark("driveway", -16, -11.5)
    s.mark("driveway", 16, -11.5)
    s.put(recycling_bins(mat), 34, -39, 90, y=DRIVE_Y)
    s.put(recycling_bins(mat), -33, -12.5, -90, y=DRIVE_Y)
    s.mark("bins", -30.6, -12.5, y=DRIVE_Y)
    a = math.radians(-35)
    vx, vz = -21.75 * math.cos(a), LOOP_C + 21.75 * math.sin(a)
    s.put(ice_cream_van(mat), vx, vz, -35, y=ROAD_Y)
    s.mark("van", *turned(vx, vz, -35, 0, 8.0), y=ROAD_Y)                                  # behind the van
    for deg in (20, 160, -50, 230):
        a = math.radians(deg)
        s.put(lamp_post(mat), -27.3 * math.cos(a), LOOP_C + 27.3 * math.sin(a), 0, y=PAVE_Y)
    for sx in (-1, 1):
        for z in (-52, -30):
            s.put(lamp_post(mat), sx * 9.5, z, 0, y=LANE_PAVE_Y)
    s.put(street_sign(mat), 11.0, -62.0, 0)
    # a hedge along the inside of the walls (the draft's green border) in blocks of two greens, open at the gate,
    # and trees in the empty corners
    hb = Builder()

    def hedge_run(a0, a1, at, along_x):
        n = max(1, round(abs(a1 - a0) / 7.0))
        step = (a1 - a0) / n
        for i in range(n):
            c, size = a0 + (i + 0.5) * step, (abs(step), BORDER_D, 6.6 + 0.5 * (i % 2))
            sw = ("leaf_green", "leaf_dark")[i % 2]
            if along_x:
                hb.box_base((-c, at, 0), size, sw, bevel=False)
            else:
                hb.box_base((-at, c, 0), (size[1], size[0], size[2]), sw, bevel=False)

    inner = HALF - 0.5                                          # the walls' inner faces
    mid = inner - BORDER_D / 2
    hedge_run(-inner, inner, mid, True)                                                    # far wall
    for sx in (-1, 1):
        hedge_run(-inner, inner - BORDER_D, sx * mid, False)                               # side walls
        # the town side (town-layout-v3.md 7d: see-through, the wall behind is invisible): a low hedge with gaps
        n = 7
        step = (inner - GATE_HALF) / n
        for i in range(n):
            c = sx * (GATE_HALF + (i + 0.5) * step)
            hb.box_base((-c, -mid, 0), (step - 1.6, BORDER_D * 0.8, 3.0), ("leaf_green", "leaf_dark")[i % 2],
                        bevel=False)
    s.put([hb.finalize(N + "BorderHedge", mat)], 0, 0, 0)
    tb = Builder()
    for (x, z, hh, k) in ((-63, -63, 8, 0), (-50, -62, 7, 1), (63, -63, 8, 2), (-60, -30, 7, 1), (62, -40, 7, 0),
                          (48, -12, 6.5, 2), (40, 63, 7.5, 1), (-40, 63, 7.5, 0)):
        tree_round(tb, -x, z, 0, h=hh * 1.5, r=3.0 + 0.4 * k, leaf=("leaf_green", "leaf_dark", "mint")[k])
    s.put([tb.finalize(N + "Trees", mat)], 0, 0, 0)
    return s.finish(_ground(), mat), s


def build_neighbourhood_set(mat):
    objs, _ = build_set(mat)
    return objs


ASSETS = {
    "CatCafe_Neighbourhood_Set": (build_neighbourhood_set, 80000),
}
