"""The Park set for town layout v3.2 (town-layout-v3.md section 8, F81): 160 x 120 of lawn behind the Park gate.

  CatCafe_Park_Set   the whole area dressed, in area space (areakit): place it at the area's centre on its floor,
                     with the Park's half turn, like the other sets. The gate is at z -60.

The way in (8b) winds about 1.6 times the straight walk. The gravel path leaves the gate through a small plaza, runs
east past flower beds to the only gap in the first hedge row (east end), comes back to the duck pond and rounds it on
both sides, leaves it to the north-west for the only gap in the second hedge row (west end), and ends on the loop
round the bandstand, the far landmark. The playground (west) and the rose garden (east) hang off the loop. The pond is
sunken behind a stone kerb and a grass bank, with an invisible `_Barrier` ring that only the jetty passes (8c).

The set brings its own walls just inside WorldBuilder's (whose inner faces stand at +-79.5 and +-59.5): the far and
side walls are runs of hedge, brick, iron railing and old stone 9 to 10 high between stone pillars; the town side is
a low plinth with a railing and flower boxes, so the town shows through (7d).

Points (manifest points_roblox): [x, y, z, zone], zone "near" (the gate half, z < 0) or "deep" (the far half). The
trap spots (trap_tree, trap_trashcan) add a fifth number, the turn in degrees for the world-placed
CatCafe_Park_RescueTree or CatCafe_Park_TrashCan standing there (a tree's branch points along its -X).
"""

import math

from mathutils import Matrix, Vector

import neighbourhood as nb
from areakit import PI, Set, flowers, gable, rx, ry, turned
from common import Builder
from furniture import build_bench

N = "CatCafe_Park_"
HALF_X, HALF_Z = 80.0, 60.0          # WorldBuilder's walls at +-80, +-60
WALL_D = 2.4                         # the set's walls: inner face here, back against WorldBuilder's
IN_X, IN_Z = HALF_X - 0.5 - WALL_D, HALF_Z - 0.5 - WALL_D
GATE_HALF = 21.5                     # the Park gate model is 40.95 wide, centred on the path
PATH_W, LINK_W = 6.0, 4.0
GRAVEL, KERB = "paving_sand", "paving_grout"
POND, RING_R = (0.0, -8.0), 20.5     # the pond's centre and the path ring round it
BAND, LOOP_R = (0.0, 40.0), 13.5     # the bandstand and the loop round it
GARDEN, SUNDIAL = (46.0, 40.0), (63.0, 28.0)
HEDGE_A, GAP_A = -34.5, (31.0, 45.0)   # first hedge row, gap at the east end
HEDGE_B, GAP_B = 20.0, (-45.0, -31.0)  # second hedge row, gap at the west end
PLAY = (-49.0, 41.0, 44.0, 26.0)     # playground mat centre and size


def bl(x, z, h=0.0):
    """Area (Roblox x, z) to Builder coordinates (Blender x is Roblox -x)."""
    return (-x, z, h)


def ring_point(c, r, deg):
    a = math.radians(deg)
    return (c[0] + r * math.cos(a), c[1] + r * math.sin(a))


def face(x, z, tx, tz):
    """rot_y that turns a piece at (x, z) to face (tx, tz)."""
    return math.degrees(math.atan2(-(tx - x), -(tz - z)))


RING_IN, RING_OUT = ring_point(POND, RING_R, -38), ring_point(POND, RING_R, 145)
LOOP_IN = ring_point(BAND, LOOP_R, 180)
PATH_IN = [(0, -60), (0, -52), (0, -46), (12, -44), (24, -41), (38, -37), (38, -32), (28, -25), RING_IN]
PATH_ON = [RING_OUT, (-28, 11), (-38, 17), (-38, 23), (-24, 29), LOOP_IN]


# ------------------------------------------------------------------ ground ---
def _strip(g, p0, p1, w, swatch, top):
    (ax, ay, _), (bx, by, _) = bl(*p0), bl(*p1)
    L = math.hypot(bx - ax, by - ay)
    g.box_base(((ax + bx) / 2, (ay + by) / 2, 0), (L, w, top), swatch, bevel=False,
               rot=(math.atan2(by - ay, bx - ax), "Z"))


def _path(g, pts, w, swatch=GRAVEL, top=0.05):
    """Straight strips, every other one 0.006 taller so overlaps never share a top, and a disc under each bend."""
    for i, (p0, p1) in enumerate(zip(pts, pts[1:])):
        _strip(g, p0, p1, w, swatch, top + 0.006 * (i % 2))
    for p in pts[1:-1]:
        g.cyl_base(bl(*p), w / 2, top - 0.01, swatch, segments=16, bevel=False)


def _ring_path(g, c, r, w, swatch, top, n):
    chord = 2 * (r + w / 2) * math.sin(PI / n) * 1.04
    for k in range(n):
        a = 2 * PI * (k + 0.5) / n
        x, y, _ = bl(c[0] + r * math.cos(a), c[1] + r * math.sin(a))
        g.box_base((x, y, 0), (w, chord, top + 0.006 * (k % 2)), swatch, bevel=False, rot=(PI - a, "Z"))


def _ground():
    g = Builder()
    _path(g, PATH_IN, PATH_W)
    _path(g, PATH_ON, PATH_W)
    _ring_path(g, POND, RING_R, 5.0, GRAVEL, 0.05, 40)
    _ring_path(g, BAND, LOOP_R, LINK_W, GRAVEL, 0.05, 32)
    _strip(g, (0, BAND[1] - LOOP_R - 1.0), (0, BAND[1] - 8.0), LINK_W, GRAVEL, 0.058)          # bandstand approach
    g.cyl_base(bl(0, -46), 6.5, 0.075, "paving_light", segments=24, bevel=False)                 # entrance plaza
    g.cyl_base(bl(0, -46), 6.9, 0.07, KERB, segments=24, bevel=False)
    g.cyl_base(bl(*GARDEN), 5.5, 0.075, "paving_light", segments=20, bevel=False)                # garden centre
    _strip(g, ring_point(BAND, LOOP_R, 0), (GARDEN[0] - 5.0, GARDEN[1]), LINK_W, GRAVEL, 0.05)  # loop to garden
    _path(g, [(GARDEN[0], GARDEN[1] - 5.0), (GARDEN[0], 27.0), (60.5, 27.0)], LINK_W, GRAVEL, 0.05)
    g.cyl_base(bl(*SUNDIAL), 3.2, 0.075, "paving_light", segments=16, bevel=False)              # sundial nook
    _strip(g, LOOP_IN, (PLAY[0] + PLAY[2] / 2 + 0.5, BAND[1]), LINK_W, GRAVEL, 0.058)           # loop to playground
    x, z, w, d = PLAY
    g.box_base(bl(x, z), (w, d, 0.045), "terracotta", bevel=False)                               # safety surface
    return g


# ----------------------------------------------------------------- walls -----
def _ivy(b, x0, x1, top, seed):
    for i in range(3):
        x = x0 + (x1 - x0) * (0.2 + 0.3 * i) + 0.4 * ((seed + i) % 3)
        h = top * (0.45 + 0.12 * ((seed * 3 + i) % 4))
        b.ico((x, -0.05, h / 2 + 0.3), 0.8, ("leaf_green", "leaf_dark")[(i + seed) % 2], subdivisions=1,
              scale=(1.5, 0.35, h / 1.7))


