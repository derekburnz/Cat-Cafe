"""The Sewer set for town layout v3.2 (town-layout-v3.md section 8, F81): 180 x 180 of sewer behind the Sewer gate.

  CatCafe_Sewer_SetV32   the whole area dressed, in area space (areakit): place it at the area's v3.2 centre on its
                         floor, turned so -Z faces the gate (a quarter turn, like the v3.1 set). The gate is at z -90.
                         A new name, so the live game keeps CatCafe_Sewer_Set (v3.1, 90 x 90) until Gameplay moves
                         the Sewer to its v3.2 Config and switches the set name in the same change.

The way in (8b): the gate opens on an open storm drain yard. A canal crosses the whole yard, sunken between kerbs, and
its only crossing is a brick bridge at the east end, straight in front of the only walk-in arch in the tunnel front.
Behind the front the sewer is roofed (Derek 2026-10-28 01:39: "higher walls possibly roofs for things like sewer
area"): two brick halls either side of a central channel, lit through grated skylights. The channel runs from a pool
at the far wall, where the culvert pours in out of the wall itself (Derek 01:40: "needs to be attached to the wall"),
to the yard's canal. The east hall's cross wall leaves one archway at its east end; the market is before it, the cat
houses after it. Two steel catwalks cross the channel (8b): one in the yard by the tunnel front, out to the west
bank, and one at the far end, the only way into the west hall: the junk throne by the far wall, and the far
chamber with the boat, the raft and the hammock. About 280 studs gate to throne, 330 to the far chamber,
against 180 straight. Every tunnel mouth in the walls is finished (Derek 01:41): a stone frame, an arch, depth, and
iron bars, an iron door or a water grate. Water is only crossed on the three bridges (8c): `_Barrier` walls stand on
every kerb and round the pool, open only at the bridges, and a 30 high `_Barrier` stands in the wall band all round
but the gate.

Points (manifest points_roblox): [x, y, z, zone]. Zone "near" is the yard and the market (the first half of the walk
from the gate), "deep" is the rest. The trap spots (trap_grate, trap_drain_pipe, built into the set as in v3.1) add a
fifth number, the piece's turn in degrees.

Positions are area space in Roblox numbers (x across, z from the gate at -90 to the far wall at +90); bl() turns them
into Builder (Blender) axes. Pieces from the v3.1 kit (sewer.py) are reused as they are.
"""

import math

import alleyway
import sewer as sw
from areakit import PI, Set, rx, ry, turned
from common import RB, Builder, text_width

N = "CatCafe_Sewer_"
SET = N + "SetV32"
HALF = 90.0                          # WorldBuilder's walls at +-90
WALL_D = 3.0                         # the set's walls: inner face here, back against WorldBuilder's
IN = HALF - 0.5 - WALL_D             # 86.5
OUT = IN + WALL_D                    # 89.5
FLOOR = 0.4                          # the tiled slab's top; pieces stand on it
WALL_H = 24.0                        # the tunnels' walls, up to the roof (v3.1's walls were 16)
YARD_H = 18.0                        # the open yard's walls
ROOF_T = 1.2
GATE_HALF = 16.0                     # clear of the Sewer gate model (31.1 wide)
BARRIER_H = 30.0
FACADE_Z, FACADE_T = -40.0, 3.0      # the tunnel front: yard face at -40
CANAL_Z, CANAL_HW = -61.0, 5.0       # the yard's canal, water z -66..-56
KERB_W, KERB_H = 1.2, 1.6            # kerbs stand on the area floor, 1.2 above the slab
CH_HW = 4.0                          # the central channel's water, x -4..4
POOL, POOL_R = (0.0, 72.0), 11.0     # the pool under the culvert, against the far wall
BRANCH_Z, BRANCH_HW, BRANCH_END = 12.0, 3.0, -50.0   # the west hall's side canal, from the channel to x -50
B1X = 44.0                           # the yard bridge, and the walk-in arch behind it
B2Z = 50.0                           # the catwalk over the channel at the far end
FB_Z = -47.4                         # the footbridge over the channel in the yard, in front of the tunnels
E1_Z, E1_T, E1_GAP = 4.0, 3.0, 66.0  # the east hall's cross wall, z 4..7, open from x 66 to the east wall
MOUTH_W = 12.0
CULVERT_W = 17.0                     # the culvert's headwall, built into the far wall
ARCH_W, ARCH_SPRING = 14.0, 9.0      # the tunnel front's big arches
PILLARS = [(sx * x, z) for sx in (-1, 1) for x in (25.0, 65.0) for z in (-30.0, 24.0, 62.0)]
SKYLIGHTS = [(-6.0, 6.0, -34.0, 40.0), (-10.0, 10.0, 62.0, 82.0), (38.0, 52.0, -24.0, -10.0),
             (34.0, 50.0, 36.0, 52.0), (-52.0, -38.0, -24.0, -10.0), (-52.0, -36.0, 34.0, 50.0)]
IRON = "fur_charcoal"


def bl(x, z, h=0.0):
    """Area (Roblox x, z) to Builder coordinates (Blender x is Roblox -x)."""
    return (-x, z, h)


def face(x, z, tx, tz):
    """rot_y that turns a piece at (x, z) to face (tx, tz)."""
    return math.degrees(math.atan2(-(tx - x), -(tz - z)))


def span(b, x0, x1, z0, z1, h0, h1, swatch, bevel=False):
    """An area-space box from Roblox x0..x1, z0..z1, height h0..h1."""
    b.box_base(bl((x0 + x1) / 2, (z0 + z1) / 2, h0), (abs(x1 - x0), abs(z1 - z0), h1 - h0), swatch, bevel=bevel)


def _rect_minus(r, h):
    """Rect r minus rect h (both (x0, x1, z0, z1)) as up to four rects."""
    x0, x1, z0, z1 = r
    a0, a1, b0, b1 = h
    if a1 <= x0 or a0 >= x1 or b1 <= z0 or b0 >= z1:
        return [r]
    out = []
    if b0 > z0:
        out.append((x0, x1, z0, b0))
    if b1 < z1:
        out.append((x0, x1, b1, z1))
    lo, hi = max(z0, b0), min(z1, b1)
    if a0 > x0:
        out.append((x0, a0, lo, hi))
    if a1 < x1:
        out.append((a1, x1, lo, hi))
    return out


def rects_minus(rects, holes):
    for h in holes:
        rects = [p for r in rects for p in _rect_minus(r, h)]
    return [r for r in rects if r[1] - r[0] > 0.05 and r[3] - r[2] > 0.05]


# the footprints cut out of the slab: the canal, the channel, the branch (water and kerbs), the inner walls
CANAL_RECT = (-IN, IN, CANAL_Z - CANAL_HW - KERB_W, CANAL_Z + CANAL_HW + KERB_W)
CHANNEL_RECT = (-CH_HW - KERB_W, CH_HW + KERB_W, CANAL_Z + CANAL_HW + KERB_W, POOL[1] - POOL_R)
BRANCH_RECT = (BRANCH_END - KERB_W, -CH_HW - KERB_W, BRANCH_Z - BRANCH_HW - KERB_W, BRANCH_Z + BRANCH_HW + KERB_W)
FACADE_RECT = (-IN, IN, FACADE_Z, FACADE_Z + FACADE_T)
E1_RECT = (CH_HW + KERB_W, E1_GAP, E1_Z, E1_Z + E1_T)


# ------------------------------------------------------------------ arches ---
def voussoirs(b, cx, spring, r, y0, y1, swatch="concrete", n=11, thick=1.2, key="concrete_dark", key_out=0.3):
    """A round arch ring of n blocks over an opening 2r wide centred at local x cx, from depth y0 to y1. The ring
    reaches 0.3 into the opening so it hides the stepped fill behind it; the keystone stands proud by key_out."""
    rm = r - 0.3 + thick / 2
    L = 2 * rm * math.sin(PI / n / 2) * 1.15
    for k in range(n):
        a = PI * (k + 0.5) / n
        is_key = k == n // 2
        d0, d1 = y0 - (key_out if is_key else 0), y1 - 0.01 * is_key           # no shared back face with the key
        b.box((cx + rm * math.cos(a), (d0 + d1) / 2, spring + rm * math.sin(a)), (L, d1 - d0, thick + 0.2 * is_key),
              key if is_key else swatch, bevel=False, rot=ry(90 - math.degrees(a)))


def arch_fill(b, cx, w, spring, top, y0, y1, swatch="brick", n=8):
    """The wall from `spring` up to `top` over a round opening w wide (centred at local x cx), as slices that step
    round the arch (the voussoirs cover the steps)."""
    r = w / 2
    for k in range(n):
        z0, z1 = spring + r * k / n, spring + r * (k + 1) / n
        hw = math.sqrt(max(0.0, r * r - ((z0 + z1) / 2 - spring) ** 2))
        if r - hw > 0.05:
            for s in (-1, 1):
                b.box_base((cx + s * (hw + r) / 2, (y0 + y1) / 2, z0), (r - hw, y1 - y0, z1 - z0), swatch, bevel=False)
    if top > spring + r + 0.05:
        b.box_base((cx, (y0 + y1) / 2, spring + r), (w, y1 - y0, top - spring - r), swatch, bevel=False)


