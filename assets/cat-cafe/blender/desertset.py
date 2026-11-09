"""The Desert (Tier 6, Sunstone Cafe; tier6-7-areas.md sections 3 and 4): a long rectangle, 150 x 560 for the wild
part, with the camp (CatCafe_Camp_Desert, camps.py) 30 more across its -Z end, outside it, as on every F85 area.

  CatCafe_Desert_Set   the wild part dressed, in area space (areakit): place it at the area's centre on its floor,
                       camp side -Z, like every set (WorldBuilder turns it 180, its camp on the north edge). Walls at
                       x +-75 and z +-280 (Config.World's DesertWidth 150, DesertDepth 560); the way in is the 24 stud
                       opening (CampOpeningWidth) at x 0 on z -280.

No grass anywhere (section 3): the whole floor is sand, the paths packed sand and flagstones, and the edges dunes,
red mesas and broken sandstone walls 11 to 16 high. Every blocker stands taller than a jump (about 7.2) with a
`_Barrier` BLOCK_OVER over its top, and none runs wall to wall, so the way on is a short walk round an end. The
zones, camp first (the Oasis Camp is the camp set's):

  z -276 to -110   the Dune Sea: two dune ridges 10 to 11 high cross the width as islands (z -215: x -54 to -12 and
                   16 to 52; z -150: x -40 to 10 and 34 to the east wall), low walkable dune humps on the trail, sand
                   ripples, half buried pots and old crates
  z -110 to -20    the Red Canyon: two red rock masses 20 high (x -71.5 to -9 and 9 to 54, strata bands, rock faces)
                   leave the slot canyon 18 wide up the middle, a side alcove off each wall of it, and a side passage
                   17.5 wide along the east wall; a 30 high barrier over each mass
  z -20 to 150     the Mirage Flats: a pan of cracked clay, sunk between sandstone terraces (two steps of 1.2 up to
                   the walls, ramps here and there), the only open sightlines; a mesa ridge 11 high as two islands
                   at z 60 (x -40 to -6 and 18 to 44), a broken caravan, striped shade canopies
  z 132 to 136     a broken sandstone wall 9.6 high, one island x -20 to 24 with a column at each end
  z 150 to 276     the Sunken Pyramid: a courtyard of flagstones and broken obelisks before a stepped pyramid half
                   sunk in sand (five tiers of 2.8 to 14, a stair of 1.4 steps up its camp face, a cat shrine on
                   top); the deep zone where Mythicals stay

The way, camp to pyramid: the packed sand trail between the first ridge's islands, east round the second ridge's
middle gap, up the slot canyon, across the flats between the mesa's islands, round the broken wall's east end and
up the courtyard to the pyramid's stair.

Points (manifest points_roblox): [x, y, z, zone], zone "near" (z < 0) or "deep". The five rescue spots are built in
(section 4: no cactus, nothing sharp), each with its piece's turn as a fifth number:
  trap_sand_dune x2         a ring of sand round the spot, so a cat there is in it up to its chest (the spot is the
                            cat's, on the floor at the ring's middle)
  trap_clay_urn x2          a big clay urn tipped on its side, its mouth toward the piece's local +X (as the Woods'
                            hollow log), the spot the urn's middle on the floor
  trap_collapsed_canopy     a striped canopy fallen off its poles, the cloth sagging over the spot, its open side
                            toward the piece's local -Z
Four of the five are deep and none is within 100 studs of the camp.
"""

import math

from mathutils import Matrix, Vector

from areakit import PI, Set, turned
from common import RB, Builder
from woodsset import _dist_seg, _path, bl

NAME = "CatCafe_Desert_Set"
N = "CatCafe_Desert_"
HALF_X, HALF_Z = 75.0, 280.0            # WorldBuilder's walls at +-75, +-280 (DesertWidth 150, DesertDepth 560)
WALL_D = 3.0
IN_X, IN_Z = HALF_X - 0.5 - WALL_D, HALF_Z - 0.5 - WALL_D       # 71.5, 276.5
GATE_HALF = 12.0                        # CampOpeningWidth 24
BARRIER_H = 30.0
BLOCK_OVER = 1.0
TRAIL_W = 7.0

# the palette (section 4): sand, sandstone, canyon red, oasis teal, the canopies' stripes in the rarity colours
SAND, SAND_DUNE, SAND_DARK = "fur_oat", "fur_dune", "treat_tan"
STONE, STONE_LIGHT, STONE_DARK = "fur_caramel", "paving_tan", "fur_latte"
RED, RED_LIGHT, RED_DARK = "fur_copper", "terracotta", "fur_russet"
CLAY, CRACK = "fur_latte", "fur_hazel"
PATH = "paving_tan"
STRIPES = ("rarity_common", "rarity_rare", "rarity_epic", "rarity_legend", "rarity_mythic")

DUNE_A_Z, ISLE_A = -215.0, [(-54.0, -12.0), (16.0, 52.0)]
DUNE_B_Z, ISLE_B = -150.0, [(-40.0, 10.0), (34.0, IN_X)]
DUNE_TOP = 11.0
CANYON_Z0, CANYON_Z1 = -110.0, -20.0
SLOT_HALF = 9.0                         # the slot canyon, 18 wide
EAST_MASS = 54.0                        # the east mass ends here; the side passage beyond, to the wall
CANYON_H = 20.0
ALCOVES = ((-1, -78.0), (1, -48.0))     # (side, z): a 10 x 10 alcove into each wall of the slot
FLATS_Z0, FLATS_Z1 = -16.0, 146.0
PAN_X = 50.0                            # the clay pan between the terraces
TERRACE_X, TERRACE_H = 58.0, 1.2        # the upper step from |x| 58
MESA_Z, ISLE_M = 60.0, [(-40.0, -6.0), (18.0, 44.0)]
MESA_TOP = 11.0
RUIN_Z, ISLE_R = 134.0, [(-20.0, 24.0)]
RUIN_H = 9.6
COURT = (0.0, 184.0)
PYRAMID = (0.0, 234.0)
PYR_BASE, PYR_STEP, PYR_TIERS = 46.0, 2.8, 5
PYR_TOP = PYR_STEP * PYR_TIERS          # 14
STAIR_W, STAIR_OUT = 8.0, 4.5           # the pyramid's stair, and how far it starts in front of the base

TRAIL = [(0, -IN_Z), (0, -246), (2, -226), (2, -204), (-8, -186), (12, -170), (22, -160), (22, -140), (6, -124),
         (0, -112), (0, -22), (4, -4), (6, 20), (6, 44), (6, 76), (18, 100), (34, 118), (34, 146), (20, 162),
         (0, 176), (0, PYRAMID[1] - PYR_BASE / 2 - STAIR_OUT - 1.0)]
SIDE = [(62.0, -104.0), (63.0, -60.0), (62.0, -24.0)]       # the canyon's side passage, packed sand too


def near_trail(x, z):
    d = 1e9
    for pts in (TRAIL, SIDE):
        for a, b in zip(pts, pts[1:]):
            d = min(d, _dist_seg((x, z), a, b))
    return d


def trail_length():
    return sum(math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(TRAIL, TRAIL[1:]))


def _spot(s, label, x, z, y=0.0, turn=None):
    p = [round(x, 2), round(y, 2), round(z, 2), "deep" if z > 0 else "near"]
    if turn is not None:
        p.append(turn)
    s.points.setdefault(label, []).append(p)


