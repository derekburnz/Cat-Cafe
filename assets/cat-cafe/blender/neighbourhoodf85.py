"""The F85 Neighbourhood (hometown-cannon.md section 6b): a long rectangle, 180 x 460 with the camp, so the run home with
a cat is long and in view. The set is the wild part, 180 x 430; the camp (CatCafe_Camp_NeighbourhoodF85, camps.py) lies
across its -Z end, outside it, as in F84.

  CatCafe_Neighbourhood_SetF85   the wild part dressed, in area space (areakit): place it at the area's centre on its
                                 floor, gate side -Z toward the camp, like every set. Walls at x +-90 and z +-215
                                 (WorldBuilder's); the way in is a 24 stud opening (CampOpeningWidth) at x 0 on z -215.

Five blockers cross the width with their gaps on alternating sides, so the far end is never in a straight line:

  z -172 to -122   the first house block, houses back to back (tall); Cat Lane runs through it at x 24 to 34
  z -57 to -54     the village green's picket fence with a box hedge behind it, about 4 high; its gap at x -38 to -22
  z 10.6 to 17.4   the road works dug along Paw Road, red and white barriers 3.7 high round a trench, spoil heaps,
                   a digger and a skip; crossed only on the steel plates at x 22 to 38
  z 22 to 72       the second house block (tall); Mitten Lane runs through it at x -34 to -24
  z 149 to 152     the garden wall, brick under a hedge about 4 high; the Paw Parade arch at x 22 to 38

The low three let a hunter see a carrier coming but make them go round; a `_Barrier` 30 high on each stops anyone
jumping one, and on each house block from the house fronts back. The far end is Paw Parade: the corner shop against the
far wall with the playground beside it and two houses across, the best of the Neighbourhood's landmarks.

The way, camp to far end: Whisker Lane north from the gate, east along it to Cat Lane, through the first block to
Green Side and the village green, through the fence's gap into the allotments, over the plated crossing of the road
works, west along Paw Road to Mitten Lane, through the second block to Mitten Row and the back gardens, through the
Paw Parade arch to the shop and the playground. Shortest walk from the pad (walk check on the Part model) about 550 to
the shop and about 630 to the far corner (6b: about 575 camp to far end).

Points (manifest points_roblox): [x, y, z, zone], zone "near" (the camp half, z < 0) or "deep" (the far half). The
traps are built in, as in v3.2: `trap_shed` x2 (a garden shed with a jammed door, the door on the piece's -Z) and
`trap_gutter` x2 (a bungalow's front gutter, 7 up, by the downpipe), each with the piece's turn as a fifth number.
Three of the four are deep and none is within 100 studs of the camp.
"""

import math

from mathutils import Matrix

import neighbourhood as nb
import parkset as pk
import sewer as sw
from areakit import Set, flowers, rx, tree_round, turned, window
from common import RB, Builder, text_width
from neighbourhoodset import (BARRIER_H, BED_TOP, BUS_SEAT, FRONT, GREENHOUSE_FLOOR, GUTTER_SPOT, GUTTER_Z, HD,
                              PATH_Y, PAVE_Y, PLOT, ROAD_Y, SHOP_D, WALL_D, _block_end, _lot, _run, _spot, _strip,
                              bench, bird_bath, bl, bus_stop, car, compost_bin, corner_shop, deck_chair, face,
                              fingerpost, flower_bed, front_fence, greenhouse, low_hedge, pier, playhouse, post_box,
                              potting_shed, rects_minus, scarecrow, seg, side_fence, span, street_sign, sunflowers,
                              town_hedge, veg_bed, washing_line, water_butt)

NAME = "CatCafe_Neighbourhood_SetF85"
N = "CatCafe_Neighbourhood_"
HALF_X, HALF_Z = 90.0, 215.0            # WorldBuilder's walls at +-90, +-215 (NeighbourhoodWidth 180, Depth 430)
IN_X, IN_Z = HALF_X - 0.5 - WALL_D, HALF_Z - 0.5 - WALL_D       # 87.1, 212.1
GATE_HALF = 19.0                        # CatCafe_Neighbourhood_GateF85 is about 36.6 wide, centred on the lane
ROAD_END = 76.0                         # the streets across end in turning heads (radius 8) short of the side walls

S1_Z = -180.0                           # Whisker Lane, across in front of the first block
ROW1 = (-172.0, -122.0)                 # the first block's front fences: south on S1, north on S2
S2_Z = -114.0                           # Green Side
G1_X = 29.0                             # Cat Lane, through the first block
R1W, R1E = (-IN_X, G1_X - 8.0), (G1_X + 8.0, IN_X)
FENCE_Z, GAP_B = -57.0, (-38.0, -22.0)  # the green's picket fence (its face) and its gap
S3_Z = 14.0                             # Paw Road, dug up
WORKS = (10.6, 17.4)                    # the works' barrier lines
CROSS = (22.0, 38.0)                    # the plated crossing between them
ROW2 = (22.0, 72.0)                     # the second block
S4_Z = 80.0                             # Mitten Row
G2_X = -29.0                            # Mitten Lane
R2W, R2E = (-IN_X, G2_X - 8.0), (G2_X + 8.0, IN_X)
WALL_Z, GAP_E = 149.0, (22.0, 38.0)     # the garden wall (its face) and the Paw Parade arch
S5_Z = 166.0                            # Paw Parade
FAR_ROW = (31.0, IN_X)                  # the two houses across the parade
SHOP = (0.0, IN_Z - SHOP_D / 2 - 0.4)   # the corner shop, its back to the far wall
PLAY = (-52.0, 192.5, 64.0, 33.0)       # the playground's safety surface: centre and size

ROADS = [(-5.0, 5.0, -IN_Z, S1_Z - 5),
         (-ROAD_END, ROAD_END, S1_Z - 5, S1_Z + 5), (G1_X - 5, G1_X + 5, S1_Z + 5, S2_Z - 5),
         (-ROAD_END, ROAD_END, S2_Z - 5, S2_Z + 5),
         (-IN_X + 0.05, IN_X - 0.05, S3_Z - 5, S3_Z + 5), (G2_X - 5, G2_X + 5, S3_Z + 5, S4_Z - 5),
         (-ROAD_END, ROAD_END, S4_Z - 5, S4_Z + 5),
         (-ROAD_END, ROAD_END, S5_Z - 5, S5_Z + 5)]
HEADS = [(sx * ROAD_END, z, 8.0) for sx in (-1, 1) for z in (S1_Z, S2_Z, S4_Z, S5_Z)]
PAVES = [(-8.0, -5.0, -IN_Z, S1_Z - 8), (5.0, 8.0, -IN_Z, S1_Z - 8),
         (-ROAD_END, ROAD_END, S1_Z - 8, S1_Z - 5),
         (-ROAD_END, ROAD_END, S1_Z + 5, S1_Z + 8),
         (G1_X - 8, G1_X - 5, S1_Z + 8, S2_Z - 8), (G1_X + 5, G1_X + 8, S1_Z + 8, S2_Z - 8),
         (-ROAD_END, ROAD_END, S2_Z - 8, S2_Z - 5), (-ROAD_END, ROAD_END, S2_Z + 5, S2_Z + 8),
         (-IN_X + 0.05, IN_X - 0.05, S3_Z - 8, S3_Z - 5), (-IN_X + 0.05, IN_X - 0.05, S3_Z + 5, S3_Z + 8),
         (G2_X - 8, G2_X - 5, S3_Z + 8, S4_Z - 8), (G2_X + 5, G2_X + 8, S3_Z + 8, S4_Z - 8),
         (-ROAD_END, ROAD_END, S4_Z - 8, S4_Z - 5), (-ROAD_END, ROAD_END, S4_Z + 5, S4_Z + 8),
         (-ROAD_END, ROAD_END, S5_Z - 8, S5_Z - 5), (-ROAD_END, ROAD_END, S5_Z + 5, S5_Z + 8)]
