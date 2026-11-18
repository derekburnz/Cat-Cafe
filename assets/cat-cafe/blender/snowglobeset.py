"""Snowglobe Village (the Christmas Event, Tue Dec 1 2026 to Sun Jan 3 2027; Design-Agent's snowglobe-village-spec.md
section 3): you walk into the giant snow globe in Town Square and land in a tiny snowy village inside it, at night.
The village is a round 120 across (the globe's glass stands at radius 60), on a square floor 128 x 128. Players
arrive by the portal (a teleport), so the set has no way in: the curved glass all round is the edge.

  CatCafe_Snowglobe_Set        the area dressed, in area space (areakit): place it at the area's centre on its floor.
                               The arrival end is -Z. From the arrival:
                                 z -56 to -40   the spawn at (0, -50) facing +Z, a welcome sign and a lamp lane
                                 the middle     the village square round (0, 4): the lit tree (its bulbs are
                                                `_TreeLights_Glow`, its star `_TreeStar_Glow`), eight lamp posts with
                                                string lights, benches, the Gift Stall's spot on the lane
                                 x > 20, z > 0  the log lodge (hollow, a 7 wide door facing -Z) with the
                                                fireplace and rug spots inside
                                 x < -20, z > 0 the Snowflake patch: a pale blue field with the 12 pickup spots
                                 x < -20, z < 0 the frozen pond with a snowman and a sled
                                 the edge       four backdrop cottages, snowy pines and snow banks
                               The glass sky is `_Sky_Glass` (no collision): a wall 16 high at radius 60 that
                               curves in toward the top to radius 30 at 68 up, so you can tell you are inside the
                               globe. `_Snowfall` is an invisible volume (no collision) where Motion-FX's snow falls.
  CatCafe_Snowglobe_Portal     the Town Square portal: a giant snow globe (plinth, `_Glass` dome, a tiny village
                               inside, flakes that drift round, `_Spin`), and in front of it a candy cane arch with a
                               wreath round the glowing way in (`_Portal_Glow`, 7 wide, 8.6 high) and a sign whose face
                               is `_Screen` (8.0 x 2.6, Front -Z: "SNOWGLOBE VILLAGE" and the small line the UI changes).
  CatCafe_Snowglobe_Stall      the Gift Stall: a cabin stall with a snowy roof and a garland of lights (`_Glow`), the
                               three hats on stands, a present pile, a little snowman, a little lit tree, a stocking
                               and a GIFT STALL board. Front -Z, 12 wide.
  CatCafe_Snowglobe_Snowflake  one glowing snowflake to pick up at a patch spot (base centre at the pivot, 2.2 across):
                               a snow mound with the flake standing on it (`_Glow`).

Nothing invisible stands inside the area but `_Snowfall`: the only _Barrier is the 30 high ring just inside the glass.
Lights are `_Glow`, the pond `_Water`, rope and the lights' cables `_Decor` (no collision).

Points (manifest points_roblox, area space [x, y, z]): `player_spawn` (1, with a turn), `spawn` (14 stray spots, no
two within 12), `nook` (1, behind the lodge: Rare or better), `snowflake` (12, the patch's pickup spots), `stall`,
`fireplace` and `rug` (where CatCafe_Snowglobe_Stall, CatCafe_Decor_StoneFireplace and CatCafe_Decor_FiresideRug
stand, each with its turn).
"""

import math
import random

from mathutils import Matrix, Vector

import areakit
from common import RB, Builder
from crate_decor import _little_pine, _snowflake
from plot import rot_x, rot_y, rot_z

NAME = "CatCafe_Snowglobe_Set"
N = "CatCafe_Snowglobe_"
PORTAL, STALL, FLAKE = N + "Portal", N + "Stall", N + "Snowflake"
HALF = 64.0
R = 60.0                                   # the glass
G = 0.03                                   # the ground slab's top
BARRIER_H = 30.0
WALL_H = 16.0                              # the glass stands straight this high, then curves in
SNOW, SNOW_SHADE = "milk", "fur_mist"
ICE, ICE_LIGHT = "pastel_sky", "fish_belly"
PINE, PINE_DARK = "leaf_dark", "paw_woods"
RED, GOLD = "shirt_red", "rarity_legend"
LOG, LOG_DARK = "caramel_wood", "dark_wood"
BULBS = ("lamp_warm", RED, GOLD, "pastel_sky", "leaf_green")
SQUARE = (0.0, 4.0)
LODGE = (-36.0, 26.0)
PATCH = (36.0, 24.0)
POND = (32.0, -22.0)
COTTAGES = ((-46.0, -16.0, -70), (-14.0, 46.0, 8), (14.0, 47.0, -8), (46.0, 2.0, 80))
MOVING = {PORTAL: {"model_attributes": {"_Spin": {"Seconds": {"Float64": 18.0}}}}}

# Everything in the set is laid out in Blender axes (x, y, z up); Roblox area space is (-x, z, y), so a point here at
# (x, y) is reported as [-x, height, y].


def rz(d):
    return (math.radians(d), "Z")


