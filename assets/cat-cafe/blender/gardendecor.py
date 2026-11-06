"""Garden Decor Pack decor (#1852, for Gameplay-Engineer's #1851 and #1168 row 3): six garden pieces that come with the
pass. They are looks only (no cafeMultiplier, not in the Decor Index) and stand on a decor spot like the Cafe Pass
decor (seasondecor.py): 4 studs wide and 2.5 deep at most, pivot base centre, the front toward -Z, no collision.

  CatCafe_Decor_HangingFernBasket    a dark iron shepherd's hook on crossed feet, a woven basket hung from it on three
                                     chains, and a fern spilling out of the basket all round
  CatCafe_Decor_SunflowerPot         a butter yellow pot with an orange sun band, three sunflowers of different
                                     heights turned a little toward the street, two leaves on each stem
  CatCafe_Decor_WateringCanPlanter   an old tin watering can with its long spout and arched handle, full of daisies
                                     and leaves, one daisy leaning out over the rim
  CatCafe_Decor_PottedLemonTree      a white pot with a blue band, a little round tree with bright lemons in it, and a
                                     lemon fallen on the soil
  CatCafe_Decor_IvyTrellis           (furniture) a wooden planter box with a diamond lattice trellis standing in it,
                                     three ivy vines climbing it and leaves trailing over the planter
  CatCafe_Decor_GardenSwingSeat      (furniture) a white A-frame with a wooden swing seat hung on four ropes, a pink
                                     cushion and a cream pillow, flowers and leaves wound along the top beam and down
                                     the front ropes. It doesn't move

Built with RB in Roblox axes (x across, y up, -Z the front).
"""

import math

from mathutils import Matrix, Vector

from common import RB

LEAVES = ("leaf_green", "leaf_dark")
IRON = "fur_ash"


def _rx(deg):
    return Matrix.Rotation(math.radians(deg), 3, "X")


def _ry(deg):
    return Matrix.Rotation(math.radians(deg), 3, "Y")


def _rz(deg):
    return Matrix.Rotation(math.radians(deg), 3, "Z")


def _along(p0, p1):
    """The rotation that turns +Y onto the line p0 -> p1, its length and its middle."""
    d = Vector(p1) - Vector(p0)
    return Vector((0, 1, 0)).rotation_difference(d).to_matrix(), d.length, (Vector(p0) + Vector(p1)) / 2


def _rod(b, p0, p1, r, sw, segments=6):
    """A round rod from p0 to p1."""
    rot, length, mid = _along(p0, p1)
    b.b.cyl(RB.p(*mid), r, length, sw, segments=segments, bevel=False, rot=RB._rot(rot))


def _beam(b, p0, p1, w, sw, d=None):
    """A square beam w by d (default w) from p0 to p1."""
    rot, length, mid = _along(p0, p1)
    b.box(tuple(mid), (w, length, d or w), sw, rot=rot)


def _disc(b, c, r, h, sw, face, segments=10):
    """A flat round disc centred on c, its flat faces along the rotation `face` (whose +Z is the disc's normal)."""
    b.b.cyl(RB.p(*c), r, h, sw, segments=segments, bevel=False, rot=RB._rot(face @ _rx(90)))


def _bloom(b, c, r, petal, middle, face, n=10, second=None):
    """A flower head facing along face's -Z: a round middle and `n` petals round it (a second ring between them in
    `second`, a hair behind)."""
    fwd = face @ Vector((0, 0, -1))
    _disc(b, Vector(c) + fwd * 0.04, r * 0.4, 0.1, middle, face)
    rings = [(0.0, petal, 0.0)] + ([(180 / n, second, 0.04)] if second else [])
    for off, sw, back in rings:
        for k in range(n):
            a = off + 360 * k / n
            loc = face @ Vector((r * 0.68 * math.cos(math.radians(a)), r * 0.68 * math.sin(math.radians(a)), back))
            b.box(tuple(Vector(c) + loc), (r * 0.62, r * 0.26, 0.04), sw, rot=face @ _rz(a))