GRAVEL = "paving_sand"


# ------------------------------------------------------------------------------------------------- ground --
def _ground():
    """Roads (top 0.24) with centre dashes, pavements (0.34) cut round them, turning heads, the footpaths across the
    green, the allotments and the back gardens, the parade in front of the shop and the playground's surface."""
    g = Builder()
    for (x0, x1, z0, z1) in ROADS:
        span(g, x0, x1, z0, z1, 0.015, ROAD_Y, "concrete_dark")
    for (x, z, r) in HEADS:
        g.cyl_base(bl(x, z, 0.015), r, ROAD_Y + 0.006 - 0.015, "concrete_dark", segments=24, bevel=False)
    for (x0, x1, z0, z1) in rects_minus(PAVES, ROADS):
        span(g, x0, x1, z0, z1, 0.01, PAVE_Y, "concrete")
    dash = ROAD_Y + 0.01

    def dashes(p0, p1, step=7.0):
        L = math.hypot(p1[0] - p0[0], p1[1] - p0[1])
        ux, uz = (p1[0] - p0[0]) / L, (p1[1] - p0[1]) / L
        for i in range(int(L / step)):
            t = (i + 0.5) * step
            x, z = p0[0] + ux * t, p0[1] + uz * t
            _strip(g, (x - ux * 1.2, z - uz * 1.2), (x + ux * 1.2, z + uz * 1.2), 0.4, "offwhite", dash)

    dashes((0, -IN_Z + 2), (0, S1_Z - 6))
    for z in (S1_Z, S2_Z, S4_Z, S5_Z):
        dashes((-ROAD_END + 4, z), (ROAD_END - 4, z))
    dashes((G1_X, S1_Z + 6), (G1_X, S2_Z - 6))
    dashes((G2_X, S3_Z + 6), (G2_X, S4_Z - 6))
    # footpaths: across the green, through the allotments, through the back gardens
    for pts in ([(G1_X, S2_Z + 8), (14.0, -88.0), (-30.0, -70.0), (-30.0, FENCE_Z)],
                [(-30.0, FENCE_Z + 3.0), (-30.0, -40.0), (30.0, -16.0), (30.0, S3_Z - 8)],
                [(G2_X, S4_Z + 8), (-14.0, 104.0), (30.0, 128.0), (30.0, WALL_Z)]):
        for a, b in zip(pts, pts[1:]):
            _strip(g, a, b, 3.0, GRAVEL, 0.05)
    for (a, b) in (((30.0, -16.0), (80.0, -16.0)), ((-84.0, 112.0), (-24.0, 112.0))):
        _strip(g, a, b, 2.4, GRAVEL, 0.044)
    # the parade: the shop's forecourt and the square in front of it, one slab from the pavement to the shop
    span(g, -16.0, 16.0, S5_Z + 8, SHOP[1] - SHOP_D / 2, 0.01, PATH_Y, "paving_light")
    x, z, w, d = PLAY
    g.box_base(bl(x, z), (w, d, 0.045), "terracotta", bevel=False)
    return g


# -------------------------------------------------------------------------------------------------- walls --
def _walls(s, mat):
    far = ("fence", "hedge", "brick")
    _run(s, mat, far, 6, 2 * IN_X, lambda t: (-IN_X + t, IN_Z, 0), 0)
    _run(s, mat, ("hedge", "brick", "fence"), 14, 2 * IN_Z, lambda t: (IN_X, -IN_Z + t, 90), 1)
    _run(s, mat, ("brick", "fence", "hedge"), 14, 2 * IN_Z, lambda t: (-IN_X, IN_Z - t, -90), 2)
    for sx in (-1, 1):
        s.put(pier(mat, h=11.2, w=2.4), sx * (IN_X + 1.2), IN_Z, 0)                         # far corners
        s.put(pier(mat, h=6.0, w=2.4), sx * (IN_X + 1.2), -IN_Z - 0.3, 180)                 # camp corners
        L = IN_X - GATE_HALF - 1.0
        s.put(town_hedge(mat, L), sx * (GATE_HALF + 1.0 + L / 2), -IN_Z, 180)                # camp side, low
        s.put(nb.lamp_post(mat), sx * (GATE_HALF + 2.5), -IN_Z + 1.5, 0)                     # either side of the gate
    bar = Builder()                       # all round but the way in: a jump from a porch clears WorldBuilder's walls
    ox = IN_X + WALL_D
    bar.box_base((0, IN_Z + WALL_D / 2, 0), (2 * ox, WALL_D, BARRIER_H), "offwhite", bevel=False)              # far
    for sx in (-1, 1):
        bar.box_base((sx * (IN_X + WALL_D / 2), 0, 0), (WALL_D, 2 * IN_Z, BARRIER_H), "offwhite", bevel=False)  # sides
        bar.box_base((sx * (GATE_HALF + ox) / 2, -(IN_Z + WALL_D / 2), 0), (ox - GATE_HALF, WALL_D, BARRIER_H),
                     "offwhite", bevel=False)                                                                 # camp
    s.put([bar.finalize(N + "Walls_Barrier", mat)], 0, 0, 0)


# -------------------------------------------------------------------------------------------- house blocks --
def _row(s, g, mat, plots, zc, rot, x0, x1, width=PLOT, seed=0):
    """A row of plots facing one street (neighbourhoodset._row with its own plot width and ends): plots are
    (x, variant, spot, extras). Side fences close the gaps between houses just behind the front line, low hedges part
    the front gardens, and box hedges fill the front line from the last fence to the row's ends."""
    fs = -1 if rot == 0 else 1
    line = zc + fs * (HD / 2 - 0.35)
    mid = zc + fs * (HD / 2 + 0.2 + 3.15)
    fence_z = zc + fs * FRONT
    xs = sorted(p[0] for p in plots)
    for i, (x, variant, spot, extras) in enumerate(plots):
        _lot(s, g, mat, variant, x, zc, rot, i + seed, spot, extras, width=width)
    edges = [x0] + [e for x in xs for e in (x - 10.5, x + 10.5)] + [x1]
    for a, b in zip(edges[0::2], edges[1::2]):
        a2 = a + ((0.6 if abs(a) > IN_X - 0.1 else 0.25) if a == x0 else 0.0)
        b2 = b - ((0.6 if abs(b) > IN_X - 0.1 else 0.25) if b == x1 else 0.0)
        if b2 - a2 > 0.8:
            s.put(side_fence(mat, b2 - a2), (a2 + b2) / 2, line, rot)
    for a, b in zip(xs, xs[1:]):
        if abs(b - a - width) < 0.1:
            s.put(low_hedge(mat, 6.3), (a + b) / 2, mid, 90)
    for (a, b) in ((x0 + 0.5, xs[0] - width / 2), (xs[-1] + width / 2, x1 - 0.5)):
        if b - a > 0.8:
            s.put(front_fence(mat, "hedge", b - a, -(b - a) / 2 - 3.0, gap_w=0.0), (a + b) / 2, fence_z, rot)
    return xs