def _pine(b, x, y, h, z=G):
    """A snowy pine h high in four tiers, as the Snowy Mountain's."""
    b.cyl_base((x, y, z), 0.22 * h / 6, h * 0.9, LOG_DARK, segments=8, bevel=False)
    for i, (t, r) in enumerate(((0.16, 0.34), (0.36, 0.27), (0.55, 0.19), (0.72, 0.11))):
        rr, th = r * h, 0.2 * h
        b.cyl_base((x, y, z + h * t), rr, th * 0.78, (PINE, PINE_DARK)[i % 2], segments=8, bevel=False)
        b.cyl_base((x, y, z + h * t + th * 0.78), rr * 0.8, th * 0.2, SNOW, segments=8, bevel=False)
    b.cyl_base((x, y, z + h * 0.9), 0.06 * h, 0.1 * h, SNOW, segments=8, bevel=False)


def _snowman(b, x, y, s=1.0, turn=0):
    b.ico((x, y, 1.5 * s), 1.5 * s, SNOW)
    b.ico((x, y, 3.5 * s), 1.05 * s, SNOW)
    b.ico((x, y, 5.0 * s), 0.75 * s, SNOW)
    a = math.radians(turn)
    fx, fy = -math.sin(a), -math.cos(a)                       # it looks toward -Y turned by `turn`
    b.cyl((x + fx * 0.85 * s, y + fy * 0.85 * s, 5.0 * s), 0.12 * s, 0.6 * s, "fur_marmalade", segments=6,
          bevel=False, rot=Matrix.Rotation(math.radians(90), 3, "X") @ Matrix.Rotation(-a, 3, "Y"), radius2=0.02)
    b.box((x, y, 4.35 * s), (1.7 * s, 1.7 * s, 0.35 * s), RED, bevel=False, rot=rz(turn))       # scarf
    b.cyl_base((x, y, 5.6 * s), 0.55 * s, 0.9 * s, "fur_black", segments=10, bevel=False)          # hat
    b.cyl_base((x, y, 5.55 * s), 0.85 * s, 0.1 * s, "fur_black", segments=10, bevel=False)


def _present(b, x, y, z, w, sw, rib=GOLD, turn=0):
    b.box_base((x, y, z), (w, w, w * 0.8), sw, bevel=False, rot=rz(turn))
    b.box_base((x, y, z - 0.01), (w * 1.02, w * 0.18, w * 0.82), rib, bevel=False, rot=rz(turn))
    b.box_base((x, y, z - 0.01), (w * 0.18, w * 1.02, w * 0.82), rib, bevel=False, rot=rz(turn))


def _ground(b):
    b.box_base((0, 0, 0), (2 * HALF, 2 * HALF, G), SNOW_SHADE, bevel=False)
    b.cyl_base((0, 0, G), R + 0.6, 0.04, SNOW, segments=40, bevel=False)                      # the globe's snow
    b.cyl_base((SQUARE[0], SQUARE[1], G), 19, 0.07, "fur_oat", segments=28, bevel=False)      # the square's cobbles
    b.cyl_base((SQUARE[0], SQUARE[1], G), 15.5, 0.1, "fur_vanilla", segments=28, bevel=False)
    b.box_base((0, -33, G), (8, 40, 0.065), "fur_oat", bevel=False)                            # the lane from the spawn
    for (x, y, rr, L) in ((-21, 15, 38, 22), (21, 15, -38, 22), (0, 30, 0, 16)):
        b.box_base((x, y, G), (6, L, 0.06), "fur_oat", bevel=False, rot=rz(rr))               # to the lodge, patch, back
    b.box_base((PATCH[0], PATCH[1], G), (26, 20, 0.09), ICE_LIGHT, bevel=False)                # the Snowflake patch


def _glass(mat):
    """The globe: straight glass to WALL_H at radius R, then a curve in toward the top, in rings of panels."""
    s = Builder()
    n = 40
    seg = 2 * math.pi * R / n * 1.02
    for k in range(n):
        a = 2 * math.pi * (k + 0.5) / n
        s.box_base((R * math.cos(a), R * math.sin(a), 0), (0.4, seg, WALL_H), ICE, bevel=False,
                   rot=Matrix.Rotation(a, 3, "Z"))
    steps = 6
    for i in range(steps):                                     # a quarter circle of radius R about (0, 0, WALL_H)
        t0, t1 = math.radians(10 * i), math.radians(10 * (i + 1))
        tm = (t0 + t1) / 2
        rm, zm = R * math.cos(tm), WALL_H + R * math.sin(tm)
        L = 2 * R * math.sin((t1 - t0) / 2) * 1.04
        w = 2 * math.pi * rm / n * 1.03
        for k in range(n):
            a = 2 * math.pi * (k + 0.5) / n
            rot = Matrix.Rotation(a, 3, "Z") @ Matrix.Rotation(-tm, 3, "Y")
            s.box((rm * math.cos(a), rm * math.sin(a), zm), (0.4, w, L), ICE, bevel=False, rot=rot)
    return s.finalize(NAME + "_001_Sky_Glass", mat)


def _barrier(mat):
    bar = Builder()
    n = 40
    r = R - 2.2
    seg = 2 * math.pi * r / n * 1.04
    for k in range(n):
        a = 2 * math.pi * (k + 0.5) / n
        bar.box_base((r * math.cos(a), r * math.sin(a), 0), (1.6, seg, BARRIER_H), "offwhite", bevel=False,
                     rot=Matrix.Rotation(a, 3, "Z"))
    return bar.finalize(NAME + "_002_Edge_Barrier", mat)


