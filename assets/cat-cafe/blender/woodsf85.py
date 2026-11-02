"""The F85 Woods (hometown-cannon.md section 6b): a long rectangle, 160 x 520 with the camp, so the run home with a cat
is long and in view. The set is the wild part, 160 x 490; the camp (CatCafe_Camp_WoodsF85, camps.py) lies across its
-Z end, outside it, as in F84. The Woods gate (CatCafe_Woods_Gate) and its night fence already span a 24 stud opening,
so the long Woods keeps them.

  CatCafe_Woods_SetF85   the wild part dressed, in area space (areakit): place it at the area's centre on its floor,
                         gate side -Z toward the camp, like every set. Walls at x +-80 and z +-245 (WorldBuilder's);
                         the way in is a 24 stud opening (CampOpeningWidth) at x 0 on z -245.

Five blockers cross the width, their ways through 24 wide and moving about (Derek 11-02: "the gaps also don't always
have to be on the sides can be a bit wider ... don't want it feeling too tightly cramped"), so the far end is never in
a straight line:

  z -172 to -168   the fallen timber: big trunks end to end, a thinner one on every other, about 4 high; its gap at
                   x 34 to 58 between two lanterns
  z -98 to -82     the stream from the waterfall at the east wall, log rails on its rock edges; crossed only on the
                   log bridge at x -46, its deck 10 wide (6 until 11-02)
  z -14 to -6      the tree line, a thicket 9 to 10 high with pines in it (tall); its gap in the middle, x -12 to 12
  z 70 to 72       a dry stone wall about 4 high; its gap at x -58 to -34 between stone gateposts, the field gate
                   standing open
  z 147 to 153     a mossy boulder ridge about 4.5 high; its gap at x 34 to 58 under the GREAT OAK arch

The low four let a hunter see a carrier coming but make them go round; a `_Barrier` 30 high stands on each, on the
stream's rails and in the wall band all round but the way in. The tree line is the tall piece that hides the far half
from the near. The far end is the Great Oak's clearing with the tree house and the lookout tower, the Woods' best
landmark.

The way, camp to far end: the dirt trail north-east from the gate past the berry meadow to the timber's gap, back west
past the mushroom ring to the log bridge, past the berry patch to the tree line's gap in the middle, west through the
dell to the wall's field gate, east past the old campsite to the arch, and west into the clearing. Shortest walk from the pad
(walk check on the Part model) in area-sets.md (6b: about 650 camp to far end).

Points (manifest points_roblox): [x, y, z, zone], zone "near" (the camp half, z < 0) or "deep" (the far half). The
traps are built in, as in v3.2: `trap_hollow_log` x2 (the open end faces the piece's local +X), `trap_bramble_bush` x2
and `trap_treehouse_branch` (the branch along the tree house's local -X), each with the piece's turn as a fifth
number. Four of the five are deep and none is within 100 studs of the camp. nook_great_oak (inside the oak's top) is
kept as in v3.2.
"""

import math

from mathutils import Matrix

import woods as wd
import woodsset as ws
from areakit import PI, Set, ry, turned
from common import RB, Builder, text_width
from woodsset import (BARRIER_H, DIRT, TRAIL_W, WALL_D, _dist_seg, _path, _run, _spot, _strip, bl, face, log_bridge,
                      log_pile, rail_fence)

NAME = "CatCafe_Woods_SetF85"
N = "CatCafe_Woods_"
HALF_X, HALF_Z = 80.0, 245.0            # WorldBuilder's walls at +-80, +-245 (WoodsWidth 160, WoodsDepth 490)
IN_X, IN_Z = HALF_X - 0.5 - WALL_D, HALF_Z - 0.5 - WALL_D       # 76.5, 241.5
GATE_HALF = 19.0                        # CatCafe_Woods_Gate is 36.2 wide, centred on the trail

LOGS_Z, GAP_A = -170.0, (34.0, 58.0)    # the fallen timber, gap east (the gaps 24 wide since Derek 11-02)
STREAM_Z, BRIDGE_X = -90.0, -46.0       # the stream's centre line at the bridge, and the bridge (west)
BRIDGE_W = 10.0                         # the log bridge's deck (6 until 11-02)
TREES_Z, GAP_C = -10.0, (-12.0, 12.0)   # the tree line, gap in the middle
WALL_Z, GAP_D = 70.0, (-58.0, -34.0)    # the dry stone wall (its face), gap west
RIDGE_Z, GAP_E = 150.0, (34.0, 58.0)    # the boulder ridge, gap east
WATERFALL_X = IN_X - 7.5                # as in v3.2: the pond's back against the east wall
RAIL_END_E = IN_X - 13.5                # the rails stop short of the pond's rocks
OAK = (-32.0, 206.0)                    # the Great Oak, in its clearing
CLEARING_R = 20.0
CAMPSITE = (54.0, 98.0)                 # the old campsite between the wall and the ridge
RING = (-30.0, -146.0)                  # the mushroom ring

