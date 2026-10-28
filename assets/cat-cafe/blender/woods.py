"""The Woods kit (areas-and-stations.md A3; draft sheet approved by Derek 2026-10-27): a storybook forest. The gate
opens onto a dirt path that crosses the stream on a little bridge and ends in the clearing round the Great Oak; the
campsite sits off the path on one side and the treehouse, mushroom ring and waterfall pond on the other, all ringed
by pines and a thicket along the walls.

  CatCafe_Woods_Set   the whole area dressed, in area space (areakit), gate side -Z: place it at the area's centre
                      on its floor, turned so -Z faces the gate. 120 x 120 inside WorldBuilder's walls.

The pieces inside it are built here too (PineTall, OakRound, GreatOak, Stump, FallenLog, HollowLog, BrambleBush,
Fern, MushroomSmall, MushroomGlowing, MushroomRing, MossyRock, SteppingStones, WoodBridge, Tent, Campfire,
LogBench, Treehouse, LookoutTower, BerryBush, LeafPile, Signpost, Lantern, WaterfallPond). Lantern lamps and the
glowing mushrooms are _Bulb parts and the oak's and treehouse's windows _Pane parts, so they light at night; the
campfire's flames are _Glow, lit all day.
"""

import math

from mathutils import Matrix, Vector

import common
from areakit import PI, Set, gable, rx, ry, rz, tree_round
from common import RB, Builder

N = "CatCafe_Woods_"


def pine(mat, h=18.0):
    b = Builder()
    b.cyl_base((0, 0, 0), 0.7, h * 0.35, "fur_brown", segments=8, radius2=0.5)
    for i, (z, r) in enumerate(((0.22, 4.2), (0.42, 3.4), (0.6, 2.6), (0.76, 1.7))):
        b.cyl_base((0, 0, h * z), r, h * 0.3 if i < 3 else h * 0.26, "leaf_dark", segments=8, radius2=0.25, bevel=False)
    return [b.finalize(N + "PineTall", mat)]


def oak(mat):
    b = Builder()
    tree_round(b, 0, 0, h=12.0, r=4.4, leaf="leaf_green")
    return [b.finalize(N + "OakRound", mat)]


def great_oak(mat):
    b, win = Builder(), Builder()
    b.cyl_base((0, 0, 0), 5.0, 26.0, "fur_brown", segments=12, radius2=3.4)
    b.box_base((0, -4.6, 0), (4.2, 1.6, 6.5), "choco", bevel=False)                          # hollow doorway
    b.cyl((0, -4.6, 6.5), 2.1, 1.6, "choco", segments=12, rot=rx(90), bevel=False)
    win.box((2.6, -4.7, 13.0), (1.6, 0.6, 1.6), "lamp_warm", bevel=False)                     # a little window
    b.box((2.6, -4.9, 13.0), (1.9, 0.3, 0.2), "caramel_wood", bevel=False)                  # sill, proud of the pane
    for k in range(7):                                                                       # roots, nooks between
        a = 2 * PI * (k + 0.5) / 7 - PI / 2
        if abs(math.cos(a)) < 0.2 and math.sin(a) < 0:
            continue
        b.box((6.0 * math.cos(a), 6.0 * math.sin(a), 1.0), (5.0, 1.8, 2.4), "fur_brown", rot=(a, "Z"))
    for (x, y, z, r, sw) in ((0, 0, 30, 10, "leaf_green"), (8, 2, 26, 6.5, "leaf_dark"), (-8, -1, 27, 7, "leaf_green"),
                             (2, 7, 27, 6.5, "leaf_dark"), (-2, -7, 25, 6, "leaf_dark")):
        b.ico((x, y, z), r, sw, subdivisions=1)
    for (x, z) in ((-5.5, 18), (5.5, 20)):                                                   # big branches
        b.box((x, 0, z), (6, 1.6, 1.6), "fur_brown", rot=ry(25 if x > 0 else -25))
    for k in range(4):                                                                       # mushrooms at the foot
        a = -PI / 2 + 0.7 + k * 0.5
        b.cyl_base((5.4 * math.cos(a), 5.4 * math.sin(a), 0), 0.25, 0.6, "offwhite", segments=6)
        b.cyl_base((5.4 * math.cos(a), 5.4 * math.sin(a), 0.6), 0.6, 0.35, "bowl_red", segments=8, radius2=0.1)
    return [b.finalize(N + "GreatOak", mat), win.finalize(N + "GreatOak_Pane", mat)]


