"""Harvest Hollow (#4251), the limited autumn area, Wed Nov 25 to Sun Dec 6 2026 (Derek OK'd it on 2026-11-14;
Design-Agent's harvest-hollow-spec.md section 2): about the size of the Park, 150 x 120, golden hour. Players arrive
by the Town Square arch (a teleport), so the set has no way in: a rail fence and a line of autumn trees all round.

  CatCafe_Harvest_Set      the area dressed, in area space (areakit): place it at the area's centre on its floor. The
                           arrival end is -Z. Zones, arrival first:
                             z -56 to -40   Arrival: the spawn at (0, -55) facing +Z, the creek across the width
                                            (flat `_Water`, no kerb) and the plank bridge on the path
                             the middle     the feast plaza round (0, 2): ten lamp posts with string lights, the
                                            long feast table, the Thankful Board's spot on its far side
                             x > 20, z < 0  the Pumpkin Patch: five soil rows, the 12 pumpkin spots, the Giant
                                            Pumpkin with its lit door, a wheelbarrow
                             x < -20, z < 0 the Orchard: eight apple trees with crates, the cider stand
                             x > 20, z > 0  the red barn (hollow, a 10 wide open door facing -Z), its silo, the
                                            Harvest Stall's spot by it
                             x < -20, z > 0 the corn maze, 14 x 11 cells of 3.5 with walls 9 high, the nook in its
                                            middle, a scarecrow outside
                             z 44           the windmill; its sails are `_Windmill_Sails_Spin` (Effects/Motion)
  CatCafe_Harvest_Arch     the Town Square portal: two hay bale piers, a beam with a leaf garland, a sign board
                           whose face is the `_Screen` part (8.0 x 2.6, Front -Z: "HARVEST HOLLOW" and the small
                           line the UI changes), pumpkins and corn at its feet. The way through is 9 wide, 8.6 high.
  CatCafe_Harvest_Stall    the Harvest Stall: a red and cream market stall with a striped awning, pumpkins, apples
                           and two hats on stands, a HARVEST STALL board. Front -Z, 12 wide.
  CatCafe_Harvest_Board    the Thankful Board: a roofed chalkboard on two posts whose face is the `_Screen` part
                           (10.0 x 5.6, Front -Z: the UI draws the Feast Pie's eight slices and the notes), a pie on
                           its shelf and pumpkins at its feet.
  CatCafe_Harvest_Pumpkin  one pumpkin to pick up at a patch spot (base centre at the pivot, 2.2 across).

Nothing invisible stands inside the area: the only _Barrier is the 30 high ring in the fence band. Lights are `_Glow`,
the creek `_Water`, fallen leaves and string light cables `_Decor` (no collision).

Points (manifest points_roblox, area space [x, y, z]): `player_spawn` (1, with a turn), `spawn` (14 stray spots: patch,
orchard, barn, maze and the edges, no two within 12), `nook` (1, the maze's middle: Rare or better), `pumpkin` (12,
the patch's pickup spots, on top of its three middle soil rows), `stall` and `board` (where those two models stand, each with its turn). The feast table stands at (0, -4).
"""

import math
import random

from mathutils import Matrix

import areakit
from common import RB, Builder
from plot import rot_x, rot_y, rot_z

NAME = "CatCafe_Harvest_Set"
N = "CatCafe_Harvest_"
ARCH, STALL, BOARD, PUMPKIN = N + "Arch", N + "Stall", N + "Board", N + "Pumpkin"
HALF_X, HALF_Z = 75.0, 60.0
G = 0.03                                    # the ground slab's top
BARRIER_H = 30.0
CELL, WALL_H = 3.5, 9.0
AUT = ("fur_marmalade", "bowl_red", "fur_golden", "fur_ginger", "fur_rust_red", "eye_amber")
SOIL, PATH, PLAZA = "fur_toffee", "fur_oat", "fur_vanilla"

# Everything below is laid out in Blender axes (x, y, z up); Roblox area space is (-x, z, y), so a point here at
# (x, y) is reported as [-x, height, y].
BARN = (-46.0, 30.0)
MAZE_C = (46.0, 30.0)
PATCH = (-46.0, -26.0)
ORCHARD = (46.0, -26.0)
MILL = (0.0, 44.0)
MAZE = ["#########.####",
        "#....#.......#",
        "#.##.#.###.#.#",
        "#.#....#...#.#",
        "#.#.####.###.#",
        "#...#......#.#",
        "###.#.####.#.#",
        "#...#....#...#",
        "#.######.#.###",
        "#............#",
        "######.#######"]
MOVING = {NAME: {"pivot_turns": {"_Spin": Matrix.Rotation(math.radians(-90), 3, "X")},
                 "model_attributes": {"_Spin": {"Seconds": {"Float64": 16.0}}}}}


def rz(d):
    return (math.radians(d), "Z")


def rx(d):
    return (math.radians(d), "X")


def ry(d):
    return (math.radians(d), "Y")


def _cell(r, c):
    """Blender (x, y) of the middle of maze cell (row r from the far side, column c)."""
    return MAZE_C[0] - (len(MAZE[0]) - 1) / 2 * CELL + c * CELL, MAZE_C[1] + (len(MAZE) - 1) / 2 * CELL - r * CELL


