"""F85 Alleyway blockers (hometown-cannon.md section 6b: "the F84 set, 90 x 281, with low blockers along the
lanes"). The Alleyway is laid out by Layout.luau from kit pieces rather than as one set, so its blockers are prop
models that Gameplay places in Layout.alley.props (lane space, through laneProp): three across each 30 stud lane,
their gaps on alternating sides. Laid out in Roblox axes through common.RB, sizes in studs.

Every blocker pivots on the lane's middle line, on the floor. It spans local x -15 (a wall's face) to +6 and leaves
the way through, local x 6 to 15 (9 studs), at its +X end: rotY 0 puts the gap at world +x and rotY 180 at world -x.
Its `_Barrier` (30 high, invisible, solid, CanQuery off) runs along local z 0 over the piece from end to end, so
nobody hops over and the barrier always stands on something you can see. A lamp post at the gap end leans its lamp
out over the way through, so a player finds the gap from afar.

Each row stands on the line of a CatCafe_Alley_StringLightsLong (Layout's alleyDressing hangs one across the lane in
every gap between the buildings, poles at local x -14 and 14 on a 1 x 1 base). So the pile stops at x -13.35 and the
light's wall pole stands between it and the wall (1.65 studs, too narrow to pass, and the barrier is there); its other
pole stands in the way through, which leaves 7.5 studs to walk. The bulbs hang over the blocker.

  CatCafe_Alley_Blocker_Bins     wheelie bins with bin bags on a bin-store slab, about 3.9 high, 2.5 deep
  CatCafe_Alley_Blocker_Pallets  pallet stacks with crates and boxes, about 4 high, 2.8 deep
  CatCafe_Alley_Blocker_Skip     a builder's skip of rubble and planks on scaffold boards, a bulk bag of sand and a
                                 plank stack on trestles with cones, about 4.6 high, 5.4 deep
  CatCafe_Alley_Blocker_Van      a parked FRESH FISH box van, 8.4 high (the tall one: it hides the lane past it), back
                                 doors open, a ramp down to the crates it is unloading, 11.4 deep with the doors

The bins and the pallets are thin; they take the rows whose gap is on the inner side, their pile against the outer
wall's buildings. The skip and the van stand against the block of building backs, with the gap on the outer side.

Rows (lane space as in Layout.luau; side -1 west, 1 east; x = side * MID, MID 78; z on the gaps between buildings):
  west x -78:  z 88.025 Bins rotY 0 (gap inner), z 18.25 Skip rotY 180 (gap outer), z -53.675 Pallets rotY 0 (inner)
  east x 78:   z 88.025 Pallets rotY 180 (gap inner), z 18.25 Van rotY 0 (gap outer), z -88.025 Bins rotY 180 (inner)
The east lane's third row is at -88.025, not -53.675, because the east Warehouse's crate stack stands in that gap.
"""

import math

from mathutils import Matrix

from alleyway import _crate, label
from common import RB

N = "CatCafe_Alley_Blocker_"
X0, X1 = -15.0, 6.0          # the piece, from a wall's face to the gap
PILE_END = -13.35            # the pile's wall end: the string lights' pole base (x -14.5 to -13.5) stands past it
LAMP_X = 5.4                 # the lamp post at the gap end
BARRIER_H = 30.0


def rz(deg):
    return Matrix.Rotation(math.radians(deg), 3, "Z")


def rx(deg):
    return Matrix.Rotation(math.radians(deg), 3, "X")


def ry(deg):
    return Matrix.Rotation(math.radians(deg), 3, "Y")


def _barrier(name, mat):
    bar = RB()
    bar.span((X0, 0.0, -0.25), (X1, BARRIER_H, 0.25), "concrete")
    return bar.finalize(name + "_Barrier", mat)


