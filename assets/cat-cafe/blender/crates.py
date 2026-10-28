"""Cafe Crates (F53, golden-fish.md section 4; Derek 2026-10-28 00:54: "crates still missing designs for pictures
and models needed"): one crate for each pool, the five zones and Classic, and its golden version. They stand on the
Golden Fish Market's shelf, open in the crate reveal and give the shop and inventory their pictures (icons.py).

  CatCafe_Prop_Crate_<Pool>        Alley (a street slat crate), Park (a picnic hamper), Neighbourhood (a parcel),
                                   Woods (a log chest), Sewer (a steel utility crate with a rubber duck), Classic
                                   (the cafe's own crate with a ribbon)
  CatCafe_Prop_Crate_<Pool>_Gold   the golden crate: the same crate in the three metal golds, its accents kept

Each crate carries its zone's paw (paw_<zone>; Alley neon pink, Classic blush). Pivot base centre, front -Z, about
2.4 wide, 1.9 deep and 2.1 tall. The lid is the child Model <name>_Lid, pivoted on its back hinge: turning it about
X by a positive angle lifts the front (about 105 degrees is wide open). Nothing collides.
"""

import math

from mathutils import Matrix, Vector

import palette
from common import RB, bake_transform
from plot import rot_z

W, D, H = 1.2, 0.95, 1.6         # half width, half depth, body height
HINGE = (0.0, H, D + 0.06)       # the lid turns about the back top edge

PAW = {"Alley": "neon_pink", "Park": "paw_park", "Neighbourhood": "paw_neighbourhood", "Woods": "paw_woods",
       "Sewer": "paw_sewer", "Classic": "blush"}


def _paw(b, cx, cy, z, s, swatch, depth=0.02):
    """A paw print facing -Z on the face at depth z: a pad and four toes, s across."""
    b.span((cx - 0.3 * s, cy - 0.32 * s, z - depth), (cx + 0.3 * s, cy + 0.08 * s, z), swatch)
    b.span((cx - 0.2 * s, cy - 0.42 * s, z - depth), (cx + 0.2 * s, cy - 0.32 * s, z), swatch)
    for tx, ty in ((-0.42, 0.22), (-0.15, 0.4), (0.15, 0.4), (0.42, 0.22)):
        b.span((cx + (tx - 0.1) * s, cy + (ty - 0.1) * s, z - depth), (cx + (tx + 0.1) * s, cy + (ty + 0.12) * s, z),
               swatch)


def _top_paw(b, cx, cz, y, s, swatch, depth=0.02):
    """A paw print lying on a top face at height y, toes toward -Z (read from the front)."""
    b.span((cx - 0.3 * s, y, cz - 0.08 * s), (cx + 0.3 * s, y + depth, cz + 0.32 * s), swatch)
    b.span((cx - 0.2 * s, y, cz + 0.32 * s), (cx + 0.2 * s, y + depth, cz + 0.42 * s), swatch)
    for tx, tz in ((-0.42, -0.22), (-0.15, -0.4), (0.15, -0.4), (0.42, -0.22)):
        b.span((cx + (tx - 0.1) * s, y, cz + (tz - 0.12) * s), (cx + (tx + 0.1) * s, y + depth, cz + (tz + 0.1) * s),
               swatch)


def _faces(fn):
    """Call fn(axis, sign) for the four sides: ("z", -1) front, ("z", 1) back, ("x", -1) and ("x", 1)."""
    for axis, sign in (("z", -1), ("z", 1), ("x", -1), ("x", 1)):
        fn(axis, sign)


def _side_span(b, axis, sign, u0, u1, y0, y1, n0, n1, swatch):
    """A block on one side: u runs along the face (x on front and back, z on the sides), n is depth out from the
    centre (n0 < n1), so the same call draws on any side."""
    if axis == "z":
        b.span((u0, y0, sign * n0), (u1, y1, sign * n1), swatch)
    else:
        b.span((sign * n0, y0, u0), (sign * n1, y1, u1), swatch)


