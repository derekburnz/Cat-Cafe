"""Juniper's Mystery Market (#2565, mystery-market.md section 4, look A): a travelling cat's covered wagon parked in
the Town Square's south-west quarter. A deep teal wagon on four big spoked wheels under a round cream canvas hood
with stitched patches, gold stars and wooden hoops, and a MYSTERY MARKET board standing on the ridge. Its front side
folds down into a counter with a cat-eared pedestal in the middle, where the week's featured item turns. Juniper, a
marmalade and custard cat in a berry hood and capelet with gold trim, sits on a step stool at the counter's left (as
a player sees it) under a hanging lantern on a pole, and a string of little lanterns runs from the pole to the
wagon's far end. In front: a round rug and a chalkboard easel reading THIS WEEK SALE!; at the far end a "?" board on
a post (next week's silhouette), a crate and a basket of yarn. The back end has a paw-print door and two steps;
the back side a painted moon and stars.

  CatCafe_Square_MysteryCart                the wagon, counter, pedestal, signs and props (collides), with two
                                            Attachments in its PrimaryPart: PromptAnchor (where WorldBuilder hangs
                                            the MysteryPrompt, before the counter, 3 up) and FeaturedItem (the
                                            pedestal's top centre, where the featured item's model can sit and turn)
  CatCafe_Square_MysteryCart_Bulb           the pole lantern and the string's little lanterns, lit at night
  CatCafe_Square_MysteryCart_Lights_Decor   the lantern string's cord (no collision)
  CatCafe_Square_MysteryCart_Rug_Decor      the round rug on the paving (no collision)
  CatCafe_Square_MysteryCart_Cat_<Piece>    Juniper, the same hinged pieces as every sitting cat; the hood
                                            (_Cat_Prop) rides inside the Head Model, the capelet is _Cat_Cloak

Pivot at the base centre, the counter (-Z) toward the players. The whole model, rug and props included, fits
FOOT (x by z) studs, under the design's 12 x 7, so WalkUpCircles.front puts the ring where the clearance check
expects it; about 7.2 tall to the sign's top.
"""

import math

from mathutils import Matrix, Vector

import cats
import mystery
import props
from alleyway import label
from common import RB, Builder, scale_mesh, text_width
from plot import rot_x, rot_y, rot_z

NAME = "CatCafe_Square_MysteryCart"
FOOT = (10.2, 5.7)                          # the whole model's x and z extent, rug and props included

OX = 0.65                                   # the body's centre x: the props at the -X end shift it so the whole
BX = 3.4                                    # footprint centres on the pivot; the body's half length
BZ = 1.62                                   # its half depth
BY0, BY1 = 1.55, 3.75                       # its bottom and top
HOOD_R = 1.5                                # the canvas hood: a half cylinder on the body's top (its lower half
HOOD_X = BX - 0.12                          # sits inside the body), half length
WHEEL_R, WHEEL_DX, WHEEL_Z = 1.25, 2.2, BZ + 0.2
WHEEL_Y = WHEEL_R + 0.04                    # the rim's blocks reach a hair past its radius: keep them off the floor
BODY = "dumpster_green"                     # deep teal
PANEL = "sign_teal"
GOLD = "rarity_legend"                      # plastic gold: stays bright at dusk (#2449)
WOOD, DARK = "caramel_wood", "dark_wood"
CANVAS = "cream"
CLOAK, TRIM = "royal_berry", "fur_golden"   # Juniper's hood and capelet: not the Mystery Visitor's blue and violet
CTR_X0, CTR_X1 = OX - 3.0, OX + 0.4         # the fold-down counter's ends
CTR_Z0, CTR_Y = -BZ - 1.1, 2.72             # its front edge and top
PED = (OX - 1.3, CTR_Z0 + 0.55)             # the pedestal's (x, z) on the counter
PED_TOP = CTR_Y + 0.82
STOOL = (OX + 2.2, -BZ - 0.85, 1.25)        # Juniper's step stool: x, z, top
POLE = (OX + BX + 0.12, -BZ + 0.12)         # the lantern pole, bolted to the body's front right corner
POLE_TOP = 6.3
FAR_TOP, SAG = 5.9, 0.45            # the far post's top and the lantern string's sag
LAMP = (OX + BX - 0.55, 5.15, -BZ - 0.75)   # the pole lantern's centre
EASEL = (OX - 4.75, -2.7)                   # the chalkboard's (x, z)
QPOST = (OX - 4.9, -0.45)                   # the "?" board's post
SIGN_PX = 0.14
PROMPT_ROBLOX = (OX - 1.3, 3.0, CTR_Z0 - 0.4)
FEATURED_ROBLOX = (PED[0], PED_TOP, PED[1])