# ------------------------------------------------------------------------------------------------- ground --
def _ground():
    """Sand over the whole floor (no plate shows, no grass), the trail of packed sand, the clay pan and its cracks,
    the courtyard's flagstones, and sand ripples on the dune sea."""
    g = Builder()
    g.box_base((0, 0, 0), (2 * HALF_X, 2 * HALF_Z, 0.03), SAND, bevel=False)
    _path(g, TRAIL, TRAIL_W, PATH, 0.07)
    _path(g, SIDE, 5.0, PATH, 0.07)
    x, y, _ = bl(0, (FLATS_Z0 + FLATS_Z1) / 2)
    g.box_base((x, y, 0), (2 * PAN_X, FLATS_Z1 - FLATS_Z0, 0.05), CLAY, bevel=False)        # the clay pan
    for k in range(26):                                                                       # its cracks
        cx = -44 + (k * 37) % 88
        cz = FLATS_Z0 + 6 + (k * 53) % (FLATS_Z1 - FLATS_Z0 - 12)
        if near_trail(cx, cz) < TRAIL_W / 2 + 1.5:
            continue
        for j in range(3):
            a = (k * 1.7 + j * 2.1) % PI
            L = 3.5 + (k + j) % 3
            px, pz = cx + 1.8 * j * math.cos(k + j), cz + 1.8 * j * math.sin(k + j)
            x, y, _ = bl(px, pz)
            g.box_base((x, y, 0), (L, 0.18, 0.09), CRACK, bevel=False, rot=(a, "Z"))
    cx, cz = COURT
    x, y, _ = bl(cx, cz)
    g.box_base((x, y, 0), (52, 40, 0.05), STONE_LIGHT, bevel=False)                          # the courtyard
    for i in range(8):
        for j in range(6):
            if (i * 3 + j * 5) % 7 == 0:
                continue                                                                        # broken flags
            fx, fz = cx - 22.75 + i * 6.5, cz - 16.25 + j * 6.5
            x, y, _ = bl(fx, fz)
            g.box_base((x, y, 0), (6.1, 6.1, 0.1 + 0.02 * ((i + j) % 2)), (STONE_LIGHT, "paving_sand")[(i + j) % 2],
                       bevel=False)
    for k in range(34):                                                                       # ripples
        rx = -64 + (k * 41) % 128
        rz = -268 + (k * 71) % 150
        if near_trail(rx, rz) < TRAIL_W / 2 + 1.0:
            continue
        if abs(rz - DUNE_A_Z) < 8 or abs(rz - DUNE_B_Z) < 8:
            continue
        for j in range(3):
            x, y, _ = bl(rx, rz + 1.1 * j)
            g.box_base((x, y, 0), (5.0 - j, 0.3, 0.1 + 0.02 * j), SAND_DARK, bevel=False,
                       rot=(0.25 * math.sin(k), "Z"))
    return g


# -------------------------------------------------------------------------------------------------- walls --
def _seg_dune(b, L, k):
    """A sand bank: a core 11 high, one long soft dune leaning out of it into the area, a crest line along its top."""
    H = 11.0 + 1.2 * (k % 2)
    b.box_base((0, 1.8, 0), (L, 2.4, H), SAND_DUNE, bevel=False)
    b.ico((0.6 * (k % 3 - 1), 0.6, 2.0), 1.0, SAND_DUNE, subdivisions=2, scale=(L * 0.62, 3.6, H - 1.6))
    b.ico((-0.2 * L * ((k % 2) - 0.5), 1.4, H - 0.9), 1.0, SAND, subdivisions=2, scale=(L * 0.42, 1.4, 1.2))


def _seg_mesa(b, L, k):
    """A red mesa face 16 high: the cliff, strata bands standing out of it, fluted rock and a sandstone cap."""
    H = 15.0 + 1.5 * (k % 2)
    b.box_base((0, 1.7, 0), (L, 2.6, H), RED, bevel=False)
    for j, (z, sw) in enumerate(((3.2, RED_LIGHT), (7.4, RED_DARK), (11.2, RED_LIGHT))):
        b.box((0, 0.3, z), (L, 0.4, 0.9 + 0.2 * j), sw, bevel=False)
    _place_face(b, _buttresses(L, k, H - 1.0), (0, 0.4), 0.0)
    b.box_base((0, 1.5, H), (L + 0.2, 3.2, 0.7), STONE, bevel=False)


def _seg_ruin(b, L, k):
    """A broken sandstone wall 11 high: block coursing, a broken top in steps, sand drifted at its foot."""
    H = 10.5 + 0.8 * (k % 2)
    b.box_base((0, 1.5, 0), (L, 2.4, H - 2.0), STONE, bevel=False)
    n = max(2, round(L / 3.2))
    for i in range(n):                                                     # the broken top, block by block
        x = -L / 2 + (i + 0.5) * L / n
        h = 2.0 - 1.2 * ((i * 5 + k) % 3 == 0) + 0.04 * (i % 2)
        b.box_base((x, 1.5, H - 2.0), (L / n - 0.1, 2.4, h), (STONE, STONE_DARK)[i % 2], bevel=False)
    for z in (1.6, 3.4, 5.2, 7.0):                                         # coursing
        b.box((0, 0.27, z), (L, 0.06, 0.12), STONE_DARK, bevel=False)
    for i in range(max(1, round(L / 9.0))):                                # drifts
        x = -L / 2 + (i + 0.5) * L / max(1, round(L / 9.0))
        b.ico((x, 0.2, 0.4), 3.0, SAND_DUNE, subdivisions=1, scale=(1.4, 0.7, 0.55))


SEGMENTS = {"dune": _seg_dune, "mesa": _seg_mesa, "ruin": _seg_ruin}


def wall_segment(mat, kind, L, k=0):
    """One wall run L long along local x, its face at y 0 (facing -Y, into the area) and its back at WALL_D."""
    b = Builder()
    SEGMENTS[kind](b, L, k)
    return [b.finalize(N + "Wall" + kind.capitalize(), mat)]


def spire(mat, h=18.0):
    """A sandstone rock spire in the wall line between two runs, standing over them."""
    b = Builder()
    for j, (r, z0, z1, sw) in enumerate(((2.6, 0, 7, STONE), (2.1, 7, 13, STONE_DARK), (1.6, 13, h, STONE))):
        b.box_base((0.2 * (j % 2), WALL_D / 2, z0), (2 * r, 2 * r, z1 - z0 + 0.05 * j), sw, bevel=False)
    b.box_base((0, WALL_D / 2, h), (3.8, 3.8, 0.7), RED_LIGHT, bevel=False)                    # its cap
    b.ico((0, 0.4, 0.6), 2.2, SAND_DUNE, subdivisions=1, scale=(1.5, 0.8, 0.5))
    return [b.finalize(N + "Spire", mat)]


def _run(s, mat, kinds, n, length, place, seed):
    L = (length - (n - 1) * 3.2) / n
    for i in range(n):
        t = i * (L + 3.2) + L / 2
        s.put(wall_segment(mat, kinds[i % len(kinds)], L, i + seed), *place(t))
        if i < n - 1:
            s.put(spire(mat, 16.0 + 2.0 * ((i + seed) % 3)), *place(t + L / 2 + 1.6))


def low_wall(mat, L):
    """The camp side: an adobe wall 3.6 high with a coping and clay pots on it, so the camp shows over it."""
    b = Builder()
    b.box_base((0, 1.0, 0), (L, 1.6, 3.2), STONE, bevel=False)
    b.box_base((0, 1.0, 3.2), (L + 0.2, 1.9, 0.4), STONE_LIGHT, bevel=False)
    n = max(1, round(L / 12.0))
    for i in range(n):
        x = -L / 2 + (i + 0.5) * L / n
        b.cyl_base((x, 1.0, 3.6), 0.55, 0.9, RED_LIGHT, segments=10, radius2=0.4)
        b.cyl_base((x, 1.0, 4.5), 0.42, 0.18, RED, segments=10, bevel=False)
    return [b.finalize(N + "LowWall", mat)]


def _walls(s, mat):
    """Dune banks, red mesas and broken sandstone walls just inside WorldBuilder's walls, rock spires between, the
    mesas along the canyon and the ruin round the pyramid; the camp side a low adobe wall either side of the way in;
    a barrier all round but the way in."""
    far = ("ruin", "mesa", "ruin", "mesa", "ruin")
    side = ("dune", "dune", "ruin", "dune", "mesa", "mesa", "mesa", "dune", "ruin", "dune", "dune", "ruin", "mesa",
            "ruin", "ruin")                                               # camp end first
    _run(s, mat, far, 5, 2 * IN_X, lambda t: (-IN_X + t, IN_Z, 0), 0)
    _run(s, mat, side, 15, 2 * IN_Z, lambda t: (IN_X, -IN_Z + t, 90), 1)
    _run(s, mat, side, 15, 2 * IN_Z, lambda t: (-IN_X, -IN_Z + t, -90), 2)
    for sx in (-1, 1):
        s.put(spire(mat, 20.0), sx * (IN_X - 2.0), IN_Z - 2.0, 45 * sx)                      # far corners
        s.put(spire(mat, 14.0), sx * (IN_X - 2.0), -IN_Z + 2.0, 135 * sx)                    # camp corners
        L = IN_X - GATE_HALF - 4.5
        s.put(low_wall(mat, L), sx * (GATE_HALF + 0.5 + L / 2), -IN_Z, 180)
        s.put(lamp(mat), sx * (GATE_HALF + 2.0), -IN_Z + 2.0, 0)  # either side of the way in
    bar = Builder()
    ox = IN_X + WALL_D
    bar.box_base((0, IN_Z + WALL_D / 2, 0), (2 * ox, WALL_D, BARRIER_H), "offwhite", bevel=False)               # far
    for sx in (-1, 1):
        bar.box_base((sx * (IN_X + WALL_D / 2), 0, 0), (WALL_D, 2 * IN_Z, BARRIER_H), "offwhite", bevel=False)  # sides
        bar.box_base((sx * (GATE_HALF + ox) / 2, -(IN_Z + WALL_D / 2), 0), (ox - GATE_HALF, WALL_D, BARRIER_H),
                     "offwhite", bevel=False)                                                                 # camp
    s.put([bar.finalize(N + "Walls_Barrier", mat)], 0, 0, 0)


