"""The Medieval Castle (Tier 10, Castle Cafe; the next-areas plan Derek OK'd on 2026-11-13, section 3, #4067): a long
rectangle, 150 x 560 for the wild part like the Snowy Mountain and the Water Park, with the camp (the Village Gate, a
later piece) 30 more across its -Z end, outside it.

  CatCafe_Castle_Set   the wild part dressed, in area space (areakit): place it at the area's centre on its floor,
                       camp side -Z, like every set. Walls at x +-75 and z +-280; the way in is the 24 stud opening
                       at x 0 on z -280.

No grass anywhere: cobbles on the lane and the wards, packed earth round the field, sand on the field, stone flags in
the keep; the edges are timber palisades by the village and battlemented stone from the moat on, 10 high. Nothing
invisible stands inside the area (#2897's rule): the only _Barrier is the 30 high ring in the border's wall band,
which starts BAR_IN behind the border's drawn faces. Every zone has two ways through. The zones, camp first:

  z -276 to -150   Market Lane: a 12 wide cobbled street between two rows of five timber houses and market stalls
                   (scenery only), a well on a round plaza at (0, -201), a back alley behind each row that leaves the
                   street at z -270 and meets it again at z -156
  z -150 to -15    the Jousting Field: a sand oval round (0, -82), the tilt fence (a low rail, 1.3 high) west of the
                   path, a stand by each wall, straw archery butts, two striped pavilions
  z -15 to 70      the Castle Gate: the moat across the width (z -15 to -2, a kerb 0.7 high round shallow _Water), the
                   16 wide drawbridge, the gatehouse with its portcullis raised, the curtain wall 20 high with a tower
                   at each end and a second way in, a postern 8 wide at x 50 with a plank bridge over the moat; the
                   outer ward behind with the stables
  z 70 to 170      the Courtyard: a loop path round the old oak in its stone ring, the training yard's dummies,
                   haystacks and carts
  z 170 to 276     the Throne Hall: a roofless keep (walls 22 high at x +-55, the front at z 178) with a 16 wide
                   door, a 10 wide door in each side wall at z 226, columns with banners, two long tables, a red
                   carpet and the throne on its steps at z 266; the deep zone where the Mythical stays

Torch flames are `_Glow` (soft, still), windows `_Pane`. Nothing here turns: the windmill is the backdrop's.

Points (manifest points_roblox): [x, y, z, zone], zone "near" (z < 0) or "deep". The five rescue spots are built in
(the plan's 3a), each with its piece's turn as a fifth number:
  trap_haystack      a haystack with a hollow in its middle, the cat in it up to its chin
  trap_barrel        an open barrel, the cat's head and front paws out of its top (0.9 up)
  trap_banner_pole   a low banner pole on a stone foot, the cat hugging it half way up (1.6 up)
  trap_awning        a fallen stall awning, striped cloth over two broken poles, the cat peeking out from under it
  trap_helmet        an empty armour stand, the cat inside its big helmet looking out of the visor (2.2 up)
Four of the five are deep and none is within 100 studs of the camp. The rescue pool adds ten more (POOL_*), 15 in
all, ten of them deep, every one 25 or more from every other and off the paths, the blockers and the moat
(check_layout asserts it).
"""

import math
from itertools import pairwise

from areakit import PI, Set, hinge, smoke, turned
from common import Builder
from woodsset import _dist_seg, _strip, bl

NAME = "CatCafe_Castle_Set"
N = "CatCafe_Castle_"
HALF_X, HALF_Z = 75.0, 280.0
WALL_D = 3.0
IN_X, IN_Z = HALF_X - 0.5 - WALL_D, HALF_Z - 0.5 - WALL_D       # 71.5, 276.5
GATE_HALF = 12.0
BARRIER_H = 30.0
BAR_IN = 0.8
SPINE_W, ALLEY_W, LOOP_W, SIDE_W = 12.0, 8.0, 9.0, 7.0

# the palette: timber on plaster, grey castle stone, banners in four colours
COBBLE, COBBLE_EDGE = "fur_dusty", "concrete_dark"
EARTH, SAND, SAND_EDGE = "treat_tan", "paving_sand", "paving_tan"
FLAG, FLAG_EDGE = "paving_light", "paving_grout"
STONE, STONE_LIGHT, STONE_DARK = "concrete", "metal", "concrete_dark"
WOOD, WOOD_DARK, PLASTER = "caramel_wood", "dark_wood", "cream"
ROOF, ROOF_DARK = "terracotta", "brick"
RED, NAVY, GREEN, GOLD, MILK = "shirt_red", "pants_navy", "leaf_green", "rarity_legend", "milk"
STRAW, WATER, IRON = "fur_golden", "fish_blue", "fur_soot"
BANNERS = (RED, NAVY, GREEN, GOLD)

# Market Lane
HOUSE_X, HOUSE_W, HOUSE_D = 23.0, 14.0, 10.0
HOUSE_Z = (-256.0, -234.0, -212.0, -190.0, -168.0)
WELL = (0.0, -201.0)
ALLEY_X, ALLEY_Z0, ALLEY_Z1 = 40.0, -270.0, -156.0
# the Jousting Field
FIELD = (0.0, -82.0, 58.0, 62.0)                    # the sand oval: x, z, half along x, half along z
TILT = (-26.0, -118.0, -46.0)                       # the tilt fence: x, z0, z1
STANDS = ((-64.0, -82.0), (64.0, -82.0))            # each 40 long (z) by 9 deep (x)
TENTS = ((-46.0, -134.0), (46.0, -32.0))
BUTTS = ((34.0, -112.0), (34.0, -90.0), (34.0, -68.0))
# the Castle Gate
MOAT_Z0, MOAT_Z1 = -15.0, -2.0
WALL_Z0, WALL_Z1, WALL_H = 4.0, 12.0, 20.0
DOOR_HALF = 8.0
POSTERN_X, POSTERN_HALF = 50.0, 4.0
GATEHOUSE = (8.0, 20.0, 0.0, 18.0, 26.0)            # each tower: |x| from, to, z from, to, height
TOWERS = ((-66.0, 8.0, 7.0, 30.0), (66.0, 8.0, 7.0, 30.0), (-34.0, 8.0, 5.0, 25.0), (30.0, 8.0, 5.0, 25.0))
STABLES = (-34.0, 40.0, 16.0, 10.0)                 # x, z, width (x), depth (z)
# the Courtyard
OAK = (0.0, 120.0, 6.0)
# the Throne Hall
KEEP_X, KEEP_Z0, KEEP_Z1, KEEP_T, KEEP_H = 55.0, 178.0, 276.5, 4.0, 22.0
SIDE_DOOR_Z, SIDE_DOOR_HALF = 226.0, 5.0
DAIS = (0.0, 266.0, 24.0, 14.0)
TABLES = ((-25.0, 218.0), (25.0, 218.0))            # each 4 wide (x) by 36 long (z)
COLUMNS = tuple((sx * 13.0, z) for z in (192.0, 212.0, 232.0, 252.0) for sx in (-1, 1))

TRAIL = [(0.0, -IN_Z), (0.0, 258.0)]
LOOP = [(0.0, 70.0), (-36.0, 92.0), (-36.0, 150.0), (0.0, 170.0), (36.0, 150.0), (36.0, 92.0), (0.0, 70.0)]
ALLEYS = [[(0.0, ALLEY_Z0), (sx * ALLEY_X, ALLEY_Z0), (sx * ALLEY_X, ALLEY_Z1), (0.0, ALLEY_Z1)] for sx in (-1, 1)]
POSTERN = [(0.0, -26.0), (POSTERN_X, -26.0), (POSTERN_X, 36.0), (0.0, 62.0)]
SIDES = [[(sx * 36.0, 150.0), (sx * 64.0, 168.0), (sx * 64.0, SIDE_DOOR_Z), (sx * 40.0, SIDE_DOOR_Z)] for sx in (-1, 1)]
PATHS = ((TRAIL, SPINE_W), (LOOP, LOOP_W), (ALLEYS[0], ALLEY_W), (ALLEYS[1], ALLEY_W), (POSTERN, SIDE_W),
         (SIDES[0], SIDE_W), (SIDES[1], SIDE_W))

# the rescue spots: (label, x, z, turn); the pool as (x, z, turn)
MAIN_TRAPS = (("trap_haystack", -46.0, -30.0, 0), ("trap_barrel", 61.0, 52.0, 0),
              ("trap_banner_pole", -54.0, 130.0, 0), ("trap_awning", 22.0, 120.0, 200),
              ("trap_helmet", 44.0, 248.0, 150))
POOL_HAYSTACKS = ((40.0, -138.0, 0), (-58.0, 100.0, 0))
POOL_BARRELS = ((-61.0, -150.0, 0), (-43.0, 200.0, 0))
POOL_POLES = ((60.0, -20.0, 0), (44.0, 196.0, 0))
POOL_AWNINGS = ((22.0, -44.0, 30), (-60.0, 54.0, -40))
POOL_HELMETS = ((-44.0, 250.0, 210), (60.0, 110.0, 90))
TRAP_BARREL_Y, TRAP_POLE_Y, TRAP_HELMET_Y = 0.9, 1.6, 2.2


def near_trail(x, z):
    """Distance to the nearest path's edge (its middle line, less half its width)."""
    d = 1e9
    for pts, w in PATHS:
        for a, b in pairwise(pts):
            d = min(d, _dist_seg((x, z), a, b) - w / 2)
    return d


def trail_length():
    return sum(math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in pairwise(TRAIL))


def in_moat(x, z, pad=0.0):
    return MOAT_Z0 - 0.6 - pad < z < MOAT_Z1 + 0.6 + pad


def _rect(x, z, cx, cz, w, d, pad):
    return abs(x - cx) < w / 2 + pad and abs(z - cz) < d / 2 + pad


def in_block(x, z, pad=0.0):
    """On or within pad of a blocker's footprint: a house or stall, the well, a stand, a pavilion, a butt, the tilt
    fence, the gatehouse, the curtain wall and its towers, the stables, the oak, the keep's walls, columns, tables
    and dais."""
    for hz in HOUSE_Z:
        if _rect(abs(x), z, HOUSE_X, hz, HOUSE_D, HOUSE_W, pad):
            return True
    if math.hypot(x - WELL[0], z - WELL[1]) < 3.0 + pad:
        return True
    if any(_rect(x, z, sx, sz, 9.0, 40.0, pad) for sx, sz in STANDS):
        return True
    if any(math.hypot(x - tx, z - tz) < 6.5 + pad for tx, tz in TENTS):
        return True
    if any(_rect(x, z, bx, bz, 3.0, 4.0, pad) for bx, bz in BUTTS):
        return True
    if abs(x - TILT[0]) < 0.6 + pad and TILT[1] - pad < z < TILT[2] + pad:
        return True
    x0, x1, z0, z1, _ = GATEHOUSE
    if x0 - pad < abs(x) < x1 + pad and z0 - pad < z < z1 + pad:
        return True
    if WALL_Z0 - pad < z < WALL_Z1 + pad and abs(x) > DOOR_HALF - pad and abs(x - POSTERN_X) > POSTERN_HALF - pad:
        return True
    if any(math.hypot(x - tx, z - tz) < tr + pad for tx, tz, tr, _ in TOWERS):
        return True
    if _rect(x, z, *STABLES, pad):
        return True
    if math.hypot(x - OAK[0], z - OAK[1]) < OAK[2] + pad:
        return True
    if KEEP_Z0 - pad < z < KEEP_Z0 + KEEP_T + pad and DOOR_HALF - pad < abs(x) < KEEP_X + KEEP_T / 2 + pad:
        return True
    if abs(abs(x) - KEEP_X) < KEEP_T / 2 + pad and z > KEEP_Z0 - pad and abs(z - SIDE_DOOR_Z) > SIDE_DOOR_HALF - pad:
        return True
    if any(math.hypot(abs(x) - KEEP_X, z - KEEP_Z0 - 2.0) < 6.0 + pad for _ in (0,)):
        return True
    if _rect(x, z, *DAIS, pad):
        return True
    if any(_rect(x, z, tx, tz, 4.0, 36.0, pad) for tx, tz in TABLES):
        return True
    return any(math.hypot(x - cx, z - cz) < 1.8 + pad for cx, cz in COLUMNS)