def stump(mat):
    b = Builder()
    b.cyl_base((0, 0, 0), 1.6, 1.6, "fur_brown", segments=10, radius2=1.4)
    b.cyl_base((0, 0, 1.6), 1.35, 0.06, "treat_tan", segments=10, bevel=False)
    b.ring((0, 0, 1.62), 0.8, 0.12, 0.04, "kibble", segments=10, bevel=False)
    b.cyl_base((1.2, -1.0, 0), 0.15, 0.5, "offwhite", segments=6)
    b.cyl_base((1.2, -1.0, 0.5), 0.4, 0.25, "bowl_red", segments=8, radius2=0.1)
    return [b.finalize(N + "Stump", mat)]


def _log(b, L, r, moss=True, hollow=False):
    b.cyl((0, 0, r), r, L, "fur_brown", segments=10, rot=ry(90))
    for x in (-L / 2 - 0.02, L / 2 + 0.02):
        b.cyl((x, 0, r), r * 0.86, 0.06, "treat_tan", segments=10, rot=ry(90), bevel=False)
    if hollow:
        b.cyl((-L / 2 - 0.06, 0, r), r * 0.68, 0.1, "choco", segments=10, rot=ry(90), bevel=False)
    if moss:
        b.ico((L * 0.15, 0, r * 1.85), r * 0.6, "leaf_green", subdivisions=1, scale=(1.6, 1.0, 0.35))
        b.ico((-L * 0.25, 0.2, r * 1.8), r * 0.45, "leaf_green", subdivisions=1, scale=(1.4, 1.0, 0.35))


def fallen_log(mat):
    b = Builder()
    _log(b, 8.0, 0.9)
    b.box((1.5, 0.9, 1.4), (0.3, 1.4, 0.3), "fur_brown", rot=rx(40))                           # broken branch
    return [b.finalize(N + "FallenLog", mat)]


def hollow_log(mat):
    b = Builder()
    _log(b, 7.0, 1.5, hollow=True)
    b.ico((3.0, -1.6, 0.5), 0.8, "leaf_dark", subdivisions=1, scale=(1, 1, 0.6))
    return [b.finalize(N + "HollowLog", mat)]


def bramble(mat):
    b = Builder()
    b.ico((0, 0, 1.4), 2.0, "leaf_dark", subdivisions=1, scale=(1.4, 1.0, 0.8))
    for k in range(14):                                                                      # thorny canes
        a = 2 * PI * k / 14
        b.box((1.8 * math.cos(a), 1.3 * math.sin(a), 1.2 + 0.5 * math.sin(3 * a)), (0.14, 2.4, 0.14), "rust",
              rot=Matrix.Rotation(a, 3, "Z") @ Matrix.Rotation(0.6, 3, "X"))
    for k in range(9):
        a = 2 * PI * k / 9 + 0.3
        b.ico((2.3 * math.cos(a), 1.5 * math.sin(a), 1.1 + 0.6 * math.cos(2 * a)), 0.2,
              "pastel_lilac" if k % 2 else "bowl_red", subdivisions=1)
    return [b.finalize(N + "BrambleBush", mat)]


