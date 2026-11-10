"""The Desert (Tier 6, Sunstone Cafe; tier6-7-areas.md sections 3 and 4): a long rectangle, 150 x 560 for the wild
part, with the camp (CatCafe_Camp_Desert, camps.py) 30 more across its -Z end, outside it, as on every F85 area.

  CatCafe_Desert_Set   the wild part dressed, in area space (areakit): place it at the area's centre on its floor,
                       camp side -Z, like every set (WorldBuilder turns it 180, its camp on the north edge). Walls at
                       x +-75 and z +-280 (Config.World's DesertWidth 150, DesertDepth 560); the way in is the 24 stud
                       opening (CampOpeningWidth) at x 0 on z -280.

No grass anywhere (section 3): the whole floor is sand, the paths packed sand and flagstones, and the edges dunes,
red mesas and broken sandstone walls 11 to 16 high. No blocker runs wall to wall, so the way on is a short walk
round an end. Nothing invisible stands inside the area (#2897, Derek2 11-10): every blocker stops a player where it
is drawn and a nimble player may climb one; the only _Barrier is the 30 high ring in the border's wall band, which
starts BAR_IN behind the border's drawn faces. invisible_walls.py checks it. The zones, camp first (the Oasis Camp is
the camp set's):

  z -276 to -110   the Dune Sea: two dune ridges 7.5 to 8.5 high cross the width as islands (z -215: x -54 to -12
                   and 16 to 52; z -150: x -40 to 10 and 34 to the east wall), each a row of crested dunes with
                   their horns curving away, low walkable dune humps on the trail, sand ripples, half buried pots
                   and old crates
  z -110 to -20    the Red Canyon: two red rock masses of stepped buttes 11 to 18 high (x -71.5 to -9 and 9 to 54, strata bands, rock faces)
                   leave the slot canyon 18 wide up the middle, a side alcove off each wall of it, and a side passage
                   17.5 wide along the east wall
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
Four of the five are deep and none is within 100 studs of the camp. The rescue pool (#2240's shape, Gameplay 11-09)
adds ten more of the three kinds (POOL_DUNES, POOL_URNS, POOL_CANOPIES), 15 in all, ten of them deep, every one 25
or more from every other, off the trail and the blockers and 8 or more from every cat spot.
"""

import math
from itertools import pairwise

from mathutils import Matrix, Vector

from areakit import PI, Set, turned
from common import RB, Builder
from woodsset import _dist_seg, _path, bl, face

NAME = "CatCafe_Desert_Set"
N = "CatCafe_Desert_"
HALF_X, HALF_Z = 75.0, 280.0            # WorldBuilder's walls at +-75, +-280 (DesertWidth 150, DesertDepth 560)
WALL_D = 3.0
IN_X, IN_Z = HALF_X - 0.5 - WALL_D, HALF_Z - 0.5 - WALL_D       # 71.5, 276.5
GATE_HALF = 12.0                        # CampOpeningWidth 24
BARRIER_H = 30.0
BAR_IN = 0.8                            # the border's barrier starts this far into the wall band (#2897)
TRAIL_W = 7.0

# the palette (section 4): sand, sandstone, canyon red, oasis teal, the canopies' stripes in the rarity colours
SAND, SAND_DUNE, SAND_DARK = "fur_oat", "fur_dune", "treat_tan"
STONE, STONE_LIGHT, STONE_DARK = "fur_caramel", "paving_tan", "fur_latte"
RED, RED_LIGHT, RED_DARK = "fur_copper", "terracotta", "fur_russet"
CLAY, CRACK = "fur_latte", "fur_hazel"
PATH, PATH_EDGE = "paving_grout", "fur_hazel"   # packed earth, darker than the sand and the clay (#2834; was paving_tan)
STRIPES = ("rarity_common", "rarity_rare", "rarity_epic", "rarity_legend", "rarity_mythic")

DUNE_A_Z, ISLE_A = -215.0, [(-54.0, -12.0), (16.0, 52.0)]
DUNE_B_Z, ISLE_B = -150.0, [(-40.0, 10.0), (34.0, IN_X)]
DUNE_TOP = 8.5                          # just over a jump (7.2); was 11, too big (Derek 11-09)
CANYON_Z0, CANYON_Z1 = -110.0, -20.0
SLOT_HALF = 9.0                         # the slot canyon, 18 wide
EAST_MASS = 54.0                        # the east mass ends here; the side passage beyond, to the wall
CANYON_H = 18.0                         # the tallest butte, by the slot (was 20 all over)
ARCH_Z = -66.0
ALCOVES = ((-1, -78.0), (1, -48.0))     # (side, z): where a lane between two buttes meets the slot
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
# the rescue pool past today's five (x, z, turn)
POOL_DUNES = ((43.0, -176.0, 0), (-30.0, -6.0, 0), (-30.0, 180.0, 0), (-20.0, 88.0, 0))
POOL_URNS = ((-32.0, -124.0, 160), (-30.0, 122.0, 30), (42.0, 204.0, -120))
POOL_CANOPIES = ((52.0, -126.0, -70), (-58.0, 156.0, 80), (56.0, 236.0, -100))

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
    return sum(math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(TRAIL[:-1], TRAIL[1:]))


def _spot(s, label, x, z, y=0.0, turn=None):
    p = [round(x, 2), round(y, 2), round(z, 2), "deep" if z > 0 else "near"]
    if turn is not None:
        p.append(turn)
    s.points.setdefault(label, []).append(p)


# ------------------------------------------------------------------------------------------------- ground --
def _trail_to(z_end):
    """TRAIL cut where it first reaches z_end."""
    out = [TRAIL[0]]
    for (ax, az), (bx, bz) in pairwise(TRAIL):
        if bz < z_end:
            out.append((bx, bz))
            continue
        t = (z_end - az) / (bz - az)
        out.append((ax + (bx - ax) * t, z_end))
        break
    return out