TRAIL_IN = [(0, -IN_Z), (0, -232), (8, -222), (22, -208), (36, -194), (44, -184), (46, -176), (46, -164), (42, -154),
            (30, -144), (12, -134), (-8, -124), (-24, -116), (-36, -110), (-42, -106.5), (BRIDGE_X, -104.5)]
TRAIL_ON = [(BRIDGE_X, -75.5), (-44, -70), (-36, -62), (-24, -50), (-12, -38), (-4, -28), (0, -20), (0, -4),
            (-6, 6), (-16, 18), (-22, 34), (-34, 46), (-42, 54), (-46, 62), (-46, 78),
            (-42, 88), (-28, 98), (-8, 108), (14, 118), (32, 128), (42, 138), (46, 146), (46, 156), (40, 166),
            (24, 176), (4, 186), (-14, 192)]


def stream_z(x):
    """The stream's centre line: level with the bridge at BRIDGE_X, wandering up to 6 south of it."""
    return STREAM_Z - 3.0 * (1 - math.cos(2 * PI * (x - BRIDGE_X) / 90.0))


def trail_length():
    pts = TRAIL_IN + [(BRIDGE_X, -104.5 + 0.01)] + TRAIL_ON
    return sum(math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(pts, pts[1:])) + CLEARING_R - 2


def near_trail(x, z):
    d = 1e9
    for pts in (TRAIL_IN, TRAIL_ON, [(BRIDGE_X, -105), (BRIDGE_X, -75)]):
        for a, b in zip(pts, pts[1:]):
            d = min(d, _dist_seg((x, z), a, b))
    return d


# ------------------------------------------------------------------------------------------------- ground --
def _ground():
    g = Builder()
    _path(g, TRAIL_IN, TRAIL_W)
    _path(g, TRAIL_ON, TRAIL_W)
    g.cyl_base(bl(*OAK), CLEARING_R, 0.08, "fur_sand", segments=28, bevel=False)                 # the oak's clearing
    g.cyl_base(bl(*CAMPSITE), 12.0, 0.075, "fur_sand", segments=24, bevel=False)                 # the old campsite
    _strip(g, (32, 128), (CAMPSITE[0] - 6.0, CAMPSITE[1] + 10.4), 4.0, DIRT, 0.058)             # its track
    g.cyl_base(bl(*RING), 7.0, 0.07, "leaf_dark", segments=20, bevel=False)                      # mossy ring floor
    return g


# -------------------------------------------------------------------------------------------------- walls --
def _walls(s, mat):
    """Runs of mossy cliff, thicket, dry stone and now and then a log palisade between old trees just inside
    WorldBuilder's walls, as in v3.2, the stream coming out of a cliff on each side; a split rail fence with bushes on
    the camp side either side of the gate, lanterns by it; a barrier all round but the way in."""
    far = ("cliff", "thicket", "palisade", "drystone", "cliff")
    east = ("thicket", "drystone", "palisade", "thicket", "cliff", "drystone", "thicket", "cliff", "drystone",
            "thicket", "cliff", "drystone", "thicket", "cliff", "palisade")               # index 4: the waterfall's
    west = ("palisade", "cliff", "thicket", "drystone", "cliff", "thicket", "drystone", "cliff", "thicket",
            "drystone", "cliff", "thicket", "drystone", "palisade", "cliff")              # index 10: the stream's
    _run(s, mat, far, 5, 2 * IN_X, lambda t: (-IN_X + t, IN_Z, 0), 0)
    _run(s, mat, east, 15, 2 * IN_Z, lambda t: (IN_X, -IN_Z + t, 90), 1)
    _run(s, mat, west, 15, 2 * IN_Z, lambda t: (-IN_X, IN_Z - t, -90), 2)
    for sx in (-1, 1):
        s.put(ws.old_tree(mat, 18.0), sx * (IN_X - 2.0), IN_Z - 2.0, 45 * sx)                # far corners
        s.put(wd.rock(mat), sx * (IN_X - 3.0), -IN_Z + 3.0, 40 * sx)                       # camp corners
        L = IN_X - GATE_HALF - 1.0
        s.put(rail_fence(mat, L), sx * (GATE_HALF + 1.0 + L / 2), -IN_Z, 180)
        s.put(wd.lantern(mat), sx * (GATE_HALF + 0.6), -IN_Z + 1.5, 90 * sx)               # either side of the gate
    bar = Builder()
    ox = IN_X + WALL_D
    bar.box_base((0, IN_Z + WALL_D / 2, 0), (2 * ox, WALL_D, BARRIER_H), "offwhite", bevel=False)              # far
    for sx in (-1, 1):
        bar.box_base((sx * (IN_X + WALL_D / 2), 0, 0), (WALL_D, 2 * IN_Z, BARRIER_H), "offwhite", bevel=False)  # sides
        bar.box_base((sx * (GATE_HALF + ox) / 2, -(IN_Z + WALL_D / 2), 0), (ox - GATE_HALF, WALL_D, BARRIER_H),
                     "offwhite", bevel=False)                                                                 # camp
    s.put([bar.finalize(N + "Walls_Barrier", mat)], 0, 0, 0)