def _lamp(b, bulb, x, y0=0.0, z=0.0):
    """A lamp post standing on (x, y0, z); its lamp hangs out over the way through (+X)."""
    b.cyl((x, y0 + 0.2, z), 0.35, 0.4, "concrete_dark")
    b.cyl((x, y0 + 4.7, z), 0.14, 8.6, "fur_black")
    b.span((x - 0.1, y0 + 8.75, z - 0.1), (x + 1.5, y0 + 8.95, z + 0.1), "fur_black")                   # the arm
    b.span((x + 1.05, y0 + 8.55, z - 0.45), (x + 1.95, y0 + 9.05, z + 0.45), "fur_black")               # the head
    bulb.span((x + 1.15, y0 + 8.3, z - 0.32), (x + 1.85, y0 + 8.6, z + 0.32), "lamp_warm")


def _bag(b, x, y, z, r, swatch="fur_black", tied=True):
    """A tied bin bag sitting on y."""
    b.ball((x, y + r * 0.85 - 0.06, z), r, swatch, scale=(1.05, 0.85, 1.0))
    if tied:
        top = y + r * 1.7 - 0.14
        b.b.pyramid(RB.p(x, top, z), r * 0.32, r * 0.36, swatch)
        b.span((x - r * 0.22, top + r * 0.3, z - 0.04), (x + r * 0.22, top + r * 0.38, z + 0.04), "metal")


# --------------------------------------------------------------------------------------------------------- bins --
BIN_W, BIN_D, BIN_H = 1.9, 1.7, 2.4


def _bin(b, x, z, colour, y0):
    """A shut wheelie bin standing on y0, lid hinge at the back (+Z); returns the lid's top."""
    w, d, h = BIN_W, BIN_D, BIN_H
    b.span((x - w / 2, y0 + 0.15, z - d / 2), (x + w / 2, y0 + h, z + d / 2), colour)                   # body
    b.span((x - w / 2 - 0.06, y0 + h - 0.04, z - d / 2 - 0.06), (x + w / 2 + 0.06, y0 + h + 0.1, z + d / 2 + 0.06),
           "concrete_dark")                                                                            # rim
    b.span((x - w / 2 - 0.04, y0 + h + 0.08, z - d / 2 - 0.12), (x + w / 2 + 0.04, y0 + h + 0.2, z + d / 2 + 0.04),
           "concrete_dark")                                                                            # lid
    b.span((x - 0.6, y0, z - d / 2 + 0.1), (x + 0.6, y0 + 0.15, z - d / 2 + 0.35), "fur_black")         # front foot
    for sx in (-1, 1):
        b.cyl((x + sx * 0.7, y0 + 0.22, z + d / 2 - 0.12), 0.22, 0.18, "fur_black", axis="X")          # wheels
    b.span((x - 0.55, y0 + h - 0.34, z + d / 2 - 0.05), (x + 0.55, y0 + h - 0.24, z + d / 2 + 0.22), "metal")
    b.span((x - 0.45, y0 + 1.1, z - d / 2 - 0.02), (x + 0.45, y0 + 1.55, z - d / 2 + 0.01), "offwhite")  # label
    return y0 + h + 0.2


