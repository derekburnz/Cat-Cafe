"""The Sewer kit (areas-and-stations.md A4; draft sheets approved by Derek 2026-10-27, the junk town after his 15:47
note): the hidden canal town. Brick walls 16 high with tunnel arches, a round pool under the big pipe waterfall, the
main canal from the pool toward the gate with a catwalk over it, a narrow branch with a bathtub boat, and the junk
town round the pool: market stalls, can, box and teapot houses, a lounge, crate decks and wall pieces.

  CatCafe_Sewer_Set   the whole area dressed, in area space (areakit), gate side -Z: place it at the area's centre
                      on its floor, turned so -Z faces the gate. 90 x 90 of floor inside WorldBuilder's walls; its
                      own brick walls wrap those walls (93.2 outside), and on the gate side it has a low wall with a
                      railing so the town can see in (town-layout-v3.md 7d).

The pieces inside it are built here too (TunnelArch, Catwalk, PipeLarge, PipeElbow, PipeOutlet, ValveWheel, Grate,
DrainPipe, MaintenanceCart, Rails, LostToyPile, BottlecapThrone, GlowMushrooms, WallLantern, PawGraffiti,
DripPuddle, JunkStall, CanHouse, BoxHouse, TeapotHouse, CapBunting, LostLounge, CrateDeck, BathtubBoat, RubberDucks,
CrateRaft, PipeOrgan, WallFan, SteamVent, SockLine, Barrel, TyreStack, TrafficCone, SuitcaseStack, YarnTrolley,
PipeHammock). Wall lanterns and the lounge lamp are _Bulb parts (lit at night), glowing mushrooms and the pool's
glow moss _Glow (lit all day); the toy heap is walk-through (_Decor) so strays can hide in it.

Positions below are the draft's (Blender axes: Roblox x is -x here); `put` and `spot` turn them into area space.
"""

import math

from mathutils import Matrix

import alleyway
from areakit import PI, Set, ring_blocks, rx, ry, rz
from common import Builder

N = "CatCafe_Sewer_"
CAPS = ("bowl_red", "rarity_legend", "fish_blue", "mint", "neon_pink", "offwhite")
FLOOR = 0.4                     # the tiled floor slab's top; everything stands on it
INNER = 44.4                    # the brick walls' inner faces, just inside WorldBuilder's (44.5)
WALL_T, WALL_H = 2.2, 16.0      # thick enough to wrap WorldBuilder's 1 stud walls (44.5 to 45.5)
GATE_HALF = 16.0                # clear of the Sewer gate model (31.1 wide, 24 opening)


def _arch(b, w, h, depth, y, sw="brick", n=9, thick=1.0):
    """A round arch of n blocks over an opening w wide whose sides are h tall, `depth` deep (along y)."""
    r = w / 2 + thick / 2
    for k in range(n):
        a = PI * (k + 0.5) / n
        L = 2 * r * math.sin(PI / n / 2) * 2 * 1.05
        key = k == n // 2                                                                   # the keystone stands proud
        b.box((r * math.cos(a), y, h + r * math.sin(a)), (L, depth + 0.06 * key, thick), "concrete" if key else sw,
              rot=ry(-math.degrees(a) + 90))


def _shroom(b, x, y, s, cap, dots="offwhite", stem="offwhite", glow=None):
    top = glow or b
    b.cyl_base((x, y, 0), 0.22 * s, 0.8 * s, stem, segments=8)
    top.cyl_base((x, y, 0.8 * s), 0.75 * s, 0.45 * s, cap, segments=10, radius2=0.2 * s)
    for k in range(3):
        a = 2 * PI * k / 3
        top.ico((x + 0.45 * s * math.cos(a), y + 0.45 * s * math.sin(a), 1.02 * s), 0.12 * s, dots, subdivisions=1)


def _crate(b, x, y, z, s=2.0, sw="caramel_wood"):
    b.box_base((x, y, z), (s, s, s), sw)
    for d in (-1, 1):
        b.box((x, y - s / 2 - 0.02, z + s / 2 + d * s * 0.3), (s * 0.9, 0.05, 0.15), "dark_wood", bevel=False)


def _cap(b, x, y, z, r, sw, rot=None):
    b.cyl((x, y, z), r, r * 0.35, sw, segments=12, rot=rot)


# ------------------------------------------------------------------------------------------- the pieces --
def tunnel_arch(mat):
    b, lamp = Builder(), Builder()
    for sx in (-1, 1):
        b.box_base((sx * 5.5, 0, 0), (2.0, 1.6, 7.0), "brick")
    _arch(b, 9.0, 7.0, 1.6, 0)
    b.box((0, -0.9, 12.3), (2.2, 0.2, 1.0), "sign_teal", bevel=False)                        # a little sign
    lamp.box((4.3, -1.2, 5.6), (0.6, 0.6, 0.9), "lamp_warm", bevel=False)
    b.box((4.6, -0.9, 5.6), (0.6, 0.4, 0.2), "fur_black", bevel=False)
    return [b.finalize(N + "TunnelArch", mat), lamp.finalize(N + "TunnelArch_Bulb", mat)]


def catwalk(mat):
    b = Builder()
    b.box((0, 0, 3.0), (3.0, 12.0, 0.2), "metal", bevel=False)
    for i in range(13):
        b.box((0, -5.8 + i * 0.97, 3.12), (2.9, 0.08, 0.05), "concrete_dark", bevel=False)  # grating
    for sx in (-1, 1):
        for y in (-5.6, 0, 5.6):
            b.box_base((sx * 1.4, y, 0), (0.25, 0.25, 4.6), "rust" if y == 0 else "metal", bevel=False)
        b.box((sx * 1.4, 0, 4.6), (0.15, 12.0, 0.15), "rarity_legend", bevel=False)
        b.box((sx * 1.4, 0, 3.8), (0.1, 12.0, 0.1), "metal", bevel=False)
    return [b.finalize(N + "Catwalk", mat)]


def pipe_large(mat):
    b = Builder()
    b.cyl((0, 0, 2.2), 1.8, 12.0, "dumpster_green", segments=12, rot=ry(90))
    for x in (-5.7, 0, 5.7):
        b.cyl((x, 0, 2.2), 2.05, 0.4, "metal", segments=12, rot=ry(90))
        for k in range(6):
            a = 2 * PI * k / 6
            b.box((x, 2.0 * math.cos(a), 2.2 + 2.0 * math.sin(a)), (0.5, 0.2, 0.2), "rust", bevel=False)
    for x in (-6.05, 6.05):                                                                  # the dark open ends
        b.cyl((x, 0, 2.2), 1.4, 0.1, "fur_black", segments=12, rot=ry(90), bevel=False)
    for x in (-4, 4):
        b.box_base((x, 0, 0), (1.0, 3.0, 0.5), "concrete_dark")
    return [b.finalize(N + "PipeLarge", mat)]


