"""The hometown's backdrop (Derek 2026-10-28 17:05: "add clouds in sky and nicer background of the actual game outside
of the map"; 17:10: "make it so that the sides of the map are blended in with terrain more smoothly and not just a patch
of grass ground stretching out"; Set 5 Q8: "the cafe area and town square become a reorganized bigger area with
something that blends in the background and borders so its not too plain"; hometown-cannon.md section 2, the backdrop
ring). Everything outside the town's hedges, in town space (the town's centre on the ground, Roblox axes, -Z toward
the Park end), placed once with no turn at (0, 0, 0).

  CatCafe_Town_Backdrop          the pieces in palette colours: trees, the north cottages, the windmill on the
                                 street's line past the north arch, the south garden with its wall, hedges and
                                 bandstand, the east barn and hay bales, the west pond, meadow flowers.
  CatCafe_Town_Backdrop_Ground   the ground carried on past the town's own ground plate (260 x 300, WorldBuilder) out
                                 to GROUND_X, GROUND_Z: four slabs round the plate, top at 0, in the plate's own grass
                                 colour and Grass material, so there is no seam and no edge in view.
  CatCafe_Town_Backdrop_Hills    the near ring of rolling hills, in the same grass, sunk well into the ground so each
                                 rises gently from it; the ring hides the town ground's edge.
  CatCafe_Town_Backdrop_HillsFar the far ring, bigger and paler, so the horizon reads as layers of countryside.
  CatCafe_Town_Backdrop_Sails    the windmill's sails (still).
  CatCafe_Town_Backdrop_Bulbs    the cottages' and the windmill's windows, lit at night like every _Bulbs.

Nothing collides, casts a shadow or takes a raycast (rbx_export BACKDROP_PREFIXES): it is scenery past the town's edge
blocks, out of reach. Every piece keeps clear of the town inside its hedges (|x| <= 64, |z| <= 126.5).
"""

import math

import rbx_export
from alleyway import flower_clump
from common import RB
from plot import rot_y, rot_z

N = "CatCafe_Town_Backdrop"
TOWN_X, TOWN_Z = 64.0, 126.5          # the hedges round the town (Layout.townEdges), outer faces
PLATE_X, PLATE_Z = 130.0, 150.0       # the town's ground plate (Config.World.TownGroundWidth and Depth halves)
GROUND_X, GROUND_Z = 430.0, 450.0     # the backdrop's ground reaches this far
GRASS_RGB = (110, 170, 90)            # WorldBuilder's GRASS, so the ground and near hills meet the plate seamlessly
LOOK = {
    N + "_Ground": (GRASS_RGB, "Grass"),
    N + "_Hills": (GRASS_RGB, "Grass"),
    N + "_HillsFar": ((150, 186, 128), "Grass"),
}
for _name, (_rgb, _material) in LOOK.items():
    rbx_export.LOOKS[_name] = ([round(v / 255, 4) for v in _rgb], _material)


def _hash(*v):
    h = 0
    for x in v:
        h = (h * 1000003 + int(round(x * 1000))) & 0xFFFFFFFF
    h ^= h >> 13
    h = (h * 0x5BD1E995) & 0xFFFFFFFF
    return (h ^ (h >> 15)) / 0xFFFFFFFF


# ---------------------------------------------------------------------------------------------------- hills --
class Hill:
    """An ellipsoid sunk into the ground: `along` and `across` are its foot's half lengths at y 0, `rise` its height
    over the ground, turned `turn` radians about Y (Roblox, like CFrame.Angles) so `along` runs that way."""

    SINK = 1.6   # the centre sits SINK x rise under the ground, so the hill meets it at a gentle slope

    def __init__(self, x, z, along, across, rise, turn):
        self.x, self.z, self.rise, self.turn = x, z, rise, turn
        b = rise * (1 + self.SINK)
        f = math.sqrt(1 - (self.SINK / (1 + self.SINK)) ** 2)     # the foot is this much of the full radius
        self.a, self.b, self.c = along / f, b, across / f

    def height(self, x, z):
        dx, dz = x - self.x, z - self.z
        ct, st = math.cos(self.turn), math.sin(self.turn)
        u, v = dx * ct - dz * st, dx * st + dz * ct                 # into the hill's own axes
        q = 1 - (u / self.a) ** 2 - (v / self.c) ** 2
        return -1.0 if q <= 0 else -self.rise * self.SINK + self.b * math.sqrt(q)

    def add(self, rb, swatch):
        rb.b.ico(RB.p(self.x, -self.rise * self.SINK, self.z), 1.0, swatch, subdivisions=2,
                 scale=(self.a, self.c, self.b), rot=(self.turn, "Z"))


