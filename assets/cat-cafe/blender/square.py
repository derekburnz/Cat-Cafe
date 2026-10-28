"""The Town Square set for town layout v3.1 (docs/design/cat-cafe/town-layout-v3.md sections 3 and 7, F76 and F77).
Derek, 2026-10-28 00:47: "fountain in middle of map needs some finishing"; 00:48: "the default looking roblox texture
pavement in the middle isn't a good look find something to design the paths to the sides and middle of map a bit
better". The square is x -48 to 48, z -32 to 32 around the origin, so square space is world space, with a cross of
open paving (the street's line x -8 to 8 and the lane z -6 to 6) that nothing stands on. Laid out in Roblox axes
through common.RB, front -Z, sizes in studs. PLACEMENTS below is the table for Layout.townSquare.props; every pivot
goes on the square's floor top (y 0.1) unless the table says otherwise.

  CatCafe_Square_Paving     the whole floor, pivot at (0, 0.1, 0): a 0.4 thick grout slab that players stand on
                            (top at the pivot) and 0.02 thick stones on it. The quarters are sand and tan tiles in a
                            checker, the cross is light pavers in running bond edged with brick kerbs, a brick border
                            runs round the square, and the cross carries on as paths through both gardens to the side
                            arches and across both back alleys to the Woods and Sewer gates. Round the fountain a
                            compass: a cream medallion in a brick ring with a point down each arm in its area's colour
                            (Neighbourhood north, Park south, Woods west, Sewer east) and four short brick diagonals.
  CatCafe_Square_Fountain   radius 6.5 at its step, the landmark at (0, 0): a cream basin with a teal tile band, a rim
                            (1.85 high) to sit on with a paw in each area's colour on its coping, four brass fish on
                            the diagonals spouting into the pool, lily pads and wishing coins, a pedestal bowl that
                            spills a veil of water, and a brass cat on top waving south at the spawn. _Water parts are
                            Glass and do not collide.
  CatCafe_Square_Signpost   the finger signpost at (-9, -7.5), placed with no turn: its four arms are aimed in world
                            space at the Park, Neighbourhood, Woods and Sewer gates. Each arm is one blank board (the
                            UI draws its name, icon and lock), long along its own X, with an `Area` attribute; tips
                            and caps are separate plain parts.
  CatCafe_Square_ArchAlley  the alley arch, 12 wide, for the side openings into the back alleys: THE ALLEYWAY on the
                            -Z face (the square side), TOWN SQUARE on the alley side.
  CatCafe_Square_SignArch   the town's sign over the street at each end of the square: a 36 opening, CAT CAFE and
                            TOWN SQUARE on the -Z face (the street side), CAFE STREET on the +Z face (the square side).
  CatCafe_Square_Bench      4 studs long, teal slats on a black iron frame, seat at 1.35, front -Z.
  CatCafe_Square_Lamp       an 11 stud post with two lanterns (_Bulb) and a brass hook ring at 9.6 for the bunting.
  CatCafe_Square_Bunting    22 studs of pennants on a line that sags from 9.6 at its ends to 8.6 in the middle; pivot
                            on the ground under the middle of the span, its ends inside two lamp posts.
  CatCafe_Square_Garden     a 22 x 12 raised bed for the gardens between the square and the back alleys: brick kerb,
                            grass, two trees, a hedge along the back (+Z), flowers along the front, a topiary cat.

Pivots are at the base centre except where noted.
"""

import math

from alleyway import _arch, flower_clump, label, lantern
from common import RB
from plot import rot_x, rot_y, rot_z

SQ_W, SQ_D = 48.0, 32.0                        # the square's half width (x) and half depth (z)
LANE, CROSS = 8.0, 6.0                         # half widths of the street's line and the east to west lane
GARDEN_X, ALLEY_X, GATE_X = 62.9, 63.6, 92.8   # the garden path ends under the arch, the crossing starts past the
#                                                safe zone stripe (x 63.05 to 63.55) and stops at the gate's wall
BORDER, KERB = 2.0, 0.6
TILE_X, TILE_Z, JOINT = 3.8, 4.0, 0.14
PAVER_L, PAVER_W = 3.7, 2.0                    # across the walk, along the walk
STONE = 0.02                                   # stones on the slab: 0 to 0.02 above the pivot (world 0.1 to 0.12)
MED_R = 11.6                                   # the compass medallion's brick ring
POINT_TIP = 13.6                               # paw paths start past this (Layout.pawPrints, PAW_START 14.5)
AREA_POINTS = (("paw_neighbourhood", 0, 1), ("paw_park", 0, -1), ("paw_woods", -1, 0), ("paw_sewer", 1, 0))
FOUNTAIN_R = 6.5                               # its step

RING_R = 17.0                                  # bench ring radius
BENCH_ANGLES = (35, 55)                        # degrees from +X in each quarter, clear of the cross
LAMP_AT = 11.0                                 # lamps at (+-11, +-11)
HOOK_Y = 9.6                                   # where the bunting ties on
SAG = 1.0
FLAGS = ("blush", "sign_teal", "pastel_butter", "mint", "nose_pink", "pastel_sky")
SIGNPOST_AT = (-9.0, -7.5)
GATES = {"park": (0.0, -125.0), "neighbourhood": (0.0, 125.0), "woods": (-94.0, 0.0), "sewer": (94.0, 0.0)}


def flat_tri(b, pts, y0, y1, swatch):
    """A flat triangle lying on the ground between heights y0 and y1, points as Roblox (x, z)."""
    q = [(-x, z) for x, z in pts]                                    # Roblox (x, z) is Blender (-x, y)
    b.b.fan(RB.p(0, (y0 + y1) / 2, 0), q[0], q[1:], y1 - y0, swatch)


