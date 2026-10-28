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
from areakit import PI, Set, gable, rx, ry, rz, tree_round, window
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


OAK_H, OAK_R0, OAK_R1, OAK_T = 26.0, 5.0, 3.4, 0.9   # the Great Oak's trunk: height, radius foot and top, wall
NOOK_Z = 18.0                                         # the floor of the nook at the top inside it
OAK_ROOTS = (-35, 30, 90, 150, -145)                  # degrees from +x (Blender), none in front of the doorway
OAK_NOOKS = (60, 120, 182)                            # root nooks between them, where strays sit
NOOK_SPOTS = ((-1.6, -0.6, 0.0), (1.6, -0.6, 0.0), (0.0, -1.8, 0.3))   # Blender x, y on the nook floor, height


def _oak_r(z):
    return OAK_R0 + (OAK_R1 - OAK_R0) * z / OAK_H


def great_oak(mat):
    """The clearing's landmark (Derek 2026-10-28: "have the main big tree entrance actually work"): a hollow trunk
    of six rings of wall blocks with a doorway at the front, a ladder up the inside (an invisible truss behind its
    rungs, so it climbs) to a nook at the top with two lit windows, where the rarer strays turn up."""
    b, win, bulb, climb = Builder(), Builder(), Builder(), Builder()
    levels, seg = 6, 16
    hz = OAK_H / levels
    door = (11, 12)                                                  # the two blocks either side of straight ahead
    for i in range(levels):
        z0 = i * hz
        r_out = _oak_r(z0 + hz / 2)
        rm = r_out - OAK_T / 2
        chord = 2 * r_out * math.sin(PI / seg) * 1.04
        for k in range(seg):
            a = 2 * PI * (k + 0.5) / seg
            e = 0.006 * (k % 2)                                      # neighbours never share a top or bottom face
            spans = [(z0 - e, z0 + hz + e)]
            if k in door and i == 0:
                spans = []
            elif k in door and i == 1:
                spans = [(6.2, z0 + hz + e)]                         # the lintel over the doorway
            elif k in door and i == 4:
                spans = [(z0 - e, 19.3), (21.3, z0 + hz + e)]       # the front window
            elif k == 8 and i == 4:
                spans = [(z0 - e, 19.3), (21.3, z0 + hz + e)]       # the side window
            for (za, zb) in spans:
                b.box((rm * math.cos(a), rm * math.sin(a), (za + zb) / 2), (OAK_T, chord, zb - za), "fur_brown",
                      rot=(a, "Z"))
            if i == 4 and (k in door or k == 8):                     # the pane fills the gap, inside the wall
                win.box((rm * math.cos(a), rm * math.sin(a), 20.3), (OAK_T * 0.5, chord, 2.0), "lamp_warm",
                        bevel=False, rot=(a, "Z"))
                b.box(((r_out + 0.31) * math.cos(a), (r_out + 0.31) * math.sin(a), 19.2), (0.6, chord, 0.2),
                      "caramel_wood", bevel=False, rot=(a, "Z"))           # sill, against the wall face
    # the doorway's frame: dark wood jambs against the wall ends either side, a head under each lintel block
    for i, k, s_ in ((0, 10, 1), (0, 13, -1), (1, 11, 1), (1, 12, -1)):     # s_: the side facing the doorway
        r_out = _oak_r(i * hz + hz / 2)
        half = r_out * math.sin(PI / seg) * 1.04                     # half a wall block, along the wall
        a = 2 * PI * (k + 0.5) / seg
        if i == 0:                                                   # a jamb past the block's end, 6.2 tall
            ta, tb, z, h = s_ * (half + 0.01), s_ * (half + 0.51), 0.0, 6.2
        else:                                                        # a head under the lintel, clear of the jamb
            ta, tb, z, h = -0.2 * s_, half * s_, 5.7, 0.5
        tc, rm = (ta + tb) / 2, r_out - OAK_T / 2
        cx, cy = rm * math.cos(a) - tc * math.sin(a), rm * math.sin(a) + tc * math.cos(a)
        b.box_base((cx, cy, z), (OAK_T + 0.2, abs(tb - ta), h), "dark_wood", bevel=False, rot=(a, "Z"))
    # the ladder up the inside, against the back wall, and the nook floor round its top
    for x in (-0.8, 0.8):
        b.box_base((x, 0.6, 0), (0.2, 0.2, NOOK_Z + 1.0), "caramel_wood", bevel=False)
    for n in range(18):
        b.box((0, 0.6, 0.8 + n * 1.0), (1.6, 0.2, 0.2), "caramel_wood", bevel=False)
    climb.box_base((0, 1.7, 0), (2.0, 2.0, NOOK_Z), "caramel_wood", bevel=False)
    f0, R = NOOK_Z - 0.4, 3.2
    b.box_base((0, (-R + 0.5) / 2, f0), (2 * R, R + 0.5, 0.4), "caramel_wood")       # in front of the ladder
    for s_ in (-1, 1):
        b.box_base((s_ * (1.1 + R) / 2, (0.5 + R) / 2, f0), (R - 1.1, R - 0.5, 0.4), "caramel_wood")
    b.cyl_base((0, 0, 23.6), _oak_r(23.6) - 0.4, 0.4, "dark_wood", segments=12, bevel=False)   # the nook's ceiling
    b.cyl_base((0.0, -1.8, NOOK_Z), 0.8, 0.3, "blush", segments=10, bevel=False)       # a cushion in the nook
    bulb.box((-_oak_r(4.0) + OAK_T + 0.25, 0, 4.0), (0.4, 0.5, 0.6), "lamp_warm", bevel=False)   # a lamp inside
    b.box((-_oak_r(4.0) + OAK_T + 0.1, 0, 4.4), (0.2, 0.2, 0.2), "fur_black", bevel=False)
    for d in OAK_ROOTS:                                                                  # roots
        a = math.radians(d)
        b.box((6.0 * math.cos(a), 6.0 * math.sin(a), 1.0), (5.0, 1.8, 2.4), "fur_brown", rot=(a, "Z"))
    for (x, y, z, r, sw) in ((0, 0, 34, 9.5, "leaf_green"), (9.5, 2, 29, 6.0, "leaf_dark"),
                             (-9.5, -1, 30, 6.5, "leaf_green"), (2, 9, 29, 6.0, "leaf_dark"),
                             (-2, -9, 28, 5.5, "leaf_dark")):                            # the crown, clear of the nook
        b.ico((x, y, z), r, sw, subdivisions=1)
    for (x, z) in ((-6.2, 15.5), (6.2, 20)):                                           # big branches
        b.box((x, 0, z), (6, 1.6, 1.6), "fur_brown", rot=ry(25 if x > 0 else -25))
    for d in (-15, -2, 11):                                                              # mushrooms at the foot
        a = math.radians(d)
        b.cyl_base((5.4 * math.cos(a), 5.4 * math.sin(a), 0), 0.25, 0.6, "offwhite", segments=6)
        b.cyl_base((5.4 * math.cos(a), 5.4 * math.sin(a), 0.6), 0.6, 0.35, "bowl_red", segments=8, radius2=0.1)
    return [b.finalize(N + "GreatOak", mat), win.finalize(N + "GreatOak_Pane", mat),
            bulb.finalize(N + "GreatOak_Bulb", mat), climb.finalize(N + "GreatOak_Climb", mat)]


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
    """A toadstool; with `glow` (a _Bulb builder) its spots are on it, so they light up at night."""
    top = glow or b                                       # only the spots glow (Derek 2026-10-28: "lower the glow")
    b.cyl_base((x, y, 0), 0.22 * s, 0.8 * s, stem, segments=8)
    b.cyl_base((x, y, 0.8 * s), 0.75 * s, 0.45 * s, cap, segments=10, radius2=0.2 * s)
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