# ---------------------------------------------------------------------------------------------------- crates --
def alley(b, lid):
    """A street slat crate: dark posts, three slats a side in two woods, iron corner plates, a spray-painted paw."""
    slats = ((0.1, 0.56), (0.6, 1.06), (1.1, 1.56))
    b.span((-W + 0.1, 0.04, -D + 0.1), (W - 0.1, H - 0.07, D - 0.1), "dark_wood")        # the core, seen between
    for sx in (-1, 1):
        for sz in (-1, 1):
            b.span((min(sx * W, sx * (W - 0.2)), 0.0, min(sz * D, sz * (D - 0.2))),
                   (max(sx * W, sx * (W - 0.2)), H, max(sz * D, sz * (D - 0.2))), "fur_bramble")

    def slat(axis, sign):
        half = (W if axis == "z" else D) - 0.2
        out = (D if axis == "z" else W)
        for k, (y0, y1) in enumerate(slats):
            _side_span(b, axis, sign, -half, half, y0, y1, out - 0.12, out - 0.04,
                       ("caramel_wood", "fur_acorn", "fur_caramel")[(k + (axis == "x")) % 3])
    _faces(slat)
    for sx in (-1, 1):                                                   # iron plates on the front corners
        for y0, y1 in ((0.04, 0.4), (H - 0.36, H - 0.02)):
            b.span((min(sx * (W - 0.42), sx * (W - 0.01)), y0, -D - 0.03),
                   (max(sx * (W - 0.42), sx * (W - 0.01)), y1, -D), "metal")
            for yy in ((y0 + 0.12,) if y0 < 1 else (y1 - 0.12,)):
                b.span((sx * (W - 0.12) - 0.04, yy - 0.04, -D - 0.06), (sx * (W - 0.12) + 0.04, yy + 0.04, -D - 0.03),
                       "fur_black")
    # the paw, sprayed across the slats (the dark gaps stay dark)
    paw_z = -D + 0.04
    for (x0, x1, y0, y1) in _paw_blocks(0.0, 0.86, 0.95):
        for (s0, s1) in slats:
            a, c = max(y0, s0), min(y1, s1)
            if c - a > 0.01:
                b.span((x0, a, paw_z - 0.012), (x1, c, paw_z), PAW["Alley"])
    # lid: a board under four planks, two battens and a rope handle
    lid.span((-W - 0.04, H, -D - 0.04), (W + 0.04, H + 0.06, D + 0.06), "dark_wood")
    n = 4
    z0, z1 = -D - 0.04, D + 0.06
    for k in range(n):
        a = z0 + (z1 - z0) * k / n + 0.025
        c = z0 + (z1 - z0) * (k + 1) / n - 0.025
        lid.span((-W - 0.04, H + 0.06, a), (W + 0.04, H + 0.2, c), ("caramel_wood", "fur_acorn")[k % 2])
    for sx in (-1, 1):
        lid.span((sx * 0.85 - 0.12, H + 0.2, -D - 0.02), (sx * 0.85 + 0.12, H + 0.28, D + 0.04), "fur_bramble")
    for sx in (-1, 1):
        lid.span((sx * 0.3 - 0.05, H + 0.2, -0.05), (sx * 0.3 + 0.05, H + 0.42, 0.05), "fur_caramel")
    lid.span((-0.35, H + 0.42, -0.05), (0.35, H + 0.5, 0.05), "fur_caramel")


def _paw_blocks(cx, cy, s):
    """The paw as (x0, x1, y0, y1) rectangles, for painting it across slats."""
    out = [(cx - 0.3 * s, cx + 0.3 * s, cy - 0.32 * s, cy + 0.08 * s),
           (cx - 0.2 * s, cx + 0.2 * s, cy - 0.42 * s, cy - 0.32 * s)]
    for tx, ty in ((-0.42, 0.22), (-0.15, 0.4), (0.15, 0.4), (0.42, 0.22)):
        out.append((cx + (tx - 0.1) * s, cx + (tx + 0.1) * s, cy + (ty - 0.1) * s, cy + (ty + 0.12) * s))
    return out