def build_bins(mat):
    name = N + "Bins"
    b, bulb = RB(), RB()
    pad = 0.12
    b.span((PILE_END, 0.0, -1.25), (5.95, pad, 1.25), "concrete")                                     # bin store
    for k in range(1, 8):                                                                             # slab joints
        x = PILE_END + k * (5.95 - PILE_END) / 8
        b.span((x - 0.03, pad - 0.02, -1.26), (x + 0.03, pad + 0.005, 1.26), "concrete_dark")
    row = (("bin", -12.35, "dumpster_green"), ("bin", -10.3, "shirt_blue"), ("bags", -8.0, None),
           ("bin", -5.7, "dumpster_green"), ("bin", -3.65, "concrete"), ("bags", -1.35, None),
           ("bin", 0.95, "shirt_blue"), ("bin", 3.0, "dumpster_green"))
    tops = {}
    for kind, x, colour in row:
        if kind == "bin":
            tops[x] = _bin(b, x, 0.0, colour, pad)
        else:                                                                                         # a bag pile
            _bag(b, x - 0.55, pad, -0.25, 0.8, "fur_black")
            _bag(b, x + 0.6, pad, 0.3, 0.72, "concrete_dark")
            _bag(b, x, pad + 1.1, 0.0, 0.62, "fur_black")
    for x, r, sw in ((-12.35, 0.72, "fur_black"), (-5.7, 0.68, "concrete_dark"), (0.95, 0.74, "fur_black"),
                     (3.0, 0.66, "fur_black")):                                                       # bags on lids
        _bag(b, x, tops[x], 0.05, r, sw)
    b.span((-4.2, tops[-3.65] - 0.06, -0.55), (-3.15, tops[-3.65] + 0.84, 0.45), "cardboard", rot=rz(6))  # a box
    b.span((-4.2, tops[-3.65] + 0.84, -0.2), (-3.15, tops[-3.65] + 0.86, 0.1), "offwhite", rot=rz(6))
    _bag(b, 4.55, pad, -0.2, 0.55, "concrete_dark")
    _lamp(b, bulb, LAMP_X, pad)
    return [b.finalize(name, mat), bulb.finalize(name + "_Bulb", mat), _barrier(name, mat)]


# ------------------------------------------------------------------------------------------------------ pallets --
PAL_W, PAL_D = 2.6, 2.8


def _pallet(b, x, y, z=0.0):
    """One pallet on y: bottom boards, three rust blocks, top boards. Returns its top."""
    w, d = PAL_W, PAL_D
    b.span((x - w / 2, y, z - d / 2), (x + w / 2, y + 0.08, z + d / 2), "cardboard")
    for c in (-d / 2 + 0.2, 0.0, d / 2 - 0.2):
        b.span((x - w / 2 + 0.05, y + 0.08, z + c - 0.18), (x + w / 2 - 0.05, y + 0.22, z + c + 0.18), "rust")
    b.span((x - w / 2, y + 0.22, z - d / 2), (x + w / 2, y + 0.3, z + d / 2), "cardboard")
    return y + 0.3


def _stack(b, x, n, z=0.0):
    y = 0.0
    for _ in range(n):
        y = _pallet(b, x, y, z)
    return y


def _box(b, x, y, z, w, d, h, turn=0.0):
    """A taped cardboard box sitting on y."""
    b.span((x - w / 2, y - 0.02, z - d / 2), (x + w / 2, y + h, z + d / 2), "cardboard", rot=ry(turn))
    b.span((x - 0.1, y + h - 0.01, z - d / 2 - 0.01), (x + 0.1, y + h + 0.02, z + d / 2 + 0.01), "treat_tan",
           rot=ry(turn))