def fern(mat):
    b = Builder()
    for k in range(7):
        a = 2 * PI * k / 7
        b.box((0.9 * math.cos(a), 0.9 * math.sin(a), 0.7), (0.5, 2.0, 0.08), "leaf_green",
              rot=Matrix.Rotation(a - PI / 2, 3, "Z") @ Matrix.Rotation(-0.6, 3, "X"))
    return [b.finalize(N + "Fern", mat)]


def _shroom(b, x, y, s, cap, dots="offwhite", stem="offwhite", glow=None):
    """A toadstool; with `glow` (a _Bulb builder) the cap and spots are on it, so they light up at night."""
    top = glow or b
    b.cyl_base((x, y, 0), 0.22 * s, 0.8 * s, stem, segments=8)
    top.cyl_base((x, y, 0.8 * s), 0.75 * s, 0.45 * s, cap, segments=10, radius2=0.2 * s)
    for k in range(3):
        a = 2 * PI * k / 3
        top.ico((x + 0.45 * s * math.cos(a), y + 0.45 * s * math.sin(a), 1.02 * s), 0.12 * s, dots, subdivisions=1)


def mushroom(mat):
    b = Builder()
    _shroom(b, 0, 0, 1.6, "bowl_red")
    _shroom(b, 1.0, -0.6, 0.9, "bowl_red")
    return [b.finalize(N + "MushroomSmall", mat)]


def mushroom_glow(mat):
    b, glow = Builder(), Builder()
    _shroom(b, 0, 0, 2.2, "sign_teal", dots="sparkle", stem="fish_belly", glow=glow)
    _shroom(b, 1.2, 0.8, 1.2, "mint", dots="sparkle", stem="fish_belly", glow=glow)
    return [b.finalize(N + "MushroomGlowing", mat), glow.finalize(N + "MushroomGlowing_Bulb", mat)]


def mushroom_ring(mat):
    b, glow = Builder(), Builder()
    b.cyl_base((0, 0, 0), 5.0, 0.05, "leaf_dark", segments=16, bevel=False)
    for k in range(9):
        a = 2 * PI * k / 9
        _shroom(b, 4.2 * math.cos(a), 4.2 * math.sin(a), 0.9 + 0.3 * (k % 3) / 2,
                ("sign_teal", "mint", "pastel_lilac")[k % 3], dots="sparkle", stem="fish_belly", glow=glow)
    return [b.finalize(N + "MushroomRing", mat), glow.finalize(N + "MushroomRing_Bulb", mat)]


def rock(mat):
    b = Builder()
    b.ico((0, 0, 0.9), 1.6, "concrete", subdivisions=1, scale=(1.3, 1.0, 0.75))
    b.ico((1.4, 0.4, 0.5), 0.8, "concrete_dark", subdivisions=1)
    b.ico((-0.2, 0, 1.75), 1.2, "leaf_green", subdivisions=1, scale=(1.2, 0.9, 0.3))
    return [b.finalize(N + "MossyRock", mat)]


def stones(mat):
    b = Builder()
    for i in range(5):
        b.cyl_base((-4 + i * 2, 0.4 * (-1) ** i, 0), 0.75, 0.45, "concrete", segments=8, scale=(1.2, 1, 1))
    return [b.finalize(N + "SteppingStones", mat)]


