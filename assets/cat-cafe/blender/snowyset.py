"""The Snowy Mountain (Tier 8, Summit Cafe; the next-areas plan Derek OK'd on 2026-11-13, section 1, #3997): a long
rectangle, 150 x 560 for the wild part like the Desert, with the camp (the Cocoa Lodge, a later piece) 30 more across
its -Z end, outside it.

  CatCafe_Snowy_Set   the wild part dressed, in area space (areakit): place it at the area's centre on its floor,
                      camp side -Z, like every set. Walls at x +-75 and z +-280 (a SnowyWidth 150 and SnowyDepth 560
                      in Config.World, Gameplay-Engineer's); the way in is the 24 stud opening at x 0 on z -280.

No grass anywhere: the floor is snow, the paths packed snow, the lake ice and the edges snowbanks, snowy pines and
grey rock cliffs 9 to 16 high. No blocker runs wall to wall, so the way on is a short walk round an end. Nothing
invisible stands inside the area (#2897's rule): every blocker stops a player where it is drawn and a nimble player
may climb one; the only _Barrier is the 30 high ring in the border's wall band, which starts BAR_IN behind the
border's drawn faces. The zones, camp first:

  z -276 to -130   the Pine Slopes: two snowbank ridges 9.2 high with snowy pines along their crests cross the
                   width as islands (z -222: x -60 to -12 and 14 to 58; z -165: the west wall to -30 and -6 to 40),
                   two paths wind through them (the main one up the middle, a second round the east), low snow
                   humps on the way and a sled run beside it (scenery, no physics)
  z -130 to -8     the Frozen Lake: a wide lake of ice (48 by 38 round (0, -68)) with skate scratches, three
                   ice-fishing huts, a snow fort and an igloo on its shores; the open sightlines
  z -8 to 132      the Ice Cave: blocks of blue ice 11.5 to 16 high either side of a passage 16 wide, with lanes
                   between them, two ice arches over the passage hung with icicles, frozen bubbles in the walls and a
                   side passage 17.5 wide along the west wall
  z 132 to 200     the Summit Path: a pine ridge 9.2 high as two islands at z 164 (x -62 to -14 and 16 to 60),
                   trail signs, snowmen and boulders
  z 200 to 276     Summit Peak: a stepped rocky summit (four snow-capped tiers of 2.8 to 11.2, a stair of 1.4
                   steps up its camp face) with the summit flag, a cairn and a small observatory dome on top; the
                   deep zone where the Mythical stays

The way, camp to summit: up the middle between the first ridge's islands, west through the second ridge's gap,
across the lake between the huts, up the ice passage under both arches, through the pine ridge's middle and up the
summit's stair. The second path leaves the first at z -250, runs up the east side through both ridges' east gaps and
meets it again at the lake's camp shore.

Points (manifest points_roblox): [x, y, z, zone], zone "near" (z < 0) or "deep". The five rescue spots are built in
(the plan's 1b), each with its piece's turn as a fifth number:
  trap_snowdrift x2         a ring of snow round the spot, so a cat there is in it up to its chest (the spot is the
                            cat's, on the floor at the ring's middle)
  trap_snowman              a snowman with a heap of snow at its feet, the cat in the heap with its tail out (the
                            snowman stands 2.4 behind the spot, toward the piece's local +Z)
  trap_sled                 a sled tipped over on its side and propped on a drift, over the spot, open toward the
                            piece's local -Z
  trap_snow_log             a hollow log with snow on top, its mouth toward the piece's local +X (as the Woods' log)
Four of the five are deep and none is within 100 studs of the camp. The rescue pool (as the Desert's) adds ten more of
the four kinds (POOL_*), 15 in all, ten of them deep, every one 25 or more from every other, off the paths and the
blockers and 8 or more from every cat spot (check_layout asserts it).
"""

import math
from itertools import pairwise

from mathutils import Matrix, Vector

from areakit import PI, Set, gable, hinge, smoke, turned
from common import Builder
from desertset import _hip_ends, dune_piece
from woodsset import _dist_seg, _path, bl

NAME = "CatCafe_Snowy_Set"
N = "CatCafe_Snowy_"
HALF_X, HALF_Z = 75.0, 280.0            # the area's walls at +-75, +-280 (150 wide, 560 deep, as the Desert)
WALL_D = 3.0
IN_X, IN_Z = HALF_X - 0.5 - WALL_D, HALF_Z - 0.5 - WALL_D       # 71.5, 276.5
GATE_HALF = 12.0                        # the camp opening, 24 wide
BARRIER_H = 30.0
BAR_IN = 0.8                            # the border's barrier starts this far into the wall band (#2897)
TRAIL_W = 7.0

# the palette: lit snow, shaded snow, packed snow, blue ice, grey rock, dark pines, warm wood and red trims
SNOW, SNOW_SHADE, SNOW_WARM = "milk", "fur_mist", "fur_white"
PATH, PATH_EDGE = "fur_silver", "fur_mist"
ICE, ICE_LIGHT, ICE_DEEP, ICE_DARK = "pastel_sky", "fish_belly", "fish_blue", "fur_puddle"
ROCK, ROCK_DARK, ROCK_LIGHT = "concrete", "concrete_dark", "fur_pewter"
PINE, PINE_DARK = "leaf_dark", "paw_woods"
WOOD, WOOD_DARK, WOOD_LIGHT = "fur_brown", "dark_wood", "caramel_wood"
RED = "shirt_red"
FLAGS = ("rarity_common", "rarity_rare", "rarity_epic", "rarity_legend", "rarity_mythic")

RIDGE_A_Z, ISLE_A = -222.0, [(-60.0, -12.0), (14.0, 58.0)]
RIDGE_B_Z, ISLE_B = -165.0, [(-IN_X, -30.0), (-6.0, 40.0)]
RIDGE_C_Z, ISLE_C = 164.0, [(-62.0, -14.0), (16.0, 60.0)]
RIDGE_TOP = 9.2                          # over a jump (7.2) and the plan's 9
# Derek 2026-11-14: "make the hills at least for snowy mountain area at the start much less tall and annoying". The two
# ridges by the camp are low rolls a player walks straight over; the one before the summit is lower too.
RIDGE_LOW, RIDGE_MID = 3.2, 5.0
RIDGE_WIND, RIDGE_LEE = 10.0, 6.0        # a ridge's windward slope (toward the camp) and its back, at RIDGE_TOP

LAKE = (0.0, -68.0)
LAKE_RX, LAKE_RZ = 48.0, 38.0
LAKE_TOP = 0.14                          # over the paths (0.078 to 0.116), so the ice covers them where they cross

CAVE_Z0, CAVE_Z1 = -8.0, 132.0
PASS_HALF = 8.0                          # the ice passage, 16 wide
SIDE_X = -IN_X + 8.75                    # the west side passage's middle line (x -71.5 to -54)
ARCHES = (40.0, 110.0)
# (x0, x1, z0, z1, top): the blocks either side of the passage stand tallest, the outer ones step down
ICE_BLOCKS = (
    (-30.0, -PASS_HALF, -6.0, 16.0, 13.0), (-32.0, -PASS_HALF, 26.0, 52.0, 16.0),
    (-28.0, -PASS_HALF, 62.0, 86.0, 14.0), (-30.0, -PASS_HALF, 96.0, 122.0, 16.0),
    (-54.0, -38.0, -4.0, 20.0, 11.5), (-52.0, -40.0, 30.0, 56.0, 13.0), (-54.0, -36.0, 66.0, 90.0, 12.0),
    (-52.0, -38.0, 100.0, 126.0, 12.5),
    (PASS_HALF, 30.0, -6.0, 18.0, 13.5), (PASS_HALF, 32.0, 28.0, 54.0, 16.0), (PASS_HALF, 28.0, 64.0, 88.0, 13.0),
    (PASS_HALF, 30.0, 98.0, 124.0, 16.0),
    (38.0, 56.0, -4.0, 22.0, 12.0), (40.0, 58.0, 32.0, 58.0, 14.0), (38.0, 56.0, 68.0, 94.0, 12.0),
    (40.0, 58.0, 104.0, 128.0, 13.0),
)
ARCH_H = 16.0                            # the arch's rims stand this high, right to the passage

SUMMIT = (0.0, 230.0)
SUM_BASE, SUM_STEP, SUM_TIERS = 56.0, 2.8, 4
SUM_TOP = SUM_STEP * SUM_TIERS           # 11.2
SNOW_CAP = 0.18                          # the snow on each tier, so a tier's walking top is i * SUM_STEP + SNOW_CAP
STAIR_W, STAIR_OUT = 8.0, 4.5

TRAIL = [(0, -IN_Z), (0, -250), (2, -236), (1, -214), (-8, -198), (-18, -182), (-18, -152), (-6, -130), (0, -108),
         (4, -70), (0, -32), (0, -8), (0, 132), (0, 150), (2, 176), (0, 190),
         (0, SUMMIT[1] - SUM_BASE / 2 - STAIR_OUT - 1.0)]
EAST = [(0, -250), (28, -246), (52, -238), (64, -224), (64, -206), (56, -190), (56, -150), (40, -134), (18, -122),
        (0, -108)]                       # the second path, round the east
SIDE = [(SIDE_X, -2.0), (SIDE_X, 128.0)]  # the cave's side passage, packed snow too

# the rescue pool (Desert's shape): (x, z, turn)
POOL_DRIFTS = ((-40.0, -130.0, 0), (44.0, -18.0, 0), (-20.0, 146.0, 0))
POOL_SNOWMEN = ((62.0, -126.0, -90), (40.0, 252.0, 160))
POOL_SLEDS = ((-62.0, -64.0, 90), (60.0, 222.0, -120))
POOL_LOGS = ((-46.0, 95.0, 0), (64.0, 34.0, -90), (-58.0, 250.0, 30))
MAIN_TRAPS = (("trap_snowdrift", -60.0, -152.0, 0), ("trap_snowdrift", 48.0, 182.0, 0),
              ("trap_snowman", -44.0, 214.0, 30), ("trap_sled", 64.0, 80.0, -90),
              ("trap_snow_log", -47.0, 61.0, 0))


def near_trail(x, z):
    d = 1e9
    for pts in (TRAIL, EAST, SIDE):
        for a, b in pairwise(pts):
            d = min(d, _dist_seg((x, z), a, b))
    return d


def trail_length():
    return sum(math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in pairwise(TRAIL))


def in_lake(x, z, pad=0.0):
    return ((x - LAKE[0]) / (LAKE_RX + pad)) ** 2 + ((z - LAKE[1]) / (LAKE_RZ + pad)) ** 2 < 1.0