def _pumpkin(b, c, r, sw="fur_marmalade"):
    x, y, z = c
    for k in range(6):
        a = math.radians(60 * k)
        b.ico((x + 0.42 * r * math.cos(a), y + 0.42 * r * math.sin(a), z + r * 0.6), r * 0.68, sw, scale=(1, 1, 0.85))
    b.box((x, y, z + r * 1.3), (r * 0.25, r * 0.25, r * 0.4), "leaf_dark", bevel=False)


def _bale(b, x, y, z=G, rot=0):
    b.box_base((x, y, z), (3.2, 2.0, 1.8), "fur_sand", bevel=False, rot=rz(rot))
    b.box_base((x, y, z + 0.6), (3.26, 2.06, 0.12), "bowl_red", bevel=False, rot=rz(rot))
    b.box_base((x, y, z + 1.2), (3.26, 2.06, 0.12), "bowl_red", bevel=False, rot=rz(rot))


def _tree(b, rnd, x, y, h=None, sw=None):
    h = h or rnd.uniform(9, 13)
    areakit.tree_round(b, x, y, G, h, h * 0.36, sw or rnd.choice(AUT), "fur_bramble")


def _ground(b):
    W, D = 2 * HALF_X, 2 * HALF_Z
    b.box_base((0, 0, 0), (W, D, G), "fur_sand", bevel=False)
    b.cyl_base((0, 2, G), 24, 0.05, PATH, segments=28, bevel=False)                        # the feast plaza
    b.cyl_base((0, 2, G), 20, 0.08, PLAZA, segments=28, bevel=False)
    b.box_base((0, -39, G), (9, 36, 0.04), PATH, bevel=False)                              # the path from the bridge
    for (x, y, r) in ((-28, 14, -25), (28, 14, 25), (-28, -12, 25), (28, -12, -25)):
        b.box_base((x, y, G), (26, 6, 0.045), PATH, bevel=False, rot=rz(r))                # to the four corners
    b.box_base((0, 34, G), (6, 16, 0.045), PATH, bevel=False)                              # to the windmill
    b.box_base((PATCH[0], PATCH[1], G), (40, 30, 0.06), SOIL, bevel=False)
    b.box_base((MAZE_C[0], MAZE_C[1], G), (len(MAZE[0]) * CELL + 2, len(MAZE) * CELL + 2, 0.06), SOIL, bevel=False)


def _border(b, rnd):
    W, D = 2 * HALF_X, 2 * HALF_Z
    for k in range(int(W / 5)):                                                             # the rail fence
        x = -W / 2 + 2.5 + k * 5
        for y in (-D / 2 + 1.5, D / 2 - 1.5):
            b.box_base((x, y, G), (0.5, 0.5, 3.2), "dark_wood", bevel=False)
            if k < int(W / 5) - 1:
                b.box_base((x + 2.5, y, 1.4), (5, 0.25, 0.4), "caramel_wood", bevel=False)
                b.box_base((x + 2.5, y, 2.5), (5, 0.25, 0.4), "caramel_wood", bevel=False)
    for k in range(int(D / 5)):
        y = -D / 2 + 2.5 + k * 5
        for x in (-W / 2 + 1.5, W / 2 - 1.5):
            b.box_base((x, y, G), (0.5, 0.5, 3.2), "dark_wood", bevel=False)
            if k < int(D / 5) - 1:
                b.box_base((x, y + 2.5, 1.4), (0.25, 5, 0.4), "caramel_wood", bevel=False)
                b.box_base((x, y + 2.5, 2.5), (0.25, 5, 0.4), "caramel_wood", bevel=False)
    for k in range(15):                                                                     # autumn trees inside it
        _tree(b, rnd, -W / 2 + 7 + k * 9.7 + rnd.uniform(-1, 1), D / 2 - 6 + rnd.uniform(-1, 1), rnd.uniform(12, 17))
    for k in range(9):
        for sx in (-1, 1):
            y = -D / 2 + 8 + k * 12
            if abs(y - 28) < 14 and sx < 0:
                continue                                                                    # the barn and silo stand there
            _tree(b, rnd, sx * (W / 2 - 6) + rnd.uniform(-1, 1), y + rnd.uniform(-2, 2))
    for x in (-60, -48, -34, -20, 20, 34, 48, 60):
        _tree(b, rnd, x, -D / 2 + 6, rnd.uniform(8, 11))


def _barrier(mat):
    bar = Builder()
    T = 1.6
    for sy in (-1, 1):
        bar.box_base((0, sy * (HALF_Z - 0.2 - T / 2), 0), (2 * HALF_X, T, BARRIER_H), "offwhite", bevel=False)
    for sx in (-1, 1):
        bar.box_base((sx * (HALF_X - 0.2 - T / 2), 0, 0), (T, 2 * HALF_Z - 2 * T - 0.4, BARRIER_H), "offwhite", bevel=False)
    return bar.finalize(NAME + "_001_Fence_Barrier", mat)


