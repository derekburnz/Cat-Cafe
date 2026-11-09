"""Juniper's Mystery Market items (#2565, mystery-market.md sections 3d and 4): the models the shop window's pictures
(Components/ItemIcon draws a model from ReplicatedStorage.Assets at a three-quarter view of its -Z face) and the
wagon's pedestal (the Attachment FeaturedItem on CatCafe_Square_MysteryCart) show. Both face -Z, like every item.

  CatCafe_Item_Backpack        the Backpack (#2849, made cuter in a new color for #2888): a soft lilac pack with
                               chubby cat ears on its top corners (pink insides), plum piping, base and straps, a
                               pink front panel with pearl stitching and a gold heart buckle, a pearl front pocket
                               with a pink paw and a gold zip pull, plum side pockets each holding a mint bottle, and
                               a short lilac cat tail with a pink tip curling up its +X side. About 1.8 x 1.6 x 0.8
                               studs with the tail. Pivot at the middle of its back (the strap side, +Z), so it can be
                               worn as the design says (welded behind the torso by HeldCat.wearPack, turned 180
                               degrees about Y so the front looks backward, the strap side against the back). The
                               opening's rim and middle stay where HeldCat's PACK_RIM and PACK_MOUTH_Z expect them.
  CatCafe_Item_Backpack_Flap   the pink lid with pearl stitching (the heart-buckled front panel stays on the pack), a
                               child Model pivoted on its hinge at the top of the pack's back: turn it about its own X
                               axis (HeldCat opens it 90 degrees, so it stands up behind the cat) when a cat rides in
                               it, so the packed cat's head comes out of the top between the ears.
  CatCafe_Item_LongNet         the Long Net: a round net seen face-on with a long three-piece telescoping handle
                               (a dark grip, a teal middle and a measuring-tape tip in cream and ink) and a gold arrow
                               beside the handle pointing out toward the hoop: "your net reaches further". About
                               3.5 x 3.3 x 1 studs, pivot at the middle of its bounding box's bottom.

No scripts, nothing Neon. Collision is the user's call: ItemIcon clones them into a ViewportFrame, and the worn pack is
massless and CanCollide off like the held cat.
"""

import math

from mathutils import Vector

from common import RB
from plot import rot_z

BACKPACK = "CatCafe_Item_Backpack"
LONG_NET = "CatCafe_Item_LongNet"

# #2849 (Derek2 2026-11-09: "make the model for backpack cooler") gave it cat ears, a buckled front and a cat tail;
# #2888 (Derek2 23:23 and 23:29: "a little more cutesy", "change the blue color of bag and make it slightly diff")
# made it a soft lilac pack with a pink front panel and lid, a pearl pocket, a gold heart buckle, chubbier ears and a
# shorter tail with a pink tip.
SKY, NAVY, POCKET, PINK = "pastel_lilac", "velvet_lilac", "pearl", "nose_pink"
PANEL, ZIP = "apron_pink", "fur_strawberry"
STITCH, BOTTLE, CAP = "pearl", "mint", "offwhite"
BUCKLE = "gold_mid"
GOLD = "rarity_legend"                        # the Long Net's
W, H, D = 1.3, 1.4, 0.62                      # the pack's width, height and depth (front at -D; its back at
                                              # -0.045, the straps and buckles out to z 0)
Y0 = -0.75                                    # its bottom (the pivot is the middle of its back)
Y1 = Y0 + H                                   # the opening's rim (HeldCat.PACK_RIM 0.66 sits just above it)
HINGE = (0.0, Y1 + 0.03, -0.06)               # the flap's hinge, along X at the top of the back
FLAP_OPEN = 125                               # degrees the flap turns back to open
FW = 0.46                                     # the flap's half width: the ears stand on the corners beside it
TAIL = ((W / 2 - 0.02, Y0 + 0.26), (W / 2 + 0.17, Y0 + 0.4), (W / 2 + 0.24, Y0 + 0.62),
        (W / 2 + 0.14, Y0 + 0.8))             # the tail's joints, a short curl up the +X side near the back
