"""The Cat Cannons (F84, docs/design/cat-cafe/hometown-cannon.md sections 3 and 4). Laid out in Roblox axes through
common.RB, sizes in studs, front -Z.

  CatCafe_Square_Cannon       the hometown cannon at the Town Square's centre, where the fountain stood. Pivot at the
                              plinth's base centre on the square's floor (0, 0.1, 0), placed with no turn, front -Z
                              (south, toward the spawn). The plinth is the fountain's size (radius 6.5 at its step):
                              cream tile with a teal band, a coping with a paw in each area's colour pointing the way
                              the cannon fires to it (Alleyway south-west, Park south, Neighbourhood north, Woods west,
                              Sewer east), two steps up on the south side, and the brass cat statue waving south on
                              its own base on the south-east of the deck. On the deck a fixed base and the turret:
    _Turret                   child Model, pivot on the turntable's top centre (0, 2.53, 0), the barrel at rest
                              pointing +Z (north). Turn it about Y (PivotTo) to face where it fires: a turn of theta
                              degrees points the barrel along (sin theta, 0, cos theta), so 0 north, 180 south, -90
                              west, 90 east, -135 south-west. It carries the turntable, the carriage and its wheels,
                              the barrel (cream, about 10 long, tilted 50 degrees up, teal and gold bands, a teal paw
                              on each side), a hatch on the barrel's top with its lid open, the fuse, and the ladder at
                              the barrel's back (south at rest) with its platform. Attachments in its PrimaryPart:
                              `Muzzle` (the centre of the mouth, UpVector out of the barrel), `Fuse` (the wick's tip,
                              UpVector up) and `Seat` (on the barrel's axis, UpVector along the barrel toward the
                              mouth, LookVector to the hatch: a HumanoidRootPart there lies inside the barrel, head to
                              the mouth, hidden for the ride).
      _Climb                  rides the turret: the ladder's invisible TrussPart.
      _MoonCover              rides the turret: a night-blue cap with a gold crescent and stars, closed over the
                              mouth, pivot at its centre. Hide it by day; at dusk drop it down the barrel's line
                              (pivot from about 3 studs out along the barrel to where it is) and lift it at sunrise.
    _Statue, _Decor           the brass cat and its teal scarf (the scarf does not collide).
  CatCafe_Square_LandingPad   the town's landing pad (LandingPadRadius 8) at the cannon's foot: a big teal paw print
                              with a cream edge, toes toward the cannon (+Z), on a cream disc of radius 8 with a dashed
                              ring round its edge. Pivot at
                              its centre on the floor top, placed at (0, 0.1, -16.5) with no turn (its north edge
                              clears the steps by 1). Flat, walk-on, nothing collides.
  CatCafe_Camp_Cannon_<Area>  each camp's cannon, the same cannon at three quarters size in the area's trim (Alleyway
                              neon pink, Park leaf green, Neighbourhood orange, Woods deep green, Sewer slate blue) on a
                              low round base with one step at its back, no statue. Pivot at the base centre on the
                              camp's floor, front -Z: place it at the camp's back wall with -Z to the wall, so the
                              barrel at rest points +Z out over the area. Same child Models and attachments; the
                              _Turret pivot is 1.49 up.

The camps' own pads are part of the camp sets (camps.py) and use landing_pad() here.
"""

import math

from mathutils import Matrix, Vector

from common import RB, scale_mesh
from plot import rot_y
from square import _paw, _ring, _statue

TILT = math.radians(50)
D = Vector((0, math.sin(TILT), math.cos(TILT)))      # along the barrel, toward the mouth
E = Vector((0, math.cos(TILT), -math.sin(TILT)))     # square to it in the YZ plane, up and back: the barrel's top
X = Vector((1, 0, 0))
TRUNNION = Vector((0, 3.8, 0.2))                     # where the barrel turns on the carriage, turret space
S_BREECH, S_BODY, S_MOUTH = -2.8, 6.4, 7.2           # along the barrel from the trunnion: breech end, body end, mouth
R_BREECH, R_MOUTH = 1.45, 1.25                       # the body tapers between them
S_FUSE, S_HATCH, S_PAW, S_SEAT = -1.75, -0.75, 2.2, 1.2
S_COVER = 7.42                                       # the moon cover's centre
TT_R = 3.5                                           # the turntable
LADDER_Z = -3.3

