"""Cherry Blossom Grove (#4386), a future area from a player's idea: a quiet garden of cherry trees, water and stone.
BLOCKOUT: the tier, the cats and the station are not decided, so nothing in the game uses it yet. About the size of
the Park, 150 x 120.

  CatCafe_Cherry_Set   the area dressed, in area space (areakit): place it at the area's centre on its floor. The
                       arrival end is -Z. Zones, arrival first:
                         z -56 to -18   Arrival: the spawn at (0, -55) facing +Z, the great red gate and a walk
                                        under five small red arches to the round court at (0, -22)
                         x < -20, z < 0 the Wishing Tree on its stone ring, three benches round it
                         x > 25, z < 0  the sand garden: raked sand, three mossy rocks, a low fence on three sides
                         x < -10, z > 5 the koi pond (flat `_Water`, no kerb) with the red hump bridge across its
                                        narrow part, and the cliff behind it with three waterfalls
                         the far middle the four tier pagoda on its stone base (solid; looks only)
                         x > 30, z > 10 the tea house on stilts: a deck 2.5 up with steps at its -X end
  Nothing invisible stands inside the area: the only _Barrier is the 30 high ring in the wall band. Lights are `_Glow`,
  the pond and the falls `_Water`, petals, koi and lily pads `_Decor` (no collision).

Points (manifest points_roblox, area space [x, y, z]): `player_spawn` (1, with a turn), `spawn` (14 stray spots, no
two within 12), `nook` (1, on the pond's far shore between two waterfalls: Rare or better).
"""

import math
import random

import areakit
from common import Builder

NAME = "CatCafe_Cherry_Set"
HALF_X, HALF_Z = 75.0, 60.0
G = 0.03                                    # the ground slab's top
BARRIER_H = 30.0
PINK = ("blush", "fur_rose", "fur_bubblegum", "apron_pink", "fur_strawberry")
RED, ROOF, WOODD, STONE = "bowl_red", "fur_slate", "dark_wood", "fur_pewter"

# Everything below is laid out in Blender axes (x, y, z up); Roblox area space is (-x, z, y), so a point here at
# (x, y) is reported as [-x, height, y].
POND = (-34.0, 22.0)
PAGODA = (6.0, 40.0)
TEA = (46.0, 22.0)
SAND = (42.0, -22.0)
WISH = (-40.0, -24.0)
FALLS = ((-53.0, 6.0, 17.0), (-36.0, 8.0, 18.5), (-19.0, 5.0, 16.0))       # x, width, height
SPAWNS = ((-16, -46), (16, -46), (-24, -6), (-58, -36), (-40, -44), (-62, 2), (32, -4), (40, -28), (64, -28),
          (62, 6), (22, 12), (-12, -2), (32, 38), (-66, 18))
NOOK = (-27.5, 42.0)


def rz(d):
    return (math.radians(d), "Z")


def ry(d):
    return (math.radians(d), "Y")


def _cherry(b, d, rnd, x, y, h=None):
    h = h or rnd.uniform(10, 15)
    r = h * 0.36
    b.cyl_base((x, y, G), 0.7, h * 0.55, "fur_bramble", segments=8, bevel=False, radius2=0.45)
    b.box((x + r * 0.35, y, G + h * 0.5), (r * 0.9, 0.4, 0.4), "fur_bramble", bevel=False, rot=ry(-35))
    b.box((x - r * 0.35, y, G + h * 0.5), (r * 0.9, 0.4, 0.4), "fur_bramble", bevel=False, rot=ry(35))
    c = rnd.sample(PINK, 3)
    b.ico((x, y, G + h * 0.78), r, c[0])
    b.ico((x + r * 0.75, y - r * 0.2, G + h * 0.66), r * 0.68, c[1])
    b.ico((x - r * 0.7, y + r * 0.25, G + h * 0.68), r * 0.7, c[2])
    b.ico((x + r * 0.1, y + r * 0.6, G + h * 0.9), r * 0.55, "offwhite" if rnd.random() < 0.3 else c[1])
    for k in range(7):                                                             # fallen petals under it
        a = rnd.uniform(0, 6.28)
        q = rnd.uniform(1, r * 1.5)
        d.box((x + q * math.cos(a), y + q * math.sin(a), G + 0.07 + 0.004 * k), (0.7, 0.7, 0.05), rnd.choice(PINK),
              bevel=False, rot=rz(rnd.uniform(0, 90)))