def pipe_elbow(mat):
    b = Builder()
    b.cyl((0, 0, 1.5), 1.2, 5.0, "dumpster_green", segments=10, rot=ry(90), bevel=False)
    b.box((2.9, 0, 2.6), (2.0, 2.4, 3.4), "dumpster_green")
    b.cyl_base((2.9, 0, 2.6), 1.2, 6.0, "dumpster_green", segments=10)
    for (x, z, rot) in ((-2.5, 1.5, ry(90)), (2.9, 8.4, None)):
        b.cyl((x, 0, z), 1.45, 0.35, "metal", segments=10, rot=rot)
    return [b.finalize(N + "PipeElbow", mat)]


def pipe_outlet(mat, s=1.6):
    """The big pipe pouring into the hub pool, at 1.6 times the draft piece."""
    b, glow = Builder(), Builder()
    b.box_base((0, 1.5 * s, 0), (10.0 * s, 2.0 * s, 12.0 * s), "brick")
    b.cyl((0, -0.3 * s, 8.0 * s), 2.2 * s, 2.2 * s, "metal", segments=12, rot=rx(90))
    b.cyl((0, -1.45 * s, 8.0 * s), 1.7 * s, 0.2 * s, "choco", segments=12, rot=rx(90), bevel=False)
    b.box((0, -2.0 * s, 4.6 * s), (2.6 * s, 0.5 * s, 7.0 * s), "fish_blue", bevel=False)      # the waterfall
    b.box((0, -1.8 * s, 7.0 * s), (3.0 * s, 1.0 * s, 0.6 * s), "fish_belly", bevel=False)
    b.ico((0, -2.8 * s, 0.4), 1.0 * s, "fish_belly", subdivisions=1, scale=(1.5, 1, 0.3))     # splash
    for (x, z) in ((-3.6, 10.5), (3.8, 3.0)):
        glow.ico((x * s, 0.4 * s, z * s), 0.5 * s, "mint", subdivisions=1, scale=(1, 0.5, 1))  # glow moss
    return [b.finalize(N + "PipeOutlet", mat), glow.finalize(N + "PipeOutlet_Glow", mat)]


def valve_wheel(mat):
    b = Builder()
    b.box_base((0, 0.5, 0), (5.0, 1.0, 6.0), "brick")
    b.cyl((0, -0.6, 3.0), 0.6, 2.2, "metal", segments=10, rot=rx(90))
    b.ring((0, -1.8, 3.0), 1.6, 0.3, 0.3, "bowl_red", segments=14, rot=rx(90))
    for k in range(4):
        b.box((0, -1.8, 3.0), (3.0, 0.2, 0.2), "bowl_red", bevel=False, rot=ry(45 * k))
    b.cyl((0, -1.9, 3.0), 0.35, 0.4, "rarity_legend", segments=8, rot=rx(90))
    for (x, z) in ((-1.8, 5.2), (1.6, 5.4)):                                                 # little dials
        b.cyl((x, -0.1, z), 0.4, 0.2, "offwhite", segments=10, rot=rx(90))
        b.box((x, -0.22, z + 0.1), (0.06, 0.05, 0.3), "fur_black", bevel=False)
    return [b.finalize(N + "ValveWheel", mat)]


def grate(mat):
    b = Builder()
    b.box_base((0, 0, 0), (5.0, 5.0, 0.3), "concrete")
    b.box_base((0, 0, 0.05), (4.0, 4.0, 0.2), "fur_black", bevel=False)                     # the dark under it
    for i in range(7):
        b.box((-1.8 + i * 0.6, 0, 0.36), (0.2, 4.0, 0.15), "metal", bevel=False)
    b.box((0, 0, 0.4), (4.2, 0.25, 0.12), "metal", bevel=False)
    b.box((2.3, 0, 0.44), (0.3, 1.2, 0.3), "rust", bevel=False)                               # lift handle
    return [b.finalize(N + "Grate", mat)]


def drain_pipe(mat):
    b, glow = Builder(), Builder()
    b.box_base((0, 1.0, 0), (6.0, 2.0, 6.0), "brick")
    b.cyl((1.0, -0.4, 1.2), 0.9, 2.8, "metal", segments=10, rot=rx(90))
    b.cyl((1.0, -1.8, 1.2), 1.1, 0.3, "rust", segments=10, rot=rx(90))
    b.cyl((1.0, -1.95, 1.2), 0.65, 0.1, "fur_black", segments=10, rot=rx(90), bevel=False)
    b.box((1.0, -1.6, 0.05), (1.4, 1.2, 0.08), "puddle", bevel=False)
    glow.ico((-1.6, -0.1, 4.5), 0.5, "mint", subdivisions=1, scale=(1, 0.5, 1))
    return [b.finalize(N + "DrainPipe", mat), glow.finalize(N + "DrainPipe_Glow", mat)]


def cart(mat):
    """The cart alone; in the set it stands on the Rails piece."""
    b = Builder()
    b.box_base((0, 0, 0.9), (3.6, 2.4, 2.0), "rust")
    b.box_base((0, 0, 2.6), (3.2, 2.0, 0.4), "fur_black", bevel=False)                      # a stray rides in here
    for (x, y) in ((-1.2, -0.8), (1.2, -0.8), (-1.2, 0.8), (1.2, 0.8)):
        b.cyl((x, y, 0.75), 0.55, 0.3, "concrete_dark", segments=10, rot=rx(90))
    b.box((0, -1.25, 1.9), (1.4, 0.05, 0.5), "offwhite", bevel=False)
    return [b.finalize(N + "MaintenanceCart", mat)]


def rails(mat):
    b = Builder()
    for y in (-0.8, 0.8):
        b.box_base((0, y, 0.15), (16.0, 0.25, 0.3), "metal", bevel=False)
    for i in range(12):
        b.box_base((-7.3 + i * 1.33, 0, 0), (0.6, 2.4, 0.15), "dark_wood", bevel=False)
    b.box_base((7.4, 0, 0), (0.6, 2.6, 1.2), "rust")                                          # buffer stop
    return [b.finalize(N + "Rails", mat)]