def _seg_hedge(b, L, shade):
    sw = ("leaf_dark", "leaf_green")[shade % 2]
    b.box_base((0, WALL_D / 2, 0), (L, WALL_D, 9.4), sw)
    n = max(2, round(L / 3.0))
    for i in range(n):
        x = -L / 2 + (i + 0.5) * L / n
        b.ico((x, WALL_D / 2, 9.3 + 0.15 * (i % 2)), 1.6, sw, subdivisions=1, scale=(L / n / 2.8, 0.85, 0.55))


def _seg_brick(b, L, shade):
    b.box_base((0, WALL_D / 2, 0), (L, WALL_D, 9.0), "brick")
    b.box_base((0, WALL_D / 2, 9.0), (L + 0.1, WALL_D + 0.3, 0.45), "concrete", bevel=False)      # coping
    b.box_base((0, WALL_D / 2 - 0.1, 0), (L, WALL_D + 0.2, 1.0), "concrete_dark", bevel=False)  # plinth
    for k in range(3):                                                                         # piers
        x = -L / 2 + L * (k + 1) / 4
        b.box_base((x, -0.15, 1.0), (1.0, 0.3, 7.8), "brick", bevel=False)
    _ivy(b, -L / 2, L / 2, 9.0, shade)


def _seg_rail(b, L, shade):
    b.box_base((0, 1.6, 0), (L, 1.6, 9.4), ("leaf_dark", "leaf_green")[shade % 2])               # hedge behind
    b.box_base((0, WALL_D / 2, 0), (L, WALL_D, 1.4), "brick")                                  # brick plinth
    b.box_base((0, WALL_D / 2, 1.4), (L + 0.1, WALL_D + 0.2, 0.2), "concrete", bevel=False)
    n = max(2, round(L / 1.0))
    for i in range(n + 1):
        x = -L / 2 + 0.3 + i * (L - 0.6) / n
        b.box_base((x, 0.45, 1.6), (0.16, 0.16, 3.5), "fur_black", bevel=False)
        b.pyramid((x, 0.45, 5.1), 0.26, 0.4, "gold_mid")                                       # gilded tips
    for z in (2.2, 4.6):
        b.box((0, 0.45, z), (L - 0.4, 0.14, 0.2), "fur_black", bevel=False)


def _seg_stone(b, L, shade):
    b.box_base((0, WALL_D / 2, 0), (L, WALL_D, 10.0), "concrete")
    for z in (2.0, 4.0, 6.0, 8.0):                                                             # coursing
        b.box((0, -0.03, z), (L, 0.06, 0.12), "concrete_dark", bevel=False)
    b.box_base((0, WALL_D / 2, 10.0), (L + 0.1, WALL_D + 0.3, 0.4), "concrete_dark", bevel=False)
    # a bricked-up old gate under a stone arch
    w, h = 5.0, 5.5
    b.box_base((0, -0.04, 0), (w, 0.16, h), "brick", bevel=False)
    b.fan((0, -0.04, h), (0, 0), [(w / 2 * math.cos(PI * k / 8), w / 2 * math.sin(PI * k / 8)) for k in range(9)],
          0.16, "brick", rot=rx(90))
    for k in range(9):                                                                         # voussoirs
        a = PI * k / 8
        b.box((math.cos(a) * (w / 2 + 0.35), -0.1, h + math.sin(a) * (w / 2 + 0.35)), (0.7, 0.24, 0.55),
              "concrete_dark", bevel=False, rot=ry(-math.degrees(a) + 90))
    for s in (-1, 1):
        b.box_base((s * (w / 2 + 0.35), -0.1, 0), (0.7, 0.24, h), "concrete_dark", bevel=False)
    _ivy(b, -L / 2, -w / 2 - 1.0, 10.0, shade)
    _ivy(b, w / 2 + 1.0, L / 2, 10.0, shade + 1)


def _seg_low(b, L, shade, flowers_b):
    """Town side: a plinth, a railing 4.6 high and flower boxes, so the town shows through."""
    b.box_base((0, WALL_D / 2, 0), (L, WALL_D, 1.2), "concrete")
    b.box_base((0, WALL_D / 2, 1.2), (L + 0.1, WALL_D + 0.2, 0.15), "concrete_dark", bevel=False)
    n = max(2, round(L / 1.0))
    for i in range(n + 1):
        x = -L / 2 + 0.3 + i * (L - 0.6) / n
        b.box_base((x, 1.6, 1.35), (0.15, 0.15, 3.25), "fur_black", bevel=False)
    for z in (1.9, 4.45):
        b.box((0, 1.6, z), (L - 0.4, 0.12, 0.18), "fur_black", bevel=False)
    k = max(1, round(L / 7.0))
    for i in range(k):
        x = -L / 2 + (i + 0.5) * L / k
        b.box_base((x, 0.55, 1.35), (2.6, 0.8, 0.55), "terracotta", bevel=False)
        for j in range(5):
            flowers_b.box_base((x - 1.0 + 0.5 * j, 0.5 + 0.12 * (j % 2), 1.9), (0.32, 0.32, 0.32),
                               ("blush", "pastel_butter", "offwhite", "pastel_lilac", "shirt_red")[(j + shade) % 5],
                               bevel=False)


SEGMENTS = {"hedge": _seg_hedge, "brick": _seg_brick, "rail": _seg_rail, "stone": _seg_stone}


def wall_segment(mat, kind, L, shade=0):
    """One wall run L long along local x, its face at y 0 (facing -Y, into the area) and its back at WALL_D."""
    b = Builder()
    name = N + "Wall" + kind.capitalize()
    if kind == "low":
        fl = Builder()
        _seg_low(b, L, shade, fl)
        return [b.finalize(name, mat), fl.finalize(name + "_Flowers", mat)]
    SEGMENTS[kind](b, L, shade)
    return [b.finalize(name, mat)]


def pillar(mat, top="ball", h=10.6, w=1.8):
    b, bulb = Builder(), Builder()
    d = WALL_D + 0.2
    b.box_base((0, WALL_D / 2, 0), (w, d, h), "concrete")
    b.box_base((0, WALL_D / 2, 0), (w + 0.2, d + 0.2, 0.8), "concrete_dark", bevel=False)
    b.box_base((0, WALL_D / 2, h), (w + 0.3, d + 0.3, 0.35), "concrete_dark", bevel=False)
    if top == "ball":
        b.cyl_base((0, WALL_D / 2, h + 0.35), 0.45, 0.35, "concrete", segments=10)
        b.sphere((0, WALL_D / 2, h + 1.3), 0.65, "concrete", segments=10, rings=6)
        return [b.finalize(N + "Pillar", mat)]
    b.box_base((0, WALL_D / 2, h + 0.35), (0.9, 0.9, 0.15), "fur_black", bevel=False)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box_base((sx * 0.4, WALL_D / 2 + sy * 0.4, h + 0.5), (0.1, 0.1, 1.2), "fur_black", bevel=False)
    bulb.box_base((0, WALL_D / 2, h + 0.5), (0.7, 0.7, 1.2), "lamp_warm", bevel=False)
    b.pyramid((0, WALL_D / 2, h + 1.7), 1.1, 0.6, "fur_black")
    return [b.finalize(N + "Pillar", mat), bulb.finalize(N + "Pillar_Bulb", mat)]