TAIL_Z = -0.095                               # its middle, front to back (between the side pocket and the straps)


def _tail(b):
    """A short lilac cat tail curling up the +X side with a pink tip: one box per joint-to-joint run, a ball on each
    inner joint so the bends stay round."""
    n = len(TAIL) - 1
    for i in range(n):
        (ax, ay), (bx, by) = TAIL[i], TAIL[i + 1]
        length = math.hypot(bx - ax, by - ay)
        ang = math.degrees(math.atan2(by - ay, bx - ax))
        r = 0.075 if i < n - 1 else 0.07
        b.box(((ax + bx) / 2, (ay + by) / 2, TAIL_Z), (length, 2 * r, 2 * r), SKY if i < n - 1 else PANEL,
              rot=rot_z(ang))
        if 0 < i:
            b.ball((ax, ay, TAIL_Z), r + 0.005, SKY)


def _pack(b):
    x0, x1 = -W / 2, W / 2
    b.span((x0, Y0 + 0.12, -D), (x1, Y1, -0.045), SKY)
    b.span((x0 - 0.03, Y0, -D - 0.03), (x1 + 0.03, Y0 + 0.12, -0.015), NAVY)                     # the base
    for x in (x0 + 0.06, x1 - 0.06):                                                             # navy piping up
        b.span((x - 0.04, Y0 + 0.12, -D - 0.035), (x + 0.04, Y0 + 0.72, -D + 0.04), NAVY)        # the front corners
    # the front pocket: pearl, a strawberry zip line with a gold pull, a pink paw
    b.span((x0 + 0.18, Y0 + 0.18, -D - 0.12), (x1 - 0.18, Y0 + 0.64, -D), POCKET)
    b.span((x0 + 0.21, Y0 + 0.57, -D - 0.13), (x1 - 0.21, Y0 + 0.6, -D - 0.12), ZIP)
    b.span((0.27, Y0 + 0.43, -D - 0.15), (0.33, Y0 + 0.58, -D - 0.12), BUCKLE)
    py, pz = Y0 + 0.33, -D - 0.135
    b.cyl((-0.05, py, pz), 0.1, 0.03, PINK, axis="Z", segments=10)
    for dx, dy in ((-0.11, 0.1), (-0.04, 0.15), (0.04, 0.15), (0.11, 0.1)):
        b.cyl((-0.05 + dx, py + dy, pz), 0.038, 0.03, PINK, axis="Z", segments=6)
    # side pockets, plum, each with a mint bottle standing in it
    for s in (-1, 1):
        b.span((s * (W / 2), Y0 + 0.16, -D + 0.1), (s * (W / 2 + 0.12), Y0 + 0.6, -0.17), NAVY)
        b.span((s * (W / 2 + 0.005), Y0 + 0.54, -D + 0.095), (s * (W / 2 + 0.125), Y0 + 0.57, -0.165), STITCH)
        bx = s * (W / 2 + 0.065)
        b.cyl((bx, Y0 + 0.72, -0.36), 0.06, 0.24, BOTTLE, segments=8)
        b.cyl((bx, Y0 + 0.87, -0.36), 0.035, 0.06, CAP, segments=6)
    # chubby cat ears on the top corners, beside the flap: lilac with pink insides, facing -Z
    for s in (-1, 1):
        lo, hi, tip = s * (FW + 0.01), s * (W / 2 + 0.15), s * (W / 2 + 0.02)
        b.fan_z(-D + 0.14, (tip, Y1 + 0.36), [(lo, Y1), (hi, Y1)], 0.24, SKY)
        b.fan_z(-D + 0.12, (tip, Y1 + 0.26), [(lo + s * 0.07, Y1 + 0.04), (hi - s * 0.08, Y1 + 0.04)], 0.02, PINK)
    # the back: two plum straps from the top to the base with gold buckles, a carry loop on top
    for x in (-0.33, 0.33):
        b.span((x - 0.11, Y0 + 0.12, -0.045), (x + 0.11, Y1 - 0.05, -0.01), NAVY)
        b.span((x - 0.12, Y0 + 0.35, -0.01), (x + 0.12, Y0 + 0.45, 0.0), BUCKLE)
    for x in (-0.22, 0.22):
        b.span((x - 0.05, Y1, -0.16), (x + 0.05, Y1 + 0.24, -0.08), NAVY)
    b.span((-0.27, Y1 + 0.2, -0.16), (0.27, Y1 + 0.28, -0.08), NAVY)
    # the pink front panel with pearl stitching and a gold heart buckle. It stays on the body, so the lid alone
    # swings up behind a riding cat's head and nothing hangs over it.
    zf = -D - 0.06
    b.span((-FW, Y0 + 0.76, zf), (FW, Y1, -D), PANEL)
    for x in (-FW + 0.08, FW - 0.08):
        b.span((x - 0.015, Y0 + 0.86, zf - 0.012), (x + 0.015, Y1 - 0.06, zf), STITCH)
    b.span((-FW + 0.08, Y0 + 0.82, zf - 0.012), (FW - 0.08, Y0 + 0.85, zf), STITCH)
    hy, hz = Y0 + 0.8, zf - 0.02                                                                # the heart buckle
    for s in (-1, 1):
        b.cyl((s * 0.065, hy + 0.04, hz - 0.004), 0.08, 0.044, BUCKLE, axis="Z", segments=12)   # its two lobes
    b.box((0.0, hy - 0.025, hz + 0.004), (0.155, 0.155, 0.04), BUCKLE, rot=rot_z(45))       # its point, set back
    _tail(b)


