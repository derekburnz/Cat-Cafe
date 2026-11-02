"""Backdrop rings for the five wild areas (hometown-cannon.md section 6a: "Each area sits on its own ground with a
backdrop ring outside its walls (hills, trees, house roofs or brick vaults by theme), so no player ever sees the empty
space between places"; Derek 2026-10-28 17:10: "make it so that the sides of the map are blended in with terrain more
smoothly and not just a patch of grass ground stretching out").

One model per area, in set space like the area's kit set and its camp set (x across, -Z toward the camp and the town,
the area's centre on the ground at the origin): place it where the camp set goes, at y 0,
CFrame.new(spec.center.x, 0, spec.center.z) * CFrame.Angles(0, math.rad(camp.turn), 0).

  CatCafe_<Area>_Backdrop           the pieces: buildings, houses, trees, chimneys and the rest, by theme.
  CatCafe_<Area>_Backdrop_Ground    the ground carried on from WorldBuilder's plate under the area and its camp
                                    (CAMP_GROUND_MARGIN 80 past the walls) out REACH more, top at -0.1 like the plate,
                                    in the plate's grass (the Alleyway's in asphalt over the plate too).
  CatCafe_<Area>_Backdrop_Hills     the near ring of rolling hills, sunk into the ground (backdrop.Hill).
  CatCafe_<Area>_Backdrop_HillsFar  the far ring, bigger and paler (the Woods': grey mountains, Rock).
  CatCafe_<Area>_Backdrop_Snow      the Woods' snow caps on the tallest mountains.
  CatCafe_<Area>_Backdrop_Road      the Alleyway's asphalt over the plate, the Neighbourhood's road, the Sewer's yard.
  CatCafe_<Area>_Backdrop_Flowers   flower tufts and beds.
  CatCafe_<Area>_Backdrop_Bulbs     windows, lit at night like every _Bulbs.

Themes: the Alleyway in city blocks, the Park in hills and parkland with a lake, the Neighbourhood in house rows along
a road, the Woods in deep forest under mountains, the Sewer in brick works with chimneys. Nothing collides, casts a
shadow or takes a raycast (rbx_export BACKDROP), and every piece keeps KEEP clear of the area's walls and its camp set.
Built against Config.World's v4 (F84) sizes; each F85 long rectangle gets its own ring with its numbers in AREAS
(CatCafe_Park_BackdropF85 round the 120 x 310 Park, CatCafe_Neighbourhood_BackdropF85 round the 180 x 430 Neighbourhood,
CatCafe_Woods_BackdropF85 round the 160 x 490 Woods).
"""

import math

from mathutils import Vector

import rbx_export
from alleyway import flower_clump
from backdrop import GRASS_RGB, Hill, _hash, _ring
from common import RB
from plot import rot_y

CAMP_D = 30.0          # Config.World.CampDepth: the camp lies across the gate side, this deep
CAMP_SET = 2.0         # the camp sets' ground runs this far past the camp's back line (CatCafe_Camp_<Area>)
MARGIN = 80.0          # WorldBuilder's CAMP_GROUND_MARGIN: its plate reaches this far past the walls and the camp
REACH = 260.0          # this backdrop's ground carries on this far past the plate
TOP = -0.1             # the plate's top (1 thick, centred at -0.6)
KEEP = 3.0             # nothing stands nearer than this to the walls' outer faces or the camp set

# area: (half its width across, half its length from the gate line to the far wall, theme), Config.World v4 (F84)
AREAS = {
    "Alleyway": (45.0, 125.5, "city"),        # the two lanes and the block between, 90 x 251
    "Park": (80.0, 60.0, "park"),             # ParkWidth 160, ParkDepth 120
    "Neighbourhood": (140.0, 140.0, "houses"),
    "Woods": (120.0, 120.0, "forest"),        # turned a quarter: its depth runs across
    "Sewer": (90.0, 90.0, "works"),
    "ParkF85": (60.0, 155.0, "park"),         # F85's long Park, 120 x 310 (parkf85.py)
    "NeighbourhoodF85": (90.0, 215.0, "houses"),   # F85's long Neighbourhood, 180 x 430 (neighbourhoodf85.py)
    "WoodsF85": (80.0, 245.0, "forest"),      # F85's long Woods, 160 x 490 (woodsf85.py)
}
NAMES = {"ParkF85": "CatCafe_Park_BackdropF85", "NeighbourhoodF85": "CatCafe_Neighbourhood_BackdropF85",
         "WoodsF85": "CatCafe_Woods_BackdropF85"}   # an F85 ring keeps its area's name, so WorldBuilder can pick it

ASPHALT_RGB = (70, 70, 75)                     # WorldBuilder's ASPHALT
PALE_RGB = (150, 186, 128)                     # the far hills, as in the hometown's
WOODS_RGB = (86, 120, 70)                      # WorldBuilder's Woods floor
MOUNTAIN_RGB = (118, 140, 150)
FOREST_RGB = (62, 110, 70)


def _look(name, rgb, material):
    rbx_export.LOOKS[name] = ([round(v / 255, 4) for v in rgb], material)