def toy_pile(mat):
    b = Builder()
    b.ico((0, 0, 1.0), 1.4, "cardboard", subdivisions=1, scale=(1.4, 1.2, 0.7))
    b.sphere((-1.0, -0.6, 1.6), 0.7, "shirt_red", segments=10, rings=6)
    b.box((-1.0, -1.26, 1.6), (1.0, 0.05, 0.25), "offwhite", bevel=False)
    b.sphere((0.9, -0.3, 1.9), 0.6, "fur_brown", segments=8, rings=6)                          # teddy
    b.sphere((0.9, -0.3, 2.6), 0.45, "fur_brown", segments=8, rings=6)
    for x in (0.6, 1.2):
        b.sphere((x, -0.3, 3.0), 0.16, "fur_brown", segments=6, rings=4)
    b.box((0.2, 0.8, 2.0), (0.7, 0.7, 0.7), "sign_teal", rot=rz(20))
    b.box((-0.3, 0.9, 2.5), (0.6, 0.6, 0.6), "pastel_butter", rot=rz(-15))
    b.ico((1.8, 0.8, 0.6), 0.45, "pastel_butter", subdivisions=1)                             # duck
    b.box((2.2, 0.8, 0.65), (0.3, 0.15, 0.1), "fur_orange", bevel=False)
    b.box((-2.2, 0.0, 0.5), (1.4, 0.7, 0.5), "shirt_blue")                                    # toy car
    for x in (-2.6, -1.8):
        b.cyl((x, -0.36, 0.25), 0.25, 0.1, "fur_black", segments=8, rot=rx(90))
    return [b.finalize(N + "LostToyPile_Decor", mat)]                    # walk-through: strays hide inside it


def throne(mat):
    b = Builder()
    b.box_base((0, 0, 0), (6.0, 5.0, 1.6), "cardboard")                                      # crate platform
    for x in (-1.5, 1.5):
        b.box((x, -2.52, 0.8), (2.8, 0.05, 1.4), "dark_wood", bevel=False)
    for i in range(2):
        b.box_base((0, -3.0 - i * 0.7, 0), (2.4, 0.7, 1.2 - i * 0.6), "cardboard")          # steps
    b.box_base((0, 0.6, 1.6), (3.0, 2.4, 1.2), "metal")                                      # tin-can seat
    b.box_base((0, 1.6, 1.6), (3.0, 0.6, 4.2), "metal")                                      # back
    for k in range(5):                                                                        # bottle cap crest
        a = PI * (k + 0.5) / 5
        b.cyl((1.4 * math.cos(a), 1.5 + 0.04 * (k % 2), 5.8 + 1.0 * math.sin(a)), 0.45, 0.15, CAPS[k], segments=10,
              rot=rx(90))
    for sx in (-1, 1):
        b.cyl_base((sx * 1.7, 0.6, 1.6), 0.45, 1.6, "rust", segments=8)                      # can armrests
        b.cyl((sx * 1.7, 0.6, 3.25), 0.5, 0.1, "rarity_legend", segments=10)
    b.box((0, 0.4, 2.85), (2.4, 1.8, 0.1), "shirt_red", bevel=False)                         # a cushion
    return [b.finalize(N + "BottlecapThrone", mat)]


def glow_mushrooms(mat):
    b, glow = Builder(), Builder()
    for (x, y, s_, cap) in ((0, 0, 1.4, "mint"), (0.9, 0.5, 0.9, "sign_teal"), (-0.8, 0.3, 1.0, "aurora_violet"),
                            (0.3, -0.7, 0.7, "mint")):
        _shroom(b, x, y, s_, cap, dots="sparkle", stem="fish_belly", glow=glow)
    return [b.finalize(N + "GlowMushrooms", mat), glow.finalize(N + "GlowMushrooms_Glow", mat)]


def wall_lantern(mat):
    b, bulb = Builder(), Builder()
    b.box_base((0, 0.3, 0), (2.0, 0.6, 2.0), "brick")
    b.box((0, -0.3, 1.3), (0.2, 0.9, 0.2), "fur_black", bevel=False)
    bulb.box((0, -0.8, 0.94), (0.7, 0.7, 0.88), "lamp_warm", bevel=False)
    b.pyramid((0, -0.8, 1.4), 0.95, 0.4, "fur_black")
    b.box((0, -0.8, 0.45), (0.85, 0.85, 0.12), "fur_black", bevel=False)
    return [b.finalize(N + "WallLantern", mat), bulb.finalize(N + "WallLantern_Bulb", mat)]


def graffiti(mat):
    b = Builder()
    b.box_base((0, 0.5, 0), (8.0, 1.0, 6.0), "brick")
    for i in range(4):
        b.box((0, -0.02, 1.0 + i * 1.4), (8.0, 0.05, 0.1), "concrete_dark", bevel=False)
    b.cyl((0, -0.05, 2.8), 1.2, 0.1, "neon_pink", segments=12, rot=rx(90), scale=(1.1, 0.85, 1), bevel=False)
    for (x, z) in ((-1.2, 4.0), (-0.4, 4.6), (0.4, 4.6), (1.2, 4.0)):
        b.cyl((x, -0.05, z), 0.45, 0.1, "neon_pink", segments=10, rot=rx(90), bevel=False)
    for (x, z) in ((-2.8, 1.2), (2.9, 4.8)):
        b.cyl((x, -0.05, z), 0.35, 0.1, "mint", segments=10, rot=rx(90), bevel=False)
    return [b.finalize(N + "PawGraffiti", mat)]


def puddle(mat):
    b, water = Builder(), Builder()
    water.cyl_base((0, 0, 0), 1.6, 0.04, "puddle", segments=12, scale=(1.3, 1, 1), bevel=False)
    b.ring((0.4, 0.2, 0.06), 0.6, 0.08, 0.02, "fish_belly", segments=12, bevel=False)
    b.sphere((0.4, 0.2, 1.4), 0.12, "fish_blue", segments=6, rings=4, scale=(1, 1, 1.5))     # a drip on its way
    return [b.finalize(N + "DripPuddle", mat), water.finalize(N + "DripPuddle_Water", mat)]