# Marmalade and custard patches with green eyes: no collectable cat has this coat (Taxi is marmalade stripes),
# and the hood is berry and gold, so Juniper doesn't read as the Mystery Visitor, the dealer or the fishmonger.
CAT = dict(rarity="Common", fur="fur_marmalade", second="fur_custard", eyes="eye_green", pattern="patches",
           muzzle="fur_custard", nose="nose_brick", scale=1.5)


def _paw(b, x, y, z, s, sw, facing=-1):
    """A paw print on a face at depth z, facing -Z (facing -1) or +Z (facing 1)."""
    b.cyl((x, y - 0.06 * s, z), 0.2 * s, 0.03, sw, axis="Z", segments=8)
    for dx, dy in ((-0.2, 0.16), (-0.07, 0.25), (0.07, 0.25), (0.2, 0.16)):
        b.cyl((x + dx * s, y + dy * s, z), 0.075 * s, 0.03, sw, axis="Z", segments=6)


def _paw_x(b, x, y, z, s, sw):
    """A paw print on a face at x, facing +X."""
    b.cyl((x, y - 0.06 * s, z), 0.2 * s, 0.03, sw, axis="X", segments=8)
    for dz, dy in ((-0.2, 0.16), (-0.07, 0.25), (0.07, 0.25), (0.2, 0.16)):
        b.cyl((x, y + dy * s, z + dz * s), 0.075 * s, 0.03, sw, axis="X", segments=6)


def _star(b, x, y, z, s, sw, axis="Z"):
    """A four-point star on a face: two crossed bars and a diamond, flat across `axis`."""
    t = 0.03
    if axis == "Z":
        b.box((x, y, z), (s, s * 0.22, t), sw)
        b.box((x, y, z), (s * 0.22, s, t), sw)
        b.box((x, y, z), (s * 0.36, s * 0.36, t * 1.2), sw, rot=rot_z(45))
    else:
        b.box((x, y, z), (t, s * 0.22, s), sw)
        b.box((x, y, z), (t, s, s * 0.22), sw)
        b.box((x, y, z), (t * 1.2, s * 0.36, s * 0.36), sw, rot=rot_x(45))


# ------------------------------------------------------------------- body ----

def _wheel(b, x, z):
    side = 1 if z > 0 else -1
    y = WHEEL_Y
    b.b.ring(RB.p(x, y, z), WHEEL_R, 0.24, 0.24, DARK, segments=14, bevel=False, rot=(math.radians(90), "X"))
    for k in range(4):                                                              # four bars make eight spokes
        b.box((x, y, z), (2 * WHEEL_R - 0.3, 0.11, 0.11), WOOD, rot=rot_z(k * 45 + 10))
    b.cyl((x, y, z + side * 0.05), 0.27, 0.3, PANEL, axis="Z", segments=10)
    b.cyl((x, y, z + side * 0.21), 0.13, 0.06, GOLD, axis="Z", segments=8)