def _ring(rx, rz, corner, step, sizes, seed):
    """Hills spaced about `step` apart round a rounded rectangle (half sizes rx, rz, corner radius), each lying along
    the ring. `sizes` = (along, across, rise_min, rise_max)."""
    pts = []
    sx, sz = rx - corner, rz - corner
    legs = [((-sx, -rz), (sx, -rz)), None, ((rx, -sz), (rx, sz)), None,
            ((sx, rz), (-sx, rz)), None, ((-rx, sz), (-rx, -sz)), None]
    centres = [(sx, -sz), (sx, sz), (-sx, sz), (-sx, -sz)]
    for k, leg in enumerate(legs):
        if leg is not None:
            (x0, z0), (x1, z1) = leg
            L = math.hypot(x1 - x0, z1 - z0)
            n = max(1, round(L / step))
            for i in range(n):
                t = (i + 0.5) / n
                pts.append((x0 + (x1 - x0) * t, z0 + (z1 - z0) * t, math.atan2(-(z1 - z0), x1 - x0)))
        else:
            cx, cz = centres[k // 2]
            a0 = -math.pi / 2 + (k // 2) * math.pi / 2
            n = max(1, round(corner * math.pi / 2 / step))
            for i in range(n):
                a = a0 + (i + 0.5) / n * math.pi / 2
                x, z = cx + corner * math.cos(a), cz + corner * math.sin(a)
                pts.append((x, z, math.atan2(-math.cos(a), -math.sin(a))))
    along, across, r0, r1 = sizes
    out = []
    for i, (x, z, turn) in enumerate(pts):
        h = _hash(seed, i)
        out.append(Hill(x + (h - 0.5) * 8, z + (_hash(i, seed) - 0.5) * 8, along * (0.85 + 0.3 * h),
                        across * (0.9 + 0.2 * _hash(seed, i, 2)), r0 + (r1 - r0) * _hash(i, 3, seed), turn))
    return out


def _low_on_the_line(hills):
    """Hills on the street's line past either arch stay low, so the view down the street opens onto the far ring."""
    out = []
    for h in hills:
        if abs(h.x) < 50 and abs(h.z) > 150:
            h = Hill(h.x, h.z, h.a * 0.8, h.c * 0.8, h.rise * 0.45, h.turn)
        out.append(h)
    return out


NEAR = _low_on_the_line(_ring(134.0, 182.0, 60.0, 46.0, (44.0, 30.0, 9.0, 19.0), 1))
FAR = _ring(238.0, 282.0, 110.0, 72.0, (66.0, 48.0, 24.0, 44.0), 2)


def ground_y(x, z):
    """The top of the backdrop at (x, z): the highest hill there, else the ground."""
    return max([0.0] + [h.height(x, z) for h in NEAR + FAR])


# ---------------------------------------------------------------------------------------------------- trees --
LEAVES = ("leaf_green", "leaf_dark", "paw_park")


def tree(rb, x, z, s=1.0, leaf="leaf_green", y=None):
    """A round tree s times the town gardens' size, standing on the backdrop's ground at (x, z)."""
    y = ground_y(x, z) - 0.3 * s if y is None else y
    rb.cyl((x, y + 2.2 * s, z), 0.5 * s, 4.4 * s, "fur_brown", segments=8)
    rb.ball((x, y + 6.0 * s, z), 3.0 * s, leaf)
    rb.ball((x + 1.9 * s, y + 4.9 * s, z - 0.5 * s), 1.9 * s, leaf)
    rb.ball((x - 1.7 * s, y + 5.3 * s, z + 0.6 * s), 1.8 * s, leaf)


def far_tree(rb, x, z, s, leaf):
    """A far tree: a trunk and one round crown, two parts."""
    y = ground_y(x, z) - 0.3 * s
    rb.cyl((x, y + 1.8 * s, z), 0.5 * s, 3.6 * s, "fur_brown", segments=6)
    rb.ball((x, y + 5.2 * s, z), 2.9 * s, leaf, scale=(1.0, 1.1, 1.0))


def bush(rb, x, z, s=1.0, leaf="leaf_dark"):
    y = ground_y(x, z)
    rb.ball((x, y + 0.6 * s, z), 1.6 * s, leaf, scale=(1.3, 0.8, 1.0))
    rb.ball((x + 1.6 * s, y + 0.4 * s, z + 0.5 * s), 1.0 * s, leaf, scale=(1.2, 0.8, 1.0))


def tuft(rb, flowers, x, z, spread):
    """A clump of wildflowers on a low tuft of grass."""
    rb.cyl((x, 0.04, z), spread + 0.6, 0.08, "leaf_dark", segments=10)
    flower_clump(flowers, x, 0.08, z, n=3, spread=spread)


def _clear_of_town(x, z, pad):
    return abs(x) > TOWN_X + pad or abs(z) > TOWN_Z + pad


def _scatter_trees(rb, hills, per, seed, scale, keep_out=(), plant=tree):
    """Trees on the hills' upper slopes, `per` a hill, none on the street's line past either arch."""
    for i, h in enumerate(hills):
        for k in range(per):
            t = _hash(seed, i, k)
            a = 2 * math.pi * t
            d = 0.15 + 0.45 * _hash(k, i, seed)
            x = h.x + math.cos(a) * h.a * d * math.cos(h.turn) - math.sin(a) * h.c * d * math.sin(h.turn)
            z = h.z - math.cos(a) * h.a * d * math.sin(h.turn) - math.sin(a) * h.c * d * math.cos(h.turn)
            if not _clear_of_town(x, z, 12) or any(x0 <= x <= x1 and z0 <= z <= z1 for x0, x1, z0, z1 in keep_out):
                continue
            leaf = "blush" if _hash(i, k, 7) > 0.88 else LEAVES[int(_hash(k, seed, i) * 3) % 3]
            plant(rb, x, z, scale * (0.8 + 0.5 * _hash(i, k, seed)), leaf)


# ------------------------------------------------------------------------------------------------- cottages --
WALLS = ("pastel_butter", "blush", "mint", "pastel_sky", "pastel_lilac", "cream")
ROOFS = ("terracotta", "bowl_red", "fur_slate", "sign_teal", "brick", "galaxy_blue")


def hedge(rb, x0, x1, z, h, d):
    """A clipped hedge along X with a rounded top."""
    rb.span((x0, 0, z - d / 2), (x1, h, z + d / 2), "leaf_dark")
    n = max(1, round((x1 - x0) / 4))
    for i in range(n):
        rb.ball((x0 + (i + 0.5) * (x1 - x0) / n, h, z), 1.0, "leaf_dark", scale=((x1 - x0) / n * 0.6, 0.4 * d, 0.55 * d))


def cottage(rb, lit, x, z, w, d, h, wall, roof, k):
    """A little house facing -Z (the town): walls, a gable roof of two wedges, a chimney, a door and two windows."""
    y = 0.0
    rb.span((x - w / 2, y, z - d / 2), (x + w / 2, y + h, z + d / 2), wall)
    rise = 0.45 * w
    for s in (-1, 1):                                     # each roof half: a wedge rising toward the ridge
        rb.wedge((x + s * (w / 4 + 0.15), y + h + rise / 2, z), (d + 1.2, rise, w / 2 + 0.3), roof,
                 rot=rot_y(-s * 90))
    rb.span((x + w * 0.22, y + h + rise * 0.3, z + d * 0.1), (x + w * 0.22 + 1.1, y + h + rise * 0.95, z + d * 0.1 + 1.1),
            "brick")                                      # chimney
    rb.span((x - 0.8, y, z - d / 2 - 0.12), (x + 0.8, y + 2.8, z - d / 2), ROOFS[(k + 2) % len(ROOFS)])   # door
    for s in (-1, 1):
        wx = x + s * w * 0.3
        lit.span((wx - 0.8, y + h * 0.45, z - d / 2 - 0.12), (wx + 0.8, y + h * 0.45 + 1.5, z - d / 2), "pastel_sky")
        rb.span((wx - 1.0, y + h * 0.45 - 0.25, z - d / 2 - 0.3), (wx + 1.0, y + h * 0.45, z - d / 2), "offwhite")


# -------------------------------------------------------------------------------------------------- windmill --
def windmill(rb, lit, sails, x, z):
    """A white windmill with a red cap, its sails toward the town (-Z), on the hill top past the north arch."""
    y = ground_y(x, z) - 0.5
    rb.cyl((x, y + 9.0, z), 3.6, 18.0, "offwhite", segments=12)
    rb.cyl((x, y + 18.6, z), 3.4, 1.2, "dark_wood", segments=12)
    rb.ball((x, y + 19.2, z), 3.4, "bowl_red", scale=(1.0, 0.9, 1.0))
    rb.span((x - 1.1, y, z - 3.75), (x + 1.1, y + 3.6, z - 3.4), "dark_wood")         # door
    for wy in (8.0, 13.0):
        lit.span((x - 0.7, y + wy, z - 3.75), (x + 0.7, y + wy + 1.4, z - 3.45), "pastel_sky")
    hub = (x, y + 17.5, z - 4.0)
    rb.cyl(hub, 0.7, 1.4, "dark_wood", axis="Z", segments=10)
    for k in range(4):
        a = math.radians(45 + 90 * k)
        ca, sa = math.cos(a), math.sin(a)
        L = 11.0
        cx, cy = hub[0] + ca * (L / 2 + 0.6), hub[1] + sa * (L / 2 + 0.6)
        rot = rot_z(math.degrees(a))
        sails.box((cx, cy, hub[2] - 0.2), (L, 0.35, 0.3), "dark_wood", rot=rot)
        px, py = hub[0] + ca * (L / 2 + 1.6) - sa * 1.2, hub[1] + sa * (L / 2 + 1.6) + ca * 1.2
        sails.box((px, py, hub[2] - 0.3), (L - 2.4, 2.2, 0.12), "cream", rot=rot)


# ----------------------------------------------------------------------------------------- the town's ends --
def north_end(rb, flowers, lit, sails):
    """Past the north arch: a row of cottages either side of the street's line with gardens and hedges, the windmill
    on the hill behind the line."""
    xs = (-74.0, -52.0, -31.0, 31.0, 52.0, 74.0)
    for k, x in enumerate(xs):
        w, d, h = 9.0 + 2 * _hash(k, 1), 8.0, 6.0 + 1.5 * _hash(k, 2)
        z = 140.0 + 2.5 * _hash(k, 3)
        cottage(rb, lit, x, z, w, d, h, WALLS[k % len(WALLS)], ROOFS[k % len(ROOFS)], k)
        hedge(rb, x - w / 2 - 1.5, x + w / 2 + 1.5, z - d / 2 - 3.8, 1.6, 0.8)
        for j in range(2):
            tuft(rb, flowers, x - w / 2 + 2.0 + j * (w - 4), z - d / 2 - 1.2, 0.6)
        tree(rb, x + w / 2 + 4.5, z + 3.0, 1.0, LEAVES[k % 3], y=0.0)
    windmill(rb, lit, sails, 0.0, 190.0)


def south_end(rb, flowers):
    """Past the south arch: a garden behind a low brick wall, with clipped hedges, round topiaries, flower beds,
    trees and a white bandstand on the street's line."""
    z0 = -131.0
    for x0, x1 in ((-78.0, -10.0), (10.0, 78.0)):                     # the wall, open on the line
        rb.span((x0, 0, z0 - 0.5), (x1, 2.2, z0 + 0.5), "brick")
        rb.span((x0 - 0.1, 2.2, z0 - 0.65), (x1 + 0.1, 2.5, z0 + 0.65), "cream")
        n = round((x1 - x0) / 11)
        for i in range(n + 1):
            px = x0 + i * (x1 - x0) / n
            rb.span((px - 0.8, 0, z0 - 0.8), (px + 0.8, 3.2, z0 + 0.8), "brick")
            rb.span((px - 0.95, 3.2, z0 - 0.95), (px + 0.95, 3.5, z0 + 0.95), "cream")
            rb.ball((px, 4.0, z0), 0.5, "terracotta")
    for s in (-1, 1):
        for i in range(4):                                             # flower beds and topiaries
            x = s * (18.0 + i * 15.0)
            rb.span((x - 5.0, 0, z0 - 4.8), (x + 5.0, 0.5, z0 - 1.6), "dark_wood")
            for j in range(3):
                flower_clump(flowers, x - 3.0 + j * 3.0, 0.5, z0 - 3.2, n=3, spread=0.6)
            rb.ball((x + 7.5, 1.6, z0 - 6.5), 1.6, "leaf_dark")
            rb.ball((x + 7.5, 3.7, z0 - 6.5), 1.0, "leaf_dark")
        hedge(rb, min(s * 12.0, s * 74.0), max(s * 12.0, s * 74.0), z0 - 9.75, 2.4, 1.5)   # a clipped hedge behind
    # the bandstand: a white octagon with a blush dome, on the line, 12 behind the wall
    bx, bz = 0.0, z0 - 14.0
    rb.cyl((bx, 0.4, bz), 6.0, 0.8, "cream", segments=16)
    for k in range(8):
        a = 2 * math.pi * (k + 0.5) / 8
        rb.cyl((bx + 5.3 * math.cos(a), 3.3, bz + 5.3 * math.sin(a)), 0.25, 5.0, "offwhite", segments=8)
    rb.cyl((bx, 6.05, bz), 6.4, 0.5, "offwhite", segments=16)
    for k, r in enumerate((5.8, 4.5, 3.1, 1.6)):                      # a stepped roof
        rb.cyl((bx, 6.7 + 0.8 * k, bz), r, 0.8 + 0.01 * k, "blush", segments=16)
    rb.ball((bx, 10.0, bz), 0.6, "rarity_legend")
    for x in (-6.0, 6.0):
        tree(rb, bx + x * 2.4, bz - 8.0, 1.2, "leaf_green", y=0.0)


def east_side(rb, hay):
    """The east meadow: a red barn with a silo and hay bales."""
    x, z = 88.0, -40.0
    w, d, h = 16.0, 12.0, 8.0
    rb.span((x - d / 2, 0, z - w / 2), (x + d / 2, h, z + w / 2), "bowl_red")
    rise = 6.0
    for s in (-1, 1):
        rb.wedge((x + s * (d / 4 + 0.15), h + rise / 2, z), (w + 1.0, rise, d / 2 + 0.3), "fur_charcoal",
                 rot=rot_y(-s * 90))
    rb.span((x - d / 2 - 0.15, 0, z - 3.0), (x - d / 2, 6.0, z + 3.0), "offwhite")       # big doors, to the town
    rb.span((x - d / 2 - 0.25, 2.9, z - 3.0), (x - d / 2 - 0.15, 3.1, z + 3.0), "bowl_red")
    rb.cyl((x + 2.0, 8.0, z + w / 2 + 3.5), 3.0, 16.0, "metal", segments=12)            # silo
    rb.ball((x + 2.0, 16.0, z + w / 2 + 3.5), 3.0, "fur_charcoal", scale=(1.0, 0.6, 1.0))
    for i, (bx, bz) in enumerate(((76.0, -60.0), (74.0, -18.0), (80.0, 8.0), (88.0, 30.0))):
        hay.cyl((bx, 1.4, bz), 1.4, 2.4, "fur_sand", axis="X", segments=10)               # bales in twos
        hay.cyl((bx + 0.6, 1.4, bz + 2.75), 1.4, 2.4, "fur_sand", axis="X", segments=10)


def west_side(rb):
    """The west meadow: a pond with a sandy rim, reeds and a little jetty."""
    x, z = -84.0, 28.0
    rb.cyl((x, 0.05, z), 12.5, 0.1, "fur_sand", segments=20)
    rb.cyl((x, 0.12, z), 11.0, 0.1, "pastel_sky", segments=20)
    rb.span((x + 8.0, 0.5, z - 1.2), (x + 15.0, 0.8, z + 1.2), "caramel_wood")
    for px in (x + 9.0, x + 12.0):
        for pz in (z - 1.1, z + 1.1):
            rb.span((px - 0.2, 0, pz - 0.2), (px + 0.2, 0.6, pz + 0.2), "dark_wood")
    for k in range(9):
        a = 2.2 + 0.18 * k
        rb.span((x + 11.6 * math.cos(a) - 0.12, 0, z + 11.6 * math.sin(a) - 0.12),
                (x + 11.6 * math.cos(a) + 0.12, 2.0 + 0.3 * (k % 3), z + 11.6 * math.sin(a) + 0.12), "leaf_dark")


def meadow(rb, flowers):
    """Tree clumps, bushes and wildflowers in the meadows between the hedges and the near hills."""
    spots = []
    for k in range(40):
        x = (TOWN_X + 6) + 40 * _hash(k, 11)
        z = -170 + 340 * _hash(k, 12)
        side = -1 if k % 2 else 1
        spots.append((side * x, z))
    for k, (x, z) in enumerate(spots):
        if ground_y(x, z) > 1.0 or not _clear_of_town(x, z, 6):
            continue
        if (70 < x < 100 and -70 < z < -14) or (-100 < x < -68 and 12 < z < 44):
            continue                                                   # the barn and the pond
        r = _hash(k, 13)
        if r < 0.5:
            tree(rb, x, z, 1.0 + 0.4 * r, LEAVES[k % 3])
        elif r < 0.75:
            bush(rb, x, z, 1.0 + r, LEAVES[(k + 1) % 3])
        else:
            for j in range(2):
                tuft(rb, flowers, x + 1.8 * j, z + 0.7 * j, 0.7)


def build_backdrop(mat):
    rb, ground, near, far, flowers, hay, sails, lit = RB(), RB(), RB(), RB(), RB(), RB(), RB(), RB()
    # the ground: four slabs round the town's plate, top at 0
    for (x0, x1, z0, z1) in ((-GROUND_X, GROUND_X, PLATE_Z, GROUND_Z), (-GROUND_X, GROUND_X, -GROUND_Z, -PLATE_Z),
                             (PLATE_X, GROUND_X, -PLATE_Z, PLATE_Z), (-GROUND_X, -PLATE_X, -PLATE_Z, PLATE_Z)):
        ground.span((x0, -1.0, z0), (x1, 0.0, z1), "leaf_green")
    for h in NEAR:
        h.add(near, "leaf_green")
    for h in FAR:
        h.add(far, "leaf_green")
    keep = ((-20, 20, 150, 240), (-20, 20, -240, -150))                # the street's line past both arches
    _scatter_trees(rb, NEAR, 3, 5, 1.6, keep)
    _scatter_trees(rb, FAR, 2, 6, 2.6, plant=far_tree)
    north_end(rb, flowers, lit, sails)
    south_end(rb, flowers)
    east_side(rb, hay)
    west_side(rb)
    meadow(rb, flowers)
    return [rb.finalize(N, mat), ground.finalize(N + "_Ground", mat), near.finalize(N + "_Hills", mat),
            far.finalize(N + "_HillsFar", mat), flowers.finalize(N + "_Flowers", mat),
            hay.finalize(N + "_Hay", mat), sails.finalize(N + "_Sails", mat), lit.finalize(N + "_Bulbs", mat)]


ASSETS = {N: (build_backdrop, 60000)}