def _edge(b, rnd):
    """Snow banks along the glass and a ring of pines inside them, kept off the arrival lane."""
    for k in range(48):
        a = 2 * math.pi * (k + 0.5) / 48
        rr = R - 2.6 + rnd.uniform(-0.6, 0.6)
        r_ = rnd.uniform(3.0, 4.2)
        b.ico((rr * math.cos(a), rr * math.sin(a), r_ * 0.55), r_, (SNOW, SNOW_SHADE)[k % 2], scale=(1.3, 1.3, 0.55))
    for k in range(30):
        a = 2 * math.pi * (k + 0.25) / 30
        x, y = (R - 8.5) * math.cos(a), (R - 8.5) * math.sin(a)
        if y < -38 and abs(x) < 16:
            continue                                                                   # the arrival
        if any(math.hypot(x - cx, y - cy) < 11 for (cx, cy, _) in COTTAGES):
            continue
        _pine(b, x + rnd.uniform(-1, 1), y + rnd.uniform(-1, 1), rnd.uniform(10, 15))
    for (x, y) in ((-22, -40), (24, -42), (-52, 18), (-30, 44), (30, 42), (52, 24), (-8, -24), (10, -22)):
        _pine(b, x, y, rnd.uniform(6, 9))


def _roof(b, cx, cy, z0, w, d, h, wall, roof, turn=0.0, over=0.7, thick=0.5):
    """A front-gable roof (ridge front to back along local y) turned `turn` degrees: gable ends in the wall colour,
    two slabs, snow over each slab and along the ridge."""
    yaw = Matrix.Rotation(math.radians(turn), 3, "Z")
    b.fan((cx, cy, z0), (0, h), [(-w / 2, 0), (w / 2, 0)], d, wall, rot=yaw @ Matrix.Rotation(math.radians(90), 3, "X"))
    a = math.atan2(h, w / 2)
    L = math.hypot(w / 2, h) + over
    for s_ in (-1, 1):
        out = (s_ * math.cos(a), -math.sin(a))
        nrm = (s_ * math.sin(a), math.cos(a))
        for t, sw, k in ((thick, roof, 0.5), (0.3, SNOW, 1.0 + 0.15 / thick)):
            lx_ = s_ * w / 4 + out[0] * over / 2 + nrm[0] * thick * k
            lz_ = h / 2 + out[1] * over / 2 + nrm[1] * thick * k
            v = yaw @ Vector((lx_, 0, 0))
            b.box((cx + v.x, cy + v.y, z0 + lz_), (L - (0.1 if sw == SNOW else 0), d + 2 * over - (0.2 if sw == SNOW else 0), t),
                  sw, bevel=False, rot=yaw @ Matrix.Rotation(s_ * a, 3, "Y"))
    b.box((cx, cy, z0 + h + 0.35), (0.7, d + 2 * over, 0.4), SNOW, bevel=False, rot=yaw)


def _cottage(b, g, x, y, turn, sw, roof="fur_rust_red"):
    """A backdrop cottage 10 x 8, solid, its door and lit windows on the front (local -y), a snowy roof."""
    yaw = Matrix.Rotation(math.radians(turn), 3, "Z")

    def at(dx, dy):
        v = yaw @ Vector((dx, dy, 0))
        return x + v.x, y + v.y

    b.box_base((x, y, G), (10, 8, 6.5), sw, bevel=False, rot=rz(turn))
    _roof(b, x, y, 6.5 + G, 10, 8, 3.4, sw, roof, turn)
    cx, cy = at(3, 1.5)
    b.box_base((cx, cy, 6.5), (1.4, 1.4, 4.6), "fur_pewter", bevel=False, rot=rz(turn))       # chimney
    b.box_base((cx, cy, 11.1), (1.6, 1.6, 0.3), SNOW, bevel=False, rot=rz(turn))
    cx, cy = at(0, -4.05)
    b.box_base((cx, cy, G), (1.8, 0.3, 3.6), "fur_seal", bevel=False, rot=rz(turn))           # door
    for wx in (-3, 3):
        cx, cy = at(wx, -4.1)
        g.box((cx, cy, 3.6), (1.6, 0.3, 1.5), "lamp_warm", bevel=False, rot=rz(turn))
        cx, cy = at(wx, -4.3)
        b.box((cx, cy, 2.75), (2.0, 0.4, 0.2), SNOW, bevel=False, rot=rz(turn))               # snowy sill
    cx, cy = at(0, -4.4)
    b.cyl((cx, cy, 5.2), 0.7, 0.2, PINE, segments=10, bevel=False,
          rot=yaw @ Matrix.Rotation(math.radians(90), 3, "X"))                                # a wreath


