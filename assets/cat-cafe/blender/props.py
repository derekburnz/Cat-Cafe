"""Themed cats' props (data-model sections 3a to 3c): every Rare-and-up cat wears one prop, baked into all four of its
models (walking, sitting and the gold twins) as its own object, `CatCafe_Cat_<Name>[_Gold][_Sit]_Prop`, plus
`..._Prop_Glass` for clear parts (lenses, bubbles, a jar, a helmet; Glass in Roblox, left out of the Cycles
previews). The model's PropSlot attribute names the slot, and CatPose.dress leaves the role outfit piece in that slot
off (Catalog.outfitPieceSlots): a Head prop replaces the role hat, a Back prop the Entertainer's cape, and a Face prop
clashes with nothing.

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
}


def build(name, spec, body, d):
    """{object suffix: Builder} for one cat's prop on one body: "Prop", plus "Prop_Glass" when it has clear parts.
    Head and Face props are drawn relative to the neck (the Head's pivot), Back props in the model's space."""
    ctx = Ctx(spec, body, d)
    PROPS[name][1](ctx)
    out = {"Prop": ctx.main}
    if ctx.glass.prims:
        out["Prop_Glass"] = ctx.glass
    return out


def slot(name):
    return PROPS[name][0] if name in PROPS else None
