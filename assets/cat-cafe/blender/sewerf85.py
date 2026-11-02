"""The F85 Sewer (hometown-cannon.md section 6b): a long rectangle, 120 x 600 with the camp, so the run home with a
cat is the longest of the five. The set is the wild part, 120 x 570; the camp (CatCafe_Camp_SewerF85, camps.py) lies
across its -Z end, outside it, as in F84. The Sewer gate (CatCafe_Sewer_Gate) and its night fence already span the
24 stud opening (CampOpeningWidth), so the long Sewer keeps them.

  CatCafe_Sewer_SetF85   the wild part dressed, in area space (areakit): place it at the area's centre on its floor,
                         gate side -Z toward the camp, like every set. Walls at x +-60 and z +-285 (WorldBuilder's);
                         the way in is the gap in the low wall at x -16 to 16 on z -285.

Six pieces cross the width. Since Derek 11-02 ("it should be easily navigatable just little areas to walk around to
continue forward") none of them runs wall to wall: each is an island or stops short of one wall, so the way on is a
short walk round an end, and the ends swap sides so the far end is never in a straight line:

  z -211 to -199   the yard's canal, sunken between kerbs with guard rails, in through a grate in the west wall and
                   ending in a drain grate at x 8; walk round its east end (47 wide) or cross the brick bridge at
                   x -26, 12 wide
  z -150 to -147   the tunnel front, brick 24 high (tall), where the roof begins: three open arches, the walk-in
                   arches at x -49.5 to -26.5 and 26.5 to 49.5 (23 wide) and a small one in the middle (x -5 to 5)
  z -78 to -72     the rubble where the roof came down, about 4 high, daylight through the hole above it: an island
                   from x -34 to 10, walk round either end; the timber props at x 26 to 50 hold up the cracked beam
  z -5 to 5        the channel, sunken between railed kerbs, in through a grate in the east wall and ending in a drain
                   grate at x -8; walk round its west end (47 wide) or cross the steel catwalk at x 24, 9 wide
  z 90 to 96       the vault wall, brick to the roof (tall): two deep vaulted arches, x -46 to -22 and x 28 to 52,
                   CAT TOWN over the east one
  z 181 to 189     the pipe bank, three big pipes on concrete saddles, about 4.5 high: an island from x -24 to 24
                   with flanged pipe ends, walk round either end

The canal, the channel, the rubble and the pipe bank each have a 30 high `_Barrier` on their own line only (on the
guard rails' line and across the end for the water), and one stands in the wall band all round but the way in. The
tunnel front and the vault wall hide the halls behind them. The yard is open to the sky (walls 18 high); from the
tunnel front on the sewer is roofed at 24 (Derek 2026-10-28 01:39), lit through grated skylights and the hole, cage
lamps hanging from brick beams on pillars at x +-28. The far end is the throne room, the Sewer's best landmark: the
junk throne on its dais in front of the pipe organ, and the culvert pouring out of the far wall into the pool.

The way, camp to far end: round the canal's east end, through the middle arch of the tunnel front, round the
rubble, round the channel's west end, through the vault's west arch, round the pipe bank and across the throne room
to the throne. Shortest walk (walk check on the Part model) in area-sets.md (6b: about 560 camp to the throne, 680
before the islands).

Points (manifest points_roblox): [x, y, z, zone], zone "near" (the camp half, z < 0) or "deep" (the far half). The
traps are built in as in v3.2: `trap_grate` x2 and `trap_drain_pipe` x2, each with the piece's turn as a fifth
number. Three of the four are deep and none is within 100 studs of the camp.
"""

import math

from mathutils import Matrix

import alleyway
import sewer as sw
from areakit import PI, Set, rx, ry, turned
from common import RB, Builder, text_width
from sewerset import (BAR_T, BARRIER_H, CULVERT_W, FLOOR, IRON, KERB_H, KERB_W, MOUTH_W, RAIL_STEP, ROOF_T, WALL_D,
                      WALL_H, YARD_H, _line, bl, brick_bridge, catwalk_bridge, corner_pier, culvert, face, rail,
                      rail_path, rects_minus, span, town_wall, tunnel_mouth)

NAME = "CatCafe_Sewer_SetF85"
N = "CatCafe_Sewer_"
HALF_X, HALF_Z = 60.0, 285.0            # WorldBuilder's walls at +-60, +-285 (SewerWidth 120, SewerDepth 570)
IN_X, IN_Z = HALF_X - 0.5 - WALL_D, HALF_Z - 0.5 - WALL_D       # 56.5, 281.5
OUT_X, OUT_Z = IN_X + WALL_D, IN_Z + WALL_D                     # 59.5, 284.5
GATE_HALF = 16.0                        # clear of the Sewer gate model (31.1 wide)

# Islands to walk round (Derek 11-02: "it should be easily navigatable just little areas to walk around to continue
# forward"): the canal and the channel stop short of one wall each, every arch in the two tall walls is open, and the
# rubble and the pipe bank are islands in the middle
CANAL_Z, CANAL_HW, BRIDGE_X = -205.0, 5.0, -26.0     # the yard's canal (brick_bridge spans CANAL_HW 5), bridge west
CANAL_END = (8.0, 1)                                 # from the west wall's grate to a drain at x 8; open floor east
BRIDGE_D, CATWALK_W = 12.0, 9.0                      # the brick bridge and the catwalk wide (8 and 5 until 11-02)
FRONT_Z, FRONT_T, WALK_X = -150.0, 3.0, -38.0        # the tunnel front's yard face, and its walk-in arch (west)
WALK_HW = 11.5                                       # half the walk-in arch and its barred twin (7 until 11-02)
RUBBLE_Z, GAP_R = -75.0, (26.0, 50.0)                # the rubble line; the timber props stand at GAP_R
ISLE_R = [(-34.0, 10.0)]                             # the heap, under the hole
HOLE = (-44.0, 16.0, -88.0, -62.0)                   # where the roof came down, over the rubble
CH_Z, CH_HW, CATWALK_X = 0.0, 4.0, 24.0             # the channel and its catwalk (east)
CH_END = (-8.0, -1)                                  # from a drain at x -8 to the east wall's grate; open floor west
VAULT_Z, VAULT_T, VAULT_GAP = 90.0, 6.0, (28.0, 52.0)   # the vault wall, its arch east (spring 3.5: CAT TOWN fits under the cornice)
VAULT_GAP2 = (-46.0, -22.0)                              # and a second arch west
PIPES_Z, ISLE_P = 185.0, [(-24.0, 24.0)]             # the pipe bank, one island in the middle
POOL, POOL_R = (0.0, IN_Z - 14.5), 11.0              # the pool under the culvert, as v3.2 has them to the far wall
DAIS = (34.0, 269.0)                                 # the throne's dais
PILLAR_X = 28.0
BEAMS = (-125.0, -100.0, -50.0, -25.0, 30.0, 60.0, 120.0, 155.0, 215.0, 245.0)
PILLARS = [(sx * PILLAR_X, z) for z in BEAMS for sx in (-1, 1)]
SKYLIGHTS = [(-14.0, 14.0, -120.0, -105.0), (16.0, 40.0, -45.0, -30.0), (10.0, 30.0, 8.0, 24.0),
             (-44.0, -20.0, 36.0, 54.0), (-40.0, -16.0, 100.0, 114.0), (14.0, 44.0, 126.0, 149.0),
             (-44.0, -24.0, 192.0, 208.0), (20.0, 44.0, 222.0, 238.0), (-12.0, 12.0, 252.0, 276.0)]
MOUTHS = {1: [(-112.0, "door"), (40.0, "bars"), (140.0, "door")],                       # the side walls' tunnel mouths
          -1: [(-122.0, "bars"), (-40.0, "door"), (120.0, "bars"), (230.0, "bars")]}
FAR_MOUTHS = [(-36.0, "bars")]
CAPS = sw.CAPS

CANAL_RECT = (-IN_X, CANAL_END[0] + KERB_W, CANAL_Z - CANAL_HW - KERB_W, CANAL_Z + CANAL_HW + KERB_W)
CH_RECT = (CH_END[0] - KERB_W, IN_X, CH_Z - CH_HW - KERB_W, CH_Z + CH_HW + KERB_W)
FRONT_RECT = (-IN_X, IN_X, FRONT_Z, FRONT_Z + FRONT_T)
VAULT_RECT = (-IN_X, IN_X, VAULT_Z, VAULT_Z + VAULT_T)