DECK = 10.0                     # the tree house deck's top


def treehouse(mat):
    """A tree house you can walk into (Derek 2026-10-28: fix its collisions, a climbable ladder, a stuck cat up
    the tree): a ladder at the front (rungs a stud apart, an invisible truss behind them) up to a 10 x 10 deck,
    railed round with a gap at the ladder, a cabin on it with a doorway and windows, the trunk behind the cabin,
    and a branch out over the deck's back corner where a stray gets stuck."""
    b, win, climb = Builder(), Builder(), Builder()
    D = DECK
    b.cyl_base((0, 4.6, 0), 1.0, 24.0, "fur_brown", segments=10, radius2=0.7)                # the trunk
    for (x, y, z, r) in ((0, 4.2, 24.0, 5.5), (3.8, 3.2, 21.5, 3.6), (-4.0, 5.2, 22.0, 3.8)):
        b.ico((x, y, z), r, "leaf_green", subdivisions=1)
    b.cyl((3.6, 4.4, 15.0), 0.45, 5.6, "fur_brown", segments=8, rot=ry(90))              # the branch
    b.ico((6.9, 4.4, 15.6), 1.3, "leaf_dark", subdivisions=1)
    b.box((0, 0, D - 0.25), (10.0, 10.0, 0.5), "caramel_wood")                           # the deck
    for x in (-4.6, 4.6):
        for y in (-4.6, 4.6):
            b.box_base((x, y, 0), (0.5, 0.5, D - 0.5), "dark_wood")
    for x in (-4.6, 4.6):                                                                # braces under the deck
        b.box((x, 0, D - 1.2), (0.3, 9.0, 0.3), "dark_wood", bevel=False)
    x0, x1, y0, y1, t, h = -3.5, 3.5, -2.4, 3.4, 0.4, 6.5                               # the cabin
    b.box_base((0, y1 - t / 2, D), (x1 - x0, t, h), "treat_tan")
    for s_ in (-1, 1):
        b.box_base((s_ * (x1 - t / 2), (y0 + y1) / 2, D), (t, y1 - y0, h), "treat_tan")
        b.box_base((s_ * (x1 + 1.5) / 2, y0 + t / 2, D), (x1 - 1.5, t, h), "treat_tan")  # front, either side of
    b.box_base((0, y0 + t / 2, D + 5.6), (3.0, t, h - 5.6), "treat_tan")                 # the doorway (3 x 5.6)
    for s_ in (-1, 1):                                                                   # its frame
        b.box_base((s_ * 1.6, y0 - 0.15, D), (0.25, 0.3, 5.75), "choco", bevel=False)
    b.box_base((0, y0 - 0.15, D + 5.6), (3.45, 0.3, 0.25), "choco", bevel=False)
    for s_ in (-1, 1):
        window(b, win, s_ * 2.5, y0, D + 3.4, 1.0, 1.2, frame="choco", cross=False)
    gable(b, 0, (y0 + y1) / 2, D + h, x1 - x0 + 0.2, y1 - y0, 2.6, "treat_tan", "bowl_red")
    b.cyl_base((1.8, 1.8, D), 0.9, 0.3, "blush", segments=10, bevel=False)              # a cushion inside
    rail = 3.0                                                                           # railing round the deck
    for (xa, xb, ya, yb) in ((-5.0, -4.05, -5.0, -4.8), (-1.95, 5.0, -5.0, -4.8),        # front, a gap at the ladder
                             (-5.0, -1.1, 4.8, 5.0), (1.1, 5.0, 4.8, 5.0),                # back, round the trunk
                             (-5.0, -4.8, -5.0, 5.0), (4.8, 5.0, -5.0, 5.0)):              # sides
        b.box_base(((xa + xb) / 2, (ya + yb) / 2, D + rail - 0.2), (xb - xa, yb - ya + 0.04, 0.2), "dark_wood",
                   bevel=False)
        L = max(xb - xa, yb - ya)
        n = max(1, round(L / 1.2))
        for q in range(n + 1):
            f = q / n
            px, py = xa + (xb - xa) * f, ya + (yb - ya) * f
            px, py = min(max(px, xa + 0.1), xb - 0.1), min(max(py, ya + 0.1), yb - 0.1)
            b.box_base((px, py, D), (0.2, 0.2, rail - 0.2), "caramel_wood", bevel=False)
    for x in (-3.8, -2.2):                                                               # the ladder
        b.box_base((x, -5.3, 0), (0.2, 0.2, D + 1.2), "dark_wood", bevel=False)
    for n_ in range(10):
        b.box((-3.0, -5.3, 0.8 + n_ * 1.0), (1.4, 0.2, 0.2), "caramel_wood", bevel=False)
    climb.box_base((-3.0, -4.3, 0), (2.0, 2.0, D), "caramel_wood", bevel=False)
    return [b.finalize(N + "Treehouse", mat), win.finalize(N + "Treehouse_Pane", mat),
            climb.finalize(N + "Treehouse_Climb", mat)]