def junk_stall(mat):
    b = Builder()
    for x in (-2.0, 0.0, 2.0):
        _crate(b, x, 0, 0)
    b.box_base((0, 0, 2.0), (6.4, 2.4, 0.2), "dark_wood")                                    # counter board
    for (x, sw) in ((-2.2, "metal"), (-1.6, "bowl_red"), (-0.6, "fish_blue"), (0.6, "rarity_legend"), (1.6, "mint")):
        b.cyl_base((x, -0.3, 2.2), 0.25, 0.5, sw, segments=8)                                 # tins and jars
    for k in range(5):
        _cap(b, -2.4 + k * 0.5, 0.5, 2.3, 0.2, CAPS[k])
    b.cyl_base((0, 0.9, 0), 0.12, 6.2, "dark_wood", segments=6)                               # umbrella pole
    for k in range(8):                                                                       # striped umbrella
        a = 2 * PI * (k + 0.5) / 8
        b.fan((0, 0.9, 6.2), (0, 0), [(3.6 * math.cos(a - PI / 8), 3.6 * math.sin(a - PI / 8)),
                                      (3.6 * math.cos(a + PI / 8), 3.6 * math.sin(a + PI / 8))], 0.12,
              "blush" if k % 2 else "offwhite")
    b.cyl_base((0, 0.9, 6.25), 0.6, 0.6, "blush", segments=8, radius2=0.1)
    b.box((0, -1.07, 1.2), (2.6, 0.08, 0.8), "cardboard", bevel=False)                        # price card
    return [b.finalize(N + "JunkStall", mat)]


def can_house(mat):
    b = Builder()
    b.cyl_base((0, 0, 0), 1.7, 3.2, "metal", segments=14)
    b.cyl_base((0, 0, 1.0), 1.72, 1.2, "bowl_red", segments=14, bevel=False)                  # label
    b.box((0, -1.62, 1.6), (0.8, 0.12, 0.8), "fish_belly", bevel=False)                        # fish on the label
    b.box_base((0, -1.66, 0), (1.2, 0.2, 1.7), "fur_black", bevel=False)                      # door hole
    b.cyl((0, -1.66, 1.7), 0.6, 0.2, "fur_black", segments=10, rot=rx(90), bevel=False)
    b.cyl_base((0, 0, 3.2), 1.9, 0.35, "rarity_legend", segments=14)                         # bottle cap roof
    for k in range(14):
        a = 2 * PI * k / 14
        b.box((1.9 * math.cos(a), 1.9 * math.sin(a), 3.37), (0.2, 0.2, 0.35), "rarity_legend", bevel=False,
              rot=rz(math.degrees(a)))
    b.cyl_base((-1.4, -0.9, 0), 0.5, 0.06, "pastel_lilac", segments=10, bevel=False)           # welcome mat
    return [b.finalize(N + "CanHouse", mat)]


def box_house(mat):
    b = Builder()
    b.box_base((0, 0, 0), (3.0, 3.0, 2.6), "cardboard")
    b.box_base((0, -1.52, 0), (1.2, 0.1, 1.5), "fur_black", bevel=False)
    b.cyl((0, -1.52, 1.5), 0.6, 0.1, "fur_black", segments=10, rot=rx(90), bevel=False)
    for s in (-1, 1):                                                                        # flaps opened into a roof
        b.box((s * 0.8, 0, 3.15), (1.8, 3.0, 0.08), "cardboard", rot=ry(-s * 35))
    b.box((0, -1.53, 2.1), (0.9, 0.04, 0.35), "offwhite", bevel=False)                         # "this side up" label
    b.box((0.9, -1.55, 0.9), (0.5, 0.04, 0.5), "fish_belly", bevel=False)                      # window
    b.box_base((-1.1, 1.1, 2.6), (0.08, 0.08, 1.6), "dark_wood", bevel=False)                  # flag
    b.box((-0.75, 1.1, 3.95), (0.7, 0.04, 0.45), "mint", bevel=False)
    return [b.finalize(N + "BoxHouse", mat)]


def teapot_house(mat):
    b = Builder()
    b.sphere((0, 0, 1.9), 2.0, "mint", segments=14, rings=8, scale=(1, 1, 0.85))
    b.cyl_base((0, 0, 0), 1.5, 0.3, "mint", segments=14)
    b.cyl_base((0, 0, 3.45), 1.1, 0.3, "offwhite", segments=12)                                 # lid
    b.sphere((0, 0, 4.0), 0.35, "blush", segments=8, rings=5)
    for k in range(4):                                                                       # spout
        b.cyl((2.0 + k * 0.45, 0, 1.5 + k * 0.45), 0.42 - k * 0.06, 0.72, "mint", segments=10, rot=ry(-45 - k * 6))
    for k in range(6):                                                                       # handle
        a = -PI / 2 + PI * k / 5
        b.box((-2.0 - 0.9 * math.cos(a), 0, 1.9 + 0.9 * math.sin(a)), (0.35, 0.35, 0.55), "mint",
              rot=ry(math.degrees(a)))
    b.box_base((0, -1.85, 0.3), (1.1, 0.3, 1.4), "fur_black", bevel=False)
    b.cyl((0, -1.85, 1.7), 0.55, 0.3, "fur_black", segments=10, rot=rx(90), bevel=False)
    for x in (-1.0, 1.0):
        b.box((x, -1.47, 2.6), (0.12, 0.12, 0.12), "blush", bevel=False)                         # painted dots
    return [b.finalize(N + "TeapotHouse", mat)]