def _block(s, g, mat, row, west, east, south, north, wplot, eplot):
    """A block of houses back to back between two streets, split by a lane: `south` and `north` are the plot lists
    for its west and east parts ((west, east) each). Close-board fences run along the lane's sides between the house
    fronts, low hedges part the corner front gardens from the lane, and trees stand in the back gardens."""
    zs, zn = row[0] + FRONT, row[1] - FRONT
    _row(s, g, mat, south[0], zs, 0, west[0], west[1], wplot[0])
    _row(s, g, mat, south[1], zs, 0, east[0], east[1], eplot[0], seed=1)
    _row(s, g, mat, north[0], zn, 180, west[0], west[1], wplot[1], seed=2)
    _row(s, g, mat, north[1], zn, 180, east[0], east[1], eplot[1], seed=1)
    for x in (west[1] - 0.2, east[0] + 0.2):
        _block_end(s, mat, x, row[0] + 7.9, row[1] - 7.9)
    for x in (west[1] - 0.7, east[0] + 0.7):
        for (z0, z1) in ((row[0] + 0.8, row[0] + 7.1), (row[1] - 7.1, row[1] - 0.8)):
            s.put(low_hedge(mat, z1 - z0), x, (z0 + z1) / 2, 90)
    return zs, zn


def _blocks(s, g, mat):
    _block(s, g, mat, ROW1, R1W, R1E,
           ([(-70, "C2", "porch", ("bed",)), (-44, "A2", "flowerbed", ("bed", "mail")), (-18, "B2", None, ("hedge",)),
             (8, "C", "porch", ("bed", "hedge"))],
            [(49, "B", "flowerbed", ("bed",)), (73, "A3", None, ("mail",))]),
           ([(-70, "A2", None, ("bed",)), (-44, "C", "flowerbed", ("bed",)), (-18, "B3", None, ("hedge", "mail")),
             (8, "A", "porch", ("bed",))],
            [(49, "C3", "porch", ("hedge",)), (73, "B2", None, ("bed",))]),
           (PLOT, PLOT), (24.0, 24.0))
    _block(s, g, mat, ROW2, R2W, R2E,
           ([(-73, "B3", "porch", ("bed",)), (-49, "C", "flowerbed", ("bed", "mail"))],
            [(-8, "A", "porch", ("hedge",)), (18, "C3", "flowerbed", ("bed",)), (44, "D2", "flowerbed", ("bed",)),
             (70, "B", "porch", ("mail",))]),
           ([(-73, "A3", "flowerbed", ("bed",)), (-49, "B2", "porch", ("hedge",))],
            [(-8, "C2", "porch", ("bed", "mail")), (18, "A2", None, ("hedge",)), (44, "B", "flowerbed", ("bed",)),
             (70, "C", "porch", ("bed",))]),
           (24.0, 24.0), (PLOT, PLOT))
    zs2 = ROW2[0] + FRONT
    _spot(s, "trap_gutter", *turned(44, zs2, 0, *GUTTER_SPOT), y=GUTTER_Z, turn=0)          # the Mitten Row bungalow
    # trees in the back gardens, over the roofs
    tb = Builder()
    for (x, z, h, k) in ((-82, -147, 14, 0), (-31, -148, 15, 1), (16, -146, 14, 2), (62, -147, 15, 1),
                         (-58, 47, 15, 2), (-4, 46, 14, 0), (31, 48, 16, 1), (80, 46, 14, 2)):
        tree_round(tb, -x, z, 0, h=h, r=3.4 + 0.3 * k, leaf=("leaf_green", "leaf_dark", "mint")[k])
    s.put([tb.finalize(N + "BackTrees", mat)], 0, 0, 0)


# -------------------------------------------------------------------------------------------- low blockers --
def _gap_pier(b, x, z0, z1, h, ball=True):
    """A brick pier on a concrete plinth from z0 to z1 at x, a stone ball on top."""
    w = 1.6
    b.box_base(bl(x, (z0 + z1) / 2), (w + 0.3, z1 - z0 + 0.3, 0.5), "concrete", bevel=False)
    b.box_base(bl(x, (z0 + z1) / 2, 0.5), (w, z1 - z0, h - 0.5), "brick", bevel=False)
    b.box_base(bl(x, (z0 + z1) / 2, h), (w + 0.3, z1 - z0 + 0.3, 0.3), "concrete", bevel=False)
    if ball:
        b.ico(bl(x, (z0 + z1) / 2, h + 0.8), 0.6, "concrete", subdivisions=1)


def _green_fence(s, mat, z, gap):
    """The village green's edge across the area: a white picket fence 2.6 high (its face at z, toward the camp) and a
    clipped box hedge 3.6 to 4 high behind it, so a hunter sees over both; brick piers either side of the one gap.
    The `_Barrier` stands on the fence and hedge."""
    b, bar = Builder(), Builder()
    for (a0, a1) in ((-IN_X, gap[0]), (gap[1], IN_X)):
        L = a1 - a0
        n = max(2, int(L / 1.15))
        for i in range(n + 1):
            b.box_base(bl(a0 + 0.3 + i * (L - 0.6) / n, z + 0.3), (0.36, 0.36, 2.6), "offwhite", bevel=False)
        for h in (0.7, 1.9):
            b.box(bl((a0 + a1) / 2, z + 0.53, h), (L - 0.4, 0.12, 0.25), "offwhite", bevel=False)
        m = max(1, round(L / 6.0))
        step = L / m
        for i in range(m):
            c, h = a0 + (i + 0.5) * step, 3.6 + 0.2 * (i % 3)
            sw_ = ("leaf_dark", "leaf_green")[i % 2]
            x, y, _ = bl(c, z + 1.8)
            b.box_base((x, y, 0), (step + 0.02 * (i % 2), 1.8 + 0.02 * (i % 2), h), sw_, bevel=False)
            b.ico((x, y, h), 1.1, sw_, subdivisions=1, scale=(step / 2.2, 0.8, 0.4))
        span(bar, a0, a1, z, z + 2.7, 0, BARRIER_H, "offwhite")
    for x in (gap[0] + 0.5, gap[1] - 0.5):
        _gap_pier(b, x, z - 0.2, z + 2.9, 4.6)
    s.put([b.finalize(N + "GreenFence", mat), bar.finalize(N + "GreenFence_Barrier", mat)], 0, 0, 0)
    s.put(fingerpost(mat, "ALLOTMENTS"), gap[1] + 3.0, z - 2.0, 0)