def _run(s, mat, kinds, n, length, place):
    """n segments filling `length` with 1.8 wide pillars between; place(t) -> (x, z, rot) at distance t along."""
    L = (length - (n - 1) * 1.8) / n
    for i in range(n):
        t = i * (L + 1.8) + L / 2
        s.put(wall_segment(mat, kinds[i % len(kinds)], L, i), *place(t))
        if i < n - 1:
            s.put(pillar(mat), *place(t + L / 2 + 0.9))


def _walls(s, mat):
    _run(s, mat, ("hedge", "brick", "rail", "stone"), 6, 2 * IN_X, lambda t: (-IN_X + t, IN_Z, 0))          # far
    _run(s, mat, ("stone", "rail", "hedge", "brick", "rail"), 5, 2 * IN_Z, lambda t: (IN_X, -IN_Z + t, 90))   # east
    _run(s, mat, ("brick", "hedge", "stone", "rail", "hedge"), 5, 2 * IN_Z, lambda t: (-IN_X, IN_Z - t, -90))  # west
    for sx in (-1, 1):
        s.put(pillar(mat, h=11.2, w=2.4), sx * (IN_X + 1.2), IN_Z, 0)                       # far corners
        s.put(pillar(mat, h=6.0, w=2.4), sx * (IN_X + 1.2), -IN_Z, 180)                     # town corners
        x0, x1 = GATE_HALF + 0.9, IN_X
        L = (x1 - x0 - 2 * 1.8) / 3
        for i in range(3):                                                                    # town side, low
            c = x0 + i * (L + 1.8) + L / 2
            s.put(wall_segment(mat, "low", L, i + (sx > 0)), sx * c, -IN_Z, 180)
            if i < 2:
                s.put(pillar(mat, h=5.2), sx * (c + L / 2 + 0.9), -IN_Z, 180)
        s.put(pillar(mat, top="lantern", h=7.0), sx * GATE_HALF, -IN_Z, 180)                 # by the gate


def _hedge_row(s, mat, z, gap, urns=True):
    """A hedge row across the area, 6 to 6.8 high, with one gap (x0, x1); stone urns flank the gap."""
    b = Builder()
    for (a0, a1) in ((-IN_X, gap[0]), (gap[1], IN_X)):
        n = max(1, round((a1 - a0) / 8.0))
        step = (a1 - a0) / n
        for i in range(n):
            c, h = a0 + (i + 0.5) * step, 6.0 + 0.4 * (i % 3)
            sw = ("leaf_dark", "leaf_green")[i % 2]
            x, y, _ = bl(c, z)
            b.box_base((x, y, 0), (step + 0.02 * (i % 2), 2.4 + 0.02 * (i % 2), h), sw, bevel=False)
            b.ico((x, y, h), 1.4, sw, subdivisions=1, scale=(step / 2.6, 0.95, 0.5))
    s.put([b.finalize(N + "Hedge", mat)], 0, 0, 0)
    if urns:
        for x in (gap[0] + 1.0, gap[1] - 1.0):
            for dz in (-2.2, 2.2):
                s.put(urn(mat), x, z + dz, 0)


# ------------------------------------------------------------ the pond -------
def pond(mat):
    """Sunken duck pond at the origin: a grass bank (wedges) up to a stone kerb 1 high round water 0.35 deep in
    look, an island with a duck house, and a jetty out from the east (Blender -x). Pond_Barrier: an invisible wall
    on the kerb with a gap only for the jetty, which has its own side and end walls."""
    b, water, decor, bulb, bar = Builder(), Builder(), Builder(), Builder(), Builder()
    for k in range(32):                                                                       # the bank
        a = 2 * PI * (k + 0.5) / 32
        r = 16.2
        b.wedge((r * math.cos(a), r * math.sin(a), 0.5), (2 * 17.4 * math.sin(PI / 32) * 1.04, 2.4, 1.0),
                "leaf_green", bevel=False, rot=(a + PI / 2, "Z"))
    for k in range(40):                                                                       # the kerb
        a = 2 * PI * (k + 0.5) / 40
        r = 14.3
        b.box_base((r * math.cos(a), r * math.sin(a), 0), (1.4, 2 * 15.0 * math.sin(PI / 40) * 1.04, 1.0 + 0.006 * (k % 2)),
                   "concrete", bevel=False, rot=(a, "Z"))
    b.cyl_base((0, 0, 0), 13.8, 0.02, "concrete_dark", segments=32, bevel=False)              # the bed
    water.cyl_base((0, 0, 0.02), 13.7, 0.33, "fish_blue", segments=32, bevel=False)
    # the island and its duck house
    b.cyl_base((0, 0, 0), 4.0, 0.8, "leaf_green", segments=16)
    b.cyl_base((0, 0, 0), 4.3, 0.45, "concrete", segments=16, bevel=False)
    b.box_base((0.6, 0.6, 0.8), (2.2, 1.8, 1.4), "cream")
    b.box((0.6, -0.31, 1.3), (0.8, 0.04, 0.8), "fur_black", bevel=False)                      # doorway
    gable(b, 0.6, 0.6, 2.2, 2.2, 1.8, 0.9, "cream", "terracotta", over=0.25, thick=0.2)
    b.box((0.6, -0.9, 0.95), (0.5, 1.0, 0.1), "caramel_wood", bevel=False, rot=rx(-16))         # ramp
    for (x, y, rot, s) in ((5.5, 6.0, 30, 1.0), (-7.0, 3.5, 160, 0.9), (2.0, -8.5, 260, 1.0), (-6.5, -7.0, 200, 0.8)):
        a = math.radians(rot)                                                                 # ducks
        decor.ico((x, y, 0.55), 0.5 * s, "offwhite", subdivisions=1, scale=(1.3, 0.9, 0.7))
        hx, hy = x + 0.55 * s * math.cos(a), y + 0.55 * s * math.sin(a)
        decor.ico((hx, hy, 0.95 * s + 0.1), 0.28 * s, "offwhite", subdivisions=1)
        decor.box((hx + 0.3 * s * math.cos(a), hy + 0.3 * s * math.sin(a), 0.92 * s + 0.1), (0.22 * s, 0.14, 0.08),
                  "fur_orange", bevel=False, rot=(a, "Z"))
    for k in range(9):                                                                        # lily pads
        a = 2 * PI * k / 9 + 0.4
        r = 7.5 + 2.8 * ((k * 5) % 3) / 2
        decor.cyl_base((r * math.cos(a), r * math.sin(a), 0.35), 0.55 + 0.1 * (k % 3), 0.03, "leaf_green",
                       segments=8, bevel=False)
        if k % 3 == 0:
            decor.ico((r * math.cos(a) + 0.2, r * math.sin(a), 0.45), 0.15, "blush", subdivisions=1)
    for k in range(7):                                                                        # reeds by the kerb
        a = 2 * PI * k / 7 + 1.1
        for j in range(3):
            r = 12.6 - 0.3 * j
            decor.box_base((r * math.cos(a + 0.03 * j), r * math.sin(a + 0.03 * j), 0.3), (0.12, 0.12, 1.2 + 0.4 * j),
                           ("leaf_dark", "leaf_green")[j % 2], bevel=False)
        decor.cyl((12.0 * math.cos(a + 0.06), 12.0 * math.sin(a + 0.06), 2.55), 0.1, 0.5, "choco", segments=6)
    # the jetty, east of the pond (Blender -x): deck top 1.2, one step of 0.6 up from the path ring
    x0, x1, hw, top = -17.6, -8.0, 1.6, 1.2
    b.box_base(((x0 + 1.0 + x1) / 2, 0, top - 0.3), (x1 - x0 - 1.0, 2 * hw, 0.3), "caramel_wood", bevel=False)
    b.box_base((x0 + 0.5, 0, 0), (1.0, 2 * hw, 0.6), "caramel_wood", bevel=False)              # the step
    for i in range(9):
        x = x0 + 1.0 + (i + 0.5) * (x1 - x0 - 1.0) / 9
        b.box_base((x, 0, top), (0.06, 2 * hw - 0.1, 0.012), "dark_wood", bevel=False)          # plank lines
    rx0, rx1 = x0 + 1.15, x1 - 0.15
    for x in (rx0, (rx0 + rx1) / 2, rx1):
        for s in (-1, 1):
            b.box_base((x, s * (hw - 0.12), top), (0.24, 0.24, 3.1), "dark_wood", bevel=False)  # rail posts
            b.box_base((x, s * (hw - 0.3), 0), (0.3, 0.3, top - 0.3), "dark_wood", bevel=False)  # legs
    for s in (-1, 1):
        for z, hh in ((top + 2.85, 0.3), (top + 1.5, 0.2)):
            b.box(((rx0 + rx1) / 2, s * (hw - 0.12), z), (rx1 - rx0, 0.18, hh), "caramel_wood", bevel=False)
    for z, hh in ((top + 2.85, 0.3), (top + 1.5, 0.2)):
        b.box((rx1, 0, z), (0.18, 2 * hw - 0.24, hh), "caramel_wood", bevel=False)                 # end rail
    b.ring((-14.4, -(hw + 0.04), top + 2.5), 0.6, 0.2, 0.15, "bowl_red", segments=12, bevel=False, rot=rx(90))
    b.box_base((rx1, hw - 0.12, top + 3.1), (0.2, 0.2, 1.5), "dark_wood", bevel=False)          # lantern post
    b.box((rx1, hw - 0.12 - 0.45, top + 4.45), (0.15, 0.9, 0.12), "fur_black", bevel=False)
    bulb.box((rx1, hw - 0.12 - 0.75, top + 4.39 - 0.325), (0.45, 0.45, 0.65), "lamp_warm", bevel=False)
    # the barrier: a ring on the kerb (gap for the jetty), and walls along the jetty's sides and end
    n = 48
    chord = 2 * 14.3 * math.sin(PI / n) * 1.04
    for k in range(n):
        a = 2 * PI * (k + 0.5) / n
        if math.cos(a) < 0 and abs(14.3 * math.sin(a)) < hw + 0.25:
            continue
        bar.box_base((14.3 * math.cos(a), 14.3 * math.sin(a), 0), (0.6, chord, 10.0), "offwhite", bevel=False,
                     rot=(a, "Z"))
    for s in (-1, 1):
        bar.box_base(((-15.0 + x1 + 0.45) / 2, s * (hw + 0.25), 0), (x1 + 0.45 + 15.0, 0.4, 10.0), "offwhite",
                     bevel=False)
    bar.box_base((x1 + 0.25, 0, 0), (0.4, 2 * hw + 0.9, 10.0), "offwhite", bevel=False)
    return [b.finalize(N + "Pond", mat), water.finalize(N + "Pond_Water", mat), decor.finalize(N + "Pond_Decor", mat),
            bulb.finalize(N + "Pond_Bulb", mat), bar.finalize(N + "Pond_Barrier", mat)]


