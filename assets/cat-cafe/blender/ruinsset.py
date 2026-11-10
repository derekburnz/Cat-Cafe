"""The Ruins (Tier 7, Wonder Cafe; tier6-7-areas.md sections 3 and 5): a long rectangle, 140 x 600 for the wild part,
with the camp (CatCafe_Camp_Ruins, camps.py) 30 more across its -Z end, outside it, as on every F85 area.

  CatCafe_Ruins_Set   the wild part dressed, in area space (areakit): place it at the area's centre on its floor,
                      camp side -Z, like every set (WorldBuilder turns it 0, its camp on the south edge). Walls at
                      x +-70 and z +-300 (RuinsWidth 140, RuinsDepth 600); the way in is the 24 stud opening at x 0
                      on z -300.

No grass (section 3): the floor is packed earth, the ways cut stone flags; vine green only in small trims. The long
sides are the plateau's edge: broken stone walls 9 to 10 high, the mist beyond them (the backdrop's), and at the far
end a tall ruined wall with a giant cat's head carved in it. Every blocker stands taller than a jump with a
`_Barrier` over it; a 30 high one stands in the wall band all round but the way in. Nothing is built below the floor,
so the mist catch zone (floorY -15 to -45) stays clear. The zones, camp first (Broken Gate Camp is the camp set's):

  z -296 to -150   Statue Avenue: a paved road 52 wide between rows of gargoyle cat statues on plinths, split into
                   three lanes by low walls 2.4 high with gaps; at z -160 the Triumphal Arch, two pylons 13 high
                   (islands x -48 to -14 and 14 to 48) and an arch over the road between, open by the walls
  z -150 to 20     the Fallen Colonnade: a stylobate 3.6 high in the west half (x -66.5 to -8, z -122 to -18) with
                   ramps up and rows of standing columns carrying beams overhead; toppled columns in drums on the
                   low east side, a fallen pediment 9.6 high as an island (x 14 to 50, z -64); the broken bridge
                   ledge in a bay of the east wall (z -110 to -90)
  z 40 to 170      the Glyph Halls: a small maze of carved walls 12 high, four long walls (x -40, -14, 14, 40) making
                   five halls, each wall with a doorway, glowing glyph strips (_Glow) along every wall; three ways in
                   (halls 1, 3 and 5) and three ways out (halls 2, 3 and 4), hall 3 baffled at z 105
  z 180 to 296     the Golem Courtyard: a sunken round court (three stone rings stepping down to the floor, r 30 to
                   42, open at the south, east and west), a dry fountain in the middle and the great stone throne
                   at the back, before the cat-head wall

Landmarks (#2834): the cat colossus, a carved cat's head sunk to the chin in fallen blocks against the far wall
behind the throne, its ears about 39 up so it shows over the halls from the Triumphal Arch, its eyes glowing teal;
a waterfall off the colonnade, from a broken aqueduct over the east wall into a pool at (55, 6); rune stones with
teal runes along the way through the colonnade; and a trilithon gate over the way before the court (z 186).

Points (manifest points_roblox): [x, y, z, zone], zone "near" (z < 0) or "deep". The rescue spots are built in, each
with its piece's turn as a fifth number:
  trap_rubble_pile      broken blocks heaped round the spot, the cat between them (the spot on the floor)
  trap_stone_urn        a tall stone urn standing upright, the cat inside it, its head out of the mouth (2.9 up)
  trap_bridge_ledge     the cat on the far stub of the broken bridge in the east wall's bay, the gap 5 across: the spot
                        is the cat's, on the stub (0.6 in past the gap); the near edge is a broken parapet 2.4 high
                        with a `_Barrier` over it to 9, so the prompt reaches across (about 6.2 from the parapet's
                        inner face) and nobody steps into the gap
Today's five are two rubble piles, two urns and the ledge; the rescue pool (#2240's shape) adds five more of each of
the first two, 15 in all.
"""

import math
from itertools import pairwise

from mathutils import Matrix, Vector

from areakit import PI, Set, ring_blocks, turned
from common import Builder
from woodsset import _dist_seg, _path, bl, face

NAME = "CatCafe_Ruins_Set"
N = "CatCafe_Ruins_"
HALF_X, HALF_Z = 70.0, 300.0            # WorldBuilder's walls at +-70, +-300 (RuinsWidth 140, RuinsDepth 600)
WALL_D = 3.0
IN_X, IN_Z = HALF_X - 0.5 - WALL_D, HALF_Z - 0.5 - WALL_D       # 66.5, 296.5
GATE_HALF = 12.0                        # CampOpeningWidth 24
BARRIER_H = 30.0
BLOCK_OVER = 1.0
TRAIL_W = 8.0

# the palette (section 5): old stone, sandstone, jade, glyph gold; vine green only in trims
STONE, STONE_DARK, STONE_LIGHT = "fur_dusty", "fur_soot", "fur_pewter"
SANDSTONE, SANDSTONE_LIGHT = "fur_dune", "paving_tan"
EARTH, FLAG, FLAG_DARK = "paving_grout", "fur_pewter", "concrete"
JADE, GOLD, VINE = "fur_emerald", "fur_golden", "leaf_dark"
# #2834 moss pass: grey-green moss in cushions on the stone's tops and ledges and in the flags' gaps, still trims
# (section 3: no grass). Moss is `_Decor` (no collision), so no cat spot or blocker changes
MOSS, MOSS_LIGHT, MOSS_DARK = "fur_moss", "fur_fern", "leaf_dark"

AVENUE_HALF = 26.0
LANE_X = 9.0                            # the lane walls at x +-9
STATUE_X = 31.0
ARCH_Z, ISLE_ARCH = -160.0, [(-48.0, -14.0), (14.0, 48.0)]
ARCH_H = 13.0
STYLO = (-IN_X, -8.0, -122.0, -18.0)     # the stylobate (x0, x1, z0, z1), STYLO_H high
STYLO_H = 3.6
PEDIMENT_Z, ISLE_PED = -64.0, [(14.0, 50.0)]
PED_H = 9.6
BAY_Z0, BAY_Z1 = -110.0, -90.0          # the bridge ledge's bay in the east wall
PARAPET_X, GAP = 57.0, 5.0              # the parapet's inner face, and the gap past it
HALLS_Z0, HALLS_Z1 = 40.0, 170.0
HALL_WALLS = (-40.0, -14.0, 14.0, 40.0)
HALL_DOORS = {-40.0: 100.0, -14.0: 70.0, 14.0: 140.0, 40.0: 100.0}   # each long wall's doorway (z of its middle)
HALL_IN = (-53.25, 0.0, 53.25)          # ways in through the z 40 wall
HALL_OUT = (-27.0, 0.0, 27.0)           # ways out through the z 170 wall
DOOR_W = 10.0
HALL_H, HALL_T = 12.0, 2.4
COURT = (0.0, 236.0)
RINGS = ((30.0, 1.2), (34.0, 2.4), (38.0, 3.6))   # (inner radius, top): each 4 wide
RING_GAPS = (-90.0, 0.0, 180.0)         # the court's ways in (degrees: -90 south toward the camp, 0 east, 180 west)
THRONE_Z = 264.0
# #2834 landmarks: the cat colossus at the far end behind the throne, the waterfall off the colonnade by the east wall,
# rune stones along the way and a trilithon gate before the court
COLOSSUS_Z = 284.0
FALLS_X, FALLS_Z = 55.0, 6.0            # the pool's centre; the aqueduct comes in over the east wall behind it
GATE_Z = 186.0
RUNE = "sign_teal"                      # the rune glow (Neon all day, as every _Glow)
WATER, FALL_WATER, FOAM = "sign_teal", "fish_belly", "offwhite"

TRAIL = [(0, -IN_Z), (0, -170), (0, -150), (12, -132), (12, -100), (6, -60), (-2, -10), (0, 20), (0, 40), (0, 100),
         (10, 105), (10, 112), (0, 120), (0, 170), (0, 194)]
# today's five rescue spots and the pool (x, z, turn)
RUBBLE = ((-54.0, -140.0, 0), (30.0, 196.0, 30))
URNS = ((-56.0, 30.0, 0), (54.0, 282.0, 0))
POOL_RUBBLE = ((52.0, -180.0, 60), (40.0, -20.0, -30), (-30.0, 182.0, 10), (56.0, 210.0, 80), (-54.0, 276.0, -40))
POOL_URNS = ((-48.0, 0.0, 0), (54.0, 30.0, 0), (-60.0, 120.0, 0), (60.0, 150.0, 0), (-30.0, 290.0, 0))


def _spot(s, label, x, z, y=0.0, turn=None):
    p = [round(x, 2), round(y, 2), round(z, 2), "deep" if z > 0 else "near"]
    if turn is not None:
        p.append(turn)
    s.points.setdefault(label, []).append(p)


def near_trail(x, z):
    return min(_dist_seg((x, z), a, b) for a, b in pairwise(TRAIL))


# ------------------------------------------------------------------------------------------------- ground --
def _flags(g, x0, x1, z0, z1, size, seed=0, gaps=7):
    """Cut stone flags over a rect (area x0..x1, z0..z1), a few missing, two greys every other one."""
    nx, nz = max(1, round((x1 - x0) / size)), max(1, round((z1 - z0) / size))
    sx, sz = (x1 - x0) / nx, (z1 - z0) / nz
    for i in range(nx):
        for j in range(nz):
            x, y, _ = bl(x0 + (i + 0.5) * sx, z0 + (j + 0.5) * sz)
            if (i * 3 + j * 5 + seed) % gaps == 0:
                g.cyl_base((x, y, 0), min(sx, sz) * 0.42, 0.06, MOSS, segments=10, bevel=False)    # moss in its place
                continue
            h = (i * 7 + j * 13 + seed) % 10                                     # #2834: worn tones, no checkerboard
            sw = STONE if h < 4 else FLAG if h < 8 else (MOSS, "fur_smoke_light")[h - 8]
            g.box_base((x, y, 0), (sx - 0.25, sz - 0.25, 0.08 + 0.02 * ((i + j) % 2)), sw, bevel=False)


def _moss(d, x, y, z, w, dd, k=0):
    """A flat cushion of moss about w x dd sitting on a top face at height z (Builder space): grey-green with a lighter
    tuft on it, now and then a darker one."""
    d.sphere((x, y, z), 0.5, MOSS, segments=6, rings=3, scale=(w, dd, 0.36))
    d.sphere((x + 0.22 * w * (1 - 2 * (k % 2)), y - 0.15 * dd, z + 0.06), 0.5, (MOSS_LIGHT, MOSS_DARK)[k % 3 == 2],
             segments=6, rings=3, scale=(0.45 * w, 0.5 * dd, 0.3))


def _ground():
    """Packed earth over the whole floor, the avenue's flags, a flagged way through the colonnade and the halls, the
    court's floor."""
    g = Builder()
    g.box_base((0, 0, 0), (2 * HALF_X, 2 * HALF_Z, 0.03), EARTH, bevel=False)
    _flags(g, -AVENUE_HALF, AVENUE_HALF, -IN_Z, -150.0, 6.5, gaps=9)
    _path(g, TRAIL[2:], TRAIL_W, SANDSTONE_LIGHT, 0.07)
    cx, cz = COURT
    g.cyl_base(bl(cx, cz), RINGS[0][0] + 0.2, 0.09, SANDSTONE_LIGHT, segments=32, bevel=False)
    g.cyl_base(bl(cx, cz), 12.0, 0.12, FLAG, segments=24, bevel=False)
    for k in range(40):                                                         # rubble scatter on the earth
        x = -62 + (k * 37) % 124
        z = -280 + (k * 97) % 560
        if near_trail(x, z) < 6 or abs(x) < AVENUE_HALF + 2 and z < -150:
            continue
        xx, yy, _ = bl(x, z)
        g.box_base((xx, yy, 0), (0.9, 0.7, 0.14), (STONE, STONE_DARK, SANDSTONE)[k % 3], bevel=False,
                   rot=(k * 0.7, "Z"))
    return g