def tunnel_mouth(mat, kind, w=MOUTH_W, H=WALL_H, spring=8.0):
    """A finished tunnel mouth for a gap w + 4 wide in a wall run (Derek 01:41: "the doorways look unfinished"):
    stone jambs standing proud, the wall over a round arch, a voussoir ring with a keystone, depth back to a dark
    inner arch, and the closure: "bars" (an iron gate, chained), "door" (a riveted iron double door under a fan
    grille) or "water" (a grate down into the canal running out under it). Front at y 0 facing -Y, back at WALL_D."""
    b, back, bar = Builder(), Builder(), Builder()
    r = w / 2
    for s in (-1, 1):                                                             # the jambs
        b.box_base((s * (r + 1.0), (WALL_D - 0.6) / 2, 0), (2.0, WALL_D + 0.6, H), "concrete", bevel=False)
        b.box_base((s * (r + 1.0), -0.5, 0), (2.4, 0.3, 1.4), "concrete_dark", bevel=False)       # plinth
        b.box((s * (r + 1.0), -0.5, spring), (2.4, 0.4, 0.5), "concrete_dark", bevel=False)       # impost
    arch_fill(b, 0, w, spring, H, 0.0, WALL_D)
    voussoirs(b, 0, spring, r, -0.4, WALL_D - 0.02)
    back.box_base((0, WALL_D - 0.19, 0), (w, 0.3, spring + r), "fur_ink", bevel=False)           # the dark beyond
    voussoirs(back, 0, spring - 0.6, r - 0.9, WALL_D - 0.9, WALL_D - 0.3, "fur_soot", n=9, thick=0.8,
              key="fur_soot", key_out=0)
    for s in (-1, 1):
        back.box_base((s * (r - 0.6), WALL_D - 0.6, 0), (1.2, 0.6, spring - 0.6), "fur_soot", bevel=False)
    lo = 0.0 if kind == "water" else FLOOR
    if kind != "water":
        b.box_base((0, WALL_D / 2, 0), (w, WALL_D, FLOOR), "concrete_dark", bevel=False)          # the mouth's floor
    if kind in ("bars", "water"):
        n = int(w / 0.8)
        for i in range(n + 1):
            x = -r + 0.4 + i * (w - 0.8) / n
            top = spring + math.sqrt(max(0.0, r * r - x * x)) - 0.2
            b.box_base((x, 0.6, lo), (0.26, 0.26, top - lo), IRON, bevel=False)
        for z in ((1.2, spring - 1.0) if kind == "bars" else (0.9, spring - 1.0)):
            b.box((0, 0.6, lo + z), (w - 0.1, 0.32, 0.3), IRON, bevel=False)
        if kind == "bars":                                                        # a chain and a padlock
            b.box((0, 0.36, 3.6), (0.5, 0.2, 2.4), "metal", bevel=False)
            b.box((0, 0.3, 2.3), (0.9, 0.35, 0.9), "brass", bevel=False)
    else:                                                                         # an iron double door
        for s in (-1, 1):
            b.box_base((s * r / 2, 0.55, FLOOR), (r - 0.08, 0.4, spring - FLOOR), "dumpster_green", bevel=False)
            for z in (1.6, spring - 1.4):
                b.box((s * r / 2, 0.32, z), (r - 0.5, 0.1, 0.4), IRON, bevel=False)                 # straps
            b.box((s * 0.6, 0.28, 3.6), (0.25, 0.2, 1.4), "brass", bevel=False)                    # handles
        b.ring((0, 0.25, spring * 0.55), 1.0, 0.25, 0.2, "brass", segments=12, rot=rx(90))
        for k in range(5):                                                        # the fan grille over it
            a = PI * (k + 1) / 6
            b.box((r / 2 * math.cos(a), 0.6, spring + r / 2 * math.sin(a)), (r - 0.6, 0.22, 0.22), IRON, bevel=False,
                  rot=ry(-math.degrees(a)))
        b.box((0, 0.6, spring + 0.1), (w - 0.1, 0.28, 0.3), IRON, bevel=False)
    bar.box_base((0, 0.6, 0), (w, 0.6, spring + r), "offwhite", bevel=False)
    return [b.finalize(N + "TunnelMouth", mat), back.finalize(N + "TunnelMouth_Decor", mat),
            bar.finalize(N + "TunnelMouth_Barrier", mat)]


# ------------------------------------------------------------------- walls ---
def _course(b, x0, x1, z, h, swatch, out=0.25):
    b.box((((x0 + x1) / 2), -out / 2 + 0.005, z), (x1 - x0, out, h), swatch, bevel=False)


def _seg_brick(b, x0, x1, H, k):
    L = x1 - x0
    m = (x0 + x1) / 2
    b.box_base((m, WALL_D / 2, 0), (L, WALL_D, H), "brick", bevel=False)
    _course(b, x0, x1, 0.6, 1.2, "concrete_dark")
    for z in (7.0, 15.0)[: 1 + (H > 15)]:
        _course(b, x0, x1, z, 0.4, "concrete", 0.3)
    px = m + L * (0.22 if k % 2 else -0.2)                                        # a patch of older brick
    b.box_base((px, -0.04, 2.6 + 0.5 * (k % 3)), (L * 0.28, 0.1, 3.4), "fur_russet", bevel=False)
    vx = m - L * 0.25 * (1 if k % 2 else -1)                                      # a vent and its stain
    b.box_base((vx, -0.1, 4.2), (1.8, 0.24, 1.1), IRON, bevel=False)
    for i in range(4):
        b.box((vx, -0.25, 4.35 + i * 0.27), (1.6, 0.08, 0.1), "metal", bevel=False)
    b.box_base((vx, -0.03, 1.2), (1.2, 0.06, 3.0), "fur_soot", bevel=False)


def _seg_arcade(b, x0, x1, H, k):
    """Blind arches: a dark brick wall set back 0.5 behind piers and round arch rings."""
    L = x1 - x0
    m = (x0 + x1) / 2
    b.box_base((m, (WALL_D + 0.5) / 2, 0), (L, WALL_D - 0.5, H), "fur_russet", bevel=False)
    n = max(1, round(L / 7.5))
    bay = L / n
    pier = 1.3
    spring = 8.0 if H > 15 else 5.5
    w = bay - pier
    for i in range(n + 1):
        x = x0 + i * bay
        xa, xb = max(x0, x - pier / 2), min(x1, x + pier / 2)
        b.box_base(((xa + xb) / 2, 0.25, 0), (xb - xa, 0.5, spring), "brick", bevel=False)
    for i in range(n):
        cx = x0 + (i + 0.5) * bay
        arch_fill(b, cx, w, spring, H, 0.0, 0.5, n=6)
        voussoirs(b, cx, spring, w / 2, -0.15, 0.5, n=9, thick=0.8, key_out=0.15)
        b.box((cx, 0.47, 1.6), (w - 0.2, 0.08, 0.7), "concrete_dark", bevel=False)            # a sill in each bay
    _course(b, x0, x1, 0.6, 1.2, "concrete_dark", 0.35)


def _seg_tiled(b, x0, x1, H, k):
    """White tiles below a teal band, brick above (the old station look)."""
    L = x1 - x0
    m = (x0 + x1) / 2
    b.box_base((m, WALL_D / 2, 0), (L, WALL_D, H), "brick", bevel=False)
    th = 7.0 if H > 15 else 5.0
    b.box_base((m, -0.06, 0), (L, 0.14, th), "fur_mist", bevel=False)
    b.box_base((m, -0.1, th - 1.0), (L, 0.2, 0.7), "sign_teal", bevel=False)
    b.box_base((m, -0.1, 0), (L, 0.2, 0.8), "paw_sewer", bevel=False)
    for i in range(1, max(2, round(L / 2.0))):                                    # grout lines
        x = x0 + i * L / max(2, round(L / 2.0))
        b.box_base((x, -0.14, 0.8), (0.08, 0.04, th - 1.8), "paving_grout", bevel=False)
    for z in (2.4, 4.0, 5.6)[: 2 + (th > 6)]:
        b.box((m, -0.145, z), (L, 0.04, 0.08), "paving_grout", bevel=False)
    _course(b, x0, x1, th + 0.2, 0.4, "concrete", 0.3)
    if H > 15:
        _course(b, x0, x1, 15.0, 0.4, "concrete", 0.3)


def _seg_pipes(b, x0, x1, H, k):
    """Brick with pipes run along it on brackets, a drop pipe and a gauge."""
    L = x1 - x0
    m = (x0 + x1) / 2
    b.box_base((m, WALL_D / 2, 0), (L, WALL_D, H), "brick", bevel=False)
    _course(b, x0, x1, 0.6, 1.2, "concrete_dark")
    _course(b, x0, x1, 12.0 if H > 15 else 9.0, 0.4, "concrete", 0.3)
    for (z, r, sw_) in ((5.2, 0.6, "dumpster_green"), (6.9, 0.4, "metal"), (9.6, 0.35, "rust"))[: 2 + (H > 15)]:
        b.cyl((m, -r - 0.1, z), r, L - 0.4, sw_, segments=10, bevel=False, rot=ry(90))
        for i in range(max(2, round(L / 4.5))):
            x = x0 + (i + 0.5) * L / max(2, round(L / 4.5))
            b.box((x, -(r + 0.1) / 2, z - r - 0.1), (0.3, r + 0.3, 0.2), IRON, bevel=False)          # brackets
    dx = m + L * (0.3 if k % 2 else -0.3)
    b.cyl((dx, -0.5, 2.7), 0.4, 5.0, "dumpster_green", segments=10, bevel=False)                  # the drop pipe
    b.cyl((dx, -0.5, 0.3), 0.55, 0.4, "metal", segments=10, bevel=False)
    b.cyl((m, -0.85, 3.2), 0.55, 0.2, "offwhite", segments=12, bevel=False, rot=rx(90))         # a gauge
    b.box((m + 0.1, -0.97, 3.3), (0.06, 0.04, 0.4), "bowl_red", bevel=False, rot=ry(30))