# --------------------------------------------------------- the bandstand ----
def _panel(b, p0, p1, apex, swatch, thick=0.25):
    p0, p1, apex = Vector(p0), Vector(p1), Vector(apex)
    m = (p0 + p1) / 2
    u = (p1 - p0).normalized()
    v = apex - m
    v = (v - u * v.dot(u)).normalized()
    n = u.cross(v)
    if n.z < 0:
        n, u = -n, -u
    L = (p1 - p0).length
    R = Matrix((u, v, n)).transposed()
    b.fan(m + n * thick / 2, (0, (apex - m).dot(v)), [(-L / 2, 0), (L / 2, 0)], thick, swatch, rot=R)


def bandstand(mat):
    """The far landmark: an octagonal bandstand on two round steps, the stage at 1.15, eight posts, a railing 3 high
    on every side but the front (-Y), a striped roof with a cupola and a gold cat weather vane."""
    b, bulbs, decor = Builder(), Builder(), Builder()
    b.cyl_base((0, 0, 0), 8.6, 0.55, "concrete", segments=24)
    b.cyl_base((0, 0, 0.55), 7.8, 0.6, "concrete", segments=24)
    b.cyl_base((0, 0, 1.15), 7.2, 0.02, "caramel_wood", segments=24, bevel=False)
    stage, R, post_h = 1.17, 6.4, 6.0
    ang = [2 * PI * (k + 0.5) / 8 for k in range(8)]
    for a in ang:
        x, y = R * math.cos(a), R * math.sin(a)
        b.cyl_base((x, y, stage), 0.45, 0.4, "gold_mid", segments=8, bevel=False)
        b.cyl_base((x, y, stage), 0.28, post_h - 0.05, "offwhite", segments=8)
        b.cyl_base((x, y, stage + post_h - 0.35), 0.42, 0.35, "gold_mid", segments=8, bevel=False)
    top = stage + post_h
    b.ring((0, 0, top + 0.3), 6.9, 0.9, 0.6, "mint", segments=16, bevel=False)                # frieze
    b.ring((0, 0, top - 0.05), 6.95, 0.6, 0.1, "gold_mid", segments=16, bevel=False)
    for k in range(16):
        a = 2 * PI * k / 16
        bulbs.ico((7.0 * math.cos(a), 7.0 * math.sin(a), top + 0.3), 0.16, "lamp_warm", subdivisions=1)
    for k in range(8):                                                                        # railings
        a0, a1 = ang[k], ang[(k + 1) % 8]
        if k == 5:
            continue                                                                          # the front (-Y) stays open
        p0, p1 = Vector((R * math.cos(a0), R * math.sin(a0))), Vector((R * math.cos(a1), R * math.sin(a1)))
        mid, d = (p0 + p1) / 2, p1 - p0
        rot = (math.atan2(d.y, d.x), "Z")
        b.box((mid.x, mid.y, stage + 2.85), (d.length, 0.2, 0.3), "dumpster_green", bevel=False, rot=rot)
        b.box((mid.x, mid.y, stage + 0.35), (d.length, 0.2, 0.2), "dumpster_green", bevel=False, rot=rot)
        for i in range(5):
            p = p0 + d * ((i + 1) / 6)
            b.box_base((p.x, p.y, stage + 0.45), (0.15, 0.15, 2.25), "dumpster_green", bevel=False, rot=rot)
    eave, apex = top + 0.6, top + 0.6 + 4.4
    er = 7.7
    for k in range(8):
        a0, a1 = ang[k], ang[(k + 1) % 8]
        _panel(b, (er * math.cos(a0), er * math.sin(a0), eave), (er * math.cos(a1), er * math.sin(a1), eave),
               (0, 0, apex), ("mint", "offwhite")[k % 2])
    b.cyl_base((0, 0, apex - 0.6), 0.9, 1.0, "offwhite", segments=10)
    b.cyl_base((0, 0, apex + 0.4), 1.15, 0.8, "mint", segments=10, radius2=0.08)
    b.cyl_base((0, 0, apex + 1.1), 0.07, 1.5, "gold_mid", segments=6, bevel=False)
    vz = apex + 2.4
    b.box((0, 0, vz), (1.0, 0.1, 0.45), "gold_mid", bevel=False)                               # the cat on the vane
    b.box((-0.55, 0, vz + 0.3), (0.42, 0.1, 0.4), "gold_mid", bevel=False)
    for ex in (-0.68, -0.42):
        b.pyramid((ex, 0, vz + 0.5), 0.14, 0.2, "gold_mid")
    b.box((0.62, 0, vz + 0.35), (0.12, 0.1, 0.7), "gold_mid", bevel=False, rot=ry(-20))
    b.box((0, 0, vz - 0.5), (1.6, 0.06, 0.06), "gold_mid", bevel=False)                       # the arrow
    b.pyramid((-0.85, 0, vz - 0.53), 0.2, 0.25, "gold_mid", rot=ry(90))
    for (x, y) in ((3.0, 3.4), (-3.0, 3.6)):                                                  # music stands
        decor.cyl_base((x, y, stage), 0.25, 0.06, "fur_black", segments=6, bevel=False)
        decor.box_base((x, y, stage + 0.06), (0.06, 0.06, 2.4), "fur_black", bevel=False)
        decor.box((x, y - 0.1, stage + 2.6), (0.9, 0.06, 0.6), "fur_black", bevel=False, rot=rx(-25))
    decor.cyl_base((0, 1.2, stage), 0.6, 0.9, "shirt_red", segments=12)                       # a drum
    decor.cyl_base((0, 1.2, stage + 0.9), 0.62, 0.05, "offwhite", segments=12, bevel=False)
    return [b.finalize(N + "Bandstand", mat), bulbs.finalize(N + "Bandstand_Bulbs", mat),
            decor.finalize(N + "Bandstand_Decor", mat)]