# ---------------------------------------------------------------------------------------------------- frame --
class Frame:
    """An area's footprint in set space: the walls' outer faces at |x| ex and z ez1, the camp set's back at ez0."""

    def __init__(self, A, H):
        self.A, self.H = A, H
        self.ex = A + 1.0
        self.ez0 = -(H + CAMP_D + CAMP_SET)
        self.ez1 = H + 1.0
        self.cz = (self.ez0 + self.ez1) / 2
        self.hz = (self.ez1 - self.ez0) / 2
        self.px = A + MARGIN                            # WorldBuilder's plate
        self.pz0 = -(H + CAMP_D) - MARGIN
        self.pz1 = H + MARGIN
        self.hills = []

    def out(self, x, z):
        """How far (x, z) is outside the footprint (negative inside)."""
        return max(abs(x) - self.ex, self.ez0 - z, z - self.ez1)

    def gy(self, x, z):
        return max([TOP] + [h.height(x, z) for h in self.hills])

    def around(self, d, step, seed, wobble=0.0, shift=0.0, corners=True):
        """Points every `step` round the footprint at distance d (a rounded rectangle), each (x, z, nx, nz) with its
        outward normal; `wobble` moves each in or out by up to that, `shift` along by up to that."""
        ex, ez0, ez1 = self.ex, self.ez0, self.ez1
        legs = [((-ex - d, ez0), (-ex - d, ez1), (-1, 0)), ((-ex, ez1 + d), (ex, ez1 + d), (0, 1)),
                ((ex + d, ez1), (ex + d, ez0), (1, 0)), ((ex, ez0 - d), (-ex, ez0 - d), (0, -1))]
        corner_at = [(-ex, ez1, math.pi), (ex, ez1, math.pi / 2), (ex, ez0, 0.0), (-ex, ez0, -math.pi / 2)]
        pts = []
        for k, ((x0, z0), (x1, z1), (nx, nz)) in enumerate(legs):
            L = math.hypot(x1 - x0, z1 - z0)
            n = max(1, round(L / step))
            for i in range(n):
                t = (i + 0.5) / n
                pts.append((x0 + (x1 - x0) * t, z0 + (z1 - z0) * t, nx, nz))
            if corners:
                cx, cz, a0 = corner_at[k]
                m = max(1, round(d * math.pi / 2 / step))
                for i in range(m):
                    a = a0 - (i + 0.5) / m * math.pi / 2
                    pts.append((cx + d * math.cos(a), cz + d * math.sin(a), math.cos(a), math.sin(a)))
        out = []
        for i, (x, z, nx, nz) in enumerate(pts):
            w = (_hash(seed, i, 1) - 0.5) * 2 * wobble
            s = (_hash(i, seed, 2) - 0.5) * 2 * shift
            out.append((x + nx * w - nz * s, z + nz * w + nx * s, nx, nz))
        return out


def ring(f, d, step, sizes, seed, corner=None):
    """A ring of hills round the footprint, d past it, every hill's foot KEEP + 4 clear of it (shrunk or left out)."""
    rx, rz = f.ex + d, f.hz + d
    hills = []
    for h in _ring(rx, rz, corner if corner is not None else min(0.8 * d, rx, rz), step, sizes, seed):
        h.z += f.cz
        foot = math.sqrt(1 - (Hill.SINK / (1 + Hill.SINK)) ** 2)
        for _ in range(8):
            if _foot_clear(f, h, foot):
                hills.append(h)
                break
            h = Hill(h.x, h.z, h.a * foot * 0.85, h.c * foot * 0.85, h.rise * 0.85, h.turn)
    return hills


def _foot_in(h, box):
    """Whether any of a hill's foot lies in box (x0, x1, z0, z1)."""
    foot = math.sqrt(1 - (Hill.SINK / (1 + Hill.SINK)) ** 2)
    ct, st = math.cos(h.turn), math.sin(h.turn)
    for k in range(32):
        a = 2 * math.pi * k / 32
        for r in (0.0, 0.5, 1.0):
            u, v = h.a * foot * r * math.cos(a), h.c * foot * r * math.sin(a)
            x, z = h.x + u * ct + v * st, h.z - u * st + v * ct
            if box[0] <= x <= box[1] and box[2] <= z <= box[3]:
                return True
    return False


def _foot_clear(f, h, foot):
    ct, st = math.cos(h.turn), math.sin(h.turn)
    for k in range(32):
        a = 2 * math.pi * k / 32
        u, v = h.a * foot * math.cos(a), h.c * foot * math.sin(a)
        x, z = h.x + u * ct + v * st, h.z - u * st + v * ct
        if f.out(x, z) < KEEP + 4:
            return False
    return True


def ground(f, rb, swatch):
    """Four slabs round WorldBuilder's plate, out REACH past it, top at TOP."""
    gx, gz0, gz1 = f.px + REACH, f.pz0 - REACH, f.pz1 + REACH
    for (x0, x1, z0, z1) in ((-gx, gx, f.pz1, gz1), (-gx, gx, gz0, f.pz0), (f.px, gx, f.pz0, f.pz1),
                             (-gx, -f.px, f.pz0, f.pz1)):
        rb.span((x0, TOP - 1.0, z0), (x1, TOP, z1), swatch)