def _ring(b, y0, y1, r_out, width, swatch, segments=32):
    """A flat ring round the origin from boxes; every other one stands 0.01 proud top and bottom, so neighbours
    never share a face where they overlap."""
    rm = r_out - width / 2
    chord = 2 * r_out * math.sin(math.pi / segments) * 1.04
    for k in range(segments):
        a = 2 * math.pi * (k + 0.5) / segments
        e = 0.01 if k % 2 else 0.0
        b.box((rm * math.cos(a), (y0 + y1) / 2, rm * math.sin(a)), (width, y1 - y0 + 2 * e, chord), swatch,
              rot=rot_y(-math.degrees(a)))


def _hash(*v):
    h = 0
    for x in v:
        h = (h * 131 + int(round(x * 10)) * 7919 + 17) % 1000003
    return h


# ------------------------------------------------------------------------------------------------- paving --
def _tiles(b, x0, x1, z0, z1):
    """Checker tiles over a rect, a JOINT of grout between them."""
    nx, nz = round((x1 - x0) / TILE_X), round((z1 - z0) / TILE_Z)
    tx, tz = (x1 - x0) / nx, (z1 - z0) / nz
    for i in range(nx):
        for k in range(nz):
            xa, za = x0 + i * tx, z0 + k * tz
            cx, cz = xa + tx / 2, za + tz / 2
            if math.hypot(abs(cx) - tx / 2 if abs(cx) > tx / 2 else 0, abs(cz) - tz / 2 if abs(cz) > tz / 2 else 0) \
                    > MED_R or max(math.hypot(xa + dx, za + dz) for dx in (0, tx) for dz in (0, tz)) > MED_R:
                sw = "paving_sand" if (i + k + round(x0 / tx) + round(z0 / tz)) % 2 == 0 else "paving_tan"
                h = JOINT / 2
                b.span((xa + h, 0, za + h), (xa + tx - h, STONE, za + tz - h), sw)


def _pavers(b, x0, x1, z0, z1, along):
    """Running bond pavers over a rect, rows across the walk; `along` is the walking axis ("x" or "z")."""
    a0, a1, c0, c1 = (x0, x1, z0, z1) if along == "x" else (z0, z1, x0, x1)
    rows = max(1, round((a1 - a0) / PAVER_W))
    rw = (a1 - a0) / rows
    n = max(1, round((c1 - c0) / PAVER_L))
    cl = (c1 - c0) / n
    h = JOINT / 2
    for r in range(rows):
        ra = a0 + r * rw
        cuts = [c0 + cl * k for k in range(n + 1)]
        if r % 2:
            cuts = [c0] + [c0 + cl * (k + 0.5) for k in range(n)] + [c1]
        for p, (ca, cb) in enumerate(zip(cuts, cuts[1:])):
            mid_a, mid_c = ra + rw / 2, (ca + cb) / 2
            mx, mz = (mid_a, mid_c) if along == "x" else (mid_c, mid_a)
            corners = [(xx, zz) for xx in ((ra, ra + rw) if along == "x" else (ca, cb))
                       for zz in ((ca, cb) if along == "x" else (ra, ra + rw))]
            if max(math.hypot(xx, zz) for xx, zz in corners) < MED_R - 0.2:
                continue                                                 # under the medallion
            sw = "floor_tile" if _hash(mx, mz) % 6 == 0 else "paving_light"
            lo_a, hi_a, lo_c, hi_c = ra + h, ra + rw - h, ca + h, cb - h
            if along == "x":
                b.span((lo_a, 0, lo_c), (hi_a, STONE, hi_c), sw)
            else:
                b.span((lo_c, 0, lo_a), (hi_c, STONE, hi_a), sw)


def _kerbs(b, x0, x1, z0, z1, along):
    """Brick kerbs along both long edges of a walk."""
    if along == "x":
        b.span((x0, 0, z0), (x1, STONE, z0 + KERB), "terracotta")
        b.span((x0, 0, z1 - KERB), (x1, STONE, z1), "terracotta")
    else:
        b.span((x0, 0, z0), (x0 + KERB, STONE, z1), "terracotta")
        b.span((x1 - KERB, 0, z0), (x1, STONE, z1), "terracotta")


def _walk(b, x0, x1, z0, z1, along):
    if along == "x":
        _kerbs(b, x0, x1, z0, z1, "x")
        _pavers(b, x0, x1, z0 + KERB, z1 - KERB, "x")
    else:
        _kerbs(b, x0, x1, z0, z1, "z")
        _pavers(b, x0 + KERB, x1 - KERB, z0, z1, "z")


def _border(b):
    """Brick band round the square in 4 stud blocks."""
    ix, iz = SQ_W - BORDER, SQ_D - BORDER
    h = JOINT / 2
    for z0, z1 in ((-SQ_D, -iz), (iz, SQ_D)):                                   # the north and south runs, full width
        n = round(2 * SQ_W / 4)
        w = 2 * SQ_W / n
        for k in range(n):
            b.span((-SQ_W + k * w + h, 0, z0 + h), (-SQ_W + (k + 1) * w - h, STONE, z1 - h), "terracotta")
    for x0, x1 in ((-SQ_W, -ix), (ix, SQ_W)):                                   # east and west, between them
        n = round(2 * iz / 4)
        w = 2 * iz / n
        for k in range(n):
            b.span((x0 + h, 0, -iz + k * w + h), (x1 - h, STONE, -iz + (k + 1) * w - h), "terracotta")


