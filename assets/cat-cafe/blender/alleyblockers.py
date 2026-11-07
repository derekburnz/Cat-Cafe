"""F85 Alleyway blockers (hometown-cannon.md section 6b: "the F84 set, 90 x 281, with low blockers along the
lanes"). The Alleyway is laid out by Layout.luau from kit pieces rather than as one set, so its blockers are prop
models that Gameplay places in Layout.alley.props (lane space, through laneProp): three rows across each 30 stud
lane. Laid out in Roblox axes through common.RB, sizes in studs.

Every blocker pivots on the lane's middle line, on the floor, with its pile against a wall at -X. Two lengths, so
the way through moves about (Derek 11-02: "the gaps also don't always have to be on the sides can be a bit wider ...
don't want it feeling too tightly cramped"):
  long   the pile runs from x -13.35 to 1 and the way through is x 1 to 15 at +X (14 studs); rotY 180 puts it at -X.
  short  the pile runs from x -13.35 to -6.5. Two at one spot, one at rotY 0 and one at rotY 180, leave a 13 stud
         way through down the middle of the lane, x -6.5 to 6.5.
Every pile stands WALL_TOP (10.4) high with sheer sides, and nothing low enough to hop on (1.7 at most) stands
near it, so a jump (7.2) never lands on a pile and the pile itself reads as a wall (#2204, Derek's playtest: "taller
so you clearly can't hop them"). Each `_Barrier` (invisible, solid, CanQuery off) stands a stud over that, 11.4
high, along local z 0 from the wall (x -15) to the pile's end, so the barrier always stands on something you can
see. A lamp post (11.5 high) at the pile's end leans its lamp out over the way through, so a player finds the gap
from afar.

Each row stands on the line of a CatCafe_Alley_StringLightsLong (Layout's alleyDressing hangs one across the lane in
every gap between the buildings, poles at local x -14 and 14 on a 1 x 1 base). So every pile stops at x -13.35 and
the light's wall pole stands between it and the wall (1.65 studs, too narrow to pass, and the barrier is there); in
a side row the other pole stands in the way through, which leaves 12.5 studs to walk. The bulbs hang over the row.

  CatCafe_Alley_Blocker_Bins          long: a timber bin store under a tin roof, six bays a side with a wheelie bin or
                                      a bag heap in each (the bays 3.4 high, too low to stand in), bags, a tyre and
                                      a box thrown up on the roof, a BIN STORE sign each side
  CatCafe_Alley_Blocker_BinsShort     short: the same with three bays a side
  CatCafe_Alley_Blocker_Pallets       long: five columns of pallet loads (boxes, fish sacks, milk crates) two loads
                                      high, flush with the pallets; a FISH crate, a strap, a tarp and boxes on top
  CatCafe_Alley_Blocker_PalletsShort  short: two columns, a tarp, a FISH crate, two boxes on the ground past them
  CatCafe_Alley_Blocker_Skip          long: a builder's skip with boards stood on its rims up to 10.4, rubble heaped
                                      to the top, planks and a chair sticking out; past it a scaffold tower in blue
                                      sheeting (13.4) with a rubbish chute down into the skip, cones either side
  CatCafe_Alley_Blocker_Van           long: a FRESH FISH box lorry, 10.4 high, its flat-fronted cab under the box's
                                      peak (no bonnet or cab roof to climb), back doors open, a crate set down
                                      behind it

Rows (lane space as in Layout.luau; side -1 west, 1 east; x = side * MID, MID 78; z on the gaps between buildings):
  west x -78:  z 88.025 BinsShort rotY 0 + PalletsShort rotY 180 (way through in the middle),
               z 18.25 Skip rotY 180 (by the buildings), z -53.675 Pallets rotY 0 (by the block)
  east x 78:   z 88.025 Pallets rotY 180 (by the block), z 18.25 Van rotY 0 (by the buildings),
               z -88.025 PalletsShort rotY 0 + BinsShort rotY 180 (in the middle)
The east lane's third row is at -88.025, not -53.675, because the east Warehouse's crate stack stands in that gap.
"""

import math

from mathutils import Matrix

from alleyway import _crate, label
from areakit import Set
from common import RB, text_width

N = "CatCafe_Alley_Blocker_"
X0 = -15.0                   # a wall's face
PILE_END = -13.35            # the pile's wall end: the string lights' pole base (x -14.5 to -13.5) stands past it
LONG_END, SHORT_END = 1.0, -6.5
LONG_LAMP, SHORT_LAMP = 0.65, -6.85     # lamp posts (base radius 0.35) at each pile's end
WALL_TOP = 10.4             # every pile's sheer top: a jump (7.2) from anything low enough to hop on stays under it
BARRIER_H = WALL_TOP + 1.0  # the invisible wall's top, a stud over the piles (Gameplay #2204)
BARRIER_HIGH = 30.0         # a row's barrier-only span by the Warehouse's crate stack, whose steps go to 7.7
LAMP_UP = 2.5               # lamp posts raised by this over their old 9, so the lamp still hangs over the piles