def _body(b):
    x0, x1 = OX - BX, OX + BX
    b.span((x0, BY0, -BZ), (x1, BY1, BZ), BODY)
    b.span((x0 - 0.06, BY0 - 0.02, -BZ - 0.06), (x1 + 0.06, BY0 + 0.2, BZ + 0.06), DARK)        # skirt
    b.span((x0 - 0.06, BY1 - 0.02, -BZ - 0.06), (x1 + 0.06, BY1 + 0.1, BZ + 0.06), GOLD)        # top rail
    for x in (x0, x1):                                                                          # corner posts
        for z in (-BZ, BZ):
            b.span((x - 0.09, BY0 + 0.2, z - 0.09), (x + 0.09, BY1 - 0.02, z + 0.09), DARK)
    # the front: an open hatch over the counter (shelves of jars inside), a teal panel either side of it
    b.span((CTR_X0 + 0.12, CTR_Y + 0.02, -BZ - 0.02), (CTR_X1 - 0.12, BY1 - 0.14, -BZ + 0.01), "fur_ink")
    b.span((CTR_X0 + 0.12, 3.18, -BZ - 0.24), (CTR_X1 - 0.12, 3.24, -BZ + 0.02), WOOD)       # the shelf
    for i, sw in enumerate(("mint", "pastel_lilac", "fur_strawberry", "pastel_butter", "sign_teal", "aurora_violet",
                            "pastel_sky")):
        x = CTR_X0 + 0.45 + i * (CTR_X1 - CTR_X0 - 0.9) / 6
        b.cyl((x, 3.36, -BZ - 0.1), 0.1, 0.24, sw, segments=6)                                 # jars on the shelf
        b.cyl((x, 3.5, -BZ - 0.1), 0.07, 0.05, WOOD, segments=6)
    for xa, xb in ((CTR_X0 - 0.06, CTR_X0 + 0.12), (CTR_X1 - 0.12, CTR_X1 + 0.06)):           # the hatch's frame
        b.span((xa, CTR_Y, -BZ - 0.05), (xb, BY1 - 0.02, -BZ + 0.02), GOLD)
    b.span((CTR_X0 - 0.06, BY1 - 0.16, -BZ - 0.05), (CTR_X1 + 0.06, BY1 - 0.02, -BZ + 0.02), GOLD)
    for a, c in ((x0 + 0.3, CTR_X0 - 0.25), (CTR_X1 + 0.25, x1 - 0.3)):                       # side panels
        b.span((a, BY0 + 0.38, -BZ - 0.03), (c, BY1 - 0.22, -BZ + 0.01), PANEL)
    _star(b, (x0 + 0.3 + CTR_X0 - 0.25) / 2, 2.65, -BZ - 0.04, 0.45, GOLD)
    _paw(b, (CTR_X1 + x1) / 2, 2.55, -BZ - 0.04, 1.1, CANVAS)
    # under the counter: a teal panel with a row of gold studs
    b.span((CTR_X0 + 0.05, BY0 + 0.3, -BZ - 0.03), (CTR_X1 - 0.05, CTR_Y - 0.45, -BZ + 0.01), PANEL)
    for i in range(6):
        b.cyl((CTR_X0 + 0.4 + i * (CTR_X1 - CTR_X0 - 0.8) / 5, 2.0, -BZ - 0.045), 0.07, 0.04, GOLD, axis="Z",
              segments=6)
    # the back side: two panels with a painted crescent moon and stars
    for a, c in ((x0 + 0.3, OX - 0.15), (OX + 0.15, x1 - 0.3)):
        b.span((a, BY0 + 0.38, BZ - 0.01), (c, BY1 - 0.22, BZ + 0.03), PANEL)
    b.b.crescent(RB.p(OX - 1.6, 2.65, BZ + 0.045), 0.55, 0.3, 0.04, GOLD, segments=9)
    for x, y, s in ((OX - 0.6, 3.1, 0.35), (OX + 1.0, 2.4, 0.45), (OX + 2.2, 3.05, 0.3), (OX - 2.6, 2.2, 0.28)):
        _star(b, x, y, BZ + 0.04, s, GOLD)
    # the back end (+X): the paw-print door, its knob and two steps
    b.span((x1 - 0.01, BY0 + 0.25, -0.62), (x1 + 0.05, BY1 - 0.12, 0.62), WOOD)
    b.span((x1 + 0.02, BY1 - 0.24, -0.72), (x1 + 0.08, BY1 - 0.08, 0.72), GOLD)
    _paw_x(b, x1 + 0.06, 2.75, 0.0, 1.0, PANEL)
    b.cyl((x1 + 0.1, 2.3, -0.42), 0.07, 0.1, GOLD, axis="X", segments=6)
    for i, (w, top) in enumerate(((0.45, 1.05), (0.9, 0.5))):
        b.span((x1 + 0.06, top - 0.16, -0.55), (x1 + 0.06 + w, top, 0.55), WOOD)
        b.span((x1 + 0.06 + w - 0.12, 0.0, -0.5), (x1 + 0.06 + w, top - 0.16, -0.38), DARK)
        b.span((x1 + 0.06 + w - 0.12, 0.0, 0.38), (x1 + 0.06 + w, top - 0.16, 0.5), DARK)
    # the far end (-X): a teal panel with a star
    b.span((x0 - 0.03, BY0 + 0.38, -BZ + 0.3), (x0 + 0.01, BY1 - 0.22, BZ - 0.3), PANEL)
    _star(b, x0 - 0.04, 2.65, 0.0, 0.5, GOLD, axis="X")


def _under(b):
    """Two axles and the four wheels, a beam along each side, and the tongue folded up under the far end."""
    for dx in (-WHEEL_DX, WHEEL_DX):
        b.cyl((OX + dx, WHEEL_Y, 0), 0.1, 2 * WHEEL_Z - 0.1, DARK, axis="Z", segments=6)
        b.span((OX + dx - 0.25, WHEEL_Y + 0.05, -BZ + 0.2), (OX + dx + 0.25, BY0, BZ - 0.2), DARK)   # bolster
        for z in (-WHEEL_Z, WHEEL_Z):
            _wheel(b, OX + dx, z)
    for z in (-0.5, 0.5):
        b.span((OX - BX + 0.2, BY0 - 0.16, z - 0.1), (OX + BX - 0.2, BY0, z + 0.1), DARK)