def _spot(s, label, x, z, h=0.0, turn=None):
    p = [round(x, 2), round(FLOOR + h, 2), round(z, 2), "near" if z < 0 else "deep"]
    if turn is not None:
        p.append(turn)
    s.points.setdefault(label, []).append(p)


def trail_points():
    """The way, camp to far end, through each crossing (for the walk check's notes)."""
    return [(0, -IN_Z), (CANAL_END[0] + 8.0, CANAL_Z), (0.0, FRONT_Z), (20.0, RUBBLE_Z),
            (CH_END[0] - 8.0, CH_Z), ((VAULT_GAP2[0] + VAULT_GAP2[1]) / 2, VAULT_Z), (34.0, PIPES_Z), DAIS]


# ------------------------------------------------------------------------------------------------- water --
def _kerb(b, bar, x0, x1, z0, z1, gaps=(), ins=(0.3, 0.3)):
    """A kerb along x with its yellow edge, its guard rail (open at each gap) and the barrier on the rail's line.
    `ins`: how far in from each end the rail stops; negative runs it on over a closing end kerb to the corner."""
    span(b, x0, x1, z0, z1, 0, KERB_H, "concrete_dark")
    m = (z0 + z1) / 2
    span(b, x0, x1, m - 0.2, m + 0.2, KERB_H, KERB_H + 0.05, "rarity_legend")
    runs, pieces = [(x0 + ins[0], x1 - ins[1])], [(min(x0, x0 + ins[0]), max(x1, x1 - ins[1]))]
    for (g0, g1) in sorted(gaps):
        r, q = runs.pop(), pieces.pop()
        runs += [(r[0], g0 - 0.4), (g1 + 0.4, r[1])]
        pieces += [(q[0], g0), (g1, q[1])]
    for (a0, a1) in runs:
        rail(b, True, m, a0, a1)
    for (a0, a1) in pieces:
        n = max(1, round((a1 - a0) / 24.0))
        for i in range(n):
            c0, c1 = a0 + (a1 - a0) * i / n, a0 + (a1 - a0) * (i + 1) / n
            span(bar, c0, c1, m - BAR_T / 2, m + BAR_T / 2, 0, BARRIER_H, "offwhite")


def waterway(mat, name, zc, hw, cross_x, bridge, end=None):
    """A sunken waterway across the whole width at zc (water hw each side), out through the water mouths in both
    walls: a dark bed, water (`_Water`) 0.04 to 0.3, kerbs 1.2 wide to 1.6 with a yellow edge and a guard rail on
    each bank, the `_Barrier` on the rails' line (8c). Crossed only at cross_x: on the brick bridge (bridge: its
    abutments take the kerbs' place) or on the steel catwalk (over the kerbs, the rails open under it), with a
    barrier along the crossing's sides over the water. `end` (x, side) stops it short of one wall (F85 islands, Derek
    11-02: "just little areas to walk around"): side +1 runs it from the west wall east to x, -1 from x to the east
    wall; a kerb closes it there over a drain grate, the rail and barrier turn across, and past it is open floor."""
    b, water, bar = Builder(), Builder(), Builder()
    z0, z1 = zc - hw, zc + hw
    xe = IN_X + WALL_D - 0.3                                       # into the water mouths
    xk = IN_X - 0.7                                                # clear of the mouths' jambs
    lo, hi, klo, khi, ins = -xe, xe, -xk, xk, [0.3, 0.3]
    if end is not None:
        e, side = end
        if side > 0:
            hi, khi, ins[1] = e, e, -KERB_W / 2
        else:
            lo, klo, ins[0] = e, e, -KERB_W / 2
    span(b, lo, hi, z0, z1, 0, 0.04, "fur_ink")
    span(water, lo, hi, z0, z1, 0.04, 0.3, "fish_blue")
    for (za, zb) in ((z0 - KERB_W, z0), (z1, z1 + KERB_W)):
        if bridge:
            for k, (x0, x1) in enumerate(((klo, cross_x - BRIDGE_D / 2), (cross_x + BRIDGE_D / 2, khi))):
                _kerb(b, bar, x0, x1, za, zb, ins=(ins[0] if k == 0 else 0.3, ins[1] if k == 1 else 0.3))
        else:
            _kerb(b, bar, klo, khi, za, zb, gaps=[(cross_x - CATWALK_W / 2, cross_x + CATWALK_W / 2)], ins=tuple(ins))
    if end is not None:                                            # the closing kerb, its rail, a drain grate
        e, side = end
        ka, kb = sorted((e, e + side * KERB_W))
        km = (ka + kb) / 2
        span(b, ka, kb, z0 - KERB_W, z1 + KERB_W, 0, KERB_H + 0.006, "concrete_dark")
        span(b, km - 0.2, km + 0.2, z0 - KERB_W / 2 + 0.2, z1 + KERB_W / 2 - 0.2, KERB_H + 0.006, KERB_H + 0.056,
             "rarity_legend")
        rail(b, False, km, z0 - KERB_W / 2, z1 + KERB_W / 2, False, False)
        span(bar, km - BAR_T / 2, km + BAR_T / 2, z0 - KERB_W / 2 - BAR_T / 2, z1 + KERB_W / 2 + BAR_T / 2, 0,
             BARRIER_H, "offwhite")
        gx = e - side * 1.6                                        # the grate the water goes down, at the end
        span(b, gx - 1.2, gx + 1.2, z0 + 0.4, z1 - 0.4, 0.31, 0.35, IRON)
        for k in range(7):
            zz = z0 + 0.4 + (k + 0.5) * (z1 - z0 - 0.8) / 7
            span(b, gx - 1.3, gx + 1.3, zz - 0.09, zz + 0.09, 0.35, 0.43, IRON)
    for sx in (-1, 1):
        hw_ = BRIDGE_D / 2 if bridge else CATWALK_W / 2
        d0, d1 = hw_ + 0.1, hw_ + 0.7
        x0, x1 = sorted((cross_x + sx * d0, cross_x + sx * d1))
        span(bar, x0, x1, z0, z1, 0, BARRIER_H, "offwhite")
    return [b.finalize(N + name, mat), water.finalize(N + name + "_Water", mat),
            bar.finalize(N + name + "_Barrier", mat)]


def pool(mat):
    """The pool under the culvert: a dark bed and water on the slab, a ring of kerb blocks all round with a yellow
    edge, its guard rail and barrier, and a low barrier from the ring to the culvert under its pipe so nobody walks
    round behind it (as v3.2)."""
    b, water, bar = Builder(), Builder(), Builder()
    px, pz = POOL
    b.cyl_base(bl(px, pz, FLOOR), POOL_R + 0.1, 0.04, "fur_ink", segments=28, bevel=False)
    water.cyl_base(bl(px, pz, FLOOR + 0.04), POOL_R + 0.1, 0.36, "fish_blue", segments=28, bevel=False)
    rr = POOL_R + KERB_W / 2
    n = 32
    chord = 2 * (POOL_R + KERB_W) * math.sin(PI / n) * 1.04
    for k in range(n):
        a = 2 * PI * (k + 0.5) / n
        c = (bl(px, pz)[0] + rr * math.cos(a), pz + rr * math.sin(a))
        b.box_base((c[0], c[1], 0), (KERB_W, chord, KERB_H + 0.006 * (k % 2)), "concrete_dark", bevel=False,
                   rot=(a, "Z"))
        b.box_base((c[0], c[1], KERB_H + 0.006 * (k % 2)), (0.4, chord, 0.05), "rarity_legend", bevel=False,
                   rot=(a, "Z"))
        bar.box_base((c[0], c[1], 0), (BAR_T, 2 * rr * math.sin(PI / n) * 1.04, BARRIER_H), "offwhite", bevel=False,
                     rot=(a, "Z"))
    m = 2 * math.ceil(2 * PI * rr / RAIL_STEP / 2)                # even: the closing bay is a thin one
    pts = [(bl(px, pz)[0] + rr * math.cos(PI / 2 + 2 * PI * i / m), pz + rr * math.sin(PI / 2 + 2 * PI * i / m))
           for i in range(m + 1)]
    rail_path(b, pts, posts=(True, False), straight=False)
    span(bar, -0.5, 0.5, pz + POOL_R + KERB_W - 0.6, IN_Z - 1.5, 0, 5.5, "offwhite")
    return [b.finalize(N + "Pool", mat), water.finalize(N + "Pool_Water", mat), bar.finalize(N + "Pool_Barrier", mat)]