def in_block(x, z, pad=0.0):
    """On or within pad of an ice block, a ridge or the summit's base: a blocker's footprint."""
    for (x0, x1, z0, z1, _) in ICE_BLOCKS:
        if x0 - pad < x < x1 + pad and z0 - pad < z < z1 + pad:
            return True
    for rz, runs in ((RIDGE_A_Z, ISLE_A), (RIDGE_B_Z, ISLE_B), (RIDGE_C_Z, ISLE_C)):
        if rz - RIDGE_WIND - 1 - pad < z < rz + RIDGE_LEE + 1 + pad:
            if any(a0 - 6 - pad < x < a1 + 6 + pad for a0, a1 in runs):
                return True
    sx, sz = SUMMIT
    h = SUM_BASE / 2
    return abs(x - sx) < h + pad and sz - h - STAIR_OUT - pad < z < sz + h + pad


def _spot(s, label, x, z, y=0.0, turn=None):
    p = [round(x, 2), round(y, 2), round(z, 2), "deep" if z > 0 else "near"]
    if turn is not None:
        p.append(turn)
    s.points.setdefault(label, []).append(p)


# ------------------------------------------------------------------------------------------------- ground --
def _ground():
    """Snow over the whole floor (no plate shows, no grass), the paths of packed snow with a shaded rim, the lake's
    ice with its skate scratches and snow ripples on the slopes."""
    g = Builder()
    g.box_base((0, 0, 0), (2 * HALF_X, 2 * HALF_Z, 0.03), SNOW, bevel=False)
    # rims 0.078 and 0.084 (bend discs 0.068), middles 0.11 and 0.116 (discs 0.1), as the Desert's
    way = TRAIL[:-1] + [(0, SUMMIT[1] - SUM_BASE / 2 - STAIR_OUT + 0.5)]
    for pts, w in ((way, TRAIL_W), (EAST, TRAIL_W - 1.0), (SIDE, 5.0)):
        _path(g, pts, w + 1.4, PATH_EDGE, 0.078)
        _path(g, pts, w, PATH, 0.11)
    # the lake: a flat disc of ice over the paths, a lighter sheen inside it and the skaters' scratches
    x, y, _ = bl(*LAKE)
    g.cyl_base((x, y, 0), LAKE_RX, LAKE_TOP, ICE, segments=32, bevel=False, scale=(1.0, LAKE_RZ / LAKE_RX, 1.0))
    g.cyl_base((x - 6, y + 4, 0), LAKE_RX * 0.55, LAKE_TOP + 0.02, ICE_LIGHT, segments=24, bevel=False,
               scale=(1.0, 0.6, 1.0))
    for k in range(9):                                                   # scratches: arcs of thin strokes
        cx, cz = LAKE[0] - 30 + (k * 23) % 60, LAKE[1] - 24 + (k * 17) % 48
        r = 5.0 + (k % 3) * 2.0
        for j in range(5):
            a = 0.6 * j + k
            px, pz = cx + r * math.cos(a), cz + r * math.sin(a) * 0.7
            if not in_lake(px, pz, -3.0):
                continue
            x, y, _ = bl(px, pz)
            g.box_base((x, y, 0), (2.6, 0.12, LAKE_TOP + 0.05 + 0.006 * (j % 2)), SNOW_WARM, bevel=False,
                       rot=(a + PI / 2, "Z"))
    for k in range(30):                                                  # wind ripples on the slopes
        rx = -64 + (k * 41) % 128
        rz = -268 + (k * 71) % 130
        if near_trail(rx, rz) < TRAIL_W / 2 + 1.0 or in_block(rx, rz, 2.0):
            continue
        for j in range(3):
            x, y, _ = bl(rx, rz + 1.1 * j)
            g.box_base((x, y, 0), (5.0 - j, 0.3, 0.07 + 0.012 * j), SNOW_SHADE, bevel=False,
                       rot=(0.25 * math.sin(k), "Z"))
    return g


# -------------------------------------------------------------------------------------------------- walls --
def pine(mat, h=12.0, name="Pine"):
    """A snowy pine h high, stepped like the style's low-poly trees: a trunk up its middle and four tiers of
    needles narrowing upward, each with a layer of snow on its step, and a snowy tip. Plain Cylinder bands in
    Roblox (10 parts), each colliding where it is drawn."""
    b = Builder()
    b.cyl_base((0, 0, 0), 0.22 * h / 6, h * 0.9, WOOD, segments=8, bevel=False)
    for i, (z, r) in enumerate(((0.16, 0.34), (0.36, 0.27), (0.55, 0.19), (0.72, 0.11))):
        R, t = r * h, 0.2 * h
        b.cyl_base((0, 0, h * z), R, t * 0.78, (PINE, PINE_DARK)[i % 2], segments=8, bevel=False)
        b.cyl_base((0, 0, h * z + t * 0.78), R * 0.8, t * 0.2, SNOW, segments=8, bevel=False)
    b.cyl_base((0, 0, h * 0.9), 0.06 * h, 0.1 * h, SNOW, segments=8, bevel=False)
    return [b.finalize(N + name, mat)]


def _seg_bank(b, L, k):
    """A snowbank against the wall: 9 to 10.5 high in three rolling pieces, each a rounded slope leaning into the
    area up to its crest BAR_IN behind the face line (so the barrier starts at the crest), the bank behind it and a
    shaded crest along its top."""
    n = 3
    w = L / n
    R = Matrix(((0, 0, 1), (1, 0, 0), (0, 1, 0)))                 # profile (y, up), run along x
    for i in range(n):
        x = -L / 2 + (i + 0.5) * w
        H = 9.0 + 1.5 * (((i * 2 + k) % 3) / 2)
        c = BAR_IN
        prof = [(-3.4, 0.0), (-2.5, 0.2 * H), (-1.55, 0.52 * H), (-0.6, 0.85 * H), (c, H)]
        b.fan((x, 0, 0), (c, 0.0), prof, w + 0.02 * i, SNOW, rot=R)
        b.box_base((x, (c + WALL_D) / 2, 0), (w + 0.02 * i, WALL_D - c, H), SNOW_SHADE, bevel=False)
        b.box_base((x, 1.5, H), (w * 0.9, 1.4, 0.35), SNOW_WARM, bevel=False)


def _seg_cliff(b, L, k):
    """A grey rock cliff 15 to 16.5 high: the face, darker ledges standing out of it with snow lying on them, a
    snow cap and drifts at its foot."""
    H = 15.0 + 1.5 * (k % 2)
    b.box_base((0, 1.7, 0), (L, 2.6, H), ROCK, bevel=False)
    for j, z in enumerate((4.2, 8.6, 12.4)):
        b.box((0, 0.25, z), (L, 0.5, 0.8 + 0.1 * j), ROCK_DARK, bevel=False)
        b.box((0, 0.3, z + 0.48 + 0.05 * j), (L - 0.6, 0.6, 0.16), SNOW, bevel=False)
    n = max(2, round(L / 5.5))
    for i in range(n):                                                     # rough buttresses
        x = -L / 2 + (i + 0.5) * L / n
        h = H * (0.45 + 0.4 * (((i * 5 + k * 3) % 6) / 5))
        b.box_base((x, 0.0, 0), (L / n * 0.55, 0.9 + 0.3 * (i % 2), h), (ROCK_LIGHT, ROCK)[(i + k) % 2],
                   bevel=False, rot=(0.04 * ((i * 3 + k) % 3 - 1), "Z"))
        b.box_base((x, 0.0, h), (L / n * 0.6, 1.1 + 0.3 * (i % 2), 0.3), SNOW, bevel=False)
    b.box_base((0, 1.5, H), (L + 0.2, 3.2, 0.7), SNOW, bevel=False)
    m = max(1, round(L / 10.0))
    for i in range(m):                                                     # drifts at the foot, a wedge each
        x = -L / 2 + (i + 0.5) * L / m
        b.wedge((x, -1.1, 1.0 + 0.1 * (i % 2)), (6.0, 3.0, 2.0 + 0.2 * (i % 2)), SNOW, bevel=False)


def _seg_pines(b, L, k):
    """A snowbank 9 high with a row of snowy pines on its crest, so the wall reads as forest."""
    _seg_bank(b, L, k)


SEGMENTS = {"bank": _seg_bank, "cliff": _seg_cliff, "pines": _seg_pines}


def wall_segment(mat, kind, L, k=0):
    """One wall run L long along local x, its face at y 0 (facing -Y, into the area) and its back at WALL_D."""
    b = Builder()
    SEGMENTS[kind](b, L, k)
    out = [b.finalize(N + "Wall" + kind.capitalize(), mat)]
    return out


def peak(mat, h=18.0):
    """A rocky peak in the wall line between two runs, standing over them: three narrowing courses of rock, snow on
    each step and a snow cap."""
    b = Builder()
    for j, (r, z0, z1, sw) in enumerate(((2.8, 0, 8, ROCK), (2.2, 8, 13.5, ROCK_DARK), (1.6, 13.5, h, ROCK))):
        b.box_base((0.2 * (j % 2), WALL_D / 2, z0), (2 * r, 2 * r, z1 - z0 + 0.05 * j), sw, bevel=False,
                   rot=(0.08 * j, "Z"))
        b.box_base((0.2 * (j % 2), WALL_D / 2, z1 + 0.05 * j), (2 * r + 0.3, 2 * r + 0.3, 0.25), SNOW, bevel=False,
                   rot=(0.08 * j, "Z"))
    b.box_base((0, WALL_D / 2, h + 0.3), (2.0, 2.0, 0.7), SNOW, bevel=False, rot=(0.3, "Z"))
    b.wedge((0, -1.6, 1.0), (5.0, 2.4, 2.0), SNOW, bevel=False)
    return [b.finalize(N + "Peak", mat)]


def _run(s, mat, kinds, n, length, place, seed):
    L = (length - (n - 1) * 3.2) / n
    for i in range(n):
        t = i * (L + 3.2) + L / 2
        x, z, rot = place(t)
        kind = kinds[i % len(kinds)]
        s.put(wall_segment(mat, kind, L, i + seed), x, z, rot)
        if kind == "pines":                                     # the pines on the bank's crest, behind the face
            m = max(2, round(L / 7.0))
            for j in range(m):
                lx = -L / 2 + (j + 0.5) * L / m
                px, pz = turned(x, z, rot, -lx, 1.6)
                s.put(pine(mat, 9.0 + 2.5 * ((i + j + seed) % 3) / 2, "PineWall"), px, pz, (j * 53) % 360,
                      y=8.4)
        if i < n - 1:
            s.put(peak(mat, 16.0 + 2.0 * ((i + seed) % 3)), *place(t + L / 2 + 1.6))


