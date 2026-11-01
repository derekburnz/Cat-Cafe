"""The F84 camps (docs/design/cat-cafe/hometown-cannon.md sections 4 and 6a): each wild area's safe landing camp,
added in front of its moved v3.2 set. In F84 the old gate is the camp's way out and its arch the name arch, so a
camp is the ground, low side and back walls, the landing pad, a carrier basket and a few props in the area's theme.

  CatCafe_Camp_<Area>   in area space (areakit): place it with the same CFrame as the area's set, at the area's centre
                        on its floor with -Z toward the camp. The gate line is z G = -(depth / 2 + 1); the camp is
                        the whole width between the side walls and 30 deep, from G back to the back wall's inner face
                        at G - 30. On the ground: a path from the way out to the cannon, a red SAFE ZONE stripe just
                        inside the gate line across the opening with SAFE ZONE painted behind it, the landing pad
                        (cannon.landing_pad, the area's colour) 12 in from the gate line, and the theme props. Low
                        walls (3.5) at the sides and the back, with invisible `_Barrier` walls above them to 30 so
                        nobody jumps out. Everything solid collides; the pad and the paint are walk-on.
    _Basket             the carrier basket by the pad (a wicker cat carrier, lid open, a cushion inside), tagged
                        CampBasket, with a `Drop` Attachment over its opening (UpVector up) for the cat's hop in.

Spots (manifest points_roblox, area space [x, height, z]): `pad` (the pad's centre), `cannon` (where
CatCafe_Camp_Cannon_<Area> stands, barrel at rest +Z), `basket`, `index_board` (the area's Index Board beside the way
out, front -Z into the camp). The manifest's `camp` entry has the rect and the opening.

Theme props: Park benches, lamps, trees and flower beds; Neighbourhood a mailbox, picket fences, lamp posts, flower
beds and recycling bins; Woods a tent, a campfire with log benches, lanterns and pines; Sewer a manhole, a big pipe,
wall lanterns, barrels, cones and tyres.
"""

import math

from mathutils import Vector

import neighbourhood as nb
import park
import sewer as sw
import square
import woods
from areakit import Set
from cannon import frame_at, landing_pad
from common import RB, text_width
from plot import rot_x, rot_y

DEPTH = 30.0
WALL_H, BARRIER_H = 3.5, 30.0
PAD_IN, CANNON_IN = 12.0, 24.5          # the pad's centre and the cannon's spot, in from the gate line
BASKET_X = -11.0
# width, depth (the v3.2 set), the way out's half width, ground, path, wall, wall top, the area's colour
AREAS = {
    "Park": dict(W=160.0, D=120.0, half=16.0, ground="leaf_green", path="paving_sand", wall="paving_grout",
                 top="leaf_dark", trim="paw_park"),
    "Neighbourhood": dict(W=280.0, D=280.0, half=16.0, ground="leaf_green", path="paving_light", wall="brick",
                          top="offwhite", trim="paw_neighbourhood"),
    "Woods": dict(W=240.0, D=240.0, half=12.0, ground="fur_moss", path="fur_sand", wall="caramel_wood",
                  top="dark_wood", trim="paw_woods"),
    "Sewer": dict(W=180.0, D=180.0, half=12.0, ground="concrete_dark", path="concrete", wall="brick",
                  top="concrete", trim="paw_sewer"),
}
CAMPS = {}               # asset -> the manifest's camp entry
ATTACHMENTS = {}         # asset -> [(object suffix, name, Roblox point, Roblox rotation)]


def gate_line(area):
    return -(AREAS[area]["D"] / 2 + 1)