def park(b, lid):
    """A picnic hamper: woven bands over stakes, a dark rim, rope side handles; the lid has a red gingham cloth,
    a daisy and two leather straps that fasten down the front."""
    b.span((-W + 0.08, 0.02, -D + 0.08), (W - 0.08, H - 0.02, D - 0.08), "caramel_wood")
    rows = [(0.06 + 0.25 * k, 0.06 + 0.25 * k + 0.2) for k in range(6)]

    def weave(axis, sign):
        half = (W if axis == "z" else D) - 0.08
        out = (D if axis == "z" else W) - 0.08
        n = 6 if axis == "z" else 5
        for k in range(n + 1):                                           # stakes
            u = -half + 0.1 + (2 * half - 0.2) * k / n
            _side_span(b, axis, sign, u - 0.05, u + 0.05, 0.02, H - 0.14, out, out + 0.03, "dark_wood")
        for k, (y0, y1) in enumerate(rows):                              # bands, every other one proud
            _side_span(b, axis, sign, -half, half, y0, y1, out, out + (0.06 if k % 2 == 0 else 0.045),
                       "fur_caramel" if k % 2 == 0 else "treat_tan")
        _side_span(b, axis, sign, -half - 0.08, half + 0.08, H - 0.14, H, out, out + 0.1, "fur_acorn")   # the rim
    _faces(weave)
    for sx in (-1, 1):                                                   # rope handles on the sides
        for sz in (-0.35, 0.35):
            b.span((sx * (W + 0.02) - 0.05, 1.0, sz - 0.05), (sx * (W + 0.02) + 0.05, 1.3, sz + 0.05), "fur_bramble")
        b.span((min(sx * (W + 0.02), sx * (W + 0.14)), 1.26, -0.4), (max(sx * (W + 0.02), sx * (W + 0.14)), 1.36, 0.4),
               "fur_bramble")
    _paw(b, 0.0, 0.95, -D - 0.025, 0.7, PAW["Park"], depth=0.02)
    # lid: wicker board, the cloth in a 4 x 3 check with a fold over the front, a daisy, the straps
    lid.span((-W - 0.04, H, -D - 0.04), (W + 0.04, H + 0.16, D + 0.06), "fur_caramel")
    lid.span((-W - 0.06, H + 0.02, -D - 0.06), (W + 0.06, H + 0.1, D + 0.08), "fur_acorn")
    cw, cd = 1.7, 1.3
    for i in range(4):
        for j in range(3):
            x0, x1 = -cw / 2 + cw * i / 4, -cw / 2 + cw * (i + 1) / 4
            z0, z1 = -cd / 2 - 0.15 + cd * j / 3, -cd / 2 - 0.15 + cd * (j + 1) / 3
            lid.span((x0, H + 0.16, z0), (x1, H + 0.2 + 0.004 * ((i + j) % 2), z1),
                     "bowl_red" if (i + j) % 2 == 0 else "offwhite")
    for i in range(4):                                                   # the fold over the front edge
        x0, x1 = -cw / 2 + cw * i / 4, -cw / 2 + cw * (i + 1) / 4
        lid.span((x0, H + 0.0, -D - 0.1), (x1, H + 0.2, -D - 0.06), "offwhite" if i % 2 == 0 else "bowl_red")
    for dx, dz in ((0, -0.13), (0, 0.13), (-0.13, 0), (0.13, 0)):        # a daisy on the cloth
        lid.span((0.45 + dx - 0.07, H + 0.2, 0.15 + dz - 0.07), (0.45 + dx + 0.07, H + 0.24, 0.15 + dz + 0.07),
                 "offwhite")
    lid.span((0.45 - 0.06, H + 0.2, 0.15 - 0.06), (0.45 + 0.06, H + 0.26, 0.15 + 0.06), "pastel_butter")
    for sx in (-1, 1):                                                   # straps over the lid and down the front
        u = sx * 0.95
        lid.span((u - 0.09, H + 0.16, -D - 0.12), (u + 0.09, H + 0.21, D + 0.08), "dark_wood")
        lid.span((u - 0.09, H - 0.45, -D - 0.16), (u + 0.09, H + 0.21, -D - 0.12), "dark_wood")
        lid.span((u - 0.12, H - 0.36, -D - 0.19), (u + 0.12, H - 0.2, -D - 0.16), "brass")


