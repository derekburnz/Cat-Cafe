"""The Theme Park and Water Park (Tier 9, Funfair Cafe; the next-areas plan Derek OK'd on 2026-11-13, section 2,
#4066; the area was a player's idea): a long rectangle, 150 x 560 for the wild part like the Desert and the Snowy
Mountain, with the camp (the Ticket Gate, a later piece) 30 more across its -Z end, outside it.

  CatCafe_WaterPark_Set   the wild part dressed, in area space (areakit): place it at the area's centre on its
                          floor, camp side -Z, like every set. Walls at x +-75 and z +-280; the way in is the 24
                          stud opening at x 0 on z -280.

No grass anywhere: painted asphalt in the park half, wet blue tiles from the Splash Zone on, cream paths, and the
edges striped board fences, cut hedges in planters and blue tile walls 9.5 to 10 high. No blocker runs wall to wall.
Nothing invisible stands inside the area (#2897's rule): the only _Barrier is the 30 high ring in the border's wall
band, which starts BAR_IN behind the border's drawn faces. The zones, camp first:

  z -276 to -160   the Midway: a 14 wide spine between two rows of six game booths (10.4 high, scenery only), a back
                   alley behind each row that leaves the spine at z -270 and meets it again at z -156, prize walls
                   and food carts along the walls
  z -160 to 20     Ride Row: the carousel (-38, -110) and the teacups (38, -118) on painted discs, the Ferris wheel
                   by the east wall, the drop tower by the west wall and the coaster's track as a tall arch over the
                   path at z -10 (the track is 15 up at the walls and 24 over the path; only its posts stand on the
                   floor)
  z 20 to 140      the Splash Zone: blue tiles from here on, a lazy river ring round (0, 80) (a low kerbed channel 9
                   wide) that the spine crosses on two 14 wide plank bridges, the splash pad with its tipping bucket
                   west of the spine and the wave pool behind glass east of it, beach chairs and umbrellas outside
  z 140 to 276     the Slide Tower: a loop path round the big tower at (0, 210) with two spiral slides, two small
                   slide towers, two kids' pools; the deep zone where the Mythical stays

The turning pieces are their own objects so Motion-FX can find them by name: `..._CarouselTurn` (turns about the
carousel's middle, a vertical axis), `..._TeacupsTurn` (the same) and `..._FerrisTurn` (the wheel, about its hub,
RIDES below). They stand still under Reduce Motion and Low performance.

Points (manifest points_roblox): [x, y, z, zone], zone "near" (z < 0) or "deep". The five rescue spots are built in
(the plan's 2b), each with its piece's turn as a fifth number:
  trap_carousel       a little kiddie carousel, four poles and a low striped top, the cat on its deck (0.3 up)
  trap_ball_pit       a round ball pit 1.1 high full of coloured balls, open in the middle, the cat in it to its chest
  trap_plush_pile     a heap of prize plushies round the spot, fallen off a prize wall
  trap_river_ring     a swim ring stuck on a puddle of water, the cat sitting in the ring
  trap_balloons       a bunch of balloons on strings tied to a weight, over the spot, the cat holding on
Four of the five are deep and none is within 100 studs of the camp. The rescue pool (as the Desert's) adds ten more
(POOL_*), 15 in all, ten of them deep, every one 25 or more from every other and off the paths and the blockers
(check_layout asserts it).
"""

import math
from itertools import pairwise

from mathutils import Matrix

from areakit import PI, Set, hinge, turned
from common import Builder
from woodsset import _dist_seg, _strip, bl

NAME = "CatCafe_WaterPark_Set"
N = "CatCafe_WaterPark_"
HALF_X, HALF_Z = 75.0, 280.0
WALL_D = 3.0
IN_X, IN_Z = HALF_X - 0.5 - WALL_D, HALF_Z - 0.5 - WALL_D       # 71.5, 276.5
GATE_HALF = 12.0
BARRIER_H = 30.0
BAR_IN = 0.8
SPINE_W, ALLEY_W, LOOP_W = 14.0, 8.0, 9.0

# the palette: a candy set on grey asphalt and blue tiles
ASPHALT, ASPHALT_DARK = "concrete", "concrete_dark"
TILE, TILE_LIGHT, WATER, WATER_DEEP = "pastel_sky", "fish_belly", "fish_blue", "fur_blue"
PATH, PATH_EDGE = "paving_light", "paving_sand"
PATH_WET, PATH_WET_EDGE = "paving_sand", "paving_tan"
RED, BLUE, BUTTER, GREEN, MILK, GOLD = "shirt_red", "shirt_blue", "pastel_butter", "leaf_green", "milk", "rarity_legend"
PINK, LILAC, MINT = "fur_bubblegum", "pastel_lilac", "mint"
WOOD, WOOD_DARK = "caramel_wood", "dark_wood"
METAL = "metal"
CANDY = (RED, BLUE, BUTTER, GREEN)
LANES = ("rarity_common", "rarity_rare", "rarity_epic", "rarity_legend", "rarity_mythic")
BALLOONS = (RED, BUTTER, BLUE, PINK, GREEN, LILAC)

# the Midway
BOOTH_X, BOOTH_W, BOOTH_D, BOOTH_H = 22.0, 12.0, 9.0, 10.4
BOOTH_Z = tuple(-256.0 + 17.0 * i for i in range(6))            # -256 to -171
ALLEY_X, ALLEY_Z0, ALLEY_Z1 = 40.0, -270.0, -156.0
# Ride Row: (x, z, footprint radius)
RIDES = {"carousel": (-38.0, -110.0, 13.0), "teacups": (38.0, -118.0, 11.0)}
FERRIS = (59.0, -42.0)                   # the wheel's base; its hub is FERRIS_HUB up, the wheel turns in the z plane
FERRIS_R, FERRIS_HUB = 20.0, 24.0
DROP = (-60.0, -30.0)
COASTER_Z = -10.0
COASTER_POSTS = (-62.0, -38.0, -14.0, 14.0, 38.0, 62.0)
# the Splash Zone
TILE_Z = 20.0                            # blue tiles from here to the far wall
RIVER = (0.0, 80.0)
RIVER_RX, RIVER_RZ, RIVER_W = 52.0, 50.0, 9.0
KERB_H = 0.7
BRIDGE_L = RIVER_W + 4.0                 # the bridge's flat deck, along the spine
POOL = (26.0, 80.0, 28.0, 22.0)          # the wave pool: x, z, width (x), depth (z)
PAD = (-26.0, 80.0, 10.0)                # the splash pad: x, z, radius
# the Slide Tower
TOWER = (0.0, 210.0)
TOWER_R = 10.5                           # the tower's footprint with its slides
SMALL_TOWERS = ((-60.0, 228.0, -90), (60.0, 190.0, 90))    # x, z, turn: each slides toward the middle
KIDS_POOLS = ((56.0, 238.0), (-56.0, 176.0))

TRAIL = [(0.0, -IN_Z), (0.0, 150.0)]
LOOP = [(0.0, 150.0), (-34.0, 172.0), (-34.0, 246.0), (0.0, 266.0), (34.0, 246.0), (34.0, 172.0), (0.0, 150.0)]
ALLEYS = [[(0.0, ALLEY_Z0), (sx * ALLEY_X, ALLEY_Z0), (sx * ALLEY_X, ALLEY_Z1), (0.0, ALLEY_Z1)] for sx in (-1, 1)]
PATHS = ((TRAIL, SPINE_W), (LOOP, LOOP_W), (ALLEYS[0], ALLEY_W), (ALLEYS[1], ALLEY_W))

# the rescue spots: (label, x, z, turn); the pool as (x, z, turn)
MAIN_TRAPS = (("trap_carousel", -17.0, -90.0, 0), ("trap_ball_pit", -60.0, 112.0, 0),
              ("trap_plush_pile", 18.0, 238.0, 200), ("trap_river_ring", 62.0, 53.0, 0),
              ("trap_balloons", -18.0, 180.0, 0))
POOL_CAROUSELS = ((58.0, -150.0, 0), (56.0, 152.0, 0))
POOL_BALL_PITS = ((-62.0, -150.0, 0), (60.0, 262.0, 0))
POOL_PLUSH = ((62.0, -96.0, -90), (-58.0, 262.0, 20))
POOL_RINGS = ((-62.0, 40.0, 0), (-60.0, 150.0, 0))
POOL_BALLOONS = ((30.0, -64.0, 0), (60.0, 112.0, 0))


def near_trail(x, z):
    """Distance to the nearest path's edge (its middle line, less half its width)."""
    d = 1e9
    for pts, w in PATHS:
        for a, b in pairwise(pts):
            d = min(d, _dist_seg((x, z), a, b) - w / 2)
    return d


def trail_length():
    return sum(math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in pairwise(TRAIL))


def river_t(x, z):
    """0 at the river's middle line, 1 at its kerbs' outer faces."""
    a = math.atan2((z - RIVER[1]) / RIVER_RZ, (x - RIVER[0]) / RIVER_RX)
    mx, mz = (RIVER_RX - RIVER_W / 2) * math.cos(a), (RIVER_RZ - RIVER_W / 2) * math.sin(a)
    return math.hypot(x - RIVER[0] - mx, z - RIVER[1] - mz) / (RIVER_W / 2 + 0.6)


def in_river(x, z, pad=0.0):
    return river_t(x, z) < 1.0 + pad / (RIVER_W / 2 + 0.6)


def in_block(x, z, pad=0.0):
    """On or within pad of a blocker's footprint: a booth, a ride, the wave pool, a slide tower, a kids' pool."""
    for bz in BOOTH_Z:
        if BOOTH_X - BOOTH_D / 2 - pad < abs(x) < BOOTH_X + BOOTH_D / 2 + pad and abs(z - bz) < BOOTH_W / 2 + pad:
            return True
    for (rx_, rz_, rr) in RIDES.values():
        if math.hypot(x - rx_, z - rz_) < rr + pad:
            return True
    if abs(x - FERRIS[0]) < 5.0 + pad and abs(z - FERRIS[1]) < 13.0 + pad:
        return True
    if abs(x - DROP[0]) < 5.0 + pad and abs(z - DROP[1]) < 5.0 + pad:
        return True
    if any(abs(x - px) < 1.6 + pad and abs(z - COASTER_Z) < 2.6 + pad for px in COASTER_POSTS):
        return True
    px, pz, pw, pd = POOL
    if abs(x - px) < pw / 2 + 1.0 + pad and abs(z - pz) < pd / 2 + 1.0 + pad:
        return True
    if math.hypot(x - PAD[0], z - PAD[1]) < PAD[2] + pad:
        return True
    if math.hypot(x - TOWER[0], z - TOWER[1]) < TOWER_R + pad:
        return True
    for (tx, tz, rot) in SMALL_TOWERS:
        f = -math.sin(math.radians(rot))                                  # its front, along x
        if -6.0 - pad < (x - tx) * f < 18.0 + pad and abs(z - tz) < 4.5 + pad:
            return True
    return any(math.hypot(x - kx, z - kz) < 7.4 + pad for (kx, kz) in KIDS_POOLS)


def _spot(s, label, x, z, y=0.0, turn=None):
    p = [round(x, 2), round(y, 2), round(z, 2), "deep" if z > 0 else "near"]
    if turn is not None:
        p.append(turn)
    s.points.setdefault(label, []).append(p)


# ------------------------------------------------------------------------------------------------- ground --
def _path(g, pts, w, swatch, top):
    """As woodsset's, with a wider step (0.02) between overlapping strips: straight strips, every other one taller,
    and a disc under each bend."""
    for i, (p0, p1) in enumerate(pairwise(pts)):
        _strip(g, p0, p1, w, swatch, top + 0.02 * (i % 2))
    for p in pts[1:-1]:
        g.cyl_base(bl(*p), w / 2, top - 0.012, swatch, segments=16, bevel=False)