# -------------------------------------------------------------------------------------------- the blockers --
def _dune_ridge(s, mat, z, runs):
    """A dune ridge (runs, x0 to x1), taller than a jump: long soft dunes, the windward one toward the camp lower and
    longer, the crest a sharper line about 11 up, the ends tailing off into the sand. A barrier BLOCK_OVER over the
    crest on each run."""
    b, bar = Builder(), Builder()
    for k, (a0, a1) in enumerate(runs):
        L = a1 - a0
        x, y, _ = bl((a0 + a1) / 2, z)
        b.box_base((x, y, 0), (L - 6.0, 4.0, DUNE_TOP - 2.5), SAND_DUNE, bevel=False)         # the core
        n = max(1, round(L / 20.0))
        step = L / n
        for i in range(n):
            j = i + 3 * k
            c = a0 + (i + 0.5) * step
            x, y, _ = bl(c, z - 1.0)
            b.ico((x, y, 0.8), 1.0, (SAND_DUNE, SAND)[j % 2], subdivisions=2,
                  scale=(step * 0.66, 5.6, DUNE_TOP - 1.8 - 0.6 * (j % 2)))                     # the dune
            x, y, _ = bl(c + 0.1 * step * (1 if j % 2 else -1), z + 0.6)
            b.ico((x, y, DUNE_TOP - 1.3), 1.0, SAND, subdivisions=2, scale=(step * 0.44, 1.5, 1.3))   # its crest
            x, y, _ = bl(c - 0.15 * step, z - 4.4)
            b.ico((x, y, 0.2), 1.0, SAND_DUNE, subdivisions=1, scale=(step * 0.5, 3.0, 2.4))        # windward foot
        for e, sgn in ((a0, 1), (a1, -1)):                                        # the ends tail off
            if abs(abs(e) - IN_X) < 1:
                continue
            x, y, _ = bl(e + sgn * 3.5, z)
            b.ico((x, y, 0.4), 1.0, SAND_DUNE, subdivisions=1, scale=(5.0, 4.6, 4.2))
        x, y, _ = bl((a0 + a1) / 2, z)
        bar.box_base((x, y, 0), (L, 11.0, DUNE_TOP + BLOCK_OVER), "offwhite", bevel=False)
    s.put([b.finalize(N + "DuneRidge", mat), bar.finalize(N + "DuneRidge_Barrier", mat)], 0, 0, 0)


def _hump(s, mat, x, z, w=TRAIL_W + 4.0):
    """A low sand hump the trail climbs over (a height change, section 3): up 1.6 over 6, flat 4, down over 6."""
    b = Builder()
    H = 1.6
    for sgn in (-1, 1):
        b.wedge((0, sgn * 5.0, H / 2), (w, 6.0, H), SAND_DUNE, bevel=False, rot=(0 if sgn > 0 else PI, "Z"))
    b.box_base((0, 0, 0), (w, 4.02, H), SAND_DUNE, bevel=False)
    b.ico((-w / 2, 0, 0.6), 2.4, SAND, subdivisions=1, scale=(1.0, 2.6, 0.5))
    b.ico((w / 2, 0, 0.6), 2.4, SAND, subdivisions=1, scale=(1.0, 2.6, 0.5))
    s.put([b.finalize(N + "Hump", mat)], x, z, 0)


def _rock_mass(b, bar, x0, x1, z0, z1, cuts, seed):
    """A red rock mass from x0 to x1, z0 to z1 (area), CANYON_H high, with cut-out alcoves (x0, x1, z0, z1): its
    blocks, strata bands standing out of every face, rock faces at the foot and up the top, a sandstone cap."""
    # split the footprint into blocks round the alcoves
    blocks = [(x0, x1, z0, z1)]
    for (cx0, cx1, cz0, cz1) in cuts:
        out = []
        for (bx0, bx1, bz0, bz1) in blocks:
            if cx1 <= bx0 or cx0 >= bx1 or cz1 <= bz0 or cz0 >= bz1:
                out.append((bx0, bx1, bz0, bz1))
                continue
            if cz0 > bz0:
                out.append((bx0, bx1, bz0, cz0))
            if cz1 < bz1:
                out.append((bx0, bx1, cz1, bz1))
            if cx0 > bx0:
                out.append((bx0, cx0, max(bz0, cz0), min(bz1, cz1)))
            if cx1 < bx1:
                out.append((cx1, bx1, max(bz0, cz0), min(bz1, cz1)))
        blocks = out
    for k, (bx0, bx1, bz0, bz1) in enumerate(blocks):
        H = CANYON_H - 1.5 * ((k + seed) % 2)
        x, y, _ = bl((bx0 + bx1) / 2, (bz0 + bz1) / 2)
        w, d = bx1 - bx0, bz1 - bz0
        b.box_base((x, y, 0), (w, d, H), RED, bevel=False)
        for j, (zz, sw) in enumerate(((3.0, RED_LIGHT), (7.6, RED_DARK), (12.2, RED_LIGHT), (16.4, STONE))):
            b.box((x, y, zz), (w + 0.6, d + 0.6, 0.9 + 0.15 * j), sw, bevel=False)           # strata
        b.box_base((x, y, H), (w + 0.8, d + 0.8, 0.6 + 0.05 * (k % 2)), STONE, bevel=False)  # the cap
        bar.box_base((x, y, 0), (w, d, BARRIER_H), "offwhite", bevel=False)
    return blocks


def _buttresses(L, seed, H=CANYON_H):
    """Fluted rock along a face L long (local x, the face at y 0 facing -Y): buttresses of red rock of varied width,
    depth and height, each a hair off square, and boulders at the foot: a list of (centre, size, swatch, turn) in the
    face's own space for _place_face (turn None: a boulder)."""
    out = []
    x = -L / 2
    i = 0
    while x < L / 2 - 0.5:
        w = min(2.2 + 1.6 * (((i * 7 + seed) % 5) / 4), L / 2 - x)
        dep = 0.7 + 0.9 * (((i * 3 + seed) % 4) / 3)
        h = H * (0.55 + 0.4 * (((i * 5 + seed * 3) % 6) / 5))
        sw = (RED, RED_LIGHT, RED_DARK, RED)[(i + seed) % 4]
        out.append(((x + w / 2, -dep / 2 + 0.3, h / 2), (w + 0.25, dep + 0.6, h), sw, 0.04 * ((i * 3 + seed) % 3 - 1)))
        if (i + seed) % 3 == 0:
            r = 1.0 + 0.4 * ((i + seed) % 2)
            out.append(((x + w / 2, -dep - r * 0.6, r * 0.55), (r * 2.2, r * 1.8, r * 1.3), STONE_DARK if i % 2 else
                        RED_LIGHT, None))
        x += w
        i += 1
    return out


def _place_face(b, items, origin, yaw):
    """Places _buttresses' items: origin the face's middle (Builder), yaw the face's turn about Z (Builder)."""
    R = Matrix.Rotation(yaw, 3, "Z")
    for (c, size, sw, tw) in items:
        p = R @ Vector(c)
        pos = (origin[0] + p.x, origin[1] + p.y, c[2])
        if tw is None:
            b.ico(pos, 1.0, sw, subdivisions=1, scale=(size[0] / 2, size[1] / 2, size[2] / 2),
                  rot=(yaw + 0.5, "Z"))
        else:
            b.box(pos, size, sw, bevel=False, rot=(yaw + tw, "Z"))


def _rock_faces(b, x0, x1, z, outward, seed=0, H=CANYON_H):
    """Fluted rock along a face that runs along x (area x0 to x1 at depth z, outward the face's normal in z)."""
    L = abs(x1 - x0)
    ox, oy, _ = bl((x0 + x1) / 2, z)
    yaw = 0.0 if outward < 0 else PI                 # Builder -Y is Roblox -Z: a face looking -Z needs no turn
    _place_face(b, _buttresses(L, seed, H), (ox, oy), yaw)


def _rock_faces_x(b, z0, z1, x, outward, seed=0, H=CANYON_H):
    """Fluted rock along a face that runs along z (at area x, outward the normal in x)."""
    L = abs(z1 - z0)
    ox, oy, _ = bl(x, (z0 + z1) / 2)
    yaw = -PI / 2 if outward > 0 else PI / 2         # Roblox +X is Builder -X
    _place_face(b, _buttresses(L, seed, H), (ox, oy), yaw)