# -------------------------------------------------------------------------------------------------- walls --
def _seg_broken(b, L, k, d=None):
    """The plateau's edge: a broken stone wall 9.6 high, coursed, its top broken in steps, vines trailing over it in
    one or two places and rubble at its foot."""
    H = 9.6 + 0.4 * (k % 2)
    b.box_base((0, 1.3, 0), (L, 2.2, H - 2.2), STONE, bevel=False)
    n = max(2, round(L / 3.0))
    for i in range(n):
        x = -L / 2 + (i + 0.5) * L / n
        h = 2.2 - 1.3 * (((i * 5 + k) % 4) == 1) + 0.04 * (i % 2)
        b.box_base((x, 1.3, H - 2.2), (L / n - 0.1, 2.2, h), (STONE, STONE_LIGHT)[i % 2], bevel=False)
        if d is not None and (i + k) % 3 != 1:                                   # moss on the broken top
            _moss(d, x, 0.75, H - 2.2 + h, L / n * 0.75, 1.9, i)            # a lip over the front edge
        if d is not None and (i + k) % 2 == 0:                                   # and at the foot
            _moss(d, x + 0.4, 0.15, 0.0, L / n * 0.6, 0.9, i + 1)
    for z in (1.8, 3.8, 5.8):
        b.box((0, 0.17, z), (L, 0.06, 0.12), STONE_DARK, bevel=False)
    for i in range(max(1, round(L / 14.0))):
        x = -L / 2 + (i + 0.5) * L / max(1, round(L / 14.0)) + 2.0
        b.box((x, 0.1, H - 3.0), (1.2, 0.12, 4.2), VINE, bevel=False)            # a trailing vine
        b.box((x + 0.5, 0.08, H - 4.6), (0.9, 0.12, 1.6), VINE, bevel=False)
        b.box_base((x - 3.0, -0.4, 0), (1.4, 1.1, 0.9), STONE_DARK, bevel=False, rot=(0.3, "Z"))


def _seg_colonnade(b, L, k, d=None):
    """A run of the plateau's old portico: a low wall 4.2 high with columns 11 high along it and a broken beam."""
    b.box_base((0, 1.3, 0), (L, 2.2, 4.2), SANDSTONE, bevel=False)
    b.box_base((0, 1.3, 4.2), (L + 0.2, 2.5, 0.4), SANDSTONE_LIGHT, bevel=False)
    n = max(2, round(L / 5.0))
    for i in range(n + 1):
        x = -L / 2 + 0.9 + i * (L - 1.8) / n
        h = 11.0 if (i + k) % 3 else 7.4                                         # one in three broken
        b.cyl_base((x, 1.2, 0), 0.85, h, STONE_LIGHT, segments=10)
        b.box_base((x, 1.2, h), (2.0, 2.0, 0.5), STONE, bevel=False)
        if d is not None and (i + k) % 2 == 0:
            _moss(d, x, 1.2, h + 0.5, 1.6, 1.6, i)                               # on the capital
            _moss(d, x + 1.6, 1.3, 4.6, 1.8, 1.9, i + 1)                         # and along the coping
    b.box_base((-L / 4, 1.2, 11.5), (L / 2, 1.8, 1.0), STONE, bevel=False)       # what is left of the beam


SEGMENTS = {"broken": _seg_broken, "colonnade": _seg_colonnade}


def wall_segment(mat, kind, L, k=0):
    b, d = Builder(), Builder()
    SEGMENTS[kind](b, L, k, d)
    return [b.finalize(N + "Wall" + kind.capitalize(), mat), d.finalize(N + "Wall" + kind.capitalize() + "_Decor", mat)]


def pier(mat, h=12.0, k=0):
    """A square stone pier in the wall line between two runs, capped, a jade band near its top. #2834: a carved panel
    with a cat's paw in relief on its inner face, a rune below the band that glows teal (_Glow), moss on the cap and
    the foot. k picks the rune."""
    b, glow, d = Builder(), Builder(), Builder()
    y = WALL_D / 2
    b.box_base((0, y, 0), (3.2, 3.2, 0.8), STONE_DARK, bevel=False)
    b.box_base((0, y, 0.8), (2.6, 2.6, h - 0.8), STONE, bevel=False)
    b.box_base((0, y, h - 2.0), (2.75, 2.75, 0.5), JADE, bevel=False)
    b.box_base((0, y, h), (3.2, 3.2, 0.6), STONE_LIGHT, bevel=False)
    f = y - 1.3                                                                  # the inner face
    b.box_base((0, f - 0.04, 1.6), (2.0, 0.12, 3.0), STONE_DARK, bevel=False)    # the panel
    b.box((0, f - 0.14, 2.7), (1.1, 0.12, 0.9), SANDSTONE_LIGHT, bevel=False)     # the paw: its pad
    for du, dh in ((-0.62, 3.45), (-0.21, 3.8), (0.21, 3.8), (0.62, 3.45)):       # and toes
        b.box((du, f - 0.14, dh), (0.34, 0.12, 0.38), SANDSTONE_LIGHT, bevel=False)
    _rune(glow, 0.0, f - 0.05, h - 3.6, k, 0.7)
    _moss(d, 0.3, y, h + 0.6, 2.4, 2.4, int(h))
    _moss(d, -0.6, f, 0.8, 1.6, 0.9, int(h) + 1)                                 # on the foot's ledge
    return [b.finalize(N + "Pier", mat), glow.finalize(N + "Pier_Glow", mat), d.finalize(N + "Pier_Decor", mat)]


def _run(s, mat, kinds, n, z0, z1, x, rot, seed):
    """n segments from z0 to z1 along a side wall at x (rot faces it inward), piers between."""
    length = z1 - z0
    L = (length - (n - 1) * 3.2) / n
    for i in range(n):
        t = z0 + i * (L + 3.2) + L / 2
        s.put(wall_segment(mat, kinds[(i + seed) % len(kinds)], L, i + seed), x, t, rot)
        if i < n - 1:
            s.put(pier(mat, 11.0 + 1.0 * ((i + seed) % 2), i + seed), x, t + L / 2 + 1.6, rot)


def low_wall(mat, L):
    """The camp side: a low stone wall 3.6 high with a coping, so the camp shows over it."""
    b = Builder()
    b.box_base((0, 1.0, 0), (L, 1.6, 3.2), STONE, bevel=False)
    b.box_base((0, 1.0, 3.2), (L + 0.2, 1.9, 0.4), STONE_LIGHT, bevel=False)
    for i in range(max(1, round(L / 10.0))):
        x = -L / 2 + (i + 0.5) * L / max(1, round(L / 10.0))
        b.box((x, 0.12, 2.2), (0.8, 0.1, 2.0), VINE, bevel=False)
    d = Builder()
    for i in range(max(1, round(L / 7.0))):
        _moss(d, -L / 2 + (i + 0.5) * L / max(1, round(L / 7.0)) + 1.0, 1.0, 3.6, 2.2, 1.6, i)
    return [b.finalize(N + "LowWall", mat), d.finalize(N + "LowWall_Decor", mat)]


def cat_head_wall(mat, L):
    """The far end: a ruined wall 22 high, coursed, broken at both ends. #2834: its flat carved head gave way to the
    cat colossus (colossus()), which stands in front of it, so the wall is plain courses with vines down it."""
    b = Builder()
    H = 22.0
    b.box_base((0, 1.6, 0), (L, 2.6, H - 4.0), STONE, bevel=False)
    n = max(2, round(L / 4.0))
    for i in range(n):
        x = -L / 2 + (i + 0.5) * L / n
        edge = min(i, n - 1 - i)
        h = 4.0 if edge > 3 else 4.0 - 2.6 * (edge % 2 == 0) - 0.04 * edge
        b.box_base((x, 1.6, H - 4.0), (L / n - 0.1, 2.6, max(0.4, h)), (STONE, STONE_LIGHT)[i % 2], bevel=False)
    for z in (2.0, 4.4, 6.8, 9.2, 11.6, 14.0, 16.4):
        b.box((0, 0.27, z), (L, 0.06, 0.12), STONE_DARK, bevel=False)
    for x in (-50.0, -36.0, -24.0, 24.0, 38.0, 52.0):                              # vines down it, clear of the head
        b.box((x, 0.2, H - 6.0), (1.3, 0.12, 8.0 + 0.1 * (x % 3)), VINE, bevel=False)
        b.box((x + 0.7, 0.18, H - 11.5), (0.9, 0.12, 3.4), VINE, bevel=False)
    return [b.finalize(N + "CatHeadWall", mat)]


def _walls(s, mat):
    """The long sides broken walls and portico runs along the plateau's edge with piers between; the bridge bay left
    open in the east wall; the cat-head wall across the far end; low walls either side of the way in; a barrier all
    round but the way in, round the bay instead of across it."""
    side = ("broken", "colonnade", "broken", "broken", "colonnade", "broken", "broken", "colonnade", "broken",
            "broken", "colonnade", "broken", "broken", "colonnade", "broken", "broken")
    _run(s, mat, side, 5, -IN_Z, BAY_Z0 - 2.2, IN_X, 90, 1)                  # east, to the bridge bay
    _run(s, mat, side, 11, BAY_Z1 + 2.2, IN_Z, IN_X, 90, 6)                  # and on from it
    _run(s, mat, side, 16, -IN_Z, IN_Z, -IN_X, -90, 2)
    s.put(cat_head_wall(mat, 2 * IN_X), 0, IN_Z, 0)
    for sx in (-1, 1):
        s.put(pier(mat, 14.0), sx * (IN_X - 1.6), -IN_Z + 1.6, 0)
        L = IN_X - GATE_HALF - 4.5
        s.put(low_wall(mat, L), sx * (GATE_HALF + 0.5 + L / 2), -IN_Z, 180)
        s.put(brazier(mat), sx * (GATE_HALF + 2.0), -IN_Z + 2.0, 0)                 # either side of the way in
    bar = Builder()
    ox = IN_X + WALL_D
    bar.box_base((0, IN_Z + WALL_D / 2, 0), (2 * ox, WALL_D, BARRIER_H), "offwhite", bevel=False)               # far
    x, _, _ = bl(-(IN_X + WALL_D / 2), 0)
    bar.box_base((x, 0, 0), (WALL_D, 2 * IN_Z, BARRIER_H), "offwhite", bevel=False)                        # west
    for (z0, z1) in ((-IN_Z, BAY_Z0), (BAY_Z1, IN_Z)):                                                     # east
        x, y, _ = bl(IN_X + WALL_D / 2, (z0 + z1) / 2)
        bar.box_base((x, y, 0), (WALL_D, z1 - z0, BARRIER_H), "offwhite", bevel=False)
    for sx in (-1, 1):
        bar.box_base((sx * (GATE_HALF + ox) / 2, -(IN_Z + WALL_D / 2), 0), (ox - GATE_HALF, WALL_D, BARRIER_H),
                     "offwhite", bevel=False)                                                               # camp
    s.put([bar.finalize(N + "Walls_Barrier", mat)], 0, 0, 0)