# -------------------------------------------------------------------------------------------- low blockers --
def _log_line(s, mat, z, gap):
    """The fallen timber across the area, one gap: big trunks (radius 1.3 to 1.6) end to end along the line, each a
    hair off straight, a thinner log lying on every other one so the line stands about 4 high, a brush mound over
    every join, moss on the trunks, ferny bushes at their feet and a snapped branch here and there. Cut ends show
    only at the runs' ends. A barrier 30 high on the line."""
    b, bar = Builder(), Builder()
    for k, (a0, a1) in enumerate(((-IN_X, gap[0]), (gap[1], IN_X))):
        L = a1 - a0
        n = max(1, round(L / 10.0))
        step = L / n
        for i in range(n):
            j = i + 7 * k
            r = 1.3 + 0.15 * (j % 3)
            c = a0 + (i + 0.5) * step
            ln = step - 0.8
            yaw = 0.05 * math.sin(j * 2.1)
            x, y, _ = bl(c, z + 0.4 * math.sin(j * 1.3))
            R = Matrix.Rotation(yaw, 3, "Z") @ Matrix.Rotation(PI / 2, 3, "Y")
            ax, ay = math.cos(yaw), math.sin(yaw)                        # the trunk's axis (Builder)
            b.cyl((x, y, r), r, ln, ("fur_brown", "fur_hazel")[j % 2], segments=10, rot=R)
            for e, cut in ((-1, i == n - 1), (1, i == 0)):              # Builder -x is Roblox +x
                if cut:
                    d = ln / 2 + 0.02
                    b.cyl((x + e * d * ax, y + e * d * ay, r), r * 0.86, 0.06, "treat_tan", segments=10, rot=R,
                          bevel=False)
            b.ico((x - 0.15 * ln * ax, y - 0.15 * ln * ay, 1.86 * r), r * 0.6, "leaf_green", subdivisions=1,
                  scale=(1.6, 1.0, 0.35), rot=(yaw, "Z"))                # moss along the top
            if j % 2 == 0:                                               # a thinner log on top
                R2 = Matrix.Rotation(-yaw * 2.0 + 0.06, 3, "Z") @ Matrix.Rotation(PI / 2, 3, "Y")
                r2 = 0.75 + 0.05 * (j % 3)
                b.cyl((x + 0.6, y + 0.2, 2 * r + r2 - 0.3), r2, ln * 0.6, "fur_hazel" if j % 4 else "fur_brown",
                      segments=8, rot=R2)
            if j % 3 == 1:                                               # a snapped branch
                b.box((x + 0.25 * ln * ax, y + 0.9, 1.75 * r), (0.3, 1.4, 0.3), "fur_brown",
                      rot=Matrix.Rotation(0.7, 3, "X"))
            for side in (-1, 1):                                         # ferny bushes at the feet
                if (j + (side > 0)) % 2 == 0:
                    b.ico((x + 0.28 * ln * side, y + side * (r + 0.5), 0.8), 1.1, ("leaf_green", "shirt_green")[j % 2],
                          subdivisions=1, scale=(1.5, 0.8, 0.85))
        for i in range(1, n):                                            # brush over each join
            j = i + 7 * k
            x, y, _ = bl(a0 + i * step, z + 0.2 * math.sin(j))
            b.ico((x, y, 1.6), 1.7, ("leaf_dark", "paw_woods")[j % 2], subdivisions=1, scale=(1.0, 1.3, 1.15))
        x, y, _ = bl((a0 + a1) / 2, z)
        bar.box_base((x, y, 0), (L, 3.6, BARRIER_H), "offwhite", bevel=False)
    s.put([b.finalize(N + "FallenTimber", mat), bar.finalize(N + "FallenTimber_Barrier", mat)], 0, 0, 0)
    for (x, rot) in ((gap[0] - 1.5, 180), (gap[1] + 1.5, 0)):           # lanterns either side of the gap
        s.put(wd.lantern(mat), x, z - 3.5, rot)