def _compass(b):
    """The medallion round the fountain: brick ring, cream disc, the four area points and four brick diagonals."""
    b.cyl((0, STONE + 0.01, 0), MED_R, 0.02, "terracotta", segments=40)          # 0.02 to 0.04
    b.cyl((0, STONE + 0.03, 0), MED_R - 0.6, 0.02, "cream", segments=40)         # 0.04 to 0.06
    _ring(b, STONE + 0.04, STONE + 0.055, FOUNTAIN_R + 1.3, 1.1, "terracotta", segments=36)   # round the step
    y0, y1 = STONE + 0.04, STONE + 0.055
    r_in, r_mid, half_w = FOUNTAIN_R + 1.35, FOUNTAIN_R + 2.6, 1.7
    for sw, ux, uz in AREA_POINTS:                                               # a kite down each arm
        vx, vz = -uz, ux
        inner = (ux * r_in, uz * r_in)
        tip = (ux * POINT_TIP, uz * POINT_TIP)
        left = (ux * r_mid + vx * half_w, uz * r_mid + vz * half_w)
        right = (ux * r_mid - vx * half_w, uz * r_mid - vz * half_w)
        flat_tri(b, [inner, left, tip], y0, y1, sw)
        flat_tri(b, [inner, tip, right], y0, y1, sw)
        # a cream spine down the middle so the point reads as a compass needle
        L = POINT_TIP - r_mid - 0.6
        c = r_mid + 0.3 + L / 2
        b.box((ux * c, y1 + 0.004, uz * c), (0.22 if ux == 0 else L, 0.008, L if ux == 0 else 0.22), "offwhite")
    for k in range(4):                                                           # the diagonals, shorter, in brick
        a = math.radians(45 + 90 * k)
        ux, uz = math.cos(a), math.sin(a)
        vx, vz = -uz, ux
        tip = (ux * (MED_R - 1.4), uz * (MED_R - 1.4))
        inner = (ux * r_in, uz * r_in)
        rm = r_in + 1.0
        left = (ux * rm + vx * 0.9, uz * rm + vz * 0.9)
        right = (ux * rm - vx * 0.9, uz * rm - vz * 0.9)
        flat_tri(b, [inner, left, tip], y0, y1, "terracotta")
        flat_tri(b, [inner, tip, right], y0, y1, "terracotta")


def build_paving(mat):
    b, slab = RB(), RB()
    slab.span((-SQ_W, -0.4, -SQ_D), (SQ_W, 0, SQ_D), "paving_grout")               # players stand on its top
    for s in (-1, 1):                                                             # under the garden paths
        x0, x1 = sorted((s * SQ_W, s * GARDEN_X))
        slab.span((x0, -0.4, -CROSS), (x1, 0, CROSS), "paving_grout")
    _border(b)
    ix, iz = SQ_W - BORDER, SQ_D - BORDER
    for sx in (-1, 1):                                                            # the quarters
        for sz in (-1, 1):
            x0, x1 = sorted((sx * LANE, sx * ix))
            z0, z1 = sorted((sz * CROSS, sz * iz))
            _tiles(b, x0, x1, z0, z1)
    _kerbs(b, -LANE, LANE, -iz, -CROSS, "z")                                       # the street's line, kerbs
    _kerbs(b, -LANE, LANE, CROSS, iz, "z")                                         # either side of the lane
    _pavers(b, -LANE + KERB, LANE - KERB, -iz, iz, "z")                            # and pavers right through
    for s in (-1, 1):
        x0, x1 = sorted((s * LANE, s * ix))
        _walk(b, x0, x1, -CROSS, CROSS, "x")                                       # the lane in the square
        x0, x1 = sorted((s * SQ_W, s * GARDEN_X))
        _walk(b, x0, x1, -CROSS, CROSS, "x")                                       # through the garden
        x0, x1 = sorted((s * ALLEY_X, s * GATE_X))
        _walk(b, x0, x1, -CROSS, CROSS, "x")                                       # across the back alley
    _compass(b)
    return [b.finalize("CatCafe_Square_Paving", mat), slab.finalize("CatCafe_Square_Paving_Slab", mat)]


# ------------------------------------------------------------------------------------------------ fountain --
def _paw(b, x, y, z, s, swatch, toward=(0, -1)):
    """A flat paw print (pad and four toes) on a surface at height y, toes toward `toward` (Roblox x, z)."""
    ux, uz = toward
    vx, vz = -uz, ux
    b.cyl((x, y + 0.01, z), 0.5 * s, 0.02, swatch, segments=14)
    for side, fwd in ((-0.55, 0.5), (-0.2, 0.78), (0.2, 0.78), (0.55, 0.5)):
        b.cyl((x + (ux * fwd + vx * side) * s, y + 0.01, z + (uz * fwd + vz * side) * s), 0.19 * s, 0.02, swatch,
              segments=10)


def _fish(b, x, z, a, y):
    """A brass fish standing on its tail fin on the coping at angle a (radians), its mouth toward the centre."""
    ux, uz = -math.cos(a), -math.sin(a)                                          # toward the middle
    deg = math.degrees(math.atan2(-uz, ux))                                      # its local +X to the middle
    b.box((x - ux * 0.15, y + 0.12, z - uz * 0.15), (1.0, 0.24, 0.7), "brass", rot=rot_y(deg))      # base
    b.b.ico(RB.p(x, y + 0.75, z), 0.42, "brass", scale=(1.35, 0.75, 1.0), rot=RB._rot(rot_y(deg)))   # body
    b.box((x - ux * 0.62, y + 0.62, z - uz * 0.62), (0.5, 0.62, 0.12), "gold_dark",
          rot=rot_y(deg) @ rot_z(35))                                             # tail fin
    b.ball((x + ux * 0.5, y + 0.86, z + uz * 0.5), 0.15, "bronze")               # mouth
    for s in (-1, 1):                                                             # eyes either side
        b.ball((x + ux * 0.28 + uz * s * 0.22, y + 0.95, z + uz * 0.28 - ux * s * 0.22), 0.09, "fur_black")