# ------------------------------------------------------------------------------------------- the bridge bay --
def _bridge_bay(s, mat):
    """The broken bridge ledge (section 5): a bay in the east wall from BAY_Z0 to BAY_Z1, its sides walls with piers;
    a broken parapet 2.4 high across it at PARAPET_X with a barrier over it to 9; the gap GAP wide past it, dark
    with mist (no floor shows); the bridge's far stub beyond, on a broken arch, its deck 0.8 up, running on out
    over the edge. The barriers round the bay's sides go to 30."""
    b, bar, mist = Builder(), Builder(), Builder()
    zc = (BAY_Z0 + BAY_Z1) / 2
    W = BAY_Z1 - BAY_Z0
    gx0, gx1 = PARAPET_X + 0.6, PARAPET_X + 0.6 + GAP                                 # the gap (area x)
    # the parapet: 0.6 thick, its top broken
    x, y, _ = bl(PARAPET_X + 0.3, zc)
    b.box_base((x, y, 0), (0.6, W, 1.6), STONE, bevel=False)
    for i in range(6):
        zz = BAY_Z0 + (i + 0.5) * W / 6
        x, y, _ = bl(PARAPET_X + 0.3, zz)
        b.box_base((x, y, 1.6), (0.7, W / 6 - 0.1, 0.8 - 0.5 * (i % 3 == 1) + 0.03 * (i % 2)), STONE_LIGHT,
                   bevel=False)
    x, y, _ = bl(PARAPET_X + 0.3, zc)
    bar.box_base((x, y, 0), (0.6, W, 9.0), "offwhite", bevel=False)
    # the gap: a dark drop with mist rising in it (no collision, so nothing stands on it)
    x, y, _ = bl((gx0 + gx1) / 2, zc)
    b.box_base((x, y, 0), (GAP, W, 0.06), "fur_ink", bevel=False)
    for i in range(5):
        zz = BAY_Z0 + (i + 0.5) * W / 5
        x, y, _ = bl((gx0 + gx1) / 2 + 0.6 * ((i % 2) - 0.5), zz)
        mist.ico((x, y, 0.4), 1.0, "fur_mist", subdivisions=1, scale=(GAP * 0.42, W / 5 * 0.7, 0.5))
    # the far stub: a deck on a broken arch, running on to the wall line
    sx0, sx1 = gx1, IN_X + WALL_D
    x, y, _ = bl((sx0 + sx1) / 2, zc)
    b.box_base((x, y, 0.06), (sx1 - sx0, 6.0, 0.74), SANDSTONE_LIGHT, bevel=False)            # deck, top 0.8
    for sy in (-1, 1):
        b.box_base((x, y + sy * 3.2, 0.8), (sx1 - sx0, 0.5, 1.0), STONE, bevel=False)          # its kerbs
    xb, _, _ = bl(sx0, zc)
    b.box_base((xb - 0.4, y, 0.06), (0.8, 6.0, 0.74), STONE_DARK, bevel=False)                 # the broken end
    b.box((xb - 0.9, y + 1.4, 0.5), (1.0, 1.4, 0.7), STONE_LIGHT, bevel=False, rot=(0.5, "Y"))
    # the bay's side walls
    for z, sgn in ((BAY_Z0, 1), (BAY_Z1, -1)):
        x, y, _ = bl((PARAPET_X + IN_X + WALL_D) / 2, z - sgn * 1.1)
        b.box_base((x, y, 0), (IN_X + WALL_D - PARAPET_X, 2.2, 9.6), STONE, bevel=False)
        b.box_base((x, y, 9.6), (IN_X + WALL_D - PARAPET_X + 0.2, 2.5, 0.5), STONE_LIGHT, bevel=False)
        bar.box_base((x, y, 0), (IN_X + WALL_D - PARAPET_X, 2.2, BARRIER_H), "offwhite", bevel=False)
    s.put([b.finalize(N + "BridgeBay", mat), mist.finalize(N + "BridgeBay_Decor", mat),
           bar.finalize(N + "BridgeBay_Barrier", mat)], 0, 0, 0)
    _spot(s, "trap_bridge_ledge", gx1 + 0.6, zc, y=0.8, turn=90)


# -------------------------------------------------------------------------------------------- the blockers --
def gargoyle(mat):
    """A gargoyle cat on its plinth, front -Z: a sitting stone cat with small folded wings, a jade collar stone,
    on a plinth 2.2 high; 6.6 in all."""
    b = Builder()
    b.box_base((0, 0, 0), (3.0, 3.0, 0.5), STONE_DARK, bevel=False)
    b.box_base((0, 0, 0.5), (2.5, 2.5, 1.5), STONE, bevel=False)
    b.box_base((0, 0, 2.0), (3.0, 3.0, 0.3), STONE_LIGHT, bevel=False)
    z = 2.3
    b.ico((0, 0.3, z + 1.0), 1.0, STONE_LIGHT, subdivisions=1, scale=(0.95, 1.2, 1.1))         # haunches
    b.box_base((0, -0.2, z + 0.9), (1.0, 1.0, 1.4), STONE_LIGHT, bevel=False)                  # chest
    b.box((0, -0.35, z + 2.65), (1.3, 1.1, 1.0), STONE_LIGHT, bevel=False)                     # head
    for sx in (-1, 1):
        b.pyramid((sx * 0.42, -0.35, z + 3.15), 0.45, 0.55, STONE_LIGHT)                       # ears
        b.box((sx * 0.3, -0.92, z + 2.75), (0.22, 0.06, 0.16), STONE_DARK, bevel=False)        # eyes
        b.box((sx * 0.75, 0.5, z + 1.9), (0.25, 1.4, 1.2), STONE, bevel=False,
              rot=Matrix.Rotation(sx * 0.35, 3, "Y"))                                         # wings
        b.box_base((sx * 0.35, -0.75, z), (0.32, 0.4, 0.5), STONE_LIGHT, bevel=False)         # paws
    b.box((0, -0.72, z + 1.95), (0.5, 0.1, 0.4), JADE, bevel=False)                            # collar stone
    b.box((0.7, 1.1, z + 0.3), (0.3, 1.6, 0.3), STONE_LIGHT, bevel=False, rot=(0.4, "Z"))       # tail
    d = Builder()
    _moss(d, -1.0, -1.3, 0.5, 1.4, 0.7, 0)                                                     # on the plinth's step
    _moss(d, 1.3, 0.6, 0.5, 0.7, 1.6, 1)
    return [b.finalize(N + "Gargoyle", mat), d.finalize(N + "Gargoyle_Decor", mat)]


def lane_wall(mat, L):
    """A low wall splitting the avenue's lanes, 2.4 high, 1.2 thick, coped, along local Y (the road's run)."""
    b = Builder()
    b.box_base((0, 0, 0), (1.2, L, 2.1), STONE, bevel=False)
    b.box_base((0, 0, 2.1), (1.4, L + 0.2, 0.3), STONE_LIGHT, bevel=False)
    for i in range(max(1, round(L / 8.0))):
        b.box((0.66, -L / 2 + (i + 0.5) * L / max(1, round(L / 8.0)), 1.4), (0.1, 1.4, 0.9), VINE, bevel=False)
    d = Builder()
    for i in range(max(1, round(L / 6.0))):
        _moss(d, 0.0, -L / 2 + (i + 0.3) * L / max(1, round(L / 6.0)), 2.4, 1.5, 3.2, i)
    return [b.finalize(N + "LaneWall", mat), d.finalize(N + "LaneWall_Decor", mat)]


def _triumphal_arch(s, mat):
    """The Triumphal Arch across the end of the avenue: two pylons (ISLE_ARCH, ARCH_H high, battered and coursed, a
    jade band and a gold disc on each) and an arch over the road between them carrying a cornice; open by the walls.
    A barrier BLOCK_OVER over each pylon."""
    b, bar = Builder(), Builder()
    z = ARCH_Z
    for k, (a0, a1) in enumerate(ISLE_ARCH):
        L = a1 - a0
        x, y, _ = bl((a0 + a1) / 2, z)
        b.box_base((x, y, 0), (L, 8.0, 1.0), STONE_DARK, bevel=False)
        b.box_base((x, y, 1.0), (L - 0.6, 7.0, ARCH_H - 1.6), SANDSTONE, bevel=False)
        b.box_base((x, y, ARCH_H - 0.6), (L, 7.8, 0.6), STONE_LIGHT, bevel=False)
        for zz in (3.4, 6.2, 9.0):
            b.box((x, y, zz), (L - 0.4, 7.12, 0.12), STONE, bevel=False)
        b.box((x, y, ARCH_H - 2.6), (L - 0.4, 7.2, 0.6), JADE, bevel=False)
        b.cyl((x, y - 3.65, 6.0), 2.0, 0.3, GOLD, segments=16, rot=(PI / 2, "X"))
        for e in (a0, a1):                                                  # broken stones at its ends
            xx, yy, _ = bl(e, z - 4.6)
            b.box_base((xx, yy, 0), (1.6, 1.2, 1.0), SANDSTONE, bevel=False, rot=(0.3 + k, "Z"))
        bar.box_base((x, y, 0), (L, 8.0, ARCH_H + BLOCK_OVER), "offwhite", bevel=False)
    w = ISLE_ARCH[1][0] - ISLE_ARCH[0][1]                                   # the arch over the road
    for i in range(14):
        a = PI * (i + 0.5) / 14
        x, y, _ = bl((w / 2) * math.cos(a), z)
        zz = ARCH_H - 4.5 + 3.0 * math.sin(a)
        b.box((x, y, zz), (w / 14 * 1.6 + 0.4, 6.0 - 0.01 * (i % 2), 1.6 - 0.03 * (i % 2)),
              (SANDSTONE, SANDSTONE_LIGHT)[i % 2], bevel=False,
              rot=(math.atan2(3.0 * math.cos(a), (w / 2) * math.sin(a)), "Y"))
    x, y, _ = bl(0, z)
    b.box_base((x, y, ARCH_H - 0.6), (w + 0.2, 6.6, 0.6), STONE_LIGHT, bevel=False)            # the cornice
    s.put([b.finalize(N + "TriumphalArch", mat), bar.finalize(N + "TriumphalArch_Barrier", mat)], 0, 0, 0)


def column(mat, h=12.0, broken=False):
    """A standing column (#2834 remake): a plinth and a moulded base, a shaft (12 sided) with eight flutes cut in a
    darker stone, a flared capital under its abacus; a moss band low on the shaft and a vine winding up it. Broken, the
    shaft stops in a jagged top with moss on it and a fallen drum lies behind it (local +Z, away from the cat spots
    at its front corners)."""
    b, d = Builder(), Builder()
    b.box_base((0, 0, 0), (2.8, 2.8, 0.6), STONE_DARK, bevel=False)
    b.cyl_base((0, 0, 0.6), 1.32, 0.3, STONE, segments=12)
    b.cyl_base((0, 0, 0.9), 1.18, 0.2, STONE_LIGHT, segments=12, bevel=False)
    hh = h * (0.6 if broken else 1.0)
    top = hh - (0.3 if broken else 1.4)                                           # where the shaft stops
    b.cyl_base((0, 0, 1.1), 1.05, top - 1.1, STONE_LIGHT, segments=12)
    for i in range(8):                                                            # the flutes
        a = 2 * PI * (i + 0.5) / 8
        b.box_base((1.02 * math.cos(a), 1.02 * math.sin(a), 1.4), (0.1, 0.22, top - 1.9 - 0.02 * (i % 2)), STONE,
                   bevel=False, rot=(a, "Z"))
    if broken:
        for k, (x, y, z, w, hgt, a) in enumerate(((0.25, 0.1, top, 1.3, 0.8, 0.4), (-0.45, -0.3, top, 0.9, 0.45, 1.1),
                                                   (0.4, -0.45, top, 0.7, 1.2, 0.2))):
            b.box_base((x, y, z), (w, w * 0.9, hgt + 0.01 * k), STONE_LIGHT, bevel=False, rot=(a, "Z"))
        _moss(d, 0.0, 0.0, top + 0.45, 1.6, 1.4, 0)
        b.cyl((0.3, 2.35, 0.95), 0.95, 1.9, STONE_LIGHT, segments=12, rot=(PI / 2, "Y"))     # the fallen drum
        _moss(d, 0.4, 2.35, 1.85, 1.3, 1.0, 1)
    else:
        b.cyl_base((0, 0, top), 1.05, 0.6, STONE, segments=12, radius2=1.42)
        b.box_base((0, 0, top + 0.6), (2.9, 2.9, 0.45), STONE_LIGHT, bevel=False)
        b.box((0, 0, top + 0.25), (2.96, 0.3, 0.3), STONE, bevel=False)          # volutes under the abacus
        b.cyl((0, 0, top + 0.25), 0.32, 3.0, STONE, segments=8, rot=(PI / 2, "Y"))
        _moss(d, 0.6, 0.4, top + 1.05, 1.6, 1.4, 1)
    d.cyl_base((0, 0, 1.9), 1.13, 0.55, MOSS, segments=12, bevel=False)          # the moss band
    for i in range(7):                                                            # a vine winding up the shaft
        a = 0.6 + i * 0.95
        z = 2.6 + i * (top - 3.6) / 7
        if z > top - 0.8:
            break
        d.box((1.12 * math.cos(a), 1.12 * math.sin(a), z), (0.16, 0.42, 1.3), (VINE, "leaf_green")[i % 2],
              bevel=False, rot=Matrix.Rotation(a, 3, "Z") @ Matrix.Rotation(0.5, 3, "X"))
    _moss(d, 0.9, -0.9, 0.6, 1.0, 1.0, 0)                                         # in the base's corners
    _moss(d, -0.95, 0.85, 0.6, 0.9, 1.0, 1)
    return [b.finalize(N + "Column" + ("Broken" if broken else ""), mat),
            d.finalize(N + "Column" + ("Broken" if broken else "") + "_Decor", mat)]