# ------------------------------------------------------------------------------------------------- turning --
class Turned:
    """A local frame at (x, y, z) turned `turn` degrees about Y (CFrame.Angles), front -Z: pieces built facing -Z
    land facing the area when turn = atan2(nx, nz) for the outward normal (nx, nz)."""

    def __init__(self, x, z, turn, y=0.0):
        self.o = Vector((x, y, z))
        self.R = rot_y(turn)

    @staticmethod
    def facing(x, z, nx, nz, y=0.0):
        return Turned(x, z, math.degrees(math.atan2(nx, nz)), y)

    def p(self, c):
        return tuple(self.R @ Vector(c) + self.o)

    def span(self, rb, lo, hi, swatch):
        c = tuple((a + b) / 2 for a, b in zip(lo, hi))
        rb.box(self.p(c), tuple(abs(b - a) for a, b in zip(lo, hi)), swatch, rot=self.R)

    def wedge(self, rb, c, s, swatch, rot):
        rb.wedge(self.p(c), s, swatch, rot=self.R @ rot)

    def cyl(self, rb, c, r, h, swatch, segments=12):
        rb.cyl(self.p(c), r, h, swatch, segments=segments)

    def ball(self, rb, c, r, swatch, sy=1.0):
        rb.ball(self.p(c), r, swatch, scale=(1.0, sy, 1.0))


# ---------------------------------------------------------------------------------------------- vegetation --
LEAVES = ("leaf_green", "leaf_dark", "paw_park")


def tree(rb, f, x, z, s=1.0, leaf="leaf_green"):
    """The hometown backdrop's round tree, standing on this backdrop's ground."""
    y = f.gy(x, z) - 0.3 * s
    rb.cyl((x, y + 2.2 * s, z), 0.5 * s, 4.4 * s, "fur_brown", segments=8)
    rb.ball((x, y + 6.0 * s, z), 3.0 * s, leaf)
    rb.ball((x + 1.9 * s, y + 4.9 * s, z - 0.5 * s), 1.9 * s, leaf)
    rb.ball((x - 1.7 * s, y + 5.3 * s, z + 0.6 * s), 1.8 * s, leaf)


def fir(rb, f, x, z, s=1.0, leaf="leaf_dark"):
    """A fir: a trunk under three stacked, squashed tiers."""
    y = f.gy(x, z) - 0.3 * s
    rb.cyl((x, y + 1.6 * s, z), 0.45 * s, 3.2 * s, "fur_brown", segments=8)
    for r, h in ((2.8, 3.9), (1.9, 6.3), (1.0, 8.2)):
        rb.ball((x, y + h * s, z), r * s, leaf, scale=(1.0, 0.85, 1.0))


def far_tree(rb, f, x, z, s, leaf):
    y = f.gy(x, z) - 0.3 * s
    rb.cyl((x, y + 1.8 * s, z), 0.5 * s, 3.6 * s, "fur_brown", segments=6)
    rb.ball((x, y + 5.2 * s, z), 2.9 * s, leaf, scale=(1.0, 1.1, 1.0))


def bush(rb, f, x, z, s=1.0, leaf="leaf_dark"):
    y = f.gy(x, z)
    rb.ball((x, y + 0.6 * s, z), 1.6 * s, leaf, scale=(1.3, 0.8, 1.0))
    rb.ball((x + 1.6 * s, y + 0.4 * s, z + 0.5 * s), 1.0 * s, leaf, scale=(1.2, 0.8, 1.0))


def tuft(rb, flowers, x, z, spread):
    rb.cyl((x, TOP + 0.04, z), spread + 0.6, 0.08, "leaf_dark", segments=10)
    flower_clump(flowers, x, TOP + 0.08, z, n=3, spread=spread)


def on_hills(rb, f, hills, per, seed, scale, plant=tree, leaves=LEAVES, pad=8.0):
    """Trees on the hills' upper slopes, `per` a hill."""
    for i, h in enumerate(hills):
        for k in range(per):
            a = 2 * math.pi * _hash(seed, i, k)
            d = 0.12 + 0.45 * _hash(k, i, seed)
            u, v = math.cos(a) * h.a * d, math.sin(a) * h.c * d
            x = h.x + u * math.cos(h.turn) + v * math.sin(h.turn)
            z = h.z - u * math.sin(h.turn) + v * math.cos(h.turn)
            if f.out(x, z) < KEEP + pad:
                continue
            plant(rb, f, x, z, scale * (0.8 + 0.5 * _hash(i, k, seed)), leaves[int(_hash(k, seed, i) * 97) % len(leaves)])


def belt(rb, f, d, step, seed, plant=tree, scale=1.0, leaves=LEAVES, wobble=3.0):
    """A belt of trees round the footprint, d past it."""
    for i, (x, z, nx, nz) in enumerate(f.around(d, step, seed, wobble=wobble, shift=step * 0.3)):
        if f.out(x, z) < KEEP + 3:
            continue
        plant(rb, f, x, z, scale * (0.85 + 0.35 * _hash(i, seed, 5)), leaves[int(_hash(seed, i, 6) * 97) % len(leaves)])


# ------------------------------------------------------------------------------------------------ buildings --
WALLS = ("pastel_butter", "blush", "mint", "pastel_sky", "pastel_lilac", "cream")
ROOFS = ("terracotta", "bowl_red", "fur_slate", "sign_teal", "brick", "galaxy_blue")
CITY = ("brick", "fur_latte", "concrete", "pastel_butter", "terracotta", "fur_sand", "blush", "fur_mist")