def _spot(s, label, x, z, y=0.0, turn=None):
    p = [round(x, 2), round(y, 2), round(z, 2), "deep" if z > 0 else "near"]
    if turn is not None:
        p.append(turn)
    s.points.setdefault(label, []).append(p)


# ------------------------------------------------------------------------------------------------- ground --
def _path(g, pts, w, swatch, top):
    for i, (p0, p1) in enumerate(pairwise(pts)):
        _strip(g, p0, p1, w, swatch, top + 0.02 * (i % 2))
    for p in pts[1:-1]:
        g.cyl_base(bl(*p), w / 2, top - 0.012, swatch, segments=16, bevel=False)


def _ground():
    """Packed earth right out to the walls (no plate shows, no grass), the field's sand oval, cobbles under the lane
    and the wards, stone flags in the keep with the red carpet, the paths over it all."""
    g = Builder()
    g.box_base((0, 0, 0), (2 * HALF_X, 2 * HALF_Z, 0.03), EARTH, bevel=False)
    g.box_base((*bl(0, (-HALF_Z + ALLEY_Z1 + 6) / 2)[:2], 0), (2 * HALF_X, ALLEY_Z1 + 6 + HALF_Z, 0.05), COBBLE,
               bevel=False)                                               # the village's cobbles
    g.box_base((*bl(0, (MOAT_Z1 + KEEP_Z0) / 2)[:2], 0), (2 * HALF_X, KEEP_Z0 - MOAT_Z1, 0.052), COBBLE, bevel=False)
    g.box_base((*bl(0, (KEEP_Z0 + HALF_Z) / 2)[:2], 0), (2 * HALF_X, HALF_Z - KEEP_Z0, 0.056), FLAG, bevel=False)
    k = 0
    for ix in range(-5, 6):                                              # darker flags in a checker inside the keep
        for iz in range(10):
            k += 1
            if (ix + iz) % 2:
                continue
            g.box_base((*bl(ix * 10.0, KEEP_Z0 + 9.0 + iz * 10.0)[:2], 0), (9.4, 9.4, 0.066 + 0.002 * (k % 2)), FLAG_EDGE,
                       bevel=False)
    for i in range(60):                                                  # darker cobbles scattered on the cobbled parts
        x = -68.0 + (i * 37) % 137
        z = (-272.0 + (i * 53) % 118) if i % 2 else (22.0 + (i * 41) % 144)
        g.cyl_base((*bl(x, z)[:2], 0), 1.5 + 0.5 * (i % 3), 0.062 + 0.002 * (i % 3), COBBLE_EDGE, segments=8, bevel=False)
    fx, fz, frx, frz = FIELD
    g.cyl_base((*bl(fx, fz)[:2], 0), 1.0, 0.07, SAND_EDGE, segments=40, bevel=False, scale=(frx + 2.0, frz + 2.0, 1.0))
    g.cyl_base((*bl(fx, fz)[:2], 0), 1.0, 0.085, SAND, segments=40, bevel=False, scale=(frx, frz, 1.0))
    for i, z in enumerate(range(-116, -44, 12)):                         # the lists' chalk marks beside the tilt
        for dx in (-5.0, 5.0):
            g.box_base((*bl(TILT[0] + dx, z)[:2], 0), (0.5, 6.0, 0.095), MILK, bevel=False)
    g.cyl_base((*bl(*WELL)[:2], 0), 10.0, 0.1, COBBLE_EDGE, segments=24, bevel=False)
    g.cyl_base((*bl(OAK[0], OAK[1])[:2], 0), OAK[2] + 5.0, 0.1, COBBLE_EDGE, segments=24, bevel=False)
    spine_a = [TRAIL[0], (0.0, MOAT_Z0 - 2.0)]
    spine_b = [(0.0, MOAT_Z1 + 2.0), (0.0, KEEP_Z0)]
    spine_c = [(0.0, KEEP_Z0), TRAIL[1]]
    post_a = [POSTERN[0], POSTERN[1], (POSTERN_X, MOAT_Z0 - 1.0)]
    post_b = [(POSTERN_X, MOAT_Z1 + 1.0), POSTERN[2], POSTERN[3]]
    for pts, w, sw, edge, top in ((spine_a, SPINE_W, FLAG, FLAG_EDGE, 0.0), (spine_b, SPINE_W, FLAG, FLAG_EDGE, 0.004),
                                  (LOOP, LOOP_W, FLAG, FLAG_EDGE, 0.012), (ALLEYS[0], ALLEY_W, SAND, SAND_EDGE, 0.012),
                                  (ALLEYS[1], ALLEY_W, SAND, SAND_EDGE, 0.012), (post_a, SIDE_W, SAND, SAND_EDGE, 0.02),
                                  (post_b, SIDE_W, SAND, SAND_EDGE, 0.02), (SIDES[0], SIDE_W, SAND, SAND_EDGE, 0.02),
                                  (SIDES[1], SIDE_W, SAND, SAND_EDGE, 0.02)):
        _path(g, pts, w + 1.6, edge, 0.105 + top)
        _path(g, pts, w, sw, 0.16 + top * 3)
    _path(g, spine_c, 10.0, GOLD, 0.11)                                   # the carpet's gold edge
    _path(g, spine_c, 8.6, RED, 0.17)                                     # the red carpet
    return g


# -------------------------------------------------------------------------------------------------- walls --
def _seg_palisade(b, d, L, k):
    """A timber palisade 10 high: pointed stakes in two woods, two rails across."""
    n = max(4, round(L / 1.8))
    w = L / n
    for i in range(n):
        x = -L / 2 + (i + 0.5) * w
        h = 9.0 + 0.5 * ((i + k) % 3)
        b.box_base((x, 1.0, 0), (w + 0.02, 1.3 + 0.03 * (i % 2), h), (WOOD, "fur_brown")[i % 2], bevel=False)
        b.cyl_base((x, 1.0, h), w * 0.62, 1.2, (WOOD, "fur_brown")[i % 2], segments=4, radius2=0.05, bevel=False)
    for z in (3.0, 7.0):
        b.box_base((0, 0.2, z), (L, 0.4, 0.6), WOOD_DARK, bevel=False)
    b.box_base((0, 2.2, 0), (L, 1.2, 5.0), WOOD_DARK, bevel=False)


def _seg_stone(b, d, L, k):
    """A castle wall 10 high: a darker foot, grey blocks with a course line, merlons along the top."""
    b.box_base((0, 1.5, 0), (L, 3.0, 1.2), STONE_DARK, bevel=False)
    b.box_base((0, 1.5, 1.2), (L, 2.6, 7.4), (STONE, STONE_LIGHT)[k % 2], bevel=False)
    b.box((0, 0.17, 4.9), (L, 0.08, 0.2), STONE_DARK, bevel=False)
    b.box_base((0, 1.5, 8.6), (L, 3.0, 0.5), STONE_DARK, bevel=False)
    n = max(3, round(L / 4.0))
    for i in range(n):
        x = -L / 2 + (i + 0.5) * L / n
        b.box_base((x, 1.5, 9.1), (L / n * 0.55, 2.8, 1.3), (STONE, STONE_LIGHT)[k % 2], bevel=False)
    for i in range(max(1, round(L / 14.0))):                              # a banner on the wall's face
        x = -L / 2 + (i + 0.5) * L / max(1, round(L / 14.0))
        b.box((x, 0.12, 6.0), (2.2, 0.08, 3.6), BANNERS[(i + k) % 4], bevel=False)
        b.box((x, 0.06, 6.2), (0.9, 0.06, 0.9), GOLD, bevel=False, rot=(PI / 4, "Y"))


SEGMENTS = {"palisade": _seg_palisade, "stone": _seg_stone}


def wall_segment(mat, kind, L, k=0):
    """One wall run L long along local x, its face at y 0 (facing -Y, into the area) and its back at WALL_D."""
    b, d = Builder(), Builder()
    SEGMENTS[kind](b, d, L, k)
    return [b.finalize(N + "Wall" + kind.capitalize(), mat)]


def wall_turret(mat, h=16.0, k=0):
    """A small turret in the wall line between two runs: timber with a pitched cap by the village, round stone with a
    cone roof and a pennant from the moat on."""
    b = Builder()
    if k < 0:
        b.box_base((0, WALL_D / 2, 0), (3.2, 3.2, h - 3.0), WOOD_DARK, bevel=False)
        b.box_base((0, WALL_D / 2, h - 3.0), (4.2, 4.2, 0.4), WOOD, bevel=False)
        b.cyl_base((0, WALL_D / 2, h - 2.6), 3.1, 2.8, ROOF, segments=4, radius2=0.2, bevel=False)
    else:
        b.cyl_base((0, WALL_D / 2, 0), 1.9, h - 4.0, STONE, segments=10, bevel=False)
        b.cyl_base((0, WALL_D / 2, h - 4.0), 2.3, 0.8, STONE_DARK, segments=10, bevel=False)
        b.cyl_base((0, WALL_D / 2, h - 3.2), 2.5, 3.2, (RED, NAVY)[k % 2], segments=10, radius2=0.15, bevel=False)
        b.cyl_base((0, WALL_D / 2, h), 0.08, 2.2, IRON, segments=6, bevel=False)
        b.box((0.8, WALL_D / 2, h + 1.6), (1.6, 0.06, 0.9), GOLD, bevel=False)
    return [b.finalize(N + "WallTurret", mat)]


def _run(s, mat, kinds, n, length, place, seed):
    L = (length - (n - 1) * 3.4) / n
    for i in range(n):
        t = i * (L + 3.4) + L / 2
        x, z, rot = place(t)
        kind = kinds[i % len(kinds)]
        s.put(wall_segment(mat, kind, L, i + seed), x, z, rot)
        if i < n - 1:
            nxt = kinds[(i + 1) % len(kinds)]
            k = -1 if kind == "palisade" and nxt == "palisade" else i + seed
            s.put(wall_turret(mat, 14.0 + 2.0 * ((i + seed) % 3), k), *place(t + L / 2 + 1.7))


def low_wall(mat, L):
    """The camp side: a low palisade 3.6 high, so the camp shows over it."""
    b = Builder()
    n = max(4, round(L / 1.6))
    w = L / n
    for i in range(n):
        x = -L / 2 + (i + 0.5) * w
        b.box_base((x, 1.0, 0), (w * 0.85, 0.6, 3.2 + 0.3 * (i % 2)), (WOOD, "fur_brown")[i % 2], bevel=False)
    b.box_base((0, 1.0, 1.0), (L, 0.8, 0.3), WOOD_DARK, bevel=False)
    b.box_base((0, 1.0, 2.5), (L, 0.8, 0.3), WOOD_DARK, bevel=False)
    return [b.finalize(N + "LowWall", mat)]


def _walls(s, mat):
    """Palisades by the village and stone from the moat on just inside the area's walls, turrets between, the camp
    side a low palisade either side of the way in; a barrier all round but the way in."""
    far = ("stone",) * 5
    side = ("palisade",) * 7 + ("stone",) * 8                             # camp end first
    _run(s, mat, far, 5, 2 * IN_X, lambda t: (-IN_X + t, IN_Z, 0), 0)
    _run(s, mat, side, 15, 2 * IN_Z, lambda t: (IN_X, -IN_Z + t, 90), 1)
    _run(s, mat, side, 15, 2 * IN_Z, lambda t: (-IN_X, -IN_Z + t, -90), 2)
    for sx in (-1, 1):
        s.put(wall_turret(mat, 22.0, 1 + (sx > 0)), sx * (IN_X - 2.0), IN_Z - 2.0, 45 * sx)
        s.put(wall_turret(mat, 14.0, -1), sx * (IN_X - 2.0), -IN_Z + 2.0, 135 * sx)
        L = IN_X - GATE_HALF - 4.5
        s.put(low_wall(mat, L), sx * (GATE_HALF + 0.5 + L / 2), -IN_Z, 180)
        s.put(torch_post(mat), sx * (GATE_HALF + 2.0), -IN_Z + 2.0, 0)
    bar = Builder()
    ox = IN_X + WALL_D
    T = WALL_D - BAR_IN
    mid = IN_Z + BAR_IN + T / 2
    bar.box_base((0, mid, 0), (2 * ox, T, BARRIER_H), "offwhite", bevel=False)
    for sx in (-1, 1):
        bar.box_base((sx * (IN_X + BAR_IN + T / 2), 0, 0), (T, 2 * IN_Z, BARRIER_H), "offwhite", bevel=False)
        bar.box_base((sx * (GATE_HALF + ox) / 2, -mid, 0), (ox - GATE_HALF, T, BARRIER_H), "offwhite", bevel=False)
    s.put([bar.finalize(N + "Walls_Barrier", mat)], 0, 0, 0)