# ------------------------------------------------------------------------------------------------- walls --
def front_wall(mat, name, z0, T, ops, piers=(), sign=None, both=False, yard=False):
    """A brick wall across the whole width, 24 high up to the roof, its -Z face at z0 and T thick, with a concrete
    pier into the side walls' band at each end. Arches through it (ops: (x0, x1, spring, kind), kind "walk" open
    with a threshold or "bars" with iron bars and their barrier), each with imposts and a voussoir ring right
    through the wall (a vault when the wall is thick), stone piers at `piers`, a base course and a cornice, lanterns
    either side of each arch (_Bulb) and a teal sign (text, x, bottom) on the -Z face; piers, courses, cornice and
    lanterns on both faces when `both`; a course in line with the yard walls' tops on the -Z face when `yard`.
    Returns the wall, its lamps and its barrier."""
    rb = RB()
    b, bar, lamp = rb.b, Builder(), Builder()
    z1 = z0 + T
    faces = [(z0, -1), (z1, 1)] if both else [(z0, -1)]
    holes = [(a - 1.1, c + 1.1, -1e9, 1e9) for (a, c, _, _) in ops]

    def courses(za, zc, h0, h1, swatch):
        for (x0, x1, _, _) in rects_minus([(-IN_X + 1.5, IN_X - 1.5, za, zc)], holes):
            span(b, x0, x1, za, zc, h0, h1, swatch)

    x = -(IN_X - 1.0)
    for (a, c) in sorted([(o[0], o[1]) for o in ops]) + [(IN_X - 1.0, IN_X - 1.0)]:
        if a - x > 0.05:
            span(b, x, a, z0, z1, 0, WALL_H, "brick")
        x = c
    for sx in (-1, 1):                                                            # into the side walls' band
        x0, x1 = sorted((sx * (IN_X - 1.0), sx * OUT_X))
        span(b, x0, x1, z0 - 0.4, z1 + 0.4, 0, WALL_H, "concrete")
    for (a, c, spring, kind) in ops:
        w, cx = c - a, (a + c) / 2
        r = w / 2
        for k in range(8):                                                       # the wall over the arch
            h0, h1 = spring + r * k / 8, spring + r * (k + 1) / 8
            hw = math.sqrt(max(0.0, r * r - ((h0 + h1) / 2 - spring) ** 2))
            if r - hw > 0.05:
                for s in (-1, 1):
                    span(b, cx + s * hw, cx + s * r, z0, z1, h0, h1, "brick")
        span(b, a, c, z0, z1, spring + r, WALL_H, "brick")
        n = 13 if w > 12 else 11                                                 # voussoirs through the wall
        rm = r - 0.3 + 0.7
        L = 2 * rm * math.sin(PI / n / 2) * 1.15
        for k in range(n):
            t = PI * (k + 0.5) / n
            key = k == n // 2
            bx, by, bz = bl(cx + rm * math.cos(t), (z0 + z1) / 2 - 0.21 * key, spring + rm * math.sin(t))
            b.box((bx, by, bz), (L, T + 0.8 + 0.38 * key, 1.4 + 0.3 * key), "concrete_dark" if key else "concrete",
                  bevel=False, rot=ry(-(90 - math.degrees(t))))
        for s in (-1, 1):                                                         # imposts
            span(b, cx + s * (r + 0.1), cx + s * (r + 1.1), z0 - 0.5, z1 + 0.5, spring - 0.25, spring + 0.25,
                 "concrete_dark")
        if kind == "walk":
            span(b, a, c, z0, z1, 0, FLOOR, "concrete_dark")                       # the threshold
        else:                                                                     # iron bars
            m = int(w / 0.8)
            for i in range(m + 1):
                xx = a + 0.4 + i * (w - 0.8) / m
                h = spring + math.sqrt(max(0.0, r * r - (xx - cx) ** 2)) - 0.2
                span(b, xx - 0.13, xx + 0.13, z0 + 1.0, z0 + 1.26, FLOOR, h, IRON)
            for h in (1.4, spring - 1.0):
                span(b, a + 0.05, c - 0.05, z0 + 0.95, z0 + 1.31, FLOOR + h - 0.15, FLOOR + h + 0.15, IRON)
            span(b, cx - 0.4, cx + 0.4, z0 + 0.6, z0 + 1.02, 2.0, 2.8, "brass")    # a padlock on the bars
            span(bar, a, c, z0 + 0.8, z0 + 1.5, 0, spring + r, "offwhite")
            span(b, a, c, z0, z1, 0, FLOOR, "concrete_dark")
        for x in (a - 2.4, c + 2.4):                                              # lanterns either side
            if abs(x) > IN_X - 2.5:
                continue
            for (zf, d) in faces:
                bx, by, _ = bl(x, zf)
                b.box_base((bx, by + d * 0.3, 7.0), (2.0, 0.6, 2.0), "brick", bevel=False)
                b.box((bx, by + d * 0.9, 8.3), (0.2, 0.9, 0.2), IRON, bevel=False)
                lamp.box((bx, by + d * 1.4, 7.94), (0.7, 0.7, 0.88), "lamp_warm", bevel=False)
                b.pyramid((bx, by + d * 1.4, 8.4), 0.95, 0.4, IRON)
                b.box((bx, by + d * 1.4, 7.45), (0.85, 0.85, 0.12), IRON, bevel=False)
    for (zf, d) in faces:
        for x in piers:                                                           # stone piers
            za, zc = sorted((zf, zf + d * 0.7))
            span(b, x - 1.0, x + 1.0, za, zc, 0, WALL_H - 1.2, "concrete")
            za, zc = sorted((zf, zf + d * 0.9))
            span(b, x - 1.2, x + 1.2, za, zc, 0, 1.6, "concrete_dark")
        za, zc = sorted((zf, zf + d * 0.8))
        span(b, -(IN_X - 1.0), IN_X - 1.0, za, zc, WALL_H - 1.2, WALL_H, "concrete")         # cornice
        za, zc = sorted((zf, zf + d * 0.5))
        span(b, -(IN_X - 1.0), IN_X - 1.0, za, zc, WALL_H - 2.0, WALL_H - 1.2, "concrete_dark")
        za, zc = sorted((zf, zf + d * 0.3))
        courses(za, zc, 0, 1.2, "concrete_dark")                                  # base course
    if not both:
        courses(z1, z1 + 0.25, 0, 1.2, "concrete_dark")
    if yard:
        courses(z0 - 0.3, z0, YARD_H, YARD_H + 0.4, "concrete")
    if sign:
        text, sx_, h0 = sign
        tw = text_width(text, 0.5)
        bw = tw + 3.0
        span(b, sx_ - bw / 2, sx_ + bw / 2, z0 - 0.5, z0, h0, h0 + 4.0, "sign_teal")
        span(b, sx_ - bw / 2 - 0.4, sx_ + bw / 2 + 0.4, z0 - 0.45, z0 - 0.05, h0 - 0.4, h0 + 4.4, IRON)
        rb.text(text, (sx_ + tw / 2, h0 + 0.75, z0 - 0.54), 0.5, 0.1, "offwhite", right=(-1, 0, 0))
    return [b.finalize(N + name, mat), lamp.finalize(N + name + "_Bulb", mat), bar.finalize(N + name + "_Barrier", mat)]