def _barn(b, g):
    bx, by = BARN
    W, D, H, T = 28.0, 20.0, 13.0, 1.0
    b.box_base((bx, by, G), (W - 0.4, D - 0.4, 0.1), "caramel_wood", bevel=False)          # a board floor
    b.box_base((bx, by + D / 2 - T / 2, G), (W, T, H), "fur_rust_red", bevel=False)        # back
    for sx in (-1, 1):
        b.box_base((bx + sx * (W / 2 - T / 2), by, G), (T, D - 2 * T, H), "fur_rust_red", bevel=False)   # sides
        b.box_base((bx + sx * 9.5, by - D / 2 + T / 2, G), (9.0, T, H), "fur_rust_red", bevel=False)    # front, by the door
    b.box_base((bx, by - D / 2 + T / 2, 9.0), (10.0, T, H - 9.0 + G), "fur_rust_red", bevel=False)      # over the door
    areakit.gable(b, bx, by, H + G, W, D, 9, "fur_rust_red", "fur_seal", over=1.2, thick=0.8)
    for dx in (-5.2, 5.2):                                                                  # the door's white trim
        b.box_base((bx + dx, by - D / 2 - 0.1, G), (0.7, 0.3, 9), "milk", bevel=False)
    b.box_base((bx, by - D / 2 - 0.1, 9.0), (11.1, 0.3, 0.7), "milk", bevel=False)
    for sx in (-1, 1):                                                                      # the doors, swung open
        b.box_base((bx + sx * 7.4, by - D / 2 - 2.0, G), (0.4, 4.6, 8.6), "fur_russet", bevel=False, rot=rz(sx * 25))
        b.box((bx + sx * 7.5, by - D / 2 - 2.0, 4.4), (0.3, 5.6, 0.6), "milk", bevel=False, rot=rz(sx * 25))
    b.box((bx, by - D / 2 - 0.2, 17.5), (4.2, 0.4, 4.2), "milk", bevel=False)              # the loft window
    g.box((bx, by - D / 2 - 0.4, 17.5), (3.2, 0.3, 3.2), "lamp_warm", bevel=False)
    for dx in (-10.5, 10.5):
        b.box((bx + dx, by - D / 2 - 0.2, 7), (3.6, 0.4, 4.2), "milk", bevel=False)
        g.box((bx + dx, by - D / 2 - 0.4, 7), (2.8, 0.3, 3.4), "lamp_warm", bevel=False)
    for (x, y, z) in ((bx - 9, by + 6, G + 0.1), (bx - 5.6, by + 6, G + 0.1), (bx - 7.3, by + 6, 1.93), (bx + 9, by + 5, G + 0.1)):
        _bale(b, x, y, z)                                                                   # bales inside
    g.ico((bx, by, 10.5), 0.7, "lamp_warm")                                                 # a lantern from the beam
    b.box((bx, by, 12.0), (0.15, 0.15, 2.4), "dark_wood", bevel=False)
    b.cyl_base((bx - 19, by + 4, G), 5, 20, "fur_pewter", segments=14, bevel=False)        # the silo
    b.cyl_base((bx - 19, by + 4, 20 + G), 5.3, 3.5, "fur_rust_red", segments=14, bevel=False, radius2=0.6)
    for (x, y, z) in ((bx - 6, by - 14, G), (bx - 2.6, by - 14, G), (bx - 4.3, by - 14, 1.83)):
        _bale(b, x, y, z)


def _maze(b, g):
    for r_, row in enumerate(MAZE):
        for c_, ch in enumerate(row):
            if ch == "#":
                x, y = _cell(r_, c_)
                h = WALL_H + ((r_ * 5 + c_ * 3) % 4) * 0.4
                b.box_base((x, y, G), (CELL - 0.3, CELL - 0.3, h), "leaf_dark" if (r_ + c_) % 2 else "leaf_green",
                           bevel=False)
                b.box_base((x, y, G + h), (CELL - 0.9, CELL - 0.9, 1.0), "fur_golden", bevel=False)
    sx_, sy_ = _cell(0, 9)                                                                  # the way in, far side
    b.box_base((sx_ - 3.5, sy_ + 3.0, G), (0.5, 0.5, 12), "dark_wood", bevel=False)
    b.box((sx_, sy_ + 3.0, 12.6), (9.5, 0.5, 3.0), "caramel_wood", bevel=False)
    g.box((sx_, sy_ + 2.7, 12.6), (8.6, 0.2, 2.2), "eye_amber", bevel=False)
    b.box_base((sx_ + 3.5, sy_ + 3.0, G), (0.5, 0.5, 12), "dark_wood", bevel=False)
    nx, ny = _cell(4, 7)                                                                    # the nook's star, on the wall
    b.box_base((nx, ny, G + WALL_H + 1.0), (0.4, 0.4, 3.4), "dark_wood", bevel=False)      # behind it
    g.star((nx, ny, WALL_H + 5.6), 1.6, 0.75, 0.5, "rarity_legend", rot=rx(90))
    x, y = 22.0, 52.0                                                                       # a scarecrow outside
    b.box_base((x, y, G), (0.5, 0.5, 8), "dark_wood", bevel=False)
    b.box((x, y, 6.2), (7, 0.5, 0.5), "dark_wood", bevel=False)
    b.box((x, y, 5.4), (3, 1.4, 3.2), "fish_blue", bevel=False)
    b.ico((x, y, 8.6), 1.5, "fur_oat")
    b.cyl_base((x, y, 9.4), 2.4, 0.3, "fur_sand", segments=12, bevel=False)
    b.cyl_base((x, y, 9.6), 1.3, 1.6, "fur_sand", segments=10, bevel=False, radius2=0.9)