# ------------------------------------------------------------------------------------------- small pieces --
def _banner(b, x, y, z, w, h, col, face=1):
    """A hanging banner on a face at y (its cloth 0.08 proud toward -Y * face): the cloth, a gold bar and a
    swallow tail."""
    b.box((x, y - face * 0.06, z), (w, 0.08, h), col, bevel=False)
    b.box((x, y - face * 0.08, z + h / 2 + 0.12), (w + 0.5, 0.16, 0.24), GOLD, bevel=False)
    b.box((x, y - face * 0.12, z + h * 0.12), (w * 0.4, 0.06, w * 0.4), GOLD, bevel=False, rot=(PI / 4, "Y"))
    for sx in (-1, 1):
        b.box((x + sx * w / 4, y - face * 0.06, z - h / 2 - 0.3), (w / 2 - 0.1, 0.08, 0.7), col, bevel=False)


def torch_post(mat):
    """A torch on a wooden post, an iron basket and a soft still flame (_Glow)."""
    b, g = Builder(), Builder()
    b.box_base((0, 0, 0), (0.9, 0.9, 0.4), STONE_DARK, bevel=False)
    b.box_base((0, 0, 0.4), (0.4, 0.4, 5.6), WOOD_DARK, bevel=False)
    b.cyl_base((0, 0, 6.0), 0.55, 0.7, IRON, segments=8, radius2=0.75, bevel=False)
    g.cyl_base((0, 0, 6.6), 0.5, 1.3, "fur_orange", segments=6, radius2=0.05, bevel=False)
    g.cyl_base((0, 0, 6.6), 0.28, 0.9, "pastel_butter", segments=6, radius2=0.03, bevel=False)
    return [b.finalize(N + "Torch", mat), g.finalize(N + "Torch_Glow", mat)]


def bench(mat):
    b = Builder()
    b.box((0, 0, 1.3), (4.4, 1.3, 0.25), WOOD, bevel=False)
    for sx in (-1, 1):
        b.box_base((sx * 1.8, 0, 0), (0.4, 1.1, 1.2), WOOD_DARK, bevel=False)
    return [b.finalize(N + "Bench", mat)]


def barrel(mat, k=0):
    b = Builder()
    b.cyl_base((0, 0, 0), 1.2, 2.6, (WOOD, "fur_brown")[k % 2], segments=10, bevel=False)
    for z in (0.5, 2.0):
        b.cyl_base((0, 0, z), 1.27, 0.2, IRON, segments=10, bevel=False)
    b.cyl_base((0, 0, 2.6), 1.1, 0.08, WOOD_DARK, segments=10, bevel=False)
    return [b.finalize(N + "Barrel", mat)]


def barrels(mat, k=0):
    """Three barrels, one lying on its side."""
    b = Builder()
    for i, (x, y) in enumerate(((-1.3, 0.0), (1.3, 0.3))):
        b.cyl_base((x, y, 0), 1.2, 2.6, (WOOD, "fur_brown")[(i + k) % 2], segments=10, bevel=False)
        for z in (0.5, 2.0):
            b.cyl_base((x, y, z), 1.27, 0.2, IRON, segments=10, bevel=False)
    b.cyl((0, -2.2, 1.2), 1.2, 2.6, WOOD, segments=10, rot=(PI / 2, "Y"), bevel=False)
    for x in (-0.8, 0.8):
        b.cyl((x, -2.2, 1.2), 1.27, 0.2, IRON, segments=10, rot=(PI / 2, "Y"), bevel=False)
    return [b.finalize(N + "Barrels", mat)]


def crate_stack(mat, k=0):
    b = Builder()
    for i, (x, y, z, s) in enumerate(((0, 0, 0, 2.2), (2.3, 0.2, 0, 2.0), (0.6, 0.1, 2.2, 1.8))):
        b.box_base((x, y, z), (s, s, s), (WOOD, "cardboard")[(i + k) % 2], bevel=False)
        b.box_base((x, y, z + s * 0.45), (s + 0.08, s + 0.08, 0.18), WOOD_DARK, bevel=False)
    return [b.finalize(N + "Crates", mat)]


def haystack(mat, s=1.0):
    b = Builder()
    b.cyl_base((0, 0, 0), 2.6 * s, 1.6 * s, STRAW, segments=10, bevel=False)
    b.cyl_base((0, 0, 1.6 * s), 2.6 * s, 1.8 * s, "fur_sand", segments=10, radius2=0.5 * s, bevel=False)
    for k in range(5):
        a = 2 * PI * k / 5
        b.box((2.5 * s * math.cos(a), 2.5 * s * math.sin(a), 0.5 * s), (0.1, 0.9, 0.1), "pastel_butter", bevel=False,
              rot=(a + 0.5, "Z"))
    return [b.finalize(N + "Haystack", mat)]


def hay_cart(mat):
    """A two-wheeled cart full of hay, its shafts resting on the ground (front -Y)."""
    b = Builder()
    b.box_base((0, 0, 1.4), (4.0, 6.0, 0.3), WOOD, bevel=False)
    for sx in (-1, 1):
        b.box_base((sx * 2.0, 0, 1.7), (0.25, 6.0, 1.3), WOOD_DARK, bevel=False)
        b.cyl((sx * 2.3, 0.6, 1.5), 1.5, 0.3, WOOD_DARK, segments=12, rot=(PI / 2, "Y"), bevel=False)
        b.cyl((sx * 2.3, 0.6, 1.5), 0.4, 0.4, IRON, segments=8, rot=(PI / 2, "Y"), bevel=False)
        b.box((sx * 1.4, -4.4, 0.8), (0.25, 3.4, 0.25), WOOD_DARK, bevel=False, rot=(0.36, "X"))
    b.box_base((0, 0, 1.7), (3.6, 5.6, 1.5), STRAW, bevel=False)
    b.ico((0, 0, 3.4), 2.0, "fur_sand", subdivisions=1, scale=(0.95, 1.4, 0.6))
    return [b.finalize(N + "HayCart", mat)]


def well(mat):
    """The village well: a round stone wall 2.2 high, water inside, two posts, a little pitched roof and a bucket."""
    b, w = Builder(), Builder()
    b.ring((0, 0, 1.1), 2.6, 0.7, 2.2, STONE, segments=12, bevel=False)
    b.ring((0, 0, 2.3), 2.75, 0.95, 0.25, STONE_DARK, segments=12, bevel=False)
    w.cyl_base((0, 0, 1.5), 1.9, 0.1, WATER, segments=12, bevel=False)
    for sx in (-1, 1):
        b.box_base((sx * 2.3, 0, 2.4), (0.45, 0.45, 4.2), WOOD_DARK, bevel=False)
        b.box((sx * 1.3, 0, 7.3), (3.1, 3.6, 0.3), ROOF, bevel=False, rot=(sx * 0.6, "Y"))
    b.cyl((0, 0, 6.0), 0.25, 4.6, WOOD, segments=8, rot=(PI / 2, "Y"), bevel=False)
    b.box((0.6, 0, 4.7), (0.06, 0.06, 2.4), "fur_sand", bevel=False)
    b.cyl_base((0.6, 0, 2.9), 0.5, 0.8, WOOD, segments=8, radius2=0.6, bevel=False)
    return [b.finalize(N + "Well", mat), w.finalize(N + "Well_Water", mat)]


def timber_house(mat, k=0, smoking=False):
    """A timber-framed house, 14 wide and 10 deep, about 17 to its ridge (front -Y): a stone foot, cream plaster in a
    dark frame, a jettied upper floor, a steep tiled roof, a door, shuttered windows (_Pane, lit at night) and a
    chimney (`smoking`: with a "Smoke" Attachment at its top). Scenery only."""
    b, p = Builder(), Builder()
    W, D = HOUSE_W, HOUSE_D
    roof = (ROOF, ROOF_DARK, "fur_brown")[k % 3]
    b.box_base((0, 0, 0), (W, D, 1.2), STONE, bevel=False)
    b.box_base((0, 0, 1.2), (W - 0.4, D - 0.4, 5.8), PLASTER, bevel=False)
    b.box_base((0, -0.5, 7.0), (W + 0.6, D + 1.0, 0.5), WOOD_DARK, bevel=False)             # the jetty's beam
    b.box_base((0, -0.5, 7.5), (W, D + 0.6, 4.5), PLASTER, bevel=False)
    for x in (-W / 2 + 0.3, -W / 6, W / 6, W / 2 - 0.3):                                    # the frame's posts
        b.box_base((x, -D / 2 + 0.1, 1.2), (0.5, 0.3, 5.8), WOOD_DARK, bevel=False)
        b.box_base((x, -D / 2 - 0.82, 7.5), (0.5, 0.3, 4.5), WOOD_DARK, bevel=False)
    for sx in (-1, 1):                                                                      # braces on the upper floor
        b.box((sx * W / 3, -D / 2 - 0.84, 9.7), (0.4, 0.26, 5.4), WOOD_DARK, bevel=False, rot=(sx * 0.75, "Y"))
    b.box_base((0, -D / 2 - 0.82, 11.6), (W, 0.34, 0.5), WOOD_DARK, bevel=False)
    a = math.atan2(5.2, (D + 2.6) / 2)
    L = math.hypot(5.2, (D + 2.6) / 2) + 0.6
    for sy in (-1, 1):                                                                      # the roof's two slabs
        b.box((0, -0.5 + sy * (D + 2.6) / 4, 14.4), (W + 1.6, L, 0.5), roof, bevel=False, rot=(-sy * a, "X"))
    for sx in (-1, 1):                                                                      # gable ends, stepped
        for j in range(4):
            wd = (D + 0.6) * (1 - (j + 0.5) / 4.4)
            b.box_base((sx * (W / 2 - 0.25), -0.5, 12.0 + 1.2 * j), (0.5, wd, 1.22), PLASTER, bevel=False)
    b.box_base((W / 2 - 2.6, 2.0, 12.0), (1.8, 1.8, 6.6), STONE_DARK, bevel=False)          # the chimney
    b.box_base((-W / 4 + 0.4 * (k % 2), -D / 2 - 0.02, 1.2), (2.6, 0.24, 4.4), WOOD, bevel=False)   # the door
    b.box_base((-W / 4 + 0.4 * (k % 2), -D / 2 - 0.06, 1.2), (0.16, 0.26, 4.4), WOOD_DARK, bevel=False)
    for (x, z) in ((W / 4, 3.2), (-W / 4, 8.6), (W / 4, 8.6)):
        y = -D / 2 - (0.84 if z > 7 else 0.02)
        b.box_base((x, y, z), (3.0, 0.2, 2.6), WOOD_DARK, bevel=False)
        p.box_base((x, y - 0.08, z + 0.25), (2.4, 0.08, 2.1), "lamp_warm", bevel=False)
        b.box_base((x, y - 0.14, z + 0.25), (0.14, 0.06, 2.1), WOOD_DARK, bevel=False)
        b.box((x, y - 0.5, z - 0.1), (3.2, 0.9, 0.5), (RED, GREEN, NAVY)[(k + int(x > 0)) % 3], bevel=False)   # a window box
    house = b.finalize(N + "TimberHouse", mat)
    if smoking:
        smoke(house, (W / 2 - 2.6, 2.0, 18.6))
    return [house, p.finalize(N + "TimberHouse_Pane", mat)]