def field_gate(mat, L=7.0):
    """An old five bar field gate, L long and 3.6 high, standing on its hinge end at local x 0 and running to -x
    (Roblox +x), with a diagonal brace; front -Y."""
    b = Builder()
    for x in (-0.15, -(L - 0.15)):
        b.box_base((x, 0, 0), (0.3, 0.3, 3.7), "caramel_wood", bevel=False)                     # stiles
    for k in range(5):
        b.box((-L / 2, 0, 0.6 + 0.7 * k), (L - 0.6, 0.12, 0.22), "caramel_wood", bevel=False)
    a = math.atan2(2.8, L - 0.8)
    b.box((-L / 2, -0.12, 2.0), (math.hypot(L - 0.8, 2.8), 0.12, 0.22), "dark_wood", bevel=False,
          rot=Matrix.Rotation(a, 3, "Y"))                                                       # the brace
    for zz in (0.9, 3.0):
        b.box((-0.15, 0.25, zz), (0.2, 0.2, 0.3), "metal", bevel=False)                         # hinges
    return [b.finalize(N + "FieldGate", mat)]


def _stone_wall(s, mat, z, gap):
    """A dry stone field wall across the area, one gap: 1.8 thick and 3.4 high, cap stones on edge to about 3.9,
    coursing on both faces, moss on the caps and ferns at its foot; at the gap two tall stone gateposts with lanterns
    in front, the field gate swung back against the wall's far side. A barrier 30 high on the wall."""
    b, bar = Builder(), Builder()
    H = 3.4
    for k, (a0, a1) in enumerate(((-IN_X, gap[0]), (gap[1], IN_X))):
        L = a1 - a0
        x, y, _ = bl((a0 + a1) / 2, z + 0.9)
        b.box_base((x, y, 0), (L, 1.8, H), "concrete")
        n = max(2, round(L / 1.6))
        for i in range(n):
            cx = a0 + (i + 0.5) * L / n
            x, y, _ = bl(cx, z + 0.9)
            b.box_base((x, y, H), (L / n - 0.08, 2.0, 0.45 + 0.006 * (i % 2)), ("concrete_dark", "fur_grey")[i % 2],
                       bevel=False)
            if (i + k) % 5 == 2:
                b.ico((x, y, H + 0.5), 0.9, "fur_moss", subdivisions=1, scale=(1.4, 1.1, 0.35))
        for zz in (1.1, 2.3):                                                                 # coursing
            for f in (-0.03, 1.83):
                x, y, _ = bl((a0 + a1) / 2, z + f)
                b.box((x, y, zz), (L, 0.06, 0.1), "concrete_dark", bevel=False)
        m = max(1, round(L / 7.0))
        for i in range(m):
            cx = a0 + (i + 0.5) * L / m
            side = -1 if (i + k) % 2 == 0 else 1
            if side > 0 and gap[1] - 3.0 < cx < gap[1] + 9.0:                # the field gate lies here
                continue
            x, y, _ = bl(cx, z + 0.9 + side * 1.4)
            b.ico((x, y, 0.7), 1.1, ("leaf_green", "leaf_dark")[i % 2], subdivisions=1, scale=(1.5, 0.6, 0.75))
        x, y, _ = bl((a0 + a1) / 2, z + 0.9)
        bar.box_base((x, y, 0), (L, 2.0, BARRIER_H), "offwhite", bevel=False)
    for gx in (gap[0] + 0.8, gap[1] - 0.8):                                                    # gateposts
        x, y, _ = bl(gx, z + 0.9)
        b.box_base((x, y, 0), (1.6, 2.2, 5.0), "fur_grey")
        b.box_base((x, y, 5.0), (2.0, 2.6, 0.4), "concrete_dark", bevel=False)
        b.ico((x, y, 5.5), 0.55, "fur_moss", subdivisions=1, scale=(1.3, 1.2, 0.5))
        bar.box_base((x, y, 0), (1.6, 2.2, BARRIER_H), "offwhite", bevel=False)
    s.put([b.finalize(N + "StoneWall", mat), bar.finalize(N + "StoneWall_Barrier", mat)], 0, 0, 0)
    s.put(field_gate(mat), gap[1] - 1.6, z + 2.3, 0)                     # hinged on the east post, swung back east
    for (x, rot) in ((gap[0] - 0.6, 180), (gap[1] + 0.6, 0)):
        s.put(wd.lantern(mat), x, z - 2.2, rot)