def _leaf(b, c, s, sw, rot):
    """A flat oval leaf `s` long, lying along rot's +X."""
    b.b.ico(RB.p(*c), s / 2, sw, scale=(1.0, 0.35, 0.12), rot=RB._rot(rot))


def build_hanging_fern_basket(mat):
    b = RB()
    px, pz, bx = -0.85, 0.35, 0.35
    for a in (35, -35):                                                             # crossed feet
        b.box((px, 0.04, pz), (1.2, 0.08, 0.12), IRON, rot=_ry(a))
    b.cyl((px, 0.09, pz), 0.14, 0.06, IRON, segments=8)
    b.cyl((px, 2.32, pz), 0.06, 4.4, IRON, segments=8)                              # the pole
    b.ball((px, 4.56, pz), 0.11, IRON)                                              # its finial
    b.span((px, 4.35, pz - 0.05), (bx + 0.12, 4.45, pz + 0.05), IRON)               # the hook's arm
    _beam(b, (px, 3.85, pz), (px + 0.55, 4.36, pz), 0.07, IRON)                     # its brace
    b.span((bx - 0.03, 4.15, pz - 0.03), (bx + 0.03, 4.35, pz + 0.03), IRON)        # the hook
    yb, yr, R = 2.2, 2.72, 0.55                                                     # the basket
    b.cyl((bx, yb + 0.08, pz), 0.38, 0.16, "caramel_wood", segments=10)
    b.cyl((bx, (yb + 0.12 + yr) / 2, pz), R, yr - yb - 0.12, "caramel_wood", segments=12)
    for y in (2.42, 2.58):                                                          # weave bands
        b.cyl((bx, y, pz), R + 0.02, 0.06, "treat_tan", segments=12)
    b.cyl((bx, yr + 0.04, pz), R + 0.05, 0.08, "dark_wood", segments=12)            # its rim
    b.cyl((bx, yr + 0.09, pz), R - 0.06, 0.02, "choco", segments=12)                # soil
    for k in range(3):                                                              # three chains up to the hook
        a = math.radians(90 + 120 * k)
        _rod(b, (bx + (R - 0.05) * math.cos(a), yr + 0.06, pz + (R - 0.05) * math.sin(a)), (bx, 4.16, pz), 0.025,
             "metal", segments=4)
    # the fern: fronds of three segments out of the soil, the outer ones spilling down over the rim
    for k in range(12):
        yaw = 30 * k + 8
        pitches = (55, 5, -45) if k % 2 == 0 else (40, -15, -65)
        p = Vector((bx, yr + 0.1, pz))
        for j, (pitch, ln) in enumerate(zip(pitches, (0.55, 0.5, 0.45))):
            rot = _ry(yaw) @ _rz(pitch)
            d = rot @ Vector((1, 0, 0))
            b.box(tuple(p + d * ln / 2), (ln, 0.04, 0.3 - 0.06 * j), LEAVES[(k + j) % 2], rot=rot)
            p = p + d * ln * 0.9
    for k in range(5):                                                              # and upright ones in the middle
        rot = _ry(72 * k + 20) @ _rz(72)
        d = rot @ Vector((1, 0, 0))
        b.box(tuple(Vector((bx, yr + 0.1, pz)) + d * 0.32), (0.64, 0.04, 0.2), LEAVES[k % 2], rot=rot)
    return [b.finalize("CatCafe_Decor_HangingFernBasket", mat)]