def _ground():
    """Sand over the whole floor (no plate shows, no grass), the trail of packed sand, the clay pan and its cracks,
    the courtyard's flagstones, and sand ripples on the dune sea."""
    g = Builder()
    g.box_base((0, 0, 0), (2 * HALF_X, 2 * HALF_Z, 0.03), SAND, bevel=False)
    # packed earth with a darker rim, up to the courtyard (its flagstones are the way on from there). Every top, the
    # bends' discs too, keeps 0.016 or more from the pan's (0.05) and from the other colour's, so rbx_zfight has
    # nothing to lift: rim 0.078 and 0.084 (discs 0.068), middle 0.11 and 0.116 (discs 0.1)
    way = _trail_to(COURT[1] - 20.0)
    _path(g, way, TRAIL_W + 1.4, PATH_EDGE, 0.078)
    _path(g, way, TRAIL_W, PATH, 0.11)
    _path(g, SIDE, 6.4, PATH_EDGE, 0.078)
    _path(g, SIDE, 5.0, PATH, 0.11)
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
    """A sand bank against the wall: a bank 8.5 to 10 high in three rolling pieces, each a dune's rounded windward
    slope (dune_piece's facets, #2897) leaning 4.2 into the area up to its crest BAR_IN behind the face line, so the
    border's barrier starts right at the crest, the bank behind it and a lighter crest along its top."""
    n = 3
    w = L / n
    R = Matrix(((0, 0, 1), (1, 0, 0), (0, 1, 0)))                 # profile (y, up), run along x
    for i in range(n):
        x = -L / 2 + (i + 0.5) * w
        H = 8.5 + 1.5 * (((i * 2 + k) % 3) / 2)
        c = BAR_IN
        prof = [(-3.4, 0.0), (-2.5, 0.2 * H), (-1.55, 0.52 * H), (-0.6, 0.85 * H), (c, H)]
        b.fan((x, 0, 0), (c, 0.0), prof, w + 0.02 * i, SAND_DUNE, rot=R)                         # the slope
        b.box_base((x, (c + WALL_D) / 2, 0), (w + 0.02 * i, WALL_D - c, H), SAND_DUNE, bevel=False)   # the bank
        b.box_base((x, 1.5, H), (w * 0.9, 1.4, 0.35), SAND, bevel=False)                            # the crest


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
    T = WALL_D - BAR_IN                    # the barrier starts BAR_IN inside the wall band, behind every drawn face
    mid = IN_Z + BAR_IN + T / 2
    bar.box_base((0, mid, 0), (2 * ox, T, BARRIER_H), "offwhite", bevel=False)                                # far
    for sx in (-1, 1):
        bar.box_base((sx * (IN_X + BAR_IN + T / 2), 0, 0), (T, 2 * IN_Z, BARRIER_H), "offwhite", bevel=False)   # sides
        bar.box_base((sx * (GATE_HALF + ox) / 2, -mid, 0), (ox - GATE_HALF, T, BARRIER_H), "offwhite",
                     bevel=False)                                                                             # camp
    s.put([bar.finalize(N + "Walls_Barrier", mat)], 0, 0, 0)


# -------------------------------------------------------------------------------------------- the blockers --
DUNE_WIND, DUNE_LEE = 10.0, 6.0         # a dune's windward slope (toward the camp, -Z) and its slip face, at DUNE_TOP


def _windward_yaw(dx, dz):
    """The turn (radians, for dune_piece) that faces a dune's windward slope along area direction (dx, dz)."""
    return math.atan2(-dx, -dz)


def _panel(b, A, B, C, sw, thick=0.4):
    """A flat triangle A, B, C (Builder space) as a panel `thick` deep behind it, its outside the side the corners
    run counter-clockwise round (two WedgeParts in Roblox, thick enough to collide)."""
    A, B, C = Vector(A), Vector(B), Vector(C)
    n = (B - A).cross(C - A)
    if n.length < 1e-6:
        return
    n.normalize()
    u = (B - A).normalized()
    v = n.cross(u)
    R = Matrix((u, v, n)).transposed()
    b.fan(tuple(A - n * (thick / 2)), (0.0, 0.0), [((B - A).dot(u), 0.0), ((C - A).dot(u), (C - A).dot(v))], thick,
          sw, rot=R)


def dune_piece(b, x, z, L, h, yaw=0.0, wind=None, lee=None, hip=0.7, sw=SAND, sw_lee=SAND_DUNE):
    """One length of dune, L long, its crest h high over area (x, z) (#2897): a long windward slope that rounds over
    toward the crest in four facets, the sharp crest, and a straight, shaded slip face down the other side, each end
    sloping away to the sand in a hip hip * h long, so no flat end shows. Its windward slope faces -Z at yaw 0
    (_windward_yaw turns it). Built of WedgeParts, so it collides exactly where it is drawn: a player walks up it, no
    barrier."""
    wind = DUNE_WIND * h / DUNE_TOP if wind is None else wind
    lee = DUNE_LEE * h / DUNE_TOP if lee is None else lee
    prof = [(-wind, 0.0), (-0.72 * wind, 0.2 * h), (-0.45 * wind, 0.52 * h), (-0.19 * wind, 0.85 * h), (0.0, h),
            (lee, 0.0)]
    R = Matrix.Rotation(yaw, 3, "Z") @ Matrix(((0, 0, 1), (1, 0, 0), (0, 1, 0)))   # profile (z, up), run along x
    c = Vector(bl(x, z))
    b.fan(tuple(c), (0.0, 0.0), prof[:5], L, sw, rot=R)
    b.fan(tuple(c), (0.0, 0.0), prof[4:], L, sw_lee, rot=R)
    if hip > 0:
        _hip_ends(b, c, R, prof, L, -0.3 * wind, hip * h, [sw] * (len(prof) - 2) + [sw_lee])