def _canyon(s, mat):
    """The Red Canyon: the west mass (x -71.5 to -9) and the east mass (x 9 to 54), the slot canyon between, an alcove
    off each wall of the slot, the side passage east of the east mass, fallen boulders in the slot."""
    b, bar = Builder(), Builder()
    cuts_w, cuts_e = [], []
    for side, z in ALCOVES:
        if side < 0:
            cuts_w.append((-SLOT_HALF - 10.0, -SLOT_HALF, z - 5.0, z + 5.0))
        else:
            cuts_e.append((SLOT_HALF, SLOT_HALF + 10.0, z - 5.0, z + 5.0))
    _rock_mass(b, bar, -IN_X, -SLOT_HALF, CANYON_Z0, CANYON_Z1, cuts_w, 0)
    _rock_mass(b, bar, SLOT_HALF, EAST_MASS, CANYON_Z0, CANYON_Z1, cuts_e, 1)
    # the faces: along the slot (x +-9), the side passage (x 54), the two ends (z -110 and -20)
    for sx, cuts in ((-1, cuts_w), (1, cuts_e)):
        zs = [CANYON_Z0] + [v for (_, _, cz0, cz1) in cuts for v in (cz0, cz1)] + [CANYON_Z1]
        for a, c in zip(zs[0::2], zs[1::2]):
            _rock_faces_x(b, a, c, sx * SLOT_HALF, -sx, seed=2 + sx)
        for (cx0, cx1, cz0, cz1) in cuts:                                 # the alcove's three walls
            back = cx0 if sx < 0 else cx1
            _rock_faces_x(b, cz0 + 0.5, cz1 - 0.5, back, -sx, seed=5)
            _rock_faces(b, cx0, cx1, cz0, 1, seed=6)
            _rock_faces(b, cx0, cx1, cz1, -1, seed=7)
    _rock_faces_x(b, CANYON_Z0, CANYON_Z1, EAST_MASS, 1, seed=8)
    for (a0, a1) in ((-IN_X, -SLOT_HALF), (SLOT_HALF, EAST_MASS)):
        _rock_faces(b, a0, a1, CANYON_Z0, -1, seed=9)
        _rock_faces(b, a0, a1, CANYON_Z1, 1, seed=10)
    s.put([b.finalize(N + "Canyon", mat), bar.finalize(N + "Canyon_Barrier", mat)], 0, 0, 0)
    # fallen boulders and a sandstone arch high over the slot
    for (x, z, r) in ((-6.0, -92.0, 1.6), (6.5, -64.0, 1.3), (-6.5, -36.0, 1.5), (66.0, -84.0, 1.4),
                      (58.5, -40.0, 1.2)):
        s.put(rock(mat, r), x, z, (x * 13) % 360)
    s.put(rock_arch(mat), 0, -66.0, 0)


def rock_arch(mat):
    """A natural sandstone arch from rim to rim of the slot, 15 over the floor."""
    b = Builder()
    w = 2 * SLOT_HALF + 2.0
    for k in range(12):
        t = (k + 0.5) / 12
        a = PI * t
        x = -(w / 2) * math.cos(a)
        z = CANYON_H - 5.5 + 3.0 * math.sin(a)
        b.box((x, 0, z), (w / 12 * 1.6 + 0.4, 3.0 - 0.01 * (k % 2), 1.8 - 0.03 * (k % 2)), (STONE, RED_LIGHT)[k % 2],
              bevel=False,
              rot=(-math.atan2(3.0 * math.cos(a), w / 2 * math.sin(a)), "Y"))      # along the arc
    return [b.finalize(N + "RockArch", mat)]


def _mesa_ridge(s, mat, z, runs):
    """Short red mesas across the flats (runs, x0 to x1), MESA_TOP high: a cliff block with strata and a cap, rock
    faces round its foot, a barrier BLOCK_OVER over the cap."""
    b, bar = Builder(), Builder()
    for k, (a0, a1) in enumerate(runs):
        L = a1 - a0
        x, y, _ = bl((a0 + a1) / 2, z)
        b.box_base((x, y, 0), (L, 7.0, MESA_TOP - 0.6), RED, bevel=False)
        for j, (zz, sw) in enumerate(((2.6, RED_LIGHT), (6.4, RED_DARK))):
            b.box((x, y, zz), (L + 0.6, 7.6, 0.9 + 0.2 * j), sw, bevel=False)
        b.box_base((x, y, MESA_TOP - 0.6), (L + 0.8, 8.2, 0.6), STONE, bevel=False)
        _rock_faces(b, a0, a1, z - 3.5, -1, seed=k, H=MESA_TOP - 1.0)
        _rock_faces(b, a0, a1, z + 3.5, 1, seed=k + 3, H=MESA_TOP - 1.0)
        for e in (a0, a1):
            xx, yy, _ = bl(e, z)
            b.ico((xx, yy, 2.2), 3.4, RED_LIGHT, subdivisions=1, scale=(0.6, 1.0, 0.9))
        bar.box_base((x, y, 0), (L + 1.0, 8.6, MESA_TOP + BLOCK_OVER), "offwhite", bevel=False)
    s.put([b.finalize(N + "MesaRidge", mat), bar.finalize(N + "MesaRidge_Barrier", mat)], 0, 0, 0)


def _terraces(s, mat):
    """The sandstone terraces either side of the clay pan: a step 1.2 up from |x| PAN_X, another to 2.4 from
    TERRACE_X, edged with a darker course, and ramps up to them from the pan."""
    b = Builder()
    z0, z1 = FLATS_Z0, FLATS_Z1
    L = z1 - z0
    for sx in (-1, 1):
        for (xa, h, sw) in ((PAN_X, TERRACE_H, STONE_LIGHT), (TERRACE_X, 2 * TERRACE_H + 0.02, STONE)):
            w = IN_X - xa
            x, y, _ = bl(sx * (xa + w / 2), (z0 + z1) / 2)
            b.box_base((x, y, 0), (w, L, h), sw, bevel=False)
            x, y, _ = bl(sx * (xa + 0.1), (z0 + z1) / 2)
            b.box_base((x, y, h - 0.35), (0.34, L, 0.33), STONE_DARK, bevel=False)            # its edge course
        for zr in (12.0, 104.0):                                                              # ramps
            for (xa, base) in ((PAN_X, 0.0), (TERRACE_X, TERRACE_H)):
                x, y, _ = bl(sx * (xa - 2.0), zr)
                b.wedge((x, y, base + TERRACE_H / 2), (6.0, 4.0, TERRACE_H), STONE_DARK, bevel=False,
                        rot=(PI / 2 * sx, "Z"))
    s.put([b.finalize(N + "Terraces", mat)], 0, 0, 0)


def _ruin_wall(s, mat, z, runs):
    """A broken sandstone wall across the end of the flats (runs, x0 to x1), RUIN_H high with a broken top, a
    column at each end, sand drifted against it, a barrier BLOCK_OVER over the columns."""
    b, bar = Builder(), Builder()
    T = 2.4
    for k, (a0, a1) in enumerate(runs):
        L = a1 - a0
        x, y, _ = bl((a0 + a1) / 2, z)
        b.box_base((x, y, 0), (L, T, RUIN_H - 1.6), STONE, bevel=False)
        n = max(2, round(L / 3.0))
        for i in range(n):
            c = a0 + (i + 0.5) * L / n
            xx, yy, _ = bl(c, z)
            h = 1.6 - 1.0 * ((i * 5) % 4 == 1) + 0.04 * (i % 2)
            b.box_base((xx, yy, RUIN_H - 1.6), (L / n - 0.1, T, h), (STONE, STONE_DARK)[i % 2], bevel=False)
        for zz in (1.6, 3.4, 5.2, 7.0):
            for f in (-T / 2 - 0.03, T / 2 + 0.03):
                xx, yy, _ = bl((a0 + a1) / 2, z + f)
                b.box((xx, yy, zz), (L, 0.06, 0.12), STONE_DARK, bevel=False)
        for e in (a0, a1):                                                     # the columns
            xx, yy, _ = bl(e, z)
            b.cyl_base((xx, yy, 0), 1.9, 1.0, STONE_DARK, segments=12)
            b.cyl_base((xx, yy, 1.0), 1.5, RUIN_H + 0.6, STONE, segments=12)
            b.cyl_base((xx, yy, RUIN_H + 1.6), 1.9, 0.6, STONE_DARK, segments=12, bevel=False)
        for i in range(3):
            c = a0 + (i + 0.5) * L / 3
            for side in (-1, 1):
                xx, yy, _ = bl(c + 2 * side, z + side * 2.2)
                b.ico((xx, yy, 0.5), 3.2, SAND_DUNE, subdivisions=1, scale=(1.5, 0.6, 0.6))
        xx, yy, _ = bl((a0 + a1) / 2, z)
        bar.box_base((xx, yy, 0), (L + 4.0, 4.0, RUIN_H + 2.2 + BLOCK_OVER), "offwhite", bevel=False)
    s.put([b.finalize(N + "RuinWall", mat), bar.finalize(N + "RuinWall_Barrier", mat)], 0, 0, 0)