def low_wall(mat, L):
    """The camp side: a log fence 3.6 high, three logs between posts, snow along its top, so the camp shows over
    it."""
    b = Builder()
    n = max(2, round(L / 6.0))
    for i in range(n + 1):
        x = -L / 2 + i * L / n
        b.cyl_base((x, 1.0, 0), 0.38, 3.6, WOOD_DARK, segments=8)
        b.cyl_base((x, 1.0, 3.6), 0.46, 0.3, SNOW, segments=8, bevel=False)
    for j, z in enumerate((0.7, 1.7, 2.7)):
        b.cyl((0, 1.0 + 0.04 * j, z), 0.42, L, (WOOD, WOOD_LIGHT)[j % 2], segments=8, rot=(PI / 2, "Y"))
    b.box_base((0, 1.0, 3.12), (L, 0.9, 0.24), SNOW, bevel=False)
    b.wedge((0, -0.4, 0.7), (L - 1.0, 2.0, 1.4), SNOW, bevel=False)                         # a drift along its foot
    return [b.finalize(N + "LowWall", mat)]


def _walls(s, mat):
    """Snowbanks, pine banks and rock cliffs just inside the area's walls, peaks between, the camp side a log fence
    either side of the way in; a barrier all round but the way in."""
    far = ("cliff", "pines", "cliff", "pines", "cliff")
    side = ("pines", "bank", "pines", "pines", "bank", "bank", "cliff", "cliff", "cliff", "pines", "bank", "pines",
            "cliff", "cliff", "cliff")                                   # camp end first
    _run(s, mat, far, 5, 2 * IN_X, lambda t: (-IN_X + t, IN_Z, 0), 0)
    _run(s, mat, side, 15, 2 * IN_Z, lambda t: (IN_X, -IN_Z + t, 90), 1)
    _run(s, mat, side, 15, 2 * IN_Z, lambda t: (-IN_X, -IN_Z + t, -90), 2)
    for sx in (-1, 1):
        s.put(peak(mat, 21.0), sx * (IN_X - 2.0), IN_Z - 2.0, 45 * sx)                      # far corners
        s.put(peak(mat, 14.0), sx * (IN_X - 2.0), -IN_Z + 2.0, 135 * sx)                    # camp corners
        L = IN_X - GATE_HALF - 4.5
        s.put(low_wall(mat, L), sx * (GATE_HALF + 0.5 + L / 2), -IN_Z, 180)
        s.put(lamp(mat), sx * (GATE_HALF + 2.0), -IN_Z + 2.0, 0)
    bar = Builder()
    ox = IN_X + WALL_D
    T = WALL_D - BAR_IN
    mid = IN_Z + BAR_IN + T / 2
    bar.box_base((0, mid, 0), (2 * ox, T, BARRIER_H), "offwhite", bevel=False)                                # far
    for sx in (-1, 1):
        bar.box_base((sx * (IN_X + BAR_IN + T / 2), 0, 0), (T, 2 * IN_Z, BARRIER_H), "offwhite", bevel=False)   # sides
        bar.box_base((sx * (GATE_HALF + ox) / 2, -mid, 0), (ox - GATE_HALF, T, BARRIER_H), "offwhite",
                     bevel=False)                                                                             # camp
    s.put([bar.finalize(N + "Walls_Barrier", mat)], 0, 0, 0)


# -------------------------------------------------------------------------------------------- the blockers --
def _ridge(s, mat, z, runs, seed=0, top=RIDGE_TOP):
    """A snowbank ridge (runs, x0 to x1) `top` high with snowy pines along its crest: banks end to end, each with
    a long windward slope toward the camp and a shaded back, the crest wandering and the heights rolling, the ends
    stepping down into the snow. Every piece collides where it is drawn, so a player can climb over a ridge or walk
    round its end."""
    b = Builder()
    crest = []
    for k, (a0, a1) in enumerate(runs):
        L = a1 - a0
        n = max(2, round(L / 13.0))
        step = L / n
        for i in range(n):
            j = i + 3 * k + seed
            c = a0 + (i + 0.5) * step
            h = top * (1 - 0.045 * (j % 3))                    # the crest rolls a little, the pines over it
            ln = step + 2.4
            hip = 0.7
            if abs(c) + ln / 2 + hip * h > IN_X:
                ln = min(ln, 2 * (IN_X + 1.0 - abs(c)))
                hip = 0.0
            zc = z + 1.3 * ((j * 2) % 3 - 1)
            dune_piece(b, c, zc, ln, h, math.radians(6.0 * ((j * 5) % 3 - 1)), wind=RIDGE_WIND * (0.9 + 0.1 * (j % 3)),
                       lee=RIDGE_LEE, hip=hip, sw=SNOW, sw_lee=SNOW_SHADE)
            for f in (-0.28, 0.22):
                crest.append((c + f * step, zc + 0.5, h, j))
        for e, sgn in ((a0, -1), (a1, 1)):                       # the ends, stepping down
            if abs(abs(e) - IN_X) < 1:
                continue
            for (t, hh, ln, dz) in ((3.0, 0.6, 6.0, 0.6), (6.5, 0.3, 4.0, 1.4)):
                if near_trail(e + sgn * (t + ln / 2 + 0.7 * top * hh), z + dz) < TRAIL_W / 2 + 1.0:
                    break
                dune_piece(b, e + sgn * t, z + dz, ln, top * hh, 0.0, sw=SNOW, sw_lee=SNOW_SHADE)
    s.put([b.finalize(N + "Ridge", mat)], 0, 0, 0)
    for (x, zc, h, j) in crest:
        s.put(pine(mat, 6.0 + 1.5 * (j % 3), "PineRidge"), x, zc, (j * 47) % 360, y=h - min(1.1, 0.25 * h))


def _hump(s, mat, x, z, w=TRAIL_W + 4.0):
    """A low snow hump the path climbs over (a height change): 1.6 high, a soft rise over 7 each side and a rounded
    top, its two ends sloping down into the snow. WedgeParts, so it collides where it is drawn."""
    b = Builder()
    H = 1.6
    prof = [(-7.0, 0.0), (-3.6, 1.0), (-1.4, H), (1.4, H), (3.6, 1.0), (7.0, 0.0)]
    R = Matrix(((0, 0, 1), (1, 0, 0), (0, 1, 0)))
    b.fan((0, 0, 0), (0.0, 0.0), prof, w, SNOW, rot=R)
    _hip_ends(b, Vector((0, 0, 0)), R, prof, w, 0.0, 3.0, [SNOW] * (len(prof) - 1))
    s.put([b.finalize(N + "Hump", mat)], x, z, 0)


def _ice_faces(L, seed, H):
    """Faceted ice along a face L long (local x, the face at y 0 facing -Y): slabs of ice of varied width, depth and
    height, a hair off square, as a list of (centre, size, swatch, turn) in the face's own space."""
    out = []
    x = -L / 2
    i = 0
    while x < L / 2 - 0.5:
        w = min(2.4 + 1.8 * (((i * 7 + seed) % 5) / 4), L / 2 - x)
        dep = 0.6 + 0.8 * (((i * 3 + seed) % 4) / 3)
        h = H * (0.5 + 0.45 * (((i * 5 + seed * 3) % 6) / 5))
        sw = (ICE, ICE_DEEP, ICE_LIGHT, ICE_DARK, ICE_DEEP)[(i + seed) % 5]
        lean = 0.03 + 0.05 * (((i * 5 + seed) % 3) / 2)                      # the slab's top leans out a little
        out.append(((x + w / 2, -dep / 2 + 0.3, h / 2), (w + 0.25, dep + 0.6, h), sw, 0.05 * ((i * 3 + seed) % 3 - 1),
                    lean))
        x += w
        i += 1
    return out


def _place(b, items, origin, yaw):
    R = Matrix.Rotation(yaw, 3, "Z")
    for (c, size, sw, tw, lean) in items:
        p = R @ Vector(c)
        b.box((origin[0] + p.x, origin[1] + p.y, c[2]), size, sw, bevel=False,
              rot=Matrix.Rotation(yaw + tw, 3, "Z") @ Matrix.Rotation(lean, 3, "X"))


def _faces_round(b, x0, x1, z0, z1, H, seed):
    """_ice_faces on all four sides of a block's base (area x0..x1, z0..z1)."""
    for (cx, cz, L, yaw, k) in (((x0 + x1) / 2, z0, x1 - x0 - 4.0, 0.0, 0), ((x0 + x1) / 2, z1, x1 - x0 - 4.0, PI, 1),
                                (x0, (z0 + z1) / 2, z1 - z0 - 4.0, PI / 2, 2),
                                (x1, (z0 + z1) / 2, z1 - z0 - 4.0, -PI / 2, 3)):
        ox, oy, _ = bl(cx, cz)
        _place(b, _ice_faces(L, seed + k, H), (ox, oy), yaw)


def _icicles(d, x0, x1, z, outward, top, seed=0):
    """A row of icicles hanging from an edge `top` high along x (area x0 to x1 at depth z, outward its normal in z):
    thin spikes of four lengths (one Part each). _Decor, so they never get in the way."""
    n = max(2, round(abs(x1 - x0) / 2.2))
    for i in range(n):
        x = x0 + (i + 0.5) * (x1 - x0) / n
        L = (0.8, 1.5, 1.1, 2.0)[(i + seed) % 4]
        px, py, _ = bl(x, z + outward * 0.25)
        d.box((px, py, top - L / 2), (0.24, 0.24, L), (ICE_LIGHT, ICE)[i % 2], bevel=False, rot=(PI / 4, "Z"))


def _icicles_x(d, z0, z1, x, outward, top, seed=0):
    n = max(2, round(abs(z1 - z0) / 2.2))
    for i in range(n):
        z = z0 + (i + 0.5) * (z1 - z0) / n
        L = (0.8, 1.5, 1.1, 2.0)[(i + seed) % 4]
        px, py, _ = bl(x + outward * 0.25, z)
        d.box((px, py, top - L / 2), (0.24, 0.24, L), (ICE_LIGHT, ICE)[i % 2], bevel=False, rot=(PI / 4, "Z"))