def _spout(water, x, z, a, y):
    """An arc of water from a fish's mouth into the pool."""
    ux, uz = -math.cos(a), -math.sin(a)
    x0, y0 = 0.0, y + 0.86
    pts = []
    for k in range(7):
        t = k / 6
        d = 0.6 + 2.0 * t                                                         # out from the fish
        h = y0 + 0.9 * t - 2.3 * t * t                                            # up a little, then down
        pts.append((x + ux * d, h, z + uz * d))
    for p0, p1 in zip(pts, pts[1:]):
        c = tuple((p + q) / 2 for p, q in zip(p0, p1))
        dx, dy, dz = (q - p for p, q in zip(p0, p1))
        L = math.sqrt(dx * dx + dy * dy + dz * dz) + 0.08
        yaw = math.degrees(math.atan2(-dz, dx))
        pitch = math.degrees(math.atan2(dy, math.hypot(dx, dz)))
        water.box(c, (L, 0.22, 0.22), "fish_blue", rot=rot_y(yaw) @ rot_z(pitch))
    del x0


def _statue(b, scarf, y):
    """Brass cat sitting on (0, y, 0), looking -Z (south, at the spawn), its right paw raised in a wave."""
    m = "brass"
    b.ball((0, y + 1.0, 0.25), 1.05, m, scale=(0.95, 1.05, 1.0))                # body
    b.ball((0, y + 0.55, 0.15), 1.15, m, scale=(1.0, 0.55, 1.05))               # haunches
    b.ball((0, y + 1.25, -0.55), 0.72, m, scale=(0.95, 1.1, 0.7))               # chest
    b.span((-0.55, y, -0.95), (-0.15, y + 1.05, -0.55), m)                      # left front leg
    b.ball((-0.35, y + 0.12, -0.95), 0.24, m, scale=(1.0, 0.6, 1.2))            # its paw
    b.span((0.25, y + 1.55, -0.85), (0.6, y + 2.25, -0.55), m, rot=rot_z(-20))  # right arm up
    b.ball((0.62, y + 2.42, -0.72), 0.3, m)                                       # the waving paw
    b.ball((0.62, y + 2.48, -0.95), 0.12, "gold_dark")                           # its pad
    b.ball((1.05, y + 0.25, 0.25), 0.26, m, scale=(1.0, 1.0, 3.2))              # tail along the side
    b.ball((0.8, y + 0.32, -0.6), 0.25, m)                                        # its tip curled forward
    hy = y + 2.55
    b.ball((0, hy, -0.35), 0.82, m, scale=(1.08, 0.92, 0.9))                     # head
    for s in (-1, 1):
        b.box((s * 0.5, hy + 0.72, -0.3), (0.5, 0.5, 0.3), m, rot=rot_z(45))     # ears
        b.box((s * 0.5, hy + 0.7, -0.46), (0.28, 0.28, 0.04), "gold_dark", rot=rot_z(45))   # inner ears
        b.span((s * 0.3 - 0.09, hy + 0.05, -1.08), (s * 0.3 + 0.09, hy + 0.3, -0.94), "fur_black")   # eyes
        for dy in (-0.12, 0.0):                                                   # whiskers
            b.span((s * 0.55 - 0.2, hy - 0.1 + dy, -0.96), (s * 0.55 + 0.2, hy - 0.06 + dy, -0.86), "bronze")
    b.span((-0.09, hy - 0.12, -1.07), (0.09, hy - 0.02, -0.94), "nose_pink")     # nose
    for k, x in enumerate((-0.2, -0.07, 0.07, 0.2)):                             # W mouth
        lo = hy - (0.3 if k in (0, 2) else 0.24)
        b.span((x - 0.06, lo, -1.04 - 0.002 * k), (x + 0.06, lo + 0.08, -0.98), "bronze")
    scarf.cyl((0, y + 1.86, -0.32), 0.66, 0.24, "sign_teal", segments=14)        # teal scarf round the neck
    scarf.box((-0.38, y + 1.5, -0.85), (0.32, 0.55, 0.1), "sign_teal", rot=rot_z(12))   # its loose end


