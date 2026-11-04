"""Themed cats' props (data-model sections 3a to 3c): every Rare-and-up cat wears one prop, baked into all four of its
models (walking, sitting and the gold twins) as its own object, `CatCafe_Cat_<Name>[_Gold][_Sit]_Prop`, plus
`..._Prop_Glass` for clear parts (lenses, bubbles, a jar, a helmet; Glass in Roblox, left out of the Cycles
previews). The model's PropSlot attribute names the slot, and CatPose.dress leaves the role outfit piece in that slot
off (Catalog.outfitPieceSlots): a Head prop replaces the role hat, a Back prop the Entertainer's cape, and a Face prop
clashes with nothing. A few cats wear a second prop in another slot (PROPS2, v0.13): `..._Prop2`, slot in PropSlot2.

  Head  on top of the head, between and over the ears (they poke through hats, as with the role hats)
  Face  on the face, around the eyes or at the mouth
  Back  on the back: lying along A's back, against B's upright back, clear of the role vests and aprons

Head and Face props ride the Head: the object is pivoted at the neck like the Head, and the Roblox model nests it in
the Head Model, so a head turn carries it. Back props ride the Body. Each prop is drawn once in its slot's own space
(Frame) and lands on either body:
  head   origin on the head top centre, x the cat's left, y back, z up, in units of B's head (0.92 wide)
  face   origin on the face plane at eye height, y negative out of the face, in units of B's face
  back   origin on the middle of the back: on A the top of the body (along +y to the tail, out +z), on B the back of
         the chest (along runs down it, out is backwards)
  up     the same spot with the world's axes, for things that stand up (wings, a jar)
"""

import math

from mathutils import Matrix, Vector

import cats
import gold
from common import Builder

B_BACK_Y = cats.B_CHEST_C[1] + cats.B_CHEST_S[1] / 2      # the back face of B's chest
B_BACK_Z = 0.8                                           # the middle of B's back, above the haunches (0.56)


def _rx(deg):
    return Matrix.Rotation(math.radians(deg), 3, "X")


def _ry(deg):
    return Matrix.Rotation(math.radians(deg), 3, "Y")


def _rz(deg):
    return Matrix.Rotation(math.radians(deg), 3, "Z")


class Pen:
    """Builder primitives drawn in a slot frame: point p lands at T @ R @ (s * p), sizes scale by s."""

    def __init__(self, b, at, R, s):
        self.b, self.at, self.R, self.s = b, Vector(at), R, s

    def p(self, c):
        return tuple(self.at + self.R @ (Vector(c) * self.s))

    def _r(self, rot):
        return self.R @ rot if rot is not None else self.R.copy()

    def box(self, c, size, sw, rot=None, bevel=False):
        self.b.box(self.p(c), tuple(v * self.s for v in size), sw, bevel=bevel, rot=self._r(rot))

    def cyl(self, c, r, h, sw, rot=None, r2=None, segments=12, bevel=False):
        self.b.cyl(self.p(c), r * self.s, h * self.s, sw, segments=segments, bevel=bevel, rot=self._r(rot),
                   radius2=None if r2 is None else r2 * self.s)

    def sphere(self, c, r, sw, scale=(1, 1, 1), rot=None, segments=10, rings=6):
        self.b.sphere(self.p(c), r * self.s, sw, segments=segments, rings=rings, scale=scale, rot=self._r(rot))

    def ico(self, c, r, sw, scale=(1, 1, 1), rot=None):
        self.b.ico(self.p(c), r * self.s, sw, scale=scale, rot=self._r(rot))

    def pyramid(self, c, size, h, sw, rot=None):
        """Square pyramid centred on c (the Builder's pyramid turns about its middle)."""
        x, y, z = self.p(c)
        self.b.pyramid((x, y, z - h * self.s / 2), size * self.s, h * self.s, sw, rot=self._r(rot))

    def ring(self, c, r, t, h, sw, rot=None, segments=12):
        self.b.ring(self.p(c), r * self.s, t * self.s, h * self.s, sw, segments=segments, bevel=False, rot=self._r(rot))

    def star(self, c, outer, inner, h, sw, rot=None):
        self.b.star(self.p(c), outer * self.s, inner * self.s, h * self.s, sw, rot=self._r(rot))

    def fan(self, c, apex, chain, h, sw, rot=None):
        s = self.s
        self.b.fan(self.p(c), (apex[0] * s, apex[1] * s), [(x * s, y * s) for x, y in chain], h * s, sw, rot=self._r(rot))

    def bar(self, a, b, w, t, sw, up=(0, 0, 1)):
        """A strap or rod from point a to point b: width w across, thickness t along `up` (frame units)."""
        a, b = Vector(a), Vector(b)
        d = b - a
        y = d.normalized()
        z = Vector(up)
        z = (z - y * z.dot(y)).normalized()
        x = y.cross(z)
        R = Matrix((x, y, z)).transposed()
        self.box(tuple((a + b) / 2), (w, d.length, t), sw, rot=R)


class Ctx:
    """One prop drawing on one body: pens per frame on the prop's Builder and on its glass Builder, and the head's
    sizes in each frame's units."""

    def __init__(self, spec, body, d):
        self.body, self.spec, self.d = body, spec, d
        self.work = False               # body S (the working pose) draws on B's frames; set by build
        self.main, self.glass = Builder(), Builder()
        self.origin = Vector((0.0, 0.0, 0.0))        # the object's pivot in the ridden piece's space (pivot_at)
        self.extra = {}                              # suffix -> (Builder, pivot), extra objects (piece)
        h = d["head"]
        self.h = h
        hs, kf = h["s"][0] / 0.92, h["k"] / 1.05
        self._frames = {"head": ((0, h["c"][1], h["top"]), Matrix.Identity(3), hs),
                        "face": ((0, h["fy"], h["fz"]), Matrix.Identity(3), kf)}
        if body == "walk":
            (x0, y0, z0), (sx, sy, sz) = d["body"]
            self.back_len, self.back_w = sy, sx
            self._frames["back"] = ((0, y0, z0 + sz / 2), Matrix.Identity(3), 1.0)
            self._frames["up"] = ((0, y0 - sy * 0.22, z0 + sz / 2), Matrix.Identity(3), 1.0)
        else:
            self.back_len, self.back_w = cats.B_CHEST_S[2], cats.B_CHEST_S[0]
            self._frames["back"] = ((0, B_BACK_Y, B_BACK_Z), _rx(-90), 1.0)
            self._frames["up"] = ((0, B_BACK_Y, 0.98), Matrix.Identity(3), 1.0)
        # the head in head-frame units (B: 0.46 half width, 0.37 to the front and back, 0.76 deep)
        self.hw, self.hd, self.hh = h["s"][0] / 2 / hs, h["s"][1] / 2 / hs, h["s"][2] / hs
        self.ear_x = h["ear_x"] / hs
        # the face in face-frame units: half width, depth to the back of the head, top and bottom, eyes
        self.fw, self.fd = h["s"][0] / 2 / kf, h["s"][1] / kf
        self.ftop, self.fbot = (h["top"] - h["fz"]) / kf, (h["c"][2] - h["s"][2] / 2 - h["fz"]) / kf
        self.eye_x = h["eye_dx"] * h["k"] / kf
        self.eye_hw, self.eye_hh = 0.1 * h["k"] / kf, cats.EYE_H / 2 * h["k"] / kf
        self.mouth_z = -0.2 * h["k"] / kf
        if body == "sit":
            (hx0, hy0, _hz0), (hsx, hsy, hsz) = d["haunch"]
            self.haunch_back, self.haunch_top = hy0 + hsy / 2, hsz

    def pen(self, frame):
        at, R, s = self._frames[frame]
        return Pen(self.main, Vector(at) - self.origin, R, s)

    def gpen(self, frame):
        at, R, s = self._frames[frame]
        return Pen(self.glass, Vector(at) - self.origin, R, s)

    def point(self, frame, c):
        """Point c of `frame` in the space of the piece the prop rides (the neck for Head and Face props)."""
        at, R, s = self._frames[frame]
        return Vector(at) + R @ (Vector(c) * s)

    def pivot_at(self, frame, c):
        """Pivot the prop's object at point c of `frame` (a hinge the animations turn it about) instead of at the
        joint it rides. Call before drawing."""
        assert not self.main.prims and not self.glass.prims, "pivot_at goes before the first primitive"
        self.origin = self.point(frame, c)

    def piece(self, suffix, frame, c):
        """A Pen for an extra object of this prop, `<name>_<suffix>`, pivoted at point c of `frame` (a bell that
        swings from it). It rides what the prop rides; PIECES names its host for the Roblox nesting."""
        at = self.point(frame, c)
        b = Builder()
        self.extra[suffix] = (b, at)
        _, R, s = self._frames[frame]
        return Pen(b, Vector(self._frames[frame][0]) - at, R, s)

    def back_frame_offset(self):
        """Back props are in the Body's space (pivot at the model origin), head props relative to the neck."""
        return self._frames["back"][0]


def _strap_round(ctx, sw, at_y=0.0):
    """A strap round A's body at y = at_y (back frame): down both flanks and under the belly."""
    P = ctx.pen("back")
    (x0, y0, zc), (sx, sy, sz) = ctx.d["body"]
    hx = sx / 2
    belly = -(sz)                                       # back-frame z of the belly
    for side in (-1, 1):                                # 0.01 into the fur, out past the coat patches
        P.box((side * (hx + 0.015), at_y, belly / 2), (0.05, 0.08, sz - 0.02), sw)
    P.box((0, at_y, belly - 0.015), (sx - 0.02, 0.08, 0.05), sw)


# ------------------------------------------------------------------------------------------------- Head --
def _brim(P, r, z, sw, h=0.04, scale=(1, 1, 1), segments=12):
    P.cyl((0, 0, z), r, h, sw, segments=segments, rot=None)


def headphones(ctx):
    """Sphynx, DJ Cat: a band over the head in front of the ears and big cups on the sides, neon trims."""
    P, w = ctx.pen("head"), ctx.hw
    y = -0.2
    pts = [(w + 0.06, -0.36), (w + 0.06, -0.06), (w - 0.06, 0.07), (-(w - 0.06), 0.07), (-(w + 0.06), -0.06),
           (-(w + 0.06), -0.36)]
    for (xa, za), (xb, zb) in zip(pts, pts[1:]):
        P.bar((xa, y, za), (xb, y, zb), 0.07, 0.1, "fur_black", up=(0, 1, 0))
    for sx in (-1, 1):
        P.cyl((sx * (w + 0.06), y, -0.4), 0.18, 0.14, "fur_black", rot=_ry(90))
        P.cyl((sx * (w + 0.145), y, -0.4), 0.12, 0.03, "neon_pink", rot=_ry(90))
        P.cyl((sx * (w + 0.165), y, -0.4), 0.05, 0.03, "sign_teal", rot=_ry(90), segments=8)
    P.box((0, y, 0.115), (0.3, 0.06, 0.03), "sign_teal")


def ninja_band(ctx):
    """Void, Ninja Cat: a red band round the brow with a metal plate, knotted at the back with two trailing tails."""
    P, w, d = ctx.pen("head"), ctx.hw, ctx.hd
    z, hgt = -0.16, 0.12
    P.box((0, -(d + 0.015), z), (2 * w + 0.05, 0.04, hgt), "shirt_red")
    P.box((0, d + 0.015, z), (2 * w + 0.05, 0.04, hgt), "shirt_red")
    for sx in (-1, 1):
        P.box((sx * (w + 0.015), 0, z), (0.04, 2 * d + 0.06, hgt + 0.004), "shirt_red")
    P.box((0, -(d + 0.04), z), (0.26, 0.02, 0.09), "metal")
    P.box((0, -(d + 0.052), z), (0.12, 0.012, 0.025), "fur_black")
    P.box((0, d + 0.06, z), (0.13, 0.08, 0.13), "shirt_red")
    for sx in (-1, 1):
        P.bar((sx * 0.04, d + 0.08, z - 0.02), (sx * 0.2, d + 0.36, z - 0.24), 0.09, 0.03, "shirt_red", up=(0, 1, 1))


def wizard_hat(ctx):
    """Midnight, Wizard Cat: a tall violet cone with a bent tip, a gold band and stars, on a wide brim."""
    P = ctx.pen("head")
    P.cyl((0, 0, 0.005), 0.44, 0.05, "aurora_violet", segments=14)
    h1 = 0.55
    P.cyl((0, 0, 0.03 + h1 / 2), 0.28, h1, "aurora_violet", r2=0.1)
    P.cyl((0, 0, 0.075), 0.29, 0.07, "rarity_legend")
    tip = Vector((0, 0, 0.03 + h1))
    d = _rx(-35) @ Vector((0, 0, 1))
    P.cyl(tuple(tip + d * 0.14), 0.1, 0.3, "aurora_violet", r2=0.0, rot=_rx(-35), segments=10)
    P.ico(tuple(tip + d * 0.3), 0.05, "sparkle")
    slope = math.degrees(math.atan2(0.18, h1))
    for az, z in ((-20, 0.24), (35, 0.42), (-60, 0.48), (160, 0.3)):
        r = 0.28 - (0.18 * (z - 0.03) / h1)
        R = _rz(az) @ _rx(90 - slope)
        P.star(tuple(_rz(az) @ Vector((0, -(r + 0.006), z))), 0.07, 0.03, 0.025, "sparkle", rot=R)


def safari_hat(ctx):
    """Bengal, Explorer Cat: a cream pith helmet with a brown band and a button on top."""
    P = ctx.pen("head")
    P.sphere((0, 0.01, 0.0), 0.33, "cream", scale=(1, 1.08, 0.82), segments=12, rings=6)
    P.cyl((0, 0.01, 0.03), 0.47, 0.04, "cream", segments=14)
    P.cyl((0, 0.01, 0.08), 0.335, 0.06, "dark_wood", segments=12)
    P.cyl((0, 0.01, 0.275), 0.05, 0.04, "dark_wood", segments=8)


def nightcap(ctx):
    """Ragdoll, Sleepy Cat: a lilac nightcap flopping over to the left, cream cuff and pom-pom."""
    P = ctx.pen("head")
    P.cyl((0, 0, 0.03), 0.33, 0.09, "offwhite", segments=12)
    at, a = Vector((0, 0, 0.07)), 0.0
    for r1, r2, hgt, turn in ((0.3, 0.21, 0.26, 18), (0.21, 0.12, 0.24, 60), (0.12, 0.04, 0.22, 70)):
        R = _ry(a + turn / 2)
        d = R @ Vector((0, 0, 1))
        P.cyl(tuple(at + d * hgt / 2), r1, hgt, "pastel_lilac", r2=r2, rot=R, segments=10)
        at, a = at + d * (hgt - 0.02), a + turn
    P.ico(tuple(at + _ry(a) @ Vector((0, 0, 0.04))), 0.09, "offwhite")


def top_hat(ctx):
    """Persian, Fancy Cat: a black top hat with a blush band, and a gold monocle on the left eye."""
    P = ctx.pen("head")
    P.cyl((0, 0, 0.005), 0.34, 0.05, "fur_black", segments=14)
    P.cyl((0, 0, 0.24), 0.24, 0.44, "fur_black", segments=12)
    P.cyl((0, 0, 0.08), 0.245, 0.08, "blush", segments=12)
    F = ctx.pen("face")
    F.ring((ctx.eye_x, -0.095, 0.0), 0.18, 0.035, 0.03, "rarity_legend", rot=_rx(90), segments=12)
    F.bar((ctx.eye_x + 0.1, -0.09, -0.15), (ctx.eye_x + 0.16, -0.06, -0.38), 0.03, 0.03, "rarity_legend", up=(0, -1, 0))