def build_sunflower_pot(mat):
    b = RB()
    b.cyl((0, 0.45, 0), 0.68, 0.9, "pastel_butter", segments=14)                    # the pot
    b.cyl((0, 0.93, 0), 0.76, 0.16, "offwhite", segments=14)                        # its rim
    b.cyl((0, 1.02, 0), 0.64, 0.02, "choco", segments=12)                           # soil
    for k in range(8):                                                              # a band of little suns
        a = math.radians(45 * k + 90)
        b.box((0.69 * math.cos(a), 0.5, 0.69 * math.sin(a)), (0.16, 0.16, 0.04), "fur_orange",
              rot=_ry(-math.degrees(a) + 90) @ _rz(45))
    for x, z, h, yaw, sw in ((-0.3, 0.12, 2.3, 18, "rarity_legend"), (0.05, -0.12, 2.9, -4, "rarity_legend"),
                             (0.36, 0.18, 1.9, -22, "fur_golden")):
        top = 1.0 + h
        b.cyl((x, 1.0 + h / 2, z), 0.06, h, "leaf_dark", segments=6)                # the stem
        for s, y in ((1, 1.0 + h * 0.38), (-1, 1.0 + h * 0.62)):                    # two leaves
            _leaf(b, (x + s * 0.3, y, z), 0.6, "leaf_green", _rz(s * 25) if s > 0 else _rz(180 - 25))
        face = _ry(yaw) @ _rx(18)
        _bloom(b, (x, top, z), 0.62, sw, "choco", face, n=12, second="fur_orange_dark")
        _disc(b, Vector((x, top, z)) + face @ Vector((0, 0, 0.09)), 0.3, 0.06, "leaf_dark", face)   # its back
    return [b.finalize("CatCafe_Decor_SunflowerPot", mat)]


DAISY = ("offwhite", "rarity_legend")


def build_watering_can_planter(mat):
    b = RB()
    R, H = 0.62, 1.1
    b.cyl((0, H / 2, 0), R, H, "fur_mist", segments=14)                             # the can
    for y in (0.08, H - 0.08):                                                      # its rolled bands
        b.cyl((0, y, 0), R + 0.03, 0.1, "metal", segments=14)
    b.cyl((0, H + 0.01, 0), R - 0.07, 0.02, "choco", segments=12)                   # soil in its open top
    _rod(b, (R - 0.12, 0.28, 0), (1.5, 1.2, 0), 0.08, "fur_mist", segments=8)       # the spout
    _rod(b, (1.42, 1.15, 0), (1.62, 1.31, 0), 0.17, "metal", segments=10)           # and its rose
    handle = ((0.05, H - 0.02), (-0.12, 1.42), (-0.45, 1.55), (-0.75, 1.35), (-0.82, 0.95), (-R + 0.02, 0.6))
    for p0, p1 in zip(handle, handle[1:]):                                          # the arched handle
        _rod(b, (p0[0], p0[1], 0), (p1[0], p1[1], 0), 0.07, "metal", segments=6)
    for k in range(5):                                                              # leaves round the top
        a = 72 * k + 10
        _leaf(b, (0.3 * math.cos(math.radians(a)), H + 0.12, 0.3 * math.sin(math.radians(a))), 0.55,
              LEAVES[k % 2], _ry(-a) @ _rz(20))
    daisies = ((-0.2, 0.55, -0.1, 0, 25), (0.18, 0.75, -0.18, 15, 15), (0.25, 0.45, 0.2, -30, 35),
               (-0.25, 0.7, 0.22, 40, 20), (0.0, 0.95, 0.05, -10, 10))
    for x, h, z, yaw, tilt in daisies:
        top = H + h
        b.cyl((x, H + h / 2, z), 0.035, h, "leaf_dark", segments=5)
        _bloom(b, (x, top, z), 0.3, DAISY[0], DAISY[1], _ry(yaw) @ _rx(tilt), n=10)
    _beam(b, (0.15, H, -0.35), (0.3, H + 0.25, -0.75), 0.05, "leaf_dark")           # one leaning out over the rim
    _bloom(b, (0.31, H + 0.27, -0.79), 0.3, DAISY[0], DAISY[1], _ry(20) @ _rx(-15), n=10)
    return [b.finalize("CatCafe_Decor_WateringCanPlanter", mat)]