def _garden_wall(s, mat, z, gap):
    """The garden wall across the area: brick 2.2 high under a coping, a hedge 3.6 to 4 high behind it, and the Paw
    Parade arch over the gap: two tall piers, an iron band and the name board, lanterns on top. Barrier on the wall."""
    b, bar, lamps = Builder(), Builder(), Builder()
    for (a0, a1) in ((-IN_X, gap[0]), (gap[1], IN_X)):
        L = a1 - a0
        b.box_base(bl((a0 + a1) / 2, z + 0.5), (L, 1.0, 2.2), "brick", bevel=False)
        b.box_base(bl((a0 + a1) / 2, z + 0.5, 2.2), (L + 0.02, 1.3, 0.2), "concrete", bevel=False)
        m = max(1, round(L / 6.0))
        step = L / m
        for i in range(m):
            c, h = a0 + (i + 0.5) * step, 3.6 + 0.2 * ((i + 1) % 3)
            sw_ = ("leaf_green", "leaf_dark")[i % 2]
            x, y, _ = bl(c, z + 2.2)
            b.box_base((x, y, 0), (step + 0.02 * (i % 2), 1.6 + 0.02 * (i % 2), h), sw_, bevel=False)
            b.ico((x, y, h), 1.0, sw_, subdivisions=1, scale=(step / 2.2, 0.8, 0.4))
        span(bar, a0, a1, z, z + 3.0, 0, BARRIER_H, "offwhite")
    for x in (gap[0] + 0.6, gap[1] - 0.6):
        _gap_pier(b, x, z - 0.3, z + 3.1, 8.6, ball=False)
        lamps.box_base(bl(x, z + 1.4, 8.9), (0.9, 0.9, 1.0), "lamp_warm", bevel=False)
        b.box_base(bl(x, z + 1.4, 9.9), (1.3, 1.3, 0.2), "fur_black", bevel=False)
    gx0, gx1 = gap[0] + 1.4, gap[1] - 1.4
    xc = (gx0 + gx1) / 2
    b.box(bl(xc, z + 1.4, 8.2), (gx1 - gx0 + 0.6, 0.3, 0.3), "fur_black", bevel=False)                 # iron band
    text = "PAW PARADE"
    tw = text_width(text, 0.2)
    b.box_base(bl(xc, z + 1.4, 6.5), (tw + 1.0, 0.24, 1.6), "sign_teal", bevel=False)                  # hangs from it
    rb = RB()
    rb.text(text, (xc + tw / 2, 6.8, z + 1.28), 0.2, 0.06, "offwhite", right=(-1, 0, 0))
    s.put([b.finalize(N + "GardenWall", mat), lamps.finalize(N + "GardenWall_Bulb", mat),
           bar.finalize(N + "GardenWall_Barrier", mat), rb.finalize(N + "GardenWallSign", mat)], 0, 0, 0)


# --------------------------------------------------------------------------------------------- road works --
def _works_line(b, lamps, a0, a1, c, along_x, out, k0=0):
    """Road-works barriers from a0 to a1 on the line c (z for a line along x, x for one along z): posts on rubber feet
    every 3.8 or so, two boards between each pair (red over white, then white over red) on the side `out` (+1 or -1
    along the other axis), an amber lamp on every other post."""
    L = a1 - a0
    n = max(1, round(L / 3.8))
    step = (L - 0.3) / n
    y0 = ROAD_Y

    def P(t, h, off=0.0):
        return bl(t, c + off, h) if along_x else bl(c + off, t, h)

    def sz(lx, ly, lz):
        return (lx, ly, lz) if along_x else (ly, lx, lz)

    for i in range(n + 1):
        t = a0 + 0.15 + i * step
        b.box_base(P(t, y0), sz(0.5, 1.4, 0.3), "fur_black", bevel=False)
        b.box_base(P(t, y0 + 0.3), sz(0.18, 0.18, 3.4), "offwhite", bevel=False)
        if (i + k0) % 2 == 0:
            lamps.box_base(P(t, y0 + 3.65), sz(0.36, 0.36, 0.4), "lamp_warm", bevel=False)
    for i in range(n):
        t = a0 + 0.15 + (i + 0.5) * step
        top, low = ("bowl_red", "offwhite") if (i + k0) % 2 == 0 else ("offwhite", "bowl_red")
        b.box_base(P(t, y0 + 2.9, out * 0.12), sz(step - 0.02, 0.1, 0.55), top, bevel=False)
        b.box_base(P(t, y0 + 1.5, out * 0.12), sz(step - 0.02, 0.1, 0.45), low, bevel=False)


def digger(mat):
    """A little tracked digger, arm out over the trench at its local +X end (Roblox -X), cab glass as _Glass."""
    b, glass = Builder(), Builder()
    for y in (-1.35, 1.35):
        b.box_base((0, y, 0), (4.4, 0.9, 0.85), "fur_black")                                   # tracks
        for x in (-1.6, 0, 1.6):
            b.cyl((x, y - 0.47 * (1 if y < 0 else -1), 0.42), 0.32, 0.06, "metal", segments=8, rot=rx(90),
                  bevel=False)
    b.box_base((0, 0, 0.85), (3.4, 2.0, 0.35), "concrete_dark", bevel=False)                   # undercarriage
    b.box_base((-0.3, 0, 1.2), (3.2, 2.7, 1.0), "pastel_butter", bevel=False)                  # the body
    b.box_base((-1.7, 0, 1.2), (0.6, 2.8, 1.25), "concrete_dark", bevel=False)                 # counterweight
    b.box_base((-0.6, 0.35, 2.2), (1.8, 1.7, 0.12), "pastel_butter", bevel=False)              # cab floor
    for (x, y) in ((-1.4, -0.42), (-1.4, 1.12), (0.2, -0.42), (0.2, 1.12)):
        b.box_base((x, y, 2.32), (0.14, 0.14, 1.9), "pastel_butter", bevel=False)              # cab posts
    b.box_base((-0.6, 0.35, 4.22), (2.0, 1.9, 0.18), "pastel_butter", bevel=False)              # cab roof
    glass.box_base((0.2, 0.35, 2.4), (0.06, 1.4, 1.75), "glass", bevel=False)                  # windscreen
    glass.box_base((-0.6, 1.12, 2.4), (1.45, 0.06, 1.75), "glass", bevel=False)                # side window
    b.box_base((-0.75, 0.35, 2.32), (0.6, 0.6, 0.5), "fur_black", bevel=False)                 # seat
    # the arm: a boom up and out from the body's front, a dipper down into the trench, a bucket
    bx, bz = 0.9, 1.9
    b.box((bx + 1.1, -0.55, bz + 1.15), (2.9, 0.45, 0.5), "pastel_butter", rot=(Matrix.Rotation(-0.75, 3, "Y")))
    b.box((bx + 2.7, -0.55, bz + 0.5), (0.45, 0.42, 2.9), "pastel_butter", rot=(Matrix.Rotation(-0.35, 3, "Y")))
    b.box((bx + 3.15, -0.55, 0.65), (1.0, 1.1, 0.75), "metal", rot=(Matrix.Rotation(0.5, 3, "Y")))
    b.cyl((bx + 0.25, -0.55, bz), 0.32, 0.6, "metal", segments=8, rot=rx(90), bevel=False)  # the boom's pin
    return [b.finalize(N + "Digger", mat), glass.finalize(N + "Digger_Glass", mat)]