def drums(mat, n=3):
    """A toppled column lying in drums along local X, each a little turned, its capital at the end. #2834: a darker
    band where each drum meets the next, moss on their tops and at their feet, the last one half sunk."""
    b, d = Builder(), Builder()
    R = Matrix.Rotation(PI / 2, 3, "Y")
    for i in range(n):
        x = -2.6 * (n - 1) / 2 + 2.6 * i
        sink = 0.35 if i == 0 else 0.0
        b.cyl((x, 0.15 * math.sin(i * 2.1), 1.05 - sink), 1.05, 2.4, STONE_LIGHT, segments=12,
              rot=R @ Matrix.Rotation(0.08 * (i - 1), 3, "X"))
        if i:
            b.cyl((x - 1.3, 0.15 * math.sin(i * 2.1), 1.0), 0.98, 0.22, STONE, segments=12, rot=R, bevel=False)
        if i % 2 == 0:
            _moss(d, x + 0.3, 0.1, 2.05 - sink, 1.6, 1.2, i)
        _moss(d, x - 0.4, -1.0, 0.0, 1.4, 0.7, i + 1)
    b.box((2.6 * (n - 1) / 2 + 2.4, 0.6, 1.2), (2.4, 2.4, 1.0), STONE_LIGHT, bevel=False,
          rot=Matrix.Rotation(PI / 2, 3, "Y") @ Matrix.Rotation(0.3, 3, "Z"))
    return [b.finalize(N + "Drums", mat), d.finalize(N + "Drums_Decor", mat)]


def _stylobate(s, mat):
    """The colonnade's upper level: a stylobate STYLO_H high, coursed, its edge a darker course, ramps up from the
    road at its south end and its east side; rows of columns on it with beams overhead (two rows, three spans)."""
    b = Builder()
    x0, x1, z0, z1 = STYLO
    x, y, _ = bl((x0 + x1) / 2, (z0 + z1) / 2)
    b.box_base((x, y, 0), (x1 - x0, z1 - z0, STYLO_H), SANDSTONE, bevel=False)
    for zz in (1.2, 2.4):
        b.box((x, y, zz), (x1 - x0 + 0.12, z1 - z0 + 0.12, 0.1), STONE, bevel=False)
    b.box_base((x, y, STYLO_H - 0.02), (x1 - x0 - 1.0, z1 - z0 - 1.0, 0.1), FLAG, bevel=False)
    # ramps (the wedge's high back toward the stylobate): up north at its south end, up west on its east side, up
    # south at its north end
    for (rx, rz, turn) in ((-30.0, z0 - 6.0, 0.0), (x1 + 6.0, -60.0, -PI / 2), (-50.0, z1 + 6.0, PI)):
        xx, yy, _ = bl(rx, rz)
        b.wedge((xx, yy, STYLO_H / 2), (10.0, 12.0, STYLO_H), SANDSTONE_LIGHT, bevel=False, rot=(turn, "Z"))
    s.put([b.finalize(N + "Stylobate", mat)], 0, 0, 0)
    for i, zc in enumerate((-104.0, -80.0, -56.0, -32.0)):                    # the columns and their beams
        row_broken = False
        for j, xc in enumerate((-56.0, -38.0, -20.0)):
            broken = i % 2 == 1 and j != 1
            row_broken = row_broken or broken
            s.put(column(mat, 12.0, broken), xc, zc, 0, y=STYLO_H)
        if not row_broken:
            bb = Builder()
            xx, yy, _ = bl(-38.0, zc)
            bb.box_base((xx, yy, STYLO_H + 12.0), (40.0, 2.4, 1.4), STONE, bevel=False)
            bb.box_base((xx, yy, STYLO_H + 13.4), (40.6, 2.8, 0.4), STONE_LIGHT, bevel=False)
            s.put([bb.finalize(N + "Beam", mat)], 0, 0, 0)


def _pediment(s, mat, z, runs):
    """A fallen temple pediment standing across the low side (runs, x0 to x1): its triangle in courses on a rubble bed,
    PED_H high at the apex, a jade cat relief in the tympanum, column drums against it. A barrier BLOCK_OVER over it."""
    b, bar = Builder(), Builder()
    for (a0, a1) in runs:
        L = a1 - a0
        x, y, _ = bl((a0 + a1) / 2, z)
        b.box_base((x, y, 0), (L, 6.0, 2.0), STONE_DARK, bevel=False)                          # the rubble bed
        steps = 8                                                               # the triangle, in courses
        for i in range(steps):
            w = L * (1 - (i + 0.5) / steps)
            h = (PED_H - 2.0) / steps
            b.box_base((x, y, 2.0 + i * h), (w, 3.0 - 0.04 * (i % 2), h + 0.01), (SANDSTONE, SANDSTONE_LIGHT)[i % 2],
                       bevel=False)
        b.box_base((x, y, 2.0), (L + 0.6, 3.4, 0.6), STONE_LIGHT, bevel=False)                  # the cornice
        b.box((x, y - 1.55, 4.6), (4.0, 0.1, 2.4), JADE, bevel=False)                           # the relief
        for sx in (-1, 1):
            b.pyramid((x + sx * 1.3, y - 1.55, 5.8), 1.2, 1.1, JADE)
        bar.box_base((x, y, 0), (L + 0.6, 7.0, PED_H + BLOCK_OVER), "offwhite", bevel=False)
    s.put([b.finalize(N + "Pediment", mat), bar.finalize(N + "Pediment_Barrier", mat)], 0, 0, 0)


def _glyph(box0, u, h, f, kind, k=1.7):
    """A carved glyph on a wall face (f the face's side, the face at v = f * (HALL_T / 2 + 0.2)): a cat's head with
    its ears and eyes, a paw print, or a fish, in sandstone on the panel; box(u, v, h, su, sv, sh, swatch)."""
    v = f * (HALL_T / 2 + 0.36)

    def box(bu, bv, bh, su, sv, sh, sw):                                 # scaled k about (u, h), not in depth
        box0(u + (bu - u) * k, bv, h + (bh - h) * k, su * k, sv, sh * k, sw)

    if kind == 0:                                                        # a cat's head
        box(u, v, h, 2.2, 0.16, 1.8, SANDSTONE_LIGHT)
        for su in (-1, 1):
            box(u + su * 0.75, v, h + 1.15, 0.6, 0.16, 0.6, SANDSTONE_LIGHT)
            box(u + su * 0.5, v + f * 0.06, h + 0.15, 0.36, 0.08, 0.42, STONE_DARK)
        box(u, v + f * 0.06, h - 0.45, 0.3, 0.08, 0.22, STONE_DARK)
    elif kind == 1:                                                      # a paw print
        box(u, v, h - 0.3, 1.5, 0.16, 1.2, SANDSTONE_LIGHT)
        for k, (du, dh) in enumerate(((-0.85, 0.65), (-0.3, 0.95), (0.3, 0.95), (0.85, 0.65))):
            box(u + du, v, h + dh, 0.5, 0.16, 0.5, SANDSTONE_LIGHT)
    else:                                                                # a fish
        box(u - 0.2, v, h, 2.0, 0.16, 0.9, SANDSTONE_LIGHT)
        box(u + 1.15, v, h, 0.5, 0.16, 1.4, SANDSTONE_LIGHT)
        box(u - 0.8, v + f * 0.06, h + 0.12, 0.22, 0.08, 0.22, STONE_DARK)


def _carved_wall(b, glow, L, box, seed):
    """A Glyph Hall wall L long in its own frame (u along it from -L/2, v across, h up), drawn through box(u, v, h, su,
    sv, sh, swatch, target): a dark plinth, coursed stone with a light band every other course, pilasters every bay
    with capitals, a recessed panel in each bay with a carved glyph on alternate faces, the glowing glyph strip, a
    broken top (merlons, some missing, some fallen to the foot), vines hanging over the top and moss along it (Derek2
    11-09: the walls felt low effort)."""
    n = max(1, round(L / 8.0))
    bay = L / n
    box(0, 0, 0.6, L + 0.02, HALL_T + 0.7, 1.2, STONE_DARK)                         # the plinth
    for k, hh in enumerate((3.4, 8.2)):                                             # coursing bands
        box(0, 0, hh, L - 0.1, HALL_T + 0.16 + 0.02 * k, 0.3, STONE_LIGHT)
    broken = [n > 2 and (i + seed) % 5 == 3 for i in range(n)]
    for i in range(n):                                                              # the body, bay by bay
        u = -L / 2 + (i + 0.5) * bay
        if broken[i]:                                                               # its top fallen in, stepped
            box(u, 0, (HALL_H - 3.4) / 2, bay + 0.01, HALL_T, HALL_H - 3.4, STONE)
            box(u - bay * 0.3, 0, HALL_H - 3.4 + 0.9, bay * 0.4, HALL_T - 0.02, 1.8, STONE_LIGHT)
            box(u + bay * 0.33, 0, HALL_H - 3.4 + 1.5, bay * 0.34, HALL_T - 0.04, 3.0, STONE)
        else:
            box(u, 0, HALL_H / 2, bay + 0.01 * (i % 2 + 1), HALL_T, HALL_H, STONE)
            box(u, 0, HALL_H + 0.27, bay + 0.3 + 0.01 * (i % 2), HALL_T + 0.3, 0.54, STONE_LIGHT)   # the coping
    for i in range(n + 1):                                                          # pilasters, both faces
        u = -L / 2 + i * bay
        if i in (0, n):
            u += 0.7 if i == 0 else -0.7
        for f in (-1, 1):
            box(u, f * (HALL_T / 2 + 0.25), 6.0, 1.3, 0.5, 9.6, SANDSTONE)
            box(u, f * (HALL_T / 2 + 0.35), 11.1, 1.7, 0.7, 0.6, STONE_LIGHT)
    for i in range(n):
        u = -L / 2 + (i + 0.5) * bay
        j = i + seed
        for f in (-1, 1):
            box(u, f * (HALL_T / 2 + 0.06), 5.8, bay - 2.4, 0.12, 4.6, STONE_DARK)    # the recessed panel
            glow.box(u, f * (HALL_T / 2 + 0.16), 8.1, bay - 3.0, 0.08, 0.3, (JADE, GOLD)[f > 0])
            if (j + (f > 0)) % 2 == 0:
                _glyph(box, u, 5.4, f, j % 3)
        if broken[i]:                                                               # its fallen blocks
            for f, du in ((-1, -1.2), (1, 1.4)):
                box(u + du, f * (HALL_T / 2 + 1.5), 0.6, 1.8, 1.4, 1.2, (STONE, STONE_LIGHT)[f > 0])
            continue
        for m in (-1, 1):                                                           # merlons, broken
            if (j * 3 + m) % 5 == 0:
                continue
            hm = 1.6 - 0.5 * ((j + m) % 3 == 0)
            box(u + m * bay * 0.25, 0, HALL_H + 0.54 + hm / 2, bay * 0.3, HALL_T, hm, (STONE, STONE_LIGHT)[(j + m) % 2])
        if j % 3 == 1:                                                              # vines over the top
            for f in (-1, 1):
                for k, (du, dl) in enumerate(((-0.8, 4.2), (0.2, 6.4), (1.1, 3.0))):
                    box(u + du + f * 0.4, f * (HALL_T / 2 + 0.42), HALL_H + 0.4 - dl / 2, 0.45, 0.14, dl, VINE)
                box(u + f * 0.3, 0, HALL_H + 0.62, 3.4, HALL_T + 0.5, 0.2, "leaf_green")  # moss on the coping
        if j % 4 == 2:                                                              # a fallen merlon at the foot
            f = 1 if j % 8 == 2 else -1
            box(u + 1.0, f * (HALL_T / 2 + 1.7), 0.5, bay * 0.3, 1.2, 1.0, STONE_LIGHT)