def bridge(mat):
    b = Builder()
    n = 11
    for i in range(n):
        t = (i - (n - 1) / 2) / ((n - 1) / 2)
        y = t * 6.0
        z = 1.6 * (1 - t * t)
        b.box((0, y, z + 0.15), (4.4, 1.1, 0.3), "caramel_wood", rot=rx(math.degrees(math.atan(-3.2 * t / 6.0))))  # along the arch
    for sx in (-1, 1):                                                                       # stringers under the planks
        for i in range(n - 1):
            t0, t1 = (i - (n - 1) / 2) / ((n - 1) / 2), (i + 1 - (n - 1) / 2) / ((n - 1) / 2)
            y0, y1, z0, z1 = t0 * 6.0, t1 * 6.0, 1.6 * (1 - t0 * t0), 1.6 * (1 - t1 * t1)
            b.box((sx * 1.4, (y0 + y1) / 2, (z0 + z1) / 2 - 0.1), (0.3, math.hypot(y1 - y0, z1 - z0) + 0.1, 0.25),
                  "dark_wood", bevel=False, rot=rx(math.degrees(math.atan2(z1 - z0, y1 - y0))))
    for sx in (-1, 1):
        for i in range(5):
            t = (i - 2) / 2
            b.box_base((sx * 2.1, t * 5.4, 1.6 * (1 - t * t) * 0.9), (0.3, 0.3, 1.8), "dark_wood")
        for i in range(4):
            t0, t1 = (i - 2) / 2, (i - 1) / 2
            y0, y1 = t0 * 5.4, t1 * 5.4
            z0, z1 = 1.6 * (1 - t0 * t0) * 0.9 + 1.7, 1.6 * (1 - t1 * t1) * 0.9 + 1.7
            b.box((sx * 2.1, (y0 + y1) / 2, (z0 + z1) / 2), (0.25, math.hypot(y1 - y0, z1 - z0) + 0.2, 0.25), "dark_wood",
                  rot=rx(math.degrees(math.atan2(z1 - z0, y1 - y0))))
    return [b.finalize(N + "WoodBridge", mat)]


def tent(mat, col="shirt_green"):
    b = Builder()
    b.fan((0, 0, 0), (0, 4.0), [(-2.8, 0), (2.8, 0)], 6.0, col, rot=rx(90))
    b.fan((0, -3.05, 0), (0, 3.3), [(-1.3, 0), (1.3, 0)], 0.1, "choco", rot=rx(90))          # door
    b.box((0.8, -3.3, 1.4), (1.4, 0.1, 2.6), "pastel_butter", rot=rz(-25), bevel=False)     # flap tied back
    for sx in (-1, 1):
        b.box((sx * 3.6, -3.5, 0.4), (0.15, 0.15, 1.0), "caramel_wood", bevel=False)
    return [b.finalize(N + "Tent", mat)]


def campfire(mat):
    b, fire = Builder(), Builder()
    for k in range(9):
        a = 2 * PI * k / 9
        b.ico((1.6 * math.cos(a), 1.6 * math.sin(a), 0.3), 0.45, "concrete", subdivisions=1, scale=(1, 1, 0.7))
    for k in range(4):
        a = PI * k / 4
        b.box((0, 0, 0.35), (2.2, 0.35, 0.35), "fur_brown", rot=Matrix.Rotation(a, 3, "Z") @ Matrix.Rotation(0.3, 3, "Y"))
    fire.cyl_base((0, 0, 0.3), 0.8, 1.6, "fur_orange", segments=6, radius2=0.05, bevel=False)    # flames
    fire.cyl_base((0.25, 0.1, 0.31), 0.45, 1.1, "pastel_butter", segments=6, radius2=0.02, bevel=False)
    fire.cyl_base((-0.3, -0.2, 0.32), 0.4, 1.0, "fur_ginger", segments=6, radius2=0.02, bevel=False)
    return [b.finalize(N + "Campfire", mat), fire.finalize(N + "Campfire_Glow", mat)]


def log_bench(mat):
    b = Builder()
    for x in (-1.6, 1.6):
        b.cyl_base((x, 0, 0), 0.6, 1.2, "fur_brown", segments=8)
    b.cyl((0, 0, 1.55), 0.55, 5.0, "fur_brown", segments=8, rot=ry(90))
    b.box((0, 0, 2.0), (4.9, 1.0, 0.12), "treat_tan", bevel=False)                           # flat sawn top
    return [b.finalize(N + "LogBench", mat)]