# --------------------------------------------------------- park pieces ------
def oak(mat, blossom=False):
    b = Builder()
    leaf, leaf2 = ("blush", "fur_rose") if blossom else ("leaf_green", "leaf_dark")
    b.cyl_base((0, 0, 0), 0.9, 6.5, "fur_brown", segments=10, radius2=0.6)
    b.box((0.9, 0.3, 5.2), (2.4, 0.5, 0.5), "fur_brown", rot=ry(-35))
    b.ico((0, 0, 8.8), 4.2, leaf, subdivisions=1, scale=(1, 1, 0.8))
    b.ico((2.6, 0.8, 7.6), 2.6, leaf2, subdivisions=1)
    b.ico((-2.4, -1.0, 7.8), 2.7, leaf2, subdivisions=1)
    b.ico((0.5, -2.2, 9.8), 2.2, leaf, subdivisions=1)
    return [b.finalize(N + ("BlossomOak" if blossom else "Oak"), mat)]


def poplar(mat, h=13.0):
    b = Builder()
    b.cyl_base((0, 0, 0), 0.45, 3.6, "fur_brown", segments=8, radius2=0.35)
    b.ico((0, 0, h * 0.58), 1.9, "leaf_dark", subdivisions=1, scale=(1, 1, h / 4.2))
    return [b.finalize(N + "Poplar", mat)]


def willow(mat):
    b, fronds = Builder(), Builder()                       # fronds as _Decor: walk under them, cats sit inside
    b.cyl_base((0, 0, 0), 0.85, 6.5, "fur_brown", segments=10, radius2=0.6)
    b.ico((0, 0, 8.2), 4.5, "leaf_green", subdivisions=1, scale=(1, 1, 0.6))
    for k in range(18):
        a = 2 * PI * k / 18
        r = 3.6 + 0.4 * (k % 3)
        L = 5.2 - 0.6 * (k % 2)
        fronds.box_base((r * math.cos(a), r * math.sin(a), 8.2 - L), (0.55, 0.3, L), ("leaf_green", "leaf_dark")[k % 2],
                        bevel=False, rot=(a + PI / 2, "Z"))
    return [b.finalize(N + "Willow", mat), fronds.finalize(N + "Willow_Decor", mat)]


def lamp(mat):
    b, bulb = Builder(), Builder()
    b.cyl_base((0, 0, 0), 0.45, 0.5, "dumpster_green", segments=8)
    b.cyl_base((0, 0, 0.5), 0.17, 7.6, "dumpster_green", segments=8)
    b.box((0, 0, 8.0), (1.1, 0.15, 0.15), "dumpster_green", bevel=False)
    bulb.box_base((0, 0, 8.1), (0.85, 0.85, 1.05), "lamp_warm", bevel=False)
    b.box_base((0, 0, 9.15), (1.15, 1.15, 0.12), "dumpster_green", bevel=False)
    b.pyramid((0, 0, 9.27), 1.0, 0.55, "dumpster_green")
    b.sphere((0, 0, 9.9), 0.14, "gold_mid", segments=6, rings=4)
    return [b.finalize(N + "Lamp", mat), bulb.finalize(N + "Lamp_Bulb", mat)]


def bench(mat):
    return [build_bench(N + "Bench", seat="caramel_wood", frame="dumpster_green").finalize(N + "Bench", mat)]


def bin_(mat):
    b = Builder()
    b.cyl_base((0, 0, 0), 0.6, 1.7, "dumpster_green", segments=10)
    b.ring((0, 0, 1.65), 0.66, 0.12, 0.12, "fur_black", segments=10, bevel=False)
    b.cyl_base((0, 0, 1.7), 0.5, 0.25, "fur_black", segments=10, radius2=0.3)
    return [b.finalize(N + "Bin", mat)]


def urn(mat):
    b, fl = Builder(), Builder()
    b.box_base((0, 0, 0), (1.2, 1.2, 0.9), "concrete")
    b.cyl_base((0, 0, 0.9), 0.3, 0.3, "concrete", segments=10)
    b.cyl_base((0, 0, 1.2), 0.45, 0.8, "concrete", segments=10, radius2=0.75)
    b.ring((0, 0, 2.05), 0.8, 0.12, 0.12, "concrete_dark", segments=10, bevel=False)
    b.ico((0, 0, 2.15), 0.65, "leaf_dark", subdivisions=1, scale=(1, 1, 0.6))
    flowers(fl, 0, 0, 2.2, n=4, r=0.35, seed=2)
    return [b.finalize(N + "Urn", mat), fl.finalize(N + "Urn_Flowers", mat)]


def flower_bed(mat, seed=0):
    b, fl = Builder(), Builder()
    b.box_base((0, 0, 0), (6.0, 3.0, 0.6), "concrete")
    b.box_base((0, 0, 0.3), (5.6, 2.6, 0.32), "choco", bevel=False)
    for i, x in enumerate((-2.0, -0.7, 0.7, 2.0)):
        flowers(fl, x, 0.4 * (-1) ** i, 0.62, n=5, r=0.55, seed=i + seed)
    return [b.finalize(N + "FlowerBed", mat), fl.finalize(N + "FlowerBed_Flowers", mat)]