def rz(deg):
    return Matrix.Rotation(math.radians(deg), 3, "Z")


def rx(deg):
    return Matrix.Rotation(math.radians(deg), 3, "X")


def ry(deg):
    return Matrix.Rotation(math.radians(deg), 3, "Y")


def _barrier(name, mat, x1):
    bar = RB()
    bar.span((X0, 0.0, -0.25), (x1, BARRIER_H, 0.25), "concrete")
    return bar.finalize(name + "_Barrier", mat)


def _out(b, bulb, name, mat, end):
    """A piece's objects: the pile, its lamp's bulb if it has one, its barrier."""
    out = [b.finalize(name, mat)]
    if len(bulb.b.bm.faces):
        out.append(bulb.finalize(name + "_Bulb", mat))
    return out + [_barrier(name, mat, end)]


def _lamp(b, bulb, x, y0=0.0, z=0.0):
    """A lamp post standing on (x, y0, z); its lamp hangs out over the way through (+X)."""
    u = LAMP_UP
    b.cyl((x, y0 + 0.2, z), 0.35, 0.4, "concrete_dark")
    b.cyl((x, y0 + 4.7 + u / 2, z), 0.14, 8.6 + u, "fur_black")
    b.span((x - 0.1, y0 + 8.75 + u, z - 0.1), (x + 1.5, y0 + 8.95 + u, z + 0.1), "fur_black")           # the arm
    b.span((x + 1.05, y0 + 8.55 + u, z - 0.45), (x + 1.95, y0 + 9.05 + u, z + 0.45), "fur_black")       # the head
    bulb.span((x + 1.15, y0 + 8.3 + u, z - 0.32), (x + 1.85, y0 + 8.6 + u, z + 0.32), "lamp_warm")


def _bag(b, x, y, z, r, swatch="fur_black", tied=True):
    """A tied bin bag sitting on y."""
    b.ball((x, y + r * 0.85 - 0.06, z), r, swatch, scale=(1.05, 0.85, 1.0))
    if tied:
        top = y + r * 1.7 - 0.14
        b.b.pyramid(RB.p(x, top, z), r * 0.32, r * 0.36, swatch)
        b.span((x - r * 0.22, top + r * 0.3, z - 0.04), (x + r * 0.22, top + r * 0.38, z + 0.04), "metal")


def _boards(b, x0, x1, y0, y1, z, step, swatch="dark_wood"):
    """Board joints across a face at depth z (the face's outside), every `step` up from y0: thin, never solid."""
    s = 1 if z > 0 else -1
    y = y0 + step
    while y < y1 - step * 0.4:
        b.span((x0, y - 0.03, z), (x1, y + 0.03, z + s * 0.02), swatch)
        y += step


# --------------------------------------------------------------------------------------------------------- bins --
BIN_W, BIN_H = 1.9, 2.4
SHED_D, CORE, BAY_H, POST = 1.5, 0.12, 3.4, 0.2    # the bin store: half depth, its middle wall's half thickness, the
#                                                    bays' opening height, the posts between the bays


def _bin(b, x, z, colour, y0, f=-1, d=1.25):
    """A shut wheelie bin standing on y0, its front toward f (-1: -Z), lid hinge at the back; d deep."""
    w, h = BIN_W, BIN_H
    front, back = z + f * d / 2, z - f * d / 2
    b.span((x - w / 2, y0 + 0.15, z - d / 2), (x + w / 2, y0 + h, z + d / 2), colour)                   # body
    b.span((x - w / 2 - 0.06, y0 + h - 0.04, z - d / 2 - 0.06), (x + w / 2 + 0.06, y0 + h + 0.1, z + d / 2 + 0.06),
           "concrete_dark")                                                                            # rim
    b.span((x - w / 2 - 0.04, y0 + h + 0.08, front + f * 0.12), (x + w / 2 + 0.04, y0 + h + 0.2, back),
           "concrete_dark")                                                                            # lid
    b.span((x - 0.6, y0, front - f * 0.1), (x + 0.6, y0 + 0.15, front - f * 0.35), "fur_black")         # front foot
    for sx in (-1, 1):
        b.cyl((x + sx * 0.7, y0 + 0.22, back + f * 0.12), 0.22, 0.18, "fur_black", axis="X")           # wheels
    b.span((x - 0.45, y0 + 1.1, front + f * 0.02), (x + 0.45, y0 + 1.55, front - f * 0.01), "offwhite")  # label