def _ice_block(b, d, x0, x1, z0, z1, H, seed):
    """One block of blue ice: a notched base (corners cut back so it reads as ice, not a crate) with a pale ice top
    and a patch of snow on it, big crystal shards standing out of it, leaning this way and that, up to H high,
    faceted slabs leaning out of the base's faces, frozen bubbles in them and icicles along its top edges."""
    W, D = x1 - x0, z1 - z0
    cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
    base = min(H * 0.6, 8.5)
    x, y, _ = bl(cx, cz)
    for n, (w, dd) in enumerate(((W - 4.0, D), (W, D - 4.0))):
        b.box_base((x, y, 0), (w, dd, base - 0.06 * n), (ICE_DEEP, ICE)[n], bevel=False)
    for n, (w, dd) in enumerate(((W - 3.6, D + 0.4), (W + 0.4, D - 3.6))):
        b.box_base((x, y, base - 0.06 * n), (w, dd, 0.4), ICE_LIGHT, bevel=False)
    b.box_base((x + 0.15 * W * (seed % 2 * 2 - 1), y, base + 0.4), (W * 0.42, D * 0.38, 0.25), SNOW, bevel=False,
               rot=(0.3 * ((seed % 3) - 1), "Z"))
    n = max(3, round(W * D / 110.0))
    for j in range(n):                                                       # the shards
        u = ((j * 0.618 + seed * 0.13) % 1.0) - 0.5
        v = ((j * 0.382 + seed * 0.29 + 0.5 * (j % 2)) % 1.0) - 0.5
        px, py, _ = bl(cx + u * (W - 7.0), cz + v * (D - 7.0))
        w = 2.6 + 1.8 * (((j * 3 + seed) % 4) / 3)
        dd = 2.4 + 1.6 * (((j * 5 + seed) % 3) / 2)
        h = (H - base) * (0.55 + 0.5 * (((j * 7 + seed) % 5) / 4)) + 1.0 if j else H - base + 0.6
        tilt = (Matrix.Rotation(0.16 * ((j + seed) % 3 - 1), 3, "X")
                @ Matrix.Rotation(0.14 * ((j * 2 + seed) % 3 - 1), 3, "Y"))
        R = Matrix.Rotation(PI / 4 * ((j + seed) % 2) + 0.2 * u, 3, "Z") @ tilt
        b.box((px, py, base - 0.4 + h / 2), (w, dd, h), (ICE_LIGHT, ICE, ICE_DEEP)[(j + seed) % 3], bevel=False, rot=R)
    _faces_round(b, x0, x1, z0, z1, base, seed)
    for j in range(max(2, round((W + D) / 9.0))):                            # frozen bubbles, in the faces
        t = (j * 0.37 + seed * 0.11) % 1.0
        side = (j + seed) % 4
        zz = 1.6 + 4.0 * (((j * 3 + seed) % 5) / 4) * (base - 2.0) / 6.5
        r = 0.45 + 0.2 * (j % 3)
        if side < 2:
            px, pz = x0 + 2.5 + t * (W - 5.0), (z0 - 0.15 if side == 0 else z1 + 0.15)
        else:
            px, pz = (x0 - 0.15 if side == 2 else x1 + 0.15), z0 + 2.5 + t * (D - 5.0)
        xx, yy, _ = bl(px, pz)
        d.ico((xx, yy, zz), r, ICE_LIGHT, subdivisions=1, scale=(1.0, 1.0, 0.85))
    _icicles(d, x0 + 2.2, x1 - 2.2, z0 - 0.3, -1, base, seed)
    _icicles(d, x0 + 2.2, x1 - 2.2, z1 + 0.3, 1, base, seed + 1)
    _icicles_x(d, z0 + 2.2, z1 - 2.2, x0 - 0.3, -1, base, seed + 2)
    _icicles_x(d, z0 + 2.2, z1 - 2.2, x1 + 0.3, 1, base, seed + 3)


def ice_arch(mat):
    """An arch of ice from rim to rim of the passage, its underside about 11.4 over the floor: a thick band of ice
    in light and deep courses, its feet widening into the rims, snow on its back and icicles hanging under it."""
    b, d = Builder(), Builder()
    w = 2 * PASS_HALF + 2.0
    n = 14
    for k in range(n):
        t = (k + 0.5) / n
        a = PI * t
        x = -(w / 2) * math.cos(a)
        z = ARCH_H - 4.6 + 2.6 * math.sin(a)
        foot = max(0.0, 1.0 - math.sin(a) * 1.6)
        tilt = -math.atan2(2.6 * math.cos(a), w / 2 * math.sin(a))
        b.box((x, 0, z - 0.6 * foot), (w / n * 1.5 + 0.4, 5.0 + 1.5 * foot - 0.01 * (k % 2), 2.6 + 1.6 * foot),
              (ICE, ICE_LIGHT, ICE_DEEP)[k % 3], bevel=False, rot=(tilt, "Y"))
        b.box((x, 0, z + 1.3 + 0.2), (w / n * 1.3, 4.4, 0.4), SNOW, bevel=False, rot=(tilt, "Y"))
        if 2 <= k <= n - 3:
            for f in (-1.6, 0.0, 1.6):
                L = (1.0, 1.8, 1.3)[(k + int(f)) % 3]
                d.box((x, f, z - 1.3 - L / 2), (0.26, 0.26, L), ICE_LIGHT, bevel=False, rot=(PI / 4, "Z"))
    return [b.finalize(N + "IceArch", mat), d.finalize(N + "IceArch_Decor", mat)]


def _cave(s, mat):
    """The Ice Cave: blocks of ice either side of the passage (x -8 to 8) with snow lanes between them, the tallest
    pairs holding the two arches; the west side passage runs between the outer blocks and the wall."""
    b, d = Builder(), Builder()
    for i, (x0, x1, z0, z1, H) in enumerate(ICE_BLOCKS):
        _ice_block(b, d, x0, x1, z0, z1, H, i * 3)
    for z in ARCHES:                                           # the arches' rims, full height right to the passage
        for sx in (-1, 1):
            x, y, _ = bl(sx * (PASS_HALF + 2.7), z)             # 0.3 proud of the blocks' faces
            b.box_base((x, y, 0), (6.0, 12.0, ARCH_H - 0.5), ICE_DEEP, bevel=False)
            b.box_base((x, y, ARCH_H - 0.5), (6.6, 12.6, 0.55), ICE_LIGHT, bevel=False)
    s.put([b.finalize(N + "Cave", mat), d.finalize(N + "Cave_Decor", mat)], 0, 0, 0)
    for z in ARCHES:
        s.put(ice_arch(mat), 0, z, 0)


# ---------------------------------------------------------------------------------------------- the summit --
def summit(mat):
    """Summit Peak, its pivot at its base centre, its stair on the camp face (-Z): four rock tiers SUM_STEP high from
    SUM_BASE wide, each notched at the corners, snow on every tier, a stair of 1.4 steps up the middle of the camp
    face with rock walls, boulders and drifts round the foot."""
    b = Builder()
    for i in range(SUM_TIERS):
        w = SUM_BASE - 9.0 * i
        z = i * SUM_STEP
        for n, (ww, dd) in enumerate(((w - 3.0, w), (w, w - 3.0))):
            b.box_base((0, 0, z), (ww, dd, SUM_STEP - 0.04 * n), (ROCK, ROCK_LIGHT)[(i + n) % 2], bevel=False)
        b.box_base((0, 0, z + SUM_STEP), (w - 3.6, w - 0.6, SNOW_CAP), SNOW, bevel=False)
        b.box_base((0, 0, z + SUM_STEP), (w - 0.6, w - 3.6, SNOW_CAP - 0.01), SNOW, bevel=False)
        for sx in (-1, 1):                                                  # rough rock at the tier's corners
            for sy in (-1, 1):
                b.ico((sx * (w / 2 - 2.2), sy * (w / 2 - 2.2), z + 1.0), 1.4, ROCK_DARK, subdivisions=1,
                      scale=(1.2, 1.0, 0.9))
    for i in range(SUM_TIERS * 2):                                          # the stair, packed snow on stone
        y = -(SUM_BASE / 2) - STAIR_OUT + 2.25 * i + 1.125
        b.box_base((0, y, 0), (STAIR_W, 2.25, 1.4 * (i + 1)), ROCK_DARK, bevel=False)
        b.box_base((0, y, 1.4 * (i + 1)), (STAIR_W - 0.6, 2.1, 0.12), PATH, bevel=False)
    for sx in (-1, 1):
        for i in range(SUM_TIERS):
            y = -(SUM_BASE / 2) - STAIR_OUT + 4.5 * i + 2.25
            b.box_base((sx * (STAIR_W / 2 + 0.5), y, 0), (1.0, 4.5, SUM_STEP * (i + 1) + 0.8), ROCK, bevel=False)
            b.box_base((sx * (STAIR_W / 2 + 0.5), y, SUM_STEP * (i + 1) + 0.8), (1.2, 4.6, 0.2), SNOW, bevel=False)
    c = SUM_BASE / 2
    for sx in (-1, 1):                                                      # drifts banked against the foot
        dune_piece(b, sx * (c - 0.5), c + 0.5, 16.0, 2.4, math.atan2(-sx, -1.0) + PI, wind=4.0, lee=1.0, sw=SNOW,
                   sw_lee=SNOW_SHADE)
        dune_piece(b, sx * (c - 6.0), -c - 0.4, 12.0, 1.8, 0.0, wind=3.0, lee=0.4, sw=SNOW, sw_lee=SNOW_SHADE)
    return [b.finalize(N + "Summit", mat)]


def summit_flag(mat):
    """The summit flag on a stone cairn: a pole 7 high with a pennant in the five rarity colours, the cairn of
    stacked stones with snow on top."""
    b = Builder()
    for j, (r, z) in enumerate(((1.3, 0.0), (1.0, 0.7), (0.75, 1.3), (0.5, 1.8))):
        b.cyl_base((0.06 * (j % 2), 0, z), r, 0.7, (ROCK, ROCK_LIGHT)[j % 2], segments=8)
    b.cyl_base((0, 0, 2.5), 0.4, 0.15, SNOW, segments=8, bevel=False)
    b.cyl_base((0, 0, 2.5), 0.1, 7.0, "metal", segments=8, bevel=False)
    b.ico((0, 0, 9.6), 0.22, "rarity_legend", subdivisions=1)
    f = Builder()                    # the pennant flaps about the mast: the child Model ..._SummitFlag_Swing
    for i, sw in enumerate(FLAGS):
        f.box((-0.6 - 0.62 * i, 0, 8.8 - 0.04 * i), (0.6, 0.06, 1.4 - 0.22 * i), sw, bevel=False)
    return [b.finalize(N + "SummitFlag", mat), hinge(f.finalize(N + "SummitFlag_Swing", mat), (-0.1, 0, 8.8))]


def observatory(mat):
    """A small observatory: a round stone drum 4.4 high, a white dome on it with its slit open toward -Z and a
    brass telescope looking out of it, a little door at the front and snow round its foot."""
    b, panes = Builder(), Builder()
    R = 4.2
    b.cyl_base((0, 0, 0), R, 4.4, ROCK_LIGHT, segments=16)
    b.cyl_base((0, 0, 4.4), R + 0.25, 0.3, ROCK_DARK, segments=16, bevel=False)
    b.sphere((0, 0, 4.7), R, "offwhite", segments=16, rings=8, scale=(1.0, 1.0, 0.9))
    b.box((0, -R * 0.55, 7.0), (1.3, R * 0.9, 3.4), "night_sky", bevel=False, rot=(-0.55, "X"))      # the slit
    b.cyl((0, -R - 0.2, 7.6), 0.35, 3.0, "brass", segments=8, rot=(1.0, "X"), radius2=0.28)        # the telescope
    b.box_base((0, -R + 0.1, 0), (1.8, 0.5, 2.8), WOOD_DARK, bevel=False)                          # the door
    panes.box((-2.6, -R + 0.95, 2.6), (0.9, 0.1, 0.9), "glass", bevel=False, rot=(0.6, "Z"))
    b.cyl_base((0, 0, 0), R + 0.9, 0.4, SNOW, segments=16, radius2=R + 0.2, bevel=False)
    return [b.finalize(N + "Observatory", mat), panes.finalize(N + "Observatory_Pane", mat)]