def planter(mat):
    b, fl = Builder(), Builder()
    b.ring((0, 0, 0.45), 2.3, 0.4, 0.9, "concrete", segments=16, bevel=False)
    b.cyl_base((0, 0, 0), 1.95, 0.8, "choco", segments=16, bevel=False)
    b.cyl_base((0, 0, 0.8), 0.25, 1.4, "fur_brown", segments=8)
    b.ico((0, 0, 2.6), 1.1, "leaf_dark", subdivisions=1)
    for k in range(6):
        a = 2 * PI * k / 6
        flowers(fl, 1.3 * math.cos(a), 1.3 * math.sin(a), 0.8, n=3, r=0.3, seed=k)
    return [b.finalize(N + "Planter", mat), fl.finalize(N + "Planter_Flowers", mat)]


def map_board(mat):
    b = Builder()
    for x in (-1.8, 1.8):
        b.box_base((x, 0, 0), (0.3, 0.3, 5.2), "dark_wood")
    b.box((0, 0, 3.4), (3.9, 0.3, 2.6), "dark_wood")
    b.box((0, -0.16, 3.4), (3.5, 0.04, 2.2), "leaf_green", bevel=False)
    b.cyl((0, -0.19, 3.3), 0.45, 0.03, "fish_blue", segments=12, bevel=False, rot=rx(90))
    for (x, z, w, h) in ((0, 2.55, 0.18, 0.5), (0.7, 3.0, 1.2, 0.14), (1.3, 3.5, 0.14, 1.0), (-0.9, 3.75, 1.6, 0.14),
                         (-1.6, 4.1, 0.14, 0.7)):
        b.box((x, -0.185, z), (w, 0.02, h), "paving_sand", bevel=False)
    b.box((0, -0.19, 4.2), (0.5, 0.03, 0.3), "offwhite", bevel=False)                           # the bandstand
    b.box((0, 0, 5.3), (4.4, 1.0, 0.2), "dumpster_green", bevel=False, rot=rx(8))
    return [b.finalize(N + "MapBoard", mat)]


def picnic_table(mat):
    b = Builder()
    b.box_base((0, 0, 2.3), (5.0, 2.4, 0.25), "caramel_wood")
    for y in (-1.9, 1.9):
        b.box_base((0, y, 1.3), (5.0, 0.9, 0.2), "caramel_wood")
    for x in (-1.9, 1.9):
        for s in (-1, 1):
            b.box((x, s * 1.1, 1.2), (0.25, 0.25, 2.8), "dark_wood", rot=rx(s * 38))
        b.box((x, 0, 1.15), (0.25, 4.6, 0.25), "dark_wood", bevel=False)                       # brace
    return [b.finalize(N + "PicnicTable", mat)]


def blanket(mat):
    b = Builder()
    b.box_base((0, 0, 0), (4.0, 4.0, 0.05), "blush", bevel=False)
    for i in range(4):
        for j in range(4):
            if (i + j) % 2 == 0:
                b.box_base((-1.5 + i, -1.5 + j, 0.05), (0.9, 0.9, 0.006), "offwhite", bevel=False)
    bx, by = 1.55, 1.5
    b.box_base((bx, by, 0.05), (0.9, 0.6, 0.6), "caramel_wood")
    for s in (-1, 1):
        b.box_base((bx + s * 0.35, by, 0.65), (0.08, 0.08, 0.45), "dark_wood", bevel=False)     # handle uprights
    b.box((bx, by, 1.12), (0.78, 0.08, 0.08), "dark_wood", bevel=False)
    return [b.finalize(N + "Blanket", mat)]


def kiosk(mat):
    """A tea and ice cream kiosk, serving hatch at the front (-Y) under a striped awning."""
    b, bulb = Builder(), Builder()
    W, D, H = 5.0, 3.6, 5.2
    b.box_base((0, 0, 0), (W, D, 2.4), "mint")
    b.box_base((0, 0.3, 2.4), (W, D - 0.6, 1.8), "mint")
    b.box_base((0, 0, 4.2), (W, D, H - 4.2), "mint")
    b.box_base((0, -0.15, 2.4), (W + 0.2, D + 0.3, 0.2), "offwhite", bevel=False)              # counter top
    b.box((0, -D / 2 + 0.25, 3.3), (W - 0.6, 0.05, 1.6), "cream", bevel=False)                 # inside back
    b.box_base((0, 0, H), (W + 0.6, D + 0.6, 0.3), "offwhite")
    b.box((0, -D / 2 - 0.02, 4.7), (2.8, 0.04, 0.6), "sign_teal", bevel=False)                 # sign board
    for i in range(8):
        x = -W / 2 + (i + 0.5) * W / 8
        b.box((x, -D / 2 - 0.62, 4.0), (W / 8, 1.4, 0.08), ("bowl_red", "offwhite")[i % 2], bevel=False, rot=rx(25))
    b.box((0, -D / 2 - 1.27, 3.66), (W, 0.08, 0.3), "bowl_red", bevel=False)
    bulb.box((0, -0.2, 4.05), (0.6, 0.6, 0.25), "lamp_warm", bevel=False)
    b.cyl_base((1.6, -D / 2 - 0.4, 2.6), 0.35, 0.5, "pastel_butter", segments=8, radius2=0.1)    # a cone sign
    b.ico((1.6, -D / 2 - 0.4, 3.25), 0.3, "blush", subdivisions=1)
    return [b.finalize(N + "Kiosk", mat), bulb.finalize(N + "Kiosk_Bulb", mat)]


def bistro(mat):
    b = Builder()
    b.cyl_base((0, 0, 0), 0.6, 0.1, "fur_black", segments=10, bevel=False)
    b.cyl_base((0, 0, 0.1), 0.12, 2.3, "fur_black", segments=8)
    b.cyl_base((0, 0, 2.4), 1.2, 0.12, "offwhite", segments=14)
    b.cyl_base((0, 0, 2.52), 0.07, 2.9, "fur_black", segments=6, bevel=False)
    b.cyl_base((0, 0, 5.3), 2.6, 1.0, "offwhite", segments=12, radius2=0.15)
    b.ring((0, 0, 5.36), 2.62, 0.25, 0.12, "bowl_red", segments=12, bevel=False)
    for a in (0.3, 2.4, 4.4):
        x, y = 1.75 * math.cos(a), 1.75 * math.sin(a)
        b.cyl_base((x, y, 0), 0.1, 1.3, "fur_black", segments=6, bevel=False)
        b.cyl_base((x, y, 1.3), 0.5, 0.15, "caramel_wood", segments=10)
    return [b.finalize(N + "Bistro", mat)]


def seesaw(mat):
    b = Builder()
    b.box_base((0, 0, 0), (0.9, 1.2, 1.1), "shirt_red")
    b.box((0, 0, 1.2), (7.0, 0.8, 0.2), "pastel_butter", rot=ry(9))
    for s in (-1, 1):
        x, z = s * 3.0, 1.2 - s * 3.0 * math.tan(math.radians(9))
        b.box_base((x, 0, z + 0.1), (0.8, 0.85, 0.15), "sign_teal", bevel=False, rot=ry(9))
        b.box_base((x + s * -0.5, 0, z + 0.1), (0.12, 0.9, 0.9), "fur_black", bevel=False, rot=ry(9))
    return [b.finalize(N + "Seesaw", mat)]