def _lantern(b, g, x, y, s=1.0):
    b.box_base((x, y, G), (1.6 * s, 1.6 * s, 0.4 * s), STONE, bevel=False)
    b.box_base((x, y, G + 0.4 * s), (0.7 * s, 0.7 * s, 2.2 * s), STONE, bevel=False)
    b.box_base((x, y, G + 2.6 * s), (1.5 * s, 1.5 * s, 0.3 * s), STONE, bevel=False)
    g.box_base((x, y, G + 2.9 * s), (1.0 * s, 1.0 * s, 1.0 * s), "lamp_warm", bevel=False)
    b.cyl_base((x, y, G + 3.9 * s), 1.3 * s, 0.8 * s, "fur_gunmetal", segments=4, bevel=False, radius2=0.2 * s)


def _roof(b, x, y, z, w, dd, h=1.6, col=ROOF):
    """A flared tier: a wide thin slab, two smaller ones over it, gold tips at the corners."""
    b.box_base((x, y, z), (w, dd, 0.35), col, bevel=False)
    b.box_base((x, y, z + 0.35), (w * 0.78, dd * 0.78, h * 0.45), col, bevel=False)
    b.box_base((x, y, z + 0.35 + h * 0.45), (w * 0.5, dd * 0.5, h * 0.45), col, bevel=False)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box((x + sx * (w / 2 - 0.2), y + sy * (dd / 2 - 0.2), z + 0.55), (1.3, 1.3, 0.35), "gold_mid", bevel=False,
                  rot=rz(45))


def _arch(b, x, y, w=12.0, h=11.0):
    """A red garden gate: two posts on dark feet, a tie beam, a top beam and a dark cap."""
    for sx in (-1, 1):
        b.cyl_base((x + sx * w / 2, y, G), 0.75, h, RED, segments=10, bevel=False, radius2=0.6)
        b.box_base((x + sx * w / 2, y, G), (1.9, 1.9, 0.7), "fur_ink", bevel=False)
    b.box((x, y, h - 1.6), (w + 2.5, 0.7, 0.8), RED, bevel=False)
    b.box((x, y, h + 0.6), (w + 5, 1.1, 0.9), RED, bevel=False)
    b.box((x, y, h + 1.3), (w + 6.4, 1.4, 0.5), "fur_ink", bevel=False)
    b.box((x, y, h - 0.5), (0.7, 0.6, 1.5), RED, bevel=False)


def _bamboo(b, rnd, x, y):
    for _ in range(6):
        dx, dy = rnd.uniform(-1.6, 1.6), rnd.uniform(-1.6, 1.6)
        h = rnd.uniform(9, 14)
        b.cyl_base((x + dx, y + dy, G), 0.28, h, "fur_fern", segments=6, bevel=False)
        b.ico((x + dx, y + dy, h + 0.2), 1.1, "leaf_green", scale=(1, 1, 0.6))


def _ground(b):
    b.box_base((0, 0, 0), (2 * HALF_X, 2 * HALF_Z, G), "leaf_green", bevel=False)
    for k, (x, y, w, dd, r) in enumerate(((0, -40, 8, 38, 0), (0, -6, 8, 34, 0), (-24, 14, 30, 6, -20),
                                          (26, 10, 30, 6, 20))):
        b.box_base((x, y, G), (w, dd, 0.05 + 0.004 * k), "paving_light", bevel=False, rot=rz(r))
    b.cyl_base((0, -22, G), 13, 0.07, "paving_sand", segments=24, bevel=False)             # the round court