def _halls(s, mat):
    """The Glyph Halls: the long walls (HALL_WALLS, z HALLS_Z0 to HALLS_Z1) each with a doorway, the end walls with
    three ways in and three out, hall 3's baffle at z 105; carved walls HALL_H high (_carved_wall), glowing glyph
    strips along both faces of every wall (_Glow), a barrier to 30 over every wall."""
    b, glow, bar = Builder(), Builder(), Builder()

    def frame(xx, yy, along_y):
        def box(u, v, h, su, sv, sh, swatch, target=None):
            t = target or b
            if along_y:
                t.box((xx + v, yy + u, h), (sv, su, sh), swatch, bevel=False)
            else:
                t.box((xx + u, yy + v, h), (su, sv, sh), swatch, bevel=False)

        class G:                                                         # the glow strips, in the same frame
            @staticmethod
            def box(u, v, h, su, sv, sh, swatch):
                box(u, v, h, su, sv, sh, swatch, target=glow)
        return box, G

    def wall_x(x, z0, z1):
        L = z1 - z0
        xx, yy, _ = bl(x, (z0 + z1) / 2)
        box, g = frame(xx, yy, True)
        _carved_wall(b, g, L, box, int(abs(x) + z0) % 7)
        bar.box_base((xx, yy, 0), (HALL_T, L, BARRIER_H), "offwhite", bevel=False)

    def wall_z(z, x0, x1):
        L = x1 - x0
        xx, yy, _ = bl((x0 + x1) / 2, z)
        box, g = frame(xx, yy, False)
        _carved_wall(b, g, L, box, int(abs(x0) + z) % 7)
        bar.box_base((xx, yy, 0), (L, HALL_T, BARRIER_H), "offwhite", bevel=False)

    for x in HALL_WALLS:
        d = HALL_DOORS[x]
        wall_x(x, HALLS_Z0 + HALL_T / 2, d - DOOR_W / 2)
        wall_x(x, d + DOOR_W / 2, HALLS_Z1 - HALL_T / 2)
    for z, ways in ((HALLS_Z0, HALL_IN), (HALLS_Z1, HALL_OUT)):
        edges = [-IN_X]
        for c in ways:
            edges += [c - DOOR_W / 2, c + DOOR_W / 2]
        edges.append(IN_X)
        for a0, a1 in zip(edges[0::2], edges[1::2]):
            wall_z(z, a0, a1)
    wall_z(105.0, -14.0 + HALL_T / 2, 4.0)                                        # hall 3's baffle
    s.put([b.finalize(N + "GlyphHalls", mat), glow.finalize(N + "GlyphHalls_Glow", mat),
           bar.finalize(N + "GlyphHalls_Barrier", mat)], 0, 0, 0)


def _court(s, mat):
    """The Golem Courtyard: three stone rings stepping down to the court's floor (RINGS, 4 wide each), open at
    RING_GAPS with the ring ends squared off by blocks; the dry fountain in the middle; the great throne at the back."""
    b = Builder()
    cx, cz = COURT
    ox, oy, _ = bl(cx, cz)
    for k, (r0, top) in enumerate(RINGS):
        r_out = r0 + 4.0
        n = 48
        chord = 2 * r_out * math.sin(PI / n) * 1.04
        for i in range(n):
            a = 2 * PI * (i + 0.5) / n
            deg = math.degrees(a)                                                # Builder angle; Roblox x is -X
            rdeg = (180.0 - deg) % 360.0                                         # the same direction in area space
            if any(min(abs(rdeg - g % 360), 360 - abs(rdeg - g % 360)) < 9.0 + 1.2 * k for g in RING_GAPS):
                continue
            rr = r_out - 2.0
            b.box_base((ox + rr * math.cos(a), oy + rr * math.sin(a), 0), (4.0, chord, top + 0.006 * (i % 2)),
                       (SANDSTONE, STONE_LIGHT, SANDSTONE_LIGHT)[k], bevel=False, rot=(a, "Z"))
    s.put([b.finalize(N + "CourtRings", mat)], 0, 0, 0)
    s.put(fountain(mat), cx, cz, 0)
    s.put(throne(mat), cx, THRONE_Z, 0)


def fountain(mat):
    """The fountain (#2834 remake), in its old round basin (rim 7, 0.9 high), now running: teal water in the basin, a
    pedestal with four cat-head spouts pouring into it, an upper bowl on the pedestal brimming over in four falls,
    and the stone cat on a post in the bowl, its mouth open. Lily pads on the water, moss on the rim. The water
    (_Water) is see-through and splashes."""
    b, water, d = Builder(), Builder(), Builder()
    ring_blocks(b, 0, 0, 0, 7.0, 1.0, 0.9, STONE_LIGHT, n=28)
    b.cyl_base((0, 0, 0), 6.1, 0.2, SANDSTONE, segments=24, bevel=False)
    water.cyl_base((0, 0, 0.22), 6.05, 0.46, WATER, segments=24, bevel=False)
    b.cyl_base((0, 0, 0.2), 1.6, 0.6, STONE, segments=12)                          # the pedestal
    b.cyl_base((0, 0, 0.8), 0.9, 2.4, STONE_LIGHT, segments=12)
    for i in range(4):                                                            # cat-head spouts
        a = PI / 4 + i * PI / 2
        ca, sa = math.cos(a), math.sin(a)
        hx, hy = 1.05 * ca, 1.05 * sa
        b.box((hx, hy, 1.9), (0.62, 0.8, 0.7), STONE, bevel=False, rot=(a, "Z"))
        for e in (-1, 1):
            b.box((hx - 0.24 * e * sa, hy + 0.24 * e * ca, 2.35), (0.24, 0.26, 0.26), STONE, bevel=False,
                  rot=Matrix.Rotation(a, 3, "Z") @ Matrix.Rotation(PI / 4, 3, "X"))
        b.box((1.37 * ca, 1.37 * sa, 1.72), (0.08, 0.3, 0.18), "fur_ink", bevel=False, rot=(a, "Z"))
        water.box((1.6 * ca, 1.6 * sa, 1.66), (0.5, 0.22, 0.16), FALL_WATER, bevel=False, rot=(a, "Z"))
        water.box_base((1.9 * ca, 1.9 * sa, 0.6), (0.22, 0.22, 1.1), FALL_WATER, bevel=False)
        d.sphere((1.9 * ca, 1.9 * sa, 0.7), 0.5, FOAM, segments=6, rings=3, scale=(0.9, 0.9, 0.3))
    b.cyl_base((0, 0, 3.2), 1.4, 0.5, STONE, segments=14, radius2=2.9)            # the upper bowl
    ring_blocks(b, 0, 0, 3.7, 3.0, 0.4, 0.35, STONE_LIGHT, n=20)
    water.cyl_base((0, 0, 3.72), 2.62, 0.22, WATER, segments=16, bevel=False)
    for i in range(4):                                                            # brimming over between the spouts
        a = i * PI / 2
        water.box_base((3.08 * math.cos(a), 3.08 * math.sin(a), 0.6), (0.14, 0.9, 3.45), FALL_WATER, bevel=False,
                       rot=(a, "Z"))
    b.cyl_base((0, 0, 3.7), 0.5, 0.9, STONE, segments=10)                         # the cat's post
    b.ico((0, 0.2, 5.6), 0.9, STONE_LIGHT, subdivisions=1, scale=(0.9, 1.1, 1.0))
    b.box((0, -0.45, 6.6), (1.1, 0.9, 0.9), STONE_LIGHT, bevel=False)
    for sx in (-1, 1):
        b.pyramid((sx * 0.35, -0.45, 7.05), 0.4, 0.45, STONE_LIGHT)
    b.box((0, -0.92, 6.35), (0.4, 0.1, 0.25), STONE_DARK, bevel=False)                       # the open mouth
    for (x, y) in ((4.2, 2.2), (-3.6, 3.3), (-4.4, -2.0), (2.6, -4.4)):                    # lily pads
        d.cyl_base((x, y, 0.7), 0.6, 0.05, "leaf_green", segments=8, bevel=False)
    for k in range(4):
        a = k * 1.6 + 0.3
        _moss(d, 6.5 * math.cos(a), 6.5 * math.sin(a), 0.9 + 0.006 * (k % 2), 1.8, 0.9, k)
    return [b.finalize(N + "Fountain", mat), water.finalize(N + "Fountain_Water", mat),
            d.finalize(N + "Fountain_Decor", mat)]


def throne(mat):
    """The great stone throne (the Golem's seat): a dais of two steps, a seat 4 up and 8 wide, armrests ending in
    cat heads, a back 14 high with a jade panel and a gold sun crest, a broken piece at its foot. Front -Z."""
    b = Builder()
    b.box_base((0, 0, 0), (18.0, 13.0, 1.2), STONE, bevel=False)
    b.box_base((0, 1.0, 1.2), (14.0, 10.0, 1.2), STONE_LIGHT, bevel=False)
    b.box_base((0, 1.4, 2.4), (8.0, 6.0, 1.8), STONE, bevel=False)                            # the seat, top 4.2
    b.box_base((0, 4.0, 2.4), (9.0, 1.6, 14.0), STONE, bevel=False)                           # the back
    b.box((0, 3.15, 10.0), (5.0, 0.1, 6.0), JADE, bevel=False)
    b.cyl((0, 4.0, 17.4), 2.4, 1.0, GOLD, segments=16, rot=(PI / 2, "X"))
    for k in range(8):
        a = 2 * PI * k / 8
        b.box((2.9 * math.cos(a), 4.0, 17.4 + 2.9 * math.sin(a)), (0.9, 0.8, 0.5), GOLD, bevel=False,
              rot=(-a, "Y"))
    for sx in (-1, 1):
        b.box_base((sx * 4.6, 1.4, 2.4), (1.2, 6.0, 3.6), STONE_LIGHT, bevel=False)            # armrests
        b.box((sx * 4.6, -1.7, 6.6), (1.4, 1.2, 1.2), STONE_LIGHT, bevel=False)                 # cat heads on them
        for ex in (-1, 1):
            b.pyramid((sx * 4.6 + ex * 0.4, -1.7, 7.2), 0.45, 0.5, STONE_LIGHT)
    b.box_base((6.5, -5.2, 0), (2.0, 1.6, 1.2), STONE_LIGHT, bevel=False, rot=(0.5, "Z"))
    return [b.finalize(N + "Throne", mat)]