def roundabout(mat):
    b = Builder()
    b.cyl_base((0, 0, 0), 0.8, 0.3, "metal", segments=10)
    b.cyl_base((0, 0, 0.3), 2.6, 0.4, "metal", segments=20)
    cols = ("shirt_red", "pastel_butter", "sign_teal", "shirt_blue")
    for k in range(4):
        a0 = PI / 2 * k
        chain = [(2.5 * math.cos(a0 + PI / 2 * j / 4), 2.5 * math.sin(a0 + PI / 2 * j / 4)) for j in range(5)]
        b.fan((0, 0, 0.71 + 0.002 * k), (0, 0), chain, 0.02 + 0.004 * k, cols[k])
    for k in range(4):
        a = PI / 2 * k + PI / 4
        x, y = 1.95 * math.cos(a), 1.95 * math.sin(a)
        b.box_base((x, y, 0.7), (0.15, 0.15, 1.5), "fur_black", bevel=False)
        b.box((x, y, 2.15), (0.7, 0.12, 0.12), "fur_black", bevel=False, rot=(a + PI / 2, "Z"))
    return [b.finalize(N + "Roundabout", mat)]


ROUNDABOUT_TOP = 0.72


def spring_rider(mat, body="pastel_butter"):
    b = Builder()
    b.cyl_base((0, 0, 0), 0.7, 0.15, "metal", segments=10, bevel=False)
    b.cyl_base((0, 0, 0.15), 0.25, 1.05, "metal", segments=8, bevel=False)
    for k in range(4):
        b.ring((0, 0, 0.3 + 0.25 * k), 0.38, 0.13, 0.1, "fur_black", segments=10, bevel=False)
    b.ico((0, 0, 1.55), 0.6, body, subdivisions=1, scale=(1.4, 0.75, 0.75))                    # a duck to ride
    b.ico((-0.9, 0, 2.15), 0.38, body, subdivisions=1)
    b.box((-1.35, 0, 2.1), (0.3, 0.22, 0.12), "fur_orange", bevel=False)
    b.box((-0.4, 0, 2.15), (0.1, 0.9, 0.1), "fur_black", bevel=False)                           # handle
    return [b.finalize(N + "SpringRider", mat)]


def rose_bed(mat, seed=0):
    b, fl = Builder(), Builder()
    b.ring((0, 0, 0.28), 2.0, 0.35, 0.55, "concrete", segments=14, bevel=False)
    b.cyl_base((0, 0, 0), 1.7, 0.57, "choco", segments=14, bevel=False)
    for k in range(6):
        a = 2 * PI * (k + 0.3 * seed) / 6
        x, y = 1.15 * math.cos(a), 1.15 * math.sin(a)
        fl.ico((x, y, 0.95), 0.4, "leaf_dark", subdivisions=1, scale=(1, 1, 0.8))
        for j in range(3):
            fl.ico((x + 0.25 * math.cos(j * 2.1), y + 0.25 * math.sin(j * 2.1), 1.25), 0.15,
                   ("shirt_red", "blush", "offwhite")[(k + j + seed) % 3], subdivisions=1)
    return [b.finalize(N + "RoseBed", mat), fl.finalize(N + "RoseBed_Flowers", mat)]


def rose_arch(mat, span=5.2):
    b, fl = Builder(), Builder()
    r = span / 2
    for s in (-1, 1):
        b.box_base((s * r, 0, 0), (0.25, 0.25, 4.6), "dumpster_green", bevel=False)
        b.box_base((s * r, 0, 0), (0.6, 0.6, 0.3), "concrete", bevel=False)
    for k in range(10):
        a = PI * (k + 0.5) / 10
        b.box((r * math.cos(a), 0, 4.6 + r * math.sin(a)), (0.25, 0.25, PI * r / 10 * 1.08), "dumpster_green",
              bevel=False, rot=ry(-math.degrees(a)))
    for k in range(9):
        a = PI * (k + 0.5) / 9
        fl.ico(((r + 0.05) * math.cos(a), 0, 4.6 + (r + 0.05) * math.sin(a)), 0.45, "leaf_dark", subdivisions=1)
        fl.ico(((r + 0.3) * math.cos(a), -0.25, 4.6 + (r + 0.3) * math.sin(a)), 0.16, ("shirt_red", "blush")[k % 2],
               subdivisions=1)
    for s in (-1, 1):
        for j in range(3):
            fl.ico((s * r, -0.05, 1.2 + 1.3 * j), 0.4, "leaf_dark", subdivisions=1)
            fl.ico((s * (r + 0.1), -0.35, 1.4 + 1.3 * j), 0.15, ("blush", "shirt_red")[j % 2], subdivisions=1)
    return [b.finalize(N + "RoseArch", mat), fl.finalize(N + "RoseArch_Flowers", mat)]


def topiary_cat(mat):
    b = Builder()
    b.box_base((0, 0, 0), (2.4, 2.4, 0.9), "concrete")
    b.ico((0, 0, 2.1), 1.25, "leaf_dark", subdivisions=2, scale=(0.95, 0.85, 1.05))
    b.ico((0, -0.2, 3.85), 0.85, "leaf_dark", subdivisions=2)
    for s in (-1, 1):
        b.pyramid((s * 0.45, -0.2, 4.5), 0.45, 0.6, "leaf_dark")
    b.cyl((0.95, 0.6, 1.5), 0.22, 1.8, "leaf_dark", segments=8, rot=ry(-25))
    b.ico((1.3, 0.6, 2.4), 0.3, "leaf_dark", subdivisions=1)
    return [b.finalize(N + "TopiaryCat", mat)]


def sundial(mat):
    b = Builder()
    b.cyl_base((0, 0, 0), 0.9, 0.3, "concrete", segments=10)
    b.cyl_base((0, 0, 0.3), 0.45, 2.0, "concrete", segments=10, radius2=0.35)
    b.cyl_base((0, 0, 2.3), 0.9, 0.15, "brass", segments=14)
    b.box((0.1, 0, 2.62), (0.9, 0.06, 0.3), "brass", bevel=False, rot=ry(-20))                  # gnomon
    return [b.finalize(N + "Sundial", mat)]


def garden_fountain(mat):
    """The rose garden's fountain: a round basin, a pedestal bowl and a brass fish spout."""
    b, water = Builder(), Builder()
    b.ring((0, 0, 0.45), 3.2, 0.5, 0.9, "concrete", segments=20, bevel=False)
    b.ring((0, 0, 0.92), 3.3, 0.7, 0.06, "concrete_dark", segments=20, bevel=False)
    b.cyl_base((0, 0, 0), 2.75, 0.1, "concrete_dark", segments=20, bevel=False)
    water.cyl_base((0, 0, 0.1), 2.7, 0.6, "puddle", segments=20, bevel=False)
    b.cyl_base((0, 0, 0.1), 0.45, 2.2, "concrete", segments=10, radius2=0.35)
    b.cyl_base((0, 0, 2.3), 0.5, 0.35, "concrete", segments=12, radius2=1.3)
    b.ring((0, 0, 2.75), 1.35, 0.15, 0.2, "concrete", segments=14, bevel=False)
    water.cyl_base((0, 0, 2.6), 1.2, 0.2, "puddle", segments=14, bevel=False)
    b.ico((0, 0, 3.3), 0.4, "brass", subdivisions=1, scale=(1, 0.6, 1.4))                    # a leaping fish
    b.pyramid((0, 0, 3.75), 0.45, 0.45, "brass", rot=rx(180))
    return [b.finalize(N + "GardenFountain", mat), water.finalize(N + "GardenFountain_Water", mat)]


