"""F80 door sets and cat flaps (golden-fish.md section 4b, Derek 2026-10-28: "can add decor for cat door / doors
also"). A door set restyles the cafe's front and back doors together; a cat flap sits low in the back door.

  CatCafe_Door_<Name>_Front     double doors for the front doorway (7 wide, up to the transom bar at 7.35)
  CatCafe_Door_<Name>_Back      a single door for the back doorway (6 wide by 7.5), hung like CatCafe_Plot_BackDoor
  CatCafe_CatFlap_<Name>        a cat flap for the CatFlap attachment of any back door, the cafe's own included
  CatCafe_CatFlap_Plain         the cafe's own flap on its own, for a door set in use with no flap

Pivots are where CafeService.refreshDoors puts each model, facing out (-Z):
  _Front   the foot of the front doorway on the wall's inside face, plot (0, 0, -14); the street is -Z
  _Back    the foot of the back doorway in the middle of the wall, plot (-8, 0, 14.5), turned 180: the yard is -Z
  flaps    a back leaf's CatFlap attachment, the foot of its yard face in the middle. The leaf runs from z 0 (its yard
           face) to z 0.3 (its cafe face) and the hole is x -0.9..0.9, y 0.23..2.13. A flap stays inside x -1.48..1.48,
           y -0.13..2.75 and 0.35 off either face, and back leaves keep that patch flat on both faces (ZONE).

Model layout (rbx_export), all modelled shut, nothing solid (CafeService turns collisions off):
  CatCafe_Door_<Name>_Front               the threshold
    _Front_LeafL, _Front_LeafR            the -X and +X leaves, each pivot on its hinge at the wall's inside face
                                          (x -3.4 or 3.4, z -0.03): -90 (LeafL) or +90 (LeafR) about Y opens it in
      _Front_LeafL_Glass, _LeafR_Glass    their glass
  CatCafe_Door_<Name>_Back                the threshold and the inside architrave (the cafe's own door brings these)
    _Back_Leaf                            the leaf, pivot on the cafe's own hinge (plot -10.88, 0, 14.72), so -90
                                          about Y swings it out into the yard; a CatFlap Attachment as on the cafe's
      _Back_Leaf_Glass                    its glass
      _Back_Sign, _Back_Sign_Bulb         the CLOSED UNTIL SUNRISE sign for the night, as on the cafe's own door
  CatCafe_CatFlap_<Name>                  the flap's frame on both faces of the leaf and a lining through the hole
    _Flap                                 the panel, pivot on its top hinge (0, 2.13, 0.15): turn it about X
      _Flap_Bulb                          the Neon Paw's outline (_Bulb: Neon at night)
    _Bell                                 the Bell Flap's bell, pivot where it hangs
"""

import math

from mathutils import Matrix, Vector

import doors
from common import RB, bake_transform
from plot import arc, rot_z

F_HINGE, F_Y0, F_Y1, F_T, F_ZIN = 3.4, 0.08, 7.33, 0.25, -0.03   # front leaves: hinge |x|, foot, top, thickness,
F_W = F_HINGE - 0.02                                              # inside face; two leaves meet with a 0.04 gap
B_HINGE = (-doors.HX - 8.0, 0.0, 14.5 - doors.HZ)                # the cafe's own hinge in the back model (2.88, 0, -0.22)
B_W, B_Y0, B_Y1, B_T = doors.LW, doors.LY0, doors.LY1, doors.LT
HOLE = (doors.FC - doors.FW / 2, doors.FC + doors.FW / 2, doors.FY0, doors.FY1)   # in a back leaf: u0, u1, y0, y1
ZONE = (doors.FC - 1.52, doors.FC + 1.52, doors.LY0 + 2.78)       # u0, u1, top: no relief here on a back leaf
FX, FY0, FY1, FT = doors.FW / 2, doors.FY0 - doors.LY0, doors.FY1 - doors.LY0, doors.LT    # a flap's hole and leaf
FLAP_HINGE = (0.0, FY1, FT / 2)
RC = 1.23                                                         # round flaps: the centre of their ring
RPI = Matrix.Rotation(math.pi, 4, "Z")                            # half a turn about Roblox Y


def _ring(b, cx, cy, z0, z1, r_out, r_in, swatch, segs=12, a0=90.0):
    """Blocks round a circle in the XY plane between depths z0 and z1, a flat side at a0 (90: flat on top and bottom
    when segs is a multiple of 4), so the outer edge never dips below cy - r_out."""
    chord = 2 * r_out * math.tan(math.pi / segs) * 1.02
    for k in range(segs):
        a = math.radians(a0 + 360.0 * k / segs)
        rr = (r_out + r_in) / 2
        b.box((cx + rr * math.cos(a), cy + rr * math.sin(a), (z0 + z1) / 2), (r_out - r_in, chord, abs(z1 - z0)),
              swatch, rot=rot_z(math.degrees(a)))