def _boulder_ridge(s, mat, z, gap):
    """A low mossy boulder ridge across the area, one gap: two staggered rows of boulders round a low core, about 3.6
    high with smaller stones and moss on top to about 4.8, ferns at the foot. A barrier 30 high on it."""
    b, bar = Builder(), Builder()
    rocks = ("concrete", "fur_grey", "concrete", "fur_smoke_light", "concrete_dark")
    for k, (a0, a1) in enumerate(((-IN_X, gap[0]), (gap[1], IN_X))):
        n = max(1, round((a1 - a0) / 4.5))
        step = (a1 - a0) / n
        x, y, _ = bl((a0 + a1) / 2, z)
        b.box_base((x, y, 0), (a1 - a0, 2.0, 2.2), "concrete_dark", bevel=False)              # the core
        for i in range(n):
            j = i + 5 * k
            for row in (-1, 1):
                c = a0 + (i + 0.5 + 0.25 * row) * step
                r = 2.3 + 0.25 * ((j * 3 + row) % 3)
                sx = min(1.4, step / (1.3 * r))
                c = min(max(c, a0 + r * sx), a1 - r * sx)                # the ends stop at the gap and the walls
                x, y, _ = bl(c, z + row * 0.9 + 0.3 * math.sin(j * 2.3))
                b.ico((x, y, r * 0.55), r, rocks[(j * 2 + (row > 0)) % 5], subdivisions=1, scale=(sx, 0.75, 0.9))
            c = a0 + (i + 0.5) * step
            x, y, _ = bl(c, z)
            if j % 2 == 0:
                b.ico((x, y, 3.6), 1.3, rocks[(j + 1) % 5], subdivisions=1, scale=(1.2, 1.0, 0.7))
                b.ico((x + 0.3, y - 0.2, 4.4), 0.95, "fur_moss", subdivisions=1, scale=(1.3, 1.1, 0.4))
            else:
                b.ico((x, y - 0.4, 3.5), 1.5, "fur_moss", subdivisions=1, scale=(1.4, 1.2, 0.45))
            if j % 3 == 2:
                side = 1 if j % 2 else -1
                b.ico((x, y + side * 2.4, 0.6), 1.0, "leaf_green", subdivisions=1, scale=(1.4, 0.7, 0.7))
        x, y, _ = bl((a0 + a1) / 2, z)
        bar.box_base((x, y, 0), (a1 - a0, 4.6, BARRIER_H), "offwhite", bevel=False)
    s.put([b.finalize(N + "BoulderRidge", mat), bar.finalize(N + "BoulderRidge_Barrier", mat)], 0, 0, 0)


def trail_arch(mat, text="GREAT OAK", w=16.0):
    """A timber arch over a way through, w between its posts' centres: two log posts 9 high on stone footings, a log
    beam across with its cut ends past the posts, knee braces, and a plank board hanging under the beam with the
    name in pale letters on its -Y face (toward the camp)."""
    b, rb = Builder(), RB()
    H = 9.0
    for sx in (-1, 1):
        x = sx * w / 2
        b.cyl_base((x, 0, 0), 0.95, 0.7, "concrete", segments=8)
        b.cyl_base((x, 0, 0.7), 0.55, H - 0.2, "fur_brown", segments=8, radius2=0.5)
        b.box((x - sx * 0.95, 0, H - 0.75), (0.28, 0.28, 2.4), "dark_wood", bevel=False, rot=ry(-sx * 45))
    b.cyl((0, 0, H + 0.55), 0.6, w + 3.0, "fur_brown", segments=8, rot=ry(90))
    for e in (-1, 1):
        b.cyl((e * (w / 2 + 1.52), 0, H + 0.55), 0.5, 0.06, "treat_tan", segments=8, rot=ry(90), bevel=False)
    tw = text_width(text, 0.2)
    bw = tw + 1.4
    for sx in (-1, 1):
        b.box((sx * (bw / 2 - 0.5), 0, H - 0.4), (0.1, 0.1, 0.8), "metal", bevel=False)            # the hangers
    b.box_base((0, 0, H - 2.4), (bw, 0.24, 1.6), "dark_wood", bevel=False)
    rb.text(text, (tw / 2, H - 2.1, -0.12), 0.2, 0.06, "pastel_butter", right=(-1, 0, 0))
    return [b.finalize(N + "TrailArch", mat), rb.finalize(N + "TrailArchText", mat)]