def build_potted_lemon_tree(mat):
    b = RB()
    b.cyl((0, 0.48, 0), 0.68, 0.96, "offwhite", segments=14)                        # the pot
    b.cyl((0, 0.72, 0), 0.7, 0.16, "shirt_blue", segments=14)                       # its band
    b.cyl((0, 0.98, 0), 0.78, 0.14, "offwhite", segments=14)                        # its rim
    b.cyl((0, 1.06, 0), 0.66, 0.02, "choco", segments=12)                           # soil
    b.cyl((0, 1.75, 0), 0.1, 1.4, "fur_brown", segments=6)                          # the trunk
    _beam(b, (0, 2.1, 0), (-0.42, 2.5, 0.05), 0.08, "fur_brown")                    # branches
    _beam(b, (0, 2.2, 0), (0.4, 2.55, -0.05), 0.08, "fur_brown")
    canopy = ((0.0, 2.95, 0.0, 0.78), (-0.6, 2.62, 0.08, 0.52), (0.6, 2.66, -0.05, 0.52), (0.15, 3.45, 0.08, 0.5),
              (-0.3, 3.3, -0.25, 0.44))
    for k, (x, y, z, r) in enumerate(canopy):
        b.ball((x, y, z), r, LEAVES[k % 2])
    lemons = ((0, (-0.4, 0.2, -1.0)), (0, (0.5, -0.35, -0.9)), (1, (-0.6, -0.2, -0.8)), (2, (0.7, 0.1, -0.7)),
              (3, (0.1, 0.4, -1.0)), (4, (-0.7, 0.3, -0.5)), (0, (0.9, 0.3, 0.3)), (1, (-0.9, 0.1, 0.4)),
              (2, (0.2, -0.6, -0.8)))
    for i, d in lemons:
        x, y, z, r = canopy[i]
        u = Vector(d).normalized()
        b.ball(tuple(Vector((x, y, z)) + u * (r - 0.02)), 0.15, "rarity_legend", scale=(1.0, 0.85, 1.3))
    b.ball((0.35, 1.18, -0.3), 0.15, "rarity_legend", scale=(1.3, 0.85, 1.0))       # one fallen on the soil
    return [b.finalize("CatCafe_Decor_PottedLemonTree", mat)]


def _diagonals(b, x0, x1, y0, y1, z, slope, step, sw):
    """Slats along lines y = slope * x + c across the rectangle, `step` apart (measured across them)."""
    gap = step * math.sqrt(2)
    c = (y0 - slope * x1) if slope > 0 else (y0 - slope * x0)
    c_end = (y1 - slope * x0) if slope > 0 else (y1 - slope * x1)
    c += gap / 2
    while c < c_end:
        pts = []
        for x in (x0, x1):                                                          # where the line meets each side
            y = slope * x + c
            if y0 <= y <= y1:
                pts.append((x, y))
        for y in (y0, y1):
            x = (y - c) / slope
            if x0 < x < x1:
                pts.append((x, y))
        if len(pts) >= 2:
            (ax, ay), (bx, by) = sorted(pts)[0], sorted(pts)[-1]
            if math.hypot(bx - ax, by - ay) > 0.2:
                _beam(b, (ax, ay, z), (bx, by, z), 0.08, sw, d=0.05)
        c += gap