# ------------------------------------------------------------------------------------------------- basket --
def build_basket(mat, trim):
    """A wicker cat carrier, pivot at its base centre, front -Z: 2.6 x 1.5 x 1.9 with an open top, the lid standing
    open behind, a cushion inside and a paw tag on the front. Returns the objects and the Drop point (local)."""
    b = RB()
    w, d, h, t = 2.6, 1.9, 1.5, 0.15
    b.span((-w / 2 + 0.01, 0, -d / 2 + 0.01), (w / 2 - 0.01, 0.15, d / 2 - 0.01), "caramel_wood")   # floor
    for sx in (1, -1):
        b.span((sx * (w / 2 - t / 2) - t / 2, 0, -d / 2), (sx * (w / 2 - t / 2) + t / 2, h, d / 2), "treat_tan")
    for sz in (1, -1):
        b.span((-w / 2 + t, 0, sz * (d / 2 - t / 2) - t / 2), (w / 2 - t, h, sz * (d / 2 - t / 2) + t / 2),
               "treat_tan")
    for y in (0.35, 0.75, 1.15):                                                             # woven bands
        b.span((-w / 2 - 0.02, y - 0.06, -d / 2 - 0.02), (w / 2 + 0.02, y + 0.06, d / 2 + 0.02), "caramel_wood")
    b.span((-w / 2 - 0.05, h - 0.05, -d / 2 - 0.05), (w / 2 + 0.05, h + 0.1, d / 2 + 0.05), "fur_brown")   # rim
    b.span((-w / 2 + t + 0.02, 0.15, -d / 2 + t + 0.02), (w / 2 - t - 0.02, 0.45, d / 2 - t - 0.02), "blush")
    lid = rot_x(105)                                                      # hinged on the back edge, standing open
    hinge = Vector((0, h + 0.1, d / 2))
    b.box(tuple(hinge + lid @ Vector((0, 0.06, -d / 2))), (w + 0.1, 0.12, d + 0.1), "treat_tan", rot=lid)
    for k in (-0.6, 0, 0.6):
        b.box(tuple(hinge + lid @ Vector((0, 0.13, -d / 2 + k))), (w + 0.12, 0.03, 0.12), "caramel_wood", rot=lid)
    for sx in (1, -1):                                                     # the handle on the lid's top
        b.box(tuple(hinge + lid @ Vector((sx * 0.45, 0.35, -d / 2))), (0.16, 0.5, 0.16), "fur_brown", rot=lid)
    b.box(tuple(hinge + lid @ Vector((0, 0.62, -d / 2))), (1.02, 0.12, 0.12), "fur_brown", rot=lid)
    for dx, dy, r in ((0, 0, 0.42), (-0.33, 0.45, 0.13), (-0.12, 0.59, 0.13), (0.12, 0.59, 0.13), (0.33, 0.45, 0.13)):
        b.cyl((dx, 0.7 + dy, -d / 2 - 0.015), r, 0.05, trim, axis="Z", segments=12 if r > 0.2 else 8)   # paw tag
    return b, Vector((0, h + 0.4, 0))


# ------------------------------------------------------------------------------------------------- pieces --
def _manhole(mat):
    """A plain manhole cover in the ground: a metal ring round a ridged dark lid, 0.06 proud."""
    b = RB()
    b.cyl((0, 0.03, 0), 1.7, 0.06, "metal", segments=16)
    b.cyl((0, 0.05, 0), 1.45, 0.06, "concrete_dark", segments=16)
    for k in range(-2, 3):
        b.span((-1.05 + abs(k) * 0.12, 0.08, k * 0.45 - 0.08), (1.05 - abs(k) * 0.12, 0.1, k * 0.45 + 0.08), "metal")
    return [b.finalize("CatCafe_Camp_Manhole", mat)]