def _border(b, d, rnd):
    """A low cream wall with tiled caps all round, cherry trees inside it."""
    W, D = 2 * HALF_X, 2 * HALF_Z
    for k in range(int(W / 6)):
        x = -W / 2 + 3 + k * 6
        for sy in (-1, 1):
            b.box_base((x, sy * (D / 2 - 1.2), G), (6, 1.2, 3.4), "fur_vanilla", bevel=False)
            b.box_base((x, sy * (D / 2 - 1.2), G + 3.4), (6.2, 2.2, 0.6), ROOF, bevel=False)
    for k in range(1, int(D / 6) - 1):
        y = -D / 2 + 3 + k * 6
        for sx in (-1, 1):
            b.box_base((sx * (W / 2 - 1.2), y, G), (1.2, 6, 3.4), "fur_vanilla", bevel=False)
            b.box_base((sx * (W / 2 - 1.2), y, G + 3.4), (2.2, 6.2, 0.6), ROOF, bevel=False)
    for k in range(14):
        x = -W / 2 + 8 + k * 10.3
        if abs(x) > 10:
            _cherry(b, d, rnd, x + rnd.uniform(-1, 1), -D / 2 + 7 + rnd.uniform(-1, 2))
    for k in range(8):
        for sx in (-1, 1):
            _cherry(b, d, rnd, sx * (W / 2 - 7) + rnd.uniform(-1, 1), -D / 2 + 16 + k * 12.5 + rnd.uniform(-2, 2))


def _barrier(mat):
    bar = Builder()
    T = 1.6
    for sy in (-1, 1):
        bar.box_base((0, sy * (HALF_Z - 0.2 - T / 2), 0), (2 * HALF_X, T, BARRIER_H), "offwhite", bevel=False)
    for sx in (-1, 1):
        bar.box_base((sx * (HALF_X - 0.2 - T / 2), 0, 0), (T, 2 * HALF_Z - 2 * T - 0.4, BARRIER_H), "offwhite",
                     bevel=False)
    return bar.finalize(NAME + "_001_Wall_Barrier", mat)


def _cliff(b, g, w, d, rnd):
    """The cliff along the far left with its three waterfalls."""
    for k in range(9):
        x = -70 + k * 8.5
        h = 18 - abs(k - 3) * 1.6 + rnd.uniform(-1, 1)
        y = 52 - (k % 2) * 2
        b.box_base((x, y, G), (9.5, 12, h), STONE if k % 2 else "fur_slate", bevel=False)
        b.box_base((x, y, G + h), (9.5, 12, 0.6), "fur_moss", bevel=False)
        if k in (1, 6):
            _cherry(b, d, rnd, x, 52, 9)
    for (x, wd, h) in FALLS:
        w.box_base((x, 44.6, G + 0.1), (wd, 0.5, h), "fish_blue", bevel=False)
        w.box_base((x - wd * 0.2, 44.3, G + 0.1), (wd * 0.25, 0.4, h), "fish_belly", bevel=False)
        g.ico((x, 43, 0.9), wd * 0.55, "offwhite", scale=(1, 0.7, 0.4))                     # the foam