# the hometown plinth (the fountain's sizes)
STEP_R, DRUM_R, COPING_R, DECK_Y = 6.5, 5.9, 6.1, 1.83
BASE_TOP = 2.13
TURRET_Y = 2.53                                      # the turntable's top, the _Turret pivot
STATUE_AT = (5.0 * math.cos(math.radians(-45)), 5.0 * math.sin(math.radians(-45)))   # south-east on the deck
# the camp cannon at k = 1 before it is scaled down
CAMP_K = 0.75
CAMP_TURRET_Y = 1.98

PAD_R = 8.0
PAD_AT = (0.0, -16.5)                                # the town pad's centre (world x, z)
TRIM = {"Alleyway": "neon_pink", "Park": "paw_park", "Neighbourhood": "paw_neighbourhood", "Woods": "paw_woods",
        "Sewer": "paw_sewer"}
PAWS = (("neon_pink", -1, -1), ("paw_park", 0, -1), ("paw_neighbourhood", 0, 1), ("paw_woods", -1, 0),
        ("paw_sewer", 1, 0))                         # the coping's paws, (swatch, x, z) toward each fire direction
GOLD, BODY = "rarity_legend", "cream"


def _frame(axis, side=X):
    """A Roblox rotation whose Y column is `axis` and whose X column is as close to `side` as it can be."""
    y = Vector(axis).normalized()
    x = (Vector(side) - y * Vector(side).dot(y)).normalized()
    return Matrix((x, y, x.cross(y))).transposed()


def _cyl(rb, c, axis, r, h, swatch, segments=16, r2=None):
    """A cylinder (a cone with r2) of height h along `axis`, centred on c."""
    rb.b.cyl(RB.p(*c), r, h, swatch, segments=segments, bevel=False, rot=RB._rot(_frame(axis)), radius2=r2)


def _washer(rb, c, axis, r, t, h, swatch, segments=16):
    """A ring of outer radius r and width t, h long along `axis`, centred on c."""
    rb.b.ring(RB.p(*c), r, t, h, swatch, segments=segments, bevel=False, rot=RB._rot(_frame(axis)))


def _rod(rb, p0, p1, w, swatch):
    """A square rod w thick from p0 to p1."""
    p0, p1 = Vector(p0), Vector(p1)
    rb.box(tuple((p0 + p1) / 2), (w, (p1 - p0).length + w * 0.6, w), swatch, rot=_frame(p1 - p0))


def at(s):
    """The barrel's axis, s studs from the trunnion toward the mouth."""
    return TRUNNION + D * s


def radius(s):
    return R_BREECH + (R_MOUTH - R_BREECH) * (s - S_BREECH) / (S_BODY - S_BREECH)


def _on_barrel(s, u, lift):
    """A point on the barrel's skin: s along it, u studs round from the top (E) toward +X, `lift` out from the
    skin. Returns (point, outward normal)."""
    r = radius(s)
    a = u / r
    n = E * math.cos(a) + X * math.sin(a)
    return at(s) + n * (r + lift), n


def frame_at(c, R):
    """Blender asset-space 4x4 for an Attachment at Roblox point c with Roblox rotation R (rbx_export.model_json)."""
    C = Matrix(((-1, 0, 0), (0, 0, 1), (0, 1, 0)))
    M = (C.transposed() @ R @ C).to_4x4()
    M.translation = Vector(RB.p(*c))
    return M