def house(t, rb, lit, w, d, h, wall, roof, k):
    """A house facing -Z in its frame, its front at z -d/2: walls, a gable roof of two wedges, a door, two windows
    (lit) and on every other house a chimney."""
    t.span(rb, (-w / 2, TOP, -d / 2), (w / 2, h, d / 2), wall)
    rise = 0.45 * w
    for s in (-1, 1):
        t.wedge(rb, (s * (w / 4 + 0.15), h + rise / 2, 0), (d + 1.2, rise, w / 2 + 0.3), roof, rot_y(-s * 90))
    if k % 2 == 0:
        t.span(rb, (w * 0.22, h + rise * 0.3, d * 0.1), (w * 0.22 + 1.1, h + rise * 0.95, d * 0.1 + 1.1), "brick")
    t.span(rb, (-0.8, TOP, -d / 2 - 0.12), (0.8, 2.8, -d / 2), ROOFS[(k + 2) % len(ROOFS)])
    for s in (-1, 1):
        wx = s * w * 0.3
        t.span(lit, (wx - 0.8, h * 0.45, -d / 2 - 0.12), (wx + 0.8, h * 0.45 + 1.5, -d / 2), "pastel_sky")


def block(t, rb, lit, w, d, h, wall, k, grid=True, tank=False, bands=True, shop=True):
    """A city building facing -Z in its frame, its front at z -d/2: body, cornice, a glass face behind floor bands
    (`bands`) and piers (`grid`) so it reads as rows of windows, lit at night, a shop front and roof things. The
    overlays run back into the body, each a little prouder than the one under it, so no faces meet flat."""
    fz = -d / 2
    t.span(rb, (-w / 2, TOP - 0.02 * (k % 5), fz), (w / 2, h, d / 2), wall)   # neighbours at the corners overlap
    trim = "cream" if wall in ("brick", "terracotta", "fur_latte") else "concrete_dark"
    t.span(rb, (-w / 2 - 0.3, h, fz - 0.3), (w / 2 + 0.3, h + 0.7, d / 2 + 0.3), trim)
    t.span(lit, (-w / 2 + 1.0, 4.2, fz - 0.1), (w / 2 - 1.0, h - 1.4, fz + 0.05), "pastel_butter")   # the glass
    if bands:
        floors = max(1, int((h - 5.6) / 4.5))
        pitch = (h - 5.6) / floors
        for i in range(1, floors + 1):                                                              # floor bands
            y = 4.2 + i * pitch
            t.span(rb, (-w / 2 + 0.9, y - 1.1, fz - 0.2), (w / 2 - 0.9, y + 0.1, fz + 0.1), wall)
    if grid:
        n = max(2, round((w - 2) / 3.4))
        for j in range(1, n):
            x = -w / 2 + 1.0 + j * (w - 2) / n
            t.span(rb, (x - 0.35, 4.1, fz - 0.24), (x + 0.35, h - 1.3, fz + 0.15), wall)
    if shop:                                                       # the shop front: an awning over a lit window
        t.span(lit, (-w / 2 + 1.5, 0.6, fz - 0.1), (w / 2 - 1.5, 3.0, fz + 0.05), "lamp_warm")
        t.wedge(rb, (0, 3.5, fz - 0.9), (w - 2.4, 0.9, 1.8), ROOFS[k % len(ROOFS)], rot_y(0))
    if tank:                                                                                      # a water tank
        tx, tz = w * 0.18, d * 0.12
        t.span(rb, (tx - 1.5, h + 0.7, tz - 1.5), (tx + 1.5, h + 3.4, tz + 1.5), "dark_wood")       # its stand
        t.cyl(rb, (tx, h + 5.2, tz), 2.0, 3.6, "caramel_wood", segments=12)
        t.ball(rb, (tx, h + 7.0, tz), 2.0, "fur_charcoal", sy=0.45)
    else:
        t.span(rb, (-w * 0.25 - 1.2, h + 0.7, -0.8), (-w * 0.25 + 1.2, h + 2.2, 0.8), "metal")    # an air unit


# ---------------------------------------------------------------------------------------------------- themes --
def _on_bed(f, x, z, r):
    """Whether a disc of radius r at (x, z) meets one of theme_park's flower beds behind the camp."""
    bz = f.ez0 - 12.0
    return any(abs(x - bx) < 5.0 + r and abs(z - bz) < 2.0 + r for bx in (-36.0, -18.0, 0.0, 18.0, 36.0))