def corner_column(mat, sx):
    """A far corner (sx 1 east, -1 west): a concrete column filling the corner of the wall band and standing 1.5
    into the room, base course and capital as the pillars have them (as v3.2)."""
    b = Builder()
    for (d, h0, h1, sw_) in ((0.0, 0, WALL_H, "concrete"), (0.12, 0, 1.6, "concrete_dark"),
                             (0.12, WALL_H - 2.0, WALL_H - 1.2, "concrete_dark")):
        ex, ez = OUT_X - (0.02 if d else 0.0), OUT_Z - (0.02 if d else 0.0)
        x0, x1 = sorted((sx * (IN_X - 1.5 - d), sx * ex))
        span(b, x0, x1, IN_Z - 1.5 - d, ez, h0, h1, sw_)
    return [b.finalize(N + "CornerColumn", mat)]


def _walls(s, mat):
    """The outer walls just inside WorldBuilder's: the yard's stone and tile walls (18 high, open to the sky) with
    the canal's water grates, the tunnels' walls (24, up to the roof) in brick, blind arcade, tile and pipe runs
    between piers with finished tunnel mouths and the channel's grates, the far wall round the culvert, and on the
    camp side a low brick wall with a railing either side of the way in. Returns the piers (for lanterns)."""
    piers = []
    yard = ("stone", "tiled", "stone", "brick")
    hall = ("brick", "arcade", "pipes", "tiled", "arcade", "brick", "pipes")
    m = MOUTH_W / 2 + 2.0
    for sx, rot, seed in ((1, 90, 0), (-1, -90, 3)):          # stone at both camp corners
        canal, channel = sx == -CANAL_END[1], sx == -CH_END[1]       # the walls the water comes out of
        wm = CANAL_HW + 2.0
        if canal:
            s.put(tunnel_mouth(mat, "water", w=2 * CANAL_HW, H=YARD_H, spring=5.0), sx * IN_X, CANAL_Z, rot)
        piers += _line(s, mat, -IN_Z, FRONT_Z - 0.4, [(CANAL_Z - wm, CANAL_Z + wm)] if canal else [], YARD_H, yard,
                       lambda t, sx=sx, rot=rot: (sx * IN_X, t, rot), seed, open_top=True)
        if channel:
            s.put(tunnel_mouth(mat, "water", w=2 * CH_HW, H=WALL_H, spring=5.0), sx * IN_X, CH_Z, rot)
        for (z, kind) in MOUTHS[sx]:
            s.put(tunnel_mouth(mat, kind), sx * IN_X, z, rot)
        cuts = [(z - m, z + m) for (z, _) in MOUTHS[sx]] + ([(CH_Z - CH_HW - 2.0, CH_Z + CH_HW + 2.0)] if channel else []) \
            + [(VAULT_Z - 0.4, VAULT_Z + VAULT_T + 0.4)]
        piers += _line(s, mat, FRONT_Z + FRONT_T + 0.4, IN_Z - 1.5, cuts, WALL_H, hall,
                       lambda t, sx=sx, rot=rot: (sx * IN_X, t, rot), seed + 1)
        s.put(corner_pier(mat, YARD_H), sx * (IN_X + WALL_D / 2), -(IN_Z + WALL_D / 2), 0)
        s.put(corner_column(mat, sx), 0, 0, 0)
    for (x, kind) in FAR_MOUTHS:
        s.put(tunnel_mouth(mat, kind), x, IN_Z, 0)
    piers += _line(s, mat, -(IN_X - 1.5), IN_X - 1.5,
                   [(x - m, x + m) for (x, _) in FAR_MOUTHS] + [(-CULVERT_W / 2, CULVERT_W / 2)], WALL_H, hall,
                   lambda t: (t, IN_Z, 0), 4)
    for sx in (-1, 1):                                                            # the camp side
        L = IN_X - GATE_HALF
        s.put(town_wall(mat, L), sx * (GATE_HALF + L / 2), -IN_Z, 180)
    bar = Builder()
    span(bar, -OUT_X, OUT_X, IN_Z, OUT_Z, 0, BARRIER_H, "offwhite")                    # far
    for sx in (-1, 1):
        x0, x1 = sorted((sx * IN_X, sx * OUT_X))
        span(bar, x0, x1, -IN_Z, IN_Z, 0, BARRIER_H, "offwhite")                       # sides
        x0, x1 = sorted((sx * GATE_HALF, sx * OUT_X))
        span(bar, x0, x1, -OUT_Z, -IN_Z, 0, BARRIER_H, "offwhite")                     # camp side
    s.put([bar.finalize(N + "Walls_Barrier", mat)], 0, 0, 0)
    return piers