def build_pallets(mat):
    name = N + "Pallets"
    b, bulb = RB(), RB()
    xs = [PILE_END + PAL_W / 2 + k * PAL_W for k in range(6)]          # six stacks side by side, -12.05 to 0.95
    tops = [_stack(b, x, n) for x, n in zip(xs, (11, 4, 13, 12, 5, 8))]
    _box(b, xs[0] - 0.3, tops[0], -0.2, 1.4, 1.3, 0.8, 8)                                              # on the 11
    _crate(b, xs[1], tops[1], 0.0, 2.6, stencil="FISH")                                                # 1.2 + 2.5
    b.span((xs[2] - 1.32, tops[2] - 0.5, -1.42), (xs[2] + 1.32, tops[2] - 0.4, 1.42), "shirt_red")     # strap
    t = tops[3]                                                                                        # the tarp
    b.span((xs[3] - 1.36, t - 0.02, -1.46), (xs[3] + 1.36, t + 0.06, 1.46), "shirt_blue")
    b.span((xs[3] - 1.36, t - 1.1, -1.46), (xs[3] + 1.36, t + 0.06, -1.38), "shirt_blue")
    b.span((xs[3] - 1.36, t - 0.7, 1.38), (xs[3] + 1.36, t + 0.06, 1.46), "shirt_blue")
    for dz in (-0.9, 0.9):                                                                             # its ropes
        b.span((xs[3] - 1.4, t - 0.9, dz - 0.05), (xs[3] + 1.4, t + 0.1, dz + 0.05), "cardboard")
    _crate(b, xs[4], tops[4], 0.0, 2.6, stencil="MILK")                                                # 1.5 + 2.5
    _box(b, xs[5], tops[5], 0.1, 1.6, 1.5, 1.2, 4)                                                     # 2.4 + 1.2
    x7 = xs[5] + PAL_W / 2 + 0.95                                                                      # 3.2
    _crate(b, x7, 0.0, 0.0, 1.9)
    _box(b, x7 - 0.1, 1.8, 0.0, 1.2, 1.1, 0.8, 12)
    _box(b, x7 + 1.55, 0.02, 0.1, 1.2, 1.1, 0.9, 0)                                                    # 4.15 to 5.35
    _box(b, x7 + 1.5, 0.92, 0.05, 0.9, 0.8, 0.6, -9)
    _lamp(b, bulb, LAMP_X, 0.0)
    return [b.finalize(name, mat), bulb.finalize(name + "_Bulb", mat), _barrier(name, mat)]


# --------------------------------------------------------------------------------------------------------- skip --
def _cone(b, x, y, z):
    b.span((x - 0.62, y, z - 0.62), (x + 0.62, y + 0.15, z + 0.62), "fur_orange")
    b.b.cyl(RB.p(x, y + 0.95, z), 0.48, 1.6, "fur_orange", segments=10, radius2=0.1, bevel=False)
    b.b.cyl(RB.p(x, y + 0.9, z), 0.35, 0.26, "offwhite", segments=10, radius2=0.31, bevel=False)


def _trestle(b, x, y0, top, half):
    """An A-frame trestle: a top bar and two splayed pairs of legs, standing on y0, its bar `half` either way in z."""
    b.span((x - 0.2, top - 0.2, -half), (x + 0.2, top, half), "caramel_wood")
    h = top - 0.2 - y0
    a = 12.0
    for sz in (-1, 1):
        for sx in (-1, 1):
            c = (x + sx * h / 2 * math.tan(math.radians(a)), y0 + h / 2, sz * (half - 0.25))
            b.box(c, (0.16, h / math.cos(math.radians(a)) + 0.1, 0.16), "caramel_wood", rot=rz(sx * a))