# ---------------------------------------------------------------------------------------------- the pyramid --
def pyramid(mat):
    """The Sunken Pyramid, its pivot at its base centre, its stair on the camp face (-Z): five sandstone tiers
    PYR_STEP high from PYR_BASE wide, each edged with a darker course, a stair of 1.4 steps up the middle of the
    camp face, a cat shrine on the top (a doorway with a cat's head over it, ears and a gold sun disc), sand drifted
    over the two back corners and the front corners' feet, so it reads half sunk."""
    b = Builder()
    for i in range(PYR_TIERS):
        w = PYR_BASE - 9.0 * i
        z = i * PYR_STEP
        b.box_base((0, 0, z), (w, w, PYR_STEP + 0.02 * (i % 2)), (STONE, STONE_LIGHT)[i % 2], bevel=False)
        b.box_base((0, 0, z + PYR_STEP - 0.4), (w + 0.3, w + 0.3, 0.36), STONE_DARK, bevel=False)
    # the stair, its slope the tiers' (1.4 up for 2.25 on), from the sand STAIR_OUT in front of the base to the top
    for i in range(PYR_TIERS * 2):
        y = -(PYR_BASE / 2) - STAIR_OUT + 2.25 * i + 1.125
        b.box_base((0, y, 0), (STAIR_W, 2.25, 1.4 * (i + 1)), (STONE_LIGHT, STONE)[i % 2], bevel=False)
    for sx in (-1, 1):                                                         # its side walls, a block a tier
        for i in range(PYR_TIERS):
            y = -(PYR_BASE / 2) - STAIR_OUT + 4.5 * i + 2.25
            b.box_base((sx * (STAIR_W / 2 + 0.5), y, 0), (1.0, 4.5, PYR_STEP * (i + 1) + 0.8), STONE_DARK,
                       bevel=False)
    top = PYR_TOP
    tw = PYR_BASE - 9.0 * (PYR_TIERS - 1)                                      # 10 wide on top
    b.box_base((0, 1.5, top), (7.0, 5.0, 5.0), STONE, bevel=False)            # the shrine
    b.box_base((0, 1.5, top + 5.0), (7.6, 5.6, 0.5), STONE_DARK, bevel=False)
    b.box_base((0, -1.02, top), (2.6, 0.1, 3.4), "fur_ink", bevel=False)       # its doorway
    b.box((0, -1.1, top + 4.2), (3.2, 0.2, 1.4), RED_LIGHT, bevel=False)        # the cat's head over it
    for sx in (-1, 1):
        b.pyramid((sx * 1.15, -1.1, top + 4.9), 0.9, 1.0, RED_LIGHT)                          # its ears
        b.box((sx * 0.6, -1.22, top + 4.3), (0.35, 0.06, 0.35), "fur_ink", bevel=False)     # eyes
    b.cyl((0, 1.5, top + 7.0), 1.4, 0.3, "rarity_legend", segments=16, rot=(PI / 2, "X"))    # the sun disc
    b.box_base((0, 1.5, top + 5.5), (0.4, 0.3, 0.6), STONE_DARK, bevel=False)
    for (x, y, r, sx_, sy_, sz_) in ((tw / 2 + 14, tw / 2 + 14, 9.0, 1.3, 1.3, 0.55),
                                     (-(tw / 2 + 14), tw / 2 + 14, 9.0, 1.3, 1.3, 0.55),
                                     (PYR_BASE / 2 - 1, -PYR_BASE / 2 + 2, 5.0, 1.4, 1.0, 0.45),
                                     (-(PYR_BASE / 2 - 1), -PYR_BASE / 2 + 2, 5.0, 1.4, 1.0, 0.45),
                                     (0, PYR_BASE / 2 + 1, 8.0, 2.2, 0.9, 0.5)):
        b.ico((x, y, 0.4), r, SAND_DUNE, subdivisions=2, scale=(sx_, sy_, sz_))             # the drifts
    return [b.finalize(N + "Pyramid", mat)]


def obelisk(mat, h=12.0, broken=False):
    """A sandstone obelisk on a plinth: a tapering shaft in three blocks, carved paw glyphs on its -Z face, a gold
    tip; broken, it stops in a jagged top with its tip lying at its foot."""
    b = Builder()
    b.box_base((0, 0, 0), (3.4, 3.4, 1.0), STONE_DARK, bevel=False)
    hh = h * (0.55 if broken else 1.0)
    for j in range(3):
        w = 2.2 - 0.3 * j
        z0, z1 = 1.0 + (hh - 1.0) * j / 3, 1.0 + (hh - 1.0) * (j + 1) / 3
        b.box_base((0.05 * (j % 2), 0, z0), (w, w, z1 - z0 + 0.02 * j), (STONE, STONE_LIGHT)[j % 2], bevel=False)
    for j in range(3):                                                          # glyphs
        z = 2.6 + 2.2 * j
        if z > hh - 0.8:
            break
        b.cyl((0, -1.13 + 0.1 * j, z), 0.32, 0.08, RED_DARK, segments=8, rot=(PI / 2, "X"), bevel=False)
        for dx in (-0.36, 0, 0.36):
            b.cyl((dx, -1.13 + 0.1 * j, z + 0.45), 0.12, 0.08, RED_DARK, segments=6, rot=(PI / 2, "X"), bevel=False)
    if broken:
        b.box_base((0.3, 0.2, hh), (1.0, 1.2, 0.7), STONE, bevel=False)
        b.box((2.6, -1.4, 0.75), (1.4, 3.6, 1.4), STONE_LIGHT, bevel=False, rot=(0.5, "Z"))   # the fallen tip
        b.pyramid((3.4, -2.9, 0.1), 1.3, 1.2, "rarity_legend", rot=Matrix.Rotation(PI / 2, 3, "X"))
    else:
        b.pyramid((0, 0, hh), 1.6, 1.4, "rarity_legend")
    return [b.finalize(N + "Obelisk" + ("Broken" if broken else ""), mat)]


# --------------------------------------------------------------------------------------------- the pieces --
def pot(mat, r=1.0, swatch=RED_LIGHT):
    """A clay pot half buried in the sand: its belly sunk, the neck and lip out, a sand ring round it."""
    b = Builder()
    b.cyl_base((0, 0, 0), r * 1.1, r * 0.9, swatch, segments=12, radius2=r * 0.7)
    b.cyl_base((0, 0, r * 0.9), r * 0.55, r * 0.35, swatch, segments=10)
    b.cyl_base((0, 0, r * 1.25), r * 0.68, r * 0.16, RED, segments=10, bevel=False)
    b.cyl_base((0, 0, 0), r * 1.6, r * 0.25, SAND_DUNE, segments=12, radius2=r * 1.15, bevel=False)
    return [b.finalize(N + "Pot", mat)]


def crate(mat, tilt=0.0):
    """An old wooden crate sunk a little in the sand, a drift against one side."""
    b = Builder()
    b.box((0, 0, 0.9), (2.2, 2.2, 2.2), "caramel_wood", rot=(tilt, "Y"))
    for z in (0.3, 1.5):
        b.box((0, -1.13, z + 0.1), (2.2, 0.08, 0.3), "dark_wood", bevel=False)
    b.box((0, -1.14, 0.9), (0.3, 0.08, 2.0), "dark_wood", bevel=False, rot=(0.78, "Y"))
    b.ico((1.2, 0.4, 0.2), 1.5, SAND_DUNE, subdivisions=1, scale=(0.9, 1.4, 0.55))
    return [b.finalize(N + "Crate", mat)]


def rock(mat, r=1.4):
    """A sandstone boulder cluster."""
    b = Builder()
    b.ico((0, 0, r * 0.6), r, (STONE, RED_LIGHT)[int(r * 10) % 2], subdivisions=1, scale=(1.2, 1.0, 0.8))
    b.ico((r * 0.9, r * 0.4, r * 0.35), r * 0.55, STONE_DARK, subdivisions=1)
    b.ico((-r * 0.8, -r * 0.3, r * 0.3), r * 0.45, RED, subdivisions=1)
    return [b.finalize(N + "Rock", mat)]