def _bins(name, mat, end, lamp, bays, roof):
    """A timber bin store as tall as the piles: bays both sides under one tin roof, a bin or a bag heap in each bay
    (bays: (front, back) per bay, each ("bin", colour) or ("bags",)), things thrown up on the roof (roof: (kind, x)).
    Sheer from the bays' lintel to the eaves, so nothing in it is a step up. lamp: the post's x, or None."""
    b, bulb = RB(), RB()
    pad = 0.12
    x0, x1 = PILE_END, end - 0.02
    b.span((x0, 0.0, -SHED_D - 0.15), (x1, pad, SHED_D + 0.15), "concrete")                           # bin store slab
    joints = max(2, round((x1 - x0) / 2.3))
    for k in range(1, joints):                                                                        # slab joints
        x = x0 + k * (x1 - x0) / joints
        b.span((x - 0.03, pad - 0.02, -SHED_D - 0.16), (x + 0.03, pad + 0.005, SHED_D + 0.16), "concrete_dark")
    n = len(bays)
    bay_w = (x1 - x0 - (n + 1) * POST) / n
    b.span((x0, pad, -CORE), (x1, WALL_TOP, CORE), "dark_wood")                                       # middle wall
    for s in (-1, 1):
        zo = s * SHED_D
        b.span((x0, BAY_H, s * CORE), (x1, WALL_TOP, zo), "caramel_wood")                             # over the bays
        b.span((x0, BAY_H, zo), (x1, BAY_H + 0.3, zo + s * 0.03), "dark_wood")                        # the lintel
        _boards(b, x0, x1, BAY_H + 0.3, WALL_TOP, zo, 0.9)
        for k in range(n + 1):                                                                        # posts
            px = x0 + k * (bay_w + POST)
            b.span((px, pad, s * CORE), (px + POST, BAY_H, zo), "dark_wood")
        for k, bay in enumerate(bays):
            x = x0 + POST + k * (bay_w + POST) + bay_w / 2
            kind = bay[0 if s < 0 else 1]
            if kind[0] == "bin":
                _bin(b, x, s * (SHED_D - 0.13 - 0.625), kind[1], pad, f=s)
            else:                                                                                     # a bag heap
                _bag(b, x - 0.48, pad, s * (SHED_D - 0.62), 0.52, "fur_black")
                _bag(b, x + 0.48, pad, s * (SHED_D - 0.6), 0.5, "concrete_dark")
                _bag(b, x, pad + 0.78, s * (SHED_D - 0.72), 0.46, "fur_black")
        cx = (x0 + x1) / 2                                                                            # the sign
        tpx = 0.16 if n > 3 else 0.12
        w = text_width("BIN STORE", tpx)
        b.span((cx - w / 2 - 0.35, 6.3, zo), (cx + w / 2 + 0.35, 6.3 + tpx * 5 + 0.7, zo + s * 0.05), "sign_teal")
        label(b, "BIN STORE", cx, 6.65, zo + s * 0.05, tpx, 0.04, "offwhite", s)
    roof_y = WALL_TOP + 0.18                                                                          # tin roof
    b.span((x0 - 0.2, WALL_TOP, -SHED_D - 0.3), (x1 + 0.2, roof_y, SHED_D + 0.3), "rust")
    k = x0 + 0.4
    while k < x1 - 0.2:                                                                               # its ribs
        b.span((k - 0.05, roof_y, -SHED_D - 0.3), (k + 0.05, roof_y + 0.06, SHED_D + 0.3), "concrete_dark")
        k += 1.1
    for kind, x in roof:                                                                              # up on the roof
        if kind == "bags":
            _bag(b, x - 0.4, roof_y, -0.3, 0.7, "fur_black")
            _bag(b, x + 0.5, roof_y, 0.4, 0.62, "concrete_dark")
        elif kind == "box":
            b.span((x - 0.55, roof_y - 0.02, -0.55), (x + 0.5, roof_y + 0.84, 0.45), "cardboard", rot=ry(8))
            b.span((x - 0.1, roof_y + 0.83, -0.56), (x + 0.1, roof_y + 0.86, 0.46), "treat_tan", rot=ry(8))
        else:                                                                                         # an old tyre
            b.cyl((x, roof_y + 0.2, 0.1), 0.75, 0.4, "fur_black", segments=14)
            b.cyl((x, roof_y + 0.2, 0.1), 0.36, 0.42, "concrete_dark", segments=10)
    if lamp is not None:
        _lamp(b, bulb, lamp, pad)
    return _out(b, bulb, name, mat, end)


def build_bins(mat, lamp=True):
    bays = ((("bin", "dumpster_green"), ("bin", "shirt_blue")), (("bin", "shirt_blue"), ("bags",)),
            (("bags",), ("bin", "dumpster_green")), (("bin", "dumpster_green"), ("bin", "concrete")),
            (("bin", "concrete"), ("bags",)), (("bags",), ("bin", "dumpster_green")))
    return _bins(N + "Bins", mat, LONG_END, LONG_LAMP if lamp else None, bays,
                 (("bags", -10.6), ("tyre", -6.4), ("box", -2.6)))