def _lodge(b, g):
    """The log lodge: hollow, 22 x 16, walls of logs 10 high, a 7 wide door facing -Y, a snowy gable roof and a
    stone chimney at the back; the fireplace and the rug stand inside (points)."""
    lx, ly = LODGE
    W, D, H, T = 22.0, 16.0, 10.0, 1.0
    b.box_base((lx, ly, G), (W - 0.4, D - 0.4, 0.12), LOG_DARK, bevel=False)                  # plank floor
    for i in range(5):
        z = G + i * H / 5
        sw = (LOG, "fur_toffee")[i % 2]
        b.box_base((lx, ly + D / 2 - T / 2, z), (W, T, H / 5), sw, bevel=False)              # back
        for sx in (-1, 1):
            b.box_base((lx + sx * (W / 2 - T / 2), ly, z), (T, D - 2 * T, H / 5), sw, bevel=False)
            if z < 7.0:
                b.box_base((lx + sx * 7.25, ly - D / 2 + T / 2, z), (7.5, T, H / 5), sw, bevel=False)   # by the door
        if z >= 7.0:
            b.box_base((lx, ly - D / 2 + T / 2, z), (W, T, H / 5), sw, bevel=False)          # over the door
    for sx in (-1, 1):                                                                   # log ends at the corners
        for sy in (-1, 1):
            b.box_base((lx + sx * (W / 2 + 0.2), ly + sy * (D / 2 + 0.2), G), (1.4, 1.4, H), LOG_DARK, bevel=False)
    _roof(b, lx, ly, H + G, W, D, 5.5, LOG, "fur_seal", over=1.2, thick=0.6)
    b.box_base((lx + 5, ly + D / 2 + 0.8, G), (3.4, 2.2, H + 7.5), "fur_pewter", bevel=False)   # chimney
    b.box_base((lx + 5, ly + D / 2 + 0.8, H + 7.5 + G), (3.8, 2.6, 0.4), SNOW, bevel=False)
    for dx in (-3.9, 3.9):                                                               # door posts and a wreath
        b.box_base((lx + dx, ly - D / 2 - 0.2, G), (0.6, 0.5, 7.2), LOG_DARK, bevel=False)
    b.box_base((lx, ly - D / 2 - 0.2, 7.0), (8.4, 0.5, 0.6), LOG_DARK, bevel=False)
    b.cyl((lx, ly - D / 2 - 0.5, 8.6), 1.0, 0.3, PINE, segments=12, bevel=False, rot=(math.radians(90), "X"))
    b.box((lx, ly - D / 2 - 0.7, 7.9), (0.6, 0.2, 0.5), RED, bevel=False)
    for dx in (-8.5, 8.5):                                                               # front windows
        g.box((lx + dx, ly - D / 2 - 0.05, 4.6), (2.6, 0.3, 2.2), "lamp_warm", bevel=False)
        b.box((lx + dx, ly - D / 2 - 0.35, 3.4), (3.2, 0.5, 0.3), SNOW, bevel=False)
    for sx in (-1, 1):                                                                   # side windows
        g.box((lx + sx * (W / 2 + 0.05), ly + 2, 4.6), (0.3, 2.6, 2.2), "lamp_warm", bevel=False)
    g.ico((lx, ly, 8.6), 0.6, "lamp_warm")                                               # a lantern from the beam
    b.box((lx, ly, 9.6), (0.15, 0.15, 1.6), LOG_DARK, bevel=False)
    for (x, y, z) in ((lx - 11, ly - 11, G), (lx - 9.6, ly - 11, G), (lx - 10.3, ly - 11, 1.0)):
        b.cyl((x, y, z + 0.5), 0.5, 2.6, "fur_bramble", segments=8, bevel=False, rot=(math.radians(90), "X"))  # logs
    _pine(b, lx + 14.5, ly - 9, 6)
    _present(b, lx + 12.5, ly - 10.5, G, 1.2, "leaf_green")


def _square(b, g, d):
    sx_, sy_ = SQUARE
    h = 20.0                                                                             # the lit tree
    _pine(b, sx_, sy_, h)
    rnd = random.Random(5)
    for i, (t, r) in enumerate(((0.16, 0.34), (0.36, 0.27), (0.55, 0.19), (0.72, 0.11))):
        rr = r * h + 0.05
        for k in range(int(10 + 22 * r)):
            a = 2 * math.pi * k / int(10 + 22 * r) + i * 0.4
            g.ico((sx_ + rr * math.cos(a), sy_ + rr * math.sin(a), G + h * t + 0.6 + 0.3 * math.sin(k * 1.7)), 0.32,
                  BULBS[(k + i) % len(BULBS)])
    star = Builder()
    star.star((0, 0, 0), 1.6, 0.75, 0.5, GOLD, rot=(math.radians(90), "X"))
    for k in range(5):                                                                   # presents round its foot
        a = 2 * math.pi * k / 5 + 0.3
        _present(b, sx_ + 5.6 * math.cos(a), sy_ + 5.6 * math.sin(a), G + 0.1, (1.4, 1.0, 1.7, 1.1, 1.3)[k],
                 (RED, "leaf_green", "pastel_lilac", "fish_blue", RED)[k], (GOLD, "cream", GOLD, "cream", "cream")[k],
                 turn=17 * k)
    n = 8
    for k in range(n):                                                                   # lamp posts and string lights
        a = 2 * math.pi * (k + 0.5) / n
        x, y = sx_ + 18 * math.cos(a), sy_ + 18 * math.sin(a)
        b.cyl_base((x, y, G), 0.3, 7, LOG_DARK, segments=8, bevel=False)
        b.box_base((x, y, 7.0), (0.9, 0.9, 0.2), LOG_DARK, bevel=False)
        g.ico((x, y, 7.7), 0.75, "lamp_warm")
        b.cyl_base((x, y, 8.3), 0.6, 0.3, SNOW, segments=8, bevel=False)
        a2 = 2 * math.pi * (k + 1.5) / n
        x2, y2 = sx_ + 18 * math.cos(a2), sy_ + 18 * math.sin(a2)
        for j in range(1, 6):
            tt = j / 6
            g.ico((x + (x2 - x) * tt, y + (y2 - y) * tt, 7.0 - 1.6 * math.sin(tt * math.pi)), 0.3,
                  BULBS[(j + k) % len(BULBS)])
    for k in range(4):                                                                   # benches facing the tree
        a = 2 * math.pi * k / 4 + math.pi / 4
        x, y = sx_ + 12 * math.cos(a), sy_ + 12 * math.sin(a)
        rot = math.degrees(a) + 90
        b.box_base((x, y, 1.3), (4.8, 1.4, 0.35), LOG, bevel=False, rot=rz(rot))
        b.box_base((x + 0.75 * math.cos(a), y + 0.75 * math.sin(a), 1.65), (4.8, 0.3, 1.4), LOG, bevel=False,
                   rot=rz(rot))
        for o in (-1.9, 1.9):
            ox, oy = -math.sin(a) * o, math.cos(a) * o
            b.box_base((x + ox, y + oy, G), (0.4, 1.2, 1.3), LOG_DARK, bevel=False, rot=rz(rot))
        b.box_base((x, y, 1.65), (4.6, 1.2, 0.12), SNOW, bevel=False, rot=rz(rot))
    return star