# --------------------------------------------------------------------------------------------- the pieces --
def snow_rock(mat, r=1.4):
    """A grey boulder with snow on its top."""
    b = Builder()
    b.ico((0, 0, r * 0.55), r, ROCK, subdivisions=1, scale=(1.2, 1.0, 0.8))
    b.ico((0.1 * r, 0, r * 1.05), r * 0.8, SNOW, subdivisions=1, scale=(1.25, 1.05, 0.32))
    return [b.finalize(N + "Rock", mat)]


def snowman(mat, look=0):
    """A snowman, 5 high: three balls of snow, coal eyes and buttons, a carrot nose, stick arms; look 0 wears a red
    scarf and a bobble hat, look 1 a top hat and a blue scarf."""
    b = Builder()
    for (r, z) in ((1.3, 1.1), (0.95, 2.95), (0.68, 4.25)):
        b.ico((0, 0, z), r, SNOW, subdivisions=2)
    for sx in (-1, 1):
        b.ico((sx * 0.26, -0.6, 4.4), 0.08, "fur_black", subdivisions=1)
        b.cyl((sx * 1.4, 0, 3.3), 0.06, 1.6, WOOD, segments=6, bevel=False, rot=(sx * 1.0, "Y"))
    for z in (2.6, 3.1, 3.6):
        b.ico((0, -0.92 + 0.1 * abs(z - 3.1), z), 0.08, "fur_black", subdivisions=1)
    b.cyl((0, -0.95, 4.2), 0.12, 0.7, "fur_orange", segments=8, rot=(PI / 2, "X"), radius2=0.0, bevel=False)
    scarf = (RED, "shirt_blue")[look % 2]
    b.cyl_base((0, 0, 3.7), 0.78, 0.26, scarf, segments=12, bevel=False)
    b.box((0.4, -0.75, 3.35), (0.3, 0.12, 0.8), scarf, bevel=False, rot=(0.2, "Y"))
    if look % 2 == 0:
        b.cyl_base((0, 0, 4.65), 0.6, 0.5, RED, segments=12, radius2=0.45)
        b.ico((0, 0, 5.3), 0.2, "offwhite", subdivisions=1)
    else:
        b.cyl_base((0, 0, 4.72), 0.85, 0.08, "fur_black", segments=12, bevel=False)
        b.cyl_base((0, 0, 4.8), 0.5, 0.9, "fur_black", segments=12)
    return [b.finalize(N + "Snowman" + ("AB"[look % 2]), mat)]


def igloo(mat):
    """An igloo 4.6 high: a dome of snow blocks with block lines, an entrance tunnel toward -Z with a dark door."""
    b = Builder()
    R, n = 4.6, 6
    for k in range(n):                                                        # courses of snow blocks, stepping in
        z0 = R * k / n
        rr = R * math.cos(math.asin(min(1.0, (z0 + R / n * 0.35) / R)))
        b.cyl_base((0, 0, z0), rr, R / n + 0.01 * (k % 2), (SNOW, SNOW_WARM)[k % 2], segments=14, bevel=False)
    b.cyl_base((0, 0, R - 0.1), 0.9, 0.3, SNOW, segments=10, bevel=False)
    b.box_base((0, -R - 0.4, 0), (3.2, 3.4, 2.4), SNOW, bevel=False)                   # the entrance tunnel
    b.box_base((0, -R - 0.4, 2.4), (2.6, 3.2, 0.5), SNOW_WARM, bevel=False)
    b.box_base((0, -R - 2.12, 0), (1.8, 0.1, 1.9), "fur_ink", bevel=False)
    return [b.finalize(N + "Igloo", mat)]


def snow_fort(mat, L=10.0):
    """A snow fort wall L long and 2.6 high with crenellations, a pile of snowballs behind it."""
    b = Builder()
    b.box_base((0, 0, 0), (L, 1.4, 2.0), SNOW, bevel=False)
    n = max(2, round(L / 1.6))
    for i in range(n):
        if i % 2 == 0:
            b.box_base((-L / 2 + (i + 0.5) * L / n, 0, 2.0), (L / n, 1.4, 0.6), SNOW_WARM, bevel=False)
    for (x, y, z) in ((-1.0, 1.4, 0.35), (-0.3, 1.5, 0.35), (0.4, 1.4, 0.35), (-0.65, 1.45, 0.95), (0.05, 1.45, 0.95),
                      (-0.3, 1.45, 1.5)):
        b.ico((x, y, z), 0.36, SNOW, subdivisions=1)
    b.wedge((0, -1.3, 0.45), (L, 1.2, 0.9), SNOW_SHADE, bevel=False)
    return [b.finalize(N + "SnowFort", mat)]


def sled(mat, b=None, at=(0, 0, 0), rot=None, name="Sled"):
    """A red wooden sled 3.6 long: two curled runners, four slats and a rope."""
    own = b is None
    b = b or Builder()
    M = Matrix.Translation(at) @ (rot.to_4x4() if rot is not None else Matrix.Identity(4))

    def P(x, y, z):
        return tuple(M @ Vector((x, y, z)))
    R3 = rot if rot is not None else Matrix.Identity(3)
    for sx in (-0.7, 0.7):
        b.box(P(sx, 0.2, 0.08), (0.14, 3.2, 0.12), "metal", bevel=False, rot=R3)
        b.cyl(P(sx, -1.55, 0.35), 0.32, 0.14, "metal", segments=8, bevel=False,
              rot=R3 @ Matrix.Rotation(PI / 2, 3, "Y"))
        for y in (-1.0, 0.2, 1.4):
            b.box(P(sx, y, 0.3), (0.12, 0.12, 0.4), WOOD_DARK, bevel=False, rot=R3)
    for i, y in enumerate((-1.1, -0.35, 0.4, 1.15)):
        b.box(P(0, y, 0.55 + 0.01 * (i % 2)), (1.7, 0.6, 0.12), RED, bevel=False, rot=R3)
    if own:
        return [b.finalize(N + name, mat)]
    return None


def snowboard_ramp(mat):
    """A snow kicker 1.8 high for show (no physics): a wedge of packed snow with a red lip, flags at its sides."""
    b = Builder()
    b.wedge((0, 0, 0.9), (4.0, 5.0, 1.8), SNOW, bevel=False, rot=(PI, "Z"))
    b.box((0, -2.45, 1.82), (4.0, 0.2, 0.12), RED, bevel=False)
    for sx in (-1, 1):
        b.cyl_base((sx * 2.4, -2.2, 0), 0.06, 2.4, "metal", segments=6, bevel=False)
        b.box((sx * 2.4 - 0.35 * sx, -2.2, 2.1), (0.7, 0.05, 0.45), FLAGS[1 + (sx > 0)], bevel=False)
    return [b.finalize(N + "SnowboardRamp", mat)]


def sled_run(mat, L=34.0):
    """A sled run L long along local y (scenery, no physics): a trough of packed snow between low banks, with a
    bump in the middle, a start flag at its far end."""
    b = Builder()
    W = 5.0
    b.box_base((0, 0, 0), (W, L, 0.14), PATH, bevel=False)
    for sx in (-1, 1):                                                         # its banks, sloping in
        b.wedge((sx * (W / 2 + 0.6), 0, 0.45), (L, 1.2, 0.9), SNOW, bevel=False, rot=(-sx * PI / 2, "Z"))
    prof = [(-3.0, 0.0), (-1.2, 0.5), (0.0, 0.7), (1.2, 0.5), (3.0, 0.0)]
    R = Matrix(((0, 0, 1), (1, 0, 0), (0, 1, 0)))
    b.fan((0, 0, 0.14), (0.0, 0.0), prof, W - 0.2, SNOW_WARM, rot=R)
    for sx in (-1, 1):
        b.cyl_base((sx * (W / 2 + 1.2), L / 2 - 0.8, 0), 0.08, 3.0, "metal", segments=6, bevel=False)
        b.box((sx * (W / 2 + 1.2) - 0.4, L / 2 - 0.8, 2.6), (0.8, 0.05, 0.6), FLAGS[2 + (sx > 0)], bevel=False)
    return [b.finalize(N + "SledRun", mat)]


def ice_hut(mat, roof=RED):
    """An ice-fishing hut 4 by 4: plank walls on skids, a gabled roof, a door and window at the front (-Z), a
    stovepipe, and the fishing hole in the ice beside it with a stool and a bucket."""
    b, panes = Builder(), Builder()
    W, D, H = 4.0, 4.0, 3.0
    for sx in (-1, 1):
        b.box_base((sx * 1.6, 0, 0), (0.3, D + 0.6, 0.3), WOOD_DARK, bevel=False)
    b.box_base((0, 0, 0.3), (W, D, H), WOOD, bevel=False)
    for i in range(1, 4):
        b.box((0, -D / 2 - 0.03, 0.3 + i * 0.75), (W, 0.06, 0.08), WOOD_DARK, bevel=False)
    gable(b, 0, 0, 0.3 + H, W, D, 1.6, WOOD, roof, over=0.4, thick=0.3)
    b.box((0, 0, 0.3 + H + 1.9), (W * 0.7, D + 0.6, 0.12), SNOW, bevel=False)              # snow on the ridge
    b.box_base((-0.9, -D / 2 - 0.05, 0.3), (1.2, 0.1, 2.2), WOOD_DARK, bevel=False)        # the door
    panes.box((0.95, -D / 2 - 0.08, 2.2), (0.9, 0.06, 0.8), "glass", bevel=False)
    b.box((0.95, -D / 2 - 0.1, 2.2), (1.2, 0.04, 1.1), "offwhite", bevel=False)
    b.cyl_base((1.1, 1.0, 0.3 + H + 0.6), 0.2, 1.6, "concrete_dark", segments=8, bevel=False)  # the stovepipe
    b.cyl_base((-3.6, -1.4, 0), 0.7, 0.18, "fur_ink", segments=12, bevel=False)           # the fishing hole
    b.cyl_base((-3.6, -1.4, 0), 0.95, 0.15, SNOW_WARM, segments=12, bevel=False)
    b.cyl_base((-3.4, -2.8, 0), 0.32, 0.6, "metal", segments=8, radius2=0.38)              # the bucket
    b.cyl_base((-2.4, -1.5, 0), 0.28, 0.55, WOOD_LIGHT, segments=8, bevel=False)           # the stool
    return [b.finalize(N + "IceHut", mat), panes.finalize(N + "IceHut_Pane", mat)]