def bubble_helmet(ctx):
    """Aurora, Astro Cat: a glass bubble round the whole head, ears and all, on a white collar with mint lights."""
    P, G = ctx.pen("head"), ctx.gpen("head")
    cz = -ctx.hh / 2 + 0.1 + (0.11 if ctx.work else 0.0)     # S: up off the shoulders so the arms clear the collar
    G.sphere((0, -0.03, cz), 0.73, "glass", segments=14, rings=8)
    zc = cz - math.sqrt(0.73 ** 2 - 0.52 ** 2)
    P.ring((0, -0.03, zc), 0.56, 0.1, 0.12, "offwhite", segments=14)
    for az in (-25, 0, 25):
        P.box(tuple(_rz(az) @ Vector((0, -0.57, zc + 0.01)) + Vector((0, -0.03, 0))), (0.07, 0.04, 0.05), "mint", rot=_rz(az))


def beret(ctx):
    """Fold, Painter Cat: a red beret tipped to the left with a stalk, splashed with teal and butter paint."""
    P = ctx.pen("head")
    R = _ry(12)
    o = Vector((0.04, 0.0, 0.05))

    def at(u, v, w):
        return tuple(o + R @ Vector((u, v, w)))
    P.cyl(at(0, 0, 0), 0.38, 0.1, "bowl_red", rot=R, r2=0.33, segments=14)
    P.cyl(at(0, 0, 0.075), 0.31, 0.05, "bowl_red", rot=R, r2=0.22, segments=12)
    P.cyl(at(0, 0, 0.13), 0.03, 0.08, "bowl_red", rot=R, segments=6)
    for (u, v, rr, sw) in ((-0.1, -0.08, 0.07, "sign_teal"), (0.1, 0.07, 0.06, "pastel_butter"), (-0.04, 0.12, 0.045, "sign_teal")):
        P.cyl(at(u, v, 0.106), rr, 0.02, sw, rot=R, segments=8)
    P.box(at(0.22, -0.26, -0.04), (0.06, 0.05, 0.14), "pastel_butter", rot=R)       # a drip off the edge


def chef_hat(ctx):
    """Chonk, Chef Cat: a tall white toque, a band and a puffy top."""
    P = ctx.pen("head")
    P.cyl((0, 0, 0.06), 0.3, 0.14, "offwhite", segments=12)
    P.cyl((0, 0, 0.27), 0.27, 0.3, "milk", segments=12, r2=0.3)
    for (x, y) in ((0.14, 0.0), (-0.14, 0.0), (0.0, 0.14), (0.0, -0.14), (0.0, 0.0)):
        P.ico((x, y, 0.45 + (0.05 if x == y == 0 else 0)), 0.17, "milk")


def mail_cap(ctx):
    """Postie, Mail Cat: a navy carrier's cap with a black peak and an envelope badge."""
    P = ctx.pen("head")
    P.cyl((0, 0, 0.07), 0.31, 0.16, "pants_navy", segments=12)
    P.cyl((0, 0.02, 0.175), 0.35, 0.06, "pants_navy", segments=14)
    P.cyl((0, 0, 0.02), 0.315, 0.04, "fur_black", segments=12)
    P.box((0, -0.36, 0.02), (0.44, 0.2, 0.035), "fur_black", rot=_rx(14))
    P.box((0, -0.312, 0.1), (0.15, 0.03, 0.1), "offwhite")
    P.box((0, -0.33, 0.115), (0.11, 0.012, 0.05), "pants_navy", rot=_ry(45))
    P.box((0.045, -0.336, 0.075), (0.035, 0.012, 0.035), "bowl_red")


def ice_cream_hat(ctx):
    """Comet, Ice Cream Cat: a waffle cone upside down on the head, a strawberry scoop squashed under it dripping
    onto the fur, sprinkles and a cherry on the tip."""
    P = ctx.pen("head")
    P.sphere((0, 0, 0.04), 0.34, "fur_strawberry", scale=(1, 1, 0.5), segments=12, rings=6)
    for (x, y, z) in ((0.27, -0.2, 0.0), (-0.22, -0.26, -0.01), (0.05, -0.32, -0.02)):
        P.ico((x, y, z), 0.075, "fur_strawberry", scale=(1, 1, 1.4))
    P.cyl((0, 0, 0.38), 0.25, 0.5, "treat_tan", r2=0.03, segments=10)
    for z, r in ((0.24, 0.198), (0.42, 0.13)):
        P.cyl((0, 0, z), r + 0.012, 0.035, "kibble", segments=10)
    cols = ctx.spec.get("sprinkles", ("neon_pink", "sign_teal"))
    for i, az in enumerate((20, 100, 170, 250, 320)):
        R = _rz(az)
        P.box(tuple(R @ Vector((0, -0.325, 0.09))), (0.09, 0.035, 0.035), cols[i % len(cols)], rot=R @ _ry(30 * (-1) ** i))
    P.ico((0, 0, 0.67), 0.09, "bowl_red")
    P.bar((0, 0, 0.74), (0.05, 0.02, 0.86), 0.025, 0.025, "leaf_dark")


def plaid_cap(ctx):
    """ForestCat, Lumberjack Cat: a red and black plaid cap with a peak and ear flaps down the sides."""
    P, w = ctx.pen("head"), ctx.hw
    P.cyl((0, 0, 0.09), 0.33, 0.2, "shirt_red", r2=0.29, segments=12)
    for z in (0.05, 0.13):
        P.cyl((0, 0, z), 0.322 - z * 0.12, 0.035, "fur_black", segments=12)
    for az in (0, 45, 90, 135):
        R = _rz(az)
        for sgn in (1, -1):
            P.box(tuple(R @ Vector((0, sgn * 0.312, 0.09))), (0.035, 0.03, 0.2), "fur_black", rot=R @ _rx(sgn * 11))
    P.box((0, -0.38, 0.03), (0.42, 0.18, 0.035), "shirt_red", rot=_rx(12))
    for sx in (-1, 1):
        P.box((sx * (w + 0.02), -0.02, -0.13), (0.045, 0.24, 0.28), "shirt_red")
        P.box((sx * (w + 0.047), -0.02, -0.13), (0.012, 0.24, 0.04), "fur_black")
        P.box((sx * (w + 0.02), -0.02, 0.0), (0.055, 0.25, 0.05), "fur_black")


def mushroom_cap(ctx):
    """Toadstool, Mushroom Cat: a wide red toadstool cap in three steps with cream gills and white spots."""
    P = ctx.pen("head")
    P.cyl((0, 0, 0.0), 0.49, 0.04, "cream", segments=14)
    P.cyl((0, 0, 0.07), 0.52, 0.1, "bowl_red", r2=0.45, segments=14)
    P.cyl((0, 0, 0.17), 0.45, 0.1, "bowl_red", r2=0.31, segments=14)
    P.cyl((0, 0, 0.255), 0.31, 0.07, "bowl_red", r2=0.0, segments=14)
    for (az, rad, z, r) in ((-30, 0.49, 0.07, 0.07), (60, 0.48, 0.08, 0.06), (150, 0.49, 0.07, 0.07), (230, 0.48, 0.08, 0.06),
                            (300, 0.48, 0.07, 0.05), (10, 0.37, 0.18, 0.06), (120, 0.38, 0.17, 0.05), (220, 0.37, 0.18, 0.06),
                            (0, 0.0, 0.29, 0.07)):
        P.ico(tuple(_rz(az) @ Vector((0, -rad, z))), r, "offwhite", scale=(1, 1, 0.7))


def antlers(ctx):
    """OldOak, Antler Cat: two branching antlers with moss at the base and tiny flowers on the tines."""
    P = ctx.pen("head")
    for sx in (-1, 1):
        base = Vector((sx * 0.13, -0.08, -0.02))
        top = base + Vector((sx * 0.12, 0.06, 0.38))
        P.bar(tuple(base), tuple(top), 0.08, 0.08, "caramel_wood", up=(0, 1, 0))
        for f, end in ((0.45, Vector((sx * 0.13, -0.1, 0.12))), (0.8, Vector((sx * 0.02, -0.02, 0.16))),
                       (1.0, Vector((sx * 0.12, 0.08, 0.12)))):
            a = base + (top - base) * f
            P.bar(tuple(a), tuple(a + end), 0.06, 0.06, "caramel_wood", up=(0, 1, 0))
            P.box(tuple(a + end), (0.075, 0.075, 0.075), ("blush", "pastel_butter", "offwhite")[int(f * 2) % 3], rot=_rz(45))
        P.ico(tuple(base + Vector((0, 0, 0.04))), 0.09, "leaf_green", scale=(1.2, 1.2, 0.7))
        P.box(tuple(base + (top - base) * 0.25 + Vector((sx * 0.04, -0.02, 0))), (0.07, 0.07, 0.05), "leaf_dark", rot=_rz(30))


def unicorn_horn(ctx):
    """Wisp, Unicorn Cat: a glowing spiral horn on the brow."""
    P = ctx.pen("head")
    R = _rx(16)
    base = Vector((0, -0.17, -0.02))
    d = R @ Vector((0, 0, 1))
    P.cyl(tuple(base + d * 0.23), 0.1, 0.46, "sparkle", r2=0.015, rot=R, segments=10)
    for f, r in ((0.12, 0.092), (0.32, 0.068), (0.52, 0.045)):
        P.cyl(tuple(base + d * (0.46 * f + 0.02)), r + 0.012, 0.03, "pastel_lilac", rot=R @ _rx(-14), segments=10)


def hard_hat(ctx):
    """Lantern, Miner Cat: a yellow hard hat with a ridge and a lamp on the front."""
    P = ctx.pen("head")
    P.cyl((0, -0.02, 0.0), 0.42, 0.04, "rarity_legend", segments=14)
    P.cyl((0, 0, 0.1), 0.33, 0.18, "rarity_legend", r2=0.29, segments=12)
    P.cyl((0, 0, 0.23), 0.29, 0.08, "rarity_legend", r2=0.17, segments=12)
    P.box((0, 0, 0.255), (0.08, 0.5, 0.07), "rarity_legend")
    P.box((0, -0.33, 0.14), (0.14, 0.06, 0.12), "fur_black")
    P.cyl((0, -0.39, 0.14), 0.085, 0.1, "metal", rot=_rx(90))
    P.cyl((0, -0.445, 0.14), 0.065, 0.02, "sparkle", rot=_rx(90))


def bottlecap_crown(ctx):
    """Bottlecap, King Cat: a bronze band crowned with bottle caps standing round it, a red one at the front."""
    P = ctx.pen("head")
    P.cyl((0, 0, 0.05), 0.31, 0.12, "bronze", segments=12)
    cols = ("bowl_red", "shirt_blue", "leaf_green", "metal", "pastel_butter", "sign_teal")
    for i, az in enumerate((0, 60, 120, 180, 240, 300)):
        R = _rz(az)
        P.pyramid(tuple(R @ Vector((0, -0.27, 0.2))), 0.2, 0.3, "bronze", rot=R @ _rx(-8) @ _rz(45))
        P.cyl(tuple(R @ Vector((0, -0.3, 0.2))), 0.1, 0.045, cols[i], rot=R @ _rx(90 - 12), segments=8)
        P.cyl(tuple(R @ Vector((0, -0.325, 0.205))), 0.055, 0.012, "offwhite", rot=R @ _rx(90 - 12), segments=8)
    P.ico((0, -0.31, 0.065), 0.04, "neon_pink")


# ------------------------------------------------------------------------------------------------- Face --
def _side_strap(ctx, z, sw, hgt=0.06, back=True):
    """A strap along both sides of the head and across the back at face-frame height z."""
    F = ctx.pen("face")
    for sx in (-1, 1):
        F.box((sx * (ctx.fw + 0.01), ctx.fd / 2 - 0.02, z), (0.03, ctx.fd + 0.02, hgt), sw)
    if back:
        F.box((0, ctx.fd + 0.01, z), (2 * ctx.fw + 0.05, 0.03, hgt + 0.004), sw)


def eye_patch(ctx):
    """Calico, Pirate Cat: a black patch over the left eye on a strap round the head. The strap climbs to the right
    side of the head, not over the top, so a role hat's brim sits clear of it."""
    F, ex = ctx.pen("face"), ctx.eye_x
    hi = ctx.ftop - 0.16                                   # the strap's high side, below any hat brim
    F.box((ex, -0.085, 0.0), (2 * ctx.eye_hw + 0.08, 0.035, 2 * ctx.eye_hh + 0.06), "fur_black")
    F.bar((ex - 0.12, -0.014, 0.16), (-(ctx.fw + 0.01), -0.014, hi), 0.05, 0.03, "fur_black", up=(0, -1, 0))
    F.bar((ex + 0.13, -0.05, 0.02), (ctx.fw + 0.015, -0.03, 0.04), 0.05, 0.03, "fur_black", up=(0, -1, 0))
    F.box((ctx.fw + 0.01, ctx.fd / 2 - 0.02, 0.04), (0.03, ctx.fd + 0.02, 0.05), "fur_black")
    F.box((-(ctx.fw + 0.01), ctx.fd / 2 - 0.02, hi), (0.03, ctx.fd + 0.02, 0.05), "fur_black")
    F.bar((ctx.fw + 0.02, ctx.fd + 0.01, 0.04), (-(ctx.fw + 0.02), ctx.fd + 0.01, hi), 0.05, 0.03,
          "fur_black", up=(0, 1, 0))


def bandit_mask(ctx):
    """MaineCoon, Bandit Cat: a black mask across both eyes with eye holes, tied at the back with two tails."""
    F, ex, hw, hh = ctx.pen("face"), ctx.eye_x, ctx.eye_hw, ctx.eye_hh
    y, t = -0.0135, 0.043                               # front 0.005 past the muzzle, back clear of the nose's
    inner, outer = ex - hw + 0.015, ex + hw - 0.015          # the mask runs under the eyes' edges
    F.box((0, y, hh + 0.04), (2 * ctx.fw + 0.02, t, 0.1), "fur_black")
    F.box((0, y, -hh - 0.035), (2 * ctx.fw + 0.02, t, 0.09), "fur_black")
    F.box((0, y, 0), (2 * inner, t, 2 * hh + 0.06), "fur_black")
    for sx in (-1, 1):
        F.box((sx * (outer + ctx.fw + 0.01) / 2, y, 0), (ctx.fw + 0.01 - outer, t, 2 * hh + 0.03), "fur_black")
    _side_strap(ctx, 0.04, "fur_black", hgt=0.08)
    for sx in (-1, 1):
        F.bar((sx * 0.04, ctx.fd + 0.03, 0.04), (sx * 0.16, ctx.fd + 0.3, -0.18), 0.08, 0.03, "fur_black", up=(0, 1, 1))
    F.box((0, ctx.fd + 0.05, 0.04), (0.12, 0.06, 0.12), "fur_black")


def round_glasses(ctx):
    """Siamese, Nerd Cat: big round black glasses with clear lenses, arms back to the ears."""
    F, G, ex = ctx.pen("face"), ctx.gpen("face"), ctx.eye_x
    for sx in (-1, 1):
        F.ring((sx * ex, -0.095, 0.0), 0.18, 0.04, 0.035, "fur_black", rot=_rx(90), segments=12)
        G.cyl((sx * ex, -0.1, 0.0), 0.145, 0.012, "glass", rot=_rx(90), segments=12)
        F.box((sx * (ctx.fw + 0.01), ctx.fd * 0.3 - 0.05, 0.03), (0.04, ctx.fd * 0.6 + 0.1, 0.04), "fur_black")
        F.bar((sx * (ex + 0.17), -0.095, 0.03), (sx * (ctx.fw + 0.01), -0.03, 0.03), 0.04, 0.04, "fur_black", up=(0, 0, 1))
    F.box((0, -0.095, 0.03), (2 * ex - 0.34, 0.035, 0.04), "fur_black")