def _wall(g, bar, x0, z0, x1, z1, look):
    """A low wall from (x0, z0) to (x1, z1) (an axis-aligned rect), its top in the area's look, and a barrier."""
    wall, top = look["wall"], look["top"]
    if look is AREAS["Park"]:                                             # a stone base under a clipped hedge
        g.span((x0, 0, z0), (x1, 1.2, z1), wall)
        g.span((x0 + 0.05, 1.2, z0 + 0.05), (x1 - 0.05, WALL_H, z1 - 0.05), top)
    elif look is AREAS["Woods"]:                                          # planks, a capping rail
        g.span((x0 + 0.1, 0, z0 + 0.1), (x1 - 0.1, WALL_H - 0.3, z1 - 0.1), wall)
        g.span((x0, WALL_H - 0.3, z0), (x1, WALL_H, z1), top)
    else:                                                                 # brick under a coping
        g.span((x0 + 0.1, 0, z0 + 0.1), (x1 - 0.1, WALL_H - 0.3, z1 - 0.1), wall)
        g.span((x0, WALL_H - 0.3, z0), (x1, WALL_H, z1), top)
    bar.span((x0, WALL_H, z0), (x1, BARRIER_H, z1), wall)


def _posts(g, x0, z0, x1, z1, step, inward):
    """Log posts along a wooden wall's inner face (Woods): `inward` is the unit (x, z) into the camp."""
    L = math.hypot(x1 - x0, z1 - z0)
    n = int(L // step)
    for k in range(n + 1):
        t = k / n
        x, z = x0 + (x1 - x0) * t + inward[0] * 0.25, z0 + (z1 - z0) * t + inward[1] * 0.25
        g.cyl((x, (WALL_H + 0.4) / 2, z), 0.3, WALL_H + 0.4, "dark_wood", segments=8)


def build_camp(area):
    look = AREAS[area]
    name = "CatCafe_Camp_" + area

    def build(mat):
        W, half, trim = look["W"], look["half"], look["trim"]
        G = gate_line(area)
        B = G - DEPTH
        near = -look["D"] / 2                                             # the area's own floor edge
        s = Set(name)
        g, bar = RB(), RB()
        g.span((-W / 2 - 1, -1, B - 1), (W / 2 + 1, 0, near), look["ground"])               # the camp's ground
        g.span((-14, 0, G - PAD_IN - 9), (14, 0.02, near), look["path"])                     # the way in, round the pad
        g.span((-6.5, 0, B), (6.5, 0.02, G - PAD_IN - 9), look["path"])                      # to the cannon
        landing_pad(g, 0, 0, G - PAD_IN, trim)
        g.span((-half, 0, G - 0.6), (half, 0.05, G - 0.1), "bowl_red")                       # the SAFE ZONE stripe
        px = 0.45
        tw = text_width("SAFE ZONE", px)
        g.text("SAFE ZONE", (-tw / 2, 0.02, G - 1.4), px, 0.03, "milk", right=(1, 0, 0), up=(0, 0, -1))
        _wall(g, bar, -W / 2 - 1, B - 1, W / 2 + 1, B, look)                                  # back wall
        for sx in (1, -1):
            _wall(g, bar, min(sx * (W / 2 - 0.5), sx * (W / 2 + 0.5)), B - 1,
                  max(sx * (W / 2 - 0.5), sx * (W / 2 + 0.5)), near, look)                     # side walls
        if area == "Woods":
            _posts(g, -W / 2 + 1, B, W / 2 - 1, B, 6.0, (0, 1))
            for sx in (1, -1):
                _posts(g, sx * (W / 2 - 0.5), B + 2, sx * (W / 2 - 0.5), near - 1, 6.0, (-sx, 0))
        # the carrier basket beside the pad, turned to face it
        bb, drop = build_basket(mat, trim)
        bx, bz = BASKET_X, G - PAD_IN
        basket = bb.finalize("CatCafe_Camp_Basket", mat)
        s.put([basket], bx, bz, -90)
        R = rot_y(-90)
        ATTACHMENTS[name] = [("_Basket", "Drop", Vector((bx, 0, bz)) + R @ drop, R)]
        s.mark("pad", 0, G - PAD_IN)
        s.mark("cannon", 0, B + (DEPTH - CANNON_IN))
        s.mark("basket", bx, bz)
        s.mark("index_board", -(half + 7), G - 1.5)
        _theme(s, mat, area, G, B, W, half)
        objs = s.finish(g, mat)
        objs.append(bar.finalize(name + "_Barrier", mat))
        CAMPS[name] = {"rect_roblox": [-W / 2 + 0.5, B, W / 2 - 0.5, G], "gate_line_z": G,
                       "opening_half_width": half, "pad_radius": 8.0, "depth": DEPTH}
        return objs
    return build


def _theme(s, mat, area, G, B, W, half):
    cz = B + (DEPTH - CANNON_IN)                                           # the cannon's z
    if area == "Park":
        for sx in (1, -1):
            s.put(park.build_park_bench(mat), sx * 16, G - PAD_IN - 2, 90 * sx)
            s.put(square.build_lamp(mat), sx * 9, cz, 0)
            for x in (24, 44, 64):
                s.put(park.build_tree(mat), sx * x, B + 7, 0)
            for x in (18, 32, 52):
                s.put(nb.flowerbed(mat), sx * x, B + 2.5, 180)
            s.put(nb.flowerbed(mat), sx * (half + 14), G - 3, 0)
    elif area == "Neighbourhood":
        s.put(nb.mailbox(mat), half + 4, G - 3, 0)
        s.put(nb.recycling_bins(mat), -(half + 14), G - 3.5, 0)
        for sx in (1, -1):
            s.put(nb.lamp_post(mat), sx * 9, cz, 0)
            for x in (12, 20, 28, 36):
                s.put(nb.fence(mat, 8.0), sx * x, B + 3, 0)
            for x in (16, 32):
                s.put(nb.flowerbed(mat), sx * x, B + 6, 0)
            for x in (60, 90, 120):
                s.put(park.build_tree(mat), sx * x, B + 8, 0)
            s.put(nb.hedge(mat, 6.0), sx * (W / 2 - 4), G - 10, 90)
    elif area == "Woods":
        s.put(woods.tent(mat, "fur_orange"), 20, G - 21, 112)
        s.put(woods.campfire(mat), 15, G - 11, 0)
        s.put(woods.log_bench(mat), 15, G - 6.5, 0)
        s.put(woods.log_bench(mat), 20.5, G - 11, 90)
        for sx in (1, -1):
            s.put(woods.lantern(mat), sx * (half + 2), G - 1.5, 90 - 90 * sx)
            s.put(woods.lantern(mat), sx * 9, cz, 90 - 90 * sx)
            for x in (30, 50, 70, 90, 110):
                s.put(woods.pine(mat, h=18.0), sx * x, B + 5, 0)
        s.put(woods.stump(mat), -22, G - 20, 0)
        s.put(woods.fern(mat), -26, G - 8, 0)
        s.put(woods.fern(mat), 28, G - 4, 40)
    elif area == "Sewer":
        s.put(_manhole(mat), 18, G - 8, 0)
        s.put(sw.pipe_large(mat), -30, B + 3, 0)
        for sx in (1, -1):
            s.put(sw.wall_lantern(mat), sx * 9, B, 180, y=1.2)
            s.put(sw.wall_lantern(mat), sx * 40, B, 180, y=1.2)
            s.put(sw.barrel(mat), sx * 22, G - 24, 0)
            s.put(sw.traffic_cone(mat), sx * (half + 2), G - 2.5, 0)
        s.put(sw.barrel(mat), 24.5, G - 25.5, 0)
        s.put(sw.tyre_stack(mat), 34, G - 20, 30)
        s.put(sw.traffic_cone(mat), 21, G - 10.5, 0)


def rbx_attachments(name):
    return [(o, n, frame_at(p, R)) for o, n, p, R in ATTACHMENTS.get(name, [])]


ASSETS = {"CatCafe_Camp_" + a: (build_camp(a), 20000) for a in AREAS}
