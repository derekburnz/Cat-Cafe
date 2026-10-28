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
        self.main, self.glass = Builder(), Builder()
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
        return Pen(self.main, at, R, s)

    def gpen(self, frame):
        at, R, s = self._frames[frame]
        return Pen(self.glass, at, R, s)

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


def _shoulder_straps(ctx, sw, xs=(-0.2, 0.2)):
    """B: two straps over the top of the chest from the back, ending under the head (clear of the role outfits)."""
    P = ctx.pen("up")
    for x in xs:
        P.box((x, -0.11, 0.125), (0.09, 0.26, 0.04), sw)              # along the chest top (z 1.1), under the chin
        P.box((x, 0.02, -0.02), (0.09, 0.05, 0.3), sw)                # down the back to the prop


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
    cz = -ctx.hh / 2 + 0.1
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
def _b_straps(ctx, sw):
    if ctx.body == "sit":
        _shoulder_straps(ctx, sw)


def guitar(ctx):
    """Tortie, Rocker Cat: a red mini electric guitar slung across the back, neck toward the left shoulder."""
    P = ctx.pen("back")
    # On A the neck runs back past the hip so it shows beside the body from the front and behind (pointed at the
    # head it hid under it); on B it goes up over the left shoulder.
    walk = ctx.body == "walk"
    R = _rz(-55 if walk else 55)
    o, lift, d = 0.07, (0.0 if walk else -0.06), (-1 if walk else 1)

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
        _shoulder_straps(ctx, "fur_black", xs=(0.2,))


def fairy_wings(ctx):
    """Blossom, Fairy Cat: two pairs of lilac and sky wings from the shoulders, tipped back a little."""
    U = ctx.pen("up")
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

    def at(x, a, o):
        return tuple(R @ Vector((x, a, o)))
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
        _shoulder_straps(ctx, "fur_black")


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
        P.box((0, -0.02, 0.11), (0.5, 0.42, 0.24), "leaf_dark", bevel=True)
        P.box((0, -0.12, 0.24), (0.46, 0.2, 0.03), "leaf_green")
        P.box((0, 0.1, 0.24), (0.3, 0.14, 0.03), "leaf_green")
        P.cyl((0, -0.31, 0.16), 0.11, 0.6, "brick", rot=_ry(90), segments=10)
        for sx in (-1, 1):
            P.cyl((sx * 0.18, -0.31, 0.16), 0.118, 0.04, "dark_wood", rot=_ry(90), segments=10)
        _shoulder_straps(ctx, "dark_wood")


def firefly_jar(ctx):
    """Firefly, Firefly Cat: a glass jar of fireflies standing on the back, a metal lid and a strap."""
    U, G = ctx.pen("up"), ctx.gpen("up")
    if ctx.body == "walk":
        at = (0, 0.25, -0.01)
    else:                                               # against the back, resting on the haunches
        at = (0, 0.205, ctx.haunch_top - 0.98 + 0.01)
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
        _shoulder_straps(ctx, "dark_wood")


def dragon_wings(ctx):
    """Eclipse, Dragon Cat: two little bat-wing dragon wings from the shoulders, green membranes on mint bones."""
    U = ctx.pen("up")
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


# name -> (slot, builder). data-model 3a (Alleyway), 3b (Park), 3c (Neighbourhood, Woods, Sewer).
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
}
# Second props (data-model 3, v0.10 and v0.13: "one or two props is fine"), in a different slot from the first: the
# object is `..._Prop2` and the model's PropSlot2 attribute names its slot.
PROPS2 = {
    "Neon": ("Back", saxophone), "Gardener": ("Back", watering_can), "Gnome": ("Face", gnome_beard),
    "Plumber": ("Back", wrench),
}


def build(name, spec, body, d):
    """{object suffix: Builder} for one cat's props on one body: "Prop", plus "Prop_Glass" when it has clear parts,
    and "Prop2" for a second prop. Head and Face props are drawn relative to the neck (the Head's pivot), Back props
    in the model's space."""
    out = {}
    for key, table in (("Prop", PROPS), ("Prop2", PROPS2)):
        if name not in table:
            continue
        ctx = Ctx(spec, body, d)
        table[name][1](ctx)
        out[key] = ctx.main
        if ctx.glass.prims:
            assert key == "Prop", "second props have no clear parts"
            out["Prop_Glass"] = ctx.glass
    return out


def slot(name):
    return PROPS[name][0] if name in PROPS else None


def slot2(name):
    return PROPS2[name][0] if name in PROPS2 else None


def piece_slot(name, suffix):
    """The slot of one of a cat's prop objects ("Prop", "Prop_Glass" or "Prop2")."""
    return slot2(name) if suffix == "Prop2" else slot(name)


def follows(slot_):
    """What a prop in this slot rides: Back props the Body, Head and Face props the Head."""
    return "Body" if slot_ == "Back" else "Head"