def treehouse(mat):
    b, win = Builder(), Builder()
    tree_round(b, 0, 0, h=20.0, r=5.0, leaf="leaf_green")
    b.box((0, 0, 9.0), (8.0, 8.0, 0.5), "caramel_wood")
    b.box_base((0, 0.5, 9.25), (5.5, 5.0, 4.0), "treat_tan")
    gable(b, 0, 0.5, 13.25, 5.5, 5.0, 2.2, "treat_tan", "bowl_red")
    b.box_base((0, -2.05, 9.25), (1.6, 0.1, 2.6), "choco", bevel=False)
    win.box((1.8, -2.05, 11.4), (1.0, 0.1, 1.0), "lamp_warm", bevel=False)
    for x in (-3.8, 3.8):
        for y in (-3.8, 3.8):
            b.box_base((x, y, 0), (0.4, 0.4, 9.0), "dark_wood")
    for i in range(12):                                                                      # rope ladder
        b.box((-1.5, -4.3, 0.6 + i * 0.7), (1.4, 0.15, 0.15), "caramel_wood", bevel=False)
    for x in (-2.2, -0.8):
        b.box((x, -4.3, 4.6), (0.08, 0.08, 9.0), "cardboard", bevel=False)
    for i in range(9):                                                                       # railing
        b.box_base((-3.8 + i * 0.95, -3.8, 9.25), (0.2, 0.2, 1.6), "caramel_wood", bevel=False)
    return [b.finalize(N + "Treehouse", mat), win.finalize(N + "Treehouse_Pane", mat)]


def tower(mat):
    b = Builder()
    for x in (-2.2, 2.2):
        for y in (-2.2, 2.2):
            b.box((x * 0.85, y * 0.85, 7.0), (0.5, 0.5, 14.2), "dark_wood",
                  rot=Matrix.Rotation(-0.06 * y / 2.2, 3, "X") @ Matrix.Rotation(0.06 * x / 2.2, 3, "Y"))
    for z in (4.5, 9.0):
        for s in (-1, 1):
            b.box((0, s * 2.0, z), (4.4, 0.25, 0.25), "dark_wood", bevel=False)
            b.box((s * 2.0, 0, z), (0.25, 4.4, 0.25), "dark_wood", bevel=False)
    b.box((0, 0, 14.0), (6.0, 6.0, 0.5), "caramel_wood")
    for s in (-1, 1):
        b.box((0, s * 2.9, 15.0), (6.0, 0.2, 1.4), "caramel_wood", bevel=False)
        b.box((s * 2.9, 0, 15.0), (0.2, 6.0, 1.4), "caramel_wood", bevel=False)
    for x in (-2.8, 2.8):
        for y in (-2.8, 2.8):
            b.box_base((x, y, 14.25), (0.3, 0.3, 4.0), "dark_wood")
    b.pyramid((0, 0, 18.2), 8.0, 3.0, "shirt_green")
    for i in range(18):
        b.box((0, -3.3, 0.5 + i * 0.75), (1.4, 0.2, 0.15), "caramel_wood", bevel=False)
    b.box((0.75, -3.3, 7.0), (0.15, 0.15, 14.0), "caramel_wood", bevel=False)
    b.box((-0.75, -3.3, 7.0), (0.15, 0.15, 14.0), "caramel_wood", bevel=False)
    return [b.finalize(N + "LookoutTower", mat)]


def berry(mat):
    b = Builder()
    b.ico((0, 0, 1.3), 1.6, "leaf_green", subdivisions=1, scale=(1.3, 1.1, 0.85))
    for k in range(12):
        a = 2 * PI * k / 12
        b.ico((1.75 * math.cos(a), 1.45 * math.sin(a), 1.25 + 0.4 * math.sin(2 * a)), 0.22,
              "aurora_violet" if k % 3 else "bowl_red", subdivisions=1)
    return [b.finalize(N + "BerryBush", mat)]