def build_fountain(mat):
    b, water, scarf = RB(), RB(), RB()
    _ring(b, 0.0, 0.35, FOUNTAIN_R, 0.6, "terracotta", segments=36)              # step round the basin
    b.cyl((0, 0.225, 0), 4.95, 0.45, "pastel_sky", segments=32)                  # pool floor, solid
    _ring(b, 0.0, 1.55, 5.9, 1.0, "floor_tile", segments=32)                     # the basin wall
    _ring(b, 0.62, 1.22, 5.96, 0.08, "sign_teal", segments=32)                   # tile band on its face
    for k in range(16):                                                          # white diamonds on the band
        a = 2 * math.pi * (k + 0.5) / 16
        b.box((5.97 * math.cos(a), 0.92, 5.97 * math.sin(a)), (0.06, 0.3, 0.3), "offwhite",
              rot=rot_y(-math.degrees(a)) @ rot_x(45))
    _ring(b, 1.55, 1.85, 6.1, 1.4, "offwhite", segments=32)                      # coping, a ledge to sit on
    for sw, ux, uz in AREA_POINTS:                                               # a paw in each area's colour
        r = 5.4
        _paw(b, ux * r, 1.85, uz * r, 0.62, sw, toward=(ux, uz))
    for k in range(4):                                                           # brass fish on the diagonals
        a = math.radians(45 + 90 * k)
        x, z = 5.4 * math.cos(a), 5.4 * math.sin(a)
        _fish(b, x, z, a, 1.85)
        _spout(water, x, z, a, 1.85)
    for (x, z) in ((1.6, -2.1), (-2.4, 0.9), (0.7, 2.8), (-1.1, -3.2), (3.1, 1.2), (-3.3, -1.6)):   # wishes
        b.cyl((x, 0.47, z), 0.25, 0.05, "rarity_legend", segments=8)
    water.cyl((0, 0.825, 0), 4.95, 0.75, "fish_blue", segments=32)               # pool, edge inside the wall
    for (x, z, r) in ((-3.0, 2.6, 0.7), (3.4, -1.9, 0.6), (2.2, 3.1, 0.5)):      # lily pads on the water
        b.cyl((x, 1.225, z), r, 0.05, "leaf_green", segments=12)
        b.span((x - 0.14, 1.25, z - 0.14), (x + 0.14, 1.45, z + 0.14), "blush")
    b.cyl((0, 1.75, 0), 1.0, 2.5, "floor_tile", segments=16)                     # pedestal
    b.cyl((0, 1.6, 0), 1.08, 0.4, "sign_teal", segments=16)                      # its band
    b.cyl((0, 3.3, 0), 1.0, 0.6, "floor_tile", r2=2.6, segments=20)              # bowl
    _ring(b, 3.6, 3.9, 2.9, 0.4, "offwhite", segments=24)                        # bowl lip, the veil hangs off it
    water.cyl((0, 3.66, 0), 2.45, 0.2, "fish_blue", segments=20)                 # bowl water
    n = 28                                                                       # a veil over the lip, its
    chord = 2 * 2.95 * math.sin(math.pi / n) * 1.04                              # strips overlapping into a sheet
    for k in range(n):
        a = 2 * math.pi * (k + 0.5) / n
        r = 2.9 + (0.01 if k % 2 else 0.0)
        water.box((r * math.cos(a), 2.55, r * math.sin(a)), (0.08, 2.6, chord), "fish_blue",
                  rot=rot_y(-math.degrees(a)))
    b.cyl((0, 4.05, 0), 0.85, 0.5, "floor_tile", segments=14)                    # statue plinth
    b.cyl((0, 4.32, 0), 0.95, 0.06, "sign_teal", segments=14)
    _statue(b, scarf, 4.35)
    return [b.finalize("CatCafe_Square_Fountain", mat), water.finalize("CatCafe_Square_Fountain_Water", mat),
            scarf.finalize("CatCafe_Square_Fountain_Decor", mat)]


# ----------------------------------------------------------------------------------------------- signpost --
ARM_LEN, ARM_H, ARM_T = 4.6, 0.72, 0.18
ARM_ORDER = ("neighbourhood", "park", "woods", "sewer")         # top to bottom
ARM_TOP = 7.45
POST = 0.62


def arm_frames():
    """(area, centre (x, y, z), yaw degrees) for each arm in the signpost's space (world, less SIGNPOST_AT)."""
    out = []
    for k, area in enumerate(ARM_ORDER):
        gx, gz = GATES[area]
        dx, dz = gx - SIGNPOST_AT[0], gz - SIGNPOST_AT[1]
        d = math.hypot(dx, dz)
        ux, uz = dx / d, dz / d
        r = POST / 2 + 0.12 + ARM_LEN / 2
        y = ARM_TOP - ARM_H / 2 - k * (ARM_H + 0.1)
        out.append((area, (ux * r, y, uz * r), math.degrees(math.atan2(-uz, ux))))
    return out


def build_signpost(mat):
    b, arms = RB(), {}
    h = POST / 2
    b.cyl((0, 0.15, 0), 1.1, 0.3, "concrete", segments=16)                        # footing
    b.cyl((0, 0.55, 0), 0.85, 0.5, "terracotta", r2=0.95, segments=14)            # planter ring
    flowers = RB()
    flowers.cyl((0, 0.82, 0), 0.82, 0.05, "leaf_green", segments=14)
    for k in range(5):
        a = 2 * math.pi * (k + 0.3) / 5
        flower_clump(flowers, 0.58 * math.cos(a), 0.82, 0.58 * math.sin(a), n=3, spread=0.2)
    b.span((-h, 0.3, -h), (h, 8.0, h), "caramel_wood")                           # post
    for y in (2.0, 3.2):                                                          # iron bands
        b.span((-h - 0.03, y, -h - 0.03), (h + 0.03, y + 0.12, h + 0.03), "fur_black")
    b.span((-h - 0.1, 8.0, -h - 0.1), (h + 0.1, 8.2, h + 0.1), "dark_wood")        # cap
    hy = 8.75                                                                     # a little cat head on top
    b.ball((0, hy, 0), 0.6, "fur_ginger", scale=(1.1, 0.9, 0.95))
    for s in (-1, 1):
        b.box((s * 0.4, hy + 0.5, 0), (0.36, 0.36, 0.24), "fur_ginger", rot=rot_z(45))
        b.box((s * 0.4, hy + 0.48, -0.1), (0.2, 0.2, 0.06), "nose_pink", rot=rot_z(45))
        b.span((s * 0.22 - 0.06, hy + 0.02, -0.57), (s * 0.22 + 0.06, hy + 0.2, -0.42), "fur_black")
    b.span((-0.07, hy - 0.1, -0.58), (0.07, hy - 0.02, -0.5), "nose_pink")
    for k, x in enumerate((-0.15, -0.05, 0.05, 0.15)):
        lo = hy - (0.25 if k in (0, 2) else 0.2)
        b.span((x - 0.045, lo, -0.56 - 0.002 * k), (x + 0.045, lo + 0.06, -0.5), "fur_black")
    tips = RB()
    for area, (x, y, z), yaw in arm_frames():
        arm = RB()
        R = rot_y(yaw)
        arm.box((x, y, z), (ARM_LEN, ARM_H, ARM_T), "cream", rot=R)                # the board the UI draws on
        ux, uz = math.cos(math.radians(yaw)), -math.sin(math.radians(yaw))
        e = ARM_LEN / 2
        tx, tz = x + ux * (e + 0.25), z + uz * (e + 0.25)                         # pointed tip at the gate end
        tips.box((tx, y, tz), (0.5, ARM_H * 0.71, ARM_T * 0.9), "dark_wood", rot=R @ rot_z(45))
        for dy in (-1, 1):                                                         # dark trim top and bottom
            tips.box((x, y + dy * (ARM_H / 2 + 0.035), z), (ARM_LEN, 0.07, ARM_T + 0.04), "dark_wood", rot=R)
        bx, bz = ux * (h + 0.06), uz * (h + 0.06)                                 # bracket on the post
        tips.box((bx, y, bz), (0.12, ARM_H + 0.2, ARM_T + 0.16), "fur_black", rot=R)
        arms[area] = arm
    out = [b.finalize("CatCafe_Square_Signpost", mat), flowers.finalize("CatCafe_Square_Signpost_Flowers", mat),
           tips.finalize("CatCafe_Square_Signpost_ArmCap", mat)]
    for area in ARM_ORDER:
        out.append(arms[area].finalize("CatCafe_Square_Signpost_Arm" + area.capitalize(), mat))
    return out