def skip_(mat):
    """A yellow skip 5 long on two skids, a rim round its top, full of rubble that heaps up to about 3."""
    b = Builder()
    L, W, H = 5.0, 2.8, 2.0
    b.box_base((0, 0, 0.15), (L - 0.4, W - 0.4, 0.2), "pastel_butter", bevel=False)               # floor
    for sy in (-1, 1):
        b.box_base((0, sy * (W / 2 - 0.1), 0.15), (L, 0.2, H), "pastel_butter", bevel=False)
        b.box_base((0, sy * (W / 2 + 0.02), H - 0.25), (L - 0.4, 0.1, 0.3), "fur_orange", bevel=False)   # the rim
    for sx in (-1, 1):
        b.box_base((sx * (L / 2 - 0.1), 0, 0.15), (0.2, W - 0.38, H), "pastel_butter", bevel=False)
        b.box_base((sx * 1.4, 0, 0), (0.5, W, 0.15), "fur_black", bevel=False)                     # skids
    for (x, y, r, sw_) in ((-1.2, -0.4, 1.0, "concrete"), (0.2, 0.4, 1.1, "brick"), (1.4, -0.3, 0.9, "choco"),
                           (-0.3, -0.5, 0.7, "dark_wood")):
        b.ico((x, y, H - 0.2), r, sw_, subdivisions=1, scale=(1.1, 0.8, 0.9))
    b.box((0.6, 0.2, H + 0.45), (2.4, 0.18, 0.18), "caramel_wood", bevel=False, rot=rx(20))        # a plank
    return [b.finalize(N + "Skip", mat)]


def site_hut(mat):
    """The works' cabin: a portable hut 8 x 3.4 on sleepers, a door and two windows in front (-Y), a step."""
    b, panes, lamp = Builder(), Builder(), Builder()
    W, D, H = 8.0, 3.4, 3.4
    for x in (-3.0, 0.0, 3.0):
        b.box_base((x, 0, 0), (0.6, D + 0.2, 0.4), "dark_wood", bevel=False)
    b.box_base((0, 0, 0.4), (W, D, H), "sign_teal")
    b.box_base((0, 0, 0.4 + H), (W + 0.3, D + 0.3, 0.25), "offwhite", bevel=False)
    for x in (-2.6, 2.6):
        window(b, panes, x, -D / 2, 2.4, 1.8, 1.2, cross=False)
    b.box_base((-0.2, -D / 2 - 0.05, 0.4), (1.3, 0.12, 2.6), "offwhite", bevel=False)            # the door
    b.box((0.25, -D / 2 - 0.15, 1.7), (0.12, 0.12, 0.3), "metal", bevel=False)
    b.box_base((-0.2, -D / 2 - 0.45, 0), (1.8, 0.9, SITE_HUT_STEP), "metal", bevel=False)      # the step
    lamp.box((-0.2, -D / 2 - 0.08, 3.25), (0.4, 0.2, 0.3), "lamp_warm", bevel=False)
    b.box((1.8, -D / 2 - 0.03, 3.3), (1.8, 0.08, 0.4), "offwhite", bevel=False)                  # a notice
    return [b.finalize(N + "SiteHut", mat), panes.finalize(N + "SiteHut_Pane", mat),
            lamp.finalize(N + "SiteHut_Bulb", mat)]


def works_sign(mat, text="ROAD WORKS"):
    """A sign on two legs with rubber feet: a yellow board with black words, facing -Y."""
    b = Builder()
    tw = text_width(text, 0.22)
    for x in (-(tw / 2 + 0.3), tw / 2 + 0.3):
        b.box_base((x, -0.16, 0), (0.12, 0.12, 2.7), "metal", bevel=False)
        b.box_base((x, -0.16, 0), (0.3, 1.2, 0.12), "fur_black", bevel=False)
    b.box_base((0, -0.24, 1.1), (tw + 1.0, 0.08, 1.5), "pastel_butter", bevel=False)
    rb = RB()
    rb.text(text, (tw / 2, 1.3, -0.28), 0.22, 0.06, "fur_black", right=(-1, 0, 0))
    return [b.finalize(N + "WorksSign", mat), rb.finalize(N + "WorksSignText", mat)]


SITE_HUT_STEP = 0.4                      # the step's top, under the hut's floor at 0.4


def _works(s, mat):
    """The road works dug along Paw Road (z 10.6 to 17.4): barriers round two pens either side of the plated crossing,
    a trench down the middle of each with pipes in it, spoil heaps, a digger and a skip. The `_Barrier` is a box over
    each pen, standing on its barriers."""
    b, lamps, deco, bar = Builder(), Builder(), Builder(), Builder()
    z0, z1 = WORKS
    pens = ((-IN_X, CROSS[0]), (CROSS[1], IN_X))
    for k, (a0, a1) in enumerate(pens):
        _works_line(b, lamps, a0 + 0.05, a1, z0, True, -1, k)
        _works_line(b, lamps, a0 + 0.05, a1, z1, True, 1, k + 1)
        side = a1 if k == 0 else a0
        _works_line(b, lamps, z0 + 0.9, z1 - 0.9, side, False, 1 if k == 0 else -1, k)
        # the trench and its lips, pipes laid in it, heaps of spoil and broken tarmac along its north side
        t0, t1 = a0 + 1.5, a1 - 1.5
        span(b, t0, t1, S3_Z - 1.6, S3_Z + 1.6, ROAD_Y - 0.01, ROAD_Y + 0.02, "fur_black")
        for zz in (S3_Z - 1.75, S3_Z + 1.75):
            span(b, t0 - 0.3, t1 + 0.3, zz - 0.25, zz + 0.25, ROAD_Y - 0.005, ROAD_Y + 0.09, "choco")
        for (p0, p1, sw_) in ((t0 + 2.0, t0 + 14.0, "shirt_blue"), (t1 - 16.0, t1 - 4.0, "fur_orange")):
            deco.cyl(bl((p0 + p1) / 2, S3_Z, ROAD_Y + 0.2), 0.55, p1 - p0, sw_, segments=10, rot=(math.pi / 2, "Y"),
                     bevel=False)
        n = max(2, round((t1 - t0) / 9.0))
        for i in range(n):
            x = t0 + 3.0 + i * (t1 - t0 - 6.0) / max(1, n - 1)
            if CROSS[0] - 6 < x < CROSS[1] + 6 or abs(x + 50.0) < 6.5 or abs(x - 62.0) < 6.0:
                continue
            r, hz = 1.4 + 0.25 * (i % 3), 2.6 + 0.6 * (i % 3)
            sw_ = ("choco", "concrete", "dark_wood")[i % 3]
            b.ico(bl(x, S3_Z + 1.3, ROAD_Y + hz / 2 - 0.1), r, sw_, subdivisions=1, scale=(1.5, 0.95, hz / 2 / r))
        span(bar, a0, a1 + 0.25 if k == 0 else a1, z0 - 0.3, z1 + 0.3, 0, BARRIER_H, "offwhite")
        if k == 1:
            span(bar, a0 - 0.25, a0, z0 - 0.3, z1 + 0.3, 0, BARRIER_H, "offwhite")
    # the crossing: steel plates over the trench between the pens, with stud bolts
    for i in range(3):
        x = CROSS[0] + 0.4 + (i + 0.5) * (CROSS[1] - CROSS[0] - 0.8) / 3
        b.box_base(bl(x, S3_Z, ROAD_Y), ((CROSS[1] - CROSS[0] - 0.8) / 3 - 0.06, 6.0, 0.08 + 0.006 * i), "metal",
                   bevel=False)
    s.put([b.finalize(N + "Works", mat), lamps.finalize(N + "Works_Bulb", mat), deco.finalize(N + "Works_Decor", mat),
           bar.finalize(N + "Works_Barrier", mat)], 0, 0, 0)
    s.put(digger(mat), -50.0, S3_Z, 0, y=ROAD_Y)
    s.put(skip_(mat), 62.0, S3_Z + 1.4, 0, y=ROAD_Y)
    for x in (-76.0, -24.0, 8.0, 48.0, 80.0):
        s.put(sw.traffic_cone(mat), x, WORKS[0] + 0.9, 0, y=ROAD_Y)
    s.put(works_sign(mat), 16.0, WORKS[0] - 2.8, 0, y=PAVE_Y)
    s.put(works_sign(mat, "FOOTPATH"), CROSS[1] + 4.0, WORKS[1] + 2.8, 180, y=PAVE_Y)
    s.put(site_hut(mat), -74.0, 0.0, 0)
    _spot(s, "works_hut", -73.8, -3.8)
    _spot(s, "works", 4.0, S3_Z - 6.5, y=PAVE_Y)
    _spot(s, "works", -62.0, S3_Z + 6.5, y=PAVE_Y)