def leaves(mat):
    b = Builder()
    for k, sw in enumerate(("fur_orange", "fur_ginger", "pastel_butter", "fur_orange_dark", "terracotta")):
        a = 2 * PI * k / 5
        b.ico((0.7 * math.cos(a), 0.7 * math.sin(a), 0.5), 1.1, sw, subdivisions=1, scale=(1.2, 1.0, 0.5))
    b.ico((0, 0, 1.0), 1.0, "fur_orange", subdivisions=1, scale=(1.1, 1.0, 0.6))
    return [b.finalize(N + "LeafPile_Decor", mat)]                    # walk-through: strays hide inside it


def signpost(mat):
    rb = RB()
    rb.box((0, 3.5, 0), (0.4, 7.0, 0.4), "dark_wood")
    for i, (txt, ang) in enumerate((("CAMP", 15), ("OAK", -20), ("POND", 160))):
        y = 6.2 - i * 1.3
        w = common.text_width(txt, 0.16) + 1.0
        rot = Matrix.Rotation(math.radians(ang), 3, "Y")
        c = rot @ Vector((w / 2 - 0.2, 0, -0.25))
        rb.box((c.x, y, c.z), (w, 0.9, 0.2), "caramel_wood", rot=rot)
    return [rb.finalize(N + "Signpost", mat)]


def lantern(mat):
    b, bulb = Builder(), Builder()
    b.box_base((0, 0, 0), (0.35, 0.35, 6.0), "dark_wood")
    b.box((0.8, 0, 5.9), (1.8, 0.25, 0.25), "dark_wood", bevel=False)
    b.box((1.5, 0, 5.4), (0.05, 0.05, 0.8), "metal", bevel=False)
    bulb.box((1.5, 0, 4.7), (0.7, 0.7, 0.9), "lamp_warm", bevel=False)
    b.pyramid((1.5, 0, 5.15), 0.95, 0.4, "fur_black")
    b.box((1.5, 0, 4.2), (0.85, 0.85, 0.12), "fur_black", bevel=False)
    return [b.finalize(N + "Lantern", mat), bulb.finalize(N + "Lantern_Bulb", mat)]


def waterfall(mat):
    b = Builder()
    for k in range(12):                                                                      # rock rim of the pond
        a = 2 * PI * k / 12
        b.ico((5.0 * math.cos(a), 4.0 * math.sin(a) - 1, 0.4), 0.9, "concrete", subdivisions=1, scale=(1.2, 1, 0.6))
    b.cyl_base((0, -1, 0.05), 4.6, 0.3, "fish_blue", segments=16, scale=(1, 0.8, 1), bevel=False)
    for (x, y, z, r) in ((-3, 4, 3.0, 3.0), (3, 4, 3.5, 3.2), (0, 5, 5.5, 3.4), (-5, 3, 1.6, 2.0), (5, 3, 2.0, 2.2)):
        b.ico((x, y, z), r, "concrete", subdivisions=1)
    b.ico((-2, 4.5, 6.0), 2.0, "leaf_green", subdivisions=1, scale=(1.4, 1, 0.5))
    b.box((0, 2.2, 3.4), (2.2, 0.4, 6.6), "fish_blue", bevel=False)                          # the falling water
    b.box((0, 1.6, 0.45), (3.0, 1.4, 0.1), "fish_belly", bevel=False)                        # foam
    for (x, y) in ((-2.5, -2.5), (2.0, -3.0)):
        b.cyl_base((x, y, 0.36), 0.6, 0.05, "leaf_green", segments=8, bevel=False)          # lily pads
    b.cyl_base((-2.3, -2.5, 0.41), 0.15, 0.15, "blush", segments=6, bevel=False)
    return [b.finalize(N + "WaterfallPond", mat)]


# ------------------------------------------------------------------------------------------------- the set --
HALF = 60.0                     # 120 x 120 inside WorldBuilder's walls (their inner faces at +-59.5)
GATE_HALF = 19.0                # the Woods gate model is 36.2 wide (24 opening), centred on the path
BORDER_D = 3.0                  # the thicket along the walls
STREAM_Z = -36.0
OAKS = ((-40, 0), (44, -10), (-26, 36), (22, 40))