def build_skip(mat):
    name = N + "Skip"
    b, bulb = RB(), RB()
    base = 0.12
    b.span((PILE_END, 0.0, -2.7), (5.95, base, 2.7), "caramel_wood")                                  # boards
    for k in range(1, 6):
        z = -2.7 + k * 5.4 / 6
        b.span((PILE_END + 0.03, base - 0.02, z - 0.03), (5.92, base + 0.005, z + 0.03), "dark_wood")
    # the skip: skids, floor, sloped ends and trapezoid sides, 10.3 long at the top and 7.3 at the floor
    top_x0, top_x1, bot_x0, bot_x1 = PILE_END, -3.05, PILE_END + 1.5, -4.55
    mid = (top_x0 + top_x1) / 2
    y_floor, y_top = base + 0.35, base + 4.1
    for z0, z1 in ((-2.1, -1.5), (1.5, 2.1)):
        b.span((bot_x0 + 0.4, base, z0), (bot_x1 - 0.4, y_floor, z1), "concrete_dark")
    b.span((bot_x0, y_floor, -2.4), (bot_x1, y_floor + 0.2, 2.4), "rarity_legend")
    for zc in (-2.4, 2.4):
        b.fan_z(zc, (mid, y_floor), [(bot_x1, y_floor), (top_x1, y_top), (top_x0, y_top), (bot_x0, y_floor)], 0.2,
                "rarity_legend")
    slope = math.degrees(math.atan2(1.5, y_top - y_floor))
    length = math.hypot(1.5, y_top - y_floor)
    b.box(((top_x0 + bot_x0) / 2, (y_floor + y_top) / 2, 0.0), (0.2, length, 4.6), "rarity_legend", rot=rz(slope))
    b.box(((top_x1 + bot_x1) / 2, (y_floor + y_top) / 2, 0.0), (0.2, length, 4.6), "rarity_legend", rot=rz(-slope))
    for zc in (-2.45, 2.45):                                                                           # the rims
        b.span((top_x0, y_top - 0.12, zc - 0.12), (top_x1, y_top + 0.08, zc + 0.12), "concrete_dark")
    for x in (-11.0, -5.4):                                                                            # lifting lugs
        for zc in (-2.55, 2.55):
            b.span((x - 0.25, y_floor + 0.9, zc - 0.12), (x + 0.25, y_floor + 1.5, zc + 0.12), "concrete_dark")
    label(b, "WHISKER SKIPS", mid, y_floor + 1.5, -2.49, 0.15, 0.06, "fur_black", -1)
    label(b, "WHISKER SKIPS", mid, y_floor + 1.5, 2.49, 0.15, 0.06, "fur_black", 1)
    # what is in it: a rubble fill, broken slabs and bricks on top, planks sticking out, an old chair
    fill = y_top - 0.5
    b.span((-11.5, y_floor + 0.2, -2.25), (-4.9, fill, 2.25), "concrete_dark")
    for (x, z, r, sw) in ((-11.3, -1.2, 0.9, "concrete"), (-10.0, 1.1, 1.0, "concrete_dark"),
                          (-8.7, -0.6, 0.85, "brick"), (-7.2, 1.2, 0.9, "concrete"), (-5.9, -1.0, 0.8, "concrete_dark")):
        b.ball((x, fill + r * 0.35, z), r, sw, scale=(1.2, 0.7, 1.0))
    for (x, z, a, y) in ((-9.4, 0.3, 14, 0.5), (-7.6, -1.4, -10, -0.05), (-10.9, 0.2, -8, 0.5)):           # bricks
        b.span((x - 0.45, fill + y, z - 0.22), (x + 0.45, fill + y + 0.45, z + 0.22), "brick", rot=ry(a))
    for (x0, y0, x1, y1, z) in ((-11.2, fill - 0.2, -6.8, y_top + 1.9, -0.9), (-8.0, fill - 0.2, -3.6, y_top + 1.3, 0.9),
                                (-11.8, fill, -8.4, y_top + 0.9, 1.6)):                                # planks
        L = math.hypot(x1 - x0, y1 - y0)
        b.box(((x0 + x1) / 2, (y0 + y1) / 2, z), (L, 0.16, 0.55), "caramel_wood",
              rot=rz(math.degrees(math.atan2(y1 - y0, x1 - x0))))
    cx, cy, cz = -6.4, fill + 0.1, -0.2                                                                # the chair
    b.span((cx - 0.8, cy, cz - 0.8), (cx + 0.8, cy + 0.35, cz + 0.8), "terracotta", rot=rz(-14))
    b.span((cx - 0.8, cy + 0.2, cz + 0.55), (cx + 0.8, cy + 1.6, cz + 0.85), "terracotta", rot=rz(-14))
    # past the skip: a bulk bag of sand, then planks on two trestles with cones
    bx0, bx1 = -2.6, 0.2
    b.span((bx0, base, -1.4), (bx1, base + 2.6, 1.4), "offwhite")
    for x in (bx0 + 0.15, bx1 - 0.15):
        for z in (-1.25, 1.25):
            b.span((x - 0.12, base + 2.5, z - 0.12), (x + 0.12, base + 3.1, z + 0.12), "offwhite")   # loops
    b.span((bx0 + 0.1, base + 2.5, -1.3), (bx1 - 0.1, base + 2.75, 1.3), "treat_tan")                 # sand
    b.b.pyramid(RB.p((bx0 + bx1) / 2, base + 2.7, 0.0), 2.0, 0.5, "treat_tan")
    b.span((bx0 - 0.02, base + 1.0, -1.42), (bx1 + 0.02, base + 1.5, -1.38), "shirt_blue")             # its band
    b.span((bx0 - 0.02, base + 1.0, 1.38), (bx1 + 0.02, base + 1.5, 1.42), "shirt_blue")
    top = base + 2.4
    for x in (1.0, 4.2):
        _trestle(b, x, base, top, 1.3)
    for k, (z0, z1) in enumerate(((-1.2, -0.42), (-0.38, 0.38), (0.42, 1.2))):                        # planks
        for j in range(2):
            y = top + j * 0.22
            b.span((bx1 - 0.05 if j == 0 else 0.4, y, z0), (4.9 - 0.3 * k, y + 0.22, z1), "caramel_wood")
    _cone(b, 2.6, base, -2.0)
    _cone(b, 2.6, base, 2.0)
    _lamp(b, bulb, LAMP_X, base)
    return [b.finalize(name, mat), bulb.finalize(name + "_Bulb", mat), _barrier(name, mat)]