# ------------------------------------------------------------------------------------------------ the near half --
def village_sign(mat, lines=("WHISKER", "GREEN")):
    """The green's sign: two posts, a painted board with the name on two lines over a strip of green, a little roof
    with a black cat sitting on its ridge."""
    b, rb = Builder(), RB()
    px = 0.2
    tw = max(text_width(t, px) for t in lines)
    W = tw + 1.8
    for x in (-W / 2, W / 2):
        b.box_base((x, 0, 0), (0.4, 0.4, 7.4), "dark_wood", bevel=False)
    b.box_base((0, 0, 4.2), (W - 0.36, 0.25, 2.8), "offwhite", bevel=False)
    b.box_base((0, -0.14, 4.3), (W - 0.8, 0.04, 0.35), "leaf_green", bevel=False)                  # the green
    for i, t in enumerate(lines):
        w = text_width(t, px)
        rb.text(t, (w / 2, 5.95 - 1.2 * i, -0.125), px, 0.06, "sign_teal", right=(-1, 0, 0))
    for sy in (-1, 1):                                                                              # the roof
        b.box((0, sy * 0.35, 7.55), (W + 0.6, 0.85, 0.12), "dark_wood", bevel=False, rot=rx(-sy * 25))
    b.ico((0.6, 0, 8.05), 0.36, "fur_black", subdivisions=1, scale=(0.75, 0.55, 1.0))              # the cat
    b.ico((0.6, -0.05, 8.6), 0.26, "fur_black", subdivisions=1)
    for dx in (-0.13, 0.13):
        b.box((0.6 + dx, -0.05, 8.86), (0.1, 0.08, 0.2), "fur_black", bevel=False)
    b.box((0.05, 0.15, 7.95), (0.9, 0.12, 0.12), "fur_black", bevel=False, rot=(Matrix.Rotation(0.5, 3, "Y")))
    return [b.finalize(N + "VillageSign", mat), rb.finalize(N + "VillageSignText", mat)]