def market_stall(mat, k=0):
    """A market stall, 14 wide and 10 deep (front -Y): a plank counter under a striped awning on four posts, a back
    board with a banner, and its goods: bread, cheese wheels or bolts of cloth. Scenery only."""
    b = Builder()
    W, D = HOUSE_W, HOUSE_D
    c = BANNERS[k % 4]
    b.box_base((0, 0, 0), (W - 1.0, D - 1.0, 0.2), WOOD, bevel=False)
    b.box_base((0, -D / 2 + 1.4, 0), (W - 1.0, 2.2, 3.0), WOOD_DARK, bevel=False)
    b.box_base((0, -D / 2 + 1.3, 3.0), (W, 2.8, 0.3), WOOD, bevel=False)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box_base((sx * (W / 2 - 0.4), sy * (D / 2 - 0.5), 0), (0.5, 0.5, 8.4 if sy > 0 else 7.2), WOOD_DARK,
                       bevel=False)
    b.box_base((0, D / 2 - 0.5, 0), (W - 1.0, 0.4, 8.0), WOOD, bevel=False)
    n = 7
    w = (W + 1.0) / n
    a = math.atan2(1.4, D + 1.4)
    for i in range(n):
        x = -W / 2 - 0.5 + (i + 0.5) * w
        b.box((x, -0.6, 8.0), (w + 0.02, math.hypot(D + 1.6, 1.4), 0.3 + 0.02 * (i % 2)), (c, MILK)[i % 2], bevel=False,
              rot=(a, "X"))
        b.box((x, -D / 2 - 1.35, 6.75), (w * 0.9, 0.12, 0.8), (MILK, c)[i % 2], bevel=False)
    _banner(b, 0, D / 2 - 0.72, 5.6, 2.6, 3.2, c)
    kind = k % 3
    for i in range(6):
        x = -W / 2 + 1.8 + i * (W - 3.6) / 5
        if kind == 0:                                                     # loaves
            b.ico((x, -D / 2 + 1.3, 3.6), 0.6, ("fur_golden", "fur_toffee")[i % 2], subdivisions=1, scale=(1.3, 0.8, 0.6))
        elif kind == 1:                                                   # cheese wheels
            b.cyl_base((x, -D / 2 + 1.3, 3.3), 0.7, 0.5 + 0.3 * (i % 2), ("pastel_butter", "fur_golden")[i % 2], segments=10,
                       bevel=False)
        else:                                                             # bolts of cloth
            b.cyl((x, -D / 2 + 1.3, 3.75), 0.45, 2.2, BANNERS[i % 4], segments=8, rot=(PI / 2, "X"), bevel=False)
    b.box_base((W / 2 - 2.4, 1.2, 0.2), (2.2, 2.2, 2.0), "cardboard", bevel=False)           # a crate behind
    b.cyl_base((-W / 2 + 2.4, 1.4, 0.2), 1.1, 2.4, WOOD, segments=10, bevel=False)           # and a barrel
    return [b.finalize(N + "MarketStall", mat)]


def tilt_fence(mat, L):
    """The tilt: a low rail L long along local x, 1.3 high, posts every 6 and a striped cloth along it."""
    b = Builder()
    n = round(L / 6.0)
    for i in range(n + 1):
        b.box_base((-L / 2 + i * L / n, 0, 0), (0.5, 0.5, 1.5), WOOD_DARK, bevel=False)
    b.box_base((0, 0, 1.0), (L, 0.3, 0.3), WOOD, bevel=False)
    for i in range(n * 2):
        b.box_base((-L / 2 + (i + 0.5) * L / (n * 2), 0, 0.15), (L / (n * 2) - 0.06, 0.12, 0.85 + 0.01 * (i % 2)),
                   (RED, MILK)[i % 2], bevel=False)
    return [b.finalize(N + "TiltFence", mat)]


def joust_stand(mat, k=0):
    """A viewing stand, 40 long and 9 deep, 9 high at its back (front -Y): three stepped benches on a timber frame,
    a striped canopy on poles, a banner on each end post and shields along its front."""
    b = Builder()
    L, D = 40.0, 9.0
    c = (RED, NAVY)[k % 2]
    for j in range(3):
        b.box_base((0, -D / 2 + 1.5 + 3.0 * j, 0), (L, 3.0, 1.6 + 1.8 * j), WOOD if j % 2 == 0 else "fur_brown", bevel=False)
        b.box_base((0, -D / 2 + 1.9 + 3.0 * j, 1.6 + 1.8 * j), (L - 1.0, 1.4, 0.5), WOOD_DARK, bevel=False)
    b.box_base((0, -D / 2 - 0.1, 0), (L, 0.3, 2.2), c, bevel=False)
    for i in range(8):
        x = -L / 2 + 2.5 + i * (L - 5.0) / 7
        b.box((x, -D / 2 - 0.32, 1.3), (1.3, 0.16, 1.5), BANNERS[(i + k) % 4], bevel=False)
        b.box((x, -D / 2 - 0.42, 1.3), (0.5, 0.08, 0.5), GOLD, bevel=False, rot=(PI / 4, "Y"))
    n = 10
    w = L / n
    for i in range(n + 1):
        if i % 2 == 0:
            for y in (-D / 2 + 0.3, D / 2 - 0.3):
                b.box_base((-L / 2 + i * w, y, 0), (0.4, 0.4, 11.0 if y < 0 else 12.4), WOOD_DARK, bevel=False)
    a = math.atan2(1.4, D)
    for i in range(n):
        b.box((-L / 2 + (i + 0.5) * w, 0, 11.9), (w + 0.02, math.hypot(D + 1.4, 1.4), 0.3 + 0.02 * (i % 2)),
              (c, MILK)[i % 2], bevel=False, rot=(-a, "X"))
    for sx in (-1, 1):
        b.box_base((sx * L / 2, D / 2 - 0.3, 12.4), (0.3, 0.3, 3.4), WOOD_DARK, bevel=False)
        b.box((sx * L / 2 + 1.1, D / 2 - 0.3, 14.9), (2.0, 0.08, 1.3), c, bevel=False)
    return [b.finalize(N + "JoustStand", mat)]


def pavilion(mat, k=0):
    """A knight's round pavilion, 12 across and 12 high: a striped cloth drum, a cone roof with a scalloped edge, a
    pole with a pennant and a shield on a stand by its door (front -Y)."""
    b = Builder()
    c = (RED, NAVY, GREEN)[k % 3]
    n = 12
    for i in range(n):
        a = 2 * PI * (i + 0.5) / n
        if abs(a - 1.5 * PI) < 0.3:
            continue                                                      # the door, toward -Y
        b.box((5.8 * math.cos(a), 5.8 * math.sin(a), 3.0), (3.15, 0.3, 6.0), (c, MILK)[i % 2], bevel=False,
              rot=(a + PI / 2, "Z"))
    b.cyl_base((0, 0, 6.0), 6.6, 0.7, c, segments=n, bevel=False)
    b.cyl_base((0, 0, 6.7), 6.4, 4.4, MILK, segments=n, radius2=0.4, bevel=False)
    b.cyl_base((0, 0, 9.0), 3.3, 2.2, c, segments=n, radius2=0.5, bevel=False)
    b.cyl_base((0, 0, 11.0), 0.12, 3.0, IRON, segments=6, bevel=False)
    b.box((1.0, 0, 13.3), (2.0, 0.08, 1.1), GOLD, bevel=False)
    b.box_base((4.6, -7.4, 0), (0.3, 0.3, 3.0), WOOD_DARK, bevel=False)
    b.box((4.6, -7.6, 2.4), (1.8, 0.2, 2.2), c, bevel=False)
    b.box((4.6, -7.74, 2.4), (0.7, 0.1, 0.7), GOLD, bevel=False, rot=(PI / 4, "Y"))
    return [b.finalize(N + "Pavilion", mat)]


def archery_butt(mat):
    """A straw archery butt on a wooden easel, its rings facing -Y, 4.5 high."""
    b = Builder()
    for sx in (-1, 1):
        b.box((sx * 1.0, 0.5, 2.32), (0.3, 0.3, 4.6), WOOD_DARK, bevel=False, rot=(0.2, "X"))
    b.box((0, 1.6, 2.18), (0.3, 0.3, 4.4), WOOD_DARK, bevel=False, rot=(-0.3, "X"))
    for r, c, y in ((1.9, STRAW, 0.0), (1.5, MILK, -0.42), (1.05, RED, -0.46), (0.6, NAVY, -0.5), (0.25, GOLD, -0.54)):
        b.cyl((0, y, 2.9), r, 0.8 if r > 1.8 else 0.06, c, segments=14, rot=(PI / 2, "X"), bevel=False)
    return [b.finalize(N + "ArcheryButt", mat)]


def practice_dummy(mat, k=0):
    """A training dummy: a straw body on a post with a wooden cross arm, a bucket helm and a little round shield."""
    b = Builder()
    b.box_base((0, 0, 0), (1.4, 1.4, 0.3), WOOD_DARK, bevel=False)
    b.box_base((0, 0, 0.3), (0.4, 0.4, 3.0), WOOD_DARK, bevel=False)
    b.cyl_base((0, 0, 2.2), 0.9, 2.2, STRAW, segments=8, bevel=False)
    b.box((0, 0, 3.7), (4.0, 0.3, 0.3), WOOD, bevel=False)
    b.cyl_base((0, 0, 4.4), 0.7, 1.1, STONE_LIGHT, segments=8, bevel=False)
    b.box((0, -0.72, 5.0), (0.9, 0.06, 0.14), IRON, bevel=False)
    b.cyl((-1.8, -0.3, 3.4), 0.8, 0.14, BANNERS[k % 4], segments=10, rot=(PI / 2, "X"), bevel=False)
    b.box((1.9, 0, 3.0), (0.16, 0.16, 1.6), WOOD, bevel=False)             # a wooden practice sword
    return [b.finalize(N + "PracticeDummy", mat)]


def weapon_rack(mat):
    """A rack of wooden practice swords and two painted shields (toys: young audience)."""
    b = Builder()
    for sx in (-1, 1):
        b.box_base((sx * 2.2, 0, 0), (0.3, 1.2, 3.4), WOOD_DARK, bevel=False)
    for z in (1.0, 2.9):
        b.box((0, 0, z), (4.4, 0.3, 0.3), WOOD_DARK, bevel=False)
    for i in range(4):
        x = -1.5 + i * 1.0
        b.box((x, -0.3, 2.0), (0.2, 0.14, 3.0), WOOD, bevel=False, rot=(0.12, "X"))
        b.box((x, -0.38, 1.1), (0.7, 0.14, 0.16), WOOD, bevel=False)
    for sx, c in ((-1, RED), (1, NAVY)):
        b.cyl((sx * 3.3, -0.2, 1.1), 1.0, 0.16, c, segments=10, rot=(PI / 2, "X"), bevel=False)
        b.ico((sx * 3.3, -0.32, 1.1), 0.25, GOLD, subdivisions=1)
    return [b.finalize(N + "WeaponRack", mat)]


def banner_pole(mat, k=0, h=11.0):
    """A banner on a tall pole with a cross bar, on a stone foot. The banner is its own object (_Swing) hung from
    the bar, so Motion sways it."""
    b = Builder()
    b.cyl_base((0, 0, 0), 0.9, 0.5, STONE_DARK, segments=8, bevel=False)
    b.cyl_base((0, 0, 0.5), 0.18, h, WOOD_DARK, segments=6, bevel=False)
    b.ico((0, 0, h + 0.7), 0.3, GOLD, subdivisions=1)
    b.box((0, 0.15, h - 0.28), (0.14, 0.36, 0.14), WOOD_DARK, bevel=False)      # the arm the banner hangs from
    c = Builder()                    # the cloth and its bar sway on the arm: the child Model ..._BannerPole_Swing
    _banner(c, 0, 0.3, h - 2.6, 2.6, 4.4, BANNERS[k % 4])
    return [b.finalize(N + "BannerPole", mat), hinge(c.finalize(N + "BannerPole_Swing", mat), (0, 0.3, h - 0.28))]