def _patch(b, g, d, rnd):
    px, py = PATCH
    for r_ in range(5):
        y = py - 12 + r_ * 6
        b.box_base((px, y, G + 0.06), (38, 2.2, 0.2), "fur_bramble", bevel=False)           # a soil row
        for c_ in range(10):                                                                # vines and leaves along it
            x = px - 17.5 + c_ * 3.9 + rnd.uniform(-0.5, 0.5)
            d.box((x, y + rnd.uniform(-0.7, 0.7), G + 0.33), (1.3, 0.9, 0.12), "leaf_green", bevel=False,
                  rot=rz(rnd.uniform(0, 90)))
    for (x, y, r, sw) in ((px - 18.5, py - 14.2, 0.9, "fur_custard"), (px + 18.5, py + 14.2, 1.1, "fur_ginger"),
                          (px + 18.6, py - 14.0, 0.8, "fur_marmalade"), (px - 18.6, py + 14.0, 1.0, "fur_marmalade")):
        _pumpkin(b, (x, y, G + 0.06), r, sw)                                                # one at each corner
    gx, gy = px + 12, py + 22                                                               # the Giant Pumpkin, behind it
    for k in range(8):
        a = math.radians(45 * k)
        b.ico((gx + 3.2 * math.cos(a), gy + 3.2 * math.sin(a), 5.2), 5.4, "fur_marmalade" if k % 2 else "fur_ginger",
              scale=(1, 1, 0.95))
    b.box((gx, gy, 11.2), (1.6, 1.6, 2.6), "leaf_dark", bevel=False, rot=ry(12))
    b.box((gx + 2.4, gy, 11.0), (3.6, 2.2, 0.3), "leaf_green", bevel=False, rot=ry(-15))
    b.box_base((gx, gy - 8.0, G), (3.4, 0.8, 5.2), "fur_seal", bevel=False)                # its door
    g.box((gx, gy - 8.3, 2.8), (2.4, 0.4, 4.4), "lamp_warm", bevel=False)
    for dx in (-4.4, 4.4):
        g.box((gx + dx, gy - 7.0, 6.4), (1.8, 0.5, 1.8), "lamp_warm", bevel=False, rot=ry(45))
    wx, wy = px + 23.5, py + 2                                                              # a wheelbarrow
    b.box_base((wx, wy, 1.2), (4.5, 3, 1.6), "caramel_wood", bevel=False)
    b.cyl((wx + 2.6, wy, 1.0), 1.0, 0.5, "dark_wood", segments=10, bevel=False, rot=rx(90))
    b.box_base((wx - 1.6, wy, G), (0.4, 2.6, 1.2), "dark_wood", bevel=False)
    _pumpkin(b, (wx - 0.8, wy, 2.8), 1.0)
    _pumpkin(b, (wx + 1.0, wy + 0.3, 2.8), 0.8, "fur_custard")


def _orchard(b, g):
    ox, oy = ORCHARD
    for r_ in range(2):
        for c_ in range(4):
            x, y = ox - 15 + c_ * 10, oy - 8 + r_ * 14
            areakit.tree_round(b, x, y, G, 10, 3.9, "leaf_green", "fur_bramble")
            for k in range(7):
                a = k * 0.9 + c_
                b.ico((x + 3.4 * math.cos(a), y + 3.4 * math.sin(a) * 0.9 - 0.6, 6.2 + 1.6 * math.sin(k * 2.1)), 0.6,
                      "bowl_red")
            b.box_base((x + 3, y - 3, G), (1.8, 1.8, 1.3), "caramel_wood", bevel=False)
            for k in range(3):
                b.ico((x + 2.6 + k * 0.5, y - 3 + 0.3 * (k % 2), 1.6), 0.5, "bowl_red")
    cx, cy = ox - 22, oy - 2                                                                # the cider stand
    b.box_base((cx, cy, G), (8, 5, 3.2), "caramel_wood", bevel=False)
    for dx in (-3.6, 3.6):
        b.box_base((cx + dx, cy + 2, G), (0.4, 0.4, 8), "dark_wood", bevel=False)
    b.box_base((cx, cy, 8.1), (9.4, 6.4, 0.5), "fur_rust_red", bevel=False, rot=rx(-10))
    b.cyl((cx - 2, cy, 4.55), 1.3, 2.6, "fur_acorn", segments=10, bevel=False, rot=ry(90))
    for dx in (1.4, 2.8):
        b.cyl_base((cx + dx, cy - 1, 3.23), 0.5, 1.0, "fur_vanilla", segments=8, bevel=False)