TOWER_TOP = 14.0


def tower(mat):
    b, climb = Builder(), Builder()
    T = TOWER_TOP
    for x in (-2.2, 2.2):
        for y in (-2.2, 2.2):
            b.box((x * 0.85, y * 0.85, 7.0), (0.5, 0.5, 14.2), "dark_wood",
                  rot=Matrix.Rotation(-0.06 * y / 2.2, 3, "X") @ Matrix.Rotation(0.06 * x / 2.2, 3, "Y"))
    for z in (4.5, 9.0):
        for s in (-1, 1):
            b.box((0, s * 2.0, z), (4.4, 0.25, 0.25), "dark_wood", bevel=False)
            b.box((s * 2.0, 0, z), (0.25, 4.4, 0.25), "dark_wood", bevel=False)
    b.box((0, 0, T - 0.25), (6.0, 6.0, 0.5), "caramel_wood")
    # railing 3 high (design 8): a kick board, balusters and a top rail, a gap at the ladder
    for (xa, xb, ya, yb) in ((-2.65, -1.1, -3.0, -2.8), (1.1, 2.65, -3.0, -2.8), (-2.65, 2.65, 2.8, 3.0),
                             (-3.0, -2.8, -2.65, 2.65), (2.8, 3.0, -2.65, 2.65)):
        cx, cy, lx, ly = (xa + xb) / 2, (ya + yb) / 2, xb - xa, yb - ya
        b.box_base((cx, cy, T), (lx, ly, 0.5), "caramel_wood", bevel=False)
        b.box_base((cx, cy, T + 2.75), (lx, ly, 0.25), "caramel_wood", bevel=False)
        L = max(lx, ly)
        n = max(1, round(L / 0.8))
        for q in range(1, n):
            f = q / n
            px, py = (xa + lx * f, cy) if lx > ly else (cx, ya + ly * f)
            b.box_base((px, py, T + 0.5), (0.18, 0.18, 2.25), "caramel_wood", bevel=False)
    for x in (-2.8, 2.8):
        for y in (-2.8, 2.8):
            b.box_base((x, y, T), (0.3, 0.3, 4.0), "dark_wood")
    b.pyramid((0, 0, T + 3.95), 8.0, 3.0, "shirt_green")
    for i in range(18):
        b.box((0, -3.3, 0.5 + i * 0.75), (1.4, 0.2, 0.15), "caramel_wood", bevel=False)
    b.box((0.75, -3.3, 7.0), (0.15, 0.15, 14.0), "caramel_wood", bevel=False)
    b.box((-0.75, -3.3, 7.0), (0.15, 0.15, 14.0), "caramel_wood", bevel=False)
    climb.box_base((0, -2.3, 0), (2.0, 2.0, T), "caramel_wood", bevel=False)
    return [b.finalize(N + "LookoutTower", mat), climb.finalize(N + "LookoutTower_Climb", mat)]


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
    b, water = Builder(), Builder()
    for k in range(12):                                                                      # rock rim of the pond
        a = 2 * PI * k / 12
        b.ico((5.0 * math.cos(a), 4.0 * math.sin(a) - 1, 0.4), 0.9, "concrete", subdivisions=1, scale=(1.2, 1, 0.6))
    water.cyl_base((0, -1, 0.05), 4.6, 0.3, "fish_blue", segments=16, scale=(1, 0.8, 1), bevel=False)
    for (x, y, z, r) in ((-3, 4, 3.0, 3.0), (3, 4, 3.5, 3.2), (0, 5, 5.5, 3.4), (-5, 3, 1.6, 2.0), (5, 3, 2.0, 2.2)):
        b.ico((x, y, z), r, "concrete", subdivisions=1)
    b.ico((-2, 4.5, 6.0), 2.0, "leaf_green", subdivisions=1, scale=(1.4, 1, 0.5))
    water.box((0, 2.2, 3.4), (2.2, 0.4, 6.6), "fish_blue", bevel=False)                      # the falling water
    b.box((0, 1.6, 0.45), (3.0, 1.4, 0.1), "fish_belly", bevel=False)                        # foam
    for (x, y) in ((-2.5, -2.5), (2.0, -3.0)):
        b.cyl_base((x, y, 0.36), 0.6, 0.05, "leaf_green", segments=8, bevel=False)          # lily pads
    b.cyl_base((-2.3, -2.5, 0.41), 0.15, 0.15, "blush", segments=6, bevel=False)
    return [b.finalize(N + "WaterfallPond", mat), water.finalize(N + "WaterfallPond_Water", mat)]   # _Water: splashes