def moat(mat):
    """The moat across the width: a kerb 0.7 high each side of shallow water (_Water), lily pads on it."""
    b, w = Builder(), Builder()
    L = 2 * IN_X
    D = MOAT_Z1 - MOAT_Z0
    for sy in (-1, 1):
        b.box_base((0, sy * (D / 2 + 0.3), 0), (L, 0.6, 0.7), STONE_DARK, bevel=False)
    b.box_base((0, 0, 0), (L, D, 0.12), "puddle", bevel=False)
    w.box_base((0, 0, 0.12), (L, D, 0.3), WATER, bevel=False)
    for i in range(9):
        x = -L / 2 + 8.0 + i * (L - 16.0) / 8
        if abs(x) < 11.0 or abs(-x - POSTERN_X) < 7.0:
            continue
        b.cyl_base((x, 2.5 * math.sin(i * 2.3), 0.42), 1.0, 0.06, GREEN, segments=8, bevel=False)
    return [b.finalize(N + "Moat", mat), w.finalize(N + "Moat_Water", mat)]


def drawbridge(mat, W=16.0):
    """The drawbridge, down: a plank deck W wide from the gate out over the moat (local -Y), 0.9 up with a short
    ramp at its outer end, iron bands, and a chain each side up to the gatehouse (_Decor)."""
    b, d = Builder(), Builder()
    D = MOAT_Z1 - MOAT_Z0 + 4.0
    n = 8
    for i in range(n):
        b.box_base((-W / 2 + (i + 0.5) * W / n, -D / 2, 0.6), (W / n - 0.06, D, 0.3 + 0.01 * (i % 2)), (WOOD, "fur_brown")[i % 2],
                   bevel=False)
    for y in (-2.0, -D / 2, -D + 2.0):
        b.box_base((0, y, 0.6), (W + 0.3, 0.5, 0.36), IRON, bevel=False)
    b.box((0, -D - 1.3, 0.6), (W, 3.0, 0.3), WOOD, bevel=False, rot=(0.3, "X"))            # the outer ramp
    b.box((0, 1.3, 0.6), (W, 3.0, 0.3), WOOD, bevel=False, rot=(-0.3, "X"))                # the inner ramp
    for sx in (-1, 1):
        L = math.hypot(D - 2.0, 13.0)
        d.box((sx * (W / 2 - 0.3), -(D - 2.0) / 2, 7.4), (0.2, L, 0.2), IRON, bevel=False,
              rot=(-math.atan2(13.0, D - 2.0), "X"))
    return [b.finalize(N + "Drawbridge", mat), d.finalize(N + "Drawbridge_Decor", mat)]


def plank_bridge(mat, W=8.0):
    """A little plank bridge over the moat for the postern path (local Y across the moat), 0.9 up, a rail each side."""
    b = Builder()
    D = MOAT_Z1 - MOAT_Z0 + 3.0
    b.box_base((0, 0, 0.6), (W, D, 0.3), WOOD, bevel=False)
    for sy in (-1, 1):
        b.box((0, sy * (D / 2 + 1.2), 0.6), (W, 2.8, 0.3), WOOD, bevel=False, rot=(-sy * 0.3, "X"))
    for sx in (-1, 1):
        b.box_base((sx * (W / 2 - 0.2), 0, 0.9), (0.3, D, 0.25), WOOD_DARK, bevel=False)
        b.box_base((sx * (W / 2 - 0.2), 0, 2.0), (0.3, D, 0.25), WOOD_DARK, bevel=False)
        for y in (-D / 2 + 0.3, 0, D / 2 - 0.3):
            b.box_base((sx * (W / 2 - 0.2), y, 0.9), (0.35, 0.35, 1.4), WOOD_DARK, bevel=False)
    return [b.finalize(N + "PlankBridge", mat)]


def _merlons(b, x0, x1, y, z, depth, sw, step=3.2):
    n = max(2, round((x1 - x0) / step))
    w = (x1 - x0) / n
    for i in range(n):
        b.box_base((x0 + (i + 0.5) * w, y, z), (w * 0.55, depth, 1.6), sw, bevel=False)


def curtain_wall(mat):
    """The curtain wall across the width, WALL_H high and 8 thick, built round the area's middle line (local y 0 is
    its middle, front -Y): open at the gate (16 wide, the gatehouse fills it) and at the postern (8 wide, an arched
    passage 9 high), merlons along both edges of its walk, banners on its front."""
    b = Builder()
    T = WALL_Z1 - WALL_Z0
    runs = ((-IN_X, -GATEHOUSE[1]), (GATEHOUSE[1], POSTERN_X - POSTERN_HALF), (POSTERN_X + POSTERN_HALF, IN_X))
    for k, (x0, x1) in enumerate(runs):                                    # Roblox x: Blender x is its mirror
        cx, L = -(x0 + x1) / 2, x1 - x0
        b.box_base((cx, 0, 0), (L, T + 0.6, 1.6), STONE_DARK, bevel=False)
        b.box_base((cx, 0, 1.6), (L, T, WALL_H - 1.6), STONE, bevel=False)
        for z in (7.0, 13.0):
            for sy in (-1, 1):
                b.box((cx, sy * (T / 2 + 0.03), z), (L, 0.08, 0.22), STONE_DARK, bevel=False)
        b.box_base((cx, 0, WALL_H), (L, T + 0.8, 0.5), STONE_DARK, bevel=False)
        for sy in (-1, 1):
            _merlons(b, cx - L / 2, cx + L / 2, sy * (T / 2 - 0.2), WALL_H + 0.5, 1.2, STONE_LIGHT)
        nb = max(1, round(L / 22.0))
        for i in range(nb):
            _banner(b, cx - L / 2 + (i + 0.5) * L / nb, -T / 2, 12.0, 3.4, 7.0, BANNERS[(i + k) % 4])
    px = -POSTERN_X                                                        # the postern's arch
    b.box_base((px, 0, 9.0), (2 * POSTERN_HALF, T, WALL_H - 9.0), STONE, bevel=False)
    b.box_base((px, 0, 8.4), (2 * POSTERN_HALF + 0.02, T + 0.5, 0.7), STONE_DARK, bevel=False)
    b.box_base((px, 0, WALL_H), (2 * POSTERN_HALF, T + 0.8, 0.5), STONE_DARK, bevel=False)
    for sy in (-1, 1):
        _merlons(b, px - POSTERN_HALF, px + POSTERN_HALF, sy * (T / 2 - 0.2), WALL_H + 0.5, 1.2, STONE_LIGHT)
    return [b.finalize(N + "CurtainWall", mat)]


def gatehouse(mat):
    """The gatehouse (pivot on the middle line at the wall's front, front -Y): two square towers 26 high either side
    of the 16 wide way, a block over it from 15 up with the portcullis raised into it (its lower bars show), arrow
    slits, merlons, a torch each side (_Glow) and the castle's banner over the arch."""
    b, g = Builder(), Builder()
    x0, x1, z0, z1, H = GATEHOUSE
    D = z1 - z0
    for sx in (-1, 1):
        cx = sx * (x0 + x1) / 2
        W = x1 - x0
        b.box_base((cx, D / 2, 0), (W + 0.6, D + 0.6, 2.0), STONE_DARK, bevel=False)
        b.box_base((cx, D / 2, 2.0), (W, D, H - 2.0), STONE_LIGHT, bevel=False)
        b.box_base((cx, D / 2, H), (W + 1.0, D + 1.0, 0.6), STONE_DARK, bevel=False)
        for sy in (0, 1):
            _merlons(b, cx - W / 2 - 0.3, cx + W / 2 + 0.3, sy * D + (0.3 if sy == 0 else -0.3), H + 0.6, 1.2, STONE)
        for z in (9.0, 17.0):
            b.box((cx, -0.03, z), (0.5, 0.08, 2.4), IRON, bevel=False)
        b.box((cx - sx * (W / 2 - 0.6), -0.5, 7.0), (0.3, 1.0, 0.3), IRON, bevel=False)
        b.cyl_base((cx - sx * (W / 2 - 0.6), -1.0, 6.7), 0.45, 0.6, IRON, segments=8, radius2=0.6, bevel=False)
        g.cyl_base((cx - sx * (W / 2 - 0.6), -1.0, 7.2), 0.42, 1.2, "fur_orange", segments=6, radius2=0.05, bevel=False)
        g.cyl_base((cx - sx * (W / 2 - 0.6), -1.0, 7.2), 0.24, 0.8, "pastel_butter", segments=6, radius2=0.03, bevel=False)
    b.box_base((0, D / 2, 15.0), (2 * x0, D, H - 17.0), STONE, bevel=False)                  # over the way
    b.box_base((0, D / 2, 14.3), (2 * x0 + 0.02, D + 0.5, 0.8), STONE_DARK, bevel=False)
    b.box_base((0, D / 2, H - 2.0), (2 * x0, D + 0.6, 0.5), STONE_DARK, bevel=False)
    for sy in (0, 1):
        _merlons(b, -x0, x0, sy * D + (0.3 if sy == 0 else -0.3), H - 1.5, 1.2, STONE_LIGHT)
    for i in range(9):                                                     # the portcullis' lower bars
        x = -x0 + 0.9 + i * (2 * x0 - 1.8) / 8
        b.box_base((x, 1.2, 12.2), (0.3, 0.3, 2.2), IRON, bevel=False)
        b.cyl_base((x, 1.2, 11.7), 0.22, 0.5, IRON, segments=4, radius2=0.02, bevel=False)
    b.box_base((0, 1.2, 13.3), (2 * x0 - 0.6, 0.3, 0.3), IRON, bevel=False)
    _banner(b, 0, 0.0, 19.4, 4.4, 6.0, RED)
    return [b.finalize(N + "Gatehouse", mat), g.finalize(N + "Gatehouse_Glow", mat)]


def round_tower(mat, r=7.0, h=30.0, k=0):
    """A round tower: a darker foot, grey stone with two course rings, a wider top with merlons, a cone roof, a
    pennant, arrow slits and a lit window (_Pane)."""
    b, p = Builder(), Builder()
    b.cyl_base((0, 0, 0), r + 0.4, 2.0, STONE_DARK, segments=14, bevel=False)
    b.cyl_base((0, 0, 2.0), r, h - 6.0, (STONE, STONE_LIGHT)[k % 2], segments=14, bevel=False)
    for z in (h * 0.35, h * 0.6):
        b.cyl_base((0, 0, z), r + 0.12, 0.3, STONE_DARK, segments=14, bevel=False)
    b.cyl_base((0, 0, h - 4.0), r + 0.9, 1.6, STONE_DARK, segments=14, bevel=False)
    for i in range(10):
        a = 2 * PI * i / 10
        b.box_base(((r + 0.4) * math.cos(a), (r + 0.4) * math.sin(a), h - 2.4), (1.6, 1.0, 1.5), STONE_LIGHT, bevel=False,
                   rot=(a + PI / 2, "Z"))
    b.cyl_base((0, 0, h - 2.4), r - 0.6, 6.5, (RED, NAVY)[k % 2], segments=14, radius2=0.2, bevel=False)
    b.cyl_base((0, 0, h + 4.0), 0.1, 3.0, IRON, segments=6, bevel=False)
    b.box((1.1, 0, h + 6.2), (2.2, 0.08, 1.2), GOLD, bevel=False)
    for i in range(3):
        a = -PI / 2 + (i - 1) * 0.9
        b.box(((r + 0.02) * math.cos(a), (r + 0.02) * math.sin(a), h * 0.45), (0.5, 0.12, 2.4), IRON, bevel=False,
              rot=(a + PI / 2, "Z"))
    p.box((0, -r - 0.02, h * 0.72), (1.6, 0.1, 2.2), "lamp_warm", bevel=False)
    return [b.finalize(N + "RoundTower", mat), p.finalize(N + "RoundTower_Pane", mat)]