def _seg_stone(b, x0, x1, H, k):
    """The yard's retaining wall: big concrete blocks with moss, a coping on top."""
    L = x1 - x0
    m = (x0 + x1) / 2
    b.box_base((m, WALL_D / 2, 0), (L, WALL_D, H), "concrete", bevel=False)
    rows = int(H / 2.0)
    for j in range(1, rows):
        b.box((m, -0.03, j * 2.0), (L, 0.08, 0.12), "concrete_dark", bevel=False)
    for j in range(rows):
        off = 1.75 * (j % 2)
        x = x0 + 1.0 + off
        while x < x1 - 1.0:
            if (j + k) % 3 != 1:
                b.box_base((x, -0.03, j * 2.0 + 0.06), (0.12, 0.08, 1.88), "concrete_dark", bevel=False)
            x += 3.5
    for i, (fx, fz) in enumerate(((0.2, 1.2), (-0.3, 6.4), (0.35, 9.8))):
        if (i + k) % 2 == 0:
            b.ico((m + fx * L, -0.1, fz), 1.0, "fur_moss", subdivisions=1, scale=(1.6, 0.25, 0.8))


SEGMENTS = {"brick": _seg_brick, "arcade": _seg_arcade, "tiled": _seg_tiled, "pipes": _seg_pipes, "stone": _seg_stone}


def wall_run(mat, L, H, kinds, seed=0, open_top=False):
    """One wall run L long along local x, its face at y 0 (facing -Y) and back at WALL_D: segments about 16 long
    between brick piers. Returns the run and the local x of its piers (for lanterns)."""
    b = Builder()
    n = max(1, round(L / 17.0))
    P = 2.0
    seg = (L - (n - 1) * P) / n
    piers = []
    x = -L / 2
    for i in range(n):
        SEGMENTS[kinds[(i + seed) % len(kinds)]](b, x, x + seg, H, i + seed)
        x += seg
        if i < n - 1:
            c = x + P / 2
            b.box_base((c, (WALL_D - 0.7) / 2, 0), (P, WALL_D + 0.7, H), "brick", bevel=False)
            b.box_base((c, -0.55, 0), (P + 0.4, 0.5, 1.6), "concrete_dark", bevel=False)
            b.box((c, -0.5, H if open_top else H - 0.6), (P + 0.4, 0.5, 0.6), "concrete", bevel=False)
            piers.append(c)
            x += P
    if open_top:                                                                  # the open yard's coping
        b.box_base((0, WALL_D / 2 - 0.15, H), (L, WALL_D + 0.3, 0.5), "concrete_dark", bevel=False)
    return [b.finalize(N + "Wall", mat)], piers


def _line(s, mat, a0, a1, cuts, H, kinds, place, seed, open_top=False):
    """Fill a wall line from a0 to a1 (distance along it) around the cut intervals; place(t) -> (x, z, rot) puts a
    run's centre at distance t. Returns the area positions of the piers (with the run's turn)."""
    t, out = a0, []
    for (c0, c1) in sorted(cuts) + [(a1, a1)]:
        if c0 - t > 0.5:
            objs, piers = wall_run(mat, c0 - t, H, kinds, seed, open_top)
            x, z, rot = place((t + c0) / 2)
            s.put(objs, x, z, rot)
            out += [(turned(x, z, rot, -p, 0.0), rot) for p in piers]
            seed += 3
        t = c1
    return out


def town_wall(mat, L):
    """The gate side: a low brick wall with an iron railing on it, so the town sees in (7d)."""
    b = Builder()
    b.box_base((0, WALL_D / 2, 0), (L, WALL_D, 2.6), "brick", bevel=False)
    b.box_base((0, WALL_D / 2, 2.6), (L + 0.2, WALL_D + 0.3, 0.35), "concrete", bevel=False)
    n = max(2, round(L / 3.0))
    for k in range(n + 1):
        b.box_base((-L / 2 + 0.3 + k * (L - 0.6) / n, WALL_D / 2, 2.95), (0.3, 0.3, 2.6), IRON, bevel=False)
    for z in (4.0, 5.3):
        b.box((0, WALL_D / 2, z), (L - 0.4, 0.2, 0.2), "rarity_legend" if z > 5 else IRON, bevel=False)
    return [b.finalize(N + "TownWall", mat)]


def corner_pier(mat, H):
    b = Builder()
    b.box_base((0, 0, 0), (WALL_D, WALL_D, H + 0.8), "concrete", bevel=False)
    b.box_base((0, 0, H + 0.8), (WALL_D + 0.2, WALL_D + 0.2, 0.5), "concrete_dark", bevel=False)
    return [b.finalize(N + "CornerPier", mat)]


def corner_column(mat, sx):
    """A far corner of the tunnels (area space, sx 1 east, -1 west): a concrete column filling the corner of the wall
    band and standing 1.5 into the room, so neither wall's pipes and courses run into the other's brick. Base course
    and capital as the pillars have them."""
    b = Builder()
    for (d, h0, h1, sw_) in ((0.0, 0, WALL_H, "concrete"), (0.12, 0, 1.6, "concrete_dark"),
                             (0.12, WALL_H - 2.0, WALL_H - 1.2, "concrete_dark")):
        e = OUT - (0.02 if d else 0.0)                                            # trims stop short of the back
        x0, x1 = sorted((sx * (IN - 1.5 - d), sx * e))
        span(b, x0, x1, IN - 1.5 - d, e, h0, h1, sw_)
    return [b.finalize(N + "CornerColumn", mat)]