ARM_ATTRIBUTES = {"_Arm" + a.capitalize(): {"Area": a} for a in ARM_ORDER}


# -------------------------------------------------------------------------------------------------- bench --
def build_bench(mat):
    b = RB()
    for s in (-1, 1):                                                                          # iron ends
        x = s * 1.8
        b.span((x - 0.12, 0, -0.6), (x + 0.12, 0.2, 0.75), "fur_black")                       # foot
        b.span((x - 0.1, 0.2, -0.45), (x + 0.1, 1.2, -0.25), "fur_black")                      # front leg
        b.span((x - 0.1, 0.2, 0.45), (x + 0.1, 2.8, 0.65), "fur_black")                        # back leg and post
        b.span((x - 0.11, 1.2, -0.55), (x + 0.11, 1.31, 0.45), "fur_black")                    # seat rail
        b.span((x - 0.1, 1.75, -0.5), (x + 0.1, 1.9, 0.45), "fur_black")                       # arm
        b.span((x - 0.08, 1.35, -0.48), (x + 0.08, 1.75, -0.36), "fur_black")                  # arm post
    for k, z in enumerate((-0.42, -0.14, 0.14, 0.42)):                                         # seat slats
        b.span((-2.0, 1.3, z - 0.12), (2.0, 1.4 + 0.004 * k, z + 0.12), "sign_teal")
    for y in (1.75, 2.15, 2.55):                                                               # back slats
        b.span((-2.0, y, 0.63), (2.0, y + 0.28, 0.77), "sign_teal")
    return [b.finalize("CatCafe_Square_Bench", mat)]


# --------------------------------------------------------------------------------------------------- lamp --
def build_lamp(mat):
    b, lamps = RB(), RB()
    b.cyl((0, 0.35, 0), 0.6, 0.7, "fur_black", r2=0.45, segments=12)                           # base
    b.cyl((0, 5.65, 0), 0.22, 9.9, "fur_black", r2=0.17, segments=10)                          # shaft
    for y, r in ((3.0, 0.32), (7.0, 0.3)):                                                     # collars
        b.cyl((0, y, 0), r, 0.25, "fur_black", segments=10)
    b.cyl((0, HOOK_Y, 0), 0.4, 0.3, "brass", segments=12)                                      # bunting hook ring
    b.span((-1.7, 10.4, -0.1), (1.7, 10.6, 0.1), "fur_black")                                  # cross arm
    for s in (-1, 1):
        b.span((s * 1.5 - 0.08, 9.8, -0.08), (s * 1.5 + 0.08, 10.4, 0.08), "fur_black")       # arm brace
        lantern(b, lamps, s * 1.45, 10.6, 0, 0.75)
    b.ball((0, 10.88, 0), 0.32, "brass")                                                       # finial
    b.cyl((0, 6.0, 0), 0.75, 0.55, "terracotta", r2=0.95, segments=12)                         # flower ring
    flowers = RB()
    flowers.cyl((0, 6.31, 0), 0.85, 0.08, "leaf_green", segments=12)
    for k in range(5):
        a = 2 * math.pi * k / 5
        flower_clump(flowers, 0.6 * math.cos(a), 6.35, 0.6 * math.sin(a), n=3, spread=0.2)
    return [b.finalize("CatCafe_Square_Lamp", mat), lamps.finalize("CatCafe_Square_Lamp_Bulb", mat),
            flowers.finalize("CatCafe_Square_Lamp_Flowers", mat)]


# ------------------------------------------------------------------------------------------------ bunting --
def _line_y(x, half):
    return HOOK_Y - SAG * (1 - (x / half) ** 2)


def build_bunting(mat, span=2 * LAMP_AT):
    b, flags = RB(), RB()
    half = span / 2
    n = 12
    xs = [-half + span * k / n for k in range(n + 1)]
    for x0, x1 in zip(xs, xs[1:]):                                                             # the line
        y0, y1 = _line_y(x0, half), _line_y(x1, half)
        length = math.hypot(x1 - x0, y1 - y0) + 0.05
        ang = math.degrees(math.atan2(y1 - y0, x1 - x0))
        b.box(((x0 + x1) / 2, (y0 + y1) / 2, 0), (length, 0.07, 0.07), "dark_wood", rot=rot_z(ang))
    count = 16
    step = (span - 2.6) / (count - 1)
    for k in range(count):
        x = -half + 1.3 + k * step
        xl, xr = x - 0.42, x + 0.42
        yl, yr = _line_y(xl, half) - 0.03, _line_y(xr, half) - 0.03
        tip = (x, (yl + yr) / 2 - 1.05)
        flags.fan_z(0.0, tip, [(xl, yl), (xr, yr)], 0.05, FLAGS[k % len(FLAGS)])
    return [b.finalize("CatCafe_Square_Bunting", mat), flags.finalize("CatCafe_Square_Bunting_Decor", mat)]