def build_bins_short(mat, lamp=True):
    bays = ((("bin", "shirt_blue"), ("bin", "dumpster_green")), (("bin", "dumpster_green"), ("bags",)),
            (("bags",), ("bin", "shirt_blue")))
    return _bins(N + "BinsShort", mat, SHORT_END, SHORT_LAMP if lamp else None, bays, (("bags", -10.4),))


# ------------------------------------------------------------------------------------------------------ pallets --
PAL_W, PAL_D = 2.6, 2.8
LOADS = {   # a pallet load's face, its seams and what is printed on it
    "boxes": ("cardboard", "treat_tan"),
    "sacks": ("offwhite", "concrete"),
    "milk": ("shirt_blue", "pants_navy"),
}


def _pallet(b, x, y, z=0.0):
    """One pallet on y: bottom boards, three rust blocks, top boards. Returns its top."""
    w, d = PAL_W, PAL_D
    b.span((x - w / 2, y, z - d / 2), (x + w / 2, y + 0.08, z + d / 2), "cardboard")
    for c in (-d / 2 + 0.2, 0.0, d / 2 - 0.2):
        b.span((x - w / 2 + 0.05, y + 0.08, z + c - 0.18), (x + w / 2 - 0.05, y + 0.22, z + c + 0.18), "rust")
    b.span((x - w / 2, y + 0.22, z - d / 2), (x + w / 2, y + 0.3, z + d / 2), "cardboard")
    return y + 0.3


def _load(b, x, y, kind, h):
    """A pallet with a block of goods h high on it, flush with the pallet's edges so it leaves no ledge: four boxes
    (or sacks, or crates of milk) to a long face, the seams on those faces. Returns its top."""
    y = _pallet(b, x, y)
    w, d = PAL_W, PAL_D
    face, seam = LOADS[kind]
    b.span((x - w / 2, y, -d / 2), (x + w / 2, y + h, d / 2), face)
    for s in (-1, 1):
        b.span((x - 0.03, y, s * d / 2), (x + 0.03, y + h, s * (d / 2 + 0.02)), seam)
        b.span((x - w / 2, y + h / 2 - 0.03, s * d / 2), (x + w / 2, y + h / 2 + 0.03, s * (d / 2 + 0.02)), seam)
        if kind == "sacks":                                                                           # a fish print
            for zf in (-1, 1):
                b.ball((x + s * 0.65, y + h * 0.75, zf * (d / 2 + 0.01)), 0.42, "fish_blue", scale=(1.4, 0.7, 0.08))
        elif kind == "milk":                                                                          # crate handles
            for zf in (-1, 1):
                b.span((x + s * 0.65 - 0.3, y + h - 0.45, zf * d / 2), (x + s * 0.65 + 0.3, y + h - 0.3,
                       zf * (d / 2 + 0.02)), "pants_navy")
                b.span((x + s * 0.65 - 0.3, y + h / 2 - 0.45, zf * d / 2), (x + s * 0.65 + 0.3, y + h / 2 - 0.3,
                       zf * (d / 2 + 0.02)), "pants_navy")
    return y + h


def _column(b, x, pallets, loads):
    """A short stack of empty pallets and pallet loads on it, up past WALL_TOP. Returns its top."""
    y = 0.0
    for _ in range(pallets):
        y = _pallet(b, x, y)
    for kind, h in loads:
        y = _load(b, x, y, kind, h)
    assert y >= WALL_TOP - 1e-6, (x, y)
    return y


def _box(b, x, y, z, w, d, h, turn=0.0):
    """A taped cardboard box sitting on y."""
    b.span((x - w / 2, y - 0.02, z - d / 2), (x + w / 2, y + h, z + d / 2), "cardboard", rot=ry(turn))
    b.span((x - 0.1, y + h - 0.01, z - d / 2 - 0.01), (x + 0.1, y + h + 0.02, z + d / 2 + 0.01), "treat_tan",
           rot=ry(turn))


def _tarp(b, x, t):
    b.span((x - 1.36, t - 0.02, -1.46), (x + 1.36, t + 0.06, 1.46), "shirt_blue")
    b.span((x - 1.36, t - 1.1, -1.46), (x + 1.36, t + 0.06, -1.38), "shirt_blue")
    b.span((x - 1.36, t - 0.7, 1.38), (x + 1.36, t + 0.06, 1.46), "shirt_blue")
    for dz in (-0.9, 0.9):                                                                             # its ropes
        b.span((x - 1.4, t - 0.9, dz - 0.05), (x + 1.4, t + 0.1, dz + 0.05), "cardboard")