def _flap(f):
    """The lid in its hinge's frame: pink, over the opening, with a pearl stitched edge and a lip over the front panel.
    Opened (HeldCat turns it 90 degrees), it stands up behind the riding cat's head."""
    hx, hy, hz = HINGE

    def span(lo, hi, sw, rot=None):
        f.span((lo[0] - hx, lo[1] - hy, lo[2] - hz), (hi[0] - hx, hi[1] - hy, hi[2] - hz), sw, rot)

    span((-FW, Y1, -D - 0.06), (FW, Y1 + 0.07, -0.02), PANEL)                                   # lid
    span((-FW, Y1 - 0.08, -D - 0.08), (FW, Y1, -D - 0.06), PANEL)                              # its front lip
    for x in (-FW + 0.07, FW - 0.07):                                                           # stitching
        span((x - 0.015, Y1 + 0.07, -D + 0.02), (x + 0.015, Y1 + 0.082, -0.1), STITCH)
    span((-FW + 0.07, Y1 + 0.07, -D + 0.005), (FW - 0.07, Y1 + 0.082, -D + 0.035), STITCH)


def build_backpack(mat):
    b, f = RB(), RB()
    _pack(b)
    _flap(f)
    return [b.finalize(BACKPACK, mat), f.finalize(BACKPACK + "_Flap", mat, location=HINGE)]


# ------------------------------------------------------------------ long net --

HOOP = (1.12, 3.11, -0.39)                     # the hoop's centre: the net faces the camera (-Z), the bag hangs back
HOOP_R, TUBE = 0.78, 0.11
PHI = 225.0                                   # the handle's way out from the hoop, in the XY plane (down and left)


def _rcyl(b, c, r, h, sw, phi, segments=10):
    """A cylinder centred on c with its axis along angle phi (degrees from +X) in the Roblox XY plane."""
    p = math.radians(phi)
    theta = math.atan2(-math.cos(p), math.sin(p))
    b.b.cyl(RB.p(*c), r, h, sw, segments=segments, bevel=False, rot=(theta, "Y"))


def _bar(b, a, c, t, sw):
    a, c = Vector(a), Vector(c)
    d = c - a
    R = Vector((0, 1, 0)).rotation_difference(d.normalized()).to_matrix()
    b.box(tuple((a + c) / 2), (t, d.length, t), sw, rot=R)