def build_ivy_trellis(mat):
    b = RB()
    W, D = 3.2, 0.9                                                                 # the planter box
    b.span((-W / 2, 0, -D / 2), (W / 2, 0.72, D / 2), "caramel_wood")
    b.span((-W / 2 - 0.08, 0.72, -D / 2 - 0.07), (W / 2 + 0.08, 0.84, D / 2 + 0.07), "dark_wood")   # its rim
    for x in (-W / 2 + 0.8, 0.0, W / 2 - 0.8):                                      # battens on its front
        b.span((x - 0.06, 0.04, -D / 2 - 0.04), (x + 0.06, 0.72, -D / 2), "dark_wood")
    b.span((-W / 2 + 0.1, 0.84, -D / 2 + 0.1), (W / 2 - 0.1, 0.87, D / 2 - 0.1), "choco")          # soil
    zt, xp, top = 0.15, 1.45, 3.92                                                  # the trellis frame
    for x in (-xp, xp):
        b.span((x - 0.07, 0.87, zt - 0.07), (x + 0.07, top, zt + 0.07), "caramel_wood")
    b.span((-xp - 0.1, top - 0.12, zt - 0.08), (xp + 0.1, top, zt + 0.08), "caramel_wood")
    lx0, lx1, ly0, ly1 = -xp + 0.07, xp - 0.07, 0.87, top - 0.12
    _diagonals(b, lx0, lx1, ly0, ly1, zt - 0.03, 1, 0.42, "caramel_wood")           # the lattice, two layers
    _diagonals(b, lx0, lx1, ly0, ly1, zt + 0.03, -1, 0.42, "caramel_wood")
    vines = (((-1.1, 0.87), (-0.7, 1.6), (-1.0, 2.3), (-0.6, 3.0), (-0.9, 3.6)),
             ((0.2, 0.87), (0.5, 1.5), (0.1, 2.2), (0.45, 2.8)),
             ((1.1, 0.87), (0.8, 1.4), (1.15, 2.0), (0.9, 2.6), (1.2, 3.3), (0.85, 3.72)))
    zv = zt - 0.1                                                                   # just in front of the lattice
    k = 0
    for vine in vines:
        for (ax, ay), (bx, by) in zip(vine, vine[1:]):
            _rod(b, (ax, ay, zv), (bx, by, zv), 0.03, "leaf_dark", segments=4)
            n = max(2, int(math.hypot(bx - ax, by - ay) / 0.3))
            for j in range(n):
                t = (j + 0.5) / n
                x, y = ax + (bx - ax) * t, ay + (by - ay) * t
                s = 1 if k % 2 else -1
                b.box((x + s * 0.12, y, zv - 0.02), (0.26, 0.2, 0.04), LEAVES[k % 2], rot=_rz(s * 35 + 10 * (k % 3)))
                k += 1
    for j, x in enumerate((-1.3, -0.55, 0.35, 1.0)):                                # trailing over the planter
        for i in range(2 + j % 2):
            b.box((x + 0.06 * (i % 2), 0.72 - 0.22 * i, -D / 2 - 0.11), (0.24, 0.2, 0.04), LEAVES[(i + j) % 2],
                  rot=_rz(30 if i % 2 else -30))
    return [b.finalize("CatCafe_Decor_IvyTrellis", mat)]


BLOOMS = ("apron_pink", "rarity_legend", "offwhite", "pastel_lilac", "blush")


def _flat_flower(b, x, y, z, r, sw):
    """A small flat flower facing -Z: five round petals and a yellow middle."""
    for k in range(5):
        a = math.radians(72 * k + 90)
        b.cyl((x + 0.55 * r * math.cos(a), y + 0.55 * r * math.sin(a), z), 0.45 * r, 0.05, sw, axis="Z", segments=6)
    b.cyl((x, y, z - 0.04), 0.3 * r, 0.04, "rarity_legend" if sw != "rarity_legend" else "fur_orange", axis="Z",
          segments=6)