def _ground():
    """Asphalt over the park half and blue tiles over the water half, right out to the walls (no plate shows, no
    grass), painted discs under the rides, lane stripes down the Midway, the cream paths over it all."""
    g = Builder()
    g.box_base((0, 0, 0), (2 * HALF_X, 2 * HALF_Z, 0.03), ASPHALT, bevel=False)
    zc = (TILE_Z + HALF_Z) / 2
    g.box_base((0, zc, 0), (2 * HALF_X, HALF_Z - TILE_Z, 0.05), TILE, bevel=False)
    k = 0
    for ix in range(-7, 8):                                              # a checker of lighter tiles
        for iz in range(26):
            k += 1
            if (ix + iz) % 2:
                continue
            x, z = ix * 10.0, TILE_Z + 5.0 + iz * 10.0
            g.box_base((*bl(x, z)[:2], 0), (9.4, 9.4, 0.062 + 0.002 * (k % 2)), TILE_LIGHT, bevel=False)
    for sx in (-1, 1):                                                   # the Midway's painted lanes
        for i, sw in enumerate(LANES):
            x = sx * (SPINE_W / 2 + 1.6 + 0.9 * i)
            g.box_base((*bl(x, (ALLEY_Z0 + 5 + ALLEY_Z1 - 5) / 2)[:2], 0),
                       (0.6, ALLEY_Z1 - ALLEY_Z0 - 10.0, 0.07 + 0.002 * i), sw, bevel=False)
    for i, (key, sw, sw2) in enumerate((("carousel", "fur_rose", MILK), ("teacups", LILAC, MILK))):
        x, z, r = RIDES[key]                                             # painted discs under the rides
        g.cyl_base((*bl(x, z)[:2], 0), r + 5.0, 0.066 + 0.002 * i, sw, segments=28, bevel=False)
        g.cyl_base((*bl(x, z)[:2], 0), r + 2.4, 0.072 + 0.002 * i, sw2, segments=28, bevel=False)
    for i in range(14):                                                  # zebra stripes under the coaster's arch
        x = -65.0 + i * 10.0
        if abs(x) < SPINE_W / 2 + 2:
            continue
        g.box_base((*bl(x, COASTER_Z)[:2], 0), (5.0, 2.0, 0.07), (BUTTER, MILK)[i % 2], bevel=False)
    # every path at its own height, so no two share a top where they meet; sand-coloured from the tiles on
    spine_a, spine_b = [TRAIL[0], (0.0, TILE_Z)], [(0.0, TILE_Z), TRAIL[1]]
    for pts, w, sw, edge, top in ((spine_a, SPINE_W, PATH, PATH_EDGE, 0.0), (spine_b, SPINE_W, PATH_WET, PATH_WET_EDGE, 0.004),
                                  (LOOP, LOOP_W, PATH_WET, PATH_WET_EDGE, 0.012), (ALLEYS[0], ALLEY_W, PATH, PATH_EDGE, 0.012),
                                  (ALLEYS[1], ALLEY_W, PATH, PATH_EDGE, 0.012)):
        _path(g, pts, w + 1.6, edge, 0.085 + top)
        _path(g, pts, w, sw, 0.14 + top * 3)
    return g


# -------------------------------------------------------------------------------------------------- walls --
def _bulbs(d, L, top, y=-0.25, step=2.4):
    n = max(2, round(L / step))
    for i in range(n):
        x = -L / 2 + (i + 0.5) * L / n
        sag = 0.5 * math.sin(PI * (i + 0.5) / n)
        d.ico((x, y, top - sag), 0.24, (BUTTER, RED, BLUE, GREEN)[i % 4], subdivisions=1)


def _seg_boards(b, d, L, k):
    """A striped board fence 10 high: red and milk boards, a gold rail, a string of bulbs under it."""
    n = max(4, round(L / 2.2))
    w = L / n
    cols = ((RED, MILK), (BLUE, MILK), (BUTTER, MILK))[k % 3]
    for i in range(n):
        x = -L / 2 + (i + 0.5) * w
        b.box_base((x, 0.9, 0), (w + 0.02, 1.2 + 0.03 * (i % 2), 9.6 + 0.3 * (i % 2)), cols[i % 2], bevel=False)
    b.box_base((0, 0.9, 9.9), (L, 1.6, 0.4), GOLD, bevel=False)
    b.box_base((0, 2.1, 0), (L, 1.4, 6.0), WOOD_DARK, bevel=False)                           # the bracing behind
    _bulbs(d, L, 9.2)


def _seg_hedge(b, d, L, k):
    """A cut hedge 9.6 high in a long wooden planter."""
    b.box_base((0, 1.5, 0), (L, 2.8, 1.4), WOOD, bevel=False)
    b.box_base((0, 1.5, 1.4), (L - 0.4, 2.5, 7.6), "leaf_dark", bevel=False)
    b.box_base((0, 1.5, 9.0), (L - 1.2, 2.0, 0.6), GREEN, bevel=False)
    n = max(2, round(L / 6.0))
    for i in range(n):                                                    # clipped balls along its top
        x = -L / 2 + (i + 0.5) * L / n
        b.ico((x, 1.5, 10.0), 1.1, (GREEN, "leaf_dark")[(i + k) % 2], subdivisions=1)
    _bulbs(d, L, 6.4, y=-0.1)


def _seg_tiles(b, d, L, k):
    """A blue tile wall 9.8 high with a wave of white along its top and a darker foot."""
    b.box_base((0, 1.5, 0), (L, 3.0, 1.2), WATER_DEEP, bevel=False)
    b.box_base((0, 1.5, 1.2), (L, 2.6, 7.6), (WATER, TILE)[k % 2], bevel=False)
    b.box_base((0, 1.5, 8.8), (L, 3.0, 0.5), MILK, bevel=False)
    n = max(2, round(L / 5.0))
    for i in range(n):
        x = -L / 2 + (i + 0.5) * L / n
        b.cyl((x, 1.5, 9.3), 1.5, 2.2, MILK, segments=10, rot=(PI / 2, "X"), bevel=False)   # the wave's crests
        b.box((x, -0.04, 5.0 + 1.2 * ((i + k) % 2)), (2.2, 0.12, 0.3), TILE_LIGHT, bevel=False)


SEGMENTS = {"boards": _seg_boards, "hedge": _seg_hedge, "tiles": _seg_tiles}


def wall_segment(mat, kind, L, k=0):
    """One wall run L long along local x, its face at y 0 (facing -Y, into the area) and its back at WALL_D."""
    b, d = Builder(), Builder()
    SEGMENTS[kind](b, d, L, k)
    out = [b.finalize(N + "Wall" + kind.capitalize(), mat)]
    if d.bm.verts:
        out.append(d.finalize(N + "Wall" + kind.capitalize() + "_Bulbs", mat))
    return out


def pennant_tower(mat, h=17.0, k=0):
    """A striped post in the wall line between two runs, standing over them: bands of two colours, a cone roof, a
    gold ball and a pennant."""
    b = Builder()
    cols = ((RED, MILK), (BLUE, MILK), (BUTTER, MILK), (GREEN, MILK))[k % 4]
    n = 6
    for j in range(n):
        b.box_base((0, WALL_D / 2, j * (h - 4.0) / n), (3.2, 3.2, (h - 4.0) / n + 0.02 * (j % 2)), cols[j % 2],
                   bevel=False)
    b.box_base((0, WALL_D / 2, h - 4.0), (3.8, 3.8, 0.4), GOLD, bevel=False)
    b.cyl_base((0, WALL_D / 2, h - 3.6), 2.6, 3.0, cols[0], segments=8, radius2=0.2, bevel=False)
    b.ico((0, WALL_D / 2, h - 0.4), 0.4, GOLD, subdivisions=1)
    b.cyl_base((0, WALL_D / 2, h - 0.4), 0.08, 2.4, METAL, segments=6, bevel=False)
    f = Builder()                    # the pennant flaps about its rod: the child Model ..._PennantTower_Swing
    f.box((0.88, WALL_D / 2, h + 1.5), (1.6, 0.06, 0.9), cols[0], bevel=False)
    return [b.finalize(N + "PennantTower", mat),
            hinge(f.finalize(N + "PennantTower_Swing", mat), (0, WALL_D / 2, h + 1.5))]


def _run(s, mat, kinds, n, length, place, seed):
    L = (length - (n - 1) * 3.4) / n
    for i in range(n):
        t = i * (L + 3.4) + L / 2
        x, z, rot = place(t)
        s.put(wall_segment(mat, kinds[i % len(kinds)], L, i + seed), x, z, rot)
        if i < n - 1:
            s.put(pennant_tower(mat, 15.0 + 2.0 * ((i + seed) % 3), i + seed), *place(t + L / 2 + 1.7))


def low_wall(mat, L):
    """The camp side: a striped picket fence 3.6 high with a gold rail, so the camp shows over it."""
    b = Builder()
    n = max(4, round(L / 1.6))
    w = L / n
    for i in range(n):
        x = -L / 2 + (i + 0.5) * w
        b.box_base((x, 1.0, 0), (w * 0.8, 0.5, 3.3 + 0.3 * (i % 2)), (RED, MILK)[i % 2], bevel=False)
    b.box_base((0, 1.0, 1.0), (L, 0.7, 0.3), GOLD, bevel=False)
    b.box_base((0, 1.0, 2.6), (L, 0.7, 0.3), GOLD, bevel=False)
    return [b.finalize(N + "LowWall", mat)]


def _walls(s, mat):
    """Board fences, hedges and tile walls just inside the area's walls, pennant towers between, the camp side a
    picket fence either side of the way in; a barrier all round but the way in."""
    far = ("tiles", "tiles", "tiles", "tiles", "tiles")
    side = ("boards", "boards", "hedge", "boards", "boards", "hedge", "boards", "hedge", "tiles", "tiles", "hedge",
            "tiles", "tiles", "tiles", "tiles")                           # camp end first
    _run(s, mat, far, 5, 2 * IN_X, lambda t: (-IN_X + t, IN_Z, 0), 0)
    _run(s, mat, side, 15, 2 * IN_Z, lambda t: (IN_X, -IN_Z + t, 90), 1)
    _run(s, mat, side, 15, 2 * IN_Z, lambda t: (-IN_X, -IN_Z + t, -90), 2)
    for sx in (-1, 1):
        s.put(pennant_tower(mat, 21.0, 1), sx * (IN_X - 2.0), IN_Z - 2.0, 45 * sx)
        s.put(pennant_tower(mat, 14.0, 0), sx * (IN_X - 2.0), -IN_Z + 2.0, 135 * sx)
        L = IN_X - GATE_HALF - 4.5
        s.put(low_wall(mat, L), sx * (GATE_HALF + 0.5 + L / 2), -IN_Z, 180)
        s.put(lamp(mat), sx * (GATE_HALF + 2.0), -IN_Z + 2.0, 0)
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
def _plush(b, at, r, col, belly=MILK):
    """A round prize plushie: body, head, two ears and a pale belly."""
    x, y, z = at
    b.ico((x, y, z + r), r, col, subdivisions=1, scale=(1.0, 0.9, 1.0))
    b.ico((x, y - 0.1 * r, z + 2.25 * r), 0.72 * r, col, subdivisions=1)
    for sx in (-1, 1):
        b.ico((x + sx * 0.5 * r, y, z + 2.9 * r), 0.26 * r, col, subdivisions=1)
    b.ico((x, y - 0.62 * r, z + 0.95 * r), 0.5 * r, belly, subdivisions=1, scale=(1.0, 0.5, 1.0))


