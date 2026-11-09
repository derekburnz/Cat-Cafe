"""Juniper's Mystery Market items (#2565, mystery-market.md sections 3d and 4): the models the shop window's pictures
(Components/ItemIcon draws a model from ReplicatedStorage.Assets at a three-quarter view of its -Z face) and the
wagon's pedestal (the Attachment FeaturedItem on CatCafe_Square_MysteryCart) show. Both face -Z, like every item.

  CatCafe_Item_Backpack        the Backpack: a teal canvas pack, a butter front pocket with a teal paw, mint side
                               pockets, a carry loop and two straps on its back. Its cream top flap is a cat's face:
                               two ears standing up off the flap with pink insides, eyes with a glint, a pink nose,
                               a smile and whiskers, and a gold buckle under the chin. About 1.3 x 1.6 x 0.8 studs.
                               Pivot at the middle of its back (the strap side, +Z), so it can be worn as the design
                               says (welded behind the torso like HeldCat.attachBack, turned 180 degrees about Y so the
                               cat face looks backward, the strap side against the back).
  CatCafe_Item_Backpack_Flap   the flap, its ears and face, a child Model pivoted on its hinge at the top of the
                               pack's back: turn it about its own X axis (FLAP_OPEN degrees, the face swinging up
                               and back) to open the pack when a cat rides in it, so the packed cat's head and paws
                               come out of the top.
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

PACK, POCKET, SIDE, FLAP = "sign_teal", "pastel_butter", "mint", "cream"
GOLD = "rarity_legend"
STRAP = "dark_wood"
W, H, D = 1.3, 1.4, 0.62                      # the pack's width, height and depth (front at -D; its back at
                                              # -0.045, the straps and buckles out to z 0)
Y0 = -0.75                                    # its bottom (the pivot is the middle of its back)
Y1 = Y0 + H
HINGE = (0.0, Y1 + 0.03, -0.06)               # the flap's hinge, along X at the top of the back
FLAP_OPEN = 125                               # degrees the flap turns back to open


def _pack(b):
    x0, x1 = -W / 2, W / 2
    b.span((x0, Y0, -D), (x1, Y1, -0.045), PACK)
    b.span((x0 - 0.03, Y0 - 0.02, -D - 0.03), (x1 + 0.03, Y0 + 0.12, -0.015), STRAP)             # the base
    for x in (x0 + 0.06, x1 - 0.06):                                                             # piping up the
        b.span((x - 0.04, Y0 + 0.12, -D - 0.035), (x + 0.04, Y1, -D + 0.04), "cream")            # front corners
    # the front pocket: butter with a teal paw and a gold zip pull
    b.span((x0 + 0.2, Y0 + 0.16, -D - 0.12), (x1 - 0.2, Y0 + 0.72, -D + 0.01), POCKET)
    b.span((x0 + 0.2, Y0 + 0.66, -D - 0.13), (x1 - 0.2, Y0 + 0.72, -D - 0.11), "fur_caramel")   # its seam
    py, pz = Y0 + 0.4, -D - 0.13
    b.cyl((0.0, py - 0.03, pz), 0.11, 0.03, PACK, axis="Z", segments=8)
    for dx, dy in ((-0.11, 0.09), (-0.04, 0.14), (0.04, 0.14), (0.11, 0.09)):
        b.cyl((dx, py + dy, pz), 0.04, 0.03, PACK, axis="Z", segments=6)
    b.span((x1 - 0.32, Y0 + 0.56, -D - 0.16), (x1 - 0.26, Y0 + 0.68, -D - 0.12), GOLD)
    # side pockets
    for s in (-1, 1):
        b.span((s * (W / 2 + 0.1), Y0 + 0.18, -D + 0.1), (s * (W / 2 - 0.01), Y0 + 0.62, -0.1), SIDE)
        b.span((s * (W / 2 + 0.11), Y0 + 0.56, -D + 0.09), (s * (W / 2 - 0.01), Y0 + 0.62, -0.09), "cream")
    # the back: two straps from the top to the base, a carry loop on top
    for x in (-0.33, 0.33):
        b.span((x - 0.11, Y0 + 0.12, -0.05), (x + 0.11, Y1 - 0.05, -0.01), STRAP)
        b.span((x - 0.12, Y0 + 0.35, -0.03), (x + 0.12, Y0 + 0.45, 0.0), GOLD)                    # strap buckles
    for x in (-0.22, 0.22):
        b.span((x - 0.05, Y1, -0.16), (x + 0.05, Y1 + 0.24, -0.08), STRAP)
    b.span((-0.27, Y1 + 0.2, -0.16), (0.27, Y1 + 0.28, -0.08), STRAP)


def _flap(f):
    """The flap in its hinge's frame: a lid over the top and a drop down the front, the cat's face on the drop."""
    hx, hy, hz = HINGE

    def span(lo, hi, sw, rot=None):
        f.span((lo[0] - hx, lo[1] - hy, lo[2] - hz), (hi[0] - hx, hi[1] - hy, hi[2] - hz), sw, rot)

    def box(c, s, sw, rot=None):
        f.box((c[0] - hx, c[1] - hy, c[2] - hz), s, sw, rot)

    def cyl(c, r, h, sw, axis="Z", segments=8):
        f.cyl((c[0] - hx, c[1] - hy, c[2] - hz), r, h, sw, axis=axis, segments=segments)

    zf = -D - 0.06                                                                              # the drop's face
    span((-W / 2 - 0.04, Y1, -D - 0.06), (W / 2 + 0.04, Y1 + 0.07, -0.02), FLAP)                # lid
    span((-W / 2 - 0.04, Y0 + 0.74, zf), (W / 2 + 0.04, Y1 + 0.07, -D), FLAP)                   # drop
    span((-W / 2 - 0.05, Y0 + 0.74, zf - 0.01), (W / 2 + 0.05, Y0 + 0.8, -D + 0.01), "fur_caramel")   # hem
    # the ears: standing up off the lid near its front corners, pink inside, facing -Z
    for s in (-1, 1):
        ex, eb = s * 0.38, Y1 + 0.07
        f.fan_z(-D + 0.1 - hz, (ex - hx, eb + 0.36 - hy), [(ex - 0.2 - hx, eb - 0.01 - hy), (ex + 0.2 - hx, eb - 0.01 - hy)],
                0.1, FLAP)
        f.fan_z(-D + 0.04 - hz, (ex - hx, eb + 0.26 - hy), [(ex - 0.1 - hx, eb + 0.02 - hy), (ex + 0.1 - hx, eb + 0.02 - hy)],
                0.02, "nose_pink")
    # the face on the drop
    fy = Y0 + 1.08
    for s in (-1, 1):
        cyl((s * 0.27, fy + 0.05, zf - 0.015), 0.1, 0.03, "fur_ink", segments=10)              # eyes
        cyl((s * 0.27 - 0.03, fy + 0.09, zf - 0.03), 0.035, 0.02, "milk", segments=6)          # glints
        cyl((s * 0.43, fy - 0.12, zf - 0.012), 0.08, 0.024, "fur_strawberry", segments=8)      # cheeks
        for k, a in enumerate((8, -8)):                                                         # whiskers
            box((s * 0.6, fy - 0.08 - 0.06 * k, zf - 0.015), (0.26, 0.025, 0.02), "choco", rot=rot_z(s * a))
    box((0.0, fy - 0.08, zf - 0.015), (0.13, 0.09, 0.03), "nose_pink", rot=rot_z(45))          # nose
    for s in (-1, 1):                                                                           # a little w smile
        box((s * 0.06, fy - 0.17, zf - 0.012), (0.12, 0.025, 0.024), "choco", rot=rot_z(s * 30))
    span((-0.09, Y0 + 0.67, zf - 0.04), (0.09, Y0 + 0.83, zf + 0.01), GOLD)                    # the buckle
    span((-0.05, Y0 + 0.5, -D - 0.04), (0.05, Y0 + 0.74, -D + 0.005), STRAP)                   # its tab down


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