def _hood(b):
    """The canvas: a half cylinder (its lower half inside the body), dark hoops, stitched patches and gold stars."""
    # #2647: the hood in two halves, so the body (an unturned box) stays the biggest part: rbx_export makes the biggest
    # part the PrimaryPart, and MarketBang hangs the "!" on the PrimaryPart (a turned hood put it off to the side)
    for s in (-1, 1):
        b.cyl((OX + s * HOOD_X / 2, BY1, 0), HOOD_R, HOOD_X, CANVAS, axis="X", segments=24)
    n, rm = 10, HOOD_R - 0.01                                                       # the hoops: the upper half
    chord = 2 * rm * math.sin(math.radians(90 / n)) * 1.08                          # only, ten blocks each
    for x in (OX - HOOD_X + 0.06, OX - 1.1, OX + 1.1, OX + HOOD_X - 0.06):
        for k in range(n):
            th = -90 + 180 * (k + 0.5) / n
            t = math.radians(th)
            b.box((x, BY1 + rm * math.cos(t), -rm * math.sin(t)), (0.16, 0.12, chord), DARK, rot=rot_x(-th))
    for s in (-1, 1):                                                               # the round ends: a darker
        x = OX + s * (HOOD_X + 0.005)                                               # puckered disc and its tie
        b.cyl((x, BY1, 0), HOOD_R - 0.35, 0.03, "fur_oat", axis="X", segments=16)
        b.cyl((x + s * 0.02, BY1 + HOOD_R - 0.45, 0), 0.1, 0.04, WOOD, axis="X", segments=6)

    def on_hood(x, theta, w, h, sw, lift):
        """A flat piece lying on the canvas at angle theta from the top (+ toward the front, -Z)."""
        r = HOOD_R + lift
        t = math.radians(theta)
        b.box((x, BY1 + r * math.cos(t), -r * math.sin(t)), (w, 0.02, h), sw, rot=rot_x(-theta))

    for x, th, w, h, sw in ((OX - 2.2, 48, 0.9, 0.7, "fur_strawberry"), (OX + 1.75, 62, 0.75, 0.6, "mint"),
                            (OX - 0.25, 18, 0.7, 0.55, "pastel_lilac"), (OX + 2.35, -10, 0.8, 0.65, "pastel_butter"),
                            (OX - 1.6, -55, 0.85, 0.7, "pastel_sky"), (OX + 0.6, -40, 0.7, 0.6, "fur_strawberry")):
        on_hood(x, th, w + 0.1, h + 0.1, "choco", 0.008)                            # the stitched edge
        on_hood(x, th, w, h, sw, 0.022)
    stars = ((OX - 2.9, 25, 0.38), (OX - 1.3, 66, 0.3), (OX - 0.9, 38, 0.42), (OX + 0.35, 52, 0.3),
             (OX + 0.95, 26, 0.36), (OX + 2.75, 40, 0.4), (OX - 2.6, -30, 0.36), (OX - 0.5, -62, 0.32),
             (OX + 1.6, -48, 0.4), (OX + 2.9, -60, 0.3), (OX + 0.2, -15, 0.3))
    for x, th, s in stars:
        r, t = HOOD_R + 0.02, math.radians(th)
        c = (x, BY1 + r * math.cos(t), -r * math.sin(t))
        R = rot_x(-th)
        b.box(c, (s, 0.03, s * 0.22), GOLD, rot=R)
        b.box(c, (s * 0.22, 0.03, s), GOLD, rot=R)
        b.box(c, (s * 0.36, 0.036, s * 0.36), GOLD, rot=R @ rot_y(45))


# ---------------------------------------------------------------- counter ----