def lamp(mat):
    """A park lamp: a striped post, an arm and a round globe (_Glow)."""
    b, g = Builder(), Builder()
    b.cyl_base((0, 0, 0), 0.5, 0.5, GOLD, segments=8, bevel=False)
    for j in range(4):
        b.cyl_base((0, 0, 0.5 + 1.6 * j), 0.2, 1.62, (RED, MILK)[j % 2], segments=8, bevel=False)
    b.cyl_base((0, 0, 6.9), 0.36, 0.25, GOLD, segments=8, bevel=False)
    g.ico((0, 0, 7.75), 0.62, "lamp_warm", subdivisions=1)
    return [b.finalize(N + "Lamp", mat), g.finalize(N + "Lamp_Glow", mat)]


def bench(mat):
    b = Builder()
    for i, c in enumerate((RED, BUTTER, BLUE)):
        b.box((0, -0.5 + 0.5 * i, 1.4), (4.4, 0.44, 0.2), c, bevel=False)
    for i, c in enumerate((BLUE, RED)):
        b.box((0, 0.95, 2.0 + 0.6 * i), (4.4, 0.2, 0.44), c, bevel=False)
    for sx in (-1, 1):
        b.box_base((sx * 1.9, 0.1, 0), (0.3, 1.5, 1.3), METAL, bevel=False)
        b.box_base((sx * 1.9, 0.95, 1.3), (0.3, 0.3, 1.6), METAL, bevel=False)
    return [b.finalize(N + "Bench", mat)]


def trash_can(mat, k=0):
    b = Builder()
    b.cyl_base((0, 0, 0), 0.9, 2.2, (GREEN, BLUE)[k % 2], segments=10)
    b.cyl_base((0, 0, 2.2), 1.0, 0.3, MILK, segments=10, bevel=False)
    b.cyl_base((0, 0, 2.5), 0.7, 0.5, MILK, segments=10, radius2=0.3, bevel=False)
    return [b.finalize(N + "TrashCan", mat)]


def planter_palm(mat, h=8.0):
    """A palm in a big round pot (no grass: the pot stands on the tiles)."""
    b = Builder()
    b.cyl_base((0, 0, 0), 1.3, 1.6, "terracotta", segments=10, radius2=1.6)
    b.cyl_base((0, 0, 1.6), 1.7, 0.25, MILK, segments=10, bevel=False)
    for j in range(4):
        b.cyl_base((0.12 * j, 0, 1.8 + j * (h - 1.8) / 4), 0.42 - 0.04 * j, (h - 1.8) / 4 + 0.05, (WOOD, "fur_brown")[j % 2],
                   segments=8, bevel=False)
    for k in range(7):
        a = 2 * PI * k / 7
        R = Matrix.Rotation(a, 3, "Z") @ Matrix.Rotation(0.5, 3, "Y")
        b.box((0.5 + 1.7 * math.cos(a), 1.7 * math.sin(a), h - 0.5), (4.0, 1.0, 0.16), (GREEN, "leaf_dark")[k % 2],
              bevel=False, rot=R)
    b.ico((0.5, 0, h + 0.1), 0.55, "fur_brown", subdivisions=1)
    return [b.finalize(N + "PlanterPalm", mat)]


def balloon_bunch(mat, k=0):
    """A bunch of balloons on a weight. The balloons and their string are the child Model ..._BalloonBunch_Swing,
    hung from the knot on the weight so Motion sways the bunch; they never collide (nothing to bump into overhead)."""
    b, d = Builder(), Builder()
    b.box_base((0, 0, 0), (0.9, 0.9, 0.7), (RED, BLUE)[k % 2], bevel=False)
    d.cyl_base((0, 0, 0.7), 0.05, 4.6, MILK, segments=5, bevel=False)
    for i in range(6):
        a = 2 * PI * i / 6 + k
        r = 0.95 if i else 0.0
        d.ico((r * math.cos(a), r * math.sin(a), 5.9 + 0.9 * (i % 3) + (1.4 if not i else 0)), 0.85,
              BALLOONS[(i + k) % 6], subdivisions=1, scale=(1.0, 1.0, 1.2))
    return [b.finalize(N + "BalloonBunch", mat), hinge(d.finalize(N + "BalloonBunch_Swing", mat), (0, 0, 0.7))]


def park_sign(mat, k=0):
    """A fingerpost: three coloured arrows on a striped pole."""
    b = Builder()
    for j in range(4):
        b.cyl_base((0, 0, 1.3 * j), 0.18, 1.32, (BLUE, MILK)[j % 2], segments=8, bevel=False)
    for j, c in enumerate((RED, BUTTER, GREEN)):
        b.box((0.9 * (-1) ** j, 0, 4.6 - 0.8 * j), (2.4, 0.16, 0.6), CANDY[(j + k) % 4] if c else c, bevel=False,
              rot=(0.25 * (j - 1), "Z"))
    b.ico((0, 0, 5.4), 0.3, GOLD, subdivisions=1)
    return [b.finalize(N + "ParkSign", mat)]