# -------------------------------------------------------------------------------------------------- arches --
SIGN_INNER, SIGN_POST, SIGN_TOP = 36.0, 2.5, 13.0
BOARD_W, BOARD_Y0, BOARD_Y1 = 22.0, 11.55, 17.0


def _cat_face(b, y, z):
    """Ginger cat face on both faces of a disc centred (0, y, z)."""
    b.cyl((0, y, z), 2.2, 0.5, "fur_ginger", axis="Z", segments=18)
    for s in (-1, 1):
        b.box((s * 1.35, y + 1.55, z), (1.3, 1.3, 0.48), "fur_ginger", rot=rot_z(45))          # ears
        b.box((s * 1.35, y + 1.6, z), (0.7, 0.7, 0.52), "nose_pink", rot=rot_z(45))            # inner ears
    for f in (-1, 1):                                                                          # both faces
        zf = z + f * 0.25
        lo, hi = (zf, zf + f * 0.06) if f > 0 else (zf + f * 0.06, zf)
        for s in (-1, 1):
            b.span((s * 0.75 - 0.2, y + 0.3, lo), (s * 0.75 + 0.2, y + 0.95, hi), "fur_black")   # eyes
        b.span((-0.25, y - 0.05, lo), (0.25, y + 0.2, hi), "nose_pink")                        # nose
        for k, x in enumerate((-0.45, -0.15, 0.15, 0.45)):                                     # W mouth
            yy = y - (0.55 if k in (0, 2) else 0.42)
            b.span((x - 0.12, yy, lo), (x + 0.12, yy + 0.16, hi), "fur_black")