def _arrival(b, g):
    for sx in (-1, 1):                                                                   # the lamp lane
        for y in (-46.0, -36.0, -26.0):
            b.cyl_base((sx * 5.4, y, G), 0.22, 5.2, RED, segments=8, bevel=False)
            for k in range(4):
                b.cyl_base((sx * 5.4, y, G + 0.4 + 1.25 * k), 0.24, 0.4, "cream", segments=8, bevel=False)
            g.ico((sx * 5.4, y, 5.6), 0.55, "lamp_warm")
    b.box_base((-7.5, -51, G), (0.5, 0.5, 5.6), LOG_DARK, bevel=False)                     # the welcome sign
    b.box_base((-13.5, -51, G), (0.5, 0.5, 5.6), LOG_DARK, bevel=False)
    b.box((-10.5, -51, 4.6), (7.2, 0.5, 2.8), LOG, bevel=False)
    b.box((-10.5, -51.3, 4.6), (6.4, 0.2, 2.0), "cream", bevel=False)
    b.box((-10.5, -51, 6.1), (7.4, 0.8, 0.3), SNOW, bevel=False)
    _snowman(b, 10, -48, 0.9, turn=20)
    for (x, y, w, sw) in ((-6.5, -45, 1.3, RED), (-7.6, -44, 0.9, "leaf_green"), (7, -40, 1.1, "pastel_lilac")):
        _present(b, x, y, G, w, sw)


def _pond(b, w, d):
    px, py = POND
    b.cyl_base((px, py, G), 10.6, 0.18, SNOW, segments=24, bevel=False)                    # the bank
    w.cyl_base((px, py, G + 0.05), 9.4, 0.16, ICE, segments=24, bevel=False)
    for k in range(4):
        a = 1.1 * k + 0.4
        d.box((px + 4 * math.cos(a), py + 4 * math.sin(a), G + 0.22), (3.2, 0.12, 0.02), ICE_LIGHT, bevel=False,
              rot=rz(math.degrees(a) + 40))                                              # skate marks
    _snowman(b, px + 12.5, py + 6, 1.0, turn=-60)
    sx, sy = px - 13, py + 3                                                               # a sled
    b.box_base((sx, sy, 0.6), (2.0, 4.0, 0.25), LOG, bevel=False)
    for o in (-0.85, 0.85):
        b.box_base((sx + o, sy, G), (0.2, 4.4, 0.6), RED, bevel=False)
    for (x, y) in ((px - 8, py - 11), (px + 6, py - 12)):
        b.ico((x, y, 0.85), 1.4, "fur_pewter", scale=(1, 1, 0.6))
        b.ico((x, y, 1.5), 1.1, SNOW, scale=(1, 1, 0.35))


def _patch(b, g):
    px, py = PATCH
    for sx in (-1, 1):                                                                     # little ice posts
        for sy in (-1, 1):
            b.box_base((px + sx * 13.5, py + sy * 10.5, G), (0.8, 0.8, 2.4), ICE, bevel=False, rot=rz(45))
            g.ico((px + sx * 13.5, py + sy * 10.5, 2.9), 0.5, "pastel_sky")
    b.box_base((px - 10, py - 12.5, G), (0.4, 0.4, 4.4), LOG_DARK, bevel=False)            # a sign by it
    b.box((px - 10, py - 12.5, 4.2), (3.6, 0.4, 1.6), LOG, bevel=False)
    b.box((px - 10, py - 12.75, 4.2), (3.0, 0.1, 1.1), ICE_LIGHT, bevel=False)


def _snowfall(mat):
    s = Builder()
    s.box_base((0, 0, 6.0), (2 * (R - 6), 2 * (R - 6), 34.0), "offwhite", bevel=False)
    return s.finalize(NAME + "_007_Snowfall", mat)