def bubble_pipe(ctx):
    """Bubbles, Bubble Cat: a wooden pipe in the corner of the mouth, two soap bubbles floating up from it."""
    F, G = ctx.pen("face"), ctx.gpen("face")
    z = ctx.mouth_z
    F.bar((0.07, 0.0, z), (0.3, -0.26, z - 0.05), 0.055, 0.055, "dark_wood", up=(0, 0, 1))
    F.cyl((0.33, -0.28, z + 0.03), 0.11, 0.18, "caramel_wood", segments=10)
    F.cyl((0.33, -0.28, z + 0.117), 0.08, 0.012, "fur_black", segments=10)
    for (bx, by, bz, br) in ((0.42, -0.36, z + 0.33, 0.1), (0.3, -0.42, z + 0.58, 0.14), (0.5, -0.4, z + 0.75, 0.08)):
        G.ico((bx, by, bz), br, "glass")
        F.box((bx - br * 0.4, by - br * 0.7, bz + br * 0.35), (br * 0.35, br * 0.4, br * 0.35), "milk")   # a shine


def brass_goggles(ctx):
    """Gears, Steampunk Cat: brass goggles over the eyes, clear lenses, a leather strap and rivets."""
    F, G, ex = ctx.pen("face"), ctx.gpen("face"), ctx.eye_x
    for sx in (-1, 1):
        F.ring((sx * ex, -0.085, 0.0), 0.17, 0.045, 0.09, "brass", rot=_rx(90), segments=12)
        F.ring((sx * ex, -0.135, 0.0), 0.16, 0.025, 0.02, "bronze", rot=_rx(90), segments=12)
        G.cyl((sx * ex, -0.12, 0.0), 0.13, 0.01, "glass", rot=_rx(90), segments=12)
        F.box((sx * (ex + 0.14), -0.13, 0.1), (0.035, 0.035, 0.035), "bronze")
        F.box((sx * (ex + 0.14), -0.13, -0.1), (0.035, 0.035, 0.035), "bronze")
        F.bar((sx * (ex + 0.16), -0.06, 0.0), (sx * (ctx.fw + 0.015), -0.02, 0.0), 0.08, 0.03, "dark_wood", up=(0, -1, 0))
    F.box((0, -0.11, 0.02), (2 * ex - 0.33, 0.05, 0.05), "brass")
    _side_strap(ctx, 0.0, "dark_wood", hgt=0.08)


def snorkel_mask(ctx):
    """Glimmer, Diver Cat: a blue dive mask with one wide lens over both eyes and a pink snorkel up the right side."""
    F, G = ctx.pen("face"), ctx.gpen("face")
    hh, x1 = ctx.eye_hh, ctx.eye_x + ctx.eye_hw + 0.07
    y, dep = -0.06, 0.13
    F.box((0, y, hh + 0.05), (2 * x1 + 0.1, dep, 0.08), "shirt_blue")
    F.box((0, y, -hh - 0.045), (2 * x1 + 0.1, dep, 0.07), "shirt_blue")
    for sx in (-1, 1):
        F.box((sx * (x1 + 0.025), y, 0), (0.07, dep, 2 * hh + 0.03), "shirt_blue")
    G.box((0, y - 0.04, 0), (2 * x1 - 0.02, 0.012, 2 * hh + 0.04), "glass")
    _side_strap(ctx, 0.0, "fur_black", hgt=0.07)
    z = ctx.mouth_z
    sx, side = -1, -(ctx.fw + 0.05)
    F.cyl((sx * 0.1, -0.05, z - 0.02), 0.045, 0.1, "fur_black", rot=_rx(90), segments=8)
    F.bar((sx * 0.1, -0.08, z - 0.03), (side, -0.1, z - 0.06), 0.07, 0.07, "neon_pink", up=(0, 0, 1))
    F.bar((side, -0.1, z - 0.095), (side, -0.1, ctx.ftop + 0.3), 0.08, 0.08, "neon_pink", up=(0, -1, 0))
    F.cyl((side, -0.1, ctx.ftop + 0.33), 0.065, 0.08, "pastel_butter", segments=10)
    F.box((-ctx.fw, -0.1, 0.0), (0.05, 0.1, 0.08), "fur_black")


# ------------------------------------------------------------------------------------------------- Back --
def guitar(ctx):
    """Tortie, Rocker Cat: a red mini electric guitar slung across the back, neck toward the left shoulder."""
    P = ctx.pen("back")
    # On A the neck runs back past the hip so it shows beside the body from the front and behind (pointed at the
    # head it hid under it); on B it goes up over the left shoulder.
    walk = ctx.body == "walk"
    R = _rz(-55 if walk else 55)
    o, lift, d = (0.07, 0.0, -1) if walk else (0.115, -0.06, 1)     # B: the body's inner face B_CLEAR off the back

    def at(x, a, z=0.0):
        return tuple(R @ Vector((x, d * a + lift, 0)) + Vector((0, 0, o + z)))
    P.cyl(at(0, 0.16), 0.24, 0.09, "bowl_red", segments=12)
    P.cyl(at(0, -0.08), 0.19, 0.09, "bowl_red", segments=12)
    P.cyl(at(0.04, 0.15, 0.05), 0.13, 0.02, "offwhite", segments=10)
    P.box(at(0, 0.02, 0.06), (0.18, 0.05, 0.03), "fur_black", rot=R)
    P.box(at(0, -0.44, 0.0), (0.09, 0.56, 0.055), "caramel_wood", rot=R)
    P.box(at(0, -0.78, 0.0), (0.14, 0.16, 0.055), "fur_black", rot=R)
    for sx in (-1, 1):                                           # tuning pegs, so the headstock reads as one
        for a in (-0.74, -0.82):
            P.box(at(sx * 0.09, a, 0.0), (0.05, 0.035, 0.035), "metal", rot=R)
    if ctx.body == "walk":
        _strap_round(ctx, "fur_black", at_y=0.1)
    else:
        _sling(ctx, "fur_black", xs=(0.2,))


def fairy_wings(ctx):
    """Blossom, Fairy Cat: two pairs of lilac and sky wings from the shoulders, tipped back a little. On B they ride
    a harness strap, B_CLEAR off the back."""
    U = ctx.pen("up")
    if ctx.body == "sit":
        U = Pen(U.b, tuple(Vector(U.at) + Vector((0, 0.07, 0))), U.R, U.s)
        _sling(ctx, "fur_rose", xs=(0.0,), down=0.09)
    lean = _rx(-25 if ctx.body == "walk" else -15)
    for sx in (-1, 1):
        P = Pen(U.b, U.at, U.R @ lean, U.s * 1.3)
        P.sphere((sx * 0.36, 0.05, 0.3), 0.3, "pastel_lilac", scale=(1, 0.09, 0.62), rot=_ry(-sx * 35), segments=10, rings=5)
        P.sphere((sx * 0.3, 0.07, 0.0), 0.2, "pastel_sky", scale=(1, 0.09, 0.62), rot=_ry(sx * 25), segments=10, rings=5)
    U.box((0, 0.06, 0.08), (0.14, 0.1, 0.14), "fur_rose")


def skateboard(ctx):
    """Munchkin, Skater Cat: a teal skateboard strapped on, wheels out (along A's back, across B's back)."""
    P = ctx.pen("back")
    R = Matrix.Identity(3) if ctx.body == "walk" else _rz(90)
    L = 0.4 if ctx.body == "walk" else 0.36
    lift = 0.0 if ctx.body == "walk" else 0.05          # B: the deck's inner face B_CLEAR off the back

    def at(x, a, o):
        return tuple(R @ Vector((x, a, o + lift)))
    P.box(at(0, 0, 0.05), (0.38, 2 * L, 0.05), "sign_teal", rot=R)
    for sa in (-1, 1):
        P.box(at(0, sa * (L + 0.07), 0.08), (0.38, 0.16, 0.05), "sign_teal", rot=R @ _rx(sa * 20))
        P.box(at(0, sa * (L - 0.12), 0.1), (0.24, 0.07, 0.05), "metal", rot=R)
        for sx in (-1, 1):
            P.cyl(at(sx * 0.15, sa * (L - 0.12), 0.15), 0.075, 0.07, "neon_pink", rot=R @ _ry(90), segments=8)
    P.star(at(0, 0, 0.08), 0.15, 0.06, 0.012, "rarity_legend", rot=R)
    if ctx.body == "walk":
        _strap_round(ctx, "fur_black", at_y=0.0)
    else:
        _sling(ctx, "fur_black", down=0.175)


def hero_cape(ctx):
    """Marshmallow, Super Cat: a red cape with a gold star, from a collar behind the head over the back (A) or down
    the back and over the haunches (B)."""
    if ctx.body == "walk":
        P = ctx.pen("back")
        (x0, y0, zc), (sx, sy, sz) = ctx.d["body"]
        hx, hy = sx / 2, sy / 2
        P.box((0, -0.2, 0.06), (sx * 0.9, 0.16, 0.12), "shirt_red")                          # collar
        P.box((0, -0.22, 0.05), (0.16, 0.06, 0.1), "rarity_legend")                           # clasp
        P.bar((0, -0.2, 0.04), (0, hy - 0.05, 0.03), sx + 0.08, 0.035, "shirt_red", up=(0, 0, 1))
        for side in (-1, 1):                                                                  # flaring over the flanks
            P.bar((side * (hx + 0.02), -0.12, 0.0), (side * (hx + 0.09), hy - 0.08, -0.16), 0.035, 0.22, "shirt_red",
                  up=(side, 0, 0))
        P.bar((0, hy - 0.08, 0.03), (0, hy + 0.32, 0.12), sx + 0.2, 0.035, "shirt_red", up=(0, 0, 1))   # lifting behind
        for i, x in enumerate((-0.3, -0.1, 0.1, 0.3)):                                        # a wavy hem
            P.box((x * (sx + 0.2) / 0.8, hy + 0.34, 0.12 + 0.03 * (i % 2)), (0.2, 0.08, 0.035), "shirt_red", rot=_rx(-12))
        P.star((0, 0.12, 0.06), 0.16, 0.07, 0.03, "rarity_legend")
        return
    U = ctx.pen("up")
    hb, ht = ctx.haunch_back - B_BACK_Y, ctx.haunch_top - 0.98       # the haunches' back and top in this frame
    U.box((0, 0.0, 0.08), (0.72, 0.12, 0.12), "shirt_red")                                       # collar
    a, b = Vector((0, 0.06, 0.1)), Vector((0, hb - 0.16, ht + 0.02))
    U.bar(tuple(a), tuple(b), 0.86, 0.04, "shirt_red", up=(0, 1, 0))                           # down the back
    U.bar((0, hb - 0.18, ht + 0.025), (0, hb + 0.035, ht - 0.04), 0.9, 0.04, "shirt_red", up=(0, 1, 1))   # over the haunches
    U.bar((0, hb + 0.03, ht - 0.03), (0, hb + 0.07, 0.04 - 0.98), 0.94, 0.04, "shirt_red", up=(0, 1, 0))  # to the floor
    n = Vector((0, (b - a).z, -(b - a).y)).normalized()
    if n.y < 0:
        n = -n
    tilt = math.degrees(math.atan2(n.z, n.y))
    U.star(tuple((a + b) / 2 + n * 0.035), 0.15, 0.065, 0.03, "rarity_legend", rot=_rx(-90 + tilt))


def backpack(ctx):
    """Pinecone, Scout Cat: a green backpack with a flap and a pocket, and a rolled red bedroll on top."""
    P = ctx.pen("back")
    if ctx.body == "walk":
        P.box((0, 0.08, 0.12), (0.5, 0.42, 0.26), "leaf_dark", bevel=True)
        P.box((0, -0.02, 0.26), (0.46, 0.24, 0.03), "leaf_green")
        P.box((0, 0.3, 0.1), (0.3, 0.03, 0.14), "leaf_green")
        P.cyl((0, 0.1, 0.35), 0.11, 0.6, "brick", rot=_ry(90), segments=10)
        for sx in (-1, 1):
            P.cyl((sx * 0.18, 0.1, 0.35), 0.118, 0.04, "dark_wood", rot=_ry(90), segments=10)
        _strap_round(ctx, "dark_wood", at_y=0.08)
    else:
        o = 0.08                                        # the pack's inner face B_CLEAR off the back
        P.box((0, -0.02, 0.11 + o), (0.5, 0.42, 0.24), "leaf_dark", bevel=True)
        P.box((0, -0.12, 0.24 + o), (0.46, 0.2, 0.03), "leaf_green")
        P.box((0, 0.1, 0.24 + o), (0.3, 0.14, 0.03), "leaf_green")
        P.cyl((0, -0.31, 0.16 + o), 0.11, 0.6, "brick", rot=_ry(90), segments=10)
        for sx in (-1, 1):
            P.cyl((sx * 0.18, -0.31, 0.16 + o), 0.118, 0.04, "dark_wood", rot=_ry(90), segments=10)
        _sling(ctx, "dark_wood", down=0.135)


def firefly_jar(ctx):
    """Firefly, Firefly Cat: a glass jar of fireflies standing on the back, a metal lid and a strap."""
    U, G = ctx.pen("up"), ctx.gpen("up")
    if ctx.body == "walk":
        at = (0, 0.25, -0.01)
    else:                                               # B_CLEAR off the back, resting on the haunches
        at = (0, 0.295, ctx.haunch_top - 0.98 + 0.01)
    x, y, z = at
    G.cyl((x, y, z + 0.25), 0.2, 0.44, "glass", segments=12)
    U.cyl((x, y, z + 0.49), 0.21, 0.07, "metal", segments=12)
    U.cyl((x, y, z + 0.54), 0.12, 0.04, "metal", segments=10)
    U.cyl((x, y, z + 0.035), 0.205, 0.05, "metal", segments=12)
    for az, dz in ((20, 0.12), (95, 0.2), (170, 0.32), (240, 0.15), (300, 0.36), (130, 0.4)):   # resting on the glass
        U.ico(tuple(Vector((x, y, z + dz)) + _rz(az) @ Vector((0, -0.17, 0))), 0.045, "sparkle")
    U.ring((x, y, z + 0.25), 0.22, 0.025, 0.06, "dark_wood", segments=12)
    if ctx.body == "walk":
        _strap_round(ctx, "dark_wood", at_y=0.25 - ctx.d["body"][1][1] * 0.22)
    else:
        _sling(ctx, "dark_wood", xs=(0.0,), down=0.09)