# -------------------------------------------------------------------------------------- the landmarks (#2834) --
def colossus(mat):
    """The cat colossus: a huge carved cat's head sunk to the chin in a heap of fallen blocks against the far wall,
    its ears up to about 39 so it shows over the halls from the Triumphal Arch, its eyes (24 up) over the throne.
    A tiara with a jade band and a gold boss across its brow, vines hanging from it, moss on the crown, one ear
    broken off and lying at the heap's foot. Its eyes glow teal (_Glow). Front -Z; the back sits in the wall. A barrier to
    44 over the lot, so nobody climbs it out of the area."""
    b, glow, d, bar = Builder(), Builder(), Builder(), Builder()
    # the heap: a low core and tumbled blocks round it, highest against the wall
    b.cyl_base((0, 4.0, 0), 15.0, 5.0, STONE_DARK, segments=14, radius2=11.0, scale=(1, 0.62, 1), bevel=False)
    b.cyl_base((0, 6.0, 5.0), 11.0, 6.0, STONE, segments=14, radius2=7.5, scale=(1, 0.62, 1), bevel=False)
    for k, (x, y, z, w, dd, h, a) in enumerate((
            (-12.6, -2.0, 0, 4.6, 4.0, 3.2, 0.3), (-8.4, -5.6, 0, 4.0, 3.4, 2.6, -0.4), (-3.2, -8.0, 0, 3.6, 3.0, 2.0, 0.6),
            (3.4, -8.2, 0, 4.2, 3.2, 2.2, -0.2), (8.8, -5.4, 0, 4.4, 3.8, 2.8, 0.5), (12.8, -1.6, 0, 4.0, 4.4, 3.4, -0.3),
            (-10.2, 2.4, 3.6, 4.2, 3.6, 3.0, 0.7), (10.6, 2.8, 3.8, 4.6, 3.4, 3.0, -0.6), (-6.4, -3.0, 2.4, 3.4, 3.0, 2.4, 0.2),
            (6.0, -3.4, 2.2, 3.2, 3.2, 2.6, -0.5), (-12.0, 7.6, 0, 3.6, 4.0, 7.4, 0.1), (12.4, 8.0, 0, 3.4, 3.6, 7.4, -0.2))):
        b.box_base((x, y, z), (w, dd, h + 0.01 * k), (STONE, STONE_LIGHT, SANDSTONE, STONE_DARK)[k % 4], bevel=False,
                   rot=(a, "Z"))
        if k % 3 != 2:
            _moss(d, x + 0.3, y - 0.2, z + h + 0.01 * k, w * 0.7, dd * 0.6, k)
    # the head: crown, cheeks, chin, all carved stone
    b.sphere((0, 3.0, 22.0), 0.5, STONE_LIGHT, segments=18, rings=12, scale=(25.0, 20.0, 23.0))
    for sx in (-1, 1):
        b.sphere((sx * 3.2, -7.0, 16.6), 0.5, STONE_LIGHT, segments=12, rings=8, scale=(8.6, 6.4, 6.8))
    b.sphere((0, -6.4, 13.4), 0.5, STONE, segments=12, rings=8, scale=(7.0, 5.4, 4.6))
    b.box((0, -7.7, 19.3), (2.6, 1.6, 1.7), STONE_DARK, bevel=False, rot=(0.35, "X"))          # the nose
    for sx in (-1, 1):
        x = sx * 4.8
        b.sphere((x, -6.0, 23.6), 0.5, STONE_DARK, segments=12, rings=6, scale=(5.4, 1.6, 3.3), rot=(-sx * 0.14, "Y"))
        glow.sphere((x, -6.35, 23.6), 0.5, RUNE, segments=12, rings=6, scale=(4.0, 1.2, 2.4), rot=(-sx * 0.14, "Y"))
        b.box((x, -6.98, 23.6), (0.5, 0.12, 2.0), "fur_ink", bevel=False)                       # the pupil, a slit
    b.pyramid((8.0, 2.0, 28.4), 9.4, 12.6, STONE_LIGHT, rot=(-0.2, "Y"))                     # the whole ear
    b.pyramid((8.2, -0.4, 29.4), 5.0, 8.4, STONE_DARK, rot=(-0.2, "Y"))
    b.cyl((-7.9, 2.0, 31.6), 6.6, 6.4, STONE_LIGHT, segments=4, radius2=3.4,                   # the broken one
          rot=Matrix.Rotation(0.2, 3, "Y") @ Matrix.Rotation(PI / 4, 3, "Z"), bevel=False)
    b.box((-8.5, 2.0, 34.85), (3.2, 3.0, 0.3), STONE, bevel=False, rot=(0.2, "Y"))
    b.wedge((-14.2, -7.2, 1.6), (3.0, 4.4, 3.2), STONE_LIGHT, bevel=False, rot=(0.7, "Z"))       # its tip, fallen
    for k, (x, z, a) in enumerate(((-3.0, 28.6, 0.2), (2.6, 27.4, -0.3), (8.6, 21.0, 0.5))):  # cracks
        b.box((x, -5.6 + 0.6 * k, z), (3.2, 0.12, 0.2), STONE_DARK, bevel=False, rot=(a, "Y"))
    # the tiara on the brow: an arc of points over a jade band, a gold boss in the middle
    for i in range(9):
        t = -0.9 + 1.8 * i / 8
        x, y = 9.6 * math.sin(t), 3.0 - 8.4 * math.cos(t)
        h = 2.2 if i % 2 == 0 else 1.5
        b.box_base((x, y, 28.4), (2.2, 1.3, h + 0.01 * i), STONE, bevel=False, rot=(-t, "Z"))
        b.box((x * 0.98, y + 0.12, 28.4), (2.5, 1.2, 0.9), JADE, bevel=False, rot=(-t, "Z"))
    b.cyl((0, -5.75, 29.4), 1.2, 0.4, GOLD, segments=12, rot=(PI / 2, "X"))
    # vines over the tiara and down the sides of the head, moss over the crown
    for k, (x, dl) in enumerate(((-8.4, 9.0), (-6.8, 5.0), (-1.4, 2.6), (1.6, 3.4), (6.6, 6.0), (8.6, 10.4))):
        t = math.asin(max(-1.0, min(1.0, x / 9.8)))
        y = 3.0 - 8.6 * math.cos(t) - 0.5
        b.box((x, y, 28.4 - dl / 2), (0.55, 0.16, dl), (VINE, "leaf_green")[k % 2], bevel=False, rot=(-t, "Z"))
    for k, (x, y, w, dd) in enumerate(((0.0, 4.0, 9.0, 8.0), (-4.8, 7.0, 5.0, 4.0), (4.6, 0.0, 4.4, 3.6))):
        _moss(d, x, y, 33.0 - 0.6 * k - 0.04 * abs(x), w, dd, k)
    for k, (x, y, z) in enumerate(((-9.6, -3.6, 11.2), (9.4, -3.2, 11.6))):                   # leaves at the jaw
        d.sphere((x, y, z), 0.5, (VINE, "leaf_green")[k], segments=8, rings=5, scale=(3.6, 3.0, 2.4))
    bar.box_base((0, 2.0, 0), (32.0, 22.0, 44.0), "offwhite", bevel=False)
    return [b.finalize(N + "Colossus", mat), glow.finalize(N + "Colossus_Glow", mat),
            d.finalize(N + "Colossus_Decor", mat), bar.finalize(N + "Colossus_Barrier", mat)]


def waterfall(mat):
    """The waterfall: a broken aqueduct comes in over the plateau's wall (local +Z) on one pier and stops in a jagged
    end; its water falls 11 into a round pool with a stone rim, foam at the foot, stepping stones across the front,
    lily pads, a fallen block from the lost arch. The water (_Water) is see-through and splashes; the foam, lily pads,
    moss and vines are _Decor. A barrier over the pier and the aqueduct. Front -Z, the pool's centre at the pivot."""
    b, water, d, bar = Builder(), Builder(), Builder(), Builder()
    R = 6.6
    ring_blocks(b, 0, 0, 0, R, 1.1, 0.8, STONE_LIGHT, n=28)
    b.cyl_base((0, 0, 0), R - 0.9, 0.06, STONE_DARK, segments=24, bevel=False)                 # the pool's bed
    water.cyl_base((0, 0, 0.09), R - 0.95, 0.46, WATER, segments=24, bevel=False)
    for k in range(5):
        a = 2 * PI * k / 5 + 0.9
        _moss(d, (R - 0.55) * math.cos(a), (R - 0.55) * math.sin(a), 0.8 + 0.006 * (k % 2), 1.8, 1.0, k)
    for k, (x, y) in enumerate(((-4.2, -2.4), (-1.9, -3.5), (0.7, -3.7), (3.3, -2.9))):       # stepping stones
        b.cyl_base((x, y, 0), 0.95 - 0.05 * (k % 2), 0.75 + 0.03 * k, STONE, segments=10, bevel=False)
    for (x, y) in ((-3.4, 1.2), (3.6, 0.6), (-1.0, -1.6)):                                  # lily pads
        d.cyl_base((x, y, 0.57), 0.7, 0.05, "leaf_green", segments=8, bevel=False)
    d.cyl_base((-3.2, 1.3, 0.62), 0.16, 0.16, "blush", segments=6, bevel=False)
    b.box_base((2.6, 0.6, 0), (1.8, 1.3, 1.1), SANDSTONE, bevel=False, rot=(0.5, "Z"))         # the fallen block
    _moss(d, 2.6, 0.6, 1.1, 1.3, 0.9, 1)
    # the aqueduct: a pier, an arch to the wall, the channel on top running out over the wall
    PY, Z0 = 7.4, 10.4
    b.box_base((0, PY, 0), (3.4, 3.4, 0.8), STONE_DARK, bevel=False)
    b.box_base((0, PY, 0.8), (2.8, 2.8, Z0 - 0.8), STONE, bevel=False)
    b.box((0, PY, 8.2), (2.96, 2.96, 0.4), JADE, bevel=False)
    for i in range(6):                                                                       # the arch to the wall
        a = PI * (i + 0.5) / 6
        r = (11.7 - PY - 1.4) / 2
        cy = PY + 1.4 + r
        b.box((0, cy - r * math.cos(a), Z0 - 2.4 + 1.6 * math.sin(a)), (2.4, 1.5, 0.9 + 0.01 * i),
              (STONE, STONE_LIGHT)[i % 2], bevel=False, rot=(a - PI / 2, "X"))
    b.box_base((0, 12.3, 6.4), (3.0, 1.6, Z0 - 6.4), STONE, bevel=False)                       # its seat on the wall
    y0, y1 = 2.2, 14.6
    b.box_base((0, (y0 + y1) / 2 + 0.3, Z0), (3.4, y1 - y0 - 0.6, 0.8), STONE_LIGHT, bevel=False)   # the channel
    for sx, yb in ((-1, 2.9), (1, 3.6)):                                                     # its sides, broken short
        b.box_base((sx * 1.4, (yb + y1) / 2, Z0 + 0.8), (0.6, y1 - yb, 1.2), STONE_LIGHT, bevel=False)
        b.box_base((sx * 1.4, (yb + y1) / 2 + 0.6, Z0 + 2.0), (0.8, y1 - yb - 1.2, 0.3), STONE, bevel=False)
        _moss(d, sx * 1.4, 7.0 + sx, Z0 + 2.3, 1.0, 3.6, 2 + sx)
        for k, (yy, dl) in enumerate(((5.0, 3.6), (9.2, 2.4), (11.0, 4.4))):                  # vines down its sides
            b.box((sx * 1.78, yy + 0.4 * sx, Z0 + 0.6 - dl / 2), (0.14, 0.5, dl), (VINE, "leaf_green")[k % 2],
                  bevel=False)
    b.box_base((0.5, y0 + 0.1, Z0 - 0.5), (1.6, 0.9, 0.6), STONE_LIGHT, bevel=False, rot=(0.3, "Z"))  # its broken lip
    water.box_base((0, (y0 + y1) / 2 + 0.5, Z0 + 0.8), (2.2, y1 - y0 - 0.6, 0.7), WATER, bevel=False)
    water.box((0, y0 + 0.1, Z0 + 1.05), (2.2, 0.9, 0.5), FALL_WATER, bevel=False, rot=(-0.6, "X"))   # over the lip
    water.box_base((0, y0 - 0.4, 0.5), (2.6, 0.3, Z0 + 0.7), FALL_WATER, bevel=False)               # the fall
    for k, (x, w) in enumerate(((-0.75, 0.5), (0.3, 0.7), (0.95, 0.35))):                     # streaks in it
        water.box_base((x, y0 - 0.62, 0.5 + 0.8 * k), (w, 0.14, Z0 - 0.4 - 1.1 * k), "pastel_sky", bevel=False)
    for k in range(6):                                                                       # foam at its foot
        a = 2 * PI * k / 6
        d.sphere((1.3 * math.cos(a), y0 - 0.5 + 0.9 * math.sin(a), 0.58), 0.5, FOAM, segments=8, rings=4,
                 scale=(1.5, 1.1, 0.5 + 0.04 * k))
    d.sphere((0, y0 - 0.5, 0.62), 0.5, FOAM, segments=8, rings=4, scale=(2.4, 1.6, 0.6))
    bar.box_base((0, (y0 + y1) / 2 + 2.2, 0), (4.4, y1 - y0 - 3.6, 30.0), "offwhite", bevel=False)
    return [b.finalize(N + "Waterfall", mat), water.finalize(N + "Waterfall_Water", mat),
            d.finalize(N + "Waterfall_Decor", mat), bar.finalize(N + "Waterfall_Barrier", mat)]