def neighbourhood(b, lid):
    """A parcel: a cardboard box with a shoebox lid, a string tied round with a bow, an address label and a stamp."""
    b.span((-W, 0.0, -D), (W, H - 0.05, D), "cardboard")

    def string(axis, sign):
        out = (D if axis == "z" else W)
        _side_span(b, axis, sign, -0.04, 0.04, 0.0, H - 0.34, out, out + 0.02, "offwhite")
    _faces(string)
    # the address label (three lines) and the stamp with a tiny house
    b.span((-1.0, 0.42, -D - 0.02), (-0.2, 0.92, -D), "offwhite")
    for k, (x1) in enumerate((-0.4, -0.55, -0.48)):
        b.span((-0.92, 0.78 - 0.13 * k - 0.025, -D - 0.03), (x1, 0.78 - 0.13 * k + 0.025, -D - 0.02), "dark_wood")
    b.span((0.45, 0.6, -D - 0.02), (0.95, 1.08, -D), "offwhite")
    b.span((0.5, 0.65, -D - 0.03), (0.9, 1.03, -D - 0.02), "pastel_sky")
    b.span((0.6, 0.7, -D - 0.045), (0.8, 0.86, -D - 0.03), "blush")
    b.span((0.62, 0.86, -D - 0.045), (0.78, 0.96, -D - 0.03), "bowl_red")                       # its roof
    # lid: covers the top 0.35 of the box, the string over it and a bow on top, the zone paw on the front edge
    lid.span((-W - 0.05, H - 0.4, -D - 0.05), (W + 0.05, H + 0.06, D + 0.05), "cardboard")
    lid.span((-W - 0.02, H + 0.06, -D - 0.02), (W + 0.02, H + 0.08, D + 0.02), "treat_tan")
    lid.span((-0.04, H + 0.08, -D - 0.05), (0.04, H + 0.1, D + 0.05), "offwhite")
    lid.span((-W - 0.05, H + 0.08, -0.04), (W + 0.05, H + 0.1, 0.04), "offwhite")
    for axis, sign in (("z", -1), ("z", 1)):
        _side_span(lid, axis, sign, -0.04, 0.04, H - 0.4, H + 0.1, D + 0.05, D + 0.07, "offwhite")
    for axis, sign in (("x", -1), ("x", 1)):
        _side_span(lid, axis, sign, -0.04, 0.04, H - 0.4, H + 0.1, W + 0.05, W + 0.07, "offwhite")
    for sx in (-1, 1):                                                   # the bow: two loops and two tails
        lid.box((sx * 0.2, H + 0.22, 0.0), (0.34, 0.2, 0.08), "offwhite", rot=rot_z(sx * 25))
        lid.box((sx * 0.14, H + 0.12, -0.12), (0.06, 0.04, 0.22), "offwhite", rot=Matrix.Rotation(sx * 0.5, 3, "Y"))
    lid.span((-0.07, H + 0.1, -0.07), (0.07, H + 0.26, 0.07), "offwhite")
    _paw(lid, -0.7, H - 0.17, -D - 0.05, 0.55, PAW["Neighbourhood"])