def shrub(mat):
    """A dry desert bush, brown and wiry (the only green is at the oasis)."""
    b = Builder()
    b.ico((0, 0, 0.6), 0.9, CRACK, subdivisions=1, scale=(1.3, 1.1, 0.7))
    for k in range(7):
        a = 2 * PI * k / 7
        b.box((0.7 * math.cos(a), 0.7 * math.sin(a), 0.9), (0.08, 1.1, 0.08), "fur_brown", bevel=False,
              rot=Matrix.Rotation(a, 3, "Z") @ Matrix.Rotation(0.7, 3, "X"))
    return [b.finalize(N + "Shrub", mat)]


def lamp(mat):
    """A brass lantern on a sandstone post, lit at night (_Bulb)."""
    b, bulb = Builder(), Builder()
    b.box_base((0, 0, 0), (0.9, 0.9, 0.5), STONE_DARK, bevel=False)
    b.box_base((0, 0, 0.5), (0.55, 0.55, 4.6), STONE)
    b.box_base((0, 0, 5.1), (1.0, 1.0, 0.15), "brass", bevel=False)
    bulb.box_base((0, 0, 5.25), (0.6, 0.6, 0.8), "lamp_warm", bevel=False)
    for (x, y) in ((-0.36, -0.36), (0.36, -0.36), (-0.36, 0.36), (0.36, 0.36)):
        b.box_base((x, y, 5.25), (0.1, 0.1, 0.8), "brass", bevel=False)
    b.pyramid((0, 0, 6.05), 1.1, 0.6, "brass")
    return [b.finalize(N + "Lamp", mat), bulb.finalize(N + "Lamp_Bulb", mat)]


def canopy(mat, w=6.0, d=5.0):
    """A striped shade canopy on four poles, 4.4 high: the cloth in the rarity colours, scalloped at the front."""
    b = Builder()
    H = 4.4
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.cyl_base((sx * (w / 2 - 0.2), sy * (d / 2 - 0.2), 0), 0.13, H + 0.1, "dark_wood", segments=8)
    n = len(STRIPES)
    for i in range(n):
        x = -w / 2 + (i + 0.5) * w / n
        b.box((x, 0, H + 0.25), (w / n + 0.02, d + 0.4, 0.12 + 0.03 * (i % 2)), STRIPES[i],
              bevel=False, rot=(0.12, "X"))
        b.box((x, -(d / 2 + 0.25), H - 0.1), (w / n - 0.1, 0.08, 0.55), STRIPES[i], bevel=False)   # the scallops
    return [b.finalize(N + "Canopy", mat)]


def wagon(mat):
    """A broken caravan wagon half in the sand: a wooden bed, one wheel off and leaning on it, a torn hoop cover in
    two colours, a crate and pots tumbled out."""
    b = Builder()
    b.box((0, 0, 1.4), (7.0, 3.4, 0.5), "caramel_wood", rot=(0.12, "Y"))
    for sy in (-1, 1):
        b.box((0, sy * 1.6, 2.0), (7.0, 0.25, 1.0), "dark_wood", bevel=False, rot=(0.12, "Y"))
    b.cyl((2.4, -1.95, 1.3), 1.3, 0.3, "dark_wood", segments=12, rot=(PI / 2, "X"))
    b.cyl((2.4, -1.95, 1.3), 0.35, 0.4, "brass", segments=8, rot=(PI / 2, "X"), bevel=False)
    b.cyl((-2.6, 2.1, 1.4), 1.3, 0.3, "dark_wood", segments=12, rot=Matrix.Rotation(PI / 2, 3, "X") @
          Matrix.Rotation(0.5, 3, "Y"))                                      # the loose wheel, leaning
    for k in range(3):                                                        # the hoops, the cover over two
        x = -2.4 + 2.4 * k
        for j in range(5):
            a = PI * (j + 0.5) / 5
            b.box((x, -1.6 * math.cos(a), 2.4 + 1.6 * math.sin(a) - 0.3 * x / 7), (0.15, 1.1, 0.15), "fur_brown",
                  bevel=False, rot=(a - PI / 2, "X"))
    for j in range(5):
        a = PI * (j + 0.5) / 5
        b.box((-1.2, -1.75 * math.cos(a), 2.5 + 1.75 * math.sin(a)), (2.6, 1.15, 0.1), ("cream", STRIPES[3])[j % 2],
              bevel=False, rot=(a - PI / 2, "X"))
    b.box((-4.4, 0, 0.9), (2.0, 0.3, 0.3), "dark_wood", bevel=False, rot=(0.4, "Y"))           # the shaft
    b.ico((0, 2.4, 0.3), 3.0, SAND_DUNE, subdivisions=1, scale=(1.6, 0.6, 0.45))
    return [b.finalize(N + "Wagon", mat)]


def palm_stump(mat):
    """A dead palm stump and fronds (dry, brown), for the flats."""
    b = Builder()
    for j in range(4):
        b.cyl_base((0.08 * j, 0, j * 0.9), 0.5 - 0.04 * j, 0.92, ("fur_hazel", "fur_brown")[j % 2], segments=8)
    for k in range(4):
        a = 2 * PI * k / 4 + 0.4
        b.box((1.6 * math.cos(a), 1.6 * math.sin(a), 0.2), (0.4, 3.0, 0.08), CRACK, bevel=False,
              rot=(a + PI / 2, "Z"))
    return [b.finalize(N + "PalmStump", mat)]


def signpost(mat):
    """A wooden signpost with three arrow boards (the Woods' shape), a sand drift at its foot."""
    rb = RB()
    rb.box((0, 3.5, 0), (0.4, 7.0, 0.4), "dark_wood")
    for i, (w, ang) in enumerate(((3.4, 160), (4.2, -15), (4.6, 20))):
        y = 6.2 - i * 1.3
        rot = Matrix.Rotation(math.radians(ang), 3, "Y")
        c = rot @ Vector((w / 2 - 0.2, 0, -0.25))
        rb.box((c.x, y, c.z), (w, 0.9, 0.2), ("caramel_wood", "fur_hazel")[i % 2], rot=rot)
        tip = rot @ Vector((w - 0.2, 0, -0.25))
        rb.box((tip.x, y, tip.z), (0.64, 0.64, 0.2), ("caramel_wood", "fur_hazel")[i % 2],
               rot=rot @ Matrix.Rotation(math.radians(45), 3, "Z"))
    rb.ball((0, 0.1, 0), 1.2, SAND_DUNE, scale=(1.4, 0.4, 1.2))
    return [rb.finalize(N + "Signpost", mat)]


# ------------------------------------------------------------------------------- the oasis (the camp's) --
def palm(mat, h=10.0, lean=0.18):
    """A date palm, the only green in the Desert (section 4): a ringed trunk curving up and over, leaning toward
    local -X, eight drooping fronds in two greens and a bunch of dates under them."""
    b = Builder()
    n = 7
    x = 0.0
    for j in range(n):
        z0 = h * j / n
        t = j / (n - 1)
        x = lean * h * t * t
        b.cyl_base((-x, 0, z0), 0.56 - 0.03 * j, h / n + 0.04, ("fur_hazel", "fur_brown")[j % 2], segments=8,
                   radius2=0.5 - 0.03 * j)
    top = (-x, 0, h + 0.2)
    b.ico(top, 0.75, "fur_brown", subdivisions=1)
    for k in range(8):
        a = 2 * PI * k / 8 + 0.2
        ca, sa = math.cos(a), math.sin(a)
        for i, (r, dz, pitch) in enumerate(((1.1, 0.2, 0.25), (2.6, -0.2, -0.25), (3.9, -1.0, -0.7))):
            c = (top[0] + r * ca, top[1] + r * sa, top[2] + dz)
            R = Matrix.Rotation(a, 3, "Z") @ Matrix.Rotation(-pitch, 3, "Y")
            b.box(c, (1.5, 0.9 - 0.2 * i, 0.12), ("leaf_green", "leaf_dark")[(k + i) % 2], bevel=False, rot=R)
    for k in range(5):                                                              # the dates
        a = 2 * PI * k / 5
        b.ico((top[0] + 0.55 * math.cos(a), top[1] + 0.55 * math.sin(a), top[2] - 0.8), 0.24, "fur_toffee",
              subdivisions=1)
    return [b.finalize(N + "Palm", mat)]