def _rune(g, x, y, z, k, s_=1.0, t=0.08):
    """A rune on a face at y (facing -Y), centred (x, z), t thick: a branched stroke, a paw or a diamond, in g."""
    if k % 3 == 0:
        g.box((x, y, z), (0.24 * s_, t, 2.4 * s_), RUNE, bevel=False)
        for sx in (-1, 1):
            g.box((x + sx * 0.36 * s_, y, z + 0.55 * s_), (0.2 * s_, t, 0.95 * s_), RUNE, bevel=False,
                  rot=(sx * 0.6, "Y"))
    elif k % 3 == 1:
        g.box((x, y, z - 0.3 * s_), (0.9 * s_, t, 0.7 * s_), RUNE, bevel=False)
        for du, dh in ((-0.6, 0.35), (0.0, 0.62), (0.6, 0.35)):
            g.box((x + du * s_, y, z + dh * s_), (0.34 * s_, t, 0.34 * s_), RUNE, bevel=False)
    else:
        for sx in (-1, 1):
            for sz in (-1, 1):
                g.box((x + sx * 0.42 * s_, y, z + sz * 0.42 * s_), (0.2 * s_, t, 1.2 * s_), RUNE, bevel=False,
                      rot=(sx * sz * PI / 4, "Y"))
        g.box((x, y, z), (0.3 * s_, t, 0.3 * s_), RUNE, bevel=False)


def rune_stone(mat, k=0):
    """A standing stone (4.6 to 6.4 high): a wide, thin slab in two courses that narrows to a broken top, with a rune
    glowing teal on its -Z face, moss at its foot and on the top. k picks the height, the rune and the lean of its
    upper course."""
    b, glow, d = Builder(), Builder(), Builder()
    h = (5.6, 4.6, 6.4)[k % 3]
    sd = 1 - 2 * (k % 2)
    lo = h * 0.62
    b.box_base((0, 0, 0), (2.6, 1.3, lo), (STONE, STONE_LIGHT)[k % 2], bevel=False)
    b.box_base((0.12 * sd, 0.02, lo), (2.2, 1.16, h - lo - 0.5), (STONE, STONE_LIGHT)[k % 2], bevel=False,
               rot=(0.05 * sd, "Z"))
    b.box_base((0.3 * sd, 0.04, h - 0.5), (1.4, 0.98, 0.5 + 0.02 * (k % 3)), STONE, bevel=False,
               rot=(0.3 - 0.2 * (k % 3), "Z"))                                            # its broken top
    b.box_base((-1.8 * sd, -0.9, 0), (0.9, 0.7, 0.5), STONE_DARK, bevel=False, rot=(0.6, "Z"))
    _rune(glow, 0.0, -0.69, lo / 2 + 0.1, k)
    _moss(d, 0.5 * sd, -0.55, 0.0, 1.8, 0.9, k)
    _moss(d, 0.3 * sd, 0.04, h, 1.2, 0.8, k + 1)
    return [b.finalize(N + "RuneStone", mat), glow.finalize(N + "RuneStone_Glow", mat),
            d.finalize(N + "RuneStone_Decor", mat)]


def trilithon(mat, w=12.8):
    """A stone-henge gate over the way: two standing stones w apart (centres) carrying a lintel 8 up, a rune on each
    stone's -Z face, moss on the lintel and a vine off it."""
    b, glow, d = Builder(), Builder(), Builder()
    for k, sx in enumerate((-1, 1)):
        x = sx * w / 2
        b.box_base((x, 0, 0), (2.4, 1.9, 8.0 + 0.02 * k), (STONE, STONE_LIGHT)[k], bevel=False)
        b.box_base((x - 1.4 * sx, -1.1, 0), (1.0, 0.8, 0.6), STONE_DARK, bevel=False, rot=(0.5, "Z"))
        _rune(glow, x, -1.0, 4.2, k * 2, 1.2, 0.12)
        _moss(d, x + 0.3 * sx, -0.7, 0.0, 1.8, 1.0, k)
    b.box_base((0.15, 0, 8.0), (w + 3.6, 2.1, 1.6), STONE_LIGHT, bevel=False, rot=(0.03, "Z"))
    _moss(d, -2.0, 0.1, 9.6, 5.0, 1.6, 0)
    _moss(d, 4.4, 0.0, 9.6, 3.0, 1.4, 1)
    b.box((-3.4, -1.12, 6.6), (0.5, 0.14, 3.0), VINE, bevel=False)
    b.box((-2.8, -1.12, 7.2), (0.4, 0.14, 1.8), "leaf_green", bevel=False)
    return [b.finalize(N + "Trilithon", mat), glow.finalize(N + "Trilithon_Glow", mat),
            d.finalize(N + "Trilithon_Decor", mat)]


# --------------------------------------------------------------------------------------------- the pieces --
def brazier(mat):
    """A bronze brazier on a stone stand, its fire soft and glowing (_Glow, Neon day and night), no smoke."""
    b, glow = Builder(), Builder()
    b.box_base((0, 0, 0), (1.4, 1.4, 0.4), STONE_DARK, bevel=False)
    b.cyl_base((0, 0, 0.4), 0.35, 2.6, STONE, segments=8)
    b.cyl_base((0, 0, 3.0), 0.5, 0.8, "bronze", segments=12, radius2=1.05)
    b.cyl_base((0, 0, 3.8), 1.1, 0.15, GOLD, segments=12, bevel=False)
    glow.cyl_base((0, 0, 3.6), 0.85, 0.5, "fur_marmalade", segments=10, radius2=0.5)
    glow.cyl_base((0, 0, 4.1), 0.45, 0.5, "pastel_butter", segments=8, radius2=0.12)
    return [b.finalize(N + "Brazier", mat), glow.finalize(N + "Brazier_Glow", mat)]


def stone_urn(mat, h=2.4):
    """A stone urn standing (decor): a round belly, a neck and lip, a jade band."""
    b = Builder()
    b.cyl_base((0, 0, 0), 0.7, 0.3, STONE_DARK, segments=10)
    b.cyl_base((0, 0, 0.3), 0.9, h * 0.55, STONE_LIGHT, segments=12, radius2=1.05)
    b.cyl_base((0, 0, 0.3 + h * 0.55), 1.05, h * 0.25, STONE_LIGHT, segments=12, radius2=0.6)
    b.cyl_base((0, 0, 0.3 + h * 0.8), 0.75, 0.25, STONE, segments=12, bevel=False)
    b.cyl_base((0, 0, 0.3 + h * 0.4), 1.02, 0.16, JADE, segments=12, bevel=False)
    return [b.finalize(N + "Urn", mat)]


def rubble(mat, s_=1.0, k=0):
    """A small heap of broken blocks (#2834 remake): chipped blocks with moss on the top one and a fern tuft at the
    foot; with k a multiple of 3 a carved fragment lies by it, a stone cat's ear and eye (only the filler's heaps:
    it reaches past the heap, where the rescue and rubble spots sit). k picks the variant."""
    b, d = Builder(), Builder()
    for j, (x, y, w, dd, h, a) in enumerate(((0, 0, 1.6, 1.2, 0.9, 0.2), (1.2, 0.5, 1.1, 0.9, 0.7, 0.9),
                                             (-1.0, 0.6, 1.0, 1.0, 0.6, 0.4), (0.3, 0.2, 0.9, 0.8, 0.5, 1.3))):
        b.box_base((x * s_, y * s_, (0.85 if j == 3 else 0.0) * s_), (w * s_, dd * s_, h * s_),
                   (STONE, STONE_LIGHT, STONE, STONE_DARK)[j], bevel=False, rot=(a, "Z"))
    for j, (x, y, a) in enumerate(((-1.45, -0.3, 0.3), (1.5, 0.95, 1.1), (0.2, 0.95, 0.7))):     # chips, inside the heap's reach
        b.box_base((x * s_, y * s_, 0), (0.42 * s_, 0.36 * s_, 0.24 * s_ + 0.01 * j), STONE_LIGHT, bevel=False,
                   rot=(a, "Z"))
    _moss(d, 0.3 * s_, 0.2 * s_, 1.35 * s_, 0.9 * s_, 0.8 * s_, k)
    d.sphere((-1.4 * s_, 0.9 * s_, 0.2 * s_), 0.5, "fur_fern", segments=6, rings=3, scale=(0.9 * s_, 0.8 * s_, 0.5 * s_))
    if k % 3 == 0:                                                                # a carved fragment: an ear, an eye
        b.box_base((1.5 * s_, -1.0 * s_, 0), (1.3 * s_, 0.9 * s_, 0.8 * s_), STONE_LIGHT, bevel=False, rot=(0.5, "Z"))
        b.wedge((1.7 * s_, -0.95 * s_, 0.8 * s_ + 0.35 * s_), (0.7 * s_, 0.6 * s_, 0.7 * s_), STONE_LIGHT, bevel=False,
                rot=(0.5, "Z"))
        b.box((1.35 * s_, -1.47 * s_, 0.45 * s_), (0.5 * s_, 0.08, 0.3 * s_), STONE_DARK, bevel=False, rot=(0.5, "Z"))
    return [b.finalize(N + "Rubble", mat), d.finalize(N + "Rubble_Decor", mat)]


def trap_rubble_pile(mat):
    """A cat stuck in a rubble pile: broken blocks heaped round the spot to about 1.8, a gap at local -Z where its
    head shows, a fallen beam across the top."""
    b = Builder()
    for k in range(9):
        a = -PI / 2 + 2 * PI * (k + 0.5) / 10 + 0.3
        r = 1.9 + 0.2 * (k % 2)
        w, h = 1.4 + 0.3 * (k % 3), 1.2 + 0.5 * ((k * 2) % 3)
        b.box_base((r * math.cos(a), r * math.sin(a), 0), (w, 1.2, h), (STONE, STONE_LIGHT, SANDSTONE)[k % 3],
                   bevel=False, rot=(a + 0.2 * (k % 2), "Z"))
    b.box((0.2, 0.6, 1.9), (4.6, 0.8, 0.7), SANDSTONE, bevel=False, rot=Matrix.Rotation(0.25, 3, "Z") @
          Matrix.Rotation(0.15, 3, "Y"))
    for k in range(5):
        a = 2 * PI * k / 5 + 0.4
        b.box_base((3.3 * math.cos(a), 3.3 * math.sin(a), 0), (0.7, 0.6, 0.4), STONE_DARK, bevel=False, rot=(a, "Z"))
    return [b.finalize(N + "TrapRubble", mat)]


def trap_stone_urn(mat):
    """A cat stuck in a tall stone urn: the urn 2.9 high, its mouth 1.0 across at the top (where the cat's head
    shows), a crack down its side, a jade band, a lid lying beside it."""
    b = Builder()
    b.cyl_base((0, 0, 0), 1.0, 0.3, STONE_DARK, segments=12)
    b.cyl_base((0, 0, 0.3), 1.2, 1.5, STONE_LIGHT, segments=14, radius2=1.45)
    b.cyl_base((0, 0, 1.8), 1.45, 0.7, STONE_LIGHT, segments=14, radius2=0.95)
    b.ring((0, 0, 2.65), 1.1, 0.25, 0.4, STONE, segments=14)
    b.cyl_base((0, 0, 2.3), 0.86, 0.12, "fur_ink", segments=14, bevel=False)
    b.cyl_base((0, 0, 1.0), 1.36, 0.18, JADE, segments=14, bevel=False)
    b.box((-1.3, -0.5, 1.4), (0.06, 0.12, 1.4), STONE_DARK, bevel=False, rot=(0.6, "Z"))       # the crack
    b.cyl((1.9, -0.9, 0.2), 1.1, 0.3, STONE, segments=12, rot=(0.2, "Y"))                       # its lid
    return [b.finalize(N + "TrapUrn", mat)]