def _ground():
    """Flat pieces on the floor, in Builder (Blender) axes, so Roblox (x, z) is (-x, y) here: the clearing, the
    dirt path from the gate and the stream across it. Neighbouring slabs never share a top face."""
    g = Builder()
    g.cyl_base((0, 0, 0), 17, 0.08, "fur_sand", segments=24, bevel=False)                    # the clearing
    for i in range(9):                                                                       # the dirt path in
        t = i / 8
        g.box_base((6 * math.sin(t * 3), -17 - t * 38.5, 0), (6.0, 6.0, 0.06 + 0.006 * (i % 2)), "kibble", bevel=False,
                   rot=rz(20 * math.cos(t * 3)))
    for i in range(14):                                                                      # the stream across it
        x = -52 + i * 8
        dz = 0.006 * (i % 2)
        y = STREAM_Z + 4 * math.sin(i * 0.7)
        g.box_base((x, y, 0.02 + dz), (8.6, 7.0, 0.1), "fur_brown", bevel=False, rot=rz(14 * math.cos(i * 0.7)))
        g.box_base((x, y, 0.05 + dz), (8.4, 5.0, 0.12), "fish_blue", bevel=False, rot=rz(14 * math.cos(i * 0.7)))
        if i:                                                                                # round joints, a bit lower
            jx, jy = x - 4, STREAM_Z + 2 * (math.sin(i * 0.7) + math.sin((i - 1) * 0.7))
            g.cyl_base((jx, jy, 0.02), 3.5, 0.09, "fur_brown", segments=12, bevel=False)
            g.cyl_base((jx, jy, 0.05), 2.5, 0.11, "fish_blue", segments=12, bevel=False)
    return g