def _counter(b):
    """The front side folded down on two chains: a wood board with a gold edge, the pedestal in the middle."""
    z1 = -BZ - 0.01
    b.span((CTR_X0, CTR_Y - 0.14, CTR_Z0), (CTR_X1, CTR_Y, z1), WOOD)
    b.span((CTR_X0 - 0.03, CTR_Y - 0.2, CTR_Z0 - 0.04), (CTR_X1 + 0.03, CTR_Y - 0.1, CTR_Z0 + 0.06), GOLD)
    b.span((CTR_X0 + 0.05, CTR_Y - 0.3, CTR_Z0 + 0.1), (CTR_X1 - 0.05, CTR_Y - 0.14, z1), PANEL)   # its outside
    for x in (CTR_X0 + 0.15, CTR_X1 - 0.15):                                        # chains up to the hatch top
        p0, p1 = (CTR_Z0 + 0.08, CTR_Y), (-BZ - 0.02, BY1 - 0.2)
        dz, dy = p1[0] - p0[0], p1[1] - p0[1]
        b.box((x, (p0[1] + p1[1]) / 2, (p0[0] + p1[0]) / 2), (0.05, math.hypot(dz, dy), 0.05), "metal",
              rot=rot_x(math.degrees(math.atan2(dz, dy))))
    # the pedestal: a berry foot, a gold column, a round berry cushion and two gold cat ears on its back edge
    px, pz = PED
    b.cyl((px, CTR_Y + 0.08, pz), 0.42, 0.16, CLOAK, segments=12)
    b.cyl((px, CTR_Y + 0.17, pz), 0.34, 0.04, GOLD, segments=12)
    b.cyl((px, CTR_Y + 0.42, pz), 0.15, 0.48, GOLD, segments=8)
    b.cyl((px, PED_TOP - 0.08, pz), 0.4, 0.16, CLOAK, segments=14)
    b.cyl((px, PED_TOP - 0.17, pz), 0.42, 0.04, GOLD, segments=14)
    for sx in (-1, 1):
        b.fan_z(pz + 0.3, (px + sx * 0.3, PED_TOP + 0.32), [(px + sx * 0.08, PED_TOP - 0.02),
                                                            (px + sx * 0.44, PED_TOP - 0.02)], 0.06, GOLD)
    # either side of the pedestal: a little stack of wrapped boxes and a jar of fish treats
    for x, sw, rib in ((CTR_X0 + 0.45, "pastel_sky", "fur_strawberry"), (CTR_X0 + 0.95, "pastel_butter", "mint")):
        b.span((x - 0.2, CTR_Y, CTR_Z0 + 0.25), (x + 0.2, CTR_Y + 0.36, CTR_Z0 + 0.65), sw)
        b.span((x - 0.05, CTR_Y, CTR_Z0 + 0.24), (x + 0.05, CTR_Y + 0.37, CTR_Z0 + 0.66), rib)
    b.cyl((CTR_X1 - 0.65, CTR_Y + 0.2, CTR_Z0 + 0.5), 0.2, 0.4, "glass", segments=8)
    b.cyl((CTR_X1 - 0.65, CTR_Y + 0.43, CTR_Z0 + 0.5), 0.17, 0.06, CLOAK, segments=8)
    for dx, dy in ((-0.06, 0.1), (0.07, 0.18), (-0.02, 0.28)):
        b.ball((CTR_X1 - 0.65 + dx, CTR_Y + dy, CTR_Z0 + 0.38), 0.07, "fish_blue")


def _stool(b):
    """Juniper's step stool: a wooden box with a berry cushion, a step on its front."""
    x, z, top = STOOL
    b.span((x - 0.6, 0.0, z - 0.5), (x + 0.6, top - 0.12, z + 0.5), WOOD)
    b.span((x - 0.62, top - 0.4, z - 0.52), (x + 0.62, top - 0.32, z + 0.52), DARK)
    b.span((x - 0.62, top - 0.12, z - 0.52), (x + 0.62, top, z + 0.52), CLOAK)
    b.span((x - 0.45, 0.0, z - 0.75), (x + 0.45, 0.45, z - 0.5), WOOD)              # the step


# ---------------------------------------------------------------- signs -----