def cap_bunting(mat, length=16.0, sag=1.2, hooks=False):
    b = Builder()
    n = 24
    for k in range(n):
        t0, t1 = k / n, (k + 1) / n
        x0, z0 = -length / 2 + length * t0, -sag * math.sin(PI * t0)
        x1, z1 = -length / 2 + length * t1, -sag * math.sin(PI * t1)
        b.box(((x0 + x1) / 2, 0, (z0 + z1) / 2), (length / n * 1.02, 0.05, 0.05), "dark_wood", bevel=False,
              rot=ry(-math.degrees(math.atan2(z1 - z0, x1 - x0))))
        if k % 2 == 0:
            _cap(b, x0, 0, z0 - 0.35, 0.28, CAPS[(k // 2) % 6], rot=rx(90))
    if hooks:                                                                                # into the walls
        for sx in (-1, 1):
            b.box((sx * (length / 2 - 0.2), 0, 0), (0.6, 0.3, 0.3), "metal", bevel=False)
    return [b.finalize(N + "CapBunting", mat)]


def lost_lounge(mat):
    b, lamp = Builder(), Builder()
    b.box_base((0, 0, 0), (8.0, 6.0, 0.06), "pastel_lilac", bevel=False)                       # rug
    b.box_base((0, 0, 0.06), (6.6, 4.6, 0.02), "blush", bevel=False)
    b.box_base((0, 1.9, 0.08), (5.0, 1.8, 1.1), "shirt_red")                                    # sofa
    b.box_base((0, 2.6, 1.0), (5.0, 0.5, 1.4), "shirt_red")
    for s in (-1, 1):
        b.box_base((s * 2.6, 1.9, 0.08), (0.6, 1.8, 1.7), "shirt_red")
        b.box_base((s * 1.2, 1.7, 1.18), (2.2, 1.3, 0.3), "bowl_red")                         # cushions
    b.box_base((-1.9, 1.7, 1.48), (0.9, 0.3, 0.7), "rarity_legend", rot=rz(10))               # a patch
    b.box_base((3.4, -1.6, 0.08), (1.8, 1.8, 1.0), "pants_navy", rot=rz(-30))                  # armchair
    b.box_base((3.85, -1.0, 0.9), (1.8, 0.4, 1.2), "pants_navy", rot=rz(-30))
    b.cyl_base((-3.4, -2.2, 0.08), 0.35, 0.1, "fur_black", segments=8)                           # floor lamp
    b.cyl_base((-3.4, -2.2, 0.18), 0.08, 3.6, "fur_black", segments=6)
    lamp.cyl_base((-3.4, -2.2, 3.6), 0.7, 0.8, "lamp_warm", segments=10, radius2=0.4)
    b.box_base((0.6, -0.9, 0.08), (1.6, 1.0, 0.7), "caramel_wood")                               # crate table
    b.cyl_base((0.3, -0.9, 0.78), 0.18, 0.3, "offwhite", segments=8)
    return [b.finalize(N + "LostLounge", mat), lamp.finalize(N + "LostLounge_Bulb", mat)]


def crate_deck(mat):
    b = Builder()
    for x in (-2.0, 0.0, 2.0):
        for y in (-2.0, 0.0, 2.0):
            _crate(b, x, y, 0, sw="caramel_wood" if (x + y) % 4 else "cardboard")
    for k in range(7):                                                                       # deck planks
        b.box_base((-2.7 + k * 0.9, 0, 2.0), (0.85, 6.3, 0.15), "dark_wood" if k % 2 else "caramel_wood")
    L = 5.4                                                                                  # ramp to the front
    a = math.atan2(2.1, L)
    yc = -3.0 - L / 2 * math.cos(a)
    b.box((0, yc, 1.05), (2.2, L / math.cos(a) * 0.98, 0.2), "caramel_wood", rot=rx(math.degrees(a)))
    for k in range(5):                                                                       # cleats on the ramp
        y = -3.4 - k * 1.0
        b.box((0, y, 1.05 + (y - yc) * math.tan(a) + 0.1 / math.cos(a) + 0.02), (2.2, 0.12, 0.08), "dark_wood",
              bevel=False, rot=rx(math.degrees(a)))
    for s in (-1, 1):                                                                        # posts and a rope rail
        b.box_base((s * 3.0, 3.0, 2.15), (0.2, 0.2, 1.4), "dark_wood")
        b.box_base((3.0, s * 3.0, 2.15), (0.2, 0.2, 1.4), "dark_wood")
    b.box((0, 3.0, 3.3), (6.0, 0.1, 0.1), "kibble", bevel=False)
    b.box((3.0, 0, 3.3), (0.1, 6.0, 0.1), "kibble", bevel=False)
    return [b.finalize(N + "CrateDeck", mat)]


def bathtub_boat(mat):
    b = Builder()
    b.box_base((0, 0, 0), (2.4, 4.4, 1.3), "offwhite")
    b.box_base((0, 0, 0.4), (1.9, 3.9, 1.0), "fish_belly", bevel=False)                         # inside
    for s in (-1, 1):
        b.cyl((0, s * 2.1, 1.35), 1.2, 0.2, "offwhite", segments=12, rot=rx(90), scale=(1, 1, 0.5))
    b.box((0, 2.1, 1.7), (0.15, 0.3, 0.6), "metal", bevel=False)                                # taps
    b.box((0, 1.9, 2.0), (0.6, 0.15, 0.12), "metal", bevel=False)
    b.box_base((0, -0.6, 0.4), (0.1, 0.1, 3.8), "dark_wood", bevel=False)                       # mast and a sock sail
    b.fan((0.05, -0.6, 2.5), (0, 1.6), [(0, -1.2), (1.2, -1.2)], 0.05, "neon_pink", rot=rx(90))
    b.box((0, -2.33, 0.9), (0.6, 0.3, 0.3), "rarity_legend", bevel=False)                       # duck figurehead
    return [b.finalize(N + "BathtubBoat", mat)]


def _duck(b, x, y, s=1.0, rotz=0.0):
    b.sphere((x, y, 0.35 * s), 0.45 * s, "rarity_legend", segments=8, rings=5, scale=(1, 1.3, 0.75))
    hx, hy = x - 0.3 * s * math.sin(math.radians(rotz)), y - 0.3 * s * math.cos(math.radians(rotz))
    b.sphere((hx, hy, 0.75 * s), 0.28 * s, "rarity_legend", segments=8, rings=5)
    b.box((hx - 0.25 * s * math.sin(math.radians(rotz)), hy - 0.25 * s * math.cos(math.radians(rotz)), 0.72 * s),
          (0.22 * s, 0.2 * s, 0.08 * s), "fur_orange", bevel=False, rot=rz(-rotz))


def rubber_ducks(mat):
    b = Builder()
    for (x, y, s, r) in ((0, 0, 1.3, 0), (1.3, 0.8, 0.8, 10), (-1.2, 0.9, 0.8, -10), (0.6, 1.9, 0.6, 5),
                         (-0.5, 2.0, 0.6, 0)):
        _duck(b, x, y, s, r)
    return [b.finalize(N + "RubberDucks", mat)]


def crate_raft(mat):
    b = Builder()
    for k in range(5):
        b.box_base((-1.6 + k * 0.8, 0, 0), (0.75, 3.6, 0.3), "caramel_wood" if k % 2 else "dark_wood")
    _crate(b, -0.6, 0.4, 0.3, 1.5)
    _crate(b, 0.9, -0.6, 0.3, 1.2, "cardboard")
    b.cyl_base((0.9, 0.9, 0.3), 0.35, 0.6, "metal", segments=8)
    return [b.finalize(N + "CrateRaft", mat)]


def pipe_organ(mat):
    b = Builder()
    b.box_base((0, 0.5, 0), (6.4, 1.0, 1.4), "dark_wood")                                       # console
    for k in range(7):
        h = 3.0 + 2.2 * math.sin(PI * (k + 0.5) / 7) + (k % 2) * 0.6
        x = -2.7 + k * 0.9
        b.cyl_base((x, 0.6, 1.4), 0.36, h, "rarity_legend" if k % 2 else "metal", segments=10)
        b.box((x, 0.24, 1.4 + h * 0.25), (0.35, 0.04, 0.2), "fur_black", bevel=False)            # the pipe's mouth
    for k in range(8):
        b.box((-2.45 + k * 0.7, -0.05, 1.2), (0.55, 0.3, 0.12), "offwhite" if k % 3 else "fur_black", bevel=False)
    return [b.finalize(N + "PipeOrgan", mat)]


def wall_fan(mat):
    b = Builder()
    b.box_base((0, 0.3, 0), (4.6, 0.6, 4.6), "concrete_dark")
    b.cyl((0, -0.05, 2.3), 2.0, 0.2, "fur_black", segments=16, rot=rx(90))
    for k in range(4):                                                                       # blades
        a = PI / 4 + k * PI / 2 + 0.2
        b.box((0.95 * math.cos(a), -0.2, 2.3 + 0.95 * math.sin(a)), (1.7, 0.08, 0.6), "metal", rot=ry(-math.degrees(a)))
    b.cyl((0, -0.3, 2.3), 0.35, 0.3, "bowl_red", segments=10, rot=rx(90))
    for k in range(5):                                                                       # grille bars
        b.box((-1.6 + k * 0.8, -0.38, 2.3), (0.06, 0.06, 4.0), "metal", bevel=False)
    for z in (0.35, 4.25):                                                                   # on rails off the frame
        b.box((0, -0.2, z), (4.0, 0.45, 0.1), "metal", bevel=False)
    return [b.finalize(N + "WallFan", mat)]


def steam_vent(mat):
    b = Builder()
    b.cyl_base((0, 0, 0), 0.7, 1.4, "metal", segments=10)
    b.cyl_base((0, 0, 1.4), 0.85, 0.2, "rust", segments=10)
    for (dx, dz, r) in ((0, 2.1, 0.6), (0.3, 2.8, 0.75), (-0.2, 3.6, 0.9), (0.2, 4.5, 0.7)):
        b.ico((dx, 0, dz), r, "fish_belly", subdivisions=1)
    return [b.finalize(N + "SteamVent", mat)]


def sock_line(mat):
    b = Builder()
    for s in (-1, 1):
        b.box_base((s * 3.6, 0.2, 0), (0.25, 0.25, 0.25), "metal", bevel=False)
    for k in range(16):
        t0, t1 = k / 16, (k + 1) / 16
        x0, z0 = -3.6 + 7.2 * t0, -0.5 * math.sin(PI * t0)
        x1, z1 = -3.6 + 7.2 * t1, -0.5 * math.sin(PI * t1)
        b.box(((x0 + x1) / 2, 0, (z0 + z1) / 2), (0.47, 0.04, 0.04), "offwhite", bevel=False,
              rot=ry(-math.degrees(math.atan2(z1 - z0, x1 - x0))))
    for k, sw in enumerate(("bowl_red", "mint", "pastel_butter", "fish_blue", "neon_pink", "pastel_lilac")):
        x = -2.9 + k * 1.15
        z = -0.5 * math.sin(PI * (x + 3.6) / 7.2)
        b.box((x, 0, z - 0.45), (0.32, 0.08, 0.8), sw, bevel=False)
        b.box((x + 0.12, 0, z - 0.8), (0.55, 0.08, 0.28), sw, bevel=False)
        b.box((x, 0, z - 0.12), (0.34, 0.09, 0.12), "offwhite", bevel=False)
    return [b.finalize(N + "SockLine", mat)]


def barrel(mat):
    b = Builder()
    b.cyl_base((0, 0, 0), 1.0, 2.6, "dumpster_green", segments=12, radius2=1.0)
    for z in (0.4, 1.3, 2.2):
        b.cyl_base((0, 0, z - 0.08), 1.04, 0.16, "metal", segments=12, bevel=False)
    b.cyl_base((0, 0, 2.6), 0.95, 0.05, "rust", segments=12, bevel=False)
    return [b.finalize(N + "Barrel", mat)]


def tyre_stack(mat):
    b = Builder()
    for k in range(3):
        b.ring((0.1 * (k % 2), 0, 0.35 + k * 0.7), 1.2, 0.55, 0.7, "fur_black", segments=14)
    b.ring((1.7, 0.6, 1.2), 1.2, 0.55, 0.7, "fur_black", segments=14, rot=rx(75))
    return [b.finalize(N + "TyreStack", mat)]


def traffic_cone(mat):
    b = Builder()
    b.box_base((0, 0, 0), (1.3, 1.3, 0.15), "fur_orange", bevel=False)
    b.cyl_base((0, 0, 0.15), 0.5, 1.6, "fur_orange", segments=10, radius2=0.1)
    b.cyl_base((0, 0, 0.75), 0.36, 0.25, "offwhite", segments=10, radius2=0.31, bevel=False)
    return [b.finalize(N + "TrafficCone", mat)]


def suitcase_stack(mat):
    b = Builder()
    z = 0.0
    for (w, d, h, sw, r) in ((2.6, 1.0, 1.7, "pants_navy", 0), (2.2, 0.9, 1.4, "terracotta", 8),
                             (1.6, 0.8, 1.1, "mint", -6)):
        b.box_base((0, 0, z), (w, d, h), sw, rot=rz(r))
        b.box((0, 0, z + h + 0.12), (0.6, 0.15, 0.2), "fur_black", bevel=False, rot=rz(r))
        b.box((-w * 0.25, -d / 2 - 0.02, z + h / 2), (0.25, 0.04, 0.25), "rarity_legend", bevel=False, rot=rz(r))
        z += h
    return [b.finalize(N + "SuitcaseStack", mat)]


def yarn_trolley(mat):
    b, yarn = Builder(), Builder()
    for (x, y) in ((-0.9, -1.4), (0.9, -1.4), (-0.9, 1.4), (0.9, 1.4)):
        b.cyl((x, y, 0.25), 0.25, 0.15, "fur_black", segments=8, rot=ry(90))
    b.box_base((0, 0, 0.5), (2.2, 3.4, 0.1), "metal", bevel=False)
    for s in (-1, 1):                                                                        # wire basket
        for z in (0.9, 1.4, 1.9):
            b.box((s * 1.15, 0, z), (0.06, 3.6, 0.06), "metal", bevel=False)
            b.box((0, s * 1.8, z), (2.3, 0.06, 0.06), "metal", bevel=False)
        for k in range(6):
            b.box_base((s * 1.15, -1.75 + k * 0.7, 0.55), (0.06, 0.06, 1.45), "metal", bevel=False)
    b.box((0, 2.4, 2.3), (2.0, 0.12, 0.12), "bowl_red", bevel=False)                            # handle
    for s in (-1, 1):
        b.box((s * 0.9, 2.1, 2.12), (0.08, 0.7, 0.08), "metal", bevel=False, rot=rx(30))     # rising to the handle
    for (x, y, z, sw) in ((-0.5, -0.9, 1.1, "neon_pink"), (0.5, -0.6, 1.1, "mint"), (-0.3, 0.4, 1.1, "pastel_lilac"),
                          (0.5, 0.9, 1.1, "rarity_legend"), (0.0, -0.2, 1.8, "fish_blue"), (-0.2, 1.0, 1.8, "bowl_red")):
        yarn.ico((x, y, z - 0.08), 0.5, sw, subdivisions=1)
    return [b.finalize(N + "YarnTrolley", mat), yarn.finalize(N + "YarnTrolley_Decor", mat)]


def pipe_hammock(mat):
    b = Builder()
    for s in (-1, 1):
        b.cyl_base((s * 3.2, 0, 0), 0.45, 4.4, "dumpster_green", segments=10)
        b.cyl((s * 3.2, 0, 4.4), 0.55, 0.3, "metal", segments=10, bevel=False)
    n = 12
    for k in range(n):                                                                       # the hammock's sag
        t0, t1 = k / n, (k + 1) / n
        x0, z0 = -3.0 + 6.0 * t0, 3.4 - 1.5 * math.sin(PI * t0)
        x1, z1 = -3.0 + 6.0 * t1, 3.4 - 1.5 * math.sin(PI * t1)
        b.box(((x0 + x1) / 2, 0, (z0 + z1) / 2), (math.hypot(x1 - x0, z1 - z0) + 0.04, 1.6, 0.1), "pastel_butter" if k % 2 else "blush", bevel=False,
              rot=ry(-math.degrees(math.atan2(z1 - z0, x1 - x0))))
    b.box((-1.6, 0, 2.6), (1.2, 0.9, 0.35), "offwhite", rot=ry(-20))                            # a little pillow
    return [b.finalize(N + "PipeHammock", mat)]


# ------------------------------------------------------------------------------------------------- the set --
# The tunnel mouths in the walls, as the draft has them (Blender x, y, along the wall's x or y): two in the far
# wall, one in each side wall; the narrow canal runs out through the right one.
MOUTHS = (("far", -24.0), ("far", 24.0), ("left", 8.0), ("right", -16.0))
MOUTH_W = 13.0


def _ground():
    """The tiled floor slab, the hub pool, both canals, the brick walls with their tunnel mouths and the low wall
    and railing on the gate side, in Builder (Blender) axes."""
    g = Builder()
    F, I, T = FLOOR, INNER, WALL_T
    g.box_base((0, 0, 0), (2 * I + 0.2, 2 * I + 0.2, F), "concrete")                         # under the walls' faces
    for k in range(-7, 8):                                                                   # floor tile lines
        g.box_base((k * 6.0, 0, F), (0.15, 2 * I, 0.02), "concrete_dark", bevel=False)
        g.box_base((0, k * 6.0, F), (2 * I, 0.15, 0.026), "concrete_dark", bevel=False)
    g.cyl_base((0, 6, F), 13, 0.04, "concrete_dark", segments=24, bevel=False)              # the hub pool
    g.cyl_base((0, 6, F), 12, 0.1, "sign_teal", segments=24, bevel=False)
    ring_blocks(g, 0, 6, F, 13.5, 1.2, 0.6, "concrete_dark", n=24)
    g.box_base((0, -23.5, F), (8, 33, 0.04), "concrete_dark", bevel=False)                  # the main canal
    g.box_base((0, -23.5, F), (7, 33, 0.1), "sign_teal", bevel=False)
    g.box_base((24.4, -16, F), (40, 5.0, 0.044), "concrete_dark", bevel=False)              # the narrow branch
    g.box_base((24.4, -16, F), (40, 4.0, 0.104), "sign_teal", bevel=False)
    for sx in (-1, 1):
        g.box_base((sx * 4.2, -23.5, F), (0.4, 33, 0.35), "rarity_legend", bevel=False)
        g.box_base((24.6, -16 + sx * 2.7, F), (39.6, 0.4, 0.352), "rarity_legend", bevel=False)
    g.box_base((0, -40.2, F), (8.8, 0.4, 0.354), "rarity_legend", bevel=False)               # the canal's end
    out = I + T                                                                              # walls' outer faces
    mid = I + T / 2

    def wall(a0, a1, side):
        m, L = (a0 + a1) / 2, a1 - a0
        if side == "far":
            g.box_base((m, mid, 0), (L, T, WALL_H), "brick")
            for i in range(5):
                g.box((m, I - 0.05, 3 + i * 3), (L - 0.1, 0.2, 0.2), "concrete_dark", bevel=False)  # ends inside
        else:
            sx = -1 if side == "left" else 1
            g.box_base((sx * mid, m, 0), (T, L, WALL_H), "brick")
            for i in range(5):
                g.box((sx * (I - 0.05), m, 3 + i * 3), (0.2, L - 0.1, 0.2), "concrete_dark", bevel=False)

    for side in ("far", "left", "right"):
        cuts = sorted(c for s_, c in MOUTHS if s_ == side)
        lo = -out                                                                            # corner piers too
        for c in cuts + [None]:
            hi = (c - MOUTH_W / 2) if c is not None else out
            wall(lo, hi, side)
            if c is not None:
                lo = c + MOUTH_W / 2
    for side, c in MOUTHS:                                                                   # over and inside each mouth
        if side == "far":
            g.box_base((c, mid, 13.2), (MOUTH_W, T, WALL_H - 13.2), "brick")
            g.box_base((c, I + 0.05 + (T - 0.2) / 2, 0), (MOUTH_W, T - 0.1, 13.2), "fur_black", bevel=False)
        else:
            sx = -1 if side == "left" else 1
            g.box_base((sx * mid, c, 13.2), (T, MOUTH_W, WALL_H - 13.2), "brick")
            g.box_base((sx * (I + 0.05 + (T - 0.2) / 2), c, 0), (T - 0.1, MOUTH_W, 13.2), "fur_black", bevel=False)
    for sx in (-1, 1):                                                                       # the gate side: low wall
        a0, a1 = GATE_HALF, I
        m = sx * (a0 + a1) / 2
        g.box_base((m, -mid, 0), (a1 - a0, T, 2.6), "brick")
        g.box_base((m, -mid, 2.6), (a1 - a0 + 0.2, T + 0.2, 0.35), "concrete")
        n = 6
        for k in range(n + 1):                                                               # a railing on it
            x = sx * (a0 + 0.4 + k * (a1 - a0 - 0.8) / n)
            g.box_base((x, -mid, 2.95), (0.35, 0.35, 2.46), "metal", bevel=False)               # caps above the rail
        for z in (4.1, 5.25):
            g.box((m, -mid, z), (a1 - a0 - 0.8, 0.2, 0.2), "rarity_legend" if z > 5 else "metal", bevel=False)
    return g


def build_set(mat):
    s = Set(N + "Set")

    def put(objs, bx, by, rot=0.0, y=0.0):
        return s.put(objs, -bx, by, rot, y=FLOOR + y)

    def spot(label, bx, by, y=0.0):
        s.mark(label, -bx, by, y=FLOOR + y)

    def local(bx, by, rot, lx, ly):
        """Draft (Blender) position of a piece's local (lx, ly) for a piece at (bx, by) turned rot."""
        a = math.radians(rot)
        return bx + lx * math.cos(a) - ly * math.sin(a), by + lx * math.sin(a) + ly * math.cos(a)

    put(pipe_outlet(mat), 0, 22.5, 0)                                                        # pours into the pool
    for (side, c) in MOUTHS:                                                                 # arches in the mouths
        if side == "far":
            put(tunnel_arch(mat), c, INNER - 0.8, 0)
        else:
            sx = -1 if side == "left" else 1
            put(tunnel_arch(mat), sx * (INNER - 0.8), c, -90 * sx)                          # facing the room
    put(catwalk(mat), 0, -24, 90)
    spot("catwalk", -3.0, -24, y=3.1)
    put(throne(mat), -22, 24, 20)
    spot("throne", *local(-22, 24, 20, 0, -0.1), y=2.9)
    put(toy_pile(mat), -13, 30, 0)
    spot("toy_pile", -13, 30)
    put(valve_wheel(mat), 36, INNER - 1.0, 0)
    spot("valve", 31.8, INNER - 1.6)
    put(rails(mat), 28, 26, 90)
    put(cart(mat), 28, 30, 90, y=0.25)                                                       # wheels on the rails
    spot("cart", 28, 30, y=3.25)
    put(pipe_large(mat), -30, 38, 0)
    spot("pipe_end", -37.6, 38)
    put(pipe_elbow(mat), 38, 36, 180)
    put(graffiti(mat), 8, INNER - 1.0, 0)
    put(grate(mat), 31, 2, 0)
    spot("trap_grate", 31, 2)
    put(drain_pipe(mat), INNER - 2.0, -34, -90)
    spot("trap_drain_pipe", INNER - 4.4, -35)
    for (bx, by, r) in ((-INNER + 0.6, -10, 90), (INNER - 0.6, 20, -90), (-15.5, INNER - 0.6, 0),
                        (15.5, INNER - 0.6, 0)):
        put(wall_lantern(mat), bx, by, r, y=6.0)
    for (bx, by, r) in ((-6, -10, 0), (36, 12, 30)):
        put(glow_mushrooms(mat), bx, by, r)
    put(puddle(mat), 8, -6, 0)
    put(alleyway.build_crate_stack(mat), -36, 32, 30)
    for by in (-7.0, 0.0, 7.0):                                                              # market row, facing the pool
        put(junk_stall(mat), -21, by, 90)
        spot("stall", *local(-21, by, 90, 0, -2.4))
    for (bx, by, r, fn) in ((18.5, 1.5, -104, can_house), (19.5, 13.5, -69, teapot_house), (16.5, -6.5, -127, box_house),
                            (23.5, 7.0, -88, can_house)):                                    # cat houses facing it
        put(fn(mat), bx, by, r)
        spot("house", *local(bx, by, r, 0, -3.2))
    for (by, z) in ((30.0, 10.5), (-3.0, 10.0)):                                             # bottle cap bunting
        put(cap_bunting(mat, 2 * INNER, 2.2, hooks=True), 0, by, 0, y=z)
    put(lost_lounge(mat), -33, -31, 35)
    spot("sofa", *local(-33, -31, 35, -0.6, 1.1), y=1.48)
    for (bx, by, r) in ((-30, -12, 90), (30, -32, -20)):
        put(crate_deck(mat), bx, by, r)
        spot("deck", *local(bx, by, r, 0.3, 0.6), y=2.15)
    put(bathtub_boat(mat), 21, -16, 90, y=-0.2)
    spot("boat", 21, -16, y=1.2)                                                             # on the water in the tub
    put(rubber_ducks(mat), 31, -16.5, 90, y=0.15)
    put(crate_raft(mat), 12, -16, 90, y=0.15)
    spot("raft", *local(12, -16, 90, -0.6, 0.4), y=1.95)
    put(pipe_organ(mat), -8, INNER - 1.0, 0)
    put(wall_fan(mat), INNER - 0.6, 31, -90, y=5.0)
    put(sock_line(mat), -INNER + 0.3, -28, 90, y=7.0)
    for (bx, by) in ((36, -6), (-14, 37)):
        put(steam_vent(mat), bx, by, 0)
    for (bx, by) in ((35, 25), (37.5, 23)):
        put(barrel(mat), bx, by, 0)
    put(tyre_stack(mat), -38, -3, 0)
    for (bx, by, r) in ((11, -28, 0), (13.5, -31, 20), (-10, 20, 0)):
        put(traffic_cone(mat), bx, by, r)
    put(suitcase_stack(mat), -38, 18, 80)
    put(yarn_trolley(mat), -18, -24, 30)
    spot("trolley", -18, -24, y=0.6)
    put(pipe_hammock(mat), -37, 25, 90)
    spot("hammock", -37, 25, y=2.0)
    return s.finish(_ground(), mat), s


def build_sewer_set(mat):
    objs, _ = build_set(mat)
    return objs


ASSETS = {
    "CatCafe_Sewer_Set": (build_sewer_set, 80000),
}