def dragon_wings(ctx):
    """Eclipse, Dragon Cat: two little bat-wing dragon wings from the shoulders, green membranes on mint bones. On B
    they ride a harness strap, B_CLEAR off the back."""
    U = ctx.pen("up")
    if ctx.body == "sit":
        U = Pen(U.b, tuple(Vector(U.at) + Vector((0, 0.07, 0))), U.R, U.s)
        _sling(ctx, "fur_emerald", xs=(0.0,), down=0.09)
    lean = _rx(-30 if ctx.body == "walk" else -20)
    tips = [(0.12, 0.42), (0.38, 0.4), (0.56, 0.22), (0.62, 0.0)]
    edge = [(0.12, 0.42), (0.22, 0.3), (0.38, 0.4), (0.44, 0.2), (0.56, 0.22), (0.54, 0.05), (0.62, 0.0), (0.4, -0.04),
            (0.2, -0.02)]
    for sx in (-1, 1):
        P = Pen(U.b, U.at, U.R @ lean, U.s * 1.35)
        root = Vector((sx * 0.08, 0.05, 0.05))
        chain = [(sx * x, z) for x, z in edge]
        P.fan(tuple(root), (0.0, 0.0), chain, 0.03, "aurora_violet", rot=_rx(90))
        for (x, z) in tips:
            P.bar(tuple(root + Vector((0, -0.02, 0))), tuple(root + Vector((sx * x, -0.02, z))), 0.045, 0.04, "mint",
                  up=(0, 1, 0))
        P.ico(tuple(root + Vector((sx * 0.12, -0.02, 0.42))), 0.035, "mint")
    U.box((0, 0.05, 0.05), (0.26, 0.1, 0.12), "fur_emerald")


# ------------------------------------------------------------------------------- F78 area-themed cats --
# v0.13 (data-model 3, Derek 2026-10-27 23:59). On body B a back prop stays 0.055 or more off the back of the chest
# below the vest's top (z 0.965), so it clears the waiter's vest, the barista's apron bow and the greeter's sash
# (accessories.py); only the Entertainer's cape shares the back, and a Back prop takes its place.
B_CLEAR = 0.07              # up-frame y of a back prop's inner face on B: the vest's back is at 0.045, the bow's 0.06


def _sling(ctx, sw, xs=(-0.2, 0.2), down=0.3):
    """B: straps over the top of the chest from under the chin and down the back, 0.055 off it and clear of the
    role outfits, `down` from the strap tops (up frame z 0.155)."""
    U = ctx.pen("up")
    for x in xs:
        U.box((x, -0.02, 0.135), (0.09, 0.23, 0.04), sw)                  # over the chest top (z 1.1), under the chin
        U.box((x, 0.075, 0.155 - down / 2), (0.09, 0.04, down), sw)        # down the back


def _on(P, c, R, local, size, sw, rot=None):
    """A box on a turned panel: `local` and `rot` in the panel's own axes (centre c, turn R)."""
    P.box(tuple(Vector(c) + R @ Vector(local)), size, sw, rot=R @ rot if rot is not None else R)


def _bag_knot(P, at, out, up, bag):
    """A bin bag's tied top: a gathered neck out of the bag along `out`, a bunch and two floppy tie ears."""
    at, out, up = Vector(at), Vector(out), Vector(up)
    side = out.cross(up)
    P.cyl(tuple(at + out * 0.04), 0.06, 0.1, bag, rot=Vector((0, 0, 1)).rotation_difference(out).to_matrix(),
          segments=8)
    bunch = at + out * 0.11
    P.sphere(tuple(bunch), 0.08, bag, segments=8, rings=5)
    for sx in (-1, 1):
        d = (up * 0.8 + side * sx * 0.6).normalized()
        R = Vector((0, 0, 1)).rotation_difference(d).to_matrix()
        P.sphere(tuple(bunch + d * 0.1), 0.11, bag, scale=(0.4, 0.16, 1.0), rot=R, segments=8, rings=5)


def bin_bag(ctx):
    """Binbag, Garbage Bag Cat: a shiny black bin bag draped over its back like a cape (nothing at the neck):
    rumpled panels, a ragged hem of points, its tied top with two floppy ears on the back and a few glints."""
    bag, shine = "fur_black", "fur_smoke_light"
    if ctx.body == "walk":
        P = ctx.pen("back")                         # z 0 is the body top; the stripes stand 0.03 proud of it
        (x0, y0, zc), (sx, sy, sz) = ctx.d["body"]
        hx = sx / 2 + 0.035
        for k, (ya, yb, z, t) in enumerate(((-0.22, -0.02, 0.035, 4), (-0.04, 0.16, 0.05, -3), (0.14, 0.3, 0.035, 5))):
            c, R = ((0, (ya + yb) / 2, z)), _rx(t)                                             # over the back
            P.box(c, (2 * hx + 0.05 - 0.02 * k, yb - ya, 0.05), bag, rot=R)
            if k == 1:
                _on(P, c, R, (0.18, 0.0, 0.029), (0.03, 0.14, 0.012), shine, rot=_rz(25))      # a glint
        for side in (-1, 1):                                                                   # down the flanks
            for k, (y, ln) in enumerate(((-0.13, 0.3), (0.04, 0.38), (0.2, 0.26))):
                c, R = (side * (hx + 0.012), y, 0.035 - ln / 2), _ry(-side * 6)
                P.box(c, (0.04, 0.17, ln), bag, rot=R)
                _on(P, c, R, (0, 0, -ln / 2), (0.04, 0.085, 0.085), bag, rot=_rx(45))          # a point of the hem
                if k == 1:
                    _on(P, c, R, (side * 0.024, 0.03, 0.04), (0.012, 0.03, 0.14), shine, rot=_rx(18))
        _bag_knot(P, (0, 0.06, 0.06), (0, 0, 1), (0, 1, 0), bag)
        return
    U = ctx.pen("up")                               # y 0 is the back of the chest, z 0.12 its top, -0.42 the haunches
    hb, ht = ctx.haunch_back - B_BACK_Y, ctx.haunch_top - 0.98
    y1 = B_CLEAR + 0.02
    U.box((-0.2, 0.0, 0.14), (0.46, 0.16, 0.1), bag, rot=_ry(4))                             # bunched on the shoulders
    U.box((0.2, 0.01, 0.15), (0.46, 0.15, 0.1), bag, rot=_ry(-5))
    for k, (x, t, lo) in enumerate(((-0.34, 8, 0.0), (-0.17, 5, 0.04), (0.0, 9, 0.0), (0.17, 6, 0.03),
                                    (0.34, 8, 0.01))):                                        # rumpled down the back
        top, bot = 0.15, ht + 0.03 + lo
        ln = top - bot
        c = (x, y1 + 0.02 + ln / 2 * math.sin(math.radians(t)), (top + bot) / 2)
        R = _rx(t)
        U.box(c, (0.19, 0.04, ln), bag, rot=R)
        if k in (1, 3):
            _on(U, c, R, (0.02, 0.024, 0.08 - 0.1 * (k == 3)), (0.03, 0.012, 0.16), shine, rot=_ry(20 - 40 * (k == 3)))
    U.box((0, (y1 + hb) / 2 + 0.05, ht + 0.02), (0.9, hb - y1 - 0.06, 0.05), bag)          # over the haunches
    U.box((0, hb + 0.03, ht - 0.1), (0.9, 0.04, 0.24), bag)                                 # down the rump
    for x in (-0.36, -0.18, 0.0, 0.18, 0.36):                                               # a ragged hem of points
        U.box((x, hb + 0.03, ht - 0.22), (0.085, 0.04, 0.085), bag, rot=_ry(45))
    _bag_knot(U, (0.04, y1 + 0.06, -0.02), (0, 1, 0), (0, 0, 1), bag)


def taxi_light(ctx):
    """Taxi, Taxi Cat: a yellow taxi roof light worn as a hat, a black base, a checkered band round it and a paw
    print on the front (no words)."""
    P = ctx.pen("head")
    y, w, dp = -0.1, 0.44, 0.26
    P.box((0, y, 0.02), (w + 0.08, dp + 0.06, 0.05), "fur_black")                        # base on the head
    P.box((0, y, 0.15), (w, dp, 0.22), "rarity_legend")                                  # the light
    P.box((0, y, 0.275), (w - 0.08, dp - 0.06, 0.04), "rarity_legend")                   # its rounded top
    n, q = 8, w / 8
    for face in (-1, 1):                                                                  # checkered band, both faces
        fy = y + face * dp / 2
        P.box((0, fy + face * 0.004, 0.08), (w - 0.02, 0.02, 0.07), "fur_white")
        for row, dz in enumerate((0.0155, -0.0155)):
            for j in range(row % 2, n, 2):
                if (j == 0 and row == 0) or (j == n - 1 and row == 1):
                    continue                                                            # the band's own corners
                P.box((-w / 2 + q * (j + 0.5), fy + face * 0.0165, 0.08 + dz), (q, 0.015, 0.025), "fur_black")
    fy = y - dp / 2 - 0.006
    P.box((0, fy, 0.16), (0.13, 0.02, 0.075), "fur_black")                                # a paw print: the pad
    for x, z in ((-0.085, 0.215), (-0.03, 0.235), (0.03, 0.235), (0.085, 0.215)):        # and four toes
        P.box((x, fy, z), (0.04, 0.02, 0.04), "fur_black")


def fedora(ctx):
    """Neon, Jazz Cat: a little black fedora with a neon pink band and a crease on top, tipped to one side."""
    P = ctx.pen("head")
    R = _ry(-8) @ _rx(-5)
    o = Vector((0.03, -0.02, 0.0))

    def at(x, y, z):
        return tuple(o + R @ Vector((x, y, z)))
    P.cyl(at(0, 0, 0.02), 0.38, 0.035, "fur_black", rot=R, segments=14)                  # brim
    P.cyl(at(0, 0, 0.13), 0.24, 0.2, "fur_black", rot=R, r2=0.21, segments=12)          # crown
    P.cyl(at(0, 0, 0.07), 0.25, 0.06, "neon_pink", rot=R, r2=0.24, segments=12)       # band
    P.box(at(0, 0.0, 0.235), (0.07, 0.3, 0.03), "fur_black", rot=R)                     # the crease on top


def _plane(p0, p1, out):
    """A frame on a flat tool lying against the back: origin p0, y toward p1, z `out` (away from the cat), x = y x z.
    Returns (origin, rotation, length)."""
    p0, p1, z = Vector(p0), Vector(p1), Vector(out)
    y = (p1 - p0).normalized()
    x = y.cross(z)
    return p0, Matrix((x, y, z)).transposed(), (p1 - p0).length


def saxophone(ctx):
    """Neon, Jazz Cat's second prop: a glowing saxophone slung on its back, brass with a gold bell rim, teal and pink
    keys and a black mouthpiece, on a strap. Its body is the biggest part (the music notes rise off it)."""
    walk = ctx.body == "walk"
    if walk:                                    # across the back, bell by the left shoulder, neck to the right rear
        P = ctx.pen("back")
        o = 0.095
        p0, R, _ = _plane((0.2, 0.3, o), (-0.138, 0.004, o), (0, 0, 1))
        bell = -1
    else:                                       # down the back, bell low on the right, neck up by the left shoulder
        P = ctx.pen("up")
        o = B_CLEAR + 0.075
        p0, R, _ = _plane((-0.12, o, -0.33), (0.1035, o, 0.117), (0, 1, 0))
        bell = 1

    def at(x, y, z=0.0):
        return tuple(p0 + R @ Vector((x, y, z)))
    up, across = R @ _rx(-90), R @ _ry(90)              # a cylinder's axis along the sax, and across it
    bx = 0.2 * bell
    P.cyl(at(0, 0.225), 0.07, 0.45, "brass", rot=up, r2=0.06, segments=10)                    # the body
    P.cyl(at(bx / 2, -0.02, 0.03), 0.075, 0.2 + 0.075, "brass", rot=across, segments=10)      # the bow at the bottom
    P.cyl(at(bx, 0.11, 0.06), 0.09, 0.24, "brass", rot=up, r2=0.13, segments=10)              # the bell's tube
    P.ring(at(bx, 0.235, 0.06), 0.14, 0.035, 0.04, "rarity_legend", rot=up, segments=10)      # bell rim
    a, b = Vector((0, 0.43)), Vector((-0.14 * bell, 0.53))                                      # the neck, bent away
    d = (b - a).normalized()
    turn = R @ _rz(math.degrees(math.atan2(-d.x, d.y))) @ _rx(-90)
    P.cyl(at(*((a + b) / 2)), 0.035, (b - a).length + 0.04, "brass", rot=turn, segments=6)
    P.cyl(at(*(b + d * 0.04)), 0.03, 0.08, "fur_black", rot=turn, segments=6)                 # mouthpiece
    for k, y in enumerate((0.08, 0.17, 0.26, 0.35)):                                           # keys on the front
        P.cyl(at(0, y, 0.07), 0.028, 0.02, "neon_pink" if k % 2 else "sign_teal", rot=R, segments=6)
    if walk:
        mid = p0 + R @ Vector((0, 0.225, 0))
        _strap_round(ctx, "fur_black", at_y=mid.y)
        P.box((mid.x, mid.y, 0.025), (0.09, 0.09, 0.05), "fur_black")                         # the strap's loop
    else:
        _sling(ctx, "fur_black", xs=(0.05,), down=0.205)


def binoculars(ctx):
    """Birdwatch, Birdwatcher Cat: green field binoculars (the old prism kind) up to its eyes: black eyecups on the
    eyes, a chunky green prism body each side, the big lens barrels set wider apart in front with black rims and
    clear lenses, a focus wheel on the bridge and a strap round the head."""
    F, G, ex = ctx.pen("face"), ctx.gpen("face"), ctx.eye_x
    z = 0.02
    for sx in (-1, 1):
        x, xo = sx * ex, sx * (ex + 0.07)
        F.cyl((x, -0.075, z), 0.09, 0.07, "fur_black", rot=_rx(90), segments=10)            # eyecup, on the eye
        F.box((sx * (ex + 0.02), -0.17, z), (0.22, 0.14, 0.24), "leaf_dark")               # prism body
        F.cyl((xo, -0.3, z), 0.11, 0.14, "leaf_dark", rot=_rx(90), segments=10)             # lens barrel
        F.ring((xo, -0.38, z), 0.125, 0.03, 0.03, "fur_black", rot=_rx(90), segments=10)    # front rim
        G.cyl((xo, -0.375, z), 0.09, 0.012, "glass", rot=_rx(90), segments=10)              # lens, inside the rim
        F.bar((sx * (ex + 0.12), -0.15, z), (sx * (ctx.fw + 0.015), -0.02, z), 0.05, 0.03, "fur_black",
              up=(0, 0, 1))                                                                 # strap to the head
    F.box((0, -0.17, z + 0.05), (2 * ex - 0.2, 0.1, 0.07), "fur_black")                    # bridge
    F.cyl((0, -0.17, z + 0.105), 0.045, 0.06, "fur_black", rot=_ry(90), segments=8)        # focus wheel
    _side_strap(ctx, z, "fur_black", hgt=0.05)


def duckling(ctx):
    """Duckling, Duckling Cat: a fluffy yellow duckling sitting on its head, facing forward, with an orange beak and
    feet, butter wings, a tuft and a little tail."""
    P = ctx.pen("head")
    yellow, pale, beak = "rarity_legend", "pastel_butter", "eye_copper"
    P.sphere((0, 0.04, 0.115), 0.17, yellow, scale=(1, 1.2, 0.8), segments=10, rings=6)       # body
    P.sphere((0, -0.11, 0.29), 0.115, yellow, segments=10, rings=6)                            # head
    P.box((0, -0.235, 0.27), (0.1, 0.08, 0.035), beak)                                        # beak
    P.box((0, -0.24, 0.245), (0.08, 0.06, 0.025), beak)
    for sx in (-1, 1):
        P.box((sx * 0.055, -0.205, 0.32), (0.035, 0.03, 0.04), "fur_black")                  # eyes
        P.sphere((sx * 0.155, 0.05, 0.13), 0.1, pale, scale=(0.35, 1.0, 0.6), segments=8, rings=4)   # wings
        P.box((sx * 0.06, -0.13, 0.008), (0.07, 0.1, 0.03), beak)                             # feet
    P.pyramid((0, 0.22, 0.13), 0.1, 0.12, yellow, rot=_rx(-70))                               # tail
    for x, a in ((-0.02, 15), (0.03, -20)):                                                   # tuft
        P.box((x, -0.11, 0.41), (0.025, 0.025, 0.08), yellow, rot=_ry(a))