def woods(b, lid):
    """A log chest: split logs in three woods between bark posts, iron bands with rivets, a brass lock; the lid is
    a rounded roof of three logs with moss and a mushroom cluster."""
    logs = [(0.04 + 0.39 * k, 0.04 + 0.39 * (k + 1) - 0.02) for k in range(4)]
    b.span((-W + 0.12, 0.02, -D + 0.12), (W - 0.12, H - 0.02, D - 0.12), "fur_bramble")
    for sx in (-1, 1):
        for sz in (-1, 1):
            b.span((min(sx * W, sx * (W - 0.24)), 0.0, min(sz * D, sz * (D - 0.24))),
                   (max(sx * W, sx * (W - 0.24)), H, max(sz * D, sz * (D - 0.24))), "fur_bramble")

    def log_face(axis, sign):
        half = (W if axis == "z" else D) - 0.24
        out = (D if axis == "z" else W) - 0.12
        for k, (y0, y1) in enumerate(logs):
            tone = ("caramel_wood", "fur_acorn", "fur_caramel")[(k + (axis == "x")) % 3]
            _side_span(b, axis, sign, -half, half, y0, y1, out, out + 0.1, tone)
            _side_span(b, axis, sign, -half, half, y0 + 0.08, y1 - 0.08, out + 0.1, out + 0.14, tone)
    _faces(log_face)
    for sx in (-1, 1):                                                   # iron bands and rivets on the front
        b.span((sx * 0.75 - 0.1, 0.0, -D - 0.06), (sx * 0.75 + 0.1, H, -D + 0.02), "fur_black")
        for (y0, y1) in logs:
            b.span((sx * 0.75 - 0.035, (y0 + y1) / 2 - 0.035, -D - 0.09), (sx * 0.75 + 0.035, (y0 + y1) / 2 + 0.035,
                   -D - 0.06), "metal")
    b.span((-0.22, 1.02, -D - 0.08), (0.22, 1.47, -D + 0.02), "brass")             # the lock and its keyhole
    b.span((-0.05, 1.12, -D - 0.1), (0.05, 1.3, -D - 0.08), "fur_black")
    _paw(b, 0.0, 0.5, -D - 0.06, 0.5, PAW["Woods"])
    # lid: three logs along x, bark ends, the bands over it, moss and mushrooms
    zs = ((-D - 0.06, -0.3, 0.3), (-0.34, 0.34, 0.44), (0.3, D + 0.06, 0.3))
    for k, (z0, z1, h) in enumerate(zs):
        lid.span((-W - 0.04, H, z0), (W + 0.04, H + h, z1), ("fur_acorn", "caramel_wood", "fur_caramel")[k])
        lid.span((-W - 0.06, H + 0.04, z0 + 0.06), (W + 0.06, H + h - 0.06, z1 - 0.06), "fur_bramble")
    for sx in (-1, 1):
        for (z0, z1, h) in zs:
            lid.span((sx * 0.75 - 0.1, H + h, z0 - 0.0), (sx * 0.75 + 0.1, H + h + 0.04, z1), "fur_black")
        lid.span((sx * 0.75 - 0.1, H - 0.02, -D - 0.1), (sx * 0.75 + 0.1, H + 0.3, -D - 0.06), "fur_black")
    for (cx, cz, y) in ((0.3, -0.62, 0.3), (-0.05, 0.12, 0.44), (-0.35, 0.66, 0.3)):    # moss, clear of the bands
        for k, (dx, dz, r, h) in enumerate(((0.0, 0.0, 0.2, 0.06), (0.17, 0.08, 0.13, 0.04), (-0.15, 0.1, 0.11, 0.08),
                                             (0.05, -0.15, 0.1, 0.03))):
            lid.span((cx + dx - r, H + y, cz + dz - r), (cx + dx + r, H + y + h, cz + dz + r),
                     ("leaf_green", "fur_moss", "leaf_dark", "leaf_green")[k])
    for (x, z, r, hgt) in ((-0.62, -0.05, 0.24, 0.26), (-0.9, 0.12, 0.16, 0.16)):   # mushrooms on the middle log
        lid.span((x - 0.06, H + 0.44, z - 0.06), (x + 0.06, H + 0.44 + hgt, z + 0.06), "offwhite")
        lid.cyl((x, H + 0.44 + hgt + 0.06, z), r, 0.12, "bowl_red", segments=10)
        for (sx, sz) in ((0.4, -0.3), (-0.35, -0.2), (0.0, 0.4)):
            lid.span((x + sx * r - 0.035, H + 0.44 + hgt + 0.12, z + sz * r - 0.035),
                     (x + sx * r + 0.035, H + 0.44 + hgt + 0.135, z + sz * r + 0.035), "offwhite")