# ------------------------------------------------------------- water, pool ---
def canals(mat):
    """The yard's canal across the whole width (out under the side walls' grates), the central channel from the
    canal to the pool, the west hall's branch and the pool itself, each with a dark bed, water (Derek: `_Water`) and
    kerbs 1.2 above the walkway with a yellow edge; `_Barrier` walls on every kerb and round the pool, open only at
    the three bridges, and along the bridges' sides."""
    b, water, bar = Builder(), Builder(), Builder()
    cz0, cz1 = CANAL_Z - CANAL_HW, CANAL_Z + CANAL_HW
    ch0, ch1 = cz1, POOL[1] - POOL_R                              # the channel's water, canal to the weir
    xe = IN + WALL_D - 0.3                                        # into the outflow mouths
    for (x0, x1, z0, z1) in ((-xe, xe, cz0, cz1), (-CH_HW, CH_HW, ch0, ch1 - 0.6),
                             (BRANCH_END, -CH_HW, BRANCH_Z - BRANCH_HW, BRANCH_Z + BRANCH_HW)):
        span(b, x0, x1, z0, z1, 0, 0.04, "fur_ink")
        span(water, x0, x1, z0, z1, 0.04, 0.3, "fish_blue")
    span(b, -CH_HW, CH_HW, ch1 - 0.6, ch1, 0, 0.8, "concrete")                # the weir under the pool's lip
    span(water, -CH_HW + 0.2, CH_HW - 0.2, ch1 - 0.62, ch1 - 0.5, 0.3, 0.78, "fish_blue")    # spilling over it
    span(b, -CH_HW + 0.2, CH_HW - 0.2, ch1 - 1.4, ch1 - 0.62, 0.3, 0.36, "fish_belly")       # its foam

    def kerb(x0, x1, z0, z1, gaps=()):
        """A kerb with its yellow edge; each gap (a0, a1) along its length leaves the barrier open there."""
        span(b, x0, x1, z0, z1, 0, KERB_H, "concrete_dark")
        along_x = (x1 - x0) > (z1 - z0)
        if along_x:
            zm = (z0 + z1) / 2
            span(b, x0, x1, zm - 0.2, zm + 0.2, KERB_H, KERB_H + 0.05, "rarity_legend")
        else:
            xm = (x0 + x1) / 2
            span(b, xm - 0.2, xm + 0.2, z0, z1, KERB_H, KERB_H + 0.05, "rarity_legend")
        pieces = [(x0, x1, z0, z1)]
        if gaps:
            pieces = rects_minus(pieces, [(g[0], g[1], -1e9, 1e9) if along_x else (-1e9, 1e9, g[0], g[1])
                                          for g in gaps])
        for (a0, a1, c0, c1) in pieces:
            L = (a1 - a0) if along_x else (c1 - c0)
            n = max(1, round(L / 24.0))
            for i in range(n):
                if along_x:
                    span(bar, a0 + (a1 - a0) * i / n, a0 + (a1 - a0) * (i + 1) / n, c0, c1, 0, BARRIER_H, "offwhite")
                else:
                    span(bar, a0, a1, c0 + (c1 - c0) * i / n, c0 + (c1 - c0) * (i + 1) / n, 0, BARRIER_H, "offwhite")

    xk = IN - 0.7                                                               # clear of the mouths' jambs
    b1 = (B1X - 4.0, B1X + 4.0)
    for (z0, z1) in ((cz0 - KERB_W, cz0), (cz1, cz1 + KERB_W)):
        if z0 > CANAL_Z:                                                        # far kerb: the channel opens off it
            for (x0, x1) in ((-xk, -CH_HW), (CH_HW, B1X - 4.0), (B1X + 4.0, xk)):
                kerb(x0, x1, z0, z1)
        else:
            for (x0, x1) in ((-xk, B1X - 4.0), (B1X + 4.0, xk)):
                kerb(x0, x1, z0, z1)
    span(bar, b1[0] - 0.7, b1[0] - 0.1, cz0, cz1, 0, BARRIER_H, "offwhite")   # along the bridge's sides
    span(bar, b1[1] + 0.1, b1[1] + 0.7, cz0, cz1, 0, BARRIER_H, "offwhite")
    kz = POOL[1] - math.sqrt((POOL_R + KERB_W) ** 2 - (CH_HW + KERB_W / 2) ** 2) + 0.3   # where the ring takes over
    gaps = [(z - 2.5, z + 2.5) for z in (FB_Z, B2Z)]                            # the two catwalks
    for sx in (-1, 1):                                                          # the channel's kerbs
        x0, x1 = sorted((sx * CH_HW, sx * (CH_HW + KERB_W)))
        z0 = cz1 + KERB_W
        if sx < 0:                                                              # the branch opens off the west kerb
            for (a, c) in ((z0, BRANCH_Z - BRANCH_HW), (BRANCH_Z + BRANCH_HW, kz)):
                kerb(x0, x1, a, c, gaps=[g for g in gaps if a < g[0] < c])
        else:
            kerb(x0, x1, z0, kz, gaps=gaps)
    for z in (FB_Z, B2Z):                                                       # along the catwalks' sides
        for sz in (-1, 1):
            span(bar, -CH_HW, CH_HW, z + sz * 2.9 - 0.3, z + sz * 2.9 + 0.3, 0, BARRIER_H, "offwhite")
    for sz in (-1, 1):                                                          # the branch's kerbs and its end
        z0, z1 = sorted((BRANCH_Z + sz * BRANCH_HW, BRANCH_Z + sz * (BRANCH_HW + KERB_W)))
        kerb(BRANCH_END - KERB_W, -CH_HW - KERB_W, z0, z1)
    kerb(BRANCH_END - KERB_W, BRANCH_END, BRANCH_Z - BRANCH_HW, BRANCH_Z + BRANCH_HW)
    # the pool: bed and water on the slab, a ring of kerb blocks open toward the channel, a barrier on the ring
    px, pz = POOL
    b.cyl_base(bl(px, pz, FLOOR), POOL_R + 0.1, 0.04, "fur_ink", segments=28, bevel=False)
    water.cyl_base(bl(px, pz, FLOOR + 0.04), POOL_R + 0.1, 0.36, "fish_blue", segments=28, bevel=False)
    n = 32
    rr = POOL_R + KERB_W / 2
    chord = 2 * (POOL_R + KERB_W) * math.sin(PI / n) * 1.04
    gap = math.degrees(math.asin((CH_HW + KERB_W / 2) / rr)) + 1.0
    for k in range(n):
        a = 2 * PI * (k + 0.5) / n
        if abs((math.degrees(a) - 270 + 180) % 360 - 180) < gap:
            continue
        c = (bl(px, pz)[0] + rr * math.cos(a), pz + rr * math.sin(a))
        b.box_base((c[0], c[1], 0), (KERB_W, chord, KERB_H + 0.006 * (k % 2)), "concrete_dark", bevel=False,
                   rot=(a, "Z"))
        b.box_base((c[0], c[1], KERB_H + 0.006 * (k % 2)), (0.4, chord, 0.05), "rarity_legend", bevel=False,
                   rot=(a, "Z"))
        bar.box_base((c[0], c[1], 0), (KERB_W, chord, BARRIER_H), "offwhite", bevel=False, rot=(a, "Z"))
    span(bar, -0.5, 0.5, pz + POOL_R + KERB_W - 0.6, IN - 1.5, 0, 5.5, "offwhite")       # ring to the culvert, under its pipe
    return [b.finalize(N + "Canals", mat), water.finalize(N + "Canals_Water", mat),
            bar.finalize(N + "Canals_Barrier", mat)]


def culvert(mat):
    """The big culvert pipe out of the far wall (Derek 01:40: "needs to be attached to the wall"): a brick headwall
    built against the wall, the pipe through it, its water falling into the pool below, glow moss on the stone.
    Front at y 0 (facing -Y), back at 1.5 against the wall's face; base on the slab."""
    b, water, glow, foam = Builder(), Builder(), Builder(), Builder()
    W, D, H = CULVERT_W, 1.5 + WALL_D, WALL_H - FLOOR                            # through the wall band too
    b.box_base((0, D / 2, -FLOOR), (W - 0.04, D, H + FLOOR - 0.02), "brick", bevel=False)      # down past the slab
    for s in (-1, 1):                                                             # stone piers
        b.box_base((s * (W / 2 - 0.9), D / 2 - 0.31, 0.02 - FLOOR), (1.8, D + 0.58, H + FLOOR - 0.02), "concrete",
                   bevel=False)
    b.box_base((0, D / 2 - 0.21, H - 1.2), (W - 3.6, D + 0.38, 1.2), "concrete", bevel=False)        # coping band
    cz = 9.0
    b.ring((0, -0.1, cz), 4.6, 1.2, 0.5, "concrete", segments=20, rot=rx(90))                       # stone ring
    b.cyl((0, -1.1, cz), 3.4, 2.4, "concrete_dark", segments=20, rot=rx(90))                         # the pipe
    b.ring((0, -2.2, cz), 3.6, 0.5, 0.5, "metal", segments=20, rot=rx(90))                          # its rim
    b.cyl((0, -2.32, cz), 2.7, 0.04, "fur_ink", segments=20, rot=rx(90), bevel=False)               # dark inside
    water.box((0, -2.02, cz - 2.55), (3.6, 0.6, 0.4), "fish_blue", bevel=False)                       # pouring over
    water.box((0, -2.75, (cz - 2.55 + 0.35) / 2), (3.4, 0.5, cz - 2.55 - 0.35), "fish_blue", bevel=False)
    foam.ico((0, -3.4, 0.45), 2.2, "fish_belly", subdivisions=1, scale=(1.6, 1.0, 0.18))
    for (x, z) in ((-5.2, 15.5), (4.8, 3.2), (-4.0, 2.0)):
        glow.ico((x, -0.05, z), 0.6, "mint", subdivisions=1, scale=(1.2, 0.4, 0.8))
    for k in range(5):                                                            # iron rungs up the side
        b.box((W / 2 - 3.0, -0.25, 3.0 + k * 1.6), (1.2, 0.2, 0.2), IRON, bevel=False)
        for dx in (-0.5, 0.5):                                                    # set into the wall
            b.box((W / 2 - 3.0 + dx, -0.1, 3.0 + k * 1.6), (0.16, 0.3, 0.16), IRON, bevel=False)
    return [b.finalize(N + "Culvert", mat), water.finalize(N + "Culvert_Water", mat),
            glow.finalize(N + "Culvert_Glow", mat), foam.finalize(N + "Culvert_Decor", mat)]


# ---------------------------------------------------------------- bridges ---
def brick_bridge(mat):
    """The yard canal's only crossing: a brick arch bridge 8 wide along local Y, its deck 2.4 above the walkway with
    two steps of 0.8 at each end (8c: rises of at most 1), brick parapets 3 high and a lamp on each end pier. Base on
    the slab; its abutments reach down past the slab's cut edge to the area floor."""
    b, lamp = Builder(), Builder()
    D, half, H = 8.0, CANAL_HW + KERB_W, 2.4                                      # the deck spans water and kerbs
    b.box_base((0, 0, H - 0.8), (D, 2 * half, 0.8), "concrete", bevel=False)                     # the deck
    for s in (-1, 1):
        b.box_base((0, s * (half - KERB_W / 2), -FLOOR), (D, KERB_W, H - 0.8 + FLOOR), "brick", bevel=False)  # abutments
        b.box_base((0, s * (half + 0.5), 0), (D, 1.0, 1.6), "concrete", bevel=False)            # steps
        b.box_base((0, s * (half + 1.5), 0), (D, 1.0, 0.8), "concrete", bevel=False)
    a, zb, zc = CANAL_HW, -FLOOR + 0.25, H - 0.8 - 0.35                            # the low arch under each side
    for sx in (-1, 1):
        x = sx * (D / 2 - 0.3)
        n = 9
        for k in range(n):
            t0, t1 = PI * k / n, PI * (k + 1) / n
            y0, z0 = -a * math.cos(t0), zb + (zc - zb) * math.sin(t0)
            y1, z1 = -a * math.cos(t1), zb + (zc - zb) * math.sin(t1)
            ang = math.degrees(math.atan2(z1 - z0, y1 - y0))
            b.box((x, (y0 + y1) / 2, (z0 + z1) / 2), (0.7, math.hypot(y1 - y0, z1 - z0) + 0.15, 0.7),
                  "concrete", bevel=False, rot=rx(ang))
        for k in range(5):                                                        # spandrels over the arch
            y0, y1 = a * k / 5, a * (k + 1) / 5
            zt = zb + (zc - zb) * math.sqrt(max(0.0, 1 - (y1 / a) ** 2)) + 0.3
            for s in (-1, 1):
                if H - 0.8 - zt > 0.05:
                    b.box_base((x, s * (y0 + y1) / 2, zt), (0.6, y1 - y0, H - 0.8 - zt), "brick", bevel=False)
        b.box_base((sx * (D / 2 - 0.35), 0, H), (0.7, 2 * half, 3.0), "brick", bevel=False)       # parapets
        b.box_base((sx * (D / 2 - 0.35), 0, H + 3.0), (0.9, 2 * half + 0.2, 0.3), "concrete", bevel=False)
        for s in (-1, 1):                                                         # end piers with lamps
            b.box_base((sx * (D / 2 - 0.45), s * (half + 0.55), 0), (0.9, 1.1, H + 3.6), "concrete", bevel=False)
            b.box_base((sx * (D / 2 - 0.45), s * (half + 0.55), H + 3.6), (1.1, 1.3, 0.3), "concrete_dark",
                       bevel=False)
            b.box_base((sx * (D / 2 - 0.45), s * (half + 0.55), H + 4.6), (0.9, 0.9, 0.2), IRON, bevel=False)
            lamp.box_base((sx * (D / 2 - 0.45), s * (half + 0.55), H + 3.9), (0.7, 0.7, 0.7), "lamp_warm", bevel=False)
            for dx in (-0.4, 0.4):
                for dy in (-0.4, 0.4):
                    b.box_base((sx * (D / 2 - 0.45) + dx, s * (half + 0.55) + dy, H + 3.9), (0.1, 0.1, 0.7), IRON,
                               bevel=False)
    return [b.finalize(N + "BrickBridge", mat), lamp.finalize(N + "BrickBridge_Bulb", mat)]