def _points():
    """Area-space Roblox points: a Blender (x, y) here is Roblox (-x, y)."""
    def rb(x, y, h=0.0, *more):
        return [round(-x, 2), round(h, 2), round(y, 2), *more]
    lx, ly = LODGE
    px, py = PATCH
    pts = {
        "player_spawn": [rb(0, -50.0, 0.0, 0)],
        "spawn": [rb(-14, -30), rb(16, -30), rb(-30, -6), rb(36, -36), rb(-44, 2), rb(-18, 28),
                  rb(20, 8), rb(-38, -36), rb(12, 36), rb(-2, 42), rb(24, -4), rb(px, py + 14),
                  rb(lx, ly - 2), rb(-26, -44)],
        "nook": [rb(lx + 8, ly + 15)],
        "snowflake": [rb(px - 9 + 6 * c, py - 6 + 6 * r, 0.12) for r in range(3) for c in range(4)],
        "stall": [rb(15, -22, 0.0, 90)],
        "fireplace": [rb(lx - 3, ly + 5.6, 0.15, 0)],
        "rug": [rb(lx - 3, ly + 1.6, 0.15, 0)],
    }
    spots = pts["spawn"] + pts["nook"]
    for i, a in enumerate(spots):
        for c in spots[i + 1:]:
            assert math.hypot(a[0] - c[0], a[2] - c[2]) >= 12.0, (a, c)
        assert math.hypot(a[0], a[2]) <= R - 6, a
    assert len(pts["spawn"]) == 14 and len(pts["snowflake"]) == 12
    return pts


def build_snowglobe_set(mat):
    rnd = random.Random(12)
    b, g, w, d = Builder(), Builder(), Builder(), Builder()
    _ground(b)
    _edge(b, rnd)
    _lodge(b, g)
    for (x, y, turn), sw in zip(COTTAGES, ("fur_cream", "pastel_sky", "blush", "fur_vanilla")):
        _cottage(b, g, x, y, turn, sw)
    star = _square(b, g, d)
    _arrival(b, g)
    _pond(b, w, d)
    _patch(b, g)
    areakit.POINTS[NAME] = _points()
    sx_, sy_ = SQUARE
    out = [b.finalize(NAME, mat), _glass(mat), _barrier(mat), g.finalize(NAME + "_003_TreeLights_Glow", mat),
           w.finalize(NAME + "_004_Pond_Water", mat), d.finalize(NAME + "_005_Marks_Decor", mat),
           star.finalize(NAME + "_006_TreeStar_Glow", mat, location=(sx_, sy_, G + 20.0 * 0.9 + 2.4)),
           _snowfall(mat)]
    return out


# ------------------------------------------------------------------------------------- the stand-alone pieces --
def _rb_pine(b, x, y, z, h, snow=True):
    b.cyl((x, y + 0.35 * h, z), 0.05 * h, 0.7 * h, LOG_DARK, segments=6)
    for k, (t, r) in enumerate(((0.2, 0.36), (0.45, 0.27), (0.68, 0.17))):
        b.cyl((x, y + t * h + 0.1 * h, z), r * h, 0.24 * h, (PINE, PINE_DARK)[k % 2], r2=0.04 * h, segments=8)
    if snow:
        b.cyl((x, y + 0.93 * h, z), 0.07 * h, 0.1 * h, SNOW, r2=0.01 * h, segments=6)


def _rb_present(b, x, y, z, s, sw, rib=GOLD):
    b.span((x - s / 2, y, z - s / 2), (x + s / 2, y + s * 0.8, z + s / 2), sw)
    b.span((x - s * 0.09, y - 0.005, z - s * 0.51), (x + s * 0.09, y + s * 0.81, z + s * 0.51), rib)
    b.span((x - s * 0.51, y - 0.005, z - s * 0.09), (x + s * 0.51, y + s * 0.81, z + s * 0.09), rib)


def _rb_cottage(b, glow, x, z, s, sw):
    b.span((x - 0.5 * s, 0, z - 0.4 * s), (x + 0.5 * s, 0.6 * s, z + 0.4 * s), sw)
    for sd in (-1, 1):
        b.box((x + sd * 0.27 * s, 0.75 * s, z), (0.62 * s, 0.06 * s, 0.9 * s), SNOW, rot=rot_z(-sd * 35))
    glow.span((x - 0.14 * s, 0.22 * s, z - 0.41 * s), (x + 0.14 * s, 0.42 * s, z - 0.4 * s), "lamp_warm")