# -------------------------------------------------------------------------------------------------- turret --
def _carriage(t, trim):
    """The turntable, the cheeks either side of the barrel and the wheels, in turret space (y 0 = the top)."""
    t.cyl((0, -0.205, 0), TT_R, 0.41, trim, segments=24)                                  # turntable
    t.cyl((0, -0.2, 0), TT_R + 0.06, 0.14, GOLD, segments=24)                             # its gold rim
    for sx in (1, -1):
        x = sx * 1.75
        t.span((x - 0.25, 0, -2.0), (x + 0.25, 2.6, 2.4), trim)                            # cheek
        t.span((x - 0.25, 2.5, -0.8), (x + 0.25, 4.3, 1.2), trim)                          # up to the trunnion
        t.cyl((sx * 1.59, TRUNNION.y, TRUNNION.z), 0.35, 0.78, "brass", axis="X", segments=12)  # the pin
        t.cyl((sx * 2.06, TRUNNION.y, TRUNNION.z), 0.55, 0.14, GOLD, axis="X", segments=14)    # its cap
        for y, z in ((0.5, -1.6), (0.5, 2.0), (2.2, -1.6), (2.2, 2.0)):                     # rivets
            t.cyl((sx * 2.02, y, z), 0.1, 0.06, "brass", axis="X", segments=8)
        wx = sx * 2.3                                                                       # a wheel
        t.cyl((sx * 2.25, 1.46, TRUNNION.z), 0.3, 0.7, "brass", axis="X", segments=10)          # axle into the cheek
        _washer(t, (wx, 1.46, TRUNNION.z), X, 1.45, 0.3, 0.4, "dark_wood", segments=16)           # rim
        t.cyl((wx, 1.46, TRUNNION.z), 1.2, 0.24, "caramel_wood", axis="X", segments=16)        # disc
        for k in range(4):                                                                    # spokes on its face
            t.box((wx + sx * 0.145, 1.46, TRUNNION.z), (0.05, 2.3, 0.2), "dark_wood",
                  rot=Matrix.Rotation(math.radians(45 * k), 3, "X"))
        t.cyl((wx + sx * 0.12, 1.46, TRUNNION.z), 0.36, 0.5, GOLD, axis="X", segments=10)      # hub


def _barrel(t, trim):
    L = S_BODY - S_BREECH
    _cyl(t, at((S_BREECH + S_BODY) / 2), D, R_BREECH, L, BODY, r2=R_MOUTH)                    # the body
    _cyl(t, at(-2.6), D, 1.53, 0.5, trim)                                                     # breech band
    _cyl(t, at(-2.285), D, 1.5, 0.17, GOLD)
    _cyl(t, at(-3.05), D, 0.45, 0.42, GOLD, segments=12)                                      # the knob behind
    t.ball(tuple(at(-3.45)), 0.5, GOLD)
    for s0, s1 in ((4.4, 4.9),):                                                              # a band near the mouth
        r = radius((s0 + s1) / 2) + 0.08
        _cyl(t, at((s0 + s1) / 2), D, r, s1 - s0, trim)
        for s in (s0 - 0.03, s1 + 0.03):
            _cyl(t, at(s), D, r + 0.03, 0.12, GOLD)
    _washer(t, at((S_BODY - 0.05 + S_MOUTH) / 2), D, 1.62, 0.57, S_MOUTH - S_BODY + 0.05, trim)   # the mouth
    _washer(t, at(6.82), D, 1.06, 0.07, 0.72, "fur_black")                                     # dark inside it
    _cyl(t, at(S_BODY + 0.04), D, 1.08, 0.06, "fur_black")                                     # the bore
    _washer(t, at(7.1), D, 1.68, 0.22, 0.24, GOLD)                                             # gold lip
    _washer(t, at(S_BODY + 0.005), D, 1.66, 0.2, 0.14, GOLD)                                   # and the back edge
    for sx in (1, -1):                                                                        # a paw on each side
        for du, dv, r in ((0.0, 0.0, 0.5), (-0.55, 0.5, 0.19), (-0.2, 0.78, 0.19), (0.2, 0.78, 0.19),
                          (0.55, 0.5, 0.19)):
            p, n = _on_barrel(S_PAW + dv, sx * (math.pi / 2) * radius(S_PAW) + du, 0.03)
            _cyl(t, p, n, r, 0.14, trim, segments=12 if r > 0.3 else 8)
    # the hatch on top, its lid hinged on the right and standing open
    rh = radius(S_HATCH)
    _washer(t, at(S_HATCH) + E * rh, E, 0.72, 0.16, 0.5, GOLD)
    _cyl(t, at(S_HATCH) + E * (rh + 0.17), E, 0.58, 0.06, "fur_black")
    hinge = at(S_HATCH) + E * (rh + 0.25) + X * 0.72
    a = math.radians(100)
    radial, normal = -X * math.cos(a) + E * math.sin(a), X * math.sin(a) + E * math.cos(a)
    _cyl(t, hinge + radial * 0.72 + normal * 0.05, normal, 0.72, 0.1, trim)
    _cyl(t, hinge + radial * 0.72 + normal * 0.12, normal, 0.22, 0.06, GOLD, segments=10)       # a knob on it
    _cyl(t, hinge, D, 0.08, 0.5, "brass", segments=8)                                           # the hinge pin
    # the fuse on the barrel's left shoulder: a brass touch hole and a wick curling out
    p, n = _on_barrel(S_FUSE, -radius(S_FUSE) * math.pi / 3, 0.05)
    _cyl(t, p, n, 0.2, 0.3, "brass", segments=10)
    p0 = p + n * 0.13
    pts = [p0, p0 + Vector((0, 0.38, 0)), p0 + Vector((-0.14, 0.62, -0.08)), p0 + Vector((-0.3, 0.72, -0.12))]
    for q0, q1 in zip(pts, pts[1:]):
        _rod(t, q0, q1, 0.11, "treat_tan")
    t.ball(tuple(pts[-1] + Vector((-0.03, 0.02, 0))), 0.08, "fur_orange_dark")
    return pts[-1] + Vector((-0.03, 0.06, 0))