# --------------------------------------------------------------- the set ----
def _spot(s, label, x, z, y=0.0, turn=None):
    p = [round(x, 2), round(y, 2), round(z, 2), "deep" if z > 0 else "near"]
    if turn is not None:
        p.append(turn)
    s.points.setdefault(label, []).append(p)


def build_set(mat):
    s = Set(N + "Set")
    _walls(s, mat)
    _hedge_row(s, mat, HEDGE_A, GAP_A)
    _hedge_row(s, mat, HEDGE_B, GAP_B)

    # the entrance: plaza, map, lamps, benches, then flower beds along the path east
    s.put(planter(mat), 0, -46, 0)
    _spot(s, "plaza", -3.5, -49.5)
    s.put(map_board(mat), 14, -53, face(14, -53, 4, -46))
    for (x, z) in ((-16, -54), (8, -54), (-12, -37.5)):
        s.put(lamp(mat), x, z, 0)
    for x in (-6.5, 6.5):
        s.put(bench(mat), x, -40.5, face(x, -40.5, 0, -46))
    for i, (x, z) in enumerate(((18, -48.5), (30, -45.5), (45, -41))):
        s.put(flower_bed(mat, i), x, z, 0)
        _spot(s, "flowerbed", x, z, y=0.62)
    s.put(bench(mat), 54, -42, 90)
    _spot(s, "bench", *turned(54, -42, 90, 0, -2.4))
    for (x, z) in ((-11, -41), (58, -38)):
        s.put(bin_(mat), x, z, 0)

    # the picnic lawn, west of the plaza
    for i, (x, z, r) in enumerate(((-28, -47, 8), (-46, -50, -12), (-62, -44, 5))):
        s.put(picnic_table(mat), x, z, r)
        if i < 2:
            _spot(s, "picnic", *turned(x, z, r, 0, -3.4))
    s.put(blanket(mat), -42, -40, 15)
    _spot(s, "blanket", -42, -40, y=0.06)
    s.put(oak(mat), -38, -52, 20)
    _spot(s, "oak", -35, -48.5)
    s.put(oak(mat), -66, -50, 70)
    s.put(oak(mat, blossom=True), 62, -46, 40)
    _spot(s, "blossom", 62, -50.5)

    # the pond and the lawns either side of it
    s.put(pond(mat), *POND, 0)
    _spot(s, "jetty", 10, -8, y=1.2)
    for deg in (215, 70):
        _spot(s, "bank", *ring_point(POND, 19.0, deg))
    for deg in (20, 100, 200, 280):
        x, z = ring_point(POND, 24.0, deg)
        s.put(bench(mat), x, z, face(x, z, *POND))
    for deg in (60, 160, 240, 345):
        s.put(lamp(mat), *ring_point(POND, 23.6, deg), 0)
    s.put(willow(mat), -46, -12, 0)
    _spot(s, "willow", -42, -16)
    s.put(kiosk(mat), 52, -10, 90)
    _spot(s, "kiosk", 46.5, -16.5)
    for z in (-2, -20):
        s.put(bistro(mat), 40, z, 0)
    for (x, z) in ((-66, -24), (-62, 8), (64, 10), (70, -26)):
        s.put(poplar(mat), x, z, 0)
    s.put(oak(mat), -30, -26, 140)
    _spot(s, "oak", -34, -29.5)
    s.put(oak(mat), 30, 12, 260)
    _spot(s, "oak", 26, 8)
    for (x, z) in ((-60, -12), (-50, 10), (50, 6), (56, 14)):
        _spot(s, "lawn", x, z)
    _spot(s, "hedge", -60, 24)

    # the far loop: the bandstand
    s.put(bandstand(mat), *BAND, 0)
    for (x, z) in ((-3, 40.5), (3, 41), (0, 44)):
        _spot(s, "bandstand", x, z, y=1.15)
    for deg in (45, 135, 225, 315):
        s.put(lamp(mat), *ring_point(BAND, LOOP_R + 2.8, deg), 0)
    for deg in (240, 300):
        x, z = ring_point(BAND, LOOP_R + 3.4, deg)
        s.put(bench(mat), x, z, face(x, z, *BAND))
    for deg in (125, 160):
        _spot(s, "loop", *ring_point(BAND, 17.0, deg))

    # the playground, west of the loop
    s.put(nb.slide(mat), -30, 48, 180)
    _spot(s, "slide", -27, 52)
    s.put(nb.swings(mat), -46, 49, 0)
    _spot(s, "swings", -46, 45)
    s.put(nb.sandbox(mat), -62, 48, 0)
    _spot(s, "sandbox", -63.5, 46.5, y=0.55)
    s.put(seesaw(mat), -44, 33, 0)
    _spot(s, "seesaw", -44, 30)
    s.put(roundabout(mat), -60, 33, 0)
    _spot(s, "roundabout", -60, 33, y=ROUNDABOUT_TOP)
    s.put(spring_rider(mat), -33, 33, 30)
    s.put(spring_rider(mat, "sign_teal"), -28.5, 36.5, -40)
    s.put(bench(mat), -69, 40, -90)
    _spot(s, "playground", -36, 39)

    # the rose garden, east of the loop
    s.put(garden_fountain(mat), *GARDEN, 0)
    _spot(s, "fountain", GARDEN[0], GARDEN[1] - 4.5)
    for i, deg in enumerate((30, 90, 150, 210, 330)):
        s.put(rose_bed(mat, i), *ring_point(GARDEN, 8.6, deg), 0)
    _spot(s, "roses", *ring_point(GARDEN, 8.6, 90), y=0.57)
    _spot(s, "roses", *ring_point(GARDEN, 12.4, 330))
    s.put(rose_arch(mat), 26, 40, 90)
    s.put(rose_arch(mat), GARDEN[0], 30.5, 0)
    s.put(topiary_cat(mat), 66, 51, face(66, 51, *GARDEN))
    _spot(s, "topiary", 62.5, 48)
    s.put(sundial(mat), *SUNDIAL, 0)
    s.put(bench(mat), 46, 53, 0)
    s.put(bin_(mat), 38, 53, 0)
    _spot(s, "garden", 31, 50)

    # the far end and the border trees
    for (x, z) in ((-40, 54), (6, 55)):
        _spot(s, "far", x, z)
    for (x, z) in ((-71, 52), (-57, 53.5), (-22, 54), (36, 53.5), (71, 36), (-71, 24), (71, -40), (-71, -44),
                   (44, -53.5), (71, 4)):
        s.put(poplar(mat, h=12.0 + (x * 7 + z) % 3), x, z, 0)

    # rescue traps (props placed by the world): 3 trees, 2 bins, at least one of each deep
    for (x, z, turn) in ((-28, -16, 180), (-18, 27, 180), (20, 53, -90)):
        _spot(s, "trap_tree", x, z, turn=turn)
    for (x, z, turn) in ((10, -38.5, 0), (-14, 23.5, 90)):
        _spot(s, "trap_trashcan", x, z, turn=turn)
    return s.finish(_ground(), mat), s


def build_park_set(mat):
    objs, _ = build_set(mat)
    return objs


ASSETS = {
    "CatCafe_Park_Set": (build_park_set, 80000),
}