def stables(mat):
    """The stables, 16 wide and 10 deep, 9 high (front -Y): three open stalls with half doors under a thatched lean-to
    roof, hay inside, a trough in front."""
    b = Builder()
    W, D = STABLES[2], STABLES[3]
    b.box_base((0, D / 2 - 0.3, 0), (W, 0.6, 7.4), WOOD, bevel=False)
    for i in range(4):
        x = -W / 2 + i * W / 3
        b.box_base((x, 0, 0), (0.5, D, 6.0 + 0.0), WOOD_DARK, bevel=False)
    for i in range(3):
        x = -W / 2 + (i + 0.5) * W / 3
        b.box_base((x, -D / 2 + 0.2, 0), (W / 3 - 0.6, 0.3, 2.6), "fur_brown", bevel=False)
        b.box_base((x, 1.5, 0), (W / 3 - 1.0, D - 4.0, 1.0 + 0.4 * (i % 2)), STRAW, bevel=False)
    a = math.atan2(2.4, D + 2.0)
    b.box((0, -0.6, 7.0), (W + 1.6, math.hypot(D + 2.4, 2.4), 0.7), "fur_sand", bevel=False, rot=(a, "X"))
    b.box_base((0, -D / 2 - 2.4, 0), (5.0, 1.4, 1.2), WOOD_DARK, bevel=False)
    b.box_base((0, -D / 2 - 2.4, 1.0), (4.4, 0.9, 0.22), WATER, bevel=False)
    return [b.finalize(N + "Stables", mat)]


def old_oak(mat):
    """The courtyard's old oak in a round stone ring (no grass: the ring holds dark earth), a bench round its trunk."""
    b = Builder()
    r = OAK[2]
    b.ring((0, 0, 0.8), r, 1.0, 1.6, STONE, segments=14, bevel=False)
    b.cyl_base((0, 0, 0), r - 0.9, 1.3, "fur_brown", segments=14, bevel=False)
    b.cyl_base((0, 0, 1.3), 1.6, 9.0, WOOD_DARK, segments=8, radius2=1.1, bevel=False)
    for (x, y, z, s) in ((0, 0, 14.0, 6.5), (3.6, 1.0, 11.6, 4.2), (-3.4, -1.4, 12.0, 4.4), (0.6, 3.4, 12.4, 3.8),
                         (-0.8, -3.6, 11.4, 3.6)):
        b.ico((x, y, z), s, ("leaf_dark", GREEN)[int(abs(x) > 1)], subdivisions=1, scale=(1.0, 1.0, 0.72))
    return [b.finalize(N + "OldOak", mat)]


def keep_walls(mat):
    """The Throne Hall's walls, roofless (area space, pivot at the area's centre): the front at z KEEP_Z0 with its 16
    wide door, the side walls at x +-KEEP_X with a 10 wide door each at z SIDE_DOOR_Z, KEEP_H high with merlons, tall
    lit windows (_Pane), banners inside, a round tower at each front corner."""
    b, p = Builder(), Builder()
    T, H = KEEP_T, KEEP_H

    def wall(x0, x1, z0, z1, door=False):
        cx, cz = -(x0 + x1) / 2, (z0 + z1) / 2
        sx, sz = abs(x1 - x0), abs(z1 - z0)
        if door:                                                           # the lintel over a door, from 11 up
            b.box_base((cx, cz, 11.0), (sx, sz, H - 11.0), STONE, bevel=False)
            b.box_base((cx, cz, 10.3), (sx + (0.02 if sx > sz else 0.5), sz + (0.5 if sx > sz else 0.02), 0.8), STONE_DARK,
                       bevel=False)
        else:
            b.box_base((cx, cz, 0), (sx + 0.5, sz + 0.5, 1.8), STONE_DARK, bevel=False)
            b.box_base((cx, cz, 1.8), (sx, sz, H - 1.8), STONE, bevel=False)
        b.box_base((cx, cz, H), (sx + 0.7, sz + 0.7, 0.5), STONE_DARK, bevel=False)
        if sx > sz:
            _merlons(b, cx - sx / 2, cx + sx / 2, cz, H + 0.5, sz - 0.6, STONE_LIGHT)
        else:
            n = max(2, round(sz / 3.2))
            for i in range(n):
                b.box_base((cx, cz - sz / 2 + (i + 0.5) * sz / n, H + 0.5), (sx - 0.6, sz / n * 0.55, 1.6), STONE_LIGHT,
                           bevel=False)

    zf = KEEP_Z0 + T / 2
    for sx in (-1, 1):
        wall(sx * DOOR_HALF, sx * (KEEP_X + T / 2), KEEP_Z0, KEEP_Z0 + T)
        wall(sx * (KEEP_X - T / 2), sx * (KEEP_X + T / 2), KEEP_Z0 + T, SIDE_DOOR_Z - SIDE_DOOR_HALF)
        wall(sx * (KEEP_X - T / 2), sx * (KEEP_X + T / 2), SIDE_DOOR_Z + SIDE_DOOR_HALF, KEEP_Z1)
        wall(sx * (KEEP_X - T / 2), sx * (KEEP_X + T / 2), SIDE_DOOR_Z - SIDE_DOOR_HALF, SIDE_DOOR_Z + SIDE_DOOR_HALF, door=True)
        for i, z in enumerate((196.0, 210.0, 242.0, 258.0)):               # windows and banners down the side walls
            x = -sx * (KEEP_X - T / 2 - 0.03)
            p.box((x, z, 11.0), (0.1, 2.4, 7.0), "lamp_warm", bevel=False)
            b.box((x + sx * 0.02, z, 14.9), (0.12, 3.0, 0.5), STONE_DARK, bevel=False)
            b.box((x + sx * 0.03, z + 5.0, 11.0), (0.1, 2.8, 8.0), BANNERS[(i + (sx > 0)) % 4], bevel=False)
            b.box((x + sx * 0.06, z + 5.0, 12.0), (0.08, 1.1, 1.1), GOLD, bevel=False, rot=(PI / 4, "X"))
        for x in (sx * 20.0, sx * 38.0):                                   # banners on the front, outside
            _banner(b, -x, KEEP_Z0, 12.0, 3.4, 7.0, BANNERS[int(abs(x) > 30) + (sx > 0)])
    wall(-DOOR_HALF, DOOR_HALF, KEEP_Z0, KEEP_Z0 + T, door=True)
    _banner(b, 0, KEEP_Z0, 16.6, 4.4, 5.0, RED)
    b.box((0, zf, 23.6), (0.01, 0.01, 0.01), STONE, bevel=False)
    return [b.finalize(N + "KeepWalls", mat), p.finalize(N + "KeepWalls_Pane", mat)]


def column(mat, k=0):
    """A stone column 18 high with a banner hung on its inner face and a torch (_Glow)."""
    b, g = Builder(), Builder()
    b.box_base((0, 0, 0), (3.4, 3.4, 1.2), STONE_DARK, bevel=False)
    b.cyl_base((0, 0, 1.2), 1.3, 15.6, STONE_LIGHT, segments=10, bevel=False)
    b.box_base((0, 0, 16.8), (3.6, 3.6, 1.2), STONE_DARK, bevel=False)
    _banner(b, 0, -1.34, 11.0, 2.2, 5.0, BANNERS[k % 4])
    b.cyl_base((0, -1.9, 5.6), 0.4, 0.6, IRON, segments=8, radius2=0.55, bevel=False)
    b.box((0, -1.6, 5.7), (0.25, 0.7, 0.25), IRON, bevel=False)
    g.cyl_base((0, -1.9, 6.1), 0.38, 1.1, "fur_orange", segments=6, radius2=0.05, bevel=False)
    g.cyl_base((0, -1.9, 6.1), 0.2, 0.7, "pastel_butter", segments=6, radius2=0.03, bevel=False)
    return [b.finalize(N + "Column", mat), g.finalize(N + "Column_Glow", mat)]


def long_table(mat, L=36.0):
    """A feast table L long along local y, 4 wide and 3 high: a cloth runner, plates, goblets, bread and a roast
    pie, a bench each side."""
    b = Builder()
    b.box_base((0, 0, 2.6), (4.0, L, 0.4), WOOD, bevel=False)
    b.box_base((0, 0, 3.0), (1.8, L - 1.0, 0.06), RED, bevel=False)
    n = round(L / 6.0)
    for i in range(n + 1):
        y = -L / 2 + 0.8 + i * (L - 1.6) / n
        for sx in (-1, 1):
            b.box_base((sx * 1.5, y, 0), (0.5, 0.5, 2.6), WOOD_DARK, bevel=False)
    for sx in (-1, 1):
        b.box_base((sx * 3.4, 0, 1.3), (1.3, L - 2.0, 0.3), WOOD, bevel=False)
        for i in range(n):
            b.box_base((sx * 3.4, -L / 2 + 3.0 + i * (L - 6.0) / max(1, n - 1), 0), (0.9, 0.5, 1.3), WOOD_DARK, bevel=False)
    m = round(L / 4.5)
    for i in range(m):
        y = -L / 2 + 2.4 + i * (L - 4.8) / (m - 1)
        for sx in (-1, 1):
            b.cyl_base((sx * 1.35, y, 3.0), 0.55, 0.08, MILK, segments=8, bevel=False)
            b.cyl_base((sx * 1.35, y + 0.9, 3.0), 0.2, 0.6, GOLD, segments=6, radius2=0.28, bevel=False)
        if i % 3 == 0:
            b.ico((0, y, 3.4), 0.6, "fur_golden", subdivisions=1, scale=(1.0, 1.5, 0.6))
        elif i % 3 == 1:
            b.cyl_base((0, y, 3.06), 0.8, 0.5, "fur_toffee", segments=10, bevel=False)
            b.cyl_base((0, y, 3.56), 0.7, 0.1, "fur_golden", segments=10, bevel=False)
        else:
            b.cyl_base((0, y, 3.06), 0.16, 1.3, MILK, segments=6, bevel=False)
            b.ico((0, y, 4.5), 0.2, "fur_orange", subdivisions=1, scale=(1, 1, 1.5))
    return [b.finalize(N + "LongTable", mat)]


def throne_dais(mat):
    """The throne on its steps (pivot at the dais' middle, front -Y): three steps 24 wide, a red carpet up them, the
    gold throne with a tall back, a cushion and a paw crest, a banner pole each side, a great banner behind."""
    b = Builder()
    W, D = DAIS[2], DAIS[3]
    for j in range(3):
        b.box_base((0, 1.2 * j, 0), (W - 2.4 * j, D - 2.4 * j, 0.9 * (j + 1)), (STONE_LIGHT, STONE)[j % 2], bevel=False)
        b.box_base((0, -D / 2 + 1.2 * j + 0.62, 0.9 * j), (5.0, 1.26, 0.9 + 0.05), RED, bevel=False)
    b.box_base((0, 1.2, 2.7), (5.0, D - 4.8, 0.06), RED, bevel=False)
    b.box_base((0, 3.2, 2.7), (5.0, 3.6, 1.6), GOLD, bevel=False)                            # the seat
    b.box_base((0, 3.0, 4.3), (4.2, 3.0, 0.6), RED, bevel=False)
    b.box_base((0, 4.7, 2.7), (5.0, 0.8, 9.4), GOLD, bevel=False)                            # the back
    b.box_base((0, 4.25, 5.2), (3.8, 0.12, 5.6), RED, bevel=False)
    b.cyl_base((0, 4.7, 12.1), 2.5, 1.6, GOLD, segments=3, bevel=False, radius2=0.1)
    for dx, dz in ((0, 0.0), (-0.75, 0.95), (-0.25, 1.35), (0.25, 1.35), (0.75, 0.95)):       # the paw crest
        b.box((dx, 4.16, 9.0 + dz), (1.1 if dz == 0 else 0.42, 0.1, 0.9 if dz == 0 else 0.42), GOLD, bevel=False)
    for sx in (-1, 1):
        b.box_base((sx * 2.9, 3.2, 2.7), (0.8, 3.6, 3.0), GOLD, bevel=False)
        b.ico((sx * 2.9, 1.6, 5.9), 0.5, RED, subdivisions=1)
        b.cyl_base((sx * 8.6, 3.0, 1.8), 0.18, 12.0, WOOD_DARK, segments=6, bevel=False)
        b.ico((sx * 8.6, 3.0, 14.1), 0.3, GOLD, subdivisions=1)
        _banner(b, sx * 8.6, 2.8, 10.6, 2.8, 5.0, (NAVY, GREEN)[sx > 0])
    return [b.finalize(N + "ThroneDais", mat)]