def balloons(ctx):
    """Balloon, Balloon Cat: three glowing balloons, pink, sky and yellow, on strings tied to a bow on its back, high
    over the back and the tail (on B clear of the party hat). Each balloon is one part, the three biggest of the
    prop, with a knot under it."""
    cols = ("neon_pink", "pastel_sky", "rarity_legend")
    if ctx.body == "walk":
        P = ctx.pen("back")                                 # z 0 on the body top, z up
        tie = Vector((0, 0.05, 0.04))
        tops = [Vector((-0.32, 0.2, 1.15)), Vector((0.3, 0.32, 1.05)), Vector((0.0, 0.55, 1.36))]
        _strap_round(ctx, "pastel_lilac", at_y=0.05)
        P.box(tuple(tie), (0.1, 0.1, 0.06), "pastel_lilac")
        for sx in (-1, 1):
            P.box((sx * 0.09, 0.05, 0.045), (0.11, 0.07, 0.05), "pastel_lilac", rot=_ry(sx * 20))   # the bow
    else:
        P = ctx.pen("up")                                   # y out of the back, z up
        tie = Vector((0, B_CLEAR + 0.05, -0.05))
        tops = [Vector((-0.34, 0.36, 1.0)), Vector((0.32, 0.42, 0.9)), Vector((0.0, 0.62, 1.26))]
        _sling(ctx, "pastel_lilac", xs=(0.0,), down=0.24)                                     # one ribbon down the back
        P.box(tuple(tie), (0.12, 0.06, 0.1), "pastel_lilac")                                  # the strings' tie
    r = 0.24
    for c, col in zip(tops, cols):
        P.sphere(tuple(c), r, col, scale=(1, 1, 1.15), segments=12, rings=8)                 # a balloon
        knot = c - Vector((0, 0, r * 1.15))
        P.pyramid(tuple(knot - Vector((0, 0, 0.045))), 0.07, 0.07, col, rot=_rx(180))         # its knot
        P.bar(tuple(tie + Vector((0, 0, 0.02))), tuple(knot - Vector((0, 0, 0.035))), 0.02, 0.02, "offwhite")


def hard_hat_pencil(ctx):
    """Builder, Construction Cat: an orange hard hat with a ridge and a peak, a dark band round the crown and a
    yellow pencil tucked in it at the front left."""
    P = ctx.pen("head")
    hat = "paw_neighbourhood"
    P.cyl((0, -0.02, 0.0), 0.4, 0.04, hat, segments=14)                                     # brim
    P.box((0, -0.38, 0.0), (0.36, 0.16, 0.04), hat, rot=_rx(10))                            # the peak
    P.cyl((0, 0, 0.1), 0.32, 0.18, hat, r2=0.29, segments=12)
    P.cyl((0, 0, 0.23), 0.29, 0.08, hat, r2=0.17, segments=12)
    P.box((0, 0, 0.255), (0.08, 0.5, 0.07), hat)                                            # ridge
    P.cyl((0, 0, 0.065), 0.33, 0.05, "dark_wood", r2=0.322, segments=12)                    # band
    R = _rz(40)                                         # the pencil, along the band at the front left, off the ear
    c, ax = R @ Vector((0, -0.345, 0.07)), R @ Vector((1, 0, 0))
    along, tip = R @ _ry(90), R @ _ry(-90)
    P.cyl(tuple(c), 0.03, 0.3, "pastel_butter", rot=along, segments=6)
    P.cyl(tuple(c - ax * 0.185), 0.03, 0.07, "treat_tan", rot=tip, r2=0.008, segments=6)
    P.cyl(tuple(c - ax * 0.215), 0.012, 0.025, "fur_black", rot=tip, r2=0.0, segments=6)
    P.cyl(tuple(c + ax * 0.165), 0.032, 0.03, "metal", rot=along, segments=6)
    P.cyl(tuple(c + ax * 0.195), 0.03, 0.04, "blush", rot=along, segments=6)


def sun_hat(ctx):
    """Gardener, Gardener Cat: a wide straw sun hat with a woven line on the brim, a green ribbon and a daisy."""
    P = ctx.pen("head")
    straw, weave = "treat_tan", "cardboard"
    P.cyl((0, 0, 0.0), 0.52, 0.035, straw, r2=0.5, segments=14)                             # brim
    P.ring((0, 0, 0.0215), 0.44, 0.03, 0.016, weave, segments=12)                           # woven line
    P.cyl((0, 0, 0.11), 0.27, 0.19, straw, r2=0.25, segments=12)                            # crown
    P.sphere((0, 0, 0.2), 0.25, straw, scale=(1, 1, 0.38), segments=12, rings=3)            # rounded top
    P.cyl((0, 0, 0.06), 0.282, 0.065, "leaf_green", r2=0.275, segments=12)                  # ribbon
    az = 35                                                                                 # the daisy, front left
    R = _rz(az)
    c = R @ Vector((0, -0.285, 0.07))
    face = R @ _rx(90)
    P.cyl(tuple(c), 0.04, 0.03, "rarity_legend", rot=face, segments=8)
    for k in range(6):
        a = math.radians(60 * k)
        off = R @ Vector((0.075 * math.cos(a), -0.005, 0.075 * math.sin(a)))
        P.box(tuple(c + off), (0.06, 0.02, 0.035), "offwhite", rot=R @ _ry(-60 * k))


def watering_can(ctx):
    """Gardener, Gardener Cat's second prop: a little teal watering can carried on its back, spout and rose to the
    cat's right, a handle over the top on a strap (on B it rests on the haunches behind the back)."""
    walk = ctx.body == "walk"
    U = ctx.pen("up")
    if walk:
        base = Vector((0, 0.2, 0.02))                       # standing on the back (on the saddle patch)
    else:
        base = Vector((0, B_CLEAR + 0.16, ctx.haunch_top - 0.98 - 0.005))
    can, metal = "sign_teal", "metal"
    r, h = 0.15, 0.24
    U.cyl(tuple(base + Vector((0, 0, h / 2))), r, h, can, segments=12)                      # body
    U.cyl(tuple(base + Vector((0, 0, h + 0.015))), r * 0.75, 0.03, can, segments=12)        # top
    U.ring(tuple(base + Vector((0, 0, 0.05))), r + 0.012, 0.025, 0.04, "leaf_dark", segments=12)   # a band
    spout_a = base + Vector((-r + 0.02, 0, 0.06))
    spout_b = base + Vector((-r - 0.2, 0, 0.3))
    U.bar(tuple(spout_a), tuple(spout_b), 0.05, 0.05, can, up=(0, 1, 0))                    # spout
    d = (spout_b - spout_a).normalized()
    tilt = math.degrees(math.atan2(d.x, d.z))
    U.cyl(tuple(spout_b + d * 0.02), 0.05, 0.04, metal, rot=_ry(tilt), segments=8)          # the rose
    for y in (-0.06, 0.06):
        U.box(tuple(base + Vector((0, y, h + 0.07))), (0.04, 0.03, 0.12), can)              # handle posts
    U.box(tuple(base + Vector((0, 0, h + 0.13))), (0.04, 0.18, 0.04), can)                  # handle bar
    if walk:
        _strap_round(ctx, "dark_wood", at_y=0.2 - ctx.d["body"][1][1] * 0.22)
    else:
        top = base.z + h + 0.15
        _sling(ctx, "dark_wood", xs=(0.0,), down=0.155 - top + 0.02)
        U.box((0, (0.055 + base.y) / 2, top - 0.02), (0.06, base.y - 0.055, 0.06), "dark_wood")   # to the handle


def gnome_hat(ctx):
    """Gnome, Gnome Cat: a tall pointy red gnome hat, its tip drooping forward, and a four-leaf clover on the front."""
    P = ctx.pen("head")
    red = "shirt_red"
    P.cyl((0, 0, 0.13), 0.34, 0.3, red, r2=0.21, segments=12)
    at, a = Vector((0, 0, 0.26)), 0.0
    for r1, r2, hgt, turn in ((0.215, 0.11, 0.26, 25), (0.115, 0.0, 0.24, 60)):
        R = _rx(a + turn / 2)
        d = R @ Vector((0, 0, 1))
        P.cyl(tuple(at + d * hgt / 2), r1, hgt, red, r2=r2, rot=R, segments=10)
        at, a = at + d * (hgt - 0.02), a + turn
    slope = 0.13 / 0.3                                                                      # the clover, on the cone
    tilt = _rx(-math.degrees(math.atan(slope)))

    def on(x, z, out):                                  # a point `out` off the cone's front at height z
        return (x, -(0.34 - slope * (z + 0.02) + out), z)
    for dx, dz in ((-0.035, 0.035), (0.035, 0.035), (-0.035, -0.035), (0.035, -0.035)):
        P.box(on(dx, 0.13 + dz, 0.004), (0.055, 0.02, 0.055), "leaf_green", rot=tilt @ _ry(45))
    P.box(on(0.02, 0.05, 0.004), (0.015, 0.02, 0.07), "leaf_dark", rot=tilt @ _ry(-20))


def gnome_beard(ctx):
    """Gnome, Gnome Cat's second prop: a fluffy white beard from the cheeks round under the mouth, clear of the W
    mouth and ending a little below the chin, above where a waiter's bow tie sits."""
    F = ctx.pen("face")
    beard = "milk"
    top, bot = ctx.mouth_z - 0.07, ctx.fbot - 0.12          # bot: the lowest point of the fluff
    F.box((0, -0.075, (top + bot + 0.08) / 2), (0.44, 0.1, top - bot - 0.08), beard)        # under the mouth
    for x, dz in ((-0.14, 0.03), (0.0, 0.0), (0.14, 0.03)):                                 # rounded fluffy bottom
        F.ico((x, -0.075, bot + 0.09 + dz), 0.1, beard, scale=(1.1, 0.6, 0.9))
    for sx in (-1, 1):                                                                      # side whiskers
        lo, hi = bot + 0.08, ctx.mouth_z + 0.05
        F.box((sx * 0.3, -0.05, (lo + hi) / 2), (0.16, 0.11, hi - lo), beard)
        F.ico((sx * 0.31, -0.06, lo + 0.01), 0.09, beard, scale=(1, 0.65, 1))


def work_cap(ctx):
    """Plumber, Plumber Cat: a blue work cap with a navy band, a long bill and a water drop badge (no red, no
    moustache)."""
    P = ctx.pen("head")
    blue = "shirt_blue"
    P.sphere((0, 0.01, 0.03), 0.31, blue, scale=(1, 1.05, 0.62), segments=12, rings=6)       # crown
    P.cyl((0, 0.01, 0.02), 0.336, 0.05, "pants_navy", segments=12)                          # band
    P.box((0, -0.4, 0.015), (0.4, 0.26, 0.03), blue, rot=_rx(8))                            # the bill
    P.cyl((0, 0.01, 0.215), 0.04, 0.03, "pants_navy", segments=8)                           # button
    P.sphere((0, -0.285, 0.11), 0.045, "pastel_sky", scale=(1, 0.5, 1), segments=8, rings=4)   # a water drop
    P.pyramid((0, -0.29, 0.135), 0.05, 0.07, "pastel_sky")


def wrench(ctx):
    """Plumber, Plumber Cat's second prop: a big wrench slung on its back, the open jaw up toward the right shoulder,
    a ring at the other end and a navy grip, on a strap."""
    walk = ctx.body == "walk"
    if walk:                                    # on the back, ring by the left hip, jaw toward the right shoulder
        P = ctx.pen("back")
        p0, R, L = _plane((0.22, 0.42, 0.018), (-0.17, -0.1, 0.018), (0, 0, 1))
    else:
        P = ctx.pen("up")
        yc = B_CLEAR + 0.03
        p0, R, L = _plane((0.25, yc, -0.32), (-0.17, yc, 0.3), (0, 1, 0))

    def at(x, y, z=0.0):
        return tuple(p0 + R @ Vector((x, y, z)))
    P.box(at(0, L / 2), (0.09, L, 0.045), "metal", rot=R)                                     # the shank
    P.box(at(0, 0.2), (0.11, 0.24, 0.055), "pants_navy", rot=R)                               # grip
    P.box(at(0, L + 0.03), (0.24, 0.12, 0.05), "metal", rot=R)                                # the head
    for sx in (-1, 1):
        P.box(at(sx * 0.085, L + 0.15), (0.07, 0.14, 0.05), "metal", rot=R)                   # the jaw
    P.ring(at(0, -0.06), 0.085, 0.04, 0.05, "metal", rot=R, segments=8)                       # ring end
    P.box(at(0, L - 0.07, 0.03), (0.05, 0.05, 0.02), "fur_black", rot=R)                      # adjuster
    if walk:
        _strap_round(ctx, "dark_wood", at_y=(p0 + R @ Vector((0, L / 2, 0))).y)
    else:
        z = -0.1
        x = 0.25 + (z + 0.32) / 0.62 * (-0.42)                  # the shank at that height
        _sling(ctx, "dark_wood", xs=(x,), down=0.155 - z + 0.03)
        P.box((x, B_CLEAR + 0.03, z), (0.11, 0.08, 0.07), "dark_wood")                          # holding the wrench


# ------------------------------------------------------------------- second props, later areas (Set 4 Q2) --
# Derek 2026-10-29 ("All of them sound good"): a second prop for each Neighbourhood, Woods and Sewer themed cat
# except the Unicorn Cat, each in the slot its first prop leaves free.
def backwards_cap(ctx):
    """Munchkin, Skater Cat's second prop: a teal baseball cap on backwards, the pink peak over the back of the
    head, a button on top and a gold star on the front like the one on its skateboard."""
    P = ctx.pen("head")
    P.cyl((0, 0, 0.055), 0.31, 0.12, "sign_teal", segments=12)                                  # crown
    P.sphere((0, 0, 0.115), 0.31, "sign_teal", scale=(1, 1, 0.5), segments=12, rings=4)        # its dome
    P.cyl((0, 0, 0.275), 0.05, 0.03, "neon_pink", segments=8)                                   # button
    P.box((0, 0.43, 0.035), (0.46, 0.3, 0.035), "neon_pink", rot=_rx(-10))                       # the peak, behind
    P.star((0, -0.312, 0.075), 0.075, 0.032, 0.02, "rarity_legend", rot=_rx(90))               # a star on the front


def paintbrush(ctx):
    """Fold, Painter Cat's second prop: a paintbrush held across the mouth, a caramel handle with a red end, a
    metal ferrule and flat bristles dipped in teal."""
    F = ctx.pen("face")
    a = 8                                               # the bristle end a little higher
    d = Vector((math.cos(math.radians(a)), 0, math.sin(math.radians(a))))
    c = Vector((0.0, -0.07, ctx.mouth_z - 0.01))
    along, flat = _ry(90 - a), _ry(-a)

    def at(u):
        return tuple(c + d * u)
    F.cyl(at(-0.17), 0.035, 0.72, "caramel_wood", rot=along, segments=8)                     # handle
    F.cyl(at(-0.545), 0.038, 0.05, "bowl_red", rot=along, segments=8)                        # its painted end
    F.cyl(at(0.24), 0.045, 0.12, "metal", rot=along, segments=8)                              # ferrule
    F.box(at(0.36), (0.14, 0.06, 0.1), "cardboard", rot=flat)                                 # bristles
    F.box(at(0.45), (0.07, 0.066, 0.104), "sign_teal", rot=flat)                              # dipped in teal
    F.box(tuple(c + d * 0.43 + Vector((0, 0, -0.07))), (0.03, 0.03, 0.06), "sign_teal")      # a drip