# --------------------------------------------------------------------------------------------------- set --
def build_set(mat):
    s = Set(NAME)
    keep = []                                  # (x, z, r): no filler tree within r

    def put(fn, x, z, rot=0.0, r=4.0, y=0.0):
        keep.append((x, z, r))
        return s.put(fn, x, z, rot, y)

    _walls(s, mat)
    _log_line(s, mat, LOGS_Z, GAP_A)
    ws._tree_line(s, mat, TREES_Z, GAP_C, half=IN_X)
    _stone_wall(s, mat, WALL_Z, GAP_D)
    _boulder_ridge(s, mat, RIDGE_Z, GAP_E)
    put(trail_arch(mat, w=GAP_E[1] - GAP_E[0]), (GAP_E[0] + GAP_E[1]) / 2, RIDGE_Z, 0, r=0)
    s.put(ws.stream(mat, half=IN_X, zfn=stream_z, bridge_x=BRIDGE_X, rail_end=RAIL_END_E,
                    bridge_hw=BRIDGE_W / 2 + 0.4), 0, 0, 0)
    put(log_bridge(mat, w=BRIDGE_W), BRIDGE_X, STREAM_Z, 0, r=0)
    _spot(s, "bridge", BRIDGE_X - 5.5, STREAM_Z - 16.5)
    _spot(s, "bridge", BRIDGE_X + 5.5, STREAM_Z + 16.5)
    put(wd.waterfall(mat), WATERFALL_X, stream_z(WATERFALL_X), 90, r=9)
    _spot(s, "waterfall", WATERFALL_X - 5.0, stream_z(WATERFALL_X - 5.0) - 10.0)

    # the gate band: the signpost, the berry meadow west, stumps, a fallen log east
    put(wd.signpost(mat), -7.0, -226.0, 20, r=3)
    for (x, z) in ((-30, -220), (-48, -210), (-62, -224)):
        put(wd.berry(mat), x, z, 0, r=4)
        _spot(s, "berry_bush", x, z - 3.8)
    put(wd.leaves(mat), -16, -204, 30, r=3)
    _spot(s, "leaf_pile", -16, -204)
    for (x, z) in ((-60, -192), (-34, -186)):
        put(wd.stump(mat), x, z, 20, r=3)
        _spot(s, "stump", x, z, y=1.66)
    put(wd.rock(mat), -68, -180, 50, r=3.5)
    put(wd.fern(mat), 60, -230, 0, r=2)
    _spot(s, "fern", 60, -230)
    put(wd.fern(mat), 30, -236, 40, r=2)
    put(wd.fallen_log(mat), 60, -206, 25, r=5)
    _spot(s, "log", *turned(60, -206, 25, 0, -2.6))
    put(wd.mushroom(mat), -50, -184, 0, r=2.5)

    # between the timber and the stream: the mushroom ring, the near trap
    put(wd.mushroom_ring(mat), *RING, 0, r=6)
    _spot(s, "mushroom_ring", *RING, y=0.05)
    put(wd.mushroom_glow(mat), -62, -136, 0, r=3)
    _spot(s, "glow_mushrooms", -62, -139.5)
    for (x, z) in ((64, -156), (-64, -116)):
        put(wd.rock(mat), x, z, x % 90, r=3.5)
        _spot(s, "rock", x, z, y=2.0)
    for (x, z) in ((16, -156), (40, -118)):
        put(wd.fern(mat), x, z, 30, r=2)
        _spot(s, "fern", x, z)
    put(wd.fern(mat), -8, -150, 10, r=2)
    put(wd.stump(mat), 8, -112, 60, r=3)
    _spot(s, "stump", 8, -112, y=1.66)
    put(log_pile(mat), -60, -160, -30, r=4)
    _spot(s, "log_pile", *turned(-60, -160, -30, 0, -3.9))
    for (x, z, rot) in ((-14, -112, 0), (24, -150, 180)):
        put(wd.lantern(mat), x, z, rot, r=3)
    put(wd.hollow_log(mat), 62, -128, 20, r=5)
    _spot(s, "trap_hollow_log", 62, -128, turn=20)

    # between the stream and the tree line: the berry patch along the trail, glades
    for (x, z) in ((-56, -58), (-8, -60), (10, -50)):
        put(wd.berry(mat), x, z, 0, r=4)
        _spot(s, "berry_bush", x, z - 3.8)
    put(wd.leaves(mat), 30, -54, 0, r=3)
    _spot(s, "leaf_pile", 30, -54)
    for (x, z) in ((-64, -40), (64, -60)):
        put(wd.rock(mat), x, z, 20, r=3.5)
        _spot(s, "rock", x, z, y=2.0)
    put(wd.fern(mat), -34, -30, 50, r=2)
    _spot(s, "fern", -34, -30)
    put(wd.fern(mat), 60, -36, 20, r=2)
    put(wd.stump(mat), -16, -76, 0, r=3)
    _spot(s, "stump", -16, -76, y=1.66)
    _spot(s, "glade", 14, -20)
    put(wd.mushroom(mat), -50, -26, 0, r=2.5)
    for (x, z, rot) in ((-30, -66, 90), (40, -30, 180)):
        put(wd.lantern(mat), x, z, rot, r=3)
    for (x, rot) in ((GAP_C[0] - 1.5, 180), (GAP_C[1] + 1.5, 0)):              # either side of the tree line's gap
        put(wd.lantern(mat), x, TREES_Z - 5.5, rot, r=3)

    # past the tree line: the dell east, a bramble trap west
    put(wd.bramble(mat), -62, 18, 0, r=4)
    _spot(s, "trap_bramble_bush", -62, 18, turn=0)
    for (x, z) in ((20, 38), (-6, 52)):
        put(wd.berry(mat), x, z, 0, r=4)
        _spot(s, "berry_bush", x, z - 3.8)
    for (x, z) in ((66, 46), (-40, 8)):
        put(wd.rock(mat), x, z, 70, r=3.5)
        _spot(s, "rock", x, z, y=2.0)
    for (x, z) in ((58, 28), (2, 6)):
        put(wd.fern(mat), x, z, 10, r=2)
        _spot(s, "fern", x, z)
    put(wd.mushroom_glow(mat), 40, 54, 0, r=3)
    _spot(s, "glow_mushrooms", 40, 50.5)
    put(wd.fallen_log(mat), 62, 12, 60, r=5)
    _spot(s, "log", *turned(62, 12, 60, 0, -2.6))
    put(wd.leaves(mat), -52, 32, 0, r=3)
    _spot(s, "leaf_pile", -52, 32)
    put(wd.stump(mat), -24, 58, 0, r=3)
    _spot(s, "stump", -24, 58, y=1.66)
    put(log_pile(mat), -62, 52, 20, r=4)
    _spot(s, "log_pile", *turned(-62, 52, 20, 0, -3.9))
    for (x, z) in ((-26, 16), (16, 56)):
        _spot(s, "glade", x, z)
    _spot(s, "dell", 54, 40)
    for (x, z, rot) in ((20, 8, 180), (-30, 30, 90)):
        put(wd.lantern(mat), x, z, rot, r=3)

    # past the stone wall: the old campsite east, a hollow log trap west
    cx, cz = CAMPSITE
    for (x, z, col) in ((cx - 8, cz + 7, "shirt_green"), (cx + 9, cz + 4, "fur_orange")):
        r = face(x, z, cx, cz)
        put(wd.tent(mat, col), x, z, r, r=6)
        _spot(s, "tent", *turned(x, z, r, 0, -4.8))
    put(wd.campfire(mat), cx, cz, 0, r=3)
    for (x, z) in ((cx - 6, cz - 5), (cx + 6, cz - 6)):
        put(wd.log_bench(mat), x, z, face(x, z, cx, cz), r=3.5)
        _spot(s, "log_bench", x, z, y=2.06)
    put(log_pile(mat), cx + 13, cz - 9, 75, r=4)
    _spot(s, "old_camp", cx - 2.0, cz - 11.5)
    put(wd.hollow_log(mat), -62, 122, -20, r=5)
    _spot(s, "trap_hollow_log", -62, 122, turn=-20)
    put(wd.leaves(mat), -56, 92, 0, r=3)
    _spot(s, "leaf_pile", -56, 92)
    put(wd.rock(mat), -20, 132, 30, r=3.5)
    _spot(s, "rock", -20, 132, y=2.0)
    for (x, z) in ((28, 96), (-66, 142)):
        put(wd.fern(mat), x, z, 50, r=2)
        _spot(s, "fern", x, z)
    put(wd.mushroom_glow(mat), -40, 140, 0, r=3)
    _spot(s, "glow_mushrooms", -40, 136.5)
    put(wd.stump(mat), 2, 88, 0, r=3)
    _spot(s, "stump", 2, 88, y=1.66)
    for (x, z) in ((-34, 80), (8, 136)):
        put(wd.berry(mat), x, z, 0, r=4)
        _spot(s, "berry_bush", x, z - 3.8)
    for (x, z, rot) in ((-38, 104, 90), (24, 132, 180)):
        put(wd.lantern(mat), x, z, rot, r=3)

    # the far end: the Great Oak's clearing, the tree house and the lookout tower
    ox, oz = OAK
    rot = face(ox, oz, *TRAIL_ON[-1])                              # its doorway toward the trail's end
    put(wd.great_oak(mat), ox, oz, rot, r=11)
    for d in wd.OAK_NOOKS:
        a = math.radians(d)
        _spot(s, "oak_nook", *turned(ox, oz, rot, -6.8 * math.cos(a), 6.8 * math.sin(a)))
    for (bx, by, up) in wd.NOOK_SPOTS:
        _spot(s, "nook_great_oak", *turned(ox, oz, rot, -bx, by), y=wd.NOOK_Z + up)
    for (x, z) in ((-14, 218), (-50, 218), (-44, 188)):
        put(wd.log_bench(mat), x, z, face(x, z, ox, oz), r=3.5)
        _spot(s, "log_bench", x, z, y=2.06)
    put(wd.campfire(mat), -20, 200, 0, r=3)
    tx, tz = 50.0, 210.0
    trot = face(tx, tz, ox, oz)
    put(wd.treehouse(mat), tx, tz, trot, r=9)
    _spot(s, "treehouse", *turned(tx, tz, trot, -1.8, 1.8), y=wd.DECK + 0.3)
    _spot(s, "trap_treehouse_branch", *turned(tx, tz, trot, -4.9, 4.4), y=15.45, turn=round(trot, 2))  # along -X
    _spot(s, "treehouse_foot", *turned(tx, tz, trot, 3.0, -7.5))
    wx, wz = 12.0, 230.0
    wrot = 90.0                                                    # its ladder west, toward the clearing
    put(wd.tower(mat), wx, wz, wrot, r=6)
    _spot(s, "tower", wx, wz)                                      # under the deck, clear of the ladder's truss
    put(wd.signpost(mat), -2, 196, 60, r=3)
    for (x, z, rot) in ((-4, 178, 90), (-58, 200, -90)):
        put(wd.lantern(mat), x, z, rot, r=3)
    for (x, z) in ((-62, 186), (-58, 230)):
        _spot(s, "clearing", x, z)
    put(wd.bramble(mat), 64, 176, 0, r=4)
    _spot(s, "trap_bramble_bush", 64, 176, turn=0)
    put(wd.mushroom_glow(mat), -66, 218, 0, r=3)
    _spot(s, "glow_mushrooms", -66, 214.5)
    put(wd.rock(mat), -64, 166, 40, r=3.5)
    _spot(s, "rock", -64, 166, y=2.0)
    put(wd.fern(mat), 30, 198, 20, r=2)
    _spot(s, "fern", 30, 198)
    put(wd.berry(mat), 28, 226, 0, r=4)
    _spot(s, "berry_bush", 28, 222.2)
    put(wd.leaves(mat), 66, 236, 0, r=3)
    _spot(s, "leaf_pile", 66, 236)
    put(wd.mushroom(mat), -24, 236, 0, r=2.5)

    # filler: pines and a few round oaks, clear of the trail, the stream, the blockers, the pieces and the spots, a
    # little thinner than v3.2's so a hunter sees along the trail's legs
    spots = [(p[0], p[2]) for lst in s.points.values() for p in lst]
    k, trees = 0, []
    for gx in range(-68, 69, 14):
        for gz in range(-234, 235, 14):
            k += 1
            x = gx + 4.0 * math.sin(k * 2.71)
            z = gz + 4.0 * math.cos(k * 1.93)
            if z < -IN_Z + 14 and abs(x) < GATE_HALF + 12:                    # the gate stays open
                continue
            if near_trail(x, z) < 10.0 or abs(z - stream_z(x)) < 13.0:
                continue
            if (abs(z - LOGS_Z) < 8.0 or abs(z - TREES_Z) < 10.0 or abs(z - WALL_Z - 0.9) < 8.0
                    or abs(z - RIDGE_Z) < 9.0):
                continue
            if any(math.hypot(x - px, z - pz) < 12.0 for (px, pz) in trees):    # canopies apart
                continue
            if any(math.hypot(x - px, z - pz) < pr + 5.0 for (px, pz, pr) in keep):
                continue
            if any(math.hypot(x - px, z - pz) < 6.0 for (px, pz) in spots):
                continue
            if (math.hypot(x - CAMPSITE[0], z - CAMPSITE[1]) < 16 or math.hypot(x - RING[0], z - RING[1]) < 10
                    or math.hypot(x - OAK[0], z - OAK[1]) < CLEARING_R + 4):
                continue
            trees.append((x, z))
            if k % 5 == 0:
                s.put(wd.oak(mat), x, z, (k * 37) % 360)
            else:
                s.put(wd.pine(mat, h=15.0 + 3.0 * (k % 3)), x, z, 0)
    return s.finish(_ground(), mat), s


def build_woods_set(mat):
    objs, _ = build_set(mat)
    return objs


ASSETS = {
    NAME: (build_woods_set, 150000),
}