def build_pallets(mat, lamp=True):
    name = N + "Pallets"
    b, bulb = RB(), RB()
    xs = [PILE_END + PAL_W / 2 + k * PAL_W for k in range(5)]          # five stacks side by side, -12.05 to -1.65
    tops = [_column(b, xs[0], 1, (("boxes", 4.8), ("sacks", 4.7))),
            _column(b, xs[1], 4, (("milk", 4.1), ("boxes", 4.5))),
            _column(b, xs[2], 2, (("boxes", 4.7), ("boxes", 4.7))),
            _column(b, xs[3], 1, (("sacks", 4.2), ("milk", 5.3))),
            _column(b, xs[4], 3, (("boxes", 4.3), ("sacks", 4.6)))]
    _box(b, xs[0] - 0.3, tops[0], -0.2, 1.4, 1.3, 0.8, 8)
    _crate(b, xs[1], tops[1], 0.0, 2.6, stencil="FISH")
    b.span((xs[2] - 1.32, tops[2] - 0.5, -1.42), (xs[2] + 1.32, tops[2] - 0.4, 1.42), "shirt_red")     # strap
    _tarp(b, xs[3], tops[3])
    _box(b, xs[4], tops[4], 0.1, 1.6, 1.5, 1.2, 4)
    _box(b, xs[4] + PAL_W / 2 + 0.35, 0.02, 0.1, 0.7, 1.1, 0.9, 0)                                    # -0.35 to 0.35
    if lamp:
        _lamp(b, bulb, LONG_LAMP, 0.0)
    return _out(b, bulb, name, mat, LONG_END)


def build_pallets_short(mat, lamp=True):
    name = N + "PalletsShort"
    b, bulb = RB(), RB()
    xs = [PILE_END + PAL_W / 2 + k * PAL_W for k in range(2)]          # -12.05 and -9.45
    tops = [_column(b, xs[0], 1, (("sacks", 4.5), ("boxes", 5.0))),
            _column(b, xs[1], 4, (("boxes", 4.3), ("milk", 4.6)))]
    _tarp(b, xs[0], tops[0])
    _crate(b, xs[1], tops[1], 0.0, 2.6, stencil="FISH")
    _box(b, xs[1] + PAL_W / 2 + 0.5, 0.02, 0.0, 1.0, 1.1, 1.1, 0)                                    # -8.15 to -7.15
    _box(b, xs[1] + PAL_W / 2 + 0.45, 1.12, 0.05, 0.8, 0.8, 0.6, -9)
    if lamp:
        _lamp(b, bulb, SHORT_LAMP, 0.0)
    return _out(b, bulb, name, mat, SHORT_END)


# --------------------------------------------------------------------------------------------------------- skip --
def _cone(b, x, y, z):
    b.span((x - 0.62, y, z - 0.62), (x + 0.62, y + 0.15, z + 0.62), "fur_orange")
    b.b.cyl(RB.p(x, y + 0.95, z), 0.48, 1.6, "fur_orange", segments=10, radius2=0.1, bevel=False)
    b.b.cyl(RB.p(x, y + 0.9, z), 0.35, 0.26, "offwhite", segments=10, radius2=0.31, bevel=False)