def trail_sign(mat):
    """A trail sign post with three boards: a green circle, a blue square and a black diamond, as on a ski hill."""
    b = Builder()
    b.cyl_base((0, 0, 0), 0.16, 4.2, WOOD_DARK, segments=8, bevel=False)
    b.cyl_base((0, 0, 4.2), 0.24, 0.12, SNOW, segments=8, bevel=False)
    for i, (z, sw, shape) in enumerate(((3.6, "shirt_green", "c"), (2.8, "shirt_blue", "s"), (2.0, "fur_black", "d"))):
        dx = 0.7 * (-1 if i % 2 else 1)
        b.box((dx, -0.12, z), (1.6, 0.12, 0.6), "offwhite", bevel=False)
        if shape == "c":
            b.cyl((dx - 0.45, -0.2, z), 0.2, 0.05, sw, segments=12, bevel=False, rot=(PI / 2, "X"))
        elif shape == "s":
            b.box((dx - 0.45, -0.2, z), (0.36, 0.05, 0.36), sw, bevel=False)
        else:
            b.box((dx - 0.45, -0.2, z), (0.3, 0.05, 0.3), sw, bevel=False, rot=(PI / 4, "Y"))
        b.box((dx + 0.25, -0.2, z), (0.8, 0.05, 0.1), "fur_charcoal", bevel=False)
    return [b.finalize(N + "TrailSign", mat)]


def lamp(mat):
    """A lantern on a wooden post, lit at night (_Bulb), with snow on its roof."""
    b, bulb = Builder(), Builder()
    b.box_base((0, 0, 0), (0.9, 0.9, 0.5), ROCK_DARK, bevel=False)
    b.box_base((0, 0, 0.5), (0.5, 0.5, 4.6), WOOD_DARK)
    b.box_base((0, 0, 5.1), (1.0, 1.0, 0.15), "fur_charcoal", bevel=False)
    bulb.box_base((0, 0, 5.25), (0.6, 0.6, 0.8), "lamp_warm", bevel=False)
    for (x, y) in ((-0.36, -0.36), (0.36, -0.36), (-0.36, 0.36), (0.36, 0.36)):
        b.box_base((x, y, 5.25), (0.1, 0.1, 0.8), "fur_charcoal", bevel=False)
    b.pyramid((0, 0, 6.05), 1.1, 0.6, "fur_charcoal")
    b.pyramid((0, 0, 6.3), 0.8, 0.45, SNOW)
    return [b.finalize(N + "Lamp", mat), bulb.finalize(N + "Lamp_Bulb", mat)]


def bench(mat):
    """A log bench 3 long with snow on its seat ends."""
    b = Builder()
    for sx in (-1, 1):
        b.cyl_base((sx * 1.1, 0, 0), 0.32, 0.8, WOOD_DARK, segments=8)
    b.cyl((0, 0, 1.0), 0.38, 3.0, WOOD, segments=8, rot=(PI / 2, "Y"))
    b.box((1.0, 0, 1.36), (0.7, 0.5, 0.1), SNOW, bevel=False)
    return [b.finalize(N + "Bench", mat)]


def marker_poles(mat, n=3, gap=4.0):
    """A run of n red and white marker poles gap apart along local X with a rope sagging between them, lining the
    path. The poles collide (thin); the rope (_Decor) doesn't."""
    b, d = Builder(), Builder()
    xs = [(i - (n - 1) / 2) * gap for i in range(n)]
    for x in xs:
        b.sphere((x, 0, 0), 0.5, SNOW, segments=8, rings=4, scale=(1.0, 1.0, 0.35))
        for j in range(2):
            b.cyl_base((x, 0, 1.0 * j), 0.14, 1.0, (RED, "offwhite")[j % 2], segments=8, bevel=False)
    for x0, x1 in pairwise(xs):
        pts = [(x0 + (x1 - x0) * t, 1.68 - 0.45 * math.sin(PI * t)) for t in (0.0, 0.25, 0.5, 0.75, 1.0)]
        for (ax, az), (bx, bz) in pairwise(pts):
            L = math.hypot(bx - ax, bz - az)
            d.box(((ax + bx) / 2, 0, (az + bz) / 2), (L + 0.08, 0.08, 0.08), "fur_orange", bevel=False,
                  rot=(-math.atan2(bz - az, bx - ax), "Y"))
    return [b.finalize(N + "MarkerPoles", mat), d.finalize(N + "MarkerPoles_Decor", mat)]


def snowball_pile(mat):
    """A pyramid of snowballs on a low drift, as kids leave them."""
    b = Builder()
    b.cyl_base((0, 0, 0), 1.5, 0.3, SNOW_SHADE, segments=12, bevel=False)
    k = 0
    for row, n in enumerate((3, 2, 1)):
        for i in range(n):
            x = (i - (n - 1) / 2) * 0.62
            b.ico((x, 0.2 * (row % 2), 0.6 + 0.5 * row), 0.31, (SNOW, SNOW_WARM)[k % 2], subdivisions=1)
            k += 1
    return [b.finalize(N + "SnowballPile", mat)]


def ski_pair(mat):
    """A pair of skis and two poles stuck upright in a snow mound."""
    b = Builder()
    b.cyl_base((0, 0, 0), 1.4, 0.45, SNOW, segments=12, radius2=0.9, bevel=False)
    for i, sx in enumerate((-0.25, 0.25)):
        b.box_base((sx, 0.1, 0.2), (0.22, 0.08, 3.6), ("shirt_blue", RED)[i], bevel=False,
                   rot=(0.05 * (1 - 2 * i), "Y"))
        b.box((sx, 0.04, 3.85), (0.22, 0.2, 0.3), ("shirt_blue", RED)[i], bevel=False, rot=(0.6, "X"))
    for sx in (-0.9, 0.9):
        b.cyl_base((sx, 0.2, 0.2), 0.05, 2.8, "metal", segments=6, bevel=False)
        b.cyl_base((sx, 0.2, 0.55), 0.26, 0.04, "fur_black", segments=8, bevel=False)
    return [b.finalize(N + "SkiPair", mat)]


def _on_path(pts, i, t, side, off):
    (ax, az), (bx, bz) = pts[i], pts[i + 1]
    dx, dz = bx - ax, bz - az
    L = math.hypot(dx, dz)
    nx, nz = -dz / L, dx / L
    return ax + dx * t + side * off * nx, az + dz * t + side * off * nz, math.degrees(math.atan2(-dz, dx))


# --------------------------------------------------------------------------------------- the rescue traps --
def trap_snowdrift(mat):
    """A cat stuck in a snowdrift up to its chest: a ring of snow mounds 1.2 high round the spot (radius 1.3 open in
    the middle), spilled snow round it, a paw print trail leading in from local -Z."""
    b = Builder()
    for k in range(10):
        a = 2 * PI * k / 10
        r = 1.9 + 0.15 * (k % 2)
        b.ico((r * math.cos(a), r * math.sin(a), 0.35), 1.15, (SNOW, SNOW_WARM)[k % 2], subdivisions=1,
              scale=(1.0, 1.0, 0.75 + 0.05 * (k % 3)))
    b.cyl_base((0, 0, 0), 3.6, 0.3, SNOW_SHADE, segments=16, radius2=2.6, bevel=False)
    for i in range(3):
        b.cyl_base((0.35 * (-1) ** i, -4.2 - 1.2 * i, 0), 0.22, 0.06, SNOW_SHADE, segments=8, bevel=False)
    return [b.finalize(N + "TrapSnowdrift", mat)]


def trap_snowman(mat):
    """A snowman 2.4 behind the spot (local +Z) and a heap of snow at its feet round the spot, a cat in the heap up
    to its chest with its tail out (the cat is the game's; the heap is open in the middle)."""
    b = Builder()
    for (r, z) in ((1.3, 1.1), (0.95, 2.95), (0.68, 4.25)):
        b.ico((0, 2.6, z), r, SNOW, subdivisions=2)
    for sx in (-1, 1):
        b.ico((sx * 0.26, 2.0, 4.4), 0.08, "fur_black", subdivisions=1)
        b.cyl((sx * 1.4, 2.6, 3.3), 0.06, 1.6, WOOD, segments=6, bevel=False, rot=(sx * 1.0, "Y"))
    b.cyl((0, 1.65, 4.2), 0.12, 0.7, "fur_orange", segments=8, rot=(PI / 2, "X"), radius2=0.0, bevel=False)
    b.cyl_base((0, 2.6, 3.7), 0.78, 0.26, RED, segments=12, bevel=False)
    b.cyl_base((0, 2.6, 4.65), 0.6, 0.5, "shirt_green", segments=12, radius2=0.45)
    for k in range(8):                                                     # the heap round the spot, open at -Z
        a = PI / 2 + 2 * PI * (k + 0.5) / 9
        b.ico((1.8 * math.cos(a), 1.8 * math.sin(a), 0.3), 0.95, (SNOW, SNOW_WARM)[k % 2], subdivisions=1,
              scale=(1.0, 1.0, 0.7))
    b.cyl_base((0, 0.4, 0), 3.2, 0.24, SNOW_SHADE, segments=16, radius2=2.4, bevel=False)
    return [b.finalize(N + "TrapSnowman", mat)]


def trap_sled(mat):
    """A sled tipped over on its side and propped on a drift at its back, its slats over the spot, open toward local
    -Z; the drift behind it."""
    b = Builder()
    tip = Matrix.Rotation(-1.1, 3, "X") @ Matrix.Rotation(PI / 2, 3, "Z")       # runners up and toward the back
    sled(mat, b, at=(0.0, 1.0, 0.2), rot=tip)
    b.wedge((0, 2.6, 0.8), (5.0, 2.4, 1.6), SNOW, bevel=False, rot=(PI, "Z"))               # the drift it leans on
    b.cyl_base((0, 0, 0), 3.0, 0.2, SNOW_SHADE, segments=16, radius2=2.4, bevel=False)
    return [b.finalize(N + "TrapSled", mat)]


def trap_snow_log(mat):
    """A hollow log lying on its side, its mouth toward local +X (a cat head first inside, as the Woods' log): bark
    rings, a dark mouth, snow heaped on its top and a drift at its back end."""
    b = Builder()
    R = Matrix.Rotation(PI / 2, 3, "Y")
    b.cyl((0.0, 0, 1.25), 1.3, 4.6, WOOD, segments=14, rot=R)
    b.ring((2.32, 0, 1.25), 1.34, 0.3, 0.12, WOOD_LIGHT, segments=14, rot=(PI / 2, "Y"))
    b.cyl((2.3, 0, 1.25), 1.0, 0.12, "fur_ink", segments=14, rot=R, bevel=False)
    for x in (-1.4, 0.2, 1.5):
        b.cyl((x, 0, 1.25), 1.36, 0.2, WOOD_DARK, segments=14, rot=R, bevel=False)
    b.box((0.0, 0, 2.6), (4.2, 1.4, 0.3), SNOW, bevel=False)
    b.box((-0.2, 0, 2.82), (3.0, 0.9, 0.2), SNOW_WARM, bevel=False)
    b.wedge((-3.2, 0, 0.7), (2.6, 1.6, 1.4), SNOW, bevel=False, rot=(-PI / 2, "Z"))         # a drift at its back end
    return [b.finalize(N + "TrapSnowLog", mat)]