def oasis_pool(mat, r=7.5):
    """The oasis pool: oasis teal water in a rim of sandstone blocks, reeds in clumps at its edge, flat stones to
    step on, a sand beach round it."""
    from areakit import ring_blocks
    b, water = Builder(), Builder()
    b.cyl_base((0, 0, 0), r + 2.4, 0.06, SAND_DUNE, segments=24, bevel=False)
    ring_blocks(b, 0, 0, 0, r + 0.9, 1.1, 0.7, STONE, n=28)
    water.cyl_base((0, 0, 0.1), r, 0.42, "sign_teal", segments=24, bevel=False)
    for k in range(5):                                                              # reeds
        a = 2 * PI * k / 5 + 0.5
        cx, cy = (r - 0.6) * math.cos(a), (r - 0.6) * math.sin(a)
        for j in range(4):
            dx, dy = 0.35 * math.cos(j * 1.7), 0.35 * math.sin(j * 1.7)
            b.box_base((cx + dx, cy + dy, 0.1), (0.12, 0.12, 2.0 + 0.3 * (j % 3)), ("leaf_dark", "fur_fern")[j % 2],
                       bevel=False, rot=Matrix.Rotation(0.12 * (j - 1.5), 3, "X"))
            if j % 2 == 0:
                b.box_base((cx + dx, cy + dy, 2.0 + 0.3 * (j % 3)), (0.2, 0.2, 0.5), "fur_brown", bevel=False)
    for (x, y) in ((r + 0.2, -2.5), (r - 0.3, 2.8)):                                # stepping stones on the rim
        b.cyl_base((x, y, 0.7), 0.8, 0.12, STONE_LIGHT, segments=10, bevel=False)
    return [b.finalize(N + "OasisPool", mat), water.finalize(N + "OasisPool_Water", mat)]


def well(mat):
    """The camp's stone well: a round sandstone wall 2.4 high with a dark shaft, two posts, a beam with a winch, a
    little striped roof and a bucket on the rim."""
    b = Builder()
    b.cyl_base((0, 0, 0), 2.0, 2.4, STONE, segments=14)
    b.cyl_base((0, 0, 2.4), 2.15, 0.3, STONE_DARK, segments=14, bevel=False)
    b.cyl_base((0, 0, 2.45), 1.45, 0.3, "fur_ink", segments=14, bevel=False)
    for sx in (-1, 1):
        b.box_base((sx * 1.8, 0, 2.4), (0.3, 0.3, 3.4), "dark_wood", bevel=False)
    b.cyl((0, 0, 5.0), 0.2, 3.9, "caramel_wood", segments=8, rot=(PI / 2, "Y"))
    b.box((0, 0, 4.0), (0.05, 0.05, 1.9), "fur_hazel", bevel=False)
    b.cyl_base((0, 0, 2.95), 0.32, 0.5, "metal", segments=8, radius2=0.38)
    for sy in (-1, 1):
        for i, sw in enumerate(STRIPES[:4]):
            x = -1.95 + (i + 0.5) * 3.9 / 4
            b.box((x, sy * 0.85, 6.1), (3.9 / 4 + 0.02, 1.9, 0.12), sw, bevel=False, rot=(sy * 0.55, "X"))
    b.cyl_base((2.4, -1.0, 0), 0.4, 0.6, "caramel_wood", segments=8, radius2=0.45)       # a spare bucket
    return [b.finalize(N + "Well", mat)]


# --------------------------------------------------------------------------------------- the rescue traps --
def trap_sand_dune(mat):
    """A cat stuck in the sand up to its chest: a ring of sand mounds 1.2 high round the spot (radius 1.3 open in
    the middle), spilled sand round it, a paw print trail leading in from local -Z."""
    b = Builder()
    for k in range(10):
        a = 2 * PI * k / 10
        r = 1.9 + 0.15 * (k % 2)
        b.ico((r * math.cos(a), r * math.sin(a), 0.35), 1.15, (SAND_DUNE, SAND)[k % 2], subdivisions=1,
              scale=(1.0, 1.0, 0.75 + 0.05 * (k % 3)))
    b.cyl_base((0, 0, 0), 3.6, 0.3, SAND_DUNE, segments=16, radius2=2.6, bevel=False)
    for i in range(3):
        b.cyl_base((0.35 * (-1) ** i, -4.2 - 1.2 * i, 0), 0.22, 0.05, SAND_DARK, segments=8, bevel=False)
    return [b.finalize(N + "TrapSandDune", mat)]


def trap_clay_urn(mat):
    """A big clay urn tipped on its side, its mouth toward local +X (a cat head first inside, as the Woods' hollow
    log): the belly 3.6 long, a neck and lip, bands, half sunk in a drift, a shard broken off its back."""
    b = Builder()
    R = Matrix.Rotation(PI / 2, 3, "Y")
    b.cyl((-0.4, 0, 1.25), 1.35, 2.6, RED_LIGHT, segments=14, rot=R)
    b.cyl((1.25, 0, 1.25), 1.35, 0.8, RED_LIGHT, segments=14, rot=R, radius2=0.95)
    b.cyl((1.85, 0, 1.25), 0.95, 0.5, RED_LIGHT, segments=14, rot=R)
    b.ring((2.12, 0, 1.25), 1.08, 0.3, 0.2, RED, segments=14, rot=(PI / 2, "Y"))
    b.cyl((2.1, 0, 1.25), 0.8, 0.12, "fur_ink", segments=14, rot=R, bevel=False)                  # the dark mouth
    for x in (-1.2, 0.4):
        b.cyl((x, 0, 1.25), 1.42, 0.22, RED_DARK, segments=14, rot=R, bevel=False)                 # bands
    b.ico((-1.4, 0, 0.1), 1.8, SAND_DUNE, subdivisions=1, scale=(1.3, 1.2, 0.5))
    b.box((-2.6, 1.0, 0.15), (0.8, 0.6, 0.12), RED_LIGHT, bevel=False, rot=(0.6, "Z"))             # the shard
    return [b.finalize(N + "TrapClayUrn", mat)]


def trap_collapsed_canopy(mat):
    """A striped canopy fallen off its poles: two poles still standing at the back, two down, the cloth sagging from
    the back poles to the sand over the spot, open toward local -Z."""
    b = Builder()
    w, d = 6.0, 5.0
    for sx in (-1, 1):
        b.cyl_base((sx * (w / 2 - 0.2), d / 2 - 0.2, 0), 0.13, 3.8, "dark_wood", segments=8)
        b.cyl((sx * (w / 2 - 0.6), -d / 2 + 0.6, 0.15), 0.13, 4.4, "dark_wood", segments=8,
              rot=Matrix.Rotation(PI / 2, 3, "X") @ Matrix.Rotation(sx * 0.3, 3, "Y"))           # fallen
    n = len(STRIPES)
    tilt = math.atan2(3.0, d)
    for i in range(n):
        x = -w / 2 + (i + 0.5) * w / n
        b.box((x, 0.3, 2.15 - 0.04 * (i % 2)), (w / n + 0.02, d / math.cos(tilt) - 0.4, 0.12), STRIPES[i],
              bevel=False, rot=(-tilt, "X"))
        b.box((x, -1.9, 0.5), (w / n - 0.1, 0.1, 0.7), STRIPES[i], bevel=False, rot=(0.25, "X"))  # the hem on the sand
    b.ico((0, 2.8, 0.3), 2.0, SAND_DUNE, subdivisions=1, scale=(1.6, 0.6, 0.4))
    return [b.finalize(N + "TrapCanopy", mat)]