def theme_park(f, P):
    lake = (0.0, f.ez1 + 26.0, 30.0, 11.0)                        # x, z, half along x, half along z
    lx, lz, la, lc = lake
    box = (lx - la - 12.0, lx + la + 12.0, lz - lc - 6.0, lz + lc + 16.0)
    near = [h for h in ring(f, 52.0, 40.0, (38.0, 26.0, 8.0, 16.0), 11) if not _foot_in(h, box)]
    far = ring(f, 175.0, 64.0, (60.0, 44.0, 22.0, 40.0), 12)
    f.hills = near + far
    for h in near:
        h.add(P["hills"], "leaf_green")
    for h in far:
        h.add(P["far"], "leaf_green")
    rb, flowers, lit = P["rb"], P["flowers"], P["lit"]
    on_hills(rb, f, near, 3, 13, 1.7)
    on_hills(rb, f, far, 2, 14, 2.6, plant=far_tree)
    # parkland between the walls and the hills: trees, bushes and flower tufts, clear of the lake
    for i, (x, z, nx, nz) in enumerate(f.around(16.0, 15.0, 15, wobble=9.0, shift=5.0)):
        if f.out(x, z) < KEEP + 2 or (abs(x - lake[0]) < lake[2] + 6 and abs(z - lake[1]) < lake[3] + 6):
            continue
        r = _hash(i, 16)
        if r >= 0.8 and any(_on_bed(f, tx, tz, tr) for tx, tz, tr in ((x, z, 1.3), (x + 1.9, z + 0.8, 1.2))):
            continue                                                       # a tuft would lie on a flower bed
        if r < 0.55:
            tree(rb, f, x, z, 1.1 + 0.5 * r, LEAVES[i % 3] if _hash(i, 17) < 0.85 else "blush")
        elif r < 0.8:
            bush(rb, f, x, z, 1.0 + r, LEAVES[(i + 1) % 3])
        else:
            tuft(rb, flowers, x, z, 0.7)
            tuft(rb, flowers, x + 1.9, z + 0.8, 0.6)
    # the lake past the far wall, with the near hills opened round it: sandy rim, water, a jetty, a little boathouse
    # and two ducks
    rb.ball((lx, TOP, lz), 1.0, "fur_sand", scale=(la + 3.0, 0.3, lc + 3.0))
    rb.ball((lx, TOP, lz), 1.0, "puddle", scale=(la, 0.4, lc))
    jx = lx + 12.0
    rb.span((jx - 1.4, 0.35, lz - lc + 2.0), (jx + 1.4, 0.65, lz - lc - 3.5), "caramel_wood")
    for pz in (lz - lc - 3.0, lz - lc + 1.5):
        for px in (jx - 1.2, jx + 1.2):
            rb.span((px - 0.2, TOP, pz - 0.2), (px + 0.2, 0.35, pz + 0.2), "dark_wood")
    bx, bz = lx - 22.0, lz + lc + 4.0
    t = Turned(bx, bz, 0.0)
    house(t, rb, lit, 8.0, 6.0, 4.5, "offwhite", "sign_teal", 3)
    for k, (dx, dz) in enumerate(((-6.0, -2.0), (5.0, 3.0))):
        x, z = lx + dx, lz + dz
        rb.ball((x, 0.55, z), 0.7, "offwhite", scale=(1.3, 0.8, 1.0))
        rb.ball((x + 0.75, 1.25, z), 0.4, "offwhite")
        rb.span((x + 1.05, 1.15, z - 0.12), (x + 1.45, 1.35, z + 0.12), "fur_orange")
    # a white gazebo on the left, a flower garden behind the camp
    gx, gz = -f.ex - 26.0, f.cz + 20.0
    rb.cyl((gx, 0.3, gz), 5.0, 0.8, "cream", segments=16)
    for k in range(6):
        a = 2 * math.pi * (k + 0.5) / 6
        rb.cyl((gx + 4.4 * math.cos(a), 2.95, gz + 4.4 * math.sin(a)), 0.22, 4.5, "offwhite", segments=8)
    rb.cyl((gx, 5.4, gz), 5.4, 0.4, "offwhite", segments=16)
    for k, r in enumerate((4.8, 3.6, 2.3, 1.0)):
        rb.cyl((gx, 6.0 + 0.7 * k, gz), r, 0.7 + 0.01 * k, "sign_teal", segments=16)
    for i in range(5):
        x = -36.0 + i * 18.0
        z = f.ez0 - 12.0
        rb.span((x - 5.0, TOP, z - 2.0), (x + 5.0, 0.5, z + 2.0), "dark_wood")
        for j in range(3):
            flower_clump(flowers, x - 3.0 + j * 3.0, 0.5, z, n=3, spread=0.6)


def theme_forest(f, P):
    near = ring(f, 60.0, 42.0, (40.0, 28.0, 10.0, 22.0), 21)
    far = ring(f, 215.0, 90.0, (80.0, 56.0, 60.0, 95.0), 22, corner=180.0)
    f.hills = near + far
    for h in near:
        h.add(P["hills"], "leaf_dark")
    for h in far:
        h.add(P["far"], "leaf_dark")
    rb = P["rb"]
    for h in far:                                                    # snow on the tallest peaks
        if h.rise > 80.0:
            P["snow"].b.ico(RB.p(h.x, h.b * 0.86 - h.rise * Hill.SINK, h.z), 1.0, "offwhite", subdivisions=2,
                            scale=(h.a * 0.32, h.c * 0.32, h.b * 0.17), rot=(h.turn, "Z"))
    leaves = ("leaf_dark", "paw_woods", "leaf_green", "paw_woods")
    belt(rb, f, 9.0, 13.0, 23, plant=fir, scale=1.6, leaves=leaves)
    belt(rb, f, 25.0, 16.0, 24, plant=tree, scale=1.8, leaves=leaves, wobble=5.0)
    on_hills(rb, f, near, 2, 26, 2.2, plant=fir, leaves=leaves)