def _pond(b, w, d, rnd):
    px, py = POND
    for k, (x, y, rx_, ry_) in enumerate(((px, py, 22, 15), (px + 14, py - 6, 13, 10), (px - 10, py + 10, 14, 10))):
        b.cyl_base((x, y, G), 1, 0.08 + 0.004 * k, "paving_sand", segments=24, bevel=False,
                   scale=(rx_ + 1.4, ry_ + 1.4, 1))
        w.cyl_base((x, y, G + 0.02), 1, 0.12 + 0.004 * k, "fish_blue", segments=24, bevel=False, scale=(rx_, ry_, 1))
    for k in range(9):                                                             # koi
        x, y = px + rnd.uniform(-16, 14), py + rnd.uniform(-8, 10)
        d.box((x, y, G + 0.19 + 0.004 * k), (1.6, 0.6, 0.05), rnd.choice(("fur_marmalade", "offwhite", "gold_mid", "bowl_red")),
              bevel=False, rot=rz(rnd.uniform(0, 180)))
    for k in range(10):                                                            # lily pads
        x, y = px + rnd.uniform(-17, 15), py + rnd.uniform(-9, 11)
        d.cyl_base((x, y, G + 0.24 + 0.004 * k), 1.0, 0.05, "leaf_dark", segments=8, bevel=False)
        if rnd.random() < 0.5:
            d.ico((x, y, G + 0.45), 0.4, "blush")
    for (x, y, r) in ((px - 22, py - 4, 2.6), (px + 22, py + 6, 2.2), (px + 6, py + 16, 2.8), (px - 4, py - 15, 2.0)):
        b.ico((x, y, 0.8), r, STONE, scale=(1, 1, 0.7))
        b.ico((x + r * 0.8, y + 0.5, 0.5), r * 0.55, "fur_slate", scale=(1, 1, 0.7))
    # the red hump bridge over the pond's narrow part
    bx, by = px + 3, py + 1
    for k in range(11):
        t = (k - 5) / 5
        b.box_base((bx + t * 9.5, by, 0.6 + 2.6 * (1 - t * t)), (2.2, 5.0, 0.45), RED, bevel=False, rot=ry(t * 24))
    for sy in (-1, 1):
        for t in (-1, -0.5, 0, 0.5, 1):
            b.box_base((bx + t * 9.5, by + sy * 2.4, 0.6 + 2.6 * (1 - t * t)), (0.45, 0.45, 2.2), RED, bevel=False)
        for k in range(10):
            t = (k - 4.5) / 5
            b.box((bx + t * 9.5, by + sy * 2.4, 2.4 + 2.6 * (1 - t * t)), (2.2, 0.3, 0.3), RED, bevel=False,
                  rot=ry(t * 24))
    for t in (-1.18, 1.18):                                                        # a ramp block at each foot
        b.box_base((bx + t * 9.5, by, G), (2.6, 5.0, 0.62), RED, bevel=False)


def _gate_walk(b):
    _arch(b, 0, -50, 14, 13)
    for k in range(5):
        _arch(b, 0, -38 + k * 4.2, 8.5, 7.5)


def _pagoda(b, g):
    gx, gy = PAGODA
    b.box_base((gx, gy, G), (24, 24, 1.6), STONE, bevel=False)
    b.box_base((gx, gy - 13, G), (8, 3, 0.8), STONE, bevel=False)                           # the step
    z = G + 1.6
    for (wd, hh) in ((16, 6.5), (13, 5.5), (10, 5), (7, 4.5)):
        b.box_base((gx, gy, z), (wd, wd, hh), "fur_vanilla", bevel=False)
        for sx in (-1, 1):
            for sy in (-1, 1):
                b.box_base((gx + sx * (wd / 2 - 0.3), gy + sy * (wd / 2 - 0.3), z), (0.8, 0.8, hh), RED, bevel=False)
        b.box_base((gx, gy, z + hh - 0.9), (wd + 0.3, wd + 0.3, 0.6), RED, bevel=False)
        g.box((gx, gy - wd / 2 - 0.05, z + hh * 0.5), (wd * 0.4, 0.2, hh * 0.42), "lamp_warm", bevel=False)
        for dx in (-1, 1):
            g.box((gx + dx * wd * 0.36, gy - wd / 2 - 0.05, z + hh * 0.5), (wd * 0.14, 0.2, hh * 0.3), "lamp_warm",
                  bevel=False)
        _roof(b, gx, gy, z + hh, wd + 7, wd + 7, 1.8)
        z += hh + 1.9
    b.cyl_base((gx, gy, z), 0.35, 5, "gold_mid", segments=6, bevel=False)                   # the spire
    for k in range(3):
        b.cyl_base((gx, gy, z + 1 + k * 1.2), 0.9 - k * 0.2, 0.3, "gold_light", segments=8, bevel=False)
    b.box_base((gx, gy - 8.2, G + 1.6), (4, 0.5, 5), WOODD, bevel=False)                    # the door