def _ladder(t):
    """The ladder at the barrel's back (-Z) up to a little platform behind the breech."""
    for sx in (1, -1):
        t.span((sx * 0.6 - 0.1, 0, LADDER_Z - 0.1), (sx * 0.6 + 0.1, 4.3, LADDER_Z + 0.1), "caramel_wood")
    for y in (0.55, 1.45, 2.35):
        t.span((-0.5, y - 0.08, LADDER_Z - 0.08), (0.5, y + 0.08, LADDER_Z + 0.08), "caramel_wood")
    t.span((-0.75, 3.2, LADDER_Z - 0.12), (0.75, 3.4, -2.55), "dark_wood")                     # platform
    climb = RB()
    climb.span((-1.0, 0.0, LADDER_Z - 0.15), (1.0, 4.0, LADDER_Z + 1.85), "caramel_wood")      # 2 x 4 x 2 truss
    return climb


def _moon_cover():
    """The night cover, built round its own centre (at(S_COVER))."""
    c = RB()
    _cyl(c, Vector(), D, 1.84, 0.2, "night_sky", segments=20)
    _washer(c, D * -0.22, D, 1.86, 0.14, 0.44, "night_sky", segments=20)
    F = _frame(D)
    face = D * 0.12                                                     # just proud of the cap's front
    n = 9
    for k in range(n):                                                  # the crescent, horns toward +X
        t0 = math.radians(50 + 260 * (k + 0.5) / n)
        w = 0.45 * (0.3 + 0.7 * math.sin(math.pi * (k + 0.5) / n))
        p = face + X * (0.85 * math.cos(t0) - 0.15) + E * (0.85 * math.sin(t0) + 0.1)
        c.box(tuple(p), (math.radians(260) / n * 0.85 * 1.15, 0.04, w), GOLD,
              rot=F @ Matrix.Rotation(t0 + math.pi / 2, 3, "Y"))
    for (u, w, r) in ((0.75, 0.62, 0.22), (1.0, -0.35, 0.16)):
        c.b.star(RB.p(*(face + X * u + E * w)), r, r * 0.42, 0.04, "pastel_butter", rot=RB._rot(F))
    return c