def build_portal(mat):
    """The Town Square portal: a giant snow globe with a candy cane arch in front round the way in."""
    b, glass, glow, screen, spin, portal = RB(), RB(), RB(), RB(), RB(), RB()
    zc = 4.0                                                                             # the globe stands behind
    b.cyl((0, 0.6, zc), 8.8, 1.2, LOG_DARK, segments=20)                                  # plinth
    b.cyl((0, 2.0, zc), 8.3, 1.6, LOG, segments=20)
    b.cyl((0, 2.9, zc), 8.4, 0.25, "brass", segments=20)
    c = (0.0, 10.8, zc)
    glass.ball(c, 8.0, "glass")
    b.ball((0, 3.3, zc), 7.2, SNOW, scale=(1.0, 0.22, 1.0))                               # the snowy floor inside
    b.ball((-1.5, 3.6, zc + 1.5), 2.6, SNOW, scale=(1.0, 0.45, 1.0))
    _rb_pine(b, 0, 3.8, zc + 1.2, 6.6)                                                    # a tiny lit tree
    for k in range(9):
        a = 2 * math.pi * k / 9
        glow.ball((1.5 * math.cos(a) * (1 - 0.08 * (k % 3)), 4.9 + 0.45 * k, zc + 1.2 + 1.5 * math.sin(a) * 0.8),
                  0.13, BULBS[k % len(BULBS)])
    glow.ball((0, 10.4, zc + 1.2), 0.4, GOLD)
    for (x, dz, s, sw) in ((-4.4, 0.6, 2.3, "fur_cream"), (4.2, 1.4, 2.1, "blush"), (2.2, 4.4, 1.8, "pastel_sky")):
        _rb_cottage(b, glow, x, zc + dz, s, sw)
    for k in range(18):                                                                  # flakes that drift round
        a = math.radians(360 * k / 18 * 7 % 360 + 9 * k)
        y = -3.4 + 9.0 * ((k * 7) % 18) / 17
        rr = min(6.6, math.sqrt(max(0.3, 7.3 ** 2 - y ** 2)) - 0.5) * (0.5 + 0.5 * ((k * 3) % 5) / 4)
        spin.box((rr * math.cos(a), y, rr * math.sin(a)), (0.22, 0.22, 0.22), SNOW, rot=rot_y(15 * k))
    zf = -5.2                                                                            # the arch in front
    for sx in (-1, 1):
        x = sx * 4.4
        for k in range(10):                                                              # candy cane posts
            b.cyl((x, 0.5 + k * 1.0, zf), 0.45, 1.0, (RED, "cream")[k % 2], segments=10)
    for k in range(13):                                                                  # the hooked top: an arc
        a = math.pi * k / 12
        b.box((4.4 * math.cos(a), 10.0 + 2.2 * math.sin(a), zf), (1.0, 0.9, 0.9), (RED, "cream")[k % 2],
              rot=rot_z(math.degrees(a) + 90))
    for k in range(22):                                                                  # a wreath round the way in
        a = 2 * math.pi * k / 22
        x, y = 4.0 * math.cos(a), 5.4 + 5.0 * math.sin(a)
        if y < 0.6:
            continue
        b.ball((x, y, zf - 0.5), 0.55, (PINE, PINE_DARK)[k % 2])
        if k % 3 == 0:
            glow.ball((x, y, zf - 1.0), 0.2, BULBS[k % len(BULBS)])
    b.span((-0.7, 10.2, zf - 1.1), (0.7, 11.0, zf - 0.6), RED)                            # its bow
    portal.span((-3.5, 0.15, zf - 0.1), (3.5, 8.75, zf + 0.1), "pastel_sky")             # the glowing way in
    b.span((-4.4, 0.0, zf - 1.4), (4.4, 0.15, zf + 1.4), "fur_oat")                        # the step in
    b.span((-4.6, 12.4, zf - 0.35), (4.6, 15.6, zf + 0.35), LOG_DARK)                      # the sign's frame
    screen.span((-4.0, 12.7, zf - 0.42), (4.0, 15.3, zf - 0.35), "night_sky")
    b.span((-4.8, 15.6, zf - 0.6), (4.8, 15.95, zf + 0.6), SNOW)
    for sx in (-1, 1):                                                                   # presents and pines at its feet
        _rb_present(b, sx * 6.4, 0, zf - 0.4, 1.6, (RED, "leaf_green")[sx > 0])
        _rb_present(b, sx * 7.6, 0, zf + 1.2, 1.1, "pastel_lilac", "cream")
        _rb_pine(b, sx * 10.6, 0, zc + 2.0, 7.0)
    return [b.finalize(PORTAL, mat), glass.finalize(PORTAL + "_Glass", mat), glow.finalize(PORTAL + "_Glow", mat),
            screen.finalize(PORTAL + "_Screen", mat), portal.finalize(PORTAL + "_Portal_Glow", mat),
            spin.finalize(PORTAL + "_Spin", mat, location=c)]