def _arrival(b, g, w):
    for k in range(50):                                                                     # the creek
        x = -HALF_X + 1.5 + k * 3
        y = -47 + 3.2 * math.sin(x / 11.0)
        b.box_base((x, y, G), (3.4, 7.5, 0.05 + 0.004 * (k % 2)), "fur_bramble", bevel=False)
        w.box_base((x, y, G + 0.06), (3.4, 5.4, 0.1 + 0.004 * (k % 2)), "fish_blue", bevel=False)
        if k % 7 == 3:
            b.ico((x, y + 3.4, 0.4), 0.9, "fur_pewter", scale=(1, 1, 0.6))
        if k % 9 == 5:
            w.box_base((x, y + 0.8, G + 0.17), (1.4, 0.5, 0.03), "fish_belly", bevel=False)
    for k in range(9):                                                                      # the bridge: low planks
        t = (k - 4) / 4
        b.box_base((0, -47 + t * 5.2, 0.1 + 0.55 * (1 - t * t)), (8.5, 1.4, 0.45), "caramel_wood", bevel=False,
                   rot=rx(-t * 9))
    for sx in (-1, 1):
        for t in (-1, 0, 1):
            b.box_base((sx * 4.1, -47 + t * 4.6, G), (0.5, 0.5, 3.4 + 0.6 * (1 - t * t)), "dark_wood", bevel=False)
        b.box((sx * 4.1, -47, 3.5), (0.35, 9.6, 0.4), "dark_wood", bevel=False)
    b.box_base((-7.5, -54.5, G), (0.5, 0.5, 6), "dark_wood", bevel=False)                  # the welcome board
    b.box_base((-13.5, -54.5, G), (0.5, 0.5, 6), "dark_wood", bevel=False)
    b.box((-10.5, -54.5, 4.9), (7.2, 0.5, 3.0), "caramel_wood", bevel=False)
    b.box((-10.5, -54.2, 4.9), (6.4, 0.2, 2.2), "fur_vanilla", bevel=False)
    _pumpkin(b, (-6.2, -53.6, G), 0.9)
    wx, wy = 14, -38                                                                        # the hay wagon
    b.box_base((wx, wy, 1.8), (11, 5.4, 0.5), "caramel_wood", bevel=False)
    for dx in (-3.6, 3.6):
        for dy in (-3, 3):
            b.cyl((wx + dx, wy + dy, 1.73), 1.7, 0.5, "dark_wood", segments=12, bevel=False, rot=rx(90))
    for dx, z in ((-3.4, 2.3), (0, 2.3), (3.4, 2.3), (-1.7, 4.1), (1.7, 4.1)):
        b.box_base((wx + dx, wy, z), (3.2, 4.4, 1.8), "fur_sand", bevel=False)
    _pumpkin(b, (wx + 1.7, wy, 5.9), 1.2)
    b.box((wx - 7.5, wy, 2.0), (4.5, 0.4, 0.4), "dark_wood", bevel=False)


def _windmill(b, g, mat):
    vx, vy = MILL
    b.cyl_base((vx, vy, G), 6, 22, "fur_vanilla", segments=10, bevel=False, radius2=3.8)
    b.cyl_base((vx, vy, 22 + G), 4.6, 5, "fur_rust_red", segments=10, bevel=False, radius2=0.8)
    b.box_base((vx, vy - 6.0, G), (3, 0.6, 5), "fur_seal", bevel=False)
    g.box((vx, vy - 4.9, 12), (2, 0.5, 2.6), "lamp_warm", bevel=False)
    b.cyl((vx, vy - 5.2, 19.5), 0.8, 2.0, "dark_wood", segments=8, bevel=False, rot=rx(90))
    hub = (vx, vy - 6.6, 19.5)
    sails = Builder()
    sails.cyl((0, 0, 0), 1.0, 0.8, "dark_wood", segments=8, bevel=False, rot=rx(90))
    for k in range(4):
        a = 20 + 90 * k
        ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
        sails.box((7 * ca, -0.1, 7 * sa), (13, 0.3, 2.6), "fur_oat", bevel=False, rot=ry(-a))
        sails.box((7 * ca, 0.25, 7 * sa), (13.6, 0.3, 0.5), "dark_wood", bevel=False, rot=ry(-a))
    return sails.finalize(NAME + "_005_Windmill_Sails_Spin", mat, location=hub)