def theme_houses(f, P):
    near = ring(f, 95.0, 46.0, (40.0, 28.0, 8.0, 16.0), 31)
    far = ring(f, 200.0, 70.0, (62.0, 46.0, 22.0, 40.0), 32)
    f.hills = near + far
    for h in near:
        h.add(P["hills"], "leaf_green")
    for h in far:
        h.add(P["far"], "leaf_green")
    rb, lit, flowers = P["rb"], P["lit"], P["flowers"]
    on_hills(rb, f, near, 1, 33, 1.6)
    on_hills(rb, f, far, 1, 34, 2.6, plant=far_tree)
    # a road round the area with a pavement on its far side, the first row of houses facing it
    road = P["road"]
    for (x0, x1, z0, z1) in _frame_rects(f, 5.0, 15.0):
        road.span((x0, TOP + 0.05, z0), (x1, 0.12, z1), "fur_charcoal")
    for (x0, x1, z0, z1) in _frame_rects(f, 15.0, 18.0):
        rb.span((x0, TOP + 0.05, z0), (x1, 0.3, z1), "paving_sand")
    for i, (x, z, nx, nz) in enumerate(f.around(29.0, 27.0, 35, corners=False)):
        t = Turned.facing(x, z, nx, nz)
        w, d, h = 10.0 + 3 * _hash(i, 1), 9.0, 6.0 + 3.5 * _hash(i, 2)
        house(t, rb, lit, w, d, h, WALLS[i % len(WALLS)], ROOFS[(i * 5) % len(ROOFS)], i)
        t.span(rb, (-w / 2 - 1.5, TOP, -11.0), (w / 2 + 1.5, 1.3, -10.7), "offwhite")   # a fence on the pavement
        if i % 2:
            tuft(rb, flowers, *t.p((w * 0.3, 0, -6.6))[::2], 0.6)
        if _hash(i, 3) < 0.6:
            tree(rb, f, *t.p((w / 2 + 4.5, 0, 2.0))[::2], 1.2, LEAVES[i % 3])
        if i % 2 == 0:                                                   # a street lamp at the kerb
            lx, _, lz = t.p((-w / 2 - 3.0, 0, -13.0))
            rb.cyl((lx, 2.4, lz), 0.18, 5.0, "fur_charcoal", segments=8)
            lit.span((lx - 0.4, 4.9, lz - 0.4), (lx + 0.4, 5.6, lz + 0.4), "lamp_warm")
            rb.span((lx - 0.55, 5.6, lz - 0.55), (lx + 0.55, 5.85, lz + 0.55), "fur_charcoal")
    # a second row further out: plainer houses between trees, seen as roofs over the first
    for i, (x, z, nx, nz) in enumerate(f.around(58.0, 30.0, 36, corners=False, shift=4.0)):
        if _hash(i, 4) < 0.35:
            tree(rb, f, x, z, 1.5, LEAVES[i % 3])
            continue
        t = Turned.facing(x, z, nx, nz, y=f.gy(x, z) - 0.2)
        w, h = 11.0 + 3 * _hash(i, 5), 7.0 + 3 * _hash(i, 6)
        t.span(rb, (-w / 2, TOP, -4.5), (w / 2, h, 4.5), WALLS[(i + 3) % len(WALLS)])
        rise = 0.45 * w
        for s in (-1, 1):
            t.wedge(rb, (s * (w / 4 + 0.15), h + rise / 2, 0), (10.2, rise, w / 2 + 0.3), ROOFS[(i * 3) % len(ROOFS)],
                    rot_y(-s * 90))
        t.span(lit, (-0.8, h * 0.45, -4.62), (0.8, h * 0.45 + 1.5, -4.5), "pastel_sky")


