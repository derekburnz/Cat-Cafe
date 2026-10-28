"""The Woods set for town layout v3.2 (town-layout-v3.md section 8, F81): 240 x 240 of forest behind the Woods gate.

  CatCafe_Woods_SetV32   the whole area dressed, in area space (areakit): place it at the area's v3.2 centre on its
                         floor, turned so -Z faces the gate (a quarter turn, like the v3.1 set). The gate is at z -120.
                         A new name, so the live game keeps CatCafe_Woods_Set (v3.1, 120 x 120) until Gameplay moves
                         the Woods to its v3.2 Config and switches the set name in the same change.

The way in (8b) winds about 1.6 times the straight walk. The dirt trail leaves the gate past the campsite (east) and
the berry meadow (west) to the only gap in the tree line (east end), back west past the mushroom ring to the stream's
only crossing, a log bridge (west), then east past the berry patch to the only gap in the rock ridge (east end), and
on west to the Great Oak's clearing at the far end, with the tree house and the lookout tower beside it. The stream
runs the whole width, sunken between rock edges and grass banks, from a waterfall at the east wall (8c), with an
invisible `_Barrier` along each rock edge that only the bridge passes.

The set brings its own walls just inside WorldBuilder's (whose inner faces stand at +-119.5): the far and side walls
are runs of mossy cliff, thicket, log palisade and dry stone under a thicket, 10 to 15 high, between old trees; the
town side is a split rail fence with bushes, so the town shows through (7d). A `_Barrier` 30 high stands on every
blocker and in the wall band all round but the gate: a default jump clears 7.2.

Points (manifest points_roblox): [x, y, z, zone], zone "near" (the gate half, z < 0) or "deep". The trap spots
(trap_hollow_log, trap_bramble_bush, built into the set as in v3.1) add a fifth number, the piece's turn in degrees
(a hollow log's open end faces the piece's local +X). nook_great_oak (inside the oak's top) and
trap_treehouse_branch are kept as in v3.1.
"""

import math

from mathutils import Matrix

import woods as wd
from areakit import PI, Set, rx, ry, turned
from common import Builder

N = "CatCafe_Woods_"
SET = N + "SetV32"
HALF = 120.0                         # WorldBuilder's walls at +-120
WALL_D = 3.0                         # the set's walls: inner face here, back against WorldBuilder's
IN = HALF - 0.5 - WALL_D             # 116.5
GATE_HALF = 19.0                     # the Woods gate model is 36.2 wide, centred on the trail
TRAIL_W = 7.0
DIRT = "kibble"
BARRIER_H = 30.0
TREE_LINE_Z, GAP_A = -66.0, (36.0, 52.0)     # first blocker, gap at the east end
RIDGE_Z, GAP_C = 46.0, (28.0, 44.0)          # rock ridge, gap at the east end
STREAM_Z, BRIDGE_X = -6.0, -38.0             # the stream's centre line at the bridge, and the bridge
WATER_HW, EDGE_W, BANK_W, EDGE_H = 4.0, 1.2, 3.0, 1.3   # half the water's width, rock edge, grass bank, edge height
DECK_TOP, DECK_HL, RAMP_L = 2.0, 9.0, 5.0    # the bridge: deck top, half its length, each ramp's run
OAK = (-38.0, 88.0)                          # the Great Oak, in its clearing
CLEARING_R = 20.0
CAMP = (80.0, -100.0)

TRAIL_IN = [(0, -120), (0, -110), (7, -100), (22, -90), (37, -81), (44, -73), (44, -66), (42, -58), (30, -50),
            (12, -43), (-8, -37), (-24, -31), (-34, -26), (BRIDGE_X, -20.5)]
TRAIL_ON = [(BRIDGE_X, 8.5), (-36, 16), (-24, 23), (-4, 28), (16, 33), (30, 39), (36, 46), (35, 54), (24, 62),
            (6, 70), (-10, 77), (-22, 82)]


def bl(x, z, h=0.0):
    """Area (Roblox x, z) to Builder coordinates (Blender x is Roblox -x)."""
    return (-x, z, h)


def face(x, z, tx, tz):
    """rot_y that turns a piece at (x, z) to face (tx, tz)."""
    return math.degrees(math.atan2(-(tx - x), -(tz - z)))


def stream_z(x):
    """The stream's centre line: level with the bridge at BRIDGE_X, wandering up to 8 south of it."""
    return STREAM_Z - 4.0 * (1 - math.cos(2 * PI * (x - BRIDGE_X) / 100.0))


def trail_length():
    pts = TRAIL_IN + [(BRIDGE_X, -20.5 + 0.01)] + TRAIL_ON
    return sum(math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(pts, pts[1:])) + CLEARING_R - 2


# ------------------------------------------------------------------ ground ---
def _strip(g, p0, p1, w, swatch, top):
    (ax, ay, _), (bx, by, _) = bl(*p0), bl(*p1)
    L = math.hypot(bx - ax, by - ay)
    g.box_base(((ax + bx) / 2, (ay + by) / 2, 0), (L, w, top), swatch, bevel=False,
               rot=(math.atan2(by - ay, bx - ax), "Z"))