def _turret(mat, base, trim, y):
    t = RB()
    _carriage(t, trim)
    fuse = _barrel(t, trim)
    climb = _ladder(t)
    cover = _moon_cover()
    lift = Vector((0, y, 0))
    cover_at = at(S_COVER)
    objs = [t.finalize(base + "_Turret", mat, location=tuple(lift)),
            climb.finalize(base + "_Climb", mat, location=tuple(lift)),
            cover.finalize(base + "_MoonCover", mat, location=tuple(lift + cover_at))]
    up = Matrix.Identity(3)
    along = _frame(D)
    attachments = [("_Turret", "Muzzle", lift + at(S_MOUTH), along),
                   ("_Turret", "Fuse", lift + fuse, up),
                   ("_Turret", "Seat", lift + at(S_SEAT), along)]
    return objs, attachments


# ------------------------------------------------------------------------------------------- hometown plinth --
def _plinth(b):
    _ring(b, 0.0, 0.35, STEP_R, 0.6, "terracotta", segments=36)                 # step round it
    _ring(b, 0.0, 1.55, DRUM_R, 1.0, "floor_tile", segments=32)                 # the drum
    b.cyl((0, 0.75, 0), DRUM_R - 0.95, 1.5, "floor_tile", segments=24)           # solid inside
    _ring(b, 0.62, 1.22, DRUM_R + 0.06, 0.08, "sign_teal", segments=32)          # tile band on its face
    for k in range(16):                                                         # white diamonds on the band
        a = 2 * math.pi * (k + 0.5) / 16
        b.box(((DRUM_R + 0.07) * math.cos(a), 0.92, (DRUM_R + 0.07) * math.sin(a)), (0.06, 0.3, 0.3), "offwhite",
              rot=rot_y(-math.degrees(a)) @ Matrix.Rotation(math.radians(45), 3, "X"))
    _ring(b, 1.55, 1.85, COPING_R, 1.4, "offwhite", segments=32)                 # coping, a ledge to sit on
    b.cyl((0, (1.5 + DECK_Y) / 2, 0), COPING_R - 1.35, DECK_Y - 1.5, "paving_light", segments=32)   # the deck
    b.cyl((0, (1.8 + BASE_TOP) / 2, 0), 3.75, BASE_TOP - 1.8, "floor_tile", segments=28)      # the turret's base
    b.cyl((0, 1.98, 0), 3.8, 0.1, "sign_teal", segments=28)
    for sw, ux, uz in PAWS:                                                     # a paw toward each fire direction
        n = math.hypot(ux, uz)
        _paw(b, ux / n * 5.4, 1.85, uz / n * 5.4, 0.62, sw, toward=(ux / n, uz / n))
    for x0, x1, z0, top in ((-1.8, 1.8, -7.4, 0.75), (-1.8, 1.8, -6.6, 1.3)):   # two steps up on the south side
        b.span((x0, 0, z0), (x1, top, -5.3), "terracotta")
        b.span((x0 + 0.05, top, z0 + 0.05), (x1 - 0.05, top + 0.02, z0 + 0.2), "offwhite")   # a light nosing


def build_square_cannon(mat):
    base = "CatCafe_Square_Cannon"
    b = RB()
    _plinth(b)
    statue, scarf = RB(), RB()
    statue.cyl((0, (DECK_Y + 2.4) / 2, 0), 0.95, 2.4 - DECK_Y, "floor_tile", segments=14)
    statue.cyl((0, 2.42, 0), 1.0, 0.06, "sign_teal", segments=14)
    _statue(statue, scarf, 2.45)
    sx, sz = STATUE_AT
    turret, attachments = _turret(mat, base, "sign_teal", TURRET_Y)
    objs = [b.finalize(base, mat)] + turret + [statue.finalize(base + "_Statue", mat, location=(sx, 0, sz)),
                                               scarf.finalize(base + "_Decor", mat, location=(sx, 0, sz))]
    ATTACHMENTS[base] = attachments
    return objs