def build_skip(mat, lamp=True):
    """A builder's skip overfilled, its sides raised to WALL_TOP with boards stood on the rims (greedy boards), the
    rubble heaped to the top of them, and past it a scaffold tower in blue sheeting with a rubbish chute down into
    the skip."""
    name = N + "Skip"
    b, bulb = RB(), RB()
    base = 0.12
    b.span((PILE_END, 0.0, -2.7), (LONG_END - 0.02, base, 2.7), "caramel_wood")                       # boards
    for k in range(1, 6):
        z = -2.7 + k * 5.4 / 6
        b.span((PILE_END + 0.03, base - 0.02, z - 0.03), (LONG_END - 0.05, base + 0.005, z + 0.03), "dark_wood")
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
    # greedy boards on the rims: the sides and ends go straight up to WALL_TOP, uprights outside holding them
    top = WALL_TOP
    for s in (-1, 1):
        zc = s * 2.45
        b.span((top_x0, y_top + 0.08, zc - 0.1), (top_x1, top, zc + 0.1), "caramel_wood")
        _boards(b, top_x0, top_x1, y_top + 0.08, top, zc + s * 0.1, 1.05)
        for x in (top_x0 + 0.15, -10.6, -8.2, -5.8, top_x1 - 0.15):
            b.span((x - 0.13, y_top - 0.1, zc + s * 0.05), (x + 0.13, top + 0.15, zc + s * 0.27), "dark_wood")
    for x in (top_x0, top_x1 - 0.2):
        b.span((x, y_top + 0.08, -2.55), (x + 0.2, top, 2.55), "caramel_wood")
    # what is in it, heaped to the top: a rubble fill, broken slabs and bricks, planks sticking out, an old chair
    fill = top - 0.45
    b.span((-11.5, y_floor + 0.2, -2.25), (-4.9, y_top, 2.25), "concrete_dark")
    b.span((top_x0 + 0.2, y_top, -2.35), (top_x1 - 0.2, fill, 2.35), "concrete_dark")
    for (x, z, r, sw) in ((-11.3, -1.2, 0.9, "concrete"), (-10.0, 1.1, 1.0, "concrete_dark"),
                          (-8.7, -0.6, 0.85, "brick"), (-7.2, 1.2, 0.9, "concrete"), (-5.9, -1.0, 0.8, "concrete_dark")):
        b.ball((x, fill + r * 0.35, z), r, sw, scale=(1.2, 0.7, 1.0))
    for (x, z, a, y) in ((-9.4, 0.3, 14, 0.5), (-7.6, -1.4, -10, -0.05), (-10.9, 0.2, -8, 0.5)):           # bricks
        b.span((x - 0.45, fill + y, z - 0.22), (x + 0.45, fill + y + 0.45, z + 0.22), "brick", rot=ry(a))
    for (x0, y0, x1, y1, z) in ((-11.2, fill - 0.2, -6.8, top + 1.9, -0.9), (-8.0, fill - 0.2, -3.6, top + 1.3, 0.9),
                                (-11.8, fill, -8.4, top + 0.9, 1.6)):                                  # planks
        L = math.hypot(x1 - x0, y1 - y0)
        b.box(((x0 + x1) / 2, (y0 + y1) / 2, z), (L, 0.16, 0.55), "caramel_wood",
              rot=rz(math.degrees(math.atan2(y1 - y0, x1 - x0))))
    cx, cy, cz = -6.4, fill + 0.1, -0.2                                                                # the chair
    b.span((cx - 0.8, cy, cz - 0.8), (cx + 0.8, cy + 0.35, cz + 0.8), "terracotta", rot=rz(-14))
    b.span((cx - 0.8, cy + 0.2, cz + 0.55), (cx + 0.8, cy + 1.6, cz + 0.85), "terracotta", rot=rz(-14))
    # past the skip: a scaffold tower in blue sheeting, its rubbish chute down into the skip, cones either side
    tx0, tx1, tz = -2.75, 0.2, 1.45
    th = top + 3.0
    b.span((tx0, base, -tz), (tx1, th, tz), "shirt_blue")                                              # sheeting
    for y in (2.4, 5.6, 8.8, 12.0):                                                                    # its bands
        for s in (-1, 1):
            b.span((tx0, y - 0.12, s * tz), (tx1, y + 0.12, s * (tz + 0.02)), "offwhite")
        for x in (tx0 - 0.02, tx1):
            b.span((x, y - 0.12, -tz), (x + 0.02, y + 0.12, tz), "offwhite")
    for x in (tx0, tx1):                                                                               # standards
        for z in (-tz, tz):
            b.cyl((x, (base + th + 1.2) / 2, z), 0.11, th + 1.2 - base, "metal", segments=8)
    for y in (th + 0.5, th + 1.1):                                                                     # guard rails
        for z in (-tz, tz):
            b.span((tx0, y - 0.05, z - 0.05), (tx1, y + 0.05, z + 0.05), "metal")
        for x in (tx0, tx1):
            b.span((x - 0.05, y - 0.05, -tz), (x + 0.05, y + 0.05, tz), "metal")
    b.span((tx0, th, -tz), (tx1, th + 0.25, tz), "caramel_wood")                                       # toe board
    p0, p1 = (tx0 + 0.6, th - 0.3), (-6.3, fill + 0.6)                                                 # the chute
    a = math.degrees(math.atan2(p1[0] - p0[0], p0[1] - p1[1]))
    n = 4
    for k in range(n):
        t0, t1 = k / n, (k + 1.12) / n
        c = (p0[0] + (p1[0] - p0[0]) * (t0 + t1) / 2, p0[1] + (p1[1] - p0[1]) * (t0 + t1) / 2, 0.0)
        h = math.hypot(p1[0] - p0[0], p1[1] - p0[1]) * (t1 - t0)
        b.b.cyl(RB.p(*c), 0.42, h, "rarity_legend", segments=10, bevel=False, rot=RB._rot(rz(a)), radius2=0.5)
    b.span((tx0 + 0.08, th - 0.7, -0.6), (tx0 + 1.28, th + 0.4, 0.6), "concrete_dark")                 # its hopper
    _cone(b, -1.2, base, -2.2)
    _cone(b, -1.2, base, 2.2)
    if lamp:
        _lamp(b, bulb, LONG_LAMP, base)
    return _out(b, bulb, name, mat, LONG_END)