def sewer(b, lid):
    """A steel utility crate: dark frame edges with rivets, a caution band, pipe handles; on the lid a red valve
    wheel and a rubber duck."""
    b.span((-W + 0.06, 0.06, -D + 0.06), (W - 0.06, H, D - 0.06), "fur_slate")
    for sx in (-1, 1):
        for sz in (-1, 1):
            b.span((min(sx * W, sx * (W - 0.16)), 0.0, min(sz * D, sz * (D - 0.16))),
                   (max(sx * W, sx * (W - 0.16)), H, max(sz * D, sz * (D - 0.16))), "concrete_dark")

    def skirt(axis, sign):
        half = (W if axis == "z" else D) - 0.16
        out = (D if axis == "z" else W) - 0.06
        _side_span(b, axis, sign, -half, half, 0.0, 0.16, out, out + 0.06, "concrete_dark")
        _side_span(b, axis, sign, -half, half, H - 0.12, H, out, out + 0.06, "concrete_dark")
    _faces(skirt)
    for sx in (-1, 1):                                                   # rivets up the front corners
        for y in (0.35, 0.8, 1.25):
            b.span((sx * (W - 0.08) - 0.035, y - 0.035, -D - 0.03), (sx * (W - 0.08) + 0.035, y + 0.035, -D), "metal")
    n = 8                                                                # the caution band
    for k in range(n):
        x0, x1 = -(W - 0.16) + 2 * (W - 0.16) * k / n, -(W - 0.16) + 2 * (W - 0.16) * (k + 1) / n
        b.span((x0, 0.34, -D + 0.03), (x1, 0.6, -D + 0.06 - 0.004 * (k % 2)), "pastel_butter" if k % 2 == 0 else "fur_black")
    _paw(b, 0.0, 1.05, -D + 0.06, 0.55, PAW["Sewer"])
    for sx in (-1, 1):                                                   # pipe handles
        for sz in (-0.4, 0.4):
            b.span((min(sx * W, sx * (W + 0.16)), 1.0, sz - 0.05), (max(sx * W, sx * (W + 0.16)), 1.1, sz + 0.05), "metal")
        b.cyl((sx * (W + 0.16), 1.05, 0.0), 0.07, 1.0, "metal", axis="Z", segments=8)
    # lid: plate with a rim, a valve wheel on its stem, the duck
    lid.span((-W - 0.03, H, -D - 0.03), (W + 0.03, H + 0.16, D + 0.06), "concrete_dark")
    lid.span((-W + 0.1, H + 0.16, -D + 0.1), (W - 0.1, H + 0.2, D - 0.07), "fur_slate")
    lid.cyl((-0.3, H + 0.3, 0.0), 0.08, 0.2, "metal", segments=8)
    lid.b.ring(RB.p(-0.3, H + 0.42, 0.0), 0.42, 0.08, 0.08, "bowl_red", segments=12, bevel=False)
    for a in (0, 90):
        lid.box((-0.3, H + 0.42, 0.0), (0.76, 0.05, 0.07), "bowl_red", rot=Matrix.Rotation(math.radians(a), 3, "Y"))
    dx, dz = 0.65, -0.2                                                  # the rubber duck, looking at you
    lid.span((dx - 0.2, H + 0.2, dz - 0.15), (dx + 0.2, H + 0.44, dz + 0.3), "pastel_butter")
    lid.span((dx - 0.13, H + 0.44, dz - 0.15), (dx + 0.13, H + 0.68, dz + 0.08), "pastel_butter")
    lid.span((dx - 0.08, H + 0.5, dz - 0.3), (dx + 0.08, H + 0.56, dz - 0.15), "fur_orange")
    for ex in (-0.07, 0.07):
        lid.span((dx + ex - 0.025, H + 0.58, dz - 0.16), (dx + ex + 0.025, H + 0.63, dz - 0.15), "fur_black")
    lid.span((dx - 0.06, H + 0.36, dz + 0.3), (dx + 0.06, H + 0.5, dz + 0.38), "pastel_butter")