def build_garden_swing_seat(mat):
    b = RB()
    X, AY, ZL = 1.8, 3.4, 0.95                                                      # the white A-frame
    for x in (-X, X):
        for z in (-ZL, ZL):
            _beam(b, (x, 0.1, z), (x, AY, 0), 0.16, "offwhite")
            b.span((x - 0.11, 0, z - 0.13), (x + 0.11, 0.14, z + 0.13), "offwhite")           # its foot
        b.span((x - 0.07, 0.95, -0.68), (x + 0.07, 1.07, 0.68), "offwhite")         # its cross brace
    b.span((-X - 0.15, AY - 0.2, -0.1), (X + 0.15, AY, 0.1), "offwhite")            # the top beam
    xs, yf, yb, zf, zb = 1.25, 1.0, 1.85, -0.4, 0.42                                # the seat
    for k in range(4):                                                              # seat slats
        z = zf + 0.04 + k * 0.2
        b.span((-xs - 0.05, yf - 0.06, z), (xs + 0.05, yf + 0.02, z + 0.16), "caramel_wood")
    for x in (-xs, xs):                                                             # back posts and arms
        b.span((x - 0.06, yf - 0.06, zb - 0.06), (x + 0.06, yb, zb + 0.06), "caramel_wood")
        b.span((x - 0.06, yf + 0.35, zf), (x + 0.06, yf + 0.45, zb), "caramel_wood")
        b.span((x - 0.05, yf + 0.02, zf + 0.02), (x + 0.05, yf + 0.35, zf + 0.12), "caramel_wood")
    for y in (1.3, 1.55, 1.78):                                                     # backrest slats
        b.span((-xs + 0.06, y - 0.07, zb - 0.04), (xs - 0.06, y + 0.07, zb + 0.04), "caramel_wood")
    b.span((-xs + 0.1, yf + 0.02, zf + 0.04), (xs - 0.1, yf + 0.18, zb - 0.06), "apron_pink")      # the cushion
    b.ball((-0.7, 1.42, zb - 0.2), 0.3, "cream", scale=(1.0, 0.95, 0.45))           # and a pillow
    for x in (-xs, xs):                                                             # four ropes up to the beam
        _rod(b, (x, yf + 0.4, zf + 0.07), (x, AY - 0.2, -0.05), 0.035, "treat_tan", segments=5)
        _rod(b, (x, yb, zb), (x, AY - 0.2, 0.05), 0.035, "treat_tan", segments=5)
    k = 0                                                                           # flowers along the top beam
    for i in range(9):
        x = -X + 0.2 + i * (2 * X - 0.4) / 8
        b.ball((x, AY + 0.02, -0.02), 0.2, LEAVES[i % 2], scale=(1.4, 0.7, 1.0))
        if i % 2 == 0:
            _flat_flower(b, x + 0.1, AY - 0.1, -0.16, 0.2, BLOOMS[k % len(BLOOMS)])
            k += 1
    for x in (-xs, xs):                                                             # and wound down the front ropes
        for j in range(4):
            t = (j + 0.5) / 4
            y = yf + 0.4 + (AY - 0.2 - yf - 0.4) * t
            z = zf + 0.07 + (-0.05 - zf - 0.07) * t
            s = 1 if j % 2 else -1
            b.box((x + s * 0.09, y, z - 0.03), (0.2, 0.16, 0.04), LEAVES[j % 2], rot=_rz(s * 40))
            if j % 2 == 0:
                _flat_flower(b, x - s * 0.1, y + 0.12, z - 0.07, 0.16, BLOOMS[k % len(BLOOMS)])
                k += 1
    return [b.finalize("CatCafe_Decor_GardenSwingSeat", mat)]


ASSETS = {
    "CatCafe_Decor_HangingFernBasket": (build_hanging_fern_basket, 1500),
    "CatCafe_Decor_SunflowerPot": (build_sunflower_pot, 2000),
    "CatCafe_Decor_WateringCanPlanter": (build_watering_can_planter, 2000),
    "CatCafe_Decor_PottedLemonTree": (build_potted_lemon_tree, 1500),
    "CatCafe_Decor_IvyTrellis": (build_ivy_trellis, 2000),
    "CatCafe_Decor_GardenSwingSeat": (build_garden_swing_seat, 2000),
}