def curly_moustache(ctx):
    """Chonk, Chef Cat's second prop: a big curly chef's moustache under the nose, sweeping out and curling up."""
    F = ctx.pen("face")
    y, col = -0.06, "choco"
    F.box((0, y, -0.17), (0.16, 0.05, 0.07), col)                                             # under the nose
    for sx in (-1, 1):
        F.bar((sx * 0.06, y, -0.175), (sx * 0.23, y, -0.205), 0.075, 0.05, col, up=(0, -1, 0))  # sweeping out
        F.bar((sx * 0.22, y, -0.215), (sx * 0.29, y, -0.165), 0.055, 0.045, col, up=(0, -1, 0))   # and up
        F.ring((sx * 0.3, y, -0.205), 0.058, 0.03, 0.04, col, rot=_rx(90), segments=8)        # a curl, under the eye


def letter(ctx):
    """Postie, Mail Cat's second prop: a letter held in the mouth by its corner, a cream envelope with its flap
    drawn on, a red seal and a teal stamp."""
    F = ctx.pen("face")
    R = _ry(-12)
    c = Vector((0.2, -0.04, ctx.mouth_z - 0.1))
    face, out = R @ _rx(90), tuple(R @ Vector((0, -1, 0)))

    def at(u, w, v=0.0):
        return tuple(c + R @ Vector((u, v, w)))
    F.box(at(0, 0), (0.5, 0.03, 0.32), "offwhite", rot=R)                                     # the envelope
    for su in (-1, 1):                                                                          # its flap, a V
        F.bar(at(su * 0.235, 0.145, -0.018), at(0, -0.02, -0.018), 0.035, 0.008, "fur_grey", up=out)
    F.cyl(at(0, -0.02, -0.023), 0.055, 0.014, "bowl_red", rot=face, segments=10)            # wax seal
    F.box(at(0.17, -0.085, -0.019), (0.09, 0.008, 0.1), "sign_teal", rot=R)                 # stamp, under the flap
    F.box(at(0.17, -0.085, -0.024), (0.05, 0.004, 0.06), "offwhite", rot=R)


def hero_mask(ctx):
    """Marshmallow, Super Cat's second prop: a red domino mask round both eyes with eye holes, pointed tips up at
    the outer corners, on a strap; the cheeks' blush stays clear."""
    F, ex, hw, hh = ctx.pen("face"), ctx.eye_x, ctx.eye_hw, ctx.eye_hh
    y, t = -0.0135, 0.043
    inner, outer = ex - hw + 0.015, ex + hw - 0.015
    edge = outer + 0.11                                     # the mask's outer edge, short of the face side
    F.box((0, y, hh + 0.04), (2 * edge, t, 0.1), "shirt_red")                                  # brow
    F.box((0, y, -hh - 0.03), (2 * edge - 0.06, t, 0.08), "shirt_red")                         # under the eyes
    F.box((0, y, 0), (2 * inner, t, 2 * hh + 0.06), "shirt_red")                               # between them
    for sx in (-1, 1):
        F.box((sx * (outer + edge) / 2, y, 0), (edge - outer, t, 2 * hh + 0.03), "shirt_red")
        F.box((sx * (edge + 0.01), y - 0.003, hh + 0.09), (0.22, t - 0.004, 0.09), "shirt_red", rot=_ry(-sx * 32))  # flared tips
        F.bar((sx * (edge - 0.02), y + 0.01, 0.03), (sx * (ctx.fw + 0.01), y + 0.02, 0.04), 0.05, 0.03, "shirt_red",
              up=(0, -1, 0))                                                                     # strap to the side
    _side_strap(ctx, 0.04, "shirt_red", hgt=0.05)


def sprinkle_sunglasses(ctx):
    """Comet, Ice Cream Cat's second prop: round strawberry pink sunglasses with dark lenses and sprinkles on the
    frames, arms back to the ears."""
    F, ex = ctx.pen("face"), ctx.eye_x
    cols = ("sign_teal", "pastel_butter", "offwhite", "mint")
    for sx in (-1, 1):
        F.ring((sx * ex, -0.095, 0.0), 0.18, 0.045, 0.035, "neon_pink", rot=_rx(90), segments=10)
        F.cyl((sx * ex, -0.1, 0.0), 0.142, 0.014, "night_sky", rot=_rx(90), segments=10)        # dark lens
        for k, az in enumerate((30, 100, 170, 250, 320)):
            a = math.radians(az)
            F.box((sx * ex + 0.158 * math.cos(a), -0.115, 0.158 * math.sin(a)), (0.05, 0.012, 0.018),
                  cols[(k + (sx > 0)) % len(cols)], rot=_ry(-az + 60 * (k % 2)))               # sprinkles
        F.box((sx * (ctx.fw + 0.01), ctx.fd * 0.3 - 0.05, 0.03), (0.04, ctx.fd * 0.6 + 0.1, 0.04), "neon_pink")
        F.bar((sx * (ex + 0.17), -0.095, 0.03), (sx * (ctx.fw + 0.01), -0.03, 0.03), 0.04, 0.04, "neon_pink",
              up=(0, 0, 1))
    F.box((0, -0.095, 0.03), (2 * ex - 0.34, 0.035, 0.04), "neon_pink")                        # bridge


def ranger_hat(ctx):
    """Pinecone, Scout Cat's second prop: a tan ranger hat with a flat brim, a pinched crown, a brown band and a
    gold badge with a pine tree."""
    P = ctx.pen("head")
    P.cyl((0, 0, 0.0), 0.48, 0.035, "treat_tan", segments=14)                                  # brim
    P.cyl((0, 0, 0.115), 0.26, 0.2, "treat_tan", r2=0.24, segments=12)                         # crown
    P.pyramid((0, 0, 0.275), 0.34, 0.14, "treat_tan", rot=_rz(45))                             # the four-dent pinch
    P.cyl((0, 0, 0.06), 0.27, 0.06, "dark_wood", r2=0.265, segments=12)                        # band
    P.cyl((0, -0.272, 0.07), 0.055, 0.02, "rarity_legend", rot=_rx(90), segments=10)          # badge
    P.box((0, -0.285, 0.075), (0.035, 0.012, 0.07), "leaf_dark")                              # its pine tree
    P.box((0, -0.286, 0.06), (0.07, 0.012, 0.03), "leaf_dark")


def log_bundle(ctx):
    """ForestCat, Lumberjack Cat's second prop: a bundle of three logs tied with rope, across A's back and standing
    up on B's haunches, cut ends showing their rings."""
    walk = ctx.body == "walk"
    if walk:
        P, along = ctx.pen("back"), _ry(90)                  # logs across the back, two below and one on top
        L, y0 = 0.62, 0.12
        logs = [(Vector((0.0, y0 - 0.085, 0.075)), 0.085), (Vector((0.0, y0 + 0.085, 0.075)), 0.085),
                (Vector((0.0, y0, 0.215)), 0.08)]
        axis = Vector((1, 0, 0))
    else:
        P, along = ctx.pen("up"), Matrix.Identity(3)        # logs standing up, resting on the haunches
        L = 0.6
        zc = ctx.haunch_top - 0.98 - 0.005 + L / 2
        yc = B_CLEAR + 0.1
        logs = [(Vector((-0.17, yc, zc)), 0.085), (Vector((0.0, yc + 0.02, zc + 0.05)), 0.09),
                (Vector((0.17, yc, zc - 0.02)), 0.085)]
        axis = Vector((0, 0, 1))
    for k, (c, r) in enumerate(logs):
        ln = L - 0.04 * k
        P.cyl(tuple(c), r, ln, "caramel_wood", rot=along, segments=8)                           # bark
        for s in (-1, 1):
            P.cyl(tuple(c + axis * s * (ln / 2 + 0.006)), r - 0.012, 0.014, "treat_tan", rot=along, segments=8)   # end
            P.cyl(tuple(c + axis * s * (ln / 2 + 0.012)), r * 0.45, 0.004, "dark_wood", rot=along, segments=6)  # ring
    mid = sum((c for c, _ in logs), Vector()) / len(logs)
    for s in (-1, 1):                                                                             # two rope ties
        if walk:
            P.ring(tuple(mid + axis * s * 0.17), 0.2, 0.032, 0.05, "cardboard", rot=along, segments=12)
        else:
            P.box((0, yc + 0.1, mid.z + s * 0.17), (0.56, 0.03, 0.05), "cardboard")
    if walk:
        _strap_round(ctx, "dark_wood", at_y=0.12)
    else:
        _sling(ctx, "dark_wood", down=0.3)


def back_mushrooms(ctx):
    """Toadstool, Mushroom Cat's second prop: a patch of moss with four tiny toadstools growing out of it, red caps
    with white spots and one brown, on A's back and on B's haunches."""
    if ctx.body == "walk":
        P, k = ctx.pen("back"), 1.0
        base = Vector((0.0, 0.12, 0.0))
    else:                                               # its inner edge B_CLEAR behind the chest
        P, k = ctx.pen("up"), 0.7
        base = Vector((0.0, B_CLEAR + 0.12, ctx.haunch_top - 0.98))
    P.box(tuple(base + Vector((0, 0, 0.012))), (0.44, 0.34 * k, 0.04), "leaf_green")           # moss
    P.box(tuple(base + Vector((0.1, -0.06 * k, 0.035))), (0.16, 0.12, 0.03), "leaf_dark", rot=_rz(20))
    for (x, y, hgt, r, cap) in ((-0.1, -0.04, 0.2, 0.11, "bowl_red"), (0.1, 0.06, 0.15, 0.09, "bowl_red"),
                                (-0.14, 0.11, 0.1, 0.07, "choco"), (0.13, -0.09, 0.09, 0.06, "bowl_red")):
        o = base + Vector((x, y * k, 0.03))
        P.cyl(tuple(o + Vector((0, 0, hgt / 2))), 0.032 + r * 0.1, hgt, "offwhite", segments=8)        # stem
        P.cyl(tuple(o + Vector((0, 0, hgt + 0.02))), r, 0.06, cap, r2=r * 0.35, segments=10)          # cap
        P.cyl(tuple(o + Vector((0, 0, hgt - 0.006))), r * 0.85, 0.012, "cream", segments=10)         # gills
        if cap == "bowl_red":
            for az in (30, 160, 270):
                v = _rz(az) @ Vector((0, -r * 0.62, 0))
                P.box(tuple(o + v + Vector((0, 0, hgt + 0.035))), (0.03, 0.03, 0.02), "offwhite", rot=_rz(az) @ _rx(25))


def glow_antennae(ctx):
    """Firefly, Firefly Cat's second prop: a black headband with two springy antennae, each tipped with a glowing
    ball like a firefly's light."""
    P, w = ctx.pen("head"), ctx.hw
    y = -0.2
    pts = [(w + 0.025, -0.3), (w + 0.025, -0.04), (w - 0.08, 0.025), (-(w - 0.08), 0.025), (-(w + 0.025), -0.04),
           (-(w + 0.025), -0.3)]
    for (xa, za), (xb, zb) in zip(pts, pts[1:]):
        P.bar((xa, y, za), (xb, y, zb), 0.06, 0.06, "fur_black", up=(0, 1, 0))
    for sx in (-1, 1):
        a, m, t = Vector((sx * 0.13, y, 0.04)), Vector((sx * 0.2, y - 0.05, 0.25)), Vector((sx * 0.3, y - 0.02, 0.42))
        P.bar(tuple(a), tuple(m + (m - a).normalized() * 0.015), 0.035, 0.035, "fur_black", up=(0, 1, 0))
        P.bar(tuple(m), tuple(t), 0.035, 0.035, "fur_black", up=(0, 1, 0))
        P.ico(tuple(t + (t - m).normalized() * 0.05), 0.075, "sparkle")


def _cape_body(ctx, cloth, collar):
    """hero_cape's shape (the same collar, back and flare) in another cloth, for the second-prop capes. Returns
    what the trims need: on A the back pen and the body's half sizes; on B the up pen, the run down the back (a, b),
    its outward normal and tilt, and the haunches' back and top in that frame."""
    if ctx.body == "walk":
        P = ctx.pen("back")
        (x0, y0, zc), (sx, sy, sz) = ctx.d["body"]
        hx, hy = sx / 2, sy / 2
        P.box((0, -0.2, 0.06), (sx * 0.9, 0.16, 0.12), collar)                                  # collar
        P.bar((0, -0.2, 0.04), (0, hy - 0.05, 0.03), sx + 0.08, 0.035, cloth, up=(0, 0, 1))
        for side in (-1, 1):                                                                    # over the flanks
            P.bar((side * (hx + 0.02), -0.12, 0.0), (side * (hx + 0.09), hy - 0.08, -0.16), 0.035, 0.22, cloth,
                  up=(side, 0, 0))
        P.bar((0, hy - 0.08, 0.03), (0, hy + 0.32, 0.12), sx + 0.2, 0.035, cloth, up=(0, 0, 1))   # lifting behind
        return P, hx, hy, sx
    U = ctx.pen("up")
    hb, ht = ctx.haunch_back - B_BACK_Y, ctx.haunch_top - 0.98
    U.box((0, 0.0, 0.08), (0.72, 0.12, 0.12), collar)                                             # collar
    a, b = Vector((0, 0.06, 0.1)), Vector((0, hb - 0.16, ht + 0.02))
    U.bar(tuple(a), tuple(b), 0.86, 0.04, cloth, up=(0, 1, 0))                                   # down the back
    U.bar((0, hb - 0.18, ht + 0.025), (0, hb + 0.035, ht - 0.04), 0.9, 0.04, cloth, up=(0, 1, 1))   # over the haunches
    U.bar((0, hb + 0.03, ht - 0.03), (0, hb + 0.07, 0.04 - 0.98), 0.94, 0.04, cloth, up=(0, 1, 0))  # to the floor
    n = Vector((0, (b - a).z, -(b - a).y)).normalized()
    if n.y < 0:
        n = -n
    tilt = math.degrees(math.atan2(n.z, n.y))
    return U, a, b, n, tilt, hb, ht


def royal_cape(ctx):
    """Bottlecap, King Cat's second prop: a royal violet cape with an ermine collar and hem (white with black
    specks) and a red bottle cap for its clasp."""
    cloth, ermine, speck = "aurora_violet", "offwhite", "fur_black"
    if ctx.body == "walk":
        P, hx, hy, sx = _cape_body(ctx, cloth, ermine)
        for x in (-0.24, -0.08, 0.08, 0.24):                                                   # specks on the collar
            P.box((x * sx / 0.78, -0.2 + 0.03 * (x > 0), 0.123), (0.03, 0.05, 0.012), speck)
        R = _rx(12.7)                                                                            # the lifted hem's slope
        hem = Vector((0, hy + 0.29, 0.113))
        P.box(tuple(hem), (sx + 0.24, 0.12, 0.06), ermine, rot=R)                               # ermine hem
        for x in (-0.3, -0.1, 0.1, 0.3):
            P.box(tuple(hem + R @ Vector((x * (sx + 0.2) / 0.8, 0.0, 0.034))), (0.03, 0.05, 0.012), speck, rot=R)
        P.cyl((0, -0.29, 0.06), 0.07, 0.04, "bowl_red", rot=_rx(90), segments=10)              # bottle cap clasp
        P.cyl((0, -0.312, 0.06), 0.04, 0.008, "offwhite", rot=_rx(90), segments=10)
        return
    U, a, b, n, tilt, hb, ht = _cape_body(ctx, cloth, ermine)
    for x in (-0.24, -0.08, 0.08, 0.24):
        U.box((x, 0.02 * (1 if x > 0 else -1), 0.143), (0.03, 0.05, 0.012), speck)
    U.box((0, hb + 0.065, -0.875), (0.98, 0.07, 0.14), ermine)                                  # ermine hem
    for x in (-0.36, -0.12, 0.12, 0.36):
        U.box((x, hb + 0.1, -0.875), (0.03, 0.012, 0.05), speck)
    U.cyl((0, -0.07, 0.08), 0.07, 0.04, "bowl_red", rot=_rx(90), segments=10)                  # clasp, at the front
    U.cyl((0, -0.092, 0.08), 0.04, 0.008, "offwhite", rot=_rx(90), segments=10)