def _tea_house(b, g):
    tx, ty = TEA
    for dx in (-8, 0, 8):
        for dy in (-5, 5):
            b.box_base((tx + dx, ty + dy, G), (0.8, 0.8, 2.2), WOODD, bevel=False)
    b.box_base((tx, ty - 1, 2.2), (22, 15, 0.5), "caramel_wood", bevel=False)               # the deck
    b.box_base((tx, ty + 1, 2.7), (18, 9, 6.5), "fur_vanilla", bevel=False)
    for dx in (-6, -2, 2, 6):                                                               # paper screens
        g.box((tx + dx, ty - 3.55, 5.7), (3.2, 0.2, 4.4), "pearl", bevel=False)
        b.box((tx + dx, ty - 3.68, 5.7), (0.25, 0.2, 4.4), WOODD, bevel=False)
        b.box((tx + dx, ty - 3.7, 5.7), (3.2, 0.2, 0.25), WOODD, bevel=False)
    for dx in (-9, 9):
        b.box_base((tx + dx, ty - 3.4, 2.7), (0.7, 0.7, 6.5), WOODD, bevel=False)
    _roof(b, tx, ty + 1, 9.2, 25, 15, 2.4)
    for k in range(4):                                                                      # the steps, -X end
        b.box_base((tx - 12.5 - k * 1.2, ty - 4, G), (1.3, 5, 0.55 * (4 - k) + 0.02), "caramel_wood", bevel=False)
    for dx in (-5, 5):                                                                      # hanging lanterns
        g.cyl((tx + dx, ty - 7.5, 6.9), 0.9, 1.6, "bowl_red", segments=8, bevel=False)
        b.box((tx + dx, ty - 7.5, 8.3), (0.15, 0.15, 1.2), WOODD, bevel=False)
    b.box_base((tx - 3, ty - 6, 2.7), (3.2, 3.2, 0.9), WOODD, bevel=False)                  # a low table and a pot
    b.cyl_base((tx - 3, ty - 6, 3.6), 0.5, 0.5, "offwhite", segments=8, bevel=False)


def _sand_garden(b):
    zx, zy = SAND
    b.box_base((zx, zy, G), (34, 24, 0.12), "fur_vanilla", bevel=False)
    for k in range(11):                                                                     # the rake lines
        b.box_base((zx, zy - 10.5 + k * 2.1, G + 0.12), (32, 0.35, 0.04), "fur_oat", bevel=False)
    for (x, y, r) in ((zx - 8, zy + 3, 2.6), (zx + 6, zy - 4, 2.0), (zx + 10, zy + 6, 1.5)):
        b.cyl_base((x, y, G + 0.12), r * 1.9, 0.05, "fur_oat", segments=16, bevel=False)
        b.cyl_base((x, y, G + 0.17), r * 1.45, 0.04, "fur_vanilla", segments=16, bevel=False)
        b.ico((x, y, 0.9), r, "fur_slate", scale=(1, 0.85, 0.9))
        b.box_base((x, y, 0.9 + r * 0.7), (r * 0.9, r * 0.8, 0.2), "fur_moss", bevel=False)
    for (sx, sy, wd, dd) in ((0, -12.3, 34.6, 0.5), (0, 12.3, 34.6, 0.5), (17.3, 0, 0.5, 24.1)):
        b.box_base((zx + sx, zy + sy, G), (wd, dd, 0.5), WOODD, bevel=False)