def _sign(b):
    """MYSTERY MARKET on a cream board standing on the hood's ridge, a gold "?" either side, a big "?" on its back."""
    w1, w2 = text_width("MYSTERY", SIGN_PX), text_width("MARKET", SIGN_PX)
    w = w1 + 1.5
    y0 = BY1 + HOOD_R + 0.22
    gap = 0.2
    y1 = y0 + 0.2 + 2 * 5 * SIGN_PX + gap + 0.2
    zf, zb = -0.12, 0.12
    for s in (-1, 1):                                                               # two legs into the hood
        b.span((OX + s * (w / 2 - 0.55) - 0.1, BY1 + HOOD_R - 0.3, -0.08), (OX + s * (w / 2 - 0.55) + 0.1, y0, 0.08),
               DARK)
    b.span((OX - w / 2, y0, zf), (OX + w / 2, y1, zb), CANVAS)
    for (xa, xb, ya, yb) in ((OX - w / 2 - 0.12, OX + w / 2 + 0.12, y0 - 0.12, y0 + 0.02),
                             (OX - w / 2 - 0.12, OX + w / 2 + 0.12, y1 - 0.02, y1 + 0.12),
                             (OX - w / 2 - 0.12, OX - w / 2 + 0.01, y0, y1), (OX + w / 2 - 0.01, OX + w / 2 + 0.12, y0, y1)):
        b.span((xa, ya, zf - 0.06), (xb, yb, zb + 0.06), CLOAK)
    label(b, "MYSTERY", OX, y0 + 0.2 + 5 * SIGN_PX + gap, zf + 0.01, SIGN_PX, 0.06, CLOAK, -1)
    label(b, "MARKET", OX, y0 + 0.2, zf + 0.01, SIGN_PX, 0.06, BODY, -1)
    qpx = 0.13
    for s in (-1, 1):                                                               # a "?" at each end
        xc = OX + s * (w / 2 - 0.42)
        mystery._question(b, xc + 1.5 * qpx, (y0 + y1) / 2 - 2.5 * qpx, zf + 0.004, qpx, GOLD)
    for x, y in ((OX - w / 2 - 0.05, y1 + 0.1), (OX + w / 2 + 0.05, y1 + 0.1)):     # gold stars on the corners
        _star(b, x, y, zf - 0.08, 0.42, GOLD)
    # the back: a big "?" in gold, read from +Z (its x mirrored: the viewer's left is -X there)
    qb = 0.22
    rows = ("111", "001", "011", "000", "010")
    for r, bits in enumerate(rows):
        for c, bit in enumerate(bits):
            if bit == "1":
                x = OX - 1.5 * qb + c * qb
                y = (y0 + y1) / 2 - 2.5 * qb + (4 - r) * qb
                b.span((x, y, zb - 0.004), (x + qb, y + qb, zb + 0.012), GOLD)


def _chalk(b, s, cx, y, z, px, sw):
    label(b, s, cx, y, z, px, 0.03, sw, -1)


def _easel(b):
    """The chalkboard easel: a dark board in a wood frame on three legs, THIS WEEK SALE! in chalk."""
    x, z = EASEL
    w, y0, y1 = 1.75, 0.95, 2.75
    zf = z
    for s in (-1, 1):                                                               # front legs
        b.span((x + s * (w / 2 - 0.12) - 0.07, 0.0, zf + 0.04), (x + s * (w / 2 - 0.12) + 0.07, y1 + 0.25, zf + 0.18),
               WOOD)
    tilt = 24
    L = (y1 + 0.1) / math.cos(math.radians(tilt))                                   # the back leg, leaning back
    b.box((x, (y1 + 0.1) / 2 + 0.03, zf + 0.12 + L / 2 * math.sin(math.radians(tilt))), (0.12, L, 0.12), WOOD,
          rot=rot_x(-tilt))
    b.span((x - w / 2, y0, zf + 0.05), (x + w / 2, y1, zf + 0.12), "fur_ink")
    for (xa, xb, ya, yb) in ((x - w / 2 - 0.08, x + w / 2 + 0.08, y0 - 0.1, y0), (x - w / 2 - 0.08, x + w / 2 + 0.08, y1, y1 + 0.1),
                             (x - w / 2 - 0.08, x - w / 2, y0, y1), (x + w / 2, x + w / 2 + 0.08, y0, y1)):
        b.span((xa, ya, zf + 0.02), (xb, yb, zf + 0.15), WOOD)
    b.span((x - w / 2 + 0.1, y0 - 0.1, zf - 0.1), (x + w / 2 - 0.1, y0 - 0.04, zf + 0.05), WOOD)   # chalk ledge
    b.span((x + 0.3, y0 - 0.04, zf - 0.06), (x + 0.5, y0 + 0.02, zf - 0.02), "offwhite")         # a stick of chalk
    px = 0.08
    _chalk(b, "THIS", x, y1 - 0.15 - 5 * px, zf + 0.06, px, "offwhite")
    _chalk(b, "WEEK", x, y1 - 0.15 - 10 * px - 0.12, zf + 0.06, px, "offwhite")
    _chalk(b, "SALE!", x, y0 + 0.15, zf + 0.06, 0.1, "pastel_butter")
    for sx in (-1, 1):                                                              # little chalk stars
        _star(b, x + sx * 0.72, y0 + 0.4, zf + 0.04, 0.18, "fur_strawberry")