# ------------------------------------------------------------------------------------------------- the set --
HALF = 60.0                     # 120 x 120 inside WorldBuilder's walls (their inner faces at +-59.5)
GATE_HALF = 19.0                # the Woods gate model is 36.2 wide (24 opening), centred on the path
BORDER_D = 3.0                  # the thicket along the walls
STREAM_Z = -36.0
OAKS = ((-40, 0), (44, -10), (-26, 36), (22, 40))


def _ground():
    """Flat pieces on the floor, in Builder (Blender) axes, so Roblox (x, z) is (-x, y) here: the clearing, the
    dirt path from the gate and the stream across it. Neighbouring slabs never share a top face."""
    g, water = Builder(), Builder()
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
        water.box_base((x, y, 0.05 + dz), (8.4, 5.0, 0.12), "fish_blue", bevel=False, rot=rz(14 * math.cos(i * 0.7)))
        if i:                                                                                # round joints, a bit lower
            jx, jy = x - 4, STREAM_Z + 2 * (math.sin(i * 0.7) + math.sin((i - 1) * 0.7))
            g.cyl_base((jx, jy, 0.02), 3.5, 0.09, "fur_brown", segments=12, bevel=False)
            water.cyl_base((jx, jy, 0.05), 2.5, 0.11, "fish_blue", segments=12, bevel=False)
    return g, water