def build_set(mat):
    """Placed from the approved draft vignette (Blender x is Roblox -x, so every x here is the draft's negated)."""
    s = Set(N + "Set")
    s.put(great_oak(mat), 0, 6, 0)
    for k in (2, 3, 4):                                          # root nooks, between roots and clear of the mushrooms
        a = 2 * PI * (k + 1) / 7 - PI / 2
        s.mark("oak_nook", -6.8 * math.cos(a), 6 + 6.8 * math.sin(a))
    s.put(bridge(mat), -4.5, -36.5, 5)
    s.mark("bridge", -8.4, -36.5)                                                            # by the bridge's foot
    s.put(stones(mat), 28, -36, 80)
    s.put(campfire(mat), 20, -6, 0)
    for (x, z, r, col) in ((28, 4, 50, "shirt_green"), (31, -15, -25, "fur_orange")):
        s.put(tent(mat, col), x, z, r)
        s.mark("tent", *_off(x, z, r, 0, -4.8))                                              # in the doorway
    s.put(log_bench(mat), 15, -12, 60)
    s.put(log_bench(mat), 20, -1, -30)
    s.put(mushroom_ring(mat), -18, -10, 0)
    s.mark("mushroom_ring", -18, -10, y=0.05)
    s.put(treehouse(mat), -30, 16, -30)
    s.mark("treehouse", *_off(-30, 16, -30, -2.0, 2.0))                                      # between the trunk and legs
    s.put(tower(mat), 38, 28, 20)
    s.mark("tower", 38, 28)                                                                  # between the legs
    s.put(waterfall(mat), -34, -22, -60)
    s.put(hollow_log(mat), -14, 22, 30)
    s.mark("trap_hollow_log", -14, 22)
    s.put(bramble(mat), 14, 22, 0)
    s.mark("trap_bramble_bush", 14, 22)
    s.put(signpost(mat), -7, -24, -20)
    s.put(lantern(mat), 6, -18, 0)
    s.put(lantern(mat), -9, -14, 180)
    for (x, z, fn, label, y) in ((10, -26, fern, "fern", 0.0), (-12, -28, fern, "fern", 0.0),
                                 (17, 14, berry, "berry_bush", 0.0), (-20, 4, rock, "rock", 2.0), (6, 18, stump, "stump", 1.66),
                                 (-12, -3, leaves, "leaf_pile", 0.0), (12, 8, mushroom, None, 0.0),
                                 (-24, -32, rock, "rock", 2.0), (20, -28, fallen_log, "log", 0.0)):
        s.put(fn(mat), x, z, (-x * 7) % 90)
        if label == "log":
            s.mark(label, *_off(x, z, (-x * 7) % 90, 0, -2.6))                               # along its side
        elif label == "berry_bush":
            s.mark(label, x, z - 4.4)                                                        # in front of it
        elif label:
            s.mark(label, x, z, y=y)
    # a ring of pines kept inside the walls, oaks between, and a thicket along the walls
    for k in range(18):
        a = 2 * PI * k / 18 + 0.2
        r = 48 + 6 * ((k * 5) % 3)
        x, z = -r * math.cos(a), r * math.sin(a)
        if z < -30 and abs(x) < 24:                                                          # the way in stays open
            continue
        x, z = max(-HALF + 8, min(HALF - 8, x)), max(-HALF + 8, min(HALF - 8, z))
        if min(math.hypot(x - ox, z - oz) for ox, oz in OAKS) < 10:                       # an oak stands there
            continue
        s.put(pine(mat, h=16 + 4 * (k % 3)), x, z, 0)
    for (x, z) in ((-50, -50), (50, -50), (-50, 50), (50, 50), (-30, -50), (34, -52)):       # the corners filled
        s.put(pine(mat, h=18 + 2 * ((x + z) % 3)), x, z, 0)
    for (x, z) in OAKS:
        s.put(oak(mat), x, z, 30)
    tb = Builder()

    def thicket_run(a0, a1, at, along_x):
        n = max(1, round(abs(a1 - a0) / 8.0))
        step = (a1 - a0) / n
        for i in range(n):
            c, h = a0 + (i + 0.5) * step, 6.6 + 0.6 * (i % 3)
            sw = ("leaf_dark", "leaf_green", "leaf_dark")[i % 3]
            bx, by = (-c, at) if along_x else (-at, c)
            sx, sy = (abs(step), BORDER_D) if along_x else (BORDER_D, abs(step))
            tb.box_base((bx, by, 0), (sx, sy, h), sw, bevel=False)
            m = min(sx, sy)
            tb.ico((bx, by, h), m * 0.75, sw, subdivisions=1, scale=(sx / m * 0.6, sy / m * 0.6, 0.5))

    inner = HALF - 0.5
    mid = inner - BORDER_D / 2
    thicket_run(-inner, inner, mid, True)                                                    # far wall
    for sx in (-1, 1):
        thicket_run(-inner, inner - BORDER_D, sx * mid, False)                               # side walls
        # the town side (town-layout-v3.md 7d: see-through, the wall behind is invisible): low bushes with gaps
        n = 5
        step = (inner - GATE_HALF) / n
        for i in range(n):
            c = sx * (GATE_HALF + (i + 0.5) * step)
            tb.ico((-c, -mid, 1.2), 1.0, ("leaf_dark", "leaf_green")[i % 2], subdivisions=1,
                   scale=((step - 2.0) / 2, BORDER_D * 0.45, 1.6))
    s.put([tb.finalize(N + "Thicket", mat)], 0, 0, 0)
    return s.finish(_ground(), mat), s


def _off(x, z, rot, lx, lz):
    from areakit import turned
    return turned(x, z, rot, lx, lz)


def build_woods_set(mat):
    objs, _ = build_set(mat)
    return objs


ASSETS = {
    "CatCafe_Woods_Set": (build_woods_set, 80000),
}