def _path(g, pts, w, swatch=DIRT, top=0.06):
    """Straight strips, every other one 0.006 taller so overlaps never share a top, and a disc under each bend."""
    for i, (p0, p1) in enumerate(zip(pts, pts[1:])):
        _strip(g, p0, p1, w, swatch, top + 0.006 * (i % 2))
    for p in pts[1:-1]:
        g.cyl_base(bl(*p), w / 2, top - 0.01, swatch, segments=16, bevel=False)


def _ground():
    g = Builder()
    _path(g, TRAIL_IN, TRAIL_W)
    _path(g, TRAIL_ON, TRAIL_W)
    g.cyl_base(bl(*OAK), CLEARING_R, 0.08, "fur_sand", segments=28, bevel=False)                 # the oak's clearing
    g.cyl_base(bl(*CAMP), 12.0, 0.075, "fur_sand", segments=24, bevel=False)                     # the campsite
    _strip(g, (44, -84), (CAMP[0] - 11.5, CAMP[1] + 2), 4.0, DIRT, 0.058)                       # the camp's track
    g.cyl_base(bl(0, -56), 7.0, 0.07, "leaf_dark", segments=20, bevel=False)                     # mossy ring floor
    return g


# ---------------------------------------------------------------- stream -----
def _seg_frame(x0, x1):
    """Centre (Builder), angle (Blender, about Z) and length of the stream segment from x0 to x1 (Roblox)."""
    (ax, ay, _), (bx, by, _) = bl(x0, stream_z(x0)), bl(x1, stream_z(x1))
    return ((ax + bx) / 2, (ay + by) / 2), math.atan2(by - ay, bx - ax), math.hypot(bx - ax, by - ay)


def _at(c, a, d):
    """The point d across (Builder +Y side of the flow) from centre c of a segment at angle a."""
    return (c[0] - d * math.sin(a), c[1] + d * math.cos(a))


def stream(mat):
    """The stream across the whole width, from the waterfall at the east wall (Roblox +x) to the west wall: a dark
    bed under water 0.36 deep in look, a rock edge 1.3 high either side and a grass bank down to the floor. Every
    other segment is 0.006 taller so the overlaps never share a face. Stream_Barrier: an invisible wall on each rock
    edge, open only at the bridge, plus the walls along the bridge's sides."""
    b, water, bar = Builder(), Builder(), Builder()
    xs = [-IN + 0.5 + k * (2 * IN - 1.0) / 58 for k in range(59)]          # its ends stop at the walls' faces
    for i, (x0, x1) in enumerate(zip(xs, xs[1:])):
        c, a, L = _seg_frame(x0, x1)
        e = 0.006 * (i % 2)
        rot = (a, "Z")
        b.box_base((*c, 0), (L * 1.06, 2 * WATER_HW + 0.4, 0.03 + e), "choco", bevel=False, rot=rot)
        water.box_base((*c, 0.03 + e), (L * 1.06, 2 * WATER_HW + 0.2, 0.33), "fish_blue", bevel=False, rot=rot)
        for s in (-1, 1):
            d = s * (WATER_HW + EDGE_W / 2)
            sw = ("concrete", "fur_grey", "concrete", "fur_smoke_light")[(i + (s > 0)) % 4]
            b.box_base((*_at(c, a, d), 0), (L * 1.12, EDGE_W, EDGE_H + e), sw, bevel=False, rot=rot)
            d = s * (WATER_HW + EDGE_W + BANK_W / 2)
            turn = Matrix.Rotation(a, 3, "Z") @ (Matrix.Rotation(PI, 3, "Z") if s > 0 else Matrix.Identity(3))
            b.wedge((*_at(c, a, d), EDGE_H / 2), (L * 1.12, BANK_W, EDGE_H - 0.01 * (i % 2)), "leaf_dark", bevel=False,
                    rot=turn)
    # the barriers: chunks about 12 long along each rock edge, none across the bridge
    gaps = (BRIDGE_X - 3.4, BRIDGE_X + 3.4)
    for (r0, r1) in ((-IN, gaps[0]), (gaps[1], IN)):
        n = max(1, round((r1 - r0) / 12.0))
        for k in range(n):
            x0, x1 = r0 + (r1 - r0) * k / n, r0 + (r1 - r0) * (k + 1) / n
            c, a, L = _seg_frame(x0, x1)
            for s in (-1, 1):
                bar.box_base((*_at(c, a, s * (WATER_HW + EDGE_W / 2)), 0), (L + 0.3, EDGE_W, BARRIER_H), "offwhite",
                             bevel=False, rot=(a, "Z"))
    for s in (-1, 1):                                                            # along the bridge's sides
        x, y, _ = bl(BRIDGE_X + s * 3.4, STREAM_Z)
        bar.box_base((x, y, 0), (0.6, 2 * (WATER_HW + EDGE_W) + 0.6, BARRIER_H), "offwhite", bevel=False)
    return [b.finalize(N + "Stream", mat), water.finalize(N + "Stream_Water", mat), bar.finalize(N + "Stream_Barrier", mat)]