def catwalk_bridge(mat):
    """The channel's only crossing, at the far end: a steel catwalk 5 wide along local Y, deck 3.2 above the walkway
    with three steps of 0.8 at each end, posts and rails 3.2 high (8c)."""
    b = Builder()
    half, H, W = 6.0, 3.2, 5.0
    b.box_base((0, 0, H - 0.25), (W, 2 * half, 0.25), "metal", bevel=False)
    for i in range(1, 12):
        b.box_base((0, -half + i * 2 * half / 12, H), (W - 0.1, 0.08, 0.03), "concrete_dark", bevel=False)
    for sx in (-1, 1):
        b.box_base((sx * 2.0, 0, H - 0.95), (0.35, 2 * half, 0.7), IRON, bevel=False)            # stringers
    for s in (-1, 1):
        for k in range(3):
            b.box_base((0, s * (half + 0.5 + k), 0), (W, 1.0, H - 0.8 * (k + 1)), "metal", bevel=False)
            b.box_base((0, s * (half + k + 0.08), H - 0.8 * (k + 1)), (W - 0.1, 0.16, 0.03), "rarity_legend",
                       bevel=False)
        for sx in (-1, 1):
            b.box_base((sx * 2.0, s * (half - 0.2), 0), (0.4, 0.4, H - 0.95), IRON, bevel=False)    # legs
    for sx in (-1, 1):                                                            # railings 3.2 high
        x = sx * (W / 2 - 0.15)
        for k in range(5):
            b.box_base((x, -half + 0.2 + k * (2 * half - 0.4) / 4, H), (0.25, 0.25, 3.2), "rust" if k == 2 else "metal",
                       bevel=False)
        b.box((x, 0, H + 3.1), (0.18, 2 * half, 0.18), "rarity_legend", bevel=False)
        b.box((x, 0, H + 1.6), (0.14, 2 * half, 0.14), "metal", bevel=False)
        for s in (-1, 1):                                                         # handrails down the steps
            ang = math.degrees(math.atan2(-2.4, 3.0)) * s
            b.box((x, s * (half + 1.5), H + 3.1 - 1.2), (0.16, math.hypot(3.0, 2.4), 0.16), "rarity_legend",
                  bevel=False, rot=rx(-ang))
            b.box_base((x, s * (half + 2.85), 0), (0.25, 0.25, H + 3.1 - 2.4), "metal", bevel=False)
    return [b.finalize(N + "CatwalkBridge", mat)]


# ------------------------------------------------------- front, cross wall ---
def tunnel_front(mat):
    """The tunnel front across the yard (area space, its yard face at FACADE_Z): brick 24 high with stone piers, a
    cornice under the roof's edge, and three arches: the walk-in arch over the bridge (east), the channel's arch
    with bars down into the water (centre), and a barred arch you can see the west hall through. A sign over the
    channel arch. Returns the front, its lamps and its barrier (the bars' openings)."""
    rb = RB()
    b, bar, lamp = rb.b, Builder(), Builder()
    z0, z1 = FACADE_Z, FACADE_Z + FACADE_T
    ops = [(-CH_HW - KERB_W, CH_HW + KERB_W, 5.2, "channel"), (B1X - ARCH_W / 2, B1X + ARCH_W / 2, ARCH_SPRING, "walk"),
           (-B1X - ARCH_W / 2, -B1X + ARCH_W / 2, ARCH_SPRING, "bars")]
    holes = [(a - 1.1, c + 1.1, -1e9, 1e9) for (a, c, _, _) in ops]

    def courses(xa, xc, za, zc, h0, h1, swatch):
        """A course across the front, broken at the arches."""
        for (x0, x1, _, _) in rects_minus([(xa, xc, za, zc)], holes):
            span(b, x0, x1, za, zc, h0, h1, swatch)

    x = -OUT                                                                      # through the walls' band too
    for (a, c) in sorted([(o[0], o[1]) for o in ops]) + [(OUT, OUT)]:
        if a - x > 0.05:
            span(b, x, a, z0, z1, 0, WALL_H, "brick")
        x = c
    for (a, c, spring, kind) in ops:
        w = c - a
        cx = (a + c) / 2
        r = w / 2
        for k in range(8):                                                       # the wall over each arch
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
            b.box((bx, by, bz), (L, z1 - z0 + 0.8 + 0.38 * key, 1.4 + 0.3 * key), "concrete_dark" if key else "concrete",
                  bevel=False, rot=ry(-(90 - math.degrees(t))))
        for s in (-1, 1):                                                         # imposts
            span(b, cx + s * (r + 0.1), cx + s * (r + 1.1), z0 - 0.5, z1 + 0.5, spring - 0.25, spring + 0.25,
                 "concrete_dark")
        if kind == "walk":
            span(b, a, c, z0, z1, 0, FLOOR, "concrete_dark")                       # the threshold
            continue
        lo, ba, bc = (0.0, -CH_HW, CH_HW) if kind == "channel" else (FLOOR, a, c)  # iron bars, between the kerbs
        m = int((bc - ba) / 0.8)
        for i in range(m + 1):
            xx = ba + 0.4 + i * (bc - ba - 0.8) / m
            h = spring + math.sqrt(max(0.0, r * r - (xx - cx) ** 2)) - 0.2
            span(b, xx - 0.13, xx + 0.13, z0 + 1.0, z0 + 1.26, lo, h, IRON)
        for h in (1.4, spring - 1.0):
            span(b, ba + 0.05, bc - 0.05, z0 + 0.95, z0 + 1.31, lo + h - 0.15, lo + h + 0.15, IRON)
        span(bar, ba, bc, z0 + 0.8, z0 + 1.5, KERB_H if kind == "channel" else 0, spring + r, "offwhite")
        if kind == "bars":
            span(b, cx - 0.4, cx + 0.4, z0 + 0.6, z0 + 0.95, 2.0, 2.8, "brass")
    for x in (-74.0, -60.0, -24.0, -14.0, 14.0, 24.0, 62.0, 76.0):                # stone piers on the yard face
        span(b, x - 1.0, x + 1.0, z0 - 0.7, z0, 0, WALL_H - 1.2, "concrete")
        span(b, x - 1.2, x + 1.2, z0 - 0.9, z0, 0, 1.6, "concrete_dark")
    span(b, -IN, IN, z0 - 0.8, z0, WALL_H - 1.2, WALL_H, "concrete")             # cornice
    span(b, -IN, IN, z0 - 0.5, z0, WALL_H - 2.0, WALL_H - 1.2, "concrete_dark")
    courses(-IN + 1.5, IN - 1.5, z0 - 0.3, z0, 0, 1.2, "concrete_dark")          # base courses
    courses(-IN + 1.5, IN - 1.5, z1, z1 + 0.25, 0, 1.2, "concrete_dark")
    courses(-IN + 1.5, IN - 1.5, z0 - 0.3, z0, YARD_H, YARD_H + 0.4, "concrete")  # in line with the yard walls' tops
    # the sign over the channel arch
    span(b, -9.0, 9.0, z0 - 0.5, z0, 12.6, 16.6, "sign_teal")
    span(b, -9.4, 9.4, z0 - 0.45, z0 - 0.05, 12.2, 17.0, IRON)
    tw = text_width("THE SEWER", 0.5)
    rb.text("THE SEWER", (tw / 2, 13.35, z0 - 0.54), 0.5, 0.1, "offwhite", right=(-1, 0, 0))
    for x in (B1X - 9.4, B1X + 9.4, -B1X - 9.4, -B1X + 9.4):                   # lanterns by the arches
        bx, by, _ = bl(x, z0)
        b.box_base((bx, by - 0.3, 7.0), (2.0, 0.6, 2.0), "brick", bevel=False)
        b.box((bx, by - 0.9, 8.3), (0.2, 0.9, 0.2), IRON, bevel=False)
        lamp.box((bx, by - 1.4, 7.94), (0.7, 0.7, 0.88), "lamp_warm", bevel=False)
        b.pyramid((bx, by - 1.4, 8.4), 0.95, 0.4, IRON)
        b.box((bx, by - 1.4, 7.45), (0.85, 0.85, 0.12), IRON, bevel=False)
    return [b.finalize(N + "TunnelFront", mat), lamp.finalize(N + "TunnelFront_Bulb", mat),
            bar.finalize(N + "TunnelFront_Barrier", mat)]