def classic(b, lid):
    """The cafe's own crate: cream boards in a mint frame, a blush ribbon round it with a bow on the lid and a tag
    with the cafe paw."""
    b.span((-W + 0.06, 0.04, -D + 0.06), (W - 0.06, H - 0.02, D - 0.06), "cream")
    for sx in (-1, 1):
        for sz in (-1, 1):
            b.span((min(sx * W, sx * (W - 0.18)), 0.0, min(sz * D, sz * (D - 0.18))),
                   (max(sx * W, sx * (W - 0.18)), H, max(sz * D, sz * (D - 0.18))), "mint")

    def frame(axis, sign):
        half = (W if axis == "z" else D) - 0.18
        out = (D if axis == "z" else W) - 0.06
        _side_span(b, axis, sign, -half, half, 0.0, 0.18, out, out + 0.06, "mint")
        _side_span(b, axis, sign, -half, half, H - 0.16, H, out, out + 0.06, "mint")
        for k in (1, 2):                                                 # board seams
            y = 0.18 + (H - 0.34) * k / 3
            _side_span(b, axis, sign, -half, half, y - 0.015, y + 0.015, out, out + 0.01, "fur_oat")
        _side_span(b, axis, sign, -0.18, 0.18, 0.18, H - 0.16, out, out + 0.04, "blush")       # the ribbon
    _faces(frame)
    b.span((-1.0, 0.34, -D - 0.02), (-0.5, 0.8, -D + 0.06), "offwhite")                      # the tag
    _paw(b, -0.75, 0.6, -D - 0.02, 0.36, "caramel_wood", depth=0.015)
    b.span((-0.78, 0.8, -D - 0.015), (-0.72, 1.0, -D + 0.06), "dark_wood")                    # its string
    # lid: cream with a mint rim, the ribbon cross, the bow
    lid.span((-W - 0.04, H, -D - 0.04), (W + 0.04, H + 0.08, D + 0.06), "mint")
    lid.span((-W + 0.06, H + 0.08, -D + 0.06), (W - 0.06, H + 0.2, D - 0.04), "cream")
    for (x0, x1, z0, z1) in ((-W - 0.04, W + 0.04, -0.18, 0.18), (-0.18, 0.18, -D - 0.04, D + 0.06)):
        lid.span((x0, H + 0.08, z0), (x1, H + 0.22 + (0.004 if x0 < -1 else 0.0), z1), "blush")
    for (x0, x1, z0, z1) in ((-W - 0.06, -W - 0.04, -0.18, 0.18), (W + 0.04, W + 0.06, -0.18, 0.18),
                             (-0.18, 0.18, -D - 0.06, -D - 0.04), (-0.18, 0.18, D + 0.06, D + 0.08)):
        lid.span((x0, H - 0.02, z0), (x1, H + 0.22, z1), "blush")
    for sx in (-1, 1):
        lid.box((sx * 0.26, H + 0.36, 0.0), (0.44, 0.26, 0.12), "blush", rot=rot_z(sx * 30))
        lid.box((sx * 0.2, H + 0.25, -0.2), (0.1, 0.05, 0.36), "blush", rot=Matrix.Rotation(sx * 0.6, 3, "Y"))
    lid.span((-0.1, H + 0.22, -0.1), (0.1, H + 0.42, 0.1), "nose_pink")


POOLS = {"Alley": alley, "Park": park, "Neighbourhood": neighbourhood, "Woods": woods, "Sewer": sewer,
         "Classic": classic}
# accents a golden crate keeps, so it still reads as its zone's crate
KEEP = {"Alley": ("neon_pink",), "Park": ("bowl_red",), "Neighbourhood": ("pastel_sky", "blush", "bowl_red"),
        "Woods": ("bowl_red", "leaf_green"), "Sewer": ("bowl_red",), "Classic": ("blush", "nose_pink")}


def _gold(pool):
    keep = set(KEEP[pool]) | {PAW[pool]} | set(palette.METAL_SWATCHES)

    def remap(sw):
        if sw in keep:
            return sw
        lum = palette.lstar(sw)
        return "gold_light" if lum > 72 else ("gold_mid" if lum > 48 else "gold_dark")
    return remap


def build_crate(pool, mat, golden=False):
    name = f"CatCafe_Prop_Crate_{pool}" + ("_Gold" if golden else "")
    remap = _gold(pool) if golden else None
    b, lid = RB(remap), RB(remap)
    POOLS[pool](b, lid)
    body = b.finalize(name, mat)
    top = lid.finalize(name + "_Lid", mat)
    top.matrix_world = Matrix.Translation(-Vector(RB.p(*HINGE)))
    bake_transform(top)
    top.location = RB.p(*HINGE)
    return [body, top]


ASSETS = {f"CatCafe_Prop_Crate_{p}{'_Gold' if g else ''}": ((lambda m, p=p, g=g: build_crate(p, m, g)), 1500)
          for p in POOLS for g in (False, True)}