# ----------------------------------------------------------------------------- Broken Gate Camp (camps.py) --
def gate_pylon(mat, h=14.0, broken=1):
    """One pylon of the fallen temple gate the camp stands in: battered sandstone courses on a plinth, a jade band, a
    gold sun disc on its -Z face, its top broken off in steps (broken toward local -X 1 or +X -1)."""
    b = Builder()
    W, D = 7.0, 5.0
    b.box_base((0, 0, 0), (W + 1.0, D + 1.0, 1.0), STONE_DARK, bevel=False)
    n = 6
    for i in range(n):
        w = W - 0.25 * i
        b.box_base((0, 0, 1.0 + i * (h - 4.0) / n), (w, D - 0.15 * i, (h - 4.0) / n + 0.01),
                   (SANDSTONE, SANDSTONE_LIGHT)[i % 2], bevel=False)
    b.box((0, 0, h - 4.6), (W - 1.2, D - 0.6, 0.5), JADE, bevel=False)
    b.cyl((0, -(D - 0.9) / 2 - 0.02, 7.0), 1.6, 0.2, GOLD, segments=16, rot=(PI / 2, "X"))
    for k in range(3):                                                               # the broken top
        x = broken * (-(W - 1.5) / 2 + k * 1.7)
        b.box_base((x, 0, h - 3.0), (1.6, D - 1.0, 3.0 - 0.9 * k + 0.02 * k), SANDSTONE, bevel=False)
    b.box_base((-broken * 4.6, -1.2, 0), (2.0, 1.6, 1.2), SANDSTONE, bevel=False, rot=(0.4, "Z"))
    return [b.finalize(N + "GatePylon", mat)]


def fallen_lintel(mat, L=16.0):
    """The gate's lintel lying where it fell, broken in two, a jade band along it and a gold disc."""
    b = Builder()
    for k, (x, a) in enumerate(((-L / 4 - 0.3, 0.05), (L / 4 + 0.4, -0.12))):
        b.box_base((x, 0, 0), (L / 2 - 0.4, 3.2, 2.6 + 0.04 * k), SANDSTONE, bevel=False, rot=(a, "Z"))
        b.box((x, -1.62, 1.5), (L / 2 - 0.8, 0.1, 0.5), JADE, bevel=False, rot=(a, "Z"))
    b.cyl((-L / 4, 0, 2.66), 1.2, 0.12, GOLD, segments=14, bevel=False)
    b.box_base((L / 2 + 0.6, 1.0, 0), (1.4, 1.2, 0.9), STONE, bevel=False, rot=(0.6, "Z"))
    return [b.finalize(N + "FallenLintel", mat)]


# --------------------------------------------------------------------------------------------------- set --
def build_set(mat):
    s = Set(NAME)
    keep = []

    def put(fn, x, z, rot=0.0, r=4.0, y=0.0):
        keep.append((x, z, r))
        return s.put(fn, x, z, rot, y)

    _walls(s, mat)
    _bridge_bay(s, mat)
    _triumphal_arch(s, mat)
    _stylobate(s, mat)
    _pediment(s, mat, PEDIMENT_Z, ISLE_PED)
    _halls(s, mat)
    _court(s, mat)

    # Statue Avenue: the gargoyles, the lane walls, braziers
    for i, z in enumerate(range(-280, -170, 16)):
        for sx in (-1, 1):
            put(gargoyle(mat), sx * STATUE_X, z, 90 * sx, r=2.5)                 # facing the road
            _spot(s, "gargoyle_plinth", sx * (STATUE_X + 2.6), z + 1.0)
        if i % 2 == 0:
            for sx in (-1, 1):
                _spot(s, "avenue", sx * 18.0, z + 8.0)
    for sx in (-1, 1):
        for (z0, z1) in ((-286.0, -256.0), (-248.0, -218.0), (-210.0, -176.0)):
            put(lane_wall(mat, z1 - z0), sx * LANE_X, (z0 + z1) / 2, 0, r=0)
        put(brazier(mat), sx * (AVENUE_HALF + 1.5), -178.0, 0, r=2)
    for (x, z) in ((-50, -270), (48, -262), (-58, -236), (56, -224), (-46, -206), (52, -196), (-60, -184)):
        put(rubble(mat, 1.0 + 0.2 * ((x + z) % 3), 1 + (x + z) % 2), x, z, (x * 7) % 360, r=3)
        _spot(s, "rubble", x + 2.4, z - 1.6)
    for (x, z) in ((-44, -254), (44, -240), (-40, -190)):
        put(stone_urn(mat), x, z, 0, r=2)
        _spot(s, "urn", x + 1.8, z - 1.4)
    for (x, z, br) in ((-54, -222, True), (58, -276, False), (42, -210, True)):
        put(column(mat, 11.0, br), x, z, 0, r=2.5)
        _spot(s, "column_foot", x - 2.2, z - 2.2)

    # the Fallen Colonnade: the upper level's columns are in _stylobate; drums and broken columns below
    for (x, z) in ((-58, -110), (-46, -92), (-26, -68), (-58, -44), (-30, -28), (-14, -112)):
        _spot(s, "stylobate", x, z, y=STYLO_H)
    for (x, z, rot) in ((24, -132, 20), (44, -104, -40), (30, -86, 70), (22, -36, -10), (50, -32, 40)):
        put(drums(mat), x, z, rot, r=5)
        _spot(s, "drums", *turned(x, z, rot, 0, -2.2))
    for (x, z, br) in ((34, -118, False), (46, -84, True), (28, -10, True), (52, -10, False), (-4, -136, True)):
        put(column(mat, 12.0, br), x, z, 0, r=2.5)
        _spot(s, "column_foot", x + 2.2, z - 2.2)
    for (x, z) in ((40, -142), (24, -54), (36, 6)):
        _spot(s, "colonnade", x, z)
    for (x, z) in ((-46, -138), (24, -112), (-34, 8)):
        put(rubble(mat, 1.2, 1), x, z, (x * 11) % 360, r=3)
        _spot(s, "rubble", x + 2.4, z - 1.6)
    for (x, z) in ((-60, -6), (8, 12)):
        put(brazier(mat), x, z, 0, r=2)

    # before and in the Glyph Halls
    for (x, z) in ((-53.25, 50), (-27, 62), (0, 56), (27, 84), (53.25, 60), (-53.25, 140), (-27, 132), (27, 118),
                   (53.25, 160), (-27, 160), (0, 150), (27, 162), (-6, 92)):
        _spot(s, "glyph_hall", x, z)
    for (x, z) in ((-40, 28), (40, 26), (-20, 176), (24, 176)):
        put(stone_urn(mat, 2.0), x, z, 0, r=2)
        _spot(s, "urn", x + 1.8, z - 1.4)
    for (x, z) in ((-22, 30), (22, 32)):
        put(brazier(mat), x, z, 0, r=2)

    # the Golem Courtyard
    cx, cz = COURT
    for k in range(8):
        a = 2 * PI * (k + 0.5) / 8
        _spot(s, "court", cx + 18.0 * math.cos(a), cz + 18.0 * math.sin(a))
    for (r0, top) in RINGS[:2]:
        for a in (30.0, 150.0, 220.0, 320.0):
            rr = r0 + 2.0
            _spot(s, "court_step", cx + rr * math.cos(math.radians(a)), cz + rr * math.sin(math.radians(a)), y=top)
    _spot(s, "fountain", cx + 7.6, cz - 2.0)
    _spot(s, "throne", cx, THRONE_Z - 1.6, y=4.2)
    _spot(s, "throne_dais", cx - 7.0, THRONE_Z - 4.5, y=1.2)
    for sx in (-1, 1):
        put(brazier(mat), sx * 10.0, THRONE_Z - 8.0, 0, r=2)
        put(gargoyle(mat), sx * 50.0, 196.0, 0, r=2.5)
        _spot(s, "gargoyle_plinth", sx * 50.0 + 2.6, 197.0)
    for (x, z) in ((-56, 250), (58, 260), (-50, 214), (46, 286), (-20, 286)):
        _spot(s, "court_edge", x, z)

    # the five rescue spots (the ledge is _bridge_bay's) and the rest of the pool
    for (x, z, t) in RUBBLE + POOL_RUBBLE:
        put(trap_rubble_pile(mat), x, z, t, r=4)
        _spot(s, "trap_rubble_pile", x, z, turn=t)
    for (x, z, t) in URNS + POOL_URNS:
        put(trap_stone_urn(mat), x, z, t, r=4)
        _spot(s, "trap_stone_urn", x, z, turn=t)

    # #2834 landmarks: the colossus behind the throne, the waterfall by the east wall, a trilithon gate before the
    # court and rune stones leading the way through the colonnade. None of them moves a spot
    spots = [(p[0], p[2]) for lst in s.points.values() for p in lst]
    put(colossus(mat), 0.0, COLOSSUS_Z, 0, r=16)
    put(waterfall(mat), FALLS_X, FALLS_Z, 90, r=8)
    s.put(trilithon(mat), 0.0, GATE_Z, 0)
    keep.extend([(-6.4, GATE_Z, 2.0), (6.4, GATE_Z, 2.0)])
    stylo = [(STYLO[0], STYLO[1], STYLO[2], STYLO[3]), (-35.0, -25.0, STYLO[2] - 12.0, STYLO[2]),
             (STYLO[1], STYLO[1] + 12.0, -65.0, -55.0), (-55.0, -45.0, STYLO[3], STYLO[3] + 12.0),
             (ISLE_PED[0][0], ISLE_PED[0][1], PEDIMENT_Z - 4.0, PEDIMENT_Z + 4.0)]

    def free(x, z, r):
        if abs(x) > IN_X - 4 or near_trail(x, z) < 5.6 or abs(z - ARCH_Z) < 9:
            return False
        if any(x0 - 2 - r < x < x1 + 2 + r and z0 - 2 - r < z < z1 + 2 + r for (x0, x1, z0, z1) in stylo):
            return False
        if any(math.hypot(x - qx, z - qz) < qr + r + 1.5 for (qx, qz, qr) in keep):
            return False
        return all(math.hypot(x - qx, z - qz) >= r + 2.5 for (qx, qz) in spots)

    step, at, k, side = 17.0, 0.0, 0, 1
    for a, c in pairwise(TRAIL):
        seg = math.hypot(c[0] - a[0], c[1] - a[1])
        ux, uz = (c[0] - a[0]) / seg, (c[1] - a[1]) / seg
        while at <= seg:
            px, pz = a[0] + ux * at, a[1] + uz * at
            if ARCH_Z + 12 < pz < HALLS_Z0 - 6:
                for sd in (side, -side):
                    x, z = px + sd * 6.6 * uz, pz - sd * 6.6 * ux
                    if free(x, z, 1.6):
                        put(rune_stone(mat, k), x, z, face(x, z, px, pz), r=1.6)
                        k += 1
                        side = -sd
                        break
            at += step
        at -= seg

    # filler: rubble and broken drums, clear of the way, the blockers, the pieces and the spots
    k = 0
    for gx in range(-58, 59, 14):
        for gz in range(-286, 287, 14):
            k += 1
            x = gx + 4.0 * math.sin(k * 2.71)
            z = gz + 4.0 * math.cos(k * 1.93)
            if z < -150 and abs(x) < AVENUE_HALF + 6:
                continue
            if near_trail(x, z) < 8.0 or abs(z - ARCH_Z) < 9 or abs(z - PEDIMENT_Z) < 9:
                continue
            if HALLS_Z0 - 4 < z < HALLS_Z1 + 4:
                continue
            if STYLO[0] - 8 < x < STYLO[1] + 8 and STYLO[2] - 8 < z < STYLO[3] + 8:
                continue
            if math.hypot(x - cx, z - cz) < RINGS[-1][0] + 8 or z > THRONE_Z - 10 and abs(x) < 14:
                continue
            if x > PARAPET_X - 8 and BAY_Z0 - 6 < z < BAY_Z1 + 6:
                continue
            if any(math.hypot(x - qx, z - qz) < qr + 4.0 for (qx, qz, qr) in keep):
                continue
            if any(math.hypot(x - qx, z - qz) < 6.0 for (qx, qz) in spots):
                continue
            if k % 2 == 0:
                s.put(rubble(mat, 0.8 + 0.2 * (k % 3), k // 2), x, z, (k * 37) % 360)
    return s.finish(_ground(), mat), s


def build_ruins_set(mat):
    objs, _ = build_set(mat)
    return objs


ASSETS = {
    NAME: (build_ruins_set, 150000),
}