def armour_stand(mat, k=0):
    """A suit of armour on a wooden stand (empty: scenery), a red plume on its helm."""
    b = Builder()
    b.box_base((0, 0, 0), (1.8, 1.8, 0.3), WOOD_DARK, bevel=False)
    b.box_base((0, 0, 0.3), (0.3, 0.3, 2.2), WOOD_DARK, bevel=False)
    b.box_base((0, 0, 2.2), (1.9, 1.1, 2.2), STONE_LIGHT, bevel=False)
    for sx in (-1, 1):
        b.box_base((sx * 1.25, 0, 2.4), (0.6, 0.7, 1.9), STONE, bevel=False)
        b.ico((sx * 1.25, 0, 4.4), 0.5, STONE_LIGHT, subdivisions=1)
    b.cyl_base((0, 0, 4.4), 0.7, 1.2, STONE_LIGHT, segments=8, bevel=False)
    b.box((0, -0.72, 5.1), (0.9, 0.06, 0.16), IRON, bevel=False)
    b.ico((0, 0.2, 5.9), 0.45, BANNERS[k % 4], subdivisions=1, scale=(0.6, 1.2, 1.0))
    return [b.finalize(N + "ArmourStand", mat)]


# -------------------------------------------------------------------------------------------- rescue spots --
def trap_haystack(mat):
    """A haystack with a hollow in its middle: a ring of straw 2.0 high round the spot, loose straw round it."""
    b = Builder()
    b.ring((0, 0, 1.0), 2.9, 1.7, 2.0, STRAW, segments=12, bevel=False)
    b.ring((0, 0, 2.2), 2.6, 1.2, 0.5, "fur_sand", segments=12, bevel=False)
    b.cyl_base((0, 0, 0), 3.4, 0.08, "pastel_butter", segments=12, bevel=False)
    for k in range(6):
        a = 2 * PI * k / 6 + 0.3
        b.box((3.2 * math.cos(a), 3.2 * math.sin(a), 0.2), (0.12, 1.2, 0.12), STRAW, bevel=False, rot=(a + 0.7, "Z"))
    return [b.finalize(N + "TrapHaystack", mat)]


def trap_barrel(mat):
    """An open barrel 2.4 high with its lid leaning on it: the cat stands inside on a false floor (TRAP_BARREL_Y),
    head and front paws over the rim."""
    b = Builder()
    b.ring((0, 0, 1.2), 1.7, 0.3, 2.4, WOOD, segments=12, bevel=False)
    b.cyl_base((0, 0, 0), 1.45, TRAP_BARREL_Y, WOOD_DARK, segments=12, bevel=False)
    for z in (0.5, 1.9):
        b.ring((0, 0, z), 1.77, 0.12, 0.22, IRON, segments=12, bevel=False)
    b.cyl((2.3, 0.4, 1.45), 1.4, 0.2, WOOD_DARK, segments=12, rot=(1.2, "Y"), bevel=False)
    return [b.finalize(N + "TrapBarrel", mat)]


def trap_banner_pole(mat):
    """A low banner pole 5 high on a stone foot behind the spot (local +Y 0.5), a little banner at its top; a step
    block (TRAP_POLE_Y) under the cat that hugs it."""
    b = Builder()
    b.cyl_base((0, 0, 0), 1.5, 0.4, STONE_DARK, segments=10, bevel=False)
    b.cyl_base((0, 0, 0.4), 1.0, TRAP_POLE_Y - 0.4, STONE, segments=10, bevel=False)
    b.cyl_base((0, 0.75, 0), 0.2, 5.4, WOOD_DARK, segments=6, bevel=False)
    b.ico((0, 0.75, 5.6), 0.3, GOLD, subdivisions=1)
    b.box((0.9, 0.75, 4.6), (1.6, 0.08, 1.4), RED, bevel=False)
    return [b.finalize(N + "TrapBannerPole", mat)]


def trap_awning(mat):
    """A fallen stall awning: striped cloth draped from two broken poles behind the spot (local +Y) down to the
    ground in front, open toward local -Y so the cat peeks out from under it."""
    b = Builder()
    for sx in (-1, 1):
        b.box((sx * 2.2, 2.0, 1.42), (0.3, 0.3, 2.8), WOOD_DARK, bevel=False, rot=(sx * 0.25, "Y"))
    for i in range(6):
        x = -2.5 + i * 1.0
        b.box((x, 0.9, 2.3), (1.02, 3.2, 0.14 + 0.01 * (i % 2)), (RED, MILK)[i % 2], bevel=False, rot=(0.42, "X"))
    for sx in (-1, 1):
        b.box((sx * 3.1, 0.6, 1.48), (0.14, 2.6, 2.0), RED, bevel=False, rot=(0.3, "X"))
    b.box_base((2.6, -1.8, 0), (1.4, 1.4, 1.2), "cardboard", bevel=False)
    b.cyl_base((0, 0, 0), 3.0, 0.07, SAND_EDGE, segments=12, bevel=False)
    return [b.finalize(N + "TrapAwning", mat)]


def trap_helmet(mat):
    """An empty armour stand with a great helm big enough for a cat: a stone block (TRAP_HELMET_Y) the cat sits on,
    the helm's shell round it open at the visor toward local -Y, a plume on top."""
    b = Builder()
    b.box_base((0, 0, 0), (2.6, 2.6, 0.4), WOOD_DARK, bevel=False)
    b.box_base((0, 0, 0.4), (2.0, 2.0, TRAP_HELMET_Y - 0.4), STONE, bevel=False)
    for (x, y, sx, sy) in ((-1.25, 0.1, 0.3, 2.5), (1.25, 0.1, 0.3, 2.5), (0, 1.25, 2.8, 0.3)):
        b.box_base((x, y, TRAP_HELMET_Y), (sx, sy, 2.6), STONE_LIGHT, bevel=False)
    b.box_base((0, -1.15, TRAP_HELMET_Y), (2.8, 0.3, 0.7), STONE_LIGHT, bevel=False)
    b.box_base((0, -1.15, TRAP_HELMET_Y + 2.0), (2.8, 0.3, 0.6), STONE_LIGHT, bevel=False)
    b.box_base((0, 0.05, TRAP_HELMET_Y + 2.6), (2.8, 2.7, 0.3), STONE_LIGHT, bevel=False)
    b.ico((0, 0.3, TRAP_HELMET_Y + 3.5), 0.7, RED, subdivisions=1, scale=(0.6, 1.3, 1.0))
    return [b.finalize(N + "TrapHelmet", mat)]


def trap_hay_nook(mat):
    """The haystack cut down for the 8 x 7 nook: a low ring of straw 1.9 out round the spot, open toward local -Y,
    on loose straw. The same trap type as trap_haystack."""
    b = Builder()
    for k in range(7):
        a = PI / 2 + 2 * PI * (k + 0.5) / 8
        b.cyl_base((1.45 * math.cos(a), 1.45 * math.sin(a), 0.0), 0.5, 0.9 + 0.12 * (k % 3), (STRAW, "fur_sand")[k % 2],
                   segments=8, radius2=0.36, bevel=False)
    b.cyl_base((0, 0, 0), 1.9, 0.06, "pastel_butter", segments=12, bevel=False)
    return [b.finalize(N + "TrapHayNook", mat)]


TRAPS = {"trap_haystack": (trap_haystack, 4.0), "trap_barrel": (trap_barrel, 3.5),
         "trap_banner_pole": (trap_banner_pole, 2.5), "trap_awning": (trap_awning, 4.0),
         "trap_helmet": (trap_helmet, 2.5)}
TRAP_Y = {"trap_barrel": TRAP_BARREL_Y, "trap_banner_pole": TRAP_POLE_Y, "trap_helmet": TRAP_HELMET_Y}


def all_traps():
    out = [t for t in MAIN_TRAPS]
    for label, pool in (("trap_haystack", POOL_HAYSTACKS), ("trap_barrel", POOL_BARRELS),
                        ("trap_banner_pole", POOL_POLES), ("trap_awning", POOL_AWNINGS),
                        ("trap_helmet", POOL_HELMETS)):
        out += [(label, x, z, t) for (x, z, t) in pool]
    return out


def check_layout():
    """The rescue pool's rules (as the Desert's): 15 traps, every one 25 from every other, off the paths, the
    blockers and the moat, none within 100 of the camp; four of the five main ones and six of the pool deep."""
    traps = all_traps()
    assert len(traps) == 15, len(traps)
    for i, (la, xa, za, _) in enumerate(traps):
        assert near_trail(xa, za) > 3.0, (la, xa, za, near_trail(xa, za))
        assert not in_block(xa, za, 2.0), (la, xa, za)
        assert not in_moat(xa, za, 3.0), (la, xa, za)
        assert abs(xa) < IN_X - 3.0 and abs(za) < IN_Z - 3.0, (la, xa, za)
        assert za > -IN_Z + 100.0, (la, xa, za)
        for (lb, xb, zb, _) in traps[i + 1:]:
            assert math.hypot(xa - xb, za - zb) >= 25.0, (la, xa, za, lb, xb, zb)
    assert sum(1 for t in MAIN_TRAPS if t[2] > 0) == 4
    assert sum(1 for t in traps[5:] if t[2] > 0) == 6, [t for t in traps[5:] if t[2] > 0]