def _wishing_tree(b, g):
    wx, wy = WISH
    b.cyl_base((wx, wy, G), 7, 0.5, STONE, segments=12, bevel=False)
    b.cyl_base((wx, wy, G + 0.5), 6, 0.2, "fur_moss", segments=12, bevel=False)
    b.cyl_base((wx, wy, G + 0.7), 1.8, 10, "fur_bramble", segments=10, bevel=False, radius2=1.1)
    b.cyl_base((wx, wy, 4.2), 1.75, 0.5, "offwhite", segments=10, bevel=False)              # the rope
    for k in range(6):                                                                      # paper charms
        g.box((wx + 1.8 * math.cos(k * 1.05), wy + 1.8 * math.sin(k * 1.05), 3.6), (0.5, 0.1, 0.9), "offwhite",
              bevel=False, rot=rz(math.degrees(k * 1.05) + 90))
    for (dx, dy, dz, r, c) in ((0, 0, 15, 7.5, "blush"), (5, -1, 12.5, 5.2, "fur_rose"), (-5, 2, 13, 5.4, "fur_bubblegum"),
                               (1, 4.5, 17, 4.6, "offwhite"), (-1, -4.5, 13.5, 4.8, "apron_pink")):
        b.ico((wx + dx, wy + dy, dz), r, c)
    for a in (30, 150, 270):                                                                # benches
        x, y = wx + 10 * math.cos(math.radians(a)), wy + 10 * math.sin(math.radians(a))
        b.box_base((x, y, G), (3, 1, 0.6), STONE, bevel=False, rot=rz(a + 90))
        b.box_base((x, y, G + 0.6), (4, 1.4, 0.3), "caramel_wood", bevel=False, rot=rz(a + 90))


def _dressing(b, g, d, rnd):
    for (x, y) in ((-14, -12), (14, -12), (-20, -40), (20, -40), (22, 26), (-8, 22), (26, 46), (62, 44), (70, -2),
                   (-66, -6), (-60, -46), (24, -2)):
        _cherry(b, d, rnd, x, y)
    for (x, y) in ((60, 50), (66, 42), (-70, 30), (-66, 38), (70, -44), (64, -50)):
        _bamboo(b, rnd, x, y)
    for (x, y) in ((-6, -34), (6, -34), (-6, -10), (6, -10), (-14, 6), (18, 2), (30, 14), (-12, 34), (24, 30),
                   (-52, -12), (-28, -16), (26, -22)):
        _lantern(b, g, x, y)
    for (x, y) in ((-9, -22), (9, -22)):
        _lantern(b, g, x, y, 1.5)
    for k in range(150):                                                                    # petals on the ground
        x, y = rnd.uniform(-HALF_X + 4, HALF_X - 4), rnd.uniform(-HALF_Z + 4, 40)
        d.box((x, y, G + 0.1 + 0.004 * (k % 7)), (0.7, 0.7, 0.05), rnd.choice(PINK), bevel=False,
              rot=rz(rnd.uniform(0, 90)))


def _points():
    """Area-space Roblox points: a Blender (x, y) here is Roblox (-x, y)."""
    def rb(x, y, h=0.0, *more):
        return [round(-x, 2), round(h, 2), round(y, 2), *more]
    pts = {"player_spawn": [rb(0, -55.2, 0.0, 0)], "spawn": [rb(x, y) for (x, y) in SPAWNS], "nook": [rb(*NOOK)]}
    spots = pts["spawn"] + pts["nook"]
    for i, a in enumerate(spots):
        for c in spots[i + 1:]:
            assert math.hypot(a[0] - c[0], a[2] - c[2]) >= 12.0, (a, c)
    assert len(pts["spawn"]) == 14
    return pts


def build_cherry_set(mat):
    rnd = random.Random(7)
    b, g, w, d = Builder(), Builder(), Builder(), Builder()
    _ground(b)
    _border(b, d, rnd)
    _cliff(b, g, w, d, rnd)
    _pond(b, w, d, rnd)
    _gate_walk(b)
    _pagoda(b, g)
    _tea_house(b, g)
    _sand_garden(b)
    _wishing_tree(b, g)
    _dressing(b, g, d, rnd)
    areakit.POINTS[NAME] = _points()
    return [b.finalize(NAME, mat), _barrier(mat), g.finalize(NAME + "_002_Lights_Glow", mat),
            w.finalize(NAME + "_003_Pond_Water", mat), d.finalize(NAME + "_004_Petals_Decor", mat)]


ASSETS = {
    NAME: (build_cherry_set, 150000),
}