def leaf_cloak(ctx):
    """OldOak, Antler Cat's second prop: a cloak of leaves, dark green with overlapping green and autumn leaves on
    it, a vine collar and a hem of leaf points."""
    cloth, vine = "leaf_dark", "leaf_green"
    cols = ("leaf_green", "caramel_wood", "leaf_green", "pastel_butter", "leaf_green")
    if ctx.body == "walk":
        P, hx, hy, sx = _cape_body(ctx, cloth, vine)
        for i, (x, y) in enumerate(((-0.22, -0.02), (0.18, 0.04), (-0.02, 0.16), (0.26, 0.26), (-0.24, 0.3),
                                    (0.04, 0.36))):
            z = 0.04 + (0.03 - 0.04) * (y + 0.2) / (hy + 0.15) + 0.0175 + 0.009
            P.box((x, y, z), (0.1, 0.17, 0.018), cols[i % len(cols)], rot=_rz(25 * (-1) ** i))     # leaves
        R = _rx(12.7)
        for x in (-0.36, -0.18, 0.0, 0.18, 0.36):                                              # leaf points at the hem
            P.box(tuple(Vector((x * (sx + 0.2) / 0.88, hy + 0.32, 0.12)) + R @ Vector((0, 0.05, 0))),
                  (0.11, 0.11, 0.03), cloth, rot=R @ _rz(45))
        return
    U, a, b, n, tilt, hb, ht = _cape_body(ctx, cloth, vine)
    face = _rx(-90 + tilt)
    for i, (x, f) in enumerate(((-0.25, 0.15), (0.2, 0.25), (-0.05, 0.45), (0.28, 0.62), (-0.3, 0.7), (0.05, 0.85))):
        c = a + (b - a) * f + n * 0.027 + Vector((x, 0, 0))
        U.box(tuple(c), (0.1, 0.17, 0.018), cols[i % len(cols)], rot=face @ _rz(25 * (-1) ** i))
    for x in (-0.38, -0.19, 0.0, 0.19, 0.38):                                                   # leaf points at the hem
        U.box((x, hb + 0.065, -0.89), (0.12, 0.05, 0.12), cloth, rot=_ry(45))


def pickaxe(ctx):
    """Lantern, Miner Cat's second prop: a miner's pickaxe slung on its back, a wooden handle with a dark grip and a
    curved metal head, on a strap."""
    walk = ctx.body == "walk"
    if walk:
        P = ctx.pen("back")
        p0, R, L = _plane((0.22, 0.42, 0.018), (-0.17, -0.1, 0.018), (0, 0, 1))
    else:
        P = ctx.pen("up")
        yc = B_CLEAR + 0.03
        p0, R, L = _plane((0.25, yc, -0.32), (-0.17, yc, 0.3), (0, 1, 0))

    def at(x, y, z=0.0):
        return tuple(p0 + R @ Vector((x, y, z)))
    P.box(at(0, L / 2), (0.07, L, 0.05), "caramel_wood", rot=R)                               # handle
    P.box(at(0, 0.16), (0.085, 0.22, 0.06), "dark_wood", rot=R)                               # grip
    P.box(at(0, L - 0.02), (0.11, 0.12, 0.075), "fur_black", rot=R)                           # the eye of the head
    for sx in (-1, 1):
        P.box(at(sx * 0.16, L - 0.035), (0.24, 0.07, 0.055), "metal", rot=R @ _rz(-sx * 12))  # arms of the pick
        P.box(at(sx * 0.3, L - 0.085), (0.1, 0.05, 0.045), "metal", rot=R @ _rz(-sx * 32))    # points, curving down
    if walk:
        _strap_round(ctx, "dark_wood", at_y=(p0 + R @ Vector((0, L / 2, 0))).y)
    else:
        z = -0.1
        x = 0.25 + (z + 0.32) / 0.62 * (-0.42)
        _sling(ctx, "dark_wood", xs=(x,), down=0.155 - z + 0.03)
        P.box((x, B_CLEAR + 0.03, z), (0.11, 0.08, 0.07), "dark_wood")


def rubber_duck(ctx):
    """Bubbles, Bubble Cat's second prop: a yellow rubber duck sitting on its head in a little heap of bath foam,
    an orange beak, an upturned tail and shiny eyes."""
    P = ctx.pen("head")
    yel = "rarity_legend"
    for (x, y, r) in ((-0.19, -0.06, 0.08), (0.18, 0.08, 0.085), (0.04, -0.22, 0.07), (-0.11, 0.2, 0.07),
                      (0.21, -0.13, 0.06)):
        P.ico((x, y, 0.025), r, "milk", scale=(1, 1, 0.7))                                     # bath foam
    P.sphere((0, 0.03, 0.13), 0.19, yel, scale=(1, 1.25, 0.72), segments=12, rings=6)          # body
    P.cyl((0, 0.25, 0.2), 0.085, 0.16, yel, r2=0.02, rot=_rx(-40), segments=8)                 # upturned tail
    for sx in (-1, 1):
        P.sphere((sx * 0.16, 0.06, 0.15), 0.09, "pastel_butter", scale=(0.4, 1.0, 0.6), segments=8, rings=4)  # wings
    P.sphere((0, -0.12, 0.31), 0.13, yel, segments=12, rings=6)                                 # head
    P.box((0, -0.265, 0.29), (0.15, 0.1, 0.045), "eye_copper")                                 # beak
    for sx in (-1, 1):
        P.box((sx * 0.06, -0.225, 0.35), (0.04, 0.03, 0.05), "fur_black")                     # eyes
        P.box((sx * 0.06 + 0.01, -0.243, 0.362), (0.014, 0.008, 0.014), "milk")


def gear_top_hat(ctx):
    """Gears, Steampunk Cat's second prop: a brown top hat with a brass band and a brass gear on its side."""
    P = ctx.pen("head")
    P.cyl((0, 0, 0.005), 0.36, 0.05, "choco", segments=14)                                     # brim
    P.cyl((0, 0, 0.22), 0.235, 0.4, "choco", segments=12)                                      # crown
    P.cyl((0, 0, 0.09), 0.242, 0.07, "brass", segments=12)                                     # band
    R = _rz(-30)                                                                                # front right
    n = R @ Vector((0, -1, 0))
    c = R @ Vector((0, -0.232, 0.26))
    face = R @ _rx(90)
    P.cyl(tuple(c), 0.075, 0.05, "bronze", rot=face, segments=8)                               # hub, half in the crown
    P.ring(tuple(c + n * 0.035), 0.12, 0.04, 0.03, "brass", rot=face, segments=12)             # the gear
    u, v = R @ Vector((1, 0, 0)), Vector((0, 0, 1))
    for k in range(8):
        a = math.radians(45 * k + 22.5)
        P.box(tuple(c + n * 0.035 + (u * math.cos(a) + v * math.sin(a)) * 0.135), (0.045, 0.028, 0.04), "brass",
              rot=R @ _ry(-math.degrees(a)))                                                     # its teeth
    P.cyl(tuple(c + n * 0.05), 0.025, 0.012, "bronze", rot=face, segments=6)                   # a rivet


def air_tank(ctx):
    """Glimmer, Diver Cat's second prop: a yellow air tank with blue bands, a metal valve and a black hose, lying
    along A's back and standing on B's haunches."""
    yel, band = "rarity_legend", "shirt_blue"
    if ctx.body == "walk":
        P = ctx.pen("back")
        r, zc, y0, y1 = 0.12, 0.115, -0.1, 0.36
        along = _rx(90)
        P.cyl((0, (y0 + y1) / 2, zc), r, y1 - y0, yel, rot=along, segments=10)                 # the tank
        P.sphere((0, y1, zc), r, yel, scale=(1, 1, 1), segments=10, rings=5)                    # round back end
        P.sphere((0, y0, zc), r, yel, scale=(1, 1, 1), segments=10, rings=5)                    # round front end
        for y in (0.02, 0.24):
            P.cyl((0, y, zc), r + 0.008, 0.05, band, rot=along, segments=10)
        P.cyl((0, y0 - 0.15, zc), 0.035, 0.1, "metal", rot=along, segments=8)                   # valve
        P.cyl((0, y0 - 0.17, zc + 0.045), 0.05, 0.03, "fur_black", segments=8)                  # its knob
        h = [Vector((0.03, y0 - 0.17, zc)), Vector((0.25, y0 - 0.16, zc - 0.02)), Vector((0.42, y0 - 0.05, -0.05))]
        for p, q in zip(h, h[1:]):
            P.bar(tuple(p), tuple(q + (q - p).normalized() * 0.02), 0.05, 0.05, "fur_black")   # hose
        _strap_round(ctx, "fur_black", at_y=0.13)
        return
    U = ctx.pen("up")
    r, yc = 0.12, B_CLEAR + 0.13
    z0 = ctx.haunch_top - 0.98 - 0.005
    z1 = 0.1
    U.cyl((0, yc, (z0 + z1) / 2), r, z1 - z0, yel, segments=10)
    U.sphere((0, yc, z1), r, yel, scale=(1, 1, 0.55), segments=10, rings=5)
    for z in (-0.3, -0.04):
        U.cyl((0, yc, z), r + 0.008, 0.05, band, segments=10)
    U.cyl((0, yc, z1 + 0.09), 0.035, 0.1, "metal", segments=8)                                 # valve
    U.cyl((0, yc, z1 + 0.15), 0.05, 0.03, "fur_black", segments=8)
    h = [Vector((0, yc, z1 + 0.1)), Vector((-0.22, yc - 0.03, z1 + 0.12)), Vector((-0.3, -0.06, 0.15))]
    for p, q in zip(h, h[1:]):
        U.bar(tuple(p), tuple(q + (q - p).normalized() * 0.02), 0.05, 0.05, "fur_black")         # hose over the shoulder
    _sling(ctx, "fur_black", down=0.32)


def dragon_horns(ctx):
    """Eclipse, Dragon Cat's second prop: two little curved horns, cream with mint ridges, sweeping back between
    the ears."""
    P = ctx.pen("head")
    for sx in (-1, 1):
        at, a = Vector((sx * 0.13, -0.12, -0.02)), -25
        for k, (r1, r2, hgt, turn) in enumerate(((0.095, 0.065, 0.19, 0), (0.065, 0.0, 0.22, -30))):
            a += turn
            R = _ry(sx * 16) @ _rx(a)
            d = R @ Vector((0, 0, 1))
            P.cyl(tuple(at + d * hgt / 2), r1, hgt, "cream", r2=r2, rot=R, segments=8)
            if k == 0:
                P.cyl(tuple(at + d * 0.08), r1 - 0.006, 0.035, "mint", rot=R, segments=8)  # a ridge
            at = at + d * (hgt - 0.02)


# name -> (slot, builder). data-model 3a (Alleyway), 3b (Park), 3c (Neighbourhood, Woods, Sewer).
# ------------------------------------------------------------------------------- F96 the Bellhop Cat --
CAP_R, CAP_H = 0.22, 0.28                  # the pillbox, head-frame units
# its base centre and tilt: the low side 0.025 into the head and the high side 0.005, so the tilted cap leaves no gap
# and does not sink into the head (Derek 11-02: the cap was "colliding with top of head")
CAP_AT, CAP_ROLL = (0.0, -0.03, -0.01), 4
STRAP_Y = 0.52                             # face-frame y of the chin strap: behind the ears, under the cap's back edge


def _cap_q(q):
    """A point on the Bellhop's cap (x across, y back, z up from its base centre) in the head frame."""
    return tuple(Vector(CAP_AT) + _ry(CAP_ROLL) @ Vector(q))


def bellhop_cap(ctx):
    """F96 Bellhop Cat (starter-cat.md section 1): a red pillbox cap tilted a little to its left, a gold band round
    the base, a modelled gold braid round the top edge (a gold cord with fourteen slanted brass twists on it), a
    gold button on top and a gold paw badge on the front. The object pivots at the back of the cap's base, the
    hinge for the cap tip and the sleepy cap-over-the-eyes (turn the _Prop Model about its pivot's X: the tip about
    +20 degrees, front up; asleep -40 degrees, then move it 0.13 up and 0.39 forward times the cat's scale, so it tips
    over the brow edge, outside the face)."""
    ctx.pivot_at("head", _cap_q((0, CAP_R, 0)))
    P, R = ctx.pen("head"), _ry(CAP_ROLL)
    P.cyl(_cap_q((0, 0, CAP_H / 2)), CAP_R, CAP_H, "shirt_red", rot=R, segments=14)                  # crown
    P.cyl(_cap_q((0, 0, 0.05)), CAP_R + 0.015, 0.06, "rarity_legend", rot=R, segments=14)            # band
    n, ro, zt = 14, CAP_R + 0.03, CAP_H - 0.018                   # the cord stands a hair proud of the top
    P.ring(_cap_q((0, 0, zt)), ro, 0.05, 0.05, "rarity_legend", rot=R, segments=n)                    # braid cord
    flat = ro * math.cos(math.pi / n)                                                                  # its flat faces
    for i in range(n):                                                                                # the twists
        a = 2 * math.pi * (i + 0.5) / n
        P.box(_cap_q((flat * math.cos(a), flat * math.sin(a), zt)), (0.014, 0.075, 0.016), "brass",
              rot=R @ _rz(math.degrees(a)) @ _rx(-40))
    P.cyl(_cap_q((0, 0, CAP_H + 0.015)), 0.05, 0.04, "rarity_legend", rot=R, segments=8)              # button
    fy = -CAP_R * math.cos(math.pi / 14) - 0.008                                                       # flat front face
    P.box(_cap_q((0, fy, 0.135)), (0.085, 0.02, 0.065), "rarity_legend", rot=R)                       # paw badge
    for x, z in ((-0.05, 0.18), (0.0, 0.195), (0.05, 0.18)):
        P.box(_cap_q((x, fy, z)), (0.03, 0.02, 0.03), "rarity_legend", rot=R)