def log_bridge(mat):
    """The stream's only crossing: a plank deck 6 wide at 2.0 on two big logs, a plank ramp at each end (22 degrees),
    and log railings 3.4 high along the deck. Runs along local Y (Roblox Z)."""
    b = Builder()
    L = 2 * DECK_HL
    for x in (-2.0, 2.0):                                                           # the logs under it
        b.cyl((x, 0, DECK_TOP - 1.0), 0.75, L + 1.0, "fur_brown", segments=10, rot=rx(90))
        for y in (-(L + 1.0) / 2 - 0.02, (L + 1.0) / 2 + 0.02):
            b.cyl((x, y, DECK_TOP - 1.0), 0.62, 0.06, "treat_tan", segments=10, rot=rx(90), bevel=False)
    b.box_base((0, 0, DECK_TOP - 0.3), (6.0, L, 0.3), "caramel_wood", bevel=False)            # the deck
    for k in range(1, 15):                                                           # plank lines
        y = -DECK_HL + k * L / 15
        b.box_base((0, y, DECK_TOP), (5.9, 0.08, 0.02), "dark_wood", bevel=False)
    slope = math.atan2(DECK_TOP, RAMP_L)
    rl = math.hypot(DECK_TOP, RAMP_L)
    for s in (-1, 1):                                                                # the ramps
        ym, zm = s * (DECK_HL + RAMP_L / 2), DECK_TOP / 2
        nz, ny = math.cos(slope), s * math.sin(slope)                               # the ramp's up direction
        b.box((0, ym - ny * 0.15, zm - nz * 0.15), (6.0, rl + 0.25, 0.3), "caramel_wood", bevel=False,
              rot=rx(-s * math.degrees(slope)))
        for k in range(1, 4):                                                        # cleats
            t = k / 4
            b.box((0, s * (DECK_HL + RAMP_L * t) + ny * 0.06, DECK_TOP * (1 - t) + nz * 0.06), (5.6, 0.25, 0.12),
                  "dark_wood", bevel=False, rot=rx(-s * math.degrees(slope)))
        for x in (-2.9, 2.9):                                                        # a short post at each foot
            b.cyl_base((x, s * (DECK_HL + RAMP_L - 0.4), 0), 0.25, 1.6, "fur_brown", segments=8)
    for x in (-2.85, 2.85):                                                          # railings 3.4 high
        for k in range(5):
            y = -DECK_HL + 0.35 + k * (L - 0.7) / 4
            b.cyl_base((x, y, DECK_TOP), 0.24, 3.4, "fur_brown", segments=8)
        for z in (1.7, 3.2):
            b.cyl((x, 0, DECK_TOP + z), 0.18, L - 0.3, "caramel_wood", segments=8, rot=rx(90))
    return [b.finalize(N + "LogBridge", mat)]


# ---------------------------------------------------------- tree line, ridge ---
def _pine_into(b, x, y, h, base=0.0):
    """A pine (as woods.pine) built into another piece, so a tree line or wall and its pines are one piece."""
    b.cyl_base((x, y, base), 0.7, h * 0.35, "fur_brown", segments=8, radius2=0.5)
    for i, (z, r) in enumerate(((0.22, 4.2), (0.42, 3.4), (0.6, 2.6), (0.76, 1.7))):
        b.cyl_base((x, y, base + h * z), r, h * 0.3 if i < 3 else h * 0.26, "leaf_dark", segments=8, radius2=0.25,
                   bevel=False)