# ---------------------------------------------------------------------------------------------------------- van --
def build_van(mat, lamp=True):
    """A FRESH FISH box lorry parked nose to the wall: a flat-fronted cab at -X under the box's peak (so the cab's
    roof is covered and there is no bonnet to climb), the cargo box up to WALL_TOP behind, its back doors swung wide
    open at the rear (x -0.5) and a crate set down on the ground behind it."""
    name = N + "Van"
    b, bulb = RB(), RB()
    W = 3.0                                                                                            # half width
    nose = PILE_END
    cab0, rear = nose + 0.4, -0.5                                                                      # cab face, back
    cab1 = cab0 + 3.4
    floor_y, box_top, cab_top, peak_y = 1.5, WALL_TOP, 5.6, 6.0
    for x in (cab0 + 1.5, rear - 2.6):                                                                 # wheels
        for zc in (-W + 0.45, W - 0.45):
            b.cyl((x, 1.0, zc), 1.0, 0.8, "fur_black", axis="Z", segments=14)
            b.cyl((x, 1.0, zc), 0.45, 0.84, "metal", axis="Z", segments=10)
    b.span((cab0 + 0.4, 0.8, -W + 0.6), (rear - 0.3, floor_y, W - 0.6), "concrete_dark")              # chassis
    b.span((cab1, floor_y, -W), (rear, box_top, W), "offwhite")                                       # cargo box
    b.span((cab0 - 0.15, peak_y, -W), (cab1 + 0.1, box_top, W), "offwhite")                           # the peak
    b.span((cab0 - 0.12, peak_y - 0.04, -W + 0.1), (cab1 + 0.1, peak_y + 0.02, W - 0.1), "concrete_dark")  # under it
    b.span((cab0, floor_y, -W + 0.2), (cab1 + 0.1, cab_top, W - 0.2), "offwhite")                     # the cab
    b.span((nose, 1.0, -W + 0.2), (cab0 + 0.05, 1.6, W - 0.2), "concrete")                            # bumper
    b.span((cab0 - 0.04, 3.3, -W + 0.5), (cab0 + 0.06, 5.2, W - 0.5), "night_sky")                    # windscreen
    b.span((cab0 - 0.06, 1.9, -1.4), (cab0 + 0.02, 2.9, 1.4), "concrete_dark")                        # grille
    for s in (-1, 1):                                                                                  # headlamps
        b.span((cab0 - 0.06, 2.1, s * (W - 0.9) - 0.35), (cab0 + 0.02, 2.6, s * (W - 0.9) + 0.35), "lamp_warm")
        b.span((cab0 - 0.17, box_top - 0.35, s * (W - 0.5) - 0.2), (cab0 - 0.12, box_top - 0.15,
               s * (W - 0.5) + 0.2), "fur_orange")                                                    # marker lamps
    for s in (-1, 1):
        zf = s * (W - 0.2)
        b.span((cab0 + 0.4, 3.5, zf - 0.04), (cab1 - 0.6, 5.1, zf + 0.04), "night_sky")               # side window
        b.span((cab1 - 0.5, 2.0, zf - 0.03), (cab1 - 0.42, 5.1, zf + 0.03), "concrete_dark")          # door line
        b.span((cab0 + 0.2, 4.3, zf), (cab0 + 0.4, 4.4, zf + s * 0.45), "fur_black")                   # mirror arm
        b.span((cab0 + 0.15, 3.9, zf + s * 0.4), (cab0 + 0.45, 4.7, zf + s * 0.6), "fur_black")       # mirror
        zb = s * W
        b.span((cab1 + 0.03, 3.0, zb - 0.04), (rear - 0.03, 3.6, zb + 0.04), "sign_teal")              # stripes
        b.span((cab0 - 0.12, box_top - 0.8, zb - 0.04), (rear - 0.03, box_top - 0.5, zb + 0.04), "sign_teal")
        b.ball((cab1 + 2.0, 7.4, zb), 1.1, "fish_blue", scale=(1.5, 0.75, 0.12))                       # the fish
        b.box((cab1 + 0.85, 7.4, zb), (1.15, 1.15, 0.2), "fish_blue", rot=rz(45))
        b.ball((cab1 + 3.4, 7.6, zb + s * 0.08), 0.16, "fur_black", scale=(1, 1, 0.5))                 # its eye
    label(b, "FRESH FISH", (cab1 + rear) / 2, 4.3, -W + 0.01, 0.2, 0.06, "sign_teal", -1)
    label(b, "FRESH FISH", (cab1 + rear) / 2, 4.3, W - 0.01, 0.2, 0.06, "sign_teal", 1)
    # the open back: a dark hold with a crate in it, the doors swung out flat to the sides, a step below
    b.span((rear - 0.05, floor_y + 0.15, -W + 0.25), (rear + 0.06, box_top - 0.25, W - 0.25), "night_sky")
    _crate(b, rear - 0.9, floor_y + 0.2, -1.2, 1.8)
    for s in (-1, 1):
        b.span((rear - 0.1, floor_y + 0.1, s * W), (rear + 0.05, box_top - 0.2, s * (W + 2.7)), "offwhite")
        b.span((rear + 0.05, 4.4, s * (W + 1.2)), (rear + 0.1, 5.4, s * (W + 1.6)), "metal")           # handle
    b.span((rear - 0.3, 0.7, -1.2), (rear + 0.35, 0.9, 1.2), "metal")                                 # back step
    _crate(b, 0.0, 0.0, 0.0, 0.8, stencil=None)                                                        # set down
    _box(b, 0.0, 0.8, 0.0, 0.6, 0.6, 0.45, 12)
    if lamp:
        _lamp(b, bulb, LONG_LAMP, 0.0)
    return _out(b, bulb, name, mat, LONG_END)