# ---------------------------------------------------------------------------------------------------------- van --
def build_van(mat):
    """A box van parked nose to the wall: the cab and bonnet at -X, the cargo box behind, its back doors swung wide
    open at the rear (x -0.6) and a ramp down to the crates."""
    name = N + "Van"
    b, bulb = RB(), RB()
    W = 3.0                                                                                            # half width
    o = PILE_END + 14.95                                                                               # 1.6 off the wall
    rear, cab0, cab1, nose = -0.6 + o, -14.0 + o, -10.0 + o, PILE_END
    floor_y, box_top, cab_top = 1.5, 8.4, 5.4
    for x in (-12.4 + o, -3.4 + o):                                                                    # wheels
        for zc in (-W + 0.45, W - 0.45):
            b.cyl((x, 1.0, zc), 1.0, 0.8, "fur_black", axis="Z", segments=14)
            b.cyl((x, 1.0, zc), 0.45, 0.84, "metal", axis="Z", segments=10)
    b.span((cab0 + 0.4, 0.8, -W + 0.6), (rear - 0.3, floor_y, W - 0.6), "concrete_dark")              # chassis
    b.span((cab1, floor_y, -W), (rear, box_top, W), "offwhite")                                       # cargo box
    b.span((cab0 + 1.6, 6.0, -W), (cab1 + 0.1, box_top, W), "offwhite")                               # over the cab
    b.span((cab0 + 1.63, 5.96, -W + 0.1), (cab1 + 0.1, 6.02, W - 0.1), "concrete_dark")                # its underside
    b.span((cab0, floor_y, -W + 0.2), (cab1 + 0.1, cab_top, W - 0.2), "offwhite")                     # the cab
    b.span((nose + 0.35, floor_y, -W + 0.3), (cab0 + 0.1, 3.3, W - 0.3), "offwhite")                  # the bonnet
    b.span((nose, 1.0, -W + 0.2), (nose + 0.4, 1.6, W - 0.2), "concrete")                             # bumper
    b.span((cab0 - 0.04, 3.6, -W + 0.6), (cab0 + 0.06, 5.1, W - 0.6), "night_sky")                    # windscreen
    for s in (-1, 1):
        zf = s * (W - 0.2)
        b.span((cab0 + 0.6, 3.6, zf - 0.04), (cab1 - 0.6, 5.0, zf + 0.04), "night_sky")               # side window
        b.span((cab1 - 0.5, 2.0, zf - 0.03), (cab1 - 0.42, 5.0, zf + 0.03), "concrete_dark")          # door line
        b.span((cab0 + 0.5, 4.3, zf), (cab0 + 0.7, 4.4, zf + s * 0.45), "fur_black")                   # mirror arm
        b.span((cab0 + 0.45, 3.9, zf + s * 0.4), (cab0 + 0.75, 4.7, zf + s * 0.6), "fur_black")       # mirror
        zb = s * W
        b.span((cab1 + 0.03, 3.0, zb - 0.04), (rear - 0.03, 3.6, zb + 0.04), "sign_teal")                            # stripe
        b.span((cab1 + 0.03, 7.6, zb - 0.04), (rear - 0.03, 7.9, zb + 0.04), "sign_teal")
        b.ball((cab1 + 1.4, 5.9, zb), 0.85, "fish_blue", scale=(1.5, 0.75, 0.12))                      # the fish
        b.box((cab1 + 0.55, 5.9, zb), (0.9, 0.9, 0.2), "fish_blue", rot=rz(45))
        b.ball((cab1 + 2.5, 6.05, zb + s * 0.08), 0.13, "fur_black", scale=(1, 1, 0.5))                # its eye
    label(b, "FRESH FISH", (cab1 + rear) / 2, 4.15, -W + 0.01, 0.2, 0.06, "sign_teal", -1)
    label(b, "FRESH FISH", (cab1 + rear) / 2, 4.15, W - 0.01, 0.2, 0.06, "sign_teal", 1)
    for s in (-1, 1):                                                                                  # lamps, grille
        b.span((nose + 0.3, 2.3, s * (W - 0.9) - 0.35), (nose + 0.4, 2.8, s * (W - 0.9) + 0.35), "lamp_warm")
    b.span((nose + 0.3, 1.9, -1.4), (nose + 0.4, 3.0, 1.4), "concrete_dark")
    # the open back: a dark hold with a crate in it, the doors swung out flat to the sides, the ramp down
    b.span((rear - 0.05, floor_y + 0.15, -W + 0.25), (rear + 0.06, box_top - 0.25, W - 0.25), "night_sky")
    _crate(b, rear - 0.9, floor_y + 0.2, -1.2, 1.8)
    for s in (-1, 1):
        b.span((rear - 0.1, floor_y + 0.1, s * W), (rear + 0.05, box_top - 0.2, s * (W + 2.7)), "offwhite")
        b.span((rear + 0.05, 4.4, s * (W + 1.2)), (rear + 0.1, 5.4, s * (W + 1.6)), "metal")           # handle
    ramp_end = 3.5
    L = math.hypot(ramp_end - rear, floor_y)
    b.box(((rear + ramp_end) / 2, floor_y / 2 + 0.09, 0.0), (L, 0.15, 3.0), "metal",
          rot=rz(-math.degrees(math.atan2(floor_y, ramp_end - rear))))
    for zc in (-1.38, 1.38):                                                                           # its rails
        b.box(((rear + ramp_end) / 2, floor_y / 2 + 0.21, zc), (L, 0.2, 0.1), "concrete_dark",
              rot=rz(-math.degrees(math.atan2(floor_y, ramp_end - rear))))
    cx = 4.45                                                                                          # the crates
    _crate(b, cx, 0.0, 0.0, 2.0)
    _crate(b, cx - 0.1, 1.9, 0.05, 1.6, stencil=None)
    _box(b, cx + 0.05, 3.4, 0.0, 1.1, 1.0, 0.7, 14)
    _lamp(b, bulb, cx + 1.1, 0.0)
    return [b.finalize(name, mat), bulb.finalize(name + "_Bulb", mat), _barrier(name, mat)]


ASSETS = {
    N + "Bins": (build_bins, 6000),
    N + "Pallets": (build_pallets, 8000),
    N + "Skip": (build_skip, 8000),
    N + "Van": (build_van, 8000),
}