def cross_wall(mat):
    """The east hall's cross wall (area space): brick to the roof from the channel's kerb to x 66, then one archway
    to the east wall (the only way on). Both faces have a base course, a string course and stone pilasters, the
    market face a JUNK MARKET sign over the stalls; the arch has a voussoir ring right through."""
    rb = RB()
    b = rb.b
    z0, z1 = E1_Z, E1_Z + E1_T
    x0 = CH_HW + KERB_W
    span(b, x0, E1_GAP, z0, z1, 0, WALL_H, "brick")
    for (za, zb) in ((z0 - 0.3, z0), (z1, z1 + 0.3)):
        span(b, x0, E1_GAP - 0.6, za, zb, 0, 1.2, "concrete_dark")                 # into the arch's jamb
        span(b, x0, E1_GAP, za, zb, 14.0, 14.4, "concrete")
    xe = IN - 1.2                                                                 # the arch's east jamb
    w = xe - E1_GAP
    cx, r, spring = (E1_GAP + xe) / 2, w / 2, 8.0
    for k in range(9):
        h0, h1 = spring + r * k / 9, spring + r * (k + 1) / 9
        hw = math.sqrt(max(0.0, r * r - ((h0 + h1) / 2 - spring) ** 2))
        if r - hw > 0.05:
            for s in (-1, 1):
                span(b, cx + s * hw, cx + s * r, z0, z1, h0, h1, "brick")
    span(b, E1_GAP, xe, z0, z1, spring + r, WALL_H, "brick")
    span(b, xe, OUT, z0 - 0.4, z1 + 0.4, 0, WALL_H, "concrete")                   # into the east wall's band
    n, rm = 15, r - 0.3 + 0.6
    L = 2 * rm * math.sin(PI / n / 2) * 1.15
    for k in range(n):
        t = PI * (k + 0.5) / n
        key = k == n // 2
        bx, by, bz = bl(cx + rm * math.cos(t), (z0 + z1) / 2, spring + rm * math.sin(t))
        b.box((bx, by, bz), (L, z1 - z0 + 0.8 + 0.1 * key, 1.2 + 0.3 * key), "concrete_dark" if key else "concrete",
              bevel=False, rot=ry(-(90 - math.degrees(t))))
    span(b, E1_GAP - 1.2, E1_GAP, z0 - 0.4, z1 + 0.4, 0, spring, "concrete")         # the arch's west jamb
    span(b, E1_GAP - 1.4, E1_GAP + 0.2, z0 - 0.5, z1 + 0.5, spring - 0.25, spring + 0.25, "concrete_dark")
    for x in (12.0, 25.0, 42.0, 56.0):                                   # pilasters, both faces (the beam at 25 lands on one)
        for (za, zb) in ((z0 - 0.4, z0), (z1, z1 + 0.4)):
            span(b, x - 0.8, x + 0.8, za, zb, 0, WALL_H, "concrete")
    span(b, 26.4, 40.6, z0 - 0.5, z0, 11.4, 14.0, "sign_teal")                    # the market's sign
    span(b, 26.05, 40.95, z0 - 0.45, z0 - 0.05, 11.05, 14.35, IRON)
    tw = text_width("JUNK MARKET", 0.3)
    rb.text("JUNK MARKET", (33.5 + tw / 2, 11.95, z0 - 0.54), 0.3, 0.1, "offwhite", right=(-1, 0, 0))
    return [b.finalize(N + "CrossWall", mat)]


# -------------------------------------------------------------- the roof ---
def roof(mat, piers=()):
    """The roof over the tunnels (area space), its underside at WALL_H: a slab with grated skylights over the channel,
    the pool and each hall (so daylight falls in), brick beams under it on brick pillars, cage lamps hanging from the
    beams (_Bulb, lit at night), and on top the skylights' curbs and a few vent stacks. A beam that meets a wall
    pier (piers: their area positions) stops at the face of the pier's cap."""
    b, lamp = Builder(), Builder()

    def stop(along, at, end):
        """Where a beam at `at` running to the wall at `end` (+-IN) along z (along "z") or x stops."""
        for (px, pz) in piers:
            a, w = (px, pz) if along == "z" else (pz, px)
            if abs(a - at) < 2.4 and abs(w - end) < 1.0:
                return end - math.copysign(0.75, end)
        return end

    z_front = FACADE_Z
    rects = rects_minus([(-OUT, OUT, z_front, OUT)], [(a, c, d, e) for (a, c, d, e) in SKYLIGHTS])
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
                z = z0 + k * (z1 - z0) / n
                span(b, x0, x1, z - 0.15, z + 0.15, WALL_H + 0.3, WALL_H + 0.9, IRON)
            else:
                x = x0 + k * (x1 - x0) / n
                span(b, x - 0.15, x + 0.15, z0, z1, WALL_H + 0.3, WALL_H + 0.9, IRON)
        if along_z:
            span(b, (x0 + x1) / 2 - 0.2, (x0 + x1) / 2 + 0.2, z0, z1, WALL_H + 0.2, WALL_H + 0.3, IRON)
        else:
            span(b, x0, x1, (z0 + z1) / 2 - 0.2, (z0 + z1) / 2 + 0.2, WALL_H + 0.2, WALL_H + 0.3, IRON)
    zs = sorted({z for (_, z) in PILLARS})
    xs = sorted({x for (x, _) in PILLARS})
    for x in xs:                                                                  # beams along z on the pillars
        far = stop("z", x, IN)
        e1 = 0.4 if x == 25.0 else 0.0                                            # onto the cross wall's pilaster
        for (za, zc) in (((FACADE_Z + FACADE_T, E1_Z - e1), (E1_Z + E1_T + e1, far)) if x > 0 else
                         ((FACADE_Z + FACADE_T, far),)):
            span(b, x - 0.8, x + 0.8, za, zc, WALL_H - 1.4, WALL_H, "brick")
    for z in zs:                                                                  # and across, hall by hall
        for (x0, x1) in ((stop("x", z, -IN), -CH_HW - KERB_W - 1.0), (CH_HW + KERB_W + 1.0, stop("x", z, IN))):
            span(b, x0, x1, z - 0.8, z + 0.8, WALL_H - 1.4 - 0.006, WALL_H - 0.006, "brick")
    for (x, z) in PILLARS:                                                        # the pillars
        span(b, x - 1.2, x + 1.2, z - 1.2, z + 1.2, FLOOR, WALL_H - 1.4, "brick")
        span(b, x - 1.5, x + 1.5, z - 1.5, z + 1.5, FLOOR, FLOOR + 1.2, "concrete")
        span(b, x - 1.45, x + 1.45, z - 1.45, z + 1.45, WALL_H - 2.2, WALL_H - 1.4, "concrete")
    for (x, z) in [(sx * 45.0, z) for sx in (-1, 1) for z in (-30.0, 24.0, 62.0)]:  # cage lamps off the beams
        span(b, x - 0.08, x + 0.08, z - 0.08, z + 0.08, WALL_H - 5.0, WALL_H - 1.4, IRON)
        span(b, x - 0.7, x + 0.7, z - 0.7, z + 0.7, WALL_H - 5.2, WALL_H - 5.0, IRON)
        lamp.box_base(bl(x, z, WALL_H - 6.8), (0.9, 0.9, 1.6), "lamp_warm", bevel=False)
        for dx in (-0.55, 0.55):
            for dz in (-0.55, 0.55):
                span(b, x + dx - 0.06, x + dx + 0.06, z + dz - 0.06, z + dz + 0.06, WALL_H - 6.8, WALL_H - 5.2, IRON)
        span(b, x - 0.7, x + 0.7, z - 0.7, z + 0.7, WALL_H - 7.0, WALL_H - 6.8, IRON)
    beam_zs = zs
    for x in (-80.0, -14.0, 14.0, 80.0):                                          # pipe runs under the roof
        runs = ((FACADE_Z + FACADE_T, E1_Z), (E1_Z + E1_T, IN)) if x > 0 else ((FACADE_Z + FACADE_T, IN),)
        for (za, zc) in runs:
            za, zc = za + 0.02, zc - 0.02
            b.cyl(bl(x, (za + zc) / 2, WALL_H - 2.0), 0.55, zc - za, "dumpster_green", segments=10, bevel=False,
                  rot=rx(90))
            for zz in (za + 0.31, zc - 0.31):                                        # flanges at the walls
                b.cyl(bl(x, zz, WALL_H - 2.0), 0.75, 0.6, "metal", segments=10, bevel=False, rot=rx(90))
            k = int((zc - za) / 9.0)
            for i in range(1, k):                                                  # hangers, clear of the beams
                zz = za + i * (zc - za) / k
                if any(abs(zz - bz) < 1.6 for bz in beam_zs):
                    continue
                span(b, x - 0.08, x + 0.08, zz - 0.08, zz + 0.08, WALL_H - 1.45, WALL_H, IRON)
                span(b, x - 0.7, x + 0.7, zz - 0.12, zz + 0.12, WALL_H - 1.6, WALL_H - 1.45, IRON)
    for (x, z) in ((-70.0, 0.0), (70.0, 70.0), (-20.0, 80.0), (60.0, -30.0)):    # vent stacks on top
        b.cyl_base(bl(x, z, WALL_H + ROOF_T), 0.8, 3.5, "metal", segments=10, bevel=False)
        b.cyl_base(bl(x, z, WALL_H + ROOF_T + 3.5), 1.2, 0.6, "metal", segments=10, bevel=False, radius2=0.4)
    return [b.finalize(N + "Roof", mat), lamp.finalize(N + "Roof_Bulb", mat)]