def _hip_ends(b, c, R, prof, L, apex_x, e, swatches):
    """Closes both ends of a profile run L long (profile (x, up) in R's local x, y; the run along its local z, centred
    on c): a facet from each profile edge down to a point on the sand e past the end, under profile x apex_x."""
    for end in (-1, 1):
        apex = c + R @ Vector((apex_x, 0.0, end * (L / 2 + e)))
        out = R @ Vector((0.0, 0.0, end))
        for (p0, p1), sw in zip(zip(prof, prof[1:]), swatches):
            tri = [c + R @ Vector((p0[0], p0[1], end * L / 2)), c + R @ Vector((p1[0], p1[1], end * L / 2)), apex]
            if (tri[1] - tri[0]).cross(tri[2] - tri[0]).dot(out) < 0:      # face away from the run
                tri[0], tri[1] = tri[1], tri[0]
            _panel(b, *tri, sw)


def _dune_ridge(s, mat, z, runs):
    """A dune ridge (runs, x0 to x1) just taller than a jump (Derek2 11-09: not tents or round clumps; #2897: finished,
    and no invisible wall): dunes end to end, each with a long windward slope toward the camp, a sharp crest and a
    shaded slip face, the crest line wandering and the heights rolling from dune to dune, the ends curving away
    downwind and stepping down into the sand like a crescent dune's horns. Every piece collides where it is drawn, so
    a player can climb over a ridge or walk round its end; nothing invisible stands round it."""
    b = Builder()
    for k, (a0, a1) in enumerate(runs):
        L = a1 - a0
        n = max(2, round(L / 13.0))
        step = L / n
        for i in range(n):
            j = i + 3 * k
            c = a0 + (i + 0.5) * step
            h = DUNE_TOP - 0.5 * (j % 3)                         # 7.5 to 8.5
            ln = step + 2.4                                      # into the neighbours
            hip = 0.7
            if abs(c) + ln / 2 + hip * h > IN_X:
                ln = min(ln, 2 * (IN_X + 1.0 - abs(c)))          # into the side dunes, never through the wall
                hip = 0.0
            dune_piece(b, c, z + 1.3 * ((j * 2) % 3 - 1), ln, h, math.radians(7.0 * ((j * 5) % 3 - 1)),
                       wind=DUNE_WIND * (0.9 + 0.12 * (j % 3)), hip=hip)
        for e, sgn in ((a0, -1), (a1, 1)):                       # the horns, curving downwind (+Z)
            if abs(abs(e) - IN_X) < 1:
                continue
            for (t, hh, ln, dz, turn) in ((3.0, 0.62, 6.0, 0.8, 12), (6.5, 0.32, 4.0, 2.0, 22)):
                if near_trail(e + sgn * (t + ln / 2 + 0.7 * DUNE_TOP * hh), z + dz) < TRAIL_W / 2 + 1.0:
                    break
                dune_piece(b, e + sgn * t, z + dz, ln, DUNE_TOP * hh, math.radians(-sgn * turn))
    s.put([b.finalize(N + "DuneRidge", mat)], 0, 0, 0)


def _hump(s, mat, x, z, w=TRAIL_W + 4.0):
    """A low sand hump the trail climbs over (a height change, section 3): 1.6 high, a soft rise over 7 each side
    and a rounded top, its two ends sloping down into the sand. WedgeParts, so it collides where it is drawn."""
    b = Builder()
    H = 1.6
    prof = [(-7.0, 0.0), (-3.6, 1.0), (-1.4, H), (1.4, H), (3.6, 1.0), (7.0, 0.0)]
    R = Matrix(((0, 0, 1), (1, 0, 0), (0, 1, 0)))
    b.fan((0, 0, 0), (0.0, 0.0), prof, w, SAND_DUNE, rot=R)
    _hip_ends(b, Vector((0, 0, 0)), R, prof, w, 0.0, 3.0, [SAND_DUNE] * (len(prof) - 1))
    s.put([b.finalize(N + "Hump", mat)], x, z, 0)


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


# The Red Canyon as a cluster of separate buttes with sand lanes between (Derek 11-09: the middle block was "way too
# big of a block"). (x0, x1, z0, z1, top): the slot's rims by the arch stand tallest, the rest step down outward.
BUTTES = (
    (-30.0, -SLOT_HALF, -108.0, -88.0, 14.0), (-32.0, -SLOT_HALF, -70.0, -50.0, 18.0),
    (-28.0, -SLOT_HALF, -42.0, -22.0, 12.5),
    (-IN_X, -42.0, -108.0, -86.0, 11.5), (-66.0, -44.0, -78.0, -52.0, 15.0), (-IN_X, -48.0, -44.0, -22.0, 11.0),
    (SLOT_HALF, 30.0, -108.0, -90.0, 13.0), (SLOT_HALF, 32.0, -82.0, -56.0, 18.0), (SLOT_HALF, 27.0, -38.0, -22.0, 12.0),
    (39.0, 53.0, -104.0, -82.0, 12.5), (41.0, 53.0, -72.0, -50.0, 14.5), (37.0, 52.0, -40.0, -24.0, 10.5),
)
HOODOOS = ((-36.0, -96.0, 9.0), (-38.0, -46.0, 7.5), (-58.0, -82.0, 8.0), (35.0, -86.0, 8.5), (34.0, -46.0, 9.5),
           (-25.0, -81.0, 6.5), (25.0, -52.0, 6.0), (46.0, -77.0, 7.0))