def theme_city(f, P):
    far = ring(f, 220.0, 80.0, (66.0, 48.0, 22.0, 40.0), 41)
    f.hills = far
    for h in far:
        h.add(P["far"], "leaf_green")
    rb, lit = P["rb"], P["lit"]
    road = P["road"]
    for (x0, x1, z0, z1) in _frame_rects(f, 0.0, MARGIN - 1.0):     # the plate under the city in asphalt
        road.span((x0, TOP + 0.05, z0), (x1, 0.08, z1), "fur_charcoal")
    # the first row hard by the walls (the street behind the camp), the second taller behind it
    for row, (d, step, h0, h1, depth) in enumerate(((1.6, 17.0, 16.0, 34.0, 20.0), (26.0, 21.0, 30.0, 58.0, 22.0))):
        for i, (x, z, nx, nz) in enumerate(f.around(d + depth / 2, step, 42 + row, corners=row == 1)):
            back = nz < -0.9
            if back and row == 0:
                continue                                                # the street behind the camp
            if back:                                                    # behind the street's own row
                x, z = x + nx * 12.0, z + nz * 12.0
            t = Turned.facing(x, z, nx, nz)
            w = step - 0.6 - 2.0 * _hash(i, row, 1)
            h = h0 + (h1 - h0) * _hash(i, row, 2)
            block(t, rb, lit, w, depth, h, CITY[(i * 3 + row) % len(CITY)], i, grid=row == 1 or _hash(i, 3) < 0.5,
                  tank=_hash(i, row, 4) < 0.3, bands=row == 0, shop=row == 0)
    # behind the camp: a kerb, then the first row across the street
    for i, (x, z, nx, nz) in enumerate(f.around(24.0, 16.0, 44, corners=False)):
        if nz > -0.9:
            continue
        t = Turned.facing(x, z, nx, nz)
        block(t, rb, lit, 15.0 - 1.5 * _hash(i, 9), 18.0, 18.0 + 14.0 * _hash(i, 8), CITY[(i * 5) % len(CITY)], i,
              tank=i % 2 == 0)
    for (x0, x1, z0, z1) in _frame_rects(f, 12.5, 14.5, sides=("back",)):
        rb.span((x0, 0.0, z0), (x1, 0.3, z1), "concrete")
    # towers further off, in soft hazy colours, their faces in window rows
    for i, (x, z, nx, nz) in enumerate(f.around(110.0, 60.0, 45, wobble=16.0, shift=12.0)):
        if _hash(i, 46) < 0.3:
            continue
        w, h = 16.0 + 8 * _hash(i, 47), 46.0 + 34 * _hash(i, 48)
        t = Turned.facing(x, z, nx, nz)
        sw = ("fur_mist", "pastel_lilac", "fur_silver", "fur_teal_grey")[i % 4]
        t.span(rb, (-w / 2, TOP, -w / 2), (w / 2, h, w / 2), sw)
        t.span(rb, (-w / 2 - 0.4, h, -w / 2 - 0.4), (w / 2 + 0.4, h + 1.0, w / 2 + 0.4), "concrete")
        t.span(lit, (-w / 2 + 1.5, 4.0, -w / 2 - 0.1), (w / 2 - 1.5, h - 2.0, -w / 2 + 0.05), "pastel_sky")
        for k in range(1, int((h - 6.0) / 9.0) + 1):
            y = 4.0 + k * 9.0
            t.span(rb, (-w / 2 + 1.4, y - 1.6, -w / 2 - 0.2), (w / 2 - 1.4, y + 0.1, -w / 2 + 0.1), sw)


def theme_works(f, P):
    near = ring(f, 70.0, 44.0, (40.0, 28.0, 7.0, 14.0), 51)
    far = ring(f, 200.0, 70.0, (62.0, 46.0, 22.0, 40.0), 52)
    f.hills = near + far
    for h in near:
        h.add(P["hills"], "leaf_green")
    for h in far:
        h.add(P["far"], "leaf_green")
    rb, lit = P["rb"], P["lit"]
    on_hills(rb, f, near, 2, 53, 1.6)
    on_hills(rb, f, far, 2, 54, 2.6, plant=far_tree)
    # a concrete yard round the sewer, brick works sheds with arched windows on it, facing in
    for (x0, x1, z0, z1) in _frame_rects(f, 0.0, 40.0):
        P["road"].span((x0, TOP + 0.05, z0), (x1, 0.08, z1), "concrete")
    for i, (x, z, nx, nz) in enumerate(f.around(18.0, 30.0, 55, corners=False, shift=3.0)):
        if _hash(i, 56) < 0.25:
            continue
        t = Turned.facing(x, z, nx, nz)
        works_shed(t, rb, lit, 22.0 + 4 * _hash(i, 57), 18.0, 12.0 + 8 * _hash(i, 58), i)
    for k, (x, z) in enumerate(((-f.ex - 34.0, f.cz - 40.0), (f.ex + 40.0, f.cz + 30.0), (-30.0, f.ez1 + 44.0),
                                (f.ex + 26.0, f.ez0 - 30.0))):
        chimney(rb, x, z, 44.0 + 10 * (k % 2))
    water_tower(rb, f.ex + 34.0, f.cz - 50.0)
    for k, (x, z) in enumerate(((-f.ex - 30.0, f.ez1 + 48.0), (36.0, f.ez1 + 50.0))):
        rb.cyl((x, 8.0, z), 11.0, 16.2, "fur_pewter", segments=16)               # gas holders
        rb.cyl((x, 16.4, z), 11.4, 0.6, "fur_gunmetal", segments=16)
        for j in range(8):
            a = 2 * math.pi * j / 8
            rb.span((x + 11.5 * math.cos(a) - 0.3, TOP, z + 11.5 * math.sin(a) - 0.3),
                    (x + 11.5 * math.cos(a) + 0.3, 18.0, z + 11.5 * math.sin(a) + 0.3), "bowl_red")
    # a big pipe on stands along each side, its flanges every 12
    for s in (-1, 1):
        x = s * (f.ex + 6.0)
        z0, z1 = f.ez0 + 10.0, f.ez1 - 10.0
        rb.cyl((x, 3.0, (z0 + z1) / 2), 1.3, z1 - z0, "rust", axis="Z", segments=12)
        n = int((z1 - z0) / 12)
        for j in range(n + 1):
            z = z0 + j * (z1 - z0) / n
            rb.cyl((x, 3.0, z), 1.6, 0.5, "metal", axis="Z", segments=12)
            rb.span((x - 0.4, TOP, z - 0.3), (x + 0.4, 1.7, z + 0.3), "concrete_dark")