def _qboard(b):
    """Next week's board on a post: a cream board with a dark mystery silhouette (a wrapped parcel shape) under a
    gold "?"."""
    x, z = QPOST
    b.span((x - 0.08, 0.0, z - 0.08), (x + 0.08, 3.2, z + 0.08), DARK)
    b.span((x - 0.2, 0.0, z - 0.2), (x + 0.2, 0.15, z + 0.2), DARK)
    w, y0, y1 = 1.15, 2.55, 3.85
    zf = z - 0.12
    b.span((x - w / 2, y0, zf), (x + w / 2, y1, z - 0.08), CANVAS)
    for (xa, xb, ya, yb) in ((x - w / 2 - 0.08, x + w / 2 + 0.08, y0 - 0.08, y0), (x - w / 2 - 0.08, x + w / 2 + 0.08, y1, y1 + 0.08),
                             (x - w / 2 - 0.08, x - w / 2, y0, y1), (x + w / 2, x + w / 2 + 0.08, y0, y1)):
        b.span((xa, ya, zf - 0.03), (xb, yb, z - 0.06), BODY)
    b.span((x - 0.32, y0 + 0.15, zf - 0.02), (x + 0.32, y0 + 0.55, zf + 0.01), "fur_ink")       # the silhouette
    b.span((x - 0.38, y0 + 0.55, zf - 0.02), (x + 0.38, y0 + 0.7, zf + 0.01), "fur_ink")
    for sx in (-1, 1):
        b.box((x + sx * 0.14, y0 + 0.8, zf - 0.005), (0.24, 0.13, 0.03), "fur_ink", rot=rot_z(sx * 30))
    qpx = 0.1
    mystery._question(b, x + 1.5 * qpx, y0 + 0.82 + 0.1, zf - 0.004, qpx, GOLD)


def _props(b):
    """At the far end, behind the "?" post: a crate with a lid and a basket of yarn balls on it, a little sack."""
    cx, cz = OX - BX - 0.95, 0.85
    b.span((cx - 0.55, 0.0, cz - 0.55), (cx + 0.55, 1.0, cz + 0.55), WOOD)
    for yy in (0.25, 0.65):
        b.span((cx - 0.57, yy, cz - 0.57), (cx + 0.57, yy + 0.1, cz + 0.57), DARK)
    b.span((cx - 0.58, 1.0, cz - 0.58), (cx + 0.58, 1.08, cz + 0.58), DARK)
    b.cyl((cx, 1.3, cz), 0.45, 0.44, "cardboard", r2=0.38, segments=10)            # the basket
    b.cyl((cx, 1.5, cz), 0.47, 0.06, WOOD, segments=10)
    for dx, dz, sw in ((-0.18, -0.1, "fur_strawberry"), (0.17, 0.05, "mint"), (0.0, 0.2, "pastel_lilac")):
        b.ball((cx + dx, 1.6, cz + dz), 0.2, sw)
    b.span((cx - 0.25, 0.0, cz - 1.55), (cx + 0.3, 0.55, cz - 1.1), "kibble")      # a little sack by the crate
    b.span((cx - 0.26, 0.55, cz - 1.56), (cx + 0.31, 0.63, cz - 1.09), CANVAS)


def _rug(rug):
    """A round rug in front of the counter: berry, a butter ring, a teal middle with a gold star."""
    x, z = OX - 1.2, -1.85
    rug.cyl((x, 0.02, z), 1.65, 0.04, CLOAK, segments=24)
    rug.cyl((x, 0.035, z), 1.4, 0.04, "pastel_butter", segments=24)
    rug.cyl((x, 0.05, z), 1.15, 0.04, PANEL, segments=24)
    t = 0.03
    for k in range(2):
        rug.box((x, 0.075, z), (1.2, t, 0.26), GOLD, rot=rot_y(45 + 90 * k))
    rug.box((x, 0.085, z), (0.48, t, 0.48), GOLD)