def build_long_net(mat):
    b = RB()
    cx, cy, cz = HOOP
    p = math.radians(PHI)
    d = (math.cos(p), math.sin(p))

    def at(t, off=0.0):
        """A point t studs out along the handle from the hoop's rim, `off` to the handle's lower right."""
        n = (-d[1], d[0])                                                          # 90 degrees round: lower right
        r = HOOP_R + t
        return (cx + d[0] * r + n[0] * off, cy + d[1] * r + n[1] * off, cz)

    # the hoop and its netting
    b.b.ring(RB.p(cx, cy, cz), HOOP_R + TUBE, 2 * TUBE, 2 * TUBE, "metal", segments=18, bevel=False,
             rot=(math.radians(90), "X"))
    b.b.ring(RB.p(cx, cy, cz - TUBE - 0.005), HOOP_R + TUBE * 0.6, TUBE * 0.8, 0.03, GOLD, segments=18, bevel=False,
             rot=(math.radians(90), "X"))
    tip = (cx + 0.05, cy - 0.3, cz + 1.0)
    rim = [(cx + (HOOP_R - 0.04) * math.cos(math.radians(a)), cy + (HOOP_R - 0.04) * math.sin(math.radians(a)), cz + 0.05)
           for a in range(0, 360, 40)]
    mid = [(0.5 * (r[0] + tip[0]) + 0.08 * math.cos(math.radians(a + 20)),
            0.5 * (r[1] + tip[1]) + 0.08 * math.sin(math.radians(a + 20)), 0.5 * (r[2] + tip[2]))
           for r, a in zip(rim, range(0, 360, 40))]
    for i in range(len(rim)):
        _bar(b, rim[i], mid[i], 0.045, "offwhite")
        _bar(b, rim[i], mid[i - 1], 0.045, "offwhite")                          # crossing: diamonds
        _bar(b, mid[i], tip, 0.045, "offwhite")
    b.ball(tip, 0.07, "offwhite")
    # the handle: neck and ferrule, the measuring-tape tip, a collar, the teal middle, a collar, the grip
    _rcyl(b, at(0.12), 0.1, 0.3, GOLD, PHI)
    for k in range(6):                                                              # tape: cream and ink bands
        _rcyl(b, at(0.37 + 0.18 * k), 0.075, 0.18, "cream" if k % 2 == 0 else "fur_ink", PHI)
    _rcyl(b, at(1.5), 0.105, 0.12, GOLD, PHI)
    _rcyl(b, at(2.0), 0.09, 0.9, "sign_teal", PHI)
    _rcyl(b, at(2.5), 0.12, 0.12, GOLD, PHI)
    _rcyl(b, at(3.0), 0.115, 0.85, "fur_black", PHI)                               # grip
    for t in (2.8, 3.2):
        _rcyl(b, at(t), 0.122, 0.05, "fur_toffee", PHI)
    _rcyl(b, at(3.46), 0.13, 0.08, GOLD, PHI)                                      # end cap
    # the arrow: a gold shaft beside the handle and a head pointing out to the hoop, standing proud of the front
    z = cz - 0.2
    a0, a1 = Vector(at(2.1, 0.42)), Vector(at(0.55, 0.42))
    m = (a0 + a1) / 2
    b.box((m.x, m.y, z), ((a1 - a0).length, 0.14, 0.08), GOLD, rot=rot_z(PHI + 180))
    tipa = Vector(at(0.05, 0.42))
    n = Vector((-d[1], d[0], 0))
    base = Vector(at(0.6, 0.42))
    b.fan_z(z - 0.04, (tipa.x, tipa.y), [((base + n * 0.3).x, (base + n * 0.3).y), ((base - n * 0.3).x, (base - n * 0.3).y)],
            0.08, GOLD)
    # its back end: three little sparkles
    for (t, off, s) in ((2.45, 0.6, 0.16), (2.4, 0.25, 0.12), (2.7, 0.45, 0.1)):
        q = at(t, off)
        b.box((q[0], q[1], z), (s, s, 0.06), "pastel_butter", rot=rot_z(45))
    return [b.finalize(LONG_NET, mat)]


ASSETS = {
    BACKPACK: (build_backpack, 1500),
    LONG_NET: (build_long_net, 2000),
}