def build_stall(mat):
    """The Gift Stall: a cabin stall with a snowy roof, the three hats on stands and the decor on show."""
    b, glow = RB(), RB()
    b.span((-5.5, 0, -1.6), (5.5, 3.2, 1.6), LOG)                                           # the counter
    b.span((-5.8, 3.2, -1.9), (5.8, 3.5, 1.9), LOG_DARK)
    for k in range(4):
        b.span((-5.4, 0.3 + 0.75 * k, -1.66), (5.4, 0.36 + 0.75 * k, -1.6), "fur_toffee")      # log lines
    for sx in (-1, 1):
        b.span((sx * 5.4 - 0.3, 3.5, 1.2), (sx * 5.4 + 0.3, 9.0, 1.8), LOG_DARK)                # posts
        b.span((sx * 5.4 - 0.25, 3.5, -1.75), (sx * 5.4 + 0.25, 8.0, -1.25), LOG_DARK)
    for sd in (-1, 1):                                                                       # the roof, front and back
        b.box((0, 8.7 + 0.35 * (sd > 0), -0.05 + sd * 1.25), (12.4, 0.35, 3.0), "fur_rust_red", rot=rot_x(sd * 18))
        b.box((0, 8.95 + 0.35 * (sd > 0), -0.05 + sd * 1.25), (12.2, 0.25, 2.8), SNOW, rot=rot_x(sd * 18))
    for k in range(13):                                                                      # a garland of lights
        x = -5.4 + 0.9 * k
        y = 7.8 - 0.35 * math.sin(math.pi * k / 12 * 2) ** 2
        b.ball((x, y + 0.15, -1.95), 0.32, (PINE, PINE_DARK)[k % 2])
        glow.ball((x, y - 0.1, -2.15), 0.16, BULBS[k % len(BULBS)])
    b.span((-4.2, 9.6, 1.4), (4.2, 11.3, 1.7), LOG_DARK)                                     # the board
    b.span((-3.9, 9.8, 1.34), (3.9, 11.1, 1.4), "cream")
    b.text("GIFT STALL", (2.65, 10.15, 1.34), 0.105, 0.04, RED, right=(-1, 0, 0))
    b.span((-4.4, 11.3, 1.3), (4.4, 11.5, 1.8), SNOW)
    for k, x in enumerate((-4.3, -2.6, -0.9)):                                               # three hats on stands
        b.cyl((x, 4.1, 0.2), 0.12, 1.2, LOG_DARK, segments=6)
        b.ball((x, 4.9, 0.2), 0.5, "cream")
        if k == 0:                                                                           # Santa Hat
            b.cyl((x, 5.35, 0.2), 0.55, 0.22, "offwhite", segments=10)
            b.cyl((x, 5.75, 0.2), 0.48, 0.6, RED, r2=0.1, segments=10)
            b.ball((x + 0.25, 6.0, 0.2), 0.14, "offwhite")
        elif k == 1:                                                                         # Reindeer Antlers
            b.span((x - 0.5, 5.3, 0.15), (x + 0.5, 5.42, 0.25), "fur_toffee")
            for sx in (-1, 1):
                b.box((x + sx * 0.4, 5.75, 0.2), (0.1, 0.7, 0.1), "fur_toffee", rot=rot_z(-sx * 15))
                b.box((x + sx * 0.58, 5.85, 0.2), (0.3, 0.08, 0.08), "fur_toffee", rot=rot_z(sx * 30))
            b.ball((x, 4.85, -0.32), 0.1, RED)
        else:                                                                                # Knit Beanie
            b.cyl((x, 5.3, 0.2), 0.52, 0.18, "cream", segments=10)
            b.cyl((x, 5.55, 0.2), 0.5, 0.4, "leaf_green", r2=0.36, segments=10)
            b.ball((x, 5.9, 0.2), 0.2, "cream")
    _rb_present(b, 1.0, 3.5, -0.2, 0.8, RED)                                                 # a present pile
    _rb_present(b, 1.75, 3.5, 0.3, 0.6, "pastel_lilac", "cream")
    _rb_present(b, 1.3, 4.14, 0.05, 0.5, "leaf_green")
    b.ball((2.9, 3.85, 0.0), 0.38, SNOW)                                                     # a little snowman
    b.ball((2.9, 4.4, 0.0), 0.27, SNOW)
    b.span((2.75, 4.2, -0.3), (3.05, 4.27, 0.28), RED)
    b.cyl((2.9, 4.74, 0.0), 0.16, 0.18, "fur_black", segments=8)
    b.span((3.45, 3.5, -0.35), (4.25, 4.2, 0.35), "cream")                                   # a gingerbread house
    for sd in (-1, 1):
        b.box((3.85 + sd * 0.22, 4.38, 0.0), (0.52, 0.06, 0.8), "fur_toffee", rot=rot_z(-sd * 38))
    _rb_pine(b, 4.9, 3.5, 0.0, 1.1, snow=False)                                              # a little lit tree
    for k in range(5):
        glow.ball((4.9 + 0.22 * math.cos(k * 1.3), 3.9 + 0.13 * k, 0.22 * math.sin(k * 1.3)), 0.06,
                  BULBS[k % len(BULBS)])
    b.span((5.55, 5.4, -1.75), (5.85, 6.3, -1.6), RED)                                       # a stocking on a post
    b.span((5.55, 5.4, -1.75), (6.15, 5.65, -1.6), RED)
    b.span((5.5, 6.2, -1.78), (5.9, 6.45, -1.58), "offwhite")
    for sx in (-1, 1):                                                                       # lanterns under the roof
        b.box((sx * 4.4, 7.3, -1.3), (0.08, 0.8, 0.08), LOG_DARK)
        glow.ball((sx * 4.4, 6.7, -1.3), 0.34, "lamp_warm")
    b.ball((-6.9, 0.6, 0.2), 1.2, SNOW, scale=(1.0, 0.5, 1.0))                               # snow at its side
    _rb_pine(b, 7.4, 0, 0.6, 4.2)
    return [b.finalize(STALL, mat), glow.finalize(STALL + "_Glow", mat)]


def build_flake(mat):
    """One snowflake to pick up: a little snow mound with a glowing flake standing on it."""
    b, glow = RB(), RB()
    b.ball((0, 0.33, 0), 1.1, SNOW, scale=(1.0, 0.3, 1.0))
    b.ball((0.35, 0.23, 0.2), 0.5, SNOW_SHADE, scale=(1.0, 0.45, 1.0))
    _snowflake(glow, 0, 1.25, 0, 0.85, "pastel_sky")
    glow.ball((0, 1.25, 0), 0.22, "offwhite")
    for k in range(6):                                                                       # the arms' tips
        a = math.radians(60 * k)
        glow.box((0.62 * math.cos(a), 1.25 + 0.62 * math.sin(a), 0), (0.26, 0.26, 0.06), "pastel_sky",
                 rot=rot_z(60 * k + 45))
    return [b.finalize(FLAKE, mat), glow.finalize(FLAKE + "_Glow", mat)]


ASSETS = {
    NAME: (build_snowglobe_set, 150000),
    PORTAL: (build_portal, 6000),
    STALL: (build_stall, 4500),
    FLAKE: (build_flake, 600),
}