def build_set(mat):
    """Placed from the approved draft vignette (Blender x is Roblox -x, so every x here is the draft's negated)."""
    s = Set(N + "Set")
    s.put(great_oak(mat), 0, 6, 0)
    for d in OAK_NOOKS:                                          # root nooks, between roots and clear of the mushrooms
        a = math.radians(d)
        s.mark("oak_nook", -6.8 * math.cos(a), 6 + 6.8 * math.sin(a))
    for (bx, by, up) in NOOK_SPOTS:                              # up in the nook: Gameplay weights rarer strays here
        s.mark("nook_great_oak", -bx, 6 + by, y=NOOK_Z + up)
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
    s.mark("treehouse", *_off(-30, 16, -30, -1.8, 1.8), y=DECK + 0.3)                        # on the cushion inside
    s.mark("trap_treehouse_branch", *_off(-30, 16, -30, -4.9, 4.4), y=15.45)                # stuck up the tree
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
    ground, water = _ground()
    s.put([water.finalize(N + "Stream_Water", mat)], 0, 0, 0)                               # _Water: splashes
    return s.finish(ground, mat), s


def _off(x, z, rot, lx, lz):
    from areakit import turned
    return turned(x, z, rot, lx, lz)


def build_woods_set(mat):
    objs, _ = build_set(mat)
    return objs


ASSETS = {
    "CatCafe_Woods_Set": (build_woods_set, 80000),
}