def _near(s, g, mat):
    """The verge by the gate, the cars, the village green and the allotments."""
    # the verge: the bus stop on Whisker Lane, the post box, benches, bins, beds, the street sign
    s.put(bus_stop(mat), -14.0, -200.0, -90)
    _spot(s, "bus_stop", *turned(-14.0, -200.0, -90, 0, 0.6), y=BUS_SEAT)
    s.put(post_box(mat), 14.0, -196.0, 180)
    _spot(s, "post_box", 16.2, -196.0)
    for (x, r) in ((-58.0, 180), (56.0, 180)):
        s.put(bench(mat), x, -200.0, r)
        _spot(s, "verge_bench", x, -197.6)
    s.put(nb.recycling_bins(mat), 40.0, -207.0, 0)
    _spot(s, "bins", 44.0, -207.0)
    for i, x in enumerate((-36.0, 30.0, 72.0, -76.0)):
        s.put(flower_bed(mat, i), x, -192.5, 0)
    s.put(street_sign(mat, "WHISKER LANE"), 10.5, -189.0, 0)
    s.put(street_sign(mat, "CAT LANE"), G1_X + 7.0, -170.5, 180)
    for (x, r, sw_) in ((-40.0, -90, "shirt_blue"), (60.0, 90, "pastel_butter")):
        s.put(car(mat, sw_), x, S1_Z - 2.6, r, y=ROAD_Y)
    _spot(s, "car", -40.0, S1_Z - 7.0, y=PAVE_Y)
    s.put(car(mat, "mint"), 58.0, S2_Z - 2.6, 90, y=ROAD_Y)

    # the green: oaks, picnic tables, benches, beds, the village sign and the ice cream van on Green Side
    s.put(street_sign(mat, "GREEN SIDE"), -12.0, S2_Z + 7.0, 0)
    for (x, z, r) in ((-62.0, -90.0, 30), (60.0, -78.0, 200), (8.0, -64.0, 100)):
        s.put(pk.oak(mat), x, z, r)
    _spot(s, "oak", -58.5, -93.0)
    for i, (x, z, r) in enumerate(((-40.0, -96.0, 8), (44.0, -96.0, -10))):
        s.put(pk.picnic_table(mat), x, z, r)
        _spot(s, "picnic", *turned(x, z, r, 0, -4.0))
    for (x, z) in ((-60.0, -68.0), (66.0, -64.0)):
        s.put(bench(mat), x, z, face(x, z, 0, -82))
    _spot(s, "green_bench", *turned(-60.0, -68.0, face(-60.0, -68.0, 0, -82), 0, -2.4))
    for i, (x, z) in enumerate(((-18.0, -100.0), (30.0, -66.0))):
        s.put(pk.flower_bed(mat, i), x, z, 0)
    _spot(s, "flowerbed", -18.0, -100.0, y=0.62)
    s.put(village_sign(mat), -2.0, -101.0, 0)
    s.put(bird_bath(mat), 34.0, -82.0, 0)
    _spot(s, "birdbath", 36.5, -82.0)
    s.put(nb.ice_cream_van(mat), -48.0, S2_Z + 1.6, 90, y=ROAD_Y + 0.006)
    _spot(s, "van", *turned(-48.0, S2_Z + 1.6, 90, -5.0, 1.0), y=PAVE_Y)
    _green_fence(s, mat, FENCE_Z, GAP_B)

    # the allotments: beds along grass and gravel paths, sheds, a greenhouse, a scarecrow
    beds = [(-80, -46, "cabbage"), (-66, -46, "beans"), (-52, -46, "carrot"), (-80, -22, "pumpkin"),
            (-66, -22, "cabbage"), (-12, -46, "pumpkin"), (2, -46, "cabbage"), (16, -46, "beans"), (44, -46, "carrot"),
            (-2, -20, "carrot"), (14, -34, "beans"), (60, -6, "cabbage"), (74, -6, "pumpkin"), (-52, -8, "beans"),
            (-38, -8, "carrot"), (42, -28, "pumpkin")]
    for i, (x, z, crop) in enumerate(beds):
        s.put(veg_bed(mat, crop, i), x, z, 0)
    for (x, z) in ((-66, -46), (2, -46), (-38, -8)):
        _spot(s, "veg_bed", x - 1.6, z, y=BED_TOP)
    crops = Builder()
    for (x0, x1, z0, n) in ((-84.0, -60.0, -38.0, 3), (56.0, 82.0, -48.0, 4), (-20.0, 4.0, -12.0, 3)):
        z1 = z0 + 3.4 * (n - 1)
        g.box_base(bl((x0 + x1) / 2, (z0 + z1) / 2), (x1 - x0 + 1.0, z1 - z0 + 2.6, 0.04), "dark_wood", bevel=False)
        for k in range(n):
            z = z0 + 3.4 * k
            g.box_base(bl((x0 + x1) / 2, z), (x1 - x0, 1.5, 0.07), "choco", bevel=False)
            if k % 2 == 0:
                crops.box_base(bl((x0 + x1) / 2, z, 0.07), (x1 - x0 - 1.0, 0.7, 0.45),
                               ("leaf_dark", "leaf_green", "fur_fern")[(k // 2 + int(x0)) % 3], bevel=False)
    s.put([crops.finalize(N + "CropRows_Decor", mat)], 0, 0, 0)
    s.put(nb.garden_shed(mat), 66.0, -30.0, 0)
    _spot(s, "trap_shed", *turned(66.0, -30.0, 0, -0.6, -3.3), turn=0)
    s.put(water_butt(mat), 71.0, -26.0, 0)
    s.put(greenhouse(mat), -72.0, -10.0, 0)
    _spot(s, "greenhouse", -72.0, -11.0, y=GREENHOUSE_FLOOR)
    s.put(scarecrow(mat), 26.0, -38.0, 10)
    _spot(s, "scarecrow", 27.5, -41.5)
    s.put(compost_bin(mat), 84.0, -30.0, 0)
    _spot(s, "compost", 80.5, -30.0)
    s.put(potting_shed(mat), 84.0, -21.0, 90)
    s.put(water_butt(mat), -60.0, -32.0, 0)
    _spot(s, "water_butt", -58.5, -35.5)
    s.put(sunflowers(mat, 5), 48.0, -2.0, 90)
    _spot(s, "sunflowers", 50.5, 2.0)
    s.put(bench(mat), -8.0, -2.0, 180)
    _spot(s, "allot_bench", *turned(-8.0, -2.0, 180, 0, -2.4))
    _spot(s, "allotments", -30.0, -24.0)


# -------------------------------------------------------------------------------------------- the far half --
def _gardens(s, g, mat):
    """The back gardens between Mitten Row and the garden wall: lawns parted by low hedges, a trampoline, the washing
    line, a patio with deck chairs and a barbecue, gnomes, a paddling pool, a playhouse, a bird bath, a greenhouse and
    a garden shed (the second shed trap)."""
    s.put(street_sign(mat, "MITTEN ROW"), G2_X - 7.0, S4_Z + 7.0, 0)
    s.put(car(mat, "fur_rose"), -64.0, S4_Z + 2.6, 90, y=ROAD_Y)
    _spot(s, "car", -60.0, S4_Z + 7.0, y=PAVE_Y)
    for (z, x0, x1) in ((120.0, -IN_X + 0.6, -52.0), (124.0, 52.0, IN_X - 0.6)):
        s.put(low_hedge(mat, x1 - x0, h=3.0), (x0 + x1) / 2, z, 0)
    s.put(nb.trampoline(mat), -72.0, 100.0, 0)
    _spot(s, "trampoline", -72.0, 100.0, y=1.73)
    s.put(washing_line(mat), -62.0, 134.0, 0)
    _spot(s, "washing", -60.0, 131.5)
    g.box_base(bl(-78.0, 112.0), (14.0, 12.0, 0.06), "paving_light", bevel=False)                  # the patio
    for (x, z, r, sw_) in ((-82.0, 108.0, 200, "sign_teal"), (-77.5, 110.0, 165, "blush")):
        s.put(deck_chair(mat, sw_), x, z, r)
    _spot(s, "deckchair", -80.0, 104.5)
    s.put(nb.bbq(mat), -74.0, 116.0, -30)
    for (x, z) in ((-48.0, 106.0), (-44.0, 108.5)):
        s.put(nb.gnome(mat), x, z, 120)
    _spot(s, "gnomes", -46.0, 104.0)
    s.put(nb.kiddie_pool(mat), -40.0, 138.0, 0)
    _spot(s, "pool", -40.0, 133.0)
    s.put(playhouse(mat), 58.0, 100.0, 180)
    _spot(s, "playhouse", *turned(58.0, 100.0, 180, 0.8, -3.0))
    s.put(bird_bath(mat), 16.0, 112.0, 0)
    _spot(s, "birdbath", 18.5, 112.0)
    s.put(greenhouse(mat), 72.0, 138.0, 0)
    _spot(s, "greenhouse", 72.0, 137.0, y=GREENHOUSE_FLOOR)
    s.put(nb.garden_shed(mat), 80.0, 108.0, 90)
    _spot(s, "trap_shed", *turned(80.0, 108.0, 90, -0.6, -3.3), turn=90)
    s.put(potting_shed(mat), 46.0, 140.0, 0)
    br = face(-2.0, 128.0, 4.0, 113.0)
    s.put(bench(mat), -2.0, 128.0, br)
    _spot(s, "garden_bench", *turned(-2.0, 128.0, br, 0, -2.4))
    for i, (x, z) in enumerate(((-22.0, 136.0), (6.0, 96.0), (44.0, 114.0))):
        s.put(flower_bed(mat, i + 2), x, z, 0 if i % 2 else 90)
    _spot(s, "flowerbed", 6.0, 96.0, y=0.7)
    _spot(s, "garden", -84.0, 140.0)
    _spot(s, "garden", 84.0, 96.0)
    _garden_wall(s, mat, WALL_Z, GAP_E)


def _far(s, g, mat):
    """Paw Parade: the street past the wall, the corner shop against the far wall with its square, the playground
    beside it and the two houses across from it (the second gutter trap on the bungalow)."""
    s.put(street_sign(mat, "PAW PARADE"), 44.0, S5_Z - 7.0, 180)
    for x in (-60.0, 64.0):
        s.put(bench(mat), x, WALL_Z + 5.4, 180)
    _spot(s, "verge_bench", -60.0, WALL_Z + 7.8)
    _spot(s, "verge", 74.0, WALL_Z + 5.5)
    # the corner shop and its square
    cx, cz = SHOP
    s.put(corner_shop(mat), cx, cz, 0)
    fy = cz - SHOP_D / 2
    _spot(s, "shop_step", cx, fy - 1.4, y=0.4)
    _spot(s, "fruit_stall", cx - 9.0, fy - 4.6, y=PATH_Y)
    s.put(bench(mat), cx - 12.5, fy - 9.0, 0)
    _spot(s, "shop_bench", cx - 12.5, fy - 11.4, y=PATH_Y)
    s.put(nb.bicycle(mat), cx + 14.6, fy - 1.6, 90)
    s.put(post_box(mat), cx + 12.0, fy - 12.0, 0, y=PATH_Y)
    for sx in (-1, 1):
        s.put(pk.planter(mat), sx * 12.0, S5_Z + 11.5, 0, y=PATH_Y)
        s.put(nb.lamp_post(mat), sx * 15.0, fy - 12.0, 0, y=PATH_Y)
    # the playground
    hx, hz = PLAY[0], PLAY[1]
    s.put(nb.tyre_swing_oak(mat), -74.0, 200.0, 20)
    _spot(s, "tyre", *turned(-74.0, 200.0, 20, -4.4, -2.2))
    s.put(nb.slide(mat), -28.0, 200.0, 180)
    _spot(s, "slide", *turned(-28.0, 200.0, 180, 0, 2.0), y=4.0)
    s.put(nb.swings(mat), -50.0, 204.0, 0)
    _spot(s, "swings", -53.0, 200.5)
    s.put(nb.sandbox(mat), -34.0, 184.0, 10)
    _spot(s, "sandbox", *turned(-34.0, 184.0, 10, 1.2, 1.2), y=0.55)
    s.put(pk.roundabout(mat), -56.0, 186.0, 0)
    _spot(s, "roundabout", -56.0, 186.0, y=pk.ROUNDABOUT_TOP)
    s.put(pk.seesaw(mat), -76.0, 182.0, 0)
    _spot(s, "seesaw", -76.0, 179.4)
    s.put(pk.spring_rider(mat), -44.0, 193.0, 30)
    s.put(pk.spring_rider(mat, "sign_teal"), -64.0, 194.0, -40)
    for x in (-66.0, -40.0):
        s.put(bench(mat), x, S5_Z + 9.0, 180)
    _spot(s, "play_bench", -40.0, S5_Z + 11.4)
    # the two houses across the parade: a house and the bungalow with the gutter
    zc = S5_Z + 8 + FRONT
    _row(s, g, mat, [(44, "A", "porch", ("bed",)), (70, "D", "flowerbed", ("bed", "mail"))], zc, 0,
         FAR_ROW[0], FAR_ROW[1])
    _spot(s, "trap_gutter", *turned(70, zc, 0, *GUTTER_SPOT), y=GUTTER_Z, turn=0)
    z0 = zc - HD / 2 + 1.0                                    # just behind the row's own side fence
    s.put(side_fence(mat, IN_Z - 0.5 - z0, gate=False), FAR_ROW[0] + 0.25, (z0 + IN_Z - 0.5) / 2, 90)
    s.put(low_hedge(mat, 6.3), FAR_ROW[0] + 0.7, S5_Z + 8 + 0.8 + 3.15, 90)
    tb = Builder()
    for (x, z, h, k) in ((22.0, 186.0, 12, 1), (40.0, 204.0, 14, 0), (64.0, 206.0, 13, 2), (82.0, 200.0, 12, 1),
                         (-81.0, 156.5, 10, 0), (-10.0, 156.5, 9, 2), (12.0, 156.5, 9, 1), (81.0, 156.5, 10, 0)):
        tree_round(tb, -x, z, 0, h=h, r=3.0 + 0.4 * k, leaf=("leaf_green", "leaf_dark", "mint")[k])
    s.put([tb.finalize(N + "FarTrees", mat)], 0, 0, 0)
    _spot(s, "lawn", 22.0, 180.0)
    _spot(s, "far", -82.0, 179.0, y=0.05)
    _spot(s, "far", -6.0, 176.0, y=PATH_Y)


def _lamps_and_trees(s, mat):
    for (x, z) in ((-6.5, -206.0), (6.5, -188.5), (-46.0, -186.5), (40.0, -186.5), (-72.0, -174.0),
                   (G1_X - 6.5, -150.0), (G1_X + 6.5, -128.0),
                   (-50.0, -107.5), (20.0, -107.5), (72.0, -107.5),
                   (-60.0, S3_Z - 6.5), (66.0, S3_Z + 6.5), (G2_X - 6.5, 40.0), (G2_X + 6.5, 60.0),
                   (-70.0, S4_Z + 6.5), (10.0, S4_Z + 6.5), (66.0, S4_Z - 6.5),
                   (-36.0, S5_Z - 6.5), (40.0, S5_Z - 6.5)):
        s.put(nb.lamp_post(mat), x, z, 0, y=PAVE_Y)
    tb = Builder()
    for (x, z, h, k) in ((-80.0, -206.0, 11, 0), (-28.0, -209.0, 10, 1), (28.0, -209.0, 10, 2), (78.0, -205.0, 11, 1),
                         (-80.0, -64.0, 9, 2), (80.0, -64.0, 10, 0), (-80.0, 96.0, 11, 1),
                         (-40.0, 94.0, 9, 0), (36.0, 132.0, 10, 2), (80.0, 128.0, 11, 0), (-6.0, 142.0, 9, 1)):
        tree_round(tb, -x, z, 0, h=h, r=3.0 + 0.4 * k, leaf=("leaf_green", "leaf_dark", "mint")[k])
    s.put([tb.finalize(N + "Trees", mat)], 0, 0, 0)


def _barriers(s, mat):
    """The house blocks' invisible walls, 30 high, from the house fronts back (the front gardens stay open), and the
    far houses' from their fronts to the far wall."""
    bar = Builder()
    rects = [(R1W[0], R1W[1], ROW1[0] + 7.8, ROW1[1] - 7.8), (R1E[0], R1E[1], ROW1[0] + 7.8, ROW1[1] - 7.8),
             (R2W[0], R2W[1], ROW2[0] + 7.8, ROW2[1] - 7.8), (R2E[0], R2E[1], ROW2[0] + 7.8, ROW2[1] - 7.8),
             (FAR_ROW[0], FAR_ROW[1], S5_Z + 8 + 7.8, IN_Z)]
    for (x0, x1, z0, z1) in rects:
        span(bar, x0, x1, z0, z1, 0, BARRIER_H, "offwhite")
    s.put([bar.finalize(N + "Blocks_Barrier", mat)], 0, 0, 0)


def build_set(mat):
    s = Set(NAME)
    g = _ground()
    _walls(s, mat)
    _blocks(s, g, mat)
    _near(s, g, mat)
    _works(s, mat)
    _gardens(s, g, mat)
    _far(s, g, mat)
    _lamps_and_trees(s, mat)
    _barriers(s, mat)
    return s.finish(g, mat), s


def build_neighbourhood_set(mat):
    objs, _ = build_set(mat)
    return objs


ASSETS = {
    NAME: (build_neighbourhood_set, 150000),
}