# --------------------------------------------------------------------------------------------------- set --
def build_set(mat):
    s = Set(NAME)
    keep = []

    def put(fn, x, z, rot=0.0, r=4.0, y=0.0):
        keep.append((x, z, r))
        return s.put(fn, x, z, rot, y)

    _walls(s, mat)
    _dune_ridge(s, mat, DUNE_A_Z, ISLE_A)
    _dune_ridge(s, mat, DUNE_B_Z, ISLE_B)
    for (x, z) in ((0, -246), (2, -196), (22, -132)):
        _hump(s, mat, x, z)
        keep.append((x, z, 9))
    _canyon(s, mat)
    _terraces(s, mat)
    _mesa_ridge(s, mat, MESA_Z, ISLE_M)
    _ruin_wall(s, mat, RUIN_Z, ISLE_R)

    # the gate band: the signpost, pots and crates by the way in
    put(signpost(mat), -7.0, -258.0, 15, r=3)
    for (x, z, r) in ((-30, -262, 1.1), (-44, -248, 0.9), (34, -256, 1.2), (56, -238, 1.0)):
        put(pot(mat, r), x, z, 0, r=3)
        _spot(s, "pot", x + 1.8 * r, z - 1.0)
    for (x, z, t) in ((-58, -264, 0.1), (48, -266, -0.08)):
        put(crate(mat, t), x, z, 20, r=3)
        _spot(s, "crate", x - 2.2, z - 1.6)
    put(shrub(mat), 22, -244, 0, r=2)
    _spot(s, "dune_shade", 22, -241.6)
    for (x, z) in ((-62, -236), (64, -258)):
        put(shrub(mat), x, z, 0, r=2)

    # the dune sea, between and past the ridges
    for (x, z, r) in ((-28, -196, 1.3), (40, -190, 1.0), (-62, -182, 1.1), (52, -172, 1.2), (-20, -134, 1.0),
                      (64, -126, 1.1)):
        put(pot(mat, r), x, z, 0, r=3)
        _spot(s, "pot", x + 1.8 * r, z - 1.0)
    for (x, z, t) in ((-46, -200, 0.06), (28, -178, -0.1), (-52, -126, 0.0)):
        put(crate(mat, t), x, z, -15, r=3)
        _spot(s, "crate", x - 2.2, z - 1.6)
    for (x, z) in ((-8, -230), (60, -200), (-36, -170), (8, -140)):
        put(rock(mat, 1.3), x, z, (x * 7) % 360, r=3)
        _spot(s, "rock", x, z, y=1.6)
    for (x, z) in ((-60, -228), (30, -232), (-30, -228), (60, -214), (-66, -146), (46, -136), (-6, -168)):
        _spot(s, "dune", x, z)
    for (x, z) in ((-16, -186), (44, -206), (-44, -136)):
        put(shrub(mat), x, z, 0, r=2)
        _spot(s, "dune_shade", x, z - 2.4)
    for (x, z, rot) in ((-14, -206, 90), (40, -146, -90)):
        put(lamp(mat), x, z, rot, r=2)
    put(canopy(mat), -52, -246, 10, r=5)
    _spot(s, "canopy_shade", -52, -246)

    # the red canyon: the slot, its alcoves, the side passage
    for side, z in ALCOVES:
        _spot(s, "alcove", side * (SLOT_HALF + 5.5), z - 1.5)
        _spot(s, "alcove", side * (SLOT_HALF + 4.0), z + 2.5)
        put(pot(mat, 0.9), side * (SLOT_HALF + 8.0), z + 3.0, 0, r=2)
    for z in (-102, -84, -56, -28):
        _spot(s, "canyon", 5.5 * (1 if z % 4 else -1), z)
    for z in (-96, -70, -46, -30):
        _spot(s, "side_passage", 66.0 - 3.0 * ((z // 2) % 2), z)
    for (x, z) in ((-6.0, -92.0), (6.5, -64.0), (66.0, -84.0)):
        _spot(s, "boulder", x + 1.6, z - 1.6)
    for (x, z, rot) in ((-7.6, -104.0, 90), (7.6, -26.0, -90), (EAST_MASS + 1.2, -60.0, 90)):
        put(lamp(mat), x, z, rot, r=1.5)

    # the mirage flats: the pan, the terraces, the caravan, canopies
    put(wagon(mat), -26, 22, 30, r=7)
    _spot(s, "wagon", *turned(-26, 22, 30, 0, -3.2))
    _spot(s, "wagon", *turned(-26, 22, 30, -4.6, 1.4))
    for (x, z, rot) in ((30, 12, -10), (-34, 88, 15)):
        put(canopy(mat), x, z, rot, r=5)
        _spot(s, "canopy_shade", x, z)
    for (x, z) in ((-38, 4), (40, 36), (-18, 46), (26, 82), (-24, 112), (42, 122), (-44, 124), (14, -6)):
        _spot(s, "flats", x, z)
    for sx in (-1, 1):
        for z in (-4, 34, 78, 120):
            _spot(s, "terrace", sx * (TERRACE_X + 5.0), z + 3 * sx, y=2 * TERRACE_H + 0.02)
        for z in (24, 96):
            _spot(s, "terrace_step", sx * (PAN_X + 3.5), z, y=TERRACE_H)
    for (x, z) in ((-46, 40), (46, 66), (-8, 100)):
        put(palm_stump(mat), x, z, (x * 11) % 360, r=2.5)
        _spot(s, "palm_stump", x + 1.4, z - 1.4)
    for (x, z, r) in ((-40, -10, 1.0), (36, 100, 1.2), (-2, 70, 1.1)):
        put(pot(mat, r), x, z, 0, r=3)
        _spot(s, "pot", x + 1.8 * r, z - 1.0)
    for (x, z) in ((-46, 72), (48, 18), (12, 120)):
        put(rock(mat, 1.5), x, z, (x * 5) % 360, r=3)
        _spot(s, "rock", x, z, y=1.8)
    for (x, z, rot) in ((-8, 52, 90), (14, 52, -90), (30, 140, 0)):
        put(lamp(mat), x, z, rot, r=1.5)

    # the sunken pyramid: the courtyard of obelisks, the pyramid
    cx, cz = COURT
    for (x, z, h, broken) in ((-20, 170, 13.0, False), (20, 170, 12.0, True), (-20, 196, 12.0, True),
                              (20, 196, 14.0, False), (-44, 182, 11.0, True), (46, 160, 11.0, False)):
        put(obelisk(mat, h, broken), x, z, 0, r=3.5)
        _spot(s, "obelisk", x + 2.6, z - 2.6)
    for (x, z) in ((-8, 162), (10, 190), (-34, 200), (36, 186)):
        _spot(s, "courtyard", x, z)
    px, pz = PYRAMID
    put(pyramid(mat), px, pz, 0, r=PYR_BASE / 2 + 4)
    for i in range(1, PYR_TIERS):                                              # on the tiers, off the stair
        w = PYR_BASE - 9.0 * i
        for sx in (-1, 1):
            _spot(s, "pyramid_tier", px + sx * max(7.0, w / 2 - 3.0), pz - w / 2 - 2.25, y=i * PYR_STEP)
    _spot(s, "pyramid_top", px - 3.4, pz - 2.4, y=PYR_TOP)
    _spot(s, "pyramid_top", px + 3.4, pz - 2.4, y=PYR_TOP)
    for (x, z) in ((-50, 230), (52, 252), (-56, 262), (40, 214)):
        _spot(s, "pyramid_foot", x, z)
    for (x, z, rot) in ((-6, 202, 90), (6, 202, -90), (-34, 156, 0), (34, 146, 0)):
        put(lamp(mat), x, z, rot, r=1.5)
    for (x, z, r) in ((-60, 248, 1.2), (62, 196, 1.0), (-62, 166, 1.1)):
        put(pot(mat, r), x, z, 0, r=3)
        _spot(s, "pot", x + 1.8 * r, z - 1.0)

    # the five rescue spots (section 4): two sand dunes, two clay urns, a collapsed canopy
    for (x, z, t) in ((-62.0, -160.0, 0), (44.0, 172.0, 0)):
        put(trap_sand_dune(mat), x, z, t, r=4)
        _spot(s, "trap_sand_dune", x, z, turn=t)
    for (x, z, t) in ((-60.0, 102.0, -30), (60.0, 262.0, 200)):
        put(trap_clay_urn(mat), x, z, t, r=4)
        _spot(s, "trap_clay_urn", x, z, turn=t)
    put(trap_collapsed_canopy(mat), 30.0, 112.0, 20, r=5)
    _spot(s, "trap_collapsed_canopy", 30.0, 112.0, turn=20)

    # filler: dry bushes and boulders, clear of the trail, the blockers, the pieces and the spots
    spots = [(p[0], p[2]) for lst in s.points.values() for p in lst]
    k = 0
    for gx in range(-64, 65, 16):
        for gz in range(-262, 263, 16):
            k += 1
            x = gx + 5.0 * math.sin(k * 2.71)
            z = gz + 5.0 * math.cos(k * 1.93)
            if z < -IN_Z + 16 and abs(x) < GATE_HALF + 10:
                continue
            if near_trail(x, z) < 8.0:
                continue
            if CANYON_Z0 - 4 < z < CANYON_Z1 + 4:
                continue
            if (abs(z - DUNE_A_Z) < 10 or abs(z - DUNE_B_Z) < 10 or abs(z - MESA_Z) < 9
                    or abs(z - RUIN_Z) < 6):
                continue
            if abs(x) > IN_X - 4 or (FLATS_Z0 < z < FLATS_Z1 and abs(x) > PAN_X - 2):
                continue
            if math.hypot(x - PYRAMID[0], z - PYRAMID[1]) < PYR_BASE / 2 + 10:
                continue
            if any(math.hypot(x - qx, z - qz) < qr + 4.0 for (qx, qz, qr) in keep):
                continue
            if any(math.hypot(x - qx, z - qz) < 6.0 for (qx, qz) in spots):
                continue
            if k % 3 == 0:
                s.put(rock(mat, 0.9 + 0.2 * (k % 3)), x, z, (k * 37) % 360)
            elif k % 3 == 1:
                s.put(shrub(mat), x, z, (k * 53) % 360)
    return s.finish(_ground(), mat), s


def build_desert_set(mat):
    objs, _ = build_set(mat)
    return objs


ASSETS = {
    NAME: (build_desert_set, 150000),
}