def _bar(b, p0, p1, t, z0, z1, swatch):
    """A straight bar t wide in the XY plane from p0 to p1, between depths z0 and z1."""
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    b.box(((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, (z0 + z1) / 2), (math.hypot(dx, dy), t, abs(z1 - z0)), swatch,
          rot=rot_z(math.degrees(math.atan2(dy, dx))))


class Leaf:
    """A door leaf drawn in its own terms: u along it from the hinge edge (0) to the free edge (w), y up from the
    floor, n out through its outside face (the street or the yard). It writes into builders in the hinge's frame,
    x = sx * u and z = n, which _place turns half round so the outside faces -Z like every door model."""

    def __init__(self, sx, w, y0, y1, t, out, back):
        self.sx, self.w, self.y0, self.y1, self.t, self.back = sx, w, y0, y1, t, back
        self.out, self.inn = out, out - t                 # the outside and inside faces
        self.mid = out - t / 2

    def X(self, u):
        return self.sx * u

    def faces(self, d, d_in=None):
        """(n0, n1) of a relief d proud of the outside face and d_in (default d) proud of the inside one."""
        return ((self.out, self.out + d), (self.inn - (d if d_in is None else d_in), self.inn))

    def span(self, b, u0, u1, y0, y1, n0, n1, swatch):
        xa, xb = sorted((self.X(u0), self.X(u1)))
        b.span((xa, y0, min(n0, n1)), (xb, y1, max(n0, n1)), swatch)

    def box(self, b, u, y, n, su, sy, sn, swatch, deg=0.0):
        """A box centred at (u, y, n), turned deg in the leaf's plane (from u toward y)."""
        b.box((self.X(u), y, n), (su, sy, sn), swatch, rot=None if deg == 0 else rot_z(self.sx * deg))

    def bar(self, b, p0, p1, t, n0, n1, swatch):
        _bar(b, (self.X(p0[0]), p0[1]), (self.X(p1[0]), p1[1]), t, n0, n1, swatch)

    def cyl(self, b, u, y, n, r, h, swatch, axis="N", segments=12):
        b.cyl((self.X(u), y, n), r, h, swatch, axis={"N": "Z", "U": "X", "Y": "Y"}[axis], segments=segments)

    def ring(self, b, u, y, n0, n1, r_out, r_in, swatch, segs=12):
        _ring(b, self.X(u), y, n0, n1, r_out, r_in, swatch, segs)

    def fan(self, b, n, depth, apex, chain, swatch):
        """Flat triangles from apex to each pair along chain, (u, y) points, depth thick about n."""
        b.fan_z(n, (self.X(apex[0]), apex[1]), [(self.X(u), y) for u, y in chain], depth, swatch)

    def outline(self, b, u0, u1, y0, y1, t, n0, n1, swatch, gap=None):
        """A rectangular frame t wide inside (u0, y0)..(u1, y1); gap = (ga, gb) leaves the bottom rail out there."""
        self.span(b, u0, u0 + t, y0, y1, n0, n1, swatch)
        self.span(b, u1 - t, u1, y0, y1, n0, n1, swatch)
        self.span(b, u0 + t, u1 - t, y1 - t, y1, n0, n1, swatch)
        if gap is None:
            self.span(b, u0 + t, u1 - t, y0, y0 + t, n0, n1, swatch)
        else:
            if gap[0] > u0 + t:
                self.span(b, u0 + t, gap[0], y0, y0 + t, n0, n1, swatch)
            if gap[1] < u1 - t:
                self.span(b, gap[1], u1 - t, y0, y0 + t, n0, n1, swatch)

    def slab(self, b, u0, u1, y0, y1, n0, n1, holes, swatch):
        """Boxes filling (u0, y0)..(u1, y1) between depths n0 and n1 except for the rectangular holes."""
        ys = sorted({y0, y1} | {min(max(h[k], y0), y1) for h in holes for k in (2, 3)})
        for ya, yb in zip(ys, ys[1:]):
            if yb - ya < 1e-4:
                continue
            cuts = sorted((max(h[0], u0), min(h[1], u1)) for h in holes
                          if h[2] < yb - 1e-6 and h[3] > ya + 1e-6 and h[0] < u1 and h[1] > u0)
            u = u0
            for ha, hb in cuts:
                if ha > u + 1e-4:
                    self.span(b, u, ha, ya, yb, n0, n1, swatch)
                u = max(u, hb)
            if u1 > u + 1e-4:
                self.span(b, u, u1, ya, yb, n0, n1, swatch)

    def body(self, b, holes, swatch):
        self.slab(b, 0, self.w, self.y0, self.y1, self.inn, self.out, holes + self.flap_hole(), swatch)

    def glass(self, g, rect, d=0.02):
        """Glass in a rectangular hole, d either side of the middle, a hair inside the hole's edges."""
        u0, u1, y0, y1 = rect
        self.span(g, u0 + 0.005, u1 - 0.005, y0 + 0.005, y1 - 0.005, self.mid - d, self.mid + d, "glass")

    def flap_hole(self):
        return [HOLE] if self.back else []

    def gap(self):
        """The bottom rail's gap for the flap patch, on a back leaf."""
        return (ZONE[0], ZONE[1]) if self.back else None

    def knuckles(self, b, ys, r, swatch):
        """Hinge knuckles on the hinge edge at the pivot's face."""
        for y in ys:
            self.cyl(b, 0.0, y, 0.0, r, 0.42, swatch, axis="Y", segments=8)


def _place(ob, hinge):
    """Turn a leaf drawn in its own frame half round about its hinge (the object's origin), so its outside faces -Z,
    and hang it at `hinge` in the door model; the hinge stays its pivot."""
    ob.matrix_world = RPI
    bake_transform(ob)
    ob.location = RB.p(*hinge)
    return ob


def _used(rb):
    return bool(rb.b.prims)


# ------------------------------------------------------------------------------------------------ door sets --
class FireEscape:
    """Alley (Common): a red steel door with rivets and a small wired window. A panic bar inside, a lever outside."""
    NAME, SILL, TRIM, SIGN_Z = "FireEscape", "concrete_dark", "concrete_dark", 0.1
    RED, STEEL = "bowl_red", "metal"

    def leaf(self, L, b, g):
        w, y0, y1 = L.w, L.y0, L.y1
        ww, wh = (1.1, 1.25) if L.back else (0.9, 1.15)
        wu0, wy1 = w / 2 - ww / 2, y1 - 1.0
        win = (wu0, wu0 + ww, wy1 - wh, wy1)
        L.body(b, [win], self.RED)
        for n0, n1 in L.faces(0.04):                                           # the raised border, both faces
            L.outline(b, 0.12, w - 0.12, y0 + 0.12, y1 - 0.12, 0.22, n0, n1, self.RED, L.gap())
        step = 0.42                                                            # rivets along it, outside
        for u, y in self._rivets(L, step):
            L.span(b, u - 0.045, u + 0.045, y - 0.045, y + 0.045, L.out + 0.04, L.out + 0.075, self.STEEL)
        for n0, n1 in L.faces(0.05):                                           # the window's steel frame
            L.outline(b, win[0] - 0.1, win[1] + 0.1, win[2] - 0.1, win[3] + 0.1, 0.1, n0, n1, self.STEEL)
        L.glass(g, win)
        u = win[0] + 0.2                                                       # the wire in the glass, a square mesh
        while u < win[1] - 0.1:
            L.span(b, u - 0.0125, u + 0.0125, win[2], win[3], L.mid + 0.02, L.mid + 0.045, self.STEEL)
            u += 0.2
        y = win[2] + 0.2
        while y < win[3] - 0.1:
            L.span(b, win[0], win[1], y - 0.0125, y + 0.0125, L.mid + 0.045, L.mid + 0.07, self.STEEL)
            y += 0.2
        if not L.back:                                                         # kick plates
            for n0, n1 in L.faces(0.03):
                L.span(b, 0.4, w - 0.4, y0 + 0.4, y0 + 1.15, n0, n1, self.STEEL)
        hu, hy = w - 0.45, 3.4                                                 # lever outside
        L.cyl(b, hu, hy, L.out + 0.025, 0.15, 0.05, self.STEEL, segments=10)
        L.span(b, hu - 0.05, hu + 0.05, hy - 0.05, hy + 0.05, L.out + 0.05, L.out + 0.19, self.STEEL)
        L.span(b, hu - 0.62, hu + 0.05, hy - 0.06, hy + 0.06, L.out + 0.19, L.out + 0.29, self.STEEL)
        # a panic bar inside, on two brackets
        bu0, bu1, by = 0.75, w - 0.6, 3.35
        for u in (bu0, bu1):
            L.span(b, u - 0.07, u + 0.07, by - 0.12, by + 0.12, L.inn - 0.14, L.inn, self.STEEL)
        L.span(b, bu0 - 0.07, bu1 + 0.07, by - 0.08, by + 0.08, L.inn - 0.24, L.inn - 0.14, self.STEEL)
        for y in (0.95, (y0 + y1) / 2, y1 - 0.6):                              # butt hinges
            L.span(b, 0.03, 0.42, y - 0.2, y + 0.2, *((0.0, 0.03) if L.back else (-0.03, 0.0)), self.STEEL)
        L.knuckles(b, (0.95, (y0 + y1) / 2, y1 - 0.6), 0.07 if L.back else 0.06, self.STEEL)

    @staticmethod
    def _rivets(L, step):
        w, y0, y1 = L.w, L.y0, L.y1
        out = []
        for u in (0.23, w - 0.23):
            y = y0 + 0.23
            while y <= y1 - 0.23 + 1e-6:
                out.append((u, y))
                y += step
        u = 0.23 + step
        while u < w - 0.23 - step / 2:
            out.append((u, y1 - 0.23))
            if not (L.back and ZONE[0] - 0.05 < u < ZONE[1] + 0.05):
                out.append((u, y0 + 0.23))
            u += step
        return out


class GardenGate:
    """Park (Common): a green plank door with a little round window ringed with leaves, iron straps and a ring pull;
    a ledge and brace inside."""
    NAME, SILL, TRIM, SIGN_Z = "GardenGate", "dark_wood", "leaf_dark", 0.1
    GREEN, GROOVE, IRON, WOOD, LEAVES = "leaf_dark", "dumpster_green", "fur_black", "caramel_wood", ("leaf_green",
                                                                                                      "paw_park")

    def leaf(self, L, b, g):
        w, y0, y1 = L.w, L.y0, L.y1
        r_sq = 0.5 if L.back else 0.42
        cu, cy = w / 2, y1 - (1.5 if L.back else 1.35)
        win = (cu - r_sq, cu + r_sq, cy - r_sq, cy + r_sq)
        holes = [win] + L.flap_hole()
        # a dark core behind the planks shows in the grooves between them
        core = [(h[0] - 0.01, h[1] + 0.01, h[2] - 0.01, h[3] + 0.01) for h in holes]
        L.slab(b, 0.01, w - 0.01, y0 + 0.01, y1 - 0.01, L.inn + 0.04, L.out - 0.04, core, self.GROOVE)
        n = max(4, round(w / 0.72))
        pw = w / n
        for k in range(n):
            L.slab(b, k * pw + (0.025 if k else 0.0), (k + 1) * pw - (0.025 if k < n - 1 else 0.0), y0, y1,
                   L.inn, L.out, holes, self.GREEN)
        # the window: a wooden ring round the glass, a cross bar, leaves round the ring outside
        r_out, r_in = r_sq * 1.414 + 0.04, r_sq - 0.04
        for n0, n1 in L.faces(0.06):
            L.ring(b, cu, cy, n0, n1, r_out, r_in, self.WOOD, segs=12)
        L.glass(g, win)
        L.span(b, cu - 0.04, cu + 0.04, win[2], win[3], L.mid - 0.05, L.mid + 0.05, self.WOOD)
        L.span(b, win[0], win[1], cy - 0.04, cy + 0.04, L.mid - 0.05, L.mid + 0.05, self.WOOD)
        k_leaves = 12
        for k in range(k_leaves):
            a = math.radians(360.0 * k / k_leaves + 15)
            rr = r_out + 0.14
            d = 0.0 if k % 2 else 0.01                           # a hair off the face and each other
            L.box(b, cu + rr * math.cos(a), cy + rr * math.sin(a), L.out + 0.031 + d / 2, 0.3, 0.13, 0.05 + d,
                  self.LEAVES[k % 2], deg=math.degrees(a) + 90 + 35)
        # iron straps outside (the low one short on a back leaf, clear of the flap), knuckles on the hinge edge
        low, high = y0 + 1.0, y1 - 0.5
        for y, length in ((low, 1.2 if L.back else 0.72 * w), (high, 0.62 * w if L.back else 0.72 * w)):
            L.span(b, 0.0, length, y - 0.11, y + 0.11, L.out, L.out + 0.04, self.IRON)
            L.box(b, length, y, L.out + 0.02, 0.2, 0.2, 0.04, self.IRON, deg=45)
            for u in (0.25, length * 0.55):
                L.span(b, u - 0.04, u + 0.04, y - 0.04, y + 0.04, L.out + 0.04, L.out + 0.065, "metal")
        L.knuckles(b, (low, high), 0.07 if L.back else 0.06, self.IRON)
        # a ring pull outside, a thumb latch inside
        hu, hy = w - 0.5, 3.4
        L.span(b, hu - 0.13, hu + 0.13, hy - 0.18, hy + 0.18, L.out, L.out + 0.03, self.IRON)
        L.ring(b, hu, hy - 0.26, L.out + 0.03, L.out + 0.07, 0.2, 0.15, self.IRON, segs=8)
        L.span(b, hu - 0.4, hu + 0.05, hy - 0.05, hy + 0.05, L.inn - 0.12, L.inn, self.IRON)
        # a ledge and brace inside (on a back leaf both ledges stay above the flap)
        lo = 3.3 if L.back else low
        for y in (lo, high):
            L.span(b, 0.15, w - 0.15, y - 0.2, y + 0.2, L.inn - 0.08, L.inn, self.GREEN)
        L.bar(b, (0.35, lo + 0.15), (w - 0.35, high - 0.15), 0.32, L.inn - 0.07, L.inn, self.GREEN)


class FrontPorch:
    """Neighbourhood (Rare): a white door with a fanlight window and a wreath, raised panels and brass."""
    NAME, SILL, TRIM, SIGN_Z = "FrontPorch", "brick", "offwhite", 0.17
    WHITE, MOULD, BRASS = "offwhite", "cream", "brass"

    def _wreath(self, L, b, cu, cy, base):
        """Leaves round a ring, red berries and a bow at the bottom, sitting on depth `base`."""
        k_leaves = 16
        for k in range(k_leaves):
            a = math.radians(360.0 * k / k_leaves)
            d = 0.006 * (k % 2)                                  # alternate leaves a hair proud of the others
            L.box(b, cu + 0.45 * math.cos(a), cy + 0.45 * math.sin(a), base + 0.04 + d, 0.34, 0.16, 0.08,
                  ("leaf_dark", "leaf_green")[k % 2], deg=math.degrees(a) + 90 + 25)
        for k in range(6):
            a = math.radians(30 + 60 * k)
            u, y = cu + 0.47 * math.cos(a), cy + 0.47 * math.sin(a)
            L.span(b, u - 0.045, u + 0.045, y - 0.045, y + 0.045, base + 0.09, base + 0.13, "bowl_red")
        by = cy - 0.47
        for s in (-1, 1):
            L.box(b, cu + s * 0.13, by, base + 0.12, 0.24, 0.14, 0.05, "bowl_red", deg=s * 20)
            L.box(b, cu + s * 0.09, by - 0.2, base + 0.12, 0.08, 0.26, 0.04, "bowl_red", deg=s * 15)
        L.span(b, cu - 0.06, cu + 0.06, by - 0.06, by + 0.06, base + 0.12, base + 0.16, "bowl_red")

    def _arch_window(self, L, b, g, cu, ys, r, y_bot, bars):
        """A window with a round top: glass from y_bot up to the springing ys and the half disc over it, mouldings
        round it on both faces, sunburst bars in the half disc."""
        # the leaf left in the two corners above the arc, full thickness
        L.fan(b, L.mid, L.t, (cu + r, ys + r), arc(cu, ys, r, 0, 90, 6), self.WHITE)
        L.fan(b, L.mid, L.t, (cu - r, ys + r), arc(cu, ys, r, 90, 180, 6), self.WHITE)
        L.fan(g, L.mid, 0.04, (cu, ys + 0.005), arc(cu, ys + 0.005, r - 0.01, 0, 180, 10), "glass")
        if ys > y_bot:
            L.glass(g, (cu - r, cu + r, y_bot, ys + 0.01))
        for a in bars:
            rad = math.radians(a)
            L.bar(b, (cu, ys), (cu + r * math.cos(rad), ys + r * math.sin(rad)), 0.07, L.mid - 0.05, L.mid + 0.05,
                  self.WHITE)
        L.span(b, cu - r, cu + r, ys - 0.04, ys + 0.04, L.mid - 0.05, L.mid + 0.05, self.WHITE)
        for n0, n1 in L.faces(0.05):
            for k in range(8):                                   # the arch moulding, staggered so blocks never share
                a = math.radians(180 * (k + 0.5) / 8)            # a face
                rr = r + 0.07
                dz = (0.004 + 0.006 * (k % 2)) * (1 if n0 >= L.out else -1)   # off the face, never sharing one
                L.box(b, cu + rr * math.cos(a), ys + rr * math.sin(a), (n0 + n1) / 2 + dz, 0.14,
                      2 * (r + 0.14) * math.sin(math.pi / 16) * 1.12, abs(n1 - n0), self.MOULD,
                      deg=math.degrees(a))
            L.span(b, cu - r - 0.14, cu - r, y_bot - 0.14, ys, n0, n1, self.MOULD)
            L.span(b, cu + r, cu + r + 0.14, y_bot - 0.14, ys, n0, n1, self.MOULD)
            L.span(b, cu - r, cu + r, y_bot - 0.14, y_bot, n0, n1, self.MOULD)

    def leaf(self, L, b, g):
        w, y0, y1 = L.w, L.y0, L.y1
        cu = w / 2
        if L.back:                                               # a fanlight over two panels, the wreath between
            r, ys = 1.25, 5.5
            fan_hole = (cu - r, cu + r, ys, ys + r)
            L.body(b, [fan_hole], self.WHITE)
            self._arch_window(L, b, g, cu, ys, r, ys, (30, 60, 90, 120, 150))
            panels = [(0.45, cu - 0.72, 3.15, 5.15), (cu + 0.72, w - 0.45, 3.15, 5.15),
                      (0.45, ZONE[0] - 0.08, 0.6, 2.75), (ZONE[1] + 0.08, w - 0.45, 0.6, 2.75)]
            wreath_y = 4.15
        else:                                                    # a tall round-topped glass, a panel under it
            r, ys, y_bot = 0.95, y1 - 0.6 - 0.95, 3.95
            L.body(b, [(cu - r, cu + r, y_bot, ys + r)], self.WHITE)
            self._arch_window(L, b, g, cu, ys, r, y_bot, (45, 90, 135))
            panels = [(0.42, w - 0.42, 0.55, 3.45)]
            wreath_y = 4.6
        for (u0, u1, pa, pb) in panels:
            for n0, n1 in L.faces(0.05):
                L.outline(b, u0, u1, pa, pb, 0.12, n0, n1, self.MOULD)
        if L.back:
            self._wreath(L, b, cu, wreath_y, L.out)
        else:                                                    # hung on a ribbon from the arch moulding
            self._wreath(L, b, cu, wreath_y, L.out + 0.02)
            L.span(b, cu - 0.05, cu + 0.05, wreath_y + 0.4, ys + r + 0.14, L.out + 0.05, L.out + 0.07, "bowl_red")
            for n0, n1 in L.faces(0.03):                         # brass kick plate
                L.span(b, 0.4, w - 0.4, y0 + 0.12, y0 + 0.42, n0, n1, self.BRASS)
        hu, hy = w - 0.42, 3.0 if L.back else 3.6                # brass knobs
        for (zf, s) in ((L.out, 1), (L.inn, -1)):
            L.cyl(b, hu, hy, zf + s * 0.015, 0.12, 0.03, self.BRASS, segments=10)
            L.cyl(b, hu, hy, zf + s * 0.06, 0.04, 0.06, self.BRASS, segments=8)
            L.cyl(b, hu, hy, zf + s * 0.12, 0.1, 0.06, self.BRASS, segments=10)
        L.knuckles(b, (0.95, y1 - 0.6), 0.07 if L.back else 0.06, self.BRASS)


class LogCabin:
    """Woods (Common): split logs laid across with long iron strap hinges and a ring pull; boards inside."""
    NAME, SILL, TRIM, SIGN_Z = "LogCabin", "dark_wood", "fur_bramble", 0.1
    LOGS, IRON = ("caramel_wood", "fur_acorn", "fur_caramel"), "fur_black"

    def leaf(self, L, b, g):
        w, y0, y1 = L.w, L.y0, L.y1
        n = round((y1 - y0) / 0.52)
        lh = (y1 - y0) / n
        zone = [(ZONE[0], ZONE[1], y0, ZONE[2])] if L.back else []
        for i in range(n):
            ya, yb = y0 + i * lh, y0 + (i + 1) * lh
            tone = self.LOGS[i % 3]
            L.slab(b, 0, w, ya, yb, L.inn, L.out, L.flap_hole(), tone)
            # the round of the split log, planed flat where a flap goes
            L.slab(b, 0, w, ya + 0.06, yb - 0.06, L.out, L.out + 0.07, zone, tone)
        # boards inside: two battens and a latch bar
        lo = 3.4 if L.back else y0 + 1.0
        for y in (lo, y1 - 0.9):
            L.span(b, 0.15, w - 0.15, y - 0.17, y + 0.17, L.inn - 0.08, L.inn, "caramel_wood")
        L.span(b, w - 1.1, w - 0.2, 2.95 if L.back else 3.0, (2.95 if L.back else 3.0) + 0.14, L.inn - 0.1, L.inn,
               "dark_wood")
        # long iron straps over the logs, arrow ends, nail heads; knuckles on the hinge edge
        ys = (y0 + 0.8, 3.65, y1 - 0.65) if L.back else (y0 + 0.9, (y0 + y1) / 2, y1 - 0.9)
        for k, y in enumerate(ys):
            length = 1.0 if (L.back and k == 0) else (0.62 * w if L.back else 0.74 * w)
            L.span(b, 0.0, length, y - 0.12, y + 0.12, L.out + 0.07, L.out + 0.11, self.IRON)
            L.box(b, length + 0.02, y, L.out + 0.09, 0.26, 0.26, 0.04, self.IRON, deg=45)
            for u in (0.3, length * 0.5, length - 0.15):
                L.span(b, u - 0.045, u + 0.045, y - 0.045, y + 0.045, L.out + 0.11, L.out + 0.135, "metal")
        L.knuckles(b, ys, 0.08 if L.back else 0.06, self.IRON)
        hu, hy = w - 0.5, 3.0 if L.back else 3.3                 # a ring pull
        L.span(b, hu - 0.14, hu + 0.14, hy - 0.14, hy + 0.14, L.out + 0.07, L.out + 0.1, self.IRON)
        L.ring(b, hu, hy - 0.27, L.out + 0.1, L.out + 0.14, 0.22, 0.16, self.IRON, segs=8)


class PortholeHatch:
    """Sewer (Rare): a steel hatch with a bolted round window and a red wheel handle, a bolted band round the edge."""
    NAME, SILL, TRIM, SIGN_Z = "PortholeHatch", "concrete_dark", "concrete_dark", 0.14
    BODY, BAND, BOLT, RIM, WHEEL = "fur_slate", "concrete_dark", "metal", "brass", "bowl_red"

    def _wheel(self, L, b, cu, cy, r, n_face, s):
        """A valve wheel on its stem off the face at depth n_face, s the outward sign."""
        L.cyl(b, cu, cy, n_face + s * 0.12, 0.09, 0.24, self.BOLT, segments=8)
        L.ring(b, cu, cy, n_face + s * 0.14, n_face + s * 0.22, r, r - 0.1, self.WHEEL, segs=12)
        for a in (45, 135, 225, 315):
            rad = math.radians(a)
            L.bar(b, (cu + 0.08 * math.cos(rad), cy + 0.08 * math.sin(rad)),
                  (cu + (r - 0.06) * math.cos(rad), cy + (r - 0.06) * math.sin(rad)), 0.07,
                  n_face + s * 0.16, n_face + s * 0.2, self.WHEEL)

    def leaf(self, L, b, g):
        w, y0, y1 = L.w, L.y0, L.y1
        cu = w / 2
        a, py, wy, wr = (0.78, 5.45, 3.62, 0.55) if L.back else (0.62, 4.3, 2.55, 0.5)
        port = (cu - a, cu + a, py - a, py + a)
        L.body(b, [port], self.BODY)
        r_out, r_in = a * 1.414 + 0.1, a - 0.04
        for n0, n1 in L.faces(0.08):                             # the brass porthole ring and its bolts
            L.ring(b, cu, py, n0, n1, r_out, r_in, self.RIM, segs=12)
            top = n1 if n1 > L.out - 1e-6 else n0
            s = 1 if n1 > L.out - 1e-6 else -1
            for k in range(8):
                ang = math.radians(22.5 + 45 * k)
                u, y = cu + (r_out + r_in) / 2 * math.cos(ang), py + (r_out + r_in) / 2 * math.sin(ang)
                L.span(b, u - 0.05, u + 0.05, y - 0.05, y + 0.05, top, top + s * 0.03, self.BOLT)
        L.glass(g, port)
        for n0, n1 in L.faces(0.05):                             # the bolted band round the edge
            L.outline(b, 0.1, w - 0.1, y0 + 0.1, y1 - 0.1, 0.25, n0, n1, self.BAND, L.gap())
        for u, y in FireEscape._rivets(L, 0.5):
            L.span(b, u - 0.05, u + 0.05, y - 0.05, y + 0.05, L.out + 0.05, L.out + 0.085, self.BOLT)
        self._wheel(L, b, cu, wy, wr, L.out, 1)
        self._wheel(L, b, cu, wy, wr * 0.8, L.inn, -1)
        for y in (wy - 1.3 if not L.back else 4.0, py + a + 0.9):    # two clamping dogs on the free edge
            if y < y1 - 0.4:
                L.span(b, w - 0.42, w - 0.1, y - 0.09, y + 0.09, L.out + 0.05, L.out + 0.13, self.BOLT)
        L.knuckles(b, (0.95, (y0 + y1) / 2, y1 - 0.6), 0.09 if L.back else 0.07, self.BAND)


class PanedGlass:
    """Classic (Common): a cream door glazed in small panes with offwhite beads, raised panels and a brass knob."""
    NAME, SILL, TRIM, SIGN_Z = "PanedGlass", "dark_wood", "offwhite", 0.1
    BODY, BEAD, BRASS = "cream", "offwhite", "brass"

    def leaf(self, L, b, g):
        w, y0, y1 = L.w, L.y0, L.y1
        if L.back:
            glazed, cols, rows = (0.5, w - 0.5, 3.2, y1 - 0.5), 3, 3
            panels = [(0.45, ZONE[0] - 0.08, 0.6, 2.75), (ZONE[1] + 0.08, w - 0.45, 0.6, 2.75)]
            hu, hy = w - 0.42, 2.95
        else:
            glazed, cols, rows = (0.4, w - 0.4, 1.6, y1 - 0.45), 2, 5
            panels = [(0.4, w - 0.4, 0.42, 1.38)]
            hu, hy = w - 0.28, 3.4
        L.body(b, [glazed], self.BODY)
        u0, u1, ga, gb = glazed
        L.glass(g, glazed)
        bar = 0.1
        for k in range(1, cols):                                 # glazing bars, recessed from both faces
            u = u0 + (u1 - u0) * k / cols
            L.span(b, u - bar / 2, u + bar / 2, ga, gb, L.mid - 0.07, L.mid + 0.07, self.BODY)
        for k in range(1, rows):
            y = ga + (gb - ga) * k / rows
            L.span(b, u0, u1, y - bar / 2, y + bar / 2, L.mid - 0.06, L.mid + 0.06, self.BODY)
        for n0, n1 in L.faces(0.04):                             # a bead round the glazing and the panels
            L.outline(b, u0 - 0.08, u1 + 0.08, ga - 0.08, gb + 0.08, 0.08, n0, n1, self.BEAD)
            for (pu0, pu1, pa, pb) in panels:
                L.outline(b, pu0, pu1, pa, pb, 0.1, n0, n1, self.BEAD)
        for (zf, s) in ((L.out, 1), (L.inn, -1)):                # brass knob on a rose, a keyhole plate
            L.cyl(b, hu, hy, zf + s * 0.015, 0.11, 0.03, self.BRASS, segments=10)
            L.cyl(b, hu, hy, zf + s * 0.06, 0.035, 0.06, self.BRASS, segments=8)
            L.cyl(b, hu, hy, zf + s * 0.12, 0.09, 0.06, self.BRASS, segments=10)
            L.span(b, hu - 0.05, hu + 0.05, hy - 0.42, hy - 0.22, zf, zf + s * 0.02, self.BRASS)
        L.knuckles(b, (0.95, y1 - 0.6), 0.07 if L.back else 0.06, self.BRASS)


SETS = (FireEscape(), GardenGate(), FrontPorch(), LogCabin(), PortholeHatch(), PanedGlass())


def build_front(style, mat):
    name = f"CatCafe_Door_{style.NAME}_Front"
    root = RB()
    root.span((-3.5, 0.0, -1.0), (3.5, 0.06, 0.0), style.SILL)                # the threshold under both leaves
    objs = [root.finalize(name, mat)]
    for side, sx, hx in (("L", -1, -F_HINGE), ("R", 1, F_HINGE)):
        b, g = RB(), RB()
        style.leaf(Leaf(sx, F_W, F_Y0, F_Y1, F_T, F_T, False), b, g)
        objs.append(_place(b.finalize(f"{name}_Leaf{side}", mat), (hx, 0.0, F_ZIN)))
        if _used(g):
            objs.append(_place(g.finalize(f"{name}_Leaf{side}_Glass", mat), (hx, 0.0, F_ZIN)))
    return objs


def build_back(style, mat):
    name = f"CatCafe_Door_{style.NAME}_Back"
    root = RB()
    root.span((-2.99, 0.0, -0.48), (2.99, 0.08, 0.5), style.SILL)              # the threshold, as the cafe's own
    for s in (-1, 1):                                                          # the inside architrave over the
        root.span((min(s * 2.98, s * 3.45), 0.0, 0.5), (max(s * 2.98, s * 3.45), 7.95, 0.82), style.TRIM)   # wainscot
    root.span((-2.98, 7.51, 0.5), (2.98, 7.95, 0.82), style.TRIM)
    b, g, sign, glow = RB(), RB(), RB(), RB()
    style.leaf(Leaf(1, B_W, B_Y0, B_Y1, B_T, 0.0, True), b, g)
    doors._sign(sign, glow, z=style.SIGN_Z)
    objs = [root.finalize(name, mat), _place(b.finalize(name + "_Leaf", mat), B_HINGE)]
    if _used(g):
        objs.append(_place(g.finalize(name + "_Leaf_Glass", mat), B_HINGE))
    objs += [_place(sign.finalize(name + "_Sign", mat), B_HINGE), _place(glow.finalize(name + "_Sign_Bulb", mat), B_HINGE)]
    return objs


def back_cat_flap_attachment(name):
    """CatFlap on a back leaf: the foot of its yard face in the middle, facing the yard (-Z here, as on the cafe's)."""
    return ("_Leaf", "CatFlap", Matrix.Translation(Vector(RB.p(0.0, B_Y0, B_HINGE[2]))))


# ------------------------------------------------------------------------------------------------ cat flaps --
def _rect_frame(f, swatch, t, d_yard, d_cafe, cafe_swatch=None):
    """A frame t wide round the hole on the yard face (d_yard proud) and the cafe face (d_cafe), lined through."""
    x0, x1, y0, y1 = -FX - t, FX + t, FY0 - 0.15, FY1 + t
    doors._frame(f, x0, x1, y0, y1, t, -d_yard, 0.0, swatch)
    doors._frame(f, x0, x1, y0, y1, t, FT, FT + d_cafe, cafe_swatch or swatch)
    doors._frame(f, -FX, FX, FY0, FY1, 0.02, 0.0, FT, cafe_swatch or swatch)     # the lining through the leaf


def _round_frame(f, ring, face, lining):
    """A round flap's rings: `ring` is [(r_out, r_in, z0, z1, swatch)] on the yard side; the cafe face gets a plain
    ring and the hole a lining, both in `lining`."""
    for r_out, r_in, z0, z1, sw in ring:
        _ring(f, 0.0, RC, z0, z1, r_out, r_in, sw)
    _ring(f, 0.0, RC, 0.0, FT, 1.3, 0.95, lining)
    _ring(f, 0.0, RC, FT, FT + face, 1.35, 0.95, lining)


def _panel(p, swatch, rod=2 * FX - 0.04):
    """The swinging panel in its own frame: hinge at the origin, hanging down, the yard toward -Z."""
    h = FY1 - FY0
    p.span((-FX + 0.03, -h + 0.03, -0.03), (FX - 0.03, -0.02, 0.03), swatch)
    p.cyl((0, -0.02, 0), 0.06, rod, "metal", axis="X", segments=8)


def _round_panel(p, swatch):
    p.cyl((0, -0.9, 0), 0.9, 0.06, swatch, axis="Z", segments=16)
    p.cyl((0, -0.02, 0), 0.05, 0.6, "metal", axis="X", segments=8)


def _paw(p, swatch, z0=-0.05, z1=-0.03):
    """The default flap's paw print on the yard face of a panel."""
    h = FY1 - FY0
    p.span((-0.27, -h + 0.42, z0), (0.27, -h + 0.84, z1), swatch)
    for (x, y) in ((-0.36, -h + 1.0), (-0.12, -h + 1.14), (0.12, -h + 1.14), (0.36, -h + 1.0)):
        p.span((x - 0.09, y - 0.09, z0), (x + 0.09, y + 0.09, z1), swatch)


def build_flap_plain(mat):
    name = "CatCafe_CatFlap_Plain"
    f, p = RB(), RB()
    _rect_frame(f, doors.TRIM, 0.18, 0.08, 0.08)
    f.span((-FX - 0.3, FY1 + 0.18, -0.24), (FX + 0.3, FY1 + 0.36, 0.0), doors.TRIM)          # the hood
    _panel(p, "fur_charcoal")
    _paw(p, doors.TRIM)
    return [f.finalize(name, mat), p.finalize(name + "_Flap", mat, location=FLAP_HINGE)]


def build_flap_neon_paw(mat):
    """Alley (Rare): a dark flap with a neon paw outline that glows at night."""
    name = "CatCafe_CatFlap_NeonPaw"
    f, p, glow = RB(), RB(), RB()
    _rect_frame(f, "fur_black", 0.22, 0.1, 0.07)
    f.span((-FX - 0.34, FY1 + 0.22, -0.2), (FX + 0.34, FY1 + 0.36, -0.01), "fur_ash")          # a dark hood
    _panel(p, "night_sky")
    h = FY1 - FY0
    _ring(glow, 0.0, -h + 0.75, -0.06, -0.03, 0.34, 0.27, "neon_pink", segs=8, a0=22.5)        # the pad
    for (x, y) in ((-0.37, -h + 1.17), (-0.13, -h + 1.36), (0.13, -h + 1.36), (0.37, -h + 1.17)):
        _ring(glow, x, y, -0.06, -0.03, 0.12, 0.075, "neon_pink", segs=6, a0=0.0)            # the toes
    return [f.finalize(name, mat), p.finalize(name + "_Flap", mat, location=FLAP_HINGE),
            glow.finalize(name + "_Flap_Bulb", mat, location=FLAP_HINGE)]


def build_flap_birdhouse(mat):
    """Park (Rare): the flap framed like a birdhouse, a little roof over it, a perch, a round door painted on."""
    name = "CatCafe_CatFlap_Birdhouse"
    f, p = RB(), RB()
    _rect_frame(f, "pastel_sky", 0.22, 0.1, 0.06, cafe_swatch="caramel_wood")
    peak, slope, half = FY1 + 0.49, math.tan(math.radians(32)), 1.36
    for s in (-1, 1):                                            # two roof boards meeting at the peak
        _bar(f, (0.0, peak), (s * half, peak - half * slope), 0.14, -0.3, -0.01, "terracotta")
    f.span((-0.08, peak - 0.06, -0.31), (0.08, peak + 0.07, -0.01), "terracotta")                # the ridge cap
    f.cyl((0.0, FY0 - 0.06, -0.21), 0.05, 0.22, "dark_wood", axis="Z", segments=8)           # the perch
    _panel(p, "pastel_butter")
    h = FY1 - FY0
    p.cyl((0.0, -h + 1.2, -0.035), 0.3, 0.01, "fur_black", axis="Z", segments=12)           # the painted door
    p.span((-0.38, -h + 0.78, -0.05), (0.38, -h + 0.84, -0.03), "caramel_wood")              # a painted sill
    return [f.finalize(name, mat), p.finalize(name + "_Flap", mat, location=FLAP_HINGE)]


def build_flap_mail_slot(mat):
    """Neighbourhood (Common): a brass flap like a letterbox, a lip over it with the slot."""
    name = "CatCafe_CatFlap_MailSlot"
    f, p = RB(), RB()
    _rect_frame(f, "brass", 0.2, 0.06, 0.05)
    f.span((-FX - 0.28, FY1 + 0.2, -0.16), (FX + 0.28, FY1 + 0.44, -0.01), "brass")           # the lip
    f.span((-0.75, FY1 + 0.29, -0.17), (0.75, FY1 + 0.35, -0.16), "fur_black")                # its slot
    for x in (-FX - 0.1, FX + 0.1):
        for y in (FY0 - 0.05, FY1 + 0.1):
            f.span((x - 0.04, y - 0.04, -0.08), (x + 0.04, y + 0.04, -0.06), "bronze")         # screws
    _panel(p, "brass")
    h = FY1 - FY0
    for y in (-h + 0.5, -h + 1.0, -h + 1.5):
        p.span((-0.7, y - 0.04, -0.06), (0.7, y + 0.04, -0.03), "bronze")                    # ribs
    p.cyl((0.0, -h + 0.25, -0.07), 0.07, 0.08, "bronze", axis="Z", segments=8)               # a pull
    return [f.finalize(name, mat), p.finalize(name + "_Flap", mat, location=FLAP_HINGE)]


def build_flap_tree_stump(mat):
    """Woods (Rare): the flap set in a carved stump ring, bark round the cut face, moss on top."""
    name = "CatCafe_CatFlap_TreeStump"
    f, p = RB(), RB()
    _round_frame(f, [(1.35, 1.12, -0.2, 0.0, "fur_bramble"), (1.12, 0.95, -0.14, 0.0, "treat_tan"),
                     (1.075, 1.025, -0.15, -0.14, "fur_acorn")], 0.06, "caramel_wood")
    for k, (a, sz) in enumerate(((58, 0.26), (75, 0.3), (92, 0.34), (108, 0.28), (124, 0.24), (140, 0.18),
                                 (30, 0.16))):
        rad = math.radians(a)
        rr = 1.235 + (0.02 if k % 2 else 0.0)
        f.box((rr * math.cos(rad), RC + rr * math.sin(rad), -0.23), (0.14, sz, 0.06),
              ("leaf_green", "leaf_dark")[k % 2], rot=rot_z(a))
        f.box(((1.35 + 0.04) * math.cos(rad), RC + (1.35 + 0.04) * math.sin(rad), -0.12 - 0.005 * (k % 2)),
              (0.08, sz * 0.8, 0.18), ("leaf_green", "leaf_dark")[k % 2], rot=rot_z(a))
    _round_panel(p, "caramel_wood")
    for r_out, r_in in ((0.62, 0.56), (0.34, 0.28)):
        _ring(p, 0.0, -0.9, -0.04, -0.03, r_out, r_in, "fur_acorn", segs=12)
    p.span((-0.06, -0.96, -0.04), (0.06, -0.84, -0.03), "fur_acorn")
    return [f.finalize(name, mat), p.finalize(name + "_Flap", mat, location=FLAP_HINGE)]


def build_flap_pipe_ring(mat):
    """Sewer (Common): the flap in a bolted pipe ring on a flange."""
    name = "CatCafe_CatFlap_PipeRing"
    f, p = RB(), RB()
    _round_frame(f, [(1.35, 0.95, -0.08, 0.0, "concrete_dark"), (1.1, 0.95, -0.3, -0.08, "metal"),
                     (1.16, 1.1, -0.24, -0.16, "rust")], 0.06, "concrete_dark")
    for k in range(8):
        a = math.radians(22.5 + 45 * k)
        x, y = 1.23 * math.cos(a), RC + 1.23 * math.sin(a)
        f.span((x - 0.06, y - 0.06, -0.13), (x + 0.06, y + 0.06, -0.08), "metal")
    _round_panel(p, "fur_charcoal")
    p.span((-0.5, -0.32, -0.05), (0.5, -0.2, -0.03), "metal")                                 # a strap across
    for x in (-0.42, 0.42):
        p.span((x - 0.04, -0.3, -0.07), (x + 0.04, -0.22, -0.05), "metal")
    return [f.finalize(name, mat), p.finalize(name + "_Flap", mat, location=FLAP_HINGE)]


def build_flap_bell(mat):
    """Classic (Rare): a pastel flap with a tiny gold bell hung over it."""
    name = "CatCafe_CatFlap_Bell"
    f, p, bell = RB(), RB(), RB()
    _rect_frame(f, "pastel_lilac", 0.2, 0.08, 0.06)
    top = FY1 + 0.2
    f.span((-0.04, top, -0.1), (0.04, top + 0.36, -0.02), "brass")                           # the bracket's post
    f.span((-0.04, top + 0.3, -0.34), (0.04, top + 0.36, -0.1), "brass")                     # and arm
    hang = (0.0, top + 0.3, -0.27)
    bell.cyl((0.0, -0.13, 0.0), 0.15, 0.2, "fur_golden", segments=10, r2=0.09)              # the bell, open below
    bell.cyl((0.0, -0.24, 0.0), 0.17, 0.03, "fur_golden", segments=10)                       # its lip
    bell.ball((0.0, -0.28, 0.0), 0.045, "brass")                                              # the clapper
    bell.span((-0.025, -0.03, -0.025), (0.025, 0.0, 0.025), "brass")                          # the loop
    _panel(p, "pastel_sky")
    _paw(p, "blush")
    return [f.finalize(name, mat), p.finalize(name + "_Flap", mat, location=FLAP_HINGE),
            bell.finalize(name + "_Bell", mat, location=hang)]


NEST = {"_LeafL_Glass": "_LeafL", "_LeafR_Glass": "_LeafR", "_Leaf_Glass": "_Leaf", "_Sign": "_Leaf",
        "_Sign_Bulb": "_Leaf", "_Flap_Bulb": "_Flap"}
FLAPS = {"Plain": build_flap_plain, "NeonPaw": build_flap_neon_paw, "Birdhouse": build_flap_birdhouse,
         "MailSlot": build_flap_mail_slot, "TreeStump": build_flap_tree_stump, "PipeRing": build_flap_pipe_ring,
         "Bell": build_flap_bell}

ASSETS = {}
for _s in SETS:
    ASSETS[f"CatCafe_Door_{_s.NAME}_Front"] = (lambda m, s=_s: build_front(s, m), 4000)
    ASSETS[f"CatCafe_Door_{_s.NAME}_Back"] = (lambda m, s=_s: build_back(s, m), 4000)
for _n, _fn in FLAPS.items():
    ASSETS[f"CatCafe_CatFlap_{_n}"] = (_fn, 1600)