# -------------------------------------------------------------------------------------------- low blockers --
def rubble(mat, z, runs):
    """Where the roof came down: a heap under the hole (runs, x0 to x1), about 4 high: a low core of broken stuff,
    slabs of the roof tipped up on it, lumps of brick and broken beam ends, rebar poking out, dust at its feet, and
    one long beam leaning from the heap up to the cracked beam's broken end. A barrier 30 high on it. Built on the
    slab (put it at FLOOR)."""
    b, bar = Builder(), Builder()
    for k, (a0, a1) in enumerate(runs):
        L = a1 - a0
        x, y, _ = bl((a0 + a1) / 2, z)
        b.box_base((x, y, 0), (L, 3.2, 1.6), "concrete_dark", bevel=False)                     # the heap's core
        n = max(1, round(L / 3.6))
        step = L / n
        for i in range(n):
            j = i + 13 * k
            c = a0 + (i + 0.5) * step
            side = 1 if j % 2 else -1
            x, y, _ = bl(c + 0.4 * math.sin(j * 1.7), z + side * 0.5)
            tilt = side * (22.0 + 8.0 * (j % 3)) * (1.8 if j % 5 == 4 else 1.0)
            R = Matrix.Rotation(math.radians(25.0 * math.sin(j * 2.3)), 3, "Z") @ Matrix.Rotation(
                math.radians(tilt), 3, "X")
            b.box((x, y, 1.9 + 0.3 * (j % 5 == 4)), (min(step * 0.95, 3.6), 2.8, 0.7),
                  ("concrete", "concrete_dark", "fur_grey")[j % 3], bevel=False, rot=R)          # a slab of roof
            if j % 2 == 0:                                                       # lumps of brick
                x2, y2, _ = bl(c - 0.6, z - side * 0.3)
                b.box((x2, y2, 1.95), (1.6, 1.1, 0.9), ("brick", "fur_russet")[(j // 2) % 2], bevel=False,
                      rot=Matrix.Rotation(math.radians(30 + 17 * j), 3, "Z") @ Matrix.Rotation(0.3, 3, "Y"))
                b.box((x2 - 0.3, y2 + 0.1, 2.65), (1.0, 0.8, 0.7), "concrete", bevel=False,
                      rot=Matrix.Rotation(math.radians(70 * j), 3, "Z") @ Matrix.Rotation(0.4, 3, "X"))
            if j % 3 == 1:                                                       # a broken beam end
                x3, y3, _ = bl(c + 0.8, z - side * 0.2)
                b.box((x3, y3, 2.4), (4.2, 1.4, 1.4), "brick", bevel=False,
                      rot=Matrix.Rotation(math.radians(15 * side + 10), 3, "Z") @ Matrix.Rotation(
                          math.radians(14), 3, "Y"))
            if j % 4 == 3:                                                       # rebar
                x4, y4, _ = bl(c, z + side * 0.2)
                b.box((x4, y4, 2.6), (0.12, 0.12, 2.4), "metal", bevel=False,
                      rot=Matrix.Rotation(math.radians(40 * j), 3, "Z") @ Matrix.Rotation(0.5, 3, "X"))
            if j % 2 == 1:                                                       # dust at its feet
                x5, y5, _ = bl(c, z + side * 2.3)
                b.ico((x5, y5, 0.15), 1.2, "fur_smoke_light", subdivisions=1, scale=(1.6, 0.9, 0.25))
        x, y, _ = bl((a0 + a1) / 2, z)
        bar.box_base((x, y, 0), (L, 5.4, BARRIER_H), "offwhite", bevel=False)
    # the long beam leaning from the heap up to the cracked beam's east end (Roblox x 4 at the foot, 14.5 at the top)
    (fx, fh), (tx, th) = (4.0, 0.6), (14.5, WALL_H - 1.6 - FLOOR)
    L = math.hypot(tx - fx, th - fh)
    phi = math.atan2(th - fh, tx - fx)
    bx, by, _ = bl((fx + tx) / 2, z)
    b.box((bx, by, (fh + th) / 2), (L + 0.8, 1.4, 1.4), "brick", bevel=False,          # 0.4 into the heap and the
          rot=Matrix.Rotation(-phi, 3, "Y"))                                       # beam, so it rests on both
    return [b.finalize(N + "Rubble", mat), bar.finalize(N + "Rubble_Barrier", mat)]


def timber_props(mat, z, gap):
    """Two pit props either side of the rubble's gap, from the slab up to the cracked beam (put at FLOOR): square
    timbers with a head block under the beam, iron straps and hazard bands."""
    b = Builder()
    top = WALL_H - 1.4 - FLOOR
    for gx in (gap[0] - 0.7, gap[1] + 0.7):
        x, y, _ = bl(gx, z)
        b.box_base((x, y, 0), (1.0, 1.0, top - 0.6), "caramel_wood", bevel=False)
        b.box_base((x, y, top - 0.6), (1.9, 1.5, 0.6), "dark_wood", bevel=False)               # the head under the beam
        b.box_base((x, y, 0), (1.4, 1.4, 0.5), "concrete_dark", bevel=False)                  # its foot block
        for h in (2.2, 4.6, top - 2.0):
            b.box((x, y, h), (1.08, 1.08, 0.18), IRON, bevel=False)                           # straps
        for h in (3.2, 3.8):
            b.box((x, y, h), (1.06, 1.06, 0.3), "rarity_legend" if h < 3.5 else "fur_black", bevel=False)
    return [b.finalize(N + "TimberProps", mat)]


def pipe_bank(mat, z, runs):
    """Three big pipes in runs (x0, x1), about 4.5 high: two side by side on concrete saddles and a thinner one on
    top, flanged every 6, into the side wall where a run meets it and open and dark at a free end, a valve on top by
    the east end. A barrier 30 high on it. Built on the slab (put it at FLOOR)."""
    b, bar = Builder(), Builder()
    pipes = ((-1.6, 2.0, 1.4, "dumpster_green"), (1.6, 2.0, 1.4, "rust"), (0.0, 3.56, 0.85, "metal"))
    for k, (a0, a1) in enumerate(runs):
        p0 = a0 - 0.5 if a0 <= -IN_X + 0.1 else a0                  # into the wall's face, or a free end
        p1 = a1 + 0.5 if a1 >= IN_X - 0.1 else a1
        opens = [(e, d) for (e, d, free) in ((a0, -1, p0 == a0), (a1, 1, p1 == a1)) if free]   # d: outward
        L = abs(p1 - p0)
        n = max(2, round((a1 - a0) / 8.0))
        for i in range(n):                                          # saddles
            x, y, _ = bl(a0 + (i + 0.5) * (a1 - a0) / n, z)
            b.box_base((x, y, 0), (1.2, 6.6, 1.4), "concrete", bevel=False)
        for (dz, h, r, col) in pipes:
            x, y, _ = bl((p0 + p1) / 2, z + dz)
            b.cyl((x, y, h), r, L, col, segments=12, bevel=False, rot=ry(90))
            m = max(1, round(L / 6.0))
            for i in range(1, m):                                   # flanges
                fx, _, _ = bl(p0 + i * L / m, z)
                b.cyl((fx, y, h), r + 0.2, 0.4, "metal", segments=12, bevel=False, rot=ry(90))
            for (e, d) in opens:
                ex, _, _ = bl(e - d * 0.3, z)
                b.cyl((ex, y, h), r + 0.25, 0.5, "metal", segments=12, bevel=False, rot=ry(90))   # the end's flange
                ex, _, _ = bl(e + d * 0.05, z)
                b.cyl((ex, y, h), r - 0.3, 0.1, "fur_ink", segments=12, bevel=False, rot=ry(90))  # dark inside
        end, d = opens[-1]
        d = -d                                                      # from the end back along the pipes
        vx, vy, _ = bl(end + d * 2.5, z)                            # a valve on the top pipe by the east end
        b.cyl_base((vx, vy, 4.3), 0.2, 0.9, "metal", segments=8, bevel=False)
        b.ring((vx, vy, 5.1), 0.9, 0.18, 0.18, "bowl_red", segments=14, bevel=False)
        for a in (0, 90):
            b.box((vx, vy, 5.19), (1.7, 0.14, 0.14), "bowl_red", bevel=False, rot=(math.radians(a), "Z"))
        x, y, _ = bl((a0 + a1) / 2, z)
        bar.box_base((x, y, 0), (a1 - a0, 7.0, BARRIER_H), "offwhite", bevel=False)
    return [b.finalize(N + "PipeBank", mat), bar.finalize(N + "PipeBank_Barrier", mat)]


# --------------------------------------------------------------------------------------------------- roof --
def roof(mat, piers):
    """The roof from the tunnel front to the far wall, its underside at WALL_H: a slab with grated skylights and the
    hole where it came down (a ragged rim, rebar), brick beams across on brick pillars at x +-28 (the beam over the
    rubble cracked through, its ends broken), cage lamps hanging from the beams (_Bulb), pipe runs along both walls
    under it, and on top the skylights' curbs and a few vent stacks. A beam that meets a wall pier stops at the face
    of the pier's cap."""
    b, lamp = Builder(), Builder()

    def stop(at, end):
        for (px, pz) in piers:
            if abs(pz - at) < 2.4 and abs(px - end) < 1.0:
                return end - math.copysign(0.75, end)
        return end

    rects = rects_minus([(-OUT_X, OUT_X, FRONT_Z, OUT_Z)], SKYLIGHTS + [HOLE])
    for i, (x0, x1, z0, z1) in enumerate(rects):
        span(b, x0, x1, z0, z1, WALL_H, WALL_H + ROOF_T + 0.004 * (i % 3), "concrete_dark")
    for (x0, x1, z0, z1) in SKYLIGHTS:
        for (a, c, d, e) in ((x0 - 0.6, x1 + 0.6, z0 - 0.6, z0), (x0 - 0.6, x1 + 0.6, z1, z1 + 0.6),
                             (x0 - 0.6, x0, z0, z1), (x1, x1 + 0.6, z0, z1)):
            span(b, a, c, d, e, WALL_H + ROOF_T, WALL_H + ROOF_T + 0.7, "concrete")
        along_z = (z1 - z0) > (x1 - x0)
        n = int(((z1 - z0) if along_z else (x1 - x0)) / 2.4)
        for k in range(1, n):                                                     # bars across the short way
            if along_z:
                zz = z0 + k * (z1 - z0) / n
                span(b, x0, x1, zz - 0.15, zz + 0.15, WALL_H + 0.3, WALL_H + 0.9, IRON)
            else:
                xx = x0 + k * (x1 - x0) / n
                span(b, xx - 0.15, xx + 0.15, z0, z1, WALL_H + 0.3, WALL_H + 0.9, IRON)
        if along_z:
            span(b, (x0 + x1) / 2 - 0.2, (x0 + x1) / 2 + 0.2, z0, z1, WALL_H + 0.2, WALL_H + 0.3, IRON)
        else:
            span(b, x0, x1, (z0 + z1) / 2 - 0.2, (z0 + z1) / 2 + 0.2, WALL_H + 0.2, WALL_H + 0.3, IRON)
    # the hole's ragged rim: broken slab jutting in, a little thinner than the roof, and rebar hanging down
    x0, x1, z0, z1 = HOLE
    k = 0
    for (along_x, at, a0, a1, d) in ((True, z0, x0 + 1.5, x1 - 1.5, 1), (True, z1, x0 + 1.5, x1 - 1.5, -1),
                                     (False, x0, z0 + 1.5, z1 - 1.5, 1), (False, x1, z0 + 1.5, z1 - 1.5, -1)):
        n = max(1, int((a1 - a0) / 3.0))
        for i in range(n):
            k += 1
            c = a0 + (i + 0.5) * (a1 - a0) / n
            Lc = 2.0 + 0.6 * (k % 3)
            out = 0.6 + 0.55 * ((k * 5) % 4)
            q0, q1 = sorted((at - d * 0.4, at + d * out))
            h0, h1 = WALL_H + 0.08 + 0.03 * (k % 3), WALL_H + ROOF_T - 0.08 - 0.03 * (k % 3)
            sw_ = "concrete_dark" if k % 3 else "concrete"
            if along_x:
                span(b, c - Lc / 2, c + Lc / 2, q0, q1, h0, h1, sw_)
            else:
                span(b, q0, q1, c - Lc / 2, c + Lc / 2, h0, h1, sw_)
            if k % 4 == 0:                                                        # rebar hanging out of the edge
                px, pz = (c, at + d * (out + 0.3)) if along_x else (at + d * (out + 0.3), c)
                bx, by, _ = bl(px, pz)
                tilt = 0.6 if along_x else 0.0
                b.box((bx, by, WALL_H - 0.4), (0.12, 0.12, 2.4), "metal", bevel=False,
                      rot=Matrix.Rotation(tilt * d, 3, "X") @ Matrix.Rotation((0.0 if along_x else 0.6 * d), 3, "Y"))
    # beams across on the pillars, and the cracked one over the rubble
    for z in BEAMS:
        span(b, stop(z, -IN_X), stop(z, IN_X), z - 0.8, z + 0.8, WALL_H - 1.4, WALL_H, "brick")
    for (xa, xb) in ((stop(RUBBLE_Z, -IN_X), x0 + 1.4), (x1 - 2.0, stop(RUBBLE_Z, IN_X))):
        span(b, xa, xb, RUBBLE_Z - 0.8, RUBBLE_Z + 0.8, WALL_H - 1.4, WALL_H, "brick")
    for (xe, d) in ((x0 + 1.4, 1), (x1 - 2.0, -1)):                                # their broken ends
        span(b, *sorted((xe - d * 0.3, xe + d * 0.9)), RUBBLE_Z - 0.55, RUBBLE_Z + 0.35, WALL_H - 1.25, WALL_H - 0.3,
             "brick")
        span(b, *sorted((xe - d * 0.2, xe + d * 0.5)), RUBBLE_Z - 0.2, RUBBLE_Z + 0.7, WALL_H - 0.95, WALL_H - 0.1,
             "fur_russet")
    for (x, z) in PILLARS:                                                        # the pillars
        span(b, x - 1.2, x + 1.2, z - 1.2, z + 1.2, FLOOR, WALL_H - 1.4, "brick")
        span(b, x - 1.5, x + 1.5, z - 1.5, z + 1.5, FLOOR, FLOOR + 1.2, "concrete")
        span(b, x - 1.45, x + 1.45, z - 1.45, z + 1.45, WALL_H - 2.2, WALL_H - 1.4, "concrete")
    for i, z in enumerate(BEAMS):                                                 # cage lamps off the beams
        for x in ((-14.0, 42.0) if i % 2 else (-42.0, 14.0)):
            span(b, x - 0.08, x + 0.08, z - 0.08, z + 0.08, WALL_H - 5.0, WALL_H - 1.4, IRON)
            span(b, x - 0.7, x + 0.7, z - 0.7, z + 0.7, WALL_H - 5.2, WALL_H - 5.0, IRON)
            lamp.box_base(bl(x, z, WALL_H - 6.8), (0.9, 0.9, 1.6), "lamp_warm", bevel=False)
            for dx in (-0.55, 0.55):
                for dz in (-0.55, 0.55):
                    span(b, x + dx - 0.06, x + dx + 0.06, z + dz - 0.06, z + dz + 0.06, WALL_H - 6.8, WALL_H - 5.2,
                         IRON)
            span(b, x - 0.7, x + 0.7, z - 0.7, z + 0.7, WALL_H - 7.0, WALL_H - 6.8, IRON)
    beam_zs = list(BEAMS) + [RUBBLE_Z]
    ph, pr = WALL_H - 2.8, 0.55                    # under the cross walls' cornices, which start at WALL_H - 2
    for x in (-53.5, 53.5):                                                       # pipe runs along both walls
        for (za, zc) in ((FRONT_Z + FRONT_T, VAULT_Z), (VAULT_Z + VAULT_T, IN_Z)):
            za, zc = za + 0.02, zc - 0.02
            b.cyl(bl(x, (za + zc) / 2, ph), pr, zc - za, "dumpster_green", segments=10, bevel=False, rot=rx(90))
            for zz in (za + 0.31, zc - 0.31):                                     # flanges at the walls
                b.cyl(bl(x, zz, ph), 0.75, 0.6, "metal", segments=10, bevel=False, rot=rx(90))
            k = int((zc - za) / 9.0)
            for i in range(1, k):                                                 # hangers from the roof
                zz = za + i * (zc - za) / k
                if any(abs(zz - bz) < 1.6 for bz in beam_zs):
                    continue
                span(b, x - 0.08, x + 0.08, zz - 0.08, zz + 0.08, ph + pr + 0.1, WALL_H, IRON)
                span(b, x - 0.7, x + 0.7, zz - 0.12, zz + 0.12, ph + pr - 0.04, ph + pr + 0.11, IRON)
    for (x, z) in ((-40.0, -136.0), (36.0, 10.0), (-30.0, 160.0), (40.0, 200.0), (-20.0, 262.0)):   # vent stacks
        b.cyl_base(bl(x, z, WALL_H + ROOF_T), 0.8, 3.5, "metal", segments=10, bevel=False)
        b.cyl_base(bl(x, z, WALL_H + ROOF_T + 3.5), 1.2, 0.6, "metal", segments=10, bevel=False, radius2=0.4)
    return [b.finalize(N + "Roof", mat), lamp.finalize(N + "Roof_Bulb", mat)]


# ------------------------------------------------------------------------------------------- landmark bits --
def throne_dais(mat, W=14.0, D=10.0, H=1.2):
    """The junk throne's dais, front -Y toward the camp: a brick platform W x D and H high under a stone edge, a
    step of 0.6 across its front, a red runner up to the throne, and a pole at each back corner flying a teal banner
    with bottle caps on it."""
    b = Builder()
    b.box_base((0, 0, 0), (W, D, H - 0.2), "brick", bevel=False)
    b.box_base((0, 0, H - 0.2), (W + 0.3, D + 0.3, 0.2), "concrete", bevel=False)
    b.box_base((0, -(D / 2 + 0.75), 0), (8.0, 1.5, 0.6), "concrete", bevel=False)                # the step
    b.box_base((0, -(D / 2 + 0.75), 0.6), (2.6, 1.5, 0.03), "shirt_red", bevel=False)            # the runner
    b.box_base((0, -1.5, H), (2.6, D - 2.0, 0.03), "shirt_red", bevel=False)
    for sx in (-1, 1):
        x, y = sx * (W / 2 - 1.0), D / 2 - 1.5
        b.cyl_base((x, y, H), 0.22, 9.0, "metal", segments=8, bevel=False)
        b.cyl_base((x, y, H + 9.0), 0.4, 0.4, "rarity_legend", segments=8, bevel=False)          # finial
        b.box((x, y, H + 8.6), (2.2, 0.16, 0.16), "metal", bevel=False)                          # crossbar
        b.box_base((x, y - 0.2, H + 3.4), (1.8, 0.08, 5.0), "sign_teal", bevel=False)            # the banner
        for k in range(3):
            b.cyl((x, y - 0.29, H + 4.4 + 1.5 * k), 0.45, 0.12, CAPS[(2 * k + 1) % 6], segments=10, bevel=False,
                  rot=rx(90))
    return [b.finalize(N + "ThroneDais", mat)]


def hanging_sign(mat, text, bottom=12.0):
    """A two-sided teal sign on two chains from the beam overhead (put at FLOOR under a beam): the board from
    `bottom`, the text in pale letters on its -Y face (toward the camp)."""
    rb = RB()
    b = rb.b
    tw = text_width(text, 0.3)
    bw = tw + 2.0
    b.box_base((0, 0, bottom), (bw, 0.4, 2.6), "sign_teal", bevel=False)
    b.box_base((0, 0, bottom - 0.3), (bw + 0.6, 0.3, 3.2), IRON, bevel=False)
    top = WALL_H - 1.4 - FLOOR
    for sx in (-1, 1):
        b.box_base((sx * (bw / 2 - 0.6), 0, bottom + 2.9), (0.14, 0.14, top - bottom - 2.9), "metal", bevel=False)
    rb.text(text, (tw / 2, bottom + 0.55, -0.24), 0.3, 0.1, "offwhite", right=(-1, 0, 0))
    return [b.finalize(N + "HangingSign", mat)]


# ------------------------------------------------------------------------------------------------- ground --
def _ground():
    """The tiled floor slab with the waterways and the cross walls cut out, tile lines on it, and darker towpaths
    along the waterways' banks (8b)."""
    g = Builder()
    rects = rects_minus([(-IN_X, IN_X, -IN_Z, IN_Z)], [CANAL_RECT, CH_RECT, FRONT_RECT, VAULT_RECT])
    for (x0, x1, z0, z1) in rects:
        span(g, x0, x1, z0, z1, 0, FLOOR, "concrete")
        for x in range(-48, 49, 8):
            if x0 + 0.5 < x < x1 - 0.5:
                span(g, x - 0.075, x + 0.075, z0, z1, FLOOR, FLOOR + 0.02, "concrete_dark")
        for z in range(-280, 281, 8):
            if z0 + 0.5 < z < z1 - 0.5:
                span(g, x0, x1, z - 0.075, z + 0.075, FLOOR, FLOOR + 0.026, "concrete_dark")
    tow = []
    for (x0, x1, z0, z1), (e, side) in ((CANAL_RECT, CANAL_END), (CH_RECT, CH_END)):
        xa, xb = (x0, x1 + 3.0) if side > 0 else (x0 - 3.0, x1)       # round the closed end too
        tow += [(xa, xb, z0 - 3.0, z0), (xa, xb, z1, z1 + 3.0)]
        tow += [(x1, x1 + 3.0, z0, z1)] if side > 0 else [(x0 - 3.0, x0, z0, z1)]
    for i, (x0, x1, z0, z1) in enumerate(tow):
        span(g, x0, x1, z0, z1, FLOOR, FLOOR + 0.032 + 0.004 * (i % 2), "paving_grout")
    return g


# --------------------------------------------------------------------------------------------------- set --
def build_set(mat):
    s = Set(NAME)

    def put(objs, x, z, rot=0.0, h=0.0):
        return s.put(objs, x, z, rot, FLOOR + h)

    piers = _walls(s, mat)
    s.put(waterway(mat, "Canal", CANAL_Z, CANAL_HW, BRIDGE_X, True, end=CANAL_END), 0, 0, 0)
    s.put(waterway(mat, "Channel", CH_Z, CH_HW, CATWALK_X, False, end=CH_END), 0, 0, 0)
    s.put(pool(mat), 0, 0, 0)
    s.put(front_wall(mat, "TunnelFront", FRONT_Z, FRONT_T,
                     [(WALK_X - WALK_HW, WALK_X + WALK_HW, 7.0, "walk"), (-5.0, 5.0, 5.5, "walk"),
                      (-WALK_X - WALK_HW, -WALK_X + WALK_HW, 7.0, "walk")],
                     piers=(-52.0, -24.0, -12.0, 12.0, 24.0, 52.0), sign=("THE SEWER", 0.0, 12.6), both=True,
                     yard=True), 0, 0, 0)
    s.put(front_wall(mat, "VaultWall", VAULT_Z, VAULT_T, [(VAULT_GAP2[0], VAULT_GAP2[1], 3.5, "walk"),
                                                          (VAULT_GAP[0], VAULT_GAP[1], 3.5, "walk")],
                     piers=(-51.5, -16.0, -3.0, 10.0, 22.0), sign=("CAT TOWN", (VAULT_GAP[0] + VAULT_GAP[1]) / 2, 17.4),
                     both=True), 0, 0, 0)
    s.put(roof(mat, [p for (p, _) in piers]), 0, 0, 0)
    s.put(rubble(mat, RUBBLE_Z, ISLE_R), 0, 0, 0, FLOOR)
    s.put(timber_props(mat, RUBBLE_Z, GAP_R), 0, 0, 0, FLOOR)
    s.put(pipe_bank(mat, PIPES_Z, ISLE_P), 0, 0, 0, FLOOR)
    put(culvert(mat), POOL[0], IN_Z - 1.5, 0)
    put(brick_bridge(mat, D=BRIDGE_D), BRIDGE_X, CANAL_Z, 0)
    _spot(s, "bridge", BRIDGE_X, CANAL_Z, h=2.4)
    put(catwalk_bridge(mat, W=CATWALK_W), CATWALK_X, CH_Z, 0)
    _spot(s, "bridge", CATWALK_X, CH_Z, h=3.2)
    for i, ((x, z), rot) in enumerate(piers):                          # wall lanterns on every other pier
        if i % 2 == 0:
            ax, az = turned(x, z, rot, 0.0, -1.3)
            s.put(sw.wall_lantern(mat), ax, az, rot, FLOOR + 6.6)

    def bunting(x0, z0, x1, z1, h=12.0, sag=2.2):
        """Cap bunting hooked between two pillars."""
        L = math.hypot(x1 - x0, z1 - z0) - 2.4
        put(sw.cap_bunting(mat, L, sag, hooks=True), (x0 + x1) / 2, (z0 + z1) / 2,
            math.degrees(math.atan2(z1 - z0, x1 - x0)), h=h)

    # ---- the yard (near): the gate plaza, the canal and its bridge, the bank before the tunnel front
    put(sw.puddle(mat), 10, -262, 0)
    put(sw.puddle(mat), -24, -250, 40)
    _spot(s, "puddle", -24, -247)
    for (x, z) in ((48, -262), (50.5, -264)):
        put(sw.barrel(mat), x, z, 0)
    _spot(s, "barrel", 45, -259)
    put(sw.tyre_stack(mat), 34, -268, 20)
    _spot(s, "tyres", 32, -264)
    for (x, z, r) in ((20, -230, 0), (22.5, -232.5, 20), (36, -228, 0)):
        put(sw.traffic_cone(mat), x, z, r)
    _spot(s, "cones", 14, -232)
    put(alleyway.build_crate_stack(mat), -46, -266, 30)
    _spot(s, "crates", -40, -262)
    put(sw.suitcase_stack(mat), -52, -238, 80)
    _spot(s, "suitcases", -48, -240.5)
    put(sw.steam_vent(mat), 26, -250, 0)
    put(sw.glow_mushrooms(mat), -40, -226, 0)
    _spot(s, "glow_mushrooms", -40, -229.5)
    put(sw.steam_vent(mat), -16, -180, 0)
    for (x, z) in ((-20, -160), (-17.6, -161.5)):                      # clear of the walk-in arch's way
        put(sw.barrel(mat), x, z, 0)
    put(sw.tyre_stack(mat), 52, -158, 0)
    put(alleyway.build_crate_stack(mat), 14, -172, -20)
    put(sw.glow_mushrooms(mat), 46, -176, 0)
    for (x, z) in ((20, -193), (-20, -193)):
        _spot(s, "bank", x, z)
    _spot(s, "arch", WALK_X, -154.5)

    # ---- the junk market (near): stalls, a crate deck, the sign and bunting, the near trap
    put(hanging_sign(mat, "JUNK MARKET"), 0, BEAMS[0], 0)
    for (x, z, rot) in ((-50, -130, -90), (-50, -114, -90), (10, -138, 180)):
        put(sw.junk_stall(mat), x, z, rot)
        _spot(s, "stall", *turned(x, z, rot, 0, -2.6))
    put(sw.crate_deck(mat), 44, -132, 30)
    _spot(s, "deck", *turned(44, -132, 30, -0.3, 0.6), h=2.15)
    bunting(-PILLAR_X, BEAMS[1], PILLAR_X, BEAMS[1])
    put(sw.grate(mat), -34, -92, 0)
    _spot(s, "trap_grate", -34, -92, turn=0)
    for (x, z) in ((52, -142), (54.4, -140)):
        put(sw.barrel(mat), x, z, 0)
    put(sw.suitcase_stack(mat), 53, -100, -90)
    put(alleyway.build_crate_stack(mat), -18, -96, 20)
    put(sw.tyre_stack(mat), -52, -96, 0)
    put(sw.steam_vent(mat), 22, -118, 0)
    put(sw.glow_mushrooms(mat), 6, -92, 0)
    _spot(s, "glow_mushrooms", 6, -95.5)
    _spot(s, "market", -16, -124)

    # ---- the pump room (near): the big pipe, a valve, the beached bathtub boat and raft by the channel
    put(sw.pipe_large(mat), 44, -30, 90)
    _spot(s, "pipe_end", *turned(44, -30, 90, -7.65, 0))
    put(sw.valve_wheel(mat), IN_X - 1.4, -47, 90)                       # between the wall's piers
    _spot(s, "valve", *turned(IN_X - 1.4, -47, 90, 0, -3.2))
    put(sw.bathtub_boat(mat), -14, -12, 90)
    _spot(s, "boat", -14, -12, h=1.42)
    put(sw.crate_raft(mat), -24, -14, 80)
    _spot(s, "raft", *turned(-24, -14, 80, 0.6, 0.4), h=1.8)
    put(sw.rubber_ducks(mat), 12, CH_Z, 90, h=-0.1)
    put(sw.pipe_elbow(mat), -50, -46, 0)
    put(sw.steam_vent(mat), 14, -58, 0)
    put(sw.puddle(mat), -4, -40, 0)
    put(sw.tyre_stack(mat), -50, -64, 0)
    for (x, z) in ((-30, -64), (-27.6, -65.5)):
        put(sw.barrel(mat), x, z, 0)
    put(alleyway.build_crate_stack(mat), 49, -14, -15)
    put(sw.glow_mushrooms(mat), -48, -30, 0)
    _spot(s, "glow_mushrooms", -48, -26.5)
    for (x, z) in ((-20, -44), (24, -20)):
        _spot(s, "pump_room", x, z)
    _spot(s, "catwalk_foot", CATWALK_X + 4, -12)

    # ---- the lost and found (deep): the lounge, the trolley, the hammock, a deck, the first deep trap
    _spot(s, "catwalk_foot", CATWALK_X - 4, 12)
    put(sw.lost_lounge(mat), 40, 70, 0)
    _spot(s, "sofa", *turned(40, 70, 0, -1.2, 1.3), h=1.48)
    put(sw.yarn_trolley(mat), -14, 44, 30)
    _spot(s, "trolley", -14, 44, h=0.6)
    put(sw.pipe_hammock(mat), -IN_X + 4.5, 70, 90)
    _spot(s, "hammock", *turned(-IN_X + 4.5, 70, 90, -0.3, 0), h=2.0)
    put(sw.crate_deck(mat), 20, 20, -20)
    _spot(s, "deck", *turned(20, 20, -20, -0.3, 0.6), h=2.15)
    put(sw.drain_pipe(mat), -IN_X + 2.4, 50, -90)
    _spot(s, "trap_drain_pipe", *turned(-IN_X + 2.4, 50, -90, -1.0, -2.4), turn=-90)
    bunting(-PILLAR_X, BEAMS[4], -PILLAR_X, BEAMS[5], h=11.0, sag=1.8)
    put(sw.glow_mushrooms(mat), 12, 78, 0)
    _spot(s, "glow_mushrooms", 12, 74.5)
    put(sw.glow_mushrooms(mat), -48, 24, 0)
    _spot(s, "glow_mushrooms", -44.5, 24)
    put(sw.steam_vent(mat), -30, 76, 0)
    put(sw.puddle(mat), 6, 50, 0)
    for (x, z) in ((50, 12), (52.4, 13.5)):
        put(sw.barrel(mat), x, z, 0)
    put(sw.tyre_stack(mat), -50, 84, 0)
    put(sw.suitcase_stack(mat), 52, 84, -90)
    for (x, z) in ((0, 40), (34, 50)):
        _spot(s, "lost_found", x, z)

    # ---- cat town (deep): houses round a square under a skylight, the cart on its rails, the second deep trap
    sq = (30.0, 137.5)
    for (x, z, fn) in ((18, 126, sw.can_house), (42, 126, sw.teapot_house), (18, 149, sw.box_house),
                       (42, 149, sw.can_house)):
        r = face(x, z, *sq)
        put(fn(mat), x, z, r)
        _spot(s, "house", *turned(x, z, r, 0, -3.6))
    for (x, z, fn) in ((51, 137.5, sw.teapot_house), (8, 137.5, sw.box_house)):
        put(fn(mat), x, z, face(x, z, *sq))
    bunting(PILLAR_X, BEAMS[6], PILLAR_X, BEAMS[7], h=11.0, sag=1.8)
    for (x, z) in ((30, 132), (26, 143)):
        _spot(s, "square", x, z)
    put(sw.rails(mat), -IN_X + 6.0, 160, 90)
    put(sw.cart(mat), -IN_X + 6.0, 164, 90, h=0.25)
    _spot(s, "cart", -IN_X + 6.0, 164, h=3.25)
    put(sw.grate(mat), -36, 112, 0)
    _spot(s, "trap_grate", -36, 112, turn=0)
    put(sw.pipe_large(mat), -14, 166, 0)
    _spot(s, "pipe_end", *turned(-14, 166, 0, 7.65, 0))
    put(sw.glow_mushrooms(mat), -8, 108, 0)
    _spot(s, "glow_mushrooms", -8, 104.5)
    put(sw.glow_mushrooms(mat), 54, 172, 0)
    _spot(s, "glow_mushrooms", 50.5, 172)
    put(sw.steam_vent(mat), -16, 140, 0)
    put(sw.puddle(mat), 0, 128, 0)
    for (x, z) in ((-50, 100), (-47.6, 101.5)):
        put(sw.barrel(mat), x, z, 0)
    put(sw.tyre_stack(mat), 54, 104, 0)
    put(alleyway.build_crate_stack(mat), -47, 133, 15)
    for (x, z) in ((-36, 104), (-4, 156), (-40, 172)):
        _spot(s, "town", x, z)

    # ---- the throne room (deep): the throne on its dais before the organ, the pool and culvert, the last trap
    dx, dz = DAIS
    put(throne_dais(mat), dx, dz, 0)
    put(sw.throne(mat), dx, dz + 1.5, 0, h=1.2)
    _spot(s, "throne", *turned(dx, dz + 1.5, 0, 0, 0.1), h=1.2 + 2.9)
    put(sw.pipe_organ(mat), dx, IN_Z - 1.4, 0)
    _spot(s, "organ", dx, IN_Z - 3.8)
    _spot(s, "dais", dx - 10, dz - 6)
    bunting(-PILLAR_X, BEAMS[9], PILLAR_X, BEAMS[9])
    put(sw.toy_pile(mat), -30, 266, 0)
    _spot(s, "toy_pile", -30, 266)
    put(sw.suitcase_stack(mat), -50, 276, 80)
    _spot(s, "suitcases", -46, 273.5)
    for (x, z) in ((-52, 250), (-49.6, 251.5)):
        put(sw.barrel(mat), x, z, 0)
    put(sw.tyre_stack(mat), 52, 210, 0)
    put(alleyway.build_crate_stack(mat), -14, 226, -15)
    put(sw.drain_pipe(mat), IN_X - 2.4, 255, 90)                        # under the blind arch, clear of wall pipes
    _spot(s, "trap_drain_pipe", *turned(IN_X - 2.4, 255, 90, -1.0, -2.4), turn=90)
    put(sw.glow_mushrooms(mat), 16, 276, 0)
    _spot(s, "glow_mushrooms", 16, 272.5)
    put(sw.glow_mushrooms(mat), -48, 206, 0)
    _spot(s, "glow_mushrooms", -44.5, 206)
    put(sw.steam_vent(mat), 0, 220, 0)
    put(sw.puddle(mat), 20, 200, 0)
    for (x, z) in ((-16, 256), (16, 252)):
        _spot(s, "pool", x, z)
    for (x, z) in ((10, 230), (-20, 212)):
        _spot(s, "throne_room", x, z)
    _spot(s, "pipes", -42.0, PIPES_Z + 9.0)                           # where the gap was until 11-02, in the open
    return s.finish(_ground(), mat), s


def build_sewer_set(mat):
    objs, _ = build_set(mat)
    return objs


ASSETS = {
    NAME: (build_sewer_set, 150000),
}