def _butte(b, x0, x1, z0, z1, H, seed):
    """One butte: a notched base (corners cut back so it reads as rock, not a crate) in striped courses, a narrower
    stepped upper tier, sandstone caps, fluted faces round the base and boulders at its foot."""
    W, D = x1 - x0, z1 - z0
    cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
    base = min(H * 0.6, 9.0)
    x, y, _ = bl(cx, cz)
    # the two crossing boxes of each course differ a hair in height so no two faces share a plane
    for n, (w, d) in enumerate(((W - 4.0, D), (W, D - 4.0))):                    # the notched base
        b.box_base((x, y, 0), (w, d, base - 0.06 * n), RED, bevel=False)
    for j, (zz, sw) in enumerate(((2.6, RED_LIGHT), (5.8, RED_DARK))):
        if zz < base - 1.0:
            for n, (w, d) in enumerate(((W - 4.0, D), (W, D - 4.0))):
                b.box((x, y, zz), (w + 0.5, d + 0.5, 0.8 + 0.15 * j - 0.08 * n), sw, bevel=False)
    for n, (w, d) in enumerate(((W - 3.6, D + 0.4), (W + 0.4, D - 3.6))):
        b.box_base((x, y, base - 0.06 * n), (w, d, 0.5), STONE_LIGHT, bevel=False)
    # the upper tier, inset from the base and split in steps so the top line is broken
    ix0, ix1, iz0, iz1 = x0 + 3.0, x1 - 3.0, z0 + 3.0, z1 - 3.0
    nx, nz = max(1, round((ix1 - ix0) / 9.0)), max(1, round((iz1 - iz0) / 9.0))
    cw, cd = (ix1 - ix0) / nx, (iz1 - iz0) / nz
    for i in range(nx):
        for k in range(nz):
            hh = (i * 7 + k * 5 + seed) % 4
            h = H - 1.4 * hh - (0.0 if (i, k) != (0, 0) else 1.0)
            if h < base + 2.0:
                continue
            px, py, _ = bl(ix0 + (i + 0.5) * cw, iz0 + (k + 0.5) * cd)
            b.box_base((px, py, base), (cw + 0.02 * (i + 1), cd + 0.02 * (k + 1), h - base), (RED, RED_DARK)[hh % 2],
                       bevel=False)
            if base + 3.0 < h - 1.2:
                b.box((px, py, base + 3.0), (cw + 0.5, cd + 0.5, 0.8 + 0.07 * ((i + k) % 3)), RED_LIGHT, bevel=False)
            b.box_base((px, py, h), (cw + 0.7, cd + 0.7, 0.55), (STONE, STONE_LIGHT)[(i + k) % 2], bevel=False)
    # the fluted faces round the base, boulders at the foot
    _rock_faces(b, x0 + 2.0, x1 - 2.0, z0, -1, seed=seed, H=base)
    _rock_faces(b, x0 + 2.0, x1 - 2.0, z1, 1, seed=seed + 1, H=base)
    _rock_faces_x(b, z0 + 2.0, z1 - 2.0, x0, -1, seed=seed + 2, H=base)
    _rock_faces_x(b, z0 + 2.0, z1 - 2.0, x1, 1, seed=seed + 3, H=base)


def hoodoo(mat, h=8.0):
    """A thin rock tower in a lane: stacked, narrowing courses with a wide cap stone balanced on top."""
    b = Builder()
    z = 0.0
    for j, (r, sw) in enumerate(((1.9, RED), (1.6, RED_LIGHT), (1.35, RED), (1.1, RED_DARK))):
        hj = h / 4 + 0.01 * j
        b.box_base((0.15 * (j % 2), -0.1 * (j % 2), z), (2 * r, 2 * r * 0.9, hj), sw, bevel=False, rot=(0.12 * j, "Z"))
        z += hj
    b.box_base((0, 0, z), (3.4, 3.0, 1.1), STONE, bevel=False, rot=(0.3, "Z"))
    b.ico((0.8, -1.4, 0.5), 1.1, RED_LIGHT, subdivisions=1, scale=(1.2, 1.0, 0.7))
    return [b.finalize(N + "Hoodoo", mat)]


def _canyon(s, mat):
    """The Red Canyon: separate buttes either side of the slot canyon (x -9 to 9) with sand lanes between them, the
    tallest pair holding the arch, hoodoos in the lanes, fallen boulders in the slot. The slot's old alcoves are the
    lanes' mouths now, so their spots stay open."""
    b = Builder()
    for i, (x0, x1, z0, z1, H) in enumerate(BUTTES):
        _butte(b, x0, x1, z0, z1, H, i * 3)
    for sx in (-1, 1):                                       # the arch's rims, full height right to the slot
        x, y, _ = bl(sx * (SLOT_HALF + 3.0), ARCH_Z)
        b.box_base((x, y, 0), (6.0, 12.0, CANYON_H - 0.5), RED, bevel=False)
        b.box_base((x, y, CANYON_H - 0.5), (6.6, 12.6, 0.55), STONE, bevel=False)
    s.put([b.finalize(N + "Canyon", mat)], 0, 0, 0)
    for (x, z, h) in HOODOOS:
        s.put(hoodoo(mat, h), x, z, (x * 17) % 360)
    for (x, z, r) in ((-6.0, -92.0, 1.6), (6.5, -64.0, 1.3), (-6.5, -36.0, 1.5), (66.0, -84.0, 1.4),
                      (58.5, -40.0, 1.2), (-38.0, -80.0, 1.3), (35.0, -62.0, 1.5), (-50.0, -48.0, 1.1)):
        s.put(rock(mat, r), x, z, (x * 13) % 360)
    s.put(rock_arch(mat), 0, ARCH_Z, 0)