def bellhop_collar(ctx):
    """F96 Bellhop Cat's second prop: a red collar round the bottom of the head (the chibi cats' neck), proud of the
    front and sides and stopping short of the back, where the Entertainer's cape collar sits; a gold tab at the front;
    a black chin strap from under the cap's back edge, behind the ears, down each side into the collar. The brass
    bell is its own object, `<name>_Bell`, pivoted where it hangs from the tab, to swing about its pivot."""
    F = ctx.pen("face")
    fw, fd, top, bot = ctx.fw, ctx.fd, ctx.ftop, ctx.fbot
    rise = 0.025 if ctx.work else 0.0                   # S: the sides sit higher so a waving arm clears them
    lo, hi = bot - 0.008, bot + 0.05
    F.box((0, 0.012, (lo + hi) / 2), (2 * fw + 0.03, 0.078, hi - lo), "shirt_red")                    # front
    for sx in (-1, 1):
        F.box((sx * (fw - 0.0175), (fd - 0.07 - 0.027) / 2, (lo + hi) / 2 + rise), (0.065, fd - 0.07 + 0.027, hi - lo),
              "shirt_red")                                                                             # sides
        F.box((sx * (0.12 + fw + 0.0125) / 2, STRAP_Y, top + 0.004), (fw + 0.0125 - 0.12, 0.045, 0.025),
              "fur_black")                                                                             # strap
        F.box((sx * (fw + 0.0045), STRAP_Y, (hi - 0.01 + top + 0.012) / 2), (0.025, 0.045, top + 0.012 - hi + 0.01),
              "fur_black")
    F.box((0, -0.03, bot - 0.012), (0.075, 0.04, 0.05), "rarity_legend")                              # tab
    B = ctx.piece("Bell", "face", (0, -0.03, bot - 0.034))
    B.ring((0, -0.03, bot - 0.07), 0.04, 0.016, 0.018, "brass", rot=_rx(90), segments=8)              # loop
    B.sphere((0, -0.03, bot - 0.175), 0.088, "rarity_legend", segments=10, rings=6)                   # bell
    B.ring((0, -0.03, bot - 0.168), 0.093, 0.014, 0.02, "brass", segments=10)                         # seam
    B.box((0, -0.03, bot - 0.215), (0.12, 0.15, 0.02), "choco")                                      # slot


# --------------------------------------------------------------------- #1191 the shop-only cats --
PASTRY_AT, PASTRY_ROLL = (0.07, -0.02, -0.02), 16       # Sprinkles' toque: base centre (head frame) and tilt to its left


def _pastry_q(q):
    return tuple(Vector(PASTRY_AT) + _ry(PASTRY_ROLL) @ Vector(q))


def pastry_hat(ctx):
    """#1191 Sprinkles, the Starter Bundle cat: a new baker's pastry chef hat, a short puffy white toque tipped over
    its left ear (the low side 0.02 into the head so no gap shows), an apron_pink band with five sprinkles on it.
    Kept smaller than the Chef Cat's tall toque, so the two read apart."""
    P, R = ctx.pen("head"), _ry(PASTRY_ROLL)
    P.cyl(_pastry_q((0, 0, 0.06)), 0.25, 0.12, "apron_pink", rot=R, segments=12)                      # band
    P.cyl(_pastry_q((0, 0, 0.2)), 0.235, 0.18, "milk", rot=R, segments=12, r2=0.27)                     # crown
    for (x, y, z, r) in ((0.12, 0.0, 0.33, 0.14), (-0.12, 0.0, 0.33, 0.14), (0.0, 0.12, 0.33, 0.14),
                         (0.0, -0.12, 0.33, 0.14), (0.0, 0.0, 0.38, 0.15)):
        P.ico(_pastry_q((x, y, z)), r, "milk")                                                         # puffs
    cols = ("neon_pink", "sign_teal", "rarity_legend", "shirt_blue", "mint")
    for i in range(5):                                                                                 # sprinkles
        a = math.radians(-150 + i * 30)                                 # round the front of the band
        x, y = 0.255 * math.cos(a), 0.255 * math.sin(a)
        P.box(_pastry_q((x, y, 0.06 + 0.025 * (i % 2 * 2 - 1))), (0.06, 0.012, 0.022), cols[i],
              rot=R @ _rz(math.degrees(a) + 90) @ _ry(35 * (1 if i % 2 else -1)))


def pearl_tiara(ctx):
    """#1191 Duchess Marzipan, the Royal cat: a little pearl tiara between the ears, a pearl band toward the front of
    the head top with a row of pearls rising to three points, the tallest a big pearl over a lilac gem; every pearl
    sits on the band or on a point."""
    P = ctx.pen("head")
    y = -0.14                                            # toward the front of the head top, between the ears
    P.box((0, y, 0.025), (0.44, 0.06, 0.05), "pearl")                                               # band
    for x in (-0.18, -0.12, -0.06, 0.06, 0.12, 0.18):                                               # pearls on it
        P.ico((x, y - 0.015, 0.07), 0.035, "pearl")
    for x, h in ((-0.12, 0.09), (0.12, 0.09), (0.0, 0.15)):                                         # the points
        P.box((x, y, 0.05 + h / 2), (0.05, 0.035, h), "pearl", rot=_ry(45) if x == 0 else None)
        P.ico((x, y, 0.05 + h + 0.035), 0.045 if x else 0.065, "pearl")
    P.box((0, y - 0.03, 0.11), (0.06, 0.02, 0.06), "velvet_lilac", rot=_ry(45))                     # gem


def velvet_cape(ctx):
    """#1191 Duchess Marzipan's second prop: a lilac velvet cape with a cream collar and hem and a pearl clasp,
    on hero_cape's shape like the other second-prop capes."""
    cloth, trim = "velvet_lilac", "cream"
    if ctx.body == "walk":
        P, hx, hy, sx = _cape_body(ctx, cloth, trim)
        R = _rx(12.7)                                                                            # the lifted hem's slope
        P.box((0, hy + 0.29, 0.113), (sx + 0.24, 0.12, 0.06), trim, rot=R)                     # hem
        P.ico((0, -0.3, 0.06), 0.06, "pearl")                                                   # clasp
        return
    U, a, b, n, tilt, hb, ht = _cape_body(ctx, cloth, trim)
    U.box((0, hb + 0.065, -0.875), (0.98, 0.07, 0.14), trim)                                    # hem
    U.ico((0, -0.08, 0.08), 0.06, "pearl")                                                      # clasp, at the front


CROWN_TOP = 0.42                        # King Croissant's crown: its top in head-frame units (CrownTop Attachment)


def king_crown(ctx):
    """#1191 King Croissant, the King cat: a small gold crown, smaller and plainer than the Bottlecap King's, a gold
    band with five points round it, a gold ball on each point and three jewel dots on the front of the band (ruby,
    sapphire, emerald). The Attachment CrownTop sits on its top for VFX's pay pop (build_all, ATTACH)."""
    P = ctx.pen("head")
    P.cyl((0, 0, 0.06), 0.24, 0.12, "gold_mid", segments=14)                                        # band
    P.cyl((0, 0, 0.005), 0.255, 0.03, "gold_dark", segments=14)                                      # its rim
    for i in range(5):                                                                               # points
        R = _rz(i * 72)
        P.pyramid(tuple(R @ Vector((0, -0.2, 0.2))), 0.16, 0.2, "gold_mid", rot=R @ _rx(-6) @ _rz(45))
        P.ico(tuple(R @ Vector((0, -0.205, 0.32))), 0.04, "gold_light")
    for x, sw in ((-0.11, "bowl_red"), (0.0, "shirt_blue"), (0.11, "leaf_green")):                   # jewels
        P.ico((x, -0.235, 0.06), 0.04, sw)
    P.ico((0, 0, 0.14), 0.21, "shirt_red", scale=(1.0, 1.0, 0.9))                                   # velvet cap
    P.ico((0, 0, CROWN_TOP - 0.05), 0.05, "gold_light")                                             # bead, on the cap


def king_cape(ctx):
    """#1191 King Croissant's second prop: a red cape with a gold collar and a gold clasp, on hero_cape's shape like
    the other capes, and its white trim with gold dots at the hem as its own object `<name>_CapeTrim` (ctx.piece),
    so VFX can scroll a texture along it."""
    cloth, collar, trim, dot = "shirt_red", "gold_mid", "offwhite", "rarity_legend"
    if ctx.body == "walk":
        P, hx, hy, sx = _cape_body(ctx, cloth, collar)
        R = _rx(12.7)                                                                            # the lifted hem's slope
        hem = Vector((0, hy + 0.29, 0.113))
        T = ctx.piece("CapeTrim", "back", tuple(hem))
        T.box(tuple(hem), (sx + 0.24, 0.12, 0.06), trim, rot=R)
        for x in (-0.3, -0.1, 0.1, 0.3):
            T.box(tuple(hem + R @ Vector((x * (sx + 0.2) / 0.8, 0.0, 0.034))), (0.04, 0.04, 0.012), dot, rot=R)
        P.cyl((0, -0.29, 0.06), 0.07, 0.04, "gold_light", rot=_rx(90), segments=10)              # clasp
        return
    U, a, b, n, tilt, hb, ht = _cape_body(ctx, cloth, collar)
    hem = (0, hb + 0.065, -0.875)
    T = ctx.piece("CapeTrim", "up", hem)
    T.box(hem, (0.98, 0.07, 0.14), trim)
    for x in (-0.36, -0.12, 0.12, 0.36):
        T.box((x, hb + 0.1, -0.875), (0.04, 0.012, 0.04), dot)
    U.cyl((0, -0.07, 0.08), 0.07, 0.04, "gold_light", rot=_rx(90), segments=10)                 # clasp, at the front


PROPS = {
    "Calico": ("Face", eye_patch), "Tortie": ("Back", guitar), "Sphynx": ("Head", headphones),
    "MaineCoon": ("Face", bandit_mask), "Void": ("Head", ninja_band), "Midnight": ("Head", wizard_hat),
    "Siamese": ("Face", round_glasses), "Bengal": ("Head", safari_hat), "Ragdoll": ("Head", nightcap),
    "Persian": ("Head", top_hat), "Blossom": ("Back", fairy_wings), "Aurora": ("Head", bubble_helmet),
    "Munchkin": ("Back", skateboard), "Fold": ("Head", beret), "Chonk": ("Head", chef_hat), "Postie": ("Head", mail_cap),
    "Marshmallow": ("Back", hero_cape), "Comet": ("Head", ice_cream_hat),
    "Pinecone": ("Back", backpack), "ForestCat": ("Head", plaid_cap), "Toadstool": ("Head", mushroom_cap),
    "Firefly": ("Back", firefly_jar), "OldOak": ("Head", antlers), "Wisp": ("Head", unicorn_horn),
    "Lantern": ("Head", hard_hat), "Bubbles": ("Face", bubble_pipe), "Gears": ("Face", brass_goggles),
    "Glimmer": ("Face", snorkel_mask), "Bottlecap": ("Head", bottlecap_crown), "Eclipse": ("Back", dragon_wings),
    # v0.13 area-themed cats (F78)
    "Binbag": ("Back", bin_bag), "Taxi": ("Head", taxi_light), "Neon": ("Head", fedora),
    "Birdwatch": ("Face", binoculars), "Duckling": ("Head", duckling), "Balloon": ("Back", balloons),
    "Builder": ("Head", hard_hat_pencil), "Gardener": ("Head", sun_hat), "Gnome": ("Head", gnome_hat),
    "Plumber": ("Head", work_cap),
    # F96 the free Bellhop Cat
    "BellhopCat": ("Head", bellhop_cap),
    # #1191 the shop-only cats
    "Sprinkles": ("Head", pastry_hat),
    "DuchessMarzipan": ("Head", pearl_tiara),
    "KingCroissant": ("Head", king_crown),
}
# Second props (data-model 3, v0.10 and v0.13: "one or two props is fine"), in a different slot from the first: the
# object is `..._Prop2` and the model's PropSlot2 attribute names its slot.
PROPS2 = {
    "Neon": ("Back", saxophone), "Gardener": ("Back", watering_can), "Gnome": ("Face", gnome_beard),
    "Plumber": ("Back", wrench),
    # Set 4 Q2 (Derek 2026-10-29): the Neighbourhood, Woods and Sewer cats; the Unicorn Cat keeps just its horn
    "Munchkin": ("Head", backwards_cap), "Fold": ("Face", paintbrush), "Chonk": ("Face", curly_moustache),
    "Postie": ("Face", letter), "Marshmallow": ("Face", hero_mask), "Comet": ("Face", sprinkle_sunglasses),
    "Pinecone": ("Head", ranger_hat), "ForestCat": ("Back", log_bundle), "Toadstool": ("Back", back_mushrooms),
    "Firefly": ("Head", glow_antennae), "OldOak": ("Back", leaf_cloak), "Lantern": ("Back", pickaxe),
    "Bubbles": ("Head", rubber_duck), "Gears": ("Head", gear_top_hat), "Glimmer": ("Back", air_tank),
    "Bottlecap": ("Back", royal_cape), "Eclipse": ("Head", dragon_horns),
    # F96: the Bellhop's collar sits at the chin, so it is a Face prop and no role piece comes off for it
    "BellhopCat": ("Face", bellhop_collar),
    # #1191: Duchess Marzipan's velvet cape
    "DuchessMarzipan": ("Back", velvet_cape),
    "KingCroissant": ("Back", king_cape),
}
# Extra objects a prop draws (Ctx.piece): cat -> {suffix: the prop object it hangs from}. They ride what that prop
# rides, and their Roblox Model nests inside that prop's Model.
PIECES = {"BellhopCat": {"Bell": "Prop2"}, "KingCroissant": {"CapeTrim": "Prop2"}}
# Extra Attachments for VFX (#1191): cat -> [(object suffix, Attachment name, frame, point in that frame)]. Frame
# "head" is the head-top frame the Head props draw in; "chest" puts it at the middle of the chest (B, S) or body (A).
ATTACH = {"KingCroissant": [("_Prop", "CrownTop", "head", (0.0, 0.0, CROWN_TOP)), ("_Body", "Glow", "chest", None)]}


# A cat with a second prop gets 1,800 triangles in place of 1,500 (style guide section 5): two props and a Mythical
# coat do not fit the single-prop budget. Set here because cats.py cannot import this module at load time.
# A cat wearing two props gets 1,800 triangles instead of 1,500 (style guide section 5), gold twins too.
TWO_PROP_BUDGET = 1800
for _table in (cats.ASSETS, gold.ASSETS):
    for _asset, (_fn, _budget) in list(_table.items()):
        if cats.parse(_asset)[0] in PROPS2:
            _table[_asset] = (_fn, max(_budget, TWO_PROP_BUDGET))


def build(name, spec, body, d):
    """{object suffix: (Builder, pivot)} for one cat's props on one body: "Prop", plus "Prop_Glass" when it has clear
    parts, "Prop2" for a second prop and any extra pieces (PIECES). Head and Face props are drawn relative to the neck
    (the Head's pivot), Back props in the model's space; `pivot` is where the object pivots in that space, (0, 0, 0)
    unless the prop set its own hinge (Ctx.pivot_at, Ctx.piece). Body "work" (S) draws on the sitting frames."""
    out = {}
    for key, table in (("Prop", PROPS), ("Prop2", PROPS2)):
        if name not in table:
            continue
        ctx = Ctx(spec, "sit" if body == "work" else body, d)
        ctx.work = body == "work"
        table[name][1](ctx)
        out[key] = (ctx.main, tuple(ctx.origin))
        if ctx.glass.prims:
            assert key == "Prop", "second props have no clear parts"
            out["Prop_Glass"] = (ctx.glass, tuple(ctx.origin))
        for suffix, (b, at) in ctx.extra.items():
            assert PIECES.get(name, {}).get(suffix) == key, f"{name}: list {suffix} in PIECES"
            out[suffix] = (b, tuple(at))
    return out


def slot(name):
    return PROPS[name][0] if name in PROPS else None


def slot2(name):
    return PROPS2[name][0] if name in PROPS2 else None


def piece_slot(name, suffix):
    """The slot of one of a cat's prop objects ("Prop", "Prop_Glass", "Prop2" or an extra piece's suffix)."""
    suffix = PIECES.get(name, {}).get(suffix, suffix)
    return slot2(name) if suffix == "Prop2" else slot(name)


def follows(slot_):
    """What a prop in this slot rides: Back props the Body, Head and Face props the Head."""
    return "Body" if slot_ == "Back" else "Head"