def _tree_line(s, mat, z, gap):
    """Dense thicket 9 to 9.3 high across the area with pines standing in it, bushes spilling out of both faces, and
    one gap (x0, x1). A barrier 30 high on its footprint, so the gap is the only way through."""
    b, bar = Builder(), Builder()
    for (a0, a1) in ((-IN, gap[0]), (gap[1], IN)):
        n = max(1, round((a1 - a0) / 7.0))
        step = (a1 - a0) / n
        for i in range(n):
            c, h = a0 + (i + 0.5) * step, 9.0 + 0.3 * (i % 2)
            x, y, _ = bl(c, z + 0.5 * math.sin(i * 1.7))
            b.box_base((x, y, 0), (step + 0.04 * (i % 2), 4.0 + 0.04 * (i % 2), h), "leaf_dark", bevel=False)
            b.ico((x, y, h), 1.9, ("leaf_dark", "leaf_green")[i % 2], subdivisions=1, scale=(step / 3.0, 1.2, 0.6))
            for side in (-1, 1):                                                 # bushes on both faces
                sw = ("leaf_green", "fur_moss", "leaf_green", "leaf_dark")[(i + (side > 0)) % 4]
                b.ico((x + 0.25 * step * side * (-1) ** i, y + side * 1.9, 1.5), 1.6, sw, subdivisions=1,
                      scale=(1.4, 0.65, 1.0))
                if (i + (side > 0)) % 2 == 0:
                    b.ico((x - 0.2 * step * side, y + side * 1.9, 5.2), 1.8, ("leaf_dark", "leaf_green")[i % 2],
                          subdivisions=1, scale=(1.3, 0.55, 1.2))
            if i % 2 == 0 and (abs(c - gap[0]) > 6 and abs(c - gap[1]) > 6):
                _pine_into(b, x, y + 0.5 * (-1) ** (i // 2), 18 + 3 * ((i // 2) % 3))
        x, y, _ = bl((a0 + a1) / 2, z)
        bar.box_base((x, y, 0), (a1 - a0, 5.2, BARRIER_H), "offwhite", bevel=False)
    s.put([b.finalize(N + "TreeLine", mat), bar.finalize(N + "TreeLine_Barrier", mat)], 0, 0, 0)


def _ridge(s, mat, z, gap):
    """A mossy rock ridge 6 to 8 high across the area, one gap (x0, x1): two staggered rows of boulders with
    smaller ones on top, a low core between them, and a barrier 30 high on it."""
    b, bar = Builder(), Builder()
    rocks = ("concrete", "fur_grey", "concrete", "fur_smoke_light", "concrete_dark")
    for (a0, a1) in ((-IN, gap[0]), (gap[1], IN)):
        n = max(1, round((a1 - a0) / 5.5))
        step = (a1 - a0) / n
        x, y, _ = bl((a0 + a1) / 2, z)
        b.box_base((x, y, 0), (a1 - a0, 2.4, 3.5), "concrete_dark", bevel=False)
        for i in range(n):
            for row in (-1, 1):
                c = a0 + (i + 0.5 + 0.25 * row) * step
                c = min(max(c, a0 + 1.5), a1 - 1.5)
                x, y, _ = bl(c, z + row * 1.0 + 0.4 * math.sin(i * 2.3))
                r = 3.8 + 0.4 * ((i * 3 + row) % 3)
                b.ico((x, y, r * 0.6), r, rocks[(i * 2 + (row > 0)) % 5], subdivisions=1,
                      scale=(step / (1.35 * r), 0.75, 1.0))
            c = a0 + (i + 0.5) * step
            x, y, _ = bl(c, z)
            if i % 2 == 0:
                b.ico((x, y, 6.2), 2.4, rocks[(i + 1) % 5], subdivisions=1, scale=(1.2, 1.0, 0.8))
                b.ico((x + 0.4, y - 0.3, 7.6), 1.5, "fur_moss", subdivisions=1, scale=(1.3, 1.1, 0.4))
            else:
                b.ico((x, y - 0.6, 6.0), 2.0, "fur_moss", subdivisions=1, scale=(1.5, 1.3, 0.45))
            if i % 3 == 1 and abs(c - gap[0]) > 8 and abs(c - gap[1]) > 8:
                _pine_into(b, x, y + 4.0, 17 + 3 * (i % 2))
        x, y, _ = bl((a0 + a1) / 2, z)
        bar.box_base((x, y, 0), (a1 - a0, 5.6, BARRIER_H), "offwhite", bevel=False)
    s.put([b.finalize(N + "Ridge", mat), bar.finalize(N + "Ridge_Barrier", mat)], 0, 0, 0)


# ------------------------------------------------------------------- walls ---
def _seg_cliff(b, L, k):
    H = 12.0 + 1.5 * (k % 2)
    b.box_base((0, 1.9, 0), (L, 2.2, H), "concrete_dark", bevel=False)
    n = max(2, round(L / 4.2))
    for i in range(n):
        x = -L / 2 + (i + 0.5) * L / n
        for j, (z, r) in enumerate(((2.4, 2.6), (6.4, 2.4), (H - 2.0, 2.2))):
            sw = ("concrete", "fur_grey", "concrete_dark", "fur_smoke_light")[(i + j + k) % 4]
            f = 0.8 + 0.35 * ((i * 7 + j * 3 + k) % 4) / 3                     # sizes vary, no egg crate
            b.ico((x + 0.9 * ((i + 2 * j) % 3 - 1), 1.6 - 0.25 * ((i + j) % 2), z + 0.5 * ((i * j + k) % 3 - 1)),
                  r * f, sw, subdivisions=1, scale=(L / n / (2 * r) * 1.35, 0.66, 0.9))
        b.ico((x, 1.6, H + 0.2), 2.0, ("leaf_green", "fur_moss")[(i + k) % 2], subdivisions=1,
              scale=(L / n / 4.0 * 1.2, 0.95, 0.4))
    b.ico((-L / 4, 0.3, 0.6), 1.2, "leaf_green", subdivisions=1, scale=(1.4, 0.7, 0.6))       # ferny bits at the foot
    b.ico((L / 3, 0.3, 0.6), 1.1, "leaf_dark", subdivisions=1, scale=(1.4, 0.7, 0.6))


def _seg_thicket(b, L, k):
    H = 10.4 + 0.8 * (k % 2)
    b.box_base((0, WALL_D / 2, 0), (L, WALL_D, H), "leaf_dark")
    n = max(2, round(L / 3.5))
    for i in range(n):
        x = -L / 2 + (i + 0.5) * L / n
        b.ico((x, WALL_D / 2, H + 0.1 * (i % 2)), 1.9, ("leaf_dark", "leaf_green")[(i + k) % 2], subdivisions=1,
              scale=(L / n / 3.2, 0.9, 0.6))
        if i % 3 == 1:
            b.ico((x, 0.0, H * 0.55), 1.8, "leaf_green", subdivisions=1, scale=(1.3, 0.5, 1.3))
        if i % 2 == 0:
            b.ico((x, -0.2, 1.3), 1.5, ("leaf_green", "leaf_dark")[(k + 1) % 2], subdivisions=1, scale=(1.3, 0.55, 0.9))


def _seg_palisade(b, L, k):
    b.box_base((0, 2.3, 0), (L, 1.4, 9.0), "fur_brown", bevel=False)                          # backing
    n = max(2, round(L / 1.15))
    for i in range(n):
        x = -L / 2 + (i + 0.5) * L / n
        h = 9.8 + 0.45 * ((i * 5) % 3)
        b.cyl_base((x, 1.0, 0), 0.58, h, ("fur_brown", "fur_hazel")[i % 2], segments=8)
        b.cyl_base((x, 1.0, h), 0.58, 1.0, "treat_tan", segments=8, radius2=0.08)
    for z in (2.6, 7.6):                                                                         # binding rails
        b.box((0, 0.3, z), (L - 0.2, 0.35, 0.4), "dark_wood", bevel=False)
    for i in range(3):
        b.ico((-L / 2 + L * (i + 0.5) / 3, 0.2, 0.5), 1.0, ("leaf_green", "fur_moss")[i % 2], subdivisions=1,
              scale=(1.6, 0.7, 0.6))


def _seg_drystone(b, L, k):
    b.box_base((0, 0.9, 0), (L, 1.8, 4.6), "concrete")                                          # the wall
    n = max(2, round(L / 1.6))
    for i in range(n):                                                                           # cap stones
        x = -L / 2 + (i + 0.5) * L / n
        b.box_base((x, 0.9, 4.6), (L / n - 0.08, 2.0, 0.45 + 0.006 * (i % 2)),
                   ("concrete_dark", "fur_grey")[i % 2], bevel=False)
    for z in (1.2, 2.6):                                                                         # coursing
        b.box((0, -0.03, z), (L, 0.06, 0.1), "concrete_dark", bevel=False)
    H = 11.2 + 0.6 * (k % 2)
    b.box_base((0, 2.4, 0), (L, 1.2, H), "leaf_dark")                                             # thicket behind
    m = max(2, round(L / 3.5))
    for i in range(m):
        x = -L / 2 + (i + 0.5) * L / m
        b.ico((x, 2.2, H), 1.7, ("leaf_dark", "leaf_green")[i % 2], subdivisions=1, scale=(L / m / 3.0, 0.9, 0.6))
        b.ico((x, 1.6, 5.4), 1.3, "leaf_green", subdivisions=1, scale=(L / m / 2.4, 0.5, 0.7))  # spilling over


SEGMENTS = {"cliff": _seg_cliff, "thicket": _seg_thicket, "palisade": _seg_palisade, "drystone": _seg_drystone}


def wall_segment(mat, kind, L, k=0):
    """One wall run L long along local x, its face at y 0 (facing -Y, into the area) and its back at WALL_D."""
    b = Builder()
    SEGMENTS[kind](b, L, k)
    return [b.finalize(N + "Wall" + kind.capitalize(), mat)]


def old_tree(mat, h=16.0):
    """An old tree standing in the wall line between two runs, its crown above them."""
    b = Builder()
    b.cyl_base((0, WALL_D / 2, 0), 1.5, h, "fur_brown", segments=10, radius2=1.1)
    for d in (200, 250, 290, 340):                                                     # roots spreading forward
        a = math.radians(d)
        b.ico((1.5 * math.cos(a), WALL_D / 2 + 1.5 * math.sin(a), 0.5), 0.9, "fur_brown", subdivisions=1,
              scale=(1.4, 0.8, 0.7), rot=(a, "Z"))
    for (x, y, z, r, sw) in ((0, -1.4, h + 1.5, 4.8, "leaf_dark"), (-2.6, -0.6, h - 0.6, 3.4, "leaf_green"),
                             (2.8, -0.4, h - 0.2, 3.2, "leaf_dark")):           # leaning in, clear of the town
        b.ico((x, y, z), r, sw, subdivisions=1, scale=(1.0, 0.9, 0.85))
    return [b.finalize(N + "OldTree", mat)]


def _run(s, mat, kinds, n, length, place, seed):
    """n segments filling `length` with old trees 3.2 apart between; place(t) -> (x, z, rot) at distance t along."""
    L = (length - (n - 1) * 3.2) / n
    for i in range(n):
        t = i * (L + 3.2) + L / 2
        s.put(wall_segment(mat, kinds[i % len(kinds)], L, i + seed), *place(t))
        if i < n - 1:
            s.put(old_tree(mat, 15.0 + 1.5 * ((i + seed) % 3)), *place(t + L / 2 + 1.6))


def rail_fence(mat, L):
    """The town side: a split rail fence 3.6 high with bushes behind, so the town shows through (7d)."""
    b = Builder()
    n = max(2, round(L / 4.0))
    for i in range(n + 1):
        x = -L / 2 + 0.3 + i * (L - 0.6) / n
        b.box_base((x, 1.2, 0), (0.4, 0.4, 3.6), "dark_wood")
    for z in (1.4, 2.9):
        b.box((0, 1.2, z), (L - 0.3, 0.25, 0.35), "caramel_wood", bevel=False)
    for i in range(n):
        if i % 3 == 1:
            continue
        x = -L / 2 + (i + 0.5) * L / n
        b.ico((x, 1.75, 1.2), 1.2, ("leaf_green", "leaf_dark")[i % 2], subdivisions=1, scale=(1.4, 0.55, 1.0))
    return [b.finalize(N + "RailFence", mat)]


def _walls(s, mat):
    far = ("cliff", "thicket", "palisade", "cliff", "drystone", "thicket", "cliff", "palisade")
    east = ("thicket", "drystone", "palisade", "cliff", "thicket", "cliff", "palisade", "drystone")   # the waterfall: cliff
    west = ("palisade", "cliff", "thicket", "drystone", "cliff", "palisade", "thicket", "cliff")
    _run(s, mat, far, 8, 2 * IN, lambda t: (-IN + t, IN, 0), 0)
    _run(s, mat, east, 8, 2 * IN, lambda t: (IN, -IN + t, 90), 1)
    _run(s, mat, west, 8, 2 * IN, lambda t: (-IN, IN - t, -90), 2)
    for sx in (-1, 1):
        s.put(old_tree(mat, 18.0), sx * (IN - 2.0), IN - 2.0, 45 * sx)                    # far corners
        s.put(wd.rock(mat), sx * (IN - 3.0), -IN + 3.0, 40 * sx)                        # town corners
        L = IN - GATE_HALF - 1.0
        s.put(rail_fence(mat, L), sx * (GATE_HALF + 1.0 + L / 2), -IN, 180)
        s.put(wd.lantern(mat), sx * (GATE_HALF + 0.6), -IN + 1.5, 90 * sx)              # either side of the gate
    bar = Builder()
    ox = IN + WALL_D
    bar.box_base((0, IN + WALL_D / 2, 0), (2 * ox, WALL_D, BARRIER_H), "offwhite", bevel=False)               # far
    for sx in (-1, 1):
        bar.box_base((sx * (IN + WALL_D / 2), 0, 0), (WALL_D, 2 * IN, BARRIER_H), "offwhite", bevel=False)    # sides
        bar.box_base((sx * (GATE_HALF + ox) / 2, -(IN + WALL_D / 2), 0), (ox - GATE_HALF, WALL_D, BARRIER_H),
                     "offwhite", bevel=False)                                                               # town side
    s.put([bar.finalize(N + "Walls_Barrier", mat)], 0, 0, 0)


# ------------------------------------------------------------------ pieces ---
def log_pile(mat):
    """Cut logs stacked three high against two stakes."""
    b = Builder()
    for row, (n, z) in enumerate(((4, 0.55), (3, 1.5), (2, 2.45))):
        for i in range(n):
            x = (i - (n - 1) / 2) * 1.1
            b.cyl((0, x, z), 0.55, 5.0, ("fur_brown", "fur_hazel")[(i + row) % 2], segments=8, rot=ry(90))
            for e in (-2.52, 2.52):
                b.cyl((e, x, z), 0.45, 0.04, "treat_tan", segments=8, rot=ry(90), bevel=False)
    for y in (-2.3, 2.3):
        b.box_base((0, y, 0), (0.25, 0.25, 3.2), "dark_wood", bevel=False)
    return [b.finalize(N + "LogPile", mat)]


# --------------------------------------------------------------------- set ---
def _spot(s, label, x, z, y=0.0, turn=None):
    p = [round(x, 2), round(y, 2), round(z, 2), "deep" if z > 0 else "near"]
    if turn is not None:
        p.append(turn)
    s.points.setdefault(label, []).append(p)


def _dist_seg(p, a, b):
    ax, az, bx, bz = a[0], a[1], b[0], b[1]
    dx, dz = bx - ax, bz - az
    t = max(0.0, min(1.0, ((p[0] - ax) * dx + (p[1] - az) * dz) / (dx * dx + dz * dz or 1)))
    return math.hypot(p[0] - ax - t * dx, p[1] - az - t * dz)


def _near_trail(x, z):
    d = 1e9
    for pts in (TRAIL_IN, TRAIL_ON, [(BRIDGE_X, -21), (BRIDGE_X, 9)]):
        for a, b in zip(pts, pts[1:]):
            d = min(d, _dist_seg((x, z), a, b))
    return d


def build_set(mat):
    s = Set(SET)
    keep = []                                  # (x, z, r): no filler tree within r

    def put(fn, x, z, rot=0.0, r=4.0, y=0.0):
        keep.append((x, z, r))
        return s.put(fn, x, z, rot, y)

    _walls(s, mat)
    _tree_line(s, mat, TREE_LINE_Z, GAP_A)
    _ridge(s, mat, RIDGE_Z, GAP_C)
    s.put(stream(mat), 0, 0, 0)
    put(log_bridge(mat), BRIDGE_X, STREAM_Z, 0, r=0)
    _spot(s, "bridge", BRIDGE_X - 5.5, -22.5)
    _spot(s, "bridge", BRIDGE_X + 5.5, 10.5)
    put(wd.waterfall(mat), 109.0, stream_z(109.0), 90, r=9)
    _spot(s, "waterfall", 104.0, stream_z(104.0) - 10.0)

    # the gate band: signpost and lanterns, the campsite east, the berry meadow west
    put(wd.signpost(mat), 6.5, -106, -20, r=3)
    for (x, z, rot) in ((-5.5, -112, 0), (17, -88, 180), (49, -76, 180)):
        put(wd.lantern(mat), x, z, rot, r=3)
    cx, cz = CAMP
    for (x, z, col) in ((cx - 8, cz - 7, "shirt_green"), (cx + 9, cz - 4, "fur_orange")):
        r = face(x, z, cx, cz)
        put(wd.tent(mat, col), x, z, r, r=6)
        _spot(s, "tent", *turned(x, z, r, 0, -4.8))
    put(wd.campfire(mat), cx, cz, 0, r=3)
    for (x, z) in ((cx - 6, cz + 5), (cx + 6, cz + 6)):
        put(wd.log_bench(mat), x, z, face(x, z, cx, cz), r=3.5)
        _spot(s, "log_bench", x, z, y=2.06)
    put(log_pile(mat), cx + 3, cz - 11, 15, r=4)
    _spot(s, "camp", cx + 0.5, cz + 11.5)
    meadow = ((-30, -96), (-48, -104), (-62, -90))
    for (x, z) in meadow:
        put(wd.berry(mat), x, z, 0, r=4)
        _spot(s, "berry_bush", x, z - 3.8)
    put(wd.leaves(mat), -16, -84, 30, r=3)
    _spot(s, "leaf_pile", -16, -84)
    for (x, z) in ((-82, -100), (-40, -80)):
        put(wd.stump(mat), x, z, 20, r=3)
        _spot(s, "stump", x, z, y=1.66)
    put(wd.rock(mat), -94, -82, 50, r=3.5)
    _spot(s, "rock", -94, -82, y=2.0)
    for (x, z) in ((-72, -76), (-14, -104), (24, -108)):
        put(wd.fern(mat), x, z, 0, r=2)
        if x < -20:                                                  # no spots right by the gate
            _spot(s, "fern", x, z)
    put(wd.fallen_log(mat), -92, -104, 25, r=5)
    _spot(s, "log", *turned(-92, -104, 25, 0, -2.6))
    put(wd.mushroom(mat), -56, -80, 0, r=2.5)

    # between the tree line and the stream: the mushroom ring, the first traps
    put(wd.mushroom_ring(mat), 0, -56, 0, r=6)
    _spot(s, "mushroom_ring", 0, -56, y=0.05)
    put(wd.mushroom_glow(mat), -52, -54, 0, r=3)
    for (x, z) in ((66, -38), (-70, -30)):
        put(wd.rock(mat), x, z, x % 90, r=3.5)
        _spot(s, "rock", x, z, y=2.0)
    for (x, z) in ((24, -30), (-22, -50), (90, -48)):
        put(wd.fern(mat), x, z, 30, r=2)
        _spot(s, "fern", x, z)
    put(wd.stump(mat), 86, -58, 60, r=3)
    _spot(s, "stump", 86, -58, y=1.66)
    put(wd.leaves(mat), -100, -42, 0, r=3)
    _spot(s, "leaf_pile", -100, -42)
    put(wd.berry(mat), 100, -76, 0, r=4)
    _spot(s, "berry_bush", 100, -79.8)
    put(wd.fallen_log(mat), 64, -56, 70, r=5)
    _spot(s, "log", *turned(64, -56, 70, 0, -2.6))
    for (x, z, rot) in ((-10, -25, 0), (-42, -34, 180)):
        put(wd.lantern(mat), x, z, rot, r=3)
    put(wd.hollow_log(mat), 78, -40, 20, r=5)
    _spot(s, "trap_hollow_log", 78, -40, turn=20)
    put(wd.bramble(mat), -84, -50, 0, r=4)
    _spot(s, "trap_bramble_bush", -84, -50, turn=0)

    # past the stream: the berry patch along the trail, glades, the deep traps
    for (x, z) in ((-14, 34), (6, 39), (22, 26), (-30, 32)):
        put(wd.berry(mat), x, z, 0, r=4)
        _spot(s, "berry_bush", x, z - 3.8)
    put(wd.mushroom_glow(mat), 50, 22, 0, r=3)
    _spot(s, "glow_mushrooms", 50, 18.5)
    put(log_pile(mat), -62, 18, -30, r=4)
    _spot(s, "log_pile", *turned(-62, 18, -30, 0, -3.9))
    for (x, z) in ((70, 34), (-96, 10)):
        put(wd.rock(mat), x, z, 20, r=3.5)
        _spot(s, "rock", x, z, y=2.0)
    for (x, z) in ((100, 6), (-50, 36), (8, 14)):
        put(wd.fern(mat), x, z, 50, r=2)
        _spot(s, "fern", x, z)
    put(wd.stump(mat), -104, 34, 0, r=3)
    _spot(s, "stump", -104, 34, y=1.66)
    put(wd.leaves(mat), 34, 14, 0, r=3)
    _spot(s, "leaf_pile", 34, 14)
    for (x, z) in ((-78, 6), (-6, 18)):
        _spot(s, "glade", x, z)
    for (x, z, rot) in ((-30, 12, 90), (24, 38, 90)):
        put(wd.lantern(mat), x, z, rot, r=3)
    put(wd.hollow_log(mat), 92, 26, -20, r=5)
    _spot(s, "trap_hollow_log", 92, 26, turn=-20)
    put(wd.bramble(mat), -86, 30, 0, r=4)
    _spot(s, "trap_bramble_bush", -86, 30, turn=0)

    # the far end: the Great Oak's clearing, the tree house and the lookout tower
    ox, oz = OAK
    rot = face(ox, oz, -22, 82)                                    # its doorway toward the trail's end
    put(wd.great_oak(mat), ox, oz, rot, r=11)
    for d in wd.OAK_NOOKS:
        a = math.radians(d)
        _spot(s, "oak_nook", *turned(ox, oz, rot, -6.8 * math.cos(a), 6.8 * math.sin(a)))
    for (bx, by, up) in wd.NOOK_SPOTS:
        _spot(s, "nook_great_oak", *turned(ox, oz, rot, -bx, by), y=wd.NOOK_Z + up)
    for (x, z) in ((-20, 100), (-56, 100), (-24, 72)):
        put(wd.log_bench(mat), x, z, face(x, z, ox, oz), r=3.5)
        _spot(s, "log_bench", x, z, y=2.06)
    put(wd.campfire(mat), -26, 92, 0, r=3)
    tx, tz = -86.0, 74.0
    trot = face(tx, tz, ox, oz)
    put(wd.treehouse(mat), tx, tz, trot, r=9)
    _spot(s, "treehouse", *turned(tx, tz, trot, -1.8, 1.8), y=wd.DECK + 0.3)
    _spot(s, "trap_treehouse_branch", *turned(tx, tz, trot, -4.9, 4.4), y=15.45)
    _spot(s, "treehouse_foot", *turned(tx, tz, trot, 3.0, -7.5))
    wx, wz = 2.0, 102.0
    put(wd.tower(mat), wx, wz, face(wx, wz, ox, oz), r=6)
    _spot(s, "tower", wx, wz)
    put(wd.signpost(mat), -12, 84, 60, r=3)
    for (x, z, rot) in ((-8, 66, 90), (-60, 76, -90)):
        put(wd.lantern(mat), x, z, rot, r=3)
    for (x, z) in ((-58, 64), (-78, 104)):
        _spot(s, "clearing", x, z)
    put(wd.mushroom(mat), -50, 70, 0, r=2.5)
    put(wd.mushroom_glow(mat), -98, 92, 0, r=3)
    _spot(s, "glow_mushrooms", -98, 88.5)

    # the far east dell, off the trail past the ridge
    for (x, z) in ((64, 80), (96, 66)):
        put(wd.rock(mat), x, z, 70, r=3.5)
        _spot(s, "rock", x, z, y=2.0)
    for (x, z) in ((80, 100), (52, 66), (100, 96)):
        put(wd.fern(mat), x, z, 10, r=2)
        if x < 100:
            _spot(s, "fern", x, z)
    put(wd.fallen_log(mat), 82, 84, -35, r=5)
    _spot(s, "log", *turned(82, 84, -35, 0, -2.6))
    put(wd.stump(mat), 44, 100, 0, r=3)
    _spot(s, "stump", 44, 100, y=1.66)
    put(wd.berry(mat), 104, 80, 0, r=4)
    _spot(s, "berry_bush", 104, 76.2)
    put(wd.leaves(mat), 28, 84, 0, r=3)
    _spot(s, "leaf_pile", 28, 84)
    put(wd.mushroom_glow(mat), 66, 104, 0, r=3)
    _spot(s, "glow_mushrooms", 66, 100.5)
    _spot(s, "dell", 84, 54)

    # filler: pines and a few round oaks, clear of the trail, the stream, the blockers, the pieces and the spots
    spots = [(p[0], p[2]) for lst in s.points.values() for p in lst]
    k, trees = 0, []
    for gx in range(-108, 109, 13):
        for gz in range(-108, 109, 13):
            k += 1
            x = gx + 4.5 * math.sin(k * 2.71)
            z = gz + 4.5 * math.cos(k * 1.93)
            if z < -IN + 14 and abs(x) < GATE_HALF + 12:                    # the gate stays open
                continue
            if _near_trail(x, z) < 9.0 or abs(z - stream_z(x)) < 13.0:
                continue
            if abs(z - TREE_LINE_Z) < 9.0 or abs(z - RIDGE_Z) < 11.0:
                continue
            if any(math.hypot(x - px, z - pz) < 11.0 for (px, pz) in trees):    # canopies apart
                continue
            if any(math.hypot(x - px, z - pz) < pr + 5.0 for (px, pz, pr) in keep):
                continue
            if any(math.hypot(x - px, z - pz) < 6.0 for (px, pz) in spots):
                continue
            if math.hypot(x - CAMP[0], z - CAMP[1]) < 15 or math.hypot(x - OAK[0], z - OAK[1]) < CLEARING_R + 4:
                continue
            trees.append((x, z))
            if k % 5 == 0:
                s.put(wd.oak(mat), x, z, (k * 37) % 360)
            else:
                s.put(wd.pine(mat, h=15.0 + 3.0 * (k % 3)), x, z, 0)
    return s.finish(_ground(), mat), s


def build_woods_set(mat):
    objs, _ = build_set(mat)
    return objs


ASSETS = {
    SET: (build_woods_set, 120000),
}