TRAPS = {"trap_snowdrift": (trap_snowdrift, 4.0), "trap_snowman": (trap_snowman, 4.0), "trap_sled": (trap_sled, 3.5),
         "trap_snow_log": (trap_snow_log, 3.5)}


def all_traps():
    out = [t for t in MAIN_TRAPS]
    for label, pool in (("trap_snowdrift", POOL_DRIFTS), ("trap_snowman", POOL_SNOWMEN), ("trap_sled", POOL_SLEDS),
                        ("trap_snow_log", POOL_LOGS)):
        out += [(label, x, z, t) for (x, z, t) in pool]
    return out


def check_layout():
    """The rescue pool's rules (as the Desert's): 15 traps, every one 25 from every other, off the paths and the
    blockers, out of the lake, none within 100 of the camp; four of the five main ones and six of the pool deep."""
    traps = all_traps()
    assert len(traps) == 15, len(traps)
    for i, (la, xa, za, _) in enumerate(traps):
        assert near_trail(xa, za) > TRAIL_W / 2 + 3.0, (la, xa, za, near_trail(xa, za))
        assert not in_block(xa, za, 2.0), (la, xa, za)
        assert not in_lake(xa, za, 3.0), (la, xa, za)
        assert abs(xa) < IN_X - 3.0 and abs(za) < IN_Z - 3.0, (la, xa, za)
        assert za > -IN_Z + 100.0, (la, xa, za)
        for (lb, xb, zb, _) in traps[i + 1:]:
            assert math.hypot(xa - xb, za - zb) >= 25.0, (la, xa, za, lb, xb, zb)
    assert sum(1 for t in MAIN_TRAPS if t[2] > 0) == 4
    assert sum(1 for t in traps[5:] if t[2] > 0) == 6, [t for t in traps[5:] if t[2] > 0]


# ------------------------------------------------------------------------------------- the Cocoa Lodge camp --
# camps.py builds CatCafe_Camp_Snowy (the camp's ground, walls, pad and basket, as every camp) and places these. The
# camp is the area's only warm colour (plan 1b): orange light, red trims, warm wood.
def lodge_front(mat):
    """The Cocoa Lodge's front, built against the camp's back wall (pivot at its base centre, front -Z): a timber
    front 22 wide and 7 high on a stone footing, a gable with a red trim and snow on the roof, a warm-lit window
    either side of a double door (_Pane, lit at night), a stone chimney at the east end, a sign board over the door
    (the words are the game's) and a snowy porch roof on two posts."""
    b, panes = Builder(), Builder()
    W, D, H = 22.0, 4.0, 7.0
    b.box_base((0, 0, 0), (W + 0.6, D + 0.6, 0.8), ROCK, bevel=False)
    b.box_base((0, 0, 0.8), (W, D, H - 0.8), WOOD, bevel=False)
    for i in range(1, 7):                                                    # the log courses
        b.box((0, -D / 2 - 0.05, 0.8 + i * 0.9), (W, 0.12, 0.14), WOOD_DARK, bevel=False)
    for sx in (-1, 1):
        b.box_base((sx * (W / 2 - 0.3), -D / 2 - 0.1, 0.8), (0.7, 0.5, H - 0.8), WOOD_DARK, bevel=False)
    gable(b, 0, 0, H, W, D, 4.6, WOOD, RED, over=0.8, thick=0.45)
    a = math.atan2(4.6, W / 2)
    for sx in (-1, 1):                                                       # snow on the roof slabs
        L = math.hypot(W / 2, 4.6) * 0.86
        b.box((sx * W / 4, 0, H + 2.3 + 0.5), (L, D + 1.4, 0.25), SNOW, bevel=False, rot=(sx * a, "Y"))
    b.box_base((0, -D / 2 - 0.06, 0.8), (4.0, 0.12, 3.6), WOOD_DARK, bevel=False)            # the double door
    b.box((0, -D / 2 - 0.14, 2.6), (0.08, 0.06, 3.4), "fur_black", bevel=False)
    b.box((0, -D / 2 - 0.1, 5.4), (6.0, 0.14, 1.3), RED, bevel=False)                       # the sign board
    b.box((0, -D / 2 - 0.16, 5.4), (5.6, 0.06, 0.95), "cream", bevel=False)
    for sx in (-1, 1):
        x = sx * 6.6
        b.box((x, -D / 2 - 0.06, 3.4), (4.2, 0.2, 2.8), RED, bevel=False)                    # window frames
        panes.box((x, -D / 2 - 0.12, 3.4), (3.6, 0.06, 2.2), "lamp_warm", bevel=False)
        b.box((x, -D / 2 - 0.2, 3.4), (0.14, 0.05, 2.2), RED, bevel=False)
        b.box((x, -D / 2 - 0.3, 2.05), (4.6, 0.6, 0.2), WOOD_DARK, bevel=False)              # sills
        b.box((x, -D / 2 - 0.3, 2.2), (4.2, 0.5, 0.12), SNOW, bevel=False)
    # the porch: two posts and a short roof over the door
    for sx in (-1, 1):
        b.cyl_base((sx * 2.8, -D / 2 - 2.6, 0), 0.22, 4.6, WOOD_DARK, segments=8, bevel=False)
    b.box((0, -D / 2 - 1.4, 4.75), (7.0, 3.2, 0.3), RED, bevel=False, rot=(-0.2, "X"))
    b.box((0, -D / 2 - 1.4, 5.0), (6.6, 2.8, 0.22), SNOW, bevel=False, rot=(-0.2, "X"))
    # the chimney, stone, at the east end (Blender -x is Roblox +x)
    b.box_base((-(W / 2 - 2.2), D / 2 - 1.0, 0), (2.4, 2.2, H + 6.4), ROCK_LIGHT, bevel=False)
    b.box_base((-(W / 2 - 2.2), D / 2 - 1.0, H + 6.4), (2.8, 2.6, 0.4), ROCK_DARK, bevel=False)
    b.box_base((-(W / 2 - 2.2), D / 2 - 1.0, H + 6.8), (2.2, 2.0, 0.2), SNOW, bevel=False)
    front = smoke(b.finalize(N + "LodgeFront", mat), (-(W / 2 - 2.2), D / 2 - 1.0, H + 7.0))
    return [front, panes.finalize(N + "LodgeFront_Pane", mat)]


def fire_pit(mat):
    """A fire pit: a ring of stones round crossed logs and a soft fire (_Campfire_Glow, Neon day and night, no smoke)."""
    b, glow = Builder(), Builder()
    for k in range(10):
        a = 2 * PI * k / 10
        b.ico((1.4 * math.cos(a), 1.4 * math.sin(a), 0.25), 0.42, (ROCK, ROCK_LIGHT)[k % 2], subdivisions=1,
              scale=(1.0, 1.0, 0.7))
    for k in range(3):
        b.cyl((0, 0, 0.3 + 0.05 * k), 0.16, 1.9, WOOD_DARK, segments=6, bevel=False,
              rot=Matrix.Rotation(k * PI / 3, 3, "Z") @ Matrix.Rotation(PI / 2, 3, "Y"))
    # three tongues, the Woods campfire's shape, so Effects/Campfire flickers it (it looks for `_Campfire_Glow`)
    glow.cyl_base((0, 0, 0.35), 0.7, 1.3, "fur_marmalade", segments=6, radius2=0.05, bevel=False)
    glow.cyl_base((0.22, 0.1, 0.36), 0.4, 0.95, "pastel_butter", segments=6, radius2=0.02, bevel=False)
    glow.cyl_base((-0.26, -0.18, 0.37), 0.36, 0.85, "fur_ginger", segments=6, radius2=0.02, bevel=False)
    return [b.finalize(N + "FirePit", mat), glow.finalize(N + "FirePit_Campfire_Glow", mat)]


def ski_rack(mat):
    """A ski rack 4 wide: a wooden frame with four pairs of skis leaning in it, poles hooked on its end, snow on top."""
    b = Builder()
    for sx in (-1, 1):
        b.box_base((sx * 2.0, 0, 0), (0.25, 1.4, 2.4), WOOD_DARK, bevel=False)
    b.box((0, 0.55, 2.2), (4.3, 0.2, 0.2), WOOD, bevel=False)
    b.box((0, -0.55, 0.5), (4.3, 0.2, 0.2), WOOD, bevel=False)
    b.box((0, 0.6, 2.36), (4.0, 0.3, 0.1), SNOW, bevel=False)
    for i, sw in enumerate(("shirt_blue", RED, "fur_orange", "shirt_green")):
        x = -1.5 + i
        for dx in (-0.14, 0.14):
            b.box((x + dx, 0.05, 1.5), (0.18, 0.08, 3.0), sw, bevel=False, rot=(-0.35, "X"))
    for dx in (2.3, 2.45):
        b.cyl_base((dx, 0.0, 0.0), 0.04, 2.0, "metal", segments=6, bevel=False)
    return [b.finalize(N + "SkiRack", mat)]