def _plaza(b, g, d):
    n = 10
    for k in range(n):
        a = 2 * math.pi * (k + 0.5) / n
        x, y = 24 * math.cos(a), 2 + 24 * math.sin(a)
        b.cyl_base((x, y, G), 0.3, 7, "dark_wood", segments=8, bevel=False)                 # a lamp post
        g.ico((x, y, 7.8), 0.8, "lamp_warm")
        a2 = 2 * math.pi * (k + 1.5) / n
        x2, y2 = 24 * math.cos(a2), 2 + 24 * math.sin(a2)
        for j in range(1, 5):
            t = j / 5
            g.ico((x + (x2 - x) * t, y + (y2 - y) * t, 7.2 - 1.6 * math.sin(t * math.pi)), 0.32,
                  ("lamp_warm", "eye_amber", "bowl_red")[j % 3])
    tx, ty, L = 0.0, -4.0, 22.0                                                              # the feast table
    b.box_base((tx, ty, 2.6), (L, 4.2, 0.4), "caramel_wood", bevel=False)
    b.box_base((tx, ty, 3.0), (L - 1.0, 2.2, 0.06), "bowl_red", bevel=False)               # a runner
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box_base((tx + sx * (L / 2 - 1.2), ty + sy * 1.5, G), (0.6, 0.6, 2.6), "dark_wood", bevel=False)
        b.box_base((tx, ty + sx * 3.4, 1.3), (L - 2, 1.4, 0.35), "caramel_wood", bevel=False)   # benches
        for dx in (-(L / 2 - 2.5), 0.0, L / 2 - 2.5):
            b.box_base((tx + dx, ty + sx * 3.4, G), (0.5, 1.2, 1.3), "dark_wood", bevel=False)
    for k, dx in enumerate((-8.5, -5.0, -1.5, 2.0, 5.5, 9.0)):                              # the feast
        if k % 3 == 0:
            _pumpkin(b, (tx + dx, ty, 3.06), 0.6, ("fur_marmalade", "fur_custard")[k % 2])
        elif k % 3 == 1:
            b.cyl_base((tx + dx, ty, 3.06), 0.9, 0.3, "fur_croissant", segments=10, bevel=False)
            b.cyl_base((tx + dx, ty, 3.36), 0.75, 0.08, "fur_marmalade", segments=10, bevel=False)
        else:
            b.cyl_base((tx + dx, ty, 3.06), 0.7, 0.5, "fur_toffee", segments=10, bevel=False, radius2=0.85)
            for j in range(3):
                b.ico((tx + dx - 0.3 + 0.3 * j, ty + 0.15 * (j % 2), 3.75), 0.3, ("bowl_red", "leaf_green", "bowl_red")[j])
    for x, y, sw in ((-14, -22, "fur_marmalade"), (13, -20, "bowl_red"), (-22, 22, "fur_golden"), (24, -30, "fur_ginger"),
                     (-30, -40, "eye_amber"), (34, 6, "fur_rust_red")):                     # leaf piles
        d.ico((x, y, 0.2), 2.6, sw, scale=(1, 1, 0.4))
        d.ico((x + 1.6, y + 0.8, 0.2), 1.7, AUT[(int(x) + 3) % 6], scale=(1, 1, 0.45))
    for x, y in ((-10, -36), (-13, -34), (30, 53), (-22, 50)):
        _bale(b, x, y)


def _leaves(d, rnd):
    for k in range(70):
        x, y = rnd.uniform(-HALF_X + 5, HALF_X - 5), rnd.uniform(-HALF_Z + 5, HALF_Z - 5)
        d.box((x, y, G + 0.1 + 0.004 * (k % 5)), (0.8, 0.8, 0.05), rnd.choice(AUT), bevel=False, rot=rz(rnd.uniform(0, 90)))


def _points():
    """Area-space Roblox points: a Blender (x, y) here is Roblox (-x, y)."""
    def rb(x, y, h=0.0, *more):
        return [round(-x, 2), round(h, 2), round(y, 2), *more]
    px, py = PATCH
    ox, oy = ORCHARD
    bx, by = BARN
    pts = {
        "player_spawn": [rb(0, -55.2, 0.0, 0)],
        "spawn": [rb(px - 10, py - 9), rb(px + 2, py - 3), rb(px + 10, py + 9),            # the patch, between rows
                  rb(ox - 10, oy - 1), rb(ox + 10, oy - 1), rb(ox + 20, oy + 13),          # the orchard
                  rb(bx - 8, by - 2), rb(bx + 6, by + 2),                                # in the barn
                  rb(*_cell(1, 2)), rb(*_cell(9, 3)), rb(*_cell(1, 11)),                  # in the maze
                  rb(-20, -36), rb(-22, 40), rb(16, 30)],                                  # by the wagon, the silo side, the mill
        "nook": [rb(*_cell(5, 7))],
        "pumpkin": [rb(px - 15 + 10 * c, py - 6 + 6 * r, 0.29) for r in range(3) for c in range(4)],
        "stall": [rb(bx + 22, by - 16, 0.0, 0)],
        "board": [rb(0, 16, 0.0, 0)],
    }
    spots = pts["spawn"] + pts["nook"]
    for i, a in enumerate(spots):
        for c in spots[i + 1:]:
            assert math.hypot(a[0] - c[0], a[2] - c[2]) >= 12.0, (a, c)
    assert len(pts["spawn"]) == 14 and len(pts["pumpkin"]) == 12
    return pts


def build_harvest_set(mat):
    rnd = random.Random(11)
    b, g, w, d = Builder(), Builder(), Builder(), Builder()
    _ground(b)
    _border(b, rnd)
    _barn(b, g)
    _maze(b, g)
    _patch(b, g, d, rnd)
    _orchard(b, g)
    _arrival(b, g, w)
    sails = _windmill(b, g, mat)
    _plaza(b, g, d)
    _leaves(d, rnd)
    areakit.POINTS[NAME] = _points()
    return [b.finalize(NAME, mat), _barrier(mat), g.finalize(NAME + "_002_Lights_Glow", mat),
            w.finalize(NAME + "_003_Creek_Water", mat), d.finalize(NAME + "_004_Leaves_Decor", mat), sails]