# ------------------------------------------------------------------------------------------------ camp cannon --
def build_camp_cannon(area):
    trim = TRIM[area]

    def build(mat):
        base = "CatCafe_Camp_Cannon_" + area
        b = RB()
        _ring(b, 0.0, 0.35, 5.0, 0.6, "paving_grout", segments=32)             # step
        _ring(b, 0.0, 1.0, 4.4, 0.9, "floor_tile", segments=28)                # drum
        b.cyl((0, 0.475, 0), 3.55, 0.95, "floor_tile", segments=24)
        _ring(b, 0.35, 0.75, 4.46, 0.08, trim, segments=28)                    # band
        _ring(b, 1.0, 1.3, 4.6, 1.0, "offwhite", segments=28)                  # coping
        b.cyl((0, 1.39, 0), 3.75, 0.38, "floor_tile", segments=24)             # the turret's base, top 1.58
        b.cyl((0, 1.45, 0), 3.8, 0.1, trim, segments=24)
        _paw(b, 0, 1.3, 4.0, 0.55, trim, toward=(0, 1))                        # a paw toward the area
        b.span((-1.8, 0, -5.6), (1.8, 0.6, -4.0), "paving_grout")             # the step up at the back
        b.span((-1.75, 0.6, -5.55), (1.75, 0.62, -5.4), "offwhite")
        turret, attachments = _turret(mat, base, trim, CAMP_TURRET_Y)
        objs = [b.finalize(base, mat)] + turret
        for ob in objs:
            ob.location = ob.location * CAMP_K
            scale_mesh(ob, CAMP_K)
        ATTACHMENTS[base] = [(o, n, p * CAMP_K, R) for o, n, p, R in attachments]
        return objs
    return build


# ------------------------------------------------------------------------------------------------ landing pad --
def landing_pad(rb, x, y, z, swatch, edge="offwhite", ground="cream", dashes=24):
    """A landing pad (LandingPadRadius 8) on a floor at height y: a `ground` disc of radius 8 with a dashed ring
    round its edge and a big paw print on it, toes toward +Z, each piece on an edge-coloured rim. Flat, 0.12 high
    at most, so it lies over paving stones and the town's compass (0.06)."""
    rb.cyl((x, y + 0.04, z), PAD_R, 0.08, ground, segments=32)
    pieces = [(0.0, -2.2, 3.8), (-2.3, -3.6, 2.4), (2.3, -3.6, 2.4),
              (-4.5, 2.1, 1.6), (-1.65, 4.75, 1.6), (1.65, 4.75, 1.6), (4.5, 2.1, 1.6)]
    for px, pz, r in pieces:
        rb.cyl((x + px, y + 0.05, z + pz), r + 0.3, 0.1, edge, segments=24 if r > 2 else 16)
        rb.cyl((x + px, y + 0.06, z + pz), r, 0.12, swatch, segments=24 if r > 2 else 16)
    chord = 2 * math.pi * (PAD_R - 0.35) / dashes * 0.55
    for k in range(dashes):
        a = 2 * math.pi * (k + 0.5) / dashes
        rb.box((x + (PAD_R - 0.35) * math.cos(a), y + 0.055, z + (PAD_R - 0.35) * math.sin(a)), (0.4, 0.11, chord),
               edge, rot=rot_y(-math.degrees(a)))


def build_town_pad(mat):
    b = RB()
    landing_pad(b, 0, 0, 0, "sign_teal")
    return [b.finalize("CatCafe_Square_LandingPad", mat)]


ATTACHMENTS = {}          # asset -> [(object suffix, name, Roblox point, Roblox rotation)], filled as they build


def rbx_attachments(name):
    """The (object suffix, Attachment name, Blender asset-space 4x4) list rbx_export wants."""
    return [(o, n, frame_at(p, R)) for o, n, p, R in ATTACHMENTS.get(name, [])]


NEST = {"_Climb": "_Turret", "_MoonCover": "_Turret"}
FIRE_TURNS = {"Alleyway": -135, "Park": 180, "Neighbourhood": 0, "Woods": -90, "Sewer": 90}   # _Turret turn, degrees
PLACEMENTS = {"CatCafe_Square_Cannon": (0, 0.1, 0, 0), "CatCafe_Square_LandingPad": (PAD_AT[0], 0.1, PAD_AT[1], 0)}

ASSETS = {"CatCafe_Square_Cannon": (build_square_cannon, 8000),
          "CatCafe_Square_LandingPad": (build_town_pad, 1500),
          **{"CatCafe_Camp_Cannon_" + a: (build_camp_cannon(a), 6000) for a in TRIM}}