# ---------------------------------------------------------------- the walls ---
def _walls(s, mat):
    """The outer walls just inside WorldBuilder's: the yard's stone and tile walls (14 high, open to the sky), the
    tunnels' brick walls (22, up to the roof) in brick, blind arcade, tile and pipe runs between piers, finished
    tunnel mouths, and on the town side a low wall with a railing. Returns the pier positions for lanterns."""
    piers = []
    yard = ("stone", "tiled", "stone", "brick")
    hall = ("brick", "arcade", "pipes", "tiled", "arcade", "brick", "pipes")
    m = MOUTH_W / 2 + 2.0
    wm = CANAL_HW + 2.0
    # the side walls: east (x +IN, facing -X) and west (x -IN, facing +X), the yard part then the tunnels
    for sx, rot, seed in ((1, 90, 0), (-1, -90, 2)):
        s.put(tunnel_mouth(mat, "water", w=2 * CANAL_HW, H=YARD_H, spring=5.0), sx * IN, CANAL_Z, rot)
        piers += _line(s, mat, -IN, FACADE_Z, [(CANAL_Z - wm, CANAL_Z + wm)], YARD_H, yard,
                       lambda t, sx=sx, rot=rot: (sx * IN, t, rot), seed, open_top=True)
        mouths = [(40.0, "door")] if sx > 0 else [(-12.0, "bars"), (58.0, "bars")]
        for (z, kind) in mouths:
            s.put(tunnel_mouth(mat, kind), sx * IN, z, rot)
        cuts = [(z - m, z + m) for (z, _) in mouths]
        if sx > 0:                                                                # the cross wall's end
            cuts.append((E1_Z - 0.4, E1_Z + E1_T + 0.4))
        piers += _line(s, mat, FACADE_Z + FACADE_T, IN - 1.5, cuts, WALL_H, hall,
                       lambda t, sx=sx, rot=rot: (sx * IN, t, rot), seed + 1)
        s.put(corner_pier(mat, YARD_H), sx * (IN + WALL_D / 2), -(IN + WALL_D / 2), 0)
        s.put(corner_column(mat, sx), 0, 0, 0)
    # the far wall (z +IN, facing -Z), between the corner columns, round the mouths and the culvert's headwall
    far_mouths = [(-50.0, "bars"), (50.0, "door")]
    for (x, kind) in far_mouths:
        s.put(tunnel_mouth(mat, kind), x, IN, 0)
    piers += _line(s, mat, -(IN - 1.5), IN - 1.5, [(x - m, x + m) for (x, _) in far_mouths] + [(-CULVERT_W / 2, CULVERT_W / 2)],
                   WALL_H, hall, lambda t: (t, IN, 0), 4)
    # the town side: low wall and railing either side of the gate
    for sx in (-1, 1):
        L = IN - GATE_HALF
        s.put(town_wall(mat, L), sx * (GATE_HALF + L / 2), -IN, 180)
    bar = Builder()
    span(bar, -OUT, OUT, IN, OUT, 0, BARRIER_H, "offwhite")                            # far
    for sx in (-1, 1):
        span(bar, sx * IN, sx * OUT, -IN, IN, 0, BARRIER_H, "offwhite")                # sides
        span(bar, sx * GATE_HALF, sx * OUT, -OUT, -IN, 0, BARRIER_H, "offwhite")       # town side
    s.put([bar.finalize(N + "Walls_Barrier", mat)], 0, 0, 0)
    return piers


# ------------------------------------------------------------------- ground ---
def _ground():
    """The tiled floor slab with the waterways and inner walls cut out, tile lines on it, and darker towpaths along
    the banks (8b: a walkway follows each bank)."""
    g = Builder()
    rects = rects_minus([(-IN, IN, -IN, IN)], [CANAL_RECT, CHANNEL_RECT, BRANCH_RECT, FACADE_RECT, E1_RECT])
    for (x0, x1, z0, z1) in rects:
        span(g, x0, x1, z0, z1, 0, FLOOR, "concrete")
        for x in range(-88, 89, 8):
            if x0 + 0.5 < x < x1 - 0.5:
                span(g, x - 0.075, x + 0.075, z0, z1, FLOOR, FLOOR + 0.02, "concrete_dark")
        for z in range(-88, 89, 8):
            if z0 + 0.5 < z < z1 - 0.5:
                span(g, x0, x1, z - 0.075, z + 0.075, FLOOR, FLOOR + 0.026, "concrete_dark")
    tow = [(-IN, IN, CANAL_RECT[2] - 3.0, CANAL_RECT[2]), (-IN, IN, CANAL_RECT[3], CANAL_RECT[3] + 3.0)]
    for sx in (-1, 1):
        a, c = sorted((sx * (CH_HW + KERB_W), sx * (CH_HW + KERB_W + 3.0)))
        tow.append((a, c, FACADE_Z + FACADE_T, POOL[1] - 12.0))
    tow = rects_minus(tow, [E1_RECT, FACADE_RECT, BRANCH_RECT, CHANNEL_RECT])
    for i, (x0, x1, z0, z1) in enumerate(tow):
        span(g, x0, x1, z0, z1, FLOOR, FLOOR + 0.032 + 0.004 * (i % 2), "paving_grout")
    return g


# ------------------------------------------------------------------ the set ---
def _zone(x, z):
    """near: the yard and the market (the first half of the walk); deep: everything past the cross wall's arch."""
    return "near" if z < FACADE_Z or (x > CH_HW and z < E1_Z) else "deep"


def _spot(s, label, x, z, h=0.0, turn=None):
    p = [round(x, 2), round(FLOOR + h, 2), round(z, 2), _zone(x, z)]
    if turn is not None:
        p.append(turn)
    s.points.setdefault(label, []).append(p)


def walk_grid(step=1.0, margin=1.0):
    """Shortest walking distance from the gate to every floor cell (8 neighbours), round the blockers: the waterways
    except on the bridges, the tunnel front except the walk-in arch, the cross wall except its archway, the pool and
    the pillars. Returns (dist dict keyed by cell, cell function)."""
    import heapq
    blocks = [(r[0] - margin, r[1] + margin, r[2] - margin, r[3] + margin) for r in
              rects_minus([CANAL_RECT], [(B1X - 3.4, B1X + 3.4, -1e9, 1e9)]) +
              rects_minus([CHANNEL_RECT], [(-1e9, 1e9, z - 2.2, z + 2.2) for z in (FB_Z, B2Z)]) +
              [BRANCH_RECT] + rects_minus([FACADE_RECT], [(B1X - ARCH_W / 2, B1X + ARCH_W / 2, -1e9, 1e9)]) + [E1_RECT] +
              [(x - 1.5, x + 1.5, z - 1.5, z + 1.5) for (x, z) in PILLARS]]

    def free(x, z):
        if abs(x) > IN - margin or abs(z) > IN - 0.1:
            return False
        if math.hypot(x - POOL[0], z - POOL[1]) < POOL_R + KERB_W + margin:
            return False
        return not any(a <= x <= c and d <= z <= e for (a, c, d, e) in blocks)

    n = int(2 * IN / step)

    def cell(x, z):
        return (round((x + IN) / step - 0.5), round((z + IN) / step - 0.5))

    def pos(i, j):
        return -IN + (i + 0.5) * step, -IN + (j + 0.5) * step

    start = cell(0.0, -IN + 1.0)
    dist = {start: 0.0}
    q = [(0.0, start)]
    nb = [(1, 0, 1), (-1, 0, 1), (0, 1, 1), (0, -1, 1), (1, 1, 1.4142), (1, -1, 1.4142), (-1, 1, 1.4142), (-1, -1, 1.4142)]
    while q:
        d, (i, j) = heapq.heappop(q)
        if d > dist.get((i, j), 1e18):
            continue
        for (di, dj, w) in nb:
            a, c = i + di, j + dj
            if not (0 <= a < n and 0 <= c < n) or not free(*pos(a, c)):
                continue
            nd = d + w * step
            if nd < dist.get((a, c), 1e18):
                dist[(a, c)] = nd
                heapq.heappush(q, (nd, (a, c)))
    return dist, cell