# ------------------------------------------------------------------------------------- the stand-alone pieces --
def _rb_pumpkin(b, c, r, sw="fur_marmalade"):
    x, y, z = c
    for k in range(6):
        a = math.radians(60 * k)
        b.ball((x + 0.42 * r * math.cos(a), y + r * 0.6, z + 0.42 * r * math.sin(a)), r * 0.68, sw, scale=(1, 0.85, 1))
    b.box((x, y + r * 1.22, z), (r * 0.24, r * 0.34, r * 0.24), "leaf_dark", rot=rot_z(10))


def _rb_bale(b, lo, hi):
    b.span(lo, hi, "fur_sand")
    (x0, y0, z0), (x1, y1, z1) = lo, hi
    for f in (0.3, 0.7):
        y = y0 + (y1 - y0) * f
        b.span((x0 - 0.03, y - 0.07, z0 - 0.03), (x1 + 0.03, y + 0.07, z1 + 0.03), "bowl_red")


def build_arch(mat):
    b, screen = RB(), RB()
    for sx in (-1, 1):
        x0, x1 = (4.5, 7.7) if sx > 0 else (-7.7, -4.5)
        for k in range(4):                                                                   # a pier of four bales
            o = 0.12 * (k % 2) * sx
            _rb_bale(b, (x0 + o, 2.15 * k, -1.1), (x1 + o, 2.15 * k + 2.1, 1.1))
        b.span((sx * 6.1 - 0.5, 8.6, -0.5), (sx * 6.1 + 0.5, 12.6, 0.5), "dark_wood")       # a post up to the sign
        _rb_pumpkin(b, (sx * 9.3, 0, -0.6), 1.3)
        _rb_pumpkin(b, (sx * 11.2, 0, 0.3), 0.8, "fur_custard")
        _rb_pumpkin(b, (sx * 3.6, 0, -1.5), 0.55, "fur_ginger")
        for k in range(3):                                                                   # corn stalks behind
            b.box((sx * (8.6 + 0.5 * k), 4.6, 1.0 + 0.2 * k), (0.2, 9.2, 0.2), ("fur_sand", "fur_custard")[k % 2],
                  rot=rot_z(-sx * (4 + 3 * k)))
            b.box((sx * (8.9 + 0.5 * k), 7.2 + 0.5 * k, 1.0 + 0.2 * k), (1.3, 0.1, 0.4), "leaf_green", rot=rot_z(sx * 30))
    b.span((-8.2, 8.6, -0.7), (8.2, 9.6, 0.7), "caramel_wood")                               # the beam
    for k in range(17):                                                                      # the leaf garland
        x = -7.6 + k * 0.95
        b.box((x, 8.45 - 0.5 * abs(math.sin(k * math.pi / 8)), -0.75 - 0.01 * (k % 3)), (0.9, 0.9, 0.14 + 0.01 * (k % 3)),
              AUT[k % 6], rot=rot_z(45))
    b.span((-4.5, 9.9, -0.35), (4.5, 13.3, 0.35), "dark_wood")                               # the sign's frame
    screen.span((-4.0, 10.3, -0.42), (4.0, 12.9, -0.35), "night_sky")
    _rb_pumpkin(b, (0, 13.3, 0), 0.8)
    b.box((1.0, 13.9, 0), (1.2, 0.1, 0.7), "leaf_green", rot=rot_z(20))
    return [b.finalize(ARCH, mat), screen.finalize(ARCH + "_Screen", mat)]


