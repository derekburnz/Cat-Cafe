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
                         the far middle the four tier pagoda on its stone base (solid; looks only), a red rail
                                        round the base, two stone cats by the step, bells on every roof tip
                         x > 30, z > 10 the tea house on stilts: a railed deck 2.5 up with steps at its -X end, two
                                        low tables with cushions
  Nothing invisible stands inside the area: the only _Barrier is the 30 high ring in the wall band. Lights are `_Glow`,
  the pond (`_003_Pond_Water`) and the three falls (`_005_Waterfall_Water`, for Effects' mist) `_Water`, petals, koi and lily pads `_Decor` (no collision).

Points (manifest points_roblox, area space [x, y, z]): `player_spawn` (1, with a turn), `spawn` (14 stray spots, no
two within 12), `nook` (1, on the pond's far shore between two waterfalls: Rare or better).
"""

import math
import random

import areakit
from common import RB, Builder
from plot import rot_z

NAME = "CatCafe_Cherry_Set"
PORTAL, STALL, PETALS = "CatCafe_Cherry_Portal", "CatCafe_Cherry_Stall", "CatCafe_Cherry_Petals"
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
SAND = (42.0, -22.0)                        # the Petal patch (spec v2 section 2), once the sand garden
STALL_AT = (44.0, 4.0)                      # the Blossom Stall, front to -Y (Roblox -Z), turn 0
WISH = (-40.0, -24.0)
FALLS = ((-53.0, 6.0, 17.0), (-36.0, 8.0, 18.5), (-19.0, 5.0, 16.0))       # x, width, height
SPAWNS = ((-16, -46), (16, -46), (-24, -6), (-58, -36), (-40, -44), (-62, 2), (32, -4), (50, -44), (64, -28),
          (62, 6), (22, 12), (-12, -2), (32, 38), (-66, 18))
NOOK = (-27.5, 42.0)
PATCH_SPOTS = tuple((SAND[0] - 9 + 6 * c, SAND[1] - 6 + 6 * r) for r in range(3) for c in range(4))


def rz(d):
    return (math.radians(d), "Z")


def ry(d):
    return (math.radians(d), "Y")


def _turn_tilt(yaw, tilt):
    """A turn about Z by yaw, with the +X end lifted by tilt degrees (for roof corners)."""
    from mathutils import Matrix
    return Matrix.Rotation(math.radians(yaw), 3, "Z") @ Matrix.Rotation(math.radians(-tilt), 3, "Y")


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
            cx, cy = x + sx * (w / 2 - 0.2), y + sy * (dd / 2 - 0.2)
            a = math.degrees(math.atan2(sy, sx))
            # the corner sweeps up: a short ridge tilted outward and up, then a gold tip on its end
            b.box((cx + sx * 0.5, cy + sy * 0.5, z + 0.55), (2.6, 0.7, 0.4), col, bevel=False,
                  rot=_turn_tilt(a, 28))
            b.box((cx + sx * 1.35, cy + sy * 1.35, z + 1.2), (0.8, 0.8, 0.5), "gold_mid", bevel=False, rot=rz(a))
            # a little bell hangs from each tip
            b.box((cx + sx * 1.5, cy + sy * 1.5, z + 0.82), (0.08, 0.08, 0.3), "fur_ink", bevel=False)
            b.cyl((cx + sx * 1.5, cy + sy * 1.5, z + 0.45), 0.3, 0.45, "gold_light", segments=6, bevel=False,
                  radius2=0.16)


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


def _koi(d, x, y, z, yaw, s, col, spot):
    """One koi seen from above: a long flat body, a head patch and a tail fin."""
    c, sn = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    d.ico((x, y, z), s, col, scale=(1, 0.36, 0.13), rot=rz(yaw))
    d.ico((x + 0.45 * s * c, y + 0.45 * s * sn, z + 0.06), s * 0.42, spot, scale=(1, 0.55, 0.2), rot=rz(yaw))
    d.box((x - 1.12 * s * c, y - 1.12 * s * sn, z), (0.62 * s, 0.62 * s, 0.05), col, bevel=False, rot=rz(yaw + 45))
    for side in (-1, 1):                                                           # side fins
        d.box((x + 0.2 * s * c - side * 0.36 * s * sn, y + 0.2 * s * sn + side * 0.36 * s * c, z - 0.02),
              (0.4 * s, 0.22 * s, 0.04), col, bevel=False, rot=rz(yaw + side * 35))


def _cat_statue(b, x, y, z, s=1.0):
    """A stone cat sitting on a block, facing the arrival end."""
    b.box_base((x, y, z), (2.2 * s, 2.2 * s, 0.8 * s), STONE, bevel=False)
    b.ico((x, y, z + 1.75 * s), 1.05 * s, "fur_slate", scale=(0.9, 0.95, 1.15))
    b.ico((x, y - 0.25 * s, z + 3.25 * s), 0.8 * s, "fur_slate")
    for sx in (-1, 1):
        b.pyramid((x + sx * 0.45 * s, y - 0.25 * s, z + 3.8 * s), 0.5 * s, 0.6 * s, "fur_slate")
        b.ico((x + sx * 0.4 * s, y - 0.85 * s, z + 1.1 * s), 0.3 * s, "fur_slate")                   # the front paws
    b.box((x, y - 0.75 * s, z + 2.65 * s), (0.9 * s, 0.25 * s, 0.25 * s), RED, bevel=False)          # a red collar bib


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


def _cliff(b, g, f, d, rnd):
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
        f.box_base((x, 44.6, G + 0.1), (wd, 0.5, h), "fish_blue", bevel=False)
        f.box_base((x - wd * 0.2, 44.3, G + 0.1), (wd * 0.25, 0.4, h), "fish_belly", bevel=False)
        g.ico((x, 43, 0.9), wd * 0.55, "offwhite", scale=(1, 0.7, 0.4))                     # the foam


def _pond(b, w, d, rnd):
    px, py = POND
    for k, (x, y, rx_, ry_) in enumerate(((px, py, 22, 15), (px + 14, py - 6, 13, 10), (px - 10, py + 10, 14, 10))):
        b.cyl_base((x, y, G), 1, 0.08 + 0.004 * k, "paving_sand", segments=24, bevel=False,
                   scale=(rx_ + 1.4, ry_ + 1.4, 1))
        w.cyl_base((x, y, G + 0.02), 1, 0.12 + 0.004 * k, "fish_blue", segments=24, bevel=False, scale=(rx_, ry_, 1))
    for k in range(9):                                                             # koi
        x, y = px + rnd.uniform(-16, 14), py + rnd.uniform(-8, 10)
        col, spot = rnd.choice((("fur_marmalade", "offwhite"), ("offwhite", "bowl_red"), ("gold_mid", "offwhite"),
                                ("bowl_red", "offwhite"), ("offwhite", "fur_ink")))
        _koi(d, x, y, G + 0.2 + 0.004 * k, rnd.uniform(0, 360), rnd.uniform(1.0, 1.5), col, spot)
    for k in range(10):                                                            # lily pads
        x, y = px + rnd.uniform(-17, 15), py + rnd.uniform(-9, 11)
        d.cyl_base((x, y, G + 0.24 + 0.004 * k), 1.0, 0.05, "leaf_dark", segments=8, bevel=False)
        if rnd.random() < 0.5:
            d.ico((x, y, G + 0.45), 0.4, "blush")
    for (x, y, r) in ((px - 22, py - 4, 2.6), (px + 22, py + 6, 2.2), (px + 6, py + 16, 2.8), (px - 4, py - 15, 2.0)):
        b.ico((x, y, 0.8), r, STONE, scale=(1, 1, 0.7))
        b.ico((x + r * 0.8, y + 0.5, 0.5), r * 0.55, "fur_slate", scale=(1, 1, 0.7))
    for k in range(26):                                                            # rocks round the main pool's rim
        a = math.radians(k * 360 / 26 + 5)
        if 150 < math.degrees(a) % 360 < 215 or math.sin(a) > 0.85:
            continue                                                               # open toward the path and the falls
        r = 0.9 + 0.5 * ((k * 7) % 5) / 4
        b.ico((px + 23.2 * math.cos(a), py + 16.2 * math.sin(a), G + r * 0.35), r, (STONE, "fur_slate")[k % 2],
              scale=(1, 1, 0.6))
    for k in range(6):                                                             # stepping stones over the near lobe
        b.cyl_base((px + 14 - 3.5 + k * 1.2, py - 14.5 + k * 3.2, G), 1.25, 0.34 + 0.004 * k, STONE, segments=8,
                   bevel=False)
    for (x, wd, _h) in FALLS:                                                       # a splash pool under each fall
        w.cyl_base((x, 41.5, G + 0.02), 1, 0.15, "fish_blue", segments=16, bevel=False, scale=(wd * 0.9, 3.4, 1))
        b.cyl_base((x, 41.5, G), 1, 0.07, "paving_sand", segments=16, bevel=False, scale=(wd * 0.9 + 1.0, 4.4, 1))
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
    for tier, (wd, hh) in enumerate(((16, 6.5), (13, 5.5), (10, 5), (7, 4.5))):
        b.box_base((gx, gy, z), (wd, wd, hh), "fur_vanilla", bevel=False)
        for sx in (-1, 1):
            for sy in (-1, 1):
                b.box_base((gx + sx * (wd / 2 - 0.3), gy + sy * (wd / 2 - 0.3), z), (0.8, 0.8, hh), RED, bevel=False)
        b.box_base((gx, gy, z + hh - 0.9), (wd + 0.3, wd + 0.3, 0.6), RED, bevel=False)
        g.box((gx, gy - wd / 2 - 0.05, z + hh * 0.5), (wd * 0.4, 0.2, hh * 0.42), "lamp_warm", bevel=False)
        for dx in (-1, 1):
            g.box((gx + dx * wd * 0.36, gy - wd / 2 - 0.05, z + hh * 0.5), (wd * 0.14, 0.2, hh * 0.3), "lamp_warm",
                  bevel=False)
        for s in (-1, 1):                                                          # lit windows on the other sides
            g.box((gx + s * (wd / 2 + 0.05), gy, z + hh * 0.5), (0.2, wd * 0.4, hh * 0.42), "lamp_warm", bevel=False)
            b.box((gx + s * (wd / 2 + 0.2), gy, z + hh * 0.5), (0.1, wd * 0.4, 0.2), WOODD, bevel=False)
            b.box((gx + s * (wd / 2 + 0.2), gy, z + hh * 0.5), (0.1, 0.2, hh * 0.42), WOODD, bevel=False)
        g.box((gx, gy + wd / 2 + 0.05, z + hh * 0.5), (wd * 0.4, 0.2, hh * 0.42), "lamp_warm", bevel=False)
        if tier:                                                                   # window bars (the door covers tier 1)
            b.box((gx, gy - wd / 2 - 0.2, z + hh * 0.5), (wd * 0.4, 0.1, 0.2), WOODD, bevel=False)
            b.box((gx, gy - wd / 2 - 0.2, z + hh * 0.5), (0.2, 0.1, hh * 0.42), WOODD, bevel=False)
        n = 5 if wd > 9 else 3                                                     # brackets under the eave
        for k in range(n):
            o = (k - (n - 1) / 2) * (wd - 2.4) / (n - 1)
            for s in (-1, 1):
                b.box_base((gx + o, gy + s * (wd / 2 + 0.6), z + hh - 0.3), (0.7, 0.9, 0.3), WOODD, bevel=False)
                b.box_base((gx + s * (wd / 2 + 0.6), gy + o, z + hh - 0.3), (0.9, 0.7, 0.3), WOODD, bevel=False)
        _roof(b, gx, gy, z + hh, wd + 7, wd + 7, 1.8)
        z += hh + 1.9
    b.cyl_base((gx, gy, z), 0.35, 5, "gold_mid", segments=6, bevel=False)                   # the spire
    for k in range(3):
        b.cyl_base((gx, gy, z + 1 + k * 1.2), 0.9 - k * 0.2, 0.3, "gold_light", segments=8, bevel=False)
    b.box_base((gx, gy - 8.2, G + 1.6), (4, 0.5, 5), WOODD, bevel=False)                    # the door
    top = G + 1.6
    for s in (-1, 1):                                                              # its frame, knobs and lanterns
        b.box_base((gx + s * 2.3, gy - 8.3, top), (0.6, 0.7, 5.6), RED, bevel=False)
        b.cyl((gx + s * 0.5, gy - 8.5, top + 2.4), 0.22, 0.2, "gold_mid", segments=8, bevel=False,
              rot=(math.radians(90), "X"))
        g.cyl((gx + s * 4.6, gy - 9.6, top + 4.4), 0.75, 1.3, "bowl_red", segments=8, bevel=False)
        b.box((gx + s * 4.6, gy - 9.6, top + 5.75), (0.12, 0.12, 1.4), WOODD, bevel=False)
        _cat_statue(b, gx + s * 6.5, gy - 14.6, G)
    b.box_base((gx, gy - 8.3, top + 5.6), (5.8, 0.8, 0.6), RED, bevel=False)
    b.box((gx, gy - 8.48, top + 0.02 + 2.5), (0.12, 0.1, 5.0), "fur_ink", bevel=False)      # the gap between the two leaves
    # a red rail round the stone base, open at the step
    R = 11.4
    for k in range(7):
        o = -R + k * 2 * R / 6
        for s in (-1, 1):
            b.box_base((gx + s * R, gy + o, top), (0.5, 0.5, 1.5), RED, bevel=False)
            if 0 < k < 6:
                b.box_base((gx + o, gy + R, top), (0.5, 0.5, 1.5), RED, bevel=False)
                if abs(o) > 4.5:
                    b.box_base((gx + o, gy - R, top), (0.5, 0.5, 1.5), RED, bevel=False)
    for s in (-1, 1):
        b.box((gx + s * R, gy, top + 1.25), (0.3, 2 * R, 0.3), RED, bevel=False)
        b.box((gx + s * 7.6, gy - R, top + 1.25), (7.6, 0.3, 0.3), RED, bevel=False)
        b.box_base((gx + s * 4.05, gy - R, top), (0.5, 0.5, 1.5), RED, bevel=False)
    b.box((gx, gy + R, top + 1.25), (2 * R, 0.3, 0.3), RED, bevel=False)


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
    for k, ox in enumerate((-3, 4.5)):                                                      # low tables, pots, cups, cushions
        b.box_base((tx + ox, ty - 6, 2.7), (3.2, 2.6, 0.9), WOODD, bevel=False)
        b.cyl_base((tx + ox, ty - 6, 3.6), 0.5, 0.5, "offwhite", segments=8, bevel=False)
        b.cyl_base((tx + ox, ty - 6, 4.1), 0.2, 0.15, "fur_ink", segments=6, bevel=False)
        for s in (-1, 1):
            b.cyl_base((tx + ox + s * 0.95, ty - 6.4, 3.6), 0.22, 0.25, "offwhite", segments=6, bevel=False)
            b.cyl_base((tx + ox + s * 2.6, ty - 6, 2.7), 0.85, 0.25, (RED, "apron_pink")[(k + (s > 0)) % 2], segments=10,
                       bevel=False)
    # the deck rail: along the front and the +X end (the steps come up at the -X end)
    FY, EX, RZ = ty - 8.2, tx + 10.7, 2.7
    for k in range(9):
        b.box_base((tx - 10.6 + k * 2.6625, FY, RZ), (0.35, 0.35, 1.5), WOODD, bevel=False)
    b.box((tx + 0.05, FY, RZ + 1.3), (21.3, 0.25, 0.25), WOODD, bevel=False)
    b.box((tx + 0.05, FY, RZ + 0.7), (21.3, 0.15, 0.15), WOODD, bevel=False)
    for k in range(1, 5):
        b.box_base((EX, FY + k * 3.6, RZ), (0.35, 0.35, 1.5), WOODD, bevel=False)
    b.box((EX, FY + 7.2, RZ + 1.3), (0.25, 14.4, 0.25), WOODD, bevel=False)
    b.box((EX, FY + 7.2, RZ + 0.7), (0.15, 14.4, 0.15), WOODD, bevel=False)
    # the ridge with gold ends, a door curtain over the middle, a round window on the +X end
    b.box_base((tx, ty + 1, 11.71), (14, 0.8, 0.6), "fur_ink", bevel=False)
    for s in (-1, 1):
        b.box_base((tx + s * 7.2, ty + 1, 11.71), (0.6, 1.0, 1.1), "gold_mid", bevel=False)
    b.box((tx, ty - 3.9, 8.75), (4.6, 0.2, 0.2), WOODD, bevel=False)
    for k in range(4):
        b.box((tx - 1.65 + k * 1.1, ty - 3.9, 7.85), (1.0, 0.1, 1.6), "pants_navy", bevel=False)
        b.cyl((tx - 1.65 + k * 1.1, ty - 3.96, 7.9), 0.28, 0.06, "offwhite", segments=8, bevel=False,
              rot=(math.radians(90), "X"))
    g.cyl((tx + 9.05, ty + 1, 6.3), 1.7, 0.2, "pearl", segments=14, bevel=False, rot=ry(90))
    b.box((tx + 9.2, ty + 1, 6.3), (0.1, 3.4, 0.2), WOODD, bevel=False)
    b.box((tx + 9.2, ty + 1, 6.3), (0.1, 0.2, 3.4), WOODD, bevel=False)


def _petal_patch(b, g, d):
    """The Petal patch: a soft pink lawn in a low fence, its 12 pickup spots on pale rings (where the glowing
    CatCafe_Cherry_Petals piles stand), fallen petals round them."""
    zx, zy = SAND
    b.box_base((zx, zy, G), (34, 24, 0.12), "blush", bevel=False)
    for (x, y) in PATCH_SPOTS:
        b.cyl_base((x, y, G + 0.12), 1.5, 0.03, "fur_rose", segments=12, bevel=False)
    for k in range(60):
        x, y = zx - 16 + (k * 7.3) % 32, zy - 11 + (k * 4.9) % 22
        d.box((x, y, G + 0.14), (0.6, 0.6, 0.04), PINK[k % len(PINK)], bevel=False, rot=rz(k * 37))
    for (sx, sy, wd, dd) in ((0, -12.3, 34.6, 0.5), (0, 12.3, 34.6, 0.5), (17.3, 0, 0.5, 24.1)):
        b.box_base((zx + sx, zy + sy, G), (wd, dd, 0.5), WOODD, bevel=False)
    for (x, y) in ((zx + 17.3, zy - 12.3), (zx + 17.3, zy + 12.3)):                         # corner lanterns
        _lantern(b, g, x - 1.5, y + (1.5 if y < zy else -1.5))


def _wishing_tree(b, g, d):
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
    for k in range(5):                                                                      # roots and big branches
        a = 20 + k * 72
        c, s = math.cos(math.radians(a)), math.sin(math.radians(a))
        b.box((wx + 2.3 * c, wy + 2.3 * s, G + 1.25), (3.2, 0.9, 0.8), "fur_bramble", bevel=False,
              rot=_turn_tilt(a, -24))
        b.box((wx + 3.4 * c, wy + 3.4 * s, 10.6), (6.5, 0.9, 0.9), "fur_bramble", bevel=False, rot=_turn_tilt(a, 34))
    for k in range(16):                                                                     # wishes on red strings
        a = k * 2.399
        q = 4.2 + (k * 5 % 7) * 0.55
        ln = 2.2 + (k * 3 % 5) * 0.45
        x, y, zt = wx + q * math.cos(a), wy + q * math.sin(a), 10.2
        d.box((x, y, zt - ln / 2), (0.08, 0.08, ln), RED, bevel=False)
        d.box((x, y, zt - ln - 0.4), (0.7, 0.1, 0.8), ("caramel_wood", "offwhite", "blush")[k % 3], bevel=False,
              rot=rz(math.degrees(a) + 90))
    posts = (0, 60, 90, 120, 180, 210, 240, 300, 330)                                       # a rope ring, open at the benches
    for a in posts:
        b.cyl_base((wx + 6.5 * math.cos(math.radians(a)), wy + 6.5 * math.sin(math.radians(a)), G + 0.5), 0.3, 1.2,
                   STONE, segments=6, bevel=False)
    for a in (75, 105, 195, 225, 315, 345):
        b.box((wx + 6.28 * math.cos(math.radians(a)), wy + 6.28 * math.sin(math.radians(a)), G + 1.45),
              (3.36, 0.12, 0.12), "offwhite", bevel=False, rot=rz(a + 90))
    ox, oy = wx + 4.2 * math.cos(math.radians(-90)), wy + 4.2 * math.sin(math.radians(-90))  # the wish box, arrival side
    b.box_base((ox, oy, G + 0.7), (1.8, 1.1, 1.1), WOODD, bevel=False)
    b.box_base((ox, oy, G + 1.8), (2.0, 1.3, 0.15), RED, bevel=False)
    b.box_base((ox, oy, G + 1.95), (1.0, 0.2, 0.03), "gold_mid", bevel=False)
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
                   (-52, -12), (-28, -16), (22, -22)):
        _lantern(b, g, x, y)
    for (x, y) in ((-9, -22), (9, -22)):
        _lantern(b, g, x, y, 1.5)
    for k in range(150):                                                                    # petals on the ground
        x, y = rnd.uniform(-HALF_X + 4, HALF_X - 4), rnd.uniform(-HALF_Z + 4, 40)
        d.box((x, y, G + 0.1 + 0.004 * (k % 7)), (0.7, 0.7, 0.05), rnd.choice(PINK), bevel=False,
              rot=rz(rnd.uniform(0, 90)))


def _props(b, g, w):
    """A bamboo water spout by the tea house, a low bamboo fence along the deck's front, post markers on the paths."""
    tx, ty = TEA
    sx, sy = tx - 20, ty - 12                                                       # the spout and its stone basin
    b.cyl_base((sx, sy, G), 1.6, 0.9, STONE, segments=10, bevel=False)
    w.cyl_base((sx, sy, G + 0.9), 1.25, 0.06, "fish_blue", segments=10, bevel=False)
    for dx in (-0.5, 0.5):
        b.box_base((sx + 2.2, sy + dx, G), (0.3, 0.3, 2.6), "fur_fern", bevel=False)
    b.box((sx + 2.2, sy, 2.3), (0.25, 1.4, 0.25), "fur_fern", bevel=False)
    b.box((sx + 1.2, sy, 2.2), (3.4, 0.5, 0.5), "fur_fern", bevel=False, rot=ry(18))   # the tipping pipe
    for k in range(9):                                                               # the fence, with a gap at the steps
        x = tx - 8 + k * 2.6
        b.box_base((x, ty - 10.2, G), (0.3, 0.3, 1.9), "fur_fern", bevel=False)
        if k < 8:
            b.box((x + 1.3, ty - 10.2, 1.5), (2.6, 0.2, 0.22), "fur_fern", bevel=False)
            b.box((x + 1.3, ty - 10.2, 0.8), (2.6, 0.2, 0.22), "fur_fern", bevel=False)
    for (x, y) in ((-5.5, -2), (5.5, -2), (-5.5, 8), (5.5, 8), (-36, 6), (34, 4)):       # path markers
        b.box_base((x, y, G), (0.6, 0.6, 1.4), STONE, bevel=False)
        g.box_base((x, y, G + 1.4), (0.5, 0.5, 0.3), "lamp_warm", bevel=False)


def _points():
    """Area-space Roblox points: a Blender (x, y) here is Roblox (-x, y)."""
    def rb(x, y, h=0.0, *more):
        return [round(-x, 2), round(h, 2), round(y, 2), *more]
    wx, wy = WISH
    pts = {"player_spawn": [rb(0, -55.2, 0.0, 0)], "spawn": [rb(x, y) for (x, y) in SPAWNS], "nook": [rb(*NOOK)],
           "station": [rb(wx, wy - 7.8, 0.0, 0)],          # the Wishing Tree's walk-up spot, by the wish box
           "petal": [rb(x, y, G + 0.15) for (x, y) in PATCH_SPOTS], "stall": [rb(*STALL_AT, 0.0, 0)]}
    spots = pts["spawn"] + pts["nook"]
    for i, a in enumerate(spots):
        for c in spots[i + 1:]:
            assert math.hypot(a[0] - c[0], a[2] - c[2]) >= 12.0, (a, c)
    for a in spots:                                     # strays stand clear of the patch and the stall
        for c in pts["petal"]:
            assert math.hypot(a[0] - c[0], a[2] - c[2]) >= 6.0, (a, c)
        for c in pts["stall"]:
            assert math.hypot(a[0] - c[0], a[2] - c[2]) >= 9.0, (a, c)
    assert len(pts["spawn"]) == 14 and len(pts["petal"]) == 12
    return pts


def build_cherry_set(mat):
    rnd = random.Random(7)
    b, g, w, d, f = Builder(), Builder(), Builder(), Builder(), Builder()
    _ground(b)
    _border(b, d, rnd)
    _cliff(b, g, f, d, rnd)
    _pond(b, w, d, rnd)
    _gate_walk(b)
    _pagoda(b, g)
    _tea_house(b, g)
    _petal_patch(b, g, d)
    _wishing_tree(b, g, d)
    _dressing(b, g, d, rnd)
    _props(b, g, w)
    areakit.POINTS[NAME] = _points()
    return [b.finalize(NAME, mat), _barrier(mat), g.finalize(NAME + "_002_Lights_Glow", mat),
            w.finalize(NAME + "_003_Pond_Water", mat), d.finalize(NAME + "_004_Petals_Decor", mat),
            f.finalize(NAME + "_005_Waterfall_Water", mat)]


def build_petals(mat):
    """One Petal pile to pick up at a patch spot: a soft mound of pink petals with a glowing blossom on top."""
    b, glow = RB(), RB()
    b.ball((0, 0.3, 0), 1.0, "fur_rose", scale=(1.0, 0.3, 1.0))
    b.ball((0.3, 0.22, 0.25), 0.55, "blush", scale=(1.0, 0.4, 1.0))
    b.ball((-0.35, 0.2, -0.2), 0.5, "apron_pink", scale=(1.0, 0.4, 1.0))
    for k in range(5):                                                                    # the glowing blossom
        a = math.radians(90 + 72 * k)
        glow.ball((0.38 * math.cos(a), 1.2 + 0.38 * math.sin(a), 0), 0.3, "blush", scale=(1.0, 1.0, 0.4))
    glow.ball((0, 1.2, -0.05), 0.17, "pastel_butter")
    return [b.finalize(PETALS, mat), glow.finalize(PETALS + "_Glow", mat)]


def build_stall(mat):
    """The Blossom Stall: a wooden stall with a red curved roof and a string of lit paper lanterns, the two hats on
    stands and the four decor pieces on show, a BLOSSOM STALL board. Front -Z, 12 wide."""
    b, glow, water = RB(), RB(), RB()
    b.span((-5.5, 0, -1.6), (5.5, 3.2, 1.6), "caramel_wood")                                # the counter
    b.span((-5.8, 3.2, -1.9), (5.8, 3.5, 1.9), WOODD)
    for k in range(4):
        b.span((-5.4, 0.3 + 0.75 * k, -1.66), (5.4, 0.36 + 0.75 * k, -1.6), "fur_toffee")
    for sx in (-1, 1):
        b.span((sx * 5.4 - 0.3, 3.5, 1.2), (sx * 5.4 + 0.3, 9.0, 1.8), RED)                   # red posts
        b.span((sx * 5.4 - 0.25, 3.5, -1.75), (sx * 5.4 + 0.25, 8.0, -1.25), RED)
    for k in range(9):                                                                     # the roof, ends turned up
        t = (k - 4) / 4.0
        x = t * 6.3
        y = 8.7 + 0.5 * t * t
        b.box((x, y, 0.0), (1.5, 0.35, 4.4), ROOF, rot=rot_z(-12 * t))
        b.box((x, y + 0.3, 0.0), (1.5, 0.25, 3.2), "fur_gunmetal", rot=rot_z(-12 * t))
    for k in range(5):                                                                     # paper lanterns, lit
        x = -4.4 + 2.2 * k
        b.box((x, 7.95, -1.9), (0.04, 0.5, 0.04), "choco")
        glow.ball((x, 7.35, -1.9), 0.32, (RED, "fur_strawberry", "gold_mid")[k % 3], scale=(1.0, 1.2, 1.0))
    b.span((-4.2, 9.9, 1.4), (4.2, 11.6, 1.7), WOODD)                                       # the board
    b.span((-3.9, 10.1, 1.34), (3.9, 11.4, 1.4), "cream")
    b.text("BLOSSOM STALL", (3.0, 10.45, 1.34), 0.09, 0.04, RED, right=(-1, 0, 0))
    for k, x in enumerate((-4.3, -2.6)):                                                    # the two hats on stands
        b.cyl((x, 4.1, 0.2), 0.12, 1.2, WOODD, segments=6)
        b.ball((x, 4.9, 0.2), 0.5, "cream")
        if k == 0:                                                                          # Flower Crown
            for j in range(8):
                a = 2 * math.pi * j / 8
                b.ball((x + 0.48 * math.cos(a), 5.3, 0.2 + 0.48 * math.sin(a)), 0.15, PINK[j % len(PINK)])
        else:                                                                               # Lantern Hat
            glow.cyl((x, 5.6, 0.2), 0.45, 0.6, RED, segments=10)
            b.cyl((x, 5.27, 0.2), 0.38, 0.08, "gold_mid", segments=10)
            b.cyl((x, 5.94, 0.2), 0.32, 0.08, "gold_mid", segments=10)
    for k in range(10):                                                                     # a little koi pond
        a = 2 * math.pi * k / 10
        b.ball((-0.6 + 0.75 * math.cos(a), 3.6, 0.0 + 0.55 * math.sin(a)), 0.16, STONE)
    water.cyl((-0.6, 3.56, 0.0), 0.65, 0.04, "fish_blue", segments=10)
    b.ball((-0.75, 3.6, 0.1), 0.1, "fur_orange", scale=(2.0, 0.6, 0.8))
    b.cyl((1.2, 4.1, 0.0), 0.08, 1.2, "fur_bramble", segments=6)                           # a blossom tree
    for (dx, dy, r, sw) in ((0, 1.0, 0.45, "blush"), (-0.3, 0.8, 0.32, "fur_rose"), (0.3, 0.85, 0.32, "apron_pink")):
        b.ball((1.2 + dx, 4.1 + dy, 0.0), r, sw)
    b.span((2.2, 3.5, -0.4), (3.4, 3.7, 0.4), WOODD)                                        # a tea set
    b.cyl((2.55, 3.85, 0.0), 0.16, 0.3, "fur_sand", segments=8)
    for x in (3.0, 3.25):
        b.cyl((x, 3.78, -0.15), 0.07, 0.12, "milk", segments=6)
    for sx in (3.9, 5.1):                                                                   # a lantern string
        b.cyl((sx, 4.4, 0.2), 0.05, 1.8, WOODD, segments=6)
    for k in range(3):
        glow.ball((4.1 + 0.4 * k, 4.95 - 0.12 * (k == 1), 0.2), 0.14, (RED, "gold_mid", RED)[k])
    for sx in (-1, 1):                                                                      # cherry trees beside it
        _rb_tree(b, sx * 8.0, 0.5, 7.5)
    return [b.finalize(STALL, mat), glow.finalize(STALL + "_Glow", mat), water.finalize(STALL + "_Water", mat)]


def _rb_tree(b, x, z, h):
    b.cyl((x, h * 0.3, z), 0.4, h * 0.6, "fur_bramble", r2=0.3, segments=8)
    for (dx, dy, dz, r, sw) in ((0, 0.75, 0, 0.34, "blush"), (-0.3, 0.62, 0.2, 0.25, "fur_rose"),
                                (0.32, 0.64, -0.15, 0.26, "apron_pink")):
        b.ball((x + dx * h, dy * h, z + dz * h), r * h, sw)


def _rb_blossom(b, x, z, h, rnd):
    """A small cherry tree in Roblox axes, base centre at (x, 0, z)."""
    b.cyl((x, h * 0.3, z), 0.55, h * 0.6, "fur_bramble", r2=0.4, segments=8)
    for (dx, dy, dz, r) in ((0, 0.75, 0, 0.36), (-0.32, 0.6, 0.2, 0.26), (0.34, 0.62, -0.15, 0.27), (0.05, 0.92, 0.1, 0.22)):
        b.ball((x + dx * h, dy * h, z + dz * h), r * h, rnd.choice(PINK))


def build_portal(mat):
    """The Town Square portal: a red torii gate under two cherry trees, its way in glowing pink. The sign's face is
    `_Screen` (8.0 x 2.6, front -Z, the same size as the Snowglobe portal's) so the UI text reads "Opens at Tier 2"
    or "Open until ..."."""
    b, glow, screen, portal = RB(), RB(), RB(), RB()
    rnd = random.Random(11)
    b.span((-7.5, 0.0, -3.0), (7.5, 0.35, 3.0), STONE)                                   # the stone step
    b.span((-6.5, 0.35, -2.4), (6.5, 0.6, 2.4), "fur_oat")
    for sx in (-1, 1):
        x = sx * 4.6
        b.cyl((x, 0.95, 0), 1.05, 0.7, "dark_wood", segments=10)                          # black feet
        b.cyl((x, 6.1, 0), 0.75, 9.6, RED, r2=0.68, segments=10)                          # the pillars
    b.span((-6.4, 8.9, -0.45), (6.4, 9.7, 0.45), RED)                                    # the lower beam (nuki)
    b.span((-0.45, 9.7, -0.4), (0.45, 11.1, 0.4), RED)                                   # the strut to the top
    for k in range(9):                                                                   # the top beam, ends turned up
        t = (k - 4) / 4.0
        x = t * 7.4
        y = 11.4 + 0.55 * t * t
        b.box((x, y, 0), (1.75, 0.6, 1.2), RED, rot=rot_z(-14 * t))
        b.box((x, y + 0.45, 0), (1.8, 0.35, 1.4), "dark_wood", rot=rot_z(-14 * t))
    portal.span((-3.5, 0.6, -0.1), (3.5, 8.85, 0.1), "blush")                             # the glowing way in
    for sx in (-1, 1):                                                                   # the sign on two short posts
        b.span((sx * 2.8 - 0.2, 11.9, -0.2), (sx * 2.8 + 0.2, 12.7, 0.2), RED)
    b.span((-4.6, 12.5, -0.35), (4.6, 15.5, 0.35), "dark_wood")
    screen.span((-4.0, 12.7, -0.42), (4.0, 15.3, -0.35), "night_sky")
    b.span((-4.9, 15.5, -0.6), (4.9, 15.85, 0.6), RED)
    for sx in (-1, 1):                                                                   # lanterns on the pillars
        b.span((sx * 4.6 - 0.12, 6.6, -1.3), (sx * 4.6 + 0.12, 6.8, -0.7), "dark_wood")
        glow.cyl((sx * 4.6, 5.9, -1.4), 0.55, 1.2, "lamp_warm", segments=8)
        b.cyl((sx * 4.6, 6.6, -1.4), 0.65, 0.2, "dark_wood", segments=8)
        b.cyl((sx * 4.6, 5.2, -1.4), 0.6, 0.2, "dark_wood", segments=8)
    for sx in (-1, 1):                                                                   # stone lanterns at its feet
        x = sx * 8.6
        b.span((x - 0.9, 0.35, -2.3), (x + 0.9, 0.75, -0.5), STONE)
        b.cyl((x, 1.75, -1.4), 0.35, 2.0, STONE, segments=8)
        b.span((x - 0.7, 2.75, -2.1), (x + 0.7, 3.95, -0.7), STONE)
        glow.span((x - 0.45, 3.0, -2.15), (x + 0.45, 3.7, -0.65), "lamp_warm")
        b.span((x - 1.1, 3.95, -2.5), (x + 1.1, 4.3, -0.3), STONE)
        b.cyl((x, 4.6, -1.4), 0.35, 0.6, STONE, r2=0.1, segments=6)
    for sx in (-1, 1):                                                                   # cherry trees each side
        _rb_blossom(b, sx * 11.0, 1.8, 10.5, rnd)
    for k in range(26):                                                                  # petals on the step
        x, z = rnd.uniform(-7, 7), rnd.uniform(-2.8, 2.8)
        if abs(x) < 3.6 and abs(z) < 0.5:
            continue
        b.box((x, 0.62, z), (0.5, 0.04, 0.5), rnd.choice(PINK), rot=rot_z(rnd.uniform(0, 90)))
    return [b.finalize(PORTAL, mat), glow.finalize(PORTAL + "_Glow", mat), screen.finalize(PORTAL + "_Screen", mat),
            portal.finalize(PORTAL + "_Portal_Glow", mat)]


ASSETS = {
    NAME: (build_cherry_set, 150000),
    PORTAL: (build_portal, 6000),
    STALL: (build_stall, 4500),
    PETALS: (build_petals, 600),
}