def build_set(mat):
    s = Set(SET)

    def put(objs, x, z, rot=0.0, h=0.0):
        return s.put(objs, x, z, rot, FLOOR + h)

    piers = _walls(s, mat)
    s.put(canals(mat), 0, 0, 0)
    s.put(tunnel_front(mat), 0, 0, 0)
    s.put(cross_wall(mat), 0, 0, 0)
    s.put(roof(mat, [p for (p, _) in piers]), 0, 0, 0)
    put(culvert(mat), POOL[0], IN - 1.5, 0)
    put(brick_bridge(mat), B1X, CANAL_Z, 0)
    _spot(s, "bridge", B1X, CANAL_Z, h=2.4)
    put(catwalk_bridge(mat), 0, B2Z, 90)
    _spot(s, "bridge", 0, B2Z, h=3.2)
    put(catwalk_bridge(mat), 0, FB_Z, 90)                                       # out to the yard's west bank
    # wall lanterns on every other pier, 7 up (_Bulb, lit at night)
    for i, ((x, z), rot) in enumerate(piers):
        if i % 2 == 0:
            ax, az = turned(x, z, rot, 0.0, -1.3)
            s.put(sw.wall_lantern(mat), ax, az, rot, FLOOR + 6.6)

    # ---- the yard (near): the gate plaza, the bridge, the bank in front of the tunnels
    put(sw.puddle(mat), 10, -71, 0)
    put(sw.puddle(mat), -24, -76, 40)
    _spot(s, "puddle", -24, -73)
    put(sw.grate(mat), -38, -78, 0)
    _spot(s, "trap_grate", -38, -78, turn=0)
    put(sw.drain_pipe(mat), IN - 2.4, -78, 90)                                   # 0.4 off the wall's courses
    _spot(s, "trap_drain_pipe", *turned(IN - 2.4, -78, 90, -1.0, -2.4), turn=90)
    for (x, z) in ((76, -82), (78.5, -84)):
        put(sw.barrel(mat), x, z, 0)
    _spot(s, "barrel", 73, -79)
    put(sw.tyre_stack(mat), 62, -82, 20)
    _spot(s, "tyres", 60, -78)
    for (x, z, r) in ((36, -74, 0), (38.5, -76.5, 20), (52, -74, 0)):
        put(sw.traffic_cone(mat), x, z, r)
    _spot(s, "cones", 30, -76)
    put(alleyway.build_crate_stack(mat), -72, -82, 30)
    _spot(s, "crates", -66, -78)
    put(sw.suitcase_stack(mat), -82, -70, 80)
    _spot(s, "suitcases", -78, -72.5)
    put(sw.steam_vent(mat), 26, -82, 0)
    put(sw.glow_mushrooms(mat), -56, -73, 0)
    _spot(s, "glow_mushrooms", -56, -76.5)
    put(sw.steam_vent(mat), -16, -51, 0)
    for (x, z) in ((-30, -44), (-27.6, -45.5)):
        put(sw.barrel(mat), x, z, 0)
    for (x, z) in ((20, -46), (-20, -47), (-66, -47), (72, -46)):
        _spot(s, "bank", x, z)
    _spot(s, "arch", -B1X, -44.5)
    put(sw.tyre_stack(mat), 80, -44, 0)

    # ---- the market (near): stalls along the cross wall, bunting over the hall
    for x in (20.0, 34.0, 48.0):                                                  # umbrellas clear of the wall
        put(sw.junk_stall(mat), x, E1_Z - 5.4, 0)
        _spot(s, "stall", x, E1_Z - 8.0)

    def bunting(x0, z0, x1, z1, h=12.0, sag=2.2):
        """Cap bunting hooked between two pillars."""
        L = math.hypot(x1 - x0, z1 - z0) - 2.4
        put(sw.cap_bunting(mat, L, sag, hooks=True), (x0 + x1) / 2, (z0 + z1) / 2,
            math.degrees(math.atan2(z1 - z0, x1 - x0)), h=h)

    bunting(25, -30, 65, -30)
    put(sw.crate_deck(mat), 74, -24, 30)
    _spot(s, "deck", *turned(74, -24, 30, -0.3, 0.6), h=2.15)
    put(sw.barrel(mat), 82, -32, 0)
    put(sw.suitcase_stack(mat), 82.5, -12, -90)
    put(alleyway.build_crate_stack(mat), 12, -12, -15)
    for (x, z) in ((24, -22), (56, -12)):
        _spot(s, "market", x, z)
    put(sw.glow_mushrooms(mat), 12, -30, 0)
    _spot(s, "glow_mushrooms", 12, -26.5)

    # ---- the cat houses (deep): past the cross wall's arch, round a square under the skylight
    sq = (42.0, 44.0)
    for (x, z, fn) in ((30, 30, sw.can_house), (54, 30, sw.teapot_house), (28, 56, sw.box_house),
                       (56, 58, sw.can_house)):
        r = face(x, z, *sq)
        put(fn(mat), x, z, r)
        _spot(s, "house", *turned(x, z, r, 0, -3.6))
    for (x, z, fn) in ((42, 66, sw.teapot_house), (64, 44, sw.box_house)):          # two more round the square
        put(fn(mat), x, z, face(x, z, *sq))
    bunting(25, 24, 25, 62, h=11.0, sag=1.8)
    for (x, z) in ((42, 38), (36, 46)):
        _spot(s, "square", x, z)
    put(sw.rails(mat), 80, 60, 90)
    put(sw.cart(mat), 80, 64, 90, h=0.25)
    _spot(s, "cart", 80, 64, h=3.25)
    put(sw.valve_wheel(mat), 34, IN - 1.4, 0)                                   # between the far wall's piers
    _spot(s, "valve", 34, IN - 4.6)
    put(sw.pipe_large(mat), 66, 78, 0)
    _spot(s, "pipe_end", 73.6, 78)
    put(sw.pipe_elbow(mat), 18, 80, 0)
    put(sw.graffiti(mat), 66, IN - 1.4, 0)
    put(sw.glow_mushrooms(mat), 20, 70, 0)
    _spot(s, "glow_mushrooms", 20, 66.5)
    put(sw.glow_mushrooms(mat), 72, 14, 0)
    _spot(s, "glow_mushrooms", 72, 17.5)
    put(sw.steam_vent(mat), 48, 72, 0)
    put(sw.grate(mat), 70, 40, 0)
    _spot(s, "trap_grate", 70, 40, turn=0)
    _spot(s, "catwalk_foot", 12, 46)
    put(sw.tyre_stack(mat), 82, 30, 0)
    _spot(s, "pool", 14, 74)                                                    # by the pool, under its skylight
    put(sw.puddle(mat), 12, 30, 0)

    # ---- the throne room (deep): over the catwalk, the west hall's far end
    put(sw.throne(mat), -46, 80, 0)
    _spot(s, "throne", *turned(-46, 80, 0, 0, 0.1), h=2.9)
    put(sw.pipe_organ(mat), -32, IN - 1.4, 0)
    _spot(s, "organ", -32, IN - 3.8)
    put(sw.toy_pile(mat), -62, 74, 0)
    _spot(s, "toy_pile", -62, 74)
    put(sw.lost_lounge(mat), -66, 44, 0)
    _spot(s, "sofa", *turned(-66, 44, 0, -1.2, 1.3), h=1.48)                     # on the right-hand cushion
    put(sw.yarn_trolley(mat), -30, 40, 30)
    _spot(s, "trolley", -30, 40, h=0.6)
    bunting(-25, 62, -65, 62)
    put(sw.suitcase_stack(mat), -80, 82, 80)
    _spot(s, "suitcases", -76, 79.5)
    put(sw.glow_mushrooms(mat), -12, 30, 0)
    _spot(s, "glow_mushrooms", -15.5, 30)
    put(sw.drain_pipe(mat), -IN + 2.4, 23, -90)                                  # on a plain brick run
    _spot(s, "trap_drain_pipe", *turned(-IN + 2.4, 23, -90, -1.0, -2.4), turn=-90)
    _spot(s, "catwalk_foot", -12, 54)
    for (x, z) in ((-46, 66), (-20, 70)):
        _spot(s, "throne_room", x, z)
    put(sw.steam_vent(mat), -50, 52, 0)
    for (x, z) in ((-80, 64), (-77.6, 65.5)):
        put(sw.barrel(mat), x, z, 0)
    put(alleyway.build_crate_stack(mat), -56, 30, 15)
    put(sw.tyre_stack(mat), -83, 40, 0)
    put(sw.puddle(mat), -40, 28, 0)

    # ---- the far chamber (deep): the beached boat and raft by the branch, the hammock, a deck
    put(sw.bathtub_boat(mat), -28, 4.0, 90)
    _spot(s, "boat", -28, 4.0, h=1.42)                                          # in the tub
    put(sw.crate_raft(mat), -40, 3.5, 80)
    _spot(s, "raft", *turned(-40, 3.5, 80, 0.6, 0.4), h=1.8)                    # on the big crate
    put(sw.rubber_ducks(mat), -20, BRANCH_Z, 90, h=-0.1)
    put(sw.pipe_hammock(mat), -82, -26, 90)
    _spot(s, "hammock", *turned(-82, -26, 90, -0.3, 0), h=2.0)
    put(sw.crate_deck(mat), -38, -22, -20)
    _spot(s, "deck", *turned(-38, -22, -20, -0.3, 0.6), h=2.15)
    bunting(-25, -30, -65, -30)
    put(sw.glow_mushrooms(mat), -60, -6, 0)
    _spot(s, "glow_mushrooms", -60, -2.5)
    put(sw.glow_mushrooms(mat), -14, -32, 0)
    _spot(s, "glow_mushrooms", -17.5, -32)
    put(sw.tyre_stack(mat), -70, -32, 0)
    for (x, z) in ((-46, -18), (-60, 20)):
        _spot(s, "chamber", x, z)
    put(sw.puddle(mat), -34, -12, 0)
    put(sw.suitcase_stack(mat), -72, 2, 30)
    put(alleyway.build_crate_stack(mat), -76, 5, -20)                             # clear of the barred mouth
    for (x, z) in ((-22, -22), (-19.6, -23.5)):
        put(sw.barrel(mat), x, z, 0)
    return s.finish(_ground(), mat), s


def build_sewer_set(mat):
    objs, _ = build_set(mat)
    return objs


ASSETS = {
    SET: (build_sewer_set, 120000),
}