# ------------------------------------------------------------------------------------------ one lane's rows --
# Derek 11-02 17:44: "I don't think they should be separated into two lanes just make it one big one". The block
# between the lanes is gone, so the Alleyway is one lane 90 wide (set space x -45 to 45, its outer walls' inner
# faces), and each blocker is a whole row across it with one way through 24 to 26 wide, never in line with the next.
# A row is the pieces above end to end (each from its wall end X0, 16 or 8.5 long, its barrier on the row's line),
# with the row's own lamp post at the way through, leaning out over it. Pivot: the lane's middle (x 0) on the floor,
# on the row's line; place every row at rotY 0.
LANE_HALF = 45.0
ROWS = {
    # name: (pieces as (builder, x0 of its wall end, +1 runs toward +X or -1 toward -X), lamp x, lamp's lean,
    # barrier-only spans (x0, x1))
    "RowCamp": ([(build_bins, -45.0, 1), (build_pallets, -29.0, 1),                         # the way through in
                 (build_pallets, 45.0, -1), (build_bins, 29.0, -1)], (-13.35, 13.35), (1, -1), ()),   # the middle
    "RowVan": ([(build_pallets, 45.0, -1), (build_van, 29.0, -1), (build_skip, 13.0, -1),     # the way through
                (build_bins, -3.0, -1)], (-18.65,), (-1,), ()),                               # west
    "RowSkip": ([(build_bins, -45.0, 1), (build_skip, -29.0, 1), (build_pallets, -13.0, 1),  # the way through
                 (build_bins_short, 3.0, 1), (build_pallets_short, 11.5, 1)], (19.65,), (1,), ()),   # east
    # the way through in the middle; the west Warehouse's crate stack (x -43.65 to -40.75, its end at z 0.03 past
    # the row's line) stands between the wall and the first pile, the barrier on the row's line behind it
    "RowFar": ([(build_pallets, -40.6, 1), (build_bins_short, -24.6, 1),
                (build_bins, 45.0, -1), (build_skip, 29.0, -1)], (-16.45, 13.35), (1, -1), ((-45.0, -40.6),)),
}


def _row(key, mat):
    pieces, lamps, leans, walls = ROWS[key]
    s = Set(N + key)
    for builder, x0, d in pieces:
        s.put(builder(mat, lamp=False), x0 + d * 15.0, 0.0, 0.0 if d > 0 else 180.0)
    b, bulb = RB(), RB()
    for x, lean in zip(lamps, leans):                    # the row's lamp posts, the lamp out over the way through
        b.cyl((x, 0.2, 0.0), 0.35, 0.4, "concrete_dark")
        u = LAMP_UP
        b.cyl((x, 4.7 + u / 2, 0.0), 0.14, 8.6 + u, "fur_black")
        x1 = x + lean * 1.5
        b.span((min(x, x1) - 0.1, 8.75 + u, -0.1), (max(x, x1) + 0.1, 8.95 + u, 0.1), "fur_black")          # the arm
        xm = x + lean * 1.5
        b.span((xm - 0.45, 8.55 + u, -0.45), (xm + 0.45, 9.05 + u, 0.45), "fur_black")                    # the head
        bulb.span((xm - 0.35, 8.3 + u, -0.32), (xm + 0.35, 8.6 + u, 0.32), "lamp_warm")
    objs = s.finish(b, mat)
    objs.insert(1, bulb.finalize(N + key + "_Bulb", mat))
    if walls:
        bar = RB()
        for x0, x1 in walls:
            bar.span((x0, 0.0, -0.25), (x1, BARRIER_HIGH, 0.25), "concrete")
        objs.append(bar.finalize(N + key + "_Barrier", mat))
    return objs


def build_row_camp(mat):
    return _row("RowCamp", mat)


def build_row_van(mat):
    return _row("RowVan", mat)


def build_row_skip(mat):
    return _row("RowSkip", mat)


def build_row_far(mat):
    return _row("RowFar", mat)


ASSETS = {
    N + "Bins": (build_bins, 6000),
    N + "BinsShort": (build_bins_short, 6000),
    N + "Pallets": (build_pallets, 8000),
    N + "PalletsShort": (build_pallets_short, 6000),
    N + "Skip": (build_skip, 8000),
    N + "Van": (build_van, 8000),
    N + "RowCamp": (build_row_camp, 20000),
    N + "RowVan": (build_row_van, 24000),
    N + "RowSkip": (build_row_skip, 24000),
    N + "RowFar": (build_row_far, 24000),
}