# ------------------------------------------------------------------------------------------- the Midway --
def booth(mat, k=0):
    """A game booth, 12 wide and 9 deep, 10.4 to its sign's top (front -Y): a counter, striped roof and valance, a
    game inside (ring toss, duck pond or a balloon wall) and prize plushies on the back wall. Scenery only."""
    b, d = Builder(), Builder()
    c = CANDY[k % 4]
    W, D = BOOTH_W, BOOTH_D
    b.box_base((0, 0, 0), (W - 1.0, D - 1.0, 0.2), WOOD, bevel=False)
    b.box_base((0, -D / 2 + 0.6, 0), (W, 1.2, 3.2), c, bevel=False)
    b.box_base((0, -D / 2 + 0.5, 3.2), (W + 0.4, 1.7, 0.25), WOOD, bevel=False)
    for sx in (-1, 1):
        b.box_base((sx * (W / 2 - 0.3), 0, 0), (0.6, D, 8.0), MILK, bevel=False)
    b.box_base((0, D / 2 - 0.3, 0), (W - 1.2, 0.6, 8.0), c, bevel=False)
    n = 8
    w = (W + 1.0) / n
    for i in range(n):
        x = -W / 2 - 0.5 + (i + 0.5) * w
        b.box_base((x, -0.6, 8.0), (w + 0.02, D + 2.4, 0.5 + 0.03 * (i % 2)), (c, MILK)[i % 2], bevel=False)
        b.box((x, -D / 2 - 1.76, 7.55), (w * 0.9, 0.14, 0.9), (MILK, c)[i % 2], bevel=False)
    b.box_base((0, -D / 2 - 0.6, 8.5), (W * 0.72, 0.5, 1.9), GOLD, bevel=False)
    b.box_base((0, -D / 2 - 0.88, 8.8), (W * 0.62, 0.1, 1.3), MILK, bevel=False)
    for i in range(5):                                                    # dots on the sign, a word without letters
        b.cyl((-2.4 + 1.2 * i, -D / 2 - 0.95, 9.45), 0.32, 0.08, CANDY[(i + k) % 4], segments=8, rot=(PI / 2, "X"),
              bevel=False)
    b.box((0, D / 2 - 0.9, 5.0), (W - 2.0, 1.0, 0.2), WOOD, bevel=False)                    # the prize shelf
    for i in range(4):
        _plush(b, (-3.6 + 2.4 * i, D / 2 - 1.0, 5.1), 0.62, (PINK, BUTTER, LILAC, MINT)[(i + k) % 4])
    game = k % 3
    if game == 0:                                                         # ring toss: bottles on a low table
        b.box_base((0, 0.6, 0.2), (6.0, 3.0, 1.6), MILK, bevel=False)
        for i in range(8):
            x, y = -2.4 + 1.6 * (i % 4), 0.0 + 1.3 * (i // 4)
            b.cyl_base((x, y, 1.8), 0.28, 0.9, (GREEN, RED, BLUE, BUTTER)[i % 4], segments=6, radius2=0.12, bevel=False)
    elif game == 1:                                                       # duck pond: a tub of water and ducks
        b.cyl_base((0, 0.6, 0.2), 3.0, 1.5, BLUE, segments=12, bevel=False, scale=(1.0, 0.6, 1.0))
        b.cyl_base((0, 0.6, 1.7), 2.8, 0.1, WATER, segments=12, bevel=False, scale=(1.0, 0.6, 1.0))
        for i in range(5):
            x = -2.0 + 1.0 * i
            b.ico((x, 0.6 + 0.6 * math.sin(i * 2.0), 1.95), 0.3, BUTTER, subdivisions=1)
            b.ico((x + 0.2, 0.6 + 0.6 * math.sin(i * 2.0), 2.3), 0.18, BUTTER, subdivisions=1)
    else:                                                                 # balloon darts: balloons on a board
        b.box((0, D / 2 - 0.75, 2.6), (W - 3.0, 0.3, 3.6), WOOD_DARK, bevel=False)
        for i in range(10):
            b.ico((-3.6 + 1.8 * (i % 5), D / 2 - 1.2, 1.8 + 1.6 * (i // 5)), 0.5, BALLOONS[(i + k) % 6], subdivisions=1)
    _bulbs(d, W, 7.95, y=-D / 2 - 1.95, step=1.5)
    return [b.finalize(N + "Booth", mat), d.finalize(N + "Booth_Bulbs", mat)]


def ticket_front(mat):
    """The Ticket Gate's front, built against the camp's back wall (pivot at its base centre, front -Y): three
    ticket windows 22 wide under a striped roof and valance, a counter along the front, a gold marquee board over
    the middle window (the words are the game's) with a big ticket standing on it, bulbs along the eave (_Bulbs)
    and warm panes in the windows (_Pane, lit at night)."""
    b, d, panes = Builder(), Builder(), Builder()
    W, D, H = 22.0, 4.0, 7.2
    b.box_base((0, 0, 0), (W + 0.6, D + 0.6, 0.5), BLUE, bevel=False)
    b.box_base((0, 0, 0.5), (W, D, H - 0.5), MILK, bevel=False)
    n = 11
    w = W / n
    for i in range(n):                                                    # candy stripes up the front, under the sill
        if i % 2 == 0:
            b.box_base((-W / 2 + (i + 0.5) * w, -D / 2 - 0.04, 0.5), (w, 0.08, 2.3), RED, bevel=False)
    b.box_base((0, -D / 2 - 0.5, 2.8), (W + 0.4, 1.3, 0.25), WOOD, bevel=False)             # the counter
    for i, x in enumerate((-7.2, 0.0, 7.2)):
        b.box((x, -D / 2 - 0.06, 4.7), (5.0, 0.2, 3.0), CANDY[i], bevel=False)               # window frames
        panes.box((x, -D / 2 - 0.12, 4.7), (4.3, 0.06, 2.4), "lamp_warm", bevel=False)
        b.box((x, -D / 2 - 0.2, 3.75), (1.6, 0.08, 0.5), WOOD_DARK, bevel=False)             # the ticket slot
    m = 12
    w = (W + 1.4) / m
    for i in range(m):                                                    # the roof and its valance
        x = -W / 2 - 0.7 + (i + 0.5) * w
        b.box_base((x, -0.9, H), (w + 0.02, D + 3.0, 0.5 + 0.03 * (i % 2)), (RED, MILK)[i % 2], bevel=False)
        b.box((x, -D / 2 - 2.36, H - 0.4), (w * 0.9, 0.14, 0.9), (MILK, RED)[i % 2], bevel=False)
    b.box_base((0, -D / 2 - 1.0, H + 0.5), (10.0, 0.5, 2.4), GOLD, bevel=False)             # the marquee
    b.box_base((0, -D / 2 - 1.28, H + 0.85), (9.0, 0.1, 1.7), MILK, bevel=False)
    b.box_base((0, -D / 2 - 0.6, H + 2.9), (4.4, 0.3, 2.2), BUTTER, bevel=False)            # the big ticket
    b.box_base((0, -D / 2 - 0.78, H + 3.15), (3.6, 0.08, 1.7), RED, bevel=False)
    b.cyl((0, -D / 2 - 0.84, H + 4.0), 0.5, 0.08, BUTTER, segments=10, rot=(PI / 2, "X"), bevel=False)
    for sx in (-1, 1):
        b.cyl((sx * 2.2, -D / 2 - 0.6, H + 4.0), 0.36, 0.34, GOLD, segments=8, rot=(PI / 2, "X"), bevel=False)
        b.cyl_base((sx * (W / 2 + 0.2), -D / 2 - 2.2, 0), 0.25, H, GOLD, segments=8, bevel=False)   # eave posts
    _bulbs(d, W + 1.0, H - 0.05, y=-D / 2 - 2.55, step=1.6)
    return [b.finalize(N + "TicketFront", mat), d.finalize(N + "TicketFront_Bulbs", mat),
            panes.finalize(N + "TicketFront_Pane", mat)]


def queue_rails(mat, lanes=3, L=9.0):
    """A queue for the ticket windows: gold posts with red ropes in `lanes` lanes, L long (along Y), open at both
    ends. About 1.2 high, so a cat hops it."""
    b = Builder()
    gap = 2.6
    for i in range(lanes + 1):
        x = (i - lanes / 2) * gap
        for y in (-L / 2, 0.0, L / 2):
            b.cyl_base((x, y, 0), 0.34, 0.12, GOLD, segments=8, bevel=False)
            b.cyl_base((x, y, 0.12), 0.11, 1.05, GOLD, segments=8, bevel=False)
            b.ico((x, y, 1.26), 0.17, GOLD, subdivisions=1)
        for y in (-L / 4, L / 4):
            b.box((x, y, 0.95), (0.14, L / 2 - 0.3, 0.14), RED, bevel=False)
    return [b.finalize(N + "QueueRails", mat)]


def prize_wall(mat, L=14.0, k=0):
    """A wall of prize plushies on three shelves under a striped pelmet, 9.4 high (front -Y)."""
    b = Builder()
    b.box_base((0, 0.6, 0), (L, 1.0, 9.0), (BLUE, RED)[k % 2], bevel=False)
    n = 7
    for i in range(n):
        x = -L / 2 + (i + 0.5) * L / n
        b.box_base((x, -0.2, 8.6), (L / n + 0.02, 2.4, 0.5 + 0.03 * (i % 2)), ((RED, BLUE)[k % 2], MILK)[i % 2],
                   bevel=False)
    b.box_base((0, 0.4, 9.1), (L * 0.5, 0.5, 0.3), GOLD, bevel=False)
    for j in range(3):
        z = 1.2 + 2.5 * j
        b.box((0, -0.3, z), (L - 0.6, 1.3, 0.2), WOOD, bevel=False)
        for i in range(5):
            _plush(b, (-L / 2 + 1.6 + i * (L - 3.2) / 4, -0.35, z + 0.1), 0.55 + 0.05 * ((i + j) % 2),
                   (PINK, BUTTER, LILAC, MINT, "fur_peach")[(i + 2 * j + k) % 5])
    return [b.finalize(N + "PrizeWall", mat)]


def food_cart(mat, kind="popcorn"):
    """A food cart under a striped parasol (front -Y): popcorn, cotton candy or ice cream."""
    b = Builder()
    c = {"popcorn": RED, "cotton": PINK, "ice": MINT}[kind]
    b.box_base((0, 0, 1.0), (4.4, 2.4, 1.8), c, bevel=False)
    b.box_base((0, 0, 2.8), (4.8, 2.8, 0.2), MILK, bevel=False)
    for sx in (-1, 1):
        b.cyl((sx * 1.6, -1.3, 1.0), 1.0, 0.25, WOOD_DARK, segments=10, rot=(PI / 2, "X"), bevel=False)
        b.cyl((sx * 1.6, -1.45, 1.0), 0.3, 0.1, GOLD, segments=8, rot=(PI / 2, "X"), bevel=False)
    b.box((0, 1.6, 1.9), (0.2, 1.0, 0.2), METAL, bevel=False)                               # the push bar
    b.cyl_base((0, 0.9, 3.0), 0.12, 4.0, METAL, segments=6, bevel=False)
    b.cyl_base((0, 0.9, 6.6), 3.4, 1.3, c, segments=10, radius2=0.2, bevel=False)
    b.cyl_base((0, 0.9, 6.45), 3.45, 0.2, MILK, segments=10, bevel=False)
    if kind == "popcorn":
        b.box_base((-0.9, 0, 3.0), (1.8, 1.6, 2.0), "glass", bevel=False)
        for i in range(6):
            b.ico((-1.4 + 0.4 * i, 0.2 * (-1) ** i, 3.5 + 0.2 * (i % 3)), 0.42, BUTTER, subdivisions=1)
        for i in range(2):
            b.box_base((0.9 + 0.8 * i, -0.3, 3.0), (0.6, 0.6, 0.9), (RED, MILK)[i], bevel=False)
            b.ico((0.9 + 0.8 * i, -0.3, 4.0), 0.36, BUTTER, subdivisions=1)
    elif kind == "cotton":
        b.cyl_base((-0.9, 0, 3.0), 1.0, 0.6, METAL, segments=10, bevel=False)
        for i, cc in enumerate((PINK, "pastel_sky", PINK, LILAC)):
            x = -0.9 + 0.9 * i
            b.cyl_base((x, -0.4, 3.0), 0.05, 1.3, MILK, segments=5, bevel=False)
            b.ico((x, -0.4, 4.6), 0.55, cc, subdivisions=1, scale=(1.0, 1.0, 1.25))
    else:
        b.box_base((0, 0, 3.0), (3.6, 1.6, 0.5), "glass", bevel=False)
        for i, cc in enumerate((PINK, "choco", BUTTER, MINT)):
            x = -1.35 + 0.9 * i
            b.cyl_base((x, 0, 3.5), 0.1, 0.7, "treat_tan", segments=6, radius2=0.3, bevel=False)
            b.ico((x, 0, 4.4), 0.36, cc, subdivisions=1)
    return [b.finalize(N + "FoodCart", mat)]


# ---------------------------------------------------------------------------------------------- the rides --
def _horse(t, x, y, z, yaw, col):
    R = Matrix.Rotation(yaw, 3, "Z")

    def at(lx, ly, lz):
        c, s = math.cos(yaw), math.sin(yaw)
        return (x + lx * c - ly * s, y + lx * s + ly * c, z + lz)
    t.box(at(0, 0, 0), (2.3, 0.85, 1.0), col, bevel=False, rot=R)
    t.box(at(1.2, 0, 0.75), (0.6, 0.6, 1.2), col, bevel=False, rot=R)
    t.box(at(1.65, 0, 1.15), (1.0, 0.55, 0.55), col, bevel=False, rot=R)
    t.box(at(0, 0, 0.6), (0.9, 0.95, 0.25), GOLD, bevel=False, rot=R)
    for lx in (-0.8, 0.8):
        t.box(at(lx, 0, -0.95), (0.3, 0.7, 0.9), col, bevel=False, rot=R)
    t.box(at(-1.3, 0, 0.1), (0.3, 0.3, 0.9), MILK, bevel=False, rot=R)


def carousel(mat):
    """The carousel: a round deck (radius 12, a gold step round it), a mirrored drum, and the turning part (its own
    object, `CarouselTurn`): eight horses on brass poles under a red cone top with a scalloped rim."""
    b, t = Builder(), Builder()
    R = 12.0
    b.cyl_base((0, 0, 0), R + 1.0, 0.4, GOLD, segments=24, bevel=False)
    b.cyl_base((0, 0, 0.4), R, 0.5, "fur_rose", segments=24, bevel=False)
    b.cyl_base((0, 0, 0.9), 3.0, 9.6, MILK, segments=12, bevel=False)
    for j in range(6):
        a = 2 * PI * j / 6
        b.box((3.0 * math.cos(a), 3.0 * math.sin(a), 5.2), (0.2, 1.8, 5.0), (GOLD, "pastel_sky")[j % 2], bevel=False,
              rot=(a, "Z"))
    t.cyl_base((0, 0, 10.5), R + 1.2, 0.8, RED, segments=24, bevel=False)
    t.cyl_base((0, 0, 11.3), R + 1.2, 4.2, RED, segments=12, radius2=0.6, bevel=False)
    for j in range(24):
        a = 2 * PI * (j + 0.5) / 24
        t.box(((R + 1.22) * math.cos(a), (R + 1.22) * math.sin(a), 10.2), (0.16, 2.6, 1.0), (MILK, GOLD)[j % 2],
              bevel=False, rot=(a, "Z"))
    t.ico((0, 0, 15.9), 0.9, GOLD, subdivisions=1)
    t.cyl_base((0, 0, 16.6), 0.08, 2.2, METAL, segments=5, bevel=False)
    t.box((0.8, 0, 18.3), (1.6, 0.06, 0.8), BUTTER, bevel=False)
    cols = (MILK, PINK, "pastel_sky", BUTTER, LILAC, MINT, "fur_peach", MILK)
    for k in range(8):
        a = 2 * PI * k / 8
        r = 8.8 if k % 2 == 0 else 6.2
        x, y = r * math.cos(a), r * math.sin(a)
        t.cyl_base((x, y, 0.95), 0.13, 9.6, "brass", segments=6, bevel=False)
        _horse(t, x, y, 3.2 + 0.9 * (k % 3) / 2, a + PI / 2, cols[k])
    return [b.finalize(N + "Carousel", mat), t.finalize(N + "CarouselTurn", mat)]


def teacups(mat):
    """The teacups: a striped round deck (radius 10) and the turning part (`TeacupsTurn`): six pastel cups with
    handles round a big teapot."""
    b, t = Builder(), Builder()
    b.cyl_base((0, 0, 0), 10.0, 0.5, LILAC, segments=24, bevel=False)
    b.cyl_base((0, 0, 0.5), 9.2, 0.12, MILK, segments=24, bevel=False)
    b.ring((0, 0, 0.9), 10.0, 0.3, 0.8, GOLD, segments=24, bevel=False)
    t.cyl_base((0, 0, 0.62), 8.4, 0.2, "fur_rose", segments=20, bevel=False)
    t.cyl_base((0, 0, 0.8), 2.0, 2.6, MILK, segments=12, radius2=2.4)                      # the teapot
    t.cyl_base((0, 0, 3.4), 2.4, 1.0, MILK, segments=12, radius2=1.0, bevel=False)
    t.ico((0, 0, 4.6), 0.45, GOLD, subdivisions=1)
    t.box((2.9, 0, 2.6), (1.6, 0.5, 0.5), MILK, bevel=False, rot=(-0.6, "Y"))               # its spout
    t.cyl_base((0, 0, 1.6), 2.36, 0.5, PINK, segments=12, bevel=False)
    for k, c in enumerate((PINK, "pastel_sky", BUTTER, MINT, LILAC, "fur_peach")):
        a = 2 * PI * k / 6
        x, y = 6.0 * math.cos(a), 6.0 * math.sin(a)
        t.cyl_base((x, y, 0.8), 0.9, 0.3, MILK, segments=10, bevel=False)
        t.cyl_base((x, y, 1.1), 1.5, 1.9, c, segments=10, radius2=1.9, bevel=False)
        t.cyl_base((x, y, 2.9), 1.95, 0.16, MILK, segments=10, bevel=False)
        t.ring((x + 2.3 * math.cos(a + 0.9), y + 2.3 * math.sin(a + 0.9), 2.0), 0.7, 0.22, 0.3, c, segments=8,
               rot=Matrix.Rotation(a + 0.9, 3, "Z") @ Matrix.Rotation(PI / 2, 3, "X"), bevel=False)
    return [b.finalize(N + "Teacups", mat), t.finalize(N + "TeacupsTurn", mat)]


def ferris_wheel(mat):
    """The Ferris wheel (the wheel in the local XZ plane, 20 in radius, its hub FERRIS_HUB up): a base, two A
    frames and a hub, and the turning part (`FerrisTurn`): two rims, spokes and twelve round pods (drums on the
    wheel's own axis, so a turn of the whole wheel leaves them looking upright)."""
    b, t = Builder(), Builder()
    R, H = FERRIS_R, FERRIS_HUB
    b.box_base((0, 0, 0), (26.0, 10.0, 0.8), BLUE, bevel=False)
    b.box_base((0, 0, 0.8), (22.0, 8.0, 0.3), MILK, bevel=False)
    for sy in (-1, 1):
        for sx in (-1, 1):
            L = math.hypot(9.0, H - 1.1)
            b.box((sx * 4.5, sy * 3.2, (H + 1.1) / 2), (0.9, 0.9, L), MILK, bevel=False,
                  rot=(math.atan2(-sx * 9.0, H - 1.1), "Y"))
        b.box((0, sy * 3.2, 9.0), (11.4, 0.5, 0.5), RED, bevel=False)
    b.cyl((0, 0, H), 1.3, 7.4, GOLD, segments=10, rot=(PI / 2, "X"), bevel=False)
    for sy in (-1, 1):
        t.ring((0, sy * 1.5, H), R, 0.6, 0.5, RED, segments=24, rot=(PI / 2, "X"), bevel=False)
        t.ring((0, sy * 1.5, H), R * 0.55, 0.4, 0.4, MILK, segments=16, rot=(PI / 2, "X"), bevel=False)
        t.cyl((0, sy * 1.9, H), 2.4, 0.5, BUTTER, segments=12, rot=(PI / 2, "X"), bevel=False)
        for k in range(12):
            a = 2 * PI * k / 12
            t.box((R / 2 * math.cos(a), sy * 1.5, H + R / 2 * math.sin(a)), (R - 0.4, 0.3, 0.3), (MILK, BUTTER)[k % 2],
                  bevel=False, rot=(-a, "Y"))
    for k in range(12):
        a = 2 * PI * (k + 0.5) / 12
        x, z = R * math.cos(a), H + R * math.sin(a)
        t.cyl((x, 0, z), 0.2, 3.4, METAL, segments=6, rot=(PI / 2, "X"), bevel=False)
        t.cyl((x, 0, z), 1.7, 2.3, BALLOONS[k % 6], segments=10, rot=(PI / 2, "X"), bevel=False)
        t.cyl((x, 0, z), 1.2, 2.44, "glass", segments=10, rot=(PI / 2, "X"), bevel=False)
    return [b.finalize(N + "FerrisWheel", mat), t.finalize(N + "FerrisTurn", mat)]


def drop_tower(mat):
    """The drop tower, 36 high: a striped mast on a stepped base, a ring of seats part way up, a gold star top."""
    b = Builder()
    b.box_base((0, 0, 0), (9.0, 9.0, 0.8), LILAC, bevel=False)
    b.box_base((0, 0, 0.8), (6.0, 6.0, 0.6), MILK, bevel=False)
    for j in range(8):
        b.box_base((0, 0, 1.4 + 4.0 * j), (2.8, 2.8, 4.02), ("aurora_violet", MILK)[j % 2], bevel=False)
    b.cyl_base((0, 0, 8.7), 4.6, 0.6, BUTTER, segments=12, bevel=False)
    for k in range(12):
        a = 2 * PI * (k + 0.5) / 12
        b.box((4.3 * math.cos(a), 4.3 * math.sin(a), 9.9), (0.5, 1.5, 1.4), BALLOONS[k % 6], bevel=False, rot=(a, "Z"))
    b.box_base((0, 0, 33.4), (4.0, 4.0, 0.6), GOLD, bevel=False)
    b.cyl_base((0, 0, 34.0), 2.4, 2.0, "aurora_violet", segments=8, radius2=0.3, bevel=False)
    b.ico((0, 0, 36.4), 0.6, GOLD, subdivisions=1)
    return [b.finalize(N + "DropTower", mat)]


def coaster_h(x):
    return 15.0 + 9.0 * math.cos(PI * x / 140.0) ** 2


def coaster_arch(mat):
    """The coaster's track as one tall arch across the width (along local x, 140 long): 15 up at the walls and 24
    over the path. The posts stand on the floor; the track and its train are _Decor (no collision overhead)."""
    b, d = Builder(), Builder()
    n = 20
    for i in range(n):
        x0, x1 = -70.0 + 7.0 * i, -63.0 + 7.0 * i
        z0, z1 = coaster_h(x0), coaster_h(x1)
        L = math.hypot(7.0, z1 - z0)
        R = (-math.atan2(z1 - z0, 7.0), "Y")
        xm, zm = (x0 + x1) / 2, (z0 + z1) / 2
        d.box((xm, 0, zm - 0.4), (L + 0.1, 0.6, 0.5 + 0.02 * (i % 2)), BLUE, bevel=False, rot=R)
        for sy in (-1, 1):
            d.box((xm, sy * 1.0, zm), (L + 0.1, 0.28, 0.28 + 0.02 * (i % 2)), RED, bevel=False, rot=R)
        for u in (-1.75, 1.75):
            d.box((xm + u, 0, zm - 0.12 + u * (z1 - z0) / 7.0), (0.4, 2.5, 0.16), MILK, bevel=False, rot=R)
    for x in COASTER_POSTS:
        h = coaster_h(x) - 0.7
        b.box_base((x, 0, 0), (3.0, 5.0, 0.6), ASPHALT_DARK, bevel=False)
        for sy in (-1, 1):
            b.cyl_base((x, sy * 1.7, 0.6), 0.42, h - 0.6, MILK, segments=8, bevel=False)
        for j in range(int(h // 5)):
            b.box((x, 0, 3.0 + 5.0 * j), (0.3, 3.4, 0.3), BLUE, bevel=False, rot=(0.6 * (-1) ** j, "X"))
        b.box((x, 0, h - 0.1), (0.6, 4.2, 0.4), BLUE, bevel=False)
    for i, x in enumerate((-9.5, -6.0, -2.5)):                            # the train, climbing to the top
        z = coaster_h(x) + 1.0
        R = (-math.atan2(coaster_h(x + 1) - coaster_h(x - 1), 2.0), "Y")
        d.box((x, 0, z), (3.1, 2.3, 1.3), (RED, BUTTER, RED)[i], bevel=False, rot=R)
        d.box((x, 0, z + 0.85), (2.2, 1.7, 0.5), "fur_ink", bevel=False, rot=R)
        if i == 2:
            d.box((x + 1.9, 0, z - 0.1), (0.9, 1.9, 0.9), GOLD, bevel=False, rot=R)
    return [b.finalize(N + "CoasterArch", mat), d.finalize(N + "CoasterArch_Decor", mat)]


# ---------------------------------------------------------------------------------------- the Splash Zone --
def lazy_river(mat):
    """The lazy river: a ring channel 9 wide between two low kerbs (KERB_H, a step up, never a wall), the water
    (_Water) and seven swim rings drifting on it (_Decor). Built round its own middle."""
    b, w, d = Builder(), Builder(), Builder()
    n = 44

    def pt(a, off):
        return ((RIVER_RX - off) * math.cos(a), (RIVER_RZ - off) * math.sin(a))
    for i in range(n):
        a0, a1 = 2 * PI * i / n, 2 * PI * (i + 1) / n
        for j, off in enumerate((0.3, RIVER_W - 0.3)):
            (x0, y0), (x1, y1) = pt(a0, off), pt(a1, off)
            L = math.hypot(x1 - x0, y1 - y0)
            b.box_base(((x0 + x1) / 2, (y0 + y1) / 2, 0), (L + 0.2, 0.6, KERB_H + 0.02 * (i % 2)),
                       (MILK, BLUE)[(i + j) % 2], bevel=False, rot=(math.atan2(y1 - y0, x1 - x0), "Z"))
        (x0, y0), (x1, y1) = pt(a0, RIVER_W / 2), pt(a1, RIVER_W / 2)
        L = math.hypot(x1 - x0, y1 - y0)
        w.box_base(((x0 + x1) / 2, (y0 + y1) / 2, 0.05), (L + 0.7, RIVER_W - 1.0, 0.4 + 0.012 * (i % 2)), WATER,
                   bevel=False, rot=(math.atan2(y1 - y0, x1 - x0), "Z"))
    for k in range(7):
        a = 0.5 + 2 * PI * k / 7
        x, y = pt(a, RIVER_W / 2 + 1.2 * math.sin(3 * k))
        d.ring((x, y, 0.62), 1.6, 0.7, 0.5, BALLOONS[k % 6], segments=10, bevel=False)
    return [b.finalize(N + "LazyRiver", mat), w.finalize(N + "LazyRiver_Water", mat),
            d.finalize(N + "LazyRiver_Decor", mat)]


BRIDGE_TOP = 1.15


def bridge(mat):
    """A plank bridge over the river, 14 wide (along local y): a flat deck BRIDGE_TOP up, a ramp at each end and a
    rail each side."""
    b = Builder()
    b.box_base((0, 0, 0), (SPINE_W, BRIDGE_L, BRIDGE_TOP), WOOD, bevel=False)
    for i in range(7):
        b.box_base((0, -BRIDGE_L / 2 + (i + 0.5) * BRIDGE_L / 7, BRIDGE_TOP), (SPINE_W - 0.2, BRIDGE_L / 7 - 0.14, 0.05),
                   ("treat_tan", WOOD)[i % 2], bevel=False)
    for sy in (-1, 1):
        b.wedge((0, sy * (BRIDGE_L / 2 + 3.0), BRIDGE_TOP / 2), (SPINE_W, 6.0, BRIDGE_TOP), WOOD, bevel=False,
                rot=None if sy < 0 else (PI, "Z"))
    for sx in (-1, 1):
        for y in (-BRIDGE_L / 2, 0.0, BRIDGE_L / 2):
            b.box_base((sx * (SPINE_W / 2 - 0.3), y, BRIDGE_TOP), (0.5, 0.5, 3.2), WOOD_DARK, bevel=False)
            b.ico((sx * (SPINE_W / 2 - 0.3), y, BRIDGE_TOP + 3.5), 0.42, GOLD, subdivisions=1)
        for z in (1.4, 2.7):
            b.box((sx * (SPINE_W / 2 - 0.3), 0, BRIDGE_TOP + z), (0.28, BRIDGE_L, 0.28), (RED, MILK)[z > 2], bevel=False)
    return [b.finalize(N + "Bridge", mat)]


def wave_pool(mat):
    """The wave pool, walled off as scenery: a tiled rim 1.3 high, glass to 9.4 on gold-capped posts (_Pane), the
    water (_Water) with wave crests and a beach ball on it (_Decor)."""
    b, w, p, d = Builder(), Builder(), Builder(), Builder()
    _, _, W, D = POOL
    b.box_base((0, 0, 0), (W + 2.0, D + 2.0, 0.3), MILK, bevel=False)
    for sy in (-1, 1):
        b.box_base((0, sy * (D / 2 + 0.5), 0.3), (W + 2.0, 1.0, 1.0), WATER_DEEP, bevel=False)
        p.box_base((0, sy * (D / 2 + 0.5), 1.3), (W + 1.4, 0.2, 8.1), "glass", bevel=False)
    for sx in (-1, 1):
        b.box_base((sx * (W / 2 + 0.5), 0, 0.3), (1.0, D, 1.02), WATER_DEEP, bevel=False)
        p.box_base((sx * (W / 2 + 0.5), 0, 1.3), (0.2, D + 1.4, 8.1), "glass", bevel=False)
    for (x, y) in [(sx * (W / 2 + 0.5), sy * (D / 2 + 0.5)) for sx in (-1, 0, 1) for sy in (-1, 1)] + \
                  [(sx * (W / 2 + 0.5), 0) for sx in (-1, 1)]:
        b.box_base((x, y, 1.3), (0.7, 0.7, 8.2), MILK, bevel=False)
        b.box_base((x, y, 9.5), (1.0, 1.0, 0.3), GOLD, bevel=False)
    w.box_base((0, 0, 0.3), (W - 0.1, D - 0.1, 0.75), WATER, bevel=False)
    for i in range(5):
        y = -D / 2 + 2.5 + i * (D - 5.0) / 4
        for j in range(3):
            d.box((-W / 2 + 5.0 + j * (W - 10.0) / 2 + 1.5 * (i % 2), y, 1.09 + 0.01 * j), (5.5, 0.6, 0.12), MILK,
                  bevel=False, rot=(0.12 * (-1) ** (i + j), "Z"))
    d.ico((W / 4, -D / 5, 1.9), 1.1, RED, subdivisions=1)
    d.ico((W / 4, -D / 5, 1.95), 0.9, MILK, subdivisions=1, scale=(1.25, 0.5, 1.2))
    return [b.finalize(N + "WavePool", mat), w.finalize(N + "WavePool_Water", mat),
            p.finalize(N + "WavePool_Pane", mat), d.finalize(N + "WavePool_Decor", mat)]


PAD_TOP = 0.2


def splash_pad(mat):
    """The splash pad: a low round pad of coloured rings with eight little jets (_Water) and the tipping bucket on
    its frame, 9.6 high."""
    b, w = Builder(), Builder()
    R = PAD[2]
    b.cyl_base((0, 0, 0), R, 0.14, WATER, segments=24, bevel=False)
    b.cyl_base((0, 0, 0), R * 0.72, 0.17, TILE_LIGHT, segments=20, bevel=False)
    b.cyl_base((0, 0, 0), R * 0.42, PAD_TOP, PINK, segments=16, bevel=False)
    for k in range(8):
        a = 2 * PI * k / 8
        x, y = R * 0.58 * math.cos(a), R * 0.58 * math.sin(a)
        b.cyl_base((x, y, 0.17), 0.3, 0.2, METAL, segments=8, bevel=False)
        w.cyl_base((x, y, 0.37), 0.16, 2.0 + 0.8 * (k % 2), WATER, segments=6, bevel=False)
        w.ico((x, y, 2.5 + 0.8 * (k % 2)), 0.34, TILE_LIGHT, subdivisions=1)
    for sx in (-1, 1):
        for j in range(5):
            b.cyl_base((sx * 2.6, 0, 0.2 + 1.8 * j), 0.36, 1.82, (RED, MILK)[j % 2], segments=8, bevel=False)
    b.box((0, 0, 9.3), (6.2, 0.5, 0.5), GOLD, bevel=False)
    b.cyl((0, 0, 7.6), 1.1, 2.4, BUTTER, segments=10, radius2=1.7, rot=(0.6, "X"), bevel=False)
    b.cyl((0, 0, 7.6), 1.74, 0.3, RED, segments=10, rot=(0.6, "X"), bevel=False)
    w.cyl((0, -1.9, 5.6), 0.5, 3.4, WATER, segments=6, rot=(0.35, "X"), bevel=False)
    return [b.finalize(N + "SplashPad", mat), w.finalize(N + "SplashPad_Water", mat)]


def beach_chair(mat, k=0):
    b = Builder()
    c = CANDY[k % 4]
    for i in range(5):
        b.box((0, -1.6 + 0.8 * i, 1.0), (2.0, 0.7, 0.18), (c, MILK)[i % 2], bevel=False)
    for i in range(3):
        b.box((0, 2.2 + 0.45 * i, 1.35 + 0.6 * i), (2.0, 0.7, 0.18), (MILK, c)[i % 2], bevel=False, rot=(0.9, "X"))
    for sx in (-1, 1):
        b.box((sx * 0.95, 0, 0.5), (0.16, 4.6, 0.16), WOOD, bevel=False)
        for y in (-1.7, 1.7):
            b.box_base((sx * 0.95, y, 0), (0.18, 0.18, 0.9), WOOD, bevel=False)
    return [b.finalize(N + "BeachChair", mat)]


def umbrella(mat, k=0):
    b = Builder()
    c = CANDY[k % 4]
    b.cyl_base((0, 0, 0), 0.7, 0.35, MILK, segments=8, bevel=False)
    b.cyl_base((0, 0, 0.35), 0.12, 6.4, WOOD, segments=6, bevel=False)
    b.cyl_base((0, 0, 6.2), 3.6, 1.5, c, segments=8, radius2=0.2, bevel=False)
    b.cyl_base((0, 0, 6.05), 3.66, 0.2, MILK, segments=8, bevel=False)
    b.ico((0, 0, 7.8), 0.25, GOLD, subdivisions=1)
    return [b.finalize(N + "Umbrella", mat)]


def lifeguard_tower(mat):
    """A lifeguard tower: a white hut on a deck 4.6 up, a red roof to 10, a ramp of steps at its back (front -Y)."""
    b = Builder()
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box_base((sx * 2.2, sy * 2.2, 0), (0.5, 0.5, 4.6), WOOD, bevel=False)
    b.box_base((0, 0, 4.6), (6.0, 6.0, 0.4), WOOD, bevel=False)
    b.box_base((0, 0.6, 5.0), (4.4, 3.6, 3.4), MILK, bevel=False)
    b.box((0, -1.22, 6.9), (2.4, 0.1, 1.4), "pastel_sky", bevel=False)
    b.box((0, -1.3, 7.9), (1.8, 0.1, 0.5), RED, bevel=False)
    b.box_base((0, 0.3, 8.4), (6.4, 5.4, 0.4), RED, bevel=False)
    b.box_base((0, 0.3, 8.8), (4.4, 3.6, 0.5), RED, bevel=False)
    b.box((0, -2.8, 6.2), (6.0, 0.2, 0.2), RED, bevel=False)
    for i in range(6):
        b.box_base((0, 3.6 + 0.9 * i, 0), (2.4, 0.92, 4.2 - 0.7 * i), WOOD, bevel=False)
    b.ring((3.2, -1.0, 6.0), 0.8, 0.3, 0.3, RED, segments=10, rot=(PI / 2, "Y"), bevel=False)
    return [b.finalize(N + "LifeguardTower", mat)]


def slide_tower(mat):
    """The big slide tower, 30 to its deck and 41 to its flag: a striped drum, a railed deck under a red cone roof
    and two spiral slides (butter and pink) winding down round it to two little splash pools."""
    b, w = Builder(), Builder()
    H = 30.0
    b.cyl_base((0, 0, 0), 7.0, 1.0, WATER_DEEP, segments=16, bevel=False)
    for j in range(6):
        b.cyl_base((0, 0, 1.0 + j * (H - 1.0) / 6), 5.0, (H - 1.0) / 6 + 0.02 * (j % 2), (BLUE, MILK)[j % 2],
                   segments=14, bevel=False)
    b.cyl_base((0, 0, H), 7.6, 0.6, WOOD, segments=16, bevel=False)
    b.ring((0, 0, H + 3.0), 7.6, 0.3, 0.3, GOLD, segments=16, bevel=False)
    for k in range(8):
        a = 2 * PI * k / 8
        b.cyl_base((7.3 * math.cos(a), 7.3 * math.sin(a), H + 0.6), 0.16, 5.0, MILK, segments=6, bevel=False)
    b.cyl_base((0, 0, H + 5.6), 8.6, 5.0, RED, segments=12, radius2=0.3, bevel=False)
    b.cyl_base((0, 0, H + 5.4), 8.7, 0.3, MILK, segments=12, bevel=False)
    b.ico((0, 0, H + 10.8), 0.6, GOLD, subdivisions=1)
    b.cyl_base((0, 0, H + 11.2), 0.08, 2.6, METAL, segments=5, bevel=False)
    b.box((0.9, 0, H + 13.3), (1.8, 0.06, 0.9), BUTTER, bevel=False)
    n, turns, r = 32, 2.25, 8.2
    seg = r * 2 * PI * turns / n
    dz = (H - 3.4) / n
    tilt = Matrix.Rotation(math.atan2(dz, seg), 3, "Y")
    for (col, a0) in ((BUTTER, 0.0), (PINK, PI)):
        for i in range(n):
            a = a0 + 2 * PI * turns * (i + 0.5) / n
            z = H - 0.6 - dz * (i + 0.5)
            R = Matrix.Rotation(a + PI / 2, 3, "Z") @ tilt
            b.box((r * math.cos(a), r * math.sin(a), z), (seg * 1.16, 2.3, 0.3 + 0.02 * (i % 2)), col, bevel=False,
                  rot=R)
            b.box(((r + 1.15) * math.cos(a), (r + 1.15) * math.sin(a), z + 0.5), (seg * 1.14, 0.25, 1.0), MILK,
                  bevel=False, rot=R)
            if i % 3 == 0:
                b.box(((r - 2.0) * math.cos(a), (r - 2.0) * math.sin(a), z - 0.3), (3.6, 0.3, 0.3), METAL, bevel=False,
                      rot=(a, "Z"))
        a = a0 + 2 * PI * turns + 0.22
        x, y = r * math.cos(a), r * math.sin(a)
        b.ring((x, y, 0.4), 2.3, 0.4, 0.8, col, segments=10, bevel=False)
        w.cyl_base((x, y, 0.05), 1.95, 0.5, WATER, segments=10, bevel=False)
    return [b.finalize(N + "SlideTower", mat), w.finalize(N + "SlideTower_Water", mat)]


def small_slide_tower(mat, k=0):
    """A small slide tower (front -Y): a deck 10 up on four posts under a cone roof, steps at its back and one
    straight slide down its front into a little pool."""
    b, w = Builder(), Builder()
    c = (GREEN, "neon_pink")[k % 2]
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.cyl_base((sx * 2.2, sy * 2.2, 0), 0.36, 14.0, MILK, segments=8, bevel=False)
    b.box_base((0, 0, 10.0), (5.6, 5.6, 0.5), WOOD, bevel=False)
    b.cyl_base((0, 0, 14.0), 4.6, 3.4, (BLUE, RED)[k % 2], segments=8, radius2=0.2, bevel=False)
    b.ico((0, 0, 17.6), 0.4, GOLD, subdivisions=1)
    for i in range(7):
        b.box_base((0, 3.3 + 0.9 * i, 0), (2.6, 0.92, 9.8 - 1.4 * i), WOOD, bevel=False)
    L = math.hypot(10.0, 9.2)
    R = (math.atan2(9.2, 10.0), "X")
    b.box((0, -7.6, 5.6), (2.6, L, 0.35), c, bevel=False, rot=R)
    for sx in (-1, 1):
        b.box((sx * 1.4, -7.6, 6.0), (0.25, L, 1.0), MILK, bevel=False, rot=R)
    b.ring((0, -15.0, 0.4), 2.6, 0.4, 0.8, c, segments=10, bevel=False)
    w.cyl_base((0, -15.0, 0.05), 2.25, 0.5, WATER, segments=10, bevel=False)
    return [b.finalize(N + "SmallSlideTower", mat), w.finalize(N + "SmallSlideTower_Water", mat)]


def kids_pool(mat, k=0):
    """A kids' pool: a round kerb (radius 7), shallow water (_Water) and a spotted mushroom fountain."""
    b, w = Builder(), Builder()
    b.ring((0, 0, 0.3), 7.0, 0.7, 0.6, (BUTTER, PINK)[k % 2], segments=20, bevel=False)
    b.cyl_base((0, 0, 0), 6.4, 0.08, TILE_LIGHT, segments=20, bevel=False)
    w.cyl_base((0, 0, 0.08), 6.3, 0.34, WATER, segments=20, bevel=False)
    b.cyl_base((0, 0, 0.08), 0.5, 3.4, MILK, segments=8, bevel=False)
    b.cyl_base((0, 0, 3.4), 2.6, 1.2, RED, segments=10, radius2=0.5, bevel=False)
    for j in range(5):
        a = 2 * PI * j / 5
        b.ico((1.5 * math.cos(a), 1.5 * math.sin(a), 4.05), 0.36, MILK, subdivisions=1)
    for j in range(3):
        a = 1.0 + 2 * PI * j / 3
        b.ico((4.2 * math.cos(a), 4.2 * math.sin(a), 0.62), 0.36, BUTTER, subdivisions=1)
    return [b.finalize(N + "KidsPool", mat), w.finalize(N + "KidsPool_Water", mat)]


def ring_stack(mat, k=0):
    b = Builder()
    for j in range(4):
        b.ring((0.1 * (-1) ** j, 0, 0.3 + 0.55 * j), 1.5, 0.65, 0.5, BALLOONS[(j + k) % 6], segments=10, bevel=False)
    return [b.finalize(N + "RingStack", mat)]


def beach_ball(mat, k=0):
    b = Builder()
    b.ico((0, 0, 1.0), 1.0, (RED, BLUE)[k % 2], subdivisions=1)
    b.ico((0, 0, 1.02), 0.82, MILK, subdivisions=1, scale=(1.26, 0.45, 1.2))
    b.ico((0, 0, 1.02), 0.82, BUTTER, subdivisions=1, scale=(0.45, 1.26, 1.2))
    return [b.finalize(N + "BeachBall", mat)]


# --------------------------------------------------------------------------------------- the rescue traps --
TRAP_DECK = 0.3


def trap_carousel(mat):
    """A little kiddie carousel: a round deck TRAP_DECK up, four brass poles and a low striped cone top, open all
    round; the cat sits on the deck's middle."""
    b = Builder()
    b.cyl_base((0, 0, 0), 3.0, 0.16, GOLD, segments=14, bevel=False)
    b.cyl_base((0, 0, 0), 2.7, TRAP_DECK, "fur_rose", segments=14, bevel=False)
    for k in range(4):
        a = PI / 4 + PI / 2 * k
        b.cyl_base((2.3 * math.cos(a), 2.3 * math.sin(a), TRAP_DECK), 0.12, 3.9, "brass", segments=6, bevel=False)
        b.box((2.3 * math.cos(a), 2.3 * math.sin(a), 1.6), (0.5, 1.2, 0.6), (MILK, PINK, "pastel_sky", BUTTER)[k],
              bevel=False, rot=(a + PI / 2, "Z"))
    b.cyl_base((0, 0, 4.2), 3.2, 0.3, MILK, segments=14, bevel=False)
    b.cyl_base((0, 0, 4.5), 3.2, 1.5, RED, segments=10, radius2=0.2, bevel=False)
    b.ico((0, 0, 6.2), 0.3, GOLD, subdivisions=1)
    return [b.finalize(N + "TrapCarousel", mat)]


def trap_ball_pit(mat):
    """A round ball pit: a soft wall 1.1 high and coloured balls heaped inside it round the spot, so a cat there is
    in them up to its chest (the middle is open)."""
    b = Builder()
    b.ring((0, 0, 0.55), 3.1, 0.6, 1.1, BLUE, segments=14, bevel=False)
    b.ring((0, 0, 1.15), 3.14, 0.68, 0.14, BUTTER, segments=14, bevel=False)
    b.cyl_base((0, 0, 0), 2.6, 0.1, MILK, segments=14, bevel=False)
    for k in range(22):
        a = 2 * PI * k / 11 + 0.3 * (k // 11)
        r = 1.45 + 0.75 * (k // 11)
        b.ico((r * math.cos(a), r * math.sin(a), 0.42 + 0.3 * ((k * 7) % 3) / 2), 0.4, BALLOONS[(k * 5) % 6],
              subdivisions=1)
    return [b.finalize(N + "TrapBallPit", mat)]


def trap_plush_pile(mat):
    """A heap of prize plushies round the spot and a tipped shelf behind it (local +Y), a cat in the middle with only
    its head out."""
    b = Builder()
    cols = (PINK, BUTTER, LILAC, MINT, "fur_peach", "pastel_sky")
    for k in range(9):
        a = PI / 2 + 2 * PI * (k + 0.5) / 10                               # open toward local -Y
        r = 1.9 + 0.35 * (k % 2)
        _plush(b, (r * math.cos(a), r * math.sin(a), 0.0 + 0.5 * (k % 2)), 0.62 + 0.08 * (k % 3), cols[k % 6])
    b.box((0, 3.3, 1.2), (5.0, 0.3, 2.6), WOOD, bevel=False, rot=(0.5, "X"))
    b.cyl_base((0, 0.3, 0), 3.2, 0.1, "fur_rose", segments=14, bevel=False)
    return [b.finalize(N + "TrapPlushPile", mat)]


def trap_plush_nook(mat):
    """The plush pile cut down for the 8 x 7 nook: seven small plushies in a ring 1.35 out round the spot, open
    toward local -Y, on a pink mat. The same trap type as trap_plush_pile."""
    b = Builder()
    cols = (PINK, BUTTER, LILAC, MINT, "fur_peach", "pastel_sky")
    for k in range(7):
        a = PI / 2 + 2 * PI * (k + 0.5) / 8
        _plush(b, (1.35 * math.cos(a), 1.35 * math.sin(a), 0.0), 0.42 + 0.05 * (k % 3), cols[k % 6])
    b.cyl_base((0, 0, 0), 1.9, 0.06, "fur_rose", segments=12, bevel=False)
    return [b.finalize(N + "TrapPlushNook", mat)]


def trap_river_ring(mat):
    """A swim ring stuck on a puddle: the ring round the spot, the cat sitting in it, a few splash drops."""
    b = Builder()
    b.cyl_base((0, 0, 0), 3.3, 0.1, WATER, segments=14, bevel=False, scale=(1.0, 0.85, 1.0))
    b.cyl_base((0.4, 0.2, 0), 2.2, 0.13, TILE_LIGHT, segments=12, bevel=False, scale=(1.0, 0.8, 1.0))
    b.ring((0, 0, 0.55), 1.9, 0.8, 0.8, PINK, segments=12, bevel=False)
    for k in range(6):
        a = 2 * PI * k / 6
        b.box((1.5 * math.cos(a), 1.5 * math.sin(a), 0.97), (0.84, 0.5, 0.06), MILK, bevel=False, rot=(a, "Z"))
    for k in range(5):
        a = 0.7 + 2 * PI * k / 5
        b.ico((2.8 * math.cos(a), 2.4 * math.sin(a), 0.3), 0.2, TILE_LIGHT, subdivisions=1)
    return [b.finalize(N + "TrapRiverRing", mat)]


def trap_balloons(mat):
    """A bunch of balloons tied to a weight behind the spot (local +Y), floating over it: the cat holds the string
    with its feet just off the ground (the balloons and string are _Decor)."""
    b, d = Builder(), Builder()
    b.box_base((0, 1.6, 0), (1.0, 1.0, 0.8), RED, bevel=False)
    b.cyl_base((0, 0, 0), 2.6, 0.08, BUTTER, segments=12, bevel=False)
    d.box((0, 0.8, 1.9), (0.08, 0.08, 2.9), MILK, bevel=False, rot=(0.6, "X"))
    d.cyl_base((0, 0, 3.0), 0.05, 2.6, MILK, segments=5, bevel=False)
    for i in range(7):
        a = 2 * PI * i / 6
        r = 1.0 if i < 6 else 0.0
        d.ico((r * math.cos(a), r * math.sin(a), 6.3 + 0.8 * (i % 3) + (1.5 if i == 6 else 0)), 0.9,
              BALLOONS[i % 6], subdivisions=1, scale=(1.0, 1.0, 1.2))
    return [b.finalize(N + "TrapBalloons", mat), d.finalize(N + "TrapBalloons_Decor", mat)]


TRAPS = {"trap_carousel": (trap_carousel, 4.0), "trap_ball_pit": (trap_ball_pit, 4.0),
         "trap_plush_pile": (trap_plush_pile, 4.5), "trap_river_ring": (trap_river_ring, 4.0),
         "trap_balloons": (trap_balloons, 3.5)}
TRAP_Y = {"trap_carousel": TRAP_DECK}


def all_traps():
    out = [t for t in MAIN_TRAPS]
    for label, pool in (("trap_carousel", POOL_CAROUSELS), ("trap_ball_pit", POOL_BALL_PITS),
                        ("trap_plush_pile", POOL_PLUSH), ("trap_river_ring", POOL_RINGS),
                        ("trap_balloons", POOL_BALLOONS)):
        out += [(label, x, z, t) for (x, z, t) in pool]
    return out


def check_layout():
    """The rescue pool's rules (as the Desert's): 15 traps, every one 25 from every other, off the paths, the
    blockers and the river, none within 100 of the camp; four of the five main ones and six of the pool deep."""
    traps = all_traps()
    assert len(traps) == 15, len(traps)
    for i, (la, xa, za, _) in enumerate(traps):
        assert near_trail(xa, za) > 3.0, (la, xa, za, near_trail(xa, za))
        assert not in_block(xa, za, 2.0), (la, xa, za)
        assert not in_river(xa, za, 3.0), (la, xa, za)
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

    _walls(s, mat)

    # the Midway: two rows of booths facing the spine, lamps between them, prize walls and carts along the walls
    for i, bz in enumerate(BOOTH_Z):
        for sx in (-1, 1):
            put(booth(mat, i + (sx > 0) * 2), sx * BOOTH_X, bz, 90 * sx, r=8)
            _spot(s, "booth", sx * (BOOTH_X - BOOTH_D / 2 - 3.6), bz + 2.0 * (-1) ** i)
            if i < 5:
                _spot(s, "booth_gap", sx * BOOTH_X, bz + 8.5)
        if i < 5:
            for sx in (-1, 1):
                put(lamp(mat), sx * 9.4, bz + 8.5, 0, r=1.2)
    for sx in (-1, 1):
        for j, z in enumerate((-250.0, -212.0)):
            put(prize_wall(mat, 14.0, j + (sx > 0)), sx * (IN_X - 1.6), z, 90 * sx, r=8)
            _spot(s, "prize_wall", sx * (IN_X - 6.5), z + 3.0)
        for j, (z, kind) in enumerate(((-266.0, "popcorn"), (-231.0, "cotton"), (-192.0, "ice"), (-170.0, "popcorn"))):
            kind = kind if sx > 0 else ("ice", "popcorn", "cotton", "ice")[j]
            put(food_cart(mat, kind), sx * 55.0, z, 90 * sx, r=4)
            _spot(s, "food_cart", sx * 50.0, z + 3.4)
        for j, z in enumerate((-240.0, -200.0)):
            put(bench(mat), sx * 48.5, z, -90 * sx, r=2.6)
            _spot(s, "bench", sx * 46.0, z)
        for j, z in enumerate((-258.0, -222.0, -182.0)):
            put(balloon_bunch(mat, j + (sx > 0)), sx * 60.0, z, 0, r=1.5)
        put(trash_can(mat, sx > 0), sx * 47.0, -262.0, 0, r=1.4)
        for z in (-246.0, -206.0, -176.0):
            _spot(s, "alley", sx * (ALLEY_X + 1.5 * (-1) ** int(z)), z)
        for z in (-264.0, -162.0):
            _spot(s, "midway_end", sx * 22.0, z - 1.0 if z < -200 else z + 1.5)
    put(park_sign(mat, 0), -8.6, -268.0, 20, r=1.4)
    put(park_sign(mat, 1), 8.6, -150.0, -30, r=1.4)

    # Ride Row: the carousel and the teacups on their discs, the wheel by the east wall, the drop tower by the
    # west, the coaster's arch over it all
    x, z, r = RIDES["carousel"]
    put(carousel(mat), x, z, 0, r=r + 1)
    for a in (20, 110, 200, 290):
        _spot(s, "carousel", x + (r + 3.0) * math.cos(math.radians(a)), z + (r + 3.0) * math.sin(math.radians(a)))
    x, z, r = RIDES["teacups"]
    put(teacups(mat), x, z, 0, r=r + 1)
    for a in (60, 150, 240, 330):
        _spot(s, "teacups", x + (r + 3.0) * math.cos(math.radians(a)), z + (r + 3.0) * math.sin(math.radians(a)))
    put(ferris_wheel(mat), FERRIS[0], FERRIS[1], 90, r=14)
    for dz in (-17.0, 0.0, 17.0):
        _spot(s, "ferris", FERRIS[0] - 9.0, FERRIS[1] + dz)
    put(drop_tower(mat), DROP[0], DROP[1], 0, r=7)
    for (dx, dz) in ((8.0, 0.0), (0.0, -8.5), (0.0, 8.5)):
        _spot(s, "drop_tower", DROP[0] + dx, DROP[1] + dz)
    s.put(coaster_arch(mat), 0.0, COASTER_Z, 0)
    for px in COASTER_POSTS:
        keep.append((px, COASTER_Z, 3.5))
        _spot(s, "coaster_post", px + 4.5 * (1 if px < 0 else -1), COASTER_Z + 5.0)
    for (x, z, rot) in ((-12, -140, 90), (12, -80, -90), (-12, -50, 90), (12, 8, -90), (-44, -66, 0), (44, -72, 0)):
        put(bench(mat), x, z, rot, r=2.6)
        _spot(s, "bench", *turned(x, z, rot, 0.0, -2.2))
    for (x, z, kind, rot) in ((-22, -146, "cotton", 0), (20, -148, "ice", 0), (-30, -60, "popcorn", 180),
                              (26, -30, "cotton", -90), (-30, 6, "ice", 0)):
        put(food_cart(mat, kind), x, z, rot, r=4)
        _spot(s, "food_cart", *turned(x, z, rot, 3.6, -1.0))
    for j, (x, z) in enumerate(((-62, -126), (62, -78), (-20, -74), (22, -100), (-64, -4), (64, 4), (-46, -150))):
        put(balloon_bunch(mat, j), x, z, 0, r=1.5)
    for (x, z) in ((-60, -84), (-14, -124), (16, -146), (62, -132), (-40, -40), (40, -22), (-20, -24), (20, -52),
                   (-62, -56), (30, 10), (-46, 12)):
        _spot(s, "ride_row", x, z)
    for z in (-140.0, -100.0, -60.0, -24.0, 12.0):
        for sx in (-1, 1):
            put(lamp(mat), sx * 9.4, z, 0, r=1.2)
    for j, (x, z) in enumerate(((-9.6, -120.0), (9.6, -40.0))):
        put(trash_can(mat, j), x, z, 0, r=1.4)

    # the Splash Zone: the river and its bridges, the pad and the pool inside the ring, chairs and umbrellas outside
    s.put(lazy_river(mat), RIVER[0], RIVER[1], 0)
    for sz in (-1, 1):
        bz = RIVER[1] + sz * (RIVER_RZ - RIVER_W / 2)
        s.put(bridge(mat), 0.0, bz, 0)
        keep.append((0.0, bz, 12))
    put(wave_pool(mat), POOL[0], POOL[1], 0, r=18)
    put(splash_pad(mat), PAD[0], PAD[1], 0, r=PAD[2] + 1)
    for a in (40, 160, 280):
        _spot(s, "splash_pad", PAD[0] + 8.2 * math.cos(math.radians(a)), PAD[1] + 8.2 * math.sin(math.radians(a)),
              y=0.14)
    for (x, z) in ((POOL[0], POOL[1] - 15.5), (POOL[0], POOL[1] + 15.5), (POOL[0] - 17.0, POOL[1] + 6.0)):
        _spot(s, "wave_pool", x, z)
    for (x, z) in ((-12, 56), (12, 54), (-12, 106), (12, 108), (-30, 100), (-34, 62), (22, 100), (-12, 80)):
        _spot(s, "river_isle", x, z)
    put(lifeguard_tower(mat), 60.0, 80.0, 90, r=6)
    _spot(s, "lifeguard", 53.5, 74.0)
    k = 0
    for (x, z, rot) in ((-58, 60, -90), (-62, 84, -90), (58, 34, 90), (60, 100, 90), (-40, 30, 160), (40, 28, 200),
                        (-44, 132, 20), (42, 134, -20)):
        put(beach_chair(mat, k), x, z, rot, r=3)
        put(umbrella(mat, k + 1), *turned(x, z, rot, 3.2, 1.0), 0, r=1.2)
        _spot(s, "beach_chair", *turned(x, z, rot, -3.0, 0.0))
        k += 1
    for j, (x, z) in enumerate(((-64, 24), (64, 24), (-66, 128), (66, 132), (-24, 26), (24, 134))):
        put(planter_palm(mat, 8.0 + (j % 3)), x, z, j * 50, r=2.4)
        _spot(s, "palm", x + (3.2 if x < 0 else -3.2), z + 1.0)
    for j, (x, z) in enumerate(((-50, 44), (48, 120), (-66, 104), (66, 66))):
        put(ring_stack(mat, j), x, z, 0, r=2)
    for j, (x, z) in enumerate(((50, 62), (-48, 122), (10, 70))):
        put(beach_ball(mat, j), x, z, j * 40, r=1.4)
    for (x, z) in ((-66, 66), (-52, 100), (52, 122), (66, 44), (-50, 22), (44, 140)):
        _spot(s, "splash_shore", x, z)
    for z in (26.0, 62.0, 98.0, 136.0):
        for sx in (-1, 1):
            if abs(z - (RIVER[1] - RIVER_RZ + RIVER_W / 2)) < 12 or abs(z - (RIVER[1] + RIVER_RZ - RIVER_W / 2)) < 12:
                continue
            put(lamp(mat), sx * 9.4, z, 0, r=1.2)

    # the Slide Tower: the big tower in the loop, the small towers and the kids' pools outside it
    put(slide_tower(mat), TOWER[0], TOWER[1], 0, r=TOWER_R + 1)
    for a in (30, 90, 150, 210, 270, 330):
        _spot(s, "slide_tower", TOWER[0] + (TOWER_R + 4.0) * math.cos(math.radians(a)),
              TOWER[1] + (TOWER_R + 4.0) * math.sin(math.radians(a)))
    for j, (x, z, rot) in enumerate(SMALL_TOWERS):
        put(small_slide_tower(mat, j), x, z, rot, r=7)
        f = -math.sin(math.radians(rot))
        keep.append((x + 12.0 * f, z, 6))
        _spot(s, "small_slide", x + 8.0 * f, z + 6.5)
        _spot(s, "small_slide", x + 15.0 * f, z - 6.0)
    for j, (x, z) in enumerate(KIDS_POOLS):
        put(kids_pool(mat, j), x, z, 0, r=8)
        _spot(s, "kids_pool", x - 9.5 * (1 if x > 0 else -1), z)
        _spot(s, "kids_pool", x, z + 9.5 * (-1 if z > 200 else 1))
    for (x, z) in ((-20, 226), (22, 196), (-16, 250), (14, 172), (22, 222), (-22, 204)):
        _spot(s, "loop_inside", x, z)
    for (x, z) in ((-48, 200), (48, 216), (-46, 252), (46, 262), (-64, 198), (66, 216), (-30, 268), (28, 270),
                   (-48, 160), (46, 164)):
        _spot(s, "tower_yard", x, z)
    k = 0
    for (x, z, rot) in ((-48, 244, -60), (46, 228, 70), (-20, 160, 180), (22, 258, 10)):
        put(beach_chair(mat, k + 2), x, z, rot, r=3)
        put(umbrella(mat, k), *turned(x, z, rot, 3.2, 1.0), 0, r=1.2)
        k += 1
    for j, (x, z) in enumerate(((-66, 150), (66, 152), (-66, 270), (66, 270), (-44, 190), (44, 244))):
        put(planter_palm(mat, 9.0 + (j % 3)), x, z, j * 70, r=2.4)
    for j, (x, z) in enumerate(((-26, 236), (26, 180), (64, 232))):
        put(balloon_bunch(mat, j + 1), x, z, 0, r=1.5)
    for (x, z) in ((-6.4, 146.0), (6.4, 146.0), (-39.8, 209.0), (39.8, 209.0), (-5.0, 272.0), (5.0, 272.0)):
        put(lamp(mat), x, z, 0, r=1.2)
    put(park_sign(mat, 2), 8.8, 142.0, 0, r=1.4)

    # the rescue spots: the five main ones and the pool (scenery until the day's pick puts a stuck cat in one)
    for (label, x, z, t) in all_traps():
        fn, r = TRAPS[label]
        put(fn(mat), x, z, t, r=r)
        _spot(s, label, x, z, y=TRAP_Y.get(label, 0.0), turn=t)

    # filler: palms in pots, ring stacks, beach balls and bins, clear of the paths, the blockers, the river, the
    # pieces and the spots
    spots = [(p[0], p[2]) for lst in s.points.values() for p in lst]
    k = 0
    for gx in range(-64, 65, 16):
        for gz in range(-262, 263, 18):
            k += 1
            x = gx + 5.0 * math.sin(k * 2.71)
            z = gz + 5.0 * math.cos(k * 1.93)
            if z < -IN_Z + 16 and abs(x) < GATE_HALF + 10:
                continue
            if near_trail(x, z) < 4.5 or in_block(x, z, 4.0) or in_river(x, z, 3.0) or abs(x) > IN_X - 4:
                continue
            if abs(z - COASTER_Z) < 4.0:
                continue
            if any(math.hypot(x - qx, z - qz) < qr + 4.0 for (qx, qz, qr) in keep):
                continue
            if any(math.hypot(x - qx, z - qz) < 6.0 for (qx, qz) in spots):
                continue
            if k % 4 == 0:
                s.put(planter_palm(mat, 7.0 + (k % 3)), x, z, (k * 53) % 360)
            elif k % 4 == 1:
                s.put((ring_stack if z > TILE_Z else trash_can)(mat, k), x, z, (k * 37) % 360)
            elif k % 4 == 2:
                s.put((beach_ball if z > TILE_Z else balloon_bunch)(mat, k), x, z, (k * 37) % 360)
    return s.finish(_ground(), mat), s


def build_waterpark_set(mat):
    objs, _ = build_set(mat)
    return objs


ASSETS = {
    NAME: (build_waterpark_set, 150000),
}