# --------------------------------------------------------------------------------------------------- set --
def build_set(mat):
    check_layout()
    s = Set(NAME)
    keep = []

    def put(fn, x, z, rot=0.0, r=4.0, y=0.0):
        keep.append((x, z, r))
        return s.put(fn, x, z, rot, y)

    _walls(s, mat)
    _ridge(s, mat, RIDGE_A_Z, ISLE_A, 0, RIDGE_LOW)
    _ridge(s, mat, RIDGE_B_Z, ISLE_B, 1, RIDGE_LOW)
    _ridge(s, mat, RIDGE_C_Z, ISLE_C, 2, RIDGE_MID)
    for (x, z) in ((0, -244), (-18, -170), (60, -176), (0, 150)):
        _hump(s, mat, x, z)
        keep.append((x, z, 9))
    _cave(s, mat)

    # the gate band: trail signs by the way in and at the fork, lamps, benches
    put(trail_sign(mat), -7.0, -262.0, 15, r=2)
    put(trail_sign(mat), 8.0, -254.0, -30, r=2)
    for (x, z, rot) in ((-26, -262, 0), (30, -266, 10)):
        put(bench(mat), x, z, rot, r=2.5)
        _spot(s, "bench", x, z - 1.6)
    put(snowman(mat, 0), -18.0, -246.0, 20, r=2.5)
    _spot(s, "snowman", -16.0, -248.2)
    put(snowball_pile(mat), 22.0, -256.0, 0, r=2)
    _spot(s, "snowballs", 22.0, -253.4)

    # the pine slopes: the sled run on the west, pines and rocks between the ridges
    put(sled_run(mat), -42.0, -255.0, 0, r=6)
    keep.append((-42.0, -240.0, 5))
    keep.append((-42.0, -270.0, 5))
    _spot(s, "sled_run", -45.8, -262.0)
    _spot(s, "sled_run", -38.2, -246.0)
    put(snowboard_ramp(mat), -60.0, -262.0, 20, r=3.5)
    _spot(s, "ramp", -60.0, -257.4, y=0.0)
    put(sled(mat), -30.0, -236.0, 70, r=2.5)
    _spot(s, "sled", -28.0, -233.6)
    for (x, z, h) in ((-62, -244, 11), (44, -262, 10), (60, -258, 12), (-26, -206, 10), (28, -206, 11),
                      (-50, -186, 9), (40, -186, 10), (-58, -138, 11), (20, -142, 10), (62, -252, 9)):
        put(pine(mat, h), x, z, (x * 7) % 360, r=h * 0.36)
        _spot(s, "pine", x + h * 0.36 + 1.0, z - 1.2)
    for (x, z) in ((-8, -228), (52, -256), (-40, -196), (10, -150), (-30, -142)):
        put(snow_rock(mat, 1.3), x, z, (x * 7) % 360, r=2.5)
        _spot(s, "rock", x, z, y=1.6)
    for (x, z) in ((-56, -234), (36, -232), (-34, -230), (16, -188), (-6, -182), (-44, -150), (30, -156)):
        _spot(s, "slope", x, z)
    for (x, z, rot) in ((-14, -206, 90), (46, -198, -90), (-26, -150, 90)):
        put(lamp(mat), x, z, rot, r=1.5)

    # the frozen lake: the huts out on the ice, the fort and the igloo on the shores
    for (x, z, rot, roof) in ((-24, -84, 20, RED), (26, -56, -15, "shirt_blue"), (22, -96, 200, "shirt_green")):
        put(ice_hut(mat, roof), x, z, rot, r=5)
        _spot(s, "hut", *turned(x, z, rot, -1.8, -2.8))
    put(snow_fort(mat), -50.0, -28.0, 40, r=6)
    _spot(s, "fort", *turned(-50.0, -28.0, 40, 0.0, 2.2))
    put(igloo(mat), 56.0, -100.0, -60, r=6)
    _spot(s, "igloo", *turned(56.0, -100.0, -60, 0.0, -7.6))
    for (x, z) in ((-36, -60), (34, -82), (-10, -48), (14, -36), (-30, -96), (38, -40), (-4, -92)):
        _spot(s, "lake", x, z, y=LAKE_TOP)
    for (x, z) in ((-60, -96), (62, -60), (-56, -116), (54, -20), (-24, -20), (24, -118)):
        _spot(s, "shore", x, z)
    for (x, z, rot) in ((-56, -80, 0), (58, -40, 180), (-8, -122, 0), (8, -18, 0)):
        put(bench(mat), x, z, rot + 90 * (x > 0), r=2.5)
    put(snowman(mat, 1), -40.0, -14.0, 160, r=2.5)
    _spot(s, "snowman", -38.0, -11.8)
    put(snowman(mat, 0), 36.0, -122.0, -20, r=2.5)
    _spot(s, "snowman", 38.0, -124.2)
    for (x, z, rot) in ((-6, -110, 90), (8, -26, -90)):
        put(lamp(mat), x, z, rot, r=1.5)

    # the ice cave: the passage, the lanes, the side passage
    for (x0, x1, z0, z1, _) in ICE_BLOCKS:                    # a cat at the mouth of each lane on the passage
        if x1 == -PASS_HALF:
            _spot(s, "cave", -PASS_HALF + 1.6, z1 + 4.0)
        elif x0 == PASS_HALF:
            _spot(s, "cave", PASS_HALF - 1.6, z0 - 4.0)
    for (x, z) in ((-34, 4), (34, 60), (-34, 92), (34, 120), (-46, 61), (48, 28), (-46, 26), (48, 100)):
        _spot(s, "lane", x, z)
    for z in (10, 44, 84, 116):
        _spot(s, "side_passage", SIDE_X + 3.0 * (1 if z % 4 else -1), z)
    for z in (12, 50, 96):
        _spot(s, "east_strip", 65.0, z)
    for (x, z, r) in ((5.5, 8.0, 1.2), (5.0, 74.0, 1.4), (5.0, 134.0, 1.1), (64.0, 64.0, 1.3),
                      (SIDE_X + 3, 30, 1.2)):
        put(snow_rock(mat, r), x, z, (x * 13) % 360, r=2.2)
        _spot(s, "rock", x, z, y=1.4 * r)
    for (x, z, rot) in ((-7.4, -4.0, 90), (7.4, 128.0, -90), (SIDE_X + 6.5, 70.0, 90)):
        put(lamp(mat), x, z, rot, r=1.5)

    # the summit path: signs, snowmen and boulders before the pine ridge and the summit
    put(trail_sign(mat), -6.0, 140.0, 0, r=2)
    put(trail_sign(mat), 6.0, 190.0, 180, r=2)
    for (x, z, look, rot) in ((-30, 140, 1, 30), (34, 146, 0, -30), (-36, 186, 0, 10)):
        put(snowman(mat, look), x, z, rot, r=2.5)
        _spot(s, "snowman", *turned(x, z, rot, 1.6, -1.6))
    for (x, z) in ((-52, 140), (54, 136), (26, 186), (-60, 196), (60, 196)):
        put(snow_rock(mat, 1.5), x, z, (x * 5) % 360, r=3)
        _spot(s, "rock", x, z, y=1.8)
    for (x, z) in ((-14, 140), (18, 136), (-20, 188), (40, 188), (-44, 156), (44, 154)):
        _spot(s, "summit_path", x, z)
    for (x, z, rot) in ((-6, 160, 90), (6, 172, -90)):
        put(lamp(mat), x, z, rot, r=1.5)

    # summit peak: the summit, the flag and the observatory on top
    px, pz = SUMMIT
    put(summit(mat), px, pz, 0, r=SUM_BASE / 2 + 4)
    put(summit_flag(mat), px - 5.0, pz - 4.0, 0, r=1.5, y=SUM_TOP + SNOW_CAP)
    put(observatory(mat), px + 6.0, pz + 7.0, 0, r=5, y=SUM_TOP + SNOW_CAP)
    for i in range(1, SUM_TIERS):
        w = SUM_BASE - 9.0 * i
        for sx in (-1, 1):
            _spot(s, "summit_tier", px + sx * max(7.0, w / 2 - 3.0), pz - w / 2 - 2.25, y=i * SUM_STEP + SNOW_CAP)
    _spot(s, "summit_top", px - 9.0, pz - 9.0, y=SUM_TOP + SNOW_CAP)
    _spot(s, "summit_top", px + 3.0, pz - 9.5, y=SUM_TOP + SNOW_CAP)
    _spot(s, "summit_top", px - 9.0, pz + 8.0, y=SUM_TOP + SNOW_CAP)
    for (x, z) in ((-50, 230), (52, 252), (-34, 266), (40, 206), (-62, 214)):
        _spot(s, "summit_foot", x, z)
    for (x, z, rot) in ((-6, 196, 90), (6, 196, -90)):
        put(lamp(mat), x, z, rot, r=1.5)

    # the rescue spots: the five main ones and the pool (scenery until the day's pick puts a stuck cat in one)
    for (label, x, z, t) in all_traps():
        fn, r = TRAPS[label]
        put(fn(mat), x, z, t, r=r)
        _spot(s, label, x, z, turn=t)

    # the path kit: marker poles, snowball piles and ski pairs along the main path, clear of the spots, the pieces
    # and the blockers, off the lake
    spots = [(p[0], p[2]) for lst in s.points.values() for p in lst]

    def free(x, z, r):
        if any(math.hypot(x - qx, z - qz) < r + 3.0 for (qx, qz) in spots):
            return False
        if any(math.hypot(x - qx, z - qz) < r + qr + 1.0 for (qx, qz, qr) in keep):
            return False
        if in_block(x, z, r + 1.0) or in_lake(x, z, r + 1.0) or z < -IN_Z + 4:
            return False
        return abs(x) < IN_X - 4
    edge = TRAIL_W / 2 + 0.7
    for pts in (TRAIL, EAST):
        seg = [math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in pairwise(pts)]
        k, d = 0, 8.0
        while d < sum(seg) - 8.0:
            i, rest = 0, d
            while rest > seg[i]:
                rest -= seg[i]
                i += 1
            L, t = seg[i], rest / seg[i]
            (ax, az), (bx, bz) = pts[i], pts[i + 1]
            kind = ("poles", "balls", "poles", "skis")[k % 4]
            for side in ((-1, 1) if k % 2 else (1, -1)):
                if kind == "poles":
                    if t - 4.5 / L < 0.0 or t + 4.5 / L > 1.0:
                        break
                    x, z, heading = _on_path(pts, i, t, side, edge + 0.5)
                    posts = [(x + u * (bx - ax) / L, z + u * (bz - az) / L) for u in (-4.0, 0.0, 4.0)]
                    if all(free(qx, qz, 0.6) and near_trail(qx, qz) > edge for qx, qz in posts):
                        s.put(marker_poles(mat), x, z, heading)
                        keep.extend((qx, qz, 0.6) for qx, qz in posts)
                        break
                else:
                    r = 1.8
                    x, z, _ = _on_path(pts, i, t, side, edge + r + 0.6)
                    if free(x, z, r) and near_trail(x, z) > edge + r:
                        put((snowball_pile if kind == "balls" else ski_pair)(mat), x, z, (k * 47) % 360, r=r)
                        break
            k += 1
            d += 15.0

    # filler: small pines and snowy rocks, clear of the paths, the blockers, the lake, the pieces and the spots
    spots = [(p[0], p[2]) for lst in s.points.values() for p in lst]
    k = 0
    for gx in range(-64, 65, 16):
        for gz in range(-262, 263, 16):
            k += 1
            x = gx + 5.0 * math.sin(k * 2.71)
            z = gz + 5.0 * math.cos(k * 1.93)
            if z < -IN_Z + 16 and abs(x) < GATE_HALF + 10:
                continue
            if near_trail(x, z) < 8.0 or in_block(x, z, 4.0) or in_lake(x, z, 4.0):
                continue
            if abs(x) > IN_X - 4:
                continue
            if any(math.hypot(x - qx, z - qz) < qr + 4.0 for (qx, qz, qr) in keep):
                continue
            if any(math.hypot(x - qx, z - qz) < 6.0 for (qx, qz) in spots):
                continue
            if k % 3 == 0:
                s.put(snow_rock(mat, 0.9 + 0.2 * (k % 3)), x, z, (k * 37) % 360)
            elif k % 3 == 1:
                s.put(pine(mat, 6.0 + (k % 4), "PineSmall"), x, z, (k * 53) % 360)
    return s.finish(_ground(), mat), s


def build_snowy_set(mat):
    objs, _ = build_set(mat)
    return objs


ASSETS = {
    NAME: (build_snowy_set, 150000),
}