def works_shed(t, rb, lit, w, d, h, k):
    """A brick works shed facing -Z: brick body, a saw-tooth roof, a row of tall arched windows (lit), a big door."""
    fz = -d / 2
    t.span(rb, (-w / 2, TOP, fz), (w / 2, h, d / 2), "brick")
    t.span(rb, (-w / 2 - 0.25, h, fz - 0.25), (w / 2 + 0.25, h + 0.5, d / 2 + 0.25), "concrete")
    n = 3
    for j in range(n):                                                      # saw-tooth roof, glass to the front
        z0 = fz + j * d / n
        t.wedge(rb, (0, h + 0.5 + 1.6, z0 + d / n / 2), (w, 3.2, d / n), "fur_charcoal", rot_y(180))
    m = max(2, int(w / 4.4))
    for j in range(m):
        x = -w / 2 + (j + 0.5) * w / m
        if abs(x) < 2.6:
            continue
        y0, y1 = 2.2, h - 3.4
        t.span(lit, (x - 0.9, y0, fz - 0.12), (x + 0.9, y1, fz), "pastel_butter")
        t.span(rb, (x - 1.15, y1, fz - 0.2), (x + 1.15, y1 + 0.9, fz), "cream")        # the arch's keystone band
        t.span(rb, (x - 1.15, y0 - 0.3, fz - 0.24), (x + 1.15, y0, fz), "cream")
    t.span(rb, (-2.4, TOP, fz - 0.15), (2.4, 5.4, fz), "dark_wood")
    t.span(rb, (-2.8, 5.4, fz - 0.3), (2.8, 6.1, fz), "cream")


def chimney(rb, x, z, h):
    rb.span((x - 3.2, TOP, z - 3.2), (x + 3.2, 4.0, z + 3.2), "brick")
    rb.cyl((x, 4.0 + h / 2, z), 2.2, h, "brick", segments=12)
    rb.cyl((x, 4.0 + h + 0.5, z), 2.6, 1.0, "fur_charcoal", segments=12)
    for y in (h * 0.35, h * 0.7):
        rb.cyl((x, 4.0 + y, z), 2.35, 0.6, "cream", segments=12)


def water_tower(rb, x, z):
    for sx in (-1, 1):
        for sz in (-1, 1):
            rb.span((x + sx * 3.5 - 0.3, TOP, z + sz * 3.5 - 0.3), (x + sx * 3.5 + 0.3, 15.9, z + sz * 3.5 + 0.3),
                    "metal")
    rb.span((x - 4.0, 15.4, z - 4.0), (x + 4.0, 16.0, z + 4.0), "concrete_dark")
    rb.cyl((x, 19.5, z), 4.6, 7.0, "sign_teal", segments=16)
    rb.ball((x, 23.0, z), 4.6, "fur_gunmetal", scale=(1.0, 0.4, 1.0))


def _frame_rects(f, d0, d1, sides=("left", "right", "far", "back")):
    """The band d0 to d1 past the footprint as up to four rects (x0, x1, z0, z1), corners on the left and right."""
    ex, z0, z1 = f.ex, f.ez0, f.ez1
    out = []
    if "left" in sides:
        out.append((-ex - d1, -ex - d0, z0 - d1, z1 + d1))
    if "right" in sides:
        out.append((ex + d0, ex + d1, z0 - d1, z1 + d1))
    if "far" in sides:
        out.append((-ex - d0, ex + d0, z1 + d0, z1 + d1))
    if "back" in sides:
        out.append((-ex - d0, ex + d0, z0 - d1, z0 - d0))
    return out


THEMES = {"park": theme_park, "forest": theme_forest, "houses": theme_houses, "city": theme_city, "works": theme_works}


def builder(area, A, H, theme):
    n = NAMES.get(area, f"CatCafe_{area}_Backdrop")
    city = theme == "city"
    _look(n + "_Ground", ASPHALT_RGB if city else GRASS_RGB, "Asphalt" if city else "Grass")
    _look(n + "_Hills", FOREST_RGB if theme == "forest" else GRASS_RGB, "Grass")
    _look(n + "_HillsFar", MOUNTAIN_RGB if theme == "forest" else PALE_RGB, "Rock" if theme == "forest" else "Grass")
    _look(n + "_Snow", (240, 244, 248), "Snow")
    _look(n + "_Road", ASPHALT_RGB if theme != "works" else (150, 150, 150), "Asphalt" if theme != "works" else "Concrete")

    def build(mat):
        f = Frame(A, H)
        P = {k: RB() for k in ("rb", "ground", "hills", "far", "flowers", "lit", "road", "snow")}
        ground(f, P["ground"], "fur_charcoal" if city else "leaf_green")
        THEMES[theme](f, P)
        objs = [P["rb"].finalize(n, mat), P["ground"].finalize(n + "_Ground", mat)]
        for key, suffix in (("hills", "_Hills"), ("far", "_HillsFar"), ("flowers", "_Flowers"), ("lit", "_Bulbs"),
                            ("road", "_Road"), ("snow", "_Snow")):
            if P[key].b.prims:
                objs.append(P[key].finalize(n + suffix, mat))
        return objs

    return build


ASSETS = {NAMES.get(area, f"CatCafe_{area}_Backdrop"): (builder(area, A, H, theme), 60000)
          for area, (A, H, theme) in AREAS.items()}