def rock_arch(mat):
    """A natural sandstone arch from rim to rim of the slot, its underside about 13 over the floor: a thick band of
    rock (3 deep, 2.6 through) in striped courses, its feet widening into the rims."""
    b = Builder()
    w = 2 * SLOT_HALF + 2.0
    n = 14
    for k in range(n):
        t = (k + 0.5) / n
        a = PI * t
        x = -(w / 2) * math.cos(a)
        z = CANYON_H - 4.6 + 2.6 * math.sin(a)
        foot = max(0.0, 1.0 - math.sin(a) * 1.6)                              # thicker toward the rims
        b.box((x, 0, z - 0.6 * foot), (w / n * 1.5 + 0.4, 5.0 + 1.5 * foot - 0.01 * (k % 2), 2.6 + 1.6 * foot),
              (RED_LIGHT, RED, STONE)[k % 3], bevel=False,
              rot=(-math.atan2(2.6 * math.cos(a), w / 2 * math.sin(a)), "Y"))      # along the arc
    return [b.finalize(N + "RockArch", mat)]


def _mesa_ridge(s, mat, z, runs):
    """Short red mesas across the flats (runs, x0 to x1), MESA_TOP high: a cliff block with strata and a cap, rock
    faces round its foot. No barrier (#2897): what is drawn is what stops a player."""
    b = Builder()
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
    s.put([b.finalize(N + "MesaRidge", mat)], 0, 0, 0)


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
    column at each end, sand drifted against it. No barrier (#2897)."""
    b = Builder()
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
    s.put([b.finalize(N + "RuinWall", mat)], 0, 0, 0)


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
    # the drifts (#2897: dunes of WedgeParts, so they collide where they are drawn, not as a box round a ball): sand
    # heaped over the two back corners and the back face, smaller drifts at the front corners' feet
    c = PYR_BASE / 2
    for sx in (-1, 1):                         # crests on the first tier, slip faces against the second
        dune_piece(b, sx * (c - 3.5), c - 3.5, 18.0, 5.0, _windward_yaw(sx, 1), wind=13.0, lee=2.0)
        dune_piece(b, sx * (c - 0.5), -c + 0.5, 9.0, 2.6, _windward_yaw(sx, -1), wind=5.5, lee=1.5)
    dune_piece(b, 0.0, c - 3.0, 22.0, 4.4, _windward_yaw(0, 1), wind=11.0, lee=1.4)
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


CACTUS, CACTUS_DARK, BLOOM = "leaf_green", "leaf_dark", "blush"


def soft_cactus(mat, kind=0):
    """A soft decor cactus (Derek2 11-09: yes to cacti as scenery; the design doc bars cactus traps): chunky rounded
    shapes with no spines at all, a pink bloom on top, standing in a little sand drift. kind 0 a paddle cactus (flat
    round pads stacked), 1 a barrel (a squat ribbed ball), 2 an arm cactus (a trunk with two raised arms), each about
    player height or a little more."""
    b = Builder()
    b.sphere((0, 0, 0), 1.0, SAND_DUNE, segments=12, rings=6, scale=(1.9, 1.7, 0.45))           # the sand drift
    if kind == 0:
        for (x, z, w, h, a, sw) in ((0.0, 1.3, 1.25, 1.5, 0, CACTUS), (-0.75, 3.4, 0.95, 1.15, -28, CACTUS_DARK),
                                    (0.85, 3.6, 0.95, 1.15, 25, CACTUS), (-0.2, 5.0, 0.7, 0.85, 8, CACTUS)):
            b.sphere((x, 0, z), 1.0, sw, segments=14, rings=8, scale=(w, 0.38, h), rot=(math.radians(a), "Y"))
        for (x, z) in ((-1.1, 4.45), (1.35, 4.65), (-0.25, 5.85)):
            b.sphere((x, 0, z), 0.26, BLOOM, segments=8, rings=4)
    elif kind == 1:
        b.sphere((0, 0, 1.25), 1.0, CACTUS, segments=16, rings=8, scale=(1.45, 1.45, 1.3))
        for k in range(8):                                                                       # soft ribs
            a = 2 * PI * k / 8
            b.sphere((1.2 * math.cos(a), 1.2 * math.sin(a), 1.25), 1.0, CACTUS_DARK, segments=8, rings=6,
                     scale=(0.22, 0.22, 1.05), rot=(a, "Z"))
        for k in range(3):
            a = 2 * PI * k / 3 + 0.4
            b.sphere((0.3 * math.cos(a), 0.3 * math.sin(a), 2.55), 0.3, BLOOM, segments=8, rings=4)
        b.sphere((0, 0, 2.62), 0.2, "pastel_butter", segments=8, rings=4)
    else:
        b.cyl_base((0, 0, 0), 0.75, 6.2, CACTUS, segments=12, bevel=False)                      # the trunk
        b.sphere((0, 0, 6.2), 0.75, CACTUS, segments=12, rings=6)
        for (sx, z0, up) in ((-1, 2.4, 2.0), (1, 3.3, 1.6)):                                   # the arms
            b.cyl((sx * 0.95, 0, z0), 0.5, 1.5, CACTUS, segments=10, bevel=False, rot=(PI / 2, "Y"))
            b.sphere((sx * 1.7, 0, z0), 0.5, CACTUS, segments=10, rings=6)
            b.cyl_base((sx * 1.7, 0, z0), 0.5, up, CACTUS, segments=10, bevel=False)
            b.sphere((sx * 1.7, 0, z0 + up), 0.5, CACTUS, segments=10, rings=6)
        for k in range(4):                                                                       # soft ribs
            a = 2 * PI * k / 4 + PI / 4
            b.box_base((0.7 * math.cos(a), 0.7 * math.sin(a), 0.3), (0.16, 0.16, 5.6), CACTUS_DARK, bevel=False,
                       rot=(a, "Z"))
        b.sphere((0.15, 0, 6.95), 0.3, BLOOM, segments=8, rings=4)
    return [b.finalize(N + "Cactus", mat)]


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
    two colours, a crate and pots tumbled out. Every piece touches the rest (#2990): the hoop pieces run along the
    arc (they leaned the wrong way and stood apart), the hoops stand in the side boards and follow the bed's tilt,
    the cover lies on them, both wheels sit against their board and the shaft runs from the bed down to the sand."""
    b = Builder()
    tilt = 0.12
    b.box((0, 0, 1.4), (7.0, 3.4, 0.5), "caramel_wood", rot=(tilt, "Y"))
    for sy in (-1, 1):
        b.box((0, sy * 1.6, 2.0), (7.0, 0.25, 1.0), "dark_wood", bevel=False, rot=(tilt, "Y"))
    b.cyl((2.4, -1.87, 1.3), 1.3, 0.3, "dark_wood", segments=12, rot=(PI / 2, "X"))
    b.cyl((2.4, -1.87, 1.3), 0.35, 0.4, "brass", segments=8, rot=(PI / 2, "X"), bevel=False)
    b.cyl((-2.6, 2.0, 1.4), 1.3, 0.3, "dark_wood", segments=12, rot=Matrix.Rotation(PI / 2, 3, "X") @
          Matrix.Rotation(0.5, 3, "Y"))                                      # the loose wheel, leaning

    def hoop_z(x):                                                            # a hoop's centre: its ends in the boards
        return 2.0 + 0.5 * math.cos(tilt) - x * math.sin(tilt) - 0.1

    for k in range(3):                                                        # the hoops, the cover over two
        x = -2.4 + 2.4 * k
        for j in range(5):
            a = PI * (j + 0.5) / 5
            b.box((x, -1.6 * math.cos(a), hoop_z(x) + 1.6 * math.sin(a)), (0.15, 1.25, 0.15), "fur_brown",
                  bevel=False, rot=(PI / 2 - a, "X"))
    for j in range(5):                                                        # lying on the first two hoops
        a = PI * (j + 0.5) / 5
        b.box((-1.2, -1.71 * math.cos(a), hoop_z(-1.2) + 1.71 * math.sin(a)), (2.6, 1.2, 0.1),
              ("cream", STRIPES[3])[j % 2], bevel=False,
              rot=Matrix.Rotation(tilt, 3, "Y") @ Matrix.Rotation(PI / 2 - a, 3, "X"))
    x0, z0, x1, z1 = -5.6, 0.12, -3.1, 1.55                                   # the shaft, bed to sand
    b.box(((x0 + x1) / 2, 0, (z0 + z1) / 2), (math.hypot(x1 - x0, z1 - z0), 0.3, 0.3), "dark_wood", bevel=False,
          rot=(-math.atan2(z1 - z0, x1 - x0), "Y"))
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


# ------------------------------------------------------------------------------------ the trail kit (#2834) --
# Dressing along the way so the long walk reads as an old caravan road: little market stalls by the camp gate and on
# the flats, standing urn groups and crate stacks at the trail's side, and rope posts lining it in the open stretches.
ROPE = "fur_sand"


def market_stall(mat, stripe=STRIPES[1]):
    """A trader's stall, 4.6 wide: a wooden counter with goods on it (pots, folded cloth, a bowl of dates), four posts,
    a striped awning sloping down to the front and scalloped there, a rug over one side, baskets at its foot. Front
    -Z (Blender -Y): stand it facing the trail. Footprint x +-2.5, z -2.5 to 1.8."""
    b = Builder()
    b.box_base((0, -0.6, 0), (4.4, 1.4, 1.1), "caramel_wood")                                     # the counter
    b.box_base((0, -0.6, 1.1), (4.7, 1.7, 0.12), "dark_wood", bevel=False)
    b.box_base((0, -1.32, 0.35), (4.2, 0.06, 0.65), stripe, bevel=False)                          # its front cloth
    for k in range(5):
        b.box_base((-1.68 + 0.84 * k, -1.36, 0.35), (0.3, 0.04, 0.65), "cream", bevel=False)
    for sx in (-1, 1):                                                                            # the posts
        b.cyl_base((sx * 2.25, -1.4, 0), 0.12, 3.05, "dark_wood", segments=8, bevel=False)
        b.cyl_base((sx * 2.25, 1.45, 0), 0.12, 3.65, "dark_wood", segments=8, bevel=False)
    a = math.atan2(0.6, 2.85)                                                                     # the awning
    n = 6
    for i in range(n):
        x = -2.45 + (i + 0.5) * 4.9 / n
        sw = (stripe, "cream")[i % 2]
        b.box((x, 0.02, 3.35), (4.9 / n + 0.02, 3.5, 0.1 + 0.02 * (i % 2)), sw, bevel=False, rot=(a, "X"))
        b.box((x, -1.69, 2.85), (4.9 / n - 0.12, 0.06, 0.42), sw, bevel=False)                   # the scallops
    b.box_base((0, 1.25, 1.55), (4.2, 0.5, 0.1), "dark_wood", bevel=False)                        # the back shelf
    for k, sw in enumerate((RED_LIGHT, "sign_teal", RED_LIGHT, "fur_caramel", "sign_teal")):
        x = -1.7 + 0.85 * k
        b.cyl_base((x, 1.25, 1.65), 0.2, 0.45, sw, segments=8, radius2=0.14)
    for (x, sw) in ((-1.5, RED_LIGHT), (-0.9, "fur_caramel")):                                    # pots on the counter
        b.cyl_base((x, -0.55, 1.22), 0.26, 0.5, sw, segments=10, radius2=0.18)
        b.cyl_base((x, -0.55, 1.72), 0.2, 0.08, RED, segments=10, bevel=False)
    for k, sw in enumerate((STRIPES[2], STRIPES[3], "cream")):                                    # folded cloth
        b.box_base((0.3, -0.5, 1.22 + 0.16 * k), (1.0, 0.8, 0.16), sw, bevel=False)
    b.cyl_base((1.5, -0.6, 1.22), 0.5, 0.22, "fur_hazel", segments=12, radius2=0.35)              # a bowl of dates
    for k in range(5):
        t = 2 * PI * k / 5
        b.ico((1.5 + 0.22 * math.cos(t), -0.6 + 0.22 * math.sin(t), 1.47), 0.13, "fur_toffee", subdivisions=1)
    b.box_base((-2.4, 0.1, 0.9), (0.06, 2.2, 2.1), STRIPES[4], bevel=False)                       # a rug over the side
    b.box_base((-2.42, 0.1, 1.5), (0.06, 2.2, 0.25), "cream", bevel=False)
    for (x, sw) in ((-1.4, "fur_toffee"), (1.3, RED_LIGHT)):                                      # baskets at its foot
        b.cyl_base((x, -2.0, 0), 0.45, 0.55, "fur_hazel", segments=10, radius2=0.52)
        for k in range(3):
            t = 2 * PI * k / 3
            b.ico((x + 0.2 * math.cos(t), -2.0 + 0.2 * math.sin(t), 0.6), 0.17, sw, subdivisions=1)
    return [b.finalize(N + "Stall", mat)]


def _urn(b, x, y, s, sw, band="cream"):
    """A standing amphora: a foot, a round belly with a painted band, a neck and a lip."""
    b.cyl_base((x, y, 0), 0.32 * s, 0.18 * s, sw, segments=10, bevel=False, radius2=0.4 * s)
    b.sphere((x, y, 0.95 * s), 0.72 * s, sw, segments=12, rings=7, scale=(1.0, 1.0, 1.15))
    b.cyl_base((x, y, 1.0 * s), 0.74 * s, 0.14 * s, band, segments=12, bevel=False)
    b.cyl_base((x, y, 1.6 * s), 0.27 * s, 0.45 * s, sw, segments=10, bevel=False, radius2=0.22 * s)
    b.cyl_base((x, y, 2.02 * s), 0.38 * s, 0.12 * s, RED, segments=10, bevel=False)


def urn_group(mat):
    """Three standing urns of three sizes and a fourth tipped over in the sand, the way a trader left them."""
    b = Builder()
    b.sphere((0.1, 0.1, 0), 1.0, SAND_DUNE, segments=12, rings=6, scale=(2.1, 1.8, 0.3))           # the sand drift
    _urn(b, 0.0, 0.3, 1.0, RED_LIGHT)
    _urn(b, 1.15, 0.85, 0.72, "fur_caramel", band="sign_teal")
    _urn(b, -1.0, -0.55, 0.58, RED_LIGHT, band="sign_teal")
    lie = Matrix.Rotation(PI / 2, 3, "Y")                                                          # the tipped one
    b.sphere((0.9, -1.0, 0.5), 0.5, "fur_caramel", segments=12, rings=7, scale=(1.15, 1.0, 1.0), rot=lie)
    b.cyl((1.62, -1.0, 0.5), 0.2, 0.42, "fur_caramel", segments=10, bevel=False, rot=lie)
    b.cyl((1.86, -1.0, 0.5), 0.28, 0.09, RED, segments=10, bevel=False, rot=lie)
    return [b.finalize(N + "UrnGroup", mat)]


def _crate_at(b, x, y, z, s, yaw):
    R = Matrix.Rotation(yaw, 3, "Z")
    b.box((x, y, z + s / 2), (s, s, s), "caramel_wood", rot=R)
    for dz in (-0.3, 0.3):                                                                         # slats on two faces
        for f in (Vector((0, -1, 0)), Vector((1, 0, 0))):
            c = Vector((x, y, z + s / 2 + dz * s)) + R @ (f * (s / 2 + 0.02))
            size = (s, 0.06, 0.14 * s) if f.x == 0 else (0.06, s, 0.14 * s)
            b.box(tuple(c), size, "dark_wood", bevel=False, rot=R)


def crate_stack(mat):
    """Two crates side by side, a third on top and turned, a grain sack leaning on them, a rope round the top one."""
    b = Builder()
    b.sphere((0, 0, 0), 1.0, SAND_DUNE, segments=12, rings=6, scale=(2.3, 1.7, 0.3))
    _crate_at(b, -0.85, 0.0, 0.0, 1.6, 0.05)
    _crate_at(b, 0.85, 0.15, 0.0, 1.5, -0.08)
    _crate_at(b, -0.2, 0.05, 1.5, 1.3, 0.35)
    b.box((-0.2, 0.05, 2.18), (1.36, 0.1, 0.08), ROPE, bevel=False, rot=(0.35, "Z"))
    b.sphere((1.75, -1.0, 0.55), 0.6, "cardboard", segments=10, rings=6, scale=(0.9, 0.8, 1.05),
             rot=(-0.3, "Y"))                                                                      # the sack
    b.cyl((1.9, -1.0, 1.15), 0.18, 0.3, ROPE, segments=8, bevel=False)
    return [b.finalize(N + "CrateStack", mat)]


def rope_posts(mat, n=3, gap=4.0):
    """A run of n short wooden posts gap apart along local X with a rope sagging between them, lining the trail. The
    posts collide (thin, a player walks round them); the rope (_Decor) doesn't."""
    b, d = Builder(), Builder()
    xs = [(i - (n - 1) / 2) * gap for i in range(n)]
    for x in xs:
        b.sphere((x, 0, 0), 0.5, SAND_DUNE, segments=8, rings=4, scale=(1.0, 1.0, 0.35))
        b.cyl_base((x, 0, 0), 0.17, 2.0, "dark_wood", segments=8, bevel=False)
        b.cyl_base((x, 0, 2.0), 0.22, 0.12, "fur_hazel", segments=8, bevel=False)
        b.box_base((x, 0, 1.62), (0.4, 0.4, 0.12), ROPE, bevel=False)
    for x0, x1 in pairwise(xs):                                                                # the rope, sagging
        pts = [(x0 + (x1 - x0) * t, 1.68 - 0.45 * math.sin(PI * t)) for t in (0.0, 0.25, 0.5, 0.75, 1.0)]
        for (ax, az), (bx, bz) in pairwise(pts):
            L = math.hypot(bx - ax, bz - az)
            d.box(((ax + bx) / 2, 0, (az + bz) / 2), (L + 0.08, 0.1, 0.1), ROPE, bevel=False,
                  rot=(-math.atan2(bz - az, bx - ax), "Y"))
    return [b.finalize(N + "RopePosts", mat), d.finalize(N + "RopePosts_Decor", mat)]


def _on_trail(i, t, side, off):
    """Area point beside TRAIL segment i at fraction t, side +1 left / -1 right of the way on, off from its middle
    line, and the segment's own heading (rot_y of a piece whose local X runs along it)."""
    (ax, az), (bx, bz) = TRAIL[i], TRAIL[i + 1]
    dx, dz = bx - ax, bz - az
    L = math.hypot(dx, dz)
    nx, nz = -dz / L, dx / L
    return ax + dx * t + side * off * nx, az + dz * t + side * off * nz, math.degrees(math.atan2(-dz, dx))


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
        b.box((x, -1.9, 0.43), (w / n - 0.1, 0.1, 0.9), STRIPES[i], bevel=False, rot=(0.25, "X"))  # the hem, on the sand
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

    # the rest of the rescue pool (as the Park's #2240): scenery until the day's pick puts a stuck cat in one. Ten
    # more, the kinds mixed, off the trail and the blockers, 8 from every cat spot, 25 from every other trap, none
    # within 100 of the camp, six of the ten in the far half
    for (x, z, t) in POOL_DUNES:
        put(trap_sand_dune(mat), x, z, t, r=4)
        _spot(s, "trap_sand_dune", x, z, turn=t)
    for (x, z, t) in POOL_URNS:
        put(trap_clay_urn(mat), x, z, t, r=4)
        _spot(s, "trap_clay_urn", x, z, turn=t)
    for (x, z, t) in POOL_CANOPIES:
        put(trap_collapsed_canopy(mat), x, z, t, r=5)
        _spot(s, "trap_collapsed_canopy", x, z, turn=t)

    # the trail kit (#2834): market stalls where the caravans stopped (the camp gate, the flats), and along the way
    # rope posts, urn groups and crate stacks at the trail's side, each clear of the cat spots, the pieces and the
    # blockers, so no cat spot moves
    spots = [(p[0], p[2]) for lst in s.points.values() for p in lst]

    def free(x, z, r):
        if any(math.hypot(x - qx, z - qz) < r + 3.0 for (qx, qz) in spots):
            return False
        if any(math.hypot(x - qx, z - qz) < r + qr + 1.0 for (qx, qz, qr) in keep):
            return False
        if (abs(z - DUNE_A_Z) < 10 or abs(z - DUNE_B_Z) < 10 or abs(z - MESA_Z) < 9 or abs(z - RUIN_Z) < 6
                or CANYON_Z0 - 4 < z < CANYON_Z1 + 4 or z < -IN_Z + 4):
            return False
        if abs(x) > IN_X - 4 or (FLATS_Z0 < z < FLATS_Z1 and abs(x) > PAN_X - 3):
            return False
        return math.hypot(x - PYRAMID[0], z - PYRAMID[1]) > PYR_BASE / 2 + 6
    for (x, z, tx, sw) in ((-12.5, -266.0, 0.0, STRIPES[1]), (12.5, -261.0, 0.0, STRIPES[2]),
                           (-9.5, 6.0, 4.8, STRIPES[3]), (17.5, 32.0, 6.0, STRIPES[1])):
        if free(x, z, 3.2):
            put(market_stall(mat, sw), x, z, face(x, z, tx, z), r=3.2)
    edge = TRAIL_W / 2 + 0.7
    seg = [math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in pairwise(TRAIL)]
    k, d = 0, 8.0
    while d < sum(seg) - 8.0:                                       # a piece every 13 studs of the way, if it fits
        i, rest = 0, d
        while rest > seg[i]:
            rest -= seg[i]
            i += 1
        L, t = seg[i], rest / seg[i]
        (ax, az), (bx, bz) = TRAIL[i], TRAIL[i + 1]
        kind = ("rope", "urns", "rope", "crates")[k % 4]
        for side in ((-1, 1) if k % 2 else (1, -1)):                 # the other side when the first is taken
            if kind == "rope":
                if t - 4.5 / L < 0.0 or t + 4.5 / L > 1.0:             # keep a run off the bends
                    break
                x, z, heading = _on_trail(i, t, side, edge + 0.5)
                posts = [(x + u * (bx - ax) / L, z + u * (bz - az) / L) for u in (-4.0, 0.0, 4.0)]
                if all(free(px, pz, 0.6) and near_trail(px, pz) > edge for px, pz in posts):
                    s.put(rope_posts(mat), x, z, heading)
                    keep.extend((px, pz, 0.6) for px, pz in posts)
                    break
            else:
                r = 2.4
                x, z, _ = _on_trail(i, t, side, edge + r + 0.6)
                if free(x, z, r) and near_trail(x, z) > edge + r:
                    put((urn_group if kind == "urns" else crate_stack)(mat), x, z, (k * 47) % 360, r=r)
                    break
        k += 1
        d += 13.0

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
            elif k % 6 == 1:
                s.put(shrub(mat), x, z, (k * 53) % 360)
            elif k % 6 == 4:                                         # soft cacti, scenery only, away from spots
                s.put(soft_cactus(mat, (k // 6) % 3), x, z, (k * 41) % 360)
    return s.finish(_ground(), mat), s


def build_desert_set(mat):
    objs, _ = build_set(mat)
    return objs


ASSETS = {
    NAME: (build_desert_set, 150000),
}