def _lights(b, bulb, cord):
    """The pole and its lantern over Juniper; a string of little lanterns along the front from the pole's top to a short post on the far corner."""
    px, pz = POLE
    b.span((px - 0.08, BY0, pz - 0.08), (px + 0.08, POLE_TOP, pz + 0.08), DARK)
    for y in (BY0 + 0.3, BY1 - 0.3):                                                # its brackets
        b.span((px - 0.14, y, pz - 0.02), (px + 0.02, y + 0.14, pz + 0.12), "metal")
    b.cyl((px, POLE_TOP + 0.05, pz), 0.13, 0.1, GOLD, segments=8)
    lx, ly, lz = LAMP
    arm_y = ly + 0.62
    for a, c in (((px, arm_y, pz), (lx, arm_y, lz)),):                              # the arm out over the stool
        dx, dz = c[0] - a[0], c[2] - a[2]
        b.box(((a[0] + c[0]) / 2, arm_y, (a[2] + c[2]) / 2), (math.hypot(dx, dz) + 0.1, 0.07, 0.07), "fur_black",
              rot=rot_y(-math.degrees(math.atan2(dz, dx))))
    b.span((lx - 0.025, ly + 0.3, lz - 0.025), (lx + 0.025, arm_y, lz + 0.025), "fur_black")
    b.cyl((lx, ly + 0.25, lz), 0.26, 0.12, CLOAK, r2=0.1, segments=8)              # a berry cap
    b.cyl((lx, ly - 0.28, lz), 0.2, 0.07, CLOAK, segments=8)
    for dx, dz in ((-0.17, -0.17), (0.17, -0.17), (-0.17, 0.17), (0.17, 0.17)):
        b.span((lx + dx - 0.025, ly - 0.25, lz + dz - 0.025), (lx + dx + 0.025, ly + 0.2, lz + dz + 0.025), GOLD)
    bulb.span((lx - 0.15, ly - 0.25, lz - 0.15), (lx + 0.15, ly + 0.2, lz + 0.15), "lamp_warm")
    # the string: sags along the front from the pole's top to a short post on the far front corner
    a = Vector((px, POLE_TOP - 0.05, pz))
    c = Vector((OX - BX - 0.12, FAR_TOP - 0.05, pz))
    b.span((c.x - 0.07, BY0, c.z - 0.07), (c.x + 0.07, FAR_TOP, c.z + 0.07), DARK)
    for y in (BY0 + 0.3, BY1 - 0.3):
        b.span((c.x - 0.02, y, c.z - 0.02), (c.x + 0.14, y + 0.14, c.z + 0.12), "metal")
    b.cyl((c.x, FAR_TOP + 0.05, c.z), 0.12, 0.1, GOLD, segments=8)
    n = 8
    pts = []
    for i in range(n + 1):
        t = i / n
        p = a.lerp(c, t)
        p.y -= SAG * 4 * t * (1 - t)
        pts.append(p)
    for p0, p1 in zip(pts, pts[1:]):
        m, d = (p0 + p1) / 2, p1 - p0
        L = d.length
        yaw = math.degrees(math.atan2(-d.z, d.x))
        pitch = math.degrees(math.asin(d.y / L))
        cord.box(tuple(m), (L + 0.03, 0.04, 0.04), "fur_black", rot=rot_y(yaw) @ rot_z(pitch))
    caps = ("fur_strawberry", "mint", "pastel_butter", "pastel_lilac", "sign_teal")
    for k, i in enumerate((1, 2, 3, 4, 5, 6, 7)):
        p = pts[i]
        cap = caps[k % len(caps)]
        cord.span((p.x - 0.015, p.y - 0.14, p.z - 0.015), (p.x + 0.015, p.y, p.z + 0.015), "fur_black")
        b.cyl((p.x, p.y - 0.17, p.z), 0.12, 0.06, cap, segments=8)
        bulb.ball((p.x, p.y - 0.33, p.z), 0.16, "lamp_warm", scale=(1.0, 1.15, 1.0))


def build_mystery_cart(mat):
    b, bulb, cord, rug = RB(), RB(), RB(), RB()
    _body(b)
    _under(b)
    _hood(b)
    _counter(b)
    _stool(b)
    _sign(b)
    _easel(b)
    _qboard(b)
    _props(b)
    _rug(rug)
    _lights(b, bulb, cord)
    out = [b.finalize(NAME, mat), bulb.finalize(NAME + "_Bulb", mat), cord.finalize(NAME + "_Lights_Decor", mat),
           rug.finalize(NAME + "_Rug_Decor", mat)]
    base = NAME + "_Cat"                                                            # Juniper, on the stool
    cat = cats.build_cat("Juniper", mat, spec=CAT, base=base, body="sit")
    d = cats.dims(CAT, "sit")
    k = cats.scale_of(CAT, "sit")
    ctx = props.Ctx(CAT, "sit", d)
    mystery._hood(ctx, CLOAK, TRIM)
    hood = ctx.main.finalize(base + "_Prop", mat, location=tuple(v * k for v in d["pivots"]["Head"]))
    scale_mesh(hood, k)
    hood["rides"] = "Head"
    cb = Builder()
    mystery._cloak(cb, CLOAK, TRIM)
    cloak = cb.finalize(base + "_Cloak", mat)
    scale_mesh(cloak, k)
    x, z, top = STOOL
    for ob in cat + [hood, cloak]:
        ob.location = ob.location + Vector(RB.p(x, top - 0.01, z))
    return out + cat + [hood, cloak]


def attachments():
    """(object, Attachment name, Blender 4x4) for rbx_export: PromptAnchor and FeaturedItem on the wagon."""
    return [(NAME, "PromptAnchor", Matrix.Translation(Vector(RB.p(*PROMPT_ROBLOX)))),
            (NAME, "FeaturedItem", Matrix.Translation(Vector(RB.p(*FEATURED_ROBLOX))))]


NEST = {NAME: {"_Prop": "_Head"}}

ASSETS = {
    NAME: (build_mystery_cart, 10000),
}