def build_stall(mat):
    b, glow = RB(), RB()
    b.span((-5.5, 0, -1.6), (5.5, 3.2, 1.6), "bowl_red")                                     # the counter
    b.span((-5.8, 3.2, -1.9), (5.8, 3.5, 1.9), "caramel_wood")
    for k in range(5):
        b.span((-5.0 + 2.2 * k, 0.5, -1.66), (-3.8 + 2.2 * k, 2.7, -1.6), "fur_cream")       # cream panels
    for sx in (-1, 1):
        b.span((sx * 5.4 - 0.25, 3.5, 1.2), (sx * 5.4 + 0.25, 9.4, 1.7), "dark_wood")        # awning posts
        b.span((sx * 5.4 - 0.2, 3.5, -1.7), (sx * 5.4 + 0.2, 8.2, -1.3), "dark_wood")
    for k in range(8):                                                                       # the striped awning
        b.box((-5.25 + 1.5 * k, 8.9, -0.4), (1.5, 0.25, 5.0), ("bowl_red", "fur_cream")[k % 2], rot=rot_x(-14))
        b.box((-5.25 + 1.5 * k, 7.75, -2.85), (1.5, 0.9, 0.14), ("bowl_red", "fur_cream")[k % 2])   # its valance
    b.span((-4.2, 9.9, 1.3), (4.2, 11.6, 1.6), "dark_wood")                                  # the board
    b.span((-3.9, 10.1, 1.24), (3.9, 11.4, 1.3), "fur_cream")
    b.text("HARVEST STALL", (3.55, 10.45, 1.24), 0.105, 0.04, "bowl_red", right=(-1, 0, 0))
    _rb_pumpkin(b, (-4.3, 3.5, -0.4), 0.8)                                                   # the goods
    _rb_pumpkin(b, (-2.7, 3.5, 0.2), 0.55, "fur_custard")
    b.cyl((-0.6, 3.85, -0.3), 0.75, 0.7, "fur_toffee", r2=0.9, segments=10)                 # a basket of apples
    for j, (dx, dz) in enumerate(((-0.3, -0.2), (0.3, 0.0), (0.0, 0.35), (0.0, -0.05))):
        b.ball((-0.6 + dx, 4.35 + 0.2 * (j == 3), -0.3 + dz), 0.33, ("bowl_red", "leaf_green", "bowl_red", "bowl_red")[j])
    for k, x in enumerate((1.6, 3.6)):                                                       # two hats on stands
        b.cyl((x, 4.1, 0.0), 0.12, 1.2, "dark_wood", segments=6)
        b.ball((x, 4.9, 0.0), 0.5, "fur_cream")
        if k == 0:
            b.cyl((x, 5.35, 0.0), 0.62, 0.2, "fur_toffee", segments=10)
            b.cyl((x, 5.55, 0.0), 0.45, 0.2, "fur_toffee", r2=0.2, segments=10)
        else:
            _rb_pumpkin(b, (x, 5.25, 0.0), 0.42)
    for sx in (-1, 1):                                                                       # lanterns under the awning
        b.box((sx * 4.4, 7.7, -1.5), (0.08, 1.0, 0.08), "dark_wood")
        glow.ball((sx * 4.4, 7.0, -1.5), 0.38, "lamp_warm")
    _rb_bale(b, (6.3, 0, -1.2), (9.5, 2.0, 0.8))                                             # a bale and a pumpkin beside it
    _rb_pumpkin(b, (7.6, 2.0, -0.2), 0.75)
    return [b.finalize(STALL, mat), glow.finalize(STALL + "_Glow", mat)]


def build_board(mat):
    b, screen = RB(), RB()
    for sx in (-1, 1):
        b.span((sx * 5.9 - 0.4, 0, -0.4), (sx * 5.9 + 0.4, 9.6, 0.4), "dark_wood")           # posts
        b.span((sx * 5.9 - 0.7, 0, -0.9), (sx * 5.9 + 0.7, 0.4, 0.9), "dark_wood")
        _rb_pumpkin(b, (sx * 7.3, 0, -0.6), 0.9, ("fur_marmalade", "fur_custard")[sx > 0])
    b.span((-5.6, 2.6, -0.3), (5.6, 9.2, 0.3), "caramel_wood")                               # the frame
    screen.span((-5.0, 3.1, -0.38), (5.0, 8.7, -0.3), "night_sky")                           # the chalkboard face
    for sx in (-1, 1):                                                                       # a little roof
        b.box((sx * 3.3, 10.3, 0), (7.2, 0.35, 2.4), "fur_rust_red", rot=rot_z(sx * -12))
    b.span((-0.4, 10.6, -1.25), (0.4, 11.2, 1.25), "fur_seal")
    b.span((-5.4, 1.9, -1.5), (5.4, 2.2, 0.3), "caramel_wood")                               # the shelf
    for sx in (-1, 1):
        b.box((sx * 4.6, 1.3, -0.6), (0.3, 1.4, 0.3), "dark_wood", rot=rot_x(35))
    b.cyl((0, 2.36, -0.7), 0.72, 0.32, "fur_pewter", r2=0.85, segments=12)                  # a pie on it
    b.cyl((0, 2.55, -0.7), 0.92, 0.1, "fur_croissant", segments=12)
    b.cyl((0, 2.6, -0.7), 0.75, 0.08, "fur_marmalade", segments=12)
    for o in (-0.35, 0.0, 0.35):
        b.box((o, 2.66, -0.7), (0.14, 0.05, 1.3 - abs(o)), "fur_croissant_dark")
        b.box((0, 2.68, -0.7 + o), (1.3 - abs(o), 0.05, 0.14), "fur_croissant")
    for k in range(9):                                                                       # leaves along the top
        b.box((-4.8 + 1.2 * k, 9.35, -0.36 - 0.01 * (k % 3)), (0.8, 0.8, 0.12), AUT[k % 6], rot=rot_z(45))
    return [b.finalize(BOARD, mat), screen.finalize(BOARD + "_Screen", mat)]


def build_pumpkin(mat):
    b = RB()
    _rb_pumpkin(b, (0, 0, 0), 1.1)
    b.box((0.45, 1.5, 0.0), (0.8, 0.08, 0.5), "leaf_green", rot=rot_z(18))
    b.box((-0.3, 1.55, 0.1), (0.1, 0.3, 0.1), "leaf_dark", rot=rot_z(-30))
    return [b.finalize(PUMPKIN, mat)]


ASSETS = {
    NAME: (build_harvest_set, 150000),
    ARCH: (build_arch, 4000),
    STALL: (build_stall, 4000),
    BOARD: (build_board, 4000),
    PUMPKIN: (build_pumpkin, 600),
}