# ------------------------------------------------------------------------------------------------ the set --
def build_set(mat):
    check_layout()
    s = Set(NAME)
    keep = []

    def put(fn, x, z, rot=0.0, r=4.0, y=0.0):
        keep.append((x, z, r))
        return s.put(fn, x, z, rot, y)

    def spot(label, x, z, y=0.0):
        assert not in_block(x, z, 0.6) and not in_moat(x, z, 0.5), (label, x, z)
        _spot(s, label, x, z, y)

    _walls(s, mat)

    # Market Lane: houses and stalls facing the street, the well on its plaza, carts, barrels and crates behind
    for i, hz in enumerate(HOUSE_Z):
        for sx in (-1, 1):
            house = (i + (sx > 0)) % 2 == 0
            smoking = house and i < 4                       # the first four houses' chimneys smoke (Effects' cap)
            fn = timber_house(mat, i + (sx > 0), smoking) if house else market_stall(mat, i + (sx > 0) * 2)
            put(fn, sx * HOUSE_X, hz, 90 * sx, r=9)
            spot("house_front" if house else "stall_front", sx * (HOUSE_X - HOUSE_D / 2 - 3.4), hz + 2.5 * (-1) ** i)
            if i < 4:
                spot("house_gap", sx * HOUSE_X, hz + 11.0)
                put(torch_post(mat), sx * 8.6, hz + 11.0, 0, r=1.2)
    put(well(mat), WELL[0], WELL[1], 0, r=3.5)
    for a in (30, 150, 270):
        spot("well", WELL[0] + 6.0 * math.cos(math.radians(a)), WELL[1] + 6.0 * math.sin(math.radians(a)))
    for sx in (-1, 1):
        for j, z in enumerate((-262.0, -222.0, -178.0)):
            put((barrels if j % 2 == 0 else crate_stack)(mat, j + (sx > 0)), sx * 56.0, z, 90 * sx, r=3.5)
            spot("lane_yard", sx * 51.0, z + 4.0)
        for j, z in enumerate((-244.0, -200.0)):
            put(haystack(mat, 0.9 + 0.2 * j), sx * 62.0, z, 0, r=3.2)
            spot("haystack", sx * 57.5, z - 2.0)
        put(hay_cart(mat), sx * 52.0, -160.0 - 4.0 * (sx > 0), 60 * sx, r=4.5)
        spot("hay_cart", sx * 46.5, -166.0)
        put(bench(mat), sx * 47.5, -238.0, -90 * sx, r=2.6)
        spot("bench", sx * 45.2, -234.0)
        for z in (-248.0, -206.0, -176.0):
            spot("alley", sx * (ALLEY_X + 1.5 * (-1) ** int(z)), z)
        for z in (-264.0, -160.0):
            spot("lane_end", sx * 21.0, z - 1.0 if z < -200 else z + 1.5)
        put(banner_pole(mat, int(sx > 0)), sx * 9.0, -272.0, 0, r=1.5)

    # the Jousting Field: the tilt, the stands, the butts, the pavilions
    put(tilt_fence(mat, TILT[2] - TILT[1]), TILT[0], (TILT[1] + TILT[2]) / 2, 90, r=1)
    for j, (x, z) in enumerate(STANDS):
        put(joust_stand(mat, j), x, z, 90 if x > 0 else -90, r=20)
        for dz in (-14.0, 0.0, 14.0):
            spot("stand", x + (-7.0 if x > 0 else 7.0), z + dz)
        spot("stand_end", x, z - 23.5)
        spot("stand_end", x, z + 23.5)
    for j, (x, z) in enumerate(TENTS):
        put(pavilion(mat, j), x, z, 180 if z < -100 else 0, r=7.5)
        for a in (20, 200):
            spot("pavilion", x + 9.4 * math.cos(math.radians(a)), z + 9.4 * math.sin(math.radians(a)))
    for (x, z) in BUTTS:
        put(archery_butt(mat), x, z, -90, r=2.6)
        spot("butt", x + 4.0, z + 3.0)
    for j, (x, z, rot) in enumerate(((-40.0, -60.0, 90), (20.0, -124.0, 0), (-14.0, -138.0, 180))):
        put(weapon_rack(mat), x, z, rot, r=3.5)
        spot("weapon_rack", *turned(x, z, rot, 0.0, -3.0))
    for j, (x, z) in enumerate(((-54.0, -112.0), (54.0, -124.0), (-16.0, -24.0), (16.0, -142.0), (-56.0, -52.0),
                                (14.0, -22.0))):
        put(banner_pole(mat, j), x, z, 0 if z < -80 else 180, r=1.5)
    for (x, z) in ((-40, -100), (-12, -90), (-38, -76), (-14, -58), (16, -80), (14, -104), (48, -60), (50, -100),
                   (-50, -84), (24, -30), (-30, -40), (36, -128), (-20, -114), (-52, -24)):
        spot("field", x, z)
    for j, (x, z) in enumerate(((-58, -140), (58, -146), (-62, -24), (30, -52))):
        put(haystack(mat, 0.8 + 0.1 * j), x, z, 0, r=3.0)
    for z in (-140.0, -100.0, -60.0):
        for sx in (-1, 1):
            put(torch_post(mat), sx * 8.6, z, 0, r=1.2)

    # the Castle Gate: the moat, the drawbridge, the gatehouse, the curtain wall and its towers, the outer ward
    s.put(moat(mat), 0.0, (MOAT_Z0 + MOAT_Z1) / 2, 0)
    s.put(drawbridge(mat), 0.0, MOAT_Z1 + 2.0, 0)
    s.put(plank_bridge(mat), POSTERN_X, (MOAT_Z0 + MOAT_Z1) / 2, 0)
    s.put(curtain_wall(mat), 0.0, (WALL_Z0 + WALL_Z1) / 2, 0)
    s.put(gatehouse(mat), 0.0, GATEHOUSE[2], 0)
    for j, (x, z, r, h) in enumerate(TOWERS):
        put(round_tower(mat, r, h, j), x, z, 0, r=r + 1)
    for sx in (-1, 1):
        spot("gate_front", sx * 26.0, -19.5)
        spot("gate_front", sx * 13.0, -20.0)
        spot("gatehouse", sx * 23.5, 21.0)
        spot("tower_foot", sx * 58.0, 19.0)
    spot("tower_foot", -34.0, 16.5)
    spot("tower_foot", 30.0, 16.5)
    spot("postern", POSTERN_X - 6.5, 16.0)
    spot("postern", POSTERN_X + 6.5, -20.0)
    put(stables(mat), STABLES[0], STABLES[1], 0, r=10)
    for dx in (-5.3, 0.0, 5.3):
        spot("stables", STABLES[0] + dx, STABLES[1] - 9.5)
    spot("stables", STABLES[0] - 11.0, STABLES[1])
    put(hay_cart(mat), -56.0, 30.0, 110, r=4.5)
    spot("hay_cart", -50.0, 26.0)
    for j, (x, z, rot) in enumerate(((20.0, 30.0, 0), (64.0, 26.0, 90), (-14.0, 44.0, 180), (30.0, 58.0, 30))):
        put((barrels if j % 2 == 0 else crate_stack)(mat, j), x, z, rot, r=3.5)
        spot("ward_stores", *turned(x, z, rot, 4.2, -1.0))
    put(weapon_rack(mat), 14.0, 46.0, -90, r=3.5)
    spot("weapon_rack", 10.5, 46.0)
    for (x, z) in ((-18, 28), (-60, 66), (38, 44), (62, 40), (-46, 60), (16, 64), (-16, 62), (40, 24)):
        spot("outer_ward", x, z)
    for sx in (-1, 1):
        put(torch_post(mat), sx * 8.6, 26.0, 0, r=1.2)
        put(torch_post(mat), sx * 8.6, 52.0, 0, r=1.2)
        put(banner_pole(mat, 2 + (sx > 0)), sx * 9.6, -22.0, 180, r=1.5)

    # the Courtyard: the oak in the loop, the training yard, haystacks, carts
    put(old_oak(mat), OAK[0], OAK[1], 0, r=OAK[2] + 1)
    for a in (45, 135, 225, 315):
        spot("oak", OAK[0] + (OAK[2] + 3.4) * math.cos(math.radians(a)), OAK[1] + (OAK[2] + 3.4) * math.sin(math.radians(a)))
    for j, (x, z, rot) in enumerate(((-18.0, 100.0, 30), (-20.0, 138.0, -20), (18.0, 96.0, -30), (16.0, 146.0, 200),
                                     (-52.0, 82.0, 90), (54.0, 96.0, -90), (56.0, 136.0, -90))):
        put(practice_dummy(mat, j), x, z, rot, r=2.4)
        spot("dummy", *turned(x, z, rot, 0.0, -3.4))
    for j, (x, z) in enumerate(((-62.0, 76.0), (62.0, 150.0), (-44.0, 162.0), (48.0, 104.0))):
        put(haystack(mat, 0.9 + 0.1 * j), x, z, 0, r=3.2)
        spot("haystack", x + (4.6 if x < 0 else -4.6), z + 1.0)
    for j, (x, z, rot) in enumerate(((-58.0, 152.0, 0), (62.0, 82.0, 180), (-24.0, 76.0, 90), (24.0, 164.0, -90))):
        put((crate_stack if j % 2 == 0 else barrels)(mat, j), x, z, rot, r=3.5)
        spot("yard_stores", *turned(x, z, rot, 4.2, -1.0))
    put(weapon_rack(mat), -48.0, 116.0, 90, r=3.5)
    spot("weapon_rack", -44.5, 116.0)
    put(archery_butt(mat), 50.0, 122.0, -90, r=2.6)
    spot("butt", 46.0, 126.0)
    for (x, z, rot) in ((-28.5, 110.0, 90), (28.5, 132.0, -90), (-12.0, 82.0, 0), (12.0, 160.0, 180)):
        put(bench(mat), x, z, rot, r=2.6)
        spot("bench", *turned(x, z, rot, 0.0, -2.2))
    for (x, z) in ((-14, 120), (14, 118), (-48, 96), (-62, 118), (-46, 142), (46, 150), (62, 122), (44, 90),
                   (-20, 158), (22, 80), (-64, 164), (60, 166)):
        spot("courtyard", x, z)
    for (x, z) in ((-41.5, 92.0), (41.5, 92.0), (-41.5, 150.0), (41.5, 150.0), (-8.0, 74.0), (8.0, 166.0)):
        put(torch_post(mat), x, z, 0, r=1.2)
    for j, (x, z) in enumerate(((-8.5, 172.0), (8.5, 172.0))):
        put(banner_pole(mat, j), x, z, 180, r=1.5)

    # the Throne Hall: the keep's walls and towers, columns, tables, the dais; armour and stores in the side strips
    s.put(keep_walls(mat), 0.0, 0.0, 0)
    for sx in (-1, 1):
        put(round_tower(mat, 6.0, 32.0, int(sx > 0)), sx * KEEP_X, KEEP_Z0 + 2.0, 0, r=7)
    for j, (x, z) in enumerate(COLUMNS):
        put(column(mat, j), x, z, 90 if x > 0 else -90, r=2.2)
        spot("column", x + (3.4 if x < 0 else -3.4), z + (2.5 if j % 2 == 0 and z < 250 else -2.5))
    for j, (x, z) in enumerate(TABLES):
        put(long_table(mat), x, z, 0, r=18)
        for dz in (-12.0, 0.0, 12.0):
            spot("table", x + (6.0 if x < 0 else -6.0), z + dz)
        spot("table_end", x, z - 20.5)
        spot("table_end", x, z + 20.5)
    put(throne_dais(mat), DAIS[0], DAIS[1], 0, r=14)
    for sx in (-1, 1):
        spot("throne", sx * 15.0, 262.0)
        spot("throne", sx * 6.0, 255.5)
        for j, z in enumerate((190.0, 240.0, 264.0)):
            put(armour_stand(mat, j + (sx > 0)), sx * 50.5, z, 90 * sx, r=2.0)
            spot("armour", sx * 47.0, z + 3.0)
        spot("hall", sx * 40.0, 214.0)
        spot("hall", sx * 38.0, 236.0)
        spot("hall", sx * 30.0, 268.0)
        spot("hall", sx * 36.0, 188.0)
        spot("hall_door", sx * 14.0, 185.0)
        spot("side_door", sx * 49.0, SIDE_DOOR_Z + 7.5)
        # the strips outside the keep's side walls
        put(barrels(mat, int(sx > 0)), sx * 66.0, 196.0, 90 * sx, r=3.5)
        put(crate_stack(mat, int(sx > 0)), sx * 65.0, 246.0, 0, r=3.5)
        put(haystack(mat, 0.8), sx * 66.0, 266.0, 0, r=3.0)
        spot("keep_strip", sx * 62.0, 240.0)
        spot("keep_strip", sx * 62.0, 258.0)
        spot("keep_strip", sx * 68.0, 208.0)
        put(torch_post(mat), sx * 59.5, SIDE_DOOR_Z - 8.0, 0, r=1.2)

    # the rescue spots: the five main ones and the pool (scenery until the day's pick puts a stuck cat in one)
    for (label, x, z, t) in all_traps():
        fn, r = TRAPS[label]
        put(fn(mat), x, z, t, r=r)
        _spot(s, label, x, z, y=TRAP_Y.get(label, 0.0), turn=t)

    # filler: barrels, crates and haystacks, clear of the paths, the blockers, the moat, the pieces and the spots
    spots = [(p[0], p[2]) for lst in s.points.values() for p in lst]
    k = 0
    for gx in range(-64, 65, 16):
        for gz in range(-262, 263, 18):
            k += 1
            x = gx + 5.0 * math.sin(k * 2.71)
            z = gz + 5.0 * math.cos(k * 1.93)
            if z < -IN_Z + 16 and abs(x) < GATE_HALF + 10:
                continue
            if near_trail(x, z) < 4.5 or in_block(x, z, 4.0) or in_moat(x, z, 4.0) or abs(x) > IN_X - 4:
                continue
            if abs(x) < KEEP_X and z > KEEP_Z0:
                continue                                                  # the hall stays open
            fx, fz, frx, frz = FIELD
            if ((x - fx) / frx) ** 2 + ((z - fz) / frz) ** 2 < 0.8:
                continue                                                  # and the middle of the field
            if any(math.hypot(x - qx, z - qz) < qr + 4.0 for (qx, qz, qr) in keep):
                continue
            if any(math.hypot(x - qx, z - qz) < 6.0 for (qx, qz) in spots):
                continue
            if k % 4 == 0:
                s.put(barrel(mat, k), x, z, (k * 53) % 360)
            elif k % 4 == 1:
                s.put(crate_stack(mat, k), x, z, (k * 37) % 360)
            elif k % 4 == 2:
                s.put(haystack(mat, 0.7 + 0.1 * (k % 3)), x, z, (k * 37) % 360)
    return s.finish(_ground(), mat), s


def build_castle_set(mat):
    objs, _ = build_set(mat)
    return objs


ASSETS = {
    NAME: (build_castle_set, 150000),
}