def build_sign_arch(mat):
    b, flowers, lamps, bulbs = RB(), RB(), RB(), RB()
    half, post, top = SIGN_INNER / 2, SIGN_POST, SIGN_TOP
    for s in (-1, 1):
        x0, x1 = sorted((s * (half - 0.12), s * (half + post)))       # 0.12 into the opening, as at every arch
        b.span((x0 - 0.3, 0, -1.55), (x1 + 0.3, 1.2, 1.55), "concrete")
        b.span((x0, 1.2, -1.25), (x1, top, 1.25), "brick")
        for y in (4.6, 9.2):
            b.span((x0 - 0.12, y, -1.37), (x1 + 0.12, y + 0.4, 1.37), "cream")
        b.span((x0 - 0.3, top, -1.55), (x1 + 0.3, top + 0.6, 1.55), "cream")
        lantern(b, lamps, s * (half + post / 2), top + 0.6, 0, 1.15)
        bx = s * (half - 0.8)                                                                  # hanging basket
        b.span((min(s * half, bx), 8.6, -0.08), (max(s * half, bx), 8.75, 0.08), "fur_black")
        b.span((bx - 0.04, 7.9, -0.04), (bx + 0.04, 8.6, 0.04), "fur_black")
        b.cyl((bx, 7.55, 0), 0.6, 0.6, "terracotta", r2=0.75, segments=10)
        flowers.span((bx - 0.6, 7.85, -0.6), (bx + 0.6, 8.0, 0.6), "leaf_green")
        flower_clump(flowers, bx, 8.0, 0, n=5, spread=0.55)
        # bracket from the beam end up to the board, with bulbs along it
        p0, p1 = (s * half, 11.5), (s * (BOARD_W / 2 + 0.3), BOARD_Y1 - 0.4)
        dx, dy = p1[0] - p0[0], p1[1] - p0[1]
        L = math.hypot(dx, dy)
        b.box(((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, 0), (L, 0.28, 0.28), "fur_black",
              rot=rot_z(math.degrees(math.atan2(dy, dx))))
        for k in range(1, 6):
            t = k / 6
            bx_, by_ = p0[0] + dx * t, p0[1] + dy * t
            bulbs.span((bx_ - 0.17, by_ + 0.16, -0.17), (bx_ + 0.17, by_ + 0.5, 0.17), "lamp_warm")
    b.span((-half, 11.0, -0.4), (half, 11.5, 0.4), "fur_black")                                # iron beam
    w2 = BOARD_W / 2
    b.span((-w2, BOARD_Y0, -0.3), (w2, BOARD_Y1, 0.3), "cream")                                # the board
    for (xa, xb, ya, yb) in ((-w2 - 0.25, w2 + 0.25, BOARD_Y0 - 0.05, BOARD_Y0 + 0.25),
                             (-w2 - 0.25, w2 + 0.25, BOARD_Y1 - 0.25, BOARD_Y1 + 0.05),
                             (-w2 - 0.25, -w2 + 0.05, BOARD_Y0 + 0.25, BOARD_Y1 - 0.25),
                             (w2 - 0.05, w2 + 0.25, BOARD_Y0 + 0.25, BOARD_Y1 - 0.25)):
        b.span((xa, ya, -0.38), (xb, yb, 0.38), "terracotta")
    label(b, "CAT CAFE", 0, 13.75, -0.3, 0.6, 0.08, "dark_wood", -1)                           # street side
    label(b, "TOWN SQUARE", 0, 12.05, -0.3, 0.26, 0.06, "terracotta", -1)
    label(b, "CAFE STREET", 0, 13.15, 0.3, 0.45, 0.08, "dark_wood", 1)                         # square side
    _cat_face(b, BOARD_Y1 + 1.4, 0)
    return [b.finalize("CatCafe_Square_SignArch", mat), flowers.finalize("CatCafe_Square_SignArch_Flowers", mat),
            lamps.finalize("CatCafe_Square_SignArch_Lamp_Bulb", mat),
            bulbs.finalize("CatCafe_Square_SignArch_Bulbs", mat)]


ARCH_INNER = 12.0


def build_arch_alley(mat):
    return _arch("CatCafe_Square_ArchAlley", mat, ARCH_INNER, [("THE", 0.2), ("ALLEYWAY", 0.25)],
                 [("TOWN", 0.25), ("SQUARE", 0.25)], board_top=14.0)


# ------------------------------------------------------------------------------------------------- garden --
GARDEN_W, GARDEN_D = 22.0, 12.0


def _tree(b, x, z):
    b.cyl((x, 2.6, z), 0.45, 5.2, "fur_brown", r2=0.32, segments=10)
    b.ball((x, 6.3, z), 2.4, "leaf_green")
    b.ball((x + 1.5, 5.4, z - 0.4), 1.5, "leaf_dark")
    b.ball((x - 1.4, 5.6, z + 0.5), 1.4, "leaf_green", scale=(1.0, 0.9, 1.0))
    b.ball((x + 0.2, 7.8, z + 0.3), 1.3, "leaf_dark")


def build_garden(mat):
    b, flowers = RB(), RB()
    hw, hd = GARDEN_W / 2, GARDEN_D / 2
    k_ = 0.5                                                                                   # kerb width
    b.span((-hw, 0, -hd), (hw, 0.65, -hd + k_), "brick")                                       # front kerb
    b.span((-hw, 0, hd - k_), (hw, 0.65, hd), "brick")                                         # back kerb
    for s in (-1, 1):
        x0, x1 = sorted((s * hw, s * (hw - k_)))
        b.span((x0, 0, -hd + k_), (x1, 0.65, hd - k_), "brick")                                # side kerbs
    b.span((-hw + k_, 0, -hd + k_), (hw - k_, 0.5, hd - k_), "leaf_green")                     # grass
    b.span((-hw + k_, 0.5, hd - 2.3), (hw - k_, 2.1, hd - k_), "leaf_dark")                    # hedge
    for k in range(5):                                                                         # its rounded top
        x = -hw + 2.6 + k * (GARDEN_W - 5.2) / 4
        b.ball((x, 2.1, hd - 1.4), 1.0, "leaf_dark", scale=(1.6, 0.55, 0.9))
    for x in (-6.5, 6.5):
        _tree(b, x, 1.0)
    # topiary cat in the middle, sitting, looking at the square
    b.ball((0, 1.55, 0.2), 1.25, "leaf_green", scale=(1.0, 1.0, 0.9))
    b.ball((0, 3.2, -0.15), 0.85, "leaf_green")
    for s in (-1, 1):
        b.box((s * 0.48, 3.95, -0.15), (0.5, 0.5, 0.3), "leaf_green", rot=rot_z(45))
    b.ball((1.15, 0.95, 0.9), 0.4, "leaf_dark", scale=(1.0, 0.8, 1.8))                         # tail
    for k in range(8):                                                                         # flowers along the front
        x = -hw + 1.6 + k * (GARDEN_W - 3.2) / 7
        flower_clump(flowers, x, 0.5, -hd + 1.4, n=4, spread=0.45)
    for x in (-3.0, 3.0):                                                                      # small bushes
        b.ball((x, 0.95, 2.1), 0.8, "leaf_dark")
    return [b.finalize("CatCafe_Square_Garden", mat), flowers.finalize("CatCafe_Square_Garden_Flowers", mat)]


ASSETS = {
    "CatCafe_Square_Paving": (build_paving, 20000),
    "CatCafe_Square_Fountain": (build_fountain, 8000),
    "CatCafe_Square_Signpost": (build_signpost, 2000),
    "CatCafe_Square_ArchAlley": (build_arch_alley, 5000),
    "CatCafe_Square_SignArch": (build_sign_arch, 6000),
    "CatCafe_Square_Bench": (build_bench, 800),
    "CatCafe_Square_Lamp": (build_lamp, 1500),
    "CatCafe_Square_Bunting": (build_bunting, 1500),
    "CatCafe_Square_Garden": (build_garden, 4000),
}


def _placements():
    """(asset, x, z, rot_y degrees) in square coordinates (world), y at the square's floor top (0.1). rot_y is
    CFrame.Angles(0, math.rad(rot_y), 0). The arches and the signpost are WorldBuilder's (buildArch, buildSignpost)."""
    out = [("CatCafe_Square_Paving", 0, 0, 0), ("CatCafe_Square_Fountain", 0, 0, 0)]
    for q in range(4):
        for a in BENCH_ANGLES:
            deg = a + 90 * q
            if deg == 215:                                                      # the signpost stands there
                continue
            t = math.radians(deg)
            out.append(("CatCafe_Square_Bench", round(RING_R * math.cos(t), 2), round(RING_R * math.sin(t), 2),
                        (90 - deg) % 360))                                      # front toward the fountain
    for sx in (-1, 1):
        for sz in (-1, 1):
            out.append(("CatCafe_Square_Lamp", sx * LAMP_AT, sz * LAMP_AT, 45))
    out += [("CatCafe_Square_Bunting", 0, -LAMP_AT, 0), ("CatCafe_Square_Bunting", 0, LAMP_AT, 0),
            ("CatCafe_Square_Bunting", -LAMP_AT, 0, 90), ("CatCafe_Square_Bunting", LAMP_AT, 0, 90),
            ("CatCafe_Square_SignArch", 0, -SQ_D, 0), ("CatCafe_Square_SignArch", 0, SQ_D, 180)]
    for sx in (-1, 1):
        for sz in (-1, 1):
            out.append(("CatCafe_Square_Garden", sx * 55.5, sz * 19.5, 90 * sx))  # front toward the square
    return out


PLACEMENTS = _placements()
